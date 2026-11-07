extends Node
## Read-only game database. All content lives in scripts/data/*.gd as constants.

const RacesData := preload("res://scripts/data/races.gd")
const JobsData := preload("res://scripts/data/jobs.gd")
const ItemsData := preload("res://scripts/data/items.gd")
const MonstersData := preload("res://scripts/data/monsters.gd")
const RegionsData := preload("res://scripts/data/regions.gd")
const NpcsData := preload("res://scripts/data/npcs.gd")
const QuestsData := preload("res://scripts/data/quests.gd")

var races: Dictionary = RacesData.RACES
var jobs: Dictionary = JobsData.JOBS
var weapons: Dictionary = JobsData.WEAPONS
var tiers: Array = JobsData.TIERS
var items: Dictionary = ItemsData.ITEMS
var materia: Dictionary = ItemsData.MATERIA
var gear_sets: Dictionary = ItemsData.GEAR_SETS
var gear := {}            # piece id -> {name, set, slot, def, price, level}
var meals: Dictionary = ItemsData.MEALS
var monsters: Dictionary = MonstersData.MONSTERS
var regions: Dictionary = RegionsData.REGIONS
var biomes: Dictionary = RegionsData.BIOMES
var npcs: Dictionary = NpcsData.NPCS
var companions: Dictionary = NpcsData.COMPANIONS
var quests: Dictionary = QuestsData.QUESTS
var writs: Array = QuestsData.WRITS

func _ready() -> void:
	monsters = MonstersData.MONSTERS.duplicate(true)
	for id in MonstersData.VARIANTS:
		var v: Dictionary = MonstersData.VARIANTS[id]
		var m: Dictionary = monsters[v.base].duplicate(true)
		for k in v:
			if k != "base":
				m[k] = v[k]
		monsters[id] = m
	for set_id in gear_sets:
		var st: Dictionary = gear_sets[set_id]
		for slot in ItemsData.GEAR_SLOTS:
			var info: Dictionary = ItemsData.SLOT_INFO[slot]
			gear["%s_%s" % [set_id, slot]] = {"name": "%s %s" % [st.name, st.pieces[slot]], "set": set_id, "slot": slot,
				"def": maxf(1.0, round(float(st.def) * float(info.share) * 10.0) / 10.0), "price": int(float(st.price) * float(info.share)), "level": int(st.get("level", 0))}

## Slot -> piece id for wearing a whole set (used by NPCs, starting gear, cameo heroes).
func set_gear(set_id: String) -> Dictionary:
	var out := {}
	if not gear_sets.has(set_id):
		return out
	for slot in ItemsData.GEAR_SLOTS:
		out[slot] = "%s_%s" % [set_id, slot]
	return out

const CITY_ORDER := ["saltcrest", "verdhollow", "sunmarch"]
const RESCUERS := {"saltcrest": "brennick", "verdhollow": "maelle", "sunmarch": "hadir"}

func item_name(id: String) -> String:
	if items.has(id):
		return items[id].name
	if materia.has(id):
		return materia[id].name
	if gear.has(id):
		return gear[id].name
	for slot in meals:
		if meals[slot].has(id):
			return meals[slot][id].name
	return id

func item_price(id: String) -> int:
	if items.has(id):
		return int(items[id].price)
	if materia.has(id):
		return int(materia[id].price)
	return 0

func guild_npc(city: String) -> String:
	for id in npcs:
		if npcs[id].get("region", "") == city and npcs[id].role == "guild":
			return id
	return ""

func npcs_in(region: String) -> Array:
	var out := []
	for id in npcs:
		if npcs[id].get("region", "") == region:
			out.append(id)
	return out

func weapon_name(job: String, tier: int) -> String:
	var names: Array = jobs[job].weapon_names
	var t := clampi(tier, 0, names.size() - 1)
	return names[t]

func weapon_attack(job: String, tier: int) -> float:
	return float(weapons[jobs[job].weapon].atk) * float(tiers[clampi(tier, 0, tiers.size() - 1)].mult) * float(jobs[job].atk)
