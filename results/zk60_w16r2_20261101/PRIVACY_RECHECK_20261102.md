# D59 condition (5): the privacy re-check of W16R2, and D60's prerequisite (the Python gate on a D55 capture)

Date: 2026-11-02. Tree: `perf/zk-batch-optimizations` at `ae0da8ee`, plus this re-check's test-only and
staging-gate commits (listed at the end). Privacy requirement: P1 (hide inputs, outputs and intermediate
activations; weights public), `docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md`. Not reopened here.

**Verdict: no leak found.** The theory argument below shows that the Ligero-style hiding of the regular
commitments survives the rate change (rate 1/2, Q = 260 opened columns, 260 pads per row). Every mechanical
check run on W16R2 captures and on D55 fork-run captures passed, and every control fired.

What this verdict does not cover:
- It is not a privacy acceptance and not a registration.
- It covers only the change D59 makes: the code rate and Q of the regular openings, and the M column-count
  plumbing. It does not cover the older owed items of the W16 gate (section 5).
- The Python records are `DEV-PASS`. Their figures are computed on the bundles as given, but they are not
  admissible evidence until the moved source pins are read.

## 1. What changed, and what the hiding argument depends on

D59 (W16R2) changes three things:
- The PCS parameters of the regular commitments (`A`, `H`, every internal boundary `B_k`, both external
  endpoints): `inv_rate` goes 4 → 2 and Q goes 256 → 260, so `n = 2^14` and `N = n · inv_rate = 2^15`.
- The pad count, which follows Q.
- The source of the `M` column count, which is now its own constant `zk::MASK_Q`. The value is unchanged
  at 256.

Nothing else moves:
- The slot schedule, the claims, the mask pairs, the transcript order and the masking commitment `M` are
  untouched.
- `git diff 3ae5625a ae0da8ee -- ops/` touches `shape.rs`, `wire.rs`, `run_fork_wire.rs`, `run_capture.rs`
  (the `mask_domain` line only), tests and harnesses.
- `zk.rs`, `pcs.rs`, `protocol.rs`, `boundary.rs`, `endpoint_g.rs`, `argument*.rs` and the Metal kernels
  are not touched.

So the question is whether the hiding argument has any step that reads the rate, Q or the encoded domain.
It has four such steps, and each one is checked below:
- (H1) Q ≤ pads;
- (H2) no opened position is pad-free;
- (H3) the code has room for the pads;
- (H4) the mask rows cover every clear combination.

## 2. Theory, from the code

### 2.1 The encoding (`ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs`)

**The row encoding.** `encode_row_zk` (pcs.rs:658–677) is the commitment's host encoder. The verifier's
re-encoder in `verify_zk_tagged` (pcs.rs:1218–1229) is the same function. The tagged commit's host path
uses `encode_buffer::initialize_row` (`pcs/encode_buffer.rs:43–71`), the same arithmetic.

For row `r` with message `d_r` (its `n` values, read as evaluations on `G_n`) and pads `g_r ∈ F^Q`, the
encoder writes:
- the coefficients of the interpolant `d_r(x)` (degree < n);
- then subtracts `pad[i]` at coefficient `i` and adds it at `n + i`.

So the committed polynomial is

    f_r(x) = d_r(x) + Z_n(x) · g_r(x),   Z_n(x) = x^n − 1,   g_r(x) = Σ_{i<Q} pad_i x^i.

It then scales coefficient `i` by `h^i` (`coset_powers`, pcs.rs:645–654) and runs a size-`N` NTT. The
codeword is `f_r` on the coset `h · G_N`, with `h = ZkOpts::standard(..).coset = 7` (pcs.rs:582–584).

**The Metal path** (`hashline/src/gpu/metal.rs:975–979, 1099–1107`):
- It receives the same `pads` and `pows`, and refuses `n + q > nn`.
- Its digests are byte-equal to the CPU's (MG-1 in section 3.1, and the W16R2 rung golden `334e168f`,
  CPU = Metal).
- The Merkle root binds every column, so the device codewords are the CPU's.

**Where the pads come from.** They are drawn per row from the prover's generator before any encoding
(`commit_zk_owned_with_tag`, pcs.rs:766–801: `rng.fp_vec(rows · q)`, then one 32-byte salt per encoded
column). Details:
- `fp()` reduces 128 uniform bits mod p (`rng.rs:83–87`), so the statistical distance per element is
  ≤ 2^-64.
- Every generator on the path is `ZkRng::from_os` under its own domain:
  - `protocol.rs:1471` for a single block;
  - `run.rs:1165` for a D12a run;
  - `run_fork.rs:719` (one per fork) and `run_fork.rs:776` (the commit phase) for D55.
- s25's W-8 census (green, below) holds that no other generator exists on the path.

**Where q_pad comes from.** It always equals Q:
- `protocol::pcs_params_at` / `endpoint_pcs_params` (protocol.rs:72–74, 86–88) put `sh.opened_cols` into
  `num_col_checks`.
- The boundary spec takes `sh.opened_cols` (`run.rs:678`), and so does the endpoint spec
  (`private_block.rs:986`).
- `ZkOpts::standard` sets `q_pad = num_col_checks`.
- `Shape::build` (shape.rs:1014–1028) sets `opened_cols = W16R2_OPENED_COLS = 260` for a W16R2 string,
  and refuses any other rate or row width.
- The committer asserts `q_pad ≥ num_col_checks` (pcs.rs:771).
- The verifier refuses `q < num_col_checks` and any clear vector whose length is not `n + q`
  (pcs.rs:1178, 1196, 1207).
- The wire refuses any opening without exactly `checks` columns and `n + checks`-long vectors
  (`wire.rs:102–108`).

So at W16R2, Q = q_pad = 260 for every regular commitment. A receipt cannot change either: the verifier's
parameters are the shape's (`pcs_params_at(sh)`), never the receipt's.

### 2.2 The view of one commitment

`open_zk` (pcs.rs:1016–1045) reveals three things.

**The clear vectors.** It draws λ per group and ρ_prox over all rows (`zk_rhos`, pcs.rs:936–957). It
reveals `K = G + 1` clear vectors `v_k = (ρ_kᵀ D, ρ_kᵀ P)`, each `n + Q` long. That is, it reveals the
polynomials `φ_k = Σ_r ρ_{k,r} f_r` (degree < n + Q):
- the message half gives `φ_k` on `G_n`;
- the pad half gives `Σ_r ρ_{k,r} g_r`.

**The opened columns.** It then draws Q indices with replacement over `[0, N)`
(`Transcript::challenge_indices`, `transcript.rs:136–148`). It reveals, for each sampled index `j`:
- the full column `(f_r(η_j))_r`, with `η_j = 7 ω_N^j`;
- the column's salt;
- its Merkle path (15 siblings at `N = 2^15`).

Let `S` be the set of distinct indices; `s = |S| ≤ Q`.

**(H2) No opened position is pad-free.**
- The coefficient of pad `i` in codeword entry `j` is `Z_n(η_j) η_j^i`.
- At rate 1/2, `η_j^n = 7^n · (ω_N^n)^j = 7^n · (−1)^j`.
- So `Z_n` takes exactly two values on the coset, `7^n − 1 = 0xfaa379da87a7f913` and
  `−7^n − 1 = 0x055c8624785806ec` (computed, Goldilocks, `n = 2^14`). Both are nonzero: 7 generates
  `F_p^*` (`7^((p−1)/q) ≠ 1` for each prime `q | p − 1` = 2, 3, 5, 17, 257, 65537), so `7^(2n) ≠ 1`.
- `coset_powers` asserts `h^N ≠ 1`, which is exactly `h ∉ G_N`, so the coset is disjoint from `G_N ⊃ G_n`.
- No index in `[0, 2^15)` is a systematic position.
- At rate 1/2 the systematic positions of the NON-hiding encoder would be every other column. Control
  C-R2a measures this: on the systematic domain the pad block at about 259 opened positions drops to rank
  127–133.
- No private-block commitment uses that encoder. The only commitment calls on the path are
  `commit_zk_owned_tagged` with `ZkOpts::standard`, in `protocol.rs:1686, 1902`, `boundary.rs:350` and
  `endpoint_g.rs:280` (grep: no `pcs::commit(` or hand-built `ZkOpts {` outside tests).

**(H1) Q ≤ pads.**
- For a data row, the map `g_r ↦ (Z_n(η_j) g_r(η_j))_{j∈S}` is a nonzero diagonal times an `s × Q`
  Vandermonde matrix on distinct nodes. Its rank is `s ≤ Q`, so it is onto `F^s`.
- So the opened entries of every data row are uniform on `F^s`, independently across rows (independent
  pads), whatever the message is.
- At W16R2, `s ≤ Q = 260 = q_pad` always. A repeated index reveals the same column twice and adds nothing.
- The margin `q_pad − s` was 0 to 3 in every capture. That is by design: Q = pads. It is the same equality
  W16 has at 256.
- The rate does not enter (H1) at all, only Q against the pad count, and those are tied by construction.

**(H3) Room for the pads.**
- `n + Q = 16,644 ≤ N = 32,768`, so the code `RS(n + Q, N)` on the coset holds the pads.
- `encode_row_zk` asserts it, and so do `encode_buffer` and the Metal path.
- `n + Q` evaluation functionals (the `n` points of `G_n` and any `s ≤ Q` coset points) are distinct, so
  they are linearly independent on polynomials of degree < n + Q.
- So conditioning on the opened columns leaves `φ_k`'s values on `G_n` (the message half) free.

**(H4) The mask rows cover every clear combination.** This part is unchanged by D59 (it reads no rate and
no Q), but the task asks for it, so the code is cited:
- **Masked claims.** Every evaluation claim carries its own reserved pair of uniformly random rows, with
  coefficients `(1, u)`, `u ∉ F_p` (`argument.rs:1226–1275`; the H tables are `(re, 1), (im, U)`).
  `audit_claims` (protocol.rs:240–284) refuses:
  - a claim without exactly its own adjacent pair;
  - a shared pair;
  - an unused pair;
  - a claim reaching the proximity pair;
  - a zero mask coefficient.
- **The proximity pair.** It is reserved and is touched only by ρ_prox, and
  `check_opening_challenges` (protocol.rs:292–303) refuses dependent proximity coefficients
  (`det(ρ_prox[p], ρ_prox[p+1]) = 0`) and any zero λ.
- **Mask-row contents.** The mask rows' messages are filled with fresh uniform words before the commitment
  (protocol.rs:1681, 1894–1900; boundary.rs:346–348). Their pads are uniform like every row's.
- **The internal boundary's geometry** is derived as `data + 2·sites + 2` (`boundary.rs:184–188`, ruling
  M-1). That is one pair per claim and the proximity pair, with no single-row proximity.
- **The rank this gives.** The `2K × (mask coordinates)` matrix over `F_p` (real and imaginary parts) is
  block-triangular with invertible 2×2 blocks, so it has full rank `2K`.
- **The consequence.** Conditioned on the opened columns, each mask row is uniform on an affine space of
  dimension `n + Q − s ≥ n`. So the `K` clear polynomials are uniform subject only to (i) consistency with
  the opened columns, which the verifier checks, and (ii) the claim values, which are themselves masked by
  the pairs.
- **How it is checked.** The Python gate computes this exactly, at the captures' real challenges, as the
  disclosed dimension (section 3.3): A 0, H 2 (the two public zero-sum constraints on H's u-rows, the same
  as at W16 and R13), each endpoint 0, each boundary 0, M 0.

**Salts and paths.**
- Every encoded column has a fresh 32-byte salt, so there are 2^15 at rate 1/2.
- A leaf is `H(H(col) ‖ salt)` under the profile's keys (pcs.rs:787–791).
- An opened column's path reveals 15 sibling digests of salted leaves of unopened columns. Those hide the
  unopened columns in the random-oracle model, exactly as the 16 did at rate 1/4.
- Nothing about salts or paths depends on the rate except the depth, which T-4 pins
  (`verify_zk_tagged` refuses a path that is not `log2 N` long).

**Fiat–Shamir.** The indices are drawn after the clear vectors are absorbed. The argument above holds for
every `S` with `s ≤ Q`, and the refusals of (H4) are evaluated on the real transcript before each opening
(`check_opening` replays a cloned prefix). So the honest-verifier simulation (sample `φ` uniformly subject
to the claims, derive `S`, sample the columns consistently) is unchanged by the rate.

### 2.3 `M` and the wire

**`M` is untouched.** `zk::mask_commit_tagged` and `mask_open` (zk.rs:481–518, 563–601) use only
`MASK_LOG_MSG = 9`, `MASK_LOG_DOM = 12` and `MASK_Q = 256` (zk.rs:373–375). They never read a shape
field. `M` keeps its own 2^12-point coset (`7 · G_4096`), 512-coefficient a-rows each carrying 256 pads,
1024-coefficient `b` / `u` rows, and 256 opened columns. D59 covers none of `M`'s accounting, and none is
needed for privacy.

**The D59 plumbing changes are value-neutral.**
- `wire.rs`'s `MASK_CHECKS = zk::MASK_Q` (wire.rs:25) replaced `Dim::block(..).checks` at four decode and
  validate sites. `run_fork_wire.rs` has the same change.
- The capture writer's `mask_domain.columns` is now `zk::MASK_Q` (run_capture.rs:3271, 3608, 3886).
- Both were 256 before and are 256 now at every non-W16R2 profile.
- At W16R2 the old code would have demanded 260 `M` columns from a 256-column opening. It would have
  refused, not leaked, and the Python gate's `derive_mask_domain` would also have refused it.

**The wire and capture carry exactly the opening.**
- What they carry: clear vectors, opened columns with their salts and paths, `M`'s `q` / `prox` / columns,
  roots and slot transcripts. The new D59 `mask_len` / `encoded_len` are length formulas only.
- The capture's allow-list (PG-7) and its `not_in_a_capture` list are unchanged. PG-7 passes on every W16R2
  and D55 capture: no pad value, mask coefficient, unopened column or unpublished salt.

### 2.4 D55 (commit, fork, join): what is new for privacy

Read from `run_fork.rs:742–1109`.

**Every commitment is opened once.**
- Each boundary `B_k` is committed once in phase 1 (commit-phase generator) and opened ONCE in the tail
  through `PreparedBoundary::into_opening`. That function consumes the owner (`boundary.rs:275–281`), and
  the one opening carries both claims: fork `k`'s slot 22, then fork `k+1`'s slot 21.
- Each endpoint is opened once after S1.
- Each fork's `A`, `H`, `M` are committed under that fork's own generator and opened once inside the fork.
- So the per-commitment argument of 2.2 applies to every commitment unchanged.

**The join adds no new information.** It absorbs only words the verifier itself computes: each fork's
final transcript state and squeeze counter, and the IO claims the verifier derives from the fork's slot
terminals (`run_fork.rs:572–583, 1035–1038`).

**The refusals run on the right transcript.** They are taken on each fork's own transcript (A, H) and on
the run transcript after S1 (boundaries and endpoints): `boundary::check_opening` and
`protocol::check_endpoint_opening` at run_fork.rs:907–915 and 1071–1101.

**The randomness is fresh per fork.** Forked transcripts change only how the public challenges are derived;
the hiding conditions are per-challenge facts and are checked at the realized challenges. Separate OS
generators per fork make the pads of different forks independent, and at least as fresh as D12a's single
generator.

## 3. Gate results

All runs went through `scripts/zk60_resource_guard.py`.

**Binary and logs.**
- Test binary: `hashline-d272b43a0f6d4b12`, sha256 `7e06528d…`, gpu-metal release build of this tree.
- Logs: `results/zk60_w16r2_20261101/logs/privacy_recheck/`. Each run has `<tag>.log`, `<tag>.cmd` (the
  binary hash, env and args) and `<tag>.guard.done`.

### 3.1 The Rust W16 privacy gate at W16R2 (new tests in `w16_privacy_gate_tests.rs`, test-only)

**PG-R2: the new check.** It runs on every capture document holding openings. For every regular opening it
checks:
- rate 1/2, `num_col_checks` = `q_pad` = 260, and exactly 260 columns;
- every index inside the 2^15 encoded columns;
- every clear vector `n + 260` long;
- that the production `protocol::pcs_params_at`, `endpoint_pcs_params` and `ZkOpts::standard` agree;
- **the exact rank of the pad block of the production encoder** (`pcs::encode_row_zk` on unit pads, at the
  production coset) at the DISTINCT opened positions: it must equal their number (H1 and H2, computed).

For every `M` it checks: 256 columns over 2^12, and 1024-entry vectors.

Its controls:
- **C-R2a, the systematic domain:** the same positions with every coset power 1 lose rank. 127–133 of about
  259 positions are pad-free.
- **C-R2b, W16's 256 pads against W16R2's positions:** rank 256 < s.
- **C-R2c, the capture held to W16's geometry:** refused.

| test | what | result | log |
|---|---|---|---|
| `w16r2_privacy_gate_at_the_development_rung` (CPU, two hidden inputs) | PG-1..PG-10, C-1..C-6, PG-R2 on both captures, C-R2a..c | **22/22 PASS** | `r2rung.log`, `gate_all_cpu.log` |
| `w16r2_privacy_gate_on_the_metal_path` (rung) | MG-0 (device carried both proofs, 0 declines), MG-1 seeded bytes CPU = Metal `53b72459…`, PG-6..9, controls, PG-R2, MG-2/3, C-7/8 | **20/20 PASS** | `r2metal.log` |
| the same at `W16R2_8B_T128_H24` | MG-1 `6d092ce6…` CPU = Metal; PG-R2 (A 260/260 rank 260, H 260/260, …) | **20/20 PASS** | `r2metal8b.log` |
| `w16_privacy_gate_at_the_trained_t128_shapes`, `HL_W16PG_PROFILES=W16R2_8B_T128_H24`, pair | PG-1..10, controls, PG-R2 on both captures | **22/22 PASS** | `r2cpu8b.log` |
| `d55_fork_run_capture_passes_the_w16_gate_checks_at_the_w16r2_rung` (3 forks) | the D55 F5 checks (PG-6..10 per fork and the tail, C-2..C-7b), PG-R2 over 3 forks and the tail (10 regular openings), the tail = 2 boundaries + 2 endpoints, C-R2a..c | **25/25 PASS** | `d55r2.log` |
| W16 regressions: `w16_privacy_gate_at_the_development_rung`, `d55_fork_run_capture_passes_the_w16_gate_checks_at_the_development_rung` | unchanged check lists | **18/18, 20/20 PASS** | `gate_all_cpu.log` |

Floors before the commit:
- **Scans:** `r19b s24 s25 absorb s33 hash_domain::` 58/58 (`scans.log`).
- **Dev bytes gate:** `01fa1b2e / 992034f8 / 371e6b00 / 3ab090df`, CPU = Metal (`devbytes.log`).
- **Builds:** the gpu-metal test build and the no-feature `cargo check --tests` both pass (`build2.log`,
  134 warnings, none in the changed file).

The new test file is not new: `w16_privacy_gate_tests.rs` was already a test-only file on `TEST_ONLY_FILES`,
so no scan list moved.

### 3.2 The captures the Python gate read

They were written by this tree's test binary, with `HL_TEST_SOURCE_COMMIT=2196592d`, under
`/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles/`.
They are test-only bundles (synthetic public weights, hidden synthetic inputs).

**One-block bundles** (`w16_privacy_gate_write_the_w16_bundles`):
- `w16r2_rung_h24-s{0,1}`;
- `w16r2_8b_t128_h24-s{0,1}`;
- `w16_rung_h24-s{0,1}`, the regression.

**D55 fork-run bundles** (new `d55_privacy_gate_write_the_fork_bundles`, L = 3):
- `d55-w16_rung_h24-s{0,1}`;
- `d55-w16r2_rung_h24-s{0,1}`.

`run_capture::write_bundle` refuses a fork-run bundle by design. So the test-only `write_fork_bundle` lays
out the recorder's own bytes:
- `run.json`, `stage-NN.json` per fork, `d55_tail.json` and `arrays.bin` (schema
  `hashline-native-capture/8-d55-fork-run-prototype`);
- the receipt frames under `receipt/`;
- a manifest last, with every file's SHA-256 and the source pins plus `run_fork.rs`, `run_fork_wire.rs` and
  the writer.

### 3.3 The Python gate (v25 staging; not frozen; v24 untouched)

Records are in `results/zk60_w16r2_20261101/privacy_recheck_gate/`, written by `logs/privacy_recheck/pygate_final.sh`
(exit 0, `pygate_final.done`). Its per-bundle logs are `py-<bundle>.log`, and `logs/privacy_recheck/summarize.py`
prints the figures below.

The logs `py-w16r2-rung-s0.log`, `py-d55-w16r2-s0.log`, `pygate_w16_batch.*` and `suite_v25.log` are earlier
dry runs on pre-final tool states. Every part passed in them too, but they are superseded and their
records were deleted. It was run under the session's gate venv
(Python 3.13.13 with blake3 1.0.11); the system pythons have no blake3.

**The two staging changes.**

(1) `zk60_native_rg_w16.py` gains the W16R2 profiles, their test-only run identities, and a geometry fact
in W16-1 that is checked per opening (`pcs_geometry`, `check_opening_geometry`). The fact requires:
- the shape and every regular opening at the family's rate and Q (W16 1/4 and 256; W16R2 1/2 and 260);
- every clear vector `n + Q` long;
- `M` at 2^12 and 256.

Everything else reads the bundle unchanged: W16-6's `RunRoleView` takes the rate and Q from the shape and
the opening's `q_pad`.

(2) A new module, `zk60_native_rg_d55.py`, runs the same W16 subset on a D55 capture:
- **D55-0:** integrity.
- **D55-1/2:** the facts. The D55 parameter line and the D55 schedule digest are recomputed from run.json's
  own lines (`run_fork.rs::schedule_lines`).
- **D55-3:** the D55 transcript, re-derived from public data:
  - the header gives `run_binding`;
  - phase 1 gives S0, which equals the head's S0 tag;
  - each fork is `fork(S0, k)` through `RunReplay`'s own per-slot / M / PCS body, with its start and end
    tags;
  - the join uses the replayed fork end states and the claims the tail opens, and gives S1, which equals
    the tail's header;
  - then the tail's openings and end tag.
- **W16-4 / W16-5:** per fork.
- **W16-6:** every fork's A, H and M, plus the tail's boundaries and endpoints, ranked by `RunRoleView`
  exactly as `run_gate.stage3` ranks a D12a run. Also the pad block's exact rank on B0, and the exclusivity
  controls.
- **W16-7:** mask / CFS per fork, and the six controls.
- **D55-C:** two replay controls:
  - C1, a joined claim value moved by one, gives S1 not reproduced;
  - C2, the fork index dropped (review F2's mutation), is refused.

The tests are in `staging_v25/tests/test_w16_gate.py`: new port tests, plus bundle tests for a W16R2 rung
and a D55 capture.

**The results** (all on one tool state; `tool_sha256` is in every record):

| bundle | gate | parts | status | the per-commitment figures |
|---|---|---|---|---|
| `w16r2_rung_h24-s0` | W16 | W16-0..7 all PASS | W16-DEV-PASS | A disclosed 0, H 2, E-In 0, E-Out 0, M 0; s ≤ 260 = pads everywhere, no vanishing Z_n node; pad block exact rank = s on E-Input; W16-7 every mask entry recomputed, 0 differing |
| `w16r2_rung_h24-s1` | W16 | all PASS | W16-DEV-PASS | as above |
| `w16r2_8b_t128_h24-s0` | W16 | all PASS | W16-DEV-PASS | as above at the 8B T128 geometry |
| `w16r2_8b_t128_h24-s1` | W16 | all PASS | W16-DEV-PASS | as above |
| `w16_rung_h24-s0` (regression) | W16 | all PASS | W16-DEV-PASS | rate 1/4, Q 256: unchanged figures |
| `d55-w16r2_rung_h24-s0` | D55 | D55-0..3, W16-4..7, D55-C all PASS | D55-DEV-PASS | 3 forks × (A 0, H 2, M 0) and B0 0, B1 0, E-In 0, E-Out 0, all at rate 1/2, Q = pads = 260; B0's pad block exact rank = s; replay 376 positions / 4,247 challenges, 0 failures; S0, S1 and the tail end reproduced; 10 distinct roots, none opened twice |
| `d55-w16r2_rung_h24-s1` | D55 | all PASS | D55-DEV-PASS | as above |
| `d55-w16_rung_h24-s0` | D55 | all PASS | D55-DEV-PASS | the same at rate 1/4, Q 256: **the D60 prerequisite, the Python gate on a D55 capture** |
| `d55-w16_rung_h24-s1` | D55 | all PASS | D55-DEV-PASS | as above |

**Over all nine records** (`logs/privacy_recheck/summarize.out`):
- **59 regular commitments ranked.** Every disclosed dimension equals its expectation: every A 0, every H 2,
  every boundary and endpoint 0.
- **18 masking commitments,** each with disclosed dimension 0.
- **The pad budget:**
  - no vanishing `Z_n` node;
  - every certifying minor has full row rank, with a nonzero determinant;
  - every reduction hypothesis (H-pad, H-pair, H-prox) holds;
  - pad margins of 0 (29 openings), 1 (20), 2 (10) and 3 (1).
- **Replays:** 0 failures. That is 1,419 challenges per rung record, 6,211 per 8B record and 4,247 per D55
  record.
- **Mask / CFS:** every entry recomputed, 0 differing, and the mask controls fire.
- **D55-C:** C1 is refused (55 replay failures, S1 not reproduced); C2 is refused (5,017 failures).
- **Tool state:** one state for every record: `zk60_native_rg_w16.py` `0ebcb0cb…`, `zk60_native_rg_d55.py`
  `34a27149…`.
- **The captures' manifests** are kept in `results/zk60_w16r2_20261101/privacy_recheck_bundle_manifests/`
  (with their SHA-256 in `MANIFEST_SHA256.txt`). The bundles themselves stay in the session scratchpad.

The staging_v25 suite was run with the W16 rung, W16R2 rung and a D55 bundle named:
- 131 tests;
- the only failure is the pre-existing `test_r19b_self_check_and_its_control`, which needs the r16b..r19b
  CLI binaries that stayed on the laptop. Round 25's own suite log has the same failure;
- every W16, W16R2 and D55 test passed, on both D55 bundles (`suite_v25_d55w16r2.log`,
  `suite_v25_d55w16.log`).

One stale staging assertion was corrected. `test_pins_are_classified_and_range16_is_not_pinned` asserted
that `range16.rs` is not pinned. Since M26 the recorder pins it (`OWN_SOURCE_FILES`), so a bundle written at
this tree pins it as one more unread pin. The test now asserts the classification against the bundle's own
pin list, and the W16 record's `not_here` drops "the recorder pinning range16.rs" when the bundle pins it.

## 4. Leaks and suspicious correlations

None found. The places that looked closest to an issue, each examined:

1. **Pad margin 0** (s = Q = pads) in many openings. This is by design: Q equals the pad count, and the
   hiding needs only `s ≤ pads`. The pad block has full rank at s = 260 (PG-R2 and the Python
   exact-rank cross-check).
   - W16 has the same equality at 256.
   - If Q were ever raised without the pads, C-R2b shows the check sees it.
   - The structural tie is `ZkOpts::standard` (q_pad = num_col_checks), plus the committer's assert and the
     verifier's length checks.
2. **Systematic positions at rate 1/2.** Half of the columns would carry raw message symbols under the
   non-hiding encoder (C-R2a). No commitment on the private-block path uses it. The coset is fixed in
   `ZkOpts::standard`, the verifier re-encodes with the shape's own opts, and the Metal path is byte-equal
   (MG-1, roots).
3. **`M`'s column count.** It was read from the block's Q until D59. That was harmless at 256, and at
   W16R2 it would have refused rather than leaked. It is now `MASK_Q`, and every capture shows `M` at
   256 / 2^12 with 1024-entry vectors.
4. **H's disclosed dimension 2.** It is the two public zero-sum constraints of H's u-rows, the same at
   W16, R13 and W16R2. It is not witness data.
5. **Repeated column indices** (2–7 per one-block capture over its four regular openings, 11 over a D55
   run's ten). They are sampling with replacement: the same column twice, no new information. The count of DISTINCT indices is what the pads must cover, and it does.

## 5. Still owed

**Of v25's W16 list, not covered by this re-check** (unchanged from round 25; each applies to W16R2 and D55
as much as to W16):
- T-0, the terminal identity of the seven W16-redefined slots (SC_LZC 3, SC_DZC 14, SC_QZC 15, SC_KVZC 16,
  SC_SZC 17, SC_FZC 18, SC_TAB 19). For D55 this also means recomputing the joined IO claims from the
  forks' terminals: the D55 replay binds the claims the tail opens through S1, but does not derive them.
- NL-1 S1–S5 on those slots.
- The joint checks.
  - **What is missing:** D12a's run-level joint rank over the three commitments that hold each interior
    plane (`A_k`'s output rows, `B_k`, `A_{k+1}`'s input rows), restricted to the reserved rows. It is not
    ported to W16, W16R2 or D55.
  - **Why this matters:** this is the one run-level privacy obligation the per-commitment rank does not
    discharge (`boundary.rs:32–38` says so).
  - **Status:** D59 does not change its structure, but nothing here checks it.
- TS-1 and the claim census.
- The full preimage.
- The hash census on the Python side. The Rust s25 W-2 census does measure the W16R2 profiles.
- The pins.
  - **What is unread:** 19 moved `private_block` and zkp-core pins on the one-block W16R2 bundles, and 22
    on the D55 bundles (plus `run_fork.rs`, `run_fork_wire.rs` and the writer).
  - **The consequence:** until they are read, every record is DEV-PASS, not admissible evidence.
  - **The v24 tables:** v24's mask-layer and run-layer pin tables refuse a post-R9 tree. They are reported
    in the W16 records and not applied.

**Closed since round 25:** the recorder pinning `range16.rs` (M26).

**New, from this re-check:**
- `W16R2_SHIELD_T128_H24` has no test-only run identity. No capture or gate can run at it (the CPU T128 run
  naming it panics in `run_profile_of`). The rung and 8B are covered.
- The D55 capture writer is test-only, and so is the D55 Python port.
  - **For registration:** D60 asks for a registered profile, which needs a production capture path for fork
    runs (or a ruling that the test-only writer's bundles are the evidence) and a freeze of the D55 gate
    module.
  - **Freezing v25** (with this module and the W16R2 entries) is a separate step with its own review. It
    was not done here.
- Condition (4) is still owed: an independent D24-class review of the W16R2 implementation. This re-check
  is not that review. Its theory section is one reader's argument, and an independent reader should check
  §2.2, especially (H4)'s rank claim, which the Python gate computes but this document does not prove in
  general.

## 6. Commits

- `2196592d`: the Rust test additions (`w16_privacy_gate_tests.rs`), with the logs of the build, scans,
  dev bytes and Rust gates.
- COMMIT2_PLACEHOLDER: the staging_v25 Python changes, the Python records, the remaining logs and this
  document.
