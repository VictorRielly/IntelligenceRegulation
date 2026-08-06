# Internal source map

No external source was needed for the findings; the decisive contradictions
and attack evidence are in the repository itself.

## Security and rejection sampling

- `zkmatrix-rs/src/ring/ct_engine.rs:1343-1495` — ARP parameters, `t = 1.5`,
  single/joint rejection calls.
- `zkmatrix-rs/src/ring/mod.rs:920-1015` — Gaussian sampler and rejection
  implementation.
- `docs/zkmatrix-poc/Q4_LEMMAS.md:143-173` — joint rejection lemma and
  `t = 12` statistical-defect calculation.
- `zkmatrix-rs/src/bin/ring_matmul.rs:14526-14620` — LKP-9 freeze of the fast
  ARP operating point.

## Multi-wave composition and size

- `zkmatrix-rs/src/ring/ct_engine.rs:378-399` — complete `CtRoundProof` fields.
- `zkmatrix-rs/src/ring/ct_engine.rs:1532-1725` — wave planning and linear
  claim splitting.
- `zkmatrix-rs/src/bin/ring_matmul.rs:12630-14170` — layer plan, partial
  reveals, wave proving/verifying, and proof dropping.
- `zkmatrix-rs/src/bin/ring_matmul.rs:13050-13078,14408-14418` — incomplete
  transcript cost fields/printing.
- `PROGRESS_UR.md:90-146` — recorded layer measurements and reveal counts.
- `PROGRESS_UR.md`, D-1 — explicit partial-scalar design decision.

## Verifier and freshness boundary

- `zkmatrix-rs/src/ring/gkr_masked.rs:197-213` — release-source deep copy.
- `zkmatrix-rs/src/ring/gkr_masked.rs:785-797` — move-by-value proving API.
- `zkmatrix-rs/src/ring/gkr_masked.rs:940-1050` — optional mask-pin checks.
- `zkmatrix-rs/src/ring/mod.rs:732-800` — OS/test prover RNG and private nonce.
- `zkmatrix-rs/src/bin/ring_matmul.rs:8688-8757` — E3Z-N1 accepts a doctored
  false lookup with `pin=false` and rejects with `pin=true`.
- `zkmatrix-rs/src/bin/ring_matmul.rs:9360-9885` — dirty U-S1 byte format,
  verifier, and battery.
- `PROGRESS_US.md` — unfinished Phases 1–3 and intended full artifact.

## Statement and computation scope

- `zkmatrix-rs/src/manifest.rs:159-255` — bare `ClaimManifest::digest`.
- `zkmatrix-rs/src/manifest.rs:865-883` — manifest v2 lookup table semantics.
- `zkmatrix-rs/src/bin/structured_matrix.rs:3646` and
  `zkmatrix-rs/src/bin/lattice_matmul.rs:3212,3865` — remaining bare digest
  call sites.
- `zkmatrix-rs/src/bin/ring_matmul.rs:10858-10880` — U-K8 activation-chain
  statement.
- `zkmatrix-rs/src/bin/ring_matmul.rs:13397-13420` — U-R layer statement.
- `zkmatrix-rs/src/bin/ring_matmul.rs:13715-13865` — local range-table prehash
  binding outside Statement semantics.
- `docs/zkmatrix-poc/TARGET_CONTRACT.md:56-126` — stated privacy, size,
  latency, and implementation status.
