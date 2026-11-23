extends Node3D
## A1 glass_row_edge (Act I milestone M3, Nov 19 2026). Ships in its own pack (build/web/districts/glass_row_edge.pck),
## never in index.pck. Holds the whole of MISSION P.2 Run, built in code from main-pack blocks like the yard, so the
## pack stays tiny. World coordinates (registry origin 0, 0, 0); ground y = 0 like the Yard and the edge apron.
##
## Route (west to east): the east fence gap (x 80, z 26 .. 32, opened by the story) -> the service alley behind
## Glass Row (x 82 .. 126, z 22 .. 36), where a parked delivery van blocks the middle lane and forces the shortcut
## choice: (A) over the dumpster, onto the loading dock, along its grindable ledge and down the stair set, or
## (B) up the parking ramp under the drone camera and down the far side -> the plaza (x 126 .. 178, z 0 .. 50) with
## the boutique, the Silver-tier mister kiosk and early shoppers -> the stair set at the east end with the loose drain
## grate beside it, on the left riding east (the culvert back under the Yard's NE corner is a story transition).
## Zero's face hops between three street screens (bus shelter, parking meter, store window): see p2_run.gd.

const Blocks = preload("res://scripts/world_blocks.gd")
const Pieces = preload("res://assets/library/skate_park/park_pieces.gd")
const Palette = preload("res://scripts/palette.gd")

const CONCRETE := Color("8e9a97")
const ALLEY := Color("6f7472")
const GLASS := Color("9fd6e8")
const TOWER := Color("cfd8dc")
const BACKS := Color("7c6f6a")
const LIME := Color("c6ff3d")
const SERA_BLUE := Color("9fe8ff")
const GRATE := Vector3(165.0, 0.0, 15.4)

func _ready() -> void:
	set_meta("district_id", "glass_row_edge")
	_alley()
	_dock()
	_garage()
	_plaza()
	_stairs_and_drain()
	_screens()
	_skyline()

func _alley() -> void:
	# the alley floor from the pack edge (x 82) to the plaza, flush with the apron (top y = 0)
	Blocks.solid(self, "AlleyFloor", Vector3(104.0, -0.5, 29.0), Vector3(44.0, 1.0, 14.0), ALLEY, Vector3.ZERO, 0.04)
	# the back walls of Glass Row (north) and the garage block (south)
	Blocks.solid(self, "AlleyWallNorth", Vector3(104.0, 4.0, 21.7), Vector3(44.0, 8.0, 0.6), BACKS)
	Blocks.solid(self, "AlleyWallSouth", Vector3(104.0, 4.0, 36.3), Vector3(44.0, 8.0, 0.6), BACKS)
	for i in 7:
		Blocks.visual(self, "AlleyWindowN%d" % i, Vector3(88.0 + i * 5.2, 3.4, 22.08), Vector3(1.6, 1.1, 0.06), GLASS)
		Blocks.visual(self, "AlleyWindowS%d" % i, Vector3(88.0 + i * 5.2, 3.4, 35.92), Vector3(1.6, 1.1, 0.06), GLASS.darkened(0.2))
	Blocks.visual(self, "AlleyCorniceN", Vector3(104.0, 7.85, 22.05), Vector3(44.0, 0.22, 0.28), BACKS.lightened(0.08))
	Blocks.visual(self, "AlleyCorniceS", Vector3(104.0, 7.85, 35.95), Vector3(44.0, 0.22, 0.28), BACKS.lightened(0.08))
	for i in 6:
		Blocks.visual(self, "AlleyStain%d" % i, Vector3(86.0 + i * 7.0, 0.02, 29.0 + (i % 2) * 1.4), Vector3(2.2, 0.02, 0.9), Color("5b605e"))
	# the van in the middle lane: you cannot go straight through
	Blocks.solid(self, "DeliveryVan", Vector3(112.0, 1.3, 29.0), Vector3(9.0, 2.6, 4.6), Color("e8e4dc"))
	Blocks.visual(self, "VanStripe", Vector3(112.0, 1.6, 26.68), Vector3(8.6, 0.4, 0.02), SERA_BLUE)
	var van := Blocks.label(self, "DUSK DYNAMICS · COMFORT, DELIVERED.", Vector3(112.0, 2.1, 26.6), Color("2a3a44"), 22)
	van.name = "VanLabel"
	_van_shape(get_node("DeliveryVan"))
	var sign := Blocks.label(self, "GLASS ROW · SERVICE ALLEY", Vector3(90.0, 5.2, 22.1), Palette.LABEL, 34)
	sign.name = "AlleySign"
	# dumpster by the dock ramp ("over the dumpster")
	Blocks.solid(self, "Dumpster", Vector3(96.5, 0.7, 23.2), Vector3(2.6, 1.4, 1.6), Color("3f6a4a"))

func _dock() -> void:
	# (A) loading dock along the north wall: ramp up 1.2 m, a deck with a grindable south edge, a stair set down east
	Pieces.wedge(self, "DockRamp", Vector3(100.0, 0.0, 24.4), 0.0, 3.0, 1.2, 4.0, 0.0)
	Blocks.solid(self, "DockDeck", Vector3(112.0, 0.6, 24.4), Vector3(18.0, 1.2, 4.0), Color("8a8580"))
	var ledge = load("res://scenes/grind_rail.tscn").instantiate()
	ledge.name = "DockLedge"
	ledge.kind = "ledge"
	ledge.length = 16.0
	ledge.position = Vector3(112.0, 1.2, 26.35)
	add_child(ledge)
	Blocks.add_slope(self, "DockStairs", Vector3(124.6, 0.0, 24.4), Vector3(121.0, 1.2, 24.4), 4.0, Color("9a948c"))
	for i in 4:
		Blocks.visual(self, "DockStep%d" % i, Vector3(121.45 + i * 0.9, 1.05 - i * 0.3, 24.4), Vector3(0.9, 0.06, 4.0), Color("b5aea4"))
	var lbl := Blocks.label(self, "LOADING DOCK 3", Vector3(110.0, 3.4, 22.1), Palette.LABEL, 26)
	lbl.name = "DockSign"

func _garage() -> void:
	# (B) parking ramp along the south wall: up 2.4 m over 6 m, a deck, down 6 m; a drone camera watches the deck
	Pieces.wedge(self, "GarageRampUp", Vector3(102.0, 0.0, 33.6), 0.0, 6.0, 2.4, 4.4, 0.0)
	Blocks.solid(self, "GarageDeck", Vector3(114.0, 1.2, 33.6), Vector3(12.0, 2.4, 4.4), Color("777c80"))
	Pieces.wedge(self, "GarageRampDown", Vector3(126.0, 0.0, 33.6), PI, 6.0, 2.4, 4.4, 0.0)
	Blocks.solid(self, "GarageRoof", Vector3(114.0, 5.6, 33.6), Vector3(12.0, 0.4, 5.0), Color("5e6266"))
	var cam := Node3D.new()
	cam.name = "DroneCamera"
	cam.position = Vector3(114.0, 5.0, 35.6)
	cam.add_to_group("spray_target")
	cam.add_to_group("painted_camera")
	cam.set_meta("camera_id", "parking")
	cam.set_meta("camera_lens_color", Color("ff3b1f"))
	add_child(cam)
	Blocks.visual(cam, "Body", Vector3.ZERO, Vector3(0.5, 0.35, 0.7), Color("2b2d30"))
	Blocks.visual(cam, "Lens", Vector3(0, -0.05, -0.38), Vector3(0.18, 0.18, 0.06), Color("ff3b1f"))
	var lbl := Blocks.label(self, "PARKING · LEVEL 1 · CAMERA IN USE", Vector3(108.0, 4.6, 36.0), SERA_BLUE, 24)
	lbl.name = "GarageSign"

func _plaza() -> void:
	Blocks.solid(self, "PlazaFloor", Vector3(152.0, -0.5, 25.0), Vector3(52.0, 1.0, 50.0), CONCRETE, Vector3.ZERO, 0.04)
	for i in 5:
		for j in 4:
			Blocks.visual(self, "PlazaTile%d_%d" % [i, j], Vector3(134.0 + i * 9.0, 0.015, 8.0 + j * 11.0), Vector3(8.6, 0.015, 10.6), Color("a3ada9") if (i + j) % 2 == 0 else Color("97a19d"))
	# boutique frontage on the plaza's north side
	Blocks.solid(self, "Boutique", Vector3(146.0, 4.0, 1.0), Vector3(24.0, 8.0, 2.0), Color("efe9df"))
	Blocks.visual(self, "BoutiqueGlass", Vector3(146.0, 2.0, 2.02), Vector3(18.0, 3.2, 0.04), GLASS)
	var b := Blocks.label(self, "LUMEN & LINEN · COMFORT TIERS INSIDE", Vector3(146.0, 5.6, 2.1), Color("3a3a44"), 30)
	b.name = "BoutiqueSign"
	# the mister kiosk: a post, a fan head, a mist cone that switches off as he passes
	var kiosk := Node3D.new()
	kiosk.name = "MisterKiosk"
	kiosk.position = Vector3(150.0, 0.0, 5.5)
	add_child(kiosk)
	Blocks.solid(kiosk, "Post", Vector3(0, 1.1, 0), Vector3(0.3, 2.2, 0.3), Color("d9dde0"))
	Blocks.visual(kiosk, "Head", Vector3(0, 2.4, 0.2), Vector3(0.8, 0.5, 0.4), Color("b8c0c6"))
	var mist := MeshInstance3D.new()
	mist.name = "Mist"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 1.4
	cone.height = 2.2
	mist.mesh = cone
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.85, 0.95, 1.0, 0.35)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.material_override = mm
	mist.position = Vector3(0, 1.2, 1.0)
	kiosk.add_child(mist)
	var tag := Label3D.new()
	tag.name = "KioskTag"
	tag.text = "COMFORT MIST · SILVER TIER"
	tag.font_size = 22
	tag.modulate = SERA_BLUE
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 3.0, 0)
	kiosk.add_child(tag)
	# early shoppers. Capsules, not boxes. They are still stand-ins, not named residents.
	var spots := [Vector3(142, 0, 7), Vector3(144.5, 0, 6.2), Vector3(156, 0, 8.5), Vector3(160, 0, 14), Vector3(138, 0, 40)]
	var coats := [Color("d9a0b0"), Color("8fb3d9"), Color("e0d28f"), Color("a0d9b4"), Color("c8b8e8")]
	for i in spots.size():
		_shopper("Shopper%d" % i, spots[i], coats[i])
	# planters and a low wall line the plaza
	for p in [Vector3(134, 0.45, 18), Vector3(134, 0.45, 32), Vector3(158, 0.45, 40)]:
		Blocks.solid(self, "Planter%d" % int(p.z), p, Vector3(3.0, 0.9, 1.6), Color("6d6359"))
	Blocks.solid(self, "PlazaWallSouth", Vector3(152.0, 0.6, 50.3), Vector3(52.0, 1.2, 0.6), Palette.PARK_WALL)
	Blocks.solid(self, "PlazaWallEast", Vector3(178.3, 2.0, 25.0), Vector3(0.6, 4.0, 50.0), BACKS)
	# The curb already stops the plaza. A taller face makes that edge read as the end of the street.
	Blocks.visual(self, "PlazaEdge", Vector3(178.55, 6.0, 25.0), Vector3(0.35, 8.0, 50.0), BACKS.darkened(0.12))
	# side walls of the plaza mouth so the alley reads as an alley
	Blocks.solid(self, "PlazaMouthNorth", Vector3(127.0, 4.0, 11.0), Vector3(2.0, 8.0, 21.4), BACKS)
	Blocks.solid(self, "PlazaMouthSouth", Vector3(127.0, 4.0, 43.3), Vector3(2.0, 8.0, 14.0), BACKS)
	var pl := Blocks.label(self, "GLASS ROW PLAZA", Vector3(150.0, 6.4, 24.0), Palette.LABEL, 40)
	pl.name = "PlazaSign"

func _stairs_and_drain() -> void:
	# a stair set up to the boutique terrace at the east end (2 m), and the loose storm-drain grate tucked under its
	# south (left, riding east) stringer
	Blocks.add_slope(self, "TerraceStairs", Vector3(162.0, 0.0, 22.0), Vector3(170.0, 2.0, 22.0), 6.0, Color("a8a29a"))
	for i in 8:
		Blocks.visual(self, "TerraceStep%d" % i, Vector3(162.5 + i, 0.25 + i * 0.25, 22.0), Vector3(1.0, 0.06, 6.0), Color("c2bbb0"))
	Blocks.solid(self, "Terrace", Vector3(174.0, 1.0, 22.0), Vector3(8.0, 2.0, 12.0), Color("b9b2a7"))
	var grate := Node3D.new()
	grate.name = "DrainGrate"
	grate.position = GRATE
	add_child(grate)
	Blocks.visual(grate, "Frame", Vector3(0, 0.02, 0), Vector3(1.6, 0.03, 1.2), Color("2b2a28"))
	for i in 5:
		Blocks.visual(grate, "Bar%d" % i, Vector3(-0.6 + i * 0.3, 0.04, 0), Vector3(0.08, 0.03, 1.1), Color("5a5650"))
	# The drop is still a fade (P2_CULVERT_IS_FADE). The mouth only shows where he goes.
	Blocks.visual(grate, "Mouth", Vector3(0, 0.012, 0), Vector3(1.3, 0.02, 0.95), Color("0c0b0a"))
	var lbl := Label3D.new()
	lbl.name = "GrateTag"
	lbl.text = "STORM DRAIN"
	lbl.font_size = 20
	lbl.modulate = Color("d8d0c8")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 1.2, 0)
	grate.add_child(lbl)

func _screens() -> void:
	# the three street screens Zero borrows (the face shows only while he talks)
	_screen("ScreenMeter", Vector3(96.0, 1.25, 35.7), Vector3(0.0, PI, 0.0), Vector2(0.5, 0.4), "PARKING  0:00")
	_screen("ScreenBusShelter", Vector3(138.0, 1.6, 30.0), Vector3(0.0, -PI * 0.5, 0.0), Vector2(1.6, 2.2), "SILVER TIER\nSTAY COMFORTABLE")
	_screen("ScreenStore", Vector3(152.0, 2.2, 2.08), Vector3.ZERO, Vector2(2.4, 1.4), "NEW: COOLING\nWEAR")
	Blocks.solid(self, "BusShelterRoof", Vector3(138.6, 2.9, 30.0), Vector3(1.8, 0.15, 4.0), Color("9aa3a8"))

func _screen(node_name: String, pos: Vector3, rot: Vector3, size: Vector2, idle: String) -> void:
	var s := Node3D.new()
	s.name = node_name
	s.position = pos
	s.rotation = rot
	add_child(s)
	Blocks.visual(s, "Frame", Vector3(0, 0, -0.05), Vector3(size.x + 0.12, size.y + 0.12, 0.08), Color("222326"))
	Blocks.visual(s, "Glass", Vector3(0, 0, 0.0), Vector3(size.x, size.y, 0.02), Color("1a2a33"))
	var ad := Label3D.new()
	ad.name = "Ad"
	ad.text = idle
	ad.font_size = 18
	ad.modulate = SERA_BLUE
	ad.position = Vector3(0, 0, 0.03)
	s.add_child(ad)
	var face := Label3D.new()
	face.name = "Face"
	face.text = "o   o\n\\___/"
	face.font_size = 34
	face.modulate = LIME
	face.position = Vector3(0, 0, 0.035)
	face.visible = false
	s.add_child(face)

func _skyline() -> void:
	# a few Glass Row towers behind the alley and the plaza (visual only)
	var spots := [Vector3(100, 0, 8), Vector3(118, 0, 4), Vector3(150, 0, -14), Vector3(176, 0, -6), Vector3(190, 0, 30), Vector3(170, 0, 66)]
	for i in spots.size():
		var h := 22.0 + float(i % 3) * 9.0
		Blocks.visual(self, "Tower%d" % i, spots[i] + Vector3(0, h * 0.5, 0), Vector3(10.0, h, 10.0), TOWER if i % 2 == 0 else GLASS.darkened(0.25))

func _shopper(node_name: String, pos: Vector3, coat: Color) -> void:
	var s := Node3D.new()
	s.name = node_name
	s.position = pos
	add_child(s)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 1.05
	body.mesh = cap
	body.position = Vector3(0, 0.78, 0)
	body.material_override = Blocks.cel(coat, 3.0, 0.16)
	s.add_child(body)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	head.mesh = sphere
	head.position = Vector3(0, 1.48, 0)
	head.material_override = Blocks.cel(Color("e6c3a5"), 3.0, 0.1)
	s.add_child(head)

## Cab and wheels on the existing van box. The box collision stays the lane block.
func _van_shape(body: Node3D) -> void:
	var plain: Array = []
	for child in body.get_children():
		if child is MeshInstance3D:
			plain.append(child)
	for child in plain:
		(child as MeshInstance3D).visible = false
	# Same footprint as the collision box (9 x 2.6 x 4.6). The cab is the west end, the end he approaches.
	Blocks.visual(body, "Cargo", Vector3(1.15, 0.0, 0.0), Vector3(6.5, 2.5, 4.5), Color("e8e4dc"))
	Blocks.visual(body, "Cab", Vector3(-3.35, -0.1, 0.0), Vector3(2.3, 2.3, 4.4), Color("d8d3cb"))
	Blocks.visual(body, "Windshield", Vector3(-4.42, 0.25, 0.0), Vector3(0.08, 0.85, 3.3), GLASS)
	for side in [-1.0, 1.0]:
		for along in [-2.8, 2.6]:
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel"
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.38
			cyl.bottom_radius = 0.38
			cyl.height = 0.28
			wheel.mesh = cyl
			wheel.rotation.x = PI * 0.5
			wheel.position = Vector3(along, -1.15, side * 2.35)
			wheel.material_override = Blocks.cel(Color("1c1c1c"), 3.0, 0.08)
			body.add_child(wheel)

## The screen nodes p2_run.gd borrows, by key.
func screen(key: String) -> Node3D:
	return get_node_or_null({"meter": "ScreenMeter", "bus": "ScreenBusShelter", "store": "ScreenStore"}.get(key, "")) as Node3D
