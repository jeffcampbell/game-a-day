// Lane Racer - PICO-8 Game Stub
// This is a placeholder JS file generated in a headless environment
// For full interactive play, use: python3 tools/run-interactive-test.py 2026-03-22

(function() {
  const canvas = document.getElementById('canvas');
  const ctx = canvas.getContext('2d');

  function drawPlaceholder() {
    ctx.fillStyle = '#222';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.fillStyle = '#fff';
    ctx.font = 'bold 32px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('Lane Racer', canvas.width/2, canvas.height/2 - 40);

    ctx.font = '16px Arial';
    ctx.fillStyle = '#888';
    ctx.fillText('Stub HTML - Use run-interactive-test.py to play', canvas.width/2, canvas.height/2);
  }

  drawPlaceholder();
})();
