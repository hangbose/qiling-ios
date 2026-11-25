import * as THREE from "three";
import {streetWalk} from "./walk.js";
import {streetExhibit} from "./exhibit.js";
import {streetLight} from "./street-light.js";
import {loadCourtShade,shadeGround} from "./court-shade.js";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { MeshoptDecoder } from "three/addons/libs/meshopt_decoder.module.js";
import { HDRLoader } from "three/addons/loaders/HDRLoader.js";

export const sites = [
  {name:"桑田广场边", x:-18, z:23},
  {name:"连廊树下", x:-34, z:12},
  {name:"楼间小庭院", x:4, z:21},
];
export const colors = {jade:0x298c80, apricot:0xbd673f, violet:0x8671b2};
export const radius = total => total >= 80 ? 7.2 : total >= 50 ? 5.7 : 4.2;
// Blender study cameras, in Three's Y-up coordinates. The film offset preserves verticals.
const cameras = {
  arrival:{eye:[19,1.72,54], target:[0,4.5,-6], lens:22.5, shift:.19, aspect:1840/1200},
  front:{eye:[.04,3.30,42.5], target:[.04,3.30,0], lens:23, shift:.124, aspect:1440/632},
  shelter:{eye:[-17.1,1.6,11], target:[9,2.3,4.5], lens:22, shift:.04, aspect:1560/1040},
};

export function campusScene(host, select, enter, busy) {
  const renderer = new THREE.WebGLRenderer({antialias:true,alpha:true,powerPreference:"low-power"});
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.8));
  renderer.setClearColor(0x000000,0);renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  renderer.shadowMap.autoUpdate=false;
  renderer.outputColorSpace=THREE.SRGBColorSpace;
  renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;
  host.prepend(renderer.domElement);
  const scene=new THREE.Scene(), camera=new THREE.PerspectiveCamera(32,1,.5,700);
  const control=new OrbitControls(camera,renderer.domElement);
  control.enablePan=false;control.minPolarAngle=.12;control.maxPolarAngle=Math.PI*.51;
  control.addEventListener("change",requestDraw);
  const skyBytes=Uint8Array.from(atob(document.getElementById("coastalSky").textContent.trim()),ch=>ch.charCodeAt(0));
  const hdr=new HDRLoader().parse(skyBytes.buffer);
  const sky=new THREE.DataTexture(hdr.data,hdr.width,hdr.height,THREE.RGBAFormat,hdr.type);
  sky.flipY=true;sky.colorSpace=THREE.LinearSRGBColorSpace;sky.mapping=THREE.EquirectangularReflectionMapping;sky.needsUpdate=true;
  const pmrem=new THREE.PMREMGenerator(renderer);
  scene.environment=pmrem.fromEquirectangular(sky).texture;scene.environmentIntensity=.56;
  pmrem.dispose();
  const daylight=new THREE.HemisphereLight(0xe1ebee,0xb6aa91,1.0);
  scene.add(daylight);
  const sun=new THREE.DirectionalLight(0xffe6c9,2.7);
  sun.castShadow=true;scene.add(sun,sun.target);
  const shadowSize=Math.min(renderer.capabilities.maxTextureSize,matchMedia("(pointer:coarse)").matches?1024:2048);
  sun.shadow.mapSize.set(shadowSize,shadowSize);
  function lightCourt(near){
    const span=near?45:100;
    const target=sun.target.position.set(0,near?6:0,near?14:0);
    sun.position.set(near?52:-68,near?51:110,near?68:62).add(target);
    sun.color.setHex(near?0xffdeaf:0xffe6c9);sun.intensity=near?2.65:2.7;
    daylight.intensity=near ? .70 : 1;scene.environmentIntensity=near ? .64 : .56;
    renderer.toneMappingExposure=near?1.02:1.1;
    Object.assign(sun.shadow.camera,{left:-span,right:span,top:span,bottom:-span,near:1,far:300});
    sun.shadow.camera.updateProjectionMatrix();
    sun.shadow.bias=near?-.000095:-.00035;sun.shadow.normalBias=near ? .028 : .09;
    renderer.shadowMap.needsUpdate=true;
  }
  lightCourt(false);
  const floor=new THREE.Mesh(new THREE.PlaneGeometry(1200,1200),new THREE.ShadowMaterial({opacity:.16}));
  floor.rotation.x=-Math.PI/2;floor.position.y=-3.45;floor.receiveShadow=true;scene.add(floor);
  const assets={}, promises={}, loader=new GLTFLoader().setMeshoptDecoder(MeshoptDecoder);
  let courtTexture;
  let current="Zhili",selected=0,plotRows=[],prior=[],history=false,frame=0,revision=0;
  const marks=new THREE.Group();scene.add(marks);
  const chip=document.createElement("button");chip.className="place-label";host.append(chip);
  chip.onclick=()=>current==="Yuehai"?enter():focus(selected);
  let drawStreet;
  function requestDraw(){if(!frame)frame=requestAnimationFrame(draw)}
  function draw(){
    frame=0;
    const wide=current==="Yuehai";
    const s=sites[selected],p=new THREE.Vector3(wide?29:s.x,wide?3:2,wide?18:s.z);
    camera.updateMatrixWorld();
    p.project(camera);
    chip.hidden=walker.active||!assets[current]?.visible||p.z < -1||p.z > 1||Math.abs(p.x)>1||Math.abs(p.y)>1;
    chip.style.left=(50+50*p.x)+"%";chip.style.top="calc("+(50-50*p.y)+"% - 12px)";
    chip.textContent=wide?"致理楼 ↗":s.name;
    if(walker.active&&drawStreet)drawStreet(scene,camera);else renderer.render(scene,camera);
  }
  const exhibit=streetExhibit(host,renderer.domElement);
  const walker=streetWalk(camera,renderer.domElement,host,requestDraw,exhibit);
  let footprint="";
  function resize(){
    const w=host.clientWidth,h=host.clientHeight;
    if(!w||!h)return;
    camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h,false);
    if(!footprint || (footprint==="portrait")!==(w/h<1)){footprint=w/h<1?"portrait":"landscape";if(!walker.active)reset()}
    requestDraw();
  }
  new ResizeObserver(resize).observe(host);
  let flight=0;
  function stopFlight(){cancelAnimationFrame(flight);flight=0}
  control.addEventListener("start",stopFlight);
  function focus(index){
    if(current!=="Zhili"||walker.active)return;
    stopFlight();
    camera.clearViewOffset();
    const s=sites[index],dest=new THREE.Vector3(s.x,1.4,s.z);
    const eye=dest.clone().add(new THREE.Vector3(-17,18,29));
    const from=camera.position.clone(),origin=control.target.clone(),start=performance.now();
    const duration=matchMedia("(prefers-reduced-motion: reduce)").matches?0:480;
    function move(now){
      const t=duration?Math.min(1,(now-start)/duration):1;
      const amount=t*t*(3-2*t);
      camera.position.lerpVectors(from,eye,amount);control.target.lerpVectors(origin,dest,amount);control.update();requestDraw();
      if(t<1)flight=requestAnimationFrame(move);
    }
    move(start);
  }
  function reset(){
    stopFlight();
    camera.clearViewOffset();
    const wide=current==="Yuehai";
    const scale=Math.max(1,1.25/Math.max(.5,camera.aspect));
    camera.near=.5;camera.fov=wide?32:35;camera.updateProjectionMatrix();
    scene.background=null;
    camera.position.copy(wide?new THREE.Vector3(38,147,144):new THREE.Vector3(-38,33,105)).multiplyScalar(scale);
    control.target.set(0,wide?0:16,0);control.minDistance=wide?72:14;control.maxDistance=340;
    control.update();requestDraw();
  }
  function photograph(name){
    if(current!=="Zhili")return;
    stopFlight();
    const shot=cameras[name];
    const width=host.clientWidth,height=host.clientHeight;
    const fitAspect=Math.max(shot.aspect,width/height);
    camera.fov=THREE.MathUtils.radToDeg(2*Math.atan(18/(shot.lens*fitAspect)));
    camera.setViewOffset(width,height,0,-height*fitAspect*shot.shift,width,height);
    scene.background=sky;scene.backgroundIntensity=.90;scene.backgroundBlurriness=.14;
    camera.position.fromArray(shot.eye);control.target.fromArray(shot.target);
    control.minDistance=3;control.update();requestDraw();
  }
  async function load(which){
    if(!promises[which]) promises[which]=(async()=>{
      const source=document.getElementById(which).textContent.trim();
      const raw=atob(source),bytes=new Uint8Array(raw.length);
      for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);
      const shade=which==="Yuehai"?null:(courtTexture??=loadCourtShade(renderer));
      const [gltf,texture]=await Promise.all([loader.parseAsync(bytes.buffer,""),shade]);
      shadeGround(gltf.scene,texture);
      gltf.scene.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true}});
      gltf.scene.visible=false;scene.add(gltf.scene);assets[which]=gltf.scene;
    })();
    return promises[which];
  }
  function suspend(){
    ++revision;stopFlight();walker.stop();control.enabled=true;
    for(const group of marks.children)group.visible=true;
    host.classList.remove("walk-mode");
  }
  async function show(which, shot, walking=false){
    suspend();host.classList.toggle("walk-mode",walking);
    const seq=++revision;current=which;busy("正在展开校园模型…");
    lightCourt(walking);marks.visible=which==="Zhili";chip.hidden=true;
    Object.values(assets).forEach(o=>o.visible=false);
    reset();
    if(which==="Zhili" && !walking && Object.hasOwn(cameras,shot))photograph(shot);
    requestDraw();
    try {
      if(which==="Zhili")await Promise.all([load(which),load("Street")]);else await load(which);
      if(seq!==revision)return;
      assets[which].visible=true;if(which==="Zhili")assets.Street.visible=true;
      if(walking){
        control.enabled=false;camera.clearViewOffset();camera.near=.1;camera.fov=62;camera.updateProjectionMatrix();
        scene.background=sky;scene.backgroundIntensity=.88;scene.backgroundBlurriness=.13;
        if(drawStreet===undefined)drawStreet=streetLight(renderer);
        exhibit.setModel(assets.Street);walker.start(shot);
        for(const group of marks.children)group.visible=group.userData.occupied;
      }
      renderer.shadowMap.needsUpdate=true;busy("");requestDraw();
    }
    catch(e){if(seq===revision)busy("模型暂时没有打开，刷新后可以再试。");throw e}
  }
  const solids=new Map(), geometry=new Map();
  function mat(color) {
    if(!solids.has(color))solids.set(color,new THREE.MeshStandardMaterial({color,roughness:.9}));
    return solids.get(color);
  }
  function primitive(kind,c,x,y,z,sx,sy,sz,parent){
    if(!geometry.has(kind)){
      const mesh=kind==="ball"?new THREE.IcosahedronGeometry(1,0):kind==="cone"?new THREE.ConeGeometry(1,1,8):
        kind==="pot"?new THREE.CylinderGeometry(1,.74,1,10):new THREE.BoxGeometry(1,1,1);
      geometry.set(kind,mesh);
    }
    const object=new THREE.Mesh(geometry.get(kind),mat(c));object.position.set(x,y,z);object.scale.set(sx,sy,sz);
    object.castShadow=true;parent.add(object);return object;
  }
  function ornament(kind,group,x,z,scale=1){
    const base=new THREE.Group();base.position.set(x,.26,z);base.scale.setScalar(scale);group.add(base);
    if(kind==="flowers"){
      primitive("pot",0xb77558,0,.62,0,1.12,1.16,1.12,base);
      for(let i=0;i<8;i++){
        const a=i*2.4,dx=Math.cos(a)*.77,dz=Math.sin(a)*.77,hh=1.8+(i%3)*.21;
        primitive("box",0x537852,dx,hh-.65,dz,.09,1.35,.09,base);
        primitive("ball",i%2?0xdd8b91:0xf4b4a3,dx,hh+.18,dz,.46,.44,.46,base);
      }
    }else if(kind==="lamp"){
      primitive("pot",0x314b4a,0,.24,0,.94,.45,.94,base);primitive("box",0x65776a,0,1.8,0,.25,3.2,.25,base);
      primitive("box",0xffd994,0,3.5,0,1.3,1.24,1.3,base);primitive("cone",0x43675c,0,4.45,0,1.19,.85,1.19,base);
    }else if(kind==="flag"){
      primitive("pot",0xb38765,0,.22,0,.85,.38,.85,base);primitive("box",0x6b6756,0,2.3,0,.18,4.6,.18,base);
      primitive("box",0xdb956b,.98,3.86,0,1.9,1.14,.14,base);primitive("ball",0xffcd81,0,4.72,0,.22,.22,.22,base);
    }
  }
  const disk=new THREE.CircleGeometry(1,48),ring=new THREE.RingGeometry(.96,1,48);
  function paint(){
    for(const o of marks.children){o.traverse(k=>{if(k.userData.ownedMaterial)k.material.dispose()})}
    marks.clear();
    for(let i=0;i<sites.length;i++){
      const s=sites[i],p=plotRows.find(row=>row.site===i),old=prior.find(row=>row.site===i&&row.ornament);
      const color=colors[p?.tint]??(p?.mine?colors.jade:p?colors.apricot:0xac9877);
      const rad=p?radius(p.health+(p.bonus||0)):3.6;
      const group=new THREE.Group();group.userData.site=i;
      group.userData.occupied=Boolean(p||(old&&history));
      group.visible=!walker.active||group.userData.occupied;marks.add(group);
      for(const [geo,y,alpha] of [[disk,.26,p ? .36 : .16],[ring,.28,i===selected?1:.78]]){
        const mesh=new THREE.Mesh(geo,new THREE.MeshBasicMaterial({color,transparent:true,opacity:alpha,depthWrite:false}));
        mesh.userData.ownedMaterial=true;mesh.rotation.x=-Math.PI/2;mesh.position.set(s.x,y,s.z);
        mesh.scale.setScalar(rad);group.add(mesh);
      }
      if(p?.ornament)ornament(p.ornament,group,s.x,s.z);
      if(old&&history)ornament(old.ornament,group,s.x+2.9,s.z+.5,.72);
      if(p){
        for(let j=0;j<6;j++){
          const a=j*Math.PI/3,px=s.x+Math.cos(a)*rad,pz=s.z+Math.sin(a)*rad;
          primitive("box",0xb89670,px,.52,pz,.22,.65,.22,group);
          primitive("ball",color,px,.91,pz,.22,.22,.22,group);
        }
      }
    }
    renderer.shadowMap.needsUpdate=true;requestDraw();
  }
  let down=null;
  renderer.domElement.addEventListener("pointerdown",e=>{down=walker.active?null:[e.clientX,e.clientY]});
  renderer.domElement.addEventListener("pointerup",e=>{
    if(!down||Math.hypot(e.clientX-down[0],e.clientY-down[1])>7)return;
    const rect=renderer.domElement.getBoundingClientRect(),ray=new THREE.Raycaster();
    ray.setFromCamera(new THREE.Vector2((e.clientX-rect.left)/rect.width*2-1,1-(e.clientY-rect.top)/rect.height*2),camera);
    if(current==="Yuehai")return;
    const hit=ray.intersectObjects(marks.children,true)[0];
    if(hit){let o=hit.object;while(o&&o.userData.site===undefined)o=o.parent;if(o)select(o.userData.site)}
  });
  resize();
  return {show,suspend,reset,focus,entrance:()=>photograph("front"),update(i,rows,past,showPast){selected=i;plotRows=rows;prior=past;history=showPast;paint()}};
}
