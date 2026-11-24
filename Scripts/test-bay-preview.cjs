const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const vm = require("node:vm");

const model = readFileSync(path.join(__dirname, "../Preview/bay-trail.js"), "utf8");

test("only personal habit days unlock trail actions, including on previous saves", () => {
  const storage = new Map(), game = start(storage);
  game("book.team=true; relay('friend')");
  assert.equal(game("learnedTrick()"), 0);
  for (const [day,expected] of [[1,1],[2,1],[5,2],[7,2],[9,3]]) {
    game("book.day="+day+";record('阅读');record('步行千步');relay('friend')");
    assert.equal(game("learnedTrick()"), expected);
  }
  game("persist()");
  assert.equal(start(storage)("learnedTrick()"), 3);
});

test("each habit day covers a visible stretch with room at both ends of every panorama", () => {
  const game = start();
  for (const [width, height] of [[325, 470], [390, 645], [430, 700], [720, 430]]) {
    for (let i = 0; i < 5; i++) {
      const world = game(`panoramaSize(${i}, ${width}, ${height})`);
      const length = game(`districts[${i}].length`);
      const step = game(`trailX(${i}, 1) - trailX(${i}, 0)`) * world.width;
      assert.ok(step >= width * 0.82 - 0.001);
      assert.ok(world.height >= height);
      assert.ok(game(`trailX(${i}, ${length})`) < 1);
      assert.ok(game(`trailX(${i}, 0)`) > 0);
    }
  }
});

function start(storage = new Map()) {
  const sandbox = vm.createContext({
    localStorage: {
      getItem: key => storage.get(key) ?? null,
      setItem: (key, value) => storage.set(key, value),
    },
  });
  vm.runInContext(model, sandbox);
  return expression => vm.runInContext(expression, sandbox);
}

test("only a later personal habit brings home a find; returning late and reloading preserve it", () => {
  const storage = new Map(), game = start(storage);
  game("book.bench.shell=true; record('阅读'); book.team=true; sendOuting(outings[1]); book.day=2; relay('friend')");
  assert.equal(game("unpackOuting()"), false);
  assert.equal(game("sendOuting(outings[2])"), false);
  game("book.day=4; record('步行千步'); book.day=8; persist()");
  const restored = start(storage);
  assert.equal(restored("unpackOuting()"), true);
  assert.equal(restored("unpackOuting()"), false);
  assert.equal(restored("findLevel(outings[1])"), 1);
  assert.equal(restored("sendOuting(outings[0]); unpackOuting()"), false);
  assert.equal(restored("walletBalance()"), 100);
});

test("nine finds complete three distinct scenes and the same habit cannot be reused", () => {
  const game = start();
  game("book.bench.shell=true; for(const r of outings){for(let n=0;n<3;n++){sendOuting(r);book.day++;record('阅读');unpackOuting();}}");
  assert.equal(game("outings.every(r=>findLevel(r)===3 && !sendOuting(r))"),true);
  assert.equal(game("book.bench.cool=true; benchTile(1).join(',')"),"3,3");
});

test("sea glass can wait in a pocket and belongs to one decoration across visits", () => {
  for (const place of ["chime", "lamp"]) {
    const storage = new Map(), game = start(storage);
    game("book.bench.shell=true; book.bench.levels.post=2; relay('friend')");
    assert.equal(game("pickSeaGlass()"), false);
    game("record('阅读');pickSeaGlass();persist()");
    const restored = start(storage);
    assert.equal(restored("book.bench.glass"), "pocket");
    assert.equal(restored("placeSeaGlass('"+place+"')"), true);
    restored("book.day++;persist()");
    const next = start(storage);
    assert.equal(next("book.day>book.bench.glassDay"), true);
    assert.equal(next("pickSeaGlass() || placeSeaGlass('other') || placeSeaGlass('"+place+"')"), false);
    assert.equal(next("readBenchLink('#'+benchLink().split('#')[1]).corner.glass"), place);
    assert.equal(next("findLevel(outings[2])"), 2);
    assert.equal(next("walletBalance()"), 50);
  }
});

test("a bench invitation is a decorative snapshot and opening it never imports the sender's progress", () => {
  const game = start();
  game("book.bench.shell=true;book.bench.levels={tide:1,light:2,post:1};book.bench.cool=true;book.pet='yaya'");
  const hash = game("benchLink().split('#')[1]");
  assert.equal(hash, "bench=yaya.0.1.2.1.1");
  const visitor = start();
  assert.equal(visitor("readBenchLink('#"+hash+"').corner.levels.light"),2);
  assert.equal(visitor("book.bench.shell"),false);
  assert.equal(visitor("readBenchLink('#bench=yaya.0.8.0.1.0')"),null);
});

test("real calendar rollover never invents habits or counts the same day twice", () => {
  const game = start();
  game("rollCalendar(new Date(2026,10,30));record('阅读');rollCalendar(new Date(2026,11,3));rollCalendar(new Date(2026,11,3))");
  assert.equal(game("book.day"),4);
  assert.equal(game("personalDays()"),1);
});

test("migrates the original demo with its actual habits and bought planter", () => {
  const storage = new Map([
    ["qiling.shenzhen-bay.demo.v1", JSON.stringify({ stage: 3, extraDays: 3, owned: ["planter"] })],
  ]);
  const game = start(storage);
  assert.equal(game("book.days[3]"), "步行千步");
  assert.equal(game("book.days[5]"), "完成阅读");
  assert.equal(game("walletBalance()"), 305);
  assert.equal(game("route().total"), 6);
  game("persist()");
  assert.equal(start(storage)("book.placements.planter.region"), 0);
});

test("crosses all 15 landmarks, preserves visits, and starts a new circuit on day 79", () => {
  const game = start();
  game('for (let i=1; i<=78; i++) { book.day=i; record("阅读"); }');
  assert.equal(game("route().current"), 4);
  assert.equal(game("route().lap"), 1);
  game('book.day++; record("喝水")');
  assert.equal(game("route().current"), 0);
  assert.equal(game("route().lap"), 2);
  assert.equal(game("route().at(4)"), 18);
});

test("a friend advances the team once without earning shells for another player", () => {
  const game = start();
  game('record("专注"); book.team = true; relay("me"); relay("friend"); relay("friend"); record("步行千步");');
  assert.equal(game("route().total"), 2);
  assert.equal(game("walletBalance()"), 50);
  game("book.team = false");
  assert.equal(game("route().total"), 1);
});


test("keeps saved solo and relay landmarks when each route gets longer", () => {
  const storage = new Map();
  const original = start(storage);
  original('for(let i=1;i<=9;i++){book.day=i;record("阅读")} book.teamSteps=Array.from({length:4},(_,i)=>"friend|"+i);delete book.shortSolo;delete book.shortTeam;persist();');
  const game = start(storage);
  assert.equal(game("route().at(1)"), 15);
  const earned = game("walletBalance()");
  game("book.team=true");
  assert.equal(game("route().current"), 1);
  assert.equal(game("route().at(1)"), 3);
  game("book.team=false;book.day++;record('阅读');persist()");
  assert.equal(game("route().at(2)"), 1);
  assert.equal(start(storage)("route().at(2)"), 1);
  assert.equal(game("walletBalance()"), earned + 80);
});
