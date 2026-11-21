import type { CameraZone, Job } from './model';
import { CAMERA_LABELS, type ParadiseDay } from './model';

function line(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, width = 2) {
  ctx.strokeStyle = color; ctx.lineWidth = width; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
}
function label(ctx: CanvasRenderingContext2D, text: string, x: number, y: number, color = '#211a25', size = 10) {
  ctx.fillStyle = color; ctx.font = 'bold ' + size + 'px monospace'; ctx.textAlign = 'center'; ctx.fillText(text, x, y);
}
function camera(ctx: CanvasRenderingContext2D, x: number, y: number, number: number, active: boolean, zone: CameraZone) {
  ctx.save(); ctx.translate(x, y);
  ctx.fillStyle = active ? '#c4e642' : '#251f2b'; ctx.strokeStyle = '#f8e9d4'; ctx.lineWidth = 2;
  ctx.fillRect(-9, -7, 14, 12); ctx.strokeRect(-9, -7, 14, 12);
  ctx.beginPath(); ctx.moveTo(5, -4); ctx.lineTo(12, -8); ctx.lineTo(12, 7); ctx.lineTo(5, 3); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#fff7e8'; ctx.beginPath(); ctx.arc(-2, -1, 1.6, 0, Math.PI * 2); ctx.fill();
  label(ctx, String(number) + (active ? ' ON' : ' OFF'), 0, 16, '#201a24', 7);
  label(ctx, CAMERA_LABELS[zone].replace(' CAM', ''), 0, 25, '#201a24', 6);
  ctx.restore();
}
function drawPerson(ctx: CanvasRenderingContext2D, x: number, y: number, shirt: string, active: boolean, phase: number, job: Job | null) {
  ctx.save(); ctx.translate(x, y);
  const stride = active ? Math.sin(phase) * 3 : 0;
  ctx.fillStyle = '#22202a'; ctx.beginPath(); ctx.ellipse(0, 2, 14, 4, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = shirt; ctx.fillRect(-7, -28, 14, 22);
  ctx.fillStyle = '#f0bd91'; ctx.beginPath(); ctx.arc(0, -36, 8, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#352532'; ctx.beginPath(); ctx.arc(-1, -39, 9, Math.PI, Math.PI * 2); ctx.fill();
  line(ctx, -4, -7, -5 + stride, 0, '#201a24', 3); line(ctx, 4, -7, 5 - stride, 0, '#201a24', 3);
  if (job === 'repair') { line(ctx, 7, -24, 17, -37 + Math.sin(phase) * (active ? 2 : 0), '#24212a', 3); }
  else if (job === 'feed') {
    ctx.fillStyle = '#b6713d'; ctx.fillRect(7, -22, 10, 8); line(ctx, 8, -19, 12, -12, '#24212a', 2);
  } else if (job === 'tend-garden' || job === 'draw-water') {
    line(ctx, 7, -22, 13, -12 + Math.sin(phase) * (active ? 2 : 0), '#24212a', 2);
  } else line(ctx, 7, -22, 12, -18, '#24212a', 2);
  ctx.restore();
}
function drawHen(ctx: CanvasRenderingContext2D, x: number, y: number, fed: boolean, time: number, reduced: boolean) {
  const bob = reduced ? 0 : Math.sin(time * 4 + x) * 1.5;
  ctx.save(); ctx.translate(x, y + bob);
  ctx.fillStyle = '#f7e1bd'; ctx.beginPath(); ctx.ellipse(0, 0, 11, 7, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#bb4f49'; ctx.beginPath(); ctx.arc(7, -6, 3, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#26202a'; ctx.beginPath(); ctx.arc(4, -2, 1.2, 0, Math.PI * 2); ctx.fill();
  line(ctx, -3, 6, -4, 10, '#594335', 1.5); line(ctx, 3, 6, 4, 10, '#594335', 1.5);
  if (fed) { ctx.fillStyle = '#e4af53'; ctx.beginPath(); ctx.arc(-7, 7, 2, 0, Math.PI * 2); ctx.fill(); }
  ctx.restore();
}
function drawZoneCone(ctx: CanvasRenderingContext2D, from: [number, number], to: [number, number], active: boolean) {
  if (!active) return;
  ctx.save(); ctx.globalAlpha = .2; ctx.fillStyle = '#b8df3d'; ctx.strokeStyle = '#354325'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(from[0], from[1]); ctx.lineTo(to[0] - 30, to[1] - 23);
  ctx.lineTo(to[0] + 30, to[1] - 23); ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.restore();
}
function drawTree(ctx: CanvasRenderingContext2D, x: number, y: number) {
  ctx.fillStyle = '#71513c'; ctx.fillRect(x - 4, y - 4, 8, 32);
  for (const [dx, dy, radius, color] of [[0, -19, 20, '#557b52'], [-12, -8, 14, '#66895a'], [13, -8, 14, '#73955c']] as const) {
    ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x + dx, y + dy, radius, 0, Math.PI * 2); ctx.fill();
  }
}
function drawCameraZone(ctx: CanvasRenderingContext2D, x: number, y: number, text: string, active: boolean) {
  ctx.fillStyle = active ? '#d7ff00' : '#fff5dc'; ctx.strokeStyle = '#443c40'; ctx.lineWidth = 1.5;
  ctx.fillRect(x - 35, y - 10, 70, 20); ctx.strokeRect(x - 35, y - 10, 70, 20);
  label(ctx, text + (active ? ' · ON' : ' · OFF'), x, y + 3, '#27212a', 7);
}
function drawStorm(ctx: CanvasRenderingContext2D, time: number, reduced: boolean) {
  ctx.fillStyle = 'rgba(40,50,66,.35)'; ctx.fillRect(0, 0, 640, 245);
  ctx.fillStyle = '#61646f';
  for (const x of [88, 128, 171, 216, 270, 325, 389, 445, 510, 574]) {
    ctx.beginPath(); ctx.arc(x, 54 + (x % 29), 20, Math.PI, 0); ctx.arc(x + 20, 59 + (x % 29), 16, Math.PI, 0); ctx.fill();
  }
  if (!reduced) {
    for (let n = 0; n < 26; n++) {
      const x = (n * 83 + time * (55 + n % 4) * 25) % 640;
      const y = (n * 37 + time * 190) % 238;
      line(ctx, x, y, x - 5, y + 11, '#b9ced7', 1);
    }
  }
  label(ctx, 'DAY 4 · STORM', 319, 53, '#fff7e8', 13);
}

export function drawYard(ctx: CanvasRenderingContext2D, width: number, height: number, game: ParadiseDay) {
  ctx.save(); ctx.scale(width / 640, height / 360); ctx.clearRect(0, 0, 640, 360);
  const sky = ctx.createLinearGradient(0, 0, 0, 250);
  sky.addColorStop(0, game.stormActive ? '#747784' : '#e8b187');
  sky.addColorStop(.72, game.stormActive ? '#a0a1a1' : '#f3d2a6');
  sky.addColorStop(1, game.stormActive ? '#b8b3a7' : '#d6bd98');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, 640, 360);

  ctx.fillStyle = game.stormActive ? '#697966' : '#8b9f93'; ctx.beginPath(); ctx.moveTo(0, 190); ctx.lineTo(90, 145); ctx.lineTo(163, 178);
  ctx.lineTo(254, 134); ctx.lineTo(338, 177); ctx.lineTo(430, 139); ctx.lineTo(538, 180); ctx.lineTo(640, 142); ctx.lineTo(640, 252); ctx.lineTo(0, 252); ctx.fill();
  ctx.fillStyle = '#3b3844'; ctx.fillRect(12, 114, 18, 72); ctx.fillRect(36, 90, 25, 96); ctx.fillRect(68, 128, 16, 58);
  ctx.fillStyle = '#d1e2a5'; ctx.fillRect(18, 128, 5, 7); ctx.fillRect(42, 110, 6, 6); ctx.fillRect(51, 110, 6, 6); ctx.fillRect(42, 128, 6, 6);
  label(ctx, 'GLITCHPORT', 48, 78, '#2b2734', 9);
  ctx.fillStyle = game.stormActive ? '#4c634b' : '#5e7850'; ctx.fillRect(0, 238, 640, 122);
  ctx.fillStyle = '#74925a'; ctx.fillRect(0, 238, 640, 7);
  ctx.fillStyle = '#c7a578'; ctx.fillRect(70, 253, 510, 22); ctx.fillStyle = '#8c6d50'; ctx.fillRect(0, 271, 640, 4);

  drawZoneCone(ctx, [119, 178], [158, 217], game.cameras.coop);
  drawZoneCone(ctx, [280, 178], [270, 242], game.cameras.garden);
  drawZoneCone(ctx, [344, 204], [343, 233], game.cameras.well);
  drawZoneCone(ctx, [427, 153], [434, 209], game.cameras.porch);
  drawZoneCone(ctx, [217, 237], [222, 247], game.cameras.workbench);
  drawZoneCone(ctx, [572, 160], [535, 169], game.stream && game.cameras['private-room']);

  ctx.strokeStyle = '#e0cba6'; ctx.lineWidth = 3;
  for (let x = 22; x < 620; x += 28) line(ctx, x, 230, x, 253, '#e0cba6', 2);
  line(ctx, 12, 234, 625, 234, '#e0cba6', 3); line(ctx, 12, 246, 625, 246, '#e0cba6', 2);
  drawTree(ctx, 91, 208);

  // One shared yard plate changes state through procedural layers in PAR-2.
  ctx.fillStyle = '#d2bba0'; ctx.strokeStyle = '#403843'; ctx.lineWidth = 3;
  ctx.fillRect(373, 108, 217, 129); ctx.strokeRect(373, 108, 217, 129);
  ctx.fillStyle = '#7a5446'; ctx.beginPath(); ctx.moveTo(357, 111); ctx.lineTo(480, 51); ctx.lineTo(607, 111); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#ac7459'; ctx.fillRect(394, 128, 36, 39); ctx.strokeRect(394, 128, 36, 39);
  ctx.fillStyle = '#20202a'; ctx.fillRect(504, 128, 59, 80); ctx.strokeStyle = '#eee0c9'; ctx.strokeRect(504, 128, 59, 80);
  ctx.fillStyle = '#26212b'; ctx.fillRect(492, 202, 86, 7); ctx.fillRect(492, 209, 86, 5);
  label(ctx, 'PORCH', 452, 225, '#332d34', 9);
  ctx.fillStyle = '#34303a'; ctx.fillRect(521, 139, 32, 62);
  ctx.strokeStyle = game.privateRoomShared ? '#bd5b2e' : '#25212b'; ctx.lineWidth = 3; ctx.strokeRect(521, 139, 32, 62);
  for (let y = 144; y < 197; y += 10) line(ctx, 522, y, 552, y + 8, '#b89ba1', 1);
  label(ctx, 'PRIVATE', 537, 216, '#2e2830', 8);

  // Day-four damage is visibly distinct, then the ordinary repair action braces the roof.
  ctx.fillStyle = game.stormActive && !game.coopRepaired ? '#6c5346' : game.coopRepaired ? '#b88358' : '#a77857';
  ctx.strokeStyle = '#352d33'; ctx.lineWidth = 3; ctx.fillRect(122, 187, 74, 51); ctx.strokeRect(122, 187, 74, 51);
  ctx.fillStyle = '#775342'; ctx.beginPath(); ctx.moveTo(111, 190);
  if (game.stormActive && !game.coopRepaired) { ctx.lineTo(146, 174); ctx.lineTo(158, 181); ctx.lineTo(176, 166); ctx.lineTo(208, 190); }
  else { ctx.lineTo(159, 163); ctx.lineTo(208, 190); }
  ctx.closePath(); ctx.fill(); ctx.stroke();
  if (game.coopRepaired) { line(ctx, 168, 170, 183, 188, '#e8d7ae', 5); label(ctx, 'BRACED', 160, 249, '#2f2830', 9); }
  else { line(ctx, 168, 171, 181, 183, '#372f32', 3); label(ctx, game.stormActive ? 'STORM DAMAGE' : 'LEAKING HINGE', 160, 249, '#2f2830', 7); }
  ctx.fillStyle = '#352f36'; ctx.fillRect(147, 207, 23, 31);
  drawHen(ctx, game.hensFed ? 178 : 200, 230, game.hensFed, game.time, game.reducedMotion);
  drawHen(ctx, game.hensFed ? 191 : 214, 231, game.hensFed, game.time, game.reducedMotion);

  // Garden state reacts to watering and carries a visible tomato setback on day three.
  ctx.fillStyle = '#795748'; ctx.fillRect(235, 226, 77, 20); ctx.fillStyle = game.gardenWatered ? '#6b984f' : '#5c824b';
  for (const x of [243, 262, 282, 300]) {
    ctx.fillRect(x, game.gardenWatered ? 203 : 209, 6, game.gardenWatered ? 24 : 18);
    ctx.fillRect(x - 5, game.gardenWatered ? 201 : 207, 16, 5);
  }
  if (game.tomatoActive || (game.dayNumber === 3 && game.tomatoChoice === 'keep')) {
    ctx.fillStyle = '#c94845'; for (const [x, y] of [[251, 211], [280, 205], [297, 214]] as const) { ctx.beginPath(); ctx.arc(x, y, 4, 0, Math.PI * 2); ctx.fill(); }
    label(ctx, 'TOMATO PROBLEM', 274, 198, '#4a282b', 7);
  }
  label(ctx, 'GARDEN', 274, 258, '#2d2830', 9);
  // Well, bucket and workbench have concrete, repeatable actions.
  ctx.fillStyle = '#6b665c'; ctx.fillRect(331, 213, 24, 30); ctx.fillStyle = '#b4c6bd'; ctx.fillRect(336, 221, 14, 12);
  line(ctx, 334, 212, 354, 212, '#403943', 2); ctx.strokeStyle = '#403943'; ctx.beginPath(); ctx.arc(343, 212, 12, Math.PI, Math.PI * 2); ctx.stroke();
  label(ctx, 'WELL', 343, 258, '#2d2830', 8);
  ctx.fillStyle = '#685141'; ctx.fillRect(205, 251, 29, 7); ctx.fillRect(204, 244, 4, 10);
  ctx.fillStyle = '#c49b69'; ctx.fillRect(209, 235, 12, 12); label(ctx, 'WORKBENCH', 219, 272, '#2d2830', 7);
  ctx.fillStyle = '#c49b69'; ctx.fillRect(194, 257, 10, 7); label(ctx, 'FEED', 215, 284, '#2d2830', 8);

  // All six camera views are labeled in-world; only selected public views show a coverage cone.
  camera(ctx, 119, 178, 1, game.cameras.coop, 'coop');
  camera(ctx, 280, 178, 2, game.cameras.garden, 'garden');
  camera(ctx, 344, 205, 3, game.cameras.well, 'well');
  camera(ctx, 427, 153, 4, game.cameras.porch, 'porch');
  camera(ctx, 218, 229, 5, game.cameras.workbench, 'workbench');
  camera(ctx, 572, 158, 6, game.stream && game.cameras['private-room'], 'private-room');
  drawCameraZone(ctx, 158, 264, '01 · COOP', game.cameras.coop);
  drawCameraZone(ctx, 274, 283, '02 · GARDEN', game.cameras.garden);
  drawCameraZone(ctx, 343, 274, '03 · WELL', game.cameras.well);
  drawCameraZone(ctx, 432, 264, '04 · PORCH', game.cameras.porch);
  drawCameraZone(ctx, 220, 302, '05 · WORKBENCH', game.cameras.workbench);
  drawCameraZone(ctx, 536, 264, '06 · PRIVATE', game.stream && game.cameras['private-room']);

  if (game.privateRevealActive) {
    ctx.fillStyle = '#9d856d'; ctx.fillRect(524, 142, 26, 56);
    ctx.fillStyle = '#3d6254'; ctx.fillRect(529, 162, 13, 23);
    ctx.fillStyle = '#d9bd8f'; ctx.fillRect(532, 145, 10, 9);
    label(ctx, 'SPONSORED CUTAWAY · AGREED', 539, 122, '#2c2430', 8);
    line(ctx, 429, 154, 536, 169, '#c43475', 2);
  } else if (game.privateRoomShared) label(ctx, 'ONE CUTAWAY SHARED', 537, 120, '#7a351f', 7);

  const animation = game.animation;
  const walking = Boolean(animation && animation.elapsed < animation.duration * 0.45);
  const phase = game.reducedMotion ? 0 : game.time * 10;
  drawPerson(ctx, game.actorX, 222, '#3e706b', walking, phase, animation?.job ?? null);
  drawPerson(ctx, 472, 222, '#aa526f', false, 0, null);
  ctx.fillStyle = '#22212a'; ctx.fillRect(451, 170, 10, 20); ctx.fillStyle = '#deff60'; ctx.strokeStyle = '#38303d';
  ctx.fillRect(447, 168, 19, 16); ctx.strokeRect(447, 168, 19, 16); label(ctx, 'ZERO', 456, 166, '#26202b', 7);

  if (game.stormActive) drawStorm(ctx, game.time, game.reducedMotion);
  if (game.stream) {
    ctx.fillStyle = '#c62847'; ctx.fillRect(266, 11, 77, 19); label(ctx, '● LIVE', 304, 24, '#fff5e9', 10);
  } else {
    ctx.fillStyle = '#27242d'; ctx.fillRect(266, 11, 77, 19); label(ctx, '■ OFFLINE', 304, 24, '#f4eadc', 9);
  }
  const meterX = 21;
  ctx.fillStyle = '#302b34'; ctx.fillRect(meterX, 20, 122, 10); ctx.fillRect(meterX + 133, 20, 122, 10);
  ctx.fillStyle = '#bce542'; ctx.fillRect(meterX, 20, 122 * game.homeCondition() / 100, 10);
  ctx.fillStyle = '#ed85aa'; ctx.fillRect(meterX + 133, 20, 122 * game.energy / 100, 10);
  label(ctx, 'HOME ' + game.homeCondition(), 82, 15, '#28222c', 8); label(ctx, 'ENERGY ' + game.energy, 215, 15, '#28222c', 8);
  ctx.restore();
}