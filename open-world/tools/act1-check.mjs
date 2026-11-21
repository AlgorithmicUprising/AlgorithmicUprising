// Act I (Nov 19 2026): the whole playable slice in the web export, in one recorded headless-Chrome session.
//   title -> PRESS START -> New Game (default name) -> the hosted intro video (plays, then hold to skip) -> P.1 played by
//   the review autopilot (story_demo=1) -> the deal -> the heat alert -> CINEMATIC P.2 and P.3 -> MISSION P.2 Run
//   (autopilot: caught once at the fork to show the restart, then the dock route) -> the culvert -> the arcade's side
//   door -> MISSION P.3 Power On in the dark arcade (three fuses, the breaker) -> CINEMATIC P.4 Zero (power cascade, the cutout puppet, ??? -> ZERO, the title card) -> the end card.
// Writes screenshots, act1-full-run.webm and act1-check.json to AU_ACT1_OUT. Run after export-web + stage-composite.
// Deploys nothing.
import { spawn } from 'node:child_process';
import { mkdir, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const world = join(dirname(fileURLToPath(import.meta.url)), '..');
const port = Number(process.env.PORT || 8131);
const base = `http://127.0.0.1:${port}`;
const outDir = process.env.AU_ACT1_OUT || '/tmp/act1-check';
await mkdir(outDir, { recursive: true });

const server = spawn(process.execPath, ['tools/serve-composite.mjs'], { cwd: world, env: { ...process.env, PORT: String(port) }, stdio: 'ignore' });
await waitForServer();
const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
const report = { steps: [], timeline: [], logs: [] };
const failures = [];
let n = 0;
const t0 = Date.now();
let page;
let context;
try {
  await run();
} catch (error) {
  failures.push('error: ' + (error.stack || String(error)));
  try { await shot('zz-error'); } catch { /* page gone */ }
} finally {
  const video = page ? page.video() : null;
  if (context) await context.close();
  if (video) { try { await rename(await video.path(), join(outDir, 'act1-full-run.webm')); } catch { /* none */ } }
  await browser.close();
  server.kill();
  report.failures = failures;
  report.seconds = Math.round((Date.now() - t0) / 1000);
  report.fatal = report.logs.filter((l) => /pageerror|SCRIPT ERROR/i.test(l));
  await writeFile(join(outDir, 'act1-check.json'), JSON.stringify(report, null, 2));
}
console.log(failures.length ? 'FAIL\n' + failures.join('\n') : 'act1-check ok');
process.exit(failures.length ? 1 : 0);

async function run() {
  context = await browser.newContext({ viewport: { width: 1280, height: 720 }, recordVideo: { dir: outDir, size: { width: 1280, height: 720 } } });
  page = await context.newPage();
  page.on('console', (m) => report.logs.push(m.type() + ': ' + m.text()));
  page.on('pageerror', (e) => report.logs.push('pageerror: ' + e.message));
  await page.goto(base + '/open-world/?story_demo=1', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await waitFor(() => window.AU_TITLE && window.AU_TITLE.title === true, 120000, 'title screen');
  await page.waitForTimeout(800);
  await shot('title');
  await page.mouse.click(640, 120);
  await waitFor(() => window.AU_TITLE.title === false && window.AU_TITLE.focus === 'Menu_new', 8000, 'menu');
  await page.keyboard.press('Enter');
  await waitFor(() => window.AU_TITLE.panel === 'name', 5000, 'name panel');
  await page.waitForTimeout(400);
  await page.keyboard.press('Enter');
  await waitFor(() => window.PZ_INTRO && window.PZ_INTRO.state === 'playing', 45000, 'intro playing');
  await page.waitForTimeout(5000);
  const intro = await page.evaluate(() => ({ ...window.PZ_INTRO, src: document.querySelector('#pz-intro video')?.currentSrc || '', t: document.querySelector('#pz-intro video')?.currentTime || 0, rs: document.querySelector('#pz-intro video')?.readyState || 0 }));
  await shot('intro-playing');
  step('New Game plays the hosted intro', /algorithmicuprising\.com\/media\/uploads\/.+\.mp4$/.test(intro.src) && intro.t > 2 && intro.rs >= 3, intro);
  await page.keyboard.down('Space');
  await page.waitForTimeout(1400);
  await page.keyboard.up('Space');
  await waitFor(() => window.AU_STORY && window.AU_STORY.active, 90000, 'P.1 after the intro');
  await page.waitForTimeout(2500);
  await shot('p1-beat0-phone');
  const s0 = await story();
  step('P.1 starts with the autopilot (Beat 0 text in; it may already be past the push)', ['push', 'ollie'].includes(s0.objective) && s0.texts >= 1, s0);

  // follow the story to the end card
  const seen = new Set();
  const want = {
    'p1-zero-score': (s) => s.zero > 0,
    'p1-deal': (s) => s.deal === 'queued' || s.deal === 'offered',
    'heat-alert': (s) => s.cine === 'p2_heat_alert',
    'drone-flagged': (s) => s.cine === 'p3_flagged',
    'run-start': (s, r) => s.phase === 'p2_run' && r && r.state === 'run',
    'run-enforcers': (s, r) => r && r.state === 'run' && r.drones >= 3,
    'run-caught': (s, r) => r && r.state === 'caught',
    'run-restart-fence-gap': (s, r) => r && r.state === 'run' && r.fails >= 1 && r.checkpoint === 'fence_gap',
    'run-dock': (s, r) => r && r.routes.includes('dock'),
    'run-plaza': (s, r) => r && r.checkpoint === 'plaza',
    'run-culvert': (s, r) => r && r.state === 'culvert',
    'run-yard-to-door': (s, r) => r && r.state === 'yard',
    'run-door': (s, r) => r && r.state === 'door',
    'p3-arcade-dark': (s, r, q) => q && q.state === 'intro' && s.phase === 'p3_power',
    'p3-play': (s, r, q) => q && q.state === 'play' && q.fuses === 0,
    'p3-fuse-coin-box': (s, r, q) => q && q.fuses >= 1,
    'p3-fuse-toolbox': (s, r, q) => q && q.fuses >= 2,
    'p3-fuse-fixture': (s, r, q) => q && q.fuses >= 3,
    'p3-breaker': (s, r, q) => q && (q.state === 'power' || q.state === 'done'),
    'p4-power-on': (s, r, q) => s.cine === 'p4_zero' && q && q.lit,
    'p4-zero-awake': (s, r, q) => q && q.zero === 'awake' && q.header === 'ZERO',
    'p4-plate': (s, r, q) => q && /reads the plate/.test(q.last),
    'p4-heat-wont-wait': (s, r, q) => q && /contest will wait/.test(q.last),  // the probe keeps 48 chars and drops apostrophes
    'p4-title-card': (s, r, q) => q && /^CARD\|PROJECT ZERO/.test(q.last),
    'end-card': (s, r) => s.phase === 'slice_end',
  };
  const delays = { 'p4-power-on': 5000, 'p4-zero-awake': 1500, 'p4-plate': 800, 'p4-title-card': 800, 'p3-arcade-dark': 2500, 'p3-fuse-fixture': 600, 'p3-breaker': 1500, 'heat-alert': 3500, 'drone-flagged': 9000, 'run-caught': 500, 'run-culvert': 900, 'run-door': 600, 'end-card': 1200, 'run-plaza': 1800, 'run-dock': 300, 'run-enforcers': 1500 };
  const end = Date.now() + 22 * 60 * 1000;
  let last = '';
  while (Date.now() < end) {
    const s = await story();
    const r = await page.evaluate(() => (window.AU_RUN ? { ...window.AU_RUN } : null));
    const q = await page.evaluate(() => (window.AU_P3 ? { ...window.AU_P3 } : null));
    const key = [s.phase, s.objective, s.cine, r && r.state, r && r.checkpoint, q && q.state, q && q.fuses].join('|');
    if (key !== last) { last = key; report.timeline.push({ t: Math.round((Date.now() - t0) / 1000), phase: s.phase, obj: s.objective, cine: s.cine, deal: s.deal, run: r, p3: q }); }
    for (const [name, pred] of Object.entries(want)) {
      if (!seen.has(name) && pred(s, r, q)) {
        seen.add(name);
        if (delays[name]) await page.waitForTimeout(delays[name]);
        await shot(name);
      }
    }
    if (seen.has('end-card')) break;
    await page.waitForTimeout(200);
  }
  for (const name of Object.keys(want)) step('reached: ' + name, seen.has(name), {});
  const fin = await page.evaluate(() => ({ story: { ...window.AU_STORY }, run: window.AU_RUN ? { ...window.AU_RUN } : null }));
  step('the run ended at the arcade door with a time', fin.run && fin.run.state === 'done' && fin.run.time > 10, fin);
  const p3 = await page.evaluate(() => (window.AU_P3 ? { ...window.AU_P3 } : null));
  step('P.3 Power On: three fuses and the breaker', p3 && p3.state === 'done' && p3.fuses === 3, p3);
  step('P.4: Zero awake, the thread header reads ZERO', p3 && p3.zero === 'awake' && p3.header === 'ZERO' && p3.lit, p3);
  await page.waitForTimeout(4000);
  await shot('zz-after-end-card');
}

async function story() {
  return page.evaluate(() => ({ ...window.AU_STORY }));
}
function step(name, ok, info) {
  report.steps.push({ name, ok, info });
  if (!ok) failures.push(name + ' ' + JSON.stringify(info).slice(0, 400));
  console.log((ok ? 'ok ' : 'not ok ') + name);
}
async function shot(name) {
  n += 1;
  const file = String(n).padStart(2, '0') + '-' + name + '.png';
  await page.screenshot({ path: join(outDir, file) });
  report.steps.push({ shot: file, t: Math.round((Date.now() - t0) / 1000) });
  console.log('shot', file);
}
async function waitFor(fn, ms, what) {
  try {
    await page.waitForFunction(fn, null, { timeout: ms, polling: 200 });
  } catch (e) {
    throw new Error('timed out waiting for ' + what);
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
