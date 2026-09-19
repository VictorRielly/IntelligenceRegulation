# Native attention and complete-block verifier captures

2026-09-19, Codex integration lane. Engineering evidence for privacy review;
**not a privacy acceptance, model-scale benchmark or five-second result.**

Implementation commit: `2b5c65c3c430d6d6dd7ac24ab0c115181e36ca75`.
[Retained source/binary manifest](../../results/zk60_native_captures_20260919/source.json)
and [validation results](../../results/zk60_native_captures_20260919/validation.json):
two fresh receipts per profile reproduce exactly, 49 native unit tests and
13 Python controls pass, and both retained pre-instrumentation receipts
verify in fresh processes. Two opt-in saved-receipt tests are ignored in
ordinary discovery and explicitly executed by the validation runner.

The shared `hashline/src/native_capture.rs` observer is included only in
unit-test builds of `private_attention` and `private_block`. Production
builds have no capture API, environment switch or observer calls. The
prover has no capture hook. Both profiles retain their existing receipt
format and transcript. No changes to `zk.rs` are needed.

The observer publishes only after the complete native verifier accepts.
Every new typed verification and every byte-verification attempt resets its
pending state before validation/decoding, so failure cannot publish partial
observations or reuse a previous success. A thread-local RAII guard confines
capture to one test thread. The saved-receipt test independently reconstructs
the public synthetic statement and reads only the saved receipt and caller
policy; it never builds a witness, computes an output or calls a prover.

## What the capture covers

Schema 3, kind `zk60-verifier-observations`, coverage `native-all-slots-v1`.
The actual full native profile is preserved in `profile` and
`transcript_domain`. Attention has 18 slots / 28 M functionals; the block
has 23 / 34. Both have exactly **five** openings in order M, A, H, Input,
Output. Public weights are bound by the public statement, with no W opening.

- Header state, public statement digest, expected policy bytes and SHA-256,
  schedule text/digests, canonical receipt SHA-256 and byte count, caller's
  source-commit pin, and all three LogUp challenges.
- Every slot's definition challenge tape, public tables/equality points,
  private-table slice offsets and coordinate formulas (public metadata),
  host coefficients, masked scalar, rounds, challenges, masked terminals,
  terminal polynomial and derived mask evaluation. Checkpoints include the
  next challenge as well as the state, to detect counter mismatches.
- Every M functional, slot specification, full q/proximity polynomials,
  theta and proximity challenges, and sampled columns/salts/authentication
  paths. The observer replays the full native M verifier independently.
- Every PCS claim, group membership/key/lambda, full 512-coordinate vector
  including pads, proximity coefficients/vector, and all 256 sampled
  columns with salts and paths. Row identities and H's zero-sum constraint
  are explicit. Element offsets preserve packed subrow aliases.

The PCS grouping/draw replay is adapted from the existing FFN diagnostic,
independent of the native protocol's schedule/refusal helpers, and checked
against the core PCS verifier. It handles short slices as well as full rows.
Slot replay checks the actual sumcheck rounds; definition replay deliberately
fails closed if a future definition adds an operation other than Fp2 draws.
All checkpoint joins are checked before publication. No witness plane,
private pad, mask coefficient, endpoint preimage or RNG state is exported.

## Reproduce and check

Build under the shared build lock, with two jobs and Rayon threads:

```sh
flock /tmp/zk-build.lock env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 cargo test --manifest-path hashline/Cargo.toml --release --offline --lib native_capture --no-run
```

Use the test executable printed by cargo. Pin its SHA-256 separately from
the source commit. The retained validation manifest records both: the
caller-supplied source string alone is not build provenance.

To capture an existing **public synthetic** receipt, invoke exactly one of
`private_attention::capture::native_capture_saved_receipt` or
`private_block::capture::native_capture_saved_receipt`, with `--exact`,
`--ignored`, `--nocapture` and these environment variables:

| Variable | Meaning |
|---|---|
| `HL_TEST_SOURCE_COMMIT` | Full lowercase source commit ID |
| `HL_TEST_NATIVE_RECEIPT` | Saved canonical native receipt |
| `HL_TEST_NATIVE_EXPECTED` | Independently supplied expected policy |
| `HL_TEST_NATIVE_CAPTURES` | Output directory; files must not already exist |
| `HL_TEST_NATIVE_COMPARE` | Optional exact reference JSON to compare |

The exporter writes `<sha>.receipt`, `<sha>.expected`, then `<sha>.json`.
The JSON is published last. The opt-in synthetic roundtrip test also
generates two fresh receipts for each profile, checks typed/wire capture
identity and rejects early/late corruptions without stale publication.

The maintained ingestion command is:

```sh
python3 scripts/zk60_native_capture.py CAPTURE.json --source-commit COMMIT --verifier-test-bin TEST_BINARY --verifier-sha256 BINARY_SHA256
```

It checks artifact hashes, exact native geometry, all slot sumcheck equations,
hosted scalars, slot-to-PCS aliases (including subrow and bilinear extension
claims), and slot-to-M functionals using the archived finite-field/CFS
functions unchanged. Then it **must run the pinned native verifier in a fresh
process and reproduce the entire capture byte-for-byte**. Merely passing
JSON screening, setting `fully_verified`, or running zero matching tests
cannot count as acceptance. The native export format is canonical; even a
whitespace-only rewrite requires regeneration. Source/binary pins must come
from the reviewer, not from an untrusted producer. The CLI is fixture-specific,
not a verifier for arbitrary public weights or a deployment policy channel.

## Review boundary and handoff

The older round-2 FFN command-line parsers hard-code a different profile and
geometry; their M checks assume eight slots and some PCS routines assume
full-row claims. Feeding native captures to them unchanged would be wrong.
No old parser, golden, geometry constant or privacy conclusion is rewritten.
This native adapter reuses their generic CFS algebra and supplies native
aliases; their full joint-view analysis still needs a reviewed native adapter.

**Next, owned by the security lane:** consume two real receipts per profile
and close the joint CFS/PCS/pad/column analysis, then the adaptive and repeated
view argument under D8/D11's full prior-history obligation. Fixed endpoint
roots and prior authentication/hash history remain in scope. This delivery
does not provide that simulator or reduction and does not close D8/D11.
`privacy_review_complete` remains false on every artifact.
