# ZKP efficiency progress

Cycle0032 — `20261004T140146Z-7230b465`, checkpoint 2026-10-04T14:20:21.232707+00:00.

**No proving speed improvement measured.** 64 source-derived clause fixtures passed 576 independent original-cube samples against 1,728 candidate samples, 5,280 direct-MLE final values, 192 arbitrary-input clause values, 36 even-lookup values, 128 native declaration checks, 192 independent arithmetic-formula checks, 576 repeated counter checks and 288 adaptive guards. Ten negative controls fired. Final run: 6.607152 s / 17,664 KiB RSS; seed 2026100432, one pinned nice19 Core Ultra 9 185H CPU thread; 59 s wall/CPU and 512 MiB address-space caps. No native proof or proving speed measured.

The corrected actual-clause census narrows the earlier equality result:25,079,832 removed weight multiplications are1.012% of the counted padded n23 scan/fold Fp2 multiplications, or0.894% of source-lowered base multiplications. Brackets and helper arithmetic dominate. These fractions omit setup/protocol work and are not runtime/complete-proof rates. The A_E exemption/plane-order error in the initial prototype is preserved and fixed, with controls. No production patch.

[Experiment](experiments/sc-szc-clause-census-20261004/README.md) · [Owner handoff](handoffs/20261004-sc-szc-clause-census.md). Five LIVE primary source records saved; remote runtime/diff/history failures blocked source inspection only, local work completed.

Accepted independently verified complete private 8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; model passes: 0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are unmeasured. No long-context prefill, repeated resident-model pass or decode proof occurred. The >=50 proved-token/s target remains unachieved. Larger workloads are allowed; attention grows quadratically with context, with fresh masks and full coverage/privacy preserved.

Next LOCAL: exact compiled-denominator Unit/Neg/Scale prototype at argument.rs helper_sum/definition, using this complete-clause cube oracle; include paired/odd multi-term lookups, nonzero tags, arbitrary Fp2 and zero challenges, preparation counts and branch costs. Owner first measures native Eq-weight/helper/bracket/interpolation/fold/reset phases and both witness builds/down, then shared-lock native masked/frozen/fresh independently verified complete-stack A/B. No heavy job queued. Saved reports are local artifacts, not notification-delivery evidence.
