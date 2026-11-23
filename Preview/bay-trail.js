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
