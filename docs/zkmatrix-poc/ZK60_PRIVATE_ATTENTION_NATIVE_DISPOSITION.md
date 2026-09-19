# Disposition of the native private attention delivery — security owner, 2026-09-18

| | |
|---|---|
| Delivery | `hashline/src/private_attention{.rs,/}`, tests, example and note `ZK60_PRIVATE_ATTENTION_NATIVE.md` from the delegated Fable lane (`/tmp/wt-zk60-attention-fable-20260918`), copied unchanged onto lane `zk60-attention-compile` at `db021ba` |
| Reviews | compile pass (`results/zk60_private_attention_native_evidence/compile/`), R-1 rank and CFS on the declared layout (`…/rank_cfs/`, `scripts/zk60_attention_native_inventory.py`, 39 tests), R-2 arithmetic (`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md`, `…/r2_review/`) |
| Verdict | **Accepted as the custom line's experimental private attention component at the tiny geometry.** The deviations from the construction are accepted (§2). It is not a complete block, not a privacy acceptance, and carries no speed claim (§4). |

## 1. What is established

- **It builds and works as delivered.** `cargo check` clean on the first invocation with zero source changes; 11 unit tests (honest receipt, 17 witness tampers, 19 receipt tampers, refusals, schedule audit, wire), 4 integration tests and the `compile_fail` doc test pass; the example proves the attention half of a T32/d16/f16 block in 0.09 s into a 2,245,800-byte receipt (exactly the note's hand count) and a fresh process verifies it in 0.04 s while refusing three corruptions. The hand-counted `A_GROUPS = 30` and `H_GROUPS = 8` are right: the prover and verifier recompute the PCS grouping and would refuse otherwise, and the R-1 tool re-derives both from `argument.rs::define` and the PCS key rule.
- **The schedule discipline holds on the layout it actually declares (R-1).** Whole A disclosed dimension 0 per column and with values; 0 on each of the 30 A groups and 6 H evaluation groups; 0 on each endpoint commitment; whole H with values discloses exactly the public LogUp identity (rank F = rank I = rank(F ∪ I) = 2). All eleven negative controls fire, including the flipped-point RoPE claim sharing a pair (2 vs 0), a single proximity row (1 vs 0), the zero-sum row without its fresh pair (8) and published helper sums (70). All 18 CFS slots pass FA6's criterion standalone; all five host groups have rank = ΣL − (k+1) and kernel k+1; 40-row M, 28 functionals with no standalone total on any hosted or host slot; largest L = 50.
- **The arithmetic holds (R-2).** Every constrained integer expression, bounded over the enforced ranges rather than honest values, stays below 2^49 (the tightest, `p·Sum + ρ < 2^25`, by 0.05%); all ten byte-limb decompositions are exact; `a1 ≥ 0 ∧ a2 ≥ 0` pins `D = isqrt(ss)` uniquely; the softmax constraints pin `max, E, Sum, p, ρ, σ` exactly including ties and force `p = ρ = 0` off the causal support; all 18 slot polynomials, expanded exactly, have a public factor in every monomial or, for score and PV, a second extension variable, so the mask branch vanishes. Eight cosmetic flags, none affecting soundness or privacy (`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md`).

## 2. Deviations from the construction, and their disposition

| Deviation | Disposition |
|---|---|
| One U8 table with byte limbs instead of the Int16/U16/Prob/Srem/Win set; hence no block masks; A 306 rows, H 290 (construction: 1,487 / 2,490) | **Accepted.** This is the lever the construction recorded in §6; R-1 shows the pair-only schedule discloses nothing and R-2 shows every limb decomposition is exact. The cost moves from rows to lookups (47,104 U8 + 2,048 exp) |
| Softmax zero-check degree 4, not 5 (the exp lookup has its own helper, so no helper relation multiplies two lookups with the causal mask) | **Accepted.** R-2 expands the polynomial: degree 4, public factor in every monomial |
| No W commitment under P1; a digest of the exact weight words is bound into the transcript and the verifier folds the public weights itself | **Accepted for P1** (weights are public by D1). P3 is not implemented and the construction's P3 rows do not apply to this component |
| Module-local row numbering; 75 A sites and 35 H sites instead of the JSON's 135-claim inventory | **Accepted.** The rank check was regenerated from the module's own definitions, which is what R-1 required |
| Extra refusals: batching challenge ν = 0 and extension challenge e = 1 | **Accepted.** Functions of challenges only, never resampled; they close the two degeneracies the CFS controls exhibit |
| Selector pinned to an attainer of the row maximum, not the kernel's first attainer | **Accepted.** No committed value depends on the choice (R-2 §2, checked over 20,000 rows); recorded in `layout.rs` |

## 3. What Codex integrates, and the small follow-ups

1. Integrate the lane (`zk60-attention-compile`) as the experimental profile `hashline-zk-mr1/private-attention-t32-poc/1`; no existing profile, proof bytes or security parameter changes. The delivery's interface requests P-1 (share `check_opening_challenges`), P-2 (a neutral alias for `into_ffn_endpoint`) and P-3 (a kernel-parity dev-dependency) are Codex's calls; none is needed to build.
2. Cosmetic follow-ups, in one small commit: R-2 flags F1 (state that `Sum ≤ 2^14` is enforced by the row-sum host and the table, not locally), F2 (record that `p < 2^10` must not be tightened, since `p = 512` is attained), F7 (one comment line on `A_MX`'s lookup-only bound); the compile agent's two notes (split the tamper test so the verifier-side refusal is asserted separately; name the `h_dom` arms).
3. A schema-3 capture writer for this profile, so the round-2 joint PCS/CFS tools and the transcript replay run on its real receipts; that is the acceptance gate per channel the construction names, and it has not been run on a captured receipt yet.

## 4. What this does not establish

- Not a block: `norm_m`, the two FFN seams and residual 2 are the composition work (the construction's A3/A4, the plan's A07). The component's output endpoint is `xres1`, which does not chain to the repaired FFN's input without the second norm.
- Not whole-proof privacy: no captured-receipt joint view, no simulator, D8/D11 open; sampled columns, salted paths, transcript conditioning and A↔H correlation are outside both linear models. D9 applies.
- No speed claim: the tiny geometry proves in a tenth of a second on a loaded laptop and says nothing about 8B; the construction's row-cost lever now has a measured shape (306/290 rows) at this geometry only.
