#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-02] D60: the D55 gate's R13 items -- a REGISTERED D55
"commit, fork, join" run over an R13 blocks-only base (`run.rs`
`D55_RUN_PROFILES`, the twelve R13 run profiles of `ACCURACY_RUN_PROFILES`),
captured by the PRODUCTION writer (`run_capture::write_bundle`, D60).

Called from `zk60_native_rg_d55.d55_gate` when the bundle's block profile is
an R13 accuracy profile (the W16-family path is unchanged).  What is R13 here:

  R13-1  the facts: the block profile is an R13 accuracy profile (shape.rs
         ACCURACY_PROFILES; a DD profile is REFUSED by name: SC_DD and the DD
         softmax twin are not ported), the run profile is the REGISTERED D55
         profile `hashline-zk-mr1/` + the D60 marker + its base, the base is the
         block profile's registered R13 run profile, the parameter line ends in
         the registered clause (D12a's one-transcript clause replaced), the
         REGISTERED schedule digest recomputed from run.json's own lines
         (`run_fork.rs::schedule_lines`, the registered branch: counts, and each
         fork line saying its IO claims are opened in phase 3), the R13
         calibration line parsed and its printed precision re-derived, and the
         PCS geometry of every regular opening (rate 1/4, Q = pads = 256) and M
  R13-2  the layout: the capture's plane index (`PlaneIndex`, its own
         integrity) against the independent R13 plane list
         (`zk60_native_rg_r13slots.check_plane_index`)
  R13-3  THE PER-SLOT TERMINAL IDENTITY of all 23 slots on EVERY fork, at that
         fork's own calibration (the line's base and any own clause of its
         stage line) and its own R13 gate denominator G_k
         (`zk60_native_rg_r13blocks.check_stage`, through a one-fork shim), with
         every public table rebuilt or (statement tables) taken from the capture
         after their structure checks; and the R13 block port's own controls on
         one fork (R13-G, NC-1, R13-N, R13-GC, R13-ACT, R13-W, R13-L), each
         predicted to fail exactly its slot.  G_k: a D12a / D55 run's stage line
         does not print it (the classifier's does); it is a layer record's
         `accuracy-gate-layer`, bound through the public statement digest the
         header absorbs.  So the gate RECOVERS it: G in the class [17, 24] is
         tried on SC_FZC (slot 18, whose host term and Rg top-bit pin read G),
         and exactly one value must close the slot; the record says so.  This
         is a determination by the terminal identity, NOT a reading of a bound
         clear-text line (owed: the capture should print G_k)
  PINS   the R13 terminal port's own source-pin check
         (`zk60_native_rg_terminals.check_source_pins`) is RUN AND REPORTED; at
         this tree it refuses (the private_block files moved since r19b), so
         R13-3's figures are computed on the bundle as given and the record is
         DEV-PASS at best -- the same rule the W16 records follow.  [gate round
         26] Unless every pin it refuses is read by the pin classification
         (`zk60_native_rg_w16.classify_pins`, the R26 readings): the D55
         driver checks exactly that

NOTHING HERE IS A PRIVACY STATEMENT OR AN ACCEPTANCE.
"""

from __future__ import annotations

import copy
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_bundle as RB  # noqa: E402
import zk60_native_rg_r13slots as R  # noqa: E402
import zk60_native_rg_stagecal as SCAL  # noqa: E402

# ---------------------------------------------------------------- the registry
# run.rs ACCURACY_RUN_PROFILES (:207-232): the twelve R13 blocks-only run profiles
R13_RUN_PROFILES = {
    "hashline-zk-mr1/private-run-tinyllama-1.1b-t128-low-stack-v01-run/1": "hashline-zk-mr1/private-block-tinyllama-1.1b-t128-low-stack-v01/1",
    "hashline-zk-mr1/private-run-tinyllama-1.1b-t128-low-ddict-v01-run/1": "hashline-zk-mr1/private-block-tinyllama-1.1b-t128-low-ddict-v01/1",
    "hashline-zk-mr1/private-run-llama-3-8b-t128-lh24-v1-statement/1": "hashline-zk-mr1/private-block-llama-3-8b-t128-lh24-v1/1",
    "hashline-zk-mr1/private-run-llama-3-8b-t128-lh24-dd-statement/1": "hashline-zk-mr1/private-block-llama-3-8b-t128-lh24-dd/1",
    "hashline-zk-mr1/private-run-shieldstral-3b-t128-lowh24-blocks-run/1": "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/1",
    "hashline-zk-mr1/private-run-shieldstral-3b-t128-lowh24-ddict1-run/1": "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-ddict1/1",
    "hashline-zk-mr1/private-run-shieldstral-3b-t256-lowh24-blocks-run/1": "hashline-zk-mr1/private-block-shieldstral-3b-t256-lowh24-blocks/1",
    "hashline-zk-mr1/private-run-shieldstral-3b-t256-lowh24-ddict1-run/1": "hashline-zk-mr1/private-block-shieldstral-3b-t256-lowh24-ddict1/1",
    "hashline-zk-mr1/private-run-rung-lo-t32-dev/1": "hashline-zk-mr1/private-block-rung-lo-t32-dev/1",
    "hashline-zk-mr1/private-run-rung-lh-t32-dev/1": "hashline-zk-mr1/private-block-rung-lh-t32-dev/1",
    "hashline-zk-mr1/private-run-rung-ld-t32-dev/1": "hashline-zk-mr1/private-block-rung-ld-t32-dev/1",
    "hashline-zk-mr1/private-run-rung-hh-t32-dev/1": "hashline-zk-mr1/private-block-rung-hh-t32-dev/1",
}
# run.rs D55_REGISTERED_MARKER (:253) and run_fork.rs D55_LINE_TAIL (:99),
# D55_SCHEDULE_LITERAL (:101), D12A_LINE_TAIL (:95)
D55_REGISTERED_MARKER = "d55-commit-fork-join-run/registered-opt-in-d60/v1/"
NS = "hashline-zk-mr1/"
REG_LINE_TAIL = "/d55-commit-fork-join-registered-d60"
REG_SCHEDULE_DOMAIN = b"hashline/private-run-fork-schedule/d55-registered-d60/1"
D12A_LINE_TAIL = "/one-run-one-transcript"


def registered_d55_profile(base: str) -> str:
    """run.rs: `hashline-zk-mr1/` + the marker + the base without `hashline-zk-mr1/`"""
    if not base.startswith(NS):
        raise ValueError(f"{base!r} is not a hashline-zk-mr1 profile")
    return NS + D55_REGISTERED_MARKER + base[len(NS):]


# run.rs D55_RUN_PROFILES (:269-282): D55 profile -> base
D55_RUN_PROFILES = {registered_d55_profile(base): base for base in R13_RUN_PROFILES}

# shape.rs: every R13 accuracy profile's regular commitments at rate 1/4, Q =
# pads = 256 (COL_CHECKS); M at its own constants (zk.rs MASK_LOG_DOM 12, MASK_Q 256)
R13_GEOMETRY = (4, 256)
MASK_GEOMETRY = (12, 256)
GATE_CLASS = range(17, 25)
SC_FZC = 18


def is_r13_block_profile(profile: str) -> bool:
    return profile in R.ACCURACY_PROFILES


def base_of(profile: str):
    """the base run profile of a REGISTERED D55 run profile, or None"""
    return D55_RUN_PROFILES.get(profile)


# ---------------------------------------------------------------- R13-1: the facts
def registered_schedule_lines(run: dict) -> list:
    """run_fork.rs `schedule_lines`, the REGISTERED branch (:659-668), from
    run.json's own lines: the fork parameter line, the layout lines, phase 1
    with the boundary COUNT, one fork line per block quoting D12a's stage line,
    phase 3 with the counts"""
    l = run["blocks"]
    b = max(l - 1, 0)
    lines = [run["parameter_line"]] + list(run["layout_description"])
    lines.append(f"phase 1 (commit): the {b} internal boundaries (boundary k after block k), committed in boundary order on "
                 f"the run transcript, each root absorbed (pb-fork-commit-root k, B, rows, log-cols); then pb-fork-s0 = {l}")
    for k in range(l):
        lines.append(f"fork {k:02} of {l}: S0, then pb-run-fork {k} and pb-run-fork-block; the stage body and IO geometry of "
                     f"D12a's [{run['stage_lines'][k]}]; its IO claims are opened in phase 3, not in the fork")
    lines.append(f"phase 3 (join): the {l} forks in block order (pb-join-fork, pb-join-state, pb-join-in-claims, "
                 f"pb-join-out-claims), then pb-fork-s1 = {l}; then each of the {b} internal boundaries opened once in boundary "
                 f"order (block k's slot 22, then block k+1's slot 21), then the external input endpoint (block 0's slot 21), "
                 f"then the external output endpoint (block {l - 1}'s slot 22)")
    return lines


def registered_schedule_digest(run: dict) -> dict:
    import blake3
    lines = registered_schedule_lines(run)
    h = blake3.blake3()
    h.update(REG_SCHEDULE_DOMAIN)
    for s in lines:
        bs = s.encode()
        h.update(len(bs).to_bytes(8, "little"))
        h.update(bs)
    got, want = h.hexdigest(), bytes(run["schedule_digest"]).hex()
    return {"what": "blake3('hashline/private-run-fork-schedule/d55-registered-d60/1' + length-framed lines) -- "
                    "run_fork.rs schedule_lines, the registered branch (D60, review F6)",
            "lines": len(lines), "recomputed": got, "run_json": want, "equal": got == want}


def check_opening_geometry(sh: dict, where: str, r: dict, inv_rate: int, q: int) -> None:
    """one regular opening at R13's geometry (as `zk60_native_rg_w16.check_opening_geometry`)"""
    import zk60_native_rg_w16 as W
    W.check_opening_geometry(sh, where, r, inv_rate, q)


def pcs_geometry(b) -> dict:
    sh = b.run["shape"]
    inv_rate, q = R13_GEOMETRY
    if (int(sh["inv_rate"]), int(sh["opened_cols"]), int(sh["endpoint_inv_rate"])) != (inv_rate, q, inv_rate):
        raise ValueError(f"R13-1: the shape declares rate 1/{sh['inv_rate']}, Q {sh['opened_cols']}, endpoint rate "
                         f"1/{sh['endpoint_inv_rate']}; R13 fixes rate 1/{inv_rate}, Q {q} for both")
    md = b.run["mask_domain"]
    if (int(md["log_dom"]), int(md["columns"])) != MASK_GEOMETRY:
        raise ValueError(f"R13-1: the mask domain {md} is not M's own constants {MASK_GEOMETRY}")
    n = 0
    for st in b.stages:
        for r in st.roles:
            check_opening_geometry(sh, st.name, r, inv_rate, q)
            n += 1
        m = st.mask
        if len(m["columns"]) != MASK_GEOMETRY[1] or any(c["index"] >= 1 << MASK_GEOMETRY[0] for c in m["columns"]):
            raise ValueError(f"R13-1: {st.name} M opens {len(m['columns'])} columns, not {MASK_GEOMETRY[1]} over 2^{MASK_GEOMETRY[0]}")
    for i, r in enumerate(b.tail.roles):
        check_opening_geometry(sh, f"{b.tail.name} #{i}", r, inv_rate, q)
        n += 1
    return {"family": "R13", "inv_rate": inv_rate, "q": q, "pads": q, "mask_log_dom": MASK_GEOMETRY[0],
            "mask_columns": MASK_GEOMETRY[1], "regular_openings_checked": n, "tail_openings_checked": len(b.tail.roles)}


def r13_facts(b) -> dict:
    """refusals are ValueErrors with their reason"""
    run = b.run
    sh = run["shape"]
    block = sh["profile"]
    if not is_r13_block_profile(block) or run.get("block_profile") != block:
        raise ValueError(f"R13-1: the block profile {block!r} is not an R13 accuracy profile")
    if int(sh.get("dd_cap", 0)) > 0 or block.endswith(("-dd/1", "-ddict-v01/1", "-ddict1/1", "-ld-t32-dev/1", "-hh-t32-dev/1")):
        raise ValueError(f"R13-1: {block} is an R13 DD profile; SC_DD and the DD softmax twin are not ported (refused by name)")
    base = base_of(b.profile)
    if base is None:
        raise ValueError(f"R13-1: the run profile {b.profile!r} is not a REGISTERED D55 run profile (run.rs D55_RUN_PROFILES)")
    if R13_RUN_PROFILES.get(base) != block:
        raise ValueError(f"R13-1: the D55 base {base!r} is not the registered R13 run profile of {block!r}")
    line = run["parameter_line"]
    if not line.endswith(REG_LINE_TAIL) or D12A_LINE_TAIL in line:
        raise ValueError("R13-1: the parameter line is not a registered D55 run's (D12a's one-transcript clause replaced by "
                         f"{REG_LINE_TAIL!r})")
    if f"/L{b.blocks}/" not in line:
        raise ValueError(f"R13-1: the parameter line does not name L{b.blocks}")
    sd = registered_schedule_digest(run)
    if not sd["equal"]:
        raise ValueError(f"R13-1: run.json's schedule digest does not recompute from its own lines under the registered "
                         f"schedule ({sd})")
    cal = R.parse_calibration_line(run["layout_description"])
    stack = R.stack_of(block)
    if cal["stack"] != stack or not (17 <= cal["gate_common"] <= 24):
        raise ValueError(f"R13-1: the calibration line's stack {cal['stack']} / gate-common {cal['gate_common']}")
    if len(run["stage_lines"]) != b.blocks:
        raise ValueError(f"R13-1: {len(run['stage_lines'])} stage lines for {b.blocks} forks")
    geom = pcs_geometry(b)
    return {"block_profile": block, "name": R.ACCURACY_PROFILES[block][0], "run_profile": b.profile, "d55_base_run_profile": base,
            "run_profile_is_registered": True, "stack": stack, "registry": cal["registry"], "base": cal["base"],
            "gate_common": cal["gate_common"], "precision": cal["precision"], "wrho_s": int(sh["wrho_s"]),
            "log_cols": int(sh["log_cols"]), "d55_schedule_digest": sd, "pcs_geometry": geom}


# ---------------------------------------------------------------- R13-H: the REGISTERED header
def run_parameter_line(b, base_cal: dict) -> str:
    """the registered fork run's parameter line, RECOMPUTED from the shape,
    the calibration line's base and the boundary table: `protocol::
    parameter_line` (protocol.rs:132-152), then `run.rs::parameter_line`
    (:748-760) with its last clause replaced by the registered one
    (run_fork.rs:626-630)"""
    sh = b.run["shape"]
    block = (f"T{sh['tokens']}/d{sh['width']}/f{sh['hidden']}/H{sh['q_heads']}/KV{sh['kv_heads']}/dh{sh['head_dim']}"
             f"/log_cols{sh['log_cols']}/inv_rate{sh['inv_rate']}/Q{sh['opened_cols']}/P1"
             f"/sh-g{base_cal['gate']}-u0-h{base_cal['product']}-z{base_cal['down']}/two-private-endpoints/one-proof-one-transcript"
             f"/endpoint-log_n{sh['endpoint_log_n']}-rate{sh['endpoint_inv_rate']}-pad{sh['opened_cols']}-rows{sh['endpoint_rows']}")
    rows = b.run["internal_boundaries"][0]["rows"] if b.blocks > 1 else 0
    return (f"{block}/L{b.blocks}/boundary-log_n{sh['endpoint_log_n']}-rate{sh['endpoint_inv_rate']}-pad{sh['opened_cols']}"
            f"-rows{rows}-sites2/external-rows{sh['endpoint_rows']}{REG_LINE_TAIL}")


def registered_header(b, facts, rp_ok: bool, controls=True) -> dict:
    """D60 review F3 (ii): the REGISTERED header, recomputed and replayed.
    Every word the header absorbs is either recomputed here from the
    capture's public data (run-shape from the shape, the parameter line, the
    schedule digest) or a bound byte string the integrity part already checked
    (expected-IO against its SHA-256 and the parsed policy); the two digests
    of the statement (public-statement, calibration) are taken as bound bytes
    -- a capture does not carry the model statement they hash.  The replay
    (D55-3) then reproduces run_binding from these words.  Controls: the same
    run replayed as its TEST-ONLY identity (the prototype constructor string,
    parameter-line clause and schedule literal and lines), and one count of
    the registered schedule lines changed, must each be refused."""
    import zk60_native_rg_d55 as D
    run = b.run
    want_line = run_parameter_line(b, facts["base"])
    sd = registered_schedule_digest(run)
    f = []
    if run["parameter_line"] != want_line:
        f.append(f"the parameter line is not the one recomputed from the shape, the base and the boundary table: "
                 f"{run['parameter_line']!r} vs {want_line!r}")
    if not sd["equal"]:
        f.append("the registered schedule digest does not recompute")
    if bytes(run["transcript_domain_bytes"]).decode() != b.profile or b.profile != registered_d55_profile(facts["d55_base_run_profile"]):
        f.append("the transcript constructor's domain is not the registered D55 profile string")
    shape_words = [b.blocks, run["shape"]["tokens"], run["shape"]["width"], run["shape"]["hidden"], run["shape"]["q_heads"],
                   run["shape"]["kv_heads"], run["shape"]["head_dim"]]
    if run["run_shape_words"] != shape_words:
        f.append("run-shape words")
    rec = {"what": "the registered D55 header: constructor domain = the registered D55 profile; run-shape recomputed; "
                   "expected-IO bound (integrity); public-statement and calibration taken as bound digests; the parameter "
                   "line RECOMPUTED (protocol.rs parameter_line + run.rs run clauses + the registered clause); the schedule "
                   "digest RECOMPUTED (the registered literal and the F6 lines); run_binding reproduced by the replay",
           "parameter_line_recomputed": want_line == run["parameter_line"], "parameter_line": want_line,
           "schedule_digest": sd, "run_binding_reproduced_by_the_replay": rp_ok,
           "taken_as_bound_bytes": ["public-statement (the model statement's digest)", "calibration (its identity digest)"],
           "findings": f}
    if controls:
        ctl = {}
        # H-1: the same run under its TEST-ONLY identity (prototype strings throughout)
        test_profile = D.D55_PREFIX + facts["d55_base_run_profile"]
        r2 = copy.deepcopy(run)
        r2["parameter_line"] = run["parameter_line"][: -len(REG_LINE_TAIL)] + D.D55_LINE_TAIL
        r2["transcript_domain_bytes"] = list(test_profile.encode())
        r2["schedule_digest"] = list(bytes.fromhex(D.d55_schedule_digest(r2)["recomputed"]))
        b2 = copy.copy(b)
        b2.run = r2
        rp2 = D.D55Replay(b2).run()
        refused_facts = False
        try:
            b3 = copy.copy(b2)
            b3.profile = test_profile
            r13_facts(b3)
        except ValueError:
            refused_facts = True
        ctl["H-1 the run replayed as its test-only identity"] = {
            "what": "constructor domain, parameter-line clause, schedule literal and schedule lines all the prototype's",
            "run_binding_reproduced": rp2.run_binding_ok, "replay_failures": len(rp2.failures), "facts_refused": refused_facts,
            "fires": (rp2.run_binding_ok is False) and bool(rp2.failures) and refused_facts}
        # H-2: one count of the F6 schedule lines changed
        r4 = copy.deepcopy(run)
        lines = registered_schedule_lines(r4)
        r4["stage_lines"] = list(r4["stage_lines"])
        r4["stage_lines"][0] = r4["stage_lines"][0].replace("data rows", "data  rows", 1)
        ctl["H-2 one schedule line changed"] = {
            "what": "fork 00's quoted stage line changed by one byte (the digest is recomputed from the changed lines)",
            "lines": len(lines), "digest_equal": registered_schedule_digest(r4)["equal"],
            "fires": registered_schedule_digest(r4)["equal"] is False}
        # H-3: the parameter line's registered clause replaced (the recompute refuses)
        b5 = copy.copy(b)
        b5.run = dict(run, parameter_line=run["parameter_line"].replace("rows", "row", 1))
        ctl["H-3 the parameter line doctored"] = {
            "what": "one byte of the parameter line changed", "recomputed_equal": run_parameter_line(b5, facts["base"]) == b5.run["parameter_line"],
            "fires": run_parameter_line(b5, facts["base"]) != b5.run["parameter_line"]}
        ctl["ok"] = all(v["fires"] for v in ctl.values() if isinstance(v, dict))
        rec["controls"] = ctl
    rec["ok"] = not f and rp_ok and (rec.get("controls", {}).get("ok", True))
    return rec


# ---------------------------------------------------------------- R13-2: the layout
def r13_layout(b) -> dict:
    from zk60_native_rg_planes import PlaneIndex, PlaneIndexError
    try:
        index = PlaneIndex(b)
    except PlaneIndexError as exc:
        return {"refused": str(exc), "ok": False}
    pi = index.summary()
    r13 = R.check_plane_index(index, b.run["shape"])
    return {"plane_index": {kk: pi[kk] for kk in ("ok", "findings", "a_planes", "h_planes", "a_data_rows", "h_data_rows", "slots")},
            "plane_index_r13": r13, "ok": bool(pi["ok"] and r13["ok"])}


# ---------------------------------------------------------------- R13-3: the terminals
# [2026-11-02, this session] the ONE pin reading R13-3 needs to evaluate the
# two bilinear slots (8 SC_SCORE, 9 SC_PV): `zk60_native_rg_gqa` selects their
# definition by the bundle's argument.rs digest, and this tree's is not one it
# has read.  READ: frozen-r19b's argument.rs (bc0332e3..., the R13 reading
# `ARGUMENT_DEFINITIONS` already accepts as REPAIRED) against this tree's
# (86c9941d...): `define` (the function that builds every slot's polynomial,
# its 17 match arms, 955 lines) is BYTE-IDENTICAL (extracted and compared line
# for line; SC_SCORE's arm sha256 a7fe208fcb12..., SC_PV's f2001cf77c8c...).
# The other 570 changed lines are outside `define`: a #[cfg(test)] lapse-bits
# accessor, the Metal IR seam (`metal`, built on a TWIN transcript), the
# parallel / in-place private-table builders (priv_table_at / _into / _fill),
# and the prover's mask_eval via a precomputed eq table (mask_eval_eq).  This
# reading covers `define` ONLY; the other hunks are NOT read here.  Added in
# memory for the R13-3 call and removed after it.
ARGUMENT_RS_READING = {
    "86c9941de1996b555c90fcb79b24c8682651df1ff24efcdff0ff0238ea50e77b": (
        "the R13 reading's repaired definition: argument.rs `define` (all 23 slot polynomials, 955 lines) byte-identical "
        "to frozen-r19b's bc0332e3...; read 2026-11-02 for the D60 privacy gate (define only; the prover-side and Metal "
        "hunks outside it are not read)"),
}


class argument_reading:
    """the in-memory `ARGUMENT_DEFINITIONS` entry above, for one call"""

    def __enter__(self):
        import zk60_native_rg_gqa as GQ
        self.added = [d for d in ARGUMENT_RS_READING if d not in GQ.ARGUMENT_DEFINITIONS]
        for d in self.added:
            GQ.ARGUMENT_DEFINITIONS[d] = (GQ.REPAIRED, ARGUMENT_RS_READING[d])
        self.removed = None
        return self

    def __exit__(self, *exc):
        import zk60_native_rg_gqa as GQ
        for d in self.added:
            GQ.ARGUMENT_DEFINITIONS.pop(d, None)
        self.removed = all(d not in GQ.ARGUMENT_DEFINITIONS for d in self.added)
        return False


class D55BlockShim:
    """ONE fork (or a list of forks) of a D55 bundle as `check_terminals` /
    `r13blocks.check_stage` read a run bundle: the forks renumbered 0.., the
    run header with the shape carrying `trained_calibration`, the eleven
    constants `cal_values` and `extra` (`norm_wrho`).  The shim carries no
    stage lines: each fork's own calibration clauses are applied to
    `cal_values` by the caller (so no clause is applied twice)."""

    def __init__(self, b, cal_values, blocks=None, extra=None):
        import zk60_native_rg_tokenblocks as TB
        self.d55_bundle = b
        self.dir = b.dir
        self.schema = b.schema
        self.profile = b.run.get("block_profile")
        self.manifest = b.manifest
        self.hash_rule = b.hash_rule
        self.hash_rule_record = b.hash_rule_record
        self.public_tables_included = b.public_tables_included
        self.block_ids = list(range(b.blocks)) if blocks is None else list(blocks)
        self.blocks = len(self.block_ids)
        self.stages = [TB._BlockStageView(b.stages[k], i) for i, k in enumerate(self.block_ids)]
        self.run = {kk: v for kk, v in b.run.items() if kk != "stage_lines"}
        shape = dict(b.run["shape"])
        if cal_values is not None:
            shape.update({"trained_calibration": True, **cal_values, **(extra or {})})
        self.run["shape"] = shape
        self.shape = RB.Shape(shape, b.run["mask_domain"])

    @property
    def name(self):
        return f"{self.d55_bundle.name} [forks {self.block_ids}]"

    def with_shape(self, shape):
        s = copy.copy(self)
        s.run = dict(self.run)
        s.run["shape"] = shape
        s.shape = RB.Shape(shape, self.run["mask_domain"])
        return s

    def boundary(self, j):
        raise IndexError("a one-fork shim has no internal boundary (the port never reads one)")


class _ForkReplayView:
    """the D55 replay with `stages[i]` = fork `block_ids[i]`'s record"""

    def __init__(self, rp, block_ids):
        self._rp = rp
        self.stages = [rp.stages[k] for k in block_ids]
        self.failures = rp.failures

    def summary(self):
        return self._rp.summary()


def fork_calibrations(b, facts) -> list:
    """per fork: the line's base with the fork's own clauses (D12a's stage
    line, quoted in the registered schedule the header absorbs) applied, and
    its precision"""
    from zk60_native_rg_r13blocks import BASE_OF_SHAPE_KEY
    out = []
    for k, line in enumerate(b.run["stage_lines"]):
        base = dict(facts["base"])
        own = SCAL.own_clauses(line)
        for key, v, run_v in own:
            bk = BASE_OF_SHAPE_KEY[key]
            if base[bk] != run_v:
                raise ValueError(f"R13-3: fork {k}'s own clause says the run's {key} is {run_v}, the line base {base[bk]}")
            if v == run_v:
                raise ValueError(f"R13-3: fork {k}'s own {key} equals the run's")
            base[bk] = v
        shifts = {"norm_tn": base["tn"], "qkv": base["qkv"], "score": base["score"], "pv": base["o"], "ao": base["ao"],
                  "gate": base["gate"], "up": 0, "product": base["product"], "down": base["down"]}
        out.append({"fork": k, "own_clauses": own, "base": base, "precision": R.derive_precision(facts["stack"], shifts)})
    return out


def _ctx(facts, cal, gate_shift, wrho_s, counts):
    h24 = facts["stack"] == "LowH24"
    rc = R.R13Ctx(facts["stack"], cal["precision"], gate_shift, wrho_s, counts, 16 if h24 else 24)
    rc.base = cal["base"]
    return rc


def _shim_for(b, k, cal):
    from zk60_native_rg_r13blocks import SHAPE_KEY_OF_BASE
    cal_values = {SHAPE_KEY_OF_BASE[kk]: int(v) for kk, v in cal["base"].items()}
    return D55BlockShim(b, cal_values, blocks=[k], extra={"norm_wrho": b.run["shape"]["norm_wrho"]})


def r13_terminals(b, rp, facts, controls=True, forks=None, control_fork=None) -> dict:
    with argument_reading() as rd:
        rec = _r13_terminals(b, rp, facts, controls=controls, forks=forks, control_fork=control_fork)
    rec["argument_rs_reading"] = {"added_in_memory": rd.added, "removed_after": rd.removed,
                                  "reading": {d[:12]: v for d, v in ARGUMENT_RS_READING.items()}}
    return rec


def _r13_terminals(b, rp, facts, controls=True, forks=None, control_fork=None) -> dict:
    """R13-3: all 23 slots per fork at its own calibration and its recovered
    G_k; the R13 block port's controls on `control_fork` (default: the
    interior fork 1, else 0).  `forks`: evaluate only these (a bounded-cost
    run; the record names the rest as NOT evaluated)."""
    import zk60_native_rg_r13blocks as RBK
    import zk60_native_rg_terminals as T
    from zk60_native_rg_planes import PlaneIndex
    t0 = time.time()
    sh = b.run["shape"]
    rec = {"what": "the per-slot terminal identity of all 23 slots on every fork of a registered R13 D55 run, at the fork's own "
                   "calibration and its own R13 gate denominator (recovered on SC_FZC), the R13 block port unchanged",
           "privacy_acceptance": False}
    full = D55BlockShim(b, None)
    index = PlaneIndex(full)
    ls = sum(1 for p in index.a_planes if p.name.startswith("A_SR") and p.name[4:].isdigit())
    counts = {"ls": ls, "h24": facts["stack"] == "LowH24", "dd": int(sh.get("dd_cap", 0)) > 0}
    sp = T.check_source_pins(full)
    rec["source_pins"] = {kk: sp[kk] for kk in ("ok", "pins_that_moved", "pins_missing_from_the_bundle", "pins_at_an_accepted_second_digest",
                                                "bilinear_definition_selected_by_the_argument_pin")}
    rec["source_pins_applied"] = False
    rec["source_pins_note"] = ("the R13 terminal port's own pin check is RUN AND REPORTED, not applied: the slot figures below are "
                               "computed on the bundle as given. [gate round 26] Every pin it refuses must be read by "
                               "zk60_native_rg_w16.classify_pins (at r19b, or by a W16 / R26 reading); the D55 driver checks "
                               "that (PINS.terminal_port_refusals) and the record is DEV-PASS at best otherwise")
    cals = fork_calibrations(b, facts)
    evaluated = [c for c in cals if forks is None or c["fork"] in forks]
    rec["forks_evaluated"] = [c["fork"] for c in evaluated]
    rec["forks_not_evaluated"] = [c["fork"] for c in cals if c not in evaluated]
    tables = bool(b.public_tables_included)
    per, shims, views, rcs, gates = [], {}, {}, {}, {}
    for c in evaluated:
        k = c["fork"]
        ts = time.time()
        shim = _shim_for(b, k, c)
        view = _ForkReplayView(rp, [k])
        # G_k: the class value(s) that close SC_FZC; exactly one must
        closes = []
        for g in GATE_CLASS:
            row = RBK.check_stage(shim, index, view, _ctx(facts, c, g, sh["wrho_s"], counts))
            if SC_FZC in row["equal"]:
                closes.append(g)
                best = row
        g_k = closes[0] if len(closes) == 1 else None
        if g_k is None:
            row = RBK.check_stage(shim, index, view, _ctx(facts, c, facts["gate_common"], sh["wrho_s"], counts))
        else:
            row = best
        opened = row.get("open_by_capture_option", [])
        expected = sh["n_slots"] - len(opened)
        ok = (g_k is not None and len(row["equal"]) == expected and set(row["equal"]).isdisjoint(opened)
              and all(e["slot"] in opened for e in row["not_checked"]) and not row.get("structure_failures")
              and not row.get("digest_failures") and row.get("group_factor_ok") is not False)
        per.append({"fork": k, "gate_shift_recovered": g_k, "gate_values_closing_sc_fzc": closes,
                    "gate_common_of_the_line": facts["gate_common"], "own_clauses": c["own_clauses"],
                    "slot_checks_equal": len(row["equal"]), "slot_checks_expected": expected,
                    "equal": row["equal"], "checked_not_equal": sorted(set(row["checked"]) - set(row["equal"])),
                    "refused_or_open": [{"slot": e["slot"], "why": e["why"][:200]} for e in row["not_checked"]],
                    "open_by_capture_option": opened, "captured_tables": row.get("captured_tables"),
                    "rebuilt_tables": len(row.get("rebuilt_tables") or []), "structure_failures": row.get("structure_failures"),
                    "digest_failures": row.get("digest_failures"), "group_factor_ok": row.get("group_factor_ok"),
                    "seconds": round(time.time() - ts, 1), "ok": ok})
        shims[k], views[k], rcs[k], gates[k] = shim, view, _ctx(facts, c, g_k or facts["gate_common"], sh["wrho_s"], counts), g_k
    rec["per_fork"] = per
    rec["tables_included"] = tables
    if not tables:
        rec["what_is_not_checked_without_tables"] = "the twelve statement-table slots are OPEN per fork (capture option)"
    ctl = {}
    if controls and per:
        kc = control_fork if control_fork is not None else (1 if 1 in shims else min(shims))
        ctl = RBK.r13_controls(b, [shims[kc]], [views[kc]], [rcs[kc]], index)
        ctl["on_fork"] = kc
        # R13-G2: the recovery itself -- the class value of the OTHER fork (when it differs)
        others = sorted({g for f, g in gates.items() if g is not None and g != gates[kc]})
        if others:
            rc_o = copy.copy(rcs[kc])
            rc_o.gate_shift = others[0]
            got = RBK._failing(RBK.check_stage(shims[kc], index, views[kc], rc_o))
            ctl["R13-G2_another_forks_gate_denominator"] = {"perturbation": f"fork {kc} evaluated at fork {[f for f, g in gates.items() if g == others[0]][0]}'s G = {others[0]}",
                                                            "predicted": [SC_FZC], "failing": sorted(got), "fires": got == {SC_FZC}}
    rec["controls"] = ctl
    fired = [v["fires"] for v in ctl.values() if isinstance(v, dict) and "fires" in v]
    rec["controls_ok"] = bool(fired) and all(fired) if controls else None
    rec["seconds"] = round(time.time() - t0, 1)
    rec["ok"] = (not rec["forks_not_evaluated"] and bool(per) and all(p["ok"] for p in per) and tables
                 and (rec["controls_ok"] if controls else True))
    return rec
