# ZKP efficiency explorer — durable state

Cycle 0102 COMPLETE: `20261020T101854Z-5d2a545a`.
Checkpoint: 2026-10-20T10:33:40.242944+00:00. Deadline: 2026-10-20 10:38:54 UTC.
Next cycle no earlier than 2026-10-20 11:18:54 UTC.
Evidence: experiments/pcs-small-ntt-census-20261020/.
AGENDA, current target and required durable documents read. Larger workloads
are allowed. Prior state, findings and source ledger are preserved in startup/.

No proving speed improvement measured. Each hiding encode runs an inverse at
log_cols and a forward at log_cols + log2(rate). Frozen R9 TinyLlama contexts
32/64/128 use log_cols 12/13/14; 8B uses 13/13/14. Active GPU has 8B T32 only.
At rate 4, q_pad 256, the guarded sketch halves inverse sector requests at
log_cols 12/13, leaving forward requests unchanged. Per-row pair requests
fall 10% with full-width input or 24.2424%/24.6154% with compact input.
These are summed requests, not physical traffic, cache misses or time.
At current T128 log_cols 14, including DD, neither phase has a request gain.
The mask commitment M has fixed logN 12 and runs on CPU: 50 rows non-DD,
52 DD. Its small size does not establish CUDA incidence.

Final probe: 619 independent integer/address checks, 16 lane/profile entries,
160 role/phase rows, 13 geometries, 444 boundaries, nine wrong controls.
Source audit: 933 assertions, 64 fragments, 48 fragment mutation controls,
16 unchanged pins. No native NTT, tensor-value, transcript, refusal or proof
validation. One CPU thread/core 0, nice 19: probe 3.850 s / 20,620 KiB RSS;
audit 0.284 s / 23,424 KiB. Caps: 59 s CPU/alarm, 60 s parent, 512 MiB AS.
Seed 270536706; exact commands, source hashes and hardware retained.
Checkpoint audit: 57 checks pass; prior findings/source prefixes preserved.

19 ranked hypotheses in this experiment's hypotheses.json. Top three remain:
owner complete high-end GPU plus verified resident 1/2/4/8 passes; DD larger
context scaling after the T128 null; actual capacity and phase measurements.
The all-eleven FZC compiler A/B stays ahead of this conditional small NTT.
Prior large-NTT, bank-pressure, pool, OUT, premature-release, implicit-affine
and carry negatives remain intact. No masks/openings reused or privacy weakened.

Seven LIVE primary records plus one correction, source ledger 591 -> 599.
Caulk+ 2022/957 is a new older applicability screen; subset size is not total
repeated query count; PDF 403. MLE lookup 2024/1058 was already assessed in
0046/0068: exact-URL audit corrected the initial NEW label with original
evidence retained. Publisher date reconciled to January 9, 2025. zkLLMPoT
October 11 v2, LogUp-GKR, cq and DeepProve/Expander metadata were refreshed.
Dates, license/commit scopes and Internal Error/Cache miss limits recorded.
No author performance or external code reproduced. Avoid repeated rediscovery.

Next LOCAL: public per-domain H helper-word and lookup-multiplicity census at
frozen R9 trained DD/non-DD shapes. Pin Shape::h_plane_doms, lookups_at and
argument.rs. Separate cached 256-entry public-table work from recurring private
helper commitments; cost added fractional GKR rounds/final openings before a
prototype. Use independent integer layout and changed-domain, omitted-
multiplicity and boundary controls. No build, GPU or private telemetry.
Next OWNER: actual complete GPU exclusive/enclosing/capacity clocks and
independently verified fixed-context resident 1/2/4/8 passes. FZC compiler A/B
first; small inverse NTT only if measured share warrants it. Shared heavy/build
locks, exact parity/refusals and current privacy/fidelity/soundness gates apply.
Handoff: handoffs/20261020-pcs-small-ntt-census.md. No merge here.

Carried baseline, not rerun/reverified: CPU non-DD 8B T128/L32, one 16-thread
pass, GPU off; total 478.737 s = 0.267370 positions/s. prove_run 393.785 s
includes witness 98.348 s and load 17.595 s; seal 84.824 s overlaps accounting.
Receipt 922,711,264 B; fresh verify 42.709 + load 13.681 s; recheck 34.395 +
load 10.739 s. Startup fraction, steady slope and isolated serialization unknown.
New independent complete proofs/passes/positions: 0/0/0. Actual model context
and device: none. All new witness/proof/serialization/verification clocks,
startup duration/fraction and steady/total rates UNMEASURED. No long prefill,
resident pass or decode. Private 8B >=50/s on RTX 5090/another named high-end
GPU remains unachieved; longer-context attention can grow quadratically.
R9 N-r9-a/b bind; DD privacy owed; D33 frozen-R7 CPU TinyLlama T32 scope is
not extended. Only research excluding runtime written. No production, Git,
builds, GPU, installs, external writes/messages, purchases or escalation.
Saved reports are not evidence of external delivery.
