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
  const speed=()=>clamp((baseSpeed + elapsed*1.72)*(1+.10*acceleration+(grindBoostLeft>0?.07:0)),baseSpeed,460);
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
    if(secondary){if(!airBoost||jumpCount>=2)return;airBoost=false;jumpCount=2;vy=-520;state('double');emit('game:power',{power:'airboost',used:true})}
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
      else if(airBoost&&jumpCount===1){ollie(true)}
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
    if(o.power==='airboost')airBoost=true;else shield=true;
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
    if(!support&&boardY>=ground&&landTimer===0)state('run');
    if(support&&!grinding&&landTimer===0)state('run');
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
    ctx.drawImage(asset,sx,sy,cellW,cellH,x,y,w,h);return true;
  };
  const drawSkater=(ctx:CanvasRenderingContext2D)=>{
    let animation=currentAnim;
    if(!alive)animation='bail';else if(grinding)animation='grind';else if((support||boardY>=ground-1)&&landTimer<=0)animation='run';
    const map={run:[0,6,12],idle:[6,4,6],land:[10,2,16],ollie:[12,5,14],double:[17,4,12],bail:[21,6,12],grind:[27,4,10],railpop:[31,4,12],flip:[35,4,14]} as const;
    const [start,frames,fps]=map[animation];
    const looping=animation==='run'||animation==='idle'||animation==='grind';
    const frame=looping?Math.floor(stateTime*fps)%frames:Math.min(frames-1,Math.floor(stateTime*fps));
    const idx=start+frame;
    const cfg=art?.grid?.skater;
    const width=cfg?.cellW??80,height=cfg?.cellH??94,columns=cfg?.columns??8;
    const anchorX=cfg?.anchorX??width/2,anchorY=cfg?.anchorY??height-4;
    const zoom=cfg?.displayScale??1;
    // The world point is Fony's skateboard contact, never the changing sprite top-left.
    // Bail frames anchor at the impact position and stop at the final frame (no looping).
    const poseY=alive?boardY:ground;
    if(drawSheet(ctx,'skater',idx%columns,Math.floor(idx/columns),playerX-anchorX*zoom,poseY-anchorY*zoom,width*zoom,height*zoom))return;
    // Procedural placeholder is required when art is absent or blocked.
    ctx.fillStyle='#ff3d7f';ctx.fillRect(playerX-15,boardY-43,30,33);
    ctx.fillStyle='#f0d2a4';ctx.fillRect(playerX-11,boardY-54,22,13);
    ctx.fillStyle='#f9efe6';ctx.fillRect(playerX-21,boardY-5,42,5);
    ctx.fillStyle='#131118';ctx.fillRect(playerX-17,boardY,6,5);ctx.fillRect(playerX+12,boardY,6,5);
  };
  const drawObstacle=(ctx:CanvasRenderingContext2D,o:Obstacle)=>{
    if(o.collected)return;
    const k=o.kind;
    if(k==='gap'){
      ctx.fillStyle='#141117';ctx.fillRect(o.x,ground-1,o.w,34);
      ctx.strokeStyle='#D7FF00';ctx.lineWidth=2;
      ctx.setLineDash([4,6]);ctx.strokeRect(o.x,ground-4,o.w,9);ctx.setLineDash([]);return;
    }
    if(k==='token'){
      const id=o.power==='airboost'?5:4;
      if(drawSheet(ctx,'hazards',id%4,Math.floor(id/4),o.x-8,ground-103,46,48))return;
      ctx.fillStyle='#D7FF00';ctx.beginPath();ctx.arc(o.x+14,ground-65,15,0,Math.PI*2);ctx.fill();
      ctx.fillStyle='#141412';ctx.font='bold 18px monospace';ctx.fillText(o.power==='airboost'?'↑':'Ø',o.x+6,ground-58);return;
    }
    if(k==='rail'){
      const spec=surfaceSpec('rail'),image=art?.images.hazards;
      if(image){
        // The source cell has unrelated sheet scraps ABOVE the actual rail.
        // Crop only those upper scraps, preserving the original rail artwork.
        // Bottom of both legs lands exactly at ground, at every screen scale.
        const cropStart=art?.rail?.clipTopCellY??48;
        const top=imageTopY('rail')+cropStart/sourceCellHeight*spec.height;
        const destHeight=(spec.bottom-cropStart)/sourceCellHeight*spec.height;
        const sections=Math.ceil(o.w/95);
        for(let i=0;i<sections;i++){
          const pw=Math.min(95,o.w-i*95);
          ctx.drawImage(image,3*144,112+cropStart,144,spec.bottom-cropStart,
                        o.x+i*95,top,pw,destHeight);
        }
      }else{
        const top=railSurfaceY();
        ctx.fillStyle='#D7FF00';ctx.fillRect(o.x,top,o.w,6);
        ctx.fillStyle='#ddd';ctx.fillRect(o.x+8,top+6,5,ground-top-6);
        ctx.fillRect(o.x+o.w-12,top+6,5,ground-top-6);
      }
      return;
    }
    const kind=k as 'accept'|'popup'|'modal';
    const spec=surfaceSpec(kind),top=flatTopY(kind);
    if(kind==='accept'){
      // Preserve the original opaque yellow ACCEPT ALL animation as requested.
      if(!drawSheet(ctx,'hazards',0,0,o.x-7,imageTopY(kind),o.w+14,spec.height)){
        ctx.fillStyle='#D7FF00';ctx.fillRect(o.x,top,o.w,ground-top);
        ctx.fillStyle='#141412';ctx.font='bold 11px monospace';ctx.fillText('ACCEPT ALL',o.x+6,top+19);
      }
    }else{
      // The original composite's modal cells are mostly transparent line art,
      // which revealed the skyline and made the consent hazard look collectible.
      // Draw a completely opaque, grounded paper-window obstacle instead.
      const x=o.x-5,width=o.w+10,height=ground-top;
      ctx.fillStyle='#08070d';ctx.fillRect(x-3,top-4,width+6,height+4);
      ctx.fillStyle='#f5eddd';ctx.fillRect(x,top,width,height);
      ctx.fillStyle='#e0287a';ctx.fillRect(x,top,width,22);
      ctx.fillStyle='#100c18';ctx.font='bold 11px monospace';
      ctx.fillText(kind==='popup'?'CONSENT':'TERMS / DATA',x+6,top+15);
      ctx.fillStyle='#34283b';ctx.font='9px monospace';
      const rows=kind==='popup'?2:4;
      for(let i=0;i<rows;i++){
        const y=top+32+i*13;
        if(y>=ground-20)break;
        ctx.fillRect(x+7,y,Math.max(12,width-25-(i%2)*14),2);
      }
      ctx.fillStyle='#e0287a';ctx.fillRect(x+10,ground-21,Math.max(26,width-20),14);
      ctx.fillStyle='#120d19';ctx.font='bold 9px monospace';
      ctx.fillText('I AGREE',x+16,ground-11);
      ctx.strokeStyle='#1d1726';ctx.lineWidth=2;ctx.strokeRect(x,top,width,height);
    }
    if(o.deflected){
      ctx.fillStyle='#101016';ctx.fillRect(o.x-3,top+23,Math.min(o.w+6,102),20);
      ctx.fillStyle='#d7ff00';ctx.font='bold 12px monospace';
      ctx.fillText('DENIED!',o.x+4,top+37);
    }
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
    if(portrait){
      const topWorld=-dy/scale;
      ctx.fillStyle='#17111f';ctx.fillRect(35,topWorld,450,Math.max(0,-topWorld+10));
      ctx.fillStyle='#281c2c';ctx.fillRect(35,topWorld+98,450,3);
      ctx.fillStyle='#514054';ctx.font='11px monospace';
      ctx.fillText('TERMS / CONDITIONS / CONSENT ENGINE  •  AU',47,topWorld+126);
    }
    const far=art?.images.far;
    if(far){const offset=(distance*.2)%640;ctx.drawImage(far,-offset,0,640,360);ctx.drawImage(far,640-offset,0,640,360);ctx.fillStyle='rgba(15,9,24,.12)';ctx.fillRect(0,0,640,360)}
    else{
      ctx.fillStyle='#1a1521';ctx.fillRect(0,0,640,360);
      ctx.fillStyle='#33283e';for(let i=0;i<15;i++)ctx.fillRect(((i*91-distance*.2)%730+730)%730-30,90,3,190);
      ctx.font='14px monospace';ctx.fillStyle='#796987';
      for(let i=0;i<9;i++)ctx.fillText('§ '+(Math.floor(distance/220)+i+1)+'  TERMS AND CONDITIONS APPLY',12,90+i*24);
    }
    const skyline=art?.images.skyline;
    if(skyline){ctx.globalAlpha=.5;ctx.drawImage(skyline,-(distance*.12%640),202,640,76);ctx.drawImage(skyline,640-(distance*.12%640),202,640,76);ctx.globalAlpha=1}
    ctx.fillStyle='#16151b';ctx.fillRect(0,ground,640,60);
    ctx.fillStyle='#D7FF00';ctx.fillRect(0,ground,640,3);
    for(const o of objects)drawObstacle(ctx,o);
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
      ctx.fillText('SPEED '+Math.round(speed())+(speedEnabled?'  FAST +10%':''),48,t+72);
      ctx.fillStyle='#e0287a';ctx.font='bold 11px monospace';
      ctx.fillText(grinding?'GRIND! RELEASE U TO POP':'CONSENT = LAND / GRIND   •   Ø TOKENS = PICKUPS',48,t+91);
      ctx.fillStyle='#b8aaba';ctx.font='bold 12px monospace';
      ctx.fillText((shield?'SHIELD  ':'')+(airBoost?'AIR BOOST READY':''),48,t+150);
    }else{
      ctx.fillStyle='rgba(17,12,20,.93)';ctx.fillRect(0,0,640,71);
      ctx.fillStyle='#D7FF00';ctx.font='bold 18px monospace';ctx.fillText('CLAUSES SKIPPED  '+score(),14,27);
      ctx.fillStyle='#F3EBDE';ctx.font='bold 12px monospace';ctx.fillText('TIER '+tier()+'   COMBO x'+(combo>=3?3:combo===2?2:combo===1?1.5:1),14,47);
      ctx.fillStyle='#D7FF00';ctx.fillText('BEST '+(host as any).best,485,27);
      ctx.fillStyle=speedEnabled||grindBoostLeft>0?'#D7FF00':'#aaa1b3';
      ctx.fillText('SPD '+Math.round(speed()),307,47);
      ctx.fillText((shield?'[SHIELD] ':'')+(airBoost?'[AIR BOOST]':''),400,47);
      ctx.fillStyle='#E0287A';ctx.font='bold 11px monospace';
      if(elapsed<11)ctx.fillText('U / ↑: JUMP & HOLD GRIND  •  SPACE / A: +10% FAST',12,65);
      else if(grinding)ctx.fillText('GRINDING THE FINE PRINT — RELEASE TO POP!',170,65);
      else ctx.fillText('CONSENT FORMS = OBSTACLES  •  TOKENS = PICKUPS',12,65);
    }
    if(visualFlash>0&&!matchMedia('(prefers-reduced-motion: reduce)').matches){ctx.fillStyle='rgba(238,40,122,.12)';ctx.fillRect(0,0,640,360)}
    ctx.restore();
  };
  const result=()=>({cause,causeLine:({accept:'YOU ACCEPTED EVERYTHING. THEY THANK YOU.',popup:'THE POP-UP WON. AGAIN.',modal:'AGREE & CONTINUE? NOT THIS TIME.',gap:'YOU FELL THROUGH A LOOPHOLE.'} as Record<string,string>)[cause]||'READ THE FINE PRINT',stats:{distancePx:Math.floor(distance),hazardsCleared,grindMs:Math.floor(grindMs),platformLandings,platformGrinds,longestCombo,shieldsUsed,speedEnabled,acceleration:Math.round(acceleration*100)/100,runSpeed:Math.round(speed()),grindBoostLeft:Math.round(grindBoostLeft*100)/100,shieldDeflections,boardY:Math.round(boardY),jumpCount,grinding}});
  reset();
  return {start:reset,input,update,draw,score,over:()=>!alive&&bailRemaining===0,result,setSkin} satisfies GameAPI;
});
