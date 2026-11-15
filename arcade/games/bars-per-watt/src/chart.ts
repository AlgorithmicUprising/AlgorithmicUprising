export type Lane = 0 | 1 | 2 | 3;
export type Difficulty = 'easy' | 'medium' | 'hard';

export interface ChartSource {
  format: 'bars-per-watt-chart-v1';
  id: string;
  songId: string;
  difficulty: Difficulty;
  audioVersion: string;
  durationSec: number;
  offsetSec: number;
  bpms: { beat: string; bpm: number }[];
  notes: { beat: string; lane: Lane; endBeat?: string }[];
}
export interface Note { lane: Lane; time: number; endTime?: number }
export interface Chart {
  id: string; songId: string; difficulty: Difficulty; audioVersion: string;
  durationSec: number; notes: readonly Note[];
}

/** Decimal and fractional beats are parsed without floating point accumulation. */
function beat(value: string): number {
  if (!/^(?:\d+(?:\.\d{1,6})?|\d+\/\d+)$/.test(value)) throw Error('Invalid beat: ' + value);
  const [numerator, denominator] = value.split('/').map(Number);
  const parsed = denominator === undefined ? numerator : numerator / denominator;
  if (!Number.isFinite(parsed) || parsed < 0 || (denominator !== undefined && denominator === 0))
    throw Error('Invalid beat: ' + value);
  return parsed;
}
export function compileChart(raw: unknown): Chart {
  const source = raw as ChartSource;
  if (!source || source.format !== 'bars-per-watt-chart-v1' ||
      !/^[a-z0-9-]{1,80}$/.test(source.id) || !/^[A-Za-z0-9-]{1,80}$/.test(source.songId) ||
      !['easy', 'medium', 'hard'].includes(source.difficulty) ||
      !/^[a-z0-9-]{1,100}$/.test(source.audioVersion) ||
      !Number.isFinite(source.durationSec) || source.durationSec <= 0 || source.durationSec > 900 ||
      !Number.isFinite(source.offsetSec) || Math.abs(source.offsetSec) > 30 ||
      !Array.isArray(source.bpms) || !source.bpms.length || source.bpms.length > 1000 ||
      !Array.isArray(source.notes) || source.notes.length > 10000)
    throw Error('Invalid chart header');
  const tempos = source.bpms.map((entry, index) => {
    const at = beat(entry.beat);
    if (!Number.isFinite(entry.bpm) || entry.bpm <= 0 || entry.bpm > 400 ||
        (index === 0 ? at !== 0 : at <= beat(source.bpms[index - 1].beat)))
      throw Error('Invalid BPM segment ' + (index + 1));
    return { at, bpm: entry.bpm };
  });
  const timeAt = (at: number) => {
    let seconds = source.offsetSec;
    for (let index = 0; index < tempos.length; index++) {
      const next = tempos[index + 1]?.at ?? at;
      if (at <= tempos[index].at) break;
      seconds += (Math.min(at, next) - tempos[index].at) * 60 / tempos[index].bpm;
      if (at < next) break;
    }
    return seconds;
  };
  const notes = source.notes.map((entry, index): Note => {
    if (![0, 1, 2, 3].includes(entry.lane)) throw Error('Invalid lane at note ' + (index + 1));
    const time = timeAt(beat(entry.beat));
    const endTime = entry.endBeat === undefined ? undefined : timeAt(beat(entry.endBeat));
    if (time < 0 || time >= source.durationSec ||
        (endTime !== undefined && (endTime <= time || endTime > source.durationSec)))
      throw Error('Invalid timing at note ' + (index + 1));
    return { lane: entry.lane, time, ...(endTime === undefined ? {} : { endTime }) };
  }).sort((a, b) => a.time - b.time || a.lane - b.lane);
  const lastTime = [-Infinity, -Infinity, -Infinity, -Infinity];
  const holdUntil = [-Infinity, -Infinity, -Infinity, -Infinity];
  for (const note of notes) {
    if (note.time - lastTime[note.lane] < 0.001) throw Error('Duplicate note in one lane');
    if (note.time < holdUntil[note.lane]) throw Error('Overlapping hold in one lane');
    lastTime[note.lane] = note.time;
    holdUntil[note.lane] = note.endTime ?? -Infinity;
  }
  return { id: source.id, songId: source.songId, difficulty: source.difficulty,
    audioVersion: source.audioVersion, durationSec: source.durationSec, notes };
}
