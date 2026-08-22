// --- Update Check ---
function checkUpdate(){
  const x=new XMLHttpRequest();
  x.open('GET','https://api.github.com/repos/upcyan/cyanweather/releases/latest',true);
  x.timeout=8000;
  x.onload=function(){
    if(x.status!==200)return;
    try{
      const j=JSON.parse(x.responseText);
      const v=(j.tag_name||'').replace('v','');
      if(v&&v!=='1.1')showUpdateDialog(j.tag_name,j.body||'',j.html_url||'');
    }catch(e){}
  };
  x.onerror=x.ontimeout=function(){};
  x.send();
}

function showUpdateDialog(ver,notes,url){
  let safeUrl='';
  try { const parsed=new URL(url); if(parsed.protocol==='https:'&&parsed.hostname==='github.com') safeUrl=parsed.href; } catch(e) {}
  const d=document.createElement('div');
  d.className='modal-overlay';
  const modal=document.createElement('div');modal.className='modal';
  const title=document.createElement('h2');title.textContent='发现新版本 '+ver;
  const body=document.createElement('div');body.className='modal-body';
  const label=document.createElement('p');const strong=document.createElement('b');strong.textContent='更新日志：';label.appendChild(strong);
  const text=document.createElement('p');text.textContent=(notes||'暂无说明').substring(0,500);
  const actions=document.createElement('div');actions.className='modal-actions';
  const later=document.createElement('button');later.textContent='稍后';later.onclick=()=>d.remove();
  actions.appendChild(later);
  if(safeUrl){const update=document.createElement('button');update.textContent='立即更新';update.onclick=()=>{window.open(safeUrl,'_system');d.remove();};actions.appendChild(update);}
  body.append(label,text);modal.append(title,body,actions);d.appendChild(modal);
  document.body.appendChild(d);
}

// --- Settings ---
function openSettings(){document.getElementById('settingsPanel').style.display='block';document.getElementById('autoUpdate').checked=S.autoCheckUpdate;document.getElementById('useGps').checked=S.useGps;document.querySelectorAll('input[name="source"]').forEach(r=>r.checked=r.value===S.source);document.querySelectorAll('input[name="font"]').forEach(r=>r.checked=r.value===S.fontSize);document.querySelectorAll('input[name="refresh"]').forEach(r=>r.checked=r.value===S.refreshInterval);}
function closeSettings(){document.getElementById('settingsPanel').style.display='none';loadWeather();}
async function saveSetting(k,v){S[k]=v;await savePrefs();if(k==='fontSize')applyFont();if(k==='refreshInterval')startRefresh();if(k==='source'||k==='useGps')loadWeather();}

document.addEventListener('DOMContentLoaded',init);
// 拦截系统返回键：设置面板打开时先关闭面板，否则默认退出App
document.addEventListener('DOMContentLoaded',function(){
  const App=window.Capacitor?.Plugins?.App;
  if(!App)return;
  App.addListener('backButton',function(){
    const panel=document.getElementById('settingsPanel');
    if(panel&&panel.style.display==='block'){closeSettings();return;}
    App.exitApp();
  });
});
