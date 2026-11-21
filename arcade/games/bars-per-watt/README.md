# Bars per Watt · Power Rack

Game 04 is a four-lane rhythm cartridge for the shared Punk Arcade engine. The public catalog pins each playable track to a versioned playback copy and its reviewed Easy, Medium and Hard charts.

## Run and embed

From `arcade/`, run `npm ci`, `npm run stage-pages`, then `node tools/serve.mjs --staged`. Open `/games/bars-per-watt/demo/` for the standalone page or `/games/bars-per-watt/demo/embed.html` in a first-party iframe. The gallery at `/demo/` also has its cartridge. `orientation="portrait"` or `"landscape"` forces a layout; otherwise the shared engine fits the actual host. Both layouts use the same four-lane timing and score.

| Action | Desktop | Mobile | Gamepad |
| --- | --- | --- | --- |
| Hit lanes | Left/Down/Up/Right or D/F/J/K | Four on-screen pads, including simultaneous taps and holds | Face buttons 0–3, D-pad or left stick |
| Start | Space or Play Song | Play Song | Button 8 |
| Pause / resume | Esc, P or button | Visible Pause / Resume | Button 9 |
| Sound | M or button | Sound button | Sound button |

Active holds stay attached to the receptor, with a visible end cap and an explicit release cue. Release when the cap reaches the line; a completed hold has separate visual feedback. Settings include persisted 0.75–1.75× scroll speed, which changes note spacing without changing playback rate, note timestamps or scoring. Note heads are height-limited to keep shorter subdivisions readable in portrait. The shared timing and judgement code is the same on desktop and mobile.

The audio element's position controls note animation and scoring. The render loop never advances musical time. A full decoded 5:18.8 stereo 48 kHz float buffer would take roughly 122 MiB before other game memory, above the guide's proposed 96 MiB buffer cap; this first pass uses one native stream. Focus loss, tab hide, offscreen host, parent pause and ejection pause or dispose the stream. Sound starts muted. Settings persist local visual and input offsets (±150 ms), contrast and reduced motion. The result is a fictional points bill, with score-version/song/chart/difficulty/input-mode best scores. The iframe forwards existing `game:*` events to the exact parent origin and accepts `pause`, `resume`, `mute` and `unmute` commands from that parent. The website still needs a receiving bridge and mini-player handoff before activating the live cartridge.

A catalog entry can include a same-origin `backgroundVideo` path to a short silent loop. The desktop cabinet requests it when the song starts and pauses it with the audio. The sleeve is shown on touch layouts, in reduced-motion mode, when Background Video is off, and if a clip cannot play.

## Timing feedback · 0.3.0-preview

The strike line and receptors sit at 84% of highway height. Timing labels and the precision badge occupy the gutter below the targets, outside the incoming note path.

| Grade | Absolute timing error | Points | Feedback |
| --- | --- | --- | --- |
| ROOT ACCESS (perfect) | ≤50 ms | 1000 | Expanding square and four pixel sparks |
| IN SYNC (good) | >50–90 ms | 750 | Small outline pulse, EARLY/LATE |
| BIT ROUGH (OK) | >90–120 ms | 500 | Brackets, EARLY/LATE |
| DESYNC (miss) | Outside ±120 ms or failed hold | 0 | Outlined X; both streaks reset |

All successful heads increase combo. Five consecutive perfect heads activate **OVERCLOCKED!**; Good/OK keeps combo but resets precision. A successful hold release adds 500 points and a check cue without increasing either streak. Dropped or overdue holds reset both. Combo and precision milestones at 10, 25, 50 and subsequent multiples of 50 pulse their counter. The rack meter tracks combo and lights fully while overclocked. Each chord lane retains its own cue. Effects last 240 ms; the readable grade stays for 550 ms. Reduced motion uses static shapes and labels, with no particles or scaling. No screen shake or full-screen flash is used.

The new scoring rules use the `timing-v2` best-score namespace; previous two-grade scores do not compete with these scores. Settings and chart/audio versions are unchanged. Results include all three hit totals, misses, max combo and best precision.

## Publish cleared audio and charts

The source of truth for public Bars Per Watt playback files and reviewed chart JSON is arcade/r2-assets/. Paths beneath that folder mirror the object keys in the bars-per-watt-media R2 bucket. The current Human Zoo Arcade Edit is versioned as human-zoo-arcade-edit-v1-827727bd.

For another track, add one approved playback copy and three reviewed chart files under bars-per-watt/<songId>/<audioVersion>/: audio.m4a, easy.json, medium.json and hard.json. Add matching URLs and audioVersion to the Bars Per Watt catalog. The workflow checks rightsStatus, object paths, chart song ID, difficulty, duration and audioVersion before upload.

A pull request runs the source/catalog check without Cloudflare credentials. After a pull request that changes this catalog or its R2 sources is merged into main, the main deployment confirms that the commit belongs to a merged PR targeting main, uploads and verifies the referenced R2 objects, then continues to the GitHub Pages publish. Direct pushes that change the catalog or R2 sources fail this deployment gate. Source media is not copied into the Pages artifact.

Before merging, configure the CLOUDFLARE_ACCOUNT_ID repository variable and the R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY GitHub secrets. Use an R2 S3 credential scoped to the bars-per-watt-media bucket. Keep private masters and unreleased exports out of arcade/r2-assets/.

Each normalized chart uses format bars-per-watt-chart-v1 and includes songId, difficulty, audioVersion, durationSec, offsetSec, bpms and notes. Beats are decimal or rational strings; lane values are 0–3; holds include endBeat.
