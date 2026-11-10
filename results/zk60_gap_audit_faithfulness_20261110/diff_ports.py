"""Diff the 15 ported FlashProve files (formal/ZK60Formal/ThirdParty/FlashProve/) against the upstream files at
commit 9e2bdd8f (fetched by fetch_flashprove.py, verified by git blob). Prints, per file, the unified diff, and a
summary that classifies each changed line as: header comment, import path rename, or OTHER (a substantive change
that a reader must check).

Usage: python3 -I diff_ports.py <worktree> <upstream_dir>
"""
import difflib
import os
import re
import sys

PORTED = [
    "Prob/Count.lean", "Prob/Cnt.lean", "Code/Mutual.lean", "Code/Agree.lean", "Code/Third.lean", "Code/Half.lean",
    "Code/Lines/PolishchukSpielman.lean", "Code/Lines/Interpolation.lean", "Code/Lines/Bivariate.lean",
    "Code/Lines/Tight.lean", "Code/Lines/Multiplicity.lean", "Code/Lines/BerlekampWelch.lean",
    "Code/Lines/RelPrimeCase.lean", "Code/Lines/RelPrime.lean", "Code/Lines/ResultantDegree.lean",
]


def main() -> int:
    wt, up = sys.argv[1], sys.argv[2]
    total_other = 0
    summary = []
    for rel in PORTED:
        a = open(os.path.join(up, "lean", rel), encoding="utf-8").read().splitlines()
        b = open(os.path.join(wt, "formal/ZK60Formal/ThirdParty/FlashProve", rel), encoding="utf-8").read().splitlines()
        d = list(difflib.unified_diff(a, b, "upstream/" + rel, "ported/" + rel, lineterm="", n=1))
        print("=" * 100)
        print(rel, "upstream lines", len(a), "ported lines", len(b))
        print("\n".join(d))
        removed = [l[1:] for l in d if l.startswith("-") and not l.startswith("---")]
        added = [l[1:] for l in d if l.startswith("+") and not l.startswith("+++")]
        kinds = {"header": 0, "import": 0, "other_added": 0, "other_removed": 0}
        for l in added:
            if l.startswith("-- ") and ("Modified for ZK60Formal" in l or l.startswith("-- ")):
                kinds["header"] += 1
            elif re.match(r"^import ZK60Formal\.ThirdParty\.FlashProve\.", l):
                kinds["import"] += 1
            else:
                kinds["other_added"] += 1
        for l in removed:
            if re.match(r"^import (Prob|Code)\.", l):
                kinds["import"] += 0
            else:
                kinds["other_removed"] += 1
        summary.append((rel, len(a), len(b), len(removed), len(added), kinds))
        total_other += kinds["other_added"] + kinds["other_removed"]
    print("=" * 100)
    print("SUMMARY (removed/added line counts; 'other' = neither the added header comment nor an import rename)")
    for rel, la, lb, nr, na, k in summary:
        print(f"{rel:40s} up {la:5d} port {lb:5d}  -{nr:4d} +{na:4d}  header+{k['header']:3d} import {k['import']:3d}"
              f"  other+{k['other_added']:3d} other-{k['other_removed']:3d}")
    print("TOTAL other lines:", total_other)
    return 0


if __name__ == "__main__":
    sys.exit(main())
