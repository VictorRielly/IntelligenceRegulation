# FA7 — Captured A/H/W observations analysed jointly

**Reviewer:** Claude Fable 5.1, independent privacy reviewer.
**Session:** 2026-09-08, worktree `zk60-fable-review` at source pin `cfa46f6`.
**Captures:** produced at `c8a342f` by the ordinary verifier's `cfg(test)` observer
(`hashline/src/zk_ffn_observation_json.rs`, schema 1), twelve files in
`/tmp/zk60-round11/final-observations` and twelve in `/tmp/zk60-round11/observations`
(six shared), 18 distinct proofs, 45 role cases.
**Deliverables:** `scripts/zk60_fable_joint_capture.py` (parser + joint model),
`tests/test_zk60_fable_joint_capture.py` (23 tests),
`results/zk60_fable_fa7_joint_captures.json` (machine-readable results), this document.
**Task:** queue row FA7 of [ZK60_FABLE_QUEUE.md](ZK60_FABLE_QUEUE.md) (round 11).

## 1. The one-paragraph answer

Every one of the 18 captured proofs was parsed under a digest-bound, layout-recomputing
parser and analysed as one exact linear system per role at full width (all message
coordinates of every group vector, the proximity vector, every terminal value including the
H sum claim's public 0, and H's zero-sum constraint on the mask row `u`), with one unknown
per committed entry so that the re-opened X rows (rho_d and p2), the re-opened h16 rows
(rho_f and p5) and every H helper row (its own claim and the LogUp sum claim) alias
automatically. Codex's thirty per-column numbers (A 2, H 0, P3 W 2) are reproduced
exactly with the same classification, which I re-derived from `LayoutV3::new` /
`ZkLayoutV3::new` rather than from claim order. The joint numbers are strictly larger:
**A discloses 2n + 4 base-field functionals per proof (68 at T2, 516 at T32), P3 W
discloses 2n + 2 (66 / 514), H discloses 2 — and those 2 are exactly the public LogUp
identity, which the zero-sum constraint exposes and whose value the proof fixes to 0.**
The actual Wd disclosure is reproduced from the captured p6 vectors: 32 functionals of the
eight Wd rows at T2, the whole 256-entry Wd plane at T32 (the same digest in all three
independent T32 P3 proofs); the X-at-p2 and h16-at-p5 rows are recovered whole at T2 (the
same digests across ten fresh proofs of one fixture and across two of the other). None of
this is a simulator, an upper bound on disclosure, or a statement about H privacy: pads,
sampled columns, the CFS channel and repeated proofs are excluded by contract (FA6/FA8),
and the captures hold no witness, so truth comparison lives only in the Rust harness.

## 2. Inputs and hash table

Both directories were hashed file by file before anything was parsed. The parity record
`results/zk60_round11_capture_parity.json` (sha256 `f38026ff…c8ef6a44`) binds only the six
seeded captures; all six verify byte-identical in both directories. The six initial-only
fresh captures are bound by Codex's `results/zk60_round11_captured_rank.json`
(`capture_sha256` per case, sha256 of that file `b81a7b2c…9ccee3a2`) and verify. The six
final-only fresh captures are **in no prior record**; their digests are recorded here and in
the results JSON for the first time. Every file name equals its `proof_sha256` field, the
transcript endpoints chain W → A → H inside every file, and no file was refused.

| proof_sha256 | capture file sha256 | privacy / shape | roles | directory | bound by |
|---|---|---|---|---|---|
| `0f021e132c54c56d4c7c4c02961df2a36000401b14b880977c4719a86dcc354e` | `77afb10005c5d9cba8203881ace92300c74df94015f2324dd6503f16dc351d65` | P1 T2/d16/f16 | A H | initial | Codex record |
| `2084e511d8fc65a1f806e8095e0328f5d1daf3d3ce7e4ff9a7036acd9d746036` | `bf14ab09b1f6ce5247320f01c3f9276cf382a9abec1750f2756785d3ef7d265a` | P3 T2 | W A H | initial | Codex record |
| `224abfdd76d8082c815ccd20fdee878d42708178786d60def7c8b4e97f1482f6` | `5f3a0b2b8093ad68a3086cee48f42631d37aee1b0d41848ecd7553e3100018f4` | P3 T32 | W A H | final | **this record only** |
| `30b390755fda91b784b9dd6d13cc957f57cb67f8441657a0266c26ac139815d2` | `6802f9a6fd3c2f0cc1d7aaaf82a5d7f86f543e64062868a00fe6e3941c37484c` | P1 T2 | A H | both | parity (seeded) |
| `39677c8cc2882da76b413c2edf348bdb58b4db607984afcbd003556cd1ea6b3c` | `1d4e456775e2c218351a8e7eeadcdcf5ebddfff851afd6d15107119f04330766` | P3 T2 | W A H | initial | Codex record |
| `3b1affac2ad55d754e5b86a591c1c6a35a0c0cc79f3e481fd99e35e9ac96c60d` | `1ff06f18a3d72a41b19fd98ffda1f4f55d632c2aeaa30ba9a792644307a90213` | P1 T2 | A H | initial | Codex record |
| `5e5f2a63f5f8ed7186009b6572510fed335eb330d480c23885a8a4af0927a3e0` | `a2a025b1d29e617023ef66df9cf5c4177e4e1ac3563ea1af214623eb59128d9c` | P3 T32 | W A H | initial | Codex record |
| `6fefcd11df3ec6c55db8dbb99304c855b4ae7a7621a21b812d7f810fb5d60297` | `9e5b400cdbc7e2817636d70a3313999af90b0b9ab16f229e6655a5ce7b37f2de` | P3 T2 | W A H | both | parity (seeded) |
| `722ad4fa3792da4de444525850ee27fdef4a0cd04ad4550a3938d4ce2cdedcf9` | `398b870ce85e9930864cb455648398a56517cc3fa75cca6f714ee8ec001f8b3c` | P1 T2 | A H | final | **this record only** |
| `7cf29500323baaa0e16db1c13bb25ea7ca357f044c216796dfbd50b540e390df` | `25f65afff3815aac7a1f881c746a6a0b31e60fd55d166d37acd41a0a785ea4f3` | P1 T32 | A H | both | parity (seeded) |
| `882ffeb5d73dbb4db565c2632c32709f0ce053a71f858b0cc503571bc6b809c7` | `473f73508cb5e48de8194e0b8d8b4852e6148ecca30d361062bba3a956ba058c` | P1 T32 | A H | final | **this record only** |
| `9506f86e7f3e5fdf3c4c3d6a16ccbb6faa042f5fa47ce0dc3d81e8bc73d1d913` | `29439a65695bccf6a388866d42a81ee52ca2176afd2a3e6dda0bb95e4e4fabb8` | P3 T2 | W A H | final | **this record only** |
| `9ce61efc214b868840a3f904ee3b1b974b62431eaf5cbe5b6a8364b83594c1a7` | `4045e9bc9266d8651ad3136c2a9be30db5d5f4f0e7ee9339c9bb90d5ddbf6d70` | P1 T2 | A H | both | parity (seeded) |
| `ac560dde2ee5352d0ef23a228411c19759ce003bb59a6d44678ec7f6ec6f6dfe` | `e883bc01944df266c48046826ab9732c0f66ab6216f543704e9c3500a3b06240` | P3 T32 | W A H | both | parity (seeded) |
| `d7cfdc8d99c7a795e73e0aed9004ac2e43c85003bae0ac2c130e97211599b31e` | `5f2040ad2c868b39d3a42c39c276e7d65da06ad1bfcef315171426c29dd9d54a` | P1 T32 | A H | initial | Codex record |
| `de66bd63823e51c15ecff4c78508559d1bf57d3a39ca7860e51774d9dab4bd5a` | `2d51566417c6e3f0a095699ce4dc1c670e16a67b523a6d621ba07926fc8bb853` | P1 T2 | A H | final | **this record only** |
| `dea4cfc7a4990dee283e3f76e4ae3c5f6d367813b32999f4d0b856ce5f2f6615` | `056a60db4383b81cd7460d24f4ea3e02b32c96f80f889d45f328b33a40b90930` | P3 T2 | W A H | both | parity (seeded) |
| `fa4a493ad42f52e71e04b70f4f83f2841898405af7aa2e200de5641b19d7ae67` | `5da817a79ea0b7a09cd3d62c01322786fa8bf0db536a45eefa7de8919349e751` | P3 T2 | W A H | final | **this record only** |

Per role the results JSON also retains the commitment root, `before/after_state`, the
next challenges, every claim's slices (offset, log_size, kind, plane name), the prox row,
the zero-sum pair rows and the aliased rows. Shapes: T2 → n = 32, Q = 12, A 5173 rows
(2585 data / 2588 mask), H 10321 (5158 / 5163), W(P3) 28 (24 / 4); T32 → n = 256,
Q = 256, A 681 (344 / 337), H 1325 (664 / 661), W(P3) 7 (3 / 4).

## 3. The parser: what is checked, what is refused, how rows get their roles

`Capture(path, expected_capture_sha256)` refuses (raising `CaptureError`, never guessing):
malformed/truncated JSON; `schema != 1`, wrong `kind`, a `coverage` other than
`ffn-v3-function-1`, `fully_verified != true`, a field modulus or nonresidue that is not
Goldilocks / u² = 7; a `proof_sha256` that is not the file's digest name; a file whose
sha256 differs from the expected record; any coefficient, lambda, point coordinate, vector
entry, rho or column value that is not a Python `int` in [0, p) (floats, strings and
booleans refuse); a part whose slice is not row-aligned, narrower than a row, or extends
beyond the commitment's rows; a point whose length is not the slice's `log_size`; a claim
that is a member of two groups or twice of one; `lambdas` not matching `members`; a group
key with `offset != 0` or `len != n`; a member part whose column tail differs from the group
key; a claim in no group; proximity rhos not one per row; roles that are not `[W, A, H]`
(P3) / `[A, H]` (P1); transcript endpoints that do not chain W → A → H; and — the check
that pins the column-weight convention — a group whose clear vector does not satisfy
`Σ_j eq(tail)[j]·v[j] = Σ_k λ_k·value_k` exactly (this identity holds on every group of
every capture with the MSB convention of `eq_table_msb`; the LSB convention fails on all
but the all-ones sum group).

**Row roles are not in the capture and are not taken from claim order.** The parser
recomputes the allocation of `hashline/src/layer.rs::LayoutV3::new` (data offsets: the seven
f-planes g8, rg, a16, u16, ru, h16, rh, then X, z16, rd; hg/hu/hh/hz as (re, im) pairs;
wg/wu/wd blocks) and `hashline/src/zk.rs::ZkLayoutV3::new` (A: `a_mf`, `a_md`, `a_mgu`,
`a_mdd`, `a_prox`, then per table slot `a_row`, `a_mask`; H: `h_mf` pairs, `h_md` pairs,
`h_u`, `h_up`, `h_prox`, then per slot `h_re`, `h_im`, `h_mre`, `h_mim`; W under P3:
`w_mgu`, `w_mdd`, `w_prox`), and the claim lists of `build_claims_zk_v3` /
`build_w_zclaims_v3` (`zk.rs` 3177–3374). Every captured claim's every slice must equal the
recomputed one, the sum claim's coefficients must be the fixed ±1 / ±u, its value must be
0, H's claims must have the (k, k·u) pair form on data and mask parts, the group shape must
be the layout's (`[7,3,1,1,6]`, `[3,1,1,6,1]`, `[2,1]`), and the only unreferenced row must
be the prox row. Otherwise the capture is refused. This is how the classification Codex used
(`ci == 4` all-mask for H, the sole unreferenced row as mask) was **verified rather than
trusted**: the zero-sum pair `u` is `h_u = (16, 17)` at both shapes, allocated before
`h_up = (18, 19)` (its extension mask u′) and before `h_prox = 20` — the source comment
"then the zero-sum u" at `zk.rs` 2539 describes the order in which the prover *fills* the
mask rows from its RNG (u last, n − 1 draws and a negated sum), not the row allocation —
and `u`'s rows are the ones the sum claim carries with (+1, +u) while u′'s appear nowhere
else. The
per-column reproduction records `classification_equals_layout_recomputation: true` for all
45 cases.

Aliasing confirmed on real claims (FA2 U12): at T32 A, claim 7 (rho_d) and claim 10 (p2)
both open the data slice (offset 3584, 2⁹ = rows 14–15) under different masks
(`a_md[0]` at 6912, `a_mgu[0]` at 7680); claims 5 and 11 both open h16 (rows 10–11). In H
every data plane and `u` are opened by their own claim and by the sum claim (rows
0–7, 16–17 and every table helper block).

A cross-role shared coefficient, recorded for FA6: under P3 the data coefficient of A's
p2 claim equals that of W's p3 claims (`k_gu.0`, e.g. `10486787992654003567 +
11913227085120168996 u` in `ac560d…`), and A's p5 data coefficient equals W's p6 data
coefficient (`k_d.0`); the mask coefficients differ (A: `(1 − e₂)e`, W: `e₂`). The unknowns
are disjoint, so there is no linear coupling between A and W; it is a shared function, not
a shared observation.

## 4. Observation classes: included and excluded

Included (all Fp2 observations, each two base-field rows): every message coordinate
`v_g[j]`, j < n, of every group vector; every coordinate of the proximity vector; every
terminal (claim value), including the H sum claim's public 0; H's public constraint
`Σ_j u[j] = 0` on the zero-sum mask pair (proven by the zsum sumcheck: its claimed sum is
`Γ_zs = c_zs·Σ g`, so the data part sums to zero); and the shared row identities.

Excluded, with the reason — these are stated classes, not costed at zero:

- **Pads** `v_g[n..n+Q)` and `prox[n..n+Q)`: linear in the Q fresh pad unknowns of each row,
  not in the message unknowns; FA2 §14.6's Vandermonde argument covers them jointly with
  the sampled columns. Retained in the files, not modelled.
- **Sampled columns** (Q per role, with salts and paths): `(f_row + Z_n·g_pad)` at coset
  points, hidden by the pads and by the salted leaves; a computational assumption plus the
  §14.6 argument, outside a rank model.
- **The CFS channel** (M root, masked round messages, masked claimed sums, `mask_open`):
  nonlinear in the data — FA6.
- **Repeated proofs of the same witness**: every capture is analysed alone — FA8. The
  captured set does contain such repeats (§7), which is why FA8 matters.
- **Unopened columns**: the Merkle root; hash assumption.

## 5. The joint model and how it is computed exactly at full width

Unknowns: one base-field scalar per (row, column) entry of a commitment (T2 H: 330 272;
T32 A: 174 336). The vector and proximity coordinates of column j involve only column j's
unknowns and their coefficients (`λ_k·coef·eq_row(r)`, `ρ_r`) do not depend on j; the
terminals are the only cross-column rows, with coefficient `coef·eq_row(r)·eq_col(j)`
(`eq_table_msb` on the point's row bits and the group tail). In the column-space picture
the rank of the observations restricted to an unknown set X is `n·r_X + dim K_X`: `r_X` is
the per-column block rank (exactly the number Codex computed) and `K_X`, the space of
cross-column combinations that vanish on every block, is `Σ_j D_j(Z_X)` with `Z_X`
computed once from the block null space and `D_j` the per-claim rescaling by
`eq_col(j)`. Rows with identical claim memberships, kind and plane form a *site* whose
generators are compressed to an Fp-basis of the span of the rows' (row weight, ρ)
features — exact, and it is what makes a 2048-row table slot cost a few vectors. Everything
is integer arithmetic mod p (the field code is imported from
`scripts/zk60_fable_joint_rank.py`, unchanged, sha256 `ad5e4e48…64ffbb5b`).

Reported per role: `disclosed_total = rank(all) − rank(masks)`; per data plane P
`projected = rank(masks ∪ P) − rank(masks)` (independent functionals of P's entries that
appear in the disclosed space) and `isolated = rank(all) − rank(all − P)` (disclosed
functionals supported on P alone, other data treated as unknown nuisance); for the
singleton planes also `isolated` with the plane removed at one column only (columns 0 and
n − 1), which is the per-column functional count; `fully_recovered` iff `isolated` equals
the plane's unknown count.

Validation of the algebra (all in the test file): on twelve random tiny systems with
overlapping slices, multi-row sites, aliasing, extra constant-coefficient rows and a
column exception, every compressed number equals the dense `analyze` of the FA2 tool;
on a synthetic full capture built from a known random matrix (T16 and T32, P3, all three
roles, generated independently of the model entry by entry) the recovered X, h16 and Wd
rows equal the matrix rows and the two-row functionals equal `Σ_r w_r M[r][j]`; the parser
refuses every malformed variant listed in §3.

## 6. Results: joint versus Codex's per-column subset

Every number below is identical across all proofs of a shape/mode (fresh OS randomness
and seeded fixtures alike), so one row per (mode, shape, role); `n` is the message width.
"Codex" is the per-column subset (`rank_joint − rank_mask` on the 2·groups + 2 base rows of
one column), reproduced exactly in all 30 cases with the same data/mask row counts and ranks.

| mode / shape / role | Codex per column | × n | joint total | difference and its source |
|---|---:|---:|---:|---|
| P1 and P3 / T2 / A | 2 | 64 | **68** | +4: the rho_f (7-member) and rho_d (3-member) all-base groups each give 2 base functionals of their planes from the *terminal values* (FA2 §14.2); the two singletons' terminals are implied by their vectors (0); tables 0 |
| P1 and P3 / T32 / A | 2 | 512 | **516** | same +4; the 2-row f/d planes do not change the count |
| P1 and P3 / T2 / H | 0 | 0 | **2** | +2: the zero-sum constraint on `u` turns the sum claim's masked coordinates into the public LogUp identity; **0 without the constraint**; the two functionals lie in the span of the identity's two base rows (§8) |
| P1 and P3 / T32 / H | 0 | 0 | **2** | same |
| P3 / T2 / W | 2 | 64 | **66** | +2: the (Wg, Wu) p3 group's two terminal functionals; the Wd terminal is implied by its vector |
| P3 / T32 / W | 2 | 512 | **514** | same |

Per data plane (identical across proofs; `rows` = rows of the plane; `proj` / `iso` as
defined in §5):

| shape / role | plane | rows | proj | iso | reading |
|---|---|---:|---:|---:|---|
| T2 A | X[0], h16[0] | 1 | 32 | 32 | **whole row recovered** (singleton at p2 / p5); 1 per column |
| T2 A | g8, rg, a16, u16, ru, rh, z16, rd | 1 | 2 | 0 | touched only by the two group functionals; nothing supported on one plane |
| T2 A | tab[0..5] | 8, 2048, 4, 1, 512, 2 | 0 | 0 | the INT16 block is Fp2-effective (FA2 §14.3); the group is covered |
| T32 A | X[0], h16[0] | 2 | 258 | 256 | one functional of the two rows per column (256) **plus** the plane is touched by the rho group's 2 functionals (258); not recovered |
| T32 A | other planes / tables | 2 / var. | 2 / 0 | 0 | as T2 |
| T2 H | hg, hu, hh, hz (re+im), h_t[0..5] | 2 / 2·slot | 2 | 0 | every plane is touched by the identity (its ±1/±u row), none alone |
| T32 H | same | 4 / 2·slot | 2 | 0 | same |
| T2 W | Wd[0][0] | 8 | 64 | 32 | 32 functionals of the eight rows (1 per column) supported on Wd alone; 32 more Wd dimensions appear inside the mixed (Wg, Wu, Wd) proximity-borne functional |
| T2 W | Wg, Wu | 8 | 34 | 0 | 32 mixed per-column functionals + 2 terminal functionals; nothing supported on one plane |
| T32 W | Wd[0][0] | 1 | 256 | 256 | **whole plane recovered** |
| T32 W | Wg, Wu | 1 | 256 | 2 | every entry is touched (the per-column (Wg[j], Wu[j]) functional, FA2 §14.4); combined with the two terminal functionals, two functionals of each plane alone |

The count of observation functionals that annihilate masks *and* data (the trivial
identities `Σ_j cw_j v_g[j] = Σ_k λ_k value_k`) is 10 for A and H (five groups) and 4 for
W (two groups) in every case, as it must be.

What is new relative to the subset: the per-column part (`n × Codex`) is the dominant term
and is exactly Codex's number; the terminals add 4 (A) / 2 (W) / 2 (H) per proof;
aliasing does not add rank beyond that at these shapes (the p2/p5 re-openings are what
already make the singletons; the rho-group functionals touch the same X/h16 rows, visible as
`proj = iso + 2`); H's 2 is not "H privacy" in either direction: it is the known-zero
identity and it is a rank statement under fixed coefficients.

## 7. The actual Wd, X and h16 disclosures reproduced from the captured vectors

For a singleton group [k] whose claim is (data slice, one single-row base mask), the
captured clear vector satisfies `v[j] = λ·(coef_d·Σ_r eq_r·D[r][j] + coef_m·R[j])`. With
`b = λ·coef_m` and `L_b(z) = z.c0·b.c1 − z.c1·b.c0`, `L_b(v[j]) = Σ_r w_r·D[r][j]` with
public `w_r = L_b(λ·coef_d·eq_r)`: a mask-free combination of the plane's rows. The tool
computes it from the message coordinates of the vector (`singleton_functionals`), checks
`Σ_j cw_j v[j] = λ·value` (true in all cases) and digests the functional values; when the
plane is one row it also digests the recovered row `L_b(v[j]) / w_0`. **Values never leave
the tool**; the JSON holds digests, the public rows and weights.

- **Wd at p6, T2** (`w_mdd[0]` = row 26 of the 28-row W commitment; data rows 16–23, i.e.
  the eight rows of the 256-entry Wd block): 32 functionals, one per column, of the eight
  rows with the public eq weights of the three row bits of p6 (listed in the JSON, e.g.
  `w_r` = `0x25f01140bdc6a124, 0x3be5679e4d5cc425, …` for `2084e5…`, a different public
  set per proof). `isolated(Wd) = 32`,
  `isolated at column 0 = 1`, `isolated at column 31 = 1`. Exactly the round-11 statement
  "32 functionals of eight-row combinations".
- **Wd at p6, T32** (`w_mdd[0]` = row 5 of 7; data row 2): the whole 256-entry plane,
  `isolated = 256 = unknowns`, `fully_recovered`. The recovered plane's digest is
  `f7fc6c90d7383d75…` in **all three** independent T32 P3 proofs (`ac560d…` seeded,
  `224abf…` and `5e5f2a…` fresh): the weights are the same in every proof by construction,
  the challenges are not, and three independent L_b projections agree — a witness-free
  consistency check that the recovery is real.
- **X at p2 and h16 at p5, T2** (`a_mgu[0]` = row 20, `a_mdd[0]` = row 21; data rows 7
  and 5): whole rows recovered in all twelve T2 proofs. Recovered-row digests: X
  `0957b0f9493dea0f…` in ten proofs (both modes, fresh and seeded from the same fixture
  witness) and `10bbda93f74e5f01…` in two (`6fefcd…`, `9ce61e…`); h16 `80e7398b4db103d9…`
  (ten) and `821846719879b4da…` (two). Two distinct witnesses in the set, each recovered
  identically from every proof of it.
- **X and h16 at T32**: one functional of the two rows per column (`isolated = 256`, at a
  column 1), with the public (1 − p₀, p₀) row weights; the functional-value digests differ
  per proof (different λ, b), as they must.

Boundary: the captures hold no witness. Agreement across proofs is the strongest check
available here; equality with the fixture's actual values is established only in the
in-process Rust harness (`zk_ffn_mask_diagnostic`), which this review does not run.

## 8. H and the zero-sum relation

Per column H's masks span every block dimension (rank 12 of 12), so the subset says 0.
Jointly: without the constraint `Σ_j u[j] = 0` the disclosed dimension is **0** in every
case; with it, **2**. Adding the LogUp identity restricted to the data rows
(`Σ_j Σ_b (hg+hu+hh)(re + u·im) + Σ_c hz − Σ_i h_t[i]`) as an extra observation does not
raise the rank (it is already in the observation row space), and since the surviving space
has dimension 2 it *is* the span of the identity's two base rows: what survives is the
functional whose value the proof itself fixes to 0. This re-verifies FA2 §14.5 on actual
coefficients. It is recorded as `residual_equals_public_logup_identity: true` for all 18 H
cases. It is not a claim of H privacy: it is the linear model with fixed coefficients, the
u pair's remaining `2(n − 1)` free dimensions are what pad the other column functionals,
and the CFS/pad/repeat channels are outside it.

## 9. What the joint numbers establish and do not

Established (linear model, captured coefficients, one proof at a time): the exact
dimension of the disclosed base-field functional space per role and per plane; that the
legacy profile discloses 2n + 4 (A), 2n + 2 (P3 W) and the public identity (H) per proof;
that the singleton disclosures are exact row recoveries at T2 and per-column two-row
functionals at T32; that Codex's subset is a lower bound that misses the terminal channel
(4 / 2 per proof) and the zero-sum interaction; that the row identities alias as the source
says.

Not established: any upper bound on disclosure (pads/columns, the CFS channel and
repeated proofs are outside the model; the captured set itself contains up to ten proofs of
one X witness and three of the same W, which FA8 must treat); any simulator or conditioning
argument (the challenges are treated as fixed public constants — FA3 B2); integer-range
amplification (FA3 B3); anything about the repaired profile, which has no capture yet
(FA3 B5); private-block, deployment or throughput acceptance.

## 10. HANDOFF — the next captures (repaired profile `ffn-v3-mr1`, function 2)

The current parser refuses any `coverage` other than `ffn-v3-function-1` by design; the
repaired and predicate captures need the schema below and a matching
`expected_claims` rule (I add it when the layout lands; the refusal is the safe default).

**Schema 2 (a superset of schema 1; every schema-1 field keeps its meaning):**

- Header: `schema: 2`; `coverage` ∈ {`ffn-v3-mr1-function-1`, `ffn-v3-mr1-function-2`,
  `ffn-v3-function-2`}; `profile` (the `HL-ZK/2` header field, FA3 §12), `transcript_domain`;
  `source_commit`; `layout_digest` = sha256 of the joined `ZkLayout*::describe()` strings so
  the parser's recomputed allocation is pinned to the prover's; `proof_sha256`; `privacy`,
  `shape`, and for function 2 the public predicate (`row`, `col`, `tau`).
- Per role, in verifier order (W under P3, A, H) and only after the whole FFN verifies:
  `params`, `commitment`, endpoints, `claims` (every part with `offset`, `log_size`,
  `coefficient`, `point`, and a `coefficient_tag` such as `"1-e_f"`, `"e_f"`, `"e_f*u"`,
  `"(1-e_gu2)(1-e_gu)"`, `"e_gu2"`, `"ext_i"` so shared functions are enumerable), `groups`
  (members, lambdas, key, the full n + Q vector), `proximity_rhos`, `proximity_vector`,
  `columns` — as today — **plus**:
  - `row_roles`: one entry per row `{row, kind ∈ {data, mask, prox}, site}` with the FA3 site
    id (`a_mf[k].re/.im`, `a_mgu[c].re/.im`, `a_prox.re/.im`, `tab[i].a_mask`, `a_pmz.re/.im`,
    `a_pmb.re/.im`, `a_sx[c].re/.im`, `a_sz[c].re/.im`, `h_u.re/.im`, `h_up.re/.im`,
    `h_prox.re/.im`, `w_mgu[k].re/.im`, `w_mdd[k].re/.im`, `w_prox.re/.im`, …). The parser
    recomputes and compares; a disagreement refuses.
  - `public_linear_constraints`: `[{rows: [h_u.re, h_u.im], relation: "sum over the n
    message columns = 0", source: "zsum sumcheck"}]` and nothing else unless the verifier
    imposes it — anything the verifier imposes on a mask row must be listed here.
  - Pair claims in the repaired form: three parts `(data, k₀, p)`, `(R_re, k₁, tail p)`,
    `(R_im, k₁·u, tail p)`; the prox pair rows entering only the proximity combination with
    their two rhos.
  - **Seam slots** (block profile): the X seam and Z seam claims on the *actual* A
    commitment (`a_sx[c]`, `a_sz[c]` groups at `tail(rho_sx)`, `tail(rho_sz)`) with their
    coefficients, points and terminal values, and the attention-side mirror claims on the
    attention A commitment, so that the seam aliasing (the same X / z rows under a third
    mask) is visible through the slice offsets.
  - **Function 2**: the predicate claims (the z block re-opened under `a_pmz`, the bit row
    under `a_pmb`, both at `tail(rho_p)`, coefficients `(1 − e_p)·ext`, `e_p·ext`) in A's
    claim list with their group, and the public `tau`.
  - P3 W: the slot index and `k`, `q_pad = k·Q`, and the slot's pair rows (FA4 §5.1); the
    vector length n + k·Q.
- Binding: file name `<proof_sha256>.json`; the exporter refuses an existing name; a
  parity record that lists **every** capture (fresh ones included — the current record binds
  only the six seeded files, which is why six final captures had no prior record), and the
  results JSON records file digest, proof digest, tool digest and `layout_digest` per case.

**Cases** (each at T2/d16/f16 and T32/d16/f16, P1 and P3, one seeded fixture and one
fresh-OS proof; that is the same 12-proof matrix as now):

1. Repaired standalone A, H, W(P3) (FA3 acceptance P3): expected `disclosed_total = 0` for
   A and W, `2` for H with `residual_equals_public_logup_identity = true` and `0` without the
   zero-sum constraint; every plane `projected = 0` (H planes 2, the identity); Codex's
   per-column numbers 0.
2. Repaired block profile with both seams bound (A carries `sx`, `sz`): same expectations;
   the seam rows must alias the rho_d X / z rows in `row_roles` and slices.
3. Function 2 (legacy `ffn-v3-function-2` **and** repaired): the predicate group is a
   2-member all-base group in the legacy layout, so the legacy capture must show
   `disclosed_total = 2n + 6` (+2 from the predicate pair's terminals, FA2 §14.2, U9) and
   the repaired one 0.
4. Negative controls through the `cfg(test)` hooks of FA3 §7: AM3 (a mask row left
   constant) must make the tool report that plane's `projected` and `isolated` nonzero; AM4
   (`a_mgu[0] := a_md[0]`) must report X `fully_recovered`; AM15 (Fp-dependent prox rhos)
   must raise the A prox contribution; a legacy capture presented with a repaired
   `coverage` must be refused by the layout recomputation.

**How FA3 acceptance test P3 runs the tool:** `python3 scripts/zk60_fable_joint_capture.py
analyze --final-dir <captures> --parity <record> -o results/<name>.json`, then assert on the
`summary` table exactly the expectations above; the unit test
`RealCaptures.test_results_file_is_bound_to_this_tool_and_these_captures` is the template
(it re-hashes every file and the tool and compares the recorded numbers).

## 11. Commands, exit codes, resources

All runs on the WSL box, Python 3.10.12, stdlib only, single-threaded, peak RSS ≤ 90 MB
(the files are streamed one at a time; nothing near the 2 GiB budget). No cargo, no GPU,
no Rust edit.

| # | Command | Exit | Result |
|---|---|---:|---|
| 1 | `sha256sum /tmp/zk60-round11/final-observations/*.json /tmp/zk60-round11/observations/*.json` | 0 | the table of §2 |
| 2 | `python3 scripts/zk60_fable_joint_capture.py check /tmp/zk60-round11/final-observations/6fefcd11….json --expected-sha256 9e5b400c…` | 0 | parsed; layout recomputation and Codex classification agree |
| 3 | `python3 scripts/zk60_fable_joint_capture.py analyze --final-dir /tmp/zk60-round11/final-observations --initial-dir /tmp/zk60-round11/observations --parity results/zk60_round11_capture_parity.json --codex results/zk60_round11_captured_rank.json -o results/zk60_fable_fa7_joint_captures.json` | 0 | 45 cases, 0 refused, 30/30 Codex cases reproduced exactly, 6/6 parity pairs verified; 52 s wall, 89 MB RSS |
| 4 | `python3 -m unittest discover -s tests -p 'test_zk60_fable_joint_capture.py' -v` | 0 | 23 tests OK (before the results file existed: 22 + 1 skip) |
| 5 | `python3 -m unittest discover -s tests -p 'test_zk60_fable_joint_rank.py'` | 0 | 34 tests OK (FA2/FA3 tool untouched) |
| 6 | `python3 -m unittest discover -s tests -p 'test_zk60_fable_joint*.py' -v` | 0 | 57 tests OK, 0 skipped, 30 s |

Digests at the end of the session: `scripts/zk60_fable_joint_capture.py`
`9dd9b6bafaedeb19c8e2ca008cc255bcede84502dd1f58d3091223e7f6bdf8b2`;
`results/zk60_fable_fa7_joint_captures.json` records the same tool digest (the unit test
fails if the tool changes without a re-run).

Two defects of my own were found by the tests and fixed before the final run: the synthetic
generator gave table-claim mask blocks only the column tail (the source gives both table
parts the full point), and the site key omitted the row kind (harmless on the real layouts,
where only the prox row is unreferenced, wrong on random systems). Neither affected a
reported number; both are in the test log history of this session.

## 12. Files

- `scripts/zk60_fable_joint_capture.py` — new: parser, layout recomputation, joint model,
  singleton reproduction, Codex-literal subset, driver, CLI.
- `tests/test_zk60_fable_joint_capture.py` — new: 23 tests (parser refusals, synthetic truth,
  compressed = dense, real captures, results binding).
- `results/zk60_fable_fa7_joint_captures.json` — new: hash table, per-case included/excluded
  classes, per-column and joint ranks, per-plane dimensions, singleton digests, H zero-sum
  checks, Codex comparison, recovered-row agreement, tool digests, limits.
- `docs/zkmatrix-poc/ZK60_FABLE_CAPTURE_REVIEW.md` — this document.
- Unchanged and imported: `scripts/zk60_fable_joint_rank.py` (`ad5e4e48…`), its 34 tests.

## 13. Limits

No private-block, deployment or throughput acceptance follows from this analysis. It is a
partial analysis by construction (four excluded observation classes, one proof at a time,
fixed coefficients, no simulator), a diagnostic of the legacy profile, and an inventory
for FA8. Shared production edits remain with the source owner; nothing under `hashline/`
or `zkp-core/` was touched.
