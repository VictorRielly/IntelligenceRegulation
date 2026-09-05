# ZK60 A1 — the path from private FFNs to private transformer blocks

Reviewed 2026-09-04 by the Codex A1 worker. Source baseline: `19ebd18`
plus C0's randomness/CLI patch, in the isolated checkout
`/tmp/zk60-parallel-OrrY0T/private_block`. This lane changes documents only.
Claude's active task and its queued `gpu/` / `pcs.rs` lane are untouched.
The machine-readable queue is [zk60_private_block_tasks.json](zk60_private_block_tasks.json).

Round-2 update: [the handoff](ZK60_PARALLEL_ROUND2.md) records an approved
fixed-T32 contract, a causal block witness oracle and an experimental
standalone private equality receipt. They do not complete A01–A10 or a
private transformer proof. The newly recorded opening-mask-rank hazard
also requires audit before sensitive use of existing private FFN paths.

## Decision

The first complete private-block target should be **P1, one tiny block,
public independently approved weights, fixed quantization, CPU-only**.
Then prove two connected blocks. P3 adds a separate approved-model
consistency obligation; a `model-id` string does not discharge it.

The smallest useful implementation before that complete block is a
**private equality/seam gadget between two independently hiding
commitments**, with a versioned pending-opening interface for the FFN.
This tests the composition problem directly. It is not itself a block
proof and must not enable `attn-pass --zk`. Running the current attention
proof beside a ZK FFN proof would still disclose the FFN input/output.

This work is CPU-first and does not need the 5090. GPU memory improvements,
exact witness acceleration, and the verifier's approved-model boundary
can proceed independently. No source changes or new performance numbers
are claimed by this review.

## What is actually covered today

| Path | Arithmetic relation implemented | Privacy and product boundary |
|---|---|---|
| `pass --profile v3 --zk` / `--p3` | Each exported FFN's gate/up/down products, fused activation lookup, requantization/range facts, optional last-FFN score predicate | Private FFN machinery exists. Separate layer inputs come from exports; no attention/residual transition connects them. Not token generation. P3 approved-weight consistency remains missing. |
| `attn-full` | One attention/norm/residual half plus ordinary v3 FFN and the two internal copy equalities | Entire path is P0. It proves a block relative to caller-provided constants/commitments, not an independently approved model by itself. |
| `attn-pass` | Above, plus previous `xres2` = next `x_in`, challenged after both activation commitments | P0 transformer-block chain. Initial embedding gather, final norm/head, token choice and decode state are absent. |
| `attn-chain` | Integer witness/digest comparison against an export | Diagnostic oracle comparison, not a proof. |

`attn_pass_run` in `hashline/src/bin/hashline.rs:1652` calls
`prove_attn` and **`prove_layer_v3`**, not `prove_layer_zk_v3`. It passes
clear `zcd_term` FFN evaluations into `attn_seam`. Its verifier uses
in-memory `(AttnConsts, FullConsts, StatementV3)` created by that same
process. Concatenated `to_bytes()` payloads are not a standalone framed
model-proof decoder. C0 correctly refuses unsupported privacy flags.

## Source-level relation and privacy map

Line numbers are navigation hints for the stated baseline; function names
are the durable ownership targets. All attention relations below run in
`attention::attn_argument` (`hashline/src/attention.rs:2194`). The numbered
sections in that function are useful implementation boundaries.

| Operation / source section | Relation and current binding | Work required for privacy |
|---|---|---|
| RMSNorm, sections 1–3 | `norm::rmsnorm_chain` builds `SS`, `D`, `D²`, `a1`, `a2`, quotient and remainders. SS row sums, `D²=D*D`, isqrt limb facts, `Extra::NormDiv`, quotient INT8 and rho/sigma limb lookups tie the two norm sites to committed inputs and gamma vectors. | Hide initial SS/isqrt evaluation claims, square/row-sum rounds, D-domain terminals and lookup counts. Convert direct linear `Ctx::check` relations to masked relation checks; comparing two independently masked values does not preserve their original equation. Gamma is public in P1, private in P3. Audit integer bounds separately. |
| QKV, section 9 | One degree-2 inner-`d` sumcheck batches `xn8 * {Wq,Wk,Wv}`; committed narrowed values plus balanced remainders reconstruct products. Q/K/V INT8 and remainder membership are in sections 4–5. | Claimed products and activation terminals are secret even in P1. P3 also needs weight-terminal masking. Do not mask both sides of a bilinear product in one extension without a vanishing branch; existing `zk::mask_specs_v3` explains its two-extension FFN solution. |
| RoPE, sections 4–5 | Q/K zero-checks use public regenerated/digest-checked C/S tables, a rotate-half coordinate flip, requantization and range facts. | Each ordinary and flipped-point private claim needs planned mask coverage. Public C/S are not secret; preserve their point mapping and table identity. |
| Scores, section 10 | Degree-3 sumcheck for `QR * KR^T`, with a public equality factor and GQA high-bit mapping; score/remainder claims tie back to S planes. | QR and KR are both private already in P1. A valid extension may use the existing equality factor's zero extension; prove that the entire mask-side polynomial is zero. Audit padded/non-power-of-two query-head mapping. |
| Integer softmax, sections 6–7 | `SPlan` (degree 5) proves masked score definition, `(m-sM,E)` membership in the 256-row exp member, binary attaining selector with row sum 1, causal E row sum, `P*Sum+rho=2^fP*E` on support, and `P+rho=0` off support. `P` and rho/sigma are range-checked. | Hide score/max/sum/P/E/selector/remainder terminals, row-sum claim, all S rounds and histogram/helper facts. “Masked” here means the **public causal mask**, not cryptographic hiding. Keep integer exp semantics; do not substitute floating softmax. |
| PV, section 11 | Degree-3 GQA sumcheck for `P*V`, with narrowed O and its balanced remainder. | Both P and V private in P1; preserve equality-factor extension and point maps. |
| Output projection, section 12 | Degree-2 `O*Wo` sumcheck, AO class reconstruction and requantization. | Hide product claim, AO limbs/remainder and O terminal; P3 also masks Wo. |
| Residuals, section 3 | Two linear equations bind rescaled `x_in+AO` to `xres1` and rescaled `xres1+z16copy` to `xres2`, with declared shifts, remainder windows and class lookups. | Current equations act on clear `vd` values. Move them into a masked zero-check; reserve independent mask sites for every reconstructed limb. |
| All attention lookup facts, sections 3–8 and 13 | `d_lookups`, `q_lookups`, `kv_lookups`, `Tbl`, `ClsPlane`, `build_helpers`; isqrt U16 limb slice; public histograms with exact tags/sizes/totals and LogUp helper-sum identity. INT24 uses U16+U8, not two unrestricted U16 limbs. | Commit histograms privately before lookup challenges, add table-side committed helpers/zero-checks, and prove one masked zero-sum identity. Never publish per-helper sums or histograms. Public totals remain shape-derived. |
| FFN | `layer::prove_layer_v3` is used in full blocks; standalone private equivalent exists in `zk::prove_layer_zk_v3`. | Reuse the private FFN argument, but refactor its commitment/opening lifecycle for reserved internal seam claims. Its present return value has already finished openings. |
| Internal FFN seam | `attention::attn_seam`, CLI `seam_points`: `xm8=X_ffn`, `z16copy=z16_ffn`, using FFN zero-check-D points and clear terminals after both commitments. | New private equality proofs on both pairs. The ZK FFN's masked `zc17_term` is not interchangeable with P0 `zcd_term`; copying it into the old comparison is incorrect. |
| Cross-layer seam | `attention::layer_seam`, `cls_claim`: reconstructed previous `xres2` equals next `x_in`; previous A opening is deferred. | Keep commit-before-challenge ordering, but prove equality without publishing either MLE or limb MLE. Bind exponents/classes as well as field words. |

## Complete exposure inventory for the current full-block proof

1. `prove_attn` uses ordinary `pcs::commit` for W, A and H, then
   `pcs::open`. A/H opened encoded columns and clear row-combination
   vectors are witness-dependent; unsalted deterministic commitments are
   not a hiding substitute. P1 may expose W, but must authenticate the
   approved W/gamma roots independently. P3 may expose neither W nor gamma.
2. `AttnProof.mults` and `absorb_mults_a` publish full witness histograms.
   Tag/count totals alone are public shape facts; individual bins are not.
3. `Cc::take/a1/h1/hsum`, `claim_at`, `claim_sub`, `terms` and `cls_claim`
   publish raw private polynomial evaluations in `AttnProof.vals`.
   This includes norm statistics, helper sums, reconstructed limbs and
   both seam types. Attention's `helper_sums` struct field is currently
   unused by the argument: actual attention helper sums travel through
   **`Cc::hsum` into `vals`**. Deleting that field would not remove them.
4. `Ctx::sc` emits ordinary witness-dependent sumcheck rounds, including
   cases whose claimed sum itself is private (matmuls and row sums).
5. `collapse_range`/`collapse_a` (L5) emit additional ordinary sumcheck
   rounds and the raw A evaluation `aval`. They cannot run unchanged on
   private A. First private version should use fixed, explicit **no-collapse**
   policy in its statement and `ZClaim` openings, accepting larger proofs.
   A later private collapse needs its own masking and cost accounting.
6. The current FFN in `attn_pass_run` is itself P0 and emits its own
   histograms, rounds, helper sums, terminals and ordinary openings.
   Making attention private while leaving this FFN unchanged is insufficient.
7. `attn_seam` exposes FFN X/z evaluations; `layer_seam` exposes residual
   evaluations and, for INT24, individual limb evaluations. A shared
   transcript binds their order but does not hide any message.
8. `fit_requant`, `fit_norm`, `residual2` and CLI `derive_ffn_on` fit
   shifts/classes or widths from current witness magnitudes. Their public
   constants, selected activation table and norm remainder widths can
   reveal input-dependent facts and change the calibrated computation.
   Freeze these values from an independently approved calibration for
   the first P1 block; reject out-of-range witnesses instead of fitting.
   Supporting adaptive quantization later requires an explicit model/
   leakage policy and proof of the selection rule, not merely logging it.
9. `witness_digests`, `verify_export`, `consts_line` and bad-range diagnostics
   are useful local debugging tools, not production-private metadata.
   Witness digests can permit dictionary testing. Keep them out of public
   artifacts unless the disclosure is explicitly part of the statement.

Public shape, layer index, fixed shifts/classes, approved table digests,
RoPE schedule, causal policy, P1 approved weights, and declared output
disclosures are intentionally public. The distinction must be explicit
in a new profile tag; neither root salting alone nor random-looking proof
bytes establishes whole-proof zero knowledge.

## Correctness gates before masking changes

These are source-review obligations, **not claims of reproduced exploits**.

- `AttnConsts.norm_round` permits floor/round witness construction, while
  `Extra::NormDiv` and the sigma check implement round unconditionally.
  The first new profile must require round and reject floor; a boolean
  field or comment must not suggest a second proven semantics.
- Derive checked integer bounds for every declared shape/shift. In
  particular, prove that isqrt reconstruction, `D²`, SS, norm division,
  rho+sigma, scaled residuals and quotient products cannot satisfy a
  different equation by wrapping modulo the field. D is not directly a
  signed-integer lookup column; show its range follows or constrain it.
  Norm limbs use U16 chunks, so their actual bound is the chunk width,
  not automatically the advertised `wrho`. Test field aliases, oversized
  shifts/limb counts, and the exact class endpoints (-128/-32768 included).
- Off-causal `P+rho=0` implies each is zero only with the advertised
  nonnegative bounds and a no-wrap argument. Max/attainment is for the
  **masked score array**, including -127 off support; retain that exact
  semantics and test rows at the INT8 lower endpoint.
- Require nonzero power-of-two T/head dimension, valid GQA divisibility,
  supported KV-head padding, consistent tensor lengths and layer indices,
  fixed proof parameters, and checked allocation arithmetic. Current
  builder assertions are not a malicious-proof verifier boundary.
- Freeze both sides' exponents/classes on every seam. Equality of integer
  words is not equality of represented values if the scales differ.
  Reject swapped/missing/duplicated layers, wrong RoPE positions and
  caller-selected statement constants outside approval.
- Preserve exact expected sumcheck, claim, mask-functional, opening and
  table counts; reject extra data as well as missing data in the new
  format. Existing `Ctx::sc` consumes a sequence of proofs but does not
  itself make a final exact-count assertion.

## Reuse boundary and proposed interfaces

Reuse the construction present in `zk.rs`; do not rewrite CUDA or PCS in
this lane. Existing reusable building blocks are `CfsMask`, `MaskFunctional`,
`mask_commit`, `mask_open`, `mask_verify`, plus `pcs::{CommittedZk,
ZPart,ZClaim,commit_zk_owned,open_zk,verify_zk}`. `masked_prove`, `extension`
and FFN claim assembly are currently internal helpers with fixed FFN
assumptions. Extract only the needed **crate-internal** API behind tests.

Proposed new `attention_zk.rs` types, not implemented by this review:

```text
PrivateBlockStatementV1  approved shape/scales/tables/roots, P1, coverage
AttnZkLayout             data/table rows, unique mask sites, fixed SC schedule
MaskedClaimSite          commitment + slice + point-role + mask-row identity
PrivateBoundaryPlan      reserved incoming/outgoing and FFN-X/Z equality sites
AttnZkPending            owned commitments, claims, completion state
FfnZkPending             new opt-in FFN lifecycle, preserving legacy wrapper
PrivateBlockProofV1      explicit framed P1 proof; no P0 fallback variant
```

Plan mask rows **before** committing; do not append a new mask after the
challenge or recommit a seam copy without proving it is the same value.
All raw/private terminal pathways should require `MaskedClaimSite`, not
an untyped `Fp2` that can accidentally enter a public collector.

For a first equality gadget on two committed same-shape planes A and B,
challenge a random equality-weighted sum of `A-B` to zero only after both
roots are bound. Use masked sumcheck rounds, reserved independent terminal
mask rows for A/B, and an authenticated mask-functional opening. An
extension must preserve the Boolean sum: for the equality-weighted
polynomial, extend the public equality factor to zero on the mask branch.
The terminal check then uses the masked A/B values, not a comparison of
unmasked MLEs. This is a **candidate interface and algebraic design**, not
a composition theorem; it needs the tests and review below. Never set
both masks equal merely to make old direct equality comparisons pass.

For each attention polynomial, explicitly test `poly(extension_branch)=0`
and record its resulting degree before adopting this pattern. Degree-5
softmax, coordinate-flipped RoPE claims, replicated norm rows and P3
bilinear products must not inherit FFN degree/point assumptions blindly.

Reserve new FFN boundary masks only in the new block profile. Keep legacy
`prove_layer_zk_v3`/`verify_layer_zk_v3` behavior and seeded artifacts intact
for ordinary FFN calls. A pending object may close A only after its
registered seam claims are consumed; double-finalize and missing-seam
states must fail. W/H can close early only when no later argument needs
them. Retain at most previous/current pending A objects in the chain.

## Ordered tasks and independent lanes

The JSON companion supplies exact files, dependencies and acceptance
tests. These are **proposed next implementation tasks**, not new authority
for this documentation worker to edit source or assignments already run.
A00 and A01 are logically independent but name shared future source files;
split their file ownership or serialize those edits before scheduling them.

| ID | Small deliverable | Depends on | Suggested owner / scheduling |
|---|---|---|---|
| A00 | Approved fixed block contract; verifier shape/range/rounding preconditions; tiny deterministic oracle fixture | None | Correctness worker; can start before GPU |
| A01 | Enumerated 13-argument schedule, private exposure/mask-site manifest and hostile-proof test helpers | None | Independent test worker; can start before GPU |
| A02 | Standalone private equality gadget on two hiding commitments | A00, A01 | ZK worker; CPU only |
| A03 | Opt-in pending ZK FFN lifecycle with reserved X/Z boundary claims | A02 | Integrator owns `zk.rs`; no concurrent shared-file edits |
| A04 | Private attention table side and lookup plumbing | A00, A01, A02 | ZK attention worker after shared API settled |
| A05 | Private norms/residuals and QKV/RoPE/O-projection arguments | A04 | Same attention owner; tiny shapes |
| A06 | Private score/softmax/PV arguments | A05 | Same attention owner; degree-5 and GQA adversarial gates |
| A07 | One P1 block with both private FFN seams; typed API only | A03, A06; approved P1 identity boundary | Integrator; first complete-block milestone |
| A08 | Two-block then 125M chain; framed independent-byte verifier; guarded CLI | A07 | Integrator; request/output policy reviewed before CLI enablement |
| A09 | P3 block extension and approved private-weight consistency | A08; Fable-reviewed P3 identity construction | Separate reviewed protocol milestone, not a flag flip |
| A10 | Embedding/final norm/head/token choice plus stateful windows | A08; product release/lag decision | Model-interface worker; full-generation milestone |

For speed work, A04–A06 should emit per-subargument timings and allocation
counts without claiming a private-block headline until A07 is complete.
The dense S planes scale as `padded_heads * T * T`; norms/residuals/QKV
activations scale linearly in T. Private no-collapse openings may grow
substantially: measure that cost before designing private claim collapse.
Do not apply old FFN speedup factors to these new relations.

## CPU-first acceptance and 5090 handoff

First fixture: proposed `T=4, d=16, H=2, Hkv=1, dh=8, f=16`, round norm,
fixed table/shift choices that demonstrably fit. Include T=1/2/4 and
query-head padding cases in targeted tests; table commitments may still
use their full public sizes, so "tiny" is not permission to weaken
security parameters. Build the oracle from exact integer arithmetic and
compare every witness plane against it, not only the final result.

Positive gates: same witness with fresh default configurations verifies
repeatedly and differs in private commitments; reference integer planes
match; all reserved opening sites are consumed; P1 approved roots match.
Negative gates: malicious witness rebuilt after mutation must reach the
**verifier** and reject, not merely trip a prover assertion. Cover every
named relation, a broken internal seam, a rebuilt second block on a
different input, statement/mode replay, table/root replacement, omitted
mask sites, tampered mask functionals, range aliases and malformed counts.
Leak scans/uniqueness tests are regression diagnostics, not a ZK proof.

Suggested commands after corresponding source tasks land:

```sh
cargo test --release --offline --manifest-path hashline/Cargo.toml
cargo test --release --offline --manifest-path hashline/Cargo.toml --test zk60_private_seam
cargo test --release --offline --manifest-path hashline/Cargo.toml --test zk60_private_block
```

The named integration tests are planned files, not currently existing
tests or commands executed by A1. Before integration, run the current
four frozen fixtures with unchanged seeded bytes on both binary variants;
the lead owns resource-heavy validation. After the 5090 arrives, run
small CPU/GPU oracles and one/four-layer memory gates before larger work.
No 8B private GPU job belongs on the present 8 GB laptop.

Even A08 is only **private transformer blocks**. For generation, A10 must
bind input token IDs to an approved embedding gather; final RMSNorm,
vocabulary projection and quantization; the actual emitted token selection
(argmax/tie policy or explicitly specified sampling randomness); request,
position, context and previous-window state. Decode/KV support must prove
the cache read/update relation, causal/sliding-window policy, RoPE absolute
positions, and input/output state commitments across windows. Recomputed
prefill rows do not prove fresh autoregressive token choices. Delayed
window proofs and proof-before-release tokens have different clocks and
must be reported separately.

## Evidence and limitations

This report is based on read-only source inspection of `attention.rs`,
`norm.rs`, `zk.rs`, relevant `pcs.rs` interfaces, `layer.rs` and the CLI,
plus the current execution/parallel plan and repository instructions.
No external cryptographic theorem is asserted or used to certify this
proposed extension. The existing `zk.rs` documentation itself says a
written simulator for layer composition remains owed. An independent
review must supply applicable hiding/soundness/composition arguments at
actual dimensions before the product security claim is closed.

Validation performed in this documentation lane: JSON syntax, task-ID and
dependency integrity, referenced current source-function existence, and
`git diff --check`. No compilation, GPU run, protocol implementation or
new benchmark was performed by A1.
