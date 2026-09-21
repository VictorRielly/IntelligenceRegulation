#!/usr/bin/env python3
"""ROUND 9, the DECODER'S equivalence proof: re-encode a `/4-run` bundle as
`/5-run` with this lane's own encoder, load both, compare every member.

    python3 scripts/zk60_native_rg_reencode.py \
      --bundle /path/to/run-g-dense-s20 \
      --work   /tmp/.../reencoded \
      --evidence results/zk60_native_run_gate_m125

WHAT THIS PROVES, AND WHAT IT DOES NOT.

It proves that `zk60_native_rg_arrays`'s DECODER reads the format document's
`/5-run` encoding back into exactly the values `/4-run` carries: every
opened column's `values`, every opening group's `vector`, every
`proximity_vector`, `proximity_rhos`, and the masking commitment's `q` and
`prox`, entry by entry, over a whole development-shape run.

**It does not test the Rust encoder.**  The Rust lane's own
`run_capture_tests::the_array_store_and_the_classic_encoding_carry_the_same_values`
captures one run twice in one process, expands the `/5-run` bundle's
references back into text and asserts byte-for-byte equality with the
`/4-run` bundle; that is the test of the writer.  This one is the test of
the reader, and it is built the other way round because the lane's rehearsal
wrote no `/5-run` bundle at a development shape into any repository.

Nothing here is a privacy statement.  Both bundles are PUBLISHED data and
the comparison reads only what they publish.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_arrays import (  # noqa: E402
    ARRAY_STORE_FILE,
    SCHEMA_4,
    SCHEMA_5,
    Fp2Array,
    FpArray,
    encode_to_5run,
)
from zk60_native_rg_bundle import RunBundle  # noqa: E402


def reencode(src: str, dst: str) -> dict:
    """Write a `/5-run` copy of the `/4-run` bundle at `src` into `dst`."""
    src, dst = os.path.abspath(src), os.path.abspath(dst)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    os.makedirs(dst)
    with open(os.path.join(src, "run.json"), "rb") as fh:
        run = json.loads(fh.read())
    if run["schema"] != SCHEMA_4:
        raise ValueError(f"{src}: schema {run['schema']} is not {SCHEMA_4}")
    blob = bytearray()
    index: dict[str, int] = {}
    externalised = 0
    written = []

    run["schema"] = SCHEMA_5
    externalised += encode_to_5run(run, blob, index, "run.json")
    for fn in run["stage_files"]:
        with open(os.path.join(src, fn), "rb") as fh:
            doc = json.loads(fh.read())
        doc["schema"] = SCHEMA_5
        externalised += encode_to_5run(doc, blob, index, fn)
        raw = json.dumps(doc).encode()
        with open(os.path.join(dst, fn), "wb") as fh:
            fh.write(raw)
        written.append((fn, raw))
    raw = json.dumps(run).encode()
    with open(os.path.join(dst, "run.json"), "wb") as fh:
        fh.write(raw)
    written.insert(0, ("run.json", raw))
    with open(os.path.join(dst, ARRAY_STORE_FILE), "wb") as fh:
        fh.write(bytes(blob))
    written.append((ARRAY_STORE_FILE, bytes(blob)))
    readme = b"A /5-run RE-ENCODING written by zk60_native_rg_reencode.py for the\n" \
             b"decoder's equivalence proof. NOT a capture and NOT written by the\n" \
             b"Rust lane. No privacy claim.\n"
    with open(os.path.join(dst, "README.md"), "wb") as fh:
        fh.write(readme)
    written.append(("README.md", readme))

    with open(os.path.join(src, "manifest.json"), "rb") as fh:
        man = json.loads(fh.read())
    man["schema"] = SCHEMA_5
    man["files"] = [
        {"file": fn, "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
        for fn, b in written
    ]
    man["total_bytes"] = sum(len(b) for _fn, b in written)
    with open(os.path.join(dst, "manifest.json"), "w") as fh:
        json.dump(man, fh, indent=1)
    return {
        "members_externalised": externalised,
        "distinct_arrays": len(index),
        "arrays_bin_bytes": len(blob),
        "total_bytes": man["total_bytes"],
    }


# ------------------------------------------------------------- comparison
def _norm(v):
    """A member as plain Python, whichever schema produced it."""
    if isinstance(v, (FpArray, Fp2Array)):
        return v.tolist()
    return v


def compare(a, b, path, diffs, counters):
    """Structural equality of two loaded documents, entry by entry."""
    a, b = _norm(a), _norm(b)
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            diffs.append(f"{path}: keys {sorted(set(a) ^ set(b))} differ")
            return
        for k in sorted(a):
            compare(a[k], b[k], f"{path}.{k}", diffs, counters)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            diffs.append(f"{path}: {len(a)} entries against {len(b)}")
            return
        counters["list_entries"] += len(a)
        for i, (x, y) in enumerate(zip(a, b)):
            compare(x, y, f"{path}[{i}]", diffs, counters)
    else:
        counters["scalars"] += 1
        if a != b:
            diffs.append(f"{path}: {a!r} against {b!r}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bundle", required=True, help="a /4-run bundle")
    ap.add_argument("--work", required=True, help="where the /5-run copy goes")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", default="loader_equivalence")
    args = ap.parse_args(argv)

    t0 = time.time()
    enc = reencode(args.bundle, args.work)
    t_enc = round(time.time() - t0, 1)

    t0 = time.time()
    four = RunBundle(args.bundle)
    five = RunBundle(args.work)
    t_load = round(time.time() - t0, 1)

    diffs: list[str] = []
    counters = {"list_entries": 0, "scalars": 0}
    t0 = time.time()
    # `schema` is the one member that MUST differ, so it is compared
    # explicitly and then excluded from the walk.
    schema_ok = four.schema == SCHEMA_4 and five.schema == SCHEMA_5
    for name, x, y in [("run.json", dict(four.run), dict(five.run))] + [
        (s4.name, dict(s4.doc), dict(s5.doc))
        for s4, s5 in zip(four.stages, five.stages)
    ]:
        x.pop("schema", None)
        y.pop("schema", None)
        compare(x, y, name, diffs, counters)
    t_cmp = round(time.time() - t0, 1)

    members = {
        "opened_column_values": 0,
        "group_vectors": 0,
        "proximity_vectors": 0,
        "proximity_rhos": 0,
        "mask_q": 0,
        "mask_prox": 0,
    }
    entries = 0
    for st in five.stages:
        for r in st.roles:
            members["opened_column_values"] += len(r["columns"])
            entries += sum(len(c["values"]) for c in r["columns"])
            members["group_vectors"] += len(r["groups"])
            entries += sum(len(g["vector"]) for g in r["groups"])
            members["proximity_vectors"] += 1
            entries += len(r["proximity_vector"])
            members["proximity_rhos"] += 1
            entries += len(r["proximity_rhos"])
        members["mask_q"] += 1
        members["mask_prox"] += 1
        entries += len(st.mask["q"]) + len(st.mask["prox"])

    out = {
        "what": "the DECODER of zk60_native_rg_arrays against the format "
        "document, on a whole development-shape run",
        "what_this_is_not": "a test of the Rust encoder.  The Rust lane's own "
        "run_capture_tests::the_array_store_and_the_classic_encoding_carry_"
        "the_same_values captures one run twice in one process and asserts "
        "byte-for-byte equality of the expanded /5-run bundle with the /4-run "
        "one; that is the writer's test.  This is the reader's, built the "
        "other way round because no /5-run bundle at a development shape "
        "exists in any repository",
        "source_bundle": four.name,
        "source_schema": four.schema,
        "reencoded_schema": five.schema,
        "schema_strings_as_expected": schema_ok,
        "encoder": enc,
        "externalised_members_by_kind": members,
        "field_elements_behind_the_references": entries,
        "json_leaves_compared": counters["scalars"],
        "list_entries_walked": counters["list_entries"],
        "differences": diffs[:20],
        "differences_total": len(diffs),
        "array_store": five.store.summary() if five.store else None,
        "seconds": {"reencode": t_enc, "load_both": t_load, "compare": t_cmp},
        "ok": not diffs and schema_ok,
    }
    os.makedirs(args.evidence, exist_ok=True)
    path = os.path.join(args.evidence, f"{args.name}.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(json.dumps({k: v for k, v in out.items()
                      if k not in ("what", "what_this_is_not")}, indent=1))
    print(f"record: {path}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
