# AU Art Pack — Fony Sprock

**All rights reserved** — Algorithmic Uprising / Zero × Humans branded artwork.

Source art: latest approved generated sheet `Grind the Terms: Punk Sprite Sheet.png` (ChatGPT conversation library), extracted/quantized into sprite cells; original Fony character appearance and color notes live in the Google Drive Punk Arcade / Game 01 art folder. These cropped sprites are preview-quality, not individually hand-cleaned finals.

`fony_sprock_atlas.png`: 8-column grid, each frame 80 × 94 px. Row-major frame order: run 0–5, idle 6–9, land 10–11, ollie 12–16, double 17–20, bail 21–26, grind 27–30, railpop 31–34, flip 35–38. Some cells include residual outline artifacts from the composite art sheet; keep source for manual cleanup.

`terms_hazards_atlas.png`: 4 × 2 grid, cells 144 × 112. Top row: accept, Consent form, retired Terms panel, gap; bottom row: token, boost, shield, rail. Decorative plate images: `terms_far_plate.jpg` and `terms_skyline_v2.jpg`.

**Open skin isolation:** This AU skin uses protected Ø / ZERO × HUMANS marks. Neither these assets nor their branded derivatives are CC BY 4.0. The `fony/` starter remains procedural and freely replaceable; do not copy the AU image assets into it.

## November 3 animation alignment repair

Replaced the source composite's flawed 80 × 94 crops with **39 individually isolated 128 × 128 cells** from the approved original sheet. Every pose is bottom-centered against one board/foot anchor at `(64, 117)`; frame art stays within transparent padding, and the renderer draws from that anchor instead of a moving upper-left crop. The death/bail animation is finite (6 frames) and anchored to the impact ground position. The original atlas remains archived but is no longer loaded. Source bounding boxes and normalized frame metadata are in `fony_sprite_anchors.json` (matching copy in the Drive Fony art folder). One source ollie pose was repeated as its fifth animation frame because the composite has four unique ollie illustrations. Further manual cleanup of character details is still possible.

## New approved visual treatment (Nov 3)

The user supplied the alternate Fony Sprock pink-mohawk, goggles and skateboard pose sheet and approved the newly generated Terms/data-center city mockup. `fony_punk_approved_v3.png` is a cleaned 39-pose normalization from that sheet (same 8-column×128px grid and board/foot anchor). Per-frame source rectangles remain in the Game 01 Drive art folder. `terms_clouds_far_v4.png`, `terms_clouds_near_v4.png`, `terms_datacenter_city_v4.png`, `terms_smoke_plumes_v4.png`, `terms_graffiti_wall_v4.png` and `terms_sidewalk_road_v4.png` are hand-composed independent parallax layers derived from the mockup's stylistic direction, not a frozen screenshot of its player, hazards or controls. The earlier hazard atlas is archived for provenance but **not used by the game renderer**; all obstacle surfaces now have clean vector geometry. This all remains **AU protected artwork**; do not relicense it as CC BY 4.0.


## Approved gameplay art pack — Nov 5

The active AU skin now uses the approved Fony and punk-comic pack saved in the Punk Arcade / Grind the Terms art-approval folder. The uploaded WebP/JPEG files are optimized game-ready derivatives; the full-resolution approved source sheets remain in the shared Drive folder.

- `fony_gameplay_atlas_v1.webp`: 8 columns × 5 rows, 128 × 128 cells. Cells 0–5 are the six-frame board-run cycle; cells 6–38 preserve the engine's idle, land, ollie, double-jump, bail, grind, rail-pop and flip indices. Fony's board is included in the new grounded poses, so the runtime no longer paints a second board over it.
- `terms_papercut_cloudbank_v13.webp` and `terms_far_clouds_v1.webp`: near/far paper-cloud parallax layers.
- `terms_datacenter_city_v6.webp`, `terms_graffiti_wall_v6.webp` and `terms_sidewalk_road_v6.webp`: separate city, wall and street layers. The generated street's fixed manhole/cover was removed before use; the game continues to place its code-driven loophole at the collision location.
- `terms_accept_button_v2.webp`, `terms_consent_barrier_v3.webp` and `terms_opt_out_token_v1.webp`: active gameplay art. The obsolete Terms-window artwork has been removed; the Consent barrier is now the only consent-form obstacle.
- `terms_title_card_v1.jpg` and `terms_game_over_card_v1.jpg`: skin-specific desktop/mobile title and game-over backgrounds.
- `terms_mobile_control_deck_v1.jpg`: the existing 9:16 mobile control area only. It skins the game controls inside the established tablet layout; it does not replace the ZERO GAME THING outer frame.

The skin is all rights reserved. Keep it under `skins/au/`; do not copy these assets into the open `fony/` starter or label them CC BY 4.0. The generated action sheet supplies the visible poses; screen-size, actual iPhone/Android and ZERO GAME THING tablet review remains pending.


## November 5 — Short Consent barrier and movement poses

`terms_consent_barrier_v3.webp` is the 100-unit Consent barrier sprite, composed for the in-game 152 × 103 drawing area without aspect distortion. It remains distinct from the 42-unit ACCEPT curb. The former high-tier Terms slots now use the same Consent hazard and the separate Terms window is retired. The grind loop holds frame 29 (both feet on the board), and rail-pop ends at frame 33 to avoid frame 34's rail embedded in the sprite.

## November 6 — Terms Runner delivery drone

- `terms_runner_delivery_drone_v1.webp`: transparent, losslessly optimized 576 × 288 px game sprite derived from the user-selected “Acid-lime Terms Runner Drone.png” concept in the ChatGPT Library. Displayed at 144 × 72 px (4× source sampling) in the AU-only skin.
- The renderer bolts a flat lime deck to the sprite. Its top is the board contact surface and the hull and cargo hitboxes sit below it. Phase 2 uses alternating high and mid-height couriers with a subtle ±3-unit hover motion.
- The packaged artwork stays under `skins/au/`; it is not copied into the open Fony skin.

## Cookie Eye security drone

- `terms_cookie_eye_v1.webp` is a transparent 384 × 152 px sprite generated from the Terms Runner's inked style and the original Cookie Eye silhouette. Its neutral rotor and hull trim reserve lime for the vulnerable roof and spray effects.
- Rotor motion, scan charge, paint splatter, the lime roof and the falling shutdown pose share the same anchored hull. The lit roof and the stomp use the same collision edge.


## Fony animation atlas v2

The runtime keeps the two approved atlas files separate by role, with a shared 128 × 128 cell size and (64, 117) board/foot contact anchor:

- `fony_gameplay_atlas_v1.webp` remains the source for the six-frame board-contact skating cycle and the settled pose after a bail. Keeping this sheet preserves the established grounded animation and stable game-over silhouette.
- `fony_gameplay_atlas_v2.webp` is loaded as `skaterActions` (8 columns × 7 rows). Its generated action frames drive ollie, landing/recovery, tricks, grinding, grind-pop and bail.
- Original v2 sheet ranges: 0–5 run; 6–10 ollie; 11–14 landing; 15–18 kickflip; 19–22 heelflip; 23–26 360 flip; 27–30 varial combo; 31–34 hard flip combo; 35–38 laser flip combo; 39–42 grind; 43–46 grind-pop; 47–50 bail. Cells 51–55 are transparent padding.
- The active ollie takes off in cells 11 and 12, tucks in 10, and reaches for the landing in 13. Ground contact starts at 14. Rail and stomp bounces use 12, 10, and 13. The grind cycles through the planted-foot poses 39 and 42. The skin lists these cells in playback order.
- The six named trick animations each use their own four-frame sequence selected by trick sequence and score tier. The action-sheet art is transparent and contains no rail, pipe, ledge, or support. Gameplay rails are drawn in world space.
- The `sheet` field in `skin.json` identifies each animation's source atlas. Both character sheets render with interpolation disabled and share one contact anchor, keeping desktop and Zero Game Thing tablet poses aligned.
