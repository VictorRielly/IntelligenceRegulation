#!/usr/bin/env python3
"""Write the token-profile approval record a verifier's pins are read from (review TR5-3).

The demo must not derive its token-profile pin by running `profile` over the prover's
files: a verifier handed another head's own pin would accept a run proved with that head.
The pins come from this record instead. It is written at the coordinator's instruction
(first 2026-10-19, round 6, for the calibration lane's b7_T32 tables; since round 7 for
the fidelity lane's exports too) from the EXPORT's own files and its lane's ledger:

  * every file in the export's `token_io/SHA256SUMS` re-hashed and matched;
  * the export's profile.json SHA-256 equal to its lane's ledger value;
  * V, BOS and the final-norm constants read from the export's `head_manifest.json`;
  * the approved pins given on the command line (the coordinator's values), with where
    each was computed / reproduced.

usage: approval_record.py --export DIR --profile-sha256 HEX --expect-statement HEX
                          --expect-token-profile HEX --approved-by TEXT --out FILE
                          [--emb DIR --head DIR]

--emb / --head (round 10): a SPLIT table layout with no token_io/SHA256SUMS (the R2
TinyLlama T32 export: `embedding_int16.bin` + `token_io.json` in the export root, the head
files + `head_manifest.json` in r2_inputs/). Each binary table is re-hashed and matched
against the sha256 its own manifest records (token_io.json's embedding_table, the head
manifest's per-file entries); V, BOS and the final norm come from that head manifest.
"""
import argparse
import hashlib
import json
import os
import sys


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(1 << 22)
            if not b:
                return h.hexdigest()
            h.update(b)


def main():
    ap = argparse.ArgumentParser()
    for a in ("--export", "--profile-sha256", "--expect-statement", "--expect-token-profile", "--approved-by", "--out"):
        ap.add_argument(a, required=True)
    ap.add_argument("--evidence", action="append", default=[])
    ap.add_argument("--emb")
    ap.add_argument("--head")
    a = ap.parse_args()
    split = a.emb is not None or a.head is not None
    if split and (a.emb is None or a.head is None):
        print("refused: --emb and --head go together", file=sys.stderr)
        return 1
    tio = os.path.join(a.export, "token_io")
    sums = {}
    if split:
        with open(os.path.join(a.emb, "token_io.json")) as f:
            et = json.load(f)["embedding_table"]
        with open(os.path.join(a.head, "head_manifest.json")) as f:
            hm0 = json.load(f)
        want = [(a.emb, et["file"], et["sha256"], "token_io.json embedding_table"),
                (a.head, "head_int8_perrow.bin", hm0["head_int8_perrow.bin"]["sha256"], "head_manifest.json"),
                (a.head, "head_mult12.bin", hm0["head_mult12.bin"]["sha256"], "head_manifest.json")]
        for d, n, h, src in want:
            got = sha256_file(os.path.join(d, n))
            if got != h:
                print(f"refused: {os.path.join(d, n)}: sha256 {got}, its {src} says {h}", file=sys.stderr)
                return 1
            sums[os.path.join(d, n)] = got
        for d, n in ((a.emb, "token_io.json"), (a.head, "head_manifest.json")):
            sums[os.path.join(d, n)] = sha256_file(os.path.join(d, n))
    else:
        with open(os.path.join(tio, "SHA256SUMS")) as f:
            for line in f:
                h, n = line.split()
                sums[n] = h
        for n, h in sorted(sums.items()):
            got = sha256_file(os.path.join(tio, n))
            if got != h:
                print(f"refused: token_io/{n}: sha256 {got}, the export's token_io/SHA256SUMS says {h}", file=sys.stderr)
                return 1
    prof = sha256_file(os.path.join(a.export, "profile.json"))
    if prof != a.profile_sha256:
        print(f"refused: profile.json sha256 {prof}, not its lane's ledger value {a.profile_sha256}", file=sys.stderr)
        return 1
    for pin in (a.expect_statement, a.expect_token_profile):
        if len(pin) != 64 or any(c not in "0123456789abcdef" for c in pin):
            print(f"refused: {pin}: not 32 bytes of lower-case hex", file=sys.stderr)
            return 1
    with open(os.path.join(a.head if split else tio, "head_manifest.json")) as f:
        hm = json.load(f)
    fn = hm["final_norm"]
    rec = {
        # review REVIEW5 TR6-4: the wording names THIS export, not the first record's
        "record": f"approved token-profile pins for the token I/O tables of the export {os.path.basename(os.path.abspath(a.export))}",
        "approved_by": a.approved_by,
        "written_by": "token-I/O lane, at that instruction, from this export's own token_io/ files and its "
                      "SHA256SUMS (below); where the table files are another lane's, the evidence says so",
        "use": "a verifier reads --expect-statement / --expect-token-profile from `pins`; never from "
               "`zk60_token_io profile` over the prover's files (review TR5-3)",
        "export": os.path.abspath(a.export),
        "export_profile_json_sha256": prof,
        **({"table_dirs": {"emb": os.path.abspath(a.emb), "head": os.path.abspath(a.head)},
            "table_files_sha256": sums,
            "table_files_checked_against": "each binary table against the sha256 its own manifest records "
                                           "(token_io.json embedding_table; head_manifest.json); no SHA256SUMS in this layout"}
           if split else
           {"token_io_SHA256SUMS_sha256": sha256_file(os.path.join(tio, "SHA256SUMS")),
            "token_io_files_sha256": sums}),
        "V": hm["V"],
        "bos": hm["bos"],
        "final_norm": {"g0": fn["g0"], "cn": fn["cn_calibrated"], "tn": fn["tn"], "ceps": fn["ceps"]},
        "pins": {"expect_statement": a.expect_statement, "expect_token_profile": a.expect_token_profile},
        "evidence": a.evidence,
        "not": "not a privacy acceptance and not a ruling; a pin fixes which public tables a verifier accepts",
    }
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w") as f:
        json.dump(rec, f, indent=1, sort_keys=True)
        f.write("\n")
    print(json.dumps({"event": "approval-record", "out": os.path.abspath(a.out), "files_checked": len(sums),
                      "pins": rec["pins"], "V": rec["V"], "bos": rec["bos"], "final_norm": rec["final_norm"]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
