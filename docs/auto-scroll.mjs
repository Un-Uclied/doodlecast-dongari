export function startAutoScroll(button, regions) {
  if (!button) return;
  const desktop = matchMedia('(min-width: 851px)');
  let enabled = !matchMedia('(prefers-reduced-motion: reduce)').matches;
  const label = () => {
    button.textContent = enabled ? '자동 스크롤 멈추기' : '자동 스크롤 켜기';
    button.setAttribute('aria-pressed', String(enabled));
  };
  button.addEventListener('click', () => { enabled = !enabled; label(); });
  label();

  for (const [element, speed] of regions) {
    if (!element) continue;
    let position = element.scrollTop, direction = 1, previous = null;
    let holdUntil = performance.now() + 4000;
    const pause = () => { holdUntil = performance.now() + 8000; };
    for (const event of ['pointerenter', 'pointermove', 'pointerdown', 'wheel', 'keydown', 'focusin']) {
      element.addEventListener(event, pause, {passive: true});
    }
    function frame(now) {
      const elapsed = previous === null ? 0 : Math.min((now - previous) / 1000, 0.1);
      previous = now;
      const limit = Math.max(0, element.scrollHeight - element.clientHeight);
      if (limit <= 1) {
        position = 0; direction = 1; holdUntil = now + 4000;
      } else if (!enabled || !desktop.matches || document.hidden || now < holdUntil) {
        position = element.scrollTop;
      } else {
        position = Math.max(0, Math.min(position, limit)) + direction * speed * elapsed;
        if (position >= limit || position <= 0) {
          position = Math.max(0, Math.min(position, limit));
          direction *= -1;
          holdUntil = now + 4000;
        }
        element.scrollTop = position;
      }
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }
}
