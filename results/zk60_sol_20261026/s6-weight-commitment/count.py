"""S6 public-weight PCS design counts; no proof implementation or speed claim."""
from collections import defaultdict
import csv
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
R13 = ROOT / "results/zk60_1b_native_20261017/r13"
NATIVE = R13 / "frozen-tree"
LAYERS = 26
Q = 256
RATE = 4


def matrix_pieces(split):
    d = [2048, 1024] if split else [4096]
    f = [8192, 1024] if split else [16384]
    q, kv = [4096], [1024]
    axes = {"Q": (q, d), "K": (kv, d), "V": (kv, d), "O": (d, q),
            "gate": (f, d), "up": (f, d), "down": (d, f)}
    return [{"site": site, "output_piece": oi, "input_piece": ii,
             "output_width": out, "input_width": inner, "words": out * inner}
            for site, (outs, ins) in axes.items()
            for oi, out in enumerate(outs) for ii, inner in enumerate(ins)]


def roots(pieces, packing):
    if packing == "joint":
        return [pieces]
    groups = defaultdict(list)
    for i, p in enumerate(pieces):
        groups[p["site"] if packing == "per_tensor" else str(i)].append(p)
    return list(groups.values())


def count(split, packing, log_n):
    n = 1 << log_n
    nn = RATE * n
    h = nn.bit_length() - 1
    pieces = matrix_pieces(split)
    rs = roots(pieces, packing)
    details = []
    for ps in rs:
        words = sum(p["words"] for p in ps)
        assert all(p["words"] % n == 0 for p in ps)
        rows = words // n
        # Generic distinct column-weight groups, one per physical matrix term.
        # Public-challenge coincidences can reduce this count; it is an upper bound.
        groups = len(ps)
        vectors = groups + 1  # the extra vector is proximity, even for public PCS
        vector_bytes = vectors * n * 16
        column_bytes = Q * (8 + rows * 8 + h * 32)
        # Exactly the flat public Opening::size_bytes field/index/path formula.
        opening_bytes = vector_bytes + column_bytes
        # verify() checks EVERY clear vector against EVERY sampled column.
        mixed_macs = Q * rows * vectors
        # Two base-field encodings (real/imaginary) per vector: inverse n,
        # forward RATE*n. Each radix2 NTT has length*log2(length)/2 butterflies.
        butterflies = vectors * (n * log_n + nn * h)
        details.append({"sites": sorted({p["site"] for p in ps}), "pieces": len(ps),
                        "rows": rows, "groups_bound": groups, "vectors": vectors,
                        "opening_bytes": opening_bytes, "clear_vector_bytes": vector_bytes,
                        "sampled_column_and_path_bytes": column_bytes,
                        "verifier_fp2_base_macs": mixed_macs,
                        "verifier_base_ntt_butterflies": butterflies,
                        "merkle_path_hashes": Q * h,
                        "encoded_matrix_bytes": words * RATE * 8,
                        "base_field_matrix_bytes": words * 8,
                        "merkle_tree_bytes": (2 * nn - 1) * 32})
    total = lambda key: sum(r[key] for r in details)
    words = sum(p["words"] for p in pieces)
    added = total("opening_bytes") + 16 * len(pieces)
    return {
        "geometry": "true_piece_axes_REQUIRES_S4" if split else "current_R13_padded_axes",
        "packing": packing, "log_cols": log_n, "n": n, "inv_rate": RATE, "column_checks": Q,
        "layers": LAYERS, "roots_per_layer": len(rs), "matrix_terminals_per_layer": len(pieces),
        "weight_words_per_layer": words, "added_bytes_per_layer_bound": added,
        "added_mib_per_layer_bound": added / 2**20,
        "added_mib_whole_26_layer_bound": added * LAYERS / 2**20,
        "verifier_fp2_base_macs_per_layer": total("verifier_fp2_base_macs"),
        "verifier_base_ntt_butterflies_per_layer": total("verifier_base_ntt_butterflies"),
        "verifier_merkle_path_hashes_per_layer": total("merkle_path_hashes"),
        "base_field_matrix_gib_per_layer": words * 8 / 2**30,
        "encoded_matrix_gib_per_layer": words * RATE * 8 / 2**30,
        "encoded_matrix_gib_whole_model": words * RATE * 8 * LAYERS / 2**30,
        "merkle_tree_mib_whole_model": total("merkle_tree_bytes") * LAYERS / 2**20,
        "largest_single_root_base_plus_encoded_gib": max((r["encoded_matrix_bytes"]+r["base_field_matrix_bytes"])/2**30 for r in details),
        "root_details": details,
        "scope": "COUNTED new public PCS opening upper bound, excluding wire framing/metadata; no native profile or measured timing/RSS",
    }


def main():
    census = json.loads((R13 / "NATIVE_LAYOUT_CENSUS.json").read_text())
    anchor = next(r for r in census["rows"] if "shieldstral" in r["profile"])
    padded = sum(p["words"] for p in matrix_pieces(False))
    true = sum(p["words"] for p in matrix_pieces(True))
    assert anchor["width"] == 3072 and anchor["hidden"] == 9216 and anchor["query_width"] == 4096
    assert padded + 2 * 4096 == anchor["padded_public_weight_bytes"]
    assert (padded, true) == (243269632, 116391936)
    assert len(matrix_pieces(False)) == 7 and len(matrix_pieces(True)) == 20
    rows = [count(split, packing, log_n) for split in [False, True]
            for packing in (["per_tensor", "joint"] if not split else ["per_piece", "per_tensor", "joint"])
            for log_n in range(12, 18)]
    report = {
        "status": "S6 design/count only; public PCS of verifier-derived weighted matrices",
        "anchor": "R13 bb9eb2123c9350c738dafd19fe3b0133d6e2e7ab93f1e765cac4f20ccaed69ec",
        "native_padded_public_weight_bytes_reproduced": padded + 8192,
        "int8_true_matrix_gib_whole_model": true * LAYERS / 2**30,
        "padded_matrices": matrix_pieces(False), "true_piece_matrices": matrix_pieces(True),
        "rows": rows,
        "exclusions": ["No speedup or zkVM cycle conversion from unlike primitive operation counts",
                       "Opening fields only; new profile/wire framing, model registration and domain metadata are additional",
                       "No claim that public PCS roots alone remove current checkpoint authentication, tied-table derivation, full-weight hashing or model validation",
                       "Verifier-side weight arrays must be removed through a separately reviewed registered-model context for verification to avoid O(parameters)",
                       "All true-piece rows depend on unimplemented S4; current padded rows are a new S6 design, not existing receipts"],
    }
    (HERE / "COUNT.json").write_text(json.dumps(report, indent=2) + "\n")
    with (HERE / "COUNT.csv").open("w") as f:
        keys = [k for k in rows[0] if k not in ["root_details", "scope"]]
        writer = csv.DictWriter(f, keys, extrasaction="ignore"); writer.writeheader(); writer.writerows(rows)
    source_files = ["hashline/src/private_block/argument.rs", "hashline/src/private_block/accuracy_fold.rs",
                    "hashline/src/private_block/shape.rs", "hashline/src/private_block/run.rs",
                    "hashline/src/private_block.rs", "hashline/src/wcache.rs", "zkp-core/src/pcs.rs",
                    "zkp-core/src/mle.rs", "zkp-core/src/ntt.rs"]
    pins = {p: hashlib.sha256((NATIVE / p).read_bytes()).hexdigest() for p in source_files}
    (HERE / "NATIVE_SOURCE_PINS.json").write_text(json.dumps(pins, indent=2) + "\n")
    print(json.dumps({"variants": len(rows), "padded_weight_words": padded, "true_weight_words": true,
                      "rows": [{k:r[k] for k in ["geometry", "packing", "log_cols", "added_mib_per_layer_bound",
                                 "added_mib_whole_26_layer_bound", "verifier_fp2_base_macs_per_layer",
                                 "verifier_base_ntt_butterflies_per_layer", "encoded_matrix_gib_whole_model"]}
                               for r in rows if r["log_cols"] in [14,16]]}))


if __name__ == "__main__":
    main()
