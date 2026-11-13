import { expect, test } from '@playwright/test';

const practice = '/games/grind-the-terms/demo/embed.html?practice=drones';

async function openPractice(page) {
  await page.goto(practice);
  const game = page.locator('grind-the-terms');
  await expect(game).toHaveAttribute('data-au-art-ready', '');
  return game;
}

test('the artwork manifest loads with the private cabinet session', async ({ page, context, baseURL }, info) => {
  test.skip(info.project.name === 'mobile-webkit', 'The WebKit CI browser does not send the loopback cookie fixture.');
  await context.addCookies([{
    url: baseURL, name: 'grind_art_session', value: 'owner', httpOnly: true, sameSite: 'Lax'
  }]);
  let signedIn = false;
  await page.route('**/games/grind-the-terms/skins/au/skin.json', async route => {
    const cookie = await route.request().headerValue('cookie');
    signedIn = (cookie ?? '').split(/;\s*/).includes('grind_art_session=owner');
    if (signedIn) await route.continue();
    else await route.fulfill({ status: 401, body: 'Artwork requires a session.' });
  });
  await openPractice(page);
  expect(signedIn).toBe(true);
});

test('Fony lands on the lime rail attached to the courier sprite', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const g = el.game;
    const read = () => g.result().stats;
    g.start();
    while (read().distancePx < 185 && !g.over()) g.update(1 / 120);
    g.input('up', true);
    for (let n = 0; n < 60 && read().boardY > 206 && !g.over(); n++) g.update(1 / 120);
    g.input('trick', true);
    g.input('trick', false);
    for (let n = 0; n < 120 && !read().grinding && !g.over(); n++) g.update(1 / 120);
    const stats = read();
    const canvas = document.createElement('canvas');
    canvas.width = 640;
    canvas.height = 360;
    const ctx = canvas.getContext('2d');
    const image = ctx.drawImage.bind(ctx), fill = ctx.fillRect.bind(ctx);
    let courier, rail;
    ctx.drawImage = (asset, ...args) => {
      if (asset.src?.endsWith('terms_runner_delivery_drone_v1.webp')) courier = args;
      return image(asset, ...args);
    };
    ctx.fillRect = (x, y, w, h) => {
      if (ctx.fillStyle === '#d7ff00' && w === 73 && h === 4) rail = { x, y };
      return fill(x, y, w, h);
    };
    g.draw(ctx, canvas.width, canvas.height);
    g.input('up', false);
    return { grinding: stats.grinding, boardY: stats.boardY, top: stats.supportTop,
      rail, courier, tricksAfterPop: read().tricksUsed };
  });
  expect(result.grinding).toBe(true);
  expect(result.rail.y).toBe(result.top);
  expect(result.boardY).toBe(Math.round(result.rail.y));
  expect(result.rail.x - result.courier[0]).toBeCloseTo(39, 5);
  expect(result.rail.y - result.courier[1]).toBeCloseTo(20, 5);
  expect(result.tricksAfterPop).toBe(0);
});

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

test('the Cookie Eye only lights and labels the stomp pad once it locks', async ({ page }) => {
  const game = await openPractice(page);
  const frames = await game.evaluate(el => {
    const g = el.game;
    const screen = el.shadowRoot.querySelector('canvas');
    const canvas = document.createElement('canvas');
    canvas.width = screen.width;
    canvas.height = screen.height;
    const ctx = canvas.getContext('2d');
    const drawImage = ctx.drawImage.bind(ctx);
    const fillRect = ctx.fillRect.bind(ctx);
    const fillText = ctx.fillText.bind(ctx);
    const frames = {};
    let frame;
    ctx.drawImage = (asset, ...args) => {
      if (asset.src?.endsWith('terms_cookie_eye_v1.webp')) frame.sprite = args;
      return drawImage(asset, ...args);
    };
    ctx.fillRect = (x, y, width, height) => {
      if (height === 4 && ['#ad9a77', '#d7ff00'].includes(ctx.fillStyle)) {
        frame.pad = { x, y, width, lit: ctx.fillStyle === '#d7ff00' };
      }
      return fillRect(x, y, width, height);
    };
    ctx.fillText = (label, x, y) => {
      if (label === 'STOMP' || label === 'SCANNED / SLOWED') frame.labels.push({ label, y });
      return fillText(label, x, y);
    };
    g.start();
    for (let i = 0; i < 1600 && !g.over() && !frames.retracting; i++) {
      g.update(1 / 120);
      const eye = g.result().stats.eye;
      if (!eye) continue;
      const phase = eye.phase === 'recover' ? (eye.padReady ? 'locked' : eye.age > .04 ? 'opening' : '') :
        eye.phase === 'depart' && eye.age > .08 ? 'retracting' : eye.phase === 'warning' ? 'warning' : '';
      if (!phase || frames[phase]) continue;
      frame = { labels: [] };
      g.draw(ctx, canvas.width, canvas.height);
      frames[phase] = frame;
    }
    return frames;
  });
  expect(frames.warning.sprite).toBeDefined();
  expect(frames.warning.pad).toBeUndefined();
  expect(frames.opening.pad.lit).toBe(false);
  expect(frames.locked.pad).toMatchObject({ lit: true, y: 0 });
  expect(frames.locked.pad.width).toBeGreaterThan(frames.opening.pad.width);
  expect(frames.retracting.pad.lit).toBe(false);
  expect(frames.retracting.pad.width).toBeLessThan(frames.locked.pad.width);
  expect(frames.opening.labels.map(row => row.label)).toEqual(['SCANNED / SLOWED']);
  expect(frames.locked.labels.map(row => row.label)).toEqual(['STOMP', 'SCANNED / SLOWED']);
  expect(frames.locked.labels[1].y).toBeLessThan(frames.locked.labels[0].y);
  expect(frames.retracting.labels).toEqual([]);
});

test('an ollie onto the Cookie Eye uses airborne poses until the board lands', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const game = el.game;
    const screen = el.shadowRoot.querySelector('canvas');
    const canvas = document.createElement('canvas');
    canvas.width = screen.width;
    canvas.height = screen.height;
    const ctx = canvas.getContext('2d');
    const image = ctx.drawImage.bind(ctx);
    const fill = ctx.fillRect.bind(ctx);
    let pose;
    let pad;
    ctx.drawImage = (asset, ...args) => {
      if (args.length === 8 && asset.src?.includes('fony_gameplay_atlas_')) {
        pose = {
          cell: (args[1] / 128) * 8 + args[0] / 128,
          actionAtlas: asset.src.endsWith('fony_gameplay_atlas_v2.webp'),
          boardY: args[5] + 117
        };
      }
      return image(asset, ...args);
    };
    ctx.fillRect = (x, y, w, h) => {
      if (w === 46 && h === 4 && ctx.fillStyle === '#d7ff00') {
        const { a, d, e, f } = ctx.getTransform();
        pad = { left: x + (e - origin.e) / a, right: x + w + (e - origin.e) / a, top: y + (f - origin.f) / d };
      }
      return fill(x, y, w, h);
    };
    let origin;
    const setTransform = ctx.setTransform.bind(ctx);
    ctx.setTransform = (...args) => {
      setTransform(...args);
      origin = ctx.getTransform();
    };
    const read = () => game.result().stats;
    game.start();
    for (let i = 0; i < 1200 && !read().eye?.padReady && !game.over(); i++) game.update(1 / 120);
    const ready = read();
    game.draw(ctx, canvas.width, canvas.height);
    const target = pad;
    game.input('up', true);
    game.input('up', false);
    const airborne = [];
    let landing;
    for (let i = 0; i < 180 && !game.over(); i++) {
      game.update(1 / 120);
      const stats = read();
      if (i % 4 !== 0 && !stats.eyesStomped && stats.boardY < ready.boardY) continue;
      game.draw(ctx, canvas.width, canvas.height);
      if (stats.eyesStomped) landing ??= pose;
      if (stats.boardY === ready.boardY) break;
      if (!stats.eyesStomped) airborne.push(pose);
    }
    return { ready, target, airborne, landing, ground: pose, after: read() };
  });
  expect(result.ready.eye.padReady).toBe(true);
  expect(result.ready.scansHit).toBe(1);
  expect(result.target.left).toBeLessThan(140 + 14);
  expect(result.target.right).toBeGreaterThan(140);
  expect(result.airborne.every(pose => pose.actionAtlas)).toBe(true);
  expect([...new Set(result.airborne.map(pose => pose.cell))]).toEqual([11, 12, 10, 13]);
  expect(result.landing).toMatchObject({ actionAtlas: true, cell: 12 });
  expect(result.landing.boardY).toBeCloseTo(result.target.top - 2, 4);
  expect(result.ground).toMatchObject({ actionAtlas: true, cell: 14, boardY: result.ready.boardY });
  expect(result.after.eyesStomped).toBe(1);
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
