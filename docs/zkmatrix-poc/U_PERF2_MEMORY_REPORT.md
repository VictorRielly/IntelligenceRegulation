# U-PERF2 lane F — MEMORY DIET: the composed pass's resident set (w0 as flat i8, Phi_0 never materialized at level 0, CRS Arcs, dead-data levers) — toward the 12x512 rig on the 15 GB box

Status: CLOSED 2026-08-17 (items 0-4 landed; commits 5bbcf9f skeleton,
7067dca w0 compact, ddadc48 phi-never-materialized + CRS Arcs, 369e423
dead-data levers, + the report/ledger commit on uperf2-f — the ONE edit
outside the lane's files is the one-line witness-store change in
`uperf_pc_diff_e2e` (its E2E leg now runs on `DigitCols`), flagged for
the orchestrator). Written by lane
F of the U-PERF2 round 4 (ledger: PROGRESS_UPERF2.md "Lane F — MEMORY
DIET" + "Agent F status"). Worktree /home/victor/wt-uperf2-f, branch
uperf2-f, opened at f512ba1 (= the A/C/D/E merge 4dcaea6 + the round-4
ledger). Box: the WSL box (Intel Core Ultra 9 185H, 22 threads, 15 GB;
the local m125 re-export IS here: `M125_EXPORT_DIR=results/
m125_ffn_export_wsl`). Every number carries `[WSL-BOX 1T|NT,
QUIET|NOISY-SHARED]`; lane G built and ran in its own worktree for the
whole session (load 1.3-4.5), so every wall below is NOISY-SHARED and
the same-state A/B pairs are what to read for timing; the RSS rows do
not move with the load. RSS rows are `VmHWM` (peak so far) / `VmRSS`
(current) from /proc/self/status at the pass's phase boundaries
(`[UPERF2-F] RSS <tag>` rows, printed only when the prof timers are on —
observation only); the process peak is `/usr/bin/time`'s maxrss.

The rule (unchanged): every change is DIFFERENTIAL — the REAL rigs'
statement digest, counted bytes, verdict AND EVAL-PROOF DIGEST are
identical on every run (3x16 at ZK_THREADS 1 and 8; 12x64 at 8, five
knob variants), fast and oracle; the batteries hold at ZK_THREADS
1/2/7; freeze-check's 98 on-box rows are identical to the pre-change
capture. The w0 store change is STRUCTURAL (a storage type has no
arithmetic oracle): its gate is the rig digests + the E2E leg + the
lane's own battery (both stores through every kernel, byte-identical);
the phi routing keeps the materialized path under `oracle_mode()`.

## 0. One paragraph

The composed pass held its level-0 digit witness for BOTH groups as
`Vec<Vec<i64>>` (one ~1 KiB heap block per digit ring — 4.6 GB at 12x64,
~12 GB at 12x512) from the commit phase through the descents to the group
eval proofs, then materialized the level-0 aggregated functional Phi_0
(one mod-q ring per digit ring — another 3.5 GB at 12x64, ~8 GB at
12x512) inside the weight group's proof, held two copies of every CRS
matrix (memo + clone), and — because glibc keeps freed 1 KiB chunks in
its arena — never gave any of it back: the 12x64 rig peaked at 11.9 GB
inside the weight group's level 1 and stayed there. Now: (1) the level-0
witness is a flat i8 store (`ring::eval_proof::DigitCols`: n x D bytes,
ONE allocation, 128 B/ring) consumed per ring inside the kernels through
the `SmallRings` trait — the same i64 coefficients reach the same
arithmetic, so every kernel is byte-identical on either store; (2) Phi_0
is never materialized on the fast path — `Phi0Source` (the O5 factored
form per tensor) fills each u-block of the level-0 h GEMM on the fly
(`level_h_pairs_with`: exact-integer block partials reduced mod q =
bit-identical to the single-window kernel) and the level-1 transport
consumes the factored Psi_0 exactly as `bg_verify_group` already does;
(3) the CRS memo hands out `Arc` handles (no clones); (4) `malloc_trim(0)`
at the phase boundaries returns the arena's freed pages, `ZK_W0_REGEN=1`
frees the i8 witnesses through the claim layer + descents and rebuilds
them before the group proofs. On the REAL rigs (digests identical on
every run): 3x16 peak **2.86 GB -> 0.94 GB** (1T; 8T 1.03 GB), 12x64 8T
peak **12.2 GB -> 4.65 GB** (default knobs) / **3.99 GB** (`ZK_W0_REGEN=1`)
with the wall 45.5 -> 42.4 s (the flat digit witness is faster; the phi
routing is neutral by same-state A/B). The 12x64 peak is now the nrw-88
descent pair's own transient (2.2-2.5 GB at depth 19, 4.9 GB at depth
20; ~20-24 GB at the 12x512 depth 22 — lane A's own 21 GB estimate) on a
~1.5-2 GB baseline: **12x128 fits with room (measured 7.44 GB peak,
accept, 66.2 s at 8T — the first run of that shape on this box)**,
12x256 is over the box's edge (~14 GB [MODEL], not attempted), and
12x512 needs the descent-pair footprint cut ~2x (lane G's file) —
everything else of the pass now fits under ~7-9 GB at 12x512 [MODEL].

## 1. Items and where they land

| item | function | oracle / gate | call sites | status |
|---|---|---|---|---|
| RSS attribution rows `[UPERF2-F] RSS <tag> hwm/rss` | bin `uf_rss` (`uf_rss_kb`), hooks in bk_pass_run (layers, aux, witness, precommit, commit end, claim layer end, each descent pair, groups start, per group prove, verify per group) and bg_prove_group (rows pass, phi pass, level-0 h, level-0 fold, each deeper level) | observation only (printed when the prof timers are on) | the `uperf-pc *-profile` arms | LANDED |
| w0 as flat i8: `DigitCols` + `SmallRings` (over `[Vec<i64>]` AND `[i8]`) + `*_gen` kernel bodies (`ntt_gemm_modq_small_gen`, `matvec_modq_small_multi_gen` / `_ref_gen`, `ring_ip_modq_small_ref_gen`, `level_h_pairs_gen` / `_ref_gen`, `fold_chunks_ntt_gen` / `_ref_gen`, `kernel_pass_factored_gen`); the old names stay as `[Vec<i64>]` wrappers | structural: rig digests + `uperf-pc` E2E + `uperf-f diff-battery` (both stores x both moduli x fast + `_ref`) | bin `agg_digit_witness_cols` -> bg_witness / bk_witness_act / bk_witness_weight; bg_precommit / bg_prove_group take `&mut DigitCols`; bg_matvec_chunks / bg_level_h / bg_fold_gen generic (bg_fold keeps its boxed signature for the uperf-c leg); the deeper levels' witnesses (w_cur, that/hhat, floors) stay boxed; the E2E leg's witness store is `DigitCols::from_vecs` (one line in `uperf_pc_diff_e2e` — the ONLY edit outside the lane's files, flagged for the orchestrator) | LANDED |
| Phi_0 never materialized: `Phi0Source` (Aligned: `PhiFactored` value rings x limb radix; Small-cols: the tensor's phi rings via the shared `phi_small_cols_tensor`; Zero) with `fill(zq, v0, n, out)`; `level_h_pairs_with[_block]`; bin `bg_level_h_src`; the level-1 transport from `psi_level0_factored_multi` via `transport_level_from_psi`; one-level Tier-Z via `agg_tier_z_mask_floor_psi` | `oracle_mode()` keeps the materialized path (phi pass -> bg_level_h -> transport_level(compute_psi)); battery: source == phi pass (fast AND per-digit-ring oracle), windows == slices, `level_h_pairs_with` blocks 7/64/1024 x both stores == `level_h_pairs`, factored Psi_0 == compute_psi | bg_prove_group | LANDED |
| CRS memo Arcs: `expand_level_matrix_arc` (the memo's handle, no clone; `expand_level_matrix` = this + clone), `ZK_CRS_MEMO=0` (no memo insert) | values identical (same expansion; O1 leg) | BgPre / bg_prove_group / bg_verify_group hold `Arc<Vec<Poly>>`; the last-level bindings are cloned once for the agg_* Tier-Z / floor helpers (a few MB) | LANDED |
| dead-data levers: `uf_trim` = `malloc_trim(0)` at the phase boundaries (Linux/glibc only, `ZK_MALLOC_TRIM=0` off), `ZK_W0_REGEN=1` (free the i8 witnesses after the pre-commit, rebuild before the groups) | values untouched (residency only); rig digests | bk_pass_run, bg_prove_group | LANDED (trim default on; regen opt-in) |
| `uperf-f {diff-battery, bench, rss}` | bin section `// [UPERF2-F]` | — | — | LANDED |

## 2. The attribution — where the resident set went BEFORE (f512ba1 + the RSS rows only)

`uperf-pc full-profile` with the `[UPERF2-F] RSS` rows (VmHWM / VmRSS in
MiB at the boundary; the phase's own transient = HWM minus the RSS
before it). Every digest identical to the ledger's on every run.

| boundary | 3x16 1T hwm / rss | 12x64 8T hwm / rss | what was added |
|---|---:|---:|---|
| bk.layers-loaded | 130 / 130 | 587 / 587 | the 12 BfLayers as i64 (weights 453 MB + acts) |
| bk.witness-built | 1103 / 1103 | 5190 / 5190 | **w0 of both groups boxed: +4.6 GB at 12x64** (weight 3.54M digit rings x ~1,064 B = 3.77 GB, act 0.8M rings) |
| bk.precommit | 1595 / 1595 | 6962 / 6962 | the CRS memo (level-0 A of both groups 0.62 + 0.15 GB, Bu) + the returned CLONES of the same (x2), that0 |
| bk.claim-layer-end | 1642 / 1642 | 7679 / 6977 | +0.7 GB packed tables (transient), lane D's |
| bk.pair-nrw-88 (the peak pair) | 1785 / 1706 | 9479 / 7929 | the pair's trees + work tables (transient) — and ~1 GB that stays (arena) |
| bg.weight.phi-pass | 2575 / 2575 | 11548 / 11548 | **Phi_0 of the weight group materialized: +3.5 GB at 12x64** (n_0 mod-q rings, boxed) |
| bg.weight.level0-fold | 2860 / 2840 | 11728 / 11649 | w0_w `clear()`ed here — **the RSS does not fall** (glibc keeps the freed 1 KiB chunks) |
| bg.weight.level1 | 2860 / 2840 | **11913 / 11836** | the level-1 transport / matrices — **the process peak** |
| bk.verify-act-end | 2860 / 2842 | 11913 / 11550 | the verifier adds nothing (its psi0 is factored, its matrices are memo hits) |
| maxrss (`/usr/bin/time`) | 2,860 MiB | 11,913 MiB (12,199,148 KB) | |

Model at 12x512 from these rows (linear in T for the act-side terms,
fixed for the weights): boxed w0 ~12 GB (weight 3.8 + act 8 x 1.0),
Phi_0 of the act group ~8 GB, the CRS memo + clones ~4 GB, lays 1.5 GB,
the claim layer's packed tables ~5.8 GB (transient), the nrw-88 pair
~17.6 GB (transient) — the ledger's "~40 GB" reading, confirmed.

## 3. Method notes (the exact identities; why the bytes cannot move)

- **`SmallRings` / `DigitCols`.** Every kernel consumes a small ring by
  lifting its coefficients (`lift_to_p` into the Goldilocks domain, or
  `poly_from_small` into R_q) ring by ring; the trait's `ring(u, buf) ->
  &[i64]` returns the boxed ring's own slice or the i8 ring widened into
  a stack buffer — the SAME i64 values enter the SAME arithmetic, and
  the window bound (`max_abs`) is the same number. Every level-0 alphabet
  is |w| <= 64 (row EB4-emax caps e at 7; the class table's e0 is 1 or 2;
  the q-range aux class is 16 limbs at e0 = 2): `agg_digit_witness_cols`
  range-checks every digit into i8 (`digits_into` verbatim, the same
  per-value-ring split over the pool — a value ring's l0 digit rows are
  one thread's contiguous byte range). The `*_gen` bodies ARE the old
  bodies with `b[idx][u]` replaced by `b[idx].ring(u, &mut buf)`; the old
  names are one-line wrappers at `B = [Vec<i64>]`, so the batteries, the
  oracles and the synthetic agg_* rig run unchanged code paths.
- **`Phi0Source::fill` IS the phi pass on a window.** The phi pass
  (`kernel_pass_factored`, aligned tensors) computes `PHI_vr =
  PhiFactored::value_ring(vr)` once per value ring and pushes
  `poly_scale(radix_limb, PHI_vr)` per limb; the fill computes exactly
  that for the value rings a window touches (one PHI_vr per value ring,
  even when the window starts mid-value-ring); small-cols tensors keep
  their rings (the same `phi_small_cols_tensor` body the pass now calls —
  single-sourced); kernel-less tensors are zero; positions past the group
  are the chunk-grid's zero pad. The battery asserts `materialize() ==
  phi pass (fast) == phi pass (per-digit-ring oracle)` and nine windows
  (crossing tensor boundaries, past the end, empty) against slices.
- **`level_h_pairs_with` is bit-identical to `level_h_pairs`.** The NTT
  GEMM already splits its u range into capacity windows and, per window,
  flushes an EXACT integer partial sum (the single-prime contract n * D *
  (q-1)/2 * s_max <= (p-1)/2, checked from the data), reduces it mod q
  and adds it (`zq.add`) into the canonical output. Splitting the u range
  further into blocks (r slices' windows of <= 1024 positions, filled per
  block; each block's GEMM = its own exact windows) and adding the
  blocks' canonical results mod q gives the same residue: every partial
  is the true integer sum of its terms mod q, and mod-q addition of true
  partial sums is the true total mod q. A block's window may be larger
  than the whole-chunk one (its local s_max is <= the global one) — every
  window is still exact. The battery drives blocks 7 / 64 / 1024 at three
  splits (chunk not a multiple of the block; the pad) on both stores.
- **The level-1 transport from the factored Psi_0.** Phi_0 enters the
  transport ONLY through Psi_0 = compute_psi(Phi_0, chunk_0, c_0);
  `psi_level0_factored_multi` computes that Psi_0 from the multi-claim
  kernels without Phi_0 (the O5 battery leg pins it against
  compute_psi(phi0_reference_multi); the lane's leg pins it against
  compute_psi(the phi pass) at three splits) — the prover now takes the
  verifier's route (`bg_verify_group` has consumed the factored Psi_0 at
  level 1 since BJ). One-level Tier-Z schedules take the same Psi_0
  through `agg_tier_z_mask_floor_psi` (the body after `compute_psi`).
- **CRS Arcs.** `expand_level_matrix` cached `Arc::new(v.clone())` and
  returned `v` — two copies of every matrix while a caller held one;
  `expand_level_matrix_arc` returns the memo's own handle. Same bytes
  (the O1 leg: raw == memo == par at both moduli). `ZK_CRS_MEMO=0` skips
  the insert (each expansion freed with its last handle; the verifier
  re-expands — +1.2 s at 12x64 8T).
- **`malloc_trim(0)`.** The pass frees millions of ~1 KiB boxed rings
  (level-0 phi on the oracle path, CRS matrices, deeper witnesses, the
  claim layer's boxed leftovers); glibc keeps them in its arena — VmRSS
  never falls after `drop`, and the next phase's large mmap'd tables
  cannot reuse those chunks. `malloc_trim(0)` walks the arenas and
  MADV_DONTNEEDs whole free pages (glibc >= 2.8): values untouched,
  milliseconds (3x16 8T A/B on/off: 10.0/9.5 vs 9.8/9.6 s). Linux/glibc
  only — a `cfg(target_os = "linux")` extern; a no-op on the Mac (whose
  allocator returns large frees itself). `ZK_MALLOC_TRIM=0` disables it.
- **`ZK_W0_REGEN=1`.** Between the pre-commit (u_0) and the group eval
  proofs nothing reads w0; the knob drops both i8 stores there and
  rebuilds them (the same deterministic decomposition of the same layer /
  aux values, re-padded to the chunk grid) before the groups: one extra
  digit-witness pass (+0.35 s at 12x64 8T) for their residency through
  the claim layer + descents. Off by default (behavior identical to
  before); the report's "floor" rows use it.
- Threads: the fill is parallel over the r slices (each slice's window is
  one thread's own), the GEMM over positions (the kernel's own split), the
  digit witness per value-ring block — exact work with fixed reduction
  order, identical for any ZK_THREADS (batteries at 1/2/7; the rig at 1
  and 8).

## 4. Differential evidence + gates (all at HEAD of uperf2-f, final binary)

- `uperf-f diff-battery` 40/40 at ZK_THREADS 1, 2, 7 (BATTERY DIGEST
  77583bed5c9ea04e0b1413ed2b2abbed96f09a9805406bdbd2312824631ddbf5
  identical): per (q31, q46) x (r 3 / chunk 17 / e 2; r 5 / 64 / e 7;
  r 2 / 130 / e 1, zero rings planted): DigitCols round trip, `ntt_gemm`
  boxed == i8, level-h boxed == i8 == ref boxed == ref i8, matvec-multi
  the same four ways, fold the same four ways; on a mixed synthetic group
  (aligned nb 1 / 2, sign-binary, a misaligned 96-col tensor, a no-kernel
  tensor, l0 13, shared col kernels): kernel-pass rows boxed == i8 (fast)
  == boxed == i8 (oracle flip); `Phi0Source::materialize` == phi pass
  (fast) == phi pass (oracle flip); nine fill windows == slices (+ zero
  pad); `level_h_pairs_with` at blocks 7 / 64 / 1024 on both stores ==
  `level_h_pairs` at r 3 / 5 / 8; factored Psi_0 == compute_psi(Phi_0)
  at r 3 / 5 / 8; `agg_digit_witness_cols` == `agg_digit_witness` == ref
  on real-class values (X int8, W sign-binary, Acc 25-bit, Q q-range l0
  16; 2,544 digit rings).
- `uperf-f bench 2048 2048 64` [WSL 1T NOISY-SHARED]: the materialized
  route (phi pass 0.353 + level-h 1.619 + compute_psi 0.347 = 2.319 s,
  VmHWM +203 MiB) vs the factored route (Phi0Source 0.050 + level-h-with
  1.778 + psi0-factored 0.418 = 2.245 s, VmHWM +0 MiB) — byte-identical
  h pairs and psi.
- `uperf-pc diff-battery` at ZK_THREADS 1 and 7: O1 4/4 (+ par 4/4),
  O2 35/35, O3 63/63, O5 12/12, **E2E 2/2** (the whole bg_prove_group /
  bg_verify_group on the DigitCols store under oracle AND fast routing —
  the routing flip covers the materialized-vs-factored Phi_0 path and the
  boxed-vs-i8 kernels in one process; field-identical proofs, both
  verify, cross-verify).
- Gates at HEAD (final binary): `uperf-a descent-battery` 18/18 at 1T
  and 7T (BATTERY DIGEST f936ff79.. unchanged); `uperf-c diff-battery`
  1T + 7T green; `uperf-d diff-battery` 30/30 at 1T + 7T (BATTERY DIGEST
  46471467.. UNCHANGED — the boxed `agg_digit_witness` the leg pins is
  untouched; the flat store is a sibling); `uperf-e diff-battery` 24/24 +
  8/8 + 8/8 (BATTERY DIGEST 59117121.. unchanged); `bh-verifier battery`
  green (12.6 s); `agg-matmul battery` green (120.0 s); `self-test`
  passed (257.0 s; every ok row identical to the merge-DE capture);
  freeze-check 98 `ok` rows identical to the pre-change capture (the
  untouched f512ba1 binary; then the expected BF panic); `pass-agg
  battery` 14/14 (REAL 3x16 data, all tamper arms, 75.9 s at 8T);
  `table-descent battery small` 5/5 (real data, 38.9 s at 8T); `t-blind
  battery` 11/11 (real data — the blind tensors ride the flat weight
  witness).
- THE REAL-DATA GATES: `uperf-pc full-profile 3 16` — accept = true,
  statement digest 93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790,
  985,142 B, EVAL-PROOF DIGEST 0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be
  at ZK_THREADS 1 and 8 after EVERY step (item 1, item 2, item 3, the
  levers; 12 runs); `uperf-pc full-profile 12 64` at ZK_THREADS 8 —
  accept = true, statement digest 80763ea537e77cd9cb5c538397af2622044447d654b8e9a34cae3ccad8f3f115,
  1,308,775 B, EVAL-PROOF DIGEST 63f4a3a4320a47260ab8ae3d52cfa3656b626fc367af671c6c317300454dec89
  on all five variants (items 1-3; + regen; + regen + no-memo; + trim; the
  final binary + regen + no-memo).

## 5. Before / after — the RSS rows and the timing rows

### 5.1 The 3x16 REAL rig, ZK_THREADS 1 (hwm / rss in MiB; digests identical on every column) [WSL 1T NOISY-SHARED]

| boundary | f512ba1 (before) | + item 1 (w0 i8) | + item 2 (phi never materialized) | + item 3 (CRS Arcs) |
|---|---:|---:|---:|---:|
| bk.witness-built | 1103 / 1103 | **249 / 249** | 249 / 249 | 249 / 249 |
| bk.precommit | 1595 / 1595 | 734 / 734 | 734 / 734 | **546 / 507** |
| bk.pair-nrw-88 | 1785 / 1706 | 925 / 845 | 924 / 845 | 682 / 603 |
| bg.weight.phi-pass | 2575 / 2575 | 1714 / 1714 | **924 / 903** | 682 / 661 |
| bg.weight.level0-h | 2609 / 2609 | 1748 / 1748 | 924 / 922 | 682 / 680 |
| bg.weight.level0-fold | 2860 / 2840 | 1999 / 1892 | 1146 / 996 | 903 / 637 |
| bg.weight.level1 | 2860 / 2840 | 1999 / 1981 | 1167 / 1158 | 903 / 746 |
| bk.verify-act-end | 2860 / 2842 | 1999 / 1971 | 1248 / 1149 | 938 / 877 |
| **maxrss** | **2,860 MiB** | 1,999 MiB | 1,247 MiB | **938 MiB** |
| wall (commit / prove / verify) | 29.1 s (4.0 / 21.4 / 3.6) | 29.4 (3.6 / 21.9 / 3.8) | 32.0 (3.9 / 24.2 / 3.8) — noise, see the A/B | 32.1 (3.7 / 24.8 / 3.6) — noise |

Same-state A/B, base f512ba1 vs the item-2 binary, alternating, 3x16 1T
[NOISY-SHARED, load 1.5-2.2]: base 28.5 / 28.7 s, HEAD 28.7 / 30.2 s
(maxrss 2,929 vs 1,278 MiB) — the phi routing is neutral within the
box's noise; the 32.x s rows above were taken while lane G ran heavy
legs. 3x16 at ZK_THREADS 8 (final binary): 9.5-9.8 s wall (commit 1.2 /
prove 6.9-7.2 / verify 1.2), maxrss 1,031-1,035 MiB (ledger 8T row: 9.9
s at 4dcaea6), digests identical.

### 5.2 The 12x64 REAL rig, ZK_THREADS 8 (hwm / rss in MiB; digests identical on every column) [WSL 8T NOISY-SHARED]

| boundary | f512ba1 (before) | items 1-3 | + malloc_trim (final default) | + `ZK_W0_REGEN=1` (pre-trim binary) | final + `ZK_W0_REGEN=1 ZK_CRS_MEMO=0` (floor) |
|---|---:|---:|---:|---:|---:|
| bk.layers-loaded | 587 / 587 | 587 / 587 | 587 / 587 | 587 / 587 | 587 / 587 |
| bk.witness-built | 5190 / 5190 | **1142 / 1142** | 1142 / 1142 | 1142 / 1142 | 1142 / 1142 |
| bk.precommit | 6962 / 6962 | 2346 / 2028 | 2346 / 2022 | 2346 / 2029 -> w0-freed 1474 | 2346 / 2022 -> w0-freed 1467 |
| bk.claim-layer-end | 7679 / 6977 | 2746 / 2043 | 2746 / 2027 | 2346 / 1489 | 2346 / 1472 |
| bk.pair-nrw-88 (peak pair) | 9479 / 7929 | 4545 / 2995 | 4546 / 2065 | **3991 / 2441** | **3991 / 1511** |
| bk.groups-start | 9479 / 8037 | 4545 / 3103 | 4546 / 2149 | 3991 / 2981 (rebuilt) | 3991 / 2149 (rebuilt) |
| bg.weight.phi-pass | 11548 / 11548 | 4545 / 3108 | 4546 / 2163 | 3991 / 2985 | — |
| bg.weight.level0-fold | 11728 / 11649 | 4545 / 2854 | 4546 / 2007 | 3991 / 2732 | 3991 / 2007 |
| bg.weight.level1 | **11913 / 11836** | 4545 / 2999 | 4546 / 2392 | 3991 / 2877 | 3991 / 2378 |
| bk.verify-act-end | 11913 / 11550 | 4545 / 2797 | 4546 / 2577 | 3991 / 2795 | 3991 / 2771 |
| **maxrss** | **11,913 MiB** (12,199,148 KB) | **4,545 MiB** | 4,545 MiB | **3,991 MiB** | 3,991 MiB |
| wall (commit / prove / verify) | 45.5 s (7.6 / 33.8 / 3.7) | **42.4 (5.4 / 33.1 / 3.3)** | 46.6 (5.7 / 36.8 / 3.5) — load 3-4.5 | 42.8 (5.2 / 33.7 / 3.4) | 46.3 (5.1 / 35.4 / 5.2) — the verifier re-expands the CRS (ep.crs-expand 3.06 s x68) |

Reading the rows: after items 1-3 the process peak is the nrw-88 descent
pair (its own transient ~2.2-2.5 GB at T = 64 — 16 trees at depth 19, 12
real: lane A/E/G's file) sitting on the baseline present at that moment
(lays 0.59 + w0 i8 0.55 + the CRS memo 0.88 + retained arena ~0.5-1.0
GB); `malloc_trim` removes the retained arena through the pairs (the rss
plateau 2.4-3.1 -> 2.0-2.1 GB) but not the peak (the pair's tables are
fresh mmap'd blocks either way); `ZK_W0_REGEN=1` removes the 0.55 GB of
witnesses under the pair (peak 4.55 -> 3.99 GB); `ZK_CRS_MEMO=0` on its
own removed nothing (the freed boxed matrices stayed in the arena); with
the trim it lowers the resident set UNDER the pair by ~0.9 GB (rss 2441
-> 1511 at nrw-88) but the peak stays 3,991 MiB: the trimmed arena pages
are simply re-faulted by the pair's own small allocations (eq tables,
claims) instead of growing the heap — i.e. the 12x64 peak is now the
pair's true footprint (~2.5 GB) plus the layers and the pass state it
needs (~1.5 GB), and no knob of this lane moves it further.
The commit phase is faster (7.6 -> 5.2-5.7 s: the flat digit witness,
`d.digit-witness` 2.65 -> 0.35 s at 8T); the group proofs are neutral.

### 5.3 The 12x128 REAL rig (first time on this box) and the 12x512 model

`uperf-pc full-profile 12 128` at ZK_THREADS 8, final binary, default
knobs [WSL 8T NOISY-SHARED] — model before the run: baseline ~2.5 GB +
the nrw-88 pair at depth 20 ~4.5-5 GB = ~7-7.5 GB:

| boundary | hwm / rss (MiB) |
|---|---:|
| bk.layers-loaded | 722 / 722 |
| bk.witness-built | 1398 / 1398 (w0 i8 both groups: 0.68 GB) |
| bk.precommit | 2837 / 2495 |
| bk.claim-layer-end | 3931 / 2500 (tables transient 1.4 GB) |
| bk.pair-nrw-88 | **7438 / 2543** (the pair's transient 4.9 GB — 2.2x the T = 64 pair) |
| bg.weight.level1 | 7438 / 2881 |
| bk.verify-act-end | 7438 / 2979 |
| **maxrss** | **7,438 MiB** (7,616,924 KB) |

accept = true, statement digest 4a3af8c3b28de9b0c472d653f981fd85bb024df23e33b08ca7f8d77cbb1bf688,
1,372,775 B counted, EVAL-PROOF DIGEST 742d88e1a030f9be6a6c4eee5cf19f42eaf6e289e0814c4bb3e5b9b03bddcb69,
wall 66.2 s (commit 7.4 / prove 53.7 / verify 4.4) — the first 12x128
full-statement run on this box; these digests are the reference for the
next run of the shape (no earlier value exists). 12x256 [MODEL]: ~3.5 +
10.8 = ~14 GB — over the box's edge with lane G resident; NOT attempted
(the brief's margin rule). 12x512 [MODEL, linear in the
act-side terms from the 12x64 rows]: lays 1.5 GB (i64 layers), w0 i8
1.3 GB (0 with regen during the pass's peak), CRS memo 1.9 GB (0 with
`ZK_CRS_MEMO=0` + trim; +2-3 s of XOF), claim-layer tables 5.8 GB
transient (lane D's packed tables; peak of that phase ~8-9 GB — fits),
the group proofs ~5-6 GB peak (fits), and the nrw-88 descent pair
**~20-24 GB transient** (16 trees at depth 22, 12 real: 2.2 GB at T = 64
x ~2.2 per doubling of T measured at T = 128; lane A's own 21 GB
estimate) — the ONLY term that does not fit: 15 GB minus a ~1.5-2 GB
floor leaves ~12-13 GB for the pair, so its footprint must come down ~2x
(lane G's fold/extract fusion + arena cut table traffic and count; a
per-instance streaming of the pair's tables, or a smaller pair split
in the statement-derived inventory, is the structural fix — not this
lane's file).

## 6. What is left (honest state at close)

1. **The descent pair's footprint** (kfield.rs / gkr_masked.rs / the BK
   descent phase — lane G): 2.2-2.5 GB at T = 64, 4.9 GB at T = 128
   (measured), ~20-24 GB at T = 512 for nrw-88 alone; the one term
   between this pass and the 15 GB box at 12x512. Everything else of the pass fits under ~7-9 GB at 12x512 with
   `ZK_W0_REGEN=1` [MODEL].
2. **Flat CRS matrices**: `Vec<Poly>` (boxed rings) means freed matrices
   never leave the arena without a trim, and the memo holds ~1.9 GB at
   12x512; a flat `Vec<u64>` matrix type (rows*cols*D) returns on drop
   and would let `ZK_CRS_MEMO=0` mean what it says without the trim; the
   consumers take `&[Poly]` today (matvec, transport, the O1 leg) — a
   wider type change, left.
3. **`BfLayer` as i64**: the 12 layers cost 1.5 GB at 12x512 as i64
   (weights 453 MB alone); int8/int32 storage per entry class would save
   ~1.1 GB — lane D's `bf_load_layer` and the freeze rows depend on it,
   not touched.
4. **The verifier's psi0 + the prover's factored Psi_0** both rebuild
   `PhiFactored` (G blocks per (col kernel, cb)) — 2 s of `ep.psi0-
   factored` per call at 12x64 8T; a per-group PHI_vr cache (n_0 / l0
   rings, ~1 GB at 12x512) would make the level-h fill a scale and the
   Psi_0 a per-value-ring product — a memory-vs-time trade left as a
   knob idea.
5. `ZK_W0_REGEN=1` could become the default once T1 has measured its
   +0.35 s (12x64 8T) against the Mac's clock; left opt-in this round.
6. Nothing here has been measured beyond 12x128 on this box: TASK_BOARD
   T1's one-binary A/B on the Mac (`ZK_UPERF_ORACLE=1` vs default,
   EVAL-PROOF DIGEST identical) is the honest test of the projections.
