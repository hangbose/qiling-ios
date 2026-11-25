// node web-site.cjs <built.html> <out-directory> <node_modules with three and esbuild>
const fs = require("node:fs");
const path = require("node:path");
const {createHash} = require("node:crypto");

if (process.argv.length !== 5) {
  console.error("Usage: node web-site.cjs <built.html> <out-directory> <node_modules>");
  process.exit(1);
}
const [input, output, modules] = process.argv.slice(2).map(file => path.resolve(file));
const directory = path.join(output, "assets");
const files = new Map();
const offline = fs.readFileSync(input, "utf8");
const {buildSync} = require(path.join(modules, "esbuild"));
const bundle = buildSync({
  entryPoints: [path.join(__dirname, "garden.js")],
  bundle: true, splitting: true, format: "esm", minify: true,
  target: ["safari17", "chrome110"], legalComments: "inline",
  nodePaths: [modules], outdir: directory, entryNames: "campus-[hash]",
  chunkNames: "[name]-[hash]", write: false,
});
let entry;
for (const file of bundle.outputFiles) {
  const name = path.basename(file.path);
  files.set(name, file.contents);
  if (/^campus-[A-Z0-9]+\.js$/.test(name)) entry = "./assets/" + name;
}
if (!entry) throw new Error("The garden.js entry was not generated");

function storeAsset(label, encoded, image = false) {
  const base64 = encoded.replace(/\s/g, "");
  const bytes = Buffer.from(base64, "base64");
  if (!bytes.length || bytes.toString("base64") !== base64) {
    throw new Error("Invalid base64 in " + label);
  }
  const header = bytes.toString("latin1", 0, 12);
  let extension = "bin";
  if (header.startsWith("RIFF") && header.endsWith("WEBP")) extension = "webp";
  else if (header.startsWith("glTF")) extension = "glb";
  else if (header.startsWith("#?RADIANCE") || header.startsWith("#?RGBE")) extension = "hdr";
  else if (header.startsWith("\x89PNG\r\n\x1a\n")) extension = "png";
  if (image && extension !== "webp") throw new Error("Expected a WebP in " + label);
  const hash = createHash("sha256").update(bytes).digest("hex").slice(0, 16);
  const name = label.replace(/[^a-z\d_-]+/gi, "-") + "-" + hash + "." + extension;
  files.set(name, bytes);
  return {url: "./assets/" + name, size: bytes.length};
}

// Consume comments and whole script/style elements before visiting image markup.
// This keeps the original bundle and the binary script contents out of attribute rewrites.
const elements = /<!--[\s\S]*?-->|<(script|style)\b([^>]*)>([\s\S]*?)<\/\1\s*>|<img\b((?:"[^"]*"|'[^']*'|[^>"']+)*)>/gi;
const parts = [...offline.matchAll(elements)];
const lastScript = parts.findLast(part => part[1]?.toLowerCase() === "script");
if (!lastScript || lastScript[2].trim()) throw new Error("Expected the final inline script from export.cjs");
const getId = attributes => /\sid\s*=\s*(["'])([^"']+)\1/i.exec(attributes)?.[2];
const webpSource = /\ssrc\s*=\s*(["'])data:image\/webp;base64,([^"']+)\1/i;
const webpUrl = /url\(\s*(["']?)data:image\/webp;base64,([a-z\d+/=\s]+)\1\s*\)/gi;
let position = 0;
const result = [];
for (const part of parts) {
  result.push(offline.slice(position, part.index));
  position = part.index + part[0].length;
  let markup = part[0];
  if (part === lastScript) {
    markup = `<script type="module" src="${entry}"></script>`;
  } else if (part[1]?.toLowerCase() === "script" && /\stype\s*=\s*(["'])application\/octet-stream\1/i.test(part[2])) {
    const id = getId(part[2]);
    if (!id) throw new Error("Binary script is missing its id");
    const asset = storeAsset(id, part[3]);
    markup = `<script${part[2]} data-src="${asset.url}" data-bytes="${asset.size}"></script>`;
  } else if (part[1]?.toLowerCase() === "style") {
    markup = markup.replace(webpUrl, (_, quote, data) =>
      `url("${storeAsset("corridor-front", data, true).url}")`);
  } else if (part[4] !== undefined) {
    const id = getId(part[4]);
    markup = markup.replace(webpSource, (_, quote, data) => {
      const asset = storeAsset(id || "study-evening", data, true);
      return id === "shot-street" ? ` src="${asset.url}" fetchpriority="high"` : ` data-src="${asset.url}"`;
    });
  }
  result.push(markup);
}
result.push(offline.slice(position));
const html = result.join("");

// Publish the entry after every referenced file exists. Old content hashes may
// still be in use by a page opened before this build.
fs.mkdirSync(directory, {recursive: true});
for (const [name, contents] of files) {
  fs.writeFileSync(path.join(directory, name), contents);
  console.log(`${contents.length.toLocaleString("en-US").padStart(12)} B  assets/${name}`);
}
fs.writeFileSync(path.join(output, "index.html"), html);
console.log(`${Buffer.byteLength(html).toLocaleString("en-US").padStart(12)} B  index.html`);
