class_name RendererGuard
extends RefCounted
## Makes sure the 3D renderer actually works on this PC.
##
## * Settings "renderer" = auto | vulkan | d3d12 | opengl. A choice other than auto that differs
##   from what is running relaunches the game with the matching command-line switches.
## * On auto, the first launch renders a tiny hidden test scene with the same effects the game
##   uses (shadows, glow, SSAO, fog, tonemapping, MSAA) and reads it back. Some drivers produce
##   noise instead of an image; then the game switches to the OpenGL (Compatibility) renderer and
##   relaunches. The result is remembered so the test runs once per renderer.

const RELAUNCH_FLAG := "--relaunched"

## Returns true if the game is being relaunched (caller should stop booting).
static func ensure(owner: Node) -> bool:
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return false
	var want: String = Settings.data.get("renderer", "auto")
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var relaunched := RELAUNCH_FLAG in OS.get_cmdline_user_args()
	match want:
		"opengl":
			if method != "gl_compatibility":
				return _relaunch(owner, ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"], relaunched)
		"vulkan", "d3d12":
			if method != "forward_plus" or driver != want:
				return _relaunch(owner, ["--rendering-method", "forward_plus", "--rendering-driver", want], relaunched)
	return false

## Runs the readback test (Forward+ only, once per driver). Returns false when 3D output is broken.
static func self_test(owner: Node) -> bool:
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return true
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return true
	var key := "gpu_ok_" + RenderingServer.get_current_rendering_driver_name()
	if Settings.data.get(key, false):
		return true
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.own_world_3d = true
	vp.msaa_3d = owner.get_viewport().msaa_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.3, 0.8)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.001
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 20, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	plane.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.1, 0.05)
	plane.material_override = mat
	vp.add_child(plane)
	var cam := Camera3D.new()
	vp.add_child(cam)
	owner.add_child(vp)
	cam.look_at_from_position(Vector3(0, 2, 6), Vector3(0, 2.6, 0))
	for i in range(6):
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return false
	# top rows: sky colour (blue, uniform); bottom rows: red ground (red, fairly uniform)
	var top := _stats(img, 2, 20)
	var bottom := _stats(img, 48, 62)
	var ok: bool = top.std < 0.08 and top.mean.b > top.mean.r and bottom.mean.r > bottom.mean.b and bottom.std < 0.2
	print("GPU self-test: top=%s bottom=%s -> %s" % [top, bottom, "ok" if ok else "BROKEN"])
	if ok:
		Settings.data[key] = true
		Settings.save_settings()
	return ok

static func _stats(img: Image, y0: int, y1: int) -> Dictionary:
	var sum := Color(0, 0, 0)
	var vals := []
	for y in range(y0, y1):
		for x in range(4, 60, 2):
			var c := img.get_pixel(x, y)
			sum += c
			vals.append(c)
	var n := float(vals.size())
	var mean := Color(sum.r / n, sum.g / n, sum.b / n)
	var v := 0.0
	for c in vals:
		v += pow(c.r - mean.r, 2) + pow(c.g - mean.g, 2) + pow(c.b - mean.b, 2)
	return {"mean": mean, "std": sqrt(v / n)}

## Switch to OpenGL after a failed self-test.
static func fall_back(owner: Node) -> bool:
	Settings.data.renderer = "opengl"
	Settings.data.renderer_fallback = true
	Settings.save_settings()
	return _relaunch(owner, ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"], RELAUNCH_FLAG in OS.get_cmdline_user_args())

static func _relaunch(owner: Node, args: Array, already: bool) -> bool:
	if already:
		push_warning("Renderer switch requested again after a relaunch; continuing with the current renderer.")
		return false
	var a: Array = args.duplicate()
	a.append_array(["--", RELAUNCH_FLAG])
	var pid := OS.create_process(OS.get_executable_path(), a)
	if pid <= 0:
		return false
	owner.get_tree().quit()
	return true
