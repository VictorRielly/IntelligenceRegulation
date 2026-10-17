# Exact Fp2 arithmetic — cycle 0007

Run `20260926T225233Z-f66107c9`, 2026-09-26. **Algebra and fixed-width
transcriptions pass; no runtime improvement or complete proof was measured.**
The target remains a complete private 8B attention-plus-FFN proof at >=50
proved tokens/s, including witness preparation and serialization. The
512-token prefill reference is <=10.24 s; five seconds is a stretch. Larger
workload amortization is a separate project direction. None establishes decode.

## Hypothesis and native seam

`zkp-core/src/field.rs::Fp2::mul` computes four variable base products and
one multiplication by seven; `Fp2::square` calls `mul(self)`. Karatsuba removes
one variable product with canonical intermediate sums. A two-product square
uses `(a+b)(a+7b)-8ab` and `2ab`. Both keep `u²=7` and all canonical bytes.

The new costs are modular additions/subtractions and dependency chains.
The baseline's duplicate `ab`/`ba` in squaring may already be removed by the
compiler, so the explicit three-product square is a comparison control,
**not a claimed optimization**. No explicit `.square()` call was found in
the inspected sumcheck sources or shaped private-block argument; its native
hotness is unknown. Fp2 `mul` is directly used by grouped round evaluation.

Baseline/current grouped field snapshots are identical. `prepare.py` creates
[the proposed patch](fp2-arithmetic.proposed.patch) and
[complete candidate source](field.candidate.rs) only here. Two hunks alter
Fp2 `mul` and `square`; no base arithmetic or other method changes. Nothing
was applied or compiled. No external code was executed or copied into it.

## Reproduction and scope

Working directory: `/home/victor/IntelligenceRegulation/research/zkp-efficiency`.

```sh
python3 experiments/fp2-arithmetic-20260926/prepare.py > experiments/fp2-arithmetic-20260926/prepare.log 2>&1
python3 experiments/fp2-arithmetic-20260926/experiment.py > experiments/fp2-arithmetic-20260926/run.log 2>&1
python3 experiments/fp2-arithmetic-20260926/validate.py > experiments/fp2-arithmetic-20260926/validation.log 2>&1
```

The runner pins one available CPU, lowers its priority, and enforces a 59 s
wall alarm, 55 s CPU limit and 512 MiB address-space ceiling. Estimated
experiment memory 32 MiB; actual **22,496 KiB peak RSS**, **3.718 s** wall
on Intel Core Ultra 9 185H, Python 3.10.12, WSL2. Seed **2026092607**.
There were no dependencies, native builds, GPU jobs or production/runtime writes.
Proving, verification and complete-readiness clocks are **null**, not this
script's elapsed time. A failed initial preparation read used `status` where
the owner JSON calls it `state`; the exact failure and correction are retained
in `preparation-failure.json`. It did not change any experiment assertion.

The independent oracle convolves unbounded integer polynomials and reduces
by `X²-7` and p. The fixed-width arm models native `u64` wrapping,
carry/borrow correction and the full `reduce128` sequence. It compares:

- 10,121 base add/subtract/multiply pairs and 10,007 full-width reductions;
- **24,641 Fp2 products**, three implementations per case;
- **10,121 squares**, four implementations per case, and 35 powers;
- 24 fused-round fixtures, four tables of 1/2/4/8/16/32 rows, degrees 2/3,
  full-extension and zero-equality cases, ragged tile three and reverse order;
  **630 round samples and 288 final MLEs across three arithmetic arms**;
- 24 synthetic masked schedule comparisons and 13 SC_SZC grouped fixtures,
  4/8/16 rows, padded/unpadded, base/extension/zero, with **189 independent
  round-point checks** using the original arithmetic, and four zero-factor
  fallback rounds in the dedicated fixture.

The local reference files are pinned copies of previously inspected research
fixtures. Only this runner imports them; their `main()` functions are not run.
The fused direct-MLE/round oracle never calls the replacement multiplier.
For grouped checks the original arithmetic first establishes direct-round,
final-MLE and transcript results; replacements are then compared to that result.
The grouped operation counters cover the whole toy harness (reference,
grouped, no-recovery and final checks), **not a native slot operation count**.

Eleven negative controls detect: unreduced 64-bit input sums; overflowing
128-bit deferred real/cross sums; wrong nonresidue; a missing cross product;
missing square doubling; subtracting 7ab instead of 8ab; missing borrow/carry
correction; swapped serialization limbs; changed input. Four invalid canonical
fixtures are refused by the harness. Native callers still owe their existing
canonical-limb precondition; this is no new native refusal policy.

## Work removed and work added

Counts are source-level primitive calls, **not machine instructions**. M is a
variable base product, K a multiply by constant seven, A/S modular add/subtract;
every M or K below calls `reduce128` once.

| Form | M | K | A | S | reduce128 |
|---|---:|---:|---:|---:|---:|
| Current general multiplication | 4 | 1 | 2 | 0 | 5 |
| Karatsuba | 3 | 1 | 3 | 2 | 4 |
| Karatsuba, seven via doubles | 3 | 0 | 6 | 3 | 3 |
| Square with shared cross product (possible compiler result) | 3 | 1 | 2 | 0 | 4 |
| Two-product square, reusing 2ab | 2 | 1 | 5 | 1 | 3 |
| Two-product square, seven via doubles | 2 | 0 | 8 | 2 | 2 |

Under a simplistic additive cost model, Karatsuba needs **M > A+2S**;
two-product square versus the shared-cross baseline needs **M > 3A+S**.
Replacing multiplication by seven needs **K > 3A+S**. Dependency chains,
compiler strength reduction, register pressure and vectorization can overturn
these inequalities. The doubles variant is Python-only and is not proposed
as the default Rust change.

Blindly accumulating `ac+7bd` in u128 needs up to 131 bits; `ad+bc` up to
129. The negative controls actually distinguish the wrapping results. There
is no lazy noncanonical representation in the candidate.

## End-to-end relevance and falsification

The latest completed owner grouped A/B remains unchanged and all four
non-warm raw-log hashes recheck. New-arm proving **34.861/33.315 s**, witness
**5.43/5.76 s**, serialization **.031/.020 s** give known readiness
**40.322/39.095 s**. Internal verification **.900/.810 s**, from bytes
**.91/.82 s**, separately. Dense synthetic 125M block, two CPU threads,
shared box, candidate with small-slot oracle work; not an enclosing request,
8B result or GPU forecast. Receipt length 40,783,352 B.

The complete softmax slot is **8.601/7.832 s** (21.3%/20.0% of readiness);
its Fp2 multiplication share is **unmeasured**. A+H encode/Merkle totals
**16.739/16.903 s**, using base-field encoding, and does not become faster
merely by replacing Fp2 arithmetic. Other Fp2 consumers also exist, so the
softmax fraction is neither a global bound nor a measured saving. There is
no justified numeric end-to-end speed estimate.

Falsify this lead with native same-source release A/B: independent arrays
and dependent chains, then the actual grouped slot and a complete dense block
with witness/serialization retained. Require old/new samples, canonical bytes,
RNG consumption, refused witnesses and receipt compatibility first. Regressed
slot time or no complete-readiness gain demotes it even if kernel time falls.
All native work is a proposal for the owner under shared build/heavy locks;
no job was launched or queued here.

## Primary sources and disposition

The [2006/471 paper](https://eprint.iacr.org/2006/471), received 2006-12-14,
revised 2007-02-20, gives the older quadratic Karatsuba and complex-square
formulas. Its large-prime timings do not predict Goldilocks performance.

[Plonky3 PR 2098](https://github.com/Plonky3/Plonky3/pull/2098), merged
2026-09-09, reports architecture-specific Goldilocks improvements. Its
[current binomial implementation](https://raw.githubusercontent.com/Plonky3/Plonky3/main/field/src/extension/binomial_extension.rs)
uses dot products for quadratic multiplication/squaring, not this Karatsuba
patch. This is a useful competing design for later bounded accumulation.
The main MIT text was inspected; commit `4faefa9` is displayed in the PR but
its detail fetch failed, so no full commit is claimed inspected. Main raw
files have no verified update date and were not revision-matched to the PR.

[prime-ir issue 409](https://github.com/fractalyze/prime-ir/issues/409), opened
2026-07-29, reports addition/carry overhead in a Poseidon2 GPU workload.
That is an author's diagnostic, not evidence about this BLAKE3 prover.
The [August instruction-wall paper](https://arxiv.org/abs/2608.13696) concerns
GPU databases and supports only the general need to measure instruction cost.
The v0.8.0 release was refreshed; its exposed September 23 timestamp still
lacks a year. Source records retain dates, licenses, URLs and failures.

## Next research experiment

Rotate to proof composition: a tiny fractional-LogUp tree that combines
`(n,d)` pairs as `(nL*dR+nR*dL, dL*dR)`, checked against independently summed
reciprocals. Preserve full-table zero-denominator refusals, zero multiplicity
entries and padding; deliberately demonstrate the root-zero/cross-multiplication
pitfall. At the native `private_block/protocol.rs` helper-to-H commitment seam,
count current helper rows and identify which would actually be displaced.
New circuit/helper/masking work and binding obligations must be charged before
claiming fewer committed rows. This is an architecture feasibility test,
not permission to alter the current relation or compose finished receipts.
