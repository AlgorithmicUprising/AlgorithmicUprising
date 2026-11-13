export type ScanLane = 'low' | 'high';
export type EyePhase = 'approach' | 'warning' | 'scan' | 'recover' | 'depart' | 'disabled';
export type Bounds = { left: number; right: number; top: number; bottom: number };

export const courierWidth = 144;
export const courierClosing = 0.68;
export const courierDeck = { left: 39, right: 112 };
// Trimmed hull and parcel bounds at the sprite's 144-unit draw width.
export const courierBody = [
  { left: 29, right: 116, top: 1, bottom: 26 },
  { left: 37, right: 99, top: 23, bottom: 46 }
] as const;

export const eyeApproachTime = 0.55;
export const eyeWarningTime = 1.1;
export const eyeOllieCueTime = 0.79;
export const eyeScanTime = 0.14;
export const eyeDipTime = 0.12;
export const eyeRecoverTime = 1.63;
export const eyeDepartTime = 0.82;
export const eyeDisabledTime = 0.58;
export const eyeEarlyJumpTime = 0.97;
export const sprayJamCost = 0.08;
const eyeRiseTime = 0.28;
const eyeHoverHeight = 164;
const eyeStompHeight = 56;
const sprayReach = 112;

export type CookieEye = {
  phase: EyePhase;
  age: number;
  lane: ScanLane;
  x: number;
  top: number;
  entryX: number;
  entryTop: number;
  earlyJump: boolean;
  scanHit: boolean;
  jammed: boolean;
  stomped: boolean;
};

const mix = (a: number, b: number, t: number) => a + (b - a) * Math.min(1, t);
const easeOut = (t: number) => 1 - (1 - Math.min(1, t)) ** 2;

export function boundsOverlap(a: Bounds, b: Bounds) {
  return a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top;
}

export function createEye(viewRight: number, playerX: number, ground: number, lane: ScanLane): CookieEye {
  const x = Math.max(viewRight + 26, playerX + 205);
  const top = ground - eyeHoverHeight;
  return { phase: 'approach', age: 0, lane, x, top, entryX: x, entryTop: top,
    earlyJump: false, scanHit: false, jammed: false, stomped: false };
}

export function enterEyePhase(eye: CookieEye, phase: EyePhase) {
  eye.phase = phase;
  eye.age = 0;
  eye.entryX = eye.x;
  eye.entryTop = eye.top;
}

export function moveEye(eye: CookieEye, dt: number, playerX: number, ground: number) {
  eye.age += dt;
  const age = eye.age;
  const high = ground - eyeHoverHeight;
  switch (eye.phase) {
    case 'approach':
      eye.x = mix(eye.entryX, playerX + 168, easeOut(age / eyeApproachTime));
      break;
    case 'warning':
      eye.x = mix(eye.entryX, playerX + 62, easeOut(age / eyeWarningTime));
      eye.top = high + Math.sin(age * 6) * 2;
      break;
    case 'scan':
      eye.top = mix(eye.entryTop, high, age / eyeScanTime);
      break;
    case 'recover':
      // The stomp pad reaches Fony's line while the hull stays out of it.
      eye.x = mix(eye.entryX, playerX + 62, easeOut(age / eyeDipTime));
      eye.top = mix(eye.entryTop, ground - eyeStompHeight, easeOut(age / eyeDipTime));
      break;
    case 'depart':
      eye.top = mix(eye.entryTop, high, easeOut(age / eyeRiseTime));
      eye.x = age <= eyeRiseTime ? eye.entryX : mix(eye.entryX, playerX - 215, (age - eyeRiseTime) / (eyeDepartTime - eyeRiseTime));
      break;
    case 'disabled':
      eye.x = eye.entryX + age * 80;
      eye.top = eye.entryTop + age * age * 270;
      break;
  }
}

export function eyeHull(eye: CookieEye): Bounds {
  return { left: eye.x - 25, right: eye.x + 25, top: eye.top, bottom: eye.top + 31 };
}

export function eyeLens(eye: CookieEye) {
  const aiming = eye.phase === 'warning' || eye.phase === 'scan';
  return { x: eye.x - 15, y: eye.top + (aiming ? (eye.lane === 'low' ? 20 : 15) : 17) };
}

export function eyePad(eye: CookieEye) {
  return { left: eye.x - 82, right: eye.x - 19, y: eye.top };
}

export function eyePadReady(eye: CookieEye) {
  return eye.phase === 'recover' && eye.age >= eyeDipTime;
}

export function eyeScan(eye: CookieEye, playerX: number, ground: number): Bounds {
  return {
    left: playerX - 84,
    right: eyeLens(eye).x,
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
