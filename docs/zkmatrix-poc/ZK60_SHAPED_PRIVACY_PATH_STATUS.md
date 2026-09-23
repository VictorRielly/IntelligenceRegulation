# The privacy path at the 125M shape — one private block and a twelve-block private run (status inventory)

**Written 2026-09-23 03:02–03:40 PDT** by a delegated Opus 5.5 agent for the
security owner, on `perf/zk-batch-optimizations` (main tree). It is a reading
of the dispositions and the two lane ledgers; **no code, gate, test or proof
was run for this page.** Main-tree documents and the ledgers were read as they
stood at 03:00; the lane branch `zk60-private-block-125m` was at `1ab1498`
(stage 44) and the gate branch `zk60-native-jointview` at `8b1c2c4` (round 9i).

**This is NOT a privacy acceptance and NOT a draft statement.** Register entry
D22 (the toy block, `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`) is the only
privacy statement in force. Nothing here upgrades an argument into a proof,
a test into a guarantee, or a two-block measurement into a twelve-block one.

**Labels.** [MEASURED] a run happened and its log or record is cited;
[COUNTED] arithmetic from code and shape, by the cited document; [ARGUED] a
drafted argument that survived one independent attack, as its disposition
rules; [READ] a fact read in a cited document or source line; **[MINE]** my
own arithmetic or inference for this page, checked by nobody. Status words:
**DONE** (closed to the level the toy's step was closed, evidence cited),
**NARROWED** (what remains is named), **OPEN** (what it needs is named),
**N/A**.

## 0. In plain words

- **Accepted: only the toy block (D22).** For the 125M block and the 125M
  run nothing is accepted and no statement is drafted — but all five of the
  toy statement's steps now have a checked core at the shaped layouts, and the
  125M shape has passed the whole gate (28 channels at 10 / 5 / 4 / 9, as at
  every small shape) — **only on two-block runs**, never on a standalone 125M
  block receipt, never on twelve blocks.
- **The block is closer.** Left: Victor's **D19b**; the lane integrated and a
  pin set traced for the 125M path; **a standalone 125M block receipt through
  the gate**; small argument leftovers (GS-5, GS-11, GS-12, what "the LAW
  still owed" means for G-R4); then a drafted, attacked statement.
- **The run needs that plus:** the gate at twelve blocks (one of eleven
  boundaries measured) with a twelve-block all-zero run; run-scope draw
  accounting; **a production run driver** (`prove_run` has no production
  caller, so M-9 is a tested writer only); two small lift items (GS-7, the
  L = 2 tag hybrid).
- **Needs Victor:** D19b (both). Not privacy, but owed before any product
  claim about a run: its ~2^-97.5 soundness and 484 MB receipt.
  **Needs the integrator:** the integration and D22 re-pin; the run driver.

## 1. Scope of the two target statements, as a D22 analogue would read

| | (a) one 125M block | (b) twelve-block 125M run |
|---|---|---|
| Profile string | `hashline-zk-mr1/private-block-m125/1` [READ, lane ledger stage 24 item 3] | `hashline-zk-mr1/private-run-m125/1` [same] |
| Shape | 512 tokens, width 768 (padded 1,024), hidden 2,048, 12 query heads of 64 over 4 key-value heads; 2^14 columns at rate 1/4 [READ, `ZK60_PRIVATE_BLOCK_125M_LAYOUT_DISPOSITION.md`] | twelve such blocks under one transcript; 11 internal boundaries, 2 external endpoints (D12a) |
| Receipt | 40,783,352 B [MEASURED, lane stage 35 `y35-m125-after.log`; post-S19-F1] | 484,107,456 B in 12 segments [MEASURED, dense, `m125-run-l12-dense.log`, 2026-09-20 21:01] |
| Weights | public synthetic (the dense recipe `dense_tests::dense_run_case`) | same; `Wd` band 1 at 125M so the chain is admissible [MEASURED, lane stage 21 item 4] |
| Hash rule | D19a tag, BLAKE3 keyed mode, four keys derived from the profile [READ, D19a] | the shape's keys, the run separated by its own domain string (D19a) |
| Sealing | the prover at proof time (D18 A); three OS-seeded generators (block + two endpoints) | the prover (D18 A); three generators per run (one for the run, two endpoints) [READ, J-2] |
| Sampler term (D9) | **9,212,588 draws → about 2^-72.86** **[MINE]**: 9,029,804 (block) + 2 × 91,392 (endpoints), the per-part counts of `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` §6.2 [COUNTED there]; no document states the standalone-block total | 109,728,784 draws → **2^-69.29** [COUNTED twice independently; H-6] |
| Input-dependent refusal inside the argument | 768/p² = 2^-118.4 one world; **2^-117.4** as a two-world distance [COUNTED, S-4; K disposition §1] | 2^-114.8 one world; **2^-113.8** two-world [COUNTED, run memo §6.2 row 2] |
| Challenge-only refusal (liveness) | 4/p = 2^-62.0 **[MINE]** from the run memo's `(3L+1)/p` at L = 1 | 37/p = **2^-58.8** [COUNTED, R-6; run memo §6.2] |
| Hash-layer terms | not tabulated for a standalone block | every distance term ≥ 37.3 bits below the sampler at q = 2^128; the total equals the D9 term to four decimals [COUNTED, reproduced independently; H disposition §1, run memo §6.2] |
| A million proofs / runs | about 2^-52.9 **[MINE]** | 2^-49.36 [COUNTED, run memo §6.3] |

## 2. Step by step against the toy statement

### 2.1 What it rests on (toy §3, five steps)

| # | Toy step (D22 §3) | (a) 125M block | (b) twelve-block 125M run |
|---|---|---|---|
| 1 | The all-zero hidden input is admissible, proves and verifies | **DONE.** The witness builder admits zero at 125M under both weight recipes, and the three zero-headroom boundaries are pinned at the shape's own constants (262,143 of 262,144; 512 of 512; 262,144 of 262,144) in the ordinary `private_` filter [MEASURED, lane ledger stage 19 task 9]. One 125M block on the zero input proves and verifies, 26.98 s / 1.23 s [MEASURED by the security owner, `ZK60_BLOCK125M_S19F1_DISPOSITION.md` §6]; re-proved after the speed stages (`q28-m125-final-zero.log`, lane stage 28). *Caveat:* no 125M prove on the lane tip since stage 35; stages 36–44 assert every byte pin unchanged [READ, ledger stage 44 "Byte identity"]. | **NARROWED.** A two-block all-zero 125M run proves, verifies and was captured (`m125-capture-zero-l2`, 2026-09-21 08:57) and gated (round 9) [MEASURED]. **A twelve-block all-zero run has never been run** [READ, `MVP_STATUS.md` privacy table row 1]. That the zero chain is identically zero and its witness weight-independent is a test (stage 19); the twelve-block case rests on that, not on a run. |
| 2 | Per commitment, the linear view discloses nothing on any non-refused run | **NARROWED.** The shaped lemma is accepted with changes S-1…S-6 (full row rank on the non-data rows; `H`'s 2 are span-equal to the public LogUp identity; no structural key collision; the refusal refinement) [ARGUED, `ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md` §1–2]; the reduction includes the individual claims (row S21 of the lemma, reduced to `ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4, computed at m = 3 and 5). Invariants S-1, S-3, S-6 are named refusals (lane stages 23, 24, 33). **At 125M, MEASURED on two two-block captures:** `A` 0 (5,681 rows, 122 claims), `H` 2 = the public identity, both endpoints 0, `M` 0 beyond its budget (`ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` §2b round 9). **Left:** GS-5 (the tool's reduction at pad count ≠ column count not re-derived; brute force scores 0), GS-11 (`M-q`, `M-prox` carried over from the toy lemma), GS-12 (the activation family at padded positions, re-derived by nobody), GS-2 (replay order pinned on a real rung-G capture, lane stage 23 item 4, and on a rung-K4 boundary, stage 25 W-3 — not at 125M), GS-4 (audit exclusivity at 125M observed only indirectly: disclosure 0 where a shared pair measurably discloses 2 and that control fires at 125M, round 9c) — each named in the lemma's §7 and mentioned in no later document. | **NARROWED.** As (a), plus the boundary: its 6 × 6 determinant is `Norm(λ₁cm₁)·Norm(λ₂cm₂)·wedge(prox)` exactly [ARGUED, S disposition §1]; the boundary's row count is derived and any other refused (M-1, lane stage 12). **At 125M ONE boundary has been measured** (6 of 6 on its reserved rows, disclosed 0, round 9); the run has eleven. |
| 3 | The gate constructs blinding reproducing each captured view under the zero input; joint figure; masking commitment closed | **OPEN for the block profile itself** (NARROWED through run stages). At 125M, all seven hiding commitments of a two-block run are reproduced from blinding constructed for zero data — 8,263,736 entries, none differing, 1,792 salted leaves — plus the masking layer (32,918 entries, 512 leaves), every control family firing, **channel table 28 at 10 / 5 / 4 / 9** [MEASURED, rounds 9 and 9c; record `results/zk60_native_run_gate_m125/m125-dense-everything.json` on the gate branch]. **But every one of these is a stage of a RUN.** No `private-block-m125` receipt has ever been captured or gated: a standalone block absorbs its own `parameters` line and has two external endpoints and no run header or boundary [READ, lane ledger stage 14 "L = 1 … not meaningful", stage 25 W-2]; the integrator's capture writer is toy-only [READ, lane stage 6 C-F5]. The toy's step 3 was measured on standalone receipts. | **NARROWED.** Measured at L = 2 only (one internal boundary): one joint assignment for the whole run, 8,296,654 entries — a SUM of per-arm checks joined through coupling C1 (128 row pairs, none touching a blinding row), not a third verification [MEASURED; the 14:26 correction in the multi-block disposition]; development shapes at L = 3. **Never at L = 12.** Of the nine open channels, seven are the toy's open-by-design seven; the two added for a run are the cross-block joint LAW (O-R3) and the boundary scale tags — the second is closed in code by R-5 (stale grading, §4 item 26). Records carry `privacy_property_established: false`. |
| 4 | For fixed challenges, the joint law of all published field values is input-free (uniform-blinding idealisation) | **NARROWED.** Theorem B — the toy theorem per stage plus a factorisation over stages whose key hypothesis is a code fact — is accepted as a reduction for a shaped block and a run [ARGUED, `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md` §1], conditional on: **G-R1** (row 2 above); **G-R2** (slot closures hold with changes, `ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md`; enforcement C-3/C-4/C-7 built, lane stage 24 items 6–8; terminal identity 46 of 46 at 125M, round 9; the non-linear channel's algebraic half closed, NL-1); **G-R4** (cross-role independence: J-1 puts it in the first hop — the generator assumption plus a position map found complete [ARGUED, `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_DISPOSITION.md` §1–2]; the seven draw-accounting assertions are live [MEASURED, lane stage 36] on single-block proofs at six shapes — toy, rung-K4, rung-P2, rung-C6, rung-W14, rung-E32 — **not at 125M**, where 9,029,804 per block is a count). The joint sentence with salts, hash objects and flag holds with changes (J disposition §1). **The security owner's latest wording still reads "the LAW still owed" for G-R4 (NL-8, 2026-09-22 20:45) without saying what remains after J-1 and stage 36** — that needs one sentence of ruling. Completeness for every admissible witness (GN-1 / GS-14): **NARROWED** by the census and rulings CS-1…CS-9 (lane stages 38–44): every data-dependent refusal site is covered by the witness builder; the 23 slot relations for every admissible witness rest on edge proofs and dense runs, not a symbolic derivation [READ, census disposition §3, §9]. | **NARROWED.** As (a), and: R-4 (zero at 125M) closed by row 1; R-6's refinement taken (S-4). **J-5 widened the draw-accounting assertion 2 to a run's `11L + 3(L−1)` segments; nothing measures that** — stage 36 measured single blocks only [READ, lane stage 36 "the seven assertions"]. The run total 109,728,784 is a count. |
| 5 | The hash layer adds nothing, and the fixed-challenge theorem lifts to the hashed protocol (Route A) | **NARROWED, BLOCKED on D19b.** The tagged hash layer and lift are written for a RUN (Lemma H^run, Route A^run, core accepted with changes, `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` §1); a block inside a run is hashed exactly as a standalone block of its shape (D19a), but **no document writes the standalone tagged block** (L = 1, own `parameters` absorb, two endpoints) — one paragraph owed. Measured at 125M on run captures: 2,304 opened columns (52.9 MB) re-hashed under independently derived keys and authenticated; 27,828 challenges re-derived (round 9). The model — BLAKE3's compression function ideal at an adversary-chosen chaining value — is **D19b, PROPOSED, pending Victor** [READ, register]. | **NARROWED, BLOCKED on D19b.** Route A^run proved inside the model, conditional on Theorem B [ARGUED, run memo §7.1 row 19]. Built since: the H-4 key test over every tagged profile, the H-5 trailer property, the H-8 constructor-length test — C-R2 is now checked (lane stage 24 items 1–3). C-R1 is covered by the stage-25 W-2 table test by its construction **[MINE; no disposition marks C-R1 closed]**; C-R4 is a deployment hypothesis; C-R5 true. **Open, both small:** the explicit L = 2 hybrid for the position tags ("STILL OPEN as an item for a future checker", run memo §7.3 item 2); **GS-7** — a boundary's site-0 claim value is published one stage before the opening whose λs blind it; the shaped lemma calls it "the simulator's ordering in the lift (G-R5), which is unwritten", and no later document maps it onto Route A^run. Route B (O-4 / G-H1) is open for the toy and the run alike and is not needed by a Route-A statement (item 13 of §3). |

The toy's own caveat carries over word for word: every step was drafted by
one delegated agent and attacked by another; nobody re-derived the mathematics
end to end, and the Python ports equal the Rust by readings — at the shaped
layouts with one extra cross-check, the lane's slot-IR export against the hand
port, 1,288 structural comparisons over seven shapes, 0 disagreements
[MEASURED, gate round 9c item 4; rung-K8 not covered].

### 2.2 Residuals (toy §4)

| Toy term | (a) 125M block | (b) run | Status |
|---|---|---|---|
| Sampler bias (D9, accepted) | 2^-72.86 **[MINE]** (§1) | 2^-69.29 [COUNTED twice] | block: **OPEN (small)** — the standalone count is written nowhere; run: DONE |
| Zero lookup denominator (the input-dependent refusal class) | 2^-117.4 two-world (2^-118.4 one world) | 2^-113.8 two-world (2^-114.8 one world) | DONE as counts (S-4, K disposition §1); *which* line refuses depends on data, *whether* does not (census C-5, same form as D22 §9 item 10) |
| Salt guessing; leaf-input collision; challenge pre-query; absorb collision | not tabulated | −106.76; −214.52; −110.52; −222.04 (log2, q = 2^128) [COUNTED, run memo §6.2] | block: **OPEN (small)**; run: DONE |
| Node/leaf overlap (toy's 2^-241.42, 2^-484.8) | removed by the tag, re-priced as the tag-key collision `C(12,2)·2^-256` = 2^-249.96, zero today by test [COUNTED, H-4] — **only in D19b's model** | the same | DONE as counts; the model is Victor's |
| Constructor-vs-absorb (new, B10) | — | −128.00 | DONE (run) |
| Key collision (tag key = a generator key) | — | −252.42 | DONE (run) |
| The generator | the named assumption (C-3), plus E-1: separate OS entropy reads independent and uniform (J-2); in-model alternative `6q·2^-256`, ASSUMED | the same, −125.42 in-model | DONE as an assumption, stated |
| Refusal on degenerate challenges (liveness) | 2^-62.0 **[MINE]** | 2^-58.79 [COUNTED] | DONE (run); block: one line |

### 2.3 Conditions (toy §5) — and the shaped ones a statement would add

| Toy condition | (a) block | (b) run | Evidence |
|---|---|---|---|
| 1. One reserved pair per claim site, weights exactly `(cm, cm·U)`; `H`'s shared zero-sum pair the one exception; `audit_claims`' exclusivity is the whole defence | **DONE as a code fact** (the shared audit and claim builder run on every profile); observed at 125M only through the ranks (GS-4) | **DONE as code:** plus two sites per boundary, one pair each, opened once (D12a); geometry derived once in `BoundarySpec` and used by preparation, metadata and opening (U-1 answer) | joint-law composition disposition J-2 (the terminal surjection review: the pair's weight SHAPE carries privacy); shaped lemma disposition S-2; multi-block disposition §2a U-1 |
| 2. Pad count = opened columns | **DONE:** at 125M the pad rank check holds with equality generically (margin 0 is the generic case, D22 §8(c)); `M`'s `L_s + 256 ≤ 512` is a named `Shape::new` refusal, headroom 139 at 125M | same | round 9; C-4 (lane stage 24 item 7); gate report §12.8 dated note |
| 3. `d + 1` values per round; exact-row-span assertions; zero-mask refusal; the declared order of the mask functionals | **DONE, measured on run stages:** 34 of 34 functionals by position, value and weight at the shaped layouts (round 8) and at 125M (round 9 masking arm) | same | multi-block disposition §2b rounds 8, 9 |
| 4. One opening per commitment; a refusal is terminal | **DONE (type system)**; CS-3 (lookup miss) is one named refusal before the first commitment in a single block | the boundary consumes itself, no `Clone` (run memo §7.2); **CS-3 inside a run fires after block k's boundary commitment and earlier segments — accepted only under M-9**, which has no production code (§2.4) | census disposition §5 |
| 5. Every Merkle leaf salted with 32 fresh bytes; no unsalted digest published | **DONE (code);** the salts never reach a device (DC-B); path length checked before any hashing (T-4, lane stage 16) | same | D19 tag disposition §2a; device disposition DC-B |
| 6. Fresh OS randomness per proof; no seeded configuration | **DONE and stronger than the toy:** at every unfrozen profile each generator's domain carries its use, role and spec digest (lane stage 26, from D22 §9 item 6); the key-is-fresh assertion (stage 25 scan, stage 36 assertion 7). The two endpoint generators are measured on a **replica** of their call sites, not in situ (S36-F2) | one generator per run, never cloned (D12b(2), a compile error to fork), plus two endpoints (`run.rs:475`, `endpoint_g.rs:224` twice) [READ, run memo §6.3] | lane ledger stages 26, 36 |
| 7. The source pins of the gates; a change to a pinned file suspends step 3 | **OPEN.** No pin set exists for a shaped statement. Nearest: the run gate's port-dependent pins and the capture writer's source list; the pre-read's 43-path toy closure (`ZK60_D22_PREREAD_SHAPED_SNAPSHOT.md` §7, P-1); and `private_block.rs`, `wire.rs`, `run_sink.rs`, `endpoint_g.rs`, `hash_domain.rs`, `witness.rs`, which the writer pins and **no run-gate table compares** (gate ledger R9i.11 item 1). And the lane is **not integrated** (tip `1ab1498` named for integration, handoff `9382533`) | same, plus `run.rs`, `boundary.rs`, `run_sink.rs`, `run_statement_file.rs` | — |

**Conditions a shaped statement would add** (all built on the lane, none yet in
an integrated tree): the tag is never an input — a key set is `legacy()` or
`for_profile()`, derived by the verifier (T-7); a tagged commitment declines
the accelerator (T-8 / C-R5), so the statement is CPU-only by construction;
shape refusals S-1 (`log(Dom::Tab) == log_cols`), S-3 (`head_dim` < row width,
protecting slots 08, 15, 16), S-6 (the unreached `a_groups` arm), C-4 (mask
budget), CS-2 (no undersized window override), CS-5 (width ≤ 16,384); NL-3 (a
"public factor" is a public TABLE, for any new slot); CS-1, CS-4, CS-6, CS-7,
CS-8, CS-9 — every part of a statement re-checked against the shape it is
proved at, a run's block digests compared with its statement, and a profile
string naming exactly one geometry (block and run registries); H-8 and J-7a
(constructor lengths and ASCII separators, watched by tests); for a run, R-5
(interior scales refused unless the approved calibration's), M-1 (boundary
geometry derived) and M-4 (one calibration identity). D12 item 4 (the second
norm's int8 range) and D16 (norm range pins) are soundness preconditions,
carried, not privacy steps.

### 2.4 Operating rules (toy §6)

| Rule | (a) block | (b) run |
|---|---|---|
| Timing, memory, power out of scope (D20) | applies unchanged | applies; a run adds per-stage wall-clock and high-water marks to what an observer could time (gate channel text) |
| A receipt the prover's own check rejected is never transmitted (D21) | applies unchanged | **OPEN (integrator).** Rule M-9 / D12b(1): a run directory is publishable only with the run statement, written only after the whole run verified. The writer is test-only and **`prove_run` has no production caller** (H-2, 2026-09-21; still so at lane stage 44: "the run layer is still dead code in release (review O-1)") — a rule plus a tested writer, nothing more |
| A retained capture counts as publishing | applies | applies; the run-capture writer is `#[cfg(test)]` [READ, gate channel "retained captures"] |
| A refusal reason is never shown to anyone not entitled to the input | applies; CS-3's text names only the table family that missed — still witness-derived, the class the ruling allows (lane stage 44 open item) | applies; a run's refusal names the refusing stage, a function of the input (R-1.2) — the driver must enforce it |
| P-2: `HL_PB_BASEFIELD` / `HL_PB_TIMING` output is prover-private | applies (`timing.rs` is on the shaped path) | applies |
| H-1: the pass that seals the endpoints is the witness builder's own; `RunWitnessSource` takes the chain at construction | N/A | **OPEN (integrator, with the driver).** Exercised in a test (lane stage 24 item 9: an inadmissible chain refused before `prove_run` is entered); the interface still permits an adaptive source (run memo §7.2 C-R3) |

### 2.5 Scope and what must not be claimed (toy §1, §7)

- **CPU path only, by construction** (tagged commitments decline the
  accelerator). Before any statement extends to a device: a keyed device path
  (not built) and the device-buffer review of DC-B (pinned staging buffers,
  the unfreed `d_coef`, pool reuse, witness rows held past the openings) —
  `ZK60_HIDING_COMMITMENT_ON_DEVICE_DISPOSITION.md`. **N/A** for a CPU
  statement; it must say CPU.
- **Sealing in advance** (D8, D11, D18 option B): out of scope for both;
  joining two finished runs stays forbidden (D12a).
- **Real weights:** out. The real checkpoint's first-residual range is
  unmeasured (P-5), and whether real chains are admissible is unknown (the
  dense synthetic chain needed `Wd` band 1 at 125M).
- **Hidden weights (P3):** the non-linear argument does not carry (NL-7).
- **Soundness** is not part of a privacy statement. The run's ~2^-97.5 (M-2,
  D15) and its 484 MB receipt (M-6) are Victor's pending rulings.
- **The frozen-seam development rung** may appear in no privacy statement
  (D19a / T-2).

### 2.6 The run composition disposition's §3 table (2026-09-20 17:58), row by row

`ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md:154-162`. Every row moved.

| Row (line) | Then (dev shape / 125M) | Now | Why / evidence |
|---|---|---|---|
| All-zero input (156) | done / **not tested — blocking (R-4)** | dev done; 125M: one block proves and verifies, two-block zero run captured and gated; twelve-block zero run not run | lane stage 19 task 9; S19-F1 disposition §6; round 9 |
| Per-commitment lemma, G-R1 (157) | owed from the start / owed | core accepted with S-1…S-6 at both; measured at 125M on two-block runs; GS-2/4/5/11/12 left | shaped lemma disposition (2026-09-20 23:27); round 9 |
| Gate constructs preimages (158) | boundaries and endpoints; `A`, `H` skipped / nothing | all commitments, masking layer and a joint run assignment at dev shapes (rounds 7, 8) and at 125M, 28 at 10 / 5 / 4 / 9 (rounds 9, 9c) | multi-block disposition §2b |
| Slot closures, G-R2 (159) | 23 of 23 machine-checked; owed as a reading / nothing | read, holds with changes; C-3/C-4/C-7 built; terminal identity 46 of 46 at 125M; GS-13 algebraic half closed | slot closures disposition; lane stage 24; round 9; NL-1 |
| Joint law (160) | reduction accepted, conditional on G-R1, G-R2, G-R4, G-R5 / plus R-4, R-6 | still a reduction; R-4 closed, R-6 taken (S-4); G-R1, G-R2 narrowed; G-R4 counted and machine-asserted on single blocks; G-R5 written | rows above; H disposition |
| Cross-role independence, G-R4 (161) | to be machine-asserted (R-3) / same | seven assertions live on single-block proofs at six shapes (not 125M, not a run); J-1 places the independence in the first hop | lane stage 36; J disposition |
| Hash layer and lift (162) | computed for what a receipt opens; G-R5 unwritten / nothing | G-R5 written (H^run, Route A^run), core accepted with changes; at 125M 2,304 opened columns authenticated, 27,828 challenges re-derived; G-H1 (Route B) open; D19b pending | H disposition (2026-09-21 01:12); round 9 |

## 3. The remaining obligations, ranked

Ranked by what blocks a statement soonest. "Blocks" says which of (a) block,
(b) run it stands in front of. Sizes are rough: small = hours of one agent,
medium = a lane stage or a gate round, large = several.

| # | Obligation | What closes it | Size | Depends on | Blocks | Whose |
|---|---|---|---|---|---|---|
| 1 | **D19b — the model behind the tag** | Victor's one line: "D19b yes" (recommended in `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md`) or "no, use prefixes" (then: redo the tag stage, re-measure, re-capture — large) | small for Victor | nothing | a, b | **Victor** |
| 2 | **Integrate the lane** (tip `1ab1498`, stages 36–44 on top of the stage-35 snapshot the integrator has baselined) and re-establish D22's condition 7 there (pre-read P-1…P-4; stages 36–44 need their own condition-7 read, F-7) | the integrator's committed tree; the security owner's re-pin | medium | integrator's queue | a, b (a statement names a tree) | **integrator** + security owner |
| 3 | **A standalone 125M block through the gate** | a capture of a `private-block-m125` receipt (a new lane capture module — the integrator's writer is toy-only), the gate taught the single-block transcript (own `parameters` absorb, two external endpoints, no header or boundary), full arms and controls at 125M; one paragraph writing the hash layer for the standalone tagged block | medium (the two-block 125M full pass took about 21.5 min at 5.5 GB [MEASURED, round 9]) | none; re-take after #2 | a | lane + gate |
| 4 | **A pin set for the shaped path** (condition 7's analogue) | trace the 125M block's and the run's path closure at the integrated tree (the pre-read's §5 method, with file:line edges), pin every file with failing-first tampers (rounds 9f / 9h pattern), including the six writer-only files of R9i.11 item 1 | medium | #2 | a, b | gate + security owner |
| 5 | **Argument leftovers at the shaped layouts** | GS-5 (the reduction at n ≠ Q derived), GS-11 (`M-q`/`M-prox` re-derived or stated as a carried lemma), GS-12 (the activation family at padded positions), GS-4 (record the 125M rank measurement as the observation, or observe it directly): one errata pass on the shaped lemma plus an independent check | small–medium | nothing | a, b | delegated drafter + checker |
| 6 | **G-R4, said exactly** | the security owner states what "the LAW still owed" (NL-8) means after J-1 and stage 36; if it is the measurement: (6a) stage 36's consumption test at 125M as an `#[ignore]`d heavy test (one 125M prove, ~10 GiB) — which also closes the standalone sampler count of §2.2; (6b) J-5's widened assertion 2 at run scope (`11L + 3(L−1)` segments) at rung-K4 L = 3, counted at 125M L = 12; (6c) `endpoint_g::prepare_with_rng` so the endpoint generators are measured in situ (S36-F2; a lane file) | small each | nothing | (6a) a, b; (6b) b | security owner; lane |
| 7 | **The twelve-block gate at 125M, dense and all-zero** | capture both twelve-block runs, run the gate with every arm; the all-zero capture is also the missing twelve-block all-zero run | medium–large compute: bundle about 1.7 GB, about 2–3 h a bundle detached **[MODEL, MINE: linear from L = 2]**; no new tooling expected (tools are shape- and L-driven, shown at L = 2 and 3) | best after #2, so the records pin the integrated tree | b | lane + gate |
| 8 | **The production run driver** | a production caller of `prove_run` implementing M-9 (publish only with the statement written after verification; remove partial directories), H-1 (seal with the witness builder's own pass), `RunWitnessSource` taking the chain at construction, the refusal-reason rule; then its condition-7 read | medium–large | #2 | b | **integrator** |
| 9 | **Lift bookkeeping for the run** | GS-7 mapped onto Route A^run's hops (or the ordering written); the explicit L = 2 hybrid for the position tags built by a checker | small | nothing | b | delegated drafter + checker |
| 10 | **A residual column for the standalone block** | salt guessing, leaf collision, pre-query at the block's own leaf and query counts, and the sampler total (§2.2) | small (COUNTED) | #6a for the measured draw total | a | delegated |
| 11 | **Draft the statement(s), attack them, rule** | the D22 path: a drafter writes `ZK60_PRIVACY_STATEMENT_M125_…`, an independent agent told to assume it wrong attacks it, the security owner rules and records a register entry | medium each | #1–#5, #10 (block); plus #6b, #7–#9 (run) | a, b | security owner |
| 12 | **Not privacy, on Victor's page** | rulings on the run's ~2^-97.5 soundness (M-2 / D15) and the 484 MB receipt deviation (M-6) | small for Victor | nothing | any product claim about (b), not the privacy statement | **Victor** |
| 13 | **Route B (O-4 / G-H1), optional** | a ruling: every item J §3 lists as owed before use has a closing record (the table, J-8 / lane stage 25; the draw-accounting test, stage 36; the errata, 03:29 on 2026-09-21), and no disposition has said whether that makes the sequential-kernel route usable | small (a ruling, perhaps a check) | nothing | neither (a Route-A statement does not need it) | security owner |
| 14 | **Device path, out of scope for a CPU statement** | a keyed device path and the DC-B buffer review | large | #2 | a statement that covers a GPU build | integrator |

## 4. Stale statements found (proposed corrections only — no other file edited)

Each proposal is a dated block to add **beside** the original, never over it.
`MVP_STATUS.md` carries another agent's uncommitted edits and is not touched.

| # | Where | What it says | What is now true | Evidence |
|---|---|---|---|---|
| 1 | `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md:156` | all-zero input at 125M "not tested — blocking (R-4)" | one block proved and verified; two-block zero run captured and gated; twelve-block zero run not run | lane stage 19 task 9; S19-F1 disposition §6; round 9 |
| 2 | same `:157` | per-commitment lemma "owed from the start" at both shapes | core accepted with S-1…S-6; measured at 125M | shaped lemma disposition; round 9 |
| 3 | same `:158` | preimages: `A`, `H` skipped; 125M "nothing" | constructed at every shape incl. 125M; 28 at 10 / 5 / 4 / 9 | rounds 7, 8, 9, 9c |
| 4 | same `:159` | slot closures "owed as a reading"; 125M "nothing" | read (holds with changes); enforcement built; 46 of 46 at 125M | slot closures disposition; lane stage 24; round 9 |
| 5 | same `:160` | joint law conditional on G-R1, G-R2, G-R4, G-R5 "plus R-4 and R-6" | R-4 closed, R-6 taken; G-R5 written | §2.6 above |
| 6 | same `:161` | G-R4 "to be machine-asserted" | asserted on single-block proofs at six shapes (not 125M, not a run) | lane stage 36 |
| 7 | same `:162` | lift for a run "unwritten"; 125M "nothing" | written, core accepted with changes; 125M hash layer measured for what a receipt opens | H disposition; round 9 |
| 8 | `ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md:128` | rung-G "Left: a Rust test pinning the refusal replay order (GS-2)" | pinned on a real dense rung-G capture; replay measured on a rung-K4 boundary; in-situ draw observer since stage 36 | lane stages 23 item 4, 25 W-3, 36 |
| 9 | same `:129` | rung-K4 bytes "are with the gate now" | gated, 28 channels, nothing failed to scale | multi-block disposition round 5 |
| 10 | same `:132-134` | "Still open on the whole path: … G-R4, … G-R2, … G-R5, … GS-13" | G-R2 read; G-R5 written; GS-13 algebraic half closed; G-R4 machine-asserted on single blocks | slot closures, H, NL dispositions; lane stage 36 |
| 11 | `ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md:102-105` | at 125M "nothing has been evaluated on a 125M receipt, and the present tools cannot" | the terminal identity is evaluated on 125M receipts, 46 of 46 (round 9) — the same false-since-2026-09-21 sentence the shaped lemma's row already corrects at `:130` | round 9; round 9g item 2 |
| 12 | `ZK60_NONLINEAR_CHANNEL_SHAPED_DISPOSITION.md:105-108` | NL-8 lists "the hash layer and the sequential lift for runs (G-R5)" as open | G-R5 written and its core accepted with changes; what is open there is G-H1 (Route B), D19b and two bookkeeping items (§3 #9) | H disposition |
| 13 | `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_DISPOSITION.md:77-80` | K-R2: "Until it exists, the independence hypothesis is a hypothesis" (the query-class table) | the code-derived table exists with a test per row (410 kinds, J-8), `ZK60_HASH_FUNCTION_SEPARATION_TABLE.md` on the lane | J disposition J-8; lane stage 25 |
| 14 | same `:140` | Route B "not yet usable: owes K-R1's hop, K-R2's table, K-R3's joint sentence" | K-R2's table done; K-R3's sentence holds with changes (J); J §3's owed list has closing records — whether Route B is now usable is unruled (§3 #13) | J disposition §1, §3, J-8 |
| 15 | `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md:127-138` | the sequential lemma "exists only for field messages … extending it to (field, hash) message pairs is the next paper task" | written and proved with changes 2026-09-21 02:19; the joint sentence 03:22 | K and J dispositions |
| 16 | `ZK60_DECISIONS.md:31` (D12a status) | "paper only, nothing built" | built and measured: runs of 2, 3, 12 blocks at the rung, 2 and 12 at 125M; derived boundary geometry (M-1) | multi-block disposition §2a, §2b |
| 17 | `ZK60_DECISIONS.md:32` (D12b status) | "(3) to be built on the lane" | built: `RunStatement::new` refuses any non-approved interior scale pair; header byte-identical (test pinned) | lane stage 21 item 3 |
| 18 | `ZK60_BLOCK125M_S19F1_DISPOSITION.md:118-126` (§8 "Still to redo") | F-1, R-5, a dense twelve-block 125M run, dense run captures, the gate's ports of slots 08/09 and figures on a non-degenerate witness | all done | lane stage 21 items 1, 3, 4, 5; `m125-run-l12-dense.log`; gate rounds 4, 9 |
| 19 | same `:114-116` (§7 item 4) | "a note is owed against them" | the note was added 2026-09-22 14:47 to the layout disposition (`:38-44`) | layout disposition §2 note |
| 20 | `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md:118-119` (§4 item 3) | the replay-order Rust test as a next step | done (see #8) | lane stage 23 item 4 |
| 21 | `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md:741-751` (§4 "Next steps") | build the run test-first; one two-block 125M run before twelve | done (§2a, §2b of the same page); whether item 1 (the errata pass on R) was done is not recorded there — not claimed here | same page §2a, §2b |
| 22 | `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md:1217, 1578, 1625` | G-R3, the all-zero chain at 125M, "BLOCKING" | closed (see #1) | lane stage 19 task 9; S19-F1 §6 |
| 23 | same `:1608, 1617, 1658` | the H-8 and H-5 tests "owed on the lane"; C-R2 "checked by nothing today" | built; C-R2 is checked | lane stage 24 items 2, 3 |
| 24 | same `:1759-1760` | "Everything at 125M is counted or bounded from the code and nothing has been measured there" | measured at 125M for what a receipt opens | round 9 |
| 25 | `MVP_STATUS.md:184` (privacy table, joint-law row; **another agent's file — propose only**) | "accepted as a reduction; three named gaps being drafted or tested" | G-R2 read; G-R5 written; G-R4 machine-asserted on single blocks; GS-13 algebraic half closed; GS-14 narrowed by the census | §2.1 row 4 |
| 26 | gate branch record `results/zk60_native_run_gate_m125/m125-dense-everything.json`, channel "the boundary scale tags and the one calibration identity" (the text lives in the run gate's channel table) | OPEN: "nothing in the run's privacy section covers the boundary's scale/calibration binding" | R-5 built: a run refuses any interior scale pair but the approved calibration's, bound through the one calibration identity the run absorbs; the grade and reason should cite it | lane stage 21 item 3; D12b(3) |
| 27 | same record, channel "whether a proof attempt produced a receipt" | a run "makes 23 more `ZkRng::from_os` calls … now possibly in stage 12, minutes in" | one generator per run accepted as built (R-2): one fail-closed entropy read before stage 1, plus two endpoints | R-2; J-2; run memo §6.3 |
| 28 | same record, channel "the cross-block joint law beyond the linear rank" | "a composition argument for a run, which is unwritten"; independence "to be machine-asserted elsewhere" | Theorem B written and accepted as a reduction; draw accounting machine-asserted on single blocks | run composition disposition; lane stage 36 |
| 29 | `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md:122-124, 129-131` (the page Victor reads for the pending run rulings) | the run's soundness "[COUNTED; one block measured, the run not built]"; twelve blocks "about 484 MB [COUNTED]" | the run is built and measured: 484,100,736 B (tagged, pre-repair) and 484,107,456 B (dense, post-repair) [MEASURED]; the soundness figure stays COUNTED | multi-block disposition §2b; `m125-run-l12-dense.log` |
| 30 | `ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md:88` | "Open: CS-1 and CS-2 until built (lane stage 40)" | built (§5 of the same page); a pointer to §5 beside §3 would do | same page §5 |

**Count: 30 stale statements** in 13 files (rows 1–7 are the seven rows of
one table; rows 26–28 live in a gate record on the joint-view branch, not in
the main tree).

## 5. What I read, and what I did not

Read in full or in the sections cited: the toy statement; the register rows
D12, D12a, D12b, D17, D18, D19, D19a, D19b, D20–D22; the dispositions named
in the brief plus `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_DISPOSITION.md` and
`ZK60_SLOT_CLOSURES_SHAPED_DISPOSITION.md` (which the §3 table's rows point
to); the rulings page for Victor; `MVP_STATUS.md` (read only); the D22
pre-read's §5–§9; the run memo's §6–§7; the shaped lemma's §7 gap table; the
lane ledger's headings and stages 14, 19, 21, 23–26, 36, 43–44; the gate
ledger's headings and rounds 9g, 9i; the 125M gate record's channel table
(read by a one-line script); the twelve-block dense run log. Not re-derived:
any lemma, count or rank; every figure above is the cited document's unless
labelled [MINE]. Nothing here establishes a privacy property.

Corrections applied on 2026-09-23 at `c60a2ef`, `16af6df` and the commit adding this line (03:16 PDT, a delegated errata editor; each row's evidence re-read first; dated in-place notes, nothing deleted): rows 1–7 (a dated "Status at 2026-09-23" column on the run composition disposition's §3 table), 8–24, 29, 30 — 26 rows in 13 files. Wording kept narrower than proposed in two places: row 8 (GS-2 narrowed, not closed; not run at 125M) and rows 1 / 22 (R-4 / G-R3 no longer blocking — twelve-block all-zero run still not run, so not "closed" for L = 12). Added beyond the list: row 21's item 1 (the errata pass on R) verified done at `26e03ff`; row 22's same stale sentence also at the run memo's §7.4. Not applied: row 25 (`MVP_STATUS.md`, another agent's uncommitted edits — excluded); rows 26–28 (the gate record on `zk60-native-jointview`, under `results/` — excluded); both left for their owners.
