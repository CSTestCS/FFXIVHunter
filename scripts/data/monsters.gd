extends RefCounted
## Monsters. Every attack is telegraphed: a body tell (anim) plus an optional ground marker.
## move fields: anim, tele (circle|cone|line|donut|none), at (self|front|target), radius, angle (cone deg),
## length/width (line), windup, active, recover, dmg (x monster attack), kb (knockback m),
## range (min..max use distance), cd (cooldown s), dash (m moved during active), rage_only.
## weak: damage-type multipliers. body: procedural body plan used by MonsterBody.

const MONSTERS := {
	# ------------------------------------------------------------- small
	"hopper": {"name": "Meadow Hopper", "size": "small", "body": "hopper", "level": 1, "hp": 160, "atk": 14, "def": 2, "speed": 4.5, "scale": 0.7,
		"colors": ["#c8b08a", "#f1e6d2"], "aggro": 10, "passive": true, "xp": 12, "gil": 6,
		"drops": [["hopper_fur", 0.9], ["beast_hide", 0.3]], "weak": {"slash": 1.0, "blunt": 1.0, "pierce": 1.0, "magic": 1.0},
		"moves": [{"anim": "lunge", "tele": "none", "windup": 0.5, "active": 0.25, "recover": 0.7, "dmg": 1.0, "kb": 1.0, "range": [0, 2.0], "cd": 1.5, "dash": 2.0}]},
	"vale_wolf": {"name": "Vale Wolf", "size": "small", "body": "quadruped", "level": 3, "hp": 280, "atk": 24, "def": 4, "speed": 7.0, "scale": 0.9,
		"colors": ["#6b6560", "#cfc6bb"], "aggro": 18, "pack": 3, "xp": 30, "gil": 14,
		"drops": [["wolf_fang", 0.7], ["beast_hide", 0.6]], "weak": {"slash": 1.1, "blunt": 1.0, "pierce": 1.0, "magic": 1.1},
		"moves": [
			{"anim": "bite", "tele": "none", "windup": 0.45, "active": 0.2, "recover": 0.6, "dmg": 1.0, "kb": 1.0, "range": [0, 2.2], "cd": 1.4},
			{"anim": "lunge", "tele": "line", "at": "front", "length": 7.0, "width": 1.4, "windup": 0.8, "active": 0.35, "recover": 0.9, "dmg": 1.4, "kb": 3.0, "range": [3, 8], "cd": 5.0, "dash": 7.0}]},
	"dune_crawler": {"name": "Dune Crawler", "size": "small", "body": "crab", "level": 5, "hp": 420, "atk": 28, "def": 12, "speed": 4.0, "scale": 1.0,
		"colors": ["#b5653a", "#e8c27a"], "aggro": 12, "xp": 45, "gil": 20,
		"drops": [["crab_shell", 0.8], ["sea_salt", 0.4]], "weak": {"slash": 0.7, "blunt": 1.4, "pierce": 0.9, "magic": 1.1},
		"moves": [
			{"anim": "slam", "tele": "cone", "at": "self", "radius": 3.0, "angle": 90, "windup": 0.7, "active": 0.2, "recover": 0.8, "dmg": 1.2, "kb": 2.0, "range": [0, 2.8], "cd": 2.0},
			{"anim": "spin", "tele": "circle", "at": "self", "radius": 3.5, "windup": 1.0, "active": 0.5, "recover": 1.0, "dmg": 1.1, "kb": 3.0, "range": [0, 3.0], "cd": 6.0}]},
	"marsh_toad": {"name": "Marsh Toad", "size": "small", "body": "toad", "level": 6, "hp": 480, "atk": 30, "def": 6, "speed": 3.5, "scale": 1.1,
		"colors": ["#4f6b3a", "#c9c27a"], "aggro": 12, "xp": 50, "gil": 22,
		"drops": [["toad_oil", 0.8], ["wild_herb", 0.3]], "weak": {"slash": 1.2, "blunt": 0.9, "pierce": 1.1, "magic": 1.2},
		"moves": [
			{"anim": "leap", "tele": "circle", "at": "target", "radius": 3.0, "windup": 1.0, "active": 0.5, "recover": 1.0, "dmg": 1.4, "kb": 3.0, "range": [3, 12], "cd": 5.0},
			{"anim": "breath", "tele": "line", "at": "front", "length": 6.0, "width": 1.2, "windup": 0.7, "active": 0.3, "recover": 0.8, "dmg": 1.0, "kb": 1.0, "range": [0, 6], "cd": 3.0}]},
	"bandit": {"name": "Highway Bandit", "size": "small", "body": "humanoid", "level": 2, "hp": 300, "atk": 22, "def": 5, "speed": 5.0, "scale": 1.0,
		"colors": ["#4a3a2a", "#7a2a2a"], "aggro": 16, "xp": 35, "gil": 30,
		"drops": [["bandit_badge", 0.9], ["potion", 0.25]], "weak": {"slash": 1.1, "blunt": 1.1, "pierce": 1.1, "magic": 1.0},
		"moves": [
			{"anim": "slash", "tele": "none", "windup": 0.55, "active": 0.2, "recover": 0.6, "dmg": 1.0, "kb": 1.0, "range": [0, 2.3], "cd": 1.6},
			{"anim": "overhead", "tele": "cone", "at": "self", "radius": 3.0, "angle": 60, "windup": 0.9, "active": 0.2, "recover": 0.9, "dmg": 1.6, "kb": 2.0, "range": [0, 2.8], "cd": 4.0}]},
	"wisp": {"name": "Aether Wisp", "size": "small", "body": "wisp", "level": 8, "hp": 380, "atk": 34, "def": 2, "speed": 3.0, "scale": 0.8,
		"colors": ["#7fd4ff", "#ffffff"], "aggro": 20, "fly": 1.6, "xp": 60, "gil": 25,
		"drops": [["wisp_ember", 0.9], ["dawn_crystal", 0.04]], "weak": {"slash": 0.8, "blunt": 0.8, "pierce": 0.8, "magic": 1.6},
		"moves": [
			{"anim": "projectile", "tele": "circle", "at": "target", "radius": 2.5, "windup": 1.2, "active": 0.3, "recover": 1.0, "dmg": 1.2, "kb": 1.5, "range": [0, 18], "cd": 3.0},
			{"anim": "spin", "tele": "donut", "at": "self", "radius": 7.0, "inner": 2.5, "windup": 1.4, "active": 0.4, "recover": 1.2, "dmg": 1.3, "kb": 2.0, "range": [0, 7], "cd": 8.0}]},
	# ------------------------------------------------------------- large
	"grimtusk": {"name": "Grimtusk", "title": "Tyrant of the Vale", "size": "large", "body": "quadruped_heavy", "level": 6, "hp": 4200, "atk": 48, "def": 10, "speed": 6.5, "scale": 2.6,
		"colors": ["#5a3e2b", "#d9cbb0"], "aggro": 30, "xp": 600, "gil": 400,
		"drops": [["grimtusk_tusk", 1.0], ["beast_hide", 1.0], ["grimtusk_tusk", 0.4]], "weak": {"slash": 1.0, "blunt": 1.15, "pierce": 1.0, "magic": 1.0},
		"moves": [
			{"anim": "charge", "tele": "line", "at": "front", "length": 22.0, "width": 3.4, "windup": 1.2, "active": 1.1, "recover": 1.6, "dmg": 1.6, "kb": 6.0, "range": [7, 26], "cd": 7.0, "dash": 22.0},
			{"anim": "bite", "tele": "cone", "at": "self", "radius": 5.0, "angle": 70, "windup": 0.8, "active": 0.25, "recover": 0.9, "dmg": 1.0, "kb": 2.5, "range": [0, 5], "cd": 2.0},
			{"anim": "slam", "tele": "circle", "at": "self", "radius": 6.5, "windup": 1.4, "active": 0.25, "recover": 1.4, "dmg": 1.5, "kb": 5.0, "range": [0, 6], "cd": 8.0},
			{"anim": "roar", "tele": "circle", "at": "self", "radius": 9.0, "windup": 0.6, "active": 0.8, "recover": 0.6, "dmg": 0.2, "kb": 4.0, "range": [0, 9], "cd": 25.0, "rage_only": true}]},
	"tidewyrm": {"name": "Tidewyrm", "title": "Serpent of the Shallows", "size": "large", "body": "serpent", "level": 10, "hp": 6800, "atk": 58, "def": 14, "speed": 6.0, "scale": 2.4,
		"colors": ["#2f6f7a", "#bfe6dd"], "aggro": 32, "swims": true, "xp": 1100, "gil": 750,
		"drops": [["tidewyrm_fin", 1.0], ["pearl", 0.8], ["tidewyrm_fin", 0.35]], "weak": {"slash": 1.0, "blunt": 0.9, "pierce": 1.15, "magic": 1.25},
		"moves": [
			{"anim": "bite", "tele": "cone", "at": "self", "radius": 6.0, "angle": 60, "windup": 0.9, "active": 0.25, "recover": 1.0, "dmg": 1.1, "kb": 3.0, "range": [0, 6], "cd": 2.2},
			{"anim": "breath", "tele": "line", "at": "front", "length": 20.0, "width": 3.0, "windup": 1.3, "active": 1.0, "recover": 1.2, "dmg": 1.3, "kb": 3.0, "range": [4, 20], "cd": 7.0},
			{"anim": "tail", "tele": "donut", "at": "self", "radius": 8.0, "inner": 2.0, "windup": 1.2, "active": 0.4, "recover": 1.2, "dmg": 1.4, "kb": 5.0, "range": [0, 8], "cd": 6.0},
			{"anim": "dive", "tele": "circle", "at": "target", "radius": 5.5, "windup": 2.0, "active": 0.5, "recover": 1.6, "dmg": 1.9, "kb": 7.0, "range": [6, 30], "cd": 14.0}]},
	"thornback": {"name": "Thornback Drake", "title": "Wyvern of the Highmoor", "size": "large", "body": "wyvern", "level": 16, "hp": 11000, "atk": 74, "def": 20, "speed": 7.0, "scale": 2.8,
		"colors": ["#6b2a1f", "#e0a050"], "aggro": 38, "xp": 2400, "gil": 1600,
		"drops": [["drake_scale", 1.0], ["drake_scale", 0.6], ["drake_heart", 0.25]], "weak": {"slash": 1.0, "blunt": 1.0, "pierce": 1.1, "magic": 0.85},
		"moves": [
			{"anim": "bite", "tele": "cone", "at": "self", "radius": 6.0, "angle": 60, "windup": 0.8, "active": 0.25, "recover": 0.9, "dmg": 1.0, "kb": 3.0, "range": [0, 6], "cd": 2.0},
			{"anim": "breath", "tele": "cone", "at": "self", "radius": 18.0, "angle": 45, "windup": 1.5, "active": 1.4, "recover": 1.2, "dmg": 1.6, "kb": 2.0, "range": [4, 18], "cd": 9.0},
			{"anim": "tail", "tele": "circle", "at": "self", "radius": 8.5, "windup": 1.1, "active": 0.4, "recover": 1.1, "dmg": 1.3, "kb": 6.0, "range": [0, 7], "cd": 5.0},
			{"anim": "leap", "tele": "circle", "at": "target", "radius": 7.0, "windup": 1.8, "active": 0.6, "recover": 1.6, "dmg": 2.0, "kb": 7.0, "range": [8, 30], "cd": 12.0},
			{"anim": "charge", "tele": "line", "at": "front", "length": 24.0, "width": 4.5, "windup": 1.2, "active": 1.0, "recover": 1.4, "dmg": 1.6, "kb": 6.0, "range": [8, 26], "cd": 8.0, "dash": 24.0, "rage_only": true}]},
	"sandmaw": {"name": "Sandmaw", "title": "The Devouring Dune", "size": "large", "body": "worm", "level": 13, "hp": 8800, "atk": 66, "def": 16, "speed": 6.0, "scale": 2.6,
		"colors": ["#a8875a", "#5a3a2a"], "aggro": 34, "xp": 1700, "gil": 1200,
		"drops": [["sandmaw_fang", 1.0], ["sandmaw_fang", 0.4], ["adamant_ore", 0.5]], "weak": {"slash": 1.1, "blunt": 0.9, "pierce": 1.0, "magic": 1.1},
		"moves": [
			{"anim": "burrow", "tele": "circle", "at": "target", "radius": 6.0, "windup": 2.0, "active": 0.6, "recover": 1.8, "dmg": 1.8, "kb": 7.0, "range": [0, 40], "cd": 10.0},
			{"anim": "slam", "tele": "line", "at": "front", "length": 14.0, "width": 4.0, "windup": 1.2, "active": 0.3, "recover": 1.2, "dmg": 1.4, "kb": 4.0, "range": [0, 14], "cd": 4.0},
			{"anim": "bite", "tele": "cone", "at": "self", "radius": 7.0, "angle": 70, "windup": 0.9, "active": 0.3, "recover": 1.0, "dmg": 1.1, "kb": 3.0, "range": [0, 7], "cd": 2.2},
			{"anim": "spin", "tele": "donut", "at": "self", "radius": 11.0, "inner": 3.0, "windup": 1.4, "active": 0.6, "recover": 1.4, "dmg": 1.3, "kb": 5.0, "range": [0, 10], "cd": 9.0, "rage_only": true}]},
	"mossgiant": {"name": "Moss Colossus", "title": "Warden of the Mire", "size": "large", "body": "golem", "level": 9, "hp": 6200, "atk": 56, "def": 22, "speed": 3.2, "scale": 2.4,
		"colors": ["#5e6457", "#4f7a3a"], "aggro": 26, "xp": 950, "gil": 650,
		"drops": [["golem_core", 1.0], ["mythril_ore", 1.0], ["adamant_ore", 0.3]], "weak": {"slash": 0.7, "blunt": 1.4, "pierce": 0.8, "magic": 1.2},
		"moves": [
			{"anim": "slam", "tele": "circle", "at": "front", "radius": 4.5, "windup": 1.3, "active": 0.25, "recover": 1.3, "dmg": 1.6, "kb": 5.0, "range": [0, 6], "cd": 3.5},
			{"anim": "spin", "tele": "circle", "at": "self", "radius": 7.0, "windup": 1.4, "active": 0.8, "recover": 1.4, "dmg": 1.3, "kb": 5.0, "range": [0, 6], "cd": 7.0},
			{"anim": "projectile", "tele": "circle", "at": "target", "radius": 4.0, "windup": 1.6, "active": 0.3, "recover": 1.2, "dmg": 1.5, "kb": 4.0, "range": [7, 30], "cd": 6.0},
			{"anim": "roar", "tele": "donut", "at": "self", "radius": 14.0, "inner": 5.0, "windup": 1.8, "active": 0.5, "recover": 1.5, "dmg": 1.6, "kb": 5.0, "range": [0, 14], "cd": 15.0, "rage_only": true}]},
}

## Regional variants: copy a base monster and override fields (merged by DB at startup).
const VARIANTS := {
	"frost_wolf": {"base": "vale_wolf", "name": "Frostfang Wolf", "level": 12, "hp": 760, "atk": 44, "def": 10, "colors": ["#dfe6ee", "#7a8ea8"], "xp": 120, "gil": 40, "drops": [["wolf_fang", 0.8], ["beast_hide", 0.7], ["frost_lily", 0.2]]},
	"snow_hopper": {"base": "hopper", "name": "Snowdrift Hopper", "level": 10, "hp": 520, "atk": 30, "colors": ["#f2f4f8", "#c8d0dc"], "xp": 80, "gil": 25},
	"ice_wisp": {"base": "wisp", "name": "Rime Wisp", "level": 13, "hp": 820, "atk": 50, "colors": ["#bfe8ff", "#ffffff"], "xp": 140, "gil": 45},
	"magma_crab": {"base": "dune_crawler", "name": "Magma Crawler", "level": 16, "hp": 1250, "atk": 56, "def": 26, "colors": ["#2a2220", "#ff7a2a"], "xp": 200, "gil": 60, "drops": [["crab_shell", 0.8], ["adamant_ore", 0.15]]},
	"ember_wisp": {"base": "wisp", "name": "Ember Wisp", "level": 17, "hp": 1100, "atk": 60, "colors": ["#ff8a3a", "#ffe0a0"], "xp": 220, "gil": 60},
	"crystal_wisp": {"base": "wisp", "name": "Shard Wisp", "level": 18, "hp": 1200, "atk": 62, "colors": ["#b88aff", "#ffffff"], "xp": 240, "gil": 70, "drops": [["wisp_ember", 0.8], ["dawn_crystal", 0.12]]},
	"shard_crawler": {"base": "dune_crawler", "name": "Shard Crawler", "level": 17, "hp": 1300, "atk": 58, "def": 30, "colors": ["#5a4a7a", "#c8b0ff"], "xp": 230, "gil": 65, "drops": [["crab_shell", 0.6], ["dawn_crystal", 0.08]]},
	"sea_hag": {"base": "marsh_toad", "name": "Reef Toad", "level": 9, "hp": 640, "atk": 36, "colors": ["#2f6a7a", "#d8c890"], "xp": 90, "gil": 30},
	"thorn_beetle": {"base": "dune_crawler", "name": "Thornback Beetle", "level": 11, "hp": 720, "atk": 40, "def": 18, "colors": ["#3a5a2a", "#a8c050"], "xp": 110, "gil": 35, "drops": [["crab_shell", 0.6], ["ash_log", 0.3]]},
	"sand_toad": {"base": "marsh_toad", "name": "Dune Toad", "level": 12, "hp": 760, "atk": 44, "colors": ["#b89a62", "#e8d8a8"], "xp": 120, "gil": 40},
	# large
	"glacial_colossus": {"base": "mossgiant", "name": "Glacial Colossus", "title": "Heart of the Frostspine", "level": 20, "hp": 16000, "atk": 92, "def": 34, "colors": ["#c8d8ec", "#7aa8d8"], "xp": 3600, "gil": 2400,
		"drops": [["golem_core", 1.0], ["mythril_ore", 1.0], ["dawn_crystal", 0.5]]},
	"magmaw": {"base": "sandmaw", "name": "Magmaw", "title": "The Molten Throat", "level": 22, "hp": 18500, "atk": 98, "def": 30, "colors": ["#3a2a24", "#ff6a1a"], "xp": 4200, "gil": 2800,
		"drops": [["sandmaw_fang", 1.0], ["adamant_ore", 1.0], ["drake_heart", 0.2]]},
	"shardback": {"base": "grimtusk", "name": "Shardback", "title": "Crystal-Crowned Tyrant", "level": 21, "hp": 17000, "atk": 94, "def": 36, "colors": ["#4a3a6a", "#d0b8ff"], "xp": 3900, "gil": 2600, "scale": 3.0,
		"drops": [["grimtusk_tusk", 1.0], ["dawn_crystal", 1.0], ["dawn_crystal", 0.5]], "weak": {"slash": 0.8, "blunt": 1.3, "pierce": 0.9, "magic": 1.1}},
	"hollow_serpent": {"base": "tidewyrm", "name": "Hollowmere Serpent", "title": "Queen of the Still Lake", "level": 15, "hp": 11500, "atk": 76, "def": 20, "colors": ["#2a4a3a", "#9ad8a8"], "xp": 2500, "gil": 1700,
		"drops": [["tidewyrm_fin", 1.0], ["pearl", 1.0], ["pearl", 0.6]]},
	"canyon_drake": {"base": "thornback", "name": "Rustwing Drake", "title": "Terror of Scorchmouth", "level": 23, "hp": 20000, "atk": 102, "def": 30, "colors": ["#8a3a1a", "#e8c070"], "xp": 4600, "gil": 3100,
		"drops": [["drake_scale", 1.0], ["drake_scale", 1.0], ["drake_heart", 0.35]]},
}
