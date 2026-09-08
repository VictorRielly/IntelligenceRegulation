# Actual FFN mask disclosure diagnostic

## Round 11: verified A/H/P3-W captures

The test-only observer now captures **W (P3 only), A and H**, in verifier
order, and publishes them atomically after complete FFN acceptance. Each
observation contains its public PCS parameters, commitment, reconstructed
claims, opening and transcript endpoints. P1's public W is not labelled a
hiding opening. Replay retains the actual group lambdas and proximity
coefficients, checks each public claim and sampled index, and reruns ordinary
PCS authentication. Endpoints must connect W → A → H and agree with the
complete verifier.

The five focused tests pass for the same twelve T2/T32 P1/P3 proofs, including
fresh OS randomness. A groups remain `[7,3,1,1,6]`; H groups are
`[3,1,1,6,1]`; P3 W groups are `[2,1]`. All six seeded full-proof hashes remain
unchanged. The actual Wd-at-p6 singleton now reproduces the review's prediction:
T2 discloses 32 base-field functionals of eight-row combinations; **T32
recovers the entire 256-word Wd block**, with both seeded and fresh proofs.
Truth comparisons occur outside the public observer/extractor. This result
does not establish total joint disclosure or privacy of H.

Controls cover W/A/H failures without partial publication, malformed group
and vector lengths, missing/modified endpoints, roots and authenticated
columns, the wrong proximity-challenge order, inert unarmed captures, guard
cleanup on unwind, nested-capture refusal, and the independent review's
nonconstant-truth, mask-tail and overlap cases.

For Fable's FA2 follow-up, the unit-test harness can export the public captures:

```sh
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 HL_GPU=0 \
  HL_TEST_FFN_OBSERVATIONS=/tmp/zk60-observations-new \
  flock /tmp/zk-heavy.lock cargo test --release --offline \
  --manifest-path hashline/Cargo.toml --lib mask_diagnostic \
  -- --nocapture --test-threads=2
```

Use a fresh destination: existing digest-named files are refused. Schema 1
contains exact integer field coordinates (use Python integers/u64/bigint,
not floating-point JSON numbers), per-role claim slices/points/coefficients,
group membership/lambdas and full public vectors, proximity coefficients,
sampled columns/salts/paths, and before/after state plus next challenge.
The exporter receives no witness, private mask arrays or RNG state. It is
compiled only inside the diagnostic test module. The twelve initial JSON
captures in `/tmp/zk60-round11/observations` parse and reconcile all dimensions;
they are inputs for independent analysis, not a stand-alone FFN byte decoder
or a completed rank/simulation proof. Fable's FA3 repair remains a separate gate.

The following sections retain the original round-7 scope and evidence.

Codex continuation from `9cf1372`, 2026-09-06. The round-6 source hypothesis
is now reproduced on the actual v3 FFN prover and verifier. This is a
**test-only diagnostic of an existing privacy defect**, not a masking repair,
independent review or private-block acceptance. Production builds exclude
the observer and diagnostic module entirely; `pcs.rs` is unchanged.

## Executed result

Both tested modes, P1 and P3, reconstruct the same five A opening groups:
**[7, 3, 1, 1, 6]** claims, in first-occurrence order. The two singleton
groups are X at p2 and h16 at p5. Every diagnostic starts with a complete
FFN proof that the ordinary verifier accepts, including the final H opening.

| Synthetic profile | Observation recovered from each singleton vector | Scope |
|---|---|---|
| T2/d16/f16, log_cols5, inverse rate4, Q12 | All 32 base-field X values and all 32 h16 values | Complete recovery of these two tiny planes under P1 and P3; two witness/explicit-proof-seed fixtures and two fresh OS proofs per mode |
| T32/d16/f16, log_cols8, inverse rate8, Q256 | 256 base-field linear combinations of the two rows in each 512-word plane | One functional per column, retaining actual row-combination coefficients; explicit fixture randomness and fresh OS randomness under each mode |

All four diagnostic tests pass in the final all-target Rust run, covering
twelve honest proofs and 24 plane observations, including fresh T32
randomness. There is no resampling loop to select favorable
challenges. A degenerate or unsupported observation fails explicitly.

The T32 result describes what this extractor computes. It is **not an upper
bound on disclosure**: this diagnostic does not use the integer ranges,
multiple proofs, other groups or helper/proximity observations to infer more.
It does not establish the affected set of larger d/f profiles. P3 here tests
the activation commitment after the real private-W opening; it does not
analyze W disclosure or approve private-model identity.

## Public-data boundary and replay

`hashline/src/zk.rs::verify_layer_zk_v3` has a `cfg(test)` observer at the A
opening. It copies only the verifier's PCS parameters, A commitment,
reconstructed claims, public A opening and unmasked verifier transcript.
It records A's endpoint after A verification and publishes the observation
**only after H also verifies**. A thread-local RAII guard limits capture to
the requesting test and resets on failure/unwind. No prover-side observer is
installed, and ordinary tests incur no proof-copy cost unless capture is armed.

`hashline/src/zk_ffn_mask_diagnostic.rs` independently reconstructs the exact
column keys (point tail, offset and length), claim membership, per-group
lambdas and combined public claims. It follows the **actual source order**:
all group coefficients, then proximity coefficients, then group/proximity
vector absorption, then sampled columns. It checks sampled indices and both
the endpoint state and next challenge against the captured verifier. It also
re-runs ordinary `pcs::verify_zk` against the copied public commitment/opening
and checks its endpoint. The final FFN verifier transcript matches the prover.

The extractor receives only that public observation, replayed groups and a
public layout role. Witness truth is used afterward in the separate fixture
comparison harness. Full private pad arrays, unsampled salts, witness data,
seed state and committed secret data are unavailable to the observer and
extractor. Already-public folded pads and sampled salts remain in the opening
for ordinary authentication. Tests log profile, role, group counts, output
dimension and full proof SHA-256, never recovered values or randomness.

These are in-process verifier replays, not a new standalone private-FFN byte
decoder. Seeded fixtures reproduce the recorded proof hashes; fresh proofs
intentionally differ. The existing separate-process public receipt gates
remain distinct evidence.

## The checked algebra

For one singleton group and one column, the authenticated clear vector has
the form `v = sum_i a_i D_i + b R`, where the data rows `D_i` and single
mask row `R` are base-field values. The public extension-field coefficients
include the actual lambda and MLE row weights. Define
`L_b(z) = z.c0*b.c1 - z.c1*b.c0`. Then `L_b(b R) = 0` and
`L_b(v) = sum_i L_b(a_i) D_i`.

The implementation requires nonzero `b`, computes the actual base-field
weights, rejects an all-zero weight vector, and normalizes by its first
nonzero entry. At one data row this recovers that row. At two rows it returns
the weights and one normalized functional per column; fixture comparison
checks that functional, without substituting an assumed one-row formula.

All parts must map to the supported aligned rows, with the same column tail
and no mask/data overlap. A role must be unique and its actual group singleton.
A multi-claim group is refused. Paired independent mask directions require a
different analysis and are refused by this one-mask extractor.

## Controls and compatibility

- Both privacy modes, multiple seeded fixtures and fresh OS randomness.
- Altered sampled index, group order, folded pad, root, claim order, transcript
  and authenticated column fail replay/authentication.
- An otherwise valid proof with corrupted final H is refused and publishes
  no observation, even though A has verified.
- Zero lambda/mask coefficient, rank degeneracy, malformed mapping and paired
  mask input refuse. The existing `zk60_mask_rank` integration test additionally
  verifies a real paired-mask opening and checks that the old coordinate
  extractor no longer recovers its data; neither control proves joint privacy.
- All instrumentation is behind `cfg(test)`; legacy layout, randomness,
  transcript and serialized production proof formats are unchanged.

Reproduce the focused gate from the repository root:

```sh
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 HL_GPU=0 \
  flock /tmp/zk-heavy.lock cargo test --release --offline \
  --manifest-path hashline/Cargo.toml --lib mask_diagnostic \
  -- --nocapture --test-threads=2
```

Final validation passes **147 Rust tests and all 144 Python/native tests,
zero skips**, plus the 63 library tests at sixteen test threads. All four
frozen CPU artifacts match their full SHA-256 and length. B4 receipt parity
and separate-process B5 verification pass. Exact commands, source hashes,
logs and results are in [the validation record](../../results/zk60_round7_validation.json).

## Next gate

Fable should independently reproduce these results, expand the joint A/H/W
analysis and review a concrete complete mask reservation/claim plan. Codex's
pending private FFN/attention implementation remains gated on that reviewed
plan. Adding only paired seam masks leaves the demonstrated core FFN defect.
This finding does not change the passed public-block/public-chain milestones
or establish private generation or target throughput.
