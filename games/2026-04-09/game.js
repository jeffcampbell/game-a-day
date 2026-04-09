// PICO-8 Game Runtime (Stub)
// Full export requires X11 display - game.p8 is the source

console.log("Dice Dueler - PICO-8 game");
document.addEventListener('DOMContentLoaded', function() {
  const canvas = document.getElementById('game');
  if (canvas) {
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, 128, 128);
    ctx.fillStyle = '#fff';
    ctx.font = '8px monospace';
    ctx.fillText('PICO-8 GAME', 20, 60);
    ctx.fillText('(Full export requires X11)', 10, 75);
  }
});
