#!/usr/bin/env python3
"""[gate round 10, the frozen-r9 re-pin] The DETERMINISTIC figures of two gate
records of the same bundle kind, side by side: the figures the tk7 note
compared with R7 (replay challenges / positions; columns checked,
authenticated and bytes hashed; every commitment's role, disclosed dimension,
rows, claims and groups; the terminal slot checks; the channel counts; the
mask entries recomputed; the whole-run joint and its sum of parts; the E3
identity check).  Randomness-dependent figures (opened columns, pad block,
determinants, roots) are not among them; `compare_records.py` lists those
leaf by leaf.  Reads JSON only.
    python3 compare_figures.py <out.json> <new.json> <old.json> [<new> <old> ...]
"""
import json
import sys


def g(o, *path):
    for k in path:
        if o is None:
            return None
        if isinstance(o, list) and isinstance(k, int):
            o = o[k] if len(o) > k else None
        elif isinstance(o, dict):
            o = o.get(k)
        else:
            return None
    return o


def figures(r):
    pcs = g(r, "stage3_per_commitment", "per_commitment") or []
    ti = g(r, "stage8_plane_index_and_terminals", "terminal_identity") or {}
    return {
        "replay_challenges": g(r, "stage2_transcript_replay", "challenges_checked"),
        "replay_positions": g(r, "stage2_transcript_replay", "positions_checked"),
        "run_binding_reproduced": g(r, "stage2_transcript_replay", "run_binding_reproduced"),
        "hash_columns_checked": g(r, "stage9_hash_layer", "columns_checked"),
        "hash_columns_authenticated": g(r, "stage9_hash_layer", "columns_authenticated"),
        "hash_bytes": g(r, "stage9_hash_layer", "bytes_hashed"),
        "commitments": [[p.get("role"), p.get("disclosed_dimension"), p.get("rows"), p.get("claims"),
                         p.get("groups")] for p in pcs],
        "terminal_slot_checks": [ti.get("slot_checks_equal"), ti.get("slot_checks_expected")],
        "channels": g(r, "stage7_channels", "counts"),
        "mask_entries_recomputed": g(r, "stage12_mask_and_cfs", "entries_recomputed"),
        "mask_entries_differing": g(r, "stage12_mask_and_cfs", "entries_differing"),
        "full_preimage_differing": g(r, "stage11_full_preimage", "view_entries_differing"),
        "joint_couplings_respected": g(r, "stage13_joint_run_preimage", "all_four_couplings_respected"),
        "whole_run_joint_fp": g(r, "stage4_the_boundary", "whole_run", "joint_fp"),
        "whole_run_joint_equals_sum_of_parts": g(r, "stage4_the_boundary", "whole_run", "joint_equals_sum_of_parts"),
        "E3_identity_equal": g(r, "stage14_export_crosscheck", "E3_statement", "identity_equal"),
        "E3_statement_sha256": g(r, "stage14_export_crosscheck", "E3_statement", "statement_sha256"),
        "export_ok": g(r, "stage14_export_crosscheck", "ok"),
    }


def main(argv):
    out = []
    allequal = True
    for new, old in zip(argv[1::2], argv[2::2]):
        a, b = figures(json.load(open(new))), figures(json.load(open(old)))
        diff = {k: {"new": a[k], "old": b[k]} for k in a if a[k] != b[k]}
        allequal &= not diff
        out.append({"new": new, "old": old, "figures_new": a, "differing": diff, "equal": not diff})
        print(f"{new.split('/')[-1]} vs {old.split('/')[-1]}: {'EQUAL' if not diff else 'DIFFER ' + str(sorted(diff))}"
              f"; challenges {a['replay_challenges']}, positions {a['replay_positions']}, commitments {len(a['commitments'])}, "
              f"terminals {a['terminal_slot_checks']}, joint {a['whole_run_joint_fp']}, E3 {a['E3_identity_equal']}")
    json.dump({"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False,
               "every_pair_equal": allequal, "pairs": out}, open(argv[0], "w"), indent=1)
    print("every pair equal:", allequal)


if __name__ == "__main__":
    main(sys.argv[1:])
