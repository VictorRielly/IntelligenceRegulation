# Suggested code-level fixes

These are design sketches, not patches applied by this audit.

## 1. Separate prover randomness from Fiat–Shamir challenges

`LkpTranscript` should generate public verifier challenges only. Mask and
blinder constructors should accept a prover-only CSPRNG:

```rust
pub fn draw_masks<R: RngCore + CryptoRng>(
    kf: &KField,
    rng: &mut R,
    depth: usize,
    n_extra: usize,
) -> Result<MaskSet, ProveError>;

pub fn draw_blinders<R: RngCore + CryptoRng>(
    kf: &KField,
    rng: &mut R,
) -> Result<BlinderSet, ProveError>;
```

Sample field elements with unbiased rejection. Commit to them, then derive
alpha from the public statement/commitment transcript. Keep deterministic RNGs
behind `#[cfg(test)]`.

Prefer consuming the mask set:

```rust
pub fn prove_masked_lookup(
    masks: MaskSet,
    /* ... */
) -> Result<MaskedLookupProof, ProveError>;
```

Consumption helps prevent accidental same-object reuse, but secure fresh
entropy/session nonces are still required across construction and processes.

## 2. Make the lookup transcript seed verifier-derived

The verifier should perform the equivalent of:

```rust
let h0_link = link_h0(
    statement_digest,
    gnd_crs,
    tgt_crs,
    gnd_commitments,
    tgt_commitments,
);
let ctx_lkp = H(table_spec.digest(), h0_link);
let h0_lkp = ct_h0(tgt_crs, &ctx_lkp, tgt_t1s, tgt_t2s, &[]);
let mut transcript = LkpTranscript::new("uk8-lkp", &h0_lkp);
let alpha = transcript.challenge_k(kf);
```

`h0_lkp` and `alpha` should not be trusted proof fields. If retained for
debugging, compare them to derived values and never use the supplied copy.

## 3. Fix quantization validation

Represent scale separately from range:

```rust
struct QuantMeta {
    raw_bits: u32,
    signed: bool,
    scale_exp2: i32,
}
```

For `x_raw = 2^shift * y_raw + r_raw`, define and enforce the exact relation
between `scale_exp2(x)`, `scale_exp2(y)`, and `shift`. A `Range` operation may
prove that `y_raw` fits a narrower width, but must not waive its scale equation.

Use two bounds for signed types:

```rust
min = -(1i128 << (bits - 1));
max =  (1i128 << (bits - 1)) - 1;
```

Matmul/Hadamard analysis must separately bound positive and negative extrema,
or conservatively allocate the next bit when the exact positive endpoint is
reachable.

Define lookup metadata:

```rust
struct TableSpec {
    digest: [u8; 32],
    input_quant: QuantMeta,
    output_quant: QuantMeta,
    rows: u32,
}
```

Validate exact equality against the table selected by the operation.

## 4. Enforce a real DAG and one statement boundary

- Reject empty operation inputs.
- Require every produced value to follow its producers topologically, or run an
  explicit cycle check.
- Declare external inputs/weights rather than inferring them from read/write
  sets.
- Check every documented orientation rule.
- Make `ClaimManifest::digest` private or return a validation error.
- Require modulus/setup IDs per entry; do not encode a second CRS only as opaque
  `key_info`.

## 5. Create an adversarial verifier API

Move U-K8 out of one monolithic benchmark function:

```rust
fn prove_ffn_gate(
    statement: &PublicStatement,
    witness: &FfnGateWitness,
    rng: &mut (impl RngCore + CryptoRng),
) -> Result<Proof, ProveError>;

fn verify_ffn_gate(
    expected: &PublicStatement,
    proof_bytes: &[u8],
) -> Result<(), VerifyError>;
```

Tests must serialize, discard all prover state, and invoke verification from a
fresh process. Add a proof mutator that targets every length, index, hash seed,
commitment, challenge-dependent value, and response.

## 6. Salvage U-K9 without importing the broken continuation

Use clean `e8fa777` as the merge input. At the dispatcher conflict, keep:

```rust
self_test_lookup_zk();
self_test_uk9();
self_test_ffn_chain();
self_test_m5_chunking();
```

Then manually retain both `slot_pin_weights` (U-K8) and
`bulk_mul_fixed_kelems` use (U-K9) in `lookup.rs`.

Before optimizing further, add direct kernel vectors for:

- all-zero/all-one/all-`q-1` coefficients;
- carries immediately below/at/above each 31/32-bit fold boundary;
- worst-case three-product reduction;
- maximum supported round accumulator length;
- forced portable and AVX2 paths; and
- a runtime rejection just above the supported capacity.

The live in-place `fold_body`/`eq_double_body` edit should be completed as a
new commit only after the wrappers, call sites, and differential tests change
together.

