"use strict";
const byId = id => document.getElementById(id);
const steps = [
  { title: "星澜在海边等你", voice: "长椅边还有个位子。明早一起沿着海堤走吧。", action: "同步昨夜记录", icon: "moon", reward: 0 },
  { title: "星澜走到了海边长椅", voice: "昨晚按时入睡，赚了 50 枚贝壳。长椅旁正好空着一个花盆位。", action: "让小雨接上一程", icon: "foot", reward: 50 },
  { title: "小雨点亮了海湾转角", voice: "我追上啦！从这个弯道望过去，已经能看见春笋了。", action: "同步次日阅读", icon: "book", reward: 0 },
  { title: "星澜走到了观景平台", voice: "今天读完一章，连续第二天赚了 60 枚。一起在灯下拍张明信片吧。", action: "收下明信片", icon: "card", reward: 60 }
];
// Coordinates refer to the uncropped illustration. Both walkers use the same promenade.
const path = [[.11,.745],[.25,.738],[.38,.743],[.51,.727],[.61,.703],[.73,.673],[.86,.624]];
const locations = Array.from(document.querySelectorAll(".route li"));
const lamps = Array.from(document.querySelectorAll(".lamp"));
const frame = byId("frame"), world = byId("world");
const reduce = matchMedia("(prefers-reduced-motion: reduce)");
const inks = { d:"#203a3b", c:"#fff5d9", r:"#d85e3f", e:"#ffd39e" };
const sprite = [
  "       d       d    ", "      ded     ded   ", "      defdddddffd   ",
  "      dfffffffffd   ", "  dd  dffffeffefd   ", " dffd dffffdeffdd   ",
  " dffddddffcccfccd   ", " ddffffdffcccdccd   ", "  dfffffrrrccccd    ",
  "   dffefffrrrrd     ", "    dffeffffrcd     ", "    dffeccffccd     ",
  "     ddccddccd      ", "     dccd dccd      ", "     ddd   ddd      "
];
const symbols = {
  shell:["...aaa...","..abbba..",".abbcbba.","abcbcbcba","abcbcbcca",".abcbcba.","..abbba..","...aaa..."],
  book:["aaaa.aaaa","abbbaabba","abbbaabba","abbbabbba","abbbabbba","abbbabbba","aaaa.aaaa"],
  foot:[".....aa..","....abba.","....abba.",".....aa..",".aaa.....","abbba....","abbba....",".aaa....."],
  moon:["....aaa..","..abba...",".abba....",".abba....",".abbaa...","..abbbaaa","...aabbba",".....aaa."],
  card:["aaaaaaaaa","abbbbbbba","abaabbaba","abbaaabba","abbbbabba","abbbbbbba","aaaaaaaaa"]
};
function drawPet(canvas, guest, stride = false) {
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0,0,20,20);
  ctx.fillStyle = "#1d373a42";
  ctx.fillRect(4,16,10,2);
  const colors = { ...inks, f: guest ? "#b3a7dd" : "#a6d0df" };
  sprite.forEach((row,y) => {
    [...row].forEach((char,x) => {
      if (!colors[char]) return;
      ctx.fillStyle = colors[char];
      const leg = stride && y>11 ? (x<9 ? -1 : 1) : 0;
      ctx.fillRect(x+leg, y+(stride ? 1 : 2), 1, 1);
    });
  });
}
function drawIcon(canvas, symbol, primary) {
  const rows = symbols[symbol];
  canvas.width=10; canvas.height=10;
  const ctx = canvas.getContext("2d");
  const colors = primary ? {a:"#fff4df",b:"#e1ac81",c:"#d99876"} : {a:"#694b3d",b:"#edbf94",c:"#ad7961"};
  rows.forEach((row,y) => [...row].forEach((c,x) => {
    if (colors[c]) { ctx.fillStyle=colors[c]; ctx.fillRect(x,y+1,1,1); }
  }));
}
document.querySelectorAll("[data-icon]").forEach(el => drawIcon(el,el.dataset.icon,false));
// Use map coordinates for both the moving view and the finished postcard.
const lampCenters = lamps.map(lamp => ({
  x: parseFloat(lamp.style.left),
  y: parseFloat(lamp.style.top)
}));
function addLightPool(group, center, rx, ry, gradient) {
  const ellipse = document.createElementNS("http://www.w3.org/2000/svg", "ellipse");
  ellipse.setAttribute("cx", center.x);
  ellipse.setAttribute("cy", center.y + 5.5);
  ellipse.setAttribute("rx", rx);
  ellipse.setAttribute("ry", ry);
  ellipse.setAttribute("fill", "url(#" + gradient + ")");
  ellipse.classList.add("light-pool");
  group.append(ellipse);
  return ellipse;
}
const litAreas = lampCenters.map(center => [
  addLightPool(byId("clearings"), center, 30, 40, "clearPool"),
  addLightPool(byId("pools"), center, 15, 15, "warmPool")
]);
const tide=byId("tide");
for (let i=0;i<13;i++) {
  const fleck=document.createElement("i");
  fleck.className="glint"; fleck.style.left=(9+i*29%83)+"%"; fleck.style.top=(48+i*7%10)+"%";
  fleck.style.animationDelay=(-i*.73)+"s"; tide.append(fleck);
}
for (let i=0;i<3;i++) {
  const gull=document.createElement("i");
  gull.className="gull"; gull.style.left=(34+i*2.5)+"%"; gull.style.top=(26+i%2*1.6)+"%";
  gull.style.animationDelay=(-i*.6)+"s"; tide.append(gull);
}
let stage=0, travel=null, raf=0, vw=0, vh=0, ww=0, wh=0;
const goods = [
  { id:"planter", name:"簕杜鹃花盆", price:35, place:"海边长椅", detail:"给长椅添一丛深圳的市花。", x:.30, y:.748, size:.053 },
  { id:"pennant", name:"海风信号旗", price:75, place:"观景平台", detail:"在观景平台升起一面海湾的小旗。", x:.92, y:.596, size:.073 },
  { id:"cottage", name:"海堤小屋", price:420, place:"海湾转角", detail:"沿着海堤回家，窗子正对晚霞。", x:.388, y:.716, size:.115 }
];
const storageKey = "qiling.shenzhen-bay.demo.v1";
const owned = new Set();
// Extra days are explicitly simulated in the offline demo after the postcard.
const sampleHabits=["步行千步","按时入睡","完成阅读","运动达标","睡眠达标","完成专注"];
let extraDays=0;
function sampleReward(index) { return index===0 ? 70 : 80; }
function walletBalance() {
  const earned = steps.slice(0,stage+1).reduce((sum,step)=>sum+step.reward,0);
  const laterIncome=sampleHabits.slice(0,extraDays).reduce((sum,_,i)=>sum+sampleReward(i),0);
  return earned + laterIncome - goods.reduce((sum,item)=>sum+(owned.has(item.id) ? item.price : 0),0);
}
function storeDemo() {
  try { localStorage.setItem(storageKey,JSON.stringify({stage, extraDays, owned:[...owned]})); } catch {}
}
function restoreDemo() {
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey));
    if (!saved || !Number.isInteger(saved.stage) || !steps[saved.stage] || !Array.isArray(saved.owned)) return;
    stage = saved.stage;
    if (stage===3 && Number.isInteger(saved.extraDays)) extraDays=Math.max(0,Math.min(sampleHabits.length,saved.extraDays));
    for (const item of goods) {
      if (saved.owned.includes(item.id) && walletBalance() >= item.price) owned.add(item.id);
    }
  } catch {}
}
function updateWallet() {
  const balance=walletBalance();
  byId("balance").textContent=balance;
  byId("wallet").setAttribute("aria-label","海湾小铺，余额 "+balance+" 枚贝壳");
  for (const item of goods) {
    const image = byId(item.id);
    image.hidden=!owned.has(item.id);
    image.style.left=(item.x*100)+"%";
    image.style.top=(item.y*100)+"%";
    image.style.width=(item.size*100)+"%";
  }
}
const clamp = (v,a,b) => Math.max(a,Math.min(b,v));
const mix = (a,b,t) => a+(b-a)*t;
function point(index) {
  const n = clamp(index,0,path.length-1);
  const a = path[Math.floor(n)], b = path[Math.ceil(n)];
  return [mix(a[0],b[0],n%1),mix(a[1],b[1],n%1)];
}
// The guest takes the lead around the bend. The camera stays between the walkers as they swap places.
const poses = [
  { me:0, pal:0, look:0 }, { me:1,pal:.74,look:1 },
  { me:2.42,pal:3,look:2.88 }, { me:6,pal:5.53,look:5.86 }
];
function put(el, index, offset=0) {
  const [x,y]=point(index);
  el.style.left=(x*100)+"%"; el.style.top=((y+offset)*100)+"%";
}
function paint(now) {
  const from=poses[stage], to=travel ? poses[stage+1] : from;
  const raw=travel ? clamp((now-travel.began)/travel.duration,0,1) : 0;
  const t=raw*raw*(3-2*raw);
  const lerp=key=>mix(from[key],to[key],t);
  const guest=stage>=2 || (travel && stage===1);
  const [cx,cy]=point(lerp("look"));
  const left=clamp(cx*ww-vw*.38,0,ww-vw);
  const top=clamp(cy*wh-vh*.76,0,wh-vh);
  world.style.transform="translate("+(-left).toFixed(2)+"px,"+(-top).toFixed(2)+"px)";
  byId("pal").hidden=!guest;
  put(byId("me"),lerp("me")); put(byId("pal"),lerp("pal"),.016);
  const stride=Boolean(travel && !reduce.matches && Math.floor((now-travel.began)/150)%2);
  drawPet(byId("me"),false,stride);
  if (guest) drawPet(byId("pal"),true,Boolean(travel && !reduce.matches && !stride));
}
function resize() {
  vw=frame.clientWidth; vh=frame.clientHeight;
  ww=Math.max(vw*(vw>580 ? 1.48 : 1.78),vh*4/3); wh=ww*.75;
  world.style.width=ww+"px"; world.style.height=wh+"px";
  paint(performance.now());
}
function arrived() {
  const s=steps[stage];
  byId("speaker").textContent=s.title; byId("voice").textContent=s.voice;
  byId("action").textContent=s.action;
  updateWallet();
  byId("earning").hidden=stage===0;
  byId("earning").textContent=stage===2 ? "伙伴接力 · 1 站" : "习惯 +"+s.reward+" 枚";

  if (extraDays>0) {
    const reason=sampleHabits[extraDays-1],credit=sampleReward(extraDays-1);
    byId("voice").textContent="今天"+reason+"，又攒了 "+credit+" 枚贝壳。";
    byId("earning").textContent="习惯 +"+credit+" 枚";
  }
  drawPet(byId("face"),stage===2);
  drawIcon(byId("actionIcon"),s.icon,true);
  lamps.forEach((el,i)=>{
    el.classList.toggle("on",i<stage);
    for (const area of litAreas[i]) area.classList.toggle("on",i<stage);
  });
  byId("shade").classList.toggle("complete", stage===lamps.length);
  locations.forEach((el,i)=>{
    el.classList.toggle("on",i<stage);
    el.setAttribute("aria-label",el.textContent+(i<stage ? "，已点亮" : "，尚未点亮"));
  });
  frame.setAttribute("aria-label","深圳湾海堤，"+s.title+"。已点亮 "+stage+" 盏灯。");
  byId("advance").disabled=false;
}
function finishWalk() {
  cancelAnimationFrame(raf); travel=null; stage++; paint(performance.now()); arrived(); storeDemo();
  byId("earning").classList.toggle("credit",steps[stage].reward>0);
  if (byId("shop").open) renderShop();
}
function tick(now) {
  if (!travel) return;
  if (now-travel.began>=travel.duration || reduce.matches) { finishWalk(); return; }
  paint(now); raf=requestAnimationFrame(tick);
}
function advance() {
  if (travel) return;
  byId("earning").classList.remove("credit");
  if (stage===3) { showSheet(true,byId("advance")); return; }
  if (reduce.matches) { finishWalk(); return; }
  const destination=locations[stage].textContent;
  byId("advance").disabled=true; byId("action").textContent="走向"+destination;
  byId("speaker").textContent=stage===1 ? "小雨赶上了星澜" : "星澜沿海堤出发";
  byId("voice").textContent=["树影慢慢从脚边滑过去。","两串脚印，一起拐过弯道。","最后一盏灯，就在海风吹来的方向。"][stage];
  travel={began:performance.now(),duration:[1500,2150,2400][stage]};
  raf=requestAnimationFrame(tick);
}
function restart() {
  cancelAnimationFrame(raf); travel=null; stage=0; extraDays=0; owned.clear(); storeDemo(); arrived(); paint(performance.now());
}
function drawSouvenirs(ctx,w,h) {
  for (const item of goods) {
    const image=byId(item.id);
    if (!owned.has(item.id) || !image.naturalWidth) continue;
    const size=w*item.size;
    ctx.drawImage(image,w*item.x-size/2,h*item.y-size,size,size);
  }
}

function drawShopArt() {
  const canvas=byId("shopArt"),ctx=canvas.getContext("2d");
  const w=canvas.width,h=w*.75;
  ctx.save();
  ctx.imageSmoothingEnabled=false;
  ctx.translate(0,-h*.38);
  if (byId("plate").naturalWidth) ctx.drawImage(byId("plate"),0,0,w,h);
  drawSouvenirs(ctx,w,h);
  ctx.restore();
}
function buy(item) {
  if (owned.has(item.id) || walletBalance()<item.price) return;
  owned.add(item.id);
  storeDemo();
  updateWallet();
  renderShop();
  byId("saleNote").textContent=item.name+"已摆在"+item.place+"。";
  byId("backToBay").focus({preventScroll:true});
}
function renderShop() {
  const balance=walletBalance();
  byId("shopBalance").textContent=balance+" 枚";
  byId("income").textContent=[
    "完成今天的第一项好习惯，就能赚到 50 枚。",
    "第一天 · 按时入睡 +50 枚",
    "你的最近入账 · 按时入睡 +50 枚",
    "连续第二天 · 完成阅读 +60 枚"
  ][stage];
  if (extraDays>0) byId("income").textContent="连续第 "+(extraDays+2)+" 天 · "+sampleHabits[extraDays-1]+" +"+sampleReward(extraDays-1)+" 枚";
  const next=byId("sampleDay");
  next.hidden=stage!==3 || extraDays>=sampleHabits.length || goods.every(item=>owned.has(item.id));
  if (!next.hidden) next.textContent="试玩下一天 · "+sampleHabits[extraDays];
  const list=byId("goods");
  list.replaceChildren();
  for (const item of goods) {
    const row=document.createElement("li");
    const icon=document.createElement("img");
    icon.src=byId(item.id).src; icon.alt="";
    const description=document.createElement("div");
    const name=document.createElement("span"),place=document.createElement("span");
    name.className="item-name"; name.textContent=item.name;
    place.className="item-place"; place.textContent=owned.has(item.id) ? "已摆在"+item.place : item.detail;
    description.append(name,place);
    if (item.id==="cottage" && !owned.has(item.id)) {
      const progress=document.createElement("progress");
      progress.className="saving"; progress.max=item.price; progress.value=Math.min(balance,item.price);
      progress.setAttribute("aria-label","小屋储蓄进度"); description.append(progress);
    }
    const price=document.createElement("div"); price.className="price";
    if (owned.has(item.id)) {
      price.classList.add("placed"); price.textContent="✓ 已摆放";
    } else {
      const button=document.createElement("button");
      button.id="buy-"+item.id; button.disabled=balance<item.price;
      button.className=button.disabled?"key":"key primary";
      button.textContent=item.price+" 枚";
      button.setAttribute("aria-label","花 "+item.price+" 枚贝壳买"+item.name);
      button.addEventListener("click",()=>buy(item));
      price.append(button);
      if (button.disabled) {
        const short=document.createElement("small"); short.textContent="还差 "+(item.price-balance)+" 枚";
        price.append(short);
      }
    }
    row.append(icon,description,price); list.append(row);
  }
  drawShopArt();
}
function drawPostcard() {
  const canvas=byId("postArt"), ctx=canvas.getContext("2d"), w=canvas.width,h=canvas.height;
  ctx.imageSmoothingEnabled=false;
  ctx.drawImage(byId("plate"),0,0,w,h);
  for (const center of lampCenters) {
    const x = center.x*w/100, y = center.y*h/100;
    ctx.save();
    ctx.translate(x, y+h*.055);
    ctx.scale(w*.15, h*.15);
    const pool = ctx.createRadialGradient(0,0,0,0,0,1);
    pool.addColorStop(0,"rgba(255,196,102,.20)");
    pool.addColorStop(1,"rgba(255,196,102,0)");
    ctx.fillStyle = pool;
    ctx.fillRect(-1,-1,2,2);
    ctx.restore();
    ctx.fillStyle="#ffe697"; ctx.fillRect(x-4,y-3,8,6);
  }
  drawSouvenirs(ctx,w,h);
  for (const [id,index,offset] of [["pal",poses[3].pal,.016],["me",6,0]]) {
    const [x,y]=point(index),size=id==="pal"?48:56;
    ctx.drawImage(byId(id),w*x-size/2,h*(y+offset)-size/2,size,size);
  }
}
let opener;
function showSheet(card, trigger) {
  opener = trigger;
  const entries=byId("entries");
  entries.replaceChildren();
  byId("postcard").hidden=!card;
  byId("sheetTitle").textContent=card ? "在深圳湾，一起看海" : "旅行手记";
  if (card) {
    drawPostcard(); byId("sheetNote").textContent="星澜和小雨，沿海堤点亮了三盏灯。";
  } else {
    byId("sheetNote").textContent=stage ? "我的贝壳 · "+walletBalance()+" 枚" : "贝壳背包空着，第一页留给今晚的好习惯。";
    const rows=[["第一天 · 按时入睡","＋50 枚"],["小雨 · 同行接力","伙伴的贝壳"],["第二天 · 完成阅读","＋60 枚"]];
    const ledger=rows.slice(0,stage);
    for (const [i,habit] of sampleHabits.slice(0,extraDays).entries()) ledger.push(["第 "+(i+3)+" 天 · "+habit,"＋"+sampleReward(i)+" 枚"]);
    for (const item of goods) if (owned.has(item.id)) ledger.push([item.name,"−"+item.price+" 枚"]);
    for(const [label,reward] of ledger) {
      const item=document.createElement("li"),value=document.createElement("b");
      item.append(label); value.textContent=reward; item.append(value); entries.append(item);
    }
  }
  byId("close").textContent=card ? "收好明信片" : "合上手记";
  byId("sheet").showModal(); byId("close").focus();
}
byId("advance").addEventListener("click",advance);
byId("restart").addEventListener("click",restart);
byId("journal").addEventListener("click",event=>showSheet(false,event.currentTarget));
byId("wallet").addEventListener("click",()=>{
  byId("saleNote").textContent="";
  renderShop(); byId("shop").showModal();
});
byId("sampleDay").addEventListener("click",()=>{
  if (stage!==3 || extraDays>=sampleHabits.length || byId("sampleDay").hidden) return;
  extraDays++;
  storeDemo(); arrived(); renderShop();
  byId("saleNote").textContent="示例第 "+(extraDays+2)+" 天，"+sampleHabits[extraDays-1]+"，已到账 "+sampleReward(extraDays-1)+" 枚。";
});
byId("shop").addEventListener("close",()=>byId("wallet").focus());
for (const id of ["plate",...goods.map(item=>item.id)]) {
  byId(id).addEventListener("load",()=>{ if (byId("shop").open) drawShopArt(); });
}
byId("sheet").addEventListener("close",()=>opener?.focus());
reduce.addEventListener("change",()=>{ if (reduce.matches && travel) finishWalk(); });
new ResizeObserver(resize).observe(frame);
restoreDemo(); arrived(); resize();
