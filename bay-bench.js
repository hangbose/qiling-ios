"use strict";

function drawFind(ctx, tile, x, y, size) {
  const atlas = byId("findAtlas");
  if (tile && atlas.naturalWidth) {
    ctx.drawImage(atlas, tile[0] * 64, tile[1] * 64, 64, 64, x - size/2, y - size, size, size);
  }
}

function renderBenchEntry(district) {
  const entry = byId("benchEntry");
  const corner = book.bench;
  if (!corner.shell) entry.textContent = "拾起长椅边的白贝";
  else if (returnDay()) entry.textContent = "打开寻宝行囊";
  else if (!corner.glass && personalDays()) entry.textContent = "去潮边捡海玻璃";
  else if (corner.glass === "pocket") entry.textContent = "安放海玻璃";
  else if (corner.errand) entry.textContent = "看看行囊";
  else entry.textContent = outings.every(r => findLevel(r) === r.finds.length) ? "回长椅坐坐" : "去长椅寻宝";
  const props = byId("benchProps");
  props.replaceChildren();
  if (!corner.shell || district !== 0) return;
  for (const [row] of outings.entries()) {
    const tile = benchTile(row);
    if (!tile) continue;
    const x = .037 + row * .003;
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = 64;
    canvas.style.left = x * 100 + "%";
    canvas.style.top = promenadeY(0,x) * 100 + "%";
    const paint = () => drawFind(canvas.getContext("2d"),tile,32,64,64);
    paint();
    if (!byId("findAtlas").complete) byId("findAtlas").addEventListener("load",paint,{once:true});
    props.append(canvas);
  }
}

function paintBench(canvas, swing = 0, withCaption = false, visitor = null, ripple = 0) {
  const ctx = canvas.getContext("2d"), w = canvas.width, h = w * .75;
  ctx.clearRect(0, 0, w, canvas.height);
  ctx.imageSmoothingEnabled = false;
  if (art(0).naturalWidth) ctx.drawImage(art(0),0,0,w,h);
  const corner = visitor?.corner ?? book.bench;
  const settled = !visitor && book.day > corner.glassDay;
  const positions = [[.21,.763,.17],[.065,.795,.115],[.71,.706,.16]];
  positions.forEach(([x,y,size],row) => {
    ctx.save();
    ctx.translate(x*w,y*h);
    if (row === 0) ctx.rotate(swing);
    drawFind(ctx,keepsakeTile(corner,row),0,0,size*w);
    ctx.restore();
  });
  if (!visitor && !withCaption && corner.shell && !corner.glass && personalDays()) {
    ctx.save();ctx.translate(w*.54,h*.75);ctx.rotate(Math.PI/4);
    ctx.fillStyle="#8cf2d8";ctx.fillRect(-w*.01,-w*.01,w*.02,w*.02);ctx.restore();
  } else if (corner.glass === "chime") {
    ctx.save();ctx.translate(w*(.235+swing*.05),h*.65);ctx.rotate(Math.PI/4+swing);
    ctx.fillStyle="#68d8d5";ctx.fillRect(-w*.009,-w*.009,w*.018,w*.018);ctx.restore();
  } else if (corner.glass === "lamp") {
    ctx.fillStyle="#80f5dfb3";ctx.beginPath();ctx.arc(w*.73,h*.605,w*.024,0,2*Math.PI);ctx.fill();
    for(let n=0;n<(settled ? 5 : 3);n++) {
      ctx.fillStyle="#fff399";ctx.beginPath();
      ctx.arc(w*(.65+n*.032),h*((n%2 ? .71 : .68)-ripple*.032),w*.0055,0,2*Math.PI);ctx.fill();
    }
  }
  const pet = petImg(visitor?.pet ?? book.pet,visitor?.grown ?? (personalDays() >= 5));
  const petX = corner.glass === "lamp" ? .555 : .295;
  const hop = settled && corner.glass === "chime" ? ripple*.025*w : 0;
  if (pet.naturalWidth) ctx.drawImage(pet,petX*w,.79*h-.15*w-hop,.15*w,.15*w);
  if (withCaption) {
    ctx.fillStyle = "#fff9ef"; ctx.fillRect(0,h,w,canvas.height-h);
    ctx.fillStyle = "#334563"; ctx.font = "600 36px sans-serif";
    ctx.fillText("我的深圳湾长椅",26,h+59);
    ctx.font = "24px sans-serif"; ctx.fillStyle = "#97452e";
    ctx.textAlign = "right";
    ctx.fillText(["","深圳湾","海鸥邮戳","海鸥邮戳 · 红旗"][findLevel(outings[2])],w-25,h+58);
    ctx.textAlign = "left";
  }
}

function showBench(message = "", placed = null) {
  const corner = book.bench;
  const name = pets[book.pet][0];
  const trip = outings.find(r => r.id === corner.errand?.id);
  const ready = !!returnDay();
  sheet("我的海边长椅", "深圳湾");
  const scene = document.createElement("canvas");
  scene.className = "bench-scene";
  scene.width = 640; scene.height = 480;
  scene.setAttribute("role","img"); scene.setAttribute("aria-label","深圳湾长椅、你的精灵与已装好的寻回物");
  const map = document.createElement("div");
  map.className = "bench-map";
  choices.append(map);map.append(scene);
  const paint = () => paintBench(scene);
  paint();
  for (const img of [art(0),byId("findAtlas"),petImg(book.pet,personalDays()>=5)]) {
    if (!img.complete) img.addEventListener("load",paint,{once:true});
  }
  const say = document.createElement("output");
  say.className = "bench-note";
  say.setAttribute("aria-live","polite");
  say.textContent = message;
  choices.append(say);
  function update(note = "", placement = null) { commit(); showBench(note, placement); }
  function primary(label, fn, id) { choices.append(button(label,fn,{id,className:"key primary"})); }
  let animationFrame;
  function react(ring) {
    if (ring) {
      const sound = byId("bayChime");sound.currentTime = 0;sound.play().catch(() => {});
    }
    if (reduce.matches) return;
    cancelAnimationFrame(animationFrame);
    const start = performance.now();
    function animate(now) {
      if (!scene.isConnected) return;
      const t = Math.min(1,(now-start)/850);
      const phase = Math.sin(t*4*Math.PI)*(1-t);
      paintBench(scene,ring ? .12*phase : 0,false,null,Math.abs(phase));
      if (t<1) animationFrame = requestAnimationFrame(animate);
    }
    animationFrame = requestAnimationFrame(animate);
  }
  if (placed) react(placed === "chime");
  function mapButton(id,label,fn) {
    map.append(button(label,fn,{id:"glass-"+id,className:"glass-target "+id}));
  }
  if (corner.shell && (personalDays() || corner.glass)) {
    const settled = book.day > corner.glassDay;
    if (!corner.glass) {
      say.textContent ||= name + "低头嗅了嗅。潮水退去的地方，有一片蓝玻璃。";
      mapButton("pick","拾起海玻璃",() => {
        if (pickSeaGlass()) { update(); byId("glass-chime")?.focus({preventScroll:true}); }
      });
    } else if (corner.glass === "pocket") {
      say.textContent ||= "海玻璃在你手里。挂在风里，还是让它透出一点蓝光？";
      for (const [place,label] of [["chime","挂到风铃上"],["lamp","嵌进灯罩"]]) {
        mapButton(place,label,() => {
          if (!placeSeaGlass(place)) return;
          update("",place);byId("glass-"+place)?.focus({preventScroll:true});
        });
      }
    } else if (corner.glass === "chime") {
      say.textContent ||= settled ? name + "又蹲在风铃旁，举起了一只前爪。" : "海玻璃碰着白贝，" + name + "竖起了耳朵。";
      mapButton("chime","拨一下风铃",() => {
        react(true);
        say.textContent = settled ? "叮、叮。" + name + "也用前爪轻轻拍了两下。" : name + "歪着头，一直听到最后一声。";
      });
    } else if (corner.glass === "lamp") {
      say.textContent ||= settled ? "上次灯下有三只萤火虫，这回有五只了。" : "草尖映着蓝光。三只萤火虫停在灯下。";
      mapButton("lamp","碰碰路灯",() => {
        react(false);
        say.textContent = settled ? name + "在灯下趴好，望着五点萤火。" : "你碰了碰灯罩，三点萤火从草尖飞了起来。";
      });
    }
  }
  if (!corner.shell) {
    section("树枝下有一枚白贝");
    say.textContent = name + "把白贝推到你脚边。木架上还空着一个小钩。";
    primary("挂上白贝", () => { corner.shell = true; update(personalDays() ? "" : "白贝晃了两下。明天想让" + name + "去哪儿？"); }, "take-shell");
  } else if (trip) {
    const find = trip.finds[findLevel(trip)];
    section(ready ? name + "带回了" + find : name + "去了" + trip.title);
    if (ready) {
      primary("把" + find + "装到长椅边", () => {
        if (unpackOuting()) update(trip.notes[findLevel(trip)-1]);
      }, "unpack-find");
    } else {
      const status = document.createElement("p");
      status.className = "bench-status";
      const when = book.day > corner.errand.departure ? "今天" : "明天起";
      status.textContent = when + "，手表同步或你记下一个习惯，" + name + "就会带回" + find + "。晚几天来，它也会等你。";
      choices.append(status);
      primary(book.day > corner.errand.departure && !book.watch ? "试玩记" + book.habit : "试玩下一天", () => {
        const advanceDay = book.day <= corner.errand.departure;
        if (advanceDay) book.day = corner.errand.departure + 1;
        if (book.watch) record(watchSamples[(book.day-1)%watchSamples.length]);
        else if (!advanceDay) record(book.habit);
        update();
      }, "bench-demo-day");
    }
  } else {
    const available = outings.filter(r => findLevel(r) < r.finds.length);
    section(available.length ? "让" + name + "去哪儿寻宝？" : "这段海湾有了你的模样");
    for (const route of available) {
      const n = findLevel(route);
      const b = button("", () => { if (sendOuting(route)) update(); },{id:"outing-"+route.id,className:"bench-route"});
      const icon = document.createElement("canvas");
      icon.width = icon.height = 64;
      const paintIcon = () => drawFind(icon.getContext("2d"),[n,outings.indexOf(route)],32,64,64);
      paintIcon();
      if (!byId("findAtlas").complete) byId("findAtlas").addEventListener("load",paintIcon,{once:true});
      const name = document.createElement("strong"), hint = document.createElement("small");
      name.textContent = route.title; hint.textContent = "寻找" + route.finds[n];
      const label = document.createElement("span"); label.append(name,hint);
      b.append(icon,label); choices.append(b);
    }
  }
  if (!corner.shell) return;
  section("长椅边");
  if (corner.glass !== "chime") choices.append(button(findLevel(outings[0]) ? "拨响风铃" : "听白贝", () => {
    react(true);
    say.textContent = findLevel(outings[0]) ? "叮、叮。贝壳在风里碰了两下。" : "白贝轻轻碰在木架上。";
  },{id:"ring-shell"}));
  if (findLevel(outings[1])) choices.append(button("换灯色",() => {
    corner.cool = !corner.cool;
    update(corner.cool ? "灯光变成了海玻璃的青色。" : "灯光变回暖暖的琥珀色。");
  },{id:"lamp-color"}));
  choices.append(button("请朋友来坐坐",async () => {
    const url = benchLink();
    try {
      if (navigator.share) await navigator.share({title:"我的深圳湾长椅",url});
      else { await navigator.clipboard.writeText(url); say.textContent = "长椅链接已复制，朋友打开就能来坐坐。"; }
    } catch (e) {
      if (e.name === "AbortError") return;
      const input = document.createElement("input");
      input.value = url; input.readOnly = true; input.setAttribute("aria-label","长椅分享链接");
      choices.append(input); input.focus(); input.select();
    }
  },{id:"invite-bench"}));
  if (findLevel(outings[2])) choices.append(button("保存海湾明信片",async () => {
    const card = document.createElement("canvas");
    card.width = 960; card.height = 816;
    try {
      await Promise.all([art(0),byId("findAtlas"),petImg(book.pet,personalDays() >= 5)].map(im => im.decode()));
      paintBench(card,0,true);
      const link = document.createElement("a");
      link.download = "栖灵-我的深圳湾长椅.png";
      link.href = card.toDataURL("image/png"); link.click();
      say.textContent = "明信片已生成，可以把这片海湾寄给朋友了。";
    } catch {
      say.textContent = "图片暂时无法导出，请打开离线试玩文件或通过本地服务重试。";
    }
  },{id:"print-bench"}));
}

function openBenchVisit() {
  const visitCard = readBenchLink(location.hash);
  if (!visitCard) return;
  sheet("朋友的深圳湾长椅","精灵给你留了个看海的位置。");
  const canvas = document.createElement("canvas");
  canvas.className = "bench-scene"; canvas.width = 640; canvas.height = 480;
  canvas.setAttribute("role","img"); canvas.setAttribute("aria-label","朋友布置的海湾长椅");
  choices.append(canvas);
  const paint = () => paintBench(canvas,0,false,visitCard);
  paint();
  for (const im of [art(0),byId("findAtlas"),petImg(visitCard.pet,visitCard.grown)]) {
    if (!im.complete) im.addEventListener("load",paint,{once:true});
  }
  const treasures = outings.flatMap(r => {
    const n = visitCard.corner.levels[r.id];
    return n ? [r.finds[n-1]] : [];
  });
  const note = document.createElement("p");
  note.textContent = treasures.length ? "长椅边有" + treasures.join("、") + "。" : "木架上，第一枚白贝正在风里轻轻晃。";
  choices.append(note);
  choices.append(button(book.bench.shell ? "回我的海边长椅" : "我也去捡一枚白贝", () => {
    history.replaceState(null,"",location.pathname + location.search);
    showBench();
  },{id:"start-own-bench",className:"key primary"}));
}

