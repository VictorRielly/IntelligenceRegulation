#!/usr/bin/env python3
"""Recover lane C's lost scratch prototype from its saved subagent transcript.

The 2026-09-29 crash wiped /tmp/zk60-lane-c-20260929 before the agent saved its
patch (`lane-c-prototype.patch` was promised in PROGRESS.md and never written).
Its transcript survives.  Every Edit/Write the agent made on the scratch tree
succeeded or failed exactly once; this replays the successful ones, in order,
on a fresh copy of the restored candidate, then writes the recovered diff.

Deterministic, read-only on the candidate and the transcript, light (5 MB copy):

  python3 replay_lane_c_from_transcript.py TRANSCRIPT.jsonl CANDIDATE_DIR OUT_ROOT PATCH_OUT [--apply-cut-off]

--apply-cut-off also applies edits whose tool call was recorded but whose result never
was (the crash hit first); without it they are skipped and listed.

The transcript's last line is half-written (the VM died mid-write); unparseable
lines are counted and skipped, never guessed.  Edits whose recorded result was
an error are skipped.  Any successful edit whose old_string does not match the
tree is a hard failure: the base differs from the one the agent used.
"""
import difflib
import json
import os
import shutil
import sys
from pathlib import Path

SCRATCH = "/tmp/zk60-lane-c-20260929"
COPIED = ["hashline", "zkp-core", "private-block-kernel", "private-block-kernel-shaped"]


def apply_pure_insertions(src, old, new):
    """Fallback when `old` no longer matches verbatim because unrelated lines were
    added inside its span since the agent copied the tree (here: the driver
    overlay's `mod mvp_driver;`).  Only valid when the edit is a pure insertion:
    each inserted block is placed after the unique line of `src` that preceded it
    in `old`.  Anything else is refused, never guessed."""
    if not old.endswith("\n") and not new.endswith("\n"):
        old, new = old + "\n", new + "\n"  # the recorded strings just omit the last newline
    old_l, new_l = old.splitlines(keepends=True), new.splitlines(keepends=True)
    ops = difflib.SequenceMatcher(None, old_l, new_l, autojunk=False).get_opcodes()
    inserts = []
    for tag, i1, i2, j1, j2 in ops:
        if tag == "equal":
            continue
        if tag != "insert" or i1 == 0:
            return None
        inserts.append((old_l[i1 - 1], "".join(new_l[j1:j2])))
    out = src
    for anchor, block in inserts:
        if not anchor.strip() or out.count(anchor) != 1:
            return None
        out = out.replace(anchor, anchor + block, 1)
    return out


def load(path):
    rows, skipped = [], 0
    for line in open(path, errors="replace"):
        try:
            rows.append(json.loads(line))
        except ValueError:
            skipped += 1
    return rows, skipped


def main(transcript, candidate, out_root, patch_out, apply_cut_off=False):
    rows, skipped = load(transcript)
    uses, results, order = {}, {}, []
    for r in rows:
        content = (r.get("message") or {}).get("content")
        if not isinstance(content, list):
            continue
        for b in content:
            if b.get("type") == "tool_use":
                uses[b["id"]] = b
                order.append(b["id"])
            elif b.get("type") == "tool_result":
                results[b["tool_use_id"]] = b
    out_root, candidate = Path(out_root), Path(candidate)
    base = out_root.with_name(out_root.name + "-base")
    for d in (out_root, base):
        if d.exists():
            shutil.rmtree(d)
        d.mkdir(parents=True)
        for name in COPIED:
            shutil.copytree(candidate / name, d / name,
                            ignore=shutil.ignore_patterns("target", ".git", "__pycache__"))
    applied, skipped_ops, drift, cut_off_applied = 0, [], [], []
    for i in order:
        u = uses[i]
        if u["name"] not in ("Edit", "Write"):
            continue
        inp = u["input"]
        fp = inp.get("file_path", "")
        if not fp.startswith(SCRATCH + "/"):
            continue
        res = results.get(i)
        text = json.dumps(res.get("content")) if res else ""
        ok = bool(res) and not res.get("is_error") and (
            "has been updated" in text or "created successfully" in text)
        rel = fp[len(SCRATCH) + 1:]
        cut_off = res is None
        if cut_off and apply_cut_off:
            cut_off_applied.append(rel)  # tool call issued, crash before its result: intent known
        elif not ok:
            skipped_ops.append((u["name"], rel, "no recorded result (cut off by the crash)"
                                if cut_off else "recorded result was an error"))
            continue
        dest = out_root / rel
        if u["name"] == "Write":
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(inp["content"])
        else:
            src = dest.read_text()
            old, new = inp["old_string"], inp["new_string"]
            n = src.count(old)
            if n == 0:
                fixed = apply_pure_insertions(src, old, new)
                if fixed is None:
                    raise SystemExit(f"REPLAY MISMATCH in {rel}: old_string matches 0x and is not a "
                                     f"pure insertion (op {applied + 1}); base tree differs from the agent's")
                drift.append(rel)
                dest.write_text(fixed)
            elif n > 1 and not inp.get("replace_all"):
                raise SystemExit(f"REPLAY MISMATCH in {rel}: old_string matches {n}x (op {applied + 1})")
            else:
                dest.write_text(src.replace(old, new) if inp.get("replace_all") else src.replace(old, new, 1))
        applied += 1
    # recovered diff, unified, base -> replayed
    chunks = []
    for p in sorted(out_root.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(out_root)
        b = base / rel
        new = p.read_text().splitlines(keepends=True)
        old = b.read_text().splitlines(keepends=True) if b.exists() else []
        if old == new:
            continue
        chunks.extend(difflib.unified_diff(
            old, new, "/dev/null" if not b.exists() else f"a/{rel}", f"b/{rel}"))
    Path(patch_out).write_text("".join(chunks))
    print(json.dumps({"transcript_rows": len(rows), "unparseable_lines": skipped,
                      "ops_applied": applied, "ops_skipped": skipped_ops,
                      "applied_by_anchor_because_base_drifted": drift,
                      "applied_although_cut_off_before_result": cut_off_applied,
                      "recovered_tree": str(out_root), "patch": str(patch_out),
                      "patch_bytes": os.path.getsize(patch_out)}, indent=1))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--apply-cut-off"]
    if len(args) != 4:
        raise SystemExit(__doc__)
    main(*args, apply_cut_off="--apply-cut-off" in sys.argv)
