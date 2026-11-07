// Keep a failed write available to other instances of this cartridge for the life of the page.
const volatile = new Map<string, string>();
export function readLocal(key: string): string | null {
  if (volatile.has(key)) return volatile.get(key)!;
  try { return localStorage.getItem(key); } catch { return null; }
}
export function writeLocal(key: string, value: string) {
  try { localStorage.setItem(key, value); volatile.delete(key); }
  catch { volatile.set(key, value); }
}
