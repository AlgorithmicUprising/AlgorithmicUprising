import { test, expect } from '@playwright/test';

const demo = '/games/cookie-wall/demo/';
const boot = async (page, path = demo + '?skin=au&seed=0') => {
  await page.goto(path);
  const game = page.locator('cookie-wall');
  await expect(game.locator('[part=start]')).toBeVisible();
  await expect.poll(() => game.evaluate(e => e.readySent)).toBe(true);
  return game;
};
const within = (outer, item) => item.x >= outer.x - 1 && item.y >= outer.y - 1 &&
  item.x + item.width <= outer.x + outer.width + 1 && item.y + item.height <= outer.y + outer.height + 1;

test('one square court fits the container, launches, pauses, and rotates in place', async ({page}, info) => {
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  const game = await boot(page);
  const phone = info.project.name.includes('mobile');
  await expect(game).toHaveAttribute('data-orientation', phone ? 'portrait' : 'landscape');
  const board = game.locator('canvas'), outer = await game.boundingBox(), court = await board.boundingBox();
  expect(Math.abs(court.width - court.height)).toBeLessThan(1.1); expect(within(outer, court)).toBe(true);
  for (const button of ['pause','sound','settings']) {
    const box = await game.locator('[part=' + button + ']').boundingBox();
    expect(box.height).toBeGreaterThanOrEqual(48); expect(box.width).toBeGreaterThanOrEqual(48); expect(within(outer, box)).toBe(true);
  }
  if (phone) expect((await game.locator('[data-position-strip]').boundingBox()).y).toBeGreaterThan(court.y + court.height);
  await game.screenshot({path:'test-results/screenshots/cookie-title-' + info.project.name + '.png'});
  await game.locator('[part=start]').click();
  await page.keyboard.down('ArrowRight'); await expect.poll(() => game.evaluate(e => e.game.world.paddleX)).toBeGreaterThan(170);
  await page.keyboard.up('ArrowRight');
  if (phone) await game.locator('[data-primary]').tap(); else await page.keyboard.press('u');
  await expect.poll(() => game.evaluate(e => e.game.world.phase)).toBe('flight');
  await game.screenshot({path:'test-results/screenshots/cookie-play-' + info.project.name + '.png'});
  await page.keyboard.press('p'); await expect(game).toHaveJSProperty('state','paused');
  const paused = await game.evaluate(e=>e.game.world.time);
  await page.setViewportSize(phone ? {width:844,height:390} : {width:320,height:568});
  await expect(game).toHaveAttribute('data-orientation', phone ? 'landscape' : 'portrait');
  expect(await game.evaluate(e=>e.game.world.time)).toBe(paused);
  const rotated = await board.boundingBox(); expect(Math.abs(rotated.width - rotated.height)).toBeLessThan(1.1);
  await game.screenshot({path:'test-results/screenshots/cookie-paused-rotated-' + info.project.name + '.png'});
  await game.locator('[part=resume]').click(); await expect(game).toHaveJSProperty('state','playing');
  expect(errors).toEqual([]);
});

test('320px touch layout, strip target, release and independent launch', async ({page}, info) => {
  test.skip(!info.project.name.startsWith('mobile'), 'Phone input');
  await page.setViewportSize({width:320,height:568});
  const game = await boot(page, demo + 'embed.html?skin=fony&orientation=auto');
  await game.locator('[part=start]').tap();
  const box = await game.locator('[data-position-strip]').boundingBox();
  // WebKit and Chromium both deliver real captured pointer events for a mouse drag.
  await page.mouse.move(box.x+box.width*.85,box.y+box.height*.5); await page.mouse.down();
  await expect.poll(()=>game.evaluate(e=>e.game.world.paddleX)).toBeGreaterThan(230);
  await page.mouse.up(); await game.locator('[data-primary]').tap();
  await expect.poll(()=>game.evaluate(e=>e.game.world.phase)).toBe('flight');
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth && document.documentElement.scrollHeight <= innerHeight)).toBe(true);
  await game.screenshot({path:'test-results/screenshots/cookie-320-' + info.project.name + '.png'});
});

test('two fingers can steer and launch; cancelling the drag releases its target', async ({page,context}, info) => {
  test.skip(info.project.name !== 'mobile-chromium', 'Native multi-touch injection via Chromium');
  const game = await boot(page); await game.locator('[part=start]').tap();
  const strip = await game.locator('[data-position-strip]').boundingBox();
  const launch = await game.locator('[data-primary]').boundingBox();
  const client = await context.newCDPSession(page);
  const finger = {x:strip.x+strip.width*.75, y:strip.y+strip.height*.5, id:1};
  const button = {x:launch.x+launch.width*.5, y:launch.y+launch.height*.5, id:2};
  const send = (type,touchPoints) => client.send('Input.dispatchTouchEvent',{type,touchPoints});
  await send('touchStart',[finger]); await expect.poll(()=>game.evaluate(e=>e.game.world.paddleX)).toBeGreaterThan(196);
  await send('touchStart',[finger,button]);
  await expect.poll(()=>game.evaluate(e=>e.game.world.phase)).toBe('flight');
  await send('touchCancel',[]); expect(await game.evaluate(e=>e.game.world.target)).toBe(null);
});

test('skin swaps, isolated storage, enriched events, exact final drain, owned share, retry and reconnect', async ({page}) => {
  const game = await boot(page);
  await game.evaluate(e => {
    e.setAttribute('storage-key','cookie-qa'); e.log = [];
    for(const t of ['start','pause','resume','over','share','skin-loaded','error','ready']){
      e.addEventListener('game:'+t, ev=>{e.log.push([t,ev.detail]); if(t==='share')ev.preventDefault()});
    }
  });
  await game.evaluate(e=>e.setSkin('../skins/fony/skin.json'));
  await game.locator('[part=start]').click();
  await game.evaluate(e=>{e.pause('host');e.resume('host')});
  await game.evaluate(e=>{
    const g=e.game.world;g.score=120;g.lives=1;g.stats.packetsLost=2;g.stats.wallsCleared=1;
    g.phase='flight';Object.assign(g.packet,{x:10,y:323,vx:0,vy:210});
  });
  await expect(game.locator('[part=again]')).toHaveText('BLOCK AGAIN'); await expect(game).toHaveJSProperty('state','over');
  await expect(game.locator('[data-summary]')).toContainText('WALLS CLEARED 1');
  await game.locator('[part=share]').click();
  const log=await game.evaluate(e=>e.log);
  for(const [type,detail] of log.filter(([type])=>['start','pause','resume','over','share'].includes(type))){
    expect(detail).toMatchObject({game:'cookie-wall',skin:'fony',version:'0.1.0'});
  }
  expect(log.filter(([t])=>t==='over')).toHaveLength(1);
  expect(log.find(([t])=>t==='start')[1].seed).toBe(0);
  expect(log.find(([t])=>t==='resume')[1].reason).toBe('host');
  expect(log.find(([t])=>t==='over')[1]).toMatchObject({cause:'leak',best:120,score:120,stats:{wallsCleared:1,packetsLost:3}});
  expect(log.find(([t])=>t==='share')[1].text).toContain('120 DATA');
  expect(await page.evaluate(()=>localStorage.getItem('cookie-qa:v1:cookie-wall:best'))).toBe('120');
  await game.locator('[part=again]').click(); expect(await game.evaluate(e=>e.game.world.lives)).toBe(3);
  await game.evaluate(e=>e.setSkin('./missing-skin.json')); expect(await game.evaluate(e=>e.game.presentation().id)).toBe('placeholder');
  expect(await game.evaluate(e=>e.log.filter(([t])=>t==='error').length)).toBe(1);
  await game.evaluate(e=>{e.removeAttribute('skin');const parent=e.parentNode;e.remove();parent.append(e)});
  await expect(game).toHaveJSProperty('state','title'); await game.locator('[part=start]').click();
  await expect(game).toHaveJSProperty('state','playing');
});

test('embedded game accepts commands from its parent and rejects other origins and sources', async ({page}) => {
  await page.route('**/cw-test-host', r=>r.fulfill({contentType:'text/html',body:
    '<meta name="viewport" content="width=device-width"><iframe title="Cookie Wall" style="width:320px;height:540px" src="/games/cookie-wall/demo/embed.html?skin=placeholder"></iframe>'}));
  await page.goto('/cw-test-host');
  const game=page.frameLocator('iframe').locator('cookie-wall');await game.locator('[part=start]').click();
  await game.evaluate(e=>{
    for(const [origin,source] of [['https://wrong.invalid',parent],[location.origin,window]]){
      window.dispatchEvent(new MessageEvent('message',{origin,source,data:{source:'punk-arcade',type:'pause'}}));
    }
  });
  await expect(game).toHaveJSProperty('state','playing');
  await page.evaluate(()=>document.querySelector('iframe').contentWindow.postMessage({source:'punk-arcade',type:'pause'},location.origin));
  await expect(game).toHaveJSProperty('state','paused');
  await page.evaluate(()=>document.querySelector('iframe').contentWindow.postMessage({source:'punk-arcade',type:'resume'},location.origin));
  await expect(game).toHaveJSProperty('state','playing');
});

test('downloadable playtest runs offline and keeps a best when storage is blocked', async ({page,context}) => {
  const {pathToFileURL} = await import('node:url'), {resolve} = await import('node:path');
  await context.setOffline(true);
  await page.addInitScript(()=>{
    Storage.prototype.setItem=()=>{throw new DOMException('Unavailable','SecurityError')};
    Storage.prototype.getItem=()=>{throw new DOMException('Unavailable','SecurityError')};
  });
  await page.goto(pathToFileURL(resolve('games/cookie-wall/dist/Cookie-Wall.html')).href);
  const game=page.locator('cookie-wall');
  await expect.poll(()=>game.evaluate(e=>e.game.presentation().id)).toBe('fony');
  await expect.poll(()=>game.evaluate(e=>Object.keys(e.game.presentation().frames).length)).toBe(35);
  await game.locator('[part=start]').click();
  await game.evaluate(e=>{
    const w=e.game.world;w.lives=1;w.score=42;w.phase='flight';Object.assign(w.packet,{x:20,y:323,vx:0,vy:200});
  });
  await expect(game).toHaveJSProperty('state','over');await expect(game).toHaveJSProperty('best',42);
  await game.evaluate(e=>{const parent=e.parentNode;e.remove();parent.append(e)});
  await expect(game).toHaveJSProperty('best',42);
});
