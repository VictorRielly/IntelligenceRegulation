# Independent adversarial privacy review: the trained TinyLlama T32 draft statement and its gate port

Reviewer: an independent Claude Opus 5.5 agent, delegated by the coordinating
session on 2026-10-17. I did not write the draft, the gate tools or the port.
Written 21:06-21:28 UTC on 2026-10-17. Paper only. The one script run here is
the recount (exact integer arithmetic, one thread, under a second). There were
no builds, no proofs and no git writes. Ledger: `PROGRESS.md` beside this file.

**This is not a privacy acceptance.** It advises the security owner. Rulings
are Victor's (`docs/zkmatrix-poc/ZK60_DECISIONS.md`).

Object:
`results/zk60_gate_tinyllama_20261017/PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md`
(the round-3 revision), together with:
- the gate lane's evidence in that directory (called **EV** below);
- the gate port `ops/zkp-mvp/gate-tinyllama/` (frozen v4, `frozen_v4/scripts/`);
- the two native trees:
  - **tree A** = `ops/zkp-mvp/trained-1b-gate/`, which the current bundles were captured from;
  - **tree B** = `results/zk60_1b_native_20261017/r5/frozen-tree/`, the frozen R5 post-port tree that round 4 of the gate is capturing from now.

This page answers draft §10b items 6 and 8: the three arguments re-read at this
layout by someone other than the gate lane, and an independent adversarial
review of the draft and the port.

Labels:
- **[READ]**: a source line or document I (or a helper, re-checked by me) read.
- **[COUNTED]**: exact arithmetic.
- **[MINE]**: my own reading, checked by nobody else.

---

## 0. Verdict, in plain words

**Could the security owner accept the draft once the gate's owed items
close? Not yet. Two things block it beyond the draft's own list. The
mathematics is not one of them.**

**What holds.** I re-read the three arguments at the trained layout: the
per-commitment rank lemma, the joint-law reduction (Theorem B), and the
hash-layer and Fiat-Shamir lift for a run. Each step goes through with the
trained numbers (§2).
- Every residual in the draft's §4 reproduces exactly from the Rust source,
  recounted independently (§3).
- The draw discipline the blinding law needs was re-scanned in tree A and holds.
- I found **nothing that leaks** in the receipts that were measured.
- The draft is careful and honest about what it has not done.

**What blocks it.**

1. **P-1. The tree a statement would have to name has moved under the
   draft.** In the R5 post-port tree, the trained `stack-prove` CLI no longer
   meets two construction rules that the draft's step 4 relies on, and that it
   describes as true:
   - **Ruling H-1:** a production caller seals the endpoints with the witness
     builder's own pass, so an inadmissible input is refused before the run
     header.
   - **Rule M-9 / D12b(1):** `statement/` is written only after the whole run
     verified.

   Tree B seals the endpoints from the export's reference words. It discovers
   builder and parity refusals mid-run, after segments are written. Its
   in-process verification is **off by default**, yet `statement/` is written
   anyway. The draft's description is true of tree A only.
2. **P-2. The ported gate's staged driver records the run-layer source pins
   but never enforces them.** Its status says PASS whenever `ok` is true, and
   `ok` ignores the pins. That is exactly the situation of the R5 re-gate now
   running, where six pinned files differ. A bundle from an unread tree would
   come out ok TRUE / PASS. Fix this before any round-4 record is read.

**The draft's own blockers remain, and I agree with them:**
- G-1: re-gate on the post-port tree.
- G-R4: the root-rebuild check at this tree. I advise against taking the
  "reading suffices" alternative (P-12).
- GN-1 / GS-14: the refusal census at the trained constants.
- G-7: NL-1 and the terminal surjection at the trained slot-IR.

**Then eleven must-fix items, P-3 to P-13.** Most are conditions or
hypotheses the statement must carry and does not yet carry. Some are live in
the CLI:
- the run context comes from a free `--label` (C-R4);
- the public statement binds a `profile.json` that carries held-out sequence
  names and statistics;
- the hidden input and every per-layer activation must sit inside the export
  directory that the verifier also needs;
- refusal text prints hidden-derived counts;
- the CPU-only scope cannot be seen from the artifact;
- the §0 plain-words line drops the word "admissible".

The rest are gate fixes: an export cross-check, a closed capture schema, and
classifier and control-family negatives.

**Wording: nine items, P-14 to P-22.** None moves a figure.

**My answer to the security owner.** Once these are done, I see no obstacle
in the arguments to a statement of the draft's form:
- P-1 is repaired or ruled;
- P-2 is fixed before the R5 re-gate is read;
- the draft's owed items close on tree B;
- P-3 to P-13 are folded in.

That statement would cover pg_rot1 only, on the CPU, for a bound run, with the
figures of §3. It would still be a statement whose steps each survived one
attack. It would not be a proof re-derived by the security owner (the D22
caveat). This page is one reader plus three helpers, not a full drafter /
checker / ruling cycle per argument.

---

## 1. What I did

- **Read:**
  - the lane rules;
  - `ZK60_PRIVACY_REQUIREMENTS.md`;
  - register rows D1, D8/D11, D9, D12, D12a, D12b, D16-D27;
  - the D22 toy statement;
  - the dispositions of:
    - the shaped rank lemma (S-1..S-6);
    - GS-4/5/11/12 (GC-1, GC-2);
    - the run joint law (R-1..R-7);
    - the run hash layer (H-1..H-8);
    - the blinding law (LW-1..LW-4);
    - the shaped refusal census (CS-1..CS-9);
  - the parts of `ZK60_GENERIC_RANK_LEMMA_SHAPED.md`,
    `ZK60_JOINT_LAW_COMPOSITION_RUN.md` and `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md`
    that carry shape constants or conditions;
  - the draft;
  - the gate ledger's results and round-4 entries;
  - the pass-F, arms and status records.
- **Three read-only helper agents (no builds, no writes outside a scratch
  folder):**
  1. an attack on the v4 port, including the status classifier;
  2. a reading of trees A and B for verifier-visible channels;
  3. an independent recount of §4 from the Rust source.

  Every load-bearing claim I take from them I re-checked in the source myself:
  - tree B's `stack-prove`;
  - the staged driver's pin handling and the PASS rule;
  - the LogUp inversion order;
  - the SiLU-registry door;
  - `prove_run` = `prove_run_with(SliceBlocks)`;
  - the export's `profile.json`;
  - the context derivation.

  See `PROGRESS.md` 21:22.
- **Recount evidence:** `recount/recount.py` (the helper's script, copied
  here) and `recount/recount.out` (re-run by me, exit 0, under 1 s). It
  reproduces D22's 327,052 toy draws before computing anything trained.

---

## 2. The three arguments at the trained layout (task 1)

### 2.1 The per-commitment rank lemma (G-R1: Lemma S, S-1..S-6, GS-4/5/11/12)

| Step | At the trained layout | State |
|---|---|---|
| S-1 `log(Dom::Tab) == log_cols` | 12 = 12 (tables of 256 rows lifted to the row width) | holds [READ, the draft's prediction] |
| T9: every `H` plane on a domain of log ≥ `log_cols` | D 16, F 18, Kv 13, Q 16, S 15 from the shape's dimensions; L and Tab lifted to 12 | holds [MINE] — corroborated by the measured `H` disclosure 2 = the public LogUp identity |
| T4: generators vs non-data rows | `A`: G = 36, 74 generators on 242 non-data rows (slack 168). `H`: G = 9, 20 generators; 49 reserved site pairs and the proximity pair (98 + 2 mask rows, after the zero-sum pair at rows 1,696-1,697), measured rank full. Boundary: 6 on 6, zero slack, the determinant identity `∏Norm(λ·cm)·wedge(prox)` (no Schwartz-Zippel needed). Endpoint: 4 on 5, the spare row | holds; measured 74 of 74, 6 of 6 [READ, EV] |
| H-pad for **every** opened-column set | Closed form `E_j[pad k] = Z_n(x_j)·x_j^k` with `x_j = 7·w_nn^j`, at `(n, nn) = (2^12, 2^14)`. `Z_n(x_j) ≠ 0` at every encoded position because `(7^4096)^4 ≠ 1 mod p`; the nodes are distinct, so the pad block has full rank on any ≤ 256 distinct columns. The same holds for `M` at `(2^9, 2^12)` | **holds for every column set**, not only the captured ones [COUNTED, mine; one line of Python] |
| GS-5: `disclosed = n·k0 + u*` at n ≠ Q | n = 4096, Q = 256; derived for any n, Q under GC-1's hypothesis (the proximity pair independent, refused otherwise) | holds [READ] |
| GS-11: `M` geometry | 50 rows; largest `L_s` = 19·5 + 2 = 97; 97 + 256 ≤ 512 (C-4 refusal) | holds [COUNTED] |
| GS-4: exclusivity | 16 of 16 clauses on every commitment at L = 1, 2, 22 | measured [READ, EV] |
| GS-12 | Holds, and the draft understates it (P-15): tree A's door makes every layer's `act` equal a frozen SiLU member, and every member has `act[128] = round(silu(0)) = 0`. Its privacy stake at this layout is liveness, not disclosure | holds |

**Verdict:** Lemma S carries to the trained layout verbatim, with the counts
above. No new argument is needed.

### 2.2 Theorem B (the joint-law reduction, with G-R2 and G-R4)

- **(H2), the mask identity: shape-free.**
  - 23 slots, 317 rounds, Σ `L_s` = 979 `Fp2` [COUNTED, recount].
  - Only slot 18 gains the indicator degree, because F is the one padded
    indicator domain.
- **(H3), `M`'s opening: holds.** `M`'s geometry is unchanged and its budget
  fits.
- **(H4) / G-R2, the slot closures.**
  - The trained relations differ from the 125M ones by **non-zero** public
    constants. The declared classes have lower bounds ≥ 1 on `tn`, `Cn_a`,
    `Cn_m`, `Ceps`, and every `2^sh` is ≥ 1, all far below p. So no monomial
    loses its public table factor, and the premise "a public factor in every
    monomial" is untouched.
  - The per-layer exp and SiLU tables are `Tab::Pub`, fixed by the layer
    manifests and checked at the door (tree A `trained_block.rs:805-816`);
    nothing is computed at proof time [READ].
  - The machine check (NL-1's `nl_check.py`) and the terminal surjection at
    the trained slot-IR are still owed (G-7). I agree.
- **G-7, the duplicate lookups, is low risk.**
  - Four `H` helper planes are duplicated: Q helper 1, Kv helpers 1 and 3, F
    helper 0 (`layout.rs:712, 749-768`) [READ].
  - Lookup counts are fixed, so rows, claims and terminals are unchanged.
  - Two terminals equal for every witness is a witness-independent identity
    and cannot carry data. I expect NL-1 to pass, but the machine check is the
    rule.
- **The run factorisation holds.**
  - There is no run-wide masking commitment.
  - The boundary's 6×6 system is block-triangular.
  - R-5 holds: only `(0, 0)` scale pairs are accepted (tree A `run.rs:269-273`,
    `trained_statement.rs:584-586`) [READ].
  - There is one OS-seeded generator per run plus one per endpoint, carrying a
    role byte. No seeded generator is reachable from the CLI [READ].
- **R-1 / H-1 (refusals in a run).** Tree A's CLI satisfies them. **Tree B's
  does not (P-1).**
- **G-R4, the draw discipline, re-scanned independently in tree A [READ,
  recount helper; spot-checked by me].**
  - Every generator draw loops over bounds fixed by shape, layout, spec, `k`
    and `L`, with no zero-skip, early exit or retry.
  - The new prover paths draw nothing: `pcs/encode_buffer.rs`,
    `sumcheck/rounds.rs`, `sumcheck/grouped.rs`, `masked_prove_rounds` and
    slot 17's grouped evaluator.
  - Pads and salts are drawn **before** the CPU/CUDA offer
    (`zkp-core/src/pcs.rs:774-781`), so the two paths draw identically.
  - No refusal after the first draw reads a drawn value, except through the
    challenges (the S-4 event).

  This is a second reading that agrees with the draft's [MINE]. **A reading
  still cannot see a copied blinding value (P-12).**

**Verdict:** the reduction carries. Its open conditions are G-R2 (the NL-1
re-run) and G-R4 (the root-rebuild check).

### 2.3 Lemma H^run and Route A^run (the hash layer and the lift)

- **Counts [COUNTED, twice independently].**
  - `N_leaf` = 69,632 / 122,880 / 1,187,840 at L = 1 / 2 / 22.
  - `A`, `H`, boundaries and endpoints have 16,384 leaves each (depth 14);
    `M` has 4,096 (depth 12).
  - Opened columns are 256·(4L + 1) = 1,280 / 2,304 / 22,784, which the gate
    re-hashes under the derived keys.
- **Step 1 (opened leaves are a public function of V and the salts) and
  step 3 (inner nodes): unchanged code paths.** Measured by the gate's
  re-authentication of every opened column.
- **N4 (the tag): rests on D19b, accepted.**
- **N5 / condition C-R1 (no 40-byte input to the unkeyed function F_U):
  holds [MINE].** The trained path adds:
  - the stack context, ≥ 8 + 37 + 8 + 1 + 8 + 1 + 8 = 71 bytes
    (`trained_block.rs:1517-1527`);
  - the trained-statement identity, which is **SHA-256** and so outside BLAKE3
    entirely.

  The run public statement is 29 + 32L ≠ 40. **The draft does not carry the
  condition (P-3).**
- **N6 / C-R2 (no transcript domain of length 35): holds.** Constructor inputs
  are 78 (run) and 70 (block), neither 47. H-8's test is present.
- **N7 (tag-key collisions): the row's `m` is now larger than 12.** The s24
  test pins every registered profile's keys pairwise distinct, so the row is
  zero by test. The draft mislabels the row (P-16).
- **N8 / C-R4 (the context is a statement constant): live (P-3).**
- **C-R5 (no unkeyed device path): holds.** `commit_zk_device` is not called
  from `private_block` [READ]. The keyed device path of G-6 is a different
  question, scoped out by "CPU only".
- **§5.1, the game:** the published object is the run directory with
  `statement/` written after verification. Tree B breaks this (P-1).

**Verdict:** the lemma and the lift carry with these counts. Conditions C-R1,
C-R4 and C-R5 must be carried.

---

## 3. Residuals, recomputed (task 1)

Recounted from the Rust source by a script that shares no code with the
lane's (`recount/`).

**Per-block draws: 2,329,764 [COUNTED].**

| Role | Draws |
|---|---:|
| `A` mask rows | 991,232 |
| `A` pads | 442,624 |
| `M` CFS masks | 1,958 |
| `M` row pads | 11,776 |
| `M` b and u polynomials | 4,096 |
| `H` mask rows | 409,600 |
| `H` zero-sum pair (drawn once, not re-drawn) | 8,190 |
| `H` pads | 460,288 |

Per boundary 30,208; per endpoint 25,856 [COUNTED].

| Term | L = 1 | L = 2 | L = 22 | Draft |
|---|---|---|---|---|
| draws | 2,381,476 | 4,741,448 | 51,940,888 | equal |
| sampler (D9) | 2^-74.82 | 2^-73.82 | 2^-70.37 | equal |
| S-4 one-world / two-world | 2^-118.42 / 2^-117.42 | 2^-117.42 / 2^-116.42 | 2^-113.96 / 2^-112.96 | equal |
| salt guessing (q = 2^128) | 2^-111.91 | 2^-111.09 | 2^-107.82 | equal |
| leaf collision | 2^-224.83 | 2^-223.19 | 2^-216.64 | equal |
| challenge pre-query (A bounded) | 2^-115.47 | 2^-114.48 | 2^-111.03 | equal (0.17 bit conservative against the measured A) |
| transcript-input collision | 2^-231.93 | 2^-229.95 | 2^-223.05 | equal |
| **constructor vs absorb, B10: (A + q)·2^-256** | **2^-128.00** | **2^-128.00** | **2^-128.00** | **missing** (P-16) |
| tag-key collision C(m,2)·2^-256 | ≤ 2^-246 for m up to ~40; zero by test | | | **mislabelled**: the draft's 2^-252.4 is the generator-key row 3·4·2^-256 (P-16) |
| liveness (3L+1)/p | 2^-62.00 | 2^-61.19 | 2^-57.93 | equal; one base-field determinant per opening (RUN.md:1282's "four per opening" is wording) |
| total distance | 2^-74.82 | 2^-73.82 | 2^-70.37 | equal |

Notes on the table:
- The S-4 bound of 768 distinct arguments per block holds at this profile.
  - The only inversions are the byte table, the exp and act lookups, and the
    three table helpers.
  - RoPE tables are public and never inverted.
  - The scaled top-limb lookups are byte-table columns.

  All [READ].
- **The total equals the sampler term**: the next term is 37 bits below it.

---

## 4. Findings

Severity scale:
- **blocking**: acceptance is impossible even after the draft's own owed list
  closes, unless this is repaired or ruled;
- **must-fix**: a repair to the statement, its conditions or the tools that is
  required before acceptance;
- **wording**: text only, no figure moves.

### P-1 — BLOCKING. The R5 post-port tree's `stack-prove` breaks ruling H-1's sealing rule and M-9 / D12b(1)

**Location.**
- Draft §3 step 4, "R-1/H-1 and M-9", describes tree A: sealing pass
  `trained_block.rs:1671-1693`, then `create_dir(&out)` :1706, verification
  :1738, `statement/` :1739.
- Tree B: `results/zk60_1b_native_20261017/r5/frozen-tree/hashline/src/private_block/trained_block.rs`:
  - :1951-1980, round-3 change R3-1: "the endpoints are sealed from the
    export's own words (layer 0's x_in, the last layer's x_out)". Every
    witness is built once, in the proving pass, with parity checked there.
  - :2001 and :2005: on failure, `let _ = std::fs::remove_dir_all(&out)`.
  - :2016-2019, round-5 change R5-2: in-process verification "OFF by
    default"; :2038 then writes `statement/` regardless.
  - The doc comment at :1885 still describes the old sealing pass.

**Why it matters.**
- **H-1 (`ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md`).** The rule: "the
  pass that seals the endpoints is the witness builder's own, with its
  refusals, so an inadmissible chain is refused before the header". In tree B
  the output endpoint is sealed from the Python reference's `x_out`. A builder
  refusal or parity failure at block k now happens after the header and after
  segments 0..k−1 are on disk. That re-opens R-1's channel: which block
  refused is a function of the hidden input. Only the best-effort removal and
  M-9 stand against it, and the removal's error is ignored.
- **M-9 / D12b(1), and D21's "a receipt the prover's own final check
  rejected is never transmitted".** Both assume `statement/` means "the whole
  run verified". In tree B, by default, it means only "the prover finished".
  - Theorem B and Lemma H^run are quantified over **accepted** runs.
  - A non-verifying directory with a statement is outside every statement
    (RUN.md N13).
  - The fresh-process `stack-verify` is the only check, and nothing ties
    publication to it.

**Minimal repair (either one):**
- **(a) Code.**
  - Make `statement/` conditional on a passing verification: in process, or
    have `stack-verify` write the statement or a verified marker.
  - Restore a builder-sealing pass before the header, or seal from the
    builder's output when it is available.
  - Make removal of a failed directory fail loudly.
- **(b) A security-owner ruling.** Amend H-1 for this caller (M-9 as the only
  line, with removal mandatory and checked, and stdout prover-private, P-6).
  Amend M-9's marker to "publishable only after a fresh-process `stack-verify`
  passed on this directory". The statement's §5 and §6 then print the amended
  rules.

The draft's step-4 text must describe the tree the statement names.

### P-2 — BLOCKING for the round-4 re-gate records. The staged gate driver does not enforce source pins, and PASS ignores unexplained false leaves

**Location (frozen v4).**
- `zk60_native_rg_m125.py:192-195` stores `check_run_layer_pins()` (or the
  block-layer pins) in the record.
- That function computes a `suspended` stage map (`zk60_native_rg_runpins.py`,
  `check_run_layer_pins`, the lines after `ok = not moved and not missing`),
  which the driver never uses.
- `:376-380` computes `ok` over `stage*` keys only.
- `zk60_native_rg_status.py:207-208` returns PASS whenever `ok is True`. Pass F
  is PASS with 1 unexplained leaf (CH-6 `fires: false`).
- Shared-file pins, including the TinyLlama `SHARED_ALSO_READ` readings, never
  suspend a stage (`zk60_native_rg_runpins.py:1022-1043`, `:1150`).
- G-2's three prover files are in no v4 pin table. The post-v4 live edit
  checks them only "when a bundle pins one".
- The monolithic `zk60_native_run_gate.py:1392-1395` does suspend, but no
  record of record comes from it.

**Why it matters.** Every trained record of record comes from the staged
driver. The R5 re-gate captures from a tree in which six pinned files
changed. A bundle written by an unread `run.rs`, `run_capture.rs` or
`boundary.rs` would get ok TRUE / PASS / exit 0. Today's three checked records
do have `run_layer_source_pins.ok` true, so no existing figure is affected.

**Minimal repair.**
- In the staged driver, suspend the affected stages (`G.not_checked()`) or
  fold the pins' `ok` into `rec["ok"]`.
- Give PASS only when `unexplained == []`.
- Treat a missing G-2 pin as a refusal.
- Re-run the rung-K4 equivalence; no figure should move.

### P-3 — must-fix. The run hash-layer argument's conditions C-R1, C-R4 and C-R5 are not carried, and C-R4 is live in the CLI

**Location.**
- Draft §5 and §6. Its condition table carries the toy's seven and H-8 (C-R2),
  but not C-R1, C-R4 or C-R5 (RUN.md §7.2).
- The CLI context is `stack_context(variant, layers, label)` with `--label`
  free (tree A `trained_block.rs:1517-1527`, :1639). It is published as
  `context_label` and `context` in `statement.json` (:1561) and absorbed via
  `expected.bin`.

**Why it matters.** If a deployment derives the label from the request or the
input, the two worlds no longer share a statement, and the sentence's
quantifier collapses (toy O-1/O-B, run C-R4).

**Repair.** Add three conditions:
- **C-R1:** no 40-byte F_U input. Note the trained additions: the context is
  ≥ 71 B and the trained identity is SHA-256.
- **C-R4:** the context label is a deployment constant, never derived from a
  request or a hidden input. Better, the CLI accepts only an allow-listed
  label.
- **C-R5:** no tagged commitment on an unkeyed device path.

### P-4 — must-fix. The public statement binds calibration-time data: the hypothesis that the export is independent of the input is missing

**Location.**
- The trained statement identity binds `profile.json`'s SHA-256 (tree A
  `trained_block.rs:917`, `trained_statement.rs`). The run absorbs that
  identity as its calibration word, and it is published.
- `pg_rot1_export_T32/profile.json` (sha256 `b25ba5f5…`) carries:
  - `"sequences": ["seq_ho00","seq_ho01"]`;
  - `fidelity_T` aggregates over the 36 held-out sequences;
  - per-layer float scales.
- The export README says the proved sequences were chosen as held-out ones
  accepted at every layer [READ].
- D24 F-6: one profile string covers a family of calibrations.

**Why it matters.**
- For this evidence it is harmless: the data is public.
- As a statement it is not. If the export were re-written per input (to
  obtain the per-layer reference activations the CLI's parity needs, P-5), or
  if an operator chose among calibrations per input (for instance, a fallback
  when an input is inadmissible under pg_rot1), the public statement identity
  would be a function of the hidden input. The same holds if a production
  input were ever in the calibration or held-out set whose statistics
  `profile.json` carries. This is the calibration analogue of R-5 and C-R4.

**Repair.** Add a hypothesis and operating rule:
- the export (`profile.json`, the layer manifests, every file whose digest
  enters the trained statement) and the context are fixed before, and
  independently of, any hidden input;
- no hidden input is in the calibration or held-out set;
- no input is retried under another calibration or label.

### P-5 — must-fix. The hidden input and all per-layer activations live inside the export directory the verifier also needs

**Location.** `TrainedExport::load_seq` reads
`<export>/seq_<id>/x_in_LNN.bin`, `x_out_LNN.bin`, and an optional
`manifest.json` carrying their SHA-256s (tree A `trained_block.rs:875-905`;
the same in tree B). `stack-prove --seq ID` requires them for every layer (the
parity reference). `stack-verify` rebuilds the statement from the same
directory's public files (:1761). The module doc calls `seq_*` PRIVATE (:17).

**Why it matters.** Shipping "the export" as a directory ships every hidden
plane of the run. A sequence manifest's SHA-256s would allow dictionary tests
on low-entropy prompts. This is a D21-class hazard that nothing in the
statement names.

**Repair.**
- Code (preferred): take the hidden input and the parity reference from a
  separate prover-private path, and have `stack-verify` refuse an export
  directory that contains `seq_*`.
- Or an operating rule in §6: the verifier's copy of the export contains no
  `seq_*` directory, and none is ever published.

### P-6 — must-fix. Refusal and diagnostic text carries hidden-derived values; the draft under-describes it

**Location.**
- Tree A `trained_block.rs:1688` (tree B :1709, :1075): the parity refusal
  prints the **number** of differing words and the token and channel of the
  first difference.
- Witness-build refusals print the block index and the failing check.
- Per-segment stdout events (index, elapsed time, memory) show how far a run
  got. In tree B these come after the header.
- The draft §6 says "names the layer and a token/channel position (no value)"
  and omits the count.

**Why it matters.** Ruling K-2 (census disposition §8) dropped exactly such
hidden-derived counts from CS-3's message. D21 forbids showing refusal
reasons to anyone not entitled to the input.

**Repair.**
- Drop the count and position from the parity message, naming the layer at
  most.
- Add an operating rule beside P-2's `HL_PB_*` rule: `stack-prove`'s
  stdout/stderr from a run on a hidden input is prover-private, never
  retained in a published log or capture.
- Correct the draft §6.

### P-7 — must-fix. The CPU-only scope cannot be audited from the artifact

**Location.**
- `statement.json` carries only the fixed scope text "CPU unless the run line
  says gpu" (tree A :1600).
- The backend appears only on stdout (`run_header`, `loaded.hl_gpu`,
  `proved.gpu`, `gpu_declines`).
- CPU and CUDA paths draw identically and produce receipts of the same form
  (`pcs.rs:774-781`), so a verifier cannot tell them apart.
- The native lane runs GPU stacks at this profile.

**Repair.**
- Record the backend in `statement.json`, or name the deployment binary
  (built without `gpu-cuda`) by digest in the statement's conditions.
- Until then, "CPU only, by configuration" is an operating rule in §6, not a
  scope fact in §1.

### P-8 — must-fix. §0 drops "admissible", and "admissible" is never defined for this profile

**Location.** Draft §0, first bullet: "Whether the prover refuses depends on
the input only through a residual of about 2^-113."

**Why it matters.**
- This is false for an inadmissible input, which is refused with certainty
  (in tree B, mid-run). §2 has the qualifier, but §0 is the line the owner
  reads.
- At the trained profile, admissibility is a non-trivial data-dependent
  predicate: the trained door, the witness builder's refusal sites at these
  constants, and bit-exact parity against the Python reference at every
  layer.
- A missing receipt discloses that bit to anyone who expected one. RUN.md
  §5.2 says the refusal fact is outside every statement.

**Repair.**
- Add "for an admissible input" to §0.
- Define admissibility concretely as the CLI's admission predicate.
- Say in §2 and §8 that the refusal fact is outside the statement.

### P-9 — must-fix (gate). Calibration constants and tables come only from the prover-written bundle

**Location.**
- `zk60_native_rg_terminals.py` `Calibration` (:687-725) reads
  `run.json["shape"]`.
- `zk60_native_rg_replay.py:133` absorbs the calibration digest without
  checking what it is a digest of.
- The parameter line is absorbed but never compared with `sh_g` / `sh_h` /
  `sh_z`.
- Per-layer table digests and `act[128]` are recorded only
  (`terminals.py:2299-2310`).
- The export is never read.

**Why it matters.** The scope sentence names pg_rot1 (statement identity
`68ad19c8…`), but the evidence's attribution to pg_rot1 rests on the writer.
A run proved consistently under different constants would pass. In passes
with no stage 8 (pass F, the arms passes) the constants are not exercised at
all.

**Repair.** Add an `--export` (or `--expect-statement`) cross-check, refusing
by name, on:
- the constants;
- the statement identity;
- the per-layer exp and SiLU digests;
- `act[128] = 0`;
- `exp[0] = 2^f_e`.

### P-10 — must-fix (gate). Nothing checks a capture for extra, possibly private, material

**Location.** `Stage.__init__` and `RunBundle` accept unknown keys
(`zk60_native_rg_bundle.py:243-269`). `ArrayStore`
(`zk60_native_rg_arrays.py:173-334`) never checks that the references cover
`arrays.bin`. The `ALLOWED_KEYS` allow-list is a Rust writer-side test only.

**Why it matters.** D21 counts a retained capture as publishing, and these
bundles are retained.
- The helper measured the L1-dense and L2-zero bundles as fully covered, with
  verifier-only key sets.
- The 22-block bundles were not measured.
- The constructions themselves read only verifier-visible fields [READ].

**Repair.**
- Add a closed key schema to the loader.
- Require the union of referenced ranges to equal `[0, size)`.
- Run it over all six bundles on disk (the 22-block ones under the guard's
  `light` class).

### P-11 — must-fix (gate). Gaps in the status classifier and the control families; the draft's test claim is false

**Location.**
- `zk60_native_rg_status.py:68, 77`: `false_leaves` catches only exact
  `False`, so a `null` or missing `ok` passes both the driver (`is not False`,
  m125.py:378) and the status.
- `:147`: rule (a) matches any top-level `…/controls/ok`.
- ARMS-ONLY requires no particular set of stages.
- `tests/test_v4_status_g10.py` tests 3 of 9 conjuncts of the mask arm and 4
  of about 17 of the joint arm. Draft §10a says "a negative for every
  recomputed condition".
- `zk60_native_rg_m125controls.py`: M9-3 turns exceptions into `None` and
  drops the domain (:242-245), returns ok with no domain left (:286-287), and
  is omitted unnamed without a plane index (:296-297).
- The P family and the one-block C family have no non-empty guard.
- CH-6 is always skipped in the staged driver (`legacy_bundle=None`,
  m125.py:314-315).
- CT can never pass there (`old=None`, m125.py:211). That is why every
  "everything" record exits 1 (fail-closed).
- A declared/derived `data_rows` mismatch is recorded, not refused
  (`zk60_native_rg_pcs.py:242-249`).

**What I checked by hand, with the helper.** The 22-block all-zero
ARMS-ONLY verdict is legitimate:
- the 7 false leaves are all explained;
- every recomputed conjunct of the stage-12 and stage-13 arms is true;
- no non-bool `ok`;
- no stage raised.

The record was taken with tools v3, so its stage 1 lacks the G-10 check;
`v4/integrity-inert.json` covers it.

**Repair.**
- Add the missing negatives.
- Restrict rule (a) to `CONTROL_FAMILIES`.
- Require stages 1-3 and the arm stages for ARMS-ONLY, and flag any
  non-bool `ok`.
- Add non-empty guards, stop swallowing exceptions in M9-3, and name every
  omitted control.
- Supply a legacy bundle to CH-6, refuse a `data_rows` mismatch other than
  the zero-sum rows, and correct §10a.

### P-12 — must-fix. G-R4 needs its machine check at this tree; do not take the "reading suffices" alternative

**Location.** Draft §3 step 4 OWED, and §10b item 4 ("or a ruling that the
reading suffices").

**Why it matters.**
- Ruling R-3's counterexample shows that "joint = sum" and the draw count
  cannot see a copied blinding value. So does LW-2: mutations m1, m2 and m4
  passed every count, sum and receipt check and were caught only by the
  root-rebuild check.
- The trained tree has new prover paths (`encode_buffer`, the grouped
  evaluators, the backend offer). That is exactly where such a copy could
  enter.
- Two readings now agree on the draw discipline (§2.2), which is good, but a
  reading is the wrong instrument for this class.

**Repair.**
- Port `gr4_check_tests.rs` (lane stage 47) to tree B and run it at the
  trained shape on one block and one two-block boundary, with the endpoints
  in situ.
- Carry LW-4's note (`CfsMask: Clone`, `CommittedZk` with `pub` fields)
  forward to this tree.

### P-13 — must-fix (already owed; one part can be closed by reading). GN-1 / GS-14 at the trained constants; CS-2 and CS-5 can be ruled unnecessary

**Location.** Draft §3 step 4 OWED, §5 row S, §10b items 1 and 5.

**Reading [READ].** The trained shape passes no window overrides
(`shape.rs:1287-1307`).
- The door refuses a norm-window override (`:1196-1200`).
- `check_trained_class` requires `norm_wrho` and `wrho_s` to equal their
  derived values (32 and 14) exactly (`:1238-1246`), re-checked in
  `Layout::for_shape` (`layout.rs:1080-1082`).
- Width is capped at `TRAINED_WIDTH_MAX = 4096` (`shape.rs:82`) in both trees.

So CS-2's concern (an undersized window makes the honest proof fail on some
inputs) and CS-5's (width above 16,384) cannot arise at trained profiles. The
security owner can rule them unnecessary there on these lines, instead of
porting them.

**Still owed.** The census itself, at these constants: a builder-admitted
input never meets any refusal other than S-4.
- In tree B, CS-3 turns a lookup miss into a prover refusal, after `B_k` and
  earlier segments.
- With P-1 that refusal is mid-run, covered only by M-9.

### P-14 — wording. The LogUp "whether" claim holds, for a different reason than D22 §9 item 10 gives

**Location.** Draft §4, "[MINE; to be checked with G-1]".

**Reading [READ].** Tree A `protocol.rs`:
- the challenges are drawn at :901-903;
- the byte table is inverted at :912, which never refuses;
- the witness-side byte helpers, `exp_den` and `act_den` follow (:913-934);
- the **three whole tables** are inverted only at :958-967.

So D22's reason, "the prover inverts the whole of each table before
multiplicities enter", does not transcribe. The conclusion holds anyway:
- for every builder-admitted witness, every witness-side argument is a table
  row (byte ranges; exp keys checked in 0..256 at `witness.rs:643-653`; act
  keys `g8 + 128`);
- the whole tables are inverted on every attempt that reaches :958;
- nothing is absorbed or drawn in between;
- the message is identical (:477, :484).

Which line returns first, and the time taken, depend on the witness; that is
out of scope under D20. Tree B has the same order, plus CS-3 earlier.

**Repair.** Replace the [MINE] with this reading.

### P-15 — wording. GS-12 / G-8 is both overstated and understated

**Overstated.** "The closure holds for this export, not as an enforced
invariant." In tree A the door requires every layer's `act` to equal a frozen
SiLU member (`trained_block.rs:813-816`). `int16out_generate` gives
`act[128] = round(silu(0)) = 0` for every member. So the closure is enforced
for every export the door admits, apart from R2-a's out-of-door shape, which
the CLI cannot reach.

**Understated.** The draft never says what is at stake. A padded F position
carries the constant pair (128, 0). If `act[128] ≠ 0`, every proof fails
verification **for every input**, and S-4's set gains one public argument. It
is a liveness question, not a disclosure channel.

### P-16 — wording. The residual table

- Add B10 (constructor vs absorb), `(A + q)·2^-256 = 2^-128.00`.
- Split "tag-key collision" into two rows:
  - `C(m,2)·2^-256` at today's `m`, zero by the s24 all-profile test;
  - the generator-key row `3·4·2^-256 = 2^-252.4`, which is the value the
    draft printed.
- "A million runs (2^20)" repeats H-7's conflation. Either write "2^20 runs",
  or give 10^6: 2^-54.89 / 2^-53.89 / 2^-50.44.
- The L = 1 column is not in the cited `run_hash_counts_tinyllama.json`, which
  computes L = 2 and 22 only. Add it, or cite `recount/`.
- `H`'s "50 claims" are 49 reserved site pairs plus the pairless LogUp sum
  claim.
- The zero-sum pair is drawn once, inside `H`'s data rows; it is not
  "re-drawn".

### P-17 — wording. Stale or overstated sentences

- §0: "with every per-stage and per-boundary control family firing in the
  same pass". CT, GQ and M9-3 did not run at L = 22 (§3 says so).
- §10b item 1: the R5 suite is stale. `r5-suite2` was GREEN at 19:48 UTC
  (688 passed, 0 failed, CS-6's test included), and the tree was frozen at
  19:48:50 (`d67fae7e…`), per the native ledger lines 1091-1100.
- §10a, the G-11 row: the test claim is false (P-11).
- Pass F's status is PASS with 1 unexplained leaf (CH-6), not 0.

### P-18 — wording (recommended). The evidence path is not the CLI path

The bundles come from a test harness: `run_capture_tests.rs:2085-2215`, with
the `TrainedChain` witness source, `prove_run` and `new_bound`. The CLI uses
`StackSource`; in tree B also `prove_run_with(CacheBlocks)` and
`new_bound_from_digests`.
- In tree B, `prove_run` = `prove_run_with(SliceBlocks)` and `new_bound` =
  the CS-1/CS-4 checks + `new_bound_from_digests` (`run.rs:301-330, 833-835`).
- So the prover core is shared; only the block and witness sources differ.

Record that equivalence in the statement. Better, capture once through the
CLI's path, as D22 did on 2026-09-22 with the integrator's binary.

### P-19 — wording. Coverage over L and the layer range

The CLI accepts any contiguous `--layers A..B`. The statement gives figures
at L = 1, 2 and 22, with evidence at layers {0}, {7, 8} and {0..21}.

**Repair.** State the formula: draws = 2,329,764·L + 30,208·(L−1) + 51,712.
Say which ranges are covered; I recommend the full 22-layer stack, with L = 1
and 2 as diagnostics.

### P-20 — wording (recommended). No per-layer table control at L = 22

The TL controls ran at L = 1 and 2, on layers 0, 7 and 8. Over 22 layers
there are 2 distinct exp tables and 7 SiLU members. Nothing shows that the
22-layer terminal identity (506 of 506) would fail if one layer read another
layer's table.

**Repair.** Add one cheap control at L = 22, or say so.

### P-21 — wording (minor tool). The G-10 repair is narrower than the block check it copies

`zk60_native_rg_bundle.py:651-699` checks both roots, row counts,
`opened_at_stage` and the policy fields. It does not check three things that
`block_integrity` does (`zk60_native_rg_block.py:721-729, :813`):
- `external_endpoints.data_rows`;
- the endpoint `log_n` / `inv_rate`;
- scales `== (0, 0)`.

A missing key raises a `KeyError`, which fails closed as NOT-OK but not as a
named finding. The risk is low: 21 rows plus EX-1 pin the data rows at 16.

**Repair.** Add the three comparisons, and report a missing key as a named
finding.

### P-22 — wording. The per-run D9 figure should be in front of Victor

D9 was accepted with the figures "2^-75 tiny, 2^-72.9 125M, about 2^-72 at
8B" per proof. This statement has 2^-70.37 per 22-block run, and about
2^-50.4 at a million runs. The 125M run memo printed its million-run figure
as "a product fact for the project owner".

**Repair.** Print the per-run and million-run figures beside the statement on
the owner's page. This is not a new ruling unless the owner wants one.

---

## 5. Checked and found sound (so nobody re-does it)

**The arguments and counts:**
- the three arguments' shape-dependent steps at the trained layout (§2);
- every §4 figure, to the draw (§3);
- H-pad for every column set (§2.1);
- the boundary and endpoint geometry: 22 = 16 + 2·2 + 2, and 21 = 16 + 5;
- the windows derived and refused otherwise (P-13);
- R-5 (0, 0).

**The code, tree A:**
- one OS generator per run plus one per endpoint (role byte); no seeded
  generator reachable from the CLI;
- segment lengths fixed by the shape and position (`wire.rs:340-356`).
  Measured: 250,855,088 B for both the dense and the all-zero 22-block runs;
- every `statement.json` field is public, apart from the P-3 and P-4
  hypotheses;
- tree A's CLI: sealing pass, verification before `statement/`, the witness
  source takes the input at construction.

**The gate:**
- the preimage and joint constructions read only verifier-visible fields;
- the 22-block all-zero ARMS-ONLY verdict;
- CT-5's "first padded domain" generalisation fails closed (F in slot 18);
- C1-C4 are named NOT APPLICABLE at L = 1;
- G10-1..G10-4 restore their perturbations and require a finding naming G-10;
- `Calibration` refuses a mixed trained/frozen shape;
- the TL controls show the terminal identity is not vacuous in the constants;
- the hash layer's `continue` branches record findings, and its `ok` needs
  every column authenticated.

## 6. Evidence

- `recount/recount.py` (exact; reproduces D22's 327,052 first) and
  `recount/recount.out` (re-run 2026-10-17 ~21:22 UTC, exit 0).
- The source lines cited in each finding, in tree A, tree B and
  `ops/zkp-mvp/gate-tinyllama/frozen_v4/scripts/`. The live `scripts/` copy
  was being edited for round 4 during this review, so the line numbers are
  frozen v4's.
- The gate records read:
  - `EV/v4/tl-l22-dense-f.json` and `.status.json`;
  - `EV/l22/tl-l22r2-zero-arms.status.json`;
  - `EV/l22/capture-l22-*.log`;
  - `EV/l2/witness_comparison_tl_dense_vs_zero.json`.
- The export file read:
  `results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32/profile.json`,
  sha256 `b25ba5f5…` (checked).
