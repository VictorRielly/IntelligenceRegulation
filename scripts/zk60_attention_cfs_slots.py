#!/usr/bin/env python3
"""ZK60 private attention -- the CFS slot table, the host batching of the private
claimed sums, the M layout and functional order, the R7 extension-round check
and the negative controls (construction doc section 3, items 1-6 of the brief).

Owner: Claude Fable 5.1 (security lane, worktree zk60-mvp-fable), 2026-09-16.

Inputs
  * Opus's inventory record  results/zk60_opus_attention_inventory.json
    -> A2_cfs_slots.P1 / .P3 (twelve slots: slot, name, main_rounds, ext_rounds,
    n_vars, degree, cfs_len, claimed_sum_form).
  * FA6's exact model  scripts/zk60_fable_cfs_channel.py, imported by path:
    Channel, cfs_len, cfs_sum_weights, cfs_eval_weights, system_single,
    analyze_system, f2_rank, Rng and the Fp2 arithmetic.  Nothing is re-derived.

What it does
  1. the eighteen-slot tables for P1 and P3 (Opus's twelve with SC_ATTN_08 split
     into SC_ATTN_08Q/K/V, plus the four slots the FFN has and attention lacks:
     SC_ATTN_TAB (17, 3), SC_ATTN_ZS (9, 2), SC_ATTN_IO_IN / SC_ATTN_IO_OUT (10, 2),
     all public-zero, none hosted or hosting) in the confirmed transcript order;
     L_s + 256 <= 512 asserted per slot;
  2. FA6's criterion on every slot standalone (rank = dim S = N d + 1, image in
     S, leaked 0, kernel 1);
  3. the host systems: a public-zero host zero-check batched with k >= 1 private
     sum slots in the FFN's gu/ZC20 form (each private slot sends one masked
     scalar claim_s = s_s + c_s G_s; the host publishes
     Gamma_host = c_host G_host - sum_i nu_i c_i G_i and its round-0 relation is
     against sum_i nu_i claim_i + Gamma_host); expected rank = dim S =
     sum L - (k + 1), kernel k + 1, leaked 0; the relabelling and f-part checks;
     run for the default mapping and the SC_ATTN_SMHOST alternative;
  4. the M layout (2 rows per slot + b_re, b_im, u_re, u_im) and the
     mask_functionals order in the round-2 tool's FUNCTIONAL_ASSIGNMENT convention;
  5. the R7 exact check on the extension round (one private family vanishes on
     the mask branch when a public factor extends to 0; two private families with
     the public factor == 1 do not in one round and do in two);
  6. the negative controls (c_s = 0, nu_i = 0, extension degree != mask degree,
     the QKV slot unsplit, L_s + 256 > 512, a standalone Sigma functional for a
     hosted slot).

    python3 scripts/zk60_attention_cfs_slots.py \
        --inventory results/zk60_opus_attention_inventory.json \
        --out results/zk60_private_attention_evidence/cfs/zk60_attention_cfs_slots.json \
        [--hosts hosts.json] [--alt-hosts alt.json] [--seed N] [--dump-hosts path]

Exit status 1 when any expectation fails.

Host-mapping JSON (--hosts / --alt-hosts):
    {"variant": "<label>",
     "hosts": {"<host slot>": ["<hosted private slot>", ...], ...},
     "extra_slots": {"<new slot>": {"n_vars": 10, "degree": 2, "ext_rounds": 1,
                                    "name": "...", "insert_after": "SC_ATTN_07"}}}
Every private-sum slot must be hosted exactly once by a public-zero slot (or an
extra slot); a host is never itself hosted; a hosted slot is private.
"""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
CFS_CHANNEL_PATH = HERE / "zk60_fable_cfs_channel.py"

_SPEC = importlib.util.spec_from_file_location("zk60_fable_cfs_channel", CFS_CHANNEL_PATH)
C = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(C)

P = C.P
ONE, ZERO = C.ONE, C.ZERO
f2, f2_add, f2_sub, f2_neg, f2_mul, f2_inv, f2_is_zero = (
    C.f2, C.f2_add, C.f2_sub, C.f2_neg, C.f2_mul, C.f2_inv, C.f2_is_zero)
f2_rank = C.f2_rank
Rng = C.Rng
Channel = C.Channel
cfs_len = C.cfs_len
cfs_sum_weights = C.cfs_sum_weights
cfs_eval_weights = C.cfs_eval_weights
Fp2 = Tuple[int, int]

TOOL = "scripts/zk60_attention_cfs_slots.py"
OWNER = "Claude Fable 5.1, security lane (zk60-mvp-fable), 2026-09-16"
MASK_Q = 256        # pads per coefficient row (zk.rs MASK_Q)
MASK_M = 512        # message positions per coefficient row (G_512)
DEFAULT_SEED = 60

OPUS_TWELVE = [f"SC_ATTN_{i:02d}" for i in range(12)]
PRIVATE_FORM = "derived-from-claims (PRIVATE under a hiding profile)"
PUBLIC_FORM = "public-zero"

# the QKV slot splits into three inner-product slots, one plane evaluation on one domain each
SPLIT = {
    "SC_ATTN_08": [
        ("SC_ATTN_08Q", "Q matmul (QKV split: Q domain)", "2^sh q8 + rq at p_q (acc_q)"),
        ("SC_ATTN_08K", "K matmul (QKV split: KV domain)", "2^sh k8 + rk at p_k (acc_k)"),
        ("SC_ATTN_08V", "V matmul (QKV split: KV domain)", "2^sh v8 + rv at p_v (acc_v)"),
    ]
}
SPLIT_SHAPE = {"P1": (5, 2, 1), "P3": (6, 2, 2)}          # (n_vars, degree, ext_rounds)
TWO_EXT = {"SC_ATTN_09": (5, 3, 2), "SC_ATTN_10": (7, 3, 2)}  # the bilinear slots keep two extension rounds

# the four slots the FFN has and attention lacks today (coordinator, 2026-09-16): public-zero + Gamma, one extension round
ADDED_SLOTS = [
    {"slot": "SC_ATTN_TAB", "name": "LogUp table helper relations (largest table domain)", "n_vars": 17, "degree": 3, "ext_rounds": 1,
     "section": "13 LogUp tables", "source": "construction 4.1 (the FFN's SC_TAB form)", "ext_rationale": "one public factor (eq) extends to 0"},
    {"slot": "SC_ATTN_ZS", "name": "zero-sum claim on the u row", "n_vars": 9, "degree": 2, "ext_rounds": 1,
     "section": "13 LogUp zero-sum row", "source": "construction 4.1 (the FFN's SC_ZSUM form)", "ext_rationale": "the all-ones table extends to 0"},
    {"slot": "SC_ATTN_IO_IN", "name": "/2 IO endpoint equality (x_in)", "n_vars": 10, "degree": 2, "ext_rounds": 1,
     "section": "IO endpoints", "source": "construction 4.2 (the /2 IO mechanism on the attention A)", "ext_rationale": "one public factor (eq) extends to 0"},
    {"slot": "SC_ATTN_IO_OUT", "name": "/2 IO endpoint equality (xres2)", "n_vars": 10, "degree": 2, "ext_rounds": 1,
     "section": "IO endpoints", "source": "construction 4.2 (the /2 IO mechanism on the attention A)", "ext_rationale": "one public factor (eq) extends to 0"},
]

# the confirmed transcript order (coordinator, 2026-09-16), by inventory section:
# 1 SS, 2 norm squares [hosts 1], 8 LM, 7 row sums, 9 Q/K/V, 10 score, 11 PV, 12 Wo, 3 D zc [hosts 12],
# 4 Q zc [hosts 9Q, 11], 5 KV zc [hosts 9K, 9V], 6 softmax zc [hosts 7, 10], TAB, ZS, IO-in, IO-out
TRANSCRIPT_ORDER = [
    "SC_ATTN_00", "SC_ATTN_01", "SC_ATTN_07", "SC_ATTN_06", "SC_ATTN_08Q", "SC_ATTN_08K", "SC_ATTN_08V",
    "SC_ATTN_09", "SC_ATTN_10", "SC_ATTN_11", "SC_ATTN_02", "SC_ATTN_03", "SC_ATTN_04", "SC_ATTN_05",
    "SC_ATTN_TAB", "SC_ATTN_ZS", "SC_ATTN_IO_IN", "SC_ATTN_IO_OUT",
]

DEFAULT_HOSTS = {
    "variant": "default",
    "note": "construction doc section 3.3: each private sum hosted by the zero-check of the plane's own domain",
    "hosts": {
        "SC_ATTN_01": ["SC_ATTN_00"],                   # D^2 (6,3) <- SS row sums
        "SC_ATTN_05": ["SC_ATTN_06", "SC_ATTN_09"],     # S zero-check (12,5) <- row sums, score
        "SC_ATTN_03": ["SC_ATTN_08Q", "SC_ATTN_10"],    # Q zero-check (10,4) <- Q matmul, PV
        "SC_ATTN_04": ["SC_ATTN_08K", "SC_ATTN_08V"],   # KV zero-check (9,4) <- K, V matmuls
        "SC_ATTN_02": ["SC_ATTN_11"],                   # D zero-check (10,4) <- Wo
    },
    "extra_slots": {},
}
SMHOST_HOSTS = {
    "variant": "smhost",
    "note": "alternative: the two sum claims (SS row sums, row sums) hosted by a dedicated (10, 2) zero-check SC_ATTN_SMHOST",
    "hosts": {
        "SC_ATTN_SMHOST": ["SC_ATTN_00", "SC_ATTN_06"],
        "SC_ATTN_05": ["SC_ATTN_09"],
        "SC_ATTN_03": ["SC_ATTN_08Q", "SC_ATTN_10"],
        "SC_ATTN_04": ["SC_ATTN_08K", "SC_ATTN_08V"],
        "SC_ATTN_02": ["SC_ATTN_11"],
    },
    "extra_slots": {
        "SC_ATTN_SMHOST": {"n_vars": 10, "degree": 2, "ext_rounds": 1,
                           "name": "sum-host zero-check (hosts the SS row sums and the row sums)",
                           "insert_after": "SC_ATTN_06"},
    },
}


# ----------------------------------------------------------------------------
# 1. the slot tables
# ----------------------------------------------------------------------------


def check_row_budget(slot: str, n_vars: int, degree: int) -> int:
    """mask_commit's assert (zk.rs:442): L_s + MASK_Q <= MASK_M.  Refuses otherwise."""
    L = cfs_len(n_vars, degree)
    if L + MASK_Q > MASK_M:
        raise ValueError(f"{slot}: refused, mask row L = {L} (n_vars {n_vars}, degree {degree}) + {MASK_Q} pads > {MASK_M} message positions")
    return L


def build_slot_table(inventory: Dict, mode: str, hosts: Optional[Dict] = None) -> List[Dict]:
    """Opus's twelve slots of A2_cfs_slots[mode] with SC_ATTN_08 split into Q/K/V
    plus the four ADDED_SLOTS (eighteen slots) in TRANSCRIPT_ORDER, plus the
    mapping's extra slots at their insert_after positions.  Each row: slot, name,
    n_vars, degree, ext_rounds, main_rounds, len, private, claimed_sum_form, and
    (once a mapping is applied) role / host / hosted."""
    if mode not in ("P1", "P3"):
        raise ValueError(f"mode must be P1 or P3, got {mode!r}")
    entries = inventory["A2_cfs_slots"][mode]
    got = [e["slot"] for e in entries]
    if got != OPUS_TWELVE:
        raise ValueError(f"inventory {mode}: expected Opus's twelve slots {OPUS_TWELVE}, got {got}")
    table: List[Dict] = []
    for e in entries:
        base = {"n_vars": int(e["n_vars"]), "degree": int(e["degree"]), "ext_rounds": int(e["ext_rounds"]),
                "section": e.get("section", ""), "source": e.get("source", ""), "ext_rationale": e.get("ext_rationale", "")}
        private = e["claimed_sum_form"] == PRIVATE_FORM
        if not private and e["claimed_sum_form"] != PUBLIC_FORM:
            raise ValueError(f"{e['slot']}: unknown claimed_sum_form {e['claimed_sum_form']!r}")
        if e["slot"] in SPLIT:
            if not private:
                raise ValueError(f"{e['slot']}: the split applies to a private-sum slot only")
            want = SPLIT_SHAPE[mode]
            if (base["n_vars"], base["degree"], base["ext_rounds"]) != want:
                raise ValueError(f"{e['slot']} {mode}: expected (n_vars, degree, ext) = {want}, inventory has {(base['n_vars'], base['degree'], base['ext_rounds'])}")
            for name, desc, value in SPLIT[e["slot"]]:
                table.append({**base, "slot": name, "name": desc, "private": True, "split_of": e["slot"], "value": value,
                              "ext_rationale": base["ext_rationale"] + "; split: one plane evaluation on one domain per masked scalar (construction 3.2)"})
        else:
            if e["slot"] in TWO_EXT and (base["n_vars"], base["degree"], base["ext_rounds"]) != TWO_EXT[e["slot"]]:
                raise ValueError(f"{e['slot']}: expected (n_vars, degree, ext) = {TWO_EXT[e['slot']]}, inventory has {(base['n_vars'], base['degree'], base['ext_rounds'])}")
            table.append({**base, "slot": e["slot"], "name": e["name"], "private": private,
                          "value": e.get("claimed_sum", "") if private else "public 0"})
    for a in ADDED_SLOTS:
        table.append({**a, "private": False, "value": "public 0"})
    known = {r["slot"] for r in table}
    if known != set(TRANSCRIPT_ORDER):
        raise ValueError(f"slot set {sorted(known)} != transcript order {sorted(TRANSCRIPT_ORDER)}")
    table.sort(key=lambda r: TRANSCRIPT_ORDER.index(r["slot"]))
    hosts = hosts or DEFAULT_HOSTS
    for name, spec in (hosts.get("extra_slots") or {}).items():
        if any(r["slot"] == name for r in table):
            raise ValueError(f"extra slot {name} collides with an inventory slot")
        row = {"slot": name, "name": spec.get("name", name), "n_vars": int(spec["n_vars"]), "degree": int(spec["degree"]),
               "ext_rounds": int(spec.get("ext_rounds", 1)), "section": "extra (mapping)", "source": "hosts mapping",
               "ext_rationale": spec.get("ext_rationale", "one public factor (eq) extends to 0"), "private": False, "value": "public 0",
               "extra": True}
        after = spec.get("insert_after")
        pos = len(table)
        if after is not None:
            idx = [r["slot"] for r in table]
            if after not in idx:
                raise ValueError(f"extra slot {name}: insert_after {after!r} is not a slot")
            pos = idx.index(after) + 1
        table.insert(pos, row)
    for i, r in enumerate(table):
        r["index"] = i
        r["main_rounds"] = r["n_vars"] - r["ext_rounds"]
        r["len"] = check_row_budget(r["slot"], r["n_vars"], r["degree"])
        r["row_budget_L_plus_256_le_512"] = True
        r["dim_S_expected"] = r["n_vars"] * r["degree"] + 1
    apply_hosts(table, hosts)
    return table


def validate_hosts(table: List[Dict], hosts: Dict) -> List[str]:
    names = {r["slot"]: r for r in table}
    errors: List[str] = []
    hosted_by: Dict[str, str] = {}
    for host, hosted in (hosts.get("hosts") or {}).items():
        if host not in names:
            errors.append(f"host {host} is not a slot")
            continue
        if names[host]["private"]:
            errors.append(f"host {host} is a private-sum slot; a host must have a public claimed sum")
        if not hosted:
            errors.append(f"host {host} hosts nothing")
        for s in hosted:
            if s not in names:
                errors.append(f"{host} hosts {s}, which is not a slot")
                continue
            if not names[s]["private"]:
                errors.append(f"{host} hosts {s}, which is public-zero (only private sums are hosted)")
            if s in hosted_by:
                errors.append(f"{s} hosted twice ({hosted_by[s]} and {host}): the masked scalar would be counted in two hosts")
            hosted_by[s] = host
    for host in (hosts.get("hosts") or {}):
        if host in hosted_by:
            errors.append(f"host {host} is itself hosted by {hosted_by[host]}")
    for r in table:
        if r["private"] and r["slot"] not in hosted_by:
            errors.append(f"private-sum slot {r['slot']} is not hosted: its claimed sum would have to be reconstructed in the clear")
    return errors


def apply_hosts(table: List[Dict], hosts: Dict) -> None:
    errors = validate_hosts(table, hosts)
    if errors:
        raise ValueError("host mapping refused: " + "; ".join(errors))
    hosted_by = {s: h for h, hs in hosts["hosts"].items() for s in hs}
    order = [r["slot"] for r in table]
    for r in table:
        s = r["slot"]
        r.pop("host", None)
        r.pop("hosted", None)
        if s in hosted_by:
            h = hosted_by[s]
            r["role"] = "private (hosted)"
            r["host"] = h
            r["claimed_sum_form"] = f"private masked scalar claim_{s} = s + c_{s} G_{s} (sent once; hosted by {h}: the host's claimed sum carries nu_{s} claim_{s})"
        elif s in hosts["hosts"]:
            hs = list(hosts["hosts"][s])
            r["role"] = "public-zero host"
            r["hosted"] = hs
            terms = " - ".join(f"nu_{x} c_{x} G_{x}" for x in hs)
            r["claimed_sum_form"] = (f"batched: sum_i nu_i claim_i + Gamma_{s}, Gamma_{s} = c_{s} G_{s} - {terms} (sent); hosted: {hs}")
            r["hosted_after_host_in_transcript"] = [x for x in hs if order.index(x) > order.index(s)]
        else:
            r["role"] = "public-zero standalone"
            r["claimed_sum_form"] = f"public 0 + Gamma_{s} = c_{s} G_{s} (sent)"


def slots_dict(table: List[Dict]) -> Dict[str, Dict]:
    """The slot-dict format FA6's system builders take (system_single / _finish)."""
    return C._finish({r["slot"]: {"n_vars": r["n_vars"], "degree": r["degree"], "ext_rounds": r["ext_rounds"]} for r in table})


def largest_slot(table: List[Dict]) -> Dict:
    r = max(table, key=lambda x: x["len"])
    return {"slot": r["slot"], "name": r["name"], "n_vars": r["n_vars"], "degree": r["degree"], "len": r["len"],
            "headroom_coefficients": MASK_M - MASK_Q - r["len"], "constraint": f"L_s + {MASK_Q} <= {MASK_M} (zk.rs mask_commit)"}


# ----------------------------------------------------------------------------
# 2. FA6's criterion per slot standalone (imported, not re-derived)
# ----------------------------------------------------------------------------


def standalone_report(table: List[Dict], rng: Rng) -> Dict[str, Dict]:
    slots = slots_dict(table)
    out: Dict[str, Dict] = {}
    for r in table:
        s = r["slot"]
        ch, meta = C.system_single(slots, s, rng)
        res = C.analyze_system(ch, meta)
        exp = r["dim_S_expected"]
        res["dim_S_expected_N_d_plus_1"] = exp
        res["pass"] = bool(res["image_inside_subspace"] and res["leaked_dim_fp2"] == 0 and res["rank_map"] == exp
                           and res["dim_consistency_subspace"] == exp and res["kernel_dim_fp2"] == 1
                           and all(res["m_functionals_in_view_span"].values()) and res["theta_combination_in_view_span"])
        out[s] = {k: res[k] for k in ("n_unknowns_fp2", "n_view_fp2", "n_constraints", "rank_map", "dim_consistency_subspace",
                                      "dim_S_expected_N_d_plus_1", "image_inside_subspace", "leaked_dim_fp2", "kernel_dim_fp2",
                                      "m_functionals_in_view_span", "theta_combination_in_view_span", "verdict", "pass")}
        out[s].update({"n_vars": r["n_vars"], "degree": r["degree"], "len": r["len"], "role": r["role"]})
    return out


# ----------------------------------------------------------------------------
# 3. the host systems: system_batched_pair generalised to k >= 1 hosted private sums
# ----------------------------------------------------------------------------

LinForm = Dict[str, Fp2]   # a linear form in named data symbols (the f-part of a view coordinate)


def lf_add(a: LinForm, b: LinForm) -> LinForm:
    out = dict(a)
    for k, v in b.items():
        out[k] = f2_add(out.get(k, ZERO), v)
    return {k: v for k, v in out.items() if not f2_is_zero(v)}


def lf_scale(a: LinForm, k: Fp2) -> LinForm:
    return {s: f2_mul(k, v) for s, v in a.items() if not f2_is_zero(f2_mul(k, v))}


def lf_sub(a: LinForm, b: LinForm) -> LinForm:
    return lf_add(a, lf_scale(b, f2_neg(ONE)))


def lf_json(a: LinForm) -> Dict[str, List[int]]:
    return {k: list(v) for k, v in a.items()}


def system_hosted(slots: Dict[str, Dict], host: str, hosted: Sequence[str], rng: Rng,
                  cs: Optional[Dict[str, Fp2]] = None, nus: Optional[Dict[str, Fp2]] = None, c_host: Optional[Fp2] = None,
                  last_round_degree: Optional[Dict[str, int]] = None, refuse_zero_c: bool = True,
                  extra_views: Optional[Dict[str, str]] = None) -> Tuple[Channel, Dict]:
    """The FFN's (SC_GU, SC_ZC20) form with k hosted slots.  Unknowns (a_host, a_1..a_k).
    View: each hosted slot's masked scalar (g-part c_i G_i) and its rounds, the host's
    Gamma_host = c_host G_host - sum_i nu_i c_i G_i and its rounds.  The host's round-0
    relation is against sum_i nu_i claim_i + Gamma_host.  `cs`, `nus`, `c_host` override
    the stand-in challenges (negative controls); `last_round_degree[slot]` models an
    extension round the mask does not cover; `extra_views` adds {label: slot} standalone
    c_slot Sigma_slot rows (the Sigma-functional control).  The f-part of every claim
    coordinate is recorded as a linear form in the data symbols s_<slot>."""
    cs = dict(cs or {})
    nus = dict(nus or {})
    lrd = dict(last_round_degree or {})
    ch = Channel()
    ch.add_mask(host, slots[host]["n_vars"], slots[host]["degree"])
    for s in hosted:
        ch.add_mask(s, slots[s]["n_vars"], slots[s]["degree"])
    c_h = c_host if c_host is not None else rng.fp2()
    c = {s: (cs[s] if s in cs else rng.fp2()) for s in hosted}
    nu = {s: (nus[s] if s in nus else rng.fp2()) for s in hosted}
    if refuse_zero_c and (f2_is_zero(c_h) or any(f2_is_zero(v) for v in c.values())):
        raise ValueError("zero mask challenge: abandon proof attempt (zk.rs extension / div refuse c = 0)")
    sum_w = {s: cfs_sum_weights(slots[s]["n_vars"], slots[s]["degree"]) for s in [host, *hosted]}
    claim_idx: Dict[str, int] = {}
    claim_rows: Dict[str, List[Fp2]] = {}
    sc: Dict[str, Dict] = {}
    f_part: Dict[int, LinForm] = {}
    for s in hosted:
        claim_rows[s] = ch.mask_row(s, sum_w[s], c[s])
        claim_idx[s] = ch.add_view(f"{s}.claim(g-part = c_s G_s)", claim_rows[s])
        f_part[claim_idx[s]] = {f"s_{s}": ONE}
        sc[s] = ch.add_masked_sumcheck(s, c[s], {claim_idx[s]: ONE}, rng, s, last_round_degree=lrd.get(s))
    host_sum_row = ch.mask_row(host, sum_w[host], c_h)
    gamma_row = list(host_sum_row)
    for s in hosted:
        gamma_row = ch.row_add(gamma_row, ch.mask_row(s, sum_w[s], f2_neg(f2_mul(nu[s], c[s]))))
    gamma_idx = ch.add_view(f"{host}.Gamma = c_host G_host - sum_i nu_i c_i G_i", gamma_row)
    f_part[gamma_idx] = {}
    refs = {claim_idx[s]: nu[s] for s in hosted}
    refs[gamma_idx] = ONE
    sc[host] = ch.add_masked_sumcheck(host, c_h, refs, rng, host, last_round_degree=lrd.get(host))
    extra_idx: Dict[str, int] = {}
    for label, s in (extra_views or {}).items():
        cc = c_h if s == host else c[s]
        extra_idx[label] = ch.add_view(label, ch.mask_row(s, sum_w[s], cc))
        f_part[extra_idx[label]] = {}
    fs = {}
    for s in hosted:
        fs[f"g_{s}(rho)"] = ch.mask_row(s, cfs_eval_weights(sc[s]["rho"], slots[s]["degree"]))
    fs[f"g_{host}(rho)"] = ch.mask_row(host, cfs_eval_weights(sc[host]["rho"], slots[host]["degree"]))
    fs[f"Gamma_{host}"] = gamma_row
    # the host's honest f-part total: the host term sum_i nu_i eq(p_i, x) V_i(x) sums to sum_i nu_i s_i
    host_f_total: LinForm = {}
    for s in hosted:
        host_f_total = lf_add(host_f_total, {f"s_{s}": nu[s]})
    meta = {"functionals": fs, "c": {host: c_h, **c}, "nu": nu, "rho": {k: v["rho"] for k, v in sc.items()},
            "claim_idx": claim_idx, "claim_rows": claim_rows, "gamma_idx": gamma_idx, "gamma_row": gamma_row,
            "host_sum_row": host_sum_row, "f_part": f_part, "host_f_total": host_f_total, "host": host, "hosted": list(hosted),
            "extra_idx": extra_idx, "sumchecks": sc}
    return ch, meta


def f_part_round0_check(ch: Channel, meta: Dict) -> Dict:
    """The homogeneous round-0 relations hold for the honest f-part: for each hosted
    slot, f(h0(0)+h0(1)) = s_i = f(claim_i); for the host,
    f(h0(0)+h0(1)) = sum_i nu_i s_i = sum_i nu_i f(claim_i) + f(Gamma) with f(Gamma) = 0.
    Exact, as linear forms in the data symbols."""
    residuals = {}
    ok = True
    for s in meta["hosted"]:
        lhs = {f"s_{s}": ONE}
        rhs = meta["f_part"][meta["claim_idx"][s]]
        res = lf_sub(lhs, rhs)
        residuals[s] = lf_json(res)
        ok = ok and not res
    lhs = meta["host_f_total"]
    rhs: LinForm = {}
    for s in meta["hosted"]:
        rhs = lf_add(rhs, lf_scale(meta["f_part"][meta["claim_idx"][s]], meta["nu"][s]))
    rhs = lf_add(rhs, meta["f_part"][meta["gamma_idx"]])
    res = lf_sub(lhs, rhs)
    residuals[meta["host"]] = lf_json(res)
    ok = ok and not res
    return {"consistent": ok, "residuals": residuals,
            "host_f_total": lf_json(meta["host_f_total"]),
            "note": "f-part of the host's claimed sum = sum_i nu_i s_i (the host term); Gamma's f-part = 0; claim_i's f-part = s_i"}


def relabelling_check(ch: Channel, meta: Dict) -> Dict:
    """FA6 section 2.3's argument: Gamma_host's g-part is c_host G_host relabelled by the
    hosted claims' g-parts (c_i G_i), which are view coordinates already; so replacing
    Gamma by the pure c_host G_host row changes nothing in the view's row space."""
    recon = list(meta["host_sum_row"])
    for s in meta["hosted"]:
        recon = ch.row_add(recon, [f2_mul(f2_neg(meta["nu"][s]), x) for x in meta["claim_rows"][s]])
    exact = recon == meta["gamma_row"]
    span_ok = ch.in_row_space([meta["host_sum_row"]])
    claims_in_span = all(ch.in_row_space([meta["claim_rows"][s]]) for s in meta["hosted"])
    gamma_in_span = ch.in_row_space([meta["gamma_row"]])
    return {"gamma_equals_host_sum_minus_sum_nu_claims_exactly": exact, "host_sum_row_in_view_span": span_ok,
            "masked_scalars_in_view_span": claims_in_span, "gamma_in_view_span": gamma_in_span,
            "pass": exact and span_ok and claims_in_span and gamma_in_span}


def analyze_hosted(ch: Channel, meta: Dict, slots: Dict[str, Dict], want_witness: bool = True) -> Dict:
    res = C.analyze_system(ch, meta) if want_witness else ch.analyze(want_witness=False)
    host, hosted = meta["host"], meta["hosted"]
    k = len(hosted)
    L_sum = sum(slots[x]["len"] for x in [host, *hosted])
    res["host"] = host
    res["hosted"] = list(hosted)
    res["k"] = k
    res["sum_L"] = L_sum
    res["expected_dim_S_sum_L_minus_k_plus_1"] = L_sum - (k + 1)
    res["expected_kernel_k_plus_1"] = k + 1
    res["relabelling"] = relabelling_check(ch, meta)
    res["f_part_round0"] = f_part_round0_check(ch, meta)
    res["hosted_after_host_note"] = "the linear model is order-free; in the transcript each hosted claim_i (and its c_i) must be absorbed before the host's round-0 challenge"
    res["pass"] = bool(res["image_inside_subspace"] and res["leaked_dim_fp2"] == 0
                       and res["rank_map"] == L_sum - (k + 1) and res["dim_consistency_subspace"] == L_sum - (k + 1)
                       and res["kernel_dim_fp2"] == k + 1
                       and all(res.get("m_functionals_in_view_span", {ONE: True}).values())
                       and res.get("theta_combination_in_view_span", True)
                       and res["relabelling"]["pass"] and res["f_part_round0"]["consistent"])
    return res


def host_groups_report(table: List[Dict], hosts: Dict, rng: Rng) -> Dict:
    slots = slots_dict(table)
    order = [r["slot"] for r in table]
    groups: Dict[str, Dict] = {}
    for host in sorted(hosts["hosts"], key=order.index):
        hosted = list(hosts["hosts"][host])
        ch, meta = system_hosted(slots, host, hosted, rng)
        res = analyze_hosted(ch, meta, slots)
        res["hosted_after_host_in_transcript"] = [s for s in hosted if order.index(s) > order.index(host)]
        groups[host] = res
    public_standalone = {}
    hosted_all = {s for hs in hosts["hosts"].values() for s in hs}
    for r in table:
        s = r["slot"]
        if s in hosts["hosts"] or s in hosted_all:
            continue
        ch, meta = C.system_single(slots, s, rng)
        res = C.analyze_system(ch, meta)
        exp = r["dim_S_expected"]
        res["pass"] = bool(res["image_inside_subspace"] and res["leaked_dim_fp2"] == 0 and res["rank_map"] == exp and res["kernel_dim_fp2"] == 1
                           and all(res["m_functionals_in_view_span"].values()) and res["theta_combination_in_view_span"])
        public_standalone[s] = res
    return {"groups": groups, "public_standalone": public_standalone,
            "all_pass": all(g["pass"] for g in groups.values()) and all(g["pass"] for g in public_standalone.values())}


# ----------------------------------------------------------------------------
# 4. the M layout and the mask_functionals order
# ----------------------------------------------------------------------------


def m_layout(table: List[Dict], hosts: Dict) -> Dict:
    rows = []
    for r in table:
        for part in ("re", "im"):
            rows.append({"row": len(rows), "name": f"a_{r['slot']},{part}", "slot": r["slot"], "coefficients": r["len"], "pads": MASK_Q,
                         "zeros": MASK_M - MASK_Q - r["len"], "layout": f"[{r['len']} coefficients | {MASK_Q} pads | {MASK_M - MASK_Q - r['len']} zeros] on G_{MASK_M}"})
    for name, note in (("b_re", "1024 coefficients, b[512] = -b[0] (the q' blinding hyperplane)"), ("b_im", "1024 coefficients, b[512] = -b[0]"),
                       ("u_re", "1024 coefficients (the prox one-time pad)"), ("u_im", "1024 coefficients")):
        rows.append({"row": len(rows), "name": name, "slot": None, "coefficients": 1024, "layout": note})
    order = [r["slot"] for r in table]
    by = {r["slot"]: r for r in table}
    hosted_by = {s: h for h, hs in hosts["hosts"].items() for s in hs}
    functionals = []
    sigma_carried = {}
    for r in table:
        s, n, d = r["slot"], r["n_vars"], r["degree"]
        if r["role"] == "public-zero standalone":
            functionals.append({"index": len(functionals), "kind": "gamma", "slots": [s], "weights": f"c_{s} sum_weights({n}, {d})",
                                "value": f"Gamma_{s} (sent); the claimed sum is 0 + Gamma_{s}"})
        elif r["role"] == "public-zero host":
            sigma_carried[s] = f"host: c_{s} Sigma_{s} enters only through its batched Gamma_{s} (below); a standalone Sigma would let the verifier derive c_i G_i = (c_{s} G_{s} - Gamma_{s}) / nu_i and hence s_i from claim_i"
        else:
            h = hosted_by[s]
            sigma_carried[s] = f"private: c_{s} Sigma_{s} enters only through Gamma_{h}; the verifier holds claim_{s} = s + c_{s} G_{s}, never G_{s}"
        functionals.append({"index": len(functionals), "kind": "eval", "slots": [s], "weights": f"eval_weights(rho_{s}, {d})",
                            "value": f"g_{s}(rho_{s}), derived by the verifier as div(fin - want({s}_term), c_{s})"})
    for host in sorted(hosts["hosts"], key=order.index):
        hs = list(hosts["hosts"][host])
        w = f"c_{host} sum_weights({by[host]['n_vars']}, {by[host]['degree']}) on {host}; " + "; ".join(
            f"-nu_{s} c_{s} sum_weights({by[s]['n_vars']}, {by[s]['degree']}) on {s}" for s in hs)
        functionals.append({"index": len(functionals), "kind": "gamma_batched", "slots": [host, *hs], "weights": w,
                            "value": f"Gamma_{host} (sent); the {host} claimed sum is " + " + ".join(f"nu_{s} claim_{s}" for s in hs) + f" + Gamma_{host}"})
    n_slots = len(table)
    return {
        "n_slots": n_slots, "n_rows": len(rows), "rows_formula": f"2 * {n_slots} + 4 (b_re, b_im, u_re, u_im)", "rows": rows,
        "message_positions": MASK_M, "pads_per_row": MASK_Q, "largest": largest_slot(table),
        "every_row_fits": all(r["coefficients"] + MASK_Q <= MASK_M for r in rows if r["slot"] is not None),
        "opened_once_at_one_theta": True,
        "mask_functionals": functionals, "n_functionals": len(functionals),
        "functional_order_rule": "for each slot in transcript order: its Sigma-type functional (Gamma_s = c_s Sigma_s, public-zero standalone slots only) then eval(rho_s); then for each host in transcript order the batched Gamma_host = c_host Sigma_host - sum_i nu_i c_i Sigma_i (the round-2 tool's gamma_pair convention, k-ary)",
        "sigma_carried_by_host_gamma": sigma_carried,
        "convention": "scripts/zk60_joint_cfs_view.py FUNCTIONAL_ASSIGNMENT kinds eval / gamma / gamma_pair (here gamma_batched for k >= 1)",
    }


# ----------------------------------------------------------------------------
# 5. R7: the extension round, exact (zkp-core extension_round: s_k(X) = poly((1 - X) fin + X ext))
# ----------------------------------------------------------------------------


def poly_mul(a: Sequence[Fp2], b: Sequence[Fp2]) -> List[Fp2]:
    out = [ZERO] * (len(a) + len(b) - 1)
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            out[i + j] = f2_add(out[i + j], f2_mul(x, y))
    return out


def poly_eval(p: Sequence[Fp2], x: Fp2) -> Fp2:
    acc = ZERO
    for coef in reversed(p):
        acc = f2_add(f2_mul(acc, x), coef)
    return acc


def poly_divisible_by_one_minus_x(p: Sequence[Fp2]) -> bool:
    """(1 - X) | p  iff  p(1) = 0 (remainder of division by X - 1)."""
    return f2_is_zero(poly_eval(p, ONE))


def ext_factor(fin: Fp2, ext: Fp2) -> List[Fp2]:
    """fin + X (ext - fin): one factor of the extension round as the code forms it."""
    return [fin, f2_sub(ext, fin)]


def extension_round_poly(factors: Sequence[Tuple[Fp2, Fp2]]) -> List[Fp2]:
    p = [ONE]
    for fin, ext in factors:
        p = poly_mul(p, ext_factor(fin, ext))
    return p


def extension_round_values(factors: Sequence[Tuple[Fp2, Fp2]], degree: int) -> List[Fp2]:
    """zkp-core::extension_round for a product poly: values at X = 0..degree."""
    return [poly_eval(extension_round_poly(factors), f2(x)) for x in range(degree + 1)]


def masked_terminal(fin: Fp2, ext: Fp2, e: Fp2) -> Fp2:
    return f2_add(fin, f2_mul(e, f2_sub(ext, fin)))


def mle_eval(vals: Sequence[Fp2], point: Sequence[Fp2]) -> Fp2:
    """Multilinear extension of `vals` (2^n entries, MSB-first) at `point`."""
    cur = list(vals)
    for r in point:
        half = len(cur) // 2
        cur = [f2_add(cur[i], f2_mul(r, f2_sub(cur[half + i], cur[i]))) for i in range(half)]
    return cur[0]


def r7_extension_check(rng: Rng, n_main: int = 2) -> Dict:
    """Small exact instances: two private factor families A, B (MLEs on a 2^n_main cube,
    evaluated at the main-round point rho -> the `finals`), a public family E, and the
    pair-mask branch values ext_A, ext_B.  The extension round's message is
    s(X) = poly((1 - X) fin + X ext); the verifier's chain needs s(1) = poly(exts) = 0
    ('vanishes on the mask branch')."""
    m = 1 << n_main
    A = [rng.fp2() for _ in range(m)]
    B = [rng.fp2() for _ in range(m)]
    E = [rng.fp2() for _ in range(m)]
    rho = rng.point(n_main)
    finA, finB, finE = mle_eval(A, rho), mle_eval(B, rho), mle_eval(E, rho)
    extA, extB = rng.fp2(), rng.fp2()
    out: Dict[str, Dict] = {"model": "zkp-core/src/sumcheck.rs extension_round: s_k(X) = poly((1 - X) fin + X ext), product poly; "
                                     "mask branch = X = 1; the chain needs s_k(0) + s_k(1) = previous claim = poly(finals), i.e. s_k(1) = 0",
                            "instance": {"n_main": n_main, "families": "A, B private (pair-masked, ext != 0), E public (ext 0) or eq_g == 1"}}

    # (i) one private family, one public factor extending to 0: E * A  -> (1 - X) finE * (finA + X (extA - finA))
    p = extension_round_poly([(finE, ZERO), (finA, extA)])
    out["one_private_public_extends_to_zero"] = {
        "factors": "E (ext 0) * A (ext extA)", "s_at_1_is_zero": f2_is_zero(poly_eval(p, ONE)),
        "one_minus_x_divides_s": poly_divisible_by_one_minus_x(p), "s_at_0_equals_poly_finals": poly_eval(p, ZERO) == f2_mul(finE, finA),
        "message_degree": len(p) - 1, "expect": "vanishes on the mask branch: the (1 - X) factor of the public family"}
    # (ii) two private families, the public factor == 1 (eq_g at KV heads = 1: fin = ext = 1), ONE extension round
    p2 = extension_round_poly([(ONE, ONE), (finA, extA), (finB, extB)])
    v1 = poly_eval(p2, ONE)
    out["two_private_public_factor_is_one_single_round"] = {
        "factors": "1 * A (ext extA) * B (ext extB)", "s_at_1": list(v1), "s_at_1_is_zero": f2_is_zero(v1),
        "s_at_1_equals_extA_extB": v1 == f2_mul(extA, extB), "one_minus_x_divides_s": poly_divisible_by_one_minus_x(p2),
        "message_degree": len(p2) - 1, "expect": "does NOT vanish: s(1) = extA extB != 0, the round stops summing to its claim"}
    # (ii') two private families but a public factor that extends to 0: still vanishes (the rule keys on a vanishing public factor)
    p2b = extension_round_poly([(finE, ZERO), (finA, extA), (finB, extB)])
    out["two_private_with_public_factor_extending_to_zero"] = {
        "factors": "E (ext 0) * A * B", "s_at_1_is_zero": f2_is_zero(poly_eval(p2b, ONE)),
        "expect": "vanishes: a public factor extending to 0 covers any number of private families in one round (why the rule is 'no public factor vanishes' rather than 'two private families')"}
    # (iii) two extension rounds, one per side (score / PV; the P3 matmul rule): round k extends A (B ext 0), round k+1 extends B (A' ext 0)
    e1, e2 = rng.fp2(), rng.fp2()
    pk = extension_round_poly([(ONE, ONE), (finA, extA), (finB, ZERO)])
    sk = [poly_eval(pk, f2(x)) for x in range(4)]     # degree-3 slot: 4 values, as extension(degree = mask.degree = 3)
    finA2 = masked_terminal(finA, extA, e1)
    finB2 = f2_mul(f2_sub(ONE, e1), finB)              # masked_terminal(finB, 0, e1)
    pk1 = extension_round_poly([(ONE, ONE), (finA2, ZERO), (finB2, extB)])
    sk1 = [poly_eval(pk1, f2(x)) for x in range(4)]
    chain = C.interp_eval(sk, e1) == f2_add(sk1[0], sk1[1])
    terminal = C.interp_eval(sk1, e2)
    want_terminal = f2_mul(f2_mul(f2_sub(ONE, e2), finA2), masked_terminal(finB2, extB, e2))
    out["two_private_two_rounds_one_per_side"] = {
        "round_k": "1 * A (ext extA) * B (ext 0)", "round_k_s_at_1_is_zero": f2_is_zero(sk[1]),
        "round_k_plus_1": "1 * A' (ext 0) * B' (ext extB), A' = finA + e1 (extA - finA), B' = (1 - e1) finB",
        "round_k_plus_1_s_at_1_is_zero": f2_is_zero(sk1[1]),
        "chain_s_k_at_e1_equals_s_k1_0_plus_s_k1_1": chain,
        "terminal_equals_(1-e2)_A'_times_B'(e2)": terminal == want_terminal,
        "expect": "both rounds vanish on the mask branch; the terminal carries the (1 - e2) factor on the first side (FA6 section 1.2's P3 form)"}
    passed = (out["one_private_public_extends_to_zero"]["s_at_1_is_zero"] and out["one_private_public_extends_to_zero"]["one_minus_x_divides_s"]
              and not out["two_private_public_factor_is_one_single_round"]["s_at_1_is_zero"]
              and out["two_private_public_factor_is_one_single_round"]["s_at_1_equals_extA_extB"]
              and out["two_private_with_public_factor_extending_to_zero"]["s_at_1_is_zero"]
              and out["two_private_two_rounds_one_per_side"]["round_k_s_at_1_is_zero"]
              and out["two_private_two_rounds_one_per_side"]["round_k_plus_1_s_at_1_is_zero"]
              and chain and terminal == want_terminal)
    out["pass"] = bool(passed)
    out["scope"] = "an exact polynomial check on small instances, not a proof; it says why SC_ATTN_09 / SC_ATTN_10 carry two extension rounds"
    return out


# ----------------------------------------------------------------------------
# 6. negative controls
# ----------------------------------------------------------------------------


def unsplit_qkv_models(table: List[Dict], mode: str, rng: Rng) -> Dict:
    """The QKV slot left UNSPLIT: one masked scalar for acc_q + lam_k acc_k + lam_v acc_v,
    a Q-domain value plus two KV-domain values.  (a) one scalar fed to both hosts with
    different nu's: the mask channel is fine but the honest f-part cannot satisfy both
    host relations (each host can only produce its own domain's part) -- the sum is
    double-counted and generic data is refused; (b) two scalars from the one mask total
    (public split t of c G): the mask channel leaks the functional
    (1 - t) acc_q - t (lam_k acc_k + lam_v acc_v); (c) the split: passes."""
    n, d, ext = SPLIT_SHAPE[mode]
    slots = slots_dict(table)
    slots["SC_ATTN_08"] = C._finish({"x": {"n_vars": n, "degree": d, "ext_rounds": ext}})["x"]
    Q, KV, X = "SC_ATTN_03", "SC_ATTN_04", "SC_ATTN_08"
    lam_k, lam_v = rng.fp2(), rng.fp2()
    claim_form: LinForm = {"acc_q": ONE, "acc_k": lam_k, "acc_v": lam_v}
    out: Dict[str, Dict] = {"claimed_sum": "acc_q + lam_k acc_k + lam_v acc_v (acc_q on the Q domain, acc_k / acc_v on the KV domain)"}

    # (a) one scalar, two hosts (double count)
    ch = Channel()
    for s in (X, Q, KV):
        ch.add_mask(s, slots[s]["n_vars"], slots[s]["degree"])
    c_x, c_q, c_kv, nu_q, nu_kv = rng.fp2(), rng.fp2(), rng.fp2(), rng.fp2(), rng.fp2()
    sw = {s: cfs_sum_weights(slots[s]["n_vars"], slots[s]["degree"]) for s in (X, Q, KV)}
    claim = ch.add_view("QKV.claim", ch.mask_row(X, sw[X], c_x))
    ch.add_masked_sumcheck(X, c_x, {claim: ONE}, rng, X)
    gq = ch.add_view("Q.Gamma", ch.row_add(ch.mask_row(Q, sw[Q], c_q), ch.mask_row(X, sw[X], f2_neg(f2_mul(nu_q, c_x)))))
    ch.add_masked_sumcheck(Q, c_q, {claim: nu_q, gq: ONE}, rng, Q)
    gkv = ch.add_view("KV.Gamma", ch.row_add(ch.mask_row(KV, sw[KV], c_kv), ch.mask_row(X, sw[X], f2_neg(f2_mul(nu_kv, c_x)))))
    ch.add_masked_sumcheck(KV, c_kv, {claim: nu_kv, gkv: ONE}, rng, KV)
    ra = ch.analyze(want_witness=False)
    # honest f-parts: the Q host's total is nu_q acc_q (its domain holds the Q planes only); the KV host's is nu_kv (lam_k acc_k + lam_v acc_v)
    resid_q = lf_sub({"acc_q": nu_q}, lf_scale(claim_form, nu_q))
    resid_kv = lf_sub(lf_scale({"acc_k": lam_k, "acc_v": lam_v}, nu_kv), lf_scale(claim_form, nu_kv))
    syms = ["acc_q", "acc_k", "acc_v"]
    rel_rows = [[r.get(s, ZERO) for s in syms] for r in (resid_q, resid_kv)]
    rel_rank = f2_rank(rel_rows)
    out["a_one_scalar_two_hosts"] = {
        "mask_channel": {k: ra[k] for k in ("rank_map", "dim_consistency_subspace", "image_inside_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "verdict")},
        "f_part_residual_Q_host": lf_json(resid_q), "f_part_residual_KV_host": lf_json(resid_kv),
        "honest_f_part_in_S": not resid_q and not resid_kv,
        "data_relations_rank": rel_rank, "data_symbols": syms,
        "meaning": "the Q host's relation forces lam_k acc_k + lam_v acc_v = 0 and the KV host's forces acc_q = 0: the whole lambda-combination is demanded from both hosts (double-counted), each can supply only its domain's part; generic honest data fails both relations (a completeness failure the verifier sees as a soundness refusal)",
        "expect": "mask channel surjective, honest f-part NOT in S, data relation rank 2"}

    # (b) two scalars from the one mask (public split t): claim_Q = acc_q + t c G, claim_KV = lam_k acc_k + lam_v acc_v + (1 - t) c G
    t = rng.fp2()
    ch2 = Channel()
    for s in (X, Q, KV):
        ch2.add_mask(s, slots[s]["n_vars"], slots[s]["degree"])
    claim_q = ch2.add_view("QKV.claim_Q (g-part t c G)", ch2.mask_row(X, sw[X], f2_mul(t, c_x)))
    claim_kv = ch2.add_view("QKV.claim_KV (g-part (1 - t) c G)", ch2.mask_row(X, sw[X], f2_mul(f2_sub(ONE, t), c_x)))
    ch2.add_masked_sumcheck(X, c_x, {claim_q: ONE, claim_kv: ONE}, rng, X)
    gq2 = ch2.add_view("Q.Gamma", ch2.row_add(ch2.mask_row(Q, sw[Q], c_q), ch2.mask_row(X, sw[X], f2_neg(f2_mul(f2_mul(nu_q, t), c_x)))))
    ch2.add_masked_sumcheck(Q, c_q, {claim_q: nu_q, gq2: ONE}, rng, Q)
    gkv2 = ch2.add_view("KV.Gamma", ch2.row_add(ch2.mask_row(KV, sw[KV], c_kv), ch2.mask_row(X, sw[X], f2_neg(f2_mul(f2_mul(nu_kv, f2_sub(ONE, t)), c_x)))))
    ch2.add_masked_sumcheck(KV, c_kv, {claim_kv: nu_kv, gkv2: ONE}, rng, KV)
    rb = ch2.analyze(want_witness=True)
    # the explicit leaked functional phi = (1 - t) [claim_Q] - t [claim_KV]: kills every mask, is not a verifier relation
    nv = len(ch2.view_rows)
    phi = [ZERO] * nv
    phi[claim_q] = f2_sub(ONE, t)
    phi[claim_kv] = f2_neg(t)
    phi_L = [ZERO] * ch2.n_unk
    for i, coef in enumerate(phi):
        if not f2_is_zero(coef):
            phi_L = [f2_add(a, f2_mul(coef, b)) for a, b in zip(phi_L, ch2.view_rows[i])]
    kills_mask = all(f2_is_zero(x) for x in phi_L)
    cons = ch2.cons_rows()
    not_a_relation = f2_rank(cons + [phi]) == f2_rank(cons) + 1
    phi_f = lf_sub(lf_scale({"acc_q": ONE}, f2_sub(ONE, t)), lf_scale({"acc_k": lam_k, "acc_v": lam_v}, t))
    out["b_two_scalars_one_mask_total"] = {
        "mask_channel": {k: rb[k] for k in ("rank_map", "dim_consistency_subspace", "image_inside_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "verdict")},
        "leaked_functionals_from_analysis": rb.get("leaked_functionals"),
        "explicit_phi": "(1 - t) claim_Q - t claim_KV", "phi_kills_every_mask": kills_mask, "phi_not_a_verifier_relation": not_a_relation,
        "phi_of_data": lf_json(phi_f), "phi_of_data_symbolic": "(1 - t) acc_q - t (lam_k acc_k + lam_v acc_v)",
        "t_is_one_case": "t = 1 is the second scalar sent in the clear: phi = -claim_KV",
        "expect": "leaked 1: one mask total cannot hide two scalars"}

    # (c) the split (positive control): three masks, hosted on their domains
    ch3, meta3 = system_hosted(slots, Q, ["SC_ATTN_08Q"], rng)
    rc_q = analyze_hosted(ch3, meta3, slots, want_witness=False)
    ch4, meta4 = system_hosted(slots, KV, ["SC_ATTN_08K", "SC_ATTN_08V"], rng)
    rc_kv = analyze_hosted(ch4, meta4, slots, want_witness=False)
    out["c_split_three_scalars"] = {
        "Q_host": {k: rc_q[k] for k in ("rank_map", "dim_consistency_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "pass")},
        "KV_host": {k: rc_kv[k] for k in ("rank_map", "dim_consistency_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "pass")},
        "expect": "surjective, honest f-part in S: each masked scalar is one plane evaluation on one domain"}
    out["pass"] = bool(ra["leaked_dim_fp2"] == 0 and not out["a_one_scalar_two_hosts"]["honest_f_part_in_S"] and rel_rank == 2
                       and rb["leaked_dim_fp2"] == 1 and kills_mask and not_a_relation and rc_q["pass"] and rc_kv["pass"])
    return out


def negative_controls(table: List[Dict], hosts: Dict, mode: str, rng: Rng) -> Dict[str, Dict]:
    slots = slots_dict(table)
    out: Dict[str, Dict] = {}
    host, hosted = "SC_ATTN_01", ["SC_ATTN_00"]           # the smallest hosted group of the default mapping
    if host not in hosts["hosts"] or hosts["hosts"][host] != hosted:
        host = next(iter(hosts["hosts"]))
        hosted = list(hosts["hosts"][host])
    s0 = hosted[0]

    # c_s = 0 on a hosted slot: refused by the code (extension asserts !c.is_zero(); div refuses c = 0); if forced, its whole view is clear
    refused = False
    try:
        system_hosted(slots, host, hosted, rng, cs={s0: ZERO})
    except ValueError:
        refused = True
    ch, meta = system_hosted(slots, host, hosted, rng, cs={s0: ZERO}, refuse_zero_c=False)
    r = analyze_hosted(ch, meta, slots)
    out["nc_hosted_c_zero"] = {
        "refused_by_the_tool_like_the_code": refused, "forced": {k: r[k] for k in ("rank_map", "dim_consistency_subspace", "image_inside_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "verdict")},
        "leaked_expected_dim_S_of_hosted_slot": slots[s0]["n_vars"] * slots[s0]["degree"] + 1,
        "pass": refused and r["leaked_dim_fp2"] == slots[s0]["n_vars"] * slots[s0]["degree"] + 1,
        "expect": f"refused; forced: leaked = dim S_{s0} = N d + 1 (the hosted slot's messages and its s are in the clear: claim_s = s_s)"}

    # nu_i = 0: the private slot decouples from the host; the criterion is blind (still surjective) -- the loss is binding, not hiding
    ch, meta = system_hosted(slots, host, hosted, rng, nus={s0: ZERO})
    r = analyze_hosted(ch, meta, slots)
    binding_lost = f"s_{s0}" not in meta["host_f_total"]
    out["nc_host_nu_zero"] = {
        "criterion": {k: r[k] for k in ("rank_map", "dim_consistency_subspace", "image_inside_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "verdict")},
        "f_part_round0": r["f_part_round0"], "host_f_total_contains_hosted_sum": not binding_lost,
        "what_the_criterion_says": "surjective, leaked 0: two independent masked sumchecks; hiding is intact",
        "what_it_does_not_see": f"the host term nu eq(p, x) V(x) vanishes, so claim_{s0}'s data part s is bound to no plane evaluation: soundness, not hiding. nu is a transcript challenge (probability p^-2 of 0); the code should refuse nu = 0 as it refuses c = 0",
        "pass": r["leaked_dim_fp2"] == 0 and r["image_inside_subspace"] and binding_lost,
        "expect": "criterion passes (blind); binding lost; refusal recommended"}

    # extension degree != mask degree in one round (the zip in zk.rs::extension): the top value of the message is clear
    dh = slots[host]["degree"]
    ch, meta = system_hosted(slots, host, hosted, rng, last_round_degree={host: dh + 1})
    r = analyze_hosted(ch, meta, slots)
    out["nc_extension_degree_exceeds_mask"] = {
        "where": f"{host}'s extension round of degree {dh + 1} under a degree-{dh} mask",
        "criterion": {k: r[k] for k in ("rank_map", "dim_consistency_subspace", "image_inside_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "verdict")},
        "leaked_functionals": r.get("leaked_functionals"),
        "pass": r["leaked_dim_fp2"] == 1 and r["image_inside_subspace"],
        "expect": "leaked 1: exactly the clear top value h_{N-1}(d+1) (FA6 I1; the code asserts degree == mask.degree)"}

    # the QKV slot unsplit
    out["nc_qkv_unsplit"] = unsplit_qkv_models(table, mode, rng)

    # L_s + 256 > 512 refused
    try:
        check_row_budget("SC_ATTN_OVERSIZE", 51, 5)
        refused = False
    except ValueError as e:
        refused = True
        msg = str(e)
    out["nc_row_budget_exceeded"] = {"slot": "(51, 5): L = 257", "refused": refused, "message": msg if refused else None, "pass": refused,
                                     "expect": "refused (mask_commit's assert: L_s + 256 <= 512)"}

    # a standalone Sigma functional opened for a hosted private slot (the literal 'Sigma then eval' for every slot): leaks s
    ch, meta = system_hosted(slots, host, hosted, rng, extra_views={f"{s0}.Sigma opened standalone (c_s G_s)": s0})
    r = analyze_hosted(ch, meta, slots)
    out["nc_sigma_functional_for_private_slot"] = {
        "criterion": {k: r[k] for k in ("rank_map", "dim_consistency_subspace", "image_inside_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "verdict")},
        "leaked_functionals": r.get("leaked_functionals"),
        "pass": r["leaked_dim_fp2"] == 1,
        "expect": f"leaked 1: claim_{s0} - c G_{s0} = s in the clear; hence the M layout carries no standalone Sigma for private or host slots"}
    ch, meta = system_hosted(slots, host, hosted, rng, extra_views={f"{host}.Sigma opened standalone (c_host G_host)": host})
    r = analyze_hosted(ch, meta, slots)
    out["nc_sigma_functional_for_host_slot"] = {
        "criterion": {k: r[k] for k in ("rank_map", "dim_consistency_subspace", "image_inside_subspace", "leaked_dim_fp2", "kernel_dim_fp2", "verdict")},
        "pass": r["leaked_dim_fp2"] == 1,
        "expect": f"leaked 1: (c_host G_host - Gamma_host) / nu = c G_{s0}, then claim_{s0} - c G_{s0} = s"}
    out["all_pass"] = all(v["pass"] for k, v in out.items() if isinstance(v, dict) and "pass" in v)
    return out


# ----------------------------------------------------------------------------
# the report
# ----------------------------------------------------------------------------


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_hosts(path: Optional[str], default: Dict) -> Dict:
    if path is None:
        return json.loads(json.dumps(default))
    with open(path) as f:
        spec = json.load(f)
    if "hosts" not in spec:
        raise ValueError(f"{path}: a host mapping needs a 'hosts' object")
    spec.setdefault("variant", Path(path).stem)
    spec.setdefault("extra_slots", {})
    return spec


def build_report(inventory_path: Path, seed: int = DEFAULT_SEED, hosts: Optional[Dict] = None, alt_hosts: Optional[Dict] = None) -> Dict:
    with open(inventory_path) as f:
        inventory = json.load(f)
    hosts = hosts or json.loads(json.dumps(DEFAULT_HOSTS))
    alt_hosts = alt_hosts or json.loads(json.dumps(SMHOST_HOSTS))
    rng = Rng(seed)
    checks: List[Dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "pass": bool(ok), "detail": detail})

    report: Dict = {
        "tool": TOOL, "owner": OWNER, "seed": seed,
        "inventory": str(inventory_path), "inventory_sha256": sha256_file(inventory_path),
        "inventory_source_commit": inventory.get("source_commit"),
        "imports": {"scripts/zk60_fable_cfs_channel.py": sha256_file(CFS_CHANNEL_PATH),
                    "scripts/zk60_fable_joint_rank.py": sha256_file(HERE / "zk60_fable_joint_rank.py")},
        "constants": {"MASK_Q": MASK_Q, "MASK_M": MASK_M},
        "slot_tables": {}, "standalone": {}, "host_variants": {}, "m_layout": {}, "r7_extension_check": None, "negative_controls": {},
        "scope": ("exact modular arithmetic at stand-in challenges; FA6's criterion imported; a construction check, not a simulator, "
                  "not an implementation, not a privacy acceptance; the PCS side (A, H, W) is the pair-schedule tool's"),
    }
    variants = [("default", hosts), (alt_hosts["variant"], alt_hosts)]
    for mode in ("P1", "P3"):
        table = build_slot_table(inventory, mode, hosts)
        report["slot_tables"][mode] = table
        names = [r["slot"] for r in table]
        by = {r["slot"]: r for r in table}
        check(f"{mode}: eighteen slots (Opus's twelve with QKV split into Q/K/V, plus TAB, ZS, IO_IN, IO_OUT) in the confirmed transcript order",
              len(table) == 18 and names == TRANSCRIPT_ORDER, str(names))
        check(f"{mode}: the four added slots at (17,3), (9,2), (10,2), (10,2), public-zero, neither hosted nor hosting",
              all(by[a["slot"]]["role"] == "public-zero standalone"
                  and (by[a["slot"]]["n_vars"], by[a["slot"]]["degree"], by[a["slot"]]["ext_rounds"]) == (a["n_vars"], a["degree"], a["ext_rounds"])
                  for a in ADDED_SLOTS))
        n, d, e = SPLIT_SHAPE[mode]
        check(f"{mode}: split slots at ({n}, {d}) with {e} extension round(s)",
              all((by[s]["n_vars"], by[s]["degree"], by[s]["ext_rounds"]) == (n, d, e) for s in ("SC_ATTN_08Q", "SC_ATTN_08K", "SC_ATTN_08V")))
        check(f"{mode}: SC_ATTN_09 (5, 3) and SC_ATTN_10 (7, 3) keep two extension rounds",
              all((by[s]["n_vars"], by[s]["degree"], by[s]["ext_rounds"]) == TWO_EXT[s] for s in TWO_EXT))
        big = largest_slot(table)
        check(f"{mode}: every slot L_s + 256 <= 512; largest {big['slot']} L = {big['len']}", all(r["len"] + MASK_Q <= MASK_M for r in table))
        report.setdefault("largest_slot", {})[mode] = big
        sa = standalone_report(table, rng)
        report["standalone"][mode] = sa
        check(f"{mode}: FA6's criterion standalone on all {len(sa)} slots (rank = dim S = N d + 1, image in S, leaked 0, kernel 1)",
              all(v["pass"] for v in sa.values()), ", ".join(f"{k}:{v['rank_map']}/{v['dim_consistency_subspace']}" for k, v in sa.items()))
        for label, spec in variants:
            vt = build_slot_table(inventory, mode, spec)
            hg = host_groups_report(vt, spec, rng)
            lay = m_layout(vt, spec)
            rv = report["host_variants"].setdefault(label, {"mapping": spec})
            rv[mode] = {"slot_order": [r["slot"] for r in vt], "n_slots": len(vt), "groups": hg["groups"], "public_standalone": hg["public_standalone"],
                        "roles": {r["slot"]: r["role"] for r in vt}, "all_pass": hg["all_pass"]}
            if label != "default":
                report["slot_tables"][f"{mode}_{label}"] = vt
            report["m_layout"].setdefault(label, {})[mode] = lay
            for host, g in hg["groups"].items():
                check(f"{mode} {label}: host {host} <- {g['hosted']}: rank = dim S = sum L - (k+1) = {g['expected_dim_S_sum_L_minus_k_plus_1']}, kernel {g['k'] + 1}, leaked 0, relabelling, f-part",
                      g["pass"], f"rank {g['rank_map']} dim S {g['dim_consistency_subspace']} kernel {g['kernel_dim_fp2']} leaked {g['leaked_dim_fp2']}")
                check(f"{mode} {label}: host {host}'s hosted slots all precede it in transcript order (each masked scalar is absorbed before the host's round 0)",
                      not g["hosted_after_host_in_transcript"], str(g["hosted_after_host_in_transcript"]))
            for s, g in hg["public_standalone"].items():
                check(f"{mode} {label}: public standalone {s}: rank = dim S, leaked 0, kernel 1", g["pass"])
            nz = 2 * len(vt) + 4
            check(f"{mode} {label}: M layout {lay['n_rows']} rows = 2 * {len(vt)} + 4, every row fits", lay["n_rows"] == nz and lay["every_row_fits"])
            evals = [f for f in lay["mask_functionals"] if f["kind"] == "eval"]
            gb = [f for f in lay["mask_functionals"] if f["kind"] == "gamma_batched"]
            gs = [f for f in lay["mask_functionals"] if f["kind"] == "gamma"]
            privates = [r["slot"] for r in vt if r["private"]]
            hosted_once = all(sum(1 for f in gb if s in f["slots"][1:]) == 1 for s in privates)
            no_sigma = all(f["slots"][0] not in privates and f["slots"][0] not in spec["hosts"] for f in gs)
            check(f"{mode} {label}: functionals: one eval per slot ({len(evals)}), one batched Gamma per host ({len(gb)}), {len(gs)} standalone Gamma, every private slot in exactly one batched Gamma, no standalone Sigma for private/host slots",
                  len(evals) == len(vt) and len(gb) == len(spec["hosts"]) and hosted_once and no_sigma and len(gs) == len(vt) - len(privates) - len(spec["hosts"]))
    r7 = r7_extension_check(rng)
    report["r7_extension_check"] = r7
    check("R7: one private family vanishes on the mask branch with a public factor extending to 0; two private families with the public factor == 1 do not in one round and do in two (one per side)", r7["pass"])
    for mode in ("P1", "P3"):
        table = build_slot_table(inventory, mode, hosts)
        nc = negative_controls(table, hosts, mode, rng)
        report["negative_controls"][mode] = nc
        for k, v in nc.items():
            if isinstance(v, dict) and "pass" in v:
                check(f"{mode} negative control {k}: {v.get('expect', '')}", v["pass"])
    report["checks"] = checks
    report["n_checks"] = len(checks)
    report["all_checks_pass"] = all(c["pass"] for c in checks)
    report["tool_sha256"] = sha256_file(Path(__file__).resolve())
    return report


def summary_lines(report: Dict) -> List[str]:
    lines = [f"[attention CFS] seed {report['seed']}  inventory {report['inventory_sha256'][:16]}  checks {sum(c['pass'] for c in report['checks'])}/{report['n_checks']}  all_pass={report['all_checks_pass']}"]
    for mode in ("P1", "P3"):
        big = report["largest_slot"][mode]
        lines.append(f"  {mode}: {len(report['slot_tables'][mode])} slots, largest {big['slot']} (n_vars {big['n_vars']}, degree {big['degree']}) L = {big['len']}, headroom {big['headroom_coefficients']}")
        for s, v in report["standalone"][mode].items():
            lines.append(f"    standalone {s:14s} ({v['n_vars']:2d},{v['degree']}) L {v['len']:3d}  rank {v['rank_map']:3d} = dim S {v['dim_consistency_subspace']:3d}  kernel {v['kernel_dim_fp2']}  leaked {v['leaked_dim_fp2']}  {'ok' if v['pass'] else 'FAIL'}")
        for label, rv in report["host_variants"].items():
            m = rv[mode]
            lines.append(f"    variant {label} ({m['n_slots']} slots, M rows {report['m_layout'][label][mode]['n_rows']}, functionals {report['m_layout'][label][mode]['n_functionals']}):")
            for host, g in m["groups"].items():
                lines.append(f"      host {host:14s} <- {', '.join(g['hosted']):40s} sum L {g['sum_L']:3d}  rank {g['rank_map']:3d} = dim S {g['dim_consistency_subspace']:3d}  kernel {g['kernel_dim_fp2']}  leaked {g['leaked_dim_fp2']}  relabel {g['relabelling']['pass']}  f-part {g['f_part_round0']['consistent']}  {'ok' if g['pass'] else 'FAIL'}")
            for s, g in m["public_standalone"].items():
                lines.append(f"      standalone public {s:14s} rank {g['rank_map']:3d} = dim S {g['dim_consistency_subspace']:3d}  kernel {g['kernel_dim_fp2']}  leaked {g['leaked_dim_fp2']}  {'ok' if g['pass'] else 'FAIL'}")
        nc = report["negative_controls"][mode]
        for k, v in nc.items():
            if isinstance(v, dict) and "pass" in v:
                lines.append(f"    {k:40s} {'ok' if v['pass'] else 'FAIL'}  ({v.get('expect', '')[:90]})")
    lines.append(f"  R7 extension check: {'ok' if report['r7_extension_check']['pass'] else 'FAIL'}")
    for c in report["checks"]:
        if not c["pass"]:
            lines.append(f"  FAIL: {c['name']}  {c['detail']}")
    return lines


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--inventory", required=True, help="results/zk60_opus_attention_inventory.json")
    ap.add_argument("--out", required=True, help="results JSON to write")
    ap.add_argument("--hosts", default=None, help="host mapping JSON for the primary variant (default: the construction's section 3.3 mapping)")
    ap.add_argument("--alt-hosts", default=None, help="host mapping JSON for the alternative variant (default: SC_ATTN_SMHOST)")
    ap.add_argument("--seed", type=int, default=DEFAULT_SEED)
    ap.add_argument("--dump-hosts", default=None, help="write the default host mapping JSON here (a template to edit) and exit")
    args = ap.parse_args(argv)
    if args.dump_hosts:
        with open(args.dump_hosts, "w") as f:
            json.dump(DEFAULT_HOSTS, f, indent=1)
        print(f"wrote {args.dump_hosts}")
        return 0
    try:
        hosts = load_hosts(args.hosts, DEFAULT_HOSTS)
        alt = load_hosts(args.alt_hosts, SMHOST_HOSTS)
        report = build_report(Path(args.inventory), seed=args.seed, hosts=hosts, alt_hosts=alt)
    except (ValueError, KeyError, AssertionError, FileNotFoundError) as e:
        print(f"[attention CFS] REFUSED: {e}", file=sys.stderr)
        return 1
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as f:
        json.dump(report, f, indent=1, default=str)
    for line in summary_lines(report):
        print(line)
    print(f"wrote {out}")
    return 0 if report["all_checks_pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
