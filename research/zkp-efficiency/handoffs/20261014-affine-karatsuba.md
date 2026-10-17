# Owner review: public-axis factory and fixed affine Karatsuba

Research cycle0050, run20261014T203626Z-4afb917a. Review candidates only;
no production patch, build, heavy/GPU job or merge. Main/Claude owns translation
and integration. Do not infer permission from any prototype timing.

The prior cycle49 public-axis experiment completed and exited0 but its final
report was not written. Its original evidence is preserved under
`experiments/public-axis-row-factory-20261013/`; recovered progress explicitly
dated October14 is at `progress/20261013T073440Z-ac1df939.md`. It uses public
mask/support dependencies, retaining five coefficient slots and every original
sample/final.52fixtures/312schedules/3,240independent samples/8,640finals and
five controls pass;7.538s/20,508KiB CPU. Illustrative3limbT512 reduces counted
base products6.9312% and field API5.2846% versus cycle48. No native gain is
established and no cycle49 literature search completion can be recovered.

Cycle50 then compares against cycle49, replacing only public width2x2
coefficient products by3-product Karatsuba. Research patch location:
`experiments/affine-karatsuba-20261014/coefficients.py`, adapter in
`karatsuba_factory.py`, and uncompiled fixed-array sketch `affine_helper.rs`.
`source-diff.patch` isolates the arithmetic change from cycle49. Existing
copies of cycle47/48/49 modules and tuple oracle are pinned in
`copy-provenance.json`; actual run-source hashes are in `command.json`.

Actual native seam, under the read-only owner copy
`ops/zkp-mvp/sonnet-hardening/`:

- `hashline/src/private_block/argument.rs:1699` creates SC_SZC; groups at1783
  and source bracket at1788–1825. `helper_sum` at894 retains all paired/odd
  lookup relations. An optional immutable fixed5Fp2 row factory must precede
  this helper; it does not exist in production yet. Dependencies and constants
  are proof-definition-local; private slopes retain their declared widths.
- `zkp-core/src/sumcheck/grouped.rs:93` begins part accumulation, sample loop
  at107, reduction at121, sample1 recovery at132. Preserve typed weighted
  coefficient reduction, final singleton fallback and original wire samples.
- `zkp-core/src/field.rs:158` is the pinned Fp2 multiplication used in counts.
  This proposal does not edit global field arithmetic. Keep its canonical
  representation, Goldilocks nonresidue7, extension and serialization rules.

Interface sketch: `mul_affine([Fp2;2],[Fp2;2])->[Fp2;3]`; coefficients selected
by the public expression widths/axis metadata. Use static helper calls or a
public per-round plan, never the harness's module-global strategy and never
private-value/zero-degree pruning. No allocation is necessary for this helper.

Validation:100fixtures/600schedules pass5,832independent cube samples,
16,272ordered direct-MLE finals,300convolution values,40full-clause extension
values,600counter equalities and8zero/random schedule checks. Four arithmetic
mutation detections plus one schedule assertion pass. Even/odd lookup counts,
ragged parts, debug sample1 recovery, explicit zero factors, padded/unpadded,
logical head layout and2/3limbs are exercised.8.322s/21,972KiB/one nice19
CoreUltra9CPU thread. Commands,seed,dimensions,logs,exit and pins retained.

Added costs matter. At the illustrative hp16/kv4/qh12/T512/3limb schedule,
51,904,500 Fp2 products are removed,51,904,500adds and103,809,000subs added;
counted base products fall5.0673% but total field API increases3.4202%.
226,492,362 generic public width tests are charged separately. Keep80logical
output bytes; quantify added temporary liveness, fixed-plan setup/code size,
registers/spills and peak memory. Lower multiplication count is not an
enclosing speedup. The entire historical SC_SZC-removal ceiling is28.317%
of one125M/T512 RTX4070Laptop test wall, not an8B-rate prediction.

Required owner gates before promotion:

1. Native fixed-array differential samples/finals against generic polynomial
   at arbitrary extension points, all registered shapes/pad/refusal cases,
   and recovery/final singleton/ragged schedules. Preserve host support mapping.
2. Masked/frozen/tagged proof-byte,challenge,RNG continuation,PCS opening and
   fresh-process independent verification gates. No new mask/opening reuse;
   P3 weights and joint privacy/whole-proof soundness are separate obligations.
3. Under shared build/heavy resource guards only, measure row construction,
   equality/preparation, folds/reduction, both witness paths, peak/RSS/VRAM,
   enclosing cold/warm clocks and required receipt verification. Drop if code
   size/spills/dispatch/additions dominate or enclosing performance regresses.

The synthetic schedule has no transcript/mask/PCS implementation and discharges
none of those native gates. Historical slower native fold-fusion remains a
useful counterexample to operation-count predictions. Fresh resident complete
passes must measure startup and recurring slope; every counted position needs
a verified full-stack receipt. No accepted private8B proof/pass/token exists.
