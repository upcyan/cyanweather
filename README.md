# 晴暖天气（CyanWeather）

一款面向老年人的 Android 天气应用：大字体、简洁界面、操作直观。

## 功能

- 实时天气：温度、体感、湿度、风向风力、空气质量（AQI）、日出日落
- 逐小时天气：过去24小时逐时实况（气象局）/ 未来48小时逐时预报（彩云）
- 多日预报：7天预报（气象局）/ 3天预报（彩云）
- 昨日天气回顾（仅气象局数据源）
- 气象预警提示（仅气象局数据源）
- 彩云分钟级降水提醒（开启彩云数据源时）
- 30分钟自动刷新，可关闭
- 手动切换城市（省级列表选择）或使用 GPS 定位
- 字号三档可调：标准 / 大 / 特大（默认「大」）

## 数据源

| 数据 | 中央气象台（NMC，默认，无需密钥） | 彩云天气（需免费 Token） |
| --- | --- | --- |
| 实时天气 | 有 | 有 |
| 逐小时 | 过去24小时实况 | 未来48小时预报 |
| 多日预报 | 7天 | 3天 |
| 昨日天气 | 有 | 无 |
| 预警 / AQI | 有 | 无 |
| 分钟级降水 | 无 | 有 |

- 气象局数据来自 `nmc.cn` 公开接口，无需注册。
- 彩云数据需在 [彩云天气开发者平台](https://dashboard.caiyunapp.com) 免费申请 Token，在「设置 → 彩云 Token」中填写后使用。

## 构建

环境要求：JDK 17、Android SDK（platform 34）、网络可访问镜像仓库（项目已配置阿里云镜像）。

```bash
# 使用本地 Gradle 构建（wrapper 已配置腾讯镜像）
gradle wrapper --gradle-version 8.9
gradle assembleDebug
```

输出：`app/build/outputs/apk/debug/app-debug.apk`

首次构建需联网下载依赖与 Android 构建工具，耗时较长。

## 目录结构

- `app/src/main/java/com/cyanweather/app/`
  - `MainActivity.kt`：入口，定位权限，屏幕切换
  - `model/`：数据模型（统一模型 + 两源模型）
  - `data/`：网络请求、NMC/彩云解析映射、设置与缓存仓库
  - `location/`：GPS 定位
  - `ui/`：主题字体、Canvas 天气图标、主页/设置/城市选择、ViewModel