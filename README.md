# 晴暖天气（CyanWeather）

给长辈用的天气 App：字大，界面简单。主推原生版，Flutter 出实验版，两者签名相同、可并存；WebF 版已弃用不再发布，鸿蒙版在移植。

## 下载

[Releases](https://github.com/upcyan/cyanweather/releases) 提供两个包：

- `cyanweather-vX.Y-release.apk` — 原生版（Kotlin + Compose），推荐
- `cyanweather-flutter-experimental-vX.Y-release.apk` — Flutter 实验版

## 功能

- 多数据源并发 + 加权聚合：中央气象台、Open-Meteo 默认启用且不需要密钥，彩云天气可选（填凭证）
- 实况、未来48小时逐时、最长15天多日、昨日回顾
- 分钟级降水和带伞提醒（彩云/气象台）、气象预警（彩云/气象台）
- 定位自动选城（省→市→区县匹配气象站），或手动选城市
- 字号三档，自动刷新间隔可选，App 内检查更新并直接下载安装

## 数据源

设置里勾选要用的来源，越靠上优先级越高；勾多个时并发取数、按权重聚合成一份结果。默认启用中国气象局 + Open-Meteo，开箱即用。

| 数据源 | 凭证 | 逐时 | 多日 | 特点 |
|--------|------|------|------|------|
| 中国气象局 | 不需要 | 过去24h实况 | 7天 | 官方国内数据，含预警、AQI |
| Open-Meteo | 不需要 | 未来48h | 15天 | 全球覆盖，含紫外线、AQI |
| 彩云天气 | Token 或 AppKey+Secret | 未来48h | 3天，可叠加扩展 | 分钟级降水、预警 |
| 和风天气 | API Host + Key | 24小时 | 7天 | 预警、官方多源数据 |
| 高德天气 | Key | ✗ | 4天 | 中国气象局数据，实况为主 |
| MET Norway | 不需要 | 48小时 | ✓ | 挪威气象局，全球覆盖 |
| 小米天气 | 不需要（实验性） | 48小时 | 15天 | 优先读小米系统天气，失败自动切下一源 |

凭证获取：

- **彩云天气**：[开放平台](https://platform.caiyunapp.com)申请。V1 直接填 Token；V3 填 AppKey + AppSecret。开「扩展多日预报」后按 3 天一批叠加请求，可选带上昨日
- **和风天气**：[dev.qweather.com](https://dev.qweather.com) 创建项目拿 Key，设置里填控制台分配的 API Host（形如 `abcxyz.qweatherapi.com`）和 Key
- **高德天气**：[console.amap.com](https://console.amap.com) 申请「Web 服务」类型 Key
- **MET Norway**：不用申请。其 CC BY 4.0 署名要求由 App 内置的可识别 User-Agent 承担

## 构建

JDK 17+、Android SDK（platform 36）、Flutter 3.47。

```bash
./gradlew assembleRelease                  # 原生版 → app/build/outputs/apk/release/
cd flutter && flutter build apk --release  # Flutter 版 → flutter/build/app/outputs/flutter-apk/
```

## 发布

推送 `v*` 标签触发 GitHub Actions，自动构建上面两个 APK 并发 Release。Actions 需要配四个 Secret：`KEYSTORE_BASE64`、`KEYSTORE_PASSWORD`、`KEYSTORE_KEY_ALIAS`、`KEYSTORE_KEY_PASSWORD`。

签名文件放仓库根 `keystore/release-key.jks`，密码写在 `keystore.properties`（均不入库，自行备份）。找不到配置文件时，原生版回退读环境变量 `KEYSTORE_PASSWORD`。
