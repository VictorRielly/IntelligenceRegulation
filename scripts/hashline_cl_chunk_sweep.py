#!/usr/bin/env python3
"""[ZK60-CL6] Chunk-row scheduling for the chunked hiding commitment.

Two subcommands. Neither opens a device, queries the driver, or launches anything.

  plan     Count the chunked path's device bytes for ONE hiding-commitment
           shape at every candidate chunk-row choice (reusing
           hashline_memory_plan.commitment_plan in mode "chunked"), and SELECT
           a chunk-row count deterministically against an EXPLICIT scratch
           budget. The budget is an operator argument. Nominal VRAM is not
           free memory, and this tool never reads free memory.
  measure  Reconcile prover logs taken at different chunk-row choices. Every
           log is first held to the validated-row contract [ZK60-CL14]: a
           KNOWN successful exit (three channels, below), a `PASS* ACCEPT`
           verdict, verified+serialized, finite POSITIVE clocks that contain
           each other, shape/privacy/coverage labels, ONE proof identity
           across the PROOF line / PASS line / HASHLINE_TIMING / CL6_RUN,
           `gpu: ON` agreeing with gpu_requested/gpu_enabled, and the prover
           phases inside the clocks — the CL5 gate (hashline_cl_profile
           parse_log + attribute), reused as is. Only then must the proof
           digest and byte length be IDENTICAL across the set (chunk rows are
           a memory decision, not a proof decision) and the shape / device /
           cache / verdict metadata identical; the per-commit chunked timings
           the prover prints under HL_GPU_VERBOSE=1 are tabulated next to the
           plan. A row without exit evidence is `missing-evidence`, never a
           success. Nothing here promotes a chunk-row selector: equal digests
           and single-box seconds are not a speed ranking.

Examples:
  python3 scripts/hashline_cl_chunk_sweep.py plan --p3-weights 4096 14336 \\
      --choices 128,256,512,1024 --scratch-budget-mib 768
  python3 scripts/hashline_cl_chunk_sweep.py measure --log 128:1=a.log --log 256:1=b.log \\
      --sweep-log results/cl6_chunk_sweep.log
  python3 scripts/hashline_cl_chunk_sweep.py measure --log 128=a.log --exit 128=0

`measure` prints the full machine-readable report (inputs and their digests,
one row per log with its evidence channels and gate outcome, the
reconciliation OR the refusal) on stdout in BOTH outcomes and exits 2 on a
refusal, so a refused sweep still leaves a record of why.

The device's own rules are mirrored exactly (hashline/src/gpu/cuda.rs):
  chunk_rows()  clamps the choice to >= 128 and does NOT round it;
  chunk_plan()  takes ALL rows as one chunk when rows <= choice, else steps of
                (choice // 128) * 128 with a short final chunk.
"""

import argparse
import hashlib
import importlib.util
import json
import math
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))


def _sibling(name):
    """Import a sibling script by path (scripts/ is not a package)."""
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, name + ".py"))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


memplan = _sibling("hashline_memory_plan")
# [ZK60-CL14] the CL5 validated-row contract (parse_log + attribute) is
# REUSED, not re-implemented: a prover log is "evidence" by one definition in
# this repo, and the chunk sweep adds only what CL5 cannot know (the CL6_RUN
# exit channel, the sweep-log binding, the chunk-plan-vs-label check).
profile = _sibling("hashline_cl_profile")

MIB = 1024 ** 2
MIN_CHUNK_ROWS = 128      # cuda.rs chunk_rows(): `.max(128)`
B3_STATE_SLOTS = 8 * 24 + 1


class ChunkSweepError(ValueError):
    """A refusal: unsupported input, an overflowing budget, or logs that disagree."""


# --------------------------------------------------------------------------- plan

def effective_chunk_rows(choice):
    """`chunk_rows()`: the environment value clamped to >= 128, NOT rounded."""
    if type(choice) is not int or choice < 1:
        raise ChunkSweepError("chunk-row choice must be a positive integer")
    return max(MIN_CHUNK_ROWS, choice)


def chunk_plan(rows, chunk):
    """`chunk_plan()` from cuda.rs: (row0, rc) per chunk."""
    if type(rows) is not int or rows < 1:
        raise ChunkSweepError("rows must be a positive integer")
    if rows <= chunk:
        return [(0, rows)]
    step = max(1, chunk // MIN_CHUNK_ROWS) * MIN_CHUNK_ROWS
    out, r0 = [], 0
    while r0 < rows:
        rc = min(step, rows - r0)
        out.append((r0, rc))
        r0 += rc
    return out


def plan_summary(rows, chunk):
    """`chunk_plan` in closed form (chunk count, largest chunk, final chunk),
    so a huge row count is refused by the planner rather than enumerated."""
    if type(rows) is not int or rows < 1:
        raise ChunkSweepError("rows must be a positive integer")
    if rows <= chunk:
        return {"chunks": 1, "rmax": rows, "final": rows}
    step = max(1, chunk // MIN_CHUNK_ROWS) * MIN_CHUNK_ROWS
    chunks = -(-rows // step)
    return {"chunks": chunks, "rmax": step, "final": rows - (chunks - 1) * step}


def rmax_for(rows, chunk):
    """The largest chunk the device will actually allocate scratch for."""
    return plan_summary(rows, chunk)["rmax"]


def commit_scratch_bytes(rows, log_cols, inv_rate, chunk):
    """The poolable scratch `commit_zk_chunked` takes with take_min:
    coef (rmax*n), coef2 (rmax*nn), enc (rmax*nn), blake3 column state.
    Excludes the retained data/pads/powers and the raw leaf buffer, which
    the full component count (commitment_plan) carries."""
    n, nn = 1 << log_cols, (1 << log_cols) * inv_rate
    rmax = rmax_for(rows, chunk)
    state = B3_STATE_SLOTS * nn * 4
    return {"rmax": rmax, "coef": rmax * n * 8, "coef2": rmax * nn * 8, "enc": rmax * nn * 8,
            "blake3_state": state, "total": rmax * n * 8 + 2 * rmax * nn * 8 + state}


def sweep(rows, log_cols=14, inv_rate=4, q_pad=None, choices=(128, 256, 512, 1024),
          prior_live_bytes=0, prior_pool_bytes=0, checks=256):
    """One row per candidate: the device-mirrored plan and the chunked-mode
    component peak from the CL3 planner. Pure arithmetic."""
    seen, out = set(), []
    for choice in choices:
        chunk = effective_chunk_rows(choice)
        # the planner validates the shape FIRST (index widths, rates, pads)
        report = memplan.commitment_plan(rows, log_cols, inv_rate, checks, q_pad, None,
                                         prior_live_bytes, prior_pool_bytes, None,
                                         mode="chunked", chunk_rows=chunk)
        plan = plan_summary(rows, chunk)
        scratch = commit_scratch_bytes(rows, log_cols, inv_rate, chunk)
        if report["chunk_rows"] != scratch["rmax"]:
            raise ChunkSweepError(
                f"planner rmax {report['chunk_rows']} disagrees with the device plan's {scratch['rmax']} "
                f"at rows {rows}, choice {choice}; refusing to select on a mismatched count")
        row = {"choice": choice, "chunk_rows": chunk, "rmax": scratch["rmax"], "chunks": plan["chunks"],
               "final_chunk_rows": plan["final"], "ragged": plan["chunks"] > 1 and plan["final"] != plan["rmax"],
               "commit_scratch_bytes": scratch["total"], "commit_scratch_mib": scratch["total"] / MIB,
               "component_peak_bytes": report["component_peak_accounted_bytes"],
               "component_peak_mib": report["component_peak_accounted_bytes"] / MIB,
               "subtotal_with_prior_bytes": report["subtotal_accounted_bytes"]}
        key = (row["rmax"], row["chunks"])
        row["duplicate_of_smaller_choice"] = key in seen
        seen.add(key)
        out.append(row)
    return out


def select(rows, log_cols, inv_rate, q_pad, choices, scratch_budget_bytes,
           device_total_bytes=None, prior_live_bytes=0, prior_pool_bytes=0, checks=256):
    """Deterministic: the LARGEST candidate whose commit scratch fits the
    explicit budget. Refuses a budget that is not a positive integer, one that
    exceeds the device's nominal capacity (so the budget cannot be "all of
    VRAM"), and a shape where even the 128-row minimum does not fit."""
    if type(scratch_budget_bytes) is not int or scratch_budget_bytes < 1:
        raise ChunkSweepError("scratch budget must be a positive integer number of bytes")
    if device_total_bytes is not None:
        if type(device_total_bytes) is not int or device_total_bytes < 1:
            raise ChunkSweepError("device total must be a positive integer number of bytes")
        if scratch_budget_bytes >= device_total_bytes:
            raise ChunkSweepError(
                f"scratch budget {scratch_budget_bytes} B is not below the device's nominal "
                f"{device_total_bytes} B; nominal VRAM is not free memory and cannot be the budget")
    rows_out = sweep(rows, log_cols, inv_rate, q_pad, choices, prior_live_bytes, prior_pool_bytes, checks)
    fitting = [r for r in rows_out if r["commit_scratch_bytes"] <= scratch_budget_bytes]
    for r in rows_out:
        r["fits_budget"] = r["commit_scratch_bytes"] <= scratch_budget_bytes
    if not fitting:
        smallest = min(rows_out, key=lambda r: r["commit_scratch_bytes"])
        raise ChunkSweepError(
            f"no candidate fits: the smallest choice ({smallest['choice']} rows) needs "
            f"{smallest['commit_scratch_bytes']} B of commit scratch against a budget of {scratch_budget_bytes} B")
    chosen = max(fitting, key=lambda r: (r["rmax"], -r["chunks"]))
    return {"schema": 1, "scope": "one chunked hiding commitment; commit scratch vs an explicit budget",
            "measured": False, "safe_to_run": False,
            "shape": {"rows": rows, "log_cols": log_cols, "inv_rate": inv_rate, "q_pad": q_pad},
            "scratch_budget_bytes": scratch_budget_bytes, "device_total_bytes": device_total_bytes,
            "selected_choice": chosen["choice"], "selected_chunk_rows": chosen["chunk_rows"],
            "selected_rmax": chosen["rmax"], "candidates": rows_out,
            "rule": "largest candidate whose commit scratch (coef + coef2 + enc + blake3 state) <= budget",
            "not_counted": ["the opening's re-encode scratch (same coef/coef2/enc sizes, no state, plus rows*q_open output)",
                            "other live commitments, helpers, zero-check tables, CUDA context",
                            "whether the budget itself is available on the device"]}


# ------------------------------------------------------------------------ measure
#
# [ZK60-CL14] Codex's round-9 review reproduced a hole: a log whose
# HASHLINE_TIMING said prove_s -1 and which the runner closed with `exit 1`
# came out of parse_measured_log + reconcile as prove_s=-1 and
# byte_identical_across_choices=true. The old measure asked only for
# `gpu: ON`, a PROOF line, verified:true and one consistent byte count; it
# never saw an exit status and never looked at a clock. Now every row passes
# the CL5 contract plus the checks below BEFORE reconcile compares digests
# or ranks prove_vs_fastest, and a row with no exit evidence at all is
# classified `missing-evidence` (absence is not success).
#
# Exit status reaches the parser through three channels; a nonzero exit or a
# disagreement between channels is refused:
#   (a) --exit LABEL=N on the command line (exit_code= in the API);
#   (b) a `exit N` line in the per-run log (the CL5 runner's convention, read
#       by hashline_cl_profile.parse_log as EXIT_LINE);
#   (c) the sweep runner's `CL6_RUN chunk_rows=<c> rep=<r> exit=<n>
#       sha256=<h> bytes=<b>` line. results/cl6_chunk_sweep.sh tees it into
#       BOTH the per-run log and the sweep log; --sweep-log binds the sweep
#       log's lines to the rows by (chunk_rows, rep) and cross-checks their
#       sha256/bytes against each per-run log's PROOF line.

_GPU_ON = re.compile(r"^\s*gpu: ON\b", re.MULTILINE)
_GPU_OFF = re.compile(r"^\s*gpu: off\b", re.MULTILINE)
_PROOF = re.compile(r"^PROOF sha256 ([0-9a-f]{64}) \((\d+) B\)", re.MULTILINE)
_TIMING = re.compile(r"^HASHLINE_TIMING (\{.*\})\s*$", re.MULTILINE)
_VRAM = re.compile(r"vram peak (\d+) MB")
_COMMIT = re.compile(r"chunked ZK commit rows (\d+) 2\^(\d+) -> 2\^(\d+) \(q (\d+)\) in (\d+) chunks of <= (\d+): ([0-9.]+) s")
_REENC = re.compile(r"chunked ZK re-encode \+ gather rows (\d+) \((\d+) chunks(?:, fused[^)]*)?\): ([0-9.]+) s")
_ROUTE = re.compile(r"zk commit rows (\d+) [^\n]*: CHUNKED \(([^)]+)\)")
_LAYER = re.compile(r"^\s*layer\s+(\d+): prove ([0-9.]+) s, (\d+) B", re.MULTILINE)
# results/cl6_chunk_sweep.sh writes `CL6_RUN chunk_rows=$c rep=$i exit=$rc
# sha256=$(sha256sum ..) bytes=$(stat ..)`; sha256/bytes are EMPTY when the
# run left no proof file, and that emptiness is evidence too
_CL6_RUN = re.compile(r"^CL6_RUN chunk_rows=(\d+) rep=(\d+) exit=(\d+) sha256=([0-9a-f]*) bytes=(\d*)\s*$", re.MULTILINE)
_LABEL = re.compile(r"^(\d+)(?::(\d+))?$")
# the sweep log's provenance and half-1 lines (informational, recorded verbatim)
_SWEEP_HEAD = re.compile(r"^HEAD\s+([0-9a-f]{7,64})\s*$", re.MULTILINE)
_SWEEP_DIRTY = re.compile(r"^dirty\s+(\d+) tracked", re.MULTILINE)
_SWEEP_BINARY = re.compile(r"^binary\s+([0-9a-f]{64})\s+(\d+) B", re.MULTILINE)
_SWEEP_GATE = re.compile(r"^GATE OK\s+zkv3 forced-chunk rows=(\d+)\s+([0-9a-f]{64})\s+(\d+) B", re.MULTILINE)
_SWEEP_FAILURE = re.compile(r"^FAILURE: .*$", re.MULTILINE)
SWEEP_GREEN = "CL6 SWEEP GREEN"

CLOCKS = profile.CLOCKS            # witness_s, prove_s, serialize_s, proof_ready_s, verify_s
CLASS_ELIGIBLE, CLASS_REFUSED, CLASS_MISSING = "eligible", "refused", "missing-evidence"
_EXIT_CHANNELS = ("argument", "exit line", "CL6_RUN (per-run log)", "CL6_RUN (sweep log)")
# the CL5 gate's reasons that report an ABSENT item (as opposed to a present
# but wrong one); they classify a row as missing-evidence, not refused
_CL5_ABSENCE = ((re.compile(r"^exit code unknown"), "exit"),
                (re.compile(r"^no PASS "), "PASS"),
                (re.compile(r"^no PROOF "), "PROOF"),
                (re.compile(r"^no `prover phases` block"), "phases"),
                (re.compile(r"^coverage label missing"), "coverage"),
                (re.compile(r"^clock (\w+) missing"), "clock:{0}"))
_UNIFORM_FIELDS = ("privacy", "coverage", "layers", "tokens", "d", "f", "randomness",
                   "verdict", "device", "gpu_requested", "gpu_enabled", "cache_state", "wcache")


def split_label(label):
    """`128` -> (128, None); `128:2` -> (128, 2); anything else -> (None, None).
    A free label binds to no sweep-log line and is not checked against the
    log's chunk plan; it is still gated like every other row."""
    m = _LABEL.match(str(label))
    if not m:
        return None, None
    return int(m.group(1)), (int(m.group(2)) if m.group(2) is not None else None)


def _cl6_fields(groups):
    c, r, x, sha, nbytes = groups
    return {"chunk_rows": int(c), "rep": int(r), "exit": int(x), "sha256": sha or None,
            "bytes": int(nbytes) if nbytes else None}


def _cl6_text(run):
    return (f"chunk_rows={run['chunk_rows']} rep={run['rep']} exit={run['exit']} "
            f"sha256={(run['sha256'] or '')[:16]}.. bytes={run['bytes']}")


def parse_sweep_log(text, path=None):
    """The sweep runner's log: its CL6_RUN records (one per (chunk_rows, rep);
    two for the same run make the log unbindable and are refused), plus the
    provenance header, the half-1 frozen-fixture gates, FAILURE lines and the
    GREEN verdict, recorded as they are."""
    runs, seen = [], {}
    for n, line in enumerate(text.splitlines(), 1):
        m = _CL6_RUN.match(line)
        if not m:
            continue
        run = _cl6_fields(m.groups())
        run["line"] = n
        key = (run["chunk_rows"], run["rep"])
        if key in seen:
            raise ChunkSweepError(
                f"sweep log {path or ''} carries two CL6_RUN lines for chunk_rows={key[0]} rep={key[1]} "
                f"(lines {seen[key]} and {n}); one run, one record")
        seen[key] = n
        runs.append(run)
    if not runs:
        raise ChunkSweepError(f"sweep log {path or ''} has no CL6_RUN line; nothing to bind rows to")
    head, dirty, binary = _SWEEP_HEAD.search(text), _SWEEP_DIRTY.search(text), _SWEEP_BINARY.search(text)
    return {"path": path, "runs": runs,
            "identity": {"head": head.group(1) if head else None,
                         "dirty_tracked_files": int(dirty.group(1)) if dirty else None,
                         "binary_sha256": binary.group(1) if binary else None,
                         "binary_bytes": int(binary.group(2)) if binary else None},
            "frozen_fixture_gates": [{"chunk_rows": int(c), "sha256": s, "bytes": int(b)}
                                     for c, s, b in _SWEEP_GATE.findall(text)],
            "failure_lines": _SWEEP_FAILURE.findall(text),
            "green": SWEEP_GREEN in text}


def _json_safe(v):
    """NaN/inf are recorded as text ("nan", "inf"), never emitted as numbers."""
    if isinstance(v, float) and not math.isfinite(v):
        return repr(v)
    return v


def _positive_finite(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) and v > 0


def clock_reasons(t):
    """[ZK60-CL14] One NAMED outcome per bad clock: absent (missing evidence),
    not a number, NaN, infinite, negative, zero; then the containment
    contradictions (a part larger than the proof_ready_s that contains it).
    The witness+prove+serialize <= proof_ready_s + tolerance rule is the CL5
    gate's (proof_ready_unknown_s below -tolerance) and is not restated here
    with a second tolerance. Returns (hard reasons, missing {key: text}, clocks)."""
    reasons, missing, clocks = [], {}, {}
    for k in CLOCKS:
        v = t.get(k)
        clocks[k] = _json_safe(v)
        if v is None:
            missing[f"clock:{k}"] = f"clock {k} absent from HASHLINE_TIMING"
        elif isinstance(v, bool) or not isinstance(v, (int, float)):
            reasons.append(f"clock {k} is not a number ({v!r})")
        elif math.isnan(v):
            reasons.append(f"clock {k} is NaN")
        elif math.isinf(v):
            reasons.append(f"clock {k} is infinite ({v})")
        elif v < 0:
            reasons.append(f"clock {k} is negative ({v})")
        elif v == 0:
            reasons.append(f"clock {k} is zero: a stage that took no time did not run")
    good = {k: float(t[k]) for k in CLOCKS if _positive_finite(t.get(k))}
    ready = good.get("proof_ready_s")
    if ready is not None:
        for k in ("witness_s", "prove_s", "serialize_s"):
            if k in good and good[k] > ready:
                reasons.append(f"contradictory clocks: {k} ({good[k]}) exceeds proof_ready_s ({ready}), which contains it")
    return reasons, missing, clocks


def _exit_evidence(exit_code, exit_lines, cl6_in_log, cl6_in_sweep):
    """Resolve the exit status across the channels. None from every channel
    is MISSING evidence; two different values are a conflict; one agreed
    value is the exit, refused when nonzero."""
    found = {"argument": exit_code,
             "exit line": exit_lines[0] if len(exit_lines) == 1 else None,
             "CL6_RUN (per-run log)": cl6_in_log["exit"] if cl6_in_log else None,
             "CL6_RUN (sweep log)": cl6_in_sweep["exit"] if cl6_in_sweep else None}
    ev = {"channels": found, "resolved": None, "resolved_source": None, "reasons": [], "missing": {}}
    distinct = {v for v in found.values() if v is not None} | set(exit_lines)
    if not distinct:
        ev["missing"]["exit"] = ("exit status: no --exit, no `exit N` line, no CL6_RUN line in the log, "
                                 "no bound sweep-log CL6_RUN line")
    elif len(distinct) > 1:
        detail = ", ".join(f"{ch}={v}" for ch, v in found.items() if v is not None)
        if len(exit_lines) > 1:
            detail += f", exit lines={exit_lines}"
        ev["reasons"].append(f"exit evidence conflicts: {detail}")
    else:
        (value,) = distinct
        ev["resolved"] = value
        ev["resolved_source"] = next((ch for ch in _EXIT_CHANNELS if found[ch] is not None), "exit line")
        if value != 0:
            ev["reasons"].append(f"exit code {value} != 0 ({ev['resolved_source']}): a failed invocation is not a measurement")
    return ev


def _cl6_conflicts(run, where, choice, rep, proof):
    out = []
    if choice is not None and run["chunk_rows"] != choice:
        out.append(f"{where} says chunk_rows={run['chunk_rows']} but the label says {choice}")
    if rep is not None and run["rep"] != rep:
        out.append(f"{where} says rep={run['rep']} but the label says {rep}")
    if run["sha256"] is None or run["bytes"] is None:
        out.append(f"{where} recorded no proof file (sha256/bytes empty): the run wrote no proof")
    elif proof is not None and (run["sha256"], run["bytes"]) != (proof["sha256"], proof["bytes"]):
        out.append(f"{where} says sha256 {run['sha256'][:16]}../{run['bytes']} B but the PROOF line says "
                   f"{proof['sha256'][:16]}../{proof['bytes']} B")
    return out


def _bind_sweep_run(sweep, label, choice, rep):
    """ONE sweep-log CL6_RUN line per row, by (chunk_rows, rep).
    Returns (run or None, hard reasons, missing {key: text})."""
    if choice is None:
        return None, [f"cannot bind label {label!r} to the sweep log: it names no chunk-row choice "
                      f"(use CHOICE or CHOICE:REP) and the log has no CL6_RUN line"], {}
    cands = [r for r in sweep["runs"] if r["chunk_rows"] == choice and (rep is None or r["rep"] == rep)]
    if not cands:
        return None, [], {"sweep-run": f"sweep log {sweep.get('path') or ''} has no CL6_RUN line for "
                                       f"chunk_rows={choice} rep={rep if rep is not None else 'any'}"}
    if len(cands) > 1:
        return None, [f"label {label!r} binds to {len(cands)} sweep-log runs (reps {[r['rep'] for r in cands]}); "
                      f"name the rep as {choice}:REP"], {}
    return cands[0], [], {}


def _chunk_plan_conflicts(choice, commits, reencs):
    """The label claims a chunk-row choice; the log's own chunk lines must be
    the device plan for that choice (the mirror at the top of this file)."""
    out = []
    if choice is None:
        return out
    if choice < 1:
        return [f"label {choice} is not a chunk-row choice"]
    chunk = effective_chunk_rows(choice)
    for c in commits:
        plan = plan_summary(c["rows"], chunk)
        if (c["chunks"], c["rmax"]) != (plan["chunks"], plan["rmax"]):
            out.append(f"label says chunk rows {choice} but the log committed {c['rows']} rows in {c['chunks']} chunks "
                       f"of <= {c['rmax']}; the device plan for {choice} is {plan['chunks']} chunks of <= {plan['rmax']}")
    for r in reencs:
        plan = plan_summary(r["rows"], chunk)
        if r["chunks"] != plan["chunks"]:
            out.append(f"label says chunk rows {choice} but the log re-encoded {r['rows']} rows in {r['chunks']} chunks; "
                       f"the device plan for {choice} is {plan['chunks']} chunks")
    return out


def _absence_key(reason):
    for rx, key in _CL5_ABSENCE:
        m = rx.match(reason)
        if m:
            return key.format(*m.groups())
    return None


def _timing_lenient(blob):
    """The TIMING JSON with NaN/Infinity kept as floats so each bad clock can
    be NAMED; the CL5 parser refuses the whole line at parse (correct) but
    names no field for a bare NaN."""
    try:
        return json.loads(blob, parse_constant=float), None
    except json.JSONDecodeError as e:
        return None, f"HASHLINE_TIMING is not parseable JSON ({e.msg} at column {e.pos})"


def parse_measured_log(text, label, exit_code=None, sweep_runs=None, strict=True):
    """One GATED row per prover log.

    `exit_code` is channel (a); `sweep_runs` is parse_sweep_log()'s result for
    channel (c) via the sweep log; channels (b) and (c) in the log itself are
    read from `text`. With strict=True (default) a row that is not evidence
    raises ChunkSweepError naming every reason; with strict=False the row is
    returned carrying its gate (classification, reasons, missing items) for a
    machine-readable record. reconcile() refuses ineligible rows either way.
    """
    label = str(label)
    choice, rep = split_label(label)
    reasons, missing = [], {}
    lines = text.splitlines()
    exit_lines = [int(m.group(1)) for m in map(profile.EXIT_LINE.match, lines) if m]
    verdict_lines = [m for m in map(profile.ACCEPT.match, lines) if m]
    gpu_lines = [line.strip() for line in lines if profile.GPU_ON.match(line)]
    has_phases = any(profile.PHASE_HDR.match(line) for line in lines)
    proofs = _PROOF.findall(text)
    timings = _TIMING.findall(text)
    cl6_lines = [_cl6_fields(g) for g in _CL6_RUN.findall(text)]
    for what, n in (("PROOF sha256", len(proofs)), ("PASS ACCEPT/REJECT", len(verdict_lines)),
                    ("HASHLINE_TIMING", len(timings)), ("`exit N`", len(exit_lines)),
                    ("CL6_RUN", len(cl6_lines)), ("`gpu:`", len(gpu_lines))):
        if n > 1:
            reasons.append(f"log carries {n} {what} lines; one run writes at most one")
    proof = {"sha256": proofs[0][0], "bytes": int(proofs[0][1])} if len(proofs) == 1 else None
    if not proofs:
        missing["PROOF"] = "PROOF sha256 line"
    verdict = verdict_lines[0].group(2) if len(verdict_lines) == 1 else None
    if not verdict_lines:
        missing["PASS"] = "PASS ACCEPT/REJECT verdict line"
    if not _GPU_ON.search(text):
        if _GPU_OFF.search(text):
            reasons.append("the log says gpu: off, not `gpu: ON`; a chunk-row measurement without the device is not one")
        else:
            missing["gpu"] = "`gpu: ON` line (a chunk-row measurement without the device is not one)"
    if not has_phases:
        missing["phases"] = "`prover phases (summed over layers)` block"
    # --- the TIMING collector: leniently, to name each bad clock ------------------
    t, t_error = _timing_lenient(timings[0]) if len(timings) == 1 else (None, None)
    if not timings:
        missing["TIMING"] = "HASHLINE_TIMING line"
    if t_error:
        reasons.append(t_error)
    if t is not None and not isinstance(t, dict):
        reasons.append(f"HASHLINE_TIMING is not a JSON object ({type(t).__name__})")
        t = None
    clocks = {}
    if t is not None:
        c_reasons, c_missing, clocks = clock_reasons(t)
        reasons += c_reasons
        missing.update(c_missing)
    # --- channel (c): the log's own CL6_RUN line and the bound sweep-log line -----
    cl6_in_log = cl6_lines[0] if len(cl6_lines) == 1 else None
    if cl6_in_log:
        reasons += _cl6_conflicts(cl6_in_log, "the log's CL6_RUN line", choice, rep, proof)
        choice = choice if choice is not None else cl6_in_log["chunk_rows"]
        rep = rep if rep is not None else cl6_in_log["rep"]
    cl6_in_sweep = None
    if sweep_runs is not None:
        cl6_in_sweep, bind_reasons, bind_missing = _bind_sweep_run(sweep_runs, label, choice, rep)
        reasons += bind_reasons
        missing.update(bind_missing)
        if cl6_in_sweep:
            reasons += _cl6_conflicts(cl6_in_sweep, "the sweep log's CL6_RUN line", choice, rep, proof)
            rep = rep if rep is not None else cl6_in_sweep["rep"]
            if cl6_in_log and any(cl6_in_log[k] != cl6_in_sweep[k] for k in ("chunk_rows", "rep", "exit", "sha256", "bytes")):
                reasons.append(f"the log's CL6_RUN line ({_cl6_text(cl6_in_log)}) and the sweep log's "
                               f"({_cl6_text(cl6_in_sweep)}) disagree")
    exit_ev = _exit_evidence(exit_code, exit_lines, cl6_in_log, cl6_in_sweep)
    reasons += exit_ev.pop("reasons")
    missing.update(exit_ev.pop("missing"))
    # --- the CL5 contract ---------------------------------------------------------
    cl5 = {"ran": False, "eligible": None, "reasons": [], "notes": [], "cache_state": None, "wcache": None}
    try:
        raw = profile.parse_log(text, "", exit_code)
    except profile.ProfileError as error:
        raw = None
        reasons.append(f"CL5 parser refused the log: {error}")
        cl5["notes"].append("CL5 gate not run: a collector was refused at parse")
    if raw is not None and raw["timing"] is None:
        cl5["notes"].append("CL5 gate not run: no HASHLINE_TIMING collector to gate")
    elif raw is not None:
        if raw["exit_code"] is None and exit_ev["resolved"] is not None:
            # the CL5 parser knows channels (a) and (b); when both are silent
            # and the CL6_RUN channel resolved, hand its gate the KNOWN exit
            raw["exit_code"], raw["exit_code_source"] = exit_ev["resolved"], exit_ev["resolved_source"]
        att = profile.attribute(raw)
        cl5 = {"ran": True, "eligible": att["eligible"], "reasons": att["ineligible_reasons"], "notes": att["notes"],
               "cache_state": att["cache_state"],
               "wcache": {k: att["wcache"][k] for k in ("hits", "misses", "rejected")},
               "cpu_fallbacks": att["cpu_fallbacks"], "prove_phases_s": att["prove_phases_s"],
               "prove_phase_sum_s": att["prove_phase_sum_s"], "unknown_exclusive_s": att["unknown_exclusive_s"],
               "proof_ready_unknown_s": att["proof_ready_unknown_s"], "tolerance_s": att["tolerance_s"]}
        for reason in att["ineligible_reasons"]:
            key = _absence_key(reason)
            if key is None:
                reasons.append(reason)
            else:
                missing.setdefault(key, reason)
    # --- the chunk lines, and the label against them ------------------------------
    commits = [{"rows": int(m[0]), "log_n": int(m[1]), "log_nn": int(m[2]), "q": int(m[3]),
                "chunks": int(m[4]), "rmax": int(m[5]), "secs": float(m[6])} for m in _COMMIT.findall(text)]
    reencs = [{"rows": int(m[0]), "chunks": int(m[1]), "secs": float(m[2])} for m in _REENC.findall(text)]
    routes = [{"rows": int(m[0]), "why": m[1]} for m in _ROUTE.findall(text)]
    vram = _VRAM.findall(text)
    layers = [{"layer": int(m[0]), "prove_s": float(m[1]), "bytes": int(m[2])} for m in _LAYER.findall(text)]
    reasons += _chunk_plan_conflicts(choice, commits, reencs)
    # --- the verdict --------------------------------------------------------------
    hard = list(dict.fromkeys(reasons))
    missing_list = list(missing.values())
    classification = CLASS_REFUSED if hard else (CLASS_MISSING if missing_list else CLASS_ELIGIBLE)
    all_reasons = hard + [f"missing evidence: {m}" for m in missing_list]

    def _clock(k):
        v = t.get(k) if isinstance(t, dict) else None
        return float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) else None

    def _field(k):
        return _json_safe(t.get(k)) if isinstance(t, dict) else None

    row = {"label": label, "choice": choice, "rep": rep,
           "sha256": proof["sha256"] if proof else None, "proof_bytes": proof["bytes"] if proof else None,
           "prove_s": _clock("prove_s"), "proof_ready_s": _clock("proof_ready_s"), "clocks": clocks,
           "privacy": _field("privacy"), "coverage": _field("coverage"), "layers": _field("layers"),
           "tokens": _field("tokens"), "d": _field("d"), "f": _field("f"), "randomness": _field("randomness"),
           "verdict": verdict, "verified": _field("verified"), "serialized": _field("serialized"),
           "device": gpu_lines[0] if len(gpu_lines) == 1 else None,
           "gpu_requested": _field("gpu_requested"), "gpu_enabled": _field("gpu_enabled"),
           "cache_state": cl5["cache_state"], "wcache": cl5["wcache"],
           "vram_peak_mb": int(vram[-1]) if vram else None,
           "chunked_commits": commits, "chunked_commit_secs": sum(c["secs"] for c in commits),
           "chunked_reencodes": reencs, "chunked_reencode_secs": sum(r["secs"] for r in reencs),
           "routes": routes, "per_layer": layers,
           "observed_rmax": sorted({c["rmax"] for c in commits}),
           "exit_evidence": exit_ev, "cl6_run": cl6_in_log, "sweep_run": cl6_in_sweep, "cl5_gate": cl5,
           "gate": {"contract": "ZK60-CL14", "classification": classification,
                    "eligible": classification == CLASS_ELIGIBLE,
                    "reasons": all_reasons, "missing_items": missing_list}}
    if strict and not row["gate"]["eligible"]:
        raise ChunkSweepError(f"log {label!r} is not evidence ({classification}): " + "; ".join(all_reasons))
    return row


def reconcile(parsed):
    """All rows must be evidence and carry the SAME proof, shape, verdict,
    device and cache state. Anything else is refused, loudly, naming the
    labels. Ranking (prove_vs_fastest) happens only after every check."""
    if not parsed:
        raise ChunkSweepError("no logs given")
    not_evidence = []
    for p in parsed:
        gate = p.get("gate") if isinstance(p, dict) else None
        if not isinstance(gate, dict) or gate.get("eligible") is not True or gate.get("reasons"):
            klass = gate.get("classification", "ungated") if isinstance(gate, dict) else "ungated"
            why = "; ".join(gate["reasons"]) if isinstance(gate, dict) and gate.get("reasons") \
                else "row was never gated by parse_measured_log"
            label = p.get("label") if isinstance(p, dict) else None
            not_evidence.append(f"{label!r} [{klass}]: {why}")
    if not_evidence:
        raise ChunkSweepError("refusing to compare rows that are not evidence: " + " | ".join(not_evidence))
    labels = [p["label"] for p in parsed]
    dup = sorted({x for x in labels if labels.count(x) > 1})
    if dup:
        raise ChunkSweepError(f"labels {dup} appear more than once; label repeats as CHOICE:REP (128:1, 128:2)")
    keys = [(p["choice"], p["rep"]) for p in parsed if p["choice"] is not None and p["rep"] is not None]
    dupk = sorted({k for k in keys if keys.count(k) > 1})
    if dupk:
        raise ChunkSweepError(f"two rows claim the same run (chunk_rows, rep) {dupk}")
    digests = {(p["sha256"], p["proof_bytes"]) for p in parsed}
    if len(digests) != 1:
        detail = ", ".join(f"{p['label']}: {p['sha256'][:16]}../{p['proof_bytes']} B" for p in parsed)
        raise ChunkSweepError(f"chunk-row choice MOVED THE PROOF; refusing to tabulate timings of different proofs ({detail})")
    for field in _UNIFORM_FIELDS:
        seen = {}
        for p in parsed:
            seen.setdefault(json.dumps(p.get(field), sort_keys=True), []).append(p["label"])
        if len(seen) > 1:
            detail = "; ".join(f"{', '.join(labels)}: {value}" for value, labels in seen.items())
            raise ChunkSweepError(f"{field} differs across the set; a chunk sweep varies chunk rows only ({detail})")
    for p in parsed:
        if not (isinstance(p["prove_s"], float) and _positive_finite(p["prove_s"])):
            raise ChunkSweepError(f"{p['label']!r}: prove_s {p['prove_s']!r} is not a finite positive number; nothing to rank against")
    base = min(parsed, key=lambda p: p["prove_s"])
    sha, nbytes = next(iter(digests))
    return {"schema": 2, "contract": "ZK60-CL14", "proof_sha256": sha, "proof_bytes": nbytes,
            "byte_identical_across_choices": True,
            "shape": {k: parsed[0][k] for k in ("privacy", "coverage", "layers", "tokens", "d", "f", "randomness")},
            "device": parsed[0]["device"], "verdict": parsed[0]["verdict"], "cache_state": parsed[0]["cache_state"],
            "exit_evidence": {p["label"]: {"exit": p["exit_evidence"]["resolved"],
                                           "source": p["exit_evidence"]["resolved_source"]} for p in parsed},
            "rows": [{**p, "prove_vs_fastest": p["prove_s"] / base["prove_s"]} for p in parsed],
            "fastest_label": base["label"], "selector_promoted": False,
            "caveat": ("single-box diagnostic seconds; not a p95 and not quiesced-certified unless the log says so; "
                       "equal digests and these seconds promote no chunk-row selector")}


def markdown(report):
    lines = ["| choice | observed rmax | prove s | chunked commit s | chunked re-encode s | VRAM peak MB | proof | exit |",
             "|---|---|---:|---:|---:|---:|---|---|"]
    for r in report["rows"]:
        ev = r.get("exit_evidence") or {}
        lines.append(f"| {r['label']} | {','.join(map(str, r['observed_rmax'])) or '-'} | {r['prove_s']:.3f} | "
                     f"{r['chunked_commit_secs']:.3f} | {r['chunked_reencode_secs']:.3f} | "
                     f"{r['vram_peak_mb'] if r['vram_peak_mb'] is not None else '-'} | {r['sha256'][:16]}.. / {r['proof_bytes']} B | "
                     f"{ev.get('resolved')} ({ev.get('resolved_source')}) |")
    return "\n".join(lines)


def _file_sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def measure(log_items, exit_items=(), sweep_log_path=None, argv=None):
    """The `measure` subcommand as a function: every input's identity, every
    row's evidence and gate, then the reconciliation or the refusal, in one
    record. Usage errors (bad LABEL=PATH, duplicate labels, an --exit naming
    no log, an unbindable sweep log) raise ChunkSweepError instead."""
    logs = {}
    for item in log_items:
        if "=" not in item:
            raise ChunkSweepError(f"--log wants LABEL=PATH, got {item!r}")
        label, path = item.split("=", 1)
        if label in logs:
            raise ChunkSweepError(f"--log label {label!r} given twice; label repeats as CHOICE:REP (128:1, 128:2)")
        logs[label] = path
    exits = {}
    for item in exit_items or ():
        if "=" not in item:
            raise ChunkSweepError(f"--exit wants LABEL=N, got {item!r}")
        label, value = item.split("=", 1)
        if label not in logs:
            raise ChunkSweepError(f"--exit {item!r} names no --log label")
        try:
            exits[label] = int(value)
        except ValueError:
            raise ChunkSweepError(f"--exit {item!r}: the exit status must be an integer") from None
    sweep = None
    if sweep_log_path is not None:
        with open(sweep_log_path, encoding="utf-8", errors="replace") as fh:
            sweep = parse_sweep_log(fh.read(), sweep_log_path)
        sweep["sha256"] = _file_sha256(sweep_log_path)
    rows = []
    for label, path in logs.items():
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        row = parse_measured_log(text, label, exits.get(label), sweep, strict=False)
        row["log"] = {"path": path, "sha256": _file_sha256(path), "bytes": os.path.getsize(path)}
        rows.append(row)
    report = {"schema": 2, "tool": "hashline_cl_chunk_sweep.py measure",
              "contract": ("ZK60-CL14 validated-row contract: the CL5 gate (hashline_cl_profile.attribute) plus exit-channel "
                           "resolution, sweep-log binding, CL6_RUN/PROOF identity and chunk-plan-vs-label checks, "
                           "before any digest comparison or ranking"),
              "command": {"argv": list(argv) if argv is not None else sys.argv[1:], "cwd": os.getcwd()},
              "inputs": {"logs": logs, "exits": exits, "sweep_log": sweep_log_path},
              "sweep_log": sweep, "rows": rows,
              "row_classes": {c: sum(1 for r in rows if r["gate"]["classification"] == c)
                              for c in (CLASS_ELIGIBLE, CLASS_REFUSED, CLASS_MISSING)},
              "reconcile": None, "refusal": None, "selector_promoted": False}
    if sweep is not None:
        bound = {(r["sweep_run"]["chunk_rows"], r["sweep_run"]["rep"]) for r in rows if r.get("sweep_run")}
        sweep["unbound_runs"] = [run for run in sweep["runs"] if (run["chunk_rows"], run["rep"]) not in bound]
    try:
        report["reconcile"] = reconcile(rows)
    except ChunkSweepError as error:
        report["refusal"] = str(error)
    return report


# --------------------------------------------------------------------------- cli

def _choices(text):
    try:
        vals = [int(x) for x in text.split(",") if x.strip()]
    except ValueError:
        raise argparse.ArgumentTypeError("choices must be comma-separated integers")
    if not vals:
        raise argparse.ArgumentTypeError("at least one choice is required")
    return vals


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="action", required=True)
    p = sub.add_parser("plan")
    shape = p.add_mutually_exclusive_group(required=True)
    shape.add_argument("--rows", type=int)
    shape.add_argument("--p3-weights", type=int, nargs=2, metavar=("D", "F"))
    p.add_argument("--log-cols", type=int, default=14)
    p.add_argument("--inv-rate", type=int, default=4)
    p.add_argument("--q-pad", type=int)
    p.add_argument("--checks", type=int, default=256)
    p.add_argument("--choices", type=_choices, default=[128, 256, 512, 1024])
    p.add_argument("--scratch-budget-mib", type=int, help="explicit commit-scratch budget; selection happens only when given")
    p.add_argument("--device-total-mib", type=int, help="nominal device capacity, used ONLY to refuse a budget that is not below it")
    p.add_argument("--prior-live-mib", type=int, default=0)
    p.add_argument("--prior-pool-mib", type=int, default=0)
    m = sub.add_parser("measure")
    m.add_argument("--log", action="append", required=True, metavar="LABEL=PATH",
                   help="a prover log; LABEL is the chunk-row choice, optionally :REP (128:1), and binds to the sweep log")
    m.add_argument("--exit", action="append", default=[], metavar="LABEL=N",
                   help="exit status of that run (channel a); the log's own `exit N` and CL6_RUN lines are read too, a conflict refuses")
    m.add_argument("--sweep-log", metavar="PATH",
                   help="the sweep runner's log; its CL6_RUN lines are bound to the rows by chunk_rows/rep (channel c)")
    m.add_argument("--markdown", action="store_true")
    args = parser.parse_args(argv)
    argv_list = list(argv) if argv is not None else sys.argv[1:]
    try:
        if args.action == "plan":
            if args.p3_weights:
                w = memplan.weight_shape(*args.p3_weights, args.log_cols)
                rows, log_cols = w["rows"], w["log_cols"]
            else:
                rows, log_cols, w = args.rows, args.log_cols, None
            if args.scratch_budget_mib is None:
                out = {"schema": 1, "measured": False, "safe_to_run": False,
                       "shape": {"rows": rows, "log_cols": log_cols, "inv_rate": args.inv_rate, "q_pad": args.q_pad},
                       "candidates": sweep(rows, log_cols, args.inv_rate, args.q_pad, args.choices,
                                           args.prior_live_mib * MIB, args.prior_pool_mib * MIB, args.checks)}
            else:
                out = select(rows, log_cols, args.inv_rate, args.q_pad, args.choices, args.scratch_budget_mib * MIB,
                             None if args.device_total_mib is None else args.device_total_mib * MIB,
                             args.prior_live_mib * MIB, args.prior_pool_mib * MIB, args.checks)
            out["p3_weight_layout"] = w
        else:
            out = measure(args.log, args.exit, args.sweep_log, argv_list)
            if out["refusal"] is not None:
                # the record goes to stdout in both outcomes; the verdict is the exit code
                print(json.dumps(out, indent=2, allow_nan=False))
                parser.exit(2, f"chunk sweep: {out['refusal']}\n")
            if args.markdown:
                print(markdown(out["reconcile"]))
                return 0
    except (ChunkSweepError, ValueError, OSError) as error:
        parser.exit(2, f"chunk sweep: {error}\n")
    print(json.dumps(out, indent=2, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
