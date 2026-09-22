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
