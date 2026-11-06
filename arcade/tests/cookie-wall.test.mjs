import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';

const bundle = await build({ stdin: { contents: [
  "export * from './games/cookie-wall/src/game';", "export * from './games/cookie-wall/src/board';",
  "export * from './games/cookie-wall/src/physics';"
].join('\n'), resolveDir: process.cwd() }, write: false, bundle: true, platform: 'node', format: 'esm' });
const { CookieWallGame, boardFor, firstHit, damage, COURT, PADDLE } =
  await import('data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].contents).toString('base64'));
const step = (g, frames = 1) => { for (let n = 0; n < frames; n++) g.update(1 / 60); };
const launch = g => { g.input('launch', true); g.input('launch', false); };
const brick = (kind, id = 0, x = 140, y = 100) => ({
  id, kind, x, y, w: 34, h: 18, hp: ['interest','reject'].includes(kind) ? 2 : 1
});
const fromBelow = (g, b) => {
  g.phase = 'flight'; Object.assign(g.packet, { x: b.x + b.w / 2, y: b.y + b.h + 5, vx: 0, vy: -g.speed }); step(g);
};
const drain = g => { g.phase = 'flight'; Object.assign(g.packet, { x: 20, y: 323, vx: 0, vy: 220 }); step(g); };

test('three authored introductions, a seeded bag of repeats, and a passage for every wall', () => {
  const first = boardFor(1, 0);
  assert.equal(first.length, 24); assert.equal(new Set(first.map(b => b.y)).size, 3);
  assert.ok(first.every(b => b.hp === 1)); assert.ok(boardFor(2, 2).some(b => b.kind === 'interest'));
  assert.ok(boardFor(3, 2).some(b => b.kind === 'reject'));
  const order = seed => Array.from({length: 12}, (_, i) => boardFor(i + 1, seed));
  assert.deepEqual(order(31), order(31)); assert.notDeepEqual(order(31), order(32));
  for (const board of order(0)) {
    assert.ok(board.length > 0 && board.length <= 48);
    assert.equal(new Set(board.map(b => b.id)).size, board.length);
    assert.ok(Math.min(...board.map(b => b.x)) >= 12 || Math.max(...board.map(b => b.x + b.w)) <= COURT - 12);
  }
});

test('target, keyboard and analog controls respect travel cap; a held launch has one edge', () => {
  const g = new CookieWallGame(0); g.setTarget(1); step(g);
  assert.equal(g.paddleX, 170); step(g, 30); assert.equal(g.paddleX, 288);
  g.input('left', true); step(g); assert.equal(g.paddleX, 278); g.releaseInput();
  g.moveAxis(-.5); step(g); assert.equal(g.paddleX, 273); g.releaseInput();
  g.input('launch', true); assert.equal(g.phase, 'flight');
  drain(g); assert.equal(g.phase, 'docked'); assert.ok(g.aim < 0);
  g.input('launch', true); assert.equal(g.phase, 'docked');
  g.input('launch', false); launch(g); assert.equal(g.phase, 'flight');
});

test('fixed steps are identical in 16.7 and 50ms outer frames, including collisions', () => {
  const a = new CookieWallGame(77), b = new CookieWallGame(77); launch(a); launch(b);
  for (let i = 0; i < 90; i++) { step(a, 3); b.update(.05); }
  assert.deepEqual(a.packet, b.packet); assert.deepEqual(a.stats, b.stats); assert.equal(a.score, b.score);
});

test('sweep chooses a stable single corner and catches a moving paddle from above', () => {
  const a = brick('necessary', 2), b = brick('necessary', 0);
  const packet = { x: 132, y: 92, vx: 200, vy: 200 };
  for (const list of [[a,b],[b,a]]) assert.equal(firstHit(packet, list, 160, 0, .05).brick.id, 0);
  const g = new CookieWallGame(2); g.phase = 'flight'; g.wall = 4; g.speed = 260;
  Object.assign(g.packet, { x: 199, y: 276, vx: 0, vy: 260 }); g.setTarget(1); g.update(.05);
  assert.equal(g.stats.paddleReturns, 1); assert.ok(g.packet.vy < 0 && g.packet.y < 280);
  assert.ok(Math.abs(Math.hypot(g.packet.vx, g.packet.vy) - 260) < .001);
  const below = { x: 160, y: 291, vx: 0, vy: 260 };
  assert.equal(firstHit(below, [], 160, 0, .05), null);
  const crossing = {x: 160, y: 60, vx: 0, vy: 260};
  assert.equal(firstHit(crossing, [brick('necessary', 7, 140, 68)], 160, 0, .05).type, 'brick');
});

test('a partial hit pays zero; Reject shrinks around its center and its collision width follows', () => {
  const g = new CookieWallGame(1), reject = brick('reject'); g.bricks = [reject, brick('necessary', 1, 240)];
  fromBelow(g, reject); assert.equal(reject.hp, 1); assert.equal(g.score, 0);
  assert.equal(reject.w, 26); assert.equal(reject.x, 144); step(g, 2); assert.equal(reject.hp, 1);
  const grazing = {x: 139, y: 90, vx: 0, vy: 200};
  assert.equal(firstHit(grazing, [reject], 160, 0, .05), null);
  fromBelow(g, reject); assert.equal(g.score, 40); assert.equal(g.stats.bricksBroken, 1);
});

test('chains multiply destructions only, clear bonus is flat, next speed waits for return', () => {
  const g = new CookieWallGame(4); const kinds = ['necessary','partners','interest','reject','necessary'];
  g.bricks = kinds.map((kind, i) => brick(kind, i, 15 + 52*i));
  for (const b of g.bricks) { fromBelow(g,b); if (b.hp) fromBelow(g,b); }
  assert.equal(g.stats.maxChain, 5); assert.equal(g.score, 10 + 20 + 60 + 80 + 30 + 100);
  assert.equal(g.phase, 'wall-clear'); assert.equal(g.stats.wallsCleared, 1);
  step(g, 59); launch(g); assert.equal(g.phase, 'wall-clear'); step(g);
  assert.equal(g.phase, 'docked'); assert.equal(g.wall, 2); assert.equal(g.lives, 3); assert.equal(g.speed,170);
  launch(g); Object.assign(g.packet,{x:g.paddleX,y:279,vx:0,vy:170});step(g);
  assert.equal(g.speed,200);assert.equal(g.chain,0);assert.ok(Math.abs(g.packet.vx)>=.15*g.speed);
});

test('third drain ends once and retry restores the seeded run', () => {
  const events=[];const g=new CookieWallGame(13, name=>events.push(name));g.reset();g.score=80;
  for(let lives=2;lives>=0;lives--){drain(g);assert.equal(g.lives,lives)}
  step(g,90);assert.equal(g.phase,'over');assert.equal(g.stats.packetsLost,3);assert.equal(g.score,80);
  assert.equal(events.filter(e=>e==='game:leak').length,3);g.reset();
  assert.deepEqual(g.bricks,boardFor(1,13));assert.equal(g.lives,3);assert.equal(g.score,0);assert.equal(g.phase,'docked');
});

test('each authored wall can be cleared by steering legal paddle returns', () => {
  for (let wall=1; wall<=3; wall++) {
    const g=new CookieWallGame(31);g.wall=wall;g.bricks=boardFor(wall,31);launch(g);
    for(let frame=0; frame<60*450 && g.stats.wallsCleared===0; frame++){
      if(g.phase==='docked')launch(g);
      if(g.phase==='over')break;
      if(g.packet.vy>0){
        const until=(PADDLE.y-PADDLE.height/2-4-g.packet.y)/g.packet.vy;
        const ray=g.packet.x+g.packet.vx*Math.max(0,until)-4;
        const wrapped=((ray%624)+624)%624, landing=4+Math.min(wrapped,624-wrapped);
        const remaining=g.bricks.filter(b=>b.hp);
        const target=remaining[(g.stats.paddleReturns*7)%remaining.length];
        const angle=Math.atan2(target.x+target.w/2-landing,280-target.y-target.h);
        g.setTarget((landing-32*angle/(Math.PI/3))/320);
      } else g.setTarget(g.packet.x/320);
      step(g);
    }
    assert.equal(g.stats.wallsCleared,1,'wall '+wall+' remaining '+g.bricks.filter(b=>b.hp).length);
  }
});
