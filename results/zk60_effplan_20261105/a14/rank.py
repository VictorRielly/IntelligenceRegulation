#!/usr/bin/env python3
"""A14: rank where the forks' host time goes, from a macOS `/usr/bin/sample` call graph of the D55 harness's
sampling window (A11's `sample_summary.py` parser and roles).

usage: rank.py <sample.txt> [--interval-ms 2] [--calls 3]

Every self sample of a fork's MAIN LINE (a stack holding `prove_core`) that is not a GPU wait, and every BUSY
sample of a rayon pool worker, is put in one bucket by the first rule below whose keywords match any frame of its
stack (leaf first). The main line is the critical path of a fork; the pool's busy samples are CPU spent in a fork's
parallel regions (its own pool's threads with A11's per-fork pools).
"""
import collections
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "a11"))
import sample_summary as ss  # noqa: E402

# (bucket, owner, keywords): the first bucket with a keyword in any frame wins (frames are scanned leaf first)
RULES = [
    ("randomness: ZkRng (fill_fp, next_u64, the XOF)", "rng.rs (A14)", ["ZkRng", "compress_xof"]),
    ("transcript absorb", "transcript.rs (A14)", ["Transcript::absorb", "Transcript::challenge"]),
    ("A/H zero-fill, free (vec! / bzero / vm_deallocate)", "protocol.rs (A13)", ["SpecFromElem", "__bzero", "mach_vm_deallocate", "_platform_memset"]),
    ("openings' store fold (A8)", "metal.rs fold region", ["fold_segments_a8", "fold_rows_host", "fold_rows_with_pads"]),
    ("private slots' tables (priv_table_fill / build_tables_at)", "argument.rs (A14)", ["priv_table_fill", "build_tables_at", "priv_table_at", "build_tables_into"]),
    ("device slots' table plan + public tables (A12 host part)", "argument.rs / metal.rs tables (A14)", ["build_tables_device", "plane_plan", "build_planned", "MetalTables"]),
    ("claimed sum (total_at)", "argument.rs", ["total_at", "argument::total"]),
    ("extension rounds (mask_eval_eq, eq_table_msb)", "argument.rs / mle.rs", ["mask_eval_eq", "eq_table_msb", "eq_cube"]),
    ("per-block public checks (check_for_shape, check_for_registry)", "prove_core's call (protocol.rs, A13); private_block.rs / accuracy_public.rs code", ["check_accuracy_for_shape", "weights_vanish", "check_for_shape", "check_words", "check_for_registry", "new_with_registry", "derive_aligned_for"]),
    ("public weight folds and public tables (define)", "argument.rs define; accuracy_fold.rs, mle.rs, pad.rs code", ["fold_cols_i8", "fold_rows_i8", "silu_table", "rope_tables", "closed_form_indicator", "B::supp", "group_folds_for", "accuracy_fold", "causal_mask", "argument::define", "group_column", "dzc_w16"]),
    ("lookup values + histograms", "protocol.rs (A13)", ["lookup_values_at", "w16_histograms", "byte_histogram", "exp_histogram", "accuracy_act::histogram", "exp_deltas"]),
    ("LogUp helper inverses", "protocol.rs (A13)", ["batch_inverse2", "protocol::inverses", "write_helpers", "denominators", "denominator_inverses", "write_h"]),
    ("witness planes into A (write_planes)", "protocol.rs (A13)", ["write_planes"]),
    ("commit host parts (salts, Merkle, host NTT, uploads)", "pcs.rs / metal.rs", ["salt_leaf", "MerkleTree", "coset_powers", "NttTables::transform", "metal::upload", "commit_zk", "mask_commit"]),
    ("sumcheck host rounds / host tail", "sumcheck (zkp-core)", ["sumcheck", "ClosureRounds", "GroupedEqRounds", "interpolate"]),
    ("openings other (group_zclaims, columns, check_opening)", "pcs.rs", ["open_zk", "group_zclaims", "check_opening", "mask_open"]),
]


def bucket(st):
    for name, owner, keys in RULES:
        for n in reversed(st):
            if any(k in n for k in keys):
                return name
    return "other / unattributed"


HELPER = "rayon::iter::plumbing::bridge_producer_consumer::helper"


def keep_helper_hashes():
    """A pool worker's parallel-region body is inlined into a monomorphized rayon `helper`, so its stack names no
    project frame. Keep the `helper` frames' symbol hashes (one per monomorphization) so they can be traced back
    to the project frame that called them on a fork's main line."""
    orig = ss.fn_name

    def fn_name(text):
        name = text.split("  (in ")[0].strip()
        if name.startswith(HELPER + "::h"):
            return name
        return orig(text)

    ss.fn_name = fn_name


def is_infra(n):
    return n.startswith(("rayon", "core::", "_$LT$rayon", "<rayon", "std::", "alloc::", "_$LT$core", "_$LT$alloc", "_$LT$T$u20$as$u20$alloc"))


def helper_owner_map(threads):
    """helper hash -> the nearest non-infrastructure frame above its outermost helper, on any stack that has one"""
    votes = collections.defaultdict(collections.Counter)
    for header, nodes in threads:
        for st, c in ss.self_samples(nodes):
            for i, n in enumerate(st):
                if n.startswith(HELPER + "::h"):
                    j = i - 1
                    while j >= 0 and not (st[j].startswith(ss.PROJECT) and not is_infra(st[j])):
                        j -= 1
                    if j >= 0:
                        votes[n][st[j]] += c
    return {h: v.most_common(1)[0][0] for h, v in votes.items()}


def resolve(st, owners):
    """the stack with its deepest known helper replaced by the frame that called it"""
    for n in reversed(st):
        if n in owners:
            return st + [owners[n]]
    return st


def main():
    a = sys.argv[1:]
    path = a[0]
    interval = float(a[a.index("--interval-ms") + 1]) if "--interval-ms" in a else 2.0
    calls = int(a[a.index("--calls") + 1]) if "--calls" in a else 3
    sec = interval / 1000.0
    main_b = collections.Counter()
    main_cat = collections.Counter()
    pool_b = collections.Counter()
    keep_helper_hashes()
    threads = ss.parse(path)
    owners = helper_owner_map(threads)
    for header, nodes in threads:
        samples = [(resolve(st, owners), c) for st, c in ss.self_samples(nodes)]
        rayonish = any(n.startswith("rayon_core::registry::WorkerThread") or "rayon_core::registry::main_loop" in n or "ThreadBuilder::run" in n for st, _ in samples for n in st)
        for st, c in samples:
            if ss.is_main(st):
                k = ss.classify_fork(st)
                main_cat[k] += c
                if k == "gpu-wait":
                    continue
                if k == "pool-wait":
                    # waiting on a parallel region: charge the region that joined
                    main_b[bucket(st)] += c
                    continue
                main_b[bucket(st)] += c
            elif rayonish and ss.classify_rayon(st) == "busy":
                pool_b[bucket(st)] += c
    mt = sum(main_cat.values())
    host = mt - main_cat["gpu-wait"]
    print(f"# A14 ranking: {path}")
    print(f"interval {interval} ms, {calls} proof-only fork calls in the window, N = 6")
    print(f"\nfork main lines: {mt} samples = {mt * sec:.2f} thread-s; " + ", ".join(f"{k} {100 * v / max(mt, 1):.1f}%" for k, v in main_cat.most_common()))
    print(f"main-line samples NOT waiting on the GPU: {host} = {host * sec:.2f} thread-s ({host * sec / calls / 6:.3f} s per fork per call)")
    pt = sum(pool_b.values())
    print(f"rayon busy samples: {pt} = {pt * sec:.2f} thread-s ({pt * sec / calls:.2f} CPU-s per call)\n")
    print("| bucket | owner | main line, % of its non-GPU samples | main line, s per fork per call | pool busy, CPU-s per call |")
    print("|---|---|---:|---:|---:|")
    names = [r[0] for r in RULES] + ["other / unattributed"]
    owners = {r[0]: r[1] for r in RULES}
    for name in sorted(names, key=lambda n: -main_b[n]):
        m, p = main_b[name], pool_b[name]
        if m == 0 and p == 0:
            continue
        print(f"| {name} | {owners.get(name, '-')} | {100 * m / max(host, 1):.1f}% | {m * sec / calls / 6:.3f} | {p * sec / calls:.2f} |")


if __name__ == "__main__":
    main()
