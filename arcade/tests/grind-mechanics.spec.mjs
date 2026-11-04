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
 expect(poses.source).toEqual([1024,640]);
 expect(poses.grid.anchorX).toBe(64);expect(poses.grid.anchorY).toBe(117);
 expect(poses.boxes).toHaveLength(39);
 for(const [i,b] of poses.boxes.entries()){
  expect(b.pixels,`frame ${i} missing pixels`).toBeGreaterThan(250);
  expect(b.minX,`frame ${i} clips left`).toBeGreaterThan(3);
  expect(b.maxX,`frame ${i} clips right`).toBeLessThan(125);
  expect(b.minY,`frame ${i} clips top`).toBeGreaterThan(3);
  expect(b.maxY,`frame ${i} exceeds foot baseline`).toBeLessThanOrEqual(118);
  expect(b.maxY,`frame ${i} not aligned to foot baseline`).toBeGreaterThanOrEqual(113);
 }
});

test('running and bail animations use stable on-screen actor origin and never loop bail',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('grind-the-terms');
 await expect(page.locator('#events')).toContainText('game:skin-loaded');
 const result=await game.evaluate(el=>{
  const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
  const original=ctx.drawImage.bind(ctx),poses=[];
  ctx.drawImage=(...args)=>{if(args.length===9&&args[0]?.naturalWidth===1024)poses.push({sx:args[1],sy:args[2],dx:args[5],dy:args[6],w:args[7],h:args[8]});return original(...args)};
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
 expect(result.final.sx).toBe((26%8)*128);
 expect(result.final.sy).toBe(Math.floor(26/8)*128);
 expect(result.after).toEqual(result.final);
});

test('visible rail and Fony board share the grind surface; legs touch ground',async({page})=>{
  await page.goto('/demo/');
  const game=page.locator('grind-the-terms');
  await expect(page.locator('#events')).toContainText('game:skin-loaded');
  const result=await game.evaluate(async el=>{
    const skinUrl=new URL('../games/grind-the-terms/skins/au/skin.json',location.href);
    const skin=await(await fetch(skinUrl)).json();
    const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
    const original=ctx.drawImage.bind(ctx),calls=[];
    ctx.drawImage=(...args)=>{
      if(args.length===9)calls.push({width:args[0]?.naturalWidth,sx:args[1],sy:args[2],sh:args[4],dx:args[5],dy:args[6],w:args[7],h:args[8]});
      return original(...args);
    };
    g.start();
    for(let i=0;i<170;i++)g.update(1/60);
    g.input('tap',true);
    let caught=false;
    for(let i=0;i<100;i++){g.update(1/60);if(g.result().stats.grindMs>0){caught=true;break}}
    if(caught)g.draw(ctx,canvas.width,canvas.height);
    const rail=calls.find(x=>x.width===576&&x.sx===432&&x.sy===112+skin.rail.clipTopCellY);
    const fony=calls.find(x=>x.width===1024);
    const railY=rail?rail.dy+rail.h*(skin.rail.surfaceCellY-skin.rail.clipTopCellY)/rail.sh:null;
    const legY=rail?rail.dy+rail.h:null;
    const boardY=fony?fony.dy+skin.grid.skater.anchorY*skin.grid.skater.displayScale:null;
    g.input('tap',false);g.update(1/60);calls.length=0;g.draw(ctx,canvas.width,canvas.height);
    const popped=calls.find(x=>x.width===1024);
    const popY=popped?popped.dy+skin.grid.skater.anchorY:null;
    ctx.drawImage=original;
    return {caught,railY,legY,boardY,popY};
  });
  expect(result.caught).toBe(true);
  expect(result.legY).toBeCloseTo(300,5);
  expect(Math.abs(result.railY-result.boardY)).toBeLessThan(1);
  expect(result.popY).toBeLessThan(result.railY);
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
test('original ACCEPT art renders without a floating green highlight',async({page})=>{
  await page.goto('/demo/');
  const game=page.locator('grind-the-terms');
  const geometry=await game.evaluate(el=>{
    const g=el.game,canvas=el.shadowRoot.querySelector('canvas'),ctx=canvas.getContext('2d');
    const original=ctx.drawImage.bind(ctx),ops=[];
    ctx.drawImage=(...args)=>{if(args.length===9&&args[0]?.naturalWidth===576&&args[1]===0&&args[2]===0)ops.push({y:args[6],height:args[8]});return original(...args)};
    g.start();for(let i=0;i<270;i++)g.update(1/60);
    g.draw(ctx,canvas.width,canvas.height);ctx.drawImage=original;return ops;
  });
  expect(geometry.length).toBeGreaterThan(0);
  expect(geometry[0].y+92/112*geometry[0].height).toBeCloseTo(300,4);
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
 expect(measured).toBeGreaterThan(190);
 expect(measured).toBeLessThan(215);
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
   return {popup:sample(226,259),modal:sample(406,241)};
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
