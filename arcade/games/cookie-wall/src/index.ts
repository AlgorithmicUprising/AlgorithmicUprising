import { readLocal, writeLocal } from '../../../core/src/storage';
import { defineArcade, type GameAPI } from '../../../core/src/engine';
import type { CartridgeProfile } from '../../../core/src/cartridge';
import { brickRules } from './board';
import { CookieWallGame } from './game';
import { drawCourt, highContrast } from './render';
import { SkinBank } from './skin';
import css from './cabinet.css';
import markup from './cabinet.html';

const profile: CartridgeProfile = {
  version: '0.1.0', shell: '<style>' + css + '</style>' + markup,
  landscape: [640, 360], portrait: [360, 640], primary: 'launch',
  keys: { ArrowLeft: 'left', a: 'left', ArrowRight: 'right', d: 'right',
    ' ': 'launch', u: 'launch', ArrowUp: 'launch', Escape: 'pause', p: 'pause', m: 'mute' },
  padButtons: { 0: 'launch', 9: 'pause', 14: 'left', 15: 'right' },
  resultStats: { wallsCleared: 'walls_cleared' },
  cues: { 'game:launch': 'launch', 'game:paddle': 'paddle', 'game:brick': 'brick',
    'game:crack': 'crack', 'game:wall-clear': 'wall_clear', 'game:leak': 'leak' }
};

defineArcade('cookie-wall', 'COOKIE WALL', (emit, host) => {
  const root = host.shadowRoot!;
  const element = host as HTMLElement & { state: string; pause(reason: string): void; resume(reason: string): void };
  const seed = () => {
    const value = Number(host.getAttribute('seed') ?? 1);
    return Number.isFinite(value) ? value | 0 : 1;
  };
  const world = new CookieWallGame(seed(), emit);
  const settingsKey = () => (host.getAttribute('storage-key') || 'au-arcade') + ':v1:cookie-wall:settings';
  const preferences = { motion: 'auto', contrast: false, left: false, volume: .6 };
  const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const signal = new AbortController();
  const bank = new SkinBank(applySkin, emit);
  const dialog = root.querySelector<HTMLDialogElement>('dialog')!;
  const form = dialog.querySelector('form')!;
  const motion = form.elements.namedItem('motion') as HTMLSelectElement;
  const contrast = form.elements.namedItem('contrast') as HTMLInputElement;
  const left = form.elements.namedItem('left') as HTMLInputElement;
  const volume = form.elements.namedItem('volume') as HTMLInputElement;
  const status = root.querySelector<HTMLElement>('[data-status]')!;
  const strip = root.querySelector<HTMLElement>('[data-position-strip]')!;
  const counters = ['score', 'lives', 'wall'].map(key => root.querySelector<HTMLElement>('[data-value=' + key + ']')!);
  let reduce = false, previousPaddle = NaN, resumeAfterSettings = false;
  const setText = (node: HTMLElement, text: string) => { if (node.textContent !== text) node.textContent = text; };
  function readPreferences() {
    Object.assign(preferences, { motion: 'auto', contrast: false, left: false, volume: .6 });
    try {
      const saved = JSON.parse(readLocal(settingsKey()) || '{}');
      if (['auto', 'on', 'off'].includes(saved.motion)) preferences.motion = saved.motion;
      preferences.contrast = saved.contrast === true; preferences.left = saved.left === true;
      if (Number.isFinite(saved.volume)) preferences.volume = Math.max(0, Math.min(1, saved.volume));
    } catch {}
  }
  function applyPreferences() {
    const setting = host.getAttribute('reduced-motion') || preferences.motion;
    reduce = setting === 'on' || (setting === 'auto' && systemMotion.matches);
    host.toggleAttribute('data-left-handed', preferences.left);
    const palette = preferences.contrast ? highContrast : bank.current.palette;
    for (const [key, color] of Object.entries(palette)) host.style.setProperty('--cw-' + key, color);
    motion.value = setting; contrast.checked = preferences.contrast; left.checked = preferences.left;
    volume.value = String(preferences.volume * 100);
  }
  function applySkin() {
    const { strings } = bank.current;
    root.querySelectorAll<HTMLElement>('[data-copy]').forEach(node => setText(node, strings[node.dataset.copy!] || ''));
    const legend = root.querySelector('[data-legend]')!;
    legend.replaceChildren(); legend.setAttribute('aria-label', strings.legend);
    for (const [kind, rule] of Object.entries(brickRules)) {
      const term = document.createElement('dt'), value = document.createElement('dd');
      term.textContent = strings['brick_' + kind]; value.textContent = rule.hits + ' ×  /  ' + rule.points;
      legend.append(term, value);
    }
    applyPreferences();
  }
  readPreferences(); applySkin();
  const redraw = () => {
    const canvas = root.querySelector('canvas')!, ctx = canvas.getContext('2d');
    if (ctx) draw(ctx, canvas.width, canvas.height);
  };
  const settingsButton = root.querySelector<HTMLButtonElement>('[part=settings]')!;
  settingsButton.addEventListener('click', () => {
    resumeAfterSettings = element.state === 'playing';
    if (resumeAfterSettings) element.pause('settings');
    if (!dialog.open) dialog.showModal();
  }, { signal: signal.signal });
  form.addEventListener('change', () => {
    preferences.motion = motion.value; preferences.contrast = contrast.checked; preferences.left = left.checked;
    preferences.volume = Number(volume.value) / 100;
    if (host.hasAttribute('reduced-motion')) host.setAttribute('reduced-motion', motion.value);
    writeLocal(settingsKey(), JSON.stringify(preferences));
    applyPreferences(); redraw();
  }, { signal: signal.signal });
  // Closing settings leaves an explicit Resume button after a run was paused.
  dialog.addEventListener('close', () => {
    if (resumeAfterSettings) root.querySelector<HTMLButtonElement>('[part=resume]')?.focus({ preventScroll: true });
    resumeAfterSettings = false;
  }, { signal: signal.signal });
  systemMotion.addEventListener('change', () => { applyPreferences(); redraw(); }, { signal: signal.signal });
  const observer = new MutationObserver(changes => {
    if (changes.some(c => c.attributeName === 'storage-key')) readPreferences();
    applyPreferences(); redraw();
  });
  observer.observe(host, { attributes: true, attributeFilter: ['storage-key', 'reduced-motion'] });
  function draw(ctx: CanvasRenderingContext2D, w: number, h: number) {
    const skin = bank.current, words = skin.strings;
    drawCourt(ctx, w, h, world, skin, reduce, preferences.contrast);
    setText(counters[0], String(world.score)); setText(counters[1], String(world.lives)); setText(counters[2], String(world.wall));
    const note = element.state === 'title' ? 'start' : world.phase === 'wall-clear' ? 'wall_clear' : world.phase === 'flight' ? 'flight_hint' :
      world.phase === 'leaking' || world.phase === 'over' ? 'leaking' :
      world.dockedAfterLoss ? 'relaunch' :
      (['wall_one', 'wall_two', 'wall_three'][world.wall - 1] || 'wall_later');
    setText(status, words[note]);
    if (previousPaddle !== world.paddleX) { strip.style.setProperty('--paddle', world.paddleX / 3.2 + '%'); previousPaddle = world.paddleX; }
  }
  return {
    world,
    start: () => world.reset(seed()), update: dt => world.update(dt), draw,
    input: (action, down) => world.input(action, down), setMoveAxis: x => world.moveAxis(x),
    setPositionTarget: position => world.setTarget(position), releaseInput: () => world.releaseInput(),
    score: () => world.score, over: () => world.phase === 'over',
    result: () => ({ cause: 'leak', stats: { ...world.stats }, causeLine: bank.current.strings.gameover_leak,
      shareText: bank.current.strings.share_text.replaceAll('{score}', String(world.score)) }),
    setSkin: url => bank.load(url),
    presentation: () => ({ ...bank.current, volume: preferences.volume }),
    dispose: () => { signal.abort(); observer.disconnect(); bank.dispose(); }
  } satisfies GameAPI & { world: CookieWallGame };
}, profile);
