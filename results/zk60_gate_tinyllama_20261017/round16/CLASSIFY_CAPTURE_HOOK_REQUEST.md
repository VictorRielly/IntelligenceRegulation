# Capture-hook request: classifier run captures for the privacy gate (gate round 16)

From the PRIVACY GATE lane to the token-I/O lane, through the coordinator,
on 2026-10-21. It is in the form of round 7's request
(`EV/token_io/CAPTURE_HOOK_REQUEST.md`). **This is a request, not a ruling
or an acceptance.**

**Tree read:** the token lane's working copy `ops/zkp-mvp/token-io/hashline/`
at manifest_r12B (list sha256 edbffc75…), the rung R-C1. The files:

- `token_io/classify.rs` dd319552…;
- `token_io/classify_run.rs` 56fcccef…;
- `token_io/stage_in_c.rs` 7bc3c30b…;
- `token_io/stage_out_c.rs` 46cb6951…;
- `run_capture.rs` aaff4e6e…, unchanged since frozen-r7.

## 1. Why the gate is blocked [READ]

The token run is capturable since round 7. The classifier run records
nothing, for three reasons.

1. **`verify_classify_run_with`** (`classify_run.rs:224-300`) has **no
   recording calls**:
   - no `run_capture::stage_begin_stage` / `stage_end`;
   - no `run_accepted`;
   - no `checkpoint` + `pcs(Geom{…})` around the boundary openings
     (`classify_run.rs:277`).

   `ClassifyRunStatement` has no `capture_header()`. The token run has all
   of these: `token_io/run.rs:902`, `:921`, `:980`, `:988`.
2. **Stages IN-C and OUT-C record nothing.**
   - Their `run_slots` (`stage_in_c.rs:238-244`, `stage_out_c.rs:429-436`)
     do not call `run_capture::start_slot` before `run_stage_slot`, as
     `stage_out.rs:550` does. So the slot hook inside `run_stage_slot`
     (`token_io.rs:950`, `:1067`) never fires.
   - Their `verify` calls a bare `mask_verify_tagged` and bare
     `pcs::verify_zk_tagged`, for A, H, the input endpoint and B_out
     (`stage_in_c.rs:421-429`, `stage_out_c.rs:679-694`). Neither carries the
     `checkpoint` + `mask` / `pcs` wrapper of `stage_out.rs:808-862`.
3. **There is no `capture_planes`** for IN-C or OUT-C, and no schema string
   for a classifier bundle.

So none of the gate's items can be measured on a classifier receipt: the
rank lemma per commitment, the CFS of IN-C / OUT-C, the joint pass, NL-1 on
the 12 classifier slots, and the margin slot's terminal identity.

## 2. What is asked (the token lane's write set; every hook a no-op unless a capture is active)

No receipt byte and no transcript byte moves. The pinned files change
additively.

### 2.1 `run_capture.rs`

- **(a) `RunHeader` gains `classify: Option<ClassifyFacts>`**, serialised
  under a new top-level key `"classify"` in `run.json`. It holds every public
  word the classifier header absorbs that a token run's does not, in absorb
  order (`classify.rs:866-881`):
  - the run-shape words: L, T, d, hidden, q_heads, kv_heads, head_dim, V,
    P0, n, S;
  - the profile's canonical text (`describe_under`) and its digest
    (`digest_under`);
  - **the policy**: id, the prefix ids, the suffix ids, `num_special`,
    yes / no ids, **c**, the tokenizer string and the template digest;
  - **the margin vector's digest `w_digest`** and its length d. The vector
    itself is a public table of slot OUTC-03, which (c) records;
  - the embedding digest; BOS; the final-norm constants (g0, cn, tn, ceps),
    wrho, D_max, the margin window and the limb count;
  - the tier (as `TokenFacts`);
  - the input endpoint's spec (rows, data rows, sites, site rows, proximity
    row, log_n, rate, words) and its root;
  - B_in's and B_out's `BoundaryFacts`;
  - **the verdict b**;
  - **the ChunkRef**: index, count, a, b, total, size, overlap.

  `begin_run_with` rebuilds the classifier header transcript from it
  (`ClassifyRunStatement::transcript`) and compares it with the binding, as
  for token runs. The transcript label list (`transcript_labels`) must show
  `classify-verdict` and `classify-chunk` as the header's last two absorbs.
  The gate checks this (its control MC-7).
- **(b) `stage_begin_stage(k, kind, …)`** with `kind` ∈ {`"IN-C"`,
  `"BLOCK"`, `"OUT-C"`}, and a `StagePlanes::Stage` for each new stage
  (`stage_in_c::capture_planes`, `stage_out_c::capture_planes`, as
  `stage_out.rs:872-885`). These give:
  - the A / H plane names in plane order: IN-C {A_TOK, A_MULT} / {H_Q,
    H_TAB, H_U}; OUT-C {A_D, A_DSQ, A_LIMB, A_X, A_XL0, A_XL1, A_Y,
    A_RHO0-3, A_SIG0-3, A_MU8} / {H_LO, H_D0-5, H_GU8, H_U};
  - domains, log sizes and row ranges;
  - `a_rows`, `a_data_rows`, `a_mask_base`, `a_prox`, `h_rows`,
    `h_data_rows`, `h_mask_base`, `h_prox`, `h_u` and `h_u_rows`;
  - per slot, the ordered terminal-vector planes.

  The gate's expected tables are `zk60_native_rg_classterminals.plane_index_c`.
  At the rung, OUT-C is A 76 / H 38 at 2^12, the same as R-C1's count.
- **(c) The slot record.** The existing `stage_slot` from
  `run_stage_slot` is enough once `start_slot` is called. Every public table
  must be recorded with its VALUES under `HL_RUN_CAPTURE_PUBLIC_TABLES=1`:
  - IN-C: π, κ, the query control column β²·ctl_q, and τ (now with the β²
    column);
  - OUT-C: the limb-plane live selector, **g(z) = σ·256^(z−32)**, u0, **the
    margin vector w_Δ**, the byte table, and every support and eq table.
- **(d) Role names:**
  - `"A-in"`, `"H-in"`, `"E-token-in"`, `"B-in"` as today;
  - `"A-out"`, `"H-out"`, `"B-out"` for OUT-C, with `commitment_kind`
    `"stage-out-c"` (and `"stage-in-c"` for IN-C);
  - **no `"E-token-out"`.**
- **(e) Schema string:** `"hashline-native-capture/7-classify-run"`, with every
  new key on the bundle's allow-list. The gate mirrors that list in its
  closed-schema check. The gate's reader refuses anything else by name
  (`check_classify_terminals`).

### 2.2 `token_io/classify_run.rs` `verify_classify_run_with`, `stage_in_c.rs` / `stage_out_c.rs` `verify` and `run_slots`

Add the calls where `token_io/run.rs` / `stage_out.rs` have them:

- **Stage IN-C (k = 0):**
  - `stage_begin_stage(0, "IN-C", …, stage_in_c::capture_planes(&lay), &tr)`;
  - `start_slot` before each `run_stage_slot`;
  - `checkpoint` + `mask` around M_in;
  - `checkpoint` + `pcs(Geom{…})` around A-in, H-in and the input endpoint;
  - `stage_end`.
- **Blocks:** as the token run: `stage_begin_stage(k + 1, "BLOCK", …)`, and
  `pcs` around each boundary opening (`classify_run.rs:277`).
- **Stage OUT-C (k = L + 1):** as stage IN-C, with A-out, H-out and B-out
  (`seg.closes[0]`).
- **After the last trailer:** `run_accepted()`.

### 2.3 `ClassifyRunStatement::capture_header()`

It returns the `RunHeader` of 2.1(a): the block part as for a run, plus
`ClassifyFacts`.

### 2.4 Capture tests (`#[ignore]`, environment-driven like `capture_a_tinyllama_token_run`)

- **`capture_a_classify_rung_run`**, at R-C1's rung (T32, d384, the
  synthetic policy). Environment variables:
  - `HL_PB_CAPTURE_DIR`;
  - `HL_PB_CAPTURE_BLOCKS` (1 and 2);
  - **`HL_PB_CLASSIFY_VERDICT=0|1|tie`**: the honest fixture with c placed
    as in `classify_tests` (`both_verdicts`, the tie test), so the gate gets
    a capture at each verdict and at the tie;
  - `HL_PB_CLASSIFY_CHUNK=<j>/<total>` (default the whole content; also
    chunk 1 of a 27-id content, `[4, 27)`, D41);
  - `HL_RUN_CAPTURE_PUBLIC_TABLES=1`;
  - `HL_TEST_SOURCE_COMMIT`.

  It proves with `prove_classify_run`, verifies with the recorder active,
  and writes the bundle with `L + 2` stage files.
- **The CLI path (P-18):** `capture_the_classify_cli_verify_path`. The
  named `zk60_classify` binary's own `classify-prove` / `classify-verify`
  run as its own processes, and then a recorded verification is made of the
  run directory, as `capture_the_cli_verify_path_at_tinyllama_t32_l2` does.
- **Later, after native R12 freezes:** a Shieldstral-shape capture at L = 1
  and 2 (T128). Please state the peak memory.

## 3. What the gate does with it (tools v19, frozen 2026-10-21; its own write set)

**Built now, before any capture** (`ops/zkp-mvp/gate-tinyllama/frozen_v19/`):

- **`zk60_native_rg_classify.py`.**
  - The re-derived geometry, which equals R-C1's count at the rung (OUT-C
    A 76 / H 38, margin window 34 bits, 5 limbs) and gives 35 bits / 5 limbs
    at Shieldstral's d 3072.
  - The expected per-commitment disclosures:
    - A 0 at every stage;
    - H 2 (the zero-sum pair);
    - E-token-in and every boundary 0;
    - **no E-token-out**;
    - the verdict the only data-dependent public value.
  - **The D34 recount:** 2·(768L + T + 256)/p² = 2^-112.7 at L = 26,
    T = 512, and 2^-116.96 at the next-token L = 1, T = 32, as a check.
  - **D41's split** (`chunk_ranges`, transcribed from `classify.rs:183-193`).
  - **The fail-closed label rule:** an OR over the chunks, and 1 on any
    missing, repeated or off-split chunk, or on a mixed policy or model.
- **`zk60_native_rg_classterminals.py`** transcribes all 12 classifier
  slots.
  - On witnesses the gate builds from R-C1's integer semantics, the margin
    hosting identity, every zero-check clause and both LogUp balances hold
    at verdict 0, verdict 1 and the tie.
  - **12 / 12 failing-first controls fire as predicted:**

    | Control | Perturbation | Breaks |
    |---|---|---|
    | MC-1 | flipped verdict, limbs unchanged | margin identity |
    | MC-2 | flipped verdict, limbs re-made from −δ−1 | LogUp |
    | MC-3 | a non-byte limb, carry kept | LogUp |
    | MC-4 | a nonzero limb pad | LZC pad clause |
    | MC-5 | c + 1 | margin identity |
    | MC-6 | the negated w_Δ with its own digest | B-3 digest refusal |
    | MC-7 | header without `classify-verdict` | refused |
    | IC-1 | a template id changed | template clause |
    | IC-2 | the shared-coefficient forgery | passes shared μ, refused by the fresh μ2 |
    | IC-3 | a content control id | LogUp |
    | IC-4 | a template control id | none (the honest case: it holds) |
    | PI-1 | the OUT-C plane table read by v18 | v18 refuses it by name; v19 reads it equal |

  - **The one-public-bit check:** every OUT-C public table is rebuilt from
    public data and b alone, and flipping b moves only g. NL-1's S1
    premises hold on all 12 slots.
- **`zk60_native_rg_classpins.py`.** The readings of round 12's three
  additive pinned-file changes against frozen-r11, and the four ported
  files' digests. A moved digest is refused by name.

**On the first capture (v20)**, the gate will run:

- the capture reader;
- the terminal identity of the 12 slots at the replayed challenges, against
  the recorded terminals;
- the per-commitment rank and joint rank of A_in, H_in, A_out and H_out;
- the CFS of IN-C / OUT-C;
- the full preimage;
- NL-1 on the recorded slots;
- the B-3 re-derivation (w_digest from the recorded w_Δ against the
  statement, and against the export's artifact once F3 lands);
- the D41 checks over a set of chunk captures.

Real captures wait for R12's freeze and the hooks.

## 4. Smallest version that unblocks the gate

- 2.1(a) without the header re-check;
- 2.1(b) with both `capture_planes`;
- `start_slot` in both `run_slots`;
- the `pcs` / `mask` wrappers on the seven stage openings and on the
  boundary openings;
- `stage_begin_stage` / `stage_end` / `run_accepted`;
- the schema string;
- `capture_a_classify_rung_run` at L = 1 and 2, verdicts 0 / 1 / tie.
