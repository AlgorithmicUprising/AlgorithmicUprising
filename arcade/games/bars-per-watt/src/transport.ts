/** One native compressed-media stream owns the song clock. No RAF delta enters timing. */
export class MediaTransport {
  private audio = new Audio();
  private generation = 0;
  private disposed = false;
  private stalled = false;
  onEnd: (() => void) | null = null;
  onState: (() => void) | null = null;
  constructor() {
    this.audio.preload = 'auto';
    this.audio.crossOrigin = 'anonymous';
    this.audio.addEventListener('ended', () => this.onEnd?.());
    for (const event of ['waiting', 'stalled', 'seeking', 'pause']) {
      this.audio.addEventListener(event, () => { this.stalled = true; this.onState?.(); });
    }
    for (const event of ['playing', 'canplay', 'seeked']) {
      this.audio.addEventListener(event, () => { this.stalled = false; this.onState?.(); });
    }
  }
  get time() { return this.audio.currentTime || 0; }
  get duration() { return this.audio.duration || 0; }
  get playing() { return !this.disposed && !this.audio.paused && !this.audio.seeking &&
    !this.stalled && this.audio.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA; }
  setMuted(muted: boolean) { this.audio.muted = muted; }
  async load(url: URL, signal?: AbortSignal) {
    this.unload();
    const generation = ++this.generation;
    this.stalled = true; this.audio.src = url.href; this.audio.load();
    try {
      await new Promise<void>((resolve, reject) => {
        const timeout = window.setTimeout(() => reject(Error('Audio load timed out')), 30000);
        const cleanup = () => {
          clearTimeout(timeout);
          this.audio.removeEventListener('canplay', ready);
          this.audio.removeEventListener('error', failure);
          signal?.removeEventListener('abort', aborted);
        };
        const ready = () => { cleanup(); resolve(); };
        const failure = () => { cleanup(); reject(Error('Audio could not load')); };
        const aborted = () => { cleanup(); reject(Error('Audio load canceled')); };
        this.audio.addEventListener('canplay', ready, { once: true });
        this.audio.addEventListener('error', failure, { once: true });
        signal?.addEventListener('abort', aborted, { once: true });
        if (signal?.aborted) aborted();
        else if (this.audio.readyState >= HTMLMediaElement.HAVE_FUTURE_DATA) ready();
      });
      if (this.disposed || generation !== this.generation) throw Error('Audio load superseded');
      this.stalled = false;
    } catch (error) {
      if (generation === this.generation) this.reset();
      throw error;
    }
  }
  async play(fromStart = false) {
    if (this.disposed) return;
    if (fromStart) this.audio.currentTime = 0;
    this.stalled = false;
    await this.audio.play();
  }
  pause() { this.audio.pause(); }
  reset() {
    this.audio.pause();
    if (this.audio.readyState) this.audio.currentTime = 0;
  }
  unload() {
    ++this.generation;
    this.audio.pause(); this.audio.removeAttribute('src'); this.audio.load();
    this.stalled = true;
  }
  /** Map event time to the current media position. Device/output calibration is applied by the caller. */
  atEvent(timestamp: number) {
    const now = performance.now();
    const normalized = timestamp > performance.timeOrigin ? timestamp - performance.timeOrigin : timestamp;
    return Math.max(0, this.time + Math.max(-0.25, Math.min(0.25, (normalized - now) / 1000)));
  }
  dispose() {
    this.disposed = true; this.onEnd = null; this.onState = null; this.unload();
  }
}
