# Migration ledger

Three boundaries are implemented: the primitives (round 11, Codex), the
Ligero commitment behind a backend seam (round 12, Fable, step 1; integrated
by Codex in `b044e20`) and the table registry plus the typed v3 pieces with
a bounded decoder (round 12, Fable, step 2; corrected in round 14 for the
review's C20-R1..R3). Each section records its source pin, what moved, what the
adapters keep, the validation and the before/after surface; the next
boundaries follow at the end.

# Primitive extraction, round 11

Source pin: `b557a7c` (reviewed Fable GPU, privacy-analysis and core-design
merges on top of Codex's `8b697b0` observation diagnostic). GPU implementation
at this pin is identical to Fable's validated `5bb1546`; Codex's combined
post-extraction validation is recorded in `results/zk60_round11_validation.json`.

The first implemented boundary is deliberately smaller than the final CL20
delivery. Seven modules live in this crate, with direct dependencies `blake3`
and `rayon`; there is no dependency on `hashline`, CUDA, exports or model data.

| Canonical module | Existing caller path | Mechanical adjustment |
|---|---|---|
| `field` | `hashline::field` | primitive tests moved; application verifier fault-injection tests remain in hashline |
| `ntt`, `merkle`, `transcript`, `mle` | same module names in hashline | entire implementations and their tests moved |
| `rng::ZkRng` | `hashline::zk::ZkRng` | stream implementation and two RNG-only tests moved; configuration/OS-freshness integration tests remain in hashline |
| `sumcheck` | `hashline::sumcheck` | RNG import points to `rng`; all sumcheck and CFS helper code/tests moved |

The adapters re-export the same Rust types; they do not convert or copy proof
objects. There is one implementation per primitive. Field operations, NTT
order, hash labels, transcript challenge consumption, RNG domains and refill
order, sumcheck messages and serialization are unchanged. Original and moved
source hashes are in `primitive_migration.json`. Existing Cargo dependency
versions are retained by seeding the new lockfile from the legacy lock.

The 19 primitive tests pass independently. The public sumcheck example checks
the terminal polynomial against its public tables; accepting only the round
checks would omit that obligation. The example is not a commitment scheme or
an FFN proof. The CFS helpers are preserved for compatibility with the legacy
FFN; Fable's FA3 B1/B2 review blockers still apply. The A/H/W disclosure and P3
identity regressions remain in hashline and must continue to pass as limitation
tests until a versioned repair changes their expected behavior.

# PCS extraction, round 12 (Fable, CL20 step 1)

Source pin: `cfa46f6` (the round-11 tree; the primitive boundary above is
its parent `c8a342f`). Worktree `/home/victor/wt-zk60-cl20`, branch
`zk60-cl20-core`. Original and moved source hashes: `pcs_migration.json`.

| Canonical module | Existing caller path | Mechanical adjustment |
|---|---|---|
| `pcs` (`src/pcs.rs`: `PcsParams`, `Slice`, `Claim`, `Commitment`, `Committed`, `Opening`, `commit`, `open`, `verify`, `hash_columns`; the hiding form `ZkOpts`, `CommittedZk`, `OpeningZk`, `ZPart`, `ZClaim`, `coset_powers`, `encode_row_zk`, `salt_leaf`, `commit_zk`, `commit_zk_owned`, `open_zk`, `verify_zk`, `assert_mask_sites`, `last_mask_sites`, `zk_groups_for_record`) | `hashline::pcs` | RNG import is `crate::rng::ZkRng` (the last application dependency of round 11 is gone); the three PCS unit tests moved with the code (core 19 -> 22 tests, hashline 159 -> 156) |
| `pcs::backend` (`src/pcs/backend.rs`: `Backend`, `EncodedStore`, `Cpu`, `NoExternal`) | new | the accelerator seam, below |

**The seam.** The legacy `Store::Device(crate::gpu::DevCommit)` variant and
the eight `#[cfg(feature = "gpu-cuda")]` arms of `pcs.rs` are replaced by two
traits the core defines and never implements for a device:

- `EncodedStore` (`fold_rows`, `columns`): what the opening needs from an
  encoding held elsewhere; `Sync` because the opening reads it from rayon
  workers, as the host store is read.
- `Backend` (`type Store: EncodedStore`; `try_commit`, `try_commit_zk`, both
  default `None`): who may take over the encode-and-hash. `None` runs the CPU
  body, which is the oracle; an implementation must return the leaves the CPU
  encoder would (hashline's differential discipline, `gpu/mod.rs`).
- `Cpu` (`Store = NoExternal`, an uninhabited enum): the only backend in the
  core. `Store<E = NoExternal>`, `Committed<E>`, `CommittedZk<E>` are generic
  in the store type, so a CPU commitment cannot hold an external store and the
  external arms are unreachable in a CPU build with no feature flag anywhere.
- `commit_with`, `commit_zk_with`, `commit_zk_owned_with` take a `&impl
  Backend`; `commit`, `commit_zk`, `commit_zk_owned` are the `Cpu` forms.
  `open_timed` returns the phase clocks (`OpenTimings`) that `open` used to
  print under `HL_TIMING`; the core reads no environment variable.

The variant keeps its legacy name `Device` (the design said `External`)
because `layer.rs`, `zk.rs` and `wcache.rs` pattern-match and construct
`pcs::Store::Device(dc)` inside their gated device arms; with the generic
store those files compile unchanged, and none of them is this lane's to edit.
Renaming is a one-line follow-up for each owner once the arms move to the
backend hooks of step 2.

**The adapter** (`hashline/src/pcs.rs`, 84 lines): `pub use zkp_core::pcs::*`,
the three aliases `Store`/`Committed`/`CommittedZk` = the core's generics
over `gpu::DevStore` (`gpu::DevCommit` with the feature, `NoExternal`
without), `commit`/`commit_zk`/`commit_zk_owned` calling the `_with` forms
with `gpu::backend()`, `open` printing the `HL_TIMING` line from
`open_timed`, and `commit_zk_device` (the hiding commitment of a
`gpu::Pooled` buffer the device already holds, drawing pads then salts in
the same order) verbatim. `hashline/src/gpu/mod.rs` gains the `seam`
module: `CudaBackend` (the `HL_GPU=1` / `enabled()` runtime switch and the
exact decline messages `tests/test_hashline_cl_profile.py` pins) and `impl
EncodedStore for DevCommit` over `dev_fold_rows` / `dev_columns`; without
the feature `backend()` is the core's `Cpu`. `gpu/cuda.rs`, `zk.rs`,
`layer.rs`, `wcache.rs`, `pcs_compact.rs`, `attention.rs` and every test are
untouched. The mask-site recorder (`LAST_SITES`, `last_mask_sites`) moved
with the code because `zk.rs` consumes it in production for the driver's
report; retiring it is the zk.rs owner's call.

Preserved, byte for byte: field operations, NTT order, the column and salted
leaf hashes, the `pcs-vec` / `pcs-prox` labels and challenge consumption,
the pads-then-salts RNG draw order on every path, `Opening`/`OpeningZk`
serialization. Validation (all at two threads under `/tmp/zk-heavy.lock`;
commands, exits, digests and log hashes in
`../results/zk60_cl20_pcs_validation.json`):

| gate | result |
|---|---|
| `cargo test --release --offline --manifest-path zkp-core/Cargo.toml --all-targets` | exit 0; 22 passed, 0 failed, 0 ignored (19 primitive + `pcs::tests::commit_open_verify_and_tampers`, `pcs::zk_tests::zk_commit_open_verify_and_tampers`, `pcs::zk_tests::zk_openings_are_uniform_and_every_site_is_masked`); no warnings |
| `cargo build --release --offline` (hashline, CPU) | exit 0 in 52.7 s; the 8 warnings are the same eight `attention.rs` warnings the round-11 build log carries (none from the moved or adapter files) |
| `cargo test --release --offline` (hashline, full suite, round-11 environment: `HL_GPU` unset) | exit 0; 21 binaries, 156 passed, 0 failed, 0 ignored = the 159 of `cfa46f6` minus the 3 PCS tests that moved (lib 46 = 49 − 3); the LIMITATION tests (`zk60_identity_gap` 5, `zk60_mask_rank` 2, `mask_diagnostic` in the lib) pass unchanged. A first attempt with `HL_GPU=0` in the environment tripped `tests/zk60_attention_schedule.rs`'s own precondition (`unset HL_GPU for this CPU gate`) after 52 passing tests and is recorded, not counted |
| `cargo check --release --offline --features gpu-cuda` (hashline, `target-gpu`, CUDA env of `results/cl1_floors.sh`) | exit 0, 0 errors; the warning list is identical to the round-11 GPU build's (`cuda.rs`, `attention.rs`); no device job was run |
| four CPU frozen cases of suite v3 (`pass 12 512 --threads 2`: v2 `50cf7bdf…`/66,844,928 B, v3 `5f368db6…`/70,758,084 B, zk `021485e4…`/87,228,528 B, zkv3 `40eb5479…`/87,697,008 B) | all four match sha256 and length exactly, exit 0, verifier ACCEPT (binary `1e84c80f…`, 4,663,272 B, built from this tree; prove walls 31.7 / 36.3 / 35.3 / 40.0 s at two threads on a loaded box, not a timing claim) |
| D8: no `std::env`, no `cudarc`, no `cfg(feature)`, no `hashline::` path in `zkp-core/src` | holds (the only `hashline` strings are the frozen hash-label bytes) |

**Dependency surface, before/after** (`tools/dep_closure.py`, two-crate
form; before = the pristine `cfa46f6` tree, after = this move):

| | nodes / edge records | hashline library modules / code lines | zkp-core library modules / code lines | cross-crate edges | literal closure of `{layer, tables_v3}` |
|---|---|---|---|---|---|
| before | 69 / 356 | 37 / 19,979 | 8 / 1,377 | 7 (six re-exports + `zk -> zkp_core::rng`) | 25 modules, 10,202 code lines (8,875 excl. tests); `zk` enters through `pcs` |
| after | 71 / 370 | 37 / 19,011 | 10 / 2,472 | 10 (+ `pcs -> zkp_core::pcs`, `pcs -> zkp_core::rng`, `gpu -> zkp_core::pcs`) | 25 modules, 7,103 code lines (6,114 excl. tests); `zk` no longer in the closure |

The 968 lines that left hashline are the 1,062 moved lines of `pcs.rs` less
the 45-line adapter plus the 49-line seam in `gpu/mod.rs`; nothing was
deleted, and the crate totals (21,356 -> 21,483 code lines across both) grow
by the seam and its documentation. `dependency_graph.json` is now the
two-crate graph at this move (the `52a13d1` single-crate graph it replaced
is reproducible with `--src hashline` on that pin).

This step claims nothing about the FFN masking disclosure
(`ZK60_FFN_MASK_DIAGNOSTIC.md`) or the P3 identity gap: their LIMITATION
tests stay in hashline and pass unchanged; the extracted commitment is the
same construction with the same obligations.

**Merge.** After this commit (`76ee275`) the performance branch `972da4e`
(Codex: `42471f0` attention message-count rejection, `72a884e`
`stable_weight_slots`, `972da4e` test-guard pin) was merged as `f61ee77`
with no conflicts; `hashline/src/lib.rs` gains the `stable_weight_slots`
module lines and nothing of this lane's changes. Re-validation on the merged
tree, two threads under the heavy lock: core tests exit 0, 22/22; hashline
suite 167 passed / 0 failed / 0 ignored across all 21 test binaries (170 at
`972da4e` minus the 3 moved PCS tests). That run's trailing doc-test stage
then failed to compile because this lane applied the step-2 sources to the
tree while it was still running (a sequencing error of this lane, not of the
merge), so the two `compile_fail` doc-checks of `stable_weight_slots.rs`
were not observed in it; the step-2 suite run below compiles the merged tree
plus step 2 from a quiet source and includes them.

# Boundary 2, round 12 (Fable, CL20 step 2): table registry and the typed v3 pieces

Source pin: `f61ee77` (the PCS boundary above merged with the performance
branch at `972da4e`). Hashes: `ffn_v3_migration.json`.

| Canonical module | Existing caller path | Mechanical adjustment |
|---|---|---|
| `tables` (`src/tables.rs`: `Act16Fn`, the 15 frozen int16-out members and digests, `int16out_generate`, `table_spec_digest_int16out`, `int16out_member`, `registry_report`, `hex`) | `hashline::tables_v3` (`pub use zkp_core::tables::*`), `hashline::silu::hex` (`pub use zkp_core::tables::hex`) | the five-line `silu::hex` helper moved with its only core caller; the registry test moved (core +1); `sha2 0.10.9` added to the core with hashline's exact subtree, seeded into the lock from hashline's lock (the seeder reproduces the round-11 lock byte for byte on `blake3,rayon`) |
| `ffn_v3::statement` (`src/ffn_v3/statement.rs`: `Params` = `LayerParams`, `Statement` = `StatementV3`, `Layout` = `LayoutV3`, `absorb_statement` = `absorb_statement_v3`, `absorb_com`, `absorb_mults`, `TAG_ACT16`, `TAG_INT16`, `tag_rem_v3`, `rem_rows`, `rem_value`, `rem_index`, `pow2_signed`) | `hashline::layer` re-exports under the legacy names (`pub use ... as ...`) | `Layout::check` added (the shape rule as a `Result`; `new` keeps its panic text), `Params::check` added (the decoder's parameter rule), the slice helpers `s_f`/`s_d`/`s_w` and `pcs_for` made `pub`; two unit tests added |
| `ffn_v3::proof` (`src/ffn_v3/proof.rs`: `Proof<X = NoExtra>` = `LayerProofV3`, `ExtraOpening`, `NoExtra`, `size_bytes`/`to_bytes` verbatim, NEW `Shape`, `OpeningShape`, `DecodeError`, `Proof::from_bytes`) | `hashline::layer::LayerProofV3 = zkp_core::ffn_v3::Proof<pcs_compact::BatchOpening>`; `impl ExtraOpening for BatchOpening` in `layer.rs` | the compact-PCS slot `cpcs_open` became the generic extra opening (field name kept for `public_block_wire.rs` and its test); three unit tests added |

The prover and verifier (`prove_layer_v3`, `verify_layer_v3`, `v3_zcd_point`,
the tamper legs, `multiplicities_v3`) are still hashline's and consume the
core's types through the re-exports; `zk.rs`, `public_block_*`,
`model_identity.rs`, `causal_oracle.rs`, `private_block_contract.rs` and every
existing test change nothing.

**The bounded decoder.** `Proof::from_bytes(bytes, &Statement, &Params)` is
shape-directed: `Shape::of` derives every field length from the layout (the
three commitments' rows and `log_cols`; `2 + distinct shifts` multiplicity
tables of 256 / 65,536 / `rem_rows(s)` entries; `2 nb_f` gu claims, `log_db`
matmul rounds of degree 2, `nb_d + 2 nb_d nb_f` gu terminals; `nb_d` d
claims, `log_fb` rounds, `nb_f + nb_f nb_d` d terminals; `log_t + log_fb`
and `log_t + log_db` zero-check rounds of degree 4 with `10 nb_f` and
`4 nb_d` terminals; `3 nb_f + nb_d` helper sums; the W/A/H openings with
2/2/3 column-weight groups of `2^log_cols` entries each plus the proximity
vector, and `num_col_checks` columns of `rows` elements and `log2(enc_cols)`
path digests). It reads exactly that and refuses short input, trailing bytes,
a commitment disagreeing with the layout, a wrong multiplicity tag/length, a
column index `>= enc_cols` and any 8-byte word `>= P` where a field element
is read (`Fp::new` would reduce it silently). The group counts are the
structural ones (`p3`/`p6`; `rho_f`/`rho_d`; `rho_f`/`rho_d`/sums); a
challenge-tail coincidence (probability ~2^-128) would make the verifier,
which regroups from the actual values, reject a well-formed proof, never
accept a malformed one.

**Tests.** Core: `ffn_v3::proof::tests` (the tiny T2/d16/f16 and the 125M
shapes; dummy round trip with `size_bytes == Shape::total_bytes`; truncation
at every field boundary, one trailing byte, a commitment/rows mismatch, a
wrong multiplicity tag and length, non-canonical elements in a claim, a
sumcheck round and an opened column, an index at and beyond `enc_cols`,
sampled bit flips, an unsupported statement) and `ffn_v3::statement::tests`.
hashline: `tests/zk60_cl20_codec.rs` (new) proves the seeded T2/d16/f16
witness with the LEGACY prover and checks that its bytes are exactly the
core's shape, that the core decoder reproduces them and the legacy verifier
accepts the decoded object, that a witness with one changed weight gives
different bytes of the same shape, that permuted shifts decode but fail to
verify while a different distinct-shift set fails to decode, that truncation,
trailing bytes, non-canonical elements and sampled bit flips are refused by
the decoder or the verifier without a panic, and that the eight tamper legs
(FlipX, FlipW, RemainderOutOfRange, WrongTableEntry, WrongRequant, WrongZ,
WrongRounding, OutOfRangeInt16) decode and are refused by the verifier with
the same message on the legacy and the decoded object. This is D2/D4/D5 and
the D3 legs on the moved pieces; D1 (old prover vs core prover bytes) needs
the prover, which has not moved.

Validation (two threads, `/tmp/zk-heavy.lock`; details in
`../results/zk60_cl20_ffn_v3_validation.json`):

| gate | result |
|---|---|
| core tests (`cargo test --release --offline --manifest-path zkp-core/Cargo.toml --all-targets`) | exit 0; 28 passed, 0 failed, 0 ignored (22 + `tables::tests::all_frozen_members_regenerate_to_their_pins` + `ffn_v3::statement::tests::{layout_shape_rule_and_offsets, tags_and_windows}` + `ffn_v3::proof::tests::{shape_of_the_tiny_and_the_125m_statements, dummy_round_trips_and_sizes_agree, malformed_bytes_are_refused_never_panic}`); no warnings. A first run of this stage failed to compile four `assert_eq!` on `Result<Proof, _>` (no `PartialEq` on `Proof`); the fix (`.err()`) touched test code only and is what is committed |
| hashline build (CPU, `cargo build --release --offline`) | exit 0 in 45.2 s; the 8 warnings are the round-11 eight (a first build of this step carried a ninth, `unused import: PcsParams` in `layer.rs`, removed before the commit; the frozen cases were re-run on the rebuilt binary) |
| hashline suite (`cargo test --release --offline`, `HL_GPU` unset, merged tree + step 2 from a quiet source) | exit 0; 23 test binaries: 169 unit/integration tests passed, 0 failed, 0 ignored, plus the 2 `compile_fail` doc-checks of `stable_weight_slots.rs` (171 in the log). Accounting from the merge tree's 167: −1 (`tables_v3`'s registry test moved to the core, where it passes; lib 53 -> 52) + 3 (`tests/zk60_cl20_codec.rs`); every other binary's count is unchanged; the LIMITATION tests pass unchanged |
| GPU feature check (`cargo check --release --offline --features gpu-cuda`, `target-gpu`, CUDA env of `results/cl1_floors.sh`) | exit 0, 0 errors; the warning list equals the round-11 GPU build's except one `attention.rs` line number moved by Codex's `42471f0`; no device job |
| four CPU frozen cases (`pass 12 512 --threads 2`) | all four match sha256 and length exactly, exit 0, verifier ACCEPT, on the binary of the committed tree (`7b37f5ce…`, 4,671,688 B; the same binary bytes before and after the unused-import removal, so both runs agree): v2 `50cf7bdf…`/66,844,928, v3 `5f368db6…`/70,758,084, zk `021485e4…`/87,228,528, zkv3 `40eb5479…`/87,697,008 |
| D8 (`zkp-core/src`: no `std::env`, `cudarc`, `cfg(feature)`, `hashline::`) | holds |

**Dependency surface** (`tools/dep_closure.py`, two-crate form; before =
the merge tree `f61ee77`, after = this step):

| | nodes / edge records | hashline library modules / code lines | zkp-core library modules / code lines | cross-crate edges | literal closure of `{layer, tables_v3}` |
|---|---|---|---|---|---|
| before (`f61ee77`) | 74 / 377 | 39 / 19,586 | 10 / 2,472 | 10 | 25 modules, 7,103 code lines (6,114 excl. tests) |
| after | 79 / 394 | 39 / 19,277 | 14 / 3,325 | 14 (+ `layer -> zkp_core::ffn_v3`, `tables_v3 -> zkp_core::tables`, `silu -> zkp_core::tables`, the new test) | 27 modules, 6,938 code lines (5,949 excl. tests) |

hashline lost 309 lines (`layer` 2,034 -> 1,858, `tables_v3` 132 -> 1,
`silu` 60 -> 58); the core gained 853 (`tables` 135, `ffn_v3` 9,
`statement` 178, `proof` 529 of which the decoder, its shape and its
tests are new, `lib` 2). The closure still enters `chain`, `export`,
`export_v3`, `gpu`, `pcs_compact`, `wcache` and `phase_profile` through
`layer`; those are the cuts of step 2c.

The core's `Layout::new` panics on an unsupported shape exactly as before
(same message text); the decoder reports the same rule as
`DecodeError::Shape` instead. No behaviour of any existing entry point
changes; the compact-PCS experiment keeps its batched opening in the same
slot, the same bytes and the same `--pcs compact` gate. This step claims
nothing about the FFN masking disclosure or the P3 identity gap.

# Round 14 corrections to boundary 2 (Fable, CL20; Codex review C20-R1..R3)

Source pin: `1c1ef6b` — the lane after merging the published performance
integration `a94ce2c` (Codex: `b044e20` integrates the PCS boundary
`76ee275`/`ee775be`, `83115b5` adapts the protected-material cleanup to the
generic store, `df7fb0d` releases journal locks before inherited descriptors
close, `a94ce2c` publishes round 14). The merge was clean (no conflicts, no
markers); PCS was not touched again and the host-store/journal fixes are kept.
The held typed-decoder commit `f8d40a7` sits on top of the integrated PCS, and
[the review](../docs/zkmatrix-poc/ZK60_CL20_ROUND14_REVIEW.md) reproduced
three findings against it. Corrections, each with a regression that reproduces
Codex's probe (`results/zk60_round14_evidence/review/probe/src/main.rs`)
and was run against the unfixed code first:

| ID | finding (reviewed pin) | correction | regression tests |
|---|---|---|---|
| C20-R1 | `Params::check` accepted `num_col_checks = usize::MAX`; decoding an ordinary tiny proof with those expected parameters panicked with capacity overflow in `Vec::with_capacity`. | `Params::check` bounds the query count to the supported `1..=MAX_COL_CHECKS` (65,536; the profile uses 256); every field length of `Shape` is formed with checked arithmetic (`Shape.fields`, `OpeningShape::{column_bytes, bytes} -> Option`), an overflow is `DecodeError::Shape`; the reader's allocation rule `Reader::ensure(count, item)` allocates a vector only when `count * item` bytes remain in the input, at every `Vec::with_capacity` (claims, sumcheck rounds, multiplicity tables, group vectors, columns, paths), so no expected parameter can make the decoder reserve more than its input. | core `ffn_v3::proof::tests::oversized_query_count_is_a_shape_error_not_a_panic`; hashline `round14_r1_oversized_query_count_is_a_shape_error_not_a_panic` |
| C20-R2 | `Proof::from_bytes(&[], statement_with_shift_64, normal_params)` panicked in `rem_rows` (debug: shift overflow) before reading input; in a release build the shift wraps to a wrong table size instead of panicking. | `Statement::check` (the layout rule plus every shift in `SHIFT_MIN..=SHIFT_MAX` = `-8..=16`) and `Params::check` run first in `Shape::of`, before any table or size arithmetic; `Layout::check` bounds `t_rows`, `d`, `f` by `MAX_DIM = 2^30`; all reported as `DecodeError::Shape`. Checked in debug and release. | core `ffn_v3::statement::tests::statement_check_refuses_unsupported_shifts_and_dimensions`, `ffn_v3::proof::tests::unsupported_shifts_and_dimensions_are_shape_errors_before_any_read`; hashline `round14_r2_unsupported_shift_is_a_shape_error_before_any_read` |
| C20-R3 | With `log_cols = 0` the legacy prover's proof verifies, `Params::check` accepts the configuration, the actual W/A/H groups are 1/1/2 but the decoder assumed 2/2/3 and refused the honest bytes. | Group counts are derived from the PCS grouping rule: claims are grouped by their column tail (the last `log_cols` point entries); with `log_cols = 0` every tail is empty and the point claims of an opening merge into one group (W 1, A 1, H 1 + the sum group), with `log_cols >= 1` the distinct points give 2/2/3 (`OpeningShape::point_groups`). `log_cols = 0` stays supported; legacy behaviour is unchanged. | core `ffn_v3::proof::tests::log_cols_zero_groups_follow_the_pcs_grouping`; hashline `round14_r3_log_cols_zero_honest_proof_decodes_with_the_pcs_groups` (legacy prove/verify at `log_cols` 0 and 1, groups equal the shape's, decode/re-encode identity, decoded object verifies) |

Before/after, on the same tests (details and log hashes in
`../results/zk60_cl20_ffn_v3_validation.json`, section `round14`):

| test | before the fix (unfixed `f8d40a7` code on the merged tree, release) | after the fix |
|---|---|---|
| hashline `round14_r1_oversized_query_count_is_a_shape_error_not_a_panic` | FAILED: `Params::check` accepted `usize::MAX` queries (Codex's probe then observed the capacity-overflow panic in `from_bytes`) | ok (release) |
| hashline `round14_r2_unsupported_shift_is_a_shape_error_before_any_read` | FAILED: shift 64 on empty input was not a shape error — in release the shift wrapped to a wrong table size and the decoder reported truncation; Codex's debug probe panicked in `rem_rows` | ok (release) |
| hashline `round14_r3_log_cols_zero_honest_proof_decodes_with_the_pcs_groups` | FAILED: decoder groups (2, 2, 3) vs the legacy PCS's (1, 1, 2); the honest proof was refused | ok (release) |
| the three pre-existing codec tests (round trip, malformed bytes, eight tamper legs) | ok | ok |
| core `oversized_query_count_is_a_shape_error_not_a_panic`, `unsupported_shifts_and_dimensions_are_shape_errors_before_any_read`, `log_cols_zero_groups_follow_the_pcs_grouping`, `statement_check_refuses_unsupported_shifts_and_dimensions` | did not exist (they use the new `check`/`MAX_COL_CHECKS` API) | ok in release AND in debug (32/32 both) |

No frozen proof byte changes (the corrections touch the decoder, the shape
and the checks only; `to_bytes` is untouched). PCS is untouched. Validation
of the corrected tree (two threads, heavy lock):

| gate | result |
|---|---|
| core tests, release | exit 0; 32 passed, 0 failed, 0 ignored (28 + the four regressions) |
| core tests, debug (`cargo test` without `--release`, the review's debug/release distinction) | exit 0; 32 passed, 0 failed, 0 ignored — the shift and size arithmetic no longer reaches an overflow in either profile |
| hashline build (CPU, `cargo build --release --offline`) | exit 0 (the merged tree carries Codex's round-13/14 modules; the warning list is the merge tree's) |
| hashline suite (default features, `HL_GPU` unset) | exit 0; 23 binaries: 173 unit/integration tests passed, 0 failed, 0 ignored, plus the 2 `compile_fail` doc-checks (175 in the log); `tests/zk60_cl20_codec.rs` 6/6 (the three round-12 tests and the three `round14_*` regressions); the LIMITATION tests unchanged. Accounting from the step-2 tree's 169: +1 lib test from Codex's `df7fb0d` journal regression, +3 `round14_*`. The suite Codex counts (`--features stable-weight-storage`, the round-14 219 = 188 hashline + 9 compile-fail + 22 core at `df7fb0d`): exit 0; 193 unit/integration passed, 0 failed (lib 73), plus the 9 compile-fail doc-checks (202 in the log); with the core's 32 that is 234 = 219 − 1 (the registry test now runs in the core) + 3 (round-12 codec tests) + 3 (`round14_*`) + 10 (core: 1 tables + 5 step-2 + 4 round-14). |
| GPU feature check (`cargo check --release --offline --features gpu-cuda`, `target-gpu`) | exit 0, 0 errors, the merged tree's 10 warnings; no device job |
| four CPU frozen cases (`pass 12 512 --threads 2`) | all four match sha256 and length exactly, exit 0, verifier ACCEPT, on the merged tree's binary (`c2168046…`, 4,672,008 B): v2 `50cf7bdf…`/66,844,928, v3 `5f368db6…`/70,758,084, zk `021485e4…`/87,228,528, zkv3 `40eb5479…`/87,697,008 |
| D8 | holds |

Remaining review items not addressed here: step 2c (the P0 prover/verifier
extraction with actual old/new parity) and everything after it, as listed
under "The next step in detail".

## Next boundaries for Fable, in order

1. ~~Extract PCS types and the CPU commit/open/verify path behind a narrow
   backend interface.~~ Done (round 12, step 1).
2. ~~Move table registration and typed v3 statement/layout/proof pieces and
   bounded decoding~~ (done, round 12, step 2: the registry and its digest
   validation are the core's, unchanged); then the selected P0 FFN path
   (prover, verifier, tamper legs, witness planes): step 2c below.
3. ~~Decoder refusals on the tiny fixture~~ (done, step 2); the old/new
   proof-byte comparison of the PROVER (D1) lands with step 2c; keep the four
   complete frozen artifacts and public receipt gates at every step. Preserve
   both compact and GPU consumers; no backend is retired as a side effect.
4. Extract the versioned masking repair only with its reviewed invariants and
   privacy classification. A P0 FFN example alone does not close CL20.

### The next step in detail

Pieces 2a (table registry) and 2b (typed v3 pieces and the bounded decoder)
are implemented above; their original plan is kept here for the record, and
2c is the exact next step.

**2a, table registry (done).** `hashline/src/tables_v3.rs` (`Act16Fn`, the 15
frozen members and digests, `int16out_generate`, `table_spec_digest_int16out`,
`int16out_member`, `registry_report`, one test) moves verbatim to
`zkp-core/src/tables.rs` together with the five-line `silu::hex` helper it
calls; `hashline::tables_v3` becomes `pub use zkp_core::tables::*` and
`hashline::silu::hex` re-exports the core's. The core gains `sha2 0.10.9`
with hashline's exact subtree (`digest 0.10.7`, `block-buffer 0.10.4`,
`crypto-common 0.1.7`, `generic-array 0.14.7`, `typenum 1.20.1`,
`version_check 0.9.5`, `cpufeatures 0.2.17`), seeded into the lock from
hashline's lock (the seeder reproduces the round-11 lock byte for byte on
`blake3,rayon`). Gate: core tests (+1), the hashline suite, all four frozen
cases (the digest string is absorbed into the v3 transcript).

**2b, typed v3 pieces (done; `Proof<X>` and `from_bytes` as planned).** From `layer.rs` (lines 1225-1404 at `cfa46f6`):
`TAG_ACT16`, `TAG_INT16`, `tag_rem_v3`, `rem_rows`, `rem_value`,
`rem_index`, `pow2_signed`, `StatementV3`, `LayoutV3` and its slice helpers,
`absorb_statement_v3`, `absorb_com`, `absorb_mults`, and `LayerProofV3` with
`size_bytes`/`to_bytes` -> `zkp-core/src/ffn_v3/{statement,proof}.rs`;
`hashline::layer` re-exports them under the current names. The design
point: `LayerProofV3.cpcs_open: Option<pcs_compact::BatchOpening>` ties the
proof type to the compact-PCS experiment. The same generic seam as
`Store<E>` applies: `Proof<X = NoExtra>` with `X: ExtraOpening { size_bytes,
write_bytes }` and `hashline::layer::LayerProofV3 = Proof<pcs_compact::BatchOpening>`,
so the compact consumer stays byte-identical and the core never names it.
`Proof::from_bytes` (new; shape-directed from `(StatementV3, LayerParams)`:
the three commitments' `rows`/`log_cols`, `2 + distinct shifts` multiplicity
tables of `rem_rows` entries, the sumcheck round counts and degrees,
`num_col_checks` columns of `rows` entries and `log2(enc_cols)` path digests;
rejecting short input, trailing bytes, any `u64 >= P` read as a field
element, and column indices `>= enc_cols`) is gated by D4/D5 on a tiny
T2/d16/f16 proof produced by hashline's `prove_layer_v3` (round trip
`to_bytes(from_bytes(b)) == b`, truncation at every field boundary, one
trailing byte, a non-canonical element, an oversized count: reject, never
panic).

**2c, the P0 prover/verifier (the next step).** Files:
`hashline/src/layer.rs` (`prove_layer_v3` at 1455-2005 of `cfa46f6`,
`verify_layer_v3` 2058-2279, `v3_zcd_point` 2280-2318, `build_claims_v3`,
`multiplicities_v3`, `HostTabsV3` and the shared v2/v3 helper builders,
`TamperV3`/`apply_tamper_v3`), `hashline/src/export_v3.rs` (`V3Witness`,
`derive_v3_with_table`, `requant_round`, `in_i16_class`, `in_rem_window`,
`matmul_i32_i8_i64`) -> `zkp-core/src/ffn_v3/{witness,prove,verify,tamper}.rs`
with `hashline::layer::{prove_layer_v3, verify_layer_v3}` as adapters
(build `Statement` and the borrowed `Witness` from `V3Witness`, choose the
pre-built W commitment through `wcache`, the backend through `gpu`, and
refuse `pcs_compact::selected()` unless the compact experiment keeps its
own prover). What blocks a mechanical move: `prove_layer_v3` (layer.rs 1455-2005),
`verify_layer_v3` (2058-2279), `v3_zcd_point` (2280-2318), `TamperV3`/
`apply_tamper_v3` (2319-2384). What blocks a mechanical move: (i) the
helper-column builders, `HostTabsV3`, the zero-check table construction
and `eval_many` that the v2 and v3 provers share inside `layer.rs`; (ii)
three further `Backend` hooks (`dev_helpers` + `dev_commit_from`,
`dev_zerocheck` / `dev_zerocheck_blocks`, `dev_eval_many`) with the
`dev_reserve` "fall back here or not at all" discipline (layer.rs 1576-1604),
to be wired with the `gpu/cuda.rs` owner; G2 (the GPU frozen digest) is that
step's gate; (iii) a ruling on the compact arm (`pcs_compact::selected()` at
the W/A/H commits and the batched opening, layer.rs 1499-1502, 1541, 1644,
1986-1988, 2246-2250): either the `--pcs compact` experiment keeps its own
copy of the v3 prover as a declared temporary duplicate (source pin,
differential test, owner, convergence milestone) or the core prover takes a
commitment strategy; (iv) `export_v3::V3Witness` split into borrowed planes
(the core's `Witness`) and the loader with its sidecar digests. The old/new
proof-byte parity test (D1: hashline's `prove_layer_v3` bytes ==
`zkp_core::ffn_v3::prove` bytes on the seeded T2/d16/f16 and T32/d16/f16
witnesses; D2 cross-verification; D3 the eight tamper legs with identical
messages) and the tiny `examples/tiny_prove_verify.rs` land with 2c; until
then the core has no FFN prover and CL20 stays open.

Codex owned the first primitive move and its compatibility validation; Fable
owns `zkp-core/` and the PCS/FFN adapters; shared boundaries receive review
before integration. Experiments, CLI tools, alternate proof paths and all
existing reports remain in their original projects. New protocol behavior
belongs in a separate change with its own profile/version and tests.
