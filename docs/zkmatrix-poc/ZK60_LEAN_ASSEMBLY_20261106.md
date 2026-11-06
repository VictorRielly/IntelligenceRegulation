# D63: the two approved statements assembled, and what is left for a production profile (2026-11-06)

Lean lane (Claude), on perf at 55aacdce. Lean 4.34.1, Mathlib v4.34.1, no new dependency. New file
`formal/ZK60Formal/Assembly.lean`, imported by the library root. `Statements.lean` is unchanged. No Rust and no prover
source changed. Evidence: `results/zk60_lean_asm_20261106/`.

**Update, same day (second lane, §6):** generic lemmas for obligations 3 (`Complete`) and 5 (`ZeroKnowledge`):
honest acceptance of every sub-protocol model, the composition into `Complete`, the random-oracle programming lemma
and the `R`-receipt hybrid. §4.3 and §4.5 are updated; finding A5 (§6.4) needs a ruling or a sharper per-profile
argument.

**Update, same day (third lane, §7): step L5's foundation.** The primitives every profile's verifier uses, in
executable Lean and proved equal to the models: the field and its extension, BLAKE3, the Fiat–Shamir transcript and
the Merkle column check, with an agreement corpus from the Rust code (5,553 checks, 0 failed). Obligation 0 (§4.0) is
updated.

**Update, same day (fourth lane, §8): step L6, the generic sumcheck verifier.** `sumcheck::verify`, `interpolate_eval`,
the eq tables and multilinear evaluations, and the CFS mask with the last-round extension, in executable Lean on L5's
foundation and proved equal to the models (`verify` accepts exactly when `FSSumcheck.lean`'s `scAccept` holds on the
transcript chain's own challenges), with an agreement corpus from the Rust code (1,206 checks, 0 failed). Obligation 0
(§4.0) is updated.

**Update, same day (fifth lane, §9): step L7, Fiat–Shamir soundness of the executable sumcheck verifier.** For any
header of transcript operations, the probability that the executable `sumcheck::verify`, on the code's own transcript,
accepts a false claim against a `q`-query prover is at most L3's bound `T·d/|F|·(1 + p/2^128)²` plus the collision terms,
`T = q + s + 2n + 1` (`exec_sumcheck_fs_sound`); at a slot's shape at most `2^-61`. Finding L6-4 is closed with no
counter premise. Obligation 0 (§4.0) is updated.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms `propext`, `Classical.choice`, `Quot.sound` only), **CODE**
(read off the sources), **ESTIMATE** (arithmetic on the bounds, not proved in Lean).

## 1. In plain words, for Victor

**What this step is.** The earlier lanes proved pieces about our protocol: the circuit lemma (L2), soundness pieces
(L3) and hiding pieces (L4). This lane proves the glue, for ANY model, constraint system and protocol: which pieces,
put together, give your production gate `ProductionReady`. The per-profile proofs plug into this frame.

**Three results, all proved.**
1. **The "learn anything" form follows from zero knowledge, exactly as you approved it.**
   - `semanticHiding_of_zeroKnowledge`: if the simulator statement (T2) holds with error `εzk`, then the guessing form
     (T2′) holds with error `εzk(q, 1)`. That is: for any property of the hidden input, any input distribution, and any
     adversary that sees one receipt and makes `q` hash computations, its success is at most the best guess from the
     public part and the declared leakage, plus `εzk(q, 1)`.
   - No extra premise and no change to the wording.
   - So the `semantic` part of the gate costs nothing per profile once zero knowledge is proved.
2. **Statement 1's "only if" splits into the circuit lemma plus one statement about the constraint system.**
   - The new notion is `IOPExtract`. From a cheating prover's hash log, an extractor recovers an input, an output and a
     witness that satisfy the constraint system, with the statement's commitments opening to that input and output.
   - `knowledgeSound_of_extract`: `IOPExtract` with error `ε` and the circuit lemma give `KnowledgeSound` with the same
     `ε`. The circuit lemma turns "satisfies the constraints" into "is the model's output".
   - This is exactly where L3 ("an accepted proof makes the constraints hold") meets L2 (`tokenRun_circuitIff`).
   - The "if" side is the same: `ArithComplete` (the honest proof is accepted for every satisfiable input) and the
     circuit lemma give `Complete`, and the two forms are equivalent.
3. **The gate.**
   - `productionReady_of`: the circuit lemma, the extraction, completeness, binding and zero knowledge give
     `ProductionReady`.
   - The error terms are monotone (`productionReady_mono`): a profile proved with bounds below your targets meets the
     targets.
   - Binding reduces to the Merkle binding already proved (`merkle_binding`), when a commitment is opened column by
     column (`binding_of_colCommit`).

**No gap in the approved statements was found for these steps.**
- One proof request plus `q` hash queries is exactly the budget `Within q 1`. The semantic adversary's `Bounded q`
  maps onto it with nothing lost.
- The prover's coin is the coin at position 0 of `ZeroKnowledge`'s `q + 1` coin positions.
- Four notes in §3; none needs a change.

**What is left for a production profile** is the list in §4.
- Three Lean instances: the model and constraint system, which exist at W16R2, and the `Protocol` itself (its prover,
  its verifier and its commitments), which does not exist yet.
- Five per-profile theorems:
  - `CircuitIff`: proved at W16R2 for the whole forward pass. It needs a registered W16R2 or W16R3 token-I/O profile.
  - `IOPExtract`: the largest. It is L3's knowledge version plus the layout map, after W16R3's freeze.
  - `Complete`: every sub-protocol's honest acceptance and the composition are now proved generically (§6); the
    instance is left.
  - `Binding`: reduced here to Merkle binding plus a per-profile column map.
  - `ZeroKnowledge`: L4's lemmas are honest-verifier with fixed challenges. The programming lemma, the `R`-receipt
    hybrid and the `Simulator` construction are now proved generically (§6). Left: the per-receipt step under
    Fiat–Shamir, the composition over the run, and the profile's simulator.
- `SemanticHiding` and `KnowledgeSound` then follow from this lane's theorems, with no per-profile work.

## 2. What is proved

All PROVED (`results/zk60_lean_asm_20261106/`):
- `lake -d formal build` is green: 3,433 jobs, no warning, no error, no `sorry` (`full.log`, `check.log`).
- `#print axioms` was run on all 24 theorems below. Each shows only `propext`, `Classical.choice` and `Quot.sound`, or
  a subset (`axioms.log`).
- Every premise is an explicit hypothesis. No `axiom`, `native_decide`, `admit` or `maxRecDepth`.

| Part | Theorem | Statement |
|---|---|---|
| (a) | **`semanticHiding_of_zeroKnowledge`** | `ZeroKnowledge M P εzk → SemanticHiding M P (fun q => εzk q 1)`, for every `IntModel`, `Protocol` and error |
| | `semDist`, `semDist_within` | the distinguisher built from a semantic adversary `A` and a property `g`, for one input `X`: one proof request of `X`, then `A` on the receipt with its hash queries forwarded, then "is the guess `g X`?". It is `Within q 1` when every `A sr` is `Bounded q` |
| | `realProb_semDist` | in the real world its success is `A`'s success on `X`: `realProb W (q + 1) (semDist A g X) = Pr_{H, c}[A(prove H W X c) = g X]` |
| | `prob_coin0` | the coin at position 0 of a uniform coin vector, with an independent uniform first component, is uniform |
| | `idealProb_semDist` | in the ideal world there is ONE function `Φ` of `(publicPart (forward W X), leak X)` and the simulator's coins such that, for every `X`, the success is `Pr_ω[Φ z ω = some (g X)]` |
| | `avg_le` | averaging over `μ`: a success that depends on `X` only through `z` is at most `⨆ B, Pr_μ[B z = g X]` (for each `ω`, `B_ω z := (Φ z ω).getD _`) |
| | `mapOut`, `liftHash`, `runState_mapOut`, `within_mapOut`, `within_liftHash`, `runState_liftHash`, `realProb_eq` | the oracle-computation steps: post-processing a result, running a hash-only computation inside a two-kind one, their budgets and their runs |
| (b) | **`IOPExtract`** (definition) | one extractor `E : log → Stmt → Receipt → Input × Output × Witness × Salt × Salt`, not given the weights. For every prover with at most `q` hash queries: `Pr[verify accepts ∧ ¬(Satisfies W x y w ∧ opensIn s x r ∧ ypub s = publicPart y ∧ opensOut s (hiddenPart y) r')] ≤ εiop q` |
| | **`knowledgeSound_of_extract`** | `CircuitIff M A → IOPExtract M A P εiop → KnowledgeSound M P εiop`: the `KnowledgeSound` extractor is the IOP extractor with `y` and `w` dropped, and `CircuitIff`'s ⇒ direction gives `admissible x` and `y = forward W x` |
| | `ArithComplete` (definition), **`complete_of_arithComplete`**, `arithComplete_iff_complete` | for every `(x, y, w)` with `Satisfies W x y w`, the honest receipt on `x` is accepted, carries `publicPart y` and opens to `x` and `hiddenPart y`, except with probability `εc`. Under `CircuitIff` this is `Complete` (⇐ supplies the witness, ⇒ forces `y = forward W x`) |
| (c) | **`productionReady_of`** | `CircuitIff → IOPExtract εiop → Complete εc → Binding εb → ZeroKnowledge εzk → ProductionReady M A P εc εiop εb εzk` |
| | `productionReady_of_arith` | the same, with `ArithComplete` for `Complete` |
| | `productionReady_mono`, `complete_mono`, `knowledgeSound_mono`, `iopExtract_mono`, `binding_mono`, `zeroKnowledge_mono` | each statement holds for any larger error, so per-profile bounds below the targets (`εcTarget`, `εsTarget`, `εzkTarget`) give the gate at the targets |
| (d) | `ColCommit` (structure), `ColCommit.Opens` | a commitment opened column by column: a root named by the statement; per position the column, its salt and its path; the columns determine the value (`col_inj`) |
| | **`ColCommit.binding`** | opening one statement's commitment to two different values costs a `q`-query adversary probability at most `collBound (q + 2(h + 2)) D`: the reduction picks a position where the columns differ and hands the two openings there to `merkle_binding`, with no further query |
| | **`binding_of_colCommit`** | if `opensIn` and `opensOut` are such openings, `Binding M P` holds with the sum of the two bounds |

**How (a) goes, in one paragraph.**
- Fix the input `X`. The distinguisher asks for one proof of `X` and runs `A` on it.
- In the real world the proof uses the coin at position 0. Hash queries use no coin, so the success is `A`'s success
  on `X` over `(H, c)` uniform.
- In the ideal world the simulator's step receives `(publicPart (forward W X), leak X)`, and nothing after the first
  request depends on `X`. So the success is the probability that `Φ (z_X, ω)` is `some (g X)`, where `Φ` is the same
  for every `X`.
- `ZeroKnowledge` bounds each real success by the ideal one plus `εzk(q, 1)`.
- Averaging over `μ` and swapping the sums, for each simulator coin vector `ω` the map `z ↦ Φ(z, ω)` is a guess `B_ω`
  from the public data alone, so its success is at most the supremum.

## 3. Findings about the approved statements

**A1 (Info): T2 ⇒ T2′ holds as worded, and the quantifier order of `ZeroKnowledge` is what makes it hold.**
- `ZeroKnowledge` is `∃ S, ∀ W q R Dist`: ONE simulator for every distinguisher. The proof uses this.
  - The distinguisher depends on `X` (it asks for a proof of `X` and compares with `g X`). The simulator must not
    depend on it.
  - If the simulator could be chosen per distinguisher, the ideal success could depend on `X` beyond
    `(publicPart (forward W X), leak X)`, and the averaging step (`avg_le`) would fail.
- So the order `∃ S, ∀ Dist` is load-bearing for T2′. Any later edit of the statement must keep it.
- `ProductionReady.semantic` is implied by `ProductionReady.zk`. The field can stay, since it is D63's own wording;
  the assembly fills it in.

**A2 (Info): the extractor of `KnowledgeSound` takes no weights, and `IOPExtract` keeps it so.**
- `KnowledgeSound` is `∃ E, ∀ W …` with `E : log → Stmt → Receipt → …`. `IOPExtract` has the same shape, so that its
  extractor gives `KnowledgeSound`'s by dropping `y` and `w`.
- Under P1 this costs nothing. The extractor reads the committed matrices off the hash log, and that does not need
  `W`; the production model has `Weights := Unit` (`tokenModel`).
- Under P3 the weights would be extracted from their commitment too. That belongs with the P3 statement change already
  flagged (L1L2 findings §8).

**A3 (Low, a reading note): `SemanticHiding` is stated for ONE receipt.**
- The approved Lean text has one receipt, with error `εzk q 1`. Section 4 of the design note sketches T2′ with
  "receipts" and `ε_zk P q R`; where they differ, the Lean text wins (the note says so).
- `ZeroKnowledge` itself covers `R` requests. The same proof with `R` proof requests (of one input, or of inputs drawn
  jointly by `μ`) would give `εzk(q, R)`. That is not formalized here.
- If you want the several-receipt form in the gate, it is an ADDITION to the statement and needs your ruling. Nothing
  in the approved gate is weaker without it, because `ZeroKnowledge` with `R` requests is already in the gate.

**A4 (Info): completeness and binding.**
- Under `CircuitIff`, `ArithComplete` and `Complete` are the same statement (`arithComplete_iff_complete`).
- No Lean lemma yet says that the honest prover is accepted. Completeness is the least developed of the five
  obligations. (Superseded the same day: §6 proves the honest acceptance of every sub-protocol model and the
  composition into `Complete`.)
- `Binding`'s two parts are each a Merkle-binding event once the openings are column by column (§2 (d)). The bound per
  commitment is `collBound (q + 2(h + 2))` over `|D| = 2^256`, i.e. `(q + 2h + 4)(q + 2h + 3)/2^257`.
  - That is below the proposed `εb(q) = q·2^-100 + 2^-100` for every `q ≤ 2^150` and `h ≤ 64`, for the sum of both
    commitments too [ESTIMATE: arithmetic on the bound, not proved in Lean].

## 4. What is left for a production profile

A production profile needs three Lean INSTANCES (`M : IntModel`, `A : Arith M`, `P : Protocol Q D Coins M`) and five
theorems about them. `productionReady_of` then gives `ProductionReady M A P εc εiop εb εzk`.
- The sixth field, `SemanticHiding`, follows from `semanticHiding_of_zeroKnowledge`.
- The `KnowledgeSound` field follows from `knowledgeSound_of_extract`.
- `productionReady_mono` moves the proved errors to the approved targets.

### 4.0 The instances

| Instance | Exists in `formal/` | Missing |
|---|---|---|
| `M` (the integer model) | `tokenModel S R`, `classifyModel S R` (`CircuitTokenRun.lean`; `Weights := Unit`, sound under P1): the whole forward pass, generic in the shape `S` and the run data `R` | the registered profile's concrete `(S, R)`. No W16R2 token-I/O run profile is registered in the code today (`token_io/run.rs:213`; L1L2 findings §14) |
| `A` (the constraint system) | `tokenArith S R`, `classifyArith S R`: `Satisfies` is `TokenRunSat` / `ClassifySat` at the LOGICAL positions, with canonical endpoint words | the same concrete `(S, R)` |
| `P` (the protocol) | **nothing as a `Protocol` instance.** Pieces of the verifier exist as models: `scAccept`, `chainAcceptsW`, `Tree.verOC` / `Tree.Accepts`, `MerkleEnc.Opens`, the opening and `M` tests. Pieces of the prover's view exist in the L4 files. **The verifier's foundation exists in executable Lean (step L5, §7)**: `Fp` / `Fp2` (`ExecField.lean`), BLAKE3 in its three modes (`ExecBlake3.lean`), the transcript (`ExecTranscript.lean`: proved to be `FSChain.lean`'s `ChainEnc`, its challenges `fp2Chal` / `idxChal`), the Merkle column check (`ExecMerkle.lean`: proved to be `Opens`, with `exec_merkle_binding`), and a finite oracle domain for `Q`, the inputs of at most `L` bytes (`QB L`), with `D` the 32-byte digests. **The generic sumcheck verifier exists too (step L6, §8)**: `scVerify` (`ExecSumcheck.lean`: accepts, with the caller's terminal check, exactly when `scAccept` holds on the transcript chain's challenges), `interpolate_eval`, the eq tables and multilinear evaluations (`ExecMle.lean`), the CFS mask's weights and rounds, the extension round and the masked terminal (`ExecCfs.lean`). **Its Fiat–Shamir bound is a theorem about the program (step L7, §9)**: `exec_sumcheck_fs_sound` on the code's own chain after any header, through the reader `codeSt` (`ExecSumcheckFS.lean`), which also serves any "absorb, then squeeze" round protocol (`fs_code_chain_sound`) | `Stmt`, `Receipt`, `Salt`; `Leak` and `leak` (the shapes, `T`, the served bit, and D65(2)'s constant refusal); `ypub`; `opensIn` and `opensOut` (§4.4); `prove` (the Lean honest prover: masks, salts, the transcript); `verify`, the Lean verifier that §6 decision 3 makes production acceptance: on top of the foundation and L6, the receipt decoder, the per-profile slot items (W16R3's batched sumcheck, its terminal identities, and the composition of its sub-protocols on the code's chain with L7's reader, §9.5), the zero-check and LogUp verifier arithmetic, the opening's claim and column-versus-clear-vector checks (the coset NTT), `M`'s test, and the profile's transcript schedule (§7.5) |

### 4.1 `CircuitIff M A`: proved at W16R2

- **Exists:** `tokenRun_circuitIff (hS : S.Valid) R (hR : R.Valid)` and `classifyRun_circuitIff`: stage IN, every W16R2
  block, stage OUT / OUT-C.
- **Missing:**
  - a registered W16R2 or W16R3 token-I/O run profile, so that the concrete `(S, R)` exist;
  - `S.Valid` and `R.Valid` for those values. Today they are the code's shape and door checks, cited and not
    re-derived; for a concrete profile they are finite checks;
  - DD and the sealed-selector variants are not modelled.
- **W16R3:** B1–B3 change no per-position relation (L1L2 findings §5), so `CircuitIff` itself should not change. B3's
  re-indexing of F belongs to the layout map (§4.2, item f).

### 4.2 `IOPExtract M A P εiop`: the largest obligation

This is L3's part: an accepted receipt makes the constraint system hold, for data extracted from the log.

**Exists:**
- Extraction from the hash log:
  - `extract_sound` (`SoundExtract.lean`), `opening_sound_extracted` (`SoundOpeningRO.lean`), `groups_sound_extracted`
    (`SoundGroups.lean`);
  - under Fiat–Shamir: `fs_opening_knowledge`, `fs_opening_knowledge_code`, `opening_extract_fail`
    (`FSOpening.lean`).
- The Fiat–Shamir bound, path by path:
  - `fs_path_run_8B_target` (`FSPathBlock.lean`): `εsTarget q` for every `q ≤ 2^75`, D12a, given its zone premises;
  - `fs_d55_sound_8B_target` (`FSTreeD55.lean`): the D55 tree, `εsTarget (max q ℓT)` (the per-query count; the
    path-wise count per fork is not composed);
  - log-reading states: `fs_chain_wide_flip_composed` (`FSCompose.lean`).
- Each sub-protocol's soundness: the sumcheck, LogUp, the zero-check, the openings, and `M`'s product test.

**Missing:**
- a. **The knowledge version, composed.** The path-wise bound with the matrices `A`, `H`, `M` extracted at each root's
   absorption (L3 Part 7 §V5, Part 9 W5), and per fork on the D55 tree (F31). Today's run theorems are the soundness
   version, for data named by the statement.
- b. **`M`'s opening under Fiat–Shamir.** It is ASSUMED today at a total `≤ 2^-106`, and it waits on F12's fix.
- c. **The run's hand-off premises** (`hhand`, `hframe`, `hstart`, `hfinal`, `hpath`), each a lemma like
   `zc_handover`, from the profile's layout.
- d. **The slots' numerator bound** (F44).
- e. **The stage relations' L3 parts** (L1L2 findings §16):
   - the head and margin sumchecks;
   - the compressed embedding row (a Schwartz–Zippel step over `r_emb`);
   - the selector sums;
   - the byte LogUp.
- f. **The layout map and the boundary links.** The map runs from the committed cube to the logical positions: padding,
   head-slot order, support gating, and W16R3's compact F domain. The links: `B_in` is block 0's input plane, and stage
   OUT reads row `T − 1` of `B_out`. With them, "every claim is true of the extracted data" becomes `tokenArith`'s
   `Satisfies`.
- g. **The endpoints.** The extractor's `(x, y, r, r')` must be read from the input and output endpoint commitments, as
   `P.opensIn` and `P.opensOut` define the openings (§4.4), with canonical words.
- h. **The code-level `ChainEnc`**: keyed BLAKE3, the header's absorbs, the counter offset.
- i. **The error.** `εiop` is the path-wise bound plus the extraction failure terms (`collBound T' + 2T'²/|D|` for the
   run). It must be at most `εsTarget`.

**Waits for:** W16R3's freeze. B1 changes the PCS encoder, B2 the batching and the challenge schedule, B3 the F
indexing. Items c, f, g and h depend on the frozen layout.

### 4.3 `Complete M P εc`: every sub-protocol part is proved generically (§6); the instance is not

- **Route:** `ArithComplete` (equivalent under `CircuitIff`). `CircuitIff`'s ⇐ direction already supplies the satisfying
  witness for an admissible input. `complete_of_checks` / `arithComplete_of_checks` (§6) assemble it from per-check
  failure bounds, `εc = Σ εᵢ`, in exactly the approved form `1 - εc ≤ prHC …`.
- **Exists (§6, PROVED, generic over the models):**
  - every sub-protocol's honest acceptance, at EVERY challenge: the sumcheck (`sumcheck_complete`; on the list verifier,
    `sumcheck_complete_list`, so under Fiat–Shamir at every oracle), the masked and extended sumchecks, the CFS chain in
    the code's coefficient form (`cfs_masked_honest`), the zero-check, batching, the regular opening
    (`opening_complete`), `M`'s product and proximity tests (`mopening_complete`), honest Merkle paths (`opens_honest`)
    and column-commitment openings (`colCommit_opens_honest`);
  - LogUp: honest multiplicities exist and make the identity hold at every fold and every point
    (`logup_identity_honest`); the honest helpers pass (`helperRel_honest`); the honest prover is served and passes
    except with probability `≤ M/|F|`, `M` the distinct table tuples (`logup_block_complete_prob`);
  - the challenge-only refusal `c = 0` of CFS: exactly `1/|F|` (`cfs_refusal_prob`);
  - the Fiat–Shamir step: a challenge read at a point the honest computation has not asked is uniform
    (`fresh_point_prob_le`, `fresh_point_prob_le_coins`); a bound at every coin is a bound on average
    (`prHC_le_of_forall`).
- **Missing:**
  - the Lean honest prover and verifier (§4.0, `prove`, `verify`);
  - per profile: the list of checks `E i` that `verify` runs on an honest receipt, the proof that together they give
    acceptance (the hypothesis `himp` of `complete_of_checks`), and each check's refusal term `ε i`. The terms: per
    LogUp domain `M/|Fp2|`, per slot `c = 0` (`1/|Fp2|`) and the extension challenge `e ∈ {0, 1}` (`2/|Fp2|`, the
    same `prob_mem_finset` step), batching zeros, D66(3)'s dictionary refusal (about `cap·2^-88` per attempt), the
    "`α` equals a table tuple" refusals of IN and OUT (a LogUp refusal: `logupRefuses_iff`);
  - under Fiat–Shamir, that each squeeze point of the honest transcript is fresh (not asked earlier by the honest
    computation), which fails only on a chain-state collision (`collBound`); then `fresh_point_prob_le` turns each
    per-challenge bound into a bound over the oracle;
  - the links from the code's layouts to these models (which claim is which sumcheck, which table which LogUp
    domain), part of the layout map (§4.2 f);
  - `M` with offset `0` assumes the honest `b_m = −b_0` (`mask_open`; CODE, cited, not re-derived).
- Input-admissibility refusals (class B) are outside `Complete`: `tokenModel.admissible` is "the integer model does not
  refuse".
- **Target:** `εcTarget = 2^-40`. Each refusal term is about `2^-111` or smaller (`M ≤ 2^17`, `|Fp2| ≈ 2^128`), so the
  budget holds for any realistic number of refusal sites [ESTIMATE].
- **Waits for:** W16R3's challenge schedule, and the Lean prover and verifier (L5).

### 4.4 `Binding M P εb`: reduced here to Merkle binding

- **Exists:** `binding_of_colCommit` and `ColCommit.binding` (this lane), on `merkle_binding` (`SoundMerkle.lean`, with
  the depth check, D19 T-4).
- **Missing:**
  - define `P.opensIn` and `P.opensOut` as `ColCommit` openings of the input and hidden-output endpoint commitments.
    The opening data `Salt` holds the salts, the paths and the mask rows;
  - prove `col_inj` for their encodings: the data rows' code words determine the plane (the code is injective on
    messages, with `N` above the degree), and the plane determines `x` (or `hiddenPart y`).
- **Bound:** below the proposed target (§3 A4) [ESTIMATE].
- **Waits for:** B1 (coefficient-form rows change the encoder, and so the code argument for `col_inj`).

### 4.5 `ZeroKnowledge M P εzk`: L4's honest-verifier lemmas, the programming lemma and the hybrid exist

**Exists, generic (§6, PROVED):**
- **the random-oracle programming lemma** (`program_real_ideal`, `program_coupling`): programming `k` points derived
  from a fresh salt costs at most `k·q₁·K/|S|` against a distinguisher whose part before the request makes `q₁`
  queries (`K` salts per point; `k·q₁/|S|` when the points are injective in the salt);
- **the `R`-receipt hybrid** for any programming simulator (`ProgSim`): it is a `Simulator` (`ProgSim.toSim`); hybrid
  `0` is exactly `realProb` (`hybProb_zero`) and hybrid `R` exactly `idealProb` (`hybProb_ge`); per-receipt bounds
  give `ZeroKnowledge` with their sum (`zeroKnowledge_of_hybrid`, `R·ε₁` when uniform); the hybrid's table realizes
  the programming lemma's oracle (`ovr_ofFn_program`);
- **the target**: per-receipt `εhv + q·δ` with `εhv ≤ 2^-120` and `δ ≤ 2^-248` gives `εzkTarget`
  (`zeroKnowledge_target_of_hybrid`); see finding A5 for the condition on `δ`.

**Exists** (honest verifier, fixed challenges):
- the opened columns are uniform (`Hiding.lean`, `HidingRows.lean`, `HidingM.lean`);
- the opening views (`HidingOpening.lean`, `HidingOpeningSum.lean`, `HidingMOpening.lean`);
- the masked sumcheck over all rounds (`HidingSumcheck.lean`, `HidingSumcheckJoint.lean`);
- salted Merkle hiding in the random-oracle model (`merkle_hiding`, about `q·2^-239 + 2^-222` at `N ≤ 2^16`);
- the refusal bit (`HidingRefusal.lean`). `refusal_output_must_be_leaked` shows that `leak` must determine the refusal
  OUTPUT; D65(2)'s constant refusal meets it;
- one block composed (`block_view_law_eq_slot_M`).

**Missing:**
- a. **Fiat–Shamir, per profile.** The generic lemma is proved (§6); what is left is its instance: the receipt's points
   `y a σ` (the challenges, the sampled columns `J`, the opened set) as functions of the fresh salts and roots, their
   salt count `K`, and the HVZK step at the programmed challenges. The code's points are chain states, which are hash
   outputs; a first step replaces the first fresh chain digest by a uniform value (`fresh_point_prob_le`,
   `preimage_out_prob_le`), then `program_real_ideal` applies. Alternatively, a simulator that programs nothing (A6).
- b. **The links for the registered layouts.** Which claim value is which masked terminal; which `M` functional is
   which `g(ρ)` or `Γ`; `CfsMask`'s layout as `M`'s a-rows.
- c. **Several slots and blocks**, the D12a / D55 run, and the token stages IN and OUT.
- d. **`R` receipts: the per-receipt step.** The hybrid is proved generically (§6). Left: the hypothesis `hstep` of
   `zeroKnowledge_of_hybrid` for the profile's simulator, i.e. receipt `j` honest versus simulated, the earlier
   receipts simulated and the later ones honest, against the current oracle.
- e. **The `Simulator` instance**: a `ProgSim` gives one (`ProgSim.toSim`). Left: the profile's `ProgSim.sim` (one
   simulated receipt and its programmed points), and `P.leak` defined as the declared leakage.
- f. **The error budget** against `εzkTarget`: `zeroKnowledge_target_of_hybrid` needs `εhv ≤ 2^-120` per receipt and
   `δ ≤ 2^-248` per query per receipt. The generic per-query terms are larger (finding A5).

**Waits for:** W16R3 (B1 and B2 change the commitments and the batching) and the `Protocol` instance.

### 4.6 Fields that need no per-profile work

- `SemanticHiding`: `semanticHiding_of_zeroKnowledge`.
- `KnowledgeSound`: `knowledgeSound_of_extract`, from §4.1 and §4.2.
- `ProductionReady` at the targets: `productionReady_mono`, from the proved errors.

**A suggested order:**
1. The `Protocol` instance's skeleton and `Binding` (§4.4), which are the smallest;
2. then `Complete`;
3. then `IOPExtract` and `ZeroKnowledge` after W16R3's freeze. They share the layout map and the Fiat–Shamir
   transcript model.

## 5. Checks

All in `results/zk60_lean_asm_20261106/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`):
- `file1.log` … `file3.log`: `lake env lean` on the new file while it was written. `file3.log` shows two deprecation
  warnings (`push_neg`, `dif_pos`); both were removed before the full build.
- `check.log`: `check_asm.sh`, which runs:
  - the full `lake -d formal build` (`full.log`): 3,433 jobs, rc 0, no warning, no error. Every other module was
    up to date with the cloned build cache, so only `Assembly` and the library root were rebuilt;
  - the axiom audit (`axioms_asm.lean` → `axioms.log`);
  - a source scan of `Assembly.lean` for `sorry`, `axiom`, `native_decide`, `admit` and `maxRecDepth`. Its only matches
    are the words in the file's header comment.

## 6. Generic lemmas for `Complete` and `ZeroKnowledge` (2026-11-06, second lane)

Lean lane (Claude), on perf at 19399b5f. Two new files, `formal/ZK60Formal/CompleteSub.lean` and
`formal/ZK60Formal/ZKHybrid.lean`, imported by the library root. They are GENERIC: stated over the existing models of
the sub-protocols (as the L3 and L4 lemmas are) and over any `IntModel` and `Protocol`, not over the code's layout.
`Statements.lean` is unchanged; no Rust and no prover source changed. Evidence: `results/zk60_lean_gen_20261106/`.

### 6.1 In plain words, for Victor

**Completeness (obligation 3): the honest proof is accepted.**
- Every sub-protocol model now has a theorem saying the honest prover is accepted:
  - the sumcheck, at EVERY challenge. So under Fiat–Shamir it is accepted for every hash function: it costs nothing
    in `εc`;
  - the same for the masked (`--zk`) sumcheck, the last-round extension, the CFS mask in the code's own coefficient
    form, the zero-check and batching;
  - the regular opening, `M`'s opening (product and proximity tests), honest Merkle paths and column-by-column
    commitments.
- The only completeness losses are the prover's own refusals.
  - LogUp refuses when `α` hits a table value (a denominator vanishes). That has probability at most `M/|F|`, `M` the
    distinct table tuples: about `2^-111` per LogUp domain [ESTIMATE].
  - CFS refuses `c = 0`: `1/|F|`.
- A composition lemma (`complete_of_checks`) turns `k` checks with failure bounds `εᵢ` into `Complete` with
  `εc = Σ εᵢ`, in exactly the approved form.
- So `Complete` is now a per-profile bookkeeping exercise: list the verifier's checks on an honest receipt, show they
  give acceptance, add up the refusal terms. It still needs the Lean prover and verifier (§4.0).

**Zero knowledge (obligation 5): the two generic tools are proved.**
- **The random-oracle programming lemma** (`program_real_ideal`).
  - The setting: a simulator draws a receipt's challenges itself and programs the hash to return them at the
    receipt's `k` Fiat–Shamir points, which depend on a fresh salt.
  - The result: a distinguisher detects this only by having asked one of those points earlier. With `q₁` earlier
    queries, its advantage is at most `k·q₁/|S|` (`S` the salt space).
  - The coupling is exact. The queries after the receipt cost nothing.
- **The `R`-receipt hybrid** (`zeroKnowledge_of_hybrid`). This settles the composition side of A3.
  - The worlds: for any simulator of the "programming" kind (one receipt from the public data, plus the points it
    programs), hybrid `j` simulates the first `j` receipts and proves the rest honestly. All hybrids use one
    probability space.
  - The endpoints: hybrid `0` is EXACTLY the approved `realProb`, and hybrid `R` is EXACTLY the approved `idealProb`
    of a `Simulator` built from it.
  - The result: if swapping one receipt costs at most `ε₁`, then `R` receipts cost at most `R·ε₁`.
  - What stays per profile: the one-receipt swap.
- **The approved target** (`zeroKnowledge_target_of_hybrid`): a per-receipt bound `εhv + q·δ` with `εhv ≤ 2^-120` and
  `δ ≤ 2^-248` gives exactly `εzkTarget`.
- **Finding A5 needs your attention.** The per-query terms of the generic bounds we have are larger than `2^-248` per
  receipt. Summed over `R` receipts they give a `q·R` cross term that `εzkTarget` has no slot for, so the target
  does not follow from them in one corner (`R` near `2^118`, `q` near `2^126`).
  - In practice this is irrelevant.
  - Formally it needs a ruling, or a sharper per-profile argument (§6.4).

### 6.2 What is proved

All PROVED (`results/zk60_lean_gen_20261106/`):
- the full `lake -d formal build` is green: 3,435 jobs, no warning, no error, no `sorry` (`full.log`, `check.log`);
- `#print axioms` on all 71 declarations below (`axioms_gen.lean` → `axioms.log`). Each shows only `propext`,
  `Classical.choice` and `Quot.sound`, or a subset; `sorryAx` appears nowhere;
- every premise is an explicit hypothesis. No `axiom`, `native_decide`, `admit` or `maxRecDepth`.

**`CompleteSub.lean` (obligation 3).**

| Part | Theorem | Statement |
|---|---|---|
| sumcheck | `honestProver`, `honestMsg` (defs); `interpEval_honestMsg`, `honestMsg_check` | round `j` sends the true round polynomial's values at `X = 0..d`. Its interpolant IS the true round polynomial (Lagrange uniqueness at `d + 1` distinct nodes, `d < char F`), so the round check holds and the next claim is true |
| | **`sumcheck_complete`**, `sumcheck_complete_prob` | for a TRUE claim and `f` of individual degree `≤ d`, `Accepts` at EVERY challenge vector (probability `1`) |
| | **`sumcheck_complete_list`** | the same on `FSSumcheck.lean`'s list verifier `scAccept`: under Fiat–Shamir, at every oracle |
| | `sumcheck_complete_masked`, `sumcheck_complete_extended` | `f + c·g` on the claim `S + c·G`, for every mask `g` and every `c`; the last-round extension on the claim `Σ f` |
| | `zerocheck_complete`, `batch_complete` | a relation vanishing on the cube makes `Σ eq(τ, x)·R(x) = 0` true at every `τ`, accepted at every `(τ, ρ)`; zero relation values pass every batching vector |
| CFS | **`cfs_masked_chainDefect`**, **`cfs_masked_honest`** | the rounds the code sends, `s_j + c·g_j`, have chain defects `(S + c·G, the unmasked gaps, F + c·g(ρ))`. So an honest chain stays honest, with scalar `S + c·G` and terminal `F + c·g(ρ)`, for every mask, `c` and challenge vector |
| | `cfs_refusal_prob` | the refusal `c = 0` has probability exactly `1/|K|` |
| LogUp | `TupleMass` (def), **`exists_tupleMass`**, **`regroup`** | honest multiplicities (natural numbers, the lookup count per distinct tuple; padded copies may share it) exist when every looked-up tuple is in the table. Then `Σ_l f(A_l) = Σ_j μ_j·f(T_j)` for EVERY `f` |
| | **`logup_identity_honest`**, `logup_ratfunc_honest` | the folded identity `Σ 1/(α − fold A) = Σ μ/(α − fold T)` holds for EVERY `β, γ, α`, and as rational functions; the multiplicities are fixed before the challenges |
| | `honestHelpers` (def), **`helperRel_honest`** | off the poles the honest helpers `1/(α − a)`, `1/(α − a) + 1/(α − b)`, `m/(α − t)` pass every relation and the sum claim of `SoundLogUpBlock.lean` |
| | `logupRefuses` (def), **`logupRefuses_iff`**, `not_mem_poles_of_not_refuses` | the honest prover refuses exactly when `α` is a table value (`HidingRefusal.lean`'s `logup_refusal_iff_table`) |
| | `logup_block_complete`, `logup_complete_prob_gen`, **`logup_block_complete_prob`** | over uniform `β, γ, α`, the honest LogUp is served and passes, except with probability `≤ M/|F|`, `M` the distinct table tuples |
| opening | **`opening_complete`**, `opening_complete_prob` | codeword rows and a true claim: the honest group and proximity vectors are codewords and pass at EVERY `ρ` and column draw |
| `M` | **`mproduct_complete`**, **`mopening_complete`** | honest rows, the honest values, `q'` the product polynomial, a blinding row with zero sum over `G_m`, and the honest proximity polynomial: `M`'s product test and its proximity checks pass at EVERY `θ`, `r` and column sample (the code's `o = 0`; `mproduct_offset_accepts` with offset `0`) |
| Merkle | `treeRoot`, `treePath` (defs); `treePath_length`, **`climb_treePath`**, **`opens_honest`** | the honestly built tree (consecutive pairs) and its paths: from every position `j < 2^h` the climb reaches the root, and the path passes the depth check |
| | `colLeaves` (def), **`colCommit_opens_honest`** | the honest openings of `Assembly.lean`'s column-by-column commitment open, when the root and paths are the honest ones: the `∃ r, opensIn …` part of `Complete` |
| compose | `one_sub_le_prob`, `prob_forall_ge` | `Pr[¬E] ≤ ε ⇒ 1 − ε ≤ Pr[E]`; checks with failure bounds `εᵢ` all pass with probability `≥ 1 − Σ εᵢ` |
| | **`complete_of_checks`**, **`arithComplete_of_checks`** | if the checks together imply the completeness event and check `i` fails with probability `≤ εᵢ` over `(H, c)`, then `Complete M P (Σ εᵢ)` (resp. `ArithComplete`) |
| FS step | `prHC_le_of_forall`, **`fresh_point_prob_le`**, `fresh_point_prob_le_coins`, `prob_snd_mem_le` | a bound at every coin is a bound on average. A challenge read at a point the honest computation did not ask lands in a set of `m` values with probability `≤ m/|D|` |

**`ZKHybrid.lean` (obligation 5).**

| Part | Theorem | Statement |
|---|---|---|
| (A) | `program` (def), `program_at`, `program_off`, `runLog_program` | the oracle programmed at `k` distinct points; an `A₁` that asked none of them runs identically |
| | `progReal`, `progIdeal`, `progBad`, `progSwap` (defs) | real world: challenges `H(y a σ)`; programmed world: fresh `v`, oracle programmed after `A₁`; bad: `A₁` asked a point; the coupling swaps `H(y)` with `v` |
| | `progSwap_bad`, `progSwap_good`, `run_program_good`, **`progSwap_involutive`**, `real_swap_iff` | the coupling is an involution of the coins (a bijection); outside the bad event it maps one world's event onto the other's |
| | **`program_coupling`** | `|progReal − progIdeal| ≤ Pr[bad]`, both directions; nothing about `A₂`'s queries is needed |
| | **`progBad_le`** | `Pr[bad] ≤ k·q₁·K/|S|` for an `A₁` of `q₁` queries, `K` salts per point |
| | **`program_real_ideal`**, **`program_real_ideal_inj`** | the programming lemma: advantage `≤ k·q₁·K/|S|`; `≤ k·q₁/|S|` with points injective in the salt |
| (B) | `ovr` (def), `ovr_append`, **`ovr_ofFn_program`** | the oracle with a table of programmed points on top; a receipt's table of `k` distinct points is exactly `program y v` |
| | `ProgSim` (structure), `hybStep`, `simStep`, `hybProb` (defs) | a programming simulator: one receipt from the weights, the CURRENT oracle, the public data and its coins, plus the points it programs. Hybrid `j`: the first `j` requests simulated, the rest honest against the current oracle, on one probability space |
| | **`ProgSim.toSim`** (def) | every programming simulator is a `Simulator` of `Statements.lean`: the base oracle from its first coin, the table in its state |
| | `runState_ask`, `within_ask_pos`, `hyb_run_real`, `hyb_run_sim`, `toSim_run`, `toSim_run_init`, `splitFst`, `splitSnd`, `splitHead`, `extend_fst`, `extend_snd`, `prob_marginal`, `prob_const` | the runs, step by step, and the coins as marginals of uniform laws |
| | **`hybProb_zero`** | hybrid `0` IS `realProb M P W n Dist`, exactly |
| | **`hybProb_ge`** | for `Dist.Within q R` and `j ≥ R`, hybrid `j` IS `idealProb M P PS.toSim W (q + R) Dist`, exactly |
| | `telescope_le`, `telescope_ge` | steps of at most `e j` add up |
| | **`zeroKnowledge_of_hybrid`**, `zeroKnowledge_of_hybrid_uniform` | if each step `j < R` moves the probability by `≤ ε q j` (both directions, every `Within q R` distinguisher), then `ZeroKnowledge M P (fun q R => Σ_{j<R} ε q j)`; `R·ε₁ q` when uniform |
| | `zeroKnowledge_min_one`, **`zeroKnowledge_target_of_hybrid`** | an error above `1` says nothing; per-receipt `εhv + q·δ` with `εhv ≤ 2^-120`, `δ ≤ 2^-248` gives `ZeroKnowledge M P εzkTarget` |

### 6.3 How each result discharges or shrinks an obligation

- **Obligation 3, `Complete`.**
  - Every "each sub-protocol's honest acceptance" item of the old §4.3 is now PROVED for the models. Those were the
    sumcheck, the LogUp identity on honest data, the openings of honestly built trees, and `M`'s tests.
  - "Under Fiat–Shamir the honest challenges are uniform" is now `fresh_point_prob_le`, given that the point is fresh.
  - The sumcheck, zero-check, opening, `M` and Merkle parts are deterministic: they hold at every oracle. So the only
    terms of `εc` are the refusals.
  - What remains is per profile: the instance (prover, verifier), the list of checks with the implication `himp`, and
    the freshness of the honest squeeze points. Updated §4.3.
- **Obligation 5, `ZeroKnowledge`.**
  - Item a (Fiat–Shamir) shrinks to its instance: the generic programming lemma is proved.
  - Item d (`R` receipts) shrinks to the one-receipt step `hstep`: the hybrid is proved, and its endpoints are the
    approved worlds exactly.
  - Item e (the `Simulator` instance) shrinks to a `ProgSim`: `ProgSim.toSim` builds the `Simulator`.
  - Item f (the budget) has its criterion: `zeroKnowledge_target_of_hybrid`.
  - Items b and c (the layouts, slots, blocks and stages) are unchanged. Updated §4.5.
- **A3** (`SemanticHiding` covers one receipt) is unchanged. `SemanticHiding` stays one-receipt as approved. The
  hybrid concerns `ZeroKnowledge`, which already covers `R` requests; it now has a proof route.

### 6.4 Findings

**A5 (Low; a ruling, or a sharper per-profile argument): per-query, per-receipt terms add up to a `q·R` cross term
that `εzkTarget` has no slot for.**
- The hybrid adds one bound per receipt. A per-receipt bound `εhv + q·δ` gives `R·εhv + q·R·δ` in total.
- `εzkTarget q R = q·2^-128 + R·2^-120` has no cross term. `zeroKnowledge_target_of_hybrid` absorbs `q·R·δ` into
  `q·2^-128` for every `R < 2^120`, and for that it needs `δ ≤ 2^-248` per query per receipt. For `R ≥ 2^120` the
  target is at least `1`, so nothing is needed there.
- The generic per-query terms we have are larger:
  - Merkle hiding (`merkle_hiding`): about `2N/2^256` per query per commitment, `2^-239` at `N = 2^16` columns;
  - the programming lemma: `k/2^256` per query per receipt, `k` the programmed points (every Fiat–Shamir squeeze; in
    the thousands).
- For these summed bounds to meet the target everywhere, `δ` must be at most `2^-246` [ESTIMATE].
  - Why: write `a = q·2^-128` and `b = R·2^-120`; the target is `a + b`, and the cross term `q·R·δ` is
    `a·b·2^248·δ`. Where the target is below `1`, `a·b/(a + b)` comes arbitrarily close to `1/4`.
  - Example: at `q = 2^126`, `R = 2^118` the target is `2^-1`, while `q·R·2^-239 = 2^5`.
  - So the target does not follow from the generic bounds in that corner. The corner is `R` above about `2^111`
    receipts, `q` near `2^126`: irrelevant in practice, but the approved statement quantifies over every `R`.
- **Options:**
  - (a) A sharper per-profile argument. The unopened columns carry the mask pads' entropy, so a query hits a salted leaf
    only by guessing both the content and the salt. That should bring the per-query term below `2^-248`; it is not
    proved.
  - (b) A cross term in the target, e.g. `+ q·R·2^-230`.
  - (c) A cap on the receipts per weight set, e.g. `R ≤ 2^100`. Then the generic terms give about `q·2^-130` or less,
    with up to `2^7` commitments per receipt [ESTIMATE].
- (b) and (c) are changes to the approved statement and need your ruling. Until then, (a) is the route.

**A6 (Info): a simulator that programs nothing is a `ProgSim`, and may be the simpler route.**
- The simulator: from the public data, choose a stand-in input with the same public output part and leakage, and run
  the honest prover on it against the current oracle, programming nothing. That is a `ProgSim`.
- Its hybrid step is a witness-indistinguishability statement: the honest prover on `x` versus on the stand-in, with
  the real oracle.
- The L4 lemmas are built for that statement: the views' law is independent of the data at every challenge value, and
  Merkle hiding covers the unopened columns.
- What it would still need: those lemmas composed under adaptive Fiat–Shamir challenges.
- It has no programming term at all. The Merkle term of A5 remains.

**A7 (Info): completeness has room to spare.**
- Every completeness loss is a refusal, and each is at most about `M/|Fp2| ≈ 2^-111` (LogUp) or `2/|Fp2|` (CFS)
  [ESTIMATE].
- Against `εcTarget = 2^-40`, that leaves room for about `2^71` refusal sites per receipt.

### 6.5 Checks

All in `results/zk60_lean_gen_20261106/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`):
- `file1.log` … `file9.log`: `lake env lean` on the new files while they were written (`file_zk.sh` builds
  `CompleteSub` first). The errors fixed on the way are in those logs: deprecated names, an implicit argument, two
  unification timeouts removed by naming the predicate.
- `check.log`: `check_gen.sh`, which runs:
  - the full `lake -d formal build` (`full.log`): 3,435 jobs, rc 0, no warning, no error;
  - the axiom audit (`axioms_gen.lean` → `axioms.log`): 71 declarations, no `sorryAx`, nothing beyond `propext`,
    `Classical.choice`, `Quot.sound`;
  - a source scan of both files for `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats` and
    `implemented_by`. Its only matches are the words in the files' header comments.

## 7. Step L5, the foundation: the executable primitives and their agreement corpus (2026-11-06, third lane)

Lean lane (Claude), on perf at 1a4acb65. Five new library files, imported by the library root: `ExecField.lean`,
`ExecBlake3.lean`, `ExecTranscript.lean`, `ExecMerkle.lean` and `L5Vectors.lean` (data). One checker, `L5Check.lean`,
not imported by the root because it defines `main`. One TEST-ONLY Rust file, the integration test
`ops/zkp-mvp/gpu-metal/zkp-core/tests/lean_l5_export.rs`: no production source changed, no crate added. `Statements.lean`
is unchanged. Evidence: `results/zk60_lean_l5_20261106/`.

### 7.1 In plain words, for Victor

**Why this step.** Your §6 decision 3 makes the Lean verifier's verdict production acceptance. That verifier must
compute exactly what the Rust verifier computes. Every profile's verifier is built from the same four primitives: the
field, the hash, the Fiat–Shamir transcript and the Merkle check. W16R3 (D67: B1 + B2 + B3) changes what is committed
and batched, not these four. So they can be done now and will not be redone.

**What now exists, all four in executable Lean.**
- **The field.** Goldilocks and its extension, written the way the code writes them: 64-bit words and the code's own
  fast reduction.
  - PROVED: each operation is the true field operation.
  - In particular the code's fast reduction (`reduce128`) is now proved correct for every 128-bit input, not just
    tested.
- **BLAKE3**, in the three modes the code uses (plain, keyed, key derivation).
  - It reproduces all 105 official test vectors (131 bytes each) and every digest in the corpus.
  - This is a test, not a proof. BLAKE3 stays modelled as a random oracle (D19); no Lean theorem says anything about
    BLAKE3's security.
- **The transcript**, as the code runs it: the running state, the labelled absorbs, the squeeze counter, and the
  challenges in `Fp`, `Fp2` and column indices.
  - PROVED: for EVERY hash function, it is exactly the hash-chain model that L3's Fiat–Shamir theorems are about.
  - Its challenges are exactly the challenge maps those theorems use.
  - So those theorems now apply to the transcript the code executes, not to a paraphrase of it.
- **The Merkle check of one opened column**, as the code runs it: the column digest, the salted leaf, the climb, the
  depth check.
  - PROVED: for every hash function, it accepts exactly when L3's model accepts.
  - Merkle binding is therefore now a theorem about the program (`exec_merkle_binding`): opening one position of one
    root to two different columns needs a hash collision.

**The agreement corpus.**
- The Rust test exports 5,359 records from the crate's real code paths:
  - field operations;
  - digests in all three modes, including the hash-tag keys of two profiles;
  - transcript runs, with the state after every step;
  - Merkle trees and paths, honest and tampered;
  - three whole PCS openings that `verify_zk_tagged` accepts.
- Lean recomputes every record:
  - with the official vectors, **5,553 checks, 0 failed**;
  - for every tampered record, the Lean verdict equals the Rust verdict;
  - for each PCS opening, Lean replays the verifier's transcript, reproduces its column indices and its final state
    byte for byte, and re-verifies every column.
- **Negative control:** six single changes to the corpus give exactly 6 failures.

**What this does not do yet.**
- It is not a per-profile verifier. The receipt decoder, the sumcheck and LogUp verifier arithmetic, the opening's
  column-versus-clear-vector check (the coset NTT), `M`'s test and the block and run schedule are still to write (§7.5).
- The corpus has no record from a real block receipt (R13 or W16R2). Making one needs a block proof run, which a
  test-only export of `zkp-core` cannot do. Its PCS openings are the crate's real commit, open and verify path, on
  synthetic data.

### 7.2 What is proved

All PROVED (`results/zk60_lean_l5_20261106/`):
- the full `lake -d formal build` is green: 3,449 jobs, no warning, no error, no `sorry` (`full.log`, `check.log`);
- `#print axioms` on the 74 declarations below (`axioms_l5.lean` → `axioms.log`): each shows only `propext`,
  `Classical.choice` and `Quot.sound`, or a subset; `sorryAx` and `Lean.ofReduceBool` appear nowhere;
- every premise is an explicit hypothesis; no `axiom`, `native_decide`, `bv_decide`, `admit`, `maxRecDepth`,
  `maxHeartbeats`, `implemented_by` or `extern` (source scan in `check.log`: none).

**`ExecField.lean`** (mirrors `zkp-core/src/field.rs` line by line on `UInt64`).

| Theorem | Statement |
|---|---|
| `leNat_leBytes`, `leNat_le64`, `ofLE64_le64` | `to_le_bytes` / `from_le_bytes` round-trip |
| `Fp.new_toNat`, `Fp.add_toNat`, `Fp.sub_toNat`, `Fp.neg_toNat` | `Fp::new` is `x mod p` for every word; on canonical inputs `add`, `sub`, `neg` are `(a + b) mod p`, `(a + p − b) mod p`, `(p − a) mod p` (the carry and borrow corrections by `EPSILON` included) |
| `Fp.t0_spec`, `Fp.t1_spec`, `Fp.res_spec`, `Fp.reduce128_arith`, **`Fp.reduce128_toNat`** | **`reduce128` is the canonical residue for EVERY `x < 2^128`**: each step's value (borrow `+p`, carry `−p`), then `2^64 ≡ 2^32 − 1` and `2^96 + 1 = p·(2^32 + 1)` |
| `Fp.mul_toNat`, `Fp.toGF_mul`, `Fp.toGF_pow`, `Fp.toGF_inv` | `mul` is the product mod `p` for ANY two words; `pow` is the power (the code's bit loop); `inv` is the field inverse of a nonzero value (Fermat) |
| `Fp.toGF_add`, `Fp.toGF_sub`, `Fp.toGF_neg`, `Fp.toGF_new`, `Fp.toGF_reduce128` | the same as equalities in `GF = ZMod gP` under `toGF a = (a.v.toNat : GF)` |
| `Fp.*_canon`, `Fp.toGF_ofGF`, `Fp.ofGF_toGF`, `Fp.toGF_injective`, `Fp.toGF_zero_iff` | outputs are canonical; canonical words and `GF` are in bijection |
| `seven_not_square` | `7` is not a square in `GF` (Euler's criterion with `Goldilocks.lean`'s `pow7_2`) |
| `Fp2.toK_add`, `toK_sub`, `toK_neg`, **`Fp2.toK_mul`**, `toK_mulBase`, `toK_one` | under `toK U a = fp2 U (toGF c0, toGF c1)` (`HidingMOpening.lean`'s reading) into ANY field `K ⊇ GF` with `U² = 7`, the code's `Fp2` operations are the field's; `mul` needs no canonical input |
| `Fp2.norm_toGF`, `Fp2.norm_ne_zero`, **`Fp2.toK_inv`** | a canonical nonzero value has a nonzero norm, so `Fp2::inv` never meets `Fp::inv`'s assertion, and it is the inverse |
| **`Fp2.toK_bijective`** | for `K = GF[u]/(u² − 7)`, canonical code pairs are in bijection with the field |
| `Fp2.fromBytes_toBytes` | `Fp2::from_bytes ∘ to_bytes` is the identity on canonical values |

**`ExecBlake3.lean`.** BLAKE3 (compression, chunks, tree, extendable output; `hash`, `keyedHash`, `deriveKey`), from the
specification and the reference implementation. No theorem: BLAKE3 is the random oracle. It is tested (§7.3).

**`ExecTranscript.lean`** (mirrors `zkp-core/src/transcript.rs`).

| Theorem | Statement |
|---|---|
| **`decodeLink_msg`** | the code's absorb input (`state ‖ le64 len(label) ‖ label ‖ le64 len(data) ‖ data`) and squeeze input (`state ‖ "squeeze" ‖ le64 counter`) decode back to the state and the item, for labels and data under `2^64` bytes |
| `chainEnc` | so the code's transcript is a `ChainEnc` of `FSChain.lean`, for a domain whose start input decodes as no link |
| `decodeLink_none_of_long`, `startMsg_ok_rungG` | a sufficient condition for that premise, and the premise for the development rung's profile string, by `decide` |
| `runOps_chainFrom`, **`runOps_chain`**, `squeeze_out` | for EVERY hash function, the executable transcript's state after any absorbs and squeezes is `lastD H (chainFrom H [] items)` of that `ChainEnc`, the squeezes carrying the code's counters, and each squeeze's output is that chain's digest |
| **`challengeFp2Of_toGF`**, `challengeFpOf_toGF`, `idx_eq_idxChal` | `challenge_fp2` is `FSChallenge.lean`'s `fp2Chal gP (2^128)` on the digest's two halves; `challenge_fp` its low half reduced; each column index is `idxChal h` of its 8-byte chunk |

**`ExecMerkle.lean`** (mirrors `merkle.rs`'s `verify_path_keyed` and `pcs.rs`'s per-column checks in `verify_zk_tagged`).

| Theorem | Statement |
|---|---|
| `merkleEnc`, `decCol_colBytes`, `splitDig_append` | the code's column, salted-leaf and node encodings form a `MerkleEnc` (`SoundMerkle.lean`), with decoders; no separation between them is used, so the legacy rule is covered too |
| `foldPath_eq_climb`, **`verifyColumn_iff`** | for EVERY hash function, `verifyColumn` (depth check, column length, the climb from the salted leaf) accepts exactly when `Opens` holds and the column has `rows` entries |
| `merkleEncB`, `liftH_eq`, `climbB_eq`, `opensB_iff` | the same on the finite oracle domain `QB L` (the inputs of at most `L` bytes, `L ≥ 64`, `L ≥ 8·rows`) |
| **`exec_merkle_binding`** | an adversary making `q` queries outputs one root, one position and two different columns that BOTH pass the executable verifier with probability `≤ collBound (q + 2(h + 2))`: `merkle_binding` applied to the program |

### 7.3 The agreement corpus

The Rust side is `zkp-core/tests/lean_l5_export.rs`, run by `export_corpus.sh`:
`cargo test --release --offline --locked --test lean_l5_export` through the guard. It writes `corpus.txt`: 5,359
records, 643,668 bytes. Its own assertions also pass: every PCS opening verifies, a tampered one is refused, and the
prover's and verifier's transcripts end in the same state.

The Lean side is `L5Check.lean`, run by `check_l5.sh` (`l5check_full.log`). It uses the SAME definitions the theorems
are about, and it also checks each field result against `Nat` arithmetic mod `p`. In all, 5,553 checks, 0 failed, in
about 16 s, interpreted:

| Kind | Checks | What |
|---|---|---|
| official BLAKE3 vectors | 105 | 35 inputs (0 to 102,400 bytes) × `hash`, `keyed_hash`, `derive_key`, 131 bytes each (`L5Vectors.lean`, from `blake3_test_vectors.json`, sha256 `dcb91ea8…2f624`) |
| `Fp` | 2,889 | `add`, `sub`, `mul` (on edge × edge and random pairs; `mul` on non-canonical words too), `neg`, `inv`, `pow`, `new` (every word), `from_u128` (every width, the edges of `p`'s multiples) |
| `Fp2` | 960 | `add`, `sub`, `mul`, `neg`, `mul_base`, `inv` |
| bytes | 443 | `Fp::to_bytes`, `Fp2::to_bytes`, `Fp2::from_bytes` (non-canonical words included) |
| BLAKE3 from Rust | 119 | 37 lengths from 0 to 266,624 bytes (every chunk boundary class) × 3 modes; the 8 hash-tag keys of two profiles as `derive_key` |
| tag keys | 5 | the two profiles' four keys equal Lean's `derive_key` and `hashtag.rs`'s pins; the legacy tag has none |
| transcript | 232 | three runs (legacy, two tagged): the start premise, and the state after every absorb (`absorb`, `absorb_u64`, `absorb_fp`, `absorb_fp2` up to 16,664 `Fp2` = an opening's clear vector at W16R2 8B) and every challenge (`challenge_fp`, `_fp2`, `_fp2_vec`, `challenge_indices` with 0 to 37 indices) |
| Merkle trees and paths | 645 | trees of `2^0` to `2^8` leaves under three tags (roots; the Lean tree's paths equal Rust's on 90 honest paths); 528 path verdicts, honest and tampered (wrong position, flipped leaf or path byte, a short or a long path) equal to Rust's |
| leaf, node, column digests | 18 | `salt_leaf_keyed`, `hash_pair_keyed`, `hash_column_keyed` under three tags |
| column openings | 84 | 12 columns of the PCS openings, each honest and with six tamperings (column entry, salt, position, short column, short path, path byte), Lean's verdict equal to Rust's |
| PCS openings | 50 | three openings (`rungg`, `m125`, `legacy`; 12, 20, 12 opened columns): the replayed verifier transcript's indices and final state, and every opened column re-verified |
| ASCII literals | 3 | `"squeeze"`, `"hashline-v1/"` and the rung's profile string, as the Lean byte lists |

**Negative control** (`mutate_corpus.py`, `negative_control.log`): one field result, one keyed digest, one transcript
state, one column index, one PCS final state and one honest opening's verdict changed. Exactly 6 checks fail.

### 7.4 Findings

**L5-1 (Info): `reduce128` is correct on its whole domain.** `field.rs`'s A11 comment claims it; `reduce128_toNat`
proves it for every `x < 2^128`. So `from_u128` (the challenge reduction) and `mul` are exact.

**L5-2 (Info; for the receipt decoder): `Fp2::from_bytes` is not injective.**
- It reduces each word with `Fp::new`, so a word `w ≥ p` decodes to the same value as `w − p`. The corpus records such
  inputs, and Lean agrees.
- `fromBytes_toBytes` holds only on canonical values.
- No soundness effect where the verifier absorbs re-encoded values, as `absorb_fp2` does.
- But a receipt decoder that uses `from_bytes` accepts two encodings of one receipt. The per-profile decoder must
  either refuse non-canonical words or be shown to absorb only re-encoded values.

**L5-3 (Info): the transcript's start premise is a real per-profile condition.**
- `ChainEnc` needs the start input to decode as no link. This is `FSChain.lean`'s noted condition: e.g. a 35-byte
  domain whose bytes 20–26 are `"squeeze"` violates it.
- `decodeLink_none_of_long` gives a sufficient condition, and `startMsg_ok_rungG` the instance for one profile string.
- Every registered profile string needs this one-line `decide`. `L5Check.lean` checks it for the corpus's three domains
  (`TRSTART`).

**L5-4 (Info; for obligation 0): a finite `Q` for the `Protocol` instance.**
- `Statements.lean` needs `Fintype Q`. BLAKE3's input domain is unbounded, so the oracle's domain is taken as `QB L`:
  the inputs of at most `L` bytes, under each mode and key.
- The verifier's hash is `liftH G`, which never asks a longer input.
- `L` is the profile's longest hash input. At W16R2 8B that is about 266,700 bytes, the absorb of an opening's clear
  vector [ESTIMATE].
- `exec_merkle_binding` is stated this way; the transcript theorems hold for every hash function, so they need no
  bound.

**L5-5 (Info): speed.**
- `lean --run` interprets, and the checker runs 5,553 checks, with hashes of up to 266,624 bytes, in about 16 s.
- A production verifier would be a compiled `lean_exe` target, which needs a `lakefile.toml` change. This lane did
  not make it.

### 7.5 What is left for the per-profile verifier (obligation 0)

- **The `Protocol` instance**:
  - `Q := QB L` and `D := Dig`;
  - `Stmt`, `Receipt` and a bounded, canonical receipt decoder (L5-2);
  - `verify` built from this foundation: the run statement's absorbs (the label table of
    `hashline/src/private_block/hash_domain.rs`), the sumcheck rounds (`interpolate_eval`), the zero-check and LogUp
    verifier arithmetic, each opening's claim check and column-versus-clear-vector check (`encode_row_zk`, the coset
    NTT), `M`'s `mask_verify_tagged`, and the D55 fork-join schedule.
- **Each verifier piece proved to be its L3 model**, as here for the transcript (`runOps_chain`) and the Merkle check
  (`verifyColumn_iff`). That covers `scAccept`, the opening and `M` tests, and the tree of chains (`Tree.verOC`).
- **The corpus at the frozen profile (W16R3)**: real receipts and malicious controls, verdict for verdict against the
  Rust verifier. One check on a real receipt was not possible here (§7.1).
- **A compiled checker target** (L5-5) and the independent kernel re-check of the statements doc's §5 (nanoda or
  lean4checker).

### 7.6 Checks

All in `results/zk60_lean_l5_20261106/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`):
- `file1.log` … `file10.log`: the new files while they were written. The errors fixed on the way are in those logs:
  deprecated names, `omega`'s incompleteness on the reduction's congruence (split into `t0_spec`, `res_spec` and
  `reduce128_arith`), and a kernel deep recursion in a `let`-heavy proof (removed by writing `reduce128` as small
  named steps).
- One exploratory job is not in that directory: a bisection copy of the reduction proof in the scratchpad, which the
  guard stopped at its 24 GiB cap (peak RSS 24.49 GiB). The restructured proof needs 3.7 GiB.
- `rust.log`: the corpus export (three runs while the path records were trimmed to keep `corpus.txt` well under 1 MB).
- `check.log`: `check_l5.sh`, which runs:
  - the full build (`full.log`): 3,449 jobs, rc 0, no warning, no error;
  - the axiom audit (`axioms.log`): 74 declarations, nothing beyond `propext`, `Classical.choice`, `Quot.sound`;
  - the source scan (none);
  - the agreement check (`l5check_full.log`): 5,553 checks, 0 failed;
  - the negative control (`negative_control.log`): 6 failed, as required.

## 8. Step L6, the generic sumcheck verifier: executable, and proved equal to its models (2026-11-06, fourth lane)

Lean lane (Claude), on perf at fbf81c73 (L5 merged). Three new library files, imported by the library root:
`ExecMle.lean`, `ExecSumcheck.lean` and `ExecCfs.lean`. One checker, `L6Check.lean`, not imported by the root because it
defines `main`. One TEST-ONLY Rust file, the integration test `ops/zkp-mvp/gpu-metal/zkp-core/tests/lean_l6_export.rs`:
no production source changed, no crate added. `Statements.lean` is unchanged. Sol's W16R3 design file was read, not
changed. Evidence: `results/zk60_lean_l6_20261106/`.

### 8.1 In plain words, for Victor

**Why this step.**
- Every slot of a block receipt is checked by the same generic sumcheck verifier of `zkp-core` (`sumcheck::verify`),
  with the same zero-knowledge pieces: the CFS mask's weights and rounds, and the last-round extension.
- W16R3 (D67) batches the slots into one larger sumcheck (B2) and changes the PCS encoder (B1) and the layout (B3). It
  keeps this mathematics.
- So the verifier's sumcheck can be written and proved now, on L5's field and transcript, and it will not be redone.

**What now exists, in executable Lean.**
- **The sumcheck verifier**, line by line as `verify` runs it: the round count, each round's length, the check
  `s(0) + s(1) = claim` on the 64-bit words, the absorb, the challenge, the interpolation.
  - PROVED: together with the caller's final check, it accepts EXACTLY when the list verifier of L3's Fiat–Shamir
    theorems (`scAccept`) accepts the same rounds with the transcript chain's own challenges, for every hash function.
  - So those theorems now speak about the program's acceptance condition, not about a paraphrase of it.
  - One piece of glue is left per profile: listing the receipt's transcript items in the form `FSChainRbr.lean` reads
    (finding L6-4, §8.5).
- **The interpolation** of a round message (`interpolate_eval`): PROVED to be the model's (`interpEval`, the round
  polynomial's value).
- **The eq tables and multilinear evaluations**: PROVED to be the model's `eqPoly` and `mleAt`, in the code's bit order
  (variable 0 is the most significant bit of an index).
- **The zero-knowledge mask (CFS)**:
  - PROVED: the code's weight vectors give the mask's sum over the cube and its value at the challenge point;
  - its round messages are the hiding model's;
  - the code's mask rounds pass the verifier's checks (the mask part of the masked prover's completeness).
- **The last-round extension and the masked terminals**: PROVED to be the hiding model's, and to be the last round of
  L3's extended polynomial. So the extension's soundness theorem applies to what the code sends.

**The agreement corpus.**
- The Rust test exports 1,561 records from the crate's real code paths:
  - interpolations (degrees 0 to 6), eq values and tables, multilinear evaluations;
  - CFS weights, masks, values and rounds, masked terminals, extension rounds;
  - 171 whole sumcheck runs made by `prove` and checked by `verify`: plain, masked, and masked with the extension
    round as a private slot runs it; honest and tampered.
- Lean recomputes every record: **1,206 checks, 0 failed.**
  - For every run Lean's verdict equals Rust's (accepted, or refused with the same message bytes), with the same
    challenges and the same transcript state after the call.
- **Negative control:** eight single changes give exactly 8 failures.

**What this does not do yet.**
- It is not a per-profile verifier. The receipt decoder, W16R3's slot items and terminal identities (B2's batching),
  the zero-check and LogUp arithmetic, the openings, `M` and the schedule are still to write (§8.5).
- The corpus has no record from a real block receipt. Its runs are the crate's real `prove` / `verify` path on
  synthetic tables.

### 8.2 What is proved

All PROVED (`results/zk60_lean_l6_20261106/`):
- the full `lake -d formal build` is green: 3,452 jobs, no warning, no error (`full.log`, `check.log`);
- `#print axioms` on all 128 theorems of the three files (`axioms_l6.lean`, written by `gen_axioms.py`, →
  `axioms.log`): each shows only `propext`, `Classical.choice` and `Quot.sound`, or a subset; `sorryAx` and
  `Lean.ofReduceBool` appear nowhere;
- every premise is an explicit hypothesis; no `sorry`, `axiom`, `native_decide`, `bv_decide`, `admit`,
  `implemented_by`, `extern`, `maxRecDepth` or `maxHeartbeats` (source scan in `check.log`: none).

The reading is L5's: `toK U` maps a code word into ANY field `K ⊇ GF` with `U² = 7` (for `K = GF[u]/(u² − 7)` a
bijection, `Fp2.toK_bijective`).

**`ExecMle.lean`** (mirrors `mle.rs`, and `from_i64` of `field.rs`).

| Theorem | Statement |
|---|---|
| `Fp.toGF_fromI64`, `Fp.toGF_inv'`, `Fp2.toK_injective` | `from_i64` is the residue on `(−2^64, 2^64)`; `Fp::inv` is the field inverse of every word (`0` included); canonical words are determined by their value, so the code's word equality is the field's equality |
| **`toK_interpolateEval`** | for `d + 1` values (`d < p`) and a canonical point, `interpolate_eval` is `interpEval`, hence the value of `roundPoly` (`interpolateEval_roundPoly`); `ringChar_eq_gP`, `interpolateEval_degree`: `d < ringChar K` is `d < p`, so the value form fixes one polynomial of degree `≤ d` |
| **`toK_eqPointBody`** | `eq_point(r, s)` is `eqPoly(r, s)` |
| `eqTableAux_spec`, `toK_eqTable`, **`toK_eqTableMsb`** | entry `idx` of `eq_table(r)` is `Π_i (r_i or 1 − r_i, by bit i of idx)` (the doubling loop on the buffer, step by step); of `eq_table_msb(r)` it is `eqPoly(r, b)` with variable `j` the bit `n − 1 − j` |
| `msbBits_msbIndex`, `msbIndex_msbBits`, `sum_range_msb` | the code's index and the cube point are a bijection `[0, 2^n) ↔ {0,1}^n` |
| **`toK_mleSumExt`**, **`toK_mleSumBase`** | `eval_mle_ext(v, r)` and `eval_mle_base(v, r)` are `mleAt` of the cube values `b ↦ v[msbIndex b]` at `r` |

**`ExecSumcheck.lean`** (mirrors `sumcheck.rs::verify`, on L5's transcript).

| Theorem | Statement |
|---|---|
| `scAccept_iff` | `scAccept τ n f C` is: exactly `n` rounds, every round check, and the final claim equal to `f` at the challenge vector |
| `scLoop_ok_iff`, `scExecOk_iff`, `toK_scFinalExec` | the program's loop returns `Ok (fin, rs)` exactly when every round has `d + 1` values and passes its word check along the transcript's challenges; those checks and the final claim are the field's |
| **`scVerify_accept_iff`** | for `1 ≤ d < p`, a canonical claimed sum and canonical round values, every hash function `H` and every `f`: `verify` returns `Ok (fin, rs)` with `fin = f(rs)` in `K` EXACTLY WHEN every round has `d + 1` values, `rs` is the transcript's challenge sequence (`scChal`), and `scAccept (scTau rounds rs) n f claimed` holds |
| `scVerify_tr`, `scChal_runOps` | an accepting run leaves the transcript `runOps` of `absorb("sc-round", s_j)` and `squeeze` per round |
| **`scChal_chain`** | those challenges are `challenge_fp2` of the squeeze digests of `FSChain.lean`'s chain of the run's items (L5's `chainEnc`, with the code's counters); each is `fp2Chal gP (2^128)` of its digest's halves (`challengeFp2Of_toGF`) |
| **`scVerify_fs`** | the two together, from `new` / `new_tagged` after any header operations: the program accepts exactly when `scAccept` holds on the transcript whose challenges are the chain's |

What the caller must still check, as `argument.rs` does: `fin = poly(terminal values)` (the theorem's hypothesis
`fin.toK U = f(rs)`), that the claimed sum is the statement's (the slot scalar plus the hosted terms), and that the
terminal values are the openings' (the PCS and `M`).

**`ExecCfs.lean`** (mirrors `CfsMask`, `CfsMasker::mask_round`, `extension_round`, `masked_terminal`).

| Theorem | Statement |
|---|---|
| `cubeSum_cfsEval` | in any field, the mask polynomial's sum over `{0,1}^N` is `cfsTotal` |
| **`toK_total`**, `toK_total_eq_cubeSum` | for `1 ≤ N < 64`: `<coeffs, sum_weights(N, d)>` (`total`) is `cfsTotal`, the cube sum of `g` |
| **`toK_evalDot`**, `toK_eval` | `<coeffs, eval_weights(ρ, d)>` (`eval`) is `cfsEval`, i.e. `g(ρ)` |
| **`toK_roundBody`** | for `1 ≤ d < 2^64`, `N < 64` and a canonical `a_0`: `round(j, prev)` at `x = 0..d` is `peval (cfsMaskRound a r j) x`, for every `r` that agrees with `prev` before `j` |
| `toK_maskRound` | the masked message at `x` is `s_x + c·g_j(x)`: the value form of `cfsView`'s round message |
| `interpEval_peval`, `toK_interpolate_round` | interpolating a degree-`≤ d` polynomial's values gives it back; so the verifier's interpolation of the code's mask round is `g_j(r_j)` |
| **`round_chain_zero`**, **`round_chain_succ`**, **`round_chain_terminal`** | the code's mask rounds pass the code's verifier's chain checks: round 0 sums to `total`, round `j + 1` to the interpolation of round `j` at `ρ_j`, and the last ends at `eval(ρ)`; with `cfs_masked_honest`, the mask part of completeness |
| **`toK_maskedTerminal`**, **`toK_extensionRound`** | `masked_terminal` is `maskedTerminal`; `extension_round` is `extRoundFun`, for any `poly` the program's `poly` computes |
| `extFe_halves`, **`extension_fe_round`**, **`extension_fe_terminal`**, `maskedTerminal_zero` | the code's extension round (`ext = R̃(ρ)` for a private table, `0` for a public one) is the last round polynomial of `SoundSumcheck.lean`'s `fe` at the challenge point, and the verifier's terminal `poly(masked terminals, (1 − ρ_k)·public)` is `fe(ρ, ρ_k)`; so `sumcheck_sound_extended` and `extension_halves` apply to what the code sends |

### 8.3 The agreement corpus

The Rust side is `zkp-core/tests/lean_l6_export.rs`, run by `export_corpus.sh`:
`cargo test --release --offline --locked -j 2 --test lean_l6_export` through the guard. It writes `corpus.txt`: 1,561
records, 323,299 bytes. Its own assertions pass too: every honest run verifies with the prover's challenges and final
transcript state, its terminal identity holds, each prover final is the table's `eval_mle_ext`, and every tampered
plain run is refused or fails its terminal check.

The Lean side is `L6Check.lean`, run by `check_l6.sh` (`l6check_full.log`). It uses the SAME definitions the theorems
are about, and adds cross-checks that use only Lean's own values. In all, 1,206 checks, 0 failed, in about 7 s,
interpreted:

| Kind | Checks | What |
|---|---|---|
| interpolation | 98 + 30 | `interpolate_eval` at degrees 0 to 6 (1 to 7 values), at the nodes, at `p − 1`, at `d + 1` and at random points; at a node Lean's value is the node's value |
| eq | 24 + 16 + 255 | `eq_point` (0 to 7 variables); `eq_table` and `eq_table_msb` (0 to 7 variables); each `eq_table_msb` entry is Lean's `eq_point` at the index's bits |
| MLE | 32 | `eval_mle_ext` and `eval_mle_base`, 0 to 7 variables |
| CFS weights | 20 | `sum_weights` and `eval_weights`, `N` from 1 to 11, `d` from 1 to 6 |
| CFS masks | 9 + 9 + 36 + 64 + 64 + 18 | nine masks of `CfsMask::random` (`N` 1 to 7, `d` 1 to 6): the length, `total`, `eval` (and the direct formula), every `round`, the chain with Lean's own rounds, the last round ending at `g(ρ)` |
| masked terminals, extension rounds | 40 + 18 | `masked_terminal`; `extension_round` for products (degrees 1, 2, 3, 5, 6) and the zero-check form |
| sumcheck runs | 171 + 171 | 171 `verify` calls: Lean's verdict, challenges and final transcript state equal Rust's (29 accepted; 142 refused with the same message bytes: 32 round count, 56 round length, 54 round sum); the transcript's start premise for each domain |
| run identities | 19 + 9 + 48 + 18 + 3 + 6 + 3 + 6 | the terminal `poly(finals)` (10 tampered runs fail it, as in Rust); the claimed sum is the cube sum; each final is the table's `eval_mle_ext` at the challenges; each masked round is the unmasked one plus `c·round(j)`; the masked terminal `+ c·g(ρ)`; the masked claim `S + c·G`; the extension round `extension_round + c·round(n)`; the extended terminal with the masked terminals and `(1 − ρ_n)·eq` (and with one mask value changed, it fails) |
| other | 18 + 1 | the CFS challenge drawn before each masked run; `"sc-round"` as bytes |

The runs: plain sumchecks of degree 1 to 6 over 0 to 8 variables (product polynomials, and the zero-check form with an
eq table), under the legacy and the rung's keyed transcript; masked (`CfsMasker` on the prover's transcript, degree 2
and 3); masked with one extension round as `argument.rs` runs a private slot (the zero-check form, 1, 4 and 5
variables). The tamperings: a dropped and an extra round; a round one value short or long (first, middle and last
round); `s(0)` off by one; the claimed sum off by one; the last value of a round changed (caught by a later round, or
only by the terminal check); wrong `n_rounds` and `degree` arguments; for the masked runs a round sum and the extension
round's sum.

**Negative control** (`mutate_corpus.py`, `negative_control.log`): one interpolation, one `eq_table_msb` entry, one
sum-weight vector, one mask round, one masked terminal, one extension round, one accepted run's final state and one
refused run's message changed. Exactly 8 checks fail.

### 8.4 Findings

**L6-1 (Info): `verify` panics on a degree-0 round.**
- CODE: `verify` checks `s.len() == degree + 1`, then reads `s[1]`. With `degree = 0` a round has one value, so `s[1]`
  is out of bounds: the process panics (and aborts: `panic = "abort"` in the release profile) instead of returning
  `Err`. The Lean mirror returns `ScErr.panic`.
- The model `scAccept` at `d = 0` reads `s 1` as `s 0` (`Fin 1` arithmetic), so it differs from the code there;
  `scVerify_accept_iff` is stated for `d ≥ 1`.
- No soundness or hiding effect: `degree` is the verifier's own public slot parameter, and every slot has degree at
  least 2 (`BASE_DEGREE` in `shape.rs`, minimum 2). The per-profile verifier should never build a degree-0 sumcheck.

**L6-2 (Info; for the per-profile verifier): the CFS weights are right only for `1 ≤ N < 64`.**
- CODE: `sum_weights` computes `from_u64(1 << N)` and `from_u64(1 << (N − 1))`, and `round` computes
  `from_u64(1 << (N − 1 − j))`, in `u64`. The release build has no overflow checks, so a shift amount `≥ 64` is taken
  mod 64 and `N − 1` wraps at `N = 0`.
- For `N ≥ 64` the weights are silently wrong (`1 << 64` gives `1`, not `2^64 mod p`). `N = 0` gives `[1, 1]`, which
  happens to be right.
- The Lean mirror computes with the release build's `UInt64` shifts, and `toK_total` / `toK_roundBody` assume `N < 64`.
- `N = n_vars + ext` is a slot's cube dimension, fixed by the profile and far below 64 (at most about 30 at 8B
  [ESTIMATE]). The per-profile verifier needs `N < 64` for every slot: a `decide` on the shape table.

**L6-3 (Info; modelling): exact casts and rayon's reduction.**
- `interpolate_eval` computes `i as i64 − j as i64` and `Fp::new(j as u64)`. The mirror takes the exact integer, which
  is the code for `d < 2^63` (the code's `d ≤ 6`).
- `eval_mle_ext` and `eval_mle_base` sum with rayon's `reduce`, in a tree; the mirror sums left to right. Every partial
  sum is a canonical word (`add`'s output is canonical) and the field's addition is associative and commutative, so the
  words are equal (`Fp2.toK_injective`). This is an argument, not a Lean theorem about rayon; the 32 MLE records and
  the 48 run finals agree.

**L6-4 (Info; for the composition): the chain's items and the squeeze counter.**
- `scVerify_fs` proves the program's acceptance in terms of L5's `chainEnc` (items `TItem`, with the code's wrapping
  `u64` squeeze counter).
- `FSChainRbr.lean`'s `fs_sumcheck_chain_sound_code` is stated for a `ChainEnc` over `PItem X M`, whose squeeze items
  carry a `ℕ` counter. A `ChainEnc` for the code's encoding needs an injective link, which a wrapping `u64` counter
  gives only below `2^64` squeezes.
- So applying the bound needs a `PItem` variant with a bounded counter, or the state function `liftSt` re-stated over
  `TItem` (with the header absorbs as the statement and the counter offset, as `FSChainRbr.lean`'s header notes).
- No soundness effect (`2^64` squeezes do not happen). It is the per-profile glue named in §8.5.

**L6-5 (Info): a refusal leaves the transcript advanced.**
- CODE: `verify` takes `&mut Transcript`; refusing in round `j`, it has already absorbed and squeezed rounds
  `0 … j − 1`. The corpus records the state after every refusal, and the Lean mirror reproduces it.
- `argument.rs` returns the error (`?`), so nothing continues on that transcript. A caller that recovered from an
  `Err` and kept the transcript would be on another chain.

### 8.5 What is left for the per-profile verifier

- **W16R3's slot items** (frozen by Sol's design §7; not modelled here): the batched sumcheck's claimed sum (B2's
  descriptor), its degree and round count, and each slot's terminal identity (the `poly`, the eq, public and private
  terms, `sel`, the hosted scalars), each proved to be its `CircuitBlock.lean` / `SoundZeroCheck.lean` model.
  `scVerify_accept_iff` then gives each sumcheck's acceptance.
- **The item map** (L6-4): the receipt's transcript items onto `FSChainRbr.lean`'s chain (or `liftSt` over `TItem`), so
  that `fs_sumcheck_chain_sound_code` and `FSCompose.lean` apply to the whole receipt's chain.
- `1 ≤ d` and `N < 64` for every slot (L6-1, L6-2): a `decide` on the shape table.
- The rest of §7.5: the `Protocol` instance, the receipt decoder (L5-2), LogUp, the openings and `M`, the schedule, a
  corpus of real W16R3 receipts with malicious controls, and a compiled checker.

### 8.6 Checks

All in `results/zk60_lean_l6_20261106/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`; peak RSS at most 6.72 GiB, the final full check):
- `file1.log` … `file8.log`: the new files while they were written (`lean_file.sh`, `stage.sh`). The errors fixed on
  the way are in those logs.
- `rust.log`: the corpus export (`export_corpus.sh`).
- `l6check.log`: the modules built and `L6Check.lean` run on the corpus (`run_l6check.sh`).
- `check.log`: `check_l6.sh`, run twice (before and after a comment-only correction of the three files' headers;
  both green), which runs:
  - the full build (`full.log`): 3,452 jobs, rc 0, no warning, no error;
  - the axiom audit (`axioms.log`): 128 theorems, nothing beyond `propext`, `Classical.choice`, `Quot.sound`;
  - the source scan (none);
  - the agreement check (`l6check_full.log`): 1,206 checks, 0 failed;
  - the negative control (`negative_control.log`): 8 failed, as required.

## 9. Step L7, Fiat–Shamir soundness of the executable sumcheck verifier, end to end (2026-11-06, fifth lane)

Lean lane (Claude), on perf at 8e565e05 (L6 merged). One new library file, imported by the library root:
`formal/ZK60Formal/ExecSumcheckFS.lean`. No Rust: the L5 and L6 corpora already pin every encoding used here, and both
are re-checked as regressions. `Statements.lean`, every existing Lean file and every production source are unchanged.
Sol's W16R3 design file was not read for this step and not changed. Evidence: `results/zk60_lean_l7_20261106/`.

### 9.1 In plain words, for Victor

**Why this step.**
- L6 proved that the Lean copy of `sumcheck::verify` accepts EXACTLY when L3's list verifier `scAccept` accepts, on the
  transcript's own challenges.
- L3 proved the Fiat–Shamir bound for `scAccept` on a hash chain, but on a MODEL of the chain: one "statement" item,
  then message and squeeze items whose counter is a natural number counted from 0.
- The code's chain is different in three ways (finding L6-4): the statement is SEVERAL absorbs (the header), the
  squeeze counter is a 64-bit word that wraps, and it counts every squeeze since the transcript began, so a sumcheck
  after a header starts at some counter `c0`, not 0.
- So the bound was not yet a theorem about the program.

**What now exists.**
- **A theorem about the program** (`exec_sumcheck_fs_sound`). PROVED: take any cheating prover that makes at most `q`
  hash queries. It may choose:
  - any header of `s` transcript operations (absorbs and squeezes: the public statement, earlier sumchecks, anything);
  - a false claim (`C ≠ Σ f`), where the polynomial `f` and the claim `C` may depend on everything in the header,
    including the challenges squeezed there;
  - the round messages.
- The executable Lean `sumcheck::verify`, run on the code's own transcript after that header, then accepts (with the
  caller's final check `fin = f(rs)`) with probability at most:
  - `T·d/|F|·(1 + p/2^128)²` plus two hash-collision terms;
  - where `T = q + s + 2n + 1`;
  - this is exactly the bound of L3's model theorem, now for the program.
- **The wrapping counter needs no premise.** The proof reads the protocol back from the code's own chain, and it never
  reads the counter. The counter is still hashed, so the chain stays unambiguous. No "`c0 + n < 2^64`" assumption is
  needed: the counter could even repeat without harm, because every hash input also carries the previous digest.
- **The bridge is general.** `fs_code_chain_sound` applies to ANY round-by-round sound protocol whose rounds are "one
  labelled absorb, then one squeeze" on the code's chain after any header (the sumcheck is one instance). Rounds with
  several squeezes or no message (LogUp's challenges, the openings') need the same reader in `FSWideRbr.lean`'s wide
  form (§9.5).
- **The numbers at a slot's shape** (for orientation only). PROVED in Lean: with Goldilocks (`|F| = p²`), degree
  `d ≤ 4`, and `T ≤ 2^64 + 2^20` (for example `q = 2^64` queries, `n = 30` rounds and a header of up to about a million
  operations), the bound is at most `2^-61` (`exec_sumcheck_fs_sound_slot`). The exact value at `q = 2^64`, `n = 30`,
  `d = 4` is about `2.17·10^-19 ≈ 2^-62` [ESTIMATE: exact rational arithmetic outside Lean].

**What this does not do.**
- It is about ONE sumcheck after a header. The receipt runs many sub-protocols on one chain. Composing them so that
  the rate is the MAXIMUM over rounds, not the sum, is `FSCompose.lean`'s job, which still reads `PItem` chains; the
  per-profile instance has to apply this file's bridge to that composition (§9.5).
- The polynomial `f` here is a function of the header. In a receipt it is the multilinear extension of COMMITTED tables,
  so tying it to the header is the extractor's part (`SoundExtract.lean`), not this file's.
- W16R3's slot layout, batching (B2), PCS encoder (B1) and layout (B3) are not modelled, by design.

### 9.2 What is proved

All PROVED (`results/zk60_lean_l7_20261106/`):
- the full `lake -d formal build` is green: 3,453 jobs, rc 0, 0 warnings, 0 errors, no `sorry` (`full.log`,
  `check.log`);
- `#print axioms` on all 39 theorems of the file (`axioms_l7.lean`, written by `gen_axioms.py`, → `axioms.log`): 24 on
  `propext, Classical.choice, Quot.sound`, 8 on `propext, Quot.sound`, 4 on `propext`, 3 on none; `sorryAx` and
  `Lean.ofReduceBool` appear nowhere;
- no `sorry`, `axiom`, `native_decide`, `bv_decide`, `admit`, `implemented_by`, `extern`, `maxRecDepth` or
  `maxHeartbeats` (source scan in `check.log`: none).

**The bridge: the protocol's state on the code's chain.**

| Theorem / definition | Statement |
|---|---|
| `cStep`, `cDecode` | the reader of the code's chain entries after the header: an absorb under the label `lab` is the round's message (`dec` of its bytes), the next squeeze completes the round with `chal` of its digest (its counter is not read); anything else leaves the schedule |
| `codeSt` | the state of a code chain transcript with a header of `s` entries: not doomed while the header is incomplete; then the protocol's state of `stmtOf (header entries)` (items, counters and digests) and the transcript `cDecode` reads off the rest |
| **`codeSt_round`** | for an RBR-sound protocol (`e` escaping challenges per round) and a derivation `chal` with at most `K` digests per value: from a doomed chain of at least `s` entries, whatever the next item, at most `e·K` digests escape |
| `cDecode_rounds` | the verifier's round operations (`absorb lab (enc m)`, `squeeze`, from any counter `c`) read back as exactly the messages `dec (enc m)` and the challenges `chal` of the squeezes' digests |
| **`fs_code_chain_sound`** | `chain_sound` on the code's chain: for any `ChainEnc` whose items read as code items, a `q`-query prover makes the header's chain doomed and the whole chain alive with probability at most `T·e·K/|D| + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1` |

**The code's chain on the finite oracle domain.**

| Theorem / definition | Statement |
|---|---|
| `TItem.len`, `Op.len`, `TItem.msg_length` | an item's hash input has `48 + |label| + |data|` (absorb) or `47` (squeeze) bytes |
| `chainEncB` | L5's `chainEnc` restricted to the items of at most `L` bytes: a `ChainEnc (ItB L) (QB L) Dig` (its decoder and the start premise from L5) |
| `lastD_liftH`, **`chainFrom_liftH`** | under `liftH G`, L5's chain of those items is `chainEncB`'s chain under `G` |
| `opItems_append`, `runOps_counter`, `opItems_fit`, `liftItems_val`, `liftItems_append` | the items of `ops₁ ++ ops₂` (the counter after `ops₁` is `opsCtr`, the executable transcript's counter); operations of at most `L < 2^64` bytes give items the code hashes unambiguously |
| `opTrace`, **`opTrace_chainFrom`** | the header's trace (each operation's item with the code's counter, and the transcript's state after it, as the executable transcript computes them) is the chain's entries |
| `decMsg`, `decMsg_enc`, `zip_dec_scTau` | the reader's message of the absorbed bytes of `d + 1` canonical values is L6's `msgK`; the reader's transcript of the rounds is L6's `scTau` |

**The challenge and the bound.**

| Theorem | Statement |
|---|---|
| `halves`, `halves_injective`, `challengeFp2Of_toK` | a digest's two 128-bit halves, injectively; `challenge_fp2` read in `K` is `fp2Field gP (2^128) ι` of them (`ι` the field reading `(a, b) ↦ a + U·b`, a bijection when `finrank GF K = 2`) |
| `card_filter_le_of_injective`, **`card_chal_fiber_le`** | every challenge value has at most `(⌊2^128/p⌋ + 1)²` digest preimages |
| `card_dig`, `card_of_pairs`, `dig_bound_le` | `|Dig| = 2^256`; `|K| = p²`; `a·(⌊2^128/p⌋+1)²/|Dig| ≤ a/|K|·(1 + p/2^128)²` |
| `ScWin`, `scSt`, **`scWin_flip`** | the prover's win (below) makes the header's chain doomed and the whole chain of the verifier's items alive, for the sumcheck's state function (`sumcheck_rbr`'s) |

**The end-to-end theorem.**

`exec_sumcheck_fs_sound` (PROVED). Premises:
- `K` a finite field `⊇ GF` with `finrank GF K = 2` and `U² = 7`;
- `key` (the mode: legacy or the profile's Fiat–Shamir key) and a `domain` string with `decodeLink (startMsg domain) =
  none`;
- `L` with `|startMsg domain| ≤ L`, `56 + 16(d + 1) ≤ L` and `L < 2^64`;
- `1 ≤ d < p`; any `n`, any `s`, any statement map `stmt` from the header's trace to `(f, C)`;
- `A`, an oracle algorithm on `QB L → Dig` making at most `q` queries, outputting a header (`List Op`) and the rounds.

Then `prH (ScWin …) ≤ (q + (s + 2n) + 1)·d/|K| · (1 + p/2^128)² + collBound (q + (s + 2n) + 1) Dig + collBound (q + (s +
2n) + 2) Dig`, where `ScWin` (the event, with `G` the oracle and `liftH G` the verifier's hash) is ALL of:
- the header has exactly `s` operations, each hash input at most `L` bytes;
- every round value is a canonical word, and the claimed sum `C` is canonical;
- for `(f, C) := stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) header)`: `IndDegLE d f` and `C ≠ Σ f`;
- `(scVerify (liftH G) C d n rounds (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) header)).1 = .ok (fin, rs)` and
  `fin = f(rs)` in `K`.

Corollaries:
- `exec_sumcheck_fs_sound_goldilocks`: `|K| = p²` and the bias `(1 + 2^-64)²`.
- `slot_bound_le`, `exec_sumcheck_fs_sound_slot`: with `d ≤ 4` and `q + (s + 2n) + 1 ≤ 2^64 + 2^20`, the probability is
  at most `2^-61` (the first term at most `3·2^-63`, each collision term at most `2^-126`; `natFrac_le`,
  `natFrac_mul`).

### 9.3 Why the bridge reads the code's chain rather than building a `PItem` encoding

- A `ChainEnc` hashes ONE link per item. The header is several links (each absorb of the public statement, every
  squeeze before the sumcheck), so it cannot be `PItem.stmt x`'s single link.
- Mapping `PItem.sq j` to the code's counter `c0 + j` as a `u64` is not injective over `ℕ`; a `ChainEnc` would need
  `j < 2^64 − c0`.
- Reading the code's own chain, which L5 already proved injective (`decodeLink_msg`), needs neither. The reader never
  reads the counter: the RBR argument only needs SOME state function satisfying the round condition, and the chain
  argument (the trace-back, the collisions, the guesses) works on the code's chain as it is.
- The cost: `FSChainRbr.lean`'s `liftSt_round` is re-proved for the code's items (`codeSt_round`, the same case
  analysis, 40 lines).

### 9.4 Findings

**L7-1 (Info; closes L6-4): the wrapping `u64` counter needs no premise.**
- There is no counterexample: two squeezes with the same counter value hash different inputs unless their previous
  digests collide, and a collision is already paid for in the bound (`collBound`).
- So `fs_code_chain_sound` has no counter premise at all. L6-4's "`2^64` squeezes" condition is not needed.

**L7-2 (Info; for the per-profile instance): `sumcheck::verify` does not absorb the claimed sum.**
- CODE: `verify` absorbs only the round values. The theorem takes the claim `C` as a function of the header's trace,
  so the per-profile instance must show that each slot's claimed sum is computed from the header (absorbed values and
  squeezed challenges).
- If a caller's claim were NOT determined by the header, the theorem as stated would not apply. An argument suggests
  the sumcheck would still be sound: round 0's check `s₀(0) + s₀(1) = C` pins `C` to the absorbed `s₀`, and a false
  `C` forces `s₀` off the true round polynomial before `r₀` is drawn. That argument is NOT proved here.

**L7-3 (Info): a fixed header length.**
- The theorem fixes the number `s` of header operations; a per-profile verifier's schedule fixes it for each slot.
- A profile whose schedule length depends on the statement would pay a union over the possible lengths, or need the
  prefix-free generalization of the header (not done).

**L7-4 (Info, engineering): concrete huge `Finset.univ`s and the literal `p` in proofs.**
- The first draft of the file was killed by the guard at its 24 GiB cap after 75 s. The runaway was the one-line proof
  of `|K| = p²` with the LITERAL Goldilocks `p` (the same proof with a variable `p` is instant).
- A membership proof in `Finset.univ` of `Fin (2^128) × Fin (2^128)` or of the digests reached Lean's recursion limit.
- Fix: such facts are stated for a variable `p` or abstract finite types, then instantiated (`card_of_pairs`,
  `dig_bound_le`, `card_filter_le_of_injective`, `slot_bound_le`). The file then elaborates in 4 s at 3.65 GiB. Later
  lanes working with the concrete `p` or digest types should do the same (bisection logs in the evidence directory).

**L7-5 (Info): no compiled checker target this step (L5-5).**
- A `lean_exe` target would not change how `lake build` builds the library (the default target stays the library).
- But building it compiles every imported module, Mathlib's included, to native code. The cache holds `.olean` files,
  not native objects, so the first `lake build` of the target is a many-hour job that this lane could not validate. It
  is left for a lane with that budget.

### 9.5 What is left

- **The composition on the code's chain.** `FSCompose.lean` (the per-round MAXIMUM over sub-protocols on one chain)
  and `FSWideRbr.lean` (vector challenges) still read `PItem` chains. Their `liftStW` should be re-stated with this
  file's reader (`codeSt` with a schedule of labels and widths), as here for one sumcheck, so that the whole receipt's
  chain gets the composed rate. The arguments are the same; the item map is this file's.
- **Per slot**: each slot's claimed sum as a function of its header (L7-2); `1 ≤ d`, `N < 64` (L6-1, L6-2); `L` for the
  profile (L5-4) and the decoder's size bounds; the start premise per profile string (L5-3).
- **The polynomial as the committed tables'**: the extractor (`SoundExtract.lean`) composed with this bound.
- The rest of §8.5 and §7.5: W16R3's slot items, the `Protocol` instance, the receipt decoder, LogUp, the openings and
  `M`, the schedule, a corpus of real W16R3 receipts, a compiled checker.

### 9.6 Checks

All in `results/zk60_lean_l7_20261106/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`):
- `file1.log`: the first draft, killed at the 24 GiB cap (L7-4).
- `bisect1.log`, `bisect2.log`, `var1.log` … `var5.log`: truncated and proof-stubbed copies (in the session scratchpad,
  never in the library), each under its own 8–10 GiB watchdog, that located the runaway; `var5.log`: the final file,
  4 s, 3.65 GiB, no message.
- `check.log`: `check_l7.sh`, which runs:
  - the full build (`full.log`): 3,453 jobs, rc 0, 0 warnings, 0 errors;
  - the axiom audit (`axioms.log`): 39 theorems, nothing beyond `propext`, `Classical.choice`, `Quot.sound`;
  - the source scan (none) and the root import;
  - the regressions: `L6Check` 1,206 checks, 0 failed (`l6check_regression.log`); `L5Check` 5,553 checks, 0 failed
    (`l5check_regression.log`).
- Peak RSS of the final check: 3.81 GiB.
