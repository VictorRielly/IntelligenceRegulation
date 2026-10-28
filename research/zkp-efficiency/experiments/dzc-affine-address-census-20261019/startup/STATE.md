# ZKP efficiency explorer — durable state

Cycle 0082 COMPLETE: `20261019T141854Z-0a847d64`, 2026-10-19 UTC.
Next cycle no earlier than **15:18:54 UTC**. This cycle's deadline: 14:38:54 UTC.
[Dated report](progress/20261019T141854Z-0a847d64.md).
Startup memory: `experiments/dzc-shared-templates-20261019/startup/`.

**Code-size result only; no speed improvement found.** Shared public helper
shapes replace 19 unique bodies with ten, retaining 19 calls and 884 field
primitives on the same 1,167-node DAG. Code falls 145,739→78,421 B, plus 634 B
of maps; instructions 39,737→21,420. Static call-chain span stays 504 B
(scalar baseline 424 B). Logical row bytes rise 8,528→9,162, versus 4,320 for
scalar calls. Physical DRAM traffic unknown. All 59 tables/folds/finals remain.

Nine balanced rotating triplets, 8,192 rows/sample: scalar median 3.7134 µs,
unique groups 4.5428 µs, shared templates 4.6577 µs. Unique/shared ratio
0.975323; only 3/9 pairs favor sharing; pair ratios 0.8004–1.2953. Shared host,
32 cache-resident arbitrary synthetic rows, one parameter pack, artificial
noinline scalar adapters. These are not native-sampler, whole-D, GPU,
quiesced, p95 or proof clocks. Runtime grouping remains demoted.

PASS: six fixtures, two public scalar catalogs, N=2/8/32, seed 2026101982;
780 coefficients, 390 captured-Rust grid/78 off-grid values, 18 messages,
354 original finals, six relations, 36 zero bindings and eight native
controls including compiled wrong-map. Independent 1,455-check address,
initialization, ownership, assembly and source audit passes six controls.
Native field unchanged; captured D/catalog retains documented field/Shape/
Layout substitutes. Actual native admission/challenges/alpha/g_u8, RNG,
refusals, masks, PCS, proofs and privacy remain owner gates. No extra opening
or private randomness reuse.

Main 7.734896 s including compile 5.503053 s;
main/compiler RSS 37,472/147,156 KiB. Audit 0.320312 s;
benchmark including harness compile 1.340532 s. One nice-19 Core Ultra 9 185H
CPU0, WSL2, rustc 1.97.1/LLVM 22.1.6, opt-level 1, one codegen unit. Each
experiment capped at 59 seconds CPU/wall and 512 MiB address space. No Cargo,
GPU, installation or foreign code execution.

Research seam: `grouping.py::shared_plan/emit` → `run.py::emit_arm` →
`kernels.rs::driven(raw,params,bases,out)`. 118 Fp2 endpoints, 129 proof-local
Fp2 parameters, 36 canonical u64 parameters; five coefficients. Parameter pack
2,352 B, scratch 208 B, maps 634 B. Original folds add 118 reads, 59 writes and
59 each add/sub/mul outside row timing. Native seam: SC_DZC / SumcheckRounds.
[Handoff](handoffs/20261019-dzc-shared-templates.md). Main/Claude owns review
and integration; no production patch or merge here.

Ranked hypotheses (full criteria in the experiment's `hypotheses.json`):

1. **Owner: whole-prover GPU D/A and verified resident passes, 1/2/4/8.**
   Broad recurring scope, high integration cost. Measure transfers, PCS,
   serialization, drain and fresh verification. Preserve exact field/profile
   and fresh masks/openings. Falsify enclosing regression, proof backlog,
   verification or privacy failure. GPU/candidate ceiling unknown.
2. **Owner: immutable public-setup residency.** Remove public work only;
   charge identity checks, retained memory, lifetime and transfers. Startup
   and slope partition unknown. Falsify stale setup, private randomness reuse
   or absence of a verified workload gain.
3. **New local question: typed affine address offsets.** Census repeated
   raw/parameter/base address families first; retain arbitrary scratch maps.
   May remove some of 634 logical index bytes/row, adding pointer arguments
   and arithmetic. Small census, moderate implementation cost. Falsify
   non-affine families, changed aliases, secret-dependent planning, no resource
   benefit or enclosing regression. No implementation/speed result yet.
4. **Owner: D30 dictionary/architecture comparisons.** Separate unbuilt profile
   with substantial soundness, hiding and composition review. D10, privacy
   requirements and D32's float-fidelity target stand.

NEXT: bounded independent census of exact typed pointer shifts across the
six- and five-instance families. Stop on non-affine source maps; do not repeat
shared timing without a changed cost. Owner GPU and completed resident
measurements remain first. Rotation: batching/amortization and public setup/
lookup; retain sumcheck/GKR, memory, NTT/commitments, quantization and composition.

Carried R6/b7 CPU 8B diagnostic: context 128, 32 blocks, one 16-thread pass,
GPU off; total 471.580 s, proof region 370.137 s includes witness 94.021 s and
block loading 17.408 s; sealing 101.279 s, D 44.833 s, receipt 922,711,264 B.
Delete-all-D ceiling 1.105058× / 0.299944 diagnostic positions/s versus
0.271428 applies only to that CPU diagnostic. Candidate affects a strict
subset; no enclosing gain measured. Fresh verify 34.587+load 11.599 s;
recheck 32.311+load 9.903 s. Serialization, startup fraction and steady slope
unisolated; sealing is not startup. Four D and five token-owner evidence pins
recheck; researcher did not reverify receipts. Separate T32 next-token clocks
remain in `target-accounting.json`.

Six LIVE records append 442→448: new older function-merger paper, LLVM patch/
talk, recent LLVM 23.1.3 (October 6), refreshed zkLLMPoT v2 (October 11) and
zkIE. Actual LLVM license and preliminary patch commit inspected; release
commit/zkIE HEAD not inspected. Fetch InternalError/Cache miss retained.
LLVM 23 was not installed; no external gain reproduced. Prior findings and
source prefixes preserved.

New target proofs / passes / positions **0 / 0 / 0**, device none. Target
context, steady/total rates, startup fraction and witness/proof/serialization/
verification clocks unmeasured. No prefill, resident series or decode. Larger
workloads allowed; attention can grow quadratically. Complete private 8B /
≥50 proved positions/s on 5090/named high-end GPU unchanged/unachieved.
Only research files written; runtime, production, Git, receipts, calibration,
safety, instructions and reviewer files untouched. Saved reports do not
establish delivery. Checkpoint 2026-10-19T14:31:51.820345+00:00.

Final validation PASS: 150 checks, 52 artifacts; 2026-10-19T14:34:12.546429+00:00.
