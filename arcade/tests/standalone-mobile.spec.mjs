import {test,expect} from '@playwright/test';

// Covers the previously untested standalone pages on both Chromium and iPhone WebKit.
const standalone='/games/grind-the-terms/demo/';
const embedded='/games/grind-the-terms/demo/embed.html';

test('standalone page initializes the actual game and Fony skin',async({page},testInfo)=>{
  const errors=[],missing=[];
  page.on('pageerror',error=>errors.push(String(error)));
  page.on('response',response=>{
    if(response.status()>=400 && /\/games\/grind-the-terms\//.test(response.url()))
      missing.push(response.status()+' '+response.url());
  });
  await page.goto(standalone);
  const game=page.locator('grind-the-terms');
  await expect(game.locator('button[part=start]')).toBeVisible();
  await expect(page.locator('#events')).toContainText('game:skin-loaded');
  await expect(page.locator('#events')).not.toContainText('SKIN_LOAD_FAILED');
  const dimensions=await game.locator('canvas').evaluate(c=>({width:c.width,height:c.height}));
  expect(dimensions.width).toBeGreaterThan(250);
  expect(dimensions.height).toBeGreaterThan(150);
  const box=await game.boundingBox();
  expect(box).not.toBeNull();
  expect(box.y).toBeGreaterThanOrEqual(0);
  if(testInfo.project.name.startsWith('mobile')){
    expect(box.y).toBeLessThan(250); // game is visible above the fold, not below long instructions
    expect(box.y+Math.min(box.height,200)).toBeLessThanOrEqual(844);
  }
  expect(missing).toEqual([]);
  expect(errors).toEqual([]);
});

test('standalone game starts and touch gameplay renders',async({page},testInfo)=>{
  await page.goto(standalone);
  const game=page.locator('grind-the-terms');
  await expect(game.locator('button[part=start]')).toBeVisible();
  await game.locator('button[part=start]').click();
  await expect(game).toHaveJSProperty('state','playing');
  const canvas=game.locator('canvas');
  await expect(canvas).toBeVisible();
  const sample=await canvas.evaluate(c=>{
    const data=c.getContext('2d').getImageData(0,0,Math.min(50,c.width),Math.min(50,c.height)).data;
    return Array.from(data).some(v=>v!==0);
  });
  expect(sample).toBe(true);
  await game.screenshot({path:`test-results/screenshots/standalone-${testInfo.project.name}.png`});
  if(testInfo.project.name.startsWith('mobile')){
    await canvas.tap({position:{x:150,y:110}});
    await game.evaluate(el=>el.pause('host'));
    await expect(game.locator('button[part=resume]')).toBeVisible();
    await game.locator('button[part=resume]').click();
    await expect(game).toHaveJSProperty('state','playing');
  }
});

test('standalone Fony/placeholder selection never blanks the game',async({page})=>{
  await page.goto(standalone);
  const game=page.locator('grind-the-terms');
  await expect(page.locator('#events')).toContainText('game:skin-loaded');
  await page.locator('#placeholder').click();
  await expect(game).not.toHaveAttribute('skin',/.+/);
  await page.locator('#au').click();
  await expect(game).toHaveAttribute('skin','../skins/au/skin.json');
  await expect(page.locator('#events')).not.toContainText('SKIN_LOAD_FAILED');
  await expect(game.locator('button[part=start]')).toBeVisible();
});

test('iframe embed loads game bundle and Fony art',async({page})=>{
  const broken=[];
  page.on('pageerror',error=>broken.push(String(error)));
  await page.goto(embedded);
  const game=page.locator('grind-the-terms');
  await expect(game.locator('button[part=start]')).toBeVisible();
  await expect(game).toHaveJSProperty('version','0.2.0-dev');
  await game.locator('button[part=start]').click();
  await expect(game).toHaveJSProperty('state','playing');
  expect(broken).toEqual([]);
});

test('portrait phone cabinet is contained and does not cover artwork buttons',async({page},info)=>{
 test.skip(!info.project.name.startsWith('mobile'),'Phone portrait only');
 await page.goto(standalone);
 const game=page.locator('grind-the-terms'),deck=game.locator('.deck'),screen=game.locator('.screen');
 await expect(deck).toBeVisible();
 const [host,display,panel,picker]=await Promise.all([game.boundingBox(),screen.boundingBox(),deck.boundingBox(),page.locator('#au').boundingBox()]);
 expect(host).not.toBeNull();expect(display).not.toBeNull();expect(panel).not.toBeNull();expect(picker).not.toBeNull();
 // The ENTIRE CRT tablet including the deck is 9:16; the upper screen is
 // also portrait and the renderer must not letterbox a landscape playfield.
 expect(Math.abs(host.width/host.height-9/16)).toBeLessThan(.025);
 expect(display.width/display.height).toBeGreaterThan(.72);
 expect(display.width/display.height).toBeLessThan(1.05);
 expect(display.height).toBeGreaterThan(display.width);
 expect(panel.y).toBeGreaterThanOrEqual(display.y+display.height-2);
 expect(host.y+host.height).toBeGreaterThanOrEqual(panel.y+panel.height-2);
 expect(picker.y).toBeGreaterThanOrEqual(host.y+host.height-2);
 const controls=await game.locator('.deck button').evaluateAll(nodes=>nodes.map(n=>({key:n.dataset.key,w:n.getBoundingClientRect().width,h:n.getBoundingClientRect().height,x:n.getBoundingClientRect().x})));
 expect(controls).toHaveLength(3);
 for(const b of controls)expect(b.h).toBeGreaterThanOrEqual(44);
 expect(controls.find(b=>b.key==='boost').w).toBeGreaterThan(controls.find(b=>b.key==='trick').w);
 expect(controls.find(b=>b.key==='boost').x).toBeLessThan(controls.find(b=>b.key==='trick').x);
});

test('320px phone width keeps the Ø A U controls usable',async({page},info)=>{
 test.skip(!info.project.name.startsWith('mobile'),'Phone portrait only');
 await page.setViewportSize({width:320,height:740});
 await page.goto(standalone);
 const game=page.locator('grind-the-terms');
 const host=await game.boundingBox();
 const deck=await game.locator('.deck').boundingBox();
 expect(host).not.toBeNull();expect(deck).not.toBeNull();
 expect(host.width).toBeLessThanOrEqual(320);
 expect(host.y+host.height).toBeGreaterThanOrEqual(deck.y+deck.height-2);
 for(const key of ['boost','trick','jump']){
  const button=game.locator('button[data-key='+key+']'),box=await button.boundingBox();
  expect(box).not.toBeNull();
  expect(box.width).toBeGreaterThanOrEqual(44);
  expect(box.x+box.width).toBeLessThanOrEqual(320);
 }
});

test('mobile A performs an aerial trick and Ø boosts while held',async({page},info)=>{
 test.skip(!info.project.name.startsWith('mobile'),'Mobile cabinet only');
 await page.goto(standalone);
 const game=page.locator('grind-the-terms');
 await game.evaluate(el=>el.setAttribute('data-qa-rocket-charge',''));
 await game.locator('button[part=start]').click();
 const a=game.locator('button[data-key=trick]'),u=game.locator('button[data-key=jump]'),zero=game.locator('button[data-key=boost]');
 await u.dispatchEvent('pointerdown',{pointerId:2});
 await game.evaluate(el=>el.game.update(.05));
 await u.dispatchEvent('pointerup',{pointerId:2});
 const before=await game.evaluate(el=>el.game.result().stats);
 expect(before.boardY).toBeLessThan(310);
 await a.click();
 const trick=await game.evaluate(el=>el.game.result().stats);
 expect(trick.tricksUsed).toBe(1);
 expect(trick.speedMultiplier).toBe(1);
 expect(trick.runSpeed).toBe(trick.normalSpeed);
 const charge=trick.sprayGauge;
 await zero.dispatchEvent('pointerdown',{pointerId:3});
 await game.evaluate(el=>el.game.update(.1));
 const boosted=await game.evaluate(el=>el.game.result().stats);
 expect(boosted.boostHeld).toBe(true);
 expect(boosted.boostActive).toBe(true);
 expect(boosted.speedMultiplier).toBe(2);
 expect(boosted.sprayGauge).toBeLessThan(charge);
 await zero.dispatchEvent('pointerup',{pointerId:3});
 const released=await game.evaluate(el=>el.game.result().stats);
 expect(released.boostActive).toBe(false);
 expect(released.speedMultiplier).toBe(1);
});

test('iPhone long U hold cannot select text or open a context menu',async({page},info)=>{
 test.skip(!info.project.name.startsWith('mobile'),'Mobile long-press behavior');
 await page.goto(standalone);
 const game=page.locator('grind-the-terms');
 const jump=game.locator('button[data-key=jump]');
 const result=await jump.evaluate(el=>{
   const style=getComputedStyle(el);
   const select=el.dispatchEvent(new Event('selectstart',{bubbles:true,composed:true,cancelable:true}));
   const context=el.dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,composed:true,cancelable:true}));
   const touch=el.dispatchEvent(new Event('touchstart',{bubbles:true,composed:true,cancelable:true}));
   return {select,context,touch,userSelect:style.userSelect,touchAction:style.touchAction};
 });
 expect(result.select).toBe(false);
 expect(result.context).toBe(false);
 expect(result.touch).toBe(false);
 expect(result.userSelect).toBe('none');
 expect(result.touchAction).toBe('none');
 await game.locator('button[part=start]').click();
 await jump.dispatchEvent('pointerdown',{pointerId:7});
 await game.evaluate(el=>{for(let i=0;i<10;i++)el.game.update(.05)});
 await jump.dispatchEvent('pointerup',{pointerId:7});
 expect(await game.evaluate(el=>el.game.result().stats.boardY)).toBeLessThanOrEqual(310);
});

test('portrait camera fills the tablet game screen without landscape letterboxing',async({page},info)=>{
 test.skip(!info.project.name.startsWith('mobile'),'Portrait screen rendering');
 await page.goto(standalone);
 const game=page.locator('grind-the-terms');
 await game.locator('button[part=start]').click();
 const measures=await game.locator('canvas').evaluate(c=>{
   const w=c.width,h=c.height,ctx=c.getContext('2d');
   const top=ctx.getImageData(Math.floor(w*.25),Math.floor(h*.15),1,1).data;
   return {ratio:w/h,top:Array.from(top)};
 });
 expect(measures.ratio).toBeLessThan(1.05);
 expect(measures.ratio).toBeGreaterThan(.70);
 expect(measures.top[3]).toBe(255);
});

test('real touchscreen tap on U still initiates an ollie in Chromium and WebKit',async({page},info)=>{
 test.skip(!info.project.name.startsWith('mobile'),'Mobile touch only');
 await page.goto(standalone);
 const game=page.locator('grind-the-terms');
 await game.locator('button[part=start]').click();
 const before=await game.evaluate(el=>el.game.result().stats.boardY);
 await game.locator('button[data-key=jump]').tap();
 await game.evaluate(el=>el.game.update(.04));
 const after=await game.evaluate(el=>el.game.result().stats.boardY);
 expect(after).toBeLessThan(before-10);
});
