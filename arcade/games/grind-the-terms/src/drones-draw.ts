import {
  courierDeck, eyeDipTime, eyeDisabledTime, eyeLens, eyePad, eyePadReady, eyeScan,
  eyeWarningTime, type CookieEye
} from './drones';

const ink = '#17121c';
const paper = '#f3e6cc';
const pink = '#ff3b9b';
const lime = '#d7ff00';
const gunmetal = '#554451';

export type SprayBurst = {
  from: { x: number; y: number };
  to: { x: number; y: number };
  left: number;
};

export function drawCourierDeck(ctx: CanvasRenderingContext2D, spriteX: number, top: number) {
  const left = spriteX + courierDeck.left;
  const width = courierDeck.right - courierDeck.left;
  ctx.save();
  for (const mount of [left + 10, left + width - 10]) {
    ctx.fillStyle = ink;
    ctx.beginPath();
    ctx.roundRect(mount - 5, top + 4, 10, 15, 2);
    ctx.fill();
    ctx.fillStyle = gunmetal;
    ctx.fillRect(mount - 3, top + 6, 6, 10);
    ctx.fillStyle = paper;
    ctx.fillRect(mount - 1, top + 12, 2, 2);
  }
  ctx.fillStyle = ink;
  ctx.fillRect(left, top, width, 9);
  ctx.fillStyle = lime;
  ctx.fillRect(left, top, width, 4);
  ctx.fillStyle = '#899b24';
  ctx.fillRect(left + 3, top + 4, width - 6, 2);
  ctx.fillStyle = '#eff5a8';
  ctx.fillRect(left + 5, top + 1, width - 10, 1);
  ctx.restore();
}

export function drawScanLane(ctx: CanvasRenderingContext2D, eye: CookieEye, playerX: number, ground: number) {
  if (eye.phase !== 'warning' && eye.phase !== 'scan') return;
  const firing = eye.phase === 'scan';
  const lane = eyeScan(eye, playerX, ground);
  const lens = eyeLens(eye);
  const w = lane.right - lane.left, h = lane.bottom - lane.top;
  if (w <= 0) return;
  ctx.save();
  ctx.fillStyle = firing ? 'rgba(255,59,155,.53)' : 'rgba(255,59,155,.16)';
  ctx.fillRect(lane.left, lane.top, w, h);
  ctx.strokeStyle = ink;
  ctx.lineWidth = 5;
  ctx.strokeRect(lane.left, lane.top, w, h);
  ctx.strokeStyle = firing ? paper : pink;
  ctx.lineWidth = firing ? 3 : 2;
  if (!firing) ctx.setLineDash([8, 5]);
  ctx.strokeRect(lane.left, lane.top, w, h);
  ctx.setLineDash([]);
  ctx.strokeStyle = pink;
  ctx.beginPath();
  ctx.moveTo(lens.x, lens.y);
  ctx.lineTo(lane.right, lane.top + h / 2);
  ctx.stroke();
  if (firing) {
    ctx.strokeStyle = paper;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(lane.left, lane.top + h / 2);
    ctx.lineTo(lane.right, lane.top + h / 2);
    ctx.stroke();
  }
  ctx.restore();
}

export function drawCookieEye(ctx: CanvasRenderingContext2D, eye: CookieEye, ground: number, elapsed: number, reducedMotion: boolean, jamInRange: boolean) {
  const {x, top, phase, age, jammed} = eye;
  const disabled = phase === 'disabled';
  const alpha = disabled ? Math.max(0, 1 - age / eyeDisabledTime) : 1;
  const brightLens = phase === 'warning' || phase === 'scan';
  const irisY = eyeLens(eye).y - top;
  ctx.save();
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  ctx.globalAlpha *= alpha;
  ctx.fillStyle = 'rgba(15,9,17,.33)';
  ctx.beginPath();
  ctx.ellipse(x, ground - 1, 28, 4, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.translate(x, top);
  if (disabled && !reducedMotion) ctx.rotate(.23 + age * .7);
  ctx.strokeStyle = ink;
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.moveTo(-20, 10);ctx.lineTo(-32, -2);ctx.lineTo(-32, -8);
  ctx.moveTo(21, 10);ctx.lineTo(31, -3);ctx.lineTo(31, -8);
  ctx.stroke();
  const rotorFrame = reducedMotion || disabled ? 0 : Math.floor(elapsed * 18) % 4;
  const blades = [19, 14, 9, 14];
  for (const [i, rotorX] of [-32, 31].entries()) {
    ctx.fillStyle = ink;
    ctx.beginPath();ctx.ellipse(rotorX, -8, blades[(rotorFrame + i) % 4], 4, 0, 0, Math.PI * 2);ctx.fill();
    ctx.strokeStyle = paper;
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.fillStyle = disabled ? '#8e795b' : pink;
    ctx.fillRect(rotorX - 5, -8, 10, 3);
  }

  ctx.fillStyle = '#b7a686';
  ctx.strokeStyle = ink;
  ctx.lineWidth = 3;
  ctx.beginPath();ctx.roundRect(-24, 1, 48, 29, [8, 6, 10, 9]);ctx.fill();ctx.stroke();
  ctx.fillStyle = paper;
  ctx.fillRect(-9, 4, 24, 5);
  ctx.fillStyle = gunmetal;
  ctx.fillRect(-1, 13, 22, 12);
  ctx.fillStyle = '#241922';
  for (let vent = 2; vent < 20; vent += 5) ctx.fillRect(vent, 15, 2, 7);
  ctx.fillStyle = pink;
  ctx.fillRect(14, 5, 7, 4);

  // The pad telescopes out of the bracket bolted to the top of the hull.
  if (phase === 'recover') {
    const pad = eyePad(eye);
    const right = pad.right - x;
    const width = (pad.right - pad.left) * Math.min(1, age / eyeDipTime);
    const left = right - width;
    ctx.fillStyle = ink;
    ctx.beginPath();
    ctx.moveTo(left, 0);ctx.lineTo(right, 0);ctx.lineTo(right, 15);
    ctx.lineTo(left, 8);ctx.closePath();ctx.fill();
    ctx.fillStyle = gunmetal;
    ctx.fillRect(left, 4, width, 3);
    ctx.fillStyle = eyePadReady(eye) ? lime : '#a5a779';
    ctx.fillRect(left, 0, width, 4);
    ctx.fillStyle = '#eff5a8';
    if (width > 8) ctx.fillRect(left + 4, 1, width - 8, 1);
    ctx.fillStyle = '#97854a';
    for (let notch = left + 7; notch < right - 10; notch += 10) ctx.fillRect(notch, 5, 3, 2);
  }
  ctx.fillStyle = ink;
  ctx.fillRect(-10, 4, 21, 9);
  ctx.fillStyle = gunmetal;
  ctx.fillRect(-8, 6, 17, 5);
  ctx.fillStyle = paper;
  ctx.fillRect(-6, 7, 2, 2);
  ctx.fillRect(5, 7, 2, 2);

  ctx.fillStyle = ink;
  ctx.beginPath();ctx.ellipse(-15, 17, 11, 10, 0, 0, Math.PI * 2);ctx.fill();
  ctx.fillStyle = disabled ? '#6f6874' : jammed ? lime : brightLens ? pink : '#8b3b71';
  ctx.beginPath();ctx.ellipse(-16, irisY, brightLens ? 7.5 : 6.5, 6.5, 0, 0, Math.PI * 2);ctx.fill();
  if (!disabled && !jammed) {
    ctx.fillStyle = paper;
    ctx.fillRect(-19, irisY - 4, 3, 3);
    if (jamInRange) {
      ctx.strokeStyle = lime;
      ctx.lineWidth = 1.5;
      ctx.beginPath();ctx.arc(-16, irisY, 12, 0, Math.PI * 2);ctx.stroke();
    }
  }
  if (jammed) {
    ctx.fillStyle = lime;
    ctx.fillRect(-23, 17, 12, 4);ctx.fillRect(-18, 19, 3, 8);ctx.fillRect(-24, 13, 4, 4);
  }
  if (disabled && eye.stomped && !reducedMotion) {
    for (let i = 0; i < 5; i++) {
      ctx.fillStyle = i % 2 ? paper : lime;
      ctx.fillRect(-22 - age * (24 + i * 12), -age * (15 + i * 13) + i * 2, 4, 3);
    }
  }
  ctx.restore();
}

export function drawSprayJam(ctx: CanvasRenderingContext2D, burst: SprayBurst, reducedMotion: boolean) {
  const {from, to, left} = burst;
  ctx.save();
  ctx.globalAlpha *= Math.min(1, left / .20);
  ctx.fillStyle = 'rgba(215,255,0,.42)';
  ctx.beginPath();ctx.moveTo(from.x, from.y);ctx.lineTo(to.x - 4, to.y - 9);ctx.lineTo(to.x + 4, to.y + 9);ctx.closePath();ctx.fill();
  for (let i = 1; i <= (reducedMotion ? 5 : 12); i++) {
    const t = i / (reducedMotion ? 5 : 12);
    ctx.fillStyle = i % 3 ? lime : paper;
    ctx.fillRect(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t + Math.sin(i * 13) * 8 * t, 3, 3);
  }
  ctx.restore();
}

export function drawEyeCallout(ctx: CanvasRenderingContext2D, x: number, y: number, label: string, color: 'warning' | 'open', eye?: CookieEye) {
  ctx.save();
  ctx.font = '900 15px monospace';
  const width = ctx.measureText(label).width + 20;
  const accent = color === 'warning' ? pink : lime;
  ctx.fillStyle = ink;
  ctx.fillRect(x, y, width, 25);
  ctx.fillStyle = accent;
  ctx.fillRect(x, y, 3, 25);
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText(label, x + 10, y + 12);
  if (eye?.phase === 'warning') ctx.fillRect(x + 3, y + 23, (width - 3) * (1 - eye.age / eyeWarningTime), 2);
  ctx.restore();
}
