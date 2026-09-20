#!/usr/bin/env python3
"""Exact-arithmetic counts for the hash layer of ONE toy private-block proof
(profile hashline-zk-mr1/private-block-t32-poc/1), and the residual terms of
the Fiat-Shamir lift.

NOTHING here reads a capture, a witness, a salt or a private plane.  Every
number is derived from the geometry constants read off the source:

    A   455 rows, n = 256, nn = 2048, depth 11   (private_block/protocol.rs:21-23,
                                                  layout.rs:519-526)
    H   384 rows, n = 256, nn = 2048, depth 11
    In  7   rows, n = 256, nn = 2048, depth 11   (private_seam.rs:106-111)
    Out 7   rows, n = 256, nn = 2048, depth 11
    M   50  rows, m = 512, nn = 4096, depth 12   (hashline/src/zk.rs:373-375)
    256 opened columns per commitment, drawn WITH REPLACEMENT
        (zkp-core/src/transcript.rs:118-131)

Run:  python3 results/zk60_hash_layer_fs_lift/hash_layer_counts.py
Writes hash_layer_counts.json beside itself.
"""

import json
import math
import os

Q_OPEN = 256          # num_col_checks
SALT_BITS = 256       # ZkRng::bytes32
DIGEST_BITS = 256     # blake3 32-byte output

# (name, rows, nn)   nn = encoded columns = leaves of that commitment's tree
TREES = [
    ("A", 455, 2048),
    ("H", 384, 2048),
    ("In", 7, 2048),
    ("Out", 7, 2048),
    ("M", 50, 4096),
]


def ancestors(nn, level, draws=Q_OPEN):
    """Expected number of DISTINCT level-`level` ancestors of `draws` uniform
    leaf draws with replacement.  A_j = (nn/2^j)(1 - (1 - 2^j/nn)^draws)."""
    blocks = nn / (2 ** level)
    return blocks * (1.0 - (1.0 - 1.0 / blocks) ** draws)


def tree_counts(nn):
    depth = int(math.log2(nn))
    a = [ancestors(nn, j) for j in range(depth + 1)]
    opened_distinct = a[0]
    leaf_digests_revealed = 2 * a[1]
    unopened_leaf_digests = leaf_digests_revealed - opened_distinct
    internal_revealed = sum(2 * a[j + 1] for j in range(1, depth))
    total_revealed = leaf_digests_revealed + internal_revealed + 1
    return {
        "nn": nn,
        "depth": depth,
        "distinct_opened_leaves": opened_distinct,
        "leaf_digests_revealed": leaf_digests_revealed,
        "unopened_leaf_digests_revealed": unopened_leaf_digests,
        "internal_nodes_revealed": internal_revealed,
        "total_nodes_revealed": total_revealed,
        "nodes_in_tree": 2 * nn - 1,
        "fraction_of_tree_revealed": total_revealed / (2 * nn - 1),
        "unopened_leaves_total": nn - opened_distinct,
        "top_pair_missing_prob_log2": -(Q_OPEN - 1),   # 2 - A_{depth-1} = 2^-255
    }


def lg(x):
    return math.log2(x) if x > 0 else float("-inf")


def main():
    out = {"per_tree": {}, "totals": {}, "oracle_query_classes": {}, "residuals": {}}

    tot_leaves = 0
    tot_unopened = 0
    tot_nodes = 0
    tot_revealed = 0
    tot_published_salts_distinct = 0
    for name, rows, nn in TREES:
        c = tree_counts(nn)
        c["rows"] = rows
        c["hash_column_input_bytes"] = 8 * rows
        c["salts_drawn"] = nn
        c["salts_published_distinct"] = c["distinct_opened_leaves"]
        c["salts_published_slots"] = Q_OPEN           # duplicates emitted
        c["path_digest_slots_emitted"] = Q_OPEN * c["depth"]
        out["per_tree"][name] = c
        tot_leaves += nn
        tot_unopened += c["unopened_leaves_total"]
        tot_nodes += nn - 1
        tot_revealed += c["total_nodes_revealed"]
        tot_published_salts_distinct += c["distinct_opened_leaves"]

    # prover's own oracle queries, class by class, for one proof
    column_hashes = tot_leaves                    # hash_column per encoded column
    salted_leaves = tot_leaves                    # salt_leaf per encoded column
    node_hashes = tot_nodes                       # hash_pair per internal node
    # ZkRng refills: 327,052 fp() draws x 16 B + 12,288 salts x 32 B, 8192 B per refill
    fp_draws = 327052
    rng_bytes = fp_draws * 16 + tot_leaves * 32
    refills = math.ceil(rng_bytes / 8192)
    transcript_queries_bound = 4000               # BOUND, not a count (see the memo)
    prover_queries = (column_hashes + salted_leaves + node_hashes
                      + refills + transcript_queries_bound)

    out["totals"] = {
        "encoded_columns_all_trees": tot_leaves,
        "unopened_leaves_all_trees": tot_unopened,
        "internal_nodes_all_trees": tot_nodes,
        "nodes_revealed_all_trees": tot_revealed,
        "distinct_published_salts": tot_published_salts_distinct,
        "roots_published": 5,
        "fp_draws_per_proof": fp_draws,
        "rng_bytes_per_proof": rng_bytes,
        "rng_refills_per_proof": refills,
        "prover_oracle_queries_bound": prover_queries,
        "prover_oracle_queries_bound_log2": lg(prover_queries),
    }

    out["oracle_query_classes"] = {
        "Transcript::squeeze_bytes (every challenge)": 47,
        "ZkRng::refill (key || counter)": 40,
        "Transcript::absorb": ">= 49 (48 + |label| + |data|)",
        "merkle::hash_pair": 64,
        "pcs::salt_leaf": 64,
        "hash_column A": 8 * 455,
        "hash_column H": 8 * 384,
        "hash_column M": 8 * 50,
        "hash_column endpoint": 8 * 7,
        "Transcript::new (domain seed)": "12 + |domain|",
        "the ONE 64-byte absorb: absorb_u64(b'log-cols', 8)": 64,
    }

    # ---- residual terms, as log2 ----
    # (R1) salt guessing by a q-query adversary, over all unopened leaves
    #      conservative: all nn leaves of every tree
    r1_coeff = tot_leaves
    # (R2) two salted-leaf oracle INPUTS coinciding (needs equal salts)
    pairs = tot_leaves * (tot_leaves - 1) / 2
    r2 = lg(pairs) - SALT_BITS
    # (R3) the 64-byte absorb overlapping a node or salted-leaf input
    overlap_objects = tot_nodes + tot_leaves
    r3 = lg(overlap_objects) - DIGEST_BITS
    # (R4) generator key guessing, 3 OS streams, in the ROM
    r4_coeff = 3
    # (R5) absorb-input collisions among <= transcript_queries_bound absorbs
    ab_pairs = transcript_queries_bound * (transcript_queries_bound - 1) / 2
    r5 = lg(ab_pairs) - DIGEST_BITS

    out["residuals"] = {
        "sampler_fp_bias_D9_log2": -77.7,
        "logup_collision_refusal_log2": -112.0,
        "logup_collision_refusal_distinct_log2": -117.4,
        "refusal_rate_liveness_log2": -62.0,
        "salt_guess_coefficient": r1_coeff,
        "salt_guess_log2_per_query": lg(r1_coeff) - SALT_BITS,
        "leaf_input_collision_log2": r2,
        "domain_overlap_64B_absorb_log2": r3,
        "generator_key_guess_coefficient": r4_coeff,
        "generator_key_guess_log2_per_query": lg(r4_coeff) - DIGEST_BITS,
        "absorb_collision_log2": r5,
    }

    # the sum at three query budgets
    sums = {}
    for qlog in (50, 80, 128):
        q = 2.0 ** qlog
        terms = [
            2 ** -77.7,
            2 ** -112.0,
            q * r1_coeff * 2.0 ** -SALT_BITS,
            2 ** r2,
            2 ** r3,
            q * r4_coeff * 2.0 ** -DIGEST_BITS,
            2 ** r5,
        ]
        sums[f"q=2^{qlog}"] = {"sum": sum(terms), "sum_log2": lg(sum(terms))}
    out["residuals"]["sum_excluding_PRG_and_refusal_liveness"] = sums

    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "hash_layer_counts.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)

    # human-readable echo
    for name, c in out["per_tree"].items():
        print(f"{name}: nn={c['nn']} depth={c['depth']} "
              f"distinct_opened={c['distinct_opened_leaves']:.1f} "
              f"leaf_digests={c['leaf_digests_revealed']:.1f} "
              f"unopened_leaf_digests={c['unopened_leaf_digests_revealed']:.1f} "
              f"internal={c['internal_nodes_revealed']:.1f} "
              f"total={c['total_nodes_revealed']:.1f} of {c['nodes_in_tree']} "
              f"({100*c['fraction_of_tree_revealed']:.1f}%) "
              f"hash_column_input={c['hash_column_input_bytes']} B")
    t = out["totals"]
    print(f"\nall trees: leaves={t['encoded_columns_all_trees']} "
          f"unopened={t['unopened_leaves_all_trees']:.1f} "
          f"internal nodes={t['internal_nodes_all_trees']} "
          f"revealed={t['nodes_revealed_all_trees']:.1f} "
          f"distinct published salts={t['distinct_published_salts']:.1f}")
    print(f"prover oracle queries (bound) = {t['prover_oracle_queries_bound']} "
          f"= 2^{t['prover_oracle_queries_bound_log2']:.2f} "
          f"(refills {t['rng_refills_per_proof']}, transcript bound "
          f"{transcript_queries_bound})")
    r = out["residuals"]
    print(f"\nsalt guessing:        q * {r['salt_guess_coefficient']} * 2^-256 "
          f"= q * 2^{r['salt_guess_log2_per_query']:.2f}")
    print(f"leaf input collision: 2^{r['leaf_input_collision_log2']:.2f}")
    print(f"64-B absorb overlap:  2^{r['domain_overlap_64B_absorb_log2']:.2f} "
          f"(over {overlap_objects} node+leaf inputs)")
    print(f"generator key guess:  q * 2^{r['generator_key_guess_log2_per_query']:.2f}")
    print(f"absorb collisions:    2^{r['absorb_collision_log2']:.2f} "
          f"(bound on <= {transcript_queries_bound} absorbs)")
    for k, v in sums.items():
        print(f"sum {k}: 2^{v['sum_log2']:.4f}")
    print(f"\nwrote {path}")


if __name__ == "__main__":
    main()
