import {
  courierDeck, eyeDisabledTime, eyeLens, eyePad, eyePadHinge, eyeScan,
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

function drawEyeFallback(ctx: CanvasRenderingContext2D) {
  ctx.strokeStyle = ink;
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.moveTo(-20, 10);ctx.lineTo(-34, 1);ctx.lineTo(-34, -5);
  ctx.moveTo(20, 10);ctx.lineTo(34, 1);ctx.lineTo(34, -5);
  ctx.stroke();
  for (const rotorX of [-34, 34]) {
    ctx.fillStyle = gunmetal;
    ctx.beginPath();ctx.ellipse(rotorX, -5, 19, 3.5, 0, 0, Math.PI * 2);ctx.fill();
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.fillStyle = pink;
    ctx.fillRect(rotorX - 5, -1, 10, 4);
  }
  ctx.fillStyle = '#b7a686';
  ctx.lineWidth = 3;
  ctx.beginPath();ctx.roundRect(-29, 3, 58, 27, [8, 6, 10, 9]);ctx.fill();ctx.stroke();
  ctx.fillStyle = gunmetal;
  ctx.fillRect(2, 13, 20, 12);
  ctx.fillStyle = ink;
  for (let vent = 5; vent < 20; vent += 5) ctx.fillRect(vent, 15, 2, 7);
  ctx.beginPath();ctx.arc(-13, 18.5, 9, 0, Math.PI * 2);ctx.fill();
  ctx.fillStyle = pink;
  ctx.beginPath();ctx.arc(-13, 18.5, 5.5, 0, Math.PI * 2);ctx.fill();
  ctx.fillStyle = ink;
  ctx.beginPath();ctx.arc(-13, 18.5, 2.5, 0, Math.PI * 2);ctx.fill();
  ctx.fillStyle = paper;
  ctx.fillRect(-12, 15, 2, 2);
}

function drawEyePad(ctx: CanvasRenderingContext2D, eye: CookieEye) {
  const pad = eyePad(eye);
  const left = pad.left - eye.x, right = pad.right - eye.x, y = pad.y - eye.top;
  const width = right - left;
  const hinge = eyePadHinge;
  if (width > 0) {
    const elbowX = (right + hinge.x) / 2;
    const elbowY = y + 12;
    ctx.beginPath();
    ctx.moveTo(hinge.x, hinge.y);ctx.lineTo(elbowX, elbowY);ctx.lineTo(right - 3, y + 5);
    ctx.strokeStyle = ink;ctx.lineWidth = 10;ctx.stroke();
    ctx.strokeStyle = '#85707b';ctx.lineWidth = 6;ctx.stroke();
    ctx.fillStyle = paper;
    ctx.fillRect(elbowX - 1, elbowY - 1, 2, 2);

    // The painted edge and board contact share pad.y when the arm locks.
    ctx.fillStyle = ink;
    ctx.beginPath();
    ctx.moveTo(left, y);ctx.lineTo(right, y);ctx.lineTo(right, y + 9);
    ctx.lineTo(left + Math.min(4, width), y + 9);ctx.lineTo(left, y + 5);
    ctx.closePath();ctx.fill();
    ctx.fillStyle = pad.ready ? lime : '#ad9a77';
    ctx.fillRect(left, y, width, 4);
    if (width > 10) {
      ctx.fillStyle = pad.ready ? '#f2ffac' : paper;
      ctx.fillRect(left + 3, y + 1, width - 6, 1);
      ctx.fillStyle = '#85707b';
      for (let bolt = left + 6; bolt < right - 4; bolt += 10) ctx.fillRect(bolt, y + 5, 3, 2);
    }
  }

  // The hub stays on the hull while the arm articulates.
  ctx.fillStyle = ink;
  ctx.beginPath();ctx.arc(hinge.x, hinge.y, 5.5, 0, Math.PI * 2);ctx.fill();
  ctx.fillStyle = '#b7a486';
  ctx.beginPath();ctx.arc(hinge.x, hinge.y, 3.5, 0, Math.PI * 2);ctx.fill();
  ctx.fillStyle = gunmetal;
  ctx.fillRect(hinge.x - 2, hinge.y - .6, 4, 1.2);
}

export function drawCookieEye(ctx: CanvasRenderingContext2D, eye: CookieEye, ground: number, elapsed: number, reducedMotion: boolean, sprite?: HTMLImageElement) {
  const {x, top, phase, age, jammed} = eye;
  const disabled = phase === 'disabled';
  const aiming = phase === 'warning' || phase === 'scan';
  ctx.save();
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  if (disabled) ctx.globalAlpha *= Math.max(0, 1 - age / eyeDisabledTime);
  ctx.fillStyle = 'rgba(15,9,17,.33)';
  ctx.beginPath();ctx.ellipse(x, ground - 1, 28, 4, 0, 0, Math.PI * 2);ctx.fill();

  ctx.translate(x, top);
  if (disabled && !reducedMotion) ctx.rotate(age * 1.5);
  if (sprite) ctx.drawImage(sprite, -54, -11, 108, 42.75);
  else drawEyeFallback(ctx);

  if (!disabled && !reducedMotion) {
    ctx.strokeStyle = 'rgba(243,230,204,.45)';
    ctx.lineWidth = .8;
    for (const rotor of [-34, 34]) {
      const spin = Math.sin(elapsed * 38 + rotor) * 11;
      ctx.beginPath();ctx.moveTo(rotor + spin - 4, -5.5);ctx.lineTo(rotor + spin + 5, -5);ctx.stroke();
    }
  }
  if (aiming) {
    const irisY = eyeLens(eye).y - top;
    ctx.strokeStyle = phase === 'scan' ? paper : pink;
    ctx.lineWidth = phase === 'scan' ? 2 : 1.4;
    const sweep = phase === 'scan' ? 1 : Math.min(1, age / eyeWarningTime);
    ctx.beginPath();ctx.arc(-13, 18.5, 8, -Math.PI / 2, -Math.PI / 2 + sweep * Math.PI * 2);ctx.stroke();
    ctx.fillStyle = paper;
    ctx.fillRect(-14.5, irisY - 1, 3, 2);
  }
  if (disabled) {
    ctx.fillStyle = '#342c37';
    ctx.beginPath();ctx.ellipse(-13, 18.5, 5.6, 5.2, 0, 0, Math.PI * 2);ctx.fill();
  }
  if (jammed && !disabled) {
    ctx.fillStyle = lime;
    ctx.fillRect(-20, 17, 11, 3);ctx.fillRect(-17, 18, 3, 6);ctx.fillRect(-21, 13, 3, 3);
  }
  drawEyePad(ctx, eye);
  if (disabled && eye.stomped && !reducedMotion) {
    for (let i = 0; i < 5; i++) {
      ctx.fillStyle = i % 2 ? paper : lime;
      ctx.fillRect(-22 - age * (24 + i * 12), -age * (15 + i * 13) + i * 2, 4, 3);
    }
  }
  ctx.restore();
}

export function drawStompCue(ctx: CanvasRenderingContext2D, pad: ReturnType<typeof eyePad>) {
  if (!pad.ready) return;
  const x = pad.right - 10, y = pad.y + 15;
  ctx.save();
  ctx.fillStyle = ink;
  ctx.fillRect(x - 24.5, y, 49, 17);
  ctx.fillStyle = lime;
  ctx.beginPath();ctx.moveTo(x - 3, y);ctx.lineTo(x, y - 4);ctx.lineTo(x + 3, y);ctx.fill();
  ctx.font = '900 11px monospace';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('STOMP', x, y + 8.5);
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
