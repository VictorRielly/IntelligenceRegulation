# D63 Lean lane L15: the token stages as whole theorems, their Fiat–Shamir form, and a real-receipt check (2026-11-07)

Lean lane L15 (Claude), on its own worktree branched from perf at `f3191282` (lanes L9, L11, L12 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. New library files under `formal/ZK60Formal/`, imported by the library root:
`StageOutCWhole.lean`, `StageOutWhole.lean`, `StageFS.lean`, `StageCheckDefs.lean`, `StageCheckValid.lean`; and the
checker `StageCheckOutC.lean` (not imported: it defines `main`). One TEST-ONLY Rust file,
`ops/zkp-mvp/gpu-metal/hashline/src/private_block/token_io/lean_l15_export_tests.rs`, declared by one
`#[cfg(test)] #[path = …] mod …;` line in the test-only `token_io/classify_capture_tests.rs` and listed in the test-only
`s25_tests.rs`'s `TEST_ONLY_FILES` (83 → 84). `Statements.lean`, every existing Lean file and every production source are
unchanged. Evidence: `results/zk60_lean_l15_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **TESTED**
(value for value against the Rust code), **CODE** (read off the sources, file:line), **ESTIMATE** (arithmetic on the
proved bounds, not proved in Lean).

## 1. In plain words, for Victor

**What this lane is.** A classifier proof (and a next-token proof) has three parts: stage IN-C (IN) turns the hidden
token ids into the first block's input; the blocks; stage OUT-C (OUT) turns the last block's output into the published
verdict (the next token). Statement 1's "only if" needs, for each part: *if the verifier accepts, the part's constraints
hold on the committed data, except with a small stated probability.* Lane L12 proved this for stage IN-C as one theorem
and for OUT-C and OUT step by step. This lane finishes the two output stages.

**What is now proved.**
- **Stage OUT-C (the verdict) as ONE theorem** (`outc_stage_sound`). Every one of the stage's eight checks is written
  exactly as the code writes it (the same tables, clauses, pads, batching and degrees), and the stage is composed: the
  LogUp challenges, then whatever helpers the prover commits, then the eight checks with any prover strategy. If the
  verifier accepts, the classifier's last stage is right — the final norm and the verdict on `B_out`'s verdict row are
  the integer model's (`OutCSat`) — except with probability at most about **2^-112.3** at the classifier's shape
  [ESTIMATE on the proved bound: numerator 54,094 over `|Fp2| ≈ 2^128`].
- **Stage OUT (the next token) as ONE theorem** (`out_stage_sound`). The same for the next-token run's last stage,
  with its eleven checks (the head, the keyed argmax's selector, the output endpoint). Its error at the 8B shape is
  about **2^-108.1** [ESTIMATE: numerator 971,826, dominated by the byte lookups of the seven keyed limbs over the whole
  `2^17` vocabulary cube].
- **The Fiat–Shamir form** (`stage_sumchecks_fs_sound`). The stages' checks run on the same transcript code as the
  blocks' (`run_stage_slot` is `run_slot` line for line), so lane L9's executable slot loop is the stage's. Lean now
  proves, on the code's own stage transcript, that a prover with `q` hash queries makes a stage accept with a false
  sumcheck claim with probability at most ONE check's bound times `q` (no factor for the number of checks): at most
  `2^-61` for any realistic `q` [PROVED via L8/L9's `block_bound_le`]. The stage's other challenges (the LogUp `α`,
  a host's `ν`, a pad's `ζ`) are given the same round-by-round form (`chalSub_rbr`), so they can enter L8's schedule
  (assembling the whole stage's schedule with its vector challenges is left, §6).
- **A real receipt agrees with the Lean code** (`StageCheckOutC`). An honest classifier receipt on the development
  rung, accepted by the production verifier, was exported slot by slot; Lean recomputed every OUT-C check from its own
  executable copy of the code's closures and its own public tables built from the profile:
  **81 checks, 0 failed** [TESTED]; eight deliberate corruptions are each caught exactly once.
- **The Shieldstral classifier's stage parameters** pass the statement's validity conditions where the data is in
  the repository (`shield_in_valid`, `shield_outc_valid`): the vocabulary, the three category templates, the pad, the
  margin window. The weights are not in the repository (D62), so the embedding's and margin vector's values remain
  hypotheses (their int16 class is the loader's type).

**What this does not do** (§6). The openings (lane L10), `M`'s test and the mask cancellation are hypotheses, as for
every slot lemma; the vector challenges' round-by-round states (the eq point `τ`, the batching vectors) are not yet in
L8's schedule; the whole run's one Fiat–Shamir schedule (stages and blocks together) is not assembled.

**One finding is worth knowing (L15-1).** Lane L12's error estimate for stage IN-C assumed a vocabulary of `2^15`;
the registered Shieldstral policies use tekken's `131,072 = 2^17`. IN-C's error is therefore about `2^-109.0`, not
`2^-110.9`. No theorem changes; the whole-run figure already charges the larger term (L12-2).

## 2. What is proved

All PROVED (`results/zk60_lean_l15_20261107/`; the counts are in §7). Every statement is for a general finite field
`K` with an embedding `φ : GF →+* K` (the code's `Fp2`); no literal prime is evaluated in a soundness proof.

### 2.1 Stage OUT-C as one theorem (`StageOutCWhole.lean`)

The code: hashline `src/private_block/token_io/stage_out_c.rs`, `verify` :658-749, `define` :283-429; the slot runner
`run_stage_slot`, `token_io.rs`:997-1135.

| Theorem / definition | Meaning |
|---|---|
| `TzcClause`, `TzcCTabs`, `tzcL3`, `tzcCW`, `tzcCPz`, `tzcCHost` | OUTC-02 TZC as the code writes it (:312-335): `dsq − d²`, `d − l3(dl)`, `2d − l3(a1) − l3(a2)`, the pad `(1 − u0)·(d + ζ·dsq)`, the host term `u0·(dsq + l3(a1) − ceps)` |
| `ioR`, `ssF` | OUTC-00 IO-in's one clause `x − B_out` (no batching: the code draws only `τ`) and OUTC-01 SS's `supp·x·x` |
| `dzcDen`, `dzcLb`, `dzcC`, `dzcW`, `dzcPz`, `dLookPl`, `dLookCst`, `dLookCoef` | OUTC-05 DZC (:371-405): the gated `g·c0`, `g·c1`, `g·c2`, the six pair helpers over `lookups_do` (`α − ((cst + g) + plane·coef)`), the pad `(1 − g)·Σ ζ^j·plane_j` |
| `tzcCW_deg`, `pad2_deg2`, `tzcCHost_deg`, `ioR_deg`, `ssF_deg`, `dzcW_deg`, `dzcPz_deg`, `tabW_deg`, `tabPz_deg` | every closure's individual degree, at most the code's declared round degree minus the eq factor (TZC 2, SS 4, DZC 4, TAB 2) |
| `accHostPad`, **`priv_hostpad_sound`** | a private slot hosted by a host WITH a pad (SS by TZC): both accept while `Σ Hs = Σ f`, a clause or a pad fails `≤ np·dp/|K| + ((m − 1) + (2 + nh + nh(dh + 1)))/|K|` (L12's `margin_sound` is the pad-free PD / LZC pair) |
| `OutCData`, `OutCLayout`, `OutCHelpers`, `OutCSum` | the committed planes (`To`, `Lo`, the twelve `Do` planes, the histogram, `B_out`'s row), the public tables with the layout facts the code's tables satisfy, the `H` helpers, the value-0 LogUp sum |
| `OutCFacts`, `dLookB`, `outcP1`, `outcP2`, `dLook_byte` | the facts at the logical positions; DZC's twelve looked values and their bytes |
| **`outC_of_facts`** | every looked value a byte and `OutCFacts` give `OutCSat` on `B_out`'s verdict row |
| `tzcL3_cube`, `dzcLb_cube`, `dzcC_cube`, `dzcDen_cube`, `dzcD_eq`, `ssF_sum`, `tzcCHost_sum` | the closures on the cube are the base field's values through `φ` |
| **`outcFacts_of_cube`**, **`outcCube`** | the slots' relations on their cubes give `OutCFacts` (no sum claim needed), and with the pads and the two sum claims the byte LogUp's relations `ByteLogUp` at the logical positions |
| `OutCChal2`, `OutCProvers`, `accZc`, `OutCAcc`, `outcSlotsErr` | the eight slots' challenges in the code's order, the provers (each a function of everything drawn before it), the verifier's acceptance, the slots' error |
| **`outc_stage_sound`** | over `(γ, α)` and the eight slots' challenges, for ANY helpers, scalars and provers: accept and `¬ OutCSat` `≤ (2^nl + 2·6·2^ndo + 511)/|K| + outcSlotsErr` |
| `outc_numerator_shape` | at the classifier's R1 shape the numerator is `54,094 < 2^16` |

### 2.2 Stage OUT as one theorem (`StageOutWhole.lean`)

The code: `stage_out.rs`, `verify` :771-, `define` :336-542.

| Theorem / definition | Meaning |
|---|---|
| `vzcDelta`, `vzcDen`, `vzcW`, `vzcPz`, `vzcHost` | OUT-06 VZC (:456-489): `e(1 − e)`, the `l/2 + l%2` limb helpers (pairs; the last a single for odd `l`), the pad `(1 − s)·zeta_fold(e, λ…)`, the host term `eq(r_j, x)·s·(M + 2^{−v}·(ι − tok − δ))` |
| `rselF`, `iooR` | OUT-07 RSEL (no eq factor, claim 0) and OUT-10 IO-out's `end − u0·tok` |
| `vzcW_deg`, `vzcPz_deg`, `vzcHost_deg`, `rselF_deg`, `iooR_deg` | degrees (VZC 4 + host 5, RSEL 4, IO-out 2) |
| **`head_vzc_sound`** | HEAD hosted by VZC, with ANY middle coordinates (DZC's) and `r_j`'s Schwartz–Zippel step: keyed values ≠ head values, or a VZC clause or pad failing, and both accepting `≤ nv/|K| + 2nd/|K| + ((m − 1) + (2 + nv + 5nv))/|K|` |
| **`rsel_sound`** | RSEL accepts while an identity fails `≤ 1/|K| + 4n/|K|` (`rsel_batch_sound` and the sumcheck) |
| `OutData`, `OutLayout`, `toCPub`, `toCLay`, `OutData.toC` | stage OUT's planes and layout; the shared parts as an OUT-C instance with no margin (`limbs = 0`), so OUT-C's lemmas apply unchanged |
| `deltaB`, `lstarB`, `lheadB`, `OutFacts`, `outA`, `outP1`, `outP2`, `OutHelpers`, `OutSum`, `outHelpers` | the keyed and head values, the facts, the byte lookups (Lo singles, Do pairs, Vo pairs and the odd single) and helpers |
| `lam_byte`, `lheadB_pos`, `lheadB_off`, **`out_of_facts`** | the facts and bytes give `OutSat` on `B_out`'s last row for the token word, and the output endpoint holds it at word 0 (`out_endpoint_word`) |
| `head_sum_eq`, `vzc_host_sum`, `vzcDelta_cube`, `rselRes_map`, `rsel_sum`, `sum_hv` | HEAD's sum is `l~(r_j)`, VZC's hosted sum is `l*~(r_j)`, RSEL's cube sum is the batched residues, the helpers' sum splits |
| **`outCube`** | the slots' relations give `ByteLogUp` and `OutFacts` (OUT-C's `outcFacts_of_cube` for the shared facts) |
| `OutChal2`, `OutProvers`, `OutAcc`, `outSlotsErr` | the eleven slots' challenges, provers, acceptance, error |
| **`out_stage_sound`** | accept and (`¬ OutSat` or the endpoint identity failing) `≤ (|ι| + 2|π| + 511)/|K| + outSlotsErr` |
| `out_numerator_8B` | at the 8B shape the numerator is `971,826 < 2^20` |

### 2.3 The Fiat–Shamir form (`StageFS.lean`)

| Theorem / definition | Meaning |
|---|---|
| `stageRootOps`, `stageRootOps_length`, `stageOps`, `slotPre_stageOps` | the stage's head (`A`, `M`, the `m` stage challenges, `H`) and its run of slots as L8 reads it |
| `stageSlots`, `runOps_stageRootOps`, **`stageSlots_eq`** | the stage verifier up to the end of its slot loop (the head, then L9's `slotsLoop`), as `runOps` of the head |
| `tRootS`, `SeenS`, `tSeenS`, `claimOfS`, `seenOfS`, `tRootS_trace`, `claimOfS_seenOfS`, **`tSeenS_trace`** | each slot's claim is a function of the code's trace before its rounds (L7-2 met on the stage) |
| `stageRootOps_len`, `stageSlot`, `stageSched`, `stageLen`, `slotsLen_stageSched`, `SlotsShape`, `StageWin`, **`stageWin_slotsWin`** | the stage's slots as L8's `Slot`s (each a `CSub` through `slotSubs`, `RbrWide` by `slotSub_rbr`); a win against the stage is L8's `SlotsWin` |
| **`stage_sumchecks_fs_sound`** | a `q`-query prover: accept, every terminal check, some false claimed sum `≤ T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + stageLen + 1` |
| `outcSlotsR1`, `outcDrawsR1`, `outc_stage_len` | OUT-C's slot shapes and draws at the R1 shape; `stageLen = hdrLen + 298` |
| `chalSt`, `chal_rbrSound`, `chalSub`, **`chalSub_rbr`** | a single challenge (LogUp `α`, `ν`, `ζ`, one batching coefficient) as a `CSub`: `RbrWide` with `B·(⌊2^128/p⌋+1)²/|Dig|` when at most `B` challenges are bad |

### 2.4 The executable stage arithmetic and the parameter checks (`StageCheckDefs.lean`, `StageCheckValid.lean`)

| Theorem / definition | Meaning |
|---|---|
| `kI`, `vg`, `mb`, `oneMinusProd`, `ioPoly` … `zsPoly`, `l3W`, `denW`, `dzcLks`, `lbW`, `zfoldW` | stage OUT-C's eight closures on the code's words, line for line (`define`, `helper_sum`, `zeta_fold`) |
| `supp`, `liveTab`, `gTab`, `wTab`, `tvTab` | the slots' public tables as functions of the profile |
| `TabR`, `stageVals`, `claimedOf`, `scArith` | the verify arm's terminal values, the claimed sum, the sumcheck's arithmetic on the recorded challenges |
| `kapOf`, `isTOf`, `getD_lt`, `kapOf_lt` | the template's public ids at the positions |
| `prefix_lt_sexual`, `prefix_lt_violence`, `prefix_lt_hate`, `suffix_lt`, **`shield_in_valid`** | the three registered category policies: stage IN-C's public data is `InPublic.Valid` for every content length and every int16 embedding |
| `shield_policy_door` | the classifier door's policy facts (BOS, yes / no, template, pad, control class, `c`) |
| `shield_limbs`, **`shield_outc_valid`** | five margin limbs at `d = 3,072`; stage OUT-C's public data is `OutCPublic.Valid` for every margin vector and final norm in the door's classes |

## 3. The stage errors at the shapes [ESTIMATE on the proved bounds]

Each slot's term below is the proved per-slot bound; with the code's extension round (one more round of the slot's
declared degree, `sumcheck_sound_extended`) add the degree. `|Fp2| = p² ≈ 2^128`. The theorem is the sum.

**Stage OUT-C at the classifier's R1 shape** (`stage_log_n = 12`: every stage domain `2^12`; `d_pad = 2^12`; `To = 2`;
CODE stage_out_c.rs:71-102, classify.rs:716-724). `outc_stage_sound`'s bound, `outc_numerator_shape`:

| Term | Theorem | Numerator |
|---|---|---|
| the byte LogUp, `2^12` singles (LZC) and `6·2^12` pairs (DZC), the 256-row table | `byte_logup_sound` | `4,096 + 2·24,576 + 511 = 53,759` |
| OUTC-00 IO-in (`n = 12`, one clause, prover degree 2) | `zerocheck_sound` | `12 + 12·2 = 36` |
| OUTC-01 SS (`n = 12`, degree 4) and OUTC-02 TZC (`n = 1`, degree 3, two pad planes) | `priv_hostpad_sound` | `48 + (1 + 2 + 1 + 3) = 55` |
| OUTC-03 PD (`n = 12`, degree 2) and OUTC-04 LZC (`n = 12`, degree 4) | `margin_sound` | `24 + (2 + 12 + 48) = 86` |
| OUTC-05 DZC (`n = 12`, degree 5, twelve pad planes) | `zc_pad_sound` | `11 + 1 + 12 + 60 = 84` |
| OUTC-06 TAB (`n = 12`, degree 3, two pad planes) | `zc_pad_sound` | `1 + 1 + 12 + 36 = 50` |
| OUTC-07 ZS (`n = 12`, degree 2) | `zs_sound` | `24` |
| total | `outc_stage_sound` | **`54,094 ≈ 2^15.72`: about `2^-112.3`** (`54,119` with the extension rounds) |

**Stage OUT at the 8B shape** (`V_pad = 2^17`, every other stage domain `2^12`, `l = 7` keyed limbs, the output
endpoint `2^8` words; CODE stage_out.rs:75-123). `out_stage_sound`'s bound, `out_numerator_8B`:

| Term | Theorem | Numerator |
|---|---|---|
| the byte LogUp: singles `2^12 + 1·2^17`, pairs `6·2^12 + 3·2^17` | `byte_logup_sound` | `135,168 + 2·417,792 + 511 = 971,263` |
| IO-in; SS + TZC; LZC (`zc_batched_sound`, `n = 12`, degree 4) | | `36 + 55 + 61` |
| HEAD (`n = 12`, degree 2) + VZC (`n = 17`, degree 5, eight pad planes) with `r_j`'s step | `head_vzc_sound` | `17 + 24 + (7 + 2 + 17 + 85) = 152` |
| DZC; RSEL (`n = 17`, degree 4); TAB; ZS; IO-out (`n = 8`, degree 3) | | `84 + 69 + 50 + 24 + 32` |
| total | `out_stage_sound` | **`971,826 ≈ 2^19.89`: about `2^-108.1`** (`971,863` with the extension rounds) |

**Stage IN-C, corrected (L15-1).** L12's `inc_stage_sound` at the registered policies' `V = 2^17` (tekken), `T = 512`,
`d_pad = 2^12`: the lookup `512 + (4·2^17 − 1) + 512·12 = 530,943`, INC-00 `40`, INC-01 `66`, INC-02 (`n = voc_log = 17`)
`1 + 1 + 17 + 18·4 = 91`, INC-03 `26`: `531,166 ≈ 2^19.02`, about **`2^-109.0`** (L12 reported `2^-110.9` at `V = 2^15`).

**Under Fiat–Shamir** (`stage_sumchecks_fs_sound`): the stage's sumcheck slots contribute
`T·5/p²·(1 + p/2^128)² + collBound T + collBound (T + 1)` (OUT-C's largest degree is 5), `T = q + hdrLen + 298 + 1`,
at most `2^-61` for `T ≤ 2^64 + 2^20` (L9's `block_bound_le`, degrees `≤ 7`). The per-query rate is one slot's.

## 4. Findings

No mismatch between the code and the approved statements was found. `Statements.lean` is unchanged.

**L15-1 (Low, an estimate only): stage IN-C's error was estimated at the wrong vocabulary.** L12's §3 used `V = 2^15`
("Mistral's vocabulary"); the three registered Shieldstral category policies use tekken's `v: 131_072`
(classify.rs:205-221), and the IN-C vocabulary domain is `voc_log = max(17, 12) = 17`. Recomputed on L12's proved bound:
about `2^-109.0` instead of `2^-110.9` (§3). The theorem is unchanged and still far inside the whole-run figure, whose
stage-IN term already charges `V·(2 + lg)` (L12-2). The coordinator may want to update L12's table and MVP_STATUS's
quoted IN-C figure.

**L15-2 (Info): OUTC-00 IO-in has no batching coefficient.** The code draws only `τ` (stage_out_c.rs:297) and the slot
has one clause `x − B_out`, so `zerocheck_sound` applies directly (`12 + 12·2`); L12's table charged an extra `1` for a
batch. Conservative, no change.

**L15-3 (Info): two pad clauses are not load-bearing for the verdict.** TZC's pad `(1 − u0)·(d + ζ·dsq)` (zeroing `To`'s
entry 1) and LZC's pad `(1 − live)·limb` (zeroing the limb plane off the isqrt and margin limbs) are never used by
`outC_of_facts`: `OutCSat` reads `To`'s entry 0, the isqrt limbs and the margin limbs only, and `G` is zero off the
margin limbs. They make the committed planes canonical (zero padding), which the hiding and uniqueness arguments may
use; soundness does not need them. Same for stage OUT's TZC pad.

**L15-4 (Info): the byte LogUp counts the LIFTED domains.** DZC's six helpers and VZC's `l/2 + l%2` helpers are not
gated by the live selector: every entry of `Do` and `Vo` is looked up (the pads look up `0` and `127`, bytes). So the
LogUp's `N` is `12·|Do|` and `l·|Vo|` (the lifted extents), as `logup_size` counts (stage_out_c.rs:106-109,
stage_out.rs:126-129). For stage OUT at 8B this makes the byte term (`≈ 2^19.9`) the stage's dominant error.

**L15-5 (Info, engineering): the run capture's transcript states carry no squeeze counter.** `run_capture::state`
writes the 32-byte state and the next challenge (run_capture.rs:2891-2893), not the counter, so Lean cannot rebuild the
transcript to replay a stage's draws (L9/L11 replayed blocks from their own exports). The corpus check therefore
takes the draws, `c` and `ρ` as recorded and checks everything computed from them; the recorder's own replay
(`at`, `same_transcript`) checks them against the verifier in Rust. Writing the counter in `state` (test-only code)
would let a Lean check replay the stage's transcript.

**L15-6 (Info): `define`'s interleaved refusals.** As L9 noted for blocks, stage `define`s refuse a zero batching
challenge (`nonzero(...)?`) in the middle of their draws (stage OUT-C: 23 coordinates, stage_out_c.rs:314-409); the
soundness bounds count every challenge, so the refusals cost only completeness (at most `23/|K|` for OUT-C).

## 5. Optimization candidates (for a later profile; nothing changed)

- **O1: four OUT-C slots declare one round degree more than their polynomial has.** SS: `supp·x·x` is degree 3 per
  variable, declared 4; LZC: `eq·(μ₀·(h·d − 1) + μ₁·(1 − s)·limb) + ν·(G·limb + u0·kc)` is 3, declared 4; DZC:
  `D` is read at a fixed point (a constant), so `kd·y` is linear and the polynomial is `eq·(degree 3)` = 4, declared 5;
  ZS: `1·u` is degree 1, declared 2. Each lowered degree saves one `Fp2` per round (13 rounds: 208 bytes per slot) and
  13 in the numerator; stage OUT's SS, DZC and ZS likewise. The CFS mask's degree follows the declared one, so the
  hiding lanes would have to confirm the mask stays sound at the lower degree. Recorded, not proposed (as L11's O1).
- **O2 (L12's O2, confirmed on the code):** the byte LogUp's single family tag makes `γ` redundant in OUT and OUT-C.
- **O3: stage OUT's byte term.** At 8B the VZC limbs' lookups over the whole `2^17` `Vo` cube (`7·2^17`) dominate the
  stage's error; gating VZC's helpers by `supp(V)` would not change the count (the cube is the lifted domain), but a
  smaller `Vo` lift or fewer limbs (a narrower keyed window) would. No change proposed: the stage's `2^-108` is well
  inside its share.

## 6. What is left

1. **The openings, `M` and the mask cancellation** remain hypotheses of every slot theorem (lane L10): each terminal
   value is the committed table's extension at the slot's point, and the masked scalars cancel by `M`'s functionals.
2. **The vector challenges in L8's schedule.** `chalSub_rbr` gives a single challenge's round-by-round form; the eq
   point `τ`, the batching vectors `μ`, `r_j` and RSEL's `c` need per-coordinate states (the partially evaluated
   extension, or the residual linear form, being nonzero: error `1/|K|` per coordinate). With those, the whole stage
   (not only its sumchecks) is one schedule of `CSub`s, composed with the blocks' on the run's transcript by
   `fs_code_chain_sound_sched`.
3. **The whole run's Fiat–Shamir schedule**: the stages' and the blocks' slots on the run's one transcript (L9's
   `blockSched` and this lane's `stageSched` concatenated), with the boundary openings between them.
4. **The executable closures proved equal to the model's** (L11's `toK_irEvalW` pattern): today
   `StageCheckDefs.lean`'s closures are checked against the Rust verifier value for value, and are the model's by
   reading (the same tables, order and constants); a `toK` bridge theorem per closure is not written.
5. **Stage IN-C's corpus and stage OUT's**: the corpus covers stage OUT-C of a classifier receipt; IN-C (the same
   capture) and stage OUT (a token-run capture) are the same pattern.
6. **The layout facts** (`OutCLayout`, `OutLayout`: where the indicators are 1, the rows, `W'`'s values) are hypotheses;
   the corpus check confirms the public tables against the code at the rung, and a registered profile's facts are
   finite checks not yet written as theorems.
7. **`R.Valid` beyond the stages' public data**: every block's `BlockPublic.Valid` and the registered shape's
   `BlockShape.Valid` (the weights are not in the repository, D62; the shape constants are not restated here).

## 7. Checks

All runs through the zk60 resource guard (class cpu, one heavy job at a time), logs in
`results/zk60_lean_l15_20261107/`.

**The corpus** (`export_corpus.sh`, `rust.log`): the test-only export
`lean_l15_export_the_classifier_stage_out_c_slots` proves an honest classifier run on the development rung (T32 / d384 /
f512, 12 heads of 32 over 4 KV heads, `L = 1`, trained norm calibration), verifies it with the production
`verify_classify_run` with the run capture's recorder attached, and writes the profile (`d = 384`, `d_pad = 512`,
every stage domain `2^12`, five margin limbs, verdict `1`, `c = −174,281`), the margin vector, stage OUT-C's LogUp
challenges and its eight slot records: `corpus.txt`, 50,641 bytes, 1 passed, 0 failed.

**The agreement check** (`StageCheckOutC`, on `corpus.txt`): **81 checks, 0 failed** [TESTED]:

| Check | Count | What |
|---|---|---|
| `logup`, `slot-count` | 1 + 1 | two LogUp challenges; eight slots in order |
| `schedule` | 8 | each slot's kind, `main`, extension rounds and declared degree are `layout`'s, from the profile's domain logs |
| `draws` | 8 | each `define` draws as many challenges as the code (`τ`, `μ`, `ν`, `ζ`) |
| `tables` | 8 | the table kinds in the code's push order; one terminal per private table |
| `eq-point` | 5 | every eq table is at the slot's own `τ` from coordinate 0 |
| `public-len` | 18 | every public table has the length of Lean's table built from the profile, and their count |
| `hosted` | 8 | the hosting (TZC hosts SS with `ν = draws[5]`, LZC hosts PD with `ν = draws[llo + 2]`) |
| `claimed` | 8 | the claimed sum is the scalar plus the hosted scalars times their coefficients |
| `sumcheck` | 8 | the rounds' arithmetic on the recorded challenges from Lean's claimed sum ends at the recorded final value |
| `verify-arm` | 8 | Lean's terminal values (`sel·eq(τ, ρ)`; `sel·mle(T)(ρ)` of LEAN's public tables `supp`, `live`, `G`, `w_Δ`, `tv`, the ones; the masked terminals) through Lean's closure equal the Rust verifier's `poly(vals)`, and `(fin − poly)·c⁻¹` is the recorded mask value |

**The negative control** (`mutate_corpus.py`, eight single changes): **81 checks, 8 failed**, each change caught
exactly once: slot 0's terminal (`verify-arm: slot 0`), slot 0's claimed sum (`claimed: slot 0`), TZC recorded as
standalone (`schedule: slot 2`), the margin vector's first word (`verify-arm: slot 3`: Lean's `w_Δ` table), LZC's eq
point (`eq-point: slot 4`), the verdict (`verify-arm: slot 4`: Lean's `G` and `b + c`), DZC's first round value
(`sumcheck: slot 5`), TAB's batching draw (`verify-arm: slot 6`).

**The gate** (`check_l15.sh`, `check.log`): one guarded job (`iterate.sh` → `check_l15.sh`, `iter6.log`), all as required:

| Gate | Result |
|---|---|
| full `lake build` of the library | green, 3,474 jobs, 0 warnings, 0 errors, no `sorry` |
| axiom audit (`gen_axioms.py` → `axioms_l15.lean`: every `theorem` of the five L15 library files) | 83 theorems: 70 on `[propext, Classical.choice, Quot.sound]`, 6 on `[propext, Quot.sound]`, 3 on `[propext]`, 4 on none; no `sorryAx`, no `Lean.ofReduceBool`, no other axiom |
| source scan of the six L15 files (`sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`) | none |
| the root imports the five library files; the checker (`main`) is not imported | yes |
| regression L6Check / L5Check / fixture L1 / L11Check on their committed corpora | 1,206 / 5,553 / 101,956 / 404 checks, 0 failed |
| StageCheckOutC on `corpus.txt` | 81 checks, 0 failed |
| negative control | 81 checks, 8 failed (each mutation once) |
| hashline's R19b file census (`TEST_ONLY_FILES` 83 → 84) | 1 passed |

Theorems per file: `StageOutCWhole.lean` 35, `StageOutWhole.lean` 24, `StageFS.lean` 14, `StageCheckValid.lean` 10
(`StageCheckDefs.lean` is definitions only).
