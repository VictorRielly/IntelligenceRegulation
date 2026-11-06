# D63: the two approved statements assembled, and what is left for a production profile (2026-11-06)

Lean lane (Claude), on perf at 55aacdce. Lean 4.34.1, Mathlib v4.34.1, no new dependency. New file
`formal/ZK60Formal/Assembly.lean`, imported by the library root. `Statements.lean` is unchanged. No Rust and no prover
source changed. Evidence: `results/zk60_lean_asm_20261106/`.

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
  - `Complete`: nothing in Lean yet.
  - `Binding`: reduced here to Merkle binding plus a per-profile column map.
  - `ZeroKnowledge`: L4's lemmas are honest-verifier with fixed challenges. Still missing: Fiat–Shamir, the composition
    over the run and over several receipts, and a `Simulator` instance.
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
  obligations.
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
| `P` (the protocol) | **nothing as a `Protocol` instance.** Pieces of the verifier exist as models: `scAccept`, `chainAcceptsW`, `Tree.verOC` / `Tree.Accepts`, `MerkleEnc.Opens`, the opening and `M` tests. Pieces of the prover's view exist in the L4 files | `Stmt`, `Receipt`, `Salt`; `Leak` and `leak` (the shapes, `T`, the served bit, and D65(2)'s constant refusal); `ypub`; `opensIn` and `opensOut` (§4.4); `prove` (the Lean honest prover: masks, salts, the transcript); `verify`, the Lean verifier that §6 decision 3 makes production acceptance (step L5) |

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

### 4.3 `Complete M P εc`: nothing in Lean yet

- **Route:** `ArithComplete` (equivalent under `CircuitIff`). `CircuitIff`'s ⇐ direction already supplies the satisfying
  witness for an admissible input.
- **Missing:**
  - the Lean honest prover (§4.0, `prove`);
  - each sub-protocol's honest acceptance: the sumcheck, the LogUp identity on honest data, the openings of honestly
    built trees, and `M`'s tests;
  - the refusal probability `≤ εc`. The challenge-only classes (C)–(E) of the refusal table (L4 findings, third batch)
    are each `≤ k/|Fp2|`. Two examples: D66(3)'s dictionary refusal, about `cap·2^-88` per attempt, and the
    "`α` equals a table tuple" refusals of IN and OUT;
  - under Fiat–Shamir, the honest challenges are hash outputs at fresh points (the transcript carries fresh salts and
    roots), so they are uniform.
- Input-admissibility refusals (class B) are outside `Complete`: `tokenModel.admissible` is "the integer model does not
  refuse".
- **Target:** `εcTarget = 2^-40`.
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

### 4.5 `ZeroKnowledge M P εzk`: L4's honest-verifier lemmas exist; the rest does not

**Exists** (honest verifier, fixed challenges):
- the opened columns are uniform (`Hiding.lean`, `HidingRows.lean`, `HidingM.lean`);
- the opening views (`HidingOpening.lean`, `HidingOpeningSum.lean`, `HidingMOpening.lean`);
- the masked sumcheck over all rounds (`HidingSumcheck.lean`, `HidingSumcheckJoint.lean`);
- salted Merkle hiding in the random-oracle model (`merkle_hiding`, about `q·2^-239 + 2^-222` at `N ≤ 2^16`);
- the refusal bit (`HidingRefusal.lean`). `refusal_output_must_be_leaked` shows that `leak` must determine the refusal
  OUTPUT; D65(2)'s constant refusal meets it;
- one block composed (`block_view_law_eq_slot_M`).

**Missing:**
- a. **Fiat–Shamir.** The simulator programs `H` at the transcript points: the challenges, the sampled columns `J` and
   the opened set. It fails when the distinguisher asked a programmed point first: about `q/2^256` per point, because
   the transcript carries fresh salts, plus the salt-guessing term.
- b. **The links for the registered layouts.** Which claim value is which masked terminal; which `M` functional is
   which `g(ρ)` or `Γ`; `CfsMask`'s layout as `M`'s a-rows.
- c. **Several slots and blocks**, the D12a / D55 run, and the token stages IN and OUT.
- d. **`R` receipts.** One simulated receipt per request, composed by a hybrid (the `R·2^-120` term).
- e. **The `Simulator` instance** (its state is the programmed table and the simulated runs; `SCoins`; `step`), and
   `P.leak` defined as the declared leakage.
- f. **The error budget** against `εzkTarget`.

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
