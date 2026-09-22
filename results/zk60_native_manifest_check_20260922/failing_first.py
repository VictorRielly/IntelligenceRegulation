#!/usr/bin/env python3
"""Round 9e, S1: the defect, shown against the PRE-FIX bytes of the pinned tool.

    python3 results/zk60_native_manifest_check_20260922/failing_first.py

It loads `scripts/zk60_native_jv_capture.py` **as it stood at `d837d50`** --
the commit round 9d closed on, straight out of git, never from the working
tree -- so this script keeps printing the pre-fix behaviour after the fix has
landed.  It then runs the same six cases against the tool in the tree, so the
two columns can be read side by side.

The six cases:

  1. the integrator's directory exactly as delivered (a manifest called
     `capture-validation.json` whose `accepted` is ONE record);
  2. a `validation.json` whose `accepted` is one record rather than a list;
  3. a `validation.json` that cannot be parsed;
  4. a `validation.json` whose `accepted` is neither a list nor a record;
  5. the four captures of record (`validation.json`, `accepted` a list) --
     the control: this case must be unchanged by the fix, byte for byte;
  6. a manifest that DISAGREES with the bundle (one artifact digest flipped).

Nothing here reads, writes or renames anything in the integrator's directory;
case 1 opens its manifest read-only.  The synthetic directories are built in a
temp dir and deleted.  A synthetic capture is the smallest document
`Capture.__init__` accepts -- `manifest_check` reads only a capture's file
name, size, digest and `proof_sha256`, so no witness-bearing field is needed
or invented.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import types

ROOT = "/home/victor/wt-zk60-jointview"
PRE_FIX_COMMIT = "d837d50"
AS_DELIVERED = (
    "/home/victor/IntelligenceRegulation/results/zk60_security_probe_repin_20260922"
)
OF_RECORD = os.path.join(ROOT, "results", "zk60_native_captures_20260919")
PROFILE = "hashline-zk-mr1/private-block-t32-poc/1"


def load_pre_fix():
    """`zk60_native_jv_capture` as of `d837d50`, from git, as a module."""
    src = subprocess.run(
        ["git", "--no-pager", "-C", ROOT, "show",
         f"{PRE_FIX_COMMIT}:scripts/zk60_native_jv_capture.py"],
        check=True, capture_output=True, text=True,
    ).stdout
    mod = types.ModuleType("jv_capture_pre_fix")
    mod.__file__ = f"git:{PRE_FIX_COMMIT}:scripts/zk60_native_jv_capture.py"
    exec(compile(src, mod.__file__, "exec"), mod.__dict__)
    return mod


def load_in_tree():
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    import zk60_native_jv_capture as mod  # noqa: E402
    return mod


def synthetic_dir(tmp, manifest, *, manifest_name="validation.json", raw=None):
    """A capture directory with one tiny synthetic capture and a manifest."""
    d = tempfile.mkdtemp(dir=tmp)
    os.makedirs(os.path.join(d, "captures"))
    stem = "aa" * 32
    doc = {
        "schema": 3,
        "kind": "zk60-verifier-observations",
        "coverage": "native-all-slots-v1",
        "profile": PROFILE,
        "transcript_domain": PROFILE,
        "proof_sha256": stem,
        "proof_bytes": 2816472,
        "source_commit": "0" * 40,
    }
    p = os.path.join(d, "captures", stem + ".json")
    with open(p, "w") as fh:
        json.dump(doc, fh, indent=1, sort_keys=True)
        fh.write("\n")
    if raw is not None:
        with open(os.path.join(d, manifest_name), "w") as fh:
            fh.write(raw)
    elif manifest is not None:
        import hashlib
        blob = open(p, "rb").read()
        man = dict(manifest)
        man.setdefault("artifacts", {})["captures/" + stem + ".json"] = {
            "sha256": hashlib.sha256(blob).hexdigest(), "bytes": len(blob)}
        if manifest.get("_flip_artifact"):
            man["artifacts"]["captures/" + stem + ".json"]["sha256"] = "00" * 32
            del man["_flip_artifact"]
        with open(os.path.join(d, manifest_name), "w") as fh:
            json.dump(man, fh, indent=1, sort_keys=True)
            fh.write("\n")
    return d, stem


def accepted_record(stem):
    return {
        "canonical_capture_reproduced": True,
        "native_reverified": True,
        "proof_sha256": stem,
        "profile": PROFILE,
    }


def run(label, mod, directory, **kw):
    try:
        caps = mod.load_all(directory)
        out = mod.manifest_check(directory, caps, **kw)
    except Exception as exc:  # noqa: BLE001 -- the point is WHICH exception
        print(f"  {label:<10} RAISED {type(exc).__name__}: {exc}")
        return
    print(f"  {label:<10} RETURNED {json.dumps(out, sort_keys=True)}")


def main():
    pre, now = load_pre_fix(), load_in_tree()
    print(f"pre-fix module: {pre.__file__}")
    print(f"in-tree module: {now.__file__}")
    print()
    tmp = tempfile.mkdtemp()
    try:
        cases = []
        cases.append(("1. the integrator's directory as delivered "
                      "(capture-validation.json, accepted = ONE record)",
                      AS_DELIVERED, {}))

        d2, s2 = synthetic_dir(tmp, {"accepted": accepted_record("aa" * 32)})
        cases.append(("2. validation.json, accepted = ONE record", d2, {}))

        d3, _ = synthetic_dir(tmp, None, raw="{not json\n")
        cases.append(("3. validation.json, unreadable", d3, {}))

        d4, _ = synthetic_dir(tmp, {"accepted": "yes"})
        cases.append(("4. validation.json, accepted = neither", d4, {}))

        cases.append(("5. CONTROL: the four captures of record "
                      "(validation.json, accepted = a list)", OF_RECORD, {}))

        d6, s6 = synthetic_dir(
            tmp, {"accepted": [accepted_record("aa" * 32)], "_flip_artifact": True})
        cases.append(("6. a manifest that DISAGREES with the bundle", d6, {}))

        d7, _ = synthetic_dir(tmp, None)
        cases.append(("7. no validation file at all", d7, {}))

        for title, directory, kw in cases:
            print(title)
            run("PRE-FIX", pre, directory, **kw)
            run("IN-TREE", now, directory, **kw)
            print()
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
