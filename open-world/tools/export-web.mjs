import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
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
// M0 district packs: one export preset per district ("District <id>"), written next to index.pck as
// districts/<id>.pck. The main preset excludes districts/*, so district content never lands in index.pck.
const registry = JSON.parse(await readFile(join(world, 'data', 'districts.json'), 'utf8'));
await rm(join(out, 'districts'), { recursive: true, force: true });
for (const [id, entry] of Object.entries(registry.districts || {})) {
  const target = join(out, entry.pack);
  await mkdir(dirname(target), { recursive: true });
  const status = await run(godot, ['--headless', '--path', world, '--export-pack', 'District ' + id, target]);
  if (status !== 0) process.exit(status);
}
// Godot's official third-party notices (COPYRIGHT.txt at the pinned tag), linked from the
// Zero X loading shell. Godot's "Complying with licenses" page suggests shipping it as
// GODOT_COPYRIGHT.txt.
await copyFile(join(world, 'web', 'GODOT_COPYRIGHT.txt'), join(out, 'GODOT_COPYRIGHT.txt'));
// Zero art for the loading shell. The same file is imported into the pack for the boot scene.
await copyFile(join(world, 'web', 'zero_x_zero.webp'), join(out, 'zero_x_zero.webp'));
// Front end: the Act I intro video plays as an HTML <video> overlay and lives NEXT TO the pack in
// media/intro/, never inside it (data/intro_video.json lists the sources in order). The media guard
// keeps video out of the repo, so the real cut comes in through AU_INTRO_MP4 at export time and a
// labelled placeholder is generated here with ffmpeg. With neither, the game shows a short
// "intro video in production" card and goes on to P.1.
const media = join(out, 'media', 'intro');
await rm(join(out, 'media'), { recursive: true, force: true });
await mkdir(media, { recursive: true });
if (process.env.AU_INTRO_MP4) {
  await copyFile(process.env.AU_INTRO_MP4, join(media, 'project-zero-intro-720p.mp4'));
  console.log('intro: copied AU_INTRO_MP4 ->', join(media, 'project-zero-intro-720p.mp4'));
}
if (process.env.AU_INTRO_PLACEHOLDER !== '0') {
  const font = join(world, 'assets', 'fonts', 'PressStart2P-Regular.ttf');
  const text = (line, size, y) =>
    `drawtext=fontfile='${font}':text='${line}':fontsize=${size}:fontcolor=0xf2e6d0:x=(w-text_w)/2:y=${y}`;
  const filter = [
    text('PROJECT ZERO', 56, 230),
    text('ACT I INTRO - PLACEHOLDER', 22, 330),
    text('THE REAL CUT REPLACES THIS FILE', 16, 400),
    `drawtext=fontfile='${font}':text='%{eif\\:6-t\\:d}':fontsize=40:fontcolor=0xff3b1f:x=(w-text_w)/2:y=480`,
  ].join(',');
  const status = await run('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-y',
    '-f', 'lavfi', '-i', 'color=c=0x0b0a10:s=1280x720:r=30:d=6',
    '-f', 'lavfi', '-i', 'sine=frequency=220:sample_rate=44100:duration=6',
    '-vf', filter, '-af', 'volume=0.15,afade=t=out:st=5:d=1',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-profile:v', 'main', '-crf', '30',
    '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', '-shortest',
    join(media, 'intro-placeholder.mp4'),
  ]);
  if (status !== 0) console.warn('intro: ffmpeg placeholder failed (' + status + '); the game will show the in-production card');
}

function run(command, args) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { cwd: world, stdio: 'inherit' });
    child.on('exit', (status) => resolve(status ?? 1));
    child.on('error', () => resolve(127)); // e.g. ffmpeg not installed: carry on without the placeholder
  });
}
