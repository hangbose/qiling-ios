// The reading view and the physical case share one image in the Street GLB.
// Horizontal coordinates below follow the three original prints in zhili_street_lobby.py.
const prints = [
  {name:"建筑手记", start:0, end:612, alt:"致理楼的线描，从上方的窗带画到柱廊和庭院台阶。",
    detail:"从台阶往上看，能找到线稿里的白色长檐。再数数檐下的柱子，和画里的节奏对得上吗？"},
  {name:"荔园草木", start:612, end:1032, alt:"一片复叶的线描，小叶沿叶轴分生，每片小叶都画出了侧脉。",
    detail:"先找一条长长的叶轴，再沿着它看两侧的小叶。把一片小叶放大，还能看到向两边伸开的侧脉。"},
  {name:"校园服务", start:1032, end:1536, alt:"致理楼 C 座一楼信息服务大厅的导览图版。",
    detail:"信息中心服务大厅在粤海校区致理楼 C 座一楼。"},
];

const style = `
.exhibit-open{position:absolute;z-index:3;left:50%;bottom:18px;transform:translateX(-50%);min-height:44px;padding:8px 17px;color:#263c36;background:#fbf6e8;border:1px solid #c9c4b4;border-radius:7px;font-weight:650;white-space:nowrap}
.exhibit-reader{position:fixed;inset:0;margin:auto;width:min(94vw,480px);max-height:89svh;overflow:auto;padding:17px;border:1px solid #b4b8a8;border-radius:10px;background:#f8f5eb;color:#263c36;overscroll-behavior:contain}
.exhibit-reader::backdrop{background:rgba(13,23,22,.72)}
.exhibit-reader .exhibit-head,.exhibit-reader .exhibit-actions{display:flex;align-items:center;gap:8px}
.exhibit-head{justify-content:space-between}.exhibit-head h2{font:650 1.22rem/1.3 system-ui,sans-serif;margin:0}
.exhibit-reader button{min-height:44px;background:transparent;color:#364a40;border:1px solid #c3c8b9;border-radius:5px;padding:6px 10px;font-size:.86rem}
.exhibit-reader button:focus-visible,.exhibit-paper:focus-visible{outline:3px solid #ac6236;outline-offset:2px}
.exhibit-actions{margin:12px 0;flex-wrap:wrap}.exhibit-actions button[aria-pressed=true]{background:#314b45;border-color:#314b45;color:#fffbed}
.exhibit-reader .exhibit-zoom{margin-left:auto;border-color:transparent}
.exhibit-paper{max-height:55svh;overflow:auto;overscroll-behavior:contain;background:#e3ddce;border:1px solid #c6c3ae}
.exhibit-paper canvas{display:block;position:static;inset:auto;width:100%;height:auto;max-width:none;touch-action:auto}
.exhibit-paper.is-large canvas{width:170%}.exhibit-reader .exhibit-caption{font-size:.94rem;line-height:1.6;margin:10px 0 0}
@media(max-width:355px){.exhibit-reader{padding:12px}.exhibit-reader .exhibit-actions{gap:3px}.exhibit-actions button{padding-inline:6px}}
`;

export function streetExhibit(host, canvas) {
  const css = document.createElement("style");
  css.textContent = style;
  document.head.append(css);
  const launch = document.createElement("button");
  launch.type = "button";
  launch.className = "exhibit-open";
  launch.textContent = "看展板";
  launch.setAttribute("aria-haspopup", "dialog");
  launch.hidden = true;
  host.append(launch);

  const dialog = document.createElement("dialog");
  dialog.className = "exhibit-reader";
  dialog.setAttribute("aria-labelledby", "exhibit-title");
  dialog.innerHTML = `
    <div class="exhibit-head"><h2 id="exhibit-title">致理楼 · 廊下展板</h2><button class="exhibit-close" type="button" autofocus>关闭</button></div>
    <div class="exhibit-actions" role="group" aria-label="选择图版"><button class="exhibit-zoom" type="button" aria-pressed="false">放大</button></div>
    <div class="exhibit-paper" tabindex="0" role="region" aria-label="图版"><canvas role="img"></canvas></div>
    <p class="exhibit-caption" aria-live="polite"></p>`;
  document.body.append(dialog);
  const viewport = dialog.querySelector(".exhibit-paper");
  const page = viewport.querySelector("canvas");
  const caption = dialog.querySelector(".exhibit-caption");
  const zoom = dialog.querySelector(".exhibit-zoom");
  const close = dialog.querySelector(".exhibit-close");
  let sourceModel, image, returnFocus, activePrint = 0;

  const tabs = prints.map((print, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = print.name;
    button.addEventListener("click", () => showPrint(index));
    zoom.before(button);
    return button;
  });
  function setZoom(enlarged) {
    viewport.classList.toggle("is-large", enlarged);
    viewport.scrollTop = viewport.scrollLeft = 0;
    zoom.setAttribute("aria-pressed", String(enlarged));
    zoom.textContent = enlarged ? "还原" : "放大";
  }
  function showPrint(index) {
    activePrint = index;
    const print = prints[index];
    const left = Math.round(image.width * print.start / 1536);
    const right = Math.round(image.width * print.end / 1536);
    page.width = right-left;
    page.height = image.height;
    page.getContext("2d").drawImage(image, left, 0, page.width, page.height, 0, 0, page.width, page.height);
    page.setAttribute("aria-label", print.alt);
    caption.textContent = print.detail;
    tabs.forEach((button, i) => button.setAttribute("aria-pressed", String(i === index)));
    setZoom(false);
  }
  function open(from) {
    if (!image || launch.hidden || dialog.open) return;
    host.dispatchEvent(new Event("exhibitopen"));
    returnFocus = from;
    showPrint(activePrint);
    dialog.showModal();
  }
  launch.addEventListener("click", () => open(launch));
  close.addEventListener("click", () => dialog.close());
  zoom.addEventListener("click", () => setZoom(!viewport.classList.contains("is-large")));
  dialog.addEventListener("close", () => {
    if (returnFocus && !launch.hidden) returnFocus.focus({preventScroll:true});
    returnFocus = null;
  });
  dialog.addEventListener("keydown", event => {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      dialog.close();
    }
  });
  host.addEventListener("keydown", event => {
    if (event.key.toLowerCase() !== "e" || event.repeat || event.ctrlKey || event.altKey ||
        event.metaKey || launch.hidden || dialog.open || event.target !== canvas) return;
    event.preventDefault();
    open(canvas);
  });
  function setModel(model) {
    if (sourceModel === model) return;
    sourceModel = model;
    image = null;
    model?.traverse(object => {
      if (image || !object.isMesh) return;
      const materials = Array.isArray(object.material) ? object.material : [object.material];
      for (const material of materials) {
        if (material?.name !== "Zhili exhibit / archival print") continue;
        image = material.map?.image || material.emissiveMap?.image;
        if (image) break;
      }
    });
  }
  function near(x, z, height) {
    // Player faces the south side of a 3.37m wide wall case. Measure to the
    // display face, so a reader beside one end can still examine the print.
    const depth = z + 6.66;
    const beyondEnd = Math.max(0, Math.abs(x + 7.1) - 1.55);
    launch.hidden = !(image && height < .68 && depth > .12 && Math.hypot(beyondEnd, depth) < 3.4);
  }
  function leave() {
    launch.hidden = true;
    returnFocus = null;
    if (dialog.open) dialog.close();
  }
  return {setModel, near, leave, reading:() => dialog.open};
}
