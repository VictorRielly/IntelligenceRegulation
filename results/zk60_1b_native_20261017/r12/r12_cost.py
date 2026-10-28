#!/usr/bin/env python3
"""NATIVE R12 (task 5): the cost per proof at Shieldstral's shapes, T = 128 /
256 / 512, with and without DD, and the split-width option (R12b, paper).

* counts [COUNTED]: the R10 replica of R9's counting (../r10/
  r10_weight_range_cost.py, its anchor re-asserted), at Shieldstral's geometry
  (d 3072 -> d_pad 4096, hidden 9216 -> f_pad 16384, 32 heads of 128 = 4096,
  8 KV heads), against Llama-3-8B at the same T and row width; at T128 / T256
  checked equal to the Rust layout's own totals printed by r12_tests (when
  that log is present);
* time [MODEL]: R9's convention — every argument phase at the 8B T128 measured
  cost per unit (R8 non-DD run, R9 DD run) times its counted size, plus the
  measured per-block witness / load phase scaled by the block's weight count
  and T / 128;
* peak memory [MODEL]: the measured 8B T128 stack-prove peak (cache 0) scaled
  by the committed words per block;
* split width (R12b) [MODEL, upper bound of the saving]: the model axis as
  2048 + 1024 and the hidden axis as 8192 + 1024 (two hypercubes each, no pad
  to 4096 / 16384), with every D / F plane and helper opened at two sites.
Writes r12_cost.json beside itself."""
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "r10"))
import r10_weight_range_cost as r10  # noqa: E402

SS = dict(h=32, hd=128, kv=8, d=3072, hidden=9216, f_e=9)
L8 = dict(h=32, hd=128, kv=8, d=4096, hidden=14336, f_e=9)
LOG_N = {128: 14, 256: 15, 512: 15}
# public weight words per block (int8): q, k, v, o, gate, up, down
W_SS = 4096 * 3072 + 2 * 1024 * 3072 + 3072 * 4096 + 3 * 9216 * 3072
W_8B = 2 * 4096 * 4096 + 2 * 1024 * 4096 + 3 * 14336 * 4096
PEAK_8B_T128 = {False: 6.69, True: 6.56}  # GiB, R8 / R9 stack-prove guard peaks, witness cache 0


class Split(r10.Layout):
    """the split-width layout: D and F as two power-of-two pieces each"""

    def __init__(self, g, dd=False):
        super().__init__(g, dd=dd)
        T = self.t_pad
        self.pieces = {"D": [T * 2048, T * 1024], "F": [T * 8192, T * 1024]}
        for k, ps in self.pieces.items():
            self.size[k] = sum(ps)
            self.rows[k] = sum(max(1, p >> self.log_n) for p in ps)
            self.pads[k] = False

    def claim_sites(self):
        A, H = super().claim_sites()
        a, hp = self.a_planes(), self.helpers()
        # every D / F plane and helper is claimed on BOTH pieces
        A["DZC"] += a["D"] + 2
        A["FZC"] += a["F"]
        H["DZC"] += hp["D"]
        H["FZC"] += hp["F"] + 1
        return A, H

    def slot_work(self):
        out = []
        for (name, m, e, t) in super().slot_work():
            if name in ("DZC", "SS", "SSM", "IO_IN", "IO_OUT"):
                p = self.pieces["D"]
            elif name == "FZC":
                p = self.pieces["F"]
            else:
                out.append((name, m, e, t))
                continue
            # two cubes, each with one extension round: (2 |piece|) x tables
            # each, written as one entry of that many element-terms
            # (`(1 << 0) * terms`)
            out.append((name, 0, 0, sum(2 * x for x in p) * t))
        return out


def per_block(meas, base8, t, blocks_measured):
    """argument-phase seconds per block at the 8B T128 per-unit costs"""
    _, _, ab, an = r10.time_model(meas, base8, t, per_unit_from=True)
    return an / blocks_measured


def fixed_per_block(meas, blocks_measured):
    return sum(sec for (sec, size, key, half) in meas["phases"].values() if key is None) / blocks_measured


def rust_totals():
    """the Rust layout's own totals, printed by r12_tests (if the log exists)"""
    out = {}
    for log in ["r12-t1-run.log", "r12-t2-run.log", "r12-suite.log"]:
        p = os.path.join(HERE, log)
        if not os.path.exists(p):
            continue
        for line in open(p, errors="replace"):
            m = re.search(r"R12 SHIELDSTRAL (\S+) \| log_cols (\d+) \| A rows (\d+) H rows (\d+) \| committed (\d+) \| U8 (\d+)", line)
            if m:
                out[m.group(1)] = dict(log_cols=int(m.group(2)), a_rows=int(m.group(3)), h_rows=int(m.group(4)), committed=int(m.group(5)), u8=int(m.group(6)))
    return out


def main():
    meas = r10.anchor()
    m8 = {dd: meas[("Llama-3-8B T128", dd)] for dd in (False, True)}
    base8 = {dd: r10.Layout(dict(L8, T=128, log_n=14), dd=dd).totals() for dd in (False, True)}
    fixed = {dd: fixed_per_block(m8[dd], 32) for dd in (False, True)}
    res, rust = {}, rust_totals()
    prof = {(128, False): "hashline-zk-mr1/private-block-shieldstral-3b-t128-trained-block/1", (256, False): "hashline-zk-mr1/private-block-shieldstral-3b-t256-trained-block/1",
            (128, True): "hashline-zk-mr1/private-block-shieldstral-3b-t128-trained-ddict/1", (256, True): "hashline-zk-mr1/private-block-shieldstral-3b-t256-trained-ddict/1"}
    for T in (128, 256, 512):
        for dd in (False, True):
            g = dict(SS, T=T, log_n=LOG_N[T])
            ss, e8, sp = r10.Layout(g, dd=dd).totals(), r10.Layout(dict(L8, T=T, log_n=LOG_N[T]), dd=dd).totals(), Split(g, dd=dd).totals()
            arg = per_block(m8[dd], base8[dd], ss, 32)
            fx = fixed[dd] * (W_SS / W_8B) * (T / 128)
            arg_sp = per_block(m8[dd], base8[dd], sp, 32)
            key = f"T{T}{' DD' if dd else ''}"
            r = dict(log_cols=LOG_N[T], committed=ss["committed"], u8=ss["u8"], element_terms=ss["element_terms"], a_rows=ss["a_rows"], h_rows=ss["h_rows"],
                     llama3_8b_committed=e8["committed"], equal_to_8b=(ss["committed"] == e8["committed"] and ss["u8"] == e8["u8"]),
                     model_argument_s_per_block=round(arg, 2), model_fixed_s_per_block=round(fx, 2), model_s_per_block=round(arg + fx, 2),
                     model_s_26_blocks=round(26 * (arg + fx), 1), model_peak_gib=round(PEAK_8B_T128[dd] * ss["committed"] / base8[dd]["committed"], 2),
                     split_committed=sp["committed"], split_u8=sp["u8"], split_element_terms=sp["element_terms"],
                     split_d_committed_pct=round(100 * (sp["committed"] / ss["committed"] - 1), 2), split_d_u8_pct=round(100 * (sp["u8"] / ss["u8"] - 1), 2),
                     split_d_element_terms_pct=round(100 * (sp["element_terms"] / ss["element_terms"] - 1), 2),
                     split_model_s_26_blocks=round(26 * (arg_sp + fx), 1), split_model_peak_gib=round(PEAK_8B_T128[dd] * sp["committed"] / base8[dd]["committed"], 2))
            if (T, dd) in prof and prof[(T, dd)] in rust:
                rt = rust[prof[(T, dd)]]
                r["rust_layout_equal"] = (rt["committed"], rt["u8"], rt["a_rows"], rt["h_rows"]) == (ss["committed"], ss["u8"], ss["a_rows"], ss["h_rows"])
                assert r["rust_layout_equal"], f"{key}: the replica {ss['committed']} / {ss['u8']} differs from the Rust layout {rt}"
            res[key] = r
            print(f"{key}: committed {ss['committed']:,} (8B {e8['committed']:,}, equal {r['equal_to_8b']}) U8 {ss['u8']:,} e-terms {ss['element_terms']:,} | "
                  f"time[M] {r['model_s_per_block']} s/block ({r['model_argument_s_per_block']} argument + {r['model_fixed_s_per_block']} witness/load), "
                  f"26 blocks {r['model_s_26_blocks']} s | peak[M] {r['model_peak_gib']} GiB | split width: committed {r['split_d_committed_pct']:+}% U8 {r['split_d_u8_pct']:+}% "
                  f"e-terms {r['split_d_element_terms_pct']:+}% -> {r['split_model_s_26_blocks']} s, {r['split_model_peak_gib']} GiB"
                  + (f" | Rust layout equal {r['rust_layout_equal']}" if "rust_layout_equal" in r else ""))
    out = dict(schema="zk60-native-r12-shieldstral-cost/1", weights_per_block=dict(shieldstral=W_SS, llama3_8b=W_8B), fixed_8b_t128_s_per_block=fixed,
               peak_8b_t128_gib={str(k): v for k, v in PEAK_8B_T128.items()}, results=res)
    json.dump(out, open(os.path.join(HERE, "r12_cost.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
