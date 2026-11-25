import test from "node:test";
import assert from "node:assert/strict";
import {entrances, floorAt, moveOnGround} from "./walk-ground.mjs";

test("every advertised entrance stands on supported ground",()=>{
  for(const [name,entry] of Object.entries(entrances)){
    assert.notEqual(floorAt(entry.x,entry.z),null,name);
  }
});

test("B's three runs reach the upper deck and descend without falling through it",()=>{
  const s={...entrances.steps,h:.14};
  moveOnGround(s,0,-20.25);
  assert.ok(Math.abs(s.z-4.75)<.001);
  assert.equal(s.h,6.61);
  moveOnGround(s,-3,0);
  assert.equal(s.h,6.61);
  moveOnGround(s,3,0);
  moveOnGround(s,0,20.25);
  assert.equal(s.h,.14);
  assert.ok(Math.abs(s.z-25)<.001);
});

test("the C flight and landing are accessible, with no step onto an overhead deck",()=>{
  const s={x:-4,z:5.7,h:.14};
  moveOnGround(s,10.6,0);
  assert.equal(s.h,3.74);
  moveOnGround(s,0,-2.9);
  assert.equal(s.h,3.74);
  moveOnGround(s,-2.3,0);
  assert.ok(s.x>=6);
  assert.equal(floorAt(22,4.6,.14),.14);
  assert.equal(floorAt(22,4.6,6.61),6.61);
});

test("the camera stops before piers, bike racks, lobby furniture, and courtyard edges",()=>{
  for (const [x,z] of [[-8.15,13.79],[-10.85,15.65],[-9.95,-6.21],[-7.1,-6.66],[23.2,17.6],[50,25]]){
    assert.equal(floorAt(x,z),null,x+","+z);
  }
  const s={x:-10.85,z:21,h:.14};
  moveOnGround(s,0,-12);
  assert.ok(s.z>16.7);
});
