import type { Song } from './catalog';

export const DAILY_ROTATION_SIZE = 6;
const ROTATION_TIME_ZONE = 'America/Chicago';
const DAY_MS = 86_400_000;

function centralDayIndex(date: Date): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: ROTATION_TIME_ZONE,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric'
  }).formatToParts(date);
  const field = (type: string) => Number(parts.find(part => part.type === type)?.value);
  return Math.floor(Date.UTC(field('year'), field('month') - 1, field('day')) / DAY_MS);
}

export function centralRotationDateLabel(date: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone: ROTATION_TIME_ZONE,
    month: 'short',
    day: 'numeric'
  }).format(date).toUpperCase();
}

/** Up to six ready tracks, cycling one position at Central midnight. Never pads a short catalog. */
export function dailyRotation<T extends Song>(
  songs: readonly T[],
  date: Date = new Date(),
  limit = DAILY_ROTATION_SIZE
): T[] {
  if (!Number.isInteger(limit) || limit < 1) return [];
  const ready = songs.filter(song => song.rightsStatus === 'cleared' &&
    Boolean(song.audio && song.audioVersion) &&
    (['easy', 'medium', 'hard'] as const).some(level => Boolean(song.charts?.[level])));
  if (!ready.length) return [];
  if (ready.length <= limit) return ready.slice();

  const start = centralDayIndex(date) % ready.length;
  return Array.from({ length: limit }, (_, index) => ready[(start + index) % ready.length]);
}
