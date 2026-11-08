# Quarter pipe

One rideable concrete quarter. It is the first finished ramp in the library, not a finished park.

## Place another one

Instance `quarter_pipe.tscn`. Set position and `rotation.y` before it enters the tree. Local +X climbs. The pivot is the middle of the low lip, on the ground.

```gdscript
var pipe := load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
pipe.position = Vector3(0, 0, 0)
pipe.rotation.y = 0.0
parent.add_child(pipe)
```

The HQ uses one at `(-54, 0, -12)`, yaw `PI`, so the approach is from the east. Half-pipes and the funbox are still the older block ramps.

## Dimensions

| | |
|---|---|
| Riding radius | 2.4 m |
| Width | 7.0 m along local Z |
| Climb | 70° then a 1.6 m deck |
| Shell thickness | 0.42 m |
| Curve segments | 36 |
| Triangles | 1,630 for the default size, shell plus coping plus two posters |
| Textures | `concrete_albedo.png` 1024×512, `graffiti_albedo.png` 512×512. Original, from `tools/make_quarter_textures.py` |
| Coping | cylinder, radius 0.05 m, length width + 0.36 m, no collision |
| Origin | centre of the entrance lip, y = 0 |

`radius`, `width`, `climb_deg`, `deck_length`, `thickness`, and `curve_steps` are exports. Change them on the instance before `_ready`.

## Collision

`Collision` is a static body. Each curve step and the deck is a convex slice using the same outer and inner profile as the shell, across the riding width only. The cheeks and coping are visual. The riding mesh and the collision share that profile, so the surface the player stands on is the surface they see.

## Materials

| Slot | Node | Texture |
|---|---|---|
| Shell | `Shell` | `concrete_albedo.png` through `cel_block.gdshader` |
| Coping | `Coping` | flat metal colour, same shader, no texture |
| Graffiti | `GraffitiL`, `GraffitiR` | `graffiti_albedo.png` |

Textures are original, drawn by `tools/make_quarter_textures.py`. They are not traced from the park painting.

## Portable mesh

`quarter_pipe.glb` is a copy of the built meshes for other tools. The game does not load it. Regenerate with:

```bash
godot --headless --path open-world -s res://tools/export_quarter_pipe.gd
```

## License

Code in this folder is MIT, with the rest of `open-world/`. The textures and the mesh are original project art, not a third-party asset.
