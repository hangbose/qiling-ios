import * as THREE from "three";

// Contact shadows for the street-scale camera. The geometry and its depth are
// rendered together, so the extra pass is independent of campus mesh density.
export function streetLight(renderer) {
  if(!renderer.extensions.has("EXT_color_buffer_float")) return null;
  const gl=renderer.getContext();
  const counts=gl.getInternalformatParameter(gl.RENDERBUFFER,gl.RGBA16F,gl.SAMPLES);
  const samples=Array.from(counts||[]).find(n=>n<=4)||0;
  const output=new THREE.WebGLRenderTarget(1,1,{
    type:THREE.HalfFloatType,depthBuffer:true,samples
  });
  output.depthTexture=new THREE.DepthTexture(1,1,THREE.UnsignedIntType);
  const uniforms={
    colour:{value:output.texture},depth:{value:output.depthTexture},
    inverseProjection:{value:new THREE.Matrix4()},scale:{value:new THREE.Vector2()},
  };
  const material=new THREE.ShaderMaterial({
    uniforms,depthTest:false,depthWrite:false,
    vertexShader:`
      varying vec2 screen;
      void main() {
        screen=position.xy*.5+.5;
        gl_Position=vec4(position.xy,0.,1.);
      }`,
    fragmentShader:`
      varying vec2 screen;
      uniform sampler2D colour,depth;
      uniform mat4 inverseProjection;
      uniform vec2 scale;
      vec3 atDepth(vec2 at,float d) {
        vec4 p=inverseProjection*vec4(at*2.-1.,d*2.-1.,1.);
        return p.xyz/p.w;
      }
      void main() {
        vec3 base=texture2D(colour,screen).rgb;
        float z=texture2D(depth,screen).r;
        vec3 p=atDepth(screen,z);
        vec3 n=normalize(cross(dFdx(p),dFdy(p)));
        float occlusion=0.;
        if(z<.99999 && -p.z<48.) {
          for(int i=0;i<12;i++) {
            float a=float(i)*2.39996;
            float reach=.95*sqrt((float(i)+.5)/12.);
            vec2 sampleAt=clamp(screen+vec2(cos(a),sin(a))*scale*(reach/max(.45,-p.z)),.001,.999);
            vec3 diff=atDepth(sampleAt,texture2D(depth,sampleAt).r)-p;
            float distanceToSurface=length(diff);
            float horizon=dot(n,diff)/max(distanceToSurface,.001);
            occlusion+=max(0.,horizon-.07)*(1.-smoothstep(.06,1.15,distanceToSurface));
          }
          base*=1.-min(.40,occlusion*.15);
        }
        gl_FragColor=vec4(base,1.);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
  });
  const geometry=new THREE.BufferGeometry();
  geometry.setAttribute("position",new THREE.Float32BufferAttribute([-1,-1,0,3,-1,0,-1,3,0],3));
  const screen=new THREE.Scene(),ortho=new THREE.OrthographicCamera(-1,1,1,-1,0,1);
  const triangle=new THREE.Mesh(geometry,material);triangle.frustumCulled=false;screen.add(triangle);
  return function drawStreet(scene,camera){
    const {width,height}=renderer.domElement;
    if(output.width!==width||output.height!==height)output.setSize(width,height);
    uniforms.inverseProjection.value.copy(camera.projectionMatrixInverse);
    uniforms.scale.value.set(camera.projectionMatrix.elements[0]*.5,camera.projectionMatrix.elements[5]*.5);
    renderer.setRenderTarget(output);renderer.render(scene,camera);
    renderer.setRenderTarget(null);renderer.render(screen,ortho);
  };
}
