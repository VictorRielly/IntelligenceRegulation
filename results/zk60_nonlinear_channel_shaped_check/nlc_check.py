#!/usr/bin/env python3
"""GS-13 ADVERSARIAL CHECK: an independent re-derivation of the draft
docs/zkmatrix-poc/ZK60_NONLINEAR_CHANNEL_SHAPED.md (DRAFT, unchecked).

Written without importing or copying the draft's nl_check.py / nl_field.py.
Re-runnable with no arguments (CPU only, no Rust built or run):

    python3 results/zk60_nonlinear_channel_shaped_check/nlc_check.py

Reads (read-only): the lane worktree /home/victor/wt-zk60-block125m — the
nine slot-IR exports, argument.rs / layout.rs / shape.rs / slot_ir.rs /
zk.rs / s24_tests.rs, zkp-core/src/sumcheck.rs, the lane's dense-run
markers; and the draft's nl_check.json (only to compare figures).
Writes nlc_check.json and nlc_check.log next to this file.

Stages
  K0  field self-test
  K1  SYMBOLIC expansion of every slot polynomial of every export into its
      monomial SUPPORT (cancellation ignored, so every verdict below is a
      sufficient condition that holds for EVERY value of every challenge
      coefficient): the premise per extension round, "a public TABLE in
      every monomial", product degree, the per-variable bound, where the
      support indicators and group eq enter
  K2  counts: L_s, dim C_s, totals, worst L, round values, terminals by
      commitment, words per block, (N, d) pairs, indicator / group-eq slots
  K3  sources: the extension-round argument of every private push in
      `define`, parsed with balanced parentheses (multi-line safe); the
      helper defaults; the IR labels of slots 08 / 09 against the code's
      coordinate lists; SLOT_KINDS / HOSTS; the declared-degree formula
  K4  Fact 2.1: R built from a per-basis-vector derivation of the CFS round
      messages (checked against brute force), rank / dim C / Im R in C /
      eval and sum weights in the column space by AUGMENTED RANK (not the
      draft's explicit kernel), at every (N, d) and seven challenge regimes
  K5  fibre tests with the protocol's REAL slot kinds and ADMISSIBLE
      witnesses: slots 08 / 09 at their full 125M cube with the real group
      eq and two extension rounds; Standalone slots 20 / 21 at their full
      rung-G cube with a witness that satisfies the relation (claim 0,
      scalar c G, Gamma revealed); a three-slot host coupling (18 hosting
      11 and 12, 125M IR, miniature cubes) with admissibility enforced;
      main-round challenges 0 and 1 included
  K6  the draft's own check, read for defects (reported, not re-run)
  K7  citations of the draft, line by line; GN-1 evidence markers
"""

import hashlib
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import nlc_field as F  # noqa: E402

LANE = "/home/victor/wt-zk60-block125m"
IR_DIR = LANE + "/results/zk60_block125m_lane/x34-slot-ir"
SHAPES = ["toy", "rung", "rung_p2", "rung_c6", "rung_w14", "rung_e32", "rung_g", "rung_k4", "m125"]
SHAPED = [s for s in SHAPES if s != "toy"]
RECORD = ["rung_g", "rung_k4", "m125"]
SRC = {
    "argument.rs": LANE + "/hashline/src/private_block/argument.rs",
    "layout.rs": LANE + "/hashline/src/private_block/layout.rs",
    "shape.rs": LANE + "/hashline/src/private_block/shape.rs",
    "slot_ir.rs": LANE + "/hashline/src/private_block/slot_ir.rs",
    "s24_tests.rs": LANE + "/hashline/src/private_block/s24_tests.rs",
    "zk.rs": LANE + "/hashline/src/zk.rs",
    "sumcheck.rs": LANE + "/zkp-core/src/sumcheck.rs",
}
DRAFT_JSON = "/home/victor/IntelligenceRegulation/results/zk60_nonlinear_channel_shaped/nl_check.json"
MASK_MSG, MASK_PADS = 512, 256

LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(s)
    print(s, flush=True)


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


PUBLIC = ("eq", "group_eq", "pub", "supp")
PRIVATE = ("A", "H", "EP")


def kind_of(t):
    k = t["kind"]
    return k.split("(")[0]


def load_ir():
    out = {}
    for s in SHAPES:
        p = f"{IR_DIR}/slot_ir_{s}.json"
        js = json.load(open(p))
        assert js["schema"] == "zk60-slot-ir/1" and js["shape"] == s and len(js["slots"]) == 23
        out[s] = (p, js)
    return out


# =========================================================================
# K1: symbolic expansion (support only; cancellation ignored)
# =========================================================================


def coef_is_literal_zero(c):
    return "value" in c and F.iszero(F.parse(c["value"]))


def mul_support(A, B):
    out = {}
    for ma, ca in A.items():
        for mb, cb in B.items():
            m = tuple(sorted(ma + mb))
            out[m] = out.get(m, 0) + ca * cb
    return out


def add_support(acc, B):
    for m, c in B.items():
        acc[m] = acc.get(m, 0) + c


def expand_support(sj):
    """monomial support of the slot polynomial: {sorted tuple of table ids:
    number of contributing products}. A constant is the empty tuple."""
    nodes = []
    for nd in sj["nodes"]:
        ex = {}
        if nd["body"] == "affine":
            if not coef_is_literal_zero(nd["konst"]):
                ex[()] = 1
            for t in nd["terms"]:
                if not coef_is_literal_zero(t["coef"]):
                    add_support(ex, {(t["table"],): 1})
        else:
            assert nd["body"] == "sum", nd["body"]
            for st in nd["subterms"]:
                if coef_is_literal_zero(st["coef"]):
                    continue
                prod = {(): 1}
                for f in st["factors"]:
                    prod = mul_support(prod, {(f["table"],): 1} if "table" in f else nodes[f["node"]])
                add_support(ex, prod)
        nodes.append(ex)
    total = {}
    for t in sj["terms"]:
        if coef_is_literal_zero(t["coef"]):
            continue
        prod = {tuple(sorted(t["wrapper"])): 1}
        for f in t["inner"]:
            prod = mul_support(prod, {(f["table"],): 1} if "table" in f else nodes[f["node"]])
        add_support(total, prod)
    return total


def table_vars(t, n):
    k = t["kind"]
    m = re.fullmatch(r"eq\(start=(\d+),\|point\|=(\d+)\)", k)
    if m:
        s, l = int(m.group(1)), int(m.group(2))
        return set(range(s, s + l))
    m = re.fullmatch(r"group_eq\(bits=(\d+)\)", k)
    if m:
        return set(range(int(m.group(1))))
    return set(range(n))


def k1_slot(sj, ext_round_of):
    kinds = [kind_of(t) for t in sj["tables"]]
    for k in kinds:
        assert k in PUBLIC + PRIVATE, k
    sup = expand_support(sj)
    n = sj["main_rounds"]
    ext = sj["extension_rounds"]
    d = sj["declared_degree"]
    priv = [i for i, k in enumerate(kinds) if k in PRIVATE]
    pub = set(i for i, k in enumerate(kinds) if k in PUBLIC)
    rounds = {i: ext_round_of.get(i, 0) for i in priv}
    # the premise per extension round: a monomial survives exts_m only if
    # EVERY table in it is a private table of round m (the empty monomial,
    # a pure constant, survives every round)
    prem_fail = {m: [mono for mono in sup if all(i in rounds and rounds[i] == m for i in mono)] for m in range(ext)}
    no_pub = [mono for mono in sup if not any(i in pub for i in mono)]
    # which public kinds carry each monomial
    carriers = {}
    for mono in sup:
        ks = tuple(sorted(set(kinds[i] for i in mono if i in pub)))
        carriers[ks] = carriers.get(ks, 0) + 1
    prod_deg = max((len(m) for m in sup), default=0)
    deps = [table_vars(t, n) for t in sj["tables"]]
    pv = [0] * n
    for mono in sup:
        for j in range(n):
            c = sum(1 for i in mono if j in deps[i])
            if c > pv[j]:
                pv[j] = c
    # top-level sufficient form: every IR term carries a public table either
    # in its wrapper or as a DIRECT table factor of its inner product
    top = all(any(w in pub for w in t["wrapper"]) or any("table" in f and f["table"] in pub for f in t["inner"]) for t in sj["terms"])
    # where the support indicators and the group eq enter, by expansion
    supp_ids = [i for i, k in enumerate(kinds) if k == "supp"]
    supp_alone = [mono for mono in sup if any(i in supp_ids for i in mono) and not any(kinds[i] in ("eq", "group_eq") for i in mono)]
    return {
        "slot": sj["slot"],
        "kind": sj["kind"],
        "main": n,
        "ext": ext,
        "d": d,
        "n_tables": len(kinds),
        "n_private": len(priv),
        "private_by_commitment": {k: kinds.count(k) for k in PRIVATE if kinds.count(k)},
        "public_kinds": sorted(set(kinds[i] for i in pub)),
        "n_monomials": len(sup),
        "premise_failing_monomials": {str(m): [list(x) for x in v] for m, v in prem_fail.items()},
        "premise_holds_all_rounds": all(not v for v in prem_fail.values()),
        "monomials_without_public_table": [list(x) for x in no_pub],
        "public_table_in_every_monomial": not no_pub,
        "top_level_public_factor_every_term": top,
        "monomials_by_public_carrier": {"+".join(k) if k else "(none)": v for k, v in sorted(carriers.items())},
        "constant_monomial_present": () in sup,
        "product_degree": prod_deg,
        "export_max_product_degree": sj["max_product_degree"],
        "per_variable_bound_max": max(pv) if pv else 0,
        "degree_fits": prod_deg <= d,
        "slack": d - prod_deg,
        "has_supp": bool(supp_ids),
        "supp_monomials_without_eq": len(supp_alone),
        "has_group_eq": "group_eq" in kinds,
        "ext_rounds_used": sorted(set(rounds.values())),
    }


# =========================================================================
# K3: sources (balanced-parenthesis parse of `define`)
# =========================================================================


def balanced_args(text, pos):
    """text[pos] is just after '('. Return (args list, end index)."""
    depth = 1
    i = pos
    cur = []
    args = []
    while depth:
        ch = text[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                args.append("".join(cur).strip())
                return args, i
        if ch == "," and depth == 1:
            args.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
        i += 1
    return args, i


def parse_define():
    arg = open(SRC["argument.rs"]).read()
    s0 = arg.index("pub(crate) fn define(")
    s1 = arg.index("pub(crate) fn argument(")
    body = arg[s0:s1]
    base_line = arg[:s0].count("\n") + 1
    arms = [(m.start(), m.group(1)) for m in re.finditer(r"(?m)^\s{8}(SC_[A-Z0-9_]+(?:\s*\|\s*SC_[A-Z0-9_]+)*)\s*=>", body)]

    def arm_at(p):
        a = None
        for q, name in arms:
            if q <= p:
                a = name
        return a

    pushes = []
    for m in re.finditer(r"\bb\.(a_at|a_slice)\(", body):
        args, _ = balanced_args(body, m.end())
        pushes.append({"line": base_line + body[: m.start()].count("\n"), "arm": arm_at(m.start()), "fn": m.group(1), "n_args": len(args), "ext_round": args[-1]})
    other = {}
    for fn in ("a", "h", "endpoint", "a_range"):
        other[fn] = len(re.findall(r"\bb\." + fn + r"\(", body))
    # the helpers' own defaults, read from `impl B`
    ib0 = arg.index("impl<'a> B<'a> {")
    ib1 = arg.index("fn tile_rep(")
    impl = arg[ib0:ib1]
    helper = {
        "a() pushes a_at(.., 0)": "self.a_at(plane, rho(0..log), 0)" in impl,
        "h() pushes ext_round: 0": bool(re.search(r"fn h\(.*?Tab::Priv\(Priv \{ cm: Cm::H,.*?ext_round: 0 \}\)", impl, re.S)),
        "endpoint() pushes ext_round: 0": bool(re.search(r"fn endpoint\(.*?Tab::Priv\(Priv \{ cm,.*?ext_round: 0 \}\)", impl, re.S)),
        "a_range -> self.a(p)": "shaped[p] = self.a(p)?" in impl,
        "a_slice stores the caller's ext_round": "mask_row, ext_round })" in impl,
    }
    # direct Priv constructions anywhere in argument.rs outside tests
    direct = [arg[: m.start()].count("\n") + 1 for m in re.finditer(r"Tab::Priv\(Priv \{", arg)]
    return {"pushes": pushes, "other_private_push_calls": other, "helpers": helper, "direct_priv_constructions_lines": direct}


def parse_layout():
    lay = open(SRC["layout.rs"]).read()
    i = lay.index("pub(crate) const SLOT_KINDS")
    j = lay.index("];", i)
    kinds = re.findall(r"SlotKind::(Private|Standalone|Host)", lay[i:j])
    sc = dict((m.group(1), int(m.group(2))) for m in re.finditer(r"pub\(crate\) const (SC_[A-Z0-9_]+): usize = (\d+);", lay))
    i = lay.index("pub(crate) const HOSTS")
    j = lay.index("];", i)
    hosts = []
    for m in re.finditer(r"\((SC_[A-Z0-9_]+),\s*&\[([^\]]*)\]\)", lay[i:j]):
        hosts.append((sc[m.group(1)], [sc[x.strip()] for x in m.group(2).split(",") if x.strip()]))
    return {"kinds": kinds, "hosts": hosts, "sc": sc}


# =========================================================================
# K4: the CFS mask map, derived per basis vector
# =========================================================================


def mask_len(N, d):
    return N * d + 2


def basis_rounds(N, d, rho, k):
    """R(e_k): (G, g_0(0..d), ..., g_{N-1}(0..d)) for the k-th unit mask
    coefficient, from g(x) = a0 + a' prod x + sum_{i,e} a_{i,e} x_i^e:
      a0     : G = 2^N;      g_j(X) = 2^(N-1-j)
      a'     : G = 1;        g_j(X) = (prod_{i<j} rho_i) X
      a_{i,e}: G = 2^(N-1);  g_j(X) = 2^(N-1-j) rho_i^e (i < j),
                             2^(N-1-j) X^e (i = j), 2^(N-2-j) (i > j)"""
    out = []
    if k == 0:
        out.append(F.e(1 << N))
        for j in range(N):
            out.extend([F.e(1 << (N - 1 - j))] * (d + 1))
        return out
    if k == 1:
        out.append(F.ONE)
        pp = F.ONE
        for j in range(N):
            out.extend([F.mul(pp, F.e(x)) for x in range(d + 1)])
            pp = F.mul(pp, rho[j])
        return out
    i, ee = divmod(k - 2, d)
    ee += 1
    out.append(F.e(1 << (N - 1)))
    for j in range(N):
        if i < j:
            v = F.mul(F.e(1 << (N - 1 - j)), F.pw(rho[i], ee))
            out.extend([v] * (d + 1))
        elif i == j:
            out.extend([F.mul(F.e(1 << (N - 1 - j)), F.pw(F.e(x), ee)) for x in range(d + 1)])
        else:
            out.extend([F.e(1 << (N - 2 - j)) if N - 2 - j >= 0 else F.ZERO] * (d + 1))
    return out


def R_rows(N, d, rho):
    return [basis_rounds(N, d, rho, k) for k in range(mask_len(N, d))]


def g_eval(a, N, d, x):
    v = a[0]
    p = F.ONE
    for xi in x:
        p = F.mul(p, xi)
    v = F.add(v, F.mul(a[1], p))
    for i, xi in enumerate(x):
        xp = F.ONE
        for ee in range(1, d + 1):
            xp = F.mul(xp, xi)
            v = F.add(v, F.mul(a[2 + i * d + ee - 1], xp))
    return v


def apply_R(a, N, d, rho):
    rows = R_rows(N, d, rho)
    width = len(rows[0])
    out = [F.ZERO] * width
    for k, ak in enumerate(a):
        if not F.iszero(ak):
            out = [F.add(o, F.mul(ak, r)) for o, r in zip(out, rows[k])]
    return out


def brute_rounds(a, N, d, rho):
    """(G, rounds) of g by brute force over the cube (small N only)"""
    G = F.ZERO
    for idx in range(1 << N):
        G = F.add(G, g_eval(a, N, d, [F.e((idx >> (N - 1 - t)) & 1) for t in range(N)]))
    out = [G]
    for j in range(N):
        for X in range(d + 1):
            acc = F.ZERO
            rest = N - 1 - j
            for idx in range(1 << rest):
                pt = list(rho[:j]) + [F.e(X)] + [F.e((idx >> (rest - 1 - t)) & 1) for t in range(rest)]
                acc = F.add(acc, g_eval(a, N, d, pt))
            out.append(acc)
    return out


def lagrange(d, r):
    out = []
    for i in range(d + 1):
        num = F.ONE
        den = 1
        for k in range(d + 1):
            if k != i:
                num = F.mul(num, F.sub(r, F.e(k)))
                den *= i - k
        out.append(F.mul(num, F.inv(F.e(den))))
    return out


def chain_ok(v, N, d, rho):
    """does v = (claim, s_0(0..d), ..) satisfy the verifier's chain equations?"""
    claim = v[0]
    for j in range(N):
        s = v[1 + j * (d + 1) : 1 + (j + 1) * (d + 1)]
        if F.add(s[0], s[1]) != claim:
            return False
        lr = lagrange(d, rho[j])
        claim = F.ZERO
        for li, si in zip(lr, s):
            claim = F.add(claim, F.mul(li, si))
    return True


def sum_w(N, d):
    w = [F.e(1 << (N - 1))] * mask_len(N, d)
    w[0] = F.e(1 << N)
    w[1] = F.ONE
    return w


def eval_w(rho, d):
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


# =========================================================================
# K5: honest masked sumcheck with extension rounds, real slot kinds
# =========================================================================


def compile_ir(sj, coef_val):
    """a closure v -> poly(v) from the IR, with coef_val(c) giving every
    coefficient's value"""
    nodes = sj["nodes"]
    terms = sj["terms"]
    cn = []
    for nd in nodes:
        if nd["body"] == "affine":
            cn.append(("a", coef_val(nd["konst"]), [(coef_val(t["coef"]), t["table"]) for t in nd["terms"]]))
        else:
            cn.append(("s", [(coef_val(st["coef"]), [(("t", f["table"]) if "table" in f else ("n", f["node"])) for f in st["factors"]]) for st in nd["subterms"]]))
    ct = [(coef_val(t["coef"]), list(t["wrapper"]), [(("t", f["table"]) if "table" in f else ("n", f["node"])) for f in t["inner"]]) for t in terms]

    def poly(v):
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
                    for kd, i in fs:
                        p = F.mul(p, v[i] if kd == "t" else nv[i])
                    acc = F.add(acc, p)
            nv.append(acc)
        out = F.ZERO
        for c, wr, inner in ct:
            p = c
            for w in wr:
                p = F.mul(p, v[w])
            for kd, i in inner:
                p = F.mul(p, v[i] if kd == "t" else nv[i])
            out = F.add(out, p)
        return out

    return poly


def coef_model(rng):
    """RELATED coefficient values, as the protocol draws them: one value per
    challenge label, zeta^j as powers of one zeta. (The draft drew most
    challenge coefficients independently per occurrence; K1's symbolic
    verdicts make the choice immaterial for the premise.)"""
    cache = {}
    zeta = rng.fp2_nz()

    def val(c):
        if "value" in c:
            return F.parse(c["value"])
        p = c["prov"]
        m = re.fullmatch(r"chal:zeta\^(\d+)", p)
        if m:
            return F.pw(zeta, int(m.group(1)))
        if p not in cache:
            cache[p] = rng.fp2_nz()
        return cache[p]

    return val


def eq_table(point):
    """eq(point, x) over {0,1}^|point|, MSB-first"""
    t = [F.ONE]
    for r in point:
        t = [y for x in t for y in (F.mul(x, F.sub(F.ONE, r)), F.mul(x, r))]
    return t


def eq_cube(point, n, start):
    e = eq_table(point)
    shift = n - start - len(point)
    return [e[(x >> shift) & (len(e) - 1)] for x in range(1 << n)]


def mle_eval(tab, rho):
    cur = list(tab)
    for r in rho:
        h = len(cur) // 2
        cur = [F.add(cur[i], F.mul(r, F.sub(cur[i + h], cur[i]))) for i in range(h)]
    return cur[0]


def honest_unmasked(poly, tables, rho, es, exts_by_round, d):
    """T'(w, pi): the true sum and the UNMASKED round messages (main rounds
    over the cube, then the extension rounds), plus terminal values"""
    cur = [list(t) for t in tables]
    size = len(cur[0])
    sigma = F.ZERO
    for x in range(size):
        sigma = F.add(sigma, poly([t[x] for t in cur]))
    rounds = []
    for r in rho:
        h = len(cur[0]) // 2
        s = [F.ZERO] * (d + 1)
        for i in range(h):
            lo = [t[i] for t in cur]
            df = [F.sub(t[i + h], t[i]) for t in cur]
            v = lo
            s[0] = F.add(s[0], poly(v))
            for X in range(1, d + 1):
                v = [F.add(a, b) for a, b in zip(v, df)]
                s[X] = F.add(s[X], poly(v))
        rounds.append(s)
        cur = [[F.add(t[i], F.mul(r, F.sub(t[i + h], t[i]))) for i in range(h)] for t in cur]
    at_rho = [t[0] for t in cur]
    vals = list(at_rho)
    for m, em in enumerate(es):
        ex = exts_by_round[m]
        s = []
        for X in range(d + 1):
            xv = F.e(X)
            s.append(poly([F.add(v, F.mul(xv, F.sub(x, v))) for v, x in zip(vals, ex)]))
        rounds.append(s)
        vals = [F.add(v, F.mul(em, F.sub(x, v))) for v, x in zip(vals, ex)]
    return sigma, rounds, at_rho, vals


def flat(claim, rounds):
    out = [claim]
    for r in rounds:
        out.extend(r)
    return out


def masked_view(claim_T, rounds, a, c, N, d, chal):
    """the published claim coordinate and rounds: T' + c R(a)"""
    Ra = apply_R(a, N, d, chal)
    base = flat(claim_T, rounds)
    return [F.add(x, F.mul(c, y)) for x, y in zip(base, Ra)]


def verify_view(view, N, d, chal):
    if not chain_ok(view, N, d, chal):
        return False, None
    claim = view[0]
    for j in range(N):
        s = view[1 + j * (d + 1) : 1 + (j + 1) * (d + 1)]
        lr = lagrange(d, chal[j])
        claim = F.ZERO
        for li, si in zip(lr, s):
            claim = F.add(claim, F.mul(li, si))
    return True, claim


def run_slot_world(poly, tables, priv, ext_round, rho, es, R, d):
    ext = len(es)
    ntab = len(tables)
    exts = [[R[i] if (i in priv and ext_round[i] == m) else F.ZERO for i in range(ntab)] for m in range(ext)]
    return honest_unmasked(poly, tables, rho, es, exts, d)


def cm_of(es, r):
    cm = es[r]
    for e2 in es[r + 1 :]:
        cm = F.mul(cm, F.sub(F.ONE, e2))
    return cm


def fibre_single(label, poly, pub_tables, priv, ext_round, n, d, kind, rng, make_private, rho=None):
    """One slot, the protocol's kind, two ADMISSIBLE worlds.
    kind 'Private': published scalar = sigma + c G, no Gamma in M.
    kind 'Standalone': admissible means sigma = 0; published scalar = c G,
    and M reveals Gamma = c G.
    Returns a dict of verdicts."""
    ext = max(ext_round.values()) + 1 if ext_round else 1
    N = n + ext
    L = mask_len(N, d)
    if rho is None:
        rho = [rng.fp2() for _ in range(n)]
    es = [rng.fp2_not01() for _ in range(ext)]
    chal = rho + es
    c = rng.fp2_nz()
    sel = F.ONE
    for e2 in es:
        sel = F.mul(sel, F.sub(F.ONE, e2))

    def world(priv_tabs, R):
        tables = [priv_tabs[i] if i in priv else pub_tables[i] for i in range(len(pub_tables))]
        return run_slot_world(poly, tables, priv, ext_round, rho, es, R, d)

    p1 = make_private(rng)
    R1 = {i: rng.fp2() for i in priv}
    sig1, rd1, at1, fin1 = world(p1, R1)
    a1 = [rng.fp2() for _ in range(L)]
    G1 = dot(sum_w(N, d), a1)
    claim_T1 = sig1 if kind == "Private" else F.ZERO
    admissible1 = kind == "Private" or F.iszero(sig1)
    view1 = masked_view(claim_T1, rd1, a1, c, N, d, chal)
    scalar1 = view1[0]  # Private: sigma + c G; Standalone: c G
    ok1, fin_claim = verify_view(view1, N, d, chal)
    terms1 = {i: fin1[i] for i in priv}
    vals1 = [terms1[i] if i in priv else F.mul(sel, at1[i]) for i in range(len(pub_tables))]
    g_true1 = dot(eval_w(chal, d), a1)
    g_derived = F.mul(F.sub(fin_claim, poly(vals1)), F.inv(c)) if ok1 else None
    res = {"label": label, "kind": kind, "n": n, "N": N, "d": d, "L": L, "ext": ext, "admissible_world1": admissible1, "chain_and_final_check": ok1 and g_derived == g_true1}
    # world 2: independent admissible private data; terminals aligned by the
    # reserved pairs; mask shifted by Delta with R(Delta) = (T'1 - T'2)/c
    p2 = make_private(rng)
    _, _, at2, _ = world(p2, {i: F.ZERO for i in priv})
    R2 = {}
    for i in priv:
        R2[i] = F.mul(F.sub(terms1[i], F.mul(sel, at2[i])), F.inv(cm_of(es, ext_round[i])))
    sig2, rd2, at2b, fin2 = world(p2, R2)
    admissible2 = kind == "Private" or F.iszero(sig2)
    claim_T2 = sig2 if kind == "Private" else F.ZERO
    T1 = flat(claim_T1, rd1)
    T2 = flat(claim_T2, rd2)
    rows = R_rows(N, d, chal)
    target = [F.mul(F.sub(x, y), F.inv(c)) for x, y in zip(T1, T2)]
    delta = F.solve_combination(rows, target)
    res["admissible_world2"] = admissible2
    res["T_prime_in_C_both"] = chain_ok(T1, N, d, chal) and chain_ok(T2, N, d, chal)
    if delta is None:
        res["fibre_constructed"] = False
        return res
    a2 = [F.add(x, y) for x, y in zip(a1, delta)]
    view2 = masked_view(claim_T2, rd2, a2, c, N, d, chal)
    G2 = dot(sum_w(N, d), a2)
    g_true2 = dot(eval_w(chal, d), a2)
    res["fibre_constructed"] = True
    res["same_published_view"] = view2 == view1 and all(fin2[i] == terms1[i] for i in priv)
    res["witness_differs"] = any(p1[i] != p2[i] for i in priv)
    res["same_M_eval_functional"] = g_true2 == g_true1
    res["same_M_gamma_functional"] = F.mul(c, G2) == F.mul(c, G1)
    res["gamma_revealed_by_M"] = kind != "Private"
    ok = res["chain_and_final_check"] and admissible1 and admissible2 and res["same_published_view"] and res["witness_differs"] and res["same_M_eval_functional"]
    if kind != "Private":
        ok = ok and res["same_M_gamma_functional"] and scalar1 == F.mul(c, G1)
    res["pass"] = ok
    return res


# =========================================================================
# main
# =========================================================================


def main():
    t0 = time.time()
    out = {"schema": "zk60-nonlinear-channel-shaped-check/1", "inputs": {}, "stages": {}}
    for k, p in SRC.items():
        out["inputs"][k] = {"path": p, "sha256": sha(p)}
    ir = load_ir()
    for s, (p, _) in ir.items():
        out["inputs"]["ir:" + s] = {"path": p, "sha256": sha(p)}
    out["inputs"]["draft nl_check.json"] = {"path": DRAFT_JSON, "sha256": sha(DRAFT_JSON)}

    # ---------------------------------------------------------------- K0
    out["stages"]["K0_field"] = F.self_test()
    log("K0 field self-test (7 non-residue, u^2 = 7, 100 inverses, a rank-2 3x3):", out["stages"]["K0_field"])

    # ---------------------------------------------------------------- K3 (first: K1 needs the extension rounds)
    dfn = parse_define()
    lay = parse_layout()
    nonzero = [p for p in dfn["pushes"] if p["ext_round"] != "0"]
    k3 = {
        "private_push_calls_a_at_a_slice": len(dfn["pushes"]),
        "pushes_with_nonzero_ext_round": nonzero,
        "other_private_push_calls": dfn["other_private_push_calls"],
        "helper_defaults": dfn["helpers"],
        "direct_Tab_Priv_constructions_in_argument_rs_lines": dfn["direct_priv_constructions_lines"],
        "slot_kinds": lay["kinds"],
        "hosts": lay["hosts"],
    }
    # the bilinear arms' push order and ext rounds, in source order
    bil = {}
    for arm, slot in (("SC_SCORE", lay["sc"]["SC_SCORE"]), ("SC_PV", lay["sc"]["SC_PV"])):
        bil[slot] = [p["ext_round"] for p in dfn["pushes"] if p["arm"] == arm]
    k3["bilinear_push_ext_rounds_in_source_order"] = {str(k): v for k, v in bil.items()}
    # the IR labels of 08 / 09 against the code's coordinate lists (cq, ck, cp, cv)
    want_labels = {
        8: ["(r_t fixed | group summed | r_hj fixed | c)", "(r_j fixed | group summed | c)"],
        9: ["(group summed | r_hj fixed | r_t fixed | s)", "(s | group summed | r_i fixed)"],
    }
    lab_ok = {}
    for s in SHAPES:
        js = ir[s][1]
        for slot in (8, 9):
            sj = js["slots"][slot]
            privs = [t for t in sj["tables"] if kind_of(t) in PRIVATE]
            geq = [t["id"] for t in sj["tables"] if kind_of(t) == "group_eq"]
            ok = len(privs) == 2 and all(w in p["label"] for w, p in zip(want_labels[slot], privs))
            # push order: the group eq (if any) is pushed FIRST, then the two
            # private factors (argument.rs:1320 before :1334 / :1341)
            ok = ok and (geq == [0] if sj["group_bits"] else geq == []) and [p["id"] for p in privs] == ([1, 2] if sj["group_bits"] else [0, 1])
            lab_ok[f"{s}:{slot:02d}"] = ok
    k3["bilinear_ir_labels_match_code_coords_and_push_order"] = lab_ok
    # kinds, hosts: triangular, every private hosted once
    kinds = lay["kinds"]
    tri = all(kinds[h] == "Host" and all(s < h and kinds[s] == "Private" for s in hs) for h, hs in lay["hosts"])
    hosted = [s for _, hs in lay["hosts"] for s in hs]
    once = sorted(hosted) == [i for i in range(23) if kinds[i] == "Private"]
    k3["hosts_triangular"] = tri
    k3["every_private_hosted_exactly_once"] = once
    k3["kind_counts"] = {k: kinds.count(k) for k in ("Private", "Standalone", "Host")}
    k3["functionals"] = 23 + kinds.count("Standalone") + kinds.count("Host")
    # IR kinds agree with SLOT_KINDS at every export
    k3["ir_kinds_agree_with_SLOT_KINDS"] = all(ir[s][1]["slots"][i]["kind"] == kinds[i] for s in SHAPES for i in range(23))
    # table kind vs provenance: every public kind must have a public
    # provenance and every private kind a committed one
    prov_bad = []
    for s in SHAPES:
        for sj in ir[s][1]["slots"]:
            for t in sj["tables"]:
                k = kind_of(t)
                pv = t["prov"]
                good = (k in ("eq", "group_eq") and pv == "eq-of-challenges") or (k in ("pub", "supp") and (pv == "public-from-shape" or pv.startswith("public-with-challenge:"))) or (k in PRIVATE and pv.startswith("committed("))
                if not good:
                    prov_bad.append((s, sj["slot"], t["id"], k, pv))
    k3["table_kind_vs_provenance_mismatches"] = prov_bad
    out["stages"]["K3_sources"] = k3
    log("K3 private pushes via a_at / a_slice:", len(dfn["pushes"]), "; non-zero extension round:", [(p["line"], p["arm"], p["ext_round"]) for p in nonzero])
    log("K3 other private push calls in define:", dfn["other_private_push_calls"], "; helper defaults:", dfn["helpers"])
    log("K3 direct Tab::Priv constructions in argument.rs at lines", dfn["direct_priv_constructions_lines"])
    log("K3 bilinear push ext rounds in source order:", bil, "; IR labels / push order match at", sum(lab_ok.values()), "of", len(lab_ok))
    log("K3 kinds", k3["kind_counts"], "functionals", k3["functionals"], "hosts triangular", tri, "private hosted once", once, "IR kinds agree", k3["ir_kinds_agree_with_SLOT_KINDS"], "kind/provenance mismatches", len(prov_bad))

    # extension-round map per slot: the IR's private tables in push order,
    # rounds from the source parse (08 / 09: [0, 1]; every other push 0)
    def ext_map(sj):
        privs = [t["id"] for t in sj["tables"] if kind_of(t) in PRIVATE]
        if sj["slot"] in bil:
            rs = [int(x) for x in bil[sj["slot"]]]
            assert len(rs) == len(privs)
            return dict(zip(privs, rs))
        return {i: 0 for i in privs}

    # ---------------------------------------------------------------- K1
    k1 = {}
    for s in SHAPES:
        rows = [k1_slot(sj, ext_map(sj)) for sj in ir[s][1]["slots"]]
        k1[s] = rows
        n_prem = sum(r["premise_holds_all_rounds"] for r in rows)
        n_pub = sum(r["public_table_in_every_monomial"] for r in rows)
        n_top = sum(r["top_level_public_factor_every_term"] for r in rows)
        n_deg = sum(r["degree_fits"] for r in rows)
        n_exp = sum(r["product_degree"] == r["export_max_product_degree"] for r in rows)
        n_mono = sum(r["n_monomials"] for r in rows)
        const = [r["slot"] for r in rows if r["constant_monomial_present"]]
        supp_alone = [(r["slot"], r["supp_monomials_without_eq"]) for r in rows if r["supp_monomials_without_eq"]]
        log(f"K1 [{s}] premise (symbolic, every round) {n_prem}/23; public TABLE in every monomial {n_pub}/23 (not: {[r['slot'] for r in rows if not r['public_table_in_every_monomial']]}); top-level public factor {n_top}/23; product degree <= declared {n_deg}/23; = export's figure {n_exp}/23; monomials {n_mono}; constant monomial at {const}; supp monomials without an eq table {supp_alone}")
    out["stages"]["K1_symbolic"] = k1

    # ---------------------------------------------------------------- K2
    k2 = {}
    for s in SHAPES:
        rows = k1[s]
        L = [mask_len(r["main"] + r["ext"], r["d"]) for r in rows]
        C = [(r["main"] + r["ext"]) * r["d"] + 1 for r in rows]
        rv = sum((r["main"] + r["ext"]) * (r["d"] + 1) for r in rows)
        term = {"A": sum(r["private_by_commitment"].get("A", 0) for r in rows), "H": sum(r["private_by_commitment"].get("H", 0) for r in rows), "EP": sum(r["private_by_commitment"].get("EP", 0) for r in rows)}
        nterm = sum(term.values())
        worst = max(L)
        k2[s] = {
            "main_rounds": sum(r["main"] for r in rows),
            "ext_rounds": sum(r["ext"] for r in rows),
            "sum_L": sum(L),
            "sum_dimC": sum(C),
            "kernel": sum(L) - sum(C),
            "worst_L": worst,
            "worst_L_slots": [i for i, x in enumerate(L) if x == worst],
            "budget_ok": all(x + MASK_PADS <= MASK_MSG for x in L),
            "round_values": rv,
            "terminals": term,
            "terminals_total": nterm,
            "words_per_block": 23 + rv + nterm,
            "degree5_slots": [r["slot"] for r in rows if r["d"] == 5],
            "overdeclared_slots": [(r["slot"], r["d"], r["product_degree"]) for r in rows if r["product_degree"] < r["d"]],
            "supp_slots": [r["slot"] for r in rows if r["has_supp"]],
            "group_eq_slots": [r["slot"] for r in rows if r["has_group_eq"]],
            "max_private_tables": max(r["n_private"] for r in rows),
            "max_private_tables_slot": max(rows, key=lambda r: r["n_private"])["slot"],
            "pairs": sorted(set((r["main"] + r["ext"], r["d"]) for r in rows)),
        }
        x = k2[s]
        log(f"K2 [{s}] rounds {x['main_rounds']}+{x['ext_rounds']}; sum L {x['sum_L']}, dim C {x['sum_dimC']}, kernel {x['kernel']}; worst L {x['worst_L']} at {x['worst_L_slots']}; budget ok {x['budget_ok']}; round values {x['round_values']}; terminals {x['terminals']} = {x['terminals_total']}; words {x['words_per_block']}; d=5 at {x['degree5_slots']}; over-declared {x['overdeclared_slots']}; supp slots {x['supp_slots']} ({len(x['supp_slots'])}); group-eq {x['group_eq_slots']}; max private tables {x['max_private_tables']} at slot {x['max_private_tables_slot']}")
    pairs = sorted(set(p for s in SHAPES for p in k2[s]["pairs"]))
    k2["distinct_pairs_all_exports"] = pairs
    out["stages"]["K2_counts"] = k2
    log("K2 distinct (N, d) pairs over the nine exports:", len(pairs), "N", min(p[0] for p in pairs), "..", max(p[0] for p in pairs), "d", min(p[1] for p in pairs), "..", max(p[1] for p in pairs))

    # ---------------------------------------------------------------- K4
    k4 = {"brute_force_values": 0, "pairs": []}
    rng = F.Rng(4040)
    for N in (1, 2, 3, 4):
        for d in (1, 2, 3, 4, 5):
            a = [rng.fp2() for _ in range(mask_len(N, d))]
            rho = [rng.fp2() for _ in range(N)]
            got = apply_R(a, N, d, rho)
            want = brute_rounds(a, N, d, rho)
            assert got == want, (N, d)
            assert dot(eval_w(rho, d), a) == g_eval(a, N, d, rho)
            assert dot(sum_w(N, d), a) == want[0]
            k4["brute_force_values"] += len(got) + 2
    log("K4 per-basis round map vs brute force over the cube:", k4["brute_force_values"], "values equal (N <= 4, d <= 5)")

    def regimes(N, d, rng):
        yield "random", [rng.fp2() for _ in range(N)]
        yield "zeros", [F.ZERO] * N
        yield "ones", [F.ONE] * N
        yield "alt01", [F.e(j % 2) for j in range(N)]
        yield "nodes0..d", [F.e(j % (d + 1)) for j in range(N)]
        yield "base-field random", [(rng.fp(), 0) for _ in range(N)]
        r = rng.fp2()
        yield "all equal", [r] * N

    ok_all = 0
    tot = 0
    for (N, d) in pairs:
        for name, rho in regimes(N, d, F.Rng(N * 100 + d)):
            rows = R_rows(N, d, rho)
            L = len(rows)
            in_c = all(chain_ok(r, N, d, rho) for r in rows)
            # rows are indexed by mask coefficient: R^T. A functional w on the
            # coefficients factors through R iff w lies in the COLUMN space
            # of R^T, i.e. is an extra column adding no rank
            ew = eval_w(rho, d)
            sw = sum_w(N, d)
            rk, (ew_in, sw_in) = F.rank_and_span(rows, [ew, sw])
            good = rk == N * d + 1 == L - 1 and in_c and ew_in and sw_in
            tot += 1
            ok_all += good
            k4["pairs"].append({"N": N, "d": d, "regime": name, "L": L, "rank": rk, "ImR_in_C": in_c, "eval_w_factors": ew_in, "sum_w_factors": sw_in, "ok": good})
    # control: a mask one degree short, published at d + 1 values, does not cover C
    N, d = 23, 5
    r5 = F.Rng(5)
    rho = [r5.fp2() for _ in range(N)]
    short = [basis_rounds(N, d - 1, rho, k) for k in range(mask_len(N, d - 1))]
    # re-evaluate the short mask's round messages at d + 1 nodes: extend each
    # round's d values with the degree-(d-1) polynomial's value at X = d
    padded = []
    for r in short:
        v = [r[0]]
        for j in range(N):
            s = r[1 + j * d : 1 + (j + 1) * d]
            lr = lagrange(d - 1, F.e(d))
            extra = F.ZERO
            for li, si in zip(lr, s):
                extra = F.add(extra, F.mul(li, si))
            v.extend(s + [extra])
        padded.append(v)
    k4["control_short_mask_rank"] = F.rank(padded)
    k4["control_short_mask_dimC"] = N * d + 1
    k4["checks"] = tot
    k4["ok"] = ok_all
    out["stages"]["K4_fact21"] = k4
    log(f"K4 Fact 2.1: {ok_all}/{tot} (pair, regime) cases with rank = N d + 1 = L - 1, Im R in C, eval AND sum weights factoring through R (augmented rank); control: a degree-{d - 1} mask at (23, 5) covers {k4['control_short_mask_rank']} of {N * d + 1}")

    # ---------------------------------------------------------------- K5
    k5 = []
    m125 = ir["m125"][1]["slots"]
    rg = ir["rung_g"][1]["slots"]
    for regime in ("random challenges", "main challenges in {0,1} where allowed"):
        for slot in (8, 9):
            sj = m125[slot]
            rng = F.Rng(800 + slot + (1000 if regime != "random challenges" else 0))
            val = coef_model(rng)
            poly = compile_ir(sj, val)
            n = sj["main_rounds"]
            lkv = sj["group_bits"]
            r_g = [rng.fp2() for _ in range(lkv)]
            geq = eq_cube(r_g, n, 0)
            priv = [t["id"] for t in sj["tables"] if kind_of(t) in PRIVATE]
            em = ext_map(sj)
            pub_tables = {0: geq}
            rho = [rng.fp2() for _ in range(n)]
            if regime != "random challenges":
                rho = [F.e(j % 2) if j % 3 else rng.fp2() for j in range(n)]

            def mk(r, priv=priv, n=n):
                # the folded private factors carry fixed extension-field
                # coordinates (IR 'committed(fixed=..)', field 'ext')
                return {i: [r.fp2() for _ in range(1 << n)] for i in priv}

            pt = [pub_tables.get(i) for i in range(len(sj["tables"]))]
            res = fibre_single(f"m125 slot {slot:02d} full cube 2^{n}, real group eq, 2 extension rounds, {regime}", poly, pt, priv, em, n, sj["declared_degree"], "Private", rng, mk, rho=rho)
            k5.append(res)
            log("K5", res["label"], "->", "PASS" if res.get("pass") else "FAIL", {k: v for k, v in res.items() if k not in ("label",)})
        # Standalone 21 (IO equality) at rung-G, full cube, admissible: plane = endpoint
        sj = rg[21]
        rng = F.Rng(2100 + (1 if regime != "random challenges" else 0))
        poly = compile_ir(sj, coef_model(rng))
        n = sj["main_rounds"]
        tau = [rng.fp2() for _ in range(n)]
        eqt = eq_cube(tau, n, 0)
        rho = [rng.fp2() for _ in range(n)] if regime == "random challenges" else [F.e(j % 2) if j % 3 else rng.fp2() for j in range(n)]

        def mk21(r, n=n):
            x = [((r.r.randrange(256) - 128) % F.P, 0) for _ in range(1 << n)]
            return {1: x, 2: list(x)}

        res = fibre_single(f"rung-G slot 21 (Standalone) full cube 2^{n}, real eq(tau), witness with plane = endpoint, {regime}", poly, [eqt, None, None], [1, 2], {1: 0, 2: 0}, n, sj["declared_degree"], "Standalone", rng, mk21, rho=rho)
        k5.append(res)
        log("K5", res["label"], "->", "PASS" if res.get("pass") else "FAIL", {k: v for k, v in res.items() if k != "label"})
        # Standalone 20 (zero-sum row) at rung-G, full cube, admissible: sum u = 0
        sj = rg[20]
        rng = F.Rng(2000 + (1 if regime != "random challenges" else 0))
        poly = compile_ir(sj, coef_model(rng))
        n = sj["main_rounds"]
        ones = [F.ONE] * (1 << n)
        rho = [rng.fp2() for _ in range(n)] if regime == "random challenges" else [F.e(j % 2) if j % 3 else rng.fp2() for j in range(n)]

        def mk20(r, n=n):
            u = [r.fp2() for _ in range((1 << n) - 1)]
            s = F.ZERO
            for x in u:
                s = F.add(s, x)
            return {1: u + [F.neg(s)]}

        res = fibre_single(f"rung-G slot 20 (Standalone) full cube 2^{n}, the real all-ones table, witness with sum u = 0, {regime}", poly, [ones, None], [1], {1: 0}, n, sj["declared_degree"], "Standalone", rng, mk20, rho=rho)
        k5.append(res)
        log("K5", res["label"], "->", "PASS" if res.get("pass") else "FAIL", {k: v for k, v in res.items() if k != "label"})

    # a control: Standalone slot 21 with an INADMISSIBLE world 2 (one entry
    # of the endpoint off by one) — the fibre must NOT exist with claim 0
    sj = rg[21]
    rng = F.Rng(2199)
    poly = compile_ir(sj, coef_model(rng))
    n = sj["main_rounds"]
    eqt = eq_cube([rng.fp2() for _ in range(n)], n, 0)
    flip = {"count": 0}

    def mk21bad(r, n=n):
        x = [((r.r.randrange(256) - 128) % F.P, 0) for _ in range(1 << n)]
        ep = list(x)
        flip["count"] += 1
        if flip["count"] == 2:
            ep[5] = F.add(ep[5], F.ONE)
        return {1: x, 2: ep}

    res = fibre_single("CONTROL rung-G slot 21, world 2 inadmissible (endpoint differs at one entry)", poly, [eqt, None, None], [1, 2], {1: 0, 2: 0}, n, sj["declared_degree"], "Standalone", rng, mk21bad)
    res["expect"] = "admissible_world2 False; T' of world 2 outside C; no fibre"
    k5.append(res)
    log("K5", res["label"], "->", {k: v for k, v in res.items() if k != "label"})

    # three-slot host coupling at the 125M IR: host 18 (SC_FZC) hosts 11 and
    # 12 with coefficients nu[0], nu[1]; miniature cubes of 3 variables; the
    # host is made ADMISSIBLE by fixing one entry of slot 11's private plane
    # so that sigma_18 = nu0 sigma_11 + nu1 sigma_12. Published scalars and
    # M functionals exactly as argument.rs:522-526 / :603-615 build them.
    n_host_pass = 0
    for shp in RECORD:
        for host in sorted(HOSTED):
            r = host_coupling(ir[shp][1]["slots"], ext_map, host=host, shape=shp)
            k5.append(r)
            n_host_pass += bool(r.get("pass"))
            log("K5", r["label"], "->", "PASS" if r.get("pass") else "FAIL", {k: v for k, v in r.items() if k not in ("label", "host", "shape")})
    log(f"K5 host coupling (all six hosts x rung-G, rung-K4, 125M): {n_host_pass}/{len(RECORD) * len(HOSTED)} pass")
    n_sep = sum(1 for r in k5 if "host" in r and not str(r["label"]).startswith("CONTROL") and r.get("a_private_gamma_would_separate"))
    log(f"K5 D9 control where it means something: a Gamma for a hosted PRIVATE slot would separate the two admissible worlds in {n_sep}/{len(RECORD) * len(HOSTED)} host runs")
    r = host_coupling(ir["m125"][1]["slots"], ext_map, host=17, shape="m125", control="inadmissible world 2")
    r["expect"] = "the host scalar (and its M Gamma) differ between the worlds, and the verifier rejects world 2"
    k5.append(r)
    log("K5", r["label"], "->", {k: v for k, v in r.items() if k not in ("label", "host", "shape")})
    out["stages"]["K5_fibre"] = k5

    # ---------------------------------------------------------------- K8 M geometry at the worst mask length
    out["stages"]["K8_M_pads"] = m_pad_geometry()

    # ---------------------------------------------------------------- K6 compare with the draft's figures
    dj = json.load(open(DRAFT_JSON))
    cmp = {}
    ds2 = dj["stages"]["S2_budgets"]
    for s in SHAPES:
        cmp[s] = {
            "sum_L": (k2[s]["sum_L"], ds2[s]["sum_L"]),
            "sum_dimC": (k2[s]["sum_dimC"], ds2[s]["sum_dimC"]),
            "worst_L": (k2[s]["worst_L"], ds2[s]["worst_L"]),
            "premise": (sum(r["premise_holds_all_rounds"] for r in k1[s]), ds2[s]["premise_holds"]),
            "public_every_monomial": (sum(r["public_table_in_every_monomial"] for r in k1[s]), ds2[s]["public_factor_every_monomial"]),
            "degree_fits": (sum(r["degree_fits"] for r in k1[s]), ds2[s]["degree_fits"]),
            "supp_slots": (len(k2[s]["supp_slots"]), ds2[s]["slots_with_support_indicator"]),
            "group_eq_slots": (len(k2[s]["group_eq_slots"]), ds2[s]["slots_with_group_eq"]),
        }
    agree = all(a == b for s in SHAPES for a, b in cmp[s].values())
    out["stages"]["K6_compare_draft"] = {"per_shape_mine_vs_draft": cmp, "all_agree": agree, "draft_fact21": dj["summary"]["fact21_tight"], "draft_controls": f"{dj['summary']['controls_as_expected']}/{dj['summary']['controls_total']}"}
    log("K6 my figures vs the draft's nl_check.json, nine exports x eight figures: all agree =", agree)

    # ---------------------------------------------------------------- K7 citations and GN-1 markers
    cites = [
        ("sumcheck.rs", 148, 150, "s.len() != degree + 1"),
        ("sumcheck.rs", 189, 274, "pub struct CfsMask"),
        ("sumcheck.rs", 222, 243, "pub fn eval_weights"),
        ("sumcheck.rs", 255, 274, "pub fn round"),
        ("zk.rs", 1094, 1094, "assert_eq!(degree, mask.degree"),
        ("zk.rs", 1096, 1096, "mask.round(prev.len(), prev)"),
        ("zk.rs", 373, 375, "MASK_Q: usize = 256"),
        ("zk.rs", 485, 485, "CfsMask::random"),
        ("zk.rs", 493, 493, "part.len() + MASK_Q <= m"),
        ("zk.rs", 505, 505, "b_re[m] = b_re[0].neg()"),
        ("zk.rs", 521, 521, "fn combined_weights"),
        ("zk.rs", 648, 685, "fn mask_verify_tagged"),
        ("argument.rs", 18, 22, "CONSTRUCTION PREMISE"),
        ("argument.rs", 476, 479, "c.is_zero()"),
        ("argument.rs", 523, 523, "SlotKind::Private => total(&tables, &def.poly).add(c.mul(mask.total()))"),
        ("argument.rs", 525, 525, "SlotKind::Host =>"),
        ("argument.rs", 534, 541, "Tab::Priv(p) if p.ext_round == m"),
        ("argument.rs", 543, 545, "masked_terminal"),
        ("argument.rs", 561, 561, "def.hosted.iter().fold(sp.scalar"),
        ("argument.rs", 565, 579, "Tab::Eq { point, start } => sel.mul(eq_point"),
        ("argument.rs", 586, 588, "e.is_zero() || *e == Fp2::ONE"),
        ("argument.rs", 586, 597, "let cm = es[p.ext_round + 1..]"),
        ("argument.rs", 603, 614, "SlotKind::Private => {}"),
        ("argument.rs", 373, 387, "fn build_claim"),
        ("argument.rs", 695, 695, "self.a_at(plane, rho(0..log), 0)"),
        ("argument.rs", 727, 727, "ext_round: 0"),
        ("argument.rs", 749, 749, "ext_round: 0"),
        ("argument.rs", 1341, 1341, "b.a_at(ids.at(A_KR8), ck, 1)"),
        ("argument.rs", 1367, 1367, "b.a_at(ids.at(A_V8), cv, 1)"),
        ("layout.rs", 885, 885, "pub(crate) const SLOT_KINDS"),
        ("layout.rs", 912, 919, "pub(crate) const HOSTS"),
        ("layout.rs", 929, 929, "N_FUNCTIONALS: usize = 34"),
        ("layout.rs", 930, 930, "M_ROWS: usize = 2 * N_SLOTS + 4"),
        ("layout.rs", 1183, 1185, "fn mask_specs(&self)"),
        ("shape.rs", 71, 72, "INDICATOR_SLOT_DOMAIN"),
        ("shape.rs", 415, 426, "ruling C-4"),
        ("shape.rs", 1139, 1188, "BASE_DEGREE[s] + usize::from(indicator) + usize::from(group_eq)"),
        ("slot_ir.rs", 55, 57, "push order"),
        ("s24_tests.rs", 749, 835, "C-7"),
    ]
    cres = []
    for f, lo, hi, needle in cites:
        lines = open(SRC[f]).read().split("\n")
        seg = "\n".join(lines[lo - 1 : hi])
        cres.append({"file": f, "lines": f"{lo}-{hi}", "needle": needle, "found": needle in seg})
    # slot_ir.rs:515-527: the provenance-not-value rule
    lines = open(SRC["slot_ir.rs"]).read().split("\n")
    seg = "\n".join(lines[514:527])
    cres.append({"file": "slot_ir.rs", "lines": "515-527", "needle": "(challenge value not exported)", "found": ("value" in seg and ("prov" in seg.lower() or "provenance" in seg.lower())), "excerpt": seg[:300]})
    gn1 = {}
    for m in ("m125-run-l12-dense", "m125-capture-dense-l2"):
        p = f"{LANE}/results/zk60_block125m_lane/{m}.done"
        gn1[m] = open(p).read().strip() if os.path.exists(p) else "MISSING"
    lp = f"{LANE}/results/zk60_block125m_lane/m125-run-l12-dense.log"
    if os.path.exists(lp):
        txt = open(lp).read()
        gn1["dense_log_lines_with_4_of_4_groups_live"] = len(re.findall(r"4/4 key-value groups live", txt))
        gn1["dense_log_lines_groups_differ_true"] = len(re.findall(r"groups differ true", txt))
    out["stages"]["K7_citations"] = cres
    out["stages"]["K7_gn1_markers"] = gn1
    bad = [c for c in cres if not c["found"]]
    log(f"K7 draft citations checked: {len(cres) - len(bad)}/{len(cres)} contain the cited text; not found: {[(c['file'], c['lines'], c['needle']) for c in bad]}")
    log("K7 GN-1 markers:", gn1)

    out["elapsed_s"] = round(time.time() - t0, 1)
    log(f"elapsed {out['elapsed_s']} s")
    with open(os.path.join(HERE, "nlc_check.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=str)
    with open(os.path.join(HERE, "nlc_check.log"), "w") as fh:
        fh.write("\n".join(LOG) + "\n")


def rank_fp(rows):
    P = F.P
    m = [list(r) for r in rows]
    rk = 0
    ncol = len(m[0])
    for c in range(ncol):
        piv = None
        for i in range(rk, len(m)):
            if m[i][c] % P:
                piv = i
                break
        if piv is None:
            continue
        m[rk], m[piv] = m[piv], m[rk]
        iv = pow(m[rk][c], P - 2, P)
        m[rk] = [(x * iv) % P for x in m[rk]]
        for i in range(rk + 1, len(m)):
            f = m[i][c] % P
            if f:
                m[i] = [(x - f * y) % P for x, y in zip(m[i], m[rk])]
        rk += 1
    return rk


def m_pad_geometry():
    """Lemma 3.1's use of the pads, at the shaped mask lengths. A mask row's
    512 message values (L_s coefficients, then 256 uniform pads, then zeros,
    zk.rs:494-497) are the row polynomial's values on G_512; M opens it at
    256 points of the coset 7 G_4096 (zk.rs:374-375, 484). The openings are
    uniform whatever the coefficients are iff the 256 x 256 block of the
    G_512 Lagrange basis (pad positions) at the opened points is invertible.
    It is a Cauchy matrix up to non-zero row and column scalings, so it is
    invertible for ANY 256 pad positions — hence for every L_s; this
    evaluates it at L_s = 50 (toy worst), 117 (125M worst), 256 (the C-4
    limit), with a control that has one pad too few."""
    import random as _r

    P = F.P
    w4096 = pow(7, (P - 1) // 4096, P)
    assert pow(w4096, 4096, P) == 1 and pow(w4096, 2048, P) != 1
    w512 = pow(w4096, 8, P)
    g512 = [pow(w512, i, P) for i in range(512)]
    rr = _r.Random(88)
    ks = rr.sample(range(4096), 256)
    zs = [(7 * pow(w4096, k, P)) % P for k in ks]
    coset_disjoint = all(pow(z, 512, P) != 1 for z in zs)
    inv512 = pow(512, P - 2, P)

    def lag(i, z):
        return (g512[i] * (pow(z, 512, P) - 1) % P * inv512 % P * pow((z - g512[i]) % P, P - 2, P)) % P

    res = {"coset_points_outside_G512": coset_disjoint}
    for L in (50, 117, 256):
        M = [[lag(L + i, z) for i in range(256)] for z in zs]
        res[f"rank_pads_at_L{L}"] = rank_fp(M)
    # control: only 255 pad positions (one position of the pad window zero)
    M = [[lag(117 + i, z) for i in range(255)] for z in zs]
    res["control_255_pads_rank"] = rank_fp(M)
    res["ok"] = coset_disjoint and all(res[f"rank_pads_at_L{L}"] == 256 for L in (50, 117, 256)) and res["control_255_pads_rank"] == 255
    log("K8 M pads: opened coset points outside G_512", coset_disjoint, "; rank of the pad block at L = 50 / 117 / 256:", res["rank_pads_at_L50"], res["rank_pads_at_L117"], res["rank_pads_at_L256"], "; control with 255 pads:", res["control_255_pads_rank"])
    return res


# argument.rs: the `hosted` lists of the six host arms (:1164, :1445, :1629,
# :1695, :1566), as (hosted slot, which nu, extra public factor). SC_SZC's
# row-sum host carries nu[0] * per_row with per_row = |Dom::S| / |Dom::Ht|.
HOSTED = {
    2: [(0, 0, None), (1, 1, None)],
    14: [(10, 0, None), (13, 1, None)],
    15: [(5, 0, None), (9, 1, None)],
    16: [(6, 0, None), (7, 1, None)],
    17: [(4, 0, "per_row"), (8, 1, None)],
    18: [(11, 0, None), (12, 1, None)],
}


def host_coupling(slots, ext_map, host=18, shape="m125", control=None):
    """a host with its two hosted Private slots (IR of `shape`), miniature
    cubes of 3 variables, the protocol's kinds, admissibility enforced"""
    rng = F.Rng(1812 + 7 * host + len(shape))
    val = coef_model(rng)
    hs_list = HOSTED[host]
    ids = {host: None, hs_list[0][0]: None, hs_list[1][0]: None}
    polys = {s: compile_ir(slots[s], val) for s in ids}
    n = 3
    # per_row from the real schedule: |S| / |Ht| = 2^(main(SC_SZC) - main(eq(p_ht)))
    per_row = None
    if host == 17:
        ht = [t for t in slots[17]["tables"] if t["label"] == "eq(p_ht)"][0]
        lht = int(re.fullmatch(r"eq\(start=0,\|point\|=(\d+)\)", ht["kind"]).group(1))
        per_row = F.e(1 << (slots[17]["main_rounds"] - lht))
    info = {}
    for s in ids:
        sj = slots[s]
        priv = [t["id"] for t in sj["tables"] if kind_of(t) in PRIVATE]
        info[s] = {"sj": sj, "priv": priv, "em": ext_map(sj), "d": sj["declared_degree"], "N": n + sj["extension_rounds"], "ntab": len(sj["tables"])}
    # public tables fixed across worlds (random stand-ins of the right size)
    pubs = {s: {i: [rng.fp2() for _ in range(1 << n)] for i in range(info[s]["ntab"]) if i not in info[s]["priv"]} for s in ids}
    chal = {s: [rng.fp2() for _ in range(n)] + [rng.fp2_not01() for _ in range(slots[s]["extension_rounds"])] for s in ids}
    cs = {s: rng.fp2_nz() for s in ids}
    # nu[0], nu[1] as the host polynomial uses them (the same coef_model labels)
    nus = [val({"prov": "chal:nu[0]"}), val({"prov": "chal:nu[1]"})]
    hosted = []
    for hs, k, extra in hs_list:
        coef = nus[k]
        if extra == "per_row":
            coef = F.mul(coef, per_row)
        hosted.append((hs, coef))

    def sigma_of(s, tabs):
        p = polys[s]
        acc = F.ZERO
        for x in range(1 << n):
            acc = F.add(acc, p([tabs[i][x] for i in range(info[s]["ntab"])]))
        return acc

    def defect(tabs):
        """sigma_host - sum coef sigma_hs: zero iff the host relation holds"""
        v = sigma_of(host, tabs[host])
        for hs, coef in hosted:
            v = F.sub(v, F.mul(coef, sigma_of(hs, tabs[hs])))
        return v

    def make_world(r, fix=True):
        tabs = {}
        for s in ids:
            t = {}
            for i in range(info[s]["ntab"]):
                t[i] = pubs[s][i] if i in pubs[s] else [r.fp2() for _ in range(1 << n)]
            tabs[s] = t
        if not fix:
            return tabs
        # admissibility: find ONE private table entry (host's or hosted's) in
        # which the defect is affine and non-constant, and solve for it
        for s in [hosted[0][0], hosted[1][0], host]:
            for i in info[s]["priv"]:
                for x in range(1 << n):
                    keep = tabs[s][i][x]
                    fv = []
                    for tv in (F.ZERO, F.ONE, F.e(2)):
                        tabs[s][i][x] = tv
                        fv.append(defect(tabs))
                    affine = F.sub(F.add(fv[2], fv[0]), F.add(fv[1], fv[1])) == F.ZERO
                    slope = F.sub(fv[1], fv[0])
                    if affine and not F.iszero(slope):
                        tabs[s][i][x] = F.mul(F.neg(fv[0]), F.inv(slope))
                        return tabs
                    tabs[s][i][x] = keep
        raise RuntimeError("no affine entry to make the host admissible")

    def transcripts(tabs, Rs):
        outp = {}
        for s in ids:
            d = info[s]["d"]
            es = chal[s][n:]
            exts = [[Rs[s][i] if (i in info[s]["priv"] and info[s]["em"][i] == m) else F.ZERO for i in range(info[s]["ntab"])] for m in range(len(es))]
            outp[s] = honest_unmasked(polys[s], [tabs[s][i] for i in range(info[s]["ntab"])], chal[s][:n], es, exts, d)
        return outp

    r1 = F.Rng(1)
    tabs1 = make_world(r1)
    Rs1 = {s: {i: r1.fp2() for i in info[s]["priv"]} for s in ids}
    T1 = transcripts(tabs1, Rs1)
    def admissible(T):
        v = T[host][0]
        for hs, coef in hosted:
            v = F.sub(v, F.mul(coef, T[hs][0]))
        return F.iszero(v)

    admissible1 = admissible(T1)
    masks1 = {s: [r1.fp2() for _ in range(mask_len(info[s]["N"], info[s]["d"]))] for s in ids}

    def published(T, masks):
        pubv = {}
        G = {s: dot(sum_w(info[s]["N"], info[s]["d"]), masks[s]) for s in ids}
        # argument.rs:522-526: Private sigma + c G; Host c G - sum coef c_hs G_hs
        for hs, _ in hosted:
            pubv[("scalar", hs)] = F.add(T[hs][0], F.mul(cs[hs], G[hs]))
        h = F.mul(cs[host], G[host])
        for hs, coef in hosted:
            h = F.sub(h, F.mul(F.mul(coef, cs[hs]), G[hs]))
        pubv[("scalar", host)] = h
        for s in ids:
            N, d = info[s]["N"], info[s]["d"]
            Ra = apply_R(masks[s], N, d, chal[s])
            rounds = flat(F.ZERO, T[s][1])[1:]
            pubv[("rounds", s)] = [F.add(x, F.mul(cs[s], y)) for x, y in zip(rounds, Ra[1:])]
            pubv[("terms", s)] = [T[s][3][i] for i in info[s]["priv"]]
        # M functionals (argument.rs:603-615): eval for every slot; the host's
        # Gamma = c_h G_h - sum coef c_hs G_hs; no Gamma for a Private slot
        for s in ids:
            pubv[("M eval", s)] = dot(eval_w(chal[s], info[s]["d"]), masks[s])
        pubv[("M host gamma", host)] = h
        return pubv

    def verifier(P, T):
        """each slot's chain from its claimed sum (host: scalar_h + sum coef
        scalar_hs, argument.rs:561) and the final identity
        (fin - poly(vals)) / c = the M eval functional (argument.rs:579)"""
        ok = True
        for s in ids:
            N, d = info[s]["N"], info[s]["d"]
            claimed = P[("scalar", s)]
            if s == host:
                for hs, coef in hosted:
                    claimed = F.add(claimed, F.mul(coef, P[("scalar", hs)]))
            good, fin = verify_view([claimed] + P[("rounds", s)], N, d, chal[s])
            if not good:
                return False
            es = chal[s][n:]
            sel = F.ONE
            for e2 in es:
                sel = F.mul(sel, F.sub(F.ONE, e2))
            terms = dict(zip(info[s]["priv"], P[("terms", s)]))
            vals = [terms[i] if i in terms else F.mul(sel, mle_eval(pubs[s][i], chal[s][:n])) for i in range(info[s]["ntab"])]
            g = F.mul(F.sub(fin, polys[s](vals)), F.inv(cs[s]))
            ok = ok and g == P[("M eval", s)]
        return ok

    P1 = published(T1, masks1)
    ok = verifier(P1, T1)
    # world 2: independent admissible data, terminals aligned, masks shifted
    r2 = F.Rng(2)
    tabs2 = make_world(r2, fix=(control != "inadmissible world 2"))
    Rs2 = {}
    _T = transcripts(tabs2, {s: {i: F.ZERO for i in info[s]["priv"]} for s in ids})
    for s in ids:
        es = chal[s][n:]
        sel = F.ONE
        for e2 in es:
            sel = F.mul(sel, F.sub(F.ONE, e2))
        Rs2[s] = {}
        for i in info[s]["priv"]:
            Rs2[s][i] = F.mul(F.sub(T1[s][3][i], F.mul(sel, _T[s][2][i])), F.inv(cm_of(es, info[s]["em"][i])))
    T2 = transcripts(tabs2, Rs2)
    admissible2 = admissible(T2)
    masks2 = {}
    solved = True
    for s in ids:
        N, d = info[s]["N"], info[s]["d"]
        A = flat(T1[s][0], T1[s][1])
        B = flat(T2[s][0], T2[s][1])
        target = [F.mul(F.sub(x, y), F.inv(cs[s])) for x, y in zip(A, B)]
        dl = F.solve_combination(R_rows(N, d, chal[s]), target)
        if dl is None:
            solved = False
            break
        masks2[s] = [F.add(x, y) for x, y in zip(masks1[s], dl)]
    label = f"{shape} IR, host {host:02d} hosting {hosted[0][0]:02d} and {hosted[1][0]:02d}, miniature 2^3 cubes, admissible by construction, scalars and M functionals as the code builds them"
    if control:
        label = f"CONTROL ({control}) " + label
    res = {"label": label, "host": host, "shape": shape, "admissible_world1": admissible1, "admissible_world2": admissible2, "verifier_accepts_world1": ok, "fibre_constructed": solved}
    if solved:
        P2 = published(T2, masks2)
        diff = [str(k) for k in P1 if P1[k] != P2[k]]
        res["published_items_that_differ"] = diff
        res["verifier_accepts_world2"] = verifier(P2, T2)
        res["witness_differs"] = any(tabs1[s][i] != tabs2[s][i] for s in ids for i in info[s]["priv"])
        # the D9 control, done where it means something: had the code put a
        # Gamma = c_hs G_hs for a HOSTED PRIVATE slot into M, it would
        # separate the two admissible worlds (their private sums differ)
        res["a_private_gamma_would_separate"] = any(
            F.mul(cs[hs], dot(sum_w(info[hs]["N"], info[hs]["d"]), masks1[hs])) != F.mul(cs[hs], dot(sum_w(info[hs]["N"], info[hs]["d"]), masks2[hs])) for hs, _ in hosted
        )
        res["pass"] = admissible1 and admissible2 and ok and res["verifier_accepts_world2"] and not diff and res["witness_differs"]
    else:
        res["pass"] = False
    return res


if __name__ == "__main__":
    main()
