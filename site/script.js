// Low Load site - small, quiet interactions.
// 1) copy-to-clipboard for the install command
// 2) scroll reveal (respects reduced motion; content stays visible with no JS)

// Mark JS active so the reveal animation can hide content; without this class,
// CSS keeps everything visible (no-JS safe).
document.documentElement.classList.add('js');

(function copyButtons() {
  document.querySelectorAll('.copy-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const text = btn.getAttribute('data-copy') || '';
      const label = btn.querySelector('.copy-label');
      try {
        await navigator.clipboard.writeText(text);
      } catch {
        const ta = document.createElement('textarea');
        ta.value = text; document.body.appendChild(ta); ta.select();
        try { document.execCommand('copy'); } catch {}
        ta.remove();
      }
      const prev = label ? label.textContent : '';
      btn.classList.add('copied');
      if (label) label.textContent = 'copied ✓';
      setTimeout(() => {
        btn.classList.remove('copied');
        if (label) label.textContent = prev || 'copy';
      }, 1400);
    });
  });
})();

(function reveal() {
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const items = document.querySelectorAll('.reveal');
  if (reduce || !('IntersectionObserver' in window)) {
    items.forEach((el) => el.classList.add('in'));
    return;
  }
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.06 });
  items.forEach((el) => io.observe(el));
})();
