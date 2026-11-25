import * as THREE from "three";

// A linear irradiance factor baked in Blender, shared by the paving, grass and
// low curbs. Matching in world space keeps the stone joints and the shade aligned
// across both exported roots, including gltfpack's instanced geometry.
export async function loadCourtShade(renderer) {
  const source=document.getElementById("courtShade")?.textContent.trim();
  if(!source||source.startsWith("@@"))return null;
  try{
    const texture=await new THREE.TextureLoader().loadAsync("data:image/png;base64,"+source);
    const image=texture.image, limit=Math.min(renderer.capabilities.maxTextureSize,matchMedia("(pointer:coarse)").matches?1024:2048);
    if(Math.max(image.width,image.height)>limit){
      const scale=limit/Math.max(image.width,image.height), canvas=document.createElement("canvas");
      canvas.width=Math.max(1,Math.round(image.width*scale));canvas.height=Math.max(1,Math.round(image.height*scale));
      const context=canvas.getContext("2d");
      if(context){context.drawImage(image,0,0,canvas.width,canvas.height);texture.image=canvas}
    }
    texture.colorSpace=THREE.NoColorSpace;
    // PNG rows start at the north edge. Texture flipY places v=0 at the south.
    texture.flipY=true;texture.needsUpdate=true;
    return texture;
  }catch{return null}
}
const groundFinishes=new Set(["paver1","paver2","paver3","sand","kerb","meadow","loam","granite","granite2","stairrose","stairrose2","stairnosing","Cycle finish | Distant paving"]);
export function shadeGround(root,texture){
  if(!texture)return;
  const patched=new Set();
  root.traverse(o=>{
    if(!o.isMesh)return;
    for(const m of (Array.isArray(o.material)?o.material:[o.material])){
      if(patched.has(m)||!m.isMeshStandardMaterial||m.transparent)continue;
      if(!groundFinishes.has(m.name)&&!m.name.startsWith("Zhili arrival /"))continue;
      patched.add(m);
      const old=m.onBeforeCompile, key=m.customProgramCacheKey();
      m.customProgramCacheKey=()=>key+"|courtyard-floor-irradiance-1";
      m.onBeforeCompile=function(shader,renderer){
        old.call(this,shader,renderer);
        shader.uniforms.courtIrradiance={value:texture};
        shader.fragmentShader="uniform sampler2D courtIrradiance;\n"+shader.fragmentShader.replace(
          "#include <aomap_fragment>",`#include <aomap_fragment>
          vec3 courtP=cameraPosition+(-vViewPosition)*mat3(viewMatrix);
          vec2 courtUV=(vec2(courtP.x,-courtP.z)+vec2(46.,36.))/vec2(92.,72.);
          float courtUp=dot(normal,viewMatrix[1].xyz);
          if(courtP.y>-.35 && courtP.y<.82 && courtUp>.55 && all(greaterThanEqual(courtUV,vec2(0.))) && all(lessThanEqual(courtUV,vec2(1.)))) {
            float weight=(1.-smoothstep(.42,.82,courtP.y))*smoothstep(.55,.90,courtUp);
            float lightFactor=mix(1.,max(.55,texture2D(courtIrradiance,courtUV).r),weight);
            reflectedLight.indirectDiffuse*=lightFactor;
            reflectedLight.indirectSpecular*=mix(1.,lightFactor,.66);
            reflectedLight.directDiffuse*=mix(1.,lightFactor,.28);
          }`);
      };
      m.needsUpdate=true;
    }
  });
}
