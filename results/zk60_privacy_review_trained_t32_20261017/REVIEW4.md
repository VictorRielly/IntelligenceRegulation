# Independent adversarial privacy review, round 4: D33's re-pin onto frozen-r7, and the next-token statement draft

Reviewer: the same independent Claude Opus 5.5 agent as rounds 1–3 (`REVIEW.md`,
`REVIEW2.md`, `REVIEW3.md`). I did not write the re-pin note, the draft, the
gate tools, or the native or token code.
- Opened 2026-10-20 00:01 UTC; written 00:01–00:15 UTC.
- Paper only, plus short read-only `python3 -I` checks: no builds, proofs,
  git writes or jobs.
- One read-only helper read the token code for part (B); I re-checked every
  load-bearing claim I take from it in the source.
- The ledger is `PROGRESS.md`, section ROUND 4.

**This is not a privacy acceptance.** It advises the security owner. Rulings
are Victor's.

**Objects** (hashes checked):
- (A) `results/zk60_gate_tinyllama_20261017/tk7/ZK60_PRIVACY_STATEMENT_REPIN_TK7_20261019.md`
  (`9958e548…`);
- (B) `results/zk60_gate_tinyllama_20261017/round9/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT.md`
  (`abccfc64…`);
- D33 in force: `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TRAINED_TINYLLAMA_T32.md`
  (`ded3f0e7…`).

---

## 0. Verdicts, in plain words

**(A) The re-pin note: YES.** It meets D33's condition 7 and the D22 precedent
at `4751b93`, and it exceeds that precedent. The security owner can lift the
step-3 suspension for frozen-r7, provided the decision names three things
(PR4-1):
- frozen-r7's 52 pins, with both hashes kept;
- the CPU binary the statement then covers;
- that two items are carried by reading, as D33 already carries one of them:
  - the capture-and-gate through the CLI path (P-18);
  - the 22-block pass F.

I agree with both carries.

**(B) The next-token draft: NOT YET.** I found nothing in the receipts that
leaks, and its residual figures recount exactly. But seven items must close
before the security owner could accept it (§2.7, PR4-12).

**F-T1 is wider than the draft says.** The token command-line prover has no
block sealing pass at all. It takes the output token from the export's Python
reference, and builds every block witness during the proving pass: builder
refusals, parity and CS-3 all come after the run header. That is the pattern
round 1 called P-1 for the trained CLI, and it breaks ruling H-1 (PR4-4).
The privacy sentence survives, because "admissible" includes those checks
and a refused run publishes nothing. But D29 does not transfer, and the
draft describes the test harness's path, not the CLI's.

**F-T2 is priced correctly**, and conservatively. It needs the security
owner's D30-(4)-style note (PR4-5).

**Still missing, as D33 required:**
- the terminal surjection on the 15 new slots (PR4-7);
- the root-rebuild replay of the token stages (PR4-8);
- the b4 calibration attribution (PR4-9);
- a named binary, with one capture through the CLI's path (PR4-10).

**Two deployment items:**
- the CLI's silent removal, and a killed run's leftovers (PR4-15);
- the owners' decommitments stored beside the captures directory (PR4-16).

The other owed items can carry, as §2.5 explains.

---

## 1. (A) The re-pin onto frozen-r7

### 1.1 What the precedent requires

D33 §5 condition 7 says: "the gates' source pins; a change suspends step 3".
D33's acceptance header gives the procedure: "until the changed functions on
this profile's path are re-read and the pins are moved with both hashes kept
(a gate re-pin round)".

The D22 precedent at `4751b93` (`ZK60_SECURITY_PROBE_REPIN_20260922.md` and
D22's notes of 2026-09-20 21:28 / 22:06 / 23:57) asked for three things:
- the changed functions on the profile's path re-read;
- the pins moved with both hashes kept, and a failing-first refusal of the
  new digest;
- the gates re-run, with every figure of record unchanged.

D22 lifted its suspension **without** gating a receipt made by the new
binary. That receipt came two days later, and "this replay extends nothing".

### 1.2 What the note shows, checked

- **The changed set** [checked by me].
  - frozen-r7 differs from R7 in exactly the five files D33's header names:
    `run.rs`, `shape.rs`, `trained_statement.rs`, `trained_block.rs` and
    `private_block.rs`.
  - Byte-identical to R7 (sha256 equal): every prover / verifier-relation
    file (`protocol.rs`, `argument.rs`, `layout.rs`, `boundary.rs`,
    `endpoint_g.rs`, `witness.rs`, `pad.rs`, `wire.rs`) and all of
    `zkp-core/src`.
  - The capture writer `run_capture.rs` differs too, and is `#[cfg(test)]`.
  - The six token files are new, and not on the block path.
- **The re-read** [the note's, and mine: I read every code hunk of the five
  diffs]. At an export whose `per_layer_constants_differ` names none of R8's
  eleven fields (pg_rot1_export_T32: `[exp_e_s, silu_member]`, checked),
  every R8 change is the identity:
  - **run.rs:** `stage_cal[k]` is the run's `norm_calibration()` for every
    k. So `stage_shape(k)` returns the run shape, and the schedule-line loop
    adds no clause. The new refusal of a token-I/O profile in a blocks-only
    statement is public. `token: None` is in the `#[cfg(test)]` capture
    header.
  - **shape.rs:** `with_layer_calibration` is reached only through `has_own`
    or `with_score_shift`, never at this export.
  - **trained_statement.rs:** the identity encoder writes an own field only
    when it is `Some`, and every layer's `own` is `[None; 11]`. So the
    identity bytes are R7's; the gate recomputes L22 identity `68ad19c8…`.
  - **trained_block.rs:** `per_layer_cal_fields()` is empty, so `masked` is
    the identity, `own_of` is all `None`, `ssh = sh.clone()` and the
    statement rendering adds no own field. The rest is `fn` →
    `pub(crate) fn`.
  - **private_block.rs:** `mod token_io`, the token CLI re-exports and a
    `#[cfg(test)]` module.
  - No block-path function calls into `token_io`.
- **Both hashes kept, and failing-first.**
  - Tools v11 accept the tk7 digests in addition to R7's, and the merge
    refuses to replace a digest it already holds.
  - Frozen v10 refuses tk7's `run.rs` and `run_capture.rs` by name and
    suspends every stage (`probe_before_repin/`).
  - frozen_v11 equals its manifest (60 of 60, checked), and every tk7 queue
    ran under it ("60 listed, 0 moved, 0 unlisted").
- **The gate re-run, on fresh captures from the new tree.** This is more
  than D22 did: D22 re-ran its gates on the old captures.
  - 10 of 10 tk7 records are PASS, with 0 unexplained leaves.
  - I compared them with their R7 twins record by record (`tk7-summary.json`
    against `r7-summary.json`). Equal: replay counts, hash counts, terminal
    identity (23 / 46 / 506), channels, mask entries recomputed, joint
    couplings, preimage leaves, export / stage verdicts.
  - Prediction validation 6 of 6. Controls: pin controls 12 of 12, TL 15 and
    18, G-10 8 of 8; schema ok.
- **Stage 47, the root-rebuild check.** All five tests pass on the tk7 copy:
  block dense and zero, boundary, and the L = 2 run dense and zero.
- **The CLI, exercised** [checked]. The tk7 binary (`dac7fc73…`) sealed
  before the header, a fresh `stack-verify` published the statement, and the
  identity is `ef061000…`.
  - Its published `statement.json` and R7's P-18 statement each have 52
    leaves.
  - **Only `/expected_io` differs**, and that field carries fresh endpoint
    roots (compared by me, field by field).
  - The receipt has the same length: 23,019,088 B.

### 1.3 The two carries

- **The 22-block pass F.**
  - D33 already carries it, from R5b by reading.
  - The files whose code computes what pass F checks are byte-identical
    R7 → frozen-r7: the PCS, masks, slot arguments, layout and boundaries.
  - The tk7 pass A at L = 22 re-derives every challenge and the run binding
    on tk7 bytes, with terminal identity 506 / 506 on both inputs.
  - **Acceptable**, on the same footing as D33.
- **P-18's capture and gate.**
  - The CLI functions R8 changed (`run_constants`, `load_layer`, the stack
    loop, `stack_records`) are the identity at this export, by my reading
    above.
  - The prover core (`prove_run_with`, `protocol.rs`) is unchanged.
  - The tk7 CLI run reproduces R7's published statement in every field but
    the fresh roots.
  - The precedent did not require a receipt from the new binary.
  - **Acceptable.** Capturing the existing run directory
    `~/zk60-artifacts/tinyllama-cli-tk7-run-l2/` with the P-18 capture test
    would close it by evidence in about a minute (PR4-2, optional).

### 1.4 Findings on (A)

- **PR4-1 (must be stated in the decision).** The lift must name:
  - **frozen-r7's 52 pins**, keeping R7's 46. Condition 7 then holds two pin
    sets, each read.
  - **The CPU binary.** D33 names `e51cc6a4…` (R7). A deployment on
    frozen-r7 runs `dac7fc73…`.

    The note says that binary was built in the gate copy's path and "a
    rebuild elsewhere need not give the same bytes". So the statement either
    names `dac7fc73…` exactly, or the native/token lane builds and names its
    own CPU `zk60_trained_block` from frozen-r7. The decision says which.
  - **That pass F and P-18's capture are carried by reading** (§1.3).
- **PR4-2 (optional).** Capture and gate the existing tk7 CLI run directory
  (P-18's test, about a minute).
- **PR4-3 (wording, the note).**
  - "Soundness … R8 accepted (r8) … its object is native R8 without the
    token files." The token files' code review (REVIEW5) still had no
    verdict at 00:12 UTC. The token files are off the block path, so this
    does not bear on (A). The lift should still say that frozen-r7's token
    files are unreviewed for soundness.
  - "Report-only" pins (`trained_statement.rs`, `trained_block.rs`,
    `private_block.rs`): condition 7 is met by the re-read, not by a port.
    The note says so, and that is fine.

---

## 2. (B) The next-token statement draft

### 2.1 What holds

- **The residuals recount exactly** [COUNTED, mine].
  - **Draws per run:** 2,329,764·L + 30,208·(L + 1) + 709,664 + 5,632 =
    3,105,476 / 5,465,448 / 52,664,888.
    - The token endpoints add 2 × (5·256 + 6·256) = 5,632.
    - The block run's two external endpoints are replaced by B_in and
      B_out, which is why the boundary term counts L + 1.
  - **Sampler:** 2^-74.43 / 2^-73.62 / 2^-70.35.
  - **Leaves:** 147,456 / 200,704 / 1,265,664, from
    2·16,384·L + 16,384·(L + 1) + 4·16,384 + 4,096·(L + 2) + 2·2,048. Salt
    guessing 2^-110.83 / 2^-110.39 / 2^-107.73.
  - **Liveness:** (3L + 7)/p = 2^-60.68 / 2^-60.30 / 2^-57.81.
  - **Refusal term:** 2·(768L + 32 + 256)/p² = 2^-116.96 / 2^-116.17 /
    2^-112.93.
  - The controls K-1 and K-2 (block stage 2,329,764; boundary 30,208) hold
    on every capture.
  - The stage IN / OUT draw counts (91,744 / 617,920) use the validated
    per-commitment formula with the captures' mask budgets (Σ L_s 177 and
    481 implied). I did not recount those budgets from the slot specs.
- **The new commitments' linear view.** The draft's one [MINE] at step 2 is
  "the lemma's coverage of a 2^8 endpoint with one site … not read by a
  reviewer". I read it, and it holds:
  - the token endpoint has 5 non-data rows against 2(G + 1) = 4 generators,
    with the spare row as at the block endpoint;
  - the pad-rank closed form holds at (n, nn) = (2^8, 2^11): (7^256)^8 ≠ 1
    mod p, checked;
  - G-6 measures disclosed 0, with a full-rank pad block on 231–245 distinct
    columns.
- **C-R1 / C-R2 for the token absorbs** (owed as a reading in the draft's
  step 5). They hold [MINE]:
  - every unkeyed BLAKE3 input on the token path is public, and at least
    96 B: the public statement, calibration word, schedule, profile,
    embedding and head digests (`token_io/run.rs:292-308, 397`;
    `token_io.rs:512-566`);
  - the token run-profile constructor is 98 B, not 47.
- **The owner model** matches DESIGN §3.4: each decommitment is handed
  privately and is never published, and each endpoint is opened once.

### 2.2 F-T1: CS-3 runs only mid-run in a token run

**Fact [READ, mine].** In frozen-r7, `check_lookup_misses` is called only by
the trained stack CLI's sealing pass (`trained_block.rs:2089`). The CS-3
refusal in `prove_core` (`protocol.rs:987`) is the only other site. No file
under `token_io/` calls either before the header.

**Does it break a claim?**
- **The privacy sentence: no.**
  - CS-3 is a deterministic function of the witness, so including it in
    "admissible", as the draft does, keeps the §2 clause true for
    admissible prompts.
  - A refused attempt publishes nothing, provided the sink contract holds
    (§2.6).
- **But it breaks two things D33 and its register rely on.**
  - **Ruling H-1, the production-caller rule.** "The pass that seals the
    endpoints is the witness builder's own, with its refusals, so an
    inadmissible chain is refused before the header." Since R6, CS-3 is
    part of that predicate (N-r5-a), and the token CLI is a production
    caller of a run.
  - **D29**, which made the census a completeness item because "every
    refusal … happens before anything is published", with the explicit
    clause "reopen if any refusal can occur after the run header". D29
    therefore does not transfer to the token profile as things stand.

**F-T1 is wider at the token CLI than the draft says [READ, mine and the
helper's].** The token CLI's `prove_inner` (`token_io/cli.rs:474-553`) has
**no block sealing pass at all**.
- **What it seals before the header:**
  - stage IN's id / BOS checks;
  - B_in from the embedded prompt, required to equal the export's
    `x_in_L00`;
  - **the output token from the export's Python reference**: the last
    layer's `x_out` row T−1, through `out_values` (`cli.rs:500-517`).
- **What it does only during the proving pass** (`CliSource::witness`,
  `cli.rs:299-312`, called at `token_io/run.rs:790`, after the header at
  `:747` and after earlier segments are written to `<out>.incomplete/`):
  - builds each block's witness for the first time;
  - with the builder's refusals (raw text, `:302`);
  - a block output outside int16 (`:303`);
  - parity against the export (`:305-306`);
  - CS-3, inside `prove_core`.

This is the R5 pattern that round 1 called P-1 (BLOCKING) for the trained
CLI, and that R5b repaired. The draft's §2 and §3 step 4 ("the honest
pipeline builds every witness first … `token_io/run.rs:1009-1072`")
describe `honest_pipeline_at`. The gate's captures in fact use
`stream_pipeline` (`capture_tests.rs:318-345, 400`). Neither is the CLI's
path.

**PR4-4 (must-fix; code preferred).** Make the token CLI seal its chain with
the witness builder's own pass, **before the header**:
- every block witness built with its refusals;
- `protocol::check_lookup_misses` (CS-3) on each;
- parity at every layer;
- the output token taken from the builder's chain, not from the export's
  reference.

This is R5b's P-1 repair (a), plus R6's N-r5-a. Then:
- H-1 holds by code;
- D29's reading transfers;
- "every refusal of an inadmissible prompt happens before the header" can be
  claimed;
- only the token stages' challenge-dependent LogUp refusals (F-T2) stay
  post-header.

The alternative is a security-owner ruling that the sink contract is the
publication barrier for token runs and that D29 extends on that basis. That
is weaker: the barrier's removal is silent (PR4-15), and the CLI path has
never been gated (PR4-10). Either way, the draft's §2 "Admissible" and §3
step 4 must describe the CLI's path, not the harness's.

### 2.3 F-T2: the token stages' input-dependent LogUp refusal

**Facts [READ, mine].**
- **Stage IN** (`stage_in.rs:326-346`):
  - after B_in, A_in and M_in are committed and β, α, γ and r_emb drawn,
    the prover inverts `α − q_t` for each prompt position;
  - `q_t = tok[t] + β·⟨emb row t, eq(r_emb)⟩ + γ_emb`, which for an honest
    witness equals the τ row `τ_tab[tok[t]]`;
  - it then inverts `α − τ_tab[v]` only for rows with non-zero
    multiplicity, the same set of rows.
  - So the refusal event is "α ∈ {τ_tab[v] : v an id of this prompt}":
    at most T = 32 distinct arguments per world, and they depend on the
    hidden ids.
- **Stage OUT** (`stage_out.rs:571-578, 701-712`):
  - the byte helpers invert `α − (x + γ_u8)` for each looked byte;
  - the table column inverts only byte rows with a non-zero histogram;
  - at most 256 distinct arguments.
- Nothing is absorbed or drawn between the challenge draw and these lines.
  The refusal text is the constant "zero LogUp denominator; discard
  attempt".

**Is the accounting right? Yes.**
- The discharge is d(view_w, view_0) ≤ Pr_w[E_w] + Pr_0[E_0] + (the
  non-refused distance).
- It holds whether or not the event depends on the input. Here the factor
  2 is needed, not just conservative: the events differ between the worlds.
- Per world, Pr ≤ (768L + 32 + 256)/p². The blocks' 768L part is
  challenge-only and is counted the same way, conservatively.
- If stage IN's witness-side and table-side arguments could differ (a
  union of 2T), the figure would move by 0.05 bit (2^-116.91). By the code
  they cannot: there is no position tag, and q_t = τ(tok_t).
- The figure is an upper bound with slack. τ(BOS) and the byte values 0 and
  127 occur in every world, and both worlds' stage-OUT sets lie in one
  256-element set. The tight figure is about 2^-117.14 at L = 1 [helper's
  count]. The draft's 2^-116.96 is safe to keep.
- Its 768L block part is challenge-only **because** CS-3 admits every block
  witness. That premise holds by `prove_core`'s CS-3 (`protocol.rs:987`).
- There is no retry loop. A "discard attempt" ends the process, and a re-run
  is a fresh process with a fresh stream and fresh endpoint roots.

**Compared with D30 condition (4).** D30 made the same move for DD:
- an input-dependent LogUp refusal priced as a two-world distance term,
  2·L·(768 + rows·cap)/p²;
- with the explicit words "replaces D22 §9 item 10's challenge-only
  sentence for this profile".

D30 additionally required inverting every dictionary slot on every attempt.
That fixes the count of inversions, so the bound C = rows·cap holds
uniformly and the work does not vary with usage. For the token stages, the
per-world bound (≤ T, ≤ 256) already holds without a fixed count. A varying
number of inversions is a timing difference only (D20).

The draft's §2 wording ("up to 2^-116.96 … a function of the challenges
and public tables alone") is the form D22 itself first used for an
input-dependent class.

**PR4-5 (must-fix by ruling, not code).** The security owner records, for
the token profile, a D30-(4)-style note:
- the token stages' refusal is input-dependent;
- it is priced at 2·(768L + T + 256)/p²;
- it replaces D33's challenge-only refusal sentence for this profile.

Inverting the whole τ table (32,768 rows) and byte table on every attempt
would make the refusal challenge-only, but at 2·(768L + 32,768 + 256)/p² =
2^-111.96 (L = 1). That buys nothing the statement uses, because the refusal
fact is outside it. I do not recommend the code change.

### 2.4 The τ table and the head fold (F-T3)

**Not a privacy gap.**
- NL-1's premise needs the two tables to be public. They are: the verifier
  computes them from the embedding and head the statement names by digest
  (T-3, `token_io/run.rs:290-308`) and from the replayed challenges.
- The captured tables are what the production verifier computed under the
  recorder. REVIEW5 §2.3: "the recorder sees only what `verify_token_run`
  hands it".

**What is missing is attribution and fidelity**: that the tables fold the
named embedding and head. That belongs with PR4-9.

**PR4-6 (wording, optional evidence).** Say this in §3 step 3. Optionally,
re-fold τ in the gate from the export's embedding at the replayed
(r_emb, β, γ). That is 32,768 × 2,048 field products, feasible offline;
the head fold is the same size.

### 2.5 The owed list: which items must close before acceptance

- **PR4-7 (must). NL-1's S3 / S4 / S5 and the terminal surjection on the 15
  new slots.**
  - This is D33's G-7, which was a closing item there.
  - The joint-law reduction (G-R2) rests on these slots' terminal maps
    being onto.
  - S1 alone (premises) is not that.
- **PR4-8 (must). The stage-47 root-rebuild replay for the token stages.**
  - Scope: stage IN, stage OUT and B_in on one seeded stream, with the
    first block stage between them (an L = 1 token run). The endpoints are
    checked in situ.
  - This is D33's P-12 / Q-6.
  - The token stages are new prover code drawing on the run's single
    stream (`token_io/run.rs:744-815`; `stage_in.rs:303-362`;
    `stage_out.rs:672-727`). That is exactly where a copied-blinding
    mutation could enter, and no count or sum check can see one.
- **PR4-9 (must, narrowed). The block layer at `pg_rot1_b4_T32_cal128`.**
  - **Must: the calibration attribution.** Recompute the token run's
    absorbed calibration word from the b4 export and the named embedding
    and head files, and compare. That is the trained identity, plus the
    token-profile digest. This is D33's E1–E4 (P-9) for this profile.
    X1–X10 compare the export against the token header and the layout
    description; they do not do this.
  - **Can carry**, if the owner records it:
    - The calibration-sensitive block controls ran at b4 and fire: NC-1
      (`sh_z` moved, fails exactly at slot 14), NC-2 (the frozen-calibration
      fallback fails exactly at 2, 14, 15, 16, 18), NC-3 (the cross-check)
      and NC-4 (a per-layer table swap).
    - The remaining families (CT, GQ, P, M, X, C, CH, M9, the pin controls,
      G-10) are calibration-independent tool controls. They were exercised
      on the same block shape and tools at pg_rot1.
    - The token run's own integrity controls (TC-1..TC-12, J-1..J-3) fire on
      all ten captures.
  - **The alternative** the draft names (token inputs and captures at
    D33's calibration, extending D33) removes this item altogether.
- **PR4-10 (must). A named CPU token binary, and one capture through the
  token CLI's own path.**
  - A capture needs **no CLI hooks**. As D33's P-18 did, a test can read the
    CLI's run directory and run `verify_token_run` on it with the recorder
    attached; the recorder sees only what the verifier hands it.
  - This is the one piece of evidence that exercises the token CLI's sink
    contract and publication path, which F-T1 / PR4-4 and the "accepted"
    rule depend on.
- **PR4-11 (should, before acceptance). The token tree's code-review verdict
  (REVIEW5).**
  - Still a placeholder at 00:12 UTC.
  - Soundness is not this statement's subject. But D33 was accepted only
    after its tree was accepted on soundness (r7), and the same order is
    right here.
  - An integrated tree is not required: a frozen copy with its 52 pins is
    condition 7's object, as for D33.

### 2.6 The token CLI's publication surface, and the sink contract

**What already matches D33's repairs** [READ; helper, re-checked by me where
cited]:
- the C-R4 label allow-list (`cli.rs:85, 109-115`, re-checked on read);
- the Q-2 backend allow-list, checked before writing and on read
  (`:520-521`);
- P-5: the verifier refuses an export holding `seq_*`, and the prover
  accepts `--seq-dir`;
- M-9 / r5_A:
  - `prove` writes only `<out>.unverified-statement/`;
  - `verify` writes `<out>/statement/` itself, from its own rendering and
    the verified bytes' hashes, and removes the prover's copy;
  - the writer label is unauthenticated, as N-r6-a says;
- refusal texts carry no counts or values;
- segment lengths are counted from the statement;
- the statement's only hidden-dependent fields are the two endpoint roots.

**Findings.**

- **PR4-15 (must-fix). Silent removal, and leftovers after a kill.**
  - On an error, `Claimed::drop` removes the incomplete, unverified and
    owner directories with `let _ = remove_dir_all` (`cli.rs:448-453`). A
    failure is ignored.
  - On SIGKILL, a MemoryMax OOM or a power loss, nothing is removed. A
    partial attempt's segments stay in `<out>.incomplete/`, a sibling of
    `<out>`.
  - D33 relies on R5b's "a failed removal is reported loudly".
  - Repair:
    - report a failed removal loudly, as R8's `fail_run` does;
    - make the next `prove` to the same `--out` refuse by name while a
      stale `<out>.incomplete/` exists;
    - add the operating rule: never sync a run's parent directory while a
      `.incomplete` sibling exists.
- **PR4-16 (must-fix, operating rule). The owners' decommitments sit beside
  the captures.**
  - The default owner base is `$HOME/zk60-artifacts/token-io/`
    (`cli.rs:366`). That directory today holds both `captures/` (which the
    draft cites as the evidence location) and five `*.owner-private`
    directories, checked.
  - Shipping that tree to share captures ships both owners'
    decommitments.
  - Delivery to the owners is not implemented, so both decommitments sit
    together on the prover host.
  - Repair:
    - an operating rule (the owner base is never shipped, and captures live
      elsewhere);
    - preferably, a default owner base outside every artifacts tree.
- **PR4-17 (wording / operating rule).**
  - `--prompt` takes the hidden prompt on the command line (`cli.rs:271`),
    where it is visible in local process listings and shell history.
  - `owner` prints the next token on its stdout.
  - Both are host-local, not in the verifier's view. §6 should name them
    (use the sequence manifest, and keep owner output private).

### 2.7 What must close before acceptance (closed list)

**PR4-12.**
1. **PR4-4:** the token CLI seals with the builder's own pass, including
   CS-3 and parity, before the header; or the security owner's ruling, as
   §2.2 describes.
2. **PR4-5:** the security owner's D30-(4)-style note pricing the token
   stages' input-dependent refusal at 2·(768L + T + 256)/p².
3. **PR4-7:** NL-1 S3–S5 and the terminal surjection on the 15 new slots.
4. **PR4-8:** the stage-47 root-rebuild replay of the token stages.
5. **PR4-9 (narrowed):** the b4 calibration attribution (the absorbed
   calibration word recomputed from the export and the named tables), with
   the owner's note carrying the calibration-independent block controls. Or
   token captures at D33's calibration instead.
6. **PR4-10:** a named CPU token binary, and one capture through the token
   CLI's own path. The capture needs no CLI hooks.
7. **PR4-15 and PR4-16:** loud removal and leftover refusal, and the owner
   base kept off any shipped tree; plus the draft's text on R-1 / H-1 and
   "Admissible" describing the CLI path (PR4-4).

**Should, before acceptance:** PR4-11, the REVIEW5 verdict.

**Wording:** PR4-6, PR4-13, PR4-14, PR4-17.

**Not on the list:**
- the residual figures, which are right;
- C-R1 / C-R2, which hold by my reading;
- the token endpoint's rank lemma, which holds;
- an integrated tree, as for D33.

### 2.8 Other findings on (B)

- **PR4-13 (wording). The owners.**
  - The sentence covers a verifier "neither the input owner nor the output
    owner".
  - It should also say that it claims **nothing** about what an output
    owner who is not the input owner learns about the prompt beyond the
    token. DESIGN §3.4 puts each owner outside the adversary for its own
    endpoint only.
  - In the usual deployment the two owners are one party, and then nothing
    is at stake.
- **PR4-14 (wording).**
  - §4's "An H re-draws its zero-sum pair" repeats round 1's P-16: the pair
    is drawn once, inside H's data rows. The arithmetic is right.
  - §3 step 5's "C-R1 and C-R2 are to be re-read" can cite §2.1 above.

---

## 3. Evidence (this round)

**(A)**
- The note, `EV/tk7/` (`tk7-summary.json`, `probe_before_repin/`,
  `gr4-*.log`, `cli/`, the `*.toolcheck` files).
- `EV/r7/r7-summary.json`.
- `EV/gate-tinyllama.tools.frozen.v11.sha256` (`7459dfdc…`) against
  `ops/zkp-mvp/gate-tinyllama/frozen_v11/` (60 of 60).
- The diffs of R7 `frozen-tree/hashline/src/{private_block.rs,
  private_block/{run,shape,trained_statement,trained_block}.rs}` against
  `results/zk60_token_io_r1_20261017/frozen-r7/`, plus sha256 equality of
  the other block files and of `zkp-core/src`.
- `~/zk60-artifacts/tinyllama-cli-{r7,tk7}-run-l2/statement/statement.json`,
  compared field by field.
- `results/zk60_d24_review_20261017/R8_VERDICT.md`.

**(B)**
- The draft.
- `EV/token_io/TOKEN_GATE_REPORT_T32_v10.md` (`bcd01bb4…`), §2.1, §2.3, §3,
  §4, §5.
- `EV/round9/token_run_counts.{py,L1L2.json,L22.json}`.
- frozen-r7, under `hashline/src/private_block/token_io/`:
  - `stage_in.rs:300-365`;
  - `stage_out.rs:560-580, 696-716`;
  - `run.rs:286-312, 397-405, 684-705`;
  - `cli.rs:15-70, 268-274, 360-395, 440-460, 470-560`;
  - `capture_tests.rs:318, 400`;
  - `token_io.rs:508-566`.
- frozen-r7 `protocol.rs:439-502, 987` (the CS-3 sites).
- `results/zk60_token_io_design_20261017/DESIGN.md` §3.4.
- `docs/zkmatrix-poc/ZK60_DECISIONS.md` D29, D30, D33.
- `results/zk60_token_io_review_r1_20261017/REVIEW5.md` (no verdict yet).
- The listing of `/home/victor/zk60-artifacts/token-io/`.
- The helper's full report is summarised in the findings above. Its line
  citations were spot-checked by me where a finding rests on them.
