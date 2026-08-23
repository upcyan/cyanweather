# 青色天气 WebF 版（cyanweather_webf）

使用 [WebF](https://openwebf.com)（HTML/CSS/JS 渲染于 Flutter）复刻原生 `app/`（Kotlin + Compose）版青色天气，目标：功能与界面与原生版完全一致。

## 功能

- **双数据源**
  - Open-Meteo：15 天预报 / 48h 逐时 / 降水概率 / 紫外线 / 美标 AQI
  - 中国气象局（中央气象台 NMC）：县区级站点、预警横幅、过去 24 小时实况、日转夜文案
- **定位**
  - 系统 `LocationManager`（NETWORK=WiFi/基站 优先，GPS 兜底）+ 最近位置缓存
  - 反向地理编码 → 省/市/县三级匹配气象站（繁体归一化 + 行政区后缀剥离）
  - 全新安装自动请求定位权限；无权限/超时有明确提示并回退上次位置
- **界面**（对齐 native HomeScreen）
  - 顶栏 ⚙️ 设置 / 城市名+更新时间 / 🔄 刷新
  - 主卡：Canvas 天气图标（复刻 WeatherIcon.kt 几何与配色）+ 温度 + 最高🔴/最低🔵/体感🟢
  - 日出日落卡、湿度/风力/空气质量/紫外线四联信息卡
  - 降雨提醒卡（12h 内有雨→带伞提示，点击滚动到 24 根柱状趋势图）
  - 48h 逐时卡片流、15 天多日列表（今天/明天/后天 + M月D日 周X + 高低红蓝）
  - 昨日天气卡（含过去 24h 实况温度横滑）
  - 气象预警红色横幅（NMC 源）
  - 错误全屏态 + 「重新获取」；刷新半透明遮罩
- **设置**（对齐 SettingsScreen）
  - 数据源切换（Open-Meteo / 中国气象局）、字号三档（标准/大/特大 = 1.0x/1.3x/1.6x）
  - 自动刷新：关闭 / 每次进入App(>30秒) / 10 / 30 / 60 分钟 / 6 / 12 / 24 小时
  - 定位开关、自动检查更新开关、手动检查更新、当前城市入口
- **更新**：GitHub Releases 版本比对 + 更新弹窗（跳转浏览器下载）

## 架构

```
Flutter (main.dart)
 ├─ GpsModule（webf 自定义模块 'GPS'，同步读取缓存）
 │    └─ MainActivity.kt（系统 LocationManager 后台解析 → files/gps_fix.json）
 └─ WebF Widget ← assets/web/{index.html, styles.css, app.js}
        ├─ 数据源请求：Open-Meteo API / nmc.cn REST
        ├─ 统一 WeatherData 模型渲染（对齐 shared/model）
        └─ Canvas 图标绘制（KIND_NORM 尺寸表 + IC 配色表）
```

> 为什么用「文件」而不是 MethodChannel 回传定位？WebF 控制器可能创建独立引擎执行
> 页面脚本，Activity 引擎上注册的通道在页面引擎中不可见；共享文件对所有引擎可见。

## 构建与安装

```bash
cd webf
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

首次启动会弹出定位授权；也可预先授权：

```bash
adb shell pm grant com.cyanweather.cyanweather_webf android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.cyanweather.cyanweather_webf android.permission.ACCESS_COARSE_LOCATION
```

## 与 native 的已知差异 / 路线图

- [ ] 彩云天气数据源（v1 Token / v3 签名、分钟级降水文本、扩展多日叠加）
- [ ] 全国省→市→区县级联城市选择器（NMC `/rest/province` 已就绪）
- [ ] 应用内更新下载安装闭环（当前跳转浏览器）
- [ ] WIND 图标弧线细节微调
