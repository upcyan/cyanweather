import { router } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { SettingsStore } from '../data/SettingsStore';
import { LocationHelper } from '../data/LocationHelper';
import { common } from '@kit.AbilityKit';

// 城市信息
interface CityInfo {
  name: string;
  lat: number;
  lon: number;
  country: string;
  admin1: string;
}

// Open-Meteo 地理编码响应
interface GeoCodingResponse {
  results: GeoCodingResult[];
}
interface GeoCodingResult {
  name: string;
  latitude: number;
  longitude: number;
  country: string;
  admin1: string;
}

// 预置常用城市
const COMMON_CITIES: CityInfo[] = [
  { name: '北京', lat: 39.9042, lon: 116.4074, country: '中国', admin1: '北京' },
  { name: '上海', lat: 31.2304, lon: 121.4737, country: '中国', admin1: '上海' },
  { name: '广州', lat: 23.1291, lon: 113.2644, country: '中国', admin1: '广东' },
  { name: '深圳', lat: 22.5431, lon: 114.0579, country: '中国', admin1: '广东' },
  { name: '杭州', lat: 30.2741, lon: 120.1551, country: '中国', admin1: '浙江' },
  { name: '南京', lat: 32.0603, lon: 118.7969, country: '中国', admin1: '江苏' },
  { name: '武汉', lat: 30.5928, lon: 114.3055, country: '中国', admin1: '湖北' },
  { name: '成都', lat: 30.5728, lon: 104.0668, country: '中国', admin1: '四川' },
  { name: '重庆', lat: 29.5630, lon: 106.5516, country: '中国', admin1: '重庆' },
  { name: '西安', lat: 34.3416, lon: 108.9398, country: '中国', admin1: '陕西' },
  { name: '天津', lat: 39.3434, lon: 117.3616, country: '中国', admin1: '天津' },
  { name: '苏州', lat: 31.2989, lon: 120.5853, country: '中国', admin1: '江苏' },
  { name: '长沙', lat: 28.2282, lon: 112.9388, country: '中国', admin1: '湖南' },
  { name: '青岛', lat: 36.0671, lon: 120.3826, country: '中国', admin1: '山东' },
  { name: '沈阳', lat: 41.8057, lon: 123.4315, country: '中国', admin1: '辽宁' },
  { name: '哈尔滨', lat: 45.8038, lon: 126.5350, country: '中国', admin1: '黑龙江' },
  { name: '昆明', lat: 25.0389, lon: 102.7183, country: '中国', admin1: '云南' },
  { name: '厦门', lat: 24.4798, lon: 118.0894, country: '中国', admin1: '福建' },
];

@Entry
@Component
struct CityPickerPage {
  @State searchText: string = '';
  @State searchResults: CityInfo[] = [];
  @State searching: boolean = false;
  @State currentCity: string = '';
  @State locating: boolean = false;

  aboutToAppear(): void {
    this.currentCity = SettingsStore.getCityName();
  }

  async searchCity(query: string): Promise<void> {
    if (query.trim().length === 0) {
      this.searchResults = [];
      return;
    }
    this.searching = true;
    try {
      const url: string = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=15&language=zh&format=json`;
      const req: http.HttpRequest = http.createHttp();
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000,
      });
      if (resp.responseCode === 200) {
        const body: string = resp.result as string;
        const data: GeoCodingResponse = JSON.parse(body) as GeoCodingResponse;
        if (data.results && data.results.length > 0) {
          this.searchResults = data.results.map((r: GeoCodingResult): CityInfo => {
            return {
              name: r.name,
              lat: r.latitude,
              lon: r.longitude,
              country: r.country || '',
              admin1: r.admin1 || ''
            };
          });
        } else {
          this.searchResults = [];
        }
      }
      req.destroy();
    } catch (e) {
      this.searchResults = [];
    } finally {
      this.searching = false;
    }
  }

  selectCity(city: CityInfo): void {
    SettingsStore.setCity(city.name, city.lat, city.lon);
    router.back();
  }

  async onLocate(): Promise<void> {
    this.locating = true;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const result = await LocationHelper.locate(context);
      if (result !== null) {
        SettingsStore.setCity(result.cityName, result.lat, result.lon);
        router.back();
      }
    } catch (_) {
    } finally {
      this.locating = false;
    }
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
        Text('选择城市')
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

      // 定位按钮
      Row() {
        if (this.locating) {
          LoadingProgress().color('#4A90D9').width(16).height(16)
          Text('定位中...')
            .fontSize(14)
            .fontColor('#4A90D9')
            .margin({ left: 6 })
        } else {
          Text('📡 定位当前城市')
            .fontSize(14)
            .fontColor('#4A90D9')
        }
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#E8F4FD')
      .borderRadius(22)
      .margin({ left: 16, right: 16, top: 12 })
      .onClick(() => { this.onLocate(); })

      // 搜索框
      Row() {
        Text('🔍').fontSize(16).fontColor('#AAAAAA').margin({ right: 8 })
        TextInput({ text: this.searchText, placeholder: '搜索城市名称...' })
          .fontSize(15)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.searchText = value;
          })
        if (this.searchText.length > 0) {
          Text('✕')
            .fontSize(16)
            .fontColor('#AAAAAA')
            .width(30)
            .height(30)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.searchText = '';
              this.searchResults = [];
            })
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F5F5F5')
      .borderRadius(24)
      .margin({ left: 16, right: 16, top: 12 })

      // 搜索按钮
      if (this.searchText.trim().length > 0) {
        Button('搜索')
          .width('100%')
          .height(40)
          .backgroundColor('#4A90D9')
          .borderRadius(20)
          .margin({ left: 16, right: 16, top: 8 })
          .onClick(() => { this.searchCity(this.searchText); })
      }

      // 内容区域
      Scroll() {
        Column() {
          if (this.searching) {
            Row() {
              LoadingProgress().color('#4A90D9').width(24).height(24)
              Text('搜索中...').fontSize(14).fontColor('#888888').margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 40 })
          }

          // 搜索结果
          if (this.searchResults.length > 0) {
            Text('搜索结果')
              .fontSize(13)
              .fontColor('#888888')
              .width('100%')
              .padding({ left: 20, top: 16, bottom: 8 })
            Column() {
              ForEach(this.searchResults, (city: CityInfo, index: number) => {
                this.CityItem(city, index, this.searchResults.length)
              })
            }
            .backgroundColor(Color.White)
            .borderRadius(16)
            .margin({ left: 16, right: 16 })
            .clip(true)
          }

          // 常用城市
          if (this.searchText.trim().length === 0) {
            Text('常用城市')
              .fontSize(13)
              .fontColor('#888888')
              .width('100%')
              .padding({ left: 20, top: 16, bottom: 8 })
            Column() {
              ForEach(COMMON_CITIES, (city: CityInfo, index: number) => {
                this.CityItem(city, index, COMMON_CITIES.length)
              })
            }
            .backgroundColor(Color.White)
            .borderRadius(16)
            .margin({ left: 16, right: 16 })
            .clip(true)
          }
        }
        .width('100%')
        .padding({ bottom: 32 })
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
  CityItem(city: CityInfo, index: number, total: number) {
    Row() {
      Column() {
        Text(city.name).fontSize(16).fontColor('#333333').fontWeight(FontWeight.Medium)
        if (city.admin1.length > 0 || city.country.length > 0) {
          Text((city.admin1.length > 0 ? city.admin1 + ' · ' : '') + city.country)
            .fontSize(12)
            .fontColor('#AAAAAA')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      // 当前选中标记
      if (city.name === this.currentCity) {
        Text('✓')
          .fontSize(18)
          .fontColor('#4A90D9')
          .width(24)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => { this.selectCity(city); })
    .borderWidth({ bottom: index < total - 1 ? 0.5 : 0 })
    .borderColor({ bottom: '#F0F0F0' })
  }
}
