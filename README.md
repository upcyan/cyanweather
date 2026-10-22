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

| 数据 | 中央气象台 | Open-Meteo | 彩云天气 |
|------|-----------|------------|----------|
| 凭证 | 不需要 | 不需要 | V1 Token 或 V3 AppKey+Secret |
| 逐时 | 过去24h实况 | 未来48h | 未来48h |
| 多日 | 7天 | 15天 | 3天，可叠加扩展 |
| 分钟级降水 | ✗ | 逐时概率 | ✓ |
| 预警 / AQI | ✓ / ✓ | ✗ / ✓ | ✓ / ✓ |

彩云凭证在[开放平台](https://platform.caiyunapp.com)申请；开扩展预报后按 3 天一批多次请求叠出更长预报，可选带上昨日。

## 构建

JDK 17+、Android SDK（platform 36）、Flutter 3.47。

```bash
./gradlew assembleRelease                  # 原生版 → app/build/outputs/apk/release/
cd flutter && flutter build apk --release  # Flutter 版 → flutter/build/app/outputs/flutter-apk/
```

## 发布

推送 `v*` 标签触发 GitHub Actions，自动构建上面两个 APK 并发 Release。Actions 需要配四个 Secret：`KEYSTORE_BASE64`、`KEYSTORE_PASSWORD`、`KEYSTORE_KEY_ALIAS`、`KEYSTORE_KEY_PASSWORD`。

签名文件放仓库根 `keystore/release-key.jks`，密码写在 `keystore.properties`（均不入库，自行备份）。找不到配置文件时，原生版回退读环境变量 `KEYSTORE_PASSWORD`。
