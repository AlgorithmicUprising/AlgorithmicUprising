import type { CameraZone, Job } from './model';
import { CAMERA_LABELS, type ParadiseDay } from './model';

const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(high, value));

function line(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, width = 2) {
  ctx.strokeStyle = color; ctx.lineWidth = width; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
}
function label(ctx: CanvasRenderingContext2D, text: string, x: number, y: number, color = '#211a25', size = 10) {
  ctx.fillStyle = color; ctx.font = 'bold ' + size + 'px monospace'; ctx.textAlign = 'center'; ctx.fillText(text, x, y);
}
function camera(ctx: CanvasRenderingContext2D, x: number, y: number, number: number, active: boolean, zone: CameraZone) {
  ctx.save();
  ctx.translate(x, y);
  ctx.fillStyle = active ? '#c4e642' : '#251f2b';
  ctx.strokeStyle = '#f8e9d4'; ctx.lineWidth = 2;
  ctx.fillRect(-11, -8, 17, 14); ctx.strokeRect(-11, -8, 17, 14);
  ctx.beginPath(); ctx.moveTo(6, -5); ctx.lineTo(14, -10); ctx.lineTo(14, 8); ctx.lineTo(6, 3); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#fff7e8'; ctx.beginPath(); ctx.arc(-3, -1, 2, 0, Math.PI * 2); ctx.fill();
  label(ctx, String(number) + (active ? ' ON' : ' OFF'), 0, 18, '#201a24', 8);
  ctx.restore();
}
function drawPerson(ctx: CanvasRenderingContext2D, x: number, y: number, shirt: string, active: boolean, phase: number, job: Job | null) {
  ctx.save(); ctx.translate(x, y);
  const stride = active ? Math.sin(phase) * 3 : 0;
  ctx.fillStyle = '#22202a';
  ctx.beginPath(); ctx.ellipse(0, 2, 14, 4, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = shirt;
  ctx.fillRect(-7, -28, 14, 22);
  ctx.fillStyle = '#f0bd91'; ctx.beginPath(); ctx.arc(0, -36, 8, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#352532'; ctx.beginPath(); ctx.arc(-1, -39, 9, Math.PI, Math.PI * 2); ctx.fill();
  line(ctx, -4, -7, -5 + stride, 0, '#201a24', 3); line(ctx, 4, -7, 5 - stride, 0, '#201a24', 3);
  if (job === 'repair') line(ctx, 7, -24, 17, -37 + Math.sin(phase) * (active ? 2 : 0), '#24212a', 3);
  else if (job === 'feed') {
    ctx.fillStyle = '#b6713d'; ctx.fillRect(7, -22, 10, 8); line(ctx, 8, -19, 12, -12, '#24212a', 2);
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
  ctx.save(); ctx.globalAlpha = .23; ctx.fillStyle = '#b8df3d'; ctx.strokeStyle = '#354325'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(from[0], from[1]); ctx.lineTo(to[0] - 34, to[1] - 28);
  ctx.lineTo(to[0] + 34, to[1] - 28); ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.restore();
}
function drawTree(ctx: CanvasRenderingContext2D, x: number, y: number) {
  ctx.fillStyle = '#71513c'; ctx.fillRect(x - 4, y - 4, 8, 32);
  for (const [dx, dy, radius, color] of [[0, -19, 20, '#557b52'], [-12, -8, 14, '#66895a'], [13, -8, 14, '#73955c']] as const) {
    ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x + dx, y + dy, radius, 0, Math.PI * 2); ctx.fill();
  }
}
function drawCameraZone(ctx: CanvasRenderingContext2D, x: number, y: number, text: string) {
  ctx.fillStyle = '#fff5dc'; ctx.strokeStyle = '#443c40'; ctx.lineWidth = 1.5;
  ctx.fillRect(x - 35, y - 10, 70, 20); ctx.strokeRect(x - 35, y - 10, 70, 20);
  label(ctx, text, x, y + 3, '#27212a', 8);
}

export function drawYard(ctx: CanvasRenderingContext2D, width: number, height: number, game: ParadiseDay) {
  ctx.save(); ctx.scale(width / 640, height / 360); ctx.clearRect(0, 0, 640, 360);
  const sky = ctx.createLinearGradient(0, 0, 0, 250);
  sky.addColorStop(0, '#e8b187'); sky.addColorStop(.72, '#f3d2a6'); sky.addColorStop(1, '#d6bd98');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, 640, 360);

  ctx.fillStyle = '#8b9f93'; ctx.beginPath(); ctx.moveTo(0, 190); ctx.lineTo(90, 145); ctx.lineTo(163, 178);
  ctx.lineTo(254, 134); ctx.lineTo(338, 177); ctx.lineTo(430, 139); ctx.lineTo(538, 180); ctx.lineTo(640, 142); ctx.lineTo(640, 252); ctx.lineTo(0, 252); ctx.fill();
  ctx.fillStyle = '#3b3844'; ctx.fillRect(12, 114, 18, 72); ctx.fillRect(36, 90, 25, 96); ctx.fillRect(68, 128, 16, 58);
  ctx.fillStyle = '#d1e2a5'; ctx.fillRect(18, 128, 5, 7); ctx.fillRect(42, 110, 6, 6); ctx.fillRect(51, 110, 6, 6); ctx.fillRect(42, 128, 6, 6);
  label(ctx, 'GLITCHPORT', 48, 78, '#2b2734', 9);
  ctx.fillStyle = '#5e7850'; ctx.fillRect(0, 238, 640, 122);
  ctx.fillStyle = '#74925a'; ctx.fillRect(0, 238, 640, 7);
  ctx.fillStyle = '#c7a578'; ctx.fillRect(70, 253, 510, 22);
  ctx.fillStyle = '#8c6d50'; ctx.fillRect(0, 271, 640, 4);

  // Camera coverage is deliberately limited to the three public yard zones.
  drawZoneCone(ctx, [119, 178], [158, 217], game.cameras.coop);
  drawZoneCone(ctx, [280, 178], [270, 242], game.cameras.garden);
  drawZoneCone(ctx, [427, 153], [434, 209], game.cameras.porch);

  // Fence and shared yard props.
  ctx.strokeStyle = '#e0cba6'; ctx.lineWidth = 3;
  for (let x = 22; x < 620; x += 28) { line(ctx, x, 230, x, 253, '#e0cba6', 2); }
  line(ctx, 12, 234, 625, 234, '#e0cba6', 3); line(ctx, 12, 246, 625, 246, '#e0cba6', 2);
  drawTree(ctx, 91, 208);

  // The farmhouse and porch stay constant across every day in the full plan.
  ctx.fillStyle = '#d2bba0'; ctx.strokeStyle = '#403843'; ctx.lineWidth = 3;
  ctx.fillRect(373, 108, 217, 129); ctx.strokeRect(373, 108, 217, 129);
  ctx.fillStyle = '#7a5446'; ctx.beginPath(); ctx.moveTo(357, 111); ctx.lineTo(480, 51); ctx.lineTo(607, 111); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#ac7459'; ctx.fillRect(394, 128, 36, 39); ctx.strokeRect(394, 128, 36, 39);
  ctx.fillStyle = '#20202a'; ctx.fillRect(504, 128, 59, 80); ctx.strokeStyle = '#eee0c9'; ctx.strokeRect(504, 128, 59, 80);
  ctx.fillStyle = '#26212b'; ctx.fillRect(492, 202, 86, 7); ctx.fillRect(492, 209, 86, 5);
  label(ctx, 'PORCH', 452, 225, '#332d34', 9);

  // Coop: leaky state changes into a braced state after the repair action.
  ctx.fillStyle = game.coopRepaired ? '#b88358' : '#a77857'; ctx.strokeStyle = '#352d33'; ctx.lineWidth = 3;
  ctx.fillRect(122, 187, 74, 51); ctx.strokeRect(122, 187, 74, 51);
  ctx.fillStyle = '#775342'; ctx.beginPath(); ctx.moveTo(111, 190); ctx.lineTo(159, 163); ctx.lineTo(208, 190); ctx.closePath(); ctx.fill(); ctx.stroke();
  if (!game.coopRepaired) { line(ctx, 168, 171, 181, 183, '#372f32', 3); label(ctx, 'LEAKING HINGE', 160, 249, '#2f2830', 8); }
  else { line(ctx, 168, 170, 183, 188, '#e8d7ae', 5); label(ctx, 'BRACED', 160, 249, '#2f2830', 9); }
  ctx.fillStyle = '#352f36'; ctx.fillRect(147, 207, 23, 31);
  drawHen(ctx, game.hensFed ? 178 : 200, 230, game.hensFed, game.time, game.reducedMotion);
  drawHen(ctx, game.hensFed ? 191 : 214, 231, game.hensFed, game.time, game.reducedMotion);

  // Garden, well, and workbench are present but their chores arrive in PAR-2.
  ctx.fillStyle = '#795748'; ctx.fillRect(235, 226, 77, 20); ctx.fillStyle = '#5c824b';
  for (const x of [243, 262, 282, 300]) { ctx.fillRect(x, 209, 6, 18); ctx.fillRect(x - 5, 207, 16, 5); }
  label(ctx, 'GARDEN', 274, 258, '#2d2830', 9);
  ctx.fillStyle = '#6b665c'; ctx.fillRect(331, 213, 24, 30); ctx.fillStyle = '#b4c6bd'; ctx.fillRect(336, 221, 14, 12);
  line(ctx, 334, 212, 354, 212, '#403943', 2); label(ctx, 'WELL', 343, 258, '#2d2830', 8);
  ctx.fillStyle = '#685141'; ctx.fillRect(205, 251, 29, 7); ctx.fillRect(204, 244, 4, 10);
  ctx.fillStyle = '#c49b69'; ctx.fillRect(209, 235, 12, 12); label(ctx, 'FEED', 215, 272, '#2d2830', 8);

  // Camera symbols and their coverage labels remain readable without color.
  camera(ctx, 119, 178, 1, game.cameras.coop, 'coop');
  camera(ctx, 280, 178, 2, game.cameras.garden, 'garden');
  camera(ctx, 427, 153, 3, game.cameras.porch, 'porch');
  drawCameraZone(ctx, 158, 264, '01 · COOP'); drawCameraZone(ctx, 274, 283, '02 · GARDEN');
  drawCameraZone(ctx, 432, 264, '03 · PORCH');

  // A hatched door identifies the no-camera area. Only the explicit sponsor
  // acceptance briefly opens a generic, non-personal room silhouette.
  ctx.fillStyle = '#34303a'; ctx.fillRect(521, 139, 32, 62);
  ctx.strokeStyle = game.privateRoomShared ? '#bd5b2e' : '#25212b'; ctx.lineWidth = 3; ctx.strokeRect(521, 139, 32, 62);
  if (game.privateRevealActive) {
    ctx.fillStyle = '#9d856d'; ctx.fillRect(524, 142, 26, 56);
    ctx.fillStyle = '#3d6254'; ctx.fillRect(529, 162, 13, 23);
    ctx.fillStyle = '#d9bd8f'; ctx.fillRect(532, 145, 10, 9);
    label(ctx, 'SPONSORED CUTAWAY · AGREED', 539, 122, '#2c2430', 8);
    line(ctx, 429, 154, 536, 169, '#c43475', 2);
  } else {
    for (let y = 144; y < 197; y += 10) line(ctx, 522, y, 552, y + 8, '#b89ba1', 1);
    label(ctx, 'PRIVATE', 537, 216, '#2e2830', 9);
    label(ctx, 'NO CAMERA', 537, 226, '#2e2830', 7);
    if (game.privateRoomShared) label(ctx, 'ONE CUTAWAY SHARED', 537, 120, '#7a351f', 7);
  }

  // A small silhouette pair stands in for the final character sheets.
  const animation = game.animation;
  const walking = Boolean(animation && animation.elapsed < animation.duration * 0.45);
  const phase = game.reducedMotion ? 0 : game.time * 10;
  const activeJob = animation?.job ?? null;
  drawPerson(ctx, game.actorX, 222, '#3e706b', walking, phase, activeJob);
  drawPerson(ctx, 472, 222, '#aa526f', false, 0, null);
  ctx.fillStyle = '#22212a'; ctx.fillRect(451, 170, 10, 20); ctx.fillStyle = '#deff60'; ctx.strokeStyle = '#38303d';
  ctx.fillRect(447, 168, 19, 16); ctx.strokeRect(447, 168, 19, 16);
  label(ctx, 'ZERO', 456, 166, '#26202b', 7);

  if (game.stream) {
    ctx.fillStyle = '#c62847'; ctx.fillRect(266, 11, 77, 19); label(ctx, '● LIVE', 304, 24, '#fff5e9', 10);
  } else {
    ctx.fillStyle = '#27242d'; ctx.fillRect(266, 11, 77, 19); label(ctx, '■ OFFLINE', 304, 24, '#f4eadc', 9);
  }
  const meterX = 21;
  ctx.fillStyle = '#302b34'; ctx.fillRect(meterX, 20, 122, 10); ctx.fillRect(meterX + 133, 20, 122, 10);
  ctx.fillStyle = '#bce542'; ctx.fillRect(meterX, 20, 122 * game.home / 100, 10);
  ctx.fillStyle = '#ed85aa'; ctx.fillRect(meterX + 133, 20, 122 * game.energy / 100, 10);
  label(ctx, 'HOME ' + game.home, 82, 15, '#28222c', 8); label(ctx, 'ENERGY ' + game.energy, 215, 15, '#28222c', 8);
  ctx.restore();
}
