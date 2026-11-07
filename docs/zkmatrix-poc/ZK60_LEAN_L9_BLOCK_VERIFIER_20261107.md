# D63 step L9: the W16R2 block verifier in executable Lean, and its Fiat–Shamir bound on the real schedule (2026-11-07)

Lean lane L9 (Claude), on perf at 18d2e74c. Lean 4.34.1, Mathlib v4.34.1, no new dependency. Three new library files,
imported by the library root: `formal/ZK60Formal/ExecBlockWire.lean` (the decoder), `ExecBlockVerify.lean` (the
verifier), `ExecBlockFS.lean` (the Fiat–Shamir bound). One checker, `ExecBlockCheck.lean`, not imported by the root
because it defines `main`. One TEST-ONLY Rust file, `ops/zkp-mvp/gpu-metal/hashline/src/private_block/lean_l9_export_tests.rs`,
declared by one `#[cfg(test)]` line in `w16r2_tests.rs` (itself a test-only file, whose harness it uses) and listed in
`s25_tests.rs`'s `TEST_ONLY_FILES`; no production source changed. `Statements.lean` and every existing Lean file are
unchanged. Evidence: `results/zk60_lean_l9_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms `propext`, `Classical.choice`, `Quot.sound` only), **TESTED**
(value for value against the Rust code), **CODE** (read off the sources), **ESTIMATE**.

## 1. In plain words, for Victor

**Why this step.** Your §6 decision 3 makes the Lean verifier's verdict production acceptance. The earlier lanes built
its parts: the field, BLAKE3, the transcript, the Merkle check (L5), the sumcheck verifier (L6), and the Fiat–Shamir
theorems about them (L7, L8). What was missing is the block verifier itself: the program that reads a W16R2 block
receipt and runs every step in the code's order. W16R2 is the profile the media app's classifier and the 8B stack run
today. This lane writes it, ties it to the real code, and proves the block's sumcheck bound on the code's real schedule.

**What now exists.**
- **The decoder** of one block receipt, as the production D55 fork frame carries it (`HLPFORK1`).
  - It refuses every field word `≥ p`, a wrong length, a wrong run, block index or start position, and a column index
    out of range, with the code's own messages.
  - PROVED: a frame the decoder accepts is exactly the encoding of what it decoded. So **a receipt has one encoding**
    (two different frames never decode to the same receipt), which closes finding L5-2 for the block. PROVED too: an
    honest frame always decodes.
- **The block verifier** `blockVerify`, step for step as `verify_core` runs: the roots, the three LogUp challenges, then
  for each of the 23 slots its challenges, the CFS challenge, the claimed sum, L6's sumcheck verifier, the terminal
  values and the claims, then `M`'s test and the two openings.
  - The parts other lanes own are slots in a parameter structure: each slot's definition and terminal identity (L11),
    `M`'s test and the openings (L10). §4 states exactly what each must be.
- **The agreement check on a real receipt.** A test-only Rust export proves one real W16R2 block (the development rung,
  23 slots) with the production prover, frames it with the production encoder, and records every challenge the
  production verifier draws, 1,609 squeezes in all.
  - Lean decodes the 14.3 MB frame, re-encodes it byte for byte, and reproduces every challenge and the transcript
    after every phase: 273 checks, 0 failed.
  - Thirteen single-byte changes to the frame are each refused, or accepted, exactly as the Rust verifier did, with
    the same message.
- **The Fiat–Shamir bound on the real schedule** (PROVED, `block_sumchecks_fs_sound`).
  - A cheating prover making `q` hash queries gets the block's slots to accept while SOME slot's claimed sum is false
    with probability at most `T·d/|F|·(1 + 2^-64)²` plus two collision terms, `T = q + ℓ + 1`, `d` the largest degree.
    That is the bound of ONE slot, not 23 times it.
  - The theorem reads the claims off the code's own transcript: each slot's claimed sum is computed from values the
    transcript absorbed or squeezed before its rounds. That is the condition L7 left open (L7-2), now met on the code.
  - At the rung: `ℓ` = header + 1,044 items, degrees up to 5, so for `q ≤ 2^64` the bound is at most **2^-61**
    (`rung_block_fs_sound`).

**What this does not do yet.**
- The slot definitions and terminal identities, `M`'s test and the openings' arithmetic are L10's and L11's. In the
  agreement check they are a transcript-only stand-in, which moves the transcript exactly as the code does but checks
  no arithmetic.
- The Fiat–Shamir theorem takes each slot's polynomial as a function of the transcript and the terminal check as a
  premise. Tying the polynomial to the committed tables is the extraction step (assembly §4.2 a), and the terminal check
  is what `M`'s test and the openings prove (L10).
- One profile instance is checked: the W16R2 rung through the w16r2 test harness's header. A real D55 run's header
  and commit phase (`run_fork.rs`), the 8B and Shieldstral schedules, and §4.1's `S.Valid` / `R.Valid` are left (§6).

## 2. What is proved

All PROVED (`results/zk60_lean_l9_20261107/`): every theorem below is on at most `propext`, `Classical.choice`,
`Quot.sound` (the axiom audit, §7); no `sorry`, `axiom`, `native_decide`, `bv_decide`, `admit`, `implemented_by`,
`extern`, `maxRecDepth`, `maxHeartbeats` or `ofReduceBool` (the source scan). Facts about the literal Goldilocks prime
are stated for a variable `p` within `2^32` below `2^64` (L7-4).

**`ExecBlockWire.lean`: the decoder** (mirrors `wire.rs`'s `Reader` and `run_fork_wire.rs`'s `decode_fork`).

| Theorem / definition | Statement |
|---|---|
| `Geom`, `Dim`, `Geom.forkLen` | the verifier's frame geometry (per slot `(n, e, d)` and terminals, `M`'s constants, the block `Dim`, groups, rows, the ceiling) and `fork_len` |
| `rdFp`, `rdColumn`, `rdHiding`, `rdSlot`, `rdMask`, `rdCore`, `rdForkHeader`, `decodeFork` | the reader: `fp` REFUSES a word `≥ p`, `column` an index `≥` the width; the fork frame's length first, then the magic, binding, `L`, `k`, start tag COMPARED, the core, the end tag, no trailing byte; the code's refusal strings |
| `rdFp_ok`, `rdFp2_ok`, `rdMany_ok`, `rdColumn_ok`, `rdHiding_ok`, `rdSlot_ok`, `rdSlots_ok`, `rdMask_ok`, **`rdCore_ok`** | each reader that accepts consumed EXACTLY the encoding of what it returns, every word it returns is canonical, its counts are the geometry's |
| **`decodeFork_spec`** | an accepted frame is `encFork` of the decoded core and end tag under the verifier's own binding, `L`, `k`, start tag; `CoreCanon`; `CoreShape`; the counted length |
| **`decodeFork_injective`** | two frames that decode to the same receipt are the same bytes (finding L5-2 closed for the block decoder) |
| `rdFp_enc`, …, `rdCore_enc`, **`decodeFork_enc`** | the encoding of a canonical core of the verifier's shape decodes back to it (the honest frame is accepted) |

**`ExecBlockVerify.lean`: the verifier** (mirrors `verify_core`, `argument_with`, `run_slot`'s verify arm,
`build_claim`, `verify_one_fork`). Definitions only; no theorem is needed to state them.

| Definition | What |
|---|---|
| `BlockParams` | the interface (§4) |
| `slotStep` | one slot: `define`'s draws (`P.draws s` squeezes), `P.define`, the schedule checks (`slotDefChecks`), `pb-slot`, `c` (refused at zero), the terminal count, `pb-scalar`, the claimed sum (`hostedSum`), L6's `scVerify` (`scCheck` names the refusal by the slot), the terminal values (`tabVals`), `g(ρ)`, the degenerate-extension refusal, `pb-term`, the claims and functionals (`slotAcc`, `slotClaims`, `buildClaim`) |
| `slotsLoop`, **`blockSlots`** | the roots, `β`, `γ`, `α`, then every slot (`histOf`: `define` sees the earlier slots' draws) |
| **`blockVerify`** | `verify_core`: the shape checks, T-4 (`pathsDepth`), `blockSlots`, the functional count, `M`, `finish_claims`, `check_opening` and the opening of `A`, then of `H`; returns the IO claims |
| `posTag`, **`forkVerify`** | `position_tag`; `verify_one_fork`: decode against the start tag of the transcript handed, `blockVerify`, the end tag |
| `maskTranscript`, `pcsTranscript`, `openingChallenges`, `zkRhos`, `det` | the openings' transcript operations and column-index checks (`mask_verify_tagged`, `verify_zk_tagged`'s `zk_rhos` and absorbs, `check_opening_challenges` on a clone), what L10's checks must move the transcript by |

**`ExecBlockFS.lean`: the Fiat–Shamir bound on the real schedule.**

| Theorem / definition | Statement |
|---|---|
| `rootOps`, `slotPreOps`, `termOp`, `slotOpsFrom`, **`blockOps`**, `fullOps` | the verifier's operations as L8's run of slots: per slot its interstitial operations (the header and the 10 root operations before slot 0, the previous `pb-term` before every other, then `define`'s draws, `pb-slot`, `c`, `pb-scalar`) and its rounds |
| `slotOpsFrom_get`, `slotPre_from`, **`slotPre_blockOps`** | the operations before slot `k`'s rounds are the header, the roots, the whole slots before `k`, and slot `k`'s prefix |
| `slotStep_ok`, `slot_after`, **`slotsLoop_ok`**, `blockSlots_eq` | an accepting `blockSlots` runs slot `k`'s `scVerify` on `runOps` of exactly those operations (`slotTr`), with its claimed sum `hostedSum` of the earlier scalars and `define`'s hosted list, its draws and `c` the transcript's |
| `TRd`, `tChals`, `tSlotPre`, `tSlots`, `tRoot`, **`tSeen`**, `Seen`, **`claimOf`** | the reader of the code's TRACE before slot `k`'s rounds: the LogUp challenges and every slot's draws and `c` (squeeze digests) and scalar (the `pb-scalar` absorb's bytes); the claimed sum recomputed from them |
| `opTrace_append`, `tChals_trace`, `tSlotPre_trace`, `tSlots_trace`, `tRoot_trace`, **`tSeen_trace`**, **`claimOf_seenOf`** | on the verifier's own trace, `tSeen` reads what the verified slots' records show, and `claimOf` is the claimed sum `blockSlots` handed to `scVerify`: **each slot's claim is a function of the trace before its rounds** (L7-2) |
| `blockSlot`, `blockSched`, `blockLen`, `slotsLen_blockSched` | slot `k` as an L8 `Slot`: `s = (k = 0 ? hdrLen + 10 : 1) + draws k + 3`, the shape's degree and rounds, its statement `(f k (tSeen …), claimOf …)` of the trace; `ℓ = blockLen` |
| `BlockWin`, **`blockWin_slotsWin`** | the prover's win (a header of `hdrLen` operations within `L` bytes, a canonical core of the shape, `blockSlots` accepting, every terminal check `fin = f(ρ)`, some claimed sum false for a polynomial of individual degree `≤ d`) is L8's `SlotsWin` on `blockOps` |
| **`block_sumchecks_fs_sound`** | `prH (BlockWin) ≤ (q + ℓ + 1)·dmax/|K|·(1 + p/2^128)² + collBound (q + ℓ + 1) + collBound (q + ℓ + 2)` over `|Dig| = 2^256` (from `exec_sumchecks_fs_sound`; the largest degree, no factor of the number of slots) |
| `block_sumchecks_fs_sound_goldilocks`, `block_bound_le`, **`block_sumchecks_fs_sound_shape`** | at `|K| = p²`; with every degree `≤ 7` and `T ≤ 2^64 + 2^20`: at most `2^-61` (the first term `≤ 15·2^61/2^126`, each collision term `≤ 2^-126`) |
| `W16R2.rungSlots`, `rungTerms`, `rungDrawList`, `maskVec`, `maskQ`, `maskDom`, `maskPath`, `openedCols`, `ceiling` | W16R2's specifics, named (the rung's schedule as the corpus records it, checked by `ExecBlockCheck`) |
| `W16R2.rung_len`, `rung_slot_facts`, **`W16R2.rung_block_fs_sound`** | at the rung `ℓ = hdrLen + 1044`, every degree in `[1, 5]`; with a header of at most `2^19` operations, `L ≥ 2^20` and `q ≤ 2^64`: **at most `2^-61`** |

## 3. The agreement corpus

**The Rust side** (TEST ONLY): `hashline/src/private_block/lean_l9_export_tests.rs`, run by `export_corpus.sh` through the
guard (`cargo test --release --offline --locked -j 2 --lib lean_l9_export_the_w16r2_rung_block`; rc 0, `rust.log`).
- The block: the W16R2 development rung (`hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/2`: `log_cols` 14, rate 1/2,
  `Q = 280`, 23 slots, `A` 320 rows in 36 opening groups, `H` 202 rows in 9, `M` 50 rows), its core proved by the
  production `prove_core` with `w16r2_tests`' seeded recipe, framed by the production `encode_fork` (`HLPFORK1`, `L = 1`,
  `k = 0`), decoded by `decode_fork` and accepted by `verify_core` and the end-tag comparison.
- Each phase of `verify_core` is replayed beside the production call on the same transcript, and the replay's state and
  counter are ASSERTED equal to the production transcript's after every slot, after `M` and after each opening: the
  recorded schedule is the code's. `define`'s draws are counted by squeezing a clone until it reaches the transcript.
- `corpus.txt` (81,130 B, committed): the frame's length and BLAKE3, the binding, the start transcript (state, counter,
  the profile's Fiat–Shamir key), both position tags, the shape and the slot schedule (rounds, extension rounds, degree,
  terminals, kind, name), the roots, `β γ α`, per slot `define`'s draws, `c`, the scalar, the hosted list, the claimed
  sum, every round challenge, `fin`, the terminals, `g(ρ)` and the transcript after the slot; `M`'s `θ`, 48 row
  coefficients and 256 column indices; `A`'s and `H`'s group counts, `λ`s, proximity coefficients and 280 column
  indices; the end state (counter 1,609: every squeeze of the block); the decoded fields' BLAKE3s; 13 single changes of
  the frame with the production verdict.
- `fork_frame.bin` (14,258,216 B): NOT committed (over 1 MB); `export_corpus.sh` regenerates it byte for byte, and the
  checker compares its BLAKE3 with the corpus's.

**The Lean side**: `ExecBlockCheck.lean`, run with `lake env lean --run` (`l9check_full.log`). It uses the SAME definitions
the theorems are about. **273 checks, 0 failed**, in about 4.5 minutes, interpreted:

| Kind | Checks | What |
|---|---|---|
| ASCII | 13 | every label (`A`, `H`, `M`, `rows`, `log-cols`, `pb-slot`, `pb-scalar`, `pb-term`, `mask-q`, `mask-prox`, `pcs-vec`, `pcs-prox`) and the magic `HLPFORK1` are `ascii` of their text |
| SHAPE, SCHEDULE | 1 + 4 | 23 slot rows; the slot schedule, the terminal counts and `define`'s draw counts are `W16R2.rungSlots`, `rungTerms`, `rungDrawList`; `Q = 280` at rate 1/2 |
| FRAME | 3 | the length, `Geom.forkLen` = the length (14,258,216), Lean's BLAKE3 of the frame = Rust's |
| TAG | 2 | the start position tag of the start transcript; the binding is the header state |
| DECODE | 3 | `decodeFork` accepts the frame; the end tag; `encFork` of the decoded core is the frame byte for byte |
| FIELDS | 5 | the roots; the BLAKE3s of the re-encoded slots (22,480 B), `M`'s opening (243,712 B), `A`'s (10,727,488 B), `H`'s (3,264,320 B) |
| LOGUP, SLOTS, FUNCTIONALS | 1 + 2 + 1 | `β γ α`; all 23 slots verified by `blockSlots`; the transcript after the last slot; 34 `M` functionals |
| SLOT-* | 9 × 23 | per slot: `define`'s draws (351 in all), `c`, the scalar, the claimed sum, every round challenge (296 rounds), `fin`, the terminals, each hosted coefficient `ν·κ` with `κ < 2^32`, and the transcript state and counter after the slot (`blockOps`' operations) |
| MASK | 4 | `θ`, the 48 row coefficients, the 256 column indices, the state after `M` |
| OPEN, PCS | 2 + 8 | the opening-challenge refusals (on a clone) for `A` and `H`; per opening the `λ`s (114 and 47), the proximity coefficients (320 and 202), the 280 column indices, the state after |
| END, FORK | 1 + 2 | the end state (counter 1,609); `forkVerify` accepts the frame and its end tag |
| TAMPER | 13 | the honest frame, and twelve single changes (one byte short or long, magic, binding, fork index, start tag, the `A` root, a non-canonical scalar, a non-canonical `M` column word, an `M` column index, a round's `s(0)`, the end tag): each Lean verdict equals Rust's, message for message |

**Negative control** (`mutate_corpus.py`, `negative_control.log`): one draw, one round challenge, one slot's state, one
column index, one field digest and one tamper verdict changed: exactly 6 checks fail.

## 4. The interface for L10 and L11

`blockVerify` is `verify_core` (protocol.rs:2802) with the sub-checks it does not own as fields of
`BlockParams` (`ExecBlockVerify.lean`). Everything below is a function of the verifier's own public statement (shape,
layout, block statement) and of the transcript's values; nothing is read from a frame that the code does not read.

| Field | Type | Owner | Contract (what the instance must be) |
|---|---|---|---|
| `geom` | `Geom` | L9 (W16R2 named defs) | the frame geometry: per slot `(n, e, d)` (`Layout::slots`), the terminal counts (`slot_terms`), `M`'s constants (`2·2^9`, `MASK_Q = 256`, `2^12`, `12`) and rows, the block `Dim` (`Q`, `2^log_cols + Q`, the encoded width, its log), `A`/`H` groups and rows, the wire ceiling |
| `logCols`, `endpointLogN`, `aRows`, `hRows`, `aPath`, `hPath`, `maskPath` | `ℕ` | L9 | the shape's numbers (`absorb_root`'s rows and log-cols; `row_log`; the T-4 depths) |
| `preChecks` | `Except String Unit` | profile | `check_constructed`, `check_is_for_shape`, `check_for_shape` of the verifier's own shape and statement (no receipt input) |
| `kind`, `name` | `ℕ → SlotKind`, `ℕ → String` | L11 / layout | `SLOT_KINDS`, `SLOT_NAMES` |
| `draws` | `ℕ → ℕ` | L11 (L9 checks it) | how many `challenge_fp2` `define` draws for slot `s` (a function of the shape only; the corpus records the rung's) |
| `define` | `ℕ → Hist → List Fp2 → Except String SlotDef` | **L11** | `argument::define`'s definition of slot `s` from the history `Hist` (`β`, `γ`, `α` and the EARLIER slots' draws, the only things `define` reads, CODE) and its own draws, in order: the tables (`Tab.eq point start`, `Tab.pub v`, `Tab.priv ⟨cm, slices, log, coords, maskRow, extRound⟩`), the round polynomial `poly` (the terminal identity: `fin = poly(vals) + c·g(ρ)`), the hosted list `(h, ν·κ)`; and `define`'s own refusals (`nonzero`, layout checks) as `.error` |
| `nFunctionals` | `ℕ` | layout | `Shape::n_functionals` |
| `logupSumClaim` | `ZClaim` | **L11** | `protocol::logup_sum_claim(lay)`, the claim that closes `H` |
| `maskVerify` | `(HIn → Dig) → Dig → List MaskFunctional → MaskOpening → Tr → Except String Tr` | **L10** | `zk::mask_verify_tagged` on `M`'s root, the functionals `blockVerify` computed (in the code's order, hosts last) and the opening; it must move the transcript as `maskTranscript` does |
| `checkOpening` | `(HIn → Dig) → Cm → List ZClaim → Tr → Except String Unit` | **L10** | `protocol::check_opening` for `A` (`Cm.a`, its claims) and `H` (`Cm.h`, its claims with the LogUp sum claim last): the schedule audit, the group count, the challenge refusals on a CLONE (`openingChallenges`); it does not move the transcript |
| `pcsVerify` | `(HIn → Dig) → Cm → Dig → List ZClaim → OpeningZk → Tr → Except String Tr` | **L10** | `pcs::verify_zk_tagged` of `A` or `H` at the profile's PCS parameters and keys; it must move the transcript as `pcsTranscript` does |

What `blockVerify` computes itself and hands on (L10 / L11 read these, they need not recompute them):
- per slot (`SlotRec`): `define`'s draws, `c`, the scalar, the claimed sum, the main and extension challenges, the
  terminals, the final value;
- the claims per commitment (`Claims4`: `A`, `H`, input, output; `build_claim` mirrored) and the `M` functionals
  (`[Γ_s if standalone] eval_s` per slot with `g(ρ) = (fin − poly(vals))·c⁻¹`, the hosts' `Γ` after the slots).
  `blockVerify` returns the input and output IO claims, as `verify_core` does.

The theorem side: `block_sumchecks_fs_sound` takes the slot polynomials as `f : (k : ℕ) → Seen → (Fin (n_k + e_k) → K) →
K`, any function of what the trace shows. L11's arithmetization supplies `f` (the masked slot polynomial) and the
terminal-check premise of `BlockWin`, which L10's `M` and opening theorems discharge.

## 5. Findings

No finding is a mismatch between the code and the approved statements; none weakens a statement. Severities: Info
unless marked.

**L9-1 (Info; closes L5-2 for the block): one receipt, one encoding.**
- CODE: `wire.rs`'s `Reader::fp` refuses every word `≥ p` (`noncanonical field word`), unlike `Fp2::from_bytes`.
- PROVED: an accepted fork frame is exactly `encFork` of what it decodes to (`decodeFork_spec`), so two different frames
  never decode to the same receipt (`decodeFork_injective`), and every decoded word is canonical (`CoreCanon`), which is
  what L6's `scVerify_accept_iff` and the transcript's re-encodings need.

**L9-2 (Info, modelling): `define`'s draws first, its refusals after.**
- CODE: `define` interleaves draws and refusals (`nonzero(tr.challenge_fp2_vec(2))?`, then more draws).
- The Lean slot draws `P.draws s` challenges, then calls `P.define`. A refusal ends verification either way (the code
  returns the `Err`), so the verdict is the code's and, on acceptance, so is the transcript; the corpus confirms every
  draw at the rung (23 slots, 351 draws).

**L9-3 (Info, CODE; for L11): `define` reads only the earlier slots' draws.**
- `define` reads `ctx` (the public statement, `α`, `β`, `γ·TAG`) and `pts`, and every point of `pts` is set by an earlier
  `define` from its own draws (`pts.r_t = tr.challenge_fp2_vec(lt)`, `pts.p_s = cat(&[&r_h, &r_t, &r_j])`, …); nothing a
  slot verifies (its `c`, `ρ`, terminals) flows into a later definition.
- So `Hist` (`β`, `γ`, `α`, the earlier draws) is exactly `define`'s input. A future profile whose `define` read more
  would widen `Hist` and the trace reader `tSeen` (both read the trace, so the theorem's shape is unchanged).

**L9-4 (Info): L7-2 is met on the code.**
- CODE (`run_slot`, argument.rs:1440): the claimed sum is the slot's scalar plus `Σ κ·scalar_h` over the hosted slots,
  `κ` = `ν` or `ν·per_row` (`define`'s hosted lists, argument_accuracy.rs:72–673).
- The scalar is absorbed (`pb-scalar`) before the rounds, `ν` is a squeeze of the slot's `define`, the hosted scalars are
  earlier `pb-scalar` absorbs: all in the trace before the slot's rounds. PROVED: `tSeen_trace`, `claimOf_seenOf`.
- TESTED: every hosted coefficient of the rung (6 host slots, 2 each) is a draw of its slot times an integer `< 2^32`.

**L9-5 (Low; for citing L7 / L8's numbers): W16R2 degrees reach 5.**
- CODE + corpus: `BASE_DEGREE` 4 plus the support indicator gives degree 5 at slots 14 (`03 D zero-check`) and 18 (`14 F
  zero-check`) of the rung.
- L7's and L8's numeric corollaries (`exec_sumcheck_fs_sound_slot`, `exec_sumchecks_fs_sound_slot`) assume degree `≤ 4`.
  Their theorems are general; only the orientation figure must not be quoted for a W16R2 block.
- `block_bound_le` covers degree `≤ 7` at the same `2^-61` (the first term at most `15·2^61/2^126`), and
  `W16R2.rung_block_fs_sound` uses it.

**L9-6 (Info): the corpus block's header is the W16R2 test harness's, not a run's.**
- CODE: W16R2 has no single-block receipt (`single_block_profile_allowed` refuses the string); its blocks travel as run
  segments or D55 fork frames.
- The corpus block is a production `prove_core` core under `w16r2_tests`' header (two absorbs), framed by the production
  `encode_fork` at `L = 1`, `k = 0`. `blockVerify` takes the transcript it starts from, so it is the same verifier inside
  a run; the run's own header, commit phase and fork start (`run_fork.rs`) are not mirrored here (§6).

**L9-7 (Info, engineering): interpreted Lean checks a 14.3 MB frame in 4.5 minutes.**
- `lean --run` interprets; the whole check takes 273 s at 4.8 GiB.
- Two traps, fixed: a reader that measured the remaining frame on every read (quadratic; the first run was stopped
  after 8 minutes, `file6.log.guard`), now `rdBytes` takes `k` bytes first; and the interpreter's stack, which the
  readers' 16,664-deep recursion over a clear vector needs raised (`ulimit -s 65520` in the scripts).
- A compiled verifier target (L5-5) remains the production route.

**L9-8 (Info): T-4 runs twice in a fork.** `verify_one_fork` checks the paths' depth, then `verify_core` checks them
again; the Lean mirrors it once, in `blockVerify` (the decoder already reads exactly the geometry's path length).

## 6. What is left

- **L10 (instances of `maskVerify`, `checkOpening`, `pcsVerify`):** `M`'s test, the schedule audit and the openings'
  arithmetic (the combined functional, `⟨v, c⟩`, the Merkle columns, the coset-NTT column checks), each proved to move
  the transcript as `maskTranscript` / `pcsTranscript` do (the corpus pins those) and to discharge `BlockWin`'s terminal
  premise `fin = f(ρ)` from the openings' claims and `M`'s `g(ρ)` functionals that `blockVerify` hands them.
- **L11 (instances of `define`, `logupSumClaim`):** each slot's tables, `poly` and hosted list from `Hist` and its draws
  (W16R2's `define_changed` and `define`), and the polynomial `f k` for the theorem (the masked slot polynomial over the
  committed tables). With L11's `define` the checker's stand-in is replaced and `g(ρ)` and the claims are checked against
  the corpus too (the corpus already records `g(ρ)` per slot: `gval`).
- **The knowledge step:** `f k` as a function of the extracted committed tables rather than of the trace alone
  (assembly §4.2 a); the theorem is stated so that this is a premise swap, not a new chain argument.
- **The run level:** `run_fork.rs`'s header (the run statement), commit phase (the boundary roots, `S0`), fork start
  (`pb-run-fork`, the block digest), the join (`S1`) and the tail (the boundary and endpoint openings); and the D12a
  segment frame (`decode_segment`: the same core with `b_root` and the IO openings). The block verifier is the piece
  each of them calls.
- **The other W16R2 schedules:** the 8B T128 and Shieldstral T128 blocks. The theorems are generic; each needs its
  named `rungSlots`/`rungTerms`/`rungDrawList` (exported the same way, at a heavier proof) and its `rung_len`.
- **W16R3 (D67):** B2 changes the slot list and the draws (a new named schedule and `define`); B1 changes `pcsVerify`
  (the encoder); B3 changes `define` and the layout. `blockVerify`, `decodeFork` (beyond `Geom`) and every theorem of
  `ExecBlockFS.lean` are unchanged.
- **§4.1's `S.Valid` / `R.Valid` for the Shieldstral classify profile (deliverable 5): not done.** `S.Valid` is a finite
  check of the profile's shape constants; `R.Valid` (`BlockPublic.Valid` of every block) ranges over the registered
  public weights, which are not in the repository (no model weights, D62), so its finite check needs the weight
  material at hand.
- Malicious controls beyond the 13 here (opening and `M` tamperings need L10's checks); a compiled checker (L5-5).

## 7. Checks

All in `results/zk60_lean_l9_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`):
- `rust.log`: the corpus export (`export_corpus.sh`), rc 0, 1 test passed (the build 2 min 42 s, the test 1.75 s).
- `rust_inventory.log`: hashline's source-inventory tests (`r19b`, `rust_inventory.sh`): 5 passed, 0 failed, among them the file census r19b_every_rs_file_under_private_block_is_on_the_path_or_a_named_test_file.
- `file1.log` … `file7.log`: the three files while they were written (`stage.sh`, `stage2.sh`; peak RSS 3.8–4.8 GiB).
  The errors fixed on the way are in those logs: a reader type that rewrites could not see through (now an `abbrev`
  with explicit combinators, no `do`), `do`-notation join points, hypothesis shadowing across `obtain` with `rfl`, the
  quadratic reader of L9-7 (`file6`, its checker stopped with SIGTERM after 469 s), `omega` on `2^64` (an explicit
  `calc`). `file7.log`: the three files built with no message, then the checker: 273 checks, 0 failed, 273 s.
- `check.log`: `check_l9.sh`, which runs:
  - the full build (`full.log`): 3,457 jobs, rc 0, 0 warnings, 0 errors, no `sorry`;
  - the axiom audit (`axioms_l9.lean`, written by `gen_axioms.py`, → `axioms.log`): 91 theorems, 45 on `propext,
    Classical.choice, Quot.sound`, 16 on `propext, Quot.sound`, 16 on `propext`, 14 on none; `sorryAx` and
    `Lean.ofReduceBool` nowhere;
  - the source scan of the four L9 files (none) and the root import (the three library files);
  - the regressions: `L6Check` 1,206 checks, 0 failed; `L5Check` 5,553 checks, 0 failed;
  - the L9 agreement check (`l9check_full.log`): 273 checks, 0 failed;
  - the negative control (`negative_control.log`): 6 failed, as required.
- Peak RSS of the final check: 4.82 GiB (545 s).
