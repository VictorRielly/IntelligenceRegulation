# S2 — experimental private equality and a framed component receipt

Built 2026-09-04 for [round 2](ZK60_PARALLEL_ROUND2.md). This is one
building block toward private transformer composition, **not a complete
private block, LLM, approved-model proof, or certified ZK construction**.
The legacy proof entry points and CLI privacy refusals remain unchanged.

## What exists

`hashline/src/private_seam.rs` provides an opt-in library API:

1. Create an immutable `SeamSpec` with independently obtained context,
   endpoint slots, shape and represented-value scale.
2. `prepare` each plane with fresh OS randomness. It allocates data and
   all terminal/proximity mask rows before creating its hiding commitment.
3. Save each `PreparedPlane::commitment()` for the enclosing statement.
4. `prove` consumes both prepared objects. There is no clone, borrowed
   opening, retained-private-state return, or repeated-opening API.
5. `verify` receives **expected** endpoint commitments separately from the
   proof. `to_bytes` / `from_bytes` support an exact, versioned, bounded
   frame with canonical field words and no attacker-controlled allocations.

The public API exposes no deterministic seed. The prototype supports
power-of-two rows/columns, 2–4096 values, scale -31..31 and distinct endpoint
slots. The context must be nonzero. These are conservative prototype limits,
not newly supported transformer shapes. No source changes to `pcs.rs` or
`gpu/` were needed; only `masked_prove` and `extension` in `zk.rs` became
crate-private reusable helpers, without changing their bodies.

The verifier proves equality of the field words committed at these roots.
**It does not prove their ranges or their provenance.** The enclosing
attention/FFN arguments must authenticate those exact roots and prove the
integer representation/scale facts. A spec/model label or roots obtained
only from the proof producer are not independent approval. In particular,
recommitting a copy of an existing FFN output without proving consistency
does not connect this gadget to that FFN.

## Relation and transcript

Let A and B be same-shape planes, and R_A, R_B independently prepared
mask polynomials. After binding the spec, both roots and the CFS mask root,
draw tau and nonzero masking coefficient c. Prove the Boolean sum of

```text
F(x,e) = (1-e) * eq(tau,x)
       * [(1-e)*(A(x)-B(x)) + e*(R_A(tail x)-R_B(tail x))].
```

On the e=0 branch this is the equality-weighted difference; the e=1
branch is zero. Degree is at most two in every variable. Consequently
the ordinary data sumcheck followed by one extension round has the same
Boolean sum as the intended original equality relation. A random equality
factor is necessary: equal unweighted sums are not pointwise equality.

The sumcheck messages are masked by c*g for the precommitted CFS mask.
The public claimed sum gamma is c*sum(g); its correctness and g(rho,e)
are authenticated through two mask functionals and `mask_verify`.
The two transmitted terminals are independently masked A/B evaluations,
not clear values to compare directly. Their `ZClaim`s bind precisely the
data slice and reserved masks. The verifier checks the final polynomial
equation, authenticates the mask, then checks both hiding PCS openings.

Transcript order is fixed: context/roots/mask root -> tau,c -> gamma ->
masked rounds -> masked terminals/mask evaluation -> mask opening -> left
opening -> right opening. Each opening has its own domain label. Within
the inherited `pcs::zk_rhos`, **both group and proximity coefficients are
drawn before either clear vector is absorbed**. This is the actual code
order; the comment in `pcs::open_zk` describes a different order. Neither
that function nor its transcript was changed in this round.

## Local masking and encoding budget

The new component fixes n=256 message positions, Q=256 pad/query symbols,
and 2048 encoded positions (`inv_rate=8`). Hiding adds degree capacity:
n+Q=512, so the relevant rate is at most **1/4**, not 1/8. The separate
CFS mask commitment retains its existing 1024/4096 encoding. These counts
are not a standalone soundness theorem or a claim of 100-bit whole-proof
security. Parameter reduction for tiny fixtures is not allowed here.

Each plane reserves two base-field terminal-mask rows and uses the
Fp2 combination R_re + U*R_im. With nonzero group coefficient lambda and
extension e, lambda*e and lambda*e*U span Fp2 over Fp. This matters: one
base-field mask by itself need not hide a clear extension-field vector.
Three further independent base-field rows are used only by the proximity
combination. Under ideal uniform coefficients their 2x3 projection fails
to have full row rank with probability p^-2 + p^-3 - p^-5. The complete
analysis must also include transcript challenge/RNG distributions, pads,
sampled columns, all opened mask functionals and composition. The local
rank calculation is not such an analysis.

Repeated private Eval/opening on a stable root is not justified by this
prototype. The one-shot ownership rule is intentional; replaying the same
already-created bytes is different from issuing another opening.

## Independent byte-verifier demonstration

`hashline/examples/zk60_seam_receipt.rs` is a two-process **component** demo
using a public synthetic fixture, not private application data or an LLM.

```sh
cargo build --release --offline --manifest-path hashline/Cargo.toml \
  --example zk60_seam_receipt
hashline/target/release/examples/zk60_seam_receipt create NEW_PROOF
hashline/target/release/examples/zk60_seam_receipt verify PROOF EXPECTED_LEFT_ROOT EXPECTED_RIGHT_ROOT
```

The creation command emits root handles and refuses to overwrite an existing
path. The verifier reads only the bounded proof file and supplied public
root handles; it does not load inputs, witness tensors or an export directory.
In this synthetic demo the producer prints the roots; that is **not** a
registration authority and does not establish model approval. A real
enclosing proof must supply authenticated endpoints. All output records
declare `experimental-equality-only` and `goal_met:false`.

## Validation and limitations

All nine integration tests passed on CPU in the final release suite. Independent
review requested the additional equal-unweighted-sum adversary:
two changed positions cancel in sum, including a row boundary, but must
still fail verifier equality. Tests cover sub-row/full-row/multirow shapes,
fresh independent commitments, rebuilt unequal witnesses, wrong roots,
endpoint swaps/context/scale/shape replay, all message families, malformed
counts, field aliases, truncated/extended frames and changed NTT metadata.
Final combined validation and artifact commands are recorded in round 2.
`results/zk60_round2_seam.proof` is a freshly generated 416,456-byte public
synthetic fixture; its public root metadata and standalone verification
command are in `results/zk60_round2_seam.json`. Separate-process byte
verification passed; a wrong expected root and attempted overwrite refused.

Review found no obvious new acceptance flaw in the algebra or fixed frame;
it did not produce a complete simulator/security proof. Timing and entropy
handling inherit their platform assumptions. Generic PCS APIs outside this
module are not hardened by its bounded decoder. The fixture is not a
benchmark for private attention, P3 or full LLM throughput.

Next: reserve these endpoints in a new pending FFN opening lifecycle,
authenticate them to actual attention commitments, complete private lookup/
norm/attention arguments, and only then compose one and two full blocks.
That lifecycle cannot reuse the already-finalized legacy FFN openings.
