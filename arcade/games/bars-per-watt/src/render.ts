import type { RhythmSession } from './session';

const symbols = ['←', '↓', '↑', '→'];
export function drawHighway(ctx: CanvasRenderingContext2D, width: number, height: number,
  session: RhythmSession | null, time: number, palette: Record<string, string>,
  visualOffsetMs: number, contrast: boolean, reducedMotion: boolean, scrollSpeed = 1) {
  const w = Math.max(1, width), h = Math.max(1, height), laneW = w / 4;
  const strike = h * .80, speed = h * .48 * Math.max(.75, Math.min(1.75, scrollSpeed));
  const headH = Math.max(10, Math.min(laneW * .64, h * .075));
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
  // Receptor backgrounds sit behind notes; opaque foreground panels hid hold tails.
  for (let lane = 0; lane < 4; lane++) {
    ctx.fillStyle = session?.pressed.has(lane as 0 | 1 | 2 | 3) ? secondary : '#ffffff0c';
    ctx.globalAlpha = session?.pressed.has(lane as 0 | 1 | 2 | 3) ? .3 : 1;
    ctx.fillRect(lane * laneW + laneW * .08, strike - headH * .65, laneW * .84, headH * 1.3);
    ctx.globalAlpha = 1;
  }
  const songTime = time + visualOffsetMs / 1000;
  if (session) {
    for (const item of session.notes) {
      if (item.state === 'done' || item.state === 'missed') continue;
      const { lane, time: at, endTime } = item.note;
      const holding = item.state === 'holding';
      const y = holding ? strike : strike - (at - songTime) * speed, x = lane * laneW;
      let cap: number | undefined;
      if (endTime !== undefined) {
        const tail = Math.min(holding ? strike : Infinity, strike - (endTime - songTime) * speed);
        if (tail < h && y > -h) {
          ctx.fillStyle = holding ? secondary : accent;
          ctx.globalAlpha = .55; ctx.fillRect(x + laneW * .36, Math.max(0, tail), laneW * .28,
            Math.max(0, Math.min(h, y) - Math.max(0, tail))); ctx.globalAlpha = 1;
          cap = tail;
        }
      }
      if (y >= -headH && y <= h + headH) {
        ctx.fillStyle = holding ? secondary : accent;
        ctx.beginPath(); ctx.roundRect(x + laneW * .12, y - headH / 2, laneW * .76, headH, 4); ctx.fill();
        ctx.strokeStyle = holding ? '#ffffff' : '#111316'; ctx.lineWidth = holding ? 3 : 2; ctx.stroke();
        ctx.fillStyle = '#111316'; ctx.font = `900 ${Math.floor(Math.min(laneW * .5, headH * .95))}px system-ui`;
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillText(symbols[lane], x + laneW / 2, y - 1);
      }
      if (cap !== undefined && cap >= -headH && cap <= h + headH) {
        // A white outlined end cap remains visible as it reaches the held head.
        ctx.fillStyle = '#ffffff'; ctx.fillRect(x + laneW * .2, cap - 3, laneW * .6, 6);
        ctx.strokeStyle = '#111316'; ctx.lineWidth = 1;
        ctx.strokeRect(x + laneW * .2, cap - 3, laneW * .6, 6);
      }
    }
  }
  ctx.strokeStyle = contrast ? '#ffffff' : grid; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(0, strike); ctx.lineTo(w, strike); ctx.stroke();
  ctx.font = `900 ${Math.floor(Math.min(laneW * .45, headH * .85))}px system-ui`;
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  for (let lane = 0; lane < 4; lane++) {
    ctx.strokeStyle = contrast ? '#ffffff' : accent; ctx.lineWidth = 2;
    ctx.strokeRect(lane * laneW + laneW * .08, strike - headH * .65, laneW * .84, headH * 1.3);
    if (!session?.activeHolds.some(note => note.lane === lane)) {
      ctx.fillStyle = '#f4f1e7'; ctx.fillText(symbols[lane], lane * laneW + laneW / 2, strike);
    }
  }
  if (session?.latest && !reducedMotion && time - session.latestAt < .22) {
    ctx.fillStyle = secondary; ctx.fillRect(0, strike + headH * .8, w, 3);
  }
  if (!session) {
    ctx.fillStyle = accent; ctx.font = `900 ${Math.max(16, Math.floor(w / 18))}px system-ui`;
    ctx.textAlign = 'center'; ctx.fillText('THE HUMAN ZOO', w / 2, h * .25);
    ctx.fillStyle = '#d8d7d2'; ctx.font = `${Math.max(11, Math.floor(w / 30))}px monospace`;
    ctx.fillText('←   ↓   ↑   →', w / 2, h * .37);
  }
}
