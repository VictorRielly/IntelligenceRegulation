# U-AG-B1 Verifier Performance Report — Lane BH (wave 3: the row-column split + the gkr_masked padding seam)

Status: LANE DELIVERABLE, COMPLETE (2026-08-10, U-AG-B1 wave 3,
worktree wt-uagb1-bh). Ledger: PROGRESS_UAGB1.md "Agent BH status". Machine:
Victor's Mac (Apple silicon) — NOT the contract reference box; every
timing here is [MAC-BOX, non-reference], [NOISY-SHARED] where marked
(sibling lanes BG/BI and this lane's own battery jobs overlapped).
Byte counts and battery verdicts are machine-independent. Raw
measurement logs: bh_baseline_full / bh_after_full / bh_quiesced /
bh_gkr20 / bh_d3_batteries / bh_aggbat_after (.log, session
scratchpad; regenerate via Section 5).

**The 2 s contract line binds the AGGREGATE verifier on the REFERENCE
box (TARGET_CONTRACT R2). This lane reports complexity-fix ratios and
absolute [MAC-BOX] numbers — it does NOT claim the contract line.**

## 0. What this lane changed, in one paragraph

The eval-proof VERIFIER no longer materializes the aggregated level-0
claim functional. Wave 2's verifier built an N-value K-mult weight
table plus Phi_0 (one ring element per digit ring, n_0 = 192,512 of
them at the 125M layer shape, 16 ring-mults each) only to fold it
once into Psi_0 — the single Phi_0-derived object the transported
constraint chain consumes (BD's recorded wall, UAGB1_AGG_STACK_REPORT
Section 6 item 1). The row-column split (the Greyhound structure,
AGGREGATION_PARAMS_DESIGN 2.2/5.3) computes Psi_0 directly from the
rank-1 kernel factors. Separately, the gkr_masked witness-tree
capacity constraint 2^(d-1)-4 (finding BF-F3) is lifted to n-8 by the
split fill, so 2^20-class pass tensors ride depth-21 trees instead of
dummy-padded depth-22 — measured ~2x tree work removed. Neither
change touches a wire byte, a transcript edge, a mask family, or a
frozen row: both are exact-value implementation restructures, and the
differential batteries assert exactly that.

## 1. Deliverable 1 — the claim-kernel row-column split

### 1.1 The seam (why this is the designed fix, not a redesign)

In the recursed verifier path (`agg_verify_group`), Phi_0 enters the
rest of the verification ONLY as
`Psi_0[u] = sum_k c_k * Phi_0[k*chunk_0 + u]` (`compute_psi`):

- levels >= 2: the level-1 transport's L1 rows consume Psi_0 and
  nothing else of Phi_0 (`transport_level` uses `phi` solely through
  its internal `compute_psi` — now factored out as the public
  `transport_level_from_psi`);
- one-level schedules: the floor L1 check and the Tier-Z L1 family
  need the same Psi_0.

PARAMS 5.3's verifier model prices exactly this shape: the dominant
designed term is the LEVEL-1 statement pass (kappa*(z+t+w) MACs),
never an n_0-sized object. The wave-2 implementation materialized
Phi_0 anyway; that is what 17 s bought.

### 1.2 The algebra (exact, mod-q)

Per tensor, the batched claim weight of value f is
`row_kernel[f/cols] *_K col_kernel[f%cols]` (rank-1), and the kw row
of digit ring v scales it by the limb radix. Two exact facts:

1. K-multiplication is F_q-bilinear over the coordinate basis
   {Y^d}: `(s *_K x)[c] = sum_d x[d] * (s *_K Y^d)[c]`;
2. `conj_poly` is Z_q-linear over coefficients.

So whenever a tensor's `cols % 128 == 0` (every 125M-shape tensor;
A/B/C at 768/2048/2048 columns), each value ring lies inside one
matrix row (f = row*cols + cb*128 + c1) and

    Phi_0[v] = radix_limb * sum_d beta[row][d] * conjQ[cb][d]
    beta[row][d] = sum_c (row_ker[row] *_K Y^d)[c] * alpha_c
    conjQ[cb][d] = conj_poly(c1 -> col_ker[cb*128 + c1][d])

`psi_level0_factored` (src/ring/eval_proof.rs) assembles Psi_0 from
this at ~(rows x 16) scalar-scaled alpha sums + (n_value_rings x 16)
ring-mults + n_0 radix-scale-adds, instead of (N_values K-mults +
n_0 x 16 ring-mults + n_0 fold ring-mults). At the 125M layer act
group that is 327,680 ring-mults replacing ~2.6M K-mults + 2.9M
ring-mults. Tensors with misaligned cols (battery-small shapes) take
a per-ring generic branch computing the identical values. Every step
is a regrouping of exact mod-q sums, so Psi_0 is coefficient-for-
coefficient EQUAL to the reference — not approximately, and the
transcript (absorb/draw sequence) does not depend on how Psi_0 is
computed. Bit-identical verdicts follow by construction; the battery
asserts them anyway.

### 1.3 What changed where

- `src/ring/eval_proof.rs` (BH-owned this wave): `+psi_level0_factored`,
  `+transport_level_from_psi` (with `transport_level` now delegating
  — its public signature and behavior unchanged), `+phi0_reference`
  (the per-ring differential oracle), module-note update. The
  pre-existing public surface is source-compatible: nothing removed,
  no signature changed (lane BG consumes this API).
- `src/bin/ring_matmul.rs` [UAGB1-BD] section, minimal MARKED
  [UAGB1-BH] edits: `agg_verify_group` recursed path computes `psi0`
  factored (after c_0 is drawn; transcript order untouched), feeds
  `transport_level_from_psi` at level 1, uses `psi_floor` (= psi0 at
  L = 1) for the bare-floor and Tier-Z L1; the vw table now exists
  only in the degenerate branch; `agg_floor_family_values` takes psi
  directly; the Tier-Z PROVER computes its (challenge-fixed) psi
  once instead of once per rejection-sampling attempt (values
  identical). One stale bench print corrected. The prover's protocol
  path is otherwise UNTOUCHED — it still materializes Phi_0 (its
  h-garbage consumes phi chunk slices).
- `[UAGB1-BH]` own section + `bh-verifier` dispatch arm: the
  differential/BF-F3 battery, the kernel-phase bench, the gkr
  measurement.

### 1.4 Differential-battery evidence (bit-identical behavior)

`bh-verifier battery` — 21/21 ok (15.2 s):

- factored Psi_0 == wave-2 reference (the VERBATIM removed pipeline:
  vw table -> per-ring bpolys -> Phi_0 -> compute_psi, kept as the
  oracle `bh_psi_reference`) at 128x768x256 both groups forced-2-level
  AND forced-1-level (n_0 6,144/11,008; multi-tensor act with mixed
  l_0 5/13), and at 64x96x128 where the A tensor's cols = 96 exercises
  the MISALIGNED generic branch; the library per-ring oracle
  (`phi0_reference`) ties to the bin pipeline on both groups.
- end-to-end: honest ACCEPT at 128x768x256 (2 levels) and the sharp
  OOA-floor leg still caught by the alphabet gate ONLY (first_fail
  string identical).
- full-shape equality: `bh-verifier kernel 512 768 2048` asserts
  factored == reference at the REAL 125M-layer group shapes (Section
  1.5 table) — the assertion is part of the bench, not sampled.

BD's own `agg-matmul battery` re-run at this HEAD: **22 ok legs,
passed, 194.1 s** — every honest/tamper/F5/Tier-Z leg through the
new verifier with its expected verdict and first-fail string asserted
by the battery itself (the battery is unmodified BD code). The
full-shape bare artifact is byte-identical: **344,318 B counted**
(deterministic; the wire is untouched).

### 1.5 Measured (before/after)

[MAC-BOX, non-reference. BEFORE = commit a714935 (the wave-2 merged
code) measured QUIET on this box 2026-08-10 (bh_baseline_full.log);
AFTER = this lane's HEAD, first run [NOISY-SHARED] (overlapped this
lane's own battery jobs), then re-measured QUIESCED (nothing else
running). The noise turned out negligible — the two AFTER columns
agree to 0.1 s.]

| measurement | BEFORE (quiet) | AFTER [NOISY-SHARED] | AFTER (quiesced) | ratio |
|---|---:|---:|---:|---:|
| 512x768x2048 bare: VERIFY | 17.16 s | 5.31 s | **5.31 s** | **3.23x** |
| 512x768x2048 bare: prove | 55.61 s | 56.67 s | 56.85 s | ~1x (untouched) |
| 512x768x2048 bare: commit | 8.28 s | 8.28 s | 8.27 s | 1x |
| 512x768x2048 bare: counted bytes | 344,318 B | 344,318 B | 344,318 B | 1.000x (wire unchanged) |
| 512x768x2048 Tier-Z: VERIFY | 17.46 s | 5.38 s | **5.38 s** | **3.25x** |
| 512x768x2048 Tier-Z: prove | 56.35 s | 57.30 s | 57.32 s | ~1x |
| 512x768x2048 Tier-Z: counted bytes | 1,527,878 B | 1,527,878 B | 1,527,878 B | 1.000x |
| Tier-Z sampler restarts | 0 | 0 | 0 | — |

Claim-kernel PHASE in isolation (`bh-verifier kernel 512 768 2048`,
quiesced; the reference leg is the verbatim removed pipeline, and the
run ASSERTS factored == reference exactly):

| group | n_0 | chunk / r | wave-2 reference | row-column | ratio |
|---|---:|---:|---:|---:|---:|
| weight | 24,576 | 1,366 / 18 | 1.809 s | 0.231 s | **7.8x** |
| act | 167,936 | 4,539 / 37 | 12.149 s | 1.387 s | **8.8x** |
| both | 192,512 | — | 13.96 s | 1.62 s | **8.6x** |

Cross-check: baseline verify 17.16 s minus the removed 12.34 s of
kernel-phase delta predicts 4.8 s; measured 5.31 s (the factored
kernel runs inside the full verifier with its allocation pattern) —
consistent. The kernel phase was 81% of the wave-2 verify; it is now
~30% of a 3.2x-smaller number.

Residual (the honest decomposition of the remaining 5.31 s): the
level-0 CRS seed-expansions alone are 0.25 s (weight) + 0.78 s (act)
= 1.03 s, measured in-run at the real schedule dims (A 11x1366/
11x4539, Bu 11x990/11x2035, Bh 11x855/11x3515); the rest is the
deeper levels' CRS, the DESIGNED level-1 transport pass
(kappa*(z+t+h) ring-mults — PARAMS 5.3's dominant modeled term), the
floor family checks, and the statement rebuild. None of it is
O(N_limb); the O(N_limb) claim-kernel wall recorded by BD is CLOSED
on the verifier side. The prover (56-57 s) still carries its
O(N_limb) passes by design (its h-garbage consumes phi chunk
slices); the wave-2 module note's "on BOTH sides" now reads
prover-only.

## 2. Deliverable 2 — the gkr_masked capacity seam (BF-F3)

### 2.1 The lift

`blinded_witness_tree` required the honest block to end below the
first blinder position: capacity 2^(d-1)-4, so 2^20-element tensors
rode depth-22 trees with a fully-dummy right half (BF-F3: ~2x tree
work). The wave-3 fill mirrors the FROZEN table-row discipline
(`table_row_positions`, which splits table rows across the halves for
exactly this reason): honest leaf j sits at j below n/2-4, and at
n/2 + (j - (n/2-4)) beyond — capacity n-8, public map
`witness_leaf_positions`. Below the old cap the map is the IDENTITY
and the built leaves are bit-identical to the historical fill (the
old builder ASSERTED at the cap, so there was no behavior above it to
preserve). `blinder_positions`, the mask families, the transcript-
shape functions, and `masked_gkr_prove`/`masked_gkr_verify` are
UNTOUCHED (they are layout-agnostic — they consume trees).

### 2.2 Battery evidence

In `bh-verifier battery` (Section 1.4's run):

- layout identity below the cap at depths 6/8/12; leaf VECTORS equal
  the historical fill (build_tree is deterministic in its leaves, so
  tree identity follows); roots equal.
- beyond the cap (depth 6, w = 40 > 28): honest END-TO-END masked
  descent — verify(pin=true) accepts, derived roots match the tree,
  and the aggregate leaf P/Q pins recomputed against the SPLIT layout
  match the claims (the house pin-modelling convention: p*/q* are the
  true leaf MLEs).
- TAMPER (right-block leaf changed): descent self-consistent, leaf Q
  pin REJECTS against the true committed column.
- WRONG MAP (pins computed with the contiguous assumption): REJECT —
  the position map is load-bearing, demonstrated.
- capacity gates: n-8 positions all distinct/in-range/off the blinder
  slots; blinder positions UNCHANGED ([28, 60, 30, 61] at n = 64 —
  the LKP-6 layout).

### 2.3 Measured (the pass shape)

`bh-verifier gkr 20` — one masked witness descent at 2^20 fused
elements, dt = 9 table side unchanged [MAC-BOX]:

| depth | tree build | prove | verify | witness transcript |
|---:|---:|---:|---:|---:|
| 22 (historical cap) | 1.57 s | 8.55 s | 0.003 s | 1,197 K-el = 76,608 B |
| 21 (split, n-8) | 0.75 s | 4.22 s | 0.003 s | 1,100 K-el = 70,400 B |

**Tree-work ratio 22 -> 21: tree 2.08x, prove 2.03x, tree+prove
2.03x — the BF-F3 ~2x is real and removed.** Pair transcript (with
the dt = 9 table side): 1,445 -> 1,348 K-el = 92,480 -> 86,272 B,
**-6,208 B per descent-pair instance** (a byte bonus BF-F3 did not
claim; kel-row freeze values pin the FUNCTION at given dw and do not
move).

### 2.4 The export (rig wiring is out of this lane's zone)

The m125 pass rig's depth derivation (`p3_dw`-class layouts and the
[UAGB1-BF] runner's descent shapes, plus their leaf-pin builders)
lives in other lanes' sections/files. Switching those rigs to
`witness_leaf_positions` + depth-21 trees for their 2^20-class
columns is mechanical (pin weights move from contiguous positions to
the public map — the wrong-map battery leg is the acceptance test)
and is EXPORTED to the orchestrator/next wave. Expected effect per
M125_PASS_REPORT: descents are 25.5% of prove time; roughly half of
that is witness-side tree work at dw = 22 -> a ~10-12% pass-prove
reduction class, plus 6,208 B x 8 pairs/layer counted-transcript
reduction. [MODEL until wired.]

## 3. Deliverable 3 — battery re-runs at this HEAD

Every battery below runs the changed engine (the eval-proof verifier
and gkr_masked sit under all of them) — that is the point. All runs
2026-08-10 in this worktree, [MAC-BOX]; verdicts machine-independent.

| battery | result |
|---|---|
| bh-verifier battery (NEW: differential + BF-F3) | **21/21 ok**, 15.2 s |
| agg-matmul battery (BD) | **all 22 source legs ok, passed**, 194.1 s (BD prose said "23/23"; the battery source carries exactly 22 `assert_true` legs — a prose-count nit, not a missing leg) |
| uagb1-digit-battery (BB D1) | **33 ok, passed**, 4.3 s |
| matmul-statement battery (BB D2) | **10 ok, passed**, 50.3 s |
| ixf-fold battery (BE) | **20 ok, passed**, 53.9 s |
| m125-pass v4-battery (BF) | **19 ok, passed** |
| m125-pass battery smoke (BF, real layer-0/1 exports) | **passed**, 73.7 s |
| freeze-check | **passed** (87 ok rows; every pre-existing digest unmoved) |
| python suite (repo root, quiesced) | **Ran 58 tests in 430.4 s — OK** (incl. the Rust self-test battery 246.0 s; zero ERROR/FAIL lines) |

## 4. Findings and exports

- **BH-F1 (the wall was the claim kernel, measured).** The full-shape
  verify drop (Section 1.5) confirms BD's attribution: the removed
  Phi_0/vw materialization was the dominant verifier term at
  512x768x2048. The residual profile is CRS seed-expansion + the
  designed level-1 pass + floor checks (Section 1.5 note) — none of
  it O(N_limb).
- **BH-F2 (Tier-Z prover restart loop).** The wave-2 Tier-Z prover
  recomputed the (challenge-fixed) floor Psi once per rejection-
  sampling attempt inside `agg_tier_z_mask_floor`; hoisted (values
  identical). At restarts = 0 this is one saved recompute; under
  aborts it was a per-attempt O(n_{L-1}) term.
- **BH-F3 (BF-F3 byte bonus).** The depth drop also shrinks the
  masked-descent transcript: -6,208 B per (dw 22 -> 21, dt 9) pair.
- **Export to BG/orchestrator:** `transport_level_from_psi` +
  `psi_level0_factored` are additive public API; `transport_level`
  unchanged — BG's composition consumes the same surface either way.
- **Export to the pass rig (BF-zone):** Section 2.4.

## 5. Reproduction

```
zkmatrix-rs$ cargo build --release
zkmatrix-rs$ ./target/release/ring_matmul bh-verifier battery
zkmatrix-rs$ ./target/release/ring_matmul bh-verifier kernel 512 768 2048
zkmatrix-rs$ ./target/release/ring_matmul bh-verifier gkr 20
zkmatrix-rs$ ./target/release/ring_matmul agg-matmul battery
zkmatrix-rs$ ./target/release/ring_matmul agg-matmul 512 768 2048
zkmatrix-rs$ ./target/release/ring_matmul agg-matmul tierz 512 768 2048
zkmatrix-rs$ ./target/release/ring_matmul freeze-check
repo$ python3 -m unittest discover -s tests
```
