// --- Render ---
function render(j,city){
  const $=id=>document.getElementById(id);
  const c=j.current,h=j.hourly,d=j.daily;
  $('cityName').textContent=city;
  $('mainIcon').textContent=emoji(wmo(c.weather_code));
  $('mainTemp').textContent=Math.round(c.temperature_2m)+'°';
  $('mainCondition').textContent=wmo(c.weather_code);
  $('high').textContent=Math.round(d.temperature_2m_max[0])+'°';
  $('low').textContent=Math.round(d.temperature_2m_min[0])+'°';
  $('feelsLike').textContent='体感温度 '+Math.round(c.apparent_temperature)+'°';
  $('sunrise').textContent=d.sunrise?.[0]?.substring(11,16)||'';
  $('sunset').textContent=d.sunset?.[0]?.substring(11,16)||'';
  $('source').textContent='数据来源：Open-Meteo';
  // InfoCards
  let cards='';
  if(c.relative_humidity_2m!=null)cards+=infoCard('湿度',c.relative_humidity_2m+'%');
  const ws=Math.round((c.wind_speed_10m||0)*3.6);
  const wd=windDir(c.wind_direction_10m||0);
  cards+=infoCard('风力',wd+' '+beaufort(ws));
  if(c.uv_index!=null)cards+=infoCard('紫外线强度',uvLevel(c.uv_index));
  $('infoCards').innerHTML=cards;
  // Rain
  $('rainCard').style.display=h.precipitation_probability?.some(v=>v>50)?'flex':'none';
  // Hourly
  const now=new Date().toISOString().substring(0,13);
  let hh='';
  for(let i=0;i<h.time.length&&i<48;i++){if(h.time[i].substring(0,13)>=now){hh+=hourCard(h,i);}}
  $('hourly').innerHTML=hh;
  // Daily
  let dd='';
  for(let i=0;i<d.time.length;i++){
    dd+='<div class="daily-row"><span class="daily-date">'+d.time[i].substring(5)+'</span><span class="daily-icon">'+emoji(wmo(d.weather_code[i]))+'</span><span class="daily-cond">'+wmo(d.weather_code[i])+'</span><span class="daily-high">'+Math.round(d.temperature_2m_max[i])+'°/</span><span class="daily-low">'+Math.round(d.temperature_2m_min[i])+'°</span></div>';
  }
  $('daily').innerHTML=dd;
  $('dailyTitle').textContent='多日预报（'+d.time.length+'天）';
  $('loading').style.display='none';$('weatherData').style.display='block';
}

function hourCard(h,i){
  return '<div class="hour-card"><div class="hour-time">'+h.time[i].substring(11,13)+'时</div><div class="hour-icon">'+emoji(wmo(h.weather_code[i]))+'</div><div class="hour-temp">'+Math.round(h.temperature_2m[i])+'°</div><div class="hour-cond">'+wmo(h.weather_code[i])+'</div></div>';
}
function infoCard(t,v){return '<div class="info-card"><div class="info-title">'+t+'</div><div class="info-value">'+v+'</div></div>';}
function emoji(c){if(c.includes('雷'))return'⛈';if(c.includes('阵雨'))return'🌦';if(c.includes('雨'))return'🌧';if(c.includes('雪'))return'❄';if(c.includes('雾'))return'🌫';if(c.includes('阴'))return'☁';if(c.includes('多云'))return'⛅';if(c.includes('晴'))return'☀';return'🌤';}
function wmo(code){return{0:'晴',1:'大部晴朗',2:'多云',3:'阴',45:'雾',48:'雾',51:'毛毛雨',53:'毛毛雨',55:'毛毛雨',61:'雨',63:'雨',65:'雨',71:'雪',73:'雪',75:'雪',80:'阵雨',81:'阵雨',82:'阵雨',95:'雷阵雨'}[code]||'未知';}
function windDir(d){const dirs=['北','东北','东','东南','南','西南','西','西北'];return dirs[((d+22.5)/45)%8|0];}
function beaufort(s){if(s<2)return'0级';if(s<12)return'1级';if(s<20)return'2级';if(s<29)return'3级';if(s<39)return'4级';if(s<50)return'5级';if(s<62)return'6级';return'7级';}
function uvLevel(u){if(u<=2)return'低';if(u<=5)return'中等';if(u<=7)return'高';if(u<=10)return'很高';return'极高';}
