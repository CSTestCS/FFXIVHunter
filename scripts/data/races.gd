extends RefCounted
## Playable races, clans and every appearance option used by the character creator.
## heights are in centimetres; features name procedural parts built in PartsBuilder.

const RACES := {
	"hume": {
		"name": "Hume", "desc": "Adaptable folk found in every corner of the realm.",
		"height": {"feminine": [154, 174], "masculine": [166, 190]},
		"ears": ["human"], "tail": [], "horns": [], "head_scale": 1.0,
		"clans": {
			"lowlander": {"name": "Lowlander", "desc": "Farmers and city-dwellers of the river plains.",
				"skin": ["#f3d6c2", "#e8c0a4", "#d9a988", "#c18e6c", "#9b6b4c", "#6e4a33"]},
			"highlander": {"name": "Highlander", "desc": "Broad, hardy people from the mountain holds.",
				"skin": ["#f0cdb6", "#dcae90", "#c4916e", "#a8744f", "#7d5236", "#563725"], "muscle_bias": 0.25},
		},
	},
	"aelith": {
		"name": "Aelith", "desc": "Tall, long-lived people with keen ears and keener pride.",
		"height": {"feminine": [174, 192], "masculine": [182, 202]},
		"ears": ["long", "swept", "short_pointed"], "tail": [], "horns": [], "head_scale": 0.96,
		"clans": {
			"sylvan": {"name": "Sylvan", "desc": "Guardians of the old forests.", "skin": ["#f7e2d4", "#efd2bd", "#e0bb9f", "#cfa385"]},
			"duskborn": {"name": "Duskborn", "desc": "Dwellers of the deep, lightless places.", "skin": ["#dcdde6", "#b9bccc", "#9a9db3", "#7c7d96"]},
		},
	},
	"pipkin": {
		"name": "Pipkin", "desc": "Small in stature, great in curiosity and cleverness.",
		"height": {"feminine": [88, 100], "masculine": [88, 100]},
		"ears": ["small_pointed"], "tail": [], "horns": [], "head_scale": 1.45,
		"clans": {
			"meadowfolk": {"name": "Meadowfolk", "desc": "Cheerful farmers of the green hills.", "skin": ["#f7dcc8", "#efc9ad", "#e4b591", "#cd9a76"]},
			"dunefolk": {"name": "Dunefolk", "desc": "Sun-browned merchants of the sands.", "skin": ["#e4b48e", "#cf9a72", "#b47e57", "#8f5e3d"]},
		},
	},
	"ferran": {
		"name": "Ferran", "desc": "Nimble hunters with feline ears and tails.",
		"height": {"feminine": [150, 162], "masculine": [158, 172]},
		"ears": ["cat", "cat_tufted", "cat_folded"], "tail": ["cat_long", "cat_short"], "horns": [], "head_scale": 1.0,
		"clans": {
			"sunstalker": {"name": "Sunstalker", "desc": "Hunt by day beneath the open sky.", "skin": ["#f4dcc6", "#e6c4a5", "#d2a682", "#b28462"]},
			"moonkeeper": {"name": "Moonkeeper", "desc": "Hunt by night, in the shadow of the woods.", "skin": ["#f1e3db", "#dcc7bd", "#b9a197", "#8d7268"]},
		},
	},
	"tharn": {
		"name": "Tharn", "desc": "Towering seafarers and stonecutters of immense strength.",
		"height": {"feminine": [192, 212], "masculine": [204, 228]},
		"ears": ["human"], "tail": [], "horns": [], "head_scale": 0.92, "muscle_bias": 0.35,
		"clans": {
			"seastrider": {"name": "Seastrider", "desc": "Sailors who ride the storm-tossed waves.", "skin": ["#e9c7ab", "#d4a988", "#ba8a66", "#946646"]},
			"stonebreaker": {"name": "Stonebreaker", "desc": "Mountain-dwellers with skin like weathered slate.", "skin": ["#bfb3ad", "#9d918f", "#7d7375", "#5d555c"]},
		},
	},
	"draeki": {
		"name": "Draeki", "desc": "Horned, scale-flecked folk said to share blood with dragons.",
		"height": {"feminine": [152, 170], "masculine": [178, 198]},
		"ears": ["fin"], "tail": ["dragon"], "horns": ["swept", "crown", "curled", "straight"], "head_scale": 1.0,
		"clans": {
			"ember": {"name": "Ember", "desc": "Fierce clans from the volcanic east.", "skin": ["#f5ddd0", "#e6c0aa", "#cf9f86", "#a77561"]},
			"frost": {"name": "Frost", "desc": "Nomads of the frozen steppes.", "skin": ["#eceaf0", "#cfd0dc", "#aaaebf", "#6f7189"]},
		},
	},
	"lupar": {
		"name": "Lupar", "desc": "Powerful beastfolk with wolfish ears and a code of honour.",
		"height": {"feminine": [188, 204], "masculine": [196, 214]},
		"ears": ["wolf", "wolf_tall"], "tail": ["wolf"], "horns": [], "head_scale": 0.95, "muscle_bias": 0.3,
		"clans": {
			"packborn": {"name": "Packborn", "desc": "Who live and die by their pack.", "skin": ["#e9cbb3", "#d1aa8d", "#ae8466", "#80604b"]},
			"lonestrider": {"name": "Lonestrider", "desc": "Wanderers who walk alone.", "skin": ["#d8d0c8", "#b3a8a0", "#8c8079", "#615753"]},
		},
	},
	"leporin": {
		"name": "Leporin", "desc": "Long-eared forest wardens, graceful and swift.",
		"height": {"feminine": [176, 190], "masculine": [180, 194]},
		"ears": ["rabbit", "rabbit_lop", "rabbit_short"], "tail": [], "horns": [], "head_scale": 0.97,
		"clans": {
			"glade": {"name": "Glade", "desc": "Keepers of the sunlit groves.", "skin": ["#f7e5d8", "#eccfba", "#d8b093", "#b98d6c"]},
			"veil": {"name": "Veil", "desc": "Who guard the mist-wreathed hollows.", "skin": ["#ece6ea", "#d1c7d2", "#a99fb1", "#7a7088"]},
		},
	},
}

const HAIRSTYLES := [
	{"id": "crop", "name": "Short Crop"},
	{"id": "swept", "name": "Swept Fringe"},
	{"id": "long", "name": "Long & Straight"},
	{"id": "ponytail", "name": "High Ponytail"},
	{"id": "twintails", "name": "Twin Tails"},
	{"id": "bob", "name": "Bob Cut"},
	{"id": "spiky", "name": "Spiky"},
	{"id": "braid", "name": "Long Braid"},
	{"id": "topknot", "name": "Top Knot"},
	{"id": "buzz", "name": "Buzzed"},
	{"id": "wavy", "name": "Wavy Shoulder"},
	{"id": "undercut", "name": "Side Undercut"},
	{"id": "bun", "name": "Low Bun"},
	{"id": "mohawk", "name": "Crest"},
]

const FACE_PRESETS := ["Soft", "Angular", "Round", "Sharp"]
const FACE_MARKINGS := ["None", "Cheek Stripes", "Eye Shadow Band", "Forehead Sigil", "Freckles", "War Paint", "Scar"]
const EYE_SHAPES := ["Gentle", "Keen", "Wide", "Narrow"]
const VOICES := ["Voice I", "Voice II", "Voice III", "Voice IV"]

const HAIR_COLORS := ["#1b1715", "#3b2a20", "#5c3b24", "#8a5a33", "#b98a52", "#e0c08a", "#f2e6c8", "#c9c9cf",
	"#8c1f1f", "#c24a2a", "#e07d3a", "#2e4f8c", "#4fa0d8", "#3c7a4a", "#7d4ea8", "#d77ab0", "#f5f5f5", "#2b2b38"]
const EYE_COLORS := ["#3b2a1c", "#6b4a2a", "#3e6b3a", "#2f5f8f", "#6aa6d8", "#8a8f99", "#c9a227", "#b23a3a", "#7e4fb8", "#d77ab0", "#e0e0e0", "#d9802b"]
const PAINT_COLORS := ["#a3241e", "#1f2a6b", "#1a1a1a", "#f0f0f0", "#6b2a8f", "#2a7a4a", "#d0a030"]

const DEITIES := [
	{"name": "Halvane, the Dawnfather", "month": 1}, {"name": "Merivel, the Tidemother", "month": 2},
	{"name": "Oruth, the Stonekeeper", "month": 3}, {"name": "Sylwen, the Greenwarden", "month": 4},
	{"name": "Kaelor, the Flamebearer", "month": 5}, {"name": "Ishra, the Windwalker", "month": 6},
	{"name": "Vaelith, the Starseer", "month": 7}, {"name": "Thorne, the Ironfist", "month": 8},
	{"name": "Nyssa, the Moonweaver", "month": 9}, {"name": "Draven, the Stormcaller", "month": 10},
	{"name": "Ilyra, the Lifegiver", "month": 11}, {"name": "Mordaine, the Duskwarden", "month": 12},
]

## Appearance defaults; every key here is saved and editable.
static func default_appearance() -> Dictionary:
	return {
		"race": "hume", "clan": "lowlander", "body": "feminine", "model_variant": 0,
		"height": 0.5, "muscle": 0.3, "bust": 0.5, "weight": 0.3,
		"face": 0, "eye_shape": 0, "eye_size": 0.5, "eye_color": "#2f5f8f", "eye_color_r": "#2f5f8f", "heterochromia": false,
		"skin": 1, "hair": "swept", "hair_color": "#5c3b24", "highlights": false, "highlight_color": "#b98a52",
		"marking": 0, "marking_color": "#a3241e", "ears": 0, "tail": 0, "tail_length": 0.5, "horns": 0,
		"scale_color": "#6b4a2a", "voice": 0, "lip_color": "#b46a6a",
		"first_name": "", "last_name": "", "nameday_day": 1, "nameday_month": 1, "deity": 0,
	}

static func randomize_appearance(rng: RandomNumberGenerator, race_id := "") -> Dictionary:
	var a := default_appearance()
	var race_ids := RACES.keys()
	a.race = race_id if race_id != "" else race_ids[rng.randi() % race_ids.size()]
	var r: Dictionary = RACES[a.race]
	var clans: Array = r.clans.keys()
	a.clan = clans[rng.randi() % clans.size()]
	a.body = "feminine" if rng.randf() < 0.5 else "masculine"
	a.height = rng.randf()
	a.muscle = clampf(rng.randf() * 0.6 + float(r.get("muscle_bias", 0.0)), 0, 1)
	a.bust = rng.randf()
	a.weight = rng.randf() * 0.6
	a.face = rng.randi() % FACE_PRESETS.size()
	a.eye_shape = rng.randi() % EYE_SHAPES.size()
	a.eye_size = rng.randf_range(0.3, 0.7)
	a.eye_color = EYE_COLORS[rng.randi() % EYE_COLORS.size()]
	a.eye_color_r = a.eye_color
	a.skin = rng.randi() % (r.clans[a.clan].skin as Array).size()
	a.hair = HAIRSTYLES[rng.randi() % HAIRSTYLES.size()].id
	a.hair_color = HAIR_COLORS[rng.randi() % HAIR_COLORS.size()]
	a.highlights = rng.randf() < 0.25
	a.highlight_color = HAIR_COLORS[rng.randi() % HAIR_COLORS.size()]
	a.marking = 0 if rng.randf() < 0.6 else rng.randi() % FACE_MARKINGS.size()
	a.marking_color = PAINT_COLORS[rng.randi() % PAINT_COLORS.size()]
	a.ears = rng.randi() % maxi(1, (r.ears as Array).size())
	a.tail = rng.randi() % maxi(1, (r.tail as Array).size())
	a.horns = rng.randi() % maxi(1, (r.horns as Array).size())
	a.tail_length = rng.randf()
	a.scale_color = HAIR_COLORS[rng.randi() % HAIR_COLORS.size()]
	a.voice = rng.randi() % VOICES.size()
	return a

static func height_cm(a: Dictionary) -> float:
	var r: Dictionary = RACES.get(a.race, RACES.hume)
	var rng: Array = r.height[a.body]
	return lerpf(rng[0], rng[1], float(a.height))

static func skin_color(a: Dictionary) -> Color:
	var r: Dictionary = RACES.get(a.race, RACES.hume)
	var clan: Dictionary = r.clans.get(a.clan, r.clans.values()[0])
	var tones: Array = clan.skin
	return Color(tones[clampi(int(a.skin), 0, tones.size() - 1)])
