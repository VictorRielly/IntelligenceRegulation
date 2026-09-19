# Disposition of the private block construction — security owner, 2026-09-19

Written by the interactive Claude Fable 5.1 session (the security owner) at
03:00 on 2026-09-19. It rules on four delegated documents on this lane:

| Short name | Document | What it is |
|---|---|---|
| T1 | `ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` | the construction memo: seam form, the second norm (`norm_m`), residual 2, the joint transcript order, the role list, scale binding, tool criteria |
| T1-check | `ZK60_PRIVATE_BLOCK_CONSTRUCTION_CHECK.md` | independent adversarial check of T1, with the rank and slot tools run on a paper Tier-1 schedule |
| T2 | `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2.md` | the feed-forward half, designed in the attention module's own idiom |
| T2-check | `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md` | independent adversarial check of T2, the tools run on the whole-block paper schedule, and one consolidated list of 22 errata (E-1 … E-22) |

| Verdict | **Accepted as the design to build**, with the 22 errata binding and the conditions of §3. It is a design for a complete private transformer block at the tiny geometry (T32 tokens, width 16) on the custom line, inside ruling D12. **It is not a privacy acceptance, establishes no privacy property, and carries no speed claim** (§5). |
|---|---|

## 1. What is accepted

1. **The seam form: none.** The native attention construction grows into the
   whole block (T1's form S). The second norm's output `nm` is one plane read
   by two relations; every hidden intermediate (`xres1`, `nm`, the
   feed-forward planes, `z16`) lives on the one proof's own commitments; there
   is one transcript, one `M`, and each commitment is opened once. D12 is met
   with no new privacy machinery. The equality-seam form (T1 §B.2) is
   **deferred, not rejected**: it is the only form that keeps the
   block-decomposed GPU feed-forward prover and is what 8B will probably need.
   The two measurements that would force it are recorded in T1 §B.3 (peak
   resident bytes of one commitment against two; host against GPU
   feed-forward time, both at the 125M rung on a quiesced box).
2. **The grown layout**, Tier 1 and Tier 2 together, as the two checks
   confirmed it: `A` 455 rows, `H` 384 rows, 120 and 51 claim sites, 23 slots,
   six host groups, 50 `M` rows, 34 functionals, opening groups `A` 35 and
   `H` 9, largest slot length 50, 61,440 byte lookups, receipt 2,816,472 bytes.
   Every count was re-derived independently from the source and reproduced by
   the committed tools driven from a paper schedule.
3. **T1's decisions 1–4, 6–12, 14** and **T2's decisions 1–14**, as corrected by
   the errata. In particular: `norm_m` and residual 2 live beside `norm_a`
   and residual 1; the output endpoint carries `xres2`; `SC_TZC` hosts both
   sum-of-squares slots (one zero-check hosting two slots already has three
   precedents in the accepted layout); the activation lookup binds the
   **pair** `(g8 + 128, a16)` under a new table tag 134 as a third triple of
   `SC_TAB`. By E-22 the pair form is a soundness requirement, not a
   preference: wherever the up matmul is zero the product relation pins
   nothing about `a16`, and the pair lookup is the only other relation it
   appears in.
4. **T1's decision 13**: for the tiny block the feed-forward is re-derived on
   the host and does not inherit the GPU prover. The tiny block is a
   correctness and privacy milestone, not a throughput one.

## 2. Two rulings of my own that change the drafts

**R-A. The block is a new module; the accepted attention component is not
edited.** T1 §B.1 proposes growing `hashline/src/private_attention/*` in
place. Instead: the block is built as `hashline/src/private_block.rs` and
`hashline/src/private_block/`, grown from a copy of the attention module, with
its own example and tests. Reasons, in order of weight: the accepted
component's receipt, tests and R-1/R-2 records stay valid byte for byte; E-13's
problem (the slot labels are hard-coded in code the two profiles would share,
so renaming them forks the shared path or silently changes the accepted
component's transcript) disappears; there is never a "Tier-1 build" of an
accepted artifact for E-1 to guard against; and Codex, who is integrating the
attention component in the main tree now, gets no file collisions. The price
is duplicated code, which is acceptable for a proof of concept and is
revisited when the block itself is accepted (fold the attention component
into a configuration of the block module, or keep both). The inventory tool
must take the module path as a parameter; the checks' drivers already do this
by rebinding.

**R-B. T1's decision 5 is accepted in part.** The new profile string
`hashline-zk-mr1/private-block-t32-poc/1` and the new `"parameters"` payload
are accepted: they are absorbed before any challenge and, with the schedule
digest, are what separates this statement's Fiat–Shamir domain from the
attention component's. The renaming of the per-slot labels to `pb-*` is
**not required** and is left to the implementer now that R-A removes the
shared code path; it adds no separation the profile string does not already
give.

## 3. Conditions (binding on the implementation)

1. **E-1.** Nothing carries the block profile string, `BlockPublic` or an
   output endpoint on `xres2` unless the feed-forward relations of T2 are in
   the same commit. The verifier-side tripwire `block_output_cannot_be_chosen`
   (tamper `z16` consistently, keep `xres2 = xres1 + z16` and every class proof
   satisfied, require the **verifier** to reject) is written first and ships in
   that commit, together with the assertion that the honest proof verifies.
2. **E-2.** `BlockPublic::new` refuses an activation table with any value
   outside `[-32768, 32767]` (or holds it as `[i16; 256]`), exactly as the
   accepted module refuses a malformed exp table
   (`hashline/src/private_attention.rs:97-99`; I re-read that line myself).
   Without it `a16`'s class is a caller's promise, the product relation can
   wrap the field, and the chain from `nm` to `z16` breaks at the very relation
   Tier 2 exists to supply.
3. **E-3 … E-22 are applied to T1 and T2** before anyone builds from them, so
   the implementer reads corrected text. E-17 (a plane constant used where a
   table index is meant) and E-19 (four tamper tests that do not isolate the
   relation they name) matter to code and tests, not only to prose.
4. **The tools are re-run on the real Rust**, not on the paper schedule, before
   the module is called a block: the inventory tool re-derives every count of
   §1.2 from the source, `NOTE_EXPECT` is updated, every group and both
   endpoints disclose 0, `H`'s residual is exactly the public identity, every
   host group has kernel 3 and leaks 0, every slot satisfies
   `L + 256 ≤ 512`, and all 18 negative controls fire, plus the two owed ones
   (`A_H16` sharing `A_U16`'s pair; `A_YM` sharing `A_Y`'s pair). A control
   that stops firing is a stop.
5. **Endpoint scales** are pinned to the calibration's `(e_r, e_r2) = (0, 0)`
   by a constructor refusal and the calibration digest is absorbed (T1 decision
   9, D12 item 5). The attention fixtures' `(-3, -3)` is Codex's fix on the
   integrated component and is not touched from this lane.
6. **Kernel parity**: the block witness equals
   `private-block-kernel::run_block` on the public synthetic fixture element
   for element, including the refusal site and string when the kernel refuses.

## 4. What I reviewed myself, and what was delegated

Honest accounting, because the four documents total about 4,600 lines and
were written and checked by delegated Opus agents to save the security
owner's usage, at Victor's instruction.

- **Read by me:** T1 §B (the seam form), §C.2 (residual 2), §C.5, §H.3 (its
  decisions); T2's relations and range-proof technique; T2-check §1 (its
  blocking finding) and its complete errata table; the tools' Tier-1 summary
  file. **Re-verified by me in the source:** the FFN proves no range on its
  input (`layer.rs` lookup list); the fixtures' `(-3, -3)` against
  `causal_oracle.rs`; the two existing components' output endpoints bind
  `xres1` and `z16` (`private_attention/argument.rs:757`,
  `zk_ffn_fresh_io.rs:284`); the exp table's public range check
  (`private_attention.rs:97-99`). **Reasoned by me:** that table membership of
  the pair under a combination drawn after commitment forces both classes;
  that a byte lookup plus a lookup of the value scaled by `2^(8−s)` gives an
  exact `s`-bit range without wraparound; that a Tier-1-only artifact is
  vacuous on its output (found before the check confirmed it).
- **Delegated and not re-done by me:** the plane-by-plane mirror of `norm_a`,
  every count's arithmetic, the label-by-label transcript order against
  `protocol.rs`, the tag-namespace search, the no-wraparound table, the seven
  attempted output tampers, and the tool runs. Each was done by one agent and
  checked by a different one instructed to assume nothing was right; the
  second agent reproduced the first's tool outputs byte for byte before
  extending them.

## 5. What this does not establish

- **No privacy property.** The tools' verdicts concern a paper description,
  and their models exclude what they excluded on the accepted layout: the
  sampled columns, the salted Merkle paths, the CFS channel, transcript
  conditioning, and correlation between `A` and `H`. The construction's own
  gate — a zero-witness preimage with the same free dimension as the real
  witness on every channel, on captured real receipts — is unmet.
- **D8 and D11 stay open** for the block's two external endpoints, `x_in` and
  `xres2`. Removing the seams removes the reuse of intermediates; it does
  nothing for the caller-fixed-root obligation at the block's boundary. D9
  stays pending.
- **No completeness claim** was checked (that an honest witness always
  exists within the ranges), and the full monomial expansion of the grown
  `SC_DZC`, `SC_LZC` at degree 4 and the new `SC_FZC` was not enumerated.
- **No speed claim.** A 2.8 MB receipt at T32 says nothing about 8B, and the
  form chosen here deliberately gives up the GPU feed-forward prover.

## 6. Next steps

1. Apply E-3 … E-22 to T1 and T2 and mark both "accepted as the design to
   build, per this disposition" (delegated; this lane).
2. Implementation on a new lane from this one, new files only (R-A), in the
   order: the tripwire and parity tests first; layout and witness; the
   argument's new arms; then the tools on the real source (condition 4).
   Builds take the shared build lock; nothing heavy runs outside the queue.
3. The schema-3 capture writer for the block profile follows the attention
   one Codex is writing, so the round-2 joint-view tools can run on real block
   receipts. That, not this document, is where a privacy statement starts.
