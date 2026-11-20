extends Node3D
## Zero as a 2D cutout puppet (Act I M4, CINEMATIC P.4 first pass, Nov 20 2026), from the approved sheet's rig layers
## (assets/zero_puppet/: the body in the leather jacket with the red ? patch, the cream CRT head, the lime glyph faces).
## Flat cards like Fony's, facing the room; the front cards are single-sided, so from behind you see the back of the
## CRT with the serial plate: "DUSK DYNAMICS · ZR-0 · PROPERTY OF" and the rest scratched out (the script has Fony
## read it in P.4). PLACEHOLDERS: no arm/servo rig yet (the body is one card), no jacket-on animation (the body
## layer already wears it; the beat is narrated), the back of the body is a plain dark card.
##
## stage(): "off" (hidden), "slump" (dark screen, slumped on the bench), "boot" (sitting up, loading glyph),
## "awake" (upright, deadpan face). Local +Z faces out of the screen; the owner turns the root to face the room.

const ART := "res://assets/zero_puppet/"
const PX := 0.0022
const PLATE_TEXT := "DUSK DYNAMICS · ZR-0\nPROPERTY OF ////////"

var body: Sprite3D
var head: Node3D
var head_card: Sprite3D
var face: Sprite3D
var back_plate: Label3D
var current := "off"

func _ready() -> void:
	name = "ZeroPuppet"
	body = _card("Body", "zero_body.png", PX)
	body.position = Vector3(0.0, 0.47, 0.0)
	var body_back := _quad("BodyBack", Vector2(0.62, 0.85), Color("17120f"))
	body_back.position = Vector3(0.0, 0.47, -0.02)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.88, 0.0)
	add_child(head)
	head_card = _card("HeadCard", "zero_head.png", PX, head)
	head_card.position = Vector3(0.0, 0.02, 0.01)
	face = _card("Face", "zero_face_loading.png", 0.0015, head)
	face.position = Vector3(-0.06, 0.25, 0.02)
	var back := _quad("HeadBack", Vector2(0.78, 0.6), Color("d9cfb4"), head)
	back.position = Vector3(0.02, 0.24, -0.03)
	back_plate = Label3D.new()
	back_plate.name = "SerialPlate"
	back_plate.text = PLATE_TEXT
	back_plate.font_size = 28
	back_plate.pixel_size = 0.0028
	back_plate.modulate = Color("2c2a26")
	back_plate.outline_size = 0
	back_plate.position = Vector3(0.02, 0.22, -0.045)
	back_plate.rotation.y = PI
	head.add_child(back_plate)
	stage("off")

func _card(n: String, file: String, px: float, parent: Node = null) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = n
	s.texture = load(ART + file) as Texture2D
	s.pixel_size = px
	s.double_sided = false
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	(parent if parent != null else self).add_child(s)
	return s

func _quad(n: String, size: Vector2, c: Color, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.rotation.y = PI
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = m
	(parent if parent != null else self).add_child(mi)
	return mi

func stage(s: String) -> void:
	current = s
	visible = s != "off"
	match s:
		"slump":
			head.rotation.z = 0.35
			head.position = Vector3(0.08, 0.74, 0.0)
			body.rotation.z = 0.12
			face.visible = false
		"boot":
			head.rotation.z = 0.08
			head.position = Vector3(0.02, 0.84, 0.0)
			body.rotation.z = 0.03
			face.visible = true
			face.texture = load(ART + "zero_face_loading.png") as Texture2D
		"awake":
			head.rotation.z = 0.0
			head.position = Vector3(0.0, 0.88, 0.0)
			body.rotation.z = 0.0
			face.visible = true
			face.texture = load(ART + "zero_face_deadpan.png") as Texture2D
