# Unapplied public owner compatibility handoff — 2026-10-19

Run `20261019T171854Z-d589849d`. Conditional construction-only candidate; no native speed gain.
Research patch: experiments/public-owner-identity-20261019/experiment.py,
PublicPool/Owner and lifetime_trace; independent audit.py. No Rust/CUDA patch.

Native interface for the owner to review: accept an authenticated public layer
request, return an immutable Arc<BlockPublic> lease, and charge allocation
identity until every borrower releases it. Share ownership across
trained_block.rs:seal_and_record (2034) and BlockCache::get (1797); caller
construction at2587 currently starts a separate cache. Admit a fixed public
pinned subset with native streaming fallback. Cache key must bind full model,
manifest,actual bytes,layer/table/geometry/RoPE/source identity, with the actual
layer-range/base-calibration selection. Synthetic19-field key is conservative,
not a checked native schema. Preserve all actual CS checks and H-1 ordering.

Key-only hits do NOT preserve source-change refusals:13/13 changed backing
arrays are accepted by retained owner, refused by streaming. This is NOT an
accepted proof of different weights; the owner still carries original bytes.
Under existing mutable-export semantics use independent current-source
validation, or retain native reload. Do not silently substitute snapshot
semantics. A future explicit immutable-source backend could define a reviewed
source contract, but its mutation/control behavior and native gates need owner
review; this cycle gives no authorization to change them.

Guarded synthetic hits leave512/512 source reads at8 scan pairs; pin4 avoids
60/512 padded constructors. New hashing/validation may exceed native reload
cost because current reload intentionally skips per-array SHA and recomputes
the actual block digest. No savings inferred without clocks.

Pin4 native-sized public backing0.906778GiB; with current/next envelope
1.360168GiB before all raw/padding/proof/private/device memory. On model change,
two old leases + four new pins + two streaming reserves is1.813557GiB;
registry-only accounting exceeds the stated six-block budget. Charge union
of distinct live allocations, pending admissions and temporary buffers.
Stress model only; no native peak or GPU-fit measurement.

Main67404 assertions/8 controls; independent audit2738
assertions/416 content mutations/64 fresh oracle fixtures. Scope is synthetic
public byte padding, identity, guard outcomes and count accounting. Native
CS/H-1/receipt/refusal/transcript/PCS/final/privacy equivalence remains owed.
No witness,RNG,masks,challenge denominators,endpoints or openings in this owner.
P1 public weights only; P3 private-weight reuse requires a separate review.
D33 R7 TinyLlama acceptance does not transfer to R8/8B/GPU; D32 remains.

Carried owner R8 CPU 8B diagnostic: T128, 32 blocks, one 16-thread
pass, GPU off, n=1. Total 478.737 s; diagnostic quotient
128/478.737 = 0.267370 positions/s. Prove_run 393.785 s includes witness
hand-over 98.348 s, itself including block loads 17.595 s. Sealing wall
84.824 s includes overlapping load tasks 27.151 s and witness tasks 80.897 s.
The JSON load_seconds is sealing load tasks only. Do not add these nested or
overlapped clocks. Receipt 922,711,264 B. Fresh verify 42.709 s plus initial
load 13.681 s; recheck 34.395 s plus load 10.739 s. The fresh verifier's
guard wall 165.982 s also includes control work, not just basic verification.
Startup fraction, isolated serialization and steady slope are unmeasured.
Researcher did not reverify a receipt and awards no new target credit.

Measure exclusive public read/hash/parse/padding/construction clocks and actual
live-allocation peak; reject if new cost >=avoided construction or any gate
differs. Whole-prover GPU and independently verified resident1/2/4/8 complete
workloads remain the first owner action. Main/Claude reviews and integrates;
researcher performs no native build/proof/merge.

Next local experiment: account for the R8 public loader's raw arrays,
aw/fw padded vectors and new_shaped-owned copies over the full constructor
lifetime. Compare borrowed-copy versus checked ownership-transfer on small
synthetic shapes with true-head permutation, zero pads and invalid-support
controls; derive a conservative public peak including current/next loads and
retained pins, without allocating model data. Preserve every constructor/CS
check and native reload/refusal. This closes a memory exclusion in the present
ledger. Cycle0027 already completed canonical public digest streaming/cache;
do not repeat it or claim a second stage hash from single-block wrappers.
Owner priority remains whole-prover GPU plus independently verified fixed-
context resident1/2/4/8 complete workloads under shared heavy locks.

New independently verified target proofs/passes/positions: **0/0/0**;
device none. Target steady-state and total-workload rates, startup fraction,
witness/proof/serialization/verification clocks: unmeasured this cycle.
No long-context prefill, resident proof series or decode ran. Synthetic scan
pairs are public constructor requests, not proof passes or proved positions.
Larger workloads remain allowed; longer context can increase attention work
quadratically. Complete private 8B / >=50 proved positions/s on one RTX 5090
or a named high-end GPU remains unchanged and unachieved.

Prior-findings check before final checkpoint: cycle0027 already tested full public digest streaming/cache and no per-stage model rescan. It remains completed/demoted. The next local task was redirected to raw/padded/owned constructor overlap, which this cycle explicitly excludes.
