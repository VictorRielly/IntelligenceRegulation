# Closing four residual gaps of the shaped generic-rank lemma: GS-4, GS-5, GS-11, GS-12

> **DRAFT, UNCHECKED.** Written by one delegated Opus agent (drafter),
> 2026-09-23 11:49–12:22 PDT (`date`). Nobody has checked this page yet;
> an independent adversarial check is owed before a ruling. **This is not a
> privacy acceptance and it establishes no privacy property.** It closes
> argument leftovers of one lemma about the per-commitment linear view.

**What this is.** Obligation 5 of `ZK60_SHAPED_PRIVACY_PATH_STATUS.md`
("argument leftovers at the shaped layouts") names four gaps of
`ZK60_GENERIC_RANK_LEMMA_SHAPED.md` §7 (lines 1370–1378): GS-4, GS-5, GS-11
and GS-12. This page takes each one to a verdict, with the argument, the
code facts (file:line) and the evidence.

**What was read, all read-only.**

| tree | commit | what |
|---|---|---|
| lane `zk60-private-block-125m`, `/home/victor/wt-zk60-block125m` | **`2ea7221`** (clean but for two untracked log files) | every Rust citation below unless marked otherwise |
| joint-view gate lane, `/home/victor/wt-zk60-jointview` | **`adcd831`** | the gate's tools and its committed records |
| main tree (this repository) | `perf/zk-batch-optimizations` | the lemma, its check and disposition, the census disposition, `hashline/src/zk.rs` |
| capture bundles | `/home/victor/zk60-artifacts/` (125M) and the lane's `results/zk60_block_captures_20260923/rung-g/` | JSON only, plus four public table arrays (GS-12) |

No Rust was built or run. Evidence: `results/zk60_gs_closures/` (six
scripts, their outputs; exact Goldilocks arithmetic where arithmetic is done).

**Labels.** **MEASURED** — read off a real receipt or capture, or a gate
record computed from one. **COUNTED** — from the code or a shape, no receipt.
**COMPUTED** — exact arithmetic on a stated model (script named).
**ARGUED** — reading and derivation only. **PROVED HERE** — a derivation
given in full on this page.

---

## 0. Verdicts

| gap | verdict | one line |
|---|---|---|
| **GS-4** | **CLOSED** | Exclusivity at 125M **has been observed directly** since round 9 (jointview `3676262`, 2026-09-21 09:32): the gate's H-pair check recomputes every claim's row weights from the capture and reports one exclusive pair per claim on every 125M commitment; this page re-observes it a second way, with a literal Python transcription of `audit_claims` run on the four 125M captures (22 openings accepted, 26 of 26 negative controls refused by name). The status page's "observed only indirectly" is stale. |
| **GS-5** | **CLOSED** (derived; computed; one sub-step computed, not proved) | `disclosed = n·k0 + u*` is derived for any row width `n` and pad count `Q` (§2); `Q` enters only through `d ≤ Q`; the u-term is `u*`, not `n·u*`, because the zero-sum rows are uniform on a **codimension-1** hyperplane of `Fp^n`, so exactly one of the `n` message directions escapes. Brute force of the whole view agrees on all 385 instances of the 11 cases where exclusivity, H-pad and the pair-basis condition of multi-member groups hold (including `k0` = 1…3, a dependent proximity pair, and a zero-slack boundary where it reads exactly `n`), at `n` = 4…32 against `Q` = 2…8, and under-counts by the predicted amount on all 140 where one of those three is broken; the gate's 79 recorded per-commitment figures at rung-G and 125M and round 9k's `k0 = 1` joints (16,384 / 16,386) fit the formula. |
| **GS-11** | **CLOSED** as a carried lemma, with its shape dependence stated | `M`'s geometry is identical at every shape (50 rows, message 512, domain 4,096, 256 pads and 256 opened columns, `b` and `u` of 1,024, 48 proximity coefficients, 34 functionals) — COUNTED from the code and MEASURED on rung-G and 125M captures. `M-q` and `M-prox` use none of the shape-dependent quantities, so they carry over verbatim; the shape enters `M` only through the mask lengths `L_s` (Σ 583 / 859 / 1,239, worst 50 / 72 / 117 of the 256 budget), which feed the fit assert, the pad window of `M-cols`, and the CFS channel (T11/T12, already recomputed). |
| **GS-12** | **CLOSED** at every registered shape | At a padded `Dom::F` position every admitted witness carries `(g8, a16) = (0, 0)` (the builder writes only the support; the pad rule proves both planes zero), so the activation argument is the pair `(128, 0)`; ruling S38-F1(a) refuses `act[128] ≠ 0` wherever `Dom::F` pads and CS-1 re-checks it at every entry; CS-3 refuses any activation miss at any position before the first commitment. MEASURED: `act[128] = 0` in all four standalone captures' public tables; `Dom::F` pads 3,584 positions at rung-G and **none at 125M**, where GS-12 is vacuous. |

---

## 1. GS-4 — `audit_claims` exclusivity at 125M: observed

### 1.1 What exclusivity is, in the code

`audit_claims` (`hashline/src/private_block/protocol.rs:230-274`) is the
shared schedule audit for `A`, `H` and every internal boundary; it is the
first statement of `check_opening` (`:318-319`), which both the prover and
the verifier run, and `boundary::check_opening` (`boundary.rs:287-289`)
calls it with the boundary's derived geometry. Over the part row ranges
`part_rows` (`protocol.rs:215-218`, `div_ceil`) it refuses:

* a part reaching the proximity pair or leaving the commitment (`:241-243`);
* a zero coefficient on a reserved row (`:245-247`);
* an evaluation claim that does not touch **exactly two adjacent reserved
  rows at even offset from the first site row** (`:259-262`);
* a sum claim that is not last, touches a reserved row, or does not cover
  both zero-sum rows (`:252-258, :264`);
* **any reserved row used by other than exactly one claim** (`:270-272`).

The external endpoints are checked instead by `check_endpoint_opening`
(`:376-390`): exactly one claim of exactly three parts, data rows `0..data`,
then one row each at `data` and `data + 1`, every coefficient nonzero.

"Exclusivity" below means what the lemma's H-pair needs: every claim's
non-data weights sit on exactly one adjacent reserved pair, no pair is used
by two claims, every reserved row is used, no claim touches the proximity
pair, and each pair's two coefficients form an `Fp`-basis of `Fp2`.

### 1.2 First observation: the gate's H-pair leaves (MEASURED since 2026-09-21)

The run gate's per-commitment view inherits `RoleView._check_pair_schedule`
(`/home/victor/wt-zk60-jointview/scripts/zk60_native_jv_pcs.py:394-433`)
unchanged into `RunRoleView` (`zk60_native_rg_pcs.py:258`). It does not
trust the capture's schedule: it **recomputes each claim's row weights**
from the claim's parts (`ShapePcs.zpart_weights`, `zk60_native_rg_pcs.py:61-93`,
a port of `pcs.rs::zpart_weights`, lane `zkp-core/src/pcs.rs:860-900`), then
for each claim takes the non-data rows it touches and fails unless they are
exactly one adjacent pair (or, for the LogUp sum claim, exactly the zero-sum
pair), no pair is used twice, the pair's coefficients have nonzero `Fp`
wedge, and no claim touches the proximity pair. The recomputed weights are
bound to the receipt's published bytes by two identities checked in the same
pass: every group's `<v_g, cw_g> = Σ λ·value` (`_check_group_claims`) and
sampled column identities against the group and proximity vectors
(`_check_columns`).

[MEASURED, `results/zk60_gs_closures/gs4_exclusivity_records.{py,json,txt}`]
Ten committed 125M records, four distinct receipts (two two-block runs,
round 9; two standalone blocks, round 9j), 55 commitment views:

| receipts | commitment | claims | distinct pairs | reserved rows (spare) | H-pair | findings |
|---|---|---:|---:|---:|---|---|
| runs (dense, zero), both stages; blocks (dense, zero) | `A` | 122 | 122 | 244 (0) | true | none |
| the same | `H` | 51 | 51 (50 + the zero-sum pair for the sum claim) | 100 (0) | true | none |
| runs and blocks | each external endpoint | 1 | 1 | 3 (1 spare, row 36) | true | none |
| runs | boundary `B0` | 2 | 2 | 4 (0) | true | none |

On all 55 views: `exclusive` (H-pair true, no finding, distinct pairs =
claims) and `every reserved row used once` (`2·(pairs − sum claims) =
reserved rows − spare`), with **0** group-identity and **0** column-identity
failures. The same leaves are in the round-9 record as first committed
(`git show 3676262:results/zk60_native_run_gate_m125/m125-dense.json`,
2026-09-21 09:32 PDT: `H-pair: true`, `reserved_pairs_used = claims` on all
seven commitments). The rung-G comparison the lemma cites ("observed at
rung-G on two captures") is the same check: three rung-G run records, 30
views, identical verdicts (same file).

So the status page's "GS-4 (audit exclusivity at 125M observed only
indirectly …)" (`ZK60_SHAPED_PRIVACY_PATH_STATUS.md` §2 row 2 and §3 row 1)
is **stale since 2026-09-21**: the observation is direct, and it is the same
observation the lemma accepted at rung-G.

### 1.3 Second observation: the Rust audit, transcribed and re-run (MEASURED)

[`results/zk60_gs_closures/gs4_audit_replay.{py,json,txt}`] A literal Python
transcription of `part_rows`, `audit_claims`, `part_key_at`,
`opening_groups_at`, `check_opening` (without the challenge replay, which
needs the transcript) and the claim-shape half of `check_endpoint_opening`
(`protocol.rs:186-192, 200-218, 230-274, 318-325, 356-370, 376-387`), run on
the claim lists of the four 125M captures (JSON only; every claim is
inline). The geometry each opening is audited against is **derived** — `A`:
site rows `data..rows−2`, proximity `rows−2`; `H`: the same with the zero-sum
pair at `data−2, data−1`; boundary: `data + 2·sites + 2` from
`BoundarySpec` (`boundary.rs:186-197`); endpoint: `endpoint_geometry` — and
only then compared with what the capture declares.

* **22 of 22 openings accepted** (A ×6, H ×6, endpoints ×8, boundary ×2);
  every reserved row used exactly once (min = max = 1); no proximity row
  touched; the derived geometry equals the declared one everywhere.
* **Opening groups: `A` 36 of 36, `H` 9 of 9, boundary 2 of 2, endpoint 1**
  — the counts the verifier requires. The real `A` group sizes, as a
  multiset, **equal the check's derived distribution** (B-7: 36 groups,
  largest 35, 17 singletons) on all six `A` openings. That also answers the
  check's own open item ("whether `a_groups`'s declared 36 is what the Rust
  forms at 125M", `ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md` §3 item 7):
  MEASURED, it is.
* **26 of 26 negative controls refused by name** on the real claim lists:
  claim 1's pair moved onto claim 0's (`unused or shared`), a zero mask
  coefficient (`zero terminal mask coefficient`), a mask part on the
  proximity row (`reaches the proximity pair`), a pair shifted one row (`does
  not carry exactly its own reserved pair`), the sum claim moved to the front
  (`unexpected sum claim`), the boundary's site-1 claim moved onto site 0
  (`unused or shared`), an endpoint mask part moved (`endpoint claim
  differs`) — on each bundle where the opening exists.

### 1.4 Verdict and what is not covered

**CLOSED.** Exclusivity at 125M is observed on four real receipts by two
independent routes (weight level in the gate; slice level in a transcription
of the Rust audit), and the Rust enforces it on both sides.

Not covered, and not GS-4: (i) **eleven boundaries** — a 12-block 125M run
has not been captured; every boundary is built from the same derived
`BoundarySpec` geometry (`boundary.rs:186-197`) and audited by the same call,
so the observation at `B0` carries by construction [ARGUED]; (ii) **other
challenge vectors** — exclusivity is a property of the slice layout (fixed
by the shape) plus nonzero coefficients (refused otherwise, `:245-247`), so
it does not vary with the challenges except through refused draws [ARGUED];
(iii) my transcription reads the capture's `data_rows` and row count to
derive the rest of the geometry — those two numbers agree with the lemma's
layout-model table (§1.2 there: `A` 5,681 / 5,435, `H` 7,120 / 7,016 + 2,
endpoint 37 / 32, boundary 38 / 32) [COUNTED].

---

## 2. GS-5 — the reduction `disclosed = n·k0 + u-term` at `n ≠ Q`

### 2.1 The object

One hiding commitment of `zkp-core/src/pcs.rs` at lane `2ea7221`. Rows `i ∈
[0, R)`, split into data rows `D` and non-data rows `N = N' ∪ U`, with `U`
the two zero-sum rows on `H` (empty elsewhere). Row `i` is `z_i = (m_i, π_i)
∈ Fp^n × Fp^Q`, `n = 2^log_cols` (1,024 at rung-G, 16,384 at 125M), `Q =
q_pad = 256` (`ZkOpts::standard`, `pcs.rs:580`).

* **Randomness.** `m_i` uniform on `Fp^n` for `i ∈ N'` (`protocol.rs:1002-1004`
  for `A`, `:1115-1117` for `H`); `m_u` for `u ∈ U` uniform on the hyperplane
  `H0 = {x : Σ_t x_t = 0}` — `n − 1` fresh words and the last set to minus
  their sum (`protocol.rs:1118-1126`), the same functional for both rows;
  `π_i` uniform on `Fp^Q` for **every** row, data rows included
  (`pcs.rs:724`, `:777`).
* **Encoding.** `encode_row_zk` (`pcs.rs:655-674`) evaluates
  `f_msg(x) + Z_n(x)·Σ_{k<Q} π_k x^k` on the coset `7·<w_nn>`; so opened
  column `j` has `E_j = (F^msg_j ∈ Fp^n, F^pad_j ∈ Fp^Q)` with `F^pad_j[k] =
  Z_n(x_j) x_j^k`. (The coefficient bookkeeping at `:666-669` gives this
  identity for any `Q` with `n + Q ≤ nn`, including `Q > n`.)
* **The view** (the tool's model, `zk60_native_jv_pcs.py:1-67`): (a) each
  published claim value `y_c = Σ_i rw_c[i] <m_i, cw_g>`; (b) each group
  vector `v_g = Σ_i ρ_g[i] z_i` (`n + Q` entries of `Fp2`), `ρ_g = Σ_{c∈g}
  λ_c rw_c`; (c) the proximity vector `v_prox = Σ_i ρ_prox[i] z_i`; (d) for
  each distinct opened column `j` and each row `i`, `col_j[i] = <E_j, z_i>`.
* **The quantity.** `disclosed = dim_Fp(F ∩ T) = rank(L) − rank(L_R)`, `L`
  the realified view as a matrix over (data, randomness) and `L_R` its
  randomness columns (`ZK60_GENERIC_RANK_LEMMA_CHECK.md` §1.2 proves the
  equivalence with uniformity of the view's law).
* **The tool's formula.** `Γ ∈ Fp^{K×R}`, `K = 2(G+1)`: the real and
  imaginary parts of the `ρ_g` and of `ρ_prox`. `k0 = rank Γ − rank Γ_N`
  (`zk60_native_rg_pcs.py:381-392`, which multiplies by `self.sp.n_cols`,
  the run's `n`; the toy tool's literal `256` at `zk60_native_jv_pcs.py:516`
  is the toy's `n`, equal to its `Q`); `u_dim = rank(ξ ∪ K_D) − rank(K_D)`,
  `ξ` the data-row images of one solution per u-row indicator, `K_D` the
  data-row images of the kernel `{c : cΓ_N = 0}` (`:394-431`). The joint tool
  uses the same form with `msg_width` (`zk60_native_jv_joint.py:339-344`).

### 2.2 The derivation (PROVED HERE, except where 2.2.2(c) says COMPUTED)

**Theorem G5.** Let the view be as above, with

* **(P)** `d ≤ Q` distinct opened columns and `rank F^pad = d` (H-pad);
* **(X)** every published claim's weights, restricted to `N' ∪ {prox rows}`,
  are exactly `(cm_c, cm_c·U)` on one adjacent pair `(r_c, r_c + 1) ⊂ N'`
  touched by no other claim, with `cm_c ≠ 0`, and no claim touches the
  proximity pair (the exclusivity of §1, plus the pair-basis condition);
* **(Π)** the proximity pair is `Fp`-independent (H-prox) — used only in
  step 2 and only for groups of two or more members.

Then

```
disclosed = n·k0 + u*,   k0 = rank Γ − rank Γ_N,
u* = dim( { cΓ_D : cΓ_{N'} = 0 } ) − k0 .
```

The tool's `u_dim` equals `u*` whenever every u-row indicator is
admissible (`u_row_indicators_admissible = |U|`), and is `≤ u*` otherwise.

**2.2.1 Step 1 — the opened columns and the pad halves drop out (uses only (P)).**
Complete `F^pad` (`d × Q`, rank `d`) to an invertible `Q × Q` matrix `M =
[F^pad; C]` and change the pad variables row by row to `p'_i = F^pad π_i ∈
Fp^d`, `p''_i = C π_i ∈ Fp^{Q−d}` — an invertible change of the randomness
coordinates, so neither `rank L` nor `rank L_R` moves. Apply `M` to the pad
half of every group and proximity vector (`M·Σ_i ρ_g[i] π_i = Σ_i ρ_g[i]
(p'_i, p''_i)`) — an invertible map on the view coordinates, same
conclusion. Then:

* the column values are `col_{·,i} = F^msg m_i + p'_i`: each `p'_i[j]`
  appears in exactly one view coordinate, with coefficient 1;
* the pad halves become `Σ_i ρ_g[i] p'_i` and `Σ_i ρ_g[i] p''_i`; the first is
  `Σ_i ρ_g[i] col_{·,i} − F^msg (Σ_i ρ_g[i] m_i)`, a combination of other view
  coordinates (the check's §4.4 identity), so it is dropped — a row that is a
  combination of other rows of `L` is the same combination in `L_R`, so both
  ranks keep;
* what is left has block form: the `d·R` column rows carry an identity block
  on the `p'` columns and nothing else touches `p'`; the `p''` rows touch only
  `p''`. Hence `rank L = d·R + rank(p''-block) + rank L₂` and `rank L_R =
  d·R + rank(p''-block) + rank L₂,R`, where `L₂` is the **message halves and
  the claim values** alone.

Nothing here relates `n` to `Q`: `Q` is used only through `d ≤ Q` and the
rank of `F^pad`. **This is the whole of the `n ≠ Q` question for the columns.**

**2.2.2 Step 2 — the published claim values drop out.**

*(a) Singleton groups (no hypothesis beyond `λ_c ≠ 0`).* If `g = {c}`, then
`v_g = λ_c Σ_i rw_c[i] m_i` on the message half, so `y_c = <v_g, cw_g>/λ_c`,
a combination of view coordinates already present. It adds nothing. (If
`λ_c = 0`, `ρ_g = 0` and `v_g` is identically zero; `y_c`'s random part
`cm_c <P_c, cw_g>`, `P_c = m_{r_c} + U·m_{r_c+1}`, is then seen by nothing
else but the proximity vector, and (b) below applies.)

*(b) Groups of two or more members, under (X) and (Π).* Write a combination
of view coordinates as `ψ = Σ_{g,t} Tr(θ_g[t] v_g[t]) + Σ_t Tr(θ_prox[t]
v_prox[t]) + Σ_c Tr(η_c y_c)` (every `Fp`-functional on `Fp2` is `z ↦ Tr(θz)`
for a unique `θ`). Suppose `ψ L_R = 0`. The coefficient of `m_prox[t]`,
`m_{prox+1}[t]` involves only `θ_prox[t]` (no claim touches the proximity
pair), so `Tr(θ_prox[t]·ρ_prox[prox]) = Tr(θ_prox[t]·ρ_prox[prox+1]) = 0`,
and by (Π) `θ_prox[t] = 0`. The coefficient of `m_{r_c}[t]`, `m_{r_c+1}[t]`
involves only `v_g` (`g ∋ c`), `v_prox` (now 0) and `y_c` (exclusivity), and
reads `Tr(cm_c(λ_c θ_g[t] + η_c cw_g[t])·z) = 0` for `z ∈ {1, U}`, an
`Fp`-basis; with `cm_c ≠ 0`, `λ_c θ_g[t] + η_c cw_g[t] = 0` for every `t`.
If some member has `λ_c ≠ 0`, then `θ_g = s_g·cw_g` and `η_c = −λ_c s_g`
for every member (for a member with `λ_c = 0` the relation gives `η_c = 0`,
consistent), so group `g`'s share of `ψ` is `Tr(s_g(<v_g, cw_g> − Σ_c λ_c
y_c))`, **identically zero** — the verifier's own group identity. If every
member has `λ = 0`, all its `η` vanish and `v_g ≡ 0`. So every `ψ` in the
left kernel of `L_R` equals, as a functional on all variables, a combination
of message-half coordinates of the groups that have no member with a pair of
its own (on `H`: the LogUp sum claim's group, whose single claim is not a
published terminal). Hence `F ∩ T` is unchanged by the values. This is the
terminal-surjection review's Proposition (`ZK60_TERMINAL_SURJECTION_REVIEW.md`
§1.4) with the proximity vector folded in, and nothing in it depends on `n`.

*(c) Multi-member groups without (Π)* — **COMPUTED, not proved.** In the
miniature (§2.3) an `Fp`-dependent proximity pair on commitments with a
two-member group leaves the values' contribution at zero (brute = formula,
70 of 70). No recorded commitment needs this case: every recorded view has
H-prox true.

**2.2.3 Step 3 — the message halves: `n·k0 + u*`, and why the u-term is not multiplied by `n`.**
What remains is `L₂ = Γ ⊗ I_n` acting on `X = (m_i[t])`: coordinate `(k, t)`
is `Σ_i Γ[k,i] X[i,t]`, the same `Γ` at every one of the `n` message
positions. In `Fp^K ⊗ Fp^n` put `S_D = colspan Γ_D`, `S = colspan Γ_{N'}`,
`S_U = colspan Γ_U`. The data rows are free, the `N'` rows are free, the `U`
rows range over `H0`:

```
Im L₂   = S_D ⊗ Fp^n + S ⊗ Fp^n + S_U ⊗ H0
Im L₂,R =              S ⊗ Fp^n + S_U ⊗ H0 .
```

Split `Fp^n = H0 ⊕ <e>` for any `e` with `Σ_t e_t ≠ 0`. Every summand above
splits along it, so

```
Im L₂   = (S_D + S + S_U) ⊗ H0  ⊕  (S_D + S) ⊗ e
Im L₂,R = (S + S_U)       ⊗ H0  ⊕  S ⊗ e
```

and

```
disclosed = (n − 1)·(rank Γ − rank Γ_N) + (rank Γ_{D∪N'} − rank Γ_{N'})
          = (n − 1)·k0                    + (k0 + u*)
          =  n·k0 + u* .
```

The second bracket: `rank Γ_{D∪N'} − rank Γ_{N'}` is the dimension of the
image of `W = {c : cΓ_{N'} = 0}` under `c ↦ cΓ_D`. `W` contains the kernel
`{c : cΓ_N = 0}`, whose image `K_D` has dimension exactly `k0` (a row of
`rowspace Γ` vanishing on `N` is determined by its data part); the rest is
`u*`. `W` is the set of combinations whose non-data restriction lies in
`span{e_u : u ∈ U}`, so the tool's per-indicator solutions span `W Γ_D`
modulo `K_D` exactly when every indicator `e_u` is itself reachable — and
may miss a direction otherwise (a reachable `e_{u0} + e_{u1}` with neither
indicator reachable would be missed). ∎

**Why `u*` and not `n·u*`, in one sentence.** Along the `n − 1` directions of
`H0` the zero-sum rows are as random as any mask row, so they contribute to
the `(n−1)·k0` term exactly like `N'`; along the **one** remaining direction
(the all-ones functional, which is also the LogUp sum claim's column weight,
`pcs.rs:902-914` for the key `([], 0, n)`) they are publicly zero and behave
like data rows, which is where `u*` comes from — **one** such direction
however large `n` is, because both rows are constrained by the same single
linear form. At `n = 16,384` the u-term is therefore `u*` (= 2 on every
recorded `H`), not `2·16,384`. That is the check's §3.3 argument
("summing `w`'s message entries kills the `u` row"), now placed inside the
general computation. Its enabling fact is a code line: if a future prover
pinned a zero-sum row by `c > 1` independent linear forms, the term would
become `c`-fold along a `c`-dimensional quotient, and it would still not
scale with `n`.

**The hypotheses the tool CHECKS against the ones the theorem USES.** (P) is
the tool's H-pad; (X) is its H-pair (exclusivity plus the pair-basis
determinant); (Π) is its H-prox. So the tool's three checks are exactly
sufficient, and (Π) is needed only for step 2(b). The admissibility condition
of step 3 is reported by the tool (`u_row_indicators_admissible`) but is not
one of its three hypotheses; on every recorded `H` it is 2 of 2, so the
recorded `u_dim` is `u*` (§2.4). **Proposal for the owner:** make
`u_row_indicators_admissible == |U|` a fourth checked hypothesis of the
reduction in the gate, since without it the u-term can under-count.

### 2.3 Numerical check 1: brute force at `n ≠ Q` (COMPUTED)

[`results/zk60_gs_closures/gs5_reduction_miniature.{py,json,log}`] One
commitment built as `build_claim` and `zk_rhos` build one (eq-tensor data
parts over the claim's own slice, reserved pairs `(cm, cm·U)`, first-occurrence
grouping by column key, one `λ` per member, a fresh `ρ_prox` on every row;
on `H`-like instances an `SC_ZS`-like claim on the u plane with
point-independent weights and the pairless LogUp sum claim with `±1 / ±U`
per plane row and `(1, U)` on the u pair), with the real `E_j` closed form on
the coset `7·<w_nn>`, `nn = 4n`. The **whole** view — every published claim
value, both halves of every group vector and of the proximity vector, every
opened column on every row — against (data | randomness), `disclosed =
rank(L) − rank(L_R)` by exact elimination mod `p`. Grid `(n, Q) ∈ {(4,8),
(8,2), (8,4), (8,8), (16,2), (16,4), (32,4)}` (so `n < Q`, `n = Q` and `n > Q`
up to `n/Q = 16`), five seeds each, 15 cases, 525 instances.

| case | hypotheses | brute = formula? | the value, as a function of `n` |
|---|---|---|---|
| honest, `H`-like | all | **35 / 35** | **2 at every `n`** (4 … 32) — the u-term does not scale |
| honest, `A`-like | all | 35 / 35 | 0 |
| u rows fully uniform (no zero-sum) | all | 35 / 35 | 0 — the 2 comes from the hyperplane (the check's B-9) |
| message halves alone, a generator set with `k0 = 1, 2, 3` | step 3 only | **105 / 105** | `n + 2`, `2n + 2`, `3n + 1` (the last `u* = 1` because 4 data rows cap it) |
| `cm = 0` in a singleton group | (X) broken, step 2(a) holds | 35 / 35 | `2n + 2` |
| dependent proximity pair, `H`-like | (Π) broken | 35 / 35 | 2 |
| dependent proximity pair, `A`-like | (Π) broken | 35 / 35 | 0 |
| zero-slack boundary (two singleton claims, no spare row), honest | all | 35 / 35 | 0 |
| the same, dependent proximity pair | (Π) broken | 35 / 35 | **`n`** — Finding N-1's "one row's worth", at every `n` |
| two claims of **different** groups on one pair | exclusivity broken | **0 / 35** | brute = formula **+ 2** |
| two claims of **one** group on one pair | exclusivity broken | 0 / 35 | brute = formula + 2 |
| `cm = 0` inside a two-member group | (X) broken (`k0` stays 0) | 0 / 35 | brute = formula + 2 |
| `d = Q + 1` distinct opened columns | (P) broken | 0 / 35 | brute = formula + 4 (= the data rows: one column combination escapes the pads on every row) |

**Reading.** The formula is exact on all **385** instances of the eleven
cases in which exclusivity, H-pad and the pair-basis condition of
multi-member groups hold — the four where every hypothesis holds (140), the
message-half system at `k0` = 1…3 (105), `cm = 0` in a singleton (35) and
the three with a dependent proximity pair (105). It under-counts, by exactly
the predicted amount, on all **140** where exclusivity, the pair-basis
condition of a multi-member group or H-pad is broken — i.e. the tool's
checks are load-bearing for its formula, which is why the gate reports H-pad
/ H-pair / H-prox beside every figure. H-prox is not needed for the formula
to be exact in any instance tried; its failure shows up inside `k0`. The lemma's own part D′ (`(n, Q) = (8, 4), (8,
2)`, disclosed 0) is reproduced inside this grid by an independent script.

### 2.4 Numerical check 2: the gate's recorded figures (MEASURED, consistency only)

[`results/zk60_gs_closures/gs5_records_check.{py,json,txt}`] For every
per-commitment view of five rung-G records (three runs, two standalone
blocks; `n = 1,024`) and eight 125M records (runs, blocks, round 9k's C3c;
`n = 16,384`), all with `Q = 256`: **79 of 79** satisfy
`disclosed = n·(rank_P1 − rank_P1_on_non_data_rows) + u_dim`, with the
recorded `k0` equal to that difference, `k0 = 0` everywhere, `u_dim ∈ {0,
2}`, and `u_row_indicators_admissible = |U|` on every `H` (so the recorded
`u_dim` is the exact `u*`). The only recorded shaped systems with `k0 > 0`
are round 9k's control C3c (one reserved row shared between the two external
endpoints of a standalone block):

| shape | system | `k0` | recorded joint | `n·k0 + u*` |
|---|---|---:|---:|---:|
| rung-G (dense and zero) | the endpoint pair, perturbed | 1 | 1,024 | 1,024·1 + 0 |
| rung-G | the whole block, perturbed | 1 | 1,026 | 1,024·1 + 2 |
| 125M (dense and zero) | the endpoint pair, perturbed | 1 | **16,384** | 16,384·1 + 0 |
| 125M | the whole block, perturbed | 1 | **16,386** | 16,384·1 + 2 |

**What this check is and is not.** It is arithmetic consistency: the gate
computes these figures with the same formula, so agreement shows the records
are what the formula says, not that the formula is right. The independent
evidence is §2.2 and §2.3. What the records add is that the formula's inputs
(`rank_P1`, the non-data rank, admissibility) were computed on real bytes at
`n = 16,384 ≠ Q = 256`, and that round 9k's prediction (R9k.2 step 3, "one
message width") was derived independently of the formula and came out equal.

### 2.5 Verdict

**CLOSED.** The reduction is derived for general `(n, Q)`; the u-term's
`u*`-not-`n·u*` is explained by the codimension of the zero-sum constraint;
brute force confirms both, including `n/Q = 16` and `n < Q`. Two residuals,
both small and both named above: step 2(c) (multi-member groups with a
dependent proximity pair) is computed, not proved, and needs no recorded
view; the tool's u-term is exact only when every indicator is admissible,
which every recorded view satisfies and which the gate does not yet treat as
a hypothesis.

---

## 3. GS-11 — `M-q` and `M-prox` at every shape

### 3.1 `M`'s geometry, from the code (COUNTED)

| quantity | where | value | depends on the shape? |
|---|---|---|---|
| slots | `N_SLOTS`, `layout.rs:798` | 23 | no |
| rows | `M_ROWS = 2·N_SLOTS + 4`, `layout.rs:931`; `n_base = 2·masks.len() + 4`, `zk.rs:435` / `:486`, with `masks.len() = lay.mask_specs().len() = N_SLOTS` (`layout.rs:1227-1229`) | 50: two `a` rows per slot, `b_re`, `b_im`, `u_re`, `u_im` | no |
| message width, domain, pads = opened columns | `MASK_LOG_MSG`, `MASK_LOG_DOM`, `MASK_Q`, `zk.rs:373-375` | 512, 4,096, 256 | no |
| `b` rows | `zk.rs:452-455` (tagged twin `:503-506`) | 1,024 coefficients each, `b[512] = −b[0]` | no |
| `u` rows | `zk.rs:456-457` (tagged twin `:507-508`) | 1,024 fresh coefficients each | no |
| `q'` | `mask_open`, `zk.rs:569-583` | 1,024 `Fp2` | no |
| proximity combination | `zk.rs:586-593`: starts from `u` with coefficient 1, adds `r_row·p_row` over `2·23 + 2 = 48` rows | 1,024 `Fp2`; 48 challenges | no |
| functionals | `N_FUNCTIONALS`, `layout.rs:930`, runtime guard `argument.rs:1884` | 34 | no |
| mask length of slot `s` | `CfsMask::len = N_s·d_s + 2`, `zkp-core/src/sumcheck.rs:197-199`, with `(N_s, d_s)` from `lay.mask_specs()` | per shape | **yes** |
| fit | `assert!(part.len() + MASK_Q <= m)`, `zk.rs:442` / `:493` | `L_s ≤ 256` | through `L_s` |

The shaped block calls the **tagged** twin `zk::mask_commit_tagged`
(`protocol.rs:1021`); its body draws in the same order as `mask_commit` and
differs only in the hashing calls (`zk.rs:481-518` against `:430-467`; the
lane's own comment at `:476-478` says so, and the diff of the two bodies is
the three hash lines). The main tree's `hashline/src/zk.rs:452-457` — the
lines the lemma cites — are byte-identical to the lane's (the two files
agree on lines 1-468).

### 3.2 The same, measured on the captures (MEASURED)

[`results/zk60_gs_closures/gs11_mask_geometry.{py,json,txt}`]

| shape | Σ `L_s` | largest `L_s` (slot) | headroom `256 − max` | coefficient unknowns | declared `M` = the constants? |
|---|---:|---:|---:|---:|---|
| toy (`layout.rs:850-874`, COUNTED) | 583 | 50 (17) | 206 | 1,166 | — (no capture read) |
| rung-G (standalone block capture) | 859 | 72 (17) | 184 | 1,718 | **yes** |
| 125M (two-block run, stage 0 and stage 1) | 1,239 | 117 (17) | 139 | 2,478 | **yes** |
| 125M (standalone block capture) | 1,239 | 117 (17) | 139 | 2,478 | **yes** |

"Declared = the constants" means: 50 rows, `q` and `prox` of 1,024, 48
proximity coefficients, 256 opened columns each of height 50, 34
functionals, and the 23 declared `(N_s, d_s)` equal to the shape's slot
table. The gate's `M` arm, which constructs a preimage (recovers `b` from
`q'`, `u` from `prox`, and reproduces the opening), reads on ten stages at
rung-G and 125M: `b` admissible (`b[512] = −b[0]`), the `q'` sum identity
holding, and **0** mismatches in `q'` (1,024), `prox` (1,024) and the 12,800
column entries; and at 125M, `disclosed_fp_computed = 2` of 2,478
coefficient unknowns (`block-m125-dense-everything.json`,
`stage12_mask_and_cfs.per_stage[0]`).

### 3.3 `M-q` and `M-prox`, re-derived (PROVED HERE, shape-free)

**`M-q`.** `q' = b + Σ_s p_{a_s}·p_{W_s}` (`zk.rs:569-583`), where
`p_{a_s}` is the interpolant on `G_512` of the `a` row's 512-word message
(`ntt.inverse`, `zk.rs:447` / `:498`) and `p_{W_s}` that of the combined
weights (`weight_polys`, `:541-547`), so every product has degree `< 1023`
whatever `L_s` is. `b = b_re + U·b_im` with each part uniform on the
hyperplane `{b_0 + b_512 = 0}` of `Fp^1024` (`:452-455`), drawn independently
of the `a` rows' coefficients and pads. For fixed `a` and `W`, `q'` is
therefore uniform on the coset `A + H_b`, `A = Σ_s p_{a_s} p_{W_s}`, and
the coset is named by one `Fp2` value, `q'_0 + q'_512 = A_0 + A_512`. Since
`Σ_{x∈G_512} x^i = 512·[512 | i]` for `i < 1024`, `512(q'_0 + q'_512) =
Σ_{x∈G_512} q'(x) = V`, the θ-combined functional value the verifier checks
(`zk.rs:611-612`; tagged `:655-656`). So `q'` discloses about the hidden
mask coefficients exactly the public θ-combination, 1 `Fp2`, and nothing
else. Every ingredient — 512, 1,024, `b`'s single pinned coefficient, the
degree bound — is a constant of `zk.rs`.

**`M-prox`.** `prox = u + Σ_{rows} r_row·p_row` (`zk.rs:586-593`) with `u =
u_re + U·u_im` uniform on `Fp2^1024` (`:456-457`) and coefficient exactly 1:
a one-time pad. `prox` is uniform and independent of everything else in the
view. Shape-free.

**The columns of `b` and `u`** are then determined by the rest of the view:
the verifier's two column checks (`zk.rs:629-638`; tagged `:673-682`) say
`b(y_j) = q'(y_j) − Σ_s a_s(y_j) W_s(y_j)` and `u(y_j) = prox(y_j) − Σ r_row
p_row(y_j)`, both functions of published values. The `a` rows' own columns
are absorbed by their 256 pads (`M-cols`): the pads sit at message positions
`[L_s, L_s + 256)` (`zk.rs:444-446`), so the pad block is a Cauchy/Lagrange
matrix on that window, nonsingular for every window because a Cauchy matrix
on distinct nodes is totally nonsingular (the toy check's condition O-4); the
window moves with `L_s`, the argument does not.

### 3.4 Verdict

**CLOSED — the toy lemma's `M-q` and `M-prox` carry over verbatim**, now
derived rather than relied on, and COUNTED plus MEASURED to use only
shape-free constants. What depends on the shape is exactly `(N_s, d_s)`, i.e.
`L_s`, and it enters in three places and no others:

1. **the fit** `L_s + 256 ≤ 512` — an assert (a panic on a public,
   shape-level condition, not a refusal); worst 117 at 125M, headroom 139
   (the gate's ruling C-4 figure);
2. **the pad window** of `M-cols` — any window works (§3.3);
3. **the CFS channel** — `uncovered_s = 0` and every published functional in
   the round span, per slot, at the shape's own `(N_s, d_s)`: items T11/T12
   of the shaped lemma, recomputed there at rung-G and 125M (its §4.C) and
   not part of GS-11.

The disclosed dimension of `M` on the mask-coefficient space is 2 `Fp` at
every shape (MEASURED at 125M: 2 of 2,478).

---

## 4. GS-12 — the activation family's `act_indices` at padded positions

### 4.1 The chain, fact by fact (lane `2ea7221`)

1. **Where the activation arguments are.** `act_indices` is the plane
   `A_G8` plus 128 over the **whole** `Dom::F` cube (`protocol.rs:571-573`);
   the LogUp denominators `α − (g8 + 128 + β·a16 + g_act)` are formed at
   every cube position (`protocol.rs:1061-1062`), and the slot's activation
   arm `f_act` is **not gated** by the support indicator
   (`argument.rs:1571-1574, 1589`), so padded positions are in the identity.
   `g_act = γ·TAG_ACT` (`protocol.rs:1034`, `TAG_ACT = 134` at
   `hashline/src/tables_attn.rs:77`); the table row `i` is `i + β·act[i] +
   g_act` (`argument.rs:1067-1069`). The activation family has no other
   domain.
2. **What an admitted witness holds there.** The builder computes `g8` by
   `quantize` (`witness.rs:672`), which writes only the support and leaves
   every other position 0 (`witness.rs:284-296`), and `a16` into a zeroed
   vector written only on the support (`witness.rs:681-685`); both planes are
   stored as built (`:703-705`). So at every padded `Dom::F` position
   `(g8, a16) = (0, 0)` and the argument is the pair `(128, 0)`. The
   verifier side agrees: `A_G8` and `A_A16` are `Dom::F` planes under
   `Rule::Zero` wherever `Dom::F` pads (`pad.rs:289-303`), proved zero by the
   hosting slot's pad-zero term (`argument.rs:1575-1581`).
3. **When `(128, 0)` is a row.** Row 128 of the table is `(128, act[128])`,
   so the pair is a row iff `act[128] = 0`.
4. **The statement refusal.** `FeedForwardPublic::check_words` refuses
   `act[128] ≠ 0` whenever `sh.pads(Dom::F)` (`private_block.rs:678-680`,
   ruling S38-F1(a)), and `pads` is `size ≠ true_size`, which also counts a
   domain the P-3 lift would enlarge (`shape.rs:1297-1299`). It runs in
   `new_shaped` (`private_block.rs:640`) and, by ruling CS-1, again through
   `check_for_shape` (`:690-692`, via `BlockPublic::check_for_shape`
   `:750-753`) at the witness builder (`witness.rs:443-444`), both prover
   entries (`protocol.rs:800` in `prove_inner_at`, `:923` in `prove_core`),
   both verifier bodies (`:1207` in `verify_core`, `:1348` in
   `verify_inner_at`), both bytes entries (`private_block.rs:1190`, `:1202`)
   and the run layer (`run.rs:611-614`, called from `RunStatement::new`
   `:220`, `prove_run` `:708`, `RunVerifier::start` `:859`) — before
   anything is absorbed, committed or drawn (census disposition §5–§6).
5. **The prover refusal, whatever the builder did.** `prove_core` counts, over
   the whole cube, every position whose pair is not a table row
   (`protocol.rs:960-967`) and refuses by name before the first `A` mask
   draw (ruling CS-3, `:978`, `refuse_lookup_misses` `:511-524`). This covers
   any witness the honest prover is handed, padded positions included.
6. **Profile ↔ geometry.** Ruling CS-9 binds each registered block profile
   string to one whole shape (census disposition §9), so "the shape whose
   `Dom::F` pads" is a property of the profile, not of a caller's choice.

Items 1–4 give: for every statement the constructors admit and every witness
the builder admits, every activation argument at a padded position is the
table row 128. Item 5 makes the same true for every attempt that reaches the
LogUp challenges, for any witness. **PROVED HERE** from the cited lines.

### 4.2 What was measured

* [MEASURED by the lane, stage 39, `census_shaped_tests.rs`, cited from
  `ZK60_SHAPED_REFUSAL_CENSUS.md` §6 on the lane] at all ten census shapes,
  `act[128] ∈ {1, −1, 32767, −32768}` is refused by name at the four shapes
  whose `Dom::F` pads (3,584 of 8,192 positions padded) and admitted at the
  six that do not, including 125M; stage 40's `s40_cs1_…` tests measure the
  CS-1 re-checks firing with 0 draws.
* [MEASURED here, `results/zk60_gs_closures/gs12_act_row128.{py,json,txt}`]
  On the four standalone block captures, the public activation table the TAB
  slot carries (slot 19; the one public table whose every row inverts to an
  `i16` under `(t_i − i − 134γ)/β` with the capture's replayed `β, γ`, bytes
  checked against the reference's sha256) has **`act[128] = 0`**, and its
  padded rows (1,024 at rung-G, 16,384 at 125M) repeat rows 0..255. `Dom::F`
  pads **3,584** positions at rung-G (`32 × 256` cube around `24 × 192`) and
  **0** at 125M (`512 × 2048`, no padding).

### 4.3 Verdict, and what is left beside it

**CLOSED at every registered shape.** At 125M the question is **vacuous**
(no padded `Dom::F` position), and the activation arguments are table rows at
every position by construction (item 2's builder lines) and by CS-3.

Beside GS-12, for completeness of the refinement N-3 that GS-12 served:

* the **u8 and exp families**, closed by the check's B-6 / ruling S-4 — the
  current lines are `layout.rs:595-605` (`byte`, `scaled`, `sym`) and the
  exp difference refusal at `witness.rs:644-645` (B-6 cited `:533, :639` at
  `e6b612f`); CS-3 now also counts u8 and exp misses over their whole domains
  (`protocol.rs:479-487, 952-959`);
* **a strengthening the owner may want recorded**: because CS-3 refuses any
  lookup miss before the `A` commitment and the LogUp challenges are drawn
  after it (`protocol.rs:978` against `:1029-1031`), the N-3 bound `|S| ≤
  768` per block now holds on **every attempt that reaches the α draw, for
  any witness the honest prover is handed** — not only for witnesses the
  constructors admit. The admission event stays governed by rule M-9, as
  S-4 says. [ARGUED]
* the **table side's padded rows** (the P-3 lift of `Dom::Tab`): the three
  multiplicity planes and the three table helpers are `Rule::Zero` above
  index 255 (`pad.rs:294-297, 322-323`), and the prover inverts only the 256
  true table values per family (`protocol.rs:1087-1092`, the check's B-5), so
  padded table rows raise no denominator; MEASURED above that they repeat
  the true rows.

---

## 5. What a checker should attack first

1. **GS-5 step 2(b).** The annihilator argument concludes that, under (X) and
   (Π), a group with a member owning a pair contributes nothing at all to
   `F ∩ T` — which also re-proves `k0 = 0` for such groups. Attack the claim
   that the only view coordinates touching a pair row are the group vector,
   the proximity vector and the claim's own value (on `H`, `SC_ZS`'s claim
   also touches the u rows — check that this does not reach the pair-row
   equations), and the step "`Tr(xz) = 0` for `z ∈ {1, U}` ⇒ `x = 0`".
2. **GS-5 step 3's admissibility caveat.** Construct an `H`-like instance
   where only `e_{u0} + e_{u1}` is reachable and confirm the tool
   under-counts; decide whether the gate should refuse (proposal in §2.2).
3. **GS-5's miniature faithfulness**: the `E_j` closed form for `Q > n`
   (§2.1 claims `encode_row_zk`'s bookkeeping gives it for any `Q` with `n +
   Q ≤ nn`; re-read `pcs.rs:666-669`), and the choice of `SC_ZS`'s u-row
   weights as `(cd, cd·U)`.
4. **GS-4's independence claim.** My audit transcription derives the site
   rows from the capture's `data_rows` and row count; a writer that declared
   both wrong consistently would pass it. The cross-check against the
   lemma's layout-model table (§1.4 (iii)) is what covers that — attack it.
5. **GS-12 item 2.** That no other constructor of a `Witness` exists on a
   shaped path (a witness whose padded `A_G8` / `A_A16` are nonzero would be
   refused by CS-3 and then by the pad-zero term, but check it).
6. **GS-11's "only three places".** Look for any other use of `L_s` or of the
   specs inside `mask_open` / `mask_verify_tagged` that could couple `M-q` to
   the shape.

---

## 6. Evidence

All under `results/zk60_gs_closures/`; every script reads only committed
records, capture JSON or public table arrays, and writes nothing elsewhere.

| file | what it shows |
|---|---|
| `gs4_exclusivity_records.py` / `.json` / `.txt` | the gate's H-pair leaves on ten 125M records (55 views) and three rung-G records (30 views) |
| `gs4_audit_replay.py` / `.json` / `.txt` | `audit_claims` & co. transcribed from `protocol.rs` at `2ea7221`, run on the four 125M captures: 22 of 22 accepted, groups 36 / 9 / 2 / 1, the B-7 multiset, 26 of 26 controls refused by name |
| `gs5_reduction_miniature.py` / `.json` / `.log` | brute-force disclosed dimension against `n·k0 + u*`, 15 cases × 7 `(n, Q)` × 5 seeds |
| `gs5_records_check.py` / `.json` / `.txt` | the 79 recorded per-commitment figures and the C3c joints against the formula |
| `gs11_mask_geometry.py` / `.json` / `.txt` | `M`'s constants read from the code, `L_s` per shape, the declared `M` geometry of rung-G and 125M captures, the gate's `M` arm |
| `gs12_act_row128.py` / `.json` / `.txt` | `act[128]` recovered from the four standalone captures' public tables; `Dom::F`'s padded positions |

## 7. What this is not

1. **Not a privacy acceptance** and not a privacy property of any shape. It
   closes four argument leftovers of a per-commitment linear-view lemma.
2. **Not the joint statement** across commitments (G-R4 / GS-6), not the
   non-linear channel (GS-13), not the hash layer, not the Fiat–Shamir lift
   (G-R5 / GS-7), not a completeness argument (GS-14).
3. **Not checked.** Every derivation and every script here was written by one
   agent in one sitting. The obligation-5 line of the status page asks for
   "one errata pass on the shaped lemma plus an independent check"; this is
   the first half's input, and the errata to the lemma's §7 rows (GS-4's
   "enforced but never observed", GS-5, GS-11, GS-12) and to the status
   page's "observed only indirectly" are the owner's to make.
