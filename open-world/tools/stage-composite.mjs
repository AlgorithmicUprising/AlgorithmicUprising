// Build a GitHub Pages tree: current arcade staging output at the root,
// Godot web export under open-world/. Does not upload or deploy.
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { cp, mkdir, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readPack, summarize } from './pack-report.mjs';

// Pack budgets (M0, Nov 18 2026). The user raised the main pack limit from 16 MiB to 50 MiB for higher-quality Fony art (near-lossless WebP q0.97, about 22 MiB).
// District packs (data/districts.json) stream in on demand; each has its own budget_bytes, capped at DISTRICT_PACK_MAX.
export const MAIN_PACK_MAX = 50 * 1024 * 1024;
export const DISTRICT_PACK_MAX = 8 * 1024 * 1024;

const here = dirname(fileURLToPath(import.meta.url));
const world = join(here, '..');
const repo = join(world, '..');
const arcade = join(repo, 'arcade');
const staged = join(arcade, '.pages');
const web = process.env.AU_WEB_DIR || join(world, 'build', 'web');
const out = process.env.AU_COMPOSITE_DIR || join(world, 'build', 'pages-composite');
const skipArcadeBuild = process.argv.includes('--skip-arcade-build');
const intoStaged = process.argv.includes('--into-staged');

if (intoStaged && skipArcadeBuild) {
  throw new Error('Use either --into-staged or --skip-arcade-build');
}
if (!intoStaged) {
  if (!skipArcadeBuild) await run('npm', ['run', 'build'], arcade);
  await run('npm', ['run', 'stage-pages'], arcade);
}
await assertFile(join(web, 'index.html'), 'Godot web export is missing. Run npm run export-web first.');
const html = await readFile(join(web, 'index.html'), 'utf8');
const jsName = [...html.matchAll(/src="([^"]+\.js)"/g)].map((match) => match[1]);
for (const ref of refsIn(html)) {
  if (ref.startsWith('/') || ref.startsWith('http:') || ref.startsWith('https:')) {
    throw new Error('Web export has an absolute asset reference, which breaks the /open-world/ subpath: ' + ref);
  }
}
if (jsName.length === 0) throw new Error('Web export HTML has no script');
for (const name of jsName) {
  await assertFile(join(web, name.split('?')[0]), 'Missing web script ' + name);
}
if (!html.includes('const GODOT_THREADS_ENABLED = false;')) {
  throw new Error('Web export is not the single-threaded build. GitHub Pages will not send the cross-origin isolation headers a threaded build needs.');
}
const root = intoStaged ? staged : out;
if (!intoStaged) {
  await rm(out, { recursive: true, force: true });
  await cp(staged, out, { recursive: true });
}
await rm(join(root, 'open-world'), { recursive: true, force: true });
const before = await hashTree(root);
await cp(web, join(root, 'open-world'), { recursive: true });
const after = await hashTree(root);
for (const [path, hash] of before) {
  if (isHq(path)) continue;
  if (after.get(path) !== hash) throw new Error('Arcade file changed in the composite: ' + path);
}
for (const path of after.keys()) {
  if (!before.has(path) && !isHq(path)) throw new Error('Composite added a file outside open-world/: ' + path);
}
const added = [...after.keys()].filter((path) => !before.has(path));
if (!added.some((path) => path === join('open-world', 'index.html') || path.endsWith(sep + 'index.html') && path.startsWith('open-world'))) {
  throw new Error('Composite is missing open-world/index.html');
}
const wasm = added.filter((path) => path.endsWith('.wasm'));
const districtDir = join('open-world', 'districts') + sep;
const pck = added.filter((path) => path.endsWith('.pck') && !path.startsWith(districtDir));
const districtPcks = added.filter((path) => path.endsWith('.pck') && path.startsWith(districtDir));
if (wasm.length !== 1 || pck.length !== 1) throw new Error('Expected one wasm and one main pck, got ' + wasm.length + ' wasm and ' + pck.length + ' pck');
const wasmStat = await stat(join(root, wasm[0]));
const pckStat = await stat(join(root, pck[0]));
if (pckStat.size > MAIN_PACK_MAX) throw new Error('Main pack is over its ' + MAIN_PACK_MAX + ' byte budget: ' + pckStat.size);
const mainReport = summarize(await readPack(join(root, pck[0])));
if (mainReport.biggest.some(([, name]) => name.startsWith('districts/'))) throw new Error('A district leaked into the main pack');
if (Object.keys(mainReport.folders).some((name) => name === 'art-src' || name === 'design' || name === 'tests')) {
  throw new Error('Source-only folders leaked into the main pack: ' + Object.keys(mainReport.folders).join(', '));
}
const registry = JSON.parse(await readFile(join(world, 'data', 'districts.json'), 'utf8'));
const districtReports = [];
for (const [id, entry] of Object.entries(registry.districts || {})) {
  const rel = join('open-world', entry.pack);
  if (!districtPcks.includes(rel)) throw new Error('District pack missing from the composite: ' + rel);
  const budget = Math.min(Number(entry.budget_bytes) || DISTRICT_PACK_MAX, DISTRICT_PACK_MAX);
  const report = summarize(await readPack(join(root, rel)));
  if (report.bytes > budget) throw new Error('District pack ' + id + ' is over its ' + budget + ' byte budget: ' + report.bytes);
  districtReports.push({ id, budgetBytes: budget, ...report });
}
for (const path of districtPcks) {
  if (!districtReports.some((r) => join('open-world', registry.districts[r.id].pack) === path)) throw new Error('Unlisted district pack: ' + path);
}
const rootIndex = await readFile(join(root, 'index.html'), 'utf8');
if (!rootIndex.includes('./demo/')) throw new Error('Arcade landing no longer points at ./demo/');
console.log(JSON.stringify({
  composite: root,
  arcadeFiles: before.size,
  added: added.length,
  wasmBytes: wasmStat.size,
  pckBytes: pckStat.size,
  wasm: wasm[0],
  budget: {
    mainPackMaxBytes: MAIN_PACK_MAX,
    mainPackBytes: pckStat.size,
    mainPackMiB: mainReport.mib,
    mainPackGzipBytes: mainReport.gzipBytes,
    mainPackHeadroomMiB: +((MAIN_PACK_MAX - pckStat.size) / 1048576).toFixed(2),
    mainPackFolders: mainReport.folders,
    districts: districtReports.map((r) => ({ id: r.id, bytes: r.bytes, gzipBytes: r.gzipBytes, budgetBytes: r.budgetBytes, files: r.files })),
  },
}, null, 2));

function isHq(path) {
  return path === 'open-world' || path.startsWith('open-world' + sep);
}

function refsIn(text) {
  return [...text.matchAll(/(?:src|href)="([^"]+)"/g)].map((match) => match[1]);
}

async function assertFile(path, message) {
  const info = await stat(path).catch(() => null);
  if (!info?.isFile() || !info.size) throw new Error(message);
}

async function hashTree(root) {
  const map = new Map();
  async function walk(dir) {
    for (const name of await readdir(dir, { withFileTypes: true })) {
      const path = join(dir, name.name);
      if (name.isDirectory()) await walk(path);
      else if (name.isFile()) map.set(relative(root, path), createHash('sha256').update(await readFile(path)).digest('hex'));
    }
  }
  await walk(root);
  return map;
}

function run(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, stdio: 'inherit' });
    child.on('exit', (status) => status === 0 ? resolve() : reject(new Error(command + ' exited ' + status)));
  });
}
