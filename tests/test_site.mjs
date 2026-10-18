import assert from 'node:assert/strict';
import {rankPlayers} from '../docs/ranking.mjs';
const record=(id,participant_key,score,hits=0,finished_ms=1)=>({id,participant_key,score,hits,finished_ms,status:'finished'});
const records=[record('a','one',100,2),record('b','one',200,1),record('c','two',200,0,9),record('d','three',200,0,3),record('e','four',150)];
assert.deepEqual(rankPlayers(records).map(r=>r.id),['d','c','b','e']);
assert.equal(rankPlayers([{...records[0],status:'started'}]).length,0);
assert.equal(rankPlayers(Array.from({length:30},(_,i)=>record(String(i),String(i),i))).length,30);
console.log('site self-test: OK (best result, ties, all 30 participants)');

assert.equal(rankPlayers(Array.from({length:1000},(_,i)=>record(String(i),String(i),i))).at(-1).score,0);
