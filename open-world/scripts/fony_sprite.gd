extends Node3D

## Painted Fony as a Y-locked billboard. v2 clips animate the views that move.
## v1 stills remain for the directions v2 does not cover. The mesh rig stays
## in the tree so the pause menu can show it again.

const AnimScript = preload("res://scripts/fony_sprite_anim.gd")
const V2_PIXEL := 0.005972
const V1_PIXEL := 0.007674

var anim = AnimScript.new()
var sprite: Sprite3D
var tex_v1: Texture2D
var tex_v2: Texture2D
var foot_local_y := 0.325
var _prev_speed := 0.0

func _ready() -> void:
	name = "FonySprite"
	anim.ensure_loaded()
	tex_v1 = load("res://assets/library/fony2d/fony2d_atlas.png")
	tex_v2 = load("res://assets/library/fony2d/fony2d_v2_atlas.png")
	sprite = Sprite3D.new()
	sprite.name = "Card"
	sprite.texture = tex_v2 if tex_v2 != null else tex_v1
	sprite.centered = true
	sprite.pixel_size = V2_PIXEL
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
	add_child(sprite)

func _physics_process(delta: float) -> void:
	var body = get_parent()
	if body == null or sprite == null:
		return
	var velocity: Vector3 = body.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var accel := (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var camera_x := global_position.x
	var camera_z := global_position.z + 4.0
	if cam != null:
		camera_x = cam.global_position.x
		camera_z = cam.global_position.z
	var facing := 0.0
	if body.rig != null:
		facing = body.rig.global_rotation.y
	var ctx := {
		"facing_yaw": facing,
		"camera_x": camera_x,
		"camera_z": camera_z,
		"origin_x": global_position.x,
		"origin_z": global_position.z,
		"skating": bool(body.skating),
		"speed": speed,
		"accel": accel,
		"wish": float(body.wish_len),
		"on_floor": body.is_on_floor(),
		"vy": velocity.y,
		"trick": str(body.trick),
		"trick_time": float(body.trick_time),
		"flip_turns": float(body.flip_turns),
		"bail_time": float(body.bail_time),
		"grind": body.grind != null,
	}
	var frame_key: String = anim.step(delta, ctx)
	_apply(not body.is_on_floor())
	body.sprite_frame = frame_key

func _apply(airborne: bool) -> void:
	var fr := anim.current_frame()
	if fr.is_empty() or sprite == null:
		return
	var rect: Array = fr.get("rect", [0, 0, 1, 1])
	var off: Array = fr.get("anchor_offset", [0.0, 0.0])
	var w := float(rect[2])
	var h := float(rect[3])
	var use_v2 := str(fr.get("source", "v1")) == "v2"
	var ps := V2_PIXEL if use_v2 else V1_PIXEL
	sprite.texture = tex_v2 if use_v2 else tex_v1
	sprite.pixel_size = ps
	sprite.region_rect = Rect2(float(rect[0]), float(rect[1]), w, h)
	# anchor_offset is the rect top-left relative to the ground anchor, y down.
	var anchor_x := -float(off[0])
	var anchor_y := -float(off[1])
	var lift := float(fr.get("lift_atlas", 0.0))
	# The painting already raises airborne poses. The capsule is rising too,
	# so drop that gap while the body is in the air.
	if airborne:
		anchor_y -= lift
	sprite.position = Vector3(
		-(anchor_x - w * 0.5) * ps,
		foot_local_y + (anchor_y - h * 0.5) * ps,
		0.0
	)
