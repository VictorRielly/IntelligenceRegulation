#!/usr/bin/env python3
"""[ZK60-CL5] Parse the prover's EXISTING collectors into attributed rows.

This deliberately creates NO new clock. It reads what the binary already
emits — `HASHLINE_TIMING` (the authoritative top-level JSON), the
`prover phases (summed over layers)` block, the `gpu device-side (summed)`
counters, the `PASS*` acceptance line and the `PROOF sha256` line — and
reports them as one row per run with the context needed to compare rows.

Every row carries shape, device, privacy mode, cache state, coverage, the
command and its exit code. UNKNOWN exclusive time is reported rather than
silently absorbed: if the named phases do not account for the prove clock,
the difference appears as `unknown_exclusive_s`.

It measures nothing itself and launches nothing. Give it a log.

Round 7 (Codex review, 2026-09-06). The earlier version attributed and
ranked every row it could parse. The review showed two holes: a row marked
`exit_code=1` still received a ranked speedup table, and a phase larger than
the proof-ready clock produced a NEGATIVE bound (-7.34575353 on the
sample-based control) instead of a refusal. Now:

- every row carries an explicit gate: `eligible` plus `ineligible_reasons`.
  Diagnostic rows are RETAINED in the output, marked, never ranked;
- `rank()` refuses any ineligible row, and refuses a phase that is not
  smaller than the proof-ready clock (the negative/infinite Amdahl case);
- a non-finite value (NaN/Infinity, or a literal that overflows to inf)
  anywhere in the collectors is refused AT PARSE, not carried as a number;
- the exit code and the command are read from the log itself when the
  runner wrote them there (`exit N`, `CMD: ...`); an external value that
  contradicts the log makes the row ineligible rather than overriding it;
- the cache state is derived from the log's own `wcache HIT/MISS` lines
  (HL_WCACHE_VERBOSE=1) and, when present, the `wcache DIR: hits N |
  misses N` summary, cross-checked against `--wcache` in the command.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

TIMING = re.compile(r"^HASHLINE_TIMING (\{.*\})\s*$")
PHASE_HDR = re.compile(r"^prover phases \(summed over layers\):")
# the value is captured as \S+ (not [0-9.]+) so that a printed NaN/inf/-x is
# SEEN and refused instead of silently failing to match and vanishing into
# `unknown_exclusive_s` as if it were missing work
PHASE = re.compile(r"^ {6}(\S.*?)\s{2,}(\S+) s\s*$")
DEVICE = re.compile(r"^\s*gpu device-side \(summed\): (.*)$")
GPU_ON = re.compile(r"^\s*gpu: (ON|off)\b(.*)$")
DECLINED = re.compile(r"gpu .* declined \(([^)]*)\)")
SHA = re.compile(r"^PROOF sha256 ([0-9a-f]{64}) \((\d+) B\)")
# the verdict comes BEFORE the colon: "PASS-V3 ACCEPT [ZK]: 12 x 512 ..."
ACCEPT = re.compile(r"^(PASS\S*)\s+(ACCEPT|REJECT)\b")
PASS_BYTES = re.compile(r"\| proof (\d+) B ")
DEV_FIELD = re.compile(r"(\w+) (\S+) s(?: \((\d+) MB\))?")
VRAM = re.compile(r"vram peak (\d+) MB")
# written into the log by results/cl5_profile_matrix.sh: the exact command
# as its first line, the exit code as its last
CMD_LINE = re.compile(r"^CMD: (.+?)\s*$")
EXIT_LINE = re.compile(r"^exit (\d+)\s*$")
# src/wcache.rs, HL_WCACHE_VERBOSE=1, one line per layer (stderr):
#   [UPERF3-AC] wcache HIT <path> (rows 288, 4.2 MB, load+verify 0.008 s, re-encode 0.088 s)
#   [UPERF3-AC] wcache MISS -> wrote <path> (4.2 MB, commit 0.087 s, write 0.002 s)
#   [UPERF3-AC] wcache entry <path> REJECTED (<reason>); re-committing
# and the driver's summary (printed by pass_v3 only; the ZK pass does NOT print it):
#   wcache <dir>: hits N | misses N | rejected N | read X MB | wrote Y MB | ...
WC_HIT = re.compile(r"wcache HIT (\S+) \(rows (\d+), ([0-9.]+) MB, load\+verify (\S+) s, re-encode (\S+) s\)")
WC_MISS = re.compile(r"wcache MISS -> wrote (\S+) \(([0-9.]+) MB, commit (\S+) s, write (\S+) s\)")
WC_REJECTED = re.compile(r"wcache entry (\S+) REJECTED")
WC_SUMMARY = re.compile(r"wcache (\S+): hits (\d+) \| misses (\d+) \| rejected (\d+)")
WC_REFUSED = re.compile(r"^REFUSED: --wcache with --p3")

# Each phase is printed `{:.3} s`, so a value carries up to 0.5 ms of
# rounding; the sum of n phases can therefore legitimately exceed the prove
# clock (printed to 9 places) by up to n x 0.5 ms while describing the same
# work. 1 ms per phase is twice that worst case. The tolerance only ever
# EXCUSES a small NEGATIVE residual; a positive residual of any size is
# reported as unknown time, never gated.
TOL_PER_PHASE_S = 0.001
CLOCKS = ("witness_s", "prove_s", "serialize_s", "proof_ready_s", "verify_s")
PRIVACY_LABELS = ("P0", "P1", "P3")


class ProfileError(ValueError):
    pass


def _refuse_constant(name: str):
    raise ProfileError(
        f"HASHLINE_TIMING carries a non-finite value ({name}): a clock that is not a "
        "number cannot be attributed or ranked; refused at parse"
    )


def _finite(where: str, s: str) -> float:
    """Parse a printed seconds value; refuse anything that is not a finite number."""
    try:
        v = float(s)
    except ValueError:
        raise ProfileError(f"{where}: '{s}' is not a number; refused at parse") from None
    if not math.isfinite(v):
        raise ProfileError(f"{where}: non-finite value '{s}'; refused at parse")
    return v


def _parse_timing(blob: str) -> dict:
    try:
        t = json.loads(blob, parse_constant=_refuse_constant)
    except json.JSONDecodeError as e:
        raise ProfileError(f"HASHLINE_TIMING is not parseable JSON ({e.msg} at column {e.pos})") from None
    for k, v in t.items():
        # a literal like 1e999 parses to inf without going through parse_constant
        if isinstance(v, float) and not math.isfinite(v):
            raise ProfileError(
                f"HASHLINE_TIMING field {k} is non-finite ({v}); refused at parse")
    return t


def parse_log(text: str, command: str = "", exit_code: int | None = None) -> dict:
    """One raw row from one prover log.

    `command` and `exit_code` may be supplied by the caller (old logs) but the
    log's own `CMD:` / `exit N` lines are read too; a disagreement is kept on
    the row so the gate can refuse it, instead of one source silently winning.
    """
    row: dict = {
        "command": command or None,
        "command_source": "argument" if command else None,
        "command_from_log": None,
        "exit_code": exit_code,
        "exit_code_source": "argument" if exit_code is not None else None,
        "exit_code_from_log": None,
        "device": None,
        "gpu_enabled_line": None,
        "gpu_line_state": None,          # "ON" / "off" / None
        "cpu_fallbacks": [],
        "phases_s": {},
        "device_side": {},
        "proof_sha256": None,
        "proof_bytes": None,
        "pass_proof_bytes": None,
        "verdict": None,
        "timing": None,
        "wcache": {"hits": 0, "misses": 0, "rejected": 0, "entries": [], "summary": None},
        "wcache_refused": False,
    }
    in_phases = False
    for line in text.splitlines():
        m = TIMING.match(line)
        if m:
            row["timing"] = _parse_timing(m.group(1))
            continue
        m = CMD_LINE.match(line)
        if m:
            row["command_from_log"] = m.group(1)
            if row["command"] is None:
                row["command"], row["command_source"] = m.group(1), "log"
            continue
        m = EXIT_LINE.match(line)
        if m:
            row["exit_code_from_log"] = int(m.group(1))
            if row["exit_code"] is None:
                row["exit_code"], row["exit_code_source"] = int(m.group(1)), "log"
            continue
        if PHASE_HDR.match(line):
            in_phases = True
            continue
        if in_phases:
            m = PHASE.match(line)
            if m:
                name = m.group(1).strip()
                row["phases_s"][name] = _finite(f"phase '{name}'", m.group(2))
                continue
            # any other line ends the block
            if line.strip() and not line.startswith("      "):
                in_phases = False
        m = GPU_ON.match(line)
        if m:
            row["gpu_enabled_line"] = line.strip()
            row["device"] = line.strip()
            row["gpu_line_state"] = m.group(1)
            continue
        m = DECLINED.search(line)
        if m:
            row["cpu_fallbacks"].append(m.group(1))
            continue
        m = DEVICE.match(line)
        if m:
            body = m.group(1)
            for name, secs, mb in DEV_FIELD.findall(body):
                row["device_side"][f"{name}_s"] = _finite(f"device-side {name}", secs)
                if mb:
                    row["device_side"][f"{name}_mb"] = int(mb)
            v = VRAM.search(body)
            if v:
                row["device_side"]["vram_peak_mb"] = int(v.group(1))
            continue
        m = SHA.match(line)
        if m:
            row["proof_sha256"], row["proof_bytes"] = m.group(1), int(m.group(2))
            continue
        m = ACCEPT.match(line)
        if m:
            row["verdict"] = m.group(2)
            b = PASS_BYTES.search(line)
            if b:
                row["pass_proof_bytes"] = int(b.group(1))
            continue
        m = WC_HIT.search(line)
        if m:
            row["wcache"]["hits"] += 1
            row["wcache"]["entries"].append({
                "kind": "HIT", "path": m.group(1), "rows": int(m.group(2)),
                "mb": float(m.group(3)),
                "load_verify_s": _finite("wcache HIT load+verify", m.group(4)),
                "reencode_s": _finite("wcache HIT re-encode", m.group(5))})
            continue
        m = WC_MISS.search(line)
        if m:
            row["wcache"]["misses"] += 1
            row["wcache"]["entries"].append({
                "kind": "MISS", "path": m.group(1), "mb": float(m.group(2)),
                "commit_s": _finite("wcache MISS commit", m.group(3)),
                "write_s": _finite("wcache MISS write", m.group(4))})
            continue
        m = WC_REJECTED.search(line)
        if m:
            row["wcache"]["rejected"] += 1
            row["wcache"]["entries"].append({"kind": "REJECTED", "path": m.group(1)})
            continue
        m = WC_SUMMARY.search(line)
        if m:
            row["wcache"]["summary"] = {"dir": m.group(1), "hits": int(m.group(2)),
                                        "misses": int(m.group(3)), "rejected": int(m.group(4))}
            continue
        if WC_REFUSED.match(line):
            row["wcache_refused"] = True
    return row


def _cache_state(row: dict) -> tuple[str, list[str]]:
    """cold / warm / mixed / none / refused / unknown, from the LOG, plus any
    contradiction found on the way (returned as gate reasons)."""
    wc = row["wcache"]
    reasons: list[str] = []
    cmd = row["command"]
    configured = ("--wcache" in cmd) if cmd else None
    hits, misses, rejected = wc["hits"], wc["misses"], wc["rejected"]
    seen = bool(wc["entries"]) or wc["summary"] is not None
    if wc["summary"] is not None:
        s = wc["summary"]
        if wc["entries"] and (s["hits"], s["misses"]) != (hits, misses):
            reasons.append(
                f"wcache summary says hits {s['hits']} / misses {s['misses']} but the log "
                f"has {hits} HIT / {misses} MISS lines")
        # the summary is authoritative when the per-layer lines are absent
        # (HL_WCACHE_VERBOSE unset)
        if not wc["entries"]:
            hits, misses, rejected = s["hits"], s["misses"], s["rejected"]
    if row["wcache_refused"]:
        return "refused", reasons
    if seen and configured is False:
        reasons.append("wcache lines in the log but the recorded command has no --wcache")
    if seen:
        if hits and not misses:
            return "warm", reasons
        if misses and not hits:
            return "cold", reasons
        if hits and misses:
            return "mixed", reasons
        return "unknown", reasons        # configured, nothing committed through it
    if configured is True:
        # configured, but HL_WCACHE_VERBOSE was off and the ZK pass prints no
        # summary line: the log cannot say whether it hit or missed
        return "unknown", reasons
    if configured is False:
        return "none", reasons
    return "unknown", reasons           # no command recorded at all


def _is_num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _gate(row: dict, out: dict) -> list[str]:
    """The eligibility gate. Every reason is a refusal, not a note."""
    t = row["timing"]
    r: list[str] = []
    # --- command / exit evidence -------------------------------------------
    if row["command_from_log"] is not None and row["command_source"] == "argument" \
            and row["command_from_log"] != row["command"]:
        r.append(f"command given as '{row['command']}' but the log records CMD: '{row['command_from_log']}'")
    rc = row["exit_code"]
    if rc is None:
        r.append("exit code unknown: no `exit N` line in the log and none given")
    else:
        if row["exit_code_from_log"] is not None and row["exit_code_source"] == "argument" \
                and row["exit_code_from_log"] != rc:
            r.append(f"exit code given as {rc} but the log records exit {row['exit_code_from_log']}")
        if rc != 0:
            r.append(f"exit code {rc} != 0")
    # --- verdict / verification --------------------------------------------
    if row["verdict"] is None:
        r.append("no PASS ACCEPT/REJECT line")
    elif row["verdict"] != "ACCEPT":
        r.append(f"verifier verdict is {row['verdict']}, not ACCEPT")
    if t.get("verified") is not True:
        r.append(f"HASHLINE_TIMING verified is {t.get('verified')!r}, not true")
    if t.get("serialized") is not True:
        r.append(f"HASHLINE_TIMING serialized is {t.get('serialized')!r}, not true")
    # --- clocks --------------------------------------------------------------
    for k in CLOCKS:
        v = t.get(k)
        if v is None:
            r.append(f"clock {k} missing from HASHLINE_TIMING")
        elif not _is_num(v):
            r.append(f"clock {k} is not a number ({v!r})")
        elif not math.isfinite(v):
            r.append(f"clock {k} is not finite ({v!r})")
        elif v < 0:
            r.append(f"clock {k} is negative ({v})")
    ready = t.get("proof_ready_s")
    if _is_num(ready) and math.isfinite(ready) and ready <= 0:
        r.append("proof_ready_s is not positive: nothing to rank against")
    # --- shape / labels ------------------------------------------------------
    for k in ("layers", "tokens", "d", "f"):
        v = t.get(k)
        if not (isinstance(v, int) and not isinstance(v, bool) and v > 0):
            r.append(f"shape field {k} missing or not a positive integer ({v!r})")
    if t.get("privacy") not in PRIVACY_LABELS:
        r.append(f"privacy label {t.get('privacy')!r} is not one of {PRIVACY_LABELS}")
    if not t.get("coverage"):
        r.append("coverage label missing")
    # --- proof identity ------------------------------------------------------
    tb = t.get("proof_bytes")
    if row["proof_sha256"] is None:
        r.append("no PROOF sha256 line")
    elif row["proof_bytes"] != tb:
        r.append(f"PROOF line says {row['proof_bytes']} B but HASHLINE_TIMING says {tb} B")
    if row["pass_proof_bytes"] is not None and row["pass_proof_bytes"] != tb:
        r.append(f"PASS line says proof {row['pass_proof_bytes']} B but HASHLINE_TIMING says {tb} B")
    # --- device: a GPU row must be a GPU row all the way through ---------------
    req, en, line = t.get("gpu_requested"), t.get("gpu_enabled"), row["gpu_line_state"]
    if req is True or en is True or line == "ON":
        if req is True and en is not True:
            r.append("gpu requested but HASHLINE_TIMING gpu_enabled is not true")
        if en is True and req is not True:
            r.append("HASHLINE_TIMING gpu_enabled=true without gpu_requested=true")
        if en is True and line != "ON":
            r.append("HASHLINE_TIMING gpu_enabled=true but the log has no `gpu: ON` line"
                     if line is None else "HASHLINE_TIMING gpu_enabled=true but the log says gpu: off")
        if line == "ON" and en is not True:
            r.append("the log says gpu: ON but HASHLINE_TIMING gpu_enabled is not true")
    # --- phases: exhaustive, nonnegative, inside the clocks they sit in --------
    phases = row["phases_s"]
    tol = out["tolerance_s"]
    prove = t.get("prove_s")
    if not phases:
        r.append("no `prover phases` block: exclusive attribution is impossible")
    for name, secs in phases.items():
        if secs < 0:
            r.append(f"phase '{name}' is negative ({secs} s)")
        if _is_num(ready) and math.isfinite(ready) and secs >= ready:
            r.append(f"phase '{name}' ({secs} s) is not smaller than the proof-ready clock "
                     f"({ready} s): the Amdahl bound would be negative or infinite")
        elif _is_num(prove) and math.isfinite(prove) and secs > prove + tol:
            r.append(f"phase '{name}' ({secs} s) exceeds the prove clock ({prove} s) it sits inside")
    for name, secs in row["device_side"].items():
        if name.endswith("_s") and secs < 0:
            r.append(f"device-side {name} is negative ({secs})")
    unknown = out["unknown_exclusive_s"]
    if unknown is not None and unknown < -tol:
        r.append(f"phases sum to {out['prove_phase_sum_s']} s, more than the prove clock "
                 f"{prove} s by {-unknown:.6f} s (tolerance {tol} s)")
    if _is_num(ready) and math.isfinite(ready) and out["prove_phase_sum_s"] > ready + tol:
        r.append(f"phases sum to {out['prove_phase_sum_s']} s, more than the proof-ready clock {ready} s")
    top_unknown = out["proof_ready_unknown_s"]
    if top_unknown is not None and top_unknown < -tol:
        r.append(f"witness+prove+serialize exceed proof_ready_s by {-top_unknown:.6f} s (tolerance {tol} s)")
    return r


def attribute(row: dict) -> dict:
    """Exclusive attribution, with the unaccounted remainder made explicit,
    and the eligibility gate applied. Ineligible rows are returned (retained
    as diagnostics), never silently dropped and never rankable."""
    t = row.get("timing")
    if not t:
        raise ProfileError(
            "no HASHLINE_TIMING line: this parser reuses the prover's own collector "
            "and refuses to invent a clock from the prose lines"
        )
    phases = row["phases_s"]
    phase_sum = sum(phases.values())
    prove = t.get("prove_s")
    ready = t.get("proof_ready_s")
    top = {"witness_s": t.get("witness_s"), "prove_s": prove,
           "serialize_s": t.get("serialize_s")}
    known_top = sum(v for v in top.values() if _is_num(v))
    cache_state, cache_reasons = _cache_state(row)
    out = {
        "shape": {"layers": t.get("layers"), "tokens": t.get("tokens"),
                  "d": t.get("d"), "f": t.get("f")},
        "privacy": t.get("privacy"),
        "coverage": t.get("coverage"),
        "gpu_requested": t.get("gpu_requested"),
        "gpu_enabled": t.get("gpu_enabled"),
        "device": row["device"],
        "verified": t.get("verified"),
        "serialized": t.get("serialized"),
        "verdict": row["verdict"],
        "proof_sha256": row["proof_sha256"],
        "proof_bytes": row["proof_bytes"] if row["proof_bytes"] is not None else t.get("proof_bytes"),
        "command": row["command"],
        "command_source": row["command_source"],
        "exit_code": row["exit_code"],
        "exit_code_source": row["exit_code_source"],
        "cache_state": cache_state,
        "wcache": {"hits": row["wcache"]["hits"], "misses": row["wcache"]["misses"],
                   "rejected": row["wcache"]["rejected"], "summary": row["wcache"]["summary"],
                   "entries": row["wcache"]["entries"]},
        "cpu_fallback_count": len(row["cpu_fallbacks"]),
        "cpu_fallbacks": row["cpu_fallbacks"],
        "top_level_s": top,
        "proof_ready_s": ready,
        "proof_ready_unknown_s": None if not _is_num(ready) else round(ready - known_top, 6),
        "prove_phases_s": dict(sorted(phases.items(), key=lambda kv: -kv[1])),
        "prove_phase_sum_s": round(phase_sum, 6),
        "unknown_exclusive_s": None if not _is_num(prove) else round(prove - phase_sum, 6),
        "device_side": row["device_side"],
        "tolerance_s": TOL_PER_PHASE_S * max(1, len(phases)),
        "eligible": False,
        "ineligible_reasons": [],
        "notes": [],
    }
    reasons = _gate(row, out) + cache_reasons
    out["ineligible_reasons"] = reasons
    out["eligible"] = not reasons
    if row["command"] is None:
        out["notes"].append("command unknown: cache state cannot be read from the flags")
    if cache_state == "unknown" and row["command"] and "--wcache" in row["command"]:
        out["notes"].append("--wcache configured but the log has no HIT/MISS evidence "
                            "(HL_WCACHE_VERBOSE unset; the ZK pass prints no wcache summary)")
    if out["cpu_fallback_count"]:
        out["notes"].append(f"{out['cpu_fallback_count']} CPU fallback(s): not a pure GPU row")
    return out


def rank(rows: list[dict], top_n: int = 3) -> dict:
    """Top exclusive costs and the BOUNDED Amdahl gain of removing each.

    Each bound is computed on its own against the same proof-ready clock.
    Factors are never multiplied together: two phases removed at once is not
    the product of their individual speedups, and presenting it that way is
    how a 1.05x becomes an imaginary 4x.

    Refuses: any ineligible row (a diagnostic row is not evidence), and any
    phase that is not smaller than the proof-ready clock — ready/(ready-phase)
    would be negative or infinite, which is not a bound, it is a bug in the
    input. The earlier version emitted -7.34575353 for exactly that case.
    """
    if not rows:
        raise ProfileError("no rows to rank")
    for i, r in enumerate(rows):
        if not r.get("eligible"):
            why = r.get("ineligible_reasons") or ["eligibility was never assessed"]
            raise ProfileError(
                f"row {i} ({r.get('command') or 'command unknown'}) is not eligible evidence "
                f"and will not be ranked: " + "; ".join(why))
    base = rows[0]
    ready = base["proof_ready_s"]
    if not _is_num(ready) or not math.isfinite(ready) or ready <= 0:
        raise ProfileError(f"no usable proof_ready_s to rank against ({ready!r})")
    phases = base["prove_phases_s"]
    if not phases:
        raise ProfileError("no phases to rank")
    for name, secs in phases.items():
        if not _is_num(secs) or not math.isfinite(secs) or secs < 0:
            raise ProfileError(f"phase '{name}' has an unusable exclusive time ({secs!r})")
        if secs >= ready:
            kind = "infinite" if secs == ready else "negative"
            raise ProfileError(
                f"phase '{name}' = {secs} s is not smaller than the proof-ready clock "
                f"{ready} s: the Amdahl bound ready/(ready - phase) would be {kind}; "
                "an impossible input is refused, not reported")
    tol = base.get("tolerance_s", TOL_PER_PHASE_S)
    if sum(phases.values()) > ready + tol:
        raise ProfileError(
            f"phases sum to {sum(phases.values())} s, more than the proof-ready clock {ready} s")
    items = sorted(phases.items(), key=lambda kv: -kv[1])[:top_n]
    out = []
    for name, secs in items:
        out.append({
            "phase": name,
            "exclusive_s": secs,
            "share_of_proof_ready": secs / ready,
            "bounded_speedup_if_removed_entirely": ready / (ready - secs),
            "note": "an upper bound: removing the phase completely, which no real change does",
        })
    return {
        "proof_ready_s": ready,
        "ranked_row": {"command": base.get("command"), "privacy": base.get("privacy"),
                       "shape": base.get("shape"), "cache_state": base.get("cache_state"),
                       "proof_sha256": base.get("proof_sha256")},
        "ranked": out,
        "amdahl_warning": (
            "These bounds are independent. Do NOT multiply them: removing two phases "
            "is not the product of their individual factors, and unrelated device/host "
            "factors must not be composed at all."
        ),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("logs", nargs="+", help="prover output logs to parse")
    ap.add_argument("--command", default="",
                    help="command that produced the log (the log's own CMD: line is read too; a conflict is a refusal)")
    ap.add_argument("--exit-code", type=int, default=None,
                    help="exit code of that command (the log's own `exit N` line is read too; a conflict is a refusal)")
    ap.add_argument("--rank", action="store_true",
                    help="also rank the top exclusive costs of the first ELIGIBLE row; diagnostic rows are listed, never ranked")
    a = ap.parse_args()
    rows = []
    for p in a.logs:
        text = Path(p).read_text(errors="replace")
        try:
            r = attribute(parse_log(text, a.command, a.exit_code))
        except ProfileError as e:
            print(f"{p}: REFUSED — {e}", file=sys.stderr)
            return 2
        r["log"] = p
        rows.append(r)
    eligible = [r for r in rows if r["eligible"]]
    doc: dict = {"schema": 2, "measured": True, "rows": rows,
                 "eligible_rows": len(eligible), "diagnostic_rows": len(rows) - len(eligible)}
    for r in rows:
        if not r["eligible"]:
            print(f"{r['log']}: DIAGNOSTIC (not evidence) — " + "; ".join(r["ineligible_reasons"]),
                  file=sys.stderr)
    if a.rank:
        if not eligible:
            print("REFUSED — no eligible row to rank", file=sys.stderr)
            return 2
        try:
            doc["ranking"] = rank(eligible)
        except ProfileError as e:
            print(f"REFUSED — {e}", file=sys.stderr)
            return 2
        doc["ranking"]["excluded_diagnostic_rows"] = [
            {"log": r["log"], "reasons": r["ineligible_reasons"]} for r in rows if not r["eligible"]]
    print(json.dumps(doc, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
