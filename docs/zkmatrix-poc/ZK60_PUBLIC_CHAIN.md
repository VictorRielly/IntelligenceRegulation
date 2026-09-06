# B5 — public two-block receipt

Implemented; full-suite closure in [round 6](ZK60_PARALLEL_ROUND6.md).
This is **P0 public arithmetic only**, not a private proof, recursive
aggregation, complete model execution or a 60-tokens/s result. Never put
sensitive data in this example. Full-profile privacy and integer/no-wrap
obligations remain open.

## Statement and trust boundary

The verifier receives two independently approved contracts, exactly layers
0 then 1 of the supported T32/d16/f16 fixed calibration, and an independently
trusted expected context/input/output. Model and calibration identities,
residual scale/class, layer order and shape must agree at the boundary.
Each contract pins its own approved attention/gamma and FFN roots.

The candidate carries one public signed INT16 intermediate tensor. The verifier
uses the **same words** as block 0's expected output and block 1's expected
input. Each constituent B4 proof authenticates that boundary against its
actual arithmetic commitment. Comparing roots or producer-supplied tensor
digests alone would not establish this relation.

A domain-separated per-block context binds the complete chain expectation
(format/count, ordered contracts, request context, initial input and final
output) and the block index. The B4 request digest additionally binds the
intermediate words before its commitment challenges. Receipts from different
requests/positions cannot simply be relabelled or spliced into this chain.

The consumer returns success only after both complete proofs verify. Exact
replay under identical trusted expectations remains valid; persistent nonce
consumption, authenticated registration distribution and release/proof-lag
policy belong to the application, not this stateless verifier.

## API and bounded bytes

- `ExpectedPublicChain::new` / `from_bytes`: exactly two approved contracts,
  nonzero context and two fixed tensors. Expected-state frame: **2,160 bytes**.
- `PublicChainOracle::prove`: builds the real first residual, then proves both
  blocks using that residual as the second input. No private state composition.
- `verify_public_chain_bytes`: no weights, witness/oracle execution or prover.
  Checks the entire outer frame, then decodes/verifies each complete B4 receipt
  sequentially. No partial acceptance is returned.

Outer framing is versioned, has fixed block/word counts and indices, bounded
constituent lengths and an exact final marker with no trailing bytes. Its
overhead is 1,089 bytes, including the public intermediate tensor. Maximum
frame length is `1089 + 2*MAX_RECEIPT_BYTES`. Sequential byte verification
retains at most one B4 codec's 16-MiB requested decoded-vector capacity budget;
`PublicChainReceipt::from_bytes`, which retains both, can use two such budgets.
These are decoder capacity bounds, **not** whole-process RSS limits. Input
bytes, allocator overhead and generic verifier workspaces are additional.

B4 deliberately extends its fixed profile from layer 0 to layers 0/1; its
layer-zero transcript, wire format and frozen artifact must remain unchanged.
No other calibration or layer is enabled. The legacy standalone FFN and
attention paths are untouched by B5.

## Separate-process public demo

Build the CPU-only example under the shared lock:

```sh
flock /tmp/zk-heavy.lock env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 cargo build --release --offline --manifest-path hashline/Cargo.toml --example zk60_chain_receipt
```

Use fresh output paths; the example refuses overwriting existing artifacts:

```sh
hashline/target/release/examples/zk60_chain_receipt prepare NEW_EXPECTED
hashline/target/release/examples/zk60_chain_receipt prove EXPECTED NEW_RECEIPT
hashline/target/release/examples/zk60_chain_receipt verify EXPECTED RECEIPT EXPECTED_AW0 EXPECTED_FW0 EXPECTED_AW1 EXPECTED_FW1
```

`prepare` uses the fixed integer oracle, **without proving**, to create synthetic
expected state before the receipt. It reports the four registration roots.
The example intentionally reuses the same public synthetic weights at two
distinct layer positions; it is not a trained two-layer language model.
`verify` reconstructs metadata only from caller-supplied roots; never obtain
those roots from the candidate receipt or trust its accompanying expected-state
file without independent authentication. A separate verifier process is not
itself an authenticated registry.

The example rejects GPU-enabled builds and `HL_GPU`. Core B4 runtime checks
also refuse compact PCS, tamper and folding overrides. Normal fixture/proof
timings on this shared CPU are diagnostics only.

## Validation

The integrated CPU release gate passes **143 Rust tests**, including 12 B5
test entries (one isolated-process helper) and two CLI unit tests. The new
tests include two individually valid constituent receipts with inconsistent
actual seam values, and freshly rebuilt arithmetic/openings under false
intermediate expectations reaching each block's external-boundary refusal.
Swapped/duplicated/spliced/relabelled receipts, malformed/truncated frames and
unsupported layers/modes reject. The separate-process CLI verification and
wrong-root/no-overwrite/GPU-environment refusal checks pass. Existing B4 layer-0
bytes and all four frozen CPU artifacts are unchanged. All **144 Python/native
tests pass with zero skips**; the round-6 ledger records final closure.

Two deliberately different fixtures must not be confused:

| Fixture | Receipt bytes | SHA-256 |
|---|---:|---|
| Integration test, distinct second-layer weights | 4,290,981 | `30f9c105c8ac389f0d84691778f0068bb31b4c1fa3455bfb93ea456637b295fb` |
| Persisted CLI demo, repeated public synthetic weights | 4,290,981 | `264a2cf4b026a27783c2c70fcca062081fd42c60ef9d394f082a9d6cb8331495` |

The persisted CLI expected state is 2,160 bytes with SHA-256
`dd5bb09b8d33d58c314c774e155c49e1250ba240cdd1af661dea02f79a32f5ec`.
Its two layer registrations both use the independently frozen synthetic roots
AW=`f20dc692c421abae9bfcb15ac4c15d8cdce64ef6f49e256c635dcc4bf2354d36`,
FW=`7578e15ca90d83ca31ce14df62f39fd0ede70089b34dd4580b86eb9e424ddbad`.
Verification needs only those approved metadata roots and the two files
`results/zk60_round6_expected.bin`, `results/zk60_round6_receipt.proof`:

```sh
env RAYON_NUM_THREADS=2 /tmp/zk60-round2-oNXEVd/lead-target/release/examples/zk60_chain_receipt verify \
  results/zk60_round6_expected.bin results/zk60_round6_receipt.proof \
  f20dc692c421abae9bfcb15ac4c15d8cdce64ef6f49e256c635dcc4bf2354d36 \
  7578e15ca90d83ca31ce14df62f39fd0ede70089b34dd4580b86eb9e424ddbad \
  f20dc692c421abae9bfcb15ac4c15d8cdce64ef6f49e256c635dcc4bf2354d36 \
  7578e15ca90d83ca31ce14df62f39fd0ede70089b34dd4580b86eb9e424ddbad
```
