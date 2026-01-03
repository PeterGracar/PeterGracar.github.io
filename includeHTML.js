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
    el.addEventListener('click', e => {
      e.stopPropagation();
      adjustTooltipPosition(el);
      el.classList.toggle('active');
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
  // This prevents downloading large images until they are actually needed.
  if (tt.dataset.src && !tt.src) {
    tt.src = tt.dataset.src;
  }

  // If the image is still loading, wait for it to complete.
  // This prevents the tooltip from appearing at the wrong position (0x0 size)
  // and then jumping when the image loads.
  if (tt.dataset.src && !tt.complete) {
    tt.style.visibility = 'hidden';
    // Ensure we only attach the listener once
    if (!tt.hasAttribute('data-loading-listener')) {
      tt.setAttribute('data-loading-listener', 'true');
      tt.addEventListener('load', () => {
        tt.removeAttribute('data-loading-listener');
        tt.style.visibility = ''; // Unhide so positioning logic can run/show it
        adjustTooltipPosition(el);
      }, { once: true });
    }
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