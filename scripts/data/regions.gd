extends RefCounted
## World map. Every region is generated from this data at load time (no huge level files).
## Exits sit on a region edge (side + offset along that edge) and lead to a matching entry
## on the target region, so regions join into one continuous, walkable world.

const START_POINTS := {
	"saltcrest": {"region": "saltcrest_shore", "pos": Vector3(-205, 0, 6)},
	"verdhollow": {"region": "verdant_reach", "pos": Vector3(205, 0, 4)},
	"sunmarch": {"region": "amber_wastes", "pos": Vector3(4, 0, 205)},
}

const REGIONS := {
	# ======================================================== cities
	"saltcrest": {
		"name": "Saltcrest", "subtitle": "City of Sails", "type": "city", "size": 256, "seed": 11,
		"biome": "coast", "base": 4.0, "amp": 1.0, "freq": 0.01, "water": 0.0, "sea": "west", "sea_start": -60.0,
		"city": "port", "exits": [{"side": "east", "offset": 0, "to": "saltcrest_shore", "entry": "west"}],
		"waystones": [{"id": "ws_saltcrest", "pos": Vector3(10, 0, 0)}],
		"sky": {"top": "#3d74c4", "horizon": "#b9d4ee", "fog": "#bcd3e8", "fog_density": 0.0012, "sun": 1.25},
	},
	"verdhollow": {
		"name": "Verdhollow", "subtitle": "The Living City", "type": "city", "size": 256, "seed": 21,
		"biome": "forest", "base": 6.0, "amp": 1.0, "freq": 0.01, "water": 3.2, "lakes": [[Vector3(-40, 0, -60), 22.0]],
		"city": "forest", "exits": [{"side": "west", "offset": 0, "to": "verdant_reach", "entry": "east"}],
		"waystones": [{"id": "ws_verdhollow", "pos": Vector3(-6, 0, 10)}],
		"sky": {"top": "#4a7fb8", "horizon": "#c6dccb", "fog": "#a9c2a4", "fog_density": 0.003, "sun": 1.0},
	},
	"sunmarch": {
		"name": "Sunmarch", "subtitle": "Jewel of the Sands", "type": "city", "size": 256, "seed": 31,
		"biome": "desert", "base": 5.0, "amp": 1.0, "freq": 0.01, "water": 2.0, "lakes": [[Vector3(0, 0, 40), 12.0]],
		"city": "desert", "exits": [{"side": "north", "offset": 0, "to": "amber_wastes", "entry": "south"}],
		"waystones": [{"id": "ws_sunmarch", "pos": Vector3(0, 0, -10)}],
		"sky": {"top": "#3f78c8", "horizon": "#f1dcb4", "fog": "#e9d6b2", "fog_density": 0.0015, "sun": 1.45},
	},
	# ======================================================== fields
	"saltcrest_shore": {
		"name": "Saltcrest Coast", "subtitle": "Where the tide meets the road", "type": "field", "size": 512, "seed": 101,
		"biome": "coast", "base": 7.0, "amp": 14.0, "freq": 0.006, "water": 0.0, "sea": "south", "sea_start": 120.0,
		"exits": [{"side": "west", "offset": 0, "to": "saltcrest", "entry": "east"}, {"side": "east", "offset": -60, "to": "highmoor", "entry": "west"}],
		"waystones": [{"id": "ws_coast_camp", "pos": Vector3(20, 0, -20)}],
		"spawns": [["hopper", 10], ["dune_crawler", 7], ["bandit", 4]],
		"gather": [["wild_herb", 8, "herb"], ["sea_salt", 6, "ore"], ["pearl", 5, "pearl"]],
		"sky": {"top": "#3a6fc0", "horizon": "#bcd6ef", "fog": "#c2d7ea", "fog_density": 0.0011, "sun": 1.25},
	},
	"highmoor": {
		"name": "Highmoor", "subtitle": "Heath and windswept stone", "type": "field", "size": 512, "seed": 202,
		"biome": "highland", "base": 18.0, "amp": 34.0, "freq": 0.005, "water": 9.0, "lakes": [[Vector3(60, 0, -90), 55.0]],
		"exits": [{"side": "west", "offset": -60, "to": "saltcrest_shore", "entry": "east"}, {"side": "south", "offset": 30, "to": "crossroads", "entry": "north"}],
		"waystones": [{"id": "ws_highmoor", "pos": Vector3(-30, 0, 40)}],
		"spawns": [["vale_wolf", 9], ["hopper", 6], ["wisp", 4]],
		"gather": [["iron_ore", 8, "ore"], ["mythril_ore", 4, "ore"], ["wild_herb", 6, "herb"], ["pearl", 3, "pearl"]],
		"sky": {"top": "#56789e", "horizon": "#c5ccd4", "fog": "#b7bfc7", "fog_density": 0.0028, "sun": 1.0},
	},
	"crossroads": {
		"name": "Crossroads Vale", "subtitle": "Heart of the realm's roads", "type": "field", "size": 512, "seed": 303,
		"biome": "grass", "base": 8.0, "amp": 16.0, "freq": 0.0055, "water": 3.0, "lakes": [[Vector3(-80, 0, 60), 45.0], [Vector3(110, 0, -110), 30.0]],
		"exits": [{"side": "north", "offset": 30, "to": "highmoor", "entry": "south"}, {"side": "east", "offset": 0, "to": "verdant_reach", "entry": "west"},
			{"side": "south", "offset": -20, "to": "amber_wastes", "entry": "north"}],
		"waystones": [{"id": "ws_crossroads", "pos": Vector3(10, 0, 0)}],
		"spawns": [["hopper", 10], ["vale_wolf", 8], ["bandit", 5]],
		"gather": [["wild_herb", 8, "herb"], ["ash_log", 6, "log"], ["iron_ore", 5, "ore"], ["pearl", 3, "pearl"]],
		"sky": {"top": "#3c74c2", "horizon": "#c4dbef", "fog": "#c6d8e6", "fog_density": 0.0012, "sun": 1.2},
	},
	"verdant_reach": {
		"name": "Verdant Reach", "subtitle": "The old wood", "type": "field", "size": 512, "seed": 404,
		"biome": "forest", "base": 10.0, "amp": 18.0, "freq": 0.006, "water": 4.0, "lakes": [[Vector3(40, 0, 100), 38.0]],
		"exits": [{"side": "west", "offset": 0, "to": "crossroads", "entry": "east"}, {"side": "east", "offset": 0, "to": "verdhollow", "entry": "west"},
			{"side": "north", "offset": -40, "to": "mirewood", "entry": "south"}],
		"waystones": [{"id": "ws_verdant", "pos": Vector3(-20, 0, -10)}],
		"spawns": [["vale_wolf", 8], ["hopper", 8], ["wisp", 3], ["bandit", 3]],
		"gather": [["ash_log", 10, "log"], ["sunleaf", 6, "herb"], ["wild_herb", 6, "herb"], ["pearl", 3, "pearl"]],
		"sky": {"top": "#4d7fb3", "horizon": "#c4d8c4", "fog": "#9fb89a", "fog_density": 0.004, "sun": 0.95},
	},
	"mirewood": {
		"name": "Mirewood", "subtitle": "Fen of a thousand pools", "type": "field", "size": 512, "seed": 505,
		"biome": "swamp", "base": 3.0, "amp": 7.0, "freq": 0.008, "water": 3.2,
		"exits": [{"side": "south", "offset": -40, "to": "verdant_reach", "entry": "north"}],
		"waystones": [{"id": "ws_mirewood", "pos": Vector3(-40, 0, 150)}],
		"spawns": [["marsh_toad", 10], ["wisp", 6]],
		"gather": [["toad_oil", 4, "herb"], ["sunleaf", 6, "herb"], ["mythril_ore", 5, "ore"], ["pearl", 6, "pearl"]],
		"sky": {"top": "#5d7480", "horizon": "#a9b5a3", "fog": "#8d9b85", "fog_density": 0.007, "sun": 0.8},
	},
	"amber_wastes": {
		"name": "Amber Wastes", "subtitle": "Sea of golden dunes", "type": "field", "size": 512, "seed": 606,
		"biome": "desert", "base": 9.0, "amp": 22.0, "freq": 0.0045, "water": 4.0, "lakes": [[Vector3(-70, 0, -30), 30.0]],
		"exits": [{"side": "north", "offset": -20, "to": "crossroads", "entry": "south"}, {"side": "south", "offset": 0, "to": "sunmarch", "entry": "north"}],
		"waystones": [{"id": "ws_amber", "pos": Vector3(30, 0, 40)}],
		"spawns": [["dune_crawler", 10], ["bandit", 5], ["hopper", 4]],
		"gather": [["iron_ore", 6, "ore"], ["adamant_ore", 3, "ore"], ["sunleaf", 4, "herb"], ["pearl", 3, "pearl"]],
		"sky": {"top": "#3a73c6", "horizon": "#f0d9ae", "fog": "#ead6ae", "fog_density": 0.0016, "sun": 1.5},
	},
}

## Biome palettes and vegetation: used by Terrain and Vegetation builders.
const BIOMES := {
	"coast": {"grass": "#6f8f45", "grass2": "#8fa35a", "rock": "#8a8478", "sand": "#d9c99a", "dirt": "#8a7253", "trees": ["palm", "broadleaf"], "tree_density": 0.25, "grass_density": 0.8, "rocks": 0.6},
	"highland": {"grass": "#6f7f4a", "grass2": "#8a7f52", "rock": "#7a7670", "sand": "#a49a80", "dirt": "#6f5f48", "trees": ["pine", "dead"], "tree_density": 0.35, "grass_density": 0.9, "rocks": 1.4},
	"grass": {"grass": "#5f8c3a", "grass2": "#86a449", "rock": "#858078", "sand": "#cdbf94", "dirt": "#86704f", "trees": ["broadleaf", "pine"], "tree_density": 0.45, "grass_density": 1.0, "rocks": 0.7},
	"forest": {"grass": "#3f6a2c", "grass2": "#5b7d34", "rock": "#6f6c64", "sand": "#a8996e", "dirt": "#5e4a35", "trees": ["broadleaf", "giant", "pine"], "tree_density": 1.4, "grass_density": 1.0, "rocks": 0.6},
	"swamp": {"grass": "#4f5f33", "grass2": "#6a6a3a", "rock": "#5f5c54", "sand": "#6e6448", "dirt": "#4a3f2e", "trees": ["mangrove", "dead"], "tree_density": 0.9, "grass_density": 1.1, "rocks": 0.3},
	"desert": {"grass": "#a8955a", "grass2": "#b9a26a", "rock": "#a07b58", "sand": "#dcb880", "dirt": "#b08a5c", "trees": ["palm", "cactus"], "tree_density": 0.12, "grass_density": 0.15, "rocks": 0.9},
}
