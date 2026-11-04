# Grind the Terms — build guide gap analysis

Reviewed: Punk Arcade Game 01 (Nov 3 v0.1), Shared Kit & Embed Spec, the new Fony Art starter folder and the deployed code on `arcade`. The source guide remains authoritative for release acceptance; this report distinguishes **implemented** from **tested** and **outstanding**.

| Requirement | Before this pass | After this pass | Remaining verification / gap |
|---|---|---|---|
| Public game demo | Both greyboxes on one page | Unchanged, AU art now default for Grind | ZERO TV CH 05 still separate |
| Game code | One monolithic greybox | Authored chunk data and richer game state | Further split source into player/spawner/hazards modules |
| Fony art | Rectangle character | Cropped 39-frame AU sprite atlas (run, idle, land, ollie, double, bail, grind, railpop, flip), hazards, cleaned skyline crop, paper plate | Crop cleanup, precise 64×64 production sprite template, open-skin art |
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
| Accessibility | Basic keyboard / focus / pause | Keyboard/pointer plus standard gamepad A input; no flashes added, muted by default | Full settings overlay, FlashGuard test, assistive text, reduced-motion effects |
| Audio | Toggle only / no generated SFX | Muted-by-default procedural Web Audio SFX for grind/power/bail events, sound toggle persistence; no song audio | Safari/Android sound acceptance, richer art-driven SFX and user volume setting |
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
4. Polish gamepad and portrait controls, settings, FlashGuard, full sound acceptance and share fallback.
5. Finish clean unbranded Fony skin, frame validation, standalone embed, polished visual/sprite review.
6. Band approval before merging `arcade` to `main` or publishing as a tagged v0.1 release; ZERO TV integration remains M3.

## Playtest request: flat-top skating, November 3

Implemented rideable/grindable ACCEPT, POPUP and MODAL boxes, with consistent foot/board contact, pop-off and an easier wide first box. The intro now teaches the new mechanic before later hazards. Vertical reward routes and airborne drones remain future work pending art and balance tests.

## November 3 — portrait controls change order and speed

Keyboard SPACE now toggles GO FASTER; ↑/W/U jump. Portrait mobile U jumps and holds/release grind; A toggles speed; large left lightning-Ø is reserved for future special. The new portrait cabinet must occupy layout height beneath a width-scaled 16:9 game screen; never overlap the art selectors or next page section. Speed ramps up/down smoothly and extended grinds award short momentum. Pending: hazard sprite transparency trim cleanup; long capped rail segments; phone interaction acceptance and balance testing.

## Zero TV tablet layout / consent form feedback (Nov 3)

- [x] Changed speed toggle from +30% to +10%; long-grind bonus from +18% to +7%.
- [x] Replaced short 16:9 landscape mobile screen with 9:16 overall tablet cabinet, portrait camera in top 65% and Ø/A/U deck below. Target: approved ZTV mobile screen art 1008×1728 and shared 360×640 portrait requirement.
- [x] Disabled iOS selection/context callout during held U within the game, without affecting document text outside it.
- [x] Pink consent forms use opaque, grounded rendered panels, clearly distinct from floating collectible tokens; original yellow ACCEPT stays. Shield impacts keep form visible with DENIED mark. Increased landing tolerance for low-framerate descent.
- [ ] Compare the prototype in the *actual* live CH05 Zero TV tablet rather than only the standalone test page; include embedded/resized host acceptance.
- [ ] Clean remaining sprite trim artifacts and build seamless multi-length rails with end caps and legs.
- [ ] Human visual and gameplay sign-off on actual iPhone and Android, novice difficulty and accessibility.

## Nov 3 approved visual rebuild — implemented preview, human acceptance pending

- [x] New Fony atlas from attached hot-pink hair/goggle character sheet (39 normalized poses); no use of the previous Fony/Zero graphic for gameplay.
- [x] Fully distinct scrolling backgrounds: torn parchment terms clouds in two depths, three branded data centers with smoke, neon city, graffiti wall, sidewalk, curbed road.
- [x] Sidewalk and lane-marked street take the place of a thin dark ground line; manhole/loophole now has a clear circular hole, moved cover and warning label.
- [x] Hazard atlas is not sampled at runtime: dynamic rails have clean end caps/legs at arbitrary width; original ACCEPT styling recreated without stray transparent edging; coins/shield/boost are clean vector tokens; consent panels are opaque.
- [x] Desktop 640×360 and mobile portrait camera share collision geometry and layered parallax.
- [ ] Artist to inspect pose silhouettes manually at 1× and 2× for any residual detached component from the original raster sheet (automatic extraction is not perfect).
- [ ] Physical iPhone and Zero TV CH05 tablet playtest, clouds/data-center smoke visual consistency, token pickup collision acceptance, and beginner difficulty/balance.

## Nov 4 — rejected V4 artwork and corrective V5

- [x] Replaced low-detail flat V4 backgrounds with detailed user-approved mockup-derived scenic layers (far/near paper clouds, data-center city, graffiti wall, street). No static gameplay screenshot compositing and no baked collectible coins.
- [x] Reduced cloud height and visual dominance; skyline remains visible. Reduced pause veil opacity for visual QA.
- [x] Preserved all functional progress: clean cap rails, grounded consent forms/ACCEPT, visible manhole holes and token art, 10% speed toggle, mobile U long-press suppression, portrait cabinet.
- [ ] Actual physical-device art acceptance and balance tuning. No production ZERO TV deployment.
