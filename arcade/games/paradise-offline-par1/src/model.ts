export type Schedule = 'live' | 'offline' | null;
export type CameraZone = 'coop' | 'garden' | 'porch';
export type Job = 'feed' | 'repair' | 'rest' | 'sponsor';
export type Stage = 'schedule' | 'camera-setup' | 'offline-ready' | 'tasks' | 'message' | 'sponsor' | 'animating' | 'report' | 'complete';

type Signal = (name: string, detail?: Record<string, unknown>) => void;

export const CAMERA_ZONES: readonly CameraZone[] = ['coop', 'garden', 'porch'];
export const CAMERA_LABELS: Record<CameraZone, string> = {
  coop: 'COOP CAM',
  garden: 'GARDEN CAM',
  porch: 'PORCH CAM'
};
export const SPONSOR_TERMS = {
  cash: 12,
  boards: 1,
  energy: 8,
  boundaryLoss: 25
} as const;

type Snapshot = { home: number; energy: number; boundaries: number; cash: number; boards: number; feed: number };
type Animation = { job: Job; elapsed: number; duration: number; fromX: number; toX: number; energyCost: number };

const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(high, value));
const freshCameras = (): Record<CameraZone, boolean> => ({ coop: false, garden: false, porch: false });

export class ParadiseDay {
  stage: Stage = 'schedule';
  schedule: Schedule = null;
  stream = false;
  cameras = freshCameras();
  home = 54;
  coop = 38;
  energy = 76;
  boundaries = 100;
  cash = 8;
  boards = 1;
  feed = 1;
  audience = 0;
  workActions = 0;
  slotsUsed = 0;
  usedJobs = new Set<Job>();
  animation: Animation | null = null;
  actorX = 455;
  time = 0;
  notice = 'Choose a schedule. Camera-off work stays available.';
  messageResolved = false;
  tipReady = false;
  sponsorResolved = false;
  sponsorAccepted = false;
  privateRoomShared = false;
  privateRevealActive = false;
  hensFed = false;
  coopRepaired = false;
  reducedMotion: boolean;
  private startSnapshot: Snapshot = { home: 54, energy: 76, boundaries: 100, cash: 8, boards: 1, feed: 1 };

  constructor(public seed = 1, reducedMotion = false, private emit: Signal = () => {}) {
    this.reducedMotion = reducedMotion;
  }

  reset(seed = this.seed) {
    this.seed = Number.isFinite(seed) ? seed | 0 : 1;
    this.stage = 'schedule';
    this.schedule = null;
    this.stream = false;
    this.cameras = freshCameras();
    this.home = 54; this.coop = 38; this.energy = 76; this.boundaries = 100;
    this.cash = 8; this.boards = 1; this.feed = 1; this.audience = 0;
    this.workActions = 0; this.slotsUsed = 0; this.usedJobs.clear();
    this.animation = null; this.actorX = 455; this.time = 0;
    this.notice = 'Choose a schedule. Camera-off work stays available.';
    this.messageResolved = false; this.tipReady = false;
    this.sponsorResolved = false; this.sponsorAccepted = false;
    this.privateRoomShared = false; this.privateRevealActive = false;
    this.hensFed = false; this.coopRepaired = false;
    this.startSnapshot = this.snapshot();
  }

  setReducedMotion(value: boolean) {
    this.reducedMotion = value;
  }

  chooseSchedule(schedule: Exclude<Schedule, null>) {
    if (this.stage !== 'schedule') return false;
    this.schedule = schedule;
    this.stream = false;
    this.stage = schedule === 'live' ? 'camera-setup' : 'offline-ready';
    this.notice = schedule === 'live'
      ? 'Choose the public yard views. The private room stays outside every camera zone.'
      : 'Offline Day selected. No cameras or chat are needed; every chore is still available.';
    this.emit('game:schedule', { schedule });
    return true;
  }

  toggleCamera(zone: CameraZone) {
    if (this.stage !== 'camera-setup' || !CAMERA_ZONES.includes(zone)) return false;
    this.cameras[zone] = !this.cameras[zone];
    this.notice = CAMERA_LABELS[zone] + (this.cameras[zone] ? ' added to the live frame.' : ' removed from the live frame.');
    this.emit('game:camera', { zone, active: this.cameras[zone], privateRoomCovered: false });
    return this.cameras[zone];
  }

  cameraCount() {
    return CAMERA_ZONES.filter(zone => this.cameras[zone]).length;
  }

  cameraSummary() {
    const active = CAMERA_ZONES.filter(zone => this.cameras[zone]).map(zone => CAMERA_LABELS[zone]);
    return (active.length ? 'On-air zones: ' + active.join(', ') + '. ' : 'No yard camera selected. ') +
      'Private room: marked PRIVATE; no selected camera covers it.';
  }

  startDay() {
    if (this.stage !== 'camera-setup' && this.stage !== 'offline-ready') return false;
    if (this.schedule === 'live' && this.cameraCount() === 0) {
      this.notice = 'Choose at least one yard camera before going live.';
      return false;
    }
    if (!this.schedule) return false;
    this.startSnapshot = this.snapshot();
    this.stream = this.schedule === 'live';
    this.stage = 'tasks';
    this.notice = this.stream
      ? 'LIVE. Three work slots. You can stop the stream without losing any chore.'
      : 'OFFLINE. Three work slots. Every chore remains available.';
    this.emit('game:day-start', { schedule: this.schedule, cameras: this.cameraCount(), seed: this.seed });
    return true;
  }

  toggleStream() {
    if (this.stage !== 'tasks' || this.schedule !== 'live') return false;
    this.stream = !this.stream;
    this.notice = this.stream
      ? 'Stream on. Only the selected yard zones are visible.'
      : 'Stream off. The yard work continues; no job has been removed.';
    this.emit('game:stream', { on: this.stream });
    if (this.stream) this.routeAfterAction();
    return this.stream;
  }

  canJob(job: Job) {
    if (this.stage !== 'tasks' || this.slotsUsed >= 3 || this.usedJobs.has(job)) return false;
    if (job === 'feed') return this.feed > 0;
    if (job === 'repair') return this.boards > 0;
    if (job === 'rest') return this.energy < 100;
    return false;
  }

  startJob(job: Exclude<Job, 'sponsor'>) {
    if (!this.canJob(job)) {
      this.notice = job === 'feed' && this.feed === 0 ? 'No feed remains today. Choose another job or finish the day.' :
        job === 'repair' && this.boards === 0 ? 'No roof boards remain. Choose another job or finish the day.' :
        job === 'rest' && this.energy >= 100 ? 'Energy is already full. Choose another job or finish the day.' :
        'That job is not available right now.';
      return false;
    }
    const baseCost = job === 'feed' ? 8 : job === 'repair' ? 14 : 0;
    const energyCost = baseCost > 0 && this.tipReady ? Math.max(0, baseCost - 5) : baseCost;
    if (energyCost > 0 && this.tipReady) this.tipReady = false;
    const targets: Record<Exclude<Job, 'sponsor'>, number> = { feed: 236, repair: 145, rest: 472 };
    const duration = this.reducedMotion ? 0.24 : 1.65;
    this.animation = { job, elapsed: 0, duration, fromX: this.actorX, toX: targets[job], energyCost };
    this.stage = 'animating';
    this.notice = job === 'feed' ? 'Walking to the coop with the feed bucket…' :
      job === 'repair' ? 'Walking to the loose coop hinge with a roof board…' :
      'Taking a short porch break…';
    this.emit('game:task-start', { job, energyCost, slot: this.slotsUsed + 1 });
    return true;
  }

  resolveViewerMessage(useTip: boolean) {
    if (this.stage !== 'message') return false;
    this.messageResolved = true;
    this.tipReady = useTip;
    this.notice = useTip
      ? 'Tip saved: your next feed or repair task costs 5 less energy.'
      : 'Message hidden. The task list stays available.';
    this.emit('game:viewer-message', { action: useTip ? 'tip-used' : 'hidden' });
    this.routeAfterAction();
    return true;
  }

  acceptSponsor() {
    if (this.stage !== 'sponsor' || this.slotsUsed >= 3) return false;
    this.sponsorResolved = true;
    this.privateRoomShared = true;
    this.privateRevealActive = true;
    this.animation = {
      job: 'sponsor', elapsed: 0, duration: this.reducedMotion ? 0.24 : 1.1,
      fromX: this.actorX, toX: 515, energyCost: SPONSOR_TERMS.energy
    };
    this.stage = 'animating';
    this.notice = 'You accepted the stated terms. The short room-tour cutaway is on air by your choice.';
    this.emit('game:sponsor-accepted', {
      cash: SPONSOR_TERMS.cash, boards: SPONSOR_TERMS.boards, energy: SPONSOR_TERMS.energy,
      boundaryLoss: SPONSOR_TERMS.boundaryLoss, privacyChangedByPlayer: true
    });
    return true;
  }

  declineSponsor() {
    if (this.stage !== 'sponsor') return false;
    this.sponsorResolved = true;
    this.notice = 'Offer declined. No penalty; the private room stays private.';
    this.emit('game:sponsor-declined');
    this.routeAfterAction();
    return true;
  }

  finishDay() {
    if (this.stage !== 'tasks') return false;
    this.stage = 'report';
    this.notice = 'Day one report. Review the household changes before leaving the slice.';
    this.emit('game:day-report', { schedule: this.schedule, jobs: this.workActions, sponsorAccepted: this.sponsorAccepted });
    return true;
  }

  completeReport() {
    if (this.stage !== 'report') return false;
    this.stage = 'complete';
    this.notice = 'PAR-1 slice complete. This result is local and unranked.';
    return true;
  }

  handleInput(action: string) {
    switch (action) {
      case 'live': return this.chooseSchedule('live');
      case 'offline': return this.chooseSchedule('offline');
      case 'camera-coop': return this.toggleCamera('coop');
      case 'camera-garden': return this.toggleCamera('garden');
      case 'camera-porch': return this.toggleCamera('porch');
      case 'begin-day': return this.startDay();
      case 'feed': return this.startJob('feed');
      case 'repair': return this.startJob('repair');
      case 'rest': return this.startJob('rest');
      case 'stream': return this.toggleStream();
      case 'use-tip': return this.resolveViewerMessage(true);
      case 'hide-message': return this.resolveViewerMessage(false);
      case 'accept-sponsor': return this.acceptSponsor();
      case 'decline-sponsor': return this.declineSponsor();
      case 'finish-day': return this.finishDay();
      case 'complete-report': return this.completeReport();
      case 'confirm':
        if (this.stage === 'camera-setup' || this.stage === 'offline-ready') return this.startDay();
        if (this.stage === 'message') return this.resolveViewerMessage(false);
        if (this.stage === 'sponsor') return this.declineSponsor();
        if (this.stage === 'tasks') return this.finishDay();
        if (this.stage === 'report') return this.completeReport();
        return false;
      default: return false;
    }
  }

  update(dt: number) {
    if (this.stage !== 'animating' || !this.animation) return;
    this.time += Math.max(0, Math.min(0.1, dt));
    this.animation.elapsed = Math.min(this.animation.duration, this.animation.elapsed + Math.max(0, Math.min(0.1, dt)));
    const progress = this.animation.duration ? this.animation.elapsed / this.animation.duration : 1;
    const eased = progress * progress * (3 - 2 * progress);
    this.actorX = this.animation.fromX + (this.animation.toX - this.animation.fromX) * eased;
    if (progress >= 1) this.completeAnimation();
  }

  score() {
    const supplies = this.resourceMeter();
    return Math.round(this.home * 0.3 + this.energy * 0.25 + this.boundaries * 0.25 + supplies * 0.2);
  }

  resourceMeter() {
    return Math.round(clamp(this.cash * 4 + this.boards * 18 + this.feed * 12, 0, 100));
  }

  over() {
    return this.stage === 'complete';
  }

  reportData() {
    return {
      before: { ...this.startSnapshot },
      after: this.snapshot(),
      jobs: this.workActions,
      slots: this.slotsUsed,
      schedule: this.schedule === 'live' ? 'Live' : 'Offline',
      streamWasUsed: this.schedule === 'live' && this.stream,
      sponsor: this.sponsorAccepted
        ? 'Accepted: the player chose to share one short private-room cutaway.'
        : this.sponsorResolved ? 'Declined: the private room stayed private.' : 'No sponsor offer was shown.',
      privateRoomShared: this.privateRoomShared
    };
  }

  result(): Record<string, unknown> {
    const report = this.reportData();
    const delta = (current: number, before: number) => {
      const difference = current - before;
      return (difference >= 0 ? '+' : '−') + Math.abs(difference);
    };
    const startResources = '$' + report.before.cash + ', ' + report.before.boards + ' boards, ' + report.before.feed + ' feed';
    const endResources = '$' + report.after.cash + ', ' + report.after.boards + ' boards, ' + report.after.feed + ' feed';
    const scheduleLabel = this.schedule === 'live' ? 'LIVE' : 'OFFLINE';
    return {
      heading: 'DAY ONE COMPLETE',
      causeLine: scheduleLabel + ' schedule · home ' + delta(report.after.home, report.before.home) +
        ' · energy ' + delta(report.after.energy, report.before.energy) +
        ' · boundaries ' + delta(report.after.boundaries, report.before.boundaries) +
        ' · supplies ' + startResources + ' → ' + endResources,
      stats: {
        homestead: this.home, energy: this.energy, boundaries: this.boundaries,
        supplies: this.resourceMeter(), actions: this.slotsUsed
      },
      scenario: 'welcome-yard-day-1',
      scenarioSeed: this.seed,
      mode: 'par1-local-prototype',
      scoreVersion: 'par1-prototype-v1',
      leaderboardEligible: false,
      practiceMode: true,
      sponsorAccepted: this.sponsorAccepted,
      privateRoomShared: this.privateRoomShared,
      shareText: 'I finished one local, unranked day in the Paradise Offline prototype: ' + this.score() + ' household points.'
    };
  }

  actorTarget() {
    return this.animation ? this.animation.toX : this.actorX;
  }

  private completeAnimation() {
    const animation = this.animation;
    if (!animation) return;
    this.actorX = animation.toX;
    this.animation = null;
    if (animation.job === 'sponsor') {
      this.slotsUsed++;
      this.cash += SPONSOR_TERMS.cash;
      this.boards += SPONSOR_TERMS.boards;
      this.energy = clamp(this.energy - SPONSOR_TERMS.energy, 0, 100);
      this.boundaries = clamp(this.boundaries - SPONSOR_TERMS.boundaryLoss, 0, 100);
      this.audience += 10;
      this.sponsorAccepted = true;
      this.privateRevealActive = false;
      this.notice = 'Sponsor cutaway complete. The room closes; the report records the boundary change.';
      this.emit('game:privacy-shared', { boundary: this.boundaries, oneTimeCutaway: true });
      this.emit('game:task-complete', { job: 'sponsor', slotsUsed: this.slotsUsed });
      this.routeAfterAction();
      return;
    }

    this.slotsUsed++;
    this.workActions++;
    this.usedJobs.add(animation.job);
    this.energy = clamp(this.energy - animation.energyCost, 0, 100);
    if (animation.job === 'feed') {
      this.feed--; this.coop = clamp(this.coop + 18, 0, 100); this.home = clamp(this.home + 8, 0, 100);
      this.hensFed = true; this.notice = 'Hens fed. The coop is steadier and the feed count changed.';
    } else if (animation.job === 'repair') {
      this.boards--; this.coop = clamp(this.coop + 30, 0, 100); this.home = clamp(this.home + 22, 0, 100);
      this.coopRepaired = true; this.notice = 'Loose coop hinge braced. The repaired state is visible on the yard map.';
    } else {
      this.energy = clamp(this.energy + 20, 0, 100);
      this.notice = 'Rest complete. Energy recovered; the rest of the day remains yours.';
    }
    this.emit('game:task-complete', { job: animation.job, slotsUsed: this.slotsUsed, energy: this.energy });
    this.routeAfterAction();
  }

  private routeAfterAction() {
    if (this.schedule === 'live' && this.stream && this.workActions >= 1 && !this.messageResolved) {
      this.stage = 'message';
      this.notice = 'One fictional viewer has a practical tip. Use it or hide the message.';
      this.emit('game:viewer-tip', { energyDiscount: 5 });
      return;
    }
    if (this.schedule === 'live' && this.stream && this.workActions >= 2 && !this.sponsorResolved) {
      this.stage = 'sponsor';
      this.notice = 'A fictional sponsor asks for one bounded, clearly priced cutaway. Review every term first.';
      this.emit('game:sponsor-offer', { ...SPONSOR_TERMS });
      return;
    }
    this.stage = this.slotsUsed >= 3 ? 'report' : 'tasks';
  }

  private snapshot(): Snapshot {
    return { home: this.home, energy: this.energy, boundaries: this.boundaries, cash: this.cash, boards: this.boards, feed: this.feed };
  }
}
