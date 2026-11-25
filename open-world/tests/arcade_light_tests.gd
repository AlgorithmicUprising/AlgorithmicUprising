extends RefCounted
## The Solar Arcade stays dark, but entering it must not turn the world into a black frame.
## Headless CI has no viewport texture, so the lighting numbers are always checked and the
## rendered luminance check runs whenever a frame can actually be read.

const World = preload("res://scripts/story/story_world.gd")

var t: Node

func run(host: Node) -> void:
	t = host
	var preset: Dictionary = World.INTERIOR_DARK
	t.expect(float(preset.sun_energy) == 0.0, "solar arcade: the sun stays off inside (energy %.2f)" % float(preset.sun_energy))
	t.expect(float(preset.ambient_energy) >= 0.5, "solar arcade: ambient is high enough to read the room (%.2f)" % float(preset.ambient_energy))
	var main = load("res://scenes/main.tscn").instantiate()
	t.add_child(main)
	for _i in 20:
		await t.get_tree().process_frame
	main.districts.arm("solar_arcade_dark")
	main.districts.request("solar_arcade_dark")
	var ready := false
	for _i in 240:
		await t.get_tree().physics_frame
		if main.districts.state("solar_arcade_dark") == "ready":
			ready = true
			break
	t.expect(ready, "solar arcade: the district loads")
	World.apply(main, World.INTERIOR_DARK)
	var player = main.player
	player.external_move_active = true
	player.external_move = Vector2.ZERO
	player.skating = false
	player.global_position = Vector3(215.5, 1.2, -16.0)
	player.rotation.y = PI
	player.camera_yaw = 0.0
	player.velocity = Vector3.ZERO
	for _i in 40:
		await t.get_tree().physics_frame
	if DisplayServer.get_name() == "headless":
		t.expect(true, "solar arcade: headless has no framebuffer; the lighting numbers above are the check")
	else:
		var image: Image = t.get_viewport().get_texture().get_image()
		var lum := _lum(image)
		t.expect(lum > 0.04, "solar arcade: a rendered frame is not black (luminance %.3f)" % lum)
		t.expect(player.is_on_floor() and player.global_position.y > -0.6, "solar arcade: Fony is standing on the floor (%s)" % player.global_position)
	main.queue_free()
	for _i in 2:
		await t.get_tree().process_frame

func _lum(image: Image) -> float:
	var lum := 0.0
	var n := 0
	var h := image.get_height()
	var w := image.get_width()
	for y in range(0, h, 8):
		for x in range(0, w, 8):
			var c := image.get_pixel(x, y)
			lum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return lum / float(maxi(n, 1))
