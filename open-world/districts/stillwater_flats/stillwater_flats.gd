extends Node3D
## Stillwater Flats (Act I 1.2 Water Run and 1.3 Cool Roofs, Nov 20 2026). Its own pack (districts/stillwater_flats.pck),
## built in code from main-pack blocks so it stays tiny. World coordinates, off-map east (x 268 .. 352, z -92 .. -8),
## reached only by the story's fade. Ground y = 0; the north row of housing blocks has flat black tar roofs at y 6,
## joined by plank bridges (1.3). PLACEHOLDER blockout: block people, box buildings, label signs.
##
## Street (1.2): the community center (south-west), the QuickDrop ice locker (east, the Glass Row side), and the
## residents: Mr. Delacroix and Biscuit on a bench, Mrs. Okonkwo in a doorway, the kid on the stairs, the rooftop
## gardener's plot. Roofs (1.3): four tar roof sections (RoofTar0..3) that act1.gd paints white, the plank bridges, the
## laundry lines, and the Dusk billboard facing Glass Row with a camera in the "O" of COMFORT.

const Blocks = preload("res://scripts/world_blocks.gd")
const Kit = preload("res://scripts/story/act1_kit.gd")

const TAR := Color("1d1b1c")
const BRICK := Color("8a4a36")
const BLOCK := Color("9b8f84")
const ROOF_Y := 6.0
const ROOFS := [282.0, 298.0, 314.0, 330.0]     # roof centres along z -70, 12 m wide, 4 m gaps
const ROW_Z := -70.0

func _ready() -> void:
	set_meta("district_id", "stillwater_flats")
	Blocks.solid(self, "Street", Vector3(310.0, -0.5, -50.0), Vector3(84.0, 1.0, 84.0), Color("4a4644"), Vector3.ZERO, 0.04)
	for x in [268.0, 352.0]:
		Blocks.solid(self, "Edge%d" % int(x), Vector3(x, 1.0, -50.0), Vector3(0.5, 2.0, 84.0), Color("5a5250"))
	Blocks.solid(self, "EdgeS", Vector3(310.0, 1.0, -8.0), Vector3(84.0, 2.0, 0.5), Color("5a5250"))
	_row()
	_center()
	_locker()
	_residents()
	_billboard()
	Kit.lamp(self, "Shimmer", Vector3(310.0, 8.0, -45.0), Color("ffd9a0"), 0.6, 60.0)

func _row() -> void:
	for i in ROOFS.size():
		var x: float = ROOFS[i]
		Blocks.solid(self, "Block%d" % i, Vector3(x, ROOF_Y * 0.5, ROW_Z), Vector3(12.0, ROOF_Y, 12.0), BLOCK)
		var tar := Blocks.visual(self, "RoofTar%d" % i, Vector3(x, ROOF_Y + 0.03, ROW_Z), Vector3(11.6, 0.06, 11.6), TAR)
		tar.set_meta("roof", i)
		Blocks.solid(self, "Parapet%dN" % i, Vector3(x, ROOF_Y + 0.4, ROW_Z - 5.9), Vector3(12.0, 0.8, 0.2), BLOCK)
		Blocks.solid(self, "Parapet%dS" % i, Vector3(x, ROOF_Y + 0.4, ROW_Z + 5.9), Vector3(12.0, 0.8, 0.2), BLOCK)
		var temp := Kit.sign(self, "Temp%d" % i, "TOP FLOOR 104°F", Vector3(x, ROOF_Y - 1.2, ROW_Z + 6.05), 0.0, Color("ff8a5a"), 48, 0.02)
		temp.set_meta("temp", i)
		# foil-covered windows on the street side
		for k in 3:
			Blocks.visual(self, "Foil%d_%d" % [i, k], Vector3(x - 4.0 + k * 4.0, 3.2, ROW_Z + 6.02), Vector3(1.6, 1.4, 0.04), Color("c9ccd1"))
		if i < ROOFS.size() - 1:
			# the plank bridge to the next roof (and a laundry line over it)
			Blocks.solid(self, "Plank%d" % i, Vector3(x + 8.0, ROOF_Y - 0.05, ROW_Z), Vector3(4.6, 0.1, 1.4), Color("8c6a42"))
			Blocks.visual(self, "Laundry%d" % i, Vector3(x + 8.0, ROOF_Y + 1.6, ROW_Z - 3.0), Vector3(4.4, 0.03, 0.03), Color("d8d2c4"))
			for k in 3:
				Blocks.visual(self, "Sheet%d_%d" % [i, k], Vector3(x + 6.8 + k * 1.2, ROOF_Y + 1.25, ROW_Z - 3.0), Vector3(0.8, 0.7, 0.02), [Color("d84f4f"), Color("e8e0c8"), Color("4f8bd8")][k])
	# a stair rail by the kid's stoop (1.2) between blocks 2 and 3
	Blocks.solid(self, "Stoop", Vector3(322.0, 0.4, -62.0), Vector3(3.0, 0.8, 2.0), Color("7d746c"))

func _center() -> void:
	Blocks.solid(self, "CommunityCenter", Vector3(290.0, 2.0, -26.0), Vector3(14.0, 4.0, 10.0), BRICK)
	Kit.sign(self, "CenterSign", "STILLWATER\nCOMMUNITY CENTER", Vector3(290.0, 3.1, -20.94), 0.0, Color("f4e3b0"), 56, 0.016)
	Blocks.visual(self, "CenterDoor", Vector3(290.0, 1.1, -20.96), Vector3(1.6, 2.2, 0.05), Color("3b2a22"))
	Kit.lamp(self, "CenterLamp", Vector3(290.0, 3.0, -19.0), Color("ffcf8a"), 0.8, 8.0)

func _locker() -> void:
	Blocks.solid(self, "Locker", Vector3(346.0, 1.3, -46.0), Vector3(2.0, 2.6, 6.0), Color("2f6fb3"))
	Kit.sign(self, "LockerSign", "QUICKDROP · ICE\nSURGE COMFORT PRICING ×3", Vector3(344.96, 2.2, -46.0), -PI * 0.5, Color("e8f6ff"), 44, 0.012)
	Kit.lamp(self, "LockerGlow", Vector3(343.5, 2.0, -46.0), Color("9fd8ff"), 1.0, 7.0)

func _residents() -> void:
	Blocks.solid(self, "Bench", Vector3(280.0, 0.25, -44.0), Vector3(2.4, 0.5, 0.8), Color("6b4c34"))
	Kit.person(self, "MrDelacroix", "MR. DELACROIX", Vector3(280.0, 0.0, -43.2), Color("c9c2b4"), 1.7, PI)
	Blocks.visual(self, "Biscuit", Vector3(281.6, 0.22, -43.2), Vector3(0.6, 0.4, 0.3), Color("b07a3a"))
	Kit.person(self, "MrsOkonkwo", "MRS. OKONKWO", Vector3(306.0, 0.0, -63.0), Color("2f8f6f"), 1.68)
	Kit.person(self, "KidOnStairs", "KID ON THE STAIRS", Vector3(322.0, 0.8, -61.5), Color("e0b03a"), 1.15)
	Blocks.solid(self, "GardenPlot", Vector3(300.0, 0.2, -14.0), Vector3(5.0, 0.4, 2.5), Color("4d6b2f"))
	Kit.person(self, "RooftopGardener", "ROOFTOP GARDENER", Vector3(303.5, 0.0, -14.0), Color("b04a6a"), 1.72, -PI * 0.5)
	Kit.person(self, "NanaInes", "NANA INES", Vector3(292.5, 0.0, -19.8), Color("e6e0d0"), 1.62)

func _billboard() -> void:
	var x: float = ROOFS[3]
	Blocks.solid(self, "BillboardPost", Vector3(x + 3.5, ROOF_Y + 1.5, ROW_Z - 4.0), Vector3(0.4, 3.0, 0.4), Color("3a3a3a"))
	var board := Blocks.visual(self, "Billboard", Vector3(x + 3.5, ROOF_Y + 4.0, ROW_Z - 4.0), Vector3(0.2, 3.0, 8.0), Color("e9edf2"))
	board.rotation.y = 0.0
	Kit.sign(self, "BillboardText", "COMFORT, DELIVERED.\nUpgrade your CLEARANCE tier today.", Vector3(x + 3.38, ROOF_Y + 4.0, ROW_Z - 4.0), -PI * 0.5, Color("1b2a44"), 64, 0.018)
	Blocks.visual(self, "BillboardCam", Vector3(x + 3.35, ROOF_Y + 4.6, ROW_Z - 6.1), Vector3(0.12, 0.3, 0.3), Color("ff3030"))
