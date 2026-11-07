import defaults from '../skins/placeholder/skin.json';
import type { Texts } from '../../../core/src/cartridge';

export type Skin = {
  id: string; strings: Texts; palette: Record<string, string>;
  sfx: Record<string, number[]>; frames: Record<string, HTMLImageElement>;
};
const fallback = (): Skin => ({
  id: 'placeholder', strings: { ...defaults.strings }, palette: { ...defaults.palette },
  sfx: { ...defaults.sfx }, frames: Object.create(null)
});
const slug = /^[a-z0-9-]+$/;
const frameName = /^(?:blocker|packet|brick|tracker|fx|bg|logo|ui)_[a-z0-9_]+_[0-9]{2}$/;
const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

function webURL(path: string, base: string) {
  const url = new URL(path, base);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) throw Error('Unsupported skin URL');
  return url;
}

function manifestURL(path: string, base: string) {
  if (path.startsWith('data:')) {
    if (path.length > 1_500_000 || !/^data:application\/json;base64,[A-Za-z0-9+/]+={0,2}$/i.test(path)) throw Error('Unsupported inline skin');
    return new URL(path);
  }
  return webURL(path, base);
}

function inlineImageURL(path: string) {
  if (path.length > 2_800_000 || !/^data:image\/(?:png|webp);base64,[A-Za-z0-9+/]+={0,2}$/i.test(path)) throw Error('Unsupported inline frame');
  return new URL(path);
}

async function bytes(url: URL, limit: number, signal: AbortSignal) {
  const response = await fetch(url, { signal, mode: 'cors', credentials: 'omit', referrerPolicy: 'no-referrer' });
  if (!response.ok || Number(response.headers.get('content-length')) > limit || !response.body) throw Error('Skin resource unavailable or too large');
  const reader = response.body.getReader();
  const chunks: Uint8Array<ArrayBuffer>[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > limit) { await reader.cancel(); throw Error('Skin resource too large'); }
      chunks.push(new Uint8Array(value));
    }
  } finally { reader.releaseLock(); }
  return new Blob(chunks);
}

function safeSVG(source: string) {
  const doc = new DOMParser().parseFromString(source, 'image/svg+xml');
  if (doc.doctype || doc.documentElement.localName !== 'svg') throw Error('Invalid vector frame');
  const elements = new Set('svg g path rect circle ellipse polygon polyline line title desc'.split(' '));
  const attributes = new Set('xmlns viewBox width height x y x1 y1 x2 y2 cx cy r rx ry d points fill fill-rule stroke stroke-width stroke-linecap stroke-linejoin opacity transform'.split(' '));
  for (const el of Array.from(doc.querySelectorAll('*'))) {
    if (!elements.has(el.localName) || el.namespaceURI !== 'http://www.w3.org/2000/svg') throw Error('Unsupported vector frame');
    for (const attr of Array.from(el.attributes)) {
      if (!attributes.has(attr.name) || /url\s*\(|[\\<>]/i.test(attr.value)) throw Error('Unsafe vector frame');
    }
  }
  return new XMLSerializer().serializeToString(doc.documentElement);
}

async function imageFrame(url: URL, signal: AbortSignal) {
  const inline = url.protocol === 'data:' ? /^data:image\/(png|webp);base64,/i.exec(url.href) : null;
  const ext = inline ? inline[1].toLowerCase() : url.pathname.split('.').pop()?.toLowerCase();
  if (!ext || !['png', 'webp', 'svg'].includes(ext) || (url.protocol === 'data:' && !inline)) throw Error('Unsupported frame format');
  const data = await bytes(url, 2 * 1024 * 1024, signal);
  const content = ext === 'svg' ? new Blob([safeSVG(await data.text())], { type: 'image/svg+xml' }) :
    data.slice(0, data.size, 'image/' + ext);
  const objectURL = URL.createObjectURL(content);
  try {
    const image = new Image(); image.src = objectURL;
    await image.decode(); signal.throwIfAborted();
    if (!image.naturalWidth || !image.naturalHeight || Math.max(image.naturalWidth, image.naturalHeight) > 2048) throw Error('Oversized frame');
    return image;
  } finally { URL.revokeObjectURL(objectURL); }
}

function dictionary(value: unknown) {
  if (value === undefined) return {};
  if (!record(value)) throw Error('Expected a skin dictionary');
  return value;
}

async function resolveSkin(url: URL, seen: Set<string>, signal: AbortSignal, warnings: Set<string>): Promise<Skin> {
  if (seen.has(url.href) || seen.size >= 4) throw Error('Invalid skin inheritance');
  seen.add(url.href);
  const manifestLimit = url.protocol === 'data:' ? 1024 * 1024 : 256 * 1024;
  const manifest = JSON.parse(await (await bytes(url, manifestLimit, signal)).text(), (key, value) => {
    if (['constructor', 'prototype', '__proto__'].includes(key)) throw Error('Invalid skin key');
    return value;
  });
  if (!record(manifest) || manifest.game !== 'cookie-wall' || typeof manifest.id !== 'string' || !slug.test(manifest.id)) throw Error('Invalid Cookie Wall skin');
  let skin = fallback();
  if (manifest.extends !== undefined) {
    const parent = manifest.extends;
    if (typeof parent !== 'string' || !slug.test(parent) || parent === manifest.id || (parent === 'au' && manifest.id !== 'au')) throw Error('Invalid parent skin');
    if (parent !== 'placeholder') skin = await resolveSkin(webURL('../' + parent + '/skin.json', url.href), seen, signal, warnings);
  }
  skin.id = manifest.id;
  for (const [key, value] of Object.entries(dictionary(manifest.strings))) {
    if (typeof value !== 'string' || value.length > 1024) throw Error('Invalid skin string');
    if (Object.hasOwn(defaults.strings, key)) skin.strings[key] = value;
  }
  for (const [key, value] of Object.entries(dictionary(manifest.palette))) {
    if (typeof value !== 'string' || !/^#[0-9a-f]{6}$/i.test(value)) throw Error('Invalid skin color');
    if (Object.hasOwn(defaults.palette, key)) skin.palette[key] = value;
  }
  for (const [key, value] of Object.entries(dictionary(manifest.sfx))) {
    if (!Array.isArray(value) || value.length > 24 || !value.every(n => typeof n === 'number' && Number.isFinite(n))) throw Error('Invalid sound parameters');
    if (Object.hasOwn(defaults.sfx, key)) skin.sfx[key] = value;
  }
  const files = Object.entries(dictionary(manifest.files));
  if (files.length > 64) throw Error('Too many frames');
  const folder = url.protocol === 'data:' ? null : new URL('.', url);
  for (const [key, path] of files) {
    if (!frameName.test(key) || typeof path !== 'string') throw Error('Invalid skin frame');
    const asset = folder ? webURL(path, url.href) : inlineImageURL(path);
    if (folder && asset.origin === folder.origin && !asset.pathname.startsWith(folder.pathname)) throw Error('Frame outside skin folder');
    try { skin.frames[key] = await imageFrame(asset, signal); }
    catch { signal.throwIfAborted(); delete skin.frames[key]; warnings.add(key); }
  }
  return skin;
}

export class SkinBank {
  current = fallback();
  private loading?: AbortController;
  constructor(private changed: () => void, private emit: (name: string, detail: Record<string, unknown>) => void) {}
  dispose() { this.loading?.abort(); this.loading = undefined; }
  async load(path: string | null) {
    this.dispose();
    const request = new AbortController(); this.loading = request;
    const timer = window.setTimeout(() => request.abort(), 8000);
    let selected = fallback();
    const warnings = new Set<string>();
    try {
      if (path) selected = await resolveSkin(manifestURL(path, document.baseURI), new Set(), request.signal, warnings);
    } catch {
      if (this.loading !== request) return;
      this.emit('game:error', { code: 'SKIN_LOAD_FAILED', message: 'Using procedural skin.' });
    } finally { clearTimeout(timer); }
    if (this.loading !== request) return;
    this.current = selected; this.changed();
    if (warnings.size) this.emit('game:error', { code: 'FRAME_FALLBACK', frames: Array.from(warnings) });
    this.emit('game:skin-loaded', { skin: selected.id, usingPlaceholder: selected.id === 'placeholder' });
  }
}
