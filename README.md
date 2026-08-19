# 晴暖天气（CyanWeather）

一款面向长辈的 Android 天气应用：大字体、简洁界面、操作直观。

## 功能

- **实时天气**：温度、体感、湿度、风向风力、空气质量（AQI）、紫外线强度、日出日落
- **逐时预报**：未来48小时逐时天气（Open-Meteo / 彩云 / 气象局过去24小时实况）
- **多日预报**：15天预报（Open-Meteo）/ 7天（气象局）/ 可扩展更多天（彩云多次请求叠加）
- **昨日天气**：昨日温度回顾（气象局 / 彩云开启扩展时）
- **分钟级降水**：降雨趋势预报，精确到分钟（彩云 / Open-Meteo 逐时降水概率）
- **气象预警提示**（彩云数据源）
- **自动刷新**：可选间隔（关闭 / 每次进入App / 10/30/60分钟 / 6/12/24小时）
- **自动检查更新**：进入App自动检查GitHub Release新版本，支持下载安装
- **扩展多日预报**（可选）：多次请求叠加突破彩云免费版3天限制，最多16天
- **城市选择**：全国省→市→区县层级选择，支持全局搜索
- **GPS定位**：自动定位当前城市
- **字号三档**：标准 / 大（推荐）/ 特大

## 数据源

| 数据 | 中央气象局 | Open-Meteo | 彩云天气 |
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

环境要求：JDK 17、Android SDK（platform 36）、网络可访问镜像仓库。

```bash
# 本地构建（wrapper 已配置腾讯镜像）
gradle assembleDebug
```

输出：`app/build/outputs/apk/debug/app-debug.apk`

### Release 构建

```bash
gradle assembleRelease
```

Release APK 使用 `release-key.jks` 签名（已配置 signingConfig）。

### GitHub Actions 自动构建

推送 `v*` 标签时自动构建 Release APK 并发布到 GitHub Releases：

```bash
git tag v1.0.1
git push origin v1.0.1
```

## 自动更新

App 内置检查更新功能：
- 进入首页自动检查 GitHub Release（可在设置中关闭）
- 发现新版本弹窗显示版本号 + 更新日志
- 点击「立即更新」下载 APK 并安装
- 需要 Android 8+ 的 `REQUEST_INSTALL_PACKAGES` 权限

## 目录结构

- `app/src/main/java/com/cyanweather/app/`
  - `MainActivity.kt`：入口，权限处理，屏幕切换
  - `model/`：数据模型（NMC / 彩云 / Open-Meteo）
  - `data/`：网络请求、API解析、设置缓存、城市映射
  - `location/`：GPS定位（最优源选择）
  - `ui/`：主题字体、Canvas天气图标、主页/设置/城市选择/降雨趋势/更新弹窗
  - `update/`：检查更新、下载安装
- `app/src/main/java/com/cyanweather/app/data/AdminHierarchy.kt`：全国行政区划层级映射（自动生成）

## 技术栈

- Kotlin + Jetpack Compose
- Material 3
- Kotlin Serialization
- OkHttp3
- DataStore Preferences
- Canvas 自绘天气图标
- GitHub Actions CI/CD
