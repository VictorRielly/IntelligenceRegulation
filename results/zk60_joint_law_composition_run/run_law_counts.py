#!/usr/bin/env python3
"""Counts for ZK60_JOINT_LAW_COMPOSITION_RUN.md.

Exact integer arithmetic only.  Nothing here is run against the Rust; every
formula is transcribed from a named source line of the lane worktree
/home/victor/wt-zk60-block125m (branch zk60-private-block-125m, tip caa9b9a)
and every shape parameter from a named constructor.  Three published figures
are reproduced FIRST, as a check on the method:

  * the toy block's 173 published terminals and dim C = 560
    (ZK60_JOINT_LAW_COMPOSITION.md sections 1.3 and 2.2);
  * the toy block's 327,052 field draws and 2^-77.7 sampler residual
    (ZK60_PRIVACY_CASE_FIRST_MVP.md item 23, decision D9);
  * the 125M block's worst masked-sumcheck message length L = 117 at SC_SZC
    (ZK60_PRIVATE_BLOCK_125M_LAYOUT.md section 3.7a).

Sources, by line:
  shape.rs:58   BASE_DEGREE
  shape.rs:65   INDICATOR_SLOT_DOMAIN (8 slots gain one degree when their
                governing domain pads)
  shape.rs:603-641  Shape::slots()  -> (main, ext, degree) per slot
  shape.rs:662-669  Shape::slot_lengths()  L_s = (main+ext)*deg + 2
  shape.rs:672-695  Shape::totals()   a_rows = a_data + 2*a_sites + 2, etc.
  shape.rs:480-482  Shape::pads(dom)
  shape.rs:234/288/324  Shape::toy() / rung_g() / m125()
  layout.rs:815 SLOTS (the frozen toy slot table -- the cross-check)
  layout.rs:896 M_ROWS = 2*N_SLOTS + 4
  layout.rs:906-908  slot_terms  = A_SITES + H_SITES + (slot >= SC_IO_IN)
  boundary.rs:180-182  commitment_rows = data + 2*sites + 2
  endpoint_g.rs:51     the generalised endpoint's 5 appended rows
  zk.rs:373-375        MASK_LOG_MSG 9, MASK_LOG_DOM 12, MASK_Q 256
  pcs.rs:673           pads then salts, per row
"""

N_SLOTS = 23
(SC_SS, SC_SSM, SC_TZC, SC_LZC, SC_RS, SC_QMM, SC_KMM, SC_VMM, SC_SCORE,
 SC_PV, SC_WO, SC_GMM, SC_UMM, SC_DMM, SC_DZC, SC_QZC, SC_KVZC, SC_SZC,
 SC_FZC, SC_TAB, SC_ZS, SC_IO_IN, SC_IO_OUT) = range(23)

# shape.rs:58
BASE_DEGREE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]
# shape.rs:65-66
INDICATOR_SLOT_DOMAIN = {SC_SS: "D", SC_SSM: "D", SC_RS: "S", SC_DZC: "D",
                         SC_QZC: "Q", SC_KVZC: "Kv", SC_SZC: "S", SC_FZC: "F"}
# shape.rs:604-616 -- which cube a slot's main rounds run over
CUBE = {SC_SS: "D", SC_SSM: "D", SC_DZC: "D", SC_IO_IN: "D", SC_IO_OUT: "D",
        SC_TZC: "T", SC_LZC: "L", SC_RS: "S", SC_SZC: "S", SC_QZC: "Q",
        SC_KVZC: "Kv", SC_FZC: "F", SC_TAB: "Tab", SC_ZS: "Tab"}
# shape.rs:617-625 -- the matmul slots run over their INNER index
INNER = {SC_QMM: "d_pad", SC_KMM: "d_pad", SC_VMM: "d_pad", SC_WO: "d_pad",
         SC_GMM: "d_pad", SC_UMM: "d_pad", SC_SCORE: "head_dim",
         SC_PV: "t_pad", SC_DMM: "f_pad"}


def clog2(v):
    assert v > 0
    return (v - 1).bit_length() if v > 1 else 0


class Shape:
    def __init__(self, name, tokens, width, hidden, q_heads, head_dim, kv_heads,
                 log_cols, inv_rate, endpoint_rows, pad_rule, dom_log, a_sites,
                 h_sites, a_rows, h_rows, a_data, h_data, a_groups, h_groups):
        self.name = name
        self.tokens, self.width, self.hidden = tokens, width, hidden
        self.q_heads, self.head_dim, self.kv_heads = q_heads, head_dim, kv_heads
        self.log_cols, self.inv_rate = log_cols, inv_rate
        self.endpoint_rows = endpoint_rows
        self.pad_rule = pad_rule              # Shape::carries_pad_rule()
        self.dom_log = dom_log                # log2 of every padded domain
        self.dom_pads = {}                    # filled by the caller
        self.a_sites, self.h_sites = a_sites, h_sites
        self.a_rows, self.h_rows = a_rows, h_rows
        self.a_data, self.h_data = a_data, h_data
        self.a_groups, self.h_groups = a_groups, h_groups
        self.n = 1 << log_cols                # message positions per row
        self.q = 256                          # opened columns == pads per row

    def inner_log(self, key):
        return {"d_pad": clog2(_pow2(self.width)), "head_dim": clog2(self.head_dim),
                "t_pad": clog2(_pow2(self.tokens)), "f_pad": clog2(_pow2(self.hidden))}[key]

    def slots(self):
        out = []
        for s in range(N_SLOTS):
            if s in CUBE:
                main = self.dom_log[CUBE[s]]
            else:
                main = self.inner_log(INNER[s])
            ind = self.pad_rule and s in INDICATOR_SLOT_DOMAIN and \
                self.dom_pads[INDICATOR_SLOT_DOMAIN[s]]
            ext = 2 if s in (SC_SCORE, SC_PV) else 1
            out.append((main, ext, BASE_DEGREE[s] + (1 if ind else 0)))
        return out

    def slot_lengths(self):
        return [(m + e) * d + 2 for (m, e, d) in self.slots()]

    # ---- the objects the memo counts -------------------------------------
    def dim_C(self):
        """dim of the per-slot consistency subspace, summed: sum (N_s d_s + 1)."""
        return sum((m + e) * d + 1 for (m, e, d) in self.slots())

    def round_values(self):
        """published masked round values, in Fp2 words."""
        return sum((m + e) * (d + 1) for (m, e, d) in self.slots())

    def terminals(self):
        """layout.rs:906-908 summed over the 23 slots."""
        return self.a_sites + self.h_sites + 2


def _pow2(v):
    return 1 << clog2(v)


def make(name, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols,
         inv_rate, endpoint_rows, pad_rule, lift_lookup, a_sites, h_sites,
         a_rows, h_rows, a_data, h_data, a_groups, h_groups):
    t_pad, d_pad, f_pad = _pow2(tokens), _pow2(width), _pow2(hidden)
    h_pad = _pow2((q_heads + kv_heads - 1) // kv_heads) * kv_heads   # padded head slots
    size = {"T": t_pad, "Ht": h_pad * t_pad, "D": t_pad * d_pad,
            "Q": t_pad * h_pad * head_dim, "Kv": t_pad * kv_heads * head_dim,
            "S": h_pad * t_pad * t_pad, "F": t_pad * f_pad,
            "L": 16 * t_pad, "Tab": 256}
    true = {"T": tokens, "Ht": q_heads * tokens, "D": tokens * width,
            "Q": tokens * q_heads * head_dim, "Kv": tokens * kv_heads * head_dim,
            "S": q_heads * tokens * tokens, "F": tokens * hidden,
            "L": 9 * tokens, "Tab": 256}
    if lift_lookup:                       # ruling P-3: lift L and Tab to the row width
        size["L"] = max(size["L"], 1 << log_cols)
        size["Tab"] = max(size["Tab"], 1 << log_cols)
    sh = Shape(name, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols,
               inv_rate, endpoint_rows, pad_rule, {k: clog2(v) for k, v in size.items()},
               a_sites, h_sites, a_rows, h_rows, a_data, h_data, a_groups, h_groups)
    sh.dom_pads = {k: size[k] != true[k] for k in size}
    sh.size = size
    return sh


# shape.rs:234 -- the frozen toy.  carries_pad_rule() is false (finding S9-F1).
TOY = make("toy T32/d16/f16", 32, 16, 16, 2, 8, 1, 8, 8, 7, False, False,
           120, 51, 455, 384, 213, 280, 35, 9)
# shape.rs:288 -- rung-G, the generalised development rung.
RUNG_G = make("rung-G T24/d96/f192", 24, 96, 192, 6, 16, 2, 10, 4, 9, True, True,
              122, 52, 623, 576, 377, 470, 36, 9)
# shape.rs:324 -- the 125M block.  H carries 50 planes here, not 52: correction
# C-6 drops two Dom::D helpers because the top norm limb is exactly full
# (shape.rs:428-430), so h_sites = 50 and h_data_rows = 7,018.
M125 = make("125M T512/d768/f2048", 512, 768, 2048, 12, 64, 4, 14, 4, 37, True, True,
            122, 50, 5681, 7120, 5435, 7018, 36, 9)

# ------------------------------------------------------------------ checks
TOY_SLOTS_RUST = [(9, 1, 3), (9, 1, 3), (5, 1, 3), (9, 1, 4), (11, 1, 3),
                  (4, 1, 2), (4, 1, 2), (4, 1, 2), (3, 2, 2), (5, 2, 2),
                  (4, 1, 2), (4, 1, 2), (4, 1, 2), (4, 1, 2), (9, 1, 4),
                  (9, 1, 4), (8, 1, 4), (11, 1, 4), (9, 1, 4), (8, 1, 3),
                  (8, 1, 2), (9, 1, 2), (9, 1, 2)]


def draws_pcs(rows, data_rows, n, q, zero_sum_pair=False):
    """D9 field draws of one hiding PCS commitment.

    Every non-data row's n message entries plus every row's q pads
    (pcs.rs:673 draws pads then salts; salts are raw bytes and are D9-exempt).
    A zero-sum pair is inside `data_rows` and contributes 2(n-1) free entries
    (protocol.rs:364-372 at the toy: the last entry is the negated sum).
    """
    d = (rows - data_rows) * n + rows * q
    if zero_sum_pair:
        d += 2 * (n - 1)
    return d


def draws_mask(sum_L):
    """zk.rs:434-457 -- 2 rows per slot of L_s coefficients, 256 pads per a-row,
    four b/u rows of 2m = 1024 coefficients each."""
    return 2 * sum_L + 2 * N_SLOTS * 256 + 4 * 1024


def block_draws(sh):
    a = draws_pcs(sh.a_rows, sh.a_data, sh.n, sh.q)
    h = draws_pcs(sh.h_rows, sh.h_data, sh.n, sh.q, zero_sum_pair=True)
    m = draws_mask(sum(sh.slot_lengths()))
    return a, h, m


def endpoint_draws(sh):
    data = sh.endpoint_rows - 5                      # endpoint_g.rs:51
    return draws_pcs(sh.endpoint_rows, data, sh.n, sh.q)


def boundary_draws(sh, sites=2):
    data = sh.endpoint_rows - 5
    rows = data + 2 * sites + 2                      # boundary.rs:180-182
    return rows, draws_pcs(rows, data, sh.n, sh.q)


def log2(x):
    import math
    return math.log2(x)


def report():
    out = []
    w = out.append

    w("=" * 74)
    w("A. METHOD CHECKS (published figures reproduced first)")
    w("=" * 74)
    w("toy slot table equals layout.rs:815 SLOTS : %s" % (TOY.slots() == TOY_SLOTS_RUST))
    w("toy dim C = sum (N_s d_s + 1)             : %d   (memo: 560)" % TOY.dim_C())
    w("toy published round values (Fp2)          : %d   (memo: 721)" % TOY.round_values())
    w("toy published terminals                   : %d   (memo: 173)" % TOY.terminals())
    a, h, m = block_draws(TOY)
    e = endpoint_draws(TOY)
    tot = a + h + m + 2 * e
    w("toy field draws A/H/M/2xEnd               : %d / %d / %d / %d" % (a, h, m, 2 * e))
    w("toy field draws, total                    : %d   (privacy case: 327,052)" % tot)
    w("toy sampler residual  draws * 2^-96       : 2^%.1f   (D9: 2^-77.7)" % (log2(tot) - 96))
    w("125M worst slot length L_s                : %d at slot %d   (layout memo: 117 at SC_SZC=17)"
      % (max(M125.slot_lengths()), M125.slot_lengths().index(max(M125.slot_lengths()))))
    w("rung-G A data rows (83 planes)            : %d   (run gate: 377)" % RUNG_G.a_data)
    w("rung-G terminals per stage                : %d   (run gate: 176 = 176)" % RUNG_G.terminals())
    w("125M   terminals per stage                : %d   (H has 50 planes, not 52)" % M125.terminals())
    for sh, want in ((RUNG_G, 4234648), (M125, 40782792)):
        nq = sh.n + sh.q
        path = sh.log_cols + clog2(sh.inv_rate)
        def opening(g, rows):
            return (g + 1) * nq * 16 + sh.q * (8 + rows * 8 + 32 + path * 32)
        slot_line = 16 * (N_SLOTS + sh.round_values() + sh.terminals())
        mask_open = 2 * 1024 * 16 + 256 * (8 + 50 * 8 + 32 + 12 * 32)
        total = (136 + slot_line + mask_open + opening(sh.a_groups, sh.a_rows)
                 + opening(sh.h_groups, sh.h_rows) + 2 * opening(1, sh.endpoint_rows))
        w("%-22s receipt = %d   (grow_tests.rs: %d)  %s"
          % (sh.name, total, want, "OK" if total == want else "MISMATCH"))

    for sh in (RUNG_G, M125):
        w("")
        w("=" * 74)
        w("B. SHAPE %s" % sh.name)
        w("=" * 74)
        w("padded domains (Shape::pads)   : %s"
          % ", ".join("%s%s" % (k, "*" if v else "") for k, v in sorted(sh.dom_pads.items())))
        w("domain logs                    : %s"
          % ", ".join("%s %d" % (k, v) for k, v in sorted(sh.dom_log.items())))
        sl = sh.slots()
        w("slots (main, ext, degree)      : %s" % (sl,))
        w("slots that gained a degree     : %s"
          % [s for s in range(N_SLOTS)
             if s in INDICATOR_SLOT_DOMAIN and sh.dom_pads[INDICATOR_SLOT_DOMAIN[s]]])
        w("main / extension rounds        : %d / %d"
          % (sum(s[0] for s in sl), sum(s[1] for s in sl)))
        w("published round values (Fp2)   : %d" % sh.round_values())
        w("published scalars              : %d" % N_SLOTS)
        w("published terminals            : %d" % sh.terminals())
        w("dim C (Fp2)                    : %d" % sh.dim_C())
        w("sum L_s (mask coefficients)    : %d" % sum(sh.slot_lengths()))
        w("largest L_s (budget L+256<=512): %d" % max(sh.slot_lengths()))
        w("free mask coeffs sum L_s       : %d ; consumed dim C = %d ; ker = %d"
          % (sum(sh.slot_lengths()), sh.dim_C(), sum(sh.slot_lengths()) - sh.dim_C()))
        rows_b, db = boundary_draws(sh)
        w("boundary rows data+2*2+2       : %d" % rows_b)
        w("external endpoint rows data+5  : %d" % sh.endpoint_rows)
        a, h, m = block_draws(sh)
        w("field draws  A / H / M         : %d / %d / %d" % (a, h, m))
        w("field draws  block (A+H+M)     : %d" % (a + h + m))
        w("field draws  one boundary      : %d" % db)
        w("field draws  one ext endpoint  : %d" % endpoint_draws(sh))
        for L in (3, 12):
            run = L * (a + h + m) + (L - 1) * db + 2 * endpoint_draws(sh)
            w("RUN L=%-2d draws %14d   residual 2^%.1f" % (L, run, log2(run) - 96))

    w("")
    w("=" * 74)
    w("C. THE RUN'S PUBLISHED FIELD VALUES (Fp words; Fp2 counts twice)")
    w("=" * 74)
    for sh in (RUNG_G, M125):
        nq = sh.n + sh.q                       # a published PCS vector's length
        per_stage_fp2 = N_SLOTS + sh.round_values() + sh.terminals()
        a_open = (sh.a_groups + 1) * nq
        h_open = (sh.h_groups + 1) * nq
        m_open = 2 * 1024
        b_open = (2 + 1) * nq
        e_open = (1 + 1) * nq
        a_cols = sh.q * sh.a_rows
        h_cols = sh.q * sh.h_rows
        m_cols = 256 * (2 * N_SLOTS + 4)
        rows_b = boundary_draws(sh)[0]
        b_cols = sh.q * rows_b
        e_cols = sh.q * sh.endpoint_rows
        stage_fp = 2 * (per_stage_fp2 + a_open + h_open + m_open) + a_cols + h_cols + m_cols
        bnd_fp = 2 * b_open + b_cols
        ext_fp = 2 * e_open + e_cols
        for L in (3, 12):
            tot = L * stage_fp + (L - 1) * bnd_fp + 2 * ext_fp
            w("%-24s L=%-2d  Fp words published = %d" % (sh.name, L, tot))
        w("  per stage (Fp words) %d ; per boundary %d ; per external endpoint %d"
          % (stage_fp, bnd_fp, ext_fp))

    w("")
    w("=" * 74)
    w("D. REFUSALS -- liveness (challenge-only) and the one input-dependent class")
    w("=" * 74)
    w("The challenge-only rate is DOMINATED by the vanishing-proximity-determinant")
    w("refusal (protocol.rs:289-290), one per PCS opening, each about 1/p over the")
    w("BASE field.  Zero-Fp2-challenge classes (c_s, e in {0,1}, nu, zeta, a zero")
    w("group coefficient) are O(2^-128) each and are negligible beside it.")
    p = 2 ** 64 - 2 ** 32 + 1
    w("toy block: 4 openings (A, H, In, Out) -> 4/p = 2^%.2f   (ruling L-4: 2^-62.0)"
      % log2(4 / p))
    for L in (3, 12):
        # A and H per stage = 2L; IO openings = L+1 (external in, L-1 boundaries,
        # external out).  The masking commitment's opening has no determinant check.
        opens = 3 * L + 1
        w("run L=%-2d : %d openings -> %d/p = 2^%.2f" % (L, opens, opens, log2(opens / p)))
    w("")
    w("The one INPUT-DEPENDENT class is the zero LogUp denominator")
    w("(protocol.rs:403).  Its probability is (number of inverted denominators)")
    w("/ |Fp2| and therefore MOVES WITH THE SHAPE; 2^-112.0 is a TOY figure.")
    # denominator counts: grow_tests.rs:282-284 (toy), :299-302 (rung), :337-340 (125M)
    # plus three table-helper rows of size(Dom::Tab).
    dens = {"toy": 61440 + 2048 + 512 + 3 * 256,
            "rung-G": 419840 + 8192 + 8192 + 3 * (1 << RUNG_G.log_cols),
            "125M": 98598912 + 4194304 + 1048576 + 3 * (1 << M125.log_cols)}
    for k, v in dens.items():
        w("%-8s denominators %12d = 2^%.2f -> per block 2^%.2f" % (k, v, log2(v), log2(v) - 128))
        for L in (3, 12):
            w("            run L=%-2d  %d x that = 2^%.2f" % (L, L, log2(L * v) - 128))
    w("")
    w("=" * 74)
    w("E. RECEIPT FRAMING (code vs design memo)")
    w("=" * 74)
    w("wire.rs:263 RUN_HEADER = 8+32+8+8+32 = %d" % (8 + 32 + 8 + 8 + 32))
    w("wire.rs:265 RUN_TRAILER = %d" % 32)
    w("framing per segment, code = %d B ; design memo section 4.2 = 136 B" % (88 + 32))
    w("12 segments: code total 484,100,736 B ; memo 484,100,928 B ; difference %d = 12 x %d"
      % (484100928 - 484100736, 136 - 120))
    return "\n".join(out)


if __name__ == "__main__":
    print(report())
