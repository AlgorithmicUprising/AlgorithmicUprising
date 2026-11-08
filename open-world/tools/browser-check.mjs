import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const world = join(dirname(fileURLToPath(import.meta.url)), '..');
const port = Number(process.env.PORT || 8090);
const base = `http://127.0.0.1:${port}`;
const outDir = process.env.AU_BROWSER_OUT || '/tmp/hq-browser';
await mkdir(outDir, { recursive: true });

const server = spawn(process.execPath, ['tools/serve-composite.mjs'], {
  cwd: world,
  env: { ...process.env, PORT: String(port) },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let serverLog = '';
server.stdout.on('data', (chunk) => { serverLog += chunk; });
server.stderr.on('data', (chunk) => { serverLog += chunk; });
await waitForServer();

const browser = await chromium.launch({
  channel: 'chrome',
  headless: true,
  args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const logs = [];
page.on('console', (msg) => logs.push(msg.type() + ': ' + msg.text()));
page.on('pageerror', (error) => logs.push('pageerror: ' + error.message));
const failures = [];

try {
  await checkArcade();
  await checkWorld();
} catch (error) {
  failures.push(error.stack || String(error));
} finally {
  await page.screenshot({ path: join(outDir, 'hq-browser.png') }).catch(() => {});
  await browser.close();
  server.kill();
}

const fatal = logs.filter((line) => /SharedArrayBuffer|incorrect MIME|Failed to fetch|pageerror:/i.test(line));
if (fatal.length) failures.push('fatal browser log:\n' + fatal.join('\n'));
console.log(logs.join('\n'));
if (failures.length) {
  console.error(failures.join('\n\n'));
  process.exit(1);
}
console.log('browser-check ok');

async function checkArcade() {
  const root = await page.request.get(base + '/');
  if (root.status() !== 200 || !(await root.text()).includes('./demo/')) failures.push('arcade root missing demo redirect');
  const demo = await page.request.get(base + '/demo/');
  if (demo.status() !== 200) failures.push('arcade /demo/ status ' + demo.status());
  const bundle = await page.request.get(base + '/games/grind-the-terms/dist/grind-the-terms.js');
  const bundleType = bundle.headers()['content-type'] || '';
  if (bundle.status() !== 200 || !bundleType.includes('javascript')) failures.push('grind bundle missing or wrong MIME ' + bundle.status() + ' ' + bundleType);
  const tag = await page.request.get(base + '/games/tag-before-training/dist/tag-before-training.js');
  if (tag.status() !== 200) failures.push('tag bundle status ' + tag.status());
  const cookie = await page.request.get(base + '/games/cookie-wall/demo/page.js');
  if (cookie.status() !== 200) failures.push('cookie wall page status ' + cookie.status());
}

async function checkWorld() {
  const listing = await page.request.get(base + '/open-world/');
  const html = await listing.text();
  const wasmMatch = html.match(/["']([^"']+\.wasm)["']/);
  if (listing.status() !== 200) failures.push('open-world status ' + listing.status());
  if (!wasmMatch) failures.push('open-world html has no wasm reference');
  else {
    const wasmUrl = new URL(wasmMatch[1], base + '/open-world/').toString();
    const wasm = await page.request.get(wasmUrl);
    const type = wasm.headers()['content-type'] || '';
    if (wasm.status() !== 200 || !type.includes('application/wasm')) {
      failures.push('wasm MIME failed ' + wasm.status() + ' ' + type + ' ' + wasmUrl);
    }
  }
  await page.goto(base + '/open-world/', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForFunction(() => window.AU_HQ && window.AU_HQ.session === 'world', { timeout: 45000 });
  const before = await page.evaluate(() => ({ ...window.AU_HQ }));
  await page.click('canvas');
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(900);
  await page.keyboard.up('KeyW');
  await page.waitForTimeout(200);
  const after = await page.evaluate(() => ({ ...window.AU_HQ }));
  const moved = Math.hypot(after.x - before.x, after.z - before.z);
  console.log('world before', before, 'after', after, 'moved', moved);
  if (!(moved > 0.4)) failures.push('keyboard did not move the player in the browser');
  if (after.session !== 'world') failures.push('session changed during the move check');
  const yawBefore = after.yaw;
  await page.mouse.move(180, 280);
  await page.mouse.move(760, 320);
  await page.waitForTimeout(250);
  const turned = await page.evaluate(() => ({ ...window.AU_HQ }));
  console.log('synthetic pointer look', after.look, 'yaw', yawBefore, '->', turned.yaw);
  if (after.look && Math.abs(turned.yaw - yawBefore) < 0.05) {
    failures.push('captured mouse move did not turn the view');
  }
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(700);
  await page.keyboard.up('KeyW');
  const headed = await page.evaluate(() => ({ ...window.AU_HQ }));
  const dx = headed.x - turned.x;
  const dz = headed.z - turned.z;
  const travel = Math.hypot(dx, dz);
  const align = travel > 0.01 ? (dx * -Math.sin(turned.yaw) + dz * -Math.cos(turned.yaw)) / travel : 0;
  console.log('synthetic W after mouse turn', { dx, dz, travel, align, yaw: turned.yaw });
  if (!(travel > 0.4 && align > 0.7)) failures.push('W did not follow the mouse heading');
  const yawE = turned.yaw;
  await page.keyboard.press('KeyE');
  await page.waitForTimeout(200);
  const afterE = await page.evaluate(() => ({ ...window.AU_HQ }));
  if (Math.abs(afterE.yaw - yawE) > 0.05) failures.push('E rotated the view');
  if (afterE.session !== 'world') failures.push('E left the world from the open yard');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(200);
  const paused = await page.evaluate(() => ({ ...window.AU_HQ }));
  if (!paused.paused) failures.push('Esc did not pause');
  if (paused.look) failures.push('Esc left the pointer captured');
  await page.keyboard.down('KeyW');
  await page.waitForTimeout(400);
  await page.keyboard.up('KeyW');
  const frozen = await page.evaluate(() => ({ ...window.AU_HQ }));
  if (Math.hypot(frozen.x - paused.x, frozen.z - paused.z) > 0.2) failures.push('paused yard still accepted movement');
  await page.mouse.click(640, 360);
  await page.waitForTimeout(250);
  const resumed = await page.evaluate(() => ({ ...window.AU_HQ }));
  console.log('synthetic resume', resumed.paused, resumed.look);
  if (resumed.paused) failures.push('click did not leave pause');
  await page.screenshot({ path: join(outDir, 'hq-browser.png') });
}

function waitForServer() {
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const timer = setInterval(async () => {
      if (server.exitCode != null) {
        clearInterval(timer);
        reject(new Error('server exited\n' + serverLog));
        return;
      }
      try {
        const response = await fetch(base + '/');
        if (response.status === 200) {
          clearInterval(timer);
          resolve();
        }
      } catch { /* not up yet */ }
      if (Date.now() - started > 10000) {
        clearInterval(timer);
        reject(new Error('server did not start\n' + serverLog));
      }
    }, 200);
  });
}
