# Selective SC_SZC row-coefficient factory — owner review

Cycle 0047, run `20261013T042555Z-29e31968`, 2026-10-13 UTC.
**Synthetic algebra/accounting passed; uncompiled, unapplied, no native speed claim.**

Read [experiment and cost scope](../experiments/sc-szc-row-polynomial-20261013/README.md)
and its result/command/execution/source pins. The candidate removes 14.944% of
counted base products and 16.163% of field API work in the n23/ls3/padded/release
census relative to cycle 0033's compiled-denominator baseline. That denominator
plan remains a prerequisite, not an already integrated native baseline.
Do not add these percentages to earlier experiments or convert them to seconds.

In the current owner copy, prepare the SC_SZC row factory beside its existing
`GroupPoly` in `hashline/src/private_block/argument.rs` around 1724/1782.
The source-derived experiment evaluates the same expression in the polynomial
ring `Fp2[X]` after replacing each table value by `cur[i]+X*dif[i]`. Degree four
needs five fixed coefficients. The lookup offsets are current-proof alpha/tag
plans prepared only after their original draws; retain original lookups for
the S35 oracle/final bracket. Per-row private coefficients die with the row.

Add an optional internal factory to the grouped driver, conceptually:

```rust
// Interface proposal only; not compiled or inserted into production.
type GroupRowFactory = Arc<dyn Fn(
    usize, &[Fp2], &[Fp2], &mut [Fp2; 5]
) -> Option<usize> + Send + Sync>;
// Some(4): coefficients initialized in public degree order.
// None: evaluate the existing GroupPoly at its original samples.
```

Own scratch separately inside each `grouped.rs` part around lines 86..110.
For a padded SC_SZC profile return Some(4) only for group zero; return None
for both host groups. Unpadded profiles should install no factory. Keep the
existing cur/dif scan, host sample loops, suffix weights, folds, declared
degrees, recovery/inverse-zero fallback, mask extensions, pending claims,
transcript and final bracket initially. At sample zero read coefficient zero;
at each remaining required public integer t use Horner with `mul_base(t)`.
The transmitted vector, including interpolation above the bracket degree,
must remain byte-identical. Scratch must never be shared mutably by the Arc.

Use fixed public lengths and first-write convolution initialization. Do not
trim coefficients or branch on private zero values. The prototype uses 200
full multiplies/21 base multiplies/174 adds/86 subtracts to construct group zero
per row; retained output is 80 logical bytes, not a peak bound. Charge input
carriers, temporaries, allocations, coefficient copies and GPU register/spill
costs. Integration may be slower despite the arithmetic count reduction.

Validation retained here: 128 fixtures, 768 chunk/debug schedules, 6,912
independent round samples, 20,736 direct-MLE finals, 1,536 arbitrary row values,
948 general lookup denominators, 100 convolution values and 48 prior census
matches; ten controls fire. Both declared supports, A_E pad exemption, ordered
limb/plane powers, odd helpers, skipped sample 1, explicit debug sample 1,
648 zero-factor fallbacks and 1,080 recoveries are exercised. An initial
all-coefficient regression and a zero-leading-coefficient control failure are
retained. A declared leading coefficient can be zero in early rounds because
the public mask is constant there; this does not authorize deleting a sample.

Owner gates: native fixed-array arithmetic against original bracket at all
registered shapes and full-extension points; debug/release masked bytes,
challenge/final/RNG continuation parity; frozen legacy/tagged receipts;
malformed/honest witness refusal parity; mask extension and full PCS binding;
fresh-process independent verification. Refusal schedule must remain unchanged,
including all lookup poles and future/padded attention positions. No masks,
private openings or challenge-dependent plans may be reused across proofs.
Whole-proof privacy acceptance and P3 remain separate unresolved obligations.

Only after correctness gates, propose shared build/heavy-lock native peak and
enclosing A/B runs. Record bracket/convolution/Horner/weight/fold/recovery,
both witness paths, serialization, startup boundary/fraction and independent
verification. Complete 8B steady/total rates remain unknown; this cycle counts
zero proved tokens. Main/Claude reviews and integrates; researcher does not merge.

Next local refinement: aggregate suffix-weighted row coefficients before sample
evaluation, with five coefficient weight products charged versus the current
four/five per-sample weight products, part reduction and recovery/fallback.
Keep original integer samples and final relation; reject higher total cost.
