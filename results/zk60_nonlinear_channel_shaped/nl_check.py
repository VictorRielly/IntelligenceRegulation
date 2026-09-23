#!/usr/bin/env python3
"""GS-13: the non-linear channel of the private block at the shaped layouts.

Machine check for docs/zkmatrix-poc/ZK60_NONLINEAR_CHANNEL_SHAPED.md (DRAFT,
unchecked). Re-runnable with no arguments:

    python3 results/zk60_nonlinear_channel_shaped/nl_check.py

Reads (read-only):
  * the lane's canonical slot-IR exports (stage 34, ruling I-8):
      /home/victor/wt-zk60-block125m/results/zk60_block125m_lane/x34-slot-ir/*.json
  * three Rust sources of the lane, parsed for constants only
      (layout.rs HOSTS / SLOT_KINDS, argument.rs extension-round arguments)

Writes nl_check.json and nl_check.log next to this file. No Rust is built or
run. Exact arithmetic over Goldilocks Fp2 (nl_field.py) throughout.

Stages (the memo's §2 numbering):
  S0  field self-test
  S1  per slot, per shape, from the IR: degree walk (independent of the
      export's own figure), per-variable degree bound, where the public
      factors (eq, group eq, public tables, support indicators) enter, the
      construction premise poly(exts_m) = 0 per extension round (exact
      random evaluation + a syntactic liveness walk), and its mechanism
  S2  budgets and structure: L_s + 256 <= 512, dim C_s, sum over slots,
      the 34 M functionals, the host table (triangularity), the
      extension-round assignment read from argument.rs
  S3  Fact 2.1 at every distinct (N, d) of every shape, at full size:
      rank R = N d + 1 = dim C, the explicit kernel, sum/eval weights in
      rowspace(R); closed-form round map vs brute force on small N
  S4  per slot, per shape, a MINIATURE honest masked run with the slot's
      real polynomial (the IR), real extension rounds and real declared
      degree: chain accepts, the verifier-derived mask value equals
      g(rho_full) (Fact 3.2), terminals = cd T + cm R, the unmasked
      offset lies in Im R (Lemma 2.2), and the FIBRE TEST of Theorem 3.3:
      a second world with a different witness and identical published
      (V_sc, terminals) gives the identical M value V
  S5  controls that must fire
"""

import glob
import hashlib
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import nl_field as F  # noqa: E402

LANE = "/home/victor/wt-zk60-block125m"
IR_DIR = LANE + "/results/zk60_block125m_lane/x34-slot-ir"
SRC = {
    "layout.rs": LANE + "/hashline/src/private_block/layout.rs",
    "argument.rs": LANE + "/hashline/src/private_block/argument.rs",
    "shape.rs": LANE + "/hashline/src/private_block/shape.rs",
    "zk.rs": LANE + "/hashline/src/zk.rs",
    "sumcheck.rs(zkp-core)": LANE + "/zkp-core/src/sumcheck.rs",
    "slot_ir.rs": LANE + "/hashline/src/private_block/slot_ir.rs",
}
SHAPES_OF_RECORD = ["m125", "rung_g", "rung_k4"]
MASK_MSG = 512  # zk.rs:373 MASK_LOG_MSG = 9
MASK_Q = 256  # zk.rs:375

LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(s)
    print(s, flush=True)


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def sd(*parts):
    """a deterministic seed (Python's hash() of a str is randomised per run)"""
    return int.from_bytes(hashlib.sha256(repr(parts).encode()).digest()[:8], "little")


# =========================================================================
# the IR
# =========================================================================

PUBLIC_KINDS = ("eq", "group_eq", "pub", "supp")
PRIVATE_KINDS = ("A", "H", "EP")


def tkind(t):
    k = t["kind"]
    if k.startswith("eq("):
        return "eq"
    if k.startswith("group_eq("):
        return "group_eq"
    if k.startswith("supp("):
        return "supp"
    return k  # pub, A, H, EP


def var_range(t, n):
    """the cube variables a table depends on. Eq / group eq from their kind;
    every other table conservatively depends on all n variables."""
    k = t["kind"]
    m = re.match(r"eq\(start=(\d+),\|point\|=(\d+)\)", k)
    if m:
        s, ln = int(m.group(1)), int(m.group(2))
        return set(range(s, s + ln))
    m = re.match(r"group_eq\(bits=(\d+)\)", k)
    if m:
        return set(range(int(m.group(1))))
    return set(range(n))


class Slot:
    def __init__(self, js, shape, ext_assign):
        self.js = js
        self.shape = shape
        self.slot = js["slot"]
        self.name = js["name"]
        self.kind = js["kind"]
        self.main = js["main_rounds"]
        self.ext = js["extension_rounds"]
        self.d = js["declared_degree"]
        self.maxdeg_export = js["max_product_degree"]
        self.pad_on = js["pad_on"]
        self.group_bits = js["group_bits"]
        self.tables = js["tables"]
        self.nodes = js["nodes"]
        self.terms = js["terms"]
        self.kinds = [tkind(t) for t in self.tables]
        self.private = [i for i, k in enumerate(self.kinds) if k in PRIVATE_KINDS]
        self.public = [i for i, k in enumerate(self.kinds) if k in PUBLIC_KINDS]
        unknown = [k for k in self.kinds if k not in PRIVATE_KINDS + PUBLIC_KINDS]
        assert not unknown, f"unknown table kind {unknown}"
        # extension round of each private table: argument.rs pushes every
        # private table with ext_round 0 except the SECOND private factor of
        # the two bilinear slots (S2 reads this from the source)
        self.ext_round = {i: 0 for i in self.private}
        if self.ext == 2:
            order = ext_assign[self.slot]
            assert len(order) == len(self.private), (self.slot, order, self.private)
            for i, r in zip(self.private, order):
                self.ext_round[i] = r
        assert all(r < self.ext for r in self.ext_round.values())

    # ---------------------------------------------------------- evaluation

    def compile(self, rng, zeta=None):
        """fix a value for every coefficient. Public constants: the export's
        value. Challenge coefficients (their values never leave the Rust
        process): zeta^j consistent in one random zeta; mu[k] / nu[k] per
        label; every other challenge coefficient independently per
        occurrence (so no identity can hold by an accidental relation)."""
        z = zeta if zeta is not None else rng.fp2_nonzero_not_one()
        cache = {}

        def val(c):
            if "value" in c:
                return F.parse(c["value"])
            p = c["prov"]
            m = re.match(r"chal:zeta\^(\d+)$", p)
            if m:
                return F.pw(z, int(m.group(1)))
            if p.startswith("chal:mu[") or p.startswith("chal:nu["):
                if p not in cache:
                    cache[p] = rng.fp2()
                return cache[p]
            return rng.fp2()

        cn = []
        for n in self.nodes:
            if n["body"] == "affine":
                cn.append(("a", val(n["konst"]), [(val(t["coef"]), t["table"]) for t in n["terms"]]))
            else:
                sts = []
                for st in n["subterms"]:
                    sts.append((val(st["coef"]), [("t", fc["table"]) if "table" in fc else ("n", fc["node"]) for fc in st["factors"]]))
                cn.append(("s", sts))
        ct = []
        for t in self.terms:
            ct.append((val(t["coef"]), list(t["wrapper"]), [("t", fc["table"]) if "table" in fc else ("n", fc["node"]) for fc in t["inner"]]))
        return (cn, ct)

    @staticmethod
    def evaluate(comp, v):
        cn, ct = comp
        nv = []
        for nd in cn:
            if nd[0] == "a":
                acc = nd[1]
                for c, t in nd[2]:
                    acc = F.add(acc, F.mul(c, v[t]))
            else:
                acc = F.ZERO
                for c, fs in nd[1]:
                    p = c
                    for kind, i in fs:
                        p = F.mul(p, v[i] if kind == "t" else nv[i])
                    acc = F.add(acc, p)
            nv.append(acc)
        out = F.ZERO
        for c, wr, inner in ct:
            p = c
            for w in wr:
                p = F.mul(p, v[w])
            for kind, i in inner:
                p = F.mul(p, v[i] if kind == "t" else nv[i])
            out = F.add(out, p)
        return out

    # ---------------------------------------------------------- structure

    def degrees(self):
        """node degrees and the max product degree, walked from the bodies
        (independent of the export's stored figures)"""
        nd = []
        for n in self.nodes:
            if n["body"] == "affine":
                nd.append(1 if n["terms"] else 0)
            else:
                nd.append(max((sum(1 if "table" in fc else nd[fc["node"]] for fc in st["factors"]) for st in n["subterms"]), default=0))
        tdeg = []
        for t in self.terms:
            tdeg.append(len(t["wrapper"]) + sum(1 if "table" in fc else nd[fc["node"]] for fc in t["inner"]))
        stored_nodes_ok = all(nd[i] == self.nodes[i]["degree"] for i in range(len(nd)))
        stored_terms_ok = all(tdeg[i] == self.terms[i]["degree"] for i in range(len(tdeg)))
        return nd, tdeg, max(tdeg) if tdeg else 0, stored_nodes_ok and stored_terms_ok

    def per_variable_degree(self):
        """an upper bound on the degree of the slot polynomial in each cube
        variable: a table contributes 1 in the variables it depends on
        (eq / group eq: their ranges; everything else: all)"""
        n = self.main
        deps = [var_range(t, n) for t in self.tables]
        nvd = []
        for nd in self.nodes:
            vec = [0] * n
            if nd["body"] == "affine":
                for t in nd["terms"]:
                    for j in deps[t["table"]]:
                        vec[j] = 1
            else:
                for st in nd["subterms"]:
                    sv = [0] * n
                    for fc in st["factors"]:
                        if "table" in fc:
                            for j in deps[fc["table"]]:
                                sv[j] += 1
                        else:
                            sv = [a + b for a, b in zip(sv, nvd[fc["node"]])]
                    vec = [max(a, b) for a, b in zip(vec, sv)]
            nvd.append(vec)
        best = [0] * n
        for t in self.terms:
            tv = [0] * n
            for w in t["wrapper"]:
                for j in deps[w]:
                    tv[j] += 1
            for fc in t["inner"]:
                if "table" in fc:
                    for j in deps[fc["table"]]:
                        tv[j] += 1
                else:
                    tv = [a + b for a, b in zip(tv, nvd[fc["node"]])]
            best = [max(a, b) for a, b in zip(best, tv)]
        return best

    def live(self, live_table):
        """syntactic walk: can the polynomial be non-zero when exactly the
        tables with live_table[i] True may be non-zero? (ignores
        cancellation between monomials, so 'not live' is a proof of zero
        and 'live' is only a possibility — the exact evaluation decides)"""

        def coef_live(c):
            return not ("value" in c and F.is_zero(F.parse(c["value"])))

        nl = []
        for n in self.nodes:
            if n["body"] == "affine":
                v = coef_live(n["konst"]) or any(coef_live(t["coef"]) and live_table[t["table"]] for t in n["terms"])
            else:
                v = any(coef_live(st["coef"]) and all((live_table[fc["table"]] if "table" in fc else nl[fc["node"]]) for fc in st["factors"]) for st in n["subterms"])
            nl.append(v)
        per_term = []
        for t in self.terms:
            v = coef_live(t["coef"]) and all(live_table[w] for w in t["wrapper"]) and all((live_table[fc["table"]] if "table" in fc else nl[fc["node"]]) for fc in t["inner"])
            per_term.append(v)
        return any(per_term), per_term

    def public_entry_points(self):
        """where each public table enters: as a term wrapper, as a plain
        factor of a product, or inside an affine node (with that node's
        constant, e.g. the pad rule's 1 - supp)"""
        out = {}
        for i in self.public:
            out[i] = {"kind": self.kinds[i], "label": self.tables[i]["label"], "wrapper": 0, "factor": 0, "affine": []}
        for t in self.terms:
            for w in t["wrapper"]:
                if w in out:
                    out[w]["wrapper"] += 1
            for fc in t["inner"]:
                if "table" in fc and fc["table"] in out:
                    out[fc["table"]]["factor"] += 1
        for n in self.nodes:
            if n["body"] == "affine":
                for t in n["terms"]:
                    if t["table"] in out:
                        out[t["table"]]["affine"].append(n["label"])
            else:
                for st in n["subterms"]:
                    for fc in st["factors"]:
                        if "table" in fc and fc["table"] in out:
                            out[fc["table"]]["factor"] += 1
        return out


def load_shapes():
    shapes = {}
    for p in sorted(glob.glob(IR_DIR + "/slot_ir_*.json")):
        js = json.load(open(p))
        assert js["schema"] == "zk60-slot-ir/1", p
        assert js["slot_count"] == 23 and len(js["slots"]) == 23, p
        shapes[js["shape"]] = (p, js)
    return shapes


# =========================================================================
# sources: the constants S2 needs
# =========================================================================


def parse_sources():
    lay = open(SRC["layout.rs"]).read()
    arg = open(SRC["argument.rs"]).read()
    sc = {m.group(1): int(m.group(2)) for m in re.finditer(r"pub\(crate\) const (SC_\w+): usize = (\d+);", lay)}
    kinds_blk = lay[lay.index("pub(crate) const SLOT_KINDS") :]
    kinds_blk = kinds_blk[: kinds_blk.index("];")]
    kinds = re.findall(r"SlotKind::(\w+)", kinds_blk)
    hosts_blk = lay[lay.index("pub(crate) const HOSTS") :]
    hosts_blk = hosts_blk[: hosts_blk.index("];")]
    hosts = []
    for m in re.finditer(r"\((SC_\w+), &\[([^\]]*)\]\)", hosts_blk):
        hosts.append((sc[m.group(1)], [sc[x.strip()] for x in m.group(2).split(",") if x.strip()]))
    # the extension-round argument of every private push inside `define`
    lines = arg.split("\n")
    d0 = next(i for i, l in enumerate(lines) if l.startswith("pub(crate) fn define("))
    pushes = []
    arm = None
    for i in range(d0, len(lines)):
        l = lines[i]
        m = re.match(r"\s*(SC_[A-Z_0-9 |]+) =>", l)
        if m:
            arm = m.group(1).strip()
        m = re.search(r"b\.a_(at|slice)\((.*)\)\?", l)
        if m:
            last = m.group(2).rsplit(",", 1)[1].strip()
            pushes.append({"line": i + 1, "arm": arm, "ext_round": last})
    helpers = {}
    for i, l in enumerate(lines):
        if "self.a_at(plane, rho(0..log), 0)" in l:
            helpers["a_range -> a_at(.., 0)"] = i + 1
        if "Cm::H, slices: vec![(re, Fp2::ONE), (im, Fp2::U)]" in l and "ext_round: 0" in l:
            helpers["h(): ext_round 0"] = i + 1
        if "Tab::Priv(Priv { cm, slices: vec![(0, Fp2::ONE)]" in l and "ext_round: 0" in l:
            helpers["endpoint(): ext_round 0"] = i + 1
    nonzero = [p for p in pushes if p["ext_round"] != "0"]
    ext_assign = {}
    for s_name in ("SC_SCORE", "SC_PV"):
        order = [int(p["ext_round"]) for p in pushes if p["arm"] == s_name]
        ext_assign[sc[s_name]] = order
    return {
        "sc": sc,
        "kinds": kinds,
        "hosts": hosts,
        "pushes": pushes,
        "nonzero_ext_pushes": nonzero,
        "helpers": helpers,
        "ext_assign": ext_assign,
    }


# =========================================================================
# the CFS mask (port of zkp-core/src/sumcheck.rs:189-274)
# =========================================================================


def mask_len(N, d):
    return N * d + 2


def u_eval(coeffs, d, j, x):
    acc = F.ZERO
    xp = F.ONE
    for e in range(1, d + 1):
        xp = F.mul(xp, x)
        acc = F.add(acc, F.mul(coeffs[2 + j * d + (e - 1)], xp))
    return acc


HALF = F.inv(F.f(2))


def mask_round(coeffs, N, d, j, prev):
    """CfsMask::round — the round-j message of g at X = 0..d (closed form)"""
    assert len(prev) == j
    base = coeffs[0]
    for i, r in enumerate(prev):
        base = F.add(base, u_eval(coeffs, d, i, r))
    for i in range(j + 1, N):
        base = F.add(base, F.mul(u_eval(coeffs, d, i, F.ONE), HALF))
    scale = F.f(1 << (N - 1 - j))
    pp = F.ONE
    for r in prev:
        pp = F.mul(pp, r)
    out = []
    for x in range(d + 1):
        xv = F.f(x)
        out.append(F.add(F.mul(scale, F.add(base, u_eval(coeffs, d, j, xv))), F.mul(F.mul(coeffs[1], pp), xv)))
    return out


def sum_weights(N, d):
    w = [F.f(1 << (N - 1))] * mask_len(N, d)
    w[0] = F.f(1 << N)
    w[1] = F.ONE
    return w


def eval_weights(rho, d):
    w = [F.ONE]
    p = F.ONE
    for r in rho:
        p = F.mul(p, r)
    w.append(p)
    for r in rho:
        xp = F.ONE
        for _ in range(d):
            xp = F.mul(xp, r)
            w.append(xp)
    return w


def dot(a, b):
    acc = F.ZERO
    for x, y in zip(a, b):
        acc = F.add(acc, F.mul(x, y))
    return acc


def g_eval_brute(coeffs, N, d, x):
    """g(x) = a0 + a' prod x + sum_j u_j(x_j)"""
    v = coeffs[0]
    p = F.ONE
    for xi in x:
        p = F.mul(p, xi)
    v = F.add(v, F.mul(coeffs[1], p))
    for j, xi in enumerate(x):
        v = F.add(v, u_eval(coeffs, d, j, xi))
    return v


def round_matrix_rows(N, d, rho, mask_degree=None):
    """the matrix of a -> (G, rounds) as ROWS indexed by mask coefficient:
    row i = the image of the i-th unit vector. Filled from the closed form
    (linear in the coefficients). mask_degree lets a control use a mask of
    lower degree than the published d + 1 values."""
    md = d if mask_degree is None else mask_degree
    L = mask_len(N, md)
    rows = []
    for i in range(L):
        e = [F.ZERO] * L
        e[i] = F.ONE
        vec = [dot(sum_weights(N, md), e)]
        for j in range(N):
            r = mask_round(e, N, md, j, rho[:j])
            # published values at X = 0..d (the mask round has md + 1; a
            # lower-degree mask is evaluated at d + 1 nodes)
            if md == d:
                vec.extend(r)
            else:
                vec.extend(_eval_at_nodes_from(e, N, md, j, rho[:j], d))
        rows.append(vec)
    return rows


def _eval_at_nodes_from(coeffs, N, md, j, prev, d):
    base = coeffs[0]
    for i, r in enumerate(prev):
        base = F.add(base, u_eval(coeffs, md, i, r))
    for i in range(j + 1, N):
        base = F.add(base, F.mul(u_eval(coeffs, md, i, F.ONE), HALF))
    scale = F.f(1 << (N - 1 - j))
    pp = F.ONE
    for r in prev:
        pp = F.mul(pp, r)
    return [F.add(F.mul(scale, F.add(base, u_eval(coeffs, md, j, F.f(x)))), F.mul(F.mul(coeffs[1], pp), F.f(x))) for x in range(d + 1)]


def lagrange_row(d, r):
    """the coefficients l_i with interpolate_eval(s, r) = sum_i l_i s_i,
    nodes 0..d"""
    out = []
    for i in range(d + 1):
        num = F.ONE
        den = 1
        for k in range(d + 1):
            if k != i:
                num = F.mul(num, F.sub(r, F.f(k)))
                den *= i - k
        out.append(F.mul(num, F.inv(F.f(den))))
    return out


def interp(s, r):
    return dot(lagrange_row(len(s) - 1, r), s)


def consistency_rank(N, d, rho):
    """rank of the verifier's chain equations on (A, r_0..r_{N-1})"""
    width = 1 + N * (d + 1)
    rows = []
    row = [F.ZERO] * width
    row[0] = F.neg(F.ONE)
    row[1] = F.ONE
    row[2] = F.ONE
    rows.append(row)
    for j in range(1, N):
        row = [F.ZERO] * width
        o = 1 + j * (d + 1)
        row[o] = F.ONE
        row[o + 1] = F.ONE
        lr = lagrange_row(d, rho[j - 1])
        po = 1 + (j - 1) * (d + 1)
        for i in range(d + 1):
            row[po + i] = F.neg(lr[i])
        rows.append(row)
    return F.rank(rows, width)


def explicit_kernel(N, d, rho):
    L = mask_len(N, d)
    k = [F.ZERO] * L
    k[1] = F.ONE
    pp = F.ONE
    a1 = []
    for j in range(N):
        # a_{j,1} = -2^{j+1-N} prod_{i<j} rho_i
        val = F.neg(F.mul(pp, F.inv(F.f(1 << (N - 1 - j)))))
        k[2 + j * d] = val
        a1.append(val)
        pp = F.mul(pp, rho[j])
    s = F.ZERO
    for v in a1[1:]:
        s = F.add(s, v)
    k[0] = F.neg(F.mul(HALF, s))
    return k


# =========================================================================
# S4: the miniature honest masked run
# =========================================================================


def fold(tab, r):
    h = len(tab) // 2
    return [F.add(tab[i], F.mul(r, F.sub(tab[i + h], tab[i]))) for i in range(h)]


def honest_transcript(sl, comp, tables, exts_by_round, rho, es, d):
    """the UNMASKED honest transcript T'(w, pi): (sigma, rounds...), plus
    the per-table values after the main rounds and the final terminals"""
    n = len(rho)
    cur = [list(t) for t in tables]
    size = len(cur[0])
    sigma = F.ZERO
    for x in range(size):
        sigma = F.add(sigma, Slot.evaluate(comp, [t[x] for t in cur]))
    rounds = []
    for j in range(n):
        h = len(cur[0]) // 2
        s = []
        for X in range(d + 1):
            xv = F.f(X)
            acc = F.ZERO
            for i in range(h):
                v = [F.add(t[i], F.mul(xv, F.sub(t[i + h], t[i]))) for t in cur]
                acc = F.add(acc, Slot.evaluate(comp, v))
            s.append(acc)
        rounds.append(s)
        cur = [fold(t, rho[j]) for t in cur]
    at_rho = [t[0] for t in cur]
    vals = list(at_rho)
    for m, e in enumerate(es):
        ex = exts_by_round[m]
        s = []
        for X in range(d + 1):
            xv = F.f(X)
            v = [F.add(vals[i], F.mul(xv, F.sub(ex[i], vals[i]))) for i in range(len(vals))]
            s.append(Slot.evaluate(comp, v))
        rounds.append(s)
        vals = [F.add(vals[i], F.mul(e, F.sub(ex[i], vals[i]))) for i in range(len(vals))]
    return sigma, rounds, at_rho, vals


def flat(sigma, rounds):
    out = [sigma]
    for r in rounds:
        out.extend(r)
    return out


def masked(sigma, rounds, coeffs, c, N, d, chal):
    G = dot(sum_weights(N, d), coeffs)
    A = F.add(sigma, F.mul(c, G))
    rr = []
    for j, r in enumerate(rounds):
        g = mask_round(coeffs, N, d, j, chal[:j])
        rr.append([F.add(r[x], F.mul(c, g[x])) for x in range(d + 1)])
    return A, rr


def verify_chain(A, rounds, chal, d):
    claim = A
    for j, s in enumerate(rounds):
        if len(s) != d + 1:
            return False, None
        if F.add(s[0], s[1]) != claim:
            return False, j
        claim = interp(s, chal[j])
    return True, claim


def miniature(sl, rng, n_mini=3, override=None):
    """one slot, one miniature cube. override: dict with optional keys
    'ext_round' (table -> round), 'd' (declared degree), 'drop_wrapper'
    (a function IR-json -> IR-json) — used only by the controls."""
    d = override.get("d", sl.d) if override else sl.d
    n = min(n_mini, sl.main)
    ext = sl.ext
    N = n + ext
    ext_round = dict(sl.ext_round)
    if override and "ext_round" in override:
        ext_round.update(override["ext_round"])
    comp = sl.compile(rng)
    ntab = len(sl.tables)
    size = 1 << n
    rho = [rng.fp2() for _ in range(n)]
    es = [rng.fp2_nonzero_not_one() for _ in range(ext)]
    chal = rho + es
    c = rng.fp2()
    while F.is_zero(c):
        c = rng.fp2()
    L = mask_len(N, d)

    def world(tables, R):
        exts = []
        for m in range(ext):
            exts.append([R[i] if (i in sl.private and ext_round[i] == m) else F.ZERO for i in range(ntab)])
        return honest_transcript(sl, comp, tables, exts, rho, es, d)

    tables1 = [[rng.fp2() for _ in range(size)] for _ in range(ntab)]
    R1 = {i: rng.fp2() for i in sl.private}
    sigma1, rounds1, at1, fin_vals1 = world(tables1, R1)
    a1 = [rng.fp2() for _ in range(L)]
    A1, mr1 = masked(sigma1, rounds1, a1, c, N, d, chal)
    ok_chain, fin = verify_chain(A1, mr1, chal, d)
    res = {"n_mini": n, "N": N, "d": d, "L": L, "chain_accepts": bool(ok_chain)}
    if not ok_chain:
        res["chain_fails_at_round"] = fin
    # the verifier's vals: public tables sel * T(rho), private the terminals
    sel = F.ONE
    for e in es:
        sel = F.mul(sel, F.sub(F.ONE, e))
    terms1 = {i: fin_vals1[i] for i in sl.private}
    vals = [terms1[i] if i in sl.private else F.mul(sel, at1[i]) for i in range(ntab)]
    g_true = dot(eval_weights(chal, d), a1)
    if ok_chain:
        g_derived = F.mul(F.sub(fin, Slot.evaluate(comp, vals)), F.inv(c))
        res["fact32_identity"] = g_derived == g_true
    else:
        res["fact32_identity"] = False
    # terminals = cd T(rho) + cm R
    cd = sel
    ok_terms = True
    for i in sl.private:
        r = ext_round[i]
        cm = es[r]
        for e in es[r + 1 :]:
            cm = F.mul(cm, F.sub(F.ONE, e))
        if terms1[i] != F.add(F.mul(cd, at1[i]), F.mul(cm, R1[i])):
            ok_terms = False
    res["terminal_formula"] = ok_terms
    # Lemma 2.2: rank R = N d + 1 and the unmasked offset lies in Im R
    rows = round_matrix_rows(N, d, chal)
    rows_c = [[F.mul(c, v) for v in r] for r in rows]
    width = 1 + N * (d + 1)
    rk = F.rank(rows_c, width)
    off1 = flat(sigma1, rounds1)
    rk_aug = F.rank(rows_c + [off1], width)
    res["rank_R"] = rk
    res["dimC_expected"] = N * d + 1
    res["offset_in_ImR"] = rk_aug == rk
    # THE FIBRE TEST (Theorem 3.3 at this miniature): a second world with an
    # independent witness, whose reserved-pair values are chosen so that its
    # terminals equal world 1's (the terminal surjection, cm != 0), and whose
    # mask is chosen so that its sumcheck channel equals world 1's (Lemma
    # 2.2). The M value V = <eval_weights, a> must then be the same.
    if res["offset_in_ImR"]:
        # the public tables are the SAME in both worlds (they are the public
        # statement and the challenges); only the private planes differ
        tables2 = [[rng.fp2() for _ in range(size)] if i in sl.private else list(tables1[i]) for i in range(ntab)]
        # T2(rho) first, to choose R2
        _, _, at2, _ = world(tables2, {i: F.ZERO for i in sl.private})
        R2 = {}
        for i in sl.private:
            r = ext_round[i]
            cm = es[r]
            for e in es[r + 1 :]:
                cm = F.mul(cm, F.sub(F.ONE, e))
            R2[i] = F.mul(F.sub(terms1[i], F.mul(cd, at2[i])), F.inv(cm))
        sigma2, rounds2, at2b, fin_vals2 = world(tables2, R2)
        off2 = flat(sigma2, rounds2)
        diff = [F.sub(x, y) for x, y in zip(off1, off2)]
        delta = F.solve(rows_c, diff)
        if delta is None:
            res["fibre_constructed"] = False
        else:
            a2 = [F.add(x, y) for x, y in zip(a1, delta)]
            A2, mr2 = masked(sigma2, rounds2, a2, c, N, d, chal)
            same_view = A2 == A1 and mr2 == mr1 and all(fin_vals2[i] == terms1[i] for i in sl.private)
            g2 = dot(eval_weights(chal, d), a2)
            G1 = F.mul(c, dot(sum_weights(N, d), a1))
            G2 = F.mul(c, dot(sum_weights(N, d), a2))
            res["fibre_constructed"] = True
            res["fibre_same_published_view"] = same_view
            res["fibre_witness_differs"] = sigma1 != sigma2 or at1 != at2b
            res["fibre_same_V"] = g2 == g_true
            # control inside the test: had this slot's OWN mask total been a
            # functional of M (a Private slot's Gamma), its value would move
            # between the two worlds by sigma1 - sigma2
            res["fibre_private_gamma_would_differ"] = G1 != G2
            res["fibre_private_gamma_shift_is_sigma_diff"] = F.sub(G2, G1) == F.sub(sigma1, sigma2)
    return res


def terminal_pair_rank(n_priv, tail_len, rng, weights="cmU", share=None, tail_kind="fp2", same_tail=False):
    """Fp-rank of the map (R_re, R_im per terminal) -> terminals in Fp^{2m}.
    Each terminal: cm (<eq(tail), R_re> + U <eq(tail), R_im>) (the
    (cm, cm U) pair shape of build_claim). weights='cm1' is the control
    (cm, cm); share=(i, j) makes terminal j reuse terminal i's pair.
    tail_kind='boolean' draws the tail from {0, 1} — admissible, because
    main-round challenges 0 and 1 are NOT refused (only the extension
    challenges are, argument.rs:586-588) — so eq(tail) is a unit vector of
    the BASE field; same_tail gives every terminal one tail (two sites of
    one plane at one point, as in slots 15 / 16's rotary pair)."""
    cols = 1 << tail_len
    m = n_priv
    pair_of = list(range(m))
    if share:
        pair_of[share[1]] = share[0]
    npairs = max(pair_of) + 1
    # unknowns: for each pair p, R_re (cols) then R_im (cols) — base field
    nunk = npairs * 2 * cols
    rows = [[0] * nunk for _ in range(2 * m)]
    shared_tail = None
    for k in range(m):
        if same_tail and shared_tail is not None:
            tail = shared_tail
        elif tail_kind == "boolean":
            tail = [F.f(rng.r.randrange(2)) for _ in range(tail_len)]
        else:
            tail = [rng.fp2() for _ in range(tail_len)]
        shared_tail = tail
        eq = [F.ONE]
        for t in tail:
            eq = [x for e in eq for x in (F.mul(e, F.sub(F.ONE, t)), F.mul(e, t))]
        cm = rng.fp2_nonzero_not_one()
        w_im = F.mul(cm, F.U) if weights == "cmU" else cm
        p = pair_of[k]
        for j in range(cols):
            a = F.mul(cm, eq[j])
            b = F.mul(w_im, eq[j])
            rows[2 * k][p * 2 * cols + j] = a[0]
            rows[2 * k + 1][p * 2 * cols + j] = a[1]
            rows[2 * k][p * 2 * cols + cols + j] = b[0]
            rows[2 * k + 1][p * 2 * cols + cols + j] = b[1]
    return F.rank_fp(rows, nunk)


# =========================================================================
# main
# =========================================================================


def main():
    t0 = time.time()
    out = {"schema": "zk60-nonlinear-channel-shaped/1", "inputs": {}, "stages": {}}
    for name, p in SRC.items():
        out["inputs"][name] = {"path": p, "sha256": sha(p)}
    shapes = load_shapes()
    for k, (p, _) in shapes.items():
        out["inputs"]["ir:" + k] = {"path": p, "sha256": sha(p)}
    log("GS-13 non-linear channel check;", len(shapes), "IR exports:", ", ".join(sorted(shapes)))

    # ------------------------------------------------------------------ S0
    out["stages"]["S0_field"] = F.self_test()
    log("S0 field self-test:", out["stages"]["S0_field"])

    # ------------------------------------------------------------------ S2 sources first (S1 needs the extension-round assignment)
    src = parse_sources()
    s2src = {
        "slot_kinds": src["kinds"],
        "hosts": src["hosts"],
        "ext_round_pushes_total": len(src["pushes"]),
        "ext_round_nonzero_pushes": src["nonzero_ext_pushes"],
        "helpers_with_ext_round_0": src["helpers"],
        "bilinear_ext_assignment": {str(k): v for k, v in src["ext_assign"].items()},
    }
    kinds = src["kinds"]
    assert len(kinds) == 23
    host_ok = True
    hosted_count = {}
    for h, lst in src["hosts"]:
        if kinds[h] != "Host":
            host_ok = False
        for s in lst:
            hosted_count[s] = hosted_count.get(s, 0) + 1
            if not (s < h and kinds[s] == "Private"):
                host_ok = False
    every_private_once = all(hosted_count.get(s, 0) == (1 if kinds[s] == "Private" else 0) for s in range(23))
    n_std = kinds.count("Standalone")
    n_host = kinds.count("Host")
    n_priv = kinds.count("Private")
    s2src["hosted_before_host_and_private"] = host_ok
    s2src["every_private_hosted_exactly_once"] = every_private_once
    s2src["kind_counts"] = {"Private": n_priv, "Standalone": n_std, "Host": n_host}
    s2src["m_functionals"] = 23 + n_std + n_host
    s2src["nonzero_ext_pushes_only_in_bilinear_arms"] = all(p["arm"] in ("SC_SCORE", "SC_PV") and p["ext_round"] == "1" for p in src["nonzero_ext_pushes"]) and len(src["nonzero_ext_pushes"]) == 2
    out["stages"]["S2_sources"] = s2src
    log("S2 sources: kinds", s2src["kind_counts"], "functionals", s2src["m_functionals"], "hosts triangular", host_ok, "every private hosted once", every_private_once)
    log("S2 sources: non-zero extension-round pushes", [(p["line"], p["arm"], p["ext_round"]) for p in src["nonzero_ext_pushes"]], "; bilinear order", src["ext_assign"])

    # ------------------------------------------------------------------ S1 + S2 per shape
    s1 = {}
    s2 = {}
    all_slots = {}
    for shape in sorted(shapes):
        _, js = shapes[shape]
        rows = []
        tot_L = tot_C = 0
        worst = (0, None)
        for sj in js["slots"]:
            sl = Slot(sj, shape, src["ext_assign"])
            all_slots[(shape, sl.slot)] = sl
            assert sl.kind == kinds[sl.slot], (shape, sl.slot, sl.kind)
            nd, tdeg, maxdeg, stored_ok = sl.degrees()
            pvd = sl.per_variable_degree()
            # the premise, per extension round: exact evaluation at three
            # seeds, private tables of that round random, everything else 0
            prem = []
            for m in range(sl.ext):
                zeros = []
                for seed in (1, 2, 3):
                    rng = F.Rng(sd(shape, sl.slot, m, seed))
                    comp = sl.compile(rng)
                    v = [rng.fp2() if (i in sl.private and sl.ext_round[i] == m) else F.ZERO for i in range(len(sl.tables))]
                    zeros.append(F.is_zero(Slot.evaluate(comp, v)))
                live_m, _ = sl.live([i in sl.private and sl.ext_round[i] == m for i in range(len(sl.tables))])
                prem.append({"round": m, "exact_zero_3_of_3": all(zeros), "syntactically_zero": not live_m})
            # the mechanism probe: every private table arbitrary, every public zero
            rng = F.Rng(sd(shape, sl.slot, "mech"))
            comp = sl.compile(rng)
            v = [rng.fp2() if i in sl.private else F.ZERO for i in range(len(sl.tables))]
            pub_factor_every_monomial = F.is_zero(Slot.evaluate(comp, v))
            live_pub, _ = sl.live([i in sl.private for i in range(len(sl.tables))])
            entry = sl.public_entry_points()
            L = mask_len(sl.main + sl.ext, sl.d)
            dimC = (sl.main + sl.ext) * sl.d + 1
            tot_L += L
            tot_C += dimC
            if L > worst[0]:
                worst = (L, sl.slot)
            row = {
                "slot": sl.slot,
                "name": sl.name,
                "kind": sl.kind,
                "main": sl.main,
                "ext": sl.ext,
                "declared_degree": sl.d,
                "max_product_degree_walked": maxdeg,
                "max_product_degree_export": sl.maxdeg_export,
                "stored_degrees_agree": stored_ok,
                "per_variable_degree_bound_max": max(pvd) if pvd else 0,
                "per_variable_degree_bound_min": min(pvd) if pvd else 0,
                "degree_fits": maxdeg <= sl.d and max(pvd) <= sl.d,
                "slack": sl.d - maxdeg,
                "pad_on": sl.pad_on,
                "group_bits": sl.group_bits,
                "tables": {k: sl.kinds.count(k) for k in PUBLIC_KINDS + PRIVATE_KINDS if sl.kinds.count(k)},
                "private_ext_rounds": sorted(set(sl.ext_round.values())),
                "premise": prem,
                "premise_holds": all(p["exact_zero_3_of_3"] for p in prem),
                "public_factor_in_every_monomial_exact": pub_factor_every_monomial,
                "public_factor_in_every_monomial_syntactic": not live_pub,
                "public_entry_points": {str(k): v for k, v in entry.items()},
                "L": L,
                "dimC": dimC,
                "budget_ok": L + MASK_Q <= MASK_MSG,
            }
            rows.append(row)
        s1[shape] = rows
        s2[shape] = {"sum_L": tot_L, "sum_dimC": tot_C, "sum_ker": tot_L - tot_C, "worst_L": worst[0], "worst_slot": worst[1], "budget_all_ok": all(r["budget_ok"] for r in rows)}
        n_prem = sum(1 for r in rows if r["premise_holds"])
        n_pf = sum(1 for r in rows if r["public_factor_in_every_monomial_exact"])
        n_deg = sum(1 for r in rows if r["degree_fits"])
        n_supp = sum(1 for r in rows if "supp" in r["tables"])
        n_geq = sum(1 for r in rows if "group_eq" in r["tables"])
        s2[shape].update({"premise_holds": n_prem, "public_factor_every_monomial": n_pf, "degree_fits": n_deg, "slots_with_support_indicator": n_supp, "slots_with_group_eq": n_geq, "max_declared_degree": max(r["declared_degree"] for r in rows)})
        log(
            f"S1 [{shape}] premise {n_prem}/23; public factor in every monomial {n_pf}/23; degree fits {n_deg}/23 (max declared {s2[shape]['max_declared_degree']}); "
            f"supp slots {n_supp}; group-eq slots {n_geq}; sum L {tot_L}, dim C {tot_C}, ker {tot_L - tot_C}; worst L {worst[0]} at slot {worst[1]}"
        )
        bad = [r["slot"] for r in rows if not (r["premise_holds"] and r["degree_fits"] and r["budget_ok"] and r["stored_degrees_agree"] and r["max_product_degree_walked"] == r["max_product_degree_export"])]
        if bad:
            log(f"S1 [{shape}] SLOTS FAILING A DEPENDENCY: {bad}")
        nonpf = [r["slot"] for r in rows if not r["public_factor_in_every_monomial_exact"]]
        if nonpf:
            log(f"S1 [{shape}] slots whose premise needs the second mechanism (different extension rounds): {nonpf}")
        syn_disagree = [r["slot"] for r in rows if any(p["exact_zero_3_of_3"] != p["syntactically_zero"] for p in r["premise"])]
        if syn_disagree:
            log(f"S1 [{shape}] syntactic and exact premise disagree (cancellation) at {syn_disagree}")
    out["stages"]["S1_slots"] = s1
    out["stages"]["S2_budgets"] = s2

    # ------------------------------------------------------------------ S3 Fact 2.1 at full size
    pairs = sorted({(r["main"] + r["ext"], r["declared_degree"]) for rows in s1.values() for r in rows})
    log("S3 distinct (N, d) pairs over all shapes:", len(pairs), pairs)
    s3 = {"pairs": [], "brute_force_round_map": None}
    # the closed-form round map against a brute-force sum, small N
    rng = F.Rng(0xF21)
    bf = 0
    for N in (1, 2, 3, 4, 5):
        for d in (2, 3, 4, 5):
            coeffs = [rng.fp2() for _ in range(mask_len(N, d))]
            prev_all = [rng.fp2() for _ in range(N)]
            for j in range(N):
                cf = mask_round(coeffs, N, d, j, prev_all[:j])
                for X in range(d + 1):
                    acc = F.ZERO
                    for rest in range(1 << (N - 1 - j)):
                        xs = list(prev_all[:j]) + [F.f(X)] + [F.f((rest >> (N - 2 - j - k)) & 1) for k in range(N - 1 - j)]
                        acc = F.add(acc, g_eval_brute(coeffs, N, d, xs))
                    assert acc == cf[X], (N, d, j, X)
                    bf += 1
            # total and eval weights
            tot = F.ZERO
            for x in range(1 << N):
                xs = [F.f((x >> (N - 1 - k)) & 1) for k in range(N)]
                tot = F.add(tot, g_eval_brute(coeffs, N, d, xs))
            assert tot == dot(sum_weights(N, d), coeffs)
            assert g_eval_brute(coeffs, N, d, prev_all) == dot(eval_weights(prev_all, d), coeffs)
            bf += 2
    s3["brute_force_round_map"] = bf
    log("S3 closed-form round map, total and eval weights vs brute force:", bf, "values equal")
    regimes = ["random-Fp2", "all-zero", "all-one", "alternating-0-1", "all-equal"]
    n_checks = 0
    n_tight = 0
    for (N, d) in pairs:
        for reg in regimes:
            rng = F.Rng(sd(N, d, reg))
            if reg == "random-Fp2":
                rho = [rng.fp2() for _ in range(N)]
            elif reg == "all-zero":
                rho = [F.ZERO] * N
            elif reg == "all-one":
                rho = [F.ONE] * N
            elif reg == "alternating-0-1":
                rho = [F.ZERO if k % 2 == 0 else F.ONE for k in range(N)]
            else:
                v = rng.fp2()
                rho = [v] * N
            # only the random regime at the largest pairs (the Fp2 rank is the slow part)
            rows = round_matrix_rows(N, d, rho)
            width = 1 + N * (d + 1)
            L = mask_len(N, d)
            rk = F.rank(rows, width)
            crk = consistency_rank(N, d, rho)
            dimC = width - crk
            # Im R in C: every row satisfies the chain
            in_c = True
            for r in rows:
                if F.add(r[1], r[2]) != r[0]:
                    in_c = False
                for j in range(1, N):
                    o = 1 + j * (d + 1)
                    po = 1 + (j - 1) * (d + 1)
                    if F.add(r[o], r[o + 1]) != interp(r[po : po + d + 1], rho[j - 1]):
                        in_c = False
            k = explicit_kernel(N, d, rho)
            Rk = [F.ZERO] * width
            for i in range(L):
                if not F.is_zero(k[i]):
                    Rk = [F.add(a, F.mul(k[i], b)) for a, b in zip(Rk, rows[i])]
            kernel_ok = all(F.is_zero(x) for x in Rk)
            sw = dot(sum_weights(N, d), k)
            ew = dot(eval_weights(rho, d), k)
            tight = rk == N * d + 1 and dimC == N * d + 1 and in_c and kernel_ok and F.is_zero(sw) and F.is_zero(ew) and (L - rk) == 1
            n_checks += 1
            n_tight += int(tight)
            s3["pairs"].append({"N": N, "d": d, "regime": reg, "L": L, "rank_R": rk, "dimC": dimC, "ImR_in_C": in_c, "explicit_kernel": kernel_ok, "sum_weights_kill_kernel": F.is_zero(sw), "eval_weights_kill_kernel": F.is_zero(ew), "tight": tight})
    s3["checks"] = n_checks
    s3["tight"] = n_tight
    out["stages"]["S3_fact21"] = s3
    log(f"S3 Fact 2.1 at full size: {n_tight}/{n_checks} (N, d, regime) triples exactly tight (rank = dim C = N d + 1, kernel = the explicit line, sum/eval weights in rowspace)")

    # ------------------------------------------------------------------ S4 miniatures
    s4 = {}
    for shape in sorted(shapes):
        res_rows = []
        for s in range(23):
            sl = all_slots[(shape, s)]
            rng = F.Rng(sd(shape, s, "mini"))
            r = miniature(sl, rng)
            r["slot"] = s
            res_rows.append(r)
        ok = [
            r
            for r in res_rows
            if r["chain_accepts"]
            and r["fact32_identity"]
            and r["terminal_formula"]
            and r["rank_R"] == r["dimC_expected"]
            and r["offset_in_ImR"]
            and r.get("fibre_constructed")
            and r.get("fibre_same_published_view")
            and r.get("fibre_witness_differs")
            and r.get("fibre_same_V")
        ]
        pg = sum(1 for r in res_rows if r.get("fibre_private_gamma_would_differ") and r.get("fibre_private_gamma_shift_is_sigma_diff"))
        s4[shape] = {"rows": res_rows, "all_pass": len(ok), "private_gamma_control_fires": pg}
        log(f"S4 [{shape}] miniature runs passing every check: {len(ok)}/23; the Private-Gamma control fires in {pg}/23")
        bad = [r["slot"] for r in res_rows if r not in ok]
        if bad:
            log(f"S4 [{shape}] FAILING: {bad}", [{k: r[k] for k in r if k != 'slot'} for r in res_rows if r['slot'] in bad])
    out["stages"]["S4_miniatures"] = s4

    # per-slot terminal masking (the pair shape), at the miniature
    rng = F.Rng(0x7E53)
    tp = {}
    for shape in SHAPES_OF_RECORD:
        rks = []
        for s in range(23):
            sl = all_slots[(shape, s)]
            m = len(sl.private)
            rk = terminal_pair_rank(m, 2, rng)
            rkb = terminal_pair_rank(m, 2, rng, tail_kind="boolean", same_tail=True)
            rks.append((s, m, rk, rkb, rk == 2 * m and rkb == 2 * m))
        tp[shape] = {"slots_onto_Fp2^m": sum(1 for x in rks if x[4]), "rows": rks}
        log(f"S4 [{shape}] per-slot terminal map (R_re, R_im) -> terminals onto Fp2^m (Fp-rank 2m), at random tails AND at one shared boolean tail: {tp[shape]['slots_onto_Fp2^m']}/23; terminals per slot {[x[1] for x in rks]}")
    out["stages"]["S4_terminal_pairs"] = tp

    # ------------------------------------------------------------------ S5 controls
    s5 = {}
    m125 = {s: all_slots[("m125", s)] for s in range(23)}

    def with_json(sl, js):
        return Slot(js, sl.shape, src["ext_assign"])

    # C1..C3: slot 08 (SC_SCORE) at 125M
    base8 = m125[8]
    q_id, k_id = base8.private
    js_nogeq = json.loads(json.dumps(base8.js))
    for t in js_nogeq["terms"]:
        t["wrapper"] = [w for w in t["wrapper"] if w != 0]
    sl_nogeq = with_json(base8, js_nogeq)

    def premise_exact(sl, ext_round, seeds=(11, 12, 13)):
        allz = True
        for m in range(sl.ext):
            for sd in seeds:
                rng = F.Rng(sd * 7919 + m)
                comp = sl.compile(rng)
                v = [rng.fp2() if (i in sl.private and ext_round[i] == m) else F.ZERO for i in range(len(sl.tables))]
                if not F.is_zero(Slot.evaluate(comp, v)):
                    allz = False
        return allz

    same_round = {q_id: 0, k_id: 0}
    s5["C1_group_eq_kept_both_round0"] = {"premise_holds": premise_exact(base8, same_round), "expect": True}
    s5["C2_group_eq_dropped_rounds_0_1"] = {"premise_holds": premise_exact(sl_nogeq, base8.ext_round), "expect": True}
    s5["C3_group_eq_dropped_both_round0"] = {"premise_holds": premise_exact(sl_nogeq, same_round), "expect": False}
    r = miniature(sl_nogeq, F.Rng(0xC3), override={"ext_round": same_round})
    s5["C3_miniature"] = {"chain_accepts": r["chain_accepts"], "offset_in_ImR": r["offset_in_ImR"], "expect": "chain rejects, offset outside Im R"}
    # C4: slot 17 (SC_SZC) at 125M, the pad-zero subterm moved outside eq(tau)
    base17 = m125[17]
    js4 = json.loads(json.dumps(base17.js))
    moved = False
    for n in js4["nodes"]:
        if n["body"] == "sum":
            keep = []
            for st in n["subterms"]:
                fs = st["factors"]
                if len(fs) == 2 and all("node" in fc for fc in fs) and js4["nodes"][fs[0]["node"]]["label"].startswith("1 - supp") and not moved:
                    js4["terms"].append({"coef": st["coef"], "wrapper": [], "inner": fs, "degree": 2, "note": "control C4: pad term outside eq(tau)"})
                    moved = True
                else:
                    keep.append(st)
            n["subterms"] = keep
    sl4 = with_json(base17, js4)
    s5["C4_pad_term_outside_eq"] = {"moved": moved, "premise_holds": premise_exact(sl4, sl4.ext_round), "expect": False}
    r = miniature(sl4, F.Rng(0xC4))
    s5["C4_miniature"] = {"chain_accepts": r["chain_accepts"], "offset_in_ImR": r["offset_in_ImR"], "expect": "chain rejects, offset outside Im R"}
    # C5: slot 17 at 125M declared one degree too low (its product degree is 5)
    r = miniature(base17, F.Rng(0xC5), override={"d": base17.d - 1})
    s5["C5_declared_degree_minus_one"] = {"declared": base17.d - 1, "max_product": base17.maxdeg_export, "chain_accepts": r["chain_accepts"], "expect": False}
    # C6: Fact 2.1 with a mask one degree short of the published d + 1 values
    N, d = 23, 5
    rng = F.Rng(0xC6)
    rho = [rng.fp2() for _ in range(N)]
    rows = round_matrix_rows(N, d, rho, mask_degree=d - 1)
    rk = F.rank(rows, 1 + N * (d + 1))
    s5["C6_mask_one_degree_short"] = {"N": N, "d": d, "rank": rk, "dimC": N * d + 1, "covers": rk == N * d + 1, "expect": False}
    # C7 / C8: the terminal pair shape and a shared pair
    rng = F.Rng(0xC7)
    s5["C7_honest_pair_boolean_tail"] = {"fp_rank": terminal_pair_rank(1, 2, rng, tail_kind="boolean"), "onto_needs": 2, "expect": "onto"}
    s5["C7_pair_weights_cm_cm_boolean_tail"] = {"fp_rank": terminal_pair_rank(1, 2, rng, weights="cm1", tail_kind="boolean"), "onto_needs": 2, "expect": "short"}
    s5["C7_pair_weights_cm_cm_fp2_tail"] = {"fp_rank": terminal_pair_rank(1, 2, rng, weights="cm1"), "onto_needs": 2, "expect": "onto (the Fp2 tail covers the loss; not a defence)"}
    s5["C8_honest_distinct_pairs_same_tail"] = {"fp_rank": terminal_pair_rank(2, 2, rng, same_tail=True), "onto_needs": 4, "expect": "onto"}
    s5["C8_shared_pair_same_tail"] = {"fp_rank": terminal_pair_rank(2, 2, rng, share=(0, 1), same_tail=True), "onto_needs": 4, "expect": "short"}
    s5["C8_shared_pair_different_tails"] = {"fp_rank": terminal_pair_rank(2, 2, rng, share=(0, 1)), "onto_needs": 4, "expect": "onto on terminals alone; the joint trap needs the PCS view ((H1), not here)"}
    # C9 — a SCOPE probe, not a P1 finding: under P3 (hidden weights) the
    # tables built from model weights (the seven folded matrices, the two
    # norm gains) would become private factors. Which slots would then lose
    # the premise if those factors were masked in the plane's own round?
    p3_fail = []
    p3_tables = {}
    for s in range(23):
        sl = m125[s]
        js = json.loads(json.dumps(sl.js))
        hit = []
        for t in js["tables"]:
            if "weight matrix folded" in t["prov"] or t["label"].startswith("gamma_"):
                t["kind"] = "A"
                hit.append(t["label"])
        if not hit:
            continue
        p3_tables[s] = hit
        slp = Slot(js, "m125", src["ext_assign"])
        if not premise_exact(slp, slp.ext_round):
            p3_fail.append(s)
    s5["C9_P3_scope_probe_weights_private"] = {"slots_with_weight_tables": {str(k): v for k, v in p3_tables.items()}, "premise_fails_at": p3_fail}
    # the toy's own mechanism split, from its IR, as a sanity anchor
    toy_rows = s1["toy"]
    s5["toy_anchor"] = {
        "premise_holds": sum(1 for r in toy_rows if r["premise_holds"]),
        "public_factor_every_monomial": [r["slot"] for r in toy_rows if r["public_factor_in_every_monomial_exact"]].__len__(),
        "second_mechanism_slots": [r["slot"] for r in toy_rows if not r["public_factor_in_every_monomial_exact"]],
        "expect": "23 / 21 / [8, 9]",
    }
    fired = {
        "C1 (redundancy, must NOT fire)": s5["C1_group_eq_kept_both_round0"]["premise_holds"] is True,
        "C2 (toy mechanism, must NOT fire)": s5["C2_group_eq_dropped_rounds_0_1"]["premise_holds"] is True,
        "C3 fires": s5["C3_group_eq_dropped_both_round0"]["premise_holds"] is False and not s5["C3_miniature"]["chain_accepts"] and not s5["C3_miniature"]["offset_in_ImR"],
        "C4 fires": moved and s5["C4_pad_term_outside_eq"]["premise_holds"] is False and not s5["C4_miniature"]["chain_accepts"],
        "C5 fires": s5["C5_declared_degree_minus_one"]["chain_accepts"] is False,
        "C6 fires": s5["C6_mask_one_degree_short"]["covers"] is False,
        "C7 honest pair onto at a boolean tail (must NOT fire)": s5["C7_honest_pair_boolean_tail"]["fp_rank"] == 2,
        "C7 fires ((cm, cm) at a boolean tail)": s5["C7_pair_weights_cm_cm_boolean_tail"]["fp_rank"] < 2,
        "C8 honest distinct pairs onto (must NOT fire)": s5["C8_honest_distinct_pairs_same_tail"]["fp_rank"] == 4,
        "C8 fires (shared pair, same tail)": s5["C8_shared_pair_same_tail"]["fp_rank"] < 4,
        "C9 P3 probe fires at exactly the seven matmul slots": s5["C9_P3_scope_probe_weights_private"]["premise_fails_at"] == [5, 6, 7, 10, 11, 12, 13],
        "toy anchor 23/21/[8,9]":s5["toy_anchor"]["premise_holds"] == 23 and s5["toy_anchor"]["public_factor_every_monomial"] == 21 and s5["toy_anchor"]["second_mechanism_slots"] == [8, 9],
    }
    s5["verdicts"] = fired
    out["stages"]["S5_controls"] = s5
    for k, v in fired.items():
        log(f"S5 {k}: {'OK' if v else 'NOT AS EXPECTED'}")
    log("S5 details:", {k: v for k, v in s5.items() if k != "verdicts"})

    out["elapsed_s"] = round(time.time() - t0, 1)
    out["summary"] = {
        "shapes": sorted(shapes),
        "premise_holds": {k: v["premise_holds"] for k, v in s2.items()},
        "public_factor_every_monomial": {k: v["public_factor_every_monomial"] for k, v in s2.items()},
        "degree_fits": {k: v["degree_fits"] for k, v in s2.items()},
        "budget": {k: (v["worst_L"], v["worst_slot"], v["budget_all_ok"]) for k, v in s2.items()},
        "sum_L_dimC_ker": {k: (v["sum_L"], v["sum_dimC"], v["sum_ker"]) for k, v in s2.items()},
        "fact21_tight": f"{s3['tight']}/{s3['checks']}",
        "miniatures_all_pass": {k: v["all_pass"] for k, v in s4.items()},
        "controls_as_expected": sum(1 for v in fired.values() if v),
        "controls_total": len(fired),
    }
    log("SUMMARY", json.dumps(out["summary"]))
    log(f"elapsed {out['elapsed_s']} s")
    with open(os.path.join(HERE, "nl_check.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=str)
    with open(os.path.join(HERE, "nl_check.log"), "w") as fh:
        fh.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
