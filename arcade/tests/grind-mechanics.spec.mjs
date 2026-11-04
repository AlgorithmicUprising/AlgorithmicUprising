import {test,expect} from '@playwright/test';
const art='../games/grind-the-terms/skins/au/skin.json';

test('AU image skin loads and renders new Fony art', async ({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await expect(game).toHaveAttribute('skin',art);
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
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
  g.input('tap',true);
  for(let i=0;i<68;i++)g.update(1/60);
  const afterHold=g.result().stats.grindMs;
  g.input('tap',false);
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
 expect(poses.source).toEqual([2048,1280]);
 expect(poses.grid.anchorX).toBe(128);expect(poses.grid.anchorY).toBe(234);expect(poses.grid.displayScale).toBe(.5);
 expect(poses.boxes).toHaveLength(39);
 for(const [i,b] of poses.boxes.entries()){
  expect(b.pixels,`frame ${i} missing pixels`).toBeGreaterThan(1000);
  expect(b.minX,`frame ${i} clips left`).toBeGreaterThan(7);
  expect(b.maxX,`frame ${i} clips right`).toBeLessThan(249);
  expect(b.minY,`frame ${i} clips top`).toBeGreaterThan(3);
  expect(b.maxY,`frame ${i} exceeds foot baseline`).toBeLessThanOrEqual(236);
  expect(b.maxY,`frame ${i} not aligned to foot baseline`).toBeGreaterThanOrEqual(225);
 }
});

test('running and bail animations use stable on-screen actor origin and never loop bail',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 const result=await game.evaluate(el=>{
  const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
  const original=ctx.drawImage.bind(ctx),poses=[];
  ctx.drawImage=(...args)=>{if(args.length===9&&args[0]?.naturalWidth===2048)poses.push({sx:args[1],sy:args[2],dx:args[5],dy:args[6],w:args[7],h:args[8]});return original(...args)};
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
 for(const p of result.run){expect(p.dx).toBeCloseTo(76,0);expect(p.dy).toBeCloseTo(183,0);expect(p.w).toBe(128);expect(p.h).toBe(128)}
 expect(result.final.dx).toBeCloseTo(76,0);
 expect(result.final.dy).toBeCloseTo(183,0);
 expect(result.final.sx).toBe((26%8)*256);
 expect(result.final.sy).toBe(Math.floor(26/8)*256);
 expect(result.after).toEqual(result.final);
});

test('seamless rail cap top matches skater contact and end legs touch pavement',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const result=await game.evaluate(el=>{
  const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
  g.start();
  for(let i=0;i<170;i++)g.update(1/60);
  g.input('tap',true);
  let caught=false;
  for(let i=0;i<100;i++){g.update(1/60);if(g.result().stats.grindMs>0){caught=true;break}}
  g.draw(ctx,canvas.width,canvas.height);
  const stats=g.result().stats;
  const portrait=canvas.width/canvas.height<1.05,k=portrait?canvas.width/450:Math.min(canvas.width/640,canvas.height/360),dx=portrait?-35*k:(canvas.width-640*k)/2,dy=portrait?canvas.height-340*k:(canvas.height-360*k)/2;
  const sample=(x,y)=>[...ctx.getImageData(Math.floor(dx+x*k),Math.floor(dy+y*k),1,1).data];
  const bar=stats.supportX!==null?sample(stats.supportX+stats.supportWidth*.72,stats.supportTop+4):null;
  g.input('tap',false);g.update(1/60);
  return {caught,stats,bar,pop:g.result().stats.boardY};
 });
 expect(result.caught).toBe(true);
 expect(result.stats.supportTop).toBeGreaterThan(278);
 expect(result.stats.supportTop).toBeLessThan(282);
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
      const drawTop=300-g.groundCellY/cell*g.drawHeight;
      const visibleTop=drawTop+g.surfaceCellY/cell*g.drawHeight;
      const visibleBottom=drawTop+g.groundCellY/cell*g.drawHeight;
      return [kind,{visibleTop,visibleBottom}];
    }));
  });
  for(const kind of ['rail','accept','popup','modal']){
    expect(data[kind].visibleBottom).toBeCloseTo(300,5);
    expect(data[kind].visibleTop).toBeLessThan(300);
  }
  expect(data.rail.visibleTop).toBeGreaterThan(278);
  expect(data.rail.visibleTop).toBeLessThan(282);
  expect(data.accept.visibleTop).toBeGreaterThan(265);
  expect(data.accept.visibleTop).toBeLessThan(275);
});
test('clean ACCEPT ALL sprite body is grounded with no detached green guide',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const colors=await game.evaluate(el=>{
  el.setAttribute('data-qa-accept','');
  const c=el.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d');
  el.game.start();el.game.draw(ctx,c.width,c.height);
  const portrait=c.width/c.height<1.05,k=portrait?c.width/450:Math.min(c.width/640,c.height/360),dx=portrait?-35*k:(c.width-640*k)/2,dy=portrait?c.height-340*k:(c.height-360*k)/2;
  const sample=(x,y)=>[...ctx.getImageData(Math.floor(dx+x*k),Math.floor(dy+y*k),1,1).data];
  return {button:sample(375,276),above:sample(375,264),floor:sample(375,299)};
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
   return {left:sample(284,283),mid:sample(280+width/2,283),right:sample(276+width,283),end:sample(286+width,292)};
  },width);
  for(const pixel of [bounds.left,bounds.mid,bounds.right])expect(pixel[1]).toBeGreaterThan(125);
  if(width===300)await game.screenshot({path:'test-results/screenshots/rail-four-span.png'});
 }
});

test('token and manhole fixtures are readable, independent of old hazard atlas',async({page},info)=>{
 test.skip(info.project.name.startsWith('mobile'),'Representative desktop pixel screenshot');
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 const result=await game.evaluate(el=>{
  el.setAttribute('data-qa-token','');
  el.setAttribute('data-qa-loophole','');
  const c=el.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d');
  el.game.start();el.game.draw(ctx,c.width,c.height);
  const k=Math.min(c.width/640,c.height/360),dx=(c.width-640*k)/2,dy=(c.height-360*k)/2;
  const sample=(x,y)=>[...ctx.getImageData(Math.floor(dx+x*k),Math.floor(dy+y*k),1,1).data];
  return {coin:sample(323,230),manhole:sample(320,307)};
 });
 expect(result.coin[1]).toBeGreaterThan(155);
 expect(result.coin[3]).toBe(255);
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
     g.input('tap',true);
     for(let i=0;i<110;i++)g.update(1/60);
     const stats=g.result().stats;
     if(stats.platformGrinds>0){
       g.input('tap',false);
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


test('space changes speed without causing an ollie',async({page},info)=>{
 test.skip(info.project.name.startsWith('mobile'),'Desktop keyboard only');
 await page.goto('/demo/');
 const el=page.locator('grind-the-terms');
 await el.locator('button[part=start]').click();
 await page.keyboard.press('Space');
 expect(await el.evaluate(x=>x.game.result().stats.speedEnabled)).toBe(true);
 expect(await el.evaluate(x=>x.game.result().stats.boardY)).toBe(300);
 await el.evaluate(x=>{for(let i=0;i<10;i++)x.game.update(.05)});
 const measured=await el.evaluate(x=>x.game.result().stats.runSpeed);
 expect(measured).toBeGreaterThan(345);
 expect(measured).toBeLessThan(380);
 await page.keyboard.press('Space');
 expect(await el.evaluate(x=>x.game.result().stats.speedEnabled)).toBe(false);
 await page.keyboard.press('ArrowUp');
 await el.evaluate(x=>x.game.update(.05));
 expect(await el.evaluate(x=>x.game.result().stats.boardY)).toBeLessThan(300);
});

test('consent forms are opaque, visible, grounded obstacles rather than translucent pickups',async({page},info)=>{
 test.skip(info.project.name.startsWith('mobile'),'Exact pixel colors in desktop art fixture');
 await page.goto('/demo/');
 const el=page.locator('grind-the-terms');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 const colors=await el.evaluate(e=>{
   e.setAttribute('data-qa-consent','');
   const c=e.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d');
   e.game.start();e.game.draw(ctx,c.width,c.height);
   const sample=(x,y)=>{
     const px=Math.floor(c.width*x/640),py=Math.floor(c.height*y/360);
     return [...ctx.getImageData(px,py,1,1).data];
   };
   return {popup:sample(274,259),modal:sample(457,241)};
 });
 // The fully opaque paper fill is #f5eddd (245,237,221).
 for(const color of [colors.popup,colors.modal]){
   expect(color[0]).toBeGreaterThan(225);
   expect(color[1]).toBeGreaterThan(212);
   expect(color[2]).toBeGreaterThan(194);
   expect(color[3]).toBe(255);
 }
 await el.locator('canvas').screenshot({path:'test-results/screenshots/consent-opaque-desktop.png'});
});

test('approved illustrated scenery is loaded as five distinct parallax layers',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 const result=await page.locator('grind-the-terms').evaluate(async el=>{
  const url=new URL('../games/grind-the-terms/skins/au/skin.json',location.href);
  const skin=await(await fetch(url)).json();
  const keys=['cloudsFar','cloudsNear','dataCity','graffitiWall','road'];
  const images=await Promise.all(keys.map(async key=>{const i=new Image();i.src=new URL(skin.files[key],url).href;await i.decode();return {key,assetName:skin.files[key],w:i.naturalWidth,h:i.naturalHeight}}));
  const canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
  const original=ctx.drawImage.bind(ctx),seen=[];
  ctx.drawImage=(...args)=>{
    if(args[0] instanceof HTMLImageElement)seen.push(args[0].src.split('/').pop());
    if(args[0] instanceof HTMLCanvasElement&&args[0].width===1280&&args[0].height===190)seen.push('cached-cloud');
    return original(...args);
  };
  el.game.start();el.game.draw(ctx,canvas.width,canvas.height);
  ctx.drawImage=original;
  return {images,seen};
 });
 expect(result.images).toHaveLength(5);
 for(const i of result.images){
  expect(i.w).toBe(1280);
  expect(i.h).toBeGreaterThan(80);
  // Compare the drawn asset to its declared skin path, regardless of asset version or extension.
  if(i.key==='cloudsFar'||i.key==='cloudsNear')expect(result.seen).toContain('cached-cloud');
  else expect(result.seen,`missing rendered ${i.key}: ${i.assetName}`).toContain(i.assetName);
 }
 await page.locator('grind-the-terms').screenshot({path:'test-results/screenshots/approved-illustrated-scene-v9.png'});
});

test('Fony gameplay atlas uses crisp no-interpolation ink while scenery retains smoothing',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 const data=await page.locator('grind-the-terms').evaluate(el=>{
   const game=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
   const original=ctx.drawImage.bind(ctx),seen=[];
   ctx.drawImage=(...args)=>{
     if(args[0]?.naturalWidth===2048)seen.push({smooth:ctx.imageSmoothingEnabled,sourceW:args[3],destW:args[7]});
     return original(...args);
   };
   game.start();game.draw(ctx,canvas.width,canvas.height);
   ctx.drawImage=original;
   return {seen,after:ctx.imageSmoothingEnabled};
 });
 expect(data.seen.length).toBeGreaterThan(0);
 expect(data.seen.every(s=>s.smooth===false&&s.sourceW===256&&s.destW===128)).toBe(true);
 expect(data.after).toBe(true);
 await page.locator('grind-the-terms').screenshot({path:'test-results/screenshots/fony-crisp-legal-smog-v6.png'});
});

test('world-space ACCEPT and physical sidewalk scroll at identical speed',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 const result=await page.locator('grind-the-terms').evaluate(el=>{
   el.setAttribute('data-qa-ground-scroll','');
   const game=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
   const draw=ctx.drawImage.bind(ctx),fill=ctx.fillText.bind(ctx),scans=[];
   let roadX=null,acceptX=null;
   ctx.drawImage=(...args)=>{
     if(args[0]?.src?.includes('terms_illustrated_sidewalk_road_v5.png')&&roadX===null)roadX=args.length===9?args[5]-args[1]:args[1];
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

test('near and far cloud artwork has compact typography metadata and separate assets',async({page})=>{
 await page.goto('/demo/');
 const detail=await page.evaluate(async()=>{
  const url=new URL('../games/grind-the-terms/skins/au/skin.json',location.href);
  const data=await(await fetch(url)).json();return {type:data.cloudTypography,far:data.files.cloudsFar,near:data.files.cloudsNear};
 });
 expect(detail.type.largestRenderedTextPx).toBeLessThanOrEqual(10);
 expect(detail.type.heading).toBe('TERMS & CONDITIONS');
 expect(detail.near).not.toBe(detail.far);
 expect(detail.near).toContain('cloud_canopy_near_v9.svg');
});


test('double ollie is always available without AIR BOOST pickup',async({page})=>{
 await page.goto('/demo/');
 const result=await page.locator('grind-the-terms').evaluate(el=>{
  const g=el.game;g.start();
  g.input('up',true);g.update(1/60);g.input('up',false);
  for(let i=0;i<8;i++)g.update(1/60);
  const first=g.result().stats;
  g.input('up',true);g.update(1/60);g.input('up',false);
  const second=g.result().stats;
  g.input('up',true);g.update(1/60);g.input('up',false);
  return {first,second,third:g.result().stats};
 });
 expect(result.first.jumpCount).toBe(1);
 expect(result.second.jumpCount).toBe(2);
 expect(result.second.boardY).toBeLessThan(result.first.boardY);
 expect(result.second.doubleJumpAlwaysOn).toBe(true);
 expect(result.third.jumpCount).toBe(2);
});

test('speed toggle exactly doubles baseline after the ramp',async({page})=>{
 await page.goto('/demo/');
 const stats=await page.locator('grind-the-terms').evaluate(el=>{
  const g=el.game;g.start();g.input('speed',true);
  for(let i=0;i<10;i++)g.update(.05);
  return g.result().stats;
 });
 expect(stats.speedEnabled).toBe(true);
 expect(stats.acceleration).toBe(1);
 expect(stats.runSpeed/stats.normalSpeed).toBeGreaterThan(1.99);
 expect(stats.runSpeed/stats.normalSpeed).toBeLessThan(2.01);
});

test('ground motion uses low stable Fony pose with persistent board',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 const result=await page.locator('grind-the-terms').evaluate(el=>{
  const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
  const seen=[],draw=ctx.drawImage.bind(ctx);g.start();
  ctx.drawImage=(...args)=>{if(args.length===9&&args[3]===256&&args[4]===256)seen.push({sx:args[1],sy:args[2]});return draw(...args)};
  for(let frame=0;frame<6;frame++){g.update(.05);g.draw(ctx,canvas.width,canvas.height)}
  ctx.drawImage=draw;
  return seen;
 });
 expect(result.length).toBeGreaterThan(3);
 // Two approved crouch/recovery cells alternate, both safely on the board baseline.
 for(const frame of result){expect(frame.sy).toBe(256);expect([512,768]).toContain(frame.sx)}
});


test('the legal-smog canopy uses no rigid paper cards and keeps tiny text',async({page})=>{
 await page.goto('/demo/');
 const content=await page.evaluate(async()=>{
  const jsonUrl=new URL('../games/grind-the-terms/skins/au/skin.json',location.href);
  const skin=await(await fetch(jsonUrl)).json();
  const layers=await Promise.all(['cloudsFar','cloudsNear'].map(async key=>(await fetch(new URL(skin.files[key],jsonUrl))).text()));
  return {layers,print:skin.cloudTypography};
 });
 expect(content.layers).toHaveLength(2);
 for(const svg of content.layers){
   expect(svg).toContain('<clipPath');
   expect(svg).toContain('Q'); // rounded cloud lobes rather than rectangular type cards
   expect(svg).not.toContain('<rect');
   expect(svg).toContain('font-size="3.');
 }
 expect(content.print.layers).toBe(3);
});

test('normal cruising remains stable and speed toggle doubles it',async({page})=>{
 await page.goto('/demo/');
 const stat=await page.locator('grind-the-terms').evaluate(el=>{
   const g=el.game;g.start();
   for(let i=0;i<20;i++)g.update(1/60);
   const normal=g.result().stats.normalSpeed;
   g.input('speed',true);
   for(let i=0;i<40;i++)g.update(1/60);
   const fast=g.result().stats;
   return {normal,fast};
 });
 expect(stat.normal).toBeGreaterThanOrEqual(180);
 expect(stat.fast.normalSpeed).toBeGreaterThanOrEqual(stat.normal);
 expect(stat.fast.runSpeed/stat.fast.normalSpeed).toBeGreaterThan(1.99);
 expect(stat.fast.runSpeed/stat.fast.normalSpeed).toBeLessThan(2.01);
});


test('parallax renderer only draws visible portions of large scenic tiles',async({page})=>{
 await page.goto('/demo/');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 const result=await page.locator('grind-the-terms').evaluate(el=>{
   const g=el.game,c=el.shadowRoot.querySelector('canvas'),ctx=c.getContext('2d');
   const original=ctx.drawImage.bind(ctx),drawn=[];
   ctx.drawImage=(...args)=>{
     if(args.length===9&&args[0]?.width===1280&&args[0]?.height===190)
       drawn.push({kind:'raster-cloud',sourceWidth:args[3],destWidth:args[7]});
     if(args.length===9&&args[0]?.src?.includes('terms_illustrated_datacenter_city'))
       drawn.push({kind:'city',sourceWidth:args[3],destWidth:args[7]});
     return original(...args);
   };
   g.start();g.draw(ctx,c.width,c.height);ctx.drawImage=original;
   return drawn;
 });
 expect(result.filter(x=>x.kind==='raster-cloud').length).toBeGreaterThanOrEqual(2);
 expect(result.some(x=>x.kind==='city')).toBe(true);
 for(const x of result)expect(x.destWidth).toBeLessThanOrEqual(650);
});
