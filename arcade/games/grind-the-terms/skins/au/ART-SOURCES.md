# AU Art Pack — Fony Sprock

**All rights reserved** — Algorithmic Uprising / Zero × Humans branded artwork.

Source art: latest approved generated sheet `Grind the Terms: Punk Sprite Sheet.png` (ChatGPT conversation library), extracted/quantized into sprite cells; original Fony character appearance and color notes live in the Google Drive Punk Arcade / Game 01 art folder. These cropped sprites are preview-quality, not individually hand-cleaned finals.

`fony_sprock_atlas.png`: 8-column grid, each frame 80 × 94 px. Row-major frame order: run 0–5, idle 6–9, land 10–11, ollie 12–16, double 17–20, bail 21–26, grind 27–30, railpop 31–34, flip 35–38. Some cells include residual outline artifacts from the composite art sheet; keep source for manual cleanup.

`terms_hazards_atlas.png`: 4 × 2 grid, cells 144 × 112. Top row: accept, popup, modal, gap; bottom row: token, boost, shield, rail. Decorative plate images: `terms_far_plate.jpg` and `terms_skyline_v2.jpg`.

**Open skin isolation:** This AU skin uses protected Ø / ZERO × HUMANS marks. Neither these assets nor their branded derivatives are CC BY 4.0. The `fony/` starter remains procedural and freely replaceable; do not copy the AU image assets into it.

## November 3 animation alignment repair

Replaced the source composite's flawed 80 × 94 crops with **39 individually isolated 128 × 128 cells** from the approved original sheet. Every pose is bottom-centered against one board/foot anchor at `(64, 117)`; frame art stays within transparent padding, and the renderer draws from that anchor instead of a moving upper-left crop. The death/bail animation is finite (6 frames) and anchored to the impact ground position. The original atlas remains archived but is no longer loaded. Source bounding boxes and normalized frame metadata are in `fony_sprite_anchors.json` (matching copy in the Drive Fony art folder). One source ollie pose was repeated as its fifth animation frame because the composite has four unique ollie illustrations. Further manual cleanup of character details is still possible.
