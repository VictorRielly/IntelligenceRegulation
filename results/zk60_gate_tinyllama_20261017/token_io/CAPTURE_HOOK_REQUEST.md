# Capture-hook request: token-I/O run captures for the privacy gate (gate round 7)

From the PRIVACY GATE lane to the token-I/O lane, through the coordinator, on
2026-10-19. This is a request, not a ruling or an acceptance.

**Tree read:**

- `ops/zkp-mvp/token-io/hashline/` at round 6
  (`results/zk60_token_io_r1_20261017/manifest_final_r6.sha256`);
- round 7's `wip-r7a/`, `wip-r7b/` and `wip-r7merge/`, for any capture
  change. There is none.

## 1. Why the gate is blocked

The gate reads a *capture bundle*: the recorder's view of an accepted run,
written by `run_capture.rs` (`begin_run_with`, then `stage_begin` / `slot` /
`mask` / `pcs` / `stage_end`, then `run_accepted`, `take` and
`write_bundle`). In the token tree **no token run can be captured** [READ]:

1. **The run-level hooks are never called.** `verify_token_run_with`
   (`token_io/run.rs:725-808`) calls none of `stage_begin`, `stage_end` or
   `run_accepted`. Only `run::RunVerifier::step` calls them (`run.rs:1138`,
   `:1272`, `:1289`). There is also no token capture header:
   `TokenRunStatement` has no `capture_header()`, and `RunHeader`
   (`run_capture.rs:327`) has no token fields.
2. **Stages IN and OUT record nothing.** `stage_in::verify` and
   `stage_out::verify` run their slots through `token_io::run_stage_slot`
   (`token_io.rs:898`). That function has no `run_capture::start_slot` /
   `slot` call, unlike `argument::run_slot` (`argument.rs:475`, `:661`,
   `:1948`). They verify M with `crate::zk::mask_verify_tagged`
   (`stage_out.rs:802`, and the same in stage IN) and every opening with a
   bare `pcs::verify_zk_tagged` (`stage_out.rs:806-815`; stage IN A, H and
   input endpoint). None of these carries the `checkpoint` + `mask` / `pcs`
   wrapper that `protocol.rs:1256-1305` puts around the block's.
3. **The boundary openings of a token run record nothing either.** That
   covers B_in at block 0 and every B_k, opened with a bare
   `pcs::verify_zk_tagged` at `token_io/run.rs:783`, while
   `RunVerifier::step` wraps the same opening in `run_capture::pcs(Geom{…})`
   (`run.rs:1177-1250`).

So the seven gate items of `DESIGN.md` §4.2 (G-1..G-7) have no receipt to
read. G-1, G-2, G-3, G-4, G-6 and G-7 need the openings, slots and mask of
the new stages. G-5 can be read from a capture's layout or from the code.

## 2. What is asked (the token lane's write set; test-only where possible)

Every hook below is a **no-op unless a capture is active**
(`run_capture::with` returns `None`), exactly as in `protocol.rs` and
`run.rs` today. No receipt byte and no transcript byte moves. The pinned
files change (the token lane re-freezes them anyway at round 7).

### 2.1 `run_capture.rs`

- **(a) `RunHeader` gains `token: Option<TokenFacts>`.** `TokenFacts` holds
  every public word the token run header absorbs that a block run's does not,
  in absorb order:
  - the token run profile;
  - V and V_pad;
  - T;
  - the variant (public row / P / F) and the mode (i / ii);
  - the limb count L;
  - the embedding digest and the head digest;
  - the BOS constant;
  - the final-norm constants (g0, Cn_f, tn_f, Ceps_f);
  - s_in and s_out;
  - the tier: name, `ep_log_n`, rate, rows;
  - each token endpoint's spec: rows, data rows, sites, site rows, proximity
    row, log_n, rate, and the plane geometry `(rows, cols)`;
  - the input and output token-endpoint roots;
  - B_in's and B_out's `BoundaryFacts` (derived rows, site rows, proximity
    row, scale).

  `write_run` serialises it under a new top-level key `"token_io"`.
  `begin_run_with` rebuilds the TOKEN header transcript from it
  (`TokenRunStatement::transcript`) and compares it with the binding. This
  is the token analogue of the block header check.
- **(b) `stage_begin_stage(k, kind, bytes, start_tag, b_root, a_root, h_root,
  mask_root, plane_index, tr)`.** `kind` ∈ {`"IN"`, `"BLOCK"`, `"OUT"`}.
  `plane_index` is the stage's plane table, built from `StageLayout` for IN
  and OUT and from `Layout` for a block. It is written into each `stage-NN`
  file as today's `plane_index` is, with these fields:
  - for every A and H plane: its id, name, domain (V_pad, T, Tab, …), log
    size and row range;
  - `a_rows`, `a_data_rows`, `a_mask_base`, `a_prox`;
  - `h_rows`, `h_data_rows`, `h_mask_base`, `h_prox`, `h_u` and `h_sign`;
  - per slot, the ordered list of planes its terminal vector evaluates;
  - `sched`: the slot specs (main, ext, degree, kind, a/h/io sites), the
    hosts and `row_log [A, H, In, Out]`.

  The existing `stage_begin` can stay as the BLOCK case.
- **(c) `stage_slot(def: &token_io::StageSlotDef, acc, proof, rho, c,
  mask_eval, before, after)`.** This writes the SAME record shape as `slot`
  writes for a block slot:
  - definition challenges;
  - round messages;
  - terminals (private evaluations), in `plane_index` order;
  - every public table, with its kind, length and SHA-256, and its VALUES
    when `HL_RUN_CAPTURE_PUBLIC_TABLES=1`. That covers tau, iota, the
    support indicators, u0, and every eq / fixed-point table;
  - each claim's point, **with the fixed coordinates marked as fixed**: the
    challenge-fixed column coordinate `r_emb` on B_in, and the public row
    bits `T − 1` on B_out in the public-row variant (G-2).
- **(d) New role names for `Geom`**: `"A-in"`, `"H-in"`, `"A-out"`,
  `"H-out"`, `"B-in"`, `"B-out"`, `"E-token-in"` and `"E-token-out"`.
  - `commitment_kind` gains `"token-endpoint"` and `"stage-in"` /
    `"stage-out"`.
  - For the two-site input endpoint (D26 variant P), `site_rows` lists both
    sites.
  - `claim_sources` names the IO-s / SHIFT claims (G-7) by slot.
- **(e) The schema string** becomes `"hashline-native-capture/6-token-run"`
  for a token bundle. Every new key goes into the bundle's own allow-list,
  and the gate will mirror that list in its closed-schema check.

### 2.2 `token_io/run.rs` `verify_token_run_with`, `token_io/stage_in.rs` / `stage_out.rs` `verify`, `token_io.rs` `run_stage_slot`

Add the calls in the same places `run.rs` / `protocol.rs` / `argument.rs`
have them:

- **Stage IN (k = 0):**
  - `stage_begin_stage(0, "IN", &segments[0], start, seg.b_root, seg.a_root,
    seg.h_root, seg.mask_root, &plane_index(&in_lay), &tr)`;
  - in `run_stage_slot`'s verify side, `start_slot` / `stage_slot` around
    each slot;
  - `checkpoint` + `mask(&lay.mask_specs(), &seg.mask_root, &acc.fs,
    &seg.mask_open, ntt, before, tr)` around `mask_verify_tagged`;
  - `checkpoint` + `pcs(Geom{…})` around each of A-in, H-in and the input
    token endpoint;
  - `stage_end(0, end, &tr)` after the trailer check.
- **Block stages (k = 1..L):**
  - `stage_begin_stage(k + 1, "BLOCK", …, &lay)`. The `verify_core` hooks
    already fire inside.
  - `checkpoint` + `pcs(Geom{role: "Input", commitment_kind:
    "internal-boundary" (k ≥ 1) or "B-in" (k = 0), boundary: Some(k), …})`
    around the opening at `token_io/run.rs:783`;
  - `stage_end(k + 1, end, &tr)`.
- **Stage OUT (k = L + 1):** as stage IN, with A-out, H-out, **B-out**
  (`seg.closes[0]`) and the output token endpoint (`seg.closes[1]`).
- **After the last trailer:** `run_accepted()`.

### 2.3 `token_io.rs` / `token_io/run.rs`: `TokenRunStatement::capture_header()`

It returns the `RunHeader` of 2.1(a): the block part as `RunStatement` gives
it, plus `TokenFacts`.

### 2.4 Capture tests (`run_capture_tests.rs` or a token test module), `#[ignore]`, environment-driven like `capture_a_tinyllama_trained_run`

- **`capture_a_tinyllama_token_run`** at the **R2 geometry**: TinyLlama T32,
  22 blocks, the public-row variant, mode (i), the R2 calibration and tables.
  Environment variables:
  - `HL_PB_CAPTURE_DIR`;
  - `HL_PB_CAPTURE_BLOCKS` (22, and also 1 and 2 for quick rungs);
  - `HL_PB_FIRST_LAYER`;
  - `HL_PB_TOKEN_INPUT=dense|fixed`. `dense` is a real held-out prompt (the
    R2 demo's ho00 token ids). `fixed` is the gate's degenerate partner, one
    fixed public prompt such as T copies of a single admissible id; please
    name the id you choose;
  - `HL_RUN_CAPTURE_PUBLIC_TABLES=1`;
  - `HL_TEST_SOURCE_COMMIT`.

  It proves with `prove_token_run`, verifies with the recorder active, and
  writes the bundle with `L + 2` stage files.
- **`capture_a_llama3_8b_token_run`** at the **8B T32 token geometry**, with
  the same variables. If the full 32-block capture is too heavy for the
  15 GiB box, a reduced L (for example 1 block) is enough for the gate: the
  endpoint, IN and OUT geometry is what is new. Please state the peak memory.

## 3. What the gate does with it (its own write set)

The gate extends its tools to the new stage kinds:

- per-commitment rank and the joint rank of the new hidden planes restricted
  to reserved rows (G-1);
- claims at partially fixed points on B_in / B_out (G-2);
- CFS of stages IN and OUT (G-3);
- the vocabulary pads, the P-3 lift and the endpoint pad words (G-4);
- `log(Tab) == row width` per stage (G-5);
- the D17 joint view at the 2^8-row token endpoints (G-6);
- the two-site input endpoint's SHIFT / IO-s claims (G-7).

New negative controls must fire on the new stages. The hidden-length mode
(ii) and variant F are not built, so they are out of scope.

## 4. Smallest version that unblocks the gate

If the full request is too large for round 7, the gate can start from this
subset:

- 2.1(a), with `TokenFacts` serialised but no header re-check;
- 2.1(b);
- 2.1(d) with 2.2's `pcs` wrappers on all eight new openings and on the
  boundary openings;
- 2.2's `mask` wrapper on M_in and M_out;
- `stage_begin` / `stage_end` / `run_accepted`;
- the R2 capture test at L = 1 and 2.

The slot hook 2.1(c) comes next. Without it, G-3's slot side and G-4's
pad-zero terms cannot be checked from the bundle; only from the code.
