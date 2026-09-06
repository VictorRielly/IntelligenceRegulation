# ZK60 round 7 — actual FFN privacy diagnostic and GPU handoff review

Baseline `9cf1372`, branch `perf/zk-batch-optimizations`, 2026-09-06.
Victor requested continuation from the prior handoff. Codex resumed the
unfinished test-only FFN disclosure diagnostic and reviewed Claude's newer
committed response. No subagents were used in this continuation.

## Ownership and scope

Codex owns the new `hashline/src/zk_ffn_mask_diagnostic.rs`, its narrowly
scoped `cfg(test)` observer in `zk.rs`, diagnostic documentation and integration
status/validation handoffs, plus H1 fixture process isolation in
`hashline/src/field/verifier_hardening_tests.rs`. Claude retains GPU/PCS/planner source ownership;
Fable retains the independent privacy/identity review. Neither lane's source
was edited or merged. No production protocol or security parameter changed.

The final release/offline Rust gate passes four new tests. It authenticates
actual FFN proofs and reproduces full tiny X/h16 disclosure under P1/P3,
including fresh OS randomness. At T32 it recovers 256 actual base-field
functionals per plane. See [the diagnostic](ZK60_FFN_MASK_DIAGNOSTIC.md) for
the public-data boundary, exact algebra, negative controls and limits.
They include fresh T32 coverage and strengthened replay controls.

Private pending attention/FFN implementation remains gated on a reviewed
complete mask plan. This work supplies the formerly missing reproduction;
it does not implement a repair or complete an independent audit.

The read-only [GPU review](ZK60_CL1_INTEGRATION_REVIEW.md) first pins `39272d6`.
It credits the CL3/CL4 response and twelve archived full-hash byte gates while
identifying remaining allocation instrumentation, pool lifetime and final
evidence gaps. Claude merged the baseline into its own lane as `25f8b6d`
and resumed further work during this turn; later committed responses receive
their own pinned reviews below. The [CL5/CL9 review](ZK60_CL5_CL9_REVIEW.md)
reproduces a test-order dependency and invalid ranking inputs; those tasks
need follow-ups. Codex separately reproduced and fixed the H1 test isolation
failure exposed by the lane's merged-suite run.
The [CL8/CL10 review](ZK60_CL8_CL10_REVIEW.md) additionally checks their
22 existing tests, reproduces invalid/rounded memory-count cases and corrects
53,248 bytes of mode-dependent artifact attribution using Rust layout counts.
The later `c346236` CL3/CL4 response has also been reviewed. Its CPU
missing-feature refusal is independently reproduced; the revised floor
script has a reproduced Python f-string syntax error, now added to the
pickup list. Allocation/planner corrections and full final evidence remain
with Claude Fable's lane.
The next `9b24975` planner response closes the earlier capacity-transfer and
chunked-return findings; all 25 tests pass independently. A new small CPU
reproduction identifies an unreachable warm-pool refusal, now in the queue.

## Validation

The final runner is `/tmp/zk60-round7/validate.py`, launched with `setsid nohup`.
It queues on `/tmp/zk-heavy.lock`, caps each checked process at 8 GiB address
space, uses two build/Rayon/native threads, disables GPU use and works offline.
Logs and an exit-code marker are under `/tmp/zk60-round7/validation2`.

All **147 Rust tests pass**; the **63 library tests also pass with sixteen
test threads**, exercising the H1 isolation fix. Four diagnostic tests cover
twelve actual FFN proofs and 24 plane observations. All **144 Python/native
tests pass with zero skips** in 929.502 seconds. Four frozen CPU proof
artifacts match their full SHA-256 and exact lengths; the 2,144,946-byte B4
receipt reproves identically and B5 verifies in a separate process. Every
final stage exits zero.

The first full-run attempt in `validation/` passed the library tests but
stopped at an existing CPU schedule gate because the temporary runner set
`HL_GPU=0`, while that gate requires the variable to be absent. The runner
now removes HL overrides and uses the CPU-only build. No schedule-test or
production-source change was made for that runner error; its failure log is
preserved. The fresh run also includes the H1 isolation fix.

The [final evidence](../../results/zk60_round7_validation.json) records exact
commands, source/binary hashes, resource use, proof digests and log hashes.
Logs remain under `/tmp/zk60-round7/validation2`; `validation.done` is zero.
The earlier failed runner attempt remains recorded separately. Source hashes
were checked again at closure. Formatting, whitespace and JSON checks pass.

## Next work

1. Fable independently reproduces the actual FFN finding, inventories all
   joint A/H/W observations and reviews a concrete complete repair.
2. Codex implements the new pending private lifecycle and real arithmetic
   seams after that reviewed plan; public-chain success does not close it.
3. Claude closes the pinned capacity/lifetime/evidence findings and continues
   the existing GPU queue. Any later source needs a new pinned review.

No target benchmark, GPU launch, complete private block, generated-response
proof or 60-tokens/s result is claimed here.
