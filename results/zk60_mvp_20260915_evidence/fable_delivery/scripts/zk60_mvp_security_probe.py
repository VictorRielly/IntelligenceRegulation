#!/usr/bin/env python3
"""Executable checks behind docs/zkmatrix-poc/ZK60_MVP_SECURITY_DECISION.md.

The decision memo proposes ONE simulator for the fresh-IO FFN `/2` profile:
the honest prover run on the all-zero valid witness with fresh randomness, in
the joint prepare+prove game (the simulator issues the endpoint roots). It
programs no oracle point at all. Its correctness reduces to a fixed-challenge
statement checked here channel by channel on the round-22 captures:

  every public observation of an accepted receipt has a preimage under the
  zero witness with the SAME free dimension as under the real witness.

The adaptive lift (fixed-challenge kernels -> the adaptive transcript) is the
sequential-kernel induction stated in the memo; it is an argument about the
honest prover's Markov structure, not a random-oracle programming step, and it
is NOT "checked" by this tool. Nothing here produces a receipt the real BLAKE3
verifier accepts, and nothing here is whole-proof privacy acceptance.

Read-only inputs: pinned Rust sources at HEAD, the round-22 manifest, and (if
readable) the four capture triplets. No witness, mask, pad, salt or seed is read.
"""
import argparse
import hashlib
import importlib.util
import json
import secrets
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import zk60_fable_cfs_channel as C  # noqa: E402  (FA6's exact CFS arithmetic)

P, ZERO, ONE = C.P, C.ZERO, C.ONE
MANIFEST = ROOT / "results/zk60_round22_captures.json"
DEFAULT_CAPTURES = Path("/home/victor/IntelligenceRegulation/results/zk60_round22_captures")
IO_N, IO_D = 10, 2


class ProbeError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise ProbeError(message)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


# ---------------------------------------------------------------------------
# 1. Source pins: the analysis is about HEAD, and HEAD is the capture producer.
# ---------------------------------------------------------------------------
EXTRA_SOURCES = [
    "hashline/src/zk_ffn_fresh_poc.rs",
    "hashline/src/zk_ffn_io_diagnostic.rs",
    "zkp-core/src/merkle.rs",
    "zkp-core/src/rng.rs",
    "zkp-core/src/field.rs",
]


def check_source_pins():
    manifest = json.loads(MANIFEST.read_text())
    pinned = manifest["source_sha256"]
    rows, all_ok = [], True
    for rel, want in pinned.items():
        got = sha256(ROOT / rel)
        rows.append(dict(path=rel, manifest=want, head=got, match=got == want))
        all_ok &= got == want
    extra = {rel: sha256(ROOT / rel) for rel in EXTRA_SOURCES}
    return dict(manifest_source_commit=manifest["source_commit"], manifest_sha256=sha256(MANIFEST),
                pinned=rows, all_pinned_match=all_ok, unpinned_head_sha256=extra)


# ---------------------------------------------------------------------------
# 2. Schedule order: no challenge is squeezed before the fresh A root, the /2
#    entry point takes an OS-seeded RNG, and the seeded config path is unreachable.
# ---------------------------------------------------------------------------
def _fn_body(text, name):
    """The source text of `fn name(` up to the closing brace at its own indentation."""
    start = text.index(f"fn {name}(")
    line_start = text.rfind("\n", 0, start) + 1
    prefix = text[line_start:start]
    indent = len(prefix) - len(prefix.lstrip(" "))
    close = "\n" + " " * indent + "}"
    at = start
    while True:
        at = text.index(close, at + 1)
        after = text[at + len(close):at + len(close) + 1]
        if after in ("", "\n"):
            break
    return text[start:at + len(close)], text.count("\n", 0, start) + 1


def _lines_with(body, line0, needle):
    return [line0 + i for i, line in enumerate(body.splitlines()) if needle in line]


def check_schedule_order():
    zk = (ROOT / "hashline/src/zk.rs").read_text()
    io = (ROOT / "hashline/src/zk_ffn_fresh_io.rs").read_text()
    body, l0 = _fn_body(zk, "prepare_layer_zk_v3_inner")
    a_root = _lines_with(body, l0, 'absorb_com(tr, b"A"')
    m_root = _lines_with(body, l0, 'tr.absorb(b"M"')
    challenges = _lines_with(body, l0, "tr.challenge_")
    require(len(a_root) == 1 and len(m_root) == 1 and challenges, "prepare_layer_zk_v3_inner landmarks")
    first_challenge = min(challenges)
    require(a_root[0] < m_root[0] < first_challenge, "a challenge precedes the fresh A/M roots")
    require("cfg.rng(" not in body and "layer_rng(" not in body and "ZkRng::new(" not in body,
            "seeded RNG reachable inside prepare_layer_zk_v3_inner")
    require("rng: ZkRng" in body.splitlines()[0], "prepare_layer_zk_v3_inner does not take the caller's RNG")
    # `/2` entry: ExpectedIo absorbed, no challenge, fresh OS stream, seed None.
    tbody, tl0 = _fn_body(io, "transcript")
    require("challenge" not in tbody and 'absorb(b"expected-IO"' in tbody, "io::transcript shape")
    pbody, pl0 = _fn_body(io, "prepare")
    require("ZkRng::from_os(PROFILE)" in pbody and "seed: None" in pbody and "tr.challenge_" not in pbody,
            "io::prepare randomness/seed/challenge shape")
    fbody, fl0 = _fn_body(io, "finish")
    finish_challenges = _lines_with(fbody, fl0, "challenge_fp2")
    require(finish_challenges, "finish draws IO challenges")
    ep_body, el0 = _fn_body((ROOT / "hashline/src/private_seam.rs").read_text(), "prepare")
    require("ZkRng::from_os(DOMAIN)" in ep_body, "endpoint preparation does not use fresh OS entropy")
    return dict(zk_rs=dict(prepare_layer_zk_v3_inner_line=l0, a_root_absorb_line=a_root[0],
                           m_root_absorb_line=m_root[0], first_challenge_line=first_challenge,
                           challenge_lines=challenges, seeded_rng_reachable=False),
                zk_ffn_fresh_io_rs=dict(transcript_line=tl0, prepare_line=pl0, finish_line=fl0,
                                        finish_challenge_lines=finish_challenges),
                private_seam_rs=dict(prepare_line=el0, os_entropy=True),
                every_challenge_follows_fresh_a_root=True)


# ---------------------------------------------------------------------------
# 3. Refusal inventory of the /2 prover path (what an observer can see fail).
#    Each row names a source line that MUST contain the snippet; the class is
#    the memo's classification, verified here only as a source binding.
# ---------------------------------------------------------------------------
REFUSALS = [
    ("hashline/src/zk_ffn_fresh_io.rs", 'return Err("FFN IO: expected endpoint root mismatch"', "public-policy"),
    ("hashline/src/zk_ffn_fresh_io.rs", 'return Err("FFN IO: zero terminal mask challenge; discard attempt"', "challenge-only"),
    ("hashline/src/zk_ffn_fresh_io.rs", ".ok_or(\"FFN IO: missing mask allocation\")", "static-layout"),
    ("hashline/src/zk_ffn_fresh_io.rs", 'map_err(|e| format!("FFN IO randomness: {e}"))', "entropy-failure"),
    ("hashline/src/zk_ffn_fresh_poc.rs", 'return Err("zero CFS mask challenge; discard attempt"', "challenge-only"),
    ("hashline/src/zk_ffn_fresh_poc.rs", 'return Err("degenerate table mask row coordinate; discard attempt"', "challenge-only"),
    ("hashline/src/zk_ffn_fresh_poc.rs", '.ok_or("zero terminal mask challenge; discard attempt")', "challenge-only"),
    ("hashline/src/zk_ffn_fresh_poc.rs", 'return Err("mask coefficients do not span Fp2; discard attempt"', "challenge-only"),
    ("hashline/src/zk_ffn_fresh_poc.rs", 'return Err("zero group member coefficient; discard attempt"', "challenge-only"),
    ("hashline/src/zk_ffn_fresh_poc.rs", 'return Err("dependent proximity mask coefficients; discard attempt"', "challenge-only"),
    ("hashline/src/zk_ffn_fresh_poc.rs", 'return Err("fresh FFN PoC witness plane length"', "statement-shape"),
    ("hashline/src/private_seam.rs", 'return Err("seam: wrong length or noncanonical input words"', "input-validity"),
    ("hashline/src/zk.rs", 'assert!(!c.is_zero(), "zero mask challenge: abandon proof attempt")', "challenge-only"),
    ("hashline/src/zk.rs", 'assert_eq!(sk.len(), gk.len(), "masked extension: round length mismatch")', "static-layout"),
    ("hashline/src/zk.rs", "den.par_chunks_mut(4096).for_each(|c| batch_inverse2(c));", "witness-and-challenge (negligible)"),
    ("zkp-core/src/field.rs", 'assert!(self.0 != 0, "inverse of zero");', "witness-and-challenge (negligible)"),
]


def check_refusal_inventory():
    rows = []
    for rel, snippet, cls in REFUSALS:
        lines = (ROOT / rel).read_text().splitlines()
        hits = [i + 1 for i, line in enumerate(lines) if snippet in line]
        require(hits, f"refusal snippet not found: {rel}: {snippet}")
        rows.append(dict(path=rel, lines=hits, snippet=snippet, classification=cls))
    classes = sorted({r["classification"] for r in rows})
    return dict(rows=rows, classes=classes,
                witness_dependent_rows=[r for r in rows if r["classification"].startswith("witness")],
                note="the only witness-dependent prover event is a LogUp denominator alpha - l = 0 (probability <= lookups / 2^128 per proof); every other refusal is a function of public inputs, transcript challenges or entropy availability")


# ---------------------------------------------------------------------------
# 4. External roots are unreachable through the owner API.
# ---------------------------------------------------------------------------
def check_owner_api():
    io = (ROOT / "hashline/src/zk_ffn_fresh_io.rs").read_text()
    seam = (ROOT / "hashline/src/private_seam.rs").read_text()
    ep_struct = io[io.index("pub struct Endpoints {"):]
    ep_struct = ep_struct[:ep_struct.index("}") + 1]
    require("pub " not in ep_struct.replace("pub struct Endpoints", ""), "Endpoints exposes a public field")
    before = io[:io.index("pub struct Endpoints {")].rsplit("\n", 3)[-3:]
    require(not any("derive" in b for b in before), "Endpoints derives a trait")
    pp = seam[:seam.index("pub struct PreparedPlane {")].rsplit("\n", 3)[-3:]
    require(not any("derive" in b for b in pp), "PreparedPlane derives a trait")
    require("pub(crate) fn into_ffn_endpoint(self" in seam, "into_ffn_endpoint does not consume")
    require(seam.count("PreparedPlane {") == 2, "PreparedPlane constructed outside prepare_with_rng")
    require("pub fn from_roots(" in io and "pub fn finish(mut self, endpoints: Endpoints)" in io, "policy/finish signatures")
    require('return Err("FFN IO: expected endpoint root mismatch".into())' in io, "root equality check missing")
    return dict(endpoints_no_pub_fields=True, endpoints_no_derive=True, prepared_plane_no_derive=True,
                prepared_plane_constructed_only_by_prepare=True, finish_consumes_owner=True,
                from_roots_is_public=True, finish_requires_root_equality=True,
                conclusion="a policy may NAME arbitrary roots, but an accepting receipt needs the in-process owner that prepared them; no import/export path exists")


# ---------------------------------------------------------------------------
# 5. Exact F_{p^2} linear algebra for the zero-witness preimage of an IO argument.
# ---------------------------------------------------------------------------
def solve(rows, rhs):
    """Return (particular solution, kernel dimension) or None if inconsistent."""
    require(len(rows) == len(rhs) and rows, "linear system shape")
    n = len(rows[0])
    aug = [list(r) + [b] for r, b in zip(rows, rhs)]
    red, pivots = C.f2_rref(aug)
    if n in pivots:
        return None
    x = [ZERO] * n
    for row, p in zip(red, pivots):
        x[p] = row[n]
    return x, n - len(pivots)


def eq_point(tau, rho):
    acc = ONE
    for t, r in zip(tau, rho):
        acc = C.f2_mul(acc, C.f2_add(C.f2_mul(t, r), C.f2_mul(C.f2_sub(ONE, t), C.f2_sub(ONE, r))))
    return acc


def io_zero_witness_system(arg):
    """Equations on the 22 slot coefficients under the all-zero data planes.

    For zero data every round polynomial before the extension is pure mask,
    and the extension round is x(1-x)*eq(tau,rho)*(ext_A - ext_E) plus mask,
    where ext_i = terminal_i / e because the zero plane folds to 0.
    """
    rho = [tuple(x) for x in arg["rho"]]
    tau = [tuple(x) for x in arg["tau"]]
    c = tuple(arg["c"])
    require(len(rho) == IO_N and len(tau) == IO_N - 1, "IO argument geometry")
    e = rho[-1]
    require(c != ZERO and e != ZERO, "refused IO challenge")
    eq = eq_point(tau, rho[:-1])
    m1, m2 = (tuple(x) for x in arg["terminals"])
    delta = C.f2_mul(C.f2_sub(m1, m2), C.f2_inv(e))
    rows, rhs = [], []
    for j in range(IO_N):
        weights = C.cfs_round_weights(IO_N, IO_D, j, rho[:j])
        for x in range(IO_D + 1):
            rows.append([C.f2_mul(c, w) for w in weights[x]])
            h = tuple(arg["rounds"][j][x])
            if j == IO_N - 1:
                xv = (x, 0)
                f0 = C.f2_mul(C.f2_mul(C.f2_mul(xv, C.f2_sub(ONE, xv)), eq), delta)
                h = C.f2_sub(h, f0)
            rhs.append(h)
    rows.append([C.f2_mul(c, w) for w in C.cfs_sum_weights(IO_N, IO_D)])
    rhs.append(tuple(arg["gamma"]))
    rows.append(C.cfs_eval_weights(rho, IO_D))
    rhs.append(tuple(arg["mask_eval"]))
    return rows, rhs, dict(delta=delta, eq=eq, ext=[C.f2_mul(m1, C.f2_inv(e)), C.f2_mul(m2, C.f2_inv(e))])


def zero_witness_io_argument(arg, coeffs, ext):
    """Re-run the honest IO argument on zero data with the given slot mask/pair values."""
    rho = [tuple(x) for x in arg["rho"]]
    tau = [tuple(x) for x in arg["tau"]]
    c = tuple(arg["c"])
    e = rho[-1]
    eq = eq_point(tau, rho[:-1])
    rounds = []
    for j in range(IO_N - 1):
        rounds.append([C.f2_mul(c, g) for g in C.cfs_round(coeffs, IO_N, IO_D, j, rho[:j])])
    g9 = C.cfs_round(coeffs, IO_N, IO_D, IO_N - 1, rho[:-1])
    last = []
    for x in range(IO_D + 1):
        xv = (x, 0)
        f0 = C.f2_mul(C.f2_mul(C.f2_mul(xv, C.f2_sub(ONE, xv)), eq), C.f2_sub(ext[0], ext[1]))
        last.append(C.f2_add(f0, C.f2_mul(c, g9[x])))
    rounds.append(last)
    return dict(side=arg["side"], slot=arg["slot"], tau=[list(t) for t in tau], c=list(c),
                rho=[list(r) for r in rho], gamma=list(C.f2_mul(c, C.cfs_total(coeffs, IO_N, IO_D))),
                terminals=[list(C.f2_mul(e, ext[0])), list(C.f2_mul(e, ext[1]))],
                mask_eval=list(C.cfs_eval(coeffs, rho, IO_D)),
                rounds=[[list(x) for x in r] for r in rounds])


def io_zero_witness_preimage(arg):
    rows, rhs, aux = io_zero_witness_system(arg)
    found = solve(rows, rhs)
    if found is None:
        return dict(preimage_exists=False)
    coeffs, kernel = found
    rebuilt = zero_witness_io_argument(arg, coeffs, aux["ext"])
    same = all(rebuilt[k] == arg[k] for k in ("gamma", "terminals", "mask_eval", "rounds"))
    require(same, "zero-witness rebuild disagrees with the captured argument")
    return dict(preimage_exists=True, kernel_dim_fp2=kernel, equations=len(rows), unknowns=C.cfs_len(IO_N, IO_D),
                rebuilt_argument_identical=True)


def io_negative_controls(arg):
    """Corruptions that must leave the zero-witness system inconsistent."""
    import copy
    out = []
    for name, path in (("round", ("rounds", 3, 1)), ("final round", ("rounds", 9, 2)),
                       ("mask_eval", ("mask_eval",)), ("gamma", ("gamma",)), ("terminal", ("terminals", 0))):
        obj = copy.deepcopy(arg)
        target = obj
        for key in path:
            target = target[key]
        target[0] = (target[0] + 1) % P
        rows, rhs, _ = io_zero_witness_system(obj)
        out.append(dict(corrupted=name, preimage_exists=solve(rows, rhs) is not None))
    require(all(not o["preimage_exists"] for o in out), "corrupted IO argument still has a zero-witness preimage")
    return out


# ---------------------------------------------------------------------------
# 6. A synthetic honest IO prover (for tests and for the negative wrong-witness control).
# ---------------------------------------------------------------------------
def _poly(v):
    return C.f2_mul(v[0], C.f2_sub(v[1], v[2]))


def eq_table(tau):
    n = len(tau)
    table = []
    for idx in range(1 << n):
        acc = ONE
        for j, t in enumerate(tau):
            bit = (idx >> (n - 1 - j)) & 1
            acc = C.f2_mul(acc, t if bit else C.f2_sub(ONE, t))
        table.append(acc)
    return table


def _fold(table, r):
    half = len(table) // 2
    return [C.f2_add(table[i], C.f2_mul(r, C.f2_sub(table[i + half], table[i]))) for i in range(half)]


def _round_poly(tables, degree):
    half = len(tables[0]) // 2
    out = []
    for x in range(degree + 1):
        xv = (x, 0)
        acc = ZERO
        for i in range(half):
            v = [C.f2_add(t[i], C.f2_mul(xv, C.f2_sub(t[i + half], t[i]))) for t in tables]
            acc = C.f2_add(acc, _poly(v))
        out.append(acc)
    return out


def honest_io_argument(tau, c, rho, x_plane, in_plane, coeffs, ext, side=0):
    """The /2 IO equality argument on real planes with mask coefficients and pair values."""
    require(len(x_plane) == len(in_plane) == 1 << (IO_N - 1), "IO plane length")
    tables = [eq_table(tau), [(v % P, 0) for v in x_plane], [(v % P, 0) for v in in_plane]]
    rounds = []
    for j in range(IO_N - 1):
        s = _round_poly(tables, IO_D)
        g = C.cfs_round(coeffs, IO_N, IO_D, j, rho[:j])
        rounds.append([C.f2_add(a, C.f2_mul(c, b)) for a, b in zip(s, g)])
        tables = [_fold(t, rho[j]) for t in tables]
    finals = [t[0] for t in tables]
    exts = [ZERO, ext[0], ext[1]]
    g9 = C.cfs_round(coeffs, IO_N, IO_D, IO_N - 1, rho[:-1])
    last = []
    for x in range(IO_D + 1):
        xv = (x, 0)
        v = [C.f2_add(f, C.f2_mul(xv, C.f2_sub(e_, f))) for f, e_ in zip(finals, exts)]
        last.append(C.f2_add(_poly(v), C.f2_mul(c, g9[x])))
    rounds.append(last)
    e = rho[-1]
    terminals = [C.f2_add(f, C.f2_mul(e, C.f2_sub(e_, f))) for f, e_ in zip(finals[1:], exts[1:])]
    return dict(side=side, slot=6 + side, tau=[list(t) for t in tau], c=list(c), rho=[list(r) for r in rho],
                gamma=list(C.f2_mul(c, C.cfs_total(coeffs, IO_N, IO_D))),
                terminals=[list(t) for t in terminals], mask_eval=list(C.cfs_eval(coeffs, rho, IO_D)),
                rounds=[[list(x) for x in r] for r in rounds])


def random_fp2(randbelow=secrets.randbelow):
    return (randbelow(P), randbelow(P))


def synthetic_case(randbelow=secrets.randbelow, equal=True):
    tau = [random_fp2(randbelow) for _ in range(IO_N - 1)]
    rho = [random_fp2(randbelow) for _ in range(IO_N)]
    c = random_fp2(randbelow)
    coeffs = [random_fp2(randbelow) for _ in range(C.cfs_len(IO_N, IO_D))]
    ext = [random_fp2(randbelow), random_fp2(randbelow)]
    x_plane = [randbelow(1 << 16) for _ in range(1 << (IO_N - 1))]
    in_plane = list(x_plane) if equal else [(v + (i == 271)) % P for i, v in enumerate(x_plane)]
    return honest_io_argument(tau, c, rho, x_plane, in_plane, coeffs, ext)


# ---------------------------------------------------------------------------
# 7. Capture-bound checks.
# ---------------------------------------------------------------------------
def m_functional_rank(mask):
    import zk60_io_opening_translation as T
    lengths, offsets, fs, _, _ = T.mask_weights(mask)
    rank = C.f2_rank(fs)
    per_slot = []
    for s, (n, d) in enumerate(mask["specs"]):
        rows = [row[offsets[s]:offsets[s] + lengths[s]] for row in fs if any(x != ZERO for x in row[offsets[s]:offsets[s] + lengths[s]])]
        per_slot.append(dict(slot=s, n_vars=n, degree=d, coefficients=lengths[s], functionals=len(rows),
                             rank_fp2=C.f2_rank(rows) if rows else 0))
    return dict(functionals=len(fs), joint_rank_fp2=rank, joint_full_rank=rank == len(fs),
                coefficient_total=sum(lengths), per_slot=per_slot,
                programmed_points_a_programmable_rom_simulator_would_need=sum(n for n, _ in mask["specs"]),
                programmed_points_zero_witness_simulator=0)


def capture_checks(directory):
    import zk60_endpoint_fibre as F
    import zk60_io_capture_preflight as pre
    import zk60_io_cfs_composition as cfs
    manifest = json.loads(MANIFEST.read_text())
    preflight = pre.run(directory, manifest["source_commit"])
    recorded = {c["proof_sha256"]: c for c in manifest["captures"]["cases"]}
    captures = [F.repeated.O.IoCapture(str(p)) for p in sorted(directory.glob("*.json"))]
    cases = []
    for item in preflight["cases"]:
        rec = recorded[item["proof_sha256"]]
        for key in ("capture_sha256", "capture_bytes", "proof_sha256", "proof_bytes", "expected_policy_sha256"):
            require(item[key] == rec[key], "round-22 manifest mismatch: " + key)
        raw = json.loads(Path(item["path"]).read_bytes())
        cap = next(c for c in captures if c.proof_sha256 == item["proof_sha256"])
        io_rows = []
        for arg in raw["io_arguments"]:
            cfs.replay(arg)
            io_rows.append(dict(side=arg["side"], slot=arg["slot"], **io_zero_witness_preimage(arg),
                                controls=io_negative_controls(arg)))
        endpoints = []
        for role in (r for r in raw["roles"] if r["role"] in ("Input", "Output")):
            view = F.from_capture(role, cap.by_role[role["role"]])
            zero = [[0] * view.n for _ in range(2)]
            sampled = F.sample(view, zero)
            endpoints.append(dict(role=role["role"], distinct_columns=len(set(view.indices)),
                                  zero_witness_preimage=True, message_free_dim=sampled["message_free_dim"],
                                  pad_free_dim=sampled["pad_free_dim"]))
        cases.append(dict(proof_sha256=item["proof_sha256"], privacy=item["privacy"],
                          mask=m_functional_rank(raw["mask"]), io_arguments=io_rows, endpoints=endpoints,
                          ffn_slot_specs=raw["mask"]["specs"][:6]))
    return dict(available=True, preflight_checks=len(preflight["cases"]), cases=cases,
                a_h_w_zero_witness_preimage="not recomputed here; O8 / round-23 disclosed_dim = 0 on the same captures (results/zk60_round22_o8_analysis.json, results/zk60_round23_repeated_view.json) is the rank-equality statement for those roles")


def run(captures):
    result = dict(schema=1, kind="zk60-mvp-security-probe",
                  tool_sha256=sha256(Path(__file__)),
                  dependency_sha256={n: sha256(SCRIPTS / n) for n in (
                      "zk60_fable_cfs_channel.py", "zk60_fable_joint_rank.py", "zk60_endpoint_fibre.py",
                      "zk60_io_cfs_composition.py", "zk60_io_opening_translation.py", "zk60_io_capture_preflight.py")},
                  prior_results_sha256={n: sha256(ROOT / "results" / n) for n in (
                      "zk60_round22_o8_analysis.json", "zk60_round23_repeated_view.json",
                      "zk60_round24_endpoint_fibre.json", "zk60_round25_endpoint_views.json")},
                  source_pins=check_source_pins(), schedule=check_schedule_order(),
                  refusals=check_refusal_inventory(), owner_api=check_owner_api(),
                  blake3_python_module_available=importlib.util.find_spec("blake3") is not None)
    synthetic = synthetic_case()
    import zk60_io_cfs_composition as cfs
    cfs.replay(synthetic)
    wrong = synthetic_case(equal=False)
    try:
        cfs.replay(wrong)
        wrong_replay = "accepted"
    except ValueError as err:
        wrong_replay = str(err)
    rows, rhs, _ = io_zero_witness_system(wrong)
    result["synthetic"] = dict(honest_equal_planes=dict(replay_accepted=True, **io_zero_witness_preimage(synthetic),
                                                       controls=io_negative_controls(synthetic)),
                               unequal_planes=dict(replay=wrong_replay, zero_witness_preimage_exists=solve(rows, rhs) is not None))
    require(wrong_replay != "accepted" and not result["synthetic"]["unequal_planes"]["zero_witness_preimage_exists"],
            "unequal planes must be refused and have no zero-witness preimage")
    if captures is None:
        result["captures"] = dict(available=False, reason="no capture directory supplied")
    else:
        try:
            paths = sorted(Path(captures).glob("*.json"))
        except OSError as err:
            result["captures"] = dict(available=False, reason=f"capture directory unreadable: {err}")
        else:
            if len(paths) != 4:
                result["captures"] = dict(available=False, reason=f"expected four captures, found {len(paths)}")
            else:
                result["captures"] = capture_checks(Path(captures))
    result["decision"] = dict(
        simulator="honest prover on the all-zero valid witness, fresh randomness, joint prepare+prove game",
        oracle_points_programmed=0,
        leaf_or_node_hash_programming_needed=False,
        external_root_game="not a P1 requirement: unreachable through the owner API and vacuous for adversarially chosen roots",
        adaptive_lift="sequential-kernel induction (memo section 3); hypothesis = fixed-challenge witness-independence of every published message given the public past",
        fixed_challenge_evidence=dict(endpoints="round 24 zero-data preimages, re-executed here when captures are readable",
                                      io_cfs="zero-witness preimage solver, this tool",
                                      a_h_w="O8 / round-23 disclosed_dim = 0", m_opening="no data rows; FA6 G2 + joint functional rank, this tool",
                                      ffn_cfs_slots="FA6 G1 surjectivity at stand-in challenges; captured-challenge check is a bounded follow-up"),
        whole_proof_privacy_accepted=False)
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", type=Path, default=DEFAULT_CAPTURES)
    ap.add_argument("--no-captures", action="store_true")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    require(not args.out.exists(), "output already exists; evidence is never overwritten")
    result = run(None if args.no_captures else args.captures)
    with args.out.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    caps = result["captures"]
    print("PASS source/schedule/refusal/owner-API checks; synthetic IO zero-witness preimage OK; captures:",
          "checked" if caps.get("available") else caps.get("reason"))


if __name__ == "__main__":
    main()
