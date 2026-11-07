# D63 step L11: the W16R2 slot arithmetization and the layout map (2026-11-07)

Lean lane L11 (Claude), on its own worktree branched from perf (`4ae2627b`; perf's `18d2e74c` differs from it only in
`apps/proven-media`). Lean 4.34.1, Mathlib v4.34.1, no new dependency. New library files under `formal/ZK60Formal/`:
`SlotW16Ir.lean`, `SlotW16R2.lean`, `SlotW16Sound.lean`, `LayoutW16.lean`, `LayoutW16Handoff.lean` (imported by the
library root), and the checker `L11Check.lean` (not imported: it defines `main`). One TEST-ONLY Rust file,
`ops/zkp-mvp/gpu-metal/hashline/src/private_block/lean_l11_export_tests.rs`, declared by four lines in the test-only
`w16r2_tests.rs` and listed in the test-only `s25_tests.rs`'s `TEST_ONLY_FILES` (the R19b file census). No production
source changed. `Statements.lean` and every existing Lean file are unchanged. Evidence:
`results/zk60_lean_l11_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**TESTED** (value for value against the Rust code), **CODE** (read off the sources, file:line), **ESTIMATE**.

## 1. In plain words, for Victor

**What this step is.** Statement 1's "only if" needs: an accepted receipt makes the block's constraint system hold on
the data behind its commitments. The constraint system was proved to be the integer model (`block_circuitIff`, L2). What
was missing is the bridge from what the verifier actually checks — 23 sumcheck "slots" per block, each with its own
final identity, on a padded and permuted commitment layout — to that constraint system at the model's logical
positions. This lane builds that bridge for the W16R2 blocks the code runs today (the Shieldstral classifier's and the
8B stack's).

**What now exists.**
1. **The slot list, executable, and checked against a real W16R2 receipt.** The verifier's per-slot arithmetic — the
   claimed sum with its hosted terms, the sumcheck, the terminal values, the slot polynomial, the mask value `g` — is
   written in executable Lean exactly as `run_slot` runs it, and PROVED equal to its mathematical model. A real W16R2
   block proof (the development rung, accepted by the production verifier) was exported slot by slot, and Lean
   recomputes it: **404 checks, 0 failed** [TESTED]. Lean also checks that every host slot's `eq` tables carry the
   right claim points (the hand-off between slots) and that every challenge in a slot polynomial is the transcript's.
2. **Per-slot soundness.** PROVED, generically, with the existing Schwartz–Zippel, zero-check and batching lemmas: if a
   host slot's relation fails on the committed data (a clause, a lookup helper, a padded entry, a matmul hand-off), its
   claim and its two hosted slots' claims survive the verifier's random challenges with probability at most
   `(n₁ + n₂ + m + n + 2)/|F|` (`n` the cube's variables, `m` the pad planes). At Goldilocks² that is below `2^-120`
   per slot [ESTIMATE]. Its instantiation at each W16R2 slot's own clause list is left (§6).
3. **The numerator premise F44 is discharged.** PROVED: at the W16R2 8B shape (and Shieldstral's) the slots' error
   numerators sum to `1,479` (`1,539`) plus the pad terms, far below the `2^16` that the zone budget assumed.
4. **The layout map.** PROVED (`blockSat_of_slots`): the slots' relations on the committed cube plus LogUp's
   conclusion give CircuitBlock's constraint system at the logical positions. It handles the padding (padded weights
   and planes are zero), the head-slot order (a query head's slot is its key-value group's bits on top), the RoPE
   flip, and the support gates. With `block_circuitIff` this says: the slots' relations ⇒ the block's output IS the
   integer block's output.
5. **The hand-off premises** of the run's composition, for the slots, each a short lemma (`hstart_block`, `hhand_*`,
   `hfinal_terminal`).

**What this does not do yet** (§6):
- **the per-slot polynomials and public tables as Lean functions of the shape and the challenges.** Today they come
  from the corpus (from the Rust builders), and are checked there; the link from the verify arm's polynomial to the
  named relations the layout theorem uses (`W16Rels`) is read off the code, not proved;
- the per-slot bounds instantiated at each slot's clause list and composed along the block's transcript (L8's
  schedule, with L9's decoder), the extraction of the committed planes from the hash log (`SoundExtract.lean`), the
  openings and `M` (L10);
- W16R3: each W16R2 specific is one named definition (`sched`, `draws`, `hostsOf`, the `Ax` of `Dom::F`), so B2 / B3 are
  instance swaps.

**Findings and savings** (§4, §5): no mismatch with the approved statements. One latent hazard (L11-1: the SiLU
product's remainder lookup width is hard-coded, not derived from the shift it guards). Savings: a LogUp host declares
one degree more than its polynomial needs where its domain pads (FZC at 8B; known, ruling I-7); the zone's numerator
budget has 40× headroom.

## 2. What is proved

All PROVED (`results/zk60_lean_l11_20261107/`): the full `lake -d formal build` is green (3,459 jobs, 0 warnings,
0 errors); `#print axioms` on all 82 theorems of the five library files shows at most `propext`,
`Classical.choice`, `Quot.sound` (`axioms.log`); the source scan finds none of `sorry`, `axiom`, `native_decide`,
`admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`.

### 2.1 `SlotW16Ir.lean`: the slot's terminal identity and verify arm (generic; obligation 0 for L9)

The reading is L5's: `toK U` maps a code word into any field `K ⊇ GF` with `U² = 7`.

| Theorem / definition | Statement |
|---|---|
| `Factor`, `Body`, `Term`, `Ir`, `Ir.map` | `slot_ir.rs`'s grammar as data: tables, nodes (`Affine {konst, terms}`, `Sum {subterms}`), top-level terms `coef·Π wrapper·Π inner`, with the coefficients' VALUES |
| `irEval` / `irEvalW` | the slot polynomial's value in a commutative ring (the model) / on the code's words exactly as `SlotIr::eval` folds |
| **`toK_irEvalW`** | the word evaluation IS the model's evaluation with every coefficient and value read in `K`; only the coefficients need be canonical (`Ir.Canon`, decided by `Ir.canonB`) |
| `TabV`, `selW`, `valsGo` | the verifier's tables (`Tab::Eq {point, start}`, `Tab::Pub`, `Tab::Priv`) and the terminal values (argument.rs:1444-1457): `sel·eq_point(point, ρ[start..])`, `sel·eval_mle_ext(pub, ρ)`, the masked terminals |
| **`toK_valsGo`** | each terminal value is its model `tabValK`: `sel·eqPoly`, `sel·mleAt(pub)(ρ)` (L6's `toK_eqPointBody`, `toK_mleSumExt`), or the terminal |
| `claimedW`, **`toK_claimedW`** | the claimed sum `scalar + Σ_hosted coef·scalar_hs` (argument.rs:1440) |
| `gValW`, `toK_gValW`, **`terminal_iff`** | `g = (fin − poly)·c⁻¹`, i.e. `fin = poly + c·g` in `K` (`c ≠ 0`) |
| `SlotDefW`, `SlotProofW`, `SlotOutW`, `SlotErr`, **`slotVerifyW`** | `run_slot`'s verify arm (argument.rs:1171-1178, 1434-1468) on the code's transcript: `pb-slot`, `c` (refused if zero), the terminal count, `pb-scalar`, L6's `scVerify` over `n + ext` rounds, the values, `poly`, `g`, the degenerate-extension refusal, `pb-term` |
| **`slotVerifyW_ok`** | an accepting arm, unfolded: `c` is the transcript's challenge after `pb-slot` and nonzero; `scVerify` accepts the claimed sum on the transcript after `pb-scalar`; the values are `valsGo` at `ρ = rhoFull[..n]`; `poly = irEvalW`; `g = gValW`; the transcript ends with `pb-term` |
| **`slotVerifyW_terminal`** | an accepting arm's final claim is `poly(vals) + c·g` in `K` |

### 2.2 `SlotW16R2.lean`: the W16R2 slot list (the named definitions W16R3 replaces)

| Definition / theorem | Statement (CODE: `layout.rs`, `shape.rs`, `argument.rs`, `argument_accuracy.rs`, `pad.rs`) |
|---|---|
| `scSS` … `scIOOUT`, `kindOf`, `hostsOf` | the 23 slots in transcript order, `SLOT_KINDS`, `HOSTS` |
| `ShapeW`, `sched` | the shape facts (axis logs, domain logs after the P-3 lift, pads, helpers, zero-rule planes) and **`Shape::slots`**: `(main, ext, degree)` per slot |
| `draws`, `drawLen`, `splitDraws`, `segOf` | each slot's `define` draws in order: `τ`, `μ`, `ν`, `ζ`, `λ`, `μ_pad`, the claim points' coordinates |
| `claimPoint`, `eqPoints`, `hostedCoefs` | **the hand-off**: the claim point each private slot publishes, the `eq` tables each slot must hold (a host's `τ` then its hosted slots' points; `SC_SCORE` / `SC_PV`'s group `eq(r_g)`), the hosted coefficients `ν_k` (`ν_0·per_row` for `SC_RS`) |
| `segFix`, `zetaLen`, `slotNum`, `blockNum`, **`blockNum_eq`** | the slots' small numerators in L3's accounting (sumcheck `(n + ext)·d`, each point's length, one per batch, `pp` per pad term), linear in `pp` |
| `sh8B`, `shShield`, `blockFix_8B` (1,479), `zetaTotal_8B` (3), `blockFix_shield` (1,539), `zetaTotal_shield` (4) | the W16R2 8B T128 and Shieldstral T128 shapes, evaluated by `decide` |
| **`w16r2_8B_numerator_le`**, **`w16r2_shield_numerator_le`** | **F44 discharged**: for every pad charge `pp ≤ 64`, the 23 slots' numerators sum to at most `2^16` (`1,479 + 3·pp`, `1,539 + 4·pp`) |

### 2.3 `SlotW16Sound.lean`: per-slot soundness (interactive, challenges uniform and independent)

| Theorem | Statement |
|---|---|
| `Dens`, `dens_prob`, `dens_mono`, `dens_le`, `dens_empty`, `dens_prod`, `dens_union`, `dens_fst`, `dens_snd` | the counting calculus: `|E|·|F| ≤ k·|Ω|` gives `Pr[E] ≤ k/|F|`; conditioning on the first coordinates adds densities |
| `dens_affine`, `dens_line`, `dens_mle_zero`, `dens_mleEq`, `dens_root` | a nonzero linear form: `1`; a line: `1`; a nonzero cube function's extension vanishing (`mle_zero_card_le`): `n`; two different cube functions agreeing at a random point: `n`; a nonzero polynomial of degree `≤ d`: `d` |
| `batched`, `padPoly`, **`dens_batchPad`** | the zero-check's batched relation `Σ_k μ_k·c_k + μ_pad·Σ_j ζ^j·w_j`: if some clause or pad plane is nonzero anywhere, it vanishes on the whole cube with density at most `m + 1` |
| `hostPoly`, **`host_cubeSum`**, **`host_claim_iff`** | the three-term host polynomial; its cube sum is `Z̃(τ) + Σ ν_i·(g·h_i)~(p_i)`; the claim `= Σ ν_i·S_i` iff `Z̃(τ) + Σ ν_i·D_i = 0` |
| **`dens_host`** | relation failing or some `D_i ≠ 0` ⇒ the host's claim holds with density at most `m + 1 + n + 1` |
| **`dens_host_hosted`**, **`host_hosted_sound`** | a host and its two hosted private slots (claim points drawn first): relation failing or a hosted identity `H_i = M_i` failing ⇒ all three claims hold with probability at most `(n_1 + n_2 + m + n + 2)/|F|` |
| **`dens_rowsum`** | `SC_RS`'s `λ`-batched row claim at `p_ht`: at most `(n + 1)/|F|` |
| `mle2`, **`matmul_sum`**, `mle2_eq`, `dens_mle2_zero`, `dens_mle2Eq` | a private matmul slot's true sum `Σ_c Ã(r, c)·W̃(c)` is the extension of the contraction `Σ_c A·W` at its claim point `(r, s)`; its SZ density `b + a` |
| `eqPoly_append`, **`mleAt_append`** | the code's flat claim point `cat(r, s)` over the flat cube is the product-cube extension (`Fin.appendEquiv`) |
| `helperClause_single`, `helperClause_pair`, `helperClause_table` | the zero-check's LogUp helper clauses (`helper_sum`, `SC_TAB`) vanish exactly when `HelperRel`'s relations hold, i.e. `logup_block_bound`'s premise |

### 2.4 `LayoutW16.lean`: the layout map (ASSEMBLY §4.2 item f)

| Theorem / definition | Statement |
|---|---|
| `Ax`, **`sum_emb`** | an axis of the committed cube (logical indices embedded injectively in the padded axis); the pad rule for a sum |
| `gated_at` | support gating: `g·c = 0` with `g = 1` at a logical position gives `c = 0` there |
| `word16_of_lk`, `remVal`, `remLk`, `remW16_of_lk`, `word24_of_lk`, `wordS8_of_lk`, `direct_of_lk`, `bytes24_of_lk` | LogUp's conclusion for the W16R2 lookups (`lookups_w16`, range16.rs `word16`, `rem_lookups`, `word24`, `direct`; the isqrt bytes) gives exactly `Word16`, `RemW16`, `Word24`, `WordS8`, `InRange` |
| `W16Layout` (`slot`, `dPos`, `qPos`, `kPos`, `sPos`, `htPos`, `fPos`) | the W16R2 layout map: axes for tokens, width, key-value groups, head dimension (with its RoPE flip), hidden; **the head-slot order** C-1 (a head's slot = its group's bits on top of its within-group index, injective) |
| `W16Data`, `W16Pub`, `W16Rels`, `W16Lookups`, `W16Widths`, `toWit` | the extracted planes on the cube; the public tables and gates through the layout (gates `1` on the logical positions and `0` on the pad, padded weights zero); the 23 slots' relations on the cube; LogUp's conclusion at every logical position, domain by domain in the code's order; the widths in the family list; the witness read through the map |
| **`blockSat_of_slots`** | for one W16R2 block at LowH24: `W16Rels` ∧ `W16Lookups` (∧ the layout facts) ⇒ `BlockSat P (X ∘ dPos) (X2 ∘ dPos) (toWit L E)`, all 18 clause groups of CircuitBlock (the input check, both norms with their isqrt, Q/K/V, both RoPEs, the scores, softmax with its row sums, PV, the output projection, both residuals, gate with its ACT tuple, up, the 24-bit product, down) |

### 2.5 `LayoutW16Handoff.lean`: the hand-off premises (ASSEMBLY §4.2 item c)

| Theorem | Statement |
|---|---|
| **`hstart_block`** | if the attested output is not the integer block's on the committed input (or the block refuses it), then some slot relation fails or some lookup's tuple is not a table tuple (`blockSat_of_slots` through `block_circuitIff`): the zone's start doom sits in a slot or in LogUp |
| `hhand_batch`, `hhand_point`, `hhand_host`, `hhand_hosted`, `hhand_nu` | inside a host slot each stage hands its doom on outside exactly the bad events `SlotW16Sound` counts: the batch, the point `τ`, the host's claim (false sumcheck claim), the hosted difference at the claim point, `ν` |
| **`hfinal_terminal`** | an accepting slot whose final claim is not `poly(true values) + c·(true g)` has a false opened terminal or a false `g`: the doom passes to the openings (L10) and `M`; this is the slot's release (`hframe`, finding L8-4) |
| (`w16r2_8B_numerator_le`) | `hpath`'s numerator part (§2.2) |

## 3. The interface for L9

Namespace `ZK60.Exec.Slot` (`SlotW16Ir.lean`):

```lean
inductive TabV | eq (start : ℕ) (point : List Fp2) | pub (vals : List Fp2) | priv
structure SlotDefW where
  slot : ℕ; n : ℕ; ext : ℕ; degree : ℕ; tabs : List TabV; hosted : List (ℕ × Fp2); ir : Ir Fp2
structure SlotProofW where scalar : Fp2; rounds : List (List Fp2); terms : List Fp2
structure SlotOutW where c claimed fin : Fp2; rhoFull vals : List Fp2; polyVal gVal : Fp2
def slotVerifyW (H : HIn → Dig) (d : SlotDefW) (scalars : List Fp2) (p : SlotProofW) (t : Tr) :
    Except SlotErr SlotOutW × Tr
def claimedW (scalar : Fp2) (hosted : List (ℕ × Fp2)) (scalars : List Fp2) : Fp2
def valsGo (sel : Fp2) (rho terms : List Fp2) : ℕ → List TabV → Option (List Fp2)
def irEvalW (ir : Ir Fp2) (v : List Fp2) : Fp2
def gValW (fin polyVal c : Fp2) : Fp2
```

- `scalars` is the list of the earlier slots' published scalars, in slot order (`acc.scalars`).
- An accepting `slotVerifyW` hands on: `gVal`, the value of the slot's mask functional for `M`'s test (with `c` for its
  `Γ` weights); the masked terminals `p.terms`, the claims on `A`, `H` and the endpoints; `rhoFull`, the claim points.
- The zero-check and LogUp verifier arithmetic is INSIDE the slot polynomials: every zero-check's batched clauses and
  its LogUp helper relations (`helper_sum`), the pad term (`PadTerm`), `SC_TAB`'s table relations, `SC_ZS`'s zero-sum
  row. The verifier draws `β, γ, α` before `H` (protocol.rs:2829-2835); L11Check replays that head.

Namespace `ZK60.Exec.Slot.W16R2` (`SlotW16R2.lean`), for L9's schedule:

```lean
def sched (sh : ShapeW) (s : ℕ) : ℕ × ℕ × ℕ            -- (main, ext, degree)
def draws (sh : ShapeW) (s : ℕ) : List (Seg × ℕ)         -- define's draws, in order
def kindOf (s : ℕ) : Kind ; def hostsOf (s : ℕ) : List ℕ ; def padOn (sh : ShapeW) (s : ℕ) : Bool
def claimPoint (segs : ℕ → List (Seg × List Fp2)) (s : ℕ) : List Fp2
def eqPoints (sh : ShapeW) (segs : ℕ → List (Seg × List Fp2)) (s : ℕ) : List (List Fp2)
def hostedCoefs (sh : ShapeW) (segs : ℕ → List (Seg × List Fp2)) (s : ℕ) : List (ℕ × Fp2)
```

**Not supplied: the per-slot IR and public tables as Lean functions of the shape and the challenges** (a port of
`define`'s builders and `build_slot_ir`; §6). L11Check takes them from the corpus and checks them against the Rust
builder; `blockSat_of_slots` takes the slots' relations in named form (`W16Rels`).

## 4. Findings

No mismatch between the code and the approved statements was found.

**L11-1 (Low, latent): the SiLU product's remainder lookup width is hard-coded, not derived from the shift it guards.**
- CODE: `fzc_w16`'s product clause uses `r = data.folds().product.shift` (argument_accuracy.rs:520, 526); its
  remainder's lookups use a literal width, `16` at LowH24 and `24` at Low (accuracy_layout.rs:324). They agree today
  only through the fold derivation (`accuracy_public.rs:488` asserts the shifts `(24, 16)`).
- If a later profile changed the fold's product shift without the lookup, the remainder would be range-checked
  loosely and the product word `h` would no longer be pinned (the clause `a·u = 2^r·h + R − 2^(r−1)` is solved by
  several `h` once `R` may exceed `2^r`). `W16Lookups` states the lookup at `S.sprod`, the clause's shift, so the
  Lean instance needs `sprod = 16` at LowH24 — a decidable fact of the registered shape.
- Suggested: derive the width from `folds().product.shift` (a one-line change, byte-identical at W16R2).

**L11-2 (Info): an accepting verify arm does not itself check the terminal identity.**
- CODE: `run_slot` computes `g = (fin − poly(vals))/c` and pushes it as the value of the slot's mask functional
  (argument.rs:1458, 1494); the identity becomes a check only in `M`'s test (L10), and the masked terminals only in the
  `A` / `H` / endpoint openings. `slotVerifyW_terminal` states exactly this; `hfinal_terminal` passes the doom on.

**L11-3 (Info): the corpus's public tables.** 42 of the corpus's 49 public tables are larger than `2^10` entries (the
lifted cubes are `2^14`–`2^15`); for those the corpus carries Rust's multilinear value at `ρ` and L11Check checks the
verify arm with it (`verify-arm-parts`), not Lean's own `evalMleExt`. Lean recomputes the 7 smaller ones.

**L11-4 (Info): `ν`'s nonzero refusal is not needed for soundness.** `nonzero(tr.challenge_fp2_vec(2))`
(argument_accuracy.rs:466 and siblings) refuses a zero `ν`; `dens_affine` counts every `ν`, so the soundness bound holds
without the refusal. The refusal costs completeness `2/|F|` per host (negligible). Its reason is not stated at the site;
whether the zero-knowledge accounting needs it (the host's `Γ` functional carries `ν_k·c_hs`, argument.rs:1484-1490) is
for the hiding lanes to say. Not changed.

**L11-5 (Info): `SC_TZC`'s six isqrt clauses are not gated** (argument.rs:2097: `v[i_tau]·(zc + pz)`); only its host
terms are. On a padded token row the clauses hold on the zero-rule planes (`0 = 0·0`), so `W16Rels` states them on
the whole `T` cube; consistent.

**L11-6 (Info, engineering).** Multi-line structure-instance updates whose continuation lines do not align with the first
field fail to parse in this Lean ("unexpected identifier; expected '}'"); `rw` of a partially applied definition
(`List.map (segNum pp)`) needs the unfolded form stated (`e : … := rfl`); decidability instances from `classical`
against `[DecidableEq F]` caused `whnf` timeouts until each base density was passed through `dens_mono (fun _ h => h)`.

## 5. Optimization candidates (for a later profile; none changed)

- **O1: a LogUp host's declared degree is one more than its polynomial needs where its domain pads**: `FZC` wherever
  `F` pads (the rung, Shieldstral, 8B), `DZC` wherever `D` pads (the rung, Shieldstral). `Shape::slots` adds one for the
  support gate, but the host's degree is already set by its ungated LogUp arm. Known (slot_ir_tests.rs:228-290, ruling
  I-7: "recorded, not proposed"); L11Check confirms it from the IRs of the real rung receipt (its `DEGREE GAP` lines:
  slot 14 `DZC` and slot 18 `FZC`, declared 5, computed 4; every other slot attains its declared degree, and none
  exceeds it). Lowering it saves one `Fp2` per round (22 rounds of `FZC` at 8B: 352 bytes per block) and one
  evaluation point per round, and lowers the numerator by 22.
- **O2: the zone budget's slack.** `BlockZone8B` assumed `2^16` for the small numerators; the W16R2 8B slots need
  `1,479 + 3·pp` (`w16r2_8B_numerator_le`). With `2^11` instead, the zone total `εZone8B` would drop by about
  `2·(2^16 − 2^11)/p² ≈ 2^-110.0` — negligible against LogUp's share; no profile change, only a sharper count.
- **O3 (L11-1's fix):** derive the product remainder's lookup width from the fold's shift.
- Looked at and not proposed: the `per_row` factor of `SC_RS`'s hosted coefficient (it is the host term's constant in
  `j`, needed); `SC_LZC`'s all-ones helper batching (known, L3 F2: sound for one helper only).

## 6. What is left

1. **The per-slot IR and public tables in Lean.** A Lean port of `define`'s table builders (the folded weights, the
   RoPE and gain tables, the causal mask, the support indicators, the activation tables) and of `build_slot_ir` /
   `slot_ir_accuracy.rs` for the W16R2 slots, as functions of the shape and the drawn challenges, proved to have the
   three-term host form (`hostPoly`) with W16Rels's clause lists. Today the IR comes from the corpus: checked against
   the Rust closure (Rust) and against the host template (Lean), not proved. This is the remaining link between
   `slotVerifyW` and `W16Rels`.
2. **The instantiation of the per-slot bounds** with each slot's clause list and cube (`dens_host_hosted` at `DZC`,
   `QZC`, `KVZC`, `SZC`, `FZC`, `TZC`; `dens_rowsum` at `SC_RS`; the standalone zero-checks with `dens_host` and
   `D = 0`), the flat cubes split by `mleAt_append`, and their composition on the transcript (L8's
   `fs_code_chain_sound_sched` with each slot's `CSub` and `RbrWide`).
3. **The extraction** of the planes from the hash log (`SoundExtract.lean`), so that `W16Data` is the extracted data,
   and LogUp's `logup_block_bound` applied to the block's lookup list (its premise from `helperClause_*` and `SC_ZS` with
   `H`'s sum rows, L10).
4. **The concrete layout** of a registered shape: the axes' embeddings as the code's index maps (`plane_index.rs`,
   msb-first), the gates as `pad::indicator_table`, the padded weights zero, as finite checks; `W16Widths` for the
   8B family list (`range16::widths`); `S.sprod = 16` (L11-1).
5. **W16R3:** B2 replaces `sched`, `draws` and the hosts (one batched sumcheck over several slots); B3 replaces `Dom::F`'s
   axis (`Ax` for the compact flattened index, no gate). The theorems are stated for arbitrary embeddings and slot lists.

## 7. Checks

All in `results/zk60_lean_l11_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`):
- `rust.log`: the corpus export (`export_corpus.sh`: `cargo test --release --offline --locked -j 2 --lib
  lean_l11_export`, 163 s): 1 passed. `corpus.txt`: 286,295 bytes, sha256 `b9726375…8382`; 23 slots, 23 IRs.
- `file1.log` … `file4.log`, `iter1.log` … `iter4.log` (`stage.sh`, `iterate.sh`): the new files while they were written;
  the errors fixed on the way are in those logs (§4 L11-6). The Lean jobs waited behind the other lanes' and the media
  lane's GPU jobs, and the first ones behind the host disk's 40 GiB floor (it was at 33.7–39 GiB for about 25 minutes).
- `check.log`: `check_l11.sh`, which runs:
  - the full build (`full.log`): 3,459 jobs, rc 0, 0 warnings, 0 errors;
  - the axiom audit (`axioms_l11.lean`, written by `gen_axioms.py`, → `axioms.log`): 82 theorems, nothing
    beyond `propext`, `Classical.choice`, `Quot.sound`; 59 on `propext, Classical.choice, Quot.sound`, 14 on `propext, Quot.sound`, 8 on `propext`, 1 on none;
    `sorryAx` and `Lean.ofReduceBool` appear nowhere;
  - the source scan (none) and the root imports;
  - the regressions: `L6Check` 1,206 checks, 0 failed; `L5Check` 5,553 checks, 0 failed; the fixture L1 check 101,956
    checks, 0 failed;
  - **L11Check** (`l11check_full.log`): 404 checks, 0 failed, by kind (the table below);
  - the negative control (`mutate_corpus.py`, `negative_control.log`): seven single changes, exactly 7 failed;
  - the R19b file census (`cargo test … r19b_every_rs_file`, `r19b.log`): 1 passed.
- Peak RSS of the final check: 3.67 GiB (55 s).

| L11Check kind | Checks | What |
|---|---|---|
| `ASCII` | 1 | `pb-slot`, `pb-scalar`, `pb-term` as the Lean byte lists |
| `head`, `tags` | 1 + 1 | `verify_core`'s head replayed from the header (`A` root, `M`, `β, γ, α`, `H` root) to the state before slot 0; the three LogUp tags `γ·133`, `γ·129`, `γ·134` |
| `slot-index`, `kind`, `schedule`, `terms`, `slot-count` | 23 × 4 + 1 | the W16R2 slot list (`kindOf`, `sched` from the shape facts against `Shape::slots`, the terminal counts) |
| `draws`, `draw-layout` | 23 + 23 | each `define`'s draws replayed as squeezes from the previous slot's end, equal to Rust's and ending at the state before `pb-slot`; their count is `drawLen` |
| `hosted` | 23 | the hosted slots and coefficients (`ν_k`; `ν_0·per_row` for `SC_RS`) from the draws |
| `claim-points` | 15 | every slot's `eq` tables are exactly `τ` and the hosted slots' claim points built from the earlier slots' draws (the 8 slots without `eq` tables are the 7 matmuls and `SC_ZS`) |
| `ir-shape`, `ir-degree`, `ir-template`, `ir-challenges` | 23 + 23 + 6 + 149 | each IR: table count, back-references only, canonical coefficients; its computed degree at most the declared one (`DEGREE GAP` at slots 14 and 18: declared 5, computed 4); the six hosts' three-term template; every `μ[k]`, `ν[k]`, `ζ^j` coefficient equal to the draws |
| `verify-arm` | 12 | `slotVerifyW` from the state before `pb-slot` reproduces `c`, the claimed sum, `fin`, the challenges, every terminal value, `poly(vals)`, `g` and the transcript after `pb-term` |
| `verify-arm-parts` | 11 | the same where the slot has a public table above `2^10` entries, with Rust's multilinear value of that table (L11-3) |

**Negative control** (`mutate_corpus.py`, `negative_control.log`): one round value of slot 3, the scalar of slot 20, one
terminal value of slot 5, one public constant of slot 14's IR, the last draw of slot 4, LogUp's `β`, the terminal count
of slot 0. Exactly 7 checks fail, one per change.
