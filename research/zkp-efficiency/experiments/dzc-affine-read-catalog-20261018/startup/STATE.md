# ZKP efficiency explorer — durable state

Cycle 0074 COMPLETE: `20261018T032105Z-8464ee28`.
Next cycle no earlier than 2026-10-18 04:21:05 UTC.
Checkpoint: 2026-10-18T03:32:53.063382+00:00.
Report: progress/20261018T032105Z-8464ee28.md.

No native proving speedup measured. AGENDA, target, all durable memory and
current project status/decisions/coordination consulted. Previous state and
source hashes preserved under experiments/dzc-affine-aggregate-20261018/startup/.
MVP is an aggregate-only capture; decisions omit actual inference-token data.
All prior findings and 389 source records preserved; six LIVE records added,
395 total. No production/runtime/Git or other protected files changed.

NEW tested D affine aggregate plus four bilinear terms. Main PASS 96 synthetic
fixtures: N=2,4,16,64; support/base branches; four/five limbs; 1/2/9 lookups.
9,840 captured-Rust clause comparisons and 9,840 enclosing polynomial values;
1,968 folded values; 6,240 original-cube terminal values; 1,032 base constructor
values and 48 base-contract refusals. Eight control checks and two invariants.
Independent PASS 24 fixtures: 1,536 native-basis linear coefficients, 96 bilinear
coefficients, 396 declared-degree round sums, 24 native terminals, seven
corruptions. Seeds 2026101874/75. Synthetic bindings are toy-index based;
five limbs are generic tests, not accepted trained layouts.

Main 3.023713 s including tiny Rust shim compilation; RSS 18,296 KiB, compiler
122,356 KiB. Audit 0.498599 s / 16,104 KiB; cost audit 0.000597 s / 13,920 KiB.
One Core Ultra 9 185H CPU0 thread, nice19, each 59s/512MiB AS. No native
field/PTX/CUDA/full proof/transcript/RNG/privacy or runtime result. Eight source
snapshots and final checks match; no live movement at final source check.

Four-limb current clause: 15 Fp2mul +23 mul_base +39 add +15 sub per point.
Candidate online: 8 Fp2mul +5 add; prepare 26 mul_base +9 add +20 sub; build
33 general or mixed products +34 adds per entry, plus all N-1 extra folds.
Adds16N+608B capacity; original source tables/finals/folds remain. Counted
N2^19/D4/unknown first claim: 285,474,332 ->183,500,687 generic or131,596,175
base scalar products (Rust five-product model only); extra8MiB. N2^21 adds
32MiB; no device timing/DRAM/peak-memory saving inferred. Guard/provenance,
allocation and compiler/scheduling costs need native accounting.

Cost correction: native ClosureRounds uses additive point stepping. Initial
conservative +5-scalar-product/evaluation bound remains in result.json;
source-refined counts are in cost-result.json. Current host slot14 has unknown
first claim and E=D(N-1)+N/2; known initial claim E=D(N-1). Keep registered
D4/D5 and extension rounds; no degree change. GenericN2/known loses63 scalar
products; native none-claim saves18; conservative none-claim loses7. Preserve
these distinct scopes. No nonlinear whole-clause MLE folding allowed.

Unapplied handoff: handoffs/20261018-dzc-affine-aggregate.md.
Seam: owner private_block/argument.rs::SC_DZC (slot14) and
zkp-core/src/sumcheck/rounds.rs::SumcheckRounds. Prototype candidate.py needs
real B/Ids-returned indices. F's device template is slot18; no D device adapter
exists in this experiment. Preserve original finals, helpers/hosts/pad/gates,
CFS/PCS masks, source identity and fresh per-proof coefficients. No cache or
private mask/opening reuse authorized.

Owner R4 small/trained device gates now exited0; seeded proof bytes pass four
shapes. Real TinyLlamaT128 resident known-claim raw F bodies27.921/26.474ms vs
materialized25.964/25.855ms; raw first build72.933ms, warm3.883/3.249ms; raw
round0~9.2ms vs~6.5. Host-upload ladder default486.86ms at n20 includes336MB
H2D. Not a clear body gain and not enclosing steady throughput. No enclosing
R4 stack/fresh-verifier result captured. Do not relaunch owner jobs or change
thermal policy. Aggregate logs/hashes in owner-metrics.json contain no model
inputs/activations/weights/token data.

Carried owner R3 full-stack TinyLlama1.1B T128/22blocks/onepass/16threads,
RTX4070Laptop: default app174.052/process174.196237s, diagnostic0.735412/s;
load13.521,seal0.059,prove132.202 includes15.473witness/11.181reload; inprocess
verify23.290; freshload11.009+check9.394/process20.480536s. Warm app216.500/
process216.656004s,0.591224/s; load29.322,seal0.100,prove153.729 includes
17.952witness/12.785reload; inprocess24.227; fresh13.082+13.067/process26.236683.
Receipt497,665,904B,0declines,VRAM3137MiB. Warm22spins6.6241s recur. Load+seal
7.802%/13.590% are phase shares; startup/serialization/steady/prefill/drain
remain unknown. Shared n1/different settings, no causal A/B or accepted privacy.

All-D26.691s/app174.052 gives a deletion bound1.18113x,0.868615 diagnostic
positions/s; this candidate changes only the clause subset. Actual clause
phase and8B ceiling unknown. Full target cannot follow from scalar counts.

Carried R5b8B T128/32blocks/onecoldCPU pass/16threads/GPUoff/shared n1:
app606.598/process606.728291s,diagnostic0.211013/0.210968positions/s. Seal105.287
(17.357%phase,notstartup) overlaps load36.570/witness103.349. Prove501.126
includes122.694witnessrebuild/21.176reload. Serialization unisolated. Freshload
14.126+check43.902 (18.459reload inside); verifier process186.088255 includes
11controls. Receipt922,711,264B; RSS6.55/cgroup8.47GiB. R5 accepts soundness,
notprivacy; marker-race assignedR6. LatestD25 next-tokenR2 soundness accepted,
privacy/hidden-length/stream still owed; no actual token identifier retained.

Ranked hypotheses:
1. OWNER whole-prover GPU/D/A work, largest measured recurring costs. Charge
   all build/fold/transfer/verify/drain; reject gate failures or no enclosing gain.
2. OWNER immutable public residency/fixed-context fresh-pass slopes. No measured
   steady slope; charge recurring witnesses and fresh private masks/openings.
3. NEW TESTED D affine aggregate: exact synthetic CPU result, moderate adapter
   cost, added scratch; actual clause share/8B ceiling unknown. Reject original
   polynomial/final/refusal/RNG/byte/privacy divergence or net regression.
4. Prior root compression/F constructor: unknown cache/device benefit and
   low phase ceilings; rebase on ownerR4 inline construction, retain negatives.
5. Deferred factored lookup/recursive GKR/newPCS: full state links, commitments,
   masking, helper joint-view, soundness and field compatibility costs required.

NEXT LOCAL: capture real TinyLlamaT128/8BT128 D lookup/helper/host/final catalogs
and B/Ids bindings. Determine whether L can avoid any working-table reads or
only add one stream. Test public table-order permutations, alias and refusal
controls against original full polynomial. Do not discard originals needed
by helpers or final oracle. Owner profiles clause construction/evaluation
before a port; no heavy/GPU job launched here. Rotation next memory traffic /
batching-amortization; retain NTT/commitments,sumcheck/GKR,lookup/softmax,
arithmetic/quantization and composition. Preserve cubic/CSE, slower fusion,
lookup wrapping/offcube/jointmask and all previous negative findings.

LIVE sources: known ZeroCheck/SRAM, EPFL current claim/oracle and Sage concrete
precompute refreshed; NEW older2024/162 recursive-GKR training (receivedFeb4,
lastrevisionJul22,2024), NEW ROSETTASep15,2026 encrypted inference filter; newly
inspected Hekate engine0.37/helper-tree postmortem extends math-onlycycle47.
Release07Octyear unverified; checkdate6Oct2026 explicit. Core/verifier AGPL
label plus actual linking exception read, prover proprietary. Commit fetches,
LICENSE/403/cache failures and exact date/license scopes in sources. None of
the author performance/security claims reproduced or imported.

New target complete proofs/passes/positions0/0/0; context/device none. Target
steady/total-workload rates,startup fraction,witness/proof/serialization/
verification clocks unmeasured. No long-context prefill,resident series or
decode. Larger workloads may amortize valid setup, but attention can grow
quadratically; decode needs proved state. Complete private8B>=50/s on5090 or
another named high-endGPU unchanged/unachieved. No production/runtime/Git,
receipts/calibration/safety/instructions/reviewer writes,installs,heavy/GPU
jobs,external writes/messages or escalation. Saved reports do not prove delivery.
