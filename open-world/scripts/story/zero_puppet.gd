extends Node3D
## Zero as a 2D cutout puppet (Act I M4, CINEMATIC P.4 first pass, Nov 20 2026), from the approved sheet's rig layers
## (assets/zero_puppet/: the body in the leather jacket with the red ? patch, the cream CRT head, the lime glyph faces).
## Flat cards like Fony's, facing the room; the front cards are single-sided, so from behind you see the back of the
## CRT with the serial plate: "DUSK DYNAMICS · ZR-0 · PROPERTY OF" and the rest scratched out (the script has Fony
## read it in P.4). The painted body already wears the jacket. Servo arms ride at the shoulders and the shrug
## (badly, then correctly) plays on "boot". The body's back is the jacket, not a blank card.
## OPEN: P4_TITLE_SONG lives on the story host. This puppet does not play audio.
##
## stage(): "off" (hidden), "slump" (dark screen, slumped on the bench), "boot" (sitting up, loading glyph),
## "awake" (upright, deadpan face). Local +Z faces out of the screen; the owner turns the root to face the room.

const ART := "res://assets/zero_puppet/"
const PX := 0.0022
const PLATE_TEXT := "DUSK DYNAMICS · ZR-0\nPROPERTY OF ////////"
## OPEN: how long "badly, then correctly" takes. The line is the script's; this is only the pose.
const JACKET_SHRUG_S := 1.35
const LEATHER := Color("1c1e22")
const LEATHER_EDGE := Color("3a3e46")
const SERVO := Color("6a6e76")
const HAND := Color("8d9096")

var body: Sprite3D
var head: Node3D
var head_card: Sprite3D
var face: Sprite3D
var back_plate: Label3D
var arm_l: Node3D
var arm_r: Node3D
var current := "off"
var shrug_t := -1.0

func _ready() -> void:
	name = "ZeroPuppet"
	body = _card("Body", "zero_body.png", PX)
	body.position = Vector3(0.0, 0.47, 0.0)
	var body_back := _quad("BodyBack", Vector2(0.58, 0.78), LEATHER)
	body_back.position = Vector3(0.0, 0.48, -0.025)
	var seam := _quad("BodySeam", Vector2(0.045, 0.62), LEATHER_EDGE)
	seam.position = Vector3(0.0, 0.5, -0.03)
	var collar := _quad("JacketCollar", Vector2(0.34, 0.08), LEATHER_EDGE)
	collar.position = Vector3(0.0, 0.82, -0.028)
	arm_l = _arm("ServoArmL", -0.3)
	arm_r = _arm("ServoArmR", 0.3)
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
	shrug_t = 0.0 if s == "boot" else -1.0
	match s:
		"slump":
			head.rotation.z = 0.35
			head.position = Vector3(0.08, 0.74, 0.0)
			body.rotation.z = 0.12
			face.visible = false
			_arms(0.15, 0.4, -0.15, 0.35)
		"boot":
			head.rotation.z = 0.08
			head.position = Vector3(0.02, 0.84, 0.0)
			body.rotation.z = 0.2
			face.visible = true
			face.texture = load(ART + "zero_face_loading.png") as Texture2D
			_shrug(0.0)
		"awake":
			head.rotation.z = 0.0
			head.position = Vector3(0.0, 0.88, 0.0)
			body.rotation.z = 0.0
			face.visible = true
			face.texture = load(ART + "zero_face_deadpan.png") as Texture2D
			_arms(0.08, 0.15, -0.08, 0.15)

func _process(delta: float) -> void:
	if shrug_t < 0.0 or current != "boot":
		return
	shrug_t += delta
	var u := clampf(shrug_t / JACKET_SHRUG_S, 0.0, 1.0)
	_shrug(u)
	if u >= 1.0:
		shrug_t = -1.0

## u = 0 is the jacket on badly (one shoulder up). u = 1 is it sitting correctly.
func _shrug(u: float) -> void:
	body.rotation.z = lerpf(0.22, 0.02, u)
	var lift := 1.15 * (1.0 - smoothstep(0.0, 1.0, u))
	_arms(0.12 + lift, 0.25, -0.1, 0.2 + lift * 0.35)

func _arms(lz: float, le: float, rz: float, re: float) -> void:
	if arm_l == null:
		return
	# In front only while the shrug plays. At rest they sit behind the approved front card.
	var z := 0.08 if current == "boot" else -0.05
	arm_l.position.z = z
	arm_r.position.z = z
	arm_l.rotation.z = lz
	(arm_l.get_node("Elbow") as Node3D).rotation.z = le
	arm_r.rotation.z = rz
	(arm_r.get_node("Elbow") as Node3D).rotation.z = re

func _arm(node_name: String, x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = Vector3(x, 0.76, 0.06)
	add_child(pivot)
	var upper := _limb("Upper", 0.16, LEATHER_EDGE)
	upper.position = Vector3(0.0, -0.08, 0.0)
	pivot.add_child(upper)
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0.0, -0.16, 0.0)
	pivot.add_child(elbow)
	var fore := _limb("Fore", 0.14, SERVO)
	fore.position = Vector3(0.0, -0.07, 0.0)
	elbow.add_child(fore)
	var hand := MeshInstance3D.new()
	hand.name = "Hand"
	var sphere := SphereMesh.new()
	sphere.radius = 0.048
	sphere.height = 0.096
	hand.mesh = sphere
	hand.position = Vector3(0.0, -0.15, 0.0)
	hand.material_override = _mat(HAND)
	elbow.add_child(hand)
	return pivot

func _limb(node_name: String, length: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var cap := CapsuleMesh.new()
	cap.radius = 0.042
	cap.height = length
	mi.mesh = cap
	mi.material_override = _mat(color)
	return mi

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.72
	return m
