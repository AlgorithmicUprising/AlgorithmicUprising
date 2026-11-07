import layouts from './boards.json';

export const COURT = 320;
export const PADDLE = { width: 64, height: 12, y: 290, speed: 600, margin: 2 } as const;
export const PACKET_RADIUS = 4;
export const speeds = [170, 200, 230, 260] as const;

export const brickRules = {
  necessary: { hits: 1, points: 10 },
  partners: { hits: 1, points: 20 },
  interest: { hits: 2, points: 30 },
  reject: { hits: 2, points: 40 }
} as const;
export type Kind = keyof typeof brickRules;
export type Rect = { x: number; y: number; w: number; h: number };
export type Brick = Rect & { id: number; kind: Kind; hp: number };
const alphabet: Record<string, Kind> = { N: 'necessary', P: 'partners', I: 'interest', R: 'reject' };

function mix(seed: number) {
  let n = Math.imul(seed ^ (seed >>> 16), 0x21f0aaad);
  n = Math.imul(n ^ (n >>> 15), 0x735a2d97);
  return (n ^ (n >>> 15)) >>> 0;
}

export function boardFor(wall: number, seed: number): Brick[] {
  const index = wall - 1;
  const bag = [0, 1, 2];
  if (index >= 3) {
    const roll = mix(seed ^ Math.floor(index / 3));
    const end = roll % 3;
    [bag[2], bag[end]] = [bag[end], bag[2]];
    if ((roll >>> 4) & 1) [bag[0], bag[1]] = [bag[1], bag[0]];
  }
  const rows = layouts[bag[index % 3]];
  const flipped = index >= 3 && (mix(seed ^ wall) & 1) === 1;
  const bricks: Brick[] = [];
  for (const [row, cells] of rows.entries()) {
    for (let col = 0; col < cells.length; col++) {
      const kind = alphabet[cells[col]];
      if (!kind) continue;
      // Offset the grid by two units so even a full opening row has a 12px side passage.
      const x = 12 + col * 38;
      bricks.push({ id: row * 8 + col, kind, x: flipped ? COURT - x - 34 : x,
        y: 36 + row * 22, w: 34, h: 18, hp: brickRules[kind].hits });
    }
  }
  return bricks;
}

export function damage(brick: Brick) {
  brick.hp--;
  if (brick.kind === 'reject' && brick.hp === 1) {
    brick.x += 4;
    brick.w = 26;
  }
  return brick.hp === 0;
}
