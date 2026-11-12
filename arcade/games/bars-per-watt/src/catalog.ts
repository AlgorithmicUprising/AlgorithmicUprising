import type { Difficulty } from './chart';

export interface Song {
  id: string; title: string; durationSec: number; explicit: boolean;
  rightsStatus: 'pending' | 'cleared';
  audioVersion?: string; audio?: string;
  artist?: string; sleeve?: string;
  charts?: Partial<Record<Difficulty, string>>;
}
export interface Catalog { version: 1; songs: Song[] }
export const humanZoo: Song = {
  id: 'AU-001', title: 'The Human Zoo', durationSec: 318.8,
  explicit: true, rightsStatus: 'pending'
};

function allowed(url: URL, base: URL) {
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) throw Error('Invalid media URL');
  if (url.origin !== base.origin) throw Error('Media must be served from the catalog origin');
  if (url.protocol !== 'https:' && !['localhost', '127.0.0.1'].includes(url.hostname))
    throw Error('Media must use HTTPS');
  return url;
}
const firstPartyCatalogOrigins = new Set([
  'https://algorithmicuprising.com', 'https://www.algorithmicuprising.com',
  'https://algorithmicuprising.github.io'
]);
export function assetUrl(path: string, catalogUrl: URL): URL {
  if (typeof path !== 'string' || !path || path.length > 1024) throw Error('Missing media path');
  return allowed(new URL(path, catalogUrl), catalogUrl);
}
export async function loadCatalog(url: URL, signal: AbortSignal): Promise<Catalog> {
  const page = new URL(document.baseURI);
  if (url.origin !== page.origin && !firstPartyCatalogOrigins.has(url.origin))
    throw Error('Catalog origin is not allowed');
  allowed(url, url);
  // Owner-only same-origin previews need their sign-in cookie for static assets.
  // Keep credentials off the approved cross-origin public catalog hosts.
  const response = await fetch(url, { signal,
    credentials: url.origin === page.origin ? 'same-origin' : 'omit' });
  if (!response.ok) throw Error('Catalog HTTP ' + response.status);
  if (Number(response.headers.get('content-length')) > 256000) throw Error('Catalog too large');
  const raw = await response.text();
  if (raw.length > 256000) throw Error('Catalog too large');
  const catalog = JSON.parse(raw) as Catalog;
  if (catalog.version !== 1 || !Array.isArray(catalog.songs) || catalog.songs.length > 100)
    throw Error('Unsupported catalog');
  for (const song of catalog.songs) {
    if (!/^[A-Za-z0-9-]{1,80}$/.test(song.id) || typeof song.title !== 'string' ||
        song.title.length > 120 || !Number.isFinite(song.durationSec) || song.durationSec <= 0 ||
        song.durationSec > 900 || typeof song.explicit !== 'boolean' ||
        !['pending', 'cleared'].includes(song.rightsStatus))
      throw Error('Invalid song metadata');
    if (song.artist !== undefined && (typeof song.artist !== 'string' || song.artist.length > 120))
      throw Error('Invalid artist');
    if (song.sleeve !== undefined) assetUrl(song.sleeve, url);
    if (song.audio) assetUrl(song.audio, url);
    if (song.audio && !/^[a-z0-9-]{1,100}$/.test(song.audioVersion || ''))
      throw Error('Missing audio version');
    for (const path of Object.values(song.charts || {})) if (path) assetUrl(path, url);
  }
  return catalog;
}
