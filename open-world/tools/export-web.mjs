import { mkdir, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const world = join(dirname(fileURLToPath(import.meta.url)), '..');
const godot = process.env.GODOT_BIN || 'godot';
const out = process.env.AU_WEB_DIR || join(world, 'build', 'web');
const index = join(out, 'index.html');

await mkdir(join(world, 'build'), { recursive: true });
await mkdir(join(world, 'node_modules'), { recursive: true });
await writeFile(join(world, 'build', '.gdignore'), '');
await writeFile(join(world, 'node_modules', '.gdignore'), '');
await mkdir(out, { recursive: true });

const code = await run(godot, ['--headless', '--path', world, '--export-release', 'Web', index]);
if (code !== 0) process.exit(code);

function run(command, args) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { cwd: world, stdio: 'inherit' });
    child.on('exit', (status) => resolve(status ?? 1));
  });
}
