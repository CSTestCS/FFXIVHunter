#!/usr/bin/env python3
"""Fails if any script, shader or data file is not referenced anywhere else in the project.

Part of the project's "no dead code" rule: when a feature is changed or removed, its scripts must
be deleted in the same change. Run: python3 tools/check_unused.py   (CI runs it on every push)
"""
import os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
CHECK_DIRS = ["scripts", "shaders"]
ENTRY_POINTS = {"scripts/Boot.gd"}            # referenced by scenes/Boot.tscn
SEARCH_EXT = (".gd", ".gdshader", ".tscn", ".godot", ".cfg", ".py", ".md", ".yml")

def files(dirs, exts):
    for d in dirs:
        for dp, _, fs in os.walk(os.path.join(ROOT, d)):
            for f in fs:
                if f.endswith(exts):
                    yield os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, "/")

corpus = {}
for dp, dirs, fs in os.walk(ROOT):
    dirs[:] = [x for x in dirs if not x.startswith(".") and x not in ("build",)]
    for f in fs:
        if f.endswith(SEARCH_EXT):
            p = os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, "/")
            with open(os.path.join(ROOT, p), encoding="utf-8", errors="ignore") as fh:
                corpus[p] = fh.read()

unused = []
for f in files(CHECK_DIRS, (".gd", ".gdshader")):
    if f in ENTRY_POINTS:
        continue
    text = corpus.get(f, "")
    m = re.search(r"^class_name\s+(\w+)", text, re.M)
    names = [f, os.path.basename(f)]
    if m:
        names.append(m.group(1))
    used = False
    for other, content in corpus.items():
        if other == f:
            continue
        for n in names:
            if n.endswith((".gd", ".gdshader")):
                if n in content:
                    used = True
            elif re.search(r"\b%s\b" % re.escape(n), content):
                used = True
        if used:
            break
    if not used:
        unused.append(f)

if unused:
    print("Unused files (delete them, or reference them):")
    for u in unused:
        print("  " + u)
    sys.exit(1)
print("No unused scripts or shaders.")
