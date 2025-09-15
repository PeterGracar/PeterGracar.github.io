(async function() {
  await Promise.all(['header','footer'].map(async id => {
    const res = await fetch(id + '.html');
    const html = await res.text();
    document.getElementById(id + '-placeholder').innerHTML = html;
  }));

  const filename = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('nav a').forEach(a => {
    if (a.getAttribute('href') === filename) {
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