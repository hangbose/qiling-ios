// Distances are metres in the Y-up viewer. Blender positive Y points to negative Z.
const pad = .29;
const ground = .14;
const obstacles = [];
function box(x,z,width,depth) {
  obstacles.push([x-width/2-pad,x+width/2+pad,z-depth/2-pad,z+depth/2+pad]);
}
for (const x of [-21,-8.15,4.85,17.85]) for (const z of [13.79,4]) box(x,z,1.04,1.09);
for (const x of [-17.2,-3.85,4.25,12.3]) box(x,2,.76,.9);
for (const x of [24.4,30.35,36.35,41.85]) box(x,7.35,1.04,1.15);
for (const x of [-4.4,2,8.4]) box(x,.7,.78,.92);
box(-9.95,-6.22,2.06,.54); // bench near the west lobby doors
box(-7.1,-6.66,2.26,.40); // glazed notice board against the rear wall
box(23.2,17.6,.2,.2); // directional post
box(-1.05,14.72,4.23,.47); // psychology sign
box(-22,15.9,14.78,2.18);
box(-23.3,9.8,9.4,.28);
box(-10.85,15.65,3.8,1.72); // parked bicycles
for (const [x,z,width] of [[-38,21,1],[43.1,18,.75],[29.7,12.2,.65]]) box(x,z,width,width);
function inside(x,z,x0,x1,z0,z1) {return x>=x0&&x<=x1&&z>=z0&&z<=z1}

export const entrances = {
  street:{x:-17.1,z:18.8,lookX:-11.4,lookZ:14.6,pitch:-.061,worldEye:1.57},
  arrival:{x:15,z:33,lookX:2,lookZ:1,pitch:.13},
  front:{x:1.8,z:29.5,lookX:.8,lookZ:0,pitch:.10},
  gallery:{x:-7.25,z:-2.0,lookX:-7.1,lookZ:-6.66,pitch:.01},
  shelter:{x:-16.5,z:10.9,lookX:7,lookZ:4.8,pitch:.04},
  steps:{x:32.5,z:25,lookX:32.5,lookZ:5,pitch:.22},
};
const bRun=(15.42-2*1.08)/37;
function bHeight(z) {
  let d=20.70-z, climbed=0;
  for (const count of [12,12,13]) {
    if(d<=count*bRun) return .24+(climbed+Math.ceil(Math.max(0,d)/bRun))*.17;
    climbed+=count;d-=count*bRun;
    if(d<=1.08)return .24+climbed*.17;
    d-=1.08;
  }
  return 6.53;
}
function nearestLevel(current, candidates) {
  let nearest=null,delta=.34; // One ordinary riser, including the transition from the paving.
  for (const h of candidates) if(Math.abs(h-current)<delta) {nearest=h;delta=Math.abs(h-current)}
  return nearest;
}
export function floorAt(x,z,height=ground) {
  // Courtyard apron, shaded C lobby up to the actual glass doors, exterior B approach.
  const yard=inside(x,z,-42,42.8,10.35,35.35);
  const lobby=inside(x,z,-17.6,18.3,-6.18,14.6);
  const east=inside(x,z,18.35,42.8,2.8,20.8);
  if(!yard&&!lobby&&!east)return null;
  if(obstacles.some(bounds=>inside(x,z,...bounds)))return null;
  if(lobby&&inside(x,z,-6,10,-6.3,-2.20))return null;
  const onB=inside(x,z,30.65,42.35,5.28,20.7);
  if(onB){
    if(x<31.11||x>41.89)return null;
    // Both intermediate handrails stop at the cross-landings.
    const d=20.7-z, landing=[12*bRun,24*bRun+1.08].some(start=>d>start+.28&&d<start+.80);
    if(!landing&&(Math.abs(x-34.51)<.31||Math.abs(x-38.61)<.31))return null;
    return nearestLevel(height,[bHeight(z)]);
  }
  const bDeck=inside(x,z,18.7,37.31,3.12,8.27);
  // Ground under the horizontal bridge and the upper deck are separately reachable.
  if(bDeck)return nearestLevel(height,[ground,6.61]);
  if(inside(x,z,-2.85,6.0,4.16,7.24)){
    if(z<4.67||z>6.73)return null;
    return nearestLevel(height,[.23+3.51*Math.ceil((x+2.85)*24/8.85)/24]);
  }
  if(inside(x,z,6,7.52,1.19,7.15)) {
    if(x>6.90||z>6.82||z<1.51)return null;
    return nearestLevel(height,[3.74]);
  }
  // The upper C flight runs beneath a continuous soffit in the architectural model.
  // Limit access to the intermediate landing until the upper stairwell has headroom.
  if(inside(x,z,-4.2,6.0,1.10,4.16))return nearestLevel(height,[ground]);
  const lawn=inside(x,z,-34,-12,17.5,26.5)||inside(x,z,-7.5,11.5,17,27)||inside(x,z,15.5,22.5,15,19);
  return nearestLevel(height,[lawn ? .25 : ground]);
}
export function moveOnGround(state,dx,dz) {
  // Sweep in substeps even at a low frame rate. Axis sliding lets you skim a wall.
  const n=Math.max(1,Math.ceil(Math.hypot(dx,dz)/.12));
  for(let i=0;i<n;i++){
    const xx=state.x+dx/n,zz=state.z+dz/n;
    const hx=floorAt(xx,state.z,state.h);
    if(hx!==null){state.x=xx;state.h=hx}
    const hz=floorAt(state.x,zz,state.h);
    if(hz!==null){state.z=zz;state.h=hz}
  }
}
export function placeName({x,z,h}){
  if(x>23&&z<21&&h>.4)return h>6.45?"B 座 · 上层平台":"B 座 · 室外阶梯";
  if(h>1&&x<10)return "C 座 · 折返楼梯";
  if(x>26)return "B 座 · 东侧庭院";
  if(z<14.4&&x>-20&&x<19)return "C 座 · 檐下柱廊";
  return "致理楼 · 前庭";
}
