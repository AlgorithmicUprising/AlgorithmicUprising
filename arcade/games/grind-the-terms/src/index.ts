import { defineArcade, type GameAPI } from '../../../core/src/engine';
import chunksData from './chunks.json';
import {
  boundsOverlap, courierBody, courierClosing, courierDeck, courierWidth, createEye,
  enterEyePhase, eyeApproachTime, eyeDepartTime, eyeDisabledTime, eyeEarlyJumpTime,
  eyeHull, eyeInSprayRange, eyeLens, eyeOllieCueTime, eyePad, eyePadReady, eyeRecoverTime,
  eyeScan, eyeScanTime, eyeWarningTime, moveEye, sprayJamCost, sprayOrigin,
  type Bounds, type CookieEye
} from './drones';
import { drawCookieEye, drawEyeCallout, drawScanLane, drawSprayJam, type SprayBurst } from './drones-draw';

// Grind the Terms v0.2 preview: mechanics separated from the AU-only skin assets.
type HazardKind = 'accept' | 'popup' | 'gap' | 'rail' | 'token' | 'drone';
type Power = 'coin' | 'shield' | 'airboost' | 'trick2' | 'rocket';
type Chunk = { id: string; tier: number; width: number; objects: Array<{at:number;kind:HazardKind;w:number;power?:Power;pickupY?:number}> };
type Obstacle = { x:number; w:number; kind:HazardKind; power?:Power; pickupY?:number; scored:boolean; collected:boolean; deflected:boolean; cargoCollected?:boolean; phase?:number; hoverHeight?:number; arriveAt?:number; intro?:boolean };
type Anim = 'run'|'idle'|'land'|'ollie'|'bail'|'grind'|'railpop'|'kickflip'|'heelflip'|'flip360'|'varial'|'hardflip'|'laserflip';
type AtlasGrid={cellW:number;cellH:number;columns:number;anchorX?:number;anchorY?:number;displayScale?:number;boardIncluded?:boolean};
type RailVisual={surfaceCellY:number;groundCellY:number;drawHeight:number;clipTopCellY:number};
type Art = { images:Record<string,HTMLImageElement>; cloudRaster:Record<string,HTMLCanvasElement>; palette?:Record<string,string>; grid?:Record<string,AtlasGrid>; rail?:RailVisual; anims?:Record<string,{start:number;frames:number;fps:number;loop?:boolean;sheet?:string}>; name:string };
const chunks = chunksData as Chunk[];
const clamp = (n:number,low:number,high:number)=>Math.max(low,Math.min(high,n));

// No global listeners: multiple embedded games are independent Web Components.
defineArcade('grind-the-terms','GRIND THE TERMS',(emit,host)=>{
  // Fony, ground pickups, and obstacles share the sidewalk centerline.
  const ground = 310, playerX = 140, gravity = 1800, jumpVelocity = -620, railPopVelocity = -380;
  const baseSpeed=180; // Gameplay travel is independent of render FPS; do not change it to fix stutter.
  let viewLeft=0,viewRight=640; // Current world-space camera bounds for parallax cropping.
  let boardY=ground, lastBoardY=ground, vy=0, elapsed=0, distance=0;
  let bonus=0, extraClauses=0, grindDistance=0, totalGrindDistance=0, grindMs=0;
  let alive=true, bailRemaining=0, cause='accept', held=false, grinding=false;
  // Rails, low Accept buttons, and taller consent forms are separate surfaces.
  let support:Obstacle|null=null,platformLandings=0,platformGrinds=0;
  let jumpCount=0,tricksUsed=0,trick2Unlocked=false,airBoost=false,shield=false,shieldsUsed=0,hazardsCleared=0;
  let bufferLeft=0, coyoteLeft=0, stateTime=0, landTimer=0;
  let combo=0,comboTimer=0,longestCombo=0,lastSurface='ground';
  let trickDown=false,boostDown=false,boostExhausted=false,trickUpgradeSpawned=false,nextRocketScore=160,sprayGauge=0;
  let grindCharge=0,grindBoostLeft=0,boostTriggered=false,shieldDeflections=0;
  let trickCallout='',trickCalloutLeft=0;
  let objects:Obstacle[]=[];
  let clearedStationary:{rail:boolean;accept:boolean;popup:boolean;gap:boolean}={rail:false,accept:false,popup:false,gap:false};
  const droneHeightBands=[154,96,166,92] as const;
  const stepTime=1/120;
  let stepCarry=0, practiceDrones=false;
  let deliveryUnlocked=false, nextDroneSection=Infinity, droneBeat=0, droneHeightIndex=0;
  let eyeAt=Infinity, eye:CookieEye|null=null, scanSlowLeft=0;
  let earlyDodges:boolean[]=[], sprayBurst:SprayBurst|null=null;
  let scansHit=0, eyesJammed=0, eyesStomped=0;
  const boostSeconds=11.25;
  let nextChunk=0, lastChunkId='', firstChunk=true;
  let art:Art|null=null,skinRequest=0;
  const skinCssVars={titleCard:'--grind-title-art',gameOverCard:'--grind-over-art',mobileControlDeck:'--grind-deck-art'};
  const clearSkinCss=()=>{for(const property of Object.values(skinCssVars))host.style.removeProperty(property);host.removeAttribute('data-au-art-ready')};
  const applySkinCss=(files:Record<string,string>,skinUrl:URL)=>{let ready=false;for(const [key,property] of Object.entries(skinCssVars)){const path=files[key];if(path){host.style.setProperty(property,'url(\"'+new URL(path,skinUrl).href+'\")');ready=true}else host.style.removeProperty(property)}if(ready)host.setAttribute('data-au-art-ready','');else host.removeAttribute('data-au-art-ready')};
  let rngState=0x11b00c5;
  let visualFlash=0;
  let currentAnim:Anim='run';

  const rng=()=>{rngState=(Math.imul(1664525,rngState)+1013904223)>>>0;return rngState/4294967296};
  const tier=()=>elapsed<20?1:elapsed<45?2:elapsed<90?3:4;
  // Ground pace ramps independently; the held spray gauge supplies a temporary 2x multiplier.
  const normalSpeed=()=>clamp(baseSpeed+elapsed*1.72,baseSpeed,460);
  const score=()=>Math.floor(distance/48)+Math.floor(extraClauses)+Math.floor(totalGrindDistance/32)*2+Math.floor(bonus);
  const boostActive=()=>boostDown&&!boostExhausted&&sprayGauge>0;
  const speed=()=>normalSpeed()*(boostActive()?2:(grindBoostLeft>0?1.07:1))*(scanSlowLeft>0?.75:1);
  const addSpray=(amount:number)=>{if(amount>0)sprayGauge=clamp(sprayGauge+amount*(boostDown ? 0.25 : 1),0,1)};
  const comboMultiplier=()=>combo>0?combo:1;
  const comboAction=(base=0)=>{
    combo=combo<=0||comboTimer<=0?1:combo+1;comboTimer=1.5;
    longestCombo=Math.max(longestCombo,combo);
    if(base>0)bonus+=base*combo;
    return combo;
  };
  const stationaryClearCount=()=>Object.values(clearedStationary).filter(Boolean).length;
  // Grounding contract (source atlas cells are 144x112).
  // Each obstacle is drawn relative to its *visible* feet / button base,
  // not the transparent cell edge. Top collision = actual artwork top.
  // Keep geometry independent of skin selection to avoid mid-run physics jumps.
  const sourceCellHeight=112;
  const surfaces={
    rail:   {top:53,bottom:82,height:77},   // metal coping / feet
    accept: {top:0,bottom:112,height:42},   // low, standalone ACCEPT block sprite
    popup:  {top:0,bottom:112,height:100}  // single 100-unit Consent barrier
  } as const;
  type SurfaceKind=keyof typeof surfaces;
  const surfaceSpec=(kind:SurfaceKind)=>surfaces[kind];
  const imageTopY=(kind:SurfaceKind)=>{
    const spec=surfaceSpec(kind);
    return ground-spec.bottom/sourceCellHeight*spec.height;
  };
  const surfaceTopY=(kind:SurfaceKind)=>{
    const spec=surfaceSpec(kind);
    return imageTopY(kind)+spec.top/sourceCellHeight*spec.height;
  };
  const railSurfaceY=()=>surfaceTopY('rail');
  const flatTopY=(kind:HazardKind)=>
    kind==='accept'||kind==='popup'?surfaceTopY(kind):ground;
  const droneTopY=(o:Obstacle)=>ground-(o.hoverHeight??118)+Math.sin((o.phase||0)+elapsed*2.1)*3;
  const surfaceY=(o:Obstacle)=>o.kind==='rail'?railSurfaceY():o.kind==='drone'?droneTopY(o):flatTopY(o.kind);
  const overlaps=(o:Obstacle)=>o.x+(o.kind==='drone'?courierDeck.left:0)<playerX+16&&
    o.x+(o.kind==='drone'?courierDeck.right:o.w)>playerX-16;
  const state=(animation:Anim)=>{if(currentAnim!==animation){currentAnim=animation;stateTime=0}};
  const isTrickAnimation=(animation:Anim)=>animation==='kickflip'||animation==='heelflip'||animation==='flip360'||animation==='varial'||animation==='hardflip'||animation==='laserflip';
  const playerBody=():Bounds=>({left:playerX-14,right:playerX+14,top:boardY-(grinding||isTrickAnimation(currentAnim)?76:96),bottom:boardY});
  const reset=()=>{
    boardY=ground;lastBoardY=ground;vy=0;elapsed=0;distance=0;bonus=0;extraClauses=0;
    grindDistance=0;totalGrindDistance=0;grindMs=0;alive=true;bailRemaining=0;cause='accept';
    held=false;grinding=false;support=null;platformLandings=0;platformGrinds=0;jumpCount=0;tricksUsed=0;trick2Unlocked=false;airBoost=false;shield=false;shieldsUsed=0;sprayGauge=0;
    hazardsCleared=0;bufferLeft=0;coyoteLeft=.08;stateTime=0;landTimer=0;
    combo=0;comboTimer=0;longestCombo=0;lastSurface='ground';objects=[];clearedStationary={rail:false,accept:false,popup:false,gap:false};
    practiceDrones=host.getAttribute('practice')==='drones';
    deliveryUnlocked=practiceDrones;nextDroneSection=practiceDrones?40:Infinity;droneBeat=0;droneHeightIndex=0;
    nextChunk=practiceDrones?40:380;lastChunkId='';firstChunk=true;
    stepCarry=0;eyeAt=Infinity;eye=null;scanSlowLeft=0;earlyDodges=[];sprayBurst=null;
    scansHit=0;eyesJammed=0;eyesStomped=0;
    trickDown=false;boostDown=false;boostExhausted=false;trickUpgradeSpawned=false;nextRocketScore=160;grindCharge=0;grindBoostLeft=0;boostTriggered=false;shieldDeflections=0;
    trickCallout='';trickCalloutLeft=0;
    if(host.hasAttribute('data-qa-trick-upgrade'))trick2Unlocked=true;
    if(practiceDrones||host.hasAttribute('data-qa-rocket-charge'))sprayGauge=1/3;
    rngState=(Number(host.getAttribute('seed'))||0x11b00c5)>>>0;visualFlash=0;currentAnim='run';
  };
  const land=()=>{
    boardY=ground;vy=0;grinding=false;jumpCount=0;tricksUsed=0;coyoteLeft=.08;
    if(lastSurface!=='ground'){landTimer=.36;state('land')}
    lastSurface='ground';combo=0;comboTimer=0;
    if(bufferLeft>0){bufferLeft=0;ollie()}
  };
  const ollie=()=>{
    if(!alive||bailRemaining>0)return;
    if(eye?.phase==='warning'&&eye.age<=eyeEarlyJumpTime)eye.earlyJump=true;
    // Jump input is always a single ollie. Tricks use their own button.
    jumpCount=1;vy=jumpVelocity;state('ollie');
    support=null;grinding=false;landTimer=0;coyoteLeft=0;bufferLeft=0;lastSurface='air';comboAction();
  };
  const trickLimit=()=>trick2Unlocked?2:1;
  const trickTier=():0|1|2 =>score()>=125?2:score()>=50?1:0;
  const performTrick=()=>{
    if(!alive||bailRemaining>0||grinding||support||lastSurface!=='air'||boardY>=ground-1||tricksUsed>=trickLimit())return;
    const sequence=tricksUsed+1,level=trickTier();
    const names=sequence===1?['KICKFLIP','HEELFLIP','360 FLIP']:['VARIAL COMBO','HARD FLIP COMBO','LASER FLIP COMBO'];
    const values=sequence===1?[2,4,6]:[4,8,12];
    const name=names[level],points=values[level];
    tricksUsed=sequence;jumpCount=1;vy=sequence===1?-520:-470;
    const trickAnims=sequence===1?['kickflip','heelflip','flip360'] as const:['varial','hardflip','laserflip'] as const;
    state(trickAnims[level]);lastSurface='air';
    comboAction(points);addSpray(.015+Math.min(.01,Math.max(0,combo-2)*.002));trickCallout=name+' +'+points;trickCalloutLeft=1.15;
    emit('game:trick',{name,points,level:level+1,sequence,limit:trickLimit(),combo,sprayGauge,score:score()});
  };
  const railPop=()=>{
    const from=support?.kind||'rail';support=null;grinding=false;grindCharge=0;boostTriggered=false;
    if(from==='drone')tricksUsed=0;
    vy=railPopVelocity;boardY-=3;lastSurface='air';jumpCount=1;comboAction(1);
    state('railpop');emit('game:grind-end',{surface:from,distancePx:Math.floor(grindDistance),grindMs:Math.floor(grindMs),combo,tricksReset:from==='drone',tricksUsed});
  };
  const input=(key:string,down:boolean)=>{
    if(key==='trick'){
      if(down&&!trickDown)performTrick();
      trickDown=down;return;
    }
    if(key==='boost'||key==='special'){
      if(down&&!boostDown&&alive){
        boostExhausted=sprayGauge<=0;
        if(!boostExhausted)emit('game:boost',{source:'spray-gauge',remainingMs:Math.round(sprayGauge*boostSeconds*1000),charges:Math.floor(sprayGauge*3),speedMultiplier:2});
      }
      if(!down)boostExhausted=false;
      boostDown=down;return;
    }
    // Canvas clicks and the trick button never trigger an ollie or release a grind.
    if(key!=='up')return;
    if(down&&!held){
      if(grinding){railPop()}
      else if(support||boardY>=ground-1||coyoteLeft>0){ollie()}
      else bufferLeft=.1;
    }
    if(!down&&held&&grinding)railPop();
    held=down;
  };
  const comboBonus=(base:number)=>{bonus+=base*comboMultiplier()};
  const handleCollision=(kind:HazardKind|'cookie-eye',top:number)=>{
    if(shield){shield=false;shieldsUsed++;shieldDeflections++;bonus+=1;
      boardY=Math.min(boardY,top-4);vy=-260;support=null;grinding=false;
      emit('game:shield',{used:true,blocked:kind});return true}
    alive=false;cause=kind;bailRemaining=.55;combo=0;comboTimer=0;state('bail');
    emit('game:bail',{cause,score:score()});
    return false;
  };
  const collideObstacle=(o:Obstacle)=>{if(handleCollision(o.kind,surfaceY(o)))o.deflected=true};
  const collect=(o:Obstacle)=>{
    if(o.collected)return;
    o.collected=true;bonus+=10;
    if(o.power==='trick2'){
      trick2Unlocked=true;
      emit('game:power',{power:'trick2',collected:true,secondTrickUnlocked:true});
      return;
    }
    if(o.power==='rocket'){
      sprayGauge=Math.min(1,sprayGauge+1/3);
      emit('game:power',{power:'rocket',collected:true,charges:Math.floor(sprayGauge*3),maxCharges:3,sprayGauge});
      return;
    }
    if(o.power==='coin'){
      emit('game:power',{power:'coin',collected:true,score:score()});
      return;
    }
    // Opt-out and legacy AIR BOOST pickups are defensive, not jump upgrades.
    shield=true;airBoost=false;
    emit('game:power',{power:o.power||'shield',collected:true});
  };
  const spawnMilestonePickups=()=>{
    if(!trickUpgradeSpawned&&score()>=80){
      trickUpgradeSpawned=true;
      objects.push({x:playerX+430,w:48,kind:'token',power:'trick2',pickupY:ground-90,scored:false,collected:false,deflected:false});
      emit('game:pickup-ready',{power:'trick2',score:score(),pickupY:ground-90});
    }
    while(score()>=nextRocketScore){
      const milestone=nextRocketScore;
      nextRocketScore+=120;
      const pending=objects.some(o=>o.kind==='token'&&o.power==='rocket'&&!o.collected);
      if(sprayGauge<1&&!pending){
        const pickupY=Math.floor(milestone/120)%2===1?ground-90:ground;
        objects.push({x:playerX+440,w:72,kind:'token',power:'rocket',pickupY,scored:false,collected:false,deflected:false});
        emit('game:pickup-ready',{power:'rocket',score:score(),pickupY});
      }
    }
  };
  const emitChunk=()=>{
    const choices=chunks.filter(c=>c.tier<=tier()&&(!firstChunk||c.id==='intro-rails')&&c.id!==lastChunkId);
    const list=choices.length?choices:chunks.filter(c=>c.tier<=tier()&&(!firstChunk||c.id==='intro-rails'));
    // The first low ACCEPT button follows the opening practice rail.
    const picked=lastChunkId==='intro-rails'?(chunks.find(c=>c.id==='intro-accept')||list[0]):list[Math.floor(rng()*list.length)];
    if(!picked)return;
    firstChunk=false;lastChunkId=picked.id;
    for(const item of picked.objects){
      objects.push({x:playerX+nextChunk+item.at-distance,w:item.w,kind:item.kind,power:item.power,pickupY:item.pickupY,scored:false,collected:false,deflected:false});
    }
    nextChunk+=picked.width;
  };
  const markStationaryCleared=(kind:HazardKind)=>{
    const key=kind==='rail'||kind==='accept'||kind==='popup'||kind==='gap'?kind:null;
    if(!key||clearedStationary[key])return;
    clearedStationary[key]=true;
    const cleared=stationaryClearCount();
    emit('game:obstacle-cleared',{kind:key,cleared,total:4});
    if(cleared===4&&!deliveryUnlocked){
      deliveryUnlocked=true;
      nextDroneSection=nextChunk;
      emit('game:delivery-unlocked',{cleared,total:4,spawnDistance:nextChunk+270});
    }
  };
  const emitDroneSection=()=>{
    const start=nextChunk;
    const courier=droneBeat===0||(!practiceDrones&&droneBeat%2===0);
    if(courier){
      const arriveAt=start+270;
      const x=playerX+(arriveAt-distance)*courierClosing-courierDeck.left;
      const hoverHeight=droneHeightBands[droneHeightIndex++%droneHeightBands.length];
      objects.push({x,w:courierWidth,kind:'drone',power:'coin',phase:rng()*Math.PI*2,
        hoverHeight,arriveAt,intro:droneBeat===0,scored:false,collected:false,cargoCollected:false,deflected:false});
      emit('game:delivery-spawn',{x:Math.round(x),cargo:'coin',grindable:true,hoverHeight,clearCount:stationaryClearCount()});
      if(droneBeat===0){
        for(const offset of [205,270,335]){
          objects.push({x:playerX+start+offset-distance,w:26,kind:'token',power:'coin',pickupY:ground,
            scored:false,collected:false,deflected:false});
        }
      }
      nextChunk=start+640;
      nextDroneSection=nextChunk+(droneBeat===0?0:900);
    }else{
      eyeAt=start+105;
      if(sprayGauge<0.2){
        objects.push({x:playerX+start+34-distance,w:72,kind:'token',power:'rocket',pickupY:ground,
          scored:false,collected:false,deflected:false});
      }
    }
    droneBeat++;
  };

  const fillRoute=()=>{
    // An Eye needs a clear stretch until it leaves, even if Fony boosts midway through its warning.
    while(!eye&&!Number.isFinite(eyeAt)&&nextChunk<distance+790){
      if(nextChunk>=nextDroneSection)emitDroneSection();
      else emitChunk();
    }
    if(distance<eyeAt)return;
    const lane=earlyDodges.length===2&&earlyDodges.every(Boolean)?'high':'low';
    eye=createEye(viewRight,playerX,ground,lane);
    eyeAt=Infinity;
    emit('game:drone-spawn',{drone:'cookie-eye',lane,clearCount:stationaryClearCount()});
  };

  const canJamEye=(target:CookieEye)=>target.phase==='warning'&&sprayGauge>=sprayJamCost&&eyeInSprayRange(target,playerX,boardY);
  const updateEye=(target:CookieEye,dt:number)=>{
    moveEye(target,dt,playerX,ground);
    if(target.phase==='approach'&&target.age>=eyeApproachTime){
      enterEyePhase(target,'warning');
      emit('game:drone-warn',{drone:'cookie-eye',lane:target.lane,warningMs:Math.round(eyeWarningTime*1000)});
    }
    if(target.phase==='warning'){
      if(boostActive()&&canJamEye(target)){
        sprayGauge=Math.max(0,sprayGauge-sprayJamCost);
        if(sprayGauge<=0)boostExhausted=true;
        sprayBurst={from:sprayOrigin(playerX,boardY),to:eyeLens(target),left:.32};
        target.jammed=true;
        eyesJammed++;
        enterEyePhase(target,'recover');
        emit('game:drone-jam',{drone:'cookie-eye',sprayCost:sprayJamCost,sprayGauge});
      }else if(target.age>=eyeWarningTime){
        enterEyePhase(target,'scan');
        emit('game:drone-scan',{drone:'cookie-eye',lane:target.lane});
      }
    }
    if(target.phase==='scan'){
      if(!target.scanHit&&boundsOverlap(playerBody(),eyeScan(target,playerX,ground))){
        target.scanHit=true;
        scansHit++;
        scanSlowLeft=1.15;
        combo=0;
        comboTimer=0;
        emit('game:drone-hit',{drone:'cookie-eye',lane:target.lane,slowMs:1150});
      }
      if(target.age>=eyeScanTime){
        const earlyDodge=target.earlyJump&&!target.scanHit;
        earlyDodges=[...earlyDodges,earlyDodge].slice(-2);
        if(!target.scanHit)emit('game:drone-dodge',{drone:'cookie-eye',lane:target.lane,early:earlyDodge});
        enterEyePhase(target,'recover');
      }
    }
    if(target.phase==='recover'){
      const pad=eyePad(target);
      const abovePad=playerX+14>pad.left&&playerX-14<pad.right;
      if(eyePadReady(target)&&abovePad&&!support&&vy>=0&&lastBoardY<=pad.y+2&&boardY>=pad.y){
        target.stomped=true;
        enterEyePhase(target,'disabled');
        eyesStomped++;
        boardY=pad.y-2;
        vy=-420;
        jumpCount=1;
        tricksUsed=0;
        coyoteLeft=0;
        landTimer=0;
        lastSurface='air';
        state('railpop');
        comboAction(8);
        trickCallout='TRICKS REFRESHED';
        trickCalloutLeft=1.05;
        emit('game:drone-stomp',{drone:'cookie-eye',jammed:target.jammed,combo,tricksReset:true,score:score()});
      }else if(target.age>=eyeRecoverTime){
        enterEyePhase(target,'depart');
      }
    }
    if(target.phase!=='disabled'&&boundsOverlap(playerBody(),eyeHull(target))){
      if(handleCollision('cookie-eye',target.top))enterEyePhase(target,'disabled');
    }
    if((target.phase==='depart'&&target.age>=eyeDepartTime)||(target.phase==='disabled'&&target.age>=eyeDisabledTime)){
      eye=null;
      nextChunk=distance+(practiceDrones?110:Math.max(175,speed()*.65));
      nextDroneSection=nextChunk+(practiceDrones?0:1000);
    }
  };

  const step=(dt:number)=>{
    if(!alive){bailRemaining=Math.max(0,bailRemaining-dt);stateTime+=dt;return}
    elapsed+=dt;stateTime+=dt;landTimer=Math.max(0,landTimer-dt);
    scanSlowLeft=Math.max(0,scanSlowLeft-dt);
    if(sprayBurst){sprayBurst.left-=dt;if(sprayBurst.left<=0)sprayBurst=null;}
    if(combo>0){if(grinding)comboTimer=1.5;else{comboTimer=Math.max(0,comboTimer-dt);if(comboTimer===0)combo=0}}
    trickCalloutLeft=Math.max(0,trickCalloutLeft-dt);
    grindBoostLeft=Math.max(0,grindBoostLeft-dt);
    if(grinding){grindCharge+=dt;addSpray(dt*.006);if(grindCharge>=.85&&!boostTriggered){boostTriggered=true;grindBoostLeft=2.2;emit('game:boost',{source:'extended-grind',durationMs:2200,bonusPercent:7})}}
    else {grindCharge=0;boostTriggered=false;}
    visualFlash=Math.max(0,visualFlash-dt);
    bufferLeft=Math.max(0,bufferLeft-dt);
    if(!grinding&&boardY>=ground-1)coyoteLeft=.08;
    else coyoteLeft=Math.max(0,coyoteLeft-dt);
    const playerSpeed=speed(),moved=playerSpeed*dt;
    distance+=moved;
    if(boostActive()){
      sprayGauge=Math.max(0,sprayGauge-dt/boostSeconds);
      if(sprayGauge<=0)boostExhausted=true;
    }
    fillRoute();
    // The leading edge of each courier deck reaches Fony at the section's planned distance.
    for(const o of objects){
      if(o.kind==='drone'&&o.arriveAt!==undefined)o.x=playerX+(o.arriveAt-distance)*courierClosing-courierDeck.left;
      else o.x-=moved;
    }
    lastBoardY=boardY;
    if(support&&!overlaps(support)){
      const previous=support;support=null;
      if(grinding){
        grinding=false;
        emit('game:grind-end',{surface:previous.kind,distancePx:Math.floor(grindDistance),grindMs:Math.floor(grindMs)});
      }
      vy=0;coyoteLeft=.1;lastSurface='air';
    }
    if(support){
      boardY=surfaceY(support);vy=0;
      if(grinding){
        grindMs+=dt*1000;totalGrindDistance+=moved;grindDistance+=moved;
        extraClauses+=moved/48;
      }
    }else{
      boardY+=vy*dt;vy+=gravity*dt;
    }
    for(const o of objects){
      const overlap=overlaps(o);
      if(o.kind==='rail'){
        const top=railSurfaceY();
        if(!support&&held&&overlap&&vy>=0&&lastBoardY<=top+15&&boardY>=top-16&&boardY<=top+20){
          support=o;boardY=top;vy=0;grinding=true;grindCharge=0;boostTriggered=false;jumpCount=0;lastSurface='rail';
          state('grind');comboAction(1);emit('game:grind-start',{surface:'rail',combo,score:score()});
        }
        continue;
      }
      if(o.kind==='drone'){
        const top=surfaceY(o),cargoX=o.x-22,cargoY=top-28;
        if(!o.cargoCollected&&Math.abs(playerX-cargoX)<22&&Math.abs(boardY-cargoY)<38){
          o.cargoCollected=true;bonus+=10;
          emit('game:power',{power:'coin',collected:true,source:'delivery-drone',score:score()});
        }
        if(!o.deflected&&!support&&overlap&&vy>=0&&lastBoardY<=top+3&&boardY>=top){
          support=o;boardY=top;vy=0;coyoteLeft=.08;landTimer=.36;platformLandings++;lastSurface='drone';
          if(held){
            grinding=true;grindCharge=0;boostTriggered=false;platformGrinds++;state('grind');comboAction(1);
            emit('game:grind-start',{surface:'drone',combo,score:score()});
          }else{grinding=false;state('land');emit('game:platform-land',{surface:'drone',score:score()})}
          continue;
        }
        if(o.deflected||!alive||o===support)continue;
        const body=playerBody();
        if(courierBody.some(part=>boundsOverlap(body,{
          left:o.x+part.left,right:o.x+part.right,top:top+part.top,bottom:top+part.bottom
        })))collideObstacle(o);
        continue;
      }
      if(o.kind==='token'){
        if(overlap&&!o.collected&&Math.abs(boardY-(o.pickupY??ground))<34)collect(o);
        continue;
      }
      if(!overlap||o.collected||o.deflected||!alive||o===support)continue;
      if(o.kind==='gap'){
        if(boardY>ground-10)collideObstacle(o);
        continue;
      }
      // ACCEPT and Consent barriers have flat, skatable tops.
      // Catch descending from above; hitting the vertical side still bails.
      const top=flatTopY(o.kind);
      if(!support&&vy>=0&&lastBoardY<=top+12&&boardY>=top-10&&boardY<=top+Math.max(26,Math.abs(vy)*dt+12)){
        support=o;boardY=top;vy=0;lastSurface=o.kind;
        jumpCount=0;coyoteLeft=.08;landTimer=.36;platformLandings++;
        if(held){
          grinding=true;grindCharge=0;boostTriggered=false;platformGrinds++;state('grind');comboAction(1);
          emit('game:grind-start',{surface:o.kind,combo,score:score()});
        }else{
          grinding=false;state('land');
          emit('game:platform-land',{surface:o.kind,score:score()});
        }
        continue;
      }
      if(boardY>top+10)collideObstacle(o);
    }
    if(eye&&alive)updateEye(eye,dt);
    if(!support&&boardY>=ground){land()}
    if(!support&&boardY<ground-1&&landTimer===0&&alive){
      if(currentAnim!=='ollie'&&!isTrickAnimation(currentAnim)&&currentAnim!=='railpop')state('ollie');
    }
    if(!support&&boardY>=ground&&landTimer===0)state('idle');
    if(support&&!grinding&&landTimer===0)state('idle');
    for(const o of objects){
      if(!alive||o.kind==='token'||o.kind==='drone'||o.scored||o.collected)continue;
      if(o.x+o.w<playerX-15){
        o.scored=true;markStationaryCleared(o.kind);
        if(o.kind==='rail')continue;
        hazardsCleared++;
        const base=o.kind==='popup'?5:o.kind==='gap'?8:3;
        comboBonus(base);
        const nearTarget=o.kind==='gap'?ground-30:surfaceY(o);
        const near=Math.abs(boardY-nearTarget)<10;
        if(near){bonus+=1;emit('game:near-miss',{score:score()})}
      }
    }
    objects=objects.filter(o=>o.x+o.w>-45);
    spawnMilestonePickups();
  };

  const update=(dt:number)=>{
    stepCarry+=Math.min(dt,.05);
    while(stepCarry+1e-9>=stepTime){
      stepCarry=Math.max(0,stepCarry-stepTime);
      step(stepTime);
    }
  };

  async function setSkin(url:string|null){
    const request=++skinRequest;
    if(!url){art=null;clearSkinCss();emit('game:skin-loaded',{skin:'placeholder',usingPlaceholder:true});return}
    try{
      const skinUrl=new URL(url,document.baseURI);
      const response=await fetch(skinUrl.toString(),{credentials:'omit'});
      if(!response.ok)throw new Error('skin HTTP '+response.status);
      const data=await response.json() as {game:string;name?:string;files?:Record<string,string>;palette?:Record<string,string>;grid?:Art['grid'];rail?:RailVisual;anims?:Art['anims']};
      if(data.game!=='grind-the-terms'||!data.files)throw new Error('Unsupported skin data');
      const images:Record<string,HTMLImageElement>={};
      await Promise.all(Object.entries(data.files).map(async ([key,path])=>{
        const image=new Image();image.decoding='async';image.src=new URL(path,skinUrl).href;await image.decode();images[key]=image;
      }));
      if(request!==skinRequest)return;
      if(data.grid?.skater){const g=data.grid.skater,image=images.skater;if(!image||!Number.isInteger(g.cellW)||!Number.isInteger(g.cellH)||!Number.isInteger(g.columns)||g.cellW<16||g.cellH<16||g.columns<1||image.naturalWidth<g.columns*g.cellW||image.naturalHeight<Math.ceil(39/g.columns)*g.cellH)throw new Error('Incomplete Fony sprite atlas grid')}
      if(data.grid?.skaterActions){const g=data.grid.skaterActions,image=images.skaterActions;if(!image||!Number.isInteger(g.cellW)||!Number.isInteger(g.cellH)||!Number.isInteger(g.columns)||g.cellW<16||g.cellH<16||g.columns<1||image.naturalWidth<g.columns*g.cellW||image.naturalHeight<Math.ceil(51/g.columns)*g.cellH)throw new Error('Incomplete Fony action atlas grid')}
      if(data.rail){const r=data.rail,g=data.grid?.hazards; if(!g||!Number.isFinite(r.groundCellY)||!Number.isFinite(r.drawHeight)||!Number.isFinite(r.surfaceCellY)||!Number.isFinite(r.clipTopCellY)||r.drawHeight<=0||r.clipTopCellY<0||r.clipTopCellY>=r.surfaceCellY||r.surfaceCellY>=r.groundCellY||r.groundCellY>g.cellH)throw new Error('Invalid rail surface metadata')}
      // The approved WebP is an internally layered paper-cut cloudbank.
      // Cache it once at its NATIVE dimensions; no full-frame resampling in the render loop.
      const cloudRaster:Record<string,HTMLCanvasElement>={};
      const source=images.cloudsNear;
      if(source){
        const cache=document.createElement('canvas');
        cache.width=source.naturalWidth;cache.height=source.naturalHeight;
        const cc=cache.getContext('2d',{alpha:true});
        if(cc){
          cc.drawImage(source,0,0);
          // Almost-illegible legal fine print is printed into the cloud artwork,
          // clipped automatically to the cloudbank's paper shapes.
          cc.save();cc.globalCompositeOperation='source-atop';
          cc.fillStyle='rgba(48,31,51,.16)';cc.font='3.2px monospace';
          const clauses=['TERMS AND CONDITIONS SUBJECT TO CHANGE','DATA RETENTION MAY CONTINUE WITHOUT NOTICE','SECTION 14.2 CONSENT TO PROCESSING','YOUR INFORMATION MAY BE REVIEWED'];
          for(let y=38;y<cache.height-12;y+=11){
            for(let x=15;x<cache.width-60;x+=209){
              cc.fillText(clauses[(Math.floor(y/11)+Math.floor(x/209))%clauses.length],x,y,182);
            }
          }
          cc.restore();cloudRaster.cloudsNear=cache;
        }
      }
      art={images,cloudRaster,name:data.name||'Fony',palette:data.palette,grid:data.grid,rail:data.rail,anims:data.anims};
      applySkinCss(data.files,skinUrl);
      emit('game:skin-loaded',{skin:'au',usingPlaceholder:false,assets:Object.keys(images)});
    }catch(error){if(request!==skinRequest)return;art=null;clearSkinCss();emit('game:error',{code:'SKIN_LOAD_FAILED',message:String(error),usingPlaceholder:true})}
  }

  const drawSheet=(ctx:CanvasRenderingContext2D,key:string,col:number,row:number,x:number,y:number,w:number,h:number)=>{
    const asset=art?.images[key];if(!asset)return false;
    const isSkater=key==='skater'||key==='skaterActions',cfg=art?.grid?.[key],cellW=cfg?.cellW??(isSkater?80:144),cellH=cfg?.cellH??(isSkater?94:112);
    const sx=col*cellW,sy=row*cellH;
    if(sx<0||sy<0||sx+cellW>asset.naturalWidth||sy+cellH>asset.naturalHeight)return false;
    // Fony is an inked sprite with intentional hard contour lines.
    // Disable interpolation only for character source pixels; background
    // textures remain smoothly resampled. Save/restore prevents global bleed.
    if(isSkater){
      ctx.save();ctx.imageSmoothingEnabled=false;
      ctx.drawImage(asset,sx,sy,cellW,cellH,x,y,w,h);
      ctx.restore();
    }else ctx.drawImage(asset,sx,sy,cellW,cellH,x,y,w,h);
    return true;
  };
  const drawSkater=(ctx:CanvasRenderingContext2D)=>{
    let animation=currentAnim;
    if(!alive)animation='bail';
    else if(grinding)animation='grind';
    else if(landTimer>0)animation='land';
    else if(support||boardY>=ground-1)animation='idle';
    // The approved v1 sheet keeps the six-frame cruise cycle; generated v2 cells cover action poses.
    const fallbackMap:Record<Anim,{sheet:string;start:number;frames:number;fps:number;loop?:boolean}>={
      run:{sheet:'skater',start:0,frames:6,fps:12,loop:true},idle:{sheet:'skater',start:0,frames:6,fps:12,loop:true},
      ollie:{sheet:'skaterActions',start:6,frames:5,fps:9},land:{sheet:'skaterActions',start:11,frames:4,fps:12},
      kickflip:{sheet:'skaterActions',start:15,frames:4,fps:8},heelflip:{sheet:'skaterActions',start:19,frames:4,fps:8},
      flip360:{sheet:'skaterActions',start:23,frames:4,fps:8},varial:{sheet:'skaterActions',start:27,frames:4,fps:8},
      hardflip:{sheet:'skaterActions',start:31,frames:4,fps:8},laserflip:{sheet:'skaterActions',start:35,frames:4,fps:8},
      grind:{sheet:'skaterActions',start:39,frames:4,fps:10,loop:true},railpop:{sheet:'skaterActions',start:43,frames:4,fps:10},
      bail:{sheet:'skaterActions',start:47,frames:4,fps:8}
    };
    const fallback=fallbackMap[animation],metadata=art?.anims?.[animation];
    const sheet=metadata?.sheet??fallback.sheet,start=metadata?.start??fallback.start;
    const frames=metadata?.frames??fallback.frames,fps=metadata?.fps??fallback.fps;
    const looping=metadata?.loop??fallback.loop??false;
    const frame=looping?Math.floor(stateTime*fps)%frames:Math.min(frames-1,Math.floor(stateTime*fps));
    const rolling=alive&&!grinding&&(animation==='run'||animation==='idle');
    // The approved six-frame board-run cycle stays active on the ground.
    const rollFrame=Math.floor(elapsed*12)%6;
    const settledBail=!alive&&bailRemaining<=0;
    const atlasKey=settledBail?'skater':sheet;
    const idx=settledBail?26:rolling&&atlasKey==='skater'?rollFrame:start+frame;
    const cfg=art?.grid?.[atlasKey]??art?.grid?.skater;
    const width=cfg?.cellW??80,height=cfg?.cellH??94,columns=cfg?.columns??8;
    const anchorX=cfg?.anchorX??width/2,anchorY=cfg?.anchorY??height-4;
    const zoom=cfg?.displayScale??1;
    // The world point is Fony's skateboard contact, never the changing sprite top-left.
    // Bail frames anchor at the impact position and stop at the final frame (no looping).
    const poseY=alive?boardY:ground;
    // Legacy atlases can use the procedural board. The approved gameplay atlas includes Fony's board.
    const boardVisible=alive&&rolling&&!Boolean(cfg?.boardIncluded)&&Boolean(art?.images[atlasKey]);
    if(boardVisible){
      ctx.save();ctx.fillStyle='#14101a';
      for(let n=0;n<5;n++){
        const shift=(distance*.92+n*31)%135;
        ctx.globalAlpha=.17+n*.07;
        ctx.fillRect(playerX-24-shift,poseY+6+n%2*5,19+n*3,1.3);
      }
      ctx.restore();
    }
    if(rolling&&art?.images.skater){
      // Motion is expressed by environment streaks, not missing-board limb frames.
      ctx.save();ctx.strokeStyle='rgba(238,40,122,.7)';ctx.lineWidth=1.5;
      for(let i=0;i<3;i++){const offset=(elapsed*speed()*.5+i*19)%55;
        ctx.beginPath();ctx.moveTo(playerX-38-offset,poseY-7+i*3);ctx.lineTo(playerX-19-offset,poseY-7+i*3);ctx.stroke()}
      ctx.restore();
    }
    const usedAtlas=drawSheet(ctx,atlasKey,idx%columns,Math.floor(idx/columns),playerX-anchorX*zoom,poseY-anchorY*zoom,width*zoom,height*zoom);
    if(boardVisible){
      // Draw board ON TOP of any stray source-cell foot fragments, at the board baseline.
      ctx.save();
      ctx.fillStyle='#17121b';ctx.beginPath();ctx.roundRect(playerX-32,poseY-7,64,7,3.5);ctx.fill();
      ctx.fillStyle='#e0287a';ctx.beginPath();ctx.roundRect(playerX-29,poseY-6,58,4,2);ctx.fill();
      ctx.fillStyle='#d7ff00';ctx.fillRect(playerX-15,poseY-6,30,1.8);
      for(const wheelX of [playerX-20,playerX+20]){
        ctx.fillStyle='#100e17';ctx.beginPath();ctx.arc(wheelX,poseY+3,5,0,Math.PI*2);ctx.fill();
        ctx.fillStyle='#efe9da';ctx.beginPath();ctx.arc(wheelX,poseY+3,2.5,0,Math.PI*2);ctx.fill();
        const theta=distance*.15;
        ctx.strokeStyle='#e0287a';ctx.lineWidth=1.25;
        ctx.beginPath();ctx.moveTo(wheelX,poseY+3);ctx.lineTo(wheelX+Math.cos(theta)*2.3,poseY+3+Math.sin(theta)*2.3);ctx.stroke();
      }
      ctx.restore();
    }
    if(usedAtlas)return;
    // Procedural placeholder is required when art is absent or blocked.
    ctx.fillStyle='#ff3d7f';ctx.fillRect(playerX-15,boardY-43,30,33);
    ctx.fillStyle='#f0d2a4';ctx.fillRect(playerX-11,boardY-54,22,13);
    ctx.fillStyle='#f9efe6';ctx.fillRect(playerX-21,boardY-5,42,5);
    ctx.fillStyle='#131118';ctx.fillRect(playerX-17,boardY,6,5);ctx.fillRect(playerX+12,boardY,6,5);
  };
  // All obstacle artwork is drawn from clean geometry. The old hazard composite
  // remains archived but is never sampled: its alpha trim included stray borders.
  const railLength=(o:Obstacle)=>Math.max(28,o.w);
  const drawRail=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    const x=o.x,w=railLength(o),y=railSurfaceY();
    ctx.save();
    // Three-part assembly: round left cap / uninterrupted center / round right cap.
    // Rail length is exact, so no partial bitmap can be clipped at the right end.
    ctx.lineJoin='round';ctx.lineCap='round';
    ctx.fillStyle='#130e18';ctx.beginPath();ctx.roundRect(x-2,y-2,w+4,12,5);ctx.fill();
    ctx.fillStyle='#d7ff00';ctx.beginPath();ctx.roundRect(x,y,w,7,4);ctx.fill();
    ctx.fillStyle='#eefc72';ctx.fillRect(x+10,y+1,Math.max(0,w-20),2);
    ctx.fillStyle='#e0287a';ctx.fillRect(x+3,y+7,Math.max(0,w-6),2);
    // A leg under each cap, and evenly distributed supports on longer rails.
    const legs=[x+13,x+w-18];
    for(let p=x+115;p<x+w-50;p+=115)legs.push(p);
    for(const leg of legs){
      ctx.fillStyle='#130f19';ctx.fillRect(leg-3,y+9,11,ground-y-7);
      ctx.fillStyle='#c0d52d';ctx.fillRect(leg,y+10,5,ground-y-12);
      ctx.fillStyle='#15111a';ctx.fillRect(leg-9,ground-3,23,3);
    }
    // Two end caps with distinct bolts and edge outlines.
    for(const cx of [x+7,x+w-8]){
      ctx.fillStyle='#101018';ctx.beginPath();ctx.arc(cx,y+3.5,2.1,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#eee6d9';ctx.fillRect(cx-.7,y+3,.9,.9);
    }
    ctx.restore();
  };
  const drawAccept=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    const top=flatTopY('accept'),x=o.x,w=o.w,h=ground-top;
    const sprite=art?.images.acceptObstacle;
    ctx.save();ctx.lineJoin='round';
    ctx.fillStyle='rgba(10,8,16,.55)';ctx.beginPath();ctx.ellipse(x+w/2,ground-1,w*.48,4,0,0,Math.PI*2);ctx.fill();
    if(sprite){
      // The separate ACCEPT ALL curb art stays low and grounded; consent forms keep their own surfaces.
      ctx.drawImage(sprite,16,51,616,138,x,top,w,h);
      // Retain a crisp canvas label over the distressed lettering at small tablet scale.
      ctx.fillStyle='#141412';ctx.font='900 13px Arial,sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';
      ctx.fillText('ACCEPT ALL',x+w*.58,top+h*.48,w*.52);
    }else{
      ctx.fillStyle='#0c0a11';ctx.beginPath();ctx.roundRect(x-3,top-2,w+6,h+4,7);ctx.fill();
      ctx.fillStyle='#81766c';ctx.beginPath();ctx.roundRect(x,top,w,h,4);ctx.fill();
      ctx.fillStyle='#e0287a';ctx.fillRect(x+5,top+4,w-10,4);
      const buttonW=Math.min(w-16,Math.max(72,(h-8)*3.25));
      const buttonH=buttonW/3.25,buttonX=x+(w-buttonW)/2,buttonY=ground-buttonH-4;
      ctx.fillStyle='#d7ff00';ctx.beginPath();ctx.roundRect(buttonX,buttonY,buttonW,buttonH,5);ctx.fill();
      ctx.strokeStyle='#151216';ctx.lineWidth=2;ctx.stroke();
      ctx.fillStyle='#151216';ctx.font='bold 9px monospace';ctx.textAlign='center';ctx.textBaseline='middle';
      ctx.fillText('ACCEPT ALL',buttonX+buttonW*.58,buttonY+buttonH/2+1,buttonW*.7);
    }
    ctx.restore();
  };
  const drawConsent=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    const top=flatTopY(o.kind),x=o.x,w=o.w,h=ground-top;
    const panel=art?.images.consentPopup;
    ctx.save();ctx.lineJoin='round';
    if(panel)ctx.drawImage(panel,x-4,top-3,w+8,h+3);
    else{
      ctx.fillStyle='#0e0b14';ctx.beginPath();ctx.roundRect(x-4,top-3,w+8,h+3,6);ctx.fill();
      ctx.fillStyle='#f6efe2';ctx.beginPath();ctx.roundRect(x,top,w,h,3);ctx.fill();
      ctx.fillStyle='#d72c80';ctx.fillRect(x,top,w,22);
      ctx.fillStyle='#15111b';ctx.font='bold 11px monospace';
      ctx.textBaseline='alphabetic';ctx.textAlign='left';ctx.fillText('CONSENT',x+7,top+15,Math.max(34,w-14));
      ctx.font='9px monospace';ctx.fillStyle='#231b2c';
      for(let i=0;i<2;i++){
        const rowY=top+32+i*18;
        ctx.strokeStyle='#221a26';ctx.lineWidth=1.6;ctx.strokeRect(x+8,rowY-8,9,9);
        ctx.fillText(['Share my data','Track activity'][i],x+22,rowY,Math.max(20,w-27));
      }
      ctx.strokeStyle='#15121a';ctx.lineWidth=2;ctx.strokeRect(x,top,w,h);
    }
    if(o.deflected){
      ctx.fillStyle='#171119';ctx.fillRect(x+3,top+25,w-6,19);
      ctx.fillStyle='#d7ff00';ctx.font='bold 12px monospace';ctx.textAlign='center';ctx.fillText('DENIED!',x+w/2,top+39);
    }
    ctx.restore();
  };
  const drawToken=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    // Each pickup targets a board height: ground lanes roll through, high lanes require an ollie.
    const x=o.x+o.w/2,cy=(o.pickupY??ground)-28;
    const wobble=1+Math.sin(elapsed*7+o.x*.018)*.045;
    ctx.save();ctx.translate(x,cy);ctx.scale(wobble,1);
    if(o.power==='trick2'&&art?.images.trickUpgrade){
      ctx.fillStyle='rgba(224,40,122,.24)';ctx.beginPath();ctx.arc(0,0,26,0,Math.PI*2);ctx.fill();
      ctx.drawImage(art.images.trickUpgrade,-24,-24,48,48);
    }else if(o.power==='rocket'&&art?.images.rocketCan){
      ctx.fillStyle='rgba(215,255,0,.2)';ctx.beginPath();ctx.ellipse(0,0,39,22,0,0,Math.PI*2);ctx.fill();
      ctx.drawImage(art.images.rocketCan,-37,-13,74,26);
    }else if(o.power==='coin'){
      // Ordinary coins are visually distinct from defensive and upgrade tokens.
      ctx.fillStyle='rgba(215,255,0,.25)';ctx.beginPath();ctx.arc(0,0,23,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#111018';ctx.beginPath();ctx.arc(0,0,18,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#d7ff00';ctx.beginPath();ctx.arc(0,0,15,0,Math.PI*2);ctx.fill();
      ctx.strokeStyle='#fff6b7';ctx.lineWidth=2;ctx.beginPath();ctx.arc(0,0,11,0,Math.PI*2);ctx.stroke();
      ctx.fillStyle='#17121b';ctx.beginPath();ctx.moveTo(0,-8);ctx.lineTo(2.4,-2.4);ctx.lineTo(8,0);ctx.lineTo(2.4,2.4);ctx.lineTo(0,8);ctx.lineTo(-2.4,2.4);ctx.lineTo(-8,0);ctx.lineTo(-2.4,-2.4);ctx.closePath();ctx.fill();
    }else if((o.power==='shield'||o.power==='airboost')&&art?.images.optOutToken){
      ctx.fillStyle='rgba(215,255,0,.18)';ctx.beginPath();ctx.arc(0,0,23,0,Math.PI*2);ctx.fill();
      ctx.drawImage(art.images.optOutToken,-23,-23,46,46);
    }else{
      ctx.fillStyle='rgba(215,255,0,.2)';ctx.beginPath();ctx.arc(0,0,22,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#0c0a13';ctx.beginPath();ctx.arc(0,0,18,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#d7ff00';ctx.beginPath();ctx.arc(0,0,15,0,Math.PI*2);ctx.fill();
      ctx.strokeStyle='#f4ffae';ctx.lineWidth=2;ctx.beginPath();ctx.arc(0,0,11.5,0,Math.PI*2);ctx.stroke();
      ctx.fillStyle='#16121e';ctx.beginPath();
      ctx.moveTo(2,-12);ctx.lineTo(-7,2);ctx.lineTo(0,2);ctx.lineTo(-3,12);
      ctx.lineTo(10,-4);ctx.lineTo(3,-4);ctx.lineTo(6,-12);ctx.closePath();ctx.fill();
    }
    ctx.restore();
  };
  const drawDeliveryDrone=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    const x=o.x,w=o.w,top=surfaceY(o),phase=o.phase||0;
    const cargoX=x-22,hoverHeight=o.hoverHeight??118;
    const shadowAlpha=clamp(.34-(hoverHeight-96)*.002,.15,.34);
    const shadowWidth=38+(hoverHeight-96)*.12;
    ctx.save();ctx.lineJoin='round';ctx.lineCap='round';
    // The shadow softens as the same courier flies higher above the sidewalk.
    ctx.fillStyle='rgba(7,5,11,'+shadowAlpha.toFixed(3)+')';
    ctx.beginPath();ctx.ellipse(x+w*.48,ground-1,shadowWidth,5,0,0,Math.PI*2);ctx.fill();
    const sprite=art?.images.deliveryDrone;
    if(sprite&&sprite.naturalWidth>0){
      // The bright lime coping in Terms Runner sits 35.6% down the sprite.
      // Anchor it exactly to the collision surface so board contact matches the art.
      const spriteH=w*(sprite.naturalHeight/sprite.naturalWidth);
      const grindRailAnchorY=spriteH*.356;
      ctx.save();ctx.imageSmoothingEnabled=false;
      ctx.drawImage(sprite,x,top-grindRailAnchorY,w,spriteH);
      ctx.restore();
    }else{
      // Keep the procedural fallback fully aligned with the same three hover lanes.
      const rotorY=top-12;
      for(const cx of [x+20,x+w-20]){
        ctx.strokeStyle='#17121c';ctx.lineWidth=4;ctx.beginPath();ctx.moveTo(cx,rotorY+9);ctx.lineTo(cx,top+1);ctx.stroke();
        ctx.fillStyle='#292331';ctx.beginPath();ctx.ellipse(cx,rotorY,16,4,0,0,Math.PI*2);ctx.fill();
        ctx.strokeStyle='#e8dfd0';ctx.lineWidth=1.3;ctx.stroke();
        ctx.strokeStyle='#e0287a';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(cx-11,rotorY+Math.sin(elapsed*18+phase)*2);ctx.lineTo(cx+11,rotorY-Math.sin(elapsed*18+phase)*2);ctx.stroke();
      }
      ctx.fillStyle='#111018';ctx.beginPath();ctx.roundRect(x+29,top-4,w-57,30,7);ctx.fill();
      ctx.strokeStyle='#e8dfd0';ctx.lineWidth=2;ctx.stroke();
      ctx.fillStyle='#392334';ctx.fillRect(x+31,top+4,w-61,14);
      ctx.fillStyle='#e0287a';ctx.fillRect(x+34,top-5,17,4);
      ctx.fillStyle='#d7ff00';ctx.fillRect(x+w-49,top-5,12,4);
      // The parcel hangs from the hovering body rather than staying fixed by the ground.
      ctx.fillStyle='#b6a78d';ctx.beginPath();ctx.roundRect(x+37,top+23,62,23,3);ctx.fill();
      ctx.strokeStyle='#151019';ctx.lineWidth=2;ctx.stroke();
      ctx.fillStyle='#e0287a';ctx.fillRect(x+39,top+26,58,3);
      ctx.fillStyle='#17121b';ctx.font='bold 7px monospace';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('TERMS',x+68,top+38);
      ctx.fillStyle='#101018';ctx.beginPath();ctx.roundRect(x+courierDeck.left-2,top-2,courierDeck.right-courierDeck.left+4,8,4);ctx.fill();
      ctx.fillStyle='#d7ff00';ctx.fillRect(x+courierDeck.left,top,courierDeck.right-courierDeck.left,4);
    }
    // Cargo coin remains separate from the grind surface and collects on contact.
    if(!o.cargoCollected)drawToken(ctx,{kind:'token',power:'coin',x:cargoX-13,w:26,pickupY:top,scored:false,collected:false,deflected:false});
    else{ctx.fillStyle='#d7ff00';ctx.font='bold 8px monospace';ctx.textAlign='center';ctx.fillText('DELIVERED',cargoX,top-24)}
    ctx.restore();
  };
  const drawLoophole=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    const x=o.x,w=o.w,cx=x+w/2,y=ground+6;
    ctx.save();
    // A broken manhole and torn paper-rim make the gap legible.
    ctx.fillStyle='#c8bbac';ctx.beginPath();ctx.ellipse(cx,y+3,w*.54,13,0,0,Math.PI*2);ctx.fill();
    ctx.fillStyle='#0a0810';ctx.beginPath();ctx.ellipse(cx,y,w*.49,11,0,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle='#e0287a';ctx.lineWidth=3;ctx.stroke();
    ctx.fillStyle='#302b37';ctx.beginPath();ctx.ellipse(x+19,ground-1,23,9,-.3,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle='#e8d8c2';ctx.lineWidth=2;ctx.stroke();
    ctx.strokeStyle='#d7ff00';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(x+12,ground-4);ctx.lineTo(x+23,ground-8);ctx.stroke();
    ctx.fillStyle='#f7e8ce';ctx.font='bold 10px monospace';
    ctx.fillText('LOOPHOLE',cx-w*.38,ground+27,Math.max(36,w-13));
    ctx.restore();
  };
  const drawSprayGauge=(ctx:CanvasRenderingContext2D,x:number,y:number,w:number,h:number)=>{
    const gap=3,segment=(w-gap*2)/3,units=sprayGauge*3;
    for(let i=0;i<3;i++){
      const sx=x+i*(segment+gap),fill=clamp(units-i,0,1);
      ctx.fillStyle='#18131e';ctx.fillRect(sx,y,segment,h);
      ctx.strokeStyle='#eee5d6';ctx.lineWidth=1;ctx.strokeRect(sx+.5,y+.5,segment-1,h-1);
      if(fill>0){ctx.fillStyle=boostActive()?'#e0287a':'#d7ff00';ctx.fillRect(sx+2,y+2,Math.max(0,(segment-4)*fill),h-4)}
    }
  };
  const drawObstacle=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    if(o.collected)return;
    switch(o.kind){
      case 'rail':drawRail(ctx,o);break;
      case 'drone':drawDeliveryDrone(ctx,o);break;
      case 'accept':drawAccept(ctx,o);break;
      case 'popup':drawConsent(ctx,o);break;
      case 'token':drawToken(ctx,o);break;
      case 'gap':drawLoophole(ctx,o);break;
    }
  };
  const tileLayer=(ctx:CanvasRenderingContext2D,key:string,y:number,height:number,parallax:number,opacity=1)=>{
    // Pre-rasterized clouds and clipped source rectangles keep rendering within
    // the visible camera instead of drawing 3+ full 1280px tiles per layer.
    const img=art?.cloudRaster[key]??art?.images[key];if(!img)return false;
    const width=1280,shift=((distance*parallax)%width+width)%width;
    const srcScale=img.width/width;
    ctx.save();ctx.globalAlpha=opacity;
    const first=Math.floor((viewLeft+shift)/width),last=Math.floor((viewRight+shift-.0001)/width);
    for(let tile=first;tile<=last;tile++){
      const tileX=tile*width-shift;
      const from=Math.max(viewLeft,tileX),to=Math.min(viewRight,tileX+width);
      const span=to-from;
      // Source is a 1024px PNG, scenery is 1280 logical world units wide.
      // Crop in source pixels, then draw only the visible logical-world span.
      if(span>0)ctx.drawImage(img,(from-tileX)*srcScale,0,span*srcScale,img.height,from,y,span,height);
    }
    ctx.restore();
    return true;
  };
  const drawBackdrop=(ctx:CanvasRenderingContext2D,portrait:boolean,topWorld:number)=>{
    // Illustrated 2.5-D city plus paper-cut cloud canopy; foreground remains independent.
    // Keep the board at the sidewalk centerline; no enlarged paper wallpaper.
    const sky=ctx.createLinearGradient(0,topWorld,0,ground);
    sky.addColorStop(0,'#170d19');sky.addColorStop(.47,'#46203e');
    sky.addColorStop(.76,'#d92a82');sky.addColorStop(1,'#2d1b36');
    ctx.fillStyle=sky;ctx.fillRect(-1400,topWorld,3200,ground-topWorld+90);
    if(art?.images.cloudsNear&&art?.images.dataCity){
      // Give each plane a meaningful silhouette and leave the factory visible.
      const cityFactor=.19;
      // Fine paper clouds drift behind the industrial skyline at a slower depth.
      tileLayer(ctx,'cloudsFar',74,92,.025,.78);
      // Align the city's opaque lower edge with the retaining wall's opaque top.
      tileLayer(ctx,'dataCity',86,230,cityFactor,1);
      // Keep the cloudbank's top edge behind the existing HUD in both views.
      // Its canvas starts at the screen top; only the rounded underside is exposed.
      const cloudNearY=portrait?topWorld+2:-10;
      const cloudNearH=portrait?310:190;
      const cityShift=((distance*cityFactor)%1280+1280)%1280;
      tileLayer(ctx,'cloudsNear',cloudNearY,cloudNearH,.068,1);
            // Plumes start at city chimney positions, follow city parallax and fade
      // upward INTO the near-cloud silhouette instead of floating separately.
      ctx.save();
      for(let tile=-1280-cityShift;tile<1400;tile+=1280){
        for(const [i,stack] of [[44,199],[216,180],[484,179],[744,183],[1024,183]] as const){
          const x=tile+i;
          if(x<viewLeft-42||x>viewRight+42)continue;
          const top=Math.min(stack-49,cloudNearY+cloudNearH*.8);
          for(let puff=0;puff<10;puff++){
            const t=puff/9,cy=stack+(top-stack)*t;
            const cx=x+t*8+Math.sin(t*4.6+i*.037+elapsed*.62)*7*t;
            const radius=2.6+t*6.8;
            ctx.beginPath();ctx.ellipse(cx,cy,radius*1.04,radius,0,0,Math.PI*2);
            ctx.fillStyle=`rgba(248,218,225,${(.7-t*.61).toFixed(3)})`;
            ctx.fill();
          }
        }
      }
      ctx.restore();
            // Do not bake coins or obstacles into the scenery. Retaining wall is
      // behind the actor, never on top of the skating surface.
      tileLayer(ctx,'graffitiWall',239,61,.32,.97);
      // Image holds the curb, textured sidewalk and distinct asphalt lanes.
      // The board baseline sits near the sidewalk center; no black line stands in for a floor.
      // This is physical world geometry: sidewalk and attached obstacles
      // MUST move in perfect lockstep. Never use parallax on the ground.
      tileLayer(ctx,'road',295,90,1,1);
      return;
    }
    // Safe fallback to the former clearly framed art; never a blank stage.
    const far=art?.images.far;
    if(far){const offset=(distance*.2)%640;ctx.drawImage(far,-offset,0,640,360);ctx.drawImage(far,640-offset,0,640,360)}
    const skyline=art?.images.skyline;
    if(skyline){const offset=(distance*.12)%640;ctx.drawImage(skyline,-offset,200,640,76);ctx.drawImage(skyline,640-offset,200,640,76)}
    ctx.fillStyle='#39333b';ctx.fillRect(-300,ground,1500,80);
    ctx.fillStyle='#d9d3c5';ctx.fillRect(-300,ground,1500,4);
  };
  const draw=(ctx:CanvasRenderingContext2D,w:number,h:number)=>{
    // Landscape remains 640x360; tablet mode is an actual portrait camera,
    // not a letterboxed landscape canvas. The sidescroller still uses the
    // same physics coordinates and a 450-unit horizontal reaction window.
    ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.fillStyle='#0d0b12';ctx.fillRect(0,0,w,h);
    const portrait=(host.getAttribute('layout')==='portrait'&&matchMedia('(pointer:coarse)').matches)||w/h<1.05;
    const portraitHeight=ground+40;
    const scale=portrait?Math.min(w/450,h/portraitHeight):Math.min(w/640,h/360);
    const dx=portrait?(w-450*scale)/2-35*scale:(w-640*scale)/2;
    const dy=portrait?h-portraitHeight*scale:(h-360*scale)/2;
    ctx.setTransform(scale,0,0,scale,dx,dy);
    viewLeft=-dx/scale;viewRight=(w-dx)/scale;
    const reducedMotion=matchMedia('(prefers-reduced-motion: reduce)').matches;
    const showCourierHint=!eye&&objects.some(o=>o.kind==='drone'&&o.intro&&o.x<viewRight-32&&o.x+o.w>playerX-14);
    drawBackdrop(ctx,portrait,-dy/scale);
    for(const o of objects)drawObstacle(ctx,o);
    if(eye){
      drawScanLane(ctx,eye,playerX,ground);
      drawCookieEye(ctx,eye,ground,elapsed,reducedMotion,canJamEye(eye));
    }
    // This opt-in developer-only visual fixture uses the production renderer.
    // It is not part of gameplay, and is never displayed without the QA attr.
    if(host.hasAttribute('data-qa-consent'))
      drawObstacle(ctx,{kind:'popup',x:225,w:144,scored:false,collected:false,deflected:false});
    // QA fixtures exercise production geometry (not simplified test drawings).
    if(host.hasAttribute('data-qa-rail-size')){
      const w=Number(host.getAttribute('data-qa-rail-size'))||70;
      drawRail(ctx,{kind:'rail',x:280,w,scored:false,collected:false,deflected:false});
    }
    if(host.hasAttribute('data-qa-accept'))
      drawAccept(ctx,{kind:'accept',x:315,w:160,scored:false,collected:false,deflected:false});
    // QA-only obstacle at a fixed WORLD position verifies the pavement
    // and actual ACCEPT buttons scroll at exactly the same world velocity.
    if(host.hasAttribute('data-qa-ground-scroll'))
      drawAccept(ctx,{kind:'accept',x:980-distance,w:160,scored:false,collected:false,deflected:false});
    if(host.hasAttribute('data-qa-token'))
      drawToken(ctx,{kind:'token',power:'shield',x:310,w:26,scored:false,collected:false,deflected:false});
    if(host.hasAttribute('data-qa-loophole'))
      drawLoophole(ctx,{kind:'gap',x:270,w:100,scored:false,collected:false,deflected:false});
    if(boostActive()){
      const pulse=.72+.18*Math.sin(elapsed*34),left=playerX-30,base=boardY-30;
      ctx.fillStyle='#E0287A';ctx.beginPath();ctx.moveTo(left,base-8);ctx.lineTo(left-29*pulse,base);ctx.lineTo(left,base+7);ctx.closePath();ctx.fill();
      ctx.fillStyle='#D7FF00';ctx.beginPath();ctx.moveTo(left-2,base-4);ctx.lineTo(left-21*pulse,base);ctx.lineTo(left-2,base+3);ctx.closePath();ctx.fill();
    }
    drawSkater(ctx);
    if(sprayBurst)drawSprayJam(ctx,sprayBurst,reducedMotion);
    if(trickCalloutLeft>0){ctx.fillStyle='#D7FF00';ctx.font='bold 10px monospace';ctx.textAlign='center';ctx.fillText(trickCallout,playerX,Math.max(84,boardY-74));ctx.textAlign='left'}
    if(grinding){ctx.fillStyle='#E0287A';const y=support?surfaceY(support):railSurfaceY();for(let i=0;i<3;i++)ctx.fillRect(playerX-8-i*7,y-2+(i%2)*3,5,2)}
    if(portrait){
      const t=-dy/scale;
      ctx.fillStyle='rgba(17,12,20,.97)';ctx.fillRect(35,t,450,98);
      ctx.fillStyle='#d7ff00';ctx.font='bold 19px monospace';
      ctx.fillText('CLAUSES  '+score(),48,t+29);
      ctx.fillStyle='#f3ebde';ctx.font='bold 12px monospace';
      ctx.fillText('TIER '+tier()+'   BEST '+(host as any).best,48,t+51);
      ctx.fillStyle=boostActive()?'#d7ff00':'#e4cbd7';ctx.font='bold 11px monospace';
      ctx.fillText('TRICKS '+tricksUsed+'/'+trickLimit()+'   SPRAY',48,t+72);
      drawSprayGauge(ctx,246,t+63,82,10);
      ctx.fillText(boostActive()?'2X':'HOLD Ø',340,t+72);
      ctx.fillStyle='#e0287a';ctx.font='bold 10px monospace';
      ctx.fillText(grinding?'GRIND — RELEASE U TO POP':'U=OLLIE/GRIND  •  A=TRICK  •  Ø=HOLD BOOST',48,t+91);
      ctx.fillStyle='#b8aaba';ctx.font='bold 10px monospace';
      if(!eye&&!showCourierHint)ctx.fillText((shield?'SHIELD  ':'')+(trick2Unlocked?'TRICK2 READY':'TRICK2 AT 80')+'  •  '+(practiceDrones?'DRONE PRACTICE':'STREET '+stationaryClearCount()+'/4'),48,t+124);
    }else{
      ctx.fillStyle='rgba(17,12,20,.93)';ctx.fillRect(0,0,640,71);
      ctx.fillStyle='#D7FF00';ctx.font='bold 18px monospace';ctx.fillText('CLAUSES SKIPPED  '+score(),14,27);
      ctx.fillStyle='#F3EBDE';ctx.font='bold 12px monospace';
      ctx.fillText('TIER '+tier(),14,47);ctx.fillText('COMBO x'+comboMultiplier(),68,47);
      ctx.fillText('CLEAR '+stationaryClearCount()+'/4',151,47);
      ctx.fillText('TRICK '+tricksUsed+'/'+trickLimit(),236,47);
      ctx.fillText('SPRAY',324,47);drawSprayGauge(ctx,370,38,66,10);
      ctx.fillStyle=boostActive()||grindBoostLeft>0?'#D7FF00':'#aaa1b3';ctx.fillText(boostActive()?'2X':'R',441,47);
      ctx.fillStyle='#D7FF00';ctx.fillText('BEST '+(host as any).best,540,27);
      ctx.font='bold 9px monospace';
      ctx.fillText((shield?'[SHIELD] ':'')+(trick2Unlocked?'[TRICK2]':'[UPGRADE 80]')+(deliveryUnlocked?' [DRONES]':''),496,65);
      ctx.fillStyle='#E0287A';ctx.font='bold 10px monospace';
      if(grinding)ctx.fillText('GRINDING THE FINE PRINT — RELEASE U TO POP!',170,65);
      else ctx.fillText('U / ↑: OLLIE + HOLD GRIND  •  SPACE / A: TRICK  •  HOLD R / Ø: BOOST',12,65);
    }
    const cueX=portrait?48:14,cueY=portrait?-dy/scale+105:78;
    if(eye?.phase==='warning'||eye?.phase==='scan'){
      const control=eye.lane==='high'?'HIGH SCAN / STAY LOW':
        eye.phase==='scan'||eye.age>=eyeOllieCueTime?'LOW SCAN / OLLIE NOW':'LOW SCAN / GET READY';
      drawEyeCallout(ctx,cueX,cueY,control,'warning',eye);
      if(canJamEye(eye))drawEyeCallout(ctx,cueX,cueY+28,portrait?'HOLD Ø TO JAM':'HOLD R TO JAM','open');
    }else if(eye?.phase==='disabled'&&eye.stomped){
      drawEyeCallout(ctx,cueX,cueY,'COOKIE EYE DISABLED','open');
    }else if(eye?.phase==='recover'){
      drawEyeCallout(ctx,cueX,cueY,eye.jammed?'LENS JAMMED / STOMP':'STOMP THE LIME PAD','open');
      if(scanSlowLeft>0)drawEyeCallout(ctx,cueX,cueY+28,'SCANNED / SLOWED','warning');
    }else if(scanSlowLeft>0){
      drawEyeCallout(ctx,cueX,cueY,'SCANNED / SLOWED','warning');
    }else if(showCourierHint){
      drawEyeCallout(ctx,cueX,cueY,'TERMS RUNNER / SKATE UNDER','open');
    }
    if(visualFlash>0&&!reducedMotion){ctx.fillStyle='rgba(238,40,122,.12)';ctx.fillRect(0,0,640,360)}
    ctx.restore();
  };
  const result=()=>({
    cause,
    causeLine:({accept:'YOU ACCEPTED EVERYTHING. THEY THANK YOU.',popup:'THE POP-UP WON. AGAIN.',gap:'YOU FELL THROUGH A LOOPHOLE.',drone:'DELIVERY DRONE TOOK THE LINE.','cookie-eye':'THE COOKIE EYE CAUGHT YOUR BOARD.'} as Record<string,string>)[cause]||'READ THE FINE PRINT',
    stats:{distancePx:Math.floor(distance),hazardsCleared,grindMs:Math.floor(grindMs),platformLandings,platformGrinds,combo,longestCombo,comboTimer:Math.round(comboTimer*100)/100,shieldsUsed,runSpeed:Math.round(speed()),normalSpeed:Math.round(normalSpeed()),speedMultiplier:boostActive()?2:1,tricksUsed,trickLimit:trickLimit(),trick2Unlocked,trickAvailable:!support&&!grinding&&lastSurface==='air'&&boardY<ground-1&&tricksUsed<trickLimit(),sprayGauge:Math.round(sprayGauge*10000)/10000,sprayCans:Math.floor(sprayGauge*3+1e-6),boostHeld:boostDown,boostActive:boostActive(),boostExhausted,rocketBoostLeft:Math.round(sprayGauge*boostSeconds*100)/100,grindBoostLeft:Math.round(grindBoostLeft*100)/100,stationaryCleared:{...clearedStationary},stationaryClearCount:stationaryClearCount(),deliveryUnlocked,deliveryDrones:objects.filter(o=>o.kind==='drone').length,shieldDeflections,boardY:Math.round(boardY),jumpCount,grinding,supportX:support?.x??null,supportWidth:support?.w??null,supportTop:support?surfaceY(support):null,
      scansHit,eyesJammed,eyesStomped,scanSlowLeft:Math.round(scanSlowLeft*100)/100,
      eye:eye?{phase:eye.phase,lane:eye.lane,age:eye.age,padReady:eyePadReady(eye),canJam:canJamEye(eye)}:null
    }
  });
  const releaseInput=()=>{trickDown=false;boostDown=false;boostExhausted=false;if(grinding)railPop();held=false;};
  reset();
  return {start:reset,input,update,draw,score,over:()=>!alive&&bailRemaining===0,result,setSkin,releaseInput} satisfies GameAPI;
});
