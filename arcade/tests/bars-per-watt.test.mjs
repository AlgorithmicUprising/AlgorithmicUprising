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
