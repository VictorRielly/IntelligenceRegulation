# B3: fixed-oracle public block arithmetic proof

This experimental library wrapper connects the fixed T32 witness oracle to the
existing **public P0** attention and FFN provers and verifiers. It is not a P1
proof, a private transformer, a model-quality result or a throughput result.
The original `ApprovedP1BlockContract` remains immutable and unchanged: this
wrapper validates arithmetic under its approved metadata, **not its privacy
policy**. Its separate transcript explicitly says `P0-public-arithmetic-only`.

## Covered rung

One synthetic block: T32, width 16, FFN 16, two Q heads, one KV head, head width 8.
The fixed oracle executes both round RMSNorms, Q/K/V projections, frozen RoPE,
causal integer score/exp/softmax, PV, output projection, first residual, frozen
SiLU FFN and second residual. The wrapper uses the existing public arguments
and PCS openings for these planes, with both **actual** internal seams:

1. Attention `xm8` equals the FFN's proven input X.
2. Attention's residual-pin `z16` copy equals the FFN's proven output Z.

Both comparisons use the actual `LayerProofV3.zcd_term` evaluations at
`v3_zcd_point`, replayed from the transcript before the FFN argument. The
attention commitment remains pending until those claims are registered.
Both arguments, both comparisons, and W/H/A openings must pass verification.

### Tiny PCS compatibility finding and explicit adapter

The first attempted proof failed at `pcs.rs::col_key`: Wk/Wv contain 128 values
each (`log_size=7`), shorter than the approved 256-column PCS row. Subtracting
`log_cols=8` underflows in the legacy opening path. A00's T32 check ensured the
KV **activation** plane was large enough; that did not ensure every **weight**
claim was large enough. Passing A00 preflight never certified proof support.

The new wrapper-local `lift_public_weight_claims` makes these two claims
compatible without changing approved parameters, roots, packing or legacy
attention/PCS code. Wk at 256 and Wv at 384 occupy the two halves of the same
256-value row starting at 256. Their seven-coordinate MLE claims become
eight-coordinate row claims with leading selector 0 and selector 1 respectively.
This is exact subcube evaluation, not padding an unknown value or assuming
equality. The adapter checks the precise tiny layout (W length 1024), single
part, unit coefficient, non-sum claim, arity, alignment and enclosing-row bounds;
unsupported short claims are rejected. Both prover and verifier apply it before
W opening. A domain label pins `tiny-KV-subcube-128-to-256-v1`. A direct MLE test
checks both halves, including their selectors, plus hostile adapter inputs.

Expected attention W (including both gamma vectors) and FFN W commitments come
from the independently supplied trusted contract, not from the candidate
proof. Their roots, row counts and column shapes are checked explicitly. The
entire approved metadata digest is bound before commitments/challenges, in a
new wrapper domain; verification reads constants only from the approved object.
No adaptive fitting, export loading or production CLI mode is involved.

## API and test fixture

- `causal_oracle::public_synthetic_fixture()` returns a public approved test
  contract, public signed asymmetric weights and public input. The constants,
  weights and input are fixed before any proof; the CPU NTT/Merkle helper
  independently computes its approved weight roots. This is test registration,
  not authorization of an externally supplied model.
- `PublicBlockOracle::new(&approved, weights)?.prove(&input)` first invokes the
  checked fixed oracle. It does not accept arbitrary caller-mutated witnesses:
  the legacy prover contains honest-execution assertions and release panic
  behavior can abort.
- `verify_public_block(&approved, &proof)` runs the public verifier and returns
  static refusal categories, without embedding witness evaluations in errors.
- `public_block_transcript(&approved)` is available for the opt-in executed
  schedule tests in A01. It is explicitly public and domain-separated.
- `lift_public_weight_claims(&layout, &mut claims)` exposes the exact checked
  adapter for A01's raw-call schedule tests. It must run on both proof sides.
- `PublicBlockProof::payload_size_bytes()` counts the existing attention plus
  FFN component encodings only. It excludes public contract and framing.

The test fixture uses the E1 fixed calibration and signed off-diagonal Q/K/V/O
and FFN weights. E1 checks independent scalar GEMMs and signed rounding for
those orientations. No existing private policy, attention, PCS, CUDA or CLI
source is modified by this lane.

## Validation

Run on the shared WSL CPU with default features (no CUDA):

```sh
flock /tmp/zk-heavy.lock env RAYON_NUM_THREADS=2 CARGO_BUILD_JOBS=2 cargo test --release --offline --manifest-path hashline/Cargo.toml --test zk60_public_block --test zk60_sequence_equivalence --test zk60_block_contract -- --test-threads=1 --nocapture
```

Initial honest test after the adapter: **ACCEPT**, prove 40.840 ms,
verify 4.336 ms; attention 1,408,532 B + FFN 729,232 B = **2,137,764 B** payload.
These component byte counts match their actual serializer lengths. Public
metadata and wrapper framing are excluded. The initial no-adapter failure is
recorded above; it is not counted as a successful proof.

The complete bounded test set also covers:

- Wrong attention/gamma or FFN root bytes, row counts or column shape.
- Fresh valid proofs for separately registered changed gamma or FFN weights,
  accepted in their own test context but refused under the original approval
  even after relabeling the metadata digest.
- Changed claim evaluations and FFN terminals.
- A different supported residual scale, including an attacker merely relabeling
  the proof digest to that new statement; transcript verification still refuses.
- Two individually valid, freshly committed halves with different internal X:
  attention argument and full FFN verification pass, then the X seam refuses.
- A changed residual Z copy with recomputed valid residual equation and unchanged
  FFN: the first X comparison matches; the second Z comparison refuses.
- Wrong public gamma and hostile input refused before legacy honest assertions.

The two recommitted tests supply the attention side's actual evaluations to the
local seam assertion, then open those true claims. They do **not** toggle global
tamper mode, fabricate opening values, or bypass verification. The actual
verifier compares them with the FFN's true terminals and must reject there.

Final bounded run: **20/20 tests pass**, exit 0 (B3 6, E1 7, A00 7).
Compile 18.28 s; B3 tests 0.28 s, E1 0.04 s, A00 0.01 s. The final honest
row is prove 42.642 ms, verify 7.276 ms, with the same **2,137,764 B** payload.
Formatting and whitespace checks pass for owned files. Eight pre-existing
attention warnings remain unchanged. No GPU, large export, model-sized tensor,
full-suite, frozen-gate or quiesced benchmark run was performed by this lane;
the lead owns integrated validation.

All timing is `[WSL-BOX, 2T, NOISY-SHARED]`, not a quiesced benchmark or a
60-tokens/s projection. The `prove` timing includes fixed witness execution and
all public proof work, but excludes fixture creation and the constructor's
independent public-weight root check.

## Deliberate gaps

This is one block, not a cross-layer chain. There is no embedding, final norm,
head, logits/token selection, variable-length prefix equivalence, KV cache,
window transition or autoregressive generation statement. The input and output
are committed within the block; this wrapper does not bind their equality to
separately supplied external tensors, tokens or application commitments.

No byte decoder or hardened hostile-byte parser is supplied. The underlying
typed proof objects and existing serializers are used only for verification
and byte accounting; serializer availability is not a transport round trip.
This wrapper does not establish a field-to-integer no-wrap theorem, repair
existing gadget/security obligations or audit every malformed typed object.
Use the default Ligero PCS configuration; the legacy process-global backend
selectors have not been made instance-local or safe to mutate concurrently.

P0 exposes ordinary opening columns/evaluations, unmasked sumchecks and
multiplicities. No privacy claim follows from the P1-approved metadata digest,
and no change here resolves the singleton mask-rank or joint-transcript gate.
Private composition and independently reviewed no-wrap/soundness obligations
remain necessary before any complete private-block claim.

Lead integration repeats the six B3 tests within **108 passing release Rust
tests** and a separate ten-test B3/A01 run. That honest shared-CPU row was
prove 45.154 ms and verify 4.378 ms, with the same 2,137,764-byte payload.
All timing caveats above still apply. See `results/zk60_round3_validation.json`
for exact commands, source hashes and the separate compatibility gates.
