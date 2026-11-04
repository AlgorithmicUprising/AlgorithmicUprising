import { defineArcade, type GameAPI } from '../../../core/src/engine';
import chunksData from './chunks.json';

// Grind the Terms v0.2 preview: mechanics separated from the AU-only skin assets.
type HazardKind = 'accept' | 'popup' | 'modal' | 'gap' | 'rail' | 'token';
type Power = 'shield' | 'airboost';
type Chunk = { id: string; tier: number; width: number; objects: Array<{at:number;kind:HazardKind;w:number;power?:Power}> };
type Obstacle = { x:number; w:number; kind:HazardKind; power?:Power; scored:boolean; collected:boolean; deflected:boolean };
type Anim = 'run'|'idle'|'land'|'ollie'|'double'|'bail'|'grind'|'railpop'|'flip';
type AtlasGrid={cellW:number;cellH:number;columns:number;anchorX?:number;anchorY?:number;displayScale?:number};
type RailVisual={surfaceCellY:number;groundCellY:number;drawHeight:number;clipTopCellY:number};
type Art = { images:Record<string,HTMLImageElement>; palette?:Record<string,string>; grid?:Record<string,AtlasGrid>; rail?:RailVisual; anims?:Record<string,{start:number;frames:number;fps:number;loop?:boolean}>; name:string };
const chunks = chunksData as Chunk[];
const clamp = (n:number,low:number,high:number)=>Math.max(low,Math.min(high,n));

// No global listeners: multiple embedded games are independent Web Components.
defineArcade('grind-the-terms','GRIND THE TERMS',(emit,host)=>{
  const ground = 300, playerX = 140, gravity = 1800, jumpVelocity = -620, railPopVelocity = -380;
  const baseSpeed=180;
  let boardY=ground, lastBoardY=ground, vy=0, elapsed=0, distance=0;
  let bonus=0, extraClauses=0, grindDistance=0, totalGrindDistance=0, grindMs=0;
  let alive=true, bailRemaining=0, cause='accept', held=false, grinding=false;
  // A supporting surface may be a rail or a flat-topped consent box.
  let support:Obstacle|null=null,platformLandings=0,platformGrinds=0;
  let jumpCount=0, airBoost=false, shield=false, shieldsUsed=0, hazardsCleared=0;
  let bufferLeft=0, coyoteLeft=0, stateTime=0, landTimer=0;
  let combo=0, longestCombo=0, lastSurface='ground';
  let speedEnabled=false, acceleration=0, grindCharge=0, grindBoostLeft=0, boostTriggered=false, shieldDeflections=0;
  let objects:Obstacle[]=[];
  let nextChunk=0, lastChunkId='', firstChunk=true;
  let art:Art|null=null,skinRequest=0;
  let rngState=0x11b00c5;
  let visualFlash=0;
  let currentAnim:Anim='run';

  const rng=()=>{rngState=(Math.imul(1664525,rngState)+1013904223)>>>0;return rngState/4294967296};
  const tier=()=>elapsed<20?1:elapsed<45?2:elapsed<90?3:4;
  // SPACE (keyboard) / A (cabinet) is a TOGGLE, not a jump input.
  // A modest +10% speed toggle; earned long-grind momentum contributes +7% briefly.
  const normalSpeed=()=>clamp(baseSpeed+elapsed*1.72,baseSpeed,460);
  // The toggle ramps to exactly 2x the current baseline. Grind momentum remains independent.
  const speed=()=>normalSpeed()*(1+acceleration)*(grindBoostLeft>0?1.07:1);
  const score=()=>Math.floor(distance/48)+Math.floor(extraClauses)+Math.floor(totalGrindDistance/32)*2+Math.floor(bonus);
  // Grounding contract (source atlas cells are 144x112).
  // Each obstacle is drawn relative to its *visible* feet / button base,
  // not the transparent cell edge. Top collision = actual artwork top.
  // Keep geometry independent of skin selection to avoid mid-run physics jumps.
  const sourceCellHeight=112;
  const surfaces={
    rail:   {top:53,bottom:82,height:77},   // metal coping / feet
    accept: {top:45,bottom:92,height:72},   // original yellow ACCEPT ALL body
    popup:  {top:24,bottom:105,height:94},  // pink window frame / bottom
    modal:  {top:27,bottom:101,height:130}  // tall agreement panel / bottom
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
    kind==='accept'||kind==='popup'||kind==='modal'?surfaceTopY(kind):ground;
  const surfaceY=(o:Obstacle)=>o.kind==='rail'?railSurfaceY():flatTopY(o.kind);
  const overlaps=(o:Obstacle)=>o.x<playerX+16&&o.x+o.w>playerX-16;
  const state=(animation:Anim)=>{if(currentAnim!==animation){currentAnim=animation;stateTime=0}};
  const reset=()=>{
    boardY=ground;lastBoardY=ground;vy=0;elapsed=0;distance=0;bonus=0;extraClauses=0;
    grindDistance=0;totalGrindDistance=0;grindMs=0;alive=true;bailRemaining=0;cause='accept';
    held=false;grinding=false;support=null;platformLandings=0;platformGrinds=0;jumpCount=0;airBoost=false;shield=false;shieldsUsed=0;
    hazardsCleared=0;bufferLeft=0;coyoteLeft=.08;stateTime=0;landTimer=0;
    combo=0;longestCombo=0;lastSurface='ground';objects=[];nextChunk=380;lastChunkId='';firstChunk=true;
    speedEnabled=false;acceleration=0;grindCharge=0;grindBoostLeft=0;boostTriggered=false;shieldDeflections=0;
    rngState=(Number(host.getAttribute('seed'))||0x11b00c5)>>>0;visualFlash=0;currentAnim='run';
  };
  const land=()=>{
    boardY=ground;vy=0;grinding=false;jumpCount=0;coyoteLeft=.08;
    if(lastSurface!=='ground'){landTimer=.12;state('land')}
    lastSurface='ground';combo=0;
    if(bufferLeft>0){bufferLeft=0;ollie()}
  };
  const ollie=(secondary=false)=>{
    if(!alive||bailRemaining>0)return;
    if(secondary){if(jumpCount>=2)return;jumpCount=2;vy=-520;state('double');emit('game:double-jump',{alwaysAvailable:true})}
    else{jumpCount=1;vy=jumpVelocity;state('ollie')}
    support=null;grinding=false;landTimer=0;coyoteLeft=0;bufferLeft=0;lastSurface='air';
  };
  const railPop=()=>{
    const from=support?.kind||'rail';support=null;grinding=false;grindCharge=0;boostTriggered=false;
    vy=railPopVelocity;boardY-=3;lastSurface='air';jumpCount=1;
    state('railpop');emit('game:grind-end',{surface:from,distancePx:Math.floor(grindDistance),grindMs:Math.floor(grindMs)});
  };
  const input=(key:string,down:boolean)=>{
    if(key==='speed'){
      if(down&&alive){speedEnabled=!speedEnabled;emit('game:speed',{enabled:speedEnabled,speedPxPerSecond:Math.round(speed())})}
      return;
    }
    if(key==='special')return; // Ø cabinet button is reserved for a future special.
    if(key!=='tap'&&key!=='up')return;
    if(down&&!held){
      if(grinding){railPop()}
      else if(support||boardY>=ground-1||coyoteLeft>0){ollie()}
      else if(jumpCount===1){ollie(true)}
      else bufferLeft=.1;
    }
    if(!down&&held&&grinding)railPop();
    held=down;
  };
  const comboBonus=(base:number)=>{
    const multiplier=combo>=3?3:combo===2?2:combo===1?1.5:1;
    bonus+=base*multiplier;
    combo++;longestCombo=Math.max(longestCombo,combo);
  };
  const handleCollision=(o:Obstacle)=>{
    if(shield){shield=false;shieldsUsed++;shieldDeflections++;o.deflected=true;bonus+=1;
      // Consent forms are persistent level geometry, never collectible pickups.
      // The shield absorbs impact and bounces Fony clear; the form stays visible.
      boardY=Math.min(boardY,flatTopY(o.kind)-4);vy=-260;support=null;grinding=false;
      emit('game:shield',{used:true,blocked:o.kind});return}
    alive=false;cause=o.kind;bailRemaining=.55;state('bail');
    emit('game:bail',{cause,score:score()});
  };
  const collect=(o:Obstacle)=>{
    if(o.collected)return;
    o.collected=true;bonus+=10;
    // Double jump is permanently unlocked; older AIR BOOST tokens now grant protection.
    shield=true;airBoost=false;
    emit('game:power',{power:o.power||'shield',collected:true});
  };
  const emitChunk=()=>{
    const choices=chunks.filter(c=>c.tier<=tier()&&(!firstChunk||c.id==='intro-rails')&&c.id!==lastChunkId);
    const list=choices.length?choices:chunks.filter(c=>c.tier<=tier()&&(!firstChunk||c.id==='intro-rails'));
    // A wide first consent box always follows the opening practice rail.
    const picked=lastChunkId==='intro-rails'?(chunks.find(c=>c.id==='intro-accept')||list[0]):list[Math.floor(rng()*list.length)];
    if(!picked)return;
    firstChunk=false;lastChunkId=picked.id;
    for(const item of picked.objects){
      objects.push({x:playerX+nextChunk+item.at-distance,w:item.w,kind:item.kind,power:item.power,scored:false,collected:false,deflected:false});
    }
    nextChunk+=picked.width;
  };
  const update=(dt:number)=>{
    if(!alive){bailRemaining=Math.max(0,bailRemaining-dt);stateTime+=dt;return}
    dt=Math.min(dt,.05);elapsed+=dt;stateTime+=dt;landTimer=Math.max(0,landTimer-dt);
    acceleration=clamp(acceleration+(speedEnabled?dt/.45:-dt/.35),0,1);
    grindBoostLeft=Math.max(0,grindBoostLeft-dt);
    if(grinding){grindCharge+=dt;if(grindCharge>=.85&&!boostTriggered){boostTriggered=true;grindBoostLeft=2.2;emit('game:boost',{source:'extended-grind',durationMs:2200,bonusPercent:7})}}
    else {grindCharge=0;boostTriggered=false;}
    visualFlash=Math.max(0,visualFlash-dt);
    bufferLeft=Math.max(0,bufferLeft-dt);
    if(!grinding&&boardY>=ground-1)coyoteLeft=.08;
    else coyoteLeft=Math.max(0,coyoteLeft-dt);
    const moved=speed()*dt;
    distance+=moved;
    while(nextChunk<distance+790)emitChunk();
    // Move obstacle geometry once, before resolving support or collisions.
    for(const o of objects)o.x-=moved;
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
          support=o;boardY=top;vy=0;grinding=true;grindCharge=0;boostTriggered=false;lastSurface='rail';
          state('grind');emit('game:grind-start',{surface:'rail',score:score()});
        }
        continue;
      }
      if(o.kind==='token'){
        if(overlap&&!o.collected&&Math.abs(boardY-(ground-58))<50)collect(o);
        continue;
      }
      if(!overlap||o.collected||o.deflected||!alive||o===support)continue;
      if(o.kind==='gap'){
        if(boardY>ground-10)handleCollision(o);
        continue;
      }
      // ACCEPT, POPUP and MODAL all have flat, skatable tops.
      // Catch descending from above; hitting the vertical side still bails.
      const top=flatTopY(o.kind);
      if(!support&&vy>=0&&lastBoardY<=top+12&&boardY>=top-10&&boardY<=top+Math.max(26,Math.abs(vy)*dt+12)){
        support=o;boardY=top;vy=0;lastSurface=o.kind;
        jumpCount=0;coyoteLeft=.08;landTimer=.12;platformLandings++;
        if(held){
          grinding=true;grindCharge=0;boostTriggered=false;platformGrinds++;state('grind');
          emit('game:grind-start',{surface:o.kind,score:score()});
        }else{
          grinding=false;state('land');
          emit('game:platform-land',{surface:o.kind,score:score()});
        }
        continue;
      }
      if(boardY>top+10)handleCollision(o);
    }
    if(!support&&boardY>=ground){land()}
    if(!support&&boardY<ground-1&&landTimer===0&&alive){
      if(currentAnim!=='ollie'&&currentAnim!=='double'&&currentAnim!=='railpop')state('ollie');
    }
    if(!support&&boardY>=ground&&landTimer===0)state('idle');
    if(support&&!grinding&&landTimer===0)state('idle');
    for(const o of objects){
      if(o.kind==='token'||o.kind==='rail'||o.scored||o.collected)continue;
      if(o.x+o.w<playerX-15){
        o.scored=true;hazardsCleared++;
        const base=o.kind==='modal'?10:o.kind==='popup'?5:o.kind==='gap'?8:3;
        comboBonus(base);
        const near=Math.abs(boardY-(ground-(o.kind==='modal'?98:o.kind==='popup'?62:30)))<10;
        if(near){bonus+=1;emit('game:near-miss',{score:score()})}
      }
    }
    objects=objects.filter(o=>o.x+o.w>-45);
  };

  async function setSkin(url:string|null){
    const request=++skinRequest;
    if(!url){art=null;emit('game:skin-loaded',{skin:'placeholder',usingPlaceholder:true});return}
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
      if(data.rail){const r=data.rail,g=data.grid?.hazards; if(!g||!Number.isFinite(r.groundCellY)||!Number.isFinite(r.drawHeight)||!Number.isFinite(r.surfaceCellY)||!Number.isFinite(r.clipTopCellY)||r.drawHeight<=0||r.clipTopCellY<0||r.clipTopCellY>=r.surfaceCellY||r.surfaceCellY>=r.groundCellY||r.groundCellY>g.cellH)throw new Error('Invalid rail surface metadata')}
      art={images,name:data.name||'Fony',palette:data.palette,grid:data.grid,rail:data.rail,anims:data.anims};
      emit('game:skin-loaded',{skin:'au',usingPlaceholder:false,assets:Object.keys(images)});
    }catch(error){if(request!==skinRequest)return;art=null;emit('game:error',{code:'SKIN_LOAD_FAILED',message:String(error),usingPlaceholder:true})}
  }

  const drawSheet=(ctx:CanvasRenderingContext2D,key:string,col:number,row:number,x:number,y:number,w:number,h:number)=>{
    const asset=art?.images[key];if(!asset)return false;
    const isSkater=key==='skater',cfg=art?.grid?.[key],cellW=cfg?.cellW??(isSkater?80:144),cellH=cfg?.cellH??(isSkater?94:112);
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
    if(!alive)animation='bail';else if(grinding)animation='grind';else if((support||boardY>=ground-1)&&landTimer<=0)animation='idle';
    const map={run:[0,6,12],idle:[6,4,6],land:[10,2,16],ollie:[12,5,14],double:[17,4,12],bail:[21,6,12],grind:[27,4,10],railpop:[31,4,12],flip:[35,4,14]} as const;
    const [start,frames,fps]=map[animation];
    const looping=animation==='run'||animation==='idle'||animation==='grind';
    const frame=looping?Math.floor(stateTime*fps)%frames:Math.min(frames-1,Math.floor(stateTime*fps));
    // The old run sprites are leg-running poses. Ground travel now uses the
    // stable onboard Fony stance from the approved pose atlas; no sprint loop.
    const rolling=alive&&!grinding&&(animation==='run'||animation==='idle'||animation==='land');
    const idx=rolling&&art?.images.skater?29:start+frame;
    const cfg=art?.grid?.skater;
    const width=cfg?.cellW??80,height=cfg?.cellH??94,columns=cfg?.columns??8;
    const anchorX=cfg?.anchorX??width/2,anchorY=cfg?.anchorY??height-4;
    const zoom=cfg?.displayScale??1;
    // The world point is Fony's skateboard contact, never the changing sprite top-left.
    // Bail frames anchor at the impact position and stop at the final frame (no looping).
    const poseY=alive?boardY:ground;
    // The approved source sheet's RUN poses are running silhouettes without
    // a deck. Put a proper board under those poses so Fony visibly SKATES.
    // Grind and flip artwork already includes the original green deck.
    if(alive&&(animation==='run'||animation==='land')&&art?.images.skater){
      ctx.save();
      ctx.fillStyle='#121019';ctx.beginPath();ctx.roundRect(playerX-27,poseY-6,54,6,3);ctx.fill();
      ctx.fillStyle='#e0287a';ctx.fillRect(playerX-20,poseY-5,40,3);
      ctx.fillStyle='#d7ff00';ctx.fillRect(playerX-10,poseY-5,20,2);
      ctx.fillStyle='#121019';
      for(const x of [playerX-17,playerX+16]){
        ctx.beginPath();ctx.arc(x,poseY+2,4,0,Math.PI*2);ctx.fill();
        ctx.fillStyle='#f4eee1';ctx.fillRect(x-1,poseY+1,2,2);ctx.fillStyle='#121019';
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
    if(drawSheet(ctx,'skater',idx%columns,Math.floor(idx/columns),playerX-anchorX*zoom,poseY-anchorY*zoom,width*zoom,height*zoom))return;
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
    ctx.save();ctx.lineJoin='round';
    // Clean, opaque remake of the original ACCEPT ALL button silhouette.
    ctx.fillStyle='#0c0a11';ctx.beginPath();ctx.roundRect(x-3,top-2,w+6,h+3,10);ctx.fill();
    ctx.fillStyle='#627f0e';ctx.beginPath();ctx.roundRect(x+1,top+4,w-2,h-6,8);ctx.fill();
    const g=ctx.createLinearGradient(0,top,0,ground);
    g.addColorStop(0,'#eeff72');g.addColorStop(.43,'#d7ff00');g.addColorStop(1,'#9eae14');
    ctx.fillStyle=g;ctx.beginPath();ctx.roundRect(x+2,top+1,w-4,h-6,7);ctx.fill();
    ctx.strokeStyle='#283019';ctx.lineWidth=2;ctx.stroke();
    ctx.fillStyle='#fafdc3';ctx.fillRect(x+12,top+4,Math.max(8,w-24),2);
    ctx.fillStyle='#151216';ctx.font='bold 13px monospace';
    ctx.textBaseline='middle';ctx.textAlign='center';
    ctx.fillText('ACCEPT ALL',x+w/2,top+(h-6)/2+1,Math.max(32,w-12));
    ctx.fillStyle='#17121b';ctx.fillRect(x+12,ground-5,10,5);ctx.fillRect(x+w-23,ground-5,10,5);
    ctx.restore();
  };
  const drawConsent=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    const modal=o.kind==='modal',top=flatTopY(o.kind),x=o.x,w=o.w,h=ground-top;
    ctx.save();
    ctx.fillStyle='#0e0b14';ctx.fillRect(x-4,top-3,w+8,h+3);
    ctx.fillStyle='#f6efe2';ctx.fillRect(x,top,w,h);
    ctx.fillStyle='#d72c80';ctx.fillRect(x,top,w,22);
    ctx.fillStyle='#15111b';ctx.font='bold 11px monospace';
    ctx.fillText(modal?'TERMS / DATA':'CONSENT?',x+7,top+15);
    ctx.fillStyle='#1a1621';ctx.fillRect(x+w-17,top+4,12,13);
    ctx.fillStyle='#f7e7ef';ctx.font='bold 10px monospace';ctx.fillText('×',x+w-15,top+14);
    ctx.font='9px monospace';ctx.fillStyle='#231b2c';
    for(let i=0;i<(modal?4:2);i++){
      const rowY=top+34+i*15;
      if(rowY>ground-29)break;
      ctx.strokeStyle='#221a26';ctx.lineWidth=1.6;ctx.strokeRect(x+8,rowY-8,9,9);
      ctx.fillText(['Share my data','Track activity','Personalize ads','Agree to all'][i],x+22,rowY,Math.max(20,w-27));
    }
    ctx.fillStyle='#1d1728';ctx.fillRect(x+7,ground-22,w-14,17);
    ctx.fillStyle='#e0287a';ctx.fillRect(x+9,ground-20,w-18,13);
    ctx.fillStyle='#130d1b';ctx.font='bold 9px monospace';
    ctx.textAlign='center';ctx.fillText('I AGREE',x+w/2,ground-11);
    ctx.strokeStyle='#15121a';ctx.lineWidth=2;ctx.strokeRect(x,top,w,h);
    if(o.deflected){
      ctx.fillStyle='#171119';ctx.fillRect(x+3,top+25,w-6,19);
      ctx.fillStyle='#d7ff00';ctx.font='bold 12px monospace';ctx.fillText('DENIED!',x+w/2,top+39);
    }
    ctx.restore();
  };
  const drawToken=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    // This is a collectible, never a consent form. Stable center and collision size.
    const x=o.x+o.w/2,cy=ground-66;
    const wobble=1+Math.sin(elapsed*7+o.x*.018)*.045;
    ctx.save();ctx.translate(x,cy);ctx.scale(wobble,1);
    ctx.fillStyle='rgba(215,255,0,.2)';ctx.beginPath();ctx.arc(0,0,22,0,Math.PI*2);ctx.fill();
    ctx.fillStyle='#0c0a13';ctx.beginPath();ctx.arc(0,0,18,0,Math.PI*2);ctx.fill();
    ctx.fillStyle='#d7ff00';ctx.beginPath();ctx.arc(0,0,15,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle='#f4ffae';ctx.lineWidth=2;ctx.beginPath();ctx.arc(0,0,11.5,0,Math.PI*2);ctx.stroke();
    if(o.power==='shield'){
      ctx.strokeStyle='#16121e';ctx.lineWidth=4;ctx.beginPath();ctx.ellipse(0,0,7.5,8.7,0,0,Math.PI*2);ctx.stroke();
      ctx.beginPath();ctx.moveTo(-10,11);ctx.lineTo(10,-11);ctx.stroke();
    }else{
      ctx.fillStyle='#16121e';ctx.beginPath();
      ctx.moveTo(2,-12);ctx.lineTo(-7,2);ctx.lineTo(0,2);ctx.lineTo(-3,12);
      ctx.lineTo(10,-4);ctx.lineTo(3,-4);ctx.lineTo(6,-12);ctx.closePath();ctx.fill();
    }
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
  const drawObstacle=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    if(o.collected)return;
    switch(o.kind){
      case 'rail':drawRail(ctx,o);break;
      case 'accept':drawAccept(ctx,o);break;
      case 'popup':case 'modal':drawConsent(ctx,o);break;
      case 'token':drawToken(ctx,o);break;
      case 'gap':drawLoophole(ctx,o);break;
    }
  };
  const tileLayer=(ctx:CanvasRenderingContext2D,key:string,y:number,height:number,parallax:number,opacity=1)=>{
    const img=art?.images[key];if(!img)return false;
    const width=1280,shift=((distance*parallax)%width+width)%width;
    ctx.save();ctx.globalAlpha=opacity;
    for(let x=-width-shift;x<1400;x+=width)ctx.drawImage(img,x,y,width,height);
    ctx.restore();
    return true;
  };
  const drawBackdrop=(ctx:CanvasRenderingContext2D,portrait:boolean,topWorld:number)=>{
    // Illustrated 2.5-D scene extracted from the approved punk-art mockup.
    // Keep the playable sidewalk at ground Y=300; no enlarged paper wallpaper.
    const sky=ctx.createLinearGradient(0,topWorld,0,ground);
    sky.addColorStop(0,'#170d19');sky.addColorStop(.47,'#46203e');
    sky.addColorStop(.76,'#d92a82');sky.addColorStop(1,'#2d1b36');
    ctx.fillStyle=sky;ctx.fillRect(-1400,topWorld,3200,ground-topWorld+90);
    if(art?.images.cloudsNear&&art?.images.dataCity){
      // The data-center chimneys and skyline are exposed below the torn paper clouds.
      tileLayer(ctx,'dataCity',132,143,.13,1);
      // Connect chimney mouths and legal-paper clouds with wisps that share
      // the CITY parallax offset. Render beneath the paper-cloud silhouettes.
      const cloudBottom=(portrait?topWorld+171:75)+(portrait?94:86);
      const cityShift=((distance*.13)%1280+1280)%1280;
      ctx.save();ctx.lineCap='round';
      for(let tile=-1280-cityShift;tile<1350;tile+=1280){
        for(const [i,px] of [40,214,490,736,1038].entries()){
          const x=tile+px,stackY=180+(i%3)*8,targetY=Math.min(stackY-14,cloudBottom-7);
          const flutter=Math.sin(elapsed*.7+i*1.8)*6;
          ctx.beginPath();ctx.moveTo(x,stackY);
          ctx.bezierCurveTo(x-16+flutter,stackY-30,x+16+flutter,targetY+29,x+flutter,targetY);
          ctx.strokeStyle='rgba(255,221,222,.66)';ctx.lineWidth=9;ctx.stroke();
          ctx.strokeStyle='rgba(245,185,204,.55)';ctx.lineWidth=3;ctx.stroke();
        }
      }
      ctx.restore();
      // These are two *separate* moving cloud layers. Distant paperwork is
      // atmospheric only; the nearer high-detail inked cloud stays compact.
      tileLayer(ctx,'cloudsFar',portrait?topWorld+35:69,portrait?97:80,.028,.28);
      tileLayer(ctx,'cloudsNear',portrait?topWorld+171:75,portrait?109:97,.065,.96);
      // Do not bake coins or obstacles into the scenery. Retaining wall is
      // behind the actor, never on top of the skating surface.
      tileLayer(ctx,'graffitiWall',239,61,.23,.97);
      // Image holds the curb, textured sidewalk and distinct asphalt lanes.
      // Everything sits at Y=300; no black line standing in for a floor.
      // This is physical world geometry: sidewalk and attached obstacles
      // MUST move in perfect lockstep. Never use parallax on the ground.
      tileLayer(ctx,'road',ground-5,90,1,1);
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
    const portrait=w/h<1.05;
    const scale=portrait?w/450:Math.min(w/640,h/360);
    const dx=portrait?-35*scale:(w-640*scale)/2;
    const dy=portrait?h-(ground+40)*scale:(h-360*scale)/2;
    ctx.setTransform(scale,0,0,scale,dx,dy);
    drawBackdrop(ctx,portrait,-dy/scale);
    for(const o of objects)drawObstacle(ctx,o);
    // This opt-in developer-only visual fixture uses the production renderer.
    // It is not part of gameplay, and is never displayed without the QA attr.
    if(host.hasAttribute('data-qa-consent')){
      for(const [kind,x,width] of [['popup',225,116],['modal',405,120]] as const)
        drawObstacle(ctx,{kind,x,w:width,scored:false,collected:false,deflected:false});
    }
    // QA fixtures exercise production geometry (not simplified test drawings).
    if(host.hasAttribute('data-qa-rail-size')){
      const w=Number(host.getAttribute('data-qa-rail-size'))||70;
      drawRail(ctx,{kind:'rail',x:280,w,scored:false,collected:false,deflected:false});
    }
    if(host.hasAttribute('data-qa-accept'))
      drawAccept(ctx,{kind:'accept',x:315,w:120,scored:false,collected:false,deflected:false});
    // QA-only obstacle at a fixed WORLD position verifies the pavement
    // and actual consent buttons scroll at exactly the same world velocity.
    if(host.hasAttribute('data-qa-ground-scroll'))
      drawAccept(ctx,{kind:'accept',x:980-distance,w:120,scored:false,collected:false,deflected:false});
    if(host.hasAttribute('data-qa-token'))
      drawToken(ctx,{kind:'token',power:'shield',x:310,w:26,scored:false,collected:false,deflected:false});
    if(host.hasAttribute('data-qa-loophole'))
      drawLoophole(ctx,{kind:'gap',x:270,w:100,scored:false,collected:false,deflected:false});
    drawSkater(ctx);
    if(grinding){ctx.fillStyle='#E0287A';const y=support?surfaceY(support):railSurfaceY();for(let i=0;i<3;i++)ctx.fillRect(playerX-8-i*7,y-2+(i%2)*3,5,2)}
    if(portrait){
      const t=-dy/scale;
      ctx.fillStyle='rgba(17,12,20,.97)';ctx.fillRect(35,t,450,98);
      ctx.fillStyle='#d7ff00';ctx.font='bold 19px monospace';
      ctx.fillText('CLAUSES  '+score(),48,t+29);
      ctx.fillStyle='#f3ebde';ctx.font='bold 12px monospace';
      ctx.fillText('TIER '+tier()+'   BEST '+(host as any).best,48,t+51);
      ctx.fillStyle=speedEnabled?'#d7ff00':'#e4cbd7';
      ctx.fillText('SPEED '+Math.round(speed())+(speedEnabled?'  FAST x2':''),48,t+72);
      ctx.fillStyle='#e0287a';ctx.font='bold 11px monospace';
      ctx.fillText(grinding?'GRIND! RELEASE U TO POP':'CONSENT = LAND / GRIND   •   Ø TOKENS = PICKUPS',48,t+91);
      ctx.fillStyle='#b8aaba';ctx.font='bold 12px monospace';
      ctx.fillText((shield?'SHIELD  ':'')+'DOUBLE JUMP ON',48,t+150);
    }else{
      ctx.fillStyle='rgba(17,12,20,.93)';ctx.fillRect(0,0,640,71);
      ctx.fillStyle='#D7FF00';ctx.font='bold 18px monospace';ctx.fillText('CLAUSES SKIPPED  '+score(),14,27);
      ctx.fillStyle='#F3EBDE';ctx.font='bold 12px monospace';ctx.fillText('TIER '+tier()+'   COMBO x'+(combo>=3?3:combo===2?2:combo===1?1.5:1),14,47);
      ctx.fillStyle='#D7FF00';ctx.fillText('BEST '+(host as any).best,485,27);
      ctx.fillStyle=speedEnabled||grindBoostLeft>0?'#D7FF00':'#aaa1b3';
      ctx.fillText('SPD '+Math.round(speed()),307,47);
      ctx.fillText((shield?'[SHIELD] ':'')+'[DOUBLE JUMP ON]',400,47);
      ctx.fillStyle='#E0287A';ctx.font='bold 11px monospace';
      if(elapsed<11)ctx.fillText('U / ↑: JUMP & HOLD GRIND  •  SPACE / A: 2x FAST',12,65);
      else if(grinding)ctx.fillText('GRINDING THE FINE PRINT — RELEASE TO POP!',170,65);
      else ctx.fillText('CONSENT FORMS = OBSTACLES  •  TOKENS = PICKUPS',12,65);
    }
    if(visualFlash>0&&!matchMedia('(prefers-reduced-motion: reduce)').matches){ctx.fillStyle='rgba(238,40,122,.12)';ctx.fillRect(0,0,640,360)}
    ctx.restore();
  };
  const result=()=>({cause,causeLine:({accept:'YOU ACCEPTED EVERYTHING. THEY THANK YOU.',popup:'THE POP-UP WON. AGAIN.',modal:'AGREE & CONTINUE? NOT THIS TIME.',gap:'YOU FELL THROUGH A LOOPHOLE.'} as Record<string,string>)[cause]||'READ THE FINE PRINT',stats:{distancePx:Math.floor(distance),hazardsCleared,grindMs:Math.floor(grindMs),platformLandings,platformGrinds,longestCombo,shieldsUsed,speedEnabled,acceleration:Math.round(acceleration*100)/100,runSpeed:Math.round(speed()),normalSpeed:Math.round(normalSpeed()),doubleJumpAlwaysOn:true,grindBoostLeft:Math.round(grindBoostLeft*100)/100,shieldDeflections,boardY:Math.round(boardY),jumpCount,grinding,supportX:support?.x??null,supportWidth:support?.w??null,supportTop:support?surfaceY(support):null}});
  reset();
  return {start:reset,input,update,draw,score,over:()=>!alive&&bailRemaining===0,result,setSkin} satisfies GameAPI;
});
