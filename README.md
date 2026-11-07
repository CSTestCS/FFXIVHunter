# Aether Hunter

A 3D action RPG that blends **MMO-style character creation, jobs, cities and guild work** with
**Monster Hunter-style hunts and weapon movesets** and a few **Elden Ring-style** systems,
built in Godot 4.3 with VRoid (VRM) characters.

> **Play now:** download `build/AetherHunter.zip`, extract it, and run `AetherHunter.exe`
> (Windows 10/11, x86-64, Vulkan-capable GPU). The CI workflow also builds the `.exe` on every
> push (Actions → *Build & test* → artifact `AetherHunter-windows`).

## What's in the game

**Character creation**
* 8 races × 2 clans (Hume, Aelith, Pipkin, Ferran, Tharn, Draeki, Lupar, Leporin), feminine/masculine
  body, height, muscle, bust, build, face, eye shape/size/colour, heterochromia, lips, facial markings,
  14 hairstyles, hair colour + highlights, ears, tails, horns, scale colour, voice, name, nameday, guardian.
* A second tab customizes **the Lightbearer**, the realm's legendary hero (look, name and
  signature job). They appear in the story's cameos exactly as you designed them.
* All 12 jobs are available from the start. You begin outside the city tied to your job.

**Jobs = weapon types** (each with its own combo tree, heavy/charged attack, weapon art, guard
style, evade style and gauge): Paladin (sword & shield), Warrior (greataxe), Dread Knight
(greatsword), Lancer (lance), Monk (fists), Shinobi (twin daggers), Samurai (katana), Reaper
(scythe), Ranger (bow), Gunner (rifle), Sorcerer (staff), Cleric (cane, heals).

**Story** · You wake up robbed and battered on the road; a villager brings you into the city,
gives you clothes and sends you to the adventurers' guild. Once you recover, the guild offers
writs. The main story (Arc I, 13 quests) keeps you an ordinary adventurer while the heroes of the
**Dawnward Circle** and **the Lightbearer** make cameo appearances. 9 side quests add more.

**Missions** · Story quests and repeatable **guild writs** (no story, different rewards):
large monster hunts, small monster hunts, camp defense, gathering (including diving for pearls),
and escorts. Missions fail after 3 faints.

**Meals** · Eat before a hunt: **main dish** (attack/HP), **side** (defense/stamina),
**drink** (utility: speed, swimming, breath, gil, EXP, gathering).

**Combat** · Lock-on, stamina, roll/step/blink dodges with i-frames, guard, counters, charge
attacks, combos, hitstop. Monsters telegraph every heavy attack with a ground marker that fills
in during the wind-up, enrage at half health, can be staggered, and have weaknesses
(slash/blunt/pierce/magic). Large monsters: Grimtusk, Tidewyrm, Moss Colossus, Sandmaw,
Thornback Drake. **Swimming and diving** with a breath meter.

**Elden Ring touches** · Waystones (rest, respawn the wilds, fast travel, save), fainting in
the wild drops some gil where you fell (recover it before you faint again), Phoenix Plume
auto-revive, weapon arts.

**Progression** · Gil, per-job levels (cap 50), weapon upgrades (6 tiers per job), armor sets
and reinforcement, materia melding (2 weapon + 3 armor slots), learning new jobs at each city's
job guilds, and hiring a party of up to 3 AI companions.

**World** · 3 walled cities (Saltcrest, Verdhollow, Sunmarch) and 6 field regions connected by
roads at their edges into one walkable world, with day/night, lakes and sea, forests, desert.

**Saves** · 8 save slots, autosave on travel and rest.

**Controls** · Full keyboard/mouse and gamepad support for gameplay and all menus.
See *Settings* in game for the full list.

## Setting

The world, names, characters and story are **original**: the game is inspired by FFXIV,
Monster Hunter and Elden Ring mechanics, but it does not recreate their worlds, characters or
maps. The structure mirrors what was asked (three city-states, a guild, legendary heroes who have
"disbanded", a hero you design yourself) using original content.

## Your own VRoid models

See **[docs/CUSTOM_MODELS.md](docs/CUSTOM_MODELS.md)**. Put `.vrm` files in a `CustomModels`
folder next to the `.exe`; they replace the placeholders without rebuilding the game.

## Performance design

* Regions are generated from data at load time (the whole game package is ~2 MB).
* Static geometry is merged into a few meshes; trees, rocks and grass use chunked MultiMeshes
  with visibility ranges; far monsters sleep and far NPCs animate at a reduced rate.
* Hit detection is analytic (no physics queries per swing); effects share one material.
* Quality presets (Low → Ultra) gate SSAO, SSR, SSIL, SDFGI, volumetric fog, shadow distance,
  grass and vegetation density; FSR upscaling via the resolution-scale slider.

## Development

See **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)** (rules, checks, export) and
`CONTEXT_HISTORY.txt` (log of every request and change).
