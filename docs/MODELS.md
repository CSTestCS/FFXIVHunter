# Built-in VRoid models (bodies, gear, hair)

All models live inside the project under `models/` and are packed into the `.exe` when the game
is built. Players don't supply anything. Drop your `.vrm` files into the folders below, run the
build (or let CI do it), and they replace the placeholders automatically, with no code changes.

```
models/
  bodies/<race>/<clan>/<body>/*.vrm     naked base bodies: as many as you like per subrace and body type
  bodies/<race>/<body>/*.vrm            fallback for every clan of a race
  bodies/<body>/*.vrm                   fallback for every race
  gear/<piece_id>.vrm                   one equippable piece (clothing/armor), skinned to the VRoid skeleton
  gear/<piece_id>_<body>.vrm            optional: a feminine/masculine-specific version of a piece
  gear/<piece_id>_<race>_<body>.vrm     optional: a race + body-specific version (e.g. tail holes, big frames)
  hair/<hair_id>.vrm                    a hairstyle (optionally <hair_id>_<body>.vrm)
  placeholder/body_<body>.vrm           generated placeholders, used only when nothing else exists
```

## Bodies

* Put **naked** VRoid exports in `models/bodies/<race>/<clan>/<body>/`. Every file there becomes a
  choice in the character creator's **Body model** selector (shown when a folder has more than
  one file). Files are listed alphabetically; the file name (e.g. `athletic_01.vrm`) becomes the
  label.
* A body from a race folder is assumed to include that race's ears, tail and horns, so the game
  does not add its procedural ones.
* Height comes from the creator (race + slider); the model is scaled to fit. Optional blend
  shapes named `Bust`, `Muscle` and `Weight` are driven by the creator sliders, on the body and on
  any gear that has the same blend shapes.

## Gear (clothing and armor)

Gear is worn per slot like in an MMO: **head, body, hands, legs, feet**. Each piece has an id of the
form `<set>_<slot>`:

| Set | Pieces |
| --- | --- |
| `simple_tunic` (starting clothes) | `simple_tunic_head`, `_body`, `_hands`, `_legs`, `_feet` |
| `leather_set` | `leather_set_head` … `leather_set_feet` |
| `chain_set`, `plate_set`, `scholar_robes`, `ranger_garb`, `desert_silks`, `sea_coat`, `frost_furs`, `dawnward_regalia` | same pattern |

New sets: add an entry to `GEAR_SETS` in `scripts/data/items.gd` (name, defense, price, level,
piece names, placeholder colours) and drop the `.vrm` files in `models/gear/`.

**How to author a gear .vrm:** model the piece on the same VRoid base skeleton (`J_Bip_*` bones,
T-pose) and export it as VRM, containing only the garment's meshes. The game takes every mesh in the
file, re-binds its skin to the wearer's skeleton **by bone name** (VRoid names or the VRM humanoid
map), and draws it on top of the body. Unskinned meshes in a gear file follow the hips; unskinned
meshes in a hair file follow the head.

* Fit garments to your base body. If several body shapes differ a lot, provide
  `<piece_id>_<race>_<body>.vrm` variants.
* Material names containing `HAIR` take the hair colour; `SKIN`/`BODY`/`FACE` take the skin tone;
  `IRIS` takes the eye colour. Everything else keeps its texture. Transparent materials are
  switched to alpha-scissor (cheaper, sorts correctly).
* Without a `.vrm` for a piece, the placeholder body is painted with the set's colours and simple
  procedural parts (belts, pauldrons, helmets, hoods...). On a supplied body, a piece without a
  model shows nothing, so supply all the pieces you use.

## Hair

`models/hair/<hair_id>.vrm`, where the ids are `crop`, `swept`, `long`, `ponytail`, `twintails`,
`bob`, `spiky`, `braid`, `topknot`, `buzz`, `wavy`, `undercut`, `bun`, `mohawk`. Any other file
name adds a **new hairstyle** to the creator automatically. Hair materials are tinted by the
chosen hair colour, so author hair textures in light/neutral tones.

## Export settings

* VRM 0.x or 1.0 both work (the game detects which way the model faces). Use the same format for a
  body and the gear meant for it.
* Keep VRoid's skeleton and T-pose. Animations are procedural and retarget to any T-pose humanoid.

## Checking your models

```bash
godot --path . -- --preview --view front      # renders a lineup to user://preview.png
python3 tools/make_placeholder_vrm.py --test-overlays /tmp/test   # sample gear + hair overlay files
```
