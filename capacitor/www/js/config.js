// --- Config ---
const API='https://api.open-meteo.com/v1';
const REVERSE_GEO='https://api.bigdatacloud.net/data/reverse-geocode-client';
let S={source:'openmeteo',fontSize:'large',refreshInterval:'30',lat:39.9042,lng:116.4074,cityName:'',useGps:true,locationNotice:'',locationServiceDisabled:false,autoCheckUpdate:true};
let RT=null,P=null;

async function init(){
  try{P=window.Capacitor?.Plugins?.Preferences}catch(e){}
  await loadPrefs();applyFont();loadWeather();startRefresh();if(S.autoCheckUpdate)checkUpdate();
  updateLocation(true).then(loadWeather).catch(()=>{});
}
async function loadPrefs(){if(P){const r=await P.get({key:'s'});if(r.value)try{S={...S,...JSON.parse(r.value)}}catch(e){}}applyFont();}
function savePrefs(){if(P)P.set({key:'s',value:JSON.stringify(S)});}
function applyFont(){document.body.fontSize={standard:'14px',large:'16px',xlarge:'18px'}[S.fontSize]||'16px';}
function startRefresh(){if(RT)clearInterval(RT);const m=parseInt(S.refreshInterval);if(m>0)RT=setInterval(loadWeather,m*60*1000);}

async function updateLocation(requestPermission){
  if(!S.useGps)return;
  const geo=window.Capacitor?.Plugins?.Geolocation;
  if(!geo){S.locationNotice='未获取定位权限，请手动选择城市；当前默认显示北京天气';return;}
  try{
    let p=await geo.checkPermissions();
    let status=p.location||p.coarseLocation;
    if((status==='prompt'||status==='prompt-with-rationale')&&requestPermission){p=await geo.requestPermissions();status=p.location||p.coarseLocation;}
    if(status!=='granted'){
      S.locationNotice='未获取定位权限，请手动选择城市；当前默认显示北京天气';S.locationServiceDisabled=false;return;
    }
    const position=await geo.getCurrentPosition({enableHighAccuracy:true,timeout:15000,maximumAge:300000});
    S.lat=position.coords.latitude;S.lng=position.coords.longitude;S.cityName='';S.locationNotice='';S.locationServiceDisabled=false;savePrefs();
  }catch(e){
    const message=String(e?.message||e||'').toLowerCase();
    S.locationServiceDisabled=message.includes('location')&&(message.includes('disabled')||message.includes('service'));
    S.locationNotice=S.locationServiceDisabled?'定位服务未开启，当前显示默认城市北京':'定位失败，请检查网络/GPS后重试；当前显示默认城市北京';
  }
}

async function refreshLocation(){await updateLocation(true);loadWeather();}
async function openLocationSettings(){
  try{await window.Capacitor?.Plugins?.LocationSettings?.open();}catch(e){S.locationNotice='无法打开系统定位设置，请手动开启后返回重试';loadWeather();}
}
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&S.useGps)updateLocation(false).then(loadWeather);});

function httpGet(url){
  return new Promise((resolve,reject)=>{
    const x=new XMLHttpRequest();
    x.open('GET',url,true);
    x.timeout=20000;
    x.onload=function(){if(x.status>=200&&x.status<300)try{resolve(JSON.parse(x.responseText))}catch(e){reject(e)}else reject(new Error('HTTP '+x.status))};
    x.onerror=function(){reject(new Error('网络连接失败'))};
    x.ontimeout=function(){reject(new Error('请求超时'))};
    x.send();
  });
}

async function loadWeather(){
  const $=id=>document.getElementById(id);
  $('loading').style.display='block';$('error').style.display='none';$('weatherData').style.display='none';
  try{
    const j=await httpGet(API+'/forecast?latitude='+S.lat+'&longitude='+S.lng+'&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,weather_code,precipitation_probability,uv_index&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max&timezone=auto&forecast_days=15');
    let city=S.cityName||'未识别位置';
    try{
      const g=await httpGet(REVERSE_GEO+'?latitude='+encodeURIComponent(S.lat)+'&longitude='+encodeURIComponent(S.lng)+'&localityLanguage=zh');
      const name=['locality','city','principalSubdivision'].map(k=>(g[k]||'').trim()).find(Boolean);
      if(name)city=name;
    }catch(e){}
    render(j,city);
    showLocationNotice();
  }catch(e){$('loading').style.display='none';$('error').textContent=e.message||'网络错误';$('error').style.display='block';}
}

function showLocationNotice(){
  const box=document.getElementById('locationNotice');
  const text=document.getElementById('locationNoticeText');
  const action=document.getElementById('locationNoticeAction');
  if(!S.locationNotice){box.style.display='none';return;}
  text.textContent=S.locationNotice;
  action.textContent=S.locationServiceDisabled?'去开启定位':'重新授权';
  action.onclick=S.locationServiceDisabled?openLocationSettings:refreshLocation;
  box.style.display='flex';
}
