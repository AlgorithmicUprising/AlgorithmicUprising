#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { readdir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const arcadeRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assetsRoot = path.join(arcadeRoot, 'r2-assets');
const catalogPath = path.join(arcadeRoot, 'games', 'bars-per-watt', 'catalog.json');
const bucket = 'bars-per-watt-media';
const publicOrigin = 'https://media.algorithmicuprising.com';
const cacheControl = 'public, max-age=31536000, immutable';

function requireValue(value, message) {
  if (!value) throw new Error(message);
}

function mimeType(key) {
  const ext = path.extname(key).toLowerCase();
  const types = {
    '.json': 'application/json',
    '.m4a': 'audio/mp4',
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
    '.mp4': 'video/mp4',
    '.webm': 'video/webm',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.wasm': 'application/wasm',
    '.woff2': 'font/woff2'
  };
  return types[ext] || 'application/octet-stream';
}

function safeKey(key) {
  const segments = key.split('/');
  if (!key || key.startsWith('/') || segments.some((part) => !part || part === '.' || part === '..')) {
    throw new Error('Unsafe R2 key: ' + key);
  }
  return key;
}

async function listFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isSymbolicLink()) throw new Error('R2 source tree cannot contain symbolic links: ' + fullPath);
    if (entry.isDirectory()) files.push(...await listFiles(fullPath));
    else if (entry.isFile()) files.push(fullPath);
    else throw new Error('Unsupported file in R2 source tree: ' + fullPath);
  }
  return files.sort();
}

async function sourceAsset(key) {
  safeKey(key);
  const fullPath = path.resolve(assetsRoot, ...key.split('/'));
  if (!fullPath.startsWith(assetsRoot + path.sep)) throw new Error('R2 source path escapes r2-assets: ' + key);
  const info = await stat(fullPath).catch(() => null);
  if (!info?.isFile() || info.size < 1) throw new Error('Missing or empty GitHub R2 source file: arcade/r2-assets/' + key);
  return { key, fullPath, size: info.size, contentType: mimeType(key) };
}

async function validateCatalog() {
  const catalog = JSON.parse(await readFile(catalogPath, 'utf8'));
  if (!Array.isArray(catalog.songs)) throw new Error('Bars Per Watt catalog must have a songs array.');

  const assets = new Map();
  for (const song of catalog.songs) {
    const hasMedia = ['audioVersion', 'audio', 'charts'].some((key) => Object.hasOwn(song, key));
    if (!hasMedia) continue;

    requireValue(song.rightsStatus === 'cleared', 'Catalog song ' + song.id + ' must be rights-cleared before publishing media.');
    requireValue(typeof song.id === 'string' && /^[A-Za-z0-9-]+$/.test(song.id), 'Catalog song has an invalid id.');
    requireValue(typeof song.audioVersion === 'string' && /^[A-Za-z0-9._-]+$/.test(song.audioVersion), 'Catalog song ' + song.id + ' needs a safe audioVersion.');
    requireValue(Number.isFinite(song.durationSec) && song.durationSec > 0, 'Catalog song ' + song.id + ' needs a positive durationSec.');

    const baseUrl = publicOrigin + '/bars-per-watt/' + encodeURIComponent(song.id) + '/' + encodeURIComponent(song.audioVersion);
    const audioUrl = baseUrl + '/audio.m4a';
    requireValue(song.audio === audioUrl, 'Catalog audio path/version mismatch for ' + song.id + '; expected ' + audioUrl + '.');
    const audioKey = safeKey('bars-per-watt/' + song.id + '/' + song.audioVersion + '/audio.m4a');
    assets.set(audioKey, await sourceAsset(audioKey));

    requireValue(song.charts && typeof song.charts === 'object', 'Catalog song ' + song.id + ' needs Easy, Medium and Hard chart URLs.');
    for (const difficulty of ['easy', 'medium', 'hard']) {
      const expectedUrl = baseUrl + '/' + difficulty + '.json';
      requireValue(song.charts[difficulty] === expectedUrl, 'Catalog ' + difficulty + ' chart path/version mismatch for ' + song.id + '; expected ' + expectedUrl + '.');
      const key = safeKey('bars-per-watt/' + song.id + '/' + song.audioVersion + '/' + difficulty + '.json');
      const asset = await sourceAsset(key);
      const chart = JSON.parse(await readFile(asset.fullPath, 'utf8'));
      requireValue(chart.format === 'bars-per-watt-chart-v1', 'Unsupported chart format in ' + key + '.');
      requireValue(chart.songId === song.id, 'Chart songId does not match its catalog entry: ' + key + '.');
      requireValue(chart.difficulty === difficulty, 'Chart difficulty does not match its path: ' + key + '.');
      requireValue(chart.audioVersion === song.audioVersion, 'Chart audioVersion does not match its catalog entry: ' + key + '.');
      requireValue(Number.isFinite(chart.durationSec) && Math.abs(chart.durationSec - song.durationSec) <= 0.02, 'Chart duration does not match its catalog entry: ' + key + '.');
      requireValue(Array.isArray(chart.bpms) && chart.bpms.length > 0, 'Chart has no BPM segments: ' + key + '.');
      requireValue(Array.isArray(chart.notes) && chart.notes.length > 0, 'Chart has no playable notes: ' + key + '.');
      assets.set(key, asset);
    }
  }

  requireValue(assets.size > 0, 'No charted Bars Per Watt assets are referenced by the catalog.');
  const trackedFiles = await listFiles(assetsRoot);
  const trackedKeys = new Set(trackedFiles.map((file) => path.relative(assetsRoot, file).split(path.sep).join('/')));
  for (const key of assets.keys()) {
    requireValue(trackedKeys.has(key), 'R2 source file is not tracked: arcade/r2-assets/' + key);
  }
  for (const key of trackedKeys) {
    requireValue(assets.has(key), 'Unreferenced file in R2 source tree; add it to an approved catalog or remove it: arcade/r2-assets/' + key);
  }
  return [...assets.values()];
}

function runAws(args) {
  try {
    return execFileSync('aws', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (error) {
    const detail = String(error.stderr || error.message || 'AWS CLI failed').trim();
    throw new Error('R2 S3 API command failed: ' + detail.slice(0, 1200));
  }
}

async function upload() {
  requireValue(process.env.GITHUB_EVENT_NAME === 'push', 'R2 uploads are allowed only from a main-branch push after merge.');
  requireValue(process.env.GITHUB_REF === 'refs/heads/main', 'R2 uploads are allowed only for refs/heads/main.');
  requireValue(process.env.R2_MERGED_PR === 'true', 'R2 upload requires a verified pull request merged into main.');
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID || '';
  requireValue(/^[0-9a-f]{32}$/i.test(accountId), 'Set the CLOUDFLARE_ACCOUNT_ID repository variable.');
  requireValue(process.env.AWS_ACCESS_KEY_ID, 'Set the R2_ACCESS_KEY_ID GitHub secret.');
  requireValue(process.env.AWS_SECRET_ACCESS_KEY, 'Set the R2_SECRET_ACCESS_KEY GitHub secret.');

  const endpoint = 'https://' + accountId + '.r2.cloudflarestorage.com';
  const assets = await validateCatalog();
  for (const asset of assets) {
    runAws([
      's3', 'cp', asset.fullPath, 's3://' + bucket + '/' + asset.key,
      '--endpoint-url', endpoint,
      '--region', 'auto',
      '--content-type', asset.contentType,
      '--cache-control', cacheControl,
      '--no-progress',
      '--only-show-errors'
    ]);
    const head = JSON.parse(runAws([
      's3api', 'head-object',
      '--bucket', bucket,
      '--key', asset.key,
      '--endpoint-url', endpoint,
      '--region', 'auto'
    ]));
    requireValue(head.ContentLength === asset.size, 'R2 size verification failed for ' + asset.key + '.');
    requireValue(head.ContentType === asset.contentType, 'R2 Content-Type verification failed for ' + asset.key + '.');
    requireValue(String(head.CacheControl || '').toLowerCase().includes('immutable'), 'R2 Cache-Control verification failed for ' + asset.key + '.');
  }
  console.log('Uploaded and verified ' + assets.length + ' Bars Per Watt audio/chart objects in R2.');
}

const mode = process.argv[2];
if (mode === '--validate') {
  const assets = await validateCatalog();
  console.log('Bars Per Watt catalog and ' + assets.length + ' GitHub R2 source files are consistent.');
} else if (mode === '--upload') {
  await upload();
} else {
  throw new Error('Usage: node tools/deploy-r2-assets.mjs --validate|--upload');
}
