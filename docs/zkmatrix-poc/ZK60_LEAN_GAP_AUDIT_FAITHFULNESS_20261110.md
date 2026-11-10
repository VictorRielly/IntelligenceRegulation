# Lean gap audit, faithfulness: do the statements say the right thing, how much of the real verifier the Lean covers, and how it compares with FlashProve (2026-11-10)

Independent audit, requested by the coordinator for Victor after an outside reader wrote "Partial Lean proofs vs. formal
protocol theorem in Lean". It was written on branch `worktree-agent-adbd2745a7354c11d`, which holds perf's HEAD
`2155ede8`. A second auditor covers the premise register and the hunt for vacuous premises, so this audit leaves both
alone. Evidence: `results/zk60_gap_audit_faithfulness_20261110/`. No library Lean file, no Rust file and no shared doc
was changed.

How to read the labels:
- **PROVED**: a Lean theorem, by name. The audit's own theorems are in `GB_Toys.lean`.
- **CHECKED**: output the audit ran, with its log.
- **READ**: from the source, with file:line. Sections 3 and 4 were read with the help of two read-only helper passes.
  Every line that carries a finding was then opened again and re-checked by the audit itself (listed in §6).
- **ARGUED**: reasoning, not a check.

## 1. In plain words, for Victor

**Do the approved statements say the right thing?** Mostly yes. The shapes are standard and match the approved
English:
- a straight-line extractor that reads the cheating prover's hash queries, chosen before the adversary;
- one simulator that may program the random oracle, chosen before the distinguisher, and never shown the input;
- probabilities over a uniformly random oracle;
- targets below 1 at any realistic query count.

There are two holes in what the gate `ProductionReady` certifies on its own.
1. **The hidden-data list is chosen by whoever writes the instance (GB-1, High).** The statement does not fix what may
   leak. I proved in Lean that a protocol which writes the input in clear text into its public statement passes the
   whole gate, at error 0 and at the approved targets. It passes even for the media app's own model and constraint
   system. It only has to declare "the input" as its leakage.
   - Our real instance declares the right things: only the shapes, T, the block count and the served bit leak.
   - So today the privacy guarantee rests on a person reading five fields of the instance. The proof does not cover it.
2. **The `CircuitIff` part of the gate constrains nothing (GB-9, Medium).** It speaks about a constraint system that no
   other part of the gate mentions. `Statements.lean`'s own trivial system satisfies it for every model. The real
   content of statement 1 lies in knowledge soundness.

**Does the Lean model the classifier the app actually runs? Not yet (GB-2, High).**
- The run-level integer model gives all 26 blocks one shape, and the requantization shifts live in that shape.
- Shieldstral's real export has 17 different shift sets across its 26 layers. The Lean library itself proves this
  (`shield_shift_sets`).
- So the real model is not an instance of the approved `IntModel` as built. No gate theorem can yet be instantiated at
  the real app.
- No concrete Lean value of any model's public data exists, Shieldstral or other. Its validity is always a premise.
- The Lean `forward` has never been run. The value-for-value tests ran a separate executable copy on one small
  synthetic block (GB-8).

**How much of the real verifier does the Lean cover, and how?**

| Part | Status |
|---|---|
| Field arithmetic, transcript, Merkle paths, sumcheck verifier, the opening and `M` checks, both stage verifiers (IN-C, OUT-C), the block-segment decoder, the run's framing | Written in executable Lean and PROVED equal to the models the soundness proofs use. TESTED against Rust on development rungs only: T = 32, one or two blocks, synthetic or seeded weights, a handful of receipts. |
| BLAKE3, and the Rust NTT encoder against the Lean column evaluation | Tested, not proved. |
| A Shieldstral T128 receipt, a 26-block run, any whole receipt | Never checked by any Lean code. |
| The block verifier as a whole | Tested only with a stand-in for its slot definitions, `M` and openings. |
| CLI's statement-identity and floor checks, pre-header checks, run header, block pre-checks, R13 gate-shift checks, boundary openings inside the block loop | No Lean mirror and no test (GB-5). |

**Is any of it a whole verifier?** No. The gate theorems are stated for an abstract verifier record `V` and prover
record `P`. The soundness, completeness and zero knowledge of the run's parts enter as premises:
- `ClassifyOpen`'s O7–O12;
- the covers `halive`, `hdin`, `hdblk`, `hdout`;
- `hread`, `hBal`, `hdzero`.

L34's gate `rt_productionReady_r13` is never applied to the concrete schedule `rtRunClassify`.

**Production acceptance.** You approved "production acceptance by the Lean verifier" (D63 §6.3). That is not
implemented, and cannot be yet: no runnable whole-run Lean verifier exists (GB-4).

**The app's active profile.** It runs the pre-F12 `r16b` binary at run profile `/1`. D65(1) says no soundness claim is
made for such receipts, and no Lean mirror models its `M` check (GB-7). It is not marked production.

**FlashProve, side by side.**

| What | FlashProve | Us |
|---|---|---|
| A closed soundness theorem, `sound_of_verify_at` | Yes. About one concrete Lean verifier `verify`, compiled by Merkle trees and Fiat–Shamir from a concrete Lean IOP. Its only premises are on the public files. Error about q·2^-124 + 2^-101 in the random-oracle model. | No equivalent: the soundness of the parts enters our gate as premises. |
| Completeness and zero knowledge | Proved for the same compiled protocol, at full size. | Premises of our gate. |
| An executable form | Proved equal to `verify` (`theForm_eq_verify`), run inside Lean on 47 real full-size proofs. | None for the whole run. |
| What is left open | The C++ verifier, CUDA prover, committer and parser are tested, not proved. Sixteen conditions on the public files are tests inside `verify`. Exact match is a premise that `verify` does not test. | — |
| Leakage | Fixed in the statement: one served/refused bit or label. | Chosen by the instance (GB-1). |
| Zero-knowledge range | Only within 2^64 queries and 688,127 replies. | Asked for every q and R. |
| Semantic-hiding corollary | None. | Proved generically. |
| Binding | — | Its own statement. |

**What closing the gap takes** (to reach a theorem of FlashProve's shape):
1. One concrete Lean verifier for the classify run, with every part filled in. That covers the header, the pre-header
   checks, R13's `define` and pre-checks, and the boundary openings. The block run must allow a shape per block.
2. The real public data as a Lean value, or as premises tested inside the verifier, as FlashProve does.
3. The parts' soundness, completeness and zero knowledge proved at that instance, so they are no longer premises.
4. An executable form proved equal to that verifier and run on real Shieldstral T128 receipts. Only then can §6.3
   (production acceptance by the Lean verifier) be met.
5. One reviewed page that fixes the instance's `Leak`, `PubOut`, `admissible` and `opensIn`, or a small amendment to
   the statement that fixes the leakage, which is your call.

The 15 files ported from FlashProve are faithful: CHECKED by diff against upstream (GB-17).

## 2. The approved statements, line by line

Sources: `docs/zkmatrix-poc/ZK60_LEAN_PRODUCTION_STATEMENTS.md`, approved 2026-11-04 (D63, with the §6 choices), and
`formal/ZK60Formal/Statements.lean` (READ, all 280 lines).

### 2.1 Definition by definition

**`CircuitIff M A`** (Statements.lean:146-148). It reads: for every W, x, y, (∃ w, `A.Satisfies` W x y w) ↔
(`admissible` x ∧ y = `forward` W x). This expresses the English `circuit_iff`. But in `ProductionReady` the `Arith`
`A` is a free argument that no other field uses.
- `trivialArith` (Statements.lean:271) satisfies it for every model (`trivialArith_circuitIff`, PROVED, in the file
  itself).
- `circuit_field_free` (PROVED, GB_Toys.lean): any `ProductionReady M A P …` gives `ProductionReady M (trivialArith M)
  P …`.
- So this field certifies nothing about the protocol. See GB-9.

**`Complete`** (:153-160). For every W and every admissible x: 1 − εc ≤ Pr over (H, coins) that the honest receipt is
accepted, its public part is the model's, and both commitments open.
- This matches T1a and is stronger than FlashProve's completeness, which takes the output as given.
- It says nothing on inputs the integer model does not admit (GB-16).

**`KnowledgeSound`** (:165-178). The order is ∃ E, then ∀ W q A. E reads (the query log, the statement, the receipt) and
returns (input, two salts). A is a deterministic oracle computation with at most q queries on every path. The event is
"accepted ∧ ¬(admissible ∧ the input opens ∧ the public part is the model's ∧ the hidden output opens)".
- This is the standard straight-line random-oracle knowledge soundness and expresses T1b.
- The extractor is not given the witness, the input or the oracle's table: only the log of the adversary's own queries.
- What it does not cover: an adversary that has seen honest receipts (GB-11).

**`Binding`** (:182-190). No adversary with q queries opens one statement's input commitment, or its hidden-output
commitment, to two different values except with probability εb q.
- The meaning of "opens" is the instance's field `opensIn` / `opensOut` (GB-1).

**`ZeroKnowledge`** (:230-234). The order is ∃ S, then ∀ W q R Dist with `Within q R`; the two-sided bound is
`realProb ≤ idealProb + εzk q R` and back.
- In the real world the distinguisher gets the oracle and honest receipts on inputs of its choice, with fresh coins.
- In the ideal world the simulator answers everything. It sees each request only as (`publicPart (forward W x)`,
  `leak x`), plus W at `init`.
- Order, probability space and the simulator's inputs are right for P1.
- The content depends entirely on the instance's `Leak` (GB-1).
- Under P3 the simulator must not get W; the definition as written hands it W (GB-13).

**`SemanticHiding`** (:239-245). For any prior μ and any property g of the input, an adversary that sees one receipt and
asks q queries guesses g at most as well as the best guess from (the public part, the leakage), plus ε q.
- This expresses T2′. `semanticHiding_of_zeroKnowledge` (PROVED, Assembly.lean:264) derives it from
  `ZeroKnowledge` with R = 1.
- FlashProve has no counterpart.
- Again, it is only as strong as `Leak`.

**`ProductionReady`** (:252-259). It bundles the six. The targets (:262-265) are εc = 2^-40, εs q = q·2^-100 + 2^-100
and εzk q R = q·2^-128 + R·2^-120. No εb target is defined; the comment and every gate use εsTarget.
- All targets are below 1 for q < 2^99 and R < 2^119. That is not an issue at realistic parameters.
- The bundle is satisfiable by a broken protocol (GB-1).

### 2.2 The instance's five free fields, against the approved English

| Field | The gate's instance (`classifyProtocolU` / `classifyModel`) | Approved English | Verdict |
|---|---|---|---|
| `Leak`, `leak` | `ClsLeak` = (T, d, L, served), served = `admissible x` (ProtocolClassify.lean:686-695, ProtocolClassifyU.lean:51-52) | the profile and shapes, T, the fork plan, the served bit, the receipt length | Matches. The fork plan is not relevant: the instance is the sequential D12a run. The receipt length is a function of the shapes. |
| `PubOut`, `publicPart` | the verdict, `ℕ`, published; `HidOut := Unit` (CircuitTokenRun.lean:341-350) | the verdict bits per D58/D61 | Matches. The verdict is ≤ 1 by `classifyArith`. |
| `admissible` | ∃ b, `classifySpec R x = some b`: the integer model does not refuse (:347) | vocabulary range, length | Wider than the English: also every internal range check of the model. See GB-16. |
| `opensIn` | `Cin.OpensU … e`: the Merkle-committed plane decodes with up to e = 24,448 missing columns at R13 (ProtocolClassifyU.lean:56) | a salted commitment opening | Reasonable. The choice between this and L18's all-columns opening is your open ruling D75(1). |
| `opensOut` | `opensUnit` (no output commitment) | the hidden output's commitment | Right for a classifier whose only output is the public verdict. |

Every row was READ by the audit. Today the gate's privacy and commitment content rests on this table, which no theorem
checks.

### 2.3 The modelling choices, each standard and each stated somewhere

- **Random oracle** (D19, D19a, D19b; READ ExecTranscript.lean:45-57, ExecMerkle.lean:185-194). BLAKE3 is modelled as
  one uniformly random function on (key option, message of at most Lq bytes) to 32 bytes.
  - This is standard; FlashProve does the same with BLAKE2b.
  - D19b records that the faithful reading is "BLAKE3's compression function is ideal", which is stronger than D19 as
    first put. You accepted it on 2026-10-17.
  - A detail: `liftH` answers any query longer than Lq bytes with the constant zero digest. This is harmless only if
    the final instantiation picks Lq at least as large as every real query (any Lq < 2^64 can be chosen). Nothing in
    the gate fixes Lq (GB-14).
- **`Weights := Unit`** (CircuitTokenRun.lean:342). The model is baked into the public data R. This is right for P1.
  P3 needs a different statement (GB-13).
- **The integer model is the reference semantics, not the float model.** This is stated in the doc's §1 and is
  standard; FlashProve does the same.
- **Masks are uniform; the honest prover is a Lean specification, not the Rust/Metal prover.** Stated in the doc's §5.
  The same holds for FlashProve.
- **Adversaries are deterministic, unbounded and query-counted. The extractor and simulator are noncomputable.** Stated
  in Statements.lean's header. Standard.

## 3. Lean against the code

### 3.1 The production path (READ)

- The app's active classifier profile is `shieldstral-laptop` (apps/proven-media/deploy.json:12-39).
  - Its binary is `zk60_classify.r16b.release.bin` and its run profile is
    `…private-classify-run-shieldstral-3b-t128-r13-public-row/1` (proven_media/shieldstral_runtime.py:17-21).
  - The profile entry carries no `production` flag. Its privacy statement is accepted (D58).
- The A28 fast profile is marked `production: false` (deploy.json:60).
- The verify call chain:
  - `zk60_classify verify --expect-statement --min-bits 95 …` goes to `classify_cli.rs` `classify_verify_command`
    (:920), then `verify_inner` (:934), then `check_run` (:838).
  - That reaches `verify_classify_run_with` (classify_run.rs:338-500), the sequential D12a verifier.
  - `check-serve` calls the same function (classify_serve.rs:700).
  - The D55 fork-join verifier `verify_run_with_forks` is not on the classify path.
- This tree's source is post-F12: `HL-ZK/2`, and the pre-F12 headers "are retired" (zk.rs:288-289, re-checked by the
  audit). The active binary predates that (GB-7).
- No file of the app, the CLI or the server calls Lean (grep). Production acceptance is the Rust verifier.

### 3.2 The coverage map

| Verifier part (Rust) | Lean mirror | Equal to the model? | Tested against Rust on |
|---|---|---|---|
| CLI door: export digest, statement identity = `--expect-statement`, min-bits floor, tables re-derived, policy, context, B-3 re-render, segments read at counted lengths (classify_cli.rs:838-946); `label`, `input-owner`, the publication path | NONE | — | nothing |
| Pre-header: `rulings_are_built`, `tier.check`, the whole-run floor, block and segment counts, `fits_the_ntt_tables`, `check_tables`, the R13 per-block shape and CS-6 pre-pass (classify_run.rs:340-374) | abstract parameters `preA`, `preB` (ProtocolClassify.lean:404-406). The segment count `countOk` is concrete. | the gate ASSUMES they accept (ClassifyOpen O7, AssembleClassify.lean:226) | nothing |
| The run header `st.transcript()` and the binding (classify.rs:1275-1291) | none; `start` is a parameter | — | L18 reads the binding off a corpus |
| Stage segment decoder `StageSegGeom::decode` | `decodeStage` (StageVerifyExec.lean:106) | PROVED `decodeStage_enc` | L29: 2 segments of one T = 32 legacy-stack dev rung, plus 1 byte-flip negative made in Lean |
| Block segment decoder `wire::decode_segment` | `decodeSegment` (ExecBlockR13.lean:104) | PROVED `decodeSegment_spec`, `decodeSegment_injective` | L17b: 1 segment of a one-block synthetic `r13-h24-wide` fixture, with 13 Rust single changes |
| Framing: position tags, `pb-run-stage` / `pb-run-block` / `B` absorbs, end tags | `segStep`, `runSegs`, `blockFrame` (ProtocolClassify.lean:142-321) | PROVED `classifyVerifyE_ok_iff`, `blockSeg_step_ok_iff` | L18: one rung run, L = 2, transcripts and tags only (31 checks) |
| Stage IN-C `stage_in_c::verify` | `IncV.verify` (StageVerifyExec.lean:292) | PROVED `incVerify_ok_iff`, `incSlots_model` | L29: the same single dev-rung segment (127 checks); no Rust-made negative |
| Stage OUT-C `stage_out_c::verify` | `OutcV.verify` (:360) | PROVED `outcVerify_ok_iff`, `outcSlots_model` | L29: 1 segment and 1 Lean-made negative; L15: 8 slot records |
| Block `verify_core` (protocol.rs:2802-2916) | `blockVerify` (ExecBlockVerify.lean:390) over `BlockParams`, whose `preChecks`, `define`, `maskVerify`, `checkOpening`, `pcsVerify` are fields | PROVED: Fiat–Shamir soundness of the slot sumchecks on the schedule (`shield_block_fs_sound`) | Only with a stand-in (CheckR13Block.lean:161-189, re-checked by the audit): `preChecks := .ok ()`, `define` returns dummy tables and a zero polynomial, `M` and the openings only move the transcript. On one R13-rung block (T = 32, synthetic) plus 12 tampers, and one W16R2-rung block plus 12. The slot arithmetic is tested separately (CheckR13Slots, 408 checks) from Rust's slot IR. |
| `verify_core` pre-checks (`check_constructed`, `check_is_for_shape`, `check_for_shape`); the R13 accuracy registry and gate-shift checks (argument_accuracy.rs:19-22); R13's `define` end to end | none (fields of `BlockParams`) | — | nothing |
| Sumcheck (zkp-core `sumcheck::verify`) | `scVerify` (ExecSumcheck) | PROVED `scVerify_accept_iff`, `exec_sumcheck_fs_sound` | L6: 171 synthetic runs (1,206 checks) |
| The mask commitment `M` (`mask_verify_tagged`) | `maskVerify` (ExecOpeningM, ExecOpeningBlock) | PROVED `maskVerify_ok_iff`; post-F12 weights | L10 (W16R2, corpus bytes no longer in the repository, hash only), L17d (R13 rung, 1 + 5), inside L29 |
| PCS `verify_zk_tagged`, Merkle paths, field, transcript | ExecOpening, ExecMerkle, ExecField, ExecTranscript | PROVED `pcsVerify_ok_iff`, `verifyColumn_iff`, `runOps_chain`. The Lean column evaluation = Rust's NTT encoder is TESTED only (L10-1). | L5 (synthetic, 5,553 checks), L10, L17d |
| BLAKE3 | ExecBlake3 | not proved (the theorems use the random oracle) | official vectors and the Rust crate (L5) |
| Block boundary B_k: `boundary::check_opening`, `pcs::verify_zk_tagged` inside the block loop (classify_run.rs:438-442) | abstract parameters `bndCheck`, `bndOpen`, `paths`, `check`, `digest` of `d12aBlockProf` (ProtocolClassifyR13.lean:53-68) | — | nothing; the same geometry is exercised once, as OUT-C's `B_out`, in L29 |
| D55 fork-join | `forkVerify` (one frame), the `FSTreeD55` model | — | not on the classify path |

**Across all corpora:**
- no receipt exists at Shieldstral T128 or at 8B;
- every receipt is a T = 32 development rung with synthetic or seeded weights;
- no whole multi-segment receipt is checked;
- the largest run is L18's L = 2, and only its framing is checked.

L34 lists "a whole-run comparison with a Rust receipt" as not done.

### 3.3 What the gate theorems are about

All READ, and re-checked by the audit for the last two items.

| Gate | What is concrete | What is abstract |
|---|---|---|
| `classifyProtocol` / `classifyProtocolU` (ProtocolClassify.lean:718, ProtocolClassifyU.lean:45) | the run's skeleton: segment count, tags, carry, frame absorbs | every part of `V : RunV`, `Hdr`, `P`, `Cin` |
| `classifyUExec_productionReady_run_r13` (RunChainUExec.lean:196), the most concrete | the stage skeletons | the stage verifiers' `M`/PCS fields, `preA`/`preB`/`start`, and the block verifier `blk`, which stays fully abstract |
| `rt_productionReady_r13` (RunTrGate.lean:58) | — | an arbitrary `V` and schedule `Rn` |

- For `rt_productionReady_r13`, grep finds `rtRunClassify` only at its definition (RunTrStages.lean:571) and in a
  comment. So the L34 gate has never been applied to the classify run's concrete schedule.
- Every gate takes the parts' soundness (O11a–d), completeness (O8, O9), zero knowledge (O12) and the covers as
  premises. Whether those premises can be met is the second auditor's subject.

### 3.4 The integer model

All READ unless marked otherwise.

- **What the model is.** `classifySpec` = `inSpec`, then `runSpec R.Ps`, then `outCSpec` (CircuitTokenRun.lean:307).
  `runSpec` folds `blockSpec` over a list of `BlockPublic S` that shares ONE `BlockShape S` (CircuitBlock.lean:828).
- **Where the shifts live.** `BlockShape` holds every requantization shift: `sq sk sv ss spv sao sgate sup sprod sdown`
  (CircuitBlock.lean:58-87). `BlockPublic` holds weights, multipliers, RoPE and tables, and no shift (:162-183).
- **Shieldstral's per-layer calibrations.** They are `shieldLayers` (ShapeR13.lean:139-145). `shield_shift_sets`
  (PROVED, ShapeR13.lean:161) gives 17 distinct shift sets among the 26 layers. See GB-2.
- **No concrete public data.** No value of `BlockShape`, `BlockPublic` or `ClassifyRunPublic` is constructed anywhere
  (grep). `S.Valid` and `R.Valid` are always premises (`ClassifyOpen.shape`, `.weights`, `.inPub`, `.outPub`).
- **The model has never been run.** `blockSpec` and `runSpec` are `noncomputable` (CircuitBlock.lean:300, :828), via
  `liftO`'s choice (CircuitStage.lean:32). The approved `forward` has never been run.
- **What L1 actually tests.** L1Check runs separate executables (`ModelInt.lean`: `normRow`, `softmaxRow`,
  `matmulIO`, `rope`) stage by stage on Rust's words.
  - It covers one synthetic block (T = 32, d = 16) and a T = 128 rung at width 16. LOG SAYS: 101,956 and 760,388
    checks, 0 failed (results/zk60_lean_l1l2_20261106/l1check.log:114, results/zk60_lean_l2b_20261106/l1check_rung.log:190).
  - OUT and OUT-C use synthetic heads (992 checks).
  - No theorem says these executables equal `blockSpec`'s pieces: grep finds none, and the L1/L2 doc says so at :320-323.
  - Stage IN's `embedL` was never checked against Rust.
  - No trained 8B, Shieldstral or TinyLlama golden was compared.
- **The lookup tables are parameters.** `exp`, `act` and `cos`/`sin` carry range assumptions only. They are never
  compared with the real tables.
- **How R13 relates to the model.** `blockSat_of_slots_r13` (PROVED) reduces R13's relations to the same `BlockSat`.
  But the step from the accepted R13 slot polynomials to `R13Rels` is the premise `hgdR`, and the tables' half is
  `Poly`/`hPoly` (BlockInstFinal.lean:277-301).
- **`classifyArith`** is a Lean relation (`InSat`, `RunSat`, `OutCSat`) proved equivalent to `classifySpec`. Its tie to
  the Rust slots goes through those premises and the rung tests.

## 4. FlashProve

Sources:
- FlashProve's files at commit 9e2bdd8f, fetched and verified against the git blob hashes of the project's own snapshot
  of the upstream tree (CHECKED: `fetch_flashprove.log`; stored outside the repository at
  `/Users/victorrielly/zk60-artifacts/gap_audit_faithfulness_20261110/flashprove_9e2bdd8f/`);
- its `lean/THEOREM.md`;
- a read-only helper pass over its statement files, with the definitions of `Sound` and `ZeroKnowledge` re-read by the
  audit (VerifiableInference/Statements.lean:84-99, :300-323).

**Axioms not re-checked by the audit.** That would need FlashProve's own toolchain (Lean 4.29.1, an older Mathlib) and
a build of about 16,000 files. That is a large new build, so it was not attempted. Their files end in `#print axioms`
lines (SoundOfVerifyAt.lean:83-84, TheSixLines.lean:369-393), and their docs say the answer is the three standard
axioms (THEOREM.md:381, :457-459).

### 4.1 Their top-level theorems (READ)

- **`VerifierAndGoals.AtTheName.sound_of_verify_at`** (Johnson/Goal/Skeleton/SoundOfVerifyAt.lean:69-74).
  - Statement: at public files Z with `InScope Z`, `readFiles Z = ok pp` and exact match, `Sound (systemOfRecord …
    theDescription Z …) (soundnessErrorInQueries · 1)`.
  - `verify` is ONE concrete Lean verifier (Ladder.lean:400-441): a scope test, a parser, the config readers, then
    `innerCompiledVerifier`, the Merkle and Fiat–Shamir compilation of a concrete Lean IOP `theDescription`.
  - `Sound` (VerifiableInference/Statements.lean:84-99): ∃ an extractor of the weights from the commitment and the
    COMMITTER's query log, ∀ committer and prover (sharing state, query-bounded), Pr[accepted ∧ the output is not the
    model's at the extracted weights] ≤ ε(cq + pq).
  - Error about q·2^-124 + 2^-101.
- **The six lines** (AtFullSide/Face/TheSixLines.lean) are about one committer, prover and verifier, `compile
  (flashProve setup)`, at every public setup:
  - `sound`;
  - `soundAndBinding`, with the same extractor;
  - `completeOnCanServe` at 2^-40;
  - `zeroKnowledgeOnCanServe`: ≤ 2^-154 within 2^64 queries and 688,127 replies, unbounded beyond;
  - `refusedHandsOutNoProof`;
  - `repliesFit`.
- **What they rest on, by their own account** (THEOREM.md):
  - Sixteen conditions on the public files are tests inside `verify`. They are proved to pass only at the library's
    written copy of the files; the bytes on disk are tied to it by a script.
  - Exact match is a premise that `verify` does not test.
  - The side library needs a larger stack, and the independent checker covered only the soundness theorems.
  - Nothing is proved of the C++ verifier users run, the CUDA prover, the committer or the parser.
  - The executable form is proved equal to `verify` (`PV.Ride.theForm_eq_verify`, Johnson/PVR/SoundOfTheForm.lean:87-92)
    and was run on 47 honest and 57 lying full-size proofs.

### 4.2 Our state next to theirs

| Piece | FlashProve | Us |
|---|---|---|
| One concrete Lean verifier of the whole protocol | yes (`verify`) | no: the run skeleton over an abstract `V` (§3.3) |
| A concrete IOP whose soundness is proved inside the theorem | yes (`theDescription`; `keySound`, `entrySound`, `proofSound` proved) | the parts' soundness is premises O11a–d plus the covers; pieces exist (sumcheck FS, openings, Merkle binding, block slot sumchecks) |
| A closed soundness theorem (premises only on public files) | yes | no |
| Completeness and zero knowledge of the compiled protocol | proved, full size | premises (O8, O9, O12) |
| Leakage fixed in the statement | yes (one bit or a 3-way label) | no, an instance field (GB-1) |
| ZK bound for every q and R | no (capped) | asked (target), and proved only up to R ≤ 2^110 per run (D75(2)) |
| A semantic-hiding corollary | no | yes (`semanticHiding_of_zeroKnowledge`) |
| Completeness concludes the output is right and the commitments open | no (takes the output as given) | yes |
| Soundness against an adversary that has seen honest proofs | no | no (GB-11) |
| An executable whole verifier proved equal, run on real proofs | yes (`lean-verify`, 1,287 to 1,532 s per call) | no |
| The production verifier is the Lean one | no (users run `cp_verify`) | approved as a rule, not implemented (GB-4) |
| The real model's data meets the range conditions, by theorem | no | no; and the run model cannot yet hold Shieldstral (GB-2) |
| Error per hash query | 2^-124 | target 2^-100 |

### 4.3 What a theorem of their shape needs here

These are ARGUED from the two maps above.
1. Give the classify run's verifier as one Lean definition with no free part: the header and pre-header checks, the
   block profile with R13's `define` and pre-checks, the boundary openings, and both stages with their `M`/PCS
   filled. Let the block list carry a shape per block (GB-2).
2. Fix the public data, either as a Lean value, or as FlashProve does: premises on the public files that the verifier
   itself tests, with the stored files shown to pass.
3. Prove the run's IOP sound at that verifier, so that `ClassifyOpen`'s O11 and the covers are theorems, not
   premises. Prove completeness (O8, O9) and zero knowledge (O12) for the Lean prover.
4. Prove an executable form equal to it (we have that already for most parts), and run it on real Shieldstral T128
   receipts against the Rust verifier.

### 4.4 The 15 ported files

CHECKED (`diff_ports.py`, `diff_ports.log`). Against upstream at 9e2bdd8f, the only differences are:
- the added header notes;
- the module-path renames in the imports;
- the deletions each header names: `Prob/Count` cut to its part 1, `Code/Third`'s `Enc` section, `Code/Half`'s
  `mca_monomialImage_rsCode`;
- four one-line proof fixes, each stated in its file's header: `haveI` written `have` in `Cnt`, a deprecated name in
  `Interpolation`, `unfold degZ` in `Bivariate`, `exact Iff.rfl` in `Tight`.

No retained statement changed. The README's description (formal/README.md:136-143) is accurate.

## 5. Findings

**GB-1 (High; for Victor and the coordinator). The approved gate is satisfied by a protocol that publishes the
input.**
- `ProductionReady` takes the protocol's `Leak` / `leak` as instance fields, the model's `PubOut` / `publicPart` and
  `admissible` as model fields, and `opensIn` / `opensOut` as instance fields. No field of the bundle constrains them.
- PROVED (GB_Toys.lean, CHECKED iter4.log, only the three standard axioms):
  - `leaky_productionReady`: for every `IntModel` and at every error, a protocol whose statement carries the input in
    clear, with `Leak := Input`, satisfies `ProductionReady` with `trivialArith`.
  - `leaky_productionReady_targets`: the same at the approved targets and at errors 0.
  - `leaky_productionReady_classify`: the same at the media app's `classifyModel` / `classifyArith`, at the targets,
    under the same validity premises the real gate takes.
  - `leaky_publishes_input`: its statement contains the input.
- The approved English (statements doc §4) says the declared leakage "must be listed in the Lean statement". The Lean
  statement leaves it to the instance.
- Mitigation: the real instance's choices match the English (§2.2).
- Fix options, a ruling for Victor since Statements.lean is approved text:
  - (a) a short reviewed file that names the production instance and its five fields, with the gate stated at that
    named instance; or
  - (b) an amendment that fixes `Leak` in the statement, as FlashProve does.

**GB-2 (High; for the coordinator and the run-level lanes). The run-level integer model cannot represent
Shieldstral.**
- `ClassifyRunPublic S` shares one `BlockShape S`, which holds every shift, across all blocks.
- The real export has 17 distinct shift sets in 26 layers (PROVED `shield_shift_sets`).
- So the media app's model is not `classifyModel S R` for any S and R, unless every layer's shift differences can be
  folded into its multipliers within `BlockPublic.Valid`'s 2^14 cap. Nobody has shown that, and it is ARGUED unlikely
  in general.
- No gate theorem can be instantiated at the real app as built. The docs that call `classifyProtocol` "THE Protocol
  INSTANCE of the classify run … Shieldstral T128" (ProtocolClassify.lean:2-3, :709) overstate it.
- Fix: a per-block shape in the run model (a list of `(S_k, P_k)` with common T and d, and boundary planes over the
  common width), or D75(3)(b)'s one-calibration export.
- Not found in any lane's findings.

**GB-3 (Medium; for the coordinator). The gate's verifier is a skeleton over an abstract verifier record.**
- `classifyProtocol(U)`'s `verify` is `classifyVerifyE V`, with `V : RunV` a parameter.
- The most concrete gate (`classifyUExec_productionReady_run_r13`) keeps the block verifier abstract.
- L34's `rt_productionReady_r13` is for an arbitrary `V` and is never applied to `rtRunClassify`.
- `verify_true_iff` ("the instance's verdict is `verify_classify_run_with`'s", ProtocolClassify.lean:738) is a
  definitional unfolding. It is not a tie to the Rust code.
- Docs that say the instance's `verify` "is" `verify_classify_run_with` (ProtocolClassify.lean:717) are stronger than
  the Lean.

**GB-4 (Medium; for Victor). The approved rule "production acceptance by the Lean verifier" is not implemented.**
- D63 approved §6.3.
- No runnable whole-run Lean verifier exists: the header, the pre-header checks, the block profile's parameters and the
  boundary openings are abstract (§3.2, §3.3).
- No Lean code is called by the app or the CLI.
- Nothing is in production, so this is a gap to close before production, not a breach.

**GB-5 (Medium; for the Lean lanes). Verifier checks with no Lean mirror and no test.**
- The CLI door: export digest, statement identity, min-bits floor, table re-derivation, policy and context, the B-3
  re-render, counted-length segment reads, publication, `label`, `input-owner`.
- The pre-header checks: `rulings_are_built`, `tier.check`, the whole-run floor, `fits_the_ntt_tables`, `check_tables`,
  the R13 per-block shape and CS-6 digest.
- The run header and the binding.
- `verify_core`'s pre-checks.
- The R13 accuracy registry and gate-shift checks.
- R13's `define` run end to end.
- The block path depths.
- The boundary audit and opening of B_k inside the block loop.
- READ (§3.2).

**GB-6 (Medium; for the Lean lanes). Every Rust-vs-Lean test is on development rungs.**
- Every test uses T = 32 (plus one T = 128 rung at width 16), one or two blocks, and synthetic or seeded weights.
- No Shieldstral T128 receipt, no 26-block run and no whole receipt has been checked.
- The block verifier is tested only with a stand-in for `define`, `M`, the openings and the pre-checks
  (CheckR13Block.lean:161-189).
- Some corpora are no longer reproducible from the repository: the L10 corpus bytes and the L1 T = 128 trace, of which
  only hashes remain.

**GB-7 (Medium; for Victor and the app lane). The app's active profile is pre-F12 and has no Lean mirror.**
- `shieldstral-laptop` runs `r16b` at run profile `/1` (shieldstral_runtime.py:17-21; deploy.json:12-39).
- This tree retired the pre-F12 headers (zk.rs:288-289).
- D65(1) says no soundness claim is made for classifier receipts until the fix lands, and "old versions are no longer
  proved under".
- The Lean `M` mirror is post-F12. Every Lean result is therefore about `/2` receipts, not the active profile's.
- It is not marked production.

**GB-8 (Medium; for Victor). The doc's claim that the integer model is "tested against our Rust forward pass" is
stronger than what was done.**
- The statements doc §1 and §5 row 2 say the Lean `forward` is run against the Rust witness builder "on the trained
  8B, Shieldstral and TinyLlama goldens; every intermediate value must be equal".
- In fact:
  - the approved `forward` is noncomputable and was never run;
  - L1 ran separate executables, with no theorem tying them to `blockSpec`'s pieces, on one synthetic block and a
    width-16 rung;
  - stage IN was never compared;
  - the tables are parameters;
  - no trained-model golden was compared (§3.4).

**GB-9 (Medium; for Victor). `CircuitIff` in the gate certifies nothing about the protocol.**
- PROVED `circuit_field_free`. Statements.lean's own `trivialArith_circuitIff` discharges it for every model.
- The statements doc calls `circuit_iff` "the lemma that carries the model (the bulk of the work)". In the gate it is
  not tied to the protocol. The model reaches the protocol only through `KnowledgeSound` (via `IOPExtract`,
  Assembly.lean:312-346).
- `classifyArith` is itself a Lean relation. Its tie to the Rust slots is premises plus rung tests.

**GB-10 (Low; for Victor). The two approved texts differ on the zero-knowledge range.**
- The English says the target is "valid for q ≤ 2^64 and R ≤ 2^30" (statements doc §4).
- The Lean asks it for every q and R (Statements.lean:230-234).
- The Lean is stronger. What is proved is R ≤ 2^110 per run (D75(2), open).

**GB-11 (Low; for Victor). Soundness is not stated against an adversary that has seen honest receipts.**
- The adversary in `KnowledgeSound` only queries the oracle (Statements.lean:167). It is not simulation-extractable.
- FlashProve has the same limit (THEOREM.md:369-373).
- With public receipts, a replayed receipt is still a true statement about its root, so this matters only for a
  claim of authorship.

**GB-12 (Low; for the Lean lanes). Stale code citations.**
- ProtocolClassify.lean:6 cites `verify_classify_run_with` at classify_run.rs:246-396. It is now at :338-500.
- Line citations in Lean comments drift as the Rust moves. A grep-able symbol citation would last longer.

**GB-13 (Low; for Victor, P3). `Statements.lean` cannot express P3 as written.**
- The simulator receives W (`Simulator.init : M.Weights → State`, :202).
- `leak` cannot depend on W.
- For hidden weights, the statement needs a weights commitment, the simulator must not get W, and the extractor must
  extract W, as in FlashProve's index binding.
- This needs a new statement before P3, not a proof.

**GB-14 (Info). The oracle's domain cut.**
- `liftH` answers any query longer than Lq bytes with the constant zero digest (ExecMerkle.lean:194).
- The theorems are faithful to BLAKE3-as-a-random-oracle only if the final instantiation takes Lq at least as large as
  every query the verifier and the honest prover make, on any receipt. Any Lq < 2^64 is allowed.
- Nothing in the gate fixes Lq yet.

**GB-15 (Info). What an accept means.**
- An accepted receipt says: some input committed under `inRoot` has the published verdict, and the extractor can recover
  it.
- Nothing in the statements ties `inRoot` to the media item a verifier sees. That tie is the app's (`input-owner`,
  `label`), outside Lean.

**GB-16 (Info). Completeness covers only inputs the integer model admits.**
- `admissible` means the integer model does not refuse: every internal range check passes.
- The served bit equals admissibility. It is a declared leak and a function of the hidden input (D65(2)'s constant
  refusal).
- How often real inputs are admitted is in no theorem. FlashProve's `CanServe` is the same.

**GB-17 (Info). The FlashProve port is faithful.** CHECKED (§4.4).

## 6. The checks the audit ran or re-read itself

- `GB_Toys.lean`: one guarded cpu job per iteration (`run_guarded.py`, `iter.sh`). The final run is iter4: rc 0, 17 s.
  Every theorem is on `propext`, `Classical.choice`, `Quot.sound` (iter4.log:4-8). The source scan for the forbidden
  words finds none.
  - It imports only `ZK60Formal.ZKHybrid` and `ZK60Formal.CircuitTokenRun`.
  - It uses the library's `zeroKnowledge_of_hybrid` and `semanticHiding_of_zeroKnowledge`.
- FlashProve fetch, 29 files, all matching the snapshot's git blob hashes (`fetch_flashprove.log`). The port diff is
  `diff_ports.log`.
- Re-read by the audit, beyond the helper passes:
  - Statements.lean (all);
  - ProtocolClassify.lean:1-300, :560-783;
  - ProtocolClassifyU.lean:40-70;
  - AssembleClassify.lean:205-330;
  - RunTrGate.lean (all);
  - CircuitTokenRun.lean:200-392;
  - CircuitBlock.lean:58-201;
  - ShapeR13.lean:85-163;
  - ZKHybrid.lean:436-700;
  - Assembly.lean:1-53, :255-275, :395-420;
  - ExecTranscript.lean:1-80; ExecMerkle.lean:175-200;
  - CheckR13Block.lean:155-192;
  - zk.rs:284-292;
  - deploy.json:1-70; shieldstral_runtime.py:10-25;
  - the D19, D19a, D19b, D58, D59, D61, D63, D65 and D75 rows of ZK60_DECISIONS.md;
  - FlashProve's VerifiableInference/Statements.lean:80-100, :300-323;
  - the grep for `rtRunClassify`.
- Not done:
  - FlashProve's `#print axioms`, which would need their 16,000-file build;
  - any re-run of the lanes' corpus checkers: their logs are cited, not re-run;
  - the premise register and the vacuity hunt, which belong to the second auditor.
