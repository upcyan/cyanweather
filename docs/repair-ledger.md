# CyanWeather 修复台账与交接说明

- **项目**:晴暖天气(CyanWeather)四端仓库 `github.com/upcyan/cyanweather`
- **修复范围**:`app/`(Kotlin+Compose 主推版)、`shared/`(KMP 共享模块)、`webf/`(WebF 实验版)
- **修复前基线**:commit `30361bd`(v1.2.2+13,native 版本同步)
- **修复后提交**:commit `0a2b109` "fix: 代码审查问题修复(P1-P3)",分支 main,**未 push**
- **台账日期**:2026-09-22

---

## 一、问题盘点清单与修复顺序(编号 F1–F7)

顺序依据:P1 阻塞/体验硬伤优先 → P2 可维护性与排障能力 → P3 卫生项;先根因(数据层)后下游(UI 接线)。

| 编号 | 级别 | 问题 | 位置 | 依赖关系 |
|---|---|---|---|---|
| F1 | P1 | 多数据源串行加载,5 源最坏 75s | `app/.../WeatherRepository.kt loadWeather()` | 无,根因项 |
| F2 | P1 | 自更新安装黑洞:未授权「安装未知应用」且异常被静默吞掉,下载 100% 后无反应 | `app/.../UpdateChecker.kt`、`AppViewModel.kt`、`HomeScreen.kt`、`MainActivity.kt` | 依赖 F2b(同链路) |
| F2b | P1 连带 | 下载失败(STATUS_FAILED)会落到安装分支拉起损坏 APK | `AppViewModel.checkDownloadComplete()` | 与 F2 同链路,先修 |
| F3 | P2 | `aggregateInt` 向零截断,AQI/湿度聚合系统性偏小 1 | `shared/.../WeatherAggregator.kt` | 无 |
| F4 | P2 | 1606 行 `AdminHierarchy.kt` 整份复制(app 副本零引用) | `app/.../AdminHierarchy.kt` | 无 |
| F5 | P2 | NMC 层网络/解析/空数据三类错误全吞成 null,无法排障 | `shared/.../NmcApi.kt` | 无 |
| F6 | P2 | WebF `app.js` 8 处 innerHTML 拼接未转义 | `webf/assets/web/app.js` | 无 |
| F7 | P3 | 工作日志/本机脚本/token-optimizer 数据误入库 | 仓库根 + `.gitignore` | 无 |

## 二、逐项修复记录

### F1 多数据源并行加载
- **原因**:for 循环逐源请求,每源 15s 超时,N 源串行最坏 N×15s;同文件 `loadAllCities()` 已正确用 `async/awaitAll`,属遗漏。
- **改动**:`loadWeather()` 改 `coroutineScope { selected.map { async { source to runCatching { loadSource(...) } } }.awaitAll() }`;因 `runCatching` 会把 `CancellationException` 捕获为结果,失败分类在 `fold` 中进行并原样上抛取消异常,保持刷新被新请求取代时的取消语义。
- **验证**:shared 全量编译通过;AggregatorTest 7/7 通过(覆盖聚合路径)。

### F2 自更新安装黑洞
- **原因**:Android 8+ 安装需「允许安装未知应用」逐应用授权;原代码既不检查也不引导,`startActivity` 抛异常被 `catch (_: Exception) {}` 静默吞掉。
- **改动**:
  - `UpdateChecker` 新增 `canInstallPackages()`(API 26+ 检查,<26 直接 true)与 `requestInstallPermission()`(带包名 deep link,失败退回通用设置页);
  - `AppViewModel` 新增 `installDownloadedApk()`:未授权→提示+记录 `pendingInstallFile`+跳设置页;`onResume` 检测授权成功自动续装(isRetry 分支);安装异常给出可见文案;
  - `HomeScreen` 新增非下载期安装提示弹窗(原 `updateProgressText` 只在下载对话框可见,下载结束即消失),`onDismissInstallNotice` 经 `MainActivity` 接线到 `vm::dismissInstallNotice`。
- **验证**:接线一致性 grep 复核(HomeScreen/MainActivity 各 3 处);AppViewModel 更新链路无静默空 catch 残留。**真机 ROM 行为需人工走查(见遗留风险)。**

### F2b 下载失败误入安装分支
- **原因**:`pollDownload` 抛异常(STATUS_FAILED)被 `catch → null`,`null` 与「超时」共用分支,后续仍会安装。
- **改动**:catch 中明确结束流程:清 `updateFileName`/`updateDownloadId`,提示「下载失败:原因,可在 设置→检查更新 重试」。

### F3 聚合取整
- **改动**:`toInt()` → `roundToInt()`(两处),与 Flutter 版 `round()` 对齐;补注释。
- **验证**:AggregatorTest `testTwoSourcesAverage` 等通过。

### F4 删除重复 AdminHierarchy
- **验证**:删除前 grep 确认 `com.cyanweather.app.data.AdminHierarchy` 零引用、`CityPickerScreen` 用 shared 版;删除后 `find` 确认仓库仅剩 shared 一份。

### F5 NMC 错误分层
- **改动**:`weatherByStationId` 仅捕获 `SerializationException`/`IllegalArgumentException` 并包装「气象局接口返回格式异常(可能已改版)」;网络异常(HTTP 状态)原样上抛;空数据保持 `null`(上游报「气象局暂无数据」)。
- **验证**:shared 编译+MapperTest 通过;调用方 `loadWeather` 已按源收集失败信息,不会崩溃。

### F6 WebF 转义
- **改动**:搜索结果(`r.name`/`sub`/`e.message`)、省市级联、提示卡 `showNotice`/`showNoticeAction`、`window.onerror`、逐时 `cond`、多日 `combineDayNight`(新增 `combineDayNightEsc`)统一 `escapeHTML`。
- **验证**:`node --check` 语法通过;escapeHTML 引用 15→29 处。

### F7 仓库卫生
- **改动**:`git rm --cached` 移除 `.rel_*.log`×5、`_dirlist.txt`、`build_log.txt`、`git-ssh.bat`、`.token-optimizer/wiki/*.jsonl`×2(本地保留);`.gitignore` 补规则段。
- **说明**:`git-ssh.bat` 内容为纯路径调用无密钥,仍属本机脚本不应入库。

## 三、全量回归对照

| 检查项 | 基线 30361bd | 修复后 0a2b109 | 结论 |
|---|---|---|---|
| shared 模块 kotlinc 2.0.20 编译 | 通过(RC=0) | 通过(RC=0,32 个 class) | 无回归 |
| shared 单元测试 | 20/20 通过 | 20/20 通过 | 零新增失败 |
| webf app.js 语法 | — | `node --check` 通过 | ✓ |
| diff 规模 | — | 20 files,+161/−2066 | 删多于增(主要是 F4 去重) |

## 四、遗留风险与建议(明示,未静默跳过)

| 项 | 说明 | 建议 |
|---|---|---|
| Android 层未编译验证 | 沙箱无 Android SDK,`app/` 模块(Kotlin+Compose)无法编译;已人工复查全部接线 | 本地跑 `./gradlew :app:assembleDebug` 后再出包 |
| 真机安装链路 | 授权引导→onResume 续装涉及各 ROM 行为(个别 ROM 可能拦截) | 真机过一遍:检查更新→下载→授权→自动安装 |
| 未 push | commit 仅在本地 main | 确认后 `git push` 或走 PR |
| 中期项未动 | 四端 WMO/MAD 逻辑下沉 shared、补 LICENSE、千行大文件拆分 | 超出本次范围,另行安排 |

## 五、回滚步骤

整体回滚:`git reset --hard 30361bd`(丢弃全部修复)。

单项回滚(基于同一基线,互不依赖,可独立 revert):

| 项 | 回滚命令 |
|---|---|
| F1 | `git checkout 30361bd -- app/src/main/java/com/cyanweather/app/data/WeatherRepository.kt` |
| F2/F2b | `git checkout 30361bd -- app/src/main/java/com/cyanweather/app/update/UpdateChecker.kt app/src/main/java/com/cyanweather/app/ui/AppViewModel.kt app/src/main/java/com/cyanweather/app/ui/HomeScreen.kt app/src/main/java/com/cyanweather/app/MainActivity.kt` |
| F3 | `git checkout 30361bd -- shared/src/commonMain/kotlin/com/cyanweather/shared/data/WeatherAggregator.kt` |
| F4 | `git checkout 30361bd -- app/src/main/java/com/cyanweather/app/data/AdminHierarchy.kt` |
| F5 | `git checkout 30361bd -- shared/src/commonMain/kotlin/com/cyanweather/shared/data/NmcApi.kt` |
| F6 | `git checkout 30361bd -- webf/assets/web/app.js` |
| F7 | `git checkout 30361bd -- .gitignore && git checkout 30361bd -- .rel_*.log _dirlist.txt build_log.txt git-ssh.bat .token-optimizer/` |

回滚后重跑:`./gradlew :shared:test :app:assembleDebug` + `node --check webf/assets/web/app.js`。

## 六、验证环境说明

- 沙箱无 Android SDK/gradle(系统 gradle 4.4.1 过旧),验证链为:腾讯镜像 gradle-8.9 wrapper 不可用 → 改用 kotlinc 2.0.20 直编 + maven central 依赖 jar(kotlinx-datetime/coroutines/serialization/core/okhttp/kotlin-stdlib)+ `kotlin.test` shim(`-Xallow-kotlin-package`)编译 commonTest → 反射运行 JUnit4 风格用例。
- 测试环境中间文件位于 workspace `.openclaw/tmp/`(kotlinc、依赖 jar、编译产物),不影响仓库。

---

## 七、2026-10-21 天气图标重建（夜间版 + 三端矢量）

### 7.1 图标产物

- 统一素材：QWeather Icons v1.8.0（MIT），15 个 slug，含 `clear-night` / `partly-cloudy-night`。
- native：`app/src/main/res/drawable/weather_*.xml`（VectorDrawable，16 网格）。
- flutter：`flutter/assets/weather/*.svg`（`flutter_svg` / `SvgPicture.asset`）。
- webf：`webf/assets/web/icons/*.svg`，`app.js` 的 `<img>` 已全部指向 `.svg`（WebF 0.24 原生支持 SVG 解码）。
- PNG 仅保留作历史回退，代码不再引用。

### 7.2 修复项

| 问题 | 位置 | 处理 |
|---|---|---|
| VectorDrawable 分色错误：`partly-cloudy-day/night` 的云也被染成金色 | `tools/build_weather_icons.py::svg_to_vd` | fill 只从 path 自身标签读取，不再用前 200 字符窗口误取上一段颜色；重新生成后云为 `#8A939E` |
| `SkyKind.MOON` 在白天会退回太阳图标 | `app/.../WeatherIcon.kt` | MOON 恒用 `weather_clear_night`，与本地时钟解耦 |
| Flutter 逐时图标按「当前时刻」判夜，20 点的晴仍显示太阳 | `flutter/lib/widgets/weather_icon.dart` + 调用点 | 新增 `hour` 参数；逐时卡传条目小时，多日/降雨趋势传 12（白天图标），主卡缺省用当前时刻 |

夜间判定三端统一：`h >= 19 || h < 6`。

### 7.3 构建环境（本机）

| 问题 | 处理 |
|---|---|
| sdkmanager 安装 NDK/build-tools 会解压后移动失败，留下 1KB 空目录 | 直接下载官方 zip 用 bsdtar 解压，手工落到 `ndk/28.2.13676358`、`build-tools/35.0.0` |
| Flutter 3.47 构建 `:app:compileFlutterBuildRelease` 报 `Unable to determine engine version` | 构建时设 `FLUTTER_PREBUILT_ENGINE_VERSION=<bin/internal/engine.version>`，跳过 PowerShell 探测 |
| 工程路径含空格（`E:\Project Files\...`），Flutter native assets 的 hook 命令未加引号，`objective_c` 编译报 `'E:\Project' 不是内部或外部命令` | 用 `subst P: "E:\Project Files\cyanweather"` 映射无空格盘符，从 `P:\flutter`、`P:\webf` 构建 |
| Kotlin 增量缓存跨盘（Pub cache 在 C:、工程在 P:）报 different roots | 仅告警，不影响产物；如需消除可加 `kotlin.incremental=false` |
| 插件子工程默认要 build-tools 35 | 已安装完整 35.0.0；flutter app 显式 `buildToolsVersion = "36.0.0"` |

Flutter/WebF 构建命令（PowerShell）：

```powershell
subst P: "E:\Project Files\cyanweather"
$env:JAVA_HOME = "E:\Program Files\AndroidStudio\jbr"
$env:FLUTTER_PREBUILT_ENGINE_VERSION = "5d531788691ec3404cac0cee66ead4007b177363"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
cd P:\flutter; E:\Project Files\cyanweather\flutter347\flutter\bin\flutter.bat build apk --release
cd P:\webf;    ..\flutter347\flutter\bin\flutter.bat build apk --release --no-pub
```

### 7.4 产物

`dist/` 下三个 APK，`versionName 1.2.2 / versionCode 13`，同一 release 签名（SHA-256 `4575a501…d106e2eb`），可并存安装：

- `cyanweather-v1.2.2-release.apk`（native，7.3 MB）
- `cyanweather-flutter-experimental-v1.2.2-release.apk`（53 MB）
- `cyanweather-webf-experimental-v1.2.2-release.apk`（85 MB）

### 7.5 真机验证与 Flutter 启动修复

- native / WebF 首屏正常；WebF 的 SVG 图标渲染正常；native 逐时卡夜图标（月亮）正常。
- Flutter 首屏全黑：`main()` 在 `await SharedPreferences.getInstance()` 后才 `runApp`，平台通道不返回时永远没有首帧。已改为 `runApp(_Boot)` + 异步读设置 + 6 秒超时，超时/异常显示可重试错误页（`flutter/lib/main.dart`）。
- 体积对照：native 7.3 MB；Flutter universal 52.4 MB、arm64 分包 18.7 MB；WebF universal 84.7 MB。WebF 不省体积，反而最大。

### 7.6 WebF 版弃用（2026-10-21）

**决定**：WebF 标记为弃用，代码与目录保留，但不再构建、不再随 Release 发布 APK。跨平台版本统一收敛到 Flutter。

依据：WebF 全量 84.7 MB（Flutter 52.4 MB / arm64 18.7 MB / native 7.3 MB），体积最大；且 0.24 在 `display:none`、ripple、媒体查询上存在引擎级限制，多维护一套 HTML/CSS/JS 实现不划算。

改动清单：

| 文件 | 改动 |
|---|---|
| `.github/workflows/release.yml` | 删除 Build WebF 步骤与 webf APK 收集；只发 native + Flutter |
| `README.md` | 版本表标记「已弃用」、下载表移除 WebF、构建章节改为弃用说明、目录树与技术栈同步 |
| `webf/README.md` | 顶部加弃用横幅与原因 |
| `docs/design-tokens-parity.md` | 顶部注明 webf 列仅作历史对照 |
| `tools/build_weather_icons.py` | 不再生成 webf 图标（PNG/SVG），只出 native VD 与 Flutter SVG；qweather 安装不再依赖 Edge |
| `dist/` | 已构建的 WebF APK 移至 `webf/archive/`，不再作为发布产物 |

恢复方式：在 workflow 加回 `Build WebF APK` 与收集行，并在图标脚本中恢复 `WEBF_PNG` / `WEBF_SVG` 输出即可。

### 7.7 Flutter 启动黑屏根因与修复（2026-10-21）

**现象**：Flutter release 包启动全黑；加入启动兜底页后，错误页暴露出：

```
PlatformException(java.lang.NoSuchMethodError:
no non-static method
"Lio/flutter/plugins/sharedpreferences/SharedPreferencesApiRegistrar;.getAll(
 Ljava/lang/String;Ljava/util/List;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;")
```

**根因**：`shared_preferences_android 2.5.1` 使用 JNIgen（dartjni）绑定，Dart 侧按 Java 原名/原签名通过 JNI 查找方法。Flutter release 的 R8 full mode 会：

1. 把 `SharedPreferencesApiRegistrar.getAll` 签名里的 `kotlin.coroutines.Continuation` repackage 成 `e1.c`，描述符被改写 → `NoSuchMethodError`；
2. 裁掉只在 JNI 侧使用的 `CoroutineSingletons`、`kotlin.Result` → `ClassNotFoundException`。

逐条加 keep（Registrar → Continuation → intrinsics）只是打地鼠，仍会冒出新的被裁类。

**最终处理**：Flutter 端 release 关闭 R8：

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled false
        shrinkResources false
    }
}
```

APK 由 52.4 MB 增至 55.9 MB（+3.5 MB），冷启动正常进入首页。`proguard-rules.pro` 保留，若以后重开 minify 必须引用并做冷启动回归。

同时保留两项防御：

- `main.dart` 启动兜底：先出首帧，再异步读设置（6 秒超时，错误页可重试），避免平台异常时再次全黑；
- 启动窗口固定品牌浅色（`values-night` 也强制 Light），暗色模式不再出现黑色启动页。

**验证**：真机（25102RKBEC / HyperOS）安装 `1.2.6+17`，冷启动进入首页，SVG 天气图标、预警、温度卡均正常。

### 7.8 信息卡右对齐与版本同步（2026-10-21）

**问题**：Flutter 空气质量卡的值列用 `CrossAxisAlignment.start`，胶囊「良 52」与下方 PM2.5/PM10 不在同一右边界，视觉上错位；`_pill` 字号固定 24（未乘字号档位），大字号下胶囊明显小于其他数值。

**修复**：

- 空气质量卡值列改为 `CrossAxisAlignment.end`，胶囊、PM2.5、PM10 统一右对齐（与 native `InfoCard` 的 `Alignment.End` 一致）。
- `_pill(text, color, [fs])` 增加字号参数，胶囊字号/内边距随 `_fs` 缩放；空气质量与紫外线两处调用同步传入。
- native 侧布局本就右对齐，无需改动；补齐版本同步：`app/build.gradle.kts` → `1.2.6 (17)`，与 Flutter 一致。

**验证**：真机同屏对比 native 与 Flutter 的空气质量/紫外线卡，胶囊与明细右边界一致；两端均安装 `1.2.6+17`。

### 7.9 信息卡布局重排（2026-10-21）

按使用反馈调整湿度/风力/空气质量/紫外线四张卡：

- **统一两栏**：左侧「参数名 + 参数值」上下排，右侧只放程度胶囊；四卡 `minHeight 102dp` + 值区 `minHeight 44dp`，高度一致。
- **风力**：`东北风 5级 5.4m/s`，去掉原来包住风速的括号。
- **湿度**：补程度（干燥/舒适/潮湿/闷湿），阈值 30/60/80。
- **风力程度**：微风/适中/较强/强，优先按风力等级，等级缺失时按 m/s 折算。
- **空气质量**：左侧 `PM2.5 35 · PM10 42` 一行，右侧「良 53」；不再分两行 PM 明细。
- **紫外线**：`中等（5）` 拆成左侧数值 `5`、右侧程度 `中等`；Open-Meteo 路径补数值（原来只有等级文本）。
- 程度胶囊字号 24→26，更醒目。

Flutter 侧因中文字体更宽，程度胶囊放在固定 88dp 列内并用 `FittedBox.scaleDown` 缩放；PM 行 12.5sp、风力值 14sp，保证 `PM2.5 35·PM10 42` 与 `东北风 5级 5.4m/s` 都能单行显示。同时在 `MaterialApp.builder` 里关闭系统 textScaler，字号只由 App 内档位控制，避免二次放大。native 保持 15sp + ` · `。

### 7.10 卡片两行化、胶囊统一、小米源（2026-10-21 下午）

- 卡片高度 102→120dp，值区 44→62dp，风力和空气质量允许两行：
  - 风力：`东北风 4级` + 换行 `5.6m/s`（仍不带括号）。
  - 空气质量：`PM2.5 35` + 换行 `PM10 42`，标签固定宽度（native 76dp / Flutter 58×fontScale），数值左边界对齐。
- 胶囊统一：Flutter 去掉 `FittedBox.scaleDown`，程度列固定 118dp，胶囊字号固定 26、`softWrap:false`。此前「舒适/较强/良 53」会被缩放到不同字号，特大字体下还会竖排，属同一问题。native 继续用 `fst(26)`。
- 小米数据源接入 Flutter：
  - `ApiService.fetchXiaomi()`：先走 `location/city/search` 拿小米自己的 `weathercn:101xxxxxx`（NMC 站号不通用），再请求 `wtr-v3/weather/all`；
  - 解析当前/逐时/15 日/昨日/AQI/预警/紫外线，风速 km/h → m/s + 蒲福风级；
  - 设置页新增「小米天气」多选项，聚合权重 0.7（与 native 一致）；
  - native 的「设备本地 ContentProvider」未移植，Flutter 走网络接口，MIUI 上数据同源。
- 关于动态背景：Flutter 的 `_weatherGradient` 与 native 使用同一组色值（晴 #FFF6DF→#E2EFFB、雨 #E9EFF7→#D8E4F1 等），按 6–18 点判昼夜。截图里 Flutter 偏蓝是因为多源聚合把 condition 聚成了「多云」；只启用小米/气象局且为晴时，背景会切成暖黄。容器已补 `width/height: infinity` 保证整屏铺满。

### 7.11 程度阈值校正（2026-10-21）

反馈「紫外线 6 显示高」「湿度 60% 显示潮湿」不合理，按国内常用口径校正：

| 指标 | 旧阈值 | 新阈值 |
|---|---|---|
| 紫外线 | 0–2 弱 / 3–5 中等 / 6–7 高 / 8–10 很高 / 11+ 极高（WHO 文案） | 0–2 弱 / 3–6 中等 / 7–9 强 / 10–12 很强 / 13+ 极强 |
| 湿度 | <30 干燥 / 30–59 舒适 / 60–79 潮湿 / 80+ 闷湿 | <40 干燥 / 40–64 舒适 / 65–79 潮湿 / 80+ 闷湿 |

- 紫外线 6 → 中等，7 起才是强；湿度 60% → 舒适，65% 起才算潮湿。
- 同步修改：shared `uvLevelText`、native `humidityLevel` / `uvLevelText` / `uvLevelColor`、Flutter `_humidityLevel` / `_uvLevelText` / `_uvColor`、Open-Meteo `_uvLevel` 文案。

### 7.12 胶囊字号跟随字号档位（2026-10-21）

- 现象：特大字号下 Flutter 程度胶囊明显小于 native。
- 原因：为规避竖排，上一版把 Flutter 胶囊字号写死 26、程度列固定 118dp；native 是 `fst(26)`，会随 LocalFontScale（1.6）放大到 41.6sp。
- 修复：Flutter 恢复 `_pill(..., _fs)`，去掉固定 118dp 程度列，改由 Row 的 `Expanded` 让位；保留 `maxLines:1 + softWrap:false` 防竖排。现在 1.6 档下胶囊字号与 native 一致。

### 7.13 小米源勾选不生效（2026-10-21）

- 现象：设置里勾选「小米天气」后，首页数据没有变化。
- 原因：`HomeScreen._loadPrefs()` 读取 `weatherSources` 时有一层白名单过滤，只允许 `nmc/openmeteo/caiyun/qweather`，**漏了 `xiaomi`**。设置页自己持有完整列表所以勾选框正常显示，但返回首页重新加载时小米被过滤掉，`_fetchSource('xiaomi')` 从未执行。
- 修复：白名单补上 `xiaomi`。设置页、聚合权重、网络解析此前都已就绪。
- 验证：勾选小米后重启/返回首页，`bySource` 应包含 xiaomi，聚合温度/AQI 会向小米值靠拢（宿松约 20℃、AQI 45）。
