import {test,expect} from '@playwright/test';
const url='/games/tag-before-training/demo/';
const start=async page=>{await page.goto(url);const el=page.locator('tag-before-training');await expect(el).toHaveAttribute('data-art-ready','true');await el.locator('[part=start]').click();return el};

test('Tag standalone loads the approved art without missing assets',async({page},info)=>{
 const failures=[];page.on('response',r=>{if(r.status()>=400&&r.url().includes('/tag-before-training/'))failures.push(r.url())});page.on('pageerror',e=>failures.push(e.message));
 const el=await start(page);await expect(page.locator('#events')).toContainText('usingPlaceholder":false');
 await el.evaluate(e=>{const g=e.game.world;g.x=484;g.y=190;g.facing=-Math.PI/2});await page.keyboard.down(' ');await expect.poll(()=>el.evaluate(e=>e.game.world.stats.tagsSprayed),{timeout:8000}).toBe(1);await page.keyboard.up(' ');
 expect(await el.evaluate(e=>e.game.world.stats.tagsSprayed)).toBe(1);expect(await el.evaluate(e=>e.game.world.score)).toBeGreaterThanOrEqual(100);
 await el.screenshot({path:`test-results/screenshots/tag-art-${info.project.name}.png`});expect(failures).toEqual([]);
});
test('Tag touch deck leaves the play area clear and supports drag plus spray',async({page},info)=>{
 test.skip(!info.project.name.startsWith('mobile'),'Touch layout');const el=await start(page);
 const screen=await el.locator('.screen').boundingBox(),deck=await el.locator('.tag-deck').boundingBox(),spray=await el.locator('[data-key=spray]').boundingBox();
 expect(screen.y+screen.height).toBeLessThanOrEqual(deck.y+2);expect(spray.height).toBeGreaterThanOrEqual(80);expect(deck.y+deck.height).toBeLessThanOrEqual((await el.boundingBox()).y+(await el.boundingBox()).height+2);
 const zone=el.locator('.tag-stick'),box=await zone.boundingBox(),x=box.x+box.width/2,y=box.y+box.height/2,before=await el.evaluate(e=>e.game.world.x);
 await zone.dispatchEvent('pointerdown',{pointerId:77,pointerType:'touch',clientX:x,clientY:y});await zone.dispatchEvent('pointermove',{pointerId:77,pointerType:'touch',clientX:x+42,clientY:y});
 await el.locator('[data-key=spray]').dispatchEvent('pointerdown',{pointerId:78,pointerType:'touch'});await page.waitForTimeout(500);
 expect(await el.evaluate(e=>e.game.world.x)).toBeGreaterThan(before+20);expect(await el.evaluate(e=>e.game.world.paint)).toBeLessThan(100);
 await zone.dispatchEvent('pointerup',{pointerId:77,pointerType:'touch'});await el.locator('[data-key=spray]').dispatchEvent('pointerup',{pointerId:78,pointerType:'touch'});
 await page.setViewportSize({width:320,height:760});await page.waitForTimeout(100);expect(await el.evaluate(e=>e.state)).toBe('playing');await el.screenshot({path:`test-results/screenshots/tag-small-${info.project.name}.png`});
});
test('Tag custom text, left-handed controls and placeholder mode persist safely',async({page})=>{
 const posted=[];page.on('request',r=>{if(r.method()==='POST')posted.push(r.url())});const el=await start(page);
 await el.locator('[part=settings]').click();await expect(el.locator('dialog')).toBeVisible();expect(await el.evaluate(e=>e.state)).toBe('paused');
 await el.locator('input[name=tag]').fill('MY ART');await el.locator('input[name=left]').check();await el.locator('select[name=motion]').selectOption('on');await el.getByRole('button',{name:'SAVE / RESUME'}).click();
 await expect.poll(()=>el.evaluate(e=>e.state)).toBe('playing');await expect(el).toHaveAttribute('data-left-handed','');await page.reload();await expect(page.locator('tag-before-training')).toHaveAttribute('data-art-ready','true');
 const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('au-arcade:v1:tag-before-training:settings')));expect(saved.text).toBe('MY ART');expect(saved.motion).toBe('on');expect(saved.left).toBe(true);expect(posted).toEqual([]);
 await page.selectOption('#skin','placeholder');await expect(page.locator('tag-before-training')).not.toHaveAttribute('data-art-ready','true');await page.locator('tag-before-training [part=start]').click();expect(await page.locator('tag-before-training').evaluate(e=>e.state)).toBe('playing');
});
test('Tag pause clears held controls and game-over uses Tag share/retry text',async({page})=>{
 const el=await start(page);await el.evaluate(e=>{e.game.input('spray',true);e.pause('host')});expect(await el.evaluate(e=>e.game.world.spraying)).toBe(false);await el.locator('[part=resume]').click();
 await el.evaluate(e=>{e.game.world.score=4250;e.game.world.meter=100;e.game.world.alive=false;e.addEventListener('game:share',ev=>{e.shared=ev.detail;ev.preventDefault()})});
 await expect(el.locator('.overlay')).toContainText('TRAINING COMPLETE');await expect(el.locator('[part=again]')).toHaveText('ROLL AGAIN');await el.locator('[part=share]').click();expect(await el.evaluate(e=>e.shared.text)).toContain('held the alley');
 await el.locator('[part=again]').click();expect(await el.evaluate(e=>e.game.world.meter)).toBe(0);expect(await el.evaluate(e=>e.best)).toBe(4250);
});
