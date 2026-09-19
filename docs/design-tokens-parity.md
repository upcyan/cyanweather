# CyanWeather 设计令牌与三端对齐台账

> 基准端:**native(app/, Kotlin + Compose)**。WebF 与 Flutter 向 native 看齐。
> 本文档是三端共享的唯一视觉口径;修改任一令牌须三端同步并在本表登记。

## 1. 设计令牌(Design Tokens)

### 1.1 颜色

| 令牌 | 值 | 用途 | native(CyanWeatherTheme.kt `CyanTokens`) | webf(styles.css `:root`) | flutter |
|---|---|---|---|---|---|
| primary/accent | `#0B6BCB` | 主色、强调、链接 | `CyanTokens.Primary` → `lightColorScheme(primary)` | `--accent` | 硬编码 `0xFF0B6BCB` |
| background | `#F5F9FF` | 页面背景 | `CyanTokens.Background` → `background` | `--bg` | `Scaffold.backgroundColor` |
| surface/card | `#FFFFFF` | 卡片底 | `CyanTokens.Surface` → `surface` | `--card` | Card 默认 |
| surfaceVariant/accent-soft | `#E3EDF9` | 生活指数瓷砖底、箭头按钮底 | `CyanTokens.SurfaceVariant` → `surfaceVariant` | `--accent-soft` | `_lifeTile` `0xFFE3EDF9` |
| text/onBackground | `#111111` | 主文本 | `CyanTokens.OnBackground` | `--text` | 默认 |
| muted/onSurfaceVariant | `#333333` | 次级文本/图标 | `CyanTokens.OnSurfaceVariant` | `--muted` | 图标 tint |
| soft | `#666666` | 标签、说明文字 | 直接硬编码(历史上沿) | `--soft` | `0xFF666666` |
| high-red | `#C62828` | 最高温、error | `CyanTokens.HighRed` → `error` | `--high-red` | `0xFFC62828` |
| low-blue | `#1565C0` | 最低温 | `CyanTokens.LowBlue` | `--low-blue` | `0xFF1565C0` |
| feel-teal | `#00897B` | 体感温度 | `CyanTokens.FeelTeal` | `--feel-teal` | `0xFF00897B` |
| rain-tip | `#E3F2FD` | 降雨提醒卡/分钟级降水卡 | `CyanTokens.RainTip` | 内联 `#e3f2fd` | `0xFFE3F2FD` |
| warn-bg / warn-text | `#FFEBEE` / `#B71C1C` | 气象预警横幅 | `CyanTokens.WarnBg/WarnText` | `.warn-card` | `0xFFFFEBEE`/`0xFFB71C1C` |
| location-notice | `#FFF3CD` / `#7A5600` | 定位提示卡 | 硬编码(同 webf/flutter) | `.notice-card` | `0xFFFFF3CD` |

### 1.2 圆角(Shapes 三级)

| 层级 | 值 | 用途 |
|---|---|---|
| small | 12dp | 生活指数瓷砖、小时卡 |
| medium | 16dp | 常规卡片(M3 Card 默认取 medium) |
| large | 20dp | 对话框、BigButton(16→统一 20 可选) |

- native:`CyanWeatherTheme.kt` `CyanShapes`(`small=12 / medium=16 / large=20`)。
- webf:`.card { border-radius: 16px }`、`.life-tile { border-radius: 12px }`。
- flutter:卡片默认 `RoundedRectangleBorder(radius: 12)`,`_lifeTile` 12。

### 1.3 字号与缩放档位

| 档位 | 缩放 | native(fst 基准 sp) | flutter(`_fs`/`_fontScale`) | webf(html font-size) |
|---|---|---|---|---|
| standard | 1.0 | `fst(24)` 等基准 | ×1.0 | 16px |
| large(默认) | 1.3 | ×1.3 | ×1.3 | 21px |
| xlarge | 1.6 | ×1.6 | ×1.6 | 26px |

### 1.4 间距与布局

| 令牌 | 值 | 三端一致 |
|---|---|---|
| 页面水平留白 | 16dp/px | ✅ |
| 卡片内边距 | 12-20dp | ✅(逐卡对齐) |
| 瓷砖间距 | 10dp | ✅ |
| 宽屏限宽 | 560dp(native)> 600dp 判定 | webf 用 `max-width: 35em` 等效;flutter `560.0` 同判定 |

## 2. 三端对齐台账(逐组件)

状态:✅ 已对齐 / ⚠️ 已知差异(有降级) / ⬜ 待处理

| 组件/页面 | native | webf | flutter | 状态与备注 |
|---|---|---|---|---|
| 顶栏(设置/城市+时间/刷新) | ✅ | ✅ | ✅ | 三端一致;flutter 城市点击换城 |
| 主天气卡(图标+温度+体感) | ✅ | ✅ | ✅ | 图标几何三端复刻 |
| 最高/最低/体感 StatCol | ✅ | ✅ | ✅ | 红蓝青配色一致 |
| 日出日落卡 | ✅ | ✅ | ✅ | |
| 湿度/风力/空气质量/紫外线信息卡 | ✅ | ✅ | ✅ | PM2.5/PM10 明细、风速 m/s 三端已同步 |
| 生活指数四宫格 | ✅ | ✅ | ✅ | 文案阈值逐字一致(WeatherIndex.kt 为准) |
| 降雨提醒卡(→趋势页) | ✅ | ✅ | ✅ | 全源可用,点击滚动/跳转 |
| 逐小时卡(日期+时辰+图标+概率) | ✅ | ✅(PNG 图标) | ✅(WeatherIcon widget) | |
| 逐小时左右渐变箭头 | ✅ 渐变遮罩+圆钮 | ✅ 同 | ✅ 滚动原生 | ⚠️ webf 箭头为 CSS 渐变,无触感回弹(引擎限制) |
| 多日预报(今天/明天/后天+星期) | ✅ | ✅ | ✅ | 高低温红蓝一致 |
| 昨日天气卡(含 24h 实况) | ✅ | ✅ | ✅ | |
| 气象预警横幅 | ✅ | ✅ | ✅ | |
| 分钟级降水卡(彩云) | ✅ | ✅ | ✅ | |
| 设置页(源/字号/刷新/定位/更新) | ✅ | ✅ | ✅ | 字号三档口径一致 |
| 城市选择(📍定位+省市级联+搜索) | ✅ | ✅ | ✅ | NMC 级联+全量搜索 |
| 降雨趋势页(24 根柱) | ✅ | ✅ | ✅ | |
| 更新弹窗/下载进度 | ✅ | ✅ | ⚠️ | ⚠️ flutter 实验版无 DownloadManager,弹"去 GitHub 下载"(降级方案,引擎限制) |
| 宽屏自适应 | ✅ 560dp 限宽 | ✅ 35em 限宽 | ✅ 560 限宽 | >600 判定一致 |
| 数据源脚注/置信度 | ✅ | ✅ | ✅ | |

## 3. 交互状态对齐

| 状态 | native | webf | flutter |
|---|---|---|---|
| 刷新中 | 全屏半透明遮罩+进度 | 同 | 同 |
| 加载 | 居中大进度+文案 | 同 | 同 |
| 错误全屏态 | 文案+「重新获取」 | 同 | 同 |
| 空数据 | 逐时/昨日卡隐藏 | 同 | 同 |
| 点击反馈 | M3 ripple | `:active` 背景变化(降级) | InkWell ripple |

⚠️ WebF 0.24 无 ripple 引擎能力 → 降级为 `:active` 高亮;已登记,属可接受差异。

## 4. 渲染差异降级方案(逐项)

| # | 差异项 | 受限端 | 原因 | 降级方案 | 状态 |
|---|---|---|---|---|---|
| 1 | Canvas 天气图标 | webf | WebF 无独立 Canvas 动画能力 | 用同几何/配色的 PNG 静态图标(meteocon),图标语义一致 | ✅ 已定 |
| 2 | 点击涟漪 | webf | 无 ripple 合成器 | `:active` 背景高亮 | ✅ 已定 |
| 3 | display:none 切换 | webf | 0.24 已知缺陷(README 记载) | 「摘除/置空=隐藏、重挂=显示」模型 | ✅ 已定 |
| 4 | 更新应用内下载 | flutter | 实验版无平台通道 | 更新弹窗改跳转浏览器 | ✅ 已定 |
| 5 | 媒体查询 | webf | CSS 支持不完整 | `max-width+margin:auto` 无条件生效,等效限宽 | ✅ 已定 |
| 6 | 触感回弹/动效曲线 | webf | 滚动物理引擎差异 | 原生滚动,无自定义曲线 | ✅ 已定 |
| 7 | 字体渲染 | 三端 | 平台字体栈不同 | 统一字体族声明(HarmonyOS Sans/PingFang/MiSans 回退链) | ✅ 已定 |

## 5. 变更与回滚

- 本次 UI 对齐改动以独立 commit 提交(见 git log:`feat: Flutter/WebF 实验版界面与 native 版对齐`、后续 native 美化 commit)。
- 回滚:`git log --oneline -- app/src/main/java/com/cyanweather/app/ui webf flutter` 找到改动前 commit,`git revert <hash>`(或 `git checkout <hash> -- <path>`),再次构建即可恢复。
- 验证:任何回滚后跑 32 个 JUnit 测试(方法见 `.openclaw/tmp/ktest/`)与 `node --check webf/assets/web/app.js`。
