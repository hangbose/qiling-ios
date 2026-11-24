"use strict";
const districts = [
  {
    name: "深圳湾",
    stops: ["海边长椅", "海湾转角", "观景平台"],
    notes: ["海风掀起一片红树叶。", "潮水绕过岸边的石头。", "春笋的剪影落进晚霞里。"],
    length: 12,
  },
  {
    name: "人才公园",
    stops: ["星光桥", "湖畔草坡", "春笋倒影"],
    notes: ["桥下的光晃成一片。", "草坡上留着清晨的露水。", "春笋的倒影几乎碰到了鞋尖。"],
    length: 15,
  },
  {
    name: "华侨城创意园",
    stops: ["红砖巷", "榕树庭院", "街角咖啡"],
    notes: ["红砖墙在夕阳里发亮。", "榕树荫里传来几声鸟鸣。", "街角飘来烘豆子的香气。"],
    length: 15,
  },
  {
    name: "莲花山",
    stops: ["风筝草坪", "山脊小径", "山顶看台"],
    notes: ["风筝从树梢后面飞了起来。", "树荫里有一段凉快的小路。", "山顶的风把整座城都吹亮了。"],
    length: 18,
  },
  {
    name: "大梅沙",
    stops: ["听潮栈道", "拾贝浅滩", "海边灯火"],
    notes: ["浪花在栈道脚下拍手。", "退潮的沙滩留下一枚螺旋贝。", "岸边的灯火把这圈旅途串起来了。"],
    length: 18,
  },
];
const pets = {
  legacy: ["星澜", "星尾小狐"],
  yaya: ["芽芽", "垂耳花兔"],
  xiaoying: ["小影", "金围巾夜猫"],
};
const goods = [
  {
    id: "planter",
    name: "簕杜鹃花盆",
    price: 35,
    x: 0.3,
    size: 0.065,
    detail: "一簇开在海风里的深圳市花。",
  },
  {
    id: "pennant",
    name: "海风信号旗",
    price: 75,
    x: 0.84,
    size: 0.075,
    detail: "给沿途的伙伴留个记号。",
  },
  {
    id: "cottage",
    name: "海堤小屋",
    price: 420,
    x: 0.39,
    size: 0.135,
    detail: "攒一扇属于自己的亮窗。",
  },
];
const habits = ["阅读", "喝水", "专注"],
  watchSamples = ["按时入睡", "步行千步", "户外跑步", "睡眠达标"];
const storageKey = "qiling.shenzhen-trail.demo.v2";
function freshBook() {
  return {
    day: 1,
    days: {},
    team: false,
    teamSteps: [],
    pet: "legacy",
    habit: "阅读",
    watch: true,
    buys: {},
    placements: {},
    bench: { shell: false, levels: {}, errand: null, lastUsed: 0, cool: false },
    shortSolo: 0,
    shortTeam: 0,
  };
}
function restore() {
  try {
    const current = JSON.parse(localStorage.getItem(storageKey));
    if (
      current &&
      Number.isSafeInteger(current.day) &&
      current.day > 0 &&
      current.days &&
      Array.isArray(current.teamSteps) &&
      Object.hasOwn(pets, current.pet)
    )
      return Object.assign(
        freshBook(),
        { shortSolo: Object.keys(current.days).length, shortTeam: current.teamSteps.length },
        current,
      );
    const old = JSON.parse(localStorage.getItem("qiling.shenzhen-bay.demo.v1")),
      b = freshBook();
    if (!old || !Number.isInteger(old.stage) || old.stage < 1 || old.stage > 3) return b;
    b.days[1] = "按时入睡";
    if (old.stage >= 2) {
      b.team = true;
      b.teamSteps = ["me|1", "friend|1"];
    }
    if (old.stage === 3) {
      b.days[2] = "阅读";
      b.day = 2;
      b.teamSteps.push("me|2");
      const previousHabits = [
        "步行千步",
        "按时入睡",
        "完成阅读",
        "运动达标",
        "睡眠达标",
        "完成专注",
      ];
      for (let i = 0; i < Math.min(previousHabits.length, old.extraDays || 0); i++) {
        b.day++;
        b.days[b.day] = previousHabits[i];
        b.teamSteps.push("me|" + b.day);
      }
    }
    for (const item of goods)
      if (old.owned?.includes(item.id)) {
        b.buys[item.id] = item.price;
        b.placements[item.id] = { region: 0, x: item.x };
      }
    b.shortSolo = Object.keys(b.days).length;
    b.shortTeam = b.teamSteps.length;
    return b;
  } catch {
    return freshBook();
  }
}
let book = restore();
function persist() {
  try {
    localStorage.setItem(storageKey, JSON.stringify(book));
  } catch {}
}
function ledger() {
  let last = 0,
    amount = 50;
  return Object.keys(book.days)
    .map(Number)
    .sort((a, b) => a - b)
    .map((day) => {
      if (last)
        amount =
          last + 1 === day
            ? Math.min(80, amount + 10)
            : Math.max(50, amount - 10 * (day - last - 1));
      last = day;
      return { day, reason: book.days[day], amount };
    });
}
function walletBalance() {
  return (
    ledger().reduce((s, d) => s + d.amount, 0) - Object.values(book.buys).reduce((a, b) => a + b, 0)
  );
}
function personalDays() {
  return Object.keys(book.days).length;
}
const trailTricks = [
  {days:0, name:"轻轻一跃"}, {days:1, name:"发光脚印"},
  {days:3, name:"引来流萤"}, {days:5, name:"点出星座"}
];
function learnedTrick() {
  const days = personalDays();
  return trailTricks.findLastIndex(trick => days >= trick.days);
}
const outings = [
  { id: "tide", title: "退潮的小径", finds: ["一枚蓝贝", "两片海玻璃", "珊瑚色坠子"],
    notes: ["蓝贝碰上白贝，听见第一声海风。", "海玻璃碰在一起，多了一对清亮的音。", "坠子接住海风，这串风铃终于齐了。"] },
  { id: "light", title: "堤边灯铺", finds: ["琥珀灯罩", "黄铜提梁", "星纹灯帽"],
    notes: ["长椅脚边有了一盏小灯。点一下可以换灯色。", "提梁架起来，晚归的人也看得清小路。", "灯帽把星星留在这段海堤。"] },
  { id: "post", title: "老邮局", finds: ["旧木信箱", "海鸥邮戳", "红色信号旗"],
    notes: ["长椅旁有了自己的信箱。可以寄张海湾明信片。", "海鸥邮戳落在了你的明信片上。", "小红旗升起来了，今天也有一封海边来信。"] },
];
function findLevel(route) { return book.bench.levels[route.id] || 0; }
function pickSeaGlass() {
  if (!book.bench.shell || !personalDays() || book.bench.glass) return false;
  book.bench.glass = "pocket";
  return true;
}
function placeSeaGlass(place) {
  if (book.bench.glass !== "pocket" || !["chime", "lamp"].includes(place)) return false;
  book.bench.glass = place;
  book.bench.glassDay = book.day;
  return true;
}
function sendOuting(route) {
  if (!book.bench.shell || book.bench.errand || findLevel(route) >= route.finds.length) return false;
  book.bench.errand = { id: route.id, departure: Math.max(book.day, book.bench.lastUsed) };
  return true;
}
function returnDay() {
  const trip = book.bench.errand;
  return trip && Object.keys(book.days).map(Number).filter(day => day > trip.departure).sort((a,b) => a-b)[0];
}
function unpackOuting() {
  const day = returnDay();
  if (!day) return false;
  const route = outings.find(route => route.id === book.bench.errand.id);
  if (!route || findLevel(route) >= route.finds.length) return false;
  book.bench.levels[route.id] = findLevel(route) + 1;
  book.bench.lastUsed = day;
  book.bench.errand = null;
  return true;
}
function benchTile(row) {
  return keepsakeTile(book.bench,row);
}
function keepsakeTile(corner,row) {
  const level = corner.levels[outings[row].id] || 0;
  if (row === 0 && !level && corner.shell) return [0,3];
  if (!level) return null;
  return row === 1 && corner.cool ? [level,3] : [level-1,row];
}
function benchLink() {
  const parts = [book.pet,Number(personalDays()>=5),...outings.map(findLevel),Number(book.bench.cool)];
  if (["chime","lamp"].includes(book.bench.glass)) parts.push(book.bench.glass === "chime" ? "c" : "l");
  const code = parts.join(".");
  return "https://hangbose.github.io/qiling-ios/#bench=" + code;
}
function readBenchLink(hash) {
  const match = /^#bench=(legacy|yaya|xiaoying)\.([01])\.([0-3])\.([0-3])\.([0-3])\.([01])(?:\.([cl]))?$/.exec(hash);
  if (!match) return null;
  return {pet:match[1],grown:match[2]==="1",corner:{shell:true,cool:match[6]==="1",
    glass:match[7] === "c" ? "chime" : match[7] === "l" ? "lamp" : null,
    levels:{tide:Number(match[3]),light:Number(match[4]),post:Number(match[5])}}};
}
function rollCalendar(now = new Date()) {
  const local = Date.UTC(now.getFullYear(),now.getMonth(),now.getDate()) / 86400000;
  if (book.calendarDay == null) { book.calendarDay = local; return true; }
  if (local <= book.calendarDay) return false;
  book.day += local - book.calendarDay;
  book.calendarDay = local;
  return true;
}
function relay(who) {
  const key = who + "|" + book.day;
  if (book.team && !book.teamSteps.includes(key)) book.teamSteps.push(key);
}
function record(reason) {
  if (book.days[book.day]) return false;
  book.days[book.day] = reason;
  relay("me");
  return true;
}
function route() {
  const total = book.team ? book.teamSteps.length : personalDays(),
    length = districts.reduce((s, d) => s + d.length, 0);
  const legacy = Math.min(total, book.team ? book.shortTeam : book.shortSolo);
  const oldLengths = [3, 6, 6, 6, 6];
  const oldLap = oldLengths.reduce((sum, n) => sum + n, 0);
  let remaining = legacy % oldLap;
  let position = Math.floor(legacy / oldLap) * length + total - legacy;
  districts.forEach((area, i) => {
    const old = oldLengths[i],
      segment = Math.min(old, remaining);
    position += Math.ceil((segment * area.length) / old);
    remaining -= segment;
  });
  const lap = Math.floor(Math.max(0, position - 1) / length) + 1,
    within = position === 0 ? 0 : ((position - 1) % length) + 1;
  let before = 0,
    current = 0;
  const ticks = districts.map((d, i) => {
    const t = Math.min(d.length, Math.max(0, within - before));
    before += d.length;
    if (t > 0) current = i;
    return t;
  });
  return {
    total,
    lap,
    current,
    available: (i) => lap > 1 || i <= current,
    at: (i) => (lap > 1 && i > current ? districts[i].length : ticks[i]),
  };
}
function ground(region, x) {
  return [
    0.756 - Math.max(0, x - 0.36) * 0.2,
    0.8 - 0.012 * x,
    0.79 - 0.035 * x,
    0.76 + 0.016 * x,
    0.77 - 0.022 * x,
  ][region];
}

// The route is measured in the panorama. Sprite sizes stay in viewport coordinates.
const landscapeAspects = [26, 13, 13, 26, 13];
// Ground contact along the painted paths, sampled at eighths of each panorama.
const pathProfiles = [
  [.90, .90, .89, .90, .91, .90, .91, .88, .90],
  [.90, .90, .91, .91, .91, .90, .91, .90, .91],
  [.90, .91, .90, .90, .89, .91, .90, .91, .92],
  [.85, .84, .84, .85, .84, .84, .85, .86, .84],
  [.91, .91, .89, .90, .91, .90, .90, .92, .91],
];
function trailX(i, ticks) {
  return 0.035 + 0.93 * Math.max(0, Math.min(1, ticks / districts[i].length));
}
function panoramaSize(i, screenWidth, screenHeight) {
  const landscapeAspect = landscapeAspects[i];
  const width = Math.max(screenHeight * landscapeAspect, screenWidth * districts[i].length * 0.82 / 0.93);
  return { width, height: width / landscapeAspect };
}
function promenadeY(i, x) {
  const heights = pathProfiles[i], t = Math.max(0, Math.min(1, x)) * (heights.length - 1);
  const a = Math.min(Math.floor(t), heights.length - 2);
  return heights[a] + (heights[a + 1] - heights[a]) * (t - a);
}
