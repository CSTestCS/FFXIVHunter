extends Node3D
## Dev tool: renders MeshKit primitives to verify face winding/normals.
func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var st := MeshKit.begin()
	MeshKit.tube(st, Vector3(-2, 0, 0), Vector3(-2, 1, 0), 0.8, 0.7, 12, true, Vector2.ONE, Color("8a8478"))
	MeshKit.ellipsoid(st, Vector3(0, 0.6, 0), Vector3(0.6, 0.6, 0.6), Basis(), 12, 8, Callable(), Color("c8b08a"))
	MeshKit.box(st, Vector3(2, 0.5, 0), Vector3(1, 1, 1), Basis(), Color("6b4a2e"))
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st, MeshKit.vcol_pbr(0.6))
	add_child(mi)
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.5, 4), Vector3(0, 0.4, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/kit.png")
	get_tree().quit()
