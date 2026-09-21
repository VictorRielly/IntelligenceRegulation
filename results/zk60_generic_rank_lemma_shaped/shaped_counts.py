#!/usr/bin/env python3
"""Per-commitment counts of a SHAPED private block and of a run, assembled
from the lane's own shape-driven layout model plus the geometry rules
transcribed from the Rust.

WHAT IS TAKEN FROM WHERE.

* `model_{toy,rung_g,m125}.json` are produced by
  `scripts/zk60_private_block_layout_model.py` on the lane
  `zk60-private-block-125m` at `e6b612f` (an INDEPENDENT pure-Python model
  that reproduces every number the toy's Rust asserts).  This script reads
  them and adds nothing to them.
* The geometry rules below are transcribed from the Rust, with the file and
  line of each, and are recomputed here rather than read from the model:
    - A / H row split          `layout.rs:1051-1063`
    - endpoint geometry        `protocol.rs:335-348`, `endpoint_g.rs:52,140-146`
    - boundary geometry        `boundary.rs:178-197`
    - generators of the view   2*(G+1)  (the realified group + proximity
                               combinations, `pcs.rs:943-966`)
* Every figure is printed with the quantity it is compared against, so that a
  reader can see which have slack and which have none.

Nothing here proves anything.  It counts.
"""
from __future__ import annotations
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(HERE, "model")

# `endpoint_g.rs:52`  pub(crate) const MASK_ROWS: usize = 5;
ENDPOINT_MASK_ROWS = 5

# **THE RUST IS THE AUTHORITY ON THE ENDPOINT.**  `Shape::toy/rung_g/m125`
# declare `endpoint_rows` 7 / 9 / 37 (`shape.rs:265, 318, 353`), and
# `endpoint_g.rs`'s own test asserts (4_096, 4, 9, 12) and (524_288, 32, 37,
# 16).  The pure-Python layout model still carries the MEMO's 29 at 125M
# (`model_m125.json["shape"]["endpoint_rows"]`), which is finding S11b-F3's
# superseded figure.  Both are printed and the receipt difference is shown.
RUST_ENDPOINT_ROWS = {"toy": 7, "rung": 21, "rung_g": 9, "m125": 37}
# `protocol.rs:335-348` endpoint_geometry: (rows, rows-5, rows-5+2)
# `boundary.rs:180-197` rows = data + 2*sites + 2, prox = data + 2*sites
BOUNDARY_SITES = 2
OPENED_COLS = 256          # `shape.rs:46` COL_CHECKS, and the pad count `q_pad`


def endpoint_geometry(endpoint_rows: int):
    data = endpoint_rows - ENDPOINT_MASK_ROWS
    prox = data + 2
    return dict(rows=endpoint_rows, data=data, pair=(data, data + 1),
                prox_pair=(prox, prox + 1), spare=data + 4,
                non_data=ENDPOINT_MASK_ROWS, groups=1, claims=1,
                generators=2 * (1 + 1))


def boundary_geometry(data_rows: int, sites: int = BOUNDARY_SITES):
    rows = data_rows + 2 * sites + 2
    prox = data_rows + 2 * sites
    return dict(rows=rows, data=data_rows, sites=sites,
                site_rows=(data_rows, data_rows + 2 * sites - 1),
                prox_pair=(prox, prox + 1), non_data=2 * sites + 2,
                groups=sites, claims=sites, generators=2 * (sites + 1))


def block_table(name):
    m = json.load(open(os.path.join(MODEL, f"model_{name}.json")))
    r, og, cs = m["rows"], m["opening_groups"], m["claim_sites"]
    sh = m["shape"]
    out = {}
    # ---- A ---------------------------------------------------------------
    a_sites = r["a_sites"]
    a_nondata = 2 * a_sites + 2
    out["A"] = dict(rows=r["a_rows"], data=r["a_data_rows"],
                    reserved_pairs=a_sites, prox_rows=2,
                    non_data=a_nondata, claims=a_sites,
                    groups=og["a_groups"], generators=2 * (og["a_groups"] + 1),
                    pads=OPENED_COLS, row_width=1 << sh["log_cols"])
    # ---- H.  `h_data_rows` of the model INCLUDES the zero-sum pair `u`;
    #      the run gate's "data" column excludes it.  Both are printed.
    h_sites = r["h_sites"]
    h_claims = h_sites + 1                      # + the one LogUp sum claim
    h_nondata = 2 * h_sites + 2 + 2             # site pairs + u pair + prox pair
    out["H"] = dict(rows=r["h_rows"], data=r["h_data_rows"] - 2,
                    data_incl_u=r["h_data_rows"],
                    reserved_pairs=h_sites, zero_sum_pair=2, prox_rows=2,
                    non_data=h_nondata, claims=h_claims,
                    groups=og["h_groups"], generators=2 * (og["h_groups"] + 1),
                    pads=OPENED_COLS, row_width=1 << sh["log_cols"])
    # ---- the two external endpoints --------------------------------------
    e_rows = RUST_ENDPOINT_ROWS[name]
    out["endpoint"] = endpoint_geometry(e_rows)
    out["endpoint"]["pads"] = OPENED_COLS
    out["endpoint"]["row_width"] = 1 << sh["endpoint_log_n"]
    out["endpoint"]["model_rows"] = sh["endpoint_rows"]
    # ---- an internal boundary of a run, at the same padded plane ---------
    #      the plane is the PADDED Dom::D cube, `t_pad * d_pad` words, at the
    #      endpoint row width (`shape.rs:m125` / `rung_g` doc comments)
    e_data = out["endpoint"]["data"]
    out["boundary"] = boundary_geometry(e_data)
    out["boundary"]["pads"] = OPENED_COLS
    out["boundary"]["row_width"] = 1 << sh["endpoint_log_n"]
    # ---- M ---------------------------------------------------------------
    out["M"] = dict(rows=r["m_rows"], functionals=m["slot_summary"]["functionals"],
                    slots=m["slot_summary"]["count"], pads=OPENED_COLS,
                    largest_L=m["slot_summary"]["largest_L"])
    # ---- what the endpoint correction does to the receipt ---------------
    #      `shape.rs:805-830` receipt_bytes: an opening of `g` groups over
    #      `rows` rows costs (g+1)*vec*16 + 256*(8 + rows*8 + 32 + path*32)
    e_n = 1 << sh["endpoint_log_n"]
    e_vec = e_n + OPENED_COLS
    e_path = (e_n * sh["endpoint_inv_rate"] - 1).bit_length()
    def e_open(rows):
        return 2 * e_vec * 16 + OPENED_COLS * (8 + rows * 8 + 32 + e_path * 32)
    out["_receipt"] = dict(model_total=m["receipt_bytes"]["total"],
                           model_endpoints=m["receipt_bytes"]["endpoint_openings"],
                           rust_endpoints=2 * e_open(e_rows),
                           corrected_total=m["receipt_bytes"]["total"]
                           - m["receipt_bytes"]["endpoint_openings"]
                           + 2 * e_open(e_rows))
    out["_shape"] = sh
    out["_slots"] = m["slots"]
    out["_a_group_detail"] = og["a_group_detail"]
    out["_a_sites_per_slot"] = cs["a"]
    out["_h_sites_per_slot"] = cs["h"]
    return out


def main():
    lines = []
    w = lines.append
    w("PER-COMMITMENT COUNTS OF A SHAPED PRIVATE BLOCK AND OF A RUN")
    w("lane zk60-private-block-125m @ e6b612f; model outputs under ./model/")
    w("")
    for name in ("toy", "rung_g", "m125"):
        t = block_table(name)
        sh = t["_shape"]
        w("=" * 78)
        w(f"{name}:  T{sh['tokens']} / d{sh['width']} / f{sh['hidden']}, "
          f"{sh['query_heads']} query heads of {sh['head_dim']} over {sh['kv_heads']} "
          f"key-value heads; row width 2^{sh['log_cols']}, rate 1/{sh['inv_rate']}, "
          f"Q = {OPENED_COLS}")
        lkv = max(0, (sh["kv_heads"] - 1).bit_length())
        w(f"  key-value group bits lkv = {lkv}  (the two bilinear slots' shared "
          f"summed variables)")
        w("")
        hdr = (f"  {'commitment':<12}{'rows':>7}{'data':>8}{'pairs':>7}"
               f"{'other nd':>10}{'non-data':>10}{'claims':>8}{'groups':>8}"
               f"{'gens 2(G+1)':>13}{'slack':>7}")
        w(hdr)
        for role in ("A", "H", "endpoint", "boundary"):
            d = t[role]
            pairs = d.get("reserved_pairs", d.get("sites", 1))
            other = d["non_data"] - 2 * pairs
            slack = d["non_data"] - d["generators"]
            w(f"  {role:<12}{d['rows']:>7}{d['data']:>8}{pairs:>7}{other:>10}"
              f"{d['non_data']:>10}{d['claims']:>8}{d['groups']:>8}"
              f"{d['generators']:>13}{slack:>7}")
        m = t["M"]
        w(f"  {'M':<12}{m['rows']:>7}{'-':>8}{'-':>7}{'-':>10}{'-':>10}"
          f"{'-':>8}{'-':>8}{'-':>13}{'-':>7}   "
          f"({m['functionals']} functionals over {m['slots']} slots, largest L {m['largest_L']})")
        w("")
        rc = t["_receipt"]
        if rc["model_total"] != rc["corrected_total"]:
            w(f"  RECEIPT: the model prints {rc['model_total']:,} B at "
              f"{t['endpoint']['model_rows']} endpoint rows; with the Rust's "
              f"{t['endpoint']['rows']} it is {rc['corrected_total']:,} B "
              f"(+{rc['corrected_total']-rc['model_total']:,})")
        else:
            w(f"  RECEIPT: {rc['model_total']:,} B (endpoint rows agree)")
        w(f"  endpoint rows {t['endpoint']['rows']} = {t['endpoint']['data']} data"
          f" + 5 (pair {t['endpoint']['pair']}, proximity pair {t['endpoint']['prox_pair']},"
          f" SPARE row {t['endpoint']['spare']})")
        b = t["boundary"]
        w(f"  boundary rows {b['rows']} = {b['data']} data + 2*{b['sites']} site rows"
          f" + 2 proximity rows;  generators {b['generators']} against"
          f" {b['non_data']} non-data rows -> SLACK {b['non_data']-b['generators']}")
        w("")
        w("  opening groups on A, slot by slot (the declared count "
          "`Shape::a_groups`, shape.rs:763-780):")
        det = t["_a_group_detail"]
        w("    " + ", ".join(f"{k} {v}" for k, v in sorted(det.items()) if v))
        w(f"    total {t['A']['groups']}")
        # A RIGOROUS LOWER BOUND on the number of SINGLETON opening groups on
        # `A`: a slot that raises `k` claims in `k` declared groups
        # contributes `k` singletons.  (The real split of a slot whose claim
        # count exceeds its group count is decided by the column keys, which
        # this script does not derive.)
        sites = t["_a_sites_per_slot"]
        gdet = list(t["_a_group_detail"].items())
        # the declared detail is keyed by slot NAME; align it to slot order
        order = [s["name"] for s in t["_slots"]]
        by_name = dict(gdet)
        gps = []
        for nm in order:
            k = next((v for kk, v in gdet if kk.split()[0] == nm.split()[0]), None)
            gps.append(k if k is not None else 0)
        singles = sum(ns for ns, ng in zip(sites, gps) if ns > 0 and ns == ng)
        w(f"  SINGLETON opening groups on A: at least {singles} of "
          f"{t['A']['groups']} [rigorous lower bound: the slots whose claim "
          f"count equals their declared group count]")
        bil = [s for s in t["_slots"] if s["carries_group_eq"]]
        if bil:
            w("  the two BILINEAR slots after the S19-F1 repair:")
            for s in bil:
                w(f"    slot {s['slot']:02d} {s['name']:<22} main {s['main_rounds']:>3}"
                  f" ext {s['extension_rounds']}  degree {s['degree']}"
                  f"  group bits {s['group_sumcheck_bits']}  L {s['L']}")
        else:
            w("  no slot carries a group-eq factor at this shape (lkv = 0).")
        w("")
    # ---- blocking item B-1 of the toy check, at the shaped layouts ------
    w("=" * 78)
    w("B-1 OF THE TOY CHECK: does every `H` plane's domain log lie on ONE "
      "side of the row width?")
    w("  (the enabling hypothesis of the toy lemma's u-row step; false at "
      "both shaped")
    w("   layouts BEFORE ruling P-3's lift, which `layout::domain_log_at` "
      "now applies)")
    for name in ("toy", "rung_g", "m125"):
        m = json.load(open(os.path.join(MODEL, f"model_{name}.json")))
        sh, doms = m["shape"], m["domains"]
        hdoms = sorted(m["h_planes"]["by_domain"].keys())
        lc = sh["log_cols"]
        below = [d for d in hdoms if doms[d]["log"] < lc]
        nat_below = [d for d in hdoms if doms[d]["natural_log"] < lc]
        w(f"  {name:<8} row width 2^{lc};  H domains "
          + ", ".join(f"{d} {doms[d]['log']}"
                      + ("*" if doms[d]["lifted_by_P3"] else "")
                      for d in hdoms))
        w(f"           below the row width AFTER the lift: {below or 'none'}"
          f"   (before the lift: {nat_below or 'none'})")
        # `shape.rs:792-801` logup_sum_claim_keys, recomputed with and
        # without the P-3 lift
        def keys(use_lift):
            s = set()
            for d in hdoms:
                lg = doms[d]["log"] if use_lift else doms[d]["natural_log"]
                s.add((0, 1 << lc) if lg >= lc else (0, 1 << lg))
            return s
        w(f"           LogUp sum-claim column keys: {len(keys(True))} "
          f"(instantiable {m['opening_groups']['logup_sum_claim_instantiable']});"
          f" without the lift: {len(keys(False))}")
    w("")

    # ---- a twelve-block run at 125M -------------------------------------
    t = block_table("m125")
    L = 12
    openings = 2 * L + (L - 1) + 2
    w("=" * 78)
    w(f"A RUN OF L = {L} BLOCKS AT THE 125M SHAPE")
    w(f"  commitments: {L} A, {L} H, {L} M, {L-1} internal boundaries, "
      f"2 external endpoints  = {4*L+1}")
    w(f"  PCS openings (each with its own proximity refusal): 2L + (L-1) + 2 "
      f"= {openings} = 3L + 1")
    w(f"  per-commitment generic-rank obligations: {2*L + (L-1) + 2} "
      f"(A, H, boundaries, endpoints) + {L} mask channels")
    tot_nd = L * (t["A"]["non_data"] + t["H"]["non_data"]) + \
        (L - 1) * t["boundary"]["non_data"] + 2 * t["endpoint"]["non_data"]
    tot_gen = L * (t["A"]["generators"] + t["H"]["generators"]) + \
        (L - 1) * t["boundary"]["generators"] + 2 * t["endpoint"]["generators"]
    w(f"  non-data rows over the whole run: {tot_nd};  generators: {tot_gen}")
    w("")
    out = "\n".join(lines) + "\n"
    sys.stdout.write(out)
    with open(os.path.join(HERE, "shaped_counts.txt"), "w") as fh:
        fh.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
