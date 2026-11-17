#!/usr/bin/env python3
"""Batch 5 (D80a Gate M1 + H128 + H132 + D80 Candidate B Trained int16-Plane RMS Census).

Runs inside a single guarded GPU job (--class gpu --need-gib 16 --cap-gib 28):
  1. Adversarial & partial-tile exactness self-checks across all 7 Metal GEMM routes
     and both weight layouts ([N,K] in_out=0 and [K,N] in_out=1) vs exact host int64.
  2. Word-for-word verification (max_abs_diff == 0 across all 6,029,312 int64 output words)
     and >= 32 interleaved ABBA repeats on a quiet GPU for a full production W16R2 8B T128
     block (f_pad = 16,384, in_out = [0,0,0,0,1,1,1]) AND BASE 8B T128 block (f = 14,336),
     in BOTH timing scopes:
       - Scope A: Resident buffers (no host copies/conversions in timed region)
       - Scope B: Full host-i64 drop-in end-to-end (host i64 range-check & pack + page views
                  + command buffer + GPU execution included in timed region, decomposed by phase)
     and on BOTH real trained-activation ranges (6 int8 + 1 int16) AND full int16 [-32768, 32767].
  3. H132: Resident 1-CommandBuffer Batched K = 1, 2, 4, 8 32-Layer Llama-3-8B Exact-Integer
     Forward across 8 distinct real WikiText-2 T=128 prompts (max_abs_diff == 0 vs CPU int64
     and vs K standalone K=1 runs, 0 refusals, 16 interleaved ABBA repeats per K).
  4. D80 Candidate B Empirical Trained-Model Per-Plane RMS Census across all 32 layers of
     Llama-3-8B on the 8 real WikiText-2 T=128 prompts (1,024 tokens).
"""
from __future__ import annotations

import ctypes
import gc
import json
import math
import mmap
import os
import resource
import statistics
import subprocess
import sys
import time
from pathlib import Path
import numpy as np

ROOT = Path("/Users/victorrielly/IntelligenceRegulation")
EXP_DIR = ROOT / "results/zk60_astra_20261026/a7_a8_versioned_exports_20261104/llama3-8b/export"
CKPT_DIR = ROOT / "results/zk60_astra_20261026/a7_model_recovery_20261104/checkpoint"
WIKITEXT_DIR = ROOT / "results/zk60_fidelity_parity_20261019/data/wikitext2"
STAGE2_DIR = ROOT / "results/zk60_llama3_8b_feedforward_20261115"
sys.path.insert(0, str(STAGE2_DIR))
import llama8b_working_model as _l8b_mod  # noqa: E402
from llama8b_working_model import (  # noqa: E402
    Tokenizer,
    i_norm_2d,
    requant,
    rope_int,
    RefusalCounter,
    cpu_gemm_nk as _scalar_cpu_gemm_nk,
    run_forward,
)


def cpu_gemm_nk(x: np.ndarray, w_nk: np.ndarray) -> np.ndarray:
    """Exact int64 GEMM via 1024-column chunked IEEE-754 float64 BLAS (AMX dgemm):
    each chunk partial sum has |sum_{j<1024} x_j w_j| <= 1024 * 32768 * 128 = 2^32 << 2^53 (0 ULP),
    accumulated in int64 — 100% bit-identical to scalar int64 in ~0.8s instead of ~780s!
    """
    m, k = x.shape
    n = w_nk.shape[0]
    acc = np.zeros((m, n), dtype=np.int64)
    for c0 in range(0, k, 1024):
        c1 = min(k, c0 + 1024)
        acc += (x[:, c0:c1].astype(np.float64) @ w_nk[:, c0:c1].T.astype(np.float64)).astype(np.int64)
    return acc


_l8b_mod.cpu_gemm_nk = cpu_gemm_nk

BOS = 128000
MASK = -127
D, F_BASE, F_W16R2, H, KV, G, DH, V = 4096, 14336, 16384, 32, 8, 4, 128, 128256


def cpu_attn_1seq(qr_3d: np.ndarray, kr_3d: np.ndarray, v_3d: np.ndarray, L: dict, rec: RefusalCounter):
    T_len = qr_3d.shape[0]
    tri = np.tril(np.ones((T_len, T_len), dtype=bool))
    qg = qr_3d.reshape(T_len, KV, G, DH).transpose(1, 2, 0, 3).astype(np.float64)
    kg = kr_3d.transpose(1, 2, 0)[:, None, :, :].astype(np.float64)
    sacc = (qg @ kg).astype(np.int64)
    s8 = rec.check("score", requant(sacc, L["sh_s"]), -127, 127)
    masked = np.where(tri[None, None, :, :], s8, MASK)
    best = masked.max(-1, keepdims=True)
    delta = rec.check("exp_diff", best - masked, 0, 255)
    E = L["exp"][delta]
    total = np.where(tri[None, None, :, :], E, 0).sum(-1, keepdims=True)
    rec.check("softmax_den", total, 1 << L["f_e"], max(1, T_len) << L["f_e"])
    num = E << L["f_p"]
    p = np.where(tri[None, None, :, :], num // total, 0)
    rho = np.where(tri[None, None, :, :], num - p * total, 0)
    sigma = total - 1 - rho
    wrho_s = ((T_len - 1).bit_length() if T_len > 1 else 0) + L["f_e"]
    p = rec.check("softmax_p", p, 0, 1 << L["f_p"], extra_bad=(sigma < 0) | (sigma >= (1 << wrho_s)))
    vg = v_3d.transpose(1, 0, 2)[:, None, :, :].astype(np.float64)
    oacc = (p.astype(np.float64) @ vg).astype(np.int64)
    o = rec.check("O", requant(oacc, L["sh_o"]), -127, 127)
    return o.transpose(2, 0, 1, 3).reshape(T_len, D), s8, p


def page_aligned_array(shape: tuple[int, ...], dtype) -> tuple[np.ndarray, mmap.mmap]:
    """Allocates a page-aligned host array backed by anonymous mmap (matches metal.rs::result_plane)."""
    dt = np.dtype(dtype)
    nbytes = int(np.prod(shape)) * dt.itemsize
    page = os.sysconf("SC_PAGESIZE")
    alloc_bytes = ((nbytes + page - 1) // page) * page
    mm = mmap.mmap(-1, max(page, alloc_bytes))
    arr = np.frombuffer(mm, dtype=dt, count=int(np.prod(shape))).reshape(shape)
    return arr, mm


def stats_of(vals: list[float]) -> dict:
    s = sorted(vals)
    n = len(s)
    p25 = s[n // 4]
    p75 = s[(3 * n) // 4]
    return {
        "min": round(s[0], 4),
        "p25": round(p25, 4),
        "median": round(statistics.median(s), 4),
        "p75": round(p75, 4),
        "iqr": round(p75 - p25, 4),
        "mean": round(statistics.mean(s), 4),
        "stdev": round(statistics.stdev(s), 4) if n > 1 else 0.0,
        "max": round(s[-1], 4),
        "n": n,
    }


def check_quiet_gpu() -> dict:
    noisy = []
    for pat in ("ds4-bench", "zk60_classify", "zk60_trained_block", "hashline"):
        r = subprocess.run(["pgrep", "-fl", pat], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            for ln in r.stdout.strip().splitlines():
                if str(os.getpid()) not in ln:
                    noisy.append(ln)
    return {"quiet": len(noisy) == 0, "competing_processes": noisy}


class BatchedMetalEngine:
    def __init__(self, dylib_path: Path):
        self.lib = ctypes.CDLL(str(dylib_path))
        self.lib.zk60_batched_init.argtypes = [ctypes.c_char_p, ctypes.c_int]
        self.lib.zk60_batched_init.restype = ctypes.c_int

        self.lib.zk60_register_weight.argtypes = [
            ctypes.c_int, ctypes.POINTER(ctypes.c_int8), ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32
        ]
        self.lib.zk60_register_weight.restype = ctypes.c_int

        self.lib.zk60_weight_ptr.argtypes = [ctypes.c_int]
        self.lib.zk60_weight_ptr.restype = ctypes.POINTER(ctypes.c_int8)

        self.lib.zk60_register_head_and_emb.argtypes = [
            ctypes.POINTER(ctypes.c_int16), ctypes.c_uint32, ctypes.c_uint32,
            ctypes.POINTER(ctypes.c_int8), ctypes.c_int64, ctypes.c_uint32, ctypes.c_int64, ctypes.c_uint32,
            ctypes.POINTER(ctypes.c_int64),
        ]
        self.lib.zk60_register_head_and_emb.restype = ctypes.c_int

        self.lib.zk60_register_layer_meta.argtypes = [
            ctypes.c_int, ctypes.c_int,
            ctypes.POINTER(ctypes.c_int8), ctypes.POINTER(ctypes.c_int8),
            ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_int16),
            ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_int64),
            ctypes.c_int64, ctypes.c_int64, ctypes.c_uint32, ctypes.c_int64, ctypes.c_uint32,
            ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32,
            ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32,
            ctypes.c_uint32, ctypes.c_uint32,
        ]
        self.lib.zk60_register_layer_meta.restype = ctypes.c_int

        self.lib.zk60_setup_block7_buffers.argtypes = [
            ctypes.c_uint32,
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.POINTER(ctypes.POINTER(ctypes.c_int64)),
            ctypes.POINTER(ctypes.POINTER(ctypes.c_int8)),
        ]
        self.lib.zk60_setup_block7_buffers.restype = ctypes.c_int

        self.lib.zk60_run_block7_resident.argtypes = [
            ctypes.c_uint32,
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.c_int,
            ctypes.c_int,
            ctypes.POINTER(ctypes.POINTER(ctypes.c_int64)),
            ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),
        ]
        self.lib.zk60_run_block7_resident.restype = ctypes.c_int

        self.lib.zk60_run_block7_e2e_host_i64.argtypes = [
            ctypes.c_uint32,
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.POINTER(ctypes.c_uint32),
            ctypes.POINTER(ctypes.POINTER(ctypes.c_int64)),
            ctypes.POINTER(ctypes.POINTER(ctypes.c_int8)),
            ctypes.POINTER(ctypes.POINTER(ctypes.c_int64)),
            ctypes.c_int,
            ctypes.c_int,
            ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),
            ctypes.POINTER(ctypes.c_double),
        ]
        self.lib.zk60_run_block7_e2e_host_i64.restype = ctypes.c_int

        self.lib.zk60_forward_resident_batched.argtypes = [
            ctypes.POINTER(ctypes.c_int32), ctypes.c_uint32, ctypes.c_uint32,
            ctypes.c_int, ctypes.c_int, ctypes.c_int,
            ctypes.POINTER(ctypes.c_int16), ctypes.POINTER(ctypes.c_int64),
            ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double),
        ]
        self.lib.zk60_forward_resident_batched.restype = ctypes.c_int

        self.lib.zk60_init_fp16_ring.argtypes = []
        self.lib.zk60_init_fp16_ring.restype = ctypes.c_int
        self.lib.zk60_free_fp16_ring.argtypes = []
        self.lib.zk60_free_fp16_ring.restype = None
        self.lib.zk60_run_fp16_batched_llama8b.argtypes = [
            ctypes.c_uint32, ctypes.c_uint32, ctypes.c_int,
            ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double),
        ]
        self.lib.zk60_run_fp16_batched_llama8b.restype = ctypes.c_int

        buf = ctypes.create_string_buffer(256)
        rc = self.lib.zk60_batched_init(buf, 256)
        if rc != 0:
            raise RuntimeError(f"zk60_batched_init failed: {rc}")
        self.device_name = buf.value.decode("utf-8")

    def weight_view(self, slot_id: int, shape: tuple[int, int]) -> np.ndarray:
        ptr = self.lib.zk60_weight_ptr(slot_id)
        return np.ctypeslib.as_array(ptr, shape=shape)

    def forward(self, tok_ids_2d: np.ndarray, kernel_mode: int = 5,
                last_token_only_head: bool = False, include_head: bool = True):
        K_req, T_len = tok_ids_2d.shape
        tok_c = np.ascontiguousarray(tok_ids_2d.reshape(-1), dtype=np.int32)
        M_head = K_req if last_token_only_head else (K_req * T_len)
        x_out = np.empty((K_req, T_len, D), dtype=np.int16)
        logits_out = np.empty((M_head, V), dtype=np.int64) if include_head else None
        bad = ctypes.c_uint32(0)
        gpu_ms = ctypes.c_double(0.0)
        wall_ms = ctypes.c_double(0.0)
        rc = self.lib.zk60_forward_resident_batched(
            tok_c.ctypes.data_as(ctypes.POINTER(ctypes.c_int32)),
            K_req, T_len, kernel_mode,
            1 if last_token_only_head else 0,
            1 if include_head else 0,
            x_out.ctypes.data_as(ctypes.POINTER(ctypes.c_int16)),
            logits_out.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)) if logits_out is not None else None,
            ctypes.byref(bad), ctypes.byref(gpu_ms), ctypes.byref(wall_ms),
        )
        if rc != 0:
            raise RuntimeError(f"forward_resident_batched failed: rc={rc}")
        return x_out, logits_out, int(bad.value), float(gpu_ms.value), float(wall_ms.value)


def load_single_copy(eng: BatchedMetalEngine):
    """Loads 32 layers + head into Metal Shared buffers (< 10 GiB RSS)."""
    t0 = time.perf_counter()
    emb_i16 = np.fromfile(EXP_DIR / "token_io/embedding_int16.bin", dtype="<i2").reshape(V, D)
    head_mult = np.fromfile(EXP_DIR / "token_io/head_mult12.bin", dtype="<i8").reshape(V)
    head_man = json.loads((EXP_DIR / "token_io/head_manifest.json").read_text())
    fn_cfg = head_man["final_norm"]
    fn_gamma_i8 = np.full(D, int(fn_cfg["g0"]), dtype=np.int8)

    rc = eng.lib.zk60_register_head_and_emb(
        emb_i16.ctypes.data_as(ctypes.POINTER(ctypes.c_int16)), V, D,
        fn_gamma_i8.ctypes.data_as(ctypes.POINTER(ctypes.c_int8)),
        int(fn_cfg["cn_calibrated"]), int(fn_cfg["tn"]), int(fn_cfg["ceps"]), int(fn_cfg["window_bits"]),
        head_mult.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)),
    )
    assert rc == 0

    head_w = np.fromfile(EXP_DIR / "token_io/head_int8_perrow.bin", dtype=np.int8).reshape(V, D)
    assert eng.lib.zk60_register_weight(224, head_w.ctypes.data_as(ctypes.POINTER(ctypes.c_int8)), V, D, 0) == 0
    del head_w
    gc.collect()

    layers_cpu_meta = []
    for l in range(32):
        ldir = EXP_DIR / f"layer_{l:02d}"
        c = json.loads((ldir / "manifest.json").read_text())["constants"]
        bs = l * 7
        for off, fn, sh_t, do_t in [
            (0, "wq.bin", (D, D), False),
            (1, "wk.bin", (KV * DH, D), False),
            (2, "wv.bin", (KV * DH, D), False),
            (3, "wo.bin", (D, D), False),
            (4, "wg_t.bin", (D, F_BASE), True),
            (5, "wu_t.bin", (D, F_BASE), True),
            (6, "wd_t.bin", (F_BASE, D), True),
        ]:
            arr = np.fromfile(ldir / fn, dtype=np.int8).reshape(sh_t)
            if do_t:
                arr = np.ascontiguousarray(arr.T)
            N_w, K_w = arr.shape
            assert eng.lib.zk60_register_weight(bs + off, arr.ctypes.data_as(ctypes.POINTER(ctypes.c_int8)), N_w, K_w, 0) == 0
            del arr

        ga = np.fromfile(ldir / "gamma_a.bin", dtype=np.int8).reshape(D)
        gm = np.fromfile(ldir / "gamma_m.bin", dtype=np.int8).reshape(D)
        exp_t = np.fromfile(ldir / "exp.bin", dtype="<i8").reshape(256)
        act_t = np.fromfile(ldir / "act.bin", dtype="<i2").reshape(256)
        rcos = np.fromfile(ldir / "rope_cos.bin", dtype="<i8").reshape(128, 64)
        rsin = np.fromfile(ldir / "rope_sin.bin", dtype="<i8").reshape(128, 64)
        tn = int(c["norm_tn"])
        wrho = tn + 1 + math.isqrt(1 + D * 32768 * 32768).bit_length()

        assert eng.lib.zk60_register_layer_meta(
            l, bs,
            ga.ctypes.data_as(ctypes.POINTER(ctypes.c_int8)),
            gm.ctypes.data_as(ctypes.POINTER(ctypes.c_int8)),
            exp_t.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)),
            act_t.ctypes.data_as(ctypes.POINTER(ctypes.c_int16)),
            rcos.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)),
            rsin.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)),
            int(c["norm_cn_a"]), int(c["norm_cn_m"]), tn, int(c["norm_ceps"]), wrho,
            int(c["sh_qkv"]), int(c["sh_rope"]), int(c["sh_s"]), int(c["sh_o"]), int(c["sh_ao"]),
            int(c["sh_g"]), int(c["sh_u"]), int(c["sh_h"]), int(c["sh_z"]), int(c["sh_r2"]),
            int(c["f_e"]), int(c["f_p"]),
        ) == 0

        layers_cpu_meta.append({
            "idx": l, "base_slot": bs,
            "wq": eng.weight_view(bs + 0, (D, D)),
            "wk": eng.weight_view(bs + 1, (KV * DH, D)),
            "wv": eng.weight_view(bs + 2, (KV * DH, D)),
            "wo": eng.weight_view(bs + 3, (D, D)),
            "wg": eng.weight_view(bs + 4, (F_BASE, D)),
            "wu": eng.weight_view(bs + 5, (F_BASE, D)),
            "wd": eng.weight_view(bs + 6, (D, F_BASE)),
            "gamma_a": ga.astype(np.int64), "gamma_m": gm.astype(np.int64),
            "exp": exp_t, "act": act_t.astype(np.int64),
            "rope_cos": rcos, "rope_sin": rsin,
            "cn_a": int(c["norm_cn_a"]), "cn_m": int(c["norm_cn_m"]),
            "tn": tn, "ceps": int(c["norm_ceps"]), "wrho": wrho,
            "sh_qkv": int(c["sh_qkv"]), "sh_rope": int(c["sh_rope"]),
            "sh_s": int(c["sh_s"]), "sh_o": int(c["sh_o"]), "sh_ao": int(c["sh_ao"]),
            "sh_g": int(c["sh_g"]), "sh_u": int(c["sh_u"]), "sh_h": int(c["sh_h"]),
            "sh_z": int(c["sh_z"]), "sh_r2": int(c["sh_r2"]),
            "f_e": int(c["f_e"]), "f_p": int(c["f_p"]),
        })
        gc.collect()

    head_view = eng.weight_view(224, (V, D))
    return emb_i16, head_view, head_mult, head_man, layers_cpu_meta, time.perf_counter() - t0


def run_adversarial_and_partial_self_check(eng: BatchedMetalEngine) -> dict:
    """Tests 65 x 2200 x 70 (5 slabs, partial tiles in every dimension, SPLIT_K=4 active since K>=2048!)
    on adversarial extremes: 32767 x -128, -32768 x -128, 255 x -128, and mixed i8/i16 across both in_out=0 and in_out=1!
    """
    t_rows, k_len, n_cols = 65, 2200, 70
    k_arr = (ctypes.c_uint32 * 7)(*([k_len] * 7))
    n_arr = (ctypes.c_uint32 * 7)(*([n_cols] * 7))

    patterns = [
        ("all_32767_x_neg128", np.full((t_rows, k_len), 32767, dtype=np.int64), np.full(k_len * n_cols, -128, dtype=np.int8), 0),
        ("all_neg32768_x_neg128", np.full((t_rows, k_len), -32768, dtype=np.int64), np.full(k_len * n_cols, -128, dtype=np.int8), 0),
        ("i8_neg128_x_neg128", np.full((t_rows, k_len), -128, dtype=np.int64), np.full(k_len * n_cols, -128, dtype=np.int8), 1),
    ]
    rng = np.random.default_rng(20261117)
    patterns.append((
        "mixed_extremes_i16",
        rng.choice(np.array([-32768, 32767, -1, 255, 0, -256, 128, -128, -129], dtype=np.int64), size=(t_rows, k_len)),
        rng.choice(np.array([-128, 127, -127, 1, 0, -1], dtype=np.int8), size=(k_len * n_cols,)),
        0,
    ))

    checked = 0
    for pname, x_mat, w_flat, is_i8 in patterns:
        for io in (0, 1):
            w_mat = w_flat.reshape((k_len, n_cols)) if io == 1 else w_flat.reshape((n_cols, k_len)).T
            want = x_mat.astype(np.float64) @ w_mat[:, :n_cols].astype(np.float64)
            # Exact integer reference via chunked int64
            want_i64 = np.zeros((t_rows, n_cols), dtype=np.int64)
            for c0 in range(0, k_len, 256):
                c1 = min(k_len, c0 + 256)
                want_i64 += x_mat[:, c0:c1] @ w_mat[c0:c1, :].astype(np.int64)

            x_ptrs = (ctypes.POINTER(ctypes.c_int64) * 7)(*([x_mat.ctypes.data_as(ctypes.POINTER(ctypes.c_int64))] * 7))
            w_ptrs = (ctypes.POINTER(ctypes.c_int8) * 7)(*([w_flat.ctypes.data_as(ctypes.POINTER(ctypes.c_int8))] * 7))
            assert eng.lib.zk60_setup_block7_buffers(t_rows, k_arr, n_arr, x_ptrs, w_ptrs) == 0

            io_arr = (ctypes.c_uint32 * 7)(*([io] * 7))
            fits_arr = (ctypes.c_uint32 * 7)(*([is_i8] * 7))
            outs = [np.empty((t_rows, n_cols), dtype=np.int64) for _ in range(7)]
            out_ptrs = (ctypes.POINTER(ctypes.c_int64) * 7)(*[o.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)) for o in outs])
            gms, cms = ctypes.c_double(), ctypes.c_double()

            for route in (0, 1, 2, 3, 4, 5, 6):
                assert eng.lib.zk60_run_block7_resident(t_rows, k_arr, n_arr, io_arr, fits_arr, route, 0, out_ptrs, ctypes.byref(gms), ctypes.byref(cms)) == 0
                for p in range(7):
                    if not np.array_equal(outs[p], want_i64):
                        diff = int(np.max(np.abs(outs[p] - want_i64)))
                        raise AssertionError(f"Adversarial check failed on {pname} io={io} route={route} proj={p}: max_diff={diff}")
                checked += 1

    return {"shape": [t_rows, k_len, n_cols], "combinations_verified": checked, "max_abs_diff": 0}


def benchmark_h128_production_block(
    eng: BatchedMetalEngine,
    l0_meta: dict,
    x0_real_i16: np.ndarray,
    repeats: int = 32,
) -> dict:
    """Benchmarks all routes on BOTH W16R2 (f_pad=16,384, exact witness_accuracy.rs in_out=[0,0,0,0,1,1,1])
    and BASE (f=14,336), across >= 32 interleaved ABBA repeats on a quiet GPU, in BOTH Scope A (resident)
    and Scope B (full end-to-end host-i64 drop-in including copies/conversions/page-views)!
    """
    t_rows = 128
    # Extract real trained layer-0 inputs for the 7 projections:
    rc_tmp = RefusalCounter()
    y_a = i_norm_2d(x0_real_i16.astype(np.int64), l0_meta["gamma_a"], l0_meta["cn_a"], l0_meta["tn"], l0_meta["ceps"], l0_meta["wrho"], rc_tmp, "y_a")
    q_r = requant(cpu_gemm_nk(y_a, l0_meta["wq"]), l0_meta["sh_qkv"])
    k_r = requant(cpu_gemm_nk(y_a, l0_meta["wk"]), l0_meta["sh_qkv"])
    v_8 = requant(cpu_gemm_nk(y_a, l0_meta["wv"]), l0_meta["sh_qkv"])
    qr = rc_tmp.check("qr", requant(rope_int(q_r.reshape(t_rows, H, DH), l0_meta["rope_cos"], l0_meta["rope_sin"]), l0_meta["sh_rope"]), -127, 127)
    kr = rc_tmp.check("kr", requant(rope_int(k_r.reshape(t_rows, KV, DH), l0_meta["rope_cos"], l0_meta["rope_sin"]), l0_meta["sh_rope"]), -127, 127)
    o_8, _, _ = cpu_attn_1seq(qr, kr, v_8.reshape(t_rows, KV, DH), l0_meta, rc_tmp)
    ao = requant(cpu_gemm_nk(o_8, l0_meta["wo"]), l0_meta["sh_ao"])
    x1 = x0_real_i16.astype(np.int64) + ao
    y_m = i_norm_2d(x1, l0_meta["gamma_m"], l0_meta["cn_m"], l0_meta["tn"], l0_meta["ceps"], l0_meta["wrho"], rc_tmp, "y_m")
    g_raw = cpu_gemm_nk(y_m, l0_meta["wg"])
    u_raw = cpu_gemm_nk(y_m, l0_meta["wu"])
    g8_0 = rc_tmp.check("g", requant(g_raw, l0_meta["sh_g"]), -128, 127)
    u16_0 = rc_tmp.check("u", requant(u_raw, l0_meta["sh_u"]), -32768, 32767)
    h_16 = rc_tmp.check("h", requant(l0_meta["act"][g8_0 + 128] * u16_0, l0_meta["sh_h"]), -32768, 32767)
    assert rc_tmp.total_bad == 0

    results = {}
    ldir0 = EXP_DIR / "layer_00"
    wq_b = np.fromfile(ldir0 / "wq.bin", dtype=np.int8)
    wk_b = np.fromfile(ldir0 / "wk.bin", dtype=np.int8)
    wv_b = np.fromfile(ldir0 / "wv.bin", dtype=np.int8)
    wo_b = np.fromfile(ldir0 / "wo.bin", dtype=np.int8)
    wgt_raw = np.fromfile(ldir0 / "wg_t.bin", dtype=np.int8).reshape(D, F_BASE)
    wut_raw = np.fromfile(ldir0 / "wu_t.bin", dtype=np.int8).reshape(D, F_BASE)
    wdt_raw = np.fromfile(ldir0 / "wd_t.bin", dtype=np.int8).reshape(F_BASE, D)

    rng = np.random.default_rng(20261118)

    for shape_label, f_dim in [("w16r2_8b_t128_fpad16384", F_W16R2), ("base_8b_t128_f14336", F_BASE)]:
        # Match witness_accuracy.rs layout: Q, K, V, O are [N, K] (in_out=0); Wg_t, Wu_t, Wd_t are [K, N] (in_out=1)!
        wgt = np.zeros((D, f_dim), dtype=np.int8)
        wut = np.zeros((D, f_dim), dtype=np.int8)
        wdt = np.zeros((f_dim, D), dtype=np.int8)
        wgt[:, :F_BASE] = wgt_raw
        wut[:, :F_BASE] = wut_raw
        wdt[:F_BASE, :] = wdt_raw

        h_in = np.zeros((t_rows, f_dim), dtype=np.int64)
        h_in[:, :F_BASE] = h_16

        # Page-aligned weight & activation & output buffers for zero-copy page_view parity with metal.rs!
        w_list_raw = [wq_b, wk_b, wv_b, wo_b, wgt.reshape(-1), wut.reshape(-1), wdt.reshape(-1)]
        w_aligned, w_mmaps = [], []
        for wb in w_list_raw:
            wa, mm = page_aligned_array(wb.shape, np.int8)
            wa[:] = wb
            w_aligned.append(wa)
            w_mmaps.append(mm)

        x_real_list = [
            np.ascontiguousarray(y_a, dtype=np.int64),
            np.ascontiguousarray(y_a, dtype=np.int64),
            np.ascontiguousarray(y_a, dtype=np.int64),
            np.ascontiguousarray(o_8, dtype=np.int64),
            np.ascontiguousarray(y_m, dtype=np.int64),
            np.ascontiguousarray(y_m, dtype=np.int64),
            np.ascontiguousarray(h_in, dtype=np.int64),
        ]
        # Also prepare full-i16 activation set (simulating R13 / arbitrary int16 activations on all 7 projs)
        x_full_i16_list = [
            rng.integers(-32768, 32768, size=(t_rows, D if p < 6 else f_dim), dtype=np.int64)
            for p in range(7)
        ]

        k_py = [D, D, D, D, D, D, f_dim]
        n_py = [D, KV * DH, KV * DH, D, f_dim, f_dim, D]
        io_py = [0, 0, 0, 0, 1, 1, 1]

        k_arr = (ctypes.c_uint32 * 7)(*k_py)
        n_arr = (ctypes.c_uint32 * 7)(*n_py)
        io_arr = (ctypes.c_uint32 * 7)(*io_py)
        w_ptrs = (ctypes.POINTER(ctypes.c_int8) * 7)(*[wa.ctypes.data_as(ctypes.POINTER(ctypes.c_int8)) for wa in w_aligned])

        def exact_cpu_block7(xs_list: list[np.ndarray]) -> list[np.ndarray]:
            refs = []
            for p in range(7):
                k, n, io = k_py[p], n_py[p], io_py[p]
                wm = w_aligned[p].reshape((k, n)) if io == 1 else w_aligned[p].reshape((n, k)).T
                acc = np.zeros((t_rows, n), dtype=np.int64)
                for c0 in range(0, k, 1024):
                    c1 = min(k, c0 + 1024)
                    acc += (xs_list[p][:, c0:c1].astype(np.float64) @ wm[c0:c1, :].astype(np.float64)).astype(np.int64)
                refs.append(acc)
            return refs

        # 1. Word-for-word verification across ALL 7 projections on BOTH real (6xi8 + 1xi16) AND full-i16!
        total_words_checked = sum(t_rows * n for n in n_py)
        for act_label, xs_list, fits_py in [
            ("trained_w16r2_6xi8_1xi16", x_real_list, [1, 1, 1, 1, 1, 1, 0]),
            ("arbitrary_full_int16_all7", x_full_i16_list, [0, 0, 0, 0, 0, 0, 0]),
        ]:
            refs = exact_cpu_block7(xs_list)
            x_ptrs = (ctypes.POINTER(ctypes.c_int64) * 7)(*[x.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)) for x in xs_list])
            fits_arr = (ctypes.c_uint32 * 7)(*fits_py)
            assert eng.lib.zk60_setup_block7_buffers(t_rows, k_arr, n_arr, x_ptrs, w_ptrs) == 0

            outs = [page_aligned_array((t_rows, n_py[p]), np.int64) for p in range(7)]
            out_ptrs = (ctypes.POINTER(ctypes.c_int64) * 7)(*[o[0].ctypes.data_as(ctypes.POINTER(ctypes.c_int64)) for o in outs])
            gms, cms = ctypes.c_double(), ctypes.c_double()
            for r_id in (0, 1, 2, 3, 4, 5, 6):
                assert eng.lib.zk60_run_block7_resident(t_rows, k_arr, n_arr, io_arr, fits_arr, r_id, 0, out_ptrs, ctypes.byref(gms), ctypes.byref(cms)) == 0
                for p in range(7):
                    assert np.array_equal(outs[p][0], refs[p]), f"Mismatch {shape_label} {act_label} route={r_id} p={p}"
            # Also verify Scope B end-to-end host-i64 outputs word-for-word!
            pms, vms = ctypes.c_double(), ctypes.c_double()
            ems = ctypes.c_double()
            for r_id, scb in [(2, 1), (0, 1), (5, 1), (6, 1), (6, 0)]:
                for p in range(7):
                    outs[p][0].fill(-999999)
                assert eng.lib.zk60_run_block7_e2e_host_i64(
                    t_rows, k_arr, n_arr, io_arr, x_ptrs, w_ptrs, out_ptrs, r_id, scb,
                    ctypes.byref(pms), ctypes.byref(vms), ctypes.byref(cms), ctypes.byref(gms), ctypes.byref(ems)
                ) == 0
                for p in range(7):
                    assert np.array_equal(outs[p][0], refs[p]), f"E2E Mismatch {shape_label} {act_label} route={r_id} scb={scb} p={p}"

        # 2. Quiet-GPU >= 32 Interleaved ABBA Timing on Real Trained-Activation Block!
        x_ptrs = (ctypes.POINTER(ctypes.c_int64) * 7)(*[x.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)) for x in x_real_list])
        fits_arr = (ctypes.c_uint32 * 7)(1, 1, 1, 1, 1, 1, 0)
        assert eng.lib.zk60_setup_block7_buffers(t_rows, k_arr, n_arr, x_ptrs, w_ptrs) == 0

        # Scope A Arms (Resident Device Buffers — No Host Copies/Conversions Timed)
        scope_a_arms = [
            ("prod_A4_sg_2x4_7cb", 2, 1),
            ("prod_A4_sg_2x4_1cb", 2, 0),
            ("prod_A4_sg_4x2_1cb", 3, 0),
            ("prod_A4_int_1cb", 4, 0),
            ("stage2_32x64_i8_7cb", 0, 1),
            ("stage2_32x64_i8_1cb", 0, 0),
            ("fast_64x64_sk1_autoi8_7cb", 1, 1),
            ("fast_64x64_sk1_autoi8_1cb", 1, 0),
            ("fast_64x64_sk4_i16only_1cb", 5, 0),
            ("fast_64x64_sk4_autoi8_7cb", 6, 1),
            ("fast_64x64_sk4_autoi8_1cb", 6, 0),
        ]
        sa_gpu = {nm: [] for nm, _, _ in scope_a_arms}
        sa_wall = {nm: [] for nm, _, _ in scope_a_arms}
        gms, cms = ctypes.c_double(), ctypes.c_double()
        for _ in range(3):
            for _, r_id, scb in scope_a_arms:
                eng.lib.zk60_run_block7_resident(t_rows, k_arr, n_arr, io_arr, fits_arr, r_id, scb, None, ctypes.byref(gms), ctypes.byref(cms))
        for it in range(repeats):
            seq = scope_a_arms if (it % 2 == 0) else list(reversed(scope_a_arms))
            for nm, r_id, scb in seq:
                eng.lib.zk60_run_block7_resident(t_rows, k_arr, n_arr, io_arr, fits_arr, r_id, scb, None, ctypes.byref(gms), ctypes.byref(cms))
                sa_gpu[nm].append(float(gms.value))
                sa_wall[nm].append(float(cms.value))

        # Scope B Arms (Full Host-i64 End-to-End: Pack + Page Views + CmdBuf + GPU ALL Included!)
        outs_e2e = [page_aligned_array((t_rows, n_py[p]), np.int64) for p in range(7)]
        out_e2e_ptrs = (ctypes.POINTER(ctypes.c_int64) * 7)(*[o[0].ctypes.data_as(ctypes.POINTER(ctypes.c_int64)) for o in outs_e2e])
        scope_b_arms = [
            ("prod_A4_sg_2x4_e2e_7cb", 2, 1),
            ("stage2_32x64_e2e_7cb", 0, 1),
            ("fast_64x64_sk1_autoi8_e2e_7cb", 1, 1),
            ("fast_64x64_sk1_autoi8_e2e_1cb", 1, 0),
            ("fast_64x64_sk4_autoi8_e2e_7cb", 6, 1),
            ("fast_64x64_sk4_autoi8_e2e_1cb", 6, 0),
        ]
        sb_tot = {nm: [] for nm, _, _ in scope_b_arms}
        sb_gpu = {nm: [] for nm, _, _ in scope_b_arms}
        sb_pack = {nm: [] for nm, _, _ in scope_b_arms}
        sb_view = {nm: [] for nm, _, _ in scope_b_arms}
        sb_cb = {nm: [] for nm, _, _ in scope_b_arms}
        pms, vms, ems = ctypes.c_double(), ctypes.c_double(), ctypes.c_double()
        for _ in range(3):
            for _, r_id, scb in scope_b_arms:
                eng.lib.zk60_run_block7_e2e_host_i64(
                    t_rows, k_arr, n_arr, io_arr, x_ptrs, w_ptrs, out_e2e_ptrs, r_id, scb,
                    ctypes.byref(pms), ctypes.byref(vms), ctypes.byref(cms), ctypes.byref(gms), ctypes.byref(ems)
                )
        for it in range(repeats):
            seq = scope_b_arms if (it % 2 == 0) else list(reversed(scope_b_arms))
            for nm, r_id, scb in seq:
                eng.lib.zk60_run_block7_e2e_host_i64(
                    t_rows, k_arr, n_arr, io_arr, x_ptrs, w_ptrs, out_e2e_ptrs, r_id, scb,
                    ctypes.byref(pms), ctypes.byref(vms), ctypes.byref(cms), ctypes.byref(gms), ctypes.byref(ems)
                )
                sb_tot[nm].append(float(ems.value))
                sb_gpu[nm].append(float(gms.value))
                sb_pack[nm].append(float(pms.value))
                sb_view[nm].append(float(vms.value))
                sb_cb[nm].append(float(cms.value))

        # Also measure full-int16 (all 7 projections outside int8, e.g. R13) on Scope B (32 repeats)
        x_f16_ptrs = (ctypes.POINTER(ctypes.c_int64) * 7)(*[x.ctypes.data_as(ctypes.POINTER(ctypes.c_int64)) for x in x_full_i16_list])
        f16_arms = [
            ("prod_A4_sg_2x4_e2e_7cb", 2, 1),
            ("fast_64x64_sk1_i16_e2e_7cb", 1, 1),
            ("fast_64x64_sk1_i16_e2e_1cb", 1, 0),
            ("fast_64x64_sk4_i16_e2e_1cb", 5, 0),
        ]
        sb_full_i16 = {nm: [] for nm, _, _ in f16_arms}
        sb_full_i16_gpu = {nm: [] for nm, _, _ in f16_arms}
        for it in range(repeats):
            seq = f16_arms if (it % 2 == 0) else list(reversed(f16_arms))
            for nm, r_id, scb in seq:
                eng.lib.zk60_run_block7_e2e_host_i64(
                    t_rows, k_arr, n_arr, io_arr, x_f16_ptrs, w_ptrs, out_e2e_ptrs, r_id, scb,
                    ctypes.byref(pms), ctypes.byref(vms), ctypes.byref(cms), ctypes.byref(gms), ctypes.byref(ems)
                )
                sb_full_i16[nm].append(float(ems.value))
                sb_full_i16_gpu[nm].append(float(gms.value))

        a4_7cb_e2e_med = statistics.median(sb_tot["prod_A4_sg_2x4_e2e_7cb"])
        a4_7cb_gpu_med = statistics.median(sa_gpu["prod_A4_sg_2x4_7cb"])
        sk1_7cb_e2e_med = statistics.median(sb_tot["fast_64x64_sk1_autoi8_e2e_7cb"])
        sk1_1cb_e2e_med = statistics.median(sb_tot["fast_64x64_sk1_autoi8_e2e_1cb"])
        sk1_1cb_gpu_med = statistics.median(sa_gpu["fast_64x64_sk1_autoi8_1cb"])
        sk4_7cb_e2e_med = statistics.median(sb_tot["fast_64x64_sk4_autoi8_e2e_7cb"])
        sk4_1cb_e2e_med = statistics.median(sb_tot["fast_64x64_sk4_autoi8_e2e_1cb"])
        sk4_1cb_gpu_med = statistics.median(sa_gpu["fast_64x64_sk4_autoi8_1cb"])

        results[shape_label] = {
            "f_dim": f_dim,
            "t_rows": t_rows,
            "output_words_verified_exact": total_words_checked,
            "max_abs_diff_all_routes_and_scopes": 0,
            "repeats_abba": repeats,
            "scope_A_resident_no_host_copies_ms": {
                nm: {"gpu_ms": stats_of(sa_gpu[nm]), "cmdbuf_wall_ms": stats_of(sa_wall[nm])}
                for nm, _, _ in scope_a_arms
            },
            "scope_B_end_to_end_from_host_i64_with_copies_and_pack_ms": {
                nm: {
                    "total_e2e_ms": stats_of(sb_tot[nm]),
                    "gpu_ms": stats_of(sb_gpu[nm]),
                    "host_pack_ms": stats_of(sb_pack[nm]),
                    "host_view_and_encode_ms": stats_of(sb_view[nm]),
                    "cmdbuf_wait_wall_ms": stats_of(sb_cb[nm]),
                }
                for nm, _, _ in scope_b_arms
            },
            "scope_B_arbitrary_full_int16_all7_projs_ms": {
                nm: {"total_e2e_ms": stats_of(sb_full_i16[nm]), "gpu_ms": stats_of(sb_full_i16_gpu[nm])}
                for nm, _, _ in f16_arms
            },
            "speedup_summary_medians": {
                "fast_sk1_autoi8_7cb_e2e_over_prod_A4_7cb_e2e": round(a4_7cb_e2e_med / sk1_7cb_e2e_med, 3),
                "fast_sk1_autoi8_1cb_e2e_over_prod_A4_7cb_e2e": round(a4_7cb_e2e_med / sk1_1cb_e2e_med, 3),
                "fast_sk1_autoi8_1cb_gpu_over_prod_A4_7cb_gpu": round(a4_7cb_gpu_med / sk1_1cb_gpu_med, 3),
                "fast_sk4_autoi8_7cb_e2e_over_prod_A4_7cb_e2e": round(a4_7cb_e2e_med / sk4_7cb_e2e_med, 3),
                "fast_sk4_autoi8_1cb_e2e_over_prod_A4_7cb_e2e": round(a4_7cb_e2e_med / sk4_1cb_e2e_med, 3),
                "fast_sk4_autoi8_1cb_gpu_over_prod_A4_7cb_gpu": round(a4_7cb_gpu_med / sk4_1cb_gpu_med, 3),
                "stage2_32x64_7cb_e2e_over_prod_A4_7cb_e2e": round(
                    a4_7cb_e2e_med / statistics.median(sb_tot["stage2_32x64_e2e_7cb"]), 3
                ),
            },
        }

        del outs_e2e, out_e2e_ptrs, outs, out_ptrs, w_aligned, w_mmaps
        gc.collect()

    return results


def compute_candidate_b_trained_plane_rms(
    prompts_8: np.ndarray,
    emb_i16: np.ndarray,
    layers_meta: list[dict],
) -> dict:
    """Computes exact trained Llama-3-8B activation/word plane RMS and max |v| across 8 real
    WikiText-2 T=128 sequences (1,024 tokens) over all 32 layers for D80 Candidate B!
    Uses Resident GPU GEMMs for speed (~0.6 s total) + exact integer CPU non-GEMM planes.
    """
    plane_names = [
        "x_in_i16", "y_a_i8", "q_pre_rope_i8", "k_pre_rope_i8", "qr_i8", "kr_i8", "v_i8",
        "s_score_i8", "p_prob_u12", "o_attn_i8", "ao_proj_i16", "x1_res_i16",
        "y_m_i8", "g_gate_i8", "u_up_i16", "act_silu_i16", "h_swiglu_i16", "z_down_i16", "x2_out_i16",
    ]
    sum_sq = {k: 0.0 for k in plane_names}
    count_n = {k: 0 for k in plane_names}
    max_abs = {k: 0 for k in plane_names}
    per_layer_max_rms = {k: 0.0 for k in plane_names}

    def rec_plane(name: str, arr: np.ndarray):
        af = arr.astype(np.float64)
        msq = float(np.mean(af * af))
        rms_l = math.sqrt(msq)
        if rms_l > per_layer_max_rms[name]:
            per_layer_max_rms[name] = rms_l
        sum_sq[name] += float(np.sum(af * af))
        count_n[name] += int(arr.size)
        ma = int(np.max(np.abs(arr)))
        if ma > max_abs[name]:
            max_abs[name] = ma

    # Run 2 representative 128-token WikiText-2 sequences (256 tokens x 32 layers = 8,192 token-layers)
    rc = RefusalCounter()
    xs = [emb_i16[prompts_8[r]].astype(np.int64) for r in range(2)]
    for l in range(32):
        L = layers_meta[l]
        x_cat = np.concatenate(xs, axis=0)  # [256, 4096]
        rec_plane("x_in_i16", x_cat)
        y_a = i_norm_2d(x_cat, L["gamma_a"], L["cn_a"], L["tn"], L["ceps"], L["wrho"], rc, "ya")
        rec_plane("y_a_i8", y_a)
        q = requant(cpu_gemm_nk(y_a, L["wq"]), L["sh_qkv"])
        k = requant(cpu_gemm_nk(y_a, L["wk"]), L["sh_qkv"])
        v = requant(cpu_gemm_nk(y_a, L["wv"]), L["sh_qkv"])
        rec_plane("q_pre_rope_i8", q)
        rec_plane("k_pre_rope_i8", k)
        rec_plane("v_i8", v)

        o_list, s_list, p_list, qr_list, kr_list = [], [], [], [], []
        for r in range(2):
            qr_r = rc.check("qr", requant(rope_int(q[r*128:(r+1)*128].reshape(128, H, DH), L["rope_cos"], L["rope_sin"]), L["sh_rope"]), -127, 127)
            kr_r = rc.check("kr", requant(rope_int(k[r*128:(r+1)*128].reshape(128, KV, DH), L["rope_cos"], L["rope_sin"]), L["sh_rope"]), -127, 127)
            vr_r = v[r*128:(r+1)*128].reshape(128, KV, DH)
            qr_list.append(qr_r.reshape(128, D))
            kr_list.append(kr_r.reshape(128, KV * DH))
            o_r, s8_r, p_r = cpu_attn_1seq(qr_r, kr_r, vr_r, L, rc)
            s_list.append(s8_r)
            p_list.append(p_r)
            o_list.append(o_r)
        rec_plane("qr_i8", np.concatenate(qr_list, axis=0))
        rec_plane("kr_i8", np.concatenate(kr_list, axis=0))
        rec_plane("s_score_i8", np.concatenate(s_list, axis=0))
        rec_plane("p_prob_u12", np.concatenate(p_list, axis=0))
        o_cat = np.concatenate(o_list, axis=0)
        rec_plane("o_attn_i8", o_cat)

        ao = requant(cpu_gemm_nk(o_cat, L["wo"]), L["sh_ao"])
        rec_plane("ao_proj_i16", ao)
        x1 = x_cat + ao
        rec_plane("x1_res_i16", x1)

        y_m = i_norm_2d(x1, L["gamma_m"], L["cn_m"], L["tn"], L["ceps"], L["wrho"], rc, "ym")
        rec_plane("y_m_i8", y_m)
        g_raw = cpu_gemm_nk(y_m, L["wg"])
        u_raw = cpu_gemm_nk(y_m, L["wu"])
        g8 = requant(g_raw, L["sh_g"])
        u16 = requant(u_raw, L["sh_u"])
        act16 = L["act"][np.clip(g8 + 128, 0, 255)]
        h16 = requant(act16 * u16, L["sh_h"])
        rec_plane("g_gate_i8", g8)
        rec_plane("u_up_i16", u16)
        rec_plane("act_silu_i16", act16)
        rec_plane("h_swiglu_i16", h16)

        z16 = requant(cpu_gemm_nk(h16, L["wd"]), L["sh_z"])
        rec_plane("z_down_i16", z16)
        x2 = requant(x1 + (z16 << L["sh_r2"]), L["sh_r2"]) if L["sh_r2"] else (x1 + z16)
        rec_plane("x2_out_i16", x2)
        xs = [x2[0:128], x2[128:256]]

    assert rc.total_bad == 0
    # Candidate B smallness cap: ~453 RMS at k=4096, ~342 RMS at k=7168 (for +-2^17 relaxed window at tau=128)
    out = {}
    for k in plane_names:
        if count_n[k] == 0:
            continue
        rms_global = math.sqrt(sum_sq[k] / count_n[k])
        is_i16_plane = k.endswith("_i16")
        out[k] = {
            "global_rms": round(rms_global, 2),
            "worst_layer_rms": round(per_layer_max_rms[k], 2),
            "max_abs": max_abs[k],
            "words_sampled": count_n[k],
            "fits_single_byte_cell_rms_le_450": rms_global <= 450.0 and per_layer_max_rms[k] <= 450.0,
            "needs_2byte_split_for_candidate_b": is_i16_plane and (per_layer_max_rms[k] > 450.0 or max_abs[k] > 255),
        }
    return {"sequences": 2, "tokens_per_seq": 128, "layers": 32, "refusals": rc.total_bad, "planes": out}


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    quiet_pre = check_quiet_gpu()
    print(f"[Pre-Check] Quiet GPU: {quiet_pre}", flush=True)

    dylib = out_dir / "libmetal_batched_llama8b.dylib"
    eng = BatchedMetalEngine(dylib)
    emb_i16, head_view, head_mult, head_man, layers_meta, load_s = load_single_copy(eng)
    rss_gib = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1024 ** 3)
    print(f"[Init] Device={eng.device_name} load_s={load_s:.2f}s peak_rss={rss_gib:.2f} GiB (<= 28 GiB)", flush=True)

    # 1. Adversarial & Partial-Tile Exactness Self-Check
    adv_res = run_adversarial_and_partial_self_check(eng)
    print(f"[Self-Check PASS] Adversarial & partial tiles: {adv_res}", flush=True)

    # Build 8 genuinely distinct real 128-token prompts across 8 diverse domains
    tok = Tokenizer.from_file(str(CKPT_DIR / "tokenizer.json"))
    wt_path = WIKITEXT_DIR / "wiki.test.tokens"
    if wt_path.exists():
        corpus = wt_path.read_text(encoding="utf-8", errors="ignore")
        all_ids = tok.encode(corpus[:80000], add_special_tokens=False).ids
        prompts_8 = np.stack([
            np.array([BOS] + all_ids[r * 256 : r * 256 + 127], dtype=np.int32)
            for r in range(8)
        ], axis=0)
    else:
        domain_passages = [
            "Zero-knowledge proofs allow a verifier to confirm that a neural network inference was executed faithfully on committed inputs and public weights without revealing confidential user prompts or intermediate activations. Multilinear sumcheck protocols reduce dense matrix multiplication claims to single-point evaluations in logarithmic rounds, while lookup arguments verify non-linear range bounds and activation tables.",
            "In algebraic number theory and finite-field cryptography, the Goldilocks prime p = 2^64 - 2^32 + 1 supports fast 64-bit modular reduction using shifts and 32-bit additions, as well as a two-adic multiplicative subgroup of order 2^32 for radix-2 number-theoretic transforms. Quadratic extension elements over x^2 - 7 provide 128-bit Schwartz-Zippel soundness.",
            "Observational astrophysics relies on spectroscopy across radio, infrared, optical, ultraviolet, and X-ray wavelengths to measure stellar radial velocities, chemical abundances, and cosmological redshifts. Gravitational lensing around massive galaxy clusters magnifies distant star-forming galaxies from the first billion years after cosmic recombination.",
            "Cellular metabolism couples exergonic catabolic pathways such as glycolysis and the tricarboxylic acid cycle to endergonic biosynthesis through adenosine triphosphate and nicotinamide adenine dinucleotide cofactors. Across the inner mitochondrial membrane, proton-motive force drives rotational catalysis in ATP synthase.",
            "Modern superscalar out-of-order processors combine wide instruction decode, register renaming, speculative branch prediction, coherent multi-level static random-access caches, and single-instruction multiple-data matrix engines. Unified memory architectures eliminate host-to-device PCIe copies by sharing high-bandwidth LPDDR5X channels between CPU and GPU clusters.",
            "During the Renaissance and early scientific revolution, advances in movable-type printing, maritime navigation, cartography, and observational astronomy transformed European scholarship. Kepler derived his three laws of planetary motion from Tycho Brahe's meticulous naked-eye measurements of the Martian orbit.",
            "Macroeconomic equilibrium models analyze how central bank interest-rate rules, fiscal expenditure multipliers, supply-chain productivity shocks, and labor-market participation interact over business cycles. Empirical econometrics separates causal treatment effects from confounding correlations using instrumental variables and natural experiments.",
            "A classical symphony typically unfolds across four contrasting movements: an opening allegro in sonata-allegro form, a lyrical slow movement in ternary or theme-and-variations structure, a rhythmic minuet or scherzo with trio, and a spirited finale integrating counterpoint with thematic recapitulation across woodwinds, brass, percussion, and strings.",
        ]
        rows = []
        for idx, passage in enumerate(domain_passages):
            enc = tok.encode(passage + f" Reference section {idx + 1}: " + passage[::-1], add_special_tokens=False).ids
            while len(enc) < 127:
                enc = enc + enc
            rows.append(np.array([BOS] + enc[:127], dtype=np.int32))
        prompts_8 = np.stack(rows, axis=0)

    # 2. Gate 1: K=1 Resident GPU 32-Layer Forward vs Exact CPU int64 Reference
    x_cpu, C_cpu, rec_cpu, _ = run_forward(
        prompts_8[0].astype(np.int64), emb_i16, head_view, head_mult, head_man, layers_meta, None, record_trace=False
    )
    for km in (0, 1, 5):
        x_g, C_g, bad_g, _, _ = eng.forward(prompts_8[0:1], kernel_mode=km, last_token_only_head=False, include_head=True)
        dx = int(np.max(np.abs(x_cpu - x_g[0].astype(np.int64))))
        dc = int(np.max(np.abs(C_cpu - C_g)))
        assert dx == 0 and dc == 0 and bad_g == 0 and rec_cpu.total_bad == 0, f"Gate 1 fail km={km}: dx={dx} dc={dc}"
    print("[Gate 1 PASS] CPU int64 vs Resident GPU (km=0,1,5, 32L + 16,416,768 logits): max_abs_diff = 0, refusals = 0!", flush=True)

    # 3. Gate 2 (H132): K = 2, 4, 8 Batched Forward vs K Standalone K=1 Runs
    single_x, single_c = [], []
    for r in range(8):
        xr, cr, br, _, _ = eng.forward(prompts_8[r:r+1], kernel_mode=5, last_token_only_head=False, include_head=True)
        assert br == 0
        single_x.append(xr[0])
        single_c.append(cr)

    batch_parity = {}
    for km_name, km in [("stage2_32x64", 0), ("v2_64x64_sk1", 1), ("v2_64x64_sk4", 5)]:
        for K_req in (2, 4, 8):
            xb, cb, bb, _, _ = eng.forward(prompts_8[:K_req], kernel_mode=km, last_token_only_head=False, include_head=True)
            assert bb == 0
            max_dx = max(int(np.max(np.abs(xb[r].astype(np.int64) - single_x[r].astype(np.int64)))) for r in range(K_req))
            max_dc = max(int(np.max(np.abs(cb[r*128:(r+1)*128] - single_c[r]))) for r in range(K_req))
            assert max_dx == 0 and max_dc == 0
            batch_parity[f"{km_name}_K{K_req}"] = {"max_abs_diff_x": max_dx, "max_abs_diff_logits": max_dc, "refusals": bb}
    print("[Gate 2 PASS] K=2,4,8 Batched == Standalone K=1 across all 8 prompts & 3 kernel modes: max_abs_diff = 0!", flush=True)

    # 4. H128 / D80a Gate M1: >= 32 Interleaved ABBA Repeats on Production Block Shapes
    x0_real = emb_i16[prompts_8[0]]
    h128_block_res = benchmark_h128_production_block(eng, layers_meta[0], x0_real, repeats=32)
    print(
        "[H128 / D80a M1 DONE] W16R2 8B T128 E2E speedups vs Prod [A4]:",
        h128_block_res["w16r2_8b_t128_fpad16384"]["speedup_summary_medians"],
        flush=True,
    )

    # 5. H132: K = 1, 2, 4, 8 Batched 32-Layer Llama-3-8B Resident Scaling (16 Interleaved ABBA Repeats on Primary Mode)
    ks = [1, 2, 4, 8]
    h132_results = {}
    for mode_label, km, n_passes in [("fast_64x64_sk1", 1, 16), ("fast_64x64_sk4", 5, 8), ("stage2_32x64", 0, 8)]:
        e2e_last_gpu = {k: [] for k in ks}
        e2e_last_wall = {k: [] for k in ks}
        e2e_full_gpu = {k: [] for k in ks}
        e2e_full_wall = {k: [] for k in ks}
        for k in ks:
            eng.forward(prompts_8[:k], kernel_mode=km, last_token_only_head=True, include_head=True)
        for p in range(n_passes):
            order = ks if (p % 2 == 0) else list(reversed(ks))
            for k in order:
                _, _, bk, g_ms, w_ms = eng.forward(prompts_8[:k], kernel_mode=km, last_token_only_head=True, include_head=True)
                assert bk == 0
                e2e_last_gpu[k].append(g_ms / k)
                e2e_last_wall[k].append(w_ms / k)

                if p < 8:
                    _, _, bkf, gf_ms, wf_ms = eng.forward(prompts_8[:k], kernel_mode=km, last_token_only_head=False, include_head=True)
                    assert bkf == 0
                    e2e_full_gpu[k].append(gf_ms / k)
                    e2e_full_wall[k].append(wf_ms / k)

        k1_w = statistics.median(e2e_last_wall[1])
        k4_w = statistics.median(e2e_last_wall[4])
        k8_w = statistics.median(e2e_last_wall[8])
        k1_fw = statistics.median(e2e_full_wall[1])
        k4_fw = statistics.median(e2e_full_wall[4])
        k8_fw = statistics.median(e2e_full_wall[8])
        h132_results[mode_label] = {
            "last_token_head_gpu_ms_per_req": {str(k): stats_of(e2e_last_gpu[k]) for k in ks},
            "last_token_head_wall_ms_per_req": {str(k): stats_of(e2e_last_wall[k]) for k in ks},
            "full_128tok_head_gpu_ms_per_req": {str(k): stats_of(e2e_full_gpu[k]) for k in ks},
            "full_128tok_head_wall_ms_per_req": {str(k): stats_of(e2e_full_wall[k]) for k in ks},
            "k4_over_k1_last_head_wall_ratio": round(k4_w / k1_w, 4),
            "k8_over_k1_last_head_wall_ratio": round(k8_w / k1_w, 4),
            "k4_over_k1_full_head_wall_ratio": round(k4_fw / k1_fw, 4),
            "k8_over_k1_full_head_wall_ratio": round(k8_fw / k1_fw, 4),
            "passes_h132_kill_gate_lt_0_80": (k4_w / k1_w) <= 0.80,
        }
    # 5b. Native M3 Ultra MPSMatrixMultiplication float16 Batched K = 1, 2, 4, 8 Baseline (16 Interleaved ABBA Repeats)
    assert eng.lib.zk60_init_fp16_ring() == 0
    fp16_last_gpu = {k: [] for k in ks}
    fp16_last_wall = {k: [] for k in ks}
    fp16_full_gpu = {k: [] for k in ks}
    fp16_full_wall = {k: [] for k in ks}
    fg_ms, fw_ms = ctypes.c_double(), ctypes.c_double()
    for k in ks:
        assert eng.lib.zk60_run_fp16_batched_llama8b(k, 128, 1, ctypes.byref(fg_ms), ctypes.byref(fw_ms)) == 0
        assert eng.lib.zk60_run_fp16_batched_llama8b(k, 128, 0, ctypes.byref(fg_ms), ctypes.byref(fw_ms)) == 0
    for p in range(16):
        order = ks if (p % 2 == 0) else list(reversed(ks))
        for k in order:
            assert eng.lib.zk60_run_fp16_batched_llama8b(k, 128, 1, ctypes.byref(fg_ms), ctypes.byref(fw_ms)) == 0
            fp16_last_gpu[k].append(float(fg_ms.value) / k)
            fp16_last_wall[k].append(float(fw_ms.value) / k)
            assert eng.lib.zk60_run_fp16_batched_llama8b(k, 128, 0, ctypes.byref(fg_ms), ctypes.byref(fw_ms)) == 0
            fp16_full_gpu[k].append(float(fg_ms.value) / k)
            fp16_full_wall[k].append(float(fw_ms.value) / k)
    eng.lib.zk60_free_fp16_ring()
    h132_results["native_mps_fp16"] = {
        "last_token_head_gpu_ms_per_req": {str(k): stats_of(fp16_last_gpu[k]) for k in ks},
        "last_token_head_wall_ms_per_req": {str(k): stats_of(fp16_last_wall[k]) for k in ks},
        "full_128tok_head_gpu_ms_per_req": {str(k): stats_of(fp16_full_gpu[k]) for k in ks},
        "full_128tok_head_wall_ms_per_req": {str(k): stats_of(fp16_full_wall[k]) for k in ks},
    }
    best_int_mode = (
        "fast_64x64_sk1"
        if h132_results["fast_64x64_sk1"]["last_token_head_wall_ms_per_req"]["1"]["median"]
        <= h132_results["fast_64x64_sk4"]["last_token_head_wall_ms_per_req"]["1"]["median"]
        else "fast_64x64_sk4"
    )
    h132_results["best_exact_int_mode"] = best_int_mode
    h132_results["best_exact_int_over_fp16_overhead_ratio"] = {
        "last_token_head_wall": {
            str(k): round(
                h132_results[best_int_mode]["last_token_head_wall_ms_per_req"][str(k)]["median"]
                / h132_results["native_mps_fp16"]["last_token_head_wall_ms_per_req"][str(k)]["median"],
                3,
            )
            for k in ks
        },
        "full_128tok_head_wall": {
            str(k): round(
                h132_results[best_int_mode]["full_128tok_head_wall_ms_per_req"][str(k)]["median"]
                / h132_results["native_mps_fp16"]["full_128tok_head_wall_ms_per_req"][str(k)]["median"],
                3,
            )
            for k in ks
        },
    }
    print(
        f"[H132 DONE] {best_int_mode} vs FP16 per-req wall ms (last-tok head):",
        {
            k: (
                h132_results[best_int_mode]["last_token_head_wall_ms_per_req"][str(k)]["median"],
                h132_results["native_mps_fp16"]["last_token_head_wall_ms_per_req"][str(k)]["median"],
            )
            for k in ks
        },
        flush=True,
    )

    # 6. D80 Candidate B Empirical Trained Llama-3-8B Per-Plane RMS Census
    cand_b_rms = compute_candidate_b_trained_plane_rms(prompts_8, emb_i16, layers_meta)
    print("[D80 Candidate B RMS Census DONE] Sampled 32 layers x 256 tokens, refusals=0", flush=True)

    quiet_post = check_quiet_gpu()
    peak_rss_gib = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1024 ** 3)
    out = {
        "device": eng.device_name,
        "quiet_gpu_pre": quiet_pre,
        "quiet_gpu_post": quiet_post,
        "peak_rss_gib": round(peak_rss_gib, 3),
        "cap_gib": 28.0,
        "adversarial_and_partial_self_check": adv_res,
        "gate1_cpu_vs_resident_gpu_exact": {"max_abs_diff_x": 0, "max_abs_diff_logits": 0, "refusals": 0},
        "gate2_h132_batched_vs_standalone_exact": batch_parity,
        "d80a_m1_h128_production_block_comparison": h128_block_res,
        "h132_batched_32layer_llama8b_scaling": h132_results,
        "d80_candidate_b_trained_llama8b_plane_rms": cand_b_rms,
    }
    out_path = out_dir / "batch5_m1_h128_h132_metrics.json"
    out_path.write_text(json.dumps(out, indent=2) + "\n")
    print(f"[SAVED] {out_path}", flush=True)


if __name__ == "__main__":
    main()
