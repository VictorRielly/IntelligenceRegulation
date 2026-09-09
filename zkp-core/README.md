# Minimal ZKP core

Status: **primitives and the Ligero commitment extracted; complete FFN path
pending**. The crate owns field arithmetic, NTT, Merkle trees, transcripts,
randomness, multilinear helpers, sumcheck and the Ligero-form polynomial
commitment (`pcs`: plain and hiding commit / open / verify) behind a narrow
backend seam (`pcs::Backend` / `pcs::EncodedStore`) that hashline's CUDA
code implements outside the core. `hashline` imports these canonical types
through compatibility exports. Default builds use only `blake3` and `rayon`;
they need no GPU or model files. All 22 moved tests pass (19 primitive, 3 PCS).

```sh
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 cargo test --release --offline \
  --manifest-path zkp-core/Cargo.toml --all-targets -- --test-threads=2
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 cargo run --release --offline \
  --manifest-path zkp-core/Cargo.toml --example public_sumcheck
```

The example verifies a public dot-product sumcheck, including the terminal
relation and an altered-round refusal. It is a primitive example. The
complete FFN relation and bounded proof decoding are still in the migration
queue; this crate does not yet implement a complete ZKP. Inherited CFS helpers
and the hiding commitment retain the unresolved privacy obligations of the
legacy protocol (the FFN masking disclosure is not repaired by moving code).

[MIGRATION.md](MIGRATION.md) records the exact source boundary, compatibility
rules and next extraction. [DESIGN.md](DESIGN.md) preserves Fable's initial
design and the remaining work. Existing experiments stay in their current
projects. Victor requested this lower-priority work on 2026-09-07. The contract is
[CL20 in Fable's queue](../docs/zkmatrix-poc/ZK60_FABLE_QUEUE.md#cl20--create-and-maintain-a-minimal-refactored-zkp-subproject),
with status tracked in [the task manifest](../docs/zkmatrix-poc/zk60_fable_tasks.json).

The intended result is a small, maintained Rust library for implementing and
testing the selected ZKP path. Existing `hashline`, `zkmatrix-rs`, experiments,
benchmarks, reports and alternative designs remain available. The small core
should be a dependable starting point for future implementations without
requiring readers to understand every historical experiment.

## Full extraction contract

Before extraction, record the exact supported statement/profile, parameters,
proof format and security status. Select a complete currently implemented
proof/verification path and migrate it incrementally. Existing private FFN
diagnostics establish a privacy defect at the tested profiles; reorganizing
the source cannot make that construction reviewed or repaired. Carry those
regressions and limits forward. Keep the reviewed protocol-repair work and
mechanical refactoring in separate commits with explicit version boundaries.

The expected library surface is field/extension arithmetic, transcript and
randomness, polynomial/NTT and Merkle primitives, the selected commitment and
sumcheck implementation, typed statement/proof objects, prove/verify entry
points and bounded encoding/decoding for that profile. The actual dependency
inventory determines the modules; this list is not permission to invent a
second proof system or remove required constraints.

Default builds should need neither CUDA nor model downloads, CLI/export
plumbing, campaign tooling or unused backends. Inputs and parameters should
be explicit. Keep hardware and legacy application integration in narrow
adapters, introduced only for a real consumer.

## Source boundaries found during the queue review

At integrator baseline `44d72ff`:

- `hashline/src/pcs.rs` depends on `zk::ZkRng` and contains GPU storage and
  dispatch; copying it alone does not produce a standalone core.
- `hashline/src/sumcheck.rs` also depends on `zk::ZkRng`; randomness needs a
  coherent lower-level home with unchanged domains and consumption order.
- `hashline/src/layer.rs` combines statement/layout definitions with compact
  PCS selection, cache use, export assumptions and GPU execution.
- `hashline/src/zk.rs` combines configuration/randomness, masking, layouts,
  serializers and multiple FFN proof paths. Those responsibilities need
  explicit boundaries rather than a renamed copy of the whole file.

Use this inventory to define a small dependency graph. Prefer making the
extracted code canonical and having existing applications consume it.
Temporary duplicates require source pins, differential checks, a named
maintenance owner and a convergence milestone. Do not make `zkp-core` a
wrapper whose default dependency is the entire experimental application.

## Delivery sequence

1. After the CL17 baseline is validated, pin the extraction source and
   publish the support/dependency/API matrix. Design can start earlier.
2. Introduce the crate manifest and extract a small coherent primitive
   boundary, preserving existing callers through adapters.
3. Move one vertical proof/verification path, with a tiny runnable example
   and bounded byte decoding. Keep its existing privacy classification.
4. Compare seeded proof bytes and verification outcomes across old/new
   implementations; retain fresh-randomness, tamper and disclosure tests.
5. Add a short independent build/test command and gate it alongside legacy
   compatibility. Record module/dependency reductions and remaining adapters.
6. Document promotion of future reviewed repairs and how experiments stay
   outside the maintained core. Keep one source of truth per primitive.

CL20 remains open until the selected full proof path, bounded codec, examples,
tests and compatibility adapters work. The primitive crate completes an
incremental boundary, not that entire task.

## Design phase (2026-09-07)

Historical pre-extraction design: [DESIGN.md](DESIGN.md) records, against
integrator baseline `52a13d1`, the chosen first extraction profile (the
non-hiding v3 FFN layer proof, parity gate `5f368db6…` / 70,758,084 B, privacy
class P0), the measured dependency closure of that profile before and after
the planned cuts, the couplings that block a clean cut with `file:line`
evidence, the proposed module layout and public API, the transcript/RNG/byte
constraints and differential tests, the default dependency closure, the
migration ledger template and the maintenance policy. The graph is generated
by `tools/dep_closure.py` (standard library only) into
`dependency_graph.json`; re-run it after every extraction step and diff.
