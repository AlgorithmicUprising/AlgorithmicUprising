# Tag Before Training

Skate the alley, spray your tag and stop scraper drones photographing it. The arcade branch now includes the approved Fony Back Alley art skin.

## Play

Open `demo/index.html` through the arcade dev server, or the dedicated GitHub Pages preview at `/games/tag-before-training/demo/`. The arcade landing page links to it. `demo/embed.html` is the edge-to-edge iframe fallback.

- WASD / arrows: skate with momentum; facing follows your last movement.
- Space / touch SPRAY / gamepad A: hold to spray a wall or drone in front of you.
- P / Esc: pause. M: sound. Gear: local custom tag, reduced motion and left-handed controls.
- On touch, drag the floating stick and hold SPRAY with your other thumb. Controls are below the canvas.

There are 24 taggable wall bays, paint pickups, escalating waves and four drone types. Tagged drones cancel photos, earn STYLE and reduce TRAINING DATA. Scraped tags get the approved copyright stamp; their cooldown expires before retagging. A full TRAINING DATA meter ends the run.

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

`npm run check`, `npm test` and `npm run e2e` cover both games. Tag-specific tests check facing/range, paint consumption, drone interruption, multi-tag capture, watermark locks, seeded waves, artwork loading, touch placement, custom local tags, pause and retry/share.

Custom text and downscaled images stay in localStorage on the current origin; no upload, analytics or accounts are added. SVG imports reject scripts and external resources. If storage is unavailable, the game still runs with the session settings. Reduced motion freezes ornamental frame cycling and removes no gameplay information.

This is an art-integrated development preview, not a declaration that every release milestone in the build guide is complete. The exits remain closed; the larger open world, galleries, online services and multiplayer are out of scope.
