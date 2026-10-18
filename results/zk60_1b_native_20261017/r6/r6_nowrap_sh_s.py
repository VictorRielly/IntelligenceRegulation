#!/usr/bin/env python3
"""NATIVE R6: the no-wrap check of a PER-LAYER softmax score shift over its
whole window (sh_s 1..=8, `shape::ONE_LIMB_SHIFT`), at every trained head
width (TinyLlama head_dim 64, Llama-3-8B head_dim 128).

Where sh_s enters the relation (live tree, grep `sh_s` in private_block/):
  - argument.rs ~1751: the score host relation's constants 2^sh_s and
    half(sh_s) = 2^(sh_s - 1): 2^sh_s * s8 + rsl - 2^(sh_s - 1) - acc = 0;
  - layout.rs ~773: rsl's byte lookup and its scaled top pin
    scaled(rsl, 2^(8 - sh_s)), so rsl in [0, 2^sh_s);
  - witness.rs ~626: s8 = quantize(acc, sh_s) in [-127, 127] (int8);
  - layout.rs ~1342: the schedule's calibration line (no relation).
Downstream of s8 nothing carries sh_s: the exp lookup reads max - s8, whose
range does not depend on the shift.

Adversarial facts (conservative): s8 in [-128, 127] (one byte), rsl in
[0, 2^sh_s), q8, k8 in [-128, 127] so |acc| <= head_dim * 128 * 128. The
relation holds over the integers when the largest |value| is below p/2, so
s8 and rsl are the floor quotient and remainder at every sh_s in the window.
Writes r6_nowrap_sh_s.json beside this script."""
import json
import math
import os

P = 2**64 - 2**32 + 1
HALF = P // 2
out = {"field_half_log2": round(math.log2(HALF), 3), "rows": []}
worst = 0
for model, hd in (("TinyLlama-1.1B (head_dim 64)", 64), ("Llama-3-8B (head_dim 128)", 128)):
    for sh in range(1, 9):
        acc = hd * 128 * 128
        hi = (2**sh) * 127 + (2**sh - 1) + acc  # s8 top, rsl top, -half <= 0, -acc at its most negative
        lo = (2**sh) * (-128) + 0 - 2 ** (sh - 1) - acc
        m = max(abs(hi), abs(lo))
        assert m < HALF, (model, sh, m)
        worst = max(worst, m)
        out["rows"].append({"model": model, "sh_s": sh, "max_abs": m, "log2": round(math.log2(m), 3)})
out["worst_log2"] = round(math.log2(worst), 3)
out["verdict"] = "below p/2 at every sh_s in 1..=8 and both trained head widths (margin about 2^%d)" % int(math.log2(HALF) - math.log2(worst))
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "r6_nowrap_sh_s.json")
json.dump(out, open(p, "w"), indent=1)
print(out["verdict"], "worst", out["worst_log2"])
