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
| frugal-lm ckpt + `results/m125_ffn_export/*.bin` | YES | **NO** |
| composed pass 12x512 (RSS 41-47 GiB) | runs | **cannot run** |
| `freeze-check` | full, exit 0 required | first 98 rows green, then panics at the UAGB1-BF rows (missing export) — EXPECTED here |
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
zkmatrix-rs/target/release/ring_matmul uperf-pc pass-profile 3 16      # fast yardstick (~6-8 min): attribution + EVAL-PROOF DIGEST
zkmatrix-rs/target/release/ring_matmul uperf-pc pass-profile 12 512    # the real thing (~80 min prove + verify)
zkmatrix-rs/target/release/ring_matmul pass-agg prove 12 512 p0        # composed-scope prove+verify (BG rig)
zkmatrix-rs/target/release/ring_matmul table-descent prove 12 512 p0   # FULL-STATEMENT prove+verify (BK rig, the PoC number)
zkmatrix-rs/target/release/ring_matmul pass-agg battery                # 14 legs, ~70 min [MAC]
zkmatrix-rs/target/release/ring_matmul pass-agg seam                   # 12/12 psi-seam differential (~1 min)
zkmatrix-rs/target/release/ring_matmul agg-matmul battery              # 23 legs, ~4 min, synthetic (runs on WSL)
zkmatrix-rs/target/release/ring_matmul bh-verifier battery             # BH differential + BF-F3 legs (synthetic)
```

Wrap long runs in `/usr/bin/time -v` (Linux) or `/usr/bin/time -l`
(macOS) so wall + peak RSS land in the record.

### 2.3 The EVAL-PROOF DIGEST (the composed-pass differential gate)

`uperf-pc pass-profile <layers> <t>` prints
`[UPERF-PC] EVAL-PROOF DIGEST <hex>` = SHA-256 over both groups'
GroupEvalProof wire fields (b_rows, u0, ugh0, level_us, floor,
tcap_attempts) in order. It must be IDENTICAL at the same
(layers, t, mode) before and after any Phase-0 change. Baselines are
recorded in Section 4 as they are measured (T1). If a task lands
without a baseline digest for its shape, run T1 first.

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

### T1 — pass-profile BASELINE (attribution table + digest)  `OPEN`  WHO: MAC  KIND: RUN
WHY: nobody has run the composed-pass profile; every share above is
BG-F3 arithmetic. This gives the measured table AND the digest every
later task is checked against.
STEPS:
1. `git pull`; `cargo build --release` (in zkmatrix-rs/).
2. `/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc pass-profile 3 16 > results/uperf/pass_profile_3x16_<commit>.txt 2>&1`
3. `/usr/bin/time -l zkmatrix-rs/target/release/ring_matmul uperf-pc pass-profile 12 512 > results/uperf/pass_profile_12x512_<commit>.txt 2>&1`
   (about 80-90 min prove + verify; peak RSS ~41 GiB; run when nothing else heavy runs).
4. Copy the phase table (the `ep.*` / `bg.*` rows), `accept`, wall, and
   the `EVAL-PROOF DIGEST` line into U_PERF_WAVE_REPORT.md Section 2 (a
   table per shape) and the digest into Section 4 of THIS file.
ACCEPT: `accept = true` at both shapes; the 12x512 statement digest
equals the frozen `76dbf2040409333e` prefix printed by the rig.
RECORD: U_PERF_WAVE_REPORT.md Section 2; TASK_BOARD Section 4.
NOTE: `results/uperf/` is a new directory; add a `.gitignore` with
`*.txt` if the files are large, and paste the tables into the report.

---

### T2 — the h cross-garbage in the NTT domain (O2)  `IN PROGRESS (Claude, 2026-08-17)`  WHO: ANY  KIND: CODE
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

### T3 — matvecs in the NTT domain (O3)  `OPEN (Claude next; ANY may take if Claude is absent)`  WHO: ANY  KIND: CODE
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

### T4 — A/B after T2+T3 on the rig  `OPEN (after T2, T3)`  WHO: MAC  KIND: RUN
STEPS: build; `uperf-pc pass-profile 3 16` -> digest MUST equal the T1
baseline (else STOP, report, revert); `freeze-check` exit 0; `pass-agg
seam`; `agg-matmul battery`; then `uperf-pc pass-profile 12 512`
(digest == baseline; wall + phase table); then `table-descent prove 12
512 p0` for the full-statement wall. Suite before push.
RECORD: U_PERF_WAVE_REPORT.md Section 4 (before/after table with
labels), PROGRESS_UPERF.md log line, this row.

---

### T5 — the two claim-kernel passes as integer GEMMs  `OPEN`  WHO: ANY (Claude preferred)  KIND: CODE
WHY: `bg_kernel_pass` (bin ~29210) does 16 `ring_mul_split_kara_fast`
per digit ring, twice (rows pass, phi pass): ~365M ring-mults at 125M
(~30% of the composed prove).
WHAT (exact identities, both passes):
- rows pass: `b_rows[c] = sum_u bp_u[c] * w_u` with
  `bp_u[c] = radix_u * conj(row_c(kw_u))`, `row_c(kw_u)[c1] =
  kw_u[c1][c]`. Since conj is linear over monomials:
  `b_rows[c] = sum_{c1} conj(X^{c1}) * S[c1][c]`,
  `S[c1][c] = sum_u (radix_u * kw_u[c1][c]) * w_u` — 256 accumulator
  rings, each an exact i128 (fits: |term| < 2^31 * 2^6, n_0 < 2^24)
  scalar x small-ring MAC; reduce mod q once at the end; then 256
  monomial-conj rotations (`conj_poly` of `X^{c1} * S`).
- phi pass: `phi_u = radix_u * sum_{c1} conj(X^{c1}) * beta_u[c1]`,
  `beta_u[c1] = sum_c kw_u[c1][c] * alpha_c` — precompute the 256
  rings `R[c1][c] = conj(X^{c1}) * alpha_c` ONCE (mod q), then
  `phi_u = radix_u * sum_{c1,c} kw_u[c1][c] * R[c1][c]` — a 256-scalar
  x 256-ring dot with u128 lazy accumulation, one mod-q reduction per
  ring.
Both are `n_0 x 256 x 128` integer MACs. Reference oracle = the
current loop; battery leg on synthetic groups (use the `bh-verifier`
group builders) at two shapes; byte identity of `b_rows` and `phi`.
ACCEPT/RECORD: as T2 (leg `O5 kernel-pass: 2/2 byte-identical`).

---

### T6 — multithread the u-major loops (rayon, deterministic)  `OPEN (after T2/T3/T5)`  WHO: ANY  KIND: CODE
RECIPE: rayon is already a dependency. Parallelize ONLY loops whose
per-thread state is an exact-integer accumulator with FIXED window
boundaries (T2: split the D coefficient positions across threads —
each thread owns a t-range of accumulators, no sharing; T3/T5: split
the u range into fixed blocks with per-block partial sums, then reduce
the partials in index order). Because the accumulation is exact
integer arithmetic, the result is bit-identical for any thread count.
Env knob `ZK_THREADS` (default 1 — the ledger baseline stays 1T; the
A/B row states NT). Battery: run every leg with ZK_THREADS in {1,2,7};
digests identical.
ACCEPT: legs identical at 1/2/7 threads; pass-profile digest ==
baseline at ZK_THREADS=22 [MAC]; the 1T number unchanged.
RECORD: U_PERF_WAVE_REPORT.md Section 4 (a 1T vs NT row).

---

### T7 — `bg_fold` / `agg_fold` in the NTT domain (small)  `OPEN`  WHO: ANY  KIND: CODE
`z_u = sum_j c_j * w_{j,u}` (small x small, exact i64) — currently
`poly_mul_small` schoolbook (16K MACs each, n_0 of them, ~1-2% of the
prove). Transform c_j once (r NTTs), per u r forward + 1 inverse
transform; exact by the small-operand bound (128 * 2 * 64 << p/2).
Oracle = current loop; battery leg; ACCEPT/RECORD as T2.

---

### T8 — verifier attribution toward the <= 2 s line  `OPEN`  WHO: MAC  KIND: RUN
`pass-profile` counts prove AND verify calls together; add a
`[UPERF-PC] verify-only` printout (split the counters: reset after
prove) and record the verifier's ep.* table at 3x16 and 12x512. The
199.6 s composed verify has an O(n_0)-class term somewhere
(`psi_level0_factored_multi`?); the table says where. DESIGN follow-up
(Claude): make the verifier's level-0 work O(chunk_0 + floor), not
O(n_0).
RECORD: U_PERF_WAVE_REPORT.md Section 2 (verify table).

---

### T9 — memory diet for the 15 GB reference box  `OPEN`  WHO: ANY  KIND: CODE
The composed pass peaks at 41-47 GiB (phi materialized as n_0 x Poly =
11.4M x 1 KiB alone is 11 GiB; w0 as Vec<Vec<i64>> another 11 GiB with
per-ring heap headers). Steps that are transcript-neutral: (a) store
small witnesses as `Vec<i8>`/`Vec<i16>` flat arrays with a slice view
(digits are |w| <= 64); (b) drop `phi_cur` slices as level 0 consumes
them; (c) after T5, never materialize phi at all for level 0 (compute
phî on the fly per u-block from kw). Target: 12x512 P0 under 14 GiB so
the TARGET_CONTRACT reference box can run it. Measure with
`/usr/bin/time -v` (Linux) — this is a WSL-verifiable target once the
export is copied over (T10).
RECORD: PROGRESS_UPERF.md log; TARGET_CONTRACT note if the reference
box becomes runnable.

---

### T10 — copy the m125 export to the WSL box  `OPEN`  WHO: Victor  KIND: RUN
`results/m125_ffn_export/*.bin` (+ the calibration sidecar it reads)
from the Mac to the same path on the WSL box (rsync/scp; ~50 MB
class). Unblocks freeze-check's BF rows, the 3x16 yardstick, and T9
on the reference box.

---

### T11 — DESIGN items (not for a mechanical agent)  `OPEN`  WHO: Claude/Victor  KIND: DESIGN
(a) Prover-side rank-1 Phi_0: the verifier already never materializes
Phi_0 (`psi_level0_factored_multi`); after T5 the prover's phi pass is
a GEMM against the K-weight matrix; the next step is to feed
`level_h_pairs` from the factored kernels directly (never build phi).
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

## 5. Log (append-only, newest last)

- 2026-08-17: board opened by Claude after the status recalculation
  (PROGRESS_UPERF.md 2026-08-17 section). T2 started by Claude on the
  WSL box; T1 is the first MAC task.
