# Public owner identity, source freshness and live leases

Cycle0085 — `20261019T171854Z-d589849d` — 2026-10-19 UTC.

**No speed improvement measured.** A complete cache key does not observe
changed backing arrays. The key-only owner fails the streaming oracle's
source-mutation refusal semantics. A guarded owner matches the tested
outcomes but retains every raw source read observation; only construction
is avoided. This does not demonstrate an unsound proof: retained original
bytes still name the original model. It is a native behavior/compatibility
failure if silently substituted for the existing mutable-export loader.

The native seam is seal_and_record -> shared public owner -> BlockCache::get.
The frozen R8 source (15 source/evidence pins,11 matching its manifest) already
shares the current Arc between witness and proving. Full seal validation,
reduced reload, actual block digest checks, CS1/3/4/6/8/9 and H-1 remain owner
port gates. No native patch or merge. D33 covers only trained TinyLlama T32
pg_rot1 CPU R7; R8 needs re-pin, and 8B/GPU/token stages are outside it.
D32 fidelity thresholds remain binding.

The bounded synthetic experiment uses32 public fixtures,13 arrays per layer,
seven5x3 matrices padded8x4 and six1x3 vectors padded1x4. Each layer has123 raw
bytes; these are seeded random public miniatures, not model arrays or field
arithmetic. A tuple-of-bytes owner is immutable. The full19-field identity
includes model/checkpoint/approval/profile/manifest/layer, axes, context,
ordered layer selection, base/own calibration, exp/SiLU keys, RoPE and source
format. This conservative synthetic key is not an admitted native key.

Main PASS: 67404 assertions,4800 synthetic requests,8 controls.
Row-copy construction is compared byte-for-byte to independent elementwise
padding on every request. Mutations to all19 descriptor fields refuse.
All13 raw-array mutations under the ORIGINAL expected identity demonstrate
the key-only stale-source counterexample; guard rejects them. Length,
manifest, table and RoPE changes also refuse. No concurrent-writer/atomic
snapshot guarantee follows from sequential in-memory revalidation.

Separate audit PASS: 2738 assertions,32 fixtures,416 independent
content-mutation controls and64 fresh asymmetric padding fixtures. It imports
no candidate code. The fresh fixtures validate the audit's padding oracle;
they are not additional candidate differential cases. Main/audit clocks
0.450538/0.012894s; peaks
19420/15552KiB. One nice19 CoreUltra9 185H CPU0,
Python3.10.12,WSL2;59s CPU/wall,512MiB address space,64MiB estimate per command.
Exact argv/exits/stdout/stderr are retained in commands.json and*.log.
Seeds2026101985 (main),2026101986 (audit).

Pin4 across8 ordered sealing/proving scan pairs gives60/512 constructor
hits,452 constructions, but512/512 source-read observations remain with
strict revalidation. Public padded native T128 payload count:
243411456B/block. Pinned4 retention973645824B=0.906778GiB; plus current/next
envelope1460468736B=1.360168GiB. These logical counts allocate no model data
and exclude raw decode/pad temporary buffers, private witnesses, proof/device
buffers, allocator and runtime. They are not peak-RSS/VRAM admission.

On an abstract model-generation change, two old blocks remain borrowed.
Charging registry entries only admits four new pins and reaches8 logical
blocks1947291648B=1.813557GiB against a six-block budget. Charging the union
of live owners plus two streaming reserves admits2 and denies2, capped at6.
This is a lifetime stress model, not an observed native concurrency trace.
Eviction is not a deallocation guarantee while Arc borrowers remain.

Baseline is current separate ownership. Removed work: only authenticated
public padding/construction on actual hits. Added costs: all guarded source
reads/hashes, complete identity checks, retained ownership/admission and
temporary overlap. Exclusive construction clocks are absent. End-to-end
ceiling T/(T-s+a), saved exclusive wall s and extra a, is unknown. Do not use
hit ratios as time savings or transfer prior generous all-load deletion bounds
to this guard. Falsify if native refusal/receipt/privacy behavior changes,
memory budget fails, or extra work costs at least the saved construction.

Spartan's inspected historical digest-owner commit is a useful comparison,
not a license to cache native current-file checks. Source census also rules
out an apparent second full digest from protocol::transcript in the trained
streaming route: that call belongs to single-block wrappers. Preserve it.

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

Nine qualified LIVE primary records append sources462->471: newly assessed
Spartan digest-residency commit, older paper boundary, recent Magnetar paper
and announcement, StateSync, BatchZK, ZKProphet, cuda-zkp-ntt and P3 release
filters. Licenses/verified dates/commit scope and access failures are explicit
in source-records.json/search-log.md. No external performance reproduced.

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

Only research files written. No runtime, production, Git, receipt, calibration,
safety, instruction or reviewer files changed. No GPU/build/install/downloaded
code execution, external write/message, purchase or escalation. Saved reports
do not establish delivery. See hypotheses.json and the unapplied handoff.

Prior-findings check before final checkpoint: cycle0027 already tested full public digest streaming/cache and no per-stage model rescan. It remains completed/demoted. The next local task was redirected to raw/padded/owned constructor overlap, which this cycle explicitly excludes.
