# Complete integer block experiment

This isolated workspace proves the exact fixed T32/d16/f16 transformer block
by reexecution. It is an intermediate toward the private model MVP. It does
not meet the model-scale throughput target or prove token generation.

The kernel includes both RMS norms, QKV, RoPE, causal attention, integer
softmax, PV, output projection, both residuals and SiLU FFN. Public weights
and integer lookup tables are fixed by an independently approved model
digest. The verifier's compiled image fixes shape and calibration.

`statement` defines a new 144-byte policy: 16-byte profile, 32-byte context,
32-byte model digest and two 32-byte salted endpoint commitments. Endpoints
are SHA-256 handles with separate input/output roles. They are not compatible
with existing hashline PCS roots and cannot be chained by simple equality.
Salts, inputs, output values and intermediate activations are private to the
owner/prover; the final public artifact contains only a receipt and policy.

`host` prepares a fresh small input for the demo (or reads an owner's supplied
input with `prepare-input`), executes the block, and
creates the intermediate succinct receipt. `wrap` converts that receipt to
Groth16 with a local CPU prover and independently verifies it before saving.
Keep the intermediate receipt private. The public verifier accepts Groth16
only; development/fake receipts are always refused.

The succinct receipt is functional evidence, with the vendor's unfinished
STARK privacy argument. The outer Groth16 construction has a reviewed privacy
argument under the setup, random blinding and implementation assumptions
recorded in [the source review](../docs/zkmatrix-poc/ZK60_ZKVM_SOURCE_REVIEW.md).
It does not increase the inner proof's soundness. RISC Zero's published
figures are about 96/99/99+ conjectured bits for the three layers.

## Build and run

Prerequisites are RISC Zero `r0vm` 3.0.6, its Rust guest toolchain (the
integration uses 1.97.0), and the locked crate dependencies. `.cargo/config.toml`
bounds build concurrency and uses the local dependency cache. Initial fetches
can use `cargo fetch --config net.offline=false`. No cloud prover is selected.

From this directory:

```
cargo build --release --locked -p zk60-block-host -p zk60-block-wrap
target/release/zk60-block-host prepare MODEL_BIN PUBLIC_DIR PRIVATE_DIR
target/release/zk60-block-host execute PUBLIC_DIR/model.bin PRIVATE_DIR/request.bin PUBLIC_DIR/policy.bin PRIVATE_DIR/inner.bin /absolute/path/to/r0vm
target/release/zk60-block-host prove PUBLIC_DIR/model.bin PRIVATE_DIR/request.bin PUBLIC_DIR/policy.bin PRIVATE_DIR/inner.bin /absolute/path/to/r0vm
target/release/zk60-block-wrap wrap PUBLIC_DIR/policy.bin PRIVATE_DIR/inner.bin PUBLIC_DIR/receipt.bin NATIVE_TOOLS_DIR PRIVATE_WORK_DIR /absolute/path/to/r0vm
target/release/zk60-block-wrap verify PUBLIC_DIR/policy.bin PUBLIC_DIR/receipt.bin
```

The executor's segment size limit must stay at or below `2^20`: the decisions
register's D3 figure of about 97 bits of conjectured soundness is stated at
`2^20`, and larger segments lower it. This host builds with
`SEGMENT_LIMIT_PO2 = 18` (`2^18`) and reports the limit with every
executor-only cycle count, so a recorded run states the shape it was measured
under.

The bundled public synthetic fixture is `fixtures/synthetic-model.bin`.
Its metadata records the exact digest and makes no trained-model or approval
claim. To regenerate it, export `zk60_kernel_fixture` from hashline and use
`scripts/zk60_kernel_model.py FIXTURE NEW_MODEL_BIN` from the repository root.

The maintained detached workflow is
[`scripts/zk60_zkvm_demo.py`](../scripts/zk60_zkvm_demo.py), documented in
[`ZK60_ZKVM_DEMO.md`](../docs/zkmatrix-poc/ZK60_ZKVM_DEMO.md). Native tools can
be prepared using `scripts/zk60_groth16_tools.py launch --out NEW_TOOLS_RUN`;
its `status --out TOOLS_RUN` command reports completion. The artifacts are
under `TOOLS_RUN/tools`, with `TOOLS_RUN/artifacts.json` for the runner's
`--native-hashes`. This setup downloads about 2.4 GB from pinned public image
layers, validates their hashes, and copies only the expected regular files.

For an owner-supplied input, replace `prepare` with
`prepare-input MODEL_BIN INPUT_I16 PUBLIC_DIR PRIVATE_DIR`. The input file
contains exactly 512 signed little-endian i16 words (1,024 bytes). Values
outside this fixed calibration's accepted computation range are refused.

Output directories must be new and disjoint. `PRIVATE_WORK_DIR` must also be
new and outside the public directory. It retains sensitive witness files and
logs for local diagnosis; do not publish it. No command overwrites a receipt.
Intermediate receipts use mode `0600`. The CLIs disable upstream debug logging;
capture the entire host/wrap invocation in private logs as well, since child
process output is diagnostic material. The maintained runner handles this.
The verifier must obtain `policy.bin` through an independent trusted channel;
copying an arbitrary candidate proof's policy does not authorize its model or
endpoints. `image-id` prints the verifier's compiled program identifier.

The native prover tools come from the official image
`risczero/risc0-groth16-prover:v2025-04-03.1`, resolved for this run to manifest
`sha256:7f173963196570b7a71816ed70565a4579264c5d2e3e0ecb028102538ad0e331`.
The expected files are `prover`, `stark_verify`, `stark_verify.dat`,
`stark_verify.cs` and `stark_verify_final.pk.dmp`. The wrapper uses the same
identity conversion, circuit, key and proof format as upstream. Docker is
not needed after extracting these exact native files. The integration record
tracks layer and extracted-file hashes.

`MODEL_BIN` has magic `Z60MDL01`, followed by the nine signed-byte weight
arrays in kernel order, RoPE cosine/sine and exp tables as little-endian i64,
and the SiLU table as little-endian i16. It is exactly 6,184 bytes. The public
fixture exporter in `hashline/examples/zk60_kernel_fixture.rs` supplies those
canonical tensors; their export is diagnostic synthetic data, not a real
model registration.

All heavy builds/proofs must use the repository's detached job protocol and
`/tmp/zk-heavy.lock`. Do not run the commands concurrently with another heavy
job. See [the live loop record](../docs/zkmatrix-poc/ZK60_MVP_LOOP_20260918.md)
for actual completed checks and pending jobs; this README is not a claim that
the Groth16 integration run has already passed.

## Image ID reproducibility

The guest image ID
`8d74aab3d58c1a713045dfd1ea4ffa15e61439e61af58b72a5fdb792111998d9`
was produced by a **local** build of this workspace. It is **locally built,
unreproduced**: no independent reproducible (upstream Docker) build has yet
been shown to produce the same identifier from the same pinned sources and
guest toolchain. Until one does, every approval record, decision entry or
verification instruction that pins this ID must say so in those words.
Pinning it (the maintained runner's `--expected-image-id`) binds a run to this
local build, not to an independently reproduced program.
