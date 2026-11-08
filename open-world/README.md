# AU Open World HQ greybox

A provisional 3D yard. Fony, an articulated capsule-and-sphere teen, skates it. Zero, a CRT-headed rig, waits in the resistance rooms. Neither is a skinned character, and the banded shader is not the painted concept. It is not the Punk Arcade, and it does not change that project. The engine and the shipping platform are not locked. This pass uses Godot 4.7.2 and the Compatibility renderer.

Play it locally:

```bash
# Binary verified for this pass: Godot 4.7.2-stable, Linux x86_64.
# https://github.com/godotengine/godot/releases/tag/4.7.2-stable
godot --path open-world
```

Headless checks:

```bash
godot --headless --path open-world res://tests/test_main.tscn
```

The yard, the cel shader, and the list of art still to draw are in [BUILD_GUIDE.md](BUILD_GUIDE.md) and [ASSET_MANIFEST.md](ASSET_MANIFEST.md). Merging to `main` publishes this yard over the live HQ, so that waits for a visual OK.

Code in this directory is MIT. Branding, character art, and music are not included. See [NOTICE.md](NOTICE.md).
