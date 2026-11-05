# Tag Before Training

Skate the alley, spray your tag and stop scraper drones photographing it. The arcade branch now includes the approved Fony Back Alley art skin.

## Play

Open `demo/index.html` through the arcade dev server, or the dedicated GitHub Pages preview at `/games/tag-before-training/demo/`. The arcade landing page links to it. `demo/embed.html` is the edge-to-edge iframe fallback.

- WASD / arrows: skate with momentum; facing follows your last movement.
- Space / touch SPRAY / gamepad A: hold to spray a wall or drone in front of you.
- P / Esc: pause. M: sound. Gear: local custom tag, reduced motion and left-handed controls.
- On touch, drag the floating stick and hold SPRAY with your other thumb. Controls are below the canvas.

There are 24 taggable wall bays, paint pickups, escalating waves and four drone types. Tagged drones cancel photos, earn STYLE and reduce TRAINING DATA. Scraped tags get the approved copyright stamp; their cooldown expires before retagging. A full TRAINING DATA meter ends the run.

## Hunt and police preview rules (v0.4.0)

Ten seconds without a completed, unscraped wall tag makes ordinary drones hunt Fony. Watermark signs and partial tags do not reset that timer. A hunter must stay within 90 world pixels for a continuous two-second scan to identify him. Leaving scan range, tagging the scanner, or completing a fresh wall tag breaks the scan. Fresh art draws ordinary drones back to the walls.

A completed player scan calls two police drones from opposite ends of the alley after a two-second warning. Police ignore wall tags and keep pursuing between waves. Two officers must remain within 40 world pixels of Fony together for 1.5 continuous seconds to arrest him. Leaving that radius or tagging either officer resets the hold immediately. A single officer cannot arrest, but calls one replacement after eight seconds. Tag both to clear the pursuit and restart the ten-second art timer.

Police take one second of spray, award 500 base STYLE, and reduce Training Data by five points like other drones. Their solid red/blue lights, shield, POLICE label, edge markers, scan warning and arrest progress distinguish each stage. Game over explicitly reports either Training Data reaching 100% or a police arrest. These timing values are preview defaults for playtesting.

Fony starts with one 200-unit can, twice the previous capacity. Every pickup adds a full can, with three carried cans maximum (600 units when all are full). A partly used can occupies a slot; pickups stay on the ground when all three slots are occupied. Empty cans switch automatically. The HUD shows three separate paint bars. Spray still costs 25 units per second.

Spray now reaches 72 world pixels in a 60-degree cone, and drone bodies count toward a hit instead of only their centers. Drones can be painted anywhere in the alley. A small pink bar shows accumulated paint on each drone, including police.

## Embed

```html
<script type="module" src="./dist/tag-before-training.js"></script>
<tag-before-training skin="./skins/au/skin.json" seed="1471"></tag-before-training>
```

Omit `skin` for the procedural fallback. The starter `fony` skin is still procedural; the illustrated AU artwork is isolated under `skins/au/` and all rights reserved. Anyone reusing the open game must remove that branded skin. Do not publish a CDN release URL until a corresponding release tag exists.

## Artwork

The approved overhead sheet supplies fourteen Fony poses. Four drone sheets supply 47 fly/lock/stamp/tagged poses. Props and effects bring the registered atlas total to 87. The approved artwork is exported to PNG sprite atlases and interface assets, with no runtime conversion. Frame rectangles and board anchors live in the AU skin manifest. Live HUD text and menus stay real controls. See `skins/au/ART-SOURCES.md`.

To regenerate the art exports from the numbered approval PNGs, run `npm run prepare-tag-art -- <approval-sheets-folder>` inside `arcade/`.

## Local checks

`npm run check`, `npm test` and `npm run e2e` cover both games. Tag-specific tests check facing/range, can inventory, open-space drone tagging, photo interruption, hunt and scan escape, police distraction immunity, arrest interruption, backup, seeded waves, artwork loading, touch placement, custom local tags, pause and retry/share.

Custom text and downscaled images stay in localStorage on the current origin; no upload, analytics or accounts are added. SVG imports reject scripts and external resources. If storage is unavailable, the game still runs with the session settings. Reduced motion freezes ornamental frame cycling and removes no gameplay information.

This is an art-integrated development preview, not a declaration that every release milestone in the build guide is complete. The exits remain closed; the larger open world, galleries, online services and multiplayer are out of scope.
