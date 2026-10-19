# ZKP efficiency explorer — durable state

Cycle 0079 COMPLETE: `20261019T111854Z-5ff11116`.
Checkpoint: 2026-10-19 UTC. Next cycle no earlier than **12:18:54 UTC**.
[Dated report](progress/20261019T111854Z-5ff11116.md).
Prior memory/direction: experiments/dzc-use-driven-affine-20261019/startup/.

**No native speedup measured.** Use-driven affine terms lower complete D logical
peak 77→27 Fp2 words (64.94%, 800 logical bytes per active worker), with unchanged
118 endpoint reads / 59 differences and arithmetic. Peak source words 54→4,
derived 18, round accumulator 5. All 59 original tables/folds/finals remain.
Python retains graph/cache values; static native last-use realization is owed.
Baseline is the unintegrated coefficient/lazy/streamed prototype, not installed
native sampling. Generic padded 93→87 / five-limb 101→95; keep-sources 136;
candidate no-memoization 138 reads / 69 differences. Prior negatives retained.

PASS: 30 synthetic fixtures, N2/8/32, seed 2026101979; 1,950 coefficients,
2,145 captured-Rust grid / 390 off-grid values, 90 messages, 1,845 original
finals, 30 relations/aliases/permutations/affine-only drains, 390 charged and
value-independent traces, 12 controls; 681 independent audit checks.
Six live native pins unchanged. Captured complete Rust/catalog with exact
u128 field and Shape/Layout substitutes; independent Python clauses/direct
cube agree. Actual admission/challenges/RNG/transcript/masks/PCS/proofs/privacy
remain owner gates. Both current public T128 catalogs: 35 A columns,
34 lookups, 17 helpers, 59 tables, four limbs / 32 bits, unpadded D.

Coefficient+endpoint add/sub/mul/base: 272/209/331/72. Original folds:
118 reads / 59 writes and 59 each add/sub/mul. Combined 331/268/390/72 excludes
common round reduction/conversion/plan. Main 12.651142s / RSS56,024KiB;
compiler134,256KiB; audit0.587274s / RSS27,840KiB; cost audit0.021398s /
RSS21,592KiB. One nice19 Core Ultra9 185H CPU0, WSL2, each59s CPU/wall and
512MiB address space; no Cargo/GPU/install/foreign execution.

Unapplied handoff: handoffs/20261019-dzc-use-driven-affine.md.
Interface: run.py::lazy_row(raw,p,use_driven=True), prior plan/reduce/convert.
Seam: pinned gpu-zerocheck SC_DZC / SumcheckRounds. Acquire operands before
capturing the accumulator; consume combined aliases once; drain affine-only
sources; no field-value/zero-weight branches. Native registered profiles,
seeded bytes/RNG/refusals, extension/mask/PCS/final-opening order, fresh
verify/tamper, joint-view privacy and enclosing timing remain owner work.
No extra private claims/openings, mask reuse or degree/refusal/privacy change.
D30 dictionary remains a separate unbuilt profile.

NEW actual 8B D clock audit: 32 D rows / 32 blocks in each of three retained
T128 CPU runs. Latest R6/b7: one pass,16 Rayon threads,GPU off,total471.580s,
proof370.137s includes witness94.021/load17.408; seal101.279s;922,711,264B.
D44.833s=9.507% of total. Deleting ALL D caps this CPU diagnostic at1.105058× /
0.299944 diagnostic positions/s versus0.271428. Not this candidate's prediction,
GPU bound or target acceptance. R5b shared606.598s/D61.164;quiet432.539/D43.292
remain separate. Fresh R6 verify34.587+load11.599s;guard146.473062 includes
controls;recheck32.311+load9.903,guard42.276335. Serialization/startup fraction/
steady slope unisolated. Seal fraction is not startup. No receipt reverified
by this researcher.

Distinct latest 8B next-token result: T32/32 blocks/one CPU pass;test230.5s,
prove191.7 includes witness17.3/load14.3,verify43.4;471,285,072B. NEW independent
R3 review at10:58 permits the result to stand;reviewer verify37.7/second
route41.8. Trained privacy acceptance remains pending; no hidden-length/decode.

Ranked hypotheses:
1. OWNER whole-prover GPU D/A and completed resident-pass slopes: broadest
   recurring scope, high cost. Charge traffic/serialization/fresh verify/drain;
   fresh masks/openings. Reject enclosing loss, backlog or privacy failure.
2. NEW LOCAL static named-local Rust realization of the27-word schedule:
   moderate additional cost on unintegrated prerequisites. Charge runtime
   plan/dispatch/scalar scratch/code growth/spills; unchanged coefficients and
   originals. Actual gain unknown. Falsify mismatches, uncharged reads, secret
   dispatch, no actual resource decrease or enclosing loss.
3. OWNER immutable public setup residency: possible startup benefit; slope
   unknown, high measurement cost. Identity/lifetime checks and fresh witnesses/
   masks/openings. Reject stale caches, backlog or no completed-proof gain.
4. OWNER D30 dictionary/lookup-GKR: separate profile, high soundness/privacy cost.

NEXT: research-only static named-local Rust emitter with proof-local runtime
scalar parameters, complete-D differential and lowered scalar DAG/assembly
lifetime audit. No duplicate GPU/heavy job. Rotation next: memory traffic/native
realization and GPU NTT/commitments; retain sumcheck/GKR, lookup/softmax,
batching/amortization, quantization/arithmetic and composition.

Five LIVE records appended422→427. Newly assessed older Min-Reg2023v4;
Bits Under ZK-LLM September29v1, DeepProve softmax/custom license/current
Plonky3 release/RNG and packed-mask repository refreshed. Licensing diff
9d1a53e2ef49ffa2c902b8689cd3c58057a4e662 inspected;May26 via history, not
runtime-code/current-HEAD pin. Cachemiss/InternalError retained. No external
author benchmark reproduced.

New target proofs/passes/positions0/0/0,device none. Target context,steady/total
rates,startup fraction,witness/proof/serialization/verification unmeasured.
No prefill,resident series or decode. Larger workloads allowed; context can
increase attention quadratically. Complete private8B >=50/s on5090/named
high-endGPU remains unchanged/unachieved. Only research files changed;
runtime/production/Git/receipts/calibration/safety/instructions/reviewer files
untouched. Saved reports do not establish delivery.

Final integrity check PASS at 2026-10-19T11:31:24.465053+00:00: 38 checks; prior findings/source prefixes preserved,427 source records parse, named native/owner pins unchanged, resource limits and deadline met. Artifact manifest saved in the experiment.
