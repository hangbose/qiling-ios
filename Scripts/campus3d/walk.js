import {entrances,moveOnGround,placeName,floorAt} from "./walk-ground.mjs";

export function streetWalk(camera,canvas,host,draw,exhibit) {
  const pad=host.querySelector(".walk-pad"),nub=pad.querySelector(".walk-nub"),label=host.querySelector(".walk-place");
  const slow=matchMedia("(prefers-reduced-motion: reduce)");
  const state={x:0,z:0,h:.14};
  const held=new Set();
  let active=false,frame=0,last=0,yaw=0,pitch=0,vx=0,vz=0,eyeHeight=0;
  let stick=null,look=null,forward=0,side=0,oldName="";
  let eye=1.62;
  function pose(){
    camera.position.set(state.x,eyeHeight+eye,state.z);
    camera.rotation.set(pitch,yaw,0,"YXZ");
    const name=placeName(state);
    if(oldName!==name){oldName=name;label.textContent=name}
    exhibit.near(state.x,state.z,state.h);draw();
  }
  function wake(){if(active&&!frame&&!document.hidden){last=performance.now();frame=requestAnimationFrame(tick)}}
  function tick(now){
    const dt=Math.min(.065,Math.max(0,(now-last)/1000));
    last=now;
    let f=forward+Number(held.has("KeyW")||held.has("ArrowUp"))-Number(held.has("KeyS")||held.has("ArrowDown"));
    let s=side+Number(held.has("KeyD"))-Number(held.has("KeyA"));
    const scale=Math.max(1,Math.hypot(f,s));f/=scale;s/=scale;
    const turning=Number(held.has("ArrowLeft"))-Number(held.has("ArrowRight"));
    yaw+=turning*1.55*dt;
    const speed=held.has("ShiftLeft")||held.has("ShiftRight")?4.2:2.65;
    const targetX=(Math.cos(yaw)*s-Math.sin(yaw)*f)*speed;
    const targetZ=(-Math.sin(yaw)*s-Math.cos(yaw)*f)*speed;
    const blend=slow.matches?1:1-Math.exp(-dt*14);
    vx+=(targetX-vx)*blend;vz+=(targetZ-vz)*blend;
    moveOnGround(state,vx*dt,vz*dt);
    eyeHeight+=(state.h-eyeHeight)*(slow.matches?1:1-Math.exp(-dt*15));
    pose();
    if(forward||side||held.size||Math.abs(vx)+Math.abs(vz)>.015||Math.abs(eyeHeight-state.h)>.002)frame=requestAnimationFrame(tick);
    else {frame=0;vx=0;vz=0}
  }
  function resetInput(){
    held.clear();forward=side=vx=vz=0;stick=look=null;
    nub.style.transform="";cancelAnimationFrame(frame);frame=0;
  }
  function focusCanvas(){canvas.focus({preventScroll:true})}
  function start(name){
    resetInput();host.querySelector(".walk-help").open=false;
    const e=entrances[name]||entrances.arrival;
    state.x=e.x;state.z=e.z;state.h=floorAt(e.x,e.z)??.14;eyeHeight=state.h;
    eye=e.worldEye===undefined?1.62:e.worldEye-state.h;
    yaw=Math.atan2(state.x-e.lookX,state.z-e.lookZ);pitch=e.pitch;
    active=true;host.classList.add("walking");canvas.tabIndex=0;
    pose();
  }
  function stop(){
    active=false;exhibit.leave();resetInput();host.classList.remove("walking");canvas.removeAttribute("tabindex");
  }
  const keys=new Set(["KeyW","KeyA","KeyS","KeyD","ArrowUp","ArrowDown","ArrowLeft","ArrowRight","ShiftLeft","ShiftRight"]);
  function withinView(){
    const rect=host.getBoundingClientRect();
    return rect.bottom>80 && rect.top<innerHeight-80;
  }
  window.addEventListener("keydown",event=>{
    if(!active||exhibit.reading()||!withinView()||event.metaKey||event.ctrlKey||event.altKey)return;
    if(event.code==="Escape"&&(host.contains(document.activeElement)||document.activeElement===document.body)){location.hash="garden";return}
    if(!keys.has(event.code)||!([host,canvas,document.body].includes(document.activeElement)))return;
    event.preventDefault();held.add(event.code);wake();
  });
  window.addEventListener("keyup",e=>held.delete(e.code));
  window.addEventListener("blur",resetInput);
  host.addEventListener("exhibitopen",resetInput);
  document.addEventListener("visibilitychange",()=>{if(document.hidden)resetInput()});
  host.addEventListener("focusout",e=>{if(!host.contains(e.relatedTarget))resetInput()});
  new IntersectionObserver(rows=>{if(!rows[0].isIntersecting)resetInput()}).observe(host);
  canvas.addEventListener("pointerdown",e=>{
    if(!active||exhibit.reading()||look!==null||e.button!==0)return;
    focusCanvas();canvas.setPointerCapture(e.pointerId);look={id:e.pointerId,x:e.clientX,y:e.clientY};
  });
  canvas.addEventListener("pointermove",e=>{
    if(!look||e.pointerId!==look.id)return;
    const sensitivity=Math.PI/Math.max(360,canvas.clientHeight*1.4);
    yaw-=(e.clientX-look.x)*sensitivity;
    pitch=Math.max(-1.08,Math.min(1.12,pitch-(e.clientY-look.y)*sensitivity));
    look.x=e.clientX;look.y=e.clientY;pose();
  });
  canvas.addEventListener("lostpointercapture",e=>{if(look?.id===e.pointerId)look=null});
  function joystick(e){
    const r=pad.getBoundingClientRect(),dx=e.clientX-r.left-r.width/2,dz=e.clientY-r.top-r.height/2;
    const max=r.width*.33,length=Math.hypot(dx,dz),ratio=1/Math.max(max,length);
    side=dx*ratio;forward=-dz*ratio;
    if(length<max*.14)side=forward=0;
    nub.style.transform="translate("+side*max+"px,"+-forward*max+"px)";wake();
  }
  pad.addEventListener("pointerdown",e=>{
    if(!active||exhibit.reading()||stick!==null||e.button!==0)return;
    e.preventDefault();stick=e.pointerId;pad.setPointerCapture(stick);joystick(e);
  });
  pad.addEventListener("pointermove",e=>{if(stick===e.pointerId)joystick(e)});
  pad.addEventListener("lostpointercapture",e=>{
    if(stick!==e.pointerId)return;stick=null;side=forward=0;nub.style.transform="";wake();
  });
  // The four buttons also work as discrete commands using a switch or screen reader.
  for(const button of host.querySelectorAll("[data-walk-command]")){
    const command=button.dataset.walkCommand;
    function tap(){
      if(!active)return;
      if(command==="left"||command==="right")yaw+=(command==="left"?1:-1)*Math.PI/12;
      else {const d=command==="ahead"?1:-1;moveOnGround(state,-Math.sin(yaw)*d,-Math.cos(yaw)*d);eyeHeight=state.h}
      pose();
    }
    button.addEventListener("click",tap);
  }
  return {start,stop,get active(){return active}};
}
