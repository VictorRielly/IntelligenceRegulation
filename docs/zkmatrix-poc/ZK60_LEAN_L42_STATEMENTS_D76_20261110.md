# D63 lane L42: the approved statements amended by ruling D76 (2026-11-10)

Lean lane L42 (Claude Opus 5.5), on its own worktree from perf `c447ad00` (D76 and D77 ruled). Lean 4.34.1, Mathlib
v4.34.1, no new dependency. One existing file changed as ruling D76 directs, `formal/ZK60Formal/Statements.lean` (the
approved text: comments and five new declarations, nothing else); five new library files, all `StatementsD76*.lean`,
imported by the library root. No Rust. Evidence: `results/zk60_lean_l42_20261110/`.

**STATUS: deliverables 1 to 5 done. The full check of section 7 is green (exit 0): full build 3,657 jobs, no warning;
105 declarations audited, all on at most `propext`, `Classical.choice`, `Quot.sound`; regressions 0 failed.** The
merged-tree check is the coordinator's; it rebuilds every module (finding L42-8).

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**MEASURED** (counted by a script whose log is in the evidence directory), **ARGUED** (a reasoned claim, not a Lean
theorem), **HYPOTHESIS** (a named premise), **LEFT** (not done).

## 1. In plain words, for Victor

**What you ruled (D76).** (1) The leakage we allow must be written into the approved statements, not chosen by each
protocol, and the production theorem must name it. (2) Zero knowledge must hold for adversaries making at most 2^64 hash
queries and seeing at most 2^64 receipts; the error target stays q·2^-128 + R·2^-120.

**What changed in the approved text.** `Statements.lean` keeps every old definition, word for word. It gains five
definitions, and these are now THE approved zero-knowledge statements:

- `SimulatorL M P L`: a simulator whose input, for each proof request, has the type `M.PubOut × L`: the public output
  part and a value of the allowed leakage type `L`. Before, the type was `M.PubOut × P.Leak`, where `P.Leak` was chosen
  by the protocol `P`.
- `idealProbL M P Λ S W n Dist`: the ideal world. The simulator is shown each request `x` as

  ```lean
  S.step s (Sum.map id (fun x => (M.publicPart (M.forward W x), Λ x)) i) c
  ```

  Before, it was shown `P.leak x`, the protocol's own declaration.
- `ZeroKnowledgeL M P Λ εzk` (T2):

  ```lean
  def ZeroKnowledgeL (M : IntModel) (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L)
      (εzk : ℕ → ℕ → ℝ≥0∞) : Prop :=
    ∃ S : SimulatorL M P L, ∀ (W : M.Weights) (q R : ℕ)
      (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool), q ≤ 2 ^ 64 → R ≤ 2 ^ 64 → Dist.Within q R →
        realProb M P W (q + R) Dist ≤ idealProbL M P Λ S W (q + R) Dist + εzk q R
        ∧ idealProbL M P Λ S W (q + R) Dist ≤ realProb M P W (q + R) Dist + εzk q R
  ```

  Two things are new: the argument `Λ` (the simulator sees `Λ x`, nothing the protocol picks), and
  `q ≤ 2 ^ 64 → R ≤ 2 ^ 64 →` (it was every `q` and `R`).
- `SemanticHidingL M P Λ ε` (T2′): the same change. The adversary makes at most `q ≤ 2 ^ 64` hash queries, and the best
  guess it is compared with is `⨆ B : M.PubOut × L → β, …B (M.publicPart (M.forward W X), Λ X)…`.
- `ProductionReadyL M A P Λ εc εs εb εzk`, the gate: the same six fields as before; its `zk` field is
  `ZeroKnowledgeL M P Λ εzk` and its `semantic` field is `SemanticHidingL M P Λ (fun q => εzk q 1)`. Its fields
  `circuit`, `complete`, `sound` and `binding` are the old `CircuitIff`, `Complete`, `KnowledgeSound` and `Binding`,
  unchanged.

The old `Simulator`, `idealProb`, `ZeroKnowledge`, `SemanticHiding` and `ProductionReady` stay, unchanged in their
code. Their doc comments now say they are the "instance-leak forms" the proofs so far are about, NOT the approved
statements. The file header says the same. A script checks that every old code line is still there, unchanged and in
order, and that the 39 new code lines are exactly the five new declarations (MEASURED, section 7; it refuses both of
two planted single changes).

**The media classifier's allowed leakage, named.** One short definition, in a file of 33 lines
(`StatementsD76Leak.lean`):

```lean
noncomputable def classifyLeak (S : BlockShape) (R : ClassifyRunPublic S) (x : S.Tok → ℕ) : ℕ × ℕ × ℕ × Bool :=
  (S.T, S.d, R.Ps.length, (classifySpec R x).isSome)
```

It is the token count `T`, the width `d`, the layer count (the number of blocks) and whether the request is served
(the integer model returns a verdict). The verdict itself is the model's public output part, as before.

**Why a protocol that leaks can no longer pass.** The gap audit's toy publishes its input in clear. It passed the old
gate at every error, even at error 0, because it declared "the input" as its leakage (finding GB-1). It still passes
the old gate (PROVED again in the library: `leaky_productionReady`). It fails the new one (PROVED):

- Take two different inputs `x₀`, `x₁` with the same allowed leakage and the same public output.
- A distinguisher asks for ONE receipt on `x₀`, makes no hash query, and says "yes" if the receipt contains `x₀`. A
  second one does the same for `x₁`.
- With real receipts each says "yes" every time (probability 1).
- The simulator is shown the same thing for `x₀` and `x₁` (same public output, same `Λ`). So the two "yes" events are
  two different readings of ONE simulated receipt, and cannot both happen: their probabilities add up to at most 1.
- So one of them gains at least 1/2. The approved target at one receipt and no query is 2^-120.
- Hence `leaky_not_productionReadyL`: the toy fails the approved gate at every error below 1/2 at `(q, R) = (0, 1)`.
  The failure is at the smallest corner of the range, so the 2^64 range cannot rescue a leaky protocol.
- More generally, `productionReadyL_no_reader`: a protocol that passes the approved gate has no function that reads
  `x₀` and `x₁` back from all of their receipts; and `productionReadyL_ne_leaky`: it is not the toy. (A protocol that
  leaks only sometimes is caught by the statement itself, at a smaller advantage; these two theorems are the clean
  case.)
- For the media app's own model and `classifyLeak`: `leaky_not_productionReadyL_classify'` needs only valid public
  data and `T ≥ 1` (two items with ids `p` and `p + 1` are both refused, so they have the same leakage and output).

**What carries over.** Every result so far is about the old forms. When a protocol's own declared leakage is a function
of `Λ`, everything carries over (PROVED, `StatementsD76Bridge.lean`). For the classifier, all three protocol instances
declare exactly `classifyLeak` (PROVED: `classify_leaksAtMost`, `classifyU_leaksAtMost`, `classifyUExec_leaksAtMost`).
So the top gates hold in the approved form under the SAME premises as before (PROVED: `classifyUExec_productionReadyL_run_r13`
and `_w16r2` from L30's gates, `rt_productionReadyL_r13` and `rt_productionReadyL_r13_exec` from L34's gate). The last
one is at `classifyProtocolUExec`, the production target of D77.

**What the 2^64 range buys.** Every gate asked its zero-knowledge premise for every number of receipts. Lane L33 proved
the classify run's error meets the target only up to 2^110 receipts (and again from 2^120). So that premise cannot be
met by what is proved so far. Under D76 it only has to hold up to 2^64. This lane copies the gate chain with that premise on
the range only (`StatementsD76Range.lean`, the `…_range` gates), and proves the premise holds at L33's error
(`hzk_range_of_refErr`; PROVED, 46 bits of room). The approved zero-knowledge statement for the run then needs only
L33's own premise (`classifyUExec_zkL_target_of_refErr`).

**What this does not do.** It does not prove any premise of the gates (other lanes do). It pins the leakage only; the
public output part and the meaning of "the commitment opens" still come from the model and the protocol named in the
production theorem (finding L42-1). The gap audit's GB-2 (one shape for all 26 blocks) is untouched.

## 2. The amendment of `Statements.lean`

| Change | What | Kind |
|---|---|---|
| Header | A paragraph: D76's two amendments; THE approved statements are `CircuitIff`, `Complete`, `KnowledgeSound`, `Binding`, `ZeroKnowledgeL`, `SemanticHidingL`, `ProductionReadyL`; the old forms are the instance-leak forms, kept for the proofs, NOT approved | comment |
| `Protocol.Leak` | its doc: the instance's own declaration, read by the instance-leak forms only | comment |
| `Simulator`, `idealProb`, `ZeroKnowledge`, `SemanticHiding`, `ProductionReady` | doc: INSTANCE-LEAK FORM, kept unchanged because the proofs use it; NOT the approved statement since D76; the approved one is named | comment |
| New section "D76" after the targets | `SimulatorL`, `idealProbL`, `ZeroKnowledgeL`, `SemanticHidingL`, `ProductionReadyL` (39 code lines) | new declarations |

Unchanged in code (MEASURED by `l42_statements_check.py`): every definition, field, quantifier and error target of the
old file, among them `CircuitIff`, `Complete`, `KnowledgeSound`, `Binding`, the targets `εcTarget`, `εsTarget`,
`εzkTarget`, and `trivialArith`. The diff against perf `c447ad00` is `results/zk60_lean_l42_20261110/statements_d76.diff`.

Why this design (additive). Every lane's existing theorem concludes `ProductionReady` or one of its fields. Renaming or
changing those would break the library and the running lanes L39, L40 and L41. Keeping them and adding the approved
forms beside them keeps the build green, needs no edit outside `Statements.lean` and this lane's files, and merges
cleanly. The cost: a reader must know which names are approved. The header and every old doc comment now say it.

## 3. What is proved

All PROVED, at most `propext`, `Classical.choice`, `Quot.sound`.

**`StatementsD76Leak.lean`** (one screen)
- `classifyLeak`: the media classifier's allowed leakage, (T, d, the block count, served).
- `classifyLeak_served`: its last part is `true` exactly when the integer model admits the item.

**`StatementsD76Bridge.lean`** (from the instance-leak forms to the approved ones)
- `LeaksAtMost P Λ`: the instance's leakage is a function of `Λ` (`∃ f, P.leak = f ∘ Λ`).
- `SimulatorL.ofSim`, `idealProbL_ofSim`: an old simulator, read through `f`, is a new one with the same ideal world.
- `zeroKnowledgeL_of_zeroKnowledge`: old zero knowledge (every q, R) gives the approved one at the same error.
- `zeroKnowledgeL_of_zeroKnowledge_le`: the same with an error that bounds the old one on the range only (a capped form).
- `zeroKnowledgeL_target_of_cap`, `zeroKnowledgeL_target_of_cap_or`: a cap `R ≤ 2^r` with `r ≥ 64` (L33's `ref_cap_R`
  shape, and its `R ≤ 2^r ∨ 2^120 ≤ R` shape) gives the approved statement at `εzkTarget`; `pow64_le`.
- `zeroKnowledgeL_mono`: monotone in the error on the range.
- `semanticHidingL_of_semanticHiding`: the same for T2′.
- `withLeak`, `rangeCut`, `zeroKnowledge_withLeak`: the approved form is the old form of the instance with its leakage
  replaced by `Λ`, at the error cut to `⊤` outside the range.
- `semanticHidingL_of_zeroKnowledgeL`: T2 ⇒ T2′ for the approved forms (through L4's `semanticHiding_of_zeroKnowledge`).
- `productionReadyL_of_productionReady`: the old gate plus `LeaksAtMost P Λ` gives the approved gate, same errors.
- `productionReadyL_of_productionReady_range`, `productionReadyL_mono`, `productionReadyL_of_parts`: with larger errors
  (zero knowledge compared on the range only); from the four statement-1 parts and `ZeroKnowledgeL`.

**`StatementsD76Leaky.lean`** (the test the ruling exists for)
- `leaky`, `LStmt`, `leaky_publishes_input`: the gap audit's toy, unchanged; its statement carries the input.
- `leaky_complete`, `leaky_sound`, `leaky_binding`, `leaky_zk`, `leaky_productionReady`: it passes the OLD gate at
  every error (the gap audit's GB-1, re-proved in the library).
- `readOut`, `readDist`, `readDist_within`, `readDist_runState`, `readOut_inr`, `readOut_eq`: the distinguisher (one
  request, no hash query).
- `pmf_add_le_one_of_disjoint`, `half_le_of_one_le_two`: two disjoint events add up to at most 1; `1 ≤ 2ε ⇒ ε ≥ 1/2`.
- `zeroKnowledgeL_reader_half`: a reader of two inputs with the same `Λ` and public output forces `εzk 0 1 ≥ 1/2`.
- `leaky_not_zeroKnowledgeL`, `leaky_not_productionReadyL`: the toy fails the approved statements at any error with
  `εzk 0 1 < 1/2`; `εzkTarget_zero_one_lt_half` (`2^-120 < 1/2`); `leaky_not_productionReadyL_target`: at the targets.
- `productionReadyL_no_reader`: a protocol meeting the approved gate has no such reader; `productionReadyL_ne_leaky`:
  it is not the toy.
- `leaky_old_passes_new_fails`: both facts side by side (old gate at errors 0; approved gate failed at the targets).
- `classifyLeak_eq_of_spec`, `leaky_not_productionReadyL_classify`: for `classifyModel`, `classifyArith`,
  `classifyLeak`, from two different items with the same `classifySpec` result; `classifySpec_none_of_ge`,
  `leaky_not_productionReadyL_classify'`: with no premise on the items (`T ≥ 1`, valid public data).

**`StatementsD76Gate.lean`** (generated by `l42_mk_gate.py`; the classify run)
- `clsLeakOf`, `served_eq`, `clsLeak_eq`: L18's `ClsLeak` value of an item is `classifyLeak`'s, field by field.
- `classify_leaksAtMost`, `classifyU_leaksAtMost`, `classifyUExec_leaksAtMost`: the three instances (L18, L26, L30)
  leak no more than `classifyLeak`. (`classifyProtocol` is superseded by D77; its lemma is kept for completeness.)
- `classifyU_zkL_target_of_refErr`, `classifyUExec_zkL_target_of_refErr`: from L33's own premise (the run zero
  knowledge at a refusing prover's error `refErr RunK.kinds`), the approved zero-knowledge and semantic-hiding
  statements at the TARGET, at `classifyProtocolU` and at `classifyProtocolUExec`.
- `hzk_range_of_refErr`: L33's error `min (refErr RunK.kinds q R) 1` is within `εzkTarget q R` for `q, R ≤ 2^64`.
- **`classifyUExec_productionReadyL_run_r13`**, `classifyUExec_productionReadyL_run_w16r2`: L30's gates at the
  production instance, concluding `ProductionReadyL … (classifyLeak S R) εcTarget εsTarget εsTarget εzkTarget`, under
  the same premises (the statements are copied from `RunChainUExec.lean`; only the conclusion changes).
- **`rt_productionReadyL_r13`**: L34's gate on the run's transcript, the same way (any run verifier `V`);
  **`rt_productionReadyL_r13_exec`**: at `V := classifyRunV …`, so at `classifyProtocolUExec`.

**`StatementsD76Range.lean`** (generated by `l42_mk_range.py`; `hzk` on the range only)
- `classifyU_productionReadyL_joint_target_range` ← `…_ep_target_range` ← `…_runChain_range` ← `…_run_w16r2_range`,
  `…_run_r13_range` ← `…_run_r13_token_range` ← **`rt_productionReadyL_r13_range`**;
  **`classifyUExec_productionReadyL_run_r13_range`**, `…_run_w16r2_range`; **`rt_productionReadyL_r13_exec_range`**.
  Each is its source gate's statement and proof with four changes: the name, `hzk` asked only for `q, R ≤ 2^64`, the
  conclusion in the approved form, and the gate it calls (at the bottom, `productionReady_mono` is replaced by
  `productionReadyL_of_productionReady_range`).

## 4. The numbers

| Figure | Value | Label |
|---|---|---|
| Approved target at no hash query, one receipt | `εzkTarget 0 1 = 2^-120 < 1/2` | PROVED (`εzkTarget_zero_one_lt_half`) |
| The leaky toy's advantage at `(q, R) = (0, 1)` against any simulator | `≥ 1/2` | PROVED (`zeroKnowledgeL_reader_half`) |
| D76's receipt range inside L33's per-run cap | `2^64 ≤ 2^110`: 46 bits of room | PROVED (`hzk_range_of_refErr`, `pow64_le`) |
| `Statements.lean` code lines, old → new | 160 → 199: 39 added, 0 changed or removed | MEASURED |
| New declarations in `Statements.lean` | 5 | MEASURED |
| Lane files | `StatementsD76Leak` 33 lines, `Bridge` 261, `Leaky` 424, `Gate` 605, `Range` 1,110 | MEASURED |

## 5. What is left

This lane discharges no premise of the gates; the other lanes do (brief). By name:
- **The same-premise gates** (`StatementsD76Gate.lean`) keep every premise of L30's and L34's gates: `O`
  (`ClassifyOpen`'s fields; O11 unused), the Merkle work `tag`, `C`, `coreOf`, `Vx`, `nx`, `rx`, `nrx` (with `hVx`,
  `hnx`, `hrx`, `hnrx`), the covers `halive`, `hdin`, `hdblk`, `hdout`, the endpoint's test `T` with its facts (`hTenc`,
  `hTaA`, `hTaB`, `pr`, `hp1`, `hp2`, `hF`, `hw0`, `hβLR`, `hTe`, `hTQ`, `hβJ`), `Ux`, `Xx`, `hUc`, `hXc`, `mk`, `ops`,
  `hE`, `hops`, `hcan`, `hwin`, `hread`, `hBal`, `hdzero` (L34's), or `hlink` (L30's), and `hzk` for every `q` and `R`.
- **The `_range` gates** keep the same premises but `hzk` only on `q, R ≤ 2^64`. Taking O12 at L33's error
  (`classify_zk_cap110`), `hzk` holds (`hzk_range_of_refErr`); so the zero-knowledge part of the gate rests only on L33's
  premise `ZeroKnowledge (classifyModel S R) (classifyProtocol …) (refErr RunK.kinds)`, i.e. the premises of L33's
  `classify_zk_of_model` (the prover as programs `pOC`, `hrun`, `hbd`, `FM`, `hP`; the refusal guard `G`, `hvisG`,
  `hrefG`; the honest-verifier law `hHV`; the counts and rates).
- **LEFT, not this lane's:** a closed theorem without the premises above; the per-block shapes of GB-2; P3 (GB-13).

## 6. Findings

**L42-1 (Low; for Victor). D76 pins the leakage; two other fields a reviewer must still read.** The approved gate now
names `Λ`, but the public output part (`M.PubOut`, `M.publicPart`) is the model's and the meaning of "opens"
(`opensIn`, `opensOut`) is the protocol's. Both are named in the production theorem: `classifyModel S R` (public part:
the verdict; READ, CircuitTokenRun.lean) and `classifyProtocolUExec … e` (opening: `OpensU` at radius `e`, D77). So a
reviewer reads three definitions (`classifyLeak`, `classifyModel`, `OpensU`) instead of the instance's five fields.
A model whose `PubOut` were the input itself would still pass; `classifyModel`'s is not. No action needed unless you
want those pinned in the statement too.

**L42-2 (Medium; for the coordinator and the Lean lanes). Cite the `_range` gates.** Every existing gate asks
`hzk : ∀ q R', εzk q R' ≤ εzkTarget q R'` for every `q` and `R`. L33's error meets the target for `R ≤ 2^110` and
`R ≥ 2^120` only, so that premise cannot be met by what is proved. Under D76 it is asked only on `q, R ≤ 2^64`, where
L33's error meets it (PROVED, `hzk_range_of_refErr`). The final assembly should cite
`rt_productionReadyL_r13_exec_range` (or `classifyUExec_productionReadyL_run_r13_range`), not the same-premise forms.

**L42-3 (Low; for the coordinator). The `_range` gates are text copies.** `StatementsD76Range.lean` copies nine
existing gates' statements and proofs (by a script, with four checked substitutions each). If a later lane changes one
of those gates in place, the copies stay true theorems but may no longer match the changed gate: rerun
`l42_mk_range.py`. The same-premise gates of `StatementsD76Gate.lean` cannot drift silently: they call the original
gates with every argument by name, so a changed premise list breaks the build; rerun `l42_mk_gate.py` then.

**L42-4 (Info; for Victor). The amendment's protection depends on the `Λ` the production theorem names.**
`ProductionReadyL … Λ …` with `Λ := id` (the whole input) says nothing about privacy. D76 asks the production theorem
to name `Λ`; the classify gates name `classifyLeak`. A reviewer checks that one argument.

**L42-5 (Info). Of `classifyLeak`'s four parts, three are constants of the public data.** `T` and `d` are fields of the
registered shape, the block count is the length of the registered run. The only part that depends on the item is the
served bit, which D65(2) already declares. So for a fixed registered model the receipts may reveal exactly one bit
about the item beyond the verdict: whether it was served.

**L42-6 (Info; for the coordinator). The old forms stay and are still what lanes prove.** Lanes L39, L40 and L41 cite
`ProductionReady`; nothing they do breaks. Their results reach the approved gate through
`productionReadyL_of_productionReady` (with `classifyUExec_leaksAtMost`) or, better, by citing a `_range` gate.

**L42-7 (Info). The test fails at the smallest point of the range.** The leaky toy's distinguisher uses `q = 0` and
`R = 1`. So the range of D76 (2) does not weaken the test of D76 (1) at all.

**L42-8 (Medium; for the coordinator). Merging this lane rebuilds the whole library, and at lake's default parallelism
that breaks the guard's 24 GiB cap.** Every module imports `Statements.lean`. MEASURED: the first full check ran one
`lean` per core and the guard stopped it at a summed RSS of 27.35 GiB after 85 s (`check_attempt1.log.guard`); with
`LEAN_NUM_THREADS=10`, 28.01 GiB after 11 s (`check_attempt2.log.guard`). One `lean` process reached 4.60 GiB.
Lake has no job flag, but the runtime's `LEAN_NUM_THREADS` bounds its jobs (MEASURED: 3 `lean` processes at
`LEAN_NUM_THREADS=3`; that run finished the rebuild, about 160 modules after the roughly 100 the stopped attempts had
rebuilt, in 282 s at a summed peak of 16.31 GiB). For the merged-tree check, set it (3 to 5), or raise the cap for
that one job. (ARGUED: the summed RSS counts the Mathlib files that every process maps, once per process, so the true
memory is lower; the guard counts the sum.)

## 7. The checks

One guarded cpu job, `check_l42.sh` (label `lean-l42-check`, `LEAN_NUM_THREADS=3`), `check.log`, exit 0, 63 s, peak
3.91 GiB. All MEASURED:

| Check | Result |
|---|---|
| Lane modules, one at a time (`Statements`, the five `StatementsD76*`) | rc 0 each, 0 warnings |
| Full `lake build` | rc 0, 3,657 jobs, 0 warnings, 0 errors, no `sorry` |
| Axiom audit (`axioms_l42.lean`: every `def`, `structure`, `theorem` of `Statements.lean` and the five lane files) | 105 declarations (33 def, 8 structure, 64 theorem), 105 reports; 89 on exactly `propext`, `Classical.choice`, `Quot.sound`, 16 on none; `sorryAx` 0, `ofReduceBool` 0, other axioms 0 |
| Source scan (the ten forbidden words) of `Statements.lean` and the lane files | none |
| Root imports | the five lane files imported; the draft file gone |
| `l42_statements_check.py` against perf `c447ad00` | code lines 160 → 199; every old code line kept, unchanged, in order; one added block of 39 code lines = `SimulatorL`, `idealProbL`, `ZeroKnowledgeL`, `SemanticHidingL`, `ProductionReadyL` |
| Its negative control (`l42_statements_mutate.py`) | 2 of 2 single changes refused (an old bound doubled; a field inserted into `Protocol`) |
| Existing files changed | `Statements.lean` and 5 appended root import lines only; 0 other files under `formal/`; 0 under `ops/`, `src/` |
| Diff of `Statements.lean` (`statements_d76.diff`) | 92 lines added, 7 removed (the 7 are old doc-comment lines, rewritten) |
| Name clashes (`l42_nameclash.py`, 38 worktrees, 3,253 other Lean files) | 0 |
| L6Check / L5Check / L11Check / fixture L1 | 1,206 / 5,553 / 404 / 101,956 checks, 0 failed |

How the full rebuild was done. Amending `Statements.lean` rebuilds every module. Attempts 1 and 2 (default parallelism;
`LEAN_NUM_THREADS=10`) were stopped by the guard at a summed RSS of 27.35 and 28.01 GiB (`check_attempt1.log.guard`,
`check_attempt2.log.guard`; L42-8). Attempt 3 (`LEAN_NUM_THREADS=3`, 282 s, peak 16.31 GiB, `check_attempt3.log.guard`,
`check_attempts1to3.log`) rebuilt the whole library green with every verdict above green except one: the source scan
matched the word "admits" in a doc comment of `StatementsD76Leak.lean`. That comment was reworded (no code change) and
the final check above was run; it rebuilt the four modules that import that file.

Iterations: `iter1.log` to `iter4.log` (the five files built against a draft of the amended statements, so that an
iteration did not rebuild the library; the draft was then moved verbatim into `Statements.lean` and deleted).

## 8. Files

- `formal/ZK60Formal/Statements.lean` (amended as D76 directs).
- `formal/ZK60Formal/StatementsD76Leak.lean`, `StatementsD76Bridge.lean`, `StatementsD76Leaky.lean`,
  `StatementsD76Gate.lean` (generated), `StatementsD76Range.lean` (generated); root imports appended to
  `formal/ZK60Formal.lean`.
- `results/zk60_lean_l42_20261110/`: `check_l42.sh`, `check.log` (+ `.guard`), `check_attempts1to3.log`,
  `check_attempt{1,2,3}.log.guard`, `full.log`, `prebuild_*.log`, `axioms_l42.lean`, `axioms.log`, `axioms_flat.log`,
  `statements_d76.diff`, `l42_mut{1,2}_check.log`, `nameclash.log`, the regression logs, `l42_mk_gate.py`,
  `l42_mk_range.py`, `l42_statements_check.py`, `l42_statements_mutate.py`, `l42_nameclash.py`, `gen_axioms.py`,
  `run_guarded.py`, `iter.sh`, `l42_probe.lean`, the plans and iteration logs. (The check writes copies of
  `Statements.lean`, `l42_Statements_base.lean` and the two mutants, into the same directory; they are not committed.)
