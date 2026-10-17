"""Llama-3-8B private-stack projections and the lever ladder (read-only arithmetic, [MODEL]).

Inputs: the calibrated per-block phase model (cost_model.py, fitted on the R4-4 TinyLlama T128
phase run and validated on the r3 ladder and the r4 8B T32 stack) and the exact layout replica
(layout.py).  Every platform/lever factor below is an ASSUMPTION with a stated basis; the
printed tables are copied into docs/zkmatrix-poc/ZK60_SPEED_PLAN_20261017.md.
One thread, < 1 s, < 50 MB.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cost_model as cm  # noqa: E402
from layout import Shape, clog2  # noqa: E402

L = 32  # Llama-3-8B blocks
W_UNPADDED = 4096 * 4096 * 2 + 4096 * 1024 * 2 + 3 * 4096 * 14336  # 218,103,808 weights per block

# ---------------------------------------------------------------- layout variants ------------


class Llama8B(Shape):
    """Llama-3-8B block geometry; optional design variants (COUNTED sketches, not specs)."""

    def __init__(self, T, log_cols, zkattn=False, triangle=False):
        self.zkattn, self.triangle = zkattn, triangle
        Shape.__init__(self, T, 4096, 14336, 32, 128, 8, log_cols)

    def natural_log(self, dom):
        nl = Shape.natural_log(self, dom)
        if dom == "S" and self.triangle:
            nl -= 1  # lower triangle packed into h * T * T/2 (needs a new profile + review)
        return nl

    def true_size(self, dom):
        ts = Shape.true_size(self, dom)
        if dom == "S" and self.triangle:
            ts = self.h * self.T * (self.T + 1) // 2
        return ts

    def a_plane_doms(self):
        v = Shape.a_plane_doms(self)
        if self.zkattn:  # keep s8, its remainder limb and E; drop zsel, P, p limbs, rho_s / sigma_s limbs
            n_s = v.count("S")
            v = [d for d in v if d != "S"] + ["S"] * 3
            assert n_s >= 3
        return v

    def lookups_per_position(self, dom):
        if dom == "S" and self.zkattn:
            return 4  # sym(s8) + remainder byte and its scaled top
        return Shape.lookups_per_position(self, dom)


def best_layout(T, **kw):
    best = None
    for lc in range(clog2(T) + 1, clog2(T) + 11):
        try:
            sh = Llama8B(T, lc, **kw)
        except AssertionError:
            continue
        rb = sh.receipt_bytes()
        if best is None or rb < best[0]:
            best = (rb, sh)
    return best[1]


# ---------------------------------------------------------------- measured-model pieces -----
C_CPU = cm.coefficients("cpu")
C_GPU_COMMIT_4070 = cm.coefficients("gpu")["commit"]  # 5.06 ns per committed element, keyed GPU commit, 4070 Laptop
G0_4070 = float(os.environ.get("REFIT_G0", "0.305"))  # fitted GPU-arm fixed overhead per block (s), cost_model validation; NATIVE-LANE COPY: overridable by the refit runner


def witness_cpu(T):
    """laptop 16 threads; TinyLlama fit 0.122/0.231/0.583 s at T32/64/128 scaled by weights (linear term)
    and by h*hd (quadratic term); reproduces the measured 8B T32 0.582 s/block."""
    a_tiny, b_tiny = 3.566e-3, 7.73e-6
    return a_tiny * (W_UNPADDED / 44_040_192) * T + b_tiny * 2 * T * T


def verify_block(sh):
    """fresh-process verifier cryptography per block, fit on TinyLlama T32/T128 and 8B T32 (T64 check)."""
    s = sh.summary()
    return 1.46e-9 * cm.padded_weights(sh) + 0.737e-6 * s["sizes"]["S"] + 0.0315


def phases(sh):
    return cm.block_phases(sh, C_CPU)


CPU_KEYS = ["conversion", "inverses", "zc_D", "zc_F", "zc_S", "zc_Q", "zc_Kv", "openings", "rest"]
ZC_KEYS = ["zc_D", "zc_F", "zc_S", "zc_Q", "zc_Kv"]

# ---------------------------------------------------------------- platforms -----------------
# Bands are (low, central, high) speed factors.  Every one is an ASSUMPTION; basis in the doc.
BOARD = (4.0, 5.0, 7.0)       # 5090 / 4070-Laptop for the keyed commit kernel (bandwidth 7.0x, SMs x clock ~5.7x)
HOST = (1.5, 2.0, 2.5)        # 5090 desktop host CPU / laptop 16 threads (CPU unknown; desktop 16-core class)
MAC = (2.0, 2.5, 3.5)         # M3 Ultra CPU / laptop 16 threads (24P+8E cores, 819 GB/s)
GPU_PORT = (10.0, 25.0, 60.0)  # a ported CPU phase on the 5090 / laptop 16 threads
GPU_WITNESS_S = (0.10, 0.03, 0.01)  # per block at T512 on the 5090 (int8 GEMM + exact requant), scales ~T
LOAD_PER_LAYER = float(os.environ.get("REFIT_LOAD", "2.5"))  # s, measured (digest pass 83 s / 32 layers; proving-pass reload 79 s); NATIVE-LANE COPY: overridable (R5 measured ~0.49 s)


def block_time(sh, mode, band=1, ported=(), witness_gpu=False):
    """seconds per block for one pass; mode in laptop_cpu, laptop_gpu, mac, 5090."""
    ph = phases(sh)
    s = sh.summary()
    elems = s["A_elems"] + s["H_elems"]
    w = witness_cpu(sh.T)
    if mode == "laptop_cpu":
        return ph["total"], w, ph
    if mode == "laptop_gpu":
        return ph["total"] - ph["commit"] + C_GPU_COMMIT_4070 * elems + G0_4070, w, ph
    if mode == "mac":
        return ph["total"] / MAC[band], w / MAC[band], ph
    if mode == "5090":
        commit = C_GPU_COMMIT_4070 * elems / BOARD[band] + G0_4070 / 2
        rest = 0.0
        for k in CPU_KEYS:
            rest += ph[k] / (GPU_PORT[band] if k in ported else HOST[band])
        wt = GPU_WITNESS_S[band] * sh.T / 512 if witness_gpu else w / HOST[band]
        return commit + rest, wt, ph
    raise ValueError(mode)


def memory(sh):
    s = sh.summary()
    elems = s["A_elems"] + s["H_elems"]
    terms = s["terms"]
    big_tables = max(16 * (terms[k] + 3) * s["sizes"][k] for k in terms)
    gib = 1024 ** 3
    return dict(elems_G=elems / 1e9,
                host_cpu_path_GiB=(0.5 * gib + 53 * elems) / gib,
                host_gpu_commit_path_GiB=(0.5 * gib + 40 * elems) / gib,
                vram_commit_only_GiB=(0.2 * gib + 8 * elems) / gib,
                vram_full_gpu_GiB=(1.25 * gib + 8 * elems + big_tables) / gib,
                largest_slot_tables_GiB=big_tables / gib)


def rate_single_pass(T, blk, wit, loads=True, inproc_verify=False, ver=None):
    total = L * (blk + wit)
    if loads:
        total += 2 * L * LOAD_PER_LAYER  # digest pass + proving-pass reload (today's CLI)
    if inproc_verify:
        total += L * LOAD_PER_LAYER + ver
    return T / total, total


if __name__ == "__main__":
    out = {"layouts": {}, "today": {}, "ladder": {}}
    Ts = [32, 128, 256, 512, 1024, 2048, 4096]
    print("== 8B layouts (receipt-optimal row width), counted ==")
    for T in Ts:
        sh = best_layout(T)
        s = sh.summary()
        m = memory(sh)
        ph = phases(sh)
        out["layouts"][T] = dict(log_cols=sh.log_cols, receipt_MB=s["receipt"] / 1e6, **m,
                                 u8_G=s["u8"] / 1e9, S=s["sizes"]["S"], F=s["sizes"]["F"], D=s["sizes"]["D"],
                                 cpu_phases={k: round(v, 3) for k, v in ph.items()}, witness_cpu=witness_cpu(T),
                                 verify_block=verify_block(sh))
        print("T%-5d 2^%d elems %.3fG receipt/blk %.1f MB stack %.2f GB | host CPU %.1f GiB, host GPU-commit %.1f GiB,"
              " VRAM commit-only %.1f GiB, VRAM full-GPU %.1f GiB (slot tables %.1f) | verify/blk %.2f s" % (
                  T, sh.log_cols, m["elems_G"], s["receipt"] / 1e6, L * s["receipt"] / 1e9, m["host_cpu_path_GiB"],
                  m["host_gpu_commit_path_GiB"], m["vram_commit_only_GiB"], m["vram_full_gpu_GiB"],
                  m["largest_slot_tables_GiB"], verify_block(sh)))
    print("\n== laptop-CPU phase model per block (s) ==")
    for T in Ts:
        ph = phases(best_layout(T))
        print("T%-5d total %.2f | commit %.2f zcD %.2f zcF %.2f zcS %.2f zcQ %.2f zcKv %.2f inv %.2f open %.2f conv %.2f rest %.2f (wfold %.2f) | witness %.2f" % (
            T, ph["total"], ph["commit"], ph["zc_D"], ph["zc_F"], ph["zc_S"], ph["zc_Q"], ph["zc_Kv"], ph["inverses"],
            ph["openings"], ph["conversion"], ph["rest"], ph["weight_fold_part_of_rest"], witness_cpu(T)))

    print("\n== today's code, single cold pass, prove-side rate (positions/s): proofs+witness+loads (no in-process verify) ==")
    for T in Ts:
        sh = best_layout(T)
        m = memory(sh)
        row = {}
        for mode in ("laptop_cpu", "laptop_gpu", "mac", "5090"):
            vals = []
            for band in (0, 1, 2):
                if mode in ("laptop_cpu", "laptop_gpu") and band != 1:
                    continue
                blk, wit, _ = block_time(sh, mode, band)
                load_f = HOST[band] if mode == "5090" else (MAC[band] if mode == "mac" else 1.0)
                r, tot = rate_single_pass(T, blk, wit, loads=False)
                tot += 2 * L * LOAD_PER_LAYER / min(load_f, 1.5)
                vals.append((T / tot, tot, L * blk, L * wit))
            row[mode] = vals
        fits = dict(laptop_cpu=m["host_cpu_path_GiB"] <= 12, laptop_gpu=m["host_gpu_commit_path_GiB"] <= 12 and m["vram_commit_only_GiB"] <= 6.5,
                    mac=m["host_cpu_path_GiB"] <= 230, **{"5090": m["vram_commit_only_GiB"] <= 28})
        out["today"][T] = dict(row=row, fits=fits)
        txt = []
        for mode, vals in row.items():
            if len(vals) == 1:
                txt.append("%s %.3f (%s, %.0f s)" % (mode, vals[0][0], "fits" if fits[mode] else "NO FIT", vals[0][1]))
            else:
                txt.append("%s %.3f/%.3f/%.3f (%s, central %.0f s)" % (mode, vals[0][0], vals[1][0], vals[2][0], "fits" if fits[mode] else "NO FIT", vals[1][1]))
        print("T%-5d " % T + " | ".join(txt))

    print("\n== the lever ladder on one 5090, steady state with a resident model (no loads), positions/s low/central/high ==")
    steps = [
        ("S0 today's code (GPU commits only; host CPU for the rest; CPU witness)", dict(ported=(), witness_gpu=False), {}),
        ("S1 + witness on the GPU", dict(ported=(), witness_gpu=True), {}),
        ("S2 + the five zero-check sumchecks on the GPU", dict(ported=tuple(ZC_KEYS), witness_gpu=True), {}),
        ("S3 + inverses, openings, conversion, rest on the GPU (whole prover resident)", dict(ported=tuple(CPU_KEYS), witness_gpu=True), {}),
        ("S4 + causal-triangle score domain [profile + soundness review]", dict(ported=tuple(CPU_KEYS), witness_gpu=True), dict(triangle=True)),
        ("S5 + zkAttn-style softmax normalization [RULING]", dict(ported=tuple(CPU_KEYS), witness_gpu=True), dict(triangle=True, zkattn=True)),
    ]
    for name, kw, lay in steps:
        res = {}
        for T in (256, 512, 1024):
            sh = best_layout(T, **lay)
            m = memory(sh)
            vals = []
            for band in (0, 1, 2):
                blk, wit, _ = block_time(sh, "5090", band, **kw)
                vals.append(T / (L * (blk + wit)))
            res[T] = dict(rates=vals, vram_full=m["vram_full_gpu_GiB"], vram_commit=m["vram_commit_only_GiB"], elems_G=m["elems_G"])
        out["ladder"][name] = res
        print(name)
        for T, r in res.items():
            print("   T%-5d %.2f / %.2f / %.2f   (elems %.3fG, VRAM commit-only %.1f GiB, full-GPU %.1f GiB)" % (
                T, r["rates"][0], r["rates"][1], r["rates"][2], r["elems_G"], r["vram_commit"], r["vram_full"]))

    # what dominates at S5 central, T512
    sh = best_layout(512, triangle=True, zkattn=True)
    blk, wit, ph = block_time(sh, "5090", 1, ported=tuple(CPU_KEYS), witness_gpu=True)
    s = sh.summary()
    commit = C_GPU_COMMIT_4070 * (s["A_elems"] + s["H_elems"]) / BOARD[1] + G0_4070 / 2
    print("\nS5 central T512 per block: total %.3f s, of which commit %.3f s, ported %.3f s, witness %.3f s" % (blk + wit, commit, blk - commit, wit))
    out["s5_t512_central"] = dict(block=blk + wit, commit=commit, ported=blk - commit, witness=wit)

    # commitment ceiling: commit alone at each band, today's layout vs S5 layout
    for lay_name, lay in (("today layout", {}), ("S5 layout", dict(triangle=True, zkattn=True))):
        sh = best_layout(512, **lay)
        s = sh.summary()
        e = s["A_elems"] + s["H_elems"]
        print("%s T512: committed %.3fG elems/block; commit-only ceiling positions/s at board factor %s: %s" % (
            lay_name, e / 1e9, BOARD, ["%.1f" % (512 / (L * (C_GPU_COMMIT_4070 * e / b))) for b in BOARD]))

    # ---------------- roofline (counted traffic) model of a whole-GPU prover on one 5090 ----------
    # bytes moved per unit, divided by an ACHIEVED bandwidth = fraction x 1.792 TB/s (5090 spec).
    BW = 1.792e12
    BYTES = dict(commit=170.0,        # per committed element: raw 8 B + encode passes ~128 B + hash read 32 B
                 zc=72.0,             # per element-term: Fp2 table build 24 B + rounds ~48 B
                 inv=56.0,            # per U8 lookup: value 8 B + helper 16 B + batch scratch 32 B
                 open=16.0,           # per committed element: one pass, all groups at once (compute ~ same)
                 witness=8.0)         # per A element written by the witness kernel (GEMMs themselves ~0.3 ms)
    SEQ_S = 0.025                     # per block: ~23 slots x ~25 rounds of host Fiat-Shamir syncs + host Merkle top

    def roofline_block(sh, frac):
        s = sh.summary()
        bw = BW * frac
        elems = s["A_elems"] + s["H_elems"]
        et = sum(s["sizes"][k] * s["terms"][k] for k in s["terms"])
        t = dict(commit=BYTES["commit"] * elems / bw, zc=BYTES["zc"] * et / bw, inv=BYTES["inv"] * s["u8"] / bw,
                 open=BYTES["open"] * elems / bw, witness=BYTES["witness"] * s["A_elems"] / bw, seq=SEQ_S)
        t["rest"] = 0.10 * t["zc"]
        t["total"] = sum(t.values())
        return t

    print("\n== roofline whole-GPU prover on one 5090, positions/s at achieved-bandwidth fraction 0.25 / 0.40 / 0.60 ==")
    out["roofline"] = {}
    for lay_name, lay in (("today layout", {}), ("+ causal triangle", dict(triangle=True)), ("+ triangle + zkAttn", dict(triangle=True, zkattn=True))):
        for T in (256, 512, 1024):
            sh = best_layout(T, **lay)
            vals = [roofline_block(sh, f) for f in (0.25, 0.40, 0.60)]
            out["roofline"]["%s T%d" % (lay_name, T)] = vals
            print("%-22s T%-5d %s | at 0.40: commit %.3f zc %.3f inv %.3f open %.3f wit %.3f seq %.3f total %.3f s/block" % (
                lay_name, T, " / ".join("%.1f" % (T / (L * v["total"])) for v in vals),
                vals[1]["commit"], vals[1]["zc"], vals[1]["inv"], vals[1]["open"], vals[1]["witness"], vals[1]["seq"], vals[1]["total"]))

    # amortization: tokens needed for a total-workload rate of 50 given steady rate r and startup s
    print("\n== total-workload rate: positions needed so that N / (startup + N / r) >= 50 ==")
    for r in (60.0, 75.0, 100.0):
        for st in (160.0, 40.0, 10.0):
            n = 50.0 * st / (1.0 - 50.0 / r)
            print("steady %.0f/s startup %.0f s -> N >= %.0f positions (%.1f passes of 512)" % (r, st, n, n / 512))

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "projection.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=float)
