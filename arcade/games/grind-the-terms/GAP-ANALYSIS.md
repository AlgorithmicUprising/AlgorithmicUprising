# Grind the Terms — build guide gap analysis

Reviewed: Punk Arcade Game 01 (Nov 3 v0.1), Shared Kit & Embed Spec, the new Fony Art starter folder and the deployed code on `arcade`. The source guide remains authoritative for release acceptance; this report distinguishes **implemented** from **tested** and **outstanding**.

| Requirement | Before this pass | After this pass | Remaining verification / gap |
|---|---|---|---|
| Public game demo | Both greyboxes on one page | Unchanged, AU art now default for Grind | ZERO TV CH 05 still separate |
| Game code | One monolithic greybox | Authored chunk data and richer game state | Further split source into player/spawner/hazards modules |
| Fony art | Rectangle character | Cropped 39-frame AU sprite atlas (run, idle, land, ollie, double, bail, grind, railpop, flip), hazards, skyline, paper plate | Crop cleanup, precise 64×64 production sprite template, open-skin art |
| Asset loading | Skin files ignored | Async PNG/JPG loader, switchable `skin` attribute, procedural fallback, error events | Validator checks file existence but not frame completeness, anchors or contrast |
| Ollie | -500 / 1020 physics | Spec -620 / 1800; 100ms buffer, 80ms coyote | Tuning, playtest and hold-input gamepad |
| Grind | Narrow catch window | Descending catch with 12 px snap and hold-to-grind | More deterministic collision/animation regression cases |
| Grind pop | Inconsistent | Release-to-pop at -380 | Air control feel and combo transitions |
| Double jump | Missing | Optional after AIR BOOST pickup; generated sheet double animation | Power-up gameplay validation |
| Obstacles | Random accept/popup/rail/gap | Authored 4-tier chunks including modal, token and rail-gaps | Collision calibration against every tier's maximum speed |
| Difficulty | Random density | Seeded selection, first guaranteed safe rail, 4-tier speed/density | Five beginner runs averaging 30–90s |
| Scoring | Bonuses overwritten by distance | Distance, grind bonuses, combo multiplier, token rewards, near-misses | Exact guide values for all animations / combo resets |
| Game over | Generic message | Cause-specific lines, result statistics, local best | 0.4s bail verified in browser; complete sharing fallback |
| Layout | Basic 16:9, stretched art | Letterboxed 640×360 playfield | Real 9:16 portrait arrangement, CRT interaction, 320px testing |
| Accessibility | Basic keyboard / focus / pause | Keyboard/pointer, no flashes added, muted by default | Gamepad, full settings overlay, FlashGuard test, assistive text, reduced-motion effects |
| Audio | Toggle only / no generated SFX | No song audio committed | Sound toggle and procedural SFX remain to implement |
| Packaging | CI+Pages demo | Public AU skin and browser regressions | Standalone game demo and iframe, release tag, jsDelivr test, band approval |

## Important constraints

- Keep every game file inside `arcade/`; main branch and ZERO TV app remain unchanged.
- `skins/au/` contains protected Zero / AU graphic identity; `skins/fony/` is a separate open starter and cannot inherit these assets.
- Image cells came from a **composition sheet**, not frame-by-frame production character art; some crops need refinement. Do not claim finished M2 art polish.
- Double jump is a user-requested optional power-up extension, not the default single-button rule from the original v0.1 guide.
- No real brands, no backend, no tracking, no song masters.

## Next release gates

1. CI green with Chromium desktop/mobile tests including art and gameplay smoke, plus release bundle size.
2. Visual QA: actual player animation, rails catch/pop, multiple scores, broken skin fallback, HUD on phone.
3. Gameplay QA: 5 beginner 30–90s runs, every chunk clearable at its max speed, collision/hitbox fairness, balance.
4. Add gamepad, portrait controls, settings, Sound SFX, FlashGuard, complete share fallback.
5. Finish clean unbranded Fony skin, frame validation, standalone embed, polished visual/sprite review.
6. Band approval before merging `arcade` to `main` or publishing as a tagged v0.1 release; ZERO TV integration remains M3.
