import assert from 'node:assert/strict';
import {startAutoScroll} from '../docs/auto-scroll.mjs';

const originals = new Map(['matchMedia','performance','document','requestAnimationFrame'].map(key => [key,Object.getOwnPropertyDescriptor(globalThis,key)]));
let now = 0, frames = [];
const desktop = {matches:true};
const target = (height = 120) => ({
  scrollTop:0, scrollHeight:height, clientHeight:100, events:{}, attributes:{},
  addEventListener(name, fn) {this.events[name] = fn;},
  setAttribute(name, value) {this.attributes[name] = value;}
});
const tick = milliseconds => {
  now += milliseconds;
  const pending = frames; frames = [];
  pending.forEach(frame => frame(now));
};
try {
  for (const [key,value] of Object.entries({
    matchMedia: () => desktop,
    performance:{now:() => now}, document:{hidden:false},
    requestAnimationFrame: frame => frames.push(frame)
  })) Object.defineProperty(globalThis,key,{value,configurable:true,writable:true});
  const button = target(), games = target(), rankings = target(140);
  startAutoScroll(button, [[games,20],[rankings,10]]);
  tick(4000);
  assert.equal(games.scrollTop,0);
  for (let i=0;i<10;i++) tick(100);
  assert.equal(games.scrollTop,20);
  assert.equal(rankings.scrollTop,10);
  tick(3900);
  assert.equal(games.scrollTop,20);
  tick(100);
  assert.equal(games.scrollTop,18);
  games.events.pointermove(); games.scrollTop = 7;
  tick(100); tick(7800);
  assert.equal(games.scrollTop,7);
  tick(100);
  assert.equal(games.scrollTop,5);
  button.events.click(); tick(1000);
  assert.equal(games.scrollTop,5);
  assert.equal(button.attributes['aria-pressed'],'false');
  button.events.click(); tick(100);
  assert.equal(games.scrollTop,3);
  desktop.matches = false; tick(1000);
  assert.equal(games.scrollTop,3);
  desktop.matches = true; games.scrollHeight = 105; tick(100);
  assert.equal(games.scrollTop,1);
  console.log('auto-scroll: automatic start, initial/end holds, reversal, interaction timeout, independent regions, toggle, mobile and resize');
} finally {
  for (const [key,descriptor] of originals) {
    if (descriptor) Object.defineProperty(globalThis,key,descriptor);
    else delete globalThis[key];
  }
}
