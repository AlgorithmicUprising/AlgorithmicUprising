import { defineArcade } from '../../../core/src/engine';
import type { GameAPI } from '../../../core/src/engine';
import type { CartridgeProfile } from '../../../core/src/cartridge';
import { ParadiseDay, CAMERA_LABELS, type CameraZone, type Job } from './model';
import { drawYard } from './render';
import css from './cabinet.css';
import markup from './cabinet.html';

const profile: CartridgeProfile = {
  version: '0.2.0-par2',
  shell: '<style>' + css + '</style>' + markup,
  landscape: [960, 540],
  portrait: [390, 740],
  primary: 'ui-confirm',
  keys: {
    '1': 'ranked', '2': 'practice', '4': 'cadence-recovery', '5': 'edit',
    l: 'live', e: 'edited', o: 'offline',
    c: 'camera-coop', g: 'camera-garden', w: 'camera-well',
    p: 'camera-porch', b: 'camera-workbench', i: 'camera-private',
    Enter: 'ui-confirm', ' ': 'ui-confirm',
    ArrowUp: 'ui-prev', ArrowLeft: 'ui-prev', ArrowDown: 'ui-next', ArrowRight: 'ui-next', Escape: 'pause',
    f: 'feed', r: 'repair', t: 'tend-garden', u: 'draw-water',
    k: 'cook', m: 'moderate', z: 'rest', x: 'finish-day',
    s: 'stream', y: 'use-tip', n: 'hide-message',
    j: 'tomato-keep', v: 'tomato-reframe', h: 'tomato-hide',
    q: 'tomato-stop', a: 'storm-sponsor', d: 'storm-decline',
    '7': 'storm-community', '8': 'cadence-always',
    '9': 'cadence-offline', '0': 'cadence-shared'
  },
  padButtons: { 0: 'ui-confirm', 1: 'confirm', 9: 'pause', 12: 'ui-prev', 13: 'ui-next', 14: 'ui-prev', 15: 'ui-next' },
  padAxes: [{ index: 0, negative: 'ui-prev', positive: 'ui-next', deadzone: 0.6 }],
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
  title: 'PARADISE OFFLINE · FIVE DAYS',
  subtitle: 'Run the homestead. Choose what life stays in frame.',
  paused: 'DAY PAUSED',
  pause_hint: 'Resume when you are ready.',
  gameover_title: 'WEEK COMPLETE',
  gameover_any: 'Your local five-day report is ready.',
  hud_score: 'HOUSEHOLD',
  best: 'LOCAL BEST',
  retry: 'START ANOTHER WEEK',
  play: 'START',
  resume: 'RESUME',
  share: 'SHARE REPORT',
  sound_on: 'SOUND ON',
  sound_off: 'SOUND OFF',
  stat_homestead: 'Homestead',
  stat_energy: 'Energy',
  stat_boundaries: 'Boundaries',
  stat_supplies: 'Resources',
  stat_actions: 'Work slots'
};

const jobOrder: readonly Job[] = ['feed', 'repair', 'tend-garden', 'draw-water', 'cook', 'edit', 'moderate', 'rest'];

function labelFor(zone: CameraZone) { return CAMERA_LABELS[zone]; }

defineArcade('paradise-offline-par1', 'PARADISE OFFLINE · FIVE DAYS', (emit, host): GameAPI => {
  const root = host.shadowRoot!;
  const seedValue = Number(host.getAttribute('seed') ?? 420521);
  const seed = Number.isFinite(seedValue) ? seedValue | 0 : 420521;
  const reduced = host.getAttribute('reduced-motion') === 'on' ||
    (host.getAttribute('reduced-motion') !== 'off' && matchMedia('(prefers-reduced-motion: reduce)').matches);
  const day = new ParadiseDay(seed, reduced, emit);
  root.querySelectorAll<HTMLButtonElement>('.controls button[data-key]').forEach(button => {
    button.addEventListener('click', () => { day.handleInput(button.dataset.key || ''); syncControls(); });
  });

  function uiStep() {
    if (day.stage !== 'tomato') return day.stage;
    if (day.schedule === 'live' && day.stream && day.cameras.garden) return 'tomato-live';
    if (day.schedule === 'edited') return 'tomato-edited';
    return 'tomato-private';
  }

  function syncControls() {
    const step = uiStep();
    root.querySelectorAll<HTMLElement>('[data-step]').forEach(group => { group.hidden = group.dataset.step !== step; });

    root.querySelectorAll<HTMLButtonElement>('[data-zone]').forEach(button => {
      const zone = button.dataset.zone as CameraZone;
      const active = day.cameras[zone];
      const label = labelFor(zone) + (active ? ' · INCLUDED' : ' · EXCLUDED');
      button.textContent = label;
      button.setAttribute('aria-pressed', String(active));
      button.disabled = !active && day.cameraCount() >= 3;
    });
    const privateWarning = root.querySelector<HTMLElement>('[data-private-warning]');
    if (privateWarning) privateWarning.hidden = !day.cameras['private-room'];

    const stream = root.querySelector<HTMLButtonElement>('[data-stream]');
    if (stream) {
      stream.textContent = day.stream ? 'STOP LIVE' : 'RESUME LIVE';
      stream.setAttribute('aria-pressed', String(day.stream));
    }
    root.querySelectorAll<HTMLElement>('[data-schedule-name]').forEach(node => { node.textContent = (day.schedule || 'offline').toUpperCase(); });
    const messageCopy = root.querySelector<HTMLElement>('[data-message-copy]');
    if (messageCopy) messageCopy.textContent = day.schedule === 'offline'
      ? 'A fictional neighbor leaves the same practical tip. It is a paper note, not chat or a live connection.'
      : 'A fictional viewer offers the same practical tip. This is a fixed message, not live chat.';

    for (const job of jobOrder) {
      const button = root.querySelector<HTMLButtonElement>('[data-job="' + job + '"]');
      if (!button) continue;
      button.hidden = (job === 'edit' && day.schedule !== 'edited') || (job === 'moderate' && day.schedule !== 'live');
      button.disabled = !day.canJob(job);
      const cost = day.energyCost(job);
      const details: Partial<Record<Job, string>> = {
        feed: 'FEED HENS · ' + cost + ' ENERGY · −1 FEED · COOP +10 / HOME +2',
        repair: 'REPAIR COOP · ' + cost + ' ENERGY · −1 BOARD · COOP +22 / HOME +3',
        'tend-garden': 'TEND GARDEN · ' + cost + ' ENERGY · −1 WATER · GARDEN +12 / FOOD +1',
        'draw-water': 'DRAW WATER · ' + cost + ' ENERGY · WELL +18 / WATER +1',
        cook: 'COOK · ' + cost + ' ENERGY · −1 FOOD · ENERGY +10 / HOME +4',
        edit: 'EDIT UPDATE · ' + cost + ' ENERGY · +5 AUDIENCE / +3 BOUNDARIES · DAY 3 TOMATO CHOICE EXTRA',
        moderate: 'MODERATE · ' + cost + ' ENERGY · −2 AUDIENCE / +6 BOUNDARIES',
        rest: 'REST · ' + cost + ' ENERGY · ENERGY +20'
      };
      button.textContent = details[job] || job.toUpperCase();
      button.title = button.textContent;
      button.setAttribute('aria-label', button.textContent);
    }

    const notice = root.querySelector<HTMLElement>('[data-notice]');
    if (notice) notice.textContent = day.notice;
    const values: Record<string, string> = {
      day: String(day.dayNumber) + ' / 5',
      mode: day.mode === 'practice' ? 'PRACTICE' : day.mode === 'ranked' ? 'RANKED · LOCAL' : 'NOT STARTED',
      home: String(day.homeCondition()), coop: String(day.coop), garden: String(day.garden),
      well: String(day.well), energy: String(day.energy), boundaries: String(day.boundaries),
      cash: String(day.cash), boards: String(day.boards), feed: String(day.feed),
      water: String(day.water), food: String(day.food), audience: String(day.audience),
      slots: String(Math.max(0, 3 - day.slotsUsed))
    };
    for (const [key, value] of Object.entries(values)) {
      root.querySelectorAll<HTMLElement>('[data-meter="' + key + '"]').forEach(node => { node.textContent = value; });
    }
    const slotsCopy = root.querySelector<HTMLElement>('[data-slots-copy]');
    if (slotsCopy) slotsCopy.textContent = String(Math.max(0, 3 - day.slotsUsed)) + ' work slots remain';
    root.querySelectorAll<HTMLElement>('[data-live-only]').forEach(node => { node.hidden = day.schedule !== 'live'; });
    const report = root.querySelector<HTMLElement>('[data-report]');
    if (report) {
      report.textContent = day.dayReportText();
      report.hidden = step !== 'report' && step !== 'ending';
    }
    const ending = root.querySelector<HTMLElement>('[data-ending]');
    if (ending) ending.textContent = day.endingText;
    const zero = root.querySelector<HTMLElement>('[data-zero-reaction]');
    if (zero) zero.textContent = day.zeroReaction;
    const weekScore = root.querySelector<HTMLElement>('[data-week-score]');
    if (weekScore) weekScore.textContent = String(day.score()) + ' / 100';
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
    start() { day.reset(seed); syncControls(); },
    update(dt: number) { day.update(dt); syncControls(); },
    draw,
    keyForCode(code: string) {
      if (uiStep() === 'tomato-private') {
        if (code === 'Digit1' || code === 'Numpad1') return 'tomato-private';
        if (code === 'Digit2' || code === 'Numpad2') return 'tomato-plan';
      }
      return undefined;
    },
    input(key: string, down: boolean) {
      if (!down) return;
      const choices = () => Array.from(root.querySelectorAll<HTMLButtonElement>('.controls [data-step]:not([hidden]) button[data-key]:not([hidden]):not(:disabled)'));
      if (key === 'ui-prev' || key === 'ui-next') {
        const buttons = choices();
        if (buttons.length) {
          const current = buttons.indexOf(root.activeElement as HTMLButtonElement);
          const next = current < 0 ? (key === 'ui-next' ? 0 : buttons.length - 1) :
            (current + (key === 'ui-next' ? 1 : -1) + buttons.length) % buttons.length;
          buttons[next].focus();
        }
      } else if (key === 'ui-confirm') {
        const buttons = choices();
        const selected = buttons.includes(root.activeElement as HTMLButtonElement) ? root.activeElement as HTMLButtonElement : buttons[0];
        if (selected?.dataset.key) day.handleInput(selected.dataset.key);
        else day.handleInput('confirm');
        syncControls();
      } else {
        day.handleInput(key);
        syncControls();
      }
    },
    score() { return day.score(); },
    over() { return day.over(); },
    result() { return day.result(); },
    presentation() { return { id: 'placeholder', strings, sfx: {}, volume: 0 }; },
    setMuted() {},
    setSkin() {},
    dispose() {}
  };
}, profile);
