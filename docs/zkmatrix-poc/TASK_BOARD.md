# TASK BOARD — the standing queue of small, self-checking tasks

Status: LIVE (opened 2026-08-17). Companion to CONTINUATION.md (the
phase plan) and PROGRESS_UPERF.md (the ledger). This page exists so
that ANY agent — Claude, Grok/Cursor, a human — can advance the
prove/verify clocks without reopening design. Every task below names
its files, its exact commands, and a byte-identity acceptance. If a
task's acceptance fails, revert the task's code and record the failure
here; do not "fix forward" into the transcript.

If you are Grok/Cursor: start at Section 3, take the first task marked
`OPEN` whose `WHO` includes your box, and follow it literally.

## 1. Rules (read once)

1. **Differential floor.** A performance change is accepted ONLY if
   (a) its function-level battery leg holds byte equality against the
   reference implementation, (b) `ring_matmul freeze-check` exits 0
   with every pre-existing digest unmoved, and (c) the EVAL-PROOF
   DIGEST printed by `uperf-pc pass-profile` is identical before and
   after at the same shape (Section 2.3). A speedup that moves any of
   those is a bug — revert.
2. **Transcript-preserving only.** Do not change what is absorbed into
   the transcript, the order of RNG draws, planner parameters (r cap,
   kappa, e caps), or any freeze row. Those are R-rows: file them in
   U_PERF_WAVE_REPORT.md Appendix R for Victor's ruling, do not build.
3. **One task, one commit** (or a short series of commits), message
   prefix `U-PERF PC:` and the task id, e.g.
   `U-PERF PC: T4 matvec_modq_small_multi (NTT-domain, O3) — battery leg green`.
4. **Timing labels are mandatory**: `[MAC-BOX]` or `[WSL-BOX]`, `1T` or
   `NT`, `QUIET` or `NOISY-SHARED` (frugal-lm training on the Mac =
   NOISY). Wall numbers without labels are not recorded.
5. **Do NOT touch**: `codex-audit-*`, `scripts/logup_*_spike.py`,
   `src/manifest.rs`, kfield/sumcheck/gkr/gkr_masked internals (PA's
   zone), lookup/digits/fold/pass_agg/t_blind/descent_fold/wire.
   In-scope files for the clock work: `zkmatrix-rs/src/ring/eval_proof.rs`,
   `zkmatrix-rs/src/aux_ntt_core.rs` (additive only), the `bg_*` /
   `agg_*` / `bk_*` / `uperf_pc_*` sections of
   `zkmatrix-rs/src/bin/ring_matmul.rs`, `tests/test_uperf_pc.py`,
   `docs/zkmatrix-poc/U_PERF_WAVE_REPORT.md`, this file,
   `PROGRESS_UPERF.md`.
6. **Record every result** in the task's `RECORD` target with the
   4-line format: date+box+label / command / verdict+numbers /
   commit hash. Then flip the task's status here.

## 2. Box facts and recipes

### 2.1 The two boxes

| | MAC-BOX (M3 Ultra) | WSL-BOX (Intel Core Ultra 9 185H) |
|---|---|---|
| RAM | 256 GB | 15 GB |
| frugal-lm ckpt + `results/m125_ffn_export/*.bin` | YES | ckpt YES (tarball, 2026-08-17); the frozen export's 36 weights YES (byte-identical), its 12 X files **NO** (Mac Metal rounding) — instead the local re-export `results/m125_ffn_export_wsl/` (valid witness, X differs) via `M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl` |
| composed pass 12x512 (RSS 41-47 GiB) | runs | **cannot run** (RAM); 3x16 and per-layer T=16 rigs RUN with `M125_EXPORT_DIR` set |
| `freeze-check` | full, exit 0 required | first 98 rows green, then panics at the UAGB1-BF rows (missing export) — EXPECTED here |
| python suite | all green required | 77 pass, 2 skip, and EXACTLY these 4 fail for the same missing-export reason (freeze-check SIGABRT / layer00_X.bin): `test_ring_freeze_check`, `test_freeze_rows_uagb1_bf`, `test_pass_smoke_real_data`, `test_freeze_rows` (tblind) — measured 2026-08-17 at 213dfa2, 469 s. Any OTHER failure is real. |
| `uperf-pc diff-battery`, `agg-matmul ...`, `bh-verifier ...`, `agg-kel`, unit rigs | run | run |
| build | `cargo build --release` in `zkmatrix-rs/` | same (plain `cargo`; the rustup proxy is ahead of snap on PATH) |
| timing status | frugal-lm F2 training may be running (check `top`) -> label NOISY-SHARED | usually quiet; is the TARGET_CONTRACT "CPU reference machine" |

So: code + function-level batteries can be written and verified on
EITHER box; the 125M profiles / A/Bs / full freeze-check / suite /
pass-agg batteries are MAC-BOX tasks.

### 2.2 Commands (all from the repo root unless noted)

```
# build (from zkmatrix-rs/)
cargo build --release
# gates
zkmatrix-rs/target/release/ring_matmul freeze-check            # exit 0, no FAIL rows [MAC full; WSL panics at BF rows]
zkmatrix-rs/target/release/ring_matmul uperf-pc diff-battery   # every optimization's byte-equality leg
python3 -m unittest discover -s tests                          # suite (~15-20 min MAC; export-dependent tests skip on WSL)
# profiles (MAC only; minutes to ~1.5 h)
zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16      # fast yardstick (~6-8 min): FULL-STATEMENT attribution + EVAL-PROOF DIGEST
zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512    # the real thing (~80 min prove + verify before the kernels)
zkmatrix-rs/target/release/ring_matmul uperf-pc pass-profile 12 512    # composed scope only (no table descents; BG rig)
zkmatrix-rs/target/release/ring_matmul pass-agg prove 12 512 p0        # composed-scope prove+verify (BG rig)
zkmatrix-rs/target/release/ring_matmul table-descent prove 12 512 p0   # FULL-STATEMENT prove+verify (BK rig, the PoC number)
zkmatrix-rs/target/release/ring_matmul pass-agg battery                # 14 legs, ~70 min [MAC]
zkmatrix-rs/target/release/ring_matmul pass-agg seam                   # 12/12 psi-seam differential (~1 min)
zkmatrix-rs/target/release/ring_matmul agg-matmul battery              # 23 legs, ~4 min, synthetic (runs on WSL)
zkmatrix-rs/target/release/ring_matmul bh-verifier battery             # BH differential + BF-F3 legs (synthetic)
```

Wrap long runs in `/usr/bin/time -v` (Linux) or `/usr/bin/time -l`
(macOS) so wall + peak RSS land in the record.

### 2.3 The EVAL-PROOF DIGEST (the composed-pass differential gate) and the two env knobs

`uperf-pc pass-profile <layers> <t>` prints
`[UPERF-PC] EVAL-PROOF DIGEST <hex>` = SHA-256 over both groups'
GroupEvalProof wire fields (b_rows, u0, ugh0, level_us, floor,
tcap_attempts) in order. It must be IDENTICAL at the same
(layers, t, mode) before and after any Phase-0 change. Baselines are
recorded in Section 4 as they are measured (T1).

Two environment knobs make every A/B a ONE-BINARY affair:

- `ZK_UPERF_ORACLE=1` routes every Phase-0 kernel entry point
  (matvec / ring-ip / level-h / the claim-kernel passes / the
  verifier's factored psi) to its pre-optimization oracle at runtime.
  Same binary, same box, same shape: run once with it (the "before")
  and once without (the "after"); the digests must be identical and
  the walls are the A/B.
- `ZK_THREADS=n` (default 1 = the ledger's 1T convention) sizes the
  kernel thread pool; every parallel split is over independent
  exact-integer work with a fixed reduction order, so the digest is
  identical for any n (the battery asserts it at 1/2/7). Record NT
  numbers as a separate row, never in place of the 1T number.

## 3. The queue (ordered; take the first OPEN task your box can do)

Legend: WHO = MAC | WSL | ANY (which box can do it); KIND = RUN (run
commands, paste numbers), CODE (write code + battery leg), DESIGN (not
for a mechanical agent — leave for Claude/Victor).

---

### T0 — hygiene at every commit  `STANDING`  WHO: ANY  KIND: RUN
Before every commit that touches Rust: `cargo build --release` green,
`uperf-pc diff-battery` green, `freeze-check` (MAC: exit 0; WSL: 98
rows then the expected BF panic — paste the last `ok` row). Before
every PUSH from the MAC: full suite green.

---

### T1 — pass-profile BASELINE + AFTER (attribution table + digest)  `OPEN`  WHO: MAC  KIND: RUN
WHY: nobody has run the composed-pass profile; every share above is
BG-F3 arithmetic. This gives the measured before/after tables AND the
digest identity for O2/O3/O5/T8b (which landed 2026-08-17 on the WSL
box with battery legs only). ONE binary, two env settings (2.3).
STEPS (`full-profile` = the FULL-STATEMENT rig incl. the 10 descent
pairs — the PoC number, ~80 min before; `pass-profile` = the composed
scope without table descents — use it only if full-profile cannot run):
1. `git pull`; `cargo build --release` (in zkmatrix-rs/); `mkdir -p results/uperf`.
2. Fast yardstick, BEFORE then AFTER (each ~5-10 min):
   `ZK_UPERF_ORACLE=1 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16 > results/uperf/fp_3x16_oracle.txt 2>&1`
   `/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 3 16 > results/uperf/fp_3x16_fast.txt 2>&1`
   The two `EVAL-PROOF DIGEST` lines MUST be identical. If not: STOP,
   record, do nothing else (that is a bug report, not a fix).
3. The real thing, AFTER first (so the useful number exists early),
   then BEFORE (~80-90 min; peak RSS ~47 GiB; nothing else heavy):
   `/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/fp_12x512_fast.txt 2>&1`
   `ZK_UPERF_ORACLE=1 /usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc full-profile 12 512 > results/uperf/fp_12x512_oracle.txt 2>&1`
4. Optional NT row: `ZK_THREADS=8 ... full-profile 12 512` (digest
   identical; record as a separate NT row). The phase table's
   `bk.descent-trees` / `bk.descent-gkr` / `bg.commit-phase` /
   `bg.claim-layer` / `bg.prove-group` / `bg.verify-group` rows are the
   next round's priority order.
5. Copy the phase tables (the `ep.*` / `bg.*` rows), `accept`, walls
   (commit/prove/verify), and the digests into U_PERF_WAVE_REPORT.md
   Section 4.2 (before/after per shape) and Section 4 of THIS file.
ACCEPT: `accept = true` everywhere; digests identical oracle vs fast
(and vs NT); the 12x512 statement digest equals the frozen
`76dbf2040409333e` prefix printed by the rig.
RECORD: U_PERF_WAVE_REPORT.md Section 4.2; TASK_BOARD Section 4;
PROGRESS_UPERF.md log line ("T1/T4 measured: ...").
NOTE: `results/uperf/` is new; add a `.gitignore` with `*.txt` if the
files are large, and paste the tables into the report.

---

### T2 — the h cross-garbage in the NTT domain (O2)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: ANY  KIND: CODE
DONE: `eval_proof::level_h_pairs` + `ntt_gemm_modq_small` + oracle
`level_h_pairs_ref`; `bg_level_h` / `agg_level_h` switched; battery
leg "O2 level-h" 35/35; freeze-check rows identical to the pre-change
baseline; `agg-matmul battery` 22/22 + passed; `bh-verifier battery`
passed. Kernel-bench [WSL-BOX 1T QUIET] `uperf-pc kernel-bench 64
2048`: 0.245 us/product NTT vs ~5.0 us/product kara (r=16 oracle run)
=> ~20x on the level-0 term on this box (Section 4 of
U_PERF_WAVE_REPORT.md). Remaining for T4: the 12x512 digest + wall.
WHY: the largest term of the composed prove (~500M + ~227M ring-mults at
125M, ~2 us each on `ring_ip_modq_small`). Same arithmetic, ~15-25x.
WHAT: `eval_proof::level_h_pairs(ctx, phi_slices, w_slices) -> Vec<Poly>`
— r x chunk mod-q slices and r x chunk small slices, returns the
r(r+1)/2 h polys in pair order (j <= k), computed as D independent
(r x chunk) x (chunk x r) integer GEMMs in the NTT domain (transform
each ring once, split-halves lazy accumulation, exact-integer capacity
windows from `aux::max_n_acc`, one inverse per (pair, window)), with
`level_h_pairs_ref` = the current kara loop kept as the oracle.
Callers `bg_level_h` (bin, ~line 29152) and `agg_level_h` (bin, ~line
20068) switch to it. Battery leg in `uperf_pc_diff_battery`: random
q31 AND q46, r in {1,2,3,5,8}, chunk in {1,7,64,257}, w with extreme
digits (+-s_max, zero rings, whole-zero slices), windows crossing (q46
+ s_max 64 => 32-term windows), and the over-capacity fallback.
ACCEPT: leg prints `O2 level-h: N/N byte-identical`; freeze-check per
T0; `agg-matmul battery` 23/23; then (MAC) pass-profile 3x16 digest ==
T1 baseline.
RECORD: U_PERF_WAVE_REPORT.md Section 3 (O2), this row.

---

### T3 — matvecs in the NTT domain (O3)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: ANY  KIND: CODE
DONE: `matvec_modq_small` (all call sites, prover + verifier) and
`ring_ip_modq_small` ride the kernel; new `matvec_modq_small_multi`
in `bg_matvec_chunks` / `agg_level_t`; oracles `*_ref`; battery leg
"O3 matvec" 63/63; same transcript gates as T2. Kernel-bench: 0.65
us/product NTT vs ~5.3 us kara [WSL-BOX 1T].
WHAT: `eval_proof::matvec_modq_small_multi(ctx, m, rows, cols, s_list)
-> Vec<Vec<Poly>>` (one M, many small vectors; M transformed once per
call, u-major accumulation into rows x len(s_list) accumulators);
`matvec_modq_small` and `ring_ip_modq_small` bodies switched to the
same window-accumulate primitive with the kara bodies kept as
`*_ref` oracles. Callers: `bg_matvec_chunks` (bin ~29107),
`agg_matvec_chunks` (bin ~20040) use `_multi`. Battery legs as in T2
(shapes rows in {1,11}, cols in {1,5,64,301}, both q's, extreme digits,
window crossings, fallback).
ACCEPT/RECORD: as T2 (leg `O3 matvec: N/N byte-identical`).

---

### T4 — the rest of the rig gates after T1  `OPEN (after T1)`  WHO: MAC  KIND: RUN
STEPS (all at HEAD, fast path): `freeze-check` exit 0 (full, incl. the
BF rows); `pass-agg seam` 12/12; `pass-agg battery` 14/14 (~70 min);
`table-descent prove 12 512 p0` for the full-statement wall (also once
with `ZK_UPERF_ORACLE=1` if time permits — the two `accept`/bytes
lines must match); the python suite green before any push.
RECORD: U_PERF_WAVE_REPORT.md Section 4.2, PROGRESS_UPERF.md log line,
this row.

---

### T5 — the two claim-kernel passes, factored (rows pass + phi pass)  `LANDED 2026-08-17 (Claude, WSL) — rig A/B = T4`  WHO: Claude preferred (ANY with care)  KIND: CODE
DONE: `eval_proof::kernel_pass_factored` (+ `ColBlockCache`, `cq0_block`,
`g_block`), wired at the prover's two passes and the verifier's
non-recursed rows_eval; `bg_kernel_pass` kept as the oracle; battery
leg "O5 kernel-pass" 6/6; kpass-bench 512x2048: rows 42.6x, phi 51.5x
[WSL 1T]. Details: U_PERF_WAVE_REPORT.md Section 3 (O5). The text
below is the derivation as built (kept for the record).
WHY: `bg_kernel_pass` (bin ~29210) is the second-largest prover term:
per DIGIT ring it calls `claims.kw_value_row` (per value ring: 128 x
n_contrib x 2 K-field mults — likely the hidden cost) and then 16
`ring_mul_split_kara_fast`; twice (rows pass, then phi pass): ~365M
ring-mults + ~1.4G K-mults at 125M.
WHAT (exact identities; everything below is a re-association of the
same mod-q sums, so byte identity is by construction; the current
`bg_kernel_pass` is the oracle). Notation: tensor with `rows x cols`,
`cols % 128 == 0` (all 125M tensors; else fall back to the oracle
path), value ring vr = (row, cb) with cb = column block, digit ring u =
(vr, limb), radix_u = 2^(e0*limb); K-field bilinearity:
`kf.mul(x, y)[d] = sum_{d1} x[d1] * (Y^{d1} * y)[d]`; contributions
`c` = (scale_c, row_c[.], col_c[.]) with kw_u[c1] = sum_c
kf.mul(scale_c*row_c[row], col_c[cb*128 + c1]).
- Hoist: `sr_c[row] = kf.mul(scale_c, row_c[row])` once per (c, row).
- phi pass: for each (c, cb, d1) precompute the mod-q RING
  `G_c[cb][d1] = sum_{c1} conj(X^{c1}) * ( sum_d (Y^{d1} * col_c[cb*128+c1])[d] * alpha_d )`
  (n_contrib x nb x 16 rings per tensor — trivial). Then for every
  value ring: `PHI_vr = sum_c sum_{d1} sr_c[row][d1] * G_c[cb][d1]`
  (16 x n_contrib scalar-x-ring MACs with u128 lazy accumulation, one
  mod-q reduce), and `phi_u = radix_limb * PHI_vr` per limb. This is
  the verifier's `psi_level0_factored` trick on the prover side.
- rows pass: `V_vr = sum_limb radix_limb * w_(vr,limb)` (the value
  ring recomposed mod q — small rings x radix, exact); then per
  (c, d1): `T_c[d1][cb] += sr_c[row][d1] * V_vr` over rows (scalar x
  ring MACs, u128 lazy); finally
  `b_rows[d] = sum_c sum_{d1} sum_{c1} conj(X^{c1}) * sum_cb (Y^{d1} * col_c[cb*128+c1])[d] * T_c[d1][cb]`
  (n_contrib x 16 x 128 x nb scalar-x-ring MACs — trivial).
Both passes become O(n_value_rings x 16 x n_contrib) scalar-ring MACs
(~6G mult-adds at 125M, seconds) with NO per-ring K-mults and NO ring
mults. Keep the misaligned/absent-kernel path on the oracle.
Battery leg: synthetic groups (the `bh-verifier` builders + the real
`bg_build_groups` on the 3x16 shape on the MAC), byte identity of
`b_rows` and of every `phi` ring against the oracle.
ACCEPT/RECORD: as T2 (leg `O5 kernel-pass: N/N byte-identical`).

---

### T6 — multithread the kernels (rayon, deterministic)  `LANDED for the Phase-0 kernels 2026-08-17 (Claude, WSL); the rest OPEN`  WHO: ANY  KIND: CODE
DONE: `ZK_THREADS=n` pool in eval_proof.rs; the NTT GEMM (transforms
per ring, the D coefficient positions of the accumulate, the scatter,
the flush), the factored phi pass (value-ring blocks), the rows pass
(per-range partial T sums reduced in order + per-(kernel, cb) block
products) and the verifier's factored psi (value-ring blocks) all
split over independent exact-integer work. Battery identical at
ZK_THREADS 1/2/7. Kernel-bench 64x8192 [WSL]: level-h 7.6 s (1T) ->
1.24 s (20T) = 6.6x on this hybrid 6P+8E box; kpass-bench 512x2048:
rows 2.55 -> 0.74 us/digit ring, phi 2.39 -> 0.91 at 7T (fixed
per-tensor precomputes bound the gain at this size).
OPEN (same recipe): `bg_fold`/`agg_fold` (T7), the transport levels
(T3b), the descents (PA/BK zone — see T11), commit's chain derivation.
RECORD: U_PERF_WAVE_REPORT.md Section 4 (a 1T vs NT row from T1 step 4).

---

### T7 — `bg_fold` / `agg_fold` in the NTT domain (small)  `OPEN`  WHO: ANY  KIND: CODE
`z_u = sum_j c_j * w_{j,u}` (small x small, exact i64) — currently
`poly_mul_small` schoolbook (16K MACs each, n_0 of them, ~1-2% of the
prove). Transform c_j once (r NTTs), per u r forward + 1 inverse
transform; exact by the small-operand bound (128 * 2 * 64 << p/2).
Oracle = current loop; battery leg; ACCEPT/RECORD as T2.

---

### T8 — verifier attribution toward the <= 2 s line  `OPEN`  WHO: MAC  KIND: RUN
`pass-profile` now prints `bg.verify-group` (per-group verifier total)
next to the shared `ep.*` counters; T1's table gives the split. Known
O(n_0)-class verifier terms to expect: `psi_level0_factored_multi`
(per VALUE ring: 16 kara ring-mults beta x conjq + 1 per digit-ring
chunk change — ~24M + ~10M ring-mults at 125M, i.e. ~70 s of the
199.6 s) and `transport_level` at level 1 (~12 kara ring-mults per
next-witness ring, ~750K rings per group, prover AND verifier).
RECORD: U_PERF_WAVE_REPORT.md Section 2 (verify table).

### T8b — the verifier's `psi_level0_factored_multi`, factored  `LANDED 2026-08-17 (Claude, WSL)`  WHO: ANY  KIND: CODE
DONE: the aligned branch now uses `PhiFactored` (T5's machinery: no
per-row K-mults / per-value-ring beta x conjQ ring-mults; one
c_k x PHI ring-mult per (value ring, k-run) remains) — battery leg
inside "O5 kernel-pass" (== compute_psi(phi0_reference_multi) at two
chunk splits, both moduli). Rig verify A/B rides T4.

### T3b — `transport_level_from_psi` in the NTT domain  `OPEN`  WHO: ANY  KIND: CODE
General x general operands: the 12-24 alphas are fixed rings
(transform once); per next-witness ring the operands are psi[src] /
a_mat[.][src] scaled by radix (mod q). Needs the limb-split contract
(aux `A1LimbCommitKernel` pattern, or `ring_mul_q_limbsplit`'s exact
recompose) — ~12 general ring-mults per ring today, ~750K rings per
group at level 1, prover AND verifier. Oracle: the current function.
ACCEPT/RECORD: as T2 (leg `O6 transport: N/N byte-identical`).

---

### T9 — memory diet for the 15 GB reference box  `OPEN`  WHO: ANY (c: Claude preferred)  KIND: CODE
The composed pass peaks at 41-47 GiB. Where it goes: the eval-proof
phase holds phi (n_0 x Poly: ~8 GiB for the act group) + w0 for both
groups (~12 GiB as Vec<Vec<i64>> with per-ring heap headers); but the
PASS PEAK (47 GiB, UAGB1_TABLE_DESCENT_REPORT 3.3) is the DESCENT
phase's tree batches ("nrw-88's 16-tree batch") — so a 15 GB-box diet
needs the descent trees streamed/batched smaller (BK/PA zone; T1's
`/usr/bin/time -l` RSS + the bk.descent-* rows tell how much) AS WELL
AS the two items below. Transcript-neutral steps on the eval-proof
side:
(c) FIRST (biggest, mechanical after T5/T8b): never materialize phi
at level 0. In `bg_prove_group`: (1) replace the level-1
`transport_level(ctx, &phi_cur, ...)` by
`transport_level_from_psi(ctx, &psi0, ...)` with `psi0 =
psi_level0_factored_multi(ctx, kf, group, &mk, &alphas0, &c0,
plan0.chunk)` — EXACTLY what `bg_verify_group` already does at level
1 (the `pass-agg seam` differential is the proof it is
compute_psi(phi_cur) bit for bit); (2) feed `bg_level_h` at level 0
from a phi PROVIDER instead of `phi_cur`: add
`level_h_pairs_with(ctx, phi_block: impl Fn(j, u0, &mut [Poly]),
w_slices, chunk)` whose a-side rings are produced per u-block by
`PhiFactored::value_ring` (per digit ring v = j*chunk + u: locate
(tensor, vr, limb) — consecutive u are consecutive v, so one PHI_vr
per value ring per pass, cached across the l0 limbs; radix scale per
limb) — the same arithmetic as the phi pass, no extra cost, and the
12 GiB `phi_cur` is never allocated (`phi_cur.truncate(n0)` and the
level-1 `phi_cur.resize` go away; deeper levels keep their small
materialized phi). Battery: the O5 leg's groups through the provider
vs `level_h_pairs` on the materialized phi.
(a) then w0 as a flat `Vec<i8>` (digits |w| <= 64) with slice views
at the consumers (matvec / level-h / fold / floor) — invasive, second.
(b) drop slices as level 0 consumes them.
Target: 12x512 P0 under 14 GiB so the TARGET_CONTRACT reference box
can run it. Measure with `/usr/bin/time -v` (Linux) — WSL-verifiable
once the export is copied over (T10).
RECORD: PROGRESS_UPERF.md log; TARGET_CONTRACT note if the reference
box becomes runnable.

---

### T10 — copy the m125 export to the WSL box  `MOSTLY DONE 2026-08-17`  WHO: Victor  KIND: RUN
DONE: Victor delivered the checkpoint tarball + the val shard; the WSL
box re-exported everything (`results/m125_ffn_export_wsl/`, 36/36
weights byte-identical, X differs by mlx CPU-vs-Metal rounding, 0
range violations) — the 3x16 / T=16 rigs run here with
`M125_EXPORT_DIR` set. REMAINING (small): the Mac's 12
`results/m125_ffn_export/layerXX_X.bin` files (~4.7 MB) copied to the
same path here would make freeze-check's UAGB1-BF rows and the frozen
statement digest reproducible on this box too.

---

### T11 — DESIGN items (not for a mechanical agent)  `OPEN`  WHO: Claude/Victor  KIND: DESIGN
(a) Prover-side rank-structured Phi_0: after T5 the prover's phi pass
is `PHI_vr = sum_{c,d1} sr_c[row][d1] * G_c[cb][d1]` per value ring
(16 x n_contrib scalars against 16 cached rings per (col kernel,
cb)); the next step is to feed `level_h_pairs` per u-block from that
form (never materialize the 11 GiB phi) — memory item T9(c).
(a') THE VERIFIER <= 2 s LINE (PoC-complete criterion 1(b)) — memo
2026-08-17 (orchestrator), supersedes the "chunk alignment" sketch:
after T8b the verifier's level-0 work is O(n_value_rings x 16 x
n_contrib) scalar MACs (~8.6G at 125M: ~14 s [WSL 1T], ~7 s [MAC 1T])
plus the transport levels (~25 s -> lane C), the descent verifies
(~36 s -> lane A) and small terms; the 1T verify after this round
lands in the ~40-60 s class, NOT <= 2 s. The chunk-alignment idea is
WITHDRAWN: at the 125M point every tensor (~41K digit rings) is
SMALLER than the level-0 chunk (~122K), so each chunk position u is
folded across ~r different tensors — the fold cannot be pushed
through the row structure and the "S[u'][j]" reuse has size ~1. A
verifier sublinear in n_value_rings needs a PROTOCOL change (a
polylog-verifier opening layer, or the prover supplying Psi_0 with
its own checkable proof) — design-trench work, not an R-row. The
practical route to a 2 s-class verify is `ZK_THREADS` on the
reference box (22 threads: ~2-4 s projected) — which requires
relaxing TARGET_CONTRACT's "single-threaded" wording to "single
machine, N threads stated" (Victor's ruling; an amendment, not code).
(b) R-row: the planner's r = 64 cap trades bytes for the Theta(n_0*r)
garbage; at r = 32 the h term halves and the artifact grows (derive
the bytes; the P0 artifact sits at 0.48x its gate). Transcript-
changing: Victor's ruling, freeze rows re-pinned if adopted.
(c) The GPU rung (CONTINUATION Phase 3): T2/T5's D-batched integer
GEMMs and the A1 commit kernel are the two kernels to port first.

## 4. Baselines and digests (append-only)

| date | box/label | shape | command | EVAL-PROOF DIGEST | prove s | verify s | commit |
|---|---|---|---|---|---|---|---|
| (T1 fills this) | | | | | | | |

## 4b. Round 2 + 3 (U-PERF2, 2026-08-17 — PROGRESS_UPERF2.md)

Round 2 LANDED and MERGED (a450b1f): **A** = descents (pads never
materialized, five-table round kernel, deterministic threads: prove
2.07x at 1T, 6.6-7.2x at 8T on the depth-20 bench, RSS -33%) and **C**
= eval-proof leftovers (fold NTT 4-6x, transport 3.4x, psi 3x, and the
FINDING that the Goldilocks NTT was branchy — branchless primitives
1.5/2.07 us per transform now carry every kernel). Real data reached
the WSL box (checkpoint + val shard -> `results/m125_ffn_export_wsl/`),
so the 3x16 full-statement rig runs here: **oracle 682.8 s -> 43.7 s
at 1T (15.6x) -> 16.6 s at 8T (41x), verify 1.9 s at 8T, every digest
identical** (U_PERF_WAVE_REPORT.md 4.2). Round 3 lanes **D** (claim
layer + commit phase threading) and **E** (descent callers on lane
A's drop-ins, descent VERIFY attribution, small-cols aux tensors) are
LANDED and MERGED too (4dcaea6): claim layer 3.5x/11x, chain GEMM
10x, tree callers streamed, small-cols aux K-rows 42x, parallel CRS
XOF; real-data batteries green. **3x16 now: 30.6 s at 1T (22x), 9.9 s
at 8T (69x); 12x64 at 8T: 46.0 s, 12.2 GiB RSS.** Round 4 lanes **F**
(memory diet — w0 compact, phi never materialized; the 12x512 rig on
the 15 GB box) and **G** (descents round 2: fold/extract fusion,
arena, thread scaling) are running.

**Grok (Mac): T1 is STILL the most valuable single task and now has
much more to show** — same recipe (2.3): `uperf-pc full-profile 12
512` fast at ZK_THREADS 1 and 8 (and 16), then ONE `ZK_UPERF_ORACLE=1`
run; digests must match; record walls + the phase table (the
`a.*`/`bk.*`/`bg.*`/`ep.*` rows are the next round's priority order).
Peak RSS should be lower than 47 GiB now (lane A: -11 GB of pad
layers) — record `/usr/bin/time -l`'s number.

## 5. Log (append-only, newest last)

- 2026-08-17: board opened by Claude after the status recalculation
  (PROGRESS_UPERF.md 2026-08-17 section). T2 started by Claude on the
  WSL box; T1 is the first MAC task.
- 2026-08-17 (later): T2, T3, T5, T8b, T6(kernels) LANDED on the WSL
  box with their battery legs (`uperf-pc diff-battery`: O1 4/4, O2
  35/35, O3 63/63, O5 12/12, E2E 2/2 — the last is the whole
  bg_prove_group + bg_verify_group on a synthetic mixed-tensor group
  with a forced 2-level schedule, proven under oracle AND fast routing
  in one process: proofs field-identical, both verify), freeze-check
  rows identical to the pre-change baseline, `agg-matmul battery` +
  `bh-verifier battery` green (also at ZK_THREADS=7). Kernel benches
  [WSL 1T]: level-h 21.8x, matvec 8.0x, kernel passes 42.6x / 51.5x,
  all byte-identical; 20T level-h 6.6x more. Commits 353a75d, 31e8840,
  213dfa2 (pushed to main + perf/zk-batch-optimizations).
  NEXT for the MAC (Grok): T1 — one binary, `ZK_UPERF_ORACLE=1` for the
  before, plain for the after; `full-profile 3 16` first (digests must
  match), then `12 512`.
