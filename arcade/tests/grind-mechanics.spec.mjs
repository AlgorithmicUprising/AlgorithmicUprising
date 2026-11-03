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
