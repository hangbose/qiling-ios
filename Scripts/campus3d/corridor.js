// Six perspective-correct Cycles views per position. CSS compositing keeps the
// photographic lighting available offline without a second WebGL context.
import {imageAsset} from "./asset-source.js";

const stops = ["入口地垫", "窗边长椅", "公告栏旁"];

export function nightWalk(host) {
  const viewport = host.querySelector(".night-view");
  const cube = host.querySelector(".night-cube");
  const status = host.querySelector(".night-stop");
  const previous = host.querySelector(".night-prev");
  const next = host.querySelector(".night-next");
  const hint = host.querySelector(".night-hint"),retry=host.querySelector(".night-retry");
  let failedStop=0;
  const faces = ["", "rotateY(-90deg)", "rotateY(180deg)", "rotateY(90deg)", "rotateX(-90deg)", "rotateX(90deg)"];
  faces.forEach((direction, index) => {
    const face = document.createElement("div");
    face.className = "night-face";
    face.style.transform = direction + " translateZ(-511.7px)";
    face.style.backgroundPosition = (index % 3) * 50 + "% " + Math.floor(index / 3) * 100 + "%";
    cube.append(face);
  });
  let yaw=9.3, pitch=-.4, at=0, request=0, active=false, ready=false, pointer;
  const cache=new Map();
  function orient() {
    const focal = Math.max(viewport.clientWidth*.64, viewport.clientHeight*.52);
    viewport.style.perspective = focal+"px";
    cube.style.transform = "translateZ("+focal+"px) rotateX("+pitch+"deg) rotateY("+yaw+"deg)";
  }
  function adjust(dx,dy) {
    yaw=(yaw+dx)%360; pitch=Math.min(77,Math.max(-77,pitch+dy));orient();
  }
  function load(index) {
    if (!cache.has(index)) {
      const img = new Image();
      img.src = imageAsset("rain-"+index,"image/webp");
      cache.set(index, img.decode().then(()=>img).catch(e=>{cache.delete(index);throw e}));
    }
    return cache.get(index);
  }
  async function go(index) {
    if(index<0||index>=stops.length)return;
    const id=++request;
    retry.hidden=true;previous.disabled=true;next.disabled=true;hint.textContent="正在展开全景…";
    host.classList.add("moving");
    try {
      const changing=ready&&index!==at;
      const delay=changing&&!matchMedia("(prefers-reduced-motion: reduce)").matches?160:0;
      const [img]=await Promise.all([load(index),new Promise(done=>setTimeout(done,delay))]);
      if(id!==request||!active)return;
      if(changing){yaw=[9.3,-52,124][index];pitch=[-.4,-3,1][index]}
      at=index; ready=true;
      cube.style.setProperty("--atlas",'url("'+img.src+'")');
      cube.style.visibility="visible";
      status.textContent=stops[at]+" · "+(at+1)+"/3";
      hint.textContent="拖动环看";
      viewport.setAttribute("aria-label",stops[at]+"全景，拖动或用方向键环看");
      orient();
    } catch {
      if(id!==request||!active)return;
      failedStop=index;retry.hidden=false;hint.textContent="全景暂未载入";
    } finally {
      if(id===request&&active) {
        previous.disabled=at===0;next.disabled=at===stops.length-1;
        host.classList.remove("moving");
      }
    }
  }
  retry.onclick=()=>go(failedStop);
  previous.onclick=()=>go(at-1);next.onclick=()=>go(at+1);
  viewport.addEventListener("pointerdown",e=>{
    if(pointer||!ready||e.button!==0)return;
    pointer={id:e.pointerId,x:e.clientX,y:e.clientY};
    viewport.setPointerCapture(e.pointerId);
  });
  viewport.addEventListener("pointermove",e=>{
    if(pointer?.id!==e.pointerId)return;
    adjust((pointer.x-e.clientX)*.16,(e.clientY-pointer.y)*.16);
    pointer.x=e.clientX;pointer.y=e.clientY;
  });
  viewport.addEventListener("lostpointercapture",()=>{pointer=undefined});
  viewport.addEventListener("keydown",e=>{
    const delta={ArrowLeft:[-7,0],ArrowRight:[7,0],ArrowUp:[0,6],ArrowDown:[0,-6]}[e.key];
    if(delta){e.preventDefault();adjust(...delta)}
  });
  new ResizeObserver(()=>{if(active)orient()}).observe(viewport);
  return {
    show() {active=true;host.hidden=false;orient();go(at)},
    hide() {active=false;request++;host.hidden=true;host.classList.remove("moving")},
  };
}
