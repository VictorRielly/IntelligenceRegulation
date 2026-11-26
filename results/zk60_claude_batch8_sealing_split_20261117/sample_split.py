#!/usr/bin/env python3
"""Batch 8: split the sealing pass from a /usr/bin/sample call graph of the `serve1` test process.

Threads (identified by stacks):
  lane   = a thread whose stack holds trained_block::seal_chain (one new thread per request). Outside the pool
           it runs check_lookup_misses (CS-3), padded_plane, true_words, hand-over; inside `SealPool::run` it is
           parked in rayon `in_worker_cold` (LockLatch wait) while the build runs on a pool worker.
  worker = threads named hl-seal8-N (the SealPool). The installed build (stack holds witness_for_block) runs on one of them
           and is the build's main line (A16's `main line`); the other workers run stolen halves of its parallel regions.
Main line time of the sealing pass = lane samples outside the latch wait + samples of the in-pool main line.
Seconds: per pass, sec_per_sample = (sealing-pass wall of the sampled run, from its log) / (that lane thread's seal_chain samples).

usage: sample_split.py <label>   (reads <label>.log, <label>.meta.json, the sample file named there) -> <label>.split.json + .split.txt
"""
import collections, json, re, sys
from pathlib import Path
sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT))
import sampleparse as sp

SLEEP = ("__psynch_cvwait", "__ulock_wait", "__psynch_mutexwait", "semaphore_wait", "__semwait", "mach_msg", "kevent", "__select", "nanosleep", "usleep", "__workq_kernreturn", "_dispatch_sema4_wait")
SPIN = ("swtch_pri", "thread_switch", "sched_yield", "__sched_yield")
ALLOC = ("zeros", "__bzero", "_platform_bzero", "_platform_memset", "calloc", "_xzm_malloc_large_huge", "xzm_segment_group_alloc_chunk", "_xzm_malloc_zone_malloc_type_calloc_entry", "from_elem", "xzm_malloc", "malloc_zone_calloc")
LAST = lambda n: n.split("::")[-1]
END = lambda names, suf: [i for i, n in enumerate(names) if n.endswith(suf)]


def leaf_kind(st):
    leaf = st[-1][0]
    names = [n for n, o in st]
    if any("wait_done" in n or "waitUntilCompleted" in n for n in names):
        return "device_wait"
    if leaf.startswith(SLEEP):
        return "sleep"
    if leaf.startswith(SPIN):
        return "spin"
    return "work"


def classify_pool_main(st):
    names = [n for n, o in st]
    i0 = END(names, "trained_block::witness_for_block")[0]
    sub = names[i0 + 1:]
    has = lambda s: any(n.endswith(s) for n in sub)
    if has("accuracy::assign_with"):
        return "a_assign_alloc_zero" if any(LAST(n) in ALLOC or n.startswith(ALLOC) for n in sub[sub.index(next(n for n in sub if n.endswith("accuracy::assign_with"))):]) else "a_assign_limb_loops"
    if has("BlockPublic::check_accuracy_for_shape"):
        return "b_check_accuracy_weight_scan"
    bw = [i for i, n in enumerate(st) if n[0].endswith("accuracy::build_with")]
    if bw:
        i = bw[0]
        off = st[i][1]
        callee = LAST(st[i + 1][0]) if i + 1 < len(st) else "(self)"
        rest = [n for n, o in st[i + 1:]]
        wait = any("wait_done" in n or "waitUntilCompleted" in n for n in rest)
        if callee == "normalized_par":
            return "b_norm_a" if off == 3680 else "c_norm_m"
        if callee == "zeros" and off == 3224:
            return "b_x_plane_zero"
        if off == 4988:  # the Q/K/V join closure
            if callee == "matmul":
                return "d_device_wait" if wait else "b_qkv_product_prelude"
            if callee in ("wait_until_cold",):
                return "d_pool_wait_join"
            return "c_qkv_requant_rotate"
        if callee in ("matmul", "matmul_in_out") or (callee == "_$u7b$$u7b$closure$u7d$$u7d$" and any(LAST(n) in ("matmul_in_out", "matmul") for n in rest[:2])):
            return "d_device_wait" if wait else "c_other_product_prelude"
        if callee == "wait_until_cold" or (callee.startswith("_$u7b$") and any(LAST(n) == "wait_until_cold" for n in rest[:2])):
            return "d_pool_wait_join"
        return "c_middle_other"
    return "x_other_in_pool"


def classify_lane(st):
    names = [n for n, o in st]
    i0 = END(names, "trained_block::seal_chain")[-1]
    sub = names[i0 + 1:]
    if any(n.endswith("in_worker_cold") for n in sub) and not any(n.endswith("check_lookup_misses") for n in sub):
        return "lane_wait_pool_build"
    if any(n.endswith("check_lookup_misses") for n in sub):
        j = [n for n in sub]
        if any(n.endswith("BlockPublic::check_accuracy_for_shape") for n in j):
            return "a_cs3_check_accuracy_weight_scan"
        for key, lab in (("w16_histograms_cols", "a_cs3_w16_histograms_cols"), ("looked_built", "a_cs3_looked_built"), ("accuracy_act::histogram", "a_cs3_histogram"), ("exp_deltas", "a_cs3_exp"), ("exp_histogram", "a_cs3_exp"), ("Layout::for_shape", "a_cs3_layout_for_shape")):
            if any(n.endswith(key) for n in j):
                return lab
        return "a_cs3_other"
    if any(n.endswith("padded_plane") for n in sub):
        return "a_padded_plane"
    if any(n.endswith("true_words") for n in sub):
        return "a_true_words"
    if any("FlatMap" in n for n in sub):
        return "a_true_words_or_padded_inlined"
    return "x_lane_other"


def split(label):
    meta = json.loads((OUT / f"{label}.meta.json").read_text())
    smp = meta["sample"]["path"]
    log = (OUT / f"{label}.log").read_text()
    walls = {int(m.group(1)): float(m.group(2)) for m in re.finditer(r"\[serve1\] pass (\d+) request 0: .*?\(sealing pass ([0-9.]+) s\)", log)}
    reqs = {int(m.group(1)): float(m.group(2)) for m in re.finditer(r"\[serve1\] pass (\d+): 1 requests in ([0-9.]+) s", log)}
    th = sp.parse(smp)
    lanes = []
    for h, tot, ss in th:
        lc = sum(c for st, c in ss if any(n.endswith("trained_block::seal_chain") for n, o in st))
        if lc:
            tid = int(re.search(r"Thread_(\d+)", h).group(1))
            lanes.append((tid, tot, lc, ss))
    lanes.sort()
    # passes of the window: the four requests after the attach (passes 2..5)
    first_pass = 6 - len(lanes)
    per = []
    pool_main = collections.Counter()
    pool_total = 0
    for k, (tid, tot, lc, ss) in enumerate(lanes):
        p = first_pass + k
        c = collections.Counter()
        for st, n in ss:
            if any(x.endswith("trained_block::seal_chain") for x, o in st):
                c[classify_lane(st)] += n
        per.append({"pass": p, "thread": tid, "thread_total_samples": tot, "seal_chain_samples": lc, "sealing_wall_s_sampled_run": walls[p], "request_s": reqs[p], "lane": dict(c)})
    # pool threads
    workers = {}
    for h, tot, ss in th:
        if "hl-seal8-" not in h:
            continue
        name = h.split(":")[1].strip() if ":" in h else h
        kinds = collections.Counter()
        for st, n in ss:
            if any(x.endswith("trained_block::witness_for_block") for x, o in st):
                pool_main[classify_pool_main(st)] += n
                pool_total += n
                kinds["main_line_" + leaf_kind(st)] += n
            else:
                kinds["other_" + leaf_kind(st)] += n
        workers[name] = {"total": tot, **dict(kinds)}
    sum_lane = sum(x["seal_chain_samples"] for x in per)
    sum_wall = sum(x["sealing_wall_s_sampled_run"] for x in per)
    k = sum_wall / sum_lane
    npass = len(per)
    # group table: seconds per pass (mean over the window's passes), at the sampler-run's own wall
    cats = collections.Counter()
    for x in per:
        for key, n in x["lane"].items():
            if key != "lane_wait_pool_build":
                cats[key] += n
    for key, n in pool_main.items():
        cats[key] += n
    total_main = sum(cats.values())
    grp = collections.Counter()
    for key, n in cats.items():
        grp[key[0]] += n
    table = {key: {"samples": n, "s_per_pass_sampled": n * k / npass, "share": n / total_main} for key, n in sorted(cats.items())}
    gtab = {g: {"samples": n, "s_per_pass_sampled": n * k / npass, "share": n / total_main} for g, n in sorted(grp.items())}
    # worker busy: samples where a worker is neither asleep nor spinning, over the sealing window (lane's seal_chain samples count the window)
    busy = sum(v.get("main_line_work", 0) + v.get("other_work", 0) for v in workers.values())
    spin_dev = sum(v.get("main_line_device_wait", 0) + v.get("other_device_wait", 0) for v in workers.values())
    spin = sum(v.get("main_line_spin", 0) + v.get("other_spin", 0) for v in workers.values())
    res = {
        "label": label, "sample_file": smp, "sample_sha256": meta["sample"]["sha256"], "sample_bytes": meta["sample"]["bytes"],
        "passes": per, "sum_seal_chain_samples": sum_lane, "sum_sealing_wall_s": sum_wall, "sec_per_sample": k,
        "pool_main_line_samples": pool_total, "lane_wait_on_pool_samples": sum(x["lane"].get("lane_wait_pool_build", 0) for x in per),
        "main_line_total_samples": total_main, "main_line_total_s_per_pass_sampled": total_main * k / npass,
        "categories": table, "groups": gtab, "workers": workers,
        "worker_busy_samples_work": busy, "worker_busy_samples_device_spin": spin_dev, "worker_spin_samples": spin,
        "avg_workers_working_during_sealing": busy / sum_lane, "avg_workers_working_plus_device_wait": (busy + spin_dev) / sum_lane,
    }
    (OUT / f"{label}.split.json").write_text(json.dumps(res, indent=1) + "\n")
    lines = [f"{label}: {npass} sealing passes in the window (passes {first_pass}..{first_pass + npass - 1}); lane seal_chain samples {sum_lane}, sealing walls (sampled run) {sum_wall:.3f} s => {k * 1000:.3f} ms/sample",
             f"main line: {total_main} samples = {total_main * k / npass:.3f} s per pass (lane own {total_main - pool_total} + in-pool {pool_total}); lane parked on the pool latch {res['lane_wait_on_pool_samples']} samples (cross-check vs in-pool {pool_total})",
             "per pass lane samples/ wall: " + ", ".join(f"p{x['pass']}: {x['seal_chain_samples']} / {x['sealing_wall_s_sampled_run']:.3f}" for x in per), "", "group table (s per pass at the sampled run's wall, share of main line):"]
    for g, v in gtab.items():
        lines.append(f"  {g}: {v['s_per_pass_sampled']:.3f} s  {100 * v['share']:.1f}%  ({v['samples']} samples)")
    lines.append("categories:")
    for key, v in table.items():
        lines.append(f"  {key:42s} {v['s_per_pass_sampled']:.3f} s  {100 * v['share']:.1f}%  ({v['samples']})")
    lines.append(f"workers (8): working samples {busy}, device-wait-spin samples {spin_dev}, yield-spin {spin}; avg workers working during sealing {busy / sum_lane:.2f}; incl. device wait {(busy + spin_dev) / sum_lane:.2f}")
    for nm, v in workers.items():
        lines.append(f"  {nm}: {v}")
    (OUT / f"{label}.split.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    for lab in sys.argv[1:]:
        split(lab)
