import { WeatherData, HourlyItem, DailyItem } from '../model/WeatherData';
import { WeatherManager } from '../data/WeatherManager';
import { router } from '@kit.ArkUI';
import { SettingsStore } from '../data/SettingsStore';

@Entry
@Component
struct RainForecastPage {
  @State weather: WeatherData | null = null;
  @State loading: boolean = true;
  @State tempUnit: string = 'c';
  @State fontScale: number = 1.0;

  async aboutToAppear(): Promise<void> {
    this.tempUnit = SettingsStore.getTempUnit();
    this.fontScale = SettingsStore.getFontScale();
    await this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      const lat: number = SettingsStore.getCityLat();
      const lon: number = SettingsStore.getCityLon();
      const name: string = SettingsStore.getCityName();
      this.weather = await WeatherManager.getWeather(lat, lon, name);
    } catch (e) {
      this.weather = null;
    } finally {
      this.loading = false;
    }
  }

  fs(size: number): number {
    return Math.round(size * this.fontScale);
  }

  hourLabel(timeStr: string): string {
    const t: string = timeStr.trim();
    try {
      if (t.length >= 13 && t.includes('T')) {
        const datePart: string = t.substring(5, 10);
        const hourPart: string = t.substring(11, 13);
        const hour: number = parseInt(hourPart);
        if (!isNaN(hour)) {
          return datePart.replace('-', '/') + ' ' + hour + '时';
        }
      }
      if (t.length >= 16 && t.includes(' ')) {
        const datePart: string = t.substring(5, 10);
        const hourPart: string = t.substring(11, 13);
        const hour: number = parseInt(hourPart);
        if (!isNaN(hour)) {
          return datePart.replace('-', '/') + ' ' + hour + '时';
        }
      }
    } catch (_) {}
    return t;
  }

  build() {
    Column() {
      // ===== 顶部栏 =====
      Row() {
        Text('\u2190')
          .fontSize(this.fs(28))
          .width(48).height(48)
          .textAlign(TextAlign.Center)
          .fontColor('#333333')
          .onClick(() => { router.back(); })

        Text('降雨趋势预报')
          .fontSize(this.fs(30))
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ left: 8 })
      }
      .width('100%').height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#FFFFFF')

      // ===== 内容区 =====
      Scroll() {
        Column() {
          if (this.loading) {
            Text('加载中...')
              .fontSize(this.fs(22)).fontColor('#666666')
              .margin({ top: 40 }).width('100%').textAlign(TextAlign.Center)
          } else if (this.weather) {
            Text(this.weather.cityName)
              .fontSize(this.fs(20)).fontColor('#666666')
              .margin({ top: 10, left: 16 })

            // 获取有降雨概率的逐时数据
            if (this.weather.hourly.filter((h: HourlyItem) => h.isForecast && h.rainProb !== null).length > 0) {
              Text('未来24小时降雨概率')
                .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#333333')
                .margin({ top: 16, left: 16, bottom: 4 })

              Text('数值为降雨概率，雨天与雷雨时段以蓝色标出。')
                .fontSize(this.fs(16)).fontColor('#666666')
                .margin({ left: 16, bottom: 6 })

              ForEach(this.weather.hourly.filter((h: HourlyItem) => h.isForecast && h.rainProb !== null).slice(0, 24), (h: HourlyItem) => {
                this.RainHourRow(h)
              })
            } else {
              Text('逐时降雨概率')
                .fontSize(this.fs(24)).fontWeight(FontWeight.Bold).fontColor('#333333')
                .margin({ top: 16, left: 16, bottom: 4 })

              Text('当前数据源暂不提供逐时降雨概率，以下为未来几日降雨趋势。')
                .fontSize(this.fs(16)).fontColor('#666666')
                .margin({ left: 16, bottom: 6 })

              ForEach(this.weather.daily.slice(0, 7), (d: DailyItem) => {
                this.RainDayRow(d.dayText + d.nightText)
              })
            }
          } else {
            Text('暂无天气数据')
              .fontSize(this.fs(22)).fontColor('#666666')
              .margin({ top: 40 }).width('100%').textAlign(TextAlign.Center)
          }
        }
        .width('100%').padding(16)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  RainHourRow(h: HourlyItem) {
    Column() {
      Row() {
        Text(this.hourLabel(h.time))
          .fontSize(this.fs(20)).fontColor('#666666').width(88)
          .maxLines(1)
        Text(h.condition.length > 0 ? h.condition : '-')
          .fontSize(this.fs(20))
          .fontColor((h.condition.includes('雨') || h.condition.includes('雷') || (h.rainProb !== null && h.rainProb >= 50)) ? '#0B6BCB' : '#666666')
          .layoutWeight(1)
        Text((h.rainProb !== null ? Math.round(h.rainProb) : 0) + '%')
          .fontSize(this.fs(20)).fontWeight(FontWeight.Bold)
          .fontColor((h.condition.includes('雨') || h.condition.includes('雷') || (h.rainProb !== null && h.rainProb >= 50)) ? '#0B6BCB' : '#666666')
      }
      .width('100%')

      // 进度条背景
      Stack() {
        Column()
          .width('100%').height(12)
          .backgroundColor('#E3EDF9').borderRadius(6)
      }
      .width('100%').height(12)
      .margin({ top: 4 })
    }
    .width('100%').padding({ top: 12, bottom: 12 })
  }

  @Builder
  RainDayRow(text: string) {
    Row() {
      Column()
        .width(12).height(12)
        .backgroundColor((text.includes('雨') || text.includes('雷')) ? '#0B6BCB' : '#90CAF9')
        .borderRadius(2)
        .margin({ right: 10 })

      Text(text.length > 0 ? text : '-')
        .fontSize(this.fs(22))
        .fontColor((text.includes('雨') || text.includes('雷')) ? '#0B6BCB' : '#111111')
    }
    .width('100%').padding({ top: 8, bottom: 8 })
  }
}
