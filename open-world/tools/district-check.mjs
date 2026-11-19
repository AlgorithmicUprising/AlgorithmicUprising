// M0 browser smoke test for district packs (Nov 18 2026). Serves the staged composite, then in headless Chrome:
//  1. /open-world/?district=test_district&district_demo=1 with the pack response held back 2.5 s: the loading card
//     shows while Fony keeps rolling east down Rust Avenue, the pack mounts, the district appears, the visit counts,
//     and his speed does not dip at the edge.
//  2. Same URL with the pack request aborted: the "no signal" card shows and he keeps rolling onto the apron.
//  3. /open-world/ with no flag: no district is armed (free roam unchanged).
// Screenshots go to AU_BROWSER_OUT (default /tmp/hq-district). Run after export-web + stage-composite.
import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const world = join(dirname(fileURLToPath(import.meta.url)), '..');
const port = Number(process.env.PORT || 8093);
const base = `http://127.0.0.1:${port}`;
const outDir = process.env.AU_BROWSER_OUT || '/tmp/hq-district';
await mkdir(outDir, { recursive: true });
const server = spawn(process.execPath, ['tools/serve-composite.mjs'], { cwd: world, env: { ...process.env, PORT: String(port) }, stdio: 'ignore' });
await waitForServer();
const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
const failures = [];
const results = {};
try {
  results.ok = await run('ok', async (route) => { await new Promise((r) => setTimeout(r, 2500)); await route.continue(); });
  results.fail = await run('fail', async (route) => { await route.abort('failed'); });
  results.plain = await plain();
} catch (error) {
  failures.push(error.stack || String(error));
} finally {
  await browser.close();
  server.kill();
}
console.log(JSON.stringify(results, null, 2));
if (failures.length) {
  console.error(failures.join('\n'));
  process.exit(1);
}
console.log('district-check ok');

async function run(name, handler) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const logs = [];
  page.on('console', (msg) => logs.push(msg.type() + ': ' + msg.text()));
  page.on('pageerror', (error) => logs.push('pageerror: ' + error.message));
  let packRequests = 0;
  await page.route('**/districts/*.pck', (route) => { packRequests += 1; return handler(route); });
  await page.goto(base + '/open-world/?district=test_district&district_demo=1', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForFunction(() => window.AU_HQ && window.AU_HQ.session === 'world' && window.AU_DISTRICT, { timeout: 60000 });
  const samples = [];
  let shotLoading = false;
  const started = Date.now();
  while (Date.now() - started < 30000) {
    const s = await page.evaluate(() => ({ t: performance.now(), x: window.AU_HQ.x, y: window.AU_HQ.y, z: window.AU_HQ.z, zone: window.AU_HQ.zone, skating: window.AU_HQ.skating, input: window.AU_HQ.input, paused: window.AU_HQ.paused, ...window.AU_DISTRICT }));
    samples.push(s);
    if (!shotLoading && s.x > 45 && ['fetching', 'failed', 'mounting', 'instancing'].includes(s.state)) {
      await page.screenshot({ path: join(outDir, `district-${name}-card.png`) });
      shotLoading = true;
    }
    if (s.x > 100) break;
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(600);
  await page.screenshot({ path: join(outDir, `district-${name}-after.png`) });
  const last = await page.evaluate(() => ({ ...window.AU_HQ, district: { ...window.AU_DISTRICT } }));
  await page.close();
  // Speed from position samples (m/s) around the edge (x 60..80) versus before it (x 45..60).
  const speed = (lo, hi) => {
    const v = [];
    for (let i = 1; i < samples.length; i++) {
      const a = samples[i - 1], b = samples[i];
      const d = Math.hypot(b.x - a.x, b.z - a.z);
      if (a.x >= lo && b.x <= hi && d < 4 && b.t > a.t) v.push(Math.hypot(b.x - a.x, b.z - a.z) / ((b.t - a.t) / 1000));
    }
    return v.length ? { min: +Math.min(...v).toFixed(2), mean: +(v.reduce((s, x) => s + x, 0) / v.length).toFixed(2), n: v.length } : null;
  };
  // Game-side speed (the body's velocity each physics tick, read from AU_DISTRICT.speed) around the edge.
  const body = samples.filter((s) => typeof s.speed === 'number' && s.px >= 60 && s.px <= 85).map((s) => s.speed);
  const bodyBefore = samples.filter((s) => typeof s.speed === 'number' && s.px >= 45 && s.px < 60).map((s) => s.speed);
  const gameSpeed = { beforeMin: bodyBefore.length ? Math.min(...bodyBefore) : null, edgeMin: body.length ? Math.min(...body) : null, n: body.length };
  // Wall-clock frame stalls: the longest gap between successive physics ticks seen by the page.
  let stallMs = 0;
  for (let i = 1; i < samples.length; i++) {
    const a = samples[i - 1], b = samples[i];
    if (typeof a.tick === 'number' && typeof b.tick === 'number' && b.tick === a.tick) stallMs = Math.max(stallMs, b.t - a.t);
  }
  const before = speed(45, 60);
  const edge = speed(60, 85);
  const states = [...new Set(samples.map((s) => s.state))];
  const out = { packRequests, states, before, edge, gameSpeed, stallMs: Math.round(stallMs), final: { x: last.x, y: last.y, zone: last.zone, skating: last.skating, input: last.input, paused: last.paused, district: last.district }, fatal: logs.filter((l) => /pageerror|SCRIPT ERROR/i.test(l)) };
  if (out.fatal.length) failures.push(name + ': page errors ' + out.fatal.join(' | '));
  if (!shotLoading) failures.push(name + ': never saw the loading state while rolling');
  if (!(last.x > 90) || last.y < -1) failures.push(name + ': Fony did not roll into the district area ' + JSON.stringify(out.final));
  if (!last.skating || !last.input || last.paused) failures.push(name + ': skating/input/pause changed');
  // Momentum is judged on the body's own velocity (game time). Screen-space speed from wall-clock samples is reported
  // too; under SwiftShader a frame stall can show up there without any change in the game.
  if (gameSpeed.edgeMin == null || gameSpeed.beforeMin == null || gameSpeed.edgeMin < gameSpeed.beforeMin * 0.85) failures.push(name + ': body speed dipped at the edge ' + JSON.stringify(gameSpeed));
  if (name === 'ok') {
    if (last.district.state !== 'ready' || last.district.visits < 1 || last.zone !== 'TEST DISTRICT' || last.district.card !== 'test_intro') failures.push('ok: district not ready/visited ' + JSON.stringify(last.district) + ' zone ' + last.zone);
  } else if (last.district.state !== 'failed') {
    failures.push('fail: expected a failed state ' + JSON.stringify(last.district));
  }
  return out;
}

async function plain() {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  // ?play=free: straight past the start screen into free roam (the plain URL opens the title menu).
  await page.goto(base + '/open-world/?play=free', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForFunction(() => window.AU_HQ && window.AU_HQ.session === 'world', { timeout: 60000 });
  await page.waitForTimeout(1500);
  const r = await page.evaluate(() => ({ district: window.AU_DISTRICT || null, zone: window.AU_HQ.zone }));
  await page.screenshot({ path: join(outDir, 'district-plain.png') });
  await page.close();
  if (r.district !== null) failures.push('plain: a district armed without a flag ' + JSON.stringify(r));
  if (r.zone !== 'SKATE YARD') failures.push('plain: spawn zone changed ' + r.zone);
  return r;
}

function waitForServer() {
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const timer = setInterval(async () => {
      try {
        if ((await fetch(base + '/')).status === 200) { clearInterval(timer); resolve(); }
      } catch { /* not up yet */ }
      if (Date.now() - started > 10000) { clearInterval(timer); reject(new Error('server did not start')); }
    }, 200);
  });
}
