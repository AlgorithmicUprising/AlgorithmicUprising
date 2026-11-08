# AU Open World HQ greybox

A small provisional 3D slice: a skate park, an arcade, and the edge of a shopping district. It is not the Punk Arcade, and it does not change that project. The engine and the shipping platform are not locked. This pass uses Godot 4.7.2 and the Compatibility renderer so a modest desktop GPU, and a later browser export, stay possible.

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

The web export and the combined Pages tree are in [BUILD_GUIDE.md](BUILD_GUIDE.md). After this branch is merged to `main`, the existing Pages workflow publishes the arcade at its current paths and this slice at `/open-world/`.

Code in this directory is MIT. Branding, character art, and music are not included. See [NOTICE.md](NOTICE.md).
