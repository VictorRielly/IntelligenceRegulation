# ZKP efficiency progress

Cycle 0047 — `20261013T042555Z-29e31968`, checkpoint 2026-10-13T04:42:00.627575+00:00 UTC.

**A selective softmax row-coefficient candidate passes synthetic checks; no
proving speed gain measured.** Computing five coefficients once per padded
SC_SZC row removes 14.94% of counted base multiplications and
16.16% of field operations versus the previous compiled-denominator
baseline, after charging coefficient setup and evaluation. Small host groups
retain their bracket and unpadded profiles retain the baseline. No sample,
relation, mask, private opening or challenge schedule changes.

128 fixtures / 768 schedules pass 6,912 independent round samples and 20,736
direct-MLE finals; arbitrary extension rows, generic lookup denominators,
convolution counts and ten controls pass. Experiment runtime 5.737249s,
17,764 KiB RSS, one nice-19 Core Ultra 9 CPU thread. This is synthetic
algebra/accounting, not a Rust/CUDA proof. Initial all-coefficient regressions
and a failed leading-coefficient control remain recorded.

[Experiment](experiments/sc-szc-row-polynomial-20261013/README.md) and
[owner handoff](handoffs/20261013-sc-szc-row-coefficients.md) identify the actual
SC_SZC definition and grouped row loop. Next owner gate: fixed-array native
translation, masked/frozen/refusal/final/extension parity and fresh independent
verification, then shared-lock peak/enclosing A/B. Compiler behavior and
private temporary/register memory are unknown.

LIVE searches inspected the coefficient factory/wire boundary, September
monomial methodology, extended product sumcheck, a newly assessed older
sumcheck-argument framework and October binary-field package metadata.
Five records added with date/license/commit/access qualifications. Foreign
performance remains authors' claims; blocked PDF/code/commit/license/tag
fetches were retained without bypass.

Historical GPU single-block SC_SZC remains 7.794s within 16.864s proving and
27.523873s whole-test wall. Even deleting the entire phase saves at most
28.317% of that historical wall; the arithmetic fraction supplies no
native time or complete-model speed claim. Native recurring witness work and
complete 8B measurements remain blocked on owner implementation/measurement.

Accepted independently verified complete private 8B proofs/passes/tokens: **0**.
Proof context null; device CPU only this cycle. Steady/total-workload rates,
startup duration/fraction, witness/proof/serialization/independent-verification
and latency/lag/drain clocks unmeasured. No long-context prefill, resident-model
passes or decode ran. >=50/s remains unachieved; larger workloads are allowed,
with quadratic attention accounting, full coverage/privacy and fresh masks.

Next local: suffix-weighted coefficient accumulation before original-sample
evaluation, counting five coefficient weights versus four/five sample weights,
part reduction/setup/scratch and debug/release recovery/zero-factor fallback.
Ranked queue and falsification conditions are retained in the experiment and
FINDINGS. No production/runtime/Git write, build/GPU job, installation or
external message. Saved reports are not evidence of notification delivery.
