# Disposition of the hidden-endpoints-at-scale draft — security owner, 2026-09-19

Written by the interactive Claude Fable 5.1 session (the security owner) at
20:59 on 2026-09-19. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| D | `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` | the draft: how the hiding endpoints (`private_seam.rs`, `zk_ffn_fresh_io.rs`) go from a 512-word plane to model width |
| D-check | `ZK60_PRIVATE_ENDPOINTS_AT_SCALE_CHECK.md` | independent adversarial check of D: 2 blocking findings, 13 corrections, 4 conditions, one table of 19 errata (E-1 … E-19); arithmetic under `results/zk60_private_endpoints_check/` |

| Verdict | **Accepted as the design to build, with the 19 errata binding and the rulings of §2.** It is a design for widening the hiding endpoints of the private feed-forward. **It is not a privacy acceptance, it does not close D8 or D11, and the object it widens is a cost vehicle, not the P1 product** (§3). |
|---|---|

## 1. What the two documents established

1. **A mechanical widening of the hiding endpoints is unsound, and nothing in
   the present code would notice.** The seam reads one d-block of each plane
   (`zk_ffn_fresh_io.rs:301, 306`: `a.data[lay.x[0] .. +512]` against
   `endpoints[i].data[.. 512]`, and 512 is one block). The check built the
   attack: at any shape with more than one d-block, commit the endpoint plane
   `(block 0 honest ‖ arbitrary ‖ arbitrary)` and publish its real root;
   `check_endpoints` compares roots only, the sumcheck and both commitment
   claims touch block 0 only, the shape checks pin rows, and the junk sits
   inside the data rectangle. **Nothing rejects it**, and the existing tamper
   test perturbs position 271 — inside block 0 — so it would not catch it
   either. At the tiny shape there is one block, so today's code is sound as it
   stands; the hazard is entirely in the widening.
2. **Which shapes have more than one block** — the draft had this wrong and
   the check corrected it (E-1): `log_db = min(trailing_zeros(d), 12)`
   (`zkp-core/src/ffn_v3/statement.rs:139, 153–156`), so there is one block
   **only when the width is a power of two no larger than 4096**. Width 4096
   has one; **768, 2560, 3072, 5120, 6144, 8192, 12288 and 16384 have three,
   five, three, five, three, two, three and four.** "Mistral is unaffected" is
   true of Mistral and would have licensed the unsound build at four real
   model widths.
3. **Which widening is which** (E-3, E-4). The input plane is allocated
   contiguously, so a seam over exactly `T·d` words binds the whole plane —
   but a sumcheck needs a power-of-two table (`sumcheck.rs:54–57`), so that
   form exists only when the block count is a power of two. Widening to one
   block (`tdb`) is the quiet, unsound one: the masking slot at `zk.rs:2172`
   is already block-sized, so nothing complains. Rounding the plane up to a
   power of two fails loudly **and** puts a data coefficient on the
   endpoint's reserved mask pair — a hiding break.
4. **The batched multi-block seam survives the attack.** One equality claim
   over the blocks with `nb_d` fresh transcript coefficients: soundness error
   `(3m + 3) / |Fp2|`, about 2^-122; the batching costs `1 / |Fp2|` whatever
   the block count; **one claim site, one opening group and one reserved pair
   per side at every width**, so the hiding argument's pair budget does not
   grow; no unused hypercube positions on either side.
5. **Everything else holds.** The masking slot grows only logarithmically
   (`L = 2m + 4`: 22 at the tiny shape, 38 at the 125M block, 46 at one
   Mistral layer, against a budget of 256); the true ceiling is a 64-bit shift
   in two places of `CfsMask`, at 63 variables. Per opening 2^-106.25 at the
   tiny geometry and 2^-105.61 at the model one; over a 32-layer pass the 64
   extra openings cost **0.03 bit**, because the lookup term dominates the
   whole-proof figure (D15). No hypothesis of the joint-view analysis depends
   on plane length or on the number of data rows; `coset_powers` asserts
   `x_j^n ≠ 1` at every width, so the pad block stays a full-rank Vandermonde.

## 2. Rulings

**R-1. The multi-block binding is unconditional.** Any entry point of the
hiding-endpoint path that accepts a shape other than the pinned tiny one binds
the **whole** plane through the batched multi-block seam (the draft's C6, with
conditions E-16 … E-19), at every width, including widths that happen to have
one block. There is no "this width is unaffected" exemption in code or in
documents. The single-slice form remains correct, and frozen, for the tiny
path only.

**R-2. The tiny private-IO path is frozen; everything new is additive**
(E-2). `SeamSpec`, its four constants, `params()`, `digest()` and `check_ntt`
stay byte-identical: those constants are hashed into every `SeamSpec::digest()`,
which the standalone seam transcript absorbs and `into_ffn_endpoint` compares,
and `params()` fixes the root the `/2` policy carries. The general path gets
its own `SeamSpecG` with its own digest domain, its own `check_ntt_for`, a new
profile tag and a new entry pair beside the pinned ones — the pattern
`prove_layer_zk_v3_mr1` already follows.

**R-3. The pair-exclusivity rule is enforced in code on the io path** (E-18).
"A reserved pair is used by no other claim" is checked today only in the
private block's `audit_claims` (`private_block/protocol.rs:89`); on the io
path it holds by construction and is enforced nowhere. Today's joint-view
gate measured what its violation costs: two claims sharing one pair disclose
eight dimensions. The general io path ports that audit, **and a joint-view
capture of an io-path receipt at the widened shape is a hard gate before the
path is used for anything**, not a recommendation.

**R-4. The conditions on the batched seam are binding** (E-16, E-17, E-19):
the batching coefficients are fresh transcript draws taken where `tau` is
drawn — after the expected-IO absorb, after `A`'s root (`zk.rs:2542`) and
after `M` (`:2545`) — at the identical point on the verifier side, never
re-derived, and **not** refused on zero; the endpoint's committed data region
is pinned to exactly `nb_d · tdb` with a construction-time refusal otherwise;
the wire bound becomes a statement-derived exact length **with the absolute
ceiling kept and evaluated before any allocation**, with checked arithmetic;
the commitment geometry is clamped through `pcs_for`; and the 64-bit shift
guard lives in `CfsMask` itself.

**R-5. Tests travel with it:** per-block tamper tests (a tamper in block 1
and in the last block must be rejected by the **verifier** — the test that
today's code would fail if it were widened naively), a proof against a
different root, a second use of an owner, a `SeamSpecG` with the wrong data
region refused at construction, a frame one byte long and one byte short
refused before allocation.

## 3. What this object is, and is not

The draft's conceptual section stands, and the check confirmed it against the
rulings' text. **A 32-layer feed-forward-only private pass has 64
caller-fixed endpoint roots, not a chain**: attention, two norms and a
residual sit between consecutive feed-forward blocks, so no two of them share
a plane (the cost-probe memo's "33, not 64" was wrong). Every one of those
roots carries the open D8/D11 obligation in full. It is not a block under
D12, D12's items 4 and 5 bite it (the feed-forward proves no range on its
hidden input; a scale tag proves nothing), and D13's "the hidden transformer
**blocks** are enough for the first MVP" means complete blocks. **So a
feed-forward-only private pass must never be called P1.** It is worth
building for two reasons only: it is the cheapest honest **cost vehicle** for
the private line at model width — the only way to put a measured number
beside the 58.40 s public pass — and its seam is the same masked equality
between two commitments that a complete private block needs at model width to
keep the GPU feed-forward prover (the block construction memo's deferred
equality-seam form). What is learned here is on the critical path to the
real thing; the object itself is not the real thing.

## 4. What I reviewed myself, and what was delegated

I read the check's blocking findings and its complete errata table, and the
draft's and the check's hand-back reports; I did not re-derive the layout
arithmetic, the soundness figures or the pin classification myself. Both
documents were produced by delegated Opus agents, the second instructed to
assume the first was wrong, and the second reproduced the first's tiny-shape
numbers from the committed test assertions before attacking it. The check ran
no code. **Neither document, nor this one, establishes a privacy property.**

## 5. Next steps

1. Apply E-1 … E-19 to the draft and mark it accepted per this disposition.
2. Implementation, additive only, in the draft's order C1 → C8, tests first,
   at the 12 × 512 shape before anything wider. The files are the private-IO
   path Codex has asked to keep pinned, so **who writes it is settled with
   Codex first**; nothing is unpinned.
3. An io-path capture in the native capture schema and the joint-view gate on
   it (R-3) before the path is used for a measurement anyone quotes.
4. Then the model-width runs — on the 5090 machine, where the private pass
   fits.
