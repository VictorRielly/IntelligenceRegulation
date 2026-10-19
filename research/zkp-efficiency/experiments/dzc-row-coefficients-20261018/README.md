# D round coefficients without an aggregate table

Cycle 0076, run `20261018T052105Z-217b5106`, 2026-10-18 UTC.
**Promising arithmetic counts; no native runtime improvement measured.**

The previous experiment found that an affine aggregate adds a full working
table while every original table/final remains. This experiment builds the
complete D polynomial's five coefficients directly from original endpoint
pairs, reduces coefficients across rows, then converts once per round to the
existing ordered evaluations `0..=degree`. It covers all eleven clauses,
lookup helpers, padding and both hosts. Declared D4/D5 schedules remain intact.

The original captured Rust D body and catalog are an independent executable
reference, using Shape/Layout allocation and exact u128 field substitutes.
An independently written Python eleven-equation/full-expression reference,
schoolbook coefficient multiplication and direct cube evaluation also check
the candidate. This is not native trained admission, field/PTX, transcript,
RNG, CFS masking, PCS or verifier execution.

The baseline already recovers evaluation 1 after the first round. D is a
host slot with unknown initial unmasked claim, so the actual release schedule
uses `E = 4(N-1) + N/2` scalar point evaluations when unpadded. The original
driver advances point values with additions, including the skipped point.
Every original table still folds. The audit also reports known-initial-claim
and debug schedules rather than assuming recovery removes every first round.

Run from the research directory:

```bash
python3 experiments/dzc-row-coefficients-20261018/run.py
python3 experiments/dzc-row-coefficients-20261018/audit.py
```

Seed `2026101876`. Synthetic N=2/8/32, actual public four-limb T128 catalog
descriptors for TinyLlama and Llama-3-8B; generic partial-top four/five-limb,
odd-helper and padded branches are additional algebra tests, not admitted
trained profiles. Both real T128 D geometries are unpadded.

PASS 30 fixtures: 2,145 captured-Rust grid values, 390 off-grid values,
90 complete round messages, 1,845 original cube finals, 30 final polynomial
relations, 1,950 schoolbook coefficients, 30 permutations, 30 aliases and
390 all-zero operation censuses. Eleven mutation/schema controls detect
lost leading coefficient, stale mu, reordered helpers, wrong MSB fold,
folding a pointwise nonlinear table, missing final, omitted support,
literal toy binding, out-of-range binding, wrong recovered claim and alias
overwrite. Schema checks are harness controls, not native verifier gates.

Independent closed-form audit covers all source/count contracts and 150
allocation-free geometry/schedule rows. Its initial padded audit confused
33 affine inputs with all 35 A columns; the correction and failure remain
under `initial-audit-affine-vs-column-count/`. The measured census was correct.

Current unpadded four-limb API counts:

| Scope | Fp2 mul | mul_base | add | sub |
|---|---:|---:|---:|---:|
| Original full polynomial, one scalar point |75|59|113|68|
| Candidate complete row coefficients |331|72|272|150|
| Candidate preparation, once per proof |0|30|76|54|
| Conversion, first round |0|12|16|0|
| Conversion, later recovered round |0|12|12|1|

Also charge 59 differences, five coefficient accumulation additions per row,
and all original folds. At counted 8B T128 N=524,288 (19 rounds), the native
Rust source model `5*Fp2mul + 2*mul_base` gives **1,317,795,621 -> 1,097,857,494
scalar products (-16.6899%)**; Fp2 add/sub calls 645,921,727 -> 316,669,728.
Known initial claim would reduce the product saving to 7.6312%.
The new driver adds zero full-size tables and removes zero originals/finals.
Its five coefficients occupy 80 logical bytes; that is not peak scratch.

Preserved negative: later rounds use **331 vs 300 extension products per
row** before common folds. Gains depend on avoiding 164 base products and
many stepping/add/sub calls. Karatsuba saves 23 extension products but adds
23 additions and 46 subtractions versus schoolbook. Source API counts are
not optimized machine instructions, GPU performance, bandwidth or proof time.
Common claim interpolation is unchanged/excluded; native reduction, dispatch,
preparation, allocation, spills, folding, transfers and enclosing time are owed.

No extra full L table is needed. The candidate still holds endpoint and
helper temporaries; it currently materializes all denominator coefficients.
Next: stream one helper pair at a time and measure logical lifetimes before
proposing a native fixed-array implementation. Preserve original finals and
extension/mask stages. `plan` accepts alpha/g_u8; its default values only
match the synthetic captured-reference fixture. Actual challenge plumbing
and varying challenge native tests remain owner obligations.

The full-D deletion ceiling in the carried 1.1B 174.052s diagnostic is only
1.18113x / 0.868615 diagnostic positions/s. Actual D arithmetic share and
8B end-to-end improvement remain unknown. Reject on any original-value,
recovery/refusal, degree, final, transcript/RNG/privacy divergence or enclosing
regression after all new costs. The unchanged >=50 private 8B proved-token/s
target cannot be inferred from these counts.

All commands use one nice19 CPU thread, 59s wall/CPU and 512MiB address-space
limits. `result.json`, `audit-result.json`, execution logs and `hardware.json`
retain clocks/memory/device details. No GPU, Cargo, install or external code
execution. All values synthetic; profile scalars alone were retained.

New target complete proofs/passes/positions **0/0/0**; device none. Target
steady/total rates, startup fraction, witness/proof/serialization/verification
clocks are unmeasured. No long-context prefill, resident series or decode ran.
Longer attention context can grow quadratically; masks/openings are not reused.
See [unapplied handoff](../../handoffs/20261018-dzc-row-coefficients.md).
