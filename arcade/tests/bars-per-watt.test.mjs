import { test } from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';

async function sourceModule(path) {
  const result = await build({ entryPoints: [path], bundle: true, platform: 'node',
    format: 'esm', write: false, logLevel: 'silent' });
  return import('data:text/javascript;base64,' + Buffer.from(result.outputFiles[0].contents).toString('base64'));
}
const { compileChart } = await sourceModule('games/bars-per-watt/src/chart.ts');
const { RhythmSession } = await sourceModule('games/bars-per-watt/src/session.ts');
const { drawHighway } = await sourceModule('games/bars-per-watt/src/render.ts');
const source = {
  format: 'bars-per-watt-chart-v1', id: 'human-zoo-test', songId: 'AU-001',
  difficulty: 'easy', audioVersion: 'test-1', durationSec: 12, offsetSec: .1,
  bpms: [{beat:'0',bpm:120},{beat:'4',bpm:60}],
  notes: [{beat:'1/2',lane:0},{beat:'1',lane:1},{beat:'4',lane:2,endBeat:'6'},
    {beat:'4',lane:3}]
};

test('chart compiler maps rational beats and a BPM boundary to seconds', () => {
  const chart = compileChart(source);
  assert.deepEqual(chart.notes.map(n => [n.lane,n.time,n.endTime]), [
    [0,.35,undefined],[1,.6,undefined],[2,2.1,4.1],[3,2.1,undefined]
  ]);
  for (const invalid of [
    {...source,bpms:[{beat:'0',bpm:0}]},
    {...source,bpms:[{beat:'0',bpm:120},{beat:'4',bpm:60},{beat:'4',bpm:80}]},
    {...source,notes:[{beat:'0',lane:4}]},
    {...source,notes:[{beat:'3',lane:1,endBeat:'2'}]},
    {...source,notes:[{beat:'0',lane:0},{beat:'0',lane:0}]},
    {...source,notes:[{beat:'0',lane:0,endBeat:'5'},{beat:'2',lane:0}]}
  ]) assert.throws(() => compileChart(invalid));
});

test('the same timestamped input scores identically at 30, 60 and 120 Hz', () => {
  const chart = compileChart(source);
  const events = [{at:.35,lane:0,down:true},{at:.7,lane:1,down:true},
    {at:2.1,lane:2,down:true},{at:2.1,lane:3,down:true},{at:4.1,lane:2,down:false}];
  const replay = hz => {
    const session = new RhythmSession(chart);
    let next = 0;
    for (let frame = 0; frame <= 12 * hz; frame++) {
      const now = frame / hz;
      while (next < events.length && events[next].at <= now) {
        const e = events[next++]; session.input(e.lane,e.down,e.at);
      }
      session.advance(now);
    }
    return {score:session.score,totals:session.totals,maxCombo:session.maxCombo,
      accuracy:session.accuracy,complete:session.complete};
  };
  const expected = replay(30);
  assert.deepEqual(replay(60),expected); assert.deepEqual(replay(120),expected);
  assert.deepEqual(expected,{score:4000,totals:{perfect:3,good:0,ok:1,miss:0,holds:1},
    maxCombo:4,accuracy:88.89,complete:true});
});

test('an early release misses the hold; an empty tap never scores', () => {
  const chart = compileChart({...source,notes:[{beat:'4',lane:2,endBeat:'6'}]}),
    session = new RhythmSession(chart);
  session.input(2,true,2.1); session.input(2,false,2.4);
  session.input(0,true,7);
  assert.equal(session.score,1000);
  assert.equal(session.totals.miss,1);
  assert.equal(session.combo,0);
  session.finish(); session.finish();
  assert.equal(session.totals.miss,1);
});

test('a sustained note allows opposite-hand taps and scores its release exactly once', () => {
  const session = new RhythmSession(compileChart({...source, notes:[
    {beat:'4',lane:0,endBeat:'10'}, {beat:'6',lane:3}, {beat:'7',lane:2}
  ]}));
  session.input(0,true,2.1);
  session.advance(4.0);
  assert.equal(session.activeHolds.length,1);
  assert.equal(session.pressed.has(0),true);
  session.input(3,true,4.1); session.input(3,false,4.2);
  session.input(2,true,5.1); session.input(2,false,5.2);
  session.input(0,false,8.1); session.input(0,false,8.1);
  assert.equal(session.latest,'hold');
  assert.equal(session.activeHolds.length,0);
  assert.equal(session.pressed.size,0);
  assert.equal(session.score,3500);
  assert.equal(session.totals.holds,1);
  assert.equal(session.accuracy,100);
});

test('long hold heads stay on the receptor while tails approach at any scroll speed', () => {
  const session = new RhythmSession(compileChart({...source,notes:[
    {beat:'4',lane:0,endBeat:'10'}
  ]}));
  session.input(0,true,2.1);
  const capture = (at,speed) => {
    const heads=[],fills=[];
    const ctx = new Proxy({
      createLinearGradient:()=>({addColorStop(){}}),
      roundRect:(...args)=>heads.push(args),
      fillRect:(...args)=>fills.push(args)
    },{get:(target,key)=>target[key]??(()=>{}),set:(target,key,value)=>{target[key]=value;return true;}});
    drawHighway(ctx,360,600,session,at,{},0,false,true,speed);
    return {heads,fills};
  };
  for(const speed of [.75,1,1.75]) {
    const early=capture(3,speed),late=capture(7,speed),end=capture(8.1,speed);
    assert.equal(early.heads.length,1);
    assert.equal(late.heads[0][1]+late.heads[0][3]/2,504);
    assert.deepEqual(early.heads,late.heads);
    assert.ok(end.fills.some(([x,y,w,h])=>x===18&&y===501&&w===54&&h===6),
      'release cap must remain visible at the hit line');
  }
  assert.equal(session.score,1000,'drawing never changes judgement');
});

test('three inclusive timing tiers keep the outer 120 ms window at long timestamps', () => {
  for (const base of [1,250]) for (const sign of [-1,1]) {
    for (const [distance,kind,points] of [[.05,'perfect',1000],[.05001,'good',750],
      [.09,'good',750],[.09001,'ok',500],[.12,'ok',500],[.12001,null,0]]) {
      const session = new RhythmSession(compileChart({...source,durationSec:300,offsetSec:0,
        bpms:[{beat:'0',bpm:60}],notes:[{beat:String(base),lane:0}]}));
      session.input(0,true,base+sign*distance,base+.02);
      assert.equal(session.score,points,`${base} ${sign*distance}`);
      if(kind){assert.equal(session.latest,kind);assert.equal(Math.sign(session.latestFeedback.errorSec),sign);
        assert.equal(session.latestFeedback.at,base+.02,'calibration must not shorten the effect');}
      session.advance(base+.13);assert.equal(session.totals.miss,kind?0:1);
    }
  }
});
const precisionChart=()=>compileChart({...source,offsetSec:0,durationSec:60,
  bpms:[{beat:'0',bpm:60}],notes:Array.from({length:50},(_,i)=>({beat:String(i+1),lane:i%4}))});

test('precision starts at five, pulses at milestones, and resets independently of combo',()=>{
  const session=new RhythmSession(precisionChart());
  for(let i=1;i<=25;i++){
    session.input((i-1)%4,true,i);session.input((i-1)%4,false,i+.01);
    assert.equal(session.overclocked,i>=5);
    if([5,10,25].includes(i)){assert.equal(session.milestone.kind,'precision');assert.equal(session.milestone.count,i);}
  }
  session.input(1,true,26.08);
  assert.equal(session.latest,'good');assert.equal(session.combo,26);assert.equal(session.precision,0);
  assert.equal(session.overclocked,false);assert.equal(session.milestone,null);
  session.input(2,true,27);session.input(3,true,28.11);
  assert.equal(session.latest,'ok');assert.equal(session.combo,28);assert.equal(session.precision,0);
  session.advance(29.13);
  assert.equal(session.latest,'miss');assert.equal(session.combo,0);assert.equal(session.precision,0);
  assert.equal(session.maxPrecision,25);assert.equal(session.maxCombo,28);
});

test('combo milestones include good hits; hold completion never manufactures precision',()=>{
  const taps=new RhythmSession(precisionChart());
  for(let i=1;i<=10;i++)taps.input((i-1)%4,true,i+.08);
  assert.equal(taps.milestone.kind,'combo');assert.equal(taps.milestone.count,10);assert.equal(taps.precision,0);
  for(const releaseAt of [8,7,8.151]){
    const session=new RhythmSession(compileChart({...source,offsetSec:0,bpms:[{beat:'0',bpm:60}],notes:[
      ...Array.from({length:4},(_,i)=>({beat:String(i+1),lane:1})),{beat:'5',lane:0,endBeat:'8'}]}));
    for(let i=1;i<=4;i++)session.input(1,true,i);
    session.input(0,true,5);assert.equal(session.overclocked,true);
    session.input(0,false,releaseAt);session.input(0,false,releaseAt);
    assert.equal(session.precision,releaseAt===8?5:0);assert.equal(session.combo,releaseAt===8?5:0);
    assert.equal(session.totals.holds,releaseAt===8?1:0);assert.equal(session.totals.miss,releaseAt===8?0:1);
  }
});

test('chords retain independent lane cues; reduced motion renders static cues without sparks',()=>{
  const session=new RhythmSession(compileChart({...source,offsetSec:0,notes:[{beat:'2',lane:0},{beat:'2',lane:3}]}));
  session.input(0,true,1);session.input(3,true,1);
  assert.deepEqual(session.laneFeedback.map(hit=>hit?.kind||null),['perfect',null,null,'perfect']);
  const capture=(time,reducedMotion)=>{
    const rectangles=[],pixels=[];
    const ctx=new Proxy({createLinearGradient:()=>({addColorStop(){}}),strokeRect:(...args)=>rectangles.push(args),fillRect:(...args)=>pixels.push(args)},
      {get:(target,key)=>target[key]??(()=>{}),set:(target,key,value)=>{target[key]=value;return true;}});
    drawHighway(ctx,360,600,session,time,{},0,false,reducedMotion);
    return {rectangles,pixels:pixels.filter(([, , w,h])=>w===3&&h===3)};
  };
  const moving=capture(1.1,false),still=capture(1.1,true);
  assert.equal(moving.pixels.length,8);assert.equal(still.pixels.length,0);
  assert.deepEqual(still,capture(1.2,true),'reduced motion must not expand or fade');
  assert.equal(still.rectangles.length,6);assert.equal(capture(1.6,true).rectangles.length,4);
  assert.equal(session.score,2000,'rendering never affects the score');
});
