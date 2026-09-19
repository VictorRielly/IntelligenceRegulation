# Review: next native private block and the delivered attention verifier

Independent Claude Fable review, 2026-09-19. Read-only: nothing was built, run or edited. "Verified" below means I read it in source during this review, and "recomputed" means my own arithmetic.

## Summary

- **Attention verifier:** I found no integration-blocking correctness error. All 18 slot identities, the host accounting, the terminal claims, the LogUp closure and the PCS refusal replay check out against source. There are four non-blocking findings in §1.
- **Next block implementation:** build one shared layout with no seam (form S). It already exists on lane `zk60-private-block` at `98a5db9`, grown from the accepted attention files. Codex's next step is to integrate that lane after `zk60-attention-compile`, not to join `private_attention` to `zk_ffn_fresh_io`.
- **D8, D11 and D12:** nothing here narrows them, and no privacy property is claimed.

## 1. Attention verifier inspection

All paths in this section are `hashline/src/private_attention/`.

### Verified source facts

- **Host accounting is sound.** A private slot's scalar is unconstrained on its own (`argument.rs:306`). It is bound only through its host, where the claimed sum is `Γ_host + Σ ν·claim_s` and one M functional carries `c_h·Σ_h − Σ ν·c_s·Σ_s` (`:350-357`).
  - Every private slot is hosted exactly once and its host runs later (`layout.rs:541-553`).
  - ν = 0 is refused (`:472`).
  - The row-sum host coefficient `ν·T` matches the j-constant host term (`:709`, `:726`).
- **The extension rounds are sound.** `F(x, e=1) = 0` for all 18 slots.
  - Every term of every slot carries an eq or public-table factor.
  - In the two bilinear slots each private factor vanishes on the other's extension round.
  - The terminal coefficients `cd = Π(1−e)` and `cm = e_m·Π_{k>m}(1−e_k)` match the prover's table evolution (`:336-341` against `:279-292`).
  - This matters for soundness, not only privacy: a term without a public factor would give a cheating prover slack through the mask rows it chooses.
- **Coordinate conventions are correct.**
  - The RoPE flip lands on the most significant bit of `i'` in both domains (`:662-663`).
  - Point orders for QMM, KMM, VMM, SCORE, PV and WO match the plane domains.
  - Sub-row slices (limbs, `A_D`, `A_MX`, `A_SUM`) use consistent `c0` and tail in `mask_eval` and `build_claim`.
- **The integer pins hold over the enforced ranges.**
  - isqrt is pinned through `a1, a2 ≥ 0` (three limbs each).
  - The norm quotient is pinned through `σ + ρ + 1 = den`.
  - The symmetric int8 lookups give exactly `[-127, 127]`.
  - Selector booleanity, `zsel·δ = 0`, and the exp lookup on all (h,t,j) together pin the row maximum.
  - Off the causal support, `p = ρ = 0` is forced.
- **The LogUp identity closes as intended.**
  - It is one value-0 sum claim over all H planes, with table helpers negated (`protocol.rs:47-57`).
  - The ZS slot proves the masking pair `u` sums to zero.
  - Multiplicities are committed before α, β, γ (`protocol.rs:311-323`).
- **The PCS refusal replay matches the PCS today.**
  - `part_key` equals the key rule of `zkp-core/src/pcs.rs:752-792`.
  - The replay order (λ per group, then `rows` proximity draws; `protocol.rs:136-170`) equals `zk_rhos` (`pcs.rs:835-856`).
- **The delivered byte count is right.** Recomputed 136 + 11,296 + 223,232 + 980,992 + 768,000 + 262,144 = 2,245,800.
- **Kernel parity on masked scores.** The witness refuses an out-of-range masked (j > t) score, matching the kernel (`witness.rs:166-175`, `causal_oracle.rs:302`). This is not a divergence.

### Findings, none blocking

- **V-1: the refusal replay is not pinned to the PCS draw order.**
  - The only test injects draws (`tests.rs:289`).
  - If zkp-core ever reorders its draws, soundness is unaffected, but the zero-coefficient and proximity-pair refusals would silently examine the wrong values.
  - The block module carries a second copy of this code.
  - Recommendation: do the disposition's P-1 at integration, with one shared helper fed by the PCS's own draw routine, plus a test that pins the order.
- **V-2: `IoSpec::new` accepts any scale pair** (`private_attention.rs:150-154`). This is known from D12 item 5; the block module pins `(0, 0)`. The attention profile should stay "experimental component" until this is fixed.
- **V-3: stale text in the lane's `private_block.rs`.**
  - Lines 45-47 still list the composition with norm_m, the feed-forward and residual 2 as not addressed.
  - Lines 371-372 say "attention output" where the block output is meant.
  - Fix at integration: only inter-block chaining (A4) is actually open, and the stale sentence misstates what the module covers.
- **V-4: an opening-group count mismatch returns an error without the "discard attempt" phrase** (`protocol.rs:164-166`). It can only happen on a challenge collision, so this is cosmetic.

### Not checked

- The internals of `masked_prove`, `extension` and `sumcheck::verify` (shared with the FFN).
- Any execution.
- Privacy beyond the schedule rules.

## 2. The next implementation: one layout, no seam

### Why not join the two existing components

- **The transcript cannot be shared.** `zk_ffn_fresh_io` creates its own transcript (`zk_ffn_fresh_io.rs:138-146`, `:163`), uses `NttTables::new(16)` against attention's `new(12)`, and uses seam slots 1..4 against 21..24.
- **The values do not line up.** Its input is `nm`, not `xres1`, and no second norm sits between them. D12 item 4 records that the FFN proves no range on its input; I did not re-verify that.
- **Both possible joins are inadmissible.**
  - One `xres1` endpoint commitment opened by two proofs is exactly D11's broken configuration: two openings recover all 512 words.
  - Two separate commitments to a value that "should" be equal, with no equality argument, bind nothing: a prover can commit different values. That is not a seam.

### Construction (verified on lane `zk60-private-block` at `98a5db9`)

- **Shape:** one A, one H, one M, one transcript. The external endpoints are `x_in` and `xres2` only (`argument.rs:896-903`).
- **Commitment sharing:** a hidden intermediate is a single plane that every relation reads. Each read is a separate claim site with its own reserved mask pair. No equality between commitments is argued anywhere.

| Value | Plane | Read at (one pair each) |
|---|---|---|
| `xres1` | `A_X1` | SSM, DZC |
| `nm` | `A_YM` | DZC, GMM, UMM |
| `h16` | `A_H16` | FZC, DMM |
| `z16` | `A_Z16` | DZC |
| `xres2` | `A_X2` | DZC, IO-out |

- **New relations:**
  - The second norm is the attention norm relation over `x1` with `gamma_m`, hosted with the first in TZC, plus `sym(A_YM)`. That symmetric lookup is D12 item 4's mandatory int8 proof.
  - The feed-forward adds:
    - `a16·u16 = 2^14·h16 + rh − 2^13`;
    - the fused `(g8 + 128, a16)` activation lookup under `TAG_ACT = 134`;
    - the int16 limb decompositions;
    - FZC hosting the gate and up matmuls;
    - DZC hosting the down matmul alongside Wo;
    - `x2 = x1 + z16`.
- **Sizes against the attention component:**

| Item | Attention | Block |
|---|---|---|
| Slots | 18 | 23 |
| Hosts | 5 | 6 |
| M rows | 40 | 50 |
| Functionals | 28 | 34 |
| A rows (total / data / site pairs) | 306 / 154 / 75 | 455 / 213 / 120 |
| H rows (total / data / site pairs) | 290 / 218 / 35 | 384 / 280 / 51 |
| A opening groups | 30 | 35 |
| H opening groups | 8 | 9 |
| Largest mask length | 50 | 50 |

  I reconciled the site deltas slot by slot: +45 on A and +16 on H.
- **One opening per commitment:** the prover makes exactly one `mask_open` and four `open_zk` calls. Each owner is dropped after its opening (`protocol.rs:392-407`).
- **Endpoint scope preserved:** the lane keeps the 7-row `private_seam` endpoint planes, owners consumed by value, and the module doc keeps D8 and D11 open. I did not read the lane's endpoint claim check body, only that it exists (`protocol.rs:184-202`).

### API changes

- **New public API** in `hashline::private_block`:
  - `BlockPublic` and `FeedForwardPublic`. The activation table is held as `[i16; 256]`, under one digest with the attention statement.
  - `IoSpec` pinned to scales `(0, 0)` with seam slots 41..44.
  - `ExpectedIo` with frame tag `HBLKEXP1`.
  - `prepare_endpoints`, `prove`, `verify`, `verify_bytes`.
- **Transcript:** adds a `"calibration"` absorb between `"parameters"` and `"schedule"`.
- **Edits to existing files:** three only.
  - `pub mod private_block;` in `lib.rs`. Main's `lib.rs` is already modified, so expect a one-line conflict.
  - A `private-block-kernel` dev-dependency.
  - The `TAG_ACT` constant in `tables_attn.rs`.
  - The helpers it needs already exist in `zkp-core` (`fold_cols_i8`, `int16out_member`).
- **Merge order:** `zk60-attention-compile` first (`58f6150`), then the block lane. The block lane's implementation disposition records the accepted attention files as byte-identical between the two lanes; I did not compare them myself.

### Table and byte costs

- **Tables:** three 256-entry tables (U8, exp, act), with no 65,536-entry table and no block mask. Each table costs 3 A rows and 4 H rows, about 14.3 KB of receipt, and adds no opening group.
- **Lookups:** 61,440 U8, 2,048 exp and 512 act. The softmax domain takes 26,624 of the U8 lookups and grows as H·T².
- **Receipt:** recomputed 136 + 14,672 + 243,712 + 1,327,104 + 968,704 + 262,144 = 2,816,472. That equals the size the block lane's implementation disposition records from its own run. I used the attention module's byte model; the block's `wire.rs` was not read.
- **Marginal costs:**

| Unit | Bytes |
|---|---|
| Per committed row | 2,048 |
| Per opening group | 8,192 |
| Per M row | 2,048 |

### Critical acceptance tests

1. **Present on the lane, keep them green:**
   - `block_output_cannot_be_chosen`;
   - kernel parity on 1,200 cases with identical refusal sites;
   - the `u16 = 0` pair-lookup tamper;
   - the norm_m tampers;
   - the shared-pair negative controls;
   - the `compile_fail` ownership test.
2. **New at integration:**
   - A receipt produced on the lane must verify under the main-tree build, with an equal `schedule_digest`.
   - The attention profile must be unchanged: 2,245,800 bytes and its tests passing.
   - The V-1 draw-order pin.
3. **Owed:**
   - A direct multiplicity-plane tamper, which needs a test-only hook.
   - A schema-3 capture writer, then the joint-view tools run on real block receipts. That evidence goes under `results/`, never `/tmp`.

### A warning for chaining blocks

Do not use one endpoint commitment as block k's output and block k+1's input. That would be two openings of one commitment, which D11 rules out. Chaining needs a proved equality inside one transcript or a multi-block proof. It is unbuilt and its joint analysis is unowned.

## 3. Open proof obligations (unchanged)

- D8 and D11 for both external endpoints, with prior authentication and hash history in scope.
- A whole-proof simulator and the captured-receipt joint-view gate.
- Joint effects across A, H and M, and across multiple sites on one plane, beyond the linear model.
- The sampled columns, salted paths and transcript conditioning.
- D9, the `fp()` reduction bias.
- Completeness (tested, not proved) and the no-wrap bounds (not mechanised).
- Witness refusals that depend on the private input.

## 4. What this means for the five-second goal

The block lane's implementation disposition records about 0.1 s at T32/d16, a diagnostic figure that says nothing about 8B. Form S gives up the block-decomposed GPU feed-forward prover. The equality form between two prover-owned commitments is deferred, with its cost written down in the lane's construction memo §B.2–B.3.

Two quiesced measurements at the 125M rung (768 → 2048) would force that equality form:
1. Peak resident bytes.
2. Feed-forward wall-clock, host-only against GPU.

Codex's current timings count as diagnostic unless the box is quiesced.

The Gmail, Google Calendar and Google Drive connectors need authorizing in claude.ai connector settings before they can be used; this review did not need them.
