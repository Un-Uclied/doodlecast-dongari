import assert from 'node:assert/strict';
import {rankPlayers,formatPlayRecord} from '../docs/ranking.mjs';
const record=(id,participant_key,score,hits=0,finished_ms=1)=>({id,participant_key,score,hits,finished_ms,status:'finished'});
const records=[record('a','one',100,2),record('b','one',200,1),record('c','two',200,0,9),record('d','three',200,0,3),record('e','four',150)];
assert.deepEqual(rankPlayers(records).map(r=>r.id),['d','c','b','e']);
assert.equal(rankPlayers([{...records[0],status:'started'}]).length,0);
assert.equal(rankPlayers(Array.from({length:30},(_,i)=>record(String(i),String(i),i))).length,30);
console.log('site self-test: OK (best result, ties, all 30 participants)');

assert.equal(rankPlayers(Array.from({length:1000},(_,i)=>record(String(i),String(i),i))).at(-1).score,0);
assert.deepEqual(formatPlayRecord({difficulty:'HARD',level:4,cleared:0,kills:62,hits:3,duration_ms:166300}), {summary:'HARD · 4/6 레벨',details:'처치 62 · 피격 3 · 시간 02:46'});
assert.deepEqual(formatPlayRecord({difficulty:'NORMAL',level:6,cleared:1,kills:0,hits:0,duration_ms:0}), {summary:'NORMAL · 전체 클리어',details:'처치 0 · 피격 0 · 시간 00:00'});
assert.deepEqual(formatPlayRecord({difficulty:'EASY'}), {summary:'EASY · 진행 —',details:'처치 — · 피격 — · 시간 —'});
assert.equal(formatPlayRecord({level:9,kills:-1,hits:NaN,duration_ms:-1}).details, '처치 — · 피격 — · 시간 —');
assert.equal(formatPlayRecord({duration_ms:3600000}).details, '처치 — · 피격 — · 시간 60:00');
console.log('play records: OK (difficulty, clear/stage, kills, hits, duration, missing legacy fields)');
