#!/usr/bin/env python3
"""Round-12 (rung R-C1) freeze: copy the working copy's files named by
manifest_r12C.sha256 into frozen-r12/, re-hash every copied file against the
manifest (none missing, none extra), write manifest_final_r12.sha256 (= r12C)
and frozen-r12.FROZEN.txt. Refuses if the working copy moved since r12C.

usage: r12_freeze.py
"""
import datetime
import hashlib
import os
import shutil
import sys

R = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
SRC = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io"
DST = os.path.join(R, "frozen-r12")


def sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def load(path):
    m = {}
    with open(path) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line:
                h, rel = line.split("  ", 1)
                m[rel] = h
    return m


def main():
    man = os.path.join(R, "manifest_r12C.sha256")
    m = load(man)
    if os.path.exists(DST):
        sys.exit(f"{DST} exists; a frozen copy is never overwritten")
    for rel, h in m.items():
        if sha(os.path.join(SRC, rel)) != h:
            sys.exit(f"the working copy moved since manifest_r12C: {rel}")
    for rel in m:
        d = os.path.join(DST, rel)
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.copy2(os.path.join(SRC, rel), d)
    found = {}
    for d, _dirs, files in os.walk(DST):
        for f in files:
            p = os.path.join(d, f)
            found[os.path.relpath(p, DST)] = sha(p)
    missing = sorted(set(m) - set(found))
    extra = sorted(set(found) - set(m))
    bad = sorted(r for r in m if r in found and found[r] != m[r])
    if missing or extra or bad:
        sys.exit(f"copy check failed: missing {missing}, extra {extra}, mismatched {bad}")
    # the changes against frozen-r11, computed (changed files with their line
    # counts, added files) and the full diff kept as evidence
    import difflib
    old = load(os.path.join(R, "manifest_final_r11.sha256"))
    changed = sorted(r for r in m if r in old and old[r] != m[r])
    added = sorted(r for r in m if r not in old)
    removed_files = sorted(r for r in old if r not in m)
    diff_lines = []
    counts = []
    for rel in changed:
        a_ = open(os.path.join(R, "frozen-r11", rel)).read().splitlines(keepends=True)
        b_ = open(os.path.join(DST, rel)).read().splitlines(keepends=True)
        d = list(difflib.unified_diff(a_, b_, "frozen-r11/" + rel, "frozen-r12/" + rel))
        diff_lines.extend(d)
        minus = sum(1 for x in d if x.startswith("-") and not x.startswith("---"))
        plus = sum(1 for x in d if x.startswith("+") and not x.startswith("+++"))
        counts.append(f"{rel} (-{minus} +{plus})")
    with open(os.path.join(R, "classifier", "rc1_changed_files_vs_r11.diff"), "w") as fh:
        fh.writelines(diff_lines)
    final = os.path.join(R, "manifest_final_r12.sha256")
    shutil.copyfile(man, final)
    list_sha = sha(final)
    binsha = open(os.path.join(R, "cli", "binaries_r12.sha256")).read().split()[0]
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%MZ")
    with open(os.path.join(R, "frozen-r12.FROZEN.txt"), "w") as fh:
        fh.write(f"""Token-I/O lane round-12 tree frozen at {stamp} (rung R-C1: the classifier variant, DESIGN_CLASSIFIER v2.2, D41 chunks; on top of frozen-r11).
copy:     {DST}/
source:   {SRC}/ (build target/ directories excluded, BASELINE.sha256 excluded as by tools/manifest.py)
manifest: {final}
          ({len(m)} files, list sha256 {list_sha} = manifest_r12C);
          all {len(m)} entries re-hashed in the copy: match, no missing, no extra.
binary:   cli/zk60_classify.r12.release.bin ({binsha}, cli/binaries_r12.sha256; build note
          cli/zk60_classify.r12.BUILD.txt), built from this tree. The next-token binary is not rebuilt:
          D36 stays on frozen-r9 / b56f1b71 (and frozen-r11 / 0c9f247c), unchanged copies.
suite:    s15 (logs/s15-suite.log) on this tree.
vs frozen-r11: {len(changed)} changed: {"; ".join(counts)}; {len(added)} added: {", ".join(added)}; {len(removed_files)} removed.
          The full diff of the changed files: classifier/rc1_changed_files_vs_r11.diff. Production lines of the
          next-token commands are unchanged; the removed lines are in the registry TEST files only (counts and
          array lengths that the classifier profile, its hash and generator sites extend).
Not a privacy acceptance. The lane's working copy may move on; this copy does not change.
""")
    print(f"frozen-r12: {len(m)} files copied and re-hashed; list sha256 {list_sha}")


if __name__ == "__main__":
    main()
