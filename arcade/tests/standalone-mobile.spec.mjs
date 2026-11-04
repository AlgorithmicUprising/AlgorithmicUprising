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
