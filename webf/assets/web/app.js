/* CyanWeather WebF — 数据源：Open-Meteo / 中央气象台（对齐 native app/ 版） */
var APP_VERSION = '1.5.0';

/* JS 运行时错误可见化（WebF 无控制台，落到提示卡） */
window.onerror = function (msg) {
  try { showNotice('脚本异常：' + msg); } catch (e) { }
};

var GEO_URL = 'https://geocoding-api.open-meteo.com/v1/search';
var FC_URL = 'https://api.open-meteo.com/v1/forecast';
var AQI_URL = 'https://air-quality-api.open-meteo.com/v1/air-quality';
var REVERSE_URL = 'https://api.bigdatacloud.net/data/reverse-geocode-client';
var NMC_BASE = 'https://www.nmc.cn';

var DEFAULT_CITY = { name: '北京', lat: 39.9042, lon: 116.4074 };

/* ================= 映射（与 native WeatherMapper 一致） ================= */
var WMO_TEXT = {
  0:'晴',1:'晴',2:'多云',3:'阴',45:'雾',48:'雾',
  51:'小雨',53:'小雨',55:'小雨',56:'雨夹雪',57:'雨夹雪',
  61:'小雨',63:'中雨',65:'大雨',66:'雨夹雪',67:'雨夹雪',
  71:'小雪',73:'中雪',75:'大雪',77:'小雪',
  80:'小雨',81:'中雨',82:'大雨',85:'中雪',86:'大雪',
  95:'雷阵雨',96:'雷阵雨',99:'雷阵雨'
};
function wmoText(c) { return WMO_TEXT[c] || '-'; }
function wmoKind(c) {
  if (c === 0 || c === 1) return 'SUN';
  if (c === 2) return 'PARTLY';
  if (c === 3) return 'CLOUD';
  if (c === 45 || c === 48) return 'FOG';
  if ([51,53,55,61,63,65,80,81,82].indexOf(c) >= 0) return 'RAIN';
  if ([56,57,66,67].indexOf(c) >= 0) return 'SLEET';
  if ([71,73,75,77,85,86].indexOf(c) >= 0) return 'SNOW';
  if ([95,96,99].indexOf(c) >= 0) return 'THUNDER';
  return 'UNKNOWN';
}
function nmcTextKind(t) { /* native nmcSkyconKind */
  if (!t) return 'UNKNOWN';
  if (t.indexOf('雷') >= 0) return 'THUNDER';
  if (t.indexOf('雪') >= 0) return 'SNOW';
  if (t.indexOf('雨夹雪') >= 0) return 'SLEET';
  if (t.indexOf('雨') >= 0) return 'RAIN';
  if (t.indexOf('晴') >= 0) return 'SUN';
  if (t.indexOf('云') >= 0) return 'PARTLY';
  if (t.indexOf('阴') >= 0) return 'CLOUD';
  if (t.indexOf('雾') >= 0) return 'FOG';
  if (t.indexOf('霾') >= 0 || t.indexOf('尘') >= 0 || t.indexOf('沙') >= 0) return 'HAZE';
  if (t.indexOf('风') >= 0) return 'WIND';
  return 'UNKNOWN';
}
var KIND_ICON = { SUN:'☀️', PARTLY:'⛅', CLOUD:'☁️', RAIN:'🌧️', SNOW:'❄️', THUNDER:'⛈️', FOG:'🌫️', SLEET:'🌨️', WIND:'🌬️', HAZE:'😷', UNKNOWN:'' };

/* ---- Canvas 天气图标：复刻 native WeatherIcon.kt 几何与配色 ---- */
var IC = { sun:'#f6a821', cloud:'#7c97ab', rain:'#3fa3f0', bolt:'#f2a93b', snow:'#90caf9', fog:'#b0bec5' };
var KIND_NORM = { SUN:.80, MOON:1.08, PARTLY:.68, CLOUD:.98, RAIN:1.06, SNOW:1.06, THUNDER:.94, SLEET:1.06, FOG:1.22, HAZE:1.22, WIND:.98, UNKNOWN:1.10 };

function paintIcon(cv, kind) {
  var ctx = cv.getContext && cv.getContext('2d');
  if (!ctx) return;
  var u = cv.width / 100;                 /* 单位换算：设计视图 0..100 */
  var s = (KIND_NORM[kind] || 1.10) * 100 * u;
  var cx = 50 * u, cy = 50 * u;
  function C(v){ return v; }             /* 占位保持可读 */
  function cloudBody(ccx, ccy, cs) {
    ctx.fillStyle = IC.cloud;
    ctx.beginPath(); ctx.arc(ccx - .30*cs, ccy - .15*cs, .27*cs, 0, 6.284); ctx.fill();
    ctx.beginPath(); ctx.arc(ccx,            ccy - .30*cs, .34*cs, 0, 6.284); ctx.fill();
    ctx.beginPath(); ctx.arc(ccx + .32*cs, ccy - .13*cs, .27*cs, 0, 6.284); ctx.fill();
    ctx.fillRect(ccx - .50*cs, ccy - .08*cs, cs, .40*cs);
  }
  function line(x1,y1,x2,y2,color,w) {
    ctx.strokeStyle = color; ctx.lineWidth = w;
    ctx.beginPath(); ctx.moveTo(x1,y1); ctx.lineTo(x2,y2); ctx.stroke();
  }
  function rays(rcx, rcy, r1, r2, w) {
    for (var i = 0; i < 8; i++) {
      var a = i * 45 * Math.PI / 180;
      line(rcx + Math.cos(a)*r1, rcy + Math.sin(a)*r1, rcx + Math.cos(a)*r2, rcy + Math.sin(a)*r2, IC.sun, w);
    }
  }
  function flake(fx, fy, fr, fw) {
    for (var i = 0; i < 3; i++) {
      var a = i * Math.PI / 3;
      line(fx + Math.cos(a)*fr, fy + Math.sin(a)*fr, fx - Math.cos(a)*fr, fy - Math.sin(a)*fr, IC.snow, fw);
    }
    ctx.fillStyle = IC.snow; ctx.beginPath(); ctx.arc(fx, fy, fr*.22, 0, 6.284); ctx.fill();
  }
  switch (kind) {
    case 'SUN':
      ctx.fillStyle = IC.sun; ctx.beginPath(); ctx.arc(cx, cy, .30*s, 0, 6.284); ctx.fill();
      rays(cx, cy, .42*s, .60*s, .09*s); break;
    case 'MOON':
      ctx.fillStyle = IC.sun; ctx.beginPath(); ctx.arc(cx - .08*s, cy, .36*s, 0, 6.284); ctx.fill();
      ctx.fillStyle = '#ffffff'; ctx.beginPath(); ctx.arc(cx + .12*s, cy - .12*s, .30*s, 0, 6.284); ctx.fill();
      break;
    case 'CLOUD': cloudBody(cx, cy + .08*s, .72*s); break;
    case 'PARTLY':
      ctx.fillStyle = IC.sun; ctx.beginPath(); ctx.arc(cx - .30*s, cy - .30*s, .20*s, 0, 6.284); ctx.fill();
      rays(cx - .30*s, cy - .30*s, .27*s, .40*s, .07*s);
      cloudBody(cx + .16*s, cy + .22*s, .58*s); break;
    case 'RAIN':
      cloudBody(cx, cy - .16*s, .66*s);
      [-.22, 0, .22].forEach(function(dx){
        line(cx + dx*s, cy + .16*s, cx + dx*s - .05*s, cy + .36*s, IC.rain, .09*s); });
      break;
    case 'SNOW':
      cloudBody(cx, cy - .16*s, .66*s);
      [[-.20,.28],[0,.34],[.20,.28]].forEach(function(p){ flake(cx + p[0]*s, cy + p[1]*s, .085*s, .025*s); });
      break;
    case 'THUNDER':
      cloudBody(cx, cy - .18*s, .62*s);
      ctx.fillStyle = IC.bolt; ctx.beginPath();
      ctx.moveTo(cx - .06*s, cy + .08*s); ctx.lineTo(cx + .12*s, cy + .08*s);
      ctx.lineTo(cx - .02*s, cy + .28*s); ctx.lineTo(cx + .12*s, cy + .28*s);
      ctx.lineTo(cx - .14*s, cy + .50*s); ctx.lineTo(cx - .04*s, cy + .30*s);
      ctx.lineTo(cx - .12*s, cy + .30*s); ctx.closePath(); ctx.fill();
      break;
    case 'SLEET':
      cloudBody(cx, cy - .16*s, .66*s);
      line(cx - .18*s, cy + .18*s, cx - .12*s, cy + .36*s, IC.rain, .09*s);
      line(cx + .18*s, cy + .18*s, cx + .24*s, cy + .36*s, IC.rain, .09*s);
      flake(cx, cy + .34*s, .09*s, .025*s);
      break;
    case 'FOG': case 'HAZE':
      cloudBody(cx, cy - .20*s, .52*s);
      for (var fi = 0; fi < 3; fi++) {
        var fy = cy + s*(.05 + fi*.16), half = s*(.34 - fi*.05);
        line(cx - half, fy, cx + half, fy, IC.fog, .10*s);
      }
      break;
    case 'WIND':
      line(cx - .38*s, cy - .18*s, cx + .38*s, cy - .18*s, IC.cloud, .10*s);
      ctx.strokeStyle = IC.cloud; ctx.lineWidth = .10*s; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.arc(cx - .23*s, cy + .00*s, .15*s, Math.PI, Math.PI*1.5); ctx.stroke();
      ctx.beginPath(); ctx.arc(cx + .04*s, cy + .17*s, .15*s, Math.PI*1.1, Math.PI*1.9); ctx.stroke();
      break;
    default: cloudBody(cx, cy + .06*s, .60*s);
  }
}
function paintAllIcons(root) { /* 对容器内所有标记 canvas 批量绘制 */
  var list = (root || document).querySelectorAll('canvas[data-kind]');
  for (var i = 0; i < list.length; i++) {
      var c = list[i];
      paintIcon(c, c.getAttribute('data-kind'));
  }
}

function windDirName(deg) {
  var dirs = ['北风','东北风','东风','东南风','南风','西南风','西风','西北风'];
  return dirs[Math.floor((deg + 22.5) / 45) % 8];
}
function beaufort(kmh) {
  var mps = kmh / 3.6;
  var b = mps < 0.3 ? 0 : mps < 1.6 ? 1 : mps < 3.4 ? 2 : mps < 5.5 ? 3 : mps < 8 ? 4
        : mps < 10.8 ? 5 : mps < 13.9 ? 6 : mps < 17.2 ? 7 : mps < 20.8 ? 8 : 9;
  return b + '级';
}
function aqiTextOf(v) {
  if (v <= 50) return '优';
  if (v <= 100) return '良';
  if (v <= 150) return '轻度污染';
  if (v <= 200) return '中度污染';
  if (v <= 300) return '重度污染';
  return '严重污染';
}
function uvLevelText(uv) { return uv < 3 ? '弱' : uv < 6 ? '中等' : uv < 8 ? '强' : uv < 11 ? '很强' : '极强'; }

/* 名称归一化（native simp / stripAdmin） */
var TRAD_MAP = { '東':'东','濟':'济','廣':'广','陽':'阳','陰':'阴','臺':'台','灣':'湾','龍':'龙','雲':'云','島':'岛','縣':'县','區':'区','寧':'宁','蘇':'苏','澤':'泽','漢':'汉','濱':'滨','豐':'丰','麗':'丽','門':'门','華':'华','廈':'厦','閩':'闽','贛':'赣','晉':'晋','陝':'陕','貴':'贵','瓊':'琼','遼':'辽','臨':'临','萊':'莱','蕪':'芜','長':'长','慶':'庆','榮':'荣','單':'单','費':'费','濰':'潍','諸':'诸','兗':'兖','嶧':'峄','鄆':'郓','棲':'栖','遠':'远','樂':'乐','無':'无','蓮':'莲','齊':'齐','蘭':'兰','鄉':'乡','膠':'胶','黃':'黄','饒':'饶','興':'兴','棗':'枣','莊':'庄','幹':'干','烏':'乌','雙':'双','澳':'澳','蒼':'苍','潁':'颍','滁':'滁','亳':'亳','懷':'怀','滬':'沪','渝':'渝','豫':'豫','冀':'冀','蒙':'蒙','吉':'吉','黑':'黑','浙':'浙','皖':'皖','魯':'鲁','鄂':'鄂','湘':'湘','粵':'粤','桂':'桂','川':'川','黔':'黔','滇':'滇','藏':'藏','甘':'甘','青':'青','新':'新' };
function simp(s) { s = s || ''; var o = ''; for (var i = 0; i < s.length; i++) o += (TRAD_MAP[s[i]] || s[i]); return o; }
function stripAdmin(n) { return (n || '').trim().replace(/(自治区|自治州|特别行政区|省|市|区|县|盟|州)$/, ''); }

function cleanNum(v) { return (v === null || v === undefined || isNaN(v)) ? null : (v <= -9000 || v >= 9998 ? null : v); }
function cleanInt(v) { return (v === null || v === undefined || isNaN(v)) ? null : (v >= 9998 ? null : Math.round(v)); }
function cleanNmcText(s) { if (!s) return ''; var v = String(s).trim(); return (v === '' || v === '9999' || v === '0') ? '' : v; }
function tempStr(v) { var n = cleanNum(v); return n === null ? '-' : Math.round(n); }
function combineDayNight(day, night) { return (!night || night === day) ? day : day + '转' + night; }

/* ================= 状态与持久化 ================= */
var state = {
  city: DEFAULT_CITY.name,
  cityCode: '',
  lat: DEFAULT_CITY.lat,
  lon: DEFAULT_CITY.lon,
  manualCity: false,
  useGps: true,
  source: 'openmeteo',
  fontSize: 'large',
  refreshInterval: '30',
  autoCheckUpdate: true
};
var refreshTimer = null, lastHideTime = 0, refreshing = false;

function saveState() {
  try {
    localStorage.setItem('cyanweather.state', JSON.stringify(state));
  } catch (e) { }
}
function loadState() {
  try {
    var raw = localStorage.getItem('cyanweather.state');
    if (!raw) return false;
    var s = JSON.parse(raw);
    if (!s) return false;
    if (s.city && s.lat != null && s.lon != null) { state.city = s.city; state.lat = s.lat; state.lon = s.lon; }
    state.cityCode = s.cityCode || '';
    state.manualCity = !!s.manualCity;
    state.useGps = s.useGps !== false;
    state.source = s.source === 'nmc' ? 'nmc' : 'openmeteo';
    state.fontSize = s.fontSize || 'large';
    state.refreshInterval = s.refreshInterval || '30';
    state.autoCheckUpdate = s.autoCheckUpdate !== false;
    return !!(s.city);
  } catch (e) { return false; }
}

/* ================= 工具 ================= */
function $(id) { return document.getElementById(id); }
function pad(n) { return n < 10 ? '0' + n : '' + n; }
function ymd(x) { var d = new Date(x); return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
function applyFontSize() {
  var map = { standard: '16px', large: '21px', xlarge: '26px' };
  document.documentElement.style.fontSize = map[state.fontSize] || '21px';
}
function hourCardHTML(timeStr, temperature, cond, icon, rainProb) {
  var h = '<div class="hour-item">' +
    '<div class="hour-date">' + timeStr.substring(5, 10).replace('-', '/') + '</div>' +
    '<div class="hour-time">' + parseInt(timeStr.substring(11, 13), 10) + '时</div>';
  if (icon) h += '<div class="hour-icon"><canvas width="34" height="34" data-kind="' + icon + '"></canvas></div>';
  if (cond) h += '<div class="hour-cond">' + cond + '</div>';
  h += '<div class="hour-temp">' + tempStr(temperature) + '°</div>';
  if (rainProb !== undefined && rainProb !== null && rainProb > 0) {
    h += '<div class="hour-pop" style="font-size:0.7rem;color:#0b6bcb;min-height:auto">' + Math.round(rainProb) + '%</div>';
  }
  return h + '</div>';
}
function dayLabelCN(dateStr) {
  try {
    var parts = dateStr.substring(0, 10).split(/[-\/]/);
    var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    var today = new Date();
    var diff = Math.round((d - new Date(today.getFullYear(), today.getMonth(), today.getDate())) / 86400000);
    var wd = ['周日','周一','周二','周三','周四','周五','周六'][d.getDay()];
    var md = (d.getMonth() + 1) + '月' + d.getDate() + '日';
    if (diff === 0) return '今天 ' + md + ' ' + wd;
    if (diff === 1) return '明天 ' + md + ' ' + wd;
    if (diff === 2) return '后天 ' + md + ' ' + wd;
    return md + ' ' + wd;
  } catch (e) { return dateStr; }
}

/* ================= Open-Meteo → 统一模型 ================= */
function fetchForecast(lat, lon) {
  var url = FC_URL +
    '?latitude=' + lat + '&longitude=' + lon +
    '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m' +
    '&hourly=temperature_2m,weather_code,precipitation_probability,relative_humidity_2m,apparent_temperature,uv_index' +
    '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max' +
    '&timezone=auto&forecast_days=15&past_days=1&temperature_unit=celsius';
  return fetch(url).then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); });
}
function fetchAqi(lat, lon) {
  var url = AQI_URL + '?latitude=' + lat + '&longitude=' + lon + '&current=us_aqi&timezone=auto';
  return fetch(url).then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); });
}
function searchCity(q) {
  var url = GEO_URL + '?name=' + encodeURIComponent(q) + '&count=10&language=zh&format=json';
  return fetch(url).then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function (d) { return d.results || []; });
}
function reverseGeocodeFull(lat, lon) {
  var url = REVERSE_URL + '?latitude=' + lat + '&longitude=' + lon + '&localityLanguage=zh';
  return fetch(url).then(function (r) { return r.json(); })
    .then(function (g) { return { province: g.principalSubdivision || '', city: g.city || '', locality: g.locality || '' }; })
    .catch(function () { return { province: '', city: '', locality: '' }; });
}

function mapOpenMeteo(w, air, cityNameOverride) {
  var c = w.current, daily = w.daily, hourly = w.hourly;
  var nowYmd = ymd(new Date());
  var ti = daily.time.indexOf(nowYmd);

  var items = [];
  for (var i = 0; i < hourly.time.length; i++) {
    if (hourly.time[i] >= c.time) {
      items.push({ time: hourly.time[i], temperature: cleanNum(hourly.temperature_2m[i]),
        condition: wmoText(hourly.weather_code[i]), isForecast: true,
        rainProb: cleanNum(hourly.precipitation_probability[i]),
        icon: wmoKind(hourly.weather_code[i]) });
      if (items.length >= 48) break;
    }
  }
  var dailyList = [];
  for (var j = ti >= 0 ? ti : 0; j < daily.time.length; j++) {
    dailyList.push({ date: daily.time[j],
      dayText: wmoText(daily.weather_code[j]), nightText: '',
      high: cleanNum(daily.temperature_2m_max[j]), low: cleanNum(daily.temperature_2m_min[j]),
      icon: wmoKind(daily.weather_code[j]) });
  }
  var aqi = air && air.current ? cleanInt(air.current.us_aqi) : null;
  var uv = ti >= 0 ? cleanNum(daily.uv_index_max[ti]) : null;

  return {
    cityName: cityNameOverride || state.city || '未识别位置',
    updatedAt: (c.time && c.time.length >= 16) ? c.time.substring(5, 16).replace('T', ' ') : '',
    temperature: cleanNum(c.temperature_2m),
    condition: wmoText(c.weather_code),
    feelsLike: cleanNum(c.apparent_temperature),
    humidity: cleanInt(c.relative_humidity_2m),
    windDirect: c.wind_direction_10m != null ? windDirName(c.wind_direction_10m) : '',
    windPower: c.wind_speed_10m != null ? beaufort(c.wind_speed_10m) : '',
    todayHigh: ti >= 0 ? cleanNum(daily.temperature_2m_max[ti]) : null,
    todayLow: ti >= 0 ? cleanNum(daily.temperature_2m_min[ti]) : null,
    aqi: aqi, aqiText: aqi !== null ? aqiTextOf(aqi) : '',
    warning: null,
    sunrise: ti >= 0 ? (daily.sunrise[ti] || '').slice(11, 16) : '',
    sunset: ti >= 0 ? (daily.sunset[ti] || '').slice(11, 16) : '',
    uvIndex: uv !== null ? uvLevelText(uv) + '（' + Math.round(uv) + '）' : '',
    sourceTag: '数据来源：Open-Meteo',
    hourly: items, hourlyLabel: '未来48小时逐时预报',
    daily: dailyList,
    yesterday: ti >= 1 ? { high: cleanNum(daily.temperature_2m_max[ti - 1]), low: cleanNum(daily.temperature_2m_min[ti - 1]), hourly: [] } : null
  };
}

/* ================= NMC（中央气象台）→ 统一模型 ================= */
function nmcGet(path) {
  return fetch(NMC_BASE + path).then(function (r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  });
}
function nmcLoadProvinces() { return nmcGet('/rest/province'); }
function nmcLoadCities(code) { return nmcGet('/rest/province/' + code); }

function resolveBeijingCode() {
  return nmcLoadProvinces().then(function (provs) {
    var bj = null;
    for (var i = 0; i < provs.length; i++) if ((provs[i].name || '').indexOf('北京') >= 0) { bj = provs[i]; break; }
    bj = bj || provs[0];
    return nmcLoadCities(bj.code).then(function (cities) {
      var c = null;
      for (var k = 0; k < cities.length; k++) if ((cities[k].city || '').indexOf('北京') >= 0) { c = cities[k]; break; }
      return (c || cities[0]).code;
    });
  });
}

function nmcMatch(g, c) { /* native matches() */
  var full = simp(c.city).trim();
  if (!full) return false;
  var stripped = stripAdmin(full);
  return full === g || g.indexOf(full) === 0 || g.indexOf(full) >= 0 ||
    (stripped.length >= 2 && (stripped === g || g.indexOf(stripped) === 0 || g.indexOf(stripped) >= 0));
}
function resolveNmcByLocation(lat, lng) {
  return reverseGeocodeFull(lat, lng).then(function (geo) {
    var provName = simp(geo.province).trim();
    var cityName = simp(geo.city).trim();
    var locName = simp(geo.locality).trim();
    if (!provName && !cityName && !locName) throw new Error('定位失败，无法自动选择城市');
    return nmcLoadProvinces().then(function (provs) {
      var prov = null;
      var i;
      for (i = 0; i < provs.length; i++) {
        var n = stripAdmin(simp(provs[i].name));
        if (n && provName.indexOf(n) >= 0) { prov = provs[i]; break; }
      }
      if (!prov) for (i = 0; i < provs.length; i++) {
        var n2 = stripAdmin(simp(provs[i].name));
        if (n2 && (cityName.indexOf(n2) >= 0 || locName.indexOf(n2) >= 0)) { prov = provs[i]; break; }
      }
      prov = prov || provs[0];
      return nmcLoadCities(prov.code).then(function (cities) {
        var geoParts = [];
        if (locName) geoParts.push(locName);
        if (cityName) geoParts.push(cityName);
        var picked = null, gi, ci;
        for (gi = 0; gi < geoParts.length && !picked; gi++)
          for (ci = 0; ci < cities.length; ci++)
            if (nmcMatch(geoParts[gi], cities[ci])) { picked = cities[ci]; break; }
        picked = picked || cities[0];
        var displayName = locName || cityName || picked.city;
        return { name: displayName, code: picked.code };
      });
    });
  });
}

function parseNmc(data, cityName) { /* native parseNmc 完整移植 */
  if (!data) throw new Error('气象局暂无数据');
  var real = data.real || {};
  var weather = real.weather || {};
  var wind = real.wind || {};

  var todayHigh, todayLow, daily = [];
  var predict = (data.predict && data.predict.detail) || [];
  var i, d;
  if (predict.length) {
    var first = predict[0];
    var curT = cleanNum(weather.temperature);
    todayHigh = (first.day && first.day.weather && first.day.weather.temperature != null)
      ? cleanNum(parseFloat(first.day.weather.temperature)) : curT;
    todayLow = (first.night && first.night.weather && first.night.weather.temperature != null)
      ? cleanNum(parseFloat(first.night.weather.temperature)) : curT;
    for (i = 0; i < predict.length; i++) {
      d = predict[i];
      var dw = (d.day && d.day.weather) || {}, nw = (d.night && d.night.weather) || {};
      daily.push({
        date: d.date,
        dayText: cleanNmcText(dw.info), nightText: cleanNmcText(nw.info),
        high: dw.temperature != null ? cleanNum(parseFloat(dw.temperature)) : null,
        low: nw.temperature != null ? cleanNum(parseFloat(nw.temperature)) : null,
        icon: nmcTextKind(cleanNmcText(dw.info))
      });
    }
  } else {
    var tc = data.tempchart || [];
    var lastTc = tc[tc.length - 1] || {};
    todayHigh = cleanNum(lastTc.maxTemp);
    todayLow = cleanNum(lastTc.minTemp);
    for (i = 0; i < tc.length; i++) {
      var t = tc[i];
      if (cleanNum(t.maxTemp) == null && cleanNum(t.minTemp) == null) continue;
      var dt = cleanNmcText(t.dayText) || cleanNmcText(t.nightText);
      daily.push({ date: String(t.time).replace(/\//g, '-'),
        dayText: dt, nightText: cleanNmcText(t.nightText),
        high: cleanNum(t.maxTemp), low: cleanNum(t.minTemp),
        icon: nmcTextKind(dt) });
    }
  }

  var passed = [];
  var pc = data.passedchart || [];
  for (i = 0; i < pc.length; i++) {
    if (pc[i].temperature != null && cleanNum(pc[i].temperature) !== null) passed.push(pc[i]);
  }
  passed.sort(function (a, b) { return a.time < b.time ? -1 : 1; });
  var passedItems = passed.map(function (p) {
    return { time: p.time, temperature: cleanNum(p.temperature), condition: '', isForecast: false, icon: '' };
  });

  var yesterday = null;
  var today = ymd(new Date());
  var yItems = passedItems.filter(function (it) { return it.time.indexOf(today) !== 0; }).slice(-24);
  if (yItems.length) {
    var hi = -999, lo = 999;
    for (i = 0; i < yItems.length; i++) {
      var tv = yItems[i].temperature;
      if (tv !== null && tv > hi) hi = tv;
      if (tv !== null && tv < lo) lo = tv;
    }
    yesterday = { high: hi > -999 ? hi : null, low: lo < 999 ? lo : null, hourly: yItems };
  }

  var warn = real.warn && real.warn.alert && real.warn.alert !== '9999' ? real.warn.alert : '';

  return {
    cityName: cityName || (real.station && real.station.city) || '',
    updatedAt: real.publish_time || '',
    temperature: cleanNum(weather.temperature),
    condition: cleanNmcText(weather.info),
    feelsLike: cleanNum(weather.feelst),
    humidity: weather.humidity != null ? cleanInt(weather.humidity) : null,
    windDirect: cleanNmcText(wind.direct),
    windPower: cleanNmcText(wind.power),
    todayHigh: todayHigh, todayLow: todayLow,
    aqi: data.air ? cleanInt(data.air.aqi) : null,
    aqiText: (data.air && data.air.text) || '',
    warning: warn,
    sunrise: (real.sunriseSunset && real.sunriseSunset.sunrise || '').length >= 16 ? real.sunriseSunset.sunrise.substring(11, 16) : '',
    sunset: (real.sunriseSunset && real.sunriseSunset.sunset || '').length >= 16 ? real.sunriseSunset.sunset.substring(11, 16) : '',
    uvIndex: '',
    sourceTag: '数据来源：中央气象台',
    hourly: passedItems, hourlyLabel: '过去24小时逐时实况',
    daily: daily, yesterday: yesterday
  };
}

function resolveNmcStation() {
  /* 坐标已由 ensureGpsFix 刷新：GPS 时直接按坐标匹配气象站，否则用已存/默认站码 */
  var cn;
        dtrace('reverse cond: gps=' + state.useGps + ' manual=' + state.manualCity);
        if (state.useGps && !state.manualCity) {
    cn = resolveNmcByLocation(state.lat, state.lon).then(function (rc) {
      state.city = rc.name; state.cityCode = rc.code; state.manualCity = false;
      saveState();
      return rc;
    }).catch(function (e) {
      showNotice('站点匹配失败：' + e.message + '；使用默认城市北京');
      return { code: state.cityCode, name: state.city };
    });
  } else {
    cn = Promise.resolve({ code: state.cityCode, name: state.city });
  }
  return Promise.resolve(cn).then(function (c2) {
    if (c2.code) return c2;
    return resolveBeijingCode().then(function (code) {
      state.cityCode = code;
      saveState();
      return { code: code, name: c2.name || DEFAULT_CITY.name };
    });
  });
}
function loadNmcWeather() {
  return resolveNmcStation().then(function (cn) {
    return nmcGet('/rest/weather?stationid=' + cn.code).then(function (resp) {
      return parseNmc(resp.data, cn.name);
    });
  });
}

/* ================= GPS 桥接 =================
   WebF 回调形状存在两种可能：(err,data) 双参 或 (result) 单参。
   Dart 端返回 JSON 字符串。这里全部兼容，12 秒超时。 */
function dtrace(m) { try { var b = getNativeBridge(); if (b) b.invokeModule('GPS', 'trace', [m], function(){}); } catch (e) { } }
function getNativeBridge() {
  try { if (typeof webf !== 'undefined' && webf && typeof webf.invokeModule === 'function') return webf; } catch (e) { }
  try { if (typeof kraken !== 'undefined' && kraken && typeof kraken.invokeModule === 'function') return kraken; } catch (e) { }
  return null;
}
function locateViaBridge() {
  return new Promise(function (resolve, reject) {
    try {
      var bridge = getNativeBridge();
      if (bridge) {
        /* 首选：同步读取原生缓存的定位结果（原生启动即后台解析） */
        var attempts = 0;
        var poll = function () {
          var ret = null;
          try { ret = bridge.invokeModule('GPS', 'getLocation', [], function () { }); } catch (e) { }
          try {
            if (typeof ret === 'string') ret = JSON.parse(ret);
          } catch (e) { ret = null; }
          if (ret && typeof ret.latitude === 'number') {
            resolve({ lat: ret.latitude, lon: ret.longitude });
            return;
          }
          if (++attempts > 10) { reject(new Error('定位暂不可用，已使用上次位置')); return; }
          setTimeout(poll, 2000);
        };
        poll();
        return;
      }
    } catch (e) { }
    reject(new Error('no-bridge'));
  });
}

function paintGlyph(el, kind, px) {
  el.innerHTML = '<canvas width="' + px + '" height="' + px + '"></canvas>';
  var c = el.firstChild; paintIcon(c, kind);
}
/* ================= 渲染（统一模型） ================= */
function renderWeather(w) {
  $('cityName').textContent = w.cityName || state.city;
  $('updatedAt').textContent = w.updatedAt || '';
  $('curTemp').textContent = tempStr(w.temperature);
  $('curUnit').textContent = '°C';
  $('curCond').textContent = w.condition || '-';
  paintGlyph($('weatherGlyph'), nmcTextKind(w.condition), 96);
  $('todayHigh').textContent = tempStr(w.todayHigh) + '°';
  $('todayLow').textContent = tempStr(w.todayLow) + '°';
  $('feelsLike').textContent = tempStr(w.feelsLike) + '°';

  $('sunrise').textContent = w.sunrise || '-';
  $('sunset').textContent = w.sunset || '-';

  $('humidityVal').textContent = w.humidity != null ? w.humidity + '%' : '-';
  $('windVal').textContent = ((w.windDirect || '') + ' ' + (w.windPower || '')).trim() || '-';
  $('aqiVal').textContent = w.aqi != null ? (w.aqiText ? w.aqiText + ' ' : '') + w.aqi : '-';
  $('uvVal').textContent = w.uvIndex || '-';

  /* 预警横幅 */
  if (w.warning) {
    $('warnCard').innerHTML = '<div class="warn-title">⚠️ 气象预警</div><div class="warn-body">' + w.warning + '</div>';
    $('warnCard').classList.remove('hidden');
  } else {
    $('warnCard').classList.add('hidden');
  }

  /* 逐小时 */
  var hh = '';
  for (var i = 0; i < w.hourly.length; i++) {
    var it = w.hourly[i];
    hh += hourCardHTML(it.time, it.temperature, it.isForecast ? it.condition : '', it.icon, it.rainProb);
  }
  $('hourlyLabel').textContent = w.hourlyLabel;
  $('hourly').innerHTML = hh || '<div class="empty-tip">暂无数据</div>';

  /* 多日 */
  var dh = '';
  for (var j = 0; j < w.daily.length; j++) {
    var dd = w.daily[j];
    dh += '<div class="day-row">' +
      '<span class="day-name">' + dayLabelCN(dd.date) + '</span>' +
      '<div class="day-main">' +
      (dd.icon ? '<span class="day-icon"><canvas width="30" height="30" data-kind="' + dd.icon + '"></canvas></span>' : '') +
      '<span class="day-cond">' + combineDayNight(dd.dayText, dd.nightText) + '</span>' +
      '<span class="day-temp"><span class="day-high">' + tempStr(dd.high) + '°</span>' +
      '<span class="day-slash">/</span>' +
      '<span class="day-low">' + tempStr(dd.low) + '°</span></span>' +
      '</div></div>';
  }
  $('dailyLabel').textContent = '未来多日预报（' + w.daily.length + '天）';
  $('daily').innerHTML = dh || '<div class="empty-tip">暂无数据</div>';

  /* 昨日 */
  if (w.yesterday && (w.yesterday.high != null || w.yesterday.low != null)) {
    $('yestHigh').textContent = tempStr(w.yesterday.high) + '°';
    $('yestLow').textContent = tempStr(w.yesterday.low) + '°';
    var yh = '';
    for (var k = 0; k < (w.yesterday.hourly || []).length; k++) {
      var yy = w.yesterday.hourly[k];
      yh += '<div class="yh-item"><div class="yh-time">' + parseInt(yy.time.substring(11, 13), 10) + '时</div>' +
        '<div class="yh-temp">' + tempStr(yy.temperature) + '°</div></div>';
    }
    $('yestHourly').innerHTML = yh;
    $('yestHourly').style.display = yh ? 'flex' : 'none';
    $('yesterdayCard').classList.remove('hidden');
  } else {
    $('yesterdayCard').classList.add('hidden');
  }

  /* 降雨提醒 + 趋势（仅预报类源；NMC 无逐时预报） */
  if (w.sourceTag.indexOf('中央气象台') < 0) {
    renderRainTip(w);
    renderRainTrend(w);
  } else {
    $('rainTipCard').classList.add('hidden');
    $('rainBlock').classList.add('hidden');
  }

  $('sourceFooter').textContent = w.sourceTag;
  paintAllIcons($('content'));
  $('content').classList.remove('error-mode');
}

function renderRainTip(w) {
  var upcoming = [], i;
  for (i = 0; i < w.hourly.length && upcoming.length < 12; i++) {
    if (w.hourly[i].isForecast) upcoming.push(w.hourly[i].condition || '');
  }
  var tip = null, idx = -1;
  for (i = 0; i < upcoming.length; i++) {
    if (upcoming[i].indexOf('雨') >= 0 || upcoming[i].indexOf('雷') >= 0) { idx = i; break; }
  }
  if (idx >= 0) {
    tip = idx <= 1 ? '现在或很快有降雨，出门请带伞' : '预计约 ' + idx + ' 小时后可能有降雨，出门请带伞';
  } else {
    for (i = 0; i < w.daily.length && i < 3; i++) {
      var txt = combineDayNight(w.daily[i].dayText, w.daily[i].nightText);
      if (txt.indexOf('雨') >= 0 || txt.indexOf('雷') >= 0) { tip = '近期可能有雨，请留意天气变化'; break; }
    }
  }
  if (tip) { $('rainTipText').textContent = tip; $('rainTipCard').classList.remove('hidden'); }
  else $('rainTipCard').classList.add('hidden');
}

function renderRainTrend(w) {
  var cols = [], i;
  for (i = 0; i < w.hourly.length && cols.length < 24; i++) {
    var it = w.hourly[i];
    if (!it.isForecast) continue;
    cols.push({ label: it.time.substring(5, 10).replace('-', '/') + ' ' + parseInt(it.time.substring(11, 13), 10) + '时',
      pct: it.rainProb == null ? 0 : it.rainProb });
  }
  if (!cols.length) { $('rainBlock').classList.add('hidden'); return; }
  $('rainBlock').classList.remove('hidden');
  var html = '';
  for (var j = 0; j < cols.length; j++) {
    var cc = cols[j];
    var barH = Math.max(cc.pct > 0 ? 6 : 2, Math.round(cc.pct * 0.9));
    html += '<div class="rain-col">' +
      '<div class="rain-pct">' + (cc.pct > 0 ? cc.pct + '%' : '') + '</div>' +
      '<div class="rain-bar-wrap"><div class="rain-bar" style="height:' + barH + '%"></div></div>' +
      '<div class="rain-label">' + cc.label + '</div></div>';
  }
  $('rain').innerHTML = html;
}

/* ================= 提示 / 错误 / 遮罩 ================= */
function showNotice(msg) {
  var box = $('noticeBox');
  box.innerHTML = msg ? '<div class="notice-card">⚠ ' + msg + '</div>' : '';
}
function showErrorBanner(msg) { $('errorBox').textContent = msg; $('errorBox').classList.remove('hidden'); }
function clearErrors() { $('errorBox').classList.add('hidden'); showNotice(null); }
function showErrorFull(msg) {
  $('content').classList.add('error-mode');
  var old = $('errorFull');
  if (old) old.remove();
  var div = document.createElement('div');
  div.className = 'error-full';
  div.id = 'errorFull';
  div.innerHTML = '<div class="error-msg">' + msg + '</div><button class="big-btn" id="retryBtn">重新获取</button>';
  $('content').appendChild(div);
  div.querySelector('#retryBtn').addEventListener('click', function () { fullRefresh(); });
}
function setRefreshing(on) {
  $('refreshOverlay').classList.toggle('hidden', !on);
  $('refreshBtn').classList.toggle('spinning', on);
}

/* ================= 刷新主流程 ================= */
/* 统一定位前置：useGps 且非手动城市时先取真实坐标 */
function ensureGpsFix() {
  if (!(state.useGps && !state.manualCity)) return Promise.resolve();
  return locateViaBridge().then(function (pos) {
    state.lat = pos.lat;
    state.lon = pos.lon;
    saveState();
    return null;
  }).catch(function (e) {
    showNotice('定位失败：' + e.message + '，当前使用上次位置');
    return null;
  });
}

function fullRefresh() {
  dtrace('fullRefresh src=' + state.source + ' gps=' + state.useGps + ' manual=' + state.manualCity + ' lat=' + state.lat);
  if (refreshing) { dtrace('fullRefresh skipped: refreshing'); return; }
  refreshing = true;
  if (refreshing) return;
  refreshing = true;
  clearErrors();
  setRefreshing(true);

  var p;
  if (state.source === 'nmc') {
    p = ensureGpsFix().then(loadNmcWeather);
  } else {
    p = ensureGpsFix().then(function () {
      return Promise.all([
        fetchForecast(state.lat, state.lon),
        fetchAqi(state.lat, state.lon).catch(function () { return null; })
      ]).then(function (rs) {
        /* openmeteo 城市名：GPS 时反向解析县区名 */
        if (state.useGps && !state.manualCity) {
          return reverseGeocodeFull(state.lat, state.lon).then(function (g) {
            var name = stripAdmin(simp(g.locality || g.city || '')) || '未识别位置';
            return mapOpenMeteo(rs[0], rs[1], name);
          });
        }
        return mapOpenMeteo(rs[0], rs[1], state.city);
      });
    });
  }

  p.then(function (w) {
    renderWeather(w);
    saveState();
  }).catch(function (e) {
    showErrorFull('天气数据获取失败：' + e.message);
  }).then(function () {
    refreshing = false;
    setRefreshing(false);
    armAutoRefresh();
  });
}

/* ================= 自动刷新 ================= */
function armAutoRefresh() {
  if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
  var minutes = parseInt(state.refreshInterval, 10);
  if (!isNaN(minutes) && minutes > 0) refreshTimer = setInterval(fullRefresh, minutes * 60000);
}
document.addEventListener('visibilitychange', function () {
  if (document.hidden) lastHideTime = Date.now();
  else if (state.refreshInterval === 'on_resume') {
    if (lastHideTime === 0 || Date.now() - lastHideTime > 30000) fullRefresh();
  }
});

/* ================= 城市搜索 ================= */

/* ================= 省市级联选择（中国气象局） ================= */
var cascLevel = 'province', cascProv = null;
function openCascade() {
  if (state.source !== 'nmc') { showNotice('省市级联需使用「中国气象局」数据源，请先在上方切换'); return; }
  $('cascadeModal').classList.remove('hidden');
  cascLevel = 'province'; cascProv = null;
  $('cascTitle').textContent = '选择省份';
  $('cascList').innerHTML = '<li class="empty-tip">加载中…</li>';
  $('cascBack').style.display = 'none';
  nmcLoadProvinces().then(function (ps) {
    var html = '';
    for (var i = 0; i < ps.length; i++) html += '<li data-code="' + ps[i].code + '" data-name="' + ps[i].name + '">' + ps[i].name + '</li>';
    $('cascList').innerHTML = html;
  }).catch(function (e) { $('cascList').innerHTML = '<li class="empty-tip">加载失败：' + e.message + '</li>'; });
}
function cascPickProvince(code, name) {
  cascProv = { code: code, name: name };
  cascLevel = 'city';
  $('cascTitle').textContent = name + ' · 选择城市/区县';
  $('cascList').innerHTML = '<li class="empty-tip">加载中…</li>';
  $('cascBack').style.display = 'block';
  nmcLoadCities(code).then(function (cs) {
    var html = '';
    for (var i = 0; i < cs.length; i++) html += '<li data-code="' + cs[i].code + '" data-name="' + cs[i].city + '">' + cs[i].city + '</li>';
    $('cascList').innerHTML = html || '<li class="empty-tip">该省份暂无站点</li>';
  }).catch(function (e) { $('cascList').innerHTML = '<li class="empty-tip">加载失败：' + e.message + '</li>'; });
}
function cascPickCity(code, name) {
  state.city = stripAdmin(name);
  state.cityCode = code;
  state.manualCity = true;
  saveState();
  $('cascadeModal').classList.add('hidden');
  fullRefresh();
}
function doSearch(q) {
  if (!q) return;
  $('searchResults').innerHTML = '<li class="empty-tip">搜索中…</li>';
  searchCity(q).then(function (results) {
    if (!results.length) { $('searchResults').innerHTML = '<li class="empty-tip">未找到该城市</li>'; return; }
    var html = '';
    for (var i = 0; i < results.length; i++) {
      var r = results[i];
      var sub = [r.admin1, r.country].filter(Boolean).join('，');
      html += '<li data-lat="' + r.latitude + '" data-lon="' + r.longitude + '" data-name="' + r.name + '">' +
        r.name + '<div class="result-sub">' + sub + '</div></li>';
    }
    $('searchResults').innerHTML = html;
  }).catch(function (e) {
    $('searchResults').innerHTML = '<li class="empty-tip">搜索失败：' + e.message + '</li>';
  });
}
$('searchResults').addEventListener('click', function (ev) {
  var li = ev.target.closest('li[data-lat]');
  if (!li) return;
  state.city = li.getAttribute('data-name');
  state.lat = parseFloat(li.getAttribute('data-lat'));
  state.lon = parseFloat(li.getAttribute('data-lon'));
  state.manualCity = true;
  saveState();
  closeSearch();
  if (state.source === 'nmc') {
    /* NMC：按所选坐标匹配气象站 */
    resolveNmcByLocation(state.lat, state.lon).then(function (rc) {
      state.city = rc.name; state.cityCode = rc.code;
      saveState();
  dtrace('init: calling fullRefresh');
  fullRefresh();
    }).catch(function () { fullRefresh(); });
  } else {
    fullRefresh();
  }
});

/* ================= 设置 ================= */
function syncSettingsUI() {
  document.getElementById('src' + (state.source === 'nmc' ? 'Nmc' : 'OpenMeteo')).checked = true;
  document.getElementById('font' + ({ standard: 'Standard', large: 'Large', xlarge: 'XLarge' }[state.fontSize] || 'Large')).checked = true;
  var refMap = { off: 'refOff', on_resume: 'refResume', '10': 'ref10', '30': 'ref30', '60': 'ref60', '360': 'ref360', '720': 'ref720', '1440': 'ref1440' };
  var refEl = document.getElementById(refMap[state.refreshInterval] || 'ref30');
  if (refEl) refEl.checked = true;
  $('useGps').checked = state.useGps;
  $('autoCheckUpdate').checked = state.autoCheckUpdate;
  $('cityEntryName').textContent = state.city;
}
function bindRadioGroup(name, handler) {
  var radios = document.querySelectorAll('input[name="' + name + '"]');
  for (var i = 0; i < radios.length; i++) {
    radios[i].addEventListener('change', function () { if (this.checked) handler(this.value); });
  }
}

/* ================= 检查更新 ================= */
function versionCompare(a, b) {
  var pa = String(a).replace(/^v/, '').split('.'), pb = String(b).replace(/^v/, '').split('.');
  for (var i = 0; i < 3; i++) {
    var da = parseInt(pa[i], 10) || 0, db = parseInt(pb[i], 10) || 0;
    if (da > db) return 1;
    if (da < db) return -1;
  }
  return 0;
}
function checkUpdate(manual) {
  try {
    fetch('https://api.github.com/repos/upcyan/cyanweather/releases/latest')
      .then(function (r) { if (!r.ok) throw 0; return r.json(); })
      .then(function (rel) {
        var latest = (rel.tag_name || '').replace(/^v/, '');
        if (!latest || versionCompare(latest, APP_VERSION) <= 0) {
          if (manual) alert('当前已是最新版本 v' + APP_VERSION);
          return;
        }
        showUpdateDialog(latest, rel.body || '', rel.html_url || '');
      })
      .catch(function () { if (manual) alert('检查更新失败，请检查网络'); });
  } catch (e) { }
}
function showUpdateDialog(version, notes, url) {
  var old = $('updateModal');
  if (old) old.remove();
  var modal = document.createElement('div');
  modal.className = 'modal';
  modal.id = 'updateModal';
  modal.innerHTML =
    '<div class="modal-box" style="max-height:none">' +
    '<div class="setting-card" style="margin:14px">' +
    '<b>发现新版本 v' + version + '</b>' +
    '<div class="about-text" style="margin-bottom:12px">' + String(notes || '').split('\n').slice(0, 6).join('<br/>') + '</div>' +
    '<button class="big-btn" id="updateGo" style="width:100%;font-size:1rem;padding:10px 0;margin-bottom:8px">立即更新</button>' +
    '<button class="check-update-btn" id="updateLater"><span style="text-align:center;width:100%">以后再说</span></button>' +
    '</div></div>';
  document.body.appendChild(modal);
  modal.querySelector('#updateGo').addEventListener('click', function () {
    try { window.open(url, '_blank'); } catch (e) { }
    try { window.location.href = url; } catch (e) { }
  });
  modal.querySelector('#updateLater').addEventListener('click', function () { modal.remove(); });
}

/* ================= 初始化 ================= */
document.addEventListener('DOMContentLoaded', function () {
  loadState();
  applyFontSize();

  $('refreshBtn').addEventListener('click', fullRefresh);
  $('settingsBtn').addEventListener('click', function () {
    $('settingsModal').classList.remove('hidden');
    syncSettingsUI();
  });
  $('settingsClose').addEventListener('click', function () { $('settingsModal').classList.add('hidden'); });
  $('searchClose').addEventListener('click', function () { $('searchModal').classList.add('hidden'); });
  $('cascClose').addEventListener('click', function () { $('cascadeModal').classList.add('hidden'); });
  $('cascBack').addEventListener('click', function () {
    if (cascLevel === 'city') openCascade(); /* 回到省份列表 */
  });
  $('cascList').addEventListener('click', function (ev) {
    var node = ev.target;
    while (node && node !== this && !(node.tagName === 'LI' && node.getAttribute('data-code'))) node = node.parentNode;
    if (!node || node === this) return;
    var code = node.getAttribute('data-code'), name = node.getAttribute('data-name');
    if (cascLevel === 'province') cascPickProvince(code, name); else cascPickCity(code, name);
  });
  $('rainTipCard').addEventListener('click', function () {
    try { $('rainBlock').scrollIntoView({ behavior: 'smooth' }); } catch (e) { }
  });
  $('searchInput').addEventListener('keydown', function (ev) {
    if (ev.key === 'Enter') doSearch(this.value.trim());
  });

  /* 设置页整行点击即选中该 radio（不依赖 label/for 实现） */
  document.body.addEventListener('click', function (ev) {
    var node = ev.target, row = null;
    while (node && node !== document.body) {
      if (node.classList && node.classList.contains('radio-row')) { row = node; break; }
      node = node.parentNode;
    }
    if (!row) return;
    var inp = row.querySelector('input[type="radio"]');
    if (inp && !inp.checked) {
      inp.checked = true;
      try { inp.dispatchEvent(new Event('change')); } catch (e) {
        /* 兜底：手动按 name 分发 */
        var nm = inp.name, val = inp.value;
        var rs = document.querySelectorAll('input[name="' + nm + '"]');
        for (var i = 0; i < rs.length; i++) rs[i].checked = (rs[i] === inp);
        if (nm === 'src') { state.source = val; saveState(); fullRefresh(); }
        else if (nm === 'font') { state.fontSize = val; applyFontSize(); saveState(); }
        else if (nm === 'refresh') { state.refreshInterval = val; saveState(); armAutoRefresh(); }
      }
    }
  });

  bindRadioGroup('src', function (v) { state.source = v; saveState(); fullRefresh(); });
  bindRadioGroup('font', function (v) { state.fontSize = v; applyFontSize(); saveState(); });
  bindRadioGroup('refresh', function (v) { state.refreshInterval = v; saveState(); armAutoRefresh(); });
  $('useGps').addEventListener('change', function () { state.useGps = this.checked; saveState(); });
  $('autoCheckUpdate').addEventListener('change', function () { state.autoCheckUpdate = this.checked; saveState(); });
  $('manualCheckUpdate').addEventListener('click', function () { checkUpdate(true); });

  $('appVersion').textContent = 'v' + APP_VERSION;

  var cityEntry = document.createElement('div');
  cityEntry.className = 'city-entry';
  cityEntry.innerHTML = '<span>当前城市：<b id="cityEntryName">' + state.city + '</b></span><span class="go">更改 ›</span>';
  cityEntry.addEventListener('click', function () {
    $('searchModal').classList.remove('hidden');
    $('searchResults').innerHTML = '<li class="empty-tip">输入城市名搜索</li>';
    setTimeout(function () { $('searchInput').focus(); }, 50);
  });
  var body = document.querySelector('.settings-body');
  body.insertBefore(cityEntry, body.firstChild);

  var cascEntry = document.createElement('div');
  cascEntry.className = 'city-entry';
  cascEntry.innerHTML = '<span>省市级联选择（中国气象局）</span><span class="go">选择 ›</span>';
  cascEntry.addEventListener('click', function () { openCascade(); });
  body.insertBefore(cascEntry, cityEntry.nextSibling);

  if (state.autoCheckUpdate) checkUpdate(false);

  fullRefresh();
});