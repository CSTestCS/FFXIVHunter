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
var armor: Dictionary = ItemsData.ARMOR
var meals: Dictionary = ItemsData.MEALS
var monsters: Dictionary = MonstersData.MONSTERS
var regions: Dictionary = RegionsData.REGIONS
var biomes: Dictionary = RegionsData.BIOMES
var npcs: Dictionary = NpcsData.NPCS
var companions: Dictionary = NpcsData.COMPANIONS
var quests: Dictionary = QuestsData.QUESTS
var writs: Array = QuestsData.WRITS

const CITY_ORDER := ["saltcrest", "verdhollow", "sunmarch"]
const RESCUERS := {"saltcrest": "brennick", "verdhollow": "maelle", "sunmarch": "hadir"}

func item_name(id: String) -> String:
	if items.has(id):
		return items[id].name
	if materia.has(id):
		return materia[id].name
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
