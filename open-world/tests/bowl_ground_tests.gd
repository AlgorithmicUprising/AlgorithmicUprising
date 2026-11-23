extends RefCounted
## The bowl deck is a real floor, P.1 can walk to it from every checkpoint, and a pause hides the kick-up prompt.

const Bowl = preload("res://scripts/skate_bowl.gd")
const JsonFile = preload("res://scripts/json_file.gd")

var t: Node

func run(host: Node) -> void:
	t = host
	_deck_samples()
	var main = load("res://scenes/main.tscn").instantiate()
	t.add_child(main)
	await t.frames(20)
	await _reach(main)
	await _spawns(main)
	_pause(main)
	main.queue_free()
	await t.frames(2)

func ok(cond: bool, name: String) -> void:
	t.expect(cond, name)

func frames(n: int) -> void:
	await t.frames(n)

## The visual deck, outside the pool, has a collider at the surface. The old shell answered at y = -0.5.
func _deck_samples() -> void:
	var host := Node3D.new()
	t.add_child(host)
	var bowl: Node3D = Bowl.new()
	bowl.position = Vector3.ZERO
	host.add_child(bowl)
	await frames(2)
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	var lip: float = Bowl.HX + float(bowl.lip_u())
	var deep: float = Bowl.HZ + float(bowl.lip_u())
	var bad := 0
	var checked := 0
	var noted := ""
	var x := Bowl.OUTER_MIN_X + 1.0
	while x < Bowl.OUTER_MAX_X:
		var z := Bowl.OUTER_MIN_Z + 1.0
		while z < Bowl.OUTER_MAX_Z:
			var on_deck: bool = bowl.sdf(x, z) > lip + 0.35
			if on_deck:
				checked += 1
				var hit: Dictionary = _ray(space, Vector3(x, 2.0, z), -3.0)
				var y: float = 999.0 if hit.is_empty() else float(hit.position.y)
				# A coping or a shell triangle can answer above the deck. The floor under it is the box.
				if y > 0.2:
					hit = _ray(space, Vector3(x, 0.15, z), -3.0)
					y = 999.0 if hit.is_empty() else float(hit.position.y)
				if y < -0.05 or y > 0.2:
					bad += 1
					var who := "?" if hit.is_empty() else str(hit.collider.name)
					if noted.length() < 220:
						noted += " (%.1f,%.1f y=%.2f %s)" % [x, z, y, who]
			z += 4.0
		x += 4.0
	ok(checked > 20 and bad == 0, "deck: the surround has a floor at y = 0 (%d samples, %d low or missing)%s" % [checked, bad, noted])
	var south := _ray_y(space, Vector3(14.0, 2.0, -20.0), -3.0)
	ok(south > -0.05 and south < 0.25, "deck: the wide south shoulder, off the old narrow approach, is a floor (y %.2f)" % south)
	host.queue_free()

func _reach(main) -> void:
	var player = main.player
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	player.bounds_enabled = true
	var lip := Vector3(-48.0, 0.4, 41.0)
	var book: Dictionary = _dict("res://data/missions/p1_practice_run.json")
	var spawns: Dictionary = book.get("spawns", {})
	for key in ["yard", "quarter", "rail", "line"]:
		var s: Array = spawns[key]
		var spot := Vector3(float(s[0]), float(s[1]), float(s[2]))
		await _settle(player, spot)
		var stood: bool = player.is_on_floor() and player.global_position.y > -0.6 and player.global_position.y < 0.4
		ok(stood, "p1 %s: standing on the ground at the checkpoint (%s)" % [key, player.global_position])
		# The funbox sits on the straight line from the quarter checkpoint. Go around it.
		var min_y: float = player.global_position.y
		await _walk(player, Vector3(-40.0, 0.4, minf(spot.z, 6.0)), 400)
		min_y = minf(min_y, float(player.get_meta("walk_min_y", min_y)))
		await _walk(player, Vector3(-40.0, 0.4, 30.0), 500)
		min_y = minf(min_y, float(player.get_meta("walk_min_y", min_y)))
		var end: Vector3 = await _walk(player, lip, 400)
		min_y = minf(min_y, float(player.get_meta("walk_min_y", min_y)))
		var reached: bool = end.distance_to(Vector3(lip.x, end.y, lip.z)) < 3.5 and end.y > -0.4 and min_y > -0.8
		ok(reached, "p1 %s: a walk reaches the bowl deck without falling through (%s, lowest %.2f)" % [key, end, min_y])

func _spawns(main) -> void:
	for id in ["glass_row_edge", "solar_arcade_dark", "stillwater_flats", "cold_row"]:
		main.districts.arm(id)
		main.districts.request(id)
	var ready := false
	for _i in 300:
		await t.get_tree().physics_frame
		ready = true
		for id in ["glass_row_edge", "solar_arcade_dark", "stillwater_flats", "cold_row"]:
			if main.districts.state(id) != "ready":
				ready = false
		if ready:
			break
	ok(ready, "spawns: the districts with checkpoints are loaded")
	var space: PhysicsDirectSpaceState3D = main.world_sim.get_world_3d().direct_space_state
	var spots: Array = _all_spots()
	var missing: Array[String] = []
	for spot in spots:
		var at: Vector3 = spot.at
		var y := _ray_y(space, at + Vector3(0.0, 1.2, 0.0), at.y - 2.5)
		if y > at.y + 0.4 or y < at.y - 1.6:
			missing.append("%s %s hit %.2f" % [spot.id, at, y])
	ok(missing.is_empty(), "spawns: every spawn and checkpoint has ground under it (%s)" % [missing])

func _pause(main) -> void:
	var hud = load("res://scripts/story/story_hud.gd").new()
	hud.name = "PausePromptProbe"
	main.add_child(hud)
	main.story.hud = hud
	hud.prompt("KICK UP    Shift")
	ok(hud.prompt_panel.visible and "KICK UP" in hud.prompt_label.text, "pause: the kick-up prompt is showing")
	main.flow.set_paused(true)
	ok(not hud.prompt_panel.visible, "pause: the kick-up prompt hides under the pause menu")
	main.flow.set_paused(false)
	ok(hud.prompt_panel.visible and hud.prompt_held == "KICK UP    Shift", "pause: the kick-up prompt comes back")
	hud.prompt("")

func _settle(player, spot: Vector3) -> void:
	player.skating = false
	player.ramp_mode = ""
	player.ramp = null
	player.pipe_air = false
	player.grind = null
	player.velocity = Vector3.ZERO
	player.external_move = Vector2.ZERO
	player.global_position = spot + Vector3(0.0, 0.8, 0.0)
	player.last_safe_valid = false
	for _i in 40:
		await t.get_tree().physics_frame
		if player.is_on_floor():
			break

func _walk(player, target: Vector3, limit: int) -> Vector3:
	player.skating = false
	player.external_move_active = true
	var min_y: float = player.global_position.y
	for _i in limit:
		var to := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
		if to.length() < 2.2:
			break
		var d: Vector3 = to.normalized()
		var axes: Array = player._camera_flat_axes()
		player.external_move = Vector2(d.dot(axes[1]), d.dot(axes[0]))
		await t.get_tree().physics_frame
		min_y = minf(min_y, player.global_position.y)
		if player.global_position.y < -2.0:
			break
	player.set_meta("walk_min_y", min_y)
	player.external_move = Vector2.ZERO
	return player.global_position

func _ray_y(space: PhysicsDirectSpaceState3D, origin: Vector3, dest_y: float) -> float:
	var hit: Dictionary = _ray(space, origin, dest_y)
	if hit.is_empty():
		return 999.0
	return float(hit.position.y)

func _ray(space: PhysicsDirectSpaceState3D, origin: Vector3, dest_y: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origin, Vector3(origin.x, dest_y, origin.z))
	q.collision_mask = 1
	return space.intersect_ray(q)

func _all_spots() -> Array:
	var out: Array = []
	var p1: Dictionary = _dict("res://data/missions/p1_practice_run.json")
	var spawns: Dictionary = p1.get("spawns", {})
	for key in spawns:
		var s: Array = spawns[key]
		out.append({"id": "p1:%s" % str(key), "at": Vector3(float(s[0]), float(s[1]), float(s[2]))})
	var p2: Dictionary = _dict("res://data/missions/p2_run.json")
	var p2spawn: Dictionary = p2.get("spawn", {})
	var p2s: Array = p2spawn.get("pos", [])
	if p2s.size() >= 3:
		out.append({"id": "p2:spawn", "at": Vector3(float(p2s[0]), float(p2s[1]), float(p2s[2]))})
	for cp in p2.get("checkpoints", []):
		var point: Dictionary = cp
		var pos: Array = point.get("pos", [])
		if pos.size() >= 3:
			out.append({"id": "p2:%s" % str(point.get("id", "")), "at": Vector3(float(pos[0]), float(pos[1]), float(pos[2]))})
	var p3: Dictionary = _dict("res://data/missions/p3_power_on.json")
	var p3spawn: Dictionary = p3.get("spawn", {})
	var p3s: Array = p3spawn.get("pos", [])
	if p3s.size() >= 3:
		out.append({"id": "p3:spawn", "at": Vector3(float(p3s[0]), float(p3s[1]), float(p3s[2]))})
	var fuses: Dictionary = p3.get("fuses", {})
	for key in fuses:
		var fuse: Dictionary = fuses[key]
		var reset: Array = fuse.get("reset", [])
		if reset.size() >= 3:
			out.append({"id": "p3:%s" % str(key), "at": Vector3(float(reset[0]), float(reset[1]), float(reset[2]))})
	var act: Dictionary = _dict("res://data/missions/act1_scenes.json")
	var scenes: Dictionary = act.get("scenes", {})
	for key in scenes:
		var s: Array = scenes[key].get("spawn", [])
		if s.size() >= 3:
			out.append({"id": "act1:%s" % str(key), "at": Vector3(float(s[0]), float(s[1]), float(s[2]))})
	return out

func _dict(path: String) -> Dictionary:
	var parsed: Variant = JsonFile.read(path)
	var out: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		out.assign(parsed)
	return out
