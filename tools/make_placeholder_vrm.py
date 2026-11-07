#!/usr/bin/env python3
"""Generates placeholder VRoid-style VRM 0.x models (feminine / masculine).

The models use VRoid Studio's bone naming (J_Bip_*), a T-pose, identity bone
rotations and face -Z, exactly like a VRoid export, so the game's runtime
loader treats them the same way it will treat your own VRoid models.

Extra data used only by placeholders:
  TEXCOORD_1.x = body region id (lets the placeholder shader paint clothing)
  morph targets: Bust, Muscle, Weight

Usage: python3 tools/make_placeholder_vrm.py   (writes models/placeholder/*.vrm)
"""
import json, math, struct, os
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "models", "placeholder")

# region ids (must match shaders/placeholder_body.gdshader)
R_HEAD, R_NECK, R_TORSO, R_UARM, R_LARM, R_HAND, R_PELVIS, R_THIGH, R_SHIN, R_FOOT, R_BUST = range(11)

def skeleton(fem):
    s = 1.0 if fem else 1.08
    sh = 0.155 if fem else 0.19      # shoulder half width
    hp = 0.088 if fem else 0.095
    J = {
        "Root": (None, (0, 0, 0)),
        "J_Bip_C_Hips": ("Root", (0, 0.92, 0)),
        "J_Bip_C_Spine": ("J_Bip_C_Hips", (0, 1.0, 0)),
        "J_Bip_C_Chest": ("J_Bip_C_Spine", (0, 1.12, 0)),
        "J_Bip_C_UpperChest": ("J_Bip_C_Chest", (0, 1.24, 0)),
        "J_Bip_C_Neck": ("J_Bip_C_UpperChest", (0, 1.37, 0)),
        "J_Bip_C_Head": ("J_Bip_C_Neck", (0, 1.445, 0)),
    }
    for side, sx in (("L", -1), ("R", 1)):
        J[f"J_Bip_{side}_Shoulder"] = ("J_Bip_C_UpperChest", (sx * 0.03, 1.335, 0))
        J[f"J_Bip_{side}_UpperArm"] = (f"J_Bip_{side}_Shoulder", (sx * sh, 1.335, 0))
        J[f"J_Bip_{side}_LowerArm"] = (f"J_Bip_{side}_UpperArm", (sx * (sh + 0.255), 1.335, 0))
        J[f"J_Bip_{side}_Hand"] = (f"J_Bip_{side}_LowerArm", (sx * (sh + 0.495), 1.335, 0))
        J[f"J_Bip_{side}_UpperLeg"] = ("J_Bip_C_Hips", (sx * hp, 0.875, 0))
        J[f"J_Bip_{side}_LowerLeg"] = (f"J_Bip_{side}_UpperLeg", (sx * hp, 0.475, 0.0))
        J[f"J_Bip_{side}_Foot"] = (f"J_Bip_{side}_LowerLeg", (sx * hp, 0.075, 0.01))
        J[f"J_Bip_{side}_ToeBase"] = (f"J_Bip_{side}_Foot", (sx * hp, 0.02, -0.1))
    return {k: (p, np.array(v, dtype=np.float64) * s) for k, (p, v) in J.items()}, s

class Builder:
    def __init__(self):
        self.pos, self.nrm, self.joints, self.weights, self.region = [], [], [], [], []
        self.idx = []
        self.morph = {"Bust": [], "Muscle": [], "Weight": []}

    def add_ring_tube(self, a, b, ra, rb, bone, parent=None, child=None, region=0, sq=(1, 1),
                      seg=14, rings=8, caps=True, muscle=0.0, weight=0.0, region_fn=None):
        a, b = np.array(a, float), np.array(b, float)
        axis = b - a; L = np.linalg.norm(axis); d = axis / L
        up = np.array([0, 0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0, 0])
        u = np.cross(d, up); u /= np.linalg.norm(u); v = np.cross(d, u)
        base = len(self.pos)
        prof = []  # (t along, radius scale, normal tilt)
        cap_n = 4 if caps else 0
        for i in range(cap_n):
            ang = (math.pi / 2) * (1 - i / cap_n)
            prof.append((-math.sin(ang) * ra / L, math.cos(ang), -math.sin(ang), "a"))
        for i in range(rings + 1):
            prof.append((i / rings, 1.0, 0.0, "m"))
        for i in range(1, cap_n + 1):
            ang = (math.pi / 2) * (i / cap_n)
            prof.append((1 + math.sin(ang) * rb / L, math.cos(ang), math.sin(ang), "b"))
        for (t, rs, ntilt, kind) in prof:
            tc = min(max(t, 0), 1)
            r = (ra + (rb - ra) * tc) * rs
            if rs < 1e-3: r = 0.0
            center = a + axis * t
            for j in range(seg):
                th = 2 * math.pi * j / seg
                dirv = (math.cos(th) * sq[0]) * u + (math.sin(th) * sq[1]) * v
                p = center + dirv * r
                n = dirv * math.sqrt(max(0, 1 - ntilt * ntilt)) + d * ntilt
                n /= (np.linalg.norm(n) + 1e-9)
                self.pos.append(p); self.nrm.append(n)
                # skin weights: blend with parent near a, with child near b
                wj = [bone, 0, 0, 0]; ww = [1.0, 0, 0, 0]
                if parent is not None and tc < 0.2:
                    k = 0.5 * (1 - tc / 0.2); wj = [bone, parent, 0, 0]; ww = [1 - k, k, 0, 0]
                elif child is not None and tc > 0.8:
                    k = 0.5 * ((tc - 0.8) / 0.2); wj = [bone, child, 0, 0]; ww = [1 - k, k, 0, 0]
                self.joints.append(wj); self.weights.append(ww)
                self.region.append(region_fn(tc) if region_fn else region)
                self.morph["Bust"].append(np.zeros(3))
                self.morph["Muscle"].append(dirv * r * muscle * (math.sin(math.pi * tc) ** 0.7))
                self.morph["Weight"].append(dirv * r * weight * (math.sin(math.pi * tc) ** 0.5))
        nr = len(prof)
        for i in range(nr - 1):
            for j in range(seg):
                a0 = base + i * seg + j; a1 = base + i * seg + (j + 1) % seg
                b0 = a0 + seg; b1 = a1 + seg
                self.idx += [a0, b0, a1, a1, b0, b1]

    def add_ellipsoid(self, c, rad, bone, region, seg=16, rings=12, bust=False, weight=0.0, muscle=0.0, wj2=None):
        c = np.array(c, float); rad = np.array(rad, float)
        base = len(self.pos)
        for i in range(rings + 1):
            ph = math.pi * i / rings
            for j in range(seg):
                th = 2 * math.pi * j / seg
                n = np.array([math.sin(ph) * math.cos(th), math.cos(ph), math.sin(ph) * math.sin(th)])
                p = c + n * rad
                nn = n / rad; nn /= np.linalg.norm(nn)
                self.pos.append(p); self.nrm.append(nn)
                if wj2: self.joints.append([bone, wj2[0], 0, 0]); self.weights.append([1 - wj2[1], wj2[1], 0, 0])
                else: self.joints.append([bone, 0, 0, 0]); self.weights.append([1, 0, 0, 0])
                self.region.append(region)
                self.morph["Bust"].append((n * rad * 0.55 + np.array([0, -0.012, -0.02])) if bust else np.zeros(3))
                self.morph["Muscle"].append(n * rad * muscle)
                self.morph["Weight"].append(n * rad * weight)
        for i in range(rings):
            for j in range(seg):
                a0 = base + i * seg + j; a1 = base + i * seg + (j + 1) % seg
                b0 = a0 + seg; b1 = a1 + seg
                self.idx += [a0, b0, a1, a1, b0, b1]

def build(fem):
    J, s = skeleton(fem)
    names = list(J.keys())
    bi = {n: i for i, n in enumerate(names)}
    P = lambda n: J[n][1]
    B = Builder()
    m = 1.0 if fem else 1.12
    # torso
    B.add_ring_tube(P("J_Bip_C_Hips") + [0, -0.07 * s, 0], P("J_Bip_C_Spine"), 0.125 * m * (1.05 if fem else 1), 0.112 * m,
                    bi["J_Bip_C_Hips"], child=bi["J_Bip_C_Spine"], region=R_PELVIS, sq=(1.0, 0.72), weight=0.25)
    B.add_ring_tube(P("J_Bip_C_Spine"), P("J_Bip_C_Chest"), 0.11 * m, 0.118 * m, bi["J_Bip_C_Spine"],
                    parent=bi["J_Bip_C_Hips"], child=bi["J_Bip_C_Chest"], region=R_TORSO, sq=(1.0, 0.7), caps=False, weight=0.35, muscle=0.08)
    B.add_ring_tube(P("J_Bip_C_Chest"), P("J_Bip_C_UpperChest"), 0.118 * m, 0.13 * m * (1 if fem else 1.12), bi["J_Bip_C_Chest"],
                    parent=bi["J_Bip_C_Spine"], child=bi["J_Bip_C_UpperChest"], region=R_TORSO, sq=(1.0, 0.72), caps=False, weight=0.25, muscle=0.15)
    B.add_ring_tube(P("J_Bip_C_UpperChest"), P("J_Bip_C_Neck") + [0, -0.01, 0], 0.13 * m * (1 if fem else 1.12), 0.06 * s,
                    bi["J_Bip_C_UpperChest"], parent=bi["J_Bip_C_Chest"], region=R_TORSO, sq=(1.0, 0.7), muscle=0.12)
    # neck / head
    B.add_ring_tube(P("J_Bip_C_Neck") - [0, 0.02, 0], P("J_Bip_C_Head") + [0, 0.02, 0], 0.045 * m, 0.042 * m, bi["J_Bip_C_Neck"],
                    parent=bi["J_Bip_C_UpperChest"], child=bi["J_Bip_C_Head"], region=R_NECK, caps=False, muscle=0.15)
    hc = P("J_Bip_C_Head") + np.array([0, 0.095, -0.008]) * s
    B.add_ellipsoid(hc, np.array([0.088, 0.112, 0.1]) * s, bi["J_Bip_C_Head"], R_HEAD, seg=20, rings=16)
    B.add_ellipsoid(hc + np.array([0, -0.055, -0.035]) * s, np.array([0.06, 0.05, 0.065]) * s * (1 if fem else 1.12),
                    bi["J_Bip_C_Head"], R_HEAD)  # jaw
    B.add_ellipsoid(hc + np.array([0, -0.012, -0.098]) * s, np.array([0.011, 0.02, 0.016]) * s, bi["J_Bip_C_Head"], R_HEAD, seg=8, rings=6)  # nose
    if fem:  # bust
        for sx in (-1, 1):
            B.add_ellipsoid(P("J_Bip_C_UpperChest") + np.array([sx * 0.058, -0.035, -0.06]) * s, np.array([0.06, 0.058, 0.05]) * s,
                            bi["J_Bip_C_UpperChest"], R_BUST, bust=True, weight=0.2)
    else:
        for sx in (-1, 1):
            B.add_ellipsoid(P("J_Bip_C_UpperChest") + np.array([sx * 0.065, -0.02, -0.05]) * s, np.array([0.075, 0.06, 0.045]) * s,
                            bi["J_Bip_C_UpperChest"], R_TORSO, muscle=0.35)
    # glutes
    for sx in (-1, 1):
        B.add_ellipsoid(P("J_Bip_C_Hips") + np.array([sx * 0.06, -0.05, 0.045]) * s, np.array([0.075, 0.08, 0.065]) * s * (1.05 if fem else 0.95),
                        bi["J_Bip_C_Hips"], R_PELVIS, weight=0.3)
    for side in ("L", "R"):
        sh_, ua, la, hd = (f"J_Bip_{side}_{k}" for k in ("Shoulder", "UpperArm", "LowerArm", "Hand"))
        ul, ll, ft, toe = (f"J_Bip_{side}_{k}" for k in ("UpperLeg", "LowerLeg", "Foot", "ToeBase"))
        sx = -1 if side == "L" else 1
        B.add_ring_tube(P(sh_), P(ua), 0.05 * m, 0.052 * m, bi[sh_], parent=bi["J_Bip_C_UpperChest"], child=bi[ua], region=R_TORSO, muscle=0.3)
        B.add_ellipsoid(P(ua) + np.array([sx * 0.0, 0.0, 0]) , np.array([0.06, 0.058, 0.06]) * m, bi[ua], R_UARM, muscle=0.35, wj2=(bi[sh_], 0.3))  # deltoid
        B.add_ring_tube(P(ua), P(la), 0.046 * m, 0.036 * m, bi[ua], parent=bi[sh_], child=bi[la], region=R_UARM, muscle=0.35, weight=0.2)
        B.add_ring_tube(P(la), P(hd), 0.037 * m, 0.027 * m, bi[la], parent=bi[ua], child=bi[hd], region=R_LARM, muscle=0.25, weight=0.1)
        hand_c = P(hd) + np.array([sx * 0.07 * s, -0.005, 0])
        B.add_ellipsoid(hand_c, np.array([0.075, 0.022, 0.045]) * s * m ** 0.5, bi[hd], R_HAND)
        B.add_ellipsoid(hand_c + np.array([-sx * 0.025, -0.01, -0.04]) * s, np.array([0.035, 0.015, 0.015]) * s, bi[hd], R_HAND, seg=8, rings=6)  # thumb
        B.add_ring_tube(P(ul) + [0, 0.03, 0], P(ll), 0.088 * m * (1.05 if fem else 1), 0.055 * m, bi[ul], parent=bi["J_Bip_C_Hips"], child=bi[ll],
                        region_fn=lambda t: R_PELVIS if t < 0.12 else R_THIGH, muscle=0.25, weight=0.35)
        B.add_ring_tube(P(ll), P(ft), 0.055 * m, 0.035 * m, bi[ll], parent=bi[ul], child=bi[ft], region=R_SHIN, muscle=0.3, weight=0.15, sq=(1, 1.1))
        B.add_ellipsoid(P(ft) + np.array([0, -0.035, -0.04]) * s, np.array([0.045, 0.035, 0.1]) * s, bi[ft], R_FOOT, wj2=(bi[toe], 0.25))
    pos = np.array(B.pos, np.float32); nrm = np.array(B.nrm, np.float32)
    return J, names, pos, nrm, np.array(B.joints, np.uint16), np.array(B.weights, np.float32), np.array(B.region, np.float32), \
        np.array(B.idx, np.uint32), {k: np.array(v, np.float32) for k, v in B.morph.items()}

HUMAN_MAP = {"J_Bip_C_Hips": "hips", "J_Bip_C_Spine": "spine", "J_Bip_C_Chest": "chest", "J_Bip_C_UpperChest": "upperChest",
             "J_Bip_C_Neck": "neck", "J_Bip_C_Head": "head"}
for side, w in (("L", "left"), ("R", "right")):
    for k, v in (("Shoulder", "Shoulder"), ("UpperArm", "UpperArm"), ("LowerArm", "LowerArm"), ("Hand", "Hand"),
                 ("UpperLeg", "UpperLeg"), ("LowerLeg", "LowerLeg"), ("Foot", "Foot"), ("ToeBase", "Toes")):
        HUMAN_MAP[f"J_Bip_{side}_{k}"] = w + v

def write_glb(path, fem):
    J, names, pos, nrm, joints, weights, region, idx, morph = build(fem)
    blob = bytearray(); views = []; accs = []
    def add(arr, target=None, comp=5126, typ="VEC3", minmax=False, normalized=False):
        while len(blob) % 4: blob.append(0)
        off = len(blob); data = arr.tobytes(); blob.extend(data)
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target: v["target"] = target
        views.append(v)
        a = {"bufferView": len(views) - 1, "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if normalized: a["normalized"] = True
        if minmax:
            a["min"] = arr.min(axis=0).tolist(); a["max"] = arr.max(axis=0).tolist()
        accs.append(a); return len(accs) - 1
    a_pos = add(pos, 34962, minmax=True); a_nrm = add(nrm, 34962)
    a_uv0 = add(np.zeros((len(pos), 2), np.float32), 34962, typ="VEC2")
    uv1 = np.stack([region, np.zeros_like(region)], 1).astype(np.float32)
    a_uv1 = add(uv1, 34962, typ="VEC2")
    # COLOR_0 = rest position (x/2+.5, y/2, z/2+.5): lets the placeholder shader place markings/fabric in rest space
    col = np.concatenate([pos[:, 0:1] / 2 + 0.5, pos[:, 1:2] / 2, pos[:, 2:3] / 2 + 0.5, np.ones((len(pos), 1), np.float32)], 1).astype(np.float32)
    a_col = add(np.clip(col, 0, 1), 34962, typ="VEC4")
    a_j = add(joints, 34962, comp=5123, typ="VEC4"); a_w = add(weights, 34962, typ="VEC4")
    a_idx = add(idx, 34963, comp=5125, typ="SCALAR")
    targets = []
    for k in ("Bust", "Muscle", "Weight"):
        targets.append({"POSITION": add(morph[k], 34962, minmax=True)})
    # nodes
    nodes = []
    ni = {}
    for n in names: ni[n] = len(nodes); nodes.append({"name": n})
    for n in names:
        par, p = J[n]
        loc = p - (J[par][1] if par else 0)
        nodes[ni[n]]["translation"] = [float(x) for x in loc]
        kids = [ni[c] for c in names if J[c][0] == n]
        if kids: nodes[ni[n]]["children"] = kids
    skin_joints = [ni[n] for n in names]
    ibm = []
    for n in names:
        p = J[n][1]; m = np.eye(4, dtype=np.float32); m[0:3, 3] = -p
        ibm.append(m.T.flatten())  # column-major
    a_ibm = add(np.array(ibm, np.float32), None, typ="MAT4")
    mesh_node = len(nodes)
    nodes.append({"name": "Body", "mesh": 0, "skin": 0})
    scene_root = len(nodes)
    nodes.append({"name": "PlaceholderVRoid_" + ("F" if fem else "M"), "children": [ni["Root"], mesh_node]})
    humanoid = [{"bone": HUMAN_MAP[n], "node": ni[n], "useDefaultValues": True} for n in names if n in HUMAN_MAP]
    gltf = {
        "asset": {"version": "2.0", "generator": "FFXIVHunter placeholder generator"},
        "extensionsUsed": ["VRM"],
        "extensions": {"VRM": {"exporterVersion": "PlaceholderGen-1.0", "specVersion": "0.0",
            "meta": {"title": "Placeholder " + ("Feminine" if fem else "Masculine"), "version": "1", "author": "FFXIVHunter",
                     "allowedUserName": "Everyone", "violentUssageName": "Allow", "sexualUssageName": "Disallow",
                     "commercialUssageName": "Allow", "licenseName": "CC0"},
            "humanoid": {"humanBones": humanoid}, "firstPerson": {}, "blendShapeMaster": {"blendShapeGroups": []},
            "secondaryAnimation": {"boneGroups": [], "colliderGroups": []}, "materialProperties": []}},
        "scene": 0, "scenes": [{"nodes": [scene_root]}], "nodes": nodes,
        "meshes": [{"name": "Body", "primitives": [{"attributes": {"POSITION": a_pos, "NORMAL": a_nrm, "TEXCOORD_0": a_uv0,
                    "TEXCOORD_1": a_uv1, "COLOR_0": a_col, "JOINTS_0": a_j, "WEIGHTS_0": a_w}, "indices": a_idx, "material": 0, "targets": targets}],
                    "weights": [0, 0, 0], "extras": {"targetNames": ["Bust", "Muscle", "Weight"]}}],
        "materials": [{"name": "PH_Body_SKIN", "pbrMetallicRoughness": {"baseColorFactor": [0.9, 0.75, 0.65, 1], "metallicFactor": 0, "roughnessFactor": 0.6}}],
        "skins": [{"joints": skin_joints, "inverseBindMatrices": a_ibm, "skeleton": ni["Root"]}],
        "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    while len(blob) % 4: blob.append(0)
    gltf["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4: js += b" "
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942)); f.write(blob)
    print(path, len(pos), "verts", len(idx) // 3, "tris")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write_glb(os.path.join(OUT, "body_feminine.vrm"), True)
    write_glb(os.path.join(OUT, "body_masculine.vrm"), False)
