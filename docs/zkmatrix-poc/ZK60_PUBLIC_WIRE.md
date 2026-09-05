# B4 canonical public block component wire, version 1

This is a new, bounded transport codec for the fixed public synthetic T32,
`d=f=16`, INT16 P0 Ligero block. It does **not** decode the existing ambiguous
flat serializers, approve a contract, verify a proof, or add privacy. The outer
receipt is responsible for the independently approved context and I/O binding.
No arithmetic, transcript, PCS, GPU, or legacy proof serializer was changed.

## API and verification boundary

`hashline::public_block_wire` exports:

```rust
encode_components(&PublicBlockProof) -> Result<Vec<u8>, String>
decode_components(&[u8]) -> Result<PublicBlockProof, String>
validate_structure(&PublicBlockProof) -> Result<(), String>
```

Decode performs the structural check before returning. Call the same check for
an already typed untrusted proof before passing it to a low-level verifier.
It uses fixed constants, never a prover, witness, replay, or candidate-derived
safety limits. Acceptance means only canonical framing and the bounded shape.
The caller must independently approve calibration/layout, table identities and
totals, roots, contract/domain/request/I/O, and then verify all arguments and
openings. This codec permits both B3's 133 and B4's 135 attention claims; the
receipt must require **135** and its own transcript. Appending two claims to a
B3 proof does not produce a valid receipt.

## Exact framing and retained messages

All count/index words are unsigned 32-bit little-endian. Table tags are u64 LE.
Fp is a u64 LE strictly below `0xffffffff00000001`; noncanonical encodings are
rejected, not reduced. Fp2 is canonical c0 followed by c1. Digests are 32 bytes.
Every vector carries its element count. Every nested vector retains its own
count, and every sumcheck retains its round count and each round's width.

The file is, in order:

1. Eight-byte `ZKPBWIRE`, u16 LE version 1, backend byte 0 (P0 Ligero), fixed
   tiny-profile byte 1, and the 32-byte contract digest.
2. Attention tag `0xa1`, u32 body byte length, and the complete attention body.
3. FFN tag `0xf3`, u32 body byte length, and the complete FFN body.
4. End byte `0xee`, followed by exact EOF.

Both bodies start with W/A/H commitments, then multiplicity tables. A commitment
is mandatory: tag `0xc0`, root, u32 rows, u8 log_cols. Each table is its u64 tag,
u32 row count, then u32 multiplicities. Attention continues with vals, sumchecks,
helper_sums, collapse arguments (sumcheck plus Fp2 terminal), and W/A/H openings.
FFN continues with gu_claims/gu_sc/gu_term, d_claims/d_sc/d_term, zcf_sc/zcf_term,
zcd_sc/zcd_term, helper_sums, and W/A/H openings. FFN ends with byte 0 explicitly
representing `cpcs_open=None`; compact `Some` is unsupported and rejected.

Opening role tags are `0xb1` (W), `0xb2` (A), `0xb3` (H). Each opening retains
all group vectors, the proximity vector, and all columns. Each column retains
its index, Fp values, and every Merkle authentication digest. Nothing from either
supported proof type is omitted. Attention's unused `helper_sums` is explicitly
encoded as an empty vector and **nonempty values are rejected**: the current
attention verifier does not consume that field. FFN's four helper sums are
consumed and preserved. Unknown tags, section slack, or trailing bytes reject.

## Fixed bounds

- Entire wire: at most 8 MiB. Requested decoded Vec payload capacity: at most
  16 MiB, including nested Vec/tuple headers. Count multiplication/addition is
  checked; counts are bounded and minimum remaining bytes checked before each
  allocation; allocations use `try_reserve_exact`.
- The capacity budget excludes caller-owned input, allocator bookkeeping and
  rounding, and subsequent verifier workspace. It is not a process RSS limit.
  A caller constructing a typed proof has already paid its own allocation cost.
- All commitments have `log_cols=8`. Attention W/A/H rows are 4/108/106; FFN
  W/A/H rows are 3/20/16. Decode's initial row ceiling is 256; final validation
  requires those exact values.
- Each opening has 1..32 group vectors, each 256 Fp2 values, proximity length
  256, and exactly 256 queried columns. Column indices are below 2048, each
  column has exactly the commitment's row count, and each path has 11 digests.
  Repeated queried indices are permitted because transcript sampling can repeat.
- There are 1..16 tables per component, each 1..65536 rows and total multiplicity
  at most 65536. Tags are unique, strictly increasing, and in 1..400. These are
  structural budgets, **not** approval of a table's semantic identity or totals.
- Attention has 12 sumchecks. Their `(rounds, width)` pairs are
  `(9,4),(5,4),(9,5),(9,5),(8,5),(11,6),(11,4),(8,5),(4,3),(3,4),(5,4),(4,3)`.
  Its four collapse arguments have 14/13/11/10 rounds, each width 3.
- FFN gu/d sumchecks have 4 rounds of width 3; zcf/zcd have 9 rounds of width 5.
  gu_claims/gu_term/d_claims/d_term/zcf_term/zcd_term/helper_sums lengths are
  2/3/1/2/10/4/4 respectively.

Encoding first runs a count-only canonical pass with the same byte ceiling,
then reserves the exact resulting output length and serializes the immutable
proof. Decode bounds each section independently and requires full consumption.

## Bounded CPU validation

Base: `87c5338`, isolated checkout `/tmp/zk60-round4-mEV7fY/codec`, plus the new
codec, integration tests, report and local `lib.rs` module registration. Tests
are excluded from `gpu-cuda` builds; unset GPU environment alone is insufficient
to rule out prior process-wide GPU initialization. No GPU job was run.

```sh
env -u HL_GPU -u HL_FOLD -u HL_NO_FOLD CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 \
  flock /tmp/zk-heavy.lock /home/victor/.cargo/bin/cargo test \
  --release --offline \
  --manifest-path /tmp/zk60-round4-mEV7fY/codec/hashline/Cargo.toml \
  --test zk60_public_wire -- --test-threads=1 --nocapture
```

Eight tests passed. The complete ordinary public B3 proof roundtrips, matches
both legacy component byte sequences **and** the typed structure, re-encodes
identically, and verifies against the independently supplied approved fixture.
Other checks cover receipt-sized claim preservation (not receipt validity),
malformed framing/tags, oversized nested counts, selected truncation boundaries,
noncanonical Fp/Fp2 values, unsupported compact proofs, ignored helper rejection,
fixed shape failures, and noncanonical table order/multiplicity budgets. Panic
checks cover the count/truncation cases. This is bounded regression testing,
not exhaustive fuzzing or a security audit.

The deterministic B3 fixture wire is **2,144,870 bytes** versus **2,137,764 bytes**
of legacy component payload (7,106 bytes framing overhead). BLAKE3:
`b965cc4ddd05ac2eabc949579ee6482af650b7db89890d5e7cc0ae979cd6df95`.
These are transport measurements, not performance or security claims. The
separate receipt integration owns its actual 135-claim proof and from-bytes
request/I/O mismatch tests. No private masking, full LLM coverage, large model,
GPU throughput, or 60-token/s conclusion follows from this work.
