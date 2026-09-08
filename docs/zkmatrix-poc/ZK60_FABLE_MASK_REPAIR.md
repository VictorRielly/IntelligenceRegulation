# ZK60 FA3 — the repaired mask contract for the FFN A/H/W commitments and the pending private block

**Reviewer:** Claude Fable 5.1, independent reviewer, 2026-09-07 session.
**Role:** independent design review and repair specification (task FA3 of
`ZK60_FABLE_QUEUE.md`). Not the implementer: Codex implements the accepted
protocol from the schema in section 12 and the machine-readable mirror
`results/zk60_fable_fa3_mask_schedule.json`. No production source file is
changed by this review; the only code touched is the FA2 rank tool
(`scripts/zk60_fable_joint_rank.py`, `tests/test_zk60_fable_joint_rank.py`),
extended to evaluate the repaired allocation.
**Builds on:** FA1 and FA2 (`ZK60_FABLE_PRIVACY_REVIEW.md`, Parts 1 and 2), FA4
(`ZK60_FABLE_MODEL_IDENTITY.md`), FA5 (`ZK60_FABLE_SECURITY_OBLIGATIONS.md`),
A03 (`ZK60_PENDING_FFN.md`), A1 (`ZK60_PRIVATE_BLOCK.md`), S2
(`ZK60_PRIVATE_SEAM.md`), A01 (`ZK60_ATTENTION_SCHEDULE.md`), R2
(`ZK60_RESEARCH_DECISIONS.md`), Codex's round-10 record (`ZK60_ROUND10.md`).

**Status: design and review delivered.** Production composition remains gated on
acceptance of this plan; nothing here certifies a construction in advance
(section 14).

## 0. Source pin

| Item | Value |
|---|---|
| Worktree / branch | `/home/victor/wt-zk60-fa`, `zk60-fable-review` |
| HEAD | `daed46f` = baseline `52a13d1` + FA1 + FA5 + FA4 + FA2 |
| `hashline/src/zk.rs` SHA-256 | `50d37b51…259f8a19` — byte-identical to FA1's pin (§1 of Part 1) |
| `hashline/src/pcs.rs` SHA-256 | `60ac5f2f…77960ab1b` — byte-identical to FA1's pin |
| `hashline/src/private_seam.rs` SHA-256 | `ae539c9cb7799d67e60d05e98377e64b701eae20e569df4f42f7f4fa0edcb435` |
| `hashline/src/private_block_contract.rs` SHA-256 | `cba18955d162d6e5acf1302681e0a214d5bbeab27a8231a18401244532fdcb72` |
| Executed | `python3 -m unittest discover -s tests -p 'test_zk60_fable_joint_rank.py' -v`: **34 tests, OK** (FA2's 22 unchanged + 12 new); `python3 scripts/zk60_fable_joint_rank.py repair -o results/zk60_fable_fa3_mask_schedule.json`: **exit 0, 0 failures** (36 shape checks + 24 per-family models) |
| Regression of FA2's evidence | `fixtures` and `impact` re-run under the edited tool are byte-identical to the committed `results/zk60_fable_fa2_rank_cases.json` / `_impact.json` |
| Not executed | no Rust build, no Rust test, no proof, no GPU; the repaired profile does not exist in source at this pin |

Evidence classes: **[EXECUTED]** = the rank tool on this session's models (stand-in
coefficients, source structure); **[DERIVED]** = read from the pinned source;
**[COUNTED]** = row/byte accounting from `ZkLayoutV3::new` mirrored in the tool and
checked against the pinned counts (5173 / 681 / 1325 / 7 / 10774); **[BLOCKER]** = not
settled by anything in this document.

## 1. The one-paragraph answer

FA2 showed that every leak in the linear model has one cause: a mask whose
per-column contribution is a *line* in Fp2 (one base row, coefficient λc) where the
observation is a *plane* (an Fp2 value). The repair is therefore one rule applied
everywhere, not a patch per site: **every single-row mask site becomes an Fp2 pair
(re, im) carried in the claim as (k1, k1·u); every multi-row base mask block (a
table slot spanning ≥ 2 rows) keeps its block form, which is Fp2-effective through
its row weights; every proximity row becomes a pair; the two internal seams are
pair-masked claims on the actual A commitment's X and z rows at their own sumcheck
points; and every mask row is drawn exactly once, before its commitment exists, and
consumed by exactly one opening.** Under that rule the rank tool reports
`disclosed_dim = 0` on every FA2 group shape — the singletons (X@p2, h16@p5, Wd@p6),
the "individually public terminal values" channel of every multi-member group (rank
2m + 2n − 2 instead of 2m + 2n − 4), the starved tiny P3 W proximity row, the
function-2 pair, the tables at log_n = 16, and the whole tiny A/H/W commitments with
X and h16 re-opened under three different masks each — and the LogUp residual stays
exactly the public identity (section 9). Two negative controls carry the two rules a
reader might be tempted to skip: a seam-only pair appended to the legacy A leaves
FA2's 2n + 4 leak untouched, and a single proximity row beside one pair-masked claim
leaks one functional per column (the prox pair is required). What the rule does
**not** settle is recorded as five blockers (section 11): the CFS channel (nonlinear),
transcript conditioning (a simulator), integer ranges and cross-proof correlation
beyond the linear model (including FA4's k-slot reuse), and the still-missing H/P3-W
capture. The cost is 2·(number of single-row claims) + 1 + (single-row table slots)
+ 4·nb_d extra rows on A and 1 on H per proof (section 8, block profile: +21 rows at
the A00 tiny shape, +70 at 8B), and one pair per W block claim per FA4 slot. The block API of
section 12 consumes both seams exactly once through a type-state lifecycle that has
no append and no clone.

## 2. The construction: mask schedule per commitment

### 2.1 The four mask kinds

| Kind | Rows | Claim form (`ZClaim.parts`) | Why it is a one-time pad per column | Degeneracy (refused, section 6) |
|---|---|---|---|---|
| **pair** | 2 (re, im) | `[ (DATA slice, k0, p), (row R_re, k1, tail p), (row R_im, k1·u, tail p) ]`; masked terminal `(1 − e)·fin + e·(R_re~ + u·R_im~)` via `MaskPoint::eval2` (the H form, `zk.rs` 1017, and S2's `terminal_claim`, `private_seam.rs` 289–317) | per column the mask contributes λk1·(R_re + u·R_im), a bijection Fp² → Fp2 whenever λk1 ≠ 0; the FA1 degeneracy "e ∈ Fp" disappears (FA3 test `test_pairmask_pair_is_a_one_time_pad_for_the_p3_coefficient_pair`) | λ = 0 or k1 = 0 (e = 0; under P3 also e2 = 1): ≈ 2^−128 |
| **block** | rows_i = max(size_i, n)/n ≥ 2 | unchanged legacy form: `[ (slot rows, (1 − e_tab)·ext_i, rho_tab[k_i..]), (mask rows, e_tab·ext_i, rho_tab[k_i..]) ]` | per column λ·e_tab·ext_i·Σ_r eq_r R[r] with eq from the row-bit coordinates; Fp2-effective when two eq_r are Fp-independent (FA2 §14.3) | a row-bit coordinate of rho_tab[k_i..] in Fp: ≈ 2^−64 per slot |
| **zero_sum_pair** | 2 | unchanged `h_u` (Σ_j u_re[j] = Σ_j u_im[j] = 0) masked at rho_zs by the fresh unconstrained pair `h_up` | FA2 §14.5, re-verified with the prox pair: the surviving space is exactly the public LogUp identity (section 9, `h_logup_sum_zero_sum_u_prox_pair_n4/n8`) | as pair |
| **prox_pair** | 2 | no claim: the two rows enter only the proximity combination with the two independent challenges ρ[row_re], ρ[row_im] drawn by `zk_rhos` | per column Fp-span{ρ_re, ρ_im} = Fp2 unless the two are Fp-dependent; coverage no longer borrowed from other groups (FA2 §14.4, U4) | ρ_re, ρ_im Fp-dependent: ≈ 2^−64 |

The uniform alternative — every table mask block also an Fp2 pair block (2·rows_i
rows) — is also full rank (`whole_A_n4_alternative_all_pair_table_blocks`) and removes
the block kind's 2^−64 row-bit degeneracy; it costs Σ rows_i extra rows per
commitment (+2,579 at the T2 diagnostic shape, +324 at A00's T32, +14 at 125M, +9 at
8B). It is documented, not proposed first (simplest-first); the measurement that
would justify it is a captured coefficient set in which a row-bit coordinate lands in
Fp, which no run has produced.

### 2.2 The schedule table (every commitment, every opening the block makes)

m = members of the column-weight group; "rows" = data rows per member; "today" and
"proposed" = mask rows per member. Verdict names refer to section 9 /
`results/zk60_fable_fa3_mask_schedule.json`.

| Commitment / role | Group key | m | rows | today | proposed | Value in proof | Rank argument (linear model) or blocker |
|---|---|---|---|---|---|---|---|
| A `a_mf[k]` (g8,rg,a16,u16,ru,h16,rh per f-block at rho_f) | tail(rho_f) | 7·nb_f | rows_f | 1 base | **pair** | `zc20_term[10b+i]`, i < 7 | all-pair group: rank 2m + 2n − 2, disclosed 0 (`group_values_all_pairmask_m7_n4/n8`; legacy 2) |
| A `a_md[k]` (X, z, rd per d-block at rho_d) | tail(rho_d) | 3·nb_d | rows_d | 1 base | **pair** | `zc17_term[c]`, `[nb_d+c]`, `[2nb_d+c]` | same (`…_m3_n4`, `…_m9_n4`; legacy 2) |
| A `a_mgu[c]` (X block c at p2 = r_i‖r_kp; the SAME rows as `a_md[3c]`) | tail(p2) | nb_d | rows_d | 1 base | **pair** | `gu_term[c]` | singleton → pair: disclosed 0 (`…_m1_n4`; legacy n); jointly with rho_d and sx: `whole_A_n4_*` |
| A `a_mdd[b]` (h16 block b at p5 = r_ip‖r_k; the SAME rows as `a_mf[7b+5]`) | tail(p5) | nb_f | rows_f | 1 base | **pair** | `d_term[b]` | as above |
| A `a_prox` | (proximity vector) | — | — | 1 base | **prox_pair** | `a_open.prox_vec` | `one_pairmask_claim_prox_pair` (0) vs `negative_control_one_pairmask_claim_single_prox_row` (1) |
| A `tab[i].a_mask` (six multiplicity slots) | tail(rho_tab) | 6 | rows_i | block (rows_i) | **block if rows_i ≥ 2, else pair** | `tab_term[2i]` | §14.3 for blocks; `tables_at_log_n_16_all_single_row_slots` (0; legacy 2) for the all-single-row case (U10) |
| A `a_pmz`, `a_pmb` (function 2: the z block of the frozen entry; the bit row) | tail(rho_p) | 2 | rows_d, 1 | 1 base each | **pair** each | `pred.term[0]`, `[1]` | `whole_A_n4_function2_predicate_pairs` (0; legacy 14 = 12 + 2) (U9) |
| A `a_sx[c]` **new, block profile** (X block c at rho_sx; the SAME rows as `a_md[3c]` / `a_mgu[c]`) | tail(rho_sx) | nb_d | rows_d | — | **pair** | `seam_x.term_ffn[c]` | `whole_A_n4_*_seams` (0): X under three pairs at three tails |
| A `a_sz[c]` **new, block profile** (z block c at rho_sz; the SAME rows as `a_md[3c+1]`) | tail(rho_sz) | nb_d | rows_d | — | **pair** | `seam_z.term_ffn[c]` | same |
| H `h_mf[k]`, `h_md[c]` (Fp2 helper planes) | tail(rho_f) / tail(rho_d) | 3nb_f / nb_d | rows | pair | pair (unchanged) | `zc20_term[10b+7+i]`, `zc17_term[3nb_d+c]` | §14.3 (`whole_H_n4_*`, 0) |
| H `h_u` + `h_up` | rho_zs; and the value-0 sum claim (empty point) | 1 | 1 | zero-sum pair + pair | unchanged | `zs_term`; the constant 0 | §14.5 re-verified with the prox pair: residual = the public identity |
| H `h_prox` | (proximity vector) | — | — | 1 base | **prox_pair** | `h_open.prox_vec` | `whole_H_n4_*` (0) |
| H `tab[i].h_mre/h_mim` | tail(rho_tab) | 6 | rows_i | pair block | unchanged | `tab_term[2i+1]` | §14.3 |
| W(P3) `w_mgu[k]` (Wg, Wu blocks at p3 = r_kp‖r_j) | tail(p3) | 2·nb_d·nb_f | rows_w | 1 base | **pair** (per FA4 slot) | `gu_term[nb_d+k]` | `whole_W_p3_n4_nb1` (0; legacy 10), `…_nbd3` (0; legacy 4) |
| W(P3) `w_mdd[k]` (Wd blocks at p6 = r_k‖r_jp) | tail(p6) | nb_d·nb_f | rows_w | 1 base | **pair** (per slot) | `d_term[nb_f+k]` | same; the Wd singleton (FA1 item 5, FA2 U11) gone |
| W(P3) `w_prox` | (proximity vector) | — | — | 1 base | **prox_pair** (per slot) | `w_open_zk.prox_vec` | the tiny-W starvation (FA2 §14.4: 4 masks vs 6 dims) becomes 8 vs 6 |
| W(P1) | plain public opening | — | — | none | none (public weights; approved root, FA4 §2) | `w_open` | no privacy claim |
| M (CFS mask commitment) | product-form linear test | 6 (+1 pred) (+2 seams) slots | — | CFS masks | + `SC_SEAM_X`, `SC_SEAM_Z` slots (block profile) | `mask_open` | **BLOCKER B1** (section 11): outside the linear model; the schedule fixes only slot count and order |
| pads / sampled columns (A, H, W, M) | — | — | — | Q pads per row | unchanged; P3 W: q_pad = k·Q (FA4 §5.1) | `columns` | FA2 §14.6 argument (single proof); across FA4's k proofs **BLOCKER B4** |
| cross-terminal checks | — | — | — | — | — | — | identities in counted values (FA2 §14.7); no observation |

Every role in the table is a *reserved* role: it has a fixed row index in the layout
of the repaired profile (section 12's schema), it is filled once (section 3), and the
verifier builds the corresponding claim from the layout, never from the proof
(section 6).

### 2.3 Permitted point transforms and group formation

1. A single-row mask part's point is the **tail** (last log_n coordinates) of its
   data part's point — the legacy rule (`build_claims_zk_v3`, `tail`), unchanged; both
   rows of a pair use the same tail, so `group_zclaims` puts all three parts under one
   `ZKey` (it asserts this).
2. A data slice spanning 2^(ls − log_n) rows keeps its row bits `p[..ls − log_n]` as
   eq row weights on the data rows; the pair sits on one row each. The mask does not
   need row bits: its two rows are what make it Fp2-effective, not the row weights.
3. Table slots: point `rho_tab[k_i..]`, both coefficients multiplied by
   `ext_coef(rho_tab, k_i)`; unchanged. A single-row slot's pair uses the same point
   and the same ext factor on both rows (with ·u on im).
4. Seams: `rho_sx` / `rho_sz` are the seam sumchecks' own challenge vectors
   (log_t + log_db coordinates, drawn after both A roots and both M roots are absorbed);
   the FFN-side claim is at `lay.x[c]` / `lay.z[c]` with `(1 − e_sx, e_sx)`; the
   attention-side claim is the mirror on its own commitment with its own reserved
   pair. The equality relation is S2's (`F(x, e) = (1 − e)·eq(τ, x)·[(1 − e)(A − B) +
   e(R_A − R_B)]`, batched over the nb_d blocks with λ_c), so no clear comparison of
   two independently masked values ever happens (A1's warning).
5. The only empty-point claim is H's value-0 LogUp sum; A and W have none.
6. No claim may be attached at a point that is not a challenge of the block transcript
   drawn after the target commitment's root was absorbed; no coordinate flip or
   negation is used by the FFN (when the attention side adopts this contract, a
   flipped-point claim is a separate group with its own reserved pair — A1's RoPE row).
7. Group formation stays first-occurrence by `ZKey`; the expected group count per
   commitment is a function of the layout (A: 5 standalone, 7 block profile, +1 with
   the predicate; H: 5; W(P3): 2) and the verifier checks it (section 6).

### 2.4 Proximity and helper constraints

- The proximity combination of every commitment draws one fresh ρ per row
  (`zk_rhos`), pairs included; the prox pair's two ρ's are what cover it. The
  `assert_mask_sites` check (`pcs.rs` 864–884) must be extended to assert that the
  prox ρ touches **both** prox rows and that every group vector touches **both** rows
  of at least one pair (a nonzero-support check is still not a rank argument; the rank
  argument is section 9).
- H's helper planes are Fp2-valued and already pair-masked; the LogUp sum claim's mask
  is the zero-sum pair; `h_up` stays fresh and unconstrained (U5).
- The CFS mask commitment gains the two seam slots in the block profile; its
  proximity/blinding rows (b, u) are unchanged. No CFS mask is shared between the
  attention and FFN components or between attempts (section 3).

## 3. Randomness: domain separation and consumption order

**Instances.** One `ZkRng` per component per block attempt: the FFN component's
instance is keyed from OS entropy (`ZkRng::from_os`, `zk.rs` 367–379) under the domain
`ffn-mr1/layer-{l}/attempt-{nonce}`; the attention component has its own instance
under `attn-mr1/layer-{l}/attempt-{nonce}`; the enclosing block draws the attempt
nonce once from OS entropy. The keyed-blake3 construction makes the domain a
separator, not a secret: two instances never share a stream. A seeded instance
(`ZkRng::new`, "legacy deterministic stream for public test fixtures ONLY") exists
only under `cfg(test)` fixtures of the repaired profile and is not reachable from
the block API (section 12), which takes no seed. A03's "no deterministic seed
option" for S2 becomes the rule for the whole block.

**Consumption order (FFN component, repaired profile).** Every draw is listed; an
implementation that draws in a different order changes seeded fixture bytes, so
the order is part of the profile version.

1. **A mask rows**, in the allocation order of section 2.2: `a_mf` pairs (k
   ascending; re then im), `a_md` pairs, `a_mgu` pairs, `a_mdd` pairs, `a_prox`
   pair, the six table slot masks in slot order (a block's rows in row order; a pair
   re then im), the predicate pairs (function 2), `a_sx` pairs, `a_sz` pairs (block
   profile). Each row is one `fp_vec(n)`.
2. **A pads** (rows × Q) then **A salts** (nn), inside `commit_zk_owned` — unchanged.
3. **M**: for each CFS slot in order (`SC_GU, SC_D, SC_ZC20, SC_ZC17, SC_ZSUM, SC_TAB,
   [SC_PRED], [SC_SEAM_X, SC_SEAM_Z]`) `CfsMask::random`, then MASK_Q pads for its re
   row and its im row; then `b_re, b_im, u_re, u_im`; then the 4096 salts — the
   order of `mask_commit` (`zk.rs` 523–561), unchanged except for the appended slots.
4. **H mask rows**: `h_mf` pairs, `h_md` pairs, `h_up` pair, `h_prox` **pair** (the
   one change: two draws where the legacy draws one), the table helper masks
   (`h_mre` rows then `h_mim` rows per slot); then the zero-sum `h_u` rows (n − 1
   draws each, last entry = −Σ) — the order of `prove_layer_zk_v3` (`zk.rs`
   2611–2622) with the prox pair inserted where `h_prox` is drawn today.
5. **H pads**, **H salts** — unchanged.
6. **P3 W**: no per-proof W randomness. The slot set was drawn at registration
   (FA4 H2) in the order `w_mgu` pairs, `w_mdd` pairs, `w_prox` pair per set, then
   k·Q pads per row, then salts; the proof consumes set `slot` and never another.

**Error and discard paths.** A `Discarded` transition (section 4) drops the RNG
instance with the secret state. A retry is a new attempt nonce and therefore a new
instance; **no mask row value, pad, salt or CFS mask is ever reused across
attempts**, whether the first attempt failed before or after its A root was absorbed
into any transcript. This is the property FA2's U7 asks for ("fresh, independent
masks per proof") extended to failed proofs. A test asserts that two attempts on the
same witness produce different A roots, different M roots and different H roots
(section 7, AM13).

## 4. Reserve-before-commit and one-shot finalization (the state machine)

A03's ownership ladder (`ApprovedBlock → PreparedFfn → PendingFfn → BoundFfn →
FinalizedFfn`) is kept and made exact on the actual arithmetic commitments. Every
transition **consumes** its input (Rust move semantics); secret state has no `Clone`,
`Debug`, serialization, or public accessor to committed data; only public handles
(roots, rows, log_cols, slice descriptors, physical scales, the manifest digest) are
`Copy`. A handle is not evidence of anything about its peer.

### 4.1 States and transitions (FFN component)

| From | Event | To | Consumes | Refuses (→ `Discarded` or a typed error before any secret exists) |
|---|---|---|---|---|
| approved contract + manifest | `reserve(manifest)` | **Reserved** | nothing secret yet | unknown role; duplicate role; a manifest without exactly nb_d X-seam and nb_d Z-seam roles (block profile); an unsupported slice/shape; P3 without an FA4 `WeightPolicy` and a taken slot; a predicate under the first block profile (A03 first scope) |
| Reserved | `prepare(witness)` | **Prepared** | Reserved, the witness planes | witness shape/range assertion failures (no partial output; the RNG instance dies with the state) |
| Prepared | `argue(transcript, block ctx)` | **Pending** | Prepared | any degenerate challenge of section 6 (e = 0, λ = 0, prox pair Fp-dependent, a block row-bit in Fp); the block context not bound; the attention peer's roots not yet absorbed |
| Pending | (block-level) `bind_internal_seams` | **Bound** | the FFN Pending **and** the attention Pending together | a seam role missing or already consumed; a peer handle whose root, rows, log_cols, slice or scale differs from the handle the block absorbed; a peer not in Pending; any seam claim whose slice is not the layout's `lay.x[c]` / `lay.z[c]` on the FFN A root (the copied-plane substitute) |
| Bound | `finalize(transcript)` | **Finalized** (proof bytes) | Bound; every `CommittedZk` and the `MaskCommit` dropped | consumed-role set ≠ manifest role set (a role never opened, or opened twice) |
| any | error / drop | **Discarded** | everything | a second use of the same object is a compile error (moved) |

What each state holds: **Reserved** — the manifest and the RNG instance;
**Prepared** — the A `CommittedZk` (with its pairs already inside), the `MaskCommit`,
the W reference (P1: the approved public commitment; P3: the FA4 stable commitment
and the taken slot), the public handles; **Pending** — plus the H `CommittedZk`, the
claims of every non-seam role (built exactly as `build_claims_zk_v3` builds them, with
the pair form) and the consumed-role set; **Bound** — plus the seam terminals and
their claims on both sides; **Finalized** — only bytes.

### 4.2 Reserve-before-commit, exactly

Reservation fixes, before any root exists: the ordered role list, each role's row
indices in A (or H / W), each role's mask kind, the CFS slot list, and the transcript
positions at which each role's terminal is absorbed. `prepare` then fills every mask
row from the RNG in the order of section 3 **and only then** calls `commit_zk_owned`
— the legacy prover already does this for its rows (`zk.rs` 2521–2528 for A,
2437–2441 for P3 W); the repair adds rows, it does not move the fill-then-commit
boundary. Late claims are refused structurally: there is no API that accepts a
`ZClaim` or a role name after `reserve` (A03: "no generic arbitrary `Vec<ZClaim>`
append API"), and the verifier reconstructs the claim schedule from the manifest and
refuses any group vector count that differs (section 6).

### 4.3 One-shot finalization, exactly

`finalize` performs, in this order and once: the FFN `mask_open` over every CFS slot
(including the seam slots); then `open_zk` on W (P3 only), A, H. Each `open_zk` is
called on an owned `CommittedZk` that is dropped immediately after (the legacy
`drop(a_cmz)` discipline); `pcs::open_zk` keeps its immutable-borrow signature, so
the one-shot guarantee lives in the owner type, as A03 specified. A second opening of
the same commitment is impossible without the dropped state; replaying already-made
bytes is not an opening (S2's distinction).

### 4.4 Repeated, missing and error-path masks

- **Repeated mask (same row in two roles):** impossible by construction — roles map
  to disjoint row ranges fixed at reservation; a test asserts disjointness over the
  whole layout (as `zk60_pending_layout.rs` does for the legacy rows).
- **Missing mask (a role never filled):** impossible by construction — `prepare`
  fills every role's rows in one loop before committing; a test asserts every mask row
  of a fresh Prepared state is non-constant (AM3).
- **Discarded / error path:** no partial object is a receipt; the RNG dies with the
  state; a retry is a new attempt (section 3). A proof whose A root was absorbed into
  a transcript that then failed is never completed — the transcript is dropped with
  the state.
- **Repeated proof of the same witness:** every mask is fresh, so the observations are
  independent uniform values in the linear model (U7); what accumulates across proofs
  is only what the nonlinear channels leak (blocker B1, B4).

### 4.5 Two simultaneously pending blocks

The enclosing **`PendingBlock`** owns `attn: AttnPending` and `ffn: FfnPending` of
the same layer and is the only type that can bind the internal seams; the FFN-only
lifecycle cannot finalize its peer (A03). Order within one block: both components
`prepare` (both A roots and both M roots exist) → the block binds its header,
context, manifest digest and all roots → each component `argue` in the fixed
transcript order of section 12 → `bind_internal_seams` runs the X seam then the Z
seam (each: τ, c, γ, masked rounds, masked terminals on both sides) → `finalize_block`
runs the FFN finalize then the attention finalize. Across blocks k and k + 1 the
residual seam x_in(k+1) = xres2(k) is between the two **attention** A commitments;
block k's attention manifest reserves the residual-seam role at its own reservation
time, so block k's attention A may not finalize before block k + 1's attention A has
bound that seam. A chain therefore holds at most the previous and the current
`AttnPending` (A03), and an `FfnPending` is never held across a block boundary. If
either component of a block is discarded, the block is discarded (both consumed); no
bytes are emitted for the surviving half (AM18).

## 5. Profile / domain / version boundary

| Item | Legacy (untouched) | Repaired |
|---|---|---|
| Profile id | `v3` (header `P1-v3` / `HL-ZK/1\|profile=v3\|…`, `zk.rs` 273–286) | **`ffn-v3-mr1`**; header `HL-ZK/2\|profile=ffn-v3-mr1\|priv=…\|pub=…\|out=…\|model=…\|layer=l\|slot=s\|block=<ctx digest>` |
| Transcript domain | the caller's (`hashline-v1/` + domain) | `hashline-v1/` + **`hashline-zk-mr1/`** + the caller's domain; the block profile additionally absorbs the approved-contract digest and the request context first (A00's `bind_public_statement` pattern) |
| Layout constructor | `ZkLayoutV3::new` (legacy row indices) | a new constructor (`ZkLayoutV3Mr1::new` or a `MaskLayout::Repaired` variant) that allocates the pairs and the seam roles **after every data row**, so data offsets are identical to the legacy layout and the legacy constructor's outputs are never reinterpreted |
| Prover / verifier entry points | `prove_layer_zk_v3` / `verify_layer_zk_v3` | new entry points behind the pending API (section 12); the legacy functions are not modified |
| Proof envelope | `LayerProofZk` concatenation | a new framed envelope with exact counts (A03 acceptance 5; S2's `to_bytes` discipline): group vector counts and lengths, prox lengths, column counts, seam sections; no legacy variant inside it |
| Frozen fixtures | the four frozen CPU artifacts and the seeded P1/P3 hashes stay byte-identical (Codex's round-10 gate) | new seeded fixtures with their own digests; the legacy fixtures are **legacy behaviour, not repaired privacy evidence** |
| Mask-site record | `assert_mask_sites` nonzero-support strings | the same strings plus "pair" / "prox pair" markers; still not a rank argument |

A legacy proof presented to the repaired verifier fails at the row-count check
(before any challenge); a repaired proof presented to the legacy verifier fails the
same way; a repaired proof whose header claims the legacy profile diverges at the
first challenge. The version is the profile id: any change to the schedule of
section 2, the RNG order of section 3, the transcript order of section 12 or the
envelope is a new profile id, never a silent change under `ffn-v3-mr1`.

## 6. Verifier obligations

A prover cannot "drop" a mask against a verifier that never lets the prover describe
the mask schedule. The obligations, in the order the verifier meets them:

1. **Header and profile before anything.** Refuse any header other than the exact
   registered `ffn-v3-mr1` header for this layer/slot/block (FA4's `ModeMismatch`
   discipline); refuse a legacy header.
2. **Layout from the statement, never from the proof.** Build the repaired layout
   from the registered statement and parameters; compute the expected row counts of
   A, H and (P3) W **including every pair and seam role**; refuse `rows` ≠ expected
   for each commitment (today's check at `zk.rs` 3509–3511, with the new counts).
   Refuse a P3 W root ≠ the manifest's `C*_l`, a slot ≥ k, and a W opening whose
   `q_pad` ≠ k·Q (FA4 §4.3).
3. **Claims from the layout, never from the proof.** Construct every `ZClaim` — data
   slice, both mask rows, both coefficients (k1, k1·u), point tail — from the layout
   and the verifier's own challenges, as `build_claims_zk_v3` does; the proof supplies
   only values. Refuse a proof whose number of group vectors differs from the layout's
   group count (`pcs.rs` 942–944), whose vectors have length ≠ n + q_pad, or whose
   prox vector is absent.
4. **Every mask row is a mask row.** Assert structurally (verifier-side, from the
   layout) that no claim's data slice overlaps a mask row and that every group's row
   weights touch both rows of at least one pair and the prox ρ touches both prox rows
   (the verifier-side twin of `assert_mask_sites`; a prover that puts data in a mask
   row only harms itself, but a layout in which a mask row could be addressed as data
   would be a schedule bug, and this check is the tripwire).
5. **Degenerate challenges are refused, never resampled.** For every pair-masked
   claim: k1 ≠ 0 (P1: e ≠ 0; P3 matmul roles: e ≠ 0 and e2 ≠ 1); for every group
   member: λ ≠ 0; for the prox pair: ρ_re and ρ_im Fp-independent
   (det(ρ_re, ρ_im) ≠ 0); for every block-kind table slot: the row-bit coordinates of
   `rho_tab[k_i..]` outside Fp. S2 already refuses e = 0 and c = 0
   (`private_seam.rs` 497–499, 507–509); the repaired verifier refuses all of the above
   with typed errors. The prover discards on the same conditions (section 4).
   Completeness loss ≈ 2^−62 per proof; no retry with the same masks.
6. **Seams.** Exactly two seam sumchecks, in order X then Z, with the CFS spec count
   equal to the layout's (8, or 9 with the predicate); exactly nb_d FFN-side and nb_d
   attention-side terminals each; the FFN-side claims on the FFN A root the verifier
   absorbed, at `lay.x[c]` / `lay.z[c]`; the attention-side claims on the attention A
   root it absorbed; the terminal relation checked with the (1 − e)·eq(τ, ρ) factor
   (S2's `want`). A seam opening against any other root — the copied-plane
   substitute — is refused at the root comparison before any Merkle work.
7. **No "verified" bits from the producer.** The block verifier verifies both
   components' arithmetic and the two seams itself; a peer handle is public metadata
   (A03).
8. **Exact counts everywhere.** Extra sumcheck rounds, extra terminals, extra group
   vectors, extra columns, non-empty unused fields: refused (FA5 R32's typed-API
   gap must not be inherited).
9. **Publish nothing on failure.** No observation, receipt or diagnostic leaves the
   verifier unless the whole block verifies (FA1 §5's `publish` gate, kept).

## 7. CPU adversarial test matrix

Shape for every row: the A00 tiny profile (T32/d16/f16, log_cols 8, inverse rate 8,
Q 256), CPU, fresh OS entropy unless the row says "seeded fixture". "Layer" says
where the refusal lives: **type** = unreachable through the API (a `cfg(test)` hook
or a hand-built proof is needed to reach the verifier), **verifier** = a typed
refusal, **prover** = a discard. Status of every row: **planned** — the repaired
profile does not exist at this pin; the row is the acceptance test Codex writes.
Mirror: `results/zk60_fable_fa3_adversarial_matrix.json`.

| Id | Case | Layer | Expected | Mechanism |
|---|---|---|---|---|
| AM1 | A packed with one mask row fewer (a pair's im row dropped) | verifier | REJECT | row count from the verifier's layout (obligation 2) |
| AM2 | one extra row appended to A | verifier | REJECT | same |
| AM3 | a mask row left all-zero ("dropped" by not randomising) | type + privacy regression | verifier ACCEPTS (soundness intact); the privacy test recovers the plane | the rank tool on the captured observation with that row declared constant; unreachable through the API (the fill loop is the only writer); regression asserts every mask row of a fresh Prepared state is non-constant |
| AM4 | one pair's values copied from another pair (mask reused across groups: `a_mgu[0]` := `a_md[0]`) | type + privacy regression | verifier ACCEPTS; the privacy test recovers X (FA2 fixture (d)) | unreachable through the API; kept as the documented hazard test under a `cfg(test)` hook |
| AM5 | mask reused across proofs (seeded fixture, two proofs) | prover obligation | verifier ACCEPTS; identical M/A roots are visible to anyone holding both proofs (FA4 M15/M16) | the block API takes no seed; under OS entropy the roots differ (positive gate) |
| AM6 | prover uses (k1, k1) instead of (k1, k1·u) on a pair | verifier | REJECT | the verifier's own claim carries (k1, k1·u); `<v, c> != combined claim` (`pcs.rs` 953) |
| AM7 | a data row and a mask row swapped in the packing | verifier | REJECT | the sumcheck terminal / LogUp relation fails on the swapped data |
| AM8 | unreserved late claim: an extra group vector in the opening | type + verifier | REJECT | no append API; "group vectors for groups" count (`pcs.rs` 942) |
| AM9 | a claim at a point that is not a transcript challenge | verifier | REJECT | the verifier builds claims only from its own challenges; the extra claim is never in its list → group count mismatch |
| AM10 | copied-plane seam substitute: S2 run on a recommitted copy of X, its roots supplied beside the block | verifier | REJECT | seam openings are checked only against the two A roots the block absorbed ("unexpected endpoint commitment"); a seam claim on any other slice is never constructed |
| AM11 | Z seam omitted (one seam only) | verifier | REJECT | CFS spec count 7 ≠ 8; seam role count; "missing Z seam" |
| AM12 | seam terminals swapped between sides | verifier | REJECT | each side's claim is opened on its own root; the terminal relation fails |
| AM13 | error-path retry: attempt 1 discarded after its A root existed; attempt 2 completes; attempt 1's A root presented with attempt 2's openings | prover + verifier | attempt 2 ACCEPTS with different A/M/H roots; the mixed proof REJECTS | fresh RNG instance per attempt (section 3); Merkle paths |
| AM14 | e = 0 forced on a pair-masked claim (test hook on the transcript) | prover + verifier | prover DISCARDS; verifier REJECT "zero terminal mask challenge" | obligation 5 |
| AM15 | prox pair with Fp-dependent ρ's (hook) | verifier | REJECT | obligation 5 |
| AM16 | legacy proof to the repaired verifier / repaired proof to the legacy verifier / repaired proof under a legacy header | verifier | REJECT / REJECT / REJECT | row counts; row counts; first challenge diverges |
| AM17 | FFN finalized before the seams are bound | type | unreachable; a hand-built proof without seam groups REJECTS as AM11 | `finalize` exists only on `Bound` |
| AM18 | attention component discarded while the FFN is Pending | type | no bytes emitted; both consumed | `PendingBlock` owns both |
| AM19 | block k + 1 binds the residual seam to a block-k attention A whose manifest never reserved the residual role | verifier | REJECT | manifest role missing in block k; block k's A cannot finalize before the seam is bound (section 4.5) |
| AM20 | P3: slot ≥ k; slot reused | verifier; prover | REJECT; ACCEPT (prover privacy failure, soundness intact; FA4 G3/G4) | slot check; write-ahead counter |
| AM21 | P3: W root ≠ the manifest's `C*_l` | verifier | REJECT before any transcript | FA4 §4.3 obligation 3 |
| AM22 | λ = 0 for a group member (hook) | verifier | REJECT | obligation 5 |
| AM23 | duplicate role in the manifest; unknown role; missing X-seam role | type (reserve) | typed error before any secret exists | section 4.1 |
| AM24 | request context changed under identical proof bytes | verifier | REJECT | the block header absorbs the context (A03 acceptance 3); identical bytes under the identical context stay valid to a stateless verifier |
| P1 | honest block, fresh entropy, twice | — | ACCEPT twice, all private roots differ | positive gate |
| P2 | the four frozen legacy artifacts and the seeded legacy P1/P3 proofs | — | byte-identical | the legacy path is untouched |
| P3 | the FA1 `mask_diagnostic` extractor run on a repaired A observation | privacy regression | "requires exactly data plus one base mask" refusal on every claim; the FA2 rank tool on the captured coefficients: disclosed 0 | U1 closes only with captured coefficients (blocker B5) |

## 8. Memory and layout delta per shape (for CL8)

[COUNTED] Rows from `commitment_rows` in the tool (mirrors `ZkLayoutV3::new`; the
legacy columns reproduce the pinned counts 5173, 681/1325/7, 10774). Bytes per extra
row use CL8's convention from `zk60_pending_layout.rs` — data + full coset encoding =
n·8·(1 + inv_rate) — plus the Q·8 host pads per row; salts and Merkle trees are per
column and do not change. "standalone" = the repaired FFN without seam roles;
"block" = with `a_sx`/`a_sz`. Table slot rows follow the fixture shifts (7, 0, 14, 6).

| Shape (T, d, f, log_cols, rate, Q) | A rows legacy → standalone → block | H rows | W(P3) rows per slot | Extra A rows: pairs + prox + single-row slots + seams | Block delta bytes (A + H) | vs legacy A + H data+code |
|---|---|---|---|---|---|---|
| tiny T2 d16 f16, 5, 4, 12 (FA1 diagnostic) | 5173 → 5187 → **5191** | 10321 → 10322 | 28 → 32 (+4) | 12 + 1 + 1 + 4 = 18 | 26.1 KB | 0.1 % of 19.8 MB |
| **A00 tiny T32 d16 f16, 8, 8, 256** | 681 → 698 → **702** | 1325 → 1326 | 7 → 11 (+4) | 12 + 1 + 4 + 4 = 21 | 450.6 KB | 1.1 % of 36,974,592 B (CL8's number) |
| 125M d768 f2048 T32, 14, 4, 256 | 114 → 139 → **151** | 127 → 128 | 298 → 308 (+10) | 20 + 1 + 4 + 12 = 37 | 12.5 MB | 15.8 % of 79.0 MB |
| 125M T512 (deployment T) | 559 → 585 → **597** | 485 → 486 | 298 → 308 (+10) | 20 + 1 + 5 + 12 = 38 | 25.6 MB | 3.7 % of 684 MB |
| 8B d4096 f14336 T32, 14, 4, 256 | 299 → 365 → **369** | 269 → 270 | 10774 → 10796 (+22) | 60 + 1 + 5 + 4 = 70 | 46.7 MB | 12.5 % of 372 MB |
| 8B T512 (deployment T) | 3599 → 3665 → **3669** | 3029 → 3030 | 10774 → 10796 (+22) | 60 + 1 + 5 + 4 = 70 | 46.7 MB | 1.1 % of 4.34 GB |

Reading: the delta is a fixed number of rows per layer (it depends on nb_d, nb_f and
the single-row table slots, not on T), so it is noticeable only at small T where the
data rows are few; at deployment T it is ≈ 1–4 %. The **proof** grows less than the
commitment: group vectors are per group, not per row, so the opening gains only the
two seam groups (2 × (n + Q) × 16 B = 16 KB at A00) plus the 22 extra base words in
each of the 256 opened columns (≈ 45 KB at A00), and the two seam sumchecks with
their terminals. The P3 W delta is per FA4 slot: +22 rows × 657 KB ≈ 14.5 MB of
stored codeword per slot at 8B (k = 16 → 231 MB per layer on top of FA4's
accounting), which is CL8/H6's line item, not a per-proof cost. The CFS commitment
gains 4 base rows × 4096 × 8 B = 128 KB per block, shape-independent. Nothing here is
measured; the planner (`scripts/hashline_memory_plan.py`) accepts the repaired row
counts through `--rows` unchanged.

## 9. Rank verdicts of the repaired allocation (executed)

[EXECUTED] `python3 scripts/zk60_fable_joint_rank.py repair -o
results/zk60_fable_fa3_mask_schedule.json` — exit 0, **0 failures** over 36 named
checks and 24 per-family models; every check also runs in
`tests/test_zk60_fable_joint_rank.py::RepairedAllocationFA3` (12 tests). The tool,
its model and its caveat are FA2's (§13, §15): exact mod-p rank over the source's
observation structure with stand-in challenges; **numerical rank is not a simulation
proof**. The "legacy" column is the same model with FA2's kinds, recomputed in the
same run (and FA2's committed outputs are byte-identical under the edited tool).

| Check (name in the JSON) | Model | Repaired | Legacy | What it settles |
|---|---|---|---|---|
| `group_values_all_pairmask_m{m}_n{n}` for (m, n) ∈ {(1,4), (2,2), (2,4), (3,4), (7,4), (7,8), (9,4)} | one group: vector + m terminal values | **0**, rank(B) = 2m + 2n − 2 | n (m = 1), 2 (m ≥ 2) | the "individually public terminal values" channel (FA2 §14.2 / U3) closed for every group shape; the singletons closed |
| `…_with_prox_pair_m{m}_n{n}` | + the proximity vector with a prox pair | **0** | 2–6 | the prox needs no borrowed freedom |
| `negative_control_one_pairmask_claim_single_prox_row` | 1 pair claim, 1 prox row, per column | **1** (expected) | — | the prox pair is required: 3 masks vs 4 dims (FA2 §14.4 in its purest form; S2's three extra prox rows were right) |
| `one_pairmask_claim_prox_pair` | same with the pair | **0** | — | |
| `mixed_group_one_base_member_covered_only_by_composition` | (pair, base, pair) + prox pair | **0** | — | FA2 §14.3 holds, but the schedule does not rely on it (U4) |
| `negative_control_seam_only_pairs_on_legacy_A` | legacy tiny A + pair-masked sx/sz groups, n = 4 | **12** = 2n + 4 (expected) | 12 | a seam-only pair is not a core repair: X and h16 still recovered at rows 1 |
| `whole_A_n4_rows{1,2}_{p1,p3}[_seams]` | whole tiny A: 5 (7) groups, all values, prox pair | **0** in all 8 | 12 | X under three pairs at rho_d/p2/sx, h16 at rho_f/p5, z at rho_d/sz: joint rank full; P3's second-extension coefficients change nothing |
| `whole_H_n4_rows{1,2}` | whole tiny H | **0** | 0 | H unchanged except the prox pair |
| `whole_W_p3_n4_nb1`, `…_nbd3` | whole tiny P3 W | **0**, **0** | 10, 4 | the Wd singleton, the p3/p6 value leaks and the starved prox all closed (U11) |
| `h_logup_sum_zero_sum_u_prox_pair_n{4,8}` | H LogUp sum + zsum + pairs + values + prox pair | **2** = the public identity (rank F = rank I = rank(F ∪ I) = 2) | 2 | U5 re-verified for the repaired layout |
| `tables_at_log_n_16_all_single_row_slots` | 6-slot table group, all pairs | **0** | 2 | U10 |
| `A_per_column_8B_log_cols_16_block` | 8B at log_cols 16 with seams | **0** | — | the rule "pair iff single row" at the boundary case |
| `whole_A_n4_alternative_all_pair_table_blocks` | the uniform alternative | **0** | — | section 2.1 |
| `whole_A_n4_function2_predicate_pairs` | + the predicate pair, z block aliased | **0** | 14 | U9 |
| per-column `A (P1) standalone / block / P3 block / function 2`, `H`, `W (P3) one slot`, four FA2 families (tiny T2, tiny T32, 125M, 8B) | one column of each real layout | **0** in all 24 | A: 2, 2, 1, 1; W: 2, 2, 0, 0 | the affected-profile predicate (FA2 §16) has no affected cell left in the linear model |

Kernel counts as an independent check of the algebra: for the all-pair groups the
number of null functionals that also kill the data is exactly 2 per group (the
trivial identity), and for the whole tiny A it is 2 × (5 + 2 seams) — asserted in
`test_whole_tiny_commitments_repaired_are_covered`.

## 10. Disposition of every FA2 observation

Ids are FA2 §12's (`results/zk60_fable_fa2_observations.json`). "Addressed" = zero
linear leak under the repaired schedule with the named rank verdict; "BLOCKER" = not
settled here (section 11 names the blocker).

| Id | FA2 status / verdict | Disposition under the repair |
|---|---|---|
| A.vec.rho_f | affected: 2 fn (m = 7·nb_f) | **addressed**: `a_mf` pairs; `group_values_all_pairmask_m7_n{4,8}`, `whole_A_n4_*` |
| A.vec.rho_d | affected: 2 fn | **addressed**: `a_md` pairs; `…_m3_n4`, `…_m9_n4` |
| A.vec.p2 | affected: singleton (whole X at T2; 256 fn at T32) / 2 fn at nb_d ≥ 2 | **addressed**: `a_mgu` pairs; `…_m1_n4`; X's three openings jointly in `whole_A_n4_*_seams` |
| A.vec.p5 | affected: singleton / 2 fn | **addressed**: `a_mdd` pairs; same models |
| A.vec.tab | covered for log_n ≤ 15; affected (2 fn) at log_n = 16 | **addressed**: blocks kept where rows_i ≥ 2, pairs where rows_i = 1; `tables_at_log_n_16_all_single_row_slots` |
| A.vec.pred | affected: 2 fn (source-derived) | **addressed** in the model: pairs; `whole_A_n4_function2_predicate_pairs`; no function-2 proof observed (blocker B5 applies to capture) |
| A.vec.prox | covered by borrowed freedom | **addressed**: prox pair; `negative_control_one_pairmask_claim_single_prox_row` vs `one_pairmask_claim_prox_pair` |
| A.value.* | the third appearance of every mask; the source of the 2m + 2n − 4 rank | **addressed**: with pairs the values add only the trivial identity (rank 2m + 2n − 2) |
| A.pads | covered by argument (§14.6) | **unchanged**: fresh pads per row per proof; argument stands (q_pad ≥ Q asserted and checked) |
| A.columns | covered by argument + salted-leaf hash | **unchanged** for fresh commitments; **BLOCKER B4** for FA4's stable W across k proofs (the argument is FA4 §5.1's, the simulator is not written) |
| H.vec.rho_f / rho_d / zsum / tab | covered (pairs), awaiting capture | **unchanged**; re-verified jointly with the prox pair (`whole_H_n4_*`); capture is **BLOCKER B5** |
| H.vec.sum | covered by argument (§14.5) | **re-verified** with the prox pair: residual = the public identity (`h_logup_sum_zero_sum_u_prox_pair_n{4,8}`) |
| H.vec.prox | covered per column, borrowed | **addressed**: `h_prox` pair |
| H.value.* | third appearance | as A.value.* |
| H.pads_columns | as A | as A |
| W3.vec.p3 | affected: 2 fn | **addressed**: `w_mgu` pairs; `whole_W_p3_n4_*` |
| W3.vec.p6 | affected: singleton (whole Wd at T32) / 2 fn | **addressed**: `w_mdd` pairs |
| W3.vec.prox | affected at nb_d·nb_f = 1 (+1 fn per column) | **addressed**: `w_prox` pair (8 masks vs 6 dims per column) |
| W3.value.* | third appearance | as A.value.* |
| W1.plain | n/a (public) | n/a; the approved-root boundary (FA4 §2) is the identity mechanism |
| M.cfs | outside the linear model | **BLOCKER B1**: the CFS channel (round messages, masked claimed sums, `mask_open` functionals) is nonlinear in the data; the schedule fixes only the slot list (+2 seam slots) and freshness |
| cross.sumcheck_checks | identities in counted values | no observation; unchanged |
| (repeated-proof rows of FA2 §17.1) | linear accumulation across proofs | **addressed in the linear model** by fresh masks per proof (U7); **BLOCKER B3/B4** beyond it |

Two dispositions the reader should not miss: the seam pairs (`a_sx`, `a_sz`) are
part of the schedule because the block needs them, but they are **not** what repairs
A — `negative_control_seam_only_pairs_on_legacy_A` shows the legacy leak intact with
them appended (queue acceptance); and the H side changes by exactly one row (its
prox), because FA2 found H's claims already Fp2-effective — the repair does not
pretend otherwise.

## 11. Disposition of FA2's twelve unresolved assumptions

The five identified blockers, named once and referenced below:

- **B1 — the CFS channel.** Every sumcheck's round messages are masked by
  `c·g` for a CFS mask `g` committed in M (`masked_prove`, `extension`,
  `CfsMasker`); the verifier learns `Σ g` (through the Γ's) and `g(ρ)` (through the
  terminal checks) via `mask_open`'s product-form test (`mask_functionals`,
  `zk.rs` 1171–1194). The round messages are products of data MLEs, so the linear
  row model does not apply; hiding rests on a CFS/Libra-style argument (the masked
  rounds are uniform given the two opened functionals of `g`) that no document in
  this repository states or proves. The schedule adds two seam slots and forbids
  sharing/reuse; that is all it can do.
- **B2 — transcript conditioning / simulator.** λ, ρ, e, the points and the column
  indices are functions of the masked messages absorbed before them; the rank model
  conditions on them. A simulator that programs the random oracle and produces the
  same distribution of (roots, masked messages, vectors, columns) must be written for
  the repaired profile; it is standard in the ROM but it is an argument, not a rank.
- **B3 — ranges and nonlinear side information.** Zero linear leak per proof means
  integer ranges have nothing to amplify *in the linear model*; whatever B1/B2 leave
  is what ranges would amplify, so B3 is not independent of them and is not closed.
- **B4 — cross-proof correlation beyond the linear model**, in particular FA4's
  k-slot stable W: per proof the slot's pairs are fresh and the rank model is the
  fresh-W model; across proofs the opened columns are hidden by the pad budget
  q_pad ≥ k·Q (FA4 §5.1, a Vandermonde argument), and the k-transcript simulator is
  FA4 H1 — unwritten.
- **B5 — the missing H / P3-W capture and captured coefficients.** Every rank result
  uses stand-in challenges; Codex's round-10 capture hook does not exist at this pin;
  U1 closes only when the tool is run on exported coefficients of a repaired proof.

| # | FA2 assumption | Disposition |
|---|---|---|
| U1 | generic (stand-in) coefficients | **BLOCKER B5.** Required export (FA2 §19) unchanged: per role, the claims with coefficients and points, the lambdas and prox ρ, the message parts of every vector, the terminal values. Acceptance test P3 (section 7) runs the tool on it. |
| U2 | transcript conditioning | **BLOCKER B2.** The repair makes the simulator's job well-posed (every clear vector and value is a uniform Fp2 given the data, section 9), which is the precondition, not the proof. |
| U3 | terminal values individually public ⇒ every single-base-mask claim leaks | **addressed**: every single-row mask is a pair (A planes, P3 W blocks, the function-2 pair, the single-row table slots incl. log_n = 16); rank 2m + 2n − 2 on every shape (section 9). |
| U4 | mask reuse across vector / value / prox must be full rank jointly; the prox borrows | **addressed**: the prox is a pair in A, H, W; joint models (vector + values + prox, whole commitments) are full rank; coverage no longer depends on which other groups exist (`negative_control_one_pairmask_claim_single_prox_row` shows why the pair, not the borrowing, is the rule). |
| U5 | the zero-sum u pair; u′ fresh | **addressed**: re-verified with the repaired prox (`h_logup_sum_zero_sum_u_prox_pair_n{4,8}`); u′ stays a fresh unconstrained pair; the residual is the public identity. |
| U6 | the CFS channel | **BLOCKER B1.** |
| U7 | ranges and repeats amplify residual linear leak; masks must be fresh per proof | **addressed in the linear model** (zero residual, fresh masks per attempt incl. failed attempts, section 3); **BLOCKER B3** beyond it. |
| U8 | pads and columns: q_pad ≥ Q, Z_n ≠ 0, salted leaves; duplicates shrink S | **unchanged and kept**: the repair adds rows, not columns; both assertions and the verifier check remain; the hash assumption is computational and outside the model (stated). For FA4's W: **BLOCKER B4** (k·Q budget). |
| U9 | function 2's predicate group | **addressed in the model** (pairs; `whole_A_n4_function2_predicate_pairs`); no function-2 proof observed — capture under B5. The first block profile refuses predicates (A03), so this is a later profile's row. |
| U10 | log_cols = 16 turns the table masks single-row | **addressed**: the rule pairs every single-row slot; `tables_at_log_n_16_all_single_row_slots`, `A_per_column_8B_log_cols_16_block`. |
| U11 | P3 W: Wd singleton, p3/p6 values, starved prox | **addressed** per proof (`whole_W_p3_n4_nb1`: 0 vs legacy 10); composed with FA4's budgeted stable commitment as one pair set per slot (section 12.3); the k-proof composition is **BLOCKER B4**. |
| U12 | aliasing: the same X rows at rho_d and p2, h16 at rho_f and p5 | **addressed in the model** (the whole-A models alias the rows, now under three masks each incl. the seam) and **BLOCKER B5** for confirmation on real claims (the capture must show the slice offsets). |

## 12. The P1 block API and the P3 variant (FA4 compatibility); the schema Codex implements from

### 12.1 The P1 block API (conceptual Rust; names at Codex's discretion)

```text
// ---- manifest: closed, versioned, derived from the approved block contract (A00) ----
pub struct FfnManifest { profile: "ffn-v3-mr1", layer: usize, shape: StatementV3 + LayerParams,
                         roles: Vec<Role> }   // fixed order = section 2.2; exactly nb_d X-seam + nb_d Z-seam roles;
                                              // built by `FfnManifest::for_block(&ApprovedP1BlockContract)`; no push/insert
pub enum Role { Plane { site: PlaneSite, rows: (usize, usize) /* re, im */ }, Block { slot: usize, rows: Range },
                Prox { rows: (usize, usize) }, SeamX { c: usize, rows: (usize, usize) }, SeamZ { c: usize, rows: (usize, usize) } }

// ---- the type-state lifecycle; every step consumes `self`; no Clone / Debug / Serialize on secret state ----
pub struct FfnReserved  { manifest: FfnManifest, rng: ZkRng /* from_os, domain ffn-mr1/layer-l/attempt-nonce */ }
pub struct FfnPrepared  { a: CommittedZk, m: MaskCommit, w: WeightRef, handles: FfnHandles }
pub struct FfnPending   { a, m, h: CommittedZk, w, claims: Vec<ZClaim> /* non-seam roles */, consumed: RoleSet, handles }
pub struct FfnBound     { ..., seam_x: SeamTerminals, seam_z: SeamTerminals }
pub struct FfnFinalized { proof: FfnProofMr1 /* framed, exact counts */ }
pub struct Discarded;   // carries a static reason; never a value

#[derive(Clone, Copy)]                       // the ONLY copyable view
pub struct FfnHandles { a: Commitment, m_root: Digest, w: Commitment, x_slices: [SliceDesc; nb_d], z_slices: [SliceDesc; nb_d],
                        scales: (e_x, e_z16), manifest_digest: Digest }

impl FfnReserved { pub fn reserve(m: FfnManifest, w: WeightRef) -> Result<Self, ReserveError>;   // W = approved PUBLIC root (P1)
                   pub fn prepare(self, w: &V3Witness, t_rows: usize, ntt: &NttTables) -> Result<FfnPrepared, Discarded>; }
impl FfnPrepared { pub fn handles(&self) -> FfnHandles;
                   pub fn argue(self, tr: &mut Transcript, block: &BlockCtx) -> Result<FfnPending, Discarded>; }
// no method on FfnPending binds a seam by itself: only the block can, with both peers
impl FfnBound    { pub fn finalize(self, tr: &mut Transcript) -> FfnFinalized; }   // mask_open; open_zk A, H (W under P3); drops all

// ---- the block: the only owner of both components and the only binder of seams ----
pub struct PendingBlock { attn: AttnPending, ffn: FfnPending, ctx: BlockCtx }
impl PendingBlock {
    pub fn bind_internal_seams(self, tr: &mut Transcript) -> Result<BoundBlock, Discarded>;
        // X seam: consumes ffn role SeamX[c] and attn role SeamXm8[c] for every c, exactly once, in one S2-form sumcheck
        //         over eq(tau, x) * sum_c lam_c (X_c(x) - xm8_c(x)) with the masked extension; terminals on BOTH actual A roots
        // Z seam: likewise on z_c / z16c_c
        // refuses: a role already consumed; a peer handle != the handle the block absorbed; any slice != lay.x[c] / lay.z[c]
}
impl BoundBlock { pub fn finalize(self, tr: &mut Transcript) -> BlockProofMr1; }   // ffn.finalize then attn.finalize; exact frame
```

Properties the API enforces (queue acceptance): both internal seams are consumed
**exactly once** (the role set is fixed at reservation, marked at binding, checked at
finalization); a **copied-plane substitute** cannot enter because a seam terminal is
always a claim on `lay.x[c]` / `lay.z[c]` of the FFN A `CommittedZk` the block owns
and on the mirror slice of the attention A the block owns — there is no parameter
through which a third commitment could be supplied; an **unreserved late claim**
cannot enter because no type accepts a `ZClaim` or a role after `reserve`; a
**second opening** cannot happen because `finalize` drops every `CommittedZk`. The
attention side (A04–A06, not designed here) adopts the same four mask kinds and the
same lifecycle; its manifest reserves `SeamXm8[c]`, `SeamZ16c[c]` and the
residual-seam role of section 4.5.

### 12.2 Transcript order of the block (prover = verifier)

1. Block header: `HL-ZK/2` fields, profile, transcript domain, approved-contract
   digest, request context, manifest digest, layer, (P3) slot.
2. Attention: W root (approved public), A root, M root. FFN: W root (P1: approved
   public root; P3: the manifest's `C*_l`), A root, M root.
3. FFN β, γ, α → FFN H root; attention helpers likewise after their challenges.
4. FFN arguments in the legacy order (gu, d, zcF, zcD, tab, zsum, [pred]) with every
   masked claim and terminal absorbed before the next challenge; attention arguments
   in A01's 13-section order (their private form is A04–A06's).
5. Seam X: τ_sx, c_sx → γ_sx → masked rounds → masked terminals (FFN side, attention
   side) → e_sx; seam Z likewise.
6. FFN `mask_open` (all slots incl. the seams); attention `mask_open`.
7. Openings, one per owned commitment, fixed order: FFN W (P3 only), FFN A, FFN H,
   attention W (P3 only), attention A, attention H; inside each `open_zk` the actual
   order of FA1 §4.4 (lambdas per group → prox ρ → vectors absorbed → prox absorbed →
   indices). The stale `pcs.rs` doc comments (FA1 C-1) should be corrected in the same
   change.

### 12.3 The P3 variant and FA4 compatibility

Under P3 the FFN's W is FA4's **budgeted stable hiding commitment `C*_l`**
(construction (b)): data rows, then **k slot sets**, each set = the repaired W roles
(`w_mgu` pairs, `w_mdd` pairs, `w_prox` pair: 2·(3·nb_d·nb_f) + 2 rows), then the
public slot; `q_pad = k·Q`. The composition is exact: FA4's set of "3·nb_d·nb_f + 1
rows per slot" becomes "6·nb_d·nb_f + 2 rows per slot" and nothing else in FA4
changes — the manifest, `WeightPolicy`, the slot counter, the header fields, the
verifier's `proof.w_com == C*_l` and `slot < k` checks, and the changed W rate are
all as FA4 §4 specifies. Extra obligations of the P3 variant:

- `reserve_p3(manifest, stable: &mut StableWeightCommitment)` takes the slot
  write-ahead (FA4 H2) and binds it into the manifest; the roles' row indices are the
  slot's; a discarded attempt burns the slot (never reuses it).
- The two matmul sumchecks keep their second extension round and the P3 coefficient
  pairs `((1 − e2)(1 − e), (1 − e2)·e)` on the A side and `((1 − e2)(1 − e), e2)` on
  the W side (`mask_specs_v3(.., true)`, `build_w_zclaims_v3`); the pair form applies
  to both (the P3 whole-A models of section 9 use these coefficients).
- The W group vectors have length n + k·Q; `verify_zk`'s length check is already
  parametric on `q_pad`; the framed envelope carries the length from the policy, not
  from the proof.
- Per proof the rank model is the fresh-W model of section 9 (`whole_W_p3_n4_*`,
  `W (P3), one slot set`); across the k proofs the column channel rests on FA4 §5.1's
  pad budget and the unwritten k-transcript simulator — **blocker B4**, and FA4 H1 is
  where it closes.
- `--wcache` remains refused; the budget check replaces it (FA4 H3).

### 12.4 The schema (mirrored in `results/zk60_fable_fa3_mask_schedule.json` → `schedule`)

Codex implements from these fields without guessing a count or an order:

| Field | Content |
|---|---|
| `profile`, `transcript_domain_prefix`, `header` | `ffn-v3-mr1`, `hashline-zk-mr1/`, the `HL-ZK/2` header fields |
| `rule` | the one-sentence rule of section 1 |
| `mask_kinds` | pair / block / zero_sum_pair / prox_pair: rows, claim form, hiding argument |
| `commitments.A.mask_roles_in_allocation_order` | 9 roles: id, count formula (nb_d, nb_f, table rows, pred), kind, group key, data, coefficient pair per privacy mode, proof field, legacy rows, repaired rows |
| `commitments.H…`, `commitments.W_P3…` (per slot), `commitments.M_cfs.slots_in_order` | as above; M lists the 9 slots with (vars, degree) |
| `rng` | instance/domain rule, the six consumption steps, the P3 W rule, the error-path rule |
| `transcript_order_block_profile` | the 8 steps of 12.2 |
| `rank_verdicts`, `families` | section 9's evidence, with `expected_disclosed_dim` and `verdict` per check, and per-family `rows` (section 8) |

Row counts per shape are computed, not typed: `commitment_rows(layout_v3(T, d, f,
log_cols), predicate, seams)` in the tool is the reference implementation of the
repaired counts and is pinned to the legacy counts by test.

## 13. Files

| File | Role | SHA-256 |
|---|---|---|
| `docs/zkmatrix-poc/ZK60_FABLE_MASK_REPAIR.md` | this document (new) | — |
| `results/zk60_fable_fa3_mask_schedule.json` | the schedule Codex implements from + every rank verdict + per-family rows (new; generated by `repair`) | `7cf0d795363a125b20db0443c6118e0b5b8e243264a497f6d35470d4f03785a2` |
| `results/zk60_fable_fa3_adversarial_matrix.json` | section 7, machine-readable (new) | `3e1d08f3584432db5935fc3689da6bccc2d2f89aa60af67f910d1001dc6a1240` |
| `scripts/zk60_fable_joint_rank.py` | FA2's tool + the `pairmask` kind, `prox_pair`, the repaired group builders, `commitment_rows`, `fa3_schedule`, `repair_verdicts`, the `repair` subcommand (modified; FA2's `fixtures` / `impact` outputs byte-identical) | `ad5e4e483c6dd8c5f73a87ddb0af1d06c3084576e82428e9c2ada6a764ffbb5b` |
| `tests/test_zk60_fable_joint_rank.py` | FA2's 22 tests + `RepairedAllocationFA3` (12 tests) (modified) | `3bb0106e32758953867079d3ca0e0dd64450ea2f47f5dae937a52c36e2df4e17` |

Read, not changed: every file named in the header; `hashline/src/*` untouched
(section 0 hashes). Commands: `python3 -m unittest discover -s tests -p
'test_zk60_fable_joint_rank.py' -v` (34 OK); `python3
scripts/zk60_fable_joint_rank.py repair -o results/zk60_fable_fa3_mask_schedule.json`
(exit 0).

## 14. Limits

- **Design and review are the deliverable.** No source in `hashline/` changed; the
  repaired profile, its layout constructor, its envelope and its tests do not exist at
  this pin. Production private attention/FFN composition remains gated on acceptance
  of this plan, and nothing here certifies a construction in advance.
- **The rank evidence is FA2's model with FA2's caveat**: exact rank under stand-in
  coefficients over the source's observation structure; not a simulation proof; the
  CFS channel, transcript conditioning, integer ranges beyond the linear model, and
  cross-proof correlation (including FA4's k-slot reuse) are the five identified
  blockers of section 11, unchanged in kind from FA2's U-list and now named.
- **Captured coefficients: none.** The H / P3-W capture hook (Codex round 10) does
  not exist; the tool has never consumed a real proof's coefficients; U1 stays open
  until acceptance test P3 runs on a repaired proof.
- **Shapes modelled**: whole commitments at n = 4; per-column models at the four
  FA2 families plus 8B at log_cols 16; group shapes up to (9, 4) and (7, 8). The rank
  rules are n-independent by FA2's derivation (§14) and were checked at n ∈ {2, 4, 8};
  nothing was run at real width.
- **The attention side** is specified only by the four mask kinds, the lifecycle
  and its seam roles; the private attention arguments (A04–A06) and their own
  observation inventory are not reviewed here — every attention claim will need its
  own row in a schedule like section 2.2 before the block's privacy can be argued.
- **Degeneracy probabilities** (2^−128 for pairs, 2^−64 for block row bits and the
  prox pair) are derived, not measured; the refusal-not-resample rule costs
  ≈ 2^−62 completeness per proof and was not exercised.
- **Memory numbers are counted**, in CL8's convention, not measured; the T = 512 rows
  use the fixture shifts, not a real layer's.
- **The CFS blocker is inherited, not new**: the legacy profile relies on the same
  unwritten argument; the repair neither weakens nor strengthens it beyond adding two
  slots.
- This document was written after a first FA3 attempt was cut off by a rate limit;
  the only surviving artefact of that attempt (the `pairmask` kind and `prox_pair`
  option in the tool) was reviewed and kept.
