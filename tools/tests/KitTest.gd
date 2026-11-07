extends Node3D
## Dev tool: checks that procedural and placeholder meshes face outward and are lit correctly.
## Renders each mesh lit from +X and compares the brightness of its right and left halves, and
## checks triangle winding against vertex normals. Run: godot --path . -- --kit

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.BLACK
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3(1, 0.4, 1), Vector3.ZERO)   # light from the right-front
	var tests := {}
	var st := MeshKit.begin(); MeshKit.ellipsoid(st, Vector3.ZERO, Vector3.ONE * 0.6, Basis(), 16, 10); tests["ellipsoid"] = MeshKit.finish(st)
	st = MeshKit.begin(); MeshKit.tube(st, Vector3(0, -0.6, 0), Vector3(0, 0.6, 0), 0.6, 0.5, 16, true); tests["tube"] = MeshKit.finish(st)
	st = MeshKit.begin(); MeshKit.box(st, Vector3.ZERO, Vector3.ONE); tests["box"] = MeshKit.finish(st)
	st = MeshKit.begin(); MeshKit.cone(st, Vector3(0, -0.6, 0), Vector3(0, 0.6, 0), 0.6, 12); tests["cone"] = MeshKit.finish(st)
	st = MeshKit.begin(); MeshKit.rock(st, Vector3.ZERO, Vector3.ONE * 0.6, 3); tests["rock"] = MeshKit.finish(st)
	tests["tree_trunk"] = Vegetation.tree_meshes("broadleaf")[0]
	tests["tree_leaves"] = Vegetation.tree_meshes("pine")[1]
	tests["hair"] = PartsBuilder.hair_mesh("bob")
	var body := CharacterModel.new()
	body.build(DB.RacesData.default_appearance(), {}, "", 0)
	var bmesh: Mesh = body.meshes[0].mesh
	body.free()
	tests["placeholder_body"] = bmesh
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	var bad := 0
	for name in tests:
		var mesh: Mesh = tests[name]
		var w := _winding(mesh)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mi.material_override = mat
		add_child(mi)
		var aabb := mesh.get_aabb()
		var c := aabb.get_center()
		cam.size = maxf(aabb.size.x, aabb.size.y) * 1.3
		cam.look_at_from_position(c + Vector3(0, 0, 10), c)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var right := _lum(img, 0.55, 0.75)
		var left := _lum(img, 0.25, 0.45)
		var ok := w > 0.5 and right >= left - 0.01
		if not ok:
			bad += 1
		print("%-17s winding_ok=%.2f  lit_right=%.3f lit_left=%.3f  %s" % [name, w, right, left, "OK" if ok else "INVERTED"])
		mi.queue_free()
	print("KIT %s" % ("PASSED" if bad == 0 else "FAILED"))
	get_tree().quit(1 if bad else 0)

## Fraction of triangles whose winding agrees with their vertex normals (Godot: clockwise = front).
func _winding(mesh: Mesh) -> float:
	var good := 0
	var total := 0
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var count: int = idx.size() if idx != null and idx.size() > 0 else v.size()
		for t in range(0, count, 3):
			var i0: int = idx[t] if idx != null and idx.size() > 0 else t
			var i1: int = idx[t + 1] if idx != null and idx.size() > 0 else t + 1
			var i2: int = idx[t + 2] if idx != null and idx.size() > 0 else t + 2
			var face := (v[i2] - v[i0]).cross(v[i1] - v[i0])
			if face.length() < 1e-9:
				continue
			total += 1
			if face.dot(n[i0] + n[i1] + n[i2]) > 0.0:
				good += 1
	return float(good) / maxf(1.0, total)

func _lum(img: Image, x0: float, x1: float) -> float:
	var s := 0.0
	var k := 0
	for y in range(int(img.get_height() * 0.3), int(img.get_height() * 0.7), 4):
		for x in range(int(img.get_width() * x0), int(img.get_width() * x1), 4):
			s += img.get_pixel(x, y).get_luminance()
			k += 1
	return s / maxf(1.0, k)
