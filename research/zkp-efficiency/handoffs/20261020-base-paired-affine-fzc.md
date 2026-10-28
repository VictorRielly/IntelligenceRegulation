# BASE paired FZC derivation — review candidate

Cycle0098 `20261020T061854Z-03bda577`. No native patch, compile, GPU or proof
speed improvement. Extends [prior paired proposal](20261020-paired-affine-fzc.md).

Use the existing BASE flag only in `fzs_impl` raw && !FOLD phase1b. Evaluate
GL scalar clauses before multiplying extension mu; PL multiplies each fresh
extension preweighted pad coefficient by the scalar A value/difference.
Derived outputs retain Fp2. Reconstruct hi=lo+dif for the unchanged global
store. Keep all shared stores/barriers and the paired extension fallback.

Reviewable sketch: `experiments/base-affine-fzc-20261020/candidate_base_pair.cuh`;
Python interface `derived(ops,lo,delta,params,support,prepared_pad,base)`.
The sketch depends on cycle0097's `fzs_derived_pair_candidate`; no standalone
compilation is claimed. Host preparation remains per sumcheck in
`DevFzcRounds::new`, after current public coefficients exist. Keep original
parameters and raw-off/split-off/unfused/tail/finals fallbacks. Eight current
native files and prior snapshots match `source-manifest.json` hashes.

Validation: 36 fixtures, 144 rounds, 1,669 checks, 18 negative controls,
90 partial source-cost cases; independent original-slot schoolbook/MLE round
bytes, global high endpoints and original-table finals agree. Synthetic
challenges/data only; no native masks/transcript/PCS/receipt/verifier tested.
Includes out-of-profile Kh stress, not admitted profiles. One CPU thread,
1.555s/16,948KiB final leaf. Commands and hashes in experiment directory.

At illustrative L=2^21/support/k11, versus current raw literal source: remove
44,040,192 base products, 347,078,656 adds/subs and 608MiB logical operand
shared reads. Versus prior paired: remove 37,748,736 products and 304MiB
reads. These are precompiler calls/reads, not GPU performance. No global or
capacity saving; no new barrier. Costs relative to current include fresh
k host Fp2 preweights and <=176 parameter bytes/staging; relative to prior
pair no extra setup. New template/register/occupancy effects unknown.

First establish actual raw/BASE eligibility and exclusive phase fraction f;
even deleting that phase only permits 1/(1-f). No complete throughput ceiling
is measurable here. Existing Host/Public eligibility can inspect coordinates;
do not add secret-value-dependent dispatch/scans or expose private telemetry.
Prefer structural Base source eligibility or preserve the existing reviewed
boundary. BASE never survives an extension challenge. Helpers, coefficient
and derived imaginary components must remain. Fresh masks, draws, owner
lifetimes and one-opening schedule are unchanged obligations.

Owner action: under shared locks, inspect/compile the sketch; tiny A/B with
ptxas registers/spills, eligibility and exclusive/enclosing clocks; native
masked round/next-challenge parity, frozen full receipt bytes and fresh verify;
strict GPU/no silent fallback, refusal/CS/H-1 and current privacy gates.
Reject any mismatch or enclosing regression, or if compiler already removes
the work. D33 does not cover this GPU candidate. R9/DD is a distinct accepted
soundness tree with its privacy gate still owed; no cross-tree acceptance.

Local follow-up: BASE GL-only without new host coefficients may be a cheaper
integration even if its source operation saving is smaller. Compare it next.
Explorer does not merge. New verified full-stack proofs/passes/positions0/0/0;
no actual model context/device; all new proving rates/startup/clocks unmeasured.
