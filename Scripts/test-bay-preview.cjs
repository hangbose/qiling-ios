const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const vm = require("node:vm");

const model = readFileSync(path.join(__dirname, "../Preview/bay-trail.js"), "utf8");

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
