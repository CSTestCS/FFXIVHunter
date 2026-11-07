#!/usr/bin/env python3
"""Renders all of the game's original music, ambience and sound effects (no external samples).

    pip install numpy scipy ; ffmpeg (with libvorbis) on PATH
    python3 tools/make_audio.py            -> audio/music/*.ogg, audio/amb/*.ogg, audio/sfx/*.wav

Music is composed procedurally per track (key, mode, tempo, chord progression, instruments) and
rendered with small physical/additive synth models (plucked strings, flute, strings, brass, reed,
bells, choir pads, drums) through a stereo reverb. Loops are seamless (reverb tail wrapped).
Pre-rendering keeps runtime CPU cost at zero beyond normal playback.
"""
import os, subprocess, tempfile, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 32000
ROOT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)

# ------------------------------------------------------------------ helpers
def t_axis(dur): return np.arange(int(dur * SR)) / SR
def mtof(m): return 440.0 * 2 ** ((m - 69) / 12)

def env(n, a, d, s, r, sus_t=None):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    out = np.zeros(n)
    i = 0
    seg = min(a_n, n); out[:seg] = np.linspace(0, 1, seg, endpoint=False) if seg else 0; i = seg
    seg = min(d_n, n - i); out[i:i + seg] = np.linspace(1, s, seg, endpoint=False); i += seg
    rel_start = max(i, n - r_n)
    out[i:rel_start] = s
    seg = n - rel_start
    if seg > 0: out[rel_start:] = np.linspace(out[rel_start - 1] if rel_start > 0 else s, 0, seg)
    return out

def lp(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "low"); return lfilter(b, a, x)
def hp(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "high"); return lfilter(b, a, x)
def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band"); return lfilter(b, a, x)

def additive(f, dur, harmonics, phase_rand=True, vib=0.0, vib_rate=5.0, vib_delay=0.2):
    t = t_axis(dur)
    fm = f * (1 + vib * np.sin(2 * np.pi * vib_rate * t) * np.clip((t - vib_delay) / 0.3, 0, 1))
    ph = 2 * np.pi * np.cumsum(fm) / SR
    out = np.zeros_like(t)
    for k, amp in harmonics:
        if f * k >= SR / 2 - 500: break
        out += amp * np.sin(k * ph + (rng.uniform(0, 6.28) if phase_rand else 0))
    return out

def saw_h(n=24): return [(k, 1.0 / k) for k in range(1, n + 1)]
def square_h(n=24): return [(k, 1.0 / k) for k in range(1, n + 1, 2)]

def ks(f, dur, bright=0.5, decay=0.996):
    """Karplus-Strong plucked string, block-vectorised."""
    n = int(dur * SR); D = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, D)
    buf = lp(buf, 1500 + 7000 * bright, 1)
    out = np.zeros(n + D + 1)
    out[:D] = buf
    i = D
    while i < n:
        end = min(i + D, n)
        prev = out[i - D:end - D + 1]
        out[i:end] = decay * 0.5 * (prev[:-1] + prev[1:]) if len(prev) > 1 else 0
        i = end
    return out[:n]

# ------------------------------------------------------------------ instruments (mono)
def inst(name, f, dur, vel=1.0):
    n = int(dur * SR)
    if name in ("harp", "pluck", "oud", "guitar"):
        tail = dur + (1.6 if name == "harp" else 0.8)
        x = ks(f, tail, {"harp": 0.7, "pluck": 0.5, "oud": 0.35, "guitar": 0.45}[name], 0.997 if name == "harp" else 0.994)
        if name == "oud": x = x + 0.3 * lp(x, 900)
        return x * vel * 0.9
    if name == "flute":
        x = additive(f, dur, [(1, 1), (2, 0.25), (3, 0.08)], vib=0.006)
        x += lp(rng.normal(0, 1, len(x)), f * 2) * 0.05
        return x * env(len(x), 0.07, 0.1, 0.85, 0.12) * vel * 0.55
    if name in ("strings", "pad", "choir"):
        h = saw_h(16)
        x = sum(additive(f * d, dur, h, vib=0.004 if name != "pad" else 0.002) for d in (0.997, 1.0, 1.004)) / 3
        if name == "choir":
            x = bp(x, 450, 1200) * 2.5 + bp(x, 2300, 3200) * 0.8
        x = lp(x, 2600 if name == "strings" else 1700)
        a = {"strings": 0.18, "pad": 0.6, "choir": 0.5}[name]
        return x * env(len(x), a, 0.2, 0.9, 0.5) * vel * (0.45 if name == "strings" else 0.35)
    if name == "brass":
        x = additive(f, dur, saw_h(20), vib=0.003)
        e = env(len(x), 0.05, 0.15, 0.8, 0.15)
        x = lp(x, 900 + 2500 * vel) * e
        return x * vel * 0.5
    if name == "reed":
        x = sum(additive(f * d, dur, square_h(15)) for d in (0.996, 1.004)) / 2
        x = lp(x, 2400) * (1 + 0.15 * np.sin(2 * np.pi * 6 * t_axis(dur)))
        return x * env(len(x), 0.03, 0.1, 0.8, 0.1) * vel * 0.32
    if name == "bell":
        t = t_axis(dur + 1.5)
        x = np.sin(2 * np.pi * f * t + 2.0 * np.exp(-t * 3) * np.sin(2 * np.pi * f * 3.5 * t)) * np.exp(-t * 2.2)
        return x * vel * 0.4
    if name == "bass":
        x = additive(f, dur, [(1, 1), (2, 0.4), (3, 0.15), (4, 0.08)])
        return lp(x, 700) * env(len(x), 0.01, 0.15, 0.7, 0.08) * vel * 0.6
    raise ValueError(name)

def drum(name, vel=1.0):
    if name == "kick":
        t = t_axis(0.45); f = 50 + 90 * np.exp(-t * 30)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8) * vel
    if name == "snare":
        t = t_axis(0.3)
        return (bp(rng.normal(0, 1, len(t)), 1200, 7000) * np.exp(-t * 14) * 0.7 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 20) * 0.5) * vel
    if name == "hat":
        t = t_axis(0.08); return hp(rng.normal(0, 1, len(t)), 7000) * np.exp(-t * 60) * 0.35 * vel
    if name == "tamb":
        t = t_axis(0.15); return hp(rng.normal(0, 1, len(t)), 6000) * np.exp(-t * 25) * (1 + 0.5 * np.sin(2 * np.pi * 40 * t)) * 0.3 * vel
    if name in ("tom", "darbuka", "taiko"):
        f0 = {"tom": 110, "darbuka": 260, "taiko": 70}[name]
        t = t_axis(0.6 if name == "taiko" else 0.3); f = f0 * (1 + 0.5 * np.exp(-t * 25))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * (6 if name == "taiko" else 14))
        x += bp(rng.normal(0, 1, len(t)), 200, 3000) * np.exp(-t * 40) * 0.2
        return x * vel
    if name == "timpani":
        t = t_axis(1.5); x = sum(np.sin(2 * np.pi * 87 * k * t) * a for k, a in ((1, 1), (1.5, 0.4), (2, 0.25)))
        return x * np.exp(-t * 2.5) * (1 - np.exp(-t * 200)) * vel * 0.8
    raise ValueError(name)

# ------------------------------------------------------------------ reverb (stereo)
def comb(x, D, g, damp):
    y = np.zeros(len(x) + D)
    xp = np.concatenate([x, np.zeros(D)])
    i = 0
    while i < len(xp):
        end = min(i + D, len(xp))
        fb = y[i - D:end - D] if i >= D else np.zeros(end - i)
        y[i:end] = xp[i:end] + g * fb
        i = end
    return lp(y[:len(x)], damp, 1)

def allpass(x, D, g):
    y = np.zeros(len(x))
    i = 0
    while i < len(x):
        end = min(i + D, len(x))
        xd = x[i - D:end - D] if i >= D else np.zeros(end - i)
        yd = y[i - D:end - D] if i >= D else np.zeros(end - i)
        y[i:end] = -g * x[i:end] + xd + g * yd
        i = end
    return y

def reverb(x, size=1.0, wet=0.3):
    outs = []
    for side, offs in ((0, 0), (1, 23)):
        acc = sum(comb(x, int((d + offs) * size), 0.8, 4500) for d in (1557, 1617, 1491, 1422, 1277, 1356))
        acc /= 6
        for d in (225, 556, 441, 341):
            acc = allpass(acc, d + offs, 0.5)
        outs.append(acc)
    return np.stack(outs) * wet

# ------------------------------------------------------------------ composition
SCALES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10],
          "lydian": [0, 2, 4, 6, 7, 9, 11], "phrygdom": [0, 1, 4, 5, 7, 8, 10], "mixo": [0, 2, 4, 5, 7, 9, 10]}

def chord(scale, root, degree, octave=4):
    s = SCALES[scale]
    def tone(k):
        return root + 12 * octave + s[k % 7] + 12 * (k // 7)
    return [tone(degree), tone(degree + 2), tone(degree + 4)]

def scale_notes(scale, root, lo, hi):
    out = []
    for o in range(2, 8):
        for iv in SCALES[scale]:
            m = root + 12 * o + iv
            if lo <= m <= hi: out.append(m)
    return sorted(out)

def melody(spec, bars, beat_s, seed):
    r = np.random.default_rng(seed)
    notes = scale_notes(spec["scale"], spec["root"], *spec.get("mel_range", (64, 84)))
    rhythms = spec.get("rhythms", [[2, 1, 1], [1, 1, 1, 1], [3, 1], [2, 2], [1.5, 0.5, 2], [1, 1, 2]])
    bpb = spec.get("beats", 4)
    events = []
    motif = None
    cur = notes[len(notes) // 2]
    for bar in range(bars):
        prog = spec["prog"][bar % len(spec["prog"])]
        ch = [n % 12 for n in chord(spec["scale"], spec["root"], prog)]
        if bar % 4 == 2 and motif is not None:
            # repeat the motif from two bars earlier, shifted to fit the new chord
            for (b, d, m) in motif:
                cand = min(notes, key=lambda n: abs(n - (m + r.choice([-2, 0, 2]))))
                events.append((bar * bpb + b, d, cand))
            continue
        rh = rhythms[r.integers(len(rhythms))]
        scale_r = bpb / sum(rh)
        b = 0.0
        this_bar = []
        for i, d in enumerate(rh):
            d = d * scale_r
            strong = (b % 2 == 0)
            pool = [n for n in notes if (n % 12 in ch) or not strong]
            pool = [n for n in pool if abs(n - cur) <= 5] or pool
            cur = int(r.choice(pool))
            if r.random() < 0.08 and i > 0:
                b += d
                continue  # rest
            this_bar.append((b, d, cur))
            b += d
        if bar % 4 == 0: motif = this_bar
        events += [(bar * bpb + bb, dd, mm) for bb, dd, mm in this_bar]
    return [(b * beat_s, d * beat_s, m) for b, d, m in events]

def render_track(spec, seed):
    bpm = spec["bpm"]; beat = 60.0 / bpm; bpb = spec.get("beats", 4)
    bars = spec.get("bars", 16)
    length = bars * bpb * beat
    total = int((length + 4.0) * SR)
    L = np.zeros(total); R = np.zeros(total); send = np.zeros(total)

    def place(x, start, pan=0.0, rev=0.3, gain=1.0):
        i = max(0, int(start * SR))
        if i >= total: return
        x = x[: total - i] * gain
        L[i:i + len(x)] += x * np.sqrt(0.5 * (1 - pan))
        R[i:i + len(x)] += x * np.sqrt(0.5 * (1 + pan))
        send[i:i + len(x)] += x * rev

    r = np.random.default_rng(seed)
    for bar in range(bars):
        deg = spec["prog"][bar % len(spec["prog"])]
        t0 = bar * bpb * beat
        ch = chord(spec["scale"], spec["root"], deg, spec.get("chord_oct", 4))
        for part in spec["parts"]:
            kind, ins = part[0], part[1]
            g = part[2] if len(part) > 2 else 1.0
            pan = part[3] if len(part) > 3 else 0.0
            if kind == "pad":
                for k, m in enumerate(ch):
                    place(inst(ins, mtof(m), bpb * beat * 1.02, 0.7), t0, pan + (k - 1) * 0.3, 0.5, g)
            elif kind == "arp":
                pat = ch + [ch[0] + 12, ch[1] + 12, ch[2], ch[1]]
                steps = int(bpb * 2)
                for s in range(steps):
                    m = pat[s % len(pat)] + 12
                    place(inst(ins, mtof(m), beat * 0.5, 0.55 + 0.2 * (s % 2 == 0)), t0 + s * beat * 0.5, pan + 0.3 * np.sin(s), 0.35, g)
            elif kind == "strum":
                for s in spec.get("strum_beats", [0, 1.5, 2, 3]):
                    for k, m in enumerate(ch):
                        place(inst(ins, mtof(m + 12), beat * 1.0, 0.6), t0 + s * beat + k * 0.012, pan, 0.25, g)
            elif kind == "ostinato":
                for s in range(int(bpb * 2)):
                    m = ch[0] + 12 + (7 if s % 4 == 3 else 0)
                    place(inst(ins, mtof(m), beat * 0.45, 0.8 if s % 2 == 0 else 0.6), t0 + s * beat * 0.5, pan, 0.2, g)
            elif kind == "bass":
                for b in spec.get("bass_beats", [0, 2]):
                    place(inst(ins, mtof(ch[0] - 12), beat * 1.8, 0.9), t0 + b * beat, 0, 0.1, g)
            elif kind == "drums":
                for (b, name, v) in spec["groove"]:
                    if b < bpb:
                        hum = r.normal(0, 0.004)
                        place(drum(name, v * r.uniform(0.85, 1.05)), t0 + b * beat + hum, 0.15 * np.sin(b * 3.1), 0.15, g)
            elif kind == "swell" and bar % 4 == 3:
                place(drum("timpani", 0.8), t0 + (bpb - 1) * beat, 0, 0.4, g)
            elif kind == "drone" and bar % 2 == 0:
                place(inst(ins, mtof(spec["root"] + 36), bpb * beat * 2.05, 0.8), t0, 0, 0.4, g)
    for part in spec["parts"]:
        if part[0] == "melody":
            for (st, d, m) in melody(spec, bars, beat, seed + 1):
                place(inst(part[1], mtof(m), d * 0.95, 0.85), st, part[3] if len(part) > 3 else 0, 0.45, part[2] if len(part) > 2 else 1.0)
            if spec.get("counter"):
                for (st, d, m) in melody(dict(spec, mel_range=(55, 70)), bars, beat, seed + 99):
                    if r.random() < 0.6:
                        place(inst(spec["counter"], mtof(m), d * 0.95, 0.6), st, -0.4, 0.4, 0.6)
    wet = reverb(send, spec.get("room", 1.0), 0.32)
    mix = np.stack([L, R]) + wet
    # seamless loop: wrap everything past the loop point back onto the start
    n = int(length * SR)
    looped = mix[:, :n].copy()
    tail = mix[:, n:]
    looped[:, :tail.shape[1]] += tail
    return looped

def render_jingle(spec, seed):
    beat = 60.0 / spec["bpm"]
    total = int((spec["len"] + 2.5) * SR)
    L = np.zeros(total); R = np.zeros(total); send = np.zeros(total)
    for (b, d, m, ins, v) in spec["notes"]:
        x = inst(ins, mtof(m), d * beat, v)
        i = int(b * beat * SR); x = x[: total - i]
        L[i:i + len(x)] += x; R[i:i + len(x)] += x; send[i:i + len(x)] += x * 0.5
    return np.stack([L, R]) + reverb(send, 1.0, 0.3)

# ------------------------------------------------------------------ track list
G4 = [(0, "kick", 1), (1, "snare", 0.8), (2, "kick", 0.9), (3, "snare", 0.8)] + [(b * 0.5, "hat", 0.6) for b in range(8)]
TRACKS = {
    "title": {"bpm": 70, "root": 2, "scale": "lydian", "prog": [0, 4, 5, 3, 0, 4, 1, 4], "bars": 16, "room": 1.4, "mel_range": (66, 86),
              "parts": [("pad", "strings", 0.8), ("arp", "harp", 0.7), ("melody", "flute", 1.0, 0.2), ("bass", "bass", 0.6), ("swell", "", 0.6)]},
    "city_saltcrest": {"bpm": 112, "root": 7, "scale": "major", "beats": 3, "prog": [0, 3, 4, 0, 5, 3, 4, 4], "bars": 32, "bass_beats": [0],
              "strum_beats": [0, 1, 2], "rhythms": [[1, 1, 1], [2, 1], [1.5, 0.5, 1], [3]],
              "parts": [("strum", "guitar", 0.6, -0.3), ("melody", "reed", 1.0, 0.2), ("bass", "bass", 0.7), ("drums", "", 0.5)],
              "groove": [(0, "tom", 0.6), (1, "tamb", 0.6), (2, "tamb", 0.5), (2.5, "tamb", 0.4)], "counter": "flute"},
    "city_verdhollow": {"bpm": 84, "root": 4, "scale": "dorian", "prog": [0, 3, 6, 4, 0, 3, 2, 4], "bars": 16, "room": 1.3,
              "parts": [("pad", "pad", 0.6), ("arp", "harp", 0.8), ("melody", "flute", 1.0, 0.15), ("bass", "bass", 0.5)]},
    "city_sunmarch": {"bpm": 96, "root": 2, "scale": "phrygdom", "prog": [0, 1, 0, 6, 0, 1, 3, 0], "bars": 16, "mel_range": (62, 80),
              "parts": [("drone", "pad", 0.5), ("melody", "oud", 1.0, 0.1), ("ostinato", "pluck", 0.45, -0.3), ("drums", "", 0.7)],
              "groove": [(0, "taiko", 0.6), (0.5, "darbuka", 0.5), (1.5, "darbuka", 0.6), (2, "taiko", 0.5), (2.75, "darbuka", 0.4), (3, "darbuka", 0.6), (3.5, "tamb", 0.5)], "counter": "flute"},
    "town": {"bpm": 90, "root": 0, "scale": "major", "prog": [0, 5, 3, 4, 0, 5, 1, 4], "bars": 16,
              "parts": [("strum", "guitar", 0.6, -0.2), ("melody", "flute", 0.9, 0.2), ("bass", "bass", 0.5)]},
    "field_day": {"bpm": 100, "root": 9, "scale": "minor", "prog": [0, 5, 2, 6, 0, 5, 3, 4], "bars": 16, "room": 1.2,
              "parts": [("pad", "strings", 0.7), ("ostinato", "strings", 0.35, 0.3), ("melody", "brass", 0.9, -0.1), ("bass", "bass", 0.6), ("drums", "", 0.35)],
              "groove": [(0, "tom", 0.6), (1.5, "tom", 0.4), (2, "tom", 0.5), (3, "hat", 0.5), (3.5, "hat", 0.4)], "counter": "flute"},
    "field_night": {"bpm": 68, "root": 5, "scale": "lydian", "prog": [0, 1, 4, 3], "bars": 16, "room": 1.6, "mel_range": (70, 90),
              "parts": [("pad", "pad", 0.7), ("melody", "bell", 0.7, 0.3), ("bass", "bass", 0.4)]},
    "field_snow": {"bpm": 72, "root": 11, "scale": "minor", "prog": [0, 5, 3, 4], "bars": 16, "room": 1.7,
              "parts": [("pad", "choir", 0.8), ("arp", "bell", 0.35), ("melody", "flute", 0.8, 0.2), ("bass", "bass", 0.5)]},
    "field_harsh": {"bpm": 92, "root": 4, "scale": "phrygdom", "prog": [0, 1, 0, 6, 5, 6, 1, 0], "bars": 16,
              "parts": [("drone", "pad", 0.6), ("melody", "oud", 0.9), ("drums", "", 0.8)],
              "groove": [(0, "taiko", 0.9), (1, "darbuka", 0.5), (1.5, "darbuka", 0.5), (2, "taiko", 0.7), (3, "darbuka", 0.6), (3.5, "darbuka", 0.5)]},
    "battle": {"bpm": 144, "root": 2, "scale": "minor", "prog": [0, 5, 6, 4, 0, 5, 3, 4], "bars": 16, "room": 0.9, "mel_range": (62, 82),
              "parts": [("ostinato", "strings", 0.6, 0.2), ("pad", "strings", 0.5), ("melody", "brass", 1.0, -0.2), ("bass", "bass", 0.8), ("drums", "", 0.9)],
              "bass_beats": [0, 1, 2, 3], "groove": G4 + [(1.5, "kick", 0.6)]},
    "boss": {"bpm": 156, "root": 0, "scale": "minor", "prog": [0, 1, 5, 4, 0, 1, 6, 4], "bars": 16, "room": 1.1, "mel_range": (60, 80),
              "parts": [("pad", "choir", 0.9), ("ostinato", "strings", 0.7, 0.2), ("melody", "brass", 1.0, -0.2), ("bass", "bass", 0.9), ("drums", "", 1.0), ("swell", "", 0.8)],
              "bass_beats": [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], "groove": G4 + [(0.5, "kick", 0.7), (2.5, "kick", 0.7), (3.75, "snare", 0.5), (0, "taiko", 0.8), (2, "taiko", 0.7)]},
    "hero": {"bpm": 96, "root": 10, "scale": "major", "prog": [0, 4, 5, 3, 0, 4, 3, 4], "bars": 16, "room": 1.3,
              "parts": [("pad", "strings", 0.8), ("melody", "brass", 1.0), ("arp", "harp", 0.5), ("bass", "bass", 0.7), ("swell", "", 0.9), ("drums", "", 0.4)],
              "groove": [(0, "timpani", 0.6), (2, "timpani", 0.4)], "counter": "strings"},
}

JINGLES = {
    "victory": {"bpm": 120, "len": 3.0, "notes": [(0, 0.5, 70, "brass", 0.9), (0.5, 0.5, 74, "brass", 0.9), (1, 0.5, 77, "brass", 0.9), (1.5, 2.5, 82, "brass", 1.0),
               (1.5, 2.5, 70, "strings", 0.8), (1.5, 2.5, 74, "strings", 0.7), (1.5, 2.5, 77, "strings", 0.7)]},
    "level_up": {"bpm": 140, "len": 2.2, "notes": [(0, 0.5, 72, "bell", 0.9), (0.5, 0.5, 76, "bell", 0.9), (1, 0.5, 79, "bell", 0.9), (1.5, 2, 84, "bell", 1.0), (1.5, 2, 60, "strings", 0.6)]},
    "quest_accept": {"bpm": 120, "len": 1.5, "notes": [(0, 0.5, 67, "harp", 0.9), (0.5, 0.5, 71, "harp", 0.9), (1, 1.5, 74, "harp", 0.9)]},
    "quest_complete": {"bpm": 110, "len": 2.8, "notes": [(0, 0.5, 67, "harp", 0.8), (0.5, 0.5, 72, "harp", 0.8), (1, 0.5, 76, "harp", 0.8), (1.5, 2.5, 79, "flute", 0.9), (1.5, 2.5, 60, "strings", 0.6), (1.5, 2.5, 64, "strings", 0.6)]},
    "faint": {"bpm": 60, "len": 3.5, "notes": [(0, 1, 69, "strings", 0.7), (1, 1, 65, "strings", 0.7), (2, 2, 64, "strings", 0.7), (0, 4, 45, "pad", 0.7)]},
}

# ------------------------------------------------------------------ ambience
def amb(name, dur=20.0):
    n = int(dur * SR); t = t_axis(dur)
    noise = rng.normal(0, 1, n)
    out = np.zeros(n)
    def chirps(rate, lo, hi, vol):
        o = np.zeros(n)
        for _ in range(int(rate * dur)):
            st = rng.integers(0, n - SR); f0 = rng.uniform(lo, hi); ln = rng.uniform(0.05, 0.25); m = int(ln * SR)
            tt = np.arange(m) / SR
            f = f0 * (1 + 0.3 * np.sin(2 * np.pi * rng.uniform(8, 25) * tt))
            o[st:st + m] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / ln) * vol * rng.uniform(0.3, 1)
        return o
    slow = lambda rate, depth: 1 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t + rng.uniform(0, 6)))
    if name == "coast":
        out = lp(noise, 900) * (0.35 + 0.65 * np.clip(np.sin(2 * np.pi * t / 6.5) ** 2, 0, 1)) * 0.6 + hp(noise, 3000) * 0.04 + chirps(0.3, 1800, 2600, 0.05)
    elif name == "wind":
        out = bp(noise, 200, 1200) * slow(0.08, 0.7) * 0.5
    elif name == "meadow":
        out = bp(noise, 300, 1500) * slow(0.1, 0.5) * 0.15 + chirps(1.5, 2500, 5000, 0.08)
    elif name == "forest":
        out = bp(noise, 600, 3000) * slow(0.15, 0.5) * 0.1 + chirps(3.0, 1800, 4500, 0.09) + chirps(0.4, 600, 900, 0.06)
    elif name == "swamp":
        o = np.zeros(n)
        for _ in range(int(2.5 * dur)):
            st = rng.integers(0, n - SR); f = rng.uniform(90, 220); m = int(0.25 * SR); tt = np.arange(m) / SR
            o[st:st + m] += np.sign(np.sin(2 * np.pi * f * tt)) * np.exp(-tt * 12) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * tt)) * 0.08
        out = lp(o, 1200) + hp(noise, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 40 * t)) * 0.03 + bp(noise, 200, 800) * 0.08
    elif name == "desert":
        out = bp(noise, 300, 2500) * slow(0.06, 0.8) * 0.35 + hp(noise, 6000) * slow(0.2, 0.9) * 0.05
    elif name == "snow":
        out = bp(noise, 250, 900) * slow(0.05, 0.85) * 0.6 + bp(noise, 900, 1400) * slow(0.13, 0.95) * 0.15
    elif name == "volcanic":
        crack = np.zeros(n)
        for _ in range(int(25 * dur)):
            st = rng.integers(0, n - 200); crack[st:st + 60] += rng.normal(0, 1, 60) * rng.uniform(0.1, 0.5)
        out = lp(noise, 120) * 1.2 * slow(0.07, 0.5) + hp(crack, 1500) * 0.3
    elif name == "crystal":
        o = np.zeros(n)
        for _ in range(int(1.2 * dur)):
            st = rng.integers(0, n - 3 * SR); f = mtof(rng.choice([76, 79, 83, 86, 88, 91])); m = 3 * SR; tt = np.arange(m) / SR
            o[st:st + m] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 1.5) * 0.06
        out = o + bp(noise, 400, 1200) * slow(0.05, 0.6) * 0.12
    elif name == "city":
        mur = sum(bp(rng.normal(0, 1, n), f, f * 1.6) * slow(rng.uniform(0.3, 1.2), 0.8) for f in (300, 500, 800, 1200)) * 0.06
        out = mur + chirps(0.5, 1500, 3000, 0.04) + lp(noise, 600) * 0.05
    elif name == "night":
        o = np.zeros(n)
        for k in range(3):
            f = rng.uniform(4000, 5500); rate = rng.uniform(2, 4)
            o += np.sin(2 * np.pi * f * t) * (np.sin(2 * np.pi * rate * t) > 0.6) * (0.5 + 0.5 * np.sin(2 * np.pi * 60 * t)) * 0.02
        out = o + lp(noise, 500) * 0.04
    # seamless loop: crossfade the end into the start
    fade = SR
    out[:fade] = out[:fade] * np.linspace(0, 1, fade) + out[-fade:] * np.linspace(1, 0, fade)
    return out[:-fade]

def fit(x, n):
    return x[:n] if len(x) >= n else np.pad(x, (0, n - len(x)))

# ------------------------------------------------------------------ sound effects
def sfx(name):
    def nz(d): return rng.normal(0, 1, int(d * SR))
    def tt(d): return t_axis(d)
    if name in ("swing_light", "swing_heavy", "whoosh"):
        d = {"swing_light": 0.28, "swing_heavy": 0.5, "whoosh": 0.18}[name]; t = tt(d)
        sweep = np.sin(np.pi * t / d) ** 2
        x = bp(nz(d), 300 if name == "swing_heavy" else 700, 3500) * sweep
        return x * (1.2 if name == "swing_heavy" else 0.8)
    if name == "hit_slash":
        t = tt(0.3); return hp(nz(0.3), 1800) * np.exp(-t * 18) * 0.8 + np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 25) * 0.2 + fit(drum("kick", 0.4), len(t))
    if name == "hit_blunt":
        t = tt(0.35); return fit(drum("kick", 0.9), len(t)) + lp(nz(0.35), 900) * np.exp(-t * 20) * 0.8
    if name == "hit_pierce":
        t = tt(0.22); return bp(nz(0.22), 1500, 5000) * np.exp(-t * 30) * 0.8 + np.sin(2 * np.pi * 900 * t) * np.exp(-t * 30) * 0.3
    if name == "hit_magic":
        t = tt(0.5); return np.sin(2 * np.pi * (600 + 900 * np.exp(-t * 8)) * t) * np.exp(-t * 7) * 0.4 + bp(nz(0.5), 800, 4000) * np.exp(-t * 10) * 0.4
    if name == "crit":
        t = tt(0.5); return fit(sfx("hit_slash"), len(t)) + np.sin(2 * np.pi * 1760 * t) * np.exp(-t * 6) * 0.3
    if name in ("block", "parry"):
        t = tt(0.6); f = 1250 if name == "block" else 1900
        x = sum(np.sin(2 * np.pi * f * k * t) * a for k, a in ((1, 1), (2.76, 0.5), (5.4, 0.25))) * np.exp(-t * (9 if name == "block" else 5))
        return x * 0.4 + hp(nz(0.6), 2500) * np.exp(-t * 40) * 0.5
    if name == "roll":
        t = tt(0.45); return lp(nz(0.45), 700) * np.sin(np.pi * t / 0.45) * 0.6
    if name.startswith("step_"):
        kind = name[5:]; t = tt(0.12)
        lo, hi, dec = {"grass": (500, 4000, 40), "stone": (200, 3000, 60), "sand": (800, 6000, 30), "snow": (300, 2500, 25), "wood": (150, 1500, 50)}[kind]
        x = bp(nz(0.12), lo, hi) * np.exp(-t * dec)
        if kind in ("stone", "wood"): x += np.sin(2 * np.pi * (120 if kind == "wood" else 90) * t) * np.exp(-t * 50) * 0.4
        return x * 0.5
    if name == "jump":
        t = tt(0.2); return bp(nz(0.2), 400, 2000) * np.exp(-t * 15) * 0.4
    if name == "land":
        t = tt(0.25); return lp(nz(0.25), 600) * np.exp(-t * 20) * 0.8 + fit(drum("kick", 0.4), len(t))
    if name in ("splash", "dive"):
        d = 0.8; t = tt(d); x = bp(nz(d), 400, 6000) * np.exp(-t * 5) * (1 - np.exp(-t * 60))
        if name == "dive": x = lp(x, 900) * 1.5
        return x * 0.6
    if name == "swim":
        t = tt(0.5); return bp(nz(0.5), 300, 2500) * np.sin(np.pi * t / 0.5) ** 2 * 0.35
    if name == "bow":
        t = tt(0.35); return np.sin(2 * np.pi * 180 * t) * np.exp(-t * 15) * 0.5 + bp(nz(0.35), 1500, 6000) * np.exp(-t * 20) * 0.3
    if name == "gun":
        t = tt(0.6); return lp(nz(0.6), 3000) * np.exp(-t * 14) * 1.2 + fit(drum("kick", 1.0), len(t)) * 0.8
    if name == "reload":
        t = tt(0.5); x = np.zeros(len(t))
        for s in (0.05, 0.3):
            i = int(s * SR); m = int(0.05 * SR); x[i:i + m] += hp(nz(0.05), 3000) * np.exp(-np.arange(m) / SR * 80) * 0.7
        return x
    if name in ("cast", "cast_big"):
        d = 0.5 if name == "cast" else 1.0; t = tt(d)
        f = 300 + 700 * t / d
        return (np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.25 + bp(nz(d), 1000, 5000) * 0.15) * np.sin(np.pi * t / d)
    if name == "fire":
        t = tt(0.8); return lp(nz(0.8), 1500) * np.exp(-t * 4) * (1 - np.exp(-t * 50)) * 0.9 + hp(nz(0.8), 4000) * np.exp(-t * 6) * 0.2
    if name == "ice":
        t = tt(0.8); x = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * r) for f, r in ((2093, 5), (2637, 6), (3136, 7), (4186, 8))) * 0.15
        return x + hp(nz(0.8), 5000) * np.exp(-t * 10) * 0.3
    if name == "thunder":
        t = tt(1.4); return lp(nz(1.4), 400) * np.exp(-t * 2.5) * 1.3 + hp(nz(1.4), 2500) * np.exp(-t * 25) * 0.8
    if name == "holy":
        t = tt(1.2); x = sum(fit(inst("bell", mtof(m), 0.3, 0.6), len(t)) for m in (84, 88, 91))
        return x * 0.7
    if name == "dark":
        t = tt(1.0); return np.sin(2 * np.pi * (90 + 40 * np.sin(2 * np.pi * 3 * t)) * t) * np.exp(-t * 3) * 0.6 + lp(nz(1.0), 500) * np.exp(-t * 4) * 0.4
    if name == "heal":
        t = tt(1.0); return sum(np.sin(2 * np.pi * mtof(m) * t) * np.exp(-t * 3) * np.clip(t * 20 - i * 2, 0, 1) for i, m in enumerate((72, 76, 79, 84))) * 0.18
    if name == "potion":
        t = tt(0.6); x = np.zeros(len(t))
        for s in (0.0, 0.15, 0.3):
            i = int(s * SR); m = int(0.12 * SR); tt2 = np.arange(m) / SR
            x[i:i + m] += np.sin(2 * np.pi * (400 + 800 * tt2 / 0.12) * tt2) * np.exp(-tt2 * 25) * 0.4
        return x
    if name in ("pickup", "gil"):
        t = tt(0.4); notes = (88, 93) if name == "gil" else (79, 86)
        x = np.zeros(len(t))
        for i, m in enumerate(notes):
            st = int(i * 0.08 * SR); y = inst("bell", mtof(m), 0.2, 0.7); y = y[: len(t) - st]; x[st:st + len(y)] += y
        return x * 0.7
    if name.startswith("ui_"):
        t = tt(0.12)
        f = {"ui_move": 1400, "ui_confirm": 1900, "ui_cancel": 700, "ui_open": 1100, "ui_page": 1600}[name]
        x = np.sin(2 * np.pi * f * t) * np.exp(-t * (60 if name == "ui_move" else 30))
        if name == "ui_confirm": x += np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t * 30) * np.clip((t - 0.04) * 200, 0, 1)
        return x * 0.35
    if name in ("roar_small", "roar_large", "growl"):
        d = {"roar_small": 0.7, "roar_large": 2.2, "growl": 1.0}[name]; t = tt(d)
        f0 = {"roar_small": 220, "roar_large": 75, "growl": 110}[name]
        f = f0 * (1 + 0.15 * np.sin(2 * np.pi * 4 * t)) * (1 - 0.3 * t / d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = sum(np.sin(k * ph) / k for k in range(1, 30))
        x = bp(tone + nz(d) * 0.6, 80, 2500) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 0.5
        x *= (1 + 0.5 * np.sin(2 * np.pi * 28 * t))
        return x * (0.45 if name != "roar_large" else 0.7)
    if name == "bite":
        t = tt(0.3); return lp(nz(0.3), 1200) * np.exp(-t * 20) + fit(drum("snare", 0.6), len(t)) * 0.5
    if name == "slam":
        t = tt(1.0); return lp(nz(1.0), 250) * np.exp(-t * 4) * 1.5 + fit(drum("taiko", 1.0), len(t))
    if name == "charge":
        t = tt(1.0); return lp(nz(1.0), 300) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) * 0.9
    if name == "breath":
        t = tt(1.5); return lp(nz(1.5), 2200) * np.sin(np.pi * t / 1.5) * 0.9
    if name == "telegraph":
        t = tt(0.5); return (np.sin(2 * np.pi * 880 * t) + np.sin(2 * np.pi * 1320 * t) * 0.5) * np.exp(-t * 6) * 0.25
    if name == "monster_die":
        t = tt(1.2); f = 160 * (1 - 0.6 * t / 1.2)
        return bp(sum(np.sin(k * 2 * np.pi * np.cumsum(f) / SR) / k for k in range(1, 12)) + nz(1.2) * 0.3, 80, 2000) * np.exp(-t * 2.5) * 0.6
    if name == "waystone":
        t = tt(2.0); return sum(np.sin(2 * np.pi * mtof(m) * t) * np.exp(-t * 1.5) * np.clip(t * 10 - i, 0, 1) for i, m in enumerate((64, 71, 76, 83, 88))) * 0.16
    if name == "eat":
        t = tt(0.6); x = np.zeros(len(t))
        for s in (0.0, 0.2, 0.4):
            i = int(s * SR); m = int(0.08 * SR); x[i:i + m] += bp(nz(0.08), 1000, 5000) * np.exp(-np.arange(m) / SR * 40) * 0.6
        return x
    raise ValueError(name)

SFX = ["swing_light", "swing_heavy", "whoosh", "hit_slash", "hit_blunt", "hit_pierce", "hit_magic", "crit", "block", "parry", "roll",
       "step_grass", "step_stone", "step_sand", "step_snow", "step_wood", "jump", "land", "splash", "dive", "swim", "bow", "gun", "reload",
       "cast", "cast_big", "fire", "ice", "thunder", "holy", "dark", "heal", "potion", "pickup", "gil", "ui_move", "ui_confirm", "ui_cancel",
       "ui_open", "ui_page", "roar_small", "roar_large", "growl", "bite", "slam", "charge", "breath", "telegraph", "monster_die", "waystone", "eat"]
AMB = ["coast", "wind", "meadow", "forest", "swamp", "desert", "snow", "volcanic", "crystal", "city", "night"]

# ------------------------------------------------------------------ output
def norm(x, peak=0.89):
    m = np.max(np.abs(x)) or 1.0
    return x * (peak / m)

def write_wav(path, x):
    x = np.atleast_2d(x)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(data.shape[0]); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.T.tobytes())

def write_ogg(path, x, q=4):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.remove(tmp)

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for d in ("music", "amb", "sfx"):
        os.makedirs(os.path.join(ROOT, d), exist_ok=True)
    for i, (name, spec) in enumerate(TRACKS.items()):
        if only and name not in only: continue
        x = norm(render_track(spec, 100 + i * 17), 0.85)
        write_ogg(os.path.join(ROOT, "music", name + ".ogg"), x)
        print("music", name, round(x.shape[1] / SR, 1), "s")
    for i, (name, spec) in enumerate(JINGLES.items()):
        if only and name not in only: continue
        write_ogg(os.path.join(ROOT, "music", name + ".ogg"), norm(render_jingle(spec, 500 + i), 0.8))
        print("jingle", name)
    for name in AMB:
        if only and name not in only: continue
        write_ogg(os.path.join(ROOT, "amb", name + ".ogg"), norm(amb(name), 0.7), 3)
        print("amb", name)
    for name in SFX:
        if only and name not in only: continue
        x = sfx(name)
        fade = min(len(x), int(0.01 * SR)); x[-fade:] *= np.linspace(1, 0, fade)
        write_wav(os.path.join(ROOT, "sfx", name + ".wav"), norm(x, 0.9))
    print("sfx", len(SFX))
