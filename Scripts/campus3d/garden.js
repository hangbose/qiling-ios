import {sites} from "./campus-plots.js";
import {nightWalk} from "./corridor.js";

const $=id=>document.getElementById(id);
const live=window.gardenLive===true;
const key="qiling-yuehai-garden-demo-v1";
const dateAt=offset=>new Date(Date.now()+(8+24*offset)*3600000).toISOString().slice(0,10);
const names={me:"阿青",pal:"小雨"};
const ornaments={flowers:"簕杜鹃花盆",lamp:"庭灯",flag:"手绘小旗"};
const questions=[
  ["致理楼的三栋教学楼用哪组编号？",["H1、H2、H3","L1、L2、L3","A1、A2、A3"],1],
  ["哪件事能带来健康贡献？",["反复打开地图","切换摆设","同步当天的步行记录"],2],
  ["明天还能在哪看到今天摆下的花？",["原地的昨日印记","贝壳商店","校园问答"],0],
];
const question=day=>questions[Number(day.slice(-2))%3];
let local={days:{},actor:"me",offset:0};
if(!live){try{local=JSON.parse(localStorage.getItem(key))??local}catch{}}
let snapshot=null, site=0, wide=false, walking=false, showPast=true, editorKey="", pending=null, scene;
// Late native replies can outlive a page reload as well as a single request.
let nextRequestId=Date.now()*1000;
let sceneLoading,viewRevision=0,lastView=null,focusWhenReady=null,failedModule=false;
function modelStatus(text,retry=false){
  $("loading-label").textContent=text;$("model-retry").hidden=!retry;
  $("loading").hidden=!text;$("stage").classList.toggle("loading-model",Boolean(text));
}
function activateImage(img){
  if(img?.dataset.src&&(img.getAttribute("src")!==img.dataset.src||(img.complete&&!img.naturalWidth)))img.src=img.dataset.src;
}
function sceneForPage(){
  if(!sceneLoading)sceneLoading=import("./scene.js").catch(error=>{failedModule=true;throw error}).then(({campusScene})=>{
    scene=campusScene($("stage"),selectSite,()=>{location.hash="garden"},modelStatus);paint();return scene;
  }).catch(error=>{sceneLoading=null;throw error});
  return sceneLoading;
}
function say(text){$("status").textContent=text}
const study=$("study"),reference=$("campus-photo");
study.addEventListener("toggle",()=>{
  if(!study.open)return;
  if(!reference.hasAttribute("src"))reference.src="https://psy.szu.edu.cn/en/images/ba1d0f55f4c605d9ad5a93fcd850442.jpg";
  const front=$("shot-front");$("study-front").src=front.dataset.src||front.src;
  study.querySelectorAll("img[data-src]").forEach(activateImage);
});
const corridor=nightWalk($("rain"));
const exterior=$("exterior");
const shotButtons=exterior.querySelectorAll("[data-shot]");
for(const button of shotButtons){
  button.addEventListener("click",()=>{
    activateImage($("shot-"+button.dataset.shot));
    exterior.querySelector(".enter-3d").hash="walk/"+button.dataset.shot;
    exterior.querySelector(".enter-map").hash=button.dataset.shot==="street"?"garden":"garden/"+button.dataset.shot;
    for(const other of shotButtons){
      const selected=button===other;
      other.setAttribute("aria-pressed",String(selected));
      $("shot-"+other.dataset.shot).hidden=!selected;
    }
  });
}
function showExterior(){
  ++viewRevision;focusWhenReady=null;scene?.suspend();walking=false;corridor.hide();
  $("stage").hidden=true;$("scene-header").hidden=true;exterior.hidden=false;
}
function enterWalk(){
  ++viewRevision;focusWhenReady=null;scene?.suspend();walking=false;
  exterior.hidden=true;$("scene-header").hidden=false;$("stage").hidden=true;
  $("title").textContent="致理楼 · 雨夜连廊";
  corridor.show();
}
async function mapView(value,shot,street=false,focusAfter=null){
  const id=++viewRevision;
  lastView=[value,shot,street];focusWhenReady=focusAfter;walking=street;wide=value;
  exterior.hidden=true;$("scene-header").hidden=false;corridor.hide();$("stage").hidden=false;
  $("title").textContent=street?"致理楼 · 步行":wide?"粤海校园全景":"致理楼";
  $("entrance").hidden=wide;$("overview").textContent=wide?"走近致理楼":"校园全景";
  const poster=$("shot-"+shot)||$("shot-street");
  $("stage").style.setProperty("--stage-poster",'url("'+(poster.dataset.src||poster.src)+'")');
  modelStatus("正在载入三维场景…");
  try{
    const view=scene||await sceneForPage();
    if(id!==viewRevision)return;
    await view.show(value?"Yuehai":"Zhili",shot,street);
    if(id===viewRevision&&focusWhenReady!==null){view.focus(focusWhenReady);focusWhenReady=null}
  }catch{
    if(id===viewRevision)modelStatus("三维场景暂未载入。",true);
  }
}
$("model-retry").onclick=()=>{if(failedModule)location.reload();else if(lastView)mapView(...lastView,focusWhenReady)};
function selectSite(value){
  site=value;
  if($("stage").hidden||walking||wide){
    // A claim can open the map while the player is still editing below it.
    history.pushState(null,"","#garden");
    mapView(false,undefined,false,site);
  }else if(!$("loading").hidden)focusWhenReady=site;
  else scene?.focus(site);
  say("");paint();
}
$("street-in").onclick=()=>{location.hash="walk"};
$("overview").onclick=()=>{location.hash=wide?"garden":"campus"};$("reset").onclick=()=>scene?.reset();
$("entrance").onclick=()=>scene?.entrance();
sites.forEach((s,i)=>{const b=document.createElement("button");b.textContent=s.name;b.onclick=()=>selectSite(i);$("sites").append(b)});
function loadDay(day){return local.days[day]??={plots:[],habits:{}}}
function health(board){const habits=board.habits[local.actor]??{};return 20+(habits.steps?25:0)+(habits.workout?35:0)}
function demoState(){
  const day=dateAt(local.offset),board=loadDay(day);
  const rows=list=>list.map(p=>({...p,name:names[p.owner],mine:p.owner===local.actor,answered:Number.isInteger(p.answer),bonus:p.answer===question(p.day)[2]?5:0}));
  snapshot={day,health:health(board),plots:rows(board.plots),previous:rows(local.days[dateAt(local.offset-1)]?.plots??[])};
  try{localStorage.setItem(key,JSON.stringify(local))}catch{}
  paint();
}
function demoAction(action,extras){
  const day=dateAt(local.offset),board=loadDay(day),p=board.plots.find(x=>x.site===site),mine=board.plots.find(x=>x.owner===local.actor);
  if(snapshot.day!==day){demoState();say("已经是新的一天，请重新选地。");return}
  if(action==="claim"&&!mine&&!p&&health(board)>=20)board.plots.push({site,day,owner:local.actor,health:health(board)});
  if(p?.owner===local.actor){
    if(action==="decorate")Object.assign(p,{ornament:extras.ornament,note:extras.note.trim().slice(0,40),tint:extras.tint});
    if(action==="quiz"&&!Number.isInteger(p.answer))p.answer=extras.answer;
  }
  if(mine)mine.health=Math.max(mine.health,health(board));
  demoState();feedback(action);
}
function feedback(action){
  if(action==="decorate")say("摆好了。明天路过这里的人也能看见。");
  if(action==="claim")say("这处角落今天归你布置。");
  if(action==="quiz")say(snapshot?.plots.find(x=>x.mine)?.bonus?"答对了，领地加 5 分。":"答案已收好，明天再来试试。");
}
function send(action,extras={}){
  if(pending)return;
  if(!live){demoAction(action,extras);return}
  const requestId=++nextRequestId;
  const timer=setTimeout(()=>window.gardenError("暂时没有收到校园回信。请刷新后确认刚才的操作。",requestId),40000);
  pending={requestId,action,site,timer};
  paint();say("正在同步…");
  try{window.webkit.messageHandlers.garden.postMessage({action,day:snapshot?.day??"",site,...extras,requestId})}
  catch{window.gardenError("暂时无法连接校园，请刷新。",requestId)}
}
function finishRequest(requestId){
  if(!pending||pending.requestId!==requestId)return null;
  const completed=pending;
  clearTimeout(completed.timer);
  pending=null;
  return completed;
}
window.showGarden=(data,requestId)=>{
  const completed=finishRequest(requestId);
  if(!completed)return;
  snapshot=data;say("");paint();
  if(completed.site===site)feedback(completed.action);
};
window.gardenError=(reason,requestId)=>{
  if(!finishRequest(requestId))return;
  say(reason);paint();
};
function paint(){
  const waiting=pending!==null;
  $("mode").textContent=live?"共享校园":"本机试玩 · "+names[local.actor];
  $("demo").hidden=live;$("liveControls").hidden=!live;
  [...$("sites").children].forEach((b,i)=>b.setAttribute("aria-pressed",String(i===site)));
  $("spot").textContent=sites[site].name;
  if(!snapshot){$("claim").disabled=true;$("rule").textContent="正在读取今天的角落。";return}
  const p=snapshot.plots.find(x=>x.site===site), mine=snapshot.plots.some(x=>x.mine);
  const old=snapshot.previous.find(x=>x.site===site&&x.ornament);
  const total=(p?.health??0)+(p?.bonus??0);
  $("day").textContent=snapshot.day+" · 今日";$("score").textContent="我的健康贡献 "+snapshot.health+" 分";
  $("claim").disabled=waiting||!!p||mine||snapshot.health<20;
  $("claim").textContent=p?(p.mine?"我的角落":"今日已有主人"):mine?"今天已选地":"认领到今晚";
  $("rule").textContent=p?(p.mine?"你":p.name)+"的角落 · "+total+" 分 · "+(total>=80?"花园":total>=50?"小庭院":"小花圃")+(total<80?"，再得 "+((total<50?50:80)-total)+" 分扩一圈。":"。"):
    mine?"这里还空着。你今天已有一个角落，明天可以换到这里。":"今天还空着。健康贡献满 20 分即可认领，一人每天一处。";
  $("current").textContent=p?.ornament?("摆了一"+({flowers:"盆簕杜鹃",lamp:"盏庭灯",flag:"面手绘小旗"}[p.ornament]??"件摆设")+(p.note?" · "+p.note:"")):"";
  $("editor").hidden=!p?.mine;$("editor").disabled=waiting;
  const ident=JSON.stringify([snapshot.day,site,p?.mine,p?.ornament,p?.note,p?.tint]);
  if(ident!==editorKey){editorKey=ident;$("decor").value=p?.ornament??"flowers";$("note").value=p?.note??"";$("tint").value=p?.tint??"jade"}
  $("quizBox").hidden=!p?.mine;$("answers").replaceChildren();
  const [prompt,choices,good]=question(snapshot.day);
  $("question").textContent=p?.answered?(p.bonus?"今天答对了，领地 +5 分。":"今天的答案是「"+choices[good]+"」。"):prompt+"（答对 +5）";
  if(p?.mine&&!p.answered)choices.forEach((s,i)=>{const b=document.createElement("button");b.textContent=s;b.disabled=waiting;b.onclick=()=>send("quiz",{answer:i});$("answers").append(b)});
  $("yesterday").hidden=!old;$("oldNote").textContent=old?old.name+" 留下了"+(ornaments[old.ornament]??"摆设")+(old.note?" · "+old.note:"。"):"";
  $("histToggle").textContent=showPast?"收起昨日摆设":"看看昨日摆设";
  if(!live){const habits=loadDay(snapshot.day).habits[local.actor]??{};
    ["steps","workout"].forEach(k=>$(k).disabled=!!habits[k]);$("swap").textContent="换成"+names[local.actor==="me"?"pal":"me"];}
  scene?.update(site,snapshot.plots,snapshot.previous,showPast);
}
$("claim").onclick=()=>{if($("stage").hidden||walking||wide)selectSite(site);send("claim")};$("save").onclick=()=>send("decorate",{ornament:$("decor").value,note:$("note").value,tint:$("tint").value});
$("histToggle").onclick=()=>{showPast=!showPast;paint()};
$("sync").onclick=()=>send("refresh",{sync:true});$("refresh").onclick=()=>send("refresh");
for(const k of ["steps","workout"]){$(k).onclick=()=>{const b=loadDay(dateAt(local.offset));(b.habits[local.actor]??={})[k]=true;const mine=b.plots.find(x=>x.owner===local.actor);if(mine)mine.health=health(b);demoState();say("示例活动已同步。")}}
$("swap").onclick=()=>{local.actor=local.actor==="me"?"pal":"me";say("");demoState()};
$("next").onclick=()=>{local.offset++;say("新的一天到了，看看谁留下了印记。");demoState()};
function refresh(){if(live)send("refresh");else demoState()}
document.addEventListener("visibilitychange",()=>{if(!document.hidden)refresh()});
window.addEventListener("storage",e=>{if(!live&&e.key===key&&e.newValue){try{local=JSON.parse(e.newValue);demoState()}catch{}}});
setInterval(()=>{if(!document.hidden&&(live||snapshot?.day!==dateAt(local.offset)))refresh()},60000);
function route(moveFocus=false){
  let target;
  switch(location.hash){
    case "#rain":
      enterWalk();target=$("rain");break;
    case "#walk":
    case "#walk/street":
    case "#walk/arrival":
    case "#walk/front":
    case "#walk/shelter":
    case "#walk/gallery":
    case "#walk/steps":
      mapView(false,location.hash.split("/")[1]||"street",true);target=$("stage");break;
    case "#campus":
      mapView(true);target=$("stage");break;
    case "#garden":
    case "#garden/arrival":
    case "#garden/front":
    case "#garden/shelter":
      mapView(false,location.hash.split("/")[1]);target=$("stage");break;
    case "#study":
      if(walking)showExterior();
      study.open=true;target=study.querySelector("summary");break;
    case "#gameplay":
      if(walking)showExterior();
      target=$("gameplay");break;
    default:
      showExterior();target=exterior;
  }
  if(moveFocus||location.hash==="#study"||location.hash==="#gameplay"){
    if(target===$("stage"))target.tabIndex=-1;
    if(moveFocus)target.focus({preventScroll:true});
    if(target===exterior||target===$("stage")||target===$("rain"))window.scrollTo(0,0);
    else target.scrollIntoView({block:"start"});
  }
}
window.addEventListener("hashchange",()=>route(true));
route();
refresh();
