#!/usr/bin/env python3
"""Round 9d: stage the integrator's bundle so the toy gate's manifest check fires.

    python3 results/zk60_native_d22_replay_20260922/stage_bundle.py

The three capture files are copied BYTE FOR BYTE (the copy's digest is
re-checked against the source afterwards) into `bundle/captures/`.  Nothing in
the integrator's directory is written, renamed or staged.

The one thing built rather than copied is `bundle/validation.json`.  The toy
gate's `manifest_check` (`zk60_native_jv_capture.py:122`) reads a file called
`validation.json` whose `accepted` is a LIST of per-capture records; the
integrator's manifest is called `capture-validation.json` and its `accepted` is
a single record, because its runner calls `zk60_native_capture.check_bundle`
once and stores what that returns.  This script therefore writes
`validation.json` = the integrator's manifest with `accepted` wrapped in a
one-element list, and NOTHING else changed -- every value is copied, none is
computed here.  The transform is recorded key by key in `staged.json` so a
later reader can see that the shim adds no fact.

Why it is done this way: the toy gate's scripts are hash-pinned by guarded
records and must not be edited to read a new bundle.  Re-shaping the DATA into
the schema the pinned tool already reads is not a tool change; a control run
straight against the integrator's directory (where the manifest check simply
reports `absent`) is taken as well, and the two records are compared.
"""
import hashlib
import json
import os
import shutil

MAIN = "/home/victor/IntelligenceRegulation"
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(MAIN, "results/zk60_security_probe_repin_20260922")
DST = os.path.join(HERE, "bundle")
STEM = "10b9d4be3c0af4a44c21789a30fddd716e0d8c63948e4056c6154d3d852ce64b"


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def main():
    os.makedirs(os.path.join(DST, "captures"), exist_ok=True)
    copied = {}
    for ext in (".json", ".receipt", ".expected"):
        s = os.path.join(SRC, "captures", STEM + ext)
        d = os.path.join(DST, "captures", STEM + ext)
        shutil.copyfile(s, d)
        hs, hd = sha(s), sha(d)
        assert hs == hd, (s, hs, hd)
        copied["captures/" + STEM + ext] = {
            "sha256": hd, "bytes": os.path.getsize(d), "copied_from": s}

    man = json.load(open(os.path.join(SRC, "capture-validation.json")))
    shim = dict(man)
    shim["accepted"] = [man["accepted"]]
    with open(os.path.join(DST, "validation.json"), "w") as fh:
        json.dump(shim, fh, indent=2, sort_keys=True)
        fh.write("\n")

    changed = [k for k in set(man) | set(shim)
               if k not in man or k not in shim or man[k] != shim[k]]
    record = {
        "staged_at": DST,
        "source_directory": SRC,
        "source_manifest": "capture-validation.json",
        "source_manifest_sha256": sha(os.path.join(SRC, "capture-validation.json")),
        "files": copied,
        "validation_json_sha256": sha(os.path.join(DST, "validation.json")),
        "keys_the_shim_changes": sorted(changed),
        "what_the_shim_does": "accepted: one record -> a one-element list; no "
                              "other key differs and no value is recomputed",
        "the_bundle_is_not_committed_here": "it is the integrator's, uncommitted "
                                            "in the main tree; only its digests are recorded",
    }
    with open(os.path.join(HERE, "staged.json"), "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(json.dumps(record, indent=1, sort_keys=True))


if __name__ == "__main__":
    main()
