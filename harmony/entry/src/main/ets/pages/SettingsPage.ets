import { SettingsStore, DataSource } from '../data/SettingsStore';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct SettingsPage {
  @State dataSource: DataSource = 'openmeteo';
  @State tempUnit: string = 'c';
  @State fontScale: number = 1.0;
  @State themeMode: string = 'auto';

  aboutToAppear(): void {
    this.dataSource = SettingsStore.getDataSource();
    this.tempUnit = SettingsStore.getTempUnit();
    this.fontScale = SettingsStore.getFontScale();
    this.themeMode = SettingsStore.getThemeMode();
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#333333')
          .onClick(() => { router.back(); })
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .backgroundColor(Color.White)

      // 内容区域
      Scroll() {
        Column() {
          // ===== 数据源 =====
          this.SectionTitle('数据源')
          Column() {
            this.DataSourceItem('Open-Meteo', '全球免费开源气象数据', 'openmeteo')
            this.Divider()
            this.DataSourceItem('中央气象台 (NMC)', '中国官方气象数据', 'nmc')
            this.Divider()
            this.DataSourceItem('彩云天气', '分钟级降水预报', 'caiyun')
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .margin({ top: 8, left: 16, right: 16 })
          .clip(true)

          // ===== 显示设置 =====
          this.SectionTitle('显示设置')
          Column() {
            // 温度单位
            Row() {
              Text('温度单位').fontSize(15).fontColor('#333333').layoutWeight(1)
              Row() {
                Text('°C')
                  .fontSize(14)
                  .fontColor(this.tempUnit === 'c' ? '#FFFFFF' : '#666666')
                  .backgroundColor(this.tempUnit === 'c' ? '#4A90D9' : Color.Transparent)
                  .borderRadius({ topLeft: 8, bottomLeft: 8 })
                  .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.tempUnit = 'c';
                    SettingsStore.setTempUnit('c');
                  })
                Text('°F')
                  .fontSize(14)
                  .fontColor(this.tempUnit === 'f' ? '#FFFFFF' : '#666666')
                  .backgroundColor(this.tempUnit === 'f' ? '#4A90D9' : Color.Transparent)
                  .borderRadius({ topRight: 8, bottomRight: 8 })
                  .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.tempUnit = 'f';
                    SettingsStore.setTempUnit('f');
                  })
              }
              .border({ width: 1, color: '#E0E0E0' })
              .borderRadius(8)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            this.Divider()

            // 字体缩放
            Row() {
              Column() {
                Row() {
                  Text('字体缩放').fontSize(15).fontColor('#333333')
                  Blank()
                  Text(this.fontScale.toFixed(1) + 'x')
                    .fontSize(14)
                    .fontColor('#4A90D9')
                }
                .width('100%')
                Slider({
                  value: this.fontScale,
                  min: 0.8,
                  max: 1.4,
                  step: 0.1
                })
                  .width('100%')
                  .blockColor('#4A90D9')
                  .selectedColor('#4A90D9')
                  .trackColor('#E0E0E0')
                  .onChange((value: number) => {
                    this.fontScale = Math.round(value * 10) / 10;
                    SettingsStore.setFontScale(this.fontScale);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            }
            .width('100%')
            this.Divider()

            // 主题模式
            Row() {
              Text('主题模式').fontSize(15).fontColor('#333333').layoutWeight(1)
              Row() {
                Text('跟随系统')
                  .fontSize(13)
                  .fontColor(this.themeMode === 'auto' ? '#FFFFFF' : '#666666')
                  .backgroundColor(this.themeMode === 'auto' ? '#4A90D9' : Color.Transparent)
                  .borderRadius({ topLeft: 8, bottomLeft: 8 })
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .onClick(() => { this.themeMode = 'auto'; SettingsStore.setThemeMode('auto'); })
                Text('浅色')
                  .fontSize(13)
                  .fontColor(this.themeMode === 'light' ? '#FFFFFF' : '#666666')
                  .backgroundColor(this.themeMode === 'light' ? '#4A90D9' : Color.Transparent)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .onClick(() => { this.themeMode = 'light'; SettingsStore.setThemeMode('light'); })
                Text('深色')
                  .fontSize(13)
                  .fontColor(this.themeMode === 'dark' ? '#FFFFFF' : '#666666')
                  .backgroundColor(this.themeMode === 'dark' ? '#4A90D9' : Color.Transparent)
                  .borderRadius({ topRight: 8, bottomRight: 8 })
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .onClick(() => { this.themeMode = 'dark'; SettingsStore.setThemeMode('dark'); })
              }
              .border({ width: 1, color: '#E0E0E0' })
              .borderRadius(8)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .margin({ top: 8, left: 16, right: 16 })
          .clip(true)

          // ===== 关于 =====
          this.SectionTitle('关于')
          Column() {
            Row() {
              Text('应用名称').fontSize(15).fontColor('#333333').layoutWeight(1)
              Text('CyanWeather').fontSize(14).fontColor('#888888')
            }
            .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
            this.Divider()
            Row() {
              Text('版本').fontSize(15).fontColor('#333333').layoutWeight(1)
              Text('1.0.0').fontSize(14).fontColor('#888888')
            }
            .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
            this.Divider()
            Row() {
              Text('开发者').fontSize(15).fontColor('#333333').layoutWeight(1)
              Text('upcyan').fontSize(14).fontColor('#888888')
            }
            .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .margin({ top: 8, left: 16, right: 16, bottom: 32 })
          .clip(true)
        }
        .width('100%')
        .padding({ top: 8, bottom: 32 })
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor('#888888')
      .width('100%')
      .padding({ left: 20, top: 20, bottom: 4 })
  }

  @Builder
  DataSourceItem(title: string, desc: string, source: DataSource) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#333333')
        Text(desc).fontSize(12).fontColor('#AAAAAA').margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(this.dataSource === source ? '✓' : '')
        .fontSize(18)
        .fontColor('#4A90D9')
        .width(24)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      this.dataSource = source;
      SettingsStore.setDataSource(source);
    })
  }

  @Builder
  Divider() {
    Row()
      .width('100%')
      .height(0.5)
      .backgroundColor('#F0F0F0')
      .margin({ left: 16, right: 16 })
  }
}
