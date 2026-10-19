#!/usr/bin/env python3
"""GPTQ-style rounding of a layer's int8 words at FIXED scales (weight-side only).

The export's scales, shifts, tables and norm constants are kept; only the
rounding of each public int8 word changes, chosen to minimise the matmul
output error ||X (W8 - W_real)||^2 against the integer model's OWN inputs X
(true-sequential within the layer: Q/K/V on the norm output, Wo on the
attention output o8 computed with the new Q/K/V words, gate/up on norm_m with
the new Wo, down on the product h16 with the new gate/up). Words stay int8 in
[-127, 127] (clamped by the quantizer), so the export stays inside every
declared class. Free for the proof: the words are public and fixed.

GPTQ: Frantar et al., arXiv 2210.17323 (lazy batch updates, Cholesky of
H^-1, act-order, dampening 1%).
"""

from __future__ import annotations

import numpy as np

import fp_lib as fl


def gptq_rows(Wr: np.ndarray, H: np.ndarray, damp: float = 0.01, block: int = 128, actorder: bool = True) -> np.ndarray:
    """Wr (out, in) real target in LSB units, H (in, in) = sum x x^T. Returns int8 (out, in)."""
    W = np.array(Wr, dtype=np.float64, copy=True)
    H = np.array(H, dtype=np.float64, copy=True)
    n = W.shape[1]
    dead = np.diag(H) <= 0
    H[dead, dead] = 1.0
    perm = np.argsort(-np.diag(H), kind="stable") if actorder else np.arange(n)
    W = W[:, perm]
    H = H[perm][:, perm]
    H[np.diag_indices(n)] += damp * float(np.mean(np.diag(H)))
    L = np.linalg.cholesky(H)
    Li = np.linalg.inv(L)
    Hi = Li.T @ Li
    U = np.linalg.cholesky(Hi).T          # upper: Hi = U^T U
    Q = np.zeros_like(W)
    for i1 in range(0, n, block):
        i2 = min(i1 + block, n)
        W1 = W[:, i1:i2].copy()
        Q1 = np.zeros_like(W1)
        E1 = np.zeros_like(W1)
        U1 = U[i1:i2, i1:i2]
        for i in range(i2 - i1):
            w = W1[:, i]
            q = np.clip(np.floor(w + 0.5), -127, 127)
            Q1[:, i] = q
            e = (w - q) / U1[i, i]
            W1[:, i:] -= np.outer(e, U1[i, i:])
            E1[:, i] = e
        Q[:, i1:i2] = Q1
        if i2 < n:
            W[:, i2:] -= E1 @ U[i1:i2, i2:]
    inv = np.empty(n, dtype=np.int64)
    inv[perm] = np.arange(n)
    return Q[:, inv].astype(np.int8)


def _acc_H(H, X):
    X2 = X.reshape(-1, X.shape[-1])
    H += X2.T @ X2
    return H


def gptq_layer(Lw: dict, Wreal: dict, T: int, xc: np.ndarray, chunk: int, damp: float = 0.01):
    """True-sequential GPTQ of one layer on calibration states xc (integer, LSB units).
    Returns (new words dict, report). Uses the EXACT integer block for every activation."""
    ex = frozenset(fl.SITES)
    w = dict(Lw["w"])
    rep = {}

    def run(words, key):
        M = fl.LayerModel({"w": words, "c": Lw["c"]}, T)
        H = None
        for s in range(0, len(xc), chunk):
            tr = {}
            fl.rx_block(xc[s:s + chunk], M, ex, None, trace=tr)
            X = tr[key]
            if H is None:
                H = np.zeros((X.shape[-1], X.shape[-1]))
            _acc_H(H, X)
        return H

    def err(Wq, Wt, H):     # relative output error  tr((Wq-Wt) H (Wq-Wt)^T) / tr(Wt H Wt^T)
        D = Wq.astype(np.float64) - Wt
        return float(np.sum((D @ H) * D) / max(float(np.sum((Wt @ H) * Wt)), 1e-30))

    Hy = run(w, "y")
    for n in ("wq", "wk", "wv"):
        old = err(w[n], Wreal[n].astype(np.float64), Hy)
        w[n] = gptq_rows(Wreal[n], Hy, damp)
        rep[n] = {"rel_err_rtn": old, "rel_err_gptq": err(w[n], Wreal[n].astype(np.float64), Hy)}
    Ho = run(w, "o8")
    old = err(w["wo"], Wreal["wo"].astype(np.float64), Ho)
    w["wo"] = gptq_rows(Wreal["wo"], Ho, damp)
    rep["wo"] = {"rel_err_rtn": old, "rel_err_gptq": err(w["wo"], Wreal["wo"].astype(np.float64), Ho)}
    Hn = run(w, "nm")
    for n in ("wg_t", "wu_t"):
        Wt = Wreal[n].T.astype(np.float64)
        old = err(w[n].T, Wt, Hn)
        q = gptq_rows(Wt, Hn, damp)
        rep[n] = {"rel_err_rtn": old, "rel_err_gptq": err(q, Wt, Hn)}
        w[n] = np.ascontiguousarray(q.T)
    Hh = run(w, "h16")
    Wt = Wreal["wd_t"].T.astype(np.float64)
    old = err(w["wd_t"].T, Wt, Hh)
    q = gptq_rows(Wt, Hh, damp)
    rep["wd_t"] = {"rel_err_rtn": old, "rel_err_gptq": err(q, Wt, Hh)}
    w["wd_t"] = np.ascontiguousarray(q.T)
    return w, rep
