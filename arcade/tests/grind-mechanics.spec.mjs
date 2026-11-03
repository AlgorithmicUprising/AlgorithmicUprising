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
  expect(b.maxY,`frame ${i} not aligned to foot baseline`).toBeGreaterThanOrEqual(115);
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
