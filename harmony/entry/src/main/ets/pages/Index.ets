import { WeatherData, HourlyItem, DailyItem, YesterdayData } from '../model/WeatherData';
import { WeatherManager } from '../data/WeatherManager';
import { router } from '@kit.ArkUI';
import { SettingsStore } from '../data/SettingsStore';

@Entry
@Component
struct Index {
  @State weather: WeatherData | null = null;
  @State loading: boolean = true;
  @State error: string = '';
  @State isRefreshing: boolean = false;
  @State tempUnit: string = 'c';
  @State fontScale: number = 1.0;
  private scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    this.tempUnit = SettingsStore.getTempUnit();
    this.fontScale = SettingsStore.getFontScale();
    await this.loadData();
  }

  onPageShow(): void {
    this.tempUnit = SettingsStore.getTempUnit();
    this.fontScale = SettingsStore.getFontScale();
    if (this.weather !== null) {
      this.loadData();
    }
  }

  async loadData(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const lat: number = SettingsStore.getCityLat();
      const lon: number = SettingsStore.getCityLon();
      const name: string = SettingsStore.getCityName();
      this.weather = await WeatherManager.getWeather(lat, lon, name);
    } catch (e) {
      const err: Error = e as Error;
      this.error = err.message || '网络错误';
    } finally {
      this.loading = false;
      this.isRefreshing = false;
    }
  }

  async onRefreshAction(): Promise<void> {
    this.isRefreshing = true;
    await this.loadData();
  }

  tempStr(val: number | null): string {
    if (val === null) return '-';
    let temp: number = Math.round(val);
    if (this.tempUnit === 'f') {
      temp = Math.round(val * 9 / 5 + 32);
    }
    return '' + temp;
  }

  tempStrWithUnit(val: number | null): string {
    return this.tempStr(val) + (this.tempUnit === 'f' ? '\u00B0F' : '\u00B0');
  }

  fs(size: number): number {
    return Math.round(size * this.fontScale);
  }

  conditionIcon(condition: string): string {
    if (condition.includes('晴')) return '\u2600\uFE0F';
    if (condition.includes('多云') || condition.includes('阴')) return '\u26C5';
    if (condition.includes('雨')) return '\uD83C\uDF1B';
    if (condition.includes('雪')) return '\u2744\uFE0F';
    if (condition.includes('雾') || condition.includes('霾')) return '\uD83C\uDF01';
    return '\uD83C\uDF24\uFE0F';
  }

  dayLabel(index: number, dateStr: string): string {
    if (index === 0) return '今天';
    if (index === 1) return '明天';
    if (index === 2) return '后天';
    try {
      const parts: string[] = dateStr.split('-');
      if (parts.length >= 3) {
        const d: Date = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        const weekdays: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
        return weekdays[d.getDay()];
      }
    } catch (_) {}
    return dateStr.substring(5, 10);
  }

  combineDayNight(day: string, night: string): string {
    if (day === night) return day;
    return day + '转' + night;
  }

  hourLabel(timeStr: string): string {
    try {
      const parts: string[] = timeStr.split(' ');
      if (parts.length >= 2) {
        const h: string = parts[1].substring(0, 2);
        return h + '时';
      }
      const t: string = timeStr.split('T')[1] || '';
      if (t.length >= 2) {
        return t.substring(0, 2) + '时';
      }
    } catch (_) {}
    return timeStr;
  }

  tempBarWidth(low: number | null, high: number | null): string {
    if (low === null || high === null) return '50%';
    const range: number = high - low;
    if (range <= 0) return '50%';
    const pct: number = 30 + (range / 20) * 70;
    return Math.min(100, Math.max(30, pct)) + '%';
  }

  buildRainReminder(): string | null {
    if (!this.weather) return null;
    const upcoming: HourlyItem[] = this.weather.hourly.filter((h: HourlyItem) => h.isForecast).slice(0, 12);
    if (upcoming.length > 0) {
      const idx: number = upcoming.findIndex((h: HourlyItem) => h.condition.includes('雨') || h.condition.includes('雷'));
      if (idx >= 0) {
        return idx <= 1 ? '现在或很快有降雨，出门请带伞' : `预计约 ${idx} 小时后可能有降雨，出门请带伞`;
      }
    }
    const soon: boolean = this.weather.daily.slice(0, 3).some((d: DailyItem) =>
      (d.dayText + d.nightText).includes('雨') || (d.dayText + d.nightText).includes('雷'));
    return soon ? '近期可能有雨，请留意天气变化' : null;
  }

  @Builder
  InfoCard(icon: string, title: string, value: string) {
    Row() {
      Text(icon)
        .fontSize(this.fs(28)).margin({ right: 12 })
      Column() {
        Text(title)
          .fontSize(this.fs(18)).fontColor('#666666')
        Text(value)
          .fontSize(this.fs(24)).fontWeight(FontWeight.Medium).fontColor('#333333')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor('#F5F5F5').borderRadius(16)
    .margin({ top: 8, left: 16, right: 16 })
  }

  build() {
    Column() {
      // ===== 顶部栏 =====
      Row() {
        Text('\u2699\uFE0F')
          .fontSize(this.fs(28))
          .width(56).height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { router.pushUrl({ url: 'pages/SettingsPage' }); })

        Column() {
          Text(this.weather?.cityName || '加载中...')
            .fontSize(this.fs(30))
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.weather) {
            Text('更新于 ' + this.weather.updatedAt)
              .fontSize(this.fs(14))
              .fontColor('#999999')
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Text(this.isRefreshing ? '\u23F3' : '\uD83D\uDD04')
          .fontSize(this.fs(28))
          .width(56).height(56)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.onRefreshAction(); })
      }
      .width('100%').height(64)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#FFFFFF')

      // ===== 内容区 =====
      Scroll() {
        Column() {
          if (this.loading) {
            Column() {
              Text('加载中...')
                .fontSize(this.fs(24)).fontColor('#666666')
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center)
          } else if (this.error.length > 0) {
            Column() {
              Text('加载失败')
                .fontSize(this.fs(24)).fontColor('#E65100').margin({ bottom: 12 })
              Text(this.error)
                .fontSize(this.fs(18)).fontColor('#666666')
              Text('点击重试')
                .fontSize(this.fs(20)).fontColor('#1565C0')
                .margin({ top: 20 })
                .onClick(() => { this.loadData(); })
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center)
          } else if (this.weather) {
            // ===== 预警信号 =====
            if (this.weather.warning) {
              Row() {
                Text('\u26A0\uFE0F').fontSize(this.fs(24)).margin({ right: 8 })
                Text(this.weather.warning)
                  .fontSize(this.fs(20)).fontColor('#C62828').layoutWeight(1)
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%').padding(16)
              .backgroundColor('#FFEBEE').borderRadius(16)
              .margin({ top: 12, left: 16, right: 16 })
            }

            // ===== 主天气区 =====
            Row() {
              Column() {
                Text(this.conditionIcon(this.weather.condition))
                  .fontSize(this.fs(56))
                Text(this.weather.condition)
                  .fontSize(this.fs(22)).fontColor('#666666').margin({ top: 8 })
              }
              .alignItems(HorizontalAlign.Center)

              Text(this.tempStr(this.weather.temperature) + (this.tempUnit === 'f' ? '\u00B0F' : '\u00B0'))
                .fontSize(this.fs(64)).fontWeight(FontWeight.Bold).fontColor('#E65100')
                .margin({ left: 20 })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 16, bottom: 16 })
            .alignItems(VerticalAlign.Center)

            // ===== 最高/最低温度 =====
            Row() {
              Column() {
                Text('最高')
                  .fontSize(this.fs(22)).fontWeight(FontWeight.Medium).fontColor('#666666')
                Text(this.tempStrWithUnit(this.weather.todayHigh))
                  .fontSize(this.fs(30)).fontWeight(FontWeight.Bold).fontColor('#E65100').margin({ top: 4 })
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Center)

              Column() {
                Text('最低')
                  .fontSize(this.fs(22)).fontWeight(FontWeight.Medium).fontColor('#666666')
                Text(this.tempStrWithUnit(this.weather.todayLow))
                  .fontSize(this.fs(30)).fontWeight(FontWeight.Bold).fontColor('#1565C0').margin({ top: 4 })
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Center)
            }
            .width('100%').padding({ left: 16, right: 16, bottom: 16 })

            // ===== 体感温度 =====
            Row() {
              Text('体感温度')
                .fontSize(this.fs(22)).fontColor('#666666')
              Text(this.tempStrWithUnit(this.weather.feelsLike))
                .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 12 })
            }
            .width('100%').padding({ left: 20, right: 20, bottom: 16 })

            // ===== 日出日落 =====
            if (this.weather.sunrise || this.weather.sunset) {
              Row() {
                Column() {
                  Text('日出')
                    .fontSize(this.fs(22)).fontWeight(FontWeight.Medium).fontColor('#666666')
                  Text(this.weather.sunrise || '-')
                    .fontSize(this.fs(22)).fontColor('#F6A821').margin({ top: 4 })
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Center)

                Column() {
                  Text('日落')
                    .fontSize(this.fs(22)).fontWeight(FontWeight.Medium).fontColor('#666666')
                  Text(this.weather.sunset || '-')
                    .fontSize(this.fs(22)).fontColor('#5C6BC0').margin({ top: 4 })
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Center)
              }
              .width('100%').padding({ left: 16, right: 16, bottom: 16 })
            }

            // ===== 降雨提醒 =====
            if (this.buildRainReminder()) {
              Row() {
                Text('\uD83C\uDF02').fontSize(this.fs(22)).margin({ right: 8 })
                Text(this.buildRainReminder()!)
                  .fontSize(this.fs(22)).fontColor('#1565C0').layoutWeight(1)
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text('查看降雨趋势 \u203A')
                  .fontSize(this.fs(18)).fontColor('#1565C0')
                  .onClick(() => { router.pushUrl({ url: 'pages/RainForecastPage' }); })
              }
              .width('100%').padding(16)
              .backgroundColor('#E3F2FD').borderRadius(16)
              .border({ width: 1, color: '#90CAF9' })
              .margin({ top: 12, left: 16, right: 16 })
            }

            // ===== 逐时预报 =====
            Text(this.weather.hourlyLabel || '逐时预报')
              .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#333333')
              .margin({ top: 24, left: 16, bottom: 8 })

            Scroll(this.scroller) {
              Row() {
                ForEach(this.weather.hourly, (h: HourlyItem) => {
                  Column() {
                    Text(this.hourLabel(h.time))
                      .fontSize(this.fs(18)).fontColor('#666666')
                    Text(this.conditionIcon(h.condition))
                      .fontSize(this.fs(32)).margin({ top: 8 })
                    Text(h.condition)
                      .fontSize(this.fs(16)).fontColor('#666666')
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
                    Text(this.tempStrWithUnit(h.temperature))
                      .fontSize(this.fs(22)).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ top: 4 })
                    if (h.rainProb !== null && h.rainProb > 0) {
                      Text(h.rainProb + '%')
                        .fontSize(this.fs(16)).fontColor('#1565C0').margin({ top: 2 })
                    }
                  }
                  .width(100).alignItems(HorizontalAlign.Center).margin({ right: 8 })
                  .backgroundColor('#F5F5F5').borderRadius(12).padding({ top: 12, bottom: 12 })
                })
              }
              .padding({ left: 16, right: 16 })
            }
            .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')

            // ===== 信息卡片 =====
            this.InfoCard('\uD83D\uDCA7', '湿度',
              this.weather.humidity !== null ? this.weather.humidity + '%' : '-')
            this.InfoCard('\uD83C\uDF2C\uFE0F', '风力',
              this.weather.windDirect + ' ' + this.weather.windPower)
            this.InfoCard('\uD83E\uDEA7', '空气质量',
              this.weather.aqi !== null ? this.weather.aqi + ' ' + this.weather.aqiText : this.weather.aqiText || '-')
            this.InfoCard('\u2600\uFE0F', '紫外线强度', this.weather.uvIndex || '-')

            // ===== 逐分钟降水 =====
            if (this.weather.minutelyText) {
              Column() {
                Text('分钟级降水预报')
                  .fontSize(this.fs(22)).fontWeight(FontWeight.Bold).fontColor('#333333')
                  .margin({ bottom: 8 })
                Text(this.weather.minutelyText)
                  .fontSize(this.fs(18)).fontColor('#1565C0')
                  .maxLines(5).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%').padding(16)
              .backgroundColor('#E3F2FD').borderRadius(16)
              .border({ width: 1, color: '#90CAF9' })
              .margin({ top: 12, left: 16, right: 16 })
            }

            // ===== 昨日天气 =====
            Text('昨日天气')
              .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#333333')
              .margin({ top: 24, left: 16, bottom: 8 })

            if (this.weather.yesterday) {
              Column() {
                Row() {
                  Text('昨日高温')
                    .fontSize(this.fs(20)).fontColor('#666666')
                  Text(this.tempStrWithUnit(this.weather.yesterday.high))
                    .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#E65100').margin({ left: 12 })
                  Text('  /  ').fontSize(this.fs(20)).fontColor('#999999')
                  Text('昨日低温')
                    .fontSize(this.fs(20)).fontColor('#666666')
                  Text(this.tempStrWithUnit(this.weather.yesterday.low))
                    .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#1565C0').margin({ left: 12 })
                }
                .width('100%').padding({ left: 16, right: 16, top: 16, bottom: 8 })

                if (this.weather.yesterday.hourly.length > 0) {
                  Text('昨日逐时')
                    .fontSize(this.fs(20)).fontWeight(FontWeight.Medium).fontColor('#666666')
                    .margin({ left: 16, bottom: 8 })

                  Scroll() {
                    Row() {
                      ForEach(this.weather.yesterday.hourly, (h: HourlyItem) => {
                        Column() {
                          Text(this.hourLabel(h.time))
                            .fontSize(this.fs(16)).fontColor('#999999')
                          Text(this.conditionIcon(h.condition))
                            .fontSize(this.fs(28)).margin({ top: 6 })
                          Text(this.tempStrWithUnit(h.temperature))
                            .fontSize(this.fs(20)).fontWeight(FontWeight.Bold).fontColor('#666666').margin({ top: 4 })
                        }
                        .width(80).alignItems(HorizontalAlign.Center).margin({ right: 8 })
                      })
                    }
                    .padding({ left: 16, right: 16 })
                  }
                  .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
                }
              }
              .width('100%').backgroundColor('#F5F5F5').borderRadius(16)
              .margin({ left: 16, right: 16 })
            } else {
              Row() {
                Text('暂不提供昨日天气数据')
                  .fontSize(this.fs(20)).fontColor('#666666')
              }
              .width('100%').padding(16).backgroundColor('#F5F5F5').borderRadius(16)
              .margin({ left: 16, right: 16 })
            }

            // ===== 7天预报 =====
            Text('7天预报')
              .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#333333')
              .margin({ top: 24, left: 16, bottom: 8 })

            Column() {
              ForEach(this.weather.daily.slice(0, 7), (d: DailyItem, index: number) => {
                Column() {
                  Row() {
                    Text(this.dayLabel(index, d.date))
                      .fontSize(this.fs(22)).fontWeight(FontWeight.Medium).fontColor('#333333').width(80)
                    Text(this.conditionIcon(d.dayText || d.nightText))
                      .fontSize(this.fs(32)).width(50).textAlign(TextAlign.Center)
                    Text(this.combineDayNight(d.dayText, d.nightText))
                      .fontSize(this.fs(20)).fontColor('#666666').layoutWeight(1)
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ left: 8 })
                    Text(this.tempStr(d.high) + '\u00B0')
                      .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#E65100')
                    Text(' / ')
                      .fontSize(this.fs(22)).fontColor('#999999')
                    Text(this.tempStr(d.low) + '\u00B0')
                      .fontSize(this.fs(22)).fontColor('#1565C0')
                  }
                  .width('100%').padding({ top: 12, bottom: 12, left: 16, right: 16 })

                  if (index < this.weather!.daily.length - 1) {
                    Divider().color('#E0E0E0').margin({ left: 16, right: 16 })
                  }
                }
              })
            }
            .width('100%').backgroundColor('#F5F5F5').borderRadius(16)
            .margin({ left: 16, right: 16 })

            // ===== 数据来源 =====
            Text(this.weather.sourceTag)
              .fontSize(this.fs(16)).fontColor('#999999')
              .margin({ top: 24, bottom: 32 })
              .width('100%').textAlign(TextAlign.Center)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor('#FFFFFF')
  }
}
