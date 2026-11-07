extends Node
## Entry point: applies settings, then opens the title screen.
## Developer switches (after `--`): --smoke-test runs the automated play-through test.

func _ready() -> void:
	get_tree().root.theme = UIKit.theme()
	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args:
		# not a "screen": it survives the screen changes it triggers
		get_tree().root.add_child.call_deferred(load("res://tools/tests/SmokeTest.gd").new())
	elif "--check" in args:
		Game.change_screen(load("res://tools/tests/CompileCheck.gd").new())
	elif "--kit" in args:
		Game.change_screen(load("res://tools/tests/KitTest.gd").new())
	elif "--preview" in args:
		Game.change_screen(load("res://tools/tests/Preview.gd").new())
	else:
		Game.goto_main_menu()
