import { WeatherData, HourlyItem, DailyItem, YesterdayData } from '../model/WeatherData';
import { WeatherManager } from '../data/WeatherManager';
import { router } from '@kit.ArkUI';
import { SettingsStore } from '../data/SettingsStore';
import { WeatherGlyph } from '../ui/WeatherGlyph';
import { AppBarIcon } from '../ui/AppBarIcon';
import { SkyKind, condToKind } from '../ui/SkyKind';

const COLOR_BG: string = '#F5F9FF';
const COLOR_SURFACE: string = '#FFFFFF';
const COLOR_SURFACE_VARIANT: string = '#E3EDF9';
const COLOR_PRIMARY: string = '#0B6BCB';
const COLOR_TEXT: string = '#111111';
const COLOR_TEXT_SECONDARY: string = '#333333';
const COLOR_TEXT_MUTED: string = '#666666';
const COLOR_TEXT_FADED: string = '#888888';
const COLOR_HIGH: string = '#C62828';
const COLOR_LOW: string = '#1565C0';
const COLOR_WARN_BG: string = '#FFEBEE';
const COLOR_WARN_TEXT: string = '#B71C1C';
const COLOR_RAIN_BG: string = '#E3F2FD';
const COLOR_ERROR: string = '#C62828';

@Entry
@Component
struct Index {
  @State weather: WeatherData | null = null;
  @State loading: boolean = true;
  @State error: string = '';
  @State isRefreshing: boolean = false;
  @State tempUnit: string = 'c';
  @State fontScale: number = 1.3;
  private scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    this.tempUnit = SettingsStore.getTempUnit();
    this.fontScale = SettingsStore.getFontScale();
    await this.loadData();
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
      this.error = (e as Error).message || '加载失败';
    } finally {
      this.loading = false;
      this.isRefreshing = false;
    }
  }

  fs(size: number): number {
    return Math.round(size * this.fontScale);
  }

  temp(v: number | null): string {
    if (v === null) {
      return '-';
    }
    if (this.tempUnit === 'f') {
      return Math.round(v * 9 / 5 + 32).toString();
    }
    return Math.round(v).toString();
  }

  buildRainReminder(w: WeatherData): string | null {
    const upcoming: HourlyItem[] = w.hourly.filter((h: HourlyItem) => h.isForecast).slice(0, 12);
    if (upcoming.length > 0) {
      const idx: number = upcoming.findIndex((h: HourlyItem) =>
        h.condition.includes('雨') || h.condition.includes('雷'));
      if (idx >= 0) {
        if (idx <= 1) {
          return '现在或很快有降雨，出门请带伞';
        }
        return '预计约 ' + idx.toString() + ' 小时后可能有降雨，出门请带伞';
      }
    }
    const soon: boolean = w.daily.slice(0, 3).some((d: DailyItem) =>
      (d.dayText + d.nightText).includes('雨') || (d.dayText + d.nightText).includes('雷'));
    return soon ? '近期可能有雨，请留意天气变化' : null;
  }

  hourKind(item: HourlyItem): SkyKind {
    if (item.isForecast && item.condition.length > 0) {
      return condToKind(item.condition, '彩云');
    }
    if (item.isForecast) {
      return SkyKind.UNKNOWN;
    }
    return condToKind(item.condition, '');
  }

  hourLabel(time: string): string {
    if (time.includes('T')) {
      const hour: string = time.substring(11, 13);
      return hour + '时';
    }
    return time;
  }

  dayLabel(date: string): string {
    if (date.includes('T')) {
      return date.substring(5, 10).replace('-', '/');
    }
    return date;
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.TopBar()

        Scroll(this.scroller) {
          Column() {
            if (this.loading) {
              this.LoadingView()
            } else if (this.error.length > 0) {
              this.ErrorView()
            } else if (this.weather) {
              this.WeatherBody(this.weather)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 30 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLOR_BG)
    }
    .width('100%')
    .height('100%')
  }

  @Builder TopBar(): void {
    Row() {
      AppBarIcon({ icon: 'settings', iconSize: this.fs(28), color: COLOR_TEXT_SECONDARY })
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsPage' });
        })

      Column() {
        Text(this.weather?.cityName ?? '—')
          .fontSize(this.fs(30))
          .fontColor(COLOR_TEXT)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.weather?.updatedAt ?? '')
          .fontSize(this.fs(14))
          .fontColor(COLOR_TEXT_MUTED)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      AppBarIcon({ icon: 'refresh', iconSize: this.fs(28), color: COLOR_TEXT_SECONDARY })
        .onClick(() => {
          this.isRefreshing = true;
          this.loadData();
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(COLOR_SURFACE)
  }

  @Builder LoadingView(): void {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(COLOR_PRIMARY)
      Text('加载中...')
        .fontSize(this.fs(18))
        .fontColor(COLOR_TEXT_MUTED)
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder ErrorView(): void {
    Column() {
      Text('加载失败')
        .fontSize(this.fs(24))
        .fontColor(COLOR_ERROR)
        .margin({ bottom: 12 })
      Text(this.error)
        .fontSize(this.fs(18))
        .fontColor(COLOR_TEXT_MUTED)
      Text('点击重试')
        .fontSize(this.fs(20))
        .fontColor(COLOR_PRIMARY)
        .margin({ top: 20 })
        .onClick(() => {
          this.loadData();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder WeatherBody(w: WeatherData): void {
    if (w.warning) {
      Row() {
        Text('\u26A0 ' + w.warning)
          .fontSize(this.fs(20))
          .fontColor(COLOR_WARN_TEXT)
          .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
      .margin({ top: 8, bottom: 4 })
      .backgroundColor(COLOR_WARN_BG)
      .borderRadius(12)
    }

    if (this.buildRainReminder(w)) {
      Column() {
        Text('\uD83C\uDF02 ' + this.buildRainReminder(w))
          .fontSize(this.fs(22))
          .fontColor(COLOR_TEXT)
        Text('查看降雨趋势 \u203A')
          .fontSize(this.fs(18))
          .fontColor(COLOR_PRIMARY)
          .margin({ top: 6 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/RainForecastPage' });
          })
      }
      .width('100%')
      .padding(16)
      .margin({ top: 8, bottom: 4 })
      .backgroundColor(COLOR_RAIN_BG)
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)
    }

    Column() {
      Row() {
        Column() {
          WeatherGlyph({
            kind: condToKind(w.condition, w.sourceTag),
            iconSize: this.fs(88)
          })
          Text(w.condition)
            .fontSize(this.fs(28))
            .fontColor(COLOR_TEXT)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Center)

        Text(this.temp(w.temperature) + '\u00B0')
          .fontSize(this.fs(64))
          .fontColor(COLOR_TEXT)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 20 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Row() {
        this.StatCol('最高', this.temp(w.todayHigh) + '\u00B0', COLOR_HIGH)
        this.StatCol('最低', this.temp(w.todayLow) + '\u00B0', COLOR_LOW)
      }
      .width('100%')
      .margin({ top: 12 })

      if (w.feelsLike !== null) {
        Text('体感温度 ' + this.temp(w.feelsLike) + '\u00B0')
          .fontSize(this.fs(20))
          .fontColor(COLOR_TEXT_MUTED)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ top: 18, bottom: 12 })
    .alignItems(HorizontalAlign.Center)

    if (w.sunrise !== null || w.sunset !== null) {
      Row() {
        this.SunCol('日出', w.sunrise)
        this.SunCol('日落', w.sunset)
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
    }

    Column() {
      this.InfoCard('湿度', (w.humidity ?? '-').toString() + '%')
      this.InfoCard('风力', (w.windDirect + ' ' + w.windPower).trim())
      this.InfoCard('空气质量', w.aqi !== null ? (w.aqiText + ' ' + w.aqi.toString()) : '-')
      if (w.uvIndex.length > 0) {
        this.InfoCard('紫外线强度', w.uvIndex)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })

    if (w.minutelyText !== null) {
      Text(w.minutelyText)
        .fontSize(this.fs(22))
        .fontColor(COLOR_TEXT)
        .width('100%')
        .padding(16)
        .margin({ top: 8, bottom: 8 })
        .backgroundColor(COLOR_RAIN_BG)
        .borderRadius(12)
    }

    if (w.hourly.length > 0 && w.hourlyLabel.includes('预报')) {
      this.SectionTitle(w.hourlyLabel)
      this.HourlyRow(w.hourly)
    }

    if (w.daily.length > 0) {
      this.SectionTitle('未来多日预报(' + w.daily.length.toString() + '天)')
      Column() {
        ForEach(w.daily, (d: DailyItem) => {
          this.DailyRow(d)
        })
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
      .backgroundColor(COLOR_SURFACE)
      .borderRadius(12)
    }

    if (w.yesterday !== null) {
      this.SectionTitle('昨日天气')
      this.YesterdayCard(w.yesterday)
    } else if (w.sourceTag.includes('彩云')) {
      this.SectionTitle('昨日天气')
      Text('彩云天气暂不提供昨日天气数据')
        .fontSize(this.fs(20))
        .fontColor(COLOR_TEXT_MUTED)
        .width('100%')
        .padding(16)
        .backgroundColor(COLOR_SURFACE_VARIANT)
        .borderRadius(12)
    }

    Text(w.sourceTag)
      .fontSize(this.fs(16))
      .fontColor(COLOR_TEXT_FADED)
      .width('100%')
      .margin({ top: 8 })
      .textAlign(TextAlign.Center)
  }

  @Builder StatCol(label: string, value: string, color: string): void {
    Column() {
      Text(label)
        .fontSize(this.fs(22))
        .fontColor(COLOR_TEXT_MUTED)
      Text(value)
        .fontSize(this.fs(30))
        .fontColor(color)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder SunCol(label: string, time: string | null): void {
    Column() {
      Text(label)
        .fontSize(this.fs(22))
        .fontColor(COLOR_TEXT_MUTED)
      Text(time ?? '-')
        .fontSize(this.fs(22))
        .fontColor(COLOR_TEXT)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder InfoCard(title: string, value: string): void {
    Column() {
      Text(title)
        .fontSize(this.fs(20))
        .fontColor(COLOR_TEXT_MUTED)
      Text(value)
        .fontSize(this.fs(28))
        .fontColor(COLOR_TEXT)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .margin({ top: 5, bottom: 5 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder SectionTitle(text: string): void {
    Text(text)
      .fontSize(this.fs(24))
      .fontColor(COLOR_TEXT)
      .fontWeight(FontWeight.Bold)
      .margin({ top: 20, bottom: 10 })
  }

  @Builder HourlyRow(items: HourlyItem[]): void {
    Scroll() {
      Row() {
        ForEach(items, (item: HourlyItem) => {
          this.HourCard(item)
        })
      }
      .padding({ left: 4, right: 4 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder HourCard(item: HourlyItem): void {
    Column() {
      Text(this.hourLabel(item.time))
        .fontSize(this.fs(18))
        .fontColor(COLOR_TEXT_MUTED)
      WeatherGlyph({
        kind: this.hourKind(item),
        iconSize: this.fs(36)
      })
      if (item.condition.length > 0) {
        Text(item.condition)
          .fontSize(this.fs(16))
          .fontColor(COLOR_TEXT_MUTED)
          .maxLines(1)
          .margin({ top: 4 })
      }
      Text(this.temp(item.temperature) + '\u00B0')
        .fontSize(this.fs(24))
        .fontColor(COLOR_TEXT)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 4 })
      if (item.rainProb !== null && item.rainProb > 0) {
        Text(item.rainProb.toString() + '%')
          .fontSize(this.fs(16))
          .fontColor(COLOR_PRIMARY)
          .margin({ top: 2 })
      }
    }
    .width(100)
    .padding({ top: 10, bottom: 10 })
    .margin({ left: 4, right: 4 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder DailyRow(d: DailyItem): void {
    Column() {
      Text(this.dayLabel(d.date))
        .fontSize(this.fs(22))
        .fontColor(COLOR_TEXT)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
      Row() {
        WeatherGlyph({
          kind: d.dayText.length > 0 ? condToKind(d.dayText, '') : SkyKind.UNKNOWN,
          iconSize: this.fs(40)
        })
        Column() {
          if (d.dayText.length > 0) {
            Text(d.dayText)
              .fontSize(this.fs(20))
              .fontColor(COLOR_TEXT)
          }
          Text(this.temp(d.high) + '\u00B0 / ' + this.temp(d.low) + '\u00B0')
            .fontSize(this.fs(20))
            .fontColor(COLOR_TEXT_MUTED)
            .margin({ top: 2 })
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 4 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder YesterdayCard(y: YesterdayData): void {
    Column() {
      Text('昨日')
        .fontSize(this.fs(22))
        .fontColor(COLOR_TEXT)
        .fontWeight(FontWeight.Medium)
      Row() {
        WeatherGlyph({
          kind: SkyKind.UNKNOWN,
          iconSize: this.fs(40)
        })
        Column() {
          Text(this.temp(y.high) + '\u00B0 / ' + this.temp(y.low) + '\u00B0')
            .fontSize(this.fs(20))
            .fontColor(COLOR_TEXT_MUTED)
            .margin({ top: 2 })
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }
}
