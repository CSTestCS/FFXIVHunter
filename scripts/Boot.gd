extends Node
## Entry point. Draws a boot screen on the very first frame (so the window is never just black
## while the GPU driver compiles shaders on first launch), then opens the title screen.
## Developer switches (after `--`): --smoke-test, --check, --preview, --kit.

var _splash: CanvasLayer

func _ready() -> void:
	get_tree().root.theme = UIKit.theme()
	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args:
		# not a "screen": it survives the screen changes it triggers
		get_tree().root.add_child.call_deferred(load("res://tools/tests/SmokeTest.gd").new())
		return
	elif "--check" in args:
		Game.change_screen(load("res://tools/tests/CompileCheck.gd").new())
		return
	elif "--kit" in args:
		Game.change_screen(load("res://tools/tests/KitTest.gd").new())
		return
	elif "--preview" in args:
		Game.change_screen(load("res://tools/tests/Preview.gd").new())
		return
	_show_splash()
	print("Renderer: %s / %s" % [RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()])
	# let the splash reach the screen before doing any heavy work
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# make sure 3D rendering works on this GPU (switches to OpenGL + relaunches if not)
	if RendererGuard.ensure(self):
		return
	if not await RendererGuard.self_test(self):
		if RendererGuard.fall_back(self):
			return
	Game.goto_main_menu()
	# keep the splash up until the title has drawn a few frames
	for i in range(4):
		await RenderingServer.frame_post_draw
	_splash.queue_free()

func _show_splash() -> void:
	_splash = CanvasLayer.new()
	_splash.layer = 100
	add_child(_splash)
	var bg := ColorRect.new()
	bg.color = Color("080b12")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.add_child(bg)
	var v := UIKit.vbox(12)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -500
	v.offset_right = 500
	v.offset_top = -80
	bg.add_child(v)
	var t := UIKit.label("AETHER HUNTER", 64, UIKit.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UIKit.label("Loading...\nThe first launch prepares shaders for your graphics card and can take a little while.", 20, UIKit.DIM, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size = Vector2(1000, 0)
	v.add_child(s)
