import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

export const sites = [
  {name:"桑田广场边", x:-18, z:15},
  {name:"连廊树下", x:-27, z:0},
  {name:"楼间小庭院", x:6, z:0},
];
export const colors = {jade:0x298c80, apricot:0xbd673f, violet:0x8671b2};
export const radius = total => total >= 80 ? 7.2 : total >= 50 ? 5.7 : 4.2;

export function campusScene(host, select, enter, busy) {
  const renderer = new THREE.WebGLRenderer({antialias:true,alpha:true,powerPreference:"low-power"});
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.8));
  renderer.setClearColor(0x000000,0);renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  renderer.outputColorSpace=THREE.SRGBColorSpace;
  host.prepend(renderer.domElement);
  const scene=new THREE.Scene(), camera=new THREE.PerspectiveCamera(32,1,.5,700);
  const control=new OrbitControls(camera,renderer.domElement);
  control.enablePan=false;control.minPolarAngle=.12;control.maxPolarAngle=Math.PI*.46;
  control.addEventListener("change",requestDraw);
  scene.add(new THREE.HemisphereLight(0xfff4dc,0xbec7ad,2.15));
  const sun=new THREE.DirectionalLight(0xffe1b1,2.45);
  sun.position.set(-68,110,62);sun.castShadow=true;
  Object.assign(sun.shadow.camera,{left:-92,right:92,top:90,bottom:-90,far:300});
  sun.shadow.mapSize.set(1024,1024);sun.shadow.bias=-.00065;sun.shadow.normalBias=.11;scene.add(sun);
  const floor=new THREE.Mesh(new THREE.PlaneGeometry(1200,1200),new THREE.ShadowMaterial({opacity:.16}));
  floor.rotation.x=-Math.PI/2;floor.position.y=-3.45;floor.receiveShadow=true;scene.add(floor);
  const assets={}, promises={}, loader=new GLTFLoader();
  let current="Zhili",selected=0,plotRows=[],prior=[],history=false,frame=0,revision=0;
  const marks=new THREE.Group();scene.add(marks);
  const chip=document.createElement("button");chip.className="place-label";host.append(chip);
  chip.onclick=()=>current==="Yuehai"?enter():select(selected);
  function requestDraw(){if(!frame)frame=requestAnimationFrame(draw)}
  function draw(){
    frame=0;
    const wide=current==="Yuehai";
    chip.hidden=!assets[current]?.visible;
    const s=sites[selected],p=new THREE.Vector3(wide?29:s.x,wide?3:2,wide?18:s.z);
    p.project(camera);
    chip.style.left=(50+50*p.x)+"%";chip.style.top=(50-50*p.y)+"%";
    chip.textContent=wide?"致理楼 ↗":s.name;
    renderer.render(scene,camera);
  }
  let footprint="";
  function resize(){
    const w=host.clientWidth,h=host.clientHeight;
    if(!w||!h)return;
    camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h,false);
    if(!footprint || (footprint==="portrait")!==(w/h<1)){footprint=w/h<1?"portrait":"landscape";reset()}
    requestDraw();
  }
  new ResizeObserver(resize).observe(host);
  function reset(){
    const wide=current==="Yuehai";
    const scale=Math.max(1,1.25/Math.max(.5,camera.aspect));
    camera.position.copy(wide?new THREE.Vector3(38,147,144):new THREE.Vector3(-70,70,108)).multiplyScalar(scale);
    control.target.set(0,wide?0:4,0);control.minDistance=wide?72:23;control.maxDistance=340;
    control.update();requestDraw();
  }
  async function load(which){
    if(!promises[which]) promises[which]=(async()=>{
      const source=document.getElementById(which).textContent.trim();
      const raw=atob(source),bytes=new Uint8Array(raw.length);
      for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);
      const gltf=await loader.parseAsync(bytes.buffer,"");
      gltf.scene.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true}});
      gltf.scene.visible=false;scene.add(gltf.scene);assets[which]=gltf.scene;
    })();
    return promises[which];
  }
  async function show(which){
    const seq=++revision;current=which;busy("正在展开校园模型…");
    marks.visible=which==="Zhili";chip.hidden=true;
    Object.values(assets).forEach(o=>o.visible=false);
    reset();requestDraw();
    try {await load(which);if(seq!==revision)return;assets[which].visible=true;busy("");requestDraw()}
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
      const group=new THREE.Group();group.userData.site=i;marks.add(group);
      for(const [geo,y,alpha] of [[disk,.26,p ? .36 : .16],[ring,.28,i===selected?1:.78]]){
        const mesh=new THREE.Mesh(geo,new THREE.MeshBasicMaterial({color,transparent:true,opacity:alpha,depthWrite:false}));
        mesh.userData.ownedMaterial=true;mesh.rotation.x=-Math.PI/2;mesh.position.set(s.x,y,s.z);
        mesh.scale.setScalar(rad);group.add(mesh);
      }
      if(p?.ornament)ornament(p.ornament,group,s.x,s.z);
      if(old&&history)ornament(old.ornament,group,s.x+2.9,s.z+.5,.72);
    }
    requestDraw();
  }
  let down=null;
  renderer.domElement.addEventListener("pointerdown",e=>{down=[e.clientX,e.clientY]});
  renderer.domElement.addEventListener("pointerup",e=>{
    if(!down||Math.hypot(e.clientX-down[0],e.clientY-down[1])>7)return;
    const rect=renderer.domElement.getBoundingClientRect(),ray=new THREE.Raycaster();
    ray.setFromCamera(new THREE.Vector2((e.clientX-rect.left)/rect.width*2-1,1-(e.clientY-rect.top)/rect.height*2),camera);
    if(current==="Yuehai")return;
    const hit=ray.intersectObjects(marks.children,true)[0];
    if(hit){let o=hit.object;while(o&&o.userData.site===undefined)o=o.parent;if(o)select(o.userData.site)}
  });
  resize();
  return {show,reset,update(i,rows,past,showPast){selected=i;plotRows=rows;prior=past;history=showPast;paint()}};
}
