# FA8 — the transcript simulator and the repeated-proof argument: FA3 B2–B4 for the repaired FFN profile, FA4's budgeted stable W, and the block

| | |
|---|---|
| Reviewer | Claude Fable 5.1, independent privacy reviewer (2026-09-08 session) |
| Task | `ZK60_FABLE_QUEUE.md` round 11, **FA8 — complete transcript and repeated-proof argument**, priority 0: "Address FA3 B2–B4 with an explicit simulator/conditioning argument, hash and entropy assumptions, failure/retry behavior, and the entire composition schedule. Treat fresh P1 and FA4's budgeted stable P3 W separately. List anything unresolved; no implementation or finite rank matrix substitutes for this review." |
| Source pin | worktree `wt-zk60-fa`, branch `zk60-fable-review`, HEAD `ed478da` = FA6 + FA7 merged with Codex's `972da4e` (round 12). `zkp-core/src/sumcheck.rs` `56dbb8c7…f250e007d19` and `hashline/src/zk.rs` `c4442534…8cc99b7715e` are byte-identical to FA6's pin; `hashline/src/pcs.rs` `60ac5f2f…f77960ab1b` to FA1/FA3's; `zkp-core/src/transcript.rs` `31ce3c9a…4cb733da8`; `zkp-core/src/rng.rs` `0d4a99ab…f4594157ccea9eb`; `hashline/src/stable_weight_slots.rs` (new, Codex H2) `efcf5003…358b7666b214`; `hashline/src/private_seam.rs` `ae539c9c…4fa0edcb435`; `hashline/src/zk_proof_size.rs` `a7598d0a…d695e890d8c04fcf` |
| Tool | `scripts/zk60_fable_transcript_sim.py` — three exact structural checks the simulator relies on and the machine-readable disposition (imports FA2's and FA6's tools by path; nothing duplicated) |
| Tests | `tests/test_zk60_fable_transcript_sim.py` (16 tests) |
| Records | `results/zk60_fable_fa8_transcript_sim.json`, `results/zk60_fable_fa8_disposition.json` |
| Limits (queue) | No private-block, deployment or throughput acceptance follows from a partial analysis or diagnostic. Shared production edits remain with the source owner. Nothing under `hashline/src/`, `zkp-core/`, FA2–FA7's files or `codex-audit-*` was changed. No cargo, no GPU, no proof run; exact integer arithmetic only; no recovered value appears anywhere. |

## 0. The verdict in plain words

**B2 (transcript conditioning / simulator) is closed as a written argument for
the repaired FFN profile `ffn-v3-mr1`, P1 and P3 with a fresh W commitment,
under the model of §A and eight conditions on the code (§B.8).** The simulator
(§B.2) is simpler than FA6 §7.4 anticipated: it commits the CFS mask matrix M
*first* and never equivocates it; it programs the random oracle at exactly one
kind of point — the sumcheck **round challenges** (56–58 per FFN proof at the
A00 shape, 92–94 at 8B, plus 20–36 for the two seams) — and squeezes every other
challenge honestly; it commits A′ and H′ (and W′ under P3 fresh) with **zero
data** and fresh mask pairs, pads and salts and runs the *honest* PCS opening on
them; and it samples every slot's round messages uniformly on the fibre of
FA6's consistency subspace over the pair `(claimed sum, fin)`, with
`fin := want(m_t) + c·g_M(ρ)` for the `g_M(ρ)` the committed M actually has.
That this reproduces the honest distribution rests on three facts beyond
FA6/FA3, each pinned by an exact check (`fibre`, `k_slots`, `pad_budget` in the
record): for **every** challenge sequence the two mask functionals `(Σg, g(ρ))`
are independent and the last-round map is onto `F_{p²}`; the whole-commitment
mask map is surjective for every non-degenerate coefficient set, not only for
stand-ins (a structural cover, §B.2 step 8); and the opened positions of a row
are hidden exactly while their number is ≤ `q_pad`. The single-proof
statistical distance is derived in §B.7:
`Δ₁ ≤ q_H·(n_sq + n_leaves + n_rng)/2^256 + N_fp·2^-95` for published proofs,
plus the degeneracy refusals `δ_deg ≈ 2^-62` (a completeness loss the simulator
mirrors, kept in the bound because the queue asked for it). The `2^-95` is not
inherited: `2^128 ≡ p − 2^32 (mod p)`, so a 128-bit draw reduced mod p is
`2^-96`-close to uniform, not the source's `2^-64`.

**B3 (ranges)** follows for the repaired profile: a view that is simulatable
without the witness gives a bounded-integer solver nothing the public statement
does not already say. For the **legacy** profile the contrast is exact: at T32
one proof discloses one base-field functional of the two X rows per column
(FA7), and with the int8 range that functional determines **both rows** by a
2^16 enumeration per column (uniqueness fails with probability ≈ 2^-48); the
same for h16 with 2^32 (§E.2).

**B4 (cross-proof)** splits. **F1** — fresh P1, and P3 with a fresh W — is
closed: k proofs are k independent runs of the simulator after a shared public
prefix, `Δ_k ≤ k·Δ₁`. **F2** — FA4's budgeted stable W, k slot sets against one
Merkle root — the k-transcript simulator FA4 H1 asked for is written (§F.2):
one registration-time commitment to a zero matrix with random pads and k unused
pair sets, proof i on slot i's rows, the union `J` of opened positions per row
hidden while `|J| ≤ k·Q ≤ q_pad`, each proximity vector covered by its own
slot's prox pair even though it touches every row. It **closes only under the
enforcement of consumption** (§F.2.4): every slot declared at most once
including failed attempts, no opening of `C*_l` outside a reservation, no
rollback or copy of the journal. Codex's H2 journal enforces the public-state
half (write-ahead, burn on drop/death, exclusive lock, torn-tail refusal,
`q_pad = budget·Q`) and, by its own contract, not the other half (no consuming
API yet, no secret material, no anti-rollback). Until E1–E3 land, the stable-W
profile's W channels stay **blocked**, not accepted.

**The block profile** closes on the FFN side and on the FFN-side seam terminals
(FA3's pair rows, FA6's slot); the attention side is a blocker in four named
pieces (A1–A4, §C.4), exactly as FA3 §14 and FA6/FA7's uninventoried
`SeamXm8[c]`, `SeamZ16c[c]` announced.

Finite rank tests and a declaration of model identity do not substitute for
the argument or for the enforcement, and nothing here is a deployment,
private-block or throughput acceptance (§H).

## A. Scope, the model, and what is taken as given

### A.1 The constructions under review

| Profile | What it is | Role here |
|---|---|---|
| `legacy_v3` | `prove_layer_zk_v3` / `verify_layer_zk_v3` at `ed478da` (single-row base masks, one prox row) | the contrast; FA7 measured its leak |
| `repaired_P1` | FA3's `ffn-v3-mr1` standalone: every single-row mask a pair, prox pairs, block table slots, public W (approved root) | the construction B2 is written for |
| `repaired_P3_fresh_W` | the same with a fresh hiding W commitment per proof carrying one repaired pair set (`w_mgu`, `w_mdd`, `w_prox` pairs) | the per-proof model of FA4's slot |
| `repaired_P3_stable_W_k_slots` | FA4 construction (b) with FA3 §12.3's slot sets: `C*_l` = data rows + k pair sets + pads, `q_pad = k·Q`, one root in the manifest, k proofs | F2 |
| `block_profile` | FA3 §12.2: attention + FFN components, two internal seams, two `mask_open`s, six openings | §C |

None of the repaired profiles exists in source at this pin (FA3 §14, blocker
B5). The argument is about the construction *as specified* by FA3 §2–§6, §12,
FA6 §7.3 and FA4 §4–§5; §B.8 lists what the code must satisfy for the argument
to apply to it.

### A.2 The model

- **Random oracle.** blake3 is modelled as a random oracle in three roles, and
  the simulator uses them differently: (H1) the Fiat–Shamir transcript
  (`Transcript::absorb`, `squeeze_bytes`, `transcript.rs` 44–94; `hashline-v1/`
  prefix, length-framed labels, FA5 §4.1) — **programmable by the simulator at
  squeeze points only**; (H2) `hash_column`, `salt_leaf` (`pcs.rs`:
  `leaf = blake3(blake3(column) ‖ salt)`, 32-byte salt from `ZkRng::bytes32`)
  and the Merkle nodes — **never programmed**; hiding of an unopened column is
  the event that nobody queries the oracle at an input containing its salt;
  (H3) the keyed XOF of `ZkRng::from_entropy_reader` (`rng.rs` 44–61:
  `blake3::keyed(32 bytes of /dev/urandom)`, `hashline-zk-os-rng/v1/` + domain,
  counter-refilled) — a pseudorandom stream to anyone without the key; (H4) the
  prefixes `hashline-v1/`, `hashline-zk-rng/`, `hashline-zk-os-rng/v1/`,
  `hashline-stable-slot-record-v1/` and the length framing make the oracle
  points of the four uses disjoint.
- **Entropy.** `ZkRng::from_os` reads 32 bytes of `/dev/urandom` and fails
  closed (`rng.rs` 30–42); one stream per component per attempt (FA3 §3, FA6
  I4). The stream's `fp()` is a 128-bit word reduced mod p; its exact distance
  from uniform is derived in §D.4.
- **Field.** `p = 2^64 − 2^32 + 1`, `F_{p²} = F_p[u]/(u² − 7)`; `|F_{p²}| = 2^128`
  up to the factor `(1 − 2^-32)²`. `2^-128` below means `1/|F_{p²}|` and
  `2^-64` means `1/p`.
- **Distinguisher.** Any verifier and environment making at most `q_H` oracle
  queries in total, holding the public statement (and, under P1, the public W;
  under stable P3, the manifest with `C*_l`) and the proof(s). Zero knowledge
  means: for every witness satisfying the relation, the statistical distance
  between the honest transcript distribution and the simulator's, taken over
  the prover's coins and the oracle, is at most the stated `Δ`.
- **Salted-leaf hiding is computational in the sense above** (an oracle-query
  event), the rest of the argument is information-theoretic.

### A.3 Taken as given, with the exact statement used

| Id | Source | Statement used here |
|---|---|---|
| G1 | FA6 §2.2, `pc_full_mask_all_zero_challenges`, `…_all_one_challenges` | for every slot and **every** challenge sequence the map from the mask coefficients to (claimed sum or Γ, all round messages including extension rounds) is surjective onto the consistency subspace S, `dim S = N·d + 1`, triangular in the free coordinates `(G, Δ_j(x))`; the batched pairs (GU, ZC20), (D, ZC17) are surjective onto `S_joint` |
| G2 | FA6 §3, I5 | the M opening (q′, prox, 256 columns) is a deterministic function of the single θ-combined value V plus independent uniform pads; V is a public function of the transcript; one `mask_open` per `MaskCommit` |
| G3 | FA3 §9, FA2 §14.3–§14.5 | under the repaired schedule the linear observation map has `disclosed_dim = 0` for the whole tiny A (5/7 groups, seams), H (public identity only), P3 W; the zero-sum u leaves exactly the public LogUp identity |
| G4 | FA2 §14.6, FA6 §3 | `encode_row_zk` = `f + Z_n·g_pad` on the coset `7·G_nn`, `Z_n ≠ 0` there; ≤ q_pad distinct opened points are a bijective image of the row's pads |
| G5 | FA7 §4, FA2 §12 | the observation set of one proof is exactly: group vectors (message + pad parts), proximity vector, terminals, sampled columns with salts and paths, the roots, the CFS messages, the M opening — nothing else is emitted (`LayerProofZk::to_bytes`) |
| G6 | FA5 §4.1, §4.5 | every challenge is preceded by every message it must constrain; challenges are 128-bit reductions (§D.4 for the exact bias); indices are 64-bit words masked to `bound − 1`, with replacement |
| G7 | FA3 §12.2, `results/zk60_fable_fa3_mask_schedule.json`.`transcript_order_block_profile` | the block transcript order (header; roots; β γ α; H root; the FFN arguments in legacy order; seams X then Z; two `mask_open`s; six openings, each `open_zk` in FA1 §4.4's inner order) |
| G8 | FA6 §5, I4; FA3 §3 | one OS stream per component per attempt with an attempt nonce; no coefficient, pad, salt or mask row serves two transcripts |

Where the simulator needs a statement stronger than the record proves (G3 for
*all* non-degenerate coefficients rather than stand-ins; G1's projection onto
`(claim, fin)`), §B gives the structural argument and the exact check.

### A.4 Not taken as given

The repaired profile's implementation (B5); the attention side (A04–A06, FA3
§14); the enforcement of slot consumption beyond Codex's public journal;
FA5's changed-rate soundness number; anything outside the model (§E.3).

## B. B2 — the simulator for one repaired-profile FFN proof

### B.1 The honest view, in transcript order (P1; FA3 §12.2 restricted to one FFN component)

0. header (`HL-ZK/2`, profile, domain, contract digest, request context, manifest digest, layer); 1. W root (public, approved); 2. A root; 3. M root; 4. β, γ, α; 5. H root; 6. for each slot in the order GU, D, ZC20, ZC17, TAB, ZSUM, [PRED]: its point challenges (r_i, r_j, λ_gu, λ_f; τ, μ, ν; …) → `c_s` → the masked claimed sum or Γ absorbed → N_s rounds, each `h_j` absorbed then `r_j` squeezed (the last one(s) being the extension round(s), whose challenge is `e`) → the masked terminals absorbed; 7. `mask_open`: θ → q′ → `rs` → prox → 256 indices → columns; 8. openings in order W (P1: plain `pcs::open`), A, H; inside each `open_zk`: λ's per group → prox ρ → vectors absorbed → prox absorbed → indices → columns with salts and paths.

### B.2 Sim, step by step

Sim holds the public statement, W (P1), the layout (hence every row role, slot
list `mask_specs_v3`, group structure and claim schedule — all functions of the
statement, FA3 §6.2–6.3), and controls the oracle answers to points not yet
queried.

**Step 0 — header.** Emitted as the honest prover does; absorbed. (Public;
identical distribution.)

**Step 1 — W root (P1).** The approved public root. Identical.

**Step 2 — A root.** Sim builds A′: every data row **zero**, every mask row
(the pairs `a_mf, a_md, a_mgu, a_mdd`, the prox pair, the six table slot masks,
[the predicate pairs], [the seam pairs]) uniform, and commits with
`commit_zk_owned` semantics: fresh pads (`rows × Q`), fresh 256-bit salts,
coset encoding, salted Merkle tree. The root is absorbed.
*Distribution.* The root is a Merkle root over leaves `H(H(col_j) ‖ salt_j)`.
Conditioned on the distinguisher never querying the oracle at an input
containing an unopened column's salt, the unopened leaves are uniform and
independent of the columns in both worlds; the opened columns are treated in
step 10. So the root's distribution differs between the honest A and A′ only
on the salt-query event, probability ≤ `q_H·nn_A/2^256`.

**Step 3 — M root.** Sim runs the honest `mask_commit(specs)`: for each slot a
uniformly random `CfsMask` (`N_s·d_s + 2` coefficients), 256 pads per re/im
row, `b` with `b_512 = −b_0`, `u`, 4096 salts. **This is a real, honest M and
it is never equivocated.** Absorbed. (An honest M's a-rows are uniform too;
the root hides them by the same salt argument, `q_H·4096/2^256`.)

**Step 4 — β, γ, α.** Squeezed honestly (Sim does not need them in advance:
H′ has zero data).

**Step 5 — H root.** H′: zero data rows, uniform `h_mf, h_md, h_up, h_prox`
pairs and table helper pair blocks, and the zero-sum pair `h_u` drawn as the
source draws it (`n − 1` draws, last entry `−Σ`); fresh pads and salts;
committed; absorbed. Same distribution argument as step 2.

**Step 6 — each masked sumcheck slot s.** This is the only place Sim programs
the oracle.

6a. The slot's point challenges (`r_i, r_j, λ_gu, λ_f` for GU; `r_ip, r_jp, λ_d`
for D; `τ, μ, ν0` for ZC20; …) are squeezed **honestly** — Sim learns them
before it needs them.

6b. `c_s` squeezed honestly. If `c_s = 0` Sim aborts exactly as the hardened
prover does (FA6 I3; §D.1).

6c. Sim now **chooses the slot's N_s round challenges** `ρ_s = (r_0, …, r_{N_s−1})`
uniformly at random (the extension-round challenge `e` — and `e2` under P3 —
among them). It checks FA3 §6.5's refusals on them (`e = 0`; P3 `e2 = 1`; for
the pair claims `λk1 ≠ 0` is checked at step 8 where the λ's are drawn) and
aborts if they trigger, as the honest prover discards (§D.1).

6d. With `ρ_s` known, Sim computes the two quantities the fibre needs:
- `G_s = Σ_x g_s(x)` and `g_s(ρ_s)` from **its committed M** (`CfsMask::total`,
  `CfsMask::eval`);
- the masked terminals `m_t` this slot will emit, from **A′ (and H′, W′)**: for a
  pair-masked claim `m = k0·T̃(p) + k1·(R̃_re + u·R̃_im)(tail p)` with `T̃ = 0` on A′,
  i.e. `m = k1·S(tail p)` where `S = R_re + u·R_im` is the pair's F_{p²} row and
  `p` is the claim's point (a function of `ρ_s` and the earlier point
  challenges); for a block slot the block form; under P1 the W terminals are the
  public W's evaluations at `p3`/`p6` (computed from W).
- `want_s(m_t)` by the verifier's terminal relation of the slot (FA6 §1.2's
  column), and `fin_s := want_s(m_t) + c_s·g_s(ρ_s)`.

6e. The claimed sum. Zero-claimed slots (TAB, ZSUM, the seams; PRED with its
public τ): Sim sends `Γ_s = c_s·G_s` — the *true* Γ of its M. Matmul slots
(GU, D): the honest claim is `s + c_s·G_s` with `s` private; Sim sends a
**uniform** `F_{p²}` value. Batched zero-checks (ZC20, ZC17): Sim sends
`Γ20 = c20·G20 − ν0·c_gu·G_gu` with its M's true totals (the verifier forms
`ν0·gu_claim + Γ20`); likewise Γ17.

6f. The round messages. Sim samples `(h_0, …, h_{N_s−1})` **uniformly on the
fibre** `S ∩ {h_0(0) + h_0(1) = claim} ∩ {h_{N_s−1}(r_{N_s−1}) = fin_s}` in FA6's
free coordinates: `Δ_j(x) = h_j(x) − h_j(0)`, `x = 1..d_s`, uniform for
`j < N_s − 1`; `Δ_{N_s−1}` uniform on the affine line/plane
`{Δ : h_{N_s−1}(r_{N_s−1}) = fin_s}`; every `h_j(0)` then fixed by the chain
`h_j(0) + h_j(1) = interp(h_{j−1})(r_{j−1})` (with `h_0`'s by the claim). That
this fibre is never empty is **Lemma L3(ii)** below.

6g. Emission and programming. For `j = 0..N_s − 1`: absorb `h_j` (an honest
oracle evaluation of the chained state); then **program**
`squeeze(state_j) := r_j` — the oracle point is
`blake3(state_j ‖ "squeeze" ‖ counter)`, and `state_j` is a chained value that
already contains the fresh A root, so it has not been queried before except
with probability ≤ `q_H/2^256` per point (§B.3). After the last round the
masked terminals `m_t` are absorbed exactly as the honest prover absorbs them
(`gu-term`, `d-term`, `zcF-term`, …).

*Distribution of step 6 (given everything absorbed before it).* Fix the slot's
public constants and `c_s`. Honest: `(claim, rounds)` is uniform on S (G1), and
`fin`, `g(ρ)` are deterministic functions of the view
(`g(ρ) = (fin − want(m_t))/c`, FA6 §2.1). Sim: `(G_s, g_s(ρ_s))` is a pair of
functionals of the uniformly random committed coefficients; by **Lemma L3(i)**
it has rank 2 for every `ρ_s`, so `(G_s, g_s(ρ_s))` is uniform on `F_{p²}²` and
independent of everything absorbed so far (M's root reveals nothing about the
coefficients but the salt event). Hence `(claim, fin)` — `(c·G, want + c·g(ρ))`
for a zero-claimed slot, `(uniform, want + c·g(ρ))` for a matmul slot — is
uniform on `F_{p²}²` in Sim; in the honest world the projection `S → F_{p²}²`,
`(claim, rounds) ↦ (claim, fin)` is a surjective affine map (**L3(ii)**), so
`(claim, fin)` is uniform on `F_{p²}²` there too, and conditioned on it the
rounds are uniform on the fibre in both worlds. The batched pairs are the same
statement in `F_{p²}⁴` (`(G_gu, g_gu(ρ_gu), G20, g20(ρ20))` has rank 4 —
`fibre.batched_pairs`, 9 systems incl. all-zero and all-one challenges). The
matmul slot's implicit private sum in Sim is `s′ := claim − c·G_M`, and the
batched claim the verifier forms is `ν0·s′ + c20·G20_M` — a consistent
zero-check claim, as coded. The masked terminals `m_t` are uniform `F_{p²}`
values under the pair (step 8's L1) and independent of the CFS coefficients in
both worlds, so the joint law of `(rounds, m_t)` is `(uniform on S | its
projection) × (the PCS law)` linked by `fin = want(m_t) + c·g(ρ)` in both. This
is the composition of FA7's terminal distribution through the terminal
relation with FA6's round-by-round uniformity that the task asked for.

**Lemma L3 (fibre).** For every `N ≥ 1`, `d ≥ 2`, every `ρ ∈ F_{p²}^N`:
(i) `rank [sum_weights(N, d); eval_weights(ρ, d)] = 2`; (ii) the map
`Δ_{N−1} ↦ h_{N−1}(r_{N−1})` is onto `F_{p²}`.
*Proof.* (i) On the coordinates `(a_0, a')` the two functionals have the minor
`2^N·Πρ − 1`; on `(a_0, a_{j,e})` they have `2^{N−1}(2ρ_j^e − 1)`; on
`(a', a_{j,1}), (a', a_{j,2})` they have `2^{N−1}(ρ_j − Πρ)` and
`2^{N−1}(ρ_j² − Πρ)`. All vanish only if `Πρ = 2^-N`, `ρ_j = 1/2` and
`ρ_j² = 1/2` for every j — contradictory (`1/4 ≠ 1/2`). (ii) With
`h(0) = (prev − Δ(1))/2` from the chain relation,
`h(r) = h(0) + Σ_x Δ(x)·L_x(r)`, so the coefficient vector of `Δ` is
`(L_1(r) − 1/2, L_2(r), …, L_d(r))`. For `d ≥ 2`, `L_x(r) = 0` for all `x ≥ 2`
forces `r ∈ {0, 1}`, where `L_1(r) − 1/2 ∈ {−1/2, 1/2} ≠ 0`. (For `d = 1` the map
degenerates at `r = 1/2`; no slot has degree 1: `mask_specs_v3`, FA6 §1.3.) ∎
Checked exactly for `(N, d) ∈ {(2,2), (3,2), (4,3), (5,4), (6,4), (10,4)}` × seven
challenge sequences (all-zero, all-one, last 0, last 1, last 2, all `1/2`,
random) and for every integer last challenge `0..d+1` at `d ∈ {2,3,4}`:
`fibre.all_ok = true` (42 + 9 + 15 rows).

**Step 7 — `mask_open`.** Sim runs the honest `mask_open` on its M with the
functionals the verifier will form: every derived `g_s(ρ_s)` equals
`(fin_s − want_s)/c_s = g_M(ρ_s)` **by construction of `fin_s`**, and every sent
Γ equals `c_s·G_M` (the matmul Γ's carry the true totals too), so the
θ-combination V is the true functional of the committed a-rows and the
product-form test passes. θ, `rs`, the 256 indices are squeezed honestly. By
G2 the view `(q′, prox, columns)` is `V` plus independent uniform pads, `b`, `u`
— the same law in both worlds because Sim's M *is* an honest M. This is the
resolution of FA6 §7.4(b): nothing about M has to be equivocated, because the
functionals' values are fixed by `(M, ρ)` in both worlds and the data-dependent
part lives entirely in the fibre of the round messages. One opening (I5).

**Step 8 — openings of A′, H′ (and W′ under P3).** Sim runs the honest
`open_zk`: λ's per group squeezed, the group vectors `v_g = Σ_i ρ_{g,i}(m_i ‖ p_i)`
folded from A′, prox ρ squeezed, prox vector folded, indices squeezed, columns
with salts and paths from A′'s tree. The verifier's checks
`<v_g, cw> = Σ_k λ_k·value_k` hold because the values are A′'s true terminals
(step 6d) and the vectors are A′'s true folds. If some `λ_k = 0` or `k1 = 0`
Sim aborts as the honest prover discards (FA3 §6.5).
*Distribution — Lemma L1 (structural cover).* Fix the coefficients (λ's, k0/k1
per claim, points, prox ρ's) outside the refused set. Write `S_k = R_re + u·R_im`
for member k's pair (an `F_{p²}`-valued row, uniform since `(R_re, R_im)` is a
bijective preimage), `cw_j = eq(tail)_j`. Group g's observations are
`v_g[j] = D_g[j] + Σ_k λ_k k1_k S_k[j]` and `value_k = d_k + k1_k Σ_j cw_j S_k[j]`,
with `D, d` the data contributions. Choose `S_k` for `k ≥ 2` to hit any target
`value_k` (one `F_{p²}` equation per member in n unknowns; some `cw_j ≠ 0` since
`Σ_j cw_j = 1`); then choose `S_1[j]` column by column to hit any target `v_g[j]`
(`λ_1 k1_1 ≠ 0`); `value_1` is then forced by the identity
`Σ_j cw_j v_g[j] = Σ_k λ_k value_k`. So the mask map of one group is onto its
consistency subspace of dimension `2m + 2n − 2` base rows, **for every**
coefficient set with all `λ_k k1_k ≠ 0`. The prox vector's per-column
contribution from the prox pair is `ρ_re R_pre[j] + ρ_im R_pim[j]`, a bijection
`F_p² → F_{p²}` whenever `ρ_re, ρ_im` are F_p-independent, and the prox pair
appears in no other observation; so the prox vector is uniform per column
independently of everything else. Block table slots (`rows_i ≥ 2`) are
F_{p²}-effective through `(1 − p_0, p_0)`, `p_0 ∉ F_p` (FA2 §14.3). Roles are
disjoint row ranges (FA3 §4.4), each pair belongs to one group, so the joint
mask map over all groups, all values and the prox is block-triangular and onto
the product of the consistency subspaces; the data contributions lie inside
those subspaces (the honest data satisfies the same identities), so the
observation vector is uniform on a **data-independent** affine space — which is
exactly `disclosed_dim = 0` (FA2 §13: `image(A) ⊆ image(B)`). The one
non-trivial constraint is H's LogUp sum claim: its group vector satisfies
`Σ_j v_sum[j] = λ·0` because the data part sums to zero (the LogUp identity,
public) and the u pair is zero-sum; A′/H′ with zero data and a zero-sum u sit in
the same affine space (FA3 `h_logup_sum_zero_sum_u_prox_pair`; FA7 §8). FA3 §9
verifies L1 numerically on every shape with stand-ins; L1 is what makes it hold
for the actual challenges the simulator draws. Aliasing (X at `rho_d`, `p2`,
`sx`; h16 at `rho_f`, `p5`) only means the same data enters several groups —
irrelevant to a cover argument about masks.

**Step 9 — what the data would have added.** Nothing observable: every term
in which the honest data appears (vector message parts, terminals, `want`,
`fin`, opened columns) has been shown to be shifted inside a space on which
the masks/pads are uniform.

**Step 10 — pads, folded pads and opened columns (Lemma L2).** Per row i,
opened positions `J` (with replacement; duplicates shrink J), `|J| ≤ Q = q_pad`.
Column values: `f_i(x_j) + Z_n(x_j)·g_i(x_j)`, `j ∈ J`. The map
`pad_i ↦ (Z_n(x_j) g_i(x_j))_{j∈J}` is `diag(Z_n)·Vandermonde` of rank `|J|`
(`Z_n ≠ 0` on the coset, distinct points), so the opened column values are
uniform and independent of `f_i` **and of the mask rows' values**, hence of the
message parts of the vectors. The folded pads: `fold_g = Σ_i ρ_{g,i} pad_i`.
Given the columns, `g_i = interp_J(target_i) + Z_J·h_i` with `h_i` uniform of
degree `< q_pad − |J|`, so `fold_g = interp_J(Z_n^{-1}(Σ_i ρ_{g,i} col_i − (Σ_i ρ_{g,i} f_i)(x_J))) + Z_J·Σ_i ρ_{g,i} h_i`;
the only data-dependent term is `(Σ_i ρ_{g,i} f_i)(x_J)`, which is the
**public** message part `v_g[..n]` interpolated at `x_J` (this identity is the
verifier's own coset-encoding check). So `(columns, folded pads | message
parts)` has the same law for every data and for A′. Exact check: `pad_budget`
(`|J| ≤ q_pad` ⇒ 0 leaked; `|J| = q_pad + 1` ⇒ exactly 1 functional of the row
in the clear; duplicates only shrink J).

**Step 11 — the plain W opening (P1).** Public data, honest algorithm.
Identical.

**Step 12 — output.** The transcript so produced verifies (every check is an
identity Sim arranged) and is distributed as the honest one up to the events of
§B.7.

### B.3 Why the programming is consistent

Sim programs exactly `n_sq = Σ_s N_s` points per proof: the squeezes that
follow a `sc-round` absorb. The state after absorbing round j of slot s is
`blake3(… ‖ A root ‖ … ‖ h_j)` — a chained oracle output whose preimage contains
the A root, itself a Merkle root over fresh 256-bit salts; before the proof is
published the distinguisher can have queried that state's squeeze point only
by guessing (a fresh salt or the state itself): probability ≤ `q_H/2^256` per
programmed point. Sim never programs two different values at one point (the
states are distinct along one transcript: the counter advances and the states
chain), never programs a point it has already answered, and never programs a
Merkle or leaf hash. The verifier, recomputing the challenges from the proof,
obtains Sim's values. Two proofs of the same statement share the prefix up to
the first fresh root (header; W root under P1) and diverge at the A root
(distinct salts ⇒ distinct roots except with probability `≤ 2^-256`), so their
programmed points are disjoint.

### B.4 The M-root question, restated

FA3 B2 and FA6 §7.4(b) framed the difficulty as: the M root is absorbed before
`c`, and the committed a-rows "cannot satisfy the functionals that are fixed only
after M". §B.2 steps 6–7 show that the functionals' **values** — `G_s` and
`g_s(ρ_s)` — are functions of `(M, ρ_s)` alone in both worlds; what the honest
data determines is the *f-part* of the round messages, and the round messages
are the one object Sim samples instead of computing. Because Sim knows `ρ_s`
before emitting the rounds (programming), it can sample them on the fibre that
lands on the true `g_M(ρ_s)`. The single `mask_open` is then honest. Nothing is
equivocated, the salted-leaf oracle is never programmed, and the simulator's
only oracle interventions are the `n_sq` round-challenge points.

### B.5 The terminal relation composed

For each slot, honestly: `fin = f_ext(ρ) + c·g(ρ)` and the verifier's
`want(m_t)` equals `f_ext(ρ)` by the extension-round identity
(`masked_terminal`: `m = (1 − e)·fin_t + e·ext_t`, so the relation polynomial on
the masked terminals is the extended polynomial at `(ρ, e)`; FA6 §1.1). In Sim:
`fin := want(m′_t) + c·g_M(ρ)` with `m′_t` A′'s masked terminals. In both worlds
`(m_t)` is uniform `F_{p²}` per terminal and jointly with the vectors uniform on
the L1 space, `(claim, fin)` is uniform on `F_{p²}²`, and the rounds are uniform
on the fibre. The link `g(ρ) = (fin − want(m_t))/c` is the same deterministic
function of the view in both. Under P1 the W evaluations inside `want_gu`,
`want_d` are public and identical; under P3 they are masked W terminals from
W′'s pairs, handled by L1 on W′.

### B.6 The P3 variant with a fresh W commitment

Add to step 2 a commitment W′: zero data rows, one repaired pair set (`w_mgu`
pairs, `w_mdd` pairs, `w_prox` pair), fresh pads (`q_pad = Q`) and salts; root
absorbed at step 1's position. The matmul slots have two extension rounds
(`e`, `e2`, both programmed); the W-side pair coefficient is `k1 = e2` and the
data coefficient `(1 − e2)(1 − e)` (FA3 §12.3); `e2 = 1` is refused. Step 8 opens
W′ first (order W, A, H), with L1 on W′'s two groups (FA3 `whole_W_p3_n4_*`:
0; `k_slots` case "one proof, one slot": `disclosed 0`, rank 26 = 26 at n = 4).
Everything else is unchanged. The shared cross-role coefficient FA7 §3 recorded
(`k_gu.0` equal on A's p2 claim and W's p3 claims) is a shared *function* of
public challenges over disjoint unknowns — it does not couple the two covers.

### B.7 The single-proof distance, derived

Let `q_H` be the distinguisher's oracle queries, `n_sq = Σ_s N_s` the programmed
round challenges, `n_leaves = nn_A + nn_H (+ nn_W) + 4096` the salted leaves,
`n_rng` the OS-keyed streams (1 per component per attempt), `N_fp` the number of
base-field mask and pad draws of the proof, and

`δ_deg = 2·n_pair·2^-128 + n_slots·2^-128 + (n_prox_pairs + n_block_slots)·2^-64 (+ n_pair,P3·2^-128)`

the probability that a challenge lands in FA3 §6.5's refused set
(`λ = 0` or `k1 = 0` per pair claim; `c_s = 0` per slot; the two prox ρ's
F_p-dependent — exactly `(p³ + p² − p)/p⁴ ≈ 2^-64`; a block slot's row-bit
coordinate in F_p — `1/p`; `e2 = 1`). Then

> **Δ₁ ≤ δ_deg + q_H·(n_sq + n_leaves + n_rng)/2^256 + N_fp·2^-95.**

Term by term: `δ_deg` — the honest prover discards and Sim aborts on the same
public event, so for *published* proofs it contributes nothing to the distance;
it is a completeness loss (FA3's "≈ 2^-62 per proof") and it is kept in the
bound because a resample-instead-of-refuse implementation would turn it into a
distinguishing event (§D.1). `q_H·n_sq/2^256` — §B.3. `q_H·n_leaves/2^256` —
the salt-query event for unopened columns of A, H, (W), M (§B.2 step 2).
`q_H·n_rng/2^256` — guessing a stream key (H3). `N_fp·2^-95` — every mask row
entry and pad is `fp()` = a 128-bit draw reduced mod p; §D.4 derives its
distance from uniform as `m(p − m)/(p·2^128)` with `m = 2^128 mod p = p − 2^32`,
i.e. `2^-96(1 − 2^-32)`, and a one-time pad drawn this way hides an addend up to
twice that; Sim may draw its masks the same way, in which case this term is
zero, but the *hiding* statements of L1/L2/G1 are exact only for uniform masks,
so the bound keeps it. Column duplicates contribute **0**: they shrink J
(L2) and are serialised as such. `|F_{p²}|` enters as `2^-128 = 1/|F_{p²}|` and
`2^-64 = 1/p`.

Numbers (block-profile row counts from FA3 §8 / the schedule JSON; `n_sq` from
FA6's slot table, summed in the record's `counts`):

| Shape | `n_sq` P1 / P3 / block | `n_leaves` (P1) | `N_fp` (P1 block, upper bound incl. M) | `N_fp·2^-95` | `δ_deg` |
|---|---|---|---|---|---|
| A00 T32/d16/f16, lc 8, rate 8, Q 256 | 56 / 58 / 76 | 2·2048 + 4096 = 8192 | 1.05·10⁶ | 2^-75.0 | 22 pair claims, 6 slots, 2 prox pairs, 2 block slots → ≈ 2^-62 |
| 125M, lc 14, rate 4 | 83 / 85 / 111 | 2·65536 + 4096 | 4.65·10⁶ | 2^-72.9 | ≈ 2^-62 |
| 8B, lc 14, rate 4 | 92 / 94 / 128 | 2·65536 + 4096 | 1.06·10⁷ | 2^-71.7 | ≈ 2^-62 |

With `q_H = 2^80`: `q_H·(n_sq + n_leaves + n_rng)/2^256 < 2^-158`. The bound is
dominated by `δ_deg` (completeness) and, for the accepted-view distance proper,
by `N_fp·2^-95 ≈ 2^-72`. If a tighter accepted-view number is wanted, the prover
can draw masks by rejection sampling (exactly uniform) and the term vanishes;
this is a one-line change in `ZkRng::fp` that Codex may weigh against the
CPU/GPU parity fixtures.

### B.8 What the argument assumes about the code (conditions)

| Id | Condition | Where it comes from | Status at `ed478da` |
|---|---|---|---|
| C1 | every mask row is drawn before its commitment exists and enters exactly one opening; roles are disjoint; the verifier builds every claim from the layout | FA3 §3, §4.2, §6.3 | legacy: yes for its rows; repaired: not implemented (S3) |
| C2 | the repaired kinds: pair for every single-row site, prox pair, block slots only at `rows_i ≥ 2`, seam pairs | FA3 §2 | not implemented (B5/S3) |
| C3 | every message is absorbed before the challenge that depends on it; the order of FA3 §12.2 | G6, G7 | legacy verified (FA5 §4.5); repaired: to implement |
| C4 | degenerate challenges refused, never resampled (`λ = 0`, `k1 = 0`, `e2 = 1`, prox pair dependent, block row bit in F_p, `c_s = 0`) | FA3 §6.5, FA6 I3 | `c = 0` refused by the verifier's `div`; the rest: to implement; prover abort on `c = 0`: hardening S2 |
| C5 | extension-round mask degree = round degree (else the top values of `s_k` are clear) | FA6 I1 | true by construction, not asserted (S2) |
| C6 | one `mask_open` per `MaskCommit`, one θ | FA6 I5 | yes (`zk.rs` 3136) |
| C7 | one OS stream per component per attempt; an explicit seed refused outside `cfg(test)`; no `--wcache` under P3 | FA6 I4, FA3 §3 | `from_os` yes; the seed path is reachable (S1); wcache refused (`zk.rs` 2450) |
| C8 | exact counts everywhere; nothing published on failure | FA3 §6.8–6.9 | to implement (S3); R32 closed on the attention side by Codex `42471f0` |

## C. The entire composition schedule (block profile)

### C.1 The block's honest view (FA3 §12.2)

1. block header; 2. attention W root, A root, M root; FFN W root, A root, M
root; 3. FFN β γ α → FFN H root; attention helpers after their challenges;
4. FFN arguments in legacy order (every masked claim and terminal absorbed
before the next challenge); attention arguments in A01's 13-section order in
their private form (A04–A06); 5. seam X: `τ_sx, c_sx → γ_sx →` masked rounds
`→` masked terminals (FFN side, attention side) `→ e_sx`; seam Z likewise;
6. FFN `mask_open` (slots 1–6, [7 pred], 7–8 seams), attention `mask_open`;
7. openings: FFN W (P3), FFN A, FFN H, attention W (P3), attention A, attention
H.

### C.2 Extending Sim

- **FFN component:** §B unchanged; A′ carries the seam pairs `a_sx[c]`, `a_sz[c]`
  and the M the two seam slots `(log_t + log_db + 1, 2)` (FA6 §6).
- **Seams:** zero-claimed slots with `Γ_s = c_s·G_s` (true total of the FFN M);
  the `log_t + log_db + 1` round challenges programmed (`e_sx` is the extension
  challenge; `e_sx = 0` refused, `private_seam.rs` 394/452); the FFN-side
  terminal `seam_x.term_ffn[c] = k1·S_sx[c](tail ρ_sx)` from A′'s seam pair, the
  attention-side terminal from the attention component's reserved pair
  `SeamXm8[c]` on **its** A; `want_s = (1 − e)·eq(τ_s, ρ)·Σ_c λ_c(m^ffn_c − m^attn_c)`;
  rounds on the fibre. L1 covers the FFN side (FA3 `whole_A_n4_*_seams`: X under
  three pairs, 0) and G1 the slot (FA6 §6, rank = dim S at 6/10/14/18
  variables). The attention side needs its own L1 — **A3**.
- **Two `mask_open`s:** each honest on its own M (I5 per component).
- **Six openings** in the fixed order; the FFN three by §B step 8; the
  attention three need the attention schedule — **A1**.
- **Programming count:** `n_sq(block) = n_sq(FFN) + n_sq(attention) + 2·(log_t + log_db + 1)`:
  76 for the FFN + seams at A00 (128 at 8B) plus the attention side's (A2).

### C.3 Every observation channel of the block

| Channel | Verdict | Basis / blocker |
|---|---|---|
| FFN CFS rounds, claims, Γ's, derived `g(ρ)`; FFN M opening | accepted | §B steps 6–7; FA6 §7.1 |
| FFN A/H (W) group vectors, terminals, prox, columns, pads, roots | accepted | §B steps 2, 5, 8, 10 |
| seam slots' rounds and Γ's | accepted | FA6 §6 (approved as specified), §C.2 |
| seam terminals, FFN side `seam_x.term_ffn[c]`, `seam_z.term_ffn[c]` | accepted | FA3 §9 `whole_A_n4_*_seams`, pair rows `a_sx`, `a_sz`; L1 |
| seam terminals, attention side `SeamXm8[c]`, `SeamZ16c[c]` | **blocker A3** | no inventory row, no pair schedule, no joint rank with the attention's own openings of `xm8`/`z16c` (FA6 §4 last row; FA7 §4) |
| attention CFS slots (rounds, claims, M opening) | **blocker A2** | `(n_vars, degree)` per slot, extension degrees, batched forms, `mask_functionals` order not specified (A04–A06) |
| attention A/H (W) vectors, terminals, prox, columns | **blocker A1** | no FA3 §2.2-style schedule; every attention claim needs a row and a whole-commitment rank of 0 |
| the residual seam between blocks; the chain transcript | **blocker A4** | FA3 §4.5 reserves the role; slot, pair rows and chain order unwritten (FA4 H7) |
| the public statement (header, contract digest, request context, roots, I/O binding R27) | accepted | public by definition; request binding is a caller obligation (FA4 M13) |
| repeats across blocks / layers | accepted for the FFN side under F1; the stable W under F2's enforcement | §F |
| ranges | as §E per side | |
| side channels | listed, X1 | §E.3 |

### C.4 What the attention side must supply before the block simulator closes

1. **A1 — a mask schedule and observation inventory** in FA3 §2.2's form for
   every attention claim (site, group key, m, rows, kind ∈ {pair, block,
   zero_sum_pair, prox_pair}, coefficient pair per privacy mode, proof field),
   including the reserved `SeamXm8[c]`, `SeamZ16c[c]` and residual-seam roles;
   with FA2's tool run in `repair` form on the whole attention A/H (and W under
   P3): `disclosed_dim = 0` on every group and on the whole commitment, and the
   H-side residual equal to the public identity if attention LogUp helpers are
   committed in a hiding H.
2. **A2 — a CFS slot table** under FA6's criterion: `(n_vars, degree)` per
   attention slot, extension degree = mask degree in every round, the
   claimed-sum form (private sum + `cG` / batched Γ / public constant + `cG`),
   the M slot order and `mask_functionals` order, rank = dim S for every slot
   and every batched pair; `L_s + 256 ≤ 512` per slot.
3. **A3 — the attention-side seam terminals** as reserved pair rows of the
   attention A at `tail(ρ_sx)`, `tail(ρ_sz)`, inventoried jointly with the
   attention's own openings of the `xm8` and `z16c` rows (the same rows under
   several masks, FA3's pair-per-site rule), and a place in FA7's schema-2
   capture (FA7 §10, "Seam slots").
4. **A4 — the residual seam** (`xres2(k)` vs `x_in(k+1)` between the two
   attention A's), its slot and pair rows, and the chain-level transcript order
   (block headers, per-block roots, the seam's position), so that the
   k-block simulator is §B applied blockwise with fresh commitments per block.
5. **Transcript order** of the attention arguments with every masked claim and
   terminal absorbed before the next challenge (so that only round challenges
   need programming), and the same reserve-before-commit / one-opening
   lifecycle (FA3 §4).

With A1–A4 delivered, the block simulator is §B run on both components with
the seams as in §C.2 and the bound of §B.7 with the block's counts.

## D. Failure, retry and entropy; the hash assumptions

### D.1 What the honest prover does

- **A refused draw** (FA3 §6.5's set; `c_s = 0` after FA6 I3): the attempt is
  **discarded** at `argue` (state `Discarded`; the RNG instance and every mask,
  pad, salt and CFS coefficient die with it). No bytes leave the process; a
  partial transcript is not a receipt (FA3 §4.4). The event is a function of
  public challenges, so Sim aborts on it identically and it is a completeness
  loss `δ_deg` (§B.7), not a distinguishing one.
- **A retry** is a **new attempt**: a new attempt nonce, a new OS-keyed stream
  (`ffn-mr1/layer-{l}/attempt-{nonce}`), new A/H/M/(W′) commitments, new pads and
  salts. Under P3 stable W the failed attempt's slot is **burned** (FA3 §12.3;
  the journal never refunds, Codex H2), and the retry takes the next slot.
  Never a resample loop on the same masks.
- **The device attempts** of the legacy prover (`clone_state` sites) re-run the
  same deterministic sumcheck on a cloned transcript and absorb nothing on a
  decline (FA6 §5) — no reuse; the repaired lifecycle inherits this only if the
  clone never leaves the process.
- **The verifier** refuses, never resamples (FA3 §6.5), and publishes nothing on
  failure (§6.9).

### D.2 What a violated rule leaks

- **Resample instead of refuse:** the accepted transcripts are then conditioned
  on a mask-dependent event (e.g. `k1 ≠ 0` re-drawn until the *same* masks
  work), which biases the masked values; more concretely a second attempt on
  the same masks with fresh challenges is a mask reuse: FA6
  `nc_mask_reuse_fresh_challenges` (`N·d` functionals of the two data's round
  messages per slot), `nc_qprime_two_openings_same_M` (every CFS coefficient),
  and for the PCS side FA2 fixture (d)/AM4 (the pair cancels between two
  openings and the data difference is in the clear). §F.2's exact check shows
  the P3 W version: a slot declared twice discloses 12 base functionals at
  n = 4 (one per block per column — FA4 §5.1's "difference of two W
  evaluations"), touching every W block.
- **Reusing a stream** (same key and domain in two attempts, or an explicit
  seed): every mask, pad, salt and CFS coefficient repeats; two proofs of
  different data leak the whole difference (FA6 §5; FA2 §17.1); the identical
  M/A roots are visible to anyone holding both proofs (FA4 M15/M16).
- **Slot reuse under stable W:** §F.2.4.

### D.3 `layer_rng`'s explicit-seed path

`ZkConfig::rng` (`zk.rs` 334–340) returns `ZkRng::new(seed, domain)` whenever
`cfg.seed` is `Some`. This is a **public** `ZkConfig` field, reachable from any
caller, not a `cfg(test)` hook. Under it the entire randomness of the proof is
a deterministic function of `(seed: u64, layer)` — and a `u64` is
brute-forceable: from one proof, `2^64` candidate seeds each reproduce the M
root (a hash of `mask_commit`'s output) and the match reveals every CFS
coefficient, pad, salt and mask row, i.e. the whole witness through the clear
`f = h − c·g`. Seeded proofs are therefore **not** a privacy mode at any seed
value, and `randomness_label()` ("deterministic-test") is not in the proof, so a
verifier cannot tell. Requirement (FA6 I4 clause 2, FA3 §3, restated as
blocker **S1**): the repaired block API takes no seed; if `ZkConfig` keeps the
field for fixtures, `ZkRng::new` must be unreachable outside `cfg(test)` or the
prover must refuse `Some(seed)` with a typed error under the repaired profile;
the seeded CPU/GPU parity fixtures never carry private data (FA6 I4 clause 5).

### D.4 Hash and entropy assumptions, stated

| Id | Assumption | Exact use | Failure event and its bound |
|---|---|---|---|
| H1 | blake3 is a programmable RO for the transcript | Sim programs `n_sq` squeeze points per proof; all other challenges honest | prior query of a programmed point: `q_H·n_sq/2^256` |
| H2 | blake3 is an RO for `hash_column`, `salt_leaf`, Merkle nodes; salts are 32 fresh bytes | hiding of the `nn − |J|` unopened columns per commitment; opened columns reveal their salt and are pad-uniform (L2) | a query containing an unopened column's salt: `q_H·n_leaves/2^256` |
| H3 | keyed blake3 XOF is pseudorandom under a 256-bit key from `/dev/urandom` | `ZkRng::from_os`; the domain names profile, layer, attempt | key guess: `q_H·n_rng/2^256`; a broken entropy source is not repaired by the attempt nonce (the nonce separates attempts only when the source is sound) |
| H4 | domain separation | `hashline-v1/` + `hashline-zk-mr1/` + caller domain and the `HL-ZK/2` header (profile, layer, slot, block context) separate profiles, layers, slots and requests in the transcript; `layer-v3-{l}` / `ffn-mr1/layer-{l}/attempt-{nonce}` in the RNG; the four RO uses have distinct prefixes | none needed for the distance: distinct proofs diverge at the fresh roots regardless; the domains prevent *identical* transcripts for identical inputs |
| H5 | `fp()` reduction | every mask, pad and challenge coordinate | exact: `2^128 ≡ p − 2^32 (mod p)`, so `SD(x mod p, U) = m(p − m)/(p·2^128) = 2^-96(1 − 2^-32)` with `m = p − 2^32`; a pad shift is bounded by `2^-95`; challenges are programmed as 256-bit RO outputs and reduced by the verifier identically in both worlds (no term). The source's "bias 2^-64" is a loose bound |
| H6 | `challenge_indices` | 64-bit words masked to `bound − 1`, with replacement | exactly uniform; duplicates shrink J |

The salt length (256 bits), the leaf construction (salt appended after the
column hash, so a low-entropy column is still hidden by the salt) and the
Merkle arity are read from `pcs.rs`/`merkle.rs` at the pin. The **approver E**
of FA4 §4.1 recomputes `C*_l` from O's randomness: E is trusted with W anyway;
the manifest's root is hiding to everyone else by H2.

## E. B3 — ranges and nonlinear side information

### E.1 The repaired profile, given B1/B2

If the view of a proof (or of k proofs, §F) is within `Δ` of a distribution
Sim produces **without the witness**, then for every function `A` of the view —
a bounded-integer solver, a lattice reduction, a range check on recovered
functionals — `A(view)` is within `Δ` of `A(Sim's view)`, which depends only on
the public statement. Integer ranges of the committed planes (int8 X, int16
h16/z16, the remainder windows, the multiplicities) are therefore not a channel
in the repaired profile: there is no functional of the data in the clear for
them to sharpen (FA3 §9: zero linear residual; FA6: zero CFS residual; §B: the
whole view uniform on data-independent spaces). Three caveats, none a leak:
(i) the statement itself carries what it carries (shifts, table digests, the
public W under P1, the LogUp identity's value 0, the seam relation's constant
0, the slot index under stable P3, the external I/O words of R27); (ii) the
`Δ` of §B.7 is statistical, so a `2^-72`-advantage adversary is not excluded by
the bound as written (§B.7's rejection-sampling remark removes that term);
(iii) "given B1/B2" means given C1–C8 — a violated condition re-opens exactly
the channel it guards, and ranges then amplify *that* (D.2).

### E.2 The legacy profile, quantified

FA7 measured the disclosed space; ranges make it worse than "functionals":

- **T2 (n = 32, one row per plane):** X and h16 rows recovered whole from one
  proof (FA7 §7) — ranges add nothing, there is nothing left.
- **T32 (n = 256, two rows per plane):** per column the singleton groups
  disclose one base-field functional `w_0·X[0][j] + w_1·X[1][j] = t_j (mod p)`
  with public `w_r = L_b(λ·coef_d·eq_r) ∈ F_p` (FA7 §7). With
  `X[·][j] ∈ [−128, 127]`, the equation has a **unique** solution in the box
  unless `w_0/w_1 ≡ (b′ − b)/(a − a′)` for some `|a − a′|, |b′ − b| ≤ 255` — at
  most `2^16` ratios out of `p`, probability ≈ `2^-48` per column. So a `2^16`
  enumeration (or a two-dimensional CVP) per column returns **both X rows
  exactly from one proof**; for h16 (`[−32768, 32767]`) `2^32` per column with
  failure ≈ `2^-32`. FA7's "one functional of the two rows per column" is, with
  ranges, the whole T32 X and h16 planes.
- **The all-base group functionals** (2 per group per proof, mixing every
  member's entries) are one exact equation each in `7·nb_f·rows_f·n` (rho_f) or
  `3·nb_d·rows_d·n` (rho_d) small integers; alone they are underdetermined, but
  they are exact, they accumulate at 2 per proof of the same witness (FA2
  §17.1; FA7 found ten proofs of one X in the captured set), and each removes
  ~64 bits of the plane's entropy (`≤ 16·3584 ≈ 57` kbit at T32 rho_f) — a
  bounded-integer attack in the hundreds of proofs, a lattice attack in
  dimension 3584 at the boundary of practicality; neither is needed for the
  verdict, which FA7 already gave.
- **P3 W:** the whole Wd plane at T32 from one proof; the (Wg, Wu) column pairs
  from two (FA2 §17.1(iii)); weights are int8 — the range makes the Wg/Wu
  recovery from a single proof's per-column functional a `2^16` enumeration as
  for X.

### E.3 Beyond the model — listed, not hand-waved

- **Proof size.** `LayerProofZk::to_bytes` writes fixed-count fields whose
  lengths are functions of the layout (`rows`, `groups`, `n + q_pad`, `Q`,
  `N_s·(d_s + 1)`, the terminal counts, the `pred` option decided by the
  statement); `zk_proof_size.rs` counts "the actual fields written … without
  inspecting field values", and its tests pin plain-vs-salted framing and
  duplicate indices as serialised twice. The size is therefore a function of
  (statement, params, mode) only and is **not** a channel. (Derived from
  `OpeningZk::write_bytes`, `pcs.rs` 543–566, and the size module; not a claim
  of CL19's beyond that.)
- **Prover timing and memory** (the host/device path choice `use_dev_h`, the
  pool drains, a declined device attempt printed to stderr) depend on shape,
  not data, in the source read; an implementation that branched on data
  values would be a timing channel — out of this model.
- **The driver's `sites` / `timings` / `randomness_label`** are not part of the
  proof and must never be published with it.
- **The registry's optional `(D_M, l, i)` double-use log** (FA4 §4.3 (8))
  reveals proof counts per model and layer — a product decision.
- **Request binding** (M13) is a replay question, not a privacy one.

These are **X1** in the disposition.

## F. B4 — cross-proof correlation

### F.1 Fresh P1, and P3 with a fresh W commitment

Claim: the view of k proofs `π_1, …, π_k` (of the same or different data, same
or different statements) is within `k·Δ₁` of k independent runs of Sim.
*Argument (hybrid).* `H_0` = all honest, `H_i` = the first i proofs by Sim.
Between `H_{i−1}` and `H_i` only proof i changes; every object of proof i —
A_i, H_i, M_i, (W′_i), their pads, salts, mask pairs, CFS coefficients — is
drawn from a fresh OS stream (G8/C7), so it is independent of proofs `≠ i`
given the public statements; the transcript of proof i shares with the others
only the public prefix (header, public W root) and diverges at A_i's root, so
its programmed points are distinct (§B.3); the pads of proof i's commitments
are opened only in proof i. Hence proof i's view given the others is exactly
the single-proof view and §B applies: `|H_{i−1} − H_i| ≤ Δ₁`. Summing,
`Δ_k ≤ k·Δ₁`. Assumptions: fresh `ZkRng` streams per attempt, no `--wcache`
(refused under P3, `zk.rs` 2450–2455; under P1 the cache is a public
commitment), no shared pads or salts across proofs, no seed. The only
cross-proof link is the public statement (and, in the block chain, the public
I/O binding). This is FA2's U7 and FA6's B4 remark ("under I4 the CFS views of
different proofs are independent uniform"), now with the PCS side.

### F.2 FA4's budgeted stable W: `C*_l`, k slot sets, `q_pad = k·Q`

#### F.2.1 The statement being simulated

The verifier's view includes the **manifest root `C*_l`** produced at
registration, then k proofs `π_1..π_k` each declaring a slot index. So the
object to simulate is the joint `(C*_l, π_1, …, π_k)`; the simulator starts at
registration.

#### F.2.2 Sim_k

- **Registration.** Sim commits once to `W*′`: zero data rows; **k repaired slot
  sets**, each `(w_mgu pairs, w_mdd pairs, w_prox pair)` uniform; pads with
  `q_pad = k·Q` per row (`n + q_pad ≤ nn`, the changed W rate per FA4 §5.1);
  fresh salts; root `C*′`. The manifest carries `C*′` (Sim plays O toward the
  distinguisher; E's recomputation is out of the distinguisher's view — E holds
  W by construction, FA4 §4.1).
- **Proof i on slot `s_i`** (all `s_i` distinct, `< k`): §B.2 with W′ replaced by
  `W*′` and the W claims built from slot `s_i`'s rows (the verifier builds them
  from the header's slot index, FA3 §12.3); the W opening opens `Q` columns of
  `W*′` with their salts and paths; the W group vectors have length `n + k·Q`.
  A_i, H_i, M_i fresh per proof as in F.1.

#### F.2.3 Why the k views are distributed as the honest ones

Per proof, the FFN side (A_i, H_i, M_i, the sumchecks) is F.1. The W side across
all k proofs:

- **Group vectors and terminals (Lemma L1 per slot).** Proof i's two W groups
  use slot `s_i`'s pairs; those pairs enter proof i's vectors and terminals and
  **no other proof's vectors or terminals**. L1 applies per proof with the
  slot's pairs as the covering masks (FA3 §12.3, `whole_W_p3_n4_*`).
- **Proximity vectors.** Proof i's prox vector is `Σ_{all rows r} ρ_{i,r} M[r]` —
  it touches the data rows and **every** slot's pair rows (the folding is over
  the whole commitment, `zk_rhos`). It is nonetheless uniform per column
  independently of everything else, because slot `s_i`'s **prox pair** appears
  in proof i's prox vector and nowhere else in any proof, and its two ρ's are
  F_p-independent (refused otherwise). The other slots' rows it touches are
  either unused (uniform, their contribution is absorbed) or used by other
  proofs' vectors — but those are covered by their own slots' pairs, and the
  joint map remains block-triangular. Exact check: `k_slots` — two and three
  proofs on distinct slots, and three slots with slot 1 burned (proofs on 0 and
  2): `disclosed_dim = 0`, `rank_mask = rank_joint` (52, 78, 52 at n = 4; 100 at
  n = 8 with single-row blocks), trivial identities exactly `4·k` (two groups per
  proof, two base rows each).
- **Opened columns and folded pads (Lemma L2 with the union).** Per row, let
  `J = ∪_i J_i` be the distinct positions opened across all k proofs;
  `|J| ≤ Σ|J_i| ≤ k·Q ≤ q_pad`. The map `pad ↦ (Z_n(x_j) g(x_j))_{j∈J}` has rank
  `|J|`, so the column values of every row across all k proofs are jointly
  uniform and independent of the data and of the mask rows' values; each
  proof's folded pads are determined by (its public message parts, the columns)
  up to the shared kernel `Z_J·h` which is data-independent (§B step 10 with
  `q_pad = k·Q`). A position opened twice reveals the same column and salt
  twice — consistent, no new information. Exact check: `pad_budget` — k
  budgeted openings hide (`leaked = 0` at `|J| = 5, 13, 54, 7 ≤ q_pad`), one
  opening beyond the budget leaks exactly `|J| − q_pad` functionals of the row
  when `|J| > q_pad` (`1` at `|J| = 7 > 6` and `17 > 16`), and duplicates shrink
  J (`54 ≤ 64` even with 9 openings of 8).
- **Salts and the root.** Across k proofs at most `k·Q` salts are revealed; the
  remaining leaves are hidden by H2 (`q_H·nn_W/2^256`, once).
- **CFS masks and the sumcheck terminal relations** involve W only through the
  masked W terminals, covered above; the masks are fresh per proof (I4).

So the joint law of `(C*′, π_1..π_k)` matches the honest one up to the terms
below, **provided every slot is used at most once and `|J| ≤ q_pad`**.

**Negative controls (exact, `k_slots`):** two proofs declaring the same slot —
`disclosed 12` at n = 4 (`rank_mask 40 < rank_joint 52`), one base functional
per W block per column, every block touched: the pair cancels between the two
openings and the difference of the two evaluations of each block is in the
clear (FA4 §5.1's sentence, now exhibited); three proofs with slot 1 used
twice — `12`; slot 1's rows a copy of slot 0's (a registration bug, AM4 across
slots) — `20`.

#### F.2.4 The enforcement of consumption

What the argument needs (E-conditions), and what Codex's H2 journal
(`hashline/src/stable_weight_slots.rs`, `ZK60_STABLE_WEIGHT_SLOTS.md`,
`ZK60_ROUND12.md`) enforces today:

| Id | Needed | Enforced by the H2 journal at `972da4e`? |
|---|---|---|
| E-a | each slot index declared in at most one transcript that ever leaves the prover (its rows enter vectors/terminals/prox only once) | **partly**: `reserve()` returns strictly increasing indices, appends and syncs before returning, refuses at `budget`; `ReservedSlot` is non-Clone with an exclusive borrow (compile-fail pinned). **Not**: nothing forces the prover to declare the reserved index — no prover consumes the token yet ("no existing prover or verifier consumes slots yet") — **E1** |
| E-b | a failed attempt burns its slot | **yes** for the reservation: drop, panic, process death never refund; a complete record left by a dead process is burned on reopen; a torn tail refuses the journal |
| E-c | no `open_zk` on `C*_l` outside a reservation | **no** — the consuming API is H3 (**E1**) |
| E-d | the k pair sets and `q_pad = k·Q` are those of the committed `C*_l`; the manifest's k equals the budget | **partly**: `SlotPolicy` checks `q_pad = budget·Q`, `n + q_pad ≤ nn`, geometry, a canonical coset, and binds manifest/layout/root digests into the header; it does not construct or verify the commitment (**E2**) |
| E-e | the secret material (data, pads, salts, mask rows) is reconstructed byte-identically per proof | **no** — not stored by H2; a mismatch is caught by the verifier (`root ≠ C*_l`) as a completeness failure, not a leak, but the storage boundary is unwritten (**E2**) |
| E-f | one canonical journal per commitment; no rollback to an earlier valid prefix | **no**, by contract: checksums detect corruption, not rollback; `create` at a second path with the same policy succeeds; a restored backup reuses slots undetected — needs an external monotonic authority or the registry's double-use record (**E3**) |
| E-g | exclusive access while proving | **yes**: exclusive OS lock, `Busy` for a second handle, released on death; advisory on the local filesystem (trusted, Linux/WSL tested) |
| E-h | the verifier cannot detect reuse | true by design (FA4 G4): two proofs with the same slot both verify; enforcement is prover-side plus the optional registry |

The public half of consumption is therefore in place and tested (drop /
unwind / restart / exhaustion / torn tail / competing processes, round 12);
the binding half (E1), the secret half (E2) and the anti-rollback half (E3)
are not, and the journal's own documents say so. **Until E1–E3 land, the
argument of F.2.3 is conditional and the stable-W profile's W channels are
blocked, not accepted.**

#### F.2.5 The bound, as H1 requires, as a function of (n, q_pad, nn, Q, k)

> **Δ_k(stable W) ≤ q_H·nn_W/2^256 + Σ_{i≤k} Δ₁(i) + ε_pad + N_fp(C*_l)·2^-95, with
> ε_pad = 0 if k·Q ≤ q_pad (and every slot used once), and otherwise
> `|J| − q_pad` base-field functionals of every W row in the clear;
> the condition `n + q_pad ≤ nn` is geometry, and the soundness distance of the
> W code is `1 − (n + q_pad)/nn` (FA5's bound, E4, not a privacy term).**

`Δ₁(i)` is §B.7's with the P3 counts (`n_sq` 58/94 at A00/8B, `n_leaves`
including `nn_W` only once); `N_fp(C*_l) = rows_W·(n + k·Q)` (at 8B,
`(10752 + k·22)·(2^14 + 256·k)`: `≈ 2^28.6` at k = 16, bias term `≈ 2^-66`);
`n` enters only through these counts and the soundness distance; `Q` and `k`
through `|J| ≤ k·Q`. The exact-rank part of H1 ("joint base-field mask rank of
the W group vectors with budgeted mask rows") is `k_slots`; the pad part is
`pad_budget`; the simulator is F.2.2–F.2.3; the changed-rate proximity bound is
E4.

#### F.2.6 Residual blockers of F2

E1 (consuming API, header/claims from the reservation, failed attempts burn),
E2 (secret material + deterministic reconstruction bound to the policy
digest), E3 (anti-rollback / single canonical journal / registry double-use),
E4 (FA5's number for RS[nn, n + kQ]), B5/S3 (the repaired W pair sets exist only
on paper), and the product ruling on how many proofs per registration the
budget must cover (k vs. re-registration, FA4 §5.3).

## G. Disposition

Machine-readable mirror: `results/zk60_fable_fa8_disposition.json`
(`channels` × `profiles`, `blockers`, `bounds`, `counts`). Legend: **A** =
accepted by argument (cite), **L** = leaks (measured/derived), **B** = blocker
(ids of §H), **–** = not applicable.

| Channel | legacy v3 | repaired P1 | repaired P3 fresh W | repaired P3 stable W, k slots | block profile |
|---|---|---|---|---|---|
| CFS round messages per slot | A FA6 §2; §B.2/6 | A §B.2/6 | A (P3 second extension) | A per proof | **B A2** |
| masked claimed sums, Γ's | A FA6 §2.3 | A §B.2/6e | A | A | **B A2** |
| derived `g_s(ρ_s)` | A FA6 §2.1; L3 | A | A | A | **B A2** |
| M root, q′, prox, M columns | A FA6 §3, I5; §B.2/7 | A | A | A (one M per proof) | A per component (seam slots in FFN M) |
| A group vectors (rho_f, rho_d, p2, p5, tab, [pred]) | **L** FA7: 2n + 4 | A FA3 §9 + L1 | A | A (A fresh) | A (FA3 `*_seams`) |
| H group vectors incl. the sum claim | A (public identity only) | A | A | A | A (FFN H); attention H → A1 |
| W group vectors (P3) | **L** FA7: 2n + 2, Wd whole | – (public W) | A FA3 `whole_W_p3` + L1 | **B E1 E2 E3** | **B E1 E2 E3** |
| proximity vectors | **L** borrowed cover | A prox pair (L1) | A | A (slot's prox pair covers a prox over all rows; `k_slots`) | A FFN; attention → A1 |
| terminal values per role | **L** FA7: +4 / +2 | A (rank 2m + 2n − 2; §B.5) | A | A | A FFN; attention → A1 |
| sampled columns, salts, paths | A FA2 §14.6 | A L2 | A | A (`|J| ≤ kQ ≤ q_pad`, `pad_budget`), conditional on E1–E3 for the count | A |
| folded pads | A | A L2 | A | A | A |
| unopened columns (roots) | A H2 | A | A | A (`C*_l` once) | A |
| seam terminals, FFN side | – | – | – | – | A FA3 `*_seams`, FA6 §6 |
| seam terminals, attention side | – | – | – | – | **B A3** |
| residual seam / chain | – | – | – | – | **B A4** |
| the public statement (identity 0, seam 0, I/O, W under P1, `C*_l`, slot index) | A | A | A | A | A |
| transcript conditioning (B2) | – (moot: leaks anyway) | A §B (round challenges only) | A | A per proof | **B A1 A2 A3** |
| repeats (B4) | **L** FA2 §17.1, FA7 §7 | A §F.1 (k·Δ₁) | A §F.1 | **B E1 E2 E3** | **B A1 E1 E2 E3** |
| ranges (B3) | **L** §E.2 (both T32 X rows from one proof) | A §E.1 | A | A given F.2's enforcement | **B A1** |
| failure / retry / entropy | **B S1** | **B S1 S2** | **B S1 S2** | **B S1 S2 E1** | **B S1 S2** |
| the profile as implemented | – (it is what exists) | **B B5 S3** | **B B5 S3** | **B B5 S3** | **B B5 S3** |
| outside the model | X1 | X1 | X1 | X1 | X1 |

Counts (from the JSON): legacy 9 A / 6 L / 2 B / 5 –; repaired P1 15 A / 0 L /
3 B / 4 –; repaired P3 fresh W 16 / 0 / 3 / 3; repaired P3 stable W 14 / 0 / 5 /
3; block 10 / 0 / 12 / 0.

**Finite rank tests and a declaration of model identity do not substitute for
the argument or for the enforcement.** The rank tools (FA2/FA3/FA7, and the
`k_slots` check here) certify surjectivity of a linear map under specific
coefficients; the argument that the *distribution* of the transcript is
witness-independent is §B/§F, and the argument that k transcripts consume k
distinct slots is E1–E3, which no rank and no manifest field can supply.

## H. What remains

| # | Item | Owner | Exact acceptance |
|---|---|---|---|
| 1 | **B5 / S3** — implement `ffn-v3-mr1` as specified (FA3 §2–§6, §12; FA6 §7.3) and capture it | Codex (source), Fable (tools) | FA3 §7 AM1–AM24 and P1–P3 green; FA7 §10 schema-2 cases 1–2 with `disclosed_total = 0` (A, W), H = the public identity; a new test that the recorded prover/verifier absorb sequence equals `transcript_order_block_profile` of the schedule JSON, label by label |
| 2 | **S1** — refuse the explicit seed in production | Codex | `ZkRng::new` unreachable outside `cfg(test)` from the repaired prover (compile-time: the block API takes no seed; or `reserve`/`prepare` returns a typed error on `Some(seed)`); a test that a seeded fixture cannot be produced through the production entry point |
| 3 | **S2** — FA6's hardenings | Codex | `assert_eq!(sk.len(), gk.len())` in `zk.rs::extension` with a test on a deliberately over-degree extension; prover abort on `c_s = 0` with an AM14-style hook test |
| 4 | **E1** — consuming slot API | Codex | `open_zk` on a `StableWeightCommitment` requires `ReservedSlot` by type; the header's `slot` and the W claims come from the token; a compile-fail for a second use of one token; a test that a panic between `reserve()` and `open_zk` leaves `used` advanced and the next proof on the next slot; the FA3 §12.3 `reserve_p3` flow |
| 5 | **E2** — secret material and reconstruction | Codex | persist/reload of `C*_l`'s (data, pads, salts, k slot sets) bound to the `SlotPolicy` digest; byte-identical root after reload; refusal on a policy mismatch |
| 6 | **E3** — anti-rollback / single canonical journal | Victor (product ruling), Codex (hook) | either an external monotonic authority the prover must consult before `reserve` (a test that a restored earlier journal is refused) or the registry's `(D_M, l, i)` double-use record with a documented response; until then the stable-W profile is not deployable |
| 7 | **E4** — the changed-rate bound | FA5 / Fable | a stated proximity-test error for RS[nn, n + kQ] at the chosen (k, inv_rate) in FA5's table, with the interleaved-code regime named |
| 8 | **A1–A4** — the attention side | Codex (design), Fable (review) | §C.4 items 1–5: schedule table + FA2 `repair` run at 0; FA6-criterion slot table; seam terminals as pairs in FA7's schema 2; the residual seam and chain order; the transcript order with terminals before challenges |
| 9 | **k-proof capture** | Codex (hook), Fable (tool) | FA7's tool extended to consume k schema-2 captures against one `C*_l` root with slot indices, asserting joint `disclosed_total = 0` on W across the k proofs and `> 0` under a forced slot reuse (the `k_slots` model on real coefficients) |
| 10 | **Accepted-view bias** (optional) | Codex | if a tighter than `2^-72` accepted-view distance is wanted: rejection-sampled `fp()` for masks and pads, or an explicit statement that `2^-95` per draw is the accepted bound |
| 11 | **X1** — side channels | product | out of this model; listed in §E.3 |

### H.1 Reviewer, pins, files, commands

- **Reviewer:** Claude Fable 5.1, independent privacy reviewer; this document,
  the tool, the tests and the two records are the deliverable of FA8. No
  source under `hashline/`, `zkp-core/`, `codex-audit-*`, FA2–FA7's files was
  edited.
- **Pins:** `ed478da` (worktree HEAD; FA6 + FA7 + Codex `972da4e`); FA6/FA7 read
  the same `sumcheck.rs`, `zk.rs`, `pcs.rs` bytes (hashes in the header);
  `ZK60_ROUND12.md` read from the main tree at `972da4e`.
- **Input hashes (SHA-256):** `ZK60_FABLE_MASK_REPAIR.md` `0df12a98…5c85e74`;
  `ZK60_FABLE_CFS_CHANNEL.md` `840be7ce…c5941de7`;
  `ZK60_FABLE_CAPTURE_REVIEW.md` `b3edda40…30ac43`;
  `ZK60_FABLE_MODEL_IDENTITY.md` `8e8c13d9…d381e9aae`;
  `ZK60_STABLE_WEIGHT_SLOTS.md` `4ac88f5d…c41b08c8`;
  `results/zk60_fable_fa3_mask_schedule.json` `7cf0d795…03785a2`;
  `results/zk60_fable_fa6_cfs_channel.json` `3018cae2…783d0`;
  `results/zk60_fable_fa7_joint_captures.json` `92166572…3674e1395c`;
  `scripts/zk60_fable_joint_rank.py` `ad5e4e48…64ffbb5b`;
  `scripts/zk60_fable_cfs_channel.py` `ba05f0d1…120066437`.
- **Commands (absolute paths from the worktree) and exits:**

| Command | Exit |
|---|---|
| `git --no-pager -C /home/victor/wt-zk60-fa log --oneline -5` (head `ed478da`) | 0 |
| `sed -n` / `grep -n` / `python3 -c` reads of every input named in §A.3 and the source ranges named in the header | 0 |
| `python3 scripts/zk60_fable_transcript_sim.py report -o results/zk60_fable_fa8_transcript_sim.json` — `fibre all_ok=True k_slots all_ok=True pad_budget all_ok=True`, `fp bias log2 = -96.000`, 9 k-slot cases PASS (6 positive at 0, 3 negative at 12 / 12 / 20) | 0 |
| `python3 scripts/zk60_fable_transcript_sim.py disposition -o results/zk60_fable_fa8_disposition.json` | 0 |
| `python3 -m unittest discover -s tests -p 'test_zk60_fable_transcript_sim.py' -v` — 16 tests (a first run failed one assertion of mine: the trivial-identity count is in base rows, 4 per proof for W's two groups, as FA7 reports; fixed) | see §H.2 |
| `python3 -m unittest discover -s tests -p 'test_zk60_fable_*.py'` (FA2/FA3, FA6, FA7, FA8 together; detached with a done marker) | see §H.2 |
| `sha256sum` of the inputs and of the four FA8 files | 0 |

### H.2 Test results and file hashes

- `python3 -m unittest discover -s tests -p 'test_zk60_fable_transcript_sim.py'`:
  **16 tests, OK** (exit 0) after the one assertion fix noted in §H.1.
- `python3 -m unittest discover -s tests -p 'test_zk60_fable_*.py'` (FA2/FA3
  34 + FA6 21 + FA7 23 + FA8 16 = 94 tests): the first detached run, launched
  before the fix, reported exactly that one failure and nothing else
  (`Ran 94 tests in 136.624s`, `FAILED (failures=1)`); the post-fix detached
  run (setsid + done marker) reports **`Ran 94 tests in 112.432s`, `OK`,
  marker `0`**. FA2/FA3's, FA6's and FA7's suites are unchanged by this
  review.
- The test `test_report_roundtrip_and_committed_record` fails if the tool
  changes without regenerating `results/zk60_fable_fa8_transcript_sim.json`
  (it compares the committed `tool_sha256` and every check section).

| File | SHA-256 |
|---|---|
| `scripts/zk60_fable_transcript_sim.py` (new) | `08720bccc36ede30dc624c0195d8d1a8ae602439fa11f90c20b3ec046c69452e` |
| `tests/test_zk60_fable_transcript_sim.py` (new) | `f6a792ad18dfc5324797090619fe34ec3ce0cd9da17ace62986fb422bcab99b6` |
| `results/zk60_fable_fa8_transcript_sim.json` (new) | `d5f6f75570d7abfa25a0e5463cc6f0128ebebfc3132e8524e0d23907f3dbe4c4` |
| `results/zk60_fable_fa8_disposition.json` (new) | `a2c9c94fed31815be8809e71679d2697ebe6486adf489666980c19cc8b46a8b8` |
| `docs/zkmatrix-poc/ZK60_FABLE_TRANSCRIPT_REVIEW.md` (this document, new) | — (see the commit) |

### H.3 Limits

- **An argument about a specified construction, not about code.** The
  repaired profile does not exist; C1–C8 are what the implementation must
  satisfy; B5/S3 gate everything.
- **The model is the ROM with programmable Fiat–Shamir squeezes** and
  salted-leaf hiding as an oracle-query event. Multi-round adaptive
  Fiat–Shamir *soundness* loss is FA5's open item and unrelated to hiding.
- **The exact checks are structural**, at tiny shapes, with stand-in
  coefficients; they pin three facts the argument uses (L3, the k-slot rank,
  the pad rank) and are not the simulator.
- **The bound's `N_fp·2^-95` term** is a proof artefact of drawing masks by
  reduction; it is the dominant accepted-view term and is removable.
- **F2 closes only under E1–E3**; today's journal provides the public-state
  half and says so.
- **The attention side is not argued** (A1–A4); the block closes on the FFN
  side and the FFN-side seam terminals only.
- **Nothing here is a private-block, deployment or throughput acceptance**;
  shared production edits remain with the source owner.
