import { readLocal, writeLocal } from '../../../core/src/storage';
import { defineArcade, type GameAPI } from '../../../core/src/engine';
import type { CartridgeProfile } from '../../../core/src/cartridge';
import { assetUrl, humanZoo, loadCatalog, type Song } from './catalog';
import { compileChart, type Chart, type Difficulty, type Lane } from './chart';
import { drawHighway } from './render';
import { RhythmSession } from './session';
import { Skin } from './skin';
import { MediaTransport } from './transport';
import css from './cabinet.css';
import markup from './cabinet.html';

const profile: CartridgeProfile = {
  version: '0.1.0-preview', shell: '<style>' + css + '</style>' + markup,
  landscape: [640, 360], portrait: [360, 640], primary: 'start',
  consumeStartInput: true,
  keys: { ' ': 'start', ArrowLeft: 'left', ArrowDown: 'down',
    ArrowUp: 'up', ArrowRight: 'right', Escape: 'pause', p: 'pause', m: 'mute' },
  padButtons: { 0: 'left', 1: 'down', 2: 'up', 3: 'right', 8: 'start', 9: 'pause',
    12: 'up', 13: 'down', 14: 'left', 15: 'right' },
  padAxes: [{ index: 0, negative: 'left', positive: 'right' },
    { index: 1, negative: 'up', positive: 'down' }],
  resultStats: { perfect: 'perfect_count', good: 'good_count',
    miss: 'miss_count', maxCombo: 'max_combo', accuracy: 'accuracy' },
  cues: {}
};

type Element = HTMLElement & {
  action(action: string, source: string, down: boolean, atMs?: number): void;
  pause(reason?: string): void; reset(): void; muted: boolean; state: string; best: number;
};
const laneIndex: Record<string, Lane> = { left: 0, down: 1, up: 2, right: 3 };
const timeLabel = (time: number) => Math.floor(time / 60) + ':' + String(Math.floor(time % 60)).padStart(2, '0');

defineArcade('bars-per-watt', 'BARS PER WATT', (emit, host) => {
  const element = host as Element, root = host.shadowRoot!;
  const transport = new MediaTransport(), skin = new Skin(host, emit);
  const lifetime = new AbortController();
  const signal = lifetime.signal;
  const button = root.querySelector<HTMLButtonElement>('[part=start]')!;
  const loadButton = root.querySelector<HTMLButtonElement>('[data-load]')!;
  const difficulty = root.querySelector<HTMLSelectElement>('[data-difficulty]')!;
  const loading = root.querySelector<HTMLElement>('[data-loading]')!;
  const judge = root.querySelector<HTMLElement>('[data-judge]')!;
  const progress = root.querySelector<HTMLProgressElement>('[data-progress]')!;
  const time = root.querySelector<HTMLElement>('[data-time]')!;
  const score = root.querySelector<HTMLElement>('[data-score]')!;
  const combo = root.querySelector<HTMLElement>('[data-combo]')!;
  const accuracy = root.querySelector<HTMLElement>('[data-accuracy]')!;
  const bill = root.querySelector<HTMLElement>('.bill')!;
  const choose = root.querySelector<HTMLButtonElement>('[data-choose]')!;
  const dialog = root.querySelector<HTMLDialogElement>('dialog')!;
  const visualControl = root.querySelector<HTMLInputElement>('[data-visual-offset]')!;
  const inputControl = root.querySelector<HTMLInputElement>('[data-input-offset]')!;
  const contrastControl = root.querySelector<HTMLInputElement>('[data-contrast]')!;
  const motionControl = root.querySelector<HTMLInputElement>('[data-motion]')!;
  const settingsKey = () => (host.getAttribute('storage-key') || 'au-arcade') + ':v1:bars-per-watt:settings';
  let settings = { visualOffsetMs: 0, inputOffsetMs: 0, contrast: false, reducedMotion: false };
  try {
    const saved = JSON.parse(readLocal(settingsKey()) || '{}');
    if (Number.isFinite(saved.visualOffsetMs)) settings.visualOffsetMs = Math.max(-150, Math.min(150, saved.visualOffsetMs));
    if (Number.isFinite(saved.inputOffsetMs)) settings.inputOffsetMs = Math.max(-150, Math.min(150, saved.inputOffsetMs));
    settings.contrast = saved.contrast === true; settings.reducedMotion = saved.reducedMotion === true;
  } catch { /* A blocked or stale preference leaves the defaults. */ }
  visualControl.value = String(settings.visualOffsetMs);
  inputControl.value = String(settings.inputOffsetMs);
  contrastControl.checked = settings.contrast; motionControl.checked = settings.reducedMotion;
  const updateValues = () => {
    root.querySelector<HTMLOutputElement>('[data-visual-value]')!.textContent = settings.visualOffsetMs + ' ms';
    root.querySelector<HTMLOutputElement>('[data-input-value]')!.textContent = settings.inputOffsetMs + ' ms';
  };
  updateValues();
  const catalogUrl = new URL(host.getAttribute('catalog') || '../catalog.json', import.meta.url);
  let catalogAbort = new AbortController(), selectionAbort: AbortController | null = null;
  let song: Song = humanZoo, chart: Chart | null = null, session: RhythmSession | null = null;
  let inputMode: 'unclassified' | 'keyboard' | 'touch' | 'gamepad' | 'mixed' = 'unclassified';
  let generation = 0, busy = false, disposed = false;
  const status = (text: string) => { loading.textContent = text; root.querySelector<HTMLElement>('.live')!.textContent = text; };
  const catalogReady = loadCatalog(catalogUrl, catalogAbort.signal).then(data => {
    song = data.songs.find(item => item.id === 'AU-001') || humanZoo;
    status(song.audio && song.rightsStatus === 'cleared' ? 'Choose a difficulty, then load The Human Zoo.' :
      'The Human Zoo is selected. A reviewed chart and playback copy are needed.');
    progress.max = song.durationSec;
  }).catch(error => {
    if (!catalogAbort.signal.aborted) status('Catalog unavailable: ' + String(error));
  });
  async function loadSelection() {
    await catalogReady;
    const level = difficulty.value as Difficulty;
    const chartPath = song.charts?.[level], audioPath = song.audio;
    if (song.rightsStatus !== 'cleared' || !audioPath || !chartPath || !song.audioVersion) {
      status('This difficulty needs cleared rights, a reviewed chart and playback copy.');
      return;
    }
    selectionAbort?.abort(); selectionAbort = new AbortController();
    const current = ++generation;
    const abort = selectionAbort;
    button.disabled = true; loadButton.disabled = true; busy = true;
    status('Loading chart and song…');
    emit('game:loading', { songId: song.id, phase: 'media' });
    try {
      const chartUrl = assetUrl(chartPath, catalogUrl);
      const response = await fetch(chartUrl, { signal: abort.signal, credentials: 'omit' });
      if (!response.ok || Number(response.headers.get('content-length')) > 256000) throw Error('Chart unavailable');
      const raw = await response.text();
      if (raw.length > 256000) throw Error('Chart too large');
      const candidate = compileChart(JSON.parse(raw));
      if (candidate.songId !== song.id || candidate.difficulty !== level ||
          candidate.audioVersion !== song.audioVersion ||
          Math.abs(candidate.durationSec - song.durationSec) > .1)
        throw Error('Chart does not match this audio version');
      await transport.load(assetUrl(audioPath, catalogUrl), abort.signal);
      if (Number.isFinite(transport.duration) &&
          Math.abs(transport.duration - candidate.durationSec) > .5)
        throw Error('Playback copy duration does not match the chart');
      if (current !== generation || disposed) return;
      chart = candidate; button.disabled = false;
      status('Ready. Enable sound, then play ' + level.toUpperCase() + '.');
      emit('game:loading', { songId: song.id, phase: 'ready' });
    } catch (error) {
      if (current !== generation || abort.signal.aborted || disposed) return;
      chart = null; transport.unload();
      status('Could not load song: ' + String(error));
      emit('game:transport-error', { songId: song.id, reason: String(error) });
    } finally {
      if (current === generation) { busy = false; loadButton.disabled = false; }
    }
  }
  loadButton.addEventListener('click', () => void loadSelection(), { signal });
  difficulty.addEventListener('change', () => {
    ++generation; selectionAbort?.abort(); selectionAbort = null;
    transport.unload(); busy = false; loadButton.disabled = false;
    chart = null; button.disabled = true; status('Load ' + difficulty.value.toUpperCase() + ' to play.');
  }, { signal });
  choose.addEventListener('click', () => {
    choose.hidden = true; element.reset();
  }, { signal });
  host.addEventListener('game:over', () => {
    if (!session) return;
    bill.hidden = false; choose.hidden = false;
    judge.textContent = 'METER SETTLED';
    root.querySelector<HTMLOutputElement>('[data-bill-score]')!.textContent = String(session.score);
    root.querySelector<HTMLOutputElement>('[data-bill-best]')!.textContent = String(element.best);
    root.querySelector<HTMLOutputElement>('[data-bill-total]')!.textContent = String(session.score);
    root.querySelector<HTMLOutputElement>('[data-bill-accuracy]')!.textContent = session.accuracy + '%';
    root.querySelector<HTMLOutputElement>('[data-bill-combo]')!.textContent = String(session.maxCombo);
  }, { signal });
  root.querySelector<HTMLButtonElement>('[part=settings]')!.addEventListener('click', () => {
    if (element.state === 'playing') element.pause('settings');
    dialog.showModal();
  }, { signal });
  dialog.querySelector('form')!.addEventListener('change', () => {
    settings = { visualOffsetMs: Number(visualControl.value), inputOffsetMs: Number(inputControl.value),
      contrast: contrastControl.checked, reducedMotion: motionControl.checked };
    writeLocal(settingsKey(), JSON.stringify(settings)); updateValues();
  }, { signal });
  for (const pad of Array.from(root.querySelectorAll<HTMLButtonElement>('[data-lane]'))) {
    const action = pad.dataset.lane!;
    const held = new Set<number>();
    pad.addEventListener('pointerdown', event => {
      if (event.button !== 0 || element.state !== 'playing') return;
      event.preventDefault(); element.focus({ preventScroll: true });
      pad.setPointerCapture(event.pointerId); held.add(event.pointerId);
      pad.classList.add('is-down');
      element.action(action, 'pointer:' + action + ':' + event.pointerId, true, event.timeStamp);
    }, { signal });
    const release = (event: PointerEvent) => {
      if (!held.delete(event.pointerId)) return;
      pad.classList.toggle('is-down', held.size > 0);
      element.action(action, 'pointer:' + action + ':' + event.pointerId, false, event.timeStamp);
    };
    for (const name of ['pointerup', 'pointercancel', 'lostpointercapture'] as const)
      pad.addEventListener(name, release, { signal });
    pad.addEventListener('click', event => {
      if (event.detail !== 0) return;
      const source = 'accessible:' + action;
      element.action(action, source, true, performance.now());
      element.action(action, source, false, performance.now());
    }, { signal });
  }
  transport.onEnd = () => session?.finish();
  transport.onState = () => {
    if (element.state === 'playing' && !transport.playing && !session?.complete)
      judge.textContent = 'BUFFERING / PAUSED';
  };
  const keyForCode = (code: string) => ({
    KeyD: 'left', KeyF: 'down', KeyJ: 'up', KeyK: 'right',
    ArrowLeft: 'left', ArrowDown: 'down', ArrowUp: 'up', ArrowRight: 'right',
    Space: 'start'
  } as Record<string, string>)[code];
  const game: GameAPI = {
    canStart: () => Boolean(chart) && !busy,
    keyForCode,
    start() {
      if (!chart) return;
      transport.reset(); session = new RhythmSession(chart);
      inputMode = 'unclassified';
      bill.hidden = true; choose.hidden = true;
      score.textContent = '0'; combo.textContent = '0'; accuracy.textContent = '0%';
      progress.value = 0; time.textContent = '0:00';
      judge.textContent = 'HIT THE LINE';
      void transport.play(true).catch(error => {
        status('Playback blocked: enable sound and retry.');
        emit('game:transport-error', { songId: song.id, reason: String(error) });
        element.pause('audio-error');
      });
    },
    update() {
      if (!session || !transport.playing) return;
      session.advance(transport.time);
    },
    draw(ctx, w, h) {
      const at = transport.time;
      drawHighway(ctx, w, h, session, at, skin.palette, settings.visualOffsetMs,
        settings.contrast, settings.reducedMotion || matchMedia('(prefers-reduced-motion: reduce)').matches);
      if (!session) return;
      score.textContent = String(session.score); combo.textContent = String(session.combo);
      accuracy.textContent = session.accuracy + '%';
      progress.value = Math.min(at, song.durationSec); time.textContent = timeLabel(at);
      if (transport.playing) judge.textContent = session.latest && at - session.latestAt < .55 ?
        skin.current.strings[session.latest] : 'HIT THE LINE';
    },
    input(action, down, atMs = performance.now(), source = '') {
      if (!session || !transport.playing || !(action in laneIndex)) return;
      if (down) {
        const mode = source.startsWith('keyboard:') ? 'keyboard' :
          source.startsWith('pointer:') || source.startsWith('accessible:') ? 'touch' :
          source.startsWith('pad:') || source.startsWith('pad-axis:') ? 'gamepad' : null;
        if (mode) inputMode = inputMode === 'unclassified' ? mode :
          inputMode === mode ? inputMode : 'mixed';
      }
      session.input(laneIndex[action], down, transport.atEvent(atMs) - settings.inputOffsetMs / 1000);
    },
    releaseInput() { /* The shared engine releases every held lane before pause. */ },
    score: () => session?.score || 0,
    over: () => session?.complete || false,
    bestKey: () => chart ? 'best:' + song.id + ':' + chart.id + ':' + chart.difficulty + ':' + inputMode : 'best',
    result: () => ({
      cause: 'complete', causeLine: skin.current.strings.gameover_any,
      songId: song.id, chartId: chart?.id, audioVersion: chart?.audioVersion, difficulty: chart?.difficulty,
      inputMode, accuracy: session?.accuracy || 0, maxCombo: session?.maxCombo || 0,
      stats: { ...session?.totals, maxCombo: session?.maxCombo || 0, accuracy: session?.accuracy || 0 },
      shareText: 'I banked {score} fictional points in BARS PER WATT · The Human Zoo: {url}'
    }),
    onPause: () => transport.pause(),
    onResume: () => { void transport.play().catch(error => {
      emit('game:transport-error', { songId: song.id, reason: String(error) });
      element.pause('audio-error');
    }); },
    onReset: () => {
      ++generation; selectionAbort?.abort(); selectionAbort = null;
      transport.unload(); session = null; chart = null; busy = false;
      button.disabled = true; loadButton.disabled = false; bill.hidden = true; choose.hidden = true;
      status('Choose a difficulty, then load The Human Zoo.');
    },
    setMuted: muted => transport.setMuted(muted),
    setSkin: path => skin.load(path),
    presentation: () => skin.current,
    dispose: () => {
      disposed = true; ++generation; catalogAbort.abort(); selectionAbort?.abort();
      lifetime.abort(); skin.dispose(); transport.dispose();
    }
  };
  return game;
}, profile);
