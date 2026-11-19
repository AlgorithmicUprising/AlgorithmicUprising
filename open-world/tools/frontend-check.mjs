// Front end (Nov 19 2026): the title menu in the web export, for review. Serves the staged composite
// (node tools/stage-composite.mjs first), then in one recorded browser session:
//   title -> PRESS START -> menu (Load greyed out on a fresh profile) -> Credits -> Uprising Arcade
//   (Game Thing Pro console + a cartridge, back each time) -> New Game -> character name -> the
//   placeholder intro video (HTML overlay outside the pack) -> P.1 -> ride to the quarter-pipe
//   checkpoint (autosave) -> reload the page -> Load Game -> P.1 resumes at the checkpoint -> pause menu.
// Writes screenshots, frontend-check.webm and frontend-check.json to AU_FRONT_OUT. Deploys nothing.
import { spawn } from 'node:child_process';
import { mkdir, rename, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const world = join(dirname(fileURLToPath(import.meta.url)), '..');
const port = Number(process.env.PORT || 8098);
const base = `http://127.0.0.1:${port}`;
const outDir = process.env.AU_FRONT_OUT || '/tmp/frontend-check';
const NAME = process.env.AU_FRONT_NAME || 'Rook';
await mkdir(outDir, { recursive: true });

const server = spawn(process.execPath, ['tools/serve-composite.mjs'], { cwd: world, env: { ...process.env, PORT: String(port) }, stdio: 'ignore' });
await waitForServer();
const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
const report = { steps: [], logs: [] };
const failures = [];
let n = 0;
try {
  await run();
} catch (error) {
  failures.push('error: ' + (error.stack || String(error)));
} finally {
  await browser.close();
  server.kill();
  report.failures = failures;
  await writeFile(join(outDir, 'frontend-check.json'), JSON.stringify(report, null, 2));
}
console.log(failures.length ? 'FAIL\n' + failures.join('\n') : 'frontend-check ok');
process.exit(failures.length ? 1 : 0);

async function run() {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, recordVideo: { dir: outDir, size: { width: 1280, height: 720 } } });
  const page = await context.newPage();
  page.on('console', (m) => report.logs.push(m.type() + ': ' + m.text()));
  page.on('pageerror', (e) => report.logs.push('pageerror: ' + e.message));

  await page.goto(base + '/open-world/', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await waitFor(page, () => window.AU_TITLE && window.AU_TITLE.title === true, 90000, 'title screen');
  await page.waitForTimeout(1500);
  await shot(page, 'title-press-start');
  await page.mouse.click(640, 120);
  await waitFor(page, () => window.AU_TITLE.title === false && window.AU_TITLE.focus === 'Menu_new', 5000, 'menu after PRESS START');
  await page.waitForTimeout(400);
  const fresh = await title(page);
  step('menu shows, New Game focused, Load greyed out on a fresh profile', fresh.load_enabled === false, fresh);
  await shot(page, 'menu-no-saves');

  // keyboard: Right skips the greyed-out Load Game
  await page.keyboard.press('ArrowRight');
  await waitFor(page, () => window.AU_TITLE.focus === 'Menu_arcade', 3000, 'Right -> Uprising Arcade');
  await page.keyboard.press('ArrowRight');
  await waitFor(page, () => window.AU_TITLE.focus === 'Menu_credits', 3000, 'Right -> Credits');
  step('Right skips Load Game to Uprising Arcade, then Credits', true);
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.AU_TITLE.panel === 'credits', 3000, 'credits panel');
  await page.waitForTimeout(500);
  await shot(page, 'credits');
  step('Credits open', true);
  await page.keyboard.press('Escape');
  await waitFor(page, () => window.AU_TITLE.panel === '', 3000, 'credits closed');

  await page.keyboard.press('ArrowLeft');
  await waitFor(page, () => window.AU_TITLE.focus === 'Menu_arcade', 3000, 'Left -> Uprising Arcade');
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.AU_TITLE.panel === 'arcade' && window.AU_TITLE.focus === 'Cart_console', 3000, 'arcade console panel');
  await page.waitForTimeout(400);
  await shot(page, 'arcade-game-thing-pro');
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.AU_TITLE.arcade === true, 5000, 'full console overlay');
  await page.waitForTimeout(4000);
  await shot(page, 'arcade-full-console-overlay');
  const backText = await page.locator('#au-arcade-overlay button').first().textContent();
  step('Game Thing Pro console opens in the overlay', true, { back: backText });
  await page.locator('#au-arcade-overlay button').first().click();
  await waitFor(page, () => window.AU_TITLE.arcade === false && window.AU_TITLE.panel === 'arcade', 5000, 'back to the console');
  await page.keyboard.press('ArrowDown');
  const cart = (await title(page)).focus;
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.AU_TITLE.arcade === true, 5000, 'cartridge overlay');
  await page.waitForTimeout(3500);
  await shot(page, 'arcade-cartridge');
  await page.locator('#au-arcade-overlay button').first().click();
  await waitFor(page, () => window.AU_TITLE.arcade === false && window.AU_TITLE.panel === 'arcade', 5000, 'back from the cartridge');
  step('a cartridge opens and BACK returns to the console', true, { cart, back: backText });
  await page.keyboard.press('Escape');
  await waitFor(page, () => window.AU_TITLE.panel === '', 3000, 'arcade closed');

  // New Game
  await page.keyboard.press('ArrowLeft');
  await waitFor(page, () => window.AU_TITLE.focus === 'Menu_new', 3000, 'Left -> New Game');
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.AU_TITLE.panel === 'name', 3000, 'name panel');
  await page.waitForTimeout(500);
  await shot(page, 'new-game-name-default-fony');
  await page.keyboard.press('Control+A');
  await page.keyboard.type(NAME);
  await page.waitForTimeout(300);
  await shot(page, 'new-game-name-typed');
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.PZ_INTRO && window.PZ_INTRO.state === 'playing', 30000, 'intro video playing');
  await page.waitForTimeout(1800);
  const intro = await page.evaluate(() => ({ ...window.PZ_INTRO, src: document.querySelector('#pz-intro video')?.currentSrc || '', t: document.querySelector('#pz-intro video')?.currentTime || 0 }));
  await shot(page, 'intro-placeholder-playing');
  step('intro video plays as an HTML overlay (outside the pack)', /media\/intro\/.+\.mp4$/.test(intro.src) && intro.t > 0.5, intro);
  // first run: hold to skip (1 s ring). Hold Space briefly and let go to show the ring, then let it end.
  await page.keyboard.down('Space');
  await page.waitForTimeout(450);
  await shot(page, 'intro-hold-to-skip-ring');
  await page.keyboard.up('Space');
  await waitFor(page, () => window.AU_STORY && window.AU_STORY.active, 60000, 'P.1 after the intro');
  const ended = await page.evaluate(() => ({ ...window.PZ_INTRO }));
  step('the intro ends and hands off to P.1', ended.state === 'done', ended);
  await page.waitForTimeout(1500);
  await shot(page, 'p1-start-after-intro');
  const first = await waitFor(page, () => window.AU_SAVE && window.AU_SAVE.count >= 1, 15000, 'New Game autosave');
  step('New Game autosaves under the character', first.character === NAME && first.mission === 'p1_practice_run', first);

  // ride P.1 to the quarter-pipe checkpoint (keyboard, as tools/story-check.mjs)
  await page.click('canvas');
  await waitFor(page, () => window.AU_STORY.objective === 'push', 30000, 'push objective');
  await page.keyboard.down('KeyW');
  await waitFor(page, () => window.AU_STORY.objective === 'kick_up', 15000, 'pushed');
  await page.keyboard.up('KeyW');
  await page.waitForTimeout(2500);
  await page.keyboard.press('ShiftLeft');
  await waitFor(page, () => window.AU_STORY.objective === 'drop_on', 5000, 'kicked up');
  await page.waitForTimeout(800);
  await page.keyboard.press('ShiftLeft');
  await waitFor(page, () => window.AU_STORY.objective === 'ollie', 5000, 'dropped on');
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(700);
  await page.keyboard.press('KeyQ');
  await waitFor(page, () => window.AU_STORY.objective === 'quarter', 6000, 'ollied');
  await page.keyboard.up('KeyW');
  const cp = await waitFor(page, () => window.AU_SAVE && window.AU_SAVE.checkpoint === 'quarter', 10000, 'checkpoint autosave');
  await page.waitForTimeout(1000);
  await shot(page, 'p1-quarter-checkpoint-autosaved');
  step('reaching the quarter-pipe checkpoint autosaves', true, cp);

  // reload: user:// is IndexedDB on the web and must survive it
  await page.reload({ waitUntil: 'domcontentloaded' });
  await waitFor(page, () => window.AU_TITLE && window.AU_TITLE.title === true, 90000, 'title after reload');
  await page.waitForTimeout(800);
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.AU_TITLE.title === false, 5000, 'menu after reload');
  await page.waitForTimeout(400);
  const after = await title(page);
  step('after a page reload Load Game is available', after.load_enabled === true, after);
  await shot(page, 'menu-after-reload-load-enabled');
  await page.keyboard.press('ArrowRight');
  await waitFor(page, () => window.AU_TITLE.focus === 'Menu_load', 3000, 'Right -> Load Game');
  await page.keyboard.press('Enter');
  await waitFor(page, () => window.AU_TITLE.panel === 'load', 3000, 'load panel');
  await page.waitForTimeout(500);
  await shot(page, 'load-game-list');
  const row = (await title(page)).focus;
  await page.keyboard.press('Enter');
  const resumed = await waitFor(page, () => window.AU_STORY && window.AU_STORY.active && window.AU_STORY.objective === 'quarter', 60000, 'P.1 resumed');
  await page.waitForTimeout(2000);
  await shot(page, 'loaded-resumed-at-quarter');
  const loaded = await page.evaluate(() => window.AU_SAVE || null);
  step('Load Game resumes P.1 at the quarter-pipe checkpoint', resumed.objective === 'quarter', { row, story: resumed, save: loaded });

  // pause menu: Save / Load / Quit to title
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);
  await shot(page, 'pause-save-load-quit');
  step('pause menu opens', (await page.evaluate(() => window.AU_HQ && window.AU_HQ.paused)) === true);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);

  const video = page.video();
  await context.close();
  if (video) await rename(await video.path(), join(outDir, 'frontend-check.webm'));
}

function title(page) { return page.evaluate(() => ({ ...(window.AU_TITLE || {}) })); }
function step(what, ok, data = {}) {
  report.steps.push({ what, ok, ...data });
  console.log((ok ? 'ok ' : 'not ok ') + what);
  if (!ok) failures.push(what + ' ' + JSON.stringify(data));
}
async function shot(page, name) {
  n += 1;
  const file = String(n).padStart(2, '0') + '-' + name + '.png';
  await page.screenshot({ path: join(outDir, file) });
  report.steps.push({ shot: file });
}
async function waitFor(page, fn, ms, what) {
  try {
    await page.waitForFunction(fn, null, { timeout: ms, polling: 100 });
  } catch {
    const state = await page.evaluate(() => ({ title: window.AU_TITLE, story: window.AU_STORY, save: window.AU_SAVE, intro: window.PZ_INTRO }));
    await page.screenshot({ path: join(outDir, 'timeout-' + what.replace(/\W+/g, '-') + '.png') });
    throw new Error('timed out: ' + what + ' ' + JSON.stringify(state));
  }
  return page.evaluate(() => ({ ...(window.AU_SAVE || {}), ...(window.AU_STORY || {}) }));
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
