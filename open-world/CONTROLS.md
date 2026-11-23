# Controls

Keyboard, mouse, and a wireless Xbox pad on the standard layout. Godot's joy buttons are the same buttons the WebGL export reads from the browser Gamepad API (the standard mapping). Everything below is remappable from the pause menu. Binds and stick look save to `user://pz-input-v1.json`. Mouse look, invert, and stick look also save with the look prefs.

Button marks in the HUD are original letterforms from this project (E, A, LB, RT, and the rest). They are not Microsoft's Xbox icons.

Last device wins. A key, mouse button, or mouse move shows the keyboard marks. A stick or pad button shows the Xbox marks.

## Dead zones and curves

| Stick | Dead zone | Curve |
|---|---|---|
| Move (left stick) | 0.25 | power 1.65 after the dead zone |
| Camera (right stick) | 0.18 | power 1.65, times the stick-look scale (0.4 to 2.2) |
| Triggers | 0.12 | linear, so a rest trigger does not spray or brake |

A left-stick deflection of 0.1 stays inside the move dead zone.

## Xbox

| Action | Button | Notes |
|---|---|---|
| Move | Left stick | Camera-relative |
| Camera | Right stick | Mouse invert Y does not flip the stick. Invert stick Y is its own option and starts off. Invert X flips both |
| Jump / ollie pop | A | Walk hop, or the pop off a rail. Also confirms menus and hold-to-skip |
| Trick | B | One button. Context and combo tier pick the maneuver |
| Interact | X | Talk, cabinets, doors, topic menu done |
| Skate / walk | Y | On a quarter deck facing the coping: set up or back out |
| Grind | LB | Separate from tricks. Hold to widen the rail catch. Riding onto a rail still locks |
| Boost | RB | Spends the boost tank. A burst of speed while it lasts |
| Brake | LT | Extra friction |
| Spray / attack | RT | Disables a drone in the cone for 8 s. Color is the one data slot |
| Menus | D-pad | Also the left stick on the start screen |
| Pause | Menu (Start) | |
| Map / log | View | Phone log when a story is running. No city map yet |
| Zero Vision | L3 | Toggles it after 1.4B unlocks it. Before that, the phone says it isn't on yet |
| Retry objective | R3 | Also a row in the pause menu |
| Story mode | Share | P on a keyboard. Share is the pad button when the browser reports it |
| Push | Left stick | The stick is the push. R on a keyboard is an extra pump |

## Keyboard and mouse

| Action | Binding | Notes |
|---|---|---|
| Move | WASD, arrows | |
| Camera | Mouse | Click to capture. `[` `]` change mouse look speed |
| Jump / ollie pop | Space | |
| Trick | Q | One button. See the tier table |
| Grind | F | |
| Spray / attack | Left click | Only once the mouse is captured, so the first click still grabs the view |
| Boost | X | |
| Push | R | Extra acceleration |
| Brake | Ctrl | |
| Interact | E | E is never a camera key. The remap screen refuses to move it |
| Skate / walk | Shift | |
| Pause | Esc | |
| Confirm | Enter | |
| Back | Backspace | |
| Map / log | M | |
| Zero Vision | Z | |
| Story mode | P | |
| Retry objective | T | |
| Topics | 1–4, or arrows and Enter | The topic list highlights a row for the pad |
| Kickturn | Hold S high on a quarter | Unchanged |
| Name entry | Type, or the on-screen letters | The letter grid is there so a pad never needs the mouse |

## The one trick button

The button reads where the board is and how long the current chain is.

| Chain | Tier | Flat | Air | Ramp | Grind |
|---|---|---|---|---|---|
| 0–1 | 0 | Ollie | Kickflip | Ollie | 50-50 |
| 2–3 | 1 | Kickflip | Grab | Backside air | 5-0 |
| 4–5 | 2 | Grab | Kickflip | Backside air | Boardslide |
| 6+ | 3 | Kickflip | Grab | Backside air | Boardslide |

A locked grind (story mode still locks 5-0 and boardslide until they open) stays on the grind he already has. Holding the trick button keeps a grab, and a grab still held at the landing is still a bail. Tests can still request an ollie, flip, or grab by name.

## Boost

Landing a trick, locking a grind, switching grind, or landing a backside air fills the tank. A higher tier fills more. The chain lasts 2.8 s. A bail ends the chain and leaves the tank where it was. The meter sits at the bottom of the screen: fill, chain, tier pips, and which button spends it.

## Spray

`data/spray_slot.json` has one slot, `default`, color Yard lime (`#c8ff3a`). Skin packs can add colors later. There is no store.

Spray disables:

- Cold Row patrol drones (1.4, and the camera patrols in 1.5). They stop and stop filling WATCH for 8 s.
- Glass Row chase drones. A disabled drone does not catch and does not keep line of sight.
- The Glass Row parking camera. Painting it before the zone blinds it, so the chase does not get the spot boost.

The 1.5 swarm is still knocked by a touch or the tower mist. Spray is not that fight.

## Conflicts

- A is jump in the world and confirm in a menu. Esc still leaves the pause menu. A confirms the highlighted row.
- B is the trick button in the world and back in a menu.
- E is interact only. It used to be named as a camera-right key as well. Nothing in the map binds it to the camera, and a remap cannot put it there.
- The left stick is both move and push. Keyboard push is R, so the pad does not spend a second button on it.
- Share (story mode) only arrives if the browser's gamepad mapping reports that button. Retry is also a pause-menu row, so a pad can reach it without Share.
- There is no city map. View / M opens the phone log.

## Rumble

Land a grind, bail, or spray a drone and the pad rumbles when the browser exposes `vibrationActuator` or a haptic actuator. Headless and a keyboard do not rumble.
