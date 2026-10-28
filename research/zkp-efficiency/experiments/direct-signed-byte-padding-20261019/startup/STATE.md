# ZKP efficiency explorer — durable state

Cycle0086 COMPLETE: `20261019T181854Z-f5bd1f03`,2026-10-19 UTC.
Next cycle no earlier19:18:54 UTC. Deadline18:38:54 UTC.
[Dated report](progress/20261019T181854Z-f5bd1f03.md).
Startup snapshots:experiments/public-constructor-transfer-20261019/startup/.

Cycle0086 — `20261019T181854Z-f5bd1f03` — 2026-10-19 UTC.

**No speed improvement measured.** Checked public ownership transfer matches
48 synthetic layouts and preserves tested refusal/encoding outcomes. Native
R8 source shows12 vector clones totalling243410944B per8B T128 load that an
owned constructor could avoid. The512B inline activation copy remains.
No native code was modified, built or proved; proposed patch is unbuilt.

Main PASS 7074 assertions / 2200 rejected mutations;
independent audit PASS 1871 assertions /624 output-corruption controls.
Main/audit 12.308901/0.152414s, peaks
30416/26828KiB, one nice19 CPU0 CoreUltra9 185H,
Python3.10.12,WSL2;59s/512MiB caps. These are synthetic validation clocks,
not a native constructor benchmark.18 pins unchanged;14 match frozen R8.

The previous pins4+current/next1.360168GiB ledger excluded loader temporaries.
This cycle counts raw/padded/owned buffers, decode/maps, optional RoPE reserve
and full sealing record hash scratch. Enumerated public-payload envelope with
four distinct pins+current+next load, accounting for16 native hash workers:
**2.016689GiB borrowed ->1.789997GiB moved** [MODEL]. One-worker ledger:
1.852619->1.625927GiB. Not actual RSS/VRAM, complete memory or hardware fit;
private witness/proof/device/allocator/page-cache costs remain excluded.
Evicted live leases from prior findings must still be charged separately.

Carried owner R8 CPU 8B diagnostic: T128,32 blocks,one16-thread pass,
GPU off,n=1. Total478.737s (128/478.737=0.267370 positions/s diagnostic),
prove_run393.785s includes witness hand-over98.348s, itself including17.595s
block loads. Sealing wall84.824s includes overlapping27.151s load tasks and
80.897s witness tasks. Do not add nested/overlapped clocks. Receipt922711264B.
Fresh verify42.709s plus initial load13.681s; recheck34.395s plus10.739s load.
Fresh guard wall165.982s includes controls. Startup fraction, isolated
serialization and steady slope are unmeasured. Researcher did not reverify
a receipt; no new target credit. Owner RSS6.69GiB/cgroup9.76GiB includes
existing allocations; do not add this public ledger to those peaks.

New independently verified complete-stack proofs/passes/positions: **0/0/0**;
device none. Target steady-state/total-workload rates, startup fraction and
witness/proof/serialization/verification clocks: all unmeasured this cycle.
No long-context prefill, resident proof series or decode ran. Synthetic48
fixtures are constructor cases, not proof passes. Larger workloads remain
allowed; attention work can grow quadratically with context. Complete private
8B / >=50 proved positions/s on one RTX5090 or a named high-end GPU is
unchanged and unachieved. No fresh masks, private commitments or openings
were reused or changed.

Owner: review the unbuilt two-file patch, then run locked native constructor
byte/refusal/parity gates and isolate allocation/copy clocks before any claim.
Whole-prover GPU and independently verified fixed-context resident1/2/4/8
workloads stay first. Next local: differential direct signed-byte padding
from Array.bytes versus i8s()+pad_matrix (all256 byte values, interleaved
query-head slots, strides, malformed lengths and zero-pad controls). Account
for whether removing58720256B decode scratch changes the dominant full-loader
peak; do not repeat cycle0027's completed public-digest streaming/cache study.


Ranked hypotheses (full prerequisites/exactness/privacy/falsification in
experiment hypotheses.json):
1.Owner whole-prover GPU + independently verified resident1/2/4/8 workloads.
2.Tested checked public constructor transfer; native port/clock gates pending.
3.Guarded public owner with source freshness and full live leases.
4.NEW next local direct signed-byte padding, no raw decode Vec.
5.Owner same-attempt witness retention with prior negatives and H-1.
6.Owner D30 architecture with D32 fidelity and all privacy/soundness gates.

Seven LIVE source records471->478. Newly assessed older Expander
clone/scratch history has exact diff/code access blocked; no full commit was
inspected. Actual floating LICENSE AGPLv3 read, no code adopted. Known
lookup/quantization papers refreshed; no author results reproduced. Plonky3
release view stale/inconsistent, no newest release or date year claim.
Rotation: next GPU NTT/commitments and sumcheck/GKR; retain lookup/softmax,
memory,batching,quantization/arithmetic,proof composition.

Handoff:handoffs/20261019-public-constructor-transfer.md. Review-only patch
under experiment; UNBUILT/UNAPPLIED. 18pins/14manifest matches unchanged.
Preserve first single-KV control failure and independent scratch-ledger audit
failure; final gates PASS. Prior public-digest streaming/cache cycle0027
remains complete/demoted. Key-only owner, cyclic-LRU and registry-only lease
shortcuts remain rejected. No private masks or openings reused.

Only research written; runtime/production/Git/receipts/calibration/safety/
instructions/reviewer files untouched. Saved reports do not establish delivery.
Checkpoint 2026-10-19T18:31:18.084399+00:00.

Final review: twelve vectors transfer; the512B inline act copy remains in both Rust proposal and corrected Python model. Earlier model preserved. Final gate/provenance checkpoint complete; artifact manifest follows. 2026-10-19T18:32:48.128067+00:00

Final validation PASS: 247 consistency/provenance checks; 18 source/evidence pins unchanged, 14 independently match frozen R8 manifest; original findings/source prefixes preserved. Patch hunks apply in memory only; no Rust compile/proof. Final checkpoint 2026-10-19T18:33:25.417508+00:00.
