extends Node3D
## Arcade Phase 1 (LOCAL): the front roll-up shutter.
## Closed by default; it never opens on approach. Interact (E / pad X) at the shutter rolls it up,
## fades to black and moves the player into the separate interior scene (scenes/arcade_interior.tscn).
## Interact at the inside exit fades back out to the deck, and the shutter rolls down behind you.
## The HQ main scene, flow and audio owner stay loaded; the interior is its own scene instanced on demand.

const M = preload("res://scripts/arcade_materials.gd")
const Trigger = preload("res://scripts/arcade_trigger.gd")
const INTERIOR_SCENE := "res://scenes/arcade_interior.tscn"
const INTERIOR_ORIGIN := Vector3(-400.0, 0.0, -400.0)
const ROLL_TIME := 1.6
const FADE_TIME := 0.45
const HOLD_TIME := 0.2
const CLOSE_TIME := 1.2

signal state_changed(new_state: String)

var state := "closed"   # closed, opening, fading_in, inside, leaving, closing
var roll := 0.0         # 0 closed .. 1 fully rolled up
var width := 8.0
var height := 5.15
var base := Vector3.ZERO
var shutter: MeshInstance3D
var shutter_mat: ShaderMaterial
var bottom_bar: MeshInstance3D
var body: StaticBody3D
var fade_layer: CanvasLayer
var fade: ColorRect
var interior: Node3D
var player: Node
var triggers: Array = []
var entries := 0
var exits := 0

func setup(at: Vector3, w: float, top: float) -> void:
	base = at
	width = w
	height = top - at.y
	shutter = MeshInstance3D.new()
	shutter.name = "Shutter"
	var q := QuadMesh.new()
	q.size = Vector2(w, 1.0)
	shutter.mesh = q
	shutter_mat = M.shutter()
	shutter.material_override = shutter_mat
	add_child(shutter)
	bottom_bar = MeshInstance3D.new()
	bottom_bar.name = "ShutterBar"
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.14, 0.12)
	bottom_bar.mesh = bm
	bottom_bar.material_override = M.flat(M.STEEL, 0.0)
	bottom_bar.layers = M.NO_OMNI_LAYER
	add_child(bottom_bar)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.5, 0.08, 0.08)
	handle.mesh = hm
	handle.position = Vector3(0, 0.02, 0.08)
	handle.material_override = M.flat(M.CAUTION, 0.0)
	handle.layers = M.NO_OMNI_LAYER
	bottom_bar.add_child(handle)
	body = StaticBody3D.new()
	body.name = "ShutterBody"
	var sh := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, top + 0.5, 0.3)
	sh.shape = bs
	body.add_child(sh)
	body.position = Vector3(at.x, (top + 0.5) * 0.5, at.z - 0.12)
	add_child(body)
	for i in 3:
		var t := Trigger.new()
		t.name = "ArcadeShutterTrigger%d" % i
		t.door = self
		t.kind = "enter"
		t.position = Vector3(at.x + (float(i) - 1.0) * 2.6, at.y + 0.5, at.z + 0.75)
		add_child(t)
		triggers.append(t)
	fade_layer = CanvasLayer.new()
	fade_layer.name = "ArcadeFade"
	fade_layer.layer = 90
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.visible = false
	fade_layer.add_child(fade)
	_set_roll(0.0)

func can_use(kind: String) -> bool:
	return (kind == "enter" and state == "closed") or (kind == "leave" and state == "inside")

func _set_roll(v: float) -> void:
	roll = clampf(v, 0.0, 1.0)
	var visible_h := maxf(height * (1.0 - roll), 0.1)
	var top := base.y + height
	shutter.scale = Vector3(1.0, visible_h, 1.0)
	shutter.position = Vector3(base.x, top - visible_h * 0.5, base.z)
	shutter_mat.set_shader_parameter("uv_scale", Vector2(width, visible_h))
	shutter_mat.set_shader_parameter("uv_offset", Vector2(0.0, height - visible_h))
	bottom_bar.position = Vector3(base.x, top - visible_h + 0.07, base.z + 0.04)

func _set_fade(a: float) -> void:
	fade.visible = a > 0.001
	fade.color = Color(0, 0, 0, a)

func _set_state(s: String) -> void:
	state = s
	state_changed.emit(s)

func _usable(flow: Node) -> bool:
	if flow == null:
		return player != null
	if "boundary" in flow and flow.boundary.phase != "world":
		return false
	if flow.get("dialogue_open") or flow.get("paused"):
		return false
	return true

func enter(flow: Node) -> bool:
	if state != "closed" or not _usable(flow):
		return false
	if flow != null:
		player = flow.player
	entries += 1
	_lock(true)
	_set_state("opening")
	var tw := create_tween()
	tw.tween_method(_set_roll, roll, 1.0, ROLL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_set_state.bind("fading_in"))
	tw.tween_method(_set_fade, 0.0, 1.0, FADE_TIME)
	tw.tween_callback(_move_inside)
	tw.tween_interval(HOLD_TIME)
	tw.tween_method(_set_fade, 1.0, 0.0, FADE_TIME)
	tw.tween_callback(_arrived)
	return true

func leave(flow: Node) -> bool:
	if state != "inside" or not _usable(flow):
		return false
	if flow != null:
		player = flow.player
	exits += 1
	_lock(true)
	_set_state("leaving")
	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, FADE_TIME)
	tw.tween_callback(_move_outside)
	tw.tween_interval(HOLD_TIME)
	tw.tween_method(_set_fade, 1.0, 0.0, FADE_TIME)
	tw.tween_callback(_back_out)
	tw.tween_method(_set_roll, 1.0, 0.0, CLOSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_set_state.bind("closed"))
	return true

func ensure_interior() -> Node3D:
	if interior == null:
		interior = load(INTERIOR_SCENE).instantiate()
		interior.name = "ArcadeInterior"
		interior.position = INTERIOR_ORIGIN
		get_parent().add_child(interior)
		interior.bind_door(self)
	return interior

func _move_inside() -> void:
	ensure_interior()
	interior.visible = true
	_set_roll(0.0)
	_place(interior.to_global(interior.spawn_local), 0.0)

func _arrived() -> void:
	_lock(false)
	_set_state("inside")

func _move_outside() -> void:
	_set_roll(1.0)
	_place(Vector3(base.x, base.y + 0.5, base.z + 2.2), PI)
	if interior != null:
		interior.visible = false

func _back_out() -> void:
	_lock(false)
	_set_state("closing")

func _place(pos: Vector3, yaw: float) -> void:
	if player == null:
		return
	if player.has_method("respawn"):
		player.respawn()
	if "skating" in player and player.skating:
		player.skating = false
		if player.has_method("update_board"):
			player.update_board()
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	if "camera_yaw" in player:
		player.camera_yaw = yaw

func _lock(on: bool) -> void:
	if player == null:
		return
	if "input_enabled" in player:
		player.input_enabled = not on
	if on:
		player.velocity = Vector3.ZERO
