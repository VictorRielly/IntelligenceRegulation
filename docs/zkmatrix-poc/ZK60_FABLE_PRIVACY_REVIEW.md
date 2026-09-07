# ZK60 independent privacy review — Part 1 (FA1): reproducing the actual FFN disclosure

**Reviewer:** Claude Fable 5.1, independent reviewer, 2026-09-07 session.
**Role:** review of Codex's diagnostic ([ZK60_FFN_MASK_DIAGNOSTIC.md](ZK60_FFN_MASK_DIAGNOSTIC.md),
[ZK60_FFN_MASK_INVENTORY.md](ZK60_FFN_MASK_INVENTORY.md)). I did not write the
diagnostic, the observer hook, or any production code, and I changed no source
file. Everything below is either (a) the retained output of one command I ran
at the pinned source, or (b) derived by me from reading the pinned source. The
two are labelled.

This file is the FA1 part of the review. FA2 (joint A/H/W exposure) and FA3
(repair) are queued behind it and are expected to append their parts here; the
"handed to FA2" section at the end is their input, not a result.

## 1. Source pin

| Item | Value |
|---|---|
| Worktree | `/home/victor/wt-zk60-fa` |
| Branch | `zk60-fable-review` |
| HEAD | `52a13d1` ("docs: publish Fable follow-ups and minimal ZKP core refactor task"), the integrator baseline; working tree clean at start |
| `hashline/src/zk.rs` SHA-256 | `50d37b51085ac40db965559e42e0d6bc9a8a1b8c5ad857a16dabab90259f8a19` |
| `hashline/src/zk_ffn_mask_diagnostic.rs` SHA-256 | `ab6df4ec1fcf12658b4c90ccd2b19e24bc7b06a56fcb914f56d9af858e05a1d2` |
| `hashline/src/pcs.rs` SHA-256 | `60ac5f2f37e30b8aa3d648f5069fa0c2cefc5b73b8e42e3fb34933f77960ab1b` |
| `hashline/tests/zk60_mask_rank.rs` SHA-256 | `2913afeeb9047c6a449f462170e7e6112fd55c41ea89d0b16ee6c2305b78fa81` |
| `hashline/src/transcript.rs` / `mle.rs` / `layer.rs` SHA-256 | `31ce3c9a…733da8` / `131cf1b4…409614` / `f0931f63…6d02d7` (full values in the JSON mirror) |

The three hashes for `zk.rs`, `zk_ffn_mask_diagnostic.rs` and `pcs.rs` are
byte-identical to the `source_sha256` entries Codex recorded in
`results/zk60_round7_validation.json` (recorded at base `9cf1372`). The
diagnostic I reviewed is therefore the same bytes Codex validated.

Toolchain: `rustc 1.97.1 (8bab26f4f 2026-07-14)`, `cargo 1.97.1`; host WSL2
kernel `6.18.33.2`; 22 logical CPUs, run restricted to two build/Rayon threads.
CPU only (`HL_GPU=0`); no GPU feature compiled.

## 2. Command, exit, log hash

One detached run under the shared heavy lock (the worktree had no build cache,
so the build was cold):

```sh
setsid nohup bash -c 'flock /tmp/zk-heavy.lock env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 HL_GPU=0 \
  cargo test --release --offline --manifest-path /home/victor/wt-zk60-fa/hashline/Cargo.toml \
  --lib mask_diagnostic -- --nocapture --test-threads=2 \
  >> /home/victor/wt-zk60-fa/results/zk60_fable_fa1_mask_diagnostic.log 2>&1; \
  echo $? > /home/victor/wt-zk60-fa/results/zk60_fable_fa1_mask_diagnostic.done' >/dev/null 2>&1 &
```

| Record | Value |
|---|---|
| Marker `results/zk60_fable_fa1_mask_diagnostic.done` | `0` |
| Log `results/zk60_fable_fa1_mask_diagnostic.log` SHA-256 | `b1e63a0012dd56952a22942354786514c9f3f4635a8fa0a27d3d0717a10cb817` |
| Build | `Finished release profile in 55.61s` (cold; 8 pre-existing warnings in `attention.rs`, none in the diagnostic) |
| Tests | `4 passed; 0 failed; 0 ignored; 63 filtered out; finished in 1.25s` |
| Tests named in the log | `zk::mask_diagnostic::actual_ffn_seeded_singleton_rows_are_recovered_in_p1_and_p3`, `…actual_ffn_fresh_os_singleton_rows_are_recovered_without_resampling`, `…actual_ffn_t32_recovers_one_functional_per_column_of_two_row_planes`, `…diagnostic_refuses_degenerate_and_paired_mask_controls` — all `ok` |
| `FFN_DIAGNOSTIC` lines | 24 (two roles per proof), 12 distinct proof SHA-256s |

The four tests are the only ones matching the `mask_diagnostic` filter; a
rerun alone is not the review, and sections 4–8 are the source-derived part.

## 3. Cases: profile parameters, proof hashes, observed dimensions

Both profiles have d = f = 16, `shifts = (7, 0, 14, 6)`, SiLU int16 table,
function 1 (no predicate), one layer. The witness is the diagnostic's own LCG
fixture (int8 X in [-127, 127], weights in [-4, 4], activations derived by
`derive_v3`); the proof RNG is either the source's fixture seed
(`ZkConfig.seed = Some(_)`, a public test constant) or `/dev/urandom` via
`ZkRng::from_os` (`seed = None`). PCS parameters are the verifier's
`pcs_params(params, lay.log_a_min)`:

| Profile | `log_cols` | inverse rate | Q (col checks) | A columns n | encoded cols | plane size | rows per plane |
|---|---|---|---|---|---|---|---|
| T2/d16/f16 | 5 | 4 | 12 | 32 | 128 | 32 | 1 |
| T32/d16/f16 | 8 | 8 | 256 | 256 | 2048 | 512 | 2 |

Every proof below was accepted by the ordinary `verify_layer_zk_v3` (W, then
A, then H, all `verify_zk`), and in every case the whole-proof prover and
verifier transcripts matched. Observed from the retained log (nothing here is
a recovered value or a secret):

| Mode | T | RNG | Proof SHA-256 | groups | data rows | base functionals per role | full plane |
|---|---|---|---|---|---|---|---|
| P1 | 2 | fixture (seed 1/101) | `30b390755fda91b784b9dd6d13cc957f57cb67f8441657a0266c26ac139815d2` | [7,3,1,1,6] | 1 | 32 | yes |
| P1 | 2 | fixture (seed 2/102) | `9ce61efc214b868840a3f904ee3b1b974b62431eaf5cbe5b6a8364b83594c1a7` | [7,3,1,1,6] | 1 | 32 | yes |
| P1 | 2 | fresh OS | `5c1ee091c2097b533d679b9510875a9eb364fbd73cb4b529ee54cc9de1f5ffda` | [7,3,1,1,6] | 1 | 32 | yes |
| P1 | 2 | fresh OS | `65abb25449d9019d42014ca19fe20ec3cb493cbaf2f8f3b779de912a589183b8` | [7,3,1,1,6] | 1 | 32 | yes |
| P3 | 2 | fixture (seed 1/101) | `dea4cfc7a4990dee283e3f76e4ae3c5f6d367813b32999f4d0b856ce5f2f6615` | [7,3,1,1,6] | 1 | 32 | yes |
| P3 | 2 | fixture (seed 2/102) | `6fefcd11df3ec6c55db8dbb99304c855b4ae7a7621a21b812d7f810fb5d60297` | [7,3,1,1,6] | 1 | 32 | yes |
| P3 | 2 | fresh OS | `be1d9bfe1a20145f7c6dbd23e60b52ba36005ec23d674216c0f03a144b0c06eb` | [7,3,1,1,6] | 1 | 32 | yes |
| P3 | 2 | fresh OS | `d05342dbc667ff0bd272025b99695e57776c66f0f1c01d8ff9d8f08b81d59cb3` | [7,3,1,1,6] | 1 | 32 | yes |
| P1 | 32 | fixture (seed 1/101) | `7cf29500323baaa0e16db1c13bb25ea7ca357f044c216796dfbd50b540e390df` | [7,3,1,1,6] | 2 | 256 | no (1 functional / column) |
| P1 | 32 | fresh OS | `91b8a6e8e6229f59f7b6839719812c57bcd3f30e5d2d02d553908a6e1bd358c0` | [7,3,1,1,6] | 2 | 256 | no |
| P3 | 32 | fixture (seed 1/101) | `ac560dde2ee5352d0ef23a228411c19759ce003bb59a6d44678ec7f6ec6f6dfe` | [7,3,1,1,6] | 2 | 256 | no |
| P3 | 32 | fresh OS | `9c321f70b51dd3f69503c3eb333ad6fb09f6303fd387772402ea2296c71edc39` | [7,3,1,1,6] | 2 | 256 | no |

Each proof row carries two observations, `X-at-p2` and `h16-at-p5`, with the
same dimensions. The six seeded hashes equal Codex's recorded six, byte for
byte; the six fresh-OS hashes are all new and disjoint from Codex's six (as
they must be), and within each fresh-OS T2 pair the two A commitment roots
differed (the test asserts it). The two `--test-threads=2` workers interleave
their lines in the log; each line is written whole.

## 4. Independent reconstruction of the grouping (source-derived)

### 4.1 Claim inventory of the A opening at nb_d = nb_f = 1

`build_claims_zk_v3` (`zk.rs` 3323–3372) pushes the A claims in this order,
each with exactly two parts (data slice, mask row) and the mask part's point
equal to the last `log_n` coordinates of the data point (`tail`):

| Index | Data plane / point | Mask row | Coefficients (data, mask) |
|---|---|---|---|
| 0–6 | g8, rg, a16, u16, ru, h16, rh at `rho_f` (length log_t+log_fb) | `a_mf[0..7]` | (1 − e_f, e_f) |
| 7, 8, 9 | X, z, rd at `rho_d` (length log_t+log_db) | `a_md[0..3]` | (1 − e_dz, e_dz) |
| 10 | X at `p2 = r_i ‖ r_kp` | `a_mgu[0]` | P1: (1 − e_gu, e_gu); P3: ((1 − e_gu2)(1 − e_gu), (1 − e_gu2) e_gu) |
| 11 | h16 at `p5 = r_ip ‖ r_k` | `a_mdd[0]` | P1: (1 − e_d, e_d); P3: ((1 − e_d2)(1 − e_d), (1 − e_d2) e_d) |
| 12–17 | six table multiplicity slots at `rho_tab[k..]`, k = log_s − log_size | table mask rows | ((1 − e_tab)·ext, e_tab·ext) |

### 4.2 The exact grouping key

`pcs::group_zclaims` (791–815) groups by `ZKey { tail, c0, len }` from
`zpart_weights` (734–774): for a part whose slice covers at least one row
(`log_size >= log_cols`, offset row-aligned), the key is
`(point[log_size − log_cols ..], 0, n)`; for a sub-row part it is
`(point, offset % n, 2^log_size)`. First occurrence fixes group order. Every
part of a claim must produce the same key (asserted).

The diagnostic's `column_key` (92–131) is an independent re-implementation of
that rule with extra bounds checks (capacity, point arity, row alignment, no
row crossing). I compared the two branch by branch; they agree on every
reachable input, and the diagnostic refuses instead of asserting on malformed
ones.

Applying the rule to the inventory above with `log_n = log_cols` (which holds
in both profiles: `log_a_min` = 5 at T2 and 9 at T32, so `min(log_cols,
log_a_min)` = `log_cols`):

- claims 0–6 → key `(rho_f[nvf − log_n ..], 0, n)` — one group, 7 members;
- claims 7–9 → key `(rho_d[nvd − log_n ..], 0, n)` — one group, 3 members;
- claim 10 → key `(p2[log_t + log_db − log_n ..], 0, n)` — alone;
- claim 11 → key `(p5[log_t + log_fb − log_n ..], 0, n)` — alone;
- claims 12–17 → key `(rho_tab[log_s − log_n ..], 0, n)` for every slot,
  because `k + log_size − log_n = log_s − log_n` regardless of the slot's
  `log_size` — one group, 6 members.

That yields **[7, 3, 1, 1, 6]** in first-occurrence order, matching the
diagnostic's assertion and all 24 logged lines. The five tails are the last
`log_n` coordinates of five different challenge vectors (`rho_f` and `rho_d`
from the two zero-check sumchecks, `r_i`/`r_kp` and `r_ip`/`r_k` from the two
matmul sumchecks, `rho_tab` from the table sumcheck); they are distinct unless
two independent blake3 squeezes collide, so the count is stable, and the
assertion re-checks it on every proof.

### 4.3 Why X-at-p2 and h16-at-p5 are singletons while the rho roles are not

The key is the column tail of the *point*, not the plane. X is opened at two
points: at `rho_d` it shares the tail with z and rd (three claims, three
masks, three lambdas), and at `p2` nothing else is opened, because only the
nb_d X blocks use `p2` and nb_d = 1. Likewise h16 at `rho_f` sits with six
other f-planes, but at `p5` only the nb_f h16 blocks are opened and nb_f = 1.
The mask rows also differ per role (`a_md[0]` vs `a_mgu[0]`; `a_mf[5]` vs
`a_mdd[0]`), which is what the diagnostic's `extract` filter uses to pick the
right claim for a plane; asking for X with mask `a_md[0]` lands in the
three-member group and is refused ("not a singleton group"), which the test
exercises.

Source-derived row indices (not logged; derived from `LayoutV3::new`,
`ZkLayoutV3::new`, `table_specs_v3` with shifts (7, 0, 14, 6)):

| | T2 (n = 32) | T32 (n = 256) |
|---|---|---|
| A data rows | 10 (planes g8…rh at rows 0–6, X row 7, z 8, rd 9) | 20 (X rows 14–15, h16 rows 10–11) |
| `a_mf`, `a_md`, `a_mgu`, `a_mdd`, `a_prox` | 10–16, 17–19, 20, 21, 22 | 20–26, 27–29, 30, 31, 32 |
| table rows (m + mask) | ACT16 8+8, INT16 2048+2048, rem 4+4, 1+1, 512+512, 2+2 | 1+1, 256+256, 1+1, 1+1, 64+64, 1+1 |
| A commitment rows | 5173 | 681 |
| X-at-p2 data part | slice (224, 2^5), point p2 (5 coords), 0 row bits | slice (3584, 2^9), point p2 (9 coords), 1 row bit |
| h16-at-p5 data part | slice (160, 2^5), point p5 (5 coords) | slice (2560, 2^9), point p5 (9 coords), 1 row bit |

### 4.4 Absorption order and why the replay's order matters

Actual order in `open_zk`/`verify_zk` via `zk_rhos` (817–839, 898–929,
931–1026): (1) for each group in order, `challenge_fp2_vec(members)` lambdas;
(2) `challenge_fp2_vec(rows)` proximity coefficients; (3) for each group,
check `<v[..n], colweights> == Σ λ_k value_k`; (4) absorb each group vector
under `"pcs-vec"`; (5) absorb the proximity vector under `"pcs-prox"`; (6)
`challenge_indices(Q, n·inv_rate)`; (7) Merkle-authenticate the Q salted
columns and check every clear vector's coset encoding against
`Σ_i ρ_g[i] col[i]` at each sampled column.

The replay (139–225) follows exactly (1)–(2)–(3)–(4)–(5)–(6) from the
captured `before` state, drawing `commitment.rows` proximity challenges
(5173 / 681) before any absorption. Had it drawn them after absorbing the
vectors (the order the `open`/`open_zk` doc comments in `pcs.rs` 311–313 and
895–897 describe), the lambdas would be unchanged but the state entering
step (6) would differ, the sampled indices would not match the opening's, and
the replay would fail at its own index check. The passing index and endpoint
checks therefore pin the real order; the doc comments are stale relative to
the code (a cross-owner comment fix is proposed in §8).

### 4.5 Endpoints and no resampling

The replay compares (a) its final state to `o.after`, the verifier's
transcript cloned immediately after A's `verify_zk` and before H
(`zk.rs` 3746–3747), using `same_transcript` = equal `state()` **and** equal
next `challenge_fp2()` on clones, which also pins the squeeze counter; (b) the
endpoint of an ordinary `pcs::verify_zk` re-run from `o.before` on the copied
observation; and (c) `check_case` asserts the prover's and verifier's
whole-proof transcripts agree after H. There is no loop over seeds or
challenges anywhere in the module: `check_case` proves once and verifies
once; the fresh-OS test calls it exactly twice per mode and asserts the two
roots differ; a degenerate coefficient would `unwrap()`-panic the test rather
than retry. I found no resampling, and none is possible without a visible
test failure.

## 5. The extractor's input boundary

`Observation` (11–18) has six fields; each is verifier-visible:

| Field | Source at capture (`zk.rs` 3744) | Public? |
|---|---|---|
| `params: PcsParams` | `a_pcs = pcs_params(params, lay.log_a_min)` — statement/parameters | yes |
| `commitment: Commitment {root, rows, log_cols}` | `proof.a_com` | yes (proof bytes) |
| `claims: Vec<ZClaim>` | `ac` from `build_claims_zk_v3`: slices/mask rows from the public layout, points and coefficients from verifier challenges, values from proof terminals | yes (recomputable from statement + proof) |
| `opening: OpeningZk` | `proof.a_open`: group vectors incl. the Q folded pad coordinates, proximity vector, Q sampled columns with their salts and Merkle paths | yes (proof bytes) |
| `before: Transcript` | `Transcript::clone_state(tr)` of the verifier transcript before A (no masker is ever installed on the verifier side; `clone_state` asserts that) | yes |
| `after: Option<Transcript>` | clone after A's `verify_zk` | yes |

Not present and not reachable from the module: the prover's `CommittedZk`
(data, full pad table, salts for unopened columns, mask rows), the `ZkRng`
key/state, the witness. `capture` runs on every `cfg(test)` verification but
returns `None` unless a `CaptureGuard` armed the thread-local; `publish`
(65–77) is the last statement before `Ok(())` in `verify_layer_zk_v3`, after
H's `verify_zk` succeeded, so an A-valid/H-invalid proof publishes nothing
(the `?` on H returns first, and the test confirms `guard.take()` is `None`
after a corrupted-H verification that failed with an `H:` error).

Witness truth (`w.x`, `w.h16`, converted to `Fp`) enters only the comparison
loop in `check_case` (411–455), after `replay` and `extract` have returned;
the layout offsets and mask-row indices passed to `extract` come from
`ZkLayoutV3::new(t, 16, 16, params, w.shifts, false)`, whose inputs are all
statement data (`st.shifts == w.shifts`).

**Boundary statement.** This is an in-process observation: the extractor
consumes the verifier's in-memory reconstruction (claims, transcript state)
plus the proof's own opening and commitment, on the same thread that ran the
prover. It does not parse serialized proof bytes, rebuild the claim list from
bytes, or run as a separate process. Everything it uses is a public function
of (statement, proof bytes), so the disclosure is real, but the artefact is a
demonstration harness, **not a standalone FFN byte decoder**. The
separate-process public receipt gates remain distinct evidence.

## 6. Independent derivation of the algebra

Field: `Fp` is Goldilocks (p = 2^64 − 2^32 + 1); `Fp2 = Fp[u]/(u² − 7)`
(`field.rs`: `NONRESIDUE = 7`). For z ∈ Fp2 write z = (z.c0, z.c1).

**Setup.** For a singleton group with lambda λ and the claim
{data part: slice of R = 2^ρ rows from row r0, coefficient a, point p;
mask part: row m, coefficient c, point p[ρ..]}, `zpart_weights` gives row
weights `rw[r0+i] = a·eq_i` with `eq = eq_table_msb(p[..ρ])` and `rw[m] = c`,
and `zk_rhos` gives ρ_g = λ·rw. `fold_rows_host` computes, for each column
j < n, `v[j] = Σ_i ρ_g[i]·M[i][j]` with `M[i][j] ∈ Fp`; the Q pad entries
follow. Hence

    v[j] = Σ_{i<R} (λ a eq_i) D_i[j]  +  (λ c) R_m[j],       D_i[j], R_m[j] ∈ Fp.

Set b := λc and L_b(z) := z.c0·b.c1 − z.c1·b.c0 (= det[z; b] over Fp).

**Facts.** (F1) L_b is Fp-linear. (F2) L_b(b·r) = 0 for every r ∈ Fp, since
(br).c0 = b.c0·r and (br).c1 = b.c1·r. (F3) Multiplication by λ is the
Fp-linear map with matrix [[λ.c0, 7λ.c1],[λ.c1, λ.c0]], whose determinant is
the norm N(λ) = λ.c0² − 7λ.c1², so det(λx, λy) = N(λ)·det(x, y) and
N(λ) ≠ 0 for λ ≠ 0.

**Consequence.** L_b(v[j]) = Σ_i w_i·D_i[j] with
w_i := det(λ a eq_i, λ c) = N(λ)·det(a·eq_i, c) ∈ Fp — the mask term is
annihilated exactly, for every column, with no assumption on R_m.

**(i) T2, R = 1.** eq = [1], w_0 = N(λ)·det(a, c). If w_0 ≠ 0 then
D[j] = L_b(v[j]) / w_0 for all 32 columns: the plane is recovered exactly as
Fp elements, hence as integers (|x| < p/2). The condition w_0 ≠ 0 is
λ ≠ 0 and det(a, c) ≠ 0, i.e. a and c Fp-linearly independent. For the
actual coefficient pairs: under P1, det(1 − e, e) = (1 − e.c0)e.c1 −
(−e.c1)e.c0 = **e.c1**, so recovery fails only if the extension challenge e
(e_gu for X, e_d for h16) lies in the base field, probability about 2^−64 per
proof; under P3 both coefficients carry the same factor s = 1 − e2, so
det = N(s)·e.c1 and the only extra failure case is s = 0. The second P3
extension round therefore does not change the structure. This is precisely
what `eliminate_one_mask` computes: `b = lambda·mask.coef`, `weights[i] =
det(lambda·data.coef·eq_i, b)`, pivot = first nonzero weight,
`values[j] = det(v[j], b)/pivot`; with R = 1, `values = D`. **Confirmed**,
and the log shows it held on all eight T2 proofs (32 functionals = 32 values,
`full_plane_recovered=true`) without any retry.

**(ii) T32, R = 2.** eq = [1 − p_0, p_0] where p_0 is the first coordinate of
the opening point (r_i[0] for X-at-p2, r_ip[0] for h16-at-p5). Then
w_0 = N(λ)det(a(1 − p_0), c), w_1 = N(λ)det(a p_0, c), and
w_0 + w_1 = N(λ)det(a, c). The extractor returns, per column,
`values[j] = D_0[j] + κ·D_1[j]` with κ = w_1/w_0 (or D_1[j] alone if w_0 = 0;
the test asserts both weights nonzero, so that branch did not occur). This
is one base-field linear functional per column with retained, public
row-combination coefficients (1, κ), 256 per plane — **confirmed**, and it is
what the log reports (`data_rows=2`, `disclosed_base_functionals=256`,
`full_plane_recovered=false`). The test checks the functional against
`Σ_r truth[r][j]·row_weights[r]`, not against a one-row formula.

**Why one base-field mask row is one dimension short.** v[j] lives in a
2-dimensional Fp-space; the mask contributes only along the line Fp·b. A
one-time pad for v[j] needs the mask contribution to range over all of Fp2:
either an Fp2-valued mask (two base rows with coefficients b and b·u — the
H "re/im pair" pattern) or two base rows with Fp-independent coefficients.
For the multi-member groups (7, 3, 6 members), the mask contribution is
Σ_k λ_k c_k R_k[j] whose Fp-span is all of Fp2 as soon as two of the λ_k c_k
are Fp-independent (generic), so the *single* group vector of those groups is
per-column hidden and the one-mask eliminator rightly refuses them. That is
a statement about one vector in isolation, not about joint privacy.

**Not an upper bound on leakage.** The T32 result is what this extractor
computes from one group vector. It does not use: the integer ranges of the
data, repeated proofs, the other four group vectors, the proximity vector,
the folded pads, the sampled columns, helper/LogUp sums, or the H and W
openings. See §9 for what a stronger extractor would add.

## 7. Confirmed / refuted table

| Claim in Codex's diagnostic | Verdict | Basis |
|---|---|---|
| A opening groups are [7, 3, 1, 1, 6] in first-occurrence order, P1 and P3 | confirmed | §4.2 derivation; 24/24 log lines |
| The singletons are X at p2 (claim 10, mask `a_mgu[0]`) and h16 at p5 (claim 11, mask `a_mdd[0]`) | confirmed | §4.1–4.3; the `claims.swap(10, 11)` control fails replay as it must |
| At T2 (log_cols 5, rate 4, Q 12) all 32 X and all 32 h16 values are recovered | confirmed | §6(i) algebra; log: 8 proofs, 16 observations, `full_plane_recovered=true` |
| At T32 (log_cols 8, rate 8, Q 256) one base-field functional per column of each two-row plane, coefficients retained | confirmed | §6(ii); log: 4 proofs, 8 observations, 256 functionals each |
| Algebra `v = Σ a_i D_i + b R`, `L_b(z) = z.c0 b.c1 − z.c1 b.c0`, `L_b(bR) = 0` | confirmed, and sharpened: det(1−e, e) = e.c1, so degeneracy ⇔ e ∈ Fp (P1) or additionally 1 − e2 = 0 (P3) | §6 |
| Observer copies only verifier-visible data | confirmed | §5 field table |
| Publish only after the whole FFN (A then H) verifies | confirmed | `zk.rs` 3744–3751; corrupted-H control |
| No resampling | confirmed | §4.5 |
| Replay follows the actual source order (lambdas, prox coefficients, vectors, columns) | confirmed; the `pcs.rs` doc comments describe a different order and are stale | §4.4 |
| Seeded fixture proofs reproduce the recorded hashes | confirmed | six-for-six byte match with `zk60_round7_validation.json` |
| "Not a standalone byte decoder" | confirmed as a limitation | §5 boundary statement |
| Any statement about profiles other than T2/T32 d16/f16, about W disclosure, or about joint privacy | not made by the diagnostic; not established here | §9 |

Nothing in the diagnostic was refuted.

## 8. Controls

### 8.1 Existing controls, what each establishes and does not

| Control (where) | Trips | Establishes | Does not establish |
|---|---|---|---|
| Sampled index `columns[0].0 ^= 1` (`check_case`) | replay's own "sampled column indices" | the replay derives indices from the transcript and compares | Merkle authentication of that column (that is `verify_zk`'s job, reached only if indices match) |
| `group_vecs.swap(2, 3)` | "combined public claim" for group 2 | group order is bound to claim order and lambdas | anything about the vectors' contents |
| Folded pad `group_vecs[2][n] += 1` | transcript divergence → index mismatch (the `<v[..n], c>` check does not see pads) | pads are transcript-bound and part of the public opening | that the ordinary verifier's coset-encoding check would also catch it (it would, at step 7, but this test asserts only `is_err()`) |
| `commitment.root[0] ^= 1` | only inside the ordinary `pcs::verify_zk` re-run (Merkle path) — the replay's own checks never read the root | the replay really invokes ordinary authentication | — |
| `claims.swap(10, 11)` | "combined public claim" | claim ↔ group ↔ vector pairing is bound; incidentally confirms 10/11 are the singletons | — |
| `before.challenge_fp2()` | wrong lambdas → "combined public claim" | the exact captured transcript state is needed | — |
| Column entry `columns[0].1[0] += 1` | ordinary `verify_zk` (leaf hash) | column authentication is retained | — |
| Corrupted final H (`h_open.columns[0].1[0] += 1`) | `verify_layer_zk_v3` returns `H: …`; `guard.take()` is `None` | publish is gated on H, even though A verified and the observation was captured | gating on an A failure (trivially true: `?` returns before `publish`) |
| `extract` with `a_md[0]` | "not a singleton group" | the eliminator refuses multi-member groups | privacy of the three-member group |
| Zero lambda / zero mask coef / rank-degenerate / three parts / wrong arity (`diagnostic_refuses_…`) | the corresponding `Err` strings | the refusal branches exist and fire on synthetic claims | that a degenerate coefficient can occur on a real proof (probability ~2^−64; never observed, and it would fail the test, not be retried) |
| Paired Fp2 masks (`diagnostic_refuses_…`, `zk60_mask_rank.rs::independent_fp2_mask_pair_blocks_…`) | "requires exactly data plus one base mask"; the old coordinate extractor's output ≠ data | one specific extractor fails; by §6 the mask contribution c(R1 + uR2) is uniform over Fp2, so the single vector is a one-time pad for that column | joint privacy when the same mask rows recur in the proximity vector or elsewhere (FA2) |
| `zk60_mask_rank.rs::known_interface_hazard_…` | — (positive) | the same one-base-mask hazard on an isolated PCS with log_cols 2 | anything about the FFN layout (that is what the actual diagnostic adds) |

### 8.2 Missing controls — proposed tests (not applied; owner: the diagnostic module's author)

All in `hashline/src/zk_ffn_mask_diagnostic.rs`, `cfg(test)` only.

**P-1. Structural refusal branches of `replay` are not exercised.** Add to
`check_case`, after the existing tampers:

```rust
// group count, vector length, proximity length, endpoint
let pristine = bad.opening.clone();           // take before the first structural tamper
bad.opening.group_vecs.pop();
assert!(replay(&bad, &ntt).unwrap_err().contains("group count"));
bad.opening = pristine.clone();
bad.opening.group_vecs[0].pop();
assert!(replay(&bad, &ntt).unwrap_err().contains("vector length"));
bad.opening.group_vecs[0].push(Fp2::ZERO); // restore length (value irrelevant: fails earlier next time)
bad.opening.prox_vec.pop();
assert!(replay(&bad, &ntt).unwrap_err().contains("proximity length"));
bad.opening.prox_vec.push(Fp2::ZERO);
bad.after.as_mut().unwrap().challenge_fp2();
assert!(replay(&bad, &ntt).unwrap_err().contains("transcript endpoint"));
```
(restore each field from a clone of `o` before the next tamper).

**P-2. `eliminate_one_mask` branches "mask tail mismatch" and "mask overlaps
data" are not exercised.** Add to `diagnostic_refuses_degenerate_and_paired_mask_controls`:

```rust
let mut c2 = c.clone();
c2.parts[1].point[0] = Fp2::ONE;               // tail differs from data point
assert!(eliminate_one_mask(&c2, Fp2::ONE, &v, 2).unwrap_err().contains("tail mismatch"));
let mut c3 = c.clone();
c3.parts[1].slice.offset = 0;                  // mask row inside the data slice
assert!(eliminate_one_mask(&c3, Fp2::ONE, &v, 2).unwrap_err().contains("overlaps"));
```

**P-3. Non-vacuous truth comparison.** In `check_case`, before the equality
assertions, assert the truth vector is not constant and that the disclosed
values differ from a different fixture's plane:

```rust
assert!(truth.iter().any(|x| *x != truth[0]), "fixture plane is constant");
let other = fixture(t, witness_seed + 7);
let other_truth: Vec<Fp> = other.x.iter().map(|v| Fp::from_i64(*v as i64)).collect();
if t == 2 && name == "X-at-p2" { assert_ne!(disclosed.values, other_truth); }
```

**P-4. Observer inert when unarmed.** New test: prove and verify with no
`CaptureGuard`; then `assert!(OBSERVER.with(|s| s.borrow().is_none()))` and
`assert!(capture(&params, &com, &[], &OpeningZk::default(), &Transcript::new(b"x")).is_none())`.

**P-5. Pin the order explicitly.** New test `replay_with_documented_order_fails`:
copy `replay` but draw the `rows` proximity challenges *after* absorbing the
group vectors (the order the `pcs.rs` doc comments state); assert it fails
with "sampled column indices" on a real observation. This turns §4.4 from
prose into a test and documents the comment discrepancy.

### 8.3 Cross-owner proposals (exact text; not applied)

**C-1. `pcs.rs` doc comments (PCS owner).** Replace the order sentence at
lines 311–313 and 895–897 with:
"Transcript order: lambdas per group -> proximity rho -> group vectors
absorbed -> prox vector absorbed -> column indices (the proximity
coefficients are drawn in `zk_rhos` before any vector is absorbed)."
Comment-only; no bytes change.

**C-2. A W-opening observer under P3 (Codex, `zk.rs`), needed by FA2 to test
the Wd-at-p6 singleton on real proofs.** At `zk.rs` 3737–3738, mirror the A
hook:

```rust
if is_p3 {
    let wcz = build_w_zclaims_v3(&zl, proof, &p3, &p6, (cd_w_gu, e_gu2), (cd_w_d, e_d2));
    #[cfg(test)]
    let w_diag = mask_diagnostic::capture_role(mask_diagnostic::Role::W, &w_pcs, w_com, &wcz, &proof.w_open_zk, tr);
    pcs::verify_zk(&w_pcs, &ZkOpts::standard(&w_pcs), w_com, &wcz, &proof.w_open_zk, ntt, tr).map_err(|e| format!("W: {e}"))?;
    #[cfg(test)]
    let w_end = w_diag.as_ref().map(|_| Transcript::clone_state(tr));
    // ... publish (w_diag, w_end) together with the A observation after H verifies
}
```
with `Observation` gaining a `role` tag and the thread-local slot holding
`Vec<Observation>` (A, W) instead of one. `cfg(test)` only; no production
bytes change. Until this exists, any W statement is source-derived only.

## 9. Handed to FA2 (joint A/H/W exposure) and FA3 (repair)

Source-derived, none executed:

1. **Affected-profile predicate.** X-at-p2 is a singleton iff nb_d = 1, i.e.
   `d / 2^min(tz(d), 12) = 1`: every power-of-two d ≤ 4096 (16, …, 768 is
   *not* — nb_d = 3 — but 4096 is). h16-at-p5 is a singleton iff nb_f = 1:
   f = 2048 yes, f = 3072 and 14336 no (nb_f = 3, 7). For nb ≥ 2 the group has
   nb members and nb masks and the one-mask eliminator does not apply to its
   vector alone. FA2 must classify the real ladder shapes with this predicate
   and then compute joint rank for the multi-member cases.
2. **Integer ranges turn the T32 functionals into full recovery.** Per column,
   D_0 + κD_1 with |D_i| ≤ 127 has at most 255² < 2^16 candidates against a
   2^64 modulus, so the pair is unique with overwhelming probability and found
   by enumeration; for int16 h16, meet-in-the-middle costs ~2·2^16 per column.
   For R rows and a single proof this is an R-dimensional bounded knapsack mod
   p (≈8R unknown bits vs 64), lattice-reducible for small R.
3. **Repeated proofs of the same witness** give independent κ's: R proofs of an
   R-row plane recover it by linear algebra without any range assumption.
4. **Known-mask chaining.** Once D_X is known (T2), R_{a_mgu}[j] =
   (v[j] − λaD_X[j]) / (λc) is known, and that row also appears in the
   proximity vector with a public coefficient; the same for R_{a_mdd}. h16 is
   additionally a member of the 7-group at rho_f, so its recovery removes one
   unknown row from that vector. FA2's rank model must treat masks recovered
   through singletons as known.
5. **P3 W.** `build_w_zclaims_v3` opens Wg and Wu at p3 (two masks, one group)
   and Wd at p6 (mask `w_mdd[0]`); at nb_d·nb_f = 1 the Wd-at-p6 group is a
   one-base-mask singleton. With `log_wn = min(log_cols, log_wb)`: at T32 /
   log_cols 8 and d = f = 16, `w_n = 256` equals the block size, so the whole
   Wd block would be one row and fully recoverable by the same eliminator; at
   T2 / log_cols 5 it is 8 rows → 8-row functionals. Requires the C-2 hook to
   test; this is the model-weight side of the same defect and is not covered
   by any executed evidence yet.
6. **Multi-member groups, proximity vector, pads, H.** Single-vector hiding
   for ≥ 2 members needs Fp-span{λ_k c_k} = Fp2 (generic); the joint system
   (group vectors + proximity vector + Q sampled columns, with mask rows
   reused across them) is what FA2's rank tool must model, keeping
   single-proof and repeated-proof observations distinct. H helper planes use
   re/im pairs; the H u-row has a cross-column zero-sum constraint (one fewer
   free mask coordinate).
7. **For FA3:** whatever the repair, the property to restore is that every
   clear vector's mask contribution is uniform over Fp2 per column *and*
   mask coordinates are single-use across all vectors in which they appear
   (group vectors, proximity vector, and the encoded sampled columns via
   pads).

## 10. Limits of this review

- One run, one host, CPU only, two threads, cold build; timing is not a
  measurement (the box is shared and not quiesced).
- Only the four `mask_diagnostic` tests were run; I did not rerun the full
  Rust suite, the Python suite, or the frozen-artifact gates (Codex's record
  covers those at `9cf1372`, and the three relevant sources are byte-identical
  at `52a13d1`).
- The profiles are the diagnostic's own: d = f = 16 with T ∈ {2, 32}, a
  synthetic LCG witness. No deployed shape, no model data, no GPU.
- The in-process boundary of §5 applies: no serialized-bytes decoder was built
  or run.
- I confirmed the plane-to-witness mapping (`lay.x[0]`, `lay.h16[0]` vs
  `w.x`, `w.h16` order) only through the passing equality assertions in the
  test, not by an independent layout dump.
- I did not audit `prove_layer_zk_v3` for resampling loops; the seeded proof
  hashes matching Codex's record show the prover is deterministic under a
  fixture seed, and the diagnostic itself never resamples.
- The probability statements (degeneracy ≈ 2^−64, tail collisions) are
  derived, not measured; no degenerate case was observed in 12 proofs.
- Nothing here approves P3 identity, private generation, joint privacy or a
  repair; FA1 establishes that the disclosure Codex reported is real,
  correctly bounded, and reproduced from verifier-visible data alone.

Mirror of the key facts: `results/zk60_fable_fa1_review.json`. Retained log:
`results/zk60_fable_fa1_mask_diagnostic.log` (+ `.done`).

---

# Part 2 — FA2: joint exposure and affected profiles

**Reviewer:** Claude Fable 5.1, independent reviewer, 2026-09-07 session.
**Builds on:** Part 1 (FA1) above, at the same pin (`zk.rs`, `pcs.rs`,
`zk_ffn_mask_diagnostic.rs`, `zk60_mask_rank.rs` hashes in §1). No source
file was changed. No Rust build or Rust test was run for FA2; the inputs are
the pinned source, FA1's retained log and Codex's round-10 record
(`ZK60_ROUND10.md`, main checkout). Part 1 is unchanged (I found no factual
slip in it).

**Executed vs derived.** The only executed evidence in this part is the
Python rank tool and its tests (§15: 22 tests, exit 0) on models whose
*structure* is the source's and whose *coefficients* are pseudo-random
stand-ins for transcript challenges. Every statement about H and about the
P3 W opening is **source-derived and awaiting capture** — the H / P3-W
observer hook Codex named as its next work in `ZK60_ROUND10.md` (the P3
`wcz` branch and the final `hc` call in `verify_layer_zk_v3`) does not
exist at this pin, so no H or W vector, value or column has been observed.
Only the A observations of §3 are executed (by FA1), and even for those the
rank tool has not yet been run on captured coefficients (§19).

## 11. What "joint exposure" means here

FA1 established that one clear vector of a singleton group with one
base-field mask row discloses one base-field functional per column. FA2
asks what the *whole* set of verifier-visible observations discloses when
the same mask rows appear in several of them, across the A, H and (under
P3) W openings, for one proof and for repeated proofs. The observations
are enumerated in §12 and in `results/zk60_fable_fa2_observations.json`;
the linear model and its limits are in §13; the rules the model yields, with
derivations, in §14; the tool and its fixtures in §15; the impact matrix in
§16–17; the unresolved assumptions FA3 must address in §18.

## 12. Observation enumeration (source-derived; status per row)

Every observation below is a public function of (statement, proof bytes).
"Coefficients" are drawn from the verifier transcript *after* the three
roots and every masked terminal are absorbed (`verify_layer_zk_v3`,
`zk.rs` 3472–3751; `zk_rhos`, `pcs.rs` 817–838: lambdas per group, then the
proximity coefficients, both before any vector is absorbed — FA1 §4.4).
"Reuse" names the other observations the same mask row enters. Status:
**executed** = present in FA1's twelve proofs; **source-derived** = read
from the pinned source, not captured; **awaiting capture** = needs the
Codex hook; **outside linear model** = not a linear functional of committed
rows. A missing observation is listed, never assigned zero cost.

| Id | Commitment / role (claims of `build_claims_zk_v3` 3323–3469, `build_w_zclaims_v3` 3292–3321) | Domain; base rows combined | Coefficient provenance | Mask support | Reuse identity | Status |
|---|---|---|---|---|---|---|
| A.vec.rho_f | group vector at tail(rho_f): 7·nb_f planes g8,rg,a16,u16,ru,h16,rh | Fp2 × n (+Q pads); rows_f rows per plane; masks `a_mf[k]` | λ_k (pcs-group), (1−e_f)·eq_r(row bits), e_f | one base row per plane | `a_mf[k]` also in A.vec.prox and A.value (zc20_term[10b+i]); h16's rows re-opened at p5 | executed |
| A.vec.rho_d | group vector at tail(rho_d): 3·nb_d planes X,z,rd | Fp2 × n; rows_d rows per plane; `a_md[k]` | λ_k, (1−e_dz), e_dz | one base row per plane | `a_md[k]` in prox and zc17_term; X's rows re-opened at p2 | executed |
| A.vec.p2 | group vector at tail(p2 = r_i‖r_kp): nb_d X blocks | Fp2 × n; `a_mgu[c]` | P1 (1−e_gu, e_gu); P3 ×(1−e_gu2) | one base row per block | `a_mgu[c]` in prox and gu_term[c] | executed (nb_d = 1) |
| A.vec.p5 | group vector at tail(p5 = r_ip‖r_k): nb_f h16 blocks | Fp2 × n; `a_mdd[b]` | P1 (1−e_d, e_d); P3 ×(1−e_d2) | one base row per block | `a_mdd[b]` in prox and d_term[b] | executed (nb_f = 1) |
| A.vec.tab | group vector at tail(rho_tab): six multiplicity slots | Fp2 × n; slot i: rows_i = max(size_i, n)/n rows of m and of mask, same eq weights | λ_i, (1−e_tab)·Π_{j<k_i}(1−rho_tab_j), e_tab·Π | same-shaped base block; **Fp2-effective per column when rows_i ≥ 2** | mask blocks in prox and tab_term[2i] | executed |
| A.vec.pred | FUNCTION 2 only: tail(rho_p): z block (`a_pmz`) + bit row `a_pb` (`a_pmb`) | Fp2 × n | (1−e_p), e_p, ext coef | two base rows | both in prox and pred.term; z block also at rho_d | source-derived |
| A.vec.prox | proximity vector | Fp2 × n; **every** row of A | fresh ρ_i per row | `a_prox` (its only site) + every A mask row | second appearance of every mask row | executed (contents not analysed by the diagnostic) |
| A.value.* | terminals zc20_term[10b+i<7], zc17_term[<3nb_d], gu_term[<nb_d], d_term[<nb_f], tab_term[2i], pred.term | Fp2, one per claim; the claim's rows with eq_r·eq_col weights | column weights eq(point tail) × the claim pair | the claim's own mask | **third** appearance; for m members only the λ-combination is implied by the vector | executed (present in every proof; not used by the diagnostic) |
| A.pads | folded pad coordinates v_g[n..n+Q) of every vector | Fp2 × Q per vector; ρᵀ·pads | same ρ as the message part | fresh pads | pads also inside the sampled columns | executed |
| A.columns | Q sampled encoded columns, salts, paths | Fp × rows per column; (f_row + Z_n·g_pad)(coset point) | public encoding at `challenge_indices` points (may repeat: `transcript.rs` 119–131 masks with `bound−1`) | the Q pads of every row | pads also in A.pads | executed |
| H.vec.rho_f | tail(rho_f): 3·nb_f helper planes hg,hu,hh (Fp2-valued, re/im rows) | Fp2 × n; masks `h_mf[k]` = (re, im) | λ_k, (1−e_f), (1−e_f)·u, e_f, e_f·u | **Fp2 pair** | masks in prox and zc20_term[10b+7+i]; helper rows also in H.vec.sum | awaiting capture |
| H.vec.rho_d | tail(rho_d): nb_d hz planes | as above with e_dz; `h_md[c]` pairs | | Fp2 pair | prox, zc17_term[3nb_d+c], H.vec.sum | awaiting capture |
| H.vec.zsum | rho_zs (single-row point): u masked by u′ | Fp2 × n; `h_u`, `h_up` pairs | λ, (1−e_zs), e_zs (× u on im) | u′ pair, fresh | u also carries H.vec.sum; u′ also in prox | awaiting capture |
| H.vec.tab | tail(rho_tab): six table-helper slots h_t | Fp2 × n; `h_re/h_im` blocks, `h_mre/h_mim` blocks | λ_i, (1−e_tab)·ext_i, e_tab·ext_i (× u) | Fp2 pairs (block-shaped) | prox, tab_term[2i+1], H.vec.sum with (−1, −u) | awaiting capture |
| H.vec.sum | the LogUp identity as one value-0 sum claim (empty point → all-ones column weights): helpers (+1,+u), table helpers (−1,−u), u (+1,+u) | Fp2 × n; every helper row, u_re, u_im | one λ; fixed ±1/±u | **only the u pair, constrained Σ_j u[j] = 0** (`zk.rs` 2662–2665) | u also in H.vec.zsum and prox | awaiting capture |
| H.vec.prox | proximity vector | every H row | fresh ρ_i | `h_prox` (**a single base row**) + all H masks | second/third appearance | awaiting capture |
| H.value.* | zc20_term[10b+7..10), zc17_term[3nb_d..4nb_d), zs_term, tab_term[2i+1]; the sum claim's value is the constant 0 | Fp2 | column weights | Fp2 pairs | third appearance | awaiting capture |
| W3.vec.p3 | P3 only, tail(p3 = r_kp‖r_j): 2·nb_d·nb_f Wg/Wu blocks | Fp2 × w_n; rows_w rows per block; `w_mgu[k]` | λ_k, (1−e_gu2)(1−e_gu)·eq_r, e_gu2 | one base row per block | prox and gu_term[nb_d+k] | awaiting capture (FA1 C-2) |
| W3.vec.p6 | P3 only, tail(p6 = r_k‖r_jp): nb_d·nb_f Wd blocks | Fp2 × w_n; `w_mdd[k]` | λ_k, (1−e_d2)(1−e_d)·eq_r, e_d2 | one base row per block | prox and d_term[nb_f+k] | awaiting capture |
| W3.vec.prox | P3 proximity vector | every W row | fresh ρ_i | `w_prox` + the 3·nb_d·nb_f block masks | second appearance | awaiting capture |
| W3.value.* | gu_term[nb_d..], d_term[nb_f..] | Fp2 | column weights | one base row | third appearance | awaiting capture |
| W1.plain | P1 W: plain opening of public weights | — | — | none (no privacy claim) | — | n/a |
| M.cfs | the CFS mask commitment: masked round polynomials of the 6 (7) sumchecks, masked claimed sums (gu_claim, d_claim, γ's), `mask_open` functionals (eval at ρ, cube sums), M's own proximity combination and MASK_Q columns (`zk.rs` 605–660, 1171–1194) | Fp2; the CFS masks' coefficient rows, **not** A/H/W rows | θ, r_row, sampled indices | the CFS masks | each sumcheck's mask is both evaluated at ρ and summed; the round messages depend nonlinearly (products) on A/H/W data | outside linear model |
| cross | the verifier's terminal checks tying A, W and H terminals (e.g. `want = Σ gu_term[c]·sel·Σ λ_f wg…`) | — | — | — | public identities on public values; no new observation | source-derived |

The full record with the per-row verdicts is
`results/zk60_fable_fa2_observations.json`.

## 13. The linear model

**Unknowns.** Base-field scalars: one per (row, column) of a commitment,
split into data rows D and mask rows R. Pads and salts are handled by the
argument of §14.6 and are not unknowns of the rank model.

**Observations.** Each Fp2 observation is a public-coefficient linear form
Σ_i a_i·M[i][j] with a_i ∈ Fp2 and M[i][j] ∈ Fp. Since a·x = (a.c0·x, a.c1·x)
for base x, one Fp2 observation is **two base-field rows** of the
observation matrix; an Fp2-valued *unknown* (the H re/im pairs) is two base
columns r, s with a·(r + u·s) = (a.c0 r + 7a.c1 s) + u(a.c1 r + a.c0 s). This is
the projection FA1's L_b functional lives in: L_b is one row of the left
null space of the mask sub-matrix.

**Computation** (`scripts/zk60_fable_joint_rank.py`, exact Gaussian
elimination over p = 2^64 − 2^32 + 1): observation matrix [A | B] (data |
mask columns); rank(B); rank([A|B]); N = left null space of B; F = N·A =
the data functionals that survive mask elimination; `disclosed_dim` =
rank(F) = rank([A|B]) − rank(B). Per data unknown: **recovered** (its unit
vector is in the row space of F), **disclosed** (a surviving functional has a
nonzero coefficient on it), **protected** (none does). The number of
null vectors that also kill the data (`observation_functionals_killing_
masks_but_not_data`) counts the trivial identities — one Fp2 identity
Σ_j cw_j v_g[j] = Σ_k λ_k value_k per group.

**Transcript-conditioning assumption.** λ, ρ, e, the points and the column
indices are treated as fixed public constants. They are in fact functions
of the masked messages absorbed before them; conditioning on their values
is what the linear model does and a simulator argument must justify it
(§18 U2). The fixture coefficients are pseudo-random stand-ins (structure
from the source, values not from any proof), so every rank result is a
*generic-coefficient* result; the degenerate cases (e ∈ Fp, λ = 0) have
probability ≈ 2^−64 per draw (FA1 §6) and are excluded by the stand-in
generator, and the tool reports them correctly when fed one (§15 test
`test_degenerate_base_field_e_is_not_disclosed_by_L_b`).

**What the model does not settle** (stated once here, repeated in the tool's
docstring and every result's `caveat` field): nonlinear observations (the
CFS-masked sumcheck round messages, hash commitments), adaptive challenge
dependence, integer-range side information, and cross-proof correlation
beyond "the same data row appears in R proofs under R independent
coefficient sets". **Numerical rank is not a simulation proof**; a
`protected` verdict means only that no nonzero linear functional of that
unknown survives elimination in this observation set with these
coefficients.

## 14. Rules the model yields (each derived, each checked by a fixture)

Throughout, a group has m members, the commitment has n columns, and a
member's mask is **Fp2-effective** per column if its per-column
contribution ranges over all of Fp2 as the mask entries range over Fp: an
(re, im) pair (H), or a base-field mask slice spanning ≥ 2 rows whose row
weights (1 − p_0, p_0), p_0 ∉ Fp, are Fp-independent (the INT16 table slot
at log_n ≤ 15). A single base row is not (its contribution is the line
Fp·(λc)).

### 14.1 Singleton, one base row (FA1, re-checked)

Observations: the vector (2n base dims) and the value (2 dims, implied by
the vector — the trivial identity). Mask rank n. **Surviving: n
functionals, one per column, of the member's rows** — the whole row when
the plane is one row (T2), (1, κ) two-row combinations at T32 (fixture (c),
κ re-derived in the test as det(λa p_0, λc)/det(λa(1−p_0), λc) and equal to
the tool's normalised coefficient; also w_0 + w_1 = det(λa, λc), and for the
P1 pair w_0 = N(λ)·e.c1 exactly as FA1 §6 states).

### 14.2 All-base multi-member group: exactly two surviving base functionals (new)

The vector gives, per column j, Σ_k λ_k c_k R_k[j] (plus data); the m public
terminal values give, per member k, c_k Σ_j cw_j R_k[j] (plus data). Write
R as the m × n base matrix of mask entries. The mask map is
B: R ↦ (Rᵀ·Λ, R·C) with Λ = (λ_k c_k)_k ∈ Fp2^m and C = (cw_j)_j ∈ Fp2^n.
Its kernel is {R : every column ∈ ker Λ, every row ∈ ker C} = K1 ⊗ K2 with
dim (m − 2)(n − 2) when Λ and C each span Fp2 over Fp (generic for m, n ≥
2). Hence **rank B = mn − (m−2)(n−2) = 2m + 2n − 4**, against 2n + 2m
observation dims of which 2 are the trivial identity: **two nontrivial
base-field functionals of the members' data survive**, for every m ≥ 2 and
every n ≥ 2, independent of m and n. Fixtures (e): (m, n) ∈ {(2,2), (2,4),
(3,4), (7,4), (7,8), (9,4)} all give rank B = 2m + 2n − 4 and
disclosed_dim = 2, and the kernel count mn − rank B = (m−2)(n−2) is asserted
in the tests. The leaked functionals mix all members' entries (every data
unknown is `disclosed`, none `recovered`).

Consequence for the source: the 7·nb_f-member rho_f group, the 3·nb_d-member
rho_d group, X-at-p2 for nb_d ≥ 2, h16-at-p5 for nb_f ≥ 2, the function-2
predicate pair, and every P3 W group each leak two base-field functionals
of their planes per proof — from the terminal values, which FA1's
extractor did not use. This is small per proof but it is nonzero, it is
linear, and it accumulates over proofs (§17).

### 14.3 Any Fp2-effective member covers the group

With member 1 Fp2-effective, choose the other members' masks to hit their
value targets (2 equations in n ≥ 2 base unknowns each), then set member
1's Fp2 entries column by column to hit the vector; its own value is then
forced by the identity. Rank = 2m + 2n − 2 = observations − identity:
**disclosed 0**. Fixtures (f): three pairs; (base1, base2, base1); (pair,
base1) — all 0. This is why H's claims (all pairs) and the A table group at
log_n ≤ 15 (the INT16 slot spans 2^16/n ≥ 2 rows) are covered in the linear
model, and why the same group *would* leak 2 at log_n = 16, where every
table slot is one row (the layout assertion allows log_cols ≤ 16).

### 14.4 The proximity vector is covered only by borrowed freedom

The prox vector's mask contribution per column is Σ_m ρ_m R_m[j] +
ρ_prox R_prox[j]. The reserved prox row is **one base row** in A, H and W
(`a_prox`, `h_prox`, `w_prox`), so it covers one of the two base dimensions
per column; the second must come from mask rows that are not already
pinned by their group vectors and values. Whole-commitment models with all
groups, all values and the prox (fixtures (i)): tiny A at n = 4 gives
disclosed = 2n + 2 + 2 — exactly the two singletons plus the rho_f and rho_d
value leaks, i.e. the prox adds nothing when the 7- and 3-member groups
have residual freedom; tiny H gives 0. But fixture (g) (one 3-member
all-base group alone + prox) gives 4, not 2, and the **tiny P3 W**
commitment (masks `w_mgu[0], w_mgu[1], w_mdd[0], w_prox` = 4 base rows per
column against 6 base observation dims) gives **one extra functional of
(Wg[j], Wu[j]) per column** on top of the p6 singleton and the p3 values:
disclosed = 2n + 2 in the whole model, 2 per column in the per-column
model. At nb_d·nb_f ≥ 3 (125M, 8B) the W prox is covered (10 and 22 masks
per column vs 6 dims). FA1's inventory remark "H's dedicated proximity
reservation is not an Fp2 pair" is therefore a real structural dependency:
the prox vector's hiding depends on the *composition* of the other groups.

### 14.5 The constrained zero-sum row u

The LogUp sum claim's only mask is the u pair with Σ_j u_re[j] = Σ_j u_im[j]
= 0. Its 2(n − 1) free base dims pad every column functional except
Σ_j v_sum[j], whose data part is the LogUp identity Σ helpers − Σ table
helpers and whose value is the public claim value 0. Modelled jointly with
the helper and table groups (pairs), the zsum claim (u masked by u′), every
value and the prox (fixture `h_logup_sum_zero_sum_u`, n = 4 and n = 8): the
surviving space has dimension 2 and **equals the span of the identity's two
base rows** (rank F = rank I = rank(F ∪ I) = 2, asserted). So u is covered
by a stated argument, not by rank alone: the one surviving functional is
information the verifier is *supposed* to learn.

### 14.6 Folded pads and sampled columns (argument, not rank)

`encode_row_zk` (`pcs.rs` 583–603) evaluates f_row + Z_n·g_pad on the coset
h·G_nn (h = 7, `coset_powers` asserts h^nn ≠ 1 so Z_n ≠ 0 on the coset); the
Q pad symbols are the coefficients of g_pad (degree < Q). On the S ≤ Q
distinct sampled coset points, pad ↦ (Z_n(x) g_pad(x))_{x∈S} is
diag(Z_n)·Vandermonde, of full row rank, so for every row the sampled
entries are a bijective image of that row's fresh pads given its message:
uniform and independent of the data. The folded pad coordinates v_g[n..)
are then determined by the message parts and the sampled columns (the
coset-encoding check the verifier performs is an identity in them), so
neither adds information beyond the message parts of the vectors.
Requirements: q_pad ≥ num_col_checks (asserted in `commit_zk_owned` and
`verify_zk`), and repeated indices from `challenge_indices` only shrink S.
Unopened columns rest on the salted Merkle leaves — a computational hash
assumption outside the linear model (§18 U8).

### 14.7 Terminal cross-checks

The sumcheck terminal checks relate public terminals of A, W and H; each
is an identity in values already counted. They add no observation.

## 15. The rank tool, fixtures and cross-checks (executed)

`scripts/zk60_fable_joint_rank.py` (stdlib only; `analyze MODEL.json`,
`fixtures`, `impact`). Input: data/mask unknown names and observations with
integer coefficients mod p (an Fp2 coefficient is a two-element list; an
Fp observation is one row). Output: the ranks, the surviving data
functionals (reduced), the mask-killing observation functionals, and the
per-unknown status; every result carries the caveat that numerical rank is
not a simulation proof.

| Fixture (contract) | Model | Tool | Independent check in the test |
|---|---|---|---|
| (a) known-deficient singleton, P1 and P3 | 1 mask row, one Fp2 obs (2 rows) | disclosed 1, `D` recovered | the null functional ∝ (b.c1, −b.c0) = L_b; D = L_b(v)/w_0 on random (D, R); w_0 = N(λ)e.c1 (P1), N(λ)N(1−e2)e.c1 (P3) — FA1 §6(i) |
| (b) independent Fp2 mask pair | masks (b, b·u) | disclosed 0, `D` protected; degenerate pair (b, r·b) → disclosed 1 | the pair is a one-time pad: for fixed v every D has exactly one (r, s) |
| (c) T32 two rows, one mask | weights λa(1−p_0), λa p_0 | disclosed 1, functional (1, κ) | κ from the det formula; w_0 + w_1 = det(λa, λc) — FA1 §6(ii) |
| (d) reuse | R in a singleton vector and in a prox-like obs with R_p | disclosed 2 (D1, D2 recovered); control with a fresh R′ → 1 (D2 protected) | — |
| (e)/(f) group + values | all-base m ∈ {1,2,3,7,9}; pairs; mixed | rank B = 2m+2n−4, disclosed 2 (m ≥ 2), n (m = 1); 0 with any Fp2-effective member | kernel dim (m−2)(n−2) |
| (g) one group + prox | 3 all-base members + prox | disclosed 4 | (shows the prox borrowing) |
| (h) LogUp sum | §14.5 joint model, n = 4, 8 | disclosed 2 = the public identity | rank F = rank I = rank(F∪I) = 2 |
| (i) whole commitments, n = 4 | tiny A (rows 1 and 2, P1 and P3), tiny H, tiny P3 W, nb_d = 3 W | A: 2n + 4 (rows 1: X and h16 recovered); H: 0; W tiny: 2n + 2 with Wd recovered; W nb_d = 3: 4 | — |
| per-column, four layouts | A, H, W(P3) at T2, T32, 125M, 8B | A: #singletons (2, 2, 1, 1); H: 0; W: 2, 2, 0, 0 | — |

Command and result:

```
python3 -m unittest discover -s /home/victor/wt-zk60-fa/tests -p 'test_zk60_fable_joint_rank.py' -v
Ran 22 tests in 0.759s   OK        (exit 0)
python3 scripts/zk60_fable_joint_rank.py fixtures -o results/zk60_fable_fa2_rank_cases.json   (exit 0)
python3 scripts/zk60_fable_joint_rank.py impact   -o results/zk60_fable_fa2_impact.json       (exit 0)
```

Cross-check status: fixtures (a) and (c) agree with FA1's derivation
(independent formulas in the test, not read back from the tool); (b) agrees
with the `zk60_mask_rank.rs` paired-mask control; (d) is new. **The tool has
not been run on captured coefficients** — FA1's observer holds the A claims
and opening in memory but no export exists (§19).

## 16. Affected-profile predicate and layout numbers

From `LayoutV3::new` (`layer.rs` 1284–1313) and `ZkLayoutV3::new` (`zk.rs`
2093–2145), mirrored by `layout_v3()` in the tool and asserted in the tests:
log_db = min(tz(d), 12), nb_d = d / 2^log_db; log_fb = min(tz(f), 12), nb_f =
f / 2^log_fb; log_n = min(log_cols, log_t + min(log_db, log_fb)); rows per
f-plane = T·2^log_fb / n; per d-plane = T·2^log_db / n; W: log_wn =
min(log_cols, log_db + log_fb), rows per block = 2^(log_db+log_fb) / w_n;
table slot rows = max(size, n)/n with sizes (256, 2^16, 2^7, 2^0, 2^14, 2^6)
for shifts (7, 0, 14, 6).

| Family | nb_d | nb_f | log_n at T = 32 | rows/f-plane | rows/d-plane | rows/W block | table rows | singleton roles |
|---|---|---|---|---|---|---|---|---|
| tiny T2 d16/f16, log_cols 5 | 1 | 1 | 5 (T = 2) | 1 | 1 | 8 (w_n 32) | 8, 2048, 4, 1, 512, 2 | X@p2, h16@p5, Wd@p6 |
| tiny T32 d16/f16, log_cols 8 | 1 | 1 | 8 | 2 | 2 | 1 (w_n 256) | 1, 256, 1, 1, 64, 1 | X@p2, h16@p5, Wd@p6 |
| 125M d768/f2048, log_cols 14 | 3 | 1 | 13 (14 for T ≥ 64) | 8 (16 at T = 128) | 1 (2 at T = 128) | 32 (w_n 2^14) | 1, 8, 1, 1, 2, 1 | h16@p5 |
| 8B d4096/f14336, log_cols 14 | 1 | 7 | 14 (T ≥ 8) | T/8 (4 at T = 32) | T/4 (8 at T = 32; 2 for T ≤ 8) | 512 (w_n 2^14) | 1, 4, 1, 1, 1, 1 | X@p2 |

The T sweep (T = 2 … 128) is in `results/zk60_fable_fa2_impact.json`
(`t_sweep`). Note the cap: at 125M, log_n = log_t + 8 < 14 for T < 64, so the
h16 plane is 8 rows for every T ≤ 64 (16 at T = 128); at 8B the X plane is 2
rows for T ≤ 8 and T/4 rows above.

## 17. Impact matrix (role × profile family)

Verdicts: **affected** = a nonzero linear leak in the model (with its size
per proof); **covered** = zero in the model *with the stated argument*;
**unresolved** = outside the model or awaiting evidence. Single-proof
figures; repeated proofs in §17.1. "H", "W(P3)" rows are awaiting capture.

| Role | tiny T2 | tiny T32 | 125M | 8B | Argument / missing observation |
|---|---|---|---|---|---|
| A rho_f (7·nb_f planes) | affected: 2 fn | affected: 2 fn | affected: 2 fn (m = 7) | affected: 2 fn (m = 49) | §14.2 (terminal values); executed vectors, values not yet fed to the tool |
| A rho_d (3·nb_d) | affected: 2 fn | affected: 2 fn | affected: 2 fn (m = 9) | affected: 2 fn (m = 3) | §14.2 |
| A X at p2 | **affected: whole X plane** (32 values; executed) | affected: 256 fn of 2 rows (executed); int8 → 16 bits/col: unique w.h.p., enumerable (derived) | affected: 2 fn (m = 3) | **affected: singleton**, n = 16384 fn of T/4 rows: T ≤ 8 → 2 rows (16 bits, enumerable); T = 16 → 4 rows (32 bits); T = 32 → 8 rows (64 bits, not unique from one proof; 8 proofs) | §14.1 + FA1 item 2 (ranges not executed) |
| A h16 at p5 | **affected: whole h16 plane** (executed) | affected: 256 fn of 2 rows (executed); int16 → 32 bits/col enumerable (derived) | **affected: singleton**, 8-row fn per column (128 bits; not unique from one proof; 8 proofs linearly) | affected: 2 fn (m = 7) | §14.1 |
| A tables (6 slots) | covered | covered | covered | covered | §14.3: INT16 slot ≥ 2 rows ⇒ Fp2-effective; **at log_n = 16 → affected 2 fn** |
| A predicate pair (function 2) | affected: 2 fn of (z block, slack bits) | same | same | same | §14.2; source-derived, no function-2 proof run |
| A proximity | covered per column | covered | covered | covered | §14.4: borrowed freedom from the 7-/3-member groups (per-column models: disclosed = #singletons only) |
| A terminal values | included above | | | | §12 A.value.* |
| A pads / sampled columns | covered by argument + hash assumption | | | | §14.6 |
| H rho_f / rho_d / zsum / tables | covered (linear) — awaiting capture | | | | §14.3 Fp2 pairs; per-column and whole models 0 |
| H LogUp sum (u, zero-sum) | covered by argument — awaiting capture | | | | §14.5: residual = the public identity |
| H proximity | covered per column — awaiting capture | | | | §14.4; `h_prox` is one base row |
| W(P3) Wg/Wu at p3 | affected: 2 fn (m = 2) | affected: 2 fn | affected: 2 fn (m = 6) | affected: 2 fn (m = 14) | §14.2; awaiting capture |
| W(P3) Wd at p6 | **affected: singleton**, 32 fn of 8-row combinations (int4 fixture weights → 32 bits/col enumerable) | **affected: whole Wd block** (256 values, one row) | affected: 2 fn (m = 3) | affected: 2 fn (m = 7) | §14.1; FA1 item 5; awaiting capture (C-2 hook) |
| W(P3) proximity | **affected: +1 fn of (Wg[j], Wu[j]) per column** | same | covered | covered | §14.4: 4 masks vs 6 dims per column at nb_d·nb_f = 1 |
| W(P1) | n/a (public) | | | | |
| CFS mask commitment / round messages | unresolved | unresolved | unresolved | unresolved | outside the linear model (§12 M.cfs) |
| Executed H / P3-W capture | unresolved (missing) | | | | Codex round-10 hook does not exist yet |

Machine-readable: `results/zk60_fable_fa2_impact.json` (roles, layouts, the
T sweep, and the per-column / group-value model results per family).

### 17.1 Single-proof vs repeated-proof (kept distinct)

Single-proof figures above are what one accepted proof discloses in the
linear model. Repeated proofs redraw every challenge, so a data row present
in R proofs is observed under R independent coefficient sets and the
functionals accumulate: (i) a singleton role's R-row plane is recovered
linearly after R proofs (FA1 item 3), with no range assumption; (ii) an
all-base multi-member group yields 2 fresh functionals per proof (linear
recovery after (data dims)/2 proofs — impractical for large planes alone,
but each functional is exact and composes with range information);
(iii) **P3 weights are identical in every proof by construction**, so the
accumulation applies to W in full: at nb_d·nb_f = 1 two proofs recover Wg,
Wu and Wd entirely (Wd from one, the (Wg, Wu) column pairs from two), and
at 125M/8B four exact functionals of the weights per proof; (iv) for
activations the accumulation applies only when the same X is re-proven.

## 18. Unresolved assumptions FA3 must address

U1. **Generic coefficients.** Every rank result uses stand-in challenges.
    The tool must be run on *captured* coefficients: for A this needs an
    export from FA1's observer (claims + lambdas + prox ρ + vector message
    parts + terminal values), for H / P3-W the hook of §19.
U2. **Transcript conditioning.** λ, ρ, e and the points are drawn after the
    masked messages; the linear model conditions on them. A simulator must
    argue that programming/conditioning is sound (standard in the ROM, but
    it is an assumption of the model, not a result).
U3. **Terminal values are individually public**, so *every* claim masked by
    a single base row leaks (§14.2). The repair must make every masked
    claim's mask Fp2-effective (a pair, or a ≥ 2-row slice with a
    non-base row coordinate) — for the A planes, the P3 W blocks, the
    function-2 pair, and the table slots at log_n = 16.
U4. **Mask reuse across vector, value and prox** must be shown full-rank
    jointly, not site by site; in particular the prox row is one base row
    in A, H and W and its second dimension is borrowed (§14.4). The repair
    should give the proximity combination its own Fp2-effective mask so
    that coverage does not depend on which other groups exist.
U5. **The zero-sum u pair** covers the LogUp sum only up to the public
    identity (§14.5); this must be re-verified for the repaired layout,
    and u′ must stay fresh and unconstrained.
U6. **The CFS channel** (round messages, masked claimed sums, `mask_open`)
    is outside the linear model and was not reviewed here.
U7. **Ranges and repeats amplify** anything the linear model leaves
    (§17.1): the repair's target is zero linear leak per proof *and* fresh,
    independent masks per proof so that repeated observations are
    independent uniform values.
U8. **Pads and columns**: the argument needs q_pad ≥ Q (asserted), Z_n ≠ 0
    on the coset (asserted), and the salted-leaf hash for unopened columns
    (computational). Duplicate sampled indices reduce distinct points and
    Q's soundness, not hiding.
U9. **Function 2**: the predicate group is a 2-member all-base group (§12
    A.vec.pred); no function-2 proof has been observed by either review.
U10. **log_cols = 16** is allowed by the layout assertion and turns the
    table masks single-row (§14.3).
U11. **P3 W**: the model-weight side of the defect (Wd singleton, p3/p6
    values, the starved prox at nb_d·nb_f = 1) is source-derived only; it
    interacts with FA4's identity question but is a separate leak.
U12. **Aliasing**: the model re-opens the same X rows at rho_d and p2 and
    the same h16 rows at rho_f and p5 (as the source does); the capture
    should confirm the row identities on real claims.

## 19. What FA2 needs from the H / P3-W capture (Codex handoff)

The same six fields the A observer already copies (`Observation`,
`zk_ffn_mask_diagnostic.rs` 11–18; FA1 §5), per role, published together
and only after the whole FFN verifies:
`params: PcsParams` (`w_pcs` / `h_pcs`), `commitment: Commitment`
(`proof.w_com` / `proof.h_com`), `claims: Vec<ZClaim>` (the verifier's
`wcz` / `hc`, with their coefficients and points), `opening: OpeningZk`
(`proof.w_open_zk` / `proof.h_open`: group vectors including pads, prox
vector, sampled columns with salts and paths), `before: Transcript` (clone
before that `verify_zk`), `after: Option<Transcript>` (clone after), plus a
`role` tag (W, A, H) and the thread-local slot holding a `Vec<Observation>`
— FA1's C-2 sketch at `zk.rs` 3737–3738 and, symmetrically, around 3748.
For the rank tool I additionally need a `cfg(test)` JSON export of one
observation per role: row count, `log_cols`, the group membership and
lambdas (from a `replay`), the prox ρ, the message parts of every vector,
and the terminal values with their claims' coefficients — enough to build
the MODEL.json of §15 with actual coefficients and finish U1.

## 20. Limits of Part 2

- No Rust was built or run; no new proof was produced; H and P3-W are
  source-derived and unobserved. The A observations are FA1's (twelve tiny
  proofs); the tool has not consumed any captured coefficient.
- The models use stand-in coefficients with the source's structure; the
  128-column, 14336-wide layouts were modelled per column and for groups
  at n = 4, not at full width (the rank rules of §14 are n-independent by
  derivation, and were checked at n ∈ {2, 4, 8}).
- Range/enumeration and repeated-proof recovery are derived, not executed
  (no lattice or enumeration was run; the bit counts assume int8 X, int16
  h16, int8 weights — the tiny fixtures' weights are in [−4, 4]).
- Nothing here is a simulation proof, a soundness statement, or an
  approval of P3 identity or of any repair. The CFS channel is unreviewed.
- The per-column table-slot modelling at T2 (2588 mask unknowns) uses the
  source's slot sizes but not its exact row-index arithmetic; the rank
  results depend only on the counts and the row-bit structure.

## 21. Files (FA2)

| File | SHA-256 |
|---|---|
| `scripts/zk60_fable_joint_rank.py` | `630a93b7cb3da25086d386ef17ecf11af0e83e5fe926b4734a18ee27db98368e` |
| `tests/test_zk60_fable_joint_rank.py` | `3372bcf81298467743fb67592ffc64cdd520b6a4981958ff952e9c950c5b6e78` |
| `results/zk60_fable_fa2_impact.json` | `11643d63e16f6a6bbd676c5fb0f74aa29ef1287ffc93f13092b9802f84c47fd3` |
| `results/zk60_fable_fa2_rank_cases.json` | `b8dd92a89bee942f7eef11f37d36f593e8e6f3845c3b3214ee856d580ce60705` |
| `results/zk60_fable_fa2_observations.json` | `5b3dace965e18552fabbc55de657f6eb1a6ca2569e84607b85b5e83459b61210` |
