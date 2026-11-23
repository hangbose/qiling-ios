"use strict";
const byId = id => document.getElementById(id);
const steps = [
  { title: "星澜在海边等你", voice: "长椅边还有个位子。明早一起沿着海堤走吧。", action: "同步昨夜记录", icon: "moon", balance: 0 },
  { title: "星澜走到了海边长椅", voice: "昨晚按时入睡，换来了第一盏灯。坐下来听听浪声吧。", action: "让小雨接上一程", icon: "foot", balance: 50 },
  { title: "小雨点亮了海湾转角", voice: "我追上啦！从这个弯道望过去，已经能看见春笋了。", action: "同步次日阅读", icon: "book", balance: 50 },
  { title: "星澜走到了观景平台", voice: "海风把云吹开了。你看，走过的三盏灯都亮着呢。", action: "收下明信片", icon: "card", balance: 110 }
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
function drawIcon(canvas, symbol, dark) {
  const rows = symbols[symbol];
  canvas.width=10; canvas.height=10;
  const ctx = canvas.getContext("2d");
  const colors = dark ? {a:"#38504b",b:"#e9ad60",c:"#fff1ba"} : {a:"#f6dba2",b:"#efad80",c:"#a56051"};
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
  byId("action").textContent=s.action; byId("balance").textContent=s.balance;
  byId("wallet").setAttribute("aria-label","贝壳 "+s.balance+" 枚，翻开手记");
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
  cancelAnimationFrame(raf); travel=null; stage++; paint(performance.now()); arrived();
}
function tick(now) {
  if (!travel) return;
  if (now-travel.began>=travel.duration || reduce.matches) { finishWalk(); return; }
  paint(now); raf=requestAnimationFrame(tick);
}
function advance() {
  if (travel) return;
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
  cancelAnimationFrame(raf); travel=null; stage=0; arrived(); paint(performance.now());
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
    byId("sheetNote").textContent=stage ? "我的贝壳 · "+steps[stage].balance+" 枚" : "贝壳背包空着，第一页留给今晚的好习惯。";
    const rows=[["第一天 · 按时入睡","＋50 枚"],["小雨 · 同行接力","伙伴的贝壳"],["第二天 · 完成阅读","＋60 枚"]];
    for(const [label,reward] of rows.slice(0,stage)) {
      const item=document.createElement("li"),value=document.createElement("b");
      item.append(label); value.textContent=reward; item.append(value); entries.append(item);
    }
  }
  byId("close").textContent=card ? "收好明信片" : "合上手记";
  byId("sheet").showModal(); byId("close").focus();
}
byId("advance").addEventListener("click",advance);
byId("restart").addEventListener("click",restart);
for (const id of ["wallet","journal"]) {
  byId(id).addEventListener("click",event=>showSheet(false,event.currentTarget));
}
byId("sheet").addEventListener("close",()=>opener?.focus());
reduce.addEventListener("change",()=>{ if (reduce.matches && travel) finishWalk(); });
new ResizeObserver(resize).observe(frame);
arrived(); resize();
