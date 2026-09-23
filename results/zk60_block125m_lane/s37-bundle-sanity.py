#!/usr/bin/env python3
"""Stage 37 bundle sanity pass, on the files AS WRITTEN (lane zk60-private-block-125m).

Usage: python3 s37-bundle-sanity.py <expected source_commit> <lkv> <bundle dir> [<bundle dir> ...]

For every bundle: every manifest entry's byte length and SHA-256; the run
file's schema, profiles, hash rule, public-tables flag and source_commit
label; every public table's SHA-256 recomputed over the 16-byte
little-endian Fp2 encodings of exactly the values included; slots 08 and 09
opening their table list with the group eq at start 0 whose point has lkv
entries equal to definition_challenges[:lkv]; and the canonical plane index
(json sort_keys, compact separators), which must be identical across the
bundles given. Run on the two stage-22 rung-K4 bundles with lkv 2 it
reproduces w5-s22-k4-bundle-sanity.log's figures (the control).

Prints counts and digests only, never a value. Exit 1 on any mismatch.
"""
import hashlib
import json
import os
import struct
import sys


def sha(b):
    return hashlib.sha256(b).hexdigest()


def main(argv):
    commit, lkv, dirs = argv[1], int(argv[2]), argv[3:]
    bad = 0
    plane_digests = {}
    for d in dirs:
        name = os.path.basename(os.path.normpath(d))
        man = json.load(open(os.path.join(d, "manifest.json")))
        print(f"-- {name}: schema {man['schema']}, manifest total {man['total_bytes']:,} B, {len(man['files'])} files, source_commit {man['source_commit']}")
        mism = 0
        for f in man["files"]:
            b = open(os.path.join(d, f["file"]), "rb").read()
            if len(b) != f["bytes"] or sha(b) != f["sha256"]:
                mism += 1
        print(f"   manifest entries: {len(man['files'])} checked, {mism} mismatches")
        bad += mism
        if man["source_commit"] != commit:
            print(f"   MISMATCH manifest source_commit {man['source_commit']} != {commit}")
            bad += 1
        r = json.load(open(os.path.join(d, "run.json")))
        print(f"   run schema {r['schema']}, profile {r['profile']}, block profile {r['block_profile']}, rule {r['hash_tag']['rule']}, public_tables_included {r['public_tables_included']}, source_commit {r['source_commit']}")
        if r["source_commit"] != commit:
            print(f"   MISMATCH run.json source_commit {r['source_commit']} != {commit}")
            bad += 1
        if r["hash_tag"]["rule"] != "blake3-keyed/1" or r["public_tables_included"] is not True:
            print("   MISMATCH hash rule or public-tables flag")
            bad += 1
        sh = r["shape"]
        print(f"   shape: T{sh['tokens']}/d{sh['width']}/f{sh['hidden']}, {sh['q_heads']} heads of {sh['head_dim']} over {sh['kv_heads']} KV heads, pads ({sh['t_pad']}, {sh['d_pad']}, {sh['h_pad']}, {sh['f_pad']}), slots[8] {sh['slots'][8]}, slots[9] {sh['slots'][9]}")
        if (sh["kv_heads"]).bit_length() - 1 != lkv:
            print(f"   MISMATCH kv_heads {sh['kv_heads']} is not 2^{lkv}")
            bad += 1
        pub = pub_vals = pub_bad = eqs = 0
        eq_ok = eq_seen = 0
        sched = set()
        for sf in r["stage_files"]:
            fname = sf if isinstance(sf, str) else sf.get("file")
            s = json.load(open(os.path.join(d, fname)))
            for a in s["arguments"]:
                for t in a.get("tables", []):
                    if t["kind"] == "public":
                        pub += 1
                        if "values" in t:
                            pub_vals += 1
                            h = sha(b"".join(struct.pack("<QQ", v[0], v[1]) for v in t["values"]))
                            if h != t["sha256"] or len(t["values"]) != t["len"]:
                                pub_bad += 1
                    elif t["kind"] == "eq":
                        eqs += 1
            for sl in (8, 9):
                a = s["arguments"][sl]
                sched.add((sl, a["main"], a["extension"], a["degree"]))
                t0 = a["tables"][0]
                eq_seen += 1
                if t0["kind"] == "eq" and t0["start"] == 0 and len(t0["point"]) == lkv and t0["point"] == a["definition_challenges"][:lkv]:
                    eq_ok += 1
        print(f"   public tables: {pub}, with values {pub_vals}, sha mismatches {pub_bad}; eq tables {eqs}")
        print(f"   slots 08/09 schedules (slot, main, ext, degree): {sorted(sched)}")
        print(f"   group eq at start 0 with a {lkv}-element point == definition_challenges[:{lkv}]: {eq_ok} of {eq_seen}")
        bad += pub_bad + (pub - pub_vals) + (eq_seen - eq_ok)
        pi = json.dumps(r["plane_index"], sort_keys=True, separators=(",", ":")).encode()
        plane_digests[name] = sha(pi)
        print(f"   plane index: {len(pi)} canonical bytes, sha256 {sha(pi)[:8]}..., {len(r['plane_index']['a_planes'])} A planes over {r['plane_index']['a_data_rows']} rows, {len(r['plane_index']['h_planes'])} H planes over {r['plane_index']['h_data_rows']} rows, slot_planes[8] {r['plane_index']['slot_planes'][8]}, slot_planes[9] {r['plane_index']['slot_planes'][9]}")
        on_disk = sum(os.path.getsize(os.path.join(d, f)) for f in os.listdir(d))
        print(f"   on disk {on_disk:,} B ({on_disk / 1e6:.1f} MB)")
    if len(set(plane_digests.values())) != 1:
        print(f"\nPLANE INDEX DIFFERS across bundles: {plane_digests}")
        bad += 1
    else:
        print(f"\nPLANE INDEX identical across {len(plane_digests)} bundles: {next(iter(plane_digests.values()))[:8]}...")
    print(f"\nTOTAL MISMATCHES: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
