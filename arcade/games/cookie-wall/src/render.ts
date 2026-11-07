import { COURT, PADDLE, type Brick, type Kind } from './board';
import type { CookieWallGame } from './game';
import type { Skin } from './skin';

const hue: Record<Kind, string> = { necessary: 'safe', partners: 'hazard', interest: 'interest', reject: 'danger' };
export const highContrast = { bg: '#08090b', panel: '#111216', court: '#090a0e', grid: '#474850',
  ink: '#ffffff', dark: '#000000', muted: '#ffffff', accent: '#ffff72', safe: '#ffffff', hazard: '#ffdb70', interest: '#abdfff', danger: '#ffafd4' };

function brickFace(ctx: CanvasRenderingContext2D, brick: Brick, art: Skin, colors: Record<string, string>, contrast: boolean) {
  const { x, y, w, h, kind } = brick;
  const cracked = brick.hp === 1 && (kind === 'interest' || kind === 'reject');
  const frame = art.frames['brick_' + kind + (cracked ? '_crack_00' : '_idle_00')];
  if (frame && !contrast) { ctx.drawImage(frame, x, y, w, h); return; }

  // High-contrast fallback retains a distinct symbol as well as a distinct label in the legend.
  ctx.fillStyle = colors.dark; ctx.fillRect(x, y, w, h);
  ctx.fillStyle = colors[hue[kind]]; ctx.fillRect(x + 1, y + 1, w - 2, h - 2);
  ctx.fillStyle = colors.ink; ctx.fillRect(x + 2, y + 1, w - 4, 1);
  ctx.fillStyle = colors.dark; ctx.fillRect(x + 2, y + h - 2, w - 4, 1);
  const cx = x + w / 2, cy = y + h / 2;
  ctx.strokeStyle = colors.dark; ctx.fillStyle = colors.ink; ctx.lineWidth = 1.6;
  if (kind === 'necessary') {
    ctx.beginPath(); ctx.arc(cx, cy - 2, 3.5, Math.PI, 0); ctx.stroke();
    ctx.fillRect(cx - 4, cy - 1, 8, 6); ctx.fillStyle = colors.dark; ctx.fillRect(cx - 1, cy, 2, 3);
  } else if (kind === 'partners') {
    ctx.beginPath(); ctx.moveTo(x + 12, cy); ctx.lineTo(cx, cy - 3); ctx.lineTo(x + 22, cy); ctx.stroke();
    for (const [nx, ny] of [[x + 12, cy], [cx, cy - 3], [x + 22, cy]]) {
      ctx.beginPath(); ctx.arc(nx, ny, 2.4, 0, Math.PI * 2); ctx.fillStyle = colors.ink; ctx.fill();
      ctx.strokeStyle = colors.dark; ctx.stroke();
    }
  } else if (kind === 'interest') {
    ctx.beginPath(); ctx.ellipse(cx, cy, 6, 3.5, 0, 0, Math.PI * 2); ctx.fillStyle = colors.ink; ctx.fill(); ctx.stroke();
    ctx.beginPath(); ctx.arc(cx, cy, 2, 0, Math.PI * 2); ctx.fillStyle = colors.dark; ctx.fill();
  } else {
    ctx.strokeStyle = colors.ink; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(cx - 4, cy - 4); ctx.lineTo(cx + 4, cy + 4);
    ctx.moveTo(cx + 4, cy - 4); ctx.lineTo(cx - 4, cy + 4); ctx.stroke();
  }
  if (cracked) {
    ctx.strokeStyle = colors.dark; ctx.lineWidth = 2; ctx.beginPath();
    ctx.moveTo(x + w * .72, y); ctx.lineTo(x + w * .58, y + 4); ctx.lineTo(x + w * .67, y + 6);
    ctx.lineTo(x + w * .51, y + 9); ctx.stroke();
  }
}

export function drawCourt(ctx: CanvasRenderingContext2D, width: number, height: number, world: CookieWallGame, skin: Skin,
  reduced: boolean, contrast: boolean) {
  const colors = contrast ? highContrast : skin.palette;
  ctx.save(); ctx.setTransform(width / COURT, 0, 0, height / COURT, 0, 0);
  ctx.fillStyle = colors.court; ctx.fillRect(0, 0, COURT, COURT);
  if (skin.frames.bg_court_00 && !contrast) ctx.drawImage(skin.frames.bg_court_00, 0, 0, COURT, COURT);
  else {
    ctx.strokeStyle = colors.grid; ctx.lineWidth = .5; ctx.beginPath();
    for (let unit = 0; unit <= COURT; unit += 20) {
      ctx.moveTo(unit, 0); ctx.lineTo(unit, COURT); ctx.moveTo(0, unit); ctx.lineTo(COURT, unit);
    }
    ctx.stroke();
    ctx.fillStyle = colors.muted;
    for (let y = 10; y < COURT; y += 10) {
      const tick = y % 50 === 0 ? 5 : 2;
      ctx.fillRect(0, y, tick, 1); ctx.fillRect(COURT - tick, y, tick, 1);
    }
  }
  ctx.fillStyle = colors.danger;
  for (let x = 0; x < COURT; x += 12) ctx.fillRect(x, COURT - 1.5, 6, 1.5);
  for (const brick of world.bricks) if (brick.hp > 0) brickFace(ctx, brick, skin, colors, contrast);
  if (world.burst && world.burst.until > world.time) {
    const { x, y, w, h, kind, until } = world.burst;
    const progress = Math.max(0, Math.min(1, 1 - (until - world.time) / .22));
    const frameIndex = reduced ? 0 : Math.min(2, Math.floor(progress * 3));
    const frame = skin.frames[`brick_${kind}_break_0${frameIndex}`];
    if (frame && !contrast) ctx.drawImage(frame, x - w / 2, y - h / 2, w, h);
    if (!reduced) {
      ctx.globalAlpha = 1 - progress; ctx.fillStyle = colors.accent;
      for (let i = 0; i < 4; i++) {
        const angle = Math.PI / 4 + i * Math.PI / 2;
        const fragment = contrast ? undefined : skin.frames['fx_crumb_0' + ((i + Math.floor(progress * 4)) % 4)];
        const fx = x + Math.cos(angle) * progress * 18 - 4;
        const fy = y + Math.sin(angle) * progress * 13 - 4;
        if (fragment) ctx.drawImage(fragment, fx, fy, 8, 8);
        else ctx.fillRect(fx + 3, fy + 3, 2, 2);
      }
      ctx.globalAlpha = 1;
    }
  }
  const px = world.paddleX - PADDLE.width / 2, py = PADDLE.y - PADDLE.height / 2;
  const paddleHitAge = world.time - world.lastPaddleHit;
  const paddleHitFrame = paddleHitAge >= 0 && paddleHitAge < 2 / 12 ? Math.min(1, Math.floor(paddleHitAge * 12)) : -1;
  const blocker = paddleHitFrame >= 0 ? skin.frames['blocker_hit_0' + paddleHitFrame] : skin.frames.blocker_idle_00;
  if (blocker) ctx.drawImage(blocker, px, PADDLE.y - 8, 64, 16);
  else {
    ctx.fillStyle = colors.accent; ctx.fillRect(px, py, PADDLE.width, PADDLE.height);
    ctx.fillStyle = colors.dark; ctx.fillRect(px + 2, py + 3, PADDLE.width - 4, 6);
    ctx.fillStyle = colors.accent;
    for (let i = 0; i < 3; i++) ctx.fillRect(px + 5 + i * 3, py + 4, 1, 4);
    ctx.fillRect(px + 51, py + 5, 7, 2);
  }
  if (skin.strings.patch) {
    const patchFrame = paddleHitFrame >= 0 ? 'blocker_ad_hit_0' + Math.min(1, paddleHitFrame) : 'blocker_ad_idle_00';
    if (skin.frames[patchFrame]) ctx.drawImage(skin.frames[patchFrame], px, PADDLE.y - 8, 64, 16);
    ctx.fillStyle = colors.ink; ctx.font = 'bold 9px monospace'; ctx.textAlign = 'center';
    ctx.fillText(skin.strings.patch, world.paddleX, PADDLE.y + 3);
  }
  if ((world.phase === 'leaking' || world.phase === 'over') && skin.frames.tracker_idle_00) {
    const age = Math.max(0, world.time - world.leakAt);
    const frame = reduced ? 0 : Math.floor(age * 4) % 2;
    const tracker = skin.frames['tracker_idle_0' + frame] ?? skin.frames.tracker_idle_00;
    ctx.drawImage(tracker, Math.max(0, Math.min(COURT - 32, world.packet.x - 16)), COURT - 24, 32, 24);
  }
  const ball = world.packet;
  if (world.phase === 'docked') {
    ctx.strokeStyle = colors.accent; ctx.lineWidth = 1; ctx.setLineDash([3, 4]); ctx.beginPath();
    ctx.moveTo(ball.x, ball.y); ctx.lineTo(ball.x + Math.sin(world.aim) * 42, ball.y - Math.cos(world.aim) * 42);
    ctx.stroke(); ctx.setLineDash([]);
  }
  if (world.phase !== 'leaking' && world.phase !== 'over') {
    const frame = skin.frames['packet_spin_0' + (reduced ? 0 : Math.floor(world.time * 8) % 4)] ?? skin.frames.packet_spin_00;
    if (frame) ctx.drawImage(frame, ball.x - 6, ball.y - 6, 12, 12);
    else {
      ctx.fillStyle = colors.ink; ctx.beginPath(); ctx.arc(ball.x, ball.y, 4, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = colors.dark; ctx.fillRect(ball.x - 1.3, ball.y - 1.3, 2.6, 2.6);
    }
  }
  ctx.restore();
}
