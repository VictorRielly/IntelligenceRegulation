"""m8b_widen_attrib — the class-widening cross-check on MISTRAL-7B
(orchestrator, 2026-08-26). The Gemma exact-chain measurement showed
int16 u/h/z classes + round-nearest requant collapse the delta
+17.60 -> +0.71 (X16 completes it). This script runs the SAME widened
exact chain on Mistral-7B-v0.1 (SwiGLU, m8b module semantics) so the
class-widening amendment is evidenced MODEL-AGNOSTICALLY.

Scales/exponents REUSED verbatim from the committed baseline
results/m8b_int8_calibration_wsl.json (seed 1337, 8+8 x 512, the same
FineWeb text). Baselines to beat [MEASURED]: floor a8 +8.1773 nats
(14,531 viols); best prior static mechanism +7.32 (percol_g16).
Variants here: round+uhz16, round+Xuhz16 (int16 = exponent e-8, SAME
absmax coverage, 256x finer step; negative shifts = exact public
up-scalings; violations counted at the widened Q).
"""

import json
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125     # noqa: E402
import m8b_int8_calibration as m8b       # noqa: E402

BASELINE_JSON = ROOT / "results" / "m8b_int8_calibration_wsl.json"
OUT = ROOT / "results" / "m8b_widen_attrib_wsl.json"
Q16 = 32767


def requant_narrow(acc, sh, q, mode, vc, key):
    if sh < 0:
        y = acc * (2.0 ** (-sh))            # exact, lossless
    else:
        y = m125.floor_requant(acc, sh, mode)
    vc[key] += int(np.count_nonzero(np.abs(y) > q))
    return np.clip(y, -q, q)


def make_widen_ffn(scales, members, wide, mode, viols):
    def ffn(li, x, lw):
        sc = scales[li]
        B, T, C = x.shape
        tab = members[(sc["eGate"], sc["eA"])][0].astype(np.float64)
        Wq = {}
        for name, ekey in (("w_gate", "eWg"), ("w_up", "eWu"),
                           ("w_down", "eWd")):
            q, _ = m125.quantize(lw[name].astype(np.float64), sc[ekey])
            Wq[name] = q
        x16 = "X" in wide
        eX = sc["eX"] - (8 if x16 else 0)
        eU = sc["eUp"] - (8 if "u" in wide else 0)
        eH = sc["eH"] - (8 if "h" in wide else 0)
        eZ = sc["eZ"] - (8 if "z" in wide else 0)
        qU = Q16 if "u" in wide else 127
        qH = Q16 if "h" in wide else 127
        qZ = Q16 if "z" in wide else 127
        sh_g = sc["eGate"] - eX - sc["eWg"]
        sh_u = eU - eX - sc["eWu"]
        sh_h = eH - sc["eA"] - eU
        sh_z = eZ - eH - sc["eWd"]
        out = np.empty((B, T, C), dtype=np.float32)
        for b in range(B):
            xf = x[b].astype(np.float64)
            qx = np.round(xf / (2.0 ** eX))
            lim = Q16 if x16 else 127
            viols[li]["X_clip"] += int(np.count_nonzero(np.abs(qx) > lim))
            xq = np.clip(qx, -lim, lim)
            acc_g = xq @ Wq["w_gate"].T
            acc_u = xq @ Wq["w_up"].T
            yg = requant_narrow(acc_g, sh_g, 127, mode, viols[li],
                                "gate_range")
            yu = requant_narrow(acc_u, sh_u, qU, mode, viols[li],
                                "up_range")
            aq = tab[(yg.astype(np.int64) + 128)]
            hq = aq * yu
            yh = requant_narrow(hq, sh_h, qH, mode, viols[li],
                                "h_range")
            acc_d = yh @ Wq["w_down"].T
            yz = requant_narrow(acc_d, sh_z, qZ, mode, viols[li],
                                "z_range")
            out[b] = (yz * (2.0 ** eZ)).astype(np.float32)
        return out
    return ffn


def main():
    base = json.loads(BASELINE_JSON.read_text())
    ckpt = base["checkpoint"]
    seed, t = base["seed"], base["dims"]["t"]
    arch = m8b.make_arch(base["arch"], ckpt)
    scales = base["calibration"]
    # the baseline JSON stores calibration rows as {layer, ...scales}
    if "eX" not in scales[0]:
        scales = [dict(s, **s.get("scales", {})) for s in scales]
    store = m8b.TensorStore(ckpt)
    walker = m8b.Walker(store, arch, t)
    members = m8b.silu_members(scales)

    class A:
        text = str(Path.home() / "models" / "fineweb-edu" /
                   "sample_text.txt")
        tokens = None
        cal_seqs = 8
        val_seqs = 8
    A.t = t
    toks = m8b.load_token_stream(A, ckpt)
    cal, val = m8b.token_batches(toks, seed, A.cal_seqs, A.val_seqs, t)
    loss_ref = base["int8_chain"]["loss_ref"]
    print("Mistral widen cross-check; ref %.4f, baselines: floor-a8 "
          "+8.1773 (14,531 viols), best static prior +7.32" % loss_ref)

    specs = [("exact_round_uhz16", {"u", "h", "z"}, "round"),
             ("exact_round_Xuhz16", {"X", "u", "h", "z"}, "round")]
    results = {}
    for label, wide, mode in specs:
        vio = [Counter() for _ in range(arch.n_layers)]
        t0 = time.time()
        loss = walker.loss(val, ffn_override=make_widen_ffn(
            scales, members, wide, mode, vio))
        tot = sum(sum(c.values()) for c in vio)
        by = Counter()
        for c in vio:
            by.update(c)
        d = loss - loss_ref
        results[label] = dict(loss=loss, delta=d, total_viol=tot,
                              viol_by_class=dict(by),
                              wall_s=round(time.time() - t0, 1))
        print("  %-20s loss %.4f  delta %+8.4f  viol %d %s  (%.0fs)"
              % (label, loss, d, tot, dict(by), time.time() - t0))
        OUT.write_text(json.dumps(dict(
            meta=dict(experiment="m8b_widen_attrib (Mistral class-"
                                 "widening cross-check)",
                      seed=seed, t=t, loss_ref=loss_ref,
                      box="[MEASURED WSL-BOX NT]"),
            results=results), indent=1))
    print("JSON ->", OUT)


if __name__ == "__main__":
    main()
