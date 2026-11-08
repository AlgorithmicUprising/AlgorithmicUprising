import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(process.env.AU_COMPOSITE_DIR || join(dirname(fileURLToPath(import.meta.url)), '..', 'build', 'pages-composite'));
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.ico': 'image/x-icon',
  '.webmanifest': 'application/manifest+json',
};
const port = Number(process.env.PORT || 8090);
const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', 'http://127.0.0.1');
    let path = normalize(resolve(root, '.' + decodeURIComponent(url.pathname)));
    if (path !== root && !path.startsWith(root + sep)) {
      res.writeHead(403).end('Forbidden');
      return;
    }
    let info = await stat(path).catch(() => null);
    if (info?.isDirectory()) path = join(path, 'index.html');
    const data = await readFile(path);
    const type = types[extname(path)] || 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' }).end(data);
  } catch {
    res.writeHead(404).end('Not found');
  }
});
server.listen(port, '127.0.0.1', () => {
  console.log(`Composite preview: http://127.0.0.1:${port}/`);
  console.log(`HQ slice: http://127.0.0.1:${port}/open-world/`);
});
