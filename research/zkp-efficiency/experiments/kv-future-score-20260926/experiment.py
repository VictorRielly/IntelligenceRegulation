#!/usr/bin/env python3
"""Synthetic score-site experiment; no native proof/model/GPU execution."""
import hashlib
import json
from pathlib import Path
import re
import resource
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / "private-block-kernel/src/lib.rs"


def checked(x):
    assert -(1 << 63) <= x < 1 << 63, "i64 overflow"
    return x


def score(q, k):
    acc = 0
    for a, b in zip(q, k):
        acc = checked(acc + checked(a * b))
    return acc, checked(acc + 32) >> 6


def refused(table):
    # Native score requantization checks in (head, query, key) order.
    return [(list(index), raw, y) for index, (raw, y) in sorted(table.items())
            if not -127 <= y <= 127]


def main():
    start = time.perf_counter()
    text = SOURCE.read_text()
    constants = {}
    for name, expected in (("T", 32), ("H", 2), ("HKV", 1), ("DH", 8), ("SH_S", 6)):
        got = int(re.search(r"pub const " + name + r": (?:usize|i32) = (\d+);", text).group(1))
        assert got == expected, (name, got)
        constants[name] = got
    assert "requant_all(&mut s, SH_S, I8N, \"score\")?;" in text
    assert 'const I8N: (i64, i64) = (-127, 127);' in text
    t, heads, dh = constants["T"], constants["H"], constants["DH"]
    # Independent integer quotient/remainder oracle for signed tie behavior.
    boundary_points = (-8256, -8224, -8192, -8161, -8160, -8128, -33, -32,
                       -31, 0, 31, 32, 33, 8128, 8159, 8160, 8192, 8255)
    for raw in boundary_points:
        quotient, remainder = divmod(raw, 64)
        assert (raw + 32) >> 6 == quotient + int(remainder >= 32)

    cases = []
    # Only post-RoPE score operands are supplied. Their upstream reachability
    # from input/weights/normalization is deliberately NOT claimed.
    for name, qpos, kpos, key in (
        ("positive_future_violation", 0, 1, (64, 1)),
        ("negative_future_violation", 0, 1, (-65, 0)),
        ("positive_boundary_valid", 0, 1, (64, 0)),
        ("negative_boundary_valid", 0, 1, (-64, 0)),
        ("visible_violation_control", 1, 0, (64, 1)),
        ("all_zero_control", 0, 1, (0, 0)),
    ):
        q = [[[0] * dh for _ in range(t)] for _ in range(heads)]
        k = [[0] * dh for _ in range(t)]
        q[0][qpos][:2] = [127, 32]
        k[kpos][:2] = key
        assert all(-127 <= v <= 127 for head in q for row in head for v in row)
        assert all(-127 <= v <= 127 for row in k for v in row)
        dense = {(h, i, j): score(q[h][i], k[j])
                 for h in range(heads) for i in range(t) for j in range(t)}
        lower = {(h, i, j): value for (h, i, j), value in dense.items() if j <= i}
        incremental = {}
        for new in range(t):
            for h in range(heads):
                # Normal KV path: newly arrived query against all keys so far.
                for j in range(new + 1):
                    incremental[h, new, j] = score(q[h][new], k[j])
                # Extra frozen-relation obligation: old queries vs new key.
                for old in range(new):
                    incremental[h, old, new] = score(q[h][old], k[new])
        assert incremental == dense
        assert len(dense) == 2048 and len(lower) == 1056
        full_bad, lower_bad, inc_bad = map(refused, (dense, lower, incremental))
        assert inc_bad == full_bad
        if "future_violation" in name:
            assert len(full_bad) == 1 and not lower_bad
            assert full_bad[0][0] == [0, 0, 1]
        elif name == "visible_violation_control":
            assert full_bad == lower_bad and len(full_bad) == 1
        else:
            assert not full_bad and not lower_bad
        cases.append({"name": name, "dense_refusals": full_bad,
                      "lower_triangle_refusals": lower_bad,
                      "retained_old_Q_refusals": inc_bad})
    result = {
        "kind": "synthetic exact score-site arithmetic, not a native/full-model counterexample",
        "frozen_constants": constants,
        "dense_score_positions": 2048,
        "lower_triangle_score_positions": 1056,
        "extra_old_query_new_key_positions": 992,
        "cases": cases,
        "checks": {"source_constants": 5, "requant_boundary_points": len(boundary_points),
                   "dense_vs_retained_Q_complete_maps": 6,
                   "future_violation_controls": 2, "visible_violation_control": 1,
                   "valid_controls": 3},
        "limits": ["No proof or kernel was executed", "No upstream-reachable witness established",
                   "No full-block first-error ordering claim", "No performance projection"],
        "source_sha256": {str(SOURCE.relative_to(ROOT)): hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                          str(Path(__file__).relative_to(ROOT)): hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},
        "script_wall_s_not_prover_timing": time.perf_counter() - start,
        "script_peak_rss_kib_linux": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    }
    (HERE / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": "PASS", "cases": len(cases),
        "dense_positions": 2048, "lower_positions": 1056,
        "counterexample": cases[0], "script_wall_s": result["script_wall_s_not_prover_timing"],
        "rss_kib": result["script_peak_rss_kib_linux"]}, indent=2))


if __name__ == "__main__":
    main()
