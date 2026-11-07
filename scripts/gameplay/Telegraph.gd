class_name Telegraph
extends MeshInstance3D
## Ground marker for an enemy attack. The quad grid is bent to follow the terrain once when placed,
## and the shader fills it in as the wind-up progresses.

var shape := "circle"
var radius := 3.0
var length := 6.0
var width := 2.0
var mat: ShaderMaterial

func setup(p_shape: String, m: Dictionary, shader: Shader) -> void:
	shape = p_shape
	radius = float(m.get("radius", 3.0))
	length = float(m.get("length", 6.0))
	width = float(m.get("width", 2.0))
	mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("shape", {"circle": 0, "cone": 1, "line": 2, "donut": 3}.get(shape, 0))
	mat.set_shader_parameter("angle", deg_to_rad(float(m.get("angle", 90.0))) * 0.5)
	mat.set_shader_parameter("inner", float(m.get("inner", 0.0)) / maxf(radius, 0.01))
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_fill(f: float) -> void:
	mat.set_shader_parameter("fill", f)

## Rebuilds the grid at origin facing dir, conforming to the terrain.
func place(origin: Vector3, dir: Vector3, terrain: Terrain) -> void:
	var g := 14
	var right := dir.cross(Vector3.UP).normalized()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for zi in range(g + 1):
		for xi in range(g + 1):
			var u := float(xi) / g
			var v := float(zi) / g
			var p: Vector3
			if shape == "line":
				p = origin + right * (u - 0.5) * width + dir * (1.0 - v) * length
			else:
				p = origin + right * (u * 2.0 - 1.0) * radius + dir * (1.0 - v * 2.0) * radius
			p.y = maxf(terrain.height_at(p.x, p.z), terrain.water) + 0.12
			verts.append(p)
			uvs.append(Vector2(u, v))
	for zi in range(g):
		for xi in range(g):
			var a := zi * (g + 1) + xi
			idx.append_array([a, a + 1, a + g + 1, a + 1, a + g + 2, a + g + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = m
	global_transform = Transform3D.IDENTITY
