// Blender: run model.py with the output directory after --.
// node export.cjs <glb directory> <node_modules with three@0.180.0 and esbuild@0.25.12> <output.html>
const fs = require("node:fs");
const path = require("node:path");
const [models, modules, output] = process.argv.slice(2).map(p => path.resolve(p));
const {buildSync} = require(path.join(modules, "esbuild"));
const js = buildSync({ entryPoints:[path.join(__dirname,"garden.js")], bundle:true, minify:true,
  format:"iife", target:["safari17","chrome110"], write:false, legalComments:"inline", nodePaths:[modules] }).outputFiles[0].text;
let html = fs.readFileSync(path.join(__dirname,"page.html"),"utf8");
for (const name of ["Zhili","Yuehai"]) {
  html = html.replace("@@"+name+"@@", () => fs.readFileSync(path.join(models,name+".glb")).toString("base64"));
}
const license = fs.readFileSync(path.join(modules,"three/LICENSE"),"utf8");
html = html.replace("<!--SCRIPT-->", () => "<!--\n"+license+"\n-->\n<script>"+js.replace(/<\/script/gi,"<\\/script")+"</script>");
fs.writeFileSync(output, html);
