"""Light replica of hashline private_block::shape counted layouts (read-only arithmetic).

Source of every formula: ops/zkp-mvp/trained-1b/hashline/src/private_block/shape.rs
(natural_log, true_size, log, rows_of, a_plane_doms, lookups_per_position, helpers,
h_plane_doms, claim_sites, slots, totals, a_groups, receipt_bytes) and layout.rs
(domain_log_at, the P-3 lift).  Checked against the counted ladder printed by
`the_trained_tinyllama_counted_layout_ladder` (results/zk60_1b_native_20261017/r3-ladder-count.log)
and the 8B counted layouts in PROGRESS.md R4-1.  One thread, pure integers.
"""

U8_LEN = 256
LIMBS_ISQRT = 3
COL_CHECKS = 256
MASK_VEC = 1024
MASK_PATH = 12
WIRE_HEADER = 40
N_SLOTS = 23
F_P = 9
INV_RATE = 4
MASK_ROWS = 5
(SC_SS, SC_SSM, SC_TZC, SC_LZC, SC_RS, SC_QMM, SC_KMM, SC_VMM, SC_SCORE, SC_PV, SC_WO, SC_GMM,
 SC_UMM, SC_DMM, SC_DZC, SC_QZC, SC_KVZC, SC_SZC, SC_FZC, SC_TAB, SC_ZS, SC_IO_IN, SC_IO_OUT) = range(23)
BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]
DOMS = ["T", "Ht", "L", "D", "Q", "Kv", "S", "F", "Tab"]
LOOKUP_DOMS = ["L", "D", "Q", "Kv", "S", "F"]
INDICATOR = [(SC_SS, "D"), (SC_SSM, "D"), (SC_RS, "S"), (SC_DZC, "D"), (SC_QZC, "Q"),
             (SC_KVZC, "Kv"), (SC_SZC, "S"), (SC_FZC, "F")]


def clog2(v):
    assert v > 0
    return (v - 1).bit_length()


def npow2(v):
    return 1 << clog2(v)


class Shape:
    def __init__(self, T, d, f, h, hd, kv, log_cols, f_e=9, norm_wrho=32, endpoint_rows=None):
        self.T, self.d, self.f, self.h, self.hd, self.kv = T, d, f, h, hd, kv
        self.t_pad, self.d_pad, self.h_pad, self.f_pad = npow2(T), npow2(d), npow2(h), npow2(f)
        assert self.d_pad == self.h_pad * hd
        self.log_cols = log_cols
        self.n = 1 << log_cols
        self.wrho_s = clog2(T) + f_e
        assert self.wrho_s <= 24, "softmax window rule clog2(T)+f_e <= 24"
        self.norm_wrho = norm_wrho
        self.ln = (norm_wrho + 7) // 8
        self.top = 0 if norm_wrho == 8 * self.ln else 1
        self.ls = (self.wrho_s + 7) // 8
        self.lp = (F_P + 1 + 7) // 8
        self.endpoint_rows = endpoint_rows if endpoint_rows is not None else ((self.t_pad * d) >> log_cols) + MASK_ROWS
        # validator conditions named in shape.rs / the counted ladder
        assert clog2(self.t_pad) < log_cols, "S-6: padded token count must be below the row width"
        assert self.natural_log("Kv") >= log_cols, "bilinear slots refuse a Kv domain lifted by P-3"
        assert log_cols >= 8, "row width at least the table's natural size (Tab)"

    def natural_log(self, dom):
        t, h, hd, kv = self.t_pad, self.h_pad, self.hd, self.kv
        return {"T": clog2(t), "Ht": clog2(h * t), "L": clog2(16 * t), "D": clog2(t * self.d_pad),
                "Q": clog2(t * h * hd), "Kv": clog2(t * kv * hd), "S": clog2(h * t * t),
                "F": clog2(t * self.f_pad), "Tab": clog2(U8_LEN)}[dom]

    def true_size(self, dom):
        T = self.T
        return {"T": T, "Ht": self.h * T, "L": 3 * LIMBS_ISQRT * T, "D": T * self.d, "Q": T * self.h * self.hd,
                "Kv": T * self.kv * self.hd, "S": self.h * T * T, "F": T * self.f, "Tab": U8_LEN}[dom]

    def log(self, dom):
        nat = self.natural_log(dom)
        carries_h = dom not in ("T", "Ht")
        return self.log_cols if (carries_h and nat < self.log_cols) else nat

    def size(self, dom):
        return 1 << self.log(dom)

    def rows_of(self, dom):
        return max(1, self.size(dom) >> self.log_cols)

    def pads(self, dom):
        return self.size(dom) != self.true_size(dom)

    def a_plane_doms(self):
        ln = self.ln
        v = ["T"] * 4 + ["Ht"] * 2 + ["L"] * 2 + ["D"] * (4 + 2 * ln + 8 + 2 * ln + 7) + ["Q"] * 7 + ["Kv"] * 6
        v += ["S"] * (5 + self.lp + 2 * self.ls) + ["F"] * 11 + ["Tab"] * 3
        return v

    def lookups_per_position(self, dom):
        per_norm = 2 + 2 * (self.ln + self.top)
        return {"L": 2, "D": 2 + per_norm + 6 + per_norm + 2 + 4, "F": 9, "Q": 13, "Kv": 12,
                "S": 2 + 2 + (self.lp + 1) + 2 * (self.ls + 1)}.get(dom, 0)

    def helpers(self, dom):
        return (self.lookups_per_position(dom) + 1) // 2

    def h_plane_doms(self):
        v = ["L"] * self.helpers("L") + ["D"] * self.helpers("D") + ["Q"] * self.helpers("Q") + ["Kv"] * self.helpers("Kv")
        v += ["S"] * (self.helpers("S") + 1) + ["F"] * (self.helpers("F") + 1) + ["Tab"] * 4
        return v

    def a_planes_on(self, dom):
        return self.a_plane_doms().count(dom)

    def claim_sites(self):
        a, h = [0] * N_SLOTS, [0] * N_SLOTS
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

    def slots(self):
        cube = {SC_SS: "D", SC_SSM: "D", SC_DZC: "D", SC_IO_IN: "D", SC_IO_OUT: "D", SC_TZC: "T", SC_LZC: "L",
                SC_RS: "S", SC_SZC: "S", SC_QZC: "Q", SC_KVZC: "Kv", SC_FZC: "F", SC_TAB: "Tab", SC_ZS: "Tab"}
        lkv = clog2(self.kv) if self.kv > 1 else 0
        inner = {SC_QMM: clog2(self.d_pad), SC_KMM: clog2(self.d_pad), SC_VMM: clog2(self.d_pad), SC_WO: clog2(self.d_pad),
                 SC_GMM: clog2(self.d_pad), SC_UMM: clog2(self.d_pad), SC_SCORE: lkv + clog2(self.hd),
                 SC_PV: lkv + clog2(self.t_pad), SC_DMM: clog2(self.f_pad)}
        out = []
        for s in range(N_SLOTS):
            main = self.log(cube[s]) if s in cube else inner[s]
            ind = any(sl == s and self.pads(dm) for sl, dm in INDICATOR)
            ext = 2 if s in (SC_SCORE, SC_PV) else 1
            geq = (s in (SC_SCORE, SC_PV)) and lkv > 0
            out.append((main, ext, BASE_DEGREE[s] + int(ind) + int(geq)))
        return out

    def a_rows(self):
        data = sum(self.rows_of(d) for d in self.a_plane_doms())
        return data + 2 * sum(self.claim_sites()[0]) + 2

    def h_rows(self):
        data = sum(2 * self.rows_of(d) for d in self.h_plane_doms())
        return data + 2 * sum(self.claim_sites()[1]) + 2

    def u8_lookups(self):
        return sum(self.lookups_per_position(d) * self.size(d) for d in LOOKUP_DOMS)

    def a_groups(self):
        n = self.n
        offs = sorted(set([(k * self.t_pad) % n for k in range(3 * LIMBS_ISQRT)] + [0]))
        return len(offs) + 15 + 4 + 8

    def receipt_bytes(self):
        n = self.n
        vec_len = n + COL_CHECKS
        path = clog2(n * INV_RATE)

        def opening(groups, rows, vc, pth):
            return (groups + 1) * vc * 16 + COL_CHECKS * (8 + rows * 8 + 32 + pth * 32)
        sl = self.slots()
        a, h = self.claim_sites()
        terms = [a[s] + h[s] + int(s >= SC_IO_IN) for s in range(N_SLOTS)]
        slot_words = sum(1 + (sl[s][0] + sl[s][1]) * (sl[s][2] + 1) + terms[s] for s in range(N_SLOTS))
        mask_opening = 2 * MASK_VEC * 16 + COL_CHECKS * (8 + (2 * N_SLOTS + 4) * 8 + 32 + MASK_PATH * 32)
        total = WIRE_HEADER + 96 + slot_words * 16 + mask_opening + opening(self.a_groups(), self.a_rows(), vec_len, path) \
            + opening(9, self.h_rows(), vec_len, path) + 2 * opening(1, self.endpoint_rows, vec_len, path)
        return total

    def zc_terms(self):
        a, h = self.claim_sites()
        return {"D": a[SC_DZC] + h[SC_DZC], "Q": a[SC_QZC] + h[SC_QZC], "Kv": a[SC_KVZC] + h[SC_KVZC],
                "S": a[SC_SZC] + h[SC_SZC], "F": a[SC_FZC] + h[SC_FZC]}

    def summary(self):
        return {"A_rows": self.a_rows(), "H_rows": self.h_rows(), "n": self.n,
                "A_elems": self.a_rows() * self.n, "H_elems": self.h_rows() * self.n,
                "u8": self.u8_lookups(), "exp_pairs": self.size("S"), "act_pairs": self.size("F"),
                "sizes": {d: self.size(d) for d in DOMS}, "terms": self.zc_terms(),
                "receipt": self.receipt_bytes(), "endpoint_rows": self.endpoint_rows,
                "slot_len_max": max((m + e) * dg + 2 for m, e, dg in self.slots())}


def tinyllama(T, log_cols):
    return Shape(T, 2048, 5632, 32, 64, 4, log_cols)


def llama3_8b(T, log_cols):
    return Shape(T, 4096, 14336, 32, 128, 8, log_cols)


if __name__ == "__main__":
    # check against the counted ladder (r3-ladder-count.log) and R4-1
    checks = [
        (tinyllama(32, 12), 1729, 1798, 11627208, 5971968),
        (tinyllama(64, 13), 1817, 1926, 15445848, 12795904),
        (tinyllama(128, 14), 1993, 2182, 23049192, 28999680),
        (tinyllama(256, 14), 4697, 5536, 35522536, 75792384),
        (tinyllama(512, 16), 3309, 3976, 69594424, 214564864),
        (tinyllama(512, 13), 24675, 31024, 122313464, 214450176),
    ]
    for sh, ar, hr, rb, u8 in checks:
        s = sh.summary()
        ok = (s["A_rows"], s["H_rows"], s["receipt"], s["u8"]) == (ar, hr, rb, u8)
        print("TinyLlama T%d 2^%d: A %d (%d) H %d (%d) receipt %d (%d) u8 %d (%d) %s" % (
            sh.T, sh.log_cols, s["A_rows"], ar, s["H_rows"], hr, s["receipt"], rb, s["u8"], u8, "OK" if ok else "MISMATCH"))
    for lc, rb in [(11, 28970648), (12, 17878872), (13, 14856216), (14, 18374872), (15, 30177688)]:
        s = llama3_8b(32, lc).summary()
        print("Llama-3-8B T32 2^%d: receipt %d (counted %d) %s" % (lc, s["receipt"], rb, "OK" if s["receipt"] == rb else "MISMATCH"))
