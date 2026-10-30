"""Exact actual-run byte count and conditional backend soundness recount.

The PCS field ceiling and lookup lemma still need independent transfer review.
This is an author count; it assigns no security tier and registers no profile.
"""
from pathlib import Path
from datetime import datetime, timezone
from fractions import Fraction
import hashlib
import json
import math
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
EXPORT = ROOT / "results/zk60_shieldstral_export_20261026/native_low_h24_t128"
OUT = HERE / "FULL26_ACTUAL_CONDITIONAL_COUNT.json"
P = 2**64 - 2**32 + 1

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()

def main():
    assert not OUT.exists()
    native_path = HERE / "full26-native-1/ACCEPTANCE.json"
    census_path = HERE / "final-census-1/ACCEPTANCE.json"
    for path in [native_path, census_path]:
        assert path.with_suffix(".done").read_text().strip() == "0"
    native, census = [json.loads(p.read_text()) for p in [native_path, census_path]]
    assert native["source"] == census["source"]
    pins = {str(p.relative_to(ROOT)): sha(p) for p in [native_path, census_path, Path(__file__)]}
    profile_path = EXPORT / "profile.json"
    assert sha(profile_path) == "2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0"
    pins[str(profile_path.relative_to(ROOT))] = sha(profile_path)
    profile = json.loads(profile_path.read_text())
    assert profile["T"] == 128 and len(profile["layers"]) == 26
    layers = []
    for k, row in enumerate(profile["layers"]):
        assert row["layer"] == k
        path = EXPORT / row["dir"] / "manifest.json"
        assert sha(path) == row["manifest_sha256"]
        pins[str(path.relative_to(ROOT))] = sha(path)
        manifest = json.loads(path.read_text())
        spec = manifest["arrays"]["silu_groups"]
        assert spec["dtype"] == "int64" and spec["shape"][1] == 2
        groups = spec["shape"][0]
        assert groups in [3, 4]
        group_file = path.parent / spec["file"]
        assert sha(group_file) == spec["sha256"]
        assert group_file.stat().st_size == groups * 2 * 8
        pins[str(group_file.relative_to(ROOT))] = sha(group_file)
        ids_spec = manifest["arrays"]["silu_group_ids"]
        ids_file = path.parent / ids_spec["file"]
        assert ids_spec["dtype"] == "int64" and ids_spec["shape"] == [9216]
        assert sha(ids_file) == ids_spec["sha256"]
        ids = struct.unpack("<9216q", ids_file.read_bytes())
        assert all(0 <= value < groups for value in ids)
        pins[str(ids_file.relative_to(ROOT))] = sha(ids_file)
        assert manifest["constants"]["f_e"] == 9 and manifest["constants"]["f_p"] == 12
        layers.append({"layer": k, "groups": groups, "f_e": 9,
                       "populations": [ids.count(g) for g in range(groups)],
                       "narrow_populations": [ids[8192:].count(g) for g in range(groups)]})
    assert sum(layer["groups"] == 3 for layer in layers) == 12
    variants = []
    for mode in native["modes"]:
        dd = mode["dd"]
        inv = [row for row in census["inventory"] if row["tokens"] == 128 and row["f_e"] == 9 and row["dd"] == dd]
        assert len(inv) == 1
        inv = inv[0]
        groups = [row for row in census["groups"] if row["base"] == inv["base_profile"]]
        assert len(groups) == 1
        groups = groups[0]
        slots = [row for row in census["slot_definitions"] if row["base"] == inv["base_profile"]]
        assert len(slots) == inv["slots"]
        n, q, rate = inv["n"], 256, 4
        path_len = (n * rate).bit_length() - 1
        def opening(g, r):
            return (g + 1) * (n + q) * 16 + q * (8 + r * 8 + 32 + path_len * 32)
        slot_bytes = sum((1 + (s["main"] + s["ext"]) * (s["degree"] + 1) + s["terminals"]) * 16 for s in slots)
        sc_stage = sum((s["main"] + s["ext"]) * s["degree"] for s in slots)
        assert sc_stage == groups["sc_round_degree_sum"]
        body = (3 * 32 + slot_bytes + 2 * 1024 * 16 + q * (8 + inv["m_rows"] * 8 + 32 + 12 * 32)
                + opening(groups["a_groups"], inv["a_rows"]) + opening(groups["h_groups"], inv["h_rows"]))
        stage_counts = []
        for k, layer in enumerate(layers):
            length = (120 + (32 if k < 25 else 0) + body + 32
                      + opening(2 if k == 0 else 4, 31 if k == 0 else 34)
                      + (opening(2, 31) if k == 25 else 0))
            segment = mode["segments"][k]
            assert segment["index"] == k and segment["bytes"] == length, (dd, k, segment["bytes"], length)
            N = inv["byte_queries"] + 32 * 128**2 + 128 * 9216 + (32 * 128**2 if dd else 0)
            Td = 512 + 4096 * layer["groups"] + (32 * 128 * 32 if dd else 0)
            assert N < 2**32
            stage_counts.append({**layer, "bytes": length, "N": N, "T_d": Td,
                                 "lookup_field_numerator": N + 4 * Td - 1, "sc_round_degree_numerator": sc_stage})
        regular, masks, commitments = 79, 26, 105
        assert regular == 3 * 26 + 1 and commitments == 4 * 26 + 1
        erasure = (n * rate - (n + q)) // 3
        pcs_field = regular * (erasure + 1 + 4096) + masks * (1025 + 4096)
        lookup_field = sum(stage["lookup_field_numerator"] for stage in stage_counts)
        sc_field = 26 * sc_stage
        column_base = Fraction(2 * n * rate + n + q, 3 * n * rate)
        column = regular * column_base**q + masks * Fraction(3, 4)**q
        total = column + Fraction(pcs_field + lookup_field + sc_field, P * P)
        variants.append({"dd": dd, "layers": stage_counts, "bytes": sum(s["bytes"] for s in stage_counts),
             "all_segment_lengths_match_native": True, "regular_openings": regular, "mask_openings": masks,
             "total_commitments": commitments, "lookup_field_numerator": lookup_field,
             "pcs_field_numerator_ceiling": pcs_field, "sumcheck_field_numerator": sc_field,
             "field_denominator": P * P, "column_term": {"regular_base": [column_base.numerator, column_base.denominator],
                 "regular_multiplicity": regular, "mask_base": [3, 4], "mask_multiplicity": masks, "exponent": q},
             "conditional_backend_bits": -math.log2(float(total))})
        assert variants[-1]["bytes"] == mode["bytes"]
    OUT.write_text(json.dumps({"utc": datetime.now(timezone.utc).isoformat(), "source": native["source"],
         "variants": variants, "source_sha256": pins, "privacy_accepted": False, "security_tier_assigned": False,
         "assumptions": "Conditional on the pinned tagged hash/Fiat-Shamir/CFS model and retained PCS ceilings. Hash-collision, RNG-failure and grinding budgets are not independently assigned by this author count.",
         "scope": "COUNTED actual26 T128 S2 backend, all52 native segment lengths exactly match final compiled census/codec formulas; authenticated per-layer3/4 ACT groups. Conditional lookup/PCS/sumcheck/column union bound only, no classifier/token composition or registration.",
         "pending": ["Independent transfer of lookup nonzero-residue and degree2 collision lemma to final split H supports",
                     "Independent PCS/CFS field ceiling transfer (4096 retained conservative ceiling)",
                     "Whole classifier/token composition before any security tier assignment",
                     "Global H/column/joint rank, complete host polynomial, NL1 and privacy gates"]}, indent=2) + "\n")
    print(json.dumps([{"dd": v["dd"], "bytes": v["bytes"], "conditional_backend_bits": v["conditional_backend_bits"]} for v in variants]))

if __name__ == "__main__":
    main()
