#!/usr/bin/env python3
"""Round 9f, task 3: the hole, shown against the PRE-CHANGE bytes of the gate.

    python3 results/zk60_native_manifest_pins_20260922/failing_first.py

Finding P36-2 says: after the stage-36 delta the two Cargo manifests decide
whether the read-only test observers can compile into a release build, and
nothing pinned them.  This script shows that, against the gate as it stood at
`025e1ac` (the commit round 9e closed on) read straight out of git, so the
left-hand column keeps printing the pre-change behaviour after the change has
landed.

The tree it tests is SYNTHETIC: a throwaway directory holding a copy of every
file the toy gate pins, with `zkp-core/Cargo.toml` replaced by the pinned
bytes plus the one-word edit finding P36-2 names --

    [features]
    default = ["test-observers"]
    test-observers = []

-- which is exactly the manifest that would put `ZkRng::consumed_bytes` and
`Transcript::squeezes` into the production library.  Every Rust file in that
tree is byte-identical to the tree's own, so any refusal can only be the
manifest's.  Nothing outside the temp directory is written.

Cases
  1  the PRE-CHANGE pin machinery on the tampered tree: both pin tables, and a
     text search of the two gates for any mention of a manifest
  2  the same tree, IN-TREE check: refused by digest, naming the file
  3  the same tree with the tampered digest FORCE-ACCEPTED (what a re-pin done
     without reading the file would look like): still refused, by the content
     assertion, naming `default`
  4  `hashline/Cargo.toml` with the observers enabled from `[dependencies]`
     instead of `[dev-dependencies]`, digest force-accepted: refused, naming
     the section
  5  the LANE's real manifests at `a8e4939` (read-only, from the main
     checkout's git), digests force-accepted: ACCEPTED -- the content
     assertion passes the shape the integration will bring
  6  CONTROL: the tree exactly as it stands: accepted, both digests equal to
     their pins of record
  7  the two gates: with the check pointed at the tampered tree, each `main`
     returns 3 and writes no record
"""
from __future__ import annotations

import io
import contextlib
import os
import shutil
import subprocess
import sys
import tempfile
import types

ROOT = "/home/victor/wt-zk60-jointview"
MAIN_TREE = "/home/victor/IntelligenceRegulation"
PRE_CHANGE_COMMIT = "025e1ac"
LANE_COMMIT = "a8e4939"

sys.path.insert(0, os.path.join(ROOT, "scripts"))
import zk60_native_manifest_pins as mp  # noqa: E402
import zk60_native_mask_commit as mask_commit  # noqa: E402
import zk60_native_terminal_polys as terminal_polys  # noqa: E402

TAMPERED_ZKP_CORE = """[package]
name = "zkp-core"
version = "0.1.0"
edition = "2021"
publish = false
description = "Maintained CPU proof primitives extracted from hashline; experimental protocol security"

[features]
default = ["test-observers"]
test-observers = []

[dependencies]
blake3 = "1.8"
rayon = "1.11"
sha2 = "0.10"

[profile.release]
opt-level = 3
codegen-units = 1
lto = "fat"
panic = "abort"
debug = false
"""


def git_show(tree, ref, path):
    return subprocess.run(
        ["git", "--no-pager", "-C", tree, "show", f"{ref}:{path}"],
        check=True, capture_output=True, text=True).stdout


def load_pre_change(name):
    """A scripts/ module as it stood at `025e1ac`, from git, as a module."""
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
             | {p.path for p in mp.MANIFEST_PINS})
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


def sha256_of(text):
    import hashlib
    return hashlib.sha256(text.encode()).hexdigest()


def show(label, fn):
    try:
        out = fn()
    except Exception as exc:  # noqa: BLE001 -- WHICH exception is the point
        head = str(exc).strip().splitlines()
        print(f"  {label:<12} RAISED {type(exc).__name__}: {head[0]}")
        for line in head[1:]:
            print(f"  {'':<12}        {line}")
        return
    print(f"  {label:<12} RETURNED {out}")


def main():
    pre_mask = load_pre_change("zk60_native_mask_commit")
    pre_terms = load_pre_change("zk60_native_terminal_polys")
    print(f"pre-change modules: {pre_mask.__file__}")
    print(f"                    {pre_terms.__file__}")
    print(f"in-tree module:     {mp.__file__}")
    print()

    tmp = tempfile.mkdtemp()
    try:
        tampered = pinned_tree(tmp, {"zkp-core/Cargo.toml": TAMPERED_ZKP_CORE})
        tampered_sha = sha256_of(TAMPERED_ZKP_CORE)
        print("the synthetic tree: every pinned file copied from the worktree, "
              "with")
        print("  zkp-core/Cargo.toml = the pinned bytes + "
              '`[features] default = ["test-observers"]`')
        print(f"  its sha256 {tampered_sha}")
        print()

        print("1. the PRE-CHANGE gate on that tree "
              f"(bytes at {PRE_CHANGE_COMMIT})")
        show("PRE mask", lambda: f"{len(pre_mask.check_source_pins(root=tampered))} "
             "pinned files checked, NO refusal")
        show("PRE terms", lambda: f"{len(pre_terms.check_source_pins(root=tampered))} "
             "pinned files checked, NO refusal")
        for gate in ("zk60_native_privacy_gate", "zk60_native_joint_view"):
            src = git_show(ROOT, PRE_CHANGE_COMMIT, f"scripts/{gate}.py")
            hits = [w for w in ("Cargo.toml", "manifest_pins", "test-observers")
                    if w in src]
            print(f"  {'PRE ' + gate[12:22]:<12} mentions {hits or 'NONE'} of "
                  "(Cargo.toml, manifest_pins, test-observers)")
        print("  => the tampered manifest passes every check the gate had.")
        print()

        print("2. the SAME tree, in-tree check: the digest")
        show("IN-TREE", lambda: mp.check_manifest_pins(root=tampered))
        print()

        print("3. the SAME tree with that digest FORCE-ACCEPTED "
              "(a re-pin done without reading the file)")
        also = {"zkp-core/Cargo.toml": {tampered_sha: (
            "n/a", "force-accepted by this script, to reach the content "
            "assertion")}}
        show("IN-TREE", lambda: mp.check_manifest_pins(root=tampered, also=also))
        print()

        print("4. hashline/Cargo.toml with the observers enabled from "
              "[dependencies]")
        hl = open(os.path.join(ROOT, "hashline/Cargo.toml")).read().replace(
            'zkp-core = { path = "../zkp-core" }',
            'zkp-core = { path = "../zkp-core", features = ["test-observers"] }')
        moved = pinned_tree(tmp, {"hashline/Cargo.toml": hl})
        also4 = {"hashline/Cargo.toml": {sha256_of(hl): (
            "n/a", "force-accepted by this script, to reach the content "
            "assertion")}}
        show("IN-TREE", lambda: mp.check_manifest_pins(root=moved, also=also4))
        print()

        print(f"5. the LANE's real manifests at {LANE_COMMIT} "
              "(read-only, from the main checkout)")
        lane = {rel: git_show(MAIN_TREE, LANE_COMMIT, rel)
                for rel in ("zkp-core/Cargo.toml", "hashline/Cargo.toml")}
        lane_tree = pinned_tree(tmp, lane)
        also5 = {rel: {sha256_of(text): ("n/a", f"the lane at {LANE_COMMIT}")}
                 for rel, text in lane.items()}
        show("IN-TREE", lambda: "; ".join(
            f"{rel}: default={r['content_assertion']['features_default']}, "
            f"test-observers {r['content_assertion']['test-observers']}"
            for rel, r in sorted(
                mp.check_manifest_pins(root=lane_tree, also=also5).items())))
        print()

        print("6. CONTROL: the tree exactly as it stands")
        clean = pinned_tree(tmp)
        show("IN-TREE", lambda: "; ".join(
            f"{rel}: {r['sha256'][:16]}… == pin of record"
            for rel, r in sorted(mp.check_manifest_pins(root=clean).items())))
        print()

        print("7. the two gates, with the check pointed at the tampered tree")
        import zk60_native_joint_view as jv
        import zk60_native_privacy_gate as p10
        empty = tempfile.mkdtemp(dir=tmp)
        for name, gate in (("joint_view", jv), ("privacy_gate", p10)):
            ev = tempfile.mkdtemp(dir=tmp)
            keep = getattr(gate, "check_manifest_pins", None)
            if keep is None:
                print(f"  {name:<12} has NO manifest-pin check (pre-change)")
                continue
            gate.check_manifest_pins = lambda t=tampered: mp.check_manifest_pins(
                root=t)
            err = io.StringIO()
            try:
                with contextlib.redirect_stderr(err):
                    rc = gate.main(["--captures", empty, "--evidence", ev])
            finally:
                gate.check_manifest_pins = keep
            first = err.getvalue().strip().splitlines()[:1]
            print(f"  {name:<12} main() -> {rc}, record written: "
                  f"{os.listdir(ev) or 'NONE'}")
            for line in first:
                print(f"  {'':<12} stderr: {line}")
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
