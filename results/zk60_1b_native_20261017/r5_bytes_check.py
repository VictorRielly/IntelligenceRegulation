#!/usr/bin/env python3
"""NATIVE LANE round 5, speed plan task 1 (d): the HL_PB_TIMING counted work
and byte counters of every per-block prove table in a stack log, checked
against the counted layout (the speed plan's exact replica,
results/zk60_speed_plan_20261017/layout.py, imported read-only with -B).

usage: python3 -B r5_bytes_check.py <prove.log> tinyllama|llama3_8b <T> <log_cols>
Exit 0 iff every table's counters equal the counted totals.
"""
import sys

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_speed_plan_20261017")
from layout import llama3_8b, tinyllama  # noqa: E402

INV_RATE = 4


def tables(path):
    """every per-block prove table of the log, in order (a list of rows each)"""
    out = []
    cur = None
    for line in open(path, errors="replace"):
        if line.startswith("PB-TIMING prove [") and "phases, wall" in line:
            cur = []
            out.append(cur)
            continue
        if cur is not None and line.startswith("PB-TIMING prove |"):
            parts = [p.strip() for p in line.split("|")]
            if parts[1] in ("phase",) or parts[1].startswith("SUM OF") or parts[1].startswith("WALL CLOCK") or parts[1].startswith("unaccounted"):
                continue
            size_unit = parts[5].split()
            size = int(size_unit[0]) if size_unit and size_unit[0].isdigit() else 0
            unit = " ".join(size_unit[1:])
            nbytes = int(parts[9]) if len(parts) > 10 and parts[9].isdigit() else 0
            cur.append(dict(name=parts[1], secs=float(parts[3]), size=size, unit=unit, bytes=nbytes))
    return out


def main():
    path, model, t, lc = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    sh = (tinyllama if model == "tinyllama" else llama3_8b)(t, lc)
    s = sh.summary()
    a, h, u8 = s["A_elems"], s["H_elems"], s["u8"]
    pairs = s["exp_pairs"] + s["act_pairs"]
    want = {
        "A: allocate + witness planes -> committed rows": (a, 8 * a),
        "A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)": (a, 8 * a * INV_RATE),
        "H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)": (h, 8 * h * INV_RATE),
        "H: LogUp helper inverses (six lookup domains)": (u8, 16 * u8),
        "H: exp + activation helper inverses": (pairs, 16 * pairs),
        "open A (schedule audit + pcs::open_zk)": (a, 8 * a),
        "open H (schedule audit + pcs::open_zk)": (h, 8 * h),
    }
    print(f"counted ({model} T{t} 2^{lc}): A {s['A_rows']} rows = {a:,} words; H {s['H_rows']} rows = {h:,} words; u8 lookups {u8:,}; exp+act pairs {pairs:,}")
    n_tables = 0
    bad = []
    slot_terms = {}
    for k, tbl in enumerate(tables(path)):
        if not tbl:
            continue
        n_tables += 1
        seen = set()
        for r in tbl:
            if r["name"] in want:
                seen.add(r["name"])
                ws, wb = want[r["name"]]
                if (r["size"], r["bytes"]) != (ws, wb):
                    bad.append(f"table {k}: {r['name']}: {r['size']:,} words / {r['bytes']:,} B, counted {ws:,} / {wb:,}")
            if r["unit"] == "elem-terms":
                slot_terms.setdefault(r["name"], set()).add((r["size"], r["bytes"]))
        missing = set(want) - seen
        if missing:
            bad.append(f"table {k}: rows missing: {sorted(missing)}")
    print(f"{n_tables} prove tables checked")
    for name, v in sorted(slot_terms.items()):
        (size, nb), = v if len(v) == 1 else (sorted(v)[0],)
        if len(v) != 1:
            bad.append(f"{name}: element-terms differ between blocks: {sorted(v)}")
        print(f"  {name}: {size:,} element-terms, {nb:,} B per block (16 B per Fp2 element-term)")
    zc = {"slot 14": "D", "slot 15": "Q", "slot 16": "Kv", "slot 17": "S", "slot 18": "F"}
    for name, v in sorted(slot_terms.items()):
        for pre, dom in zc.items():
            if name.startswith(pre):
                size = sorted(v)[0][0]
                print(f"    {pre} ({dom}): printed {size:,} = 2^(main+ext) x tables; layout size(D) x terms = {s['sizes'][dom]:,} x {s['terms'][dom]} = {s['sizes'][dom] * s['terms'][dom]:,}")
    if bad:
        print("MISMATCH:")
        for b in bad:
            print("  " + b)
        sys.exit(1)
    print("OK: every table's A / H / lookup / pair / opening counters equal the counted totals")


if __name__ == "__main__":
    main()
