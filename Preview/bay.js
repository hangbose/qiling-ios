"use strict";
const byId = (id) => document.getElementById(id);
const locations = Array.from(document.querySelectorAll(".route li"));
const lamps = Array.from(document.querySelectorAll(".lamp"));
const frame = byId("frame"),
  world = byId("world");
const reduce = matchMedia("(prefers-reduced-motion: reduce)");
const symbols = {
  shell: [
    "...aaa...",
    "..abbba..",
    ".abbcbba.",
    "abcbcbcba",
    "abcbcbcca",
    ".abcbcba.",
    "..abbba..",
    "...aaa...",
  ],
  book: ["aaaa.aaaa", "abbbaabba", "abbbaabba", "abbbabbba", "abbbabbba", "abbbabbba", "aaaa.aaaa"],
  foot: [
    ".....aa..",
    "....abba.",
    "....abba.",
    ".....aa..",
    ".aaa.....",
    "abbba....",
    "abbba....",
    ".aaa.....",
  ],
  moon: [
    "....aaa..",
    "..abba...",
    ".abba....",
    ".abba....",
    ".abbaa...",
    "..abbbaaa",
    "...aabbba",
    ".....aaa.",
  ],
  card: ["aaaaaaaaa", "abbbbbbba", "abaabbaba", "abbaaabba", "abbbbabba", "abbbbbbba", "aaaaaaaaa"],
};
function drawIcon(canvas, symbol, primary) {
  const rows = symbols[symbol];
  canvas.width = 10;
  canvas.height = 10;
  const ctx = canvas.getContext("2d");
  const colors = primary
    ? { a: "#fff4df", b: "#e1ac81", c: "#d99876" }
    : { a: "#694b3d", b: "#edbf94", c: "#ad7961" };
  rows.forEach((row, y) =>
    [...row].forEach((c, x) => {
      if (colors[c]) {
        ctx.fillStyle = colors[c];
        ctx.fillRect(x, y + 1, 1, 1);
      }
    }),
  );
}
document.querySelectorAll("[data-icon]").forEach((el) => drawIcon(el, el.dataset.icon, false));
// Use map coordinates for both the moving view and the finished postcard.
const lampCenters = lamps.map((lamp) => ({
  x: parseFloat(lamp.style.left),
  y: parseFloat(lamp.style.top),
}));
function addLightPool(group, center, rx, ry, gradient) {
  const ellipse = document.createElementNS("http://www.w3.org/2000/svg", "ellipse");
  ellipse.setAttribute("cx", center.x);
  ellipse.setAttribute("cy", center.y + 5.5);
  ellipse.setAttribute("rx", rx);
  ellipse.setAttribute("ry", ry);
  ellipse.setAttribute("fill", "url(#" + gradient + ")");
  ellipse.classList.add("light-pool");
  group.append(ellipse);
  return ellipse;
}
const litAreas = lampCenters.map((center) => [
  addLightPool(byId("clearings"), center, 30, 40, "clearPool"),
  addLightPool(byId("pools"), center, 15, 15, "warmPool"),
]);
const tide = byId("tide");
for (let i = 0; i < 13; i++) {
  const fleck = document.createElement("i");
  fleck.className = "glint";
  fleck.style.left = 9 + ((i * 29) % 83) + "%";
  fleck.style.top = 48 + ((i * 7) % 10) + "%";
  fleck.style.animationDelay = -i * 0.73 + "s";
  tide.append(fleck);
}
for (let i = 0; i < 3; i++) {
  const gull = document.createElement("i");
  gull.className = "gull";
  gull.style.left = 34 + i * 2.5 + "%";
  gull.style.top = 26 + (i % 2) * 1.6 + "%";
  gull.style.animationDelay = -i * 0.6 + "s";
  tide.append(gull);
}
const backgrounds = [byId("plate").src, ...[1, 2, 3, 4].map((i) => byId("bg" + i).src)];
const baseImage = new Image();
baseImage.src = backgrounds[0];
const art = (i) => (i === 0 ? baseImage : byId("bg" + i));
let visit = null,
  focusX = null,
  editing = null,
  notice = "",
  shown = -1;
const region = () => visit ?? route().current;
const petImg = (id, grown) => byId(id + (grown ? "1" : "0"));
const imageIfChanged = (el, src) => {
  if (el.getAttribute("src") !== src) el.src = src;
};
function point(i, ticks) {
  const x = 0.105 + (0.755 * ticks) / districts[i].length;
  return { x, y: ground(i, x) };
}
function placeImage(el, x, y, size) {
  el.style.left = x * 100 + "%";
  el.style.top = y * 100 + "%";
  el.style.width = size * 100 + "%";
}
function camera() {
  const i = region(),
    p = point(i, route().at(i)),
    w = frame.clientWidth,
    h = frame.clientHeight;
  const width = Math.max(w * (w > 580 ? 1.48 : 1.65), (h * 4) / 3),
    height = width * 0.75;
  world.style.width = width + "px";
  world.style.height = height + "px";
  const left = Math.max(0, Math.min(width - w, (focusX ?? p.x) * width - w * 0.47));
  byId("follow").hidden = focusX === null;
  byId("follow").style.top = h - 56 + "px";
  const top = Math.max(0, Math.min(height - h, p.y * height - h * 0.78));
  world.style.transform = "translate(" + -left + "px," + -top + "px)";
}
function render() {
  const r = route();
  if (visit !== null && !r.available(visit)) visit = null;
  const i = region(),
    d = districts[i],
    ticks = r.at(i),
    lit = Math.floor((3 * ticks) / d.length),
    p = point(i, ticks);
  if (i !== shown) {
    byId("plate").src = backgrounds[i];
    shown = i;
  }
  byId("districtName").textContent = d.name;
  byId("chapter").textContent = "深圳路线图 ↗ · 第" + r.lap + "圈";
  byId("tide").hidden = i !== 0 && i !== 4;
  byId("face").src = petImg(book.pet, personalDays() >= 5).src;
  imageIfChanged(byId("me"), byId("face").src);
  placeImage(byId("me"), p.x, p.y, personalDays() >= 5 ? 0.105 : 0.083);
  const guest = book.team && book.teamSteps.some((k) => k.startsWith("friend|"));
  byId("pal").hidden = !guest;
  if (guest) {
    imageIfChanged(byId("pal"), petImg(book.pet === "xiaoying" ? "yaya" : "xiaoying", false).src);
    placeImage(byId("pal"), Math.max(0.058, p.x - 0.075), p.y + 0.014, 0.075);
  }
  lamps.forEach((el, n) => {
    const cx = i === 0 ? lampCenters[n].x : [27, 52, 82][n],
      cy = i === 0 ? lampCenters[n].y : 100 * ground(i, cx / 100) - 6;
    el.style.left = cx + "%";
    el.style.top = cy + "%";
    el.classList.toggle("on", n < lit);
    el.hidden = i !== 0 && n >= lit;
    litAreas[n].forEach((area) => {
      area.setAttribute("cx", cx);
      area.setAttribute("cy", cy + 5);
      area.classList.toggle("on", n < lit);
    });
    locations[n].textContent = d.stops[n];
    locations[n].classList.toggle("on", n < lit);
    locations[n].setAttribute("aria-label", d.stops[n] + (n < lit ? "，已点亮" : "，未点亮"));
  });
  byId("shade").classList.toggle("complete", lit === 3);
  for (const item of goods) {
    const spot = book.placements[item.id],
      el = byId(item.id);
    el.hidden = !spot || spot.region !== i;
    if (!el.hidden) placeImage(el, spot.x, ground(i, spot.x), item.size);
  }
  const between = ticks > 0 && (ticks * 3) % d.length !== 0,
    name = pets[book.pet][0];
  byId("speaker").textContent =
    visit !== null
      ? "重游" + d.name
      : !ticks
        ? name + "在海边等你"
        : between
          ? name + "正走向" + d.stops[lit]
          : name + "抵达" + d.stops[lit - 1];
  const next = d.stops[Math.min(lit, 2)];
  byId("voice").textContent =
    notice ||
    (ticks === 0
      ? "试一次手表同步，或记下今天的阅读，让第一盏灯亮起来。"
      : between
        ? "再走一程，就到" + next + "了。"
        : d.notes[Math.max(0, lit - 1)]);
  byId("earning").hidden = false;
  byId("earning").textContent = (book.team ? "小队" : "独行") + " · 第 " + book.day + " 天 ›";
  byId("balance").textContent = walletBalance();
  byId("wallet").setAttribute("aria-label", "小铺，余额 " + walletBalance() + " 贝壳");
  byId("action").textContent = book.watch && !book.days[book.day] ? "试同步手表" : "试玩下一天";
  byId("mark").textContent = book.days[book.day] ? "今日已走" : "记" + book.habit;
  byId("mark").disabled = !!book.days[book.day];
  frame.setAttribute("aria-label", d.name + "，已点亮 " + lit + " 处，" + name + "在小径上。");
  drawIcon(byId("actionIcon"), "foot", true);
  camera();
}
function commit(message = "") {
  notice = message;
  persist();
  render();
}
function walk(action) {
  visit = null;
  focusX = null;
  if (action === "manual") record(book.habit);
  else {
    if (book.days[book.day] || !book.watch) book.day++;
    if (book.watch) record(watchSamples[(book.day - 1) % watchSamples.length]);
  }
  const latest = ledger().at(-1),
    message =
      latest?.day === book.day
        ? latest.reason + " · " + latest.amount + " 枚贝壳已放进背包。"
        : "新的一天，可以点一下记" + book.habit + "。";
  commit(
    personalDays() === 5 && latest?.day === book.day
      ? "第五个习惯日，" + pets[book.pet][0] + "长大了一点！"
      : message,
  );
}
function button(text, fn, opts = {}) {
  const b = document.createElement("button");
  b.className = opts.className || "key";
  b.type = "button";
  b.textContent = text;
  if (opts.id) b.id = opts.id;
  if (opts.disabled) b.disabled = true;
  b.onclick = fn;
  return b;
}
const choices = byId("choices");
function sheet(title, note, card = false) {
  byId("sheetTitle").textContent = title;
  byId("sheetNote").textContent = note;
  choices.replaceChildren();
  byId("entries").replaceChildren();
  byId("postcard").hidden = !card;
  byId("close").textContent = card ? "收好明信片" : "回到地图";
  if (!byId("sheet").open) byId("sheet").showModal();
}
function ledgerRow(left, right) {
  const row = document.createElement("li"),
    b = document.createElement("b");
  row.append(left);
  b.textContent = right;
  row.append(b);
  byId("entries").append(row);
}
function section(title) {
  const h = document.createElement("h3");
  h.textContent = title;
  choices.append(h);
}
function atlas() {
  const r = route();
  sheet(
    "深圳旅行图册",
    "第 " + r.lap + " 圈 · 累计 " + r.total + " 程。点已到访的区域，可以回去散步、摆花或看明信片。",
  );
  districts.forEach((d, i) => {
    const available = r.available(i),
      b = button(
        "",
        () => {
          visit = i === r.current ? null : i;
          focusX = null;
          notice = "";
          byId("sheet").close();
          render();
        },
        { className: "atlas-row", id: "visit-" + i, disabled: !available },
      );
    const thumb = document.createElement("img");
    thumb.src = backgrounds[i];
    thumb.alt = "";
    const text = document.createElement("span"),
      title = document.createElement("strong"),
      note = document.createElement("small");
    title.textContent =
      d.name + "  " + (i === r.current ? "• 在途中" : !available ? "· 待探索" : "");
    note.textContent = d.stops.join(" / ");
    text.append(title, note);
    b.append(thumb, text);
    choices.append(b);
    if (available && (r.lap > 1 || r.at(i) === d.length))
      choices.append(
        button("看" + d.name + "明信片", () => postcard(i), {
          className: "paper-link",
          id: "post-" + i,
        }),
      );
  });
  if (visit !== null)
    choices.append(
      button(
        "回到当前路段",
        () => {
          visit = null;
          focusX = null;
          byId("sheet").close();
          commit();
        },
        { className: "key primary" },
      ),
    );
}
function relayChoices(refresh) {
  choices.append(
    button(
      book.team ? "小队接力中 · 切回独行" : "我想试试小队接力",
      () => {
        book.team = !book.team;
        if (book.team && book.days[book.day]) relay("me");
        visit = null;
        focusX = null;
        commit();
        refresh();
      },
      { id: "team-mode" },
    ),
  );
  if (book.team) {
    const sent = book.teamSteps.includes("friend|" + book.day);
    choices.append(
      button(
        sent ? "小雨今天已接力" : "模拟队友小雨接力",
        () => {
          relay("friend");
          visit = null;
          focusX = null;
          commit("小雨也完成了今天的好习惯，一起前进一程。");
          refresh();
        },
        { id: "friend-step", disabled: sent },
      ),
    );
  }
}
function teamSheet() {
  sheet(
    "结伴同行",
    "独行时按自己的节奏走。开启接力会带上今天的一程；队友也能各走一程，大家分别攒贝壳。",
  );
  relayChoices(teamSheet);
  ledgerRow("我独自走过", personalDays() + " 程");
  ledgerRow("小队共同走过", book.teamSteps.length + " 程");
  ledgerRow("其中小雨走过", book.teamSteps.filter((k) => k.startsWith("friend|")).length + " 程");
}
function journal() {
  sheet(
    "旅行手记",
    "第 " +
      book.day +
      " 天 · 我的习惯日 " +
      personalDays() +
      " 天 · 累计贝壳收入 " +
      ledger().reduce((s, p) => s + p.amount, 0) +
      " 枚",
  );
  section("旅行伙伴");
  const cards = document.createElement("div");
  cards.className = "pet-cards";
  for (const [id, [name, kind]] of Object.entries(pets)) {
    const b = button(
      "",
      () => {
        book.pet = id;
        commit();
        journal();
      },
      { className: "pet-card", id: "pet-" + id },
    );
    b.setAttribute("aria-pressed", String(book.pet === id));
    const face = document.createElement("img");
    face.src = petImg(id, personalDays() >= 5).src;
    face.alt = kind;
    b.append(face, name);
    cards.append(b);
  }
  choices.append(cards);
  const hint = document.createElement("small");
  hint.textContent =
    personalDays() >= 5
      ? "第五个习惯日留下了成长的模样。"
      : "再过 " + (5 - personalDays()) + " 个习惯日，伙伴就会长大一点。";
  choices.append(hint);
  section("同行方式");
  relayChoices(journal);
  section("我的快捷打卡");
  for (const text of habits) {
    const b = button(
      text,
      () => {
        book.habit = text;
        commit();
        journal();
      },
      { id: "habit-" + text },
    );
    b.setAttribute("aria-pressed", String(book.habit === text));
    choices.append(b);
  }
  choices.append(
    button(
      "手表示例同步 · " + (book.watch ? "开" : "关"),
      () => {
        book.watch = !book.watch;
        commit();
        journal();
      },
      { id: "watch-mode" },
    ),
  );
  if (personalDays()) {
    section("最近入账");
    for (const p of ledger().slice(-5).reverse())
      ledgerRow("第 " + p.day + " 天 · " + p.reason, "+" + p.amount + " 枚");
  }
}
function paintSouvenirs(ctx, w, h, i, overrides = {}) {
  for (const item of goods) {
    const spot = overrides[item.id] || book.placements[item.id],
      im = byId(item.id);
    if (spot?.region !== i || !im.naturalWidth) continue;
    const size = item.size * w;
    ctx.drawImage(im, w * spot.x - size / 2, h * ground(i, spot.x) - size, size, size);
  }
}
function postcard(i) {
  sheet(
    districts[i].name + "的明信片",
    pets[book.pet][0] + " · " + districts[i].stops.join(" / "),
    true,
  );
  const canvas = byId("postArt"),
    c = canvas.getContext("2d"),
    w = canvas.width,
    h = canvas.height;
  const paint = () => {
    c.clearRect(0, 0, w, h);
    c.imageSmoothingEnabled = false;
    if (art(i).naturalWidth) c.drawImage(art(i), 0, 0, w, h);
    paintSouvenirs(c, w, h, i);
    const im = petImg(book.pet, personalDays() >= 5);
    if (im.naturalWidth)
      c.drawImage(im, w * 0.56, h * ground(i, 0.62) - w * 0.13, w * 0.13, w * 0.13);
    if (book.team && book.teamSteps.some((k) => k.startsWith("friend|"))) {
      const pal = byId("pal");
      if (pal.naturalWidth)
        c.drawImage(pal, w * 0.46, h * ground(i, 0.5) - w * 0.105, w * 0.105, w * 0.105);
    }
  };
  paint();
  if (!art(i).naturalWidth) art(i).addEventListener("load", paint, { once: true });
  choices.append(button("翻回路线图", atlas, { className: "paper-link" }));
}

function shopArt() {
  const canvas = byId("shopArt"),
    c = canvas.getContext("2d"),
    w = canvas.width,
    h = w * 0.75,
    i = editing?.region ?? region();
  c.clearRect(0, 0, w, canvas.height);
  c.save();
  c.imageSmoothingEnabled = false;
  c.translate(0, -h * 0.39);
  if (art(i).naturalWidth) c.drawImage(art(i), 0, 0, w, h);
  paintSouvenirs(c, w, h, i, editing ? { [editing.item.id]: editing } : {});
  if (editing) {
    const x = w * editing.x,
      y = h * ground(i, editing.x) + 4;
    c.fillStyle = "#ffeaac";
    c.fillRect(x - 13, y, 26, 3);
    c.fillRect(x - 2, y + 3, 4, 4);
  }
  c.restore();
}
function editPlace(item) {
  const old = book.placements[item.id],
    r = route();
  editing = {
    item,
    region: r.available(old?.region ?? 0) ? (old?.region ?? region()) : region(),
    x: old?.x ?? item.x,
  };
  byId("goods").hidden = true;
  byId("placement").hidden = false;
  byId("placing").textContent = "摆放" + item.name;
  byId("backToBay").hidden = true;
  const sel = byId("placeArea");
  sel.replaceChildren();
  districts.forEach((d, i) => {
    if (r.available(i)) sel.add(new Option(d.name, String(i)));
  });
  sel.value = String(editing.region);
  byId("placeX").value = Math.round(editing.x * 100);
  byId("saleNote").textContent = "点上方画面，或拖动滑杆选位置。";
  shopArt();
}
function renderShop() {
  editing = null;
  byId("placement").hidden = true;
  byId("goods").hidden = false;
  byId("backToBay").hidden = false;
  byId("shopBalance").textContent = walletBalance() + " 枚";
  byId("income").textContent = "连续习惯日每天多得 10 枚，最高 80 枚。摆件可以免费搬家。";
  const list = byId("goods");
  list.replaceChildren();
  for (const item of goods) {
    const row = document.createElement("li"),
      img = document.createElement("img"),
      details = document.createElement("div"),
      name = document.createElement("span"),
      caption = document.createElement("small"),
      price = document.createElement("div");
    const owned = Object.hasOwn(book.buys, item.id);
    img.src = byId(item.id).src;
    img.alt = "";
    name.className = "item-name";
    name.textContent = item.name;
    caption.className = "item-place";
    caption.textContent = owned
      ? "已摆在" + districts[book.placements[item.id].region].name
      : item.detail;
    details.append(name, caption);
    if (!owned && item.id === "cottage") {
      const meter = document.createElement("progress");
      meter.className = "saving";
      meter.max = item.price;
      meter.value = Math.min(walletBalance(), item.price);
      meter.setAttribute("aria-label", "小屋储蓄");
      details.append(meter);
    }
    price.className = "price";
    price.append(
      button(
        owned ? "移个位置" : item.price + " 枚",
        () => {
          if (!Object.hasOwn(book.buys, item.id)) {
            if (walletBalance() < item.price) return;
            book.buys[item.id] = item.price;
            book.placements[item.id] = { region: region(), x: item.x };
            commit();
            byId("shopBalance").textContent = walletBalance() + " 枚";
          }
          editPlace(item);
        },
        {
          id: (owned ? "move-" : "buy-") + item.id,
          className: owned ? "key" : "key primary",
          disabled: !owned && walletBalance() < item.price,
        },
      ),
    );
    if (!owned && walletBalance() < item.price) {
      const gap = document.createElement("small");
      gap.textContent = "差 " + (item.price - walletBalance()) + " 枚";
      price.append(gap);
    }
    row.append(img, details, price);
    list.append(row);
  }
  shopArt();
}
byId("placeX").oninput = (e) => {
  if (editing) {
    editing.x = Number(e.target.value) / 100;
    shopArt();
  }
};
byId("placeArea").onchange = (e) => {
  if (editing) {
    editing.region = Number(e.target.value);
    shopArt();
  }
};
byId("shopArt").onclick = (e) => {
  if (!editing) return;
  const box = e.currentTarget.getBoundingClientRect();
  editing.x = Math.min(0.94, Math.max(0.06, (e.clientX - box.left) / box.width));
  byId("placeX").value = Math.round(editing.x * 100);
  shopArt();
};
byId("keepPlace").onclick = () => {
  if (!editing) return;
  const { item, region: i, x } = editing;
  book.placements[item.id] = { region: i, x };
  visit = i === route().current ? null : i;
  focusX = x;
  editing = null;
  byId("shop").close();
  commit(item.name + "摆好了，在" + districts[i].name + "的小路旁。");
};
byId("cancelPlace").onclick = () => {
  byId("saleNote").textContent = "";
  renderShop();
};
byId("wallet").onclick = () => {
  byId("saleNote").textContent = "";
  renderShop();
  byId("shop").showModal();
};
byId("advance").onclick = () => walk("watch");
byId("mark").onclick = () => walk("manual");
byId("earning").onclick = teamSheet;
byId("companion").onclick = journal;
byId("atlas").onclick = atlas;
byId("journal").onclick = journal;
byId("restart").onclick = () => {
  sheet("重新出发？", "会清空这个浏览器里的试玩进度、贝壳和摆件。");
  choices.append(
    button(
      "清空试玩并出发",
      () => {
        book = freshBook();
        focusX = null;
        visit = null;
        byId("sheet").close();
        commit();
      },
      { id: "confirm-reset" },
    ),
  );
};
for (const im of [baseImage, ...[1, 2, 3, 4].map(art), ...goods.map((item) => byId(item.id))])
  im.addEventListener("load", () => {
    if (byId("shop").open) shopArt();
  });
new ResizeObserver(camera).observe(frame);
render();
persist();

let dragging = null;
function panFrom(left, delta) {
  const width = world.offsetWidth,
    screen = frame.clientWidth;
  const next = Math.max(0, Math.min(width - screen, left - delta));
  focusX = (next + screen * 0.47) / width;
  camera();
}
frame.onpointerdown = (e) => {
  if (!e.isPrimary || e.button !== 0) return;
  dragging = {
    start: e.clientX,
    y: e.clientY,
    left: frame.getBoundingClientRect().left - world.getBoundingClientRect().left,
    active: false,
  };
};
frame.onpointermove = (e) => {
  if (!dragging || !e.isPrimary) return;
  const dx = e.clientX - dragging.start;
  if (!dragging.active) {
    if (Math.abs(dx) < 8 || Math.abs(dx) < Math.abs(e.clientY - dragging.y)) return;
    dragging.active = true;
    frame.setPointerCapture(e.pointerId);
    world.classList.add("panning");
  }
  panFrom(dragging.left, dx);
};
function endDrag() {
  dragging = null;
  world.classList.remove("panning");
}
frame.onpointerup = endDrag;
frame.onpointercancel = endDrag;
frame.onpointerleave = () => {
  if (!dragging?.active) endDrag();
};
frame.onkeydown = (e) => {
  if (!["ArrowLeft", "ArrowRight"].includes(e.key)) return;
  e.preventDefault();
  panFrom(
    frame.getBoundingClientRect().left - world.getBoundingClientRect().left,
    e.key === "ArrowLeft" ? 80 : -80,
  );
};
byId("follow").onclick = () => {
  focusX = null;
  camera();
  frame.focus({ preventScroll: true });
};
