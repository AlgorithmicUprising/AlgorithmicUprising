export type Schedule = 'live' | 'edited' | 'offline' | null;
export type CameraZone = 'coop' | 'garden' | 'well' | 'porch' | 'workbench' | 'private-room';
export type Job = 'feed' | 'repair' | 'tend-garden' | 'draw-water' | 'cook' | 'edit' | 'moderate' | 'rest' | 'sponsor' | 'community';
export type RunMode = 'ranked' | 'practice' | null;
export type Ending = 'always-on' | 'offline-morning' | 'shared-yard' | 'recovery-plan';
export type Stage = 'mode' | 'schedule' | 'camera-setup' | 'schedule-ready' | 'message' | 'tomato' | 'storm-choice' | 'tasks' | 'animating' | 'report' | 'cadence' | 'ending' | 'complete';

type Signal = (name: string, detail?: Record<string, unknown>) => void;
type Snapshot = { home: number; coop: number; garden: number; well: number; energy: number; boundaries: number; cash: number; boards: number; feed: number; water: number; food: number };
type Animation = { job: Job; elapsed: number; duration: number; fromX: number; toX: number; energyCost: number };
export type DayReport = { day: number; schedule: Exclude<Schedule, null>; jobs: Job[]; event: string; before: Snapshot; after: Snapshot & { homeCondition: number; supplies: number }; audience: number };

export const CAMERA_ZONES: readonly CameraZone[] = ['coop', 'garden', 'well', 'porch', 'workbench', 'private-room'];
export const CAMERA_LABELS: Record<CameraZone, string> = {
  coop: 'COOP CAM',
  garden: 'GARDEN CAM',
  well: 'WELL CAM',
  porch: 'PORCH CAM',
  workbench: 'WORKBENCH CAM',
  'private-room': 'PRIVATE ROOM'
};
export const RANKED_SCENARIO = { id: 'paradise-week-01', seed: 420521, scoreVersion: 'paradise-five-day-v1', zeroScore: 72 } as const;
export const SPONSOR_TERMS = { cash: 16, boards: 2, energy: 6, boundaryLoss: 18, audience: 6 } as const;
export const MAX_LIVE_CAMERAS = 3;

const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(high, value));
const freshCameras = (): Record<CameraZone, boolean> => ({ coop: false, garden: false, well: false, porch: false, workbench: false, 'private-room': false });
const emptySnapshot = (): Snapshot => ({ home: 54, coop: 38, garden: 42, well: 50, energy: 76, boundaries: 100, cash: 8, boards: 1, feed: 2, water: 2, food: 2 });
const ZERO_REACTIONS: Record<Ending, string> = {
  'always-on': 'A bright frame still has an edge.',
  'offline-morning': 'Quiet time never asked for a view count.',
  'shared-yard': 'A bounded ask left room for a real answer.',
  'recovery-plan': 'A rough week is information, not a verdict.'
};

export class ParadiseDay {
  stage: Stage = 'mode';
  mode: RunMode = null;
  dayNumber = 1;
  schedule: Schedule = null;
  stream = false;
  cameras = freshCameras();
  home = 54;
  coop = 38;
  garden = 42;
  well = 50;
  energy = 76;
  boundaries = 100;
  cash = 8;
  boards = 1;
  feed = 2;
  water = 2;
  food = 2;
  audience = 0;
  slotsUsed = 0;
  jobsToday: Job[] = [];
  days: DayReport[] = [];
  animation: Animation | null = null;
  actorX = 455;
  time = 0;
  notice = 'Choose Ranked Scenario or Practice.';
  reducedMotion: boolean;
  hensFed = false;
  coopRepaired = false;
  gardenWatered = false;
  wellDrawn = false;
  stormActive = false;
  tomatoActive = false;
  tomatoChoice: 'keep' | 'reframe' | 'hide' | 'stop' | 'private' | 'plan' | null = null;
  privateRevealActive = false;
  privateRoomShared = false;
  privateExposureThisDay = false;
  privateExposureChargedToday = false;
  tipReady = false;
  messageResolved = false;
  tomatoResolved = false;
  stormResolved = false;
  stormApplied = false;
  daySettled = false;
  cadence: Ending | null = null;
  ending: Ending | null = null;
  endingText = '';
  zeroReaction = '';
  private dayBefore: Snapshot = emptySnapshot();
  private eventNote = '';

  constructor(public seed: number = RANKED_SCENARIO.seed, reducedMotion = false, private emit: Signal = () => {}) {
    this.reducedMotion = reducedMotion;
    this.reset(seed);
  }

  reset(seed = this.seed) {
    this.seed = Number.isFinite(seed) ? seed | 0 : RANKED_SCENARIO.seed;
    this.stage = 'mode'; this.mode = null; this.dayNumber = 1;
    this.schedule = null; this.stream = false; this.cameras = freshCameras();
    Object.assign(this, emptySnapshot());
    this.audience = 0; this.slotsUsed = 0; this.jobsToday = []; this.days = [];
    this.animation = null; this.actorX = 455; this.time = 0;
    this.notice = 'Choose Ranked Scenario or Practice. No network connection is needed.';
    this.hensFed = false; this.coopRepaired = false; this.gardenWatered = false; this.wellDrawn = false;
    this.stormActive = false; this.tomatoActive = false; this.tomatoChoice = null; this.privateRevealActive = false; this.privateRoomShared = false;
    this.privateExposureThisDay = false; this.privateExposureChargedToday = false;
    this.tipReady = false; this.messageResolved = false; this.tomatoResolved = false; this.stormResolved = false;
    this.stormApplied = false; this.daySettled = false; this.cadence = null; this.ending = null; this.endingText = ''; this.zeroReaction = '';
    this.eventNote = ''; this.dayBefore = this.snapshot();
  }

  setReducedMotion(value: boolean) { this.reducedMotion = value; }

  chooseMode(mode: Exclude<RunMode, null>) {
    if (this.stage !== 'mode') return false;
    this.mode = mode;
    this.seed = RANKED_SCENARIO.seed;
    this.prepareDay();
    this.stage = 'schedule';
    this.notice = 'You left Glitchport for a small homestead. Pick a day-one schedule; the chores stay either way.';
    this.emit('game:mode', { mode, scenario: RANKED_SCENARIO.id, seed: this.seed, scoreVersion: RANKED_SCENARIO.scoreVersion });
    return true;
  }

  chooseSchedule(schedule: Exclude<Schedule, null>) {
    if (this.stage !== 'schedule') return false;
    this.schedule = schedule;
    this.stream = false;
    this.cameras = freshCameras();
    this.stage = schedule === 'live' ? 'camera-setup' : 'schedule-ready';
    const messages = {
      live: 'Live is optional content, not a household penalty. Choose up to three camera views.',
      edited: 'Edited Update uses a work slot only if you choose Edit. No live camera setup is needed.',
      offline: 'Offline selected. No camera or chat; every household chore stays available.'
    };
    this.notice = messages[schedule];
    this.emit('game:schedule', { day: this.dayNumber, schedule });
    return true;
  }

  toggleCamera(zone: CameraZone) {
    if (this.stage !== 'camera-setup' || !CAMERA_ZONES.includes(zone)) return false;
    if (!this.cameras[zone] && this.cameraCount() >= MAX_LIVE_CAMERAS) {
      this.notice = 'Three views maximum. Turn one off before selecting another.';
      return false;
    }
    this.cameras[zone] = !this.cameras[zone];
    const privateZone = zone === 'private-room';
    this.notice = privateZone && this.cameras[zone]
      ? 'PRIVATE ROOM selected. This explicitly changes the boundary; it will be visible in the report.'
      : CAMERA_LABELS[zone] + (this.cameras[zone] ? ' included in the live frame.' : ' removed from the live frame.');
    this.emit('game:camera', { day: this.dayNumber, zone, active: this.cameras[zone], isPrivate: privateZone });
    return this.cameras[zone];
  }

  cameraCount() { return CAMERA_ZONES.filter(zone => this.cameras[zone]).length; }

  cameraSummary() {
    const active = CAMERA_ZONES.filter(zone => this.cameras[zone]).map(zone => CAMERA_LABELS[zone]);
    return (active.length ? 'On-air: ' + active.join(', ') + '. ' : 'No camera selected. ') +
      'Private room is off by default and only appears if you explicitly select it.';
  }

  startDay() {
    if (this.stage !== 'camera-setup' && this.stage !== 'schedule-ready') return false;
    if (!this.schedule || (this.schedule === 'live' && this.cameraCount() === 0)) {
      this.notice = 'Choose at least one view before starting Live.';
      return false;
    }
    this.stream = this.schedule === 'live';
    this.privateExposureThisDay = this.stream && this.cameras['private-room'];
    this.privateExposureChargedToday = false;
    this.daySettled = false;
    this.eventNote = '';
    this.stormActive = this.dayNumber === 4;
    if (this.dayNumber === 4 && !this.stormApplied) {
      this.stormApplied = true;
      this.emit('game:day-start', { day: this.dayNumber, schedule: this.schedule, cameras: this.cameraCount(), seed: this.seed });
      this.coop = clamp(this.coop - 18, 0, 100);
      this.well = clamp(this.well - 16, 0, 100);
      this.garden = clamp(this.garden - 4, 0, 100);
      this.eventNote = 'Storm damage: coop −18, well −16, garden −4.';
      this.stage = 'storm-choice';
      this.notice = 'STORM DAY. The coop roof and water system need work. Review the sponsor and community options; neither is required.';
      this.emit('game:storm', { day: this.dayNumber, coopDamage: 18, wellDamage: 16, gardenDamage: 4, seed: this.seed });
      return true;
    }
    this.enterDailyEvent();
    this.emit('game:day-start', { day: this.dayNumber, schedule: this.schedule, cameras: this.cameraCount(), seed: this.seed });
    return true;
  }

  toggleStream() {
    if (this.stage !== 'tasks' || this.schedule !== 'live') return false;
    this.stream = !this.stream;
    if (this.stream && this.cameras['private-room']) this.privateExposureThisDay = true;
    this.notice = this.stream ? 'Live resumed. The work continues.' : 'Stream off. Every chore remains available.';
    this.emit('game:stream', { day: this.dayNumber, on: this.stream });
    return this.stream;
  }

  cameraActive(zone: CameraZone) { return this.cameras[zone]; }

  canJob(job: Job) {
    if (this.stage !== 'tasks' || this.slotsUsed >= 3) return false;
    if (job === 'sponsor' || job === 'community') return false;
    if (job === 'edit' && this.schedule !== 'edited') return false;
    if (job === 'moderate' && (this.schedule !== 'live' || this.audience <= 0)) return false;
    if (job === 'feed' && this.feed < 1) return false;
    if (job === 'repair' && this.boards < 1) return false;
    if (job === 'tend-garden' && this.water < 1) return false;
    if (job === 'draw-water' && this.water >= 4) return false;
    if (job === 'cook' && this.food < 1) return false;
    return this.energy >= this.energyCost(job);
  }

  energyCost(job: Job) {
    const base: Record<Job, number> = {
      feed: 6, repair: 12, 'tend-garden': 7, 'draw-water': 5, cook: 5, edit: 5,
      moderate: 6, rest: 0, sponsor: SPONSOR_TERMS.energy, community: 0
    };
    const reduction = this.tipReady && (job === 'feed' || job === 'repair') ? 5 : 0;
    return Math.max(0, base[job] - reduction);
  }

  startJob(job: Exclude<Job, 'sponsor' | 'community'>) {
    if (!this.canJob(job)) {
      this.notice = this.unavailableReason(job);
      return false;
    }
    const energyCost = this.energyCost(job);
    if (this.tipReady && (job === 'feed' || job === 'repair')) this.tipReady = false;
    const targets: Record<Job, number> = {
      feed: 236, repair: 145, 'tend-garden': 274, 'draw-water': 343, cook: 472,
      edit: 456, moderate: 456, rest: 472, sponsor: 515, community: 360
    };
    this.animation = { job, elapsed: 0, duration: this.reducedMotion ? 0.2 : 1.5, fromX: this.actorX, toX: targets[job], energyCost };
    this.stage = 'animating';
    const names: Record<Job, string> = {
      feed: 'Feed the hens', repair: 'Repair the coop', 'tend-garden': 'Tend the garden',
      'draw-water': 'Draw water', cook: 'Cook a meal', edit: 'Edit the update',
      moderate: 'Moderate the chat', rest: 'Take a break', sponsor: 'Sponsor feature',
      community: 'Ask for bounded help'
    };
    this.notice = names[job] + '…';
    this.emit('game:task-start', { day: this.dayNumber, job, energyCost, slot: this.slotsUsed + 1 });
    return true;
  }

  resolveViewerMessage(useTip: boolean) {
    if (this.stage !== 'message') return false;
    this.messageResolved = true;
    this.tipReady = useTip;
    this.eventNote = useTip ? 'Saved the viewer tip: next feed or repair costs 5 less energy.' : 'Viewer message hidden.';
    this.notice = this.eventNote;
    this.emit('game:practical-tip', { day: this.dayNumber, source: this.schedule === 'offline' ? 'neighbor-note' : 'fictional-viewer', action: useTip ? 'tip-used' : 'hidden', energyDiscount: useTip ? 5 : 0 });
    this.stage = 'tasks';
    return true;
  }

  chooseTomato(choice: 'keep' | 'reframe' | 'hide' | 'stop' | 'private' | 'plan') {
    if (this.stage !== 'tomato') return false;
    const liveCapture = this.schedule === 'live' && this.stream && this.cameras.garden;
    const editedRecap = this.schedule === 'edited';
    this.tomatoChoice = choice;
    if (editedRecap) {
      const labels = {
        keep: 'Tomato clip queued for the edited recap.',
        reframe: 'A tighter garden crop queued for the edited recap.',
        hide: 'Tomato clip marked to omit from the recap.',
        stop: 'Post marked to skip; no tomato clip will be published.',
        private: 'The tomato setback stayed private.',
        plan: 'Garden repair added to the day plan.'
      };
      this.eventNote = labels[choice] + ' It only affects audience or boundaries if an Edit work slot publishes the recap.';
    } else if (choice === 'keep' && liveCapture) {
      this.audience += 8;
      this.boundaries = clamp(this.boundaries - 8, 0, 100);
      this.eventNote = 'Tomato moment kept in the live frame: +8 audience, −8 boundaries.';
    } else if (choice === 'reframe' && liveCapture) {
      this.audience += 4;
      this.eventNote = 'The frame was narrowed to the garden: +4 audience, no boundary change.';
    } else if (choice === 'hide' && liveCapture) {
      this.audience = Math.max(0, this.audience - 2);
      this.eventNote = 'Comments hidden and tomato moment omitted: −2 audience, no boundary change.';
    } else if (choice === 'stop' && liveCapture) {
      this.stream = false;
      this.audience = Math.max(0, this.audience - 3);
      this.eventNote = 'The live camera stopped: −3 audience, no boundary change. The garden still needs attention.';
    } else if (choice === 'private' || choice === 'plan') {
      this.eventNote = choice === 'private' ? 'The tomato setback stayed private.' : 'Garden repair added to the day plan.';
    } else {
      this.eventNote = 'No garden footage was available; the setback remains a household task.';
    }
    this.tomatoActive = false; this.tomatoResolved = true; this.stage = 'tasks'; this.notice = this.eventNote;
    this.emit('game:tomato-choice', { day: this.dayNumber, choice, captured: liveCapture, deferredUntilEdit: editedRecap, schedule: this.schedule });
    return true;
  }

  chooseStorm(choice: 'sponsor' | 'community' | 'decline') {
    if (this.stage !== 'storm-choice') return false;
    this.stormResolved = true;
    if (choice === 'decline') {
      this.eventNote += ' Sponsor declined; the player can use ordinary jobs to repair privately.';
      this.stage = 'tasks'; this.notice = this.eventNote;
      this.emit('game:storm-choice', { day: this.dayNumber, choice });
      return true;
    }
    if (choice === 'sponsor' && this.slotsUsed < 3 && this.energy >= SPONSOR_TERMS.energy) {
      this.privateRevealActive = true;
      this.privateRoomShared = true;
      this.privateExposureChargedToday = true;
      this.animation = { job: 'sponsor', elapsed: 0, duration: this.reducedMotion ? 0.2 : 1.5, fromX: this.actorX, toX: 515, energyCost: SPONSOR_TERMS.energy };
      this.stage = 'animating';
      this.notice = 'Sponsor feature accepted. The private-room cutaway is brief and explicitly authorized.';
      this.emit('game:sponsor-accepted', { day: this.dayNumber, ...SPONSOR_TERMS, privateRoomAuthorized: true, slotsUsed: this.slotsUsed + 1 });
      return true;
    }
    if (choice === 'community' && this.slotsUsed < 3) {
      this.animation = { job: 'community', elapsed: 0, duration: this.reducedMotion ? 0.2 : 1.2, fromX: this.actorX, toX: 360, energyCost: 0 };
      this.stage = 'animating';
      this.notice = 'Bounded request sent: specific repair supplies, no address, no private footage.';
      this.emit('game:community-request', { day: this.dayNumber, slotsUsed: this.slotsUsed + 1 });
      return true;
    }
    this.notice = this.slotsUsed >= 3 ? 'No work slots remain. Decline the request and repair privately.' : 'Not enough energy for that request. Decline it and repair privately.';
    return false;
  }

  finishDay() {
    if (this.stage !== 'tasks') return false;
    this.settleDay();
    this.stage = 'report';
    this.notice = 'Day ' + this.dayNumber + ' report. Review what changed before moving on.';
    this.emit('game:day-report', { day: this.dayNumber, schedule: this.schedule, jobs: [...this.jobsToday], score: this.score() });
    return true;
  }

  continueReport() {
    if (this.stage !== 'report') return false;
    if (this.dayNumber < 5) {
      this.dayNumber++;
      this.prepareDay();
      this.stage = 'schedule';
      this.notice = 'Day ' + this.dayNumber + ' of 5. Plan the next household day.';
      return true;
    }
    this.stage = 'cadence';
    this.notice = 'Five days complete. Choose the channel rhythm that fits this household.';
    return true;
  }

  chooseCadence(cadence: Ending) {
    if (this.stage !== 'cadence') return false;
    this.cadence = cadence;
    const home = this.homeCondition();
    this.ending = home < 40 || this.energy < 18 ? 'recovery-plan' : cadence;
    const texts: Record<Ending, string> = {
      'always-on': 'The channel stays frequent. The week’s home and energy state tells whether that rhythm is sustainable.',
      'offline-morning': 'The couple keeps regular mornings for the homestead before anything goes live.',
      'shared-yard': 'The couple keeps sharing a few practical jobs with a bounded, helpful community.',
      'recovery-plan': 'The couple sets a repair and rest plan for the next week. No abrupt fail screen.'
    };
    this.endingText = texts[this.ending];
    this.zeroReaction = ZERO_REACTIONS[this.ending];
    this.stage = 'ending';
    this.notice = this.endingText;
    this.emit('game:ending', { ending: this.ending, chosenCadence: cadence, homestead: home, energy: this.energy });
    return true;
  }

  completeEnding() {
    if (this.stage !== 'ending') return false;
    this.stage = 'complete';
    this.notice = 'PAR-2 complete. The result is local; leaderboard handoff comes in PAR-5.';
    return true;
  }

  handleInput(action: string) {
    switch (action) {
      case 'ranked': return this.chooseMode('ranked');
      case 'practice': return this.chooseMode('practice');
      case 'live': return this.chooseSchedule('live');
      case 'edited': return this.chooseSchedule('edited');
      case 'offline': return this.chooseSchedule('offline');
      case 'camera-coop': return this.toggleCamera('coop');
      case 'camera-garden': return this.toggleCamera('garden');
      case 'camera-well': return this.toggleCamera('well');
      case 'camera-porch': return this.toggleCamera('porch');
      case 'camera-workbench': return this.toggleCamera('workbench');
      case 'camera-private': return this.toggleCamera('private-room');
      case 'begin-day': return this.startDay();
      case 'feed': return this.startJob('feed');
      case 'repair': return this.startJob('repair');
      case 'tend-garden': return this.startJob('tend-garden');
      case 'draw-water': return this.startJob('draw-water');
      case 'cook': return this.startJob('cook');
      case 'edit': return this.startJob('edit');
      case 'moderate': return this.startJob('moderate');
      case 'rest': return this.startJob('rest');
      case 'stream': return this.toggleStream();
      case 'use-tip': return this.resolveViewerMessage(true);
      case 'hide-message': return this.resolveViewerMessage(false);
      case 'tomato-keep': return this.chooseTomato('keep');
      case 'tomato-reframe': return this.chooseTomato('reframe');
      case 'tomato-hide': return this.chooseTomato('hide');
      case 'tomato-stop': return this.chooseTomato('stop');
      case 'tomato-private': return this.chooseTomato('private');
      case 'tomato-plan': return this.chooseTomato('plan');
      case 'storm-sponsor': return this.chooseStorm('sponsor');
      case 'storm-community': return this.chooseStorm('community');
      case 'storm-decline': return this.chooseStorm('decline');
      case 'finish-day': return this.finishDay();
      case 'continue-day': return this.continueReport();
      case 'cadence-always': return this.chooseCadence('always-on');
      case 'cadence-offline': return this.chooseCadence('offline-morning');
      case 'cadence-shared': return this.chooseCadence('shared-yard');
      case 'cadence-recovery': return this.chooseCadence('recovery-plan');
      case 'complete-ending': return this.completeEnding();
      case 'confirm':
        if (this.stage === 'mode') return this.chooseMode('ranked');
        if (this.stage === 'schedule') return this.chooseSchedule('offline');
        if (this.stage === 'camera-setup' || this.stage === 'schedule-ready') return this.startDay();
        if (this.stage === 'message') return this.resolveViewerMessage(false);
        if (this.stage === 'tomato') return this.chooseTomato('private');
        if (this.stage === 'storm-choice') return this.chooseStorm('decline');
        if (this.stage === 'tasks') return this.finishDay();
        if (this.stage === 'report') return this.continueReport();
        if (this.stage === 'ending') return this.completeEnding();
        return false;
      default: return false;
    }
  }

  update(dt: number) {
    this.time += Math.max(0, Math.min(0.1, dt));
    if (this.stage !== 'animating' || !this.animation) return;
    this.animation.elapsed = Math.min(this.animation.duration, this.animation.elapsed + Math.max(0, Math.min(0.1, dt)));
    const progress = this.animation.duration ? this.animation.elapsed / this.animation.duration : 1;
    const eased = progress * progress * (3 - 2 * progress);
    this.actorX = this.animation.fromX + (this.animation.toX - this.animation.fromX) * eased;
    if (progress >= 1) this.completeAnimation();
  }

  homeCondition() {
    return Math.round((this.home + this.coop + this.garden + this.well) / 4);
  }

  resourceMeter() {
    return this.resourceMeterFor(this.snapshot());
  }

  private resourceMeterFor(state: Snapshot) {
    return Math.round(clamp(2 * state.cash + 14 * state.boards + 5 * state.feed + 5 * state.water + 6 * state.food, 0, 100));
  }

  score() {
    return Math.round(this.homeCondition() * 0.3 + this.energy * 0.25 + this.boundaries * 0.25 + this.resourceMeter() * 0.2);
  }

  over() { return this.stage === 'complete'; }

  dayReportText() {
    if (!this.days.length) return 'No day has been completed yet.';
    const condition = (state: Snapshot) => Math.round((state.home + state.coop + state.garden + state.well) / 4);
    const delta = (before: number, after: number) => (after - before >= 0 ? '+' : '') + (after - before);
    const rows = this.days.map(d => {
      const jobText = d.jobs.length ? d.jobs.map(j => j.toUpperCase().replace('-', ' ')).join(', ') : 'No jobs selected';
      const homeBefore = condition(d.before);
      const supplyBefore = this.resourceMeterFor(d.before);
      return 'DAY ' + d.day + ' · ' + d.schedule.toUpperCase() + ' · ' + jobText +
        ' · HOME ' + homeBefore + '→' + d.after.homeCondition + ' (' + delta(homeBefore, d.after.homeCondition) + ')' +
        ' · ENERGY ' + d.before.energy + '→' + d.after.energy + ' (' + delta(d.before.energy, d.after.energy) + ')' +
        ' · BOUNDARIES ' + d.before.boundaries + '→' + d.after.boundaries + ' (' + delta(d.before.boundaries, d.after.boundaries) + ')' +
        ' · SUPPLIES ' + supplyBefore + '→' + d.after.supplies + ' (' + delta(supplyBefore, d.after.supplies) + ')' +
        ' · AUDIENCE ' + d.audience + (d.event ? ' · ' + d.event : '');
    });
    if (this.days.length === 5) {
      rows.push('FINAL · HOUSEHOLD ' + this.score() + '/100 · ZERO SCORE ' + RANKED_SCENARIO.zeroScore +
        ' · MODE ' + (this.mode === 'practice' ? 'PRACTICE' : 'RANKED SCENARIO') +
        ' · SEED ' + this.seed + ' · VERSION ' + RANKED_SCENARIO.scoreVersion +
        ' · ENDING ' + (this.ending || 'CHOICE PENDING').toUpperCase().replaceAll('-', ' ') +
        ' · AUDIENCE ' + this.audience + ' · LOCAL ONLY');
    }
    return rows.join('\n');
  }

  result(): Record<string, unknown> {
    const ending = this.ending || 'recovery-plan';
    const audienceModes = this.days.map(d => d.schedule.toUpperCase()).join('/');
    return {
      heading: ending.replaceAll('-', ' ').toUpperCase(),
      causeLine: 'Five-day report · ' + audienceModes + ' · ending: ' + ending.replaceAll('-', ' ') +
        ' · audience ' + this.audience + ' · Zero Score target ' + RANKED_SCENARIO.zeroScore,
      stats: {
        homestead: this.homeCondition(), energy: this.energy, boundaries: this.boundaries,
        supplies: this.resourceMeter(), actions: this.days.reduce((sum, d) => sum + d.jobs.length, 0)
      },
      scenario: RANKED_SCENARIO.id,
      scenarioSeed: this.seed,
      mode: this.mode === 'practice' ? 'practice' : 'ranked-local',
      rankedScenario: this.mode === 'ranked',
      practiceMode: this.mode === 'practice',
      leaderboardEligible: false,
      submissionReady: false,
      scoreVersion: RANKED_SCENARIO.scoreVersion,
      ending,
      audience: this.audience,
      zeroScoreTarget: RANKED_SCENARIO.zeroScore,
      zeroScoreBeaten: this.score() >= RANKED_SCENARIO.zeroScore,
      days: this.days.map(d => ({ day: d.day, schedule: d.schedule, jobs: d.jobs, event: d.event })),
      shareText: 'Five-day Paradise Offline run · ' + this.score() + ' household points · ' + ending.replaceAll('-', ' ') + ' · local only.'
    };
  }

  actorTarget() { return this.animation ? this.animation.toX : this.actorX; }

  private prepareDay() {
    this.schedule = null; this.stream = false; this.cameras = freshCameras();
    this.slotsUsed = 0; this.jobsToday = []; this.animation = null;
    this.hensFed = false; this.coopRepaired = false; this.gardenWatered = false; this.wellDrawn = false;
    this.privateRevealActive = false; this.privateExposureThisDay = false; this.privateExposureChargedToday = false;
    this.tipReady = false; this.messageResolved = false; this.tomatoResolved = this.dayNumber !== 3;
    this.stormResolved = this.dayNumber !== 4; this.daySettled = false; this.tomatoActive = false;
    this.stormActive = this.dayNumber === 4; this.tomatoChoice = null; this.dayBefore = this.snapshot();
  }

  private enterDailyEvent() {
    this.stage = 'tasks';
    if (this.dayNumber === 2 && !this.messageResolved) {
      this.stage = 'message';
      this.notice = this.schedule === 'offline'
        ? 'A fictional neighbor leaves a practical note. Use it or hide it; Offline has no chat or camera.'
        : 'One fictional viewer offers a practical tip. Use it or hide the message; there is no live chat.';
    } else if (this.dayNumber === 3 && !this.tomatoResolved) {
      this.stage = 'tomato'; this.tomatoActive = true;
      this.notice = 'TOMATO PROBLEM. A garden setback draws attention; choose what, if anything, becomes content.';
    } else {
      this.notice = 'Day ' + this.dayNumber + ' of 5 · choose up to three household jobs.';
    }
  }

  private energyCostForBase(job: Job) { return this.energyCost(job); }

  private unavailableReason(job: Job) {
    if (this.slotsUsed >= 3) return 'No work slots remain. End the day to see what changed.';
    if (job === 'feed' && this.feed < 1) return 'No feed remains; draw water, tend the garden, cook, rest or end the day.';
    if (job === 'repair' && this.boards < 1) return 'No boards remain. Ask for bounded help during the storm or choose another job.';
    if (job === 'tend-garden' && this.water < 1) return 'No water remains. Draw water first, then tend the garden.';
    if (job === 'cook' && this.food < 1) return 'No food is ready. Tend the garden before cooking.';
    if (job === 'moderate' && this.audience <= 0) return 'There is no audience message to moderate.';
    if (job === 'edit' && this.schedule !== 'edited') return 'Choose Edited Update to spend a slot editing.';
    if (job === 'rest') return 'Rest is available when you need it.';
    return 'Not enough energy for that job. Rest or end the day; neither ends the campaign.';
  }

  private snapshot(): Snapshot {
    return {
      home: this.home, coop: this.coop, garden: this.garden, well: this.well,
      energy: this.energy, boundaries: this.boundaries, cash: this.cash,
      boards: this.boards, feed: this.feed, water: this.water, food: this.food
    };
  }

  private settleDay() {
    if (this.daySettled || !this.schedule) return;
    if (this.privateExposureThisDay && !this.privateExposureChargedToday) {
      this.boundaries = clamp(this.boundaries - 12, 0, 100);
      this.privateRoomShared = true;
      this.eventNote += (this.eventNote ? ' ' : '') + 'Private-room camera was on air; boundaries −12.';
    }
    this.daySettled = true;
    const after = this.snapshot();
    this.days.push({
      day: this.dayNumber, schedule: this.schedule, jobs: [...this.jobsToday],
      event: this.eventNote, before: this.dayBefore, after: {
        ...after, homeCondition: this.homeCondition(), supplies: this.resourceMeter()
      } as Snapshot & { homeCondition: number; supplies: number }, audience: this.audience
    });
  }

  private completeAnimation() {
    const animation = this.animation;
    if (!animation) return;
    this.actorX = animation.toX;
    this.animation = null;
    this.slotsUsed++;
    this.jobsToday.push(animation.job);
    this.energy = clamp(this.energy - animation.energyCost, 0, 100);
    const amount = (value: number, delta: number) => clamp(value + delta, 0, 100);
    if (animation.job === 'sponsor') {
      this.cash += SPONSOR_TERMS.cash; this.boards += SPONSOR_TERMS.boards;
      this.boundaries = amount(this.boundaries, -SPONSOR_TERMS.boundaryLoss);
      this.audience += SPONSOR_TERMS.audience; this.privateRevealActive = false;
      this.privateExposureChargedToday = true;
      this.eventNote += ' Sponsor accepted: +$16, +2 boards, +6 audience, −6 energy, −18 boundaries.';
      this.notice = 'The brief cutaway is over. The terms and boundary change remain in the report.';
      this.emit('game:sponsor-complete', { day: this.dayNumber, slotsUsed: this.slotsUsed });
    } else if (animation.job === 'community') {
      this.boards += 1; this.feed += 1; this.water += 1; this.audience += 3;
      this.boundaries = amount(this.boundaries, 1);
      this.eventNote += ' Bounded community request: +1 board, +1 feed, +1 water, +3 audience, +1 boundary.';
      this.notice = 'Specific help received; no home address or private footage was shared.';
      this.emit('game:community-help', { day: this.dayNumber, slotsUsed: this.slotsUsed });
    } else if (animation.job === 'feed') {
      this.feed--; this.coop = amount(this.coop, 10); this.home = amount(this.home, 2);
      this.hensFed = true; this.notice = 'Hens fed. Their coop and the homestead improved.';
    } else if (animation.job === 'repair') {
      this.boards--; this.coop = amount(this.coop, 22); this.home = amount(this.home, 3);
      this.coopRepaired = true; this.notice = 'Coop repaired. The roof state is visible on the yard map.';
    } else if (animation.job === 'tend-garden') {
      this.water--; this.garden = amount(this.garden, 12); this.food++;
      this.gardenWatered = true; this.notice = 'Garden watered and tended. Food is ready to use.';
    } else if (animation.job === 'draw-water') {
      this.well = amount(this.well, 18); this.water = Math.min(4, this.water + 1);
      this.wellDrawn = true; this.notice = 'Well drawn. The water supply and well condition improved.';
    } else if (animation.job === 'cook') {
      this.food--; this.energy = amount(this.energy, 10); this.home = amount(this.home, 4);
      this.notice = 'Meal cooked. Food was used and energy recovered.';
    } else if (animation.job === 'edit') {
      this.audience += 5; this.boundaries = amount(this.boundaries, 3);
      if (this.dayNumber === 3 && this.tomatoChoice) {
        const edits = {
          keep: { audience: 5, boundaries: -2, note: ' Tomato included in recap (+5 audience, −2 boundaries).' },
          reframe: { audience: 3, boundaries: 0, note: ' Tomato reframed to the garden (+3 audience, no boundary change).' },
          hide: { audience: 0, boundaries: 0, note: ' Tomato omitted from recap (no audience or boundary change).' },
          stop: { audience: 0, boundaries: 0, note: ' Update skipped; tomato stayed private (no audience or boundary change).' },
          private: { audience: 0, boundaries: 0, note: ' Tomato stayed private.' },
          plan: { audience: 0, boundaries: 0, note: ' Garden repair stays on the household plan.' }
        } as const;
        const outcome = edits[this.tomatoChoice];
        this.audience += outcome.audience;
        this.boundaries = amount(this.boundaries, outcome.boundaries);
        this.eventNote += outcome.note;
      }
      this.notice = 'Edited public chores into a short update. Private footage stayed out.';
    } else if (animation.job === 'moderate') {
      this.audience = Math.max(0, this.audience - 2); this.boundaries = amount(this.boundaries, 6);
      this.notice = 'Chat moderated. Task directions and chores remain visible.';
    } else if (animation.job === 'rest') {
      this.energy = amount(this.energy, 20); this.notice = 'Rest complete. Energy recovered; the campaign continues.';
    }
    this.emit('game:task-complete', { day: this.dayNumber, job: animation.job, slotsUsed: this.slotsUsed, energy: this.energy });
    this.stage = 'tasks';
    if (this.slotsUsed >= 3) this.finishDay();
  }
}
