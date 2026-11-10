extends RefCounted

## Human Fony, skinned to the 17-bone trick skeleton.
## The mesh is baked from the CC0 Quaternius superhero male (free Standard pack)
## by tools/bake_fony_human.py. Poses stay on this skeleton so the skate IK,
## the board, and the trick clips do not change.

const TOON := preload("res://shaders/toon_fony.gdshader")
const TOON_DOUBLE := preload("res://shaders/toon_fony_double.gdshader")
const OUTLINE := preload("res://shaders/toon_outline.gdshader")
const SCENE := preload("res://assets/library/fony/human/fony_human.gltf")

const _DOUBLE := ["Hair", "Brows", "Hood", "Eyes"]
const _WIDE_OUTLINE := ["Body", "Jacket", "Hair", "Hood"]

static func attach(root: Node3D) -> Dictionary:
	var inst := SCENE.instantiate()
	root.add_child(inst)
	var skel := _skeleton_with_meshes(inst)
	if skel.get_parent() != root:
		var holder := skel.get_parent()
		holder.remove_child(skel)
		root.add_child(skel)
		inst.queue_free()
	skel.name = "Skeleton"
	var bones := {}
	for i in skel.get_bone_count():
		var rest := skel.get_bone_rest(i)
		bones[skel.get_bone_name(i)] = i
		skel.set_bone_pose_position(i, rest.origin)
		skel.set_bone_pose_rotation(i, rest.basis.get_rotation_quaternion())
		skel.set_bone_pose_scale(i, Vector3.ONE)
	_style(skel)
	var ankle_l := Marker3D.new()
	ankle_l.name = "AnkleL"
	root.add_child(ankle_l)
	var ankle_r := Marker3D.new()
	ankle_r.name = "AnkleR"
	root.add_child(ankle_r)
	var hand_r := Marker3D.new()
	hand_r.name = "HandR"
	root.add_child(hand_r)
	return {
		"skeleton": skel,
		"bones": bones,
		"ankle_l": ankle_l,
		"ankle_r": ankle_r,
		"hand_r": hand_r,
	}

static func _skeleton_with_meshes(node: Node) -> Skeleton3D:
	var best: Skeleton3D = null
	var best_count := -1
	var pending: Array[Node] = [node]
	while pending.size() > 0:
		var current: Node = pending.pop_back()
		if current is Skeleton3D and current.get_child_count() > best_count:
			best = current
			best_count = current.get_child_count()
		for child in current.get_children():
			pending.append(child)
	return best

static func _style(skel: Skeleton3D) -> void:
	for child in skel.get_children():
		if child is MeshInstance3D:
			_style_mesh(child)

static func _style_mesh(mesh: MeshInstance3D) -> void:
	mesh.skeleton = NodePath("..")
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh.extra_cull_margin = 1.4
	var source := mesh.get_active_material(0)
	var color := Color.WHITE
	var tex: Texture2D = null
	if source is BaseMaterial3D:
		color = source.albedo_color
		tex = source.albedo_texture
	var double := mesh.name in _DOUBLE
	var mat := ShaderMaterial.new()
	mat.shader = TOON_DOUBLE if double else TOON
	mat.set_shader_parameter("albedo", color)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("texture_mix", 1.0)
	else:
		mat.set_shader_parameter("texture_mix", 0.0)
	if mesh.name.begins_with("Pad") or mesh.name.begins_with("Patch") or mesh.name.begins_with("Tape") or mesh.name.begins_with("Shoulder") or mesh.name.begins_with("Stripe"):
		mat.render_priority = 2
	elif mesh.name == "Jacket" or mesh.name.begins_with("Shoe"):
		mat.render_priority = 1
	# Open shells (the jacket, tape, patches) grow fins along every cut edge
	# if an inverted hull is used. Outline the closed body, hair, and pads.
	var open_shell := mesh.name == "Jacket" or mesh.name == "Hood" or mesh.name.begins_with("Tape") or mesh.name.begins_with("Shoulder") or mesh.name.begins_with("Pocket") or mesh.name.begins_with("Stripe") or mesh.name == "Patch" or mesh.name == "Brows"
	if not open_shell:
		var width := 0.007
		if mesh.name in _WIDE_OUTLINE:
			width = 0.01
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		outline.set_shader_parameter("outline_width", width)
		outline.render_priority = mat.render_priority
		mat.next_pass = outline
	mesh.material_override = mat
