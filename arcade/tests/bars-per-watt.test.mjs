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
  assert.deepEqual(expected,{score:4000,totals:{perfect:3,good:1,miss:0,holds:1},
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
    assert.equal(late.heads[0][1]+late.heads[0][3]/2,480);
    assert.deepEqual(early.heads,late.heads);
    assert.ok(end.fills.some(([x,y,w,h])=>x===18&&y===477&&w===54&&h===6),
      'release cap must remain visible at the hit line');
  }
  assert.equal(session.score,1000,'drawing never changes judgement');
});
