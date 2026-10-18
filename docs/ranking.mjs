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
