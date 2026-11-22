extends RefCounted
## The round bowl (continuous normals, a ride down through the flat and up the far wall) and the Glitchport
## bounds (teleport to the open edges, skate into the plaza curb and the fence-gap seam, kill-plane recovery).

const Bowl = preload("res://scripts/skate_bowl.gd")

var t: Node

func run(host: Node) -> void:
	t = host
	_normals()
	await _ride()
	await _bounds()

func ok(cond: bool, name: String) -> void:
	t.expect(cond, name)

func frames(n: int) -> void:
	await t.frames(n)

func _normals() -> void:
	var host := Node3D.new()
	t.add_child(host)
	var bowl: Node3D = Bowl.new()
	bowl.position = Vector3.ZERO
	host.add_child(bowl)
	var lip: float = bowl.lip_u()
	var radius: float = bowl.radius()
	var flat: Dictionary = bowl.sample(Vector3(0.0, 0.0, 0.0))
	ok(str(flat.kind) == "flat" and absf(float(flat.y) - Bowl.FLOOR_Y) < 0.001 and flat.normal.dot(Vector3.UP) > 0.999, "bowl: the centre is a flat bottom at y = %.2f" % Bowl.FLOOR_Y)
	var prev := Vector3.UP
	var worst := 0.0
	var formula := true
	var on_wall := false
	for i in 16:
		var u := lip * float(i) / 15.0
		var s: Dictionary = bowl.sample(Vector3(Bowl.HX + u, 0.0, 0.0))
		if str(s.kind) == "wall":
			if on_wall:
				worst = maxf(worst, rad_to_deg(prev.angle_to(s.normal)))
			else:
				worst = maxf(worst, rad_to_deg(Vector3.UP.angle_to(s.normal)))
			on_wall = true
			var th := asin(clampf(u / radius, 0.0, sin(deg_to_rad(Bowl.CLIMB_DEG))))
			var expect := (-sin(th) * Vector3.RIGHT + Vector3.UP * cos(th)).normalized()
			formula = formula and s.normal.dot(expect) > 0.999
		prev = s.normal
	ok(on_wall and worst < 12.0 and formula, "bowl: normals up the east wall stay continuous and match the quarter-pipe profile (worst step %.2f deg)" % worst)
	var ring: Array = bowl.debug_ring(lip * 0.5)
	var around := 0.0
	var closed := true
	prev = ring[ring.size() - 1].normal
	for s in ring:
		var step := rad_to_deg(prev.angle_to(s.normal))
		around = maxf(around, step)
		closed = closed and str(s.kind) == "wall" and absf(float(s.u) - lip * 0.5) < 0.08
		prev = s.normal
	ok(ring.size() > 40 and around < 20.0 and closed, "bowl: normals around the pool stay continuous (worst step %.2f deg, %d samples)" % [around, ring.size()])
	var deck: Dictionary = bowl.sample(Vector3(0.0, 0.0, -20.0))
	ok(str(deck.kind) == "deck" and absf(float(deck.y)) < 0.001 and deck.normal.dot(Vector3.UP) > 0.999, "bowl: the surround is a flat deck")
	host.queue_free()

func _ride() -> void:
	var host := Node3D.new()
	t.add_child(host)
	# Clear of the yard, which an earlier test may still have in the tree.
	const SHIFT := Vector3(0.0, 0.0, 320.0)
	var bowl: Node3D = Bowl.new()
	bowl.position = SHIFT
	host.add_child(bowl)
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = SHIFT + Vector3(0.0, 0.6, -22.0)
	player.bounds_enabled = false
	host.add_child(player)
	await frames(8)
	Engine.time_scale = 1.0
	player.skating = true
	player.camera_yaw = PI
	player.external_move_active = true
	player.velocity = Vector3(0.0, 0.0, 9.0)
	var saw := false
	var min_y := 10.0
	var max_after := -10.0
	var bottomed := false
	var max_step := 0.0
	var second_step := 0.0
	var prev: Vector3 = player.global_position
	var fell := false
	for i in 700:
		var axes: Array = player._camera_flat_axes()
		var dir := Vector3(0.0, 0.0, 1.0)
		player.external_move = Vector2(dir.dot(axes[1]), dir.dot(axes[0]))
		if player.ramp_mode != "bowl":
			player.velocity = Vector3(0.0, player.velocity.y, 9.0)
		await t.get_tree().physics_frame
		var p: Vector3 = player.global_position
		var step: float = p.distance_to(prev)
		if saw and step > max_step:
			second_step = max_step
			max_step = step
		elif saw and step > second_step:
			second_step = step
		prev = p
		if p.y < -4.2:
			fell = true
		if player.ramp_mode == "bowl":
			saw = true
		if p.y < -2.2:
			bottomed = true
			min_y = minf(min_y, p.y)
		elif bottomed:
			max_after = maxf(max_after, p.y)
		if bottomed and p.y > -0.4 and i > 40:
			break
	ok(saw, "bowl: riding the deck into the pool uses the transition")
	ok(bottomed and min_y < -2.2 and min_y > -4.0, "bowl: the ride reaches the flat bottom (y %.2f) without falling through" % min_y)
	ok(max_after > -2.0, "bowl: the ride climbs the far wall (back up to y %.2f)" % max_after)
	ok(not fell and second_step < 0.7 and max_step < 1.2, "bowl: the ride does not snag or jitter (crest %.3f m, next %.3f m)" % [max_step, second_step])
	player.queue_free()
	host.queue_free()
	await frames(2)

func _bounds() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	t.add_child(main)
	await frames(20)
	var world: Node = main.world_sim
	ok(world.get_node_or_null("SkateBowl") != null and world.get_node_or_null("SkateBowl/BowlFloor") != null, "bounds: the yard has the round bowl")
	ok(world.get_node_or_null("PlazaCurbNorthEast") != null and world.get_node_or_null("SeamCurbNorth") != null and world.get_node_or_null("ArcadeShellWest") != null, "bounds: plaza curb, seam curb and arcade shell are in the world")
	var player = main.player
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	# Stand, then get thrown off the plaza's old open north side.
	await _settle(player, Vector3(-42.0, 0.6, 2.0))
	var safe: Vector3 = player.global_position
	player.last_safe_position = safe
	player.last_safe_valid = true
	player.global_position = Vector3(168.0, 0.8, -18.0)
	player.velocity = Vector3(0.0, 0.0, -6.0)
	await frames(8)
	ok(player.global_position.distance_to(safe) < 2.0 and player.global_position.y > -2.0, "bounds: teleporting off the plaza north edge returns to the last safe spot (%s)" % player.global_position)
	# Kill plane, same contract.
	player.last_safe_position = safe
	player.last_safe_valid = true
	player.global_position = safe + Vector3(0.0, -30.0, 0.0)
	await frames(4)
	ok(player.global_position.distance_to(safe) < 2.0 and player.global_position.y > -2.0, "bounds: dropping through the kill plane recovers to the last safe spot")
	# Corners of the yard stay put.
	for spot in [Vector3(-70.0, 0.8, -70.0), Vector3(60.0, 0.8, 70.0), Vector3(52.0, 0.8, 92.0), Vector3(-48.0, 1.2, 28.0)]:
		await _settle(player, spot)
		var stayed: bool = player.global_position.distance_to(Vector3(spot.x, player.global_position.y, spot.z)) < 3.0 and player.global_position.y > -2.0
		ok(stayed, "bounds: standing at %s stays in the world (%s)" % [spot, player.global_position])
	# Into the bowl: this must NOT snap back to the yard spawn. The floor is below y = -2.
	await _settle(player, Vector3(-48.0, 0.8, 36.0))
	player.velocity = Vector3(0.0, 0.0, 8.0)
	var deep := false
	for _i in 180:
		if player.ramp_mode != "bowl":
			player.velocity.z = 8.0
		await t.get_tree().physics_frame
		if player.global_position.y < -2.0 and player.global_position.distance_to(Vector3(-48.0, player.global_position.y, 50.0)) < 18.0:
			deep = true
			break
	ok(deep and player.global_position.y > -5.0, "bounds: dropping into the yard bowl stays in the bowl (%s)" % player.global_position)
	# Glass Row and the dark arcade, then skate at the edges.
	main.districts.arm("glass_row_edge")
	main.districts.request("glass_row_edge")
	main.districts.arm("solar_arcade_dark")
	main.districts.request("solar_arcade_dark")
	var ready := false
	for _i in 240:
		await t.get_tree().physics_frame
		if main.districts.state("glass_row_edge") == "ready" and main.districts.state("solar_arcade_dark") == "ready":
			ready = true
			break
	ok(ready, "bounds: glass row and the dark arcade load for the edge check (%s / %s)" % [main.districts.state("glass_row_edge"), main.districts.state("solar_arcade_dark")])
	await _settle(player, Vector3(168.0, 0.6, 8.0))
	var north := await _push(player, Vector3(0.0, 0.0, -1.0), 200)
	ok(north.y > -1.0 and north.z > -0.2 and north.x > 150.0 and north.x < 180.0, "bounds: skating north off the plaza hits the city edge and stays up (%s)" % north)
	await _settle(player, Vector3(82.5, 0.6, 29.0))
	var seam := await _push(player, Vector3(0.0, 0.0, -1.0), 160)
	ok(seam.y > -1.0 and seam.z > 20.0 and seam.x < 90.0, "bounds: skating north of the fence gap stays on the seam (%s)" % seam)
	await _settle(player, Vector3(230.0, 0.6, -26.0))
	var inside: Vector3 = player.global_position
	player.global_position = Vector3(190.0, 0.6, -26.0)
	player.velocity = Vector3(-8.0, 0.0, 0.0)
	await frames(8)
	ok(player.global_position.distance_to(inside) < 4.0 and player.global_position.y > -2.0, "bounds: leaving the dark arcade toward Glitchport returns inside (%s)" % player.global_position)
	main.queue_free()
	await frames(2)

func _settle(player, spot: Vector3) -> void:
	player.ramp_mode = ""
	player.ramp = null
	player.pipe_air = false
	player.velocity = Vector3.ZERO
	player.external_move = Vector2.ZERO
	player.global_position = spot
	player.last_safe_valid = false
	await frames(25)
	if player.is_on_floor() or str(player.ramp_mode) != "":
		player.last_safe_position = player.global_position
		player.last_safe_yaw = player.rotation.y
		player.last_safe_valid = true

func _push(player, dir: Vector3, ticks: int) -> Vector3:
	player.external_move_active = true
	player.skating = true
	for _i in ticks:
		var axes: Array = player._camera_flat_axes()
		player.external_move = Vector2(dir.dot(axes[1]), dir.dot(axes[0]))
		await t.get_tree().physics_frame
		if player.global_position.y < -3.0:
			break
	player.external_move = Vector2.ZERO
	await frames(4)
	return player.global_position
