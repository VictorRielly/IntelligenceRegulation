# ZKP efficiency progress

Cycle0044 — `20261013T012555Z-12f897c1`, checkpoint 2026-10-13T01:41:57.621303+00:00 UTC.

**Symbolic equality passes synthetic checks; no native speed gain measured.**
The current mixed grouped softmax experiment passed32 fixtures/128 schedules,
35 equality-span cases and17 controls. Generic sums, diagnostic reads, ordered
finals and private/public-zero extensions match independent original-cube
references. An additional15-case test confirms that brackets which actually
read equality values retain exact reads. Main validation:16.297098s/22836KiB
RSS, one low-priority Core Ultra9 CPU thread; no GPU or native proof.

At the conditional512-token/h_pad16 geometry, omit192MiB logical equality
storage and12.58million folds. All brackets and other table work remain.
Exact full-cube diagnostic reads can instead add239million basis products;
native affected-phase, diagnostic and peak-memory timing is required.
These counts are neither proving speed nor a full8B result.

[Experiment](experiments/eq-row-dependency-20261013/README.md) and
[handoff](handoffs/20261013-symbolic-eq-grouped.md) retain commands, seeds,
hashes, three corrected harness failures and an uncompiled Rust helper.
The seam is native Eq construction plus grouped row reads, binding and finals;
its dependency metadata must come from the audited slot constructor.

LIVE primary-source searches covered GPIR's2026 cache/batching study,
current CUDA NTT releases and a newly assessed2024 small-point shift NTT.
Three qualified source records were added. Author timings were not reproduced;
failed fetches and unknown release/commit dates are retained.

Accepted complete private8B proofs/tokens: **0**; context none, passes0,
device CPU only. Steady/total-workload rates, startup duration/fraction,
witness/proof/serialization/independent-verification and latency/lag/drain
clocks remain unmeasured. No prefill, resident-pass or decode proof ran.
The50-token/s target and full-coverage/fresh-mask/privacy requirements stand.

Next local action: classify actual native twiddles and test exact shift/carry
arithmetic with original roots/order/cosets. Owner action: native masked,
refusal/frozen/fresh-verifier gates and affected/enclosing/peak timing.
No production/runtime write, heavy job or external message. Saved reports
are not notification-delivery evidence.
