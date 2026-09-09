#!/usr/bin/env python3
"""FA7 tests: the digest-bound capture parser (refusals), the joint model against a
synthetic capture with a KNOWN matrix (recovered rows compared to truth), the
compressed full-width algebra against the dense FA2 tool on random tiny systems,
and the real captures (parity record, Codex's 30 per-column cases reproduced
exactly, the joint numbers).  Reviewer: Claude Fable 5.1, 2026-09-08 session.

    python3 -m unittest discover -s tests -p 'test_zk60_fable_joint_capture.py' -v
"""
import hashlib
import importlib.util
import json
import os
import random
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("joint_capture", ROOT / "scripts/zk60_fable_joint_capture.py")
C = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(C)
R = C.R
P = C.P
ONE, ZERO, U = C.ONE, C.ZERO, C.U

FINAL_DIR = "/tmp/zk60-round11/final-observations"
INITIAL_DIR = "/tmp/zk60-round11/observations"
PARITY = ROOT / "results/zk60_round11_capture_parity.json"
CODEX = ROOT / "results/zk60_round11_captured_rank.json"
RESULTS = ROOT / "results/zk60_fable_fa7_joint_captures.json"


# ----------------------------------------------------------------------------
# a synthetic schema-1 capture from a known matrix (the "prover" side, written
# independently of the model: observations are computed entry by entry)
# ----------------------------------------------------------------------------


def _rand_fp2(rng):
    return (rng.randrange(P), rng.randrange(1, P))


def _rand_fp(rng):
    return rng.randrange(P)


def _fp2l(x):
    return [x[0], x[1]]


def synthetic_capture(seed=1, t=16, privacy="P3", log_cols=8):
    """Returns (capture dict, {role: matrix rows x n}, proof digest)."""
    rng = random.Random(seed)
    shape = {"t": t, "d": 16, "f": 16}
    L = C.layout_dims(shape)
    log_n = min(log_cols, L["log_a_min"])
    n = 1 << log_n
    log_wn = min(log_cols, L["log_wb"])
    table_ls = [max(8, log_n), max(16, log_n), max(7, log_n), max(0, log_n), max(14, log_n), max(6, log_n)]
    q = 12
    proof = hashlib.sha256(f"synthetic-{seed}-{t}-{privacy}".encode()).hexdigest()
    roles = []
    mats = {}
    state = [rng.randrange(256) for _ in range(32)]
    nxt = _rand_fp2(rng)
    order = ["W", "A", "H"] if privacy == "P3" else ["A", "H"]
    for role in order:
        ln = log_wn if role == "W" else log_n
        nn = 1 << ln
        lay = C.expected_claims(role, shape, ln, table_ls, privacy)
        rows = lay["rows"]
        M = [[_rand_fp(rng) for _ in range(nn)] for _ in range(rows)]
        if role == "H":
            ure, uim = lay["zero_sum_pair"]
            for r in (ure, uim):
                M[r][nn - 1] = (-sum(M[r][:nn - 1])) % P
            # make the LogUp identity hold: adjust the first table helper entry
            sp = lay["claims"][lay["sum_claim"]]
            tot = ZERO
            for (off, ls, kind, name, cf) in sp:
                r0, cnt = off // nn, (1 << ls) // nn
                for r in range(r0, r0 + cnt):
                    for j in range(nn):
                        tot = C.f2_add(tot, C.f2_mul(cf, (M[r][j], 0)))
            # tot = current sum; subtract it from the first table helper (coef -1 on re, -u on im)
            t_re = [e for e in sp if e[3] == "h_t[0].re"][0][0] // nn
            t_im = [e for e in sp if e[3] == "h_t[0].im"][0][0] // nn
            M[t_re][0] = (M[t_re][0] + tot[0]) % P
            M[t_im][0] = (M[t_im][0] + tot[1]) % P
        mats[role] = M
        # points and coefficients per claim, group tails in first-occurrence order
        claims_out = []
        group_of = []
        tails = []
        e_f, e_d, e_zs, e_tab = _rand_fp2(rng), _rand_fp2(rng), _rand_fp2(rng), _rand_fp2(rng)
        pts = {"rho_f": [_rand_fp2(rng) for _ in range(L["log_t"] + L["log_fb"])], "rho_d": [_rand_fp2(rng) for _ in range(L["log_t"] + L["log_db"])],
               "p2": [_rand_fp2(rng) for _ in range(L["log_t"] + L["log_db"])], "p5": [_rand_fp2(rng) for _ in range(L["log_t"] + L["log_fb"])],
               "rho_tab": [_rand_fp2(rng) for _ in range(max(ln, 16))], "rho_zs": [_rand_fp2(rng) for _ in range(ln)],
               "p3": [_rand_fp2(rng) for _ in range(L["log_wb"])], "p6": [_rand_fp2(rng) for _ in range(L["log_wb"])]}
        k_gu = _rand_fp2(rng), _rand_fp2(rng)
        k_d = _rand_fp2(rng), _rand_fp2(rng)
        nb_f, nb_d = L["nb_f"], L["nb_d"]
        for k, cl in enumerate(lay["claims"]):
            parts = []
            if role == "A":
                if k < 7 * nb_f:
                    pt, cf = pts["rho_f"], (C.f2_sub(ONE, e_f), e_f)
                elif k < 7 * nb_f + 3 * nb_d:
                    pt, cf = pts["rho_d"], (C.f2_sub(ONE, e_d), e_d)
                elif k < 7 * nb_f + 4 * nb_d:
                    pt, cf = pts["p2"], k_gu
                elif k < 7 * nb_f + 4 * nb_d + nb_f:
                    pt, cf = pts["p5"], k_d
                else:
                    i = k - (7 * nb_f + 4 * nb_d + nb_f)
                    kk = max(ln, 16) - table_ls[i]
                    ext = R.ext_coef(pts["rho_tab"], kk)
                    pt, cf = pts["rho_tab"][kk:], (C.f2_mul(C.f2_sub(ONE, e_tab), ext), C.f2_mul(e_tab, ext))
                is_table = k >= 7 * nb_f + 4 * nb_d + nb_f
                for pi, (off, ls, kind, name) in enumerate(cl):
                    # a table slot's mask block has the slot's shape and carries the full point (build_claims_zk_v3)
                    ppt = pt if (pi == 0 or is_table) else pt[len(pt) - ln:]
                    parts.append({"offset": off, "log_size": ls, "coefficient": _fp2l(cf[pi]), "point": [_fp2l(x) for x in ppt]})
            elif role == "W":
                kb = nb_d * nb_f
                if k < 2 * kb:
                    pt, cf = pts["p3"], k_gu
                else:
                    pt, cf = pts["p6"], k_d
                for pi, (off, ls, kind, name) in enumerate(cl):
                    ppt = pt if pi == 0 else pt[len(pt) - ln:]
                    parts.append({"offset": off, "log_size": ls, "coefficient": _fp2l(cf[pi]), "point": [_fp2l(x) for x in ppt]})
            else:
                if k == lay["sum_claim"]:
                    for (off, ls, kind, name, cf) in cl:
                        parts.append({"offset": off, "log_size": ls, "coefficient": _fp2l(cf), "point": []})
                else:
                    if k < 3 * nb_f:
                        pt, e = pts["rho_f"], e_f
                    elif k < 3 * nb_f + nb_d:
                        pt, e = pts["rho_d"], e_d
                    elif k == lay["zero_sum_claim"]:
                        pt, e = pts["rho_zs"], e_zs
                    else:
                        i = k - (lay["zero_sum_claim"] + 1)
                        kk = max(ln, 16) - table_ls[i]
                        pt, e = pts["rho_tab"][kk:], e_tab
                    ext = ONE if k <= lay["zero_sum_claim"] else R.ext_coef(pts["rho_tab"], max(ln, 16) - table_ls[k - lay["zero_sum_claim"] - 1])
                    a, c = C.f2_mul(C.f2_sub(ONE, e), ext), C.f2_mul(e, ext)
                    cfs = [a, C.f2_mul(a, U), c, C.f2_mul(c, U)]
                    is_table = k > lay["zero_sum_claim"]
                    for pi, (off, ls, kind, name) in enumerate(cl):
                        ppt = pt if pi < 2 else pt[len(pt) - ln:]
                        # the zsum claim's mask parts are single rows at the SAME single-row point;
                        # a table helper's mask blocks have the slot's shape and the full point
                        if k == lay["zero_sum_claim"] or is_table:
                            ppt = pt
                        parts.append({"offset": off, "log_size": ls, "coefficient": _fp2l(cfs[pi]), "point": [_fp2l(x) for x in ppt]})
            tail = tuple(tuple(x) for x in parts[0]["point"][len(parts[0]["point"]) - ln:]) if parts[0]["point"] else ()
            if tail not in tails:
                tails.append(tail)
            group_of.append(tails.index(tail))
            # value = sum_parts coef * sum_r rw[r] sum_j cw[j] M[r][j]
            val = ZERO
            for p in parts:
                r0, cnt = p["offset"] // nn, (1 << p["log_size"]) // nn
                pt_ = [tuple(x) for x in p["point"]]
                rw = R.eq_table_msb(pt_[: p["log_size"] - ln]) if pt_ else [ONE] * cnt
                cw = R.eq_table_msb(pt_[p["log_size"] - ln:]) if pt_ else [ONE] * nn
                s = ZERO
                for i in range(cnt):
                    acc = ZERO
                    for j in range(nn):
                        acc = C.f2_add(acc, C.f2_mul(cw[j], (M[r0 + i][j], 0)))
                    s = C.f2_add(s, C.f2_mul(rw[i], acc))
                val = C.f2_add(val, C.f2_mul(tuple(p["coefficient"]), s))
            claims_out.append({"value": _fp2l(val), "parts": parts})
        groups_out = []
        for gi, tail in enumerate(tails):
            members = [k for k in range(len(claims_out)) if group_of[k] == gi]
            lams = [_rand_fp2(rng) for _ in members]
            vec = [ZERO] * nn
            for k, lam in zip(members, lams):
                for p in claims_out[k]["parts"]:
                    r0, cnt = p["offset"] // nn, (1 << p["log_size"]) // nn
                    pt_ = [tuple(x) for x in p["point"]]
                    rw = R.eq_table_msb(pt_[: p["log_size"] - ln]) if pt_ else [ONE] * cnt
                    f = C.f2_mul(lam, tuple(p["coefficient"]))
                    for i in range(cnt):
                        w = C.f2_mul(f, rw[i])
                        row = M[r0 + i]
                        for j in range(nn):
                            vec[j] = C.f2_add(vec[j], C.f2_mul(w, (row[j], 0)))
            vec = [_fp2l(v) for v in vec] + [_fp2l(_rand_fp2(rng)) for _ in range(q)]
            groups_out.append({"members": members, "lambdas": [_fp2l(x) for x in lams], "key": {"tail": [_fp2l(x) for x in tail], "offset": 0, "len": nn}, "vector": vec})
        rho = [_rand_fp2(rng) for _ in range(rows)]
        prox = [ZERO] * nn
        for r in range(rows):
            for j in range(nn):
                prox[j] = C.f2_add(prox[j], C.f2_mul(rho[r], (M[r][j], 0)))
        prox = [_fp2l(v) for v in prox] + [_fp2l(_rand_fp2(rng)) for _ in range(q)]
        cols = [{"index": rng.randrange(nn * 4), "values": [_rand_fp(rng) for _ in range(rows)], "salt": [rng.randrange(256) for _ in range(32)], "path": []} for _ in range(q)]
        after = [rng.randrange(256) for _ in range(32)]
        after_nxt = _rand_fp2(rng)
        roles.append({"role": role, "params": {"log_cols": ln, "inv_rate": 4, "num_col_checks": q}, "commitment": {"root": [rng.randrange(256) for _ in range(32)], "rows": rows},
                      "before_state": state, "before_next_challenge": _fp2l(nxt), "after_state": after, "after_next_challenge": _fp2l(after_nxt),
                      "claims": claims_out, "groups": groups_out, "proximity_rhos": [_fp2l(x) for x in rho], "proximity_vector": prox, "columns": cols})
        state, nxt = after, after_nxt
    cap = {"schema": 1, "kind": C.KIND, "coverage": C.COVERAGE_F1, "fully_verified": True, "privacy": privacy, "shape": shape, "field_modulus": P,
           "extension_nonresidue": 7, "proof_sha256": proof, "roles": roles}
    return cap, mats, proof


def write_capture(d, cap, name=None):
    path = os.path.join(d, (name or cap["proof_sha256"]) + ".json")
    with open(path, "w") as fh:
        json.dump(cap, fh)
    return path


class _Shared:
    cache = {}

    @classmethod
    def get(cls, seed=1, t=16):
        key = (seed, t)
        if key not in cls.cache:
            cls.cache[key] = synthetic_capture(seed, t)
        return cls.cache[key]


# ----------------------------------------------------------------------------
# parser
# ----------------------------------------------------------------------------


class ParserAcceptsAndRefuses(unittest.TestCase):
    def setUp(self):
        self.cap, self.mats, self.proof = _Shared.get(1, 16)
        self.td = tempfile.TemporaryDirectory()
        self.path = write_capture(self.td.name, self.cap)

    def tearDown(self):
        self.td.cleanup()

    def test_accepts_and_recomputes_the_layout(self):
        cap = C.Capture(self.path)
        self.assertEqual([r.role for r in cap.roles], ["W", "A", "H"])
        A = cap.roles[1]
        self.assertEqual((A.rows, len(A.data_rows), len(A.mask_rows)), (671, 334, 337))
        self.assertEqual(A.layout["prox_row"], 22)
        self.assertEqual([len(g["members"]) for g in A.groups], [7, 3, 1, 1, 6])
        H = cap.roles[2]
        self.assertEqual(H.layout["zero_sum_pair"], (16, 17))
        self.assertEqual(H.row_kind[16], "mask")
        self.assertEqual(H.row_name[18], "u'.re")
        self.assertEqual([len(g["members"]) for g in H.groups], [3, 1, 1, 6, 1])
        self.assertIn("X[0]", A.aliases())
        self.assertEqual(A.aliases()["X[0]"]["claims"], [7, 10])
        self.assertEqual(A.aliases()["h16[0]"]["claims"], [5, 11])
        self.assertEqual(sorted(cap.roles[0].planes()), ["Wd[0][0]", "Wg[0][0]", "Wu[0][0]"])
        # the sha256 of the file is retained
        with open(self.path, "rb") as fh:
            self.assertEqual(cap.file_sha256, hashlib.sha256(fh.read()).hexdigest())

    def _mutated(self, fn, name=None):
        cap = json.loads(json.dumps(self.cap))
        fn(cap)
        return write_capture(self.td.name, cap, name)

    def test_refuses_truncated_json(self):
        with open(self.path, "rb") as fh:
            raw = fh.read()
        bad = os.path.join(self.td.name, "t.json")
        with open(bad, "wb") as fh:
            fh.write(raw[: len(raw) // 2])
        with self.assertRaisesRegex(C.CaptureError, "malformed JSON"):
            C.Capture(bad, require_digest_name=False)

    def test_refuses_wrong_schema_kind_coverage_field(self):
        for fn, msg in (
            (lambda c: c.update(schema=2), "schema"),
            (lambda c: c.update(kind="other"), "kind"),
            (lambda c: c.update(coverage="ffn-v3-function-2"), "coverage"),
            (lambda c: c.update(field_modulus=P - 1), "modulus"),
            (lambda c: c.update(fully_verified=False), "fully_verified"),
            (lambda c: c.update(privacy="P2"), "privacy"),
        ):
            with self.subTest(msg=msg):
                with self.assertRaisesRegex(C.CaptureError, msg):
                    C.Capture(self._mutated(fn))

    def test_refuses_non_integer_or_out_of_range_coefficient(self):
        for bad, msg in (("12", "not an integer"), (1.5, "not an integer"), (True, "not an integer"), (P, "not an integer in"), (-1, "not an integer in")):
            with self.subTest(bad=bad):
                def fn(c, bad=bad):
                    c["roles"][1]["claims"][0]["parts"][0]["coefficient"][0] = bad
                with self.assertRaisesRegex(C.CaptureError, msg):
                    C.Capture(self._mutated(fn))
        # ... also in a lambda, a vector entry and a prox rho
        for fn in (lambda c: c["roles"][1]["groups"][0]["lambdas"][0].__setitem__(1, P + 5),
                   lambda c: c["roles"][1]["groups"][0]["vector"][3].__setitem__(0, "x"),
                   lambda c: c["roles"][2]["proximity_rhos"][7].__setitem__(0, 2.0)):
            with self.assertRaisesRegex(C.CaptureError, "not an integer"):
                C.Capture(self._mutated(fn))

    def test_refuses_claim_outside_the_commitment(self):
        def fn(c):
            role = c["roles"][1]
            rows, n = role["commitment"]["rows"], 1 << role["params"]["log_cols"]
            role["claims"][0]["parts"][1]["offset"] = rows * n
        with self.assertRaisesRegex(C.CaptureError, "exceed the commitment"):
            C.Capture(self._mutated(fn))

    def test_refuses_duplicate_group_membership_and_lambda_mismatch(self):
        def dup(c):
            g = c["roles"][1]["groups"][2]
            g["members"].append(0)
            g["lambdas"].append([1, 2])
        with self.assertRaisesRegex(C.CaptureError, "already a member"):
            C.Capture(self._mutated(dup))

        def dup2(c):
            g = c["roles"][1]["groups"][0]
            g["members"].append(g["members"][0])
            g["lambdas"].append([1, 2])
        with self.assertRaisesRegex(C.CaptureError, "already a member"):
            C.Capture(self._mutated(dup2))

        def mism(c):
            c["roles"][1]["groups"][0]["lambdas"].pop()
        with self.assertRaisesRegex(C.CaptureError, "lambdas for"):
            C.Capture(self._mutated(mism))

    def test_refuses_proof_hash_mismatches(self):
        with self.assertRaisesRegex(C.CaptureError, "differs from the expected"):
            C.Capture(self.path, expected_capture_sha256="00" * 32)
        # the digest name must be the proof digest
        with self.assertRaisesRegex(C.CaptureError, "digest name"):
            C.Capture(self._mutated(lambda c: None, name="a" * 64))
        with self.assertRaisesRegex(C.CaptureError, "proof_sha256"):
            C.Capture(self._mutated(lambda c: c.update(proof_sha256="zz")))

    def test_refuses_tail_and_vector_inconsistencies(self):
        def tail(c):
            p = c["roles"][1]["claims"][3]["parts"][0]
            p["point"][-1][0] = (p["point"][-1][0] + 1) % P
        with self.assertRaisesRegex(C.CaptureError, "column tail differs"):
            C.Capture(self._mutated(tail))

        def vec(c):
            v = c["roles"][0]["groups"][1]["vector"][0]
            v[0] = (v[0] + 1) % P
        with self.assertRaisesRegex(C.CaptureError, "does not reproduce its members' terminals"):
            C.Capture(self._mutated(vec))

        def val(c):
            v = c["roles"][2]["claims"][2]["value"]
            v[1] = (v[1] + 1) % P
        with self.assertRaisesRegex(C.CaptureError, "does not reproduce"):
            C.Capture(self._mutated(val))

    def test_refuses_layout_and_transcript_deviations(self):
        def swap(c):
            a, b = c["roles"][1]["claims"][0]["parts"][0], c["roles"][1]["claims"][1]["parts"][0]
            a["offset"], b["offset"] = b["offset"], a["offset"]
        with self.assertRaisesRegex(C.CaptureError, "not the layout's"):
            C.Capture(self._mutated(swap))

        def chain(c):
            c["roles"][0]["after_state"][0] ^= 1
        with self.assertRaisesRegex(C.CaptureError, "does not connect"):
            C.Capture(self._mutated(chain))

        def sumcoef(c):
            c["roles"][2]["claims"][11]["parts"][0]["coefficient"] = [2, 0]
        with self.assertRaisesRegex(C.CaptureError, "sum-claim coefficient"):
            C.Capture(self._mutated(sumcoef))

        def rows(c):
            c["roles"][2]["commitment"]["rows"] += 1
            for col in c["roles"][2]["columns"]:
                col["values"].append(0)
            c["roles"][2]["proximity_rhos"].append([1, 1])
        with self.assertRaisesRegex(C.CaptureError, "layout has"):
            C.Capture(self._mutated(rows))

        def w_under_p1(c):
            c["privacy"] = "P1"
        with self.assertRaisesRegex(C.CaptureError, "P1 W is a plain public opening"):
            C.Capture(self._mutated(w_under_p1))


# ----------------------------------------------------------------------------
# the joint model on the synthetic capture: truth is known here
# ----------------------------------------------------------------------------


class SyntheticModelAgainstTruth(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cap, cls.mats, cls.proof = _Shared.get(1, 16)
        cls.td = tempfile.TemporaryDirectory()
        cls.path = write_capture(cls.td.name, cls.cap)
        cls.parsed = C.Capture(cls.path)

    @classmethod
    def tearDownClass(cls):
        cls.td.cleanup()

    def role(self, name):
        return next(r for r in self.parsed.roles if r.role == name)

    def test_A_singletons_recover_the_actual_rows_and_the_joint_number_is_2n_plus_4(self):
        A = self.role("A")
        n = A.n
        res = C.RoleModel(A).analyze(plane_columns=(0, -1))
        self.assertEqual(res["per_column"], {"rank_mask": 10, "rank_joint": 12, "disclosed_per_column": 2, "base_rows_per_column": 12})
        self.assertEqual(res["joint"]["disclosed_total"], 2 * n + 4)
        self.assertEqual(res["joint"]["cross_column_increment"], 4)
        self.assertTrue(res["planes"]["X[0]"]["fully_recovered"])
        self.assertTrue(res["planes"]["h16[0]"]["fully_recovered"])
        self.assertEqual(res["planes"]["X[0]"]["isolated_disclosed_dim_at_column"], {"0": 1, str(n - 1): 1})
        for pl in ("g8[0]", "rg[0]", "a16[0]", "u16[0]", "ru[0]", "rh[0]", "z16[0]", "rd[0]"):
            self.assertEqual((res["planes"][pl]["projected_disclosed_dim"], res["planes"][pl]["isolated_disclosed_dim"]), (2, 0), pl)
        for i in range(6):
            self.assertEqual(res["planes"][f"tab[{i}]"]["projected_disclosed_dim"], 0)
        # the recovered rows are the matrix rows (truth known only in this synthetic harness)
        M = self.mats["A"]
        for gi, plane, row in ((2, "X[0]", 7), (3, "h16[0]", 5)):
            rep = C.singleton_functionals(A, gi)
            self.assertEqual(rep["plane"], plane)
            self.assertEqual(rep["data_rows"], [row])
            self.assertTrue(rep["terminal_identity_holds"])
            self.assertEqual(rep["recovered_row_sha256"], C.sha256_values(M[row]))
            self.assertNotEqual(rep["recovered_row_sha256"], C.sha256_values(M[row + 1]))

    def test_W_p3_Wd_recovered_whole_and_the_Wg_Wu_prox_functional(self):
        W = self.role("W")
        n = W.n
        res = C.RoleModel(W).analyze()
        self.assertEqual(res["per_column"]["disclosed_per_column"], 2)
        self.assertEqual(res["joint"]["disclosed_total"], 2 * n + 2)
        self.assertTrue(res["planes"]["Wd[0][0]"]["fully_recovered"])
        rep = C.singleton_functionals(W, 1)
        self.assertEqual(rep["recovered_row_sha256"], C.sha256_values(self.mats["W"][2]))
        # the second per-column functional lives on (Wg, Wu): neither plane is recovered alone
        self.assertFalse(res["planes"]["Wg[0][0]"]["fully_recovered"])
        self.assertEqual(res["planes"]["Wg[0][0]"]["projected_disclosed_dim"], n)

    def test_H_residual_is_the_public_identity_and_needs_the_zero_sum(self):
        H = self.role("H")
        res = C.RoleModel(H).analyze()
        self.assertEqual(res["per_column"]["disclosed_per_column"], 0)
        self.assertEqual(res["joint"]["disclosed_total"], 2)
        self.assertEqual(C.RoleModel(H, zero_sum=False).analyze(planes=False)["joint"]["disclosed_total"], 0)
        with_id = C.RoleModel(H, extras=[C.h_identity_extra(H)])
        self.assertEqual(with_id.rank(with_id.all_gens())["rank"], res["joint"]["rank_joint"])
        for pl, e in res["planes"].items():
            self.assertEqual((e["projected_disclosed_dim"], e["isolated_disclosed_dim"]), (2, 0), pl)
        # the extra observation is recorded with its rows
        self.assertEqual(res["extras"][0]["rows"], [16, 17])

    def test_codex_literal_subset_matches_the_layout_recomputation(self):
        for r in self.parsed.roles:
            cx = C.codex_per_column(r)
            self.assertTrue(cx["classification_equals_layout_recomputation"], r.role)
            self.assertEqual(cx["disclosed_base_functionals_per_column"], {"W": 2, "A": 2, "H": 0}[r.role])
            m = C.RoleModel(r)
            self.assertEqual((cx["rank_mask"], cx["rank_joint"]), (m.rank(m.mask_gens())["block_rank_per_column"], m.rank(m.all_gens())["block_rank_per_column"]))

    def test_two_row_planes_at_T32(self):
        cap, mats, _ = _Shared.get(2, 32)
        with tempfile.TemporaryDirectory() as td:
            parsed = C.Capture(write_capture(td, cap))
        A = next(r for r in parsed.roles if r.role == "A")
        res = C.RoleModel(A).analyze(plane_columns=(0,))
        n = A.n
        self.assertEqual(res["joint"]["disclosed_total"], 2 * n + 4)
        x = res["planes"]["X[0]"]
        self.assertEqual((x["row_count"], x["isolated_disclosed_dim"], x["projected_disclosed_dim"], x["fully_recovered"]), (2, n, n + 2, False))
        self.assertEqual(x["isolated_disclosed_dim_at_column"], {"0": 1})
        rep = C.singleton_functionals(A, 2)
        self.assertEqual(rep["rows_per_functional"], 2)
        self.assertNotIn("recovered_row_sha256", rep)
        # the functional values are sum_r w_r M[r][j] -- checked against truth
        M = mats["A"]
        w = rep["base_weights_w_r"]
        vals = [(w[0] * M[rep["data_rows"][0]][j] + w[1] * M[rep["data_rows"][1]][j]) % P for j in range(n)]
        self.assertEqual(rep["functional_values_sha256"], C.sha256_values(vals))


# ----------------------------------------------------------------------------
# the compressed full-width algebra against the dense FA2 tool (random tiny systems)
# ----------------------------------------------------------------------------


class _Stub:
    """A hand-built RoleObs-like system: random slices, aliasing, multi-row sites, extras."""

    def __init__(self, seed, n=4, rows=9, role="X"):
        rng = random.Random(seed)
        self.role = role
        self.n, self.rows = n, rows
        self.log_n = n.bit_length() - 1
        self.row_kind = ["data" if rng.random() < 0.55 else "mask" for _ in range(rows)]
        self.row_kind[rows - 1] = "prox"
        self.row_name = [f"r{r}" for r in range(rows)]
        self.rho = [_rand_fp2(rng) for _ in range(rows)]
        self.layout = {"zero_sum_pair": None, "prox_row": rows - 1}
        # claims: random slices of 1 or 2 rows (aligned), random coefficient, random row bits
        self.claims = []
        n_claims = rng.randrange(3, 6)
        for k in range(n_claims):
            parts = []
            for _ in range(rng.randrange(1, 3)):
                nrows = rng.choice([1, 1, 2])
                row0 = rng.randrange(0, rows - 1 - nrows + 1)
                rb = nrows.bit_length() - 1
                pt = [_rand_fp2(rng) for _ in range(rb)]
                parts.append({"row0": row0, "nrows": nrows, "coef": _rand_fp2(rng), "rw": R.eq_table_msb(pt) if rb else [ONE], "point": pt, "tail": None})
            self.claims.append({"value": ZERO, "parts": parts, "group": None})
        # groups: random partition, one cw per group
        self.groups = []
        order = list(range(n_claims))
        rng.shuffle(order)
        while order:
            m = rng.randrange(1, min(3, len(order)) + 1)
            mem, order = sorted(order[:m]), order[m:]
            tail = [_rand_fp2(rng) for _ in range(self.log_n)]
            g = {"members": mem, "lambdas": [_rand_fp2(rng) for _ in mem], "tail": tail, "cw": R.eq_table_msb(tail), "vector": None}
            for k in mem:
                self.claims[k]["group"] = len(self.groups)
            self.groups.append(g)
        self.data_rows = [r for r in range(rows) if self.row_kind[r] == "data"]
        self.mask_rows = [r for r in range(rows) if self.row_kind[r] in ("mask", "prox")]

    def planes(self):
        return {f"r{r}": [r] for r in self.data_rows}


def dense_rank(stub, extras, unknown_rows):
    """rank of the dense observation matrix restricted to the unknowns (row in unknown_rows, any column)."""
    n = stub.n
    keep = set(unknown_rows)
    cols = [(r, j) for r in range(stub.rows) for j in range(n) if r in keep]
    idx = {x: i for i, x in enumerate(cols)}
    base = []

    def add(coeffs):
        for ci in (0, 1):
            row = [0] * len(cols)
            for (r, j), v in coeffs.items():
                if r in keep:
                    row[idx[(r, j)]] = (row[idx[(r, j)]] + v[ci]) % P
            base.append(row)

    for g in stub.groups:
        for j in range(n):
            co = {}
            for k, lam in zip(g["members"], g["lambdas"]):
                for p in stub.claims[k]["parts"]:
                    for i in range(p["nrows"]):
                        key = (p["row0"] + i, j)
                        co[key] = C.f2_add(co.get(key, ZERO), C.f2_mul(C.f2_mul(lam, p["coef"]), p["rw"][i]))
            add(co)
    for j in range(n):
        add({(r, j): stub.rho[r] for r in range(stub.rows)})
    for k, c in enumerate(stub.claims):
        cw = stub.groups[c["group"]]["cw"]
        co = {}
        for p in c["parts"]:
            for i in range(p["nrows"]):
                for j in range(n):
                    key = (p["row0"] + i, j)
                    co[key] = C.f2_add(co.get(key, ZERO), C.f2_mul(C.f2_mul(p["coef"], p["rw"][i]), cw[j]))
        add(co)
    for e in extras:
        add({(r, j): cf for r, cf in e["coefs"].items() for j in range(n)})
    return R.rank(base) if cols else 0


class CompressedEqualsDense(unittest.TestCase):
    def test_random_tiny_systems(self):
        for seed in range(12):
            with self.subTest(seed=seed):
                stub = _Stub(seed)
                rng = random.Random(100 + seed)
                extras = []
                if seed % 2:
                    rs = rng.sample(range(stub.rows - 1), 2)
                    extras.append({"name": "extra", "coefs": {rs[0]: ONE, rs[1]: _rand_fp2(rng)}})
                model = C.RoleModel(stub, extras=extras)
                allr = list(range(stub.rows))
                r_all = dense_rank(stub, extras, allr)
                r_mask = dense_rank(stub, extras, stub.mask_rows)
                self.assertEqual(model.rank(model.all_gens())["rank"], r_all)
                self.assertEqual(model.rank(model.mask_gens())["rank"], r_mask)
                res = model.analyze(plane_columns=(0,))
                self.assertEqual(res["joint"]["disclosed_total"], r_all - r_mask)
                for name, rows in stub.planes().items():
                    e = res["planes"][name]
                    self.assertEqual(e["projected_disclosed_dim"], dense_rank(stub, extras, stub.mask_rows + rows) - r_mask, name)
                    self.assertEqual(e["isolated_disclosed_dim"], r_all - dense_rank(stub, extras, [r for r in allr if r not in rows]), name)
                    # column-0 exception: drop only (row, column 0)
                    keep = [(r, j) for r in allr for j in range(stub.n) if not (r in rows and j == 0)]
                    self.assertEqual(e["isolated_disclosed_dim_at_column"]["0"], r_all - dense_rank_cells(stub, extras, keep), name)


def dense_rank_cells(stub, extras, cells):
    """dense rank restricted to an arbitrary set of (row, column) unknowns."""
    n = stub.n
    keep = set(cells)
    cols = sorted(keep)
    idx = {x: i for i, x in enumerate(cols)}
    base = []

    def add(coeffs):
        for ci in (0, 1):
            row = [0] * len(cols)
            for key, v in coeffs.items():
                if key in keep:
                    row[idx[key]] = (row[idx[key]] + v[ci]) % P
            base.append(row)

    for g in stub.groups:
        for j in range(n):
            co = {}
            for k, lam in zip(g["members"], g["lambdas"]):
                for p in stub.claims[k]["parts"]:
                    for i in range(p["nrows"]):
                        key = (p["row0"] + i, j)
                        co[key] = C.f2_add(co.get(key, ZERO), C.f2_mul(C.f2_mul(lam, p["coef"]), p["rw"][i]))
            add(co)
    for j in range(n):
        add({(r, j): stub.rho[r] for r in range(stub.rows)})
    for k, c in enumerate(stub.claims):
        cw = stub.groups[c["group"]]["cw"]
        co = {}
        for p in c["parts"]:
            for i in range(p["nrows"]):
                for j in range(n):
                    key = (p["row0"] + i, j)
                    co[key] = C.f2_add(co.get(key, ZERO), C.f2_mul(C.f2_mul(p["coef"], p["rw"][i]), cw[j]))
        add(co)
    for e in extras:
        add({(r, j): cf for r, cf in e["coefs"].items() for j in range(n)})
    return R.rank(base)


class EchelonAndHelpers(unittest.TestCase):
    def test_echelon_rank(self):
        e = C.Echelon(3)
        self.assertTrue(e.insert([1, 2, 3]))
        self.assertTrue(e.insert([0, 1, 1]))
        self.assertFalse(e.insert([1, 3, 4]))
        self.assertFalse(e.insert([2, 4, 6]))
        self.assertTrue(e.insert([0, 0, 5]))
        self.assertEqual(e.rank, 3)
        self.assertFalse(e.insert([7, 8, 9]))

    def test_sha256_values_is_order_sensitive_and_leaves_no_values(self):
        self.assertNotEqual(C.sha256_values([1, 2]), C.sha256_values([2, 1]))
        self.assertEqual(len(C.sha256_values([(1, 2), (3, 4)])), 64)

    def test_expected_layout_pins_the_tiny_row_counts(self):
        t2 = C.expected_claims("A", {"t": 2, "d": 16, "f": 16}, 5, [8, 16, 7, 5, 14, 6], "P1")
        self.assertEqual((t2["rows"], t2["prox_row"], len(t2["claims"])), (5173, 22, 18))
        h2 = C.expected_claims("H", {"t": 2, "d": 16, "f": 16}, 5, [8, 16, 7, 5, 14, 6], "P1")
        self.assertEqual((h2["rows"], h2["prox_row"], h2["zero_sum_pair"], len(h2["claims"][h2["sum_claim"]])), (10321, 20, (16, 17), 22))
        w2 = C.expected_claims("W", {"t": 2, "d": 16, "f": 16}, 5, [8, 16, 7, 5, 14, 6], "P3")
        self.assertEqual((w2["rows"], w2["prox_row"], w2["claims"][2][0][0]), (28, 27, 512))
        a32 = C.expected_claims("A", {"t": 32, "d": 16, "f": 16}, 8, [8, 16, 8, 8, 14, 8], "P3")
        self.assertEqual((a32["rows"], a32["claims"][10][0][0], a32["claims"][10][0][1]), (681, 3584, 9))
        with self.assertRaisesRegex(C.CaptureError, "P1 W"):
            C.expected_claims("W", {"t": 2, "d": 16, "f": 16}, 5, [8, 16, 7, 5, 14, 6], "P1")


# ----------------------------------------------------------------------------
# the real captures (skipped with a message when the directories are absent)
# ----------------------------------------------------------------------------


@unittest.skipUnless(os.path.isdir(FINAL_DIR) and PARITY.exists(), f"real captures absent ({FINAL_DIR}); the parity/joint regression needs them")
class RealCaptures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parity = C.load_parity(str(PARITY))

    def test_parity_record_binds_the_six_seeded_captures_and_names_are_digests(self):
        for stem, want in self.parity["seeded"].items():
            p = os.path.join(FINAL_DIR, stem + ".json")
            self.assertTrue(os.path.exists(p), stem)
            self.assertEqual(C.sha256_file(p), want, stem)
            if os.path.isdir(INITIAL_DIR):
                self.assertEqual(C.sha256_file(os.path.join(INITIAL_DIR, stem + ".json")), want, stem)
        for name in os.listdir(FINAL_DIR):
            self.assertRegex(name, r"^[0-9a-f]{64}\.json$")

    def test_t2_p3_seeded_capture_joint_numbers(self):
        stem = "6fefcd11df3ec6c55db8dbb99304c855b4ae7a7621a21b812d7f810fb5d60297"
        cap = C.Capture(os.path.join(FINAL_DIR, stem + ".json"), expected_capture_sha256=self.parity["seeded"][stem])
        self.assertEqual((cap.privacy, cap.shape["t"]), ("P3", 2))
        got = {}
        for obs in cap.roles:
            res = C.RoleModel(obs).analyze(plane_columns=(0,))
            got[obs.role] = (res["per_column"]["disclosed_per_column"], res["joint"]["disclosed_total"])
            cx = C.codex_per_column(obs)
            self.assertTrue(cx["classification_equals_layout_recomputation"])
            self.assertEqual(cx["disclosed_base_functionals_per_column"], res["per_column"]["disclosed_per_column"])
            if obs.role == "A":
                self.assertTrue(res["planes"]["X[0]"]["fully_recovered"] and res["planes"]["h16[0]"]["fully_recovered"])
                self.assertEqual(obs.aliases()["X[0]"]["claims"], [7, 10])
                for gi in (2, 3):
                    rep = C.singleton_functionals(obs, gi)
                    self.assertIn("recovered_row_sha256", rep)
                    self.assertTrue(rep["terminal_identity_holds"])
            if obs.role == "W":
                self.assertEqual(res["planes"]["Wd[0][0]"]["isolated_disclosed_dim"], 32)
                self.assertEqual(res["planes"]["Wd[0][0]"]["isolated_disclosed_dim_at_column"]["0"], 1)
                rep = C.singleton_functionals(obs, 1)
                self.assertEqual((rep["rows_per_functional"], rep["functionals"], rep["data_rows"]), (8, 32, list(range(16, 24))))
            if obs.role == "H":
                self.assertEqual(C.RoleModel(obs, zero_sum=False).analyze(planes=False)["joint"]["disclosed_total"], 0)
                wid = C.RoleModel(obs, extras=[C.h_identity_extra(obs)])
                self.assertEqual(wid.rank(wid.all_gens())["rank"], res["joint"]["rank_joint"])
        self.assertEqual(got, {"W": (2, 66), "A": (2, 68), "H": (0, 2)})

    def test_t32_p3_seeded_capture_recovers_the_whole_Wd_plane(self):
        stem = "ac560dde2ee5352d0ef23a228411c19759ce003bb59a6d44678ec7f6ec6f6dfe"
        cap = C.Capture(os.path.join(FINAL_DIR, stem + ".json"), expected_capture_sha256=self.parity["seeded"][stem])
        W = cap.roles[0]
        res = C.RoleModel(W).analyze()
        self.assertEqual((res["per_column"]["disclosed_per_column"], res["joint"]["disclosed_total"]), (2, 514))
        self.assertTrue(res["planes"]["Wd[0][0]"]["fully_recovered"])
        rep = C.singleton_functionals(W, 1)
        self.assertEqual((rep["recovered_entries"], rep["data_rows"]), (256, [2]))
        A = cap.roles[1]
        ra = C.RoleModel(A).analyze()
        self.assertEqual(ra["joint"]["disclosed_total"], 516)
        self.assertEqual((ra["planes"]["X[0]"]["isolated_disclosed_dim"], ra["planes"]["X[0]"]["projected_disclosed_dim"], ra["planes"]["X[0]"]["fully_recovered"]), (256, 258, False))

    @unittest.skipUnless(os.path.isdir(INITIAL_DIR) and CODEX.exists(), "initial captures / Codex record absent")
    def test_codex_thirty_cases_reproduced_exactly(self):
        with open(CODEX) as fh:
            codex = json.load(fh)
        self.assertEqual(len(codex["cases"]), 30)
        seen = 0
        by_file = {}
        for c in codex["cases"]:
            by_file.setdefault(c["proof_sha256"], []).append(c)
        for stem, refs in by_file.items():
            path = os.path.join(INITIAL_DIR, stem + ".json")
            self.assertEqual(C.sha256_file(path), refs[0]["capture_sha256"], stem)
            cap = C.Capture(path, expected_capture_sha256=refs[0]["capture_sha256"])
            for obs in cap.roles:
                ref = next(r for r in refs if r["role"] == obs.role)
                mine = C.codex_per_column(obs)
                for k in ("data_rows", "mask_rows", "base_observation_rows", "rank_mask", "rank_joint", "disclosed_base_functionals_per_column"):
                    self.assertEqual(mine[k], ref[k], (stem[:12], obs.role, k))
                self.assertEqual(ref["message_columns"], obs.n)
                seen += 1
            del cap
        self.assertEqual(seen, 30)

    @unittest.skipUnless(RESULTS.exists(), "results/zk60_fable_fa7_joint_captures.json absent")
    def test_results_file_is_bound_to_this_tool_and_these_captures(self):
        with open(RESULTS) as fh:
            rep = json.load(fh)
        self.assertEqual(rep["tool_sha256"]["zk60_fable_joint_capture.py"], C.sha256_file(str(ROOT / "scripts/zk60_fable_joint_capture.py")), "the results were produced by a different tool version: re-run the analysis")
        self.assertEqual(rep["tool_sha256"]["zk60_fable_joint_rank.py"], C.sha256_file(str(ROOT / "scripts/zk60_fable_joint_rank.py")))
        self.assertEqual(rep["parity_check"]["mismatched"], [])
        self.assertEqual(len(rep["parity_check"]["verified"]), 6)
        self.assertEqual(rep["codex_subset"]["reproduced_exactly"], 30)
        self.assertEqual(rep["refused"], [])
        for c in rep["cases"]:
            p = os.path.join(FINAL_DIR if "final" in c["directories"] else INITIAL_DIR, c["file"])
            self.assertEqual(C.sha256_file(p), c["file_sha256"], c["file"])
        s = rep["summary"]
        self.assertEqual(s["P3/T2/W"]["joint_disclosed"], [66])
        self.assertEqual(s["P3/T32/W"]["joint_disclosed"], [514])
        for key in ("P1/T2/A", "P3/T2/A"):
            self.assertEqual(s[key]["joint_disclosed"], [68])
        for key in ("P1/T32/A", "P3/T32/A"):
            self.assertEqual(s[key]["joint_disclosed"], [516])
        for key in ("P1/T2/H", "P3/T2/H", "P1/T32/H", "P3/T32/H"):
            self.assertEqual(s[key]["joint_disclosed"], [2])
            self.assertEqual(s[key]["per_column_disclosed"], [0])


if __name__ == "__main__":
    unittest.main()
