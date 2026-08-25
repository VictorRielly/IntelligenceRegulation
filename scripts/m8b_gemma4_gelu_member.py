#!/usr/bin/env python3
"""m8b_gemma4_gelu_member.py — U-PERF3 lane Y: int8 gelu_pytorch_tanh
table-member candidates for the C5 open table registry
(docs/zkmatrix-poc/QUANTIZATION_CONTRACT_DESIGN.md: registry keyed by
(function, e_in, e_out); adding a member is a table freeze by ruling,
never a protocol change).

GENERATION + DIGEST ONLY — no manifest.rs / lookup.rs edit happens
here. The construction mirrors the FROZEN silu-int8-table-v2 family
(zkmatrix-rs/src/ring/lookup.rs L119-242) EXACTLY:

  family formula (lookup.rs silu_v2_generate, L191-201, with the
  activation swapped to the model's gelu_pytorch_tanh — the Gemma 4
  GeGLU gate, walker facts F3):

    S[g] = clamp(round_half_up(gelu_tanh(g * 2^e_in) / 2^e_out),
                 -127, 127),   g = -128..127,
    gelu_tanh(x) = 0.5*x*(1 + tanh(sqrt(2/pi)*(x + 0.044715*x^3)))
    evaluated in f64; round_half_up(x) = floor(x + 1/2).

  digest convention (lookup.rs table_spec_digest_v2, L224-242 /
  scripts/m125_export_ffn.py silu_v2_digest): sha256 over the
  canonical spec-header JSON with SIGNED scale exponents and the
  [v, S[v]] row list; only the function name and rounding string name
  the new family:

    {"function":"gelu-tanh-int8-table-v2",
     "input":{"width":8,"scale_exp":E_IN,"signed":true},
     "output":{"width":8,"scale_exp":E_OUT,"signed":true},
     "rounding":"y = clamp(round_half_up(gelu_tanh(x*2^in_exp)/2^out_exp), -127, 127)",
     "table":[[-128,S],...,[127,S]]}

Self-gate: on import the module regenerates BOTH frozen silu-v2
members through scripts/m125_export_ffn.py and asserts their pinned
digests — the same generate/digest code path discipline, so a platform
or convention drift is loud here before any gelu digest is trusted.

No member is frozen yet: EVERY pair this prints is a C5 candidate for
the ruling (the analogue of the calibration script's W-6 lines).
"""

import argparse
import hashlib
import math
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_export_ffn as m125x  # noqa: E402  (frozen silu family — the pins)

FUNCTION = "gelu-tanh-int8-table-v2"
ROUNDING = ("y = clamp(round_half_up(gelu_tanh(x*2^in_exp)/2^out_exp), "
            "-127, 127)")

# The frozen registry for this family — EMPTY until a C5 ruling.
GELU_V2_PINS = {}


def _selfcheck_silu_pins():
    """The two frozen silu-v2 pins must reproduce through the imported
    generator/digest (drift detector — the lookup.rs freeze-row
    discipline)."""
    for (eg, ea), pin in m125x.SILU_V2_PINS.items():
        t = m125x.silu_v2_generate(eg, ea)
        dg = m125x.silu_v2_digest(eg, ea, t)
        assert dg == pin, \
            "silu-v2 pin drift at (%d,%d): %s" % (eg, ea, dg)


_selfcheck_silu_pins()


def gelu_tanh(x):
    """gelu_pytorch_tanh in f64 (walker facts F3 / HF activations.py
    GELUTanh)."""
    return 0.5 * x * (1.0 + math.tanh(math.sqrt(2.0 / math.pi)
                                      * (x + 0.044715 * x ** 3)))


def gelu_v2_generate(e_in, e_out):
    """The family generation formula (silu_v2_generate with the
    activation swapped), byte-deterministic in f64."""
    out = np.zeros(256, dtype=np.int8)
    for i in range(256):
        g = i - 128
        x = g * (2.0 ** e_in)
        y = gelu_tanh(x)
        v = math.floor(y / (2.0 ** e_out) + 0.5)
        out[i] = max(-127, min(127, v))
    return out


def gelu_v2_digest(e_in, e_out, table):
    """The canonical v2 spec-header digest (table_spec_digest_v2
    layout, this family's name/rounding strings)."""
    j = ('{"function":"%s",'
         '"input":{"width":8,"scale_exp":%d,"signed":true},'
         '"output":{"width":8,"scale_exp":%d,"signed":true},'
         '"rounding":"%s",'
         '"table":[' % (FUNCTION, e_in, e_out, ROUNDING))
    j += ','.join('[%d,%d]' % (i - 128, int(s))
                  for i, s in enumerate(table))
    j += ']}'
    return hashlib.sha256(j.encode()).hexdigest()


def gelu_members(scales):
    """Distinct calibrated (eGate, eA) pairs -> {pair: (table, digest,
    frozen?)} — the m8b silu_members structure, so the SAME int8-chain
    code consumes it. New members are C5 candidates, not an error."""
    out = {}
    for sc in scales:
        key = (sc["eGate"], sc["eA"])
        if key in out:
            continue
        t = gelu_v2_generate(*key)
        dg = gelu_v2_digest(key[0], key[1], t)
        frozen = GELU_V2_PINS.get(key) == dg
        out[key] = (t, dg, frozen)
    return out


def report_gelu_members(members):
    """The calibration script's member-line format, gelu family."""
    fresh = [(k, dg) for k, (t, dg, fr) in members.items() if not fr]
    for k, (t, dg, fr) in members.items():
        print("  %s member (eGate %d, eA %d): digest %s… %s"
              % (FUNCTION, k[0], k[1], dg[:16],
                 "= frozen pin" if fr else "** NOT IN ANY FROZEN "
                 "FAMILY — C5 registry ruling needed before the rig "
                 "accepts this statement **"), flush=True)
    return fresh


def member_stats(table, e_in, e_out):
    """Freeze-row-style facts: output range, clamp fires, identity-ish
    tail (how many of the top slots are the linear ramp)."""
    lo, hi = int(table.min()), int(table.max())
    clamps = 0
    for i in range(256):
        g = i - 128
        v = math.floor(gelu_tanh(g * (2.0 ** e_in)) / (2.0 ** e_out)
                       + 0.5)
        if v < -127 or v > 127:
            clamps += 1
    return lo, hi, clamps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pairs", default=None,
                    help="explicit 'eIn,eOut;eIn,eOut;...' candidate "
                         "pairs (default: the -5..-1 diagonal band the "
                         "silu family history makes plausible)")
    ap.add_argument("--dump", default=None,
                    help="also write each table's 256 bytes + digest "
                         "to this directory (candidate freeze record)")
    args = ap.parse_args()

    if args.pairs:
        pairs = []
        for tok in args.pairs.split(";"):
            a, b = tok.split(",")
            pairs.append((int(a), int(b)))
    else:
        # The silu family's calibrated history lives on/near the
        # diagonal (m125: (-3,-3),(-4,-4); Mistral W-6 flags: -5..-1
        # both axes). Candidates: the same band for the gelu gate.
        pairs = [(ei, eo)
                 for ei in range(-5, 0)
                 for eo in range(-5, 0)
                 if abs(ei - eo) <= 1]

    print("%s candidates (generation formula + digest convention: "
          "frozen silu-v2 family, lookup.rs L191-242; silu pins "
          "self-checked on import)" % FUNCTION)
    print("%-12s %-18s %5s %5s %7s   %s"
          % ("(eIn,eOut)", "out[min,max]", "clamp", "", "", "digest"))
    rows = []
    for (ei, eo) in pairs:
        t = gelu_v2_generate(ei, eo)
        dg = gelu_v2_digest(ei, eo, t)
        lo, hi, clamps = member_stats(t, ei, eo)
        rows.append(((ei, eo), t, dg, lo, hi, clamps))
        print("(%3d,%3d)    [%4d,%4d]        %5d           %s"
              % (ei, eo, lo, hi, clamps, dg))
    if args.dump:
        d = Path(args.dump)
        d.mkdir(parents=True, exist_ok=True)
        for (ei, eo), t, dg, lo, hi, clamps in rows:
            base = d / ("gelu_tanh_v2_%d_%d" % (ei, eo))
            base.with_suffix(".bytes.bin").write_bytes(t.tobytes())
            base.with_suffix(".digest.txt").write_text(
                "%s (eIn %d, eOut %d) sha256 %s  out[%d,%d] clamp %d\n"
                % (FUNCTION, ei, eo, dg, lo, hi, clamps))
        print("tables + digests -> %s" % d)
    print("NOTE: every pair above is a CANDIDATE — the C5 registry is "
          "empty for this family; freezing any member is a Victor "
          "ruling (manifest-pinned, like W-6).")


if __name__ == "__main__":
    main()
