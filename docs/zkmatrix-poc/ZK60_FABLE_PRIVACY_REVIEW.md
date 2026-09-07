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
