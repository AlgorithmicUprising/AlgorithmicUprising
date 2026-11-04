# Tag Before Training: Fony Back Alley

Game 02 artwork approved for integration on November 4, 2026. This skin uses the original generated punk alley art set: overhead Fony, Scout, Swarmlet, Hoover, Watermarker, props, paint effects, tag treatments, interface controls and copyright stamps.

The fourteen overhead Fony poses are the gameplay source. The three-quarter alternate is reserved for presentation and is not used for movement.

The export script cleans transparent margins, slices the animation sheets, registers Fony to the board, and packs 87 frames. `frames.json` records the frame rectangles and anchors. The exported PNG sprite atlases and interface files preserve the approved raster artwork and contain no scripts or remote image references.

Reproduce from the approved numbered PNG sheets with `npm run prepare-tag-art -- <approval-sheets-folder>`. No runtime processing tools are needed to play.

The default pink slashed-zero tag and AU / Zero X Humans patch treatments are branded artwork. This skin is all rights reserved under its LICENSE, not part of the open Fony placeholder skin. Do not distribute the AU assets under the repository's code license.

The neutral starter skin and missing-art fallback remain procedural. Live HUD values and menus are real text and controls rather than baked screenshot images. The final 24 gameplay wall bays are drawn as modular wall pieces over the background, so visual positions match spray and collision geometry.

Scraped wall labels now use a light paper backing and bold canvas lettering. The generated stamp treatments remain in the source pack, while the in-game label prioritizes reading clearly at phone size.
