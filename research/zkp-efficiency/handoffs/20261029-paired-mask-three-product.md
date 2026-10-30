# Review-only three-product terminal mask-pair dot

Cycle0137, run `20261029T065649Z-ae3c483b`, 2026-10-29 UTC.
**Synthetic algebra passes; no native speedup, build or receipt result.**

Interface: existing `mask_eval(sh: &Shape, p: &Priv, data: &[Fp],
point: &[Fp2]) -> Fp2` in
`/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs`.
The candidate replaces this one function, using the same row_log, logm, c0,
ordered point tail and two fresh reserved base rows. No wire, verifier,
field representation, relation or randomness change is intended.

Patch: [paired-mask-dot.unapplied.patch](../experiments/paired-mask-three-product-20261029/paired-mask-dot.unapplied.patch).
Full candidate, eight native source pins, primitive counts and reproduction:
[experiment](../experiments/paired-mask-three-product-20261029/README.md).
**Uncompiled and unapplied.** Separate from the preceding public-tail cache
patch; do not stack their accounting without another source/validation pass.

For Eq coefficient `(a,b)` and fresh mask words `(x,y)`, accumulate canonical
`A=Σa*x`, `B=Σb*y`, `C=Σ(a+b)*(x+y)`; return `(A+7B,C−A−B)`.
Three variable products replace four per coefficient. Both sums entering the
third product must use canonical Fp addition. Current Fp's canonical-limb
precondition is inherited; no lazy/wide representation is proposed.

Per N-word pair, removed: N variable products/reductions. Added versus a
baseline already allowing U multiplication to simplify: N−1 net canonical
additions and two subtractions, with different dependency chains. Paired
source traversal accesses Eq components once instead of twice; all 2N
private word reads remain. Eq construction and all CFS/PCS work remain.
No persistent scratch/cache is added; actual register/peak/instruction and
DRAM changes are unknown. Pairing-four is an independent control for a
single scan without arithmetic-product reduction.

Validation: 7,399 checks / 168 fixtures / 18 negative-control families;
independent unbounded schoolbook Fp2, original Boolean-cube and MSB-fold
oracles. Rows8,192/16,384 are synthetic row lengths, not contexts. Extreme,
random, base/extension/Boolean/max/zero challenges, row widths, subrow
offsets, separate pairs and ordered extension terminal bytes pass. Model
3.984581 s /32,852 KiB. Source/count/patch audit495 checks,
0.185084 s /17,528 KiB. One CPU0 nice19 CoreUltra9 185H worker;
seed202610290137;40sCPU/45salarm/50sparent/256MiBAS/96MiBestimate.

Owner first: isolate native Eq construction, real/imag row dots, complete
extension and enclosing proof clocks; inspect optimized incumbent, paired4
and paired3 code, then benchmark actual tail lengths. Run under current
shared build/heavy locks if promoted. Require canonical samples/terminals,
native golden, RNG/draw and transcript bytes, accepted and refused witnesses,
PCS/openings/capture/privacy gates, plus archived and fresh independent
receipt verification. The second slice is borrowed earlier in the candidate;
malformed-slice panic/refusal ordering must be checked explicitly. No private
mask, evaluation, pad or opening may be reused across sites or proofs.

HistoricalR4TinyLlamaT128/L22/one16-threadpass, read only: all extension-step
timers sum15.938s/153.072sCPU and13.303s/135.809sRTX4070Laptop-assisted.
Even free deletion of that entire enclosing phase gives only1.116222x /
1.108591x proving-only on those runs, using sums of displayed rounded timers;
these are approximate timer-based counterfactuals. This change removes only a subset;
its exclusive share is unknown. No R12b/8B/high-endGPU forecast. The target
ceiling is `Npositions/(T−C_removed+A_added)` with unknown costs; actual
recurring ≥20ms/newly proved position falsifies50/s for that schedule.

Reject on any value, support, tail/order/c0/width/site, native refusal, RNG,
transcript, PCS, receipt or privacy divergence; no actual removed compiler
work, worse register/peak behavior or no enclosing gain also demotes it.
Whole-prover named high-end-GPU and verified resident1/2/4/8 workloads remain
the first priorities. Main/Claude reviews/integrates; no merge or heavy job
was launched or queued by the researcher.
