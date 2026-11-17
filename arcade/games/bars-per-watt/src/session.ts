import type { Chart, Lane, Note } from './chart';

export type Judgement = 'perfect' | 'good' | 'ok' | 'miss';
type NoteState = 'pending' | 'holding' | 'done' | 'missed';
export interface SessionNote { note: Note; state: NoteState }
export interface HitFeedback { kind: Judgement | 'hold'; lane: Lane; at: number; errorSec?: number }
export const WINDOWS = { perfect: 0.05, good: 0.09, ok: 0.12 } as const;
export const PRECISION_THRESHOLD = 5;
export const SCORE_VERSION = 'timing-v2';
export const BATTERY_MAX = 100;
export const BATTERY_MISS_DRAIN = 10;
export const BATTERY_STREAK_SIZE = 5;
export const BATTERY_STREAK_CHARGE = 5;
// Inclusive boundaries must survive subtracting timestamps deep into a song.
const EPSILON = 1e-9;
const isMilestone = (count: number) => count === 10 || count === 25 || (count > 0 && count % 50 === 0);

export class RhythmSession {
  readonly notes: SessionNote[];
  score = 0; combo = 0; maxCombo = 0;
  battery = BATTERY_MAX; failed = false;
  precision = 0; maxPrecision = 0;
  totals = { perfect: 0, good: 0, ok: 0, miss: 0, holds: 0 };
  latest: Judgement | 'hold' | null = null;
  latestAt = 0;
  latestFeedback: HitFeedback | null = null;
  readonly laneFeedback: (HitFeedback | null)[] = [null, null, null, null];
  milestone: { id: number; kind: 'combo' | 'precision'; count: number; at: number } | null = null;
  readonly pressed = new Set<Lane>();
  complete = false;
  private pendingCursor = 0;
  private holding = new Set<SessionNote>();
  private maximum: number;
  private milestoneId = 0;
  constructor(readonly chart: Chart) {
    this.notes = chart.notes.map(note => ({ note, state: 'pending' }));
    this.maximum = chart.notes.reduce((sum, note) => sum + 1000 +
      (note.endTime === undefined ? 0 : 500), 0);
  }
  get accuracy() {
    return this.maximum ? Math.round(this.score / this.maximum * 10000) / 100 : 0;
  }
  get activeHolds(): readonly Note[] { return Array.from(this.holding, item => item.note); }
  get overclocked() { return this.precision >= PRECISION_THRESHOLD; }
  clearPressed() { this.pressed.clear(); }
  private feedback(kind: HitFeedback['kind'], lane: Lane, at: number, errorSec?: number) {
    this.latest = kind; this.latestAt = at;
    this.latestFeedback = { kind, lane, at, errorSec };
    this.laneFeedback[lane] = this.latestFeedback;
  }
  private judge(kind: Judgement, lane: Lane, at: number, errorSec?: number) {
    this.totals[kind]++;
    this.feedback(kind, lane, at, errorSec);
    this.precision = kind === 'perfect' ? this.precision + 1 : 0;
    this.maxPrecision = Math.max(this.maxPrecision, this.precision);
    if (kind === 'miss') {
      this.combo = 0; this.milestone = null;
      this.battery = Math.max(0, this.battery - BATTERY_MISS_DRAIN);
      if (this.battery === 0) {
        this.failed = true; this.complete = true;
        this.holding.clear(); this.pressed.clear();
      }
    } else {
      this.combo++; this.maxCombo = Math.max(this.maxCombo, this.combo);
      if (this.combo % BATTERY_STREAK_SIZE === 0)
        this.battery = Math.min(BATTERY_MAX, this.battery + BATTERY_STREAK_CHARGE);
      this.score += kind === 'perfect' ? 1000 : kind === 'good' ? 750 : 500;
      if (this.precision === PRECISION_THRESHOLD || isMilestone(this.precision))
        this.milestone = { id: ++this.milestoneId, kind: 'precision', count: this.precision, at };
      else if (isMilestone(this.combo))
        this.milestone = { id: ++this.milestoneId, kind: 'combo', count: this.combo, at };
      else if (!this.overclocked && this.milestone?.kind === 'precision') this.milestone = null;
    }
  }
  advance(at: number) {
    if (this.complete) return;
    while (this.pendingCursor < this.notes.length) {
      const item = this.notes[this.pendingCursor];
      if (item.state !== 'pending') { this.pendingCursor++; continue; }
      if (at <= item.note.time + WINDOWS.ok + EPSILON) break;
      item.state = 'missed'; this.judge('miss', item.note.lane, at); this.pendingCursor++;
      if (this.complete) return;
    }
    for (const item of this.holding) {
      if (item.note.endTime !== undefined && at >= item.note.endTime - EPSILON) {
        if (this.pressed.has(item.note.lane)) {
          item.state = 'done'; this.holding.delete(item);
          this.score += 500; this.totals.holds++;
          this.feedback('hold', item.note.lane, item.note.endTime);
        } else {
          item.state = 'missed'; this.holding.delete(item);
          this.judge('miss', item.note.lane, at);
          if (this.complete) return;
        }
      }
    }
    if (at >= this.chart.durationSec) this.finish();
  }
  input(lane: Lane, down: boolean, at: number, feedbackAt = at) {
    if (this.complete || !Number.isFinite(at)) return;
    if (down) this.pressed.add(lane);
    this.advance(at);
    if (this.complete) { this.pressed.delete(lane); return; }
    if (!down) this.pressed.delete(lane);
    if (down) {
      const item = this.notes.find(n => n.note.lane === lane && n.state === 'pending' &&
        Math.abs(at - n.note.time) <= WINDOWS.ok + EPSILON);
      if (!item) return;
      const error = at - item.note.time, distance = Math.abs(error);
      const kind = distance <= WINDOWS.perfect + EPSILON ? 'perfect' :
        distance <= WINDOWS.good + EPSILON ? 'good' : 'ok';
      item.state = item.note.endTime === undefined ? 'done' : 'holding';
      if (item.state === 'holding') this.holding.add(item);
      this.judge(kind, lane, feedbackAt, error);
    } else {
      const item = this.notes.find(n => n.note.lane === lane && n.state === 'holding');
      if (!item || item.note.endTime === undefined) return;
      if (at < item.note.endTime - EPSILON) {
        item.state = 'missed'; this.holding.delete(item); this.judge('miss', lane, feedbackAt);
      }
    }
  }
  finish() {
    if (this.complete) return;
    for (const item of this.notes) {
      if (this.complete) break;
      if (item.state === 'pending' || item.state === 'holding') {
        item.state = 'missed'; this.judge('miss', item.note.lane, this.chart.durationSec);
      }
    }
    this.holding.clear(); this.pressed.clear(); this.complete = true;
  }
}
