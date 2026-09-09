#!/usr/bin/env python3
"""Adversarial preflight checks against a REAL retained IO capture, no mocks.

Run explicitly with --capture and --source-commit. These are integration
controls, not default unit tests dependent on a particular machine's /tmp.
They test capture ingestion; Rust separately tests and replays the actual proof.
"""
import argparse
import copy
import json
from pathlib import Path

import zk60_io_capture_preflight as check


def run(path, source):
    raw = path.read_bytes()
    capture = json.loads(raw, object_pairs_hook=check.no_duplicates, parse_float=check.no_float, parse_constant=check.no_float)
    check.check_raw(capture, source)
    ai = next(i for i, r in enumerate(capture["roles"]) if r["role"] == "A")
    # Paths into the accepted capture and concrete mutations. Each must be
    # refused even when no external digest check is used to catch the change.
    mutations = [
        ("legacy_schema", ["schema"], 2),
        ("superseded_io_profile", ["profile"], "ffn-v3-mr1-fresh-io-poc/1"),
        ("relabelled_source", ["source_commit"], "0" * 40),
        ("partial_verification", ["fully_verified"], False),
        ("privacy_acceptance_claim", ["privacy_review_complete"], True),
        ("legacy_A_rows", ["roles", ai, "commitment", "rows"], 698),
        ("missing_mask_pair", ["roles", ai, "claims", 18, "parts"], capture["roles"][ai]["claims"][18]["parts"][:2]),
        ("copied_plane_alias", ["roles", ai, "claims", 18, "parts", 0, "offset"], 0),
        ("wrong_pair_coefficient", ["roles", ai, "claims", 18, "parts", 2, "coefficient"], [0, 0]),
        ("wrong_symbolic_role", ["roles", ai, "claims", 18, "parts", 0, "coefficient_tag"], "old-FFN"),
        ("missing_IO_group", ["roles", ai, "groups"], capture["roles"][ai]["groups"][:-1]),
        ("group_vector_terminal_mismatch", ["roles", ai, "groups", 5, "vector", 0], [0, 0]),
        ("short_proximity", ["roles", ai, "proximity_vector"], capture["roles"][ai]["proximity_vector"][:-1]),
        ("missing_output_endpoint", ["roles"], capture["roles"][:-1]),
        ("swapped_endpoint_roles", ["roles"], capture["roles"][:-2] + capture["roles"][-2:][::-1]),
        ("endpoint_mask_as_data", ["roles", len(capture["roles"])-1, "row_roles", 3, "kind"], "data"),
        ("missing_IO_mask_slots", ["mask", "specs"], capture["mask"]["specs"][:6]),
        ("old_mask_column_width", ["mask", "columns", 0, "values"], capture["mask"]["columns"][0]["values"][:16]),
        ("missing_mask_functional", ["mask", "functionals"], capture["mask"]["functionals"][:-1]),
        ("mask_functional_wrong_width", ["mask", "functionals", 0, "terms", 0, "weights"], []),
        ("out_of_domain_M_column", ["mask", "columns", 0, "index"], 4096),
        ("noncanonical_sampled_word", ["roles", ai, "columns", 0, "values", 0], check.old.P),
        ("boolean_field_coordinate", ["roles", ai, "groups", 0, "vector", 0, 0], True),
        ("broken_opening_join", ["mask", "after", "next"], [0, 0]),
        ("broken_equality_join", ["io_arguments", 1, "before", "next"], [0, 0]),
        ("wrong_equality_slot", ["io_arguments", 1, "slot"], 6),
        ("wrong_endpoint_terminal", ["io_arguments", 1, "terminals", 1], [0, 0]),
        ("changed_endpoint_policy", ["expected_policy_sha256"], "0"*64),
        ("missing_FFN_round", ["ffn_arguments", 0, "rounds"], capture["ffn_arguments"][0]["rounds"][:-1]),
    ]
    results = []
    for name, keys, value in mutations:
        candidate = copy.deepcopy(capture)
        cursor = candidate
        for key in keys[:-1]: cursor = cursor[key]
        cursor[keys[-1]] = value
        try:
            check.check_raw(candidate, source)
        except ValueError as error:
            results.append({"name": name, "rejected": True, "reason": str(error)})
        else:
            raise AssertionError(f"mutation accepted: {name}")
    for name, raw in [("duplicate_key", '{"x":1,"x":2}'), ("float", '{"x":1.0}'), ("NaN", '{"x":NaN}')]:
        try:
            json.loads(raw, object_pairs_hook=check.no_duplicates, parse_float=check.no_float, parse_constant=check.no_float)
        except ValueError as error:
            results.append({"name": name, "rejected": True, "reason": str(error)})
        else:
            raise AssertionError(f"malformed JSON accepted: {name}")
    check.check_raw(capture, source)
    return {"schema": 1, "status": "passed", "source_commit": source, "capture_path": str(path), "capture_sha256": check.digest(path.read_bytes()),
            "positive_control": "unmodified real capture accepted before and after mutations", "negative_controls": results,
            "tools": {p.name: check.digest(p.read_bytes()) for p in [Path(__file__), Path(check.__file__)]}, "privacy_analysis_performed": False}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--capture", type=Path, required=True)
    ap.add_argument("--source-commit", required=True)
    ap.add_argument("--output", type=Path, required=True)
    a = ap.parse_args()
    result = run(a.capture, a.source_commit)
    a.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Passed {len(result['negative_controls'])} ingestion controls against a real IO capture.")


if __name__ == "__main__":
    main()
