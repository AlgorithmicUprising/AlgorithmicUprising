import { expect, test } from '@playwright/test';

const practice = '/games/grind-the-terms/demo/embed.html?practice=drones';

async function openPractice(page) {
  await page.goto(practice);
  const game = page.locator('grind-the-terms');
  await expect(game).toHaveAttribute('data-au-art-ready', '');
  return game;
}

test('the high courier is safe to skate under and a low scan slows once', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const g = el.game;
    const events = [];
    for (const type of ['game:delivery-spawn', 'game:drone-warn', 'game:drone-hit', 'game:bail']) {
      el.addEventListener(type, event => events.push({ type, ...event.detail }));
    }
    g.start();
    for (let i = 0; i < 600 && g.result().stats.scansHit === 0; i++) g.update(1 / 60);
    const hit = g.result().stats;
    for (let i = 0; i < 75; i++) g.update(1 / 60);
    return { events, hit, after: g.result().stats, over: g.over() };
  });
  expect(result.events.map(event => event.type)).toEqual(['game:delivery-spawn', 'game:drone-warn', 'game:drone-hit']);
  expect(result.events[1]).toMatchObject({ lane: 'low', warningMs: 1100 });
  expect(result.hit.runSpeed).toBeLessThan(result.hit.normalSpeed);
  expect(result.after.scansHit).toBe(1);
  expect(result.after.runSpeed).toBe(result.after.normalSpeed);
  expect(result.over).toBe(false);
});

test('two early dodges teach the next Eye to scan high', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const g = el.game;
    const lanes = [], dodges = [];
    el.addEventListener('game:drone-warn', e => lanes.push(e.detail.lane));
    el.addEventListener('game:drone-dodge', e => dodges.push({ lane: e.detail.lane, early: e.detail.early }));
    g.start();
    let jumped = 0;
    for (let i = 0; i < 1800 && dodges.length < 3 && !g.over(); i++) {
      const eye = g.result().stats.eye;
      if (jumped < 2 && lanes.length > jumped && eye?.phase === 'warning' && eye.age >= .8) {
        g.input('up', true);
        g.input('up', false);
        jumped++;
      }
      g.update(1 / 60);
    }
    const { scansHit, eyesStomped } = g.result().stats;
    return { lanes, dodges, scansHit, eyesStomped };
  });
  expect(result.lanes).toEqual(['low', 'low', 'high']);
  expect(result.dodges).toEqual([{ lane: 'low', early: true }, { lane: 'low', early: true }, { lane: 'high', early: false }]);
  expect(result.scansHit).toBe(0);
  expect(result.eyesStomped).toBe(2);
});

test('boost jams the Eye once and a board stomp refreshes both tricks', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    el.setAttribute('data-qa-trick-upgrade', '');
    const g = el.game;
    const jams = [], stomps = [];
    el.addEventListener('game:drone-jam', e => jams.push(e.detail));
    el.addEventListener('game:drone-stomp', e => stomps.push(e.detail));
    const advanceUntil = predicate => {
      for (let i = 0; i < 1200 && !predicate(g.result().stats) && !g.over(); i++) g.update(1 / 120);
      return g.result().stats;
    };
    g.start();
    const before = advanceUntil(stats => stats.eye?.canJam);
    g.input('boost', true);
    const jam = advanceUntil(stats => stats.eyesJammed === 1);
    g.input('up', true);
    g.input('up', false);
    for (let i = 0; i < 16; i++) g.update(1 / 120);
    g.input('trick', true);
    g.input('trick', false);
    for (let i = 0; i < 16; i++) g.update(1 / 120);
    g.input('trick', true);
    g.input('trick', false);
    const spent = g.result().stats;
    g.input('boost', false);
    const stomp = advanceUntil(stats => stats.eyesStomped === 1);
    return { before, jam, spent, stomp, jams, stomps };
  });
  expect(result.jams).toHaveLength(1);
  expect(result.before.eye.canJam).toBe(true);
  expect(result.jams[0].sprayCost).toBe(.08);
  expect(result.jam.sprayGauge).toBeLessThanOrEqual(result.before.sprayGauge - .08);
  expect(result.spent).toMatchObject({ tricksUsed: 2, boostActive: true, combo: 3 });
  expect(result.stomps).toHaveLength(1);
  expect(result.stomps[0]).toMatchObject({ jammed: true, combo: 4, tricksReset: true });
  expect(result.stomp).toMatchObject({ tricksUsed: 0, trickAvailable: true, scansHit: 0 });
});

test('street run starts with drones locked and ollie height is stable across frame rates', async ({ page }) => {
  await page.goto('/games/grind-the-terms/demo/embed.html');
  const game = page.locator('grind-the-terms');
  await expect(game).toHaveAttribute('data-au-art-ready', '');
  const result = await game.evaluate(el => {
    const g = el.game;
    return [30, 60, 120].map(hz => {
      g.start();
      g.input('up', true);
      let apex = 310;
      for (let i = 0; i < hz; i++) {
        g.update(1 / hz);
        apex = Math.min(apex, g.result().stats.boardY);
      }
      return { apex, unlocked: g.result().stats.deliveryUnlocked };
    });
  });
  expect(result.map(row => row.unlocked)).toEqual([false, false, false]);
  expect(Math.max(...result.map(row => row.apex)) - Math.min(...result.map(row => row.apex))).toBeLessThanOrEqual(1);
  expect(result[0].apex).toBeGreaterThanOrEqual(198);
  expect(result[0].apex).toBeLessThanOrEqual(202);
});
