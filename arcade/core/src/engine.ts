import { readLocal, writeLocal } from './storage';
import { bindPositionInput, fitViewport, showPanel, synthesize, type CartridgeProfile, type Presentation } from './cartridge';

export type GameAPI = {
  start(): void;
  update(dt: number): void;
  draw(ctx: CanvasRenderingContext2D, width: number, height: number): void;
  input(key: string, down: boolean, atMs?: number, source?: string): void;
  score(): number;
  over(): boolean;
  setSkin?(url: string | null): void | Promise<void>;
  setMoveAxis?(x: number, y: number): void;
  setPositionTarget?(fraction: number | null): void;
  releaseInput?(): void;
  result?(): Record<string, unknown>;
  presentation?(): Presentation;
  dispose?(): void;
  /** Optional hooks; older cartridges continue to use the original contract. */
  canStart?(): boolean;
  keyForCode?(code: string): string | undefined;
  onPause?(): void;
  onResume?(): void;
  onReset?(): void;
  setMuted?(muted: boolean): void;
  bestKey?(): string;
};

const tagControlsStyle=`
:host{--tag-pink:#ff2889}.top{gap:5px}.top button{font-size:10px;padding:5px;min-width:42px;min-height:38px;border:1px solid #f2e4ce;background:#251b30;color:#f2e4ce}.tag-deck{display:none}.overlay{background:#130c1bc9;padding:20px;gap:14px}.overlay h2{font:italic 900 clamp(20px,4vw,36px) sans-serif;margin:0}.overlay p{margin:0;line-height:1.4}.overlay button{background:#ff2889;border:2px solid #f4e6d0;color:#1c1024;border-radius:8px;font-weight:900;min-height:46px}.overlay button:focus-visible,.top button:focus-visible{outline:3px solid #d3ed16;outline-offset:3px}:host([data-art-ready]) .top button{width:36px;min-width:36px!important;background-size:65% 65%;background-repeat:no-repeat;background-position:center;color:transparent!important}:host([data-art-ready]) .top [part=sound]{background-image:var(--tag-soundOff)}:host([data-art-ready][data-sound-on]) .top [part=sound]{background-image:var(--tag-soundOn)}:host([data-art-ready]) .top [part=pause]{background-image:var(--tag-pause)}:host([data-art-ready]) .top [part=settings]{background-image:var(--tag-settings)}:host([data-art-ready]) .overlay[data-phase=title] h2{background:var(--tag-title) center/contain no-repeat;color:transparent;text-shadow:none;width:min(500px,85vw);height:100px;max-width:95%;justify-self:center}.tag-settings{background:#24192e;color:#f3ead9;border:3px solid #ff2889;border-radius:12px;width:min(430px,85vw);padding:22px;box-sizing:border-box;font:14px/1.5 monospace}.tag-settings::backdrop{background:#110b17c9}.tag-settings h2{font:italic 900 22px sans-serif;color:#f3ead9}.tag-settings label{display:block;margin:15px 0}.tag-settings input:not([type=checkbox]),.tag-settings select{display:block;box-sizing:border-box;max-width:100%;width:100%;padding:9px;margin-top:5px;background:#110c19;color:#f4ebd5;border:1px solid #f4ebd5;font:16px monospace}.tag-settings input[type=checkbox]{width:22px;height:22px;vertical-align:middle}.tag-settings button{background:#ff2889;border:2px solid #f4e6d0;color:#160c20;margin:8px 8px 0 0;min-height:44px;font-size:12px}.tag-settings .tag-local{font-size:11px;color:#c9bdcc}.tag-error{color:#d8ed37}.tag-controls{position:relative!important;inset:auto!important;box-sizing:border-box;height:100%;width:100%;margin:0;display:grid;grid-template-columns:1fr 1fr;align-items:center;gap:10px;user-select:none;touch-action:none}.tag-stick{position:relative;justify-self:center;width:150px;height:132px;touch-action:none}.tag-stick-art{position:absolute;width:118px;height:118px;left:50%;top:50%;transform:translate(-50%,-50%);pointer-events:none;background:var(--tag-stick) center/contain no-repeat}.tag-knob{position:absolute;display:block;width:45px;height:45px;left:50%;top:50%;transform:translate(-50%,-50%);background:var(--tag-knob) center/contain no-repeat;border-radius:50%;pointer-events:none}.tag-controls .tag-dir{position:absolute;width:44px;height:44px;min-width:44px!important;min-height:44px;padding:0;border:0!important;background:transparent!important;color:#f4e8d0!important;font-size:19px;box-shadow:none!important;opacity:.9;border-radius:50%}.tag-dir[data-key=left]{left:4px;top:44px}.tag-dir[data-key=right]{right:4px;top:44px}.tag-dir[data-key=up]{left:53px;top:0}.tag-dir[data-key=down]{left:53px;bottom:0}.tag-controls .tag-spray{justify-self:center;width:110px;height:110px;min-width:110px!important;padding:0;border:0!important;outline-offset:1px;border-radius:50%;background:#ff2889;color:#190d20;box-shadow:none!important;font:bold 14px monospace;touch-action:none}:host([data-art-ready]) .tag-controls .tag-dir{color:transparent!important}:host([data-art-ready]) .tag-controls .tag-spray{background:var(--tag-spray) center/contain no-repeat;color:transparent!important}:host([data-art-ready]) .tag-controls .tag-spray:active{background-image:var(--tag-sprayPressed)}:host([data-left-handed]) .tag-controls{direction:rtl}:host([data-left-handed]) .tag-stick{direction:ltr}.tag-controls button:focus-visible{outline:3px solid #d3ef12!important}
@media(pointer:coarse){:host{display:grid!important;grid-template-rows:minmax(0,1fr) calc(152px + env(safe-area-inset-bottom));aspect-ratio:9/16!important;min-height:0!important;contain:layout style;overflow:hidden!important;touch-action:manipulation}:host([layout=portrait]){height:100%!important;aspect-ratio:auto!important}.screen{min-height:0;height:100%;overflow:hidden;touch-action:none}.tag-deck{display:block;min-height:0;background:#21162b;border-top:3px solid #ff2889;padding:2px 12px max(4px,env(safe-area-inset-bottom));box-sizing:border-box;touch-action:none}.tag-controls{display:grid!important}.top{top:5px;right:5px}.top button{min-width:36px;min-height:32px;font-size:9px}.overlay{padding:10px;gap:10px}.overlay h2{font-size:22px}.overlay p{font-size:12px;max-width:310px}.overlay button{min-height:42px;font-size:12px;padding:8px}:host([data-art-ready]) .overlay[data-phase=title] h2{width:90%;height:86px}}
@media(pointer:coarse) and (orientation:landscape){:host{aspect-ratio:16/9!important;grid-template-rows:minmax(0,1fr) calc(100px + env(safe-area-inset-bottom))}.tag-stick{height:90px;width:150px}.tag-stick-art{height:82px;width:82px}.tag-knob{width:32px;height:32px}.tag-controls .tag-dir{height:40px;min-height:40px;width:40px;min-width:40px!important}.tag-dir[data-key=left]{top:26px;left:10px}.tag-dir[data-key=right]{top:26px;right:10px}.tag-dir[data-key=up]{left:55px;top:-4px}.tag-dir[data-key=down]{left:55px;bottom:-4px}.tag-controls .tag-spray{width:85px;height:85px;min-width:85px!important}.overlay{gap:4px}:host([data-art-ready]) .overlay[data-phase=title] h2{height:52px}.overlay p{font-size:10px}.overlay button{min-height:32px;padding:4px}}
`;
const grindArtStyle=':host([data-au-art-ready]) .overlay[data-phase=title]{background-image:linear-gradient(0deg,rgba(12,8,16,.88),rgba(12,8,16,.24) 48%,rgba(12,8,16,.16)),var(--grind-title-art);background-position:center 48%;background-size:cover;background-repeat:no-repeat;border:2px solid #d7ff00}:host([data-au-art-ready]) .overlay[data-phase=over]{background-image:linear-gradient(0deg,rgba(12,8,16,.88),rgba(12,8,16,.38) 55%,rgba(12,8,16,.22)),var(--grind-over-art);background-position:center 68%;background-size:cover;background-repeat:no-repeat;border:2px solid #e0287a}:host([data-au-art-ready]) .deck{background-color:#1a111c;background-image:var(--grind-deck-art);background-position:center;background-size:100% 100%;background-repeat:no-repeat;border-top-color:#e0287a}:host([data-au-art-ready]) .deck .right-zone{justify-content:space-evenly;gap:0}:host([data-au-art-ready]) .deck .zero-zone{transform:translateY(32px)}:host([data-au-art-ready]) .deck .labeled{transform:translateY(36px)}:host([data-au-art-ready]) .deck .trick,:host([data-au-art-ready]) .deck .jump{align-self:center;margin:0}';
export function defineArcade(tag:string,label:string,create:(emit:(name:string,detail?:Record<string,unknown>)=>void,host:HTMLElement)=>GameAPI,profile?:CartridgeProfile){
 if(customElements.get(tag))return;
 class ArcadeElement extends HTMLElement{
  static get observedAttributes() { return profile ? ['skin', 'layout', 'orientation', 'label', 'muted', 'storage-key'] : ['skin']; }
  attributeChangedCallback(name: string, previous: string | null, next: string | null) {
    if (previous === next || !this.game || !this.isConnected) return;
    if (name === 'skin') this.loadSkin(next);
    if (!profile) return;
    if (name === 'orientation' || name === 'layout') this.resize();
    if (name === 'muted') this.muted = next === null || !['false', '0', 'off'].includes(next);
    if (name === 'storage-key') { this.readStorage(); this.refreshPanel(); }
    if (name === 'label') this.canvas.setAttribute('aria-label', next || label);
  }
  private lifetime = new AbortController();
  private skinSequence = 0;
  private readySent = false;
  private skinPending: Promise<void> = Promise.resolve();
  private releasePointer?: () => void;
  private gesture = false;
  private pauseClock = 0;
  private pausedMs = 0;
  private profilePad = new Set<number>();
  private idlePadTimer?: number;
  private storageKey(suffix: string) {
    const prefix = profile ? this.getAttribute('storage-key') || 'au-arcade' : 'au-arcade';
    const scoped = suffix === 'best' ? this.game?.bestKey?.() : undefined;
    return prefix + ':v1:' + tag + ':' + (scoped || suffix);
  }
  private readStorage() {
    const initialMute = !profile || !['false', '0', 'off'].includes(this.getAttribute('muted') || '');
    let best = 0, savedMute: string | null = null;
    best = Number(readLocal(this.storageKey('best'))) || 0;
    savedMute = readLocal(this.storageKey('muted'));
    this.bestScore = best;
    this.muted = savedMute === null ? initialMute : savedMute !== '0';
  }
  private notify(name: string, detail: Record<string, unknown> = {}, cancelable = false) {
    const identity = profile ? { game: tag, version: profile.version, skin: this.game?.presentation?.().id || 'placeholder' } : { game: tag };
    return this.dispatchEvent(new CustomEvent(name, { detail: { ...identity, ...detail }, bubbles: true, composed: true, cancelable }));
  }
  private refreshPanel() {
    const view = this.game?.presentation?.();
    if (profile && view) showPanel(this.shadowRoot!, this.phase, view.strings, this.game.score(), this.bestScore, this.game.result?.() || {}, profile.resultStats);
  }
  private loadSkin(url: string | null) {
    const sequence = ++this.skinSequence;
    this.skinPending = Promise.resolve(this.game.setSkin?.(url)).then(() => {
      if (!profile || sequence !== this.skinSequence || !this.isConnected) return;
      this.refreshPanel(); this.updateSoundLabel(); this.resize();
      if (!this.readySent) {
        this.readySent = true;
        this.notify('game:ready', { usingPlaceholder: this.game.presentation?.().id === 'placeholder' });
        if (this.hasAttribute('autostart') && this.phase === 'title') this.start();
      }
    });
  }
  setSkin(url: string | null) {
    if (url === null) this.removeAttribute('skin');
    else this.setAttribute('skin', url);
    return this.skinPending;
  }
  private canvas!:HTMLCanvasElement;private ctx!:CanvasRenderingContext2D;private game!:GameAPI;private frame=0;private last=0;private active=false;private paused=false;private live!:HTMLElement;private startButton!:HTMLButtonElement;private controls!:HTMLElement;private observer?:IntersectionObserver;private mutedValue=true;private resizeObserver?:ResizeObserver;private phase:'title'|'playing'|'paused'|'over'='title';private bestScore=0;private runStartedAt=0;private audio?:AudioContext;private padHeld:boolean[]=[false,false,false];private inputSources=new Map<string,Set<string>>();
  connectedCallback(){
   this.tabIndex=0;
   this.lifetime = new AbortController();
   const root = this.shadowRoot ?? this.attachShadow({mode:'open'});
   root.innerHTML=profile?.shell ?? `<style>:host{display:block;position:relative;aspect-ratio:16/9;min-height:220px;contain:content;background:#0d0b12;color:#f3f1eb;font:700 14px monospace;outline:none}:host(:focus-visible){outline:3px solid #ff3d7f}.screen{position:relative;width:100%;height:100%;overflow:hidden}canvas{display:block;width:100%;height:100%;touch-action:none;image-rendering:pixelated}button{background:#ff3d7f;color:#140b19;font:700 14px monospace;padding:12px;border:2px solid white;cursor:pointer;min-width:60px}.top{position:absolute;z-index:2;top:8px;right:8px;display:flex;gap:6px}.overlay{position:absolute;z-index:1;inset:0;background:#0b0b1594;display:grid;place-content:center;text-align:center;gap:10px;text-shadow:0 2px 4px #000}.controls{position:absolute;bottom:8px;left:8px;display:flex;gap:8px}.controls button{opacity:.82;touch-action:none}.deck{display:none}
@media(max-width:600px) and (pointer:coarse){
:host{display:grid!important;grid-template-rows:minmax(0,65fr) minmax(0,35fr);width:100%;aspect-ratio:9/16!important;min-height:0!important;height:auto!important;contain:layout style;overflow:hidden!important;user-select:none!important;-webkit-user-select:none!important;-webkit-touch-callout:none!important;touch-action:manipulation}:host([layout=portrait]){height:100%!important;aspect-ratio:auto!important}
.screen{height:100%;aspect-ratio:auto;min-height:0;min-width:0;touch-action:none;user-select:none;-webkit-user-select:none;-webkit-touch-callout:none}
.deck{display:grid;grid-template-columns:minmax(0,42fr) minmax(0,58fr);align-items:center;gap:0;box-sizing:border-box;min-height:0;height:100%;min-width:0;padding:12px 12px max(14px,env(safe-area-inset-bottom));touch-action:none;user-select:none;-webkit-user-select:none;-webkit-touch-callout:none;background:radial-gradient(circle at 15% 20%,#4c193b 0%,transparent 55%),repeating-linear-gradient(120deg,#1b1824,#1b1824 5px,#17121c 6px,#17121c 9px);border-top:5px solid #d7ff00;box-shadow:inset 0 6px #0b090e,inset 0 -7px #09090e}
.deck .zero-zone{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:7px}
.deck .right-zone{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:2px;justify-content:stretch;align-items:end;padding:0 6px 0 0;box-sizing:border-box;min-width:0}
.deck button{border-radius:50%;touch-action:none;user-select:none;-webkit-user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent;display:grid;place-items:center;gap:0;line-height:1;background:radial-gradient(circle at 30% 24%,#fa77bb,#dc297e 54%,#98205a 100%);border:4px solid #f4bce1;box-shadow:0 8px 0 #42102d,0 11px 0 #0b0710,inset 0 3px 2px #ffd4ea;color:#120d19}
.deck button:active{transform:translateY(5px);box-shadow:0 3px 0 #42102d,inset 0 2px 3px #53213c}
.deck button:focus-visible{outline:3px solid #d7ff00;outline-offset:4px}
.deck .zero{width:clamp(96px,29vw,136px);height:clamp(96px,29vw,136px);background:radial-gradient(circle at 26% 21%,#616273,#2b273b 64%,#14121c);border-color:#84908c;box-shadow:0 9px 0 #11101a,0 12px 0 #09090d,inset 0 3px 2px #999}
.deck .zero svg{width:73%;height:73%}
.deck .letter{width:clamp(56px,17vw,76px);height:clamp(56px,17vw,76px);font:bold clamp(26px,8vw,38px) monospace}
.deck .trick{align-self:flex-start;margin-bottom:24px}
.deck .jump{align-self:flex-end;margin-top:24px;background:radial-gradient(circle at 28% 20%,#dfff6c,#a9f000 58%,#638600);border-color:#e6ffa7;box-shadow:0 8px 0 #3a5705,0 11px 0 #080b09,inset 0 3px 2px #f5ffd5}
.deck .trick:active{background:radial-gradient(circle at 25% 18%,#eeffac,#b9ff35 70%,#75962c);border-color:#d7ff00}
.deck .caption{color:#f5e8f0;font:700 clamp(7px,2vw,9px) monospace;letter-spacing:.02em;text-align:center;white-space:nowrap}
.deck .right-zone .labeled{display:flex;flex-direction:column;align-items:center;gap:7px;min-width:0;max-width:100%}
.deck .note{font-size:9px;color:#a8a3b0;text-align:center}
}
@media(pointer:fine){.controls{display:none}}@media(max-width:600px){.top{top:3px;right:3px;gap:3px}.top button{font-size:10px;padding:5px 6px;min-width:44px;min-height:40px}.overlay{font-size:12px;padding:4px;gap:3px;place-content:center;grid-template-columns:minmax(0,1fr);justify-items:center;box-sizing:border-box;overflow:hidden}.overlay h2{font-size:14px;margin:1px}.overlay p{font-size:11px;line-height:1.25;margin:1px;max-width:290px;overflow-wrap:anywhere;text-align:center}.overlay button{font-size:11px;min-height:32px;min-width:110px;width:150px;max-width:80%;padding:5px 8px}}${tag==='tag-before-training'?tagControlsStyle:''}${tag==='grind-the-terms'?grindArtStyle:''}</style><div class="screen"><canvas role="img" aria-label="${label} game"></canvas><div class="top"><button part="sound" aria-label="Toggle sound">SOUND OFF</button><button part="pause" aria-label="Pause">Ⅱ</button></div>${tag==='tag-before-training'?'':'<div class="controls"></div>'}<div class="overlay" data-phase="title"><h2>${label}</h2><p>${tag==='grind-the-terms'?'PRESS U / ↑ TO START':'PRESS SPACE / TAP TO START'}</p>${tag==='tag-before-training'?'<p>10s without fresh art: drones hunt you. Escape their scan or tag the police.</p>':''}<button part="start">START</button></div></div>${tag==='grind-the-terms'?'<div class="deck" part="mobile-controls" aria-label="Zero Algorithmic Uprising arcade controls"><div class="zero-zone"><button type="button" class="zero" data-key="boost" aria-label="Ø, hold spray boost"><svg viewBox="0 0 100 100" aria-hidden="true"><ellipse cx="49" cy="50" rx="29" ry="39" fill="none" stroke="#d7ff00" stroke-width="12"/><path d="M54 4 L32 51 H49 L39 91 L76 41 H57 L70 4 Z" fill="#e0287a" stroke="#100b17" stroke-width="3"/></svg></button><span class="caption">Ø / BOOST</span><span class="note">GRIND + TRICKS FILL</span></div><div class="right-zone"><div class="labeled"><button type="button" class="letter trick" data-key="trick" aria-label="A, perform a trick">A</button><span class="caption">TRICK</span></div><div class="labeled"><button type="button" class="letter jump" data-key="jump" aria-label="U, jump and hold to grind">U</button><span class="caption">JUMP / GRIND</span></div></div></div>':tag==='tag-before-training'?'<div class="tag-deck" part="mobile-controls"><div class="controls tag-controls" aria-label="Skate and spray controls"></div></div>':''}<span aria-live="polite" style="position:absolute;left:-9999px" class="live"></span>`;
   this.canvas=root.querySelector('canvas')!;this.ctx=this.canvas.getContext('2d')!;this.live=root.querySelector('.live')!;this.controls=root.querySelector('.controls')!;this.startButton=root.querySelector('[part=start]')!;
   this.readStorage();
   this.game = create((name, detail = {}) => {
     if (name === 'game:skin-loaded') queueMicrotask(() => {
       if (this.isConnected && (!this.active || this.paused)) this.game.draw(this.ctx, this.canvas.width, this.canvas.height);
     });
     if (profile) {
       if (profile.cues[name]) this.playCue(profile.cues[name]);
       this.notify(name, detail);
     } else {
       if (['game:grind-start','game:grind-end','game:power','game:near-miss','game:bail','game:tag','game:drone-tagged','game:paint-pickup','game:scraped','game:stun','game:player-scan','game:identified','game:police-arrived','game:arrested'].includes(name)) this.playTone(name);
       this.notify(name, { version: this.version, skin: this.getAttribute('skin') || 'placeholder', ...detail });
     }
   }, this);
    this.game.setMuted?.(this.muted);
   this.loadSkin(this.getAttribute('skin'));
   this.updateSoundLabel();
   this.startButton.addEventListener('click', () => this.start());
   root.querySelector('[part=pause]')!.addEventListener('click', () => this.paused ? this.resume() : this.pause());
   root.querySelector('[part=sound]')!.addEventListener('click', () => this.setSound(!this.muted));
   this.addEventListener('keydown', this.onKey); this.addEventListener('keyup', this.onUp);
   if (profile) {
     this.bindProfile(root);
   } else {
   this.canvas.addEventListener('pointerdown',e=>{e.preventDefault();this.focusGame();try{this.canvas.setPointerCapture(e.pointerId)}catch{}if(!this.active)this.start();else if(!this.paused&&!(tag==='grind-the-terms'&&matchMedia('(pointer:coarse) and (max-width:600px)').matches))this.game.input('tap',true)});
   this.canvas.addEventListener('pointerup',()=>this.game.input('tap',false));this.canvas.addEventListener('pointercancel',()=>this.game.input('tap',false));
   this.controls.innerHTML=tag==='tag-before-training'?'<div class="tag-stick" aria-label="Drag to skate"><div class="tag-stick-art"><i class="tag-knob"></i></div><button class="tag-dir" data-key="left" aria-label="Move left">◀</button><button class="tag-dir" data-key="up" aria-label="Move up">▲</button><button class="tag-dir" data-key="down" aria-label="Move down">▼</button><button class="tag-dir" data-key="right" aria-label="Move right">▶</button></div><button class="tag-spray" data-key="spray" aria-label="Spray paint">SPRAY</button>':'';
   this.controls.querySelectorAll('button').forEach(b=>{const k=(b as HTMLElement).dataset.key!;b.addEventListener('pointerdown',e=>{e.preventDefault();this.game.input(k,true)});for(const evt of ['pointerup','pointercancel','pointerleave'])b.addEventListener(evt,()=>this.game.input(k,false));});
   if(tag==='tag-before-training'){
    const zone=root.querySelector('.tag-stick') as HTMLElement,knob=root.querySelector('.tag-knob') as HTMLElement,base=root.querySelector('.tag-stick-art') as HTMLElement;
    let pointer:number|null=null,originX=0,originY=0;
    const end=()=>{pointer=null;this.game.setMoveAxis?.(0,0);knob.style.transform='translate(-50%,-50%)';base.style.left=base.style.top='50%'};
    zone.addEventListener('pointerdown',e=>{if((e.target as HTMLElement).closest('button')||pointer!==null)return;e.preventDefault();if(!this.active)this.start();if(this.paused)return;pointer=e.pointerId;originX=e.clientX;originY=e.clientY;const rect=zone.getBoundingClientRect();base.style.left=(e.clientX-rect.left)+'px';base.style.top=(e.clientY-rect.top)+'px';try{zone.setPointerCapture(e.pointerId)}catch{}});
    zone.addEventListener('pointermove',e=>{if(e.pointerId!==pointer)return;e.preventDefault();const dx=e.clientX-originX,dy=e.clientY-originY,dist=Math.hypot(dx,dy),max=42,scale=dist>max?max/dist:1;knob.style.transform=`translate(calc(-50% + ${dx*scale}px),calc(-50% + ${dy*scale}px))`;this.game.setMoveAxis?.(Math.abs(dx)<5?0:dx*scale/max,Math.abs(dy)<5?0:dy*scale/max)});
    for(const name of ['pointerup','pointercancel','lostpointercapture'])zone.addEventListener(name,end);
    for(const name of ['contextmenu','selectstart','dragstart'])root.addEventListener(name,e=>e.preventDefault(),{signal:this.lifetime.signal});
   }
   if(tag==='grind-the-terms'){
    // iOS long-press selection/callout interrupts a continuous hold-to-grind.
    // Block it only inside this game; regular page content stays selectable.
    for(const name of ['contextmenu','selectstart','dragstart'])root.addEventListener(name,e=>e.preventDefault(),{signal:this.lifetime.signal});
    const trick=root.querySelector('[data-key=trick]') as HTMLButtonElement|null;
    const jump=root.querySelector('[data-key=jump]') as HTMLButtonElement|null;
    const boost=root.querySelector('[data-key=boost]') as HTMLButtonElement|null;
    const bindHold=(button:HTMLButtonElement|null,key:string)=>{
     const pointers=new Set<number>();
     button?.addEventListener('pointerdown',event=>{
      event.preventDefault();if(!this.active)this.start();if(this.paused)return;
      try{button?.setPointerCapture(event.pointerId)}catch{}
      pointers.add(event.pointerId);this.sendInput(key,'pointer:'+key+':'+event.pointerId,true);
     });
     const end=(event:PointerEvent)=>{if(!pointers.delete(event.pointerId))return;this.sendInput(key,'pointer:'+key+':'+event.pointerId,false)};
     button?.addEventListener('pointerup',end);button?.addEventListener('pointercancel',end);button?.addEventListener('lostpointercapture',end);
     button?.addEventListener('click',event=>{if(event.detail===0){if(!this.active)this.start();if(!this.paused){const source='accessible:'+key;this.sendInput(key,source,true);this.sendInput(key,source,false)}}});
    };
    bindHold(trick,'trick');
    bindHold(boost,'boost');
    const jumpPointers=new Set<number>();
    jump?.addEventListener('touchstart',e=>e.preventDefault(),{passive:false});
    jump?.addEventListener('touchmove',e=>e.preventDefault(),{passive:false});
    jump?.addEventListener('pointerdown',e=>{
     e.preventDefault();if(!this.active)this.start();if(this.paused)return;
     try{jump.setPointerCapture(e.pointerId)}catch{}
     jumpPointers.add(e.pointerId);this.sendInput('up','pointer:jump:'+e.pointerId,true);
    });
    const endJump=(e:PointerEvent)=>{if(!jumpPointers.delete(e.pointerId))return;this.sendInput('up','pointer:jump:'+e.pointerId,false)};
    jump?.addEventListener('pointerup',endJump);jump?.addEventListener('pointercancel',endJump);jump?.addEventListener('lostpointercapture',endJump);
    jump?.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.repeat){e.preventDefault();if(!this.active)this.start();if(!this.paused)this.sendInput('up','button-key:'+e.code,true)}});
    jump?.addEventListener('keyup',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();this.sendInput('up','button-key:'+e.code,false)}});   }
   }
   this.resizeObserver=new ResizeObserver(()=>this.resize());this.resizeObserver.observe(this);this.observer=new IntersectionObserver(entries=>{if(entries[0]&&entries[0].intersectionRatio<.25)this.pause('offscreen')},{threshold:[0,.25,1]});this.observer.observe(this);document.addEventListener('visibilitychange',this.onVisibility);window.addEventListener('blur',this.onBlur);this.resize();this.game.draw(this.ctx,this.canvas.width,this.canvas.height);if (!profile) this.dispatchEvent(new CustomEvent('game:ready',{detail:{game:tag,skin:'placeholder',version:'0.2.0-dev',usingPlaceholder:true},bubbles:true,composed:true}));
  }
  private focusGame(){const focused=this.shadowRoot?.activeElement;if(focused instanceof HTMLElement)focused.blur();this.focus()}
   private sendInput(key:string,source:string,down:boolean,atMs=performance.now()){
    if(!profile && tag!=='grind-the-terms'){this.game.input(key,down,atMs,source);return}
    const sources=this.inputSources.get(key)??new Set<string>(),wasDown=sources.size>0;
    if(down)sources.add(source);else sources.delete(source);
    if(sources.size)this.inputSources.set(key,sources);else this.inputSources.delete(key);
    const isDown=sources.size>0;if(wasDown!==isDown)this.game.input(key,isDown,atMs,source);
   }
   /** Allows a cartridge's independent touch pads to use the shared source aggregation. */
   action(key:string,source:string,down:boolean,atMs=performance.now()){
     if(!this.active||this.paused)return;
     this.sendInput(key,source,down,atMs);
   }
   private releaseHeldInputs(){
    for(const [key,sources] of this.inputSources)if(sources.size)this.game.input(key,false,performance.now(),'release');
    this.releasePointer?.();this.inputSources.clear();this.padHeld=[false,false,false];this.game.releaseInput?.();
   }
  private onKey = (e: KeyboardEvent) => {
    const path = e.composedPath();
    if (document.activeElement !== this || path.some(n => n instanceof HTMLInputElement || n instanceof HTMLSelectElement || n instanceof HTMLDialogElement)) return;
    const key = this.game.keyForCode?.(e.code) || this.key(e.key);
    const inButton = path.some(n => n instanceof HTMLButtonElement);
    if (!key || (inButton && (!profile || (key !== 'pause' && key !== 'mute')))) return;
    e.preventDefault();
    if (e.repeat) return;
    if (key === 'pause') { this.paused ? this.resume() : this.pause(); return; }
    if (key === 'mute') { this.setSound(!this.muted); return; }
    if (!this.active && (!profile || key === profile.primary)) {
      this.start();
      if (!profile || profile.consumeStartInput) return;
    }
    if (this.active && !this.paused) this.sendInput(key, 'keyboard:' + e.code, true, e.timeStamp);
  };
  private onUp = (event: KeyboardEvent) => {
    if (document.activeElement !== this) return;
    const action = this.game.keyForCode?.(event.code) || this.key(event.key);
    if (!action) return;
    const inControl = event.composedPath().some(node => node instanceof HTMLButtonElement || node instanceof HTMLInputElement || node instanceof HTMLSelectElement || node instanceof HTMLDialogElement);
    if (!profile || !inControl) event.preventDefault();
     this.sendInput(action, 'keyboard:' + event.code, false, event.timeStamp);
  };
  private key(k:string){if(profile)return profile.keys[k.length===1?k.toLowerCase():k] || '';if(tag==='tag-before-training'&&k.length===1)k=k.toLowerCase();if(tag==='grind-the-terms')return ({' ':'trick','ArrowUp':'up','w':'up','W':'up','u':'up','U':'up','a':'trick','A':'trick','r':'boost','R':'boost','Escape':'pause','p':'pause','m':'mute','M':'mute'} as Record<string,string>)[k]||'';return ({' ':'tap','ArrowUp':'up','ArrowDown':'down','ArrowLeft':'left','ArrowRight':'right','w':'up','a':'left','s':'down','d':'right','Escape':'pause','p':'pause','m':'mute','M':'mute'} as Record<string,string>)[k]||''}
  private onVisibility=()=>{if(document.hidden)this.pause('hidden')};private onBlur=()=>this.pause('blur');
  private resize() {
    if (!this.canvas) return;
    if (profile) fitViewport(this, this.shadowRoot!, profile);
    const surface = profile ? this.canvas : this.shadowRoot!.querySelector('.screen')!;
    const rect = surface.getBoundingClientRect();
    const dpr = Math.min(devicePixelRatio || 1, tag === 'grind-the-terms' && matchMedia('(pointer:coarse)').matches ? 1.5 : 2);
    const w = Math.max(1, Math.round(rect.width * dpr)), h = Math.max(1, Math.round(rect.height * dpr));
    if (this.canvas.width !== w) this.canvas.width = w;
    if (this.canvas.height !== h) this.canvas.height = h;
    if (profile && this.game && (!this.active || this.paused)) this.game.draw(this.ctx, w, h);
  }
  get muted() { return this.mutedValue; }
  set muted(value: boolean) {
    this.mutedValue = value;
    this.game?.setMuted?.(value);
    if (tag === 'tag-before-training') this.toggleAttribute('data-sound-on', !value);
    if (profile) {
      this.updateSoundLabel();
      if (value && this.audio?.state === 'running') void this.audio.suspend().catch(() => {});
    }
  }
  private updateSoundLabel() {
    const button = this.shadowRoot?.querySelector<HTMLButtonElement>('[part=sound]');
    if (!button) return;
    const strings = this.game?.presentation?.().strings;
    button.textContent = this.muted ? strings?.sound_off ?? 'SOUND OFF' : strings?.sound_on ?? 'SOUND ON';
    button.setAttribute('aria-pressed', String(!this.muted));
  }
  private setSound(muted: boolean) {
    this.muted = muted; this.updateSoundLabel();
    writeLocal(this.storageKey('muted'), muted ? '1' : '0');
    if (!muted && !this.paused) profile ? this.playCue('ui_click') : this.playTone('game:power');
    this.notify('game:sound', { on: !muted });
  }
  private playCue(key: string) {
    if (!this.gesture || this.paused || this.muted) return;
    const view = this.game?.presentation?.(), params = view?.sfx[key];
    if (!view || !params || view.volume <= 0) return;
    try {
      this.audio ??= new AudioContext();
      if (this.audio.state === 'suspended') void this.audio.resume().catch(() => {});
      synthesize(this.audio, params, view.volume);
    } catch { /* Silent play is supported. */ }
  }
  private bindProfile(root: ShadowRoot) {
    const signal = this.lifetime.signal;
    const activate = (event: Event) => { if (event.isTrusted) this.gesture = true; };
    for (const name of ['keydown', 'pointerdown', 'click']) this.addEventListener(name, activate, { capture: true, signal });
    this.canvas.setAttribute('aria-label', this.getAttribute('label') || label);
    this.releasePointer = bindPositionInput(root, () => this.phase === 'playing', () => this.focusGame(),
      fraction => this.game.setPositionTarget?.(fraction), signal);
    root.querySelector('[part=again]')!.addEventListener('click', () => this.start(), { signal });
    root.querySelector('[part=resume]')!.addEventListener('click', () => this.resume(), { signal });
    root.querySelector('[part=share]')!.addEventListener('click', () => void this.shareScore(this.game.score(), label), { signal });
    const launch = root.querySelector<HTMLButtonElement>('[data-primary]');
    if (launch) {
    const press = (source: string) => {
      if (this.paused) return;
      if (!this.active) this.start();
      this.focusGame(); this.sendInput(profile!.primary, source, true);
    };
    launch.addEventListener('pointerdown', event => {
      if (event.button !== 0) return;
      event.preventDefault();
      if (launch.hasPointerCapture(event.pointerId) || event.isTrusted) launch.setPointerCapture(event.pointerId);
      press('launch:' + event.pointerId);
    }, { signal });
    for (const name of ['pointerup', 'pointercancel', 'lostpointercapture'] as const) {
      launch.addEventListener(name, event => this.sendInput(profile!.primary, 'launch:' + event.pointerId, false), { signal });
    }
    launch.addEventListener('click', event => {
      if (event.detail !== 0) return;
      press('accessible-launch'); this.sendInput(profile!.primary, 'accessible-launch', false);
    }, { signal });
    }
    this.addEventListener('focusout', () => queueMicrotask(() => {
      if (this.isConnected && document.activeElement !== this) this.pause('blur');
    }), { signal });
    const syncPads = () => {
      clearInterval(this.idlePadTimer);
      try {
        if (navigator.getGamepads?.().some(pad => pad?.connected)) {
          // Only controls are polled at rest. A paused simulation has no animation frame.
          this.idlePadTimer = window.setInterval(() => {
            if (this.phase !== 'playing' && !root.querySelector('dialog[open]') && !document.hidden && document.hasFocus() && document.activeElement === this) this.pollGamepad();
          }, 100);
        } else this.readProfilePad(null);
      } catch { /* Some embeds disable gamepads. */ }
    };
    window.addEventListener('gamepadconnected', syncPads, { signal });
    window.addEventListener('gamepaddisconnected', syncPads, { signal });
    syncPads();
  }
  private readProfilePad(pad: Gamepad | null) {
    const previous = this.profilePad;
    this.profilePad = new Set<number>();
    for (const [index, action] of Object.entries(profile!.padButtons)) {
      const button = Number(index), pressed = Boolean(pad?.buttons[button]?.pressed);
      if (pressed) this.profilePad.add(button);
      if (pressed === previous.has(button)) continue;
      if (action === 'pause') {
        if (pressed && document.activeElement === this) this.paused ? this.resume('player') : this.pause();
      } else {
        if (pressed && !this.active && action === profile!.primary && document.activeElement === this) this.start();
        if (this.phase === 'playing' || !pressed) this.sendInput(action, 'pad:' + index, pressed, performance.now());
      }
    }
    for (const mapping of profile!.padAxes || []) {
      const value = pad?.axes[mapping.index] || 0, deadzone = mapping.deadzone ?? 0.35;
      this.sendInput(mapping.negative, 'pad-axis:' + mapping.index + '-', value < -deadzone && this.phase === 'playing', performance.now());
      this.sendInput(mapping.positive, 'pad-axis:' + mapping.index + '+', value > deadzone && this.phase === 'playing', performance.now());
    }
    const axis = pad?.axes[0] || 0;
    this.game.setMoveAxis?.(this.phase === 'playing' && Math.abs(axis) > 0.16 ? axis : 0, 0);
  }
  private playTone(event:string){if(this.muted)return;try{this.audio??=new AudioContext();const time=this.audio.currentTime;const osc=this.audio.createOscillator(),gain=this.audio.createGain();const pitches:Record<string,number>={'game:grind-start':610,'game:grind-end':390,'game:power':870,'game:near-miss':720,'game:bail':140,'game:player-scan':960,'game:identified':240,'game:police-arrived':330,'game:arrested':130};const f=pitches[event]||550;osc.type=event==='game:bail'?'sawtooth':'square';osc.frequency.setValueAtTime(f,time);osc.frequency.exponentialRampToValueAtTime(Math.max(65,f*.55),time+.12);gain.gain.setValueAtTime(.0001,time);gain.gain.exponentialRampToValueAtTime(.035,time+.01);gain.gain.exponentialRampToValueAtTime(.0001,time+.14);osc.connect(gain);gain.connect(this.audio.destination);osc.start(time);osc.stop(time+.15)}catch{}}
  private pollGamepad(){try{const pad=navigator.getGamepads?.().find(p=>p?.connected);if(profile){this.readProfilePad(pad ?? null);return}if(!pad)return;if(tag==='grind-the-terms'){const keys=['up','trick','boost'];keys.forEach((key,i)=>{const pressed=!!pad.buttons[i]?.pressed;if(pressed!==this.padHeld[i]){this.sendInput(key,'gamepad:'+key,pressed);this.padHeld[i]=pressed}})}else{const pressed=!!pad.buttons[0]?.pressed;if(pressed!==this.padHeld[0]){const key=tag==='tag-before-training'?'spray':'tap';this.sendInput(key,'gamepad:'+key,pressed);this.padHeld[0]=pressed}}if(tag==='tag-before-training'){const x=pad.axes[0]||0,y=pad.axes[1]||0;this.game.input('left',x<-.35);this.game.input('right',x>.35);this.game.input('up',y<-.35);this.game.input('down',y>.35)}}catch{}}
  start() {
    if (this.game.canStart && !this.game.canStart()) return;
    this.releaseHeldInputs(); this.game.start(); this.padHeld = [false,false,false];
    this.bestScore = Number(readLocal(this.storageKey('best'))) || 0;
    this.active = true; this.paused = false; this.phase = 'playing'; this.focusGame();
    this.runStartedAt = performance.now(); this.pausedMs = 0;
    const overlay = this.shadowRoot!.querySelector<HTMLElement>('.overlay')!;
    overlay.dataset.phase = 'playing'; overlay.hidden = true; overlay.style.display = 'none';
    const seed = Number(this.getAttribute('seed') ?? 1);
    this.notify('game:start', profile ? { seed: Number.isFinite(seed) ? seed | 0 : 1 } : {});
    this.last = performance.now(); cancelAnimationFrame(this.frame); this.frame = requestAnimationFrame(this.tick);
  }
  private tick=(now:number)=>{if(!this.active||this.paused)return;const dt=Math.min((now-this.last)/1000,.05);this.last=now;this.pollGamepad();if(this.paused)return;this.game.update(dt);this.game.draw(this.ctx,this.canvas.width,this.canvas.height);if(this.game.over()){this.active=false;this.phase='over';const score=this.game.score();this.bestScore=Number(readLocal(this.storageKey('best'))) || 0;const isNewBest=score>this.bestScore;this.bestScore=Math.max(this.bestScore,score);writeLocal(this.storageKey('best'),String(this.bestScore));const result=this.game.result?.()||{};this.live.textContent=`Game over. ${typeof result.causeLine==='string'?result.causeLine:''} Score ${score}. Best ${this.bestScore}`;const overlay=this.shadowRoot!.querySelector('.overlay') as HTMLElement;overlay.dataset.phase='over';overlay.hidden=false;overlay.style.display='grid';
    if (profile) { if(isNewBest)this.playCue('new_best'); this.refreshPanel(); overlay.querySelector<HTMLButtonElement>('[part=again]')?.focus({preventScroll:true}); }
    else { overlay.innerHTML=`<h2>${tag==='tag-before-training'?(result.cause==='arrested'?'BUSTED':'TRAINING COMPLETE'):'GAME OVER'}</h2><p>${typeof result.causeLine==='string'?result.causeLine:'TERMS ACCEPTED. OOPS.'}</p><p>SCORE ${score} • BEST ${this.bestScore}</p><p>${tag==='tag-before-training'?(isNewBest?'NEW STYLE RECORD.':'YOUR ALLEY. YOUR STYLE.'):(isNewBest?'NEW RECORD. STILL UNREAD.':'SKIM AGAIN?')}</p><button part="again">${tag==='tag-before-training'?'ROLL AGAIN':'SKIM AGAIN'}</button><button part="share">SHARE</button>`;overlay.querySelector('[part=again]')!.addEventListener('click',()=>this.start());overlay.querySelector('[part=share]')!.addEventListener('click',()=>{void this.shareScore(score,label)});}
    this.notify('game:over', {score, best:this.bestScore, isNewBest, durationMs:Math.round(performance.now()-this.runStartedAt-this.pausedMs), ...result});return;}this.frame=requestAnimationFrame(this.tick)};
  private async shareScore(score: number, label: string) {
    const result = this.game.result?.();
    const url = location.protocol === 'http:' || location.protocol === 'https:' ? location.href : '';
    const template = typeof result?.shareText === 'string' ? result.shareText : 'I skipped ' + score + ' clauses in ' + label + '. Nobody reads them. Skate them!';
    const text = template.replaceAll('{url}', url).replace(/:\s*$/, '').trim();
    if (!this.notify('game:share', { score, best: this.bestScore, text, url }, true)) return;
    try {
      if (navigator.share) { await navigator.share({ title: label, text, ...(url ? { url } : {}) }); return; }
    } catch (error) { if (error instanceof DOMException && error.name === 'AbortError') return; }
    const combined = text.includes(url) ? text : text + ' ' + url;
    try {
      if (navigator.clipboard?.writeText) { await navigator.clipboard.writeText(combined); this.live.textContent = 'Score copied to clipboard'; return; }
    } catch {}
    const field = this.shadowRoot?.querySelector<HTMLInputElement>('[data-share-fallback]');
    if (field) { field.hidden = false; field.value = combined; field.focus(); field.select(); }
    this.live.textContent = field ? 'Select and copy your score.' : 'Share unavailable here; copy the page URL to share your score.';
  }
  pause(reason='player'){if(!this.active||this.paused)return;this.game.onPause?.();this.releaseHeldInputs();this.paused=true;this.phase='paused';this.pauseClock=performance.now();
   if (profile && this.audio?.state === 'running') void this.audio.suspend().catch(() => {});
   this.game.releaseInput?.();cancelAnimationFrame(this.frame);const overlay=this.shadowRoot!.querySelector('.overlay') as HTMLElement;overlay.dataset.phase='paused';overlay.removeAttribute('hidden');overlay.style.display='grid';
   if (profile) { this.refreshPanel(); if (reason === 'player') overlay.querySelector<HTMLButtonElement>('[part=resume]')?.focus({preventScroll:true}); }
   else { overlay.innerHTML=tag==='tag-before-training'?'<h2>PAUSED</h2><p>The alley can wait.</p><button part="resume">RESUME</button>':'<h2>PAUSED</h2><p>Take your time. The fine print can wait.</p><button part="resume">RESUME</button>';overlay.querySelector('[part=resume]')!.addEventListener('click',()=>this.resume());} this.notify('game:pause',{reason})}
  resume(reason='player'){if(!this.active||!this.paused)return;this.pausedMs+=performance.now()-this.pauseClock;this.paused=false;this.phase='playing';this.game.onResume?.();const overlay=this.shadowRoot!.querySelector<HTMLElement>('.overlay')!;overlay.style.display='none';overlay.setAttribute('hidden','');this.focusGame();this.last=performance.now();this.frame=requestAnimationFrame(this.tick);this.notify('game:resume',{reason})}
  reset(){this.releaseHeldInputs();this.active=false;this.paused=false;this.phase='title';cancelAnimationFrame(this.frame);if(this.game.onReset)this.game.onReset();else this.game.start();const overlay=this.shadowRoot!.querySelector('.overlay') as HTMLElement;overlay.dataset.phase='title';overlay.style.display='grid';overlay.removeAttribute('hidden');if(profile){this.refreshPanel();this.resize();return}overlay.innerHTML=`<h2>${label}</h2><p>${tag==='grind-the-terms'?'PRESS U / ↑ TO START':'PRESS SPACE / TAP TO START'}</p>${tag==='tag-before-training'?'<p>10s without fresh art: drones hunt you. Escape their scan or tag the police.</p>':''}<button part="start">START</button>`;overlay.querySelector('[part=start]')!.addEventListener('click',()=>this.start());}
  get state(){return this.phase}get best(){return this.bestScore}get version(){return profile?.version ?? '0.2.0-dev'}
  disconnectedCallback(){this.releaseHeldInputs();this.lifetime.abort();this.game?.dispose?.();
   this.skinSequence++;this.readySent=false;this.gesture=false;this.active=false;this.paused=false;this.phase='title';
   clearInterval(this.idlePadTimer);this.profilePad.clear();cancelAnimationFrame(this.frame);this.removeEventListener('keydown',this.onKey);this.removeEventListener('keyup',this.onUp);document.removeEventListener('visibilitychange',this.onVisibility);window.removeEventListener('blur',this.onBlur);this.observer?.disconnect();this.resizeObserver?.disconnect();this.audio?.close().catch(()=>{});this.audio=undefined}
 }
 customElements.define(tag,ArcadeElement);
}

