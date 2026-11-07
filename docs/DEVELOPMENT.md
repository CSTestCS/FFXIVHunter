# Development guide

## Rules for every change

1. **No dead code.** When a feature changes, delete the scripts/shaders/data it no longer uses in
   the same commit. When a feature is removed, nothing it used may remain.
   `python3 tools/check_unused.py` fails on unreferenced scripts and shaders (CI runs it).
2. **Performance first.** New features must avoid heavy CPU/GPU work:
   * Prefer data-driven content (`scripts/data/*.gd`) over new scenes or large assets.
   * Merge static geometry (MeshKit / SurfaceTool) and use `MultiMesh` for repeated props.
   * Give distant things `visibility_range_end`; put repeated instances in chunks.
   * No per-frame physics queries for hit detection: use `Combat.in_shape` / `cone_targets`.
   * Far actors sleep (monsters > 90 m, NPCs animate at lower rates past 25 m).
   * Expensive effects (SDFGI, SSIL, volumetric fog, SSR) are gated behind quality presets in
     `Settings.apply_environment`.
3. **Keep the context log.** Append a short entry to `CONTEXT_HISTORY.txt` for every session.
4. Run the checks below before pushing.

## Checks

```bash
godot --headless --editor --quit --path .        # import / refresh class cache
godot --headless --path . -- --check             # compile every script
godot --headless --path . -- --smoke-test        # automated play-through
python3 tools/check_unused.py                    # no unused scripts
godot --path . -- --kit                          # mesh winding / normals check (needs a display)
godot --path . --resolution 1125x609 -- --smoke-test --ui-shots --shots /tmp/ui   # every menu, for layout checks
```

Visual check with screenshots (needs a GPU or software Vulkan + a display / xvfb):

```bash
godot --path . -- --smoke-test --shots /tmp/shots
godot --path . -- --preview --pose run --view front
```

## Building the Windows .exe

Install the Godot 4.5.1 export templates (Editor > Manage Export Templates), then:

```bash
godot --headless --path . --export-release "Windows Desktop" build/AetherHunter.exe
```

The `.pck` is embedded, so the result is a single `AetherHunter.exe`, plus
`AetherHunter.console.exe` (same game with a console window that shows errors, useful for bug
reports). Logs are also written to `%APPDATA%\AetherHunter\logs\godot.log`.

## Regenerating assets

```bash
python3 tools/make_placeholder_vrm.py     # placeholder bodies (numpy)
python3 tools/make_audio.py              # all music/ambience/sfx (numpy, scipy, ffmpeg+libvorbis)
python3 tools/make_audio.py battle hit_slash   # re-render only some
``` CI does this on every push
(`.github/workflows/build.yml`) and uploads it as an artifact.

## Layout

```
scripts/autoload   Settings (input, graphics, volumes), DB (data), Game (rules/state), Saves (slots), Audio
models             built-in VRM bodies / gear / hair (+ generated placeholders) - see docs/MODELS.md
audio              pre-rendered music, ambience, sound effects
scripts/data       all content: races, jobs + movesets, items/meals/armor, monsters, regions, NPCs, quests
scripts/character  VRM loading (ModelLibrary), gear/hair overlays, retargeted procedural animation, procedural parts (hair, ears, weapons)
scripts/actors     Actor base, Player, Monster + MonsterBody, Companion, NPC
scripts/world      World runtime, Terrain, Vegetation, CityBuilder
scripts/gameplay   Combat math, Fx (telegraphs/projectiles/effects), MissionRunner, Story cutscenes
scripts/ui         HUD, menus, title screen, character creator
shaders            terrain, water, foliage, grass, hair, placeholder body, telegraph, fx
tools              placeholder model generator, checks, dev test scenes (not exported)
```
