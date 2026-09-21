#!/usr/bin/env python3
"""An independent port of the SHAPE-driven slot schedule, for the slot-closure
reading `ZK60_SLOT_CLOSURES_SHAPED.md`.

Ported by hand from the Rust blobs at lane commit 8c5922b:
  hashline/src/private_block/shape.rs   (Shape::new, ::slots, ::claim_sites,
                                         ::slot_terms, ::slot_lengths,
                                         ::natural_log, ::log, ::pads,
                                         ::a_plane_doms, ::h_plane_doms,
                                         ::lookups_per_position, ::helpers)
  hashline/src/private_block/layout.rs  (domain_log_at, carries_h_planes,
                                         SLOT_KINDS, HOSTS, BASE_DEGREE via
                                         shape.rs)
  hashline/src/private_block/pad.rs     (pad_zero_host, a_rule, h_rule,
                                         zero_rule_{a,h}_planes)

Nothing here reads the Rust. The lane's own Python model
(scripts/zk60_private_block_layout_model.py, outputs
results/zk60_block125m_lane/model_*.json at 8c5922b) is used ONLY as a
cross-check at the end, and the two were written from the same Rust but not
from each other.

No witness value, no privacy claim.
"""
import json
import os
import sys

OUT = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- domains
DOMS = ["T", "Ht", "L", "D", "Q", "Kv", "S", "F", "Tab"]
U8_LEN = 256
LIMBS_ISQRT = 3
F_P = 9
NORM_TN = 11
NORM_CEPS = 1
INT16_MAX = 32767

# layout.rs:191-193
CARRIES_H = {d: d not in ("T", "Ht") for d in DOMS}

# shape.rs:58  BASE_DEGREE, in slot order
BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]

# layout.rs:798-820
(SC_SS, SC_SSM, SC_TZC, SC_LZC, SC_RS, SC_QMM, SC_KMM, SC_VMM, SC_SCORE,
 SC_PV, SC_WO, SC_GMM, SC_UMM, SC_DMM, SC_DZC, SC_QZC, SC_KVZC, SC_SZC,
 SC_FZC, SC_TAB, SC_ZS, SC_IO_IN, SC_IO_OUT) = range(23)
N_SLOTS = 23

SLOT_NAMES = [
    "01 SS row sums norm_a", "01m SS row sums norm_m", "02 norm squares zero-check",
    "08 limb zero-check", "07 masked row sums + selector", "09Q matmul", "09K matmul",
    "09V matmul", "10 score matmul", "11 PV matmul", "12 Wo matmul", "13G gate matmul",
    "13U up matmul", "13D down matmul", "03 D zero-check", "04 Q zero-check",
    "05 KV zero-check", "06 softmax zero-check", "14 F zero-check",
    "TAB table helper zero-check", "ZS zero-sum row", "IO-in endpoint equality",
    "IO-out endpoint equality",
]

# layout.rs:885-909
KIND = ["private", "private", "host", "standalone", "private", "private", "private",
        "private", "private", "private", "private", "private", "private", "private",
        "host", "host", "host", "host", "host", "standalone", "standalone",
        "standalone", "standalone"]

# layout.rs:912-919
HOSTS = {SC_TZC: [SC_SS, SC_SSM], SC_DZC: [SC_WO, SC_DMM], SC_QZC: [SC_QMM, SC_PV],
         SC_KVZC: [SC_KMM, SC_VMM], SC_SZC: [SC_RS, SC_SCORE], SC_FZC: [SC_GMM, SC_UMM]}

# shape.rs:65-66
INDICATOR_SLOT_DOMAIN = [(SC_SS, "D"), (SC_SSM, "D"), (SC_RS, "S"), (SC_DZC, "D"),
                         (SC_QZC, "Q"), (SC_KVZC, "Kv"), (SC_SZC, "S"), (SC_FZC, "F")]

# pad.rs:347-359
PAD_ZERO_HOST = {"T": SC_TZC, "Ht": SC_SZC, "L": SC_LZC, "D": SC_DZC, "Q": SC_QZC,
                 "Kv": SC_KVZC, "S": SC_SZC, "F": SC_FZC, "Tab": SC_TAB}


def clog2(v):
    assert v > 0
    return (v - 1).bit_length() if v > 1 else 0


def isqrt(v):
    x = 1
    while x * x <= v:
        x *= 2
    lo, hi = 0, x
    while lo < hi:
        m = (lo + hi + 1) // 2
        if m * m <= v:
            lo = m
        else:
            hi = m - 1
    return lo


class Shape:
    def __init__(self, name, profile, tokens, width, hidden, q_heads, head_dim,
                 kv_heads, log_cols, inv_rate, f_e, endpoint_rows,
                 endpoint_log_n=None, endpoint_inv_rate=None):
        self.name, self.profile = name, profile
        self.tokens, self.width, self.hidden = tokens, width, hidden
        self.q_heads, self.head_dim, self.kv_heads = q_heads, head_dim, kv_heads
        self.log_cols, self.inv_rate, self.f_e = log_cols, inv_rate, f_e
        self.endpoint_rows = endpoint_rows
        self.endpoint_log_n = log_cols if endpoint_log_n is None else endpoint_log_n
        self.endpoint_inv_rate = inv_rate if endpoint_inv_rate is None else endpoint_inv_rate
        self.t_pad = 1 << clog2(tokens)
        self.d_pad = 1 << clog2(width)
        self.h_pad = 1 << clog2(q_heads)
        self.f_pad = 1 << clog2(hidden)
        assert self.d_pad == self.h_pad * head_dim, name
        assert q_heads % kv_heads == 0 and self.h_pad % kv_heads == 0, name
        self.d_max = isqrt(NORM_CEPS + width * INT16_MAX * INT16_MAX)
        # shape.rs:222-224
        self.norm_wrho = NORM_TN + 1 + self.d_max.bit_length()
        self.wrho_s = clog2(tokens) + f_e
        # shape.rs:289 (ruling S-1) and :317 (ruling S-3)
        assert self.log("Tab") == log_cols, "ruling S-1 refusal"
        assert head_dim < (1 << log_cols), "ruling S-3 refusal"

    # shape.rs:593-606
    def natural_log(self, dom):
        s = self
        return {"T": clog2(s.t_pad), "Ht": clog2(s.h_pad * s.t_pad),
                "L": clog2(16 * s.t_pad), "D": clog2(s.t_pad * s.d_pad),
                "Q": clog2(s.t_pad * s.h_pad * s.head_dim),
                "Kv": clog2(s.t_pad * s.kv_heads * s.head_dim),
                "S": clog2(s.h_pad * s.t_pad * s.t_pad),
                "F": clog2(s.t_pad * s.f_pad), "Tab": clog2(U8_LEN)}[dom]

    # shape.rs:608-620
    def true_size(self, dom):
        s = self
        return {"T": s.tokens, "Ht": s.q_heads * s.tokens,
                "L": 3 * LIMBS_ISQRT * s.tokens, "D": s.tokens * s.width,
                "Q": s.tokens * s.q_heads * s.head_dim,
                "Kv": s.tokens * s.kv_heads * s.head_dim,
                "S": s.q_heads * s.tokens * s.tokens, "F": s.tokens * s.hidden,
                "Tab": U8_LEN}[dom]

    # layout.rs:170-176 + shape.rs:622-624
    def log(self, dom):
        nat = self.natural_log(dom)
        return self.log_cols if (CARRIES_H[dom] and nat < self.log_cols) else nat

    def size(self, dom):
        return 1 << self.log(dom)

    def rows_of(self, dom):
        return max(1, self.size(dom) >> self.log_cols)

    def pads(self, dom):
        return self.size(dom) != self.true_size(dom)

    def carries_pad_rule(self):
        return self.profile != "hashline-zk-mr1/private-block-t32-poc/1"

    # shape.rs:575-589
    def limbs_norm(self):
        return -(-self.norm_wrho // 8)

    def norm_top_is_full_byte(self):
        return self.norm_wrho == 8 * self.limbs_norm()

    def limbs_sigma_s(self):
        return -(-self.wrho_s // 8)

    def limbs_p(self):
        return -(-(F_P + 1) // 8)

    # shape.rs:639-654
    def a_plane_doms(self):
        ln = self.limbs_norm()
        v = ["T"] * 4 + ["Ht"] * 2 + ["L"] * 2
        v += ["D"] * (4 + 2 * ln + 8 + 2 * ln + 7)
        v += ["Q"] * 7 + ["Kv"] * 6
        v += ["S"] * (5 + self.limbs_p() + 2 * self.limbs_sigma_s())
        v += ["F"] * 11 + ["Tab"] * 3
        return v

    # shape.rs:658-676
    def lookups_per_position(self, dom):
        ln = self.limbs_norm()
        top = 0 if self.norm_top_is_full_byte() else 1
        per_norm = 2 + 2 * (ln + top)
        return {"L": 2, "D": 2 + per_norm + 6 + per_norm + 2 + 4, "F": 9, "Q": 13,
                "Kv": 12,
                "S": 2 + 2 + (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),
                "T": 0, "Ht": 0, "Tab": 0}[dom]

    def helpers(self, dom):
        return -(-self.lookups_per_position(dom) // 2)

    # shape.rs:684-696
    def h_plane_doms(self):
        v = ["L"] * self.helpers("L") + ["D"] * self.helpers("D")
        v += ["Q"] * self.helpers("Q") + ["Kv"] * self.helpers("Kv")
        v += ["S"] * (self.helpers("S") + 1)
        v += ["F"] * (self.helpers("F") + 1)
        v += ["Tab"] * 4
        return v

    def a_planes_on(self, dom):
        return self.a_plane_doms().count(dom)

    # shape.rs:704-739
    def claim_sites(self):
        a = [0] * N_SLOTS
        h = [0] * N_SLOTS
        a[SC_SS] = 1
        a[SC_SSM] = 1
        a[SC_TZC] = 4 + 2 * (3 * LIMBS_ISQRT)
        a[SC_LZC] = self.a_planes_on("L")
        h[SC_LZC] = self.helpers("L")
        a[SC_RS] = 2
        for s in (SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM):
            a[s] = 1
        a[SC_SCORE] = 2
        a[SC_PV] = 2
        a[SC_DZC] = self.a_planes_on("D") + 2
        h[SC_DZC] = self.helpers("D")
        a[SC_QZC] = self.a_planes_on("Q") + 1
        h[SC_QZC] = self.helpers("Q")
        a[SC_KVZC] = self.a_planes_on("Kv") + 1
        h[SC_KVZC] = self.helpers("Kv")
        a[SC_SZC] = self.a_planes_on("S") + 2
        h[SC_SZC] = self.helpers("S") + 1
        a[SC_FZC] = self.a_planes_on("F")
        h[SC_FZC] = self.helpers("F") + 1
        a[SC_TAB] = 3
        h[SC_TAB] = 3
        h[SC_ZS] = 1
        a[SC_IO_IN] = 1
        a[SC_IO_OUT] = 1
        return a, h

    # shape.rs:742-749
    def slot_terms(self):
        a, h = self.claim_sites()
        return [a[s] + h[s] + (1 if s >= SC_IO_IN else 0) for s in range(N_SLOTS)]

    # shape.rs:756-807
    def slots(self):
        cube = {SC_SS: "D", SC_SSM: "D", SC_DZC: "D", SC_IO_IN: "D", SC_IO_OUT: "D",
                SC_TZC: "T", SC_LZC: "L", SC_RS: "S", SC_SZC: "S", SC_QZC: "Q",
                SC_KVZC: "Kv", SC_FZC: "F", SC_TAB: "Tab", SC_ZS: "Tab"}
        lkv = clog2(self.kv_heads)
        inner = {SC_QMM: clog2(self.d_pad), SC_KMM: clog2(self.d_pad),
                 SC_VMM: clog2(self.d_pad), SC_WO: clog2(self.d_pad),
                 SC_GMM: clog2(self.d_pad), SC_UMM: clog2(self.d_pad),
                 SC_SCORE: lkv + clog2(self.head_dim),
                 SC_PV: lkv + clog2(self.t_pad), SC_DMM: clog2(self.f_pad)}
        out = []
        for s in range(N_SLOTS):
            main = self.log(cube[s]) if s in cube else inner[s]
            indicator = self.carries_pad_rule() and any(
                sl == s and self.pads(d) for sl, d in INDICATOR_SLOT_DOMAIN)
            ext = 2 if s in (SC_SCORE, SC_PV) else 1
            group_eq = s in (SC_SCORE, SC_PV) and lkv > 0
            out.append((main, ext, BASE_DEGREE[s] + int(indicator) + int(group_eq)))
        return out

    def slot_lengths(self):
        return [(m + e) * d + 2 for (m, e, d) in self.slots()]

    # pad.rs:289-303 / :314-326 / :365-381
    def a_rule(self, idx, dom):
        if not self.pads(dom):
            return None
        # ids.is_multiplicity: the three Dom::Tab histograms
        if dom == "Tab":
            return "Zero"
        # A_E is the exp plane, the first of the Dom::S block after A_S8..:
        # named by position below in zero_rule_a_planes
        return "Zero"

    def zero_rule_a_planes(self, dom):
        """plane indices (global A order) with Rule::Zero on `dom`."""
        if not self.carries_pad_rule() or not self.pads(dom):
            return []
        doms = self.a_plane_doms()
        out = []
        a_e = self.a_plane_index_of_exp()
        for p, d in enumerate(doms):
            if d != dom:
                continue
            if p == a_e:
                continue  # pad.rs:299-301, EXEMPT by name
            out.append(p)
        return out

    def a_plane_index_of_exp(self):
        """A_E's index in the shaped A plane list.

        The Dom::S block is, in plane order (layout.rs' A plane table):
        A_S8, A_RSL, A_ZSEL, A_E, A_P, then limbs_p() p-limbs, then
        limbs_sigma_s() rho_s limbs and limbs_sigma_s() sigma_s limbs.
        So A_E is the 4th plane of the Dom::S block.
        """
        doms = self.a_plane_doms()
        first_s = doms.index("S")
        return first_s + 3

    def zero_rule_h_planes(self, dom):
        if not self.carries_pad_rule() or not self.pads(dom):
            return []
        doms = self.h_plane_doms()
        n = len(doms)
        out = []
        for p, d in enumerate(doms):
            if d != dom:
                continue
            if p == n - 1:      # H_U: Rule::None
                continue
            if p >= n - 4:      # the three table helpers: Rule::Zero
                out.append(p)
        return out

    def pad_hosting(self):
        """slot -> the padded domains whose pad-zero term it hosts (ALL_DOMS order)"""
        out = {}
        for d in DOMS:
            if PAD_ZERO_HOST[d] != PAD_ZERO_HOST[d]:
                continue
            planes = self.zero_rule_a_planes(d)
            if not planes:
                continue
            out.setdefault(PAD_ZERO_HOST[d], []).append(d)
        return out


SHAPES = {
    "toy": Shape("toy block", "hashline-zk-mr1/private-block-t32-poc/1",
                 32, 16, 16, 2, 8, 1, 8, 8, 9, 7),
    "rung_g": Shape("development rung, generalised endpoint",
                    "hashline-zk-mr1/private-block-rung-g-t24-dev/1",
                    24, 96, 192, 6, 16, 2, 10, 4, 12, 9),
    "rung_k4": Shape("development rung, four key-value heads",
                     "hashline-zk-mr1/private-block-rung-k4-t24-dev/1",
                     24, 96, 192, 12, 8, 4, 10, 4, 12, 9),
    "m125": Shape("125M private block", "hashline-zk-mr1/private-block-m125/1",
                  512, 768, 2048, 12, 64, 4, 14, 4, 9, 37),
}


def report():
    doc = {}
    for key, sh in SHAPES.items():
        a, h = sh.claim_sites()
        sl = sh.slots()
        hosting = sh.pad_hosting()
        rows = []
        for s in range(N_SLOTS):
            rows.append({
                "slot": s, "name": SLOT_NAMES[s], "kind": KIND[s],
                "main": sl[s][0], "ext": sl[s][1], "degree": sl[s][2],
                "L": sh.slot_lengths()[s],
                "a_sites": a[s], "h_sites": h[s], "terminals": sh.slot_terms()[s],
                "hosts": HOSTS.get(s, []),
                "gains_a_degree_from_the_indicator": bool(
                    sh.carries_pad_rule()
                    and any(sl_ == s and sh.pads(d) for sl_, d in INDICATOR_SLOT_DOMAIN)),
                "carries_group_eq": s in (SC_SCORE, SC_PV) and clog2(sh.kv_heads) > 0,
                "group_bits": clog2(sh.kv_heads) if s in (SC_SCORE, SC_PV) else 0,
                "pad_zero_domains_hosted": hosting.get(s, []),
                "pad_zero_a_planes": sum(len(sh.zero_rule_a_planes(d))
                                         for d in hosting.get(s, [])),
                "pad_zero_h_planes": sum(len(sh.zero_rule_h_planes(d))
                                         for d in hosting.get(s, [])),
            })
        doc[key] = {
            "shape": {"tokens": sh.tokens, "width": sh.width, "hidden": sh.hidden,
                      "q_heads": sh.q_heads, "kv_heads": sh.kv_heads,
                      "head_dim": sh.head_dim, "log_cols": sh.log_cols,
                      "t_pad": sh.t_pad, "d_pad": sh.d_pad, "h_pad": sh.h_pad,
                      "f_pad": sh.f_pad, "limbs_norm": sh.limbs_norm(),
                      "limbs_sigma_s": sh.limbs_sigma_s(),
                      "endpoint_rows": sh.endpoint_rows,
                      "endpoint_log_n": sh.endpoint_log_n},
            "domain_log": {d: sh.log(d) for d in DOMS},
            "domain_pads": {d: sh.pads(d) for d in DOMS},
            "padded_domains": [d for d in DOMS if sh.pads(d)],
            "pad_zero_hosting_slots": {str(k): v for k, v in hosting.items()},
            "largest_L": max(sh.slot_lengths()),
            "L_plus_256_le_512": max(sh.slot_lengths()) + 256 <= 512,
            "total_main_rounds": sum(x[0] for x in sl),
            "total_extension_rounds": sum(x[1] for x in sl),
            "a_sites_total": sum(a), "h_sites_total": sum(h),
            "terminals_total": sum(sh.slot_terms()),
            "slots": rows,
        }
    return doc


def crosscheck(doc):
    """Compare with the lane's own model JSONs (written from the same Rust,
    independently)."""
    base = os.environ.get("MODEL_DIR", "")
    out = []
    for key in ("toy", "rung_g", "rung_k4", "m125"):
        path = os.path.join(base, "model_%s.json" % key)
        if not os.path.exists(path):
            out.append("%s: model json not found at %s (skipped)" % (key, path))
            continue
        m = json.load(open(path))
        ok, bad = 0, []
        for r, ms in zip(doc[key]["slots"], m["slots"]):
            for f, g in (("main", "main_rounds"), ("ext", "extension_rounds"),
                         ("degree", "degree"), ("L", "L")):
                if r[f] == ms[g]:
                    ok += 1
                else:
                    bad.append("slot %02d %s: mine %s, model %s" % (r["slot"], f, r[f], ms[g]))
        a, h = SHAPES[key].claim_sites()
        for i, (x, y) in enumerate(zip(a, m["claim_sites"]["a"])):
            if x == y:
                ok += 1
            else:
                bad.append("slot %02d a_sites: mine %s, model %s" % (i, x, y))
        for i, (x, y) in enumerate(zip(h, m["claim_sites"]["h"])):
            if x == y:
                ok += 1
            else:
                bad.append("slot %02d h_sites: mine %s, model %s" % (i, x, y))
        out.append("%s: %d checks equal, %d different %s" % (key, ok, len(bad), bad))
    return out


if __name__ == "__main__":
    doc = report()
    doc["_crosscheck_against_the_lane_model"] = crosscheck(doc)
    with open(os.path.join(OUT, "slot_table.json"), "w") as f:
        json.dump(doc, f, indent=1, sort_keys=True)
    for line in doc["_crosscheck_against_the_lane_model"]:
        print(line)
    for key in ("rung_g", "rung_k4", "m125"):
        d = doc[key]
        print("\n== %s: padded %s; pad-zero hosts %s; largest L %d; "
              "main %d ext %d; A sites %d H sites %d terminals %d"
              % (key, d["padded_domains"], sorted(d["pad_zero_hosting_slots"]),
                 d["largest_L"], d["total_main_rounds"], d["total_extension_rounds"],
                 d["a_sites_total"], d["h_sites_total"], d["terminals_total"]))
        for r in d["slots"]:
            print("  %02d %-32s %-10s (%2d,%d,%d) L=%3d A=%2d H=%2d terms=%2d %s%s%s"
                  % (r["slot"], r["name"], r["kind"], r["main"], r["ext"], r["degree"],
                     r["L"], r["a_sites"], r["h_sites"], r["terminals"],
                     "geq " if r["carries_group_eq"] else "",
                     "ind " if r["gains_a_degree_from_the_indicator"] else "",
                     ("pz" + str(r["pad_zero_domains_hosted"])) if r["pad_zero_domains_hosted"] else ""))
