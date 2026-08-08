#!/usr/bin/env python3
"""U-AG-B1 Agent BA: BOTH-DIRECTION freeze rows for the aggregation
design-round constants (R-EB1..R-EB4, kappa 11, C-win window constants,
and the R-FC2 per-group digit-headroom rows).

WHAT "BOTH DIRECTIONS" MEANS (the LKP-7/8/9 house pattern, in script
form): every pinned constant is RE-DERIVED here from its recorded
formula/derivation — transcribed from the design docs and spikes, cited
inline — and asserted EQUAL to the pin. If the derivation chain moves
(someone edits a transcribed formula, or the underlying design constant
drifts), the row FAILS; if someone edits the pin without re-deriving,
the row FAILS. [MODEL]-flagged measured constants (the R-EB1 Monte-Carlo
acceptance table) cannot be re-derived arithmetically; their rows pin
the recorded values and assert the recorded consistency gates instead
(the spike's own bands), so an edit on either side still fails.

Sources (all repo-recorded; section cited per row below):
  SC  = docs/zkmatrix-poc/AGGREGATION_SOUNDNESS_COMPOSITION.md
  DA  = docs/zkmatrix-poc/AGGREGATION_PARAMS_DESIGN.md
  FD  = docs/zkmatrix-poc/AGGREGATION_FOLDING_DESIGN.md
  FS  = docs/zkmatrix-poc/AGGREGATION_FOLDING_SOUNDNESS.md
  EA  = docs/zkmatrix-poc/AGGREGATION_ENCODING_DESIGN.md
  spike-EB = scripts/slack_composition_spike.py   (36/36, re-run 2026-08-08)
  spike-FA = scripts/aggregation_folding_spike.py (33/33, re-run 2026-08-08)

Structure:
  Section 0 — house constants (params.rs / DA Section 1) re-derived.
  Section 1 — R-EB1: T_cap = 33 sampled-cap rule.
  Section 2 — R-EB2: NS22 garbage-optimization prohibition + full
              r(r+1) garbage count.
  Section 3 — R-EB3: ct-aggregation sizing (t >= 7) / K-draw restructure.
  Section 4 — R-EB4: floor-base cap e <= 7, validity line 2^30.5,
              kappa = 11, C-win window constants.
  Section 5 — R-FC2: per-group digit-headroom rows (pass scope).
  Section 6 — verdict table print + exit code.

Runs on stdlib only, < 1 s. Exit 0 iff every row holds.
"""

import math
import sys

FAILURES = []
ROWS = []


def row(row_id, constant, pinned, derived, source, flag="", tol=0.0):
    """One freeze row. pinned == derived (within tol for floats) or FAIL."""
    if isinstance(pinned, float) or isinstance(derived, float):
        ok = abs(float(pinned) - float(derived)) <= tol
    else:
        ok = pinned == derived
    ROWS.append((row_id, constant, pinned, derived, ok, source, flag))
    if not ok:
        FAILURES.append(row_id)
    print("  [%s] %-14s %-38s pin=%-14s derived=%-14s %s%s"
          % ("OK" if ok else "FAIL", row_id, constant, repr(pinned),
             repr(round(derived, 6) if isinstance(derived, float) else derived),
             source, (" " + flag) if flag else ""))
    return ok


def gate(row_id, description, ok, source, flag=""):
    """A boolean gate row (an inequality or verdict that must hold)."""
    ROWS.append((row_id, description, True, ok, ok, source, flag))
    if not ok:
        FAILURES.append(row_id)
    print("  [%s] %-14s %s  %s%s" % ("OK" if ok else "FAIL", row_id,
                                     description, source,
                                     (" " + flag) if flag else ""))
    return ok


# ===========================================================================
# Section 0 — house constants (derivation side inputs)
# ===========================================================================
# (transcribed; skeleton commit — full content in the next commit)

def main():
    print("aggregation_freeze_rows — U-AG-B1 BA freeze rows (skeleton)")
    print("RESULT: %d rows, %d FAIL" % (len(ROWS), len(FAILURES)))
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
