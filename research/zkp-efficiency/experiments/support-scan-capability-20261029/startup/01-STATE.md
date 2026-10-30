# ZKP efficiency explorer — durable state

Cycle 0132 COMPLETE: `20261029T015649Z-e607e256`.
Started 2026-10-29 01:56:49 UTC; checkpoint 02:11:45 UTC.
Deadline 02:16:49 UTC. Next cycle no earlier than 02:56:49 UTC.

No native proving speedup measured. The full loader could reuse checked
raw SHA256 values when construction preserves the bytes exactly. Synthetic
validation passes 5,150 checks and 2,584 negative-control instances across
32 fixtures. At the inspected untied 8B geometry, six weight arrays plus
exp/act save 41,953,792 logical hash-input bytes per layer, or 1,342,521,344
per 32-layer full load. This is 17.23575% of record SHA input, not measured
time, DRAM traffic, peak memory or proof work.

Native reload already skips raw/per-word SHA, creates unhashed records and
compares the actual rebuilt block BLAKE3 with the bound digest. It gains zero
through this seam. Never treat the reader's unchecked manifest want as
authenticated. Reuse requires same-invocation checked bytes, identity maps
and unchanged constructor copies. RoPE's combined hash cannot be assembled
by concatenating finalized component hashes. All existing checks remain.

Useful negative: three 64 MiB FFN hashes/casts remain. An independent-worker
LPT countermodel has unchanged word-SHA makespan at 2/4/8/16 workers. It
refutes proportional byte-to-time claims; it does not measure Rayon or
shared bandwidth. No full-loader peak reduction is established.

Checking: 0.193040 s / 20,280 KiB RSS. Independent source/cost audit:
97 checks, 0.003939 s / 18,920 KiB. One pinned CPU0, nice-19 Core Ultra 9
185H worker; 40 s CPU / 45 s alarm / 256 MiB AS caps, 64 MiB memory estimate.
Seed 202610290132. Separate destination-indexed signed-word reference.
Canonical preimage bytes agree; SHA256 is an explicit block-digest surrogate,
not native BLAKE3. Arbitrary stress tables and small shapes are not admitted
native relations. Optional generated RoPE, full metadata/refusal order,
Rust authority, native RNG/transcript/PCS/receipts and privacy remain untested.
The diagnostic full=false hashes are not a proposed native reload addition.

Six native source pins and seven direction documents are unchanged. D44's
current guard and D45's classifier obligations stand. No classifier item or
heavy job processed. Startup snapshots preserve prior state, findings, all
857 prior sources, latest results and required project docs. Eight LIVE
primary-source records appended, 857 → 865. Pipelonk's primary conference
abstract is accessible; DOI403 remains. ICICLE version-bump commit
6c77775961b0e4dc2be359feec1ac11536c18043 was inspected, not kernel code;
pinned wrapper/LICENSE requests failed with Cache miss. Older foreign
arithmetic/Tinybear, holography accumulation and ZK-Flex hardware were screened.
No external code or author performance was reproduced.

All 48 prior hypotheses remain; rank 7 refined and rank 49 added. Top three:
whole-prover GPU plus verified fixed-context resident 1/2/4/8 workloads;
DD/fidelity context scaling; complete exclusive phase/capacity clocks.

Next OWNER: isolate raw read/SHA, padding/constructors, record SHA, actual
block BLAKE3 and enclosing workload clocks before native work. If material,
review the internal API and run full/reload record, refusal, CS/H-1,
golden/RNG/transcript, independent receipt and privacy gates under locks.
No heavy job queued. Park further loader refinement without phase clocks.

Next LOCAL: read prior support-scan findings, then census
weights_vanish_off_support across constructors and CS1/CS4 stage rechecks.
Test a same-construction immutable support certificate only if repeated
incidence exists. A stale shape or once-checked mutable block cannot justify
skipping checks. This is a research question, not native gate authority.

Experiment: experiments/layer-stream-digest-20261029/README.md.
Handoff: handoffs/20261029-layer-identity-sha.md.
Dated report: progress/20261029T015649Z-e607e256.md.

New independently verified full-stack proofs / passes / positions: 0/0/0.
Actual model context/accelerator: none. Witness, proof, serialization,
verification, startup/prefill, startup fraction, latency/bytes and steady/total
rates are unmeasured. No long prefill, resident proof series or decode.
Larger workloads remain allowed; attention can grow quadratically. Private
8B at >=50 proved tokens/s on RTX 5090 or a named high-end GPU is unachieved.

Historical diagnostic only, not rerun/reverified: non-DD 8B, T128/L32, one
16-thread CPU pass, GPU off; total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s / load 17.595 s; seal 84.824 s
overlaps. Receipt 922,711,264 B; fresh verify 42.709 s plus load 13.681 s.
Startup fraction, isolated serialization and steady slope remain unknown.

Only research outside runtime written. No production, Git, receipts,
calibration, safety gates, reviewer or instruction files changed; no native
build, GPU, install, foreign execution, external message/write, purchase or
escalation. Main/Claude reviews and integrates; no merge. Saved reports do
not imply notification delivery or supervisor liveness.

Final provenance audit: 181 checks PASS, 0.020344 s / 22,220 KiB RSS. All 857 prior sources, 48 prior hypotheses and prior findings preserved; six native pins and seven direction documents unchanged. Final checkpoint UTC: 2026-10-29T02:14:38.149998+00:00.
