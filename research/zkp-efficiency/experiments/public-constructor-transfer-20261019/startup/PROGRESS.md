# ZKP efficiency progress

Cycle0085 — `20261019T171854Z-d589849d` — 2026-10-19 UTC.

**No speed improvement measured.** A full public cache key misses changed
backing arrays. The bounded experiment rejected a key-only cache on13/13
source mutations. Revalidation caught them, but retained all512 source-read
observations; pin4 avoided60/512 synthetic constructors over8 scan pairs.
Eviction also leaves borrowed allocations live: registry-only accounting
reached8 blocks against a6-block limit in the generation-overlap stress model.

Main67404 assertions/8 controls; independent audit2738
assertions with416 content mutations and64 fresh asymmetric oracle fixtures.
0.451/0.013s, peaks
19420/15552KiB, one nice19 CPU core; no native proof/GPU.
These measure synthetic byte/identity/lease behavior, not private-model speed.
15 source/evidence pins unchanged. Nine LIVE records appended462->471.

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

Seam: immutable public lease between seal_and_record and BlockCache::get,
with preserved source-mutation refusals, every CS check and H-1. Exclusive
construction/revalidation clocks and actual complete memory remain unknown.
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

[Experiment](experiments/public-owner-identity-20261019/README.md),
[handoff](handoffs/20261019-public-owner-identity.md),
[dated report](progress/20261019T171854Z-d589849d.md).
Only research files changed; saved reports do not imply message delivery.

Prior-findings check before final checkpoint: cycle0027 already tested full public digest streaming/cache and no per-stage model rescan. It remains completed/demoted. The next local task was redirected to raw/padded/owned constructor overlap, which this cycle explicitly excludes.
