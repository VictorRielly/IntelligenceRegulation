# U-AG-B1 Aggregation Stack Report — Lane BD (wave 2: batched opening -> descent -> eval proof)

Status: LANE DELIVERABLE (2026-08-09, U-AG-B1 wave 2, worktree
wt-uagb1-bd). Ledger: PROGRESS_UAGB1.md "Agent BD status". Machine:
Victor's Mac (Apple silicon, 256 GB) — NOT the contract reference box;
every timing here is [MAC-BOX, non-reference], several [NOISY-SHARED]
(sibling lanes ran concurrently). Byte counts, battery verdicts, floor
schedules, and kel counts are machine-independent.

## 0. What this lane built, in one paragraph

The batched-opening / eval-proof layer that replaces the wave-1
statement's per-wave ct-round opening volume — the 99.8% of
117,396,459 counted bytes the whole aggregation trench exists to
remove. Per W-C commitment group (T_W = weights, T_act = activations +
accumulator): the statement's terminal MLE claims are nu_g-RLC'd
(CR-L4b), coordinate-decomposed into K_DEG = 16 base rows (the IA-O1-2
fallback), ring-embedded by conj-packing, and grounded by a
LaBRADOR-form recursion at kappa = 11 on the group's EXACT-DIGIT
witness — full-entropy K-draw constraint aggregation (R-EB3),
functional cross-garbage h, one outer commitment per level committed
BEFORE the fold challenge, quinary fold challenges resampled under
T_cap = 33 (R-EB1), adaptive digit bases capped at e <= 7 (R-EB4)
under the exact-digit gate 2^22.12 — down to a bare floor the verifier
checks directly. Stage 4 adds the priced Tier-Z masked floor (the
E2/E4 carve-out under Amendment A1): floor base refit to the F-Z1
corner (e_L = 4), prover-internal Gaussian mask, rejection-sampled
response at 4 B/coordinate, F-Z1 asserted at derive. I-6 holds
everywhere else: no other Gaussian-masked opening exists anywhere in
the stack.

## 1. Stage status

| stage | status |
|---|---|
| S1 batching (CR-L4-class, per group; E-O2-BB; E-O3-BB disposition) | **LANDED, battery green** |
| S2 descent / eval proof, BARE, at 512x768x2048 | **LANDED, battery green, measured** |
| S3 byte accounting vs Tier N vs wave-1 | **MEASURED** (Section 3) |
| S4 masked path (Tier-Z floor treatment) | **LANDED, battery green, priced** (Section 5) |
| S5 canonical wire format (M-05) | **NOT REACHED** — the counted-byte convention continues (64 B/K-el, 4 B/q31 coeff, poly 4 + 512 B, 4 B/coord masked response); stated here, not silently |

Files: `src/ring/eval_proof.rs` (new module: groups + E-O2-BB budget,
schedule planner, exact op-norm T_cap resampler, K-draws,
conj-packing, level transport, Tier-Z planner + corner arithmetic);
`[UAGB1-BD]` section of `src/bin/ring_matmul.rs` (claim layer,
prover/verifier, battery, bench, freeze rows, kel rig; subcommands
`agg-matmul [battery | tierz] ...`, `agg-kel`); ADDITIVE
`manifest.rs` section (AggGroupDescriptor — QuantMeta untouched);
`tests/test_uagb1_agg.py` (light suite face; the full battery is a
lane/merge gate).

## 2. The construction (what exactly is on the wire)

### 2.1 Commitment layer (replaces 2,944 BDLOP commitments + 24.5 MB tags)

Per group, the exact-digit witness (frozen class table UAGB1-1a: A
w8s e0=1 l0=8 sign-binary — the F-N2 base; B a8s e0=2 l0=5; C
acc24-768 e0=2 l0=13) is chunked; inner commitments t_j = A_0 s_j
(kappa = 11, seed-expanded per level) are WITNESS; the wire carries
ONE outer identity u_0 = B_0u(t-hat) per group (4 + 11*516 = 5,680 B)
inside h0_agg, plus one garbage commitment u_gh0 post-alpha. Every
challenge follows every commitment it acts on (the CRB/AZ-L4 edges;
battery-enforced both directions).

### 2.2 Claim layer (the CR-L4 batching)

rx/ry from h0_agg -> the wave-1 degree-2 matmul sumcheck over K
(reused as-is) -> terminals A~(rx,k*) [T_W], B~(k*,ry), C~(rx,ry)
[T_act] -> nu_g per group AFTER all terminals absorbed (CRB-N5;
AFS-L8 hyp. iii) -> batched K-value V_g -> 16 coordinate rows as
full-ring claims F_c(w) = B_c with ct(B_c) publicly pinned to V_g[c]
(conj-packing, SR 1.2 fact 3; 16 wire polys/group = 8,260 B) ->
full-entropy alpha RLC (R-EB3 K-draw class, error 8*q^-16 ~ 2^-493)
into ONE aggregated ring constraint per group. Multi-point/multi-claim
inputs land ADDITIVELY in the same row weights (mu-RLC), so a folded
instance family (lane BE's output at dw+index-vars) is a valid input:
**F-IF1 is not foreclosed** — the batching is claim-shape-agnostic,
one eval proof per group either way.

E-O2-BB: the group descriptor counts openings; a second batched
opening in a group is a BUILD ERROR (AggBuildError::
SecondOpeningInGroup) with a negative test. E-O3-BB: **N/A at this
statement, dispositioned not silent** — the single-matmul statement
carries no lookup/range descent pair, so D-R1 rho-sharing has no
object here; neither the battery leg nor the +143,104 B split price
applies at this scope; the obligation transfers to the pass statement
(BF integration / wave 3).

### 2.3 The recursion (per level i)

1. Fresh full-entropy alphas aggregate the accumulated constraint
   families (T1 target-carry, L1 claim transport, T4 fold
   consistency, T5 outer binding — 2 + kappa + kappa*bindings rows)
   into (Phi^(i), H^(i)).
2. Chunk split r_i (derive-time search minimizing the next witness
   under the frozen recurrence n_{i+1} = ceil(n_i/r_i)*l_z +
   r*kappa*l_t + pairs*l_h).
3. h cross-garbage h_jj = <Phi_j, s_j>, h_jk = <Phi_j,s_k> +
   <Phi_k,s_j> — r(r+1)/2 ring values, digit-decomposed into the next
   witness. (The g quadratic family is NOT carried — see 2.5.)
4. t_j = A_i s_j; ONE combined outer commitment u_i = B_i(t-hat ||
   h-hat) on the wire (5,680 B) BEFORE the fold challenge.
5. Quinary fold challenges c_j resampled-until-under the EXACT
   spectral norm T_cap = 33 (negacyclic op norm computed exactly at
   the 128 odd 256th roots of unity; deterministic FS counter; ~38%
   acceptance as the R-EB1 MC row predicts).
6. Fold z = sum c_j s_j; next witness [z-hat | t-hat | h-hat] at the
   adaptive base e_{i+1} = max e <= 7 with OP_CONC * 2^(e-1) *
   sqrt(nD) <= 2^22.12 (rows EB4-emax, H-gate-ed — asserted with row
   ids at derive).
7. Floor: the last level's witness sent bare (1 B/coord at e <= 7);
   the verifier evaluates ALL of the last level's families directly
   (T5 outer bindings on raw digits, T4 fold consistency, T1 target,
   L1 claim transport via Psi) plus per-coefficient alphabet
   membership.

### 2.4 Soundness structure (conformance, not new proof)

The per-level story is the design's exact-digit chain: fork on c +
dc-clearing (slack 58.8/level), MSIS binding at kappa 11 per level,
K-draw aggregation at per-slot q^-16, digit norms syntactic from
alphabets. Knowledge-error composition through the chain is the
standing O-7/SC-L4 obligation — this lane implements the protocol,
parameters, and FS edges; it proves no new lemmas.

### 2.5 Honest deviations from the modeled wire (named, priced)

- **g-family not carried.** The frozen byte model (R-EB2 row
  EB2-count) carries r(r+1) garbage rings/level (g quadratic + h
  functional). On the exact-digit branch nothing in this stack's
  check system consumes g (norms are syntactic; there are no
  quadratic constraints); carrying it as dead committed data to hit
  a modeled byte count would be padding. The implemented chain
  carries the h-family only (r(r+1)/2), with NO NS22-style shrink of
  h (R-EB2's actual prohibition — respected). Byte effect: my level
  messages are one 5,680 B commitment (vs the model's 5,680 + 1,036
  K-draw line — my aggregated targets are all public arithmetic, so
  the 2-poly claimed-value line has nothing to carry); my witness
  recurrence is correspondingly lighter on the h side and heavier
  nowhere.
- **16 claim-row polys (8,260 B/group) vs the model's "batched claim
  values (16 x 8 slots) 8,192 B"** — same class, ring-embedded form.
- **l_z sizing**: deterministic-concentration bound + 2 bits restart
  headroom, hard representability coverage. This is the main driver
  of the floors landing at 936/939 rings vs the design-doc spike's
  620-770 class (see 4.2) — a conservative, recorded choice, not an
  error; the F-Z1 corner absorbs it.

## 3. S3 — the byte headline (counted-not-serialized)

Full 512x768x2048 single-layer statement, one honest instance, bare
(Tier N mode), measured 2026-08-09:

| component | bytes |
|---|---:|
| statement (serialized, real) | 478 |
| matmul sumcheck (v + rounds + finals) | 2,112 |
| [weight] outer identities u_0 + u_gh0 | 11,360 |
| [weight] claim rows (16 polys) | 8,260 |
| [weight] level messages (5 at 5,680 B; 6 levels, level 0's pair above) | 28,400 |
| [weight] bare floor (939 rings, e = 7) | 120,196 |
| [act] outer identities | 11,360 |
| [act] claim rows | 8,260 |
| [act] level messages (6 at 5,680 B; 7 levels) | 34,080 |
| [act] bare floor (936 rings, e = 7) | 119,812 |
| **TOTAL** | **344,318** |

**vs Tier N 262,144 B/layer (P0): 1.313x — OVER the gate. Tier N is
NOT met by the single-layer bare stack as built, and is not claimed.**
The result is reported as a result: the DA model predicted the
FFN-shape sound frontier at 1.04-1.10x over with the descent-pair
line excluded here and different floors; my 1.31x is the same class
with the floor line (69.7% of the artifact) as the dominant term and
its named levers below.

**vs wave-1's 117,396,459 B: 341.0x smaller.** The opening layer
(80.3 MB of z + 12.4 MB of w1 + 24.5 MB of tags) is REPLACED by
2 x 5.7-11.4 KB of outer identities + 62.5 KB of level messages +
240 KB of floor. No component of the old opening volume survives.

Levers to the gate (owners named, none claimed): (a) the floor is
240,008 B — schedule tuning (l_z headroom 2 -> 1 bit, r-search
widening, stop-rule byte-optimality against the TOTAL rather than
per-group) is BD-side and plausibly worth 40-70 KB; (b) the
per-layer gate is P0-single-layer — the IXF pass (lane BE) amortizes
one eval proof per group across 12 layers, which is where the
0.3-0.5 MiB/pass class of the U-AG4 tables lives; (c) the Greyhound
row-column claim kernel removes no bytes (verifier time only).

Timings [MAC-BOX, NOISY-SHARED — sibling background runs during
measurement]: commit 8.3 s, prove 55.9 s, verify 17.4 s, peak RSS
1.36 GiB (/usr/bin/time -l). Wave-1 statement at the same shape:
commit 0.31 s / prove 45.2 s / verify 4.2 s / 1.25 GiB. The prove
delta is the claim-kernel + h-garbage + transport work; the VERIFY
delta is the recorded wall (Section 6 item 1).

## 4. The floor schedule and F-Z1 (posted to the ledger 2026-08-09)

### 4.1 The schedule (derived by the public planner, frozen BD-3)

| group | n_0 (digit rings) | levels | floor | floor coords | floor e |
|---|---:|---:|---:|---:|---:|
| weight (T_W) | 24,576 | 6 | 939 rings | 120,192 | 7 |
| act (T_act) | 167,936 | 7 | 936 rings | 119,808 | 7 |

Level-0 gamma headrooms vs the exact-digit gate (freeze rows BD-2):
weight 2^15.17 (+6.95 b), act 2^17.56 (+4.57 b) — the single-layer
statement sits far inside the gate (the pass-scale rows are the thin
ones).

F-Z1 recompute (BC's recipe): weight b = 2^27.48, act b = 2^27.47 vs
28.00 — **the masking corner SURVIVES with ~0.53 b at both floors**;
the limb-growth branch stays dead; both floors are far under the
1,940-ring survival threshold.

### 4.2 Finding: floors ~17% above BC's expected band

BC's F-Z1 row called 600-800 rings the expected 125M landing zone and
said a schedule outside it would itself be a finding. These floors
land at 936-939. Driver (verified in the planner arithmetic): the
deep levels' fold bound grows as 4^e, pushing l_z to 3 at the last
levels under my conservative sizing (concentration + 2 bits, hard
coverage), which stalls the byte-optimal stop one level earlier than
the design-doc spike's schedules. The corner margin absorbs it; the
Tier-Z corner is the binding consumer and it survives.

## 5. S4 — the Tier-Z masked floor (landed, priced)

Mechanism (the ONLY Gaussian-masked object in the aggregate layer —
the A1/E4 carve-out; I-6 stands everywhere else): the Tier-Z
schedule refits the last level at the corner base e_L = 4 and asserts
F-Z1 at derive (b < 28.00, growth branch dead); after all level
challenges (AZB-6), the prover samples a prover-internal Gaussian
mask y (never committed — FP-L2 row A8: no hash edge exists or is
needed), sends the mask images of every floor family, receives one
T_cap-capped floor challenge derived from (pre-mask state, images),
and ships the rejection-sampled response z' = y + c_fl (x) w at
4 B/coordinate; restart counts are logged (F-Z3 abort discipline).
The verifier gates ||z'||_inf at the corner line and checks every
family as L(z') = V + c_fl (x) target. The exact FS-with-aborts
constant and the extraction at the masked bound are obligations
F-Z2 (cited, not discharged).

Measured, 256x768x2048 (the smallest battery-affordable shape whose
corner survives): floors 1,344/1,356 rings at e = 4, corner 2^27.74,
masked responses 688,132 + 694,276 B, mask images 12,388 B/group,
restarts 0, total 1,511,494 B, accept true, prove 37.0 s / verify
12.1 s [MAC-BOX].

Measured, 512x768x2048 (the 125M layer shape): floors 1,368
(weight) / 1,364 (act) rings at e = 4, corner b = 2^27.75 vs 28.00
(SURVIVES, 0.25 b — thinner than the bare floors' 0.53 b because the
e = 4 refit grows the floor; still one-sidedly safe), masked
responses 700,420 + 698,372 B (4 B/coord exactly as priced), mask
images 12,388 B/group, restarts 0, **TOTAL 1,527,878 B = 1.46 MiB**,
accept true, commit 8.3 s / prove 56.0 s / verify 17.3 s [MAC-BOX].
The single-LAYER Tier-Z number is not a contract row (the frozen A1
Tier-Z budget is the 7B PASS scope; the 125M-pass number composes at
wave 3 after BE's fold amortizes one masked floor per group across
12 layers) — reported as the honest price of the mechanism at this
statement. Masking surcharge at this statement: 1,527,878 - 344,318
= +1,183,560 B = 2 x (~592 KB), the 4-B/coord-minus-1-B/coord
arithmetic at the e4-refit floors plus images — the FP 3.1 surcharge
STRUCTURE reproduced at single-layer floors (their +272-282 KB class
is at the smaller 710-734-ring pass floors).

**Live F-Z1 finding (battery-demonstrated):** at the battery shape
(act n_0 = 11,008) the Tier-Z floors land at 2,428 rings = 310,784
coords, b = 2^28.16 > 28.00 — the corner is genuinely CLOSED there
and the derive gate REFUSES the schedule (observed as a panic-gate,
then pinned as arithmetic in the battery). The corner needs floors
under 1,940 rings, which this stack reaches only for witnesses
roughly >= 2^16.5 digit rings. Consequence for deployments: Tier-Z
at SMALL statements is not a given; the 125M and pass scales are
safely inside.

## 6. Walls and findings

1. **The verifier-scaling wall (recorded, measured).** The
   transported constraint chain materializes the aggregated level-0
   claim functional at O(N_limb) ring-mults on BOTH sides; verify =
   17.4 s at the full shape [MAC-BOX, NOISY-SHARED] vs the R2 2 s
   line and the DA model's 0.14-0.52 s. This is an implementation
   point, not an architecture change: the claim kernel has product
   structure (eq tensors), and the Greyhound row-column split
   (PARAMS 2.2/5.3) keeps the verifier at sqrt-N by never
   materializing the level-0 functional. Bytes, soundness structure,
   and the wire are unaffected. The fix is the recorded 7B-scale
   work item.
2. **kel(dw,9) is engine arithmetic, not a fit** (F-O2, standalone
   route DISCHARGED at count grade): REAL masked descent pairs at
   dw = 10/12/14/17/19/21/24/25 count EXACTLY equal to
   masked_transcript_totals(dw,0,1) + masked_transcript_totals(9,0,1)
   and to the recorded quadratic 2dw^2 + 11dw + 235 at every point —
   including **kel(24,9) = 1,651 re-measured (33.7 s)** and
   **kel(25,9) = 1,760 MEASURED (67.5 s), the 125M pass point**. The
   [MODEL] flag on the fit reduces to "the transcript shape at
   (n_extra = 0, n_inst = 1)"; kel(29,9) = 2,236 (the 7B pass point)
   is engine-structural, still unmeasured as a real proof — the
   7B-freeze condition F-O2 keeps that residue.
3. **The exact-digit encoding gate narrows the stale-order attack
   surface.** The wave-1 StaleOrder forgery solves 16 mod-q C
   entries; under the aggregation stack those values cannot even be
   ENCODED (the accumulator class range 2^23.6 rejects mod-q-scale
   entries at the digit layer). A stale-order forger must instead
   solve a small-norm kernel problem (lattice-decoding class) to
   place an in-class defect. Recorded as a finding with the battery
   leg; the h0_agg ordering edge remains load-bearing and
   battery-covered via the two implemented F5 pairs.
4. **The F5 pairs at the aggregate layer are real and sharp.**
   (a) alphas-before-rows: a compensated false claim-row pair (sum
   alpha_c delta_c = 0, ct-free deltas) ACCEPTS under the weakened
   order — the CRB-N4/E4-N1-class binding collapse one level up —
   and the shipped order rejects the same crafting at the floor
   target. (b) challenge-before-commitment at level 1: two h values
   compensated against a known fold challenge ACCEPT weak / REJECT
   shipped — the E-6/AZB-6 leg at engine scale.
5. **The sharp OOA leg**: a recomposition-preserving out-of-alphabet
   floor pair passes EVERY transported linear family and is caught
   ONLY by the alphabet gate — the digit-alphabet check is
   load-bearing, demonstrated.
6. **Floors 936/939 vs the 600-800 band** (Section 4.2) — planner
   conservatism, named driver, corner unaffected.
7. **Tier-Z corner closes at small statements** (Section 5) — the
   derive gate enforces it.

## 7. AZB engine legs (E-blocks) — wired at this lane's stages

| leg | status here |
|---|---|
| E-6 (AZB-6, fold-ordering pair at the eval-proof levels) | **WIRED at engine scale** — the level-1 c-before-u F5 pair, both directions (battery); per-level structure identical, one representative level exercised |
| E-7(i) (AZB-7 floor exhibit) | **WIRED in substance** — the verifier's floor checks ARE the byte-exact recompute of every floor family from (wire, challenges); the honest-ACCEPT legs certify prover/verifier agreement end to end |
| E-1/E-2/E-3/E-4/E-5, E-7(ii/iii), E-8, E-9, E-10, E-11 | **NOT claimed** — they bind T_blind/blinding machinery, the pass manifest/group map, per-pass freshness, and the simulator harness, none of which exist at this single-layer bare/Tier-Z statement; they unlock at the pass statement (BE/BF merge + wave 3) |
| AZB-11 (weight-independence canary) | NOT reachable honestly at this statement: the activation-group CLAIMS depend on the weight tensor through the shared matmul terminals (b* and v are functions of A via the sumcheck), so "activation transcript from (T_act, challenges) alone" is not a property of the single-matmul statement; the canary's semantics attach to the P2 pass group map (E-11 as spec'd). Recorded, not fudged. |

The battery's own hash-edge F5 pairs (Section 6 item 4) are lane
batteries in the AZB-6/CRB class, claimed as E-6 only.

## 8. Freeze rows and discipline

- `freeze_check_uagb1_bd()` (in `freeze-check`): BD-0a..f (kappa 11
  = KAP-11, T_cap 33 = EB1-tcap, e-cap 7 = EB4-emax, K-draw 496 =
  EB3-kdraw, level wire 5,680 B, gamma_max 2^22.12 = H-gate-ed);
  BD-1a..c (125M group layouts 24,576 / 167,936 digit rings, acc
  l0 = 13); BD-2a/b (level-0 gammas + headrooms); BD-3 (schedules
  re-derive: 6 levels -> 939 / 7 levels -> 936 at e = 7). Every
  derive-time assert in the module cites its frozen row id; nothing
  is re-derived ad hoc.
- Full freeze-check green at every stage commit; **every
  pre-existing digest unmoved** (LKP-*, UAGB1-1*/2*, aggregation
  script rows).
- Suite: `tests/test_uagb1_agg.py` added (2 light tests, ~1 s + a
  shared build); the 23-leg battery (~224 s) is the lane/merge gate
  run via `agg-matmul battery`.

## 9. Exports

- To lane BE / the orchestrator: the batching consumes claim LISTS
  per (tensor, point, value) with additive multi-claim weights — a
  folded instance family at dw+index-vars is a valid input (F-IF1
  conformance, Section 2.2); where BD's group descriptors and BE's
  fold instances meet, F-IF1 rules and the orchestrator reconciles.
- To BC: the floor schedule + F-Z1 recompute (ledger, Section 4);
  kel points incl. the MEASURED kel(25,9) = 1,760 (Section 6 item
  2) — F-O2's 125M face is done, the 7B face (kel 29) remains
  structural.
- To FINAL: the Tier N verdict (1.313x single-layer bare, with
  levers and owners), the verifier-wall row, the Tier-Z corner
  small-statement finding, E-O3-BB's transfer to the pass statement,
  and the S5 wire-format residue (counted convention still in
  force).

## 10. Reproduction

```
zkmatrix-rs$ cargo build --release
zkmatrix-rs$ ./target/release/ring_matmul agg-matmul battery      # 23 legs, ~4 min
zkmatrix-rs$ ./target/release/ring_matmul agg-matmul 512 768 2048 # the S3 headline
zkmatrix-rs$ ./target/release/ring_matmul agg-matmul tierz 512 768 2048
zkmatrix-rs$ ./target/release/ring_matmul agg-kel 10 12 14 17 19 21 [24 25]
zkmatrix-rs$ ./target/release/ring_matmul freeze-check
repo$ python3 -m unittest tests.test_uagb1_agg
```
