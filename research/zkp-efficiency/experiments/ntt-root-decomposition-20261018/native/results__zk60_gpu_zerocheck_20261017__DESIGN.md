# G1 design: the slot-18 (`SC_FZC`) masked zero-check on the device

Written 2026-10-17 by the GPU zero-check lane before any code. Sources are the
lane copy `ops/zkp-mvp/gpu-zerocheck/` (= frozen `trained-1b-review-r3`).
Line numbers refer to that copy.

## 1. What slot 18 computes today (CPU)

`private_block/argument.rs::run_slot` (lines 448-664), for `s = SC_FZC = 18`:

1. absorb `pb-slot`, draw the CFS multiplier `c`, compute and absorb the ONE
   published scalar (slot 18 is a HOST slot: `c * G - sum coef * c_h * G_h`),
2. `tables: build` — 21 tables of `2^n` `Fp2` each (`build_tables_at`),
3. `masked sumcheck (zk.rs, shared)` — `zk::masked_prove_rounds` over
   `ClosureRounds::new(tables, degree, poly).recover_one(None)`:
   `n` rounds; each round evaluates the closure `poly` at `degree + 1`
   points per pair `(i, i + half)`, sums, hands the UNMASKED round to the
   transcript, whose installed `CfsMasker` publishes `s_j + c g_j`, draws
   `r_j`, then folds every table `t[i] += r_j (t[i+half] - t[i])`,
4. `extension rounds` (one, on the host: `mask_eval` + `zk::extension`),
5. absorb the masked terminals `pb-term`, build the PCS claims and the M
   functionals.

Measured (TinyLlama T128, CPU, 16 threads; `N/r4/PHASES_T128.md`):
step 3 is 14.62 s of the 17.63 s slot-18 phase over 22 blocks (0.66-0.69 s
per block, cube `2^20`); step 2 is 0.97 s; step 4 1.90 s.

The table set (`argument.rs` 1602-1653), in order:

| index | table | source | field |
|---|---|---|---|
| 0 | `eq(tau, x)` | challenge point, `|tau| = n`, start 0 | Fp2 |
| 1 | `eq(p_g, x)` | gate-matmul claim point | Fp2 |
| 2 | `eq(p_u, x)` | up-matmul claim point | Fp2 |
| 3..13 | the 11 `Dom::F` A planes `G8, RGL, A16, U16, UL0, UL1, H16, HL0, HL1, RH0, RH1` | committed `A`, one slice, identity coordinates | base (c1 = 0) |
| 14..18 | the 5 `Dom::F` U8 LogUp helpers | committed `H` (re, im) slices | Fp2 |
| 19 | the activation-pair helper `H_FACT` | committed `H` | Fp2 |
| 20 | `supp(Dom::F)` (only where the profile pads `Dom::F`) | public 0/1 table | base |

so k = 21 at every trained profile (`f_pad > f`), k = 20 on a profile without
the pad rule. The polynomial (written in the kernel's variable names):

```
l2(o)  = A[o] + 256 A[o+1]
f0     = A16 U16 - K_h H16 - l2(RH0) + K_h/2         (K_h = 2^sh_h)
f1     = U16 + 32768 - l2(UL0)
f2     = H16 + 32768 - l2(HL0)
f_act  = HF (alpha - (G8 + 128 + beta A16 + g_act)) - 1
den_k  = alpha - (g_u8 + coef_k A[plane_k])           (9 U8 lookups:
          RGL, RGL*2^(8-sh_g), UL0, UL1, HL0, HL1, RH0, RH1, RH1*2^(16-sh_h))
helper = sum_{k<4} mu[4+k] (H_k den_2k den_2k+1 - den_2k - den_2k+1)
         + mu[8] (H_4 den_8 - 1)
pz     = mu_pad (1 - S) sum_j zeta^j A[j]   over the ZERO-rule F planes
g      = S (or 1 without the pad rule)
zc     = helper + mu[3] f_act + pz + g (mu[0] f0 + mu[1] f1 + mu[2] f2)
P      = E0 zc + g (nu0 E1 (K_g G8 + RGL - K_g/2) + nu1 E2 U16)
```

Declared round degree: 4 (toy), 5 at every padded profile (the indicator
adds one to the schedule's degree, `shape.rs` 1759-1771). The polynomial's
true degree is 4 (every monomial has at most four table factors).

## 2. What moves to the device, what stays

**Moves (device):** the body of step 3 — the per-round evaluation of `P` over
all pairs and its reduction to `degree + 1` field sums, and every fold — plus
step 2's table construction. Concretely a new evaluator `DevFzcRounds`
implements `zkp_core::sumcheck::SumcheckRounds` (`rounds.rs` 1-35, which was
written for exactly this: "a device evaluator can own a non-Sync handle"):

- `round(j)` launches the round kernel, the block partials are reduced on the
  device, `degree + 1` `Fp2` (96 B at degree 5) come back;
- `fold(r)` launches the fold kernel with the challenge the host drew;
- `finals()` copies the 21 surviving entries back (336 B).

**Stays on the host (unchanged code):** the transcript and every absorb, the
CFS masker (`zk::masked_prove_rounds` installs it exactly as today; the
evaluator only ever sees UNMASKED rounds and never the mask), every challenge,
all randomness (none is drawn inside the body), the published scalar, the
extension round, the terminals, the claims and the openings. The R1d claim
recovery of `ClosureRounds` (`s(1) = claim - s(0)` after round 0, claim =
`interpolate_eval(s, r)`) is replicated on the host inside `DevFzcRounds`
with the same code, so tampered witnesses produce the same bytes as the CPU
path, not merely honest ones.

**Tables built on the device:** with `HL_GPU=1` the `A` and `H` commitments
are device-resident (`DevCommit.data`, rows x n, the same row-major words as
the host copy, `cuda.rs` 1590 and 3795-3808). The 11 A tables and 6 H tables
are copied out of that buffer by a widening kernel (`(a, 0)`, `(re, im)`); no
upload. The three eq tables are built on the device from two half tables
(`eq_table_into`, existing). The public `supp` table is uploaded
(16 B x 2^n). If the commitments are host-only (CPU commit), the base-field
plane slices are uploaded instead (8 B per A entry, 16 B per H entry).

## 3. Switch and fail-closed behaviour

- `HL_GPU_ZEROCHECK=1` requests the device slot 18 (read fresh per slot; off
  by default; a test-only thread-local override like `timing::force`).
- It is honoured only when the GPU path is live (`gpu::enabled()`); otherwise,
  or on any structural mismatch (table count/order, lookup structure, degree
  outside {4, 5}) or device error, the site is reported through the existing
  `gpu::declined(site, err)`, which PANICS under `HL_GPU_REQUIRED=1`
  (fail closed) and otherwise falls back to the CPU body.
- The device attempt runs on `Transcript::clone_state(tr)`; only a complete
  success replaces the caller's transcript, so a mid-run device error can
  fall back without a half-absorbed transcript.
- `HL_GZC_CHECK=1` (shadow mode, diagnostic): run BOTH bodies from the same
  transcript state and assert masked rounds, challenges, finals and the
  transcript state are equal. Usable in any run, including the CLI stacks.

## 4. Device memory layout

One buffer `tabs` of `k x 2^n` `Fp2`, table-major (`tabs[(t * L + i) * 2 + c]`,
`L = 2^n` the ORIGINAL stride; after fold j the live prefix of each table is
`2^(n-j)`). Folds are in place (thread `i < half` reads `i` and `i + half`,
writes `i`). Plus a parameter block (< 100 u64), the block partials and the
`degree + 1` sums. VRAM: TinyLlama T128 (2^20): 336 MiB; 8B T32 (2^19):
168 MiB; 8B T128 (2^21): 672 MiB — each on top of the resident commitments
(8B T32 GPU-arm stack peak 2,369 MiB). Target peak <= 4 GiB.

## 5. Kernels and counted traffic per round

Notation: cube `N = 2^n`, k = 21, `L_j = 2^(n-j)` the table length entering
round j, `D` the declared degree, all `Fp2` = 16 B.

| step | kernel | logical bytes | arithmetic |
|---|---|---|---|
| build A (x11) | `(a, 0)` widen | read 8 N, write 16 N each | none |
| build H (x6) | `(re, im)` interleave | read 16 N, write 16 N each | none |
| build eq (x3) | half tables + join | write 16 N each | 1 Fp2 mul / entry |
| upload supp | H2D | 16 N over PCIe | none |
| round j | `k_fzc_round<D>` | read 16 k L_j | P at D points per pair (D+1 in round 0), L_j/2 pairs |
| reduce j | `k_reduce_f2` | ~ blocks x (D+1) x 16 | adds |
| D2H j | copy | 16 (D+1) | - |
| fold j | `k_sc_fold` | read 16 k L_j, write 8 k L_j | 1 Fp2 mul / entry |

Totals (`sum_j L_j ~ 2N`): build 504 N device bytes + 16 N PCIe; rounds
32 k N = 672 N; folds 48 k N = 1008 N; **v1 total ~ 2,184 B per cube entry**
(2.29 GB at 2^20). A fused fold+next-round kernel (v2: the thread that folds
entries i and i + L/4 evaluates the next round on them in registers) removes
the round's separate read: rounds+folds 40 k N = 840 N, **v2 total ~ 1,344 B
per entry**. Reading round 0 straight from the base-field data and keeping
the eq tables factored (v3, not planned in this round) would reach ~ 956 B.

The plan's own counted figure is `72 B x size(F) x 17 terms` = 1,224 B per
cube entry; the report gives both the plan's figure and these counted bytes.

**Compute is likely the binding resource on the 4070.** Direct evaluation of
`P` costs about 41 Fp2 x Fp2 and 14 Fp2 x Fp products per point; a Goldilocks
product is ~30 integer instructions (`__umul64hi` + reduction), an Fp2
product ~160. At 5 points per pair (D = 5 with recovery) that is ~40 k
integer instructions per pair, 2^20 pairs per sumcheck: ~4e10 instructions
against ~4.4e12 INT32 ops/s (36 SMs x 64 lanes x ~1.9 GHz) = ~9 ms, versus
~3 ms to stream the round's 0.7 GB. So the round kernel is expected to be
compute-bound and the folds bandwidth-bound; the report separates the two.
Levers if compute dominates (all exact, no byte moves): evaluate only the true
degree (4) and extrapolate `s(5)` on the host; step the linear forms (the
denominators, `l2`, the pad sum) instead of recomputing them per point;
Karatsuba Fp2 products; products of linear forms in point-value form.

## 6. Why the transcript is byte-identical

- **Same field values.** Goldilocks/Fp2 arithmetic on the device returns the
  canonical representative of the same field expression (kernels.cu header,
  probed against `field.rs` by `k_probe`). Field arithmetic is exact, so the
  ORDER of additions in the round sums (thread, block, grid reduction) and any
  algebraic rearrangement of `P` (distributivity, factoring the gate `g`,
  constants as base-field multipliers) give the identical element. What must
  be the same is the polynomial, the tables, the evaluation points
  `0..=D`, and the round/fold sequence — not the operation order.
- **Same polynomial.** The kernel is written from the closure; a host mirror
  `FzcDesc::eval` of the kernel's expression is compared against the
  closure itself (`def.poly`) at random points at every registered shape, and
  the device rounds are compared against `ClosureRounds` on the real closure.
- **Same recovery.** Rounds >= 1 publish `s(1) = claim - s(0)` exactly as
  `ClosureRounds::recover_one` does (claim None in round 0 for this HOST slot).
- **Same schedule.** One `sc-round` absorb and one challenge per round is the
  unchanged `prove_rounds` driver; finals are returned in table order.

## 7. Equality evidence planned (G2)

1. Descriptor == closure: `FzcDesc::eval(v) == def.poly(v)` at random `v`
   at every small shape, rung-TC, TinyLlama T32/T128 and 8B T32.
2. Slot-level R1d oracle: from one transcript state, `DevFzcRounds` vs
   `ClosureRounds(def.poly)` under `masked_prove_rounds`: masked rounds,
   challenges, finals and the transcript state equal, on dense random data
   and on the honest witness tables, at the same shapes; plus claim-Some/None
   and a tampered table (recovery path) at small n.
3. The existing in-run R1d oracle (`run_slot`, `cfg(test)`, fixtures with
   `k 2^n <= 2^18`) compares the device result to the legacy
   `zk::masked_prove` automatically when the switch is on.
4. Seeded proof-byte gate: `prove_core` twice with the same seeded `ZkRng`
   (test code only) and the same endpoints, device slot 18 off/on; the encoded
   receipts must be byte-identical (rung-TC, TinyLlama T32/T128, 8B T32).
5. Fail-closed: `HL_GPU_REQUIRED=1` + an injected decline panics; the CLI
   stack run shows `gpu: ON`, `HL_GPU_REQUIRED=1`, 0 declines and shadow-mode
   equality on every block.

## 8. Measurement plan (G3)

Per slot-18 sumcheck (synchronised per-kernel timers under `HL_GZC_PROFILE=1`,
otherwise one sync per round as the transcript needs): build, round kernels,
reduce + D2H + host, folds, finals; counted bytes per kernel class; achieved
bandwidth = counted bytes / kernel time, and the plan's figure
`72 B x 2^n x 17 / slot time` against 256 GB/s. Whole-block effect from the
22-block TinyLlama T128 stack phase table (`HL_PB_TIMING=1`) with the switch
off and on, GPU arm both times; the 8B T32 generic block (and T64/T128
generic 8B blocks if memory permits) through the slot-level harness.
Decision rule (plan): >= 25% of 256 GB/s proceed on the roofline track;
10-25% kernel-design work first; < 10% design rulings needed.

## 9. Addendum (14:30-14:45Z, before the first device run): compile cost and v3

- **Start-up compile.** Instantiating the eight round kernels (degree 4/5,
  gate on/off, v1 and v2) inside `kernels.cu` raised that module's NVRTC
  compile from 4.5 s to 26 s (PTX 2.5 MB -> 11.7 MB, measured with
  `nvrtc_check.py`, no device), paid by EVERY process at first GPU use. The
  round kernels therefore moved to `gpu/fzc_kernels.cu`, compiled lazily, ONE
  variant per NVRTC module, only when `HL_GPU_ZEROCHECK=1` asks for slot 18
  (`cuda.rs::fzc_module`; the field primitives are `kernels.cu`'s own section,
  prepended verbatim). Measured NVRTC per variant: v2 degree 5 + gate 6.8 s,
  lean 3.3 s, once per process; the main module is back to 4.5 s.
- **v3 "lean" evaluation (`HL_GZC_LEAN=1`).** Same tables, points and field
  elements; the arithmetic is reorganised by field identities only: staged
  term groups (each reads only its own tables, so a thread keeps 2 (D+1)
  accumulators instead of 42 value/difference pairs), linear factors formed
  once per pair with their difference and stepped by one addition per point
  (the nine U8 denominators, the l2 sums, the activation denominator, the pad
  sum, mu x table, nu x eq), products only per point (17 Fp2 products per
  point against 41 + 14 base products), Karatsuba Fp2 products (3 base
  products; 7x as additions). Estimated ~2x less integer work per pair. The
  fused form folds every table first (the `k_sc_fold` expression, in place)
  and then evaluates on the folded entries it has just written, with plain
  (coherent) loads.
