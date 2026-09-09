# Migration ledger

Two boundaries are implemented: the primitives (round 11, Codex) and the
Ligero commitment behind a backend seam (round 12, Fable). Each section
records its source pin, what moved, what the adapters keep, the validation
and the before/after surface; the next boundaries follow at the end.

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

## Next boundaries for Fable, in order

1. ~~Extract PCS types and the CPU commit/open/verify path behind a narrow
   backend interface.~~ Done above (round 12).
2. Move table registration and typed v3 statement/witness/layout/proof pieces,
   then the selected P0 FFN path and bounded encoding/decoding. Keep the current
   table registry and digest validation; an arbitrary opaque digest must not
   replace the verifier's table semantics.
3. Add tiny old/new FFN proof-byte comparisons and decoder refusals, then keep
   the four complete frozen artifacts and public receipt gates. Preserve both
   compact and GPU consumers; no backend is retired as a side effect.
4. Extract the versioned masking repair only with its reviewed invariants and
   privacy classification. A P0 FFN example alone does not close CL20.

### The next step in detail (boundary 2, in three pieces)

**2a, table registry.** `hashline/src/tables_v3.rs` (`Act16Fn`, the 15
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

**2b, typed v3 pieces.** From `layer.rs` (lines 1225-1404 at `cfa46f6`):
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

**2c, the P0 prover/verifier.** `prove_layer_v3` (layer.rs 1455-2005),
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
