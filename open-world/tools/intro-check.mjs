// Act I intro wiring check (Nov 19 2026). Serves the staged composite (node tools/stage-composite.mjs first) and drives
// the real start screen in headless Google Chrome (H.264 needs the branded build, channel 'chrome'):
//   A. default: New Game -> the intro streams from the site (hosted 720p cut; the absent AU_INTRO_MP4 copy 404s first),
//      readyState >= 3, currentTime advancing, a seek to 45 s lands and keeps playing, hold-to-skip -> P.1.
//   B. ?intro=<a URL that never answers>  -> the load timeout gives up -> in-production card -> P.1.
//   C. ?intro=<a 404>                      -> error -> in-production card -> P.1.
//   D. ?intro=<a stream that stops mid-file> -> stall watchdog -> TRY AGAIN / SKIP INTRO -> carries on to P.1 by itself.
//   E. autoplay blocked even muted (play() rejected twice) -> TAP TO PLAY -> tap -> plays.
//   F. autoplay blocked -> SKIP INTRO button -> P.1.
// Screenshots + intro-check.json go to AU_INTRO_OUT (default /workspace/pz-frontend-evidence). Deploys nothing.
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { createReadStream, statSync, existsSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const world = join(dirname(fileURLToPath(import.meta.url)), '..');
const port = Number(process.env.PORT || 8099);
const trapPort = port + 1;
const base = `http://127.0.0.1:${port}`;
const trap = `http://127.0.0.1:${trapPort}`;
const outDir = process.env.AU_INTRO_OUT || '/workspace/pz-frontend-evidence';
const only = (process.env.AU_INTRO_ONLY || '').split(',').filter(Boolean);
const HOSTED = 'https://algorithmicuprising.com/media/uploads/1cd5a1cf-88d7-4fa3-a7b6-1832f0fae11f-pz-intro-web-720p.mp4';
// a real faststart MP4 for the mid-file stall (the local web cut if it is on this machine, else the export placeholder)
const stallSrc = [process.env.AU_INTRO_LOCAL, '/workspace/pz-intro/out/pz-intro-web-720p.mp4', join(world, 'build', 'pages-composite', 'open-world', 'media', 'intro', 'intro-placeholder.mp4')].find((p) => p && existsSync(p));
await mkdir(outDir, { recursive: true });

// the trap server: /hang.mp4 never answers; /stall.mp4 sends the first part of a real clip, then goes silent
const hung = [];
const trapServer = createServer((req, res) => {
  if (req.url.startsWith('/hang')) { hung.push(res); return; }
  if (req.url.startsWith('/stall')) {
    const size = statSync(stallSrc).size;
    const cut = Math.min(size, Math.max(400000, Math.floor(size * 0.06)));
    res.writeHead(200, { 'Content-Type': 'video/mp4', 'Content-Length': String(size), 'Access-Control-Allow-Origin': '*' });
    const rs = createReadStream(stallSrc, { start: 0, end: cut - 1 });
    rs.on('data', (c) => res.write(c));
    rs.on('end', () => hung.push(res));
    return;
  }
  res.writeHead(404).end('not here');
});
await new Promise((r) => trapServer.listen(trapPort, '127.0.0.1', r));
const server = spawn(process.execPath, ['tools/serve-composite.mjs'], { cwd: world, env: { ...process.env, PORT: String(port) }, stdio: 'ignore' });
await waitForServer();
const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
const report = { hosted: HOSTED, stallSrc, scenarios: {}, logs: [] };
const failures = [];
try {
  if (want('A')) await scenarioDefault();
  if (want('B')) await scenarioFallback('B-never-answers', trap + '/hang.mp4', 'missing', 'intro-fallback-load-timeout-card');
  if (want('C')) await scenarioFallback('C-404', trap + '/nope.mp4', 'missing', 'intro-fallback-404-card');
  if (want('D')) await scenarioStall();
  if (want('E')) await scenarioBlocked('E-tap-to-play', 'tap');
  if (want('F')) await scenarioBlocked('F-blocked-skip', 'skip');
} catch (error) {
  failures.push('error: ' + (error.stack || String(error)));
} finally {
  await browser.close();
  server.kill();
  for (const r of hung) { try { r.destroy(); } catch { /* gone */ } }
  trapServer.close();
  report.failures = failures;
  await writeFile(join(outDir, 'intro-check.json'), JSON.stringify(report, null, 2));
}
console.log(failures.length ? 'FAIL\n' + failures.join('\n') : 'intro-check ok');
process.exit(failures.length ? 1 : 0);

function want(k) { return only.length === 0 || only.includes(k); }

async function open(query = '', init = null) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  if (init) await context.addInitScript(init);
  const page = await context.newPage();
  page.on('console', (m) => report.logs.push(m.type() + ': ' + m.text()));
  page.on('pageerror', (e) => report.logs.push('pageerror: ' + e.message));
  await page.goto(base + '/open-world/' + query, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await waitFor(page, () => window.AU_TITLE && window.AU_TITLE.title === true, 90000, 'title screen');
  await page.waitForTimeout(800);
  await page.mouse.click(640, 120);
  await waitFor(page, () => window.AU_TITLE.title === false && window.AU_TITLE.focus === 'Menu_new', 5000, 'menu');
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.AU_TITLE.panel === 'name', 3000, 'name panel');
  await page.keyboard.press('Enter');
  return { context, page };
}

function video(page) {
  return page.evaluate(() => {
    const v = document.querySelector('#pz-intro video');
    const s = window.PZ_INTRO || {};
    return { state: s.state, reason: s.reason, fallback: s.fallback, src: s.src, tried: s.tried, errors: s.errors, stalls: s.stalls,
      currentSrc: v ? v.currentSrc : '', t: v ? v.currentTime : -1, rs: v ? v.readyState : -1, dur: v ? v.duration : 0, paused: v ? v.paused : null, muted: v ? v.muted : null,
      w: v ? v.videoWidth : 0, h: v ? v.videoHeight : 0, buffered: v && v.buffered.length ? [v.buffered.start(0), v.buffered.end(v.buffered.length - 1)] : [] };
  });
}

async function scenarioDefault() {
  const r = report.scenarios['A-default-hosted'] = { steps: [] };
  const { context, page } = await open();
  await waitFor(page, () => window.PZ_INTRO && window.PZ_INTRO.state === 'playing', 45000, 'hosted intro playing');
  const a = await video(page);
  await page.waitForTimeout(3000);
  const b = await video(page);
  r.steps.push({ at: 'start', ...a }, { at: '+3s', ...b });
  check(r, 'the default source is the hosted cut on the site', a.src === HOSTED && a.currentSrc.startsWith('https://algorithmicuprising.com/media/uploads/'), a);
  check(r, 'the missing AU_INTRO_MP4 copy was tried first and skipped', (a.tried || [])[0] === 'media/intro/project-zero-intro-720p.mp4' && (a.errors || []).length >= 1, a.tried);
  check(r, 'readyState >= 3 (HAVE_FUTURE_DATA) and 1280x720', b.rs >= 3 && b.w === 1280 && b.h === 720, b);
  check(r, 'currentTime advances (%s -> %s)'.replace('%s', a.t.toFixed(2)).replace('%s', b.t.toFixed(2)), b.t > a.t + 2.0 && !b.paused, { a: a.t, b: b.t });
  check(r, 'duration is the 90 s cut', Math.abs(b.dur - 90) < 1.0, b.dur);
  await shot(page, 'intro-hosted-playing');
  await page.evaluate(() => { document.querySelector('#pz-intro video').currentTime = 45; });
  await page.waitForTimeout(600);
  const c = await video(page);
  await page.waitForTimeout(2500);
  const d = await video(page);
  r.steps.push({ at: 'seek 45', ...c }, { at: 'seek +2.5s', ...d });
  check(r, 'seeking to 45 s works (byte ranges) and keeps playing', c.t >= 44.9 && d.t > c.t + 1.5 && d.rs >= 3 && !d.paused, { c: c.t, d: d.t });
  await shot(page, 'intro-hosted-seeked-45s');
  await page.evaluate(() => { document.querySelector('#pz-intro video').currentTime = 82; });
  await page.waitForTimeout(2500);
  const e = await video(page);
  r.steps.push({ at: 'seek 82', ...e });
  await shot(page, 'intro-hosted-82s-phone-text');
  check(r, 'seeking near the end (82 s) works', e.t > 82.5 && e.rs >= 3, e.t);
  await page.keyboard.down('Space');
  await page.waitForTimeout(1300);
  await page.keyboard.up('Space');
  await waitFor(page, () => window.PZ_INTRO.state === 'done' && window.AU_STORY && window.AU_STORY.active, 60000, 'P.1 after hold-to-skip');
  const f = await page.evaluate(() => ({ intro: { ...window.PZ_INTRO }, story: window.AU_STORY }));
  check(r, 'hold-to-skip hands off to P.1', f.intro.reason === 'skipped' && f.story.active, f);
  await page.waitForTimeout(1500);
  await shot(page, 'intro-hosted-then-p1');
  await context.close();
}

async function scenarioFallback(name, url, reason, shotName) {
  const r = report.scenarios[name] = { steps: [] };
  const { context, page } = await open('?intro=' + encodeURIComponent(url));
  await waitFor(page, () => window.PZ_INTRO && window.PZ_INTRO.state === 'card', 40000, name + ' card');
  await page.waitForTimeout(400);
  await shot(page, shotName);
  await waitFor(page, () => window.PZ_INTRO.state === 'done' && window.AU_STORY && window.AU_STORY.active, 30000, name + ' -> P.1');
  const s = await page.evaluate(() => ({ ...window.PZ_INTRO }));
  r.steps.push(s);
  check(r, 'falls back to the card and carries on to P.1 (' + reason + ')', s.reason === reason, s);
  await context.close();
}

async function scenarioStall() {
  const r = report.scenarios['D-stall'] = { steps: [] };
  const { context, page } = await open('?intro=' + encodeURIComponent(trap + '/stall.mp4'));
  await waitFor(page, () => window.PZ_INTRO && window.PZ_INTRO.state === 'playing', 30000, 'stall clip playing');
  await waitFor(page, () => window.PZ_INTRO.fallback === 'stall', 60000, 'stall watchdog');
  const s = await video(page);
  r.steps.push(s);
  check(r, 'a stalled stream shows TRY AGAIN / SKIP INTRO', s.fallback === 'stall' && await page.locator('#pz-intro-skip').isVisible() && (await page.locator('#pz-intro-play').textContent()).includes('TRY AGAIN'), s);
  await shot(page, 'intro-fallback-stalled');
  await waitFor(page, () => window.PZ_INTRO.state === 'done' && window.AU_STORY && window.AU_STORY.active, 40000, 'stall -> P.1 by itself');
  const e = await page.evaluate(() => ({ ...window.PZ_INTRO }));
  check(r, 'with no answer, the game carries on to P.1 by itself (stalled)', e.reason === 'stalled', e);
  await context.close();
}

async function scenarioBlocked(name, action) {
  const r = report.scenarios[name] = { steps: [] };
  const init = () => {
    window.__pzBlockPlays = 2;   // the first play() (with sound) and the muted retry are both refused
    const real = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () {
      if (this.closest && this.closest('#pz-intro') && window.__pzBlockPlays > 0) { window.__pzBlockPlays--; return Promise.reject(new DOMException('autoplay blocked (test)', 'NotAllowedError')); }
      return real.call(this);
    };
  };
  const { context, page } = await open('', init);
  await waitFor(page, () => window.PZ_INTRO && window.PZ_INTRO.fallback === 'tap', 30000, 'TAP TO PLAY');
  const s = await video(page);
  r.steps.push(s);
  check(r, 'blocked autoplay shows TAP TO PLAY with SKIP INTRO', (await page.locator('#pz-intro-play').textContent()).includes('TAP TO PLAY') && await page.locator('#pz-intro-skip').isVisible(), s);
  await shot(page, action === 'tap' ? 'intro-fallback-tap-to-play' : 'intro-fallback-blocked-skip');
  if (action === 'tap') {
    await page.locator('#pz-intro-play').click();
    await waitFor(page, () => window.PZ_INTRO.state === 'playing' && window.PZ_INTRO.fallback === '', 30000, 'playing after the tap');
    const a = await video(page);
    await page.waitForTimeout(2500);
    const b = await video(page);
    r.steps.push(a, b);
    check(r, 'the tap starts the intro with sound and it advances', b.t > a.t + 1.5 && b.muted === false, { a: a.t, b: b.t, muted: b.muted });
    await shot(page, 'intro-after-tap-playing');
  } else {
    await page.locator('#pz-intro-skip').click();
    await waitFor(page, () => window.PZ_INTRO.state === 'done' && window.AU_STORY && window.AU_STORY.active, 30000, 'skip -> P.1');
    const e = await page.evaluate(() => ({ ...window.PZ_INTRO }));
    check(r, 'SKIP INTRO goes straight to P.1', e.reason === 'skipped', e);
  }
  await context.close();
}

function check(r, name, cond, detail) {
  r.steps.push({ check: name, ok: !!cond, detail });
  console.log((cond ? 'ok ' : 'not ok ') + name);
  if (!cond) failures.push(name + ' ' + JSON.stringify(detail));
}
async function shot(page, name) {
  const file = name + '.png';
  await page.screenshot({ path: join(outDir, file) });
  report.logs.push('shot: ' + file);
}
async function waitFor(page, fn, ms, what) {
  try {
    await page.waitForFunction(fn, null, { timeout: ms, polling: 100 });
  } catch {
    const state = await page.evaluate(() => ({ title: window.AU_TITLE, story: window.AU_STORY, intro: window.PZ_INTRO }));
    await page.screenshot({ path: join(outDir, 'intro-timeout-' + what.replace(/\W+/g, '-') + '.png') });
    throw new Error('timed out: ' + what + ' ' + JSON.stringify(state));
  }
}
function waitForServer() {
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const timer = setInterval(async () => {
      try {
        const r = await fetch(base + '/');
        if (r.status === 200) { clearInterval(timer); resolve(); }
      } catch { /* not up */ }
      if (Date.now() - started > 10000) { clearInterval(timer); reject(new Error('server did not start')); }
    }, 200);
  });
}
