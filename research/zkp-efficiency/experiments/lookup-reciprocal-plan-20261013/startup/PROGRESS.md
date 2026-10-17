# ZKP efficiency progress

Cycle0045 — `20261013T022555Z-d570e67c`, checkpoint 2026-10-13T02:44:25.101210+00:00 UTC.

**Exact native-root shift arithmetic passes; no proving speed gain measured.**
A bounded CPU experiment checks all192 power2 exponents, unchanged generator7
forward/inverse twiddles, independent DFT/RS references,33 hiding rows including
pad overlap, and the native two-pass tile indexing at4096/8192/16384 points.
38,592 shift checks,8,190 table/dispatch checks,24,570 stage arithmetic checks,
48 independent tile samples and18 controls pass. Validation took1.324346s/
20,208KiB RSS on one low-priority Core Ultra9 CPU thread; no GPU/native proof.
One corrected harness control failure is retained.

At a generic2^20-point full transform,34.9997% of source butterfly products
are shift/identity eligible. Existing zero-pad stage skips lower this;
shifts/carry/dispatch/register costs can erase the gain. Native roots differ
from paper examples, and table/direction provenance must be sealed. These
counts are neither a measured NTT speed nor a complete8B throughput result.

[Experiment](experiments/native-twiddle-shifts-20261013/README.md) and
[handoff](handoffs/20261013-native-shift-twiddles.md) retain code, commands,
source hashes, controls and an uncompiled CUDA helper. First owner candidate:
first6 fused stages plus known inverse scaling; general fallback stays.

LIVE primary searches covered a newly assessed2022 Goldilocks note, current
GPU-NTT interfaces/2026 fixes, a September2026 small-modulus NTT paper and
CUDA release negatives. Four qualified source records added; unknown dates,
failed commit/license fetches and unreproduced author claims are explicit.

Accepted complete private8B proofs/passes/tokens: **0**. Proof context none,
device CPU only. Steady/total-workload rates, startup duration/fraction,
witness/proof/serialization/independent-verification and latency/lag/drain
clocks are unmeasured. No long-prefill, resident-pass or decode proof ran.
The>=50 target, larger-workload allowance, quadratic attention, full coverage,
fresh masks and decided privacy requirements remain unchanged.

Next local action: current SC_SZC denominator/table-reciprocal census with
exact zero/refusal controls and setup/occurrence costs. Owner action: native
correctness/privacy/frozen/fresh-verifier gates, then first6/scale phase and
enclosing/peak A/B under shared locks. No production/runtime/Git write,
heavy/GPU job, dependency installation or external message. Saved reports
are not notification-delivery evidence.
