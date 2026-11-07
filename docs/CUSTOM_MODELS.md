# Using your own VRoid models

The game ships with **placeholder VRoid-style models** (`models/placeholder/*.vrm`). They are real
VRM files with VRoid Studio's skeleton (`J_Bip_*` bones, T-pose), loaded at runtime through the
same code path your own models will use. Drop your files in and they replace the placeholders,
**no re-export of the game needed**.

## Where to put files

Create a `CustomModels` folder in either place (first match wins):

1. Next to `AetherHunter.exe`
2. `%APPDATA%\AetherHunter\CustomModels\` (Windows user data folder)

```
CustomModels/
  bodies/
    feminine.vrm                  base body for every race (feminine body type)
    masculine.vrm                 base body for every race (masculine body type)
    ferran_feminine.vrm           optional race-specific body (overrides the one above)
  outfits/
    plate_set_feminine.vrm        full model wearing that outfit (any race)
    ferran_feminine_plate_set.vrm full model for one race + body type + outfit
  hair/
    ponytail.glb                  optional hair mesh replacing a procedural hairstyle
```

## How the lookup works

For each character the game picks the first file that exists:

1. `outfits/<race>_<body>_<outfit>.vrm`
2. `outfits/<outfit>_<body>.vrm`
3. `bodies/<race>_<body>.vrm`
4. `bodies/<body>.vrm`
5. bundled placeholder

VRoid Studio bakes clothing into the body mesh, so **an outfit is simply a full VRoid export of
your character wearing that outfit**. When the player changes armor, the model swaps.

When a race-specific file is used (steps 1 and 3) the game assumes your model already has the
race's ears, tail and horns, and does not add its own. Otherwise it attaches the procedural race
features (ears, tails, horns) to your model's head and hips bones.

## IDs

| Kind | IDs |
| --- | --- |
| body | `feminine`, `masculine` |
| race | `hume`, `aelith`, `pipkin`, `ferran`, `tharn`, `draeki`, `lupar`, `leporin` |
| outfit | `none` (smallclothes), `simple_tunic`, `leather_set`, `chain_set`, `plate_set`, `scholar_robes`, `ranger_garb`, `desert_silks`, `sea_coat`, `dawnward_regalia` |
| hair | `crop`, `swept`, `long`, `ponytail`, `twintails`, `bob`, `spiky`, `braid`, `topknot`, `buzz`, `wavy`, `undercut`, `bun`, `mohawk` |

## Exporting from VRoid Studio

* Export as **VRM 0.0 or VRM 1.0**. Both work: the game reads the VRM humanoid bone map and
  detects which way the model faces.
* Keep the default T-pose and VRoid's skeleton. Animations are procedural and retarget to any
  T-pose humanoid, so no animation files are needed.
* Height is set by the character creator (race + height slider); your model is scaled to fit.
* Material names from VRoid are used for tinting: materials containing `HAIR` take the hair
  colour, `SKIN`/`FACE`/`BODY` take the skin tone, `IRIS` takes the eye colour. Textures are kept.
* Optional blend shapes named `Bust`, `Muscle` and `Weight` are driven by the creator sliders.

## Notes

* Custom bodies keep their own hair. Procedural hairstyles are only used on placeholders, unless
  you provide `hair/<id>.glb` (attached to the head bone).
* Models are loaded once and cached, so many NPCs sharing a file cost very little extra memory.
* To regenerate the placeholders: `python3 tools/make_placeholder_vrm.py` (needs numpy).
