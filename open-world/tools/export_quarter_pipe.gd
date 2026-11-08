extends SceneTree

func _initialize() -> void:
	var pipe: Node3D = load("res://assets/library/quarter_pipe/quarter_pipe.tscn").instantiate()
	root.add_child(pipe)
	if pipe.triangle_count == 0:
		pipe._build()
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var appended: Error = gltf.append_from_scene(pipe, state)
	var target := ProjectSettings.globalize_path("res://assets/library/quarter_pipe/quarter_pipe.glb")
	var written: Error = gltf.write_to_filesystem(state, target)
	print("quarter glb append=", appended, " write=", written, " tris=", pipe.triangle_count, " path=", target)
	quit(0 if appended == OK and written == OK else 1)
