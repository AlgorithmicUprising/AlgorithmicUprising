extends RefCounted

## Picks a painted frame from facing, camera, and skate state.
## The 3D rig stays in charge of physics. This only names a sprite.
## Kick-up, drop-in, and trick poses are front-only. The side push cycle is
## the real left-facing art; it is not mirrored, so the chest patch stays put.

const DIRS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const TRANSITION_FRAME := 0.13
const PUSH_FRAME := 0.11

var phase := ""
var phase_time := 0.0
var push_time := 0.0
var pushing := false
var skating := true
var _prev_bail := false

func direction_index(facing_yaw: float, camera_x: float, camera_z: float, origin_x: float, origin_z: float) -> int:
	var to_cam := Vector2(camera_x - origin_x, camera_z - origin_z)
	if to_cam.length() < 0.001:
		return 0
	to_cam = to_cam.normalized()
	var face := Vector2(-sin(facing_yaw), -cos(facing_yaw))
	var cross_y := to_cam.y * face.x - to_cam.x * face.y
	var dot := to_cam.dot(face)
	var signed := atan2(cross_y, dot)
	return posmod(int(round(signed / (PI / 4.0))), 8)

func direction_name(facing_yaw: float, camera_x: float, camera_z: float, origin_x: float, origin_z: float) -> String:
	return DIRS[direction_index(facing_yaw, camera_x, camera_z, origin_x, origin_z)]

func notify_mode(next_skating: bool, bail_block: bool) -> void:
	var blocked := bail_block or _prev_bail
	_prev_bail = bail_block
	if next_skating == skating:
		return
	skating = next_skating
	if blocked:
		phase = ""
		phase_time = 0.0
		return
	phase = "dropin" if next_skating else "kickup"
	phase_time = 0.0

func update_push(speed: float, accel: float, want: bool) -> void:
	if not want or not skating:
		pushing = false
		return
	if pushing:
		pushing = speed < 8.4 or accel > 0.15
	else:
		pushing = speed < 6.4 or (accel > 0.25 and speed < 8.6)

func advance(delta: float) -> void:
	if phase != "":
		phase_time += delta
		if phase_time >= TRANSITION_FRAME * 3.0:
			phase = ""
			phase_time = 0.0
	if pushing:
		push_time += delta
	else:
		push_time = 0.0

func transition_frame() -> String:
	if phase == "":
		return ""
	var idx := clampi(int(phase_time / TRANSITION_FRAME), 0, 2)
	if phase == "kickup":
		return ["kickup_1_hook", "kickup_2_rise", "kickup_3_catch"][idx]
	return ["dropin_1_drop", "dropin_2_step", "dropin_3_plant"][idx]

func choose(facing_yaw: float, camera_x: float, camera_z: float, origin_x: float, origin_z: float, trick: String, airborne: bool, rising: bool) -> String:
	if trick == "crouch":
		return "trick_crouch_front"
	if trick == "flip":
		return "trick_kickflip_front"
	if trick == "grab":
		return "trick_grab_front"
	if trick == "land" or trick == "bail":
		return "trick_land_front"
	if trick == "ollie" or (airborne and skating and rising and trick == ""):
		return "trick_ollie_front"
	var trans := transition_frame()
	if trans != "":
		return trans
	var dir := direction_name(facing_yaw, camera_x, camera_z, origin_x, origin_z)
	if not skating:
		return "idle_" + dir
	if pushing and not airborne:
		if dir == "left":
			var step := posmod(int(push_time / PUSH_FRAME), 3)
			return ["push_cycle_left_1", "push_cycle_left_2", "push_cycle_left_3"][step]
		return "push_" + dir
	return "skate_" + dir
