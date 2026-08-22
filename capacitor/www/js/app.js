const API = 'https://api.open-meteo.com/v1';
const REVERSE_GEO = 'https://api.bigdatacloud.net/data/reverse-geocode-client';

let settings = { source: 'openmeteo', fontSize: 'large', refreshInterval: '30', lat: 39.9042, lng: 116.4074, cityName: '' };
let refreshTimer = null;
let prefs = null;

async function init() {
    try { prefs = window.Capacitor?.Plugins?.Preferences; } catch(e) {}
    if (prefs) {
        const s = await prefs.get({ key: 'settings' });
        if (s.value) settings = { ...settings, ...JSON.parse(s.value) };
    }
    applyFontSize();
    await loadWeather();
    startAutoRefresh();
}

async function saveSettings() {
    if (prefs) await prefs.set({ key: 'settings', value: JSON.stringify(settings) });
}

function applyFontSize() {
    const sizes = { standard: '14px', large: '16px', xlarge: '18px' };
    document.body.style.fontSize = sizes[settings.fontSize] || '16px';
}

function startAutoRefresh() {
    if (refreshTimer) clearInterval(refreshTimer);
    const mins = parseInt(settings.refreshInterval);
    if (mins > 0) refreshTimer = setInterval(loadWeather, mins * 60 * 1000);
}

async function loadWeather() {
    const $ = id => document.getElementById(id);
    $('loading').style.display = 'block';
    $('error').style.display = 'none';
    $('weatherData').style.display = 'none';

    try {
        const lat = settings.lat, lng = settings.lng;
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000);
        const resp = await fetch(`${API}/forecast?latitude=${lat}&longitude=${lng}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,weather_code,precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto&forecast_days=15`, { signal: controller.signal });
        clearTimeout(timeoutId);
        if (!resp.ok) throw new Error('API请求失败: ' + resp.status);
        const json = await resp.json();

        let city = settings.cityName || '未识别位置';
        try {
            const g = await fetch(`${REVERSE_GEO}?latitude=${encodeURIComponent(lat)}&longitude=${encodeURIComponent(lng)}&localityLanguage=zh`);
            const gj = await g.json();
            const name = ['locality', 'city', 'principalSubdivision']
                .map(key => (gj[key] || '').trim())
                .find(Boolean);
            if (name) city = name;
        } catch (e) {}

        renderWeather(json, city);
        $('loading').style.display = 'none';
        $('weatherData').style.display = 'block';
    } catch (e) {
        $('loading').style.display = 'none';
        $('error').textContent = e.name === 'AbortError' ? '请求超时' : (e.message || '网络错误');
        $('error').style.display = 'block';
    }
}

function renderWeather(json, city) {
    const $ = id => document.getElementById(id);
    const c = json.current, h = json.hourly, d = json.daily;
    $('cityName').textContent = city;
    $('mainIcon').textContent = emoji(wmo(c.weather_code));
    $('mainTemp').textContent = Math.round(c.temperature_2m) + '°';
    $('mainCondition').textContent = wmo(c.weather_code);
    $('high').textContent = Math.round(d.temperature_2m_max[0]) + '°';
    $('low').textContent = Math.round(d.temperature_2m_min[0]) + '°';
    $('feelsLike').textContent = '体感温度 ' + Math.round(c.apparent_temperature) + '°';
    $('sunrise').textContent = d.sunrise?.[0]?.substring(11, 16) || '';
    $('sunset').textContent = d.sunset?.[0]?.substring(11, 16) || '';
    $('source').textContent = '数据来源：Open-Meteo';

    $('rainCard').style.display = h.precipitation_probability?.some(v => v > 50) ? 'flex' : 'none';

    const now = new Date().toISOString().substring(0, 13);
    let html = '';
    for (let i = 0; i < h.time.length; i++) {
        if (h.time[i].substring(0, 13) >= now && html.split('hour-card').length <= 49) {
            html += '<div class="hour-card"><div class="hour-time">' + h.time[i].substring(11,13) + '时</div><div class="hour-icon">' + emoji(wmo(h.weather_code[i])) + '</div><div class="hour-temp">' + Math.round(h.temperature_2m[i]) + '°</div><div class="hour-cond">' + wmo(h.weather_code[i]) + '</div></div>';
        }
    }
    $('hourly').innerHTML = html;

    let dh = '';
    for (let i = 0; i < d.time.length; i++) {
        dh += '<div class="daily-row"><span class="daily-date">' + d.time[i].substring(5) + '</span><span class="daily-icon">' + emoji(wmo(d.weather_code[i])) + '</span><span class="daily-cond">' + wmo(d.weather_code[i]) + '</span><span class="daily-high">' + Math.round(d.temperature_2m_max[i]) + '°/</span><span class="daily-low">' + Math.round(d.temperature_2m_min[i]) + '°</span></div>';
    }
    $('daily').innerHTML = dh;
    $('dailyTitle').textContent = '多日预报（' + d.time.length + '天）';
}

function emoji(c) {
    if (c.includes('雷')) return '⛈'; if (c.includes('阵雨')) return '🌦';
    if (c.includes('雨')) return '🌧'; if (c.includes('雪')) return '❄';
    if (c.includes('雾')) return '🌫'; if (c.includes('阴')) return '☁';
    if (c.includes('多云')) return '⛅'; if (c.includes('晴')) return '☀'; return '🌤';
}

function wmo(code) {
    return {0:'晴',1:'大部晴朗',2:'多云',3:'阴',45:'雾',48:'雾',51:'毛毛雨',53:'毛毛雨',55:'毛毛雨',61:'雨',63:'雨',65:'雨',71:'雪',73:'雪',75:'雪',80:'阵雨',81:'阵雨',82:'阵雨',95:'雷阵雨'}[code] || '未知';
}

function openSettings() { document.getElementById('settingsPanel').style.display = 'block'; }
function closeSettings() { document.getElementById('settingsPanel').style.display = 'none'; loadWeather(); }
async function saveSetting(k, v) { settings[k] = v; await saveSettings(); if (k === 'fontSize') applyFontSize(); if (k === 'refreshInterval') startAutoRefresh(); }

document.addEventListener('DOMContentLoaded', init);
