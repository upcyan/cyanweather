# 晴暖天气（CyanWeather）

一款面向长辈的天气应用：大字体、简洁界面、操作直观。一个仓库包含四个版本：

| 目录 | 技术 | 状态 |
|------|------|------|
| `app` | Kotlin + Jetpack Compose（原生） | ✅ 主推版本 |
| `shared` + `harmony` | KMP 共享模块 + ArkTS（鸿蒙 NEXT） | 🚧 移植中 |
| `flutter` | Flutter | ⚗️ 实验版 |
| `capacitor` | Capacitor (WebView) | ⚗️ 实验版 |

## 下载安装

前往 [GitHub Releases](https://github.com/upcyan/cyanweather/releases) 下载：

| 文件 | 说明 |
|------|------|
| `cyanweather-vX.Y-release.apk` | 原生版（推荐） |
| `cyanweather-flutter-experimental-vX.Y-release.apk` | Flutter 实验版 |
| `cyanweather-capacitor-experimental-vX.Y-release.apk` | Capacitor 实验版 |

三个版本使用同一 release 签名。

## 功能

- **实时天气**：温度、体感、湿度、风向风力、空气质量（AQI）、紫外线强度、日出日落
- **逐时预报**：未来48小时逐时天气（Open-Meteo / 彩云 / 气象局过去24小时实况）
- **多日预报**：15天预报（Open-Meteo）/ 7天（气象局）/ 可扩展更多天（彩云多次请求叠加）
- **昨日天气**：昨日温度回顾（气象局 / 彩云开启扩展时 / Open-Meteo `past_days=1`）
- **分钟级降水**：降雨趋势预报，精确到分钟（彩云 / Open-Meteo 逐时降水概率）
- **气象预警提示**（气象局 / 彩云数据源）
- **GPS 定位自动选城**：定位后按 省→市→(县) 匹配气象站，显示实际所在区县名
- **城市选择**：全国省→市层级选择，支持全局搜索
- **自动刷新**：可选间隔（关闭 / 每次进入App / 10/30/60分钟 / 6/12/24小时）
- **自动检查更新**：进入App自动检查GitHub Release新版本，支持下载安装
- **扩展多日预报**（可选）：多次请求叠加突破彩云免费版3天限制，最多16天
- **字号三档**：标准 / 大（推荐）/ 特大

## 数据源

| 数据 | 中央气象台 | Open-Meteo | 彩云天气 |
|------|-----------|------------|----------|
| 默认 | ✓（无需密钥） | ✓（无需密钥） | 需 Token/AppKey |
| 实时天气 | ✓ | ✓ | ✓ |
| 逐时预报 | 过去24h实况 | 未来48h | 未来48h |
| 多日预报 | 7天 | 15天 | 3天（可扩展） |
| 昨日天气 | ✓ | ✓ | ✓（需开启扩展） |
| 分钟级降水 | ✗ | 逐时降水概率 | ✓（分钟级） |
| 预警 | ✓ | ✗ | ✓ |
| AQI | ✓ | ✓ | ✓ |
| 紫外线 | ✗ | ✓ | ✗ |

### 彩云天气接入

支持两种认证方式（在「设置 → 彩云天气」中选择）：
- **V1 Token**：免费版，3天预报，Token在URL中
- **V3 AppKey + AppSecret**：开放平台凭证，签名鉴权，更安全

凭证在 [彩云天气开发者平台](https://platform.caiyunapp.com) 获取。

### 扩展多日预报（可选）

开启后通过多次请求叠加数据，突破免费版单次3天限制：
- 支持选择预报天数（3/5/7/10/15天）
- 可选开启昨日天气获取
- 自动计算并显示所需请求次数

## 构建

环境要求：JDK 17、Android SDK（platform 36）。

### 原生版（app/）

```bash
gradle assembleDebug    # 调试包
gradle assembleRelease  # 发布包
```

输出：`app/build/outputs/apk/{debug,release}/app-release.apk`

### Flutter 版（flutter/）

```bash
cd flutter
flutter build apk --release
```

输出：`flutter/build/app/outputs/flutter-apk/app-release.apk`

### Capacitor 版（capacitor/）

```bash
cd capacitor
npm ci
cd android && ./gradlew assembleRelease
```

输出：`capacitor/android/app/build/outputs/apk/release/app-release.apk`

> 注意：Capacitor 版 WebView 内直接请求外部 API 受 CORS 限制，部分接口可能不可用，故标记为 experimental。

## Release 签名

三个版本共用同一签名证书：

```
keystore/
└── release-key.jks     # 签名文件（不入库）

keystore.properties     # 密码配置（不入库），格式：
# storeFile=keystore/release-key.jks
# storePassword=xxxxxx
# keyAlias=cyanweather
# keyPassword=xxxxxx
```

- `keystore/` 与 `keystore.properties` 已加入 `.gitignore`，请自行备份
- 各端 Gradle 配置读取仓库根目录的 `keystore.properties`；未找到时原生版回退读取环境变量 `KEYSTORE_PASSWORD`
- 证书 SHA-256 示例可在 Release 页面核对

## GitHub Actions 自动构建

推送 `v*` 标签时自动构建三个 Release APK 并发布到 GitHub Releases：

```bash
git tag v1.2
git push origin v1.2
```

需在仓库 Settings → Secrets and variables → Actions 中配置：

| Secret | 说明 |
|--------|------|
| `KEYSTORE_BASE64` | `release-key.jks` 的 base64 内容（`base64 -w0 release-key.jks`） |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEYSTORE_KEY_ALIAS` | key 别名（如 `cyanweather`） |
| `KEYSTORE_KEY_PASSWORD` | key 密码 |

## 自动更新

App 内置检查更新功能（原生版）：
- 进入首页自动检查 GitHub Release（可在设置中关闭）
- 发现新版本弹窗显示版本号 + 更新日志
- 点击「立即更新」下载 APK 并安装
- 需要 Android 8+ 的 `REQUEST_INSTALL_PACKAGES` 权限

## 目录结构

```
├── app/                          # 原生版（主推）
│   └── src/main/java/com/cyanweather/app/
│       ├── MainActivity.kt       # 入口，权限处理，屏幕切换
│       ├── data/                 # 网络、API解析、设置存储
│       ├── location/             # GPS 定位
│       ├── ui/                   # 主页/设置/城市选择/降雨趋势/更新弹窗
│       └── update/               # 检查更新、下载安装
├── shared/                       # KMP 共享模块（原生与鸿蒙共用）
│   └── src/commonMain/kotlin/com/cyanweather/shared/
│       ├── data/                 # NMC / Open-Meteo / 彩云 API 与解析
│       └── model/                # 数据模型
├── harmony/                      # 鸿蒙 NEXT 移植版
├── flutter/                      # Flutter 版（experimental）
│   └── lib/                      # screens / services / widgets
├── capacitor/                    # Capacitor 版（experimental）
│   ├── www/                      # Web 资源（js/css/icons）
│   └── android/                  # Android 壳工程
├── keystore/                     # 签名文件（gitignore）
└── .github/workflows/release.yml # CI 三端打包发布
```

## 技术栈

- Kotlin + Jetpack Compose + Material 3（原生版）
- Kotlin Multiplatform 共享数据层（原生 / 鸿蒙）
- Kotlin Serialization、OkHttp3、DataStore Preferences
- Flutter / Capacitor（实验版）
- Canvas 自绘天气图标
- GitHub Actions CI/CD
