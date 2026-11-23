extends Node
## MISSION P.2 Run (Act I M3): the pursuing drones. One welfare drone (white, smiling) and, delay_s later, two grey
## Warden enforcement drones. They follow the player's own trail (breadcrumbs dropped every crumb_m), so they never cut
## through Glass Row's walls, and they fly at a fixed altitude over whatever he is riding on.
##   - speed: their base speed, or catchup when he is more than catchup_beyond_m ahead (the pressure never lets up);
##     +boost for a few seconds after the parking camera sees him.
##   - lost: when no drone has a line of sight to him for lost_after_s (behind the garage roof, the van, a wall),
##     they slow to search_speed for search_s ("Visual lost. Requesting area scan.").
##   - caught: a drone inside catch_r of him (after grace_s) drops its net -> caught(kind).
## Text + SFX only; visual nodes come from story_world.gd.

signal caught(kind: String)
signal lost
signal enforcers_in

const World = preload("res://scripts/story/story_world.gd")

## OPEN: first-pass speeds (m/s). The mission JSON overrides these. Not retuned here.
const WELFARE_SPEED := 6.6
const WELFARE_CATCHUP := 11.5
const WELFARE_CATCH_R := 2.0
const ENFORCER_SPEED := 7.2
const ENFORCER_CATCHUP := 12.0
const ENFORCER_CATCH_R := 2.2
const ENFORCER_DELAY_S := 4.0
## Spraying one drone in the chase. The downed drone uses the existing 8 s disable.
## Neighbors inside the radius investigate the spot, then scan until tracking runs out.
const ALERT_RADIUS := 22.0
const INVESTIGATE_S := 3.5
const TRACKING_S := 6.0
const SCAN_DEG := 50.0
const SCAN_HZ := 1.0
const SCAN_RANGE := 16.0

var cfg: Dictionary = {}
var player: Node3D
var root: Node3D
var drones: Array = []              # {node, kind, speed, catchup, catch_r, delay, crumb, active}
var trail: Array = []               # Vector3 ground points behind the player, oldest first
var grace := 0.0
var boost_left := 0.0
var unseen := 0.0
var search_left := 0.0
var running := false
var clock := 0.0
var bob := 0.0
var caught_kind := ""
var los_override := -1              # tests: 1 = always seen, 0 = never seen, -1 = raycast

func setup(c: Dictionary, p: Node3D, parent: Node3D) -> void:
	cfg = c
	player = p
	root = Node3D.new()
	root.name = "ChaseDrones"
	parent.add_child(root)

## Places the drones behind the player (behind: up to three [x, z] points) and starts the chase.
func begin(behind: Array, enforcers_now := false) -> void:
	clear()
	var specs := [["welfare", cfg.get("welfare", {})], ["enforcement", cfg.get("enforcement", {})], ["enforcement", cfg.get("enforcement", {})]]
	for i in specs.size():
		var kind: String = specs[i][0]
		var c: Dictionary = specs[i][1]
		var n: Node3D = World.welfare_drone(root) if kind == "welfare" else World.enforcement_drone(root)
		n.name = "%sDrone%d" % [kind.capitalize(), i]
		var b: Array = behind[mini(i, behind.size() - 1)] if not behind.is_empty() else [player.global_position.x - 14.0, player.global_position.z]
		n.global_position = Vector3(float(b[0]), _alt(player.global_position.y), float(b[1]))
		var delay := 0.0 if kind == "welfare" or enforcers_now else float(c.get("delay_s", ENFORCER_DELAY_S))
		n.visible = delay <= 0.0
		n.add_to_group("spray_target")
		var speed := WELFARE_SPEED if kind == "welfare" else ENFORCER_SPEED
		var catchup := WELFARE_CATCHUP if kind == "welfare" else ENFORCER_CATCHUP
		var catch_r := WELFARE_CATCH_R if kind == "welfare" else ENFORCER_CATCH_R
		drones.append({"node": n, "kind": kind, "speed": float(c.get("speed", speed)), "catchup": float(c.get("catchup", catchup)),
			"catch_r": float(c.get("catch_r", catch_r)), "delay": delay, "crumb": 0, "active": delay <= 0.0})
	trail = [_ground(player.global_position)]
	grace = float(cfg.get("grace_s", 3.0))
	boost_left = 0.0
	unseen = 0.0
	search_left = 0.0
	caught_kind = ""
	clock = 0.0
	running = true

func clear() -> void:
	for d in drones:
		if is_instance_valid(d.node):
			d.node.queue_free()
	drones.clear()
	trail.clear()
	running = false

func stop() -> void:
	running = false

func free_all() -> void:
	clear()
	if root != null and is_instance_valid(root):
		root.queue_free()

func spot() -> void:
	boost_left = float(cfg.get("boost_s", 5.0))

func nearest_distance() -> float:
	var best := INF
	for d in drones:
		if d.active:
			best = minf(best, _flat(d.node.global_position, player.global_position))
	return best

func active_count() -> int:
	return drones.filter(func(d): return d.active).size()

func tick(delta: float) -> void:
	if not running or player == null:
		return
	clock += delta
	bob += delta
	grace = maxf(0.0, grace - delta)
	boost_left = maxf(0.0, boost_left - delta)
	var p := _ground(player.global_position)
	if trail.is_empty() or trail[-1].distance_to(p) >= float(cfg.get("crumb_m", 1.2)):
		trail.append(p)
	# line of sight: any active drone that sees him keeps the chase hot
	var seen := false
	for d in drones:
		if d.active and float(d.node.get_meta("spray_left", 0.0)) <= 0.0 and _sees(d.node.global_position):
			seen = true
			break
	if seen:
		unseen = 0.0
	else:
		unseen += delta
		if unseen >= float(cfg.get("lost_after_s", 2.5)) and search_left <= 0.0:
			search_left = float(cfg.get("search_s", 4.0))
			lost.emit()
	search_left = maxf(0.0, search_left - delta)
	for d in drones:
		if not d.active:
			d.delay -= delta
			if d.delay <= 0.0:
				d.active = true
				d.node.visible = true
				if d.kind == "enforcement" and drones.filter(func(x): return x.kind == "enforcement" and x.active).size() == 1:
					enforcers_in.emit()
			continue
		if _downed(d, delta):
			continue
		if _alert_move(d, delta):
			continue
		_move(d, delta, p)
		if grace <= 0.0 and caught_kind == "" and _flat(d.node.global_position, player.global_position) < d.catch_r and absf(d.node.global_position.y - player.global_position.y) < 5.0:
			caught_kind = d.kind
			World.drone_net(d.node, true)
			running = false
			caught.emit(d.kind)
			return

func _alert(key: String, fallback: float) -> float:
	var block = cfg.get("spray_alert", {})
	if typeof(block) != TYPE_DICTIONARY:
		return fallback
	return float((block as Dictionary).get(key, fallback))

## True while this drone is down from spray. The first frame alerts neighbors.
func _downed(d: Dictionary, delta: float) -> bool:
	var left := float(d.node.get_meta("spray_left", 0.0))
	var was: bool = bool(d.get("down", false))
	if left <= 0.0:
		d["down"] = false
		return false
	if not was:
		d["down"] = true
		d["spot"] = d.node.global_position
		_call_neighbors(d)
	d.node.set_meta("spray_left", maxf(0.0, left - delta))
	return true

func _call_neighbors(downed: Dictionary) -> void:
	var spot: Vector3 = downed.get("spot", downed.node.global_position)
	var radius := _alert("alert_radius", ALERT_RADIUS)
	var hold := _alert("investigate_s", INVESTIGATE_S)
	for other in drones:
		if other == downed or not bool(other.get("active", false)):
			continue
		if float(other.node.get_meta("spray_left", 0.0)) > 0.0:
			continue
		if _flat(other.node.global_position, spot) > radius:
			continue
		other["mode"] = "investigate"
		other["mode_left"] = hold
		other["focus"] = spot
		other["scan_acc"] = 0.0

## True when this drone is investigating or scanning instead of following the trail.
func _alert_move(d: Dictionary, delta: float) -> bool:
	var mode := str(d.get("mode", ""))
	if mode == "":
		return false
	d["mode_left"] = float(d.get("mode_left", 0.0)) - delta
	var focus: Vector3 = d.get("focus", d.node.global_position)
	if mode == "investigate":
		_step_toward(d, focus, float(d.speed), delta)
		if float(d["mode_left"]) <= 0.0:
			d["mode"] = "tracking"
			d["mode_left"] = _alert("tracking_s", TRACKING_S)
			d["scan_acc"] = 0.0
		return true
	_step_toward(d, focus, float(cfg.get("search_speed", 2.5)), delta)
	if _scan_sees(d, delta):
		d["mode"] = ""
		return true
	if float(d["mode_left"]) <= 0.0:
		d["mode"] = ""
	return true

func _scan_sees(d: Dictionary, delta: float) -> bool:
	var hz := maxf(_alert("scan_hz", SCAN_HZ), 0.1)
	d["scan_acc"] = float(d.get("scan_acc", 0.0)) + delta
	if float(d["scan_acc"]) < 1.0 / hz:
		return false
	d["scan_acc"] = 0.0
	var to: Vector3 = player.global_position - d.node.global_position
	var flat := Vector2(to.x, to.z)
	if flat.length() > _alert("scan_range", SCAN_RANGE) or flat.length() < 0.05:
		return false
	var fwd: Vector3 = -d.node.global_transform.basis.z
	var fwd2 := Vector2(fwd.x, fwd.z)
	if fwd2.length() < 0.01:
		return false
	var ang := rad_to_deg(absf(fwd2.angle_to(flat)))
	return ang <= _alert("scan_deg", SCAN_DEG) * 0.5

func _step_toward(d: Dictionary, focus: Vector3, speed: float, delta: float) -> void:
	var n: Node3D = d.node
	var t3 := Vector3(focus.x, _alt(focus.y), focus.z)
	var to := t3 - n.global_position
	var dist := to.length()
	if dist > 0.05:
		n.global_position += to / dist * minf(dist, speed * delta)
		if dist > 0.3:
			n.look_at(n.global_position + to, Vector3.UP)

func _move(d: Dictionary, delta: float, p: Vector3) -> void:
	var n: Node3D = d.node
	var here := n.global_position
	var ahead := _flat(here, p)
	var speed: float = d.speed
	if search_left > 0.0:
		speed = float(cfg.get("search_speed", 2.5))
	elif ahead > float(cfg.get("catchup_beyond_m", 26.0)):
		speed = d.catchup
	if boost_left > 0.0 and search_left <= 0.0:
		speed += float(cfg.get("boost", 3.5))
	var step := speed * delta
	while step > 0.0:
		var target: Vector3 = trail[d.crumb] if d.crumb < trail.size() else p
		var t3 := Vector3(target.x, _alt(target.y), target.z)
		var to := t3 - n.global_position
		var dist := to.length()
		if dist <= step:
			n.global_position = t3
			step -= dist
			if d.crumb < trail.size():
				d.crumb += 1
			else:
				break
		else:
			n.global_position += to / dist * step
			step = 0.0
	n.global_position.y += sin(bob * 3.0 + float(drones.find(d))) * 0.004
	var face := Vector3(p.x, n.global_position.y, p.z)
	if face.distance_to(n.global_position) > 0.3:
		n.look_at(face, Vector3.UP)

func _sees(from: Vector3) -> bool:
	if los_override >= 0:
		return los_override == 1
	var space := player.get_world_3d().direct_space_state if player.is_inside_tree() else null
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(from, player.global_position + Vector3(0, 1.0, 0))
	q.collision_mask = 1
	if player is CollisionObject3D:
		q.exclude = [player.get_rid()]
	return space.intersect_ray(q).is_empty()

func _alt(ground_y: float) -> float:
	return ground_y + float(cfg.get("altitude", 3.4))

static func _ground(v: Vector3) -> Vector3:
	return Vector3(v.x, maxf(0.0, v.y - 0.5), v.z)

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
