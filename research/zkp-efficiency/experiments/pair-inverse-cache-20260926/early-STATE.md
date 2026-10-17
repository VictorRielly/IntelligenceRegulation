# Active cycle 0004 — early checkpoint

Run `20260926T195233Z-cef0b7d6`, started 2026-09-26 19:52:33 UTC.
Read durable findings/source log and newest NTT/KV results. Reading current
project records and helper-phase measurements; planned local experiment is
exact exp/activation pair-table inverse caching with invalid-pair fallback
and full public-table zero-denominator/refusal-order preservation.
One CPU, <=60 seconds, <=512 MiB; research-only writes, no GPU/build/Git.
This run retains its explicit 512-token <=10.24 s target; newer project notes
allow larger workload amortization, recorded without changing this run target.
No outcome or performance claim yet. Finish/checkpoint by 20:12:33 UTC.

---

# ZKP efficiency explorer — durable state

Last completed: **2026-09-26 / cycle-0003**, run `20260926T185233Z-aa002e55`.
Started 18:52:33 UTC; final checkpoint time is recorded in validation.json.
Outcome: **exact mapped-layout oracle + source-derived CUDA pad-overlap repair
candidate; no measured proving improvement**. Research only, no merge.
No next cycle before **19:52:33 UTC**; scheduling belongs to the supervisor.
This file does not establish supervisor/process liveness.

## Fixed target and boundaries

Complete private **8B attention-plus-FFN >=50 proved tokens/s** at the existing
512-token prefill contract: **<=10.24 seconds including witness preparation,
per-proof preparation and serialization**. Five seconds remains a stretch.
Report proving and verification separately. Prefill is not autoregressive decode.
P1 hides inputs, outputs and activations; P3 also hides weights. No complete
private 8B proof timing or enlarged privacy acceptance is established.

Write only this research directory, excluding `runtime/`; read production only.
One-thread CPU experiments <=60 s and <=512 MiB. No GPU, installs, heavy builds,
Git, external writes/messages, escalation or production/reviewer changes.
Main Codex / Claude reviews and integrates. No jobs queued by this cycle.

## Latest evidence

- [Findings](FINDINGS.md) preserves all three cycles, negatives and rankings.
- [Source log](sources.jsonl): six appended records this cycle, native LIVE
  search, exact URLs/dates/license/commit gaps; [search log](experiments/ntt-mapped-layout-20260926/search-log.json).
- [Experiment](experiments/ntt-mapped-layout-20260926/README.md),
  [result](experiments/ntt-mapped-layout-20260926/result.json),
  [validation](experiments/ntt-mapped-layout-20260926/validation.json).
- [Handoff](handoffs/20260926-ntt-layout-and-pad-overlap.md): exact interface,
  unapplied CUDA patch, source hashes and remaining native/device gates.
- Separate session [resource-budget handoff](handoffs/20260926-forward-budget-and-traffic.md)
  preserved. Its arithmetic sensitivity model is not an actual 8B layout,
  hardware measurement or proof result; source records remain in its directory.
- Earlier grouped-equality [handoff](handoffs/20260924-sc-szc-groups.md) and
  both prior experiments remain intact.

## Cycle 0003 result and limits

Synthetic Goldilocks hiding-row encoder: inverse DIF -> pad/coset accessor ->
mixed-radix mapped forward -> logical-column adapter. n=8,16,64; q below,
equal and above n; cosets 7/11; zero/random/edge values. 90 cases, 240 layout
comparisons, 10,560 direct points, 360 Lagrange checks, 15 existing small full
conformance vectors; all 64 column byte strings and chunk streams for five
rows; repeated unsorted gathers. Nine negative controls, three malformed
fixtures. 0.5113 s, 16,968 KiB RSS, one CPU, seed 20260926.

Current CUDA `k_zk_pad_scale`'s exclusive branches omit a negative pad in
n<=i<q. Scalar counterexample n=8,nn=32,q=9,msg=0,pad[8]=1: correct x^16-x^8,
branch x^16. Caller inspected checks n+q<=nn, not q<=n. Proposed three-condition
repair saved, NOT applied, compiled or device-tested. No affected accepted
receipt or privacy break claimed. q<=n controls agree.

Mapped layouts could avoid an EXTRA restore copy; current CUDA already emits
natural order and fuses gathers. No saving from deleting a nonexistent copy.
No native hash/RNG/receipt or production-width transform tested. Proving,
verification and complete readiness are unmeasured (null), not this script's
runtime. D22 remains the accepted CPU toy only; D19b/D23 still proposed.

## Current integration and bottleneck evidence

Latest native grouped candidate record read this cycle: nine CPU validation
steps passed; full suite 512 passed/17 ignored per retained README. Dense A/B
record is `waiting-for-heavy-lock`, no runs. Do not duplicate that job or
infer timing. Status page's older queued-validation note is superseded by
that record. Separate R2a two-thread A/B remains inconclusive.

Separate 22-thread commitment ledger: encode around 51%, allocation/zero
35–39%, column hashing 13–14%; A encode/hash 1.270/0.338 s, H 1.631/0.438 s.
These cannot be combined with two-thread block timings. No full 8B gap inferred.

## Next concrete experiment and rotation

**Next: lookup/softmax exact pair-table inverse cache.** Read current
`private_block/protocol.rs` exp/activation helper seam (inspected native
candidate around 908–943). U8 table caching already exists; do not rediscover it.
For small synthetic public tables and Fp2 challenges, compare full per-element
batch inversion with cached inverses ONLY for exact admitted (index,value)
pairs; arbitrary invalid pairs must fall back to original arithmetic. Include
beta=0/collisions, altered value at a valid index, negative/out-of-range index,
zero denominator at used and unused public pairs, identical refusal ordering,
and later inversion of EVERY public table denominator. Retain helpers and
multiplicity-weighted table values exactly; do not change lookup relation or
challenge scheduling. First read the measured exp+activation helper phase;
report work/traffic counts, never an assumed whole-proof speedup.

Then rotate memory traffic -> batching/amortization -> quantization/arithmetic
-> proof composition -> sumcheck/GKR -> GPU NTT/commitments. The native/device
pad-overlap reproduction is the owner's follow-up, proposed under shared
locks, never an explorer GPU run.

## Source/access qualifications

Qingming CUDA source/README revision mismatch unresolved, license unknown;
MIT from the sibling HIP repo does not apply automatically. GPU-NTT
Apache-2.0 inspected; commit dates from visible histories, abbreviated hashes
only. New 2026 matched-hardware paper abstract inspected; old four-step work
newly assessed. No upstream code executed or speed reproduced. Commit/release
cache misses, LICENSE Internal Error and journal PDF timeout recorded; no bypass.

Resume by reading this state, all FINDINGS/sources and latest results, then
project CLAUDE.md, MVP_STATUS.md, decisions and active coordination. Preserve
prior findings/negative results. Never record actual private model material.
