import { defineArcade } from '../../../core/src/engine';
import type { GameAPI } from '../../../core/src/engine';
import type { CartridgeProfile } from '../../../core/src/cartridge';
import { ParadiseDay, CAMERA_LABELS, type CameraZone } from './model';
import { drawYard } from './render';
import css from './cabinet.css';
import markup from './cabinet.html';

const profile: CartridgeProfile = {
  version: '0.1.0-par1',
  shell: '<style>' + css + '</style>' + markup,
  landscape: [960, 540],
  portrait: [390, 690],
  primary: 'confirm',
  keys: {
    '1': 'live', '2': 'offline',
    c: 'camera-coop', g: 'camera-garden', p: 'camera-porch',
    Enter: 'confirm', ' ': 'confirm',
    f: 'feed', r: 'repair', t: 'rest', s: 'stream',
    y: 'use-tip', n: 'hide-message',
    a: 'accept-sponsor', d: 'decline-sponsor', e: 'finish-day'
  },
  padButtons: { 0: 'confirm', 1: 'offline', 2: 'live', 3: 'feed', 4: 'repair', 5: 'rest', 8: 'finish-day' },
  resultStats: {
    homestead: 'stat_homestead',
    energy: 'stat_energy',
    boundaries: 'stat_boundaries',
    supplies: 'stat_supplies',
    actions: 'stat_actions'
  },
  cues: {}
};

const strings = {
  title: 'PARADISE OFFLINE // PAR-1',
  subtitle: 'One day. Three work slots. Your home, your call.',
  paused: 'DAY PAUSED',
  pause_hint: 'Resume when you are ready.',
  gameover_title: 'DAY ONE COMPLETE',
  gameover_any: 'Your local day report is ready.',
  hud_score: 'HOUSEHOLD',
  best: 'LOCAL BEST',
  retry: 'PLAY ANOTHER DAY',
  play: 'START DAY',
  resume: 'RESUME',
  share: 'SHARE REPORT',
  sound_on: 'SOUND ON',
  sound_off: 'SOUND OFF',
  stat_homestead: 'Homestead',
  stat_energy: 'Energy',
  stat_boundaries: 'Boundaries',
  stat_supplies: 'Resources',
  stat_actions: 'Work slots used'
};

function labelFor(zone: CameraZone) {
  return CAMERA_LABELS[zone];
}

defineArcade('paradise-offline-par1', 'PARADISE OFFLINE // PAR-1', (emit, host): GameAPI => {
  const root = host.shadowRoot!;
  const seedValue = Number(host.getAttribute('seed') ?? 1);
  const seed = Number.isFinite(seedValue) ? seedValue | 0 : 1;
  const reduced = host.getAttribute('reduced-motion') === 'on' ||
    (host.getAttribute('reduced-motion') !== 'off' && matchMedia('(prefers-reduced-motion: reduce)').matches);
  const day = new ParadiseDay(seed, reduced, emit);

  function syncControls() {
    root.querySelectorAll<HTMLElement>('[data-step]').forEach(group => {
      group.hidden = group.dataset.step !== day.stage;
    });
    root.querySelectorAll<HTMLButtonElement>('[data-live-only]').forEach(button => {
      button.hidden = day.schedule !== 'live';
    });
    root.querySelectorAll<HTMLButtonElement>('[data-zone]').forEach(button => {
      const zone = button.dataset.zone as CameraZone;
      const active = day.cameras[zone];
      button.textContent = labelFor(zone) + (active ? ' · INCLUDED' : ' · EXCLUDED');
      button.setAttribute('aria-pressed', String(active));
    });
    const stream = root.querySelector<HTMLButtonElement>('[data-stream]');
    if (stream) {
      stream.textContent = day.stream ? 'STOP LIVE' : 'RESUME LIVE';
      stream.setAttribute('aria-pressed', String(day.stream));
    }
    const notice = root.querySelector<HTMLElement>('[data-notice]');
    if (notice) notice.textContent = day.notice;
    const values: Record<string, string> = {
      home: String(day.home), coop: String(day.coop), energy: String(day.energy),
      boundaries: String(day.boundaries), cash: '$' + day.cash,
      boards: String(day.boards), feed: String(day.feed),
      slots: String(Math.max(0, 3 - day.slotsUsed))
    };
    for (const [key, value] of Object.entries(values)) {
      const node = root.querySelector<HTMLElement>('[data-meter="' + key + '"]');
      if (node) node.textContent = value;
    }
    for (const job of ['feed', 'repair', 'rest'] as const) {
      const button = root.querySelector<HTMLButtonElement>('[data-key="' + job + '"]');
      if (button) button.disabled = !day.canJob(job);
    }
  }

  function draw(ctx: CanvasRenderingContext2D, width: number, height: number) {
    ctx.fillStyle = '#17151e';
    ctx.fillRect(0, 0, width, height);
    const scale = Math.min(width / 640, height / 360);
    const offsetX = (width - 640 * scale) / 2;
    const offsetY = (height - 360 * scale) / 2;
    ctx.save();
    ctx.translate(offsetX, offsetY);
    ctx.scale(scale, scale);
    drawYard(ctx, 640, 360, day);
    ctx.restore();
  }

  return {
    start() {
      day.reset(seed);
      syncControls();
    },
    update(dt: number) {
      day.update(dt);
      syncControls();
    },
    draw,
    input(key: string, down: boolean) {
      if (!down) return;
      day.handleInput(key);
      syncControls();
    },
    score() { return day.score(); },
    over() { return day.over(); },
    result() { return day.result(); },
    presentation() {
      return { id: 'placeholder', strings, sfx: {}, volume: 0 };
    },
    setMuted() {},
    setSkin() {},
    dispose() {}
  };
}, profile);
