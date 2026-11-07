extends RefCounted
## Jobs play like weapon types: each has a unique moveset, guard style, dodge style and gauge.
##
## Move fields: anim (pose archetype), s/a/r = startup/active/recovery seconds, mv = motion value,
## st = stamina cost, mp = mana cost, lunge = metres travelled while active, range/arc = hit cone,
## dmg = slash|blunt|pierce|magic, light/heavy = next move id when that button is pressed in a combo,
## flags: charge (hold to power up), counter, proj (projectile), aoe, heal, leap, iframes, buff, guardpoint.

const JOBS := {
	# ---------------- Saltcrest (port city) ----------------
	"warrior": {
		"name": "Warrior", "city": "saltcrest", "weapon": "greataxe", "role": "Heavy melee",
		"desc": "A greataxe wielder who trades speed for crushing, charged blows. Builds Fury with every hit and unleashes it in a whirling Inner Storm.",
		"difficulty": 2, "hp": 1.15, "atk": 1.15, "def": 1.1, "dodge": "roll", "guard": "weapon", "gauge": "fury",
		"weapon_names": ["Hatchet Greataxe", "Iron Greataxe", "Steel Labrys", "Mythril Cleaver", "Adamant Ravager", "Dawnforged Labrys"],
		"moves": {
			"L1": {"anim": "slam_2h", "s": 0.55, "a": 0.14, "r": 0.5, "mv": 1.3, "st": 0, "lunge": 0.8, "range": 3.0, "arc": 70, "dmg": "slash", "light": "L2", "heavy": "H1"},
			"L2": {"anim": "sweep_2h", "s": 0.45, "a": 0.16, "r": 0.5, "mv": 1.15, "st": 0, "lunge": 0.6, "range": 3.0, "arc": 160, "dmg": "slash", "light": "L3", "heavy": "H1"},
			"L3": {"anim": "spin", "s": 0.5, "a": 0.35, "r": 0.7, "mv": 1.8, "st": 0, "lunge": 1.0, "range": 3.2, "arc": 360, "dmg": "slash", "heavy": "H1"},
			"H1": {"anim": "charge_2h", "s": 0.7, "a": 0.16, "r": 0.8, "mv": 2.6, "st": 10, "lunge": 1.0, "range": 3.2, "arc": 80, "dmg": "blunt", "flags": ["charge"]},
			"ART": {"anim": "spin", "s": 0.35, "a": 0.9, "r": 0.6, "mv": 4.0, "st": 0, "lunge": 2.5, "range": 3.6, "arc": 360, "dmg": "slash", "gauge_cost": 50, "name": "Inner Storm"},
		},
	},
	"gunner": {
		"name": "Gunner", "city": "saltcrest", "weapon": "gun", "role": "Ranged physical",
		"desc": "A long-barrelled aether rifle. Fires quick shots, heavy piercing rounds, and a devastating Scattershot. Reload manages the ammunition gauge.",
		"difficulty": 2, "hp": 0.9, "atk": 1.0, "def": 0.9, "dodge": "roll", "guard": "none", "gauge": "ammo",
		"weapon_names": ["Matchlock", "Iron Musket", "Steel Arquebus", "Mythril Longrifle", "Adamant Hand Cannon", "Dawnforged Rifle"],
		"moves": {
			"L1": {"anim": "gun_fire", "s": 0.12, "a": 0.05, "r": 0.28, "mv": 0.55, "st": 0, "dmg": "pierce", "ammo": 1, "light": "L1", "heavy": "H1", "flags": ["proj"], "proj": {"speed": 70, "radius": 0.25, "count": 1, "spread": 0, "range": 60}},
			"H1": {"anim": "gun_fire", "s": 0.5, "a": 0.05, "r": 0.5, "mv": 2.0, "st": 0, "dmg": "pierce", "ammo": 2, "light": "L1", "flags": ["proj", "charge"], "proj": {"speed": 90, "radius": 0.35, "count": 1, "spread": 0, "range": 80, "pierce": true}},
			"ART": {"anim": "gun_fire", "s": 0.35, "a": 0.05, "r": 0.7, "mv": 0.8, "st": 15, "dmg": "pierce", "ammo": 3, "name": "Scattershot", "flags": ["proj"], "proj": {"speed": 55, "radius": 0.3, "count": 7, "spread": 24, "range": 22}},
			"RELOAD": {"anim": "reload", "s": 0.2, "a": 0.6, "r": 0.2, "mv": 0, "st": 0, "dmg": "pierce"},
		},
	},
	"sorcerer": {
		"name": "Sorcerer", "city": "saltcrest", "weapon": "staff", "role": "Ranged magic",
		"desc": "Commands fire, ice and lightning. Charged spells deal huge area damage; manage mana and keep your distance.",
		"difficulty": 3, "hp": 0.85, "atk": 1.2, "def": 0.8, "dodge": "blink", "guard": "none", "gauge": "mana",
		"weapon_names": ["Ash Staff", "Yew Staff", "Rosewood Rod", "Mythril Staff", "Adamant Scepter", "Dawnforged Staff"],
		"moves": {
			"L1": {"anim": "cast", "s": 0.25, "a": 0.05, "r": 0.3, "mv": 0.8, "mp": 4, "dmg": "magic", "light": "L1", "heavy": "H1", "flags": ["proj"], "proj": {"speed": 32, "radius": 0.4, "count": 1, "spread": 0, "range": 40, "fx": "fire"}},
			"H1": {"anim": "cast_big", "s": 0.9, "a": 0.1, "r": 0.6, "mv": 3.2, "mp": 18, "dmg": "magic", "flags": ["aoe", "charge"], "aoe": {"radius": 4.5, "dist": 12, "fx": "ice"}},
			"ART": {"anim": "cast_big", "s": 1.3, "a": 0.2, "r": 0.8, "mv": 6.0, "mp": 40, "dmg": "magic", "name": "Thunderfall", "flags": ["aoe"], "aoe": {"radius": 7.0, "dist": 14, "fx": "lightning"}},
		},
	},
	"reaper": {
		"name": "Reaper", "city": "saltcrest", "weapon": "scythe", "role": "Melee",
		"desc": "A wide-reaching war scythe with sweeping arcs. Harvested Soul empowers the Void Reaping weapon art and briefly grants life steal.",
		"difficulty": 2, "hp": 1.0, "atk": 1.1, "def": 0.95, "dodge": "step", "guard": "none", "gauge": "soul",
		"weapon_names": ["Sickle Scythe", "Iron Scythe", "Steel War Scythe", "Mythril Harvester", "Adamant Deathsickle", "Dawnforged Scythe"],
		"moves": {
			"L1": {"anim": "sweep_2h", "s": 0.3, "a": 0.14, "r": 0.35, "mv": 0.9, "st": 0, "lunge": 0.6, "range": 3.4, "arc": 150, "dmg": "slash", "light": "L2", "heavy": "H1"},
			"L2": {"anim": "slash_l", "s": 0.28, "a": 0.14, "r": 0.35, "mv": 0.95, "st": 0, "lunge": 0.6, "range": 3.4, "arc": 150, "dmg": "slash", "light": "L3", "heavy": "H1"},
			"L3": {"anim": "scythe_reap", "s": 0.4, "a": 0.22, "r": 0.5, "mv": 1.5, "st": 0, "lunge": 1.2, "range": 3.6, "arc": 200, "dmg": "slash", "heavy": "H1"},
			"H1": {"anim": "overhead", "s": 0.5, "a": 0.15, "r": 0.55, "mv": 2.0, "st": 10, "lunge": 1.4, "range": 3.4, "arc": 60, "dmg": "slash"},
			"ART": {"anim": "spin", "s": 0.3, "a": 0.6, "r": 0.5, "mv": 3.4, "st": 0, "lunge": 3.0, "range": 3.8, "arc": 360, "dmg": "slash", "gauge_cost": 50, "name": "Void Reaping", "flags": ["buff"], "buff": {"lifesteal": 0.15, "time": 12}},
		},
	},
	# ---------------- Verdhollow (forest city) ----------------
	"lancer": {
		"name": "Lancer", "city": "verdhollow", "weapon": "lance", "role": "Melee",
		"desc": "Long reach and steady thrusts. Hold guard to brace, and use Skyward Leap to vault high and crash down onto prey.",
		"difficulty": 2, "hp": 1.05, "atk": 1.05, "def": 1.05, "dodge": "step", "guard": "weapon", "gauge": "none",
		"weapon_names": ["Ash Spear", "Iron Lance", "Steel Partisan", "Mythril Trident", "Adamant Glaive", "Dawnforged Lance"],
		"moves": {
			"L1": {"anim": "thrust", "s": 0.22, "a": 0.1, "r": 0.3, "mv": 0.85, "st": 0, "lunge": 0.7, "range": 4.0, "arc": 30, "dmg": "pierce", "light": "L2", "heavy": "H1"},
			"L2": {"anim": "thrust", "s": 0.2, "a": 0.1, "r": 0.3, "mv": 0.9, "st": 0, "lunge": 0.7, "range": 4.0, "arc": 30, "dmg": "pierce", "light": "L3", "heavy": "H1"},
			"L3": {"anim": "sweep_2h", "s": 0.32, "a": 0.15, "r": 0.45, "mv": 1.3, "st": 0, "lunge": 0.5, "range": 3.8, "arc": 140, "dmg": "slash", "heavy": "H1"},
			"H1": {"anim": "thrust", "s": 0.45, "a": 0.25, "r": 0.5, "mv": 1.9, "st": 12, "lunge": 4.5, "range": 4.2, "arc": 40, "dmg": "pierce"},
			"ART": {"anim": "leap_strike", "s": 0.6, "a": 0.2, "r": 0.6, "mv": 4.2, "st": 25, "lunge": 7.0, "range": 4.0, "arc": 360, "dmg": "pierce", "name": "Skyward Leap", "flags": ["leap", "iframes"]},
		},
	},
	"ranger": {
		"name": "Ranger", "city": "verdhollow", "weapon": "bow", "role": "Ranged physical",
		"desc": "A recurve bow. Tap for rapid arrows or hold for powerful charged shots. Arrow Rain blankets an area in a hail of arrows.",
		"difficulty": 2, "hp": 0.9, "atk": 1.0, "def": 0.9, "dodge": "roll", "guard": "none", "gauge": "none",
		"weapon_names": ["Shortbow", "Yew Longbow", "Horn Recurve", "Mythril Warbow", "Adamant Greatbow", "Dawnforged Bow"],
		"moves": {
			"L1": {"anim": "bow_draw", "s": 0.2, "a": 0.05, "r": 0.25, "mv": 0.6, "st": 4, "dmg": "pierce", "light": "L1", "heavy": "H1", "flags": ["proj"], "proj": {"speed": 60, "radius": 0.25, "count": 1, "spread": 0, "range": 60, "fx": "arrow"}},
			"H1": {"anim": "bow_draw", "s": 0.6, "a": 0.05, "r": 0.35, "mv": 1.9, "st": 12, "dmg": "pierce", "light": "L1", "flags": ["proj", "charge"], "proj": {"speed": 80, "radius": 0.3, "count": 3, "spread": 8, "range": 70, "fx": "arrow"}},
			"ART": {"anim": "bow_draw", "s": 0.5, "a": 0.1, "r": 0.6, "mv": 3.5, "st": 25, "dmg": "pierce", "name": "Arrow Rain", "flags": ["aoe"], "aoe": {"radius": 5.0, "dist": 14, "fx": "arrows"}},
		},
	},
	"cleric": {
		"name": "Cleric", "city": "verdhollow", "weapon": "cane", "role": "Healer / magic",
		"desc": "Wields holy light. Bolts of radiance strike foes, Benediction heals you and allies around you, and Holy detonates in a blinding burst.",
		"difficulty": 1, "hp": 0.95, "atk": 0.95, "def": 0.95, "dodge": "blink", "guard": "none", "gauge": "mana",
		"weapon_names": ["Oak Cane", "Willow Cane", "Silverwood Wand", "Mythril Cane", "Adamant Crozier", "Dawnforged Cane"],
		"moves": {
			"L1": {"anim": "cast", "s": 0.25, "a": 0.05, "r": 0.3, "mv": 0.75, "mp": 4, "dmg": "magic", "light": "L1", "heavy": "H1", "flags": ["proj"], "proj": {"speed": 30, "radius": 0.4, "count": 1, "spread": 0, "range": 40, "fx": "holy"}},
			"H1": {"anim": "heal", "s": 0.7, "a": 0.1, "r": 0.5, "mv": 0, "mp": 22, "dmg": "magic", "flags": ["heal"], "heal": {"ratio": 0.35, "radius": 12}},
			"ART": {"anim": "cast_big", "s": 0.8, "a": 0.15, "r": 0.7, "mv": 3.6, "mp": 35, "dmg": "magic", "name": "Holy", "flags": ["aoe"], "aoe": {"radius": 6.0, "dist": 0, "fx": "holy"}},
		},
	},
	"shinobi": {
		"name": "Shinobi", "city": "verdhollow", "weapon": "daggers", "role": "Fast melee",
		"desc": "Twin daggers and blinding speed. Endless combos, long dodges, and Shadow Flurry: a storm of strikes while untouchable.",
		"difficulty": 3, "hp": 0.95, "atk": 0.9, "def": 0.9, "dodge": "step", "guard": "none", "gauge": "none",
		"weapon_names": ["Iron Kunai", "Steel Daggers", "Twin Stilettos", "Mythril Kodachi", "Adamant Fangs", "Dawnforged Daggers"],
		"moves": {
			"L1": {"anim": "slash_r", "s": 0.12, "a": 0.08, "r": 0.18, "mv": 0.45, "st": 0, "lunge": 0.5, "range": 2.4, "arc": 100, "dmg": "slash", "light": "L2", "heavy": "H1"},
			"L2": {"anim": "slash_l", "s": 0.12, "a": 0.08, "r": 0.18, "mv": 0.45, "st": 0, "lunge": 0.5, "range": 2.4, "arc": 100, "dmg": "slash", "light": "L3", "heavy": "H1"},
			"L3": {"anim": "flurry", "s": 0.12, "a": 0.4, "r": 0.25, "mv": 1.4, "st": 0, "lunge": 1.0, "range": 2.6, "arc": 120, "dmg": "slash", "light": "L1", "heavy": "H1"},
			"H1": {"anim": "dash_slash", "s": 0.2, "a": 0.2, "r": 0.35, "mv": 1.2, "st": 10, "lunge": 5.0, "range": 2.6, "arc": 120, "dmg": "slash", "light": "L1", "flags": ["iframes"]},
			"ART": {"anim": "flurry", "s": 0.15, "a": 1.2, "r": 0.4, "mv": 4.5, "st": 30, "lunge": 2.0, "range": 2.8, "arc": 180, "dmg": "slash", "name": "Shadow Flurry", "flags": ["iframes"]},
		},
	},
	# ---------------- Sunmarch (desert city) ----------------
	"paladin": {
		"name": "Paladin", "city": "sunmarch", "weapon": "sword_shield", "role": "Defensive melee",
		"desc": "Sword and shield. Block almost anything, punish with Shield Bash, and turn the tide with the Sacred Riposte counter.",
		"difficulty": 1, "hp": 1.2, "atk": 0.95, "def": 1.25, "dodge": "roll", "guard": "shield", "gauge": "none",
		"weapon_names": ["Bronze Spatha", "Iron Arming Sword", "Steel Longsword", "Mythril Blade", "Adamant Brand", "Dawnforged Blade"],
		"moves": {
			"L1": {"anim": "slash_r", "s": 0.18, "a": 0.12, "r": 0.25, "mv": 0.7, "st": 0, "lunge": 0.6, "range": 2.6, "arc": 110, "dmg": "slash", "light": "L2", "heavy": "H1"},
			"L2": {"anim": "slash_l", "s": 0.18, "a": 0.12, "r": 0.25, "mv": 0.75, "st": 0, "lunge": 0.6, "range": 2.6, "arc": 110, "dmg": "slash", "light": "L3", "heavy": "H1"},
			"L3": {"anim": "overhead", "s": 0.28, "a": 0.12, "r": 0.4, "mv": 1.15, "st": 0, "lunge": 0.8, "range": 2.8, "arc": 60, "dmg": "slash", "heavy": "H1"},
			"H1": {"anim": "shield_bash", "s": 0.25, "a": 0.12, "r": 0.4, "mv": 0.9, "st": 12, "lunge": 1.4, "range": 2.4, "arc": 90, "dmg": "blunt", "stagger": 2.5, "light": "L3"},
			"ART": {"anim": "guard", "s": 0.05, "a": 0.6, "r": 0.4, "mv": 3.0, "st": 15, "range": 3.0, "arc": 120, "dmg": "slash", "name": "Sacred Riposte", "flags": ["counter", "guardpoint"]},
		},
	},
	"monk": {
		"name": "Monk", "city": "sunmarch", "weapon": "fists", "role": "Fast melee",
		"desc": "Bare-knuckled martial artist. Chain punches and kicks to build Chakra, then release it with the Hundred Fists.",
		"difficulty": 2, "hp": 1.0, "atk": 0.95, "def": 1.0, "dodge": "step", "guard": "none", "gauge": "chakra",
		"weapon_names": ["Wraps", "Iron Cesti", "Steel Knuckles", "Mythril Claws", "Adamant Gauntlets", "Dawnforged Fists"],
		"moves": {
			"L1": {"anim": "punch_r", "s": 0.1, "a": 0.08, "r": 0.16, "mv": 0.45, "st": 0, "lunge": 0.4, "range": 2.0, "arc": 80, "dmg": "blunt", "light": "L2", "heavy": "H1"},
			"L2": {"anim": "punch_l", "s": 0.1, "a": 0.08, "r": 0.16, "mv": 0.45, "st": 0, "lunge": 0.4, "range": 2.0, "arc": 80, "dmg": "blunt", "light": "L3", "heavy": "H1"},
			"L3": {"anim": "kick", "s": 0.16, "a": 0.12, "r": 0.28, "mv": 0.9, "st": 0, "lunge": 0.7, "range": 2.4, "arc": 120, "dmg": "blunt", "light": "L1", "heavy": "H1"},
			"H1": {"anim": "upper", "s": 0.3, "a": 0.12, "r": 0.4, "mv": 1.4, "st": 10, "lunge": 0.8, "range": 2.2, "arc": 80, "dmg": "blunt", "stagger": 2.0, "light": "L1"},
			"ART": {"anim": "flurry", "s": 0.1, "a": 1.0, "r": 0.4, "mv": 4.2, "st": 0, "lunge": 1.0, "range": 2.4, "arc": 100, "dmg": "blunt", "gauge_cost": 100, "name": "Hundred Fists"},
		},
	},
	"samurai": {
		"name": "Samurai", "city": "sunmarch", "weapon": "katana", "role": "Precise melee",
		"desc": "A katana and perfect discipline. Flowing slashes build Spirit; time Iaijutsu Counter as a blow lands to retaliate with a lethal draw.",
		"difficulty": 3, "hp": 1.0, "atk": 1.1, "def": 0.95, "dodge": "step", "guard": "none", "gauge": "spirit",
		"weapon_names": ["Iron Uchigatana", "Steel Katana", "Folded Tachi", "Mythril Katana", "Adamant Nodachi", "Dawnforged Katana"],
		"moves": {
			"L1": {"anim": "slash_r", "s": 0.2, "a": 0.12, "r": 0.25, "mv": 0.8, "st": 0, "lunge": 0.7, "range": 2.9, "arc": 110, "dmg": "slash", "light": "L2", "heavy": "H1"},
			"L2": {"anim": "upper", "s": 0.2, "a": 0.12, "r": 0.25, "mv": 0.85, "st": 0, "lunge": 0.6, "range": 2.9, "arc": 90, "dmg": "slash", "light": "L3", "heavy": "H1"},
			"L3": {"anim": "overhead", "s": 0.28, "a": 0.14, "r": 0.4, "mv": 1.3, "st": 0, "lunge": 0.9, "range": 3.0, "arc": 60, "dmg": "slash", "heavy": "H1"},
			"H1": {"anim": "iai", "s": 0.45, "a": 0.12, "r": 0.5, "mv": 2.1, "st": 12, "lunge": 2.0, "range": 3.2, "arc": 140, "dmg": "slash", "flags": ["charge"]},
			"ART": {"anim": "iai", "s": 0.05, "a": 0.5, "r": 0.4, "mv": 3.8, "st": 10, "range": 3.4, "arc": 160, "dmg": "slash", "name": "Iaijutsu Counter", "gauge_cost": 25, "flags": ["counter", "guardpoint"]},
		},
	},
	"dread_knight": {
		"name": "Dread Knight", "city": "sunmarch", "weapon": "greatsword", "role": "Heavy melee",
		"desc": "A massive greatsword fuelled by darkness. Charge Souleater slashes, and spend Blood to unleash the life-draining Abyssal Drain.",
		"difficulty": 2, "hp": 1.15, "atk": 1.2, "def": 1.1, "dodge": "roll", "guard": "weapon", "gauge": "blood",
		"weapon_names": ["Iron Claymore", "Steel Zweihander", "Blackened Flamberge", "Mythril Greatsword", "Adamant Executioner", "Dawnforged Greatsword"],
		"moves": {
			"L1": {"anim": "slam_2h", "s": 0.6, "a": 0.15, "r": 0.55, "mv": 1.5, "st": 0, "lunge": 0.7, "range": 3.2, "arc": 60, "dmg": "slash", "light": "L2", "heavy": "H1"},
			"L2": {"anim": "sweep_2h", "s": 0.5, "a": 0.16, "r": 0.5, "mv": 1.3, "st": 0, "lunge": 0.6, "range": 3.2, "arc": 150, "dmg": "slash", "heavy": "H1"},
			"H1": {"anim": "charge_2h", "s": 0.85, "a": 0.18, "r": 0.9, "mv": 3.2, "st": 10, "lunge": 1.0, "range": 3.4, "arc": 70, "dmg": "slash", "flags": ["charge"]},
			"ART": {"anim": "slam_2h", "s": 0.5, "a": 0.25, "r": 0.7, "mv": 4.4, "st": 0, "lunge": 1.0, "range": 3.6, "arc": 120, "dmg": "magic", "gauge_cost": 50, "name": "Abyssal Drain", "flags": ["aoe", "buff"], "aoe": {"radius": 4.0, "dist": 2.5, "fx": "dark"}, "buff": {"lifesteal": 0.3, "time": 0.5}},
		},
	},
}

## Weapon types: base attack and how the weapon is held/rendered.
const WEAPONS := {
	"greataxe": {"atk": 42, "two_handed": true, "back": true},
	"gun": {"atk": 30, "two_handed": true, "back": true},
	"staff": {"atk": 34, "two_handed": false, "back": true},
	"scythe": {"atk": 36, "two_handed": true, "back": true},
	"lance": {"atk": 33, "two_handed": true, "back": true},
	"bow": {"atk": 30, "two_handed": false, "back": true},
	"cane": {"atk": 30, "two_handed": false, "back": true},
	"daggers": {"atk": 26, "two_handed": false, "back": false},
	"sword_shield": {"atk": 28, "two_handed": false, "back": false},
	"fists": {"atk": 26, "two_handed": false, "back": false},
	"katana": {"atk": 34, "two_handed": true, "back": false},
	"greatsword": {"atk": 44, "two_handed": true, "back": true},
}

## Upgrade tiers: attack multiplier, gil cost and materials needed to reach this tier.
const TIERS := [
	{"name": "", "mult": 1.0, "gil": 0, "mats": {}},
	{"name": "", "mult": 1.25, "gil": 600, "mats": {"iron_ore": 3, "beast_hide": 2}},
	{"name": "", "mult": 1.55, "gil": 1800, "mats": {"steel_ingot": 3, "grimtusk_tusk": 2}},
	{"name": "", "mult": 1.9, "gil": 4200, "mats": {"mythril_ore": 4, "drake_scale": 2}},
	{"name": "", "mult": 2.3, "gil": 9000, "mats": {"adamant_ore": 4, "tidewyrm_fin": 2, "golem_core": 1}},
	{"name": "", "mult": 2.8, "gil": 20000, "mats": {"dawn_crystal": 3, "sandmaw_fang": 2, "drake_heart": 1}},
]

const GAUGE_NAMES := {"fury": "Fury", "ammo": "Ammo", "mana": "Mana", "soul": "Soul", "chakra": "Chakra", "spirit": "Spirit", "blood": "Blood", "none": ""}
