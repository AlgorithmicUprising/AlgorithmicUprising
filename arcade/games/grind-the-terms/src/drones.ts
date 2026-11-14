export type ScanLane = 'low' | 'high';
export type EyePhase = 'approach' | 'lineup' | 'warning' | 'scan' | 'recover' | 'depart' | 'disabled';
export type Bounds = { left: number; right: number; top: number; bottom: number };
type Roof = { left: number; right: number; y: number };
type Board = { x: number; y: number };

export const boardHalfWidth = 14;

export const courierWidth = 144;
export const courierClosing = 0.68;
export const courierDeck = { left: 39, right: 112 };
// The drawn rail sits above the painted hull. All vertical offsets are measured from its top.
export const courierSpriteTopOffset = 20;
export const courierBody = [
  { left: 29, right: 116, top: 7, bottom: 32 },
  { left: 37, right: 99, top: 28, bottom: 52 }
] as const;

export const eyeApproachTime = 0.85;
export const eyeBaitTime = 0.24;
export const eyeLineupTime = 0.27;
export const eyeWarningTime = 1.1;
export const eyeOllieCueTime = 0.79;
export const eyeScanTime = 0.14;
export const eyeRecoverTime = 1.63;
export const eyeDepartTime = 0.82;
export const droneShutdownTime = 0.58;
export const eyeEarlyJumpTime = 0.97;
export const sprayJamCost = 0.08;
const eyeRiseTime = 0.28;
const eyeHoverHeight = 164;
const eyeLowHeight = 84;
const eyeScanReach = 155;
const sprayReach = 112;

export type CookieEye = {
  phase: EyePhase;
  age: number;
  lane: ScanLane;
  x: number;
  top: number;
  entryX: number;
  entryTop: number;
  targetX: number;
  facing: -1 | 1;
  groundTime: number;
  earlyJump: boolean;
  jammed: boolean;
  stomped: boolean;
};

const mix = (a: number, b: number, t: number) => a + (b - a) * Math.min(1, t);
const easeOut = (t: number) => 1 - (1 - Math.min(1, t)) ** 2;

export function boundsOverlap(a: Bounds, b: Bounds) {
  return a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top;
}

export function landsOnDrone(from: Board, to: Board, previous: Roof, roof: Roof) {
  const start = from.y - previous.y;
  const end = to.y - roof.y;
  if (to.y < from.y || start > 0 || end < 0 || end <= start) return false;

  // Sample the board and the moving roof at the same instant of contact.
  const t = -start / (end - start);
  const boardX = mix(from.x, to.x, t);
  return boardX + boardHalfWidth > mix(previous.left, roof.left, t)
    && boardX - boardHalfWidth < mix(previous.right, roof.right, t);
}

export function hitsDroneSide(from: Bounds, to: Bounds, previous: Bounds, hull: Bounds) {
  let before: number, after: number;
  if (from.right <= previous.left) {
    before = previous.left - from.right;
    after = hull.left - to.right;
  } else if (from.left >= previous.right) {
    before = from.left - previous.right;
    after = to.left - hull.right;
  } else {
    return false;
  }
  if (after >= 0) return false;

  // Crossing a lateral face is hazardous only when the bodies overlap in height.
  const t = before / (before - after);
  return mix(from.top, to.top, t) < mix(previous.bottom, hull.bottom, t)
    && mix(from.bottom, to.bottom, t) > mix(previous.top, hull.top, t);
}

export function courierRoof(x: number, y: number): Roof {
  return { left: x + courierDeck.left, right: x + courierDeck.right, y };
}

export function createEye(viewRight: number, ground: number, approachX: number): CookieEye {
  const x = viewRight + 56;
  const top = ground - eyeHoverHeight;
  return { phase: 'approach', age: 0, lane: 'high', x, top, entryX: x, entryTop: top,
    targetX: approachX, facing: -1, groundTime: 0,
    earlyJump: false, jammed: false, stomped: false };
}

export function enterEyePhase(eye: CookieEye, phase: EyePhase) {
  eye.phase = phase;
  eye.age = 0;
  eye.entryX = eye.x;
  eye.entryTop = eye.top;
}

export function lineUpEye(eye: CookieEye, playerX: number, forwardLimit: number, lane: ScanLane) {
  const roomAhead = forwardLimit - playerX;
  // A player already near the right limit can reach a drone lined up behind them.
  eye.facing = roomAhead >= 72 ? -1 : 1;
  eye.targetX = eye.facing < 0 ? Math.min(playerX + 94, forwardLimit) : playerX - 78;
  eye.lane = lane;
  enterEyePhase(eye, 'lineup');
}

export function moveEye(eye: CookieEye, dt: number, ground: number, viewLeft: number, viewRight: number) {
  eye.age += dt;
  const age = eye.age;
  const high = ground - eyeHoverHeight;
  switch (eye.phase) {
    case 'approach':
      eye.x = mix(eye.entryX, eye.targetX, easeOut(age / eyeApproachTime));
      break;
    case 'lineup': {
      const progress = easeOut(age / eyeLineupTime);
      eye.x = mix(eye.entryX, eye.targetX, progress);
      eye.top = mix(eye.entryTop, eye.lane === 'low' ? ground - eyeLowHeight : high, progress);
      break;
    }
    case 'depart': {
      const exitX = eye.facing < 0 ? viewRight + 58 : viewLeft - 58;
      eye.top = mix(eye.entryTop, high, easeOut(age / eyeRiseTime));
      if (age > eyeRiseTime) eye.x = mix(eye.entryX, exitX, (age - eyeRiseTime) / (eyeDepartTime - eyeRiseTime));
      break;
    }
    case 'disabled':
      eye.x = eye.entryX - eye.facing * age * 80;
      eye.top = eye.entryTop + age * age * 270;
      break;
  }
}

export function eyeHull(eye: CookieEye): Bounds {
  return { left: eye.x - 29, right: eye.x + 29, top: eye.top + 5, bottom: eye.top + 31 };
}

export function eyeLens(eye: CookieEye) {
  const aiming = eye.phase === 'warning' || eye.phase === 'scan';
  return { x: eye.x + eye.facing * 13, y: eye.top + (aiming ? (eye.lane === 'low' ? 20 : 15) : 17) };
}

export function eyeRoof(eye: CookieEye) {
  return { left: eye.x - 22, right: eye.x + 22, y: eye.top + 4, ready: eye.phase !== 'disabled' };
}

export function eyeScan(eye: CookieEye, ground: number): Bounds {
  const lens = eyeLens(eye).x;
  const edge = lens + eye.facing * eyeScanReach;
  return {
    left: Math.min(lens, edge),
    right: Math.max(lens, edge),
    top: ground - (eye.lane === 'low' ? 42 : 164),
    bottom: eye.lane === 'low' ? ground + 1 : ground - 115
  };
}

export function sprayOrigin(playerX: number, boardY: number) {
  return { x: playerX + 18, y: boardY - 61 };
}

export function eyeInSprayRange(eye: CookieEye, playerX: number, boardY: number) {
  const from = sprayOrigin(playerX, boardY), lens = eyeLens(eye);
  return lens.x >= from.x && (lens.x - from.x) ** 2 + (lens.y - from.y) ** 2 <= sprayReach ** 2;
}
