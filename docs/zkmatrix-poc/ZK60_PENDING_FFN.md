# A03 — pending private-FFN opening interface

Status: **review proposal, not an implemented pending prover**. Source:
`24ae746`, `hashline/src/zk.rs`, `pcs.rs`, `private_seam.rs`, and the A00
contract. Four pure layout tests were added in this round and pass; they
pin existing metadata/counts, not privacy. No production ZK/PCS/GPU code
is modified by this proposal. Independent privacy review remains required.

## Decision and boundary

Do not append equality claims to the result of `prove_layer_zk_v3`.
It has already opened W, A and H and dropped their committed states.
The new block profile needs a separate prepare/argument/boundary/finalize
lifecycle, with every mask reserved **before** its commitment is made.
Preserve the existing standalone function and seeded byte fixtures; use
a new transcript domain and proof envelope for the new profile.

First scope: A00's T32/d16/f16 P1, committed output, no predicate, public
independently approved weights, fixed calibration, no claim collapse.
P3, predicates, adaptive fitting, GPU dispatch and private commitment reuse
are not implied. An A00 approval object pins metadata; it does not certify
the arithmetic proof or the privacy of its opening construction.

The round-2 S2 proof is useful for testing the equality relation, but its
`PreparedPlane` owns a separately committed whole plane. It cannot be
silently reused as a subplane of the FFN's A commitment. A proof about
copied X/Z planes needs a further consistency relation to the actual
arithmetic commitment and is not an acceptable substitute.

## The current call, in code order

`prove_layer_zk_v3` currently performs all of these steps before returning:

1. Make `ZkLayoutV3`, validate the predicate slot, absorb `StatementV3` and
   `ZkStatementMode`; draw fresh secret RNG state unless an explicit public
   fixture seed was supplied.
2. Pack/commit W. P1 uses plain public `wcache::commit_w`; P3 uses a fresh
   hiding commitment and refuses the public weight cache. Absorb W.
3. Pack A, including FFN planes, six committed histograms, and all reserved
   terminal/proximity masks; commit and absorb A.
4. `mask_specs_v3` fixes six CFS polynomials (seven with predicate), then
   `mask_commit` commits them. Absorb M **before** lookup challenges.
5. Draw beta/gamma/alpha, build the witness/table helpers and masks, commit
   and absorb H; prove g/u, d, zero-check F, zero-check D, table and zsum,
   plus predicate if enabled. Construct masked terminal messages.
6. Build `MaskFunctional`s and execute `mask_open`; then
   `build_claims_zk_v3` constructs all W/A/H claims from the final points.
7. Open W, drop W; open A, drop A; open H, drop H. Return only proof,
   timings and diagnostics. `verify_layer_zk_v3` replays the corresponding
   argument, mask verification and openings in the same order.

At present `pcs::open_zk` takes an immutable borrow; its API does not
consume or enforce one-shot use. `CommittedZk` also has public data/pad
fields. A new higher-level owner must keep it private and consume it once.
This does not prove that its one-shot transcript is zero knowledge.

## Exact X/Z mapping to retain

| Endpoint | Actual FFN source | Domain | Scale/representation obligation |
|---|---|---|---|
| Attention norm output -> FFN input | `LayoutV3.x[c]`, `tdb` words | `log_t + log_db`; row-major token/block-column | `AttnConsts.e_xm == V3Exps.e_x`; signed INT8 relation |
| FFN output -> attention residual's copy | `LayoutV3.z[c]`, `tdb` words | same d-block cube | FFN `e_z16 == FullConsts.e_z16`; signed INT16 relation |
| Cross-block residual -> next input | attention class-plane reconstruction, not FFN X/Z | each block's attention layout and limb convention | layer order, class and physical exponent pinned by approval |

Here `db=2^log_db`, `tdb=T*db`, and `c` is a block index. A complete
T*d plane is not necessarily one contiguous opening slice for arbitrary
non-power-of-two d; preserve `LayoutV3`'s actual blocked packing.

The current zero-check-D terminal vector contains grouped ranges, in order,
`X[0..nb_d], Z[0..nb_d], rd[0..nb_d], hz[0..nb_d]` evaluated at `rho_d`,
not interleaved per-block tuples. These are **masked** by extension `e_dz`.
Its X/Z masks are `a_md[3*c]` and `a_md[3*c+1]`; those are neither raw
seam values nor freely reusable randomness. `gu_term` has its own X masks
at `p2`. Do not reinterpret either vector as P0's `zcd_term`.

At A00's tiny shape a data slice has nine variables (512 words), while
an A mask row has eight (256 words). `build_claims_zk_v3` evaluates that
row at the **tail** of the point. Subslice row weights, coordinate flips,
limb reconstruction and zero-extension coefficients must be represented
explicitly in the new plan, not inferred from matching vector lengths.

Round-3 B3 also exposed a distinct tiny **public attention W** issue:
Wk/Wv are 128-word slices under a 256-column commitment, while the legacy
PCS opening assumes a slice is at least a full row. Its wrapper therefore
needs exact public subcube lifting to the enclosing committed row, on both
prover and verifier. That is not an FFN X/Z mask mapping or permission to
apply the same adapter blindly to private claims; audit those separately.

## Proposed ownership interface

This is conceptual pseudocode, not a promised or exported Rust API:

```text
ApprovedBlock + reserved boundary roles
    -> PreparedFfn   [W/A commitments, all terminal masks, CFS root]
    -> PendingFfn    [core arguments and helper commitment; unopened claims]
    -> BoundFfn      [both mandatory X/Z equalities added on actual roots]
    -> FinalizedFfn  [one mask opening, one opening per owned commitment]
```

An enclosing `PendingBlock` owns both the pending attention state and this
FFN state. It routes each equality's claims and mask functionals to **both**
actual owners before either opens, then emits the complete block proof only
after both components finalize. The FFN-only lifecycle cannot finalize its
peer. Public peer handles are provisional, not evidence of already-verified
peer arithmetic: requiring that during attachment would be circular in the
combined transcript. Final block verification authenticates both peers and
the connecting relations together.

Each transition consumes its input. Secret state has no `Clone`, `Debug`,
serialization or public committed-data accessor. Only public handles may
be copied: contract/context digest, role, actual commitment root/shape,
slice description and physical scale. A handle is not an equality proof.

Preparation must accept a closed, versioned boundary manifest derived
from the approved block: exactly X and Z for every supported d-block,
and no generic arbitrary `Vec<ZClaim>` append API. The manifest pins
ordered roles and required independent masks/CFS slots before A/M roots.
The first profile must reject missing/duplicate roles, unsupported slices,
new late mask requests and predicates/P3 before allocation or hashing.

Argument generation retains the committed states and CFS witness while
building base claims; do not serialize or call any opening yet. Boundaries
must refer to the actual committed A plane and the peer commitment bound
in the same enclosing block context. The consumer checks scale and role as
well as root equality. Independent producer metadata is insufficient:
the final block verifier must also verify the peer arithmetic.

Finalization requires both internal boundary proofs, collects all related
mask functionals, and opens each actual commitment once in a fixed order.
The verifier reconstructs the manifest/claim schedule from independently
approved metadata and parsed proof messages; it never trusts a producer's
"all boundaries verified" bit. A partial object is not a valid receipt.

## Transcript proposal and compatibility boundary

For the first composed implementation, commit all relevant W/A states and
their CFS masks before drawing their argument/equality challenges. Bind a
new block-profile tag, approval/calibration digest, layer/request context,
boundary manifest and parameter policy. Helpers may be committed only
after the public challenges needed to construct them; their roots must
precede the arguments that use them. The exact cross-module ordering must
be agreed with the private-attention implementation, not bolted on later.

After both actual A roots and all equality masks are bound, draw each
equality challenge and run its masked relation. Then authenticate all CFS
functionals and run the planned W/A/H openings. New domain separation and
proof framing are required: neither `LayerProofZk`'s current serialized
concatenation nor `HLSEAM01` describes this combined transcript.

Do not fork/clone a completed transcript to add extra private openings.
The repaired Orion-lineage paper distinguishes a single batched multipoint
Eval from repeatedly invoking Eval on a private commitment; its theorem
does not authorize our repeated-opening interface. This is a design
constraint informed by [Scorpius, section 4.7](https://eprint.iacr.org/2024/1164.pdf),
not a claim that hashline implements its full construction.

Initially preserve all legacy standalone paths unchanged. After review,
the new profile can reuse arithmetic helpers, but do not route legacy
bytes through a changed mask layout or change the old transcript order.
A later mechanical extraction may share code only after all old fixtures
and new negative cases pass together. CPU/GPU parity is another gate,
not inferred from CPU success.

## Masking obligations before source implementation

The inherited single-base-mask configuration already has a tiny diagnostic;
this proposal does not repair it. A complete new profile must review the
**existing** A/helper/histogram claims as well as the newly added seams.
Appending paired seam masks alone cannot repair a leaking core argument.

- Inventory every actual column-weight group and all repeated uses of
  each random row across terminal, proximity, sum and mask-functional
  messages. Nonzero mask coefficients are not a joint-rank argument.
- Paired independent base rows can represent an Fp2 mask at a local site;
  S2 uses this. Reserve them before commit, but prove privacy jointly with
  all other observations rather than treating local rank as a certificate.
- In `pcs::zk_rhos`, both group and proximity coefficients are drawn before
  their vectors are absorbed. Its source comment describes a different
  order. Analyze the code's order and all conditioning, not the comment.
- Equality uses a vanishing extension branch. A private attention product
  with two hidden factors cannot simply extend both with nonzero masks:
  their product need not vanish. Preserve/prove the relevant selector or
  multi-extension construction. `mask_specs_v3(..., true)` illustrates
  the existing two-extension P3 matmul obligation, not a P1-attention fix.
- Account for pad count, effective hiding code dimension/distance,
  challenge distribution, CFS functionals and cumulative column queries.
  Reject unsupported parameter/degenerate cases; do not silently resample
  or weaken a security claim to make a fixture pass.

Fable's independent review remains owner of the broader audit/repair
recommendation. No production/private-input safety claim follows from
this interface memo or the new P0 block proof tests.

## Counted tiny memory and reserved slots

`zk60_pending_layout.rs` checks actual `ZkLayoutV3` constructors without
large tensors. At T32/d16/f16, log_cols8, inverse rate8, Q256, shifts
(7,0,14,6), no predicate:

| Quantity | Existing value |
|---|---:|
| A/H/W ordinary data rows, width256 | 20 / 16 / 3 |
| Six histogram slot row counts | 1 / 256 / 1 / 1 / 64 / 1 |
| Full legacy A/H commitment rows | 681 / 1325 |
| A+H data and full encoded arrays alone | 36,974,592 bytes |
| Core CFS (variables, degree), P1 | (5,2), (5,2), (10,4), (10,4), (9,2), (17,3) |

The memory number excludes pads, salts, trees, proof vectors, temporaries,
attention, GPU copies and allocator/pool retention. It is a **count**, not
measured peak RAM. Hiding code dimension is n+Q=512 over 2048 encoded
columns, effective rate1/4 rather than1/8. This is not a soundness theorem.

No existing A row is unallocated. Two independent paired X/Z boundary
sites per d-block would alone add `4*nb_d` base rows; this is not the cost
of a complete repaired profile. Existing masks/histograms/proximity may
need changes too. Freeze the full allocation manifest only after review.

Deferring openings retains encodings, data, pads, salts and Merkle trees.
The first tiny implementation should keep explicit owners until finalization.
After correctness, W/H may be eligible for earlier release only if all
claims on them are closed and the agreed transcript supports that order.
Do not claim A03 is a memory optimization: composition can increase overlap.

## Acceptance for the next implementation

1. Independent API/privacy review selects a concrete new mask/claim plan;
   record what theorem and parameter assumptions are actually justified.
2. Honest synthetic fixed-oracle block verifies with authenticated X/Z
   seams on the arithmetic commitments; input/output substitution fails.
3. Reject missing/extra/reordered roles, scale/offset changes, wrong peer
   roots, late masks, duplicate finalization and truncated frames. Bind and
   check an independently supplied expected request/session context; the
   proof must fail under a different context. Identical valid bytes under
   identical expected context remain valid to a stateless verifier. Rejecting
   repeated application requires application-level nonce consumption.
   Rebuilt invalid witnesses reach verifier refusal where safely supported;
   a prover assertion is not counted as that evidence.
4. Preserve old CPU/GPU explicit-seed artifacts; new-profile default proofs
   use fresh OS randomness and never print witness values or seed state.
5. Independently decode the **new complete** proof envelope with exact
   counts, canonical fields and bounded allocations before generic PCS
   verification. The round-2 standalone decoder does not cover this.
6. Record real memory lifetimes and proof-ready clocks before optimization;
   no 5090 speed or full-model coverage is inferred from this tiny milestone.

Round-3 local layout gate: release/offline, shared lock, two threads,
`cargo test --test zk60_pending_layout`: **4 passed**, no proof generated.
The final combined validation record supersedes this local gate.

An independent read-only interface review confirmed the counted facts and
legacy lifecycle. Its block-owner, request-context and grouped-terminal
ordering clarifications are incorporated above; this was not a privacy audit.
