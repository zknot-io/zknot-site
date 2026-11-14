// Click (or Enter/Space) on a product photo to view it full size. Esc, click or tap closes.
// Opt in per image container with class "prod-img". 2026-11-14.
(function () {
  var css = document.createElement('style');
  css.textContent =
    '.prod-img img{cursor:zoom-in}' +
    '.prod-img img:focus-visible{outline:2px solid var(--accent,#38bdf8);outline-offset:3px}' +
    '.zoom-ov{position:fixed;inset:0;z-index:1000;display:flex;align-items:center;justify-content:center;' +
    'padding:max(16px,env(safe-area-inset-top)) 16px max(16px,env(safe-area-inset-bottom));' +
    'background:rgba(4,6,8,.92);cursor:zoom-out}' +
    '.zoom-ov img{width:auto;height:auto;max-width:calc(100vw - 32px);max-height:calc(100dvh - 96px);object-fit:contain;box-shadow:0 10px 40px rgba(0,0,0,.6)}' +
    '.zoom-ov .zoom-x{position:absolute;top:max(14px,env(safe-area-inset-top));right:16px;font:500 12px/1 var(--mono,monospace);' +
    'letter-spacing:.1em;text-transform:uppercase;color:#cbd5e1;background:none;border:1px solid #334155;padding:8px 12px;cursor:pointer}';
  document.head.appendChild(css);

  var ov = null, last = null;
  function close() {
    if (!ov) return;
    ov.remove(); ov = null;
    document.documentElement.style.overflow = '';
    if (last) last.focus();
  }
  function open(img) {
    last = img;
    ov = document.createElement('div');
    ov.className = 'zoom-ov';
    ov.setAttribute('role', 'dialog');
    ov.setAttribute('aria-modal', 'true');
    ov.setAttribute('aria-label', img.alt || 'Photo');
    var big = document.createElement('img');
    big.src = img.currentSrc || img.src;
    big.alt = img.alt || '';
    var x = document.createElement('button');
    x.className = 'zoom-x'; x.type = 'button'; x.textContent = 'Close ✕';
    ov.appendChild(big); ov.appendChild(x);
    ov.addEventListener('click', close);
    document.body.appendChild(ov);
    document.documentElement.style.overflow = 'hidden';
    x.focus();
  }
  document.addEventListener('keydown', function (e) {
    if (ov && (e.key === 'Escape' || e.key === 'Tab')) { e.preventDefault(); if (e.key === 'Escape') close(); }
  });
  document.querySelectorAll('.prod-img img').forEach(function (img) {
    img.tabIndex = 0;
    img.setAttribute('role', 'button');
    img.setAttribute('aria-label', 'View larger: ' + (img.alt || 'photo'));
    img.addEventListener('click', function () { open(img); });
    img.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(img); }
    });
  });
})();
