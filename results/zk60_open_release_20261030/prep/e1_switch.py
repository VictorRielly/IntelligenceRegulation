#!/usr/bin/env python3
"""E1 switch (round 16b -> token round 19b, gate v23 -> v24): build a NEW staging tree.

Read-only over the private repo. Inputs:
  NEW  prep/inventory_r19b/candidate_files.tsv  (the repointed inventory)
  OLD  candidate_files.tsv                       (this morning's inventory)
  PRI  the pristine copy of the old staging (stage_copy output before any edit)
  STG  the old, edited staging tree (/home/victor/ir-public)
Rules:
  1. copy every NEW row with decision != exclude from the repo; check its sha256;
  2. a path whose source is UNCHANGED (same sha256 in OLD and NEW) and that was edited in STG
     (STG bytes != PRI bytes) gets STG's bytes: the morning's E2/E3/E6 edits carry forward;
  3. a path whose source is unchanged and that was removed from STG is removed again;
  4. files that exist only in STG (E4 files, synthetic loader fixtures) are copied over;
  5. a path that was edited in STG but whose source CHANGED is listed for re-application.
Writes prep/e1_switch.json. Usage: python3 -I e1_switch.py <new staging dir>
"""
import csv
import filecmp
import hashlib
import json
import os
import shutil
import sys

R = "/home/victor/IntelligenceRegulation/"
P = R + "results/zk60_open_release_20261030/"
PRI = "/tmp/claude-1000/-home-victor-IntelligenceRegulation/bcfb5879-8e60-469d-8a11-08d61fb61e65/scratchpad/ir-public-orig/"
STG = "/home/victor/ir-public/"
D = sys.argv[1].rstrip("/") + "/"
if os.path.exists(D):
    sys.exit(f"refusing: {D} exists")


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def rows(tsv):
    return {r["public_path"]: r for r in csv.DictReader(open(tsv), delimiter="\t")}


old, new = rows(P + "candidate_files.tsv"), rows(P + "prep/inventory_r19b/candidate_files.tsv")
out = {"copied": 0, "sha_mismatch": [], "carried_edit": [], "removed_again": [], "stg_only_copied": [],
       "edited_but_source_changed": [], "new_paths": [], "changed_sources": []}
for p, r in sorted(new.items()):
    if r["decision"] == "exclude":
        continue
    unchanged = p in old and old[p]["sha256"] == r["sha256"]
    if not unchanged:
        (out["changed_sources"] if p in old else out["new_paths"]).append(p)
    in_pri, in_stg = os.path.isfile(PRI + p), os.path.isfile(STG + p)
    if unchanged and in_pri and not in_stg:
        out["removed_again"].append(p)
        continue
    dst = D + p
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    edited = in_pri and in_stg and not filecmp.cmp(PRI + p, STG + p, shallow=False)
    if unchanged and edited:
        shutil.copy2(STG + p, dst)
        out["carried_edit"].append(p)
    else:
        shutil.copy2(R + r["source_path"], dst)
        if sha(dst) != r["sha256"]:
            out["sha_mismatch"].append(p)
        if edited:
            out["edited_but_source_changed"].append(p)
    out["copied"] += 1
# files only in the old staging (E4 additions, loader fixtures, tools README)
for d, ds, fs in os.walk(STG):
    for f in fs:
        rel = os.path.relpath(os.path.join(d, f), STG)
        if rel not in old and rel not in new and not os.path.exists(D + rel):
            os.makedirs(os.path.dirname(D + rel), exist_ok=True)
            shutil.copy2(STG + rel, D + rel)
            out["stg_only_copied"].append(rel)
json.dump(out, open(P + "prep/e1_switch.json", "w"), indent=1)
print(json.dumps({k: (v if isinstance(v, int) else len(v)) for k, v in out.items()}))
for k in ("edited_but_source_changed", "removed_again", "new_paths", "sha_mismatch"):
    print(k, *out[k], sep="\n  ")
