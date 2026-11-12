import { readLocal, writeLocal } from '../../../core/src/storage';
import { defineArcade, type GameAPI } from '../../../core/src/engine';
import type { CartridgeProfile } from '../../../core/src/cartridge';
import { assetUrl, humanZoo, loadCatalog, type Song } from './catalog';
import { compileChart, type Chart, type Difficulty, type Lane } from './chart';
import { drawHighway } from './render';
import { PRECISION_THRESHOLD, SCORE_VERSION, RhythmSession } from './session';
import { Skin } from './skin';
import { TrackVisual } from './track-visual';
import { MediaTransport } from './transport';
import css from './cabinet.css';
import markup from './cabinet.html';

const profile: CartridgeProfile = {
  version: '0.5.0-preview', shell: '<style>' + css + '</style>' + markup,
  landscape: [640, 360], portrait: [360, 640], primary: 'start',
  consumeStartInput: true,
  keys: { ' ': 'start', ArrowLeft: 'left', ArrowDown: 'down',
    ArrowUp: 'up', ArrowRight: 'right', Escape: 'pause', p: 'pause', m: 'mute' },
  padButtons: { 0: 'left', 1: 'down', 2: 'up', 3: 'right', 8: 'start', 9: 'pause',
    12: 'up', 13: 'down', 14: 'left', 15: 'right' },
  padAxes: [{ index: 0, negative: 'left', positive: 'right' },
    { index: 1, negative: 'up', positive: 'down' }],
  resultStats: { perfect: 'perfect_count', good: 'good_count', ok: 'ok_count',
    miss: 'miss_count', maxCombo: 'max_combo', maxPrecision: 'max_precision', accuracy: 'accuracy' },
  cues: {}
};

type Element = HTMLElement & {
  action(action: string, source: string, down: boolean, atMs?: number): void;
  start(): void; pause(reason?: string): void; reset(): void; muted: boolean; state: string; best: number;
};
const laneIndex: Record<string, Lane> = { left: 0, down: 1, up: 2, right: 3 };
const timeLabel = (time: number) => Math.floor(time / 60) + ':' + String(Math.floor(time % 60)).padStart(2, '0');

defineArcade('bars-per-watt', 'BARS PER WATT', (emit, host) => {
  const element = host as Element, root = host.shadowRoot!;
  const transport = new MediaTransport(), skin = new Skin(host, emit);
  const lifetime = new AbortController();
  const signal = lifetime.signal;
  const trackVisual = new TrackVisual(root.querySelector<HTMLElement>('[data-track-visual]')!, signal);
  const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const touchPointer = matchMedia('(pointer: coarse)');
  const button = root.querySelector<HTMLButtonElement>('[part=start]')!;
  const loadButton = root.querySelector<HTMLButtonElement>('[data-load]')!;
  const titleMenu = root.querySelector<HTMLElement>('[data-title]')!;
  const songMenu = root.querySelector<HTMLElement>('[data-song-menu]')!;
  const playfield = root.querySelector<HTMLElement>('.playfield')!;
  const songList = root.querySelector<HTMLElement>('[data-song-list]')!;
  const sleeve = root.querySelector<HTMLImageElement>('[data-sleeve]')!;
  const menuSound = root.querySelector<HTMLButtonElement>('[data-menu-sound]')!;
  const playLabel = root.querySelector<HTMLElement>('[data-play-label]')!;
  const difficultyButtons = Array.from(root.querySelectorAll<HTMLButtonElement>('[data-difficulty]'));
  const countIn = root.querySelector<HTMLElement>('[data-count-in]')!;
  const loading = root.querySelector<HTMLElement>('[data-loading]')!;
  const judge = root.querySelector<HTMLElement>('[data-judge]')!;
  const progress = root.querySelector<HTMLProgressElement>('[data-progress]')!;
  const time = root.querySelector<HTMLElement>('[data-time]')!;
  const score = root.querySelector<HTMLElement>('[data-score]')!;
  const combo = root.querySelector<HTMLElement>('[data-combo]')!;
  const accuracy = root.querySelector<HTMLElement>('[data-accuracy]')!;
  const hit = root.querySelector<HTMLElement>('[data-hit]')!;
  const timing = root.querySelector<HTMLElement>('[data-timing]')!;
  const precision = root.querySelector<HTMLElement>('[data-precision]')!;
  const screen = root.querySelector<HTMLElement>('.screen')!;
  const comboStat = root.querySelector<HTMLElement>('.combo-stat')!;
  const meter = root.querySelector<HTMLElement>('.meter')!;
  const meterLabel = root.querySelector<HTMLElement>('[data-meter]')!;
  const meterBars = Array.from(root.querySelectorAll<HTMLElement>('.meter-bars i'));
  let feedbackAnimation: Animation | null = null, seenMilestone = 0;
  const bill = root.querySelector<HTMLElement>('.bill')!;
  const choose = root.querySelector<HTMLButtonElement>('[data-choose]')!;
  const dialog = root.querySelector<HTMLDialogElement>('dialog')!;
  const visualControl = root.querySelector<HTMLInputElement>('[data-visual-offset]')!;
  const inputControl = root.querySelector<HTMLInputElement>('[data-input-offset]')!;
  const scrollControl = root.querySelector<HTMLInputElement>('[data-scroll-speed]')!;
  const contrastControl = root.querySelector<HTMLInputElement>('[data-contrast]')!;
  const motionControl = root.querySelector<HTMLInputElement>('[data-motion]')!;
  const backgroundControl = root.querySelector<HTMLInputElement>('[data-background-video]')!;
  const settingsKey = () => (host.getAttribute('storage-key') || 'au-arcade') + ':v1:bars-per-watt:settings';
  let settings = {
    visualOffsetMs: 0, inputOffsetMs: 0, scrollSpeed: 1, contrast: false, reducedMotion: false,
    backgroundVideo: true
  };
  try {
    const saved = JSON.parse(readLocal(settingsKey()) || '{}');
    if (Number.isFinite(saved.visualOffsetMs)) settings.visualOffsetMs = Math.max(-150, Math.min(150, saved.visualOffsetMs));
    if (Number.isFinite(saved.inputOffsetMs)) settings.inputOffsetMs = Math.max(-150, Math.min(150, saved.inputOffsetMs));
    if (Number.isFinite(saved.scrollSpeed)) settings.scrollSpeed = Math.max(.75, Math.min(1.75, saved.scrollSpeed));
    settings.contrast = saved.contrast === true; settings.reducedMotion = saved.reducedMotion === true;
    settings.backgroundVideo = saved.backgroundVideo !== false;
  } catch { /* A blocked or stale preference leaves the defaults. */ }
  visualControl.value = String(settings.visualOffsetMs);
  inputControl.value = String(settings.inputOffsetMs);
  scrollControl.value = String(settings.scrollSpeed);
  contrastControl.checked = settings.contrast; motionControl.checked = settings.reducedMotion;
  backgroundControl.checked = settings.backgroundVideo;
  const updateValues = () => {
    root.querySelector<HTMLOutputElement>('[data-visual-value]')!.textContent = settings.visualOffsetMs + ' ms';
    root.querySelector<HTMLOutputElement>('[data-input-value]')!.textContent = settings.inputOffsetMs + ' ms';
    root.querySelector<HTMLOutputElement>('[data-scroll-value]')!.textContent = settings.scrollSpeed.toFixed(2) + '×';
  };
  updateValues();
  const catalogUrl = new URL(host.getAttribute('catalog') || '../catalog.json', import.meta.url);
  let catalogAbort = new AbortController(), selectionAbort: AbortController | null = null;
  let song: Song = humanZoo, chart: Chart | null = null, session: RhythmSession | null = null;
  let menu: 'title' | 'songs' | null = 'title';
  let songs: Song[] = [humanZoo], level: Difficulty = 'easy';
  let countdownTimer = 0;
  const lastDifficulty = new Map<string, Difficulty>();
  let catalogError: string | null = null, catalogPending = true;
  let inputMode: 'unclassified' | 'keyboard' | 'touch' | 'gamepad' | 'mixed' = 'unclassified';
  let generation = 0, busy = false, disposed = false;
  const status = (text: string) => { loading.textContent = text; root.querySelector<HTMLElement>('.live')!.textContent = text; };
  const prefersReducedMotion = () => settings.reducedMotion || systemMotion.matches;
  function syncTrackVisual(reducedMotion = prefersReducedMotion()) {
    const enabled = settings.backgroundVideo && !reducedMotion && !touchPointer.matches &&
      host.dataset.orientation === 'landscape';
    const playing = element.state === 'playing' && !document.hidden && transport.playing &&
      session !== null && !session.complete;
    trackVisual.sync(enabled, playing);
  }
  for (const media of [systemMotion, touchPointer])
    media.addEventListener('change', () => syncTrackVisual(), { signal });
  const resetFeedback = () => {
    feedbackAnimation?.cancel(); feedbackAnimation = null; seenMilestone = 0;
    hit.textContent = skin.current.strings.hit_line; delete hit.dataset.grade; timing.textContent = '';
    precision.textContent = skin.current.strings.precision + ' 0/' + PRECISION_THRESHOLD;
    precision.dataset.active = 'false'; screen.classList.remove('is-overclocked');
    meter.classList.remove('is-overclocked'); comboStat.classList.remove('is-streak');
    meterLabel.textContent = 'READY'; meterBars.forEach(bar => bar.classList.remove('is-lit'));
  };
  const drawFeedback = (at: number, reducedMotion: boolean) => {
    if (!session) return;
    const strings = skin.current.strings, recent = session.latestFeedback;
    const visible = recent && at - recent.at < .55;
    hit.textContent = visible ? strings[recent.kind] : strings.hit_line;
    hit.dataset.grade = visible ? recent.kind : '';
    timing.textContent = visible && (recent.kind === 'good' || recent.kind === 'ok') ?
      strings[recent.errorSec! < 0 ? 'early' : 'late'] : '';
    precision.textContent = session.overclocked ? strings.overclocked + ' ×' + session.precision :
      strings.precision + ' ' + session.precision + '/' + PRECISION_THRESHOLD;
    precision.dataset.active = String(session.overclocked);
    screen.classList.toggle('is-overclocked', session.overclocked);
    meter.classList.toggle('is-overclocked', session.overclocked);
    comboStat.classList.toggle('is-streak', session.combo >= 10);
    meterLabel.textContent = session.overclocked ? strings.overclocked : 'COMBO ×' + session.combo;
    const litBars = session.overclocked ? meterBars.length : Math.ceil(session.combo / 5);
    meterBars.forEach((bar, index) => bar.classList.toggle('is-lit', index < litBars));
    const milestone = session.milestone;
    if (reducedMotion) feedbackAnimation?.cancel();
    if (!milestone) { feedbackAnimation?.cancel(); return; }
    if (milestone.id === seenMilestone) return;
    seenMilestone = milestone.id;
    if (milestone.kind === 'precision' && milestone.count === PRECISION_THRESHOLD)
      root.querySelector<HTMLElement>('.live')!.textContent = strings.overclocked + ' Five perfect hits.';
    if (!reducedMotion && at - milestone.at < .55) {
      feedbackAnimation?.cancel();
      feedbackAnimation = (milestone.kind === 'precision' ? precision : combo).animate(
        [{ transform: 'scale(1)' }, { transform: 'scale(1.12)', offset: .3 }, { transform: 'scale(1)' }],
        { duration: 360, easing: 'ease-out' });
    }
  };
  const showMenu = (view: typeof menu, focus = true) => {
    menu = view;
    titleMenu.hidden = view !== 'title';
    songMenu.hidden = view !== 'songs';
    playfield.inert = view !== null;
    if (!focus) return;
    if (view === 'title') titleMenu.querySelector<HTMLButtonElement>('[data-open-songs]')!.focus();
    if (view === 'songs') songList.querySelector<HTMLButtonElement>('[aria-pressed=true]')?.focus();
  };
  const canLoad = () => !catalogPending && !catalogError && song.rightsStatus === 'cleared' &&
    Boolean(song.audio && song.audioVersion && song.charts?.[level]);
  function cancelLoad() {
    ++generation;
    selectionAbort?.abort();
    selectionAbort = null;
    trackVisual.setTrack();
    transport.unload();
    chart = null;
    busy = false;
    button.disabled = true;
    songMenu.removeAttribute('aria-busy');
  }
  function updateDifficulty() {
    for (const option of difficultyButtons) {
      const available = song.rightsStatus === 'cleared' && !!song.charts?.[option.dataset.difficulty as Difficulty];
      option.disabled = !available;
      option.setAttribute('aria-pressed', String(option.dataset.difficulty === level));
    }
    loadButton.disabled = busy || !canLoad();
    playLabel.textContent = busy ? 'LOADING…' : 'PLAY SONG';
    status(catalogError ? 'Could not load the song catalog.' :
      catalogPending ? 'Loading songs…' :
      canLoad() ? '' : 'A playable chart and cleared playback copy are needed.');
  }
  function selectSong(next: Song) {
    cancelLoad();
    song = next;
    const available = difficultyButtons.map(option => option.dataset.difficulty as Difficulty)
      .filter(option => song.charts?.[option]);
    const last = lastDifficulty.get(song.id);
    level = last && available.includes(last) ? last : available[0] || 'easy';
    for (const item of Array.from(songList.querySelectorAll<HTMLButtonElement>('button')))
      item.setAttribute('aria-pressed', String(item.dataset.song === song.id));
    root.querySelector<HTMLElement>('[data-song-title]')!.textContent = song.title;
    root.querySelector<HTMLElement>('[data-artist]')!.textContent = song.artist || 'Algorithmic Uprising';
    root.querySelector<HTMLElement>('[data-song-meta]')!.textContent =
      timeLabel(song.durationSec) + (song.explicit ? ' · EXPLICIT' : '');
    sleeve.hidden = true;
    sleeve.removeAttribute('src');
    if (song.sleeve) {
      sleeve.src = assetUrl(song.sleeve, catalogUrl).href;
      sleeve.hidden = false;
    }
    progress.max = song.durationSec;
    updateDifficulty();
  }
  function populateSongs() {
    songList.replaceChildren(...songs.map(item => {
      const row = document.createElement('button');
      row.type = 'button';
      row.dataset.song = item.id;
      row.textContent = item.title;
      row.addEventListener('click', () => selectSong(item), { signal });
      return row;
    }));
    selectSong(songs.find(item => item.id === song.id) || songs[0]);
  }
  const catalogReady = loadCatalog(catalogUrl, catalogAbort.signal).then(data => {
    if (disposed) return;
    catalogPending = false;
    if (data.songs.length) songs = data.songs;
    if (menu === 'songs') populateSongs();
  }).catch(error => {
    if (!catalogAbort.signal.aborted) {
      catalogPending = false;
      catalogError = String(error);
      if (menu === 'songs') updateDifficulty();
    }
  });
  async function loadSelection() {
    await catalogReady;
    if (menu !== 'songs' || !canLoad() || busy) return;
    selectionAbort = new AbortController();
    const current = ++generation;
    const abort = selectionAbort;
    const selectedSong = song;
    const selectedLevel = level;
    const chartPath = selectedSong.charts![selectedLevel]!;
    const audioPath = selectedSong.audio!;
    button.disabled = true;
    busy = true;
    songMenu.setAttribute('aria-busy', 'true');
    updateDifficulty();
    status('Loading chart and audio…');
    emit('game:loading', { songId: selectedSong.id, phase: 'media' });
    try {
      const chartUrl = assetUrl(chartPath, catalogUrl);
      const response = await fetch(chartUrl, { signal: abort.signal,
        credentials: chartUrl.origin === location.origin ? 'same-origin' : 'omit' });
      if (!response.ok || Number(response.headers.get('content-length')) > 256000) throw Error('Chart unavailable');
      const raw = await response.text();
      if (raw.length > 256000) throw Error('Chart too large');
      const candidate = compileChart(JSON.parse(raw));
      if (candidate.songId !== selectedSong.id || candidate.difficulty !== selectedLevel ||
          candidate.audioVersion !== selectedSong.audioVersion ||
          Math.abs(candidate.durationSec - selectedSong.durationSec) > .1)
        throw Error('Chart does not match this audio version');
      await transport.load(assetUrl(audioPath, catalogUrl), abort.signal);
      if (Number.isFinite(transport.duration) &&
          Math.abs(transport.duration - candidate.durationSec) > .5)
        throw Error('Playback copy duration does not match the chart');
      if (current !== generation || disposed) return;
      chart = candidate;
      busy = false;
      songMenu.removeAttribute('aria-busy');
      button.disabled = false;
      status('');
      emit('game:loading', { songId: selectedSong.id, phase: 'ready' });
      element.start();
    } catch (error) {
      if (current !== generation || abort.signal.aborted || disposed) return;
      cancelLoad();
      updateDifficulty();
      status('Could not load this song. Try Play Song again.');
      emit('game:transport-error', { songId: selectedSong.id, reason: String(error) });
    }
  }
  titleMenu.querySelector('[data-open-songs]')!.addEventListener('click', () => {
    populateSongs();
    showMenu('songs');
  }, { signal });
  songMenu.querySelector('[data-back]')!.addEventListener('click', () => {
    cancelLoad();
    showMenu('title');
  }, { signal });
  sleeve.addEventListener('error', () => { sleeve.hidden = true; }, { signal });
  menuSound.addEventListener('click', () => root.querySelector<HTMLButtonElement>('[part=sound]')!.click(), { signal });
  loadButton.addEventListener('click', () => void loadSelection(), { signal });
  for (const option of difficultyButtons) option.addEventListener('click', () => {
    const next = option.dataset.difficulty as Difficulty;
    if (level === next) return;
    cancelLoad();
    level = next;
    lastDifficulty.set(song.id, level);
    updateDifficulty();
  }, { signal });
  choose.addEventListener('click', () => {
    choose.hidden = true;
    element.reset();
    showMenu('songs');
  }, { signal });
  const menuButtons = () => Array.from(
    (menu === 'title' ? titleMenu : songMenu).querySelectorAll<HTMLButtonElement>('button:not(:disabled)'));
  function moveMenu(delta: number) {
    const items = menuButtons();
    const at = items.findIndex(item => item === root.activeElement);
    const next = at < 0 ? (delta < 0 ? items.length - 1 : 0) : (at + delta + items.length) % items.length;
    items[next]?.focus();
  }
  const activateMenu = () => {
    const items = menuButtons();
    (items.find(item => item === root.activeElement) ||
      (menu === 'title' ? items[0] : songList.querySelector<HTMLButtonElement>('[aria-pressed=true]')))?.click();
  };
  const backMenu = () => {
    if (menu === 'songs') songMenu.querySelector<HTMLButtonElement>('[data-back]')!.click();
  };
  host.addEventListener('keydown', event => {
    if (!menu || dialog.open || event.altKey || event.ctrlKey || event.metaKey) return;
    const moves: Record<string, number> = { ArrowUp: -1, ArrowLeft: -1, ArrowDown: 1, ArrowRight: 1 };
    if (event.key in moves) {
      event.preventDefault();
      event.stopImmediatePropagation();
      moveMenu(moves[event.key]);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      event.stopImmediatePropagation();
      backMenu();
    } else if ((event.key === 'Enter' || event.key === ' ') && !root.activeElement) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (!event.repeat) activateMenu();
    }
  }, { capture: true, signal });
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden || !busy) return;
    cancelLoad();
    updateDifficulty();
  }, { signal });
  host.addEventListener('game:pause', () => { choose.hidden = false; }, { signal });
  host.addEventListener('game:resume', () => { choose.hidden = true; }, { signal });
  host.addEventListener('game:over', () => {
    trackVisual.stop();
    if (!session) return;
    bill.hidden = false; choose.hidden = false;
    root.querySelector<HTMLElement>('[data-bill-song]')!.textContent = song.title.toUpperCase();
    judge.textContent = 'METER SETTLED';
    root.querySelector<HTMLOutputElement>('[data-bill-score]')!.textContent = String(session.score);
    root.querySelector<HTMLOutputElement>('[data-bill-best]')!.textContent = String(element.best);
    root.querySelector<HTMLOutputElement>('[data-bill-total]')!.textContent = String(session.score);
    root.querySelector<HTMLOutputElement>('[data-bill-accuracy]')!.textContent = session.accuracy + '%';
    root.querySelector<HTMLOutputElement>('[data-bill-combo]')!.textContent = String(session.maxCombo);
    root.querySelector<HTMLOutputElement>('[data-bill-precision]')!.textContent = String(session.maxPrecision);
    root.querySelector<HTMLOutputElement>('[data-bill-hits]')!.textContent =
      [session.totals.perfect, session.totals.good, session.totals.ok].join(' / ');
    root.querySelector<HTMLOutputElement>('[data-bill-miss]')!.textContent = String(session.totals.miss);
  }, { signal });
  for (const settingsButton of Array.from(root.querySelectorAll('[part=settings], [data-menu-settings]')))
    settingsButton.addEventListener('click', () => {
      if (element.state === 'playing') element.pause('settings');
      dialog.showModal();
    }, { signal });
  dialog.querySelector('form')!.addEventListener('change', () => {
    settings = { visualOffsetMs: Number(visualControl.value), inputOffsetMs: Number(inputControl.value),
      scrollSpeed: Number(scrollControl.value),
      contrast: contrastControl.checked, reducedMotion: motionControl.checked,
      backgroundVideo: backgroundControl.checked };
    host.dataset.reducedMotion = String(settings.reducedMotion);
    syncTrackVisual();
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
  function stopCountdown() {
    clearTimeout(countdownTimer);
    countIn.hidden = true;
  }
  function playAudio(fromStart = false) {
    const current = session;
    void transport.play(fromStart).catch(error => {
      if (disposed || session !== current || element.state !== 'playing') return;
      emit('game:transport-error', { songId: song.id, reason: String(error) });
      element.pause('audio-error');
      root.querySelector<HTMLElement>('[data-detail]')!.textContent = 'Press Resume to start audio.';
    });
  }
  function countdown(remaining: number) {
    if (remaining === 0) {
      countIn.hidden = true;
      playAudio(true);
      return;
    }
    countIn.hidden = false;
    countIn.textContent = String(remaining);
    countdownTimer = window.setTimeout(() => countdown(remaining - 1), 400);
  }
  transport.onEnd = () => session?.finish();
  transport.onState = () => {
    syncTrackVisual();
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
    menuPad(buttonIndex) {
      if (!menu) return false;
      if ([12, 14].includes(buttonIndex)) moveMenu(-1);
      if ([13, 15].includes(buttonIndex)) moveMenu(1);
      if ([0, 8].includes(buttonIndex)) activateMenu();
      if (buttonIndex === 1) backMenu();
      return true;
    },
    start() {
      if (!chart) return;
      showMenu(null, false);
      stopCountdown();
      transport.reset(); session = new RhythmSession(chart);
      trackVisual.setTrack(
        song.sleeve ? assetUrl(song.sleeve, catalogUrl) : null,
        song.backgroundVideo ? assetUrl(song.backgroundVideo, catalogUrl) : null
      );
      resetFeedback();
      inputMode = 'unclassified';
      bill.hidden = true; choose.hidden = true;
      score.textContent = '0'; combo.textContent = '0'; accuracy.textContent = '0%';
      progress.value = 0; time.textContent = '0:00';
      judge.textContent = 'HIT THE LINE';
      countdown(3);
    },
    update() {
      if (!session || !transport.playing) return;
      session.advance(transport.time);
    },
    draw(ctx, w, h) {
      const at = transport.time;
      const reducedMotion = prefersReducedMotion();
      host.dataset.reducedMotion = String(reducedMotion);
      syncTrackVisual(reducedMotion);
      drawHighway(ctx, w, h, session, at, skin.palette, settings.visualOffsetMs,
        settings.contrast, reducedMotion, settings.scrollSpeed);
      if (!session) return;
      drawFeedback(at, reducedMotion);
      score.textContent = String(session.score); combo.textContent = String(session.combo);
      accuracy.textContent = session.accuracy + '%';
      progress.value = Math.min(at, song.durationSec); time.textContent = timeLabel(at);
      if (transport.playing) {
        const holds = session.activeHolds;
        const release = holds.filter(note => note.endTime! - at <= .35);
        const arrows = (notes: readonly { lane: Lane }[]) => notes.map(note => ['←', '↓', '↑', '→'][note.lane]).join(' ');
        judge.textContent = release.length ? skin.current.strings.release_cue + ' ' + arrows(release) :
          holds.length ? skin.current.strings.hold_cue + ' ' + arrows(holds) : skin.current.strings.hit_line;
      }
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
      const eventTime = transport.atEvent(atMs);
      session.input(laneIndex[action], down, eventTime - settings.inputOffsetMs / 1000, eventTime);
    },
    releaseInput() {
      session?.clearPressed();
      root.querySelectorAll('[data-lane]').forEach(pad => pad.classList.remove('is-down'));
    },
    score: () => session?.score || 0,
    over: () => session?.complete || false,
    bestKey: () => chart ? 'best:' + SCORE_VERSION + ':' + song.id + ':' + chart.id + ':' + chart.difficulty + ':' + inputMode : 'best:' + SCORE_VERSION,
    result: () => ({
      cause: 'complete', causeLine: skin.current.strings.gameover_any,
      songId: song.id, chartId: chart?.id, audioVersion: chart?.audioVersion, difficulty: chart?.difficulty,
      inputMode, scoreVersion: SCORE_VERSION, accuracy: session?.accuracy || 0, maxCombo: session?.maxCombo || 0,
      maxPrecision: session?.maxPrecision || 0,
      stats: { ...session?.totals, maxCombo: session?.maxCombo || 0,
        maxPrecision: session?.maxPrecision || 0, accuracy: session?.accuracy || 0 },
      shareText: 'I banked {score} fictional points in BARS PER WATT · ' + song.title + ': {url}'
    }),
    onPause: () => { stopCountdown(); trackVisual.pause(); transport.pause(); },
    onResume: () => playAudio(),
    onReset: () => {
      stopCountdown();
      cancelLoad();
      session = null;
      resetFeedback();
      bill.hidden = true;
      choose.hidden = true;
      updateDifficulty();
      showMenu('title', false);
    },
    setMuted: muted => {
      transport.setMuted(muted);
      menuSound.textContent = muted ? 'SOUND OFF' : 'SOUND ON';
      menuSound.setAttribute('aria-pressed', String(!muted));
    },
    setSkin: path => skin.load(path),
    presentation: () => skin.current,
    dispose: () => {
      disposed = true; ++generation; catalogAbort.abort(); selectionAbort?.abort();
      trackVisual.setTrack();
      stopCountdown(); feedbackAnimation?.cancel(); lifetime.abort(); skin.dispose(); transport.dispose();
    }
  };
  host.dataset.reducedMotion = String(settings.reducedMotion);
  return game;
}, profile);
