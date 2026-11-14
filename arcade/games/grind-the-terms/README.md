# Grind the Terms · Fony Sprock

> Nobody reads them. Skate them.

The side-scrolling runner for Punk Arcade's CH 05. The `arcade` branch uses the approved Fony atlas and punk-comic city art. Desktop uses a 16:9 playfield; mobile runs inside the Zero Game Thing tablet layout with independent touch controls.

## Current controls and rules

| Move | Desktop | Zero Game Thing tablet / touch | Gamepad |
| --- | --- | --- | --- |
| Steer on the ground or in the air | ← / → | Left-thumb rocker | D-pad or left stick |
| Ollie / hold to grind | ↑ / W / U | Hold U | A |
| Pop off a grind | Release ↑ / W / U | Release U | Release A |
| Trick | SPACE or A | A button | B |
| Spray boost | Hold R | Hold Ø | Hold X |
| Pause / resume | P / Esc or pause button | Pause / Resume buttons | — |

**Steering.** Hold either direction to shift Fony across the screen. Let go to keep that position. Street obstacles are laid out for a straight run, and the spray gauge still controls boost speed.

**Grind:** Press U / ↑ / W for one ollie. Hold it as Fony descends to catch a rail, obstacle top, or delivery-drone deck; release to pop. Both feet stay on the board while grinding.

**Boost gauge:** The three-segment spray gauge replaces the can counter. A full gauge equals three current cans: 11.25 seconds at 2× speed if no charge is earned while boosting. Hold R / Ø / X to drain it; release to pause the drain. Boost works during jumps, grinds, and tricks. Grinding adds 0.6% per second; successful tricks add 1.5–2.5% based on chain length. While boost is held, those gains are quarter-rate so the gauge still drains. A collected spray-can pickup adds one segment. When empty, release and press again after recharging; it will not restart by itself.

**Tricks and combo:** A successful jump starts a chain at x1. Each successful trick, grind attach, and controlled grind pop advances it once. The action's points use the new xN multiplier; simply passing a hazard does not increase the chain. A chain expires after 1.5 seconds without an action, stays alive during a grind, and banks/reset on landing on the sidewalk or bailing. The 80-clause trick token unlocks a second trick per airtime; it stays unlocked for the run. A successful delivery-drone grind and pop resets the used-trick count to the full unlocked allowance without breaking the combo. For example, after the upgrade: **Jump x1 → Trick x2 → Trick x3 → Grind x4 → Drone pop x5 → Trick x6 → Trick x7.** Stationary rails extend the chain but do not refresh tricks.

**Terms Runner:** Drones enter the street run after Fony clears a rail, ACCEPT, Consent, and a gap. The first courier passes high enough to skate underneath, with a coin trail on the sidewalk. Its lime deck is still a moving grind surface. A hit against the visible hull or parcel uses the usual bail and shield rules.

**Cookie Eye.** Stay on the sidewalk as the Eye approaches to bait a low scan. Ollie at the cue and steer onto the lime roof. An airborne approach can draw a high scan, and the Eye also adapts after two consecutive early dodges. Stay low through the high scan, then ollie, use a trick to get above the roof, and steer onto it on the descent. The Eye commits to its lane and position when the warning starts. Spray can jam its lens for 8% of a full gauge in addition to the normal boost drain. A hit from the scan breaks the combo and slows Fony for 1.15 seconds. Stomping a vulnerable roof disables the Eye, bounces Fony, and refreshes his unlocked tricks.

The standalone demo and portrait embed accept `?practice=drones` for a quick courier pass and repeatable Cookie Eye encounters. Practice starts with one spray segment and has its own local best score.

**Coins and upgrades:** Ground pickups can be collected by rolling through them. Other coins and powerups sit in jump arcs, and a few align with obstacle tops to reward deliberate platform landings. Coins add 10 points. The 80-clause trick token adds the second trick. Spray-can pickups add one gauge segment.

## Obstacles and scores

- **ACCEPT ALL obstacle:** A low, standalone button curb; no consent heading, checkbox form, or Terms copy. Its top is rideable/grindable, and a side impact causes a bail.
- **Consent barrier:** One 100-unit-high obstacle. It is separate from the low ACCEPT curb and has a rideable top.
- **Clause rails:** Two intentional practice rails.
- **Delivery drone:** A moving obstacle with a visible grind deck and a separate pickup coin. Its arrival is gated on clearing the four stationary obstacle families.
- **Fine-print gaps:** Jump the black pit (reward currently +8; balance candidate).
- **Opt Out / Air Boost:** +10 and one-hit protection. They are defensive tokens, not extra jumps.
- **Ordinary coins:** Sidewalk and airborne lines reward different routes through the hazards.

## Build and embed

From `arcade/`: `npm install && npm run check && npm run e2e`.

```html
<script type="module" src="./games/grind-the-terms/dist/grind-the-terms.js"></script>
<grind-the-terms skin="./games/grind-the-terms/skins/au/skin.json"></grind-the-terms>
```

`skin` is optional. Without it, the game renders accessible procedural placeholders. Invalid or inaccessible skin assets trigger `game:error` and fall back to placeholders; change the attribute to swap skins without editing gameplay. `game:skin-loaded`, `game:power`, `game:grind-start`, `game:grind-end`, `game:near-miss`, `game:over`, and `game:share` are emitted as DOM events.

**AU art is all rights reserved.** All skater and hazard frames in `skins/au/` are protected branded artwork. The open `skins/fony/` remains placeholder-only until clean, unbranded sprite art is available. Do not redistribute the AU skin under CC BY.

See `GAP-ANALYSIS.md` for the gap-by-gap status, release blockers, and next QA steps.

Sound effects are procedurally generated by Web Audio after a user gesture (disabled by default); enable with the Sound toggle or **M**. No prerecorded music is distributed.

## Archived development notes — superseded by current controls and art above

## Rail sprite contact calibration (v0.2.2)

The AU skin declares `rail.drawTopFromGround=39`, `rail.drawHeight=40`, and `rail.surfaceCellY=53` (out of `grid.hazards.cellH=112`). The rendered rail's skateboard contact line is at Y ≈ 279.93 in the 640×360 logical playfield. Grind catch, hold, sparks, and release-pop use the SAME calculated surface. Procedural placeholder rails draw their top at Y = 280 instead of the obsolete Y = 272. Physics is independent of Fony's sprite pose/trim box.

## Flat-topped obstacles (v0.2.3)

Fony can land on, skate across, and ollie from ACCEPT and Consent barrier boxes. **Hold** while landing for a grind; **release** to pop off. If the jump is released before landing, the box acts as a rideable platform and the next tap triggers a new ollie. Running into its side still causes a bail. The short Consent popup is a 144-unit platform introduced in tier 2 after the beginner practice rail. The physical contact edge is visibly highlighted on the art. That earlier note predates the v0.10 delivery drone and no longer describes the current route.

## v0.2.4: obstacle artwork grounded to the floor

Restored the original **ACCEPT ALL** sprite with no artificial floating lime coping line. The sprite's actual face is the grindable surface. Current active obstacle heights are 42 units for ACCEPT and 100 for Consent; both art layers anchor to the sidewalk floor and share their tops with collision geometry. Earlier source-atlas measurements in this log are historical; live geometry is controlled by the active skin. Rail artwork keeps its coping at source y=53 and leg tips at y=82 so its feet meet the sidewalk.

## November 3 — ZERO / ALGORITHMIC / UPRISING portrait arcade cabinet

Phones in portrait show a width-scaled 16:9 gameplay viewport ABOVE a separate retro punk control deck inside the Web Component. The large lightning-bolt **Ø** on the left is reserved (no special move yet). Smaller A and U buttons sit on the lower-right for the right thumb: **A toggles GO FASTER**, **U is jump/hold-to-grind/release-to-pop**. The new keyboard map is **SPACE toggles speed**; ↑/W/U jump. Desktop gamepad A still jumps. The deck must be included in the component's measured height, not overlap the instructions, art picker, or other page content. The mobile portrait game screen remains 16:9 for correct pixels, not stretched to 9:16.

Speed increases smoothly up to ~30% above normal over 0.45 s, returns over 0.35 s after toggling off. Grinds sustained for ~0.85 s grant a separate short 18% momentum bonus. This is an early tuning pass, not final balance. The speed state is displayed in the HUD and on the A button's pressed state.

Still required before release: trim leftover transparent edges on hazard sprites, assemble variable-length rails with true left/center/right caps and legs, tune beginner run length, check real iPhone/Android interactions, verify 320px phone widths and mobile WebKit. The Ø special is expressly future work and must not perform gameplay yet.

## November 3 final mobile playtest revision — Zero TV portrait tablet (v0.2.6)

The approved ZERO TV mobile frame is **1080×1920 with a transparent screen window 1008×1728**. The shared Arcade kit specifies a **360×640 (9:16) portrait world**. The arcade cabinet now uses a **9:16 overall host**, with a portrait-mode camera (450 logical units across, tracking Fony near the left side) in its upper 65% and the Ø/A/U control deck in its lower 35%. It no longer squashes a 640×360 landscape canvas into a short strip. The `layout="portrait"` host override fills an explicitly sized ZERO TV window; standalone/mobile uses 9:16 automatically. Desktop remains 640×360. The cabinet must fit inside CH05's screen opening, without scrollbars or overflow into the Zero TV frame.

**GO FASTER is +10% only** (ramped, on/off via SPACE / cabinet A); a long grind earns a separate brief **+7%**. These replace the prior +30%/+18% preview values. The real-game upper camera shows clear consent-versus-token guidance. Phone U uses pointer capture, explicit iOS long-touch default cancellation and shadow-root selection/context-menu prevention so holding U does not select instructions or interrupt a grind. Scope that behavior to the game only; users can still select the rest of the page.

**The Consent barrier is a hazard, not a pickup.** The active 100-unit punk-comic barrier is grounded, flat-topped, and skateable/grindable. The original yellow ACCEPT ALL sprite is intentionally unchanged. Descend from above onto the visible top to ride/grind, or avoid/jump over the form. A side impact bails without a shield. If a shield absorbs the hit, the form stays present (marked DENIED) and Fony bounces clear; it is not silently removed. Only floating circular tokens are collectible. Landing checks now sweep the crossing from the previous frame for fairer phone framerates.

**Accept:** zero scrolling/text-selection on a 1–2s held U; correct 9:16 full-cabinet ratio at 320px/390px, upper screen visibly portrait; no cropped buttons/sprites; same rules inside a CH05 iframe at the Zero TV tablet size; no translucent forms, no mystery disappearances; novice player can deliberately land on the flat top and exit with U release. Visual sign-off remains required on physical iOS/Android.

## Art direction v0.3 — Approved Punk Arcade mockup (Nov 3)

The November 3 generated game mockup is the visual target: magenta/night-sky data-center city, layered parchment **Terms & Conditions** clouds (smoke from server stacks), tagged concrete retaining wall, cracked sidewalk, lane-marked road, real manhole/loophole, acid-lime rail and real skate poses from the user's **Fony Sprock** art sheet. The actual game **does not display the mockup as a static image**. It composes the following independently scrolling AU-only background layers loaded from `skin.json`:

- `terms_clouds_far_v4.png`: legal-text torn paper cloud shapes, far parallax 0.045×.
- `terms_clouds_near_v4.png`: closer legal clouds, parallax 0.077×.
- `terms_datacenter_city_v4.png`: data centers, server windows, smoke stacks, antenna skyline, 0.16×.
- `terms_smoke_plumes_v4.png`: paper smoke from data-center ventilation chimneys, 0.16×.
- `terms_graffiti_wall_v4.png`: concrete legal-graffiti wall, 0.28×.
- `terms_sidewalk_road_v4.png`: grounded sidewalk slabs, curb, manholes and lane-marked street, 1×.
- `fony_punk_approved_v3.png`: 39 normalized, board-anchored animation cells (128×128) extracted from user-approved Nov 3 pink-mohawk Fony Sprock character sheet. Previous Fony prototype remains archived.

Hazard rendering is now procedural and clean: consent cards are opaque inked paper windows; ACCEPT ALL is a clean yellow/black grounded button; shield and air-boost pickups are independent centered coins; gaps are legible broken manholes. Rails are composed from exact-length colored left/right caps, an unbroken middle strip and support posts, so a 75/150/225/300px rail is never truncated. Collision world heights continue to match the drawn caps. Old dirty `terms_hazards_atlas.png` is retained for reference only, not rendered.

**Release notes:** Assets are in the protected `au` skin only; the open CC starter remains free of band art. The generated new scenic plates are faithful interpretation, not a literal crop of the approved game screenshot. Before final art sign-off, a human should compare the mockup, accepted pose sheet, parallax spacing, sidewalk lane depth and performance on the actual ZERO TV tablet.

## Visual review correction — illustrated V5 scenery (Nov 4)

The previous V4 render was rejected by human playtesting: oversized repetitive type bands, muddy low-detail backdrop, player blending into wall, and dark pause overlay. V5 replaces ALL active V4 scenic plates with five **independently parallaxed detailed ink-art crops** from the actual approved Punk Arcade game mockup. Two compact torn-paper/legal-text cloud layers now share frame with the magenta-lit data-center skyline, concrete graffiti wall and detailed cracked sidewalk/curb/asphalt. No collectible coins are baked into the wall; every coin remains a game object. The old V4 scenic assets remain archived but are no longer in `skin.json`. The pause veil was lightened from ~85% to ~58% black so the game art remains visible in the paused state. Actual physics/collisions and 9:16 portrait cabinet geometry were intentionally preserved.

Acceptance: screenshots must have readable Fony and foreground obstacles, distinct horizontal scenery bands, city not swallowed by type wallpaper, cloud edges genuinely torn, ground physically under wheels, and unobstructed pause text. Restore the previous good production preview if the visual acceptance is not better; green CI alone is not an art-approval gate.

## Nov 3 — Sharp Fony / Legal-smog / Ground-lock pass (v0.3.2)

**Fony:** Replace the old 128px-cell extracted atlas with the 39-pose **2× ink-enhanced, 256×256-cell** atlas `fony_punk_ink_hd_v6.png`. The original poses remain unchanged; this is a contrast/ink-edge refinement, **not** new hand-drawn replacement poses. Rendering uses `imageSmoothingEnabled=false` only around skater draw calls, with the bitmap drawn at its original 128×128 logical size from a 256×256 source and the board-contact anchor doubled (128,234), displayScale 0.5. The game preserves the gameplay hitbox, animation timing and board baseline. Artist-quality redraw of individual poses remains desirable.

**Paper-clouds:** Near and distant cloud strips have been rebuilt on the existing torn-paper silhouettes with substantially denser, properly oriented legal copy. Multiple compact headings include **TERMS & CONDITIONS**, plus much smaller clauses, checkboxes, and data-consent fragments. The largest heading is roughly 11–12 logical pixels at its normal game height, no larger than the pause RESUME label. Parallax ratios, city visibility and smoke staging are unchanged.

**Accept/sidewalk sync:** The physical road + sidewalk sprite now scrolls at the SAME factor `1.0×` as ACCEPT and other world obstacles, not the old `0.86×`. A real world-space debug fixture plus a browser regression test compare the actual road-image draw positions to an ACCEPT button's render text position frame by frame. Rails, buttons and collisions still share their original physics geometry.

The original v5 layers and v3 Fony atlas remain in the protected AU skin as archived revisions. Only the three new v6 assets are selected by `skin.json`.

### Fine-print size correction (v0.3.3)
Visual screenshot inspection found that the V6 cloud headings still appeared larger than the screenshot's RESUME control. V7 reduces cloud display headings again (native 13px letterforms on the near cloud, typically under 9 logical pixels at a 97/160 game-layer scale), retaining the dense tiny paragraphs and original torn contours. The previous v6 files remain archived; only V7 is loaded.


## November 4 — v0.4 paper-smog and skating revision

- The approved fine-print cloud treatment is now two independent SVG parallax layers (`terms_paper_smoke_cloud_far_v8.svg` / `terms_paper_smoke_cloud_near_v8.svg`), with scalloped cloud silhouettes, parchment paper stacks and tiny legal clauses. Both stay independent of the city, hazards and player. City-parallax smoke curves connect chimney positions to the foreground paper-cloud bank; final physical-phone art alignment remains to be signed off.
- Fony's regular ground movement now displays a stable, low crouched skateboard pose (approved atlas frame 10) with scrolling streaks instead of cycling through the sprite sheet's **running-on-foot** poses. Air / grind / bail poses retain their dedicated animations. The original source atlas is unchanged; a future full board-accurate redraw will still improve expression and continuity.
- Double ollie is **always on**: release and tap U again while airborne. An additional jump consumes the second jump for the current airtime; landing resets it. Existing AIR BOOST pickups are treated as defensive pickups so they cannot gate double jump.
- GO FASTER ramps to exactly **2× the current normal movement speed** (0.45 seconds), while sustained-grind momentum remains an independent +7% factor. Desktop SPACE and mobile A remain toggle controls. The mobile Ø/A/U deck styling and positions are unchanged.
- New Playwright coverage asserts 2× baseline, permanent airborne double-ollie, ground sprite selection and SVG cloud selection. These checks require CI execution and real-device visual verification before release sign-off.


## November 4 — v0.5 paper-cloud canopy and pace correction

User playtests rejected the previous V8 cloud strip and 180 px/s cruise speed. V9 replaces the actual cloud assets, not their labels: the two tiled SVG images each contain three organic scalloped cut-paper strata, soft mauve/cream shadows, and nearly microscopic clause text clipped to cloud silhouettes. No rectangular policy cards are drawn. The cloud art stays independent of the data-center city. Connected circular smoke wisps now share the city parallax factor and rise from the city stacks into the underside of the cloud canopy. Foreground wall parallax increased modestly to communicate motion. Previous V8 assets are archived, not active.

Ground speed starts at **260 logical px/s**, ramps gradually with time, and remains entirely separate from the optional **2× GO FASTER** toggle. U's default double jump and all original cabinet buttons remain unchanged. Normal ground movement now alternates two low crouch/recovery poses (not running poses) with an always-visible skateboard composited at the shared board anchor, visibly rotating wheel spokes and speed-dependent motion streaks. Source pose cleanup for a full professional 39-frame sheet remains unfinished.

Playwright assertions have been updated for the new relative speed, deterministic first rail, two safe roll cells, and new cloud file selection. Real-device visual approval and beginner balance remain required before a final release.


## November 4 — v0.5.1 FPS-performance correction

The user clarified **browser animation was stuttering**, not that world-speed was too low. Rolled back the attempted 260 px/s gameplay tuning to the earlier 180 px/s progression (still with the optional 2× speed toggle), restoring the safe beginner window. The source of jank was excessive repeated drawing of large scenic tiles plus text-heavy SVG cloud assets on every animation frame. Cloud SVGs are now lightweight procedural curved paper strata with a small repeating microprint pattern. The game rasterizes each cloud SVG **once when the skin loads** and draws that cached canvas each frame. Parallax draws only cropped visible camera regions, instead of multiple full 1280px background tiles. On touch devices, the Grind canvas resolution is limited to 1.5× DPR instead of 2×, reducing fill pixels while retaining crisp ink sprites. This change has separate regression coverage for visible-only rendering and updated source cropping. Performance still requires a real iPhone run before final acceptance.


## Nov 4 — V10 shaded paper cloudbank

Art revised against the user-supplied rounded paper-cut white cloud concept. Both cached 1280x190 SVG layers now have substantial body mass, irregular large lower lobes, cream-to-mauve shaded depth, local soft puffs, fine paper grain, and microprinted legal clauses clipped to cloud silhouettes. Portrait far/near placement overlaps by >100 world units to remove the previous empty gap. Smoke is attached to the city parallax and fades as it enters the near cloud; skip offscreen plumes for performance. No change to movement speed, controls, or Fony mechanics. Visual review and Pages success are pending CI.


## November 4 — v0.6.1 denser foreground cloud tuning

User approved the overall cloud silhouette, then requested slightly greater density and no visible top contour on the nearest/outermost layer. Front bank is raised and vertically expanded so the source y=36 top-lobe boundary sits entirely behind the opaque HUD (both portrait and landscape). Its cream/mauve fill stays fully opaque, inner puff layers are more solid, and faint fine-print texture is modestly stronger; the underlying skyline remains visible below the rounded lower edge. Far cloud opacity rises from .86 to .93. All cached rasterization/camera clipping, controls, speed, physics, and Fony frames are unchanged. A new browser regression asserts the top outline is concealed across viewport profiles.


## November 4 — v0.7: approved textured PNG replaces SVG cloud layers

The user approved the cream/mauve cut-paper PNG created from the existing background cloud style. The game now uses the actual approved artwork, resized and quantized to a lightweight 1024×253 indexed-alpha PNG (`terms_papercut_cloudbank_v12.png`), rather than the old translucent SVG strips. The asset includes its own three-dimensional paper-cut shadow layers. Legal microtext is stamped into the cloud raster once at load using `source-atop`, not drawn per frame. The cloud draws at full opacity, in one parallax plane, and the source-to-world scaling supports 1024-pixel assets in the existing 1280-unit tiler. On phones the nearest upper cloud contour is geometrically hidden behind the 98-unit opaque HUD; desktop contour is likewise hidden behind the 71-unit HUD. The lower scalloped cloud bank remains above the data-center skyline, with chimney smoke retained. Road, skater, controls, and speeds are unchanged.


## November 5 — v0.10 held boost, action combos, and delivery drones

The spray-can inventory is now a three-segment hold-to-boost gauge. Full capacity remains equal to three prior cans (11.25 seconds at 2× before recharge). Grind time and successful tricks refill it gradually; can pickups add one segment. Independent input sources let Ø stay held while U and A are used on the Zero Game Thing tablet.

Combos now advance on jumps, tricks, grind attaches, and controlled pops. Hazard passage can score against the active multiplier without incrementing it. A delivery drone carries a pass-through coin and a grindable deck. Its successful grind-pop resets the available tricks while preserving the combo. Drones stay locked until the run safely clears rails, ACCEPT, Consent, and a gap.

## November 5 — Separate ACCEPT and consent obstacles

ACCEPT ALL is a standalone 42-unit-high button curb introduced at tier 1. The single Consent barrier is 100 units tall and appears from tier 2 onward, including at the former high-tier Terms locations. No separate Terms obstacle remains. The two obstacle types keep distinct artwork, grounded collision tops, and rideable/grindable surfaces.
