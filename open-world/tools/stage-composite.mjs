// Build a GitHub Pages tree: current arcade staging output at the root,
// Godot web export under open-world/. Does not upload or deploy.
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { cp, mkdir, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const world = join(here, '..');
const repo = join(world, '..');
const arcade = join(repo, 'arcade');
const staged = join(arcade, '.pages');
const web = process.env.AU_WEB_DIR || join(world, 'build', 'web');
const out = process.env.AU_COMPOSITE_DIR || join(world, 'build', 'pages-composite');
const skipArcadeBuild = process.argv.includes('--skip-arcade-build');

if (!skipArcadeBuild) {
  await run('npm', ['run', 'build'], arcade);
}
await run('npm', ['run', 'stage-pages'], arcade);
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
await rm(out, { recursive: true, force: true });
await cp(staged, out, { recursive: true });
const before = await hashTree(out);
await cp(web, join(out, 'open-world'), { recursive: true });
const after = await hashTree(out);
for (const [path, hash] of before) {
  if (after.get(path) !== hash) throw new Error('Arcade file changed in the composite: ' + path);
}
for (const path of after.keys()) {
  if (!before.has(path) && path !== 'open-world' && !path.startsWith('open-world' + sep) && path !== 'open-world') {
    throw new Error('Composite added a file outside open-world/: ' + path);
  }
}
const added = [...after.keys()].filter((path) => !before.has(path));
if (!added.some((path) => path === join('open-world', 'index.html') || path.endsWith(sep + 'index.html') && path.startsWith('open-world'))) {
  throw new Error('Composite is missing open-world/index.html');
}
const wasm = added.filter((path) => path.endsWith('.wasm'));
const pck = added.filter((path) => path.endsWith('.pck'));
if (wasm.length !== 1 || pck.length !== 1) throw new Error('Expected one wasm and one pck, got ' + wasm.length + ' wasm and ' + pck.length + ' pck');
const wasmStat = await stat(join(out, wasm[0]));
const pckStat = await stat(join(out, pck[0]));
if (pckStat.size > 8 * 1024 * 1024) throw new Error('Pack is unexpectedly large: ' + pckStat.size);
const rootIndex = await readFile(join(out, 'index.html'), 'utf8');
if (!rootIndex.includes('./demo/')) throw new Error('Arcade landing no longer points at ./demo/');
console.log(JSON.stringify({
  composite: out,
  arcadeFiles: before.size,
  added: added.length,
  wasmBytes: wasmStat.size,
  pckBytes: pckStat.size,
  wasm: wasm[0],
}, null, 2));

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
