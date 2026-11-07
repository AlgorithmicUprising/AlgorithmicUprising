/** Optional presentation contract for cartridges using the arcade element and its existing game loop. */
export type Phase = 'title' | 'playing' | 'paused' | 'over';
export type Texts = Record<string, string>;
export type Presentation = { id: string; strings: Texts; sfx: Record<string, readonly number[]>; volume: number };
export interface CartridgeProfile {
  version: string;
  shell: string;
  keys: Record<string, string>;
  primary: string;
  padButtons: Record<number, string>;
  landscape: readonly [number, number];
  portrait: readonly [number, number];
  resultStats: Record<string, string>;
  cues: Record<string, string>;
}

export function fitViewport(host: HTMLElement, root: ShadowRoot, profile: CartridgeProfile) {
  const preference = host.getAttribute('orientation') ?? host.getAttribute('layout');
  const width = host.clientWidth, height = host.clientHeight;
  const portrait = preference === 'portrait' || (preference !== 'landscape' && width < height);
  host.dataset.orientation = portrait ? 'portrait' : 'landscape';
  const [w, h] = portrait ? profile.portrait : profile.landscape;
  const scale = Math.min(width / w, height / h);
  const view = root.querySelector<HTMLElement>('[part=viewport]')!;
  view.style.width = w * scale + 'px';
  view.style.height = h * scale + 'px';
}

export function showPanel(root: ShadowRoot, phase: Phase, strings: Texts, score: number, best: number,
  result: Record<string, unknown>, statLabels: Record<string, string>) {
  const panel = root.querySelector<HTMLElement>('.overlay')!;
  panel.dataset.phase = phase;
  panel.hidden = phase === 'playing';
  if (panel.hidden) return;
  const summary: string[] = [];
  let heading = strings.title, detail = strings.subtitle;
  if (phase === 'paused') {
    heading = strings.paused; detail = strings.pause_hint;
  } else if (phase === 'over') {
    heading = strings.gameover_title;
    detail = typeof result.causeLine === 'string' ? result.causeLine : strings.gameover_any;
    summary.push(strings.hud_score + ' ' + score, strings.best + ' ' + best);
    const stats = result.stats as Record<string, number> | undefined;
    for (const [key, label] of Object.entries(statLabels)) {
      if (stats && key in stats) summary.push(strings[label] + ' ' + stats[key]);
    }
  }
  panel.querySelector('h2')!.textContent = heading;
  panel.querySelector('[data-detail]')!.textContent = detail;
  const totals = panel.querySelector<HTMLElement>('[data-summary]')!;
  totals.textContent = summary.join('  ·  '); totals.hidden = !summary.length;
  const actions = { start: 'title', resume: 'paused', again: 'over', share: 'over' };
  for (const [action, visible] of Object.entries(actions)) {
    const button = panel.querySelector<HTMLButtonElement>('[part=' + action + ']')!;
    button.hidden = phase !== visible;
    button.textContent = strings[action === 'again' ? 'retry' : action === 'start' ? 'play' : action];
  }
  const fallback = panel.querySelector<HTMLInputElement>('[data-share-fallback]');
  if (fallback) fallback.hidden = true;
}

/** Track one absolute pointer across a court and its remote strip. Buttons remain independently usable. */
export function bindPositionInput(root: ShadowRoot, allowed: () => boolean, focus: () => void,
  target: (fraction: number | null) => void, signal: AbortSignal) {
  let owner: { element: HTMLElement; id: number } | null = null;
  const release = () => {
    const previous = owner; owner = null; target(null);
    if (previous?.element.hasPointerCapture(previous.id)) previous.element.releasePointerCapture(previous.id);
  };
  for (const element of Array.from(root.querySelectorAll<HTMLElement>('canvas,[data-position-strip]'))) {
    const position = (event: PointerEvent) => {
      const rect = element.getBoundingClientRect();
      if (rect.width) target(Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width)));
    };
    element.addEventListener('pointerdown', event => {
      if (owner || !allowed() || event.button !== 0) return;
      event.preventDefault(); focus();
      element.setPointerCapture(event.pointerId);
      owner = { element, id: event.pointerId }; position(event);
    }, { signal });
    element.addEventListener('pointermove', event => {
      if (!allowed()) return;
      if (owner ? owner.element === element && owner.id === event.pointerId : event.pointerType === 'mouse' && element.matches('canvas')) position(event);
    }, { signal });
    for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'] as const) {
      element.addEventListener(type, event => { if (owner?.id === event.pointerId) release(); }, { signal });
    }
    element.addEventListener('contextmenu', event => event.preventDefault(), { signal });
  }
  return release;
}

/** Small, bounded oscillator envelope. The first seven skin parameters use the ZzFX order. */
export function synthesize(context: AudioContext, parameters: readonly number[], volume: number) {
  const [gain = 0.5, , pitch = 440, attack = 0, sustain = 0.02, release = 0.08, shape = 0] = parameters;
  const time = context.currentTime;
  const rise = Math.max(0.003, Math.min(0.3, attack)), hold = Math.max(0, Math.min(0.3, sustain));
  const end = time + rise + hold + Math.max(0.012, Math.min(0.4, release));
  const oscillator = context.createOscillator(), envelope = context.createGain();
  oscillator.type = (['sine', 'triangle', 'sawtooth', 'square'] as OscillatorType[])[Math.round(shape) % 4] ?? 'sine';
  oscillator.frequency.value = Math.max(45, Math.min(3000, pitch));
  const level = Math.max(0.0002, Math.min(1, gain) * Math.max(0, Math.min(1, volume)) * 0.09);
  envelope.gain.setValueAtTime(0.0001, time); envelope.gain.linearRampToValueAtTime(level, time + rise);
  envelope.gain.setValueAtTime(level, time + rise + hold); envelope.gain.exponentialRampToValueAtTime(0.0001, end);
  oscillator.connect(envelope); envelope.connect(context.destination);
  oscillator.onended = () => { oscillator.disconnect(); envelope.disconnect(); };
  oscillator.start(time); oscillator.stop(end);
}
