(async function() {
  await Promise.all(['header','footer'].map(async id => {
    const res = await fetch(id + '.html');
    const html = await res.text();
    document.getElementById(id + '-placeholder').innerHTML = html;
  }));

  const path = window.location.pathname.replace(/\/$/, '');
  const filename = path.split('/').pop().replace(/\.html$/, '') || 'index';
  document.querySelectorAll('nav a').forEach(a => {
    const link = a.getAttribute('href').replace(/\.html$/, '');
    if (link === filename) {
      a.classList.add('active');
    }
  });

  // Theme handled via CSS prefers-color-scheme

  // Setup tooltips
  document.querySelectorAll('.hover-image').forEach(el => {
    // Accessibility improvements
    el.setAttribute('tabindex', '0');
    el.setAttribute('role', 'button');
    el.setAttribute('aria-expanded', 'false');

    el.addEventListener('click', e => {
      e.stopPropagation();
      adjustTooltipPosition(el);
      const isActive = el.classList.toggle('active');
      el.setAttribute('aria-expanded', isActive);
    });

    el.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        e.stopPropagation();
        adjustTooltipPosition(el);
        const isActive = el.classList.toggle('active');
        el.setAttribute('aria-expanded', isActive);
      }
    });

    el.addEventListener('mouseenter', () => adjustTooltipPosition(el));
  });
  document.addEventListener('click', () =>
    document.querySelectorAll('.hover-image').forEach(el => el.classList.remove('active'))
  );
})();

function adjustTooltipPosition(el) {
  const tt = el.querySelector('.hover-img');

  // Lazy load image: only set src from data-src when the tooltip is first shown
  if (tt.dataset.src && !tt.src) {
    // Check if we are already loading
    if (tt.dataset.loading) return;

    tt.dataset.loading = "true";
    tt.style.visibility = 'hidden'; // Hide while loading

    const img = new Image();
    img.onload = () => {
        tt.src = tt.dataset.src;
        delete tt.dataset.loading;
        tt.style.visibility = '';
        adjustTooltipPosition(el);
    };
    img.onerror = () => {
        // If loading fails, show the broken image/alt text
        tt.src = tt.dataset.src;
        delete tt.dataset.loading;
        tt.style.visibility = '';
        adjustTooltipPosition(el);
    };
    img.src = tt.dataset.src;
    return;
  }

  // If still loading (async race condition where adjustTooltipPosition called again), wait
  if (tt.dataset.loading) {
      tt.style.visibility = 'hidden';
      return;
  }

  tt.style.display = 'block'; tt.style.visibility = 'hidden';
  const t = tt.getBoundingClientRect(), e = el.getBoundingClientRect();
  const spaces = { bottom: window.innerHeight-e.bottom, top: e.top, right: window.innerWidth-e.right, left: e.left };
  const dirs = ['bottom','top','right','left'];
  const feasible = dirs.filter(d =>
    ['bottom','top'].includes(d) ? spaces[d]>=t.height : spaces[d]>=t.width
  );
  const dir = feasible.length
    ? feasible.reduce((a,b)=>spaces[a]>spaces[b]?a:b)
    : dirs.reduce((a,b)=>spaces[a]>spaces[b]?a:b);
  el.classList.remove(...dirs); el.classList.add(dir);
  tt.style.visibility = ''; tt.style.display = '';
}