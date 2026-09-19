# Token-model zkVM experiment (profile `zk60-r0-token-v1`)

This isolated workspace reexecutes the fixed **synthetic-scale** token model
of `../private-model-kernel` inside a separately versioned zkVM guest:

```
32 private token IDs (vocabulary 32)
  -> embedding gather -> block 0 -> block 1 (unchanged private-block-kernel)
  -> final RMS norm of the last row -> signed int8 head
  -> greedy next token, lowest index wins ties
```

It is a functional intermediate toward the private model MVP. It is **not**
the model-scale MVP, **not** a trained language model, and it does not meet
any throughput target. Nothing here is a completed or accepted token proof:
the code and its tests make no cryptographic acceptance claim. Whether a
two-block token proof exists is decided only by the parent's actual proving
run and independent verification, recorded in the live loop record.

The complete-block workspace `../zkvm-block` is untouched. Its profile,
domains, image and policy format are not reused; files of either profile are
refused by the other. `../zkvm-block/model` is used read-only, in tests only,
to check that each embedded block payload is a complete legacy `Z60MDL01`
encoding with the same meaning.

## Formats (all sizes exact, all integers little-endian)

| Object | Bytes | Layout |
|---|---|---|
| public policy / journal | 144 | `PROFILE`(16) + context(32) + model digest(32) + input root(32) + output root(32) |
| public model `Z60TOK01` | 13,928 | magic(8) + embeddings 512 x i16 + block 0 payload(6,184) + block 1 payload(6,184) + final gamma 16 x i8 + head 512 x i8 |
| block payload `Z60MDL01` | 6,184 | the complete legacy block-model encoding (weights, RoPE cos/sin, exp, SiLU tables) |
| private request | 240 | `PROFILE`(16) + context(32) + input salt(32) + output salt(32) + 32 x u32 token IDs |
| owner input (`prepare-input`) | 128 | 32 x u32 token IDs, each in `0..31` |
| private output `output.u32` | 4 | the one next-token ID |

`PROFILE = b"zk60-r0-token-v1"`.

- Model digest: `SHA256("zk60-r0-token-model-v1\0" + PROFILE + u64 payload
  length + all payload bytes)`. It binds every public word including both
  blocks' lookup tables and the block order.
- Endpoint: `SHA256("zk60-r0-token-endpoint-v1\0" + PROFILE + role byte
  (0 input, 1 output) + context + model digest + 32-byte secret salt + u32
  count + count x u32 token words)`. The input role accepts exactly 32 tokens,
  the output role exactly 1. The two salts are independent OS-random draws.
  The output hides one of only 32 values: its hiding rests entirely on the
  output salt staying secret and not being reused for another value.
- The guest image fixes context length, vocabulary, layer count, calibration
  and the tie rule. The model file cannot change them.
- Every value is recomputed from the raw public words and the private tokens
  through `private-model-kernel`'s raw model API. No claimed activation,
  logit or token is consumed. A token ID outside the vocabulary is refused by
  the request decoder and again by the kernel.

These endpoints are SHA-256 handles. They are not compatible with hashline PCS
roots or with the block profile's endpoints and cannot be chained to them by
simple equality.

## Commands

`.cargo/config.toml` limits builds to two jobs and offline dependencies.
Prerequisites are the same as `../zkvm-block`: RISC Zero `r0vm` 3.0.6, its Rust guest toolchain, the locked crates
(`risc0-zkvm`/`risc0-build` `=3.0.6`, `risc0-groth16` `=3.0.5`). No cloud
prover is selected anywhere.

From this directory:

```
cargo test --locked -p zk60-token-statement -p zk60-token-model
cargo run --locked -p zk60-token-statement --example zk60_token_vectors
python3 reference/reference_vectors.py vectors          # must print the same three lines
cargo run --release --locked -p zk60-token-model --example zk60_token_synthetic_model -- NEW_MODEL_BIN

cargo build --release --locked -p zk60-token-host -p zk60-token-wrap
cargo test --release --locked -p zk60-token-host -p zk60-token-wrap     # bounded, no proof, no r0vm
target/release/zk60-token-host image-id
target/release/zk60-token-host prepare MODEL_BIN PUBLIC_DIR PRIVATE_DIR
target/release/zk60-token-host execute PUBLIC_DIR/model.bin PRIVATE_DIR/request.bin PUBLIC_DIR/policy.bin PRIVATE_DIR/inner.bin /absolute/path/to/r0vm
target/release/zk60-token-host prove PUBLIC_DIR/model.bin PRIVATE_DIR/request.bin PUBLIC_DIR/policy.bin PRIVATE_DIR/inner.bin /absolute/path/to/r0vm
target/release/zk60-token-host verify PUBLIC_DIR/policy.bin PRIVATE_DIR/inner.bin IMAGE_ID_HEX
target/release/zk60-token-wrap wrap PUBLIC_DIR/policy.bin PRIVATE_DIR/inner.bin PUBLIC_DIR/receipt.bin NATIVE_TOOLS_DIR PRIVATE_WORK_DIR /absolute/path/to/r0vm
target/release/zk60-token-wrap verify PUBLIC_DIR/policy.bin PUBLIC_DIR/receipt.bin IMAGE_ID_HEX
```

The host and wrapper tests need the guest build (they embed the image ID), so
they are part of the heavy build; the statement and model tests are light.
`python3 reference/reference_vectors.py check MODEL REQUEST OUTPUT_U32 POLICY`
is an owner-side, independent recomputation of a prepared policy's framing
from local private files. It does not run the model and prints no secret.

- `prepare` draws a fresh context, two independent salts and 32 uniform
  OS-random token IDs. `prepare-input MODEL_BIN INPUT_U32 PUBLIC_DIR
  PRIVATE_DIR` takes the owner's 128-byte input instead; a wrong size or any
  ID outside `0..31` is refused and nothing is created.
- Both directories must be new and disjoint. After `prepare` the public
  directory holds `model.bin` and `policy.bin` only; the private directory
  (mode `0700`) holds `request.bin` and `output.u32` (mode `0600`). The final
  Groth16 receipt is the only later addition to the public directory.
- The policy exists before any proof. `prove` recomputes the statement from
  the existing request and refuses unless it equals the supplied policy, so
  repeated proofs of one fixed policy reuse the same request with a new
  receipt path. `execute` runs the guest without creating a proof.
- `prove` accepts only a real succinct receipt, saves it with mode `0600`,
  then rereads and verifies the exact saved bytes. It is a private witness of
  the outer proof. Keep it, all logs, the work directory, the output token,
  the tokens and the salts private.
- `wrap` refuses an inner receipt that is not an owner-only regular file or
  that sits in the public output directory. It verifies the inner receipt
  against the caller's policy and the compiled image first, builds the outer
  receipt from that verified original claim and journal (not from anything
  the conversion or native prover returns), verifies it, saves it, then
  rereads and verifies the exact saved bytes. Native child logs are `0600`
  inside the new `0700` work directory, which must be outside the public
  directory. The native construction (`prlimit` 16 MiB stack, `stark_verify`,
  `prover`, the five official files, `GOMAXPROCS=2`) is the same as
  `../zkvm-block/wrap`.
- Both wrappers use `../zkvm-native-tools` to check all five official file
  lengths and SHA-256 hashes before any native tool runs. This provenance
  check does not itself verify the ceremony.
- The public verifier is `zk60-token-wrap verify`. It accepts Groth16 only,
  compares the journal with the caller's exact policy bytes, and requires the
  caller's independently obtained image ID to equal the compiled one. Fake,
  composite and succinct receipts, trailing bytes, and oversized files are
  refused. A policy copied from a candidate proof authorizes nothing: obtain
  `policy.bin`, the model and the image ID through a trusted channel.
- Both CLIs set `RUST_LOG=off` and `RUST_BACKTRACE=0` before any thread
  starts and refuse to run when any `RISC0_*` or `BONSAI_*` runtime
  variable is present (including the inherited profiler output path). Dev mode is compiled out
  (`disable-dev-mode`) and disabled on every prover/verifier context. `r0vm`
  must be an explicit absolute path. Capture the whole invocation in private
  logs too: child output is diagnostic material.
- Failures are plain static messages. No token, salt, position or activation
  is printed.

## Synthetic fixture

`zk60_token_synthetic_model` encodes `private_model_kernel::synthetic::
synthetic_raw_model()`. It is SYNTHETIC-ONLY: deterministic LCG words, not
trained, not approved, and its noncanonical RoPE/exp/activation test tables
are **not** a registered calibration. No fixture file is checked in; generate
it with the exporter and record its hash with the run.

## Limits

- Control flow and cycle count depend on secret data (argmax, refusals); no
  constant-time or constant-cycle claim is made. The session limit is 64 Mi
  cycles at segment po2 18, copied from the block host; the cost of two
  blocks plus about 14 KB of software SHA-256 input has not been measured.
- PoVW-related switches were not reviewed for this profile.
- The succinct receipt relies on the vendor's unfinished STARK privacy
  argument; see [the source review](../docs/zkmatrix-poc/ZK60_ZKVM_SOURCE_REVIEW.md).
- All heavy builds and proofs use the repository's detached job protocol and
  `/tmp/zk-heavy.lock`.
