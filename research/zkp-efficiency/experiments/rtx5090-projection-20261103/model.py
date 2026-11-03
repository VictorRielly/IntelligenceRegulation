#!/usr/bin/env python3
"""RTX 5090 projection for W16R2 (Q = 280) + D55, one request, 8B T128.

Arithmetic only. No proof, build or GPU run. Every Mac input is quoted with
its source; every 5090 factor is a labelled range. Run:

    python3 model.py            # prints the tables, writes projection.json

Labels used in the printout:
  [MEASURED]  a number from a Mac log (source given)
  [MODEL]     arithmetic on measured parts or spec sheets
  [ESTIMATE]  judgement (a range)
"""
import itertools
import json
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# 1. Mac inputs, W16R2_8B_T128_H24, Metal, warm  [MEASURED]
# ---------------------------------------------------------------------------
# GPU attribution per block, ms, from HL_METAL_TIMING=1 (attribution only):
#   results/zk60_w16r2_20261101/logs/ab/m_ab_gpu.log, warm pass 1 (W16R2 arm)
#   and results/zk60_metal_20261031/README.md M21 (rate-1/2 commit, n = 7).
MAC_GPU = {
    # commitment A + H at rate 1/2 (2^14 -> 2^15)
    "ntt_inverse": (10.0, 13.0),   # 5 + 5 (M21, A/B pass 1); 5 + 8 (A/B pass 0)
    "ntt_forward": (18.0, 25.0),   # 9 + 9 (M21); 12 + 13 (A/B log)
    "leaf_hash": (4.0, 4.0),       # 2 + 2
    # device sumcheck rounds, "batch + replay" clocks (host wall around a
    # command buffer; includes the one-threadgroup transcript step)
    "zc_heavy": (59.7, 59.7),      # slots 14 15.6, 15 6.1, 16 3.8, 17 8.1, 18 26.1
    "zc_tab": (5.1, 5.1),          # slot 19, 58 x 2^14, almost all fixed cost
    "zc_small": (12.5, 12.5),      # slots 00 01 03 04 21 22: 2.4 2.3 2.0 2.5 1.9 1.4
}
# D55 one request, N = 6 forks, best pass [MEASURED]
#   results/zk60_w16r2_20261101/logs/ab/m_d55_r2a.log pass 1
MAC_D55 = {"wall": 5.542, "preflight": 0.377, "commit": 0.226, "forks": 4.862,
           "join": 0.077, "N": 6, "blocks": 32, "tokens": 128}
MAC_CORE_ONE_BLOCK = 0.336  # prove core, warm median, W16R2 (README A/B)
MAC_FORK_PEAK_GB = (19.8, 21.0)  # guard peak "VRAM" (Metal allocation), N = 6
#   results/zk60_resource_guard/history.jsonl, labels w16r2-d55-r2a / -r2b

# ---------------------------------------------------------------------------
# 2. How each Mac GPU part splits by what bounds it  [MODEL / ESTIMATE]
# ---------------------------------------------------------------------------
# Counted from the shapes (see README section 2):
#  - forward NTT 2^15 x 2504 rows: 615 M twiddle products = 4.1 ms at the
#    measured 149 G/s; two passes of 0.66 GB each way = 3.7 ms at 0.7 TB/s;
#    model 7.8 ms against 9 measured -> about half multiply, half DRAM
#    (also M11: "about half multiply-bound").
#  - inverse NTT 2^14: 287 M products = 1.9 ms; 0.66 GB = 0.9 ms; 5 measured
#    -> 0.4 multiply, 0.2 DRAM, 0.4 other (latency / occupancy).
#  - slot 18: 2^21 x 5 points x 58 multiplies ~ 445 M Fp2-equivalents =
#    12.8 ms at the measured 34.7 G Fp2/s of 26.1 -> arithmetic ~0.47; DRAM
#    ~1.4 GB = 2.1 ms -> 0.08; the rest is redundant per-point loads (cache)
#    and the per-round fixed cost (M13: "table loads and latency weigh as much
#    as the multiplies").
SPLIT = {
    #                 mul   dram  cache  alu32 lat
    "ntt_inverse": (0.40, 0.20, 0.00, 0.00, 0.40),
    "ntt_forward": (0.50, 0.50, 0.00, 0.00, 0.00),
    "leaf_hash":   (0.00, 0.10, 0.00, 0.90, 0.00),
    "zc_heavy":    (0.47, 0.08, 0.20, 0.00, 0.25),
    "zc_tab":      (0.15, 0.05, 0.00, 0.00, 0.80),
    "zc_small":    (0.15, 0.05, 0.00, 0.00, 0.80),
}
KINDS = ("mul", "dram", "cache", "alu32", "lat")

# ---------------------------------------------------------------------------
# 3. 5090 / M3 Ultra factors  [ESTIMATE from spec sheets + one laptop probe]
# ---------------------------------------------------------------------------
# mul:   Goldilocks 64x64 multiply throughput. Mac 149 G/s [MEASURED, M18].
#        RTX 4070 Laptop 64x64->128 MAC probe 156.5 G/s [MEASURED on the lost
#        laptop, docs/zkmatrix-poc/U_PERF2_CLAIM2_REPORT.md 2.3], i.e. about
#        the Mac's figure; 5090 / 4070L SM x GHz = 410 / (54-72) = 5.7-7.6
#        (U_PERF3_THROUGHPUT_MODEL.md 3.2: every part issues 64 int32
#        multiplies per SM per clock). Widened to 4-8 for port efficiency.
# dram:  1792 / 819 GB/s = 2.19 nominal; 1.9-2.2 achieved.
# cache: redundant per-point table loads served by L1/L2; no like-for-like
#        figure for the M3 Ultra; 2-4.
# alu32: BLAKE3 add/xor/rotate: 21,760 lanes x 2.41 GHz against
#        10,240 x ~1.4 GHz = 3.7 nominal; 3-3.7.
# lat:   per-round fixed cost (dispatch, one-threadgroup transcript step,
#        partial reduction). Metal batched round 0.025 ms [MEASURED, M6
#        probe]; a CUDA graph node is a few microseconds and the 5090 clock
#        is ~1.7x; 1.5-4 when serialized.
K = {"mul": (4.0, 8.0), "dram": (1.9, 2.2), "cache": (2.0, 4.0),
     "alu32": (3.0, 3.7), "lat": (1.5, 4.0)}

# ---------------------------------------------------------------------------
# 4. Host, link, memory, serial head/tail on the 5090 box  [ESTIMATE]
# ---------------------------------------------------------------------------
# H: one fork's host wall per block (Mac-equivalent) = core 0.336 s minus
#    the 0.109-0.116 s of GPU attribution -> 0.20-0.24 s. The M9 sample found
#    the rayon workers idle in 99% of samples, so this is mostly ONE thread.
H_MAC = (0.20, 0.24)
# host speed of the (undocumented) 5090 box's CPU against an M3 Ultra P-core,
# including the lower DRAM bandwidth of a desktop part for the streaming
# phases (witness planes, histograms, helper writes, folds)
HOST_SPEED = (0.7, 1.1)
# H2D per block: today's Metal path builds A's and H's data (0.67 GB) and the
# device sumcheck tables (~0.70 GB) on the host in unified memory. A discrete
# card must upload them unless they are built on the device.
#   naive: 1.37 GB at 50 GB/s = 27 ms; tables built on device: 0.67 GB = 13 ms;
#   compact planes (i8/i16 words) + device tables: ~0.25 GB = 5 ms.
PCIE_MS = {"naive": 27.0, "device_tables": 13.0, "compact": 5.0}
# fork count limited by 32 GB VRAM: Mac W16R2 N = 6 peaked 19.8-21.0 GB
# (3.3-3.5 GB per fork); with 30 GB usable that is 8-9 forks; host-resident
# data matrices (~0.67 GB per fork) give ~11.
N_FORKS = (6, 8, 10)
# serial head + tail per request (preflight, 31 boundary commits, join)
S_TODAY = (0.45, 0.85)      # Mac 0.680 s; desktop CPU, faster GPU commits
S_FIXED = (0.10, 0.20)      # with H122 (preflight once per resident model or
                            # parallel) and H123 (boundary commits in parallel)
# Mac's unexplained concurrency overhead: forks phase per block 0.152 s
# against 0.109-0.116 s of summed attribution -> 1.31-1.39.
ETA_MAC = (4.862 / 32) / (sum(v[1] for v in MAC_GPU.values()) / 1000.0), \
          (4.862 / 32) / (sum(v[0] for v in MAC_GPU.values()) / 1000.0)
# host DRAM traffic per block written/read by host phases (witness planes
# 0.33 GB, helpers 0.52 GB, lookup reads 0.26 GB, store-fold reads 0.67 GB,
# device sumcheck tables built "in place" by host code 0.7-1.4 GB) [MODEL from
# the phase report's byte column, logs/m15g/phases.log]; with tables built on
# the device and planes uploaded compact: 0.5-1.0 GB.
HOST_GB_PER_BLOCK = {"today": (2.5, 3.5), "device_tables": (0.5, 1.0)}
# usable host DRAM bandwidth of the undocumented 5090 box: desktop
# dual-channel DDR5 60-80 GB/s; a 4-8 channel workstation part 150-300 GB/s
HOST_BW = (60.0, 300.0)
# host CPU-seconds per block of the prover's own host phases (Mac-equivalent);
# mostly one thread per fork (M9) plus rayon bursts [ESTIMATE]
HOST_CPU_S = (0.25, 0.5)
HOST_CORES = (12, 28)
# THE WITNESS (outside every clock in the 22.9 tok/s figure). The D55 A/B
# harness rebuilds 32 witnesses on 8 builder threads before every timed call;
# the test's total wall minus every timed part is 8.48-8.71 s per call over
# five logs [INFERRED, not a witness clock] -> 0.27 s of whole-Mac wall per
# W16 8B T128 block. Consistent with the laptop's MEASURED TinyLlama T128
# witness, 0.607 s per block on 16 threads (witness_speed_tests), scaled by
# multiply-adds (2.79e10 per 8B block, about 5x TinyLlama's). The matmuls in
# witness.rs are scalar i32 products widened to i64 per term (~100 GMAC/s on
# the whole Mac). D55's phase 1 commits every boundary plane before any fork,
# so the forward chain over all 32 layers is a serial PREFIX of one request.
WITNESS_MAC_S = 0.27
WITNESS_5090_BOX = {
    # per-layer forward-chain seconds on the 5090 box
    # (the matmuls dominate: 2.79e10 multiply-adds per block; the elementwise
    # rest, ~0.3 GB of i64 planes, is 10-30 ms at desktop DRAM bandwidth)
    "today's CPU code (16-28 desktop cores)": (0.30, 0.60),
    "SIMD int8 CPU products (SDOT/VNNI, int16 split in two int8 limbs)": (0.04, 0.08),
    "exact forward on the GPU (int8 tensor-core products, two limbs)": (0.01, 0.035),
}
# CPU-seconds per witness today: 8 builder threads x 8.6 s / 32 witnesses =
# 2.15 (if each builder kept to its own thread) up to 32 x 8.6 / 32 = 8.6 (if
# rayon filled the machine) [INFERRED]
WITNESS_CPU_S_TODAY = (2.15, 8.6)


def gpu_ms(mac_ms, k, hide_lat=0.0):
    """5090 GPU ms for one block: each Mac part split by bound and divided by
    its factor; `hide_lat` of the latency share overlaps other forks' work
    (concurrent streams) and drops out of the throughput figure."""
    total = 0.0
    for part, ms in mac_ms.items():
        for kind, frac in zip(KINDS, SPLIT[part]):
            t = ms * frac / k[kind]
            if kind == "lat":
                t *= (1.0 - hide_lat)
            total += t
    return total


def forks_phase(blocks, n, h, g_own, g_tp, pcie, drain_frac, x_hostbw=float("inf"), x_cores=float("inf")):
    """Closed system: n workers, each cycling host h then its own GPU work
    g_own; the GPU, the link, host DRAM and host cores are shared. Asymptotic
    bounds plus a fill/drain term (zero when the GPU is the bottleneck, as on
    the Mac)."""
    x_host = n / (h + g_own)
    x_gpu = 1.0 / g_tp
    x_link = 1.0 / pcie
    x = min(x_host, x_gpu, x_link, x_hostbw, x_cores)
    limiter = {x_host: "host (forks x per-fork host path)", x_gpu: "GPU kernels",
               x_link: "PCIe uploads", x_hostbw: "host DRAM bandwidth", x_cores: "host cores"}[x]
    drain = 0.0 if limiter == "GPU kernels" else drain_frac * (h + g_own)
    return blocks / x + drain, limiter, (x_host, x_gpu, x_link)


def mac_check():
    g = gpu_ms({p: v[0] for p, v in MAC_GPU.items()}, {k: 1.0 for k in KINDS}) / 1000.0
    eta = ETA_MAC[1]
    f, lim, xs = forks_phase(32, 6, 0.22, g, g * eta, 1e-9, 0.0)
    s = MAC_D55["preflight"] + MAC_D55["commit"] + MAC_D55["join"]
    return {"gpu_attr_s": g, "eta": eta, "forks_s": f, "limiter": lim,
            "wall_s": s + f, "tok_s": 128 / (s + f),
            "measured_wall_s": MAC_D55["wall"], "measured_tok_s": 128 / MAC_D55["wall"]}


def scenario(name, *, mac_pick, k_pick, regime, eta, h_mac, host_speed, n, pcie, s, drain_frac,
             host_gb=2.0, host_bw=80.0, cpu_s=0.35, cores=16, mac_delta=None, h_delta=0.0, s_delta=0.0):
    mac = {p: (v[0] if mac_pick == "lo" else v[1]) for p, v in MAC_GPU.items()}
    if mac_delta:
        for p, d in mac_delta.items():
            mac[p] = max(0.0, mac[p] + d)
    k = {kk: (v[1] if k_pick == "hi" else v[0] if k_pick == "lo" else (v[0] + v[1]) / 2) for kk, v in K.items()}
    hide = 0.0 if regime == "serial-queue" else 0.8
    g_own = gpu_ms(mac, k, 0.0) / 1000.0
    g_tp = gpu_ms(mac, k, hide) / 1000.0 * eta
    h = (h_mac + h_delta) / host_speed
    x_bw = host_bw / host_gb
    x_cores = cores / ((cpu_s + h_delta) / host_speed)
    f, lim, xs = forks_phase(32, n, h, g_own, g_tp, pcie / 1000.0, drain_frac, x_bw, x_cores)
    wall = (s + s_delta) + f
    return {"name": name, "regime": regime, "N": n, "g_tp_ms": g_tp * 1000, "g_own_ms": g_own * 1000,
            "host_ms_per_fork_block": h * 1000, "pcie_ms": pcie, "serial_s": s + s_delta,
            "forks_s": f, "wall_s": wall, "tok_s": 128 / wall, "limiter": lim,
            "x_host_blk_s": xs[0], "x_gpu_blk_s": xs[1], "x_link_blk_s": xs[2],
            "x_hostbw_blk_s": x_bw, "x_cores_blk_s": x_cores,
            "aggregate_ceiling_tok_s": 128 / 32 * min(xs[1], xs[2], x_bw, x_cores)}


# the per-fork host path, Mac W16 phase report (logs/m15g/phases.log, 0.358 s
# wall) minus the GPU attribution, re-cut at rate 1/2 [MODEL]:
#   witness planes + lookup values + exp/act indices + mask rows   39 ms
#   H helpers, inverses, table helpers, mask rows                  26 ms
#   commit CPU parts (salts, Merkle trees) A + H at rate 1/2       15 ms
#   M commit                                                        5 ms
#   matmul slots 05-13 (public weight folds; diagonal test weights)31 ms
#   zero-check table builds + setup, slots 14-18                    34 ms
#   small slots' host share (00-04, 19-22)                          24 ms
#   openings (store folds 16, clear vectors, paths, transcript)    41 ms
#   total                                                         ~215 ms
# Dense real weights add about +15 ms (M8 estimate).
HOST_PATH_MS = {"planes_lookups": 39, "helpers_masks": 26, "commit_cpu": 15, "m_commit": 5,
                "weight_folds": 31, "zc_table_builds": 34, "small_slots_host": 24, "openings": 41}
DEVICE_TABLES_H_CUT = 0.030   # table builds move to the device (34 ms, less a residue)
CENTRAL = dict(mac_pick="lo", k_pick="mid", regime="streams", eta=1.15, h_mac=sum(H_MAC) / 2 - DEVICE_TABLES_H_CUT,
               host_speed=0.9, n=N_FORKS[1], pcie=PCIE_MS["device_tables"], s=sum(S_TODAY) / 2,
               drain_frac=0.25, host_gb=sum(HOST_GB_PER_BLOCK["device_tables"]) / 2, host_bw=80.0,
               cpu_s=sum(HOST_CPU_S) / 2, cores=16)


def corners():
    out = []
    # pessimistic: straight port (Metal-like single queue, host-built tables
    # uploaded, desktop dual-channel host), today's serial head, few forks
    out.append(scenario("P: straight port", mac_pick="hi", k_pick="lo", regime="serial-queue",
                        eta=ETA_MAC[1], h_mac=H_MAC[1], host_speed=HOST_SPEED[0], n=N_FORKS[0],
                        pcie=PCIE_MS["naive"], s=S_TODAY[1], drain_frac=0.5,
                        host_gb=HOST_GB_PER_BLOCK["today"][1], host_bw=HOST_BW[0],
                        cpu_s=HOST_CPU_S[1], cores=HOST_CORES[0]))
    # the same port but host phases as today on a desktop host (host-built tables)
    out.append(scenario("P2: streams, host-built tables", **dict(CENTRAL, pcie=PCIE_MS["naive"],
                        h_mac=sum(H_MAC) / 2, host_gb=sum(HOST_GB_PER_BLOCK["today"]) / 2)))
    # central: per-fork streams, tables built on device, mid factors, today's head
    out.append(scenario("C: streams, device tables", **CENTRAL))
    # central + the two byte-identical serial-head fixes
    out.append(scenario("C + H122/H123", **dict(CENTRAL, s=sum(S_FIXED) / 2)))
    # optimistic: compact uploads, fast workstation host, 10 forks, fixed head
    out.append(scenario("O: compact uploads, fast host", mac_pick="lo", k_pick="hi", regime="streams",
                        eta=1.0, h_mac=H_MAC[0], host_speed=HOST_SPEED[1], n=N_FORKS[2],
                        pcie=PCIE_MS["compact"], s=S_FIXED[0], drain_frac=0.25,
                        host_gb=HOST_GB_PER_BLOCK["device_tables"][0], host_bw=HOST_BW[1],
                        cpu_s=HOST_CPU_S[0], cores=HOST_CORES[1]))
    return out


def monte_carlo(n_draws=20000, seed=20261103, fixed_head=False, regime="streams", device_tables=True,
                witness=None):
    """Uniform draws over every range. `device_tables` False keeps today's
    host-built sumcheck tables (naive uploads, today's host DRAM traffic).
    `witness` (a WITNESS_5090_BOX key) adds the serial forward-chain prefix."""
    rnd = random.Random(seed)
    toks, lims = [], {}
    for _ in range(n_draws):
        mac = {p: rnd.uniform(*v) for p, v in MAC_GPU.items()}
        k = {kk: rnd.uniform(*v) for kk, v in K.items()}
        hide = rnd.uniform(0.6, 0.9) if regime == "streams" else 0.0
        eta = rnd.uniform(1.0, 1.2) if regime == "streams" else rnd.uniform(*ETA_MAC)
        g_own = gpu_ms(mac, k, 0.0) / 1000.0
        g_tp = gpu_ms(mac, k, hide) / 1000.0 * eta
        speed = rnd.uniform(*HOST_SPEED)
        h = rnd.uniform(*H_MAC) / speed
        n = rnd.choice(N_FORKS)
        if device_tables:
            pcie = rnd.choice([PCIE_MS["device_tables"], PCIE_MS["compact"]]) / 1000.0
            gb = rnd.uniform(*HOST_GB_PER_BLOCK["device_tables"])
        else:
            pcie = PCIE_MS["naive"] / 1000.0
            gb = rnd.uniform(*HOST_GB_PER_BLOCK["today"])
        x_bw = rnd.uniform(*HOST_BW) / gb
        x_cores = rnd.uniform(*HOST_CORES) / (rnd.uniform(*HOST_CPU_S) / speed)
        s = rnd.uniform(*(S_FIXED if fixed_head else S_TODAY))
        f, lim, _ = forks_phase(32, n, h, g_own, g_tp, pcie, rnd.uniform(0.0, 0.5), x_bw, x_cores)
        chain = 32 * rnd.uniform(*WITNESS_5090_BOX[witness]) if witness else 0.0
        if witness and chain > 0:
            lim_w = "witness forward chain" if chain > f else lim
        else:
            lim_w = lim
        toks.append(128 / (chain + s + f))
        lims[lim_w] = lims.get(lim_w, 0) + 1
    toks.sort()
    q = lambda p: toks[int(p * (len(toks) - 1))]
    return {"regime": regime, "fixed_head": fixed_head, "device_tables": device_tables, "witness": witness,
            "p10": q(0.10), "p50": q(0.50), "p90": q(0.90),
            "p_ge_50": sum(t >= 50 for t in toks) / len(toks),
            "limiter_share": {k2: round(v / n_draws, 3) for k2, v in sorted(lims.items())}}


# ---------------------------------------------------------------------------
# 5. Levers, as deltas on the Mac attribution (ms per block) or the host path
# ---------------------------------------------------------------------------
LEVERS = [
    # name, GPU deltas by part (Mac ms), host delta (s per fork-block), serial delta (s)
    ("coefficient-form rows (drop the inverse NTT)", {"ntt_inverse": -10.0}, 0.0, 0.0),
    ("#5 pruned coset NTT at rate 1/2 (first stage, 1 - Q/n of pairs)", {"ntt_forward": -0.7}, 0.0, 0.0),
    ("#2 zero-check kernels, low (shared loads only)", {"zc_heavy": -3.0}, 0.0, 0.0),
    ("#2 zero-check kernels, high", {"zc_heavy": -12.0}, 0.0, 0.0),
    ("#3 batch equal-size zero-checks, low", {"zc_small": -3.0, "ntt_forward": -0.5}, -0.005, 0.0),
    ("#3 batch equal-size zero-checks, high", {"zc_small": -9.0, "ntt_forward": -0.5}, -0.005, 0.0),
    ("#4 non-power-of-two F domain", {"zc_heavy": -3.2, "ntt_forward": -1.4}, -0.001, 0.0),
    ("H114 helper inverses by gather", {}, -0.004, 0.0),
    ("H122 preflight once per resident model / parallel", {}, 0.0, -0.30),
    ("H123 boundary commits in parallel", {}, 0.0, -0.15),
    # host-path levers (byte-preserving; matter only where the host path limits)
    ("5090: store folds on the device", {}, -0.016, 0.0),
    ("5090: public weight folds on the device", {}, -0.031, 0.0),
    ("5090: Merkle trees + salts on the device", {}, -0.012, 0.0),
    ("5090: witness planes, lookups, helpers on the device", {}, -0.060, 0.0),
    ("5090: the whole host path on the device (residue 0.04 s)", {}, -0.150, 0.0),
]


def mac_lever(gpu_delta, h_delta, s_delta):
    """Mac one-request D55 N = 6, GPU-bound: the forks phase scales with the
    summed attribution (eta held); host deltas do not move a GPU-bound run."""
    base = sum(v[0] for v in MAC_GPU.values())
    new = base + sum(gpu_delta.values())
    forks = MAC_D55["forks"] * new / base
    s = MAC_D55["preflight"] + MAC_D55["commit"] + MAC_D55["join"] + s_delta
    return 128 / (s + forks)


def main():
    lines = []
    p = lines.append
    mc = mac_check()
    p("== Mac calibration (k = 1 everywhere) ==")
    p(f"summed GPU attribution {mc['gpu_attr_s']*1000:.1f} ms/block; eta (forks/32 over attribution) {ETA_MAC[0]:.2f}-{ETA_MAC[1]:.2f}")
    p(f"model wall {mc['wall_s']:.3f} s = {mc['tok_s']:.1f} tok/s; measured {mc['measured_wall_s']} s = {mc['measured_tok_s']:.1f} tok/s; limiter {mc['limiter']}")
    p("")
    p("== 5090 corners, one request, W16R2 (Q 280) + D55, 8B T128, PROOF ONLY (the Mac's 22.9 clock) [MODEL on ESTIMATE ranges] ==")
    p(f"{'scenario':34s} {'N':>2s} {'G_tp ms':>8s} {'G_own':>6s} {'H ms':>6s} {'PCIe':>5s} {'S s':>5s} {'forks s':>7s} {'wall s':>6s} {'tok/s':>6s} {'aggr':>5s}  limiter")
    cs = corners()
    for c in cs:
        p(f"{c['name']:34s} {c['N']:2d} {c['g_tp_ms']:8.1f} {c['g_own_ms']:6.1f} {c['host_ms_per_fork_block']:6.0f} {c['pcie_ms']:5.0f} {c['serial_s']:5.2f} {c['forks_s']:7.2f} {c['wall_s']:6.2f} {c['tok_s']:6.1f} {c['aggregate_ceiling_tok_s']:5.0f}  {c['limiter']}")
    p("")
    mcs = [monte_carlo(regime="serial-queue", device_tables=False), monte_carlo(device_tables=False),
           monte_carlo(), monte_carlo(fixed_head=True)]
    p("== Monte Carlo over the ranges, PROOF ONLY (uniform, 20,000 draws, seed 20261103) ==")
    for m in mcs:
        p(f"regime {m['regime']:12s} device tables {str(m['device_tables']):5s} head fixed {str(m['fixed_head']):5s}: p10 {m['p10']:.1f}  p50 {m['p50']:.1f}  p90 {m['p90']:.1f} tok/s; P(>=50) {m['p_ge_50']:.2f}; limiter {m['limiter_share']}")
    p("")
    p("== The target's clock: the witness forward chain is a serial prefix of one D55 request ==")
    p(f"Mac today [INFERRED]: {WITNESS_MAC_S} s/block x 32 = {32*WITNESS_MAC_S:.1f} s before the commit phase; "
      f"with the measured 5.542 s proof: {128/(32*WITNESS_MAC_S+5.542):.1f} tok/s (proof-only 23.1)")
    mws = []
    for wkey in WITNESS_5090_BOX:
        m = monte_carlo(fixed_head=True, witness=wkey)
        mws.append(m)
        p(f"5090, streams, device tables, head fixed, witness = {wkey}: p10 {m['p10']:.1f}  p50 {m['p50']:.1f}  p90 {m['p90']:.1f}; P(>=50) {m['p_ge_50']:.2f}")
    lo = 16 / WITNESS_CPU_S_TODAY[1] * 4
    hi = 16 / WITNESS_CPU_S_TODAY[0] * 4
    p(f"today's witness code, even perfectly overlapped, on 16 host cores: {lo:.0f}-{hi:.0f} tok/s aggregate ceiling "
      f"({WITNESS_CPU_S_TODAY[0]}-{WITNESS_CPU_S_TODAY[1]} CPU-s per block) [INFERRED]")
    p("")
    p("== Levers: Mac one request (GPU-bound, N = 6) and 5090 central (C + H122/H123) ==")
    base_mac = mac_lever({}, 0.0, 0.0)
    c_args = dict(CENTRAL, s=sum(S_FIXED) / 2)
    c_today = dict(CENTRAL)
    base_c = scenario("base", **c_args)
    base_t = scenario("base", **c_today)
    p(f"{'lever':62s} {'Mac tok/s':>9s} {'x':>5s} {'5090 C tok/s':>12s} {'x':>5s} {'5090 C(today head)':>18s} {'x':>5s}")
    p(f"{'(baseline)':62s} {base_mac:9.1f} {1:5.2f} {base_c['tok_s']:12.1f} {1:5.2f} {base_t['tok_s']:18.1f} {1:5.2f}")
    lev = []
    for name, gd, hd, sd in LEVERS:
        m = mac_lever(gd, hd, sd)
        # the head-fixed column already contains H122/H123: a serial lever is 1.00 there
        c = scenario(name, mac_delta=gd, h_delta=hd, s_delta=0.0, **c_args)
        t = scenario(name, mac_delta=gd, h_delta=hd, s_delta=sd, **c_today)
        lev.append({"lever": name, "mac_tok_s": m, "mac_x": m / base_mac, "c_tok_s": c["tok_s"],
                    "c_x": c["tok_s"] / base_c["tok_s"], "c_today_head_tok_s": t["tok_s"],
                    "c_today_head_x": t["tok_s"] / base_t["tok_s"], "c_limiter": c["limiter"]})
        p(f"{name:62s} {m:9.1f} {m/base_mac:5.2f} {c['tok_s']:12.1f} {c['tok_s']/base_c['tok_s']:5.2f} {t['tok_s']:18.1f} {t['tok_s']/base_t['tok_s']:5.2f}")
    p("")
    # what the central 5090 needs from the host path: break-even forks
    p("== Forks needed so the GPU, not the host path, is the limiter (central) ==")
    for h_ms in (150, 200, 250, 300):
        g_tp = base_c["g_tp_ms"] / 1000
        g_own = base_c["g_own_ms"] / 1000
        n_need = (h_ms / 1000 + g_own) / g_tp
        p(f"host path per fork-block {h_ms} ms: N >= {n_need:.1f} (VRAM fits about 8-9 at 3.3-3.5 GB per fork)")
    p("")
    # T256 one request on the 5090 (H and VRAM per fork x ~1.8-2; GPU per token ~same)
    p("== T256 against T128 on the 5090, central factors [MODEL] ==")
    t256 = []
    for t, hmul, gmul, vram_per_fork, smul in ((128, 1.0, 1.0, 3.4, 1.0), (256, 1.85, 1.8, 6.6, 1.3)):
        n = max(1, int(30 // vram_per_fork))
        r = scenario(f"T{t}", **dict(c_args, n=n, h_mac=CENTRAL["h_mac"] * hmul, s=sum(S_FIXED) / 2 * smul,
                                     pcie=PCIE_MS["device_tables"] * gmul, host_gb=c_args["host_gb"] * hmul,
                                     cpu_s=c_args["cpu_s"] * hmul),
                     mac_delta={p2: v[0] * (gmul - 1) for p2, v in MAC_GPU.items()})
        tok = t / r["wall_s"]
        t256.append({"T": t, "N": n, "wall_s": r["wall_s"], "tok_s": tok, "limiter": r["limiter"]})
        p(f"T{t}: N {n} (30 GB / {vram_per_fork} GB), wall {r['wall_s']:.2f} s, {tok:.1f} proved tok/s, limiter {r['limiter']}")
    out = {"mac_check": mc, "eta_mac": ETA_MAC, "corners": cs, "monte_carlo": mcs, "witness_monte_carlo": mws,
           "levers": lev, "t256": t256,
           "inputs": {"MAC_GPU": MAC_GPU, "SPLIT": SPLIT, "K": K, "H_MAC": H_MAC, "HOST_SPEED": HOST_SPEED,
                      "PCIE_MS": PCIE_MS, "N_FORKS": N_FORKS, "S_TODAY": S_TODAY, "S_FIXED": S_FIXED,
                      "MAC_D55": MAC_D55, "HOST_GB_PER_BLOCK": HOST_GB_PER_BLOCK, "HOST_BW": HOST_BW,
                      "HOST_CPU_S": HOST_CPU_S, "HOST_CORES": HOST_CORES, "WITNESS_MAC_S": WITNESS_MAC_S,
                      "WITNESS_5090_BOX": WITNESS_5090_BOX, "CENTRAL": CENTRAL}}
    with open(os.path.join(HERE, "projection.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=str)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
