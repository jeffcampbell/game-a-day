// Forest Quest - Game Runtime Stub
// This is a stub for the exported game. For full gameplay, use pico8 viewer or pixel-dashboard.

(function() {
  const canvas = document.getElementById('game');
  const ctx = canvas ? canvas.getContext('2d') : null;

  if (ctx) {
    // Draw a simple placeholder
    ctx.fillStyle = '#2a8b4b';
    ctx.fillRect(0, 0, 128, 128);

    ctx.fillStyle = '#fff';
    ctx.font = '8px monospace';
    ctx.fillText('Forest Quest', 30, 40);
    ctx.fillText('Open in PICO-8', 25, 55);
    ctx.fillText('or pixel-dashboard', 15, 70);
  }
})();
