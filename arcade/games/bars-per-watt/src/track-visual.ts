/** Decorative media follows the run state without participating in its clock. */
export class TrackVisual {
  private readonly still: HTMLImageElement;
  private readonly video: HTMLVideoElement;
  private clip: URL | null = null;
  private wantsPlayback = false;
  private playAttempt = 0;

  constructor(private panel: HTMLElement, signal: AbortSignal) {
    this.still = panel.querySelector('img')!;
    this.video = panel.querySelector('video')!;
    this.still.addEventListener('error', () => {
      this.still.hidden = true;
      this.panel.hidden = !this.video.hasAttribute('data-visible');
    }, { signal });
    this.video.addEventListener('playing', () => {
      if (!this.wantsPlayback) return;
      this.video.setAttribute('data-visible', '');
      this.panel.hidden = false;
    }, { signal });
    this.video.addEventListener('error', () => {
      if (this.video.error && this.video.hasAttribute('src')) this.fallback();
    }, { signal });
  }

  setTrack(sleeve: URL | null = null, clip: URL | null = null) {
    this.stop();
    this.clip = clip;
    this.still.hidden = !sleeve;
    this.panel.hidden = !sleeve;
    if (sleeve) this.still.src = sleeve.href;
    else this.still.removeAttribute('src');
  }

  sync(enabled: boolean, playing: boolean) {
    if (!this.clip) return;
    if (!enabled) {
      this.stop();
      return;
    }
    if (!playing) {
      this.pause();
      return;
    }
    if (this.wantsPlayback) return;

    this.wantsPlayback = true;
    const attempt = ++this.playAttempt;
    if (!this.video.hasAttribute('src')) {
      if (this.clip.origin === location.origin) this.video.removeAttribute('crossorigin');
      else this.video.crossOrigin = 'anonymous';
      this.video.src = this.clip.href;
    }
    this.video.muted = true;
    void this.video.play().catch(() => {
      if (this.playAttempt === attempt && this.wantsPlayback) this.fallback();
    });
  }

  pause() {
    if (!this.wantsPlayback) return;
    this.wantsPlayback = false;
    ++this.playAttempt;
    this.video.pause();
  }

  stop() {
    this.pause();
    if (!this.video.hasAttribute('src')) return;
    this.video.removeAttribute('data-visible');
    this.video.removeAttribute('src');
    this.video.load();
    this.panel.hidden = this.still.hidden;
  }

  private fallback() {
    this.clip = null;
    this.stop();
  }
}
