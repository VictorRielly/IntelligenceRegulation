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
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

TIMING = re.compile(r"^HASHLINE_TIMING (\{.*\})\s*$")
PHASE_HDR = re.compile(r"^prover phases \(summed over layers\):")
PHASE = re.compile(r"^ {6}(\S.*?)\s{2,}([0-9.]+) s\s*$")
DEVICE = re.compile(r"^\s*gpu device-side \(summed\): (.*)$")
GPU_ON = re.compile(r"^\s*gpu: (ON|off)\b(.*)$")
DECLINED = re.compile(r"gpu .* declined \(([^)]*)\)")
SHA = re.compile(r"^PROOF sha256 ([0-9a-f]{64}) \((\d+) B\)")
# the verdict comes BEFORE the colon: "PASS-V3 ACCEPT [ZK]: 12 x 512 ..."
ACCEPT = re.compile(r"^(PASS\S*)\s+(ACCEPT|REJECT)\b")
DEV_FIELD = re.compile(r"(\w+) ([0-9.]+) s(?: \((\d+) MB\))?")
VRAM = re.compile(r"vram peak (\d+) MB")


class ProfileError(ValueError):
    pass


def parse_log(text: str, command: str = "", exit_code: int | None = None) -> dict:
    row: dict = {
        "command": command,
        "exit_code": exit_code,
        "device": None,
        "gpu_enabled_line": None,
        "cpu_fallbacks": [],
        "phases_s": {},
        "device_side": {},
        "proof_sha256": None,
        "proof_bytes": None,
        "verdict": None,
        "timing": None,
    }
    in_phases = False
    for line in text.splitlines():
        m = TIMING.match(line)
        if m:
            row["timing"] = json.loads(m.group(1))
            continue
        if PHASE_HDR.match(line):
            in_phases = True
            continue
        if in_phases:
            m = PHASE.match(line)
            if m:
                row["phases_s"][m.group(1).strip()] = float(m.group(2))
                continue
            # any other line ends the block
            if line.strip() and not line.startswith("      "):
                in_phases = False
        m = GPU_ON.match(line)
        if m:
            row["gpu_enabled_line"] = line.strip()
            row["device"] = line.strip()
            continue
        m = DECLINED.search(line)
        if m:
            row["cpu_fallbacks"].append(m.group(1))
            continue
        m = DEVICE.match(line)
        if m:
            body = m.group(1)
            for name, secs, mb in DEV_FIELD.findall(body):
                row["device_side"][f"{name}_s"] = float(secs)
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
    return row


def attribute(row: dict) -> dict:
    """Exclusive attribution, with the unaccounted remainder made explicit."""
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
    known_top = sum(v for v in top.values() if v is not None)
    out = {
        "shape": {"layers": t.get("layers"), "tokens": t.get("tokens"),
                  "d": t.get("d"), "f": t.get("f")},
        "privacy": t.get("privacy"),
        "coverage": t.get("coverage"),
        "gpu_requested": t.get("gpu_requested"),
        "gpu_enabled": t.get("gpu_enabled"),
        "device": row["device"],
        "verified": t.get("verified"),
        "verdict": row["verdict"],
        "proof_sha256": row["proof_sha256"],
        "proof_bytes": row["proof_bytes"] or t.get("proof_bytes"),
        "command": row["command"],
        "exit_code": row["exit_code"],
        "cpu_fallback_count": len(row["cpu_fallbacks"]),
        "cpu_fallbacks": row["cpu_fallbacks"],
        "top_level_s": top,
        "proof_ready_s": ready,
        "proof_ready_unknown_s": None if ready is None else round(ready - known_top, 6),
        "prove_phases_s": dict(sorted(phases.items(), key=lambda kv: -kv[1])),
        "prove_phase_sum_s": round(phase_sum, 6),
        "unknown_exclusive_s": None if prove is None else round(prove - phase_sum, 6),
        "device_side": row["device_side"],
    }
    return out


def rank(rows: list[dict], top_n: int = 3) -> dict:
    """Top exclusive costs and the BOUNDED Amdahl gain of removing each.

    Each bound is computed on its own against the same proof-ready clock.
    Factors are never multiplied together: two phases removed at once is not
    the product of their individual speedups, and presenting it that way is
    how a 1.05x becomes an imaginary 4x.
    """
    if not rows:
        raise ProfileError("no rows to rank")
    base = rows[0]
    ready = base["proof_ready_s"]
    if not ready:
        raise ProfileError("no proof_ready_s to rank against")
    items = sorted(base["prove_phases_s"].items(), key=lambda kv: -kv[1])[:top_n]
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
    ap.add_argument("--command", default="", help="command that produced the log")
    ap.add_argument("--exit-code", type=int, default=None)
    ap.add_argument("--rank", action="store_true", help="also rank the top exclusive costs")
    a = ap.parse_args()
    rows = []
    for p in a.logs:
        text = Path(p).read_text(errors="replace")
        try:
            rows.append(attribute(parse_log(text, a.command or p, a.exit_code)))
        except ProfileError as e:
            print(f"{p}: REFUSED — {e}", file=sys.stderr)
            return 2
    doc: dict = {"schema": 1, "measured": True, "rows": rows}
    if a.rank:
        doc["ranking"] = rank(rows)
    print(json.dumps(doc, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
