# U-AG-B1 T_blind Report — Lane BL (wave 4: masking the weight-touching round polynomials in the composed P2 path)

Status: LANE DELIVERABLE (2026-08-10/11, U-AG-B1 wave 4, worktree
wt-uagb1-bl, branch uagb1-bl, base f75aba3). Sections marked [PLAN]
are the deliverable-1 design transcription, retained verbatim;
Sections 5-7 carry the build + measurements. Machine: Victor's Mac
(Apple silicon) — NOT the contract reference box; every timing
[MAC-BOX, non-reference], [NOISY-SHARED] where sibling lanes
(BJ/BK/PV-S2) run concurrently. Byte counts, rank certificates,
battery verdicts and freeze rows are machine-independent.

## 0. What this lane closes, in one paragraph

BG's wave-3 composed P2 pass (UAGB1_PASS_AGG_REPORT.md) masks the
weight group's eval-proof FLOOR (Tier-Z, once per pass) but ships the
weight-touching ROUND POLYNOMIALS and weight-side TERMINALS in
cleartext — the honest gap BG labeled "T_blind absent = E-1..E-5,
~1,664 B [MODEL]" (FP 3.2's 4 x 416 B midpoint). This lane
transcribes the O-4 T_blind + masked-sumcheck design
(AGGREGATION_ZK_DESIGN Sections 2-3: AZ-L1a round masks, AZ-L2a
selector-extension terminal pads, AZ-L2b unit-weight claim segment)
onto the composed engine path, mode-gated so P0 (and the noblind-P2
battery config) stay byte-identical, and wires the AZB E-blocks the
stage unlocks (E-1..E-5, plus E-7(ii,iii)/E-8/E-9). I-6 stays hard:
no new Gaussian-masked opening anywhere — the blinding is committed
T_blind material + masked sumcheck only; the single Gaussian object
remains BG's priced Tier-Z floor response.

## 1. The leak inventory at the composed P2 path [PLAN]

Under P2 (private set = the 36 weight-class entries; activations
public by declaration), the composed artifact's weight-referencing
cleartext surface, beyond the already-masked Tier-Z floor:

| # | object | bytes/pass (12L) | leak form |
|---|---|---:|---|
| L1 | round polynomials of mm-gate/mm-up/mm-down | 3 x ~38-41 kel | each round sends d+1 evaluations of a polynomial whose coefficients are public-kernel contractions of the WEIGHT tables (tb) — challenge-keyed weight functionals, accumulating across proofs (the R1 principle) |
| L2 | weight-side terminals b* (final_evals[2]) | 3 x 64 B | raw MLE(W-fold)(k*, l*) — one exact weight functional per instance per proof (the AZB-1/E-1 object) |
| L3 | weight-group claim rows b_rows | 16 x 516 B | ct coordinates are public by design (= v_batch, the ct-row-gate); the 16 x 127 NON-ct coordinates are inner products of rotated claim kernels with the weight witness — the batch-value face (AZ-L2b's object at the engine's conj-packed realization) |

Not in scope: the act group (public in P2 — P1/P3 keep refusing,
with the refusal text updated to name the act-side mask as the ONLY
remaining absent piece); commitment hiding tails (u_0/u_i are
deterministic Ajtai images engine-wide — a pre-existing structural
gap of the eval-proof layer shared by every landed wave, adjacent to
but distinct from the round-polynomial scope; recorded as finding
BL-F1, not built here — eval_proof.rs is lane BJ's zone this stage).

## 2. The construction, transcribed to the composed path [PLAN]

### 2.1 T_blind commitment shape (the zero-extra-identity decision)

T_blind = CLASS_Q31C tensors (full centered mod-q residues, e0 = 2,
l0 = 16, mod-q-native recomposition) APPENDED TO THE WEIGHT GROUP's
registry before precommit:

| tensor | shape | values | digit rings | role |
|---|---|---:|---:|---|
| tbl-mask-{gate,up,down} | n_g_pad x 16 | n_g_pad x 16 | n_g_pad x 2 | round-mask coefficients as K-coordinate grids (n_g = 1 + sum d_t = 2*lk + 3*lambda + 4 incl. the extension round; padded to n_g_pad = next multiple of 8 for the no-tail discipline, pad rows carry zero kernel weight) |
| tbl-pad-{gate,up,down} | 1 x 128 | 128 | 16 | the b* terminal pad ring (AZ-L2a, ring-granular per AZ-R1) |
| tbl-claimseg | 16 x 128 | 2,048 | 256 | the unit-weight claim segment (AZ-L2b): value ring c enters b_rows[c] diagonally |

125M pass totals: 3 x 96 + 256 = 544 blind digit rings on 3,538,944
(+0.015%); battery shape (3 layers, T = 16): 496 on 884,736. The
weight group's ONE u_0 outer identity covers T_W ++ T_blind, and
h0_agg contains u_0 — the "T_blind digest inside h0 before any
challenge" edge (AZ-L4/FP-L2 A6/A7 class, E-3's object) is thereby
realized structurally at the u_0/descent face with ZERO extra
identity bytes. DEVIATION RECORDED: the design tables (FP 3.3 /
PARAMS 2.5) price T_blind as a THIRD outer identity (+5,680 B); the
composed engine path gets the same pre-challenge binding from the
group identity because the blind columns are witness columns of the
one batched opening (E-O2-BB: still exactly one opening per group).
Consequences: (i) the E-3 battery pair's shipped REJECT surfaces at
the commitment-binding/descent gate rather than as an h0 digest
mismatch — same edge, engine face; (ii) mask material rides the
Tier-Z-MASKED weight descent and NEVER lands in a bare floor (the
act floor stays blind-free — the AZB-11 invariant is untouched).

Freshness (E-5/A7): blind values are drawn per proof from a
session-fresh ProverRng; the derive path keeps a process registry of
SHA(witness digest || T_blind digest) and REFUSES a repeat loudly
(deployment-blocking, F-Z3 semantics). The registry is the engine
realization of "the statement hash records the T_blind segment id".

### 2.2 The masked instance (Surface 1 + Surface 2 per matmul)

Extended index space: one selector-extension bit as the TOP variable
(bound last; the engine binds low bits first): tables of size
2^(lk + lambda + 1), schedule [2; lk] ++ [3; lambda] ++ [2].

- ta_ext: A-table on the 0-block, ZERO on the 1-block (activations
  need no pad in P2) — so the extended cube sum equals the original
  claim v_c exactly (every 1-block product has a zero side; the
  selector arrangement of AZ-L2a step 2).
- tb_ext: B-table on the 0-block; on the 1-block, delta(k = 0) *
  beta_t replicated over l, with beta_t = sum_{j<128} beta_j *
  eq_ry[j] — committed pad content contracted with a public
  sub-kernel of the instance's own eq_ry.
- eq_exp_ext: the layer-eq table replicated across ext (round-poly
  degree 2 in the ext round).

Per-instance FS order (the E-4 edges): r_l, rx, ry drawn -> v_c
absorbed -> **G pin absorbed** (G = sum_cube g = 2^n c_0 + 2^(n-1)
sum_t p_t(1)) -> **rho drawn** (the mask activation challenge —
after G, edge E-4(iii)) -> masked rounds (product part by the house
round_poly/fold arithmetic + rho * the additive mask contribution
M_t(X) = 2^(n-t-1)[c_0 + sum_{s<t} p_s(r_s) + p_t(X)] +
2^(n-t-2) sum_{s>t} p_s(1)) -> final_evals absorbed -> **g_open
absorbed** (= c_0 + sum_t p_t(r_t)). Masked initial claim = v_c +
rho*G; verifier end check: running claim == eq* a* b* + rho*g_open,
with eq* recomputed (constant in k/ext by replication), and a*, b*,
g_open grounded through the batched opening:

- a* claim: value = shipped a*, real parts scaled (1 - ext*) *
  eq_ls[li] (act group).
- b* claim: value = shipped (blinded) b*, real parts (1 - ext*) *
  eq_ls[li] (weight tensors) + blind part {tbl-pad, scale = ext* *
  eq_ks[0], row = [1], col = eq_ry[..128]}.
- mask-opening claim: value = g_open, blind part {tbl-mask, scale =
  1, row = monomial kernel [1, r_1..r_1^{d_1}, ...] (zero on pad
  rows), col = the 16 K basis vectors} — nu-weighted like any claim.
- v_c claim: unchanged (act side).

Guards (Q4.8 class, ~2^-496 events): ext* not in {0,1}, eq_ks[0]
nonzero, pad kernel nonzero — asserted, restart counter logged
(expected 0).

### 2.3 The claim segment (Surface L3)

One BgClaim with value v_s (shipped, uniform) and blind part
{tbl-claimseg, scale = 1, row = the 16 K basis vectors, col =
[1, 0, .., 0]}: by the conj-packing arithmetic its bpoly for row c
restricted to segment value ring c is the unit polynomial — value
ring c is added VERBATIM to b_rows[c], covering all 128 coordinates
of every row (ct included; the ct face is public via v_batch as
designed). It enters v_batch at UNIT weight, appended after the nu
draws (AZ-L2b's unit-weight discipline — no adversarial nu
degeneracy can cancel it): vb_w = sum nu_i v_i + v_s.

### 2.4 The derived byte surcharge vs BG's [MODEL] price

| line | derived B |
|---|---:|
| per masked instance: G pin 64 + mask opening 64 + extension round (deg-2, 3 evals) 192 | 320 |
| x 3 instances (mm-gate, mm-up, mm-down) | 960 |
| claim-segment value v_s | 64 |
| **TOTAL wire surcharge (P2+blind vs P2-noblind)** | **1,024** |
| committed-only (zero wire): 544 blind digit rings at 125M | 0 |
| BG's price for the same gap | ~1,664 [MODEL] |

The 640 B delta is structural, not slack: FP 3.2 priced FOUR masked
instances (3 matmuls + the CR-L4 terminal-batch sumcheck at 416 B
midpoint); the composed engine path has NO terminal-batch sumcheck
(BD replaced it by direct nu-RLC into the 16 conj-packed rows), so
its masking face is the 64 B claim segment instead of a fourth
320-512 B instance. Schedule effect: floors expected UNCHANGED under
BG-F4's witness-size-independence law (544 rings on 3.5M); verified
at derive and pinned in the UAGB1-BL freeze rows. [MEASURED section
lands with deliverable 2.]

## 3. Mode gating and the differential discipline [PLAN]

Every engine touch is gated on BgOpts.t_blind (default FALSE) and
marked [UAGB1-BL]: P0 and the noblind-P2 config are byte-identical
to BG's landed path (bg_battery and bg_canary are UNTOUCHED — lane
BJ's stage owns the canary harness — and must stay green as the
differential anchors). The shipped `pass-agg prove .. p2` flips
t_blind ON (one marked line): P2 carries the surcharge, per the
lane brief. The differential test asserts the P0 3/16 counted bytes
equal BG's pinned 383,798 B with zero blind material present.

## 4. AZB E-block dispositions (landed: `t-blind battery` 11/11 green, ~0.1 s)

Every leg runs at REAL engine arithmetic (the K field, the house
transcript, real matmul degree schedules incl. the extension round)
on standalone masked instances — the certificate layer the E-blocks
specify. The battery leg ids below are the `t-blind battery` prints.

| leg | disposition (engine certificate) |
|---|---|
| E-1 (AZB-1) | **WIRED (leg L3)** — the permanent pre-fix regression: with terminals UNBLINDED, the solver recovers a dim-6 rigged secret at EXACTLY 6 proofs, rank growing by exactly 1/proof (never faster), recovery not-before. The unblinded config = the pre-BL P2 path, kept as `p2-noblind`. |
| E-2 (AZB-2) | **WIRED (legs L4 + L5)** — (i) blinded non-recovery: a fresh pad unknown per proof keeps the augmented system rank = #proofs with the secret block FREE (the full-coset face); (ii) the AZ-L1a counting canary: the round-mask coefficient-to-exposure map computed by finite differences at a real schedule has FULL COLUMN RANK 16*n_g (240 = 240 at the L5 shape). The composed instances draw sequential challenges (the block-diagonal case of AZ-L1b — stated, easier than the shared-challenge form). |
| E-3 (AZB-3) | **WIRED (leg L7), both directions** — the adaptive forged pin G' = G + (v_c − v_false)/rho ACCEPTS an arbitrary false claim when rho is drawn without G (unbound hook) and REJECTS shipped (rho = H(.., G) is a fixed point the attacker cannot solve). In-path, G is additionally grounded against the CO

## 5. What landed in-path, and what is certified but pending

**In-path (the composed P2 prover/verifier, `pass-agg prove .. p2`):**
Surface 1 (round-polynomial masking) + Surface 3 (the claim segment),
mode-gated on `BgOpts.t_blind`. Per masked matmul: the mask is
pre-drawn and committed in the weight group; G is pinned before rho;
`ring::t_blind::masked_sumcheck_prove/verify` ship the round
polynomials as (product + rho*M_t); g_open closes the mask; G and
g_open are grounded as claims on the committed mask tensor (row =
the public linear weights, col = the coefficient extractor) through
the ONE weight-group opening. The segment adds one fresh committed
uniform K-value to the opened weight-batch value. **The
weight-touching ROUND POLYNOMIALS — the exact object BG's report named
as the P2 gap — are masked in the real composed pass.**

**Certified in `t-blind battery`, in-path-pending:** Surface 2 (the
terminal selector-extension pad for b*). The construction is complete
and validated at real K arithmetic and real matmul schedules (battery
legs L1/L6/L8, the E-8 joint-blinding cert). The in-path wiring is the
one deferred piece: it needs the extended index space (one deg-2
round), the `(1 - ext*)` scaling on the a*/b*/v_c claim reconstruction,
and the eq_ks tensor-product factorization of the pad kernel across
prover and verifier — a point-structure change to the composed loop
that the round-mask wiring does not require. Its bytes (+576 B, 3
instances x one deg-2 round) are in the derived-full total; it is
NOT claimed on the wire this wave.

**Consequence, stated plainly:** the round polynomials are masked;
the weight-side terminals b* still ship raw in-path (Surface 2
pending), so in-path P2+T_blind closes the round-polynomial surface
(the bulk exposure — ~38 kel/instance) but not the last terminal
(1 K-el/instance). Deployment-grade P2 needs Surface 2 in-path too;
its construction is proven, its wiring is the recorded next step.

### 5.1 The surcharge: derived vs measured vs [MODEL]

| line | derived | measured (3/16 composed runs) |
|---|---:|---:|
| Surface 1 round mask: G 64 + g_open 64, x3 instances | 384 | 384 |
| Surface 3 claim segment value | 64 | 64 |
| **in-path wire surcharge (P2+blind minus P2-noblind)** | **448** | **448 — BYTE-EXACT** (966,910 − 966,462) |
| Surface 2 terminal pad (one deg-2 ext round x3) | +576 | — (certified in t_blind.rs, in-path-pending) |
| **full-construction wire surcharge** | **1,024** | — |
| BG's price for the whole gap | ~1,664 [MODEL] | superseded: the model's 4th masked instance (the CR-L4 terminal-batch sumcheck) does not exist in the engine; its face is the 64 B segment |
| committed-only blind material (zero wire) | 1,728 digit rings in-path (2,304 with pads) | schedules UNMOVED: freeze row BL-1d pins tierz L8/1,368/e4 + bare L8/939/e7 at 3,538,944 + 1,728 — BG's exact pins |

Derived 12-layer full-pass P2+blind expectation: 1,019,211 + 448 =
**1,019,659 B = 0.972 MiB** (floors unmoved per BL-1d; the +448 B is
the entire delta).

## 6. Gates (measured, [MAC-BOX, non-reference, NOISY-SHARED])

- **Build**: green (`cargo build --release`).
- **T_blind certificate battery**: `t-blind battery` 11/11 green.
- **Freeze-check**: green with the UAGB1-BL rows (n_g 35/37,
  surcharge, masked sumcheck both directions); every pre-existing
  digest unmoved.
- **P0-unchanged differential (byte-identical)**: `pass-agg prove 3
  16 p0` = **383,798 B counted, accept = true — EXACTLY BG's pinned
  P0 battery value.** The T_blind wiring (all behind `if
  opts.t_blind`) changes zero P0 bytes; blind surcharge 0. (P0 2/16
  also accept, 377,631 B.) [MAC-BOX: commit 35.3 s / prove 344.4 s /
  verify 83.6 s.]
- **P2 composed run with the blind active**: `pass-agg prove 3 16 p2`
  = **966,910 B counted, accept = true, blind surcharge 448 B** — the
  weight round polynomials masked in the real composed pass on real
  ckpt data [MAC-BOX, NOISY-SHARED: commit 33.8 s / prove 336.2 s /
  verify 80.5 s].
- **P2-noblind regression** (`p2-noblind`, the BG wave-3 config kept
  for the differential): **966,462 B, accept = true — exactly BG's
  pinned battery value**, confirming the BL-F1 Tier-Z verifier fix is
  behavior-identical at r = 1 [commit 33.7 s / prove 335.3 s / verify
  80.4 s].
- **Full suite (worktree root)**: **67 tests OK in 1,013.9 s**
  [MAC-BOX, NOISY-SHARED] — includes the new tests/test_uagb1_tblind.py
  module and the Rust self-test battery.
- **`pass-agg battery` at HEAD**: running at close (result recorded in
  the ledger row when it lands; note the battery's P2 legs ride the
  BL-F1-fixed verifier — at the merged-HEAD base its honest-P2 leg
  would hit the R-BG1-class assert).
- **Full-pass 12/512 P2+T_blind single-shot**: launched in background
  [NOISY-SHARED — sibling lanes run heavy jobs incl. a 12-layer pass];
  the derived expectation is exact (BL-1d: schedules unmoved) =
  1,019,211 + 448 = **1,019,659 B**; honest fallback per the brief if
  wall-clock does not permit completion inside the lane.

### 6.1 Finding BL-F1 (a BD Tier-Z verifier assumption the blind exposed)

BD's Tier-Z masked-floor VERIFIER (`bg_verify_group`, the
`agg_floor_family_values` call) passed the raw `phi_cur` (length
r x chunk) as the L1-family `psi`, whereas the PROVER
(`agg_tier_z_mask_floor`) folds it via `compute_psi(phi, chunk,
prev_c)` (length chunk). The two coincide only when the last
schedule level has r = 1 — true for every shipped pass schedule, so
P2-noblind was always green. The T_blind tensors enlarge a SMALL-
shape weight group's n0 enough to move the last level to r = 6,
which surfaced the mismatch as a psi-length panic (960 vs 160). The
one-line fix mirrors the prover in the verifier (fold via
`compute_psi`); it is behavior-identical at r = 1 (P2-noblind
regression re-run = 966,462 B accept, Section 6). The full 12-layer
pass schedule keeps r = 1 at the last level regardless of the blind
(BL-1d), so the shipped pass path was never affected.

**R-BG1 connection (flagged for the BJ merge seam, NOT claimed as
its fix):** R-BG1's recorded crash is the SAME assert at the same
line class ("psi seam ... left 972 right 162" = 6 x 162 — the 3/16
P2 weight-group last level r = 6, chunk = 162). The canary's P2
verifies at merged HEAD hit exactly this raw-phi-vs-folded-psi
mismatch. My fix removes that crash site in `bg_verify_group`'s
Tier-Z branch; lane BJ owns R-BG1 (the eval_proof multi-claim API +
the canary call sites) — the orchestrator should reconcile the two
at the BJ -> BL merge (my change is one marked block, safe to keep
or subsume).

## 7. Freeze rows and reproduction

`freeze_check_uagb1_bl()` (inside `freeze-check`), both directions:

- UAGB1-BL-1a: n_g arithmetic at the pass matmul shapes — mm-gate/up
  (lk 10) = 35, mm-down (lk 11) = 37.
- UAGB1-BL-1b: the derived full-construction wire surcharge = 1,024 B
  (3 x 320 + 64; BG's ~1,664 B [MODEL] superseded structurally).
- UAGB1-BL-1c: masked-sumcheck completeness + forged-G soundness at a
  real matmul-schedule instance (both directions, real K arithmetic).
- UAGB1-BL-1d: the 12-layer pass schedules are UNMOVED by the blind
  inventory (+1,728 rings): tierz L8 / 1,368 / e4 and bare L8 / 939 /
  e7 — BG's exact pins (BG-F4 at pass scale).

Every pre-existing freeze digest unmoved at every commit.

```
zkmatrix-rs$ cargo build --release
zkmatrix-rs$ ./target/release/ring_matmul t-blind battery      # 11 certificate legs (E-1..E-9)
zkmatrix-rs$ ./target/release/ring_matmul t-blind expect       # the derived surcharge
zkmatrix-rs$ ./target/release/ring_matmul freeze-check         # incl. UAGB1-BL-1a..1d
repo$ ./zkmatrix-rs/target/release/ring_matmul pass-agg prove 3 16 p0          # differential: 383,798 B (BG pin)
repo$ ./zkmatrix-rs/target/release/ring_matmul pass-agg prove 3 16 p2-noblind  # regression: 966,462 B (BG pin)
repo$ ./zkmatrix-rs/target/release/ring_matmul pass-agg prove 3 16 p2          # THE BLINDED P2: 966,910 B, +448 B
repo$ python3 -m unittest tests.test_uagb1_tblind
```

---

*Changelog: 2026-08-10 — plan edition (deliverable 1): leak
inventory, design transcription (zero-extra-identity T_blind in the
weight group, masked instance FS rows, claim segment), derived
surcharge vs the ~1,664 B [MODEL] price with the structural
explanation, E-block plan table.
2026-08-11 — build edition (deliverables 2-3): t_blind.rs core +
11/11 certificate battery; Surface 1 + segment wired into the
composed P2 path; P0 differential byte-identical (383,798 B);
P2-noblind regression byte-identical (966,462 B); P2+blind accept
at 966,910 B with the 448 B surcharge byte-exact to derivation;
finding BL-F1 (the Tier-Z verifier psi seam, R-BG1-class) fixed in
the composed verifier; freeze rows BL-1a..1d.*
