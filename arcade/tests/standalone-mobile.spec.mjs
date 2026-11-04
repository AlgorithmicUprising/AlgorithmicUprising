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
 expect(Math.abs(display.width/display.height-16/9)).toBeLessThan(.06);
 expect(panel.y).toBeGreaterThanOrEqual(display.y+display.height-2);
 expect(host.y+host.height).toBeGreaterThanOrEqual(panel.y+panel.height-2);
 expect(picker.y).toBeGreaterThanOrEqual(host.y+host.height-2);
 const controls=await game.locator('.deck button').evaluateAll(nodes=>nodes.map(n=>({key:n.dataset.key,w:n.getBoundingClientRect().width,h:n.getBoundingClientRect().height,x:n.getBoundingClientRect().x})));
 expect(controls).toHaveLength(3);
 for(const b of controls)expect(b.h).toBeGreaterThanOrEqual(44);
 expect(controls.find(b=>b.key==='special').w).toBeGreaterThan(controls.find(b=>b.key==='speed').w);
 expect(controls.find(b=>b.key==='special').x).toBeLessThan(controls.find(b=>b.key==='speed').x);
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
 for(const key of ['special','speed','jump']){
  const button=game.locator('button[data-key='+key+']'),box=await button.boundingBox();
  expect(box).not.toBeNull();
  expect(box.width).toBeGreaterThanOrEqual(44);
  expect(box.x+box.width).toBeLessThanOrEqual(320);
 }
});
