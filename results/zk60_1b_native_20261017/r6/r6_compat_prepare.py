#!/usr/bin/env python3
"""NATIVE R6 compat check, preparation: build a FRESH artifact directory from
an R5b run so that the R6 CLI's stack-verify can verify the R5b proof bytes
under its R6 publication rule (review r5_A). Copies the segment files, and
writes <out>/run.unverified-statement/ with: the R5b expected.bin and
segments.json (same format in R6), the R6 marker text, and the R5b
statement.json re-laid into the R6 UNVERIFIED rendering (schema /2, the
writer named, the prover's self-reports grouped under prover_reported). The
R6 verifier compares that file byte for byte with ITS OWN rendering, so a
passing verify also shows this re-layout is exact. Nothing in the R5b run
directory is written.
usage: r6_compat_prepare.py <r5b run dir> <new artifact parent dir>"""
import json
import os
import shutil
import sys

WRITER = "stack-prove, WITHOUT a verification (unverified: only stack-verify publishes a statement for this run)"
WHAT = "self-reports of the prover (privacy review P-7): a CPU proof and a GPU proof have the same form, so no verifier can check these fields"
MARKER = b"The prover wrote this statement WITHOUT verifying the run. It is not a public statement: only `stack-verify`, after a fresh-process verification of the run directory passes, writes <run>/statement/ itself (rulings M-9 / D12b(1); review r5_A).\n"


def main():
    src, parent = sys.argv[1], sys.argv[2]
    run = os.path.join(parent, "run")
    un = run + ".unverified-statement"
    if os.path.exists(run) or os.path.exists(un):
        sys.exit(f"{run} or {un} exists")
    os.makedirs(run)
    segs = sorted(n for n in os.listdir(src) if n.startswith("segment-") and n.endswith(".bin"))
    for n in segs:
        shutil.copyfile(os.path.join(src, n), os.path.join(run, n))
    sdir = os.path.join(src, "statement")
    os.makedirs(un)
    shutil.copyfile(os.path.join(sdir, "expected.bin"), os.path.join(un, "expected.bin"))
    shutil.copyfile(os.path.join(sdir, "segments.json"), os.path.join(un, "segments.json"))
    with open(os.path.join(un, "UNVERIFIED.txt"), "wb") as f:
        f.write(MARKER)
    text = open(os.path.join(sdir, "statement.json")).read()
    old = json.loads(text)
    lines = text.split("\n")
    assert lines[1] == ' "schema": "zk60-trained-stack-run/1",', lines[1]
    assert lines[3].startswith(' "backend": ') and lines[4].startswith(' "gpu_declines": ') and lines[5].startswith(' "prover_verified_in_process": false'), lines[3:6]
    pr = ' "prover_reported": {"backend": %s, "gpu_declines": %d, "what": %s},' % (json.dumps(old["backend"]), old["gpu_declines"], json.dumps(WHAT))
    new = [lines[0], ' "schema": "zk60-trained-stack-run/2",', lines[2], ' "statement_written_by": %s,' % json.dumps(WRITER), pr] + lines[6:]
    with open(os.path.join(un, "statement.json"), "w") as f:
        f.write("\n".join(new))
    print(f"{run}: {len(segs)} segments copied; {un}: R6 unverified statement (identity {old['trained_statement_identity']})")


main()
