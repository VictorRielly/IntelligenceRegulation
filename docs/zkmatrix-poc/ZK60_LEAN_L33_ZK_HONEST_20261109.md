# D63 lane L33: zero knowledge of the classify run with the honest prover as an oracle program (2026-11-09)

Lean lane L33 (Claude), on its own worktree branched from perf at `0231da18` (lanes L9–L29 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Five new library files under `formal/ZK60Formal/`, imported by the library root:
`ZKHonestProg.lean`, `ZKHonestStep.lean`, `ZKHonestView.lean`, `ZKHonestCount.lean`, `ZKHonestRun.lean`. No Rust, no
production source, no existing Lean file changed (only the root's import lines); `Statements.lean` is unchanged.
Evidence: `results/zk60_lean_l33_20261109/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **CODE** (read off the
sources, file:line, 2026-11-09), **ESTIMATE** (arithmetic or reasoning not proved in Lean), **PREMISE** (a named
hypothesis a later lane must discharge).

## 1. In plain words, for Victor

**What this lane is.** Your Statement 2 says a receipt teaches nothing about the hidden post beyond what is declared.
For the media app's classifier run this is obligation O12 of lane L18's list. Lanes L14 and L19 proved the chain from
"the receipt's law at fixed challenges does not depend on the data" to your statement, for a prover given in a
particular form (a "receipt model"). No lane had put the real prover in that form. This lane was to do that and to
close O12 from named premises.

**The main thing I found (finding L33-1).** The chain L14 and L19 built cannot be applied to the real prover as it
stands. The real prover sometimes refuses and starts again (a challenge came out zero, about once in `2^57`
attempts). When it refuses it publishes only the constant word "refused". L14's and L19's one-receipt step asks two
things that cannot both hold at such a moment: that the verifier can recompute every transcript point from the receipt,
and that the points it cannot recompute are unpredictable from the prover's coins alone. A refused receipt shows
nothing, and the points before the refusal are not unpredictable from the coins alone (one of them absorbs only a slot
number). The refusals are far too frequent to be written off as an error term (`2^-57` against a target near
`2^-120`).
- Nothing L14 or L19 proved is false. Their theorems are true of a prover that never refuses.
- I re-proved the one-receipt step for a prover that refuses (`fs_step_ref`). It needs one new fact about the prover,
  which the code has (lane L4's classes, rulings D65(2) and D66(3)): whether an attempt is refused depends on the
  challenges and public data only, never on the hidden data.
- The price is in the counting (finding L33-3). With the refusals accounted for, this proof gives your target for a
  whole classify run as one receipt up to `R ≤ 2^110` receipts per weight set, not `2^112`; and for ONE block receipt
  up to `2^118`, where L19 had "every R". These are caps of this PROOF, on L19's ESTIMATED counts. `2^110` receipts is
  about `10^33`. The cap question was already yours to rule on (L19-2); the number moved by two bits.

**What now exists.**
- **Any prover written as a program is a receipt model.** A prover is written as a program that asks the hash at two
  kinds of points: public ones (the same for every post: the run header before the first fresh commitment) and fresh
  ones (everything after). PROVED: such a program IS L14's receipt model and a query-bounded computation, with the same
  output for every hash function, input and coin. The transcript programs lanes L25 and L29 wrote are programs in this
  sense (`ofT_run`).
- **The one-receipt step and zero knowledge for a prover that refuses** (`fs_step_ref`, `oneStepW_ref`,
  `zk_of_refModel`, `zk_of_prog`). The inadmissible inputs (the sealing pass refuses them; that is the "served" bit of
  the declared leakage) are handled once and for all: the receipt model is needed on admissible inputs only.
- **For the classify run** (`classify_zk_of_model`, `classify_zk_cap110`, `classifyU_zk_cap110`): your Statement 2
  for the run as one receipt, from named premises, with the error within your target for every `q` and every
  `R ≤ 2^110` (and every `R ≥ 2^120`, where the target is at least 1), for L18's instance and for the corrected
  instance of L26. PROVED outright inside it: an inadmissible post always gets the same constant refusal; the stand-in
  the simulator uses is admissible exactly when the post is and has the same verdict.
- **An honest block's view** (`honest_block_view_law_eq`). L19 left two "links" as hypotheses (every slot's simulation
  data is a function of what the openings show; `M`'s value is a function of the slots' views). PROVED here for the
  honest prover of L25: both follow from the slot polynomials' own facts (degree, a standalone slot's zero sum, the
  terminal read off the openings), the hosts' sums, and `M`'s layout. The hand-off (every hosted slot is masked) is a
  theorem for the W16R2 and R13 slot schedule (`w16_hhosted`).
- **Counting tools** (`exposed_card`, `hit_card_by_label`, `hKw_exposed`): a point that shows an earlier hash value
  (every transcript point, Merkle node, salted leaf) is hit by a given query with chance `2^-256`, PROVED from the
  point's shape alone.

**What a receipt reveals, proved versus premise.**
- The declared leakage of the instance is exactly: the shapes `T` (tokens), `d` (width), `L` (blocks) and one bit,
  whether the post was served. The public output is the verdict. (`ClsLeak`, L18.)
- PROVED outright: a post the model does not admit gets the one constant refusal, whatever the post, the hash and the
  coins. So an unserved post reveals the served bit and nothing else.
- PROVED from the premises of §4: a served post's receipt can be produced by a simulator that sees only the verdict
  and the leakage, and no one making `q` hash queries and seeing `R ≤ 2^110` receipts tells the two apart with
  advantage above `q·2^-128 + R·2^-120`.
- Still PREMISES, not proved for the code: that the masks, pads and salts really make each layer's view independent
  of the post (the per-layer facts of §4), which points a receipt shows, the counts by kind, and that the real prover
  is the program the theorems speak of. Until those are discharged, Statement 2 for the app is a reduction, not a
  closed theorem.

**Privacy check you asked for (item 5).** I read the prover's refusal sites and the code that writes receipt bytes for
the classifier run. I found NO place where a receipt byte or a refusal depends on hidden data beyond the declared
leakage (§6, L33-6). The two fast paths lanes A8 and A27 reported change time only.

**What it does not do.**
- The run's prover is not assembled as one program. Each part needs its openings' provers as programs (lane L32 is
  writing them), the position tags, and the commitments' Merkle programs. The theorems take the program as a premise.
- The per-layer view facts for the real layout (`hterm`, `hsumH`, `hlay`, the openings' conditions, `hπ`, `hout`) and
  the counts (`hKc`, `hUw`, `hwb`, `hwba`, the rates) remain premises. So O12 is REDUCED, not discharged.

## 2. What is proved

All PROVED; the counts and the axiom audit are in §7.

### 2.1 A prover program is a receipt model (`ZKHonestProg.lean`)

| Theorem / definition | Meaning |
|---|---|
| `PProg`, `PProg.oc`, `PProg.run`, **`oc_run`** | a prover's oracle program with each question tagged public (`dep`) or fresh (`pt`); as `Statements.lean`'s `OC`; its run |
| `QLE`, **`oc_bounded`** | at most `n` questions on every path gives an `n`-question computation |
| `res`, `ptAt`, `ptAt_lt`, **`ptAt_congr`**, `DepIn`, **`ptAt_sep`**, `PtLE`, `ptAt_some_lt` | the program driven by VALUES; its `j`-th point reads only the values before `j` (causality) and the oracle only at the public questions |
| **`res_eq_run`** | if every point the walk asks has the oracle's own answer as its value, the walk is the run |
| `ptsOf`, `outOf`, `ptsOf_causal`, `ptsOf_sep`, **`outOf_chain`** | the `k` points (pad points `pad j (v (j − 1))` after an early stop) and the receipt; the receipt at the honest chain is the program's run |
| **`model`**, **`model_prove`** | L14's `FSModel` of a family of programs; its honest prover is the program's run for every oracle, input and coin |

### 2.2 One receipt for a prover that refuses (`ZKHonestStep.lean`)

| Theorem | Meaning |
|---|---|
| `progVis_of_no_vis` | with nothing visible, the oracle the distinguisher sees is the plain one |
| **`hid_card_ref`** | the hidden hits with a refusal guard `G`: L19's count where the guard does not fire; where it fires, the count over coins AND values that `hKw` gives; total `Pr_H[F]·|D^k|·(2·W₂)` |
| `fs_step_of_hid`, **`fs_step_ref`** | L19's `fs_step_w` from any bound on the hidden hits; with the guard: `Pr_H[F]·(2(W₁ + 2·Kc)/|C × D^k| + 2·(2·W₂)/|C|)`, both ways |
| **`oneStepW_ref`** | L19's `OneStepW` for a protocol with class (B) refusals (constant output on an inadmissible input, admissibility a function of the leakage) and class (C) refusals (the guard), from a receipt model on ADMISSIBLE inputs only |
| **`zk_of_refModel`** | `ZeroKnowledge` (Statements.lean's), stand-in simulator, error `Σ_{j<R} wStep δp ωp δh ωh εc q R j`; the after-request rates carry the guard's factor 2 |

### 2.3 The view (`ZKHonestView.lean`)

| Theorem | Meaning |
|---|---|
| **`hHV_rel_of_view`**, **`hHV_rel_of_layers`** | the receipt's law is the same for two inputs with the same public part, where the guard does not fire (L19's `hHV_of_view` / `hHV_of_layers` relative to the public output) |
| `honest_roundSum`, **`honest_hfac`** | for L25's honest rounds `honestCo`: the claimed sum is the true sum; L19's slot defect is `(0, 0, T)` once the terminal is a function `T` of the openings' view: L19's `hfac`, for every kind |
| **`honest_mHonest`** | the code's functional list `codeFunsAt` meets L19's honest conditions from the hand-off and the host sums stated on the polynomials |
| **`honest_block_view_law_eq`** | an honest block's whole composed view (openings, every slot, `M`) has a data-independent law; L19's `hfac` and `hM` DISCHARGED; generic in the slot list, so it serves a stage too |
| `w16Hosts`, **`w16_hhosted`** | the hand-off for the W16R2 / R13 slot schedule: every hosted slot is a private slot, hence masked |

### 2.4 Counts and the budget (`ZKHonestCount.lean`)

| Theorem | Meaning |
|---|---|
| **`exposed_card`** | a point that shows the value `v j` equals a given question for at most `1/|D|` of the coins and values |
| **`hit_card_by_label`**, **`hKw_exposed`** | with labels read off the points, a question is met at most `m·κ` times (`m` points with its label); for value-showing points `κ = |C × D^k|/|D|`: the transcript rate `mT·2^-256` |
| `refErr`, `three_le_four`, **`ref_cap_R`** | the error of a refusing prover at counts by kind `Z`; within `εzkTarget q R` for every `q` and `R ≤ 2^r` when `r + b ≤ 131`, `a + r + 134 ≤ 256`, `r ≤ 118` |
| **`runK_ref_cap_110`**, **`w16r2K_ref_cap_118`**, **`r13K_ref_cap_118`** | at L19's counts: a whole classify run `R ≤ 2^110`; one W16R2 block and one R13 block `R ≤ 2^118` |

### 2.5 The classify run (`ZKHonestRun.lean`)

| Theorem / definition | Meaning |
|---|---|
| `PProg.andThen`, `run_andThen` | sequencing prover programs |
| `askP`, `askP_run`, `ofT`, **`ofT_run`**, `ofStart`, `ofStart_run` | a transcript program of L25 / L29 as a prover program on `QB Lq`, its first `nd` transcript operations public; its run is `TProg.final` under the oracle |
| **`zk_of_prog`** | `ZeroKnowledge` for a protocol whose prover on admissible inputs is the run of a family of programs: the receipt model and the oracle computation are built from the programs |
| `classifyInputInhabited`, **`classify_adm_standin`**, **`classify_standin_verdict`** | the stand-in of a post is admissible exactly when the post is, and has its verdict |
| **`classify_zk_of_model`** | O12's statement `ZeroKnowledge (classifyModel S R) (classifyProtocol …)` from the premises of §4 |
| **`classify_zk_cap`**, **`classify_zk_cap110`** | the error within `εzkTarget` for every `q` and `R ≤ 2^r`; at L19's run counts, `R ≤ 2^110` or `R ≥ 2^120` |
| **`classifyU_zk_cap110`** | the same for L26's `classifyProtocolU` (`zkU_of_zk`) |

**The chain to the approved statement, now.** `classify_zk_of_model` (from `zk_of_refModel`, from `oneStepW_ref`, from
`fs_step_ref`, with L19's `zeroKnowledge_of_oneStepW` and L14's programming lemma unchanged) → `classify_zk_cap110`
(`ref_cap_R`, L19's `wBudget_le`) → `classifyU_zk_cap110`. `ClassifyOpen`'s field O12 is the first conjunct of
`classify_zk_cap110` at `base := hon.base` and `εzk q R := min (refErr RunK.kinds q R) 1`.

## 3. The numbers

| Quantity | Value | Label |
|---|---|---|
| a value-showing point is hit by one query | at most `1/|D| = 2^-256` of the coins and values | PROVED (`exposed_card`) |
| the guard's cost in the step | after-request term `2·(2·W₂)/|C|` against L19's `2·W₂/|C|` | PROVED (`fs_step_ref`) |
| after-request rates of a refusing prover | `2(δh + δp)`, `2(ωh + ωp)` | PROVED sufficient (`refErr`, `ref_cap_R`) |
| cap, whole classify run as one receipt | `R ≤ 2^110` (L19 without refusals: `2^112`) | PROVED on L19's ESTIMATED counts (`runK_ref_cap_110`) |
| cap, one W16R2 block, one R13 block | `R ≤ 2^118` (L19 without refusals: every `R`) | PROVED on L19's ESTIMATED counts |
| above `2^120` receipts | the target is at least `1` | PROVED (L19's `one_le_target_of_large`) |
| how often an attempt is refused | about `2^-57.5` | ESTIMATE (L25 §4) |

Why two bits. The dominant term is the other receipts' provers' transcript questions, `qpT·mT·2^-256` each. L19 charged
it before the request only. A refused receipt hides its transcript points, so questions asked AFTER the request are
charged at that rate too, and the split "guard fires / does not fire" doubles it: `3·qpT·mT·2^-256` in place of
`qpT·mT·2^-256`. In powers of two that is two bits.

## 4. What is left: the premises of `classify_zk_of_model`, by name

1. **The prover as a program.** `pOC`, `hrun`, `hbd` and `FM`, `hP`. `zk_of_prog` builds all five from ONE object: a
   family of programs `prog` with `hprog` (its run is the protocol's prover on admissible inputs), `hk` (at most `k`
   points), `hq` (at most `qp` questions), `hdep` (its public questions lie in `dep`), `hres` (the receipt does not
   read the public answers). Needed for it: the run assembled as a program (stage IN-C, each block, stage OUT-C; the
   openings' provers, L32; the position tags and `check_opening`'s replays, finding L33-4; the commitments' Merkle
   programs).
2. **What the receipt shows.** `vis`, `vp`, `hvis`: a visible point is computable from the receipt, the oracle and the
   values (every transcript point, node, position tag and opened leaf of a served receipt).
3. **The refusals are challenge-only.** `G`, `hvisG`, `hrefG`: at the values where a refusal fires, every admissible
   input and coin gives the constant refusal. Needs: L4's class (C) for every site (D65(2), D66(3)); the
   deterministic refusals never fire for the registered profile (L25-4, L29-5); the carry check `own` holds on the
   honest run (L25-1).
4. **The honest-verifier law** `hHV`, between two admissible inputs with the same verdict, where the guard does not
   fire. By `hHV_rel_of_layers`: `hπ` (the coins push to the layers' independent coins), `hout` (the receipt is a
   function of the verdict and the layers' views), and per layer `hlay`. Per block or stage layer, by
   `honest_block_view_law_eq`:
   - `hA`: the openings' law (L19's `openingsAH_law_eq`: independent reserved-pair and proximity coefficients, pad
     blocks surjective at the opened set, `H`'s zero-sum data);
   - `hf`, `hstd`: each slot polynomial's degree; a standalone slot's true sum `0`;
   - `hterm`: the slot polynomial at the challenges is a function of the openings' view (L19's `hclaim` with
     `terminal_of_claims`: the masked terminals are the claim values, in `build_claim`'s order);
   - `hsumH`: a host's true sum is `Σ ν_k·S_k`;
   - `hlay`: `M`'s committed messages against its combined weights carry the θ-combined functional;
   - `M`'s public conditions `hy`, `hsum`, `hW`, `hpad`; `hc` (the CFS challenge is not zero: true where the guard does
     not fire).
   - The hand-off `hhosted` is a THEOREM for W16R2 / R13 (`w16_hhosted`); the stages' slot lists need their own.
5. **The counts.** `hKw` (tools: `hKw_exposed`, `exposed_card`, `hit_card_by_label`; the column digests need their
   pads' freshness in the coins, L19-3), `hKc` (collisions and points landing in `dep`), `hKG` (`Kf z ≤ |D^k|·KUf z`: the
   after-request weight of a question is at least its before-request rate), `hUw` (hidden points of a served receipt:
   unopened leaves and columns), `hwb`, `hwba` (the prover's own questions by kind), `hKm`, `hKUm`, and the five rates
   at `RunK.kinds` (L19's counts are ESTIMATES until the program exists).

Not a premise any more: class (B) (`prove_unserved`), the stand-in's admissibility and verdict, the honest rounds'
properties, L19's `hfac` and `hM`, the hand-off at W16R2 / R13.

## 5. `ClassifyOpen`'s field O12

| | Before (L29) | Now (L33) |
|---|---|---|
| O12 `zk` | L14 / L19's chain with the honest prover's model a hypothesis; L25 discharged the honest rounds; nothing instantiated; cap `2^112` on estimated counts | **reduced** to the premises of §4 by `classify_zk_of_model`; the chain REPAIRED for a refusing prover (`fs_step_ref`, L33-1); the prover's model BUILT from any oracle program (`zk_of_prog`); class (B) discharged; L19's `hfac` / `hM` discharged for the honest rounds (`honest_block_view_law_eq`); the hand-off a theorem; the target for `R ≤ 2^110` (`classify_zk_cap110`) and its transfer to `classifyProtocolU`. NOT discharged outright |

## 6. Findings

No mismatch between the code and the approved statements was found. `Statements.lean` is unchanged and no statement
or target is weakened.

**L33-1 (Medium; for the coordinator and every lane that uses L14 / L19's step; no statement change): the
one-receipt step of L14 and L19 cannot be instantiated by a prover that refuses.**
- L14's `FSModel` asks `vis_pts` (a visible point equals `vp` of the receipt, the oracle and the values) and its step
  asks `hU` / L19's `hUw` at EVERY value vector (a query set read off the receipt catches a hidden point for few
  coins).
- CODE: the prover refuses at challenge-dependent sites inside a part, after earlier slots have absorbed masked data
  (argument.rs:1187 `c = 0`, :1478 a degenerate `e`, :1856 a zero batching challenge; protocol.rs:269, :315, :320;
  the LogUp refusals), and every refusal reads the same constant (D65(2)).
- At a value vector where such a guard fires, the receipt is the constant for every coin. A transcript point before
  the refusal that absorbed a masked scalar is not a function of (receipt, oracle, values), so it cannot be visible.
  As a hidden point it must be unpredictable from the coins at fixed values; a `pb-slot` absorb (data: the slot
  index, argument.rs:1171) has no coin entropy at all. So `vis_pts` and `hUw` cannot both hold there.
- Consequence: `oneStepW_of_fsModel`, `zk_every_R`, `W16R2K.every_R`, `R13K.every_R`, `RunK.cap_112` are true but
  have no instance among provers that refuse. They are not wrong.
- Done here: `fs_step_ref` / `oneStepW_ref` with a guard `G`. Where it fires, the oracle the distinguisher sees is the
  plain one and its questions do not depend on the values, so the hit count is the joint count `hKw` already gives.

**L33-2 (Low, modelling): the law equality must be relative to the public part, on admissible inputs.**
- L19's `hHV_of_blockLinks` / `hHV_of_layers` conclude for every two inputs. The classify statement carries the
  verdict (`ClsStmt.verdict`), so receipts of two posts with different verdicts differ.
- A receipt model for inadmissible inputs cannot meet `vis_pts` either (their receipt is the constant).
- Done here: `hHV_rel_of_layers` (same public part, guard); `oneStepW_ref` takes the model on the subtype of
  admissible inputs and treats an inadmissible request separately (both worlds answer the constant).

**L33-3 (Medium, for Victor, to be read with L19-2): with the refusals accounted for, this proof's receipt caps are
two bits lower.**
- PROVED: for a refusing prover the after-request rates `2(δh + δp)`, `2(ωh + ωp)` suffice (`zk_of_refModel` with
  `hKG`; `ref_cap_R`).
- PROVED on L19's ESTIMATED counts: a whole classify run as one receipt `R ≤ 2^110` (`runK_ref_cap_110`; L19:
  `2^112`); one block receipt `R ≤ 2^118` (L19: every `R`). Above `2^120` the target is at least 1.
- Options. (a) A sharper count of the guard's part: the value vectors where a guard fires are about a `2^-57` share,
  and each point's exposed value is independent of the guard's coordinate; this should give back L19's figures
  [ESTIMATE, not attempted]. (b) A hybrid with two budgets for the after-request questions (removes the factor 2, one
  bit). (c) L19-2's option (d), a per-receipt transcript key in W16R3, removes the cross-receipt transcript term
  altogether [ESTIMATE]. (d) Accept `2^110` as the cap for a run receipt. (c) and (d) are yours.

**L33-4 (Low, for lane L32 and the next lane): L25's transcript programs cannot express the clone questions.**
- CODE: `position_tag` (classify_run.rs:247, :251, :266, :301, :319, :322) squeezes a CLONE of the transcript twice;
  its output goes into the segment's frame, so it is part of the receipt. `check_opening` replays challenges on a
  clone too.
- A `TProg` continuation does not see the transcript's state after an absorb, so a clone's question cannot be written
  as an outside question of the program. For O9 the clones do not matter (L25-5). For zero knowledge they are points
  of the receipt.
- Here: `PProg` has no such limit, and `ofT` threads the transcript, so the run's program can be written in `PProg`
  with `andThen`. It was not assembled in this lane.
- Also: the same position tag is computed twice (the end of part `k`, the start of part `k + 1`). The program must ask
  it once, or the chain has two equal points.

**L33-5 (Info, modelling): what is public in the run's transcript.** CODE classify.rs:1275-1289, :1147-1153: the run
header is created from the profile string and absorbs `run-shape`, then `expected-IO`, whose data contains the input
endpoint's root (fresh by its salts). So the public points are the start question and the first absorb; every later
state, the binding included, is fresh. `FSModel.out` cannot read the oracle, so a receipt may depend on public answers
only through later points (`hres`); the classify receipt does (the binding is a later state).

**L33-6 (Info; the privacy check of item 5): no receipt byte or refusal was found to depend on hidden data beyond the
declared leakage.** Read, for the classifier run (CODE, 2026-11-09):
- the run prover, classify_run.rs:185-328: the sealing pass (class (B): `lookup_misses`, `check_lookup_misses`,
  `seal_check`, before any header), then one transcript; every later `?` is a part's refusal;
- the LogUp helpers, protocol.rs:901-915, :1125-1203, :1921-1958: a looked value refuses only at a zero table entry,
  and `table_helper` / `range_table_helper` refuse when ANY table entry's denominator is zero, so the refusal event is
  "α hits the public table" (L4's class (E), public tables); the fast paths change no word written;
- D66(3)'s challenge-only refusals: protocol.rs:1091-1110 (dictionary), stage_in_c.rs:322-331, stage_out_c.rs:574-585;
- the slot refusals, argument.rs:1187, :1478, :1856; the audits, protocol.rs:240-320.
- Limits of this reading: it is a reading, not a proof; timing is outside scope (D20); the claim "the code's sealing
  pass refuses exactly the inputs the Lean model does not admit" is the parity of the witness builder with the integer
  model, not checked here; P3 (hidden weights) would reopen class (E).

**L33-7 (Info): pad points.** A program that stops early (a refusal) has fewer than `k` points. The model fills the
rest with `pad j (v (j − 1))`: points that carry the previous value and no data. They are never visible (the guard
fired) and are as fresh as a transcript state (`exposed_card`). The instance chooses `pad` of a kind no real question
has.

## 7. Checks

All through the zk60 resource guard (class cpu, need 14 GiB, cap 24 GiB, `run_guarded.py`), logs and `.done` markers
in `results/zk60_lean_l33_20261109/`.

CHECKS_PLACEHOLDER
