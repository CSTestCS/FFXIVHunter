extends RefCounted
## World map: 3 city-states, 4 towns and 18 field zones. Every region is generated from this data
## at load time. Exits sit on a region edge (side + offset along that edge) and lead to the target
## region, which must have an exit back (that is where you arrive), so the world is one continuous
## walkable map. Cluster layout:
##
##          Wavebreak --- Brinewood --- Driftwood Landing     Frostspine --- Whitewatch
##                            |  \                                |
##                    Emberreach  Saltcrest Coast --- Highmoor ---+
##                                    |                  |
##                               SALTCREST     Shattered -- Crossroads -- Verdant Reach -- VERDHOLLOW -- Thornveil
##                                             Expanse         |          /     \                          |
##                                   Scorchmouth -- Amber Wastes -- Goldsand   Mirewood -- Hollowmere ------+
##                                                    |            |      Glimmerglade        |
##                                                SUNMARCH     Cindervale                 Mossbridge
##                                                    |
##                                              Oasis of Lirae -- Dusthaven

const START_POINTS := {
	"saltcrest": {"region": "saltcrest_shore", "pos": Vector3(-205, 0, 6)},
	"verdhollow": {"region": "verdant_reach", "pos": Vector3(205, 0, 4)},
	"sunmarch": {"region": "amber_wastes", "pos": Vector3(4, 0, 205)},
}

const SKY_COAST := {"top": "#3a6fc0", "horizon": "#bcd6ef", "fog": "#c2d7ea", "fog_density": 0.0011, "sun": 1.25}
const SKY_FOREST := {"top": "#4d7fb3", "horizon": "#c4d8c4", "fog": "#9fb89a", "fog_density": 0.004, "sun": 0.95}
const SKY_DESERT := {"top": "#3a73c6", "horizon": "#f0d9ae", "fog": "#ead6ae", "fog_density": 0.0016, "sun": 1.5}
const SKY_SNOW := {"top": "#6d8fb8", "horizon": "#dde6ef", "fog": "#d8e2ec", "fog_density": 0.0045, "sun": 1.1}
const SKY_ASH := {"top": "#5a4a48", "horizon": "#b08a70", "fog": "#8a6a5a", "fog_density": 0.005, "sun": 0.9}
const SKY_CRYSTAL := {"top": "#4a5a8a", "horizon": "#b8b0d8", "fog": "#a8a0c8", "fog_density": 0.0035, "sun": 1.0}

const REGIONS := {
	# ======================================================== city-states
	"saltcrest": {
		"name": "Saltcrest", "subtitle": "City of Sails", "type": "city", "size": 256, "seed": 11,
		"biome": "coast", "base": 4.0, "amp": 1.0, "freq": 0.01, "water": 0.0, "sea": "west", "sea_start": -60.0,
		"city": "port", "music": "city_saltcrest", "exits": [{"side": "east", "offset": 0, "to": "saltcrest_shore"}],
		"waystones": [{"id": "ws_saltcrest", "pos": Vector3(10, 0, 0)}], "sky": SKY_COAST,
	},
	"verdhollow": {
		"name": "Verdhollow", "subtitle": "The Living City", "type": "city", "size": 256, "seed": 21,
		"biome": "forest", "base": 6.0, "amp": 1.0, "freq": 0.01, "water": 3.2, "lakes": [[Vector3(-40, 0, -60), 22.0]],
		"city": "forest", "music": "city_verdhollow",
		"exits": [{"side": "west", "offset": 0, "to": "verdant_reach"}, {"side": "east", "offset": 0, "to": "thornveil"}],
		"waystones": [{"id": "ws_verdhollow", "pos": Vector3(-6, 0, 10)}], "sky": SKY_FOREST,
	},
	"sunmarch": {
		"name": "Sunmarch", "subtitle": "Jewel of the Sands", "type": "city", "size": 256, "seed": 31,
		"biome": "desert", "base": 5.0, "amp": 1.0, "freq": 0.01, "water": 2.0, "lakes": [[Vector3(-60, 0, 40), 12.0]],
		"city": "desert", "music": "city_sunmarch",
		"exits": [{"side": "north", "offset": 0, "to": "amber_wastes"}, {"side": "south", "offset": 0, "to": "oasis_lirae"}],
		"waystones": [{"id": "ws_sunmarch", "pos": Vector3(0, 0, -10)}], "sky": SKY_DESERT,
	},
	# ======================================================== towns
	"driftwood_landing": {
		"name": "Driftwood Landing", "subtitle": "A fishing town on the northern shore", "type": "town", "size": 256, "seed": 41,
		"biome": "coast", "base": 4.0, "amp": 1.5, "freq": 0.01, "water": 0.0, "sea": "north", "sea_start": 70.0,
		"city": "port", "exits": [{"side": "west", "offset": 0, "to": "brinewood"}],
		"waystones": [{"id": "ws_driftwood", "pos": Vector3(0, 0, 0)}], "sky": SKY_COAST,
	},
	"whitewatch": {
		"name": "Whitewatch", "subtitle": "Outpost at the roof of the world", "type": "town", "size": 256, "seed": 42,
		"biome": "snow", "base": 30.0, "amp": 2.0, "freq": 0.01, "water": -100.0,
		"city": "snow", "exits": [{"side": "west", "offset": 0, "to": "frostspine"}],
		"waystones": [{"id": "ws_whitewatch", "pos": Vector3(0, 0, 0)}], "sky": SKY_SNOW,
	},
	"mossbridge": {
		"name": "Mossbridge", "subtitle": "Stilt village over the lake", "type": "town", "size": 256, "seed": 43,
		"biome": "forest", "base": 6.0, "amp": 1.5, "freq": 0.01, "water": 3.5, "lakes": [[Vector3(60, 0, 60), 30.0]],
		"city": "forest", "exits": [{"side": "south", "offset": 0, "to": "hollowmere"}],
		"waystones": [{"id": "ws_mossbridge", "pos": Vector3(0, 0, 0)}], "sky": SKY_FOREST,
	},
	"dusthaven": {
		"name": "Dusthaven", "subtitle": "Last well before the deep desert", "type": "town", "size": 256, "seed": 44,
		"biome": "desert", "base": 6.0, "amp": 1.5, "freq": 0.01, "water": 2.5, "lakes": [[Vector3(-50, 0, 40), 14.0]],
		"city": "desert", "exits": [{"side": "west", "offset": 0, "to": "oasis_lirae"}],
		"waystones": [{"id": "ws_dusthaven", "pos": Vector3(0, 0, 0)}], "sky": SKY_DESERT,
	},
	# ======================================================== Saltcrest fields
	"saltcrest_shore": {
		"name": "Saltcrest Coast", "subtitle": "Where the tide meets the road", "type": "field", "size": 512, "seed": 101,
		"biome": "coast", "base": 7.0, "amp": 14.0, "freq": 0.006, "water": 0.0, "sea": "south", "sea_start": 120.0,
		"exits": [{"side": "west", "offset": 0, "to": "saltcrest"}, {"side": "east", "offset": -60, "to": "highmoor"}, {"side": "north", "offset": -60, "to": "brinewood"}],
		"waystones": [{"id": "ws_coast_camp", "pos": Vector3(20, 0, -20)}],
		"spawns": [["hopper", 10], ["dune_crawler", 7], ["bandit", 4]],
		"gather": [["wild_herb", 8, "herb"], ["sea_salt", 6, "ore"], ["pearl", 5, "pearl"]], "sky": SKY_COAST,
	},
	"brinewood": {
		"name": "Brinewood", "subtitle": "Salt-twisted pines above the cliffs", "type": "field", "size": 512, "seed": 102,
		"biome": "coast", "base": 12.0, "amp": 18.0, "freq": 0.006, "water": 0.0, "sea": "north", "sea_start": 150.0, "trees": ["pine", "broadleaf"],
		"exits": [{"side": "south", "offset": -60, "to": "saltcrest_shore"}, {"side": "west", "offset": 30, "to": "wavebreak"}, {"side": "east", "offset": 30, "to": "driftwood_landing"},
			{"side": "north", "offset": -150, "to": "emberreach"}],
		"waystones": [{"id": "ws_brinewood", "pos": Vector3(0, 0, 10)}],
		"spawns": [["vale_wolf", 8], ["hopper", 6], ["bandit", 5]],
		"gather": [["ash_log", 8, "log"], ["wild_herb", 6, "herb"], ["pearl", 4, "pearl"]], "sky": SKY_COAST,
	},
	"wavebreak": {
		"name": "Wavebreak Cliffs", "subtitle": "Sea stacks and smugglers' coves", "type": "field", "size": 512, "seed": 103,
		"biome": "coast", "base": 10.0, "amp": 26.0, "freq": 0.007, "water": 0.0, "sea": "west", "sea_start": -60.0,
		"exits": [{"side": "east", "offset": 30, "to": "brinewood"}],
		"waystones": [{"id": "ws_wavebreak", "pos": Vector3(80, 0, 0)}],
		"spawns": [["dune_crawler", 9], ["bandit", 6], ["sea_hag", 4]],
		"gather": [["sea_salt", 8, "ore"], ["pearl", 8, "pearl"], ["iron_ore", 4, "ore"]], "sky": SKY_COAST,
	},
	"emberreach": {
		"name": "Emberreach", "subtitle": "The smouldering mountain", "type": "field", "size": 512, "seed": 104,
		"biome": "volcanic", "base": 24.0, "amp": 40.0, "freq": 0.005, "water": -100.0,
		"exits": [{"side": "south", "offset": -150, "to": "brinewood"}],
		"waystones": [{"id": "ws_emberreach", "pos": Vector3(-120, 0, 160)}],
		"spawns": [["magma_crab", 9], ["ember_wisp", 6], ["vale_wolf", 3]],
		"gather": [["iron_ore", 8, "ore"], ["adamant_ore", 4, "ore"], ["dawn_crystal", 2, "ore"]], "sky": SKY_ASH,
	},
	"highmoor": {
		"name": "Highmoor", "subtitle": "Heath and windswept stone", "type": "field", "size": 512, "seed": 202,
		"biome": "highland", "base": 18.0, "amp": 34.0, "freq": 0.005, "water": 9.0, "lakes": [[Vector3(60, 0, -90), 55.0]],
		"exits": [{"side": "west", "offset": -60, "to": "saltcrest_shore"}, {"side": "south", "offset": 30, "to": "crossroads"}, {"side": "north", "offset": 80, "to": "frostspine"}],
		"waystones": [{"id": "ws_highmoor", "pos": Vector3(-30, 0, 40)}],
		"spawns": [["vale_wolf", 9], ["hopper", 6], ["wisp", 4]],
		"gather": [["iron_ore", 8, "ore"], ["mythril_ore", 4, "ore"], ["wild_herb", 6, "herb"], ["pearl", 3, "pearl"]], "sky": {"top": "#56789e", "horizon": "#c5ccd4", "fog": "#b7bfc7", "fog_density": 0.0028, "sun": 1.0},
	},
	# ======================================================== central & north
	"frostspine": {
		"name": "Frostspine Highlands", "subtitle": "Where the wind never stops", "type": "field", "size": 512, "seed": 205,
		"biome": "snow", "base": 30.0, "amp": 42.0, "freq": 0.005, "water": 12.0, "lakes": [[Vector3(-60, 0, -40), 40.0]],
		"exits": [{"side": "south", "offset": 80, "to": "highmoor"}, {"side": "east", "offset": -40, "to": "whitewatch"}],
		"waystones": [{"id": "ws_frostspine", "pos": Vector3(60, 0, 120)}],
		"spawns": [["frost_wolf", 10], ["snow_hopper", 6], ["ice_wisp", 4]],
		"gather": [["mythril_ore", 6, "ore"], ["adamant_ore", 3, "ore"], ["frost_lily", 6, "herb"]], "sky": SKY_SNOW,
	},
	"crossroads": {
		"name": "Crossroads Vale", "subtitle": "Heart of the realm's roads", "type": "field", "size": 512, "seed": 303,
		"biome": "grass", "base": 8.0, "amp": 16.0, "freq": 0.0055, "water": 3.0, "lakes": [[Vector3(-80, 0, 60), 45.0], [Vector3(110, 0, -110), 30.0]],
		"exits": [{"side": "north", "offset": 30, "to": "highmoor"}, {"side": "east", "offset": 0, "to": "verdant_reach"},
			{"side": "south", "offset": -20, "to": "amber_wastes"}, {"side": "west", "offset": 0, "to": "shattered_expanse"}],
		"waystones": [{"id": "ws_crossroads", "pos": Vector3(10, 0, 0)}],
		"spawns": [["hopper", 10], ["vale_wolf", 8], ["bandit", 5]],
		"gather": [["wild_herb", 8, "herb"], ["ash_log", 6, "log"], ["iron_ore", 5, "ore"], ["pearl", 3, "pearl"]], "sky": {"top": "#3c74c2", "horizon": "#c4dbef", "fog": "#c6d8e6", "fog_density": 0.0012, "sun": 1.2},
	},
	"shattered_expanse": {
		"name": "The Shattered Expanse", "subtitle": "Crystal scars of an ancient calamity", "type": "field", "size": 512, "seed": 306,
		"biome": "crystal", "base": 12.0, "amp": 20.0, "freq": 0.006, "water": 6.0, "lakes": [[Vector3(-40, 0, 80), 35.0]],
		"exits": [{"side": "east", "offset": 0, "to": "crossroads"}],
		"waystones": [{"id": "ws_shattered", "pos": Vector3(120, 0, 0)}],
		"spawns": [["crystal_wisp", 8], ["shard_crawler", 7], ["wisp", 3]],
		"gather": [["dawn_crystal", 6, "ore"], ["mythril_ore", 5, "ore"], ["pearl", 3, "pearl"]], "sky": SKY_CRYSTAL,
	},
	# ======================================================== Verdhollow fields
	"verdant_reach": {
		"name": "Verdant Reach", "subtitle": "The old wood", "type": "field", "size": 512, "seed": 404,
		"biome": "forest", "base": 10.0, "amp": 18.0, "freq": 0.006, "water": 4.0, "lakes": [[Vector3(40, 0, 100), 38.0]],
		"exits": [{"side": "west", "offset": 0, "to": "crossroads"}, {"side": "east", "offset": 0, "to": "verdhollow"},
			{"side": "north", "offset": -40, "to": "mirewood"}, {"side": "south", "offset": -80, "to": "glimmerglade"}],
		"waystones": [{"id": "ws_verdant", "pos": Vector3(-20, 0, -10)}],
		"spawns": [["vale_wolf", 8], ["hopper", 8], ["wisp", 3], ["bandit", 3]],
		"gather": [["ash_log", 10, "log"], ["sunleaf", 6, "herb"], ["wild_herb", 6, "herb"], ["pearl", 3, "pearl"]], "sky": SKY_FOREST,
	},
	"mirewood": {
		"name": "Mirewood", "subtitle": "Fen of a thousand pools", "type": "field", "size": 512, "seed": 505,
		"biome": "swamp", "base": 3.0, "amp": 7.0, "freq": 0.008, "water": 3.2,
		"exits": [{"side": "south", "offset": -40, "to": "verdant_reach"}, {"side": "east", "offset": 60, "to": "hollowmere"}],
		"waystones": [{"id": "ws_mirewood", "pos": Vector3(-40, 0, 150)}],
		"spawns": [["marsh_toad", 10], ["wisp", 6]],
		"gather": [["toad_oil", 4, "herb"], ["sunleaf", 6, "herb"], ["mythril_ore", 5, "ore"], ["pearl", 6, "pearl"]], "sky": {"top": "#5d7480", "horizon": "#a9b5a3", "fog": "#8d9b85", "fog_density": 0.007, "sun": 0.8},
	},
	"thornveil": {
		"name": "Thornveil", "subtitle": "Where the canopy never opens", "type": "field", "size": 512, "seed": 506,
		"biome": "deepforest", "base": 12.0, "amp": 20.0, "freq": 0.006, "water": 5.0, "lakes": [[Vector3(-90, 0, -120), 25.0]],
		"exits": [{"side": "west", "offset": 0, "to": "verdhollow"}, {"side": "north", "offset": 60, "to": "hollowmere"}],
		"waystones": [{"id": "ws_thornveil", "pos": Vector3(-150, 0, 40)}],
		"spawns": [["vale_wolf", 6], ["thorn_beetle", 8], ["wisp", 4]],
		"gather": [["ash_log", 10, "log"], ["sunleaf", 8, "herb"], ["wild_herb", 6, "herb"]], "sky": {"top": "#3f6a8a", "horizon": "#9ab8a0", "fog": "#7a9a7a", "fog_density": 0.006, "sun": 0.85},
	},
	"hollowmere": {
		"name": "Hollowmere", "subtitle": "The great still lake", "type": "field", "size": 512, "seed": 507,
		"biome": "forest", "base": 7.0, "amp": 12.0, "freq": 0.006, "water": 5.0, "lakes": [[Vector3(0, 0, 0), 140.0]],
		"exits": [{"side": "south", "offset": 60, "to": "thornveil"}, {"side": "west", "offset": 60, "to": "mirewood"}, {"side": "north", "offset": 0, "to": "mossbridge"}],
		"waystones": [{"id": "ws_hollowmere", "pos": Vector3(150, 0, 150)}],
		"spawns": [["marsh_toad", 6], ["vale_wolf", 5], ["sea_hag", 4]],
		"gather": [["pearl", 10, "pearl"], ["sunleaf", 5, "herb"], ["ash_log", 5, "log"]], "sky": SKY_FOREST,
	},
	"glimmerglade": {
		"name": "Glimmerglade", "subtitle": "Woods that glow at dusk", "type": "field", "size": 512, "seed": 508,
		"biome": "glade", "base": 9.0, "amp": 14.0, "freq": 0.006, "water": 4.0, "lakes": [[Vector3(60, 0, 40), 30.0]],
		"exits": [{"side": "north", "offset": -80, "to": "verdant_reach"}],
		"waystones": [{"id": "ws_glimmerglade", "pos": Vector3(-60, 0, -120)}],
		"spawns": [["wisp", 8], ["hopper", 6], ["thorn_beetle", 4]],
		"gather": [["sunleaf", 10, "herb"], ["dawn_crystal", 3, "ore"], ["pearl", 3, "pearl"]], "sky": {"top": "#4a6aa8", "horizon": "#d0c8e8", "fog": "#b8b0d0", "fog_density": 0.004, "sun": 0.9},
	},
	# ======================================================== Sunmarch fields
	"amber_wastes": {
		"name": "Amber Wastes", "subtitle": "Sea of golden dunes", "type": "field", "size": 512, "seed": 606,
		"biome": "desert", "base": 9.0, "amp": 22.0, "freq": 0.0045, "water": 4.0, "lakes": [[Vector3(-70, 0, -30), 30.0]],
		"exits": [{"side": "north", "offset": -20, "to": "crossroads"}, {"side": "south", "offset": 0, "to": "sunmarch"},
			{"side": "east", "offset": 0, "to": "goldsand"}, {"side": "west", "offset": 40, "to": "scorchmouth"}],
		"waystones": [{"id": "ws_amber", "pos": Vector3(30, 0, 40)}],
		"spawns": [["dune_crawler", 10], ["bandit", 5], ["hopper", 4]],
		"gather": [["iron_ore", 6, "ore"], ["adamant_ore", 3, "ore"], ["sunleaf", 4, "herb"], ["pearl", 3, "pearl"]], "sky": SKY_DESERT,
	},
	"scorchmouth": {
		"name": "Scorchmouth Canyon", "subtitle": "Red rock and long shadows", "type": "field", "size": 512, "seed": 607,
		"biome": "canyon", "base": 14.0, "amp": 46.0, "freq": 0.004, "water": -100.0,
		"exits": [{"side": "east", "offset": 40, "to": "amber_wastes"}],
		"waystones": [{"id": "ws_scorchmouth", "pos": Vector3(160, 0, 60)}],
		"spawns": [["dune_crawler", 6], ["bandit", 8], ["sand_toad", 5]],
		"gather": [["iron_ore", 8, "ore"], ["adamant_ore", 5, "ore"]], "sky": {"top": "#3f6ab8", "horizon": "#e8b890", "fog": "#d8a888", "fog_density": 0.002, "sun": 1.45},
	},
	"goldsand": {
		"name": "Goldsand Flats", "subtitle": "Salt pans and mirages", "type": "field", "size": 512, "seed": 608,
		"biome": "desert", "base": 6.0, "amp": 10.0, "freq": 0.005, "water": 2.0, "lakes": [[Vector3(80, 0, 80), 25.0]],
		"exits": [{"side": "west", "offset": 0, "to": "amber_wastes"}, {"side": "north", "offset": 60, "to": "cindervale"}],
		"waystones": [{"id": "ws_goldsand", "pos": Vector3(0, 0, -40)}],
		"spawns": [["dune_crawler", 8], ["sand_toad", 6], ["hopper", 4]],
		"gather": [["sea_salt", 10, "ore"], ["sunleaf", 5, "herb"], ["iron_ore", 4, "ore"]], "sky": SKY_DESERT,
	},
	"cindervale": {
		"name": "Cindervale Mines", "subtitle": "Abandoned shafts in burnt hills", "type": "field", "size": 512, "seed": 609,
		"biome": "canyon", "base": 16.0, "amp": 34.0, "freq": 0.005, "water": -100.0,
		"exits": [{"side": "south", "offset": 60, "to": "goldsand"}],
		"waystones": [{"id": "ws_cindervale", "pos": Vector3(60, 0, 150)}],
		"spawns": [["bandit", 6], ["magma_crab", 5], ["shard_crawler", 5]],
		"gather": [["iron_ore", 10, "ore"], ["mythril_ore", 6, "ore"], ["adamant_ore", 5, "ore"]], "sky": {"top": "#4a6a98", "horizon": "#c8a888", "fog": "#a88a70", "fog_density": 0.003, "sun": 1.25},
	},
	"oasis_lirae": {
		"name": "Oasis of Lirae", "subtitle": "Palms, pools and pilgrims", "type": "field", "size": 512, "seed": 610,
		"biome": "desert", "base": 8.0, "amp": 14.0, "freq": 0.005, "water": 4.0, "lakes": [[Vector3(0, 0, 0), 70.0], [Vector3(-130, 0, 120), 25.0]],
		"trees": ["palm", "palm", "cactus"], "tree_mult": 3.0,
		"exits": [{"side": "north", "offset": 0, "to": "sunmarch"}, {"side": "east", "offset": 0, "to": "dusthaven"}],
		"waystones": [{"id": "ws_oasis", "pos": Vector3(110, 0, -110)}],
		"spawns": [["sand_toad", 7], ["dune_crawler", 6], ["bandit", 4]],
		"gather": [["pearl", 8, "pearl"], ["sunleaf", 6, "herb"], ["wild_herb", 5, "herb"]], "sky": SKY_DESERT,
	},
}

## Biome palettes and vegetation: used by Terrain and Vegetation builders.
## snow = how much of the flat ground is snow-covered; leaf overrides the canopy tint.
const BIOMES := {
	"coast": {"grass": "#6f8f45", "grass2": "#8fa35a", "rock": "#8a8478", "sand": "#d9c99a", "dirt": "#8a7253", "trees": ["palm", "broadleaf"], "tree_density": 0.25, "grass_density": 0.8, "rocks": 0.6, "ambience": "coast"},
	"highland": {"grass": "#6f7f4a", "grass2": "#8a7f52", "rock": "#7a7670", "sand": "#a49a80", "dirt": "#6f5f48", "trees": ["pine", "dead"], "tree_density": 0.35, "grass_density": 0.9, "rocks": 1.4, "ambience": "wind"},
	"grass": {"grass": "#5f8c3a", "grass2": "#86a449", "rock": "#858078", "sand": "#cdbf94", "dirt": "#86704f", "trees": ["broadleaf", "pine"], "tree_density": 0.45, "grass_density": 1.0, "rocks": 0.7, "ambience": "meadow"},
	"forest": {"grass": "#3f6a2c", "grass2": "#5b7d34", "rock": "#6f6c64", "sand": "#a8996e", "dirt": "#5e4a35", "trees": ["broadleaf", "giant", "pine"], "tree_density": 1.4, "grass_density": 1.0, "rocks": 0.6, "ambience": "forest"},
	"deepforest": {"grass": "#2f5222", "grass2": "#46642a", "rock": "#5f5c54", "sand": "#8a7d5a", "dirt": "#4a3a28", "trees": ["giant", "broadleaf", "broadleaf"], "tree_density": 2.0, "grass_density": 1.1, "rocks": 0.5, "ambience": "forest"},
	"glade": {"grass": "#4a7a4a", "grass2": "#6a9a6a", "rock": "#7a7a8a", "sand": "#b0a888", "dirt": "#5e4a45", "trees": ["broadleaf", "crystal"], "tree_density": 1.0, "grass_density": 1.0, "rocks": 0.5, "leaf": "#5a8a7a", "ambience": "forest"},
	"swamp": {"grass": "#4f5f33", "grass2": "#6a6a3a", "rock": "#5f5c54", "sand": "#6e6448", "dirt": "#4a3f2e", "trees": ["mangrove", "dead"], "tree_density": 0.9, "grass_density": 1.1, "rocks": 0.3, "ambience": "swamp"},
	"desert": {"grass": "#a8955a", "grass2": "#b9a26a", "rock": "#a07b58", "sand": "#dcb880", "dirt": "#b08a5c", "trees": ["palm", "cactus"], "tree_density": 0.12, "grass_density": 0.15, "rocks": 0.9, "ambience": "desert"},
	"canyon": {"grass": "#a87a52", "grass2": "#b88a5a", "rock": "#9a5a3a", "sand": "#c89868", "dirt": "#a86a48", "trees": ["cactus", "dead"], "tree_density": 0.08, "grass_density": 0.1, "rocks": 1.6, "ambience": "desert"},
	"snow": {"grass": "#7a8a7a", "grass2": "#8a9a8a", "rock": "#6a6e78", "sand": "#b8bcc4", "dirt": "#7a7068", "trees": ["pine", "pine", "dead"], "tree_density": 0.5, "grass_density": 0.2, "rocks": 1.2, "snow": 0.85, "leaf": "#3a5a48", "ambience": "snow"},
	"volcanic": {"grass": "#4a4038", "grass2": "#5a4a3a", "rock": "#3a3432", "sand": "#5a4a40", "dirt": "#6a3a2a", "trees": ["dead"], "tree_density": 0.15, "grass_density": 0.0, "rocks": 1.8, "ambience": "volcanic"},
	"crystal": {"grass": "#6a6a7a", "grass2": "#7a7a8e", "rock": "#5a5a6e", "sand": "#a8a4b8", "dirt": "#6a6070", "trees": ["crystal", "dead"], "tree_density": 0.4, "grass_density": 0.2, "rocks": 1.2, "ambience": "crystal"},
}
