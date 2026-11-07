extends Node
## Multiple save slots, stored as JSON in the user data folder
## (Windows: %APPDATA%/AetherHunter/saves/slot_N.json).

const SLOT_COUNT := 8
const DIR := "user://saves"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]

func exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

func save(slot: int, state: Dictionary) -> bool:
	if slot < 0:
		return false
	state.saved_at = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state, "\t"))
	f.close()
	return true

func load_slot(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}

func delete(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(slot_path(slot))

## Short summary for the slot list: name, job, level, place, play time, date.
func summary(slot: int) -> Dictionary:
	var s := load_slot(slot)
	if s.is_empty():
		return {}
	var job: String = s.get("job", "paladin")
	var lvl := int(s.get("jobs", {}).get(job, {}).get("level", 1))
	var p: Dictionary = s.get("player", {})
	var t := int(s.get("playtime", 0))
	return {
		"name": ("%s %s" % [p.get("first_name", "?"), p.get("last_name", "")]).strip_edges(),
		"job": DB.jobs.get(job, {}).get("name", job), "level": lvl,
		"region": DB.regions.get(s.get("region", ""), {}).get("name", "?"),
		"time": "%d:%02d" % [t / 3600, (t / 60) % 60], "date": s.get("saved_at", ""),
	}

func load_into_game(slot: int) -> bool:
	var s := load_slot(slot)
	if s.is_empty():
		return false
	Game.migrate_state(s)
	Game.state = s
	Game.current_slot = slot
	Game.goto_world()
	return true
