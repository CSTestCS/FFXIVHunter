extends Node3D
## Dev tool: renders characters to PNG for visual checks. Run:
##   godot --path . -- --preview [--pose NAME] [--out FILE]

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.4, 0.48)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	floor.material_override = MeshKit.pbr(Color(0.4, 0.42, 0.38), 0.9)
	add_child(floor)
	var args := OS.get_cmdline_user_args()
	var pose_name := "idle"
	var out := "user://preview.png"
	for i in args.size():
		if args[i] == "--pose": pose_name = args[i + 1]
		if args[i] == "--out": out = args[i + 1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var looks := []
	var jobs := ["paladin", "warrior", "lancer", "ranger", "sorcerer", "samurai"]
	var outfits := ["leather_set", "simple_tunic", "plate_set", "ranger_garb", "scholar_robes", "desert_silks"]
	var races := ["hume", "aelith", "ferran", "draeki", "leporin", "tharn"]
	var cams := []
	for i in range(6):
		var a: Dictionary = DB.RacesData.randomize_appearance(rng, races[i])
		var c := CharacterModel.new()
		add_child(c)
		var wk: String = DB.jobs[jobs[i]].weapon
		c.build(a, outfits[i], "" if pose_name == "test" else wk, i % 6)
		c.position = Vector3((i - 2.5) * 1.1, 0, 0)
		looks.append([c, wk])
	var cam := Camera3D.new()
	add_child(cam)
	var view := "front"
	var focus := 0
	for i in args.size():
		if args[i] == "--view": view = args[i + 1]
		if args[i] == "--focus": focus = int(args[i + 1])
	var target := Vector3(0, 0.95, 0)
	var dist := 5.2
	if focus > 0:
		target = Vector3((focus - 1 - 2.5) * 1.1, 1.45, 0)
		dist = 1.1
	var dir: Vector3 = {"front": Vector3(0, 0.15, -1), "back": Vector3(0, 0.15, 1), "side": Vector3(1, 0.1, 0), "three": Vector3(0.7, 0.2, -0.7)}[view]
	cam.look_at_from_position(target + dir.normalized() * dist, target)
	cam.fov = 50
	var t := 0.0
	for f in range(40):
		t += 0.05
		for l in looks:
			var p: Dictionary
			match pose_name:
				"walk": p = Poses.move(t * 6.0, 1.0, t, l[1])
				"run": p = Poses.move(t * 8.0, 2.0, t, l[1])
				"attack": p = Poses.attack("slash_r", 1, 0.5, Poses.idle(t, l[1]))
				"tpose": p = {}
				"test":
					var i: int = looks.find(l)
					var tests := [Poses.merge([Poses.arm("left", 0, 0, 0, 0), Poses.arm("right", 0, 0, 0, 0)]),
						Poses.merge([Poses.arm("left", 0, 0, 0, 0), Poses.arm("right", 90, 0, 0, 0)]),
						Poses.merge([Poses.arm("left", 0, 0, 0, 90), Poses.arm("right", 0, 0, 0, 90)]),
						Poses.merge([Poses.arm("left", 180, 0, 0, 0), Poses.arm("right", 90, 45, 0, 0)]),
						Poses.merge([Poses.leg("left", 45, 0), Poses.leg("right", 0, 90)]),
						{"spine": Vector3(-30, 0, 0)}]
					p = tests[i]
				_: p = Poses.idle(t, l[1])
			l[0].animate(0.05, p, 30.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", ProjectSettings.globalize_path(out))
	get_tree().quit()
