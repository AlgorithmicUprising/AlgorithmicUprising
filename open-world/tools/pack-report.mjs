// Read a Godot 4 .pck directory (pack format 2 to 4, unencrypted) and report bytes per top folder, the biggest
// files, and the gzip size (GitHub Pages serves .pck as application/octet-stream with gzip). Used by
// stage-composite.mjs for the CI pack budget report; also runnable by hand:
//   node tools/pack-report.mjs build/web/index.pck [more.pck ...]
import { readFile } from 'node:fs/promises';
import { gzipSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';

export async function readPack(path) {
  const buf = await readFile(path);
  if (buf.toString('latin1', 0, 4) !== 'GDPC') throw new Error('Not a Godot pack: ' + path);
  const format = buf.readUInt32LE(4);
  if (format < 2 || format > 4) throw new Error('Unsupported pack format ' + format + ': ' + path);
  const flags = buf.readUInt32LE(20);
  if (flags & 1) throw new Error('Encrypted pack directory: ' + path);
  let p;
  let base = 0n;
  if (format >= 3) {
    base = buf.readBigUInt64LE(24);
    p = Number(buf.readBigUInt64LE(32));
  } else {
    base = buf.readBigUInt64LE(24);
    p = 32 + 16 * 4;
  }
  const count = buf.readUInt32LE(p);
  p += 4;
  const files = [];
  for (let i = 0; i < count; i++) {
    const len = buf.readUInt32LE(p);
    p += 4;
    const name = buf.toString('utf8', p, p + len).replace(/\0+$/, '');
    p += len;
    const offset = buf.readBigUInt64LE(p);
    const size = Number(buf.readBigUInt64LE(p + 8));
    p += 16 + 16 + 4;
    files.push({ name, offset: Number(base + offset), size });
  }
  return { path, bytes: buf.length, format, files, gzipBytes: gzipSync(buf, { level: 6 }).length };
}

export function folderOf(name) {
  const clean = name.replace(/^res:\/\//, '');
  const imported = clean.match(/^\.godot\/imported\/(.+?)-[0-9a-f]{32}\./);
  if (imported) {
    const base = imported[1];
    if (base.startsWith('fony2d_')) return 'imported: fony2d atlases';
    return 'imported: other textures/meshes';
  }
  const parts = clean.split('/');
  if (parts.length === 1) return '(root)';
  if (parts[0] === 'assets' && parts.length > 3) return parts.slice(0, 3).join('/');
  if (parts[0] === 'assets') return parts.slice(0, 2).join('/');
  return parts[0];
}

export function summarize(pack) {
  const folders = new Map();
  for (const file of pack.files) folders.set(folderOf(file.name), (folders.get(folderOf(file.name)) || 0) + file.size);
  return {
    pack: pack.path,
    bytes: pack.bytes,
    mib: +(pack.bytes / 1048576).toFixed(2),
    gzipBytes: pack.gzipBytes,
    gzipMiB: +(pack.gzipBytes / 1048576).toFixed(2),
    files: pack.files.length,
    folders: Object.fromEntries([...folders.entries()].sort((a, b) => b[1] - a[1])),
    biggest: [...pack.files].sort((a, b) => b.size - a.size).slice(0, 8).map((f) => [f.size, f.name]),
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  for (const path of process.argv.slice(2)) console.log(JSON.stringify(summarize(await readPack(path)), null, 2));
}
