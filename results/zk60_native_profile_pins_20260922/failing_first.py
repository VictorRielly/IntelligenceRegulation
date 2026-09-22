#!/usr/bin/env python3
"""Round 9h, task U3: the hole, shown against the PRE-CHANGE bytes of the gate.

    python3 results/zk60_native_profile_pins_20260922/failing_first.py

Round 9g §R9g.8 says: three Rust files on the PRIVATE ATTENTION profile's
proving and verifying path -- `hashline/src/private_attention.rs`,
`private_attention/wire.rs`, `private_attention/witness.rs` -- are named by no
pin table, while two of the four toy captures of record are attention
receipts.  This script shows that, against every pin check the gate HAD at
`28853ac` (the commit round 9g closed on), read straight out of git, so the
left-hand column keeps printing the pre-change behaviour after the change has
landed.

The trees it tests are SYNTHETIC: throwaway directories holding a copy of
every file the toy gate pins, with ONE of the three files replaced by a
tampered copy.  Every other file in the tree is byte-identical to the
worktree's, so any refusal can only be that one file's.  The tampers are one
line each and are the kind that matters, not a stray byte:

    private_attention.rs   `mod wire;` -> `pub mod wire;`
                           (the frame's internals become public API)
    wire/validate          the H opening's shape clause deleted from the
                           verifier's typed check
    witness/quantize       the prover's fixed-oracle range refusal disabled

Nothing outside the temp directory is written and nothing is compiled.

Cases
  1  the PRE-CHANGE pin machinery on each tampered tree: the two Rust pin
     tables and round 9f's manifest pins, plus a text search of the two gates
     for any mention of the three files
  2  the same three trees, IN-TREE check: refused, each naming its own file
  3  CONTROL: the tree exactly as it stands: accepted, three digests equal to
     their pins of record
  4  the lane's own bytes at `a8e4939` (read-only, from the main checkout's
     git): accepted -- identical to main, so the integration moves nothing
  5  the two gates: with the check pointed at a tampered tree, each `main`
     returns 3 and writes no record
"""
from __future__ import annotations

import contextlib
import io
import os
import shutil
import subprocess
import sys
import tempfile
import types

ROOT = "/home/victor/wt-zk60-jointview"
MAIN_TREE = "/home/victor/IntelligenceRegulation"
PRE_CHANGE_COMMIT = "28853ac"
LANE_COMMIT = "a8e4939"

sys.path.insert(0, os.path.join(ROOT, "scripts"))
import zk60_native_manifest_pins as manifest_pins  # noqa: E402
import zk60_native_mask_commit as mask_commit  # noqa: E402
import zk60_native_profile_pins as pp  # noqa: E402
import zk60_native_terminal_polys as terminal_polys  # noqa: E402

# (path, what the tamper is, the exact text replaced, its replacement)
TAMPERS = [
    (
        "hashline/src/private_attention.rs",
        "the frame module made public API",
        "mod wire;",
        "pub mod wire;",
    ),
    (
        "hashline/src/private_attention/wire.rs",
        "the verifier stops checking H's opening shape",
        "        || !hiding_ok(&r.h_open, H_GROUPS, lay.h_rows)\n",
        "",
    ),
    (
        "hashline/src/private_attention/witness.rs",
        "the prover's fixed-oracle range refusal disabled",
        "        if !(lo..=hi).contains(&q) {",
        "        if false && !(lo..=hi).contains(&q) {",
    ),
]


def git_show(tree, ref, path):
    return subprocess.run(
        ["git", "--no-pager", "-C", tree, "show", f"{ref}:{path}"],
        check=True, capture_output=True, text=True).stdout


def load_pre_change(name):
    """A scripts/ module as it stood at `28853ac`, from git, as a module."""
    src = git_show(ROOT, PRE_CHANGE_COMMIT, f"scripts/{name}.py")
    mod = types.ModuleType(name + "_pre_change")
    mod.__file__ = f"git:{PRE_CHANGE_COMMIT}:scripts/{name}.py"
    exec(compile(src, mod.__file__, "exec"), mod.__dict__)
    return mod


def pinned_tree(tmp, overrides=None):
    """A copy of every file the toy gate pins, with the given overrides."""
    d = tempfile.mkdtemp(dir=tmp)
    paths = ({p.path for p in mask_commit.SOURCE_PINS}
             | {p.path for p in mask_commit.PATH_PINS}
             | {p.path for p in terminal_polys.SOURCE_PINS}
             | {p.path for p in manifest_pins.MANIFEST_PINS}
             | {p.path for p in pp.PROFILE_PINS})
    for rel in sorted(paths):
        dst = os.path.join(d, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(os.path.join(ROOT, rel), dst)
    for rel, text in (overrides or {}).items():
        dst = os.path.join(d, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w") as fh:
            fh.write(text)
    return d


def tampered_text(rel, old, new):
    text = open(os.path.join(ROOT, rel)).read()
    if text.count(old) < 1:
        raise SystemExit(f"{rel}: the text to tamper with is not there: {old!r}")
    return text.replace(old, new, 1)


def show(label, fn):
    try:
        out = fn()
    except Exception as exc:  # noqa: BLE001 -- WHICH exception is the point
        head = str(exc).strip().splitlines()
        print(f"  {label:<14} RAISED {type(exc).__name__}: {head[0]}")
        for line in head[1:]:
            print(f"  {'':<14}        {line}")
        return
    print(f"  {label:<14} RETURNED {out}")


def main():
    pre_mask = load_pre_change("zk60_native_mask_commit")
    pre_terms = load_pre_change("zk60_native_terminal_polys")
    pre_manifests = load_pre_change("zk60_native_manifest_pins")
    print(f"pre-change modules: {pre_mask.__file__}")
    print(f"                    {pre_terms.__file__}")
    print(f"                    {pre_manifests.__file__}")
    print(f"in-tree module:     {pp.__file__}")
    print()

    tmp = tempfile.mkdtemp()
    try:
        trees = {}
        for rel, what, old, new in TAMPERS:
            text = tampered_text(rel, old, new)
            trees[rel] = (what, pinned_tree(tmp, {rel: text}))
        print("three synthetic trees: every pinned file copied from the "
              "worktree, with one file tampered with in each")
        for rel, (what, _) in trees.items():
            print(f"  {rel} -- {what}")
        print()

        print(f"1. the PRE-CHANGE gate on those trees (bytes at "
              f"{PRE_CHANGE_COMMIT})")
        for rel, (_, tree) in trees.items():
            print(f"  --- {rel}")
            show("PRE mask", lambda t=tree: (
                f"{len(pre_mask.check_source_pins(root=t))} pinned files "
                "checked, NO refusal"))
            show("PRE terms", lambda t=tree: (
                f"{len(pre_terms.check_source_pins(root=t))} pinned files "
                "checked, NO refusal"))
            show("PRE manifests", lambda t=tree: (
                f"{len(pre_manifests.check_manifest_pins(root=t))} manifests "
                "checked, NO refusal"))
        for gate in ("zk60_native_privacy_gate", "zk60_native_joint_view"):
            src = git_show(ROOT, PRE_CHANGE_COMMIT, f"scripts/{gate}.py")
            hits = [w for w in ("private_attention.rs", "private_attention/",
                                "profile_pins") if w in src]
            print(f"  {'PRE ' + gate[12:24]:<14} mentions {hits or 'NONE'} of "
                  "(private_attention.rs, private_attention/, profile_pins)")
        print("  => every tampered tree passes every check the gate had.")
        print()

        print("2. the SAME trees, in-tree check")
        for rel, (_, tree) in trees.items():
            print(f"  --- {rel}")
            show("IN-TREE", lambda t=tree: pp.check_profile_pins(root=t))
        print()

        print("3. CONTROL: the tree exactly as it stands")
        clean = pinned_tree(tmp)
        show("IN-TREE", lambda: "; ".join(
            f"{rel.split('/')[-1]}: {r['sha256'][:16]}… == pin of record"
            for rel, r in sorted(pp.check_profile_pins(root=clean).items())))
        print()

        print(f"4. the LANE's own bytes at {LANE_COMMIT} (read-only, from the "
              "main checkout)")
        lane = {rel: git_show(MAIN_TREE, LANE_COMMIT, rel)
                for rel in (p.path for p in pp.PROFILE_PINS)}
        lane_tree = pinned_tree(tmp, lane)
        show("IN-TREE", lambda: "; ".join(
            f"{rel.split('/')[-1]}: {r['sha256'][:16]}…"
            for rel, r in sorted(pp.check_profile_pins(root=lane_tree).items())
        ) + "  (accepted: the lane is byte-identical to main here)")
        print()

        print("5. the two gates, with the check pointed at a tampered tree")
        import zk60_native_joint_view as jv
        import zk60_native_privacy_gate as p10
        one = trees["hashline/src/private_attention/witness.rs"][1]
        empty = tempfile.mkdtemp(dir=tmp)
        for name, gate in (("joint_view", jv), ("privacy_gate", p10)):
            ev = tempfile.mkdtemp(dir=tmp)
            keep = getattr(gate, "check_profile_pins", None)
            if keep is None:
                print(f"  {name:<14} has NO attention-profile pin check "
                      "(pre-change)")
                continue
            gate.check_profile_pins = lambda t=one: pp.check_profile_pins(root=t)
            err = io.StringIO()
            try:
                with contextlib.redirect_stderr(err):
                    rc = gate.main(["--captures", empty, "--evidence", ev])
            finally:
                gate.check_profile_pins = keep
            first = err.getvalue().strip().splitlines()[:1]
            print(f"  {name:<14} main() -> {rc}, record written: "
                  f"{os.listdir(ev) or 'NONE'}")
            for line in first:
                print(f"  {'':<14} stderr: {line}")
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
