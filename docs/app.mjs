import {rankPlayers,formatPlayRecord} from './ranking.mjs';

const $ = id => document.getElementById(id);
const number = n => new Intl.NumberFormat('ko-KR').format(n);
let prizes = [], previous = new Map(), hasServerSnapshot = false;
const demo = new URLSearchParams(location.search).get('demo') === '1';
function el(tag, className, value) {const node=document.createElement(tag); if(className)node.className=className;if(value!==undefined)node.textContent=value;return node;}
function state(message, status='') { $('connection').textContent=message;$('connection').className=`connection ${status}`; }
function render(records=[]) {
  const top = rankPlayers(records), fragment = document.createDocumentFragment();
  prizes.forEach((prize,i)=>{
    const card=el('article',`prize-card ${i===0?'first':''}`), rank=el('div','prize-rank',`${i+1}등 상품`);
    rank.append(el('span','number',`0${i+1}`)); card.append(rank);
    card.append(el('h2','prize-name',prize.name),el('p','prize-value',prize.value));
    const r=top[i], winner=el('div',`winner ${r?'':'pending'}`);
    winner.append(el('p','winner-name',r?r.display_name:'도전자를 기다리는 중'));
    const score=el('p','winner-score',r?number(r.score):'—'); score.append(el('small','',r?'  POINTS':''));winner.append(score);card.append(winner);fragment.append(card);
  });
  $('podium').replaceChildren(fragment);
  const rows = document.createDocumentFragment();
  top.forEach((r,i)=>{
    const row=el('tr',i<3?'top-rank':'');
    if(previous.size && previous.get(r.participant_key)!==r.score)row.classList.add('changed');
    row.append(el('td','',String(i+1).padStart(2,'0')),el('td','',r.display_name));
    const play= formatPlayRecord(r), details=el('td','play-record');
    details.append(el('span','run-summary',play.summary),el('span','run-detail',play.details));
    row.append(details,el('td','',number(r.score)));
    rows.append(row);
  });
  $('participant-count').textContent=`${number(top.length)}명`;
  $('ranking-rows').replaceChildren(rows);$('empty-state').hidden=top.length>0;
  previous=new Map(top.map(r=>[r.participant_key,r.score]));
}
function renderBooths(booths) {
  const target=$('booth-list');target.replaceChildren();
  if(!booths.length){
    target.append(el('p','','현장에서 더 많은 동아리 게임을 만나보세요.'));return;
  }
  booths.forEach((b,i)=>{
    const card=el('article','booth-card'), team=el('div','team',b.team || '동아리 부스');team.append(el('span','',String(i+1).padStart(2,'0')));
    card.append(team,el('h3','',b.name || '동아리 게임'),el('p','',b.description || '현장에서 직접 만나보세요.'));
    if(b.location)card.append(el('span','location',b.location));target.append(card);
  });
}
$('fullscreen').addEventListener('click',async()=>{
  try { if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen(); }
  catch { $('fullscreen').textContent='F11로 전체 화면'; }
});
document.addEventListener('fullscreenchange',()=>{$('fullscreen').textContent=document.fullscreenElement?'전체 화면 종료':'전체 화면';});
window.addEventListener('offline',()=>state('연결 끊김 · 재연결 대기','error'));
window.addEventListener('online',()=>state('재연결 확인 중'));
try {
  const response=await fetch('./site-content.json',{cache:'no-cache'});if(!response.ok)throw new Error('content');
  const content=await response.json();prizes=content.prizes;renderBooths(content.booths);render();
  if(demo){
    state('미리보기 · 예시 기록');$('notice').textContent='화면 확인용 예시입니다. 실제 순위가 아닙니다.';$('notice').className='demo-banner';
    render(Array.from({length:30},(_,i)=>({id:String(i),participant_key:String(i),status:'finished',display_name:`학번 ${11001+i} · 예*자`,score:40000-i*1190,hits:i%6,finished_ms:i,difficulty:['HARD','NORMAL','EASY'][i%3],level:6-i%6,cleared:i%6===0?1:0,kills:80-i,duration_ms:(166+i*7)*1000})));
  } else {
    const [{initializeApp}, {getFirestore,collection,query,orderBy,onSnapshot}, config] = await Promise.all([
      import('https://www.gstatic.com/firebasejs/12.2.1/firebase-app.js'),
      import('https://www.gstatic.com/firebasejs/12.2.1/firebase-firestore.js'),
      fetch('./firebase-config.json').then(r=>{if(!r.ok)throw new Error('config');return r.json();})
    ]);
    const db=getFirestore(initializeApp(config));
    const ranking=query(collection(db,'doodlecast_runs'),orderBy('score','desc'));
    onSnapshot(ranking,{includeMetadataChanges:true},snapshot=>{
      if(snapshot.metadata.fromCache){state(hasServerSnapshot?'재연결 중 · 마지막 기록':'서버 기록 확인 중');return;}
      hasServerSnapshot=true;
      render(snapshot.docs.map(d=>({...d.data(),id:d.id,finished_ms:d.data().finished_at?.toMillis()??0})));
      state('실시간 연결됨','live');$('updated').textContent='마지막 수신 '+new Date().toLocaleTimeString('ko-KR',{hour12:false});
    },error=>{state('순위 연결 오류','error');$('notice').textContent='순위를 불러오지 못했습니다. 연결 확인 후 새로고침해 주세요.';console.error('Leaderboard:',error.code);});
  }
} catch(error){state('불러오기 실패','error');$('notice').textContent='안내를 불러오지 못했습니다. 잠시 후 새로고침해 주세요.';console.error(error.message);}
