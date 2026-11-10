import type { RhythmSession } from './session';

const symbols = ['←', '↓', '↑', '→'];
export function drawHighway(ctx: CanvasRenderingContext2D, width: number, height: number,
  session: RhythmSession | null, time: number, palette: Record<string, string>,
  visualOffsetMs: number, contrast: boolean, reducedMotion: boolean) {
  const w = Math.max(1, width), h = Math.max(1, height), laneW = w / 4;
  const strike = h * .78, speed = h * .48;
  const bg = palette.bg || '#111319', grid = contrast ? '#ffffff' : palette.grid || '#4d5360';
  const accent = palette.accent || '#d7ff00', secondary = palette.secondary || '#e0287a';
  ctx.clearRect(0, 0, w, h);
  const gradient = ctx.createLinearGradient(0, 0, 0, h);
  gradient.addColorStop(0, '#080b13'); gradient.addColorStop(1, bg);
  ctx.fillStyle = gradient; ctx.fillRect(0, 0, w, h);
  for (let lane = 0; lane < 4; lane++) {
    ctx.fillStyle = lane % 2 ? '#ffffff09' : '#ffffff03';
    ctx.fillRect(lane * laneW, 0, laneW, h);
    ctx.strokeStyle = grid; ctx.lineWidth = contrast ? 3 : 1;
    ctx.beginPath(); ctx.moveTo(lane * laneW, 0); ctx.lineTo(lane * laneW, h); ctx.stroke();
  }
  ctx.strokeStyle = grid; ctx.beginPath(); ctx.moveTo(w - 1, 0); ctx.lineTo(w - 1, h); ctx.stroke();
  const songTime = time + visualOffsetMs / 1000;
  if (session) {
    for (const item of session.notes) {
      if (item.state === 'done' || item.state === 'missed') continue;
      const { lane, time: at, endTime } = item.note;
      const y = strike - (at - songTime) * speed, x = lane * laneW;
      if (endTime !== undefined) {
        const tail = strike - (endTime - songTime) * speed;
        if (tail < h && y > -h) {
          ctx.fillStyle = item.state === 'holding' ? secondary : accent;
          ctx.globalAlpha = .55; ctx.fillRect(x + laneW * .36, Math.max(0, tail), laneW * .28,
            Math.max(0, Math.min(h, y) - Math.max(0, tail))); ctx.globalAlpha = 1;
          ctx.fillStyle = secondary; ctx.fillRect(x + laneW * .22, tail - 4, laneW * .56, 8);
        }
      }
      if (y < -laneW || y > h + laneW) continue;
      ctx.fillStyle = item.state === 'holding' ? secondary : accent;
      ctx.beginPath(); ctx.roundRect(x + laneW * .12, y - laneW * .35, laneW * .76, laneW * .7, 6); ctx.fill();
      ctx.strokeStyle = '#111316'; ctx.lineWidth = 2; ctx.stroke();
      ctx.fillStyle = '#111316'; ctx.font = `900 ${Math.floor(laneW * .5)}px system-ui`;
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(symbols[lane], x + laneW / 2, y - 1);
    }
  }
  ctx.fillStyle = '#0a0d15'; ctx.fillRect(0, strike - laneW * .4, w, laneW * .8);
  ctx.strokeStyle = accent; ctx.lineWidth = Math.max(3, w / 110);
  ctx.beginPath(); ctx.moveTo(0, strike + laneW * .42); ctx.lineTo(w, strike + laneW * .42); ctx.stroke();
  ctx.font = `900 ${Math.floor(laneW * .45)}px system-ui`;
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  for (let lane = 0; lane < 4; lane++) {
    ctx.strokeStyle = contrast ? '#ffffff' : accent; ctx.lineWidth = 2;
    ctx.strokeRect(lane * laneW + laneW * .12, strike - laneW * .35, laneW * .76, laneW * .7);
    ctx.fillStyle = '#f4f1e7'; ctx.fillText(symbols[lane], lane * laneW + laneW / 2, strike);
  }
  if (session?.latest && !reducedMotion && time - session.latestAt < .22) {
    ctx.fillStyle = secondary; ctx.fillRect(0, strike + laneW * .48, w, 3);
  }
  if (!session) {
    ctx.fillStyle = accent; ctx.font = `900 ${Math.max(16, Math.floor(w / 18))}px system-ui`;
    ctx.textAlign = 'center'; ctx.fillText('THE HUMAN ZOO', w / 2, h * .25);
    ctx.fillStyle = '#d8d7d2'; ctx.font = `${Math.max(11, Math.floor(w / 30))}px monospace`;
    ctx.fillText('←   ↓   ↑   →', w / 2, h * .37);
  }
}
