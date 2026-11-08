extends Area3D

@export var length := 8.0
@export var speed := 8.0
var direction := Vector3.RIGHT
var mount_y := 0.0

func _ready() -> void:
	monitoring = false
	monitorable = false
	add_to_group("grind_rail")
	direction = global_transform.basis.x.normalized()
	if direction.length() < 0.1:
		direction = Vector3.RIGHT
	mount_y = global_position.y
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.12, 0.12)
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d7d2cb")
	mat.roughness = 1.0
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func point_at(along: float) -> Vector3:
	var start := global_position - direction * (length * 0.5)
	return start + direction * (length * clampf(along, 0.0, 1.0))

func try_attach(player: CharacterBody3D) -> bool:
	if player == null or player.grind != null or player.is_on_floor():
		return false
	if player.velocity.y > 2.5:
		return false
	if Vector2(player.velocity.x, player.velocity.z).length() < 3.0:
		return false
	var start := global_position - direction * (length * 0.5)
	var along := (player.global_position - start).dot(direction) / length
	if along < 0.02 or along > 0.9:
		return false
	var closest := start + direction * (length * along)
	var horizontal := Vector2(player.global_position.x - closest.x, player.global_position.z - closest.z).length()
	if horizontal > 0.6:
		return false
	var dy := player.global_position.y - mount_y
	if dy < -0.2 or dy > 0.9:
		return false
	player.begin_grind(self, along)
	return true
