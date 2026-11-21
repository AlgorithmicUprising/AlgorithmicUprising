# Controls (provisional)

Running list of every binding in `scripts/input_bindings.gd`, plus raw keys handled in code. **All controls are provisional.** New actions go on a temporary key that is easy to test, and are listed here with the milestone that added them. Nothing here is a final layout.

Last updated: front end (start menu, intro video, saves), Nov 19 2026 (branch `pz-m1-practice-run`, local only).

## Movement and skating

| Action | Keyboard | Gamepad | Notes |
|---|---|---|---|
| `move_forward` / `move_back` / `move_left` / `move_right` | W A S D, arrow keys | Left stick | Relative to the camera |
| `jump` | Space | A | Plain jump; also pops out of a grind |
| `skate_toggle` | Shift | Y | Kick up (walk) / drop the board (skate). On a quarter-pipe deck facing the coping: set up / back out of a drop-in |
| `trick_ollie` | Q | not bound | Ollie; pops out of a grind |
| `trick_flip` | R | not bound | Kickflip; on a rail: boardslide (locked in story mode) |
| `trick_grab` | F | not bound | Melon grab; off the coping: backside air; on a rail: 5-0 (locked in story mode) |
| Kickturn | hold S high on a quarter pipe | | |
| `camera_*` | Mouse (click to capture) | Right stick | |
| Look speed | `[` and `]` | | Raw keys in `hq_main.gd` |

## World and menus

| Action | Keyboard | Gamepad | Notes |
|---|---|---|---|
| `interact` | E | X | Talk, cabinets, doors |
| `pause` | Esc | Start | Pause menu has Invert mouse Y and Painted sprite |
| `session_confirm` | Enter, keypad Enter | A | |
| `session_cancel` | Backspace | B | |

## Story mode (added in M1, provisional, keyboard only)

| Action | Keyboard | Gamepad | Notes |
|---|---|---|---|
| `story_toggle` | **P** | not bound | Starts P.1 Practice Run from free roam; P again leaves story mode and puts free roam back |
| `mission_retry` | **T** | not bound | Back to the current objective's checkpoint; once the line is open, back to the bowl rim |

Ways in without a key, for testing: `story=p1` after `--` on the command line, or `?story=p1` on the web build. `story_demo=1` / `?story=p1&story_demo=1` lets the review autopilot play P.1 (it presses the same inputs the headless tests do).

## Start screen and front end (added Nov 19 2026, provisional)

| Where | Keyboard | Mouse | Gamepad | Notes |
|---|---|---|---|---|
| Title (PRESS START) | any key | any click | any button | Shows the menu row in place of PRESS START |
| Menu row | Left / Right (also Tab / Shift+Tab), Enter | hover + click | D-pad / left stick, A | New Game, Load Game, Uprising Arcade, Credits. Load Game is greyed out and skipped when there are no saves. Down reaches the account chip |
| Any menu panel | Esc or Backspace closes | BACK button | B | Name, Start over?, Load, Arcade, Credits |
| Character name | type, Enter to start | | | Default "Fony" (placeholder). A name that already has a save asks "Start over?" with Cancel focused |
| Intro video (first time) | hold Space / Enter / Esc for 1 s | hold the button | hold A / B / Start | Hold-to-skip ring. After the intro has been seen once, a single press skips it |
| Intro video, no sound | | click "CLICK FOR SOUND" | | Only when the browser blocks sound autoplay |
| Pause menu (with a character) | Up / Down to reach the buttons, Enter | click | D-pad, A | Save game, Load game, Quit to title |
| Arcade overlay | the overlay's back button | click | | "BACK TO PROJECT ZERO" from the start screen |

Dev shortcuts past the start screen (first load only): `?play=free` (free roam, as before the front end), `?story=p1`, `?story=p1&story_demo=1`, `?district=…`, `?demo=…`. The same words work after `--` on the command line. Intro overrides: `?intro=skip` (straight to P.1) and `?intro=<url>` (play another file). Free roam autosaves every 90 s once a character is loaded.

## Gaps to decide

- Tricks (Q, R, F) and the two story keys have no gamepad buttons yet, so P.1's ollie and 50-50 prompts say "pad: not bound yet".
- P and T were picked only because they were free. P may want to become the pause or map key later.
- The hold-to-skip time (1 s first time, single press after) is a guess. The intro can be made skippable from the first play by setting `skip.hold_s` in `data/intro_video.json`.
