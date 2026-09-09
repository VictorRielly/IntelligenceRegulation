# Round 16: executable FFN privacy repair

Implementation: `b41d036c4c1eb1ed9272494815d742d0ccf29934`.

**Task reassignment:** Victor exhausted Fable usage during this round. Pending
reviews now go to Opus 5 through [the bounded handoff](ZK60_OPUS_QUEUE.md).
Codex retains protocol implementation and final cryptographic review. Earlier
Fable analyses remain attributed to Fable.

The earlier hash-line FFN proofs verified but disclosed private information.
The actual-proof diagnostics recovered inputs/activations at the tiny singleton
shape, per-column functionals at T32, and all of the tiny P3 down-projection
weight matrix. This was disclosure of model/witness values, not a discovery that
public protocol parameters were public. See the
[actual-capture review](ZK60_FABLE_CAPTURE_REVIEW.md).

Rounds 12–15 delivered reviews, safeguards, storage and core extraction. They
did **not** deliver the repaired private proof. This round changes that specific
implementation boundary: a small FFN prover and verifier now execute the paired
mask construction with fresh commitments. The full private-model PoC is still
unfinished.

## What runs

`hashline::zk::fresh_poc` exposes a separate, experimental
`ffn-v3-mr1-fresh-poc/1` profile at T32/d16/f16, log_cols 8, inverse rate 8,
256 column checks, function 1. Its API accepts no seed, RNG or reusable private
commitment. It owns the transcript, binds the request context and obtains fresh
OS randomness before each attempt. All private commitment state is dropped
before the proof returns.

Both modes execute:

- P1: private inputs/activations; public weights checked against an independently
  supplied root. The example obtains that root before proving.
- P3: private inputs/activations and fresh private weights. This proves the FFN
  relation under its fresh W commitment; it does **not** authenticate a previously
  registered model. There is no stable commitment reuse or slot claim here.

The previously scalar A/W mask sites and A/H/W proximity masks now have two
independent base-field rows. Singleton multiplicity table masks receive pairs;
larger table blocks keep their existing block masks. H's existing helper pairs
and zero-sum pair remain. The verifier constructs the allocation and claims
itself, checks mask coefficient rank and group/proximity degeneracies, and
rejects rather than resampling. The test build also checks every generated mask
row for constant values and accidental duplicate row contents.

The shared arithmetic implementation selects an explicit mask schedule. Legacy
entry points always select the old schedule; the new API selects the repaired
one under its own transcript domain. This avoids copying the entire FFN engine.
The experimental profile is deliberately distinct from FA3's eventual registered
block `ffn-v3-mr1` envelope: it has no wire decoder, attention, seams or stable
private model identity. Fresh P3 W randomness is drawn before A; A random rows
are filled in allocation order, H retains its documented helper/zero-sum order.

Run the demonstration with all `HL_*` switches cleared, two Cargo/Rayon threads
and the shared heavy lock:

```sh
cargo run --release --locked --offline --manifest-path hashline/Cargo.toml --example zk60_fresh_ffn
```

This uses public synthetic tensors and fresh secret proof randomness. Verification
uses the public FFN statement and typed proof, without witness access. It is an
FFN demonstration, not a transformer, model benchmark or serialized receipt.

## Evidence and precise limits

The first execution passed all three new tests. Both modes verified twice with
different private roots. Tampered terminals/columns/context, missing/extra rows,
extra opening groups and cross-profile legacy proofs were rejected. Layout tests
also cover the log_cols=16 singleton-table boundary without making a large proof.

Actual verified singleton observations for X, h16 and P3 Wd have mask rank two.
The test solves compensating changes in the two masks for a change in private
data, showing why the old single-mask elimination cannot identify that data.
**This is not yet a joint-observation or nonlinear-transcript privacy verdict.**
The next review must examine the actual new captures together, including terminals, folded
vectors, pads, proximity data and H's public LogUp constraint.

The fixed diagnostic witness yields 698 A rows, 1326 H rows and 3 public W rows
or 11 private W rows. Logical payloads are 4,733,204 bytes (P1) and 4,770,164 bytes
(P3), excluding a future transport envelope. These are size measurements, not
throughput results.

**Final validation complete**, at `046e9654ab8b769be196bef5b63dbf6485982f7d`.
The proving code is identical to `b41d036`; the intervening commit corrects only
an old test that treated the now-supported suite version 7 as unsupported.

- 250 unique Rust tests pass: 218 storage-enabled hashline tests and 32 core
  tests. The overlapping default hashline run passes 191 tests.
- All 189 GPU oracle checks and all 12 frozen proof byte comparisons pass;
  suite v7 is green in all 24 cases. This is legacy compatibility evidence.
- The initial full Python run executes 660 tests: 659 pass and the obsolete
  unsupported-version assertion fails. After its one-line correction, all 87
  tests in the affected module pass. Other code/tests are unchanged; a second
  full Python run is not claimed.
- The repaired tests, synthetic demo and four actual captures pass at `b41d036`.

[Validation record](../../results/zk60_round16_validation.json),
[capture manifest](../../results/zk60_round16_captures.json), and
[retained evidence index](../../results/zk60_round16_evidence/index.json).
The 38 retained log/manifest/runner files total about 561 KB; the raw public
synthetic captures remain at the manifest's `/tmp/zk60-round16/captures` paths.
Suite v7 preserves versions 1–6 and changes only the storage-enabled expectation
from 215 to 218 for the three new regressions.

## Next acceptance milestones

1. Opus 5 checks the new generator and four fresh T32 function-1 captures (two
   per privacy mode), following O1–O3; Codex reviews the conclusions. Extend the capture parser for this explicit experimental
   profile; do not reinterpret it as the registered/seamed profile. Expected
   linear disclosures: A/W zero; H only its public LogUp identity. Keep the
   delivered legacy attack as a positive control.
2. Codex implements the bounded proof envelope and independent verification from
   bytes, then connects the repaired FFN commitment owners to the private block
   seams. Fable's attention privacy inventory determines the remaining attention
   repair before a complete private block can be accepted.
3. Demonstrate a tiny complete private block with externally bound input/output
   and model identity, then a two-block chain. For private weights, explicitly
   implement and verify the registered model binding. Advance to larger models
   only after those checks pass.

Core extraction stays priority 3. Stable storage work does not replace any of
these executable proof milestones.
