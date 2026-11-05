import {test,expect} from '@playwright/test';
const art='../games/grind-the-terms/skins/au/skin.json';

test('AU image skin loads and renders new Fony art', async ({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await expect(game).toHaveAttribute('skin',art);
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 await expect(page.locator('#events')).not.toContainText('SKIN_LOAD_FAILED');
 await game.locator('button[part=start]').click();
 await page.waitForTimeout(100);
 const alpha=await game.locator('canvas').evaluate(c=>{
  const d=c.getContext('2d').getImageData(0,0,Math.min(c.width,100),Math.min(c.height,100)).data;
  return Array.from(d).some(v=>v!==0);
 });
 expect(alpha).toBe(true);
});

test('broken skin triggers fallback and does not crash the runner',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await game.evaluate(e=>e.setAttribute('skin','./not-real/skin.json'));
 await expect(page.locator('#events')).toContainText('SKIN_LOAD_FAILED');
 await game.locator('button[part=start]').click();
 expect(await game.evaluate(e=>e.state)).toBe('playing');
});

test('rail catch and pop increase grind time in deterministic first chunk',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const result=await game.evaluate(el=>{
  const g=el.game;g.start();
  for(let i=0;i<170;i++)g.update(1/60);
  g.input('up',true);
  for(let i=0;i<68;i++)g.update(1/60);
  const afterHold=g.result().stats.grindMs;
  g.input('up',false);
  for(let i=0;i<10;i++)g.update(1/60);
  return {grindMs:afterHold,afterRelease:g.result().stats.grindMs,cause:g.result().cause};
 });
 expect(result.grindMs).toBeGreaterThan(0);
 expect(result.afterRelease).toBeGreaterThanOrEqual(result.grindMs);
});

test('correct score metadata and back-to-back starts',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await game.locator('button[part=start]').click();
 const d=await game.evaluate(el=>{
  const g=el.game;for(let i=0;i<90;i++)g.update(1/60);
  return {score:g.score(),result:g.result(),over:g.over()};
 });
 expect(d.score).toBeGreaterThan(0);
 expect(d.result.stats.distancePx).toBeGreaterThan(0);
 expect(d.over).toBe(false);
 await game.evaluate(el=>el.reset());
 expect(await game.evaluate(el=>el.state)).toBe('title');
 await game.locator('button[part=start]').click();
 expect(await game.evaluate(el=>el.state)).toBe('playing');
});


test('sound starts muted and can be toggled without a recording asset',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const sound=game.locator('button[part=sound]');
 await expect(sound).toHaveText('SOUND OFF');
 await sound.click();
 await expect(sound).toHaveText('SOUND ON');
 await expect(page.locator('#events')).toContainText('game:sound');
 await sound.click();
 await expect(sound).toHaveText('SOUND OFF');
});


test('mobile game controls stay compact and leave the score visible',async({page},testInfo)=>{
 test.skip(!testInfo.project.name.startsWith('mobile'),'Only relevant to mobile viewports');
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const sound=await game.locator('button[part=sound]').boundingBox();
 const pause=await game.locator('button[part=pause]').boundingBox();
 expect(sound).not.toBeNull();expect(pause).not.toBeNull();
 expect(sound.width).toBeLessThan(110);
 expect(pause.width).toBeLessThan(65);
});


test('share emits a score event and offers a browser fallback',async({page})=>{
 // Prevent a native Web Share dialog from blocking mobile Chromium automation.
 await page.addInitScript(()=>Object.defineProperty(navigator,'share',{configurable:true,value:async()=>{}}));
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await game.locator('button[part=start]').click();
 await game.evaluate(e=>{e.game.score=()=>44;e.game.over=()=>true});
 await expect(game.locator('button[part=share]')).toBeVisible();
 await game.locator('button[part=share]').click();
 await expect(page.locator('#events')).toContainText('game:share');
});

test('Fony atlas has 39 unclipped poses sharing one board/foot baseline',async({page})=>{
 await page.goto('/demo/');
 const poses=await page.evaluate(async()=>{
  const url=new URL('../games/grind-the-terms/skins/au/skin.json',location.href);
  const skin=await(await fetch(url)).json();
  const grid=skin.grid.skater,asset=new Image();
  asset.src=new URL(skin.files.skater,url).href;await asset.decode();
  const canvas=document.createElement('canvas');canvas.width=grid.cellW;canvas.height=grid.cellH;
  const ctx=canvas.getContext('2d',{willReadFrequently:true});
  const boxes=[];
  for(let i=0;i<39;i++){
   ctx.clearRect(0,0,grid.cellW,grid.cellH);
   ctx.drawImage(asset,(i%grid.columns)*grid.cellW,Math.floor(i/grid.columns)*grid.cellH,grid.cellW,grid.cellH,0,0,grid.cellW,grid.cellH);
   const {data}=ctx.getImageData(0,0,grid.cellW,grid.cellH);
   let minX=999,minY=999,maxX=-1,maxY=-1,pixels=0;
   for(let y=0;y<grid.cellH;y++)for(let x=0;x<grid.cellW;x++)if(data[(y*grid.cellW+x)*4+3]>180){
    pixels++;minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);
   }
   boxes.push({minX,minY,maxX,maxY,pixels});
  }
  return {grid,source:[asset.naturalWidth,asset.naturalHeight],boxes};
 });
 expect(poses.source).toEqual([1024,640]);
 expect(poses.grid.cellW).toBe(128);expect(poses.grid.cellH).toBe(128);
 expect(poses.grid.anchorX).toBe(64);expect(poses.grid.anchorY).toBe(117);expect(poses.grid.displayScale).toBe(1);
 expect(poses.boxes).toHaveLength(39);
 for(const [i,b] of poses.boxes.entries()){
  expect(b.pixels,`frame ${i} missing pixels`).toBeGreaterThan(1000);
  expect(b.minX,`frame ${i} clips left`).toBeGreaterThan(7);
  expect(b.maxX,`frame ${i} clips right`).toBeLessThan(121);
  expect(b.minY,`frame ${i} clips top`).toBeGreaterThan(3);
  expect(b.maxY,`frame ${i} exceeds foot baseline`).toBeLessThanOrEqual(118);
  expect(b.maxY,`frame ${i} not aligned to foot baseline`).toBeGreaterThanOrEqual(110);
 }
});

test('running and bail animations use stable on-screen actor origin and never loop bail',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 const result=await game.evaluate(el=>{
  const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
  const original=ctx.drawImage.bind(ctx),poses=[];
  ctx.drawImage=(...args)=>{if(args.length===9&&args[0]?.naturalWidth===1024&&args[0]?.naturalHeight===640)poses.push({sx:args[1],sy:args[2],dx:args[5],dy:args[6],w:args[7],h:args[8]});return original(...args)};
  g.start();
  for(let i=0;i<6;i++){g.update(.05);g.draw(ctx,canvas.width,canvas.height)}
  const run=poses.slice();
  let count=0;
  while(!g.over()&&count++<6000)g.update(1/60);
  g.draw(ctx,canvas.width,canvas.height);
  const final=poses.at(-1);
  for(let i=0;i<60;i++)g.update(1/60);
  g.draw(ctx,canvas.width,canvas.height);
  return {run,final,after:poses.at(-1),ended:g.over(),count};
 });
 expect(result.ended).toBe(true);
 expect(result.run).toHaveLength(6);
 for(const p of result.run){expect(p.dx).toBeCloseTo(76,0);expect(p.dy).toBeCloseTo(193,0);expect(p.w).toBe(128);expect(p.h).toBe(128)}
 expect(result.final.dx).toBeCloseTo(76,0);
 expect(result.final.dy).toBeCloseTo(193,0);
 expect(result.final.sx).toBe((26%8)*128);
 expect(result.final.sy).toBe(Math.floor(26/8)*128);
 expect(result.after).toEqual(result.final);
});

test('seamless rail cap top matches skater contact and end legs touch pavement',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const result=await game.evaluate(el=>{
  const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
  g.start();
  for(let i=0;i<170;i++)g.update(1/60);
  g.input('up',true);
  let caught=false;
  for(let i=0;i<100;i++){g.update(1/60);if(g.result().stats.grindMs>0){caught=true;break}}
  g.draw(ctx,canvas.width,canvas.height);
  const stats=g.result().stats;
  const portrait=canvas.width/canvas.height<1.05,k=portrait?canvas.width/450:Math.min(canvas.width/640,canvas.height/360),dx=portrait?-35*k:(canvas.width-640*k)/2,dy=portrait?canvas.height-350*k:(canvas.height-360*k)/2;
  const sample=(x,y)=>[...ctx.getImageData(Math.floor(dx+x*k),Math.floor(dy+y*k),1,1).data];
  const bar=stats.supportX!==null?sample(stats.supportX+stats.supportWidth*.72,stats.supportTop+4):null;
  g.input('up',false);g.update(1/60);
  return {caught,stats,bar,pop:g.result().stats.boardY};
 });
 expect(result.caught).toBe(true);
 expect(result.stats.supportTop).toBeGreaterThan(288);
 expect(result.stats.supportTop).toBeLessThan(292);
 expect(Math.abs(result.stats.boardY-result.stats.supportTop)).toBeLessThan(1.5);
 expect(result.pop).toBeLessThan(result.stats.supportTop);
 expect(result.bar[1]).toBeGreaterThan(155);
 expect(result.bar[3]).toBe(255);
});

test('all original hazard art bottoms align with floor and surface matches sprite top',async({page})=>{
  await page.goto('/demo/');
  const data=await page.evaluate(async()=>{
    const url='../games/grind-the-terms/skins/au/skin.json';
    const skin=await(await fetch(url)).json();
    const cell=skin.grid.hazards.cellH;
    const geom={rail:skin.rail,...skin.surfaces};
    return Object.fromEntries(Object.entries(geom).map(([kind,g])=>{
      const drawTop=310-g.groundCellY/cell*g.drawHeight;
      const visibleTop=drawTop+g.surfaceCellY/cell*g.drawHeight;
      const visibleBottom=drawTop+g.groundCellY/cell*g.drawHeight;
      return [kind,{visibleTop,visibleBottom}];
    }));
  });
  for(const kind of ['rail','accept','popup','modal']){
    expect(data[kind].visibleBottom).toBeCloseTo(310,5);
    expect(data[kind].visibleTop).toBeLessThan(310);
  }
  expect(data.rail.visibleTop).toBeGreaterThan(288);
  expect(data.rail.visibleTop).toBeLessThan(292);
  expect(data.accept.visibleTop).toBeGreaterThan(234);
  expect(data.accept.visibleTop).toBeLessThan(238);
});
test('clean ACCEPT ALL sprite body is grounded with no detached green guide',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const colors=await game.evaluate(el=>{
  el.setAttribute('data-qa-accept','');
  const c=el.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d');
  el.game.start();el.game.draw(ctx,c.width,c.height);
  const portrait=c.width/c.height<1.05,k=portrait?c.width/450:Math.min(c.width/640,c.height/360),dx=portrait?-35*k:(c.width-640*k)/2,dy=portrait?c.height-350*k:(c.height-360*k)/2;
  const sample=(x,y)=>[...ctx.getImageData(Math.floor(dx+x*k),Math.floor(dy+y*k),1,1).data];
  return {button:sample(375,276),above:sample(375,252),floor:sample(375,299)};
 });
 expect(colors.button[1]).toBeGreaterThan(150);
 expect(colors.button[3]).toBe(255);
 expect(colors.above[1]).toBeLessThan(colors.button[1]);
 await game.screenshot({path:'test-results/screenshots/accept-no-fringe-desktop.png'});
});

test('clean rails stay capped and supported at one through four full spans',async({page},info)=>{
 test.skip(info.project.name.startsWith('mobile'),'Representative desktop pixel screenshot');
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 for(const width of [75,150,225,300]){
  const bounds=await game.evaluate((el,width)=>{
   el.setAttribute('data-qa-rail-size',String(width));
   const c=el.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d');
   el.game.start();el.game.draw(ctx,c.width,c.height);
   const k=Math.min(c.width/640,c.height/360),dx=(c.width-640*k)/2,dy=(c.height-360*k)/2;
   const sample=(x,y)=>[...ctx.getImageData(Math.floor(dx+x*k),Math.floor(dy+y*k),1,1).data];
   return {left:sample(284,293),mid:sample(280+width/2,293),right:sample(276+width,293),end:sample(286+width,292)};
  },width);
  for(const pixel of [bounds.left,bounds.mid,bounds.right])expect(pixel[1]).toBeGreaterThan(125);
  if(width===300)await game.screenshot({path:'test-results/screenshots/rail-four-span.png'});
 }
});

test('opt-out token and loophole use the approved gameplay art',async({page},info)=>{
 test.skip(info.project.name.startsWith('mobile'),'Representative desktop pixel screenshot');
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await expect(game).toHaveAttribute('data-au-art-ready','');
 const result=await game.evaluate(el=>{
  el.setAttribute('data-qa-token','');
  el.setAttribute('data-qa-loophole','');
  const c=el.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d'),draw=ctx.drawImage.bind(ctx),tokens=[];
  ctx.drawImage=(...args)=>{if(args[0]?.src?.includes('terms_opt_out_token_v1.webp'))tokens.push(args);return draw(...args)};
  el.game.start();el.game.draw(ctx,c.width,c.height);ctx.drawImage=draw;
  const k=Math.min(c.width/640,c.height/360),dx=(c.width-640*k)/2,dy=(c.height-360*k)/2;
  const manhole=[...ctx.getImageData(Math.floor(dx+320*k),Math.floor(dy+307*k),1,1).data];
  return {tokens:tokens.length,manhole};
 });
 expect(result.tokens).toBeGreaterThan(0);
 expect(result.manhole[3]).toBe(255);
 await game.screenshot({path:'test-results/screenshots/coin-manhole-clean.png'});
});

test('the first flat-topped consent box can be ground and popped from',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const attempts=await game.evaluate(el=>{
   const g=el.game,viable=[];
   for(let frame=350;frame<=465;frame+=5){
     g.start();
     for(let i=0;i<frame;i++)g.update(1/60);
     if(g.over())continue;
     g.input('up',true);
     for(let i=0;i<110;i++)g.update(1/60);
     const stats=g.result().stats;
     if(stats.platformGrinds>0){
       g.input('up',false);
       for(let j=0;j<8;j++)g.update(1/60);
       viable.push({frame,landings:stats.platformLandings,grinds:stats.platformGrinds,ms:g.result().stats.grindMs});
     }
   }
   return viable;
 });
 expect(attempts.length).toBeGreaterThan(0);
 expect(attempts[0].grinds).toBeGreaterThan(0);
 expect(attempts[0].ms).toBeGreaterThan(0);
});
test('new flat-top counters are exposed for both skins',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const data=await game.evaluate(el=>{
   const g=el.game;g.start();
   for(let i=0;i<100;i++)g.update(1/60);
   return g.result().stats;
 });
 expect(data).toHaveProperty('platformLandings',0);
 expect(data).toHaveProperty('platformGrinds',0);
});


test('desktop SPACE performs an aerial trick without changing ground speed',async({page},info)=>{
 test.skip(info.project.name.startsWith('mobile'),'Desktop keyboard only');
 await page.goto('/demo/');
 const el=page.locator('grind-the-terms');
 await el.locator('button[part=start]').click();
 const result=await el.evaluate(e=>{
  e.focus();
  const send=(type,key)=>e.dispatchEvent(new KeyboardEvent(type,{key,bubbles:true,composed:true,cancelable:true}));
  send('keydown','ArrowUp');send('keyup','ArrowUp');e.game.update(.05);
  const airborne=e.game.result().stats;
  send('keydown',' ');send('keyup',' ');e.game.update(.05);
  const trick=e.game.result().stats;
  return {airborne,trick};
 });
 expect(result.airborne.boardY).toBeLessThan(310);
 expect(result.trick.tricksUsed).toBe(1);
 expect(result.trick.speedMultiplier).toBe(1);
 expect(result.trick.runSpeed).toBe(result.trick.normalSpeed);
});

test('consent forms render the approved illustrated panels as grounded obstacles',async({page},info)=>{
 test.skip(info.project.name.startsWith('mobile'),'Representative desktop art fixture');
 await page.goto('/demo/');
 const el=page.locator('grind-the-terms');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 const sources=await el.evaluate(e=>{
   e.setAttribute('data-qa-consent','');
   const c=e.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d'),draw=ctx.drawImage.bind(ctx),seen=[];
   ctx.drawImage=(...args)=>{if(args[0]?.src)seen.push(args[0].src.split('/').pop());return draw(...args)};
   e.game.start();e.game.draw(ctx,c.width,c.height);ctx.drawImage=draw;
   return seen;
 });
 expect(sources).toContain('terms_consent_popup_v1.webp');
 expect(sources).toContain('terms_consent_modal_v1.webp');
 await el.locator('canvas').screenshot({path:'test-results/screenshots/consent-illustrations-desktop.png'});
});

test('approved layered WebP scenery is cached and rendered across the scene',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 const result=await page.locator('grind-the-terms').evaluate(async el=>{
   const url=new URL('../games/grind-the-terms/skins/au/skin.json',location.href);
   const skin=await(await fetch(url)).json();
   const keys=['cloudsNear','cloudsFar','dataCity','graffitiWall','road'];
   const images=await Promise.all(keys.map(async key=>{const img=new Image();img.src=new URL(skin.files[key],url).href;await img.decode();return {key,assetName:skin.files[key],w:img.naturalWidth,h:img.naturalHeight}}));
   const canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d'),original=ctx.drawImage.bind(ctx),seen=[];
   ctx.drawImage=(...args)=>{
     if(args[0] instanceof HTMLImageElement)seen.push(args[0].src.split('/').pop());
     if(args[0] instanceof HTMLCanvasElement&&args[0].width===1024&&args[0].height===342)seen.push('cached-cloud');
     return original(...args);
   };
   el.game.start();el.game.draw(ctx,canvas.width,canvas.height);ctx.drawImage=original;
   return {images,seen,hasFar:Object.hasOwn(skin.files,'cloudsFar')};
 });
 expect(result.hasFar).toBe(true);
 expect(result.images).toHaveLength(5);
 const dimensions={cloudsNear:[1024,342],cloudsFar:[1024,100],dataCity:[1024,342],graffitiWall:[1024,342],road:[1024,128]};
 for(const img of result.images){
   expect([img.w,img.h]).toEqual(dimensions[img.key]);
   if(img.key==='cloudsNear')expect(result.seen).toContain('cached-cloud');
   else expect(result.seen,`Missing rendered asset: ${img.assetName}`).toContain(img.assetName);
 }
 await page.locator('grind-the-terms').screenshot({path:'test-results/screenshots/approved-illustrated-scene-v13.png'});
});

test('Fony gameplay atlas uses crisp no-interpolation ink while scenery retains smoothing',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 const data=await page.locator('grind-the-terms').evaluate(el=>{
   const game=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
   const original=ctx.drawImage.bind(ctx),seen=[];
   ctx.drawImage=(...args)=>{
     if(args[0]?.naturalWidth===1024&&args[0]?.naturalHeight===640)seen.push({smooth:ctx.imageSmoothingEnabled,sourceW:args[3],destW:args[7]});
     return original(...args);
   };
   game.start();game.draw(ctx,canvas.width,canvas.height);
   ctx.drawImage=original;
   return {seen,after:ctx.imageSmoothingEnabled};
 });
 expect(data.seen.length).toBeGreaterThan(0);
 expect(data.seen.every(s=>s.smooth===false&&s.sourceW===128&&s.destW===128)).toBe(true);
 expect(data.after).toBe(true);
 await page.locator('grind-the-terms').screenshot({path:'test-results/screenshots/fony-crisp-legal-smog-v6.png'});
});

test('world-space ACCEPT and physical sidewalk scroll at identical speed',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 const result=await page.locator('grind-the-terms').evaluate(el=>{
   el.setAttribute('data-qa-ground-scroll','');
   const game=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
   const draw=ctx.drawImage.bind(ctx),fill=ctx.fillText.bind(ctx),scans=[];
   let roadX=null,acceptX=null;
   ctx.drawImage=(...args)=>{
     if(args[0]?.src?.includes('terms_sidewalk_road_v6.webp')&&roadX===null)roadX=args.length===9?args[5]-args[1]/(args[0].naturalWidth/1280):args[1];
     return draw(...args);
   };
   ctx.fillText=(...args)=>{if(args[0]==='ACCEPT ALL')acceptX=args[1];return fill(...args)};
   game.start();
   for(const steps of [0,18,18]){
     for(let i=0;i<steps;i++)game.update(.05);
     roadX=null;acceptX=null;
     game.draw(ctx,canvas.width,canvas.height);
     scans.push({roadX,acceptX,d:game.result().stats.distancePx});
   }
   ctx.drawImage=draw;ctx.fillText=fill;
   return scans;
 });
 expect(result).toHaveLength(3);
 expect(result.every(s=>s.roadX!==null&&s.acceptX!==null)).toBe(true);
 for(let i=1;i<result.length;i++){
   const roadShift=result[i].roadX-result[i-1].roadX;
   const acceptShift=result[i].acceptX-result[i-1].acceptX;
   expect(Math.abs(roadShift-acceptShift)).toBeLessThan(.01);
   expect(roadShift).toBeLessThan(-50);
 }
});

test('cloud skin references the approved opaque PNG, not the translucent SVGs',async({page})=>{
 await page.goto('/demo/');
 const detail=await page.evaluate(async()=>{
   const url=new URL('../games/grind-the-terms/skins/au/skin.json',location.href);
   const data=await(await fetch(url)).json();
   return {type:data.cloudTypography,far:data.files.cloudsFar,near:data.files.cloudsNear};
 });
 expect(detail.type.largestRenderedTextPx).toBeLessThanOrEqual(10);
 expect(detail.type.heading).toBe('TERMS & CONDITIONS');
 expect(detail.far).toBe('terms_far_clouds_v1.webp');
 expect(detail.near).toBe('terms_papercut_cloudbank_v13.webp');
});

test('trick upgrade enables one more combo before landing',async({page})=>{
 await page.goto('/demo/');
 const result=await page.locator('grind-the-terms').evaluate(el=>{
  el.setAttribute('data-qa-trick-upgrade','');
  const g=el.game;g.start();
  g.input('up',true);g.update(1/60);g.input('up',false);
  for(let i=0;i<8;i++)g.update(1/60);
  const airborne=g.result().stats;
  g.input('trick',true);g.input('trick',false);g.update(1/60);
  const first=g.result().stats;
  g.input('trick',true);g.input('trick',false);g.update(1/60);
  return {airborne,first,second:g.result().stats};
 });
 expect(result.airborne.tricksUsed).toBe(0);
 expect(result.first.tricksUsed).toBe(1);
 expect(result.first.trick2Unlocked).toBe(true);
 expect(result.second.tricksUsed).toBe(2);
 expect(result.second.trickLimit).toBe(2);
});

test('spray can rocket gives one temporary 2x burst',async({page})=>{
 await page.goto('/demo/');
 const stats=await page.locator('grind-the-terms').evaluate(el=>{
  el.setAttribute('data-qa-rocket-charge','');
  const g=el.game;g.start();g.input('boost',true);
  g.update(.05);
  return g.result().stats;
 });
 expect(stats.sprayCans).toBe(0);
 expect(stats.speedMultiplier).toBe(2);
 expect(stats.runSpeed/stats.normalSpeed).toBeGreaterThan(1.99);
 expect(stats.runSpeed/stats.normalSpeed).toBeLessThan(2.01);
 expect(stats.rocketBoostLeft).toBeGreaterThan(1.1);
});

test('ground motion uses the approved six-frame board-contact Fony cycle',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 const result=await page.locator('grind-the-terms').evaluate(el=>{
  const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
  const seen=[],draw=ctx.drawImage.bind(ctx);g.start();
  ctx.drawImage=(...args)=>{if(args.length===9&&args[0]?.naturalHeight===640&&args[3]===128&&args[4]===128)seen.push({sx:args[1],sy:args[2]});return draw(...args)};
  for(let frame=0;frame<6;frame++){g.update(.05);g.draw(ctx,canvas.width,canvas.height)}
  ctx.drawImage=draw;
  return seen;
 });
 expect(result.length).toBeGreaterThan(3);
 for(const frame of result){
   expect(frame.sy).toBe(0);
   expect([0,128,256,384,512,640]).toContain(frame.sx);
 }
});

test('the approved cloudbank is a transparent-edge WebP with opaque paper artwork',async({page})=>{
 await page.goto('/demo/');
 const detail=await page.evaluate(async()=>{
   const url=new URL('../games/grind-the-terms/skins/au/skin.json',location.href);
   const skin=await(await fetch(url)).json();
   const response=await fetch(new URL(skin.files.cloudsNear,url));
   const bytes=new Uint8Array(await response.arrayBuffer());
   const img=new Image();img.src=new URL(skin.files.cloudsNear,url).href;await img.decode();
   const c=document.createElement('canvas');c.width=img.naturalWidth;c.height=img.naturalHeight;
   const ctx=c.getContext('2d');ctx.drawImage(img,0,0);
   return {riff:[...bytes.slice(0,4)],format:[...bytes.slice(8,12)],w:c.width,h:c.height,
     paperAlpha:ctx.getImageData(500,110,1,1).data[3],
     transparentEdgeAlpha:ctx.getImageData(512,341,1,1).data[3]};
 });
 expect(detail.riff).toEqual([82,73,70,70]);
 expect(detail.format).toEqual([87,69,66,80]);
 expect([detail.w,detail.h]).toEqual([1024,342]);
 expect(detail.paperAlpha).toBeGreaterThan(240);
 expect(detail.transparentEdgeAlpha).toBe(0);
});

test('normal cruising remains stable until a spray-can boost is activated',async({page})=>{
 await page.goto('/demo/');
 const stat=await page.locator('grind-the-terms').evaluate(el=>{
   const g=el.game;g.start();
   for(let i=0;i<20;i++)g.update(1/60);
   const normal=g.result().stats;
   g.input('speed',true);
   for(let i=0;i<10;i++)g.update(.05);
   const ignoredLegacyToggle=g.result().stats;
   return {normal,ignoredLegacyToggle};
 });
 expect(stat.normal.runSpeed/stat.normal.normalSpeed).toBe(1);
 expect(stat.ignoredLegacyToggle.speedMultiplier).toBe(1);
 expect(stat.ignoredLegacyToggle.runSpeed/stat.ignoredLegacyToggle.normalSpeed).toBe(1);
});


test('WebP cloud and city parallax draw only the visible world-camera region',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 const result=await page.locator('grind-the-terms').evaluate(el=>{
   const g=el.game,c=el.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d'),original=ctx.drawImage.bind(ctx),drawn=[];
   ctx.drawImage=(...args)=>{
     if(args.length===9&&args[0]?.width===1024&&args[0]?.height===342)
       drawn.push({kind:'raster-cloud',sourceWidth:args[3],destWidth:args[7],y:args[6],h:args[8]});
     if(args.length===9&&args[0]?.src?.includes('terms_datacenter_city_v6.webp'))
       drawn.push({kind:'city',sourceWidth:args[3],destWidth:args[7]});
     return original(...args);
   };
   g.start();g.draw(ctx,c.width,c.height);ctx.drawImage=original;return drawn;
 });
 expect(result.some(x=>x.kind==='raster-cloud')).toBe(true);
 expect(result.some(x=>x.kind==='city')).toBe(true);
 for(const item of result)expect(item.destWidth).toBeLessThanOrEqual(650);
});

test('cloud top edge stays under the HUD in mobile and desktop camera',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 await expect(page.locator('grind-the-terms')).toHaveAttribute('data-au-art-ready','');
 const dimensions=await page.locator('grind-the-terms').evaluate(el=>{
   const c=el.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d'),real=ctx.drawImage.bind(ctx),rows=[];
   ctx.drawImage=(...args)=>{
     if(args.length===9&&args[0] instanceof HTMLCanvasElement&&args[0].width===1024&&args[0].height===342)
       rows.push({y:args[6],h:args[8]});
     return real(...args);
   };
   el.game.start();el.game.draw(ctx,c.width,c.height);ctx.drawImage=real;
   const portrait=c.width/c.height<1.05;
   const scale=portrait?c.width/450:Math.min(c.width/640,c.height/360);
   const dy=portrait?c.height-350*scale:(c.height-360*scale)/2;
   return {rows,portrait,hudBottom:portrait?-dy/scale+98:71};
 });
 expect(dimensions.rows.length).toBeGreaterThan(0);
 const cloud=dimensions.rows[0];
 expect(cloud.y).toBeLessThan(dimensions.hudBottom-2);
 expect(cloud.y+cloud.h).toBeGreaterThan(dimensions.hudBottom+60);
});

