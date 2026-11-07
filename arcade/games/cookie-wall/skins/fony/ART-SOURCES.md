# Cookie Wall Fony art pack · v0.3.0

This pack implements the Cookie Wall build guide's native-size sprite table with the icon-only banner decision from the art review. Banner pixels contain no words: a lock means Strictly Necessary, linked nodes mean 347 Ad Partners, an eye means Legitimate Interest, and an X means Reject All. Short aliases and full names stay in live, accessible UI.

## Source and rights

- **Authorship:** Original pixel/vector primitives authored for Punk Arcade.
- **Build tool:** `source/build_art.py`, using Python Pillow 13.0 to draw directly at each frame's logical dimensions and export PNG/WebP.
- **External image sources:** None. No AI-generated, stock, game-captured, or third-party image pixels are included.
- **Approval:** Commissioned by the project owner in the November 7, 2026 art pass. No paid generation or external image budget was used.
- **Crop/cleanup:** None; every sprite is drawn on its final-size transparent canvas. The court and title plate are drawn at 320×320 and 320×96.
- **Rights:** CC BY 4.0, attributed to Punk Arcade contributors. The AU skin remains separate, all-rights-reserved, and uses only its code-composited `Ø` patch.

## Frame coverage

The pack has all 43 frames listed in `frames.json`: court, blocker idle/hit and swappable patch, four banner families including crack and three break frames, packet spin, two-frame tracker loop, four debris frames, title plate, toolbar icons and launch button states. Dimensions, anchors, animation rates and loop flags are recorded per frame.

The title plate is decorative; the actual title is live skin text rendered by the game UI. The sound, pause, settings, share and launch controls remain real DOM buttons with accessible labels. The icons are visual supplements only. No art is a collision surface and no sprite contains a company mark or baked-in consent text.

## Rebuild

Run `python3 source/build_art.py` from the Fony skin directory with Pillow 13.0 installed. The script writes `sprites/` and `frames.json`; add `--preview` to produce an art review sheet.
