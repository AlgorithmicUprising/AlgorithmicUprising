import { expect, test } from '@playwright/test';

const practice = '/games/grind-the-terms/demo/embed.html?practice=drones';

async function openPractice(page) {
  await page.goto(practice);
  const game = page.locator('grind-the-terms');
  await expect(game).toHaveAttribute('data-au-art-ready', '');
  return game;
}

test('steering keeps its position without changing scroll pace or the courier flight', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const g = el.game;
    const read = () => g.result().stats;
    const tick = steps => { for (let i = 0; i < steps; i++) g.update(1 / 120); };
    const canvas = document.createElement('canvas');
    const screen = el.shadowRoot.querySelector('canvas');
    canvas.width = screen.width;
    canvas.height = screen.height;
    const ctx = canvas.getContext('2d');
    const drawImage = ctx.drawImage.bind(ctx);
    let courier;
    ctx.drawImage = (asset, ...args) => {
      if (asset.src?.endsWith('terms_runner_delivery_drone_v1.webp')) courier = args;
      return drawImage(asset, ...args);
    };
    const render = () => {
      g.draw(ctx, canvas.width, canvas.height);
      return { ...read(), courier };
    };
    g.start();
    tick(96);
    const neutral = render();
    g.start();
    g.input('right', true);
    tick(96);
    const forward = render();
    g.input('right', false);
    tick(24);
    const released = read();
    g.input('left', true);
    tick(8);
    g.releaseInput();
    const beforeTick = read();
    tick(24);
    const afterTick = read();
    g.start();
    return { neutral, forward, released, beforeTick, afterTick, reset: read() };
  });
  expect(result.neutral.courier).toBeDefined();
  expect(result.forward.courier).toEqual(result.neutral.courier);
  expect(result.forward.playerX).toBeGreaterThan(result.neutral.playerX + 100);
  expect(result.forward.distancePx).toBe(result.neutral.distancePx);
  expect(result.forward.runSpeed).toBe(result.neutral.runSpeed);
  expect(result.released.playerX).toBe(result.forward.playerX);
  expect(result.beforeTick.playerX).toBeLessThan(result.released.playerX);
  expect(result.afterTick.playerX).toBe(result.beforeTick.playerX);
  expect(result.reset.playerX).toBe(result.neutral.playerX);
});

test('the desktop arrows steer while held and pause clears the held input', async ({ page }, info) => {
  test.skip(info.project.name !== 'desktop-chromium', 'Desktop keyboard bindings.');
  const game = await openPractice(page);
  const x = () => game.evaluate(el => el.game.result().stats.playerX);
  await game.locator('button[part=start]').click();
  const start = await x();
  try {
    await page.keyboard.down('ArrowRight');
    await expect.poll(x).toBeGreaterThan(start + 20);
    await page.keyboard.press('Escape');
    await page.keyboard.press('Escape');
    const resumed = await x();
    await game.evaluate(el => el.game.update(.05));
    expect(await x()).toBe(resumed);
  } finally {
    await page.keyboard.up('ArrowRight');
  }
  try {
    const beforeLeft = await x();
    await page.keyboard.down('ArrowLeft');
    await expect.poll(x).toBeLessThan(beforeLeft);
  } finally {
    await page.keyboard.up('ArrowLeft');
  }
});

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

test('the Cookie Eye locks its scan and lights only its roof during recovery', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const g = el.game;
    const screen = el.shadowRoot.querySelector('canvas');
    const canvas = document.createElement('canvas');
    canvas.width = screen.width;
    canvas.height = screen.height;
    const ctx = canvas.getContext('2d');
    const drawImage = ctx.drawImage.bind(ctx);
    const fillRect = ctx.fillRect.bind(ctx);
    const fillText = ctx.fillText.bind(ctx);
    const strokeRect = ctx.strokeRect.bind(ctx);
    let frame;
    ctx.drawImage = (asset, ...args) => {
      if (asset.src?.endsWith('terms_cookie_eye_v1.webp')) frame.sprite = args;
      return drawImage(asset, ...args);
    };
    ctx.fillRect = (x, y, width, height) => {
      if (width === 44 && height === 3 && ctx.fillStyle === '#d7ff00') frame.roofLight = { x, y, width };
      return fillRect(x, y, width, height);
    };
    ctx.fillText = (label, x, y) => {
      if (label === 'STOMP' || label === 'SCANNED / SLOWED') frame.labels.push({ label, y });
      return fillText(label, x, y);
    };
    ctx.strokeRect = (x, y, width, height) => {
      if (width === 155 && height === 43) frame.scan = { x, y, width, height };
      return strokeRect(x, y, width, height);
    };
    const render = () => {
      frame = { labels: [] };
      g.draw(ctx, canvas.width, canvas.height);
      return frame;
    };
    const next = predicate => {
      for (let i = 0; i < 1400 && !predicate(g.result().stats) && !g.over(); i++) g.update(1 / 120);
      return g.result().stats;
    };
    g.start();
    const first = next(stats => stats.eye?.phase === 'warning');
    const warning = render();
    g.input('left', true);
    const repositioned = next(stats => stats.playerX <= 84);
    g.input('left', false);
    const warningAfterSteering = render();
    const firing = next(stats => stats.eye?.phase === 'scan');
    const scan = render();
    const opened = next(stats => stats.eye?.roof.ready);
    const recovery = render();
    next(stats => stats.eye?.phase === 'depart');
    const depart = render();
    return { first, warning, repositioned, warningAfterSteering, firing, scan, opened, recovery, depart };
  });
  expect(result.warning.sprite).toBeDefined();
  expect(result.warning.roofLight).toBeUndefined();
  expect(result.warningAfterSteering.scan).toEqual(result.warning.scan);
  expect(result.scan.scan).toEqual(result.warning.scan);
  expect(result.repositioned.eye.roof).toEqual(result.first.eye.roof);
  expect(result.firing.eye.roof).toEqual(result.first.eye.roof);
  expect(result.opened.eye.roof).toEqual({ ...result.first.eye.roof, ready: true });
  expect(result.recovery.roofLight).toEqual({ x: -22, y: 4, width: 44 });
  expect(result.recovery.labels[0].label).toBe('STOMP');
  expect(result.depart.roofLight).toBeUndefined();
  expect(result.depart.labels).toEqual([]);
});

test('baiting the Cookie Eye low leaves a roof Fony can steer onto with one ollie', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const game = el.game;
    const screen = el.shadowRoot.querySelector('canvas');
    const canvas = document.createElement('canvas');
    canvas.width = screen.width;
    canvas.height = screen.height;
    const ctx = canvas.getContext('2d');
    const image = ctx.drawImage.bind(ctx);
    let pose;
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
    const read = () => game.result().stats;
    game.start();
    for (let i = 0; i < 1200 && !game.over(); i++) {
      if (read().eye?.phase === 'warning' && read().eye.age >= .8) break;
      game.update(1 / 120);
    }
    const warning = read();
    game.input('up', true);
    game.input('up', false);
    game.input('right', true);
    const airborne = [];
    let landing;
    let released = false;
    for (let i = 0; i < 220 && !game.over(); i++) {
      game.update(1 / 120);
      const stats = read();
      if (!released && stats.playerX >= warning.eye.roof.left + 11) {
        released = true;
        game.input('right', false);
      }
      if (i % 4 !== 0 && !stats.eyesStomped && stats.boardY < warning.boardY) continue;
      game.draw(ctx, canvas.width, canvas.height);
      if (stats.eyesStomped) landing ??= pose;
      if (stats.boardY === warning.boardY) break;
      if (!stats.eyesStomped) airborne.push(pose);
    }
    return { warning, airborne, landing, ground: pose, after: read() };
  });
  expect(result.warning.eye.lane).toBe('low');
  expect(result.warning.eye.roof.left).toBeGreaterThan(result.warning.playerX + 50);
  expect(result.airborne.every(pose => pose.actionAtlas)).toBe(true);
  expect([...new Set(result.airborne.map(pose => pose.cell))]).toEqual([11, 12, 10, 13]);
  expect(result.landing).toMatchObject({ actionAtlas: true, cell: 12 });
  expect(result.landing.boardY).toBeCloseTo(result.warning.eye.roof.y - 2, 4);
  expect(result.ground).toMatchObject({ actionAtlas: true, cell: 14, boardY: result.warning.boardY });
  expect(result.after).toMatchObject({ eyesStomped: 1, scansHit: 0, tricksUsed: 0 });
  expect(result.after.playerX).toBeGreaterThan(result.warning.eye.roof.left);
});

test('an airborne approach holds the Eye high and a trick reaches its vulnerable roof', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const g = el.game;
    const read = () => g.result().stats;
    const until = predicate => {
      for (let i = 0; i < 1400 && !predicate(read()) && !g.over(); i++) g.update(1 / 120);
      return read();
    };
    const tap = key => { g.input(key, true); g.input(key, false); };
    g.start();
    until(stats => stats.eye?.phase === 'approach' && stats.eye.age >= .47);
    tap('up');
    const warning = until(stats => stats.eye?.phase === 'warning');
    const recovery = until(stats => stats.eye?.roof.ready);
    tap('up');
    const ollie = until(stats => stats.boardY <= 204);
    tap('trick');
    const trick = until(stats => stats.boardY < recovery.eye.roof.y - 6);
    g.input('right', true);
    until(stats => stats.playerX >= recovery.eye.roof.left + 11);
    g.input('right', false);
    const stomp = until(stats => stats.eyesStomped === 1 || stats.eye?.phase === 'depart');
    return { warning, recovery, ollie, trick, stomp };
  });
  expect(result.warning.eye.lane).toBe('high');
  expect(result.recovery.eye.roof).toEqual({ ...result.warning.eye.roof, ready: true });
  expect(result.ollie.boardY).toBeGreaterThan(result.recovery.eye.roof.y);
  expect(result.trick.boardY).toBeLessThan(result.recovery.eye.roof.y);
  expect(result.trick.tricksUsed).toBe(1);
  expect(result.stomp).toMatchObject({ combo: 3, eyesStomped: 1, scansHit: 0, tricksUsed: 0, trickAvailable: true });
});

test('the Eye offers a reachable roof when Fony hugs the forward limit', async ({ page }) => {
  const game = await openPractice(page);
  const result = await game.evaluate(el => {
    const g = el.game;
    const read = () => g.result().stats;
    const until = predicate => {
      for (let i = 0; i < 1400 && !predicate(read()) && !g.over(); i++) g.update(1 / 120);
      return read();
    };
    g.start();
    g.input('right', true);
    for (let i = 0; i < 100; i++) g.update(1 / 120);
    g.input('right', false);
    const warning = until(stats => stats.eye?.phase === 'warning' && stats.eye.age >= .8);
    g.input('up', true);
    g.input('up', false);
    g.input('left', true);
    until(stats => stats.playerX < warning.eye.roof.right - 8);
    g.input('left', false);
    const stomp = until(stats => stats.eyesStomped === 1 || stats.eye?.phase === 'depart');
    return { warning, stomp };
  });
  expect(result.warning.eye.roof.right).toBeLessThan(result.warning.playerX - 30);
  expect(result.stomp).toMatchObject({ eyesStomped: 1, scansHit: 0 });
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
  expect(result.eyesStomped).toBe(0);
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
    g.input('right', true);
    const spent = advanceUntil(stats => stats.playerX >= jam.eye.roof.left + 10);
    g.input('right', false);
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
