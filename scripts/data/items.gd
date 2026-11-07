extends RefCounted
## Items, materia, armor sets and meals.

const ITEMS := {
	# consumables
	"potion": {"name": "Potion", "type": "consumable", "price": 40, "desc": "Restores 30% HP over a moment.", "heal": 0.3},
	"hi_potion": {"name": "Hi-Potion", "type": "consumable", "price": 140, "desc": "Restores 60% HP.", "heal": 0.6},
	"ether": {"name": "Ether", "type": "consumable", "price": 120, "desc": "Restores 50% mana.", "mana": 0.5},
	"stamina_tonic": {"name": "Stamina Tonic", "type": "consumable", "price": 90, "desc": "Stamina does not drain for 60 seconds.", "buff": {"stamina_free": 60}},
	"phoenix_down": {"name": "Phoenix Plume", "type": "consumable", "price": 600, "desc": "Automatically revives you once when you would faint.", "auto_revive": true},
	# gathered materials
	"wild_herb": {"name": "Wild Herb", "type": "material", "price": 8, "desc": "A common medicinal herb."},
	"sunleaf": {"name": "Sunleaf", "type": "material", "price": 20, "desc": "A golden leaf that drinks in sunlight."},
	"iron_ore": {"name": "Iron Ore", "type": "material", "price": 15, "desc": "Rough iron ore."},
	"mythril_ore": {"name": "Mythril Ore", "type": "material", "price": 60, "desc": "Light, silvery ore prized by smiths."},
	"adamant_ore": {"name": "Adamant Ore", "type": "material", "price": 150, "desc": "Nearly unbreakable black ore."},
	"steel_ingot": {"name": "Steel Ingot", "type": "material", "price": 45, "desc": "Smelted, folded steel."},
	"ash_log": {"name": "Ash Log", "type": "material", "price": 12, "desc": "Straight-grained timber."},
	"dawn_crystal": {"name": "Dawn Crystal", "type": "material", "price": 400, "desc": "A crystal humming with aether."},
	"sea_salt": {"name": "Sea Salt", "type": "material", "price": 10, "desc": "Harvested from the tide pools."},
	"pearl": {"name": "River Pearl", "type": "material", "price": 90, "desc": "Found only by those willing to dive."},
	# monster drops
	"beast_hide": {"name": "Beast Hide", "type": "material", "price": 18, "desc": "Tough hide from wild beasts."},
	"hopper_fur": {"name": "Hopper Fur", "type": "material", "price": 6, "desc": "Soft and fluffy."},
	"crab_shell": {"name": "Crab Shell", "type": "material", "price": 14, "desc": "A sturdy chitin plate."},
	"toad_oil": {"name": "Toad Oil", "type": "material", "price": 12, "desc": "Slick and pungent."},
	"wolf_fang": {"name": "Wolf Fang", "type": "material", "price": 16, "desc": "A sharp, curved fang."},
	"bandit_badge": {"name": "Bandit Token", "type": "material", "price": 25, "desc": "A crude token carried by highway bandits."},
	"grimtusk_tusk": {"name": "Grimtusk Tusk", "type": "material", "price": 120, "desc": "A massive tusk from the Grimtusk."},
	"tidewyrm_fin": {"name": "Tidewyrm Fin", "type": "material", "price": 220, "desc": "An iridescent fin."},
	"drake_scale": {"name": "Drake Scale", "type": "material", "price": 180, "desc": "Warm to the touch, even now."},
	"drake_heart": {"name": "Drake Heart", "type": "material", "price": 900, "desc": "Still faintly glowing with inner fire."},
	"golem_core": {"name": "Golem Core", "type": "material", "price": 300, "desc": "A stone heart veined with aether."},
	"sandmaw_fang": {"name": "Sandmaw Fang", "type": "material", "price": 260, "desc": "Serrated and as long as your arm."},
	"wisp_ember": {"name": "Wisp Ember", "type": "material", "price": 35, "desc": "A flicker of living aether."},
	# key items
	"stolen_pouch": {"name": "Your Coin Pouch", "type": "key", "price": 0, "desc": "The pouch the bandits took from you. Empty, of course."},
	"sealed_letter": {"name": "Sealed Letter", "type": "key", "price": 0, "desc": "A guild letter for delivery."},
}

const MATERIA := {
	"m_might_1": {"name": "Might Materia I", "stat": "atk", "value": 4, "price": 300},
	"m_might_2": {"name": "Might Materia II", "stat": "atk", "value": 9, "price": 1200},
	"m_ward_1": {"name": "Ward Materia I", "stat": "def", "value": 4, "price": 300},
	"m_ward_2": {"name": "Ward Materia II", "stat": "def", "value": 9, "price": 1200},
	"m_vigor_1": {"name": "Vigor Materia I", "stat": "hp", "value": 60, "price": 300},
	"m_vigor_2": {"name": "Vigor Materia II", "stat": "hp", "value": 140, "price": 1200},
	"m_crit_1": {"name": "Keen Materia I", "stat": "crit", "value": 0.03, "price": 400},
	"m_crit_2": {"name": "Keen Materia II", "stat": "crit", "value": 0.07, "price": 1500},
	"m_stamina_1": {"name": "Wind Materia I", "stat": "stamina", "value": 15, "price": 350},
	"m_haste_1": {"name": "Haste Materia I", "stat": "speed", "value": 0.04, "price": 500},
}

## Armor sets. colors map body regions (see placeholder_body.gdshader) to RGB.
## "parts" adds rigid armor pieces. Custom clothing models replace these visuals by id.
const ARMOR := {
	"none": {"name": "Smallclothes", "def": 0, "price": 0, "hidden": true,
		"colors": {"torso": "", "uarm": "", "larm": "", "hand": "", "pelvis": "#d9d2c3", "thigh": "", "shin": "", "foot": "", "bust": "#d9d2c3"}},
	"simple_tunic": {"name": "Hand-me-down Tunic", "def": 3, "price": 0,
		"colors": {"torso": "#8a7a5c", "uarm": "#8a7a5c", "larm": "", "hand": "", "pelvis": "#5b4b36", "thigh": "#5b4b36", "shin": "#5b4b36", "foot": "#3b2c20", "bust": "#8a7a5c"}, "rough": 0.9},
	"leather_set": {"name": "Hunter's Leathers", "def": 10, "price": 900, "level": 1,
		"colors": {"torso": "#6b4a2e", "uarm": "#6b4a2e", "larm": "#4a3220", "hand": "#3a2618", "pelvis": "#4a3220", "thigh": "#5a4630", "shin": "#3a2618", "foot": "#2e1f14", "bust": "#6b4a2e"}, "rough": 0.7, "parts": ["belt", "bracers"]},
	"chain_set": {"name": "Riveted Chainmail", "def": 18, "price": 2600, "level": 8,
		"colors": {"torso": "#8d9196", "uarm": "#8d9196", "larm": "#5c5f63", "hand": "#3a3022", "pelvis": "#4b3a2a", "thigh": "#8d9196", "shin": "#4b3a2a", "foot": "#2e2a26", "bust": "#8d9196"}, "rough": 0.45, "metal": 0.7, "parts": ["belt", "pauldrons_light"]},
	"plate_set": {"name": "Knightly Plate", "def": 30, "price": 7200, "level": 16,
		"colors": {"torso": "#b7bcc4", "uarm": "#b7bcc4", "larm": "#b7bcc4", "hand": "#9aa0a8", "pelvis": "#b7bcc4", "thigh": "#9aa0a8", "shin": "#b7bcc4", "foot": "#9aa0a8", "bust": "#b7bcc4"}, "rough": 0.3, "metal": 0.95, "parts": ["pauldrons_heavy", "belt"]},
	"scholar_robes": {"name": "Scholar's Robes", "def": 12, "price": 1600, "level": 4,
		"colors": {"torso": "#2c3e6b", "uarm": "#2c3e6b", "larm": "#2c3e6b", "hand": "", "pelvis": "#2c3e6b", "thigh": "#2c3e6b", "shin": "#24324f", "foot": "#2a2218", "bust": "#2c3e6b"}, "rough": 0.85, "parts": ["mantle", "belt"]},
	"ranger_garb": {"name": "Wayfarer's Garb", "def": 14, "price": 1900, "level": 6,
		"colors": {"torso": "#3d5a3a", "uarm": "#3d5a3a", "larm": "#5a4630", "hand": "#3a2618", "pelvis": "#5a4630", "thigh": "#4a5a3a", "shin": "#3a2618", "foot": "#2e1f14", "bust": "#3d5a3a"}, "rough": 0.8, "parts": ["hood_cape", "belt", "bracers"]},
	"desert_silks": {"name": "Sunmarch Silks", "def": 13, "price": 1800, "level": 6,
		"colors": {"torso": "#c9a24a", "uarm": "#e8dcc0", "larm": "#e8dcc0", "hand": "", "pelvis": "#8c2f2f", "thigh": "#e8dcc0", "shin": "#e8dcc0", "foot": "#6b4a2e", "bust": "#c9a24a"}, "rough": 0.6, "parts": ["sash"]},
	"sea_coat": {"name": "Corsair's Coat", "def": 16, "price": 2200, "level": 8,
		"colors": {"torso": "#7a1f24", "uarm": "#7a1f24", "larm": "#7a1f24", "hand": "#2a2218", "pelvis": "#2a2a34", "thigh": "#2a2a34", "shin": "#1e1a16", "foot": "#1e1a16", "bust": "#e8e0d0"}, "rough": 0.65, "parts": ["belt", "coat_tails"]},
	"dawnward_regalia": {"name": "Dawnward Regalia", "def": 45, "price": 25000, "level": 24,
		"colors": {"torso": "#f0ead8", "uarm": "#3a4a7a", "larm": "#f0ead8", "hand": "#c9a24a", "pelvis": "#3a4a7a", "thigh": "#f0ead8", "shin": "#c9a24a", "foot": "#3a2e22", "bust": "#f0ead8"}, "rough": 0.4, "metal": 0.4, "parts": ["pauldrons_light", "mantle", "belt"]},
}

## Meals: three slots, each slot targets a different side of a hunt.
##   main  -> offense & health   side -> defense & stamina   drink -> utility (speed, swim, rewards)
const MEALS := {
	"main": {
		"roast_boar": {"name": "Roast Boar Haunch", "price": 120, "desc": "+12% attack.", "buff": {"atk_pct": 0.12}},
		"seafood_stew": {"name": "Saltcrest Seafood Stew", "price": 140, "desc": "+150 max HP.", "buff": {"hp": 150}},
		"spiced_lamb": {"name": "Sunmarch Spiced Lamb", "price": 160, "desc": "+8% attack, +5% critical rate.", "buff": {"atk_pct": 0.08, "crit": 0.05}},
		"mushroom_pie": {"name": "Woodland Mushroom Pie", "price": 110, "desc": "+100 max HP, +5% attack.", "buff": {"hp": 100, "atk_pct": 0.05}},
		"drake_steak": {"name": "Seared Drake Steak", "price": 420, "desc": "+18% attack, +100 max HP.", "buff": {"atk_pct": 0.18, "hp": 100}, "level": 15},
	},
	"side": {
		"crusty_bread": {"name": "Crusty Bread", "price": 40, "desc": "+40 max stamina.", "buff": {"stamina": 40}},
		"herb_salad": {"name": "Wild Herb Salad", "price": 60, "desc": "+10% defense, faster stamina recovery.", "buff": {"def_pct": 0.10, "stamina_regen": 0.25}},
		"cheese_board": {"name": "Aged Cheese Board", "price": 80, "desc": "+18% defense.", "buff": {"def_pct": 0.18}},
		"date_pudding": {"name": "Date Pudding", "price": 90, "desc": "Heat resistance and +25 stamina.", "buff": {"heat_res": 1, "stamina": 25}},
		"kelp_rolls": {"name": "Kelp Rolls", "price": 70, "desc": "Breath lasts twice as long underwater.", "buff": {"breath": 1.0}},
	},
	"drink": {
		"spring_water": {"name": "Spring Water", "price": 10, "desc": "+5% movement speed.", "buff": {"speed": 0.05}},
		"honey_mead": {"name": "Honey Mead", "price": 60, "desc": "+15% gil from writs and quests.", "buff": {"gil_pct": 0.15}},
		"mint_tea": {"name": "Mint Tea", "price": 50, "desc": "+20% gathering yield chance, +5% speed.", "buff": {"gather": 0.2, "speed": 0.05}},
		"sailors_grog": {"name": "Sailor's Grog", "price": 70, "desc": "+30% swim speed and breath.", "buff": {"swim": 0.3, "breath": 0.3}},
		"ember_coffee": {"name": "Ember Coffee", "price": 90, "desc": "+15% experience earned.", "buff": {"xp_pct": 0.15}},
	},
}
