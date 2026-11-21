extends Node3D
## Cold Row, outer (Act I 1.4 Cold Row and 1.4B The Benefactor, Nov 20 2026). Its own pack (districts/cold_row.pck),
## built in code from main-pack blocks. World coordinates, off-map east (x 368 .. 452, z -96 .. -8). Ground y = 0.
## Night: clean asphalt, perfect lawns, windowless humming buildings, everything lit blue; three cooling towers venting
## mist (the mist under them is cool and blinds the drones: a safe zone). Three things to mark with spray: the
## substation fence (a maintenance line crosses the river toward the Flats), the water intake pipes ("Coldfront Water
## Partnership: Sustaining the City."), the lawn watered at midnight ("Biophilic employee wellness space."). Two campus
## workers smoke by the fence. The river is the north edge; 1.4B's hologram stands over it (act1.gd builds that).
## PLACEHOLDER blockout.

const Blocks = preload("res://scripts/world_blocks.gd")
const Kit = preload("res://scripts/story/act1_kit.gd")

const BLUE := Color("6fb8ff")
const TOWERS := [Vector3(388.0, 0.0, -78.0), Vector3(410.0, 0.0, -84.0), Vector3(432.0, 0.0, -78.0)]

func _ready() -> void:
	set_meta("district_id", "cold_row")
	Blocks.solid(self, "Asphalt", Vector3(410.0, -0.5, -52.0), Vector3(84.0, 1.0, 88.0), Color("2b3036"), Vector3.ZERO, 0.04)
	for x in [368.0, 452.0]:
		Blocks.solid(self, "Fence%d" % int(x), Vector3(x, 1.2, -52.0), Vector3(0.3, 2.4, 88.0), Color("8090a0"))
	Blocks.solid(self, "FenceS", Vector3(410.0, 1.2, -8.0), Vector3(84.0, 2.4, 0.3), Color("8090a0"))
	Blocks.visual(self, "River", Vector3(410.0, -0.3, -104.0), Vector3(120.0, 0.2, 16.0), Color("10243a"))
	Blocks.solid(self, "RiverWall", Vector3(410.0, 0.6, -96.0), Vector3(84.0, 1.2, 0.4), Color("5a6470"))
	# windowless data halls, humming
	for i in 3:
		Blocks.solid(self, "Hall%d" % i, Vector3(386.0 + i * 24.0, 4.0, -40.0), Vector3(14.0, 8.0, 10.0), Color("c9d2dc"))
		Kit.lamp(self, "HallBlue%d" % i, Vector3(386.0 + i * 24.0, 1.0, -34.0), BLUE, 1.6, 12.0)
	for i in TOWERS.size():
		var at: Vector3 = TOWERS[i]
		var t := MeshInstance3D.new()
		t.name = "Tower%d" % i
		var m := CylinderMesh.new()
		m.top_radius = 3.2
		m.bottom_radius = 4.4
		m.height = 16.0
		t.mesh = m
		t.position = at + Vector3(0, 8.0, 0)
		t.material_override = Blocks.cel(Color("b8c2cc"))
		add_child(t)
		var plume := Blocks.visual(self, "Plume%d" % i, at + Vector3(0, 20.0, 0), Vector3(6.0, 8.0, 6.0), Color.WHITE)
		plume.material_override = Kit.unshaded(Color("dfefff"), 0.18)
		var mist := Blocks.visual(self, "Mist%d" % i, at + Vector3(0, 1.2, 7.0), Vector3(9.0, 2.4, 6.0), Color.WHITE)
		mist.material_override = Kit.unshaded(Color("cfe6ff"), 0.22)
		mist.set_meta("mist", true)
		Kit.lamp(self, "TowerBlue%d" % i, at + Vector3(0, 1.0, 6.0), BLUE, 2.0, 12.0)
	# 1. the substation: transformers behind a fence; the maintenance line runs north over the river toward the Flats
	Blocks.solid(self, "SubstationFence", Vector3(440.0, 1.2, -50.0), Vector3(0.3, 2.4, 12.0), Color("8090a0"))
	for k in 3:
		Blocks.solid(self, "Transformer%d" % k, Vector3(446.0, 1.2, -55.0 + k * 5.0), Vector3(3.0, 2.4, 3.0), Color("5c6670"))
	Blocks.visual(self, "MaintenanceLine", Vector3(446.0, 7.0, -78.0), Vector3(0.08, 0.08, 46.0), Color("222222"))
	Kit.sign(self, "SubstationSign", "COLDFRONT SUBSTATION 4\nHIGH VOLTAGE", Vector3(439.8, 1.9, -46.0), -PI * 0.5, Color("ffd24a"), 40, 0.012)
	Blocks.visual(self, "MarkSubstation", Vector3(439.82, 1.0, -52.0), Vector3(0.02, 1.2, 1.8), Color("2a3138")).set_meta("mark", "substation")
	# 2. the water intake
	for k in 2:
		var p := MeshInstance3D.new()
		p.name = "IntakePipe%d" % k
		var c := CylinderMesh.new()
		c.top_radius = 1.1
		c.bottom_radius = 1.1
		c.height = 22.0
		p.mesh = c
		p.rotation.x = PI * 0.5
		p.position = Vector3(376.0 + k * 3.0, 1.1, -82.0)
		p.material_override = Blocks.cel(Color("6f7c88"))
		add_child(p)
	Kit.sign(self, "IntakeSign", "COLDFRONT WATER PARTNERSHIP\nSustaining the City.", Vector3(377.5, 2.6, -70.8), 0.0, Color("e8f4ff"), 40, 0.012)
	Blocks.visual(self, "MarkIntake", Vector3(377.5, 1.2, -70.85), Vector3(1.8, 1.0, 0.02), Color("2a3138")).set_meta("mark", "intake")
	# 3. the lawn, watered at midnight
	Blocks.visual(self, "Lawn", Vector3(410.0, 0.03, -20.0), Vector3(26.0, 0.06, 14.0), Color("3f8f4a"))
	for k in 4:
		var sp := Blocks.visual(self, "Sprinkler%d" % k, Vector3(400.0 + k * 6.5, 0.6, -20.0), Vector3(0.1, 1.2, 0.1), Color("cfe6ff"))
		sp.material_override = Kit.unshaded(Color("cfe6ff"), 0.4)
	Kit.sign(self, "LawnSign", "BIOPHILIC EMPLOYEE\nWELLNESS SPACE", Vector3(396.0, 1.4, -12.9), 0.0, Color("e8f4ff"), 40, 0.012)
	Blocks.solid(self, "LawnSignPost", Vector3(396.0, 0.6, -13.1), Vector3(2.4, 1.2, 0.2), Color("5a6470"))
	Blocks.visual(self, "MarkLawn", Vector3(396.0, 0.75, -12.98), Vector3(2.2, 0.8, 0.02), Color("2a3138")).set_meta("mark", "lawn")
	# the smoke break
	Kit.person(self, "Worker1", "CAMPUS WORKER", Vector3(426.0, 0.0, -56.0), Color("3a6ea8"), 1.75, PI * 0.5)
	Kit.person(self, "Worker2", "CAMPUS WORKER", Vector3(427.4, 0.0, -56.6), Color("3a6ea8"), 1.7, -PI * 0.5)
	# screens that carry the 1.4B broadcast
	for k in 2:
		Blocks.visual(self, "Screen%d" % k, Vector3(392.0 + k * 30.0, 6.0, -34.9), Vector3(6.0, 3.4, 0.1), Color("0a1018"))
		var t := Kit.sign(self, "ScreenText%d" % k, "COLDFRONT · CRITICAL INFRASTRUCTURE", Vector3(392.0 + k * 30.0, 6.0, -34.8), 0.0, Color("9fd8ff"), 32, 0.012)
		t.set_meta("screen", k)
