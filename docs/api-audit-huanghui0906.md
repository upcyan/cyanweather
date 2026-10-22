# huanghui0906/API 可用性与准确度抽检

- 抽检时间：2026-10-21 15:45–15:58（GMT+8）
- 抽检网络：中国安徽电信/联通出口
- 仓库：https://github.com/huanghui0906/API
- 方法：按仓库 Markdown 文档原样拼 URL，记录 HTTP 状态、耗时、响应体；天气类再与 Open-Meteo 同时刻实况交叉比对（宿松县 30.107N, 116.23E）

## 一、仓库本身

| 项目 | 结论 |
|---|---|
| 性质 | 第三方 API 文档收集库，不是官方 SDK，也没有服务端代码 |
| 最后更新 | README 2019-12-13，多数文档停留在 2019-04-10 |
| 许可 | 无开源许可证；README 明确“仅供学习，禁止商业使用” |
| 风险 | 接口均为产品方私有接口，无 SLA、无配额承诺，随时可能改签名/封禁 |

## 二、天气类 API（重点）

| 接口 | 文档 URL | 实测 | 耗时 | 数据时间 | 结论 |
|---|---|---|---|---|---|
| 小米天气 | `https://weatherapi.market.xiaomi.com/wtr-v3/weather/all` | **200**，15.3 KB | 0.28 s | current 15:15，AQI 15:00 | 可用，字段完整（当前/15 日/逐时/昨日/AQI/预警/UV） |
| 魅族天气 | `http://aider.meizu.com/app/weather/listWeather?cityIds=101220606` | **200**，5.7 KB | 0.11 s | realtime 15:45，AQI 15:52 | 可用，7 日预报 + 预警，更新更快 |
| 中央天气（nineton） | `http://tj.nineton.cn/Heart/index/all?city=...` | **404**（nginx） | 0.27 s | — | 已下线 |
| OPPO 天气 | `http://i1.weather.oppomobile.com/chinaWeather/smChinaWeathersGz/...json.gz` | **404**（当前小时与 2017 历史路径均 404，根路径也 404） | 0.41 s | — | 已下线或路径整体迁移 |

### 同时刻实况交叉比对（宿松县）

| 指标 | 小米天气 | 魅族天气 | Open-Meteo | 差异判断 |
|---|---|---|---|---|
| 温度 | 20 ℃（15:15） | 19 ℃（15:45） | 21.1 ℃（15:45） | 最大差 2.1 ℃，属跨源正常范围 |
| 体感 | — | 12 ℃ | 18.2 ℃ | 魅族 `sendibleTemp` 明显偏低，需谨慎 |
| 湿度 | 65% | 67% | 54% | 小米/魅族接近，与模型源差 13% |
| 风向/风速 | 57°，18 km/h（约 3 级） | 东南风 6 级 | 60°，23.1 km/h（约 4 级） | 风力等级差异较大，魅族偏高 |
| AQI | 45（15:00） | 52（15:52） | — | 差 7，均落在“良” |
| 今日高/低 | 23/14 ℃ | 23/14 ℃ | — | 完全一致 |
| 预警 | 大风蓝色 | 大风蓝色（同一条） | — | 一致 |

**准确度结论**

- 日高低温、天气现象、预警一致性最好；小米与魅族 15 日/7 日趋势可直接参考。
- 实况温度差 1–2 ℃、AQI 差 7、湿度差 13%，属于不同站点/模式源的正常离散，不能据此判定谁“更准”。
- 魅族体感 12 ℃（比气温低 7 ℃）与风速 6 级偏高，存在口径或站点差异；若要采用，需连续多天与气象局站点对齐后再定权重。
- 小米 15:15 的实况在 15:56 抽检时已滞后约 40 分钟；魅族 15:45 实况、15:52 AQI 更新更及时。
- 两源均无官方 SLA，且小米接口依赖固定 `appKey/sign`，属于非公开接口，存在随时失效风险。

## 三、其他类别抽检（代表性样本）

| 服务 | 文档端点 | 实测 | 结论 |
|---|---|---|---|
| 豆瓣电影 | `api.douban.com/v2/movie/in_theaters` | **400**，`apikey_is_blocked` | 文档里的公共 apikey 已被封，接口不可用 |
| 开眼 Eyepetizer | `baobab.kaiyanapp.com/api/v4/tabs/selected` | **200**，66 KB，首条为当日 09:00 | 仍可用，内容新鲜 |
| 「一个」ONE | `v3.wufazhuce.com:8000/api/hp/idlist/0` | **200**，88 B，返回 ID 列表 | 仍可用 |
| 12306 | `kyfw.12306.cn/otn/leftTicket/queryZ` | **200**，但返回 HTML 验证/风控页 | 文档的 JSON 流程已不可直接使用，需 Cookie/风控处理 |

其余文档（今日头条、内涵段子、图虫、一席、梨视频、快递、途牛等）未逐条实测；按仓库 2019 年的时效和上述样本判断，**大部分已失效或需要重新抓包更新**。

## 四、给晴暖天气的建议

1. **继续以中国气象局 + Open-Meteo 为主源**：一个有官方站点实况，一个有稳定全球模式，二者互补。
2. **小米天气保持“实验性”**：字段最全、可直接补 15 日/预警/AQI，但更新有 30–60 分钟滞后，且是非公开接口；继续放在可选源，权重 0.7。
3. **魅族天气可作为备选实况源**：更新快、预警准、日高低温与小米一致；但体感/风力口径需先校准，且县级查询返回的是“安庆市/宿松县”混合层级（`city=安庆市`、`region=宿松县`），接入前要确认站点归属。
4. **中央天气、OPPO 天气不要接入**：实测 404。
5. **不要使用仓库里的 2019 静态城市库**做新城市映射：小米应走 `location/city/search` 动态查询，魅族 ID 需单独校验。
6. **合规**：仓库无许可证且明确禁止商业使用；这些是产品方私有接口，正式发布前应评估协议与法律风险，不要把单一非官方源作为唯一数据来源。

## 五、复现命令

```bash
curl -s -m 15 -o /dev/null -w "%{http_code} %{time_total}\n" \
  "https://weatherapi.market.xiaomi.com/wtr-v3/weather/all?latitude=30.107&longitude=116.23&isLocated=true&locationKey=weathercn%3A101220606&days=15&appKey=weather20151024&sign=zUFJoAR2ZVrDy1vF3D07&isGlobal=false&locale=zh_cn"

curl -s -m 15 -o /dev/null -w "%{http_code} %{time_total}\n" \
  "http://aider.meizu.com/app/weather/listWeather?cityIds=101220606"

curl -s -m 15 -o /dev/null -w "%{http_code} %{time_total}\n" \
  "http://tj.nineton.cn/Heart/index/all?city=CHSH000000"
```
