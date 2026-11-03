import {test,expect} from '@playwright/test';

// These tests run against a real Chromium browser, not a DOM simulation.
test('both games load their Web Components and render starting UI',async({page},testInfo)=>{
 await page.goto('/demo/');
 await expect(page.locator('grind-the-terms')).toBeVisible();
 await expect(page.locator('tag-before-training')).toBeVisible();
 await expect(page.locator('grind-the-terms button[part=start]')).toHaveText('START');
 await expect(page.locator('tag-before-training button[part=start]')).toHaveText('START');
 await expect(page.locator('#events')).toContainText('game:ready');
 const components=await page.evaluate(()=>['grind-the-terms','tag-before-training'].map(t=>Boolean(customElements.get(t))));
 expect(components).toEqual([true,true]);
});

test('Grind starts, draws a moving game, and pauses for host',async({page},testInfo)=>{
 await page.goto('/demo/');
 const el=page.locator('grind-the-terms');
 await el.locator('button[part=start]').click();
 await expect(page.locator('#events')).toContainText('game:start');
 await page.waitForTimeout(250);
 const pixels=await el.locator('canvas').evaluate(c=>{const d=c.getContext('2d').getImageData(0,0,Math.min(c.width,100),Math.min(c.height,100)).data;return [...d].some(v=>v!==0)});
 expect(pixels).toBeTruthy();
 await el.screenshot({path:`test-results/screenshots/grind-${testInfo.project.name}.png`});
 await el.evaluate(e=>e.pause('host'));
 await expect(page.locator('#events')).toContainText('game:pause');
 expect(await el.evaluate(e=>e.state)).toBe('paused');
 await el.evaluate(e=>e.resume());
 expect(await el.evaluate(e=>e.state)).toBe('playing');
});

test('Tag loads, moves and draws a playable alley',async({page},testInfo)=>{
 await page.goto('/demo/');
 const el=page.locator('tag-before-training');
 await el.locator('button[part=start]').click();
 expect(await el.evaluate(e=>e.state)).toBe('playing');
 await page.waitForTimeout(250);
 await el.screenshot({path:`test-results/screenshots/tag-${testInfo.project.name}.png`});
 const size=await el.locator('canvas').evaluate(c=>[c.width,c.height]);
 expect(size[0]).toBeGreaterThan(0);expect(size[1]).toBeGreaterThan(0);
 await el.evaluate(e=>e.pause('host'));
 expect(await el.evaluate(e=>e.state)).toBe('paused');
});

test('touch buttons are provided in Tag on phone viewport',async({page},testInfo)=>{
 test.skip(!testInfo.project.name.startsWith('mobile'),'Touch-specific test');
 await page.goto('/demo/');
 const el=page.locator('tag-before-training');
 await expect(el.locator('button[data-key=spray]')).toBeVisible();
 await expect(el.locator('button[data-key=left]')).toBeVisible();
 await el.locator('button[part=start]').click();
 await el.locator('button[data-key=spray]').dispatchEvent('pointerdown',{pointerId:1});
 await el.locator('button[data-key=spray]').dispatchEvent('pointerup',{pointerId:1});
 expect(await el.evaluate(e=>e.state)).toBe('playing');
});


test('Grind gives a safe learning window and displays a resume action',async({page})=>{
 await page.goto('/demo/');
 const el=page.locator('grind-the-terms');
 await el.locator('button[part=start]').click();
 await page.waitForTimeout(5500);
 expect(await el.evaluate(e=>e.state)).toBe('playing');
 await el.evaluate(e=>e.pause('player'));
 expect(await el.evaluate(e=>e.state)).toBe('paused');
 await expect(el.locator('button[part=resume]')).toBeVisible();
 await el.locator('button[part=resume]').click();
 expect(await el.evaluate(e=>e.state)).toBe('playing');
});

test('game-over saves personal best and restart resets the run',async({page})=>{
 await page.goto('/demo/');
 const el=page.locator('grind-the-terms');
 await el.locator('button[part=start]').click();
 // Simulate the natural game-over condition through the greybox game API.
 await el.evaluate(e=>{e._originalScore=e.game.score;e._originalOver=e.game.over;e.game.score=()=>123;e.game.over=()=>true});
 await expect(el.locator('button[part=again]')).toBeVisible();
 await expect(el.locator('.overlay')).toContainText('BEST 123');
 expect(await el.evaluate(e=>e.best)).toBe(123);
 await el.evaluate(e=>{e.game.score=e._originalScore;e.game.over=e._originalOver});
 await el.locator('button[part=again]').click();
 expect(await el.evaluate(e=>e.state)).toBe('playing');
 await page.reload();
 expect(await page.locator('grind-the-terms').evaluate(e=>e.best)).toBe(123);
 expect(await page.locator('grind-the-terms').evaluate(e=>e.state)).toBe('title');
});
