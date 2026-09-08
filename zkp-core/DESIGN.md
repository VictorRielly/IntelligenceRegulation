# zkp-core — design of the minimal maintained ZKP library (CL20, design phase)

**Round-11 update:** the primitive boundary is now implemented; see
[MIGRATION.md](MIGRATION.md). The remainder of this document is the original
source-pinned design. Its projected cuts and API are not all implemented.

Status: **DESIGN PHASE, 2026-09-07. No code has been moved. No manifest exists.**
Written against integrator baseline `52a13d1` (branch `zk60-cl20-core`) by the
Fable refactoring lane; Codex reviews the shared-core boundaries. This document
answers, from the source rather than from memory, three questions Codex's
[README scaffold](README.md) leaves open: which proof path is extracted first,
what it actually drags along today, and what the extracted library's shape and
byte-preservation obligations are. Source extraction waits for the validated
CL17 baseline (queue: [CL20](../docs/zkmatrix-poc/ZK60_FABLE_QUEUE.md#cl20--create-and-maintain-a-minimal-refactored-zkp-subproject)).

Companion files, both in this directory:

- `tools/dep_closure.py` — stdlib-only script that reads every `hashline/`
  source file and emits the module dependency graph with `file:line` evidence,
  `#[cfg(feature = "gpu-cuda")]`-gated and `#[cfg(test)]`-only edges kept
  apart, per-module line counts, external-crate and `std::env::var` use, and
  the transitive closure of a root set before and after a list of planned cuts.
- `dependency_graph.json` — its output at `52a13d1` (deterministic; re-run
  with `python3 zkp-core/tools/dep_closure.py` from the repo root, no build).

Every coupling claim below carries `file:line` evidence from that graph or
from `grep`; the lines are at `52a13d1` and will drift as lanes land, which is
why the tool exists.

---

## 1. Purpose and boundary

`zkp-core` is the small Rust library that implements and tests ONE selected,
currently implemented prove/verify path of the hash-based line — its field and
extension arithmetic, transcript and randomness, NTT and Merkle primitives, the
Ligero-form commitment and the sumcheck, typed statement and proof objects,
prove/verify entry points and a bounded byte codec — with CPU-only defaults,
explicit parameters, no CUDA, no model download, no CLI. It is the dependable
starting point for future implementations and the one source of truth for
each primitive it contains: `hashline`, `zkmatrix-rs`, the experiments, the
benchmarks and the reports all remain, and the existing `hashline` paths become
adapters that import from the core rather than keeping copies. It is not a new
proof system, not a privacy repair, not a throughput claim, and not a wrapper
whose default dependency is the whole experimental application (README,
"Source boundaries"; queue CL20 "Limits").

## 2. The first extraction profile: candidates, choice, honest classification

Four complete, currently implemented paths have frozen byte fixtures. The
closures below are the tool's default-build closures (normal edges only) of
each path's entry module set; the code-line figures exclude `#[cfg(test)]`.

| | entry points | CLI reproduction and frozen fixture | modules pulled in today | randomness | privacy class | bounded decoder today |
|---|---|---|---|---|---|---|
| (i) **non-hiding v3 FFN layer proof** | `layer::prove_layer_v3` (layer.rs:1455), `layer::verify_layer_v3` (2058), `layer::v3_zcd_point` (2280) | `hashline pass 12 512 --profile v3 --export <m125_v3_export>`; sha256 **`5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d`**, **70,758,084 B** (results/an_floors.sh:63; results/zk60_round8_validation.json:353-358) | 18 modules / 8,781 lines literally (`zk` enters through `pcs`; `chain`, `export`, `export_v3`, `gpu`, `pcs_compact`, `wcache` through `layer`); **10 modules / 3,934 lines after the cuts of section 4** | none — the proof is a deterministic function of (witness, params, transcript domain) | **P0: not zero-knowledge.** W, A and H are committed but nothing is hidden; soundness class (3/4)^256 = 2^-106 (pcs.rs:16-20) | `to_bytes` only (layer.rs:1356); no `from_bytes` |
| (ii) plain v2 (125M fixed shapes) | `layer::prove_layer` (463), `verify_layer` (880) | `hashline pass 12 512`; `50cf7bdfd6b5b182…`, 66,844,928 B | same as (i) minus `export_v3`/`tables_v3`, plus the v2 constants `D`/`F`/`T`/`LAYERS` (export.rs:13-16) and `chain::LayerWitness` (chain.rs:19) | none | P0 | none |
| (iii) hiding ZK v3 (mode P1, seed 1) | `zk::prove_layer_zk_v3` (zk.rs:2338), `verify_layer_zk_v3` (3472) | `hashline pass 12 512 --zk --seed 1 --profile v3 --export …`; `40eb54795e023c77…`, 87,697,008 B | (i) plus `zk` (3,268 code lines: header/mode/predicate, `ZkRng`, mask commitment, masked sumchecks, two FFN proof paths, serializers) and its device arms | `ZkRng` seeded from `(seed, "layer-v3-{l}")` (zk.rs:2367, 357-363) or OS entropy (367-388) | **P1 claimed; KNOWN DEFECT**: the singleton A-opening groups disclose X (p2) and h16 (p5) — full recovery at T2, one linear functional per column at T32, verified P1 and P3, fixture and fresh-OS randomness ([ZK60_FFN_MASK_DIAGNOSTIC.md](../docs/zkmatrix-poc/ZK60_FFN_MASK_DIAGNOSTIC.md)); the **P3 identity gap** (tests/zk60_identity_gap.rs:160) | none |
| (iv) public block receipts B3/B4/B5 | `public_block_receipt::verify_public_receipt_bytes` (public_block_receipt.rs:350), `public_chain_receipt` | `results/zk60_round4_receipt.proof` `ba5d8215…` 2,144,946 B; B5 `30f9c105…` / `264a2cf4…` 4,290,981 B ([ZK60_PUBLIC_RECEIPT.md](../docs/zkmatrix-poc/ZK60_PUBLIC_RECEIPT.md), [ZK60_PUBLIC_CHAIN.md](../docs/zkmatrix-poc/ZK60_PUBLIC_CHAIN.md)) | (i) plus `attention` (2,872 lines), `causal_oracle`, `norm`, `tables_attn`, `private_block_contract` (which imports `zk::ZkStatementMode`, private_block_contract.rs:26), `public_block_oracle/wire/receipt/chain_receipt` | none | P0, tiny public synthetic block (T32/d16/f16) | **yes**: `public_block_wire::decode_components` (public_block_wire.rs:508) with fixed bounds (12-21) |

**Recommendation: (i), the non-hiding v3 FFN layer proof.** Reasons, in
order of weight:

1. It is the smallest closure that exercises every primitive the README names
   (field, NTT, Merkle, transcript, Ligero PCS, sumcheck, statement/layout,
   codec). After the section-4 cuts it is 10 modules and under 4,000 code lines.
2. It is the base the other three stand on. The ZK form imports the v3
   statement, layout, tags and remainder helpers from it (`zk.rs:2013`); the
   public block calls `prove_layer_v3`/`verify_layer_v3`/`v3_zcd_point`
   directly (`public_block_oracle.rs:11`, `public_block_receipt.rs:8`); the
   identity boundary types itself on `StatementV3` (`model_identity.rs:26`).
   Extracting it first makes (iii) and (iv) *consumers* of the core, which is
   the direction the README asks for.
3. It is deterministic. With no randomness in the path, "seeded proof bytes
   identical" degenerates to "proof bytes identical", the strongest possible
   differential gate, and the frozen 12x512 digest already runs on both the
   CPU and GPU binaries in every floors script (results/an_floors.sh:60-65).
4. It is not the defective construction. Extracting (iii) first would make
   the maintained library's headline path a known-defective one while its
   repair is FA-track work; Codex's README says reorganisation cannot make that
   construction reviewed or repaired. (iii) is the *second* vertical, taken
   either after the repair lands or explicitly limitation-classified, and its
   disclosure/identity tests move with it unchanged.

Why not the others: (ii) is fixed-shape 125M legacy (`export.rs:13-16`) that
the 8B line superseded and that nothing else builds on — it stays a legacy
gate, not the core. (iv) is a strict superset of (i) plus the attention half of
the layer, and the queue says a public-only example is not completion.

**Honest classification of the chosen profile.** It proves the exact
int8-weights / int16-activations FFN relation of one transformer FFN layer
(gate/up matmuls, the activation-table lookup, the Hadamard product, the down
matmul, signed-shift requantisation with balanced remainders, every range fact
by LogUp) against three Ligero commitments. Nothing is hidden: it is attested
computation over a committed witness, not zero-knowledge. Supported shapes are
exactly what `LayoutV3::new` accepts (layer.rs:1284-1290): `t_rows` a power of
two; `d`, `f` with `16 | d, f` and blocks of `2^min(log2 d, 12)`; shifts in
`-8..=16` (`tag_rem_v3`, 1231); the activation table a registered `Act16Fn`
member (tables_v3.rs:27-93) whose sha256 spec digest is absorbed as a string.

**The parity gates that become the core's contract:**

| gate | what | how it is run | class |
|---|---|---|---|
| G1 | `pass 12 512 --profile v3` → `5f368db6240e0614…` / 70,758,084 B, with `--threads 8 --log-cols 14 --inv-rate 4 --col-checks 256` (defaults, hashline/README.md), transcript domain `hashline-pass-v3` (bin/hashline.rs:968), twelve `LayerProofV3::to_bytes` concatenated in layer order and sha256'd (1013-1016) | the floors scripts on the WSL box; needs the worktree-local `m125_v3_export` (`*.bin` is gitignored) | heavy, authoritative |
| G2 | the same digest with `HL_GPU=1` on the `gpu-cuda` binary | same scripts | heavy; proves the backend seam preserved bytes |
| G3 | small synthetic fixtures (T2/d16/f16 and T32/d16/f16, the shapes the diagnostics already use, plus `causal_oracle::public_synthetic_fixture`) — proof bytes recorded from the `hashline` baseline at extraction time | `cargo test --offline --manifest-path zkp-core/Cargo.toml` | fast, isolated; the digests are frozen in the ledger when step 3 lands |
| G4 | the legacy gates that must stay green untouched: v2 `50cf7bdf…`, zk `021485e4f80ec695…` (87,228,528 B), zkv3 `40eb5479…`, receipts `ba5d8215…`, `30f9c105…`, `264a2cf4…` | floors scripts, `cargo test --release` in hashline, the receipt examples | heavy/medium; "nothing else moved" |

## 3. Dependency inventory (generated; regenerate with the tool)

Crate totals at `52a13d1`: **35 library modules, 20,102 code lines** (2,417
inside `#[cfg(test)]`, 2,426 inside `gpu-cuda` gates), a 1,614-line binary,
14 integration-test files, 4 examples. `gpu/kernels.cu` (1,352 lines of CUDA)
is compiled at runtime by NVRTC and is not counted.

### 3.1 Closures of the chosen root set `{layer, tables_v3}`

| closure | modules | code lines | excluding tests |
|---|---:|---:|---:|
| literal (normal + gpu + not-gpu edges) | 18 | 10,084 | 8,781 |
| default build (no `gpu-cuda`) | 18 | 10,084 | 8,781 |
| **after the planned cuts (section 4)** | **10** | **4,560** | **3,934** |

The literal and default closures coincide because every module the GPU arms
reach is already reached by an ungated edge. How each module enters the
literal closure (`entry_via` in the JSON): `zk` through `pcs`; `chain`,
`export`, `export_v3`, `gpu`, `pcs_compact`, `wcache` through `layer`;
`phase_profile` through `chain`; `silu` through `tables_v3`; `merkle` through
`pcs`. After the cuts the members are exactly `field`, `ntt`, `merkle`,
`transcript`, `mle`, `sumcheck`, `pcs`, `layer`, `tables_v3` and `silu` — the
last only for the five-line `hex` helper (`tables_v3.rs:127` → `silu.rs:45`),
which moves into the core.

### 3.2 Module table

Generated by `dep_closure.py` at `52a13d1` (`--md -`). "depends on" lists
`use crate::…`/inline `crate::…` targets; "gpu-only" are targets reached only
inside `gpu-cuda` gates; "test-only" only inside `#[cfg(test)]`.

| module | class | code lines (test / gpu-gated) | externals | env vars | depends on (normal) | gpu-only | test-only |
|---|---|---:|---|---|---|---|---|
| `field` | core | 290 (81 / 0) | (std only) | - | - | - | - |
| `ntt` | core | 141 (41 / 0) | (std only) | - | `field` | - | - |
| `merkle` | core | 70 (17 / 0) | blake3, rayon | - | - | - | - |
| `transcript` | core | 135 (21 / 0) | blake3 | - | `field` | - | - |
| `mle` | core | 208 (44 / 0) | rayon | - | `field` | - | - |
| `sumcheck` | core | 418 (174 / 0) | rayon | - | `field`, `mle`, `transcript`, **`zk`** | - | - |
| `pcs` | core | 1072 (218 / 46) | blake3, rayon | HL_TIMING | `field`, `merkle`, `mle`, `ntt`, `transcript`, **`zk`** | **`gpu`** | - |
| `layer` | core (statement/layout/prove/verify; adapters mixed in) | 2034 (2 / 147) | rayon | HL_AL_I8FOLD, HL_AL_POOL, HL_CONV_VERBOSE | **`chain`, `export`, `export_v3`**, `field`, **`gpu`**, `mle`, `ntt`, `pcs`, **`pcs_compact`**, `sumcheck`, `tables_v3`, `transcript`, **`wcache`** | `merkle` | - |
| `tables_v3` | core (table registry: the frozen statement digests) | 132 (15 / 0) | sha2 | - | `silu` | - | - |
| `zk` | application (ZK FFN paths) + primitive (`ZkRng`, to move to core `rng`) | 3268 (342 / 205) | blake3, rayon | HL_GPU_VERBOSE, HL_TIMING, HL_ZK_DRAIN | `chain`, `export`, `export_v3`, `field`, `layer`, `merkle`, `mle`, `ntt`, `pcs`, `sumcheck`, `transcript`, `wcache` | `gpu` | `tables_v3` |
| `gpu` | adapter (device dispatch; stub without the feature) | 56 (0 / 9) | (std only) | - | - | - | - |
| `gpu::cuda` | adapter (cudarc backend; feature gpu-cuda) | 2023 (0 / 2013) | cudarc, rayon | HL_BENCH_ROWS, HL_GPU_CHUNK_BYTES, HL_GPU_CHUNK_ROWS, HL_GPU_FUSE_GATHER, HL_GPU_NARROW, HL_GPU_NTT_FAST, HL_GPU_NTT_THREADS, HL_GPU_PAD_SKIP, HL_GPU_PIN_MB, HL_GPU_PRUNE_P2, HL_GPU_STREAM_COMMIT | - | `field`, `merkle`, `ntt`, `pcs`, `sumcheck`, `transcript` | - |
| `wcache` | adapter (per-model weight-commitment cache) | 299 (43 / 6) | blake3, rayon | HL_WCACHE_VERBOSE | `field`, `merkle`, `ntt`, `pcs` | `gpu` | - |
| `export` | adapter (v2 125M export loader, fixed shapes) | 98 (0 / 0) | sha2 | M125_EXPORT_DIR | `silu` | - | - |
| `export_v3` | adapter (v3 export loader + witness derivation) | 382 (50 / 0) | rayon, sha2 | HL_EXPORT_DIR | `chain`, `phase_profile`, `silu`, `tables_v3` | - | - |
| `chain` | adapter (v2 exact integer chain / witness) | 169 (60 / 0) | rayon | - | `export`, `phase_profile`, `silu` | - | - |
| `silu` | adapter (v2 SiLU table registry; `hex`) | 60 (13 / 0) | sha2 | - | - | - | - |
| `phase_profile` | adapter (timing instrumentation) | 144 (31 / 0) | (std only) | - | - | - | - |
| `pcs_compact` | experiment (BaseFold-class compact PCS, `--pcs compact`) | 1108 (151 / 0) | blake3, rayon | HL_TIMING | `field`, `merkle`, `mle`, `ntt`, `pcs`, `transcript` | - | - |
| `attention` | application (attention half of the layer) | 2872 (29 / 0) | rayon, sha2 | HL_ATTN_CLAIMS, HL_FOLD, HL_NO_FOLD | `attention_schedule`, `field`, `layer`, `mle`, `norm`, `ntt`, `pcs`, `silu`, `sumcheck`, `tables_attn`, `transcript` | - | - |
| `attention_schedule` | application (public execution metadata) | 241 (0 / 0) | blake3 | - | `attention` | - | - |
| `norm` | application (RMSNorm gadget) | 196 (35 / 0) | (std only) | - | - | - | - |
| `tables_attn` | application (attention tables) | 133 (25 / 0) | sha2 | - | `silu` | - | - |
| `causal_oracle` | application (fixed causal block oracle) | 653 (0 / 0) | blake3 | - | `attention`, `export_v3`, `field`, `layer`, `merkle`, `norm`, `ntt`, `pcs`, `private_block_contract`, `silu`, `tables_attn`, `tables_v3`, `zk` | - | - |
| `public_block_oracle` | application (public P0 block) | 215 (0 / 0) | (std only) | - | `attention`, `causal_oracle`, `field`, `layer`, `merkle`, `ntt`, `pcs`, `private_block_contract`, `transcript` | - | - |
| `public_block_wire` | application (bounded public-block codec) | 568 (0 / 0) | (std only) | - | `attention`, `field`, `layer`, `merkle`, `pcs`, `public_block_oracle`, `sumcheck` | - | - |
| `public_block_receipt` | application (B3/B4 receipt) | 324 (0 / 0) | blake3 | - | `attention`, `causal_oracle`, `field`, `layer`, `merkle`, `mle`, `ntt`, `pcs_compact`, `private_block_contract`, `public_block_oracle`, `public_block_wire`, `transcript` | - | - |
| `public_chain_receipt` | application (B5 two-block chain receipt) | 344 (0 / 0) | blake3 | - | `causal_oracle`, `merkle`, `private_block_contract`, `public_block_receipt` | - | - |
| `private_seam` | experiment (one-shot private equality gadget) | 665 (0 / 0) | blake3 | - | `field`, `merkle`, `mle`, `ntt`, `pcs`, `sumcheck`, `transcript`, `zk` | - | - |
| `private_block_contract` | application (P1 block metadata preflight) | 467 (0 / 0) | blake3 | - | `attention`, `export_v3`, `layer`, `merkle`, `norm`, `pcs`, `silu`, `tables_attn`, `tables_v3`, `transcript`, `zk` | - | - |
| `model_identity` | application (opt-in P1 approval boundary) | 243 (0 / 0) | (std only) | - | `field`, `layer`, `ntt`, `pcs`, `tables_v3`, `transcript`, `zk` | - | - |
| `zk::mask_diagnostic` | test-only (the FFN disclosure diagnostic; a LIMITATION test) | 567 (559 / 0) | (std only) | - | - | - | `export_v3`, `pcs`, `tables_v3` |
| `wcache::atomic_tests` | test-only | 225 (221 / 0) | blake3 | - | - | - | - |
| `field::verifier_hardening_tests` | test-only | 252 (245 / 0) | blake3 | - | - | - | `attention`, `causal_oracle`, `chain`, `export`, `field`, `layer`, `ntt`, `pcs_compact`, `public_block_oracle`, `public_block_wire`, `transcript` |

Consumers outside the library (from the same run): the binary reaches 16
modules including `zk`, `wcache`, `pcs_compact`, `gpu`, `phase_profile`; the
tests that call the v3 prover directly are `zk60_public_block`,
`zk60_public_receipt`, `zk60_public_chain` (via `layer::prove_layer_v3`,
`v3_zcd_point`); `cli_claims` reaches no library module (it drives the binary).

### 3.3 The couplings that block a clean cut, with evidence

**`pcs.rs` (core) → `zk::ZkRng`.** `commit_zk` and `commit_zk_owned` take
`rng: &mut crate::zk::ZkRng` (pcs.rs:615, 620); the device form too (674,
gated). The RNG is defined in zk.rs:346-437 with its key derivation
`blake3("hashline-zk-rng/" || domain || seed_le)` (357-363), the OS form
`blake3_keyed(entropy)("hashline-zk-os-rng/v1/" || domain)` (381-388), 8,192-
byte XOF blocks (`RNG_BLOCK`, 353; `refill`, 390-398), and the draw order
inside `commit_zk` (pads first, `rng.fp_vec(rows*q)`, then `nn` salts of
`bytes32()`, 627-628; the device form draws in the same order, 677-679).
`ZkConfig::rng` (334-340) chooses seeded vs OS. **Cut:** move lines 346-437 to
`zkp_core::rng` verbatim; `hashline::zk` re-exports `pub use zkp_core::rng::ZkRng`.

**`pcs.rs` → `gpu`.** The `Store::Device(crate::gpu::DevCommit)` variant
(66-67), `commit` device attempt (159-161), `fold_rows_multi` device arm
(261-262), `open` column gather (356-358), `commit_zk_owned` device attempt
(632-634), `commit_zk_device` (673-682), `open_zk` fold (847-851) and gather
(921-923). All gated; the CPU body is always present and is the oracle
(gpu/mod.rs:7-14, "differential discipline"). Also in `pcs.rs`: the
`HL_TIMING` env read (316) and the `thread_local! LAST_SITES` mask-site
recorder with `assert_mask_sites`/`last_mask_sites` (864-890), diagnostic
state living in production code. **Cut:** a `Backend` seam (section 4.3);
timing returned, not printed; the recorder behind `#[cfg(test)]` or a feature.

**`sumcheck.rs` (core) → `zk::ZkRng`.** One site: `CfsMask::random(rng: &mut
crate::zk::ZkRng, …)` (201). `CfsMask`/`CfsMasker`/`extension_round`/
`masked_terminal` (185-315) are the masking primitive used by `zk.rs` (32
references) and `private_seam.rs` (5); they stay in the core sumcheck module
because they are transcript-level machinery (the `RoundMask` hook is in
transcript.rs:12-15). **Cut:** the parameter type becomes `rng::ZkRng`.

**`layer.rs` (core) → `pcs_compact`.** Imported at 28; the selection global
`pcs_compact::selected()` reads `static CFG: Mutex<CompactCfg>`
(pcs_compact.rs:109-118), set by the CLI (bin/hashline.rs:203). In the v3
prover: W commit selection 1499-1502, A commit through `pcs_compact::commit`
1541, H 1644, the batched opening 1986-1988; verifier arms 2246-2250. When not
selected, `pcs_compact::commit` is exactly `AnyCm::Ligero(pcs::commit(…))`
(pcs_compact.rs:480), so calling `pcs::commit` directly is byte-identical.
**Cut:** the core calls `pcs::commit`; the compact PCS stays in `hashline` as
an experiment with its own `--pcs compact` gate.

**`layer.rs` → `wcache`.** `crate::wcache::commit_w(&w_pcs, &w_data, ntt,
&WKey::new("v3", l, d, f, wg_t, wu_t, wd_t))` (1502; v2 at 497). With no cache
directory configured (`static DIR: OnceLock`, wcache.rs:56; `configure`, 60;
set by the CLI at bin:188) it is `pcs::commit` unchanged (wcache.rs:292).
**Cut:** the core's prover accepts an optional pre-built W commitment; the
cache stays an adapter that produces one.

**`layer.rs` → `gpu`.** One *ungated* edge: `dev_marks()` (445-449) reads
`crate::gpu::dev_stats()` for timing residuals. Gated: `dev_of` (453-460), the
device H commitment built from device helper columns (545-566; 1575-1604 for
v3), `HelperSpec`/`TabSpec` helper and zero-check dispatch (547, 696, 754,
1577, 1835, 1908) with CPU fallbacks under `#[cfg(not(...))]` (567, 715, 772,
1605, 1863, 1931). `merkle::MerkleTree` is imported only inside those blocks
(562, 1600). **Cut:** section 4.3's backend hooks; the timing residual becomes
a field of the returned timings.

**`layer.rs` → witness/loader modules.** `chain::LayerWitness` and
`export::{D, F}` (20-21; v2 only), `export_v3::V3Witness` and
`tables_v3::Act16Fn` (1225-1226), `chain` in `apply_tamper` (1090),
`export_v3` in `apply_tamper_v3` (2347-2352). `V3Witness` (export_v3.rs:323-
349) is a plain struct of `Vec<i8>`/`Vec<i32>` planes plus shape, shifts,
table and digests; its *derivation* `derive_v3_with_table` (361-413) is the
exact integer chain, wrapped in `phase_profile::measure` (367-369). **Cut:**
the witness type and the exact chain move to the core; the file loader,
sidecar digests and `HL_EXPORT_DIR` (export_v3.rs:91) stay an adapter.

**`layer.rs` process state and env switches.** `hostbuf` pool (`static POOL:
Mutex`, 355) toggled by `HL_AL_POOL` (361); `HL_AL_I8FOLD` selects between two
byte-identical fold implementations (399-401); `HL_CONV_VERBOSE` (441-443)
prints conversion timings. **Cut:** one fold implementation (the default), the
pool behind an explicit option, no `std::env` in the core.

**`tables_v3.rs` (core) → `silu::hex`** (127 → silu.rs:45). Five lines; moves.
`tables_v3` needs `sha2` for `table_spec_digest_int16out` (108-127), the
digest string absorbed into the transcript (layer.rs:1404). See section 6.

**`transcript.rs`, `field.rs`, `ntt.rs`, `merkle.rs`, `mle.rs`**: no
intra-crate coupling beyond `field`; they move as they are.

## 4. Proposed module layout and public API of `zkp-core`

### 4.1 Layout

```
zkp-core/
  Cargo.toml                  blake3, sha2, rayon; no cudarc; no default-features surprises
  src/lib.rs                  the module list below and nothing else
  src/error.rs                Error (typed; Display reproduces today's message strings)
  src/field.rs                <- hashline/src/field.rs verbatim (Fp, Fp2, batch inverses, P, GENERATOR)
  src/ntt.rs                  <- ntt.rs verbatim
  src/merkle.rs               <- merkle.rs verbatim
  src/transcript.rs           <- transcript.rs verbatim, RoundMask hook included
  src/rng.rs                  <- zk.rs:346-437 (ZkRng) verbatim: the randomness home
  src/mle.rs                  <- mle.rs verbatim
  src/sumcheck.rs             <- sumcheck.rs; CfsMask::random takes &mut rng::ZkRng
  src/pcs/mod.rs              <- pcs.rs: params, Slice, Claim, Commitment, Committed, Opening,
                                 commit/open/verify, hash_columns; the ZK forms (ZkOpts, CommittedZk,
                                 OpeningZk, ZClaim/ZPart, commit_zk*, open_zk, verify_zk, encode_row_zk,
                                 salt_leaf, coset_powers) stay here: same commitment, one source of truth
  src/pcs/backend.rs          Backend trait + Cpu (the only implementation in the core)
  src/tables.rs               <- tables_v3.rs (Act16Fn, members, digests, int16out_member) + hex
  src/ffn_v3/mod.rs           the profile: re-exports, DOMAIN_* constants
  src/ffn_v3/statement.rs     <- layer.rs:1228-1320 (TAG_ACT16/INT16, tag_rem_v3, rem_rows/value/index,
                                 pow2_signed, StatementV3 -> Statement, LayoutV3 -> Layout,
                                 absorb_statement_v3 -> Statement::absorb) and absorb_com/absorb_mults (194-205)
  src/ffn_v3/witness.rs       <- export_v3.rs:323-349 (the planes) + 276-320 & 361-413 (exact chain:
                                 matmul_i32_i8_i64, requant_round, in_i16_class, in_rem_window, derive)
  src/ffn_v3/proof.rs         <- LayerProofV3 (layer.rs:1321-1392) without cpcs_open; to_bytes verbatim;
                                 NEW shape-directed from_bytes (4.4)
  src/ffn_v3/prove.rs         <- prove_layer_v3 (layer.rs:1455-2005) minus the adapters (4.2)
  src/ffn_v3/verify.rs        <- verify_layer_v3 (2058-2279) minus the compact arm; zcd_point (2280-2318)
  src/ffn_v3/tamper.rs        <- TamperV3/apply_tamper_v3 (2319-2384), behind feature "testing"
  examples/tiny_prove_verify.rs   T2/d16/f16 synthetic layer: derive -> prove -> bytes -> decode -> verify
  tests/parity_fixtures.rs        G3: recorded digests of the synthetic fixtures
  tests/tamper_and_malformed.rs   the eight tamper legs; truncation/trailing/flip/non-canonical/oversize
  tests/codec_roundtrip.rs        encode(decode(b)) == b on every fixture
```

Naming: `Statement`/`Layout`/`Proof` are the v3 names with the suffix
dropped, because the crate has one profile; the `hashline` adapters keep their
current names as type aliases (`pub type StatementV3 = zkp_core::ffn_v3::Statement;`).

### 4.2 Entry points

```rust
// zkp_core::ffn_v3
pub const DOMAIN_LAYER: &[u8] = b"hashline-layer-v3";   // bin/hashline.rs:894
pub const DOMAIN_PASS:  &[u8] = b"hashline-pass-v3";    // bin/hashline.rs:968

pub struct Params { pub log_cols: u32, pub inv_rate: usize, pub num_col_checks: usize } // == LayerParams (layer.rs:49)
impl Params {
    pub fn ntt_tables(&self) -> NttTables;                 // NttTables::new(log_cols + log2 inv_rate), bin:919
    pub fn check(&self) -> Result<(), Error>;              // inv_rate a power of two; Q >= 1; log_cols in range
}

pub struct Statement {                                       // == StatementV3 (layer.rs:1257)
    pub layer: usize, pub t_rows: usize, pub d: usize, pub f: usize,
    pub shifts: (i32, i32, i32, i32),                      // (g, u, h, z), absorbed as i64 LE in this order
    pub act: tables::Act16Fn, pub table: [i16; 256], pub table_digest: String,
}
impl Statement {
    pub fn new(layer, t_rows, d, f, shifts, act, e_in, e_out) -> Result<Statement, Error>; // via tables::int16out_member
    pub fn layout(&self) -> Result<Layout, Error>;         // LayoutV3::new's asserts become Err(Error::Shape)
    pub fn absorb(&self, tr: &mut Transcript);             // == absorb_statement_v3 (layer.rs:1394-1404)
}

pub struct Witness<'a> {                                     // borrowed planes; the adapter owns the Vecs
    pub x: &'a [i8], pub wg_t: &'a [i8], pub wu_t: &'a [i8], pub wd_t: &'a [i8],
    pub g8: &'a [i32], pub rg: &'a [i32], pub a16: &'a [i32], pub u16: &'a [i32], pub ru: &'a [i32],
    pub h16: &'a [i32], pub rh: &'a [i32], pub z16: &'a [i32], pub rd: &'a [i32],
}
pub struct OwnedWitness { /* the Vec form; derive() returns it; as_ref() -> Witness */ }
pub fn derive(stmt: &Statement, x: &[i8], wg_t: &[i8], wu_t: &[i8], wd_t: &[i8]) -> Result<OwnedWitness, Error>;
    // the exact chain of export_v3::derive_v3_with_table; Err(Error::Range) where range_ok would be false

pub struct ProverOptions<'a> {
    pub backend: &'a dyn pcs::Backend,                     // &pcs::Cpu by default
    pub w_committed: Option<pcs::Committed>,               // a pre-built W commitment (the cache adapter's product)
    pub reuse_buffers: bool,                               // the hostbuf pool; byte-neutral by construction
}
impl Default for ProverOptions<'static> { /* Cpu, None, true */ }

pub struct ProveOutput { pub proof: Proof, pub timings: Vec<(String, f64)> }

pub fn prove(stmt: &Statement, w: &Witness, params: &Params, ntt: &NttTables,
             opts: &ProverOptions, tr: &mut Transcript) -> Result<ProveOutput, Error>;
pub fn verify(stmt: &Statement, proof: &Proof, params: &Params, ntt: &NttTables,
              tr: &mut Transcript) -> Result<(), Error>;
pub fn zcd_point(stmt: &Statement, proof: &Proof, before: &Transcript) -> Vec<Fp2>;   // == v3_zcd_point

// conveniences for a single layer (they build Transcript::new(DOMAIN_LAYER))
pub fn prove_single(stmt, w, params, opts) -> Result<ProveOutput, Error>;
pub fn verify_single(stmt, proof, params) -> Result<(), Error>;
```

The transcript is a parameter, not created inside, because the twelve-layer
pass chains one transcript across layers (bin/hashline.rs:968-988) and the
public block continues a block transcript (public_block_oracle.rs); the
convenience forms cover the example and the single-layer command. There is no
`rng` parameter in this profile: nothing in it draws randomness. The ZK
vertical, when it comes, adds `prove_zk(stmt, w, params, ntt, mode: &ZkMode,
rng: &mut rng::ZkRng, opts, tr)` beside it.

### 4.3 The backend seam

```rust
// zkp_core::pcs
pub enum Store { Host { encoded: Vec<Fp> }, External(Box<dyn EncodedStore>) }   // replaces Store::Device
pub trait EncodedStore: Send + Sync {
    fn rows(&self) -> usize;
    fn fold_rows(&self, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>>;      // == gpu::dev_fold_rows
    fn columns(&self, idx: &[usize]) -> Vec<Vec<Fp>>;             // == gpu::dev_columns
}
pub trait Backend: Sync {
    /// Encode and hash the rows elsewhere. None = decline (the CPU body runs, as today's Err arms do).
    /// Any implementation MUST return the same leaves the CPU encoder would (gpu/mod.rs:7-14).
    fn try_commit(&self, p: &PcsParams, data: &[Fp], ntt: &NttTables) -> Option<Result<(Box<dyn EncodedStore>, Vec<Digest>), String>> { None }
    fn try_commit_zk(&self, p: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Option<Result<(Box<dyn EncodedStore>, Vec<Digest>), String>> { None }
    // layer-level accelerations, all default None (CPU): helper columns, zero-check tables,
    // many-point evaluation; signatures follow gpu::{dev_helpers, dev_zerocheck, dev_eval_many}
}
pub struct Cpu;
impl Backend for Cpu {}
```

`hashline::gpu` implements `EncodedStore` for `DevCommit` and `Backend` for a
`CudaBackend` behind its existing `gpu-cuda` feature; the runtime switch
`HL_GPU=1` and `gpu::enabled()` move into the CLI's choice of `&dyn Backend`.
The core has no `#[cfg(feature = "gpu-cuda")]` anywhere. The layer-level hooks
are the invasive part (layer.rs:545-566, 1575-1604 build a device H commitment
from device-resident helper columns); they land as trait methods with CPU
defaults in step 2 and the CUDA implementation is wired in a separate
coordinated step with the `gpu/cuda.rs` owner (one writer owns cuda.rs,
kernels and PCS — queue, "Execution order and ownership"). G2 is that step's gate.

### 4.4 Proof object and bounded codec

`Proof::to_bytes` is the frozen inner encoding (layer.rs:1356-1391): three
commitments as `root[32] | rows u64 | log_cols u32`; multiplicity tables as
`tag u64 | len u32 | u32*`; then `gu_claims, gu_sc, gu_term, d_claims, d_sc,
d_term, zcf_sc, zcf_term, zcd_sc, zcd_term, helper_sums` as raw `Fp2` LE
(sumcheck rounds flat, sumcheck.rs:27-33); then the three openings as
`group_vecs | prox_vec | per column (index u64 | rows x Fp | path x 32)`
(pcs.rs:101-125). No length prefixes, no envelope: **the format of this profile
is fully determined by `(Statement, Params)`**, so the decoder is
shape-directed rather than budgeted:

```rust
pub struct DecodeLimits { pub max_bytes: usize /* default 256 MiB */ }
impl Proof {
    pub fn from_bytes(bytes: &[u8], stmt: &Statement, params: &Params, limits: &DecodeLimits) -> Result<Proof, Error>;
}
```

`from_bytes` computes every field length from the layout (rows of each
commitment, `2 + distinct shifts` tables with their exact row counts and the
same totals `verify` checks at layer.rs:2080-2093, round counts and degree of
each sumcheck, `num_col_checks` columns each of `rows` elements and
`log2(enc_cols)` path digests), reads exactly that, rejects short input,
trailing bytes, `rows`/`log_cols` disagreeing with the layout, column indices
`>= enc_cols`, and — important — **non-canonical field elements**: `Fp::new`
reduces `v >= P` silently (field.rs:27-29) and `Fp2::from_bytes` goes through
it (199-203), so today a non-canonical byte string would decode to a valid
element and `encode(decode(b)) != b`. The decoder reads `u64` and rejects
`>= P` itself. A self-describing outer envelope (magic, version, statement
digest, length) is offered for standalone files, *around* the frozen bytes,
never inside them. `public_block_wire.rs` (fixed budgets, `MAX_*` at 12-21,
`validate_structure`) remains the codec of the public block and later reuses
`Proof::from_bytes` for its embedded layer proof.

### 4.5 How `hashline` callers become adapters

- `hashline/Cargo.toml` gains `zkp-core = { path = "../zkp-core" }`.
- `hashline/src/{field,ntt,merkle,transcript,mle,sumcheck}.rs` become one-line
  re-exports (`pub use zkp_core::field::*;`) so every existing path compiles
  unchanged; `hashline::zk::ZkRng` is `pub use zkp_core::rng::ZkRng`.
- `hashline::pcs` re-exports `zkp_core::pcs::*` and adds the CUDA
  `Backend`/`EncodedStore` implementations (moved from pcs.rs's device arms and
  gpu/cuda.rs's entry points); `Store::Device` disappears in favour of
  `Store::External`.
- `hashline::layer::prove_layer_v3(w: &V3Witness, t_rows, params, ntt, tr)`
  becomes: build `Statement` from `w`, `Witness` from `w`'s planes, choose
  `w_committed` through `wcache` when a directory is configured, choose the
  backend from `gpu::enabled()`, refuse when `pcs_compact::selected()` (the
  compact PCS keeps its own prover in `pcs_compact.rs` or is retired — its
  choice, not the core's), then call `zkp_core::ffn_v3::prove`. Same for
  `verify_layer_v3`. `export_v3::derive_v3_with_table` calls
  `zkp_core::ffn_v3::derive` inside its `phase_profile` spans.
- `zk.rs`, `attention.rs`, `public_block_*`, `model_identity.rs`,
  `private_seam.rs` change only their `use` lines. The ZK path keeps calling
  `pcs::commit_zk(…, &mut rng)` with the same `ZkRng`.
- Rule: **one source of truth per primitive.** After step 2 no primitive
  exists twice. If a step needs a temporary duplicate (for example the compact
  PCS's own copy of an encoder), the ledger row names the source pin, the
  differential test, the owner and the convergence milestone (README, "Source
  boundaries").

## 5. Randomness, transcript and byte-preservation constraints

What must not move, byte for byte, in the chosen profile — all of it
exercised by G1/G3:

1. Transcript construction: state = `blake3("hashline-v1/" || domain)`
   (transcript.rs:25-30); absorb framing `state || len(label) u64 || label ||
   len(data) u64 || data` (44-52); squeeze `blake3(state || "squeeze" ||
   counter)` with the counter incremented and the state replaced (85-94);
   `challenge_fp` from the low 16 bytes, `challenge_fp2` from both halves
   (97-112); `challenge_indices` masks 8-byte words by `bound - 1` (119-131).
   The `RoundMask` interception of `sc-round` absorbs (66-80) stays, unused here.
2. Statement absorb order and labels (layer.rs:1394-1404): `profile` =
   `"v3-widened/round"`, `layer`, `t_rows`, `d`, `f`, `shifts-signed` (four
   i64 LE, g/u/h/z), `act` (`spec_name`), `table` (the digest string's bytes).
3. Prover/verifier order (layer.rs:1469-2003 mirrored at 2064-2279): W
   commitment (`W` root then `W` rows, `absorb_com` 194-197) → A → the
   multiplicity tables (`absorb_mults`, 199) → `beta, gamma, alpha` → H →
   `r_i, r_j, lam_gu, lam_f` → `gu-claims` → matmul sumcheck (per round
   `sc-round` then one challenge, sumcheck.rs:109-110) → `gu-term` → `r_ip,
   r_jp, lam_d` → `d-claims` → sumcheck → `d-term` → `tau, mu, nu` → zero-check
   F → `zcf-term` → `tau2, mu2, nu_x, nu_z` → zero-check D → `zcd-term` →
   `helper-sums` → openings of W, A, H in that order, each: per-group lambdas
   → proximity rho → `pcs-vec` per group → `pcs-prox` → `num_col_checks`
   indices (pcs.rs:314-345).
4. The serializer layout of 4.4 and the twelve-layer concatenation of G1.
5. Layout arithmetic (`LayoutV3::new`, 1284-1316), the multiplicity table
   construction (`multiplicities_v3`, 1410-1442), the tags (1228-1233) and
   `pow2_signed` (1252).

For the ZK vertical (carried forward, not extracted now): the `zk` header
absorbed right after the statement (`tr.absorb(b"zk", header_v3)`,
zk.rs:2366; `P1-v3` legacy tag, 284-286), the RNG domain
`format!("layer-v3-{l}")` (2367), key derivations (357-363, 381-388), block
size (353), draw order in `commit_zk` (pcs.rs:627-628) and `CfsMask::random`
(`fp2_vec(n_vars*degree + 2)`, sumcheck.rs:197-202). Moving `ZkRng` to `rng.rs`
changes none of these; the zk and zkv3 gates (G4) and
`rng_is_deterministic_and_domain_separated` (zk.rs:1936) are the check.

### 5.1 The differential tests

| test | where it lives | what it proves |
|---|---|---|
| D1 bytes: `hashline::layer::prove_layer_v3(...).proof.to_bytes()` == `zkp_core::ffn_v3::prove(...)?.proof.to_bytes()` on the G3 fixtures; recorded digests in `zkp-core/tests` | `hashline/tests/zkp_core_parity.rs` (needs both crates; hashline already depends on the core) + `zkp-core/tests/parity_fixtures.rs` (digests only) | the extraction moved code, not behaviour |
| D2 cross-verify: old verify(new proof), new verify(old proof), both accept; after the adapter step they are one function, so D2 also keeps *recorded old proof bytes* as fixture files the new verifier must accept | same | verifier semantics unchanged |
| D3 tamper: the eight legs `FlipX(777), FlipW(4242), RemainderOutOfRange(99), WrongTableEntry(1000), WrongRequant(555), WrongZ(321), WrongRounding(2000), OutOfRangeInt16(123)` (bin/hashline.rs:928-937) reject in both, with identical messages | `zkp-core/tests/tamper_and_malformed.rs`, `hashline` legacy `layer … --all-tampers` | soundness checks preserved |
| D4 malformed: truncation at every field boundary, one trailing byte, single-bit flips at sampled offsets, a non-canonical `Fp` (`>= P`), an oversized count; `from_bytes` or `verify` rejects, nothing panics | `zkp-core/tests/tamper_and_malformed.rs` | bounded decoding ("reject, never panic") |
| D5 round trip: `to_bytes(from_bytes(b)) == b` for every fixture | `zkp-core/tests/codec_roundtrip.rs` | canonical codec |
| D6 fresh randomness (ZK vertical only): two OS-seeded proofs differ, seeded proofs repeat (zk.rs:1936; zk60 refusal tests in `cli_claims.rs`) | stays in `hashline` until the ZK vertical moves | unchanged randomness behaviour |
| D7 LIMITATION tests preserved unchanged: `actual_ffn_seeded_singleton_rows_are_recovered_in_p1_and_p3`, `actual_ffn_t32_recovers_one_functional_per_column_of_two_row_planes`, `diagnostic_refuses_degenerate_and_paired_mask_controls` (zk_ffn_mask_diagnostic.rs:530-558); `known_interface_hazard_verified_single_base_mask_reveals_entire_private_row` (tests/zk60_mask_rank.rs:97); `known_p3_gap_same_declared_model_and_input_different_weights_both_verify` (tests/zk60_identity_gap.rs:160) | `hashline` (they observe `verify_layer_zk_v3`); they move with the ZK vertical, assertions untouched | the refactor does not claim a repair; a passing suite still documents the defect |
| D8 dependency gate: `dep_closure.py --src zkp-core` shows externals ⊆ {blake3, sha2, rayon}, no `hashline::`, no `std::env::var`, no `cfg(feature = "gpu-cuda")` | local gate runner | the default closure stays small |
| G1/G2/G4 | floors scripts (heavy) | nothing else moved |

## 6. Default dependency closure

| crate | why | decision |
|---|---|---|
| `blake3 1.8` | transcript, Merkle leaves and nodes, salts | required |
| `sha2 0.10` | **one use in the profile**: the activation-table spec digest `table_spec_digest_int16out` (tables_v3.rs:108-127), whose hex string is absorbed into the transcript (layer.rs:1404) and whose nine SiLU / six GELU member digests are frozen constants (tables_v3.rs:70-92). The proof digest `PROOF sha256` is computed by the CLI (`export::sha256_hex`, bin:1015), not by the core | required, because a core that cannot construct a valid `Statement` from `(Act16Fn, e_in, e_out)` has no runnable example. Alternative recorded: take `table_digest` as an opaque input and keep the registry in an adapter (removes sha2, loses the constructor and the digest check) |
| `rayon 1.11` | parallel folds, hashing, NTT row encoding in `pcs`, `mle`, `sumcheck`, `merkle`, `layer` (order-independent field sums, so bytes do not depend on thread count) | required in step 2 (moving code, not rewriting it); a `parallel` feature with sequential fallbacks is a later ledger row whose gate is G3/G1 unchanged |
| `cudarc` | never | excluded; the backend trait is the seam |
| std::env, files, network, model exports | never in the core | the loader (`export_v3`, `HL_EXPORT_DIR`), the cache (`wcache`) and the CLI stay in `hashline` |

`[profile.release] panic = "abort"` (hashline/Cargo.toml:32-36) belongs to the
binary crate; the core's decoder must not rely on unwinding either way.

## 7. Migration ledger and delivery sequence

Each row of the ledger (kept in this file under "Ledger" once step 1 opens)
has: step | scope (files moved / adapters changed) | parity gates | fast
command | legacy gate | reviewer | commit | status. The steps are Codex's six
(README, "Delivery sequence"); their gates:

| step | scope | parity gate | fast isolated command | legacy gate |
|---|---|---|---|---|
| 1 pin and matrix (after CL17 is validated) | pin the source commit; publish this document's section 2-3 as the support/dependency/API matrix; record the G3 fixture digests from the `hashline` baseline | G3 digests recorded | `python3 zkp-core/tools/dep_closure.py` (graph unchanged vs. the pin) | none |
| 2 manifest + primitive boundary | `Cargo.toml`; `field, ntt, merkle, transcript, rng, mle, sumcheck, pcs (+backend), tables, error`; `hashline` re-exports; `ZkRng` moves | D1 on `pcs::commit/open/verify` and `sumcheck` unit fixtures; G4 all four CPU digests unchanged; `rng_is_deterministic_and_domain_separated` | `cargo test --offline --manifest-path zkp-core/Cargo.toml` | `cargo test --release --manifest-path hashline/Cargo.toml`; floors G1/G4 |
| 3 one vertical path | `ffn_v3/{statement, witness, proof, prove, verify, tamper}`; `examples/tiny_prove_verify.rs`; `from_bytes`; `hashline::layer` v3 functions become adapters | D1, D2, D3, D4, D5 on G3; G1 | as above + `cargo run --offline --manifest-path zkp-core/Cargo.toml --example tiny_prove_verify` | floors G1/G2/G4; receipts |
| 4 compare and retain | old-vs-new byte and outcome comparison recorded in the ledger; D6/D7 confirmed present and unchanged | D1-D7 | as above | full hashline suite |
| 5 gate | `results/zkp_core_gate.sh` (or a unittest wrapper): step-3 command + D8, added to the local gate runner beside the floors scripts; module/dependency reductions and remaining adapters recorded (section 8) | D8 | the gate script | as above |
| 6 policy | this section finalised; the ZK vertical scheduled as the next ledger entry with its LIMITATION tests | - | - | - |

### 7.1 Maintenance policy

- **Refactor commits never change a frozen digest.** A commit that moves code
  is accepted only if G1/G3/G4 are unchanged. A commit that changes a digest
  is a protocol change and is never mixed with a move (README: "separate
  commits with explicit version boundaries").
- **Promoting a reviewed repair.** A repair (for example the FFN masking
  repair from FA3) lands first where the affected code lives — after step 2
  that is the core for a primitive, `hashline::zk` for the ZK vertical until it
  moves. Its commit carries: the review reference, the new digests, a ledger
  row "digest supersession: old → new, reason, review", and the LIMITATION
  tests it retires (renamed from `known_…`/`actual_…` to ordinary regression
  names) or keeps. The core's version bumps (semver minor for a byte change
  that keeps the API, major for an API change); the profile's frozen digest
  table in section 2 is updated in the same commit.
- **Experiments stay outside.** Anything not on the supported-profile matrix
  (`pcs_compact`, attention, `private_seam`, receipts, the CLI, campaign
  scripts) lives in `hashline` (or a future `zkp-experiments`) and depends on
  the core; the core never depends on them. D8 enforces it mechanically.
- **Ownership.** Fable's refactoring lane owns `zkp-core/`; Codex reviews
  every shared-core boundary commit; `hashline` adapter changes follow the
  queue's ownership (one writer for `gpu/cuda.rs`, kernels and PCS; Codex for
  `zk.rs`, attention/composition, verifier/receipt/CLI). Exact patch or API
  proposals go to the owner before an edit in their file.

## 8. Before/after surface

| | modules | code lines | excluding tests | externals | env vars read | globals |
|---|---:|---:|---:|---|---|---|
| `hashline` library today | 35 | 20,102 | 17,685 | blake3, rayon, sha2, cudarc (feature) | 23 distinct `HL_*`/`M125_*` names (the binary adds `HL_GPU`, `HL_BENCH_CLAIMS`, `ZK_THREADS`) | `pcs_compact::CFG`, `wcache::DIR/STATS`, `layer::hostbuf::POOL`, `pcs::LAST_SITES`, `zk::PRED_BIT_TAMPER`, `phase_profile::STATE` |
| literal closure of the chosen profile today | 18 | 10,084 | 8,781 | blake3, rayon, sha2 (+ cudarc with the feature) | 9 (`HL_TIMING`, `HL_AL_POOL`, `HL_AL_I8FOLD`, `HL_CONV_VERBOSE`, `HL_WCACHE_VERBOSE`, `HL_EXPORT_DIR`, `M125_EXPORT_DIR`, `HL_GPU_VERBOSE`, `HL_ZK_DRAIN`) | all of the above |
| after the section-4 cuts (measured) | 10 | 4,560 | 3,934 | blake3, rayon, sha2 | 4 (`HL_TIMING` in `pcs`; `HL_AL_POOL`, `HL_AL_I8FOLD`, `HL_CONV_VERBOSE` in `layer`; all to be removed) | `hostbuf::POOL` (to become an option), `LAST_SITES` (test-only) |
| projected `zkp-core` | ~14 files | ~4,300 | ~3,500 + new: `from_bytes` (~150), `error.rs` (~60), backend trait (~80), example (~80) | blake3, rayon, sha2 | 0 | 0 process-global configuration |

Line count is not the goal and is not what step 5 records as success. **No
validation is discarded**: the unit tests inside the moved modules move with
them (`field` 5, `ntt` 2, `merkle` 1, `transcript` 1, `mle` 4, `sumcheck` 4,
`pcs` 3, `tables_v3` 1); `field::verifier_hardening_tests` (5 tests, attention
and public-block collision cases) stays in `hashline` because it drives the
attention and public-block verifiers; the fourteen `zk60_*` integration tests,
the four examples, `cli_claims`, the floors scripts and the Python gates stay
where they are and keep passing. What leaves the core is adapter and
application code that still exists, one directory over.

## 9. What this design does not do

- Moves no code, creates no manifest, changes no line under `hashline/`.
- Repairs nothing: the FFN mask disclosure (ZK60_FFN_MASK_DIAGNOSTIC.md) and
  the P3 identity gap remain exactly as documented, carried forward as
  LIMITATION tests; the chosen profile is P0 and claims no privacy at all.
- Claims nothing about throughput; the backend seam is designed so the GPU
  path can keep its measured bytes, not to change its speed.
- Does not pin the extraction source: that is step 1, after the validated
  CL17 baseline, and it needs Codex's review of the shared-core boundaries in
  sections 3.3 and 4.3 first. Open review questions for Codex: (a) whether the
  table registry (sha2) belongs in the core or behind an opaque
  `table_digest` input (section 6); (b) whether the layer-level GPU hooks
  should be trait methods on `Backend` or a second trait; (c) whether the
  compact PCS keeps its own prover or is retired when `layer.rs` stops
  routing through `pcs_compact::commit`.

---

## Appendix A — verified edges

Hand-checked against the source at `52a13d1`; the tool reports each with the
same kind and line:

| edge | kind | lines | note |
|---|---|---|---|
| `pcs -> zk` | normal | pcs.rs:615, 620 | `commit_zk`, `commit_zk_owned` take `crate::zk::ZkRng` |
| `pcs -> zk` | gpu | pcs.rs:674 | `commit_zk_device` under `#[cfg(feature = "gpu-cuda")]` at 673 |
| `pcs -> gpu` | gpu (only) | pcs.rs:67, 160-161, 262, 358, 633-634, 674, 682, 851, 923 | every device arm is gated; none leaks into the default build |
| `sumcheck -> zk` | normal | sumcheck.rs:201 | `CfsMask::random` |
| `layer -> gpu` | normal | layer.rs:448 | `dev_marks()` → `gpu::dev_stats()`, ungated (the stub provides it) |
| `layer -> gpu` | gpu | layer.rs:233, 235, 454, 546-547, 557-558, 695-696, … (24 lines) | device H commit, `HelperSpec`/`TabSpec` |
| `layer -> wcache` | normal | layer.rs:497, 1502 | `commit_w` for v2 and v3 |
| `layer -> pcs_compact` | normal | layer.rs:28 | the `use`; inline `pcs_compact::…` calls are unprefixed and not counted |
| `layer -> merkle` | gpu (only) | layer.rs:562, 1600 | `MerkleTree::build` inside the device H path |
| `zk -> gpu` | gpu (only) | zk.rs:1032, …, 2586-2595, … (30 lines) | 2585's `#[cfg]` covers a multi-line `let … = … && match {…}`; the tool's first version misread 2589 as ungated and was fixed |
| `zk -> export_v3` | normal / test | zk.rs:2012 / 3761 | production `V3Witness`; test-only `derive_v3` |
| `zk -> tables_v3` | test only | zk.rs:3763 | production zk.rs types `act` through `layer`'s statement |
| `zk::mask_diagnostic -> export_v3, pcs, tables_v3` | test | zk_ffn_mask_diagnostic.rs:7-9, 471 | `#[cfg(test)] #[path] mod` at zk.rs:3754-3756 |
| `field::verifier_hardening_tests -> attention, …` | test | field/verifier_hardening_tests.rs:88-96 | `#[cfg(test)] pub(crate) mod` at field.rs:237-238 |
| `gpu::cuda -> pcs, sumcheck, transcript, merkle, ntt, field` | gpu | gpu/cuda.rs:7-12 | module declared under the feature at gpu/mod.rs:19-20 |
| `tables_v3 -> silu` | normal | tables_v3.rs:127 | `hex` |
| `wcache -> gpu` | gpu (only) | wcache.rs:274-275 | gate at 273 |

Known limits of the scanner: it counts `crate::`-prefixed and `use`-declared
references, not unprefixed calls through an imported module name (so
`layer -> pcs_compact` shows one line, not the ~14 call sites listed in
section 3.3); it does not parse character literals; a `#[cfg]` on an item
whose block opens on a later line is followed until a `;`, `,` or `}` ends the
item or a `{` opens it. Regenerate and diff after every extraction step:

```
python3 zkp-core/tools/dep_closure.py                 # writes zkp-core/dependency_graph.json, prints the table
python3 zkp-core/tools/dep_closure.py --trace zk      # per-line gate audit of one module
python3 zkp-core/tools/dep_closure.py --root layer --cut layer:pcs_compact --no-default-cuts
```
