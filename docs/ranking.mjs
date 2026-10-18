export function rankPlayers(records) {
  const ordered = records.filter(r => r.status === 'finished' && Number.isSafeInteger(r.score) && r.score >= 0 && typeof r.participant_key === 'string');
  ordered.sort((a,b) => b.score-a.score || a.hits-b.hits || a.finished_ms-b.finished_ms || a.id.localeCompare(b.id));
  const seen = new Set();
  return ordered.filter(r => {
    if(seen.has(r.participant_key)) return false;
    seen.add(r.participant_key);
    return true;
  });
}

export function formatPlayRecord(record) {
  const stage = record.cleared === 1 ? '전체 클리어' : (Number.isInteger(record.level) && record.level >= 1 && record.level <= 6 ? `${record.level}/6 레벨` : '진행 —');
  const count = value => Number.isSafeInteger(value) && value >= 0 ? new Intl.NumberFormat('ko-KR').format(value) : '—';
  let time = '—';
  if (Number.isSafeInteger(record.duration_ms) && record.duration_ms >= 0) {
    const seconds = Math.floor(record.duration_ms / 1000);
    time = `${String(Math.floor(seconds / 60)).padStart(2,'0')}:${String(seconds % 60).padStart(2,'0')}`;
  }
  return {summary: `${record.difficulty || '—'} · ${stage}`, details: `처치 ${count(record.kills)} · 피격 ${count(record.hits)} · 시간 ${time}`};
}
