// Act I scenes 1.1 to 1.4B (Nov 20 2026): a recorded headless-Chrome run of the built Act I scenes in the web export,
// played by the walking review autopilot (story_demo=1), starting at a scene with the dev jump (?act1_from=<id>, the
// Prologue counts as done). Screenshots at every step change, every goal / delivery, every cinematic, Zero Vision and
// the end card; act1-scenes.webm and act1-scenes-check.json go to AU_ACT1_OUT. Run after export-web + stage-composite.
// AU_ACT1_FROM picks the first scene (default 1.1). Deploys nothing.
import { spawn } from 'node:child_process';
import { mkdir, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const world = join(dirname(fileURLToPath(import.meta.url)), '..');
const port = Number(process.env.PORT || 8132);
const base = `http://127.0.0.1:${port}`;
const outDir = process.env.AU_ACT1_OUT || '/tmp/act1-scenes';
const from = process.env.AU_ACT1_FROM || '1.1';
const minutes = Number(process.env.AU_ACT1_MINUTES || 20);
await mkdir(outDir, { recursive: true });
const server = spawn(process.execPath, ['tools/serve-composite.mjs'], { cwd: world, env: { ...process.env, PORT: String(port) }, stdio: 'ignore' });
await waitForServer();
const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
const report = { from, steps: [], timeline: [], logs: [] };
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
  if (video) { try { await rename(await video.path(), join(outDir, 'act1-scenes.webm')); } catch { /* none */ } }
  await browser.close();
  server.kill();
  report.failures = failures;
  report.seconds = Math.round((Date.now() - t0) / 1000);
  report.fatal = report.logs.filter((l) => /pageerror|SCRIPT ERROR/i.test(l));
  await writeFile(join(outDir, 'act1-scenes-check.json'), JSON.stringify(report, null, 2));
}
console.log(failures.length ? 'FAIL\n' + failures.join('\n') : 'act1-scenes-check ok');
process.exit(failures.length ? 1 : 0);

async function run() {
  context = await browser.newContext({ viewport: { width: 1280, height: 720 }, recordVideo: { dir: outDir, size: { width: 1280, height: 720 } } });
  page = await context.newPage();
  page.on('console', (m) => report.logs.push(m.type() + ': ' + m.text()));
  page.on('pageerror', (e) => report.logs.push('pageerror: ' + e.message));
  await page.goto(base + `/open-world/?story=p1&story_demo=1&act1_from=${from}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await waitFor(() => window.AU_A1 && window.AU_A1.scene !== '', 180000, 'the first Act I scene');
  const seenScenes = new Set();
  let last = '';
  let lastShot = 0;
  const end = Date.now() + minutes * 60 * 1000;
  while (Date.now() < end) {
    const s = await page.evaluate(() => ({ ...window.AU_STORY }));
    const a = await page.evaluate(() => (window.AU_A1 ? { ...window.AU_A1 } : null));
    if (!a) { await page.waitForTimeout(300); continue; }
    if (a.scene) seenScenes.add(a.scene);
    const key = [s.phase, s.cine, a.scene, a.step, a.do, a.goals, a.vision].join('|');
    if (key !== last) {
      last = key;
      report.timeline.push({ t: Math.round((Date.now() - t0) / 1000), phase: s.phase, cine: s.cine, a1: a });
      if (s.phase === 'slice_end') { await page.waitForTimeout(1500); await shot('end-card'); break; }
      const name = (s.cine ? `cine-${s.cine}` : `s${a.scene}-step${a.step}-${a.do}-${a.goals}`) + (a.vision ? '-zero-vision' : '');
      await page.waitForTimeout(s.cine ? 2500 : a.vision ? 1500 : 900);
      await shot(name);
      lastShot = Date.now();
    } else if (Date.now() - lastShot > 20000) {
      await shot(`s${a.scene}-step${a.step}-${a.do}-playing`);
      lastShot = Date.now();
    }
    await page.waitForTimeout(250);
  }
  const fin = await page.evaluate(() => ({ story: { ...window.AU_STORY }, a1: window.AU_A1 ? { ...window.AU_A1 } : null }));
  report.final = fin;
  step('reached the end card', fin.story.phase === 'slice_end', fin);
  step('scenes played: ' + [...seenScenes].join(','), seenScenes.size >= 1, {});
  step('no script errors', !report.logs.some((l) => /SCRIPT ERROR|pageerror/i.test(l)), report.logs.filter((l) => /SCRIPT ERROR|pageerror/i.test(l)).slice(0, 5));
}

function step(name, ok, info) {
  report.steps.push({ name, ok, info });
  if (!ok) failures.push(name + ' ' + JSON.stringify(info).slice(0, 400));
  console.log((ok ? 'ok ' : 'not ok ') + name);
}
async function shot(name) {
  n += 1;
  const file = String(n).padStart(2, '0') + '-' + name.replace(/[^a-zA-Z0-9._-]/g, '_') + '.png';
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
