import { SettingsStore, DataSource } from '../data/SettingsStore';
import { router } from '@kit.ArkUI';
import { AppBarIcon } from '../ui/AppBarIcon';

@Entry
@Component
struct SettingsPage {
  @State dataSource: DataSource = 'openmeteo';
  @State tempUnit: string = 'c';
  @State fontScale: number = 1.0;
  @State themeMode: string = 'auto';
  @State useGps: boolean = false;
  @State refreshInterval: string = 'off';
  @State autoUpdate: boolean = true;
  @State cityName: string = '';

  aboutToAppear(): void {
    this.dataSource = SettingsStore.getDataSource();
    this.tempUnit = SettingsStore.getTempUnit();
    this.fontScale = SettingsStore.getFontScale();
    this.themeMode = SettingsStore.getThemeMode();
    this.useGps = SettingsStore.getUseGps();
    this.refreshInterval = SettingsStore.getRefreshInterval();
    this.autoUpdate = SettingsStore.getAutoUpdate();
    this.cityName = SettingsStore.getCityName();
  }

  onPageShow(): void {
    this.cityName = SettingsStore.getCityName();
  }

  fs(size: number): number {
    return Math.round(size * this.fontScale);
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        AppBarIcon({ icon: 'back', iconSize: this.fs(24), color: '#333333' })
          .onClick(() => { router.back(); })
          .width(40)
          .height(40)
        Text('设置')
          .fontSize(this.fs(28))
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ left: 8 })
      }
      .width('100%').height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          // ===== 数据源 =====
          Text('数据源')
            .fontSize(this.fs(22)).fontWeight(FontWeight.Bold).fontColor('#333333')
            .margin({ top: 16, left: 16, bottom: 8 })

          this.DataSourceRow('nmc', 'NMC 中央气象台', '中国气象局官方数据，预报准确')
          this.DataSourceRow('openmeteo', 'Open-Meteo', '开源气象数据，全球覆盖')
          this.DataSourceRow('caiyun', '彩云天气', '分钟级降水预报，中国地区')

          // ===== 城市 =====
          Text('城市')
            .fontSize(this.fs(22)).fontWeight(FontWeight.Bold).fontColor('#333333')
            .margin({ top: 24, left: 16, bottom: 8 })

          Row() {
            Column() {
              Text('当前城市')
                .fontSize(this.fs(18)).fontColor('#666666')
              Text(this.cityName)
                .fontSize(this.fs(22)).fontWeight(FontWeight.Medium).fontColor('#333333')
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)

            Text('更改 \u203A')
              .fontSize(this.fs(20)).fontColor('#1565C0')
              .onClick(() => { router.pushUrl({ url: 'pages/CityPickerPage' }); })
          }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .backgroundColor('#F5F5F5').borderRadius(16)
          .margin({ left: 16, right: 16 })

          // ===== 显示设置 =====
          Text('显示设置')
            .fontSize(this.fs(22)).fontWeight(FontWeight.Bold).fontColor('#333333')
            .margin({ top: 24, left: 16, bottom: 8 })

          // 温度单位
          Row() {
            Text('温度单位')
              .fontSize(this.fs(20)).fontColor('#333333').layoutWeight(1)
            Row() {
              Text('\u00B0C')
                .fontSize(this.fs(20)).fontColor(this.tempUnit === 'c' ? '#1565C0' : '#999999')
                .margin({ right: 16 })
                .onClick(() => { this.tempUnit = 'c'; SettingsStore.setTempUnit('c'); })
              Text('\u00B0F')
                .fontSize(this.fs(20)).fontColor(this.tempUnit === 'f' ? '#1565C0' : '#999999')
                .onClick(() => { this.tempUnit = 'f'; SettingsStore.setTempUnit('f'); })
            }
          }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .backgroundColor('#F5F5F5').borderRadius(16)
          .margin({ left: 16, right: 16, top: 8 })

          // 字体大小
          Row() {
            Text('字体大小')
              .fontSize(this.fs(20)).fontColor('#333333').layoutWeight(1)
            Row() {
              Text('标准')
                .fontSize(this.fs(18)).fontColor(this.fontScale === 1.0 ? '#1565C0' : '#999999')
                .margin({ right: 12 })
                .onClick(() => { this.fontScale = 1.0; SettingsStore.setFontScale(1.0); })
              Text('大')
                .fontSize(this.fs(18)).fontColor(this.fontScale === 1.2 ? '#1565C0' : '#999999')
                .margin({ right: 12 })
                .onClick(() => { this.fontScale = 1.2; SettingsStore.setFontScale(1.2); })
              Text('超大')
                .fontSize(this.fs(18)).fontColor(this.fontScale === 1.4 ? '#1565C0' : '#999999')
                .onClick(() => { this.fontScale = 1.4; SettingsStore.setFontScale(1.4); })
            }
          }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .backgroundColor('#F5F5F5').borderRadius(16)
          .margin({ left: 16, right: 16, top: 8 })

          // 主题模式
          Row() {
            Text('主题模式')
              .fontSize(this.fs(20)).fontColor('#333333').layoutWeight(1)
            Row() {
              Text('自动')
                .fontSize(this.fs(18)).fontColor(this.themeMode === 'auto' ? '#1565C0' : '#999999')
                .margin({ right: 12 })
                .onClick(() => { this.themeMode = 'auto'; SettingsStore.setThemeMode('auto'); })
              Text('浅色')
                .fontSize(this.fs(18)).fontColor(this.themeMode === 'light' ? '#1565C0' : '#999999')
                .margin({ right: 12 })
                .onClick(() => { this.themeMode = 'light'; SettingsStore.setThemeMode('light'); })
              Text('深色')
                .fontSize(this.fs(18)).fontColor(this.themeMode === 'dark' ? '#1565C0' : '#999999')
                .onClick(() => { this.themeMode = 'dark'; SettingsStore.setThemeMode('dark'); })
            }
          }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .backgroundColor('#F5F5F5').borderRadius(16)
          .margin({ left: 16, right: 16, top: 8 })

          // ===== 功能设置 =====
          Text('功能设置')
            .fontSize(this.fs(22)).fontWeight(FontWeight.Bold).fontColor('#333333')
            .margin({ top: 24, left: 16, bottom: 8 })

          // 自动定位
          Row() {
            Text('自动定位')
              .fontSize(this.fs(20)).fontColor('#333333').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.useGps })
              .onChange((on: boolean) => {
                this.useGps = on;
                SettingsStore.setUseGps(on);
              })
          }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .backgroundColor('#F5F5F5').borderRadius(16)
          .margin({ left: 16, right: 16, top: 8 })

          // 自动刷新间隔
          Row() {
            Text('自动刷新间隔')
              .fontSize(this.fs(20)).fontColor('#333333').layoutWeight(1)
            Text(this.refreshIntervalLabel())
              .fontSize(this.fs(18)).fontColor('#666666')
              .onClick(() => { this.cycleRefreshInterval(); })
          }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .backgroundColor('#F5F5F5').borderRadius(16)
          .margin({ left: 16, right: 16, top: 8 })

          // 自动检查更新
          Row() {
            Text('自动检查更新')
              .fontSize(this.fs(20)).fontColor('#333333').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.autoUpdate })
              .onChange((on: boolean) => {
                this.autoUpdate = on;
                SettingsStore.setAutoUpdate(on);
              })
          }
          .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .backgroundColor('#F5F5F5').borderRadius(16)
          .margin({ left: 16, right: 16, top: 8 })

          // ===== 关于 =====
          Text('关于')
            .fontSize(this.fs(22)).fontWeight(FontWeight.Bold).fontColor('#333333')
            .margin({ top: 24, left: 16, bottom: 8 })

          this.AboutRow('应用名称', 'cyanweather')
          this.AboutRow('版本', '1.1.0')
          this.AboutRow('开发者', 'cyanweather')

          Text('数据来源：NMC / Open-Meteo / 彩云天气')
            .fontSize(this.fs(14)).fontColor('#999999')
            .margin({ top: 16, bottom: 32 })
            .width('100%').textAlign(TextAlign.Center)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor('#FFFFFF')
  }

  refreshIntervalLabel(): string {
    const map: Record<string, string> = {
      'off': '关闭',
      'on_resume': '回到应用时',
      '10': '10 分钟',
      '30': '30 分钟',
      '60': '1 小时',
      '360': '6 小时',
      '720': '12 小时',
      '1440': '24 小时'
    };
    return map[this.refreshInterval] || '关闭';
  }

  cycleRefreshInterval(): void {
    const intervals: string[] = ['off', 'on_resume', '10', '30', '60', '360', '720', '1440'];
    const idx: number = intervals.indexOf(this.refreshInterval);
    const next: string = intervals[(idx + 1) % intervals.length];
    this.refreshInterval = next;
    SettingsStore.setRefreshInterval(next);
  }

  @Builder
  DataSourceRow(value: DataSource, title: string, desc: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(this.fs(20)).fontWeight(FontWeight.Medium)
          .fontColor(this.dataSource === value ? '#1565C0' : '#333333')
        Text(desc)
          .fontSize(this.fs(16)).fontColor('#666666').margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      if (this.dataSource === value) {
        Text('\u2713')
          .fontSize(this.fs(24)).fontColor('#1565C0')
      }
    }
    .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor('#F5F5F5').borderRadius(16)
    .margin({ left: 16, right: 16, top: 8 })
    .onClick(() => {
      this.dataSource = value;
      SettingsStore.setDataSource(value);
    })
  }

  @Builder
  AboutRow(title: string, value: string) {
    Row() {
      Text(title)
        .fontSize(this.fs(18)).fontColor('#666666').layoutWeight(1)
      Text(value)
        .fontSize(this.fs(18)).fontColor('#333333')
    }
    .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor('#F5F5F5').borderRadius(16)
    .margin({ left: 16, right: 16, top: 8 })
  }
}
