#!/usr/bin/env python3
"""[ZK60-CL6] Chunk-row scheduling for the chunked hiding commitment.

Two subcommands. Neither opens a device, queries the driver, or launches anything.

  plan     Count the chunked path's device bytes for ONE hiding-commitment
           shape at every candidate chunk-row choice (reusing
           hashline_memory_plan.commitment_plan in mode "chunked"), and SELECT
           a chunk-row count deterministically against an EXPLICIT scratch
           budget. The budget is an operator argument. Nominal VRAM is not
           free memory, and this tool never reads free memory.
  measure  Reconcile prover logs taken at different chunk-row choices. The
           proof digest and byte length must be IDENTICAL across the set
           (chunk rows are a memory decision, not a proof decision); every log
           must show `gpu: ON`; the per-commit chunked timings the prover
           prints under HL_GPU_VERBOSE=1 are tabulated next to the plan.

Examples:
  python3 scripts/hashline_cl_chunk_sweep.py plan --p3-weights 4096 14336 \\
      --choices 128,256,512,1024 --scratch-budget-mib 768
  python3 scripts/hashline_cl_chunk_sweep.py measure --log 128=a.log --log 256=b.log

The device's own rules are mirrored exactly (hashline/src/gpu/cuda.rs):
  chunk_rows()  clamps the choice to >= 128 and does NOT round it;
  chunk_plan()  takes ALL rows as one chunk when rows <= choice, else steps of
                (choice // 128) * 128 with a short final chunk.
"""

import argparse
import importlib.util
import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("hashline_memory_plan", os.path.join(_HERE, "hashline_memory_plan.py"))
memplan = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = memplan
_spec.loader.exec_module(memplan)

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

_GPU_ON = re.compile(r"^\s*gpu: ON\b", re.MULTILINE)
_PROOF = re.compile(r"^PROOF sha256 ([0-9a-f]{64}) \((\d+) B\)", re.MULTILINE)
_TIMING = re.compile(r"^HASHLINE_TIMING (\{.*\})$", re.MULTILINE)
_VRAM = re.compile(r"vram peak (\d+) MB")
_COMMIT = re.compile(r"chunked ZK commit rows (\d+) 2\^(\d+) -> 2\^(\d+) \(q (\d+)\) in (\d+) chunks of <= (\d+): ([0-9.]+) s")
_REENC = re.compile(r"chunked ZK re-encode \+ gather rows (\d+) \((\d+) chunks(?:, fused[^)]*)?\): ([0-9.]+) s")
_ROUTE = re.compile(r"zk commit rows (\d+) [^\n]*: CHUNKED \(([^)]+)\)")
_LAYER = re.compile(r"^\s*layer\s+(\d+): prove ([0-9.]+) s, (\d+) B", re.MULTILINE)


def parse_measured_log(text, label):
    if not _GPU_ON.search(text):
        raise ChunkSweepError(f"log {label!r} does not show `gpu: ON`; a chunk-row measurement without the device is not one")
    proof = _PROOF.search(text)
    timing = _TIMING.search(text)
    if not proof or not timing:
        raise ChunkSweepError(f"log {label!r} lacks the PROOF sha256 line or the HASHLINE_TIMING line")
    t = json.loads(timing.group(1))
    if not t.get("verified", False):
        raise ChunkSweepError(f"log {label!r}: the proof did not verify; timings of a rejected proof are not comparable")
    if int(t["proof_bytes"]) != int(proof.group(2)):
        raise ChunkSweepError(f"log {label!r}: proof_bytes disagree between the PROOF line and HASHLINE_TIMING")
    commits = [{"rows": int(m[0]), "log_n": int(m[1]), "log_nn": int(m[2]), "q": int(m[3]),
                "chunks": int(m[4]), "rmax": int(m[5]), "secs": float(m[6])} for m in _COMMIT.findall(text)]
    reencs = [{"rows": int(m[0]), "chunks": int(m[1]), "secs": float(m[2])} for m in _REENC.findall(text)]
    routes = [{"rows": int(m[0]), "why": m[1]} for m in _ROUTE.findall(text)]
    vram = _VRAM.findall(text)
    layers = [{"layer": int(m[0]), "prove_s": float(m[1]), "bytes": int(m[2])} for m in _LAYER.findall(text)]
    return {"label": label, "sha256": proof.group(1), "proof_bytes": int(proof.group(2)),
            "prove_s": float(t["prove_s"]), "proof_ready_s": float(t.get("proof_ready_s", float("nan"))),
            "privacy": t.get("privacy"), "layers": t.get("layers"), "tokens": t.get("tokens"),
            "d": t.get("d"), "f": t.get("f"), "vram_peak_mb": int(vram[-1]) if vram else None,
            "chunked_commits": commits, "chunked_commit_secs": sum(c["secs"] for c in commits),
            "chunked_reencodes": reencs, "chunked_reencode_secs": sum(r["secs"] for r in reencs),
            "routes": routes, "per_layer": layers,
            "observed_rmax": sorted({c["rmax"] for c in commits})}


def reconcile(parsed):
    """All logs must carry the SAME proof. Anything else is refused, loudly."""
    if not parsed:
        raise ChunkSweepError("no logs given")
    digests = {(p["sha256"], p["proof_bytes"]) for p in parsed}
    if len(digests) != 1:
        detail = ", ".join(f"{p['label']}: {p['sha256'][:16]}../{p['proof_bytes']} B" for p in parsed)
        raise ChunkSweepError(f"chunk-row choice MOVED THE PROOF; refusing to tabulate timings of different proofs ({detail})")
    shapes = {(p["privacy"], p["layers"], p["tokens"], p["d"], p["f"]) for p in parsed}
    if len(shapes) != 1:
        raise ChunkSweepError("logs are not all the same shape/mode; a chunk sweep varies chunk rows only")
    base = min(parsed, key=lambda p: p["prove_s"])
    sha, nbytes = next(iter(digests))
    return {"schema": 1, "proof_sha256": sha, "proof_bytes": nbytes, "byte_identical_across_choices": True,
            "shape": dict(zip(("privacy", "layers", "tokens", "d", "f"), next(iter(shapes)))),
            "rows": [{**p, "prove_vs_fastest": p["prove_s"] / base["prove_s"] if base["prove_s"] else None}
                     for p in parsed],
            "caveat": "single-box diagnostic seconds; not a p95 and not quiesced-certified unless the log says so"}


def markdown(report):
    lines = ["| choice | observed rmax | prove s | chunked commit s | chunked re-encode s | VRAM peak MB | proof |",
             "|---|---|---:|---:|---:|---:|---|"]
    for r in report["rows"]:
        lines.append(f"| {r['label']} | {','.join(map(str, r['observed_rmax'])) or '-'} | {r['prove_s']:.3f} | "
                     f"{r['chunked_commit_secs']:.3f} | {r['chunked_reencode_secs']:.3f} | "
                     f"{r['vram_peak_mb'] if r['vram_peak_mb'] is not None else '-'} | {r['sha256'][:16]}.. / {r['proof_bytes']} B |")
    return "\n".join(lines)


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
    m.add_argument("--log", action="append", required=True, metavar="CHOICE=PATH", help="a prover log taken at that chunk-row choice")
    m.add_argument("--markdown", action="store_true")
    args = parser.parse_args(argv)
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
            parsed = []
            for item in args.log:
                if "=" not in item:
                    raise ChunkSweepError(f"--log wants CHOICE=PATH, got {item!r}")
                label, path = item.split("=", 1)
                with open(path, encoding="utf-8", errors="replace") as fh:
                    parsed.append(parse_measured_log(fh.read(), label))
            out = reconcile(parsed)
            if args.markdown:
                print(markdown(out))
                return 0
    except (ChunkSweepError, ValueError, OSError) as error:
        parser.exit(2, f"chunk sweep: {error}\n")
    print(json.dumps(out, indent=2, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
