# Notes for AI assistants working on this repo

* Godot 4.3, GDScript, everything built in code (only `scenes/Boot.tscn` is a scene file).
* Read `docs/DEVELOPMENT.md` first. Its rules are mandatory:
  - delete scripts/shaders made unused by your change (`python3 tools/check_unused.py` must pass);
  - keep new features cheap on CPU/GPU (merge meshes, MultiMesh, visibility ranges, analytic hit tests);
  - append a dated entry to `CONTEXT_HISTORY.txt` describing the request and what changed.
* Run `--check` and `--smoke-test` (see docs) before committing.
* Content is data-driven: add jobs/monsters/quests/regions in `scripts/data/*.gd`.
* Character models: VRM files loaded at runtime (`CharacterModel.gd`); never assume a specific mesh.
* The setting, names and characters are original. Do not add copyrighted names, characters, maps or assets.
