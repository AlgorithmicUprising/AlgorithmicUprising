extends SceneTree

func _initialize() -> void:
	var rig: Node3D = load("res://scripts/fony_rig.gd").new()
	root.add_child(rig)
	if rig.get_child_count() == 0:
		rig._build()
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var appended: Error = gltf.append_from_scene(rig, state)
	var target := ProjectSettings.globalize_path("res://assets/library/fony/fony.glb")
	var written: Error = gltf.write_to_filesystem(state, target)
	print("fony glb append=", appended, " write=", written, " path=", target)
	quit(0 if appended == OK and written == OK else 1)
