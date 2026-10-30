#!/usr/bin/env python3
"""Token round 14: Astra's coverage numbers (category_chunk_coverage.json) re-counted under round 14's split.

COUNTED from input lengths only (no model load, no proof). Reads Astra's files READ-ONLY:
  results/zk60_shieldstral_export_20261026/category_policy_candidates.json
  results/zk60_shieldstral_export_20261026/evaluation_inputs/input.json
and checks they are the ones Astra's coverage file pins (policies_sha256, inputs_sha256).

Round 14's rule (classify.rs chunk_ranges): an item of N >= 1 content ids is accepted; N < size is ONE chunk of
its own length (its trailing positions pinned to the public pad id), N >= size is the D41 split
(K = 1 + ceil((N - size) / (size - overlap))). N = 0 is refused (an empty content).
The overlap is registered only for the development rung (4); for the Shieldstral profiles it is NOT registered,
so K is reported for overlap 0 and 4 as a [MODEL] assumption.

usage: short_item_coverage.py OUT.json
"""
import hashlib, json, math, sys
from collections import defaultdict
from pathlib import Path

A = Path("/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026")


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def chunks(n, size, overlap):
    if n == 0:
        return None
    if n < size:
        return 1
    return 1 + math.ceil((n - size) / (size - overlap))


def main():
    out = Path(sys.argv[1])
    cov_p, pol_p, inp_p = A / "category_chunk_coverage.json", A / "category_policy_candidates.json", A / "evaluation_inputs/input.json"
    cov = json.loads(cov_p.read_text())
    assert sha(pol_p) == cov["policies_sha256"], "the policy candidates are not the ones Astra's coverage file pins"
    assert sha(inp_p) == cov["inputs_sha256"], "the inputs are not the ones Astra's coverage file pins"
    policies, inputs = json.loads(pol_p.read_text()), json.loads(inp_p.read_text())
    assert len(inputs["rows"]) == 4872
    groups = defaultdict(list)
    for row in inputs["rows"]:
        groups[(row["template"], row["dataset"])].append(row["content_tokens"])
    rows = []
    for (template, dataset), lengths in sorted(groups.items()):
        for t, size in policies["policies"][template]["content_tokens_by_T"].items():
            n_items = len(lengths)
            empty = sum(n == 0 for n in lengths)
            short = sum(0 < n < size for n in lengths)
            exact = sum(n == size for n in lengths)
            longer = sum(n > size for n in lengths)
            r = {"template": template, "dataset": dataset, "T": int(t), "chunk_size": size, "items": n_items,
                 "refused_round13": short + empty, "refused_round14_empty_content": empty,
                 "accepted_round14": n_items - empty, "acceptance_share_round14": (n_items - empty) / n_items,
                 "acceptance_share_round13": (n_items - short - empty) / n_items,
                 "short_items_now_one_chunk": short, "exact_single_chunk_items": exact, "longer_items_split": longer,
                 "pad_positions_of_short_items": {"min": min((size - n for n in lengths if 0 < n < size), default=None),
                                                  "max": max((size - n for n in lengths if 0 < n < size), default=None)}}
            for o in (0, 4):
                ks = [chunks(n, size, o) for n in lengths if n > 0]
                r[f"chunk_proofs_overlap{o}_MODEL"] = {"total": sum(ks), "max_per_item": max(ks), "mean_per_item": sum(ks) / len(ks)}
            # cross-check against Astra's counts for the same group
            a = [c for c in cov["counts"] if (c["template"], c["dataset"], c["T"]) == (template, dataset, int(t))]
            assert len(a) == 1 and a[0]["short_items_refused_by_current_native_split"] == short + empty and a[0]["items"] == n_items, (template, dataset, t)
            rows.append(r)
    by_t = {}
    for t in sorted({r["T"] for r in rows}):
        rs = [r for r in rows if r["T"] == t]
        by_t[str(t)] = {"acceptance_share_round13_range": [min(r["acceptance_share_round13"] for r in rs), max(r["acceptance_share_round13"] for r in rs)],
                        "acceptance_share_round14_range": [min(r["acceptance_share_round14"] for r in rs), max(r["acceptance_share_round14"] for r in rs)],
                        "items_refused_round13": sum(r["refused_round13"] for r in rs), "items_refused_round14": sum(r["refused_round14_empty_content"] for r in rs),
                        "group_policy_rows": len(rs), "item_policy_pairs": sum(r["items"] for r in rs)}
    result = {"schema": "zk60-token-r14-short-item-coverage/1",
              "label": "COUNTED from input lengths only (no model load, no proof run); unweighted; the Shieldstral chunk overlap is unregistered, so chunk-proof counts are MODEL (overlap 0 and 4)",
              "rule": "round 14 chunk_ranges: N >= 1 accepted; N < size is one chunk of length N (trailing positions = the public pad id); N >= size the D41 split; N = 0 refused",
              "astra_coverage_sha256": sha(cov_p), "policies_sha256": cov["policies_sha256"], "inputs_sha256": cov["inputs_sha256"],
              "tool_sha256": sha(Path(__file__)), "by_T": by_t, "counts": rows,
              "not_counted": "proof-time refusals (CS-3 range checks on an adversarial or unusual item, the pad rows at Shieldstral) and the registration of the Shieldstral classifier run profile (not built)"}
    out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"by_T": by_t}, indent=1))


if __name__ == "__main__":
    main()
