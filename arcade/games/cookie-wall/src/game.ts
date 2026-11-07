import { boardFor, brickRules, COURT, damage, PACKET_RADIUS, PADDLE, speeds, type Brick } from './board';
import { clamp, firstHit, rebound, touching, type Packet } from './physics';

type Phase = 'docked' | 'flight' | 'wall-clear' | 'leaking' | 'over';
type Signal = (name: string, detail?: Record<string, unknown>) => void;
const STEP = 1 / 60;
const REST_Y = PADDLE.y - PADDLE.height / 2 - PACKET_RADIUS - 1;
const freshStats = () => ({ wallsCleared: 0, bricksBroken: 0, packetsLost: 0, paddleReturns: 0, maxChain: 0 });

export class CookieWallGame {
  phase: Phase = 'docked';
  packet: Packet = { x: 160, y: REST_Y, vx: 0, vy: 0 };
  paddleX = 160;
  aim = Math.PI / 12;
  dockedAfterLoss = false;
  score = 0;
  lives = 3;
  wall = 1;
  chain = 0;
  speed: number = speeds[0];
  time = 0;
  stats = freshStats();
  bricks: Brick[];
  burst: { x: number; y: number; w: number; h: number; kind: Brick['kind']; until: number } | null = null;
  lastPaddleHit = -Infinity;
  leakAt = -Infinity;
  private held = new Set<string>();
  private contacts = new Set<Brick>();
  private axis = 0;
  private target: number | null = null;
  private breather = 0;
  private shallowTime = 0;
  private accumulator = 0;

  constructor(public seed: number, private emit: Signal = () => {}) {
    this.bricks = boardFor(1, seed);
  }

  reset(seed = this.seed) {
    this.seed = seed; this.wall = 1; this.score = 0; this.lives = 3; this.chain = 0;
    this.stats = freshStats(); this.time = 0; this.speed = speeds[0]; this.breather = 0;
    this.accumulator = 0; this.burst = null; this.lastPaddleHit = -Infinity; this.leakAt = -Infinity; this.paddleX = COURT / 2;
    this.releaseInput();
    this.newWall();
  }

  private newWall() {
    this.bricks = boardFor(this.wall, this.seed);
    this.dock(); this.dockedAfterLoss = false;
    this.emit('game:wall', { wall: this.wall, bricksRemaining: this.bricks.length });
  }

  private dock() {
    this.phase = 'docked'; this.shallowTime = 0; this.contacts.clear();
    this.aim = (this.stats.packetsLost % 2 ? -1 : 1) * Math.PI / 12;
    Object.assign(this.packet, { x: this.paddleX, y: REST_Y, vx: 0, vy: 0 });
  }

  input(action: string, down: boolean) {
    if (!down) { this.held.delete(action); return; }
    if (this.held.has(action)) return;
    this.held.add(action);
    if (action === 'left' || action === 'right') this.target = null;
    if (action === 'launch' && this.phase === 'docked') {
      this.phase = 'flight';
      this.packet.vx = Math.sin(this.aim) * this.speed;
      this.packet.vy = -Math.cos(this.aim) * this.speed;
      this.emit('game:launch');
    }
  }

  moveAxis(value: number) {
    this.axis = clamp(value, -1, 1);
    if (this.axis !== 0) this.target = null;
  }

  setTarget(fraction: number | null) {
    this.target = fraction === null ? null : clamp(fraction * COURT, PADDLE.width / 2, COURT - PADDLE.width / 2);
  }

  releaseInput() {
    this.held.clear(); this.axis = 0; this.target = null; this.accumulator = 0;
  }

  update(dt: number) {
    this.accumulator = Math.min(this.accumulator + clamp(dt, 0, 5 * STEP), 5 * STEP);
    while (this.accumulator + 1e-10 >= STEP) {
      this.accumulator = Math.max(0, this.accumulator - STEP);
      this.step(STEP);
    }
  }

  step(dt: number) {
    if (this.phase === 'over') return;
    this.time += dt;
    if (this.phase === 'wall-clear' || this.phase === 'leaking') {
      this.breather -= dt;
      if (this.breather <= 1e-8) {
        if (this.phase === 'leaking') this.phase = 'over';
        else { this.wall++; this.newWall(); }
      }
      return;
    }
    const oldX = this.paddleX;
    const digital = Number(this.held.has('right')) - Number(this.held.has('left'));
    const direction = clamp(digital + this.axis, -1, 1);
    const maxTravel = PADDLE.speed * dt;
    const delta = this.target === null ? maxTravel * direction : clamp(this.target - oldX, -maxTravel, maxTravel);
    this.paddleX = clamp(oldX + delta, PADDLE.width / 2, COURT - PADDLE.width / 2);
    if (this.phase === 'docked') {
      this.packet.x = this.paddleX;
      if (delta) this.aim = clamp(this.aim + Math.sign(delta) * 1.8 * dt, -Math.PI / 3, Math.PI / 3);
      return;
    }
    const paddleVx = (this.paddleX - oldX) / dt;
    this.shallowTime = Math.abs(this.packet.vy) < this.speed * 0.16 ? this.shallowTime + dt : 0;
    let elapsed = 0;
    for (let contact = 0; contact < 4 && elapsed < dt && this.phase === 'flight'; contact++) {
      for (const brick of this.contacts) if (!touching(this.packet, brick)) this.contacts.delete(brick);
      const hit = firstHit(this.packet, this.bricks, oldX + paddleVx * elapsed, paddleVx, dt - elapsed);
      const travel = hit?.time ?? dt - elapsed;
      this.packet.x += this.packet.vx * travel;
      this.packet.y += this.packet.vy * travel;
      elapsed += travel;
      if (!hit) break;
      if (hit.type === 'drain') { this.losePacket(); break; }
      if (hit.type === 'paddle') {
        this.speed = speeds[Math.min(this.wall - 1, speeds.length - 1)];
        rebound(this.packet, this.packet.x - (oldX + paddleVx * elapsed), this.speed);
        this.chain = 0; this.stats.paddleReturns++; this.lastPaddleHit = this.time; this.emit('game:paddle');
      } else {
        if (hit.nx) this.packet.vx *= -1;
        if (hit.ny) this.packet.vy *= -1;
        if (hit.brick && !this.contacts.has(hit.brick)) {
          this.contacts.add(hit.brick); this.strike(hit.brick);
        }
        if (this.shallowTime >= 2) {
          this.packet.vy = (Math.sign(this.packet.vy) || -1) * this.speed * 0.20;
          this.packet.vx = Math.sign(this.packet.vx) * Math.sqrt(this.speed ** 2 - this.packet.vy ** 2);
          this.shallowTime = 0;
        }
      }
      if (this.phase !== 'flight') break;
      this.packet.x += hit.nx * 1e-5; this.packet.y += hit.ny * 1e-5;
    }
    // Leave any unconsumed time at the last safe contact when the resolution cap is reached.
  }

  private strike(brick: Brick) {
    if (!damage(brick)) { this.emit('game:crack', { kind: brick.kind }); return; }
    this.chain++; this.stats.bricksBroken++;
    this.stats.maxChain = Math.max(this.chain, this.stats.maxChain);
    const multiplier = Math.min(3, Math.ceil(this.chain / 2));
    this.score += brickRules[brick.kind].points * multiplier;
    this.burst = { x: brick.x + brick.w / 2, y: brick.y + brick.h / 2, w: brick.w, h: brick.h, kind: brick.kind, until: this.time + 0.22 };
    this.emit('game:brick', { kind: brick.kind, multiplier });
    if (this.bricks.some(candidate => candidate.hp > 0)) return;
    this.score += 100; this.stats.wallsCleared++; this.chain = 0;
    this.phase = 'wall-clear'; this.breather = 1;
    Object.assign(this.packet, { x: this.paddleX, y: REST_Y, vx: 0, vy: 0 });
    this.emit('game:wall-clear', { wall: this.wall });
  }

  private losePacket() {
    this.stats.packetsLost++; this.lives--; this.chain = 0; this.leakAt = this.time;
    this.emit('game:leak', { lives: this.lives });
    if (this.lives > 0) { this.dock(); this.dockedAfterLoss = true; }
    else { this.phase = 'leaking'; this.breather = 0.25; }
  }
}
