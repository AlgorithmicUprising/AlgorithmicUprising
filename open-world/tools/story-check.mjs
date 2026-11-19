// M1 (Nov 19 2026): P.1 Practice Run in the web export, for review. Serves the staged composite, then
//   part A: real keyboard input from ?story=p1 (P.1 opening line, push, kick up, drop on, ollie, the hesitation prompt,
//           T back to the quarter-pipe checkpoint and riding it, the rail),
//   part B: ?story=p1&story_demo=1, the review autopilot playing the whole of P.1, recorded as video.
// Writes screenshots, a video and story-check.json to AU_STORY_OUT. Does not deploy anything.
import { spawn } from 'node:child_process';
import { mkdir, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const world = join(dirname(fileURLToPath(import.meta.url)), '..');
const port = Number(process.env.PORT || 8097);
const base = `http://127.0.0.1:${port}`;
const outDir = process.env.AU_STORY_OUT || '/tmp/story-check';
const only = process.env.AU_STORY_PART || 'AB';
await mkdir(outDir, { recursive: true });

const server = spawn(process.execPath, ['tools/serve-composite.mjs'], { cwd: world, env: { ...process.env, PORT: String(port) }, stdio: 'ignore' });
await waitForServer();
const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
const report = { a: [], b: [], logs: [] };
let failed = false;
try {
  if (only.includes('A')) await partA();
  if (only.includes('B')) await partB();
} catch (error) {
  failed = true;
  report.error = error.stack || String(error);
  console.error(report.error);
} finally {
  await browser.close();
  server.kill();
  await writeFile(join(outDir, 'story-check.json'), JSON.stringify(report, null, 2));
}
process.exit(failed ? 1 : 0);

async function open(page, query) {
  page.on('console', (m) => report.logs.push(m.type() + ': ' + m.text()));
  page.on('pageerror', (e) => report.logs.push('pageerror: ' + e.message));
  await page.goto(base + '/open-world/' + query, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForFunction(() => window.AU_STORY && window.AU_STORY.active, { timeout: 90000 });
}

function story(page) {
  return page.evaluate(() => ({ ...window.AU_STORY, x: window.AU_HQ?.x, z: window.AU_HQ?.z }));
}
async function waitStory(page, pred, ms) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const s = await story(page);
    if (pred(s)) return s;
    await page.waitForTimeout(100);
  }
  return null;
}
async function shot(page, name, log) {
  const s = await story(page);
  await page.screenshot({ path: join(outDir, name + '.png') });
  log.push({ shot: name, ...s });
  console.log(name, JSON.stringify(s));
}

async function partA() {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const log = report.a;
  await open(page, '?story=p1');
  await page.waitForTimeout(1500);
  await shot(page, 'a01-p1-opening', log);
  await page.click('canvas');
  const pushing = await waitStory(page, (s) => s.objective === 'push' && s.talk !== '', 30000);
  await shot(page, 'a02-push-objective', log);
  await page.keyboard.down('KeyW');
  const pushed = await waitStory(page, (s) => s.objective === 'kick_up', 15000);
  await page.keyboard.up('KeyW');
  log.push({ step: 'push (hold W)', ok: !!pushed });
  await shot(page, 'a03-pushed', log);
  await page.waitForTimeout(2500);
  await page.keyboard.press('ShiftLeft');
  const kicked = await waitStory(page, (s) => s.objective === 'drop_on', 5000);
  log.push({ step: 'kick up (Shift)', ok: !!kicked });
  await page.waitForTimeout(800);
  await shot(page, 'a04-kicked-up', log);
  await page.keyboard.press('ShiftLeft');
  const dropped = await waitStory(page, (s) => s.objective === 'ollie', 5000);
  log.push({ step: 'drop on (Shift)', ok: !!dropped });
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(700);
  await page.keyboard.press('KeyQ');
  await page.waitForTimeout(250);
  await shot(page, 'a05-ollie-air', log);
  const ollied = await waitStory(page, (s) => s.objective === 'quarter', 6000);
  await page.keyboard.up('KeyW');
  log.push({ step: 'ollie (Q)', ok: !!ollied });
  // hesitate on the quarter pipe: the prompt shows after 12 s
  const prompted = await waitStory(page, (s) => s.prompt === true, 30000);
  log.push({ step: 'hesitation prompt', ok: !!prompted });
  await shot(page, 'a06-hesitation-prompt', log);
  await page.keyboard.press('KeyT');
  await page.waitForTimeout(600);
  await shot(page, 'a07-retry-quarter-checkpoint', log);
  await page.keyboard.down('KeyW');
  const rode = await waitStory(page, (s) => s.objective === 'rail', 15000);
  await page.keyboard.up('KeyW');
  log.push({ step: 'quarter pipe (hold W at the ramp)', ok: !!rode });
  await shot(page, 'a08-quarter-done', log);
  // the rail: T to the rail checkpoint, push west down the lane, Q about 4 m before the bar
  let grinded = null;
  for (let attempt = 0; attempt < 3 && !grinded; attempt += 1) {
    await page.keyboard.press('KeyT');
    await page.waitForTimeout(700);
    await page.keyboard.down('KeyW');
    let popped = false;
    const end = Date.now() + 9000;
    while (Date.now() < end) {
      const s = await story(page);
      if (!popped && s.x < -44.6) {
        await page.keyboard.press('KeyQ');
        popped = true;
        await page.waitForTimeout(350);
        await shot(page, `a09-rail-attempt${attempt + 1}`, log);
      }
      if (s.objective !== 'rail') { grinded = s; break; }
      await page.waitForTimeout(30);
    }
    await page.keyboard.up('KeyW');
    log.push({ step: `rail attempt ${attempt + 1}`, ok: !!grinded });
  }
  await page.waitForTimeout(2500);
  await shot(page, 'a10-after-rail', log);
  await page.close();
}

async function partB() {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, recordVideo: { dir: outDir, size: { width: 1280, height: 720 } } });
  const page = await context.newPage();
  const log = report.b;
  const t0 = Date.now();
  await open(page, '?story=p1&story_demo=1');
  let last = '';
  const seen = new Set();
  const end = Date.now() + 15 * 60 * 1000;
  while (Date.now() < end) {
    const s = await story(page);
    const key = s.objective + '|' + s.state + '|' + s.zero + '|' + (s.best > s.zero && s.zero > 0);
    if (key !== last) {
      last = key;
      log.push({ t: (Date.now() - t0) / 1000, ...s });
      const name = 'b-' + String(seen.size).padStart(2, '0') + '-' + (s.objective || s.state) + (s.zero ? '-zero' + s.zero : '') + (s.best > s.zero && s.zero > 0 ? '-beaten' : '');
      seen.add(key);
      await page.waitForTimeout(900);
      await shot(page, name, log);
    }
    if (String(s.pilot).endsWith('/done')) break;
    await page.waitForTimeout(250);
  }
  await page.waitForTimeout(2000);
  await shot(page, 'b-zz-end', log);
  const video = page.video();
  await context.close();
  if (video) await rename(await video.path(), join(outDir, 'p1-autopilot-browser.webm'));
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
