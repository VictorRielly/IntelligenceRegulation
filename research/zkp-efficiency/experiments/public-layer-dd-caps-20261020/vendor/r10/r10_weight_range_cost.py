#!/usr/bin/env python3
"""NATIVE R10 (paper and counting only): what the weight-range levers cost the
proof, counted on native R9's layout.

THE REPLICA. `Layout` re-states, line for line, the counting functions of the
frozen R9 tree (r9/frozen-tree/hashline/src/private_block/):
  shape.rs  a_plane_doms, lookups_per_position, helpers, h_plane_doms,
            claim_sites, slots (main / extension rounds), totals, receipt_bytes
  layout.rs lookups_at (which lookup each remainder limb carries), domain_log_at
  argument.rs define() (how many TABLES each slot's sumcheck reads: the
            runtime element-terms of HL_PB_TIMING are 2^(main+ext) x tables)
with one generalisation: the remainder of each WEIGHT matmul output site
(q, k, v, ao, g, u, z) is a parameter (byte limbs, top pins) instead of R9's
literal (1 limb + 1 pin at q/k/v/ao/g/z; none at u, where sh_u = 0).

THE ANCHOR. Before any option is counted, the replica must reproduce, for the
four R9-tree runs at T128 (R8 CLI = R9 non-DD, byte-identical; R9 --dd), every
counted size the prover itself printed in HL_PB_TIMING: A words, H words, the
byte lookups, both mask-row sizes and the element-terms of all 23 / 24 slots;
and the counted receipt delta DD made (+235,008 B per block, both shapes).
The script asserts all of it and stops on any difference.

THE OPTIONS. (a) two-byte remainders; (b) per-output-channel public
multipliers (three-byte remainders, a four-byte sensitivity row); (c) the
cheaper variants; each against R9 non-DD and R9 DD at TinyLlama T128,
Llama-3-8B T128 and Llama-3-8B T512 (T512: row 2^15, the review's anchor
geometry; no T512 profile is registered, so T512 is a COUNTED layout only).

Labels: every count is [COUNTED] (exact on the replica that reproduces the
built layout); the prove-time figure is a [MODEL] (each measured phase scaled
by its own counted size). Writes r10_weight_range_cost.json beside itself.
usage: python3 r10_weight_range_cost.py"""
import json
import math
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def clog2(v):
    return (v - 1).bit_length()


def npow2(v):
    return 1 << clog2(v)


# shape.rs constants
F_P = 9
LIMBS_ISQRT = 3
U8_LEN_LOG = 8
COL_CHECKS = 256
DD_CAP = 32
SITES = ("q", "k", "v", "ao", "g", "u", "z")
SITE_DOM = {"q": "Q", "k": "Kv", "v": "Kv", "ao": "D", "g": "F", "u": "F", "z": "D"}
SITE_PLANE = {"q": "A_RQL", "k": "A_RKL", "v": "A_RVL", "ao": "A_RAL", "g": "A_RGL", "u": "(none: sh_u = 0)", "z": "A_RDL"}
# R9: one byte limb + one top pin `scaled(r, 2^(8 - sh))` at q/k/v/ao/g/z; no remainder at u
R9_SITES = {s: ((1, 1) if s != "u" else (0, 0)) for s in SITES}

GEOMS = {
    "TinyLlama-1.1B T128": dict(T=128, h=32, hd=64, kv=4, d=2048, hidden=5632, log_n=14, f_e=9),
    "Llama-3-8B T128": dict(T=128, h=32, hd=128, kv=8, d=4096, hidden=14336, log_n=14, f_e=9),
    "Llama-3-8B T512": dict(T=512, h=32, hd=128, kv=8, d=4096, hidden=14336, log_n=15, f_e=9),
}


class Layout:
    """R9's counted layout at one geometry, DD on or off, with the remainder of
    each weight-matmul site given as (byte limbs, top pins)."""

    def __init__(self, g, dd=False, sites=None, ln=4, norm_top=0, extra=None):
        self.g, self.dd = g, dd
        self.sites = dict(R9_SITES if sites is None else sites)
        self.extra = dict(extra or {})
        T, h, hd, kv, d, hid, self.log_n = g["T"], g["h"], g["hd"], g["kv"], g["d"], g["hidden"], g["log_n"]
        self.n = 1 << self.log_n
        self.t_pad, self.h_pad, self.d_pad, self.f_pad = npow2(T), npow2(h), npow2(d), npow2(hid)
        self.cap = DD_CAP if dd else 0
        self.ln, self.top = ln, norm_top
        wrho_s = clog2(T) + g["f_e"]
        self.ls, self.lp = (wrho_s + 7) // 8, (F_P + 1 + 7) // 8
        tp, hp = self.t_pad, self.h_pad
        nat = {"T": clog2(tp), "Ht": clog2(hp * tp), "L": clog2(16 * tp), "D": clog2(tp * self.d_pad), "Q": clog2(tp * hp * hd),
               "Kv": clog2(tp * kv * hd), "S": clog2(hp * tp * tp), "F": clog2(tp * self.f_pad), "Tab": U8_LEN_LOG, "Dd": clog2(hp * tp * max(1, self.cap))}
        true = {"T": T, "Ht": h * T, "L": 3 * LIMBS_ISQRT * T, "D": T * d, "Q": T * h * hd, "Kv": T * kv * hd, "S": h * T * T,
                "F": T * hid, "Tab": 1 << U8_LEN_LOG, "Dd": h * T * max(1, self.cap)}
        # layout.rs domain_log_at: every domain but T / Ht carries H planes and is lifted to the row width (P-3)
        self.log = {k: (max(v, self.log_n) if k not in ("T", "Ht") else v) for k, v in nat.items()}
        self.size = {k: 1 << v for k, v in self.log.items()}
        self.rows = {k: max(1, v >> self.log_n) for k, v in self.size.items()}
        # every profile but the frozen toy carries the pad rule; a padded domain's zero-check gets a support table
        self.pads = {k: self.size[k] != true[k] for k in self.size}
        self.lkv, self.ldh = clog2(kv), clog2(hd)

    # ---- the remainder sites -------------------------------------------------
    # `extra` = {dom: (A planes, lookups per position)} for a change that is not
    # a matmul remainder (the fused up variant: u16 -> int24 limbs, the product
    # remainder rh two -> three limbs)
    def site_planes(self, dom):
        return sum(self.sites[s][0] for s in SITES if SITE_DOM[s] == dom) + self.extra.get(dom, (0, 0))[0]

    def site_lookups(self, dom):
        # L byte limbs + p top pins (layout.rs: byte(l_i) for every limb, scaled(top, 2^(8L - sh)) per pin)
        return sum(self.sites[s][0] + self.sites[s][1] for s in SITES if SITE_DOM[s] == dom and self.sites[s][0] > 0) + self.extra.get(dom, (0, 0))[1]

    # ---- shape.rs a_plane_doms ----------------------------------------------
    def a_planes(self):
        ln, lp, ls = self.ln, self.lp, self.ls
        a = {"T": 4, "Ht": 2, "L": 2,
             # x, its two limbs, y; norm_a rho/sigma; ao + limbs, x1 + limbs; norm_m; z16, x2 + limbs, z16 limbs
             "D": 4 + 2 * ln + 7 + 2 * ln + 6 + self.site_planes("D"),
             "Q": 6 + self.site_planes("Q"),     # q8, qr8, rqrl, o8, ro0, ro1 + the Q remainder
             "Kv": 4 + self.site_planes("Kv"),   # k8, v8, kr8, rkrl + the K and V remainders
             "F": 10 + self.site_planes("F"),    # g8, a16, u16 + 2 limbs, h16 + 2 limbs, rh0, rh1 + gate (and up) remainders
             "Tab": 3}
        if self.dd:
            a["S"] = 5
            a["Dd"] = 2 + lp + 2 * ls
        else:
            a["S"] = 5 + lp + 2 * ls
        return a

    # ---- shape.rs lookups_per_position --------------------------------------
    def lookups(self):
        per_norm = 2 + 2 * (self.ln + self.top)
        lp, ls = self.lp, self.ls
        u = {"L": 2,
             # x limbs 2; norm_a; ao limbs 2 + x1 limbs 2; norm_m; x2 limbs 2; z16 limbs 2 (+ the AO and down remainders)
             "D": 2 + per_norm + 4 + per_norm + 2 + 2 + self.site_lookups("D"),
             "Q": 2 + 2 + 2 + 2 + 3 + self.site_lookups("Q"),   # sym(q8) sym(qr8) rqrl+pin sym(o8) ro0 ro1 pin
             "Kv": 2 + 2 + 2 + 2 + self.site_lookups("Kv"),     # sym(k8) sym(v8) sym(kr8) rkrl+pin
             "F": 2 + 2 + 3 + self.site_lookups("F"),           # ul0 ul1 hl0 hl1 rh0 rh1 pin
             }
        if self.dd:
            u["S"] = 4
            u["Dd"] = (lp + 1) + 2 * (ls + 1)
        else:
            u["S"] = 4 + (lp + 1) + 2 * (ls + 1)
        return u

    def helpers(self):
        return {k: (v + 1) // 2 for k, v in self.lookups().items()}

    # ---- shape.rs h_plane_doms ----------------------------------------------
    def h_planes(self):
        hp = self.helpers()
        out = {"L": hp["L"], "D": hp["D"], "Q": hp["Q"], "Kv": hp["Kv"], "S": hp["S"] + 1 + int(self.dd), "F": hp["F"] + 1, "Tab": 4}
        if self.dd:
            out["Dd"] = hp["Dd"] + 1
        return out

    # ---- shape.rs claim_sites -----------------------------------------------
    def claim_sites(self):
        a, hp = self.a_planes(), self.helpers()
        A = {"SS": 1, "SSM": 1, "TZC": 4 + 2 * (3 * LIMBS_ISQRT), "LZC": a["L"], "RS": 2, "QMM": 1, "KMM": 1, "VMM": 1, "SCORE": 2, "PV": 2,
             "WO": 1, "GMM": 1, "UMM": 1, "DMM": 1, "DZC": a["D"] + 2, "QZC": a["Q"] + 1, "KVZC": a["Kv"] + 1, "SZC": a["S"] + 2, "FZC": a["F"],
             "TAB": 3, "ZS": 0, "IO_IN": 1, "IO_OUT": 1}
        H = {"LZC": hp["L"], "DZC": hp["D"], "QZC": hp["Q"], "KVZC": hp["Kv"], "SZC": hp["S"] + 1 + int(self.dd), "FZC": hp["F"] + 1, "TAB": 3, "ZS": 1}
        if self.dd:
            A["DD"] = a["Dd"] + 1
            H["DD"] = hp["Dd"] + 1
        return A, H

    # ---- argument.rs define(): (main rounds, extension rounds, tables) per slot
    def slot_work(self):
        a, hp, lg, pads = self.a_planes(), self.helpers(), self.log, self.pads
        supp = lambda dom: int(pads[dom])
        S = [  # in transcript order (slot index = position)
            ("SS", lg["D"], 1, 2), ("SSM", lg["D"], 1, 2), ("TZC", lg["T"], 1, 25), ("LZC", lg["L"], 1, 5), ("RS", lg["S"], 1, 4),
            ("QMM", clog2(self.d_pad), 1, 2), ("KMM", clog2(self.d_pad), 1, 2), ("VMM", clog2(self.d_pad), 1, 2),
            ("SCORE", self.lkv + self.ldh, 2, 3), ("PV", self.lkv + clog2(self.t_pad), 2, 3), ("WO", clog2(self.d_pad), 1, 2),
            ("GMM", clog2(self.d_pad), 1, 2), ("UMM", clog2(self.d_pad), 1, 2), ("DMM", clog2(self.f_pad), 1, 2),
            # 3 eq + 2 gains + every D plane + the D / DM slices + helpers (+ support)
            ("DZC", lg["D"], 1, 3 + 2 + a["D"] + 2 + hp["D"] + supp("D")),
            # 3 eq + cos / sin + every plane + the flipped partner + helpers (+ support)
            ("QZC", lg["Q"], 1, 3 + 2 + a["Q"] + 1 + hp["Q"] + supp("Q")),
            ("KVZC", lg["Kv"], 1, 3 + 2 + a["Kv"] + 1 + hp["Kv"] + supp("Kv")),
            # 3 eq + mask + the S planes + MX / SUM slices + helpers + exp helper (+ tuple helper on DD)
            ("SZC", lg["S"], 1, 3 + 1 + a["S"] + 2 + hp["S"] + 1 + int(self.dd) + supp("S")),
            # 3 eq + every F plane + helpers + activation helper (+ support)
            ("FZC", lg["F"], 1, 3 + a["F"] + hp["F"] + 1 + supp("F")),
            ("TAB", lg["Tab"], 1, 11), ("ZS", lg["Tab"], 1, 2), ("IO_IN", lg["D"], 1, 3), ("IO_OUT", lg["D"], 1, 3),
        ]
        if self.dd:
            # eq + the Dd planes + SUM slice + the public e column + helpers + the table helper
            S.append(("DD", lg["Dd"], 1, 1 + a["Dd"] + 1 + 1 + hp["Dd"] + 1))
        return S

    # ---- shape.rs totals ----------------------------------------------------
    def totals(self):
        a, hpl, lk = self.a_planes(), self.h_planes(), self.lookups()
        A, H = self.claim_sites()
        a_sites, h_sites = sum(A.values()), sum(H.values())
        a_rows = sum(a[k] * self.rows[k] for k in a) + 2 * a_sites + 2
        h_rows = sum(2 * hpl[k] * self.rows[k] for k in hpl) + 2 * h_sites + 2
        sw = self.slot_work()
        et = {name: (1 << (m + e)) * t for (name, m, e, t) in sw}
        # the review's (CHECK.md / dd_check.py) convention: committed reads of the five / six domain zero-checks
        rv = {"D": (a["D"] + 2) + self.helpers()["D"], "Q": (a["Q"] + 1) + self.helpers()["Q"], "Kv": (a["Kv"] + 1) + self.helpers()["Kv"],
              "S": (a["S"] + 2) + hpl["S"], "F": a["F"] + hpl["F"]}
        if self.dd:
            rv["Dd"] = a["Dd"] + 1 + hpl["Dd"]
        return dict(
            a_rows=a_rows, h_rows=h_rows, a_words=a_rows * self.n, h_words=h_rows * self.n, committed=(a_rows + h_rows) * self.n,
            u8=sum(lk[k] * self.size[k] for k in lk), a_sites=a_sites, h_sites=h_sites,
            a_mask_words=(2 * a_sites + 2) * self.n, h_mask_words=(2 * h_sites + 2) * self.n,
            slot_terms=et, element_terms=sum(et.values()), review_terms=sum(self.size[k] * rv[k] for k in rv),
            a_planes=sum(a.values()), h_planes=sum(hpl.values()), lookups_per_position=lk, helpers=self.helpers(), a_by_dom=a)


def receipt_delta(base, new):
    """shape.rs receipt_bytes, the parts a remainder change can move: every
    slot term is one 16-byte word, every A / H row is 8 bytes in each of the
    256 column checks; groups, slots, degrees and mask rows do not move"""
    return 16 * ((new["a_sites"] + new["h_sites"]) - (base["a_sites"] + base["h_sites"])) + 8 * COL_CHECKS * ((new["a_rows"] + new["h_rows"]) - (base["a_rows"] + base["h_rows"]))


# ---- the anchor: the prover's own HL_PB_TIMING counts ------------------------
RUNS = {
    ("TinyLlama-1.1B T128", False): "r8/stack-tinyllama_dg_rot1_T128-ho00-cpu",
    ("Llama-3-8B T128", False): "r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu",
    ("TinyLlama-1.1B T128", True): "r9/stack-tinyllama_dg_rot1_T128-ho00-cpu-dd",
    ("Llama-3-8B T128", True): "r9/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu-dd",
}
SLOT_KEYS = ["SS", "SSM", "TZC", "LZC", "RS", "QMM", "KMM", "VMM", "SCORE", "PV", "WO", "GMM", "UMM", "DMM", "DZC", "QZC", "KVZC", "SZC", "FZC", "TAB", "ZS", "IO_IN", "IO_OUT", "DD"]


def timing_blocks(path):
    blocks, cur = [], None
    for line in open(path, errors="replace"):
        if line.startswith("PB-TIMING prove ["):
            cur = []
            blocks.append(cur)
            continue
        if not line.startswith("PB-TIMING prove |") or cur is None:
            continue
        parts = [p.strip() for p in line.split("|")]
        if parts[1] in ("phase", "SUM OF PHASES", "WALL CLOCK OF THE CALL", "unaccounted (wall - sum)"):
            continue
        m = re.match(r"(\d+) (\S+)", parts[5])
        cur.append((parts[1], parts[2], float(parts[3]), int(m.group(1)) if m else 0, m.group(2) if m else ""))
    return blocks


def size_key(label):
    """which counted quantity a phase's size column is (None: no layout term)"""
    if label.startswith("A: allocate") or label.startswith("A: commit") or label.startswith("open A"):
        return "a_words"
    if label.startswith("A: lookup values") or label.startswith("H: LogUp helper inverses"):
        return "u8"
    if label.startswith("A: mask + proximity"):
        return "a_mask_words"
    if label.startswith("H: mask rows"):
        return "h_mask_words"
    if label.startswith("H: commit") or label.startswith("open H"):
        return "h_words"
    m = re.match(r"slot (\d\d) ", label)
    if m:
        return ("slot", SLOT_KEYS[int(m.group(1))])
    return None


def counted(t, key):
    return t["slot_terms"][key[1]] if isinstance(key, tuple) else t[key]


def anchor():
    """assert the replica == the prover's printed sizes; return the measured
    per-phase (seconds summed over blocks, size, key) for the time model"""
    meas = {}
    for (geo, dd), rel in RUNS.items():
        t = Layout(GEOMS[geo], dd=dd).totals()
        bl = timing_blocks(os.path.join(ROOT, rel, "prove.log"))
        assert bl, rel
        first = bl[0]
        for (label, _, _, size, unit) in first:
            k = size_key(label)
            if k is not None:
                assert counted(t, k) == size, f"{rel}: replica {k} = {counted(t, k)} but the prover printed {size} ({label})"
        assert sum(1 for p in first if p[4] == "elem-terms") == len(t["slot_terms"]), rel
        # every block prints the same counted sizes; sum the seconds over blocks
        phases = {}
        for b in bl:
            for (label, half, sec, size, unit) in b:
                q = phases.setdefault(label, [0.0, size, size_key(label), half])
                q[0] += sec
        meas[(geo, dd)] = dict(blocks=len(bl), phases=phases, run=rel)
    # the counted receipt delta DD made, against the ledger's Shape::receipt_bytes figures (+235,008 B per block)
    return meas


def time_model(meas_geo_dd, t_base, t_new, per_unit_from=None):
    """[MODEL] each measured phase scaled by its own counted size; phases with
    no layout term kept. Returns (total_base, total_new, argument_base, argument_new)
    where 'argument' drops the phases with no layout term (run witness / load,
    exp/act histograms, mask commit) — the form used at T512, from the
    8B T128 per-unit costs"""
    tb = tn = ab = an = 0.0
    for label, (sec, size, key, half) in meas_geo_dd["phases"].items():
        if key is None:
            if per_unit_from is None:
                tb += sec
                tn += sec
            continue
        if per_unit_from is None:
            ob, nb = sec, sec * counted(t_new, key) / counted(t_base, key)
        else:
            unit = sec / size
            ob, nb = unit * counted(t_base, key), unit * counted(t_new, key)
        tb, tn, ab, an = tb + ob, tn + nb, ab + ob, an + nb
    return tb, tn, ab, an


def nowrap(sh, mult_bits=0, w_bits=8, up_sh=None):
    """nowrap_check.py shift_bounds, generalised: the host relation
    `2^sh q + r - 2^(sh-1) - m acc` at the top of the new window, |q| in its
    class, r < 2^sh, |m| < 2^mult_bits, public weights in [-2^(w-1), 2^(w-1)]
    (the worst-case accumulator class does not see how many bits the words
    use); `up_sh` None = R9's `u16 = acc` (no requant at up)"""
    d_pad, hid_pad = 4096, 16384
    w = 1 << (w_bits - 1)
    m = 1 << mult_bits
    host = lambda s_, q, acc: (2 ** s_) * q + (2 ** s_ - 1) + 2 ** (s_ - 1) + m * acc
    b = {"q/k/v": host(sh, 127, d_pad * 127 * w), "ao": host(sh, 32768, d_pad * 127 * w), "gate": host(sh, 128, d_pad * 127 * w),
         "down": host(sh, 32768, hid_pad * 32768 * w)}
    if up_sh is not None:
        b["up (new requant)"] = host(up_sh, 32768, d_pad * 127 * w)
    return {k: round(math.log2(v), 2) for k, v in b.items()}


def pct(a, b):
    return round(100.0 * (b / a - 1), 2)


def main():
    meas = anchor()
    # DD's counted receipt delta (ledger, from Shape::receipt_bytes via r9_tests): both shapes +235,008 B per block,
    # and the measured run receipts moved by exactly blocks x 235,008 (497,665,904 -> 502,836,080; 922,711,264 -> 930,231,520)
    assert 502_836_080 - 497_665_904 == 22 * 235_008 and 930_231_520 - 922_711_264 == 32 * 235_008
    receipts = {"TinyLlama-1.1B T128": (497_665_904, 502_836_080, 22), "Llama-3-8B T128": (922_711_264, 930_231_520, 32)}

    two = lambda pins=1: (2, pins)
    A1 = {**R9_SITES, "q": two(), "k": two(), "v": two(), "g": two(), "z": two()}
    A2 = {**A1, "ao": two()}
    FUSED_UP = {"F": (2, 2)}  # u16 -> int24 (UL2: +1 plane, +1 byte lookup); rh 2 -> 3 limbs (+1 plane, +1 byte; pin kept)
    # windows: an L-limb remainder with ONE top pin admits shifts [8(L-1), 8L] (one limb: [0, 8]);
    # a second pin (the union window) admits [1, 8L]. The `_need` rows are what r10_word_use.json
    # says the three current exports need (the union over them), site by site.
    OPTIONS = {
        "a_need": ("(a) EXACT NEED of the current exports at full per-tensor int8 range: q, k, v, g two-byte (8..=16); z two-byte union (1..=16); NEW one-byte at up (0..=8); ao unchanged",
                   {**R9_SITES, "q": two(), "k": two(), "v": two(), "g": two(), "z": two(2), "u": (1, 1)}, None),
        "a1": ("(a) the fidelity lane's earlier set: two-byte at q, k, v, g, z, one pin (refuses the layers with sh_z < 8; up stays sh_u = 0)", A1, None),
        "a1z": ("(a) a1 with the union window at z (a second pin)", {**A1, "z": two(2)}, None),
        "a2": ("(a) a1 + ao two-byte: all six existing remainders", A2, None),
        "a3_1": ("(a)/(c2) a2 + a NEW one-byte remainder at up (0..=8): every weight matmul has a window of 16 bits (up 8); = option (c2), narrow per-channel multipliers riding in these windows", {**A2, "u": (1, 1)}, None),
        "a3": ("(a) a2 + a NEW two-byte remainder at up (what int16 weights would need; the fidelity lane's R6 site set)", {s: two() for s in SITES}, None),
        "b_need": ("(b) EXACT NEED with 12-bit multipliers: q, k, v, g, z three-byte (16..=24); ao three-byte union (9..=24: s = 15 at TinyLlama / b7voc0); up two-byte (8..=16)",
                   {**{s: (3, 1) for s in SITES}, "ao": (3, 2), "u": two()}, None),
        "b3": ("(b) conservative: three-byte at all seven, new three-byte at up (the fidelity lane's site set)", {s: (3, 1) for s in SITES}, None),
        "b3m": ("(b) three-byte at the six, two-byte at up", {**{s: (3, 1) for s in SITES}, "u": two()}, None),
        "b4": ("(b) sensitivity: four-byte remainders at all seven", {s: (4, 1) for s in SITES}, None),
        "b3_5": ("(b) multipliers only at q, k, v, g, z (three-byte); ao and up unchanged", {**R9_SITES, "q": (3, 1), "k": (3, 1), "v": (3, 1), "g": (3, 1), "z": (3, 1)}, None),
        "c3_int12": ("(c3) int12 words, two-byte windows: q, k, v, g, z two-byte (sh_a + 4 = 8..16); ao two-byte union (7..12); up one-byte (4..8)",
                     {**R9_SITES, "q": two(), "k": two(), "v": two(), "g": two(), "z": two(), "ao": two(2), "u": (1, 1)}, None),
        "c_fused": ("(c) a2 + the fused up instead of an up requant: u int24 (third limb) and the product remainder rh three limbs (sh_h window 16..=24) -- dominated by a3_1", A2, FUSED_UP),
    }
    out = {"schema": "zk60-native-r10-weight-range-cost/1", "anchor": "replica == HL_PB_TIMING sizes of the four R9-tree T128 runs (asserted)",
           "geometries": GEOMS, "options": {k: v[0] for k, v in OPTIONS.items()}, "results": {}, "per_site": {}, "nowrap_log2": {}}
    for geo, g in GEOMS.items():
        for dd in (False, True):
            base = Layout(g, dd=dd).totals()
            key = f"{geo} | R9 {'DD' if dd else 'non-DD'}"
            rows = {"R9": dict(committed=base["committed"], u8=base["u8"], element_terms=base["element_terms"], review_terms=base["review_terms"],
                               a_rows=base["a_rows"], h_rows=base["h_rows"])}
            mk = (geo, dd) if (geo, dd) in meas else (("Llama-3-8B T128", dd) if geo == "Llama-3-8B T512" else None)
            for ok, (desc, sites, extra) in OPTIONS.items():
                t = Layout(g, dd=dd, sites=sites, extra=extra).totals()
                r = dict(committed=t["committed"], u8=t["u8"], element_terms=t["element_terms"], review_terms=t["review_terms"],
                         d_committed_pct=pct(base["committed"], t["committed"]), d_u8_pct=pct(base["u8"], t["u8"]),
                         d_element_terms_pct=pct(base["element_terms"], t["element_terms"]), d_review_terms_pct=pct(base["review_terms"], t["review_terms"]),
                         d_a_planes=t["a_planes"] - base["a_planes"], d_h_planes=t["h_planes"] - base["h_planes"],
                         d_a_by_dom={k: t["a_by_dom"][k] - base["a_by_dom"][k] for k in t["a_by_dom"] if t["a_by_dom"][k] != base["a_by_dom"][k]},
                         d_lookups_per_position={k: t["lookups_per_position"][k] - base["lookups_per_position"][k] for k in t["lookups_per_position"] if t["lookups_per_position"][k] != base["lookups_per_position"][k]},
                         d_helpers={k: t["helpers"][k] - base["helpers"][k] for k in t["helpers"] if t["helpers"][k] != base["helpers"][k]},
                         d_receipt_bytes_per_block=receipt_delta(base, t))
                if geo in receipts:
                    off, on, nb = receipts[geo]
                    r["d_run_receipt_pct"] = round(100.0 * nb * r["d_receipt_bytes_per_block"] / (on if dd else off), 2)
                if mk is not None:
                    if geo == "Llama-3-8B T512":
                        tb, tn, ab, an = time_model(meas[mk], base, t, per_unit_from=True)
                        r["model_argument_time_pct"] = pct(ab, an)
                    else:
                        tb, tn, ab, an = time_model(meas[mk], base, t)
                        r["model_prove_time_pct"] = pct(tb, tn)
                        r["model_argument_time_pct"] = pct(ab, an)
                rows[ok] = r
            out["results"][key] = rows
        # per-site marginal cost (non-DD base) for 2 / 3 / 4 byte limbs, one pin
        base = Layout(g).totals()
        ps = {}
        for s in SITES:
            for L in ((1, 2, 3, 4) if s == "u" else (2, 3, 4)):
                t = Layout(g, sites={**R9_SITES, s: (L, 1)}).totals()
                ps[f"{s}:{L}"] = dict(d_committed=t["committed"] - base["committed"], d_u8=t["u8"] - base["u8"], d_element_terms=t["element_terms"] - base["element_terms"],
                                      d_committed_pct=pct(base["committed"], t["committed"]), d_u8_pct=pct(base["u8"], t["u8"]), d_element_terms_pct=pct(base["element_terms"], t["element_terms"]))
        out["per_site"][geo] = ps
    out["nowrap_log2"] = {"R9 (one byte, sh <= 8; up u16 = acc)": nowrap(8), "(a) two-byte sh <= 16, up one byte": nowrap(16, up_sh=8),
                          "(b) 12-bit m, s <= 24 (up s <= 24)": nowrap(24, 12, up_sh=24), "(b) 12-bit m, s <= 32": nowrap(32, 12, up_sh=32),
                          "(c) int12 words, sh <= 16, up one byte": nowrap(16, 0, 12, up_sh=8), "int16 words, sh <= 16 (reference)": nowrap(16, 0, 16, up_sh=16),
                          "p": round(math.log2(2 ** 64 - 2 ** 32 + 1), 4)}
    json.dump(out, open(os.path.join(HERE, "r10_weight_range_cost.json"), "w"), indent=1)
    # ---- print the headline table
    for key, rows in out["results"].items():
        b = rows["R9"]
        print(f"\n== {key}: committed {b['committed']:,}  U8 {b['u8']:,}  element-terms {b['element_terms']:,} (review conv. {b['review_terms']:,})")
        for ok in OPTIONS:
            r = rows[ok]
            extra = "".join(f"  {lab} {r[f]:+.2f}%" for f, lab in (("d_run_receipt_pct", "receipt"), ("model_prove_time_pct", "time[M]"), ("model_argument_time_pct", "arg-time[M]")) if f in r)
            print(f"  {ok:5s} committed {r['d_committed_pct']:+6.2f}%  U8 {r['d_u8_pct']:+6.2f}%  e-terms {r['d_element_terms_pct']:+6.2f}% (rev {r['d_review_terms_pct']:+6.2f}%)"
                  f"  A {r['d_a_by_dom']} lk {r['d_lookups_per_position']} help {r['d_helpers']}{extra}")
    print("\nno-wrap (log2 of the largest host term; p = 2^64 - 2^32 + 1):")
    for k, v in out["nowrap_log2"].items():
        print(" ", k, v)


if __name__ == "__main__":
    main()
