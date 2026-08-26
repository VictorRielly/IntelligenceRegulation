"""m8b_gemma4_attrib — per-site quantization-noise ATTRIBUTION for the
Gemma-4-12B C4 gate failure (orchestrator, 2026-08-26).

Question: the +17.60-nat chain delta survives every RANGE mechanism
(per-column eZ: Z1 87 viols, delta unchanged) and int16 z at the hot
layers (Z3, delta unchanged). WHERE do the nats actually die?

Method: the fp GeGLU FFN (g4's reference semantics) with quantization
inserted at exactly ONE site, all other sites left in fp:
    W     int8 weights (per-tensor, the baseline exponents)
    X     quantize-dequant the FFN input at eX
    gate  the gate path through the frozen int8 table:
          y = tab[int8(gate @ eGate)] * 2^eA   (this IS the table site)
    u     quantize-dequant the up output at eUp
    h     quantize-dequant the Hadamard at eH
    z     quantize-dequant the down output at eZ
    none / all   sanity anchors (fp == ref; full chain == baseline)
Deltas are FIRST-ORDER attribution (the real chain compounds), ranked
on a REDUCED val subset (--val-take, default 2 of the 8 windows) so
the whole sweep costs ~one full pass. Scales/exponents are REUSED
verbatim from results/m8b_gemma4_calibration.json (same seed/windows).
Labels: [MEASURED WSL-BOX] on the subset — deltas comparable WITHIN
this run (the 'all' row calibrates against the full-set baseline).
"""

import json
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125     # noqa: E402
import m8b_int8_calibration as m8b       # noqa: E402
import m8b_gemma4_walker as g4           # noqa: E402
import m8b_gemma4_zfix as zfix           # noqa: E402  (loaders reused)

BASELINE_JSON = ROOT / "results" / "m8b_gemma4_calibration.json"
OUT = ROOT / "results" / "m8b_gemma4_attrib_wsl.json"


def deq(x, e):
    q, _ = m125.quantize(x, e)
    return q * (2.0 ** e)


def deq16(x, e8):
    """int16 quantize-dequant with the SAME absmax coverage as the int8
    exponent e8 (e16 = e8 - 8): 256x finer step, identical range."""
    e16 = e8 - 8
    q = np.clip(np.floor(x / (2.0 ** e16) + 0.5), -32767, 32767)
    return q * (2.0 ** e16)


def make_chain_ffn(scales, members, wide):
    """The FULL quantized chain (every site quantized), with the sites
    named in `wide` at int16 (e8-8 exponents) and the rest at int8 —
    the class-widening quality measurement. wide ⊆ {X,gate,u,h,z}."""
    def ffn(li, x, lw):
        sc = scales[li]
        B, T, C = x.shape
        wg = deq(lw["w_gate"].astype(np.float64), sc["eWg"])
        wu = deq(lw["w_up"].astype(np.float64), sc["eWu"])
        wd = deq(lw["w_down"].astype(np.float64), sc["eWd"])
        tab = members[(sc["eGate"], sc["eA"])][0].astype(np.float64)
        out = np.empty((B, T, C), dtype=np.float32)
        for b in range(B):
            xf = x[b].astype(np.float64)
            xf = deq16(xf, sc["eX"]) if "X" in wide else deq(xf, sc["eX"])
            gate = xf @ wg.T
            up = xf @ wu.T
            if "gate" in wide:
                gq = np.clip(np.floor(gate / (2.0 ** (sc["eGate"] - 8))
                                      + 0.5), -32767, 32767)
                g16 = gq * (2.0 ** (sc["eGate"] - 8))
                a = g16 * 0.5 * (1.0 + np.tanh(
                    0.7978845608028654 * (g16 + 0.044715 * g16 ** 3)))
                a = deq16(a, sc["eA"])
            else:
                a = tab[(np.clip(np.floor(gate / (2.0 ** sc["eGate"])
                                          + 0.5), -128, 127)
                         .astype(np.int64) + 128)] * (2.0 ** sc["eA"])
            up = deq16(up, sc["eUp"]) if "u" in wide else deq(
                up, sc["eUp"])
            h = a * up
            h = deq16(h, sc["eH"]) if "h" in wide else deq(h, sc["eH"])
            z = h @ wd.T
            z = deq16(z, sc["eZ"]) if "z" in wide else deq(z, sc["eZ"])
            out[b] = z.astype(np.float32)
        return out
    return ffn


def make_site_ffn(scales, members, site):
    """fp GeGLU FFN with quantization at exactly one site."""
    def ffn(li, x, lw):
        sc = scales[li]
        B, T, C = x.shape
        wg = lw["w_gate"].astype(np.float64)
        wu = lw["w_up"].astype(np.float64)
        wd = lw["w_down"].astype(np.float64)
        if site == "W":
            wg = deq(wg, sc["eWg"])
            wu = deq(wu, sc["eWu"])
            wd = deq(wd, sc["eWd"])
        out = np.empty((B, T, C), dtype=np.float32)
        for b in range(B):
            xf = x[b].astype(np.float64)
            if site == "X":
                xf = deq(xf, sc["eX"])
            gate = xf @ wg.T
            up = xf @ wu.T
            if site == "gate":
                tab = members[(sc["eGate"], sc["eA"])][0].astype(
                    np.float64)
                gq, _ = m125.quantize(gate, sc["eGate"])
                a = tab[(gq.astype(np.int64) + 128)] * (2.0 ** sc["eA"])
            else:
                a = gate * 0.5 * (1.0 + np.tanh(
                    0.7978845608028654 * (gate + 0.044715 * gate ** 3)))
            if site == "u":
                up = deq(up, sc["eUp"])
            h = a * up
            if site == "h":
                h = deq(h, sc["eH"])
            z = h @ wd.T
            if site == "z":
                z = deq(z, sc["eZ"])
            out[b] = z.astype(np.float32)
        return out
    return ffn


def main():
    base = json.loads(BASELINE_JSON.read_text())
    ckpt = base["checkpoint"]
    seed, t = base["seed"], base["dims"]["t"]
    arch = g4.arch_gemma4(ckpt)
    scales = base["calibration"]
    store = m8b.TensorStore(ckpt)
    walker = g4.Gemma4Walker(store, arch, t)
    members = zfix.gelu_members(scales)

    class A:  # the m8b loader arg shim
        text = str(Path.home() / "models" / "fineweb-edu" /
                   "sample_text.txt")
        tokens = None
        cal_seqs = 8
        val_seqs = 8
    A.t = t

    toks = m8b.load_token_stream(A, ckpt)
    cal, val = m8b.token_batches(toks, seed, A.cal_seqs, A.val_seqs, t)
    take = int(sys.argv[sys.argv.index("--val-take") + 1]) \
        if "--val-take" in sys.argv else 2
    vsub = val[:take]
    print("attrib on %d of %d val windows; ref(full) %.4f, "
          "baseline delta(full) +%.4f"
          % (len(vsub), len(val), base["verdict"]["loss_ref"],
             base["verdict"]["loss_delta_nats"]["A"]))

    if "--chains" in sys.argv:
        runs = [("fp", None),
                ("chain_a8", make_chain_ffn(scales, members, set())),
                ("chain_hz16", make_chain_ffn(scales, members,
                                              {"h", "z"})),
                ("chain_a16", make_chain_ffn(scales, members,
                                             {"X", "gate", "u", "h",
                                              "z"}))]
    else:
        runs = [(s, None if s == "none" else
                 make_site_ffn(scales, members, s))
                for s in ("none", "W", "X", "gate", "u", "h", "z")]

    results = {}
    ref_sub = None
    for site, ffn in runs:
        t0 = time.time()
        loss = walker.loss(vsub, ffn_override=ffn)
        if ref_sub is None:
            ref_sub = loss
        d = loss - ref_sub
        results[site] = dict(loss=loss, delta_vs_fp_subset=d,
                             wall_s=round(time.time() - t0, 1))
        print("  site %-10s loss %.4f  delta %+8.4f  (%.0fs)"
              % (site, loss, d, time.time() - t0))
        OUT.write_text(json.dumps(dict(
            meta=dict(experiment="m8b_gemma4_attrib (per-site noise)",
                      val_take=len(vsub), seed=seed, t=t,
                      box="[MEASURED WSL-BOX NT, val subset]"),
            results=results), indent=1))
    print("JSON ->", OUT)


if __name__ == "__main__":
    main()
