import { COURT, PACKET_RADIUS as R, PADDLE, type Brick, type Rect } from './board';

export type Packet = { x: number; y: number; vx: number; vy: number };
type Hit = { time: number; nx: number; ny: number; order: number; type: 'wall' | 'paddle' | 'brick' | 'drain'; brick?: Brick };
const EPS = 1e-8;
export const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(value, high));

export function touching(ball: Packet, rect: Rect) {
  return ball.x >= rect.x - R - EPS && ball.x <= rect.x + rect.w + R + EPS &&
    ball.y >= rect.y - R - EPS && ball.y <= rect.y + rect.h + R + EPS;
}

function slab(position: number, velocity: number, lo: number, hi: number) {
  if (Math.abs(velocity) < EPS) return position < lo || position > hi ? null : [-Infinity, Infinity];
  const a = (lo - position) / velocity, b = (hi - position) / velocity;
  return a < b ? [a, b] : [b, a];
}

function brickHit(ball: Packet, brick: Brick, limit: number): Hit | null {
  const x = slab(ball.x, ball.vx, brick.x - R, brick.x + brick.w + R);
  const y = slab(ball.y, ball.vy, brick.y - R, brick.y + brick.h + R);
  if (!x || !y) return null;
  const enter = Math.max(x[0], y[0]);
  if (enter < -EPS || enter > limit + EPS || Math.min(x[1], y[1]) < enter - EPS) return null;
  const verticalFace = x[0] > y[0] + EPS;
  return { time: Math.max(0, enter), type: 'brick', brick, order: 10 + brick.id,
    nx: verticalFace ? -Math.sign(ball.vx) : 0, ny: verticalFace ? 0 : -Math.sign(ball.vy) };
}

/** Earliest contact in seconds. Paddle position is evaluated at impact, including its travel this step. */
export function firstHit(ball: Packet, bricks: Brick[], paddleX: number, paddleVx: number, limit: number): Hit | null {
  let nearest: Hit | null = null;
  function consider(hit: Hit) {
    if (hit.time < -EPS || hit.time > limit + EPS) return;
    if (!nearest || hit.time < nearest.time - EPS || (Math.abs(hit.time - nearest.time) <= EPS && hit.order < nearest.order)) {
      hit.time = clamp(hit.time, 0, limit);
      nearest = hit;
    }
  }
  if (ball.vx < 0) consider({ time: (R - ball.x) / ball.vx, nx: 1, ny: 0, type: 'wall', order: 1 });
  if (ball.vx > 0) consider({ time: (COURT - R - ball.x) / ball.vx, nx: -1, ny: 0, type: 'wall', order: 1 });
  if (ball.vy < 0) consider({ time: (R - ball.y) / ball.vy, nx: 0, ny: 1, type: 'wall', order: 2 });
  if (ball.vy > 0) {
    const time = (PADDLE.y - PADDLE.height / 2 - R - ball.y) / ball.vy;
    const offset = (ball.x + ball.vx * time) - (paddleX + paddleVx * time);
    if (time >= -EPS && Math.abs(offset) <= PADDLE.width / 2 + R + PADDLE.margin) {
      consider({ time, nx: 0, ny: -1, type: 'paddle', order: 0 });
    }
    consider({ time: Math.max(0, (COURT + R - ball.y) / ball.vy), nx: 0, ny: 0, type: 'drain', order: 3 });
  }
  const endX = ball.x + ball.vx * limit, endY = ball.y + ball.vy * limit;
  const left = Math.min(ball.x, endX) - R, right = Math.max(ball.x, endX) + R;
  const top = Math.min(ball.y, endY) - R, bottom = Math.max(ball.y, endY) + R;
  for (const brick of bricks) {
    if (brick.hp <= 0 || brick.x > right || brick.x + brick.w < left || brick.y > bottom || brick.y + brick.h < top) continue;
    const hit = brickHit(ball, brick, limit);
    if (hit) consider(hit);
  }
  return nearest;
}

export function rebound(ball: Packet, offset: number, speed: number) {
  const angle = clamp(offset / (PADDLE.width / 2), -1, 1) * Math.PI / 3;
  const horizontal = Math.max(0.15, Math.abs(Math.sin(angle)));
  ball.vx = (Math.sign(angle) || Math.sign(ball.vx) || 1) * horizontal * speed;
  ball.vy = -Math.sqrt(speed * speed - ball.vx * ball.vx);
}
