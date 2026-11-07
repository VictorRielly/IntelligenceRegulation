# D63 lane L21: `hRel` and `hLk` under Fiat–Shamir, per block shape (2026-11-07)

Lean lane L21 (Claude), on its own worktree branched from perf at `fdad3157` (L9 … L16 merged), with lane L20 merged in
at `db1bbb43` (its per-position count and the openings' knowledge). Lean 4.34.1, Mathlib v4.34.1, no new dependency.
Seven new library files under `formal/ZK60Formal/`, imported by the library root: `RelW16Chain.lean`,
`RelW16Define.lean`, `LookupW16FS.lean`, `RelW16Block.lean`, `RelW16Host.lean`, `RelW16HostDeg.lean`,
`RelW16Pos.lean`. No Rust and no production source changed. `Statements.lean` and every existing Lean file are
unchanged. Evidence: `results/zk60_lean_l21_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`),
**CODE** (read off the sources), **ESTIMATE** (arithmetic on bounds, not proved in Lean), **HYPOTHESIS** (a named premise
of a proved theorem, with the shape another lane or the W16R2 instance must prove).

## 1. In plain words, for Victor

**What this lane is.** L16 proved one block's knowledge statement up to three named hypotheses: the openings and `M`
(`hOpen`, lane L20), the slot relations (`hRel`) and LogUp (`hLk`). `hRel` says: a prover cannot get the block accepted
with true claimed sums while the extracted planes break a slot relation. `hLk` says: nor while a looked-up value is not
in its table. Both are Fiat–Shamir statements: the challenges come from the hash of the transcript, and a prover may try
many hash queries.

**What is now proved.**
1. **The slots' challenge draws under Fiat–Shamir, for any block shape.** Each slot's `define` draws its challenges as
   squeezes in a row, at a fixed place of the verifier's transcript. For ANY claims about the extracted data and ANY
   polynomials of the draws that vanish identically only when the claim is true, the chance that the slots accept, some
   claim is false, and yet every polynomial vanishes at the drawn challenges is at most
   `(q·d + Σ draws·degree)/p²` (plus hash collisions), `d` the largest degree in one challenge. One challenge at a time
   (Schwartz–Zippel round by round), so no assumption about the header's squeeze counters is needed.
2. **LogUp under Fiat–Shamir on the code's transcript**, with the lookups and multiplicities extracted from the
   prover's log, `β`, `γ`, `α` as three separate challenges: at most `(q + 3)·(N + 2M)/p²` (plus collisions).
3. **Both counted per position** (the coordinator's L20-5): the verifier's own transcript positions are charged only the
   rounds they start, not LogUp's rate each. This removes the condition of my first version (a prover had to make at
   least a sixth as many queries as the verifier's chain has items).
4. **Everything together, on the block verifier's acceptance** (`block_knowledge_target_mt`): given the openings' bounds
   (lane L20), two define schedules for the slot relations, two for LogUp's helper columns, and the instance's algebra
   (§5), **the chance that the block verifier accepts while the extracted planes do not satisfy the block's relations is
   at most your target `q·2^-100 + 2^-100`, for every `q`**.
5. **The numbers.** In L20's units of `(q + 1)/2^126` (the target is `2^26` of them): the slot relations `121,856`, the
   helper columns `121,856`, LogUp `26,402,768`. With the slots (`929`) that is `26,647,409`, inside L20's budget of
   `2^25 = 33,554,432`; the whole block is `30,202,737` of `2^26 = 67,108,864`, a margin of 2.2 times. **LogUp
   dominates**: its 34.9 million lookups at 8B T128 set the rate `2^-102.93` per query.
6. **The slot algebra the W16R2 instance plugs in**, proved generically: the host slots' identity (L13's three-term
   polynomial) and its degree on the draw vector, the standalone zero-checks, `SC_LZC`'s fixed helper weight, `SC_RS`'s
   row sums, the private slots' hosted differences, each nonzero for some challenges whenever its relation fails; and the
   CFS unmasking (the prover's scalars and masks drop out once `M`'s functionals are true).

**Three findings change the shape of L16's (and L20's) hypotheses (L21-1 … L21-3).** As L16 stated `hRel`, it cannot be
proved with a small error: each slot's scalar is absorbed AFTER its challenges, so without `M`'s functionals the prover
can make every claimed sum true whatever the relation. The fix is proved here (`block_knowledge_mt`,
`block_knowledge_acc_mt`: the same theorems with `hRel` and `hLk` given what `M` and the openings check). Two of those
checks were missing from the premise: the host slots' `M` functionals (kept in a separate list, `acc.hostFs`) and `H`'s
LogUp sum claim. `M` and the `H` opening do check them, so the openings' lane can prove the stronger premise.

**What is not done** (§5): the W16R2 instance itself (the concrete slot polynomials over the extracted tables, the
parse of each slot's draws, the reindexing of each slot's clauses into the layout theorem's named relations, and the
lookup list's bridge to LogUp). `hRel` and `hLk` are discharged for any instance that supplies its algebra, not yet for
W16R2's.

## 2. What is proved

88 theorems, every one on at most `propext`, `Classical.choice`, `Quot.sound` (the axiom audit, §6); none of
the forbidden constructs (the source scan, §6). Facts about the literal Goldilocks prime are stated for a variable `p`
within `2^32` below `2^64` (L7-4).

### 2.1 `RelW16Chain.lean`: squeeze-run sub-protocols on the code's chain (generic)

| Theorem / definition | Statement |
|---|---|
| `szSt`, `szSt_nil`, `szSt_full`, `szSt_full_map`, **`szSt_escape`** | Schwartz–Zippel round by round: the state "`Φ` vanishes on every point extending the challenges so far"; from a doomed reading one more coordinate escapes for at most `d` values (`IndDegLE d Φ`) |
| `SqX`, `SqX.Rbr`, `sqR`, `sqSub`, **`sqSub_rbr`** | a sub-protocol of `n` single squeezes with no message (window `a`, escape count `e`, state reading a log and the header) as L8's `CSub`; `RbrWide` with `e·(⌊2^128/p⌋+1)²/|Dig|` |
| `cRd_sq`, `chalTr_sq`, `opTrace_drawOps`, `cChain_trace`, `allSt_sq_congr`, `sqSub_alive`, `sqAt`, `sq_event` | a run of squeezes is read as the rounds; `challenge_fp2_vec(n)`'s trace; the chain of the verifier's operations is their trace; the schedule at two logs |
| **`fs_sq_knowledge`** | the knowledge version of L8's composition (L8's count) for any list of such sub-protocols on the chain of any operation list: at most `T·emax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1` |

### 2.2 `RelW16Define.lean`: the slots' `define` draws on the block's schedule

| Theorem / definition | Statement |
|---|---|
| `defOff`, `defPos`, `defLen`, `allOps`, `rootOps_length`, `fullOps_append`, `fullOps_length`, `fullOps_fit`, **`def_window`** | slot `k`'s draws start at `defPos = hdrLen + 10 + Σ_{j<k}(draws_j + 4 + 2·rounds_j)`; on the verifier's trace the header is the trace of the operations before them and the draws' squeezes follow |
| `tHistD`, **`tHistD_trace`** | the header reads as what `define` saw (`histOf` of the earlier records) |
| `defSq`, `defSq_rbr`, `defSq_stab` | slot `k`'s draws as a squeeze-run sub-protocol, its state Schwartz–Zippel's for `Φ (cuts) (roots) k (hist)`, frozen once the roots are logged |
| `DefWin`, `getD_map_toK`, `defWin_event` | the win: slots accept, a start claim `Gd` false, every `Φ = 0` at the drawn challenges; it is the composed event |
| **`block_defines_fs_knowledge`** | for ANY block shape, claims `Gd`, polynomials `Φ` with `(Φ ≡ 0) → Gd` and degrees `≤ dmax`: `Pr[DefWin] ≤ (q + defLen + 1)·dmax/|K|·(1 + p/2^128)² + collisions` (L8's count) |

### 2.3 `LookupW16FS.lean`: LogUp under Fiat–Shamir, extracted lookups

| Theorem / definition | Statement |
|---|---|
| `foldB`, `fold_eq_foldB`, `lkSt3` | LogUp's state over `β`, `γ`, `α` as three single squeezes |
| `lkQ`, `lkQ_natDegree`, `lkQ_eval`, `lkQ_ne_zero`, **`lk_round_beta`**, **`lk_round_gamma`**, **`lk_round_alpha`**, **`lkSt3_rbr`** | the escape counts `2M`, `M`, `N + 2M − 1`; one count `N + 2M` |
| `lkSq`, `lkSq_rbr`, `lkOps`, `challengeFp2Vec_three`, `absAt_rootsA`, `LkWin`, `lkSq_stab`, `lkWin_event` | LogUp at entry `hdrLen + 4`, its data cut at the `A` root; a win is the composed event |
| **`block_logup_fs_knowledge`** | for ANY block shape and lookup list: `Pr[slots accept ∧ an extracted lookup outside the table ∧ some helpers pass at the transcript's β, γ, α] ≤ (q + hdrLen + 11)·(N + 2M)/|K|·(1 + p/2^128)² + collisions` (L8's count) |
| `lk_of_logup` | `hLk`'s event at most `εhelp + ` that bound, `εhelp` for the helpers failing on the slots' acceptance alone (superseded by `lk_of_logup_pos`, finding L21-8) |

### 2.4 `RelW16Block.lean`: the composition (L8's count) and the numbers

| Theorem / definition | Statement |
|---|---|
| `OpenTrue`, `OpenTrue.mfs`, **`block_knowledge_mt`** | L16's `block_knowledge` with `hOpen` covering everything `M` and the openings check (`acc.fs ++ acc.hostFs`, `H`'s sum claim) and `hRel`, `hLk` given it (L21-1 … L21-3) |
| `DefSched`, **`rel_of_defines`** | any event covered by `nd` define schedules: at most `nd ×` `block_defines_fs_knowledge`'s bound |
| `schedBound`, `bias_frac`, `coll_le_frac`, `sched_le_101`, `rel_two_le_target` | one schedule (degree `≤ 80`, `ℓ ≤ 2^20`) at most `(q + 1)/2^101`; two at most `εsTarget q`, every `q < 2^100` (L8's count) |
| `lk_le_target` | LogUp at `N + 2M ≤ 35,153,256` at most `εsTarget q` when `ℓ ≤ 6(q + 1)` (L8's count; superseded by the per-position count, L21-5) |
| `defOffW`, `defOff_eq`, **`rung_defLen`** | at the rung `defLen = hdrLen + 1045` |
| `rel_of_defines_target`, `lk_of_logup_target` | the L8-count versions against the target |

### 2.5 `RelW16Host.lean`: the slot algebra (generic in cube, clauses, pads)

| Theorem / definition | Statement |
|---|---|
| `hostPhi`, `hostGd`, `hostPhi_eq`, `batched_zero`, `exists_eval_ne_zero`, **`hostPhi_nonzero`** | a host's claim identity is `Z̃(τ) + Σ ν_i·D_i`; nonzero for some draws unless every clause, pad plane and hosted difference vanishes |
| `zcPhi`, **`zcPhi_nonzero`**; `lzcPhi`, **`lzcPhi_nonzero`** | standalone zero-checks; `SC_LZC` with its FIXED helper weight `1` (sound for one helper relation, L13-2) |
| `rsPhi`, **`rsPhi_nonzero`** | `SC_RS`'s `λ`-batched row claim (`dens_rowsum`'s form) |
| `privPhi`, **`privPhi_nonzero`**, `privPhi_deg` | a private slot's hosted difference at its claim point, multilinear |
| **`unmask_host`**, `unmask_standalone` | the CFS unmasking: with the claimed sums true of `poly + c·mask` and `M`'s `Γ` functionals true, `Σ poly_h = Σ κ_i·Σ poly_i` and `Σ poly = 0` |

### 2.6 `RelW16HostDeg.lean`: a host's identity on its draw vector

| Theorem / definition | Statement |
|---|---|
| `indDeg_coord`, `indDeg_pow`, `indDeg_sum`, `indDeg_sel`, `indDeg_eqPoly_bit` | a coordinate has degree `1`; powers, sums; a function read at distinct coordinates keeps its degree; `eq(y, b)` is multilinear |
| `hostPhiAt`, **`hostPhiAt_deg`**, **`hostPhiAt_nonzero`** | a host's identity read at coordinates `ζ`, `μ_pad`, `μ`, `τ` (injective), `ν` of the draw vector: individual degree `≤ m + 2` (`≤ 66` at W16R2), nonzero for some vector unless the start claim holds |

### 2.7 `RelW16Pos.lean`: the per-position count, `BlockAcc`, the target

| Theorem / definition | Statement |
|---|---|
| `sqND`, `sqSk`, `sqSk_charge`, `sqAt_sk` | the squeeze-run schedule's skeleton is the same at every log; its charge is `Σ n·e·fibC/|Dig|` |
| **`fs_sq_knowledge_pos`** | `fs_sq_knowledge` with L20's `fs_code_chain_sound_sched_log_pos`: `(q·emax + Σ n·e)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)` |
| `defND`, `sqND_defSq`, **`block_defines_fs_knowledge_pos`** | the define draws of any slots `ks`, any block shape: `(q·dmax + Σ_{k ∈ ks} draws_k·dg_k)/|K|·… + collisions` |
| `defND_le`, `rung_draws_sum`, `rung_defND_le` | `Σ draws_k·dg_k ≤ dmax·Σ_{k<n} draws_k` for distinct slots; the rung draws `351` in all, so `≤ 351·dmax` |
| **`rel_of_defines_pos`** | any event covered by `nd` define schedules (escape counts `≤ dmax`, `Σ draws·dg ≤ ND`): at most `nd·((q·dmax + ND)/|K|·… + collisions)` |
| **`block_logup_fs_knowledge_pos`** | LogUp, any block shape: `(q·e + 3·e)/|K|·… + collisions`, `e = N + 2M` |
| **`lk_of_logup_pos`** | any event each of whose outcomes is in the helpers' event `EvH` or a win against LogUp (`hsplit`): at most `Pr[EvH] + ` that bound |
| `sched_pos_le_u126`, `nsmul_u126`, `lk_main_le_u126`, `lk_pos_le_u126` | in units of `(q + 1)/2^126`: a schedule `≤ dmax + ND + 2^15`; LogUp `≤ 26,370,000 + 2^15` for `e ≤ 35,153,256` |
| `w16r2_rel_lk_budget`, `w16r2_budget_mt` | W16R2: `5 + 924 + 121,856 + (121,856 + 26,402,768) = 26,647,409 ≤ 2^25`; with the fixed part `30,202,737 ≤ 2^26` |
| **`block_knowledge_acc_mt`** | L20's `block_knowledge_acc` (on `BlockAcc`, per position) with `hOpen`, `hRel`, `hLk` in the `OpenTrue` form |
| **`block_knowledge_target_mt`** | for ANY block shape: openings and `M` as L20's (`hsem` for `OpenTrue`), `hRel`'s event covered by two define schedules, `hLk`'s split into the helpers' event (two define schedules) and a LogUp win, the budget: `Pr[BlockAcc ∧ ¬BlockSat] ≤ εsTarget q` for EVERY `q` |

## 3. εrel and εlk against the target

`|K| = p²`, `p = 2^64 − 2^32 + 1`, `εsTarget q = q·2^-100 + 2^-100 = (q + 1)·2^26/2^126`. L20's units: `u126 q c =
(q + 1)·c/2^126`; L20's fixed part (`M`, both openings, the extraction failure) uses `c = 3,555,328`, the slots
`dmax + blockND = 5 + 924`.

| Term | Bound (per position) | In `u126` units | Status |
|---|---|---|---|
| `εrel`: two define schedules (W16R2's hosts with the standalone zero-checks and `SC_RS`; its private slots), each draw of individual degree `≤ 80` (a host's `≤ m + 2 ≤ 66`, `hostPhiAt_deg`) | `2·[(q·80 + 80·351)/p²·(1 + p/2^128)² + collBound + collBound]` | `2·(80 + 28,080 + 2^15) = 121,856` (≈ `(q + 1)·2^-109.1`) | PROVED (`rel_of_defines_pos`, `sched_pos_le_u126`, `rung_defND_le`), given the instance's cover (HYPOTHESIS `hcoverR`, §5) |
| `εhelp`: the helpers' relations (the zero-checks' helper clauses, `H`'s sum row), two define schedules | as `εrel` | `121,856` | PROVED in the same way, given `hcoverH` |
| LogUp at 8B T128 (`N = 34,897,920`, `M = 127,668`, `e = N + 2M = 35,153,256`) | `(q·e + 3·e)/p²·(1 + p/2^128)² + collBound + collBound` | `26,370,000 + 2^15 = 26,402,768` (≈ `(q + 1)·2^-101.35`) | PROVED (`block_logup_fs_knowledge_pos`, `lk_pos_le_u126`), given `hsplit` |
| `εlk = εhelp + LogUp` | | `26,524,624` | PROVED (`lk_of_logup_pos`) |
| the relations and LogUp with the slots | | `26,647,409 ≤ 2^25 = 33,554,432` | PROVED (`w16r2_rel_lk_budget`): inside L20's budget |
| the whole block | | `30,202,737 ≤ 2^26` | PROVED (`w16r2_budget_mt`, `block_knowledge_target_mt`): `≤ εsTarget q`, every `q` |

**L16's estimate checked.** L16 estimated `εlk ≈ T·135/2^110 ≈ T·2^-102.9`, `T = q + ℓ + 1`. The rate is confirmed:
LogUp's `α` round, `(N + 2M − 1)/p²` (counted as `N + 2M` for each of the three rounds, with the bias `(1 + p/2^128)²`
of one squeeze), `≈ 2^-102.93` per query. With the per-position count `T` becomes `q + 3`: the verifier's own chain
contributes LogUp's three squeezes, not its `hdrLen + 11` items. **What dominates is `N`, the block's lookup count**
(34.9 million at 8B T128); the table's `2M = 255,336` adds 0.7 %. In `u126` units the worst case is `q = 0`, where the
three verifier squeezes give `3e/4 ≈ 26.36` million: LogUp is 87 % of the block's `30.2` million.

## 4. Findings

No mismatch with the approved statements; no statement weakened; no target changed. `Statements.lean` unchanged.

**L21-1 (Medium): L16's `hRel` premise is not dischargeable as stated** (and L20's `block_knowledge_acc` keeps that
form).
- CODE (`slotStep`, ExecBlockVerify.lean:326-353; `run_slot`): a slot's `define` draws, then `c`, THEN `pb-scalar`
  absorbs the prover's scalar. The claimed sum is `scalar + Σ κ·scalar_h`. Given the draws and `c`, a prover can choose
  the scalars so that every claimed sum equals the masked slot polynomial's cube sum, whatever the relation.
- What ties the scalars down is `M`'s `Γ` functionals (a host's scalar is `c_h·Σ mask_h − Σ κ_i·c_i·Σ mask_i`, a
  standalone's `c·Σ mask`; `slotAcc`), whose masks are committed in `M` before the draws. `unmask_host` /
  `unmask_standalone` are the algebra.
- So `hRel`'s event must include `M`'s truth. `block_knowledge_mt` (on the slots) and `block_knowledge_acc_mt` (on
  `BlockAcc`) are the same theorems with that event (the same case split: `hRel` is used only where the claims and `M`
  are true). PROVED; the conclusions are unchanged.

**L21-2 (Medium): `MTrue` over `acc.fs` only misses the hosts' `Γ` functionals in `acc.hostFs`.**
- CODE (`slotAcc`, ExecBlockVerify.lean:302-318): a host's `Γ` functional goes to `acc.hostFs`, a standalone's to
  `acc.fs`; `blockVerify` hands `M`'s test `acc.fs ++ acc.hostFs` (line 395). L16's `hOpen` / `BlockWinT` and L20's
  `block_knowledge_acc` / `block_knowledge_target` (`hOpen`, `hsem`) speak of `MTrue … acc.fs`.
- Without the hosts' functionals, L21-1 remains for every host slot. `OpenTrue` takes the whole list. **For the
  openings' lane: `hsem` must give `OpenTrue`** (`block_knowledge_target_mt`'s form); `M` checks the whole list, so
  `MGood` does give it.

**L21-3 (Low): `H`'s LogUp sum claim is outside `acc.claims`.**
- CODE (`blockVerify`, line 400): `hc := acc.claims.h ++ [P.logupSumClaim]` is what `H`'s opening checks;
  `ClaimsTrue … acc.claims` omits the sum claim, and LogUp's `HelperRel` needs it. `OpenTrue` includes it.

**L21-4 (Info): single squeezes everywhere, no width function.** `FSLogUp.lean` reads `(β, γ)` as one round of width
2, which on the code's chain needs `W` at `β`'s counter (L16-2: the counter depends on the header). Here `β`, `γ`, `α` are
three rounds of width one (`lkSt3`: escape counts `2M`, `M`, `N + 2M − 1`), and each `define` draw is one coordinate of
Schwartz–Zippel (`szSt`). The rate is unchanged (the `α` round's), and no counter premise is needed.

**L21-5 (Medium, RESOLVED): LogUp's constant term under L8's count.** My first version (`lk_le_target`) needed
`hdrLen + 10 ≤ 6(q + 1)`: L8's count charges each of the verifier's `hdrLen + 11` positions LogUp's rate, and at `q = 0`
that exceeds `2^-100`. With L20's per-position count (`fs_sq_knowledge_pos`) the verifier's chain is charged LogUp's
three squeezes only: `lk_pos_le_u126`, for every `q < 2^100` with no condition on the header (and `q ≥ 2^100` is trivial).

**L21-6 (Info): two define schedules, not one with releases.** A private slot's claim `D_i(p_i) = 0` is checked only
inside its host's identity. L8's `hframe` lets a sub-protocol release its claim only at a step where a LATER one is
already doomed, and a host before its window is alive by definition, so the private slots cannot release to their host.
The union of two schedules (the hosts' start claims include `D_i(p_i) = 0`; the private slots' are the pointwise
identities) costs a factor 2 in `εrel` (`60,928` → `121,856` units).

**L21-7 (Info, optimization candidate): the pad term's `ζ` powers set the define draws' degree.** The per-coordinate
error is `d/p²` with `d` the largest degree in one draw: `ζ` enters with degree up to the pad count (`≤ 64`), the others
linearly. Its cost, `2·121,856` of the `2^26` units, is small; no change proposed.

**L21-8 (Medium, fixed here): `lk_of_logup`'s helper premise had L21-1's gap.** `lk_of_logup` asks that the extracted
helpers satisfy their relations whenever the SLOTS accept (`hHelp` on `SlotsAcc`). The helpers' relations are proved by
zero-check slots whose claims are tied down only by `M`'s functionals (L21-1), so that premise is not dischargeable
with a small error either. `lk_of_logup_pos` takes ANY helpers' event (`EvH`, with `OpenTrue` on `BlockAcc` in
`block_knowledge_target_mt`) and asks only that every outcome of `hLk`'s event is in it or is a LogUp win.

**L21-9 (Info, optimization candidate, no prover change): LogUp's three rounds are charged the same escape count.**
`lkSq` uses one count `e = N + 2M` for `β`, `γ` and `α`; the rounds' own counts are `2M`, `M`, `N + 2M − 1`
(`lk_round_*`, proved). A per-round count in the squeeze-run sub-protocol would make the verifier's constant
`N + 5M − 1 ≈ 35.5` million instead of `3(N + 2M) ≈ 105.5` million, i.e. LogUp's `u126` constant about `8.9` million
instead of `26.4` million (the block's total about `12.7` million instead of `30.2` million of the `2^26`). Pure Lean
statement work.

**L21-10 (Low, for the coordinator): which block statement to cite.** L20's `block_knowledge_target` is correct as
stated, but its `hRel` and `hsem` premises are in the L21-1 / L21-2 form, so its `hRel` cannot be discharged with a small
error. `block_knowledge_target_mt` is the same conclusion with premises that can be discharged, and with `hRel` and
`hLk` already discharged up to the instance's covers. The assembly should cite it.

## 5. What is left

1. **The W16R2 instance of the covers.** `block_knowledge_target_mt`'s premises that are the instance's algebra:
   - `hcoverR`: every outcome of `hRel`'s event (on `BlockAcc`, with `OpenTrue` and the true claimed sums) is a
     `DefWin` of one of two define schedules `DR`. Per slot: the parse of the slot's draw vector (`Fin (P.draws k) → K`,
     L11's `draws` / `segOf`: `τ`, `μ`, `ν`, `ζ`, `λ`, `μ_pad`, the claim points) into `hostPhiAt` / `zcPhi` / `lzcPhi`
     / `rsPhi` / `privPhi`'s arguments (`hostPhiAt_deg`, `hostPhiAt_nonzero`); the unmasking at each slot
     (`unmask_host`, `unmask_standalone`); the reindexing of each slot's clause list into `W16Rels`'s fields on the
     product cubes (`mleAt_append`, the axes' index maps, `pad::indicator_table`; L13 item 2), and naturality for the
     22 slots besides `SC_DZC` (L13 item 3). `rung_defND_le` gives `hNDR` once the schedules' slots are distinct.
   - `hcoverH`: the same for the helpers' relations (the zero-checks' helper clauses, `SC_ZS`, `H`'s sum row with
     `OpenTrue`'s sum claim, L21-3).
   - `hsplit`: a failing `W16Lookups` with true helpers is an extracted tuple of the block's lookup list outside the
     table (`CodeTable` as a finite enumeration `T`; L11's `word16_of_lk` … read backwards).
   - The concrete `F`, `csX`, `msX` from L13's builders with `SlotEval`, `hdeg`, `hpolyC` (`Ir.Canon`; L16 item 4).
2. **The openings' semantics in the `OpenTrue` form** (`hsem`, lane L20's `GroupsGood` / `MGood`): over
   `acc.fs ++ acc.hostFs` and with `H`'s sum claim (L21-2, L21-3).
3. **L21-9**, optional: per-round escape counts for LogUp.

## 6. Checks

All in one guarded job (`results/zk60_lean_l21_20261107/run_guarded.py`, the zk60 resource guard, class `cpu`, need
14 GiB, cap 24 GiB): `iter.sh` with `plan.txt` (the L21 modules), then `check_l21.sh`. The final run is iteration 6
(`iter6.log`, `check.log`; 2026-11-07 05:37–05:38 PST, child wall 69 s, peak RSS 3.83 GiB; iteration 4, the first full
check after L20's merge, peaked at 9.59 GiB).

| Check | Result |
|---|---|
| `lake build` of the L21 modules, one at a time, then the whole library | rc 0, 3,519 jobs, 0 warnings, 0 errors, 0 `sorry` (`full.log`) |
| the axiom audit (`gen_axioms.py` → `axioms_l21.lean`, a `#print axioms` line for every `theorem` of the seven files) | 88 declarations: 73 on `[propext, Classical.choice, Quot.sound]`, 12 on `[propext, Quot.sound]`, 2 on `[propext]`, 1 on none; no `sorryAx`, no `ofReduceBool`, no other axiom (`axioms.log`) |
| the source scan of the seven files for the forbidden constructs (`sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`) | none |
| the library root imports the seven files | yes |
| L6Check on the committed L6 corpus | 1,206 checks, 0 failed |
| L5Check on the committed L5 corpus | 5,553 checks, 0 failed |
| L11Check on L11's committed W16R2 rung corpus | 404 checks, 0 failed |
| the fixture L1 check | 101,956 checks, 0 failed |
| SlotW16BuildCheck on L13's layout and L11's corpus | 179 checks, 0 failed |

Iteration 5 failed on one `omega` call (a recursion limit in the large context of `block_knowledge_target_mt`'s
`q ≥ 2^100` branch); it was replaced by `not_lt.mp hq`. Nothing else changed between iterations 5 and 6.
