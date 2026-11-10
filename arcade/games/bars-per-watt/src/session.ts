import type { Chart, Lane, Note } from './chart';

export type Judgement = 'perfect' | 'good' | 'miss';
type NoteState = 'pending' | 'holding' | 'done' | 'missed';
export interface SessionNote { note: Note; state: NoteState }
export const WINDOWS = { perfect: 0.05, good: 0.12, holdRelease: 0.15 } as const;

export class RhythmSession {
  readonly notes: SessionNote[];
  score = 0; combo = 0; maxCombo = 0;
  totals = { perfect: 0, good: 0, miss: 0, holds: 0 };
  latest: Judgement | null = null;
  latestAt = 0;
  complete = false;
  private pendingCursor = 0;
  private holding = new Set<SessionNote>();
  private maximum: number;
  constructor(readonly chart: Chart) {
    this.notes = chart.notes.map(note => ({ note, state: 'pending' }));
    this.maximum = chart.notes.reduce((sum, note) => sum + 1000 +
      (note.endTime === undefined ? 0 : 500), 0);
  }
  get accuracy() {
    return this.maximum ? Math.round(this.score / this.maximum * 10000) / 100 : 0;
  }
  private judge(kind: Judgement, at: number) {
    this.totals[kind]++;
    this.latest = kind; this.latestAt = at;
    if (kind === 'miss') this.combo = 0;
    else {
      this.combo++; this.maxCombo = Math.max(this.maxCombo, this.combo);
      this.score += kind === 'perfect' ? 1000 : 500;
    }
  }
  advance(at: number) {
    if (this.complete) return;
    while (this.pendingCursor < this.notes.length) {
      const item = this.notes[this.pendingCursor];
      if (item.state !== 'pending') { this.pendingCursor++; continue; }
      if (at <= item.note.time + WINDOWS.good) break;
      item.state = 'missed'; this.judge('miss', at); this.pendingCursor++;
    }
    for (const item of this.holding) {
      if (item.note.endTime !== undefined && at > item.note.endTime + WINDOWS.holdRelease) {
        item.state = 'missed'; this.judge('miss', at); this.holding.delete(item);
      }
    }
    if (at >= this.chart.durationSec) this.finish();
  }
  input(lane: Lane, down: boolean, at: number) {
    if (this.complete || !Number.isFinite(at)) return;
    this.advance(at);
    if (down) {
      const item = this.notes.find(n => n.note.lane === lane && n.state === 'pending' &&
        Math.abs(at - n.note.time) <= WINDOWS.good);
      if (!item) return;
      const kind = Math.abs(at - item.note.time) <= WINDOWS.perfect ? 'perfect' : 'good';
      item.state = item.note.endTime === undefined ? 'done' : 'holding';
      if (item.state === 'holding') this.holding.add(item);
      this.judge(kind, at);
    } else {
      const item = this.notes.find(n => n.note.lane === lane && n.state === 'holding');
      if (!item || item.note.endTime === undefined) return;
      if (Math.abs(at - item.note.endTime) <= WINDOWS.holdRelease) {
        item.state = 'done'; this.holding.delete(item); this.score += 500; this.totals.holds++;
      } else if (at < item.note.endTime - WINDOWS.holdRelease) {
        item.state = 'missed'; this.holding.delete(item); this.judge('miss', at);
      }
    }
  }
  finish() {
    if (this.complete) return;
    for (const item of this.notes)
      if (item.state === 'pending' || item.state === 'holding') {
        item.state = 'missed'; this.judge('miss', this.chart.durationSec);
      }
    this.holding.clear();
    this.complete = true;
  }
}
