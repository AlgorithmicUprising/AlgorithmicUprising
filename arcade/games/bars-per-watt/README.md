# Bars per Watt · The Human Zoo

Game 04 is a four-lane rhythm cartridge for the shared Punk Arcade engine. Its first catalog entry is Algorithmic Uprising's **The Human Zoo** (`AU-001`). The master in Drive's `Zero - Audio Masters` is 48 kHz stereo PCM, about 5:18.8, SHA-256 `54dcf056e2e5073b12a7fb38809a99ecba5c77ca72bd3111860e81ab806ee18c`. It remains outside this repository.

This branch is a timing and integration vertical slice. The published catalog contains metadata only, so the title screen deliberately cannot start a run yet. The guide requires three reviewed **human-authored** charts and a separately hosted, cleared compressed playback copy. No automatic chart is generated from the master. Synthetic notes and audio live only inside tests. A private 160 kb/s AAC playback encode was measured at 5:18.8 and 6,613,040 bytes, SHA-256 `05f6a0c87d52404ff82eb63d54052d88d824d721f5624640384a59f57d9fdf58`; it has not been published.

## Run and embed

From `arcade/`, run `npm ci`, `npm run stage-pages`, then `node tools/serve.mjs --staged`. Open `/games/bars-per-watt/demo/` for the standalone page or `/games/bars-per-watt/demo/embed.html` in a first-party iframe. The gallery at `/demo/` also has its cartridge. `orientation="portrait"` or `"landscape"` forces a layout; otherwise the shared engine fits the actual host. Both layouts use the same four-lane timing and score.

| Action | Desktop | Mobile | Gamepad |
| --- | --- | --- | --- |
| Hit lanes | Left/Down/Up/Right or D/F/J/K | Four on-screen pads, including simultaneous taps and holds | Face buttons 0–3, D-pad or left stick |
| Start | Space or Play Song | Play Song | Button 8 |
| Pause / resume | Esc, P or button | Visible Pause / Resume | Button 9 |
| Sound | M or button | Sound button | Sound button |

The audio element's position controls note animation and scoring. The render loop never advances musical time. A full decoded 5:18.8 stereo 48 kHz float buffer would take roughly 122 MiB before other game memory, above the guide's proposed 96 MiB buffer cap; this first pass uses one native stream. Focus loss, tab hide, offscreen host, parent pause and ejection pause or dispose the stream. Sound starts muted. Settings persist local visual and input offsets (±150 ms), contrast and reduced motion. The result is a fictional points bill, with per-song/chart/difficulty/input-mode best scores. The iframe forwards existing `game:*` events to the exact parent origin and accepts `pause`, `resume`, `mute` and `unmute` commands from that parent. The website still needs a receiving bridge and mini-player handoff before activating the live cartridge.

## Add the reviewed song media and charts

1. Confirm recording/cover rights and identify a private immutable master version. Encode one web playback copy from the master outside Git, inspect duration and encoder padding, and verify HTTPS, CORS, MIME, range/seek and cache behavior on first-party storage. Do not put a master or compressed song in `arcade/` or a GitHub release.
2. A person measures BPM and offset against that exact playback copy, authors Easy/Medium/Hard charts in a reviewed editor, and playtests each on keyboard, pad and touch. Record separate chart rights. The normalized JSON below describes one chart; the example has **no notes** and is a format example, not a playable chart.
3. Publish immutable chart JSON beside the playback catalog on first-party storage. Set `audioVersion`, `audio` and each difficulty path in the separate catalog. Each chart's `audioVersion` and `durationSec` must match the catalog and actual playback copy. Runtime validation rejects mismatches, missing charts, unsupported timing, duplicate/overlapping notes and cross-origin media paths.
4. Point the component at that catalog with `<bars-per-watt catalog="https://algorithmicuprising.com/arcade-media/catalog.json"></bars-per-watt>`. The Pages demo and embed accept a percent-encoded `catalog` query value for the same first-party catalog; local HTTP is allowed only on localhost. Add another first-party storage origin to the explicit allowlist in `src/catalog.ts` if hosting moves. Media and chart files remain on the catalog origin.

```json
{
  "format": "bars-per-watt-chart-v1",
  "id": "human-zoo-easy-v1",
  "songId": "AU-001",
  "difficulty": "easy",
  "audioVersion": "human-zoo-playback-v1-05f6a0c8",
  "durationSec": 318.8,
  "offsetSec": 0,
  "bpms": [{ "beat": "0", "bpm": 120 }],
  "notes": []
}
```

Beats are nonnegative decimal strings (at most six decimal places) or rational strings such as `"7/4"`; BPM segments start at beat zero and increase. A note uses `{ "beat": "7/4", "lane": 0 }`, with lanes 0–3 for left/down/up/right. A hold adds `"endBeat"`; two entries on the same beat in different lanes form a chord. The example BPM/offset above are placeholders and must be replaced by human-verified values. The full guide's restricted `.sm`/`.ssc` importer and video transport are later milestones; this first pass consumes normalized JSON only.

Run `npm run check`, `npm test`, `npm run stage-pages` and `npm run e2e`. Browser tests use a synthetic four-second WAV and chart, never the song. Timing tests replay identical input at 30/60/120 Hz. Physical device audio latency, layout and memory/performance acceptance are still needed before live-site handoff.
