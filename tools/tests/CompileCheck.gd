extends Node
## Dev tool: loads every script so parse/compile errors show up. Run:
##   godot --headless --path . -- --check

func _ready() -> void:
	var stack := ["res://scripts", "res://tools/tests"]
	var n := 0
	var bad := 0
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".gd"):
				n += 1
				if load(d + "/" + f) == null:
					bad += 1
					print("FAILED: ", d + "/" + f)
		for sd in da.get_directories():
			stack.append(d + "/" + sd)
	print("CHECKED %d scripts, %d failed" % [n, bad])
	get_tree().quit(1 if bad > 0 else 0)
