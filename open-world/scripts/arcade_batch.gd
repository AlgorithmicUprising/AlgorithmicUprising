extends RefCounted
## Arcade Phase 1 (LOCAL): merges many static boxes and quads into one mesh per material,
## so a whole facade costs one draw call per material (plus its ink pass) on the web build.

var parts := {}
var order: Array[String] = []
var aliases := {}   # logical key -> [physical key, vertex colour]
var _color := Color.WHITE
var layers := 1

## Logical material that draws into a shared vertex-coloured batch.
func alias(key: String, target: String, color: Color) -> void:
	aliases[key] = [target, color]

func _resolve(key: String) -> String:
	if aliases.has(key):
		_color = aliases[key][1]
		return aliases[key][0]
	_color = Color.WHITE
	return key

func add_material(key: String, mat: Material, shadow := true, layer_mask := -1) -> void:
	if parts.has(key):
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	parts[key] = {"st": st, "mat": mat, "shadow": shadow, "tris": 0, "layers": layers if layer_mask < 0 else layer_mask}
	order.append(key)

func _tri(key: String, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, n: Vector3) -> void:
	var p: Dictionary = parts[key]
	var st: SurfaceTool = p.st
	# Godot front faces wind clockwise when viewed from the front.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	for v in [[a, ua], [b, ub], [c, uc]]:
		st.set_color(_color)
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])
	p.tris += 1

## a, b, c, d go round the quad: a top-left, b top-right, c bottom-right, d bottom-left (seen from the front).
func quad4(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv := Rect2(0, 0, 1, 1), normal := Vector3.ZERO) -> void:
	key = _resolve(key)
	var n := normal
	if n == Vector3.ZERO:
		n = (b - a).cross(d - a).normalized()
	var ua := uv.position
	var ub := uv.position + Vector2(uv.size.x, 0)
	var uc := uv.position + uv.size
	var ud := uv.position + Vector2(0, uv.size.y)
	_tri(key, a, b, c, ua, ub, uc, n)
	_tri(key, a, c, d, ua, uc, ud, n)

## Same as quad4 but the normal always points up (ramps, wedges).
func quad_up(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(d - a).normalized()
	if n.y < 0.0:
		n = -n
	quad4(key, a, b, c, d, Rect2(0, 0, 1, 1), n)

## Flat panel facing `out` (unit axis or any horizontal direction), centred at `center`.
func panel(key: String, center: Vector3, size: Vector2, out: Vector3, uv := Rect2(0, 0, 1, 1), roll := 0.0) -> void:
	out = out.normalized()
	var right := Vector3.UP.cross(out).normalized()
	if right.length() < 0.5:
		right = Vector3.RIGHT
	var up := out.cross(right).normalized()
	if roll != 0.0:
		right = right.rotated(out, roll)
		up = up.rotated(out, roll)
	var hx := right * size.x * 0.5
	var hy := up * size.y * 0.5
	quad4(key, center - hx + hy, center + hx + hy, center + hx - hy, center - hx - hy, uv, out)

## Panel on an arbitrary basis (x = right, y = up, z = out).
func panel_basis(key: String, center: Vector3, size: Vector2, basis: Basis, uv := Rect2(0, 0, 1, 1)) -> void:
	var hx := basis.x.normalized() * size.x * 0.5
	var hy := basis.y.normalized() * size.y * 0.5
	quad4(key, center - hx + hy, center + hx + hy, center + hx - hy, center - hx - hy, uv, basis.z.normalized())

func box(key: String, center: Vector3, size: Vector3, basis := Basis(), skip_bottom := false) -> void:
	var h := size * 0.5
	var axes := [basis.x.normalized(), basis.y.normalized(), basis.z.normalized()]
	for i in 3:
		for s in [-1.0, 1.0]:
			if i == 1 and s < 0.0 and skip_bottom:
				continue
			var n: Vector3 = axes[i] * s
			var u: Vector3 = axes[(i + 1) % 3] * h[(i + 1) % 3]
			var v: Vector3 = axes[(i + 2) % 3] * h[(i + 2) % 3]
			var c: Vector3 = center + n * h[i]
			quad4(key, c - u + v, c + u + v, c + u - v, c - u - v, Rect2(0, 0, 1, 1), n)

func tris() -> int:
	var t := 0
	for k in parts:
		t += int(parts[k].tris)
	return t

func commit(parent: Node, prefix: String) -> Array:
	var out := []
	for key in order:
		var p: Dictionary = parts[key]
		if int(p.tris) == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = prefix + "_" + key
		mi.mesh = (p.st as SurfaceTool).commit()
		mi.layers = int(p.get("layers", layers))
		mi.material_override = p.mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if p.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		out.append(mi)
	return out
