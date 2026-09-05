# B4 — externally bound public block receipt

Experimental CPU-only P0, fixed B3 T32/d16/f16 calibration and layer0.
This is **not a private proof or a token-generation statement**. All fixture
inputs/outputs are public; never send sensitive data through this path.
The existing P1 approval object supplies authenticated metadata/weight roots,
not a privacy-policy acceptance or a proof of integer no-wrap.

## What the verifier checks

The independent `ExpectedPublicBlock` holds an immutable approved-contract
digest, nonzero 32-byte request/session context, 512 signed INT16 input words
and 512 signed INT16 output words. Canonical framing includes distinct ordered
input/output positions; the approved metadata binds their physical scales.
Its digest is absorbed in a NEW receipt transcript domain before either
attention/FFN arithmetic commitment. Expected state must come from the
verifier's application policy, not be blindly copied from a candidate proof.

After proving both components and their internal X/Z connections, the new
wrapper draws separately role-labelled challenges and evaluates the actual
attention `x_in` and final residual `xres2` class planes. It compares signed
class reconstruction against the MLEs of the expected public tensors and
adds those claims to the **same attention A commitment before opening**.
Thus a header digest alone cannot make unrelated inputs/outputs acceptable.
All original argument/opening checks and independently approved W/gamma roots
remain required. This adds two claim slots: 133 in B3 becomes135 in B4.

Freshly committed honest arithmetic under deliberately wrong expectations
must reach verifier refusal at the external boundary, not merely an honest
prover's assertion. Tests cover wrong input and wrong output separately.
Changing an existing receipt's expected context and relabelling its digest
also fails. The B3 and B4 domains are not interchangeable.

Exact replay under identical expected state is intentionally valid to the
stateless verifier. An application needing single-use receipts must consume
request nonces in its own durable state. The fixed public demo context is
not a secure nonce-generation or replay-consumption example.

## Complete framing and bounded entrypoint

`PublicBlockReceipt::to_bytes/from_bytes` wraps the complete canonical
[component codec](ZK60_PUBLIC_WIRE.md) with `HLB4RCP1`, a request digest and
an exact body length. Expected state is a separate fixed **2,120-byte**
`HLB4REQ1` frame. Signed INT16 words use their exact two-byte LE encoding.
The proof frame includes every attention and FFN argument/commitment/opening;
it is not a decoder for the ambiguous legacy flat component concatenation.

`verify_public_receipt_bytes(approved, expected, bytes)` parses the bounded
frame, checks canonical fields/structural counts, exact B4 schedule/profile,
expected request and roots, then runs the arithmetic/boundary/opening verifier.
Neither decoding nor structural-bound discovery invokes a prover or accepts
a producer-supplied "verified" flag. Codec acceptance alone is not verification.

Component wire is capped at8MiB; outer receipt adds44 bytes. The codec tracks
at most16MiB requested decoded Vec capacity, including nested headers. This
does not bound complete verifier RSS or allocator overhead; the legacy
verifier clones some typed state and allocates public lookup work.
Malformed tags, lengths, noncanonical Fp/Fp2, missing/extra messages, unused
attention helper sums and compact openings reject. Fixed tiny structure is
deliberately narrower than all A00 registrations.

The receipt uses default folding and Ligero only. It rejects tamper mode,
nondefault global folding settings and GPU-enabled builds. The compile-time
GPU refusal is necessary because legacy GPU enablement is cached: clearing
`HL_GPU` later is not a CPU-only guarantee. No GPU initialization is needed
to refuse. Concurrent mutation of process-global backend/folding settings is
unsupported; this example runs in a dedicated process. New proof integration
tests are CPU-only and skipped in GPU-feature builds, not claimed as GPU tests.

## Separate-process demonstration

Build only the bounded public example:

```sh
flock /tmp/zk-heavy.lock env CARGO_TARGET_DIR=/tmp/zk60-round2-oNXEVd/lead-target CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 cargo build --release --offline --manifest-path hashline/Cargo.toml --example zk60_block_receipt
```

`prepare NEW_EXPECTED` creates the public synthetic expected-state file
before any proof and prints the fixture's independently computed W roots.
`prove EXPECTED NEW_RECEIPT` creates the proof and byte-verifies it locally.
`verify EXPECTED RECEIPT EXPECTED_ATTENTION_ROOT EXPECTED_FFN_ROOT` is a
separate process with no weight generation, witness/oracle execution, export
access or prover call. Its metadata helper builds only fixed public constants
and tables from the independently supplied roots.

After the build above, verify the persisted public demo from the repository
root (the roots below are independently pinned fixture roots):

```sh
env RAYON_NUM_THREADS=2 /tmp/zk60-round2-oNXEVd/lead-target/release/examples/zk60_block_receipt verify \
  results/zk60_round4_expected.bin results/zk60_round4_receipt.proof \
  f20dc692c421abae9bfcb15ac4c15d8cdce64ef6f49e256c635dcc4bf2354d36 \
  7578e15ca90d83ca31ce14df62f39fd0ede70089b34dd4580b86eb9e424ddbad
```

All output creation uses create-new semantics; existing artifacts are not
overwritten. A failed creation after reservation can leave a partial file;
do not treat file presence as success. Require exit0 and successful decoded
verification. Expected-file provenance and model-root authentication remain
the application's responsibility; trusting roots copied from an arbitrary
proof does not establish which approved model ran.

## Validation and deliberate gaps

Initial integrated B4 gate: eight release tests pass, with a **2,144,946-byte**
complete receipt and2,120-byte expected state. The component codec separately
tests B3 round trips; the B4 gate tests actual input/output linkage from bytes.
The main-tree release CPU suite also passes: **124 Rust tests and 48 targeted
Python tests**, plus all four frozen CPU proof artifacts with unchanged full
hashes and lengths. The broader Python/native suite was not rerun.
No GPU-feature test run is implied by the CPU result.
Final combined commands/artifacts and separate-process outcomes are recorded
in [the round-4 validation record](../../results/zk60_round4_validation.json).

The actual demo artifacts are `results/zk60_round4_expected.bin` (public
expected state,2,120 bytes) and `results/zk60_round4_receipt.proof`
(complete P0 frame,2,144,946 bytes). Receipt SHA-256:
`ba5d82150b92e1ef4f58a29fe90fc65c756ac2f49c18f6df6b5de3f6f2fc6b94`.
Separate `prepare`, `prove` and `verify` processes succeeded. Independently
changed approved roots refused, and an attempted artifact overwrite refused.
The verifier's branch executes no weights, witness, export or prover path;
the supplied expected-state file/root provenance is still an application
trust obligation. These artifacts contain public synthetic data only.

Independent read-only review checked binding/order and found the cached-GPU
policy issue; it is fixed with explicit build refusal. Process-isolated policy
tests, cross-domain tests and pre-extraction B3 root/metadata literal pins
were added. This review is not a cryptographic security audit.

The parser review found no structural count/slicing/consumption defect in
the reviewed codec. This is **not a universally panic-free verifier**:
legacy attention/FFN lookup code can assert if a challenge-derived denominator
is zero. That exceptional path was identified by inspection, not reproduced.
Explicit degenerate-denominator refusal and broader hostile-input hardening
remain required before exposing a verification service. The bounded demo
must not be advertised as a production-safe network endpoint.

Still missing: private attention/FFN composition and its joint-transcript
privacy review; full integer/range/no-wrap soundness; multi-block linkage in
this receipt profile; embedding, final norm/head, logits/token choice, KV and
position/window transitions; deployment hardening and statistical performance
evidence. Passing these public tests does not establish 60 generated tokens/s.
