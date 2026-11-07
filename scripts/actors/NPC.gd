class_name NPC
extends Node3D
## Town/quest NPC. No physics body beyond a static blocker; animation rate drops with distance.

var npc_id := ""
var data: Dictionary
var model: CharacterModel
var label: Label3D
var marker: Label3D
var pose_name := "idle"
var talking := false
var t := 0.0
var _acc := 0.0
var world: Node
var wander: Array = []     # optional points for ambient walkers
var _wi := 0
var _wait := 0.0

func setup(w: Node, id: String, d: Dictionary, look: Dictionary) -> void:
	world = w
	npc_id = id
	data = d
	model = CharacterModel.new()
	add_child(model)
	var wk := ""
	if d.get("role", "") == "hero":
		wk = DB.jobs[d.get("job", "paladin")].weapon
	model.build(look, d.get("outfit", "simple_tunic"), wk, 5 if d.get("role", "") == "hero" else 0)
	model.set_sheathed(true)
	label = Label3D.new()
	label.text = "%s\n%s" % [d.get("name", ""), d.get("title", "")]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.pixel_size = 0.0035
	label.outline_size = 8
	label.modulate = Color("e8d38a") if d.get("role", "") != "villager" else Color("dfe6ee")
	label.position.y = model.height_m + 0.45
	label.visible = false
	add_child(label)
	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 64
	marker.pixel_size = 0.006
	marker.outline_size = 12
	marker.position.y = model.height_m + 0.95
	marker.no_depth_test = true
	add_child(marker)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = model.height_m
	cs.shape = cap
	cs.position.y = model.height_m * 0.5
	body.add_child(cs)
	add_child(body)
	t = randf() * 10.0

## "!" = new quest, "?" = quest to turn in.
func refresh_marker() -> void:
	if not Game.quests_to_turn_in(npc_id).is_empty():
		marker.text = "?"
		marker.modulate = Color("7fd4ff")
	elif not Game.quests_offered_by(npc_id).is_empty():
		marker.text = "!"
		marker.modulate = Color("ffd34a") if (DB.quests[Game.quests_offered_by(npc_id)[0]].type == "main") else Color("e8e8e8")
	else:
		marker.text = ""

func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var d := global_position.distance_to(world.player.global_position)
	label.visible = d < 9.0
	if d > 70.0:
		model.visible = d < 120.0
		return
	model.visible = true
	_acc += delta
	var interval := 0.0 if d < 25.0 else 0.1
	if _acc < interval:
		return
	var dt := _acc
	_acc = 0.0
	t += dt
	var pose: Dictionary
	var moving := false
	if not wander.is_empty() and not talking:
		_wait -= dt
		if _wait <= 0.0:
			var to: Vector3 = wander[_wi]
			var dir := to - global_position
			dir.y = 0
			if dir.length() < 0.6:
				_wi = (_wi + 1) % wander.size()
				_wait = randf_range(1.0, 4.0)
			else:
				moving = true
				global_position += dir.normalized() * 1.3 * dt
				global_position.y = world.terrain.height_at(global_position.x, global_position.z)
				rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-6.0 * dt))
	if talking:
		var to_p: Vector3 = world.player.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to_p.x, -to_p.z), 1.0 - exp(-6.0 * dt))
		pose = Poses.talk(t)
	elif moving:
		pose = Poses.move(t * 2.5, 0.7, t)
	else:
		match pose_name:
			"sit": pose = Poses.sit(t)
			"wave": pose = Poses.wave(t)
			"cheer": pose = Poses.cheer(t)
			"talk": pose = Poses.talk(t)
			"kneel": pose = Poses.kneel(t)
			"lying": pose = Poses.lying(t)
			_: pose = Poses.idle(t)
	model.animate(dt, pose, 8.0)
