#!/usr/bin/env python3
"""Round 9d, task T3: the leaf diff of the new capture against the record of record.

    python3 results/zk60_native_d22_replay_20260922/leafdiff.py \
        <new privacy_gate.json> [<record of record>]

The new bundle is a DIFFERENT receipt from the four of 2026-09-19, so a plain
key-by-key diff is not the question: the challenges, the digests and every
challenge-derived field element are supposed to differ, exactly as they already
differ between the two block captures of record.  The question is whether any
leaf that is the SAME on both block captures of record is different on the new
one.  That is a figure of record moving, and it is the only thing that would be
news.

So, over the per-capture subtree, with A and B the two block captures of record
and N the new one:

    receipt-specific  = { leaf : A[leaf] != B[leaf] }      (expected to differ)
    moved             = { leaf : A[leaf] == B[leaf] != N[leaf] } \\ receipt-specific
    structural        = keys present on one side and not the other

`moved` empty is the verdict the replay is after.  The top-level record (the
gate's version, its tool hashes, its disclaimers) is compared plainly, since
nothing there depends on which receipt was read.
"""
import json
import os
import sys


def walk(a, b, path, out):
    if type(a) is not type(b):
        out.append((path, repr(a)[:100], repr(b)[:100]))
        return
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                out.append((path + "/" + str(k), "<absent>", repr(b[k])[:100]))
            elif k not in b:
                out.append((path + "/" + str(k), repr(a[k])[:100], "<absent>"))
            else:
                walk(a[k], b[k], path + "/" + str(k), out)
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append((path + "/len", len(a), len(b)))
            return
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, path + "/" + str(i), out)
    elif a != b:
        out.append((path, repr(a)[:100], repr(b)[:100]))


def paths(a, b):
    out = []
    walk(a, b, "", out)
    return {p for p, _, _ in out}, out


def block_captures(rec):
    return [c for c in rec["per_capture"] if "private-block" in c["profile"]]


def main():
    new_path = sys.argv[1]
    rr_path = (sys.argv[2] if len(sys.argv) > 2 else
               "/home/victor/wt-zk60-jointview/results/zk60_native_privacy_gate/privacy_gate.json")
    new = json.load(open(new_path))
    rr = json.load(open(rr_path))

    print(f"new    : {new_path}")
    print(f"record : {rr_path}")
    print()

    print("== 1. the record, outside per_capture ==")
    skip = {"/per_capture", "/seconds", "/captures_dir", "/manifest"}
    a = {k: v for k, v in rr.items() if "/" + k not in skip}
    b = {k: v for k, v in new.items() if "/" + k not in skip}
    _, rows = paths(a, b)
    if not rows:
        print("identical at every leaf (version, definition, the four "
              "what_it_does_not_show sentences, the zero-witness acceptance "
              "test, the nine tool hashes, fixed_inputs, ok)")
    for p, x, y in rows:
        print(f"  {p}\n    record {x}\n    new    {y}")
    print()
    print(f"manifest, record : {json.dumps(rr['manifest'], sort_keys=True)}")
    print(f"manifest, new    : {json.dumps(new['manifest'], sort_keys=True)}")
    print(f"seconds, record  : {rr['seconds']}   new: {new['seconds']}")
    print(f"receipt lengths, new: "
          f"{json.dumps(new['receipt_length_is_the_same_within_a_profile'], sort_keys=True)}")
    print()

    A, B = block_captures(rr)
    news = block_captures(new)
    assert len(news) == 1, len(news)
    N = news[0]
    print("== 2. the per-capture subtree ==")
    print(f"A = {A['capture'][:16]} (record of record, block)")
    print(f"B = {B['capture'][:16]} (record of record, block)")
    print(f"N = {N['capture'][:16]} (the new bundle)")
    print()

    drop = {"capture"}
    A2 = {k: v for k, v in A.items() if k not in drop}
    B2 = {k: v for k, v in B.items() if k not in drop}
    N2 = {k: v for k, v in N.items() if k not in drop}

    ab, ab_rows = paths(A2, B2)
    an, an_rows = paths(A2, N2)
    bn, _ = paths(B2, N2)
    print(f"leaves differing A vs B (receipt-specific, expected): {len(ab)}")
    print(f"leaves differing A vs N: {len(an)}")
    print(f"leaves differing B vs N: {len(bn)}")
    moved = sorted((an & bn) - ab)
    print()
    print(f"== 3. FIGURES THAT MOVED: {len(moved)} ==")
    print("(a leaf identical on both block captures of record, different on the new one)")
    by = {p: (x, y) for p, x, y in an_rows}
    for p in moved:
        x, y = by.get(p, ("?", "?"))
        print(f"  {p}\n    record (A and B) {x}\n    new              {y}")
    if not moved:
        print("  none")
    print()

    print("== 4. leaves that differ between A and N but NOT between A and B "
          "and NOT between B and N ==")
    odd = sorted(an - bn - ab)
    print(f"  {len(odd)} (N agrees with B where A differs: the receipt-specific "
          f"leaves A happens to hold alone)")
    print()

    print("== 5. the figures the statement names, read off each record ==")
    hdr = f"{'figure':58} {'A':>12} {'B':>12} {'N':>12}"
    print(hdr)
    print("-" * len(hdr))

    def row(name, f):
        try:
            va, vb, vn = f(A), f(B), f(N)
        except Exception as exc:  # pragma: no cover
            va = vb = vn = f"ERR {exc}"
        flag = "" if va == vb == vn else "   <-- differs"
        print(f"{name:58} {str(va):>12} {str(vb):>12} {str(vn):>12}{flag}")

    row("proof_bytes", lambda c: c["proof_bytes"])
    row("ok", lambda c: c["ok"])
    row("grade.channels", lambda c: c["grade"]["channels"])
    row("grade.constructed", lambda c: c["grade"]["by_status"]["constructed"])
    row("grade.derived", lambda c: c["grade"]["by_status"]["derived"])
    row("grade.argued", lambda c: c["grade"]["by_status"]["argued"])
    row("grade.open", lambda c: c["grade"]["by_status"]["open"])
    row("grade.ok", lambda c: c["grade"]["ok"])
    row("grade.failures", lambda c: len(c["grade"]["failures"]))
    row("transcript_replay.ok", lambda c: c["transcript_replay"]["ok"])
    row("controls.all_fire", lambda c: c["controls"]["all_fire"])
    row("controls.ok", lambda c: c["controls"]["ok"])
    row("controls, number of names", lambda c: len(c["controls"]["control_names"]))
    row("controls.honest_again", lambda c: c["controls"]["honest_again"])
    row("controls M.all_fire", lambda c: c["controls"]["mask_commitment_M"]["all_fire"])
    row("masking_commitment_M_opening.ok", lambda c: c["masking_commitment_M_opening"]["ok"])
    print()
    print("channel statuses, channel by channel (name -> status):")
    same = True
    for i, ch in enumerate(A["channels"]):
        sa, sb, sn = (A["channels"][i]["status"], B["channels"][i]["status"],
                      N["channels"][i]["status"])
        na, nn = A["channels"][i]["channel"], N["channels"][i]["channel"]
        if not (sa == sb == sn and na == nn):
            same = False
            print(f"  DIFFERS {i}: {na} -> {sa} / {sb} / {sn}   (new name {nn})")
    if same:
        print(f"  all {len(A['channels'])} channels: same name and same status "
              f"on A, B and N")

    print()
    print("== 6. the controls, name by name ==")
    for n in A["controls"]["control_names"]:
        key = n.split("/")[-1]
        node = A["controls"]
        if n.startswith("mask_commitment_M/"):
            node_a = A["controls"]["mask_commitment_M"][key]
            node_b = B["controls"]["mask_commitment_M"][key]
            node_n = N["controls"]["mask_commitment_M"][key]
        else:
            node_a, node_b, node_n = (A["controls"][key], B["controls"][key],
                                      N["controls"][key])
        fa, fb, fn = (node_a.get("fires"), node_b.get("fires"), node_n.get("fires"))
        mark = "ok" if fa is True and fb is True and fn is True else "CHECK"
        print(f"  {mark:5} {n:62} {fa} / {fb} / {fn}")

    return 1 if moved else 0


if __name__ == "__main__":
    raise SystemExit(main())
