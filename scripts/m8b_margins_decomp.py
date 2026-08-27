"""m8b_margins_decomp — U-PERF3 round 3 lane AA: decompose the Gemma
margin quality cost by margin SITE.

The zero-violation margin set (results/m8b_margins_gemma_wsl.json:
X+1 at l1/10/12/21, z+1 at l5, gate+1 at l34, h+1 at l39/43 — 8 bits)
costs +0.1082 nats over the no-margin stack (+0.0353 -> +0.1436),
where Mistral's margin set was free (-0.0007).  Hypothesis: the X-site
margins carry the cost — X stays int8 in the v3 stack, so +1 exponent
bit halves the resolution of the whole X plane at those layers;
z/gate/h margins land on int16 planes with resolution to spare.

One verdict walk per margin subset (same ref, same val windows as the
margin run):
  x_only   the four X bits alone   (expect: reintroduces the z/gate/h
           violations; the question is its delta)
  non_x    the z/gate/h bits alone (expect: reintroduces X_clip 4)
The additivity check against the full set's +0.1436 is printed.

Usage: python3 scripts/m8b_margins_decomp.py [--smoke]
Output: results/m8b_margins_gemma_decomp.json
"""
import json
import sys
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import m8b_margins as m

ROOT = Path(__file__).resolve().parents[1]
MARGINS_JSON = ROOT / "results" / "m8b_margins_gemma_wsl.json"
OUT_JSON = ROOT / "results" / "m8b_margins_gemma_decomp.json"


def main():
    smoke = "--smoke" in sys.argv
    prev = json.loads(MARGINS_JSON.read_text())
    full = m.margins_from_json(prev["final"]["margins"])
    subsets = {}
    for name, keep in (("x_only", lambda s: s == "X"),
                       ("non_x", lambda s: s != "X")):
        sub = {li: {s: b for s, b in mm.items() if keep(s)}
               for li, mm in full.items()}
        subsets[name] = {li: mm for li, mm in sub.items() if mm}

    ctx = m.build_ctx("gemma", max_layers=6 if smoke else None)
    arch, walker, scales = ctx["arch"], ctx["walker"], ctx["scales"]
    val = ctx["val"][:1] if smoke else ctx["val"]
    cache = m.MemberCache()
    report = dict(meta=dict(
        experiment="m8b_margins_decomp (Gemma margin-cost by site)",
        model="gemma", checkpoint=ctx["ckpt"], seed=ctx["seed"],
        t=ctx["t"], val_windows=int(val.shape[0]),
        layers=arch.n_layers, loss_ref=ctx["loss_ref"], smoke=smoke,
        full_set=prev["final"]["margins"],
        full_delta=prev["final"]["delta_vs_ref"],
        round0_delta=prev["rounds"][0]["delta_vs_ref"],
        box="[MEASURED WSL-BOX NT|NOISY-SHARED]"), walks={})
    print("m8b_margins_decomp — gemma, %d layers, %d val windows, "
          "ref %.4f%s" % (arch.n_layers, val.shape[0], ctx["loss_ref"],
                          "  ** SMOKE **" if smoke else ""))
    for name, margins in subsets.items():
        viols = [Counter() for _ in range(arch.n_layers)]
        clamp_hits = [0] * arch.n_layers
        ffn = m.make_v3_ffn(ctx["kind"], scales, margins, cache, viols,
                            clamp_hits)
        t0 = time.time()
        loss = walker.loss(val, ffn_override=ffn)
        wall = time.time() - t0
        by = Counter()
        for c in viols:
            by.update(c)
        row = dict(margins=m.margins_to_json(margins), loss=loss,
                   delta_vs_ref=loss - ctx["loss_ref"],
                   total_viol=int(sum(by.values())),
                   viol_by_class=dict(by), wall_s=round(wall, 1))
        report["walks"][name] = row
        print("  %-7s loss %.4f  delta %+.4f  viol %d %s  (%.0fs)"
              % (name, loss, row["delta_vs_ref"], row["total_viol"],
                 dict(by), wall))
    r0 = report["meta"]["round0_delta"]
    fx = report["walks"]["x_only"]["delta_vs_ref"] - r0
    fn = report["walks"]["non_x"]["delta_vs_ref"] - r0
    ffull = report["meta"]["full_delta"] - r0
    report["decomposition"] = dict(
        x_only_cost=fx, non_x_cost=fn, full_cost=ffull,
        additivity_gap=ffull - (fx + fn))
    print("DECOMP: x_only %+0.4f  non_x %+0.4f  sum %+0.4f  "
          "full %+0.4f  (gap %+0.4f)" % (fx, fn, fx + fn, ffull,
                                         ffull - (fx + fn)))
    OUT_JSON.write_text(json.dumps(report, indent=1))
    print("JSON -> %s" % OUT_JSON)
    print("peak RSS %.2f GB" % m.rss_gb())


if __name__ == "__main__":
    main()
