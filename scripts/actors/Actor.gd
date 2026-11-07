class_name Actor
extends CharacterBody3D
## Shared base for everything that can be hit: player, companions, monsters, escorts, camp objects.

signal died(actor: Actor)
signal damaged(actor: Actor, amount: float)

var world: Node
var faction := "enemy"          # "ally" or "enemy"
var display_name := ""
var max_hp := 100.0
var hp := 100.0
var defense := 0.0
var alive := true
var radius := 0.45
var height := 1.7
var invulnerable := false
var weak := {}                  # damage type -> multiplier
var poise := 0.0
var max_poise := 40.0
var gravity := 22.0
var lifesteal := 0.0
var lifesteal_time := 0.0

func center() -> Vector3:
	return global_position + Vector3.UP * height * 0.55

func flat_dir_to(p: Vector3) -> Vector3:
	var d := p - global_position
	d.y = 0
	return d.normalized() if d.length() > 0.001 else -global_transform.basis.z

func forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0
	return f.normalized()

## Apply a hit. info: amount, type, source (Actor), kb (metres), crit (bool), stagger (mult), dir (Vector3)
## Returns the damage dealt (0 if blocked/ignored).
func take_hit(info: Dictionary) -> float:
	if not alive or invulnerable:
		return 0.0
	var amount: float = info.get("amount", 0.0)
	var mult: float = weak.get(info.get("type", "slash"), 1.0)
	var dmg := amount * mult * (100.0 / (100.0 + defense))
	dmg = intercept_hit(dmg, info)
	if dmg <= 0.0:
		return 0.0
	dmg = maxf(1.0, round(dmg))
	hp = maxf(0.0, hp - dmg)
	poise += dmg * float(info.get("stagger", 1.0))
	damaged.emit(self, dmg)
	if world and world.has_method("on_actor_damaged"):
		world.on_actor_damaged(self, dmg, info)
	var src = info.get("source", null)
	if src is Actor and is_instance_valid(src) and (src as Actor).lifesteal > 0.0:
		(src as Actor).heal(dmg * (src as Actor).lifesteal, false)
	if hp <= 0.0:
		alive = false
		on_death(info)
		died.emit(self)
	else:
		on_hit(dmg, info)
	return dmg

## Override: blocking/parrying. Return the damage that actually goes through.
func intercept_hit(dmg: float, _info: Dictionary) -> float:
	return dmg

func on_hit(_dmg: float, _info: Dictionary) -> void:
	pass

func on_death(_info: Dictionary) -> void:
	pass

func heal(amount: float, show := true) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	if show and world and world.has_method("popup_number"):
		world.popup_number(center() + Vector3.UP * 0.5, int(amount), Color("7fd48a"))

func _tick_lifesteal(delta: float) -> void:
	if lifesteal_time > 0.0:
		lifesteal_time -= delta
		if lifesteal_time <= 0.0:
			lifesteal = 0.0
