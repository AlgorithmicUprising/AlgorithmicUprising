extends RefCounted
## M1 (Nov 19 2026): the Yard dressed derelict for P.1, the dawn lighting preset, and the two story screens on the
## arcade: the Zero Score marquee board and the dead CRT in the window (where the VOICE comes from).
## Everything here is visual only (no collision), built in code, and removed again when story mode ends, so free
## roam is unchanged. Script: "Weeds through cracked concrete, a bowl half full of leaves and plastic bags, a rusted
## rail, a quarter pipe with its coping peeling. The sky is pink and already too bright."

const LIME := Color("c8ff3a")
const MARQUEE := Vector3(32.0, 8.0, -6.98)     # arcade_exterior.gd: marquee art centre (FACE + 0.72)
const CRT := Vector3(58.0, 1.62, -7.45)        # inside the west ground-floor window (x 58)
const BILLBOARD := Vector3(110.0, 26.0, -20.0)
## The Glass Row tower billboard (Fahrenheit everywhere, Nov 19 2026). The morning cycle matches the intro video's
## shots 3 and 4 (HIGH 108°F, the Sunburn Open ad, $500,000), so the game picks up the same morning.
const BB_FORECAST := "GOOD MORNING, GLITCHPORT  ·  HEAT DOME · DAY 9  ·  HIGH 108°F\nComfort tiers available for subscribers.  COMFORT, DELIVERED."
const BB_AD := "THE SUNBURN OPEN  ·  GLASS ROW  ·  QUALIFIERS SATURDAY\nGRAND PRIZE: $500,000  ·  FIVE DAYS."
const BB_EMERGENCY := "LEVEL FOUR HEAT EMERGENCY  ·  108°F\nGrid Priority Schedule active. Cooling centers closed. Stay comfortable."
const BB_POSTPONED := "NOTICE: The Sunburn Open qualifiers are postponed\nuntil the Heat Emergency ends. Dusk Dynamics thanks you for your patience."
const BB_CYCLE_S := 7.0
const SERA_BLUE := Color("9fd8ff")
const DAWN := {
	"sky_top": Color("e58fb0"), "sky_horizon": Color("ffd2a1"), "ground_horizon": Color("f0b48a"), "ground_bottom": Color("6a5348"),
	"ambient": Color("9a8a9e"), "ambient_energy": 0.3, "sun_rot": Vector3(-26, 95, 0), "sun_color": Color("ffc29a"), "sun_energy": 1.15,
}

static func build(world: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "DerelictDressing"
	world.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1119
	# bowl floor: leaves and plastic bags (floor top y = -3.0)
	var leaves: Array = []
	var bags: Array = []
	for i in 70:
		var p := Vector3(rng.randf_range(-55.0, -41.0), -2.985, rng.randf_range(39.0, 61.0))
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)
		if i % 3 == 0:
			bags.append(t.scaled_local(Vector3(rng.randf_range(0.8, 1.6), 1.0, rng.randf_range(0.8, 1.4))))
		else:
			leaves.append(t)
	_multi(root, "BowlLeaves", BoxMesh.new(), Vector3(0.22, 0.015, 0.14), leaves, Color("7a4f22"))
	_multi(root, "BowlBags", BoxMesh.new(), Vector3(0.38, 0.02, 0.3), bags, Color("dcd8cf"))
	# weeds through the cracks, and the cracks themselves, across the skate yard and plaza
	var weeds: Array = []
	var cracks: Array = []
	for i in 90:
		var p := Vector3(rng.randf_range(-78.0, -20.0), 0.0, rng.randf_range(-40.0, 26.0))
		if _near_kit(p):
			continue
		if i % 2 == 0:
			for k in 3:
				var w := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)), p + Vector3(rng.randf_range(-0.2, 0.2), 0.12, rng.randf_range(-0.2, 0.2)))
				weeds.append(w)
		else:
			cracks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0, 0.004, 0)).scaled_local(Vector3(rng.randf_range(1.0, 3.5), 1.0, 1.0)))
	_multi(root, "Weeds", BoxMesh.new(), Vector3(0.05, 0.26, 0.16), weeds, Color("5f7a2a"))
	_multi(root, "Cracks", BoxMesh.new(), Vector3(1.0, 0.006, 0.05), cracks, Color("2a2523"))
	# rust on the practice rail (GrindRail, x -55.5..-48.5 at z 8, top 0.30 m): patches just proud of the tube
	var rust: Array = []
	for i in 9:
		rust.append(Transform3D(Basis(), Vector3(-55.2 + i * 0.8 + rng.randf_range(-0.2, 0.2), 0.276, 8.0)))
	_multi(root, "RailRust", BoxMesh.new(), Vector3(0.28, 0.058, 0.058), rust, Color("8a4a22"))
	# the arcade: doors chained, marquee dead under dust
	var chain := Color("9a9a96")
	for s in [-1.0, 1.0]:
		var bar := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(8.6, 0.09, 0.09)
		bar.mesh = m
		bar.material_override = _mat(chain)
		bar.position = Vector3(32.0, 2.6, -7.36)
		bar.rotation.z = s * 0.36
		bar.name = "DoorChain"
		root.add_child(bar)
	_box(root, "Padlock", Vector3(32.0, 2.6, -7.28), Vector3(0.3, 0.36, 0.14), Color("b08a3a"))
	_box(root, "MarqueeDust", MARQUEE + Vector3(0, 0, 0.03), Vector3(10.7, 1.72, 0.03), Color("1d1a1c"))
	var board := Label3D.new()
	board.name = "ZeroScoreMarquee"
	board.text = ""
	board.font_size = 150
	board.pixel_size = 0.0068
	board.outline_size = 24
	board.modulate = LIME
	board.outline_modulate = Color(0.05, 0.12, 0.02, 1.0)
	board.position = MARQUEE + Vector3(0, 0, 0.07)
	board.no_depth_test = false
	board.shaded = false
	root.add_child(board)
	# the dead CRT in the window: a set, a dark screen, and a face that is two dots and a line
	_box(root, "CrtSet", CRT, Vector3(0.82, 0.64, 0.5), Color("3a3633"))
	var screen := MeshInstance3D.new()
	screen.name = "CrtScreen"
	var q := QuadMesh.new()
	q.size = Vector2(0.62, 0.46)
	screen.mesh = q
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("0c140c")
	sm.emission_enabled = true
	sm.emission = Color(0.16, 0.32, 0.05)
	sm.emission_energy_multiplier = 0.0
	screen.material_override = sm
	screen.position = CRT + Vector3(0, 0.02, 0.255)
	root.add_child(screen)
	var face := Label3D.new()
	face.name = "CrtFace"
	face.text = "•   •\n___"
	face.font_size = 64
	face.pixel_size = 0.004
	face.modulate = LIME
	face.outline_size = 0
	face.shaded = false
	face.position = CRT + Vector3(0, 0.03, 0.262)
	face.visible = false
	root.add_child(face)
	# P.1 v2: every Zero text makes the window CRT flicker a 0.2 s lime dot, even before the reveal (a clue)
	var dot := Label3D.new()
	dot.name = "CrtDot"
	dot.text = "•"
	dot.font_size = 48
	dot.pixel_size = 0.004
	dot.modulate = LIME
	dot.outline_size = 0
	dot.shaded = false
	dot.position = CRT + Vector3(0, 0.02, 0.263)
	dot.visible = false
	root.add_child(dot)
	# the Glass Row billboard on the skyline (script: EXT. THE YARD - DAWN)
	var bb := Label3D.new()
	bb.name = "GlassRowBillboard"
	bb.text = BB_FORECAST
	bb.set_meta("mode", "cycle")
	bb.font_size = 220
	bb.pixel_size = 0.02
	bb.outline_size = 30
	bb.modulate = Color("9fe8ff")
	bb.outline_modulate = Color(0.02, 0.05, 0.1, 1.0)
	bb.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	bb.shaded = false
	bb.position = BILLBOARD
	root.add_child(bb)
	return root

## Lights the CRT (talking) or dims it. face = the faint face is drawn (after the reveal). blip = the short dot that
## flickers with each Zero text.
static func crt(root: Node3D, talking: bool, face: bool, blip := false) -> void:
	if root == null:
		return
	var screen: MeshInstance3D = root.get_node_or_null("CrtScreen")
	if screen != null:
		(screen.material_override as StandardMaterial3D).emission_energy_multiplier = 1.0 if talking else (0.55 if blip else (0.35 if face else 0.0))
	var dot: Label3D = root.get_node_or_null("CrtDot")
	if dot != null:
		dot.visible = blip and not face and not talking
	var f: Label3D = root.get_node_or_null("CrtFace")
	if f != null:
		f.visible = face
		f.modulate.a = 1.0 if talking else 0.45

static func marquee(root: Node3D, text: String) -> void:
	if root == null:
		return
	var b: Label3D = root.get_node_or_null("ZeroScoreMarquee")
	if b != null:
		b.text = text.replace("\n", "  ")

## The tower billboard. mode "cycle" alternates the forecast and the Sunburn Open ad (billboard_tick); a fixed text
## (the heat emergency, the postponement) stops the cycle.
static func billboard(root: Node3D, text: String, mode := "fixed", color := Color("9fe8ff")) -> void:
	if root == null:
		return
	var bb: Label3D = root.get_node_or_null("GlassRowBillboard")
	if bb == null:
		return
	bb.text = text
	bb.modulate = color
	bb.set_meta("mode", mode)

static func billboard_text(root: Node3D) -> String:
	var bb: Label3D = root.get_node_or_null("GlassRowBillboard") if root != null else null
	return bb.text if bb != null else ""

static func billboard_tick(root: Node3D, clock: float) -> void:
	var bb: Label3D = root.get_node_or_null("GlassRowBillboard") if root != null else null
	if bb == null or str(bb.get_meta("mode", "fixed")) != "cycle":
		return
	var ad := int(clock / BB_CYCLE_S) % 2 == 1
	bb.text = BB_AD if ad else BB_FORECAST
	bb.modulate = Color("ffb36b") if ad else Color("9fe8ff")

## CINEMATIC P.3: the Warden welfare drone. Small, white, rounded, a friendly blue smiley on a round screen, a hatch
## with a soft restraint net folded inside, and a blue scanning light. Built in code (no assets), visual only.
static func welfare_drone(root: Node3D) -> Node3D:
	var d := Node3D.new()
	d.name = "WelfareDrone"
	root.add_child(d)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var sm := SphereMesh.new()
	sm.radius = 0.42
	sm.height = 0.7
	body.mesh = sm
	var white := _mat(Color("f2f4f7"))
	white.roughness = 0.35
	body.material_override = white
	d.add_child(body)
	for side in [-1.0, 1.0]:
		var rotor := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.22
		cm.height = 0.03
		rotor.mesh = cm
		rotor.material_override = _mat(Color("c9ced6"))
		rotor.position = Vector3(side * 0.5, 0.22, 0)
		d.add_child(rotor)
	var face := Label3D.new()
	face.name = "Smiley"
	face.text = "•  •\n\\__/"
	face.font_size = 64
	face.pixel_size = 0.0045
	face.modulate = Color("3aa8ff")
	face.outline_size = 0
	face.shaded = false
	face.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	face.position = Vector3(0, 0.02, 0.0)
	face.no_depth_test = true
	d.add_child(face)
	var net := MeshInstance3D.new()
	net.name = "Net"
	var nm := CylinderMesh.new()
	nm.top_radius = 0.08
	nm.bottom_radius = 0.95
	nm.height = 1.0
	net.mesh = nm
	var netm := _mat(Color(1.0, 1.0, 1.0, 0.35))
	netm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	netm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net.material_override = netm
	net.position = Vector3(0, -0.75, 0)
	net.visible = false
	d.add_child(net)
	var beam := MeshInstance3D.new()
	beam.name = "ScanBeam"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.04
	bm.bottom_radius = 0.9
	bm.height = 3.0
	beam.mesh = bm
	var beamm := _mat(Color(0.35, 0.7, 1.0, 0.22))
	beamm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beamm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beamm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beamm
	beam.position = Vector3(0, -1.6, 0)
	beam.visible = false
	d.add_child(beam)
	var light := OmniLight3D.new()
	light.name = "ScanLight"
	light.light_color = Color("5ab8ff")
	light.light_energy = 0.0
	light.omni_range = 4.0
	light.position = Vector3(0, -0.6, 0)
	d.add_child(light)
	return d

## MISSION P.2 Run: a grey Warden enforcement drone. Larger, boxy, no smile: one red eye bar. Same Net / ScanBeam /
## ScanLight children as the welfare drone so drone_scan() and drone_net() work on both. Visual only.
static func enforcement_drone(root: Node3D) -> Node3D:
	var d := Node3D.new()
	d.name = "EnforcementDrone"
	root.add_child(d)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var bx := BoxMesh.new()
	bx.size = Vector3(1.1, 0.45, 0.8)
	body.mesh = bx
	body.material_override = _mat(Color("6c7178"))
	d.add_child(body)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var rotor := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.26
			cm.bottom_radius = 0.26
			cm.height = 0.03
			rotor.mesh = cm
			rotor.material_override = _mat(Color("3a3d42"))
			rotor.position = Vector3(sx * 0.62, 0.26, sz * 0.46)
			d.add_child(rotor)
	var eye := Label3D.new()
	eye.name = "Eye"
	eye.text = "====="
	eye.font_size = 48
	eye.pixel_size = 0.005
	eye.modulate = Color("ff3b1f")
	eye.shaded = false
	eye.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	eye.no_depth_test = true
	d.add_child(eye)
	var net := MeshInstance3D.new()
	net.name = "Net"
	var nm := CylinderMesh.new()
	nm.top_radius = 0.1
	nm.bottom_radius = 1.1
	nm.height = 1.1
	net.mesh = nm
	var netm := _mat(Color(1.0, 0.9, 0.9, 0.35))
	netm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	netm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net.material_override = netm
	net.position = Vector3(0, -0.8, 0)
	net.visible = false
	d.add_child(net)
	var beam := MeshInstance3D.new()
	beam.name = "ScanBeam"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.05
	bm.bottom_radius = 1.0
	bm.height = 3.0
	beam.mesh = bm
	var beamm := _mat(Color(1.0, 0.3, 0.2, 0.18))
	beamm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beamm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beamm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beamm
	beam.position = Vector3(0, -1.6, 0)
	beam.visible = false
	d.add_child(beam)
	var light := OmniLight3D.new()
	light.name = "ScanLight"
	light.light_color = Color("ff5a3a")
	light.light_energy = 0.0
	light.omni_range = 4.0
	light.position = Vector3(0, -0.6, 0)
	d.add_child(light)
	return d

static func drone_scan(d: Node3D, on: bool) -> void:
	if d == null:
		return
	d.get_node("ScanBeam").visible = on
	(d.get_node("ScanLight") as OmniLight3D).light_energy = 1.6 if on else 0.0

static func drone_net(d: Node3D, on: bool) -> void:
	if d != null:
		d.get_node("Net").visible = on

## Swaps main's sky and sun to the dawn preset; returns what it replaced so restore() can put it back.
static func dawn(main: Node) -> Dictionary:
	var saved := {}
	for c in main.get_children():
		if c is WorldEnvironment and c.environment != null:
			var env: Environment = c.environment
			var proc := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
			if proc != null:
				saved["sky"] = [proc.sky_top_color, proc.sky_horizon_color, proc.ground_horizon_color, proc.ground_bottom_color]
				proc.sky_top_color = DAWN.sky_top
				proc.sky_horizon_color = DAWN.sky_horizon
				proc.ground_horizon_color = DAWN.ground_horizon
				proc.ground_bottom_color = DAWN.ground_bottom
			saved["ambient"] = [env.ambient_light_color, env.ambient_light_energy]
			env.ambient_light_color = DAWN.ambient
			env.ambient_light_energy = DAWN.ambient_energy
			saved["env"] = c
		elif c is DirectionalLight3D:
			saved["sun"] = [c, c.rotation_degrees, c.light_color, c.light_energy]
			c.rotation_degrees = DAWN.sun_rot
			c.light_color = DAWN.sun_color
			c.light_energy = DAWN.sun_energy
	saved["preset"] = "dawn"
	return saved

static func restore(saved: Dictionary) -> void:
	if saved.has("env") and is_instance_valid(saved.env):
		var env: Environment = saved.env.environment
		if saved.has("sky") and env.sky != null:
			var proc := env.sky.sky_material as ProceduralSkyMaterial
			proc.sky_top_color = saved.sky[0]
			proc.sky_horizon_color = saved.sky[1]
			proc.ground_horizon_color = saved.sky[2]
			proc.ground_bottom_color = saved.sky[3]
		env.ambient_light_color = saved.ambient[0]
		env.ambient_light_energy = saved.ambient[1]
	if saved.has("sun") and is_instance_valid(saved.sun[0]):
		saved.sun[0].rotation_degrees = saved.sun[1]
		saved.sun[0].light_color = saved.sun[2]
		saved.sun[0].light_energy = saved.sun[3]

static func _near_kit(p: Vector3) -> bool:
	# keep the dressing off the rails and the quarter-pipe faces so nothing pokes through the riding surfaces
	return (absf(p.z - 8.0) < 1.5 and p.x > -57.0 and p.x < -47.0) or (absf(p.z + 12.0) < 4.0 and p.x < -48.0)

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

static func _box(root: Node3D, name: String, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = _mat(c)
	mi.position = pos
	root.add_child(mi)
	return mi

static func _multi(root: Node3D, name: String, mesh: BoxMesh, size: Vector3, xforms: Array, c: Color) -> void:
	mesh.size = size
	mesh.material = _mat(c)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
