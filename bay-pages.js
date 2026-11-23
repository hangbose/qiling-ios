"use strict";

(() => {
  const panel = byId("fieldPage");
  const tabs = Array.from(document.querySelectorAll(".field-tabs [data-page]"));
  const pages = {
    companion: ["伙伴营地", 1],
    square: ["小队邮局", 2],
    growth: ["成长手帐", 3],
    profile: ["旅行护照", 4],
  };
  let active = "journey";
  let showRank = false;

  function element(tag, className, text) {
    const el = document.createElement(tag);
    if (className) el.className = className;
    if (text !== undefined) el.textContent = text;
    return el;
  }
  function petImage(className) {
    const img = element("img", className);
    img.src = petImg(book.pet, personalDays() >= 5).src;
    img.alt = pets[book.pet][0];
    return img;
  }
  function card(title, note) {
    const box = element("article", "field-leaf");
    if (title) box.append(element("h2", "", title));
    if (note) box.append(element("p", "", note));
    panel.append(box);
    return box;
  }
  function row(box, label, value) {
    const line = element("div", "field-info");
    line.append(element("span", "", label), element("strong", "", String(value)));
    box.append(line);
  }
  function actions(parent, specs) {
    const bar = element("div", "field-actions");
    for (const [name, click, primary] of specs)
      bar.append(button(name, click, { className: primary ? "key primary" : "key" }));
    parent.append(bar);
  }
  function syncHere(fn) {
    fn();
    commit();
    paint();
  }
  function choosePet() {
    sheet("伙伴图鉴", "选一位伙伴陪你走深圳。已走过的路和贝壳都会保留。");
    const group = element("div", "pet-cards");
    for (const [id, [name]] of Object.entries(pets)) {
      const pick = button("", () => {
        book.pet = id;
        commit();
        byId("sheet").close();
      }, {className: "pet-card"});
      pick.setAttribute("aria-pressed", String(book.pet === id));
      const img = element("img");
      img.src = petImg(id, personalDays() >= 5).src;
      img.alt = "";
      pick.append(img, name);
      group.append(pick);
    }
    choices.append(group);
  }
  function companion(cover) {
    const touch = element("button", "camp-pet");
    touch.setAttribute("aria-label", "摸摸" + pets[book.pet][0]);
    const reply = element("output");
    const greetings = ["摸摸收到啦！", "再坐一会儿吧。", "我们去海边走走？"];
    let taps = 0;
    touch.onclick = () => { reply.textContent = greetings[taps++ % greetings.length]; };
    touch.append(petImage(), reply);
    cover.append(touch);
    const log = card(pets[book.pet][0], pets[book.pet][1]);
    row(log, "一起走过", personalDays() + " 个习惯日");
    actions(panel, [["伙伴图鉴", choosePet, true], ["成长手帐", () => openPage("growth")]]);
    const today = card("今日补给");
    row(today, book.days[book.day] || "今日尚未记录", (ledger().find(r => r.day === book.day)?.amount || 0) + " 枚贝壳");
    const check = button(book.days[book.day] ? "今日已记录" : "记一次" + book.habit, () => {
      walk("manual"); paint();
    }, {disabled: Boolean(book.days[book.day])});
    today.append(check);
  }
  function square() {
    const team = card("海湾接力", book.team ? "你和小雨正在同一条路上接力。" : "自己走，也可以邀请示例伙伴小雨同行。");
    actions(team, [["结伴设置", teamSheet, true], ["回到旅途", () => openPage("journey")]]);
    row(team, "小队已走", book.teamSteps.length + " 程");
    const letters = card("小队来信");
    actions(letters, [["近况", () => { showRank = false; paint(); }, !showRank], ["同行榜", () => { showRank = true; paint(); }, showRank]]);
    if (!book.teamSteps.length) letters.append(element("p", "", "开启接力后，每次完成习惯都能为这条路添上一程。"));
    else if (showRank) {
      const scores = [["我", "me"], ["小雨", "friend"]].map(([name, id]) => [name, book.teamSteps.filter(s => s.startsWith(id + "|")).length]);
      for (const [name, steps] of scores.sort((a,b) => b[1] - a[1])) row(letters, name, steps + " 程");
    } else {
      for (const item of book.teamSteps.slice(-4).reverse()) {
        const [who, day] = item.split("|");
        row(letters, who === "me" ? "我寄来了脚印" : "小雨寄来了脚印", "第 " + day + " 天");
      }
    }
    panel.append(element("small", "field-note", "离线试玩使用示例小队。TestFlight 版支持邀请码和真实队友。"));
  }
  function growth() {
    const week = card("最近七天", "第 " + book.day + " 天 · 已留下 " + personalDays() + " 个脚印");
    const chart = element("div", "field-chart");
    const end = Math.max(7, book.day);
    const entries = ledger();
    const byDay = new Map(entries.map(entry => [entry.day, entry.amount]));
    for (let day = end - 6; day <= end; day++) {
      const amount = byDay.get(day) || 0;
      const bar = element("span");
      const ink = element("i");
      ink.style.height = Math.max(2, amount * 0.67) + "px";
      bar.setAttribute("aria-label", "第 " + day + " 天，" + amount + " 枚贝壳");
      bar.append(ink, String(day)); chart.append(bar);
    }
    week.append(chart);
    const account = card("习惯来账");
    if (!entries.length) account.append(element("p", "", "完成第一项习惯后，手帐会记下原因和贝壳。"));
    for (const d of entries.slice(-5).reverse()) row(account, "第 " + d.day + " 天 · " + d.reason, "+" + d.amount);
    actions(panel, [["翻旅行手记", journal, true], ["深圳图册", atlas]]);
  }
  function profile() {
    const pass = card();
    const id = element("div", "field-pass"), text = element("div");
    text.append(element("h2", "", pets[book.pet][0]), element("p", "", "深圳 · 第 " + book.day + " 天"));
    id.append(petImage("stamp-pet"), text); pass.append(id);
    row(pass, "随身贝壳", walletBalance() + " 枚");
    const settings = card("旅行偏好");
    row(settings, "快捷习惯", book.habit);
    row(settings, "手表示例同步", book.watch ? "已开启" : "已关闭");
    actions(settings, [["更换习惯", journal], [book.watch ? "暂停示例同步" : "开启示例同步", () => syncHere(() => {book.watch = !book.watch;})]]);
    panel.append(element("small", "field-note", "偏好保存在这个浏览器。手机上的健康授权在 App 内管理。"));
  }
  function paint() {
    if (active === "journey") return;
    panel.replaceChildren();
    const [title, scene] = pages[active];
    const cover = element("div", "field-cover"), photo = element("img");
    photo.src = art(scene).src; photo.alt = "";
    const sign = element("header"), heading = element("h1", "", title);
    heading.id = "fieldTitle";
    sign.append(element("small", "", "深圳 · " + districts[scene].name), heading);
    cover.append(photo, sign); panel.append(cover);
    ({companion, square, growth, profile})[active](cover);
  }
  function openPage(page) {
    active = page;
    panel.dataset.view = page;
    byId("journeyPage").hidden = page !== "journey";
    panel.hidden = page === "journey";
    for (const tab of tabs) {
      if (tab.dataset.page === page) tab.setAttribute("aria-current", "page");
      else tab.removeAttribute("aria-current");
    }
    paint();
    if (page === "journey") camera();
    document.querySelector(".game").scrollIntoView({block:"start", behavior:"instant"});
  }
  for (const tab of tabs) tab.onclick = () => openPage(tab.dataset.page);
  byId("sheet").addEventListener("close", paint);
})();
