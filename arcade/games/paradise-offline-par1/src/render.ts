import type { CameraZone, Job } from './model';
import { CAMERA_LABELS, type ParadiseDay } from './model';
import type { SkinImages } from './skin';

const ZONES: Array<{ zone: CameraZone; x: number; y: number; aimX: number; aimY: number }> = [
  { zone: 'coop', x: .79, y: .42, aimX: .80, aimY: .59 },
  { zone: 'garden', x: .82, y: .73, aimX: .75, aimY: .84 },
  { zone: 'well', x: .15, y: .71, aimX: .19, aimY: .80 },
  { zone: 'porch', x: .28, y: .36, aimX: .32, aimY: .56 },
  { zone: 'workbench', x: .67, y: .79, aimX: .64, aimY: .87 },
  { zone: 'private-room', x: .69, y: .32, aimX: .62, aimY: .39 }
];

function label(ctx: CanvasRenderingContext2D, text: string, x: number, y: number, color = '#211a25', size = 10) {
  ctx.fillStyle = color; ctx.font = '900 ' + size + 'px monospace'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText(text, x, y);
}
function line(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, width = 2) {
  ctx.strokeStyle = color; ctx.lineWidth = width; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
}
function drawCover(ctx: CanvasRenderingContext2D, image: CanvasImageSource, width: number, height: number) {
  const source = image as ImageBitmap;
  const scale = Math.max(width / source.width, height / source.height);
  const sw = width / scale, sh = height / scale;
  const sx = (source.width - sw) / 2, sy = (source.height - sh) / 2;
  ctx.drawImage(source, sx, sy, sw, sh, 0, 0, width, height);
}
function drawFallback(ctx: CanvasRenderingContext2D, width: number, height: number, game: ParadiseDay) {
  const sky = ctx.createLinearGradient(0, 0, 0, height);
  sky.addColorStop(0, game.stormActive ? '#777983' : '#e8b187');
  sky.addColorStop(.58, game.stormActive ? '#9c9d9f' : '#eac79c');
  sky.addColorStop(1, game.stormActive ? '#52634d' : '#6e8d57');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = '#33303a'; ctx.fillRect(width * .07, height * .27, width * .28, height * .34);
  ctx.fillStyle = '#a87355'; ctx.beginPath(); ctx.moveTo(width * .04, height * .29); ctx.lineTo(width * .21, height * .12); ctx.lineTo(width * .38, height * .29); ctx.fill();
  ctx.fillStyle = '#a24e46'; ctx.fillRect(width * .68, height * .37, width * .22, height * .28);
  ctx.fillStyle = '#5e7850'; ctx.fillRect(0, height * .65, width, height * .35);
}
function drawSprite(ctx: CanvasRenderingContext2D, sheet: ImageBitmap, index: number, x: number, y: number, w: number, h: number) {
  const cellW = sheet.width / 4, cellH = sheet.height / 2;
  const col = index % 4, row = Math.floor(index / 4);
  ctx.drawImage(sheet, col * cellW, row * cellH, cellW, cellH, x - w / 2, y - h, w, h);
}
function cameraCone(ctx: CanvasRenderingContext2D, x: number, y: number, tx: number, ty: number, active: boolean) {
  if (!active) return;
  ctx.save(); ctx.globalAlpha = .23; ctx.fillStyle = '#d7ff00'; ctx.strokeStyle = '#20311d'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(tx - 30, ty); ctx.lineTo(tx + 30, ty); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.restore();
}
function cameraTag(ctx: CanvasRenderingContext2D, number: number, name: string, x: number, y: number, active: boolean, privateZone: boolean, fontScale: number) {
  const text = String(number).padStart(2, '0') + ' ' + name;
  const w = Math.max(52, (text.length * 5.4 + 16) * fontScale), h = 20 * fontScale;
  ctx.fillStyle = privateZone ? (active ? '#ff4382' : '#f6eddf') : (active ? '#d7ff00' : '#211a25');
  ctx.strokeStyle = '#211a25'; ctx.lineWidth = 1.5;
  ctx.fillRect(x - w / 2, y - h / 2, w, h); ctx.strokeRect(x - w / 2, y - h / 2, w, h);
  label(ctx, text, x, y, privateZone && active ? '#1b0d16' : (active || privateZone ? '#211a25' : '#fff8e8'), 8 * fontScale);
}
function drawStorm(ctx: CanvasRenderingContext2D, width: number, height: number, time: number, reduced: boolean) {
  ctx.fillStyle = 'rgba(31,38,50,.28)'; ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = '#5f626e';
  for (let i = 0; i < 8; i++) {
    const x = width * (i + .5) / 8, y = height * (.09 + (i % 3) * .025), r = Math.max(14, width * .035);
    ctx.beginPath(); ctx.arc(x, y, r, Math.PI, 0); ctx.arc(x + r * .65, y + 2, r * .78, Math.PI, 0); ctx.fill();
  }
  if (!reduced) {
    for (let n = 0; n < 24; n++) {
      const x = (n * 83 + time * (42 + n % 4) * 25) % width;
      const y = (n * 37 + time * 170) % height;
      line(ctx, x, y, x - 5, y + 11, '#d1e0e6', 1);
    }
  }
  label(ctx, 'DAY 4 · STORM', width * .5, height * .19, '#fff8eb', Math.max(10, width * .022));
}
function drawMeters(ctx: CanvasRenderingContext2D, width: number, game: ParadiseDay, palette: Record<string, string>) {
  const left = width * .035, top = Math.max(26, width * .03), barW = width * .22, barH = Math.max(7, width * .015);
  ctx.fillStyle = 'rgba(24,21,30,.84)'; ctx.fillRect(left - 6, top - 19, barW * 2 + 98, 39);
  ctx.fillStyle = '#302b34'; ctx.fillRect(left, top, barW, barH); ctx.fillRect(left + barW + 38, top, barW, barH);
  ctx.fillStyle = palette.accent || '#d7ff00'; ctx.fillRect(left, top, barW * game.homeCondition() / 100, barH);
  ctx.fillStyle = '#ed85aa'; ctx.fillRect(left + barW + 38, top, barW * game.energy / 100, barH);
  label(ctx, 'HOME ' + game.homeCondition(), left + barW / 2, top - 7, '#fff8eb', Math.max(7, width * .012));
  label(ctx, 'ENERGY ' + game.energy, left + barW + 38 + barW / 2, top - 7, '#fff8eb', Math.max(7, width * .012));
}
function taskFrame(job: Job | null, walking: boolean): number {
  if (job === 'repair') return 2;
  if (job === 'tend-garden') return 3;
  if (job === 'draw-water') return 6;
  if (job === 'cook') return 7;
  if (walking) return 1;
  return 0;
}

export function drawYard(ctx: CanvasRenderingContext2D, width: number, height: number, game: ParadiseDay,
  skin: SkinImages | null, palette: Record<string, string>) {
  const portrait = height > width;
  const scale = Math.min(width / 640, height / 360);
  const base = portrait ? skin?.portrait : skin?.landscape;
  if (base) drawCover(ctx, base, width, height);
  else drawFallback(ctx, width, height, game);

  const placements = ZONES.map(z => ({
    ...z,
    x: z.x * width, y: z.y * height, aimX: z.aimX * width, aimY: z.aimY * height
  }));
  for (const zone of placements) cameraCone(ctx, zone.x, zone.y, zone.aimX, zone.aimY, game.cameras[zone.zone] && (zone.zone !== 'private-room' || game.stream));

  if (skin) {
    const pw = portrait ? width * .18 : width * .12;
    const ph = portrait ? height * .12 : height * .23;
    drawSprite(ctx, skin.props, 0, width * .80, height * .61, pw, ph);
    drawSprite(ctx, skin.props, 1, width * .81, height * .55, pw * 1.25, ph * .9);
    drawSprite(ctx, skin.props, 2, width * .79, height * .76, pw * 1.2, ph * .95);
    drawSprite(ctx, skin.props, 3, width * .16, height * .76, pw, ph);
    drawSprite(ctx, skin.props, game.gardenWatered ? 4 : 5, width * .73, height * .84, pw * .78, ph * .62);
    if (game.coopRepaired) drawSprite(ctx, skin.props, 6, width * .78, height * .64, pw * .62, ph * .5);
    if (game.slotsUsed && game.jobsToday.includes('cook')) drawSprite(ctx, skin.props, 7, width * .32, height * .46, pw * .75, ph * .55);

    const animation = game.animation;
    const walking = Boolean(!game.reducedMotion && animation && animation.elapsed < animation.duration * .45);
    const frame = taskFrame(animation?.job ?? null, walking);
    const actorX = width * (.15 + (game.actorX / 640) * .7);
    const actorY = height * (portrait ? .68 : .74);
    const actorW = portrait ? width * .20 : width * .12;
    const actorH = portrait ? height * .15 : height * .30;
    drawSprite(ctx, skin.actors, frame, actorX, actorY, actorW, actorH);
    drawSprite(ctx, skin.actors, 4, width * .86, height * (portrait ? .68 : .74), actorW, actorH);
  }

  const fontScale = portrait ? Math.max(.8, Math.min(1.12, width / 390)) : Math.max(.75, Math.min(1.15, width / 640));
  for (let i = 0; i < placements.length; i++) {
    const zone = placements[i], privateZone = zone.zone === 'private-room';
    const active = game.cameras[zone.zone] && (!privateZone || game.stream);
    const shortName = zone.zone === 'workbench' ? 'BENCH' : zone.zone === 'private-room' ? (active ? 'PRIVATE · ON AIR' : 'PRIVATE · OFF') : zone.zone.toUpperCase();
    cameraTag(ctx, i + 1, shortName, zone.x, zone.y, active, privateZone, fontScale);
  }

  if (game.privateRevealActive) {
    const x = width * (portrait ? .63 : .70), y = height * (portrait ? .34 : .36);
    ctx.fillStyle = 'rgba(157,133,109,.92)'; ctx.fillRect(x - width * .045, y - height * .045, width * .09, height * .11);
    ctx.strokeStyle = '#d7ff00'; ctx.lineWidth = Math.max(1, scale * 2); ctx.strokeRect(x - width * .045, y - height * .045, width * .09, height * .11);
    label(ctx, 'SPONSOR CUTAWAY · AGREED', x, y - height * .065, '#fff8e8', Math.max(7, width * .012));
  }
  if (game.stormActive) drawStorm(ctx, width, height, game.time, game.reducedMotion);
  ctx.fillStyle = game.stream ? '#b82c4a' : '#26222d';
  ctx.fillRect(width * .43, Math.max(12, height * .025), width * .15, Math.max(18, height * .05));
  label(ctx, game.stream ? '● LIVE' : '■ OFFLINE', width * .505, Math.max(21, height * .05), '#fff8e8', Math.max(8, width * .017));
  drawMeters(ctx, width, game, palette);
}
