import { test, expect } from '@playwright/test';
import { mkdir } from 'node:fs/promises';

const demo = '/games/bars-per-watt/demo/';
const chart = {
  format:'bars-per-watt-chart-v1', id:'human-zoo-playback-test', songId:'AU-001',
  difficulty:'easy', audioVersion:'browser-test', durationSec:4, offsetSec:0,
  bpms:[{beat:'0',bpm:120}],
  notes:[{beat:'1',lane:0},{beat:'2',lane:1},{beat:'3',lane:2,endBeat:'4'},
    {beat:'5',lane:3}]
};
function wav() {
  const rate = 8000, samples = rate * 4, buffer = Buffer.alloc(44 + samples * 2);
  buffer.write('RIFF',0);buffer.writeUInt32LE(buffer.length-8,4);buffer.write('WAVEfmt ',8);
  buffer.writeUInt32LE(16,16);buffer.writeUInt16LE(1,20);buffer.writeUInt16LE(1,22);
  buffer.writeUInt32LE(rate,24);buffer.writeUInt32LE(rate*2,28);
  buffer.writeUInt16LE(2,32);buffer.writeUInt16LE(16,34);
  buffer.write('data',36);buffer.writeUInt32LE(samples*2,40);
  for(let i=0;i<samples;i++)buffer.writeInt16LE(Math.round(Math.sin(i*2*Math.PI*220/rate)*600),44+i*2);
  return buffer;
}
async function boot(page,fixture=chart) {
  const audio = wav();
  await page.route('**/games/bars-per-watt/catalog.json', route => route.fulfill({
    contentType:'application/json',body:JSON.stringify({version:1,songs:[{
      id:'AU-001',title:'The Human Zoo',durationSec:4,explicit:true,rightsStatus:'cleared',
      audioVersion:'browser-test',audio:'./preview.wav',
      charts:{easy:'./preview-easy.json',medium:'./preview-easy.json',hard:'./preview-easy.json'}
    }]})
  }));
  await page.route('**/games/bars-per-watt/preview-easy.json', route =>
    route.fulfill({contentType:'application/json',body:JSON.stringify(fixture)}));
  await page.route('**/games/bars-per-watt/preview.wav', route =>
    route.fulfill({contentType:'audio/wav',body:audio}));
  await page.goto(demo);
  const game = page.locator('bars-per-watt');
  await expect(game.locator('[part=start]')).toBeVisible();
  await game.locator('[data-load]').click();
  await expect(game.locator('[part=start]')).toBeEnabled();
  return game;
}
const contained = (outer, inner) => inner.x >= outer.x-1 && inner.y >= outer.y-1 &&
  inner.x+inner.width <= outer.x+outer.width+1 && inner.y+inner.height <= outer.y+outer.height+1;

test('scroll speed persists independently of timing offsets and the song clock', async ({page}) => {
  let game=await boot(page);
  await game.locator('[part=settings]').click();
  const speed=game.locator('[data-scroll-speed]');
  await speed.focus();
  await page.keyboard.press('End');
  for(let i=0;i<5;i++)await page.keyboard.press('ArrowLeft');
  await expect(game.locator('[data-scroll-value]')).toHaveText('1.50×');
  await expect(game.locator('[data-input-offset]')).toHaveValue('0');
  await expect(game.locator('[data-visual-offset]')).toHaveValue('0');
  await game.locator('dialog button[type=submit]').click();
  await page.reload();
  game=page.locator('bars-per-watt');
  await game.locator('[part=settings]').click();
  await expect(game.locator('[data-scroll-speed]')).toHaveValue('1.5');
  await game.locator('dialog button[type=submit]').click();
  await game.locator('[data-load]').click();
  await expect(game.locator('[part=start]')).toBeEnabled();
  await game.locator('[part=start]').click();
  await expect(game).toHaveJSProperty('state','over',{timeout:10000});
  await expect(game.locator('[data-time]')).toHaveText('0:04');
});

test('Human Zoo catalog selection, native song clock, pause, resume and bill', async ({page}, info) => {
  const errors=[]; page.on('pageerror',error=>errors.push(error.message));
  const game=await boot(page);
  await mkdir('test-results/screenshots',{recursive:true});
  await game.screenshot({path:'test-results/screenshots/bars-title-'+info.project.name+'.png'});
  await game.locator('[part=start]').click();
  await expect(game).toHaveJSProperty('state','playing');
  await expect.poll(()=>game.locator('[data-time]').textContent()).not.toBe('0:00');
  await game.locator('[part=pause]').click();
  await expect(game).toHaveJSProperty('state','paused');
  const stopped=await game.locator('[data-progress]').evaluate(e=>e.value);
  await page.waitForTimeout(250);
  expect(await game.locator('[data-progress]').evaluate(e=>e.value)).toBeCloseTo(stopped,2);
  await game.locator('[part=resume]').click();
  await expect(game).toHaveJSProperty('state','playing');
  await expect(game).toHaveJSProperty('state','over',{timeout:12000});
  await expect(game.locator('.bill')).toBeVisible();
  await expect(game.locator('.bill')).toContainText('FICTIONAL POINTS. NOT MONEY.');
  const card=await game.locator('.card').boundingBox(), bill=await game.locator('.bill').boundingBox();
  expect(contained(card,bill)).toBe(true);
  expect(errors).toEqual([]);
  await game.screenshot({path:'test-results/screenshots/bars-bill-'+info.project.name+'.png'});
});

test('desktop and phone controls fit; host pause and eject stop the game', async ({page}, info) => {
  const phone=info.project.name.startsWith('mobile');
  if(phone)await page.setViewportSize({width:320,height:740});
  const game=await boot(page);
  const host=await game.boundingBox(), screen=await game.locator('.screen').boundingBox();
  expect(contained(host,screen)).toBe(true);
  await expect(game).toHaveAttribute('data-orientation',phone?'portrait':'landscape');
  if(phone){
    for(const name of ['left','down','up','right']){
      const pad=game.locator('[data-lane='+name+']'), box=await pad.boundingBox();
      expect(box.width).toBeGreaterThanOrEqual(48);
      expect(box.height).toBeGreaterThanOrEqual(48);
      expect(contained(host,box)).toBe(true);
    }
  }
  for(const button of await game.locator('.top button').all())expect(contained(host,await button.boundingBox())).toBe(true);
  await game.locator('[part=start]').click();
  if(phone)await game.locator('[data-lane=left]').tap();
  else await page.keyboard.press('d');
  await game.evaluate(el=>el.pause('host'));
  await expect(game).toHaveJSProperty('state','paused');
  await game.evaluate(el=>el.remove());
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('a missing licensed catalog leaves a readable, unplayable placeholder', async ({page}) => {
  await page.goto(demo);
  const game=page.locator('bars-per-watt');
  await expect(game.locator('[data-loading]')).toContainText('reviewed chart and playback copy');
  await expect(game.locator('[part=start]')).toBeDisabled();
  await expect(game.locator('canvas')).toBeVisible();
});

test('a song with pending rights never requests its media', async ({page}) => {
  let mediaRequested=false;
  page.on('request',request=>{if(request.url().endsWith('/pending.wav'))mediaRequested=true;});
  await page.route('**/games/bars-per-watt/catalog.json',route=>route.fulfill({
    contentType:'application/json',body:JSON.stringify({version:1,songs:[{
      id:'AU-001',title:'The Human Zoo',durationSec:4,explicit:true,
      rightsStatus:'pending',audioVersion:'test-1',audio:'./pending.wav',
      charts:{easy:'./pending.json'}
    }]})
  }));
  await page.goto(demo);
  const game=page.locator('bars-per-watt');
  await game.locator('[data-load]').click();
  await expect(game.locator('[data-loading]')).toContainText('cleared rights');
  await expect(game.locator('[part=start]')).toBeDisabled();
  expect(mediaRequested).toBe(false);
});

test('owner-only same-origin catalog, chart and audio use the signed-in session', async ({page}, info) => {
  test.skip(info.project.name === 'mobile-webkit',
    'The WebKit loopback cookie fixture is not sent in CI; validate the private HTTPS Site on a device.');
  // Set a first-party session on the page before it requests protected assets.
  await page.goto(demo);
  await page.evaluate(() => { document.cookie = 'playtest_auth=owner; SameSite=Lax; Path=/'; });
  expect(await page.evaluate(() => document.cookie)).toContain('playtest_auth=owner');
  const authorized = route => (route.request().headers().cookie || '').includes('playtest_auth=owner');
  let mediaAuthorized = false;
  await page.route('**/games/bars-per-watt/catalog.json', route => route.fulfill(authorized(route) ? {
    contentType:'application/json',body:JSON.stringify({version:1,songs:[{
      id:'AU-001',title:'The Human Zoo',durationSec:4,explicit:true,rightsStatus:'cleared',
      audioVersion:'browser-test',audio:'./preview.wav',charts:{easy:'./preview-easy.json'}
    }]})
  } : {status:403,body:'Sign in required'}));
  await page.route('**/games/bars-per-watt/preview-easy.json', route => route.fulfill(authorized(route) ? {
    contentType:'application/json',body:JSON.stringify(chart)
  } : {status:403,body:'Sign in required'}));
  await page.route('**/games/bars-per-watt/preview.wav', route => {
    mediaAuthorized = authorized(route);
    return route.fulfill(mediaAuthorized ? {contentType:'audio/wav',body:wav()} :
      {status:403,body:'Sign in required'});
  });
  await page.reload();
  const game=page.locator('bars-per-watt');
  await game.locator('[data-load]').click();
  await expect(game.locator('[data-loading]')).toContainText('Ready. Enable sound');
  await expect(game.locator('[part=start]')).toBeEnabled();
  expect(mediaAuthorized).toBe(true);
});

test('five perfect heads show OVERCLOCKED, a miss clears it, and reduced motion stays static',async({page})=>{
  await page.emulateMedia({reducedMotion:'reduce'});
  await page.addInitScript(()=>{
    const NativeAudio=window.Audio;
    window.Audio=function(...args){const audio=new NativeAudio(...args);window.__rhythmTestAudio=audio;return audio;};
    window.Audio.prototype=NativeAudio.prototype;
  });
  const fixture={...chart,notes:[.4,.7,1,1.3,1.6,3].map((at,i)=>({beat:String(at*2),lane:i%4}))};
  const game=await boot(page,fixture);
  await game.evaluate(el=>{
    const targets=[.4,.7,1,1.3,1.6],actions=['left','down','up','right'];
    el.addEventListener('game:start',()=>{
      let next=0;
      const step=()=>{
        const at=window.__rhythmTestAudio.currentTime;
        if(at>=targets[next]-.02){
          // Exercise timestamped shared input against the native audio clock.
          // Unit replay tests cover exact grade boundaries independently.
          const stamp=performance.now()-(at-targets[next])*1000;
          el.action(actions[next%4],'keyboard:fixture',true,stamp);
          el.action(actions[next%4],'keyboard:fixture',false,stamp);next++;
        }
        if(next<targets.length)setTimeout(step,8);
      };setTimeout(step,8);
    },{once:true});
  });
  await game.locator('[part=start]').click();
  await expect(game.locator('[data-precision]')).toHaveText('OVERCLOCKED! ×5');
  await expect(game.locator('[data-hit]')).toHaveText('ROOT ACCESS');
  await expect(game.locator('[data-combo]')).toHaveText('5');
  await expect(game.locator('.screen')).toHaveClass(/is-overclocked/);
  expect(await game.locator('[data-precision]').evaluate(el=>el.getAnimations().length)).toBe(0);
  const screen=await game.locator('.screen').boundingBox(),feedback=await game.locator('.feedback-strip').boundingBox();
  expect(contained(screen,feedback)).toBe(true);
  await expect(game.locator('[data-combo]')).toHaveText('0',{timeout:5000});
  await expect(game.locator('[data-precision]')).toHaveText('PRECISION 0/5');
  await expect(game.locator('.screen')).not.toHaveClass(/is-overclocked/);
  await expect(game).toHaveJSProperty('state','over');
  await expect(game.locator('[data-bill-precision]')).toHaveText('5');
  await expect(game.locator('[data-bill-hits]')).toHaveText('5 / 0 / 0');
  expect(await page.evaluate(()=>Object.keys(localStorage).some(key=>key.includes('best:timing-v2:')))).toBe(true);
});
