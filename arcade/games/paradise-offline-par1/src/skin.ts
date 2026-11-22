export type Palette = Record<string, string>;
export type SkinImages = {
  id: string;
  palette: Palette;
  landscape: ImageBitmap;
  portrait: ImageBitmap;
  actors: ImageBitmap;
  props: ImageBitmap;
};
type Manifest = {
  schema: string;
  game: string;
  id: string;
  files: { landscape: string; portrait: string; actors: string; props: string };
  palette: Palette;
};

const MAX_ASSET_BYTES = 8 * 1024 * 1024;
const MAX_DIMENSION = 4096;
const COLORS = new Set(['accent', 'ink', 'paper', 'sky', 'grass', 'warning']);
const FALLBACK_PALETTE: Palette = {
  accent: '#d7ff00', ink: '#211a25', paper: '#f6eddf',
  sky: '#e8b187', grass: '#718b56', warning: '#ff4382'
};

function safeName(value: unknown): value is string {
  if (typeof value !== 'string' || value.startsWith('.') || value.includes('..') || value.includes('\\')) return false;
  const name = value.startsWith('assets/') ? value.slice(7) : value;
  return /^[a-zA-Z0-9_-][a-zA-Z0-9._-]*[.](?:png|webp)$/.test(name) &&
    (!value.includes('/') || value.startsWith('assets/') && value.indexOf('/', 7) === -1);
}

function validatePalette(value: unknown): Palette {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid skin palette');
  const out: Palette = { ...FALLBACK_PALETTE };
  for (const [key, color] of Object.entries(value as Record<string, unknown>)) {
    if (!COLORS.has(key) || typeof color !== 'string' || !/^#[0-9a-fA-F]{6}$/.test(color)) {
      throw new Error('Invalid skin palette entry');
    }
    out[key] = color;
  }
  return out;
}

async function loadBitmap(url: URL): Promise<ImageBitmap> {
  const response = await fetch(url.href, { credentials: 'same-origin', cache: 'no-cache' });
  if (!response.ok) throw new Error('Skin asset request failed');
  const declared = Number(response.headers.get('content-length') || 0);
  if (declared > MAX_ASSET_BYTES) throw new Error('Skin asset exceeds size limit');
  const blob = await response.blob();
  if (blob.size === 0 || blob.size > MAX_ASSET_BYTES) throw new Error('Skin asset is empty or too large');
  const bitmap = await createImageBitmap(blob);
  if (bitmap.width > MAX_DIMENSION || bitmap.height > MAX_DIMENSION) {
    bitmap.close();
    throw new Error('Skin image dimensions exceed limit');
  }
  return bitmap;
}

export class SkinBank {
  current: SkinImages | null = null;
  palette: Palette = { ...FALLBACK_PALETTE };

  async load(url: string | null): Promise<boolean> {
    this.clear();
    if (!url) return false;
    const manifestUrl = new URL(url, document.baseURI);
    if (manifestUrl.origin !== location.origin || !manifestUrl.pathname.toLowerCase().endsWith('.json')) {
      throw new Error('Skin manifest must be same-origin JSON');
    }
    const response = await fetch(manifestUrl.href, { credentials: 'same-origin', cache: 'no-cache' });
    if (!response.ok) throw new Error('Skin manifest request failed');
    const size = Number(response.headers.get('content-length') || 0);
    if (size > 32 * 1024) throw new Error('Skin manifest exceeds size limit');
    const manifestText = await response.text();
    if (manifestText.length > 32 * 1024) throw new Error('Skin manifest exceeds size limit');
    const manifest = JSON.parse(manifestText) as Manifest;
    if (manifest.schema !== 'paradise-offline-skin/v1' || manifest.game !== 'paradise-offline-par1' ||
        typeof manifest.id !== 'string' || manifest.id.length > 48) throw new Error('Skin identity does not match');
    const keys = ['landscape', 'portrait', 'actors', 'props'] as const;
    for (const key of keys) if (!safeName(manifest.files?.[key])) throw new Error('Invalid skin asset path');
    const palette = validatePalette(manifest.palette);
    const urls = keys.map(key => new URL(manifest.files[key], manifestUrl));
    const baseDir = manifestUrl.pathname.slice(0, manifestUrl.pathname.lastIndexOf('/'));
    if (urls.some((asset, i) => {
      const assetDir = asset.pathname.slice(0, asset.pathname.lastIndexOf('/'));
      const expectedDir = baseDir + (manifest.files[keys[i]].startsWith('assets/') ? '/assets' : '');
      return asset.origin !== manifestUrl.origin || assetDir !== expectedDir;
    })) {
      throw new Error('Skin assets must stay beside the manifest');
    }
    const images = await Promise.all(urls.map(loadBitmap));
    this.current = { id: manifest.id, palette, landscape: images[0], portrait: images[1], actors: images[2], props: images[3] };
    this.palette = palette;
    return true;
  }

  clear() {
    if (this.current) {
      this.current.landscape.close(); this.current.portrait.close();
      this.current.actors.close(); this.current.props.close();
    }
    this.current = null;
    this.palette = { ...FALLBACK_PALETTE };
  }
}
