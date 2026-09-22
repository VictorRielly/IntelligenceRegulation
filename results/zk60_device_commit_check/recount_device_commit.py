#!/usr/bin/env python3
"""Independent recount of sections 2 and 3 of
`docs/zkmatrix-poc/ZK60_HIDING_COMMITMENT_ON_DEVICE_DESIGN.md`.

Adversarial check: every figure below is derived from the shape parameters
and the code's constants by THIS file, and then compared with the memo's
stated figure. Nothing is read from the memo's own `count_hiding_commit.py`
or `counts.json` except for the final cross-check block, which is labelled.

Sources of the constants (read, not assumed):
  wire format          zkp-core/src/pcs.rs:619-638 (OpeningZk::write_bytes)
  column bytes         zkp-core/src/pcs.rs:157-175, field.rs:88 (u64 LE)
  salted leaf / tree   zkp-core/src/pcs.rs:677-696, merkle.rs:34-65
  rng draws            zkp-core/src/rng.rs:73-77 (fp = 2 x u64), :93-99 (bytes32)
  mask commitment      hashline/src/zk.rs:430-467, private_block/wire.rs:17-19
  device buffers       hashline/src/gpu/cuda.rs:3602-3748 (resident arm),
                       :1813-1857 (chunked arm), :437-509 (the pool),
                       :2115-2128 (chunk_plan), :2105-2113 (chunk rows)
  BLAKE3 costs         one compression per 64-byte block, plus one per
                       parent node of the chunk tree (chunks - 1)

Shapes come from the lane's own layout models
(`results/zk60_block125m_lane/model_{m125,rung_w14,toy}.json` in
/home/victor/wt-zk60-block125m), which also carry the asserted receipt
totals this script must reproduce.
"""

import json
import os

LANE = "/home/victor/wt-zk60-block125m/results/zk60_block125m_lane"

BLOCK = 64
CHUNK = 1024


def compressions(nbytes):
    """BLAKE3 compressions for one input: one per 64-byte block, plus one
    per parent node of the chunk tree."""
    blocks = max(1, -(-nbytes // BLOCK))
    chunks = max(1, -(-nbytes // CHUNK))
    return blocks + (chunks - 1)


def commitment(name, rows, log_n, inv_rate, q, groups, num_col_checks=256):
    n = 1 << log_n
    nn = n * inv_rate
    depth = nn.bit_length() - 1
    assert 1 << depth == nn
    col_bytes = rows * 8
    d = {
        "name": name, "rows": rows, "n": n, "nn": nn, "q": q, "depth": depth,
        "groups": groups,
        # what the prover holds
        "data_bytes": rows * n * 8,
        "pad_bytes": rows * q * 8,
        "encoded_bytes": rows * nn * 8,
        "coset_pow_bytes": nn * 8,
        "salt_bytes": nn * 32,
        "tree_bytes": (2 * nn - 1) * 32,
        "inner_nodes": nn - 1,
        # what it hashes
        "column_hash_input_bytes": rows * nn * 8,
        "column_hash_compressions": compressions(col_bytes) * nn,
        "leaf_hash_input_bytes": nn * 64,
        "leaf_hash_compressions": nn * 1,          # 64 B = one block, one chunk
        "node_hash_compressions": (nn - 1) * 1,
        # what it draws: rows*q fp() at 16 stream bytes, then nn bytes32() at 32
        "rng_pad_bytes": rows * q * 16,
        "rng_salt_bytes": nn * 32,
        # what it sends (OpeningZk::write_bytes)
        "sent_vector_bytes": (groups + 1) * (n + q) * 16,
        "sent_column_bytes": num_col_checks * (8 + rows * 8 + 32 + depth * 32),
    }
    d["rng_bytes"] = d["rng_pad_bytes"] + d["rng_salt_bytes"]
    d["opening_bytes"] = d["sent_vector_bytes"] + d["sent_column_bytes"]
    d["total_compressions"] = (d["column_hash_compressions"] + d["leaf_hash_compressions"]
                               + d["node_hash_compressions"])
    return d


def mask_commitment():
    """hashline/src/zk.rs:430-467 with private_block/wire.rs:17-19:
    MASK_VEC 1024 clear entries, MASK_DOM 4096 encoded columns, MASK_PATH 12.
    The block's M is 50 rows (the models' `m_rows`), fixed at every shape."""
    rows, dom, vec, depth, opened = 50, 4096, 1024, 12, 256
    d = {
        "name": "M (mask)", "rows": rows, "nn": dom, "depth": depth,
        "encoded_bytes": rows * dom * 8,
        "salt_bytes": dom * 32,
        "column_hash_input_bytes": rows * dom * 8,
        "column_hash_compressions": compressions(rows * 8) * dom,
        "leaf_hash_compressions": dom,
        "node_hash_compressions": dom - 1,
        # MaskOpening: q and prox, each MASK_VEC Fp2, then the opened columns
        "sent_vector_bytes": 2 * vec * 16,
        "sent_column_bytes": opened * (8 + rows * 8 + 32 + depth * 32),
    }
    d["opening_bytes"] = d["sent_vector_bytes"] + d["sent_column_bytes"]
    d["total_compressions"] = (d["column_hash_compressions"] + d["leaf_hash_compressions"]
                               + d["node_hash_compressions"])
    return d


# ---------------------------------------------------------------------------
# device residency (hashline/src/gpu/cuda.rs)
# ---------------------------------------------------------------------------
CHUNK_ROWS = 128           # cuda.rs:2105-2113, floor 128
CHUNK_BYTES = 1 << 30      # cuda.rs:2062-2065, HL_GPU_CHUNK_BYTES default
B3_STATE_SLOTS = 8 * 24 + 1  # cuda.rs:2130
TWIDDLES = 2 * ((1 << 16) - 1) * 8  # ensure_twiddles: two stage-major tables


def residency(c):
    """Device bytes for one hiding commitment, both arms.

    resident arm (cuda.rs:3656-3747): d_data(rows*n) + d_pads(rows*q) +
    d_pows(nn) + d_coef(rows*n) + d_coef2(rows*nn) + d_enc(rows*nn) +
    leaves(nn*32) + twiddles.

    NOTE the term the memo omits: `drop(d_coef)` at cuda.rs:3699 returns the
    buffer to the process-global POOL free list (pool_put, :451-456) and does
    NOT call cuMemFree; `Pooled::take(rows*nn)` for d_enc matches by EXACT
    length (pool_take, :437-448) and cannot reuse a rows*n buffer. So d_coef
    is still resident on the device when d_enc is live.
    """
    rows, n, nn, q = c["rows"], c["n"], c["nn"], c["q"]
    d_data = rows * n * 8
    d_pads = rows * q * 8
    d_pows = nn * 8
    d_coef = rows * n * 8
    d_coef2 = rows * nn * 8
    d_enc = rows * nn * 8
    leaves = nn * 32
    source_formula = (rows * (n + q + 2 * nn) + nn) * 8   # cuda.rs:3618-3621
    memo_peak = source_formula + leaves + TWIDDLES
    true_peak = d_data + d_pads + d_pows + d_coef + d_coef2 + d_enc + leaves + TWIDDLES

    rmax = min(rows, CHUNK_ROWS) if rows > CHUNK_ROWS else rows
    scratch = rmax * n * 8 + rmax * nn * 8 + rmax * nn * 8   # d_coef, d_coef2(pw=nn), d_enc
    state = ((B3_STATE_SLOTS * nn + 1) // 2) * 8
    persistent = d_data + d_pads + d_pows
    chunked_peak = persistent + scratch + state + leaves + TWIDDLES
    return {
        "chunks_by_default": (rows * nn * 8) > CHUNK_BYTES,
        "rows_nn_8": rows * nn * 8,
        "resident_peak_source_formula": source_formula,
        "resident_peak_memo": memo_peak,
        "resident_peak_with_pooled_d_coef": true_peak,
        "pooled_d_coef_omitted_by_memo": true_peak - memo_peak,
        "chunked_peak": chunked_peak,
        "chunked_fixed_overhead": scratch + state + leaves + TWIDDLES,
        "survives_to_opening": persistent,
    }


def gib(x):
    return x / (1 << 30)


def main():
    models = {}
    for tag, f in (("125M", "model_m125.json"), ("rung-W14", "model_rung_w14.json"),
                   ("toy", "model_toy.json")):
        with open(os.path.join(LANE, f)) as fh:
            models[tag] = json.load(fh)

    out = {}
    for tag, m in models.items():
        sh, rw, rb = m["shape"], m["rows"], m["receipt_bytes"]
        log_n, inv_rate = sh["log_cols"], sh["inv_rate"]
        q = sh["opened_columns_Q"]          # ZkOpts::standard: q_pad = num_col_checks
        cs = [
            commitment("A", rw["a_rows"], log_n, inv_rate, q, m["opening_groups"]["a_groups"], q),
            commitment("H", rw["h_rows"], log_n, inv_rate, q, m["opening_groups"]["h_groups"], q),
            commitment("endpoint-in", sh["endpoint_rows"], sh["endpoint_log_n"],
                       sh["endpoint_inv_rate"], q, 1, q),
            commitment("endpoint-out", sh["endpoint_rows"], sh["endpoint_log_n"],
                       sh["endpoint_inv_rate"], q, 1, q),
        ]
        mk = mask_commitment()

        counted = {
            "a_opening": cs[0]["opening_bytes"],
            "h_opening": cs[1]["opening_bytes"],
            "endpoint_openings": cs[2]["opening_bytes"] + cs[3]["opening_bytes"],
            "mask_opening": mk["opening_bytes"],
            "header_and_three_roots": rb["header_and_three_roots"],
            "slots": rb["slots"],
        }
        counted["total"] = sum(counted.values())
        agree = all(counted[k] == rb[k] for k in counted)

        four = sum(c["encoded_bytes"] for c in cs)
        cols4 = sum(c["column_hash_compressions"] for c in cs)
        leaves4 = sum(c["leaf_hash_compressions"] for c in cs)
        nodes4 = sum(c["node_hash_compressions"] for c in cs)

        res = {c["name"]: residency(c) for c in cs}
        # What each arm RETAINS past its own return (cuda.rs:3690-3691 vs :3747):
        #   chunked  -> DevCommit{data, enc:None, zk:Some(ZkReenc{pads,pows})}
        #               = d_data + d_pads + d_pows
        #   resident -> DevCommit{data, enc:Some(d_enc), zk:None}
        #               = d_data + d_enc; the raw d_pads/d_pows DROP (real free)
        for c in cs:
            r = res[c["name"]]
            r["retained_after_return"] = (r["survives_to_opening"] if r["chunks_by_default"]
                                          else c["data_bytes"] + c["encoded_bytes"])
            # what the POOL keeps alive but no longer owns (never cuMemFree'd)
            r["pool_residue_after_return"] = (0 if r["chunks_by_default"]
                                              else c["data_bytes"] + c["encoded_bytes"])

        phase_peak, held, pool = 0, 0, 0
        for c in cs:
            r = res[c["name"]]
            peak = r["chunked_peak"] if r["chunks_by_default"] else r["resident_peak_memo"]
            phase_peak = max(phase_peak, held + peak)
            held += r["retained_after_return"]
        # all-resident counterfactual, the memo's model (pool ignored)
        cum_peak, cum_held = 0, 0
        for c in cs:
            r = res[c["name"]]
            cum_peak = max(cum_peak, cum_held + r["resident_peak_memo"])
            cum_held += c["data_bytes"] + c["encoded_bytes"]
        # the same counterfactual with the pool's exact-length free list, undrained
        pcum_peak, pcum_held = 0, 0
        for c in cs:
            r = res[c["name"]]
            pcum_peak = max(pcum_peak, pcum_held + r["resident_peak_with_pooled_d_coef"])
            # live d_data + d_enc, plus d_coef and d_coef2 stranded in the pool
            pcum_held += (c["data_bytes"] + c["encoded_bytes"]
                          + c["data_bytes"] + c["encoded_bytes"])

        out[tag] = {
            "commitments": cs, "mask": mk, "counted_receipt": counted,
            "model_receipt": rb, "receipt_agrees": agree,
            "four_encoded_bytes": four,
            "five_encoded_bytes": four + mk["encoded_bytes"],
            "column_compressions_four": cols4,
            "leaf_compressions_four": leaves4,
            "node_compressions_four": nodes4,
            "total_compressions_four": cols4 + leaves4 + nodes4,
            "total_compressions_five": cols4 + leaves4 + nodes4 + mk["total_compressions"],
            "rng_bytes_four": sum(c["rng_bytes"] for c in cs),
            "residency": res,
            "commit_phase_peak_default": phase_peak,
            "commit_phase_held_default": held,
            "all_resident_cum_peak": cum_peak,
            "all_resident_cum_held": cum_held,
            "all_resident_cum_peak_with_pool": pcum_peak,
            "all_resident_cum_held_with_pool": pcum_held,
        }

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "recount.json"), "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)

    # ---- the printed comparison ------------------------------------------
    memo = {
        "125M": {"total": 40783352, "four_encoded": 6750208000, "col_compr": 112197120,
                 "all_compr": 112721404, "rng": 61124608,
                 "phase_peak": 1909852144, "phase_held": 1753614336,
                 "cum_peak": 12140445680, "cum_held": 8460904432},
        "rung-W14": {"total": 16421048, "four_encoded": 514326528, "col_compr": None,
                     "all_compr": 9175036, "rng": 12406784},
        "toy": {"total": 2816472},
    }
    print("=" * 78)
    print("RECEIPT RECONCILIATION (mine, from the wire format and the shapes)")
    print("=" * 78)
    for tag in ("125M", "rung-W14", "toy"):
        o = out[tag]
        print("%-9s counted %12d   model %12d   %s" % (
            tag, o["counted_receipt"]["total"], o["model_receipt"]["total"],
            "AGREE" if o["receipt_agrees"] else "DISAGREE"))
        for k in ("a_opening", "h_opening", "endpoint_openings", "mask_opening"):
            print("            %-20s %12d  vs %12d %s" % (
                k, o["counted_receipt"][k], o["model_receipt"][k],
                "" if o["counted_receipt"][k] == o["model_receipt"][k] else "  <-- DIFFERS"))
    print()
    print("=" * 78)
    print("COMPRESSIONS  (memo section 2.2)")
    print("=" * 78)
    for tag in ("125M", "rung-W14", "toy"):
        o = out[tag]
        mm = memo.get(tag, {})
        print("%-9s column digests (four) %12d   memo %s" % (
            tag, o["column_compressions_four"], mm.get("col_compr", "-")))
        print("          leaves %9d  nodes %9d  total(four) %12d   memo %s" % (
            o["leaf_compressions_four"], o["node_compressions_four"],
            o["total_compressions_four"], mm.get("all_compr", "-")))
        print("          total including the MASK commitment: %12d" % o["total_compressions_five"])
        t = o["total_compressions_four"]
        print("          tree share %.4f%%  leaf share %.4f%%" % (
            100.0 * o["node_compressions_four"] / t, 100.0 * o["leaf_compressions_four"] / t))
    print()
    print("=" * 78)
    print("DEVICE RESIDENCY  (memo section 3)")
    print("=" * 78)
    for tag in ("125M", "rung-W14"):
        o = out[tag]
        print("--", tag)
        for name, r in o["residency"].items():
            print("  %-12s rows*nn*8 %13d  %s" % (
                name, r["rows_nn_8"], "CHUNKS" if r["chunks_by_default"] else "resident"))
            print("      resident peak: memo %13d (%.2f GiB) | with pooled d_coef %13d (%.2f GiB)  [+%d]" % (
                r["resident_peak_memo"], gib(r["resident_peak_memo"]),
                r["resident_peak_with_pooled_d_coef"], gib(r["resident_peak_with_pooled_d_coef"]),
                r["pooled_d_coef_omitted_by_memo"]))
            print("      chunked peak  %13d (%.2f GiB)   survives to opening %13d" % (
                r["chunked_peak"], gib(r["chunked_peak"]), r["survives_to_opening"]))
        mm = memo.get(tag, {})
        print("  commit-phase peak (default arms) %13d (%.2f GiB)   memo %s" % (
            o["commit_phase_peak_default"], gib(o["commit_phase_peak_default"]),
            mm.get("phase_peak", "-")))
        print("  held to the openings             %13d (%.2f GiB)   memo %s" % (
            o["commit_phase_held_default"], gib(o["commit_phase_held_default"]),
            mm.get("phase_held", "-")))
        print("  all-resident cumulative peak     %13d (%.2f GiB)   memo %s" % (
            o["all_resident_cum_peak"], gib(o["all_resident_cum_peak"]), mm.get("cum_peak", "-")))
        print("  all-resident held                %13d (%.2f GiB)   memo %s" % (
            o["all_resident_cum_held"], gib(o["all_resident_cum_held"]), mm.get("cum_held", "-")))
        print("  all-resident peak, pool UNDRAINED%13d (%.2f GiB)   [the pool never cuMemFrees]" % (
            o["all_resident_cum_peak_with_pool"], gib(o["all_resident_cum_peak_with_pool"])))
    print()
    o = out["125M"]
    print("four encoded bytes  %13d (%.2f GiB)  memo %d" % (
        o["four_encoded_bytes"], gib(o["four_encoded_bytes"]), memo["125M"]["four_encoded"]))
    print("five encoded bytes  %13d (%.2f GiB)  (the memo's four + the mask)" % (
        o["five_encoded_bytes"], gib(o["five_encoded_bytes"])))
    print("rng bytes (four)    %13d              memo %d" % (
        o["rng_bytes_four"], memo["125M"]["rng"]))
    print("A+H share of the five commitments' encoded bytes: %.2f%%" % (
        100.0 * (o["commitments"][0]["encoded_bytes"] + o["commitments"][1]["encoded_bytes"])
        / o["five_encoded_bytes"]))
    print()
    print("opened columns seen by the verifier, as a fraction of the kernel's output:")
    for tag in ("125M", "rung-W14", "toy"):
        nn = out[tag]["commitments"][0]["nn"]
        print("  %-9s 256 of %6d columns = %.3f%%   (sampled WITH replacement:"
              " ~%.1f distinct)" % (tag, nn, 100.0 * 256 / nn,
                                    nn * (1 - (1 - 1.0 / nn) ** 256)))


if __name__ == "__main__":
    main()
