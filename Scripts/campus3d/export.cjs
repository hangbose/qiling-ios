// Blender: run model.py with the output directory after --.
// node export.cjs <glb directory> <node_modules with three@0.180.0, esbuild@0.25.12 and gltfpack@0.24.0> <output.html>
const fs = require("node:fs");
const path = require("node:path");
const {execFileSync} = require("node:child_process");
const os = require("node:os");
const [models, modules, output] = process.argv.slice(2).map(p => path.resolve(p));
const {buildSync} = require(path.join(modules, "esbuild"));
const js = buildSync({ entryPoints:[path.join(__dirname,"garden.js")], bundle:true, minify:true,
  format:"iife", target:["safari17","chrome110"], write:false, legalComments:"inline", nodePaths:[modules] }).outputFiles[0].text;
let html = fs.readFileSync(path.join(__dirname,"page.html.in"),"utf8");
html=html.replace("@@sky@@",()=>fs.readFileSync(path.join(__dirname,"coastal-sky.hdr")).toString("base64"));
for(const photo of ["front","evening","corridor-front","corridor-0","corridor-1","corridor-2"]) {
  html=html.replace("@@"+photo+"@@",()=>fs.readFileSync(path.join(__dirname,photo+".webp")).toString("base64"));
}
const scratch = fs.mkdtempSync(path.join(os.tmpdir(),"zhili-pack-"));
try {
  for (const name of ["Zhili","Yuehai"]) {
    const packed=path.join(scratch,name+".glb");
    execFileSync(process.execPath,[path.join(modules,"gltfpack/cli.js"),"-i",path.join(models,name+".glb"),"-o",packed,"-cc","-vp","16"]);
    html=html.replace("@@"+name+"@@",()=>fs.readFileSync(packed).toString("base64"));
  }
} finally {
  fs.rmSync(scratch,{recursive:true,force:true});
}
const license = fs.readFileSync(path.join(modules,"three/LICENSE"),"utf8");
html = html.replace("<!--SCRIPT-->", () => "<!--\n"+license+"\n-->\n<script>"+js.replace(/<\/script/gi,"<\\/script")+"</script>");
fs.writeFileSync(output, html);
