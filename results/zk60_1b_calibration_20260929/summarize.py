#!/usr/bin/env python3
"""Read runs/<variant>/{summary,layer_NN}.json and print the tables the
REPORT uses: head metrics, per-layer quality, the range sites that refused,
and the per-site bits lost to the fixed integer structure. Pure file reading
(no checkpoint access, CPU-light)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(variant: str):
    d = HERE / "runs" / variant
    summ = json.loads((d / "summary.json").read_text())
    layers = [json.loads(p.read_text()) for p in sorted(d.glob("layer_*.json"))]
    return summ, layers


def refusals(rng: dict) -> dict:
    return {k: (v["violations"], v["seqs_refused"]) for k, v in rng["sites"].items() if v["violations"]}


def main():
    for variant in sys.argv[1:]:
        summ, layers = load(variant)
        print(f"== {variant}: args {summ['args']}")
        if "head" in summ:
            h = summ["head"]
            print(f"   head: top1 {h['top1_agreement']:.4f} ppl float {h['ppl_float']:.3f} int {h['ppl_int']:.3f} "
                  f"KL {h['kl_float_to_int_mean']:.4f} positions {h['positions']}")
        print(f"   embedding cos {summ['embedding_cos']}; held-out refused (any layer) "
              f"{summ['heldout_sequences_refused_any_layer']}/{len(summ['heldout_sequences'])}, calib refused "
              f"{summ['calib_sequences_refused_any_layer']}/{len(summ['calib_sequences'])}")
        for e in layers:
            c = e["calibration"]
            wl = {k: round(v, 1) for k, v in c["weight_loss_bits"].items() if v >= 0.5}
            al = {k: round(v, 1) for k, v in c["act_loss_bits"].items() if v >= 0.5}
            clip = {k: v for k, v in c.get("weights_clipped", {}).items() if v}
            ref_h = refusals(e["chained"]["range"])
            ref_c = refusals(e["calib_chained_range"])
            print(f"   L{e['layer']:02d} iso cos {e['isolated']['cos']['mean']:.4f} dcos {e['isolated']['delta_cos']['mean']:.4f} "
                  f"chain cos {e['chained']['cos']['mean']:.4f} | wloss {wl} aloss {al} clip {clip} | "
                  f"refuse held-out {ref_h} calib {ref_c}")


if __name__ == "__main__":
    main()
