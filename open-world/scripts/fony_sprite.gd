extends Node3D

## Painted Fony, as a Y-locked billboard inside the 3D park.
## The mesh rig stays in the tree so it can be shown again. This node does not
## move the body or the board collider.

const AnimScript = preload("res://scripts/fony_sprite_anim.gd")

var anim = AnimScript.new()
var sprite: Sprite3D
var frames := {}
var pixel_size := 0.0077
var foot_local_y := 0.325
var anchor := Vector2(106, 262)
var cell := Vector2(212, 272)
var _prev_speed := 0.0
var shown := ""

func _ready() -> void:
	name = "FonySprite"
	_load_atlas()

func _physics_process(delta: float) -> void:
	var body = get_parent()
	if body == null or sprite == null:
		return
	var velocity: Vector3 = body.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var accel := (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	var bail := str(body.trick) == "bail" or float(body.bail_time) > 0.0
	anim.notify_mode(bool(body.skating), bail)
	var grinding: bool = body.grind != null
	var want_push: bool = float(body.wish_len) > 0.2 and bool(body.skating) and body.is_on_floor() and not grinding and str(body.trick) == ""
	anim.update_push(speed, accel, want_push)
	anim.advance(delta)
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var camera_x := global_position.x
	var camera_z := global_position.z + 4.0
	if cam != null:
		camera_x = cam.global_position.x
		camera_z = cam.global_position.z
	var facing := 0.0
	if body.rig != null:
		facing = body.rig.global_rotation.y
	var rising := velocity.y > 0.8
	var key: String = anim.choose(facing, camera_x, camera_z, global_position.x, global_position.z, str(body.trick), not body.is_on_floor(), rising)
	_show(key)
	body.sprite_frame = key

func _load_atlas() -> void:
	var text := FileAccess.get_file_as_string("res://assets/library/fony2d/frames.json")
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Fony sprite atlas metadata missing")
		return
	frames = parsed.get("frames", {})
	pixel_size = float(parsed.get("pixel_size", pixel_size))
	foot_local_y = float(parsed.get("foot_local_y", foot_local_y))
	anchor = Vector2(float(parsed.get("anchor_x", anchor.x)), float(parsed.get("anchor_y", anchor.y)))
	cell = Vector2(float(parsed.get("cell_w", cell.x)), float(parsed.get("cell_h", cell.y)))
	var texture: Texture2D = load("res://assets/library/fony2d/fony2d_atlas.png")
	sprite = Sprite3D.new()
	sprite.name = "Card"
	sprite.texture = texture
	sprite.centered = true
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	sprite.region_enabled = true
	# The shared foot pixel sits on the capsule bottom. Image Y grows downward.
	sprite.position = Vector3(
		-(anchor.x - cell.x * 0.5) * pixel_size,
		foot_local_y + (anchor.y - cell.y * 0.5) * pixel_size,
		0.0
	)
	add_child(sprite)
	_show("skate_front")

func _show(key: String) -> void:
	if sprite == null or key == shown:
		return
	var frame = frames.get(key)
	if typeof(frame) != TYPE_DICTIONARY:
		return
	sprite.region_rect = Rect2(float(frame.get("x", 0)), float(frame.get("y", 0)), float(frame.get("w", cell.x)), float(frame.get("h", cell.y)))
	shown = key
