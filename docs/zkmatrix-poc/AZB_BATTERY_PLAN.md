# AZB Battery Plan — Spike Legs, Engine Specs, and the Measurement Queue (U-AG-B1, Agent BC)

Status: LANE DELIVERABLE (2026-08-08, U-AG-B1 lane BC, worktree
wt-uagb1-bc). Companion executable: `scripts/azb_battery_spike.py`
(**20/20 OK**, ~2 s, stdlib only; carried by
`tests/test_azb_battery.py`). This document dispositions EVERY AZB
battery id — each is either EXECUTABLE (a green spike leg) or SPEC'D
[ENGINE PENDING - BB] — records the F-Z1 masking-corner re-check at
the build round's operating points, and writes the measurement plans
that take O-5, O-6, and F-O2 from [MODEL] to [MEASURED]. Nothing is
dropped.

Sources (all in-repo, cited inline below): AGGREGATION_ZK_DESIGN.md
Section 6 (the AZB-1..9 spec; "confinement, not denial"),
AGGREGATION_FOLDING_DESIGN.md Sections 7-9 + the Section 8 FINAL
reconciliation block (the AZB-10 renumbering ruling; F-O1..F-O5),
AGGREGATION_FOLD_PRIVACY_PRICING.md Sections 2-4 + 8 (FP-L1/L2/L3,
the AZB-11 canary spec, F-Z1/F-Z2/F-Z3), AGGREGATION_PARAMS_DESIGN.md
5.3/5.4 (the O-5/O-6 models), AGGREGATION_LITERATURE.md 8.1 (the
O-item definitions), PROOF_BYTE_LEDGER.md 0.1 (the four recorded kel
points), TARGET_CONTRACT.md Amendment A1 (the freeze conditions),
PROGRESS_UAGB1.md (machine note: [MAC-BOX] timing rule).

## 1. Scope and the AZB id inventory

### 1.1 Numbering authority

- **AZB-1..9**: AGGREGATION_ZK_DESIGN.md Section 6 (U-AG3 EC lane) —
  the R3-battery analogue for the aggregate layer. The battery's job
  is NOT "no leak" (Section 4 proves that false at the floor) but
  **confinement**: everything is simulatable except exactly R, and R
  is exactly what Section 5.4 says it is.
- **AZB-10** = the IXF segment-map/group-map F5 pair (FA's
  "AZB-7-labeled" pair, renumbered by the U-AG4 FINAL ruling —
  AGGREGATION_FOLDING_DESIGN.md Section 8 reconciliation block item
  2: "Read every 'AZB-7 F5 pair' in this doc as AZB-10").
- **AZB-11** = the weight-independence canary
  (AGGREGATION_FOLD_PRIVACY_PRICING.md Section 4.2; same FINAL
  ruling).
- AZB-5's freshness unit is the **PASS** (FB Section 2.2 row A7 /
  8.1 item 1: refresh unit restated at pass scope).

### 1.2 Grades used here

- **EXECUTABLE** — a green leg in `scripts/azb_battery_spike.py`
  (spike grade: GF(q31) toy arithmetic; ordering / counting / split /
  recovery STRUCTURE, not lattice binding strength — the SPKZ
  convention). The spike re-runs its three parent simulators
  (aggregation_zk_spike 14/14, fold_privacy_pricing_spike 15/15,
  aggregation_folding_spike 33/33) and asserts their recorded verdict
  lines before printing a single leg.
- **[ENGINE PENDING - BB]** — the engine-scale leg: requires the Rust
  aggregation implementation (the first aggregate statement is BB's
  critical path; none exists at lane open). Section 3 gives each
  pending leg its exact procedure and pass/fail criterion.

Every AZB id below carries BOTH: the executable spike leg(s) it
already has, and the engine leg(s) it still owes. F5 pair = attack
leg ACCEPTS under the violated order / shipped order REJECTS the same
crafting — both directions always exercised.

## 2. The disposition table (every AZB id, none dropped)

| id | battery content (spec source) | spike leg(s), green | engine leg | 
|---|---|---|---|
| AZB-1 | terminal leak demonstrated, permanent unmasked baseline (EC 6) | `AZB-1`: rank 15/16 at 15 transcripts, EXACT recovery at the predicted count 16 | E-1 [ENGINE PENDING - BB] |
| AZB-2 | masked non-recovery + counting canaries (EC 6) | `AZB-2a` full-coset constructive certificate (48 transcripts, pad block 48/48, wrong tensor explained exactly); `AZB-2b` AZ-L1a rank 14 = n_g, forced = ell+1 = 5; `AZB-2c` AZ-L2a pad diagonal 3/3; `AZB-2d` AZ-L1b joint rank 28 = n_g1+n_g2, forced 2(ell+1) | E-2 [ENGINE PENDING - BB] (derive-time canaries at engine shapes) |
| AZB-3 | statement-hash F5 pair — T_blind outside h0_agg (EC 6 / AZ-L4 A3) | `AZB-3`: crafted rounds + concretely-realized swapped mask set ACCEPT the false instance when unbound; digest-in-h0 moves the tape AND pins the opening — rejects on both masks' own tapes | E-3 [ENGINE PENDING - BB] |
| AZB-4 | instance/batch ordering pairs (EC 6: A2, CRB-N4 one level up, E3Z-N1) | `AZB-4i` pad-after-r absorbs the defect (SPKZ-4 adapted); `AZB-4ii` mu-before-terminals compensation accepts / prefix-through-terminals rejects; `AZB-4iii` nu-before-G-pin crafted pin accepts / pin-first rejects | E-4 [ENGINE PENDING - BB] |
| AZB-5 | T_blind freshness, refresh unit = the pass (EC 6; FB A7) | `AZB-5`: 16 pads reused pairwise leak one equation per pair — full recovery from 32 transcripts (half rate); fresh pads keep the full coset | E-5 [ENGINE PENDING - BB] (the derive-time reuse REFUSAL is engine-only by nature) |
| AZB-6 | fold-ordering pair at the eval-proof levels (EC 6 / AZ-L4 A1) | `AZB-6`: t-after-c forgery accepts a false batched claim; commit-then-challenge rejects (SPKZ-5 adapted) | E-6 [ENGINE PENDING - BB] (per level, per group) |
| AZB-7 | floor exhibit + confinement, the permanent AZ-T1 regression (EC 6) | `AZB-7a`: floor recomputes exactly from (witness, challenges) at the bare level AND one digit level deeper; rank law [1..m2] with exact recovery at t = m2, not before; `AZB-7b`: witness-FREE S2-class simulator produces accepting transcripts (8/8) with the honest structure (19 exposures, 5 forced, 14 free = n_g) | E-7 [ENGINE PENDING - BB] |
| AZB-8 | joint-rank certificate AZ-O2 (EC 6 — the one closure-threatening leg) | `AZB-8`: conditional rank rank([E;F])−rank(F) = n_exp with pad surplus (PASS); rigged deficient mask space drops to 4 < 10 and FIRES | E-8 [ENGINE PENDING - BB] (derive-time, per pass, per group) |
| AZB-9 | slot-completeness of blinding AZ-R1 (EC 6) | `AZB-9`: slot-SHARED blind leaks — two exposures recover all 8 slot values (rank 10/10); ring-granular blinds keep the pad block 16/16 | E-9 [ENGINE PENDING - BB] (real GF(q^16) slot arithmetic) |
| AZB-10 | IXF segment-map + group-map F5 pairs (FA Section 7; FINAL ruling) | `AZB-10a` segment map: swap-only-chained pass accepts under a late map, eq-kernel binds the WRONG slices (stacked-MLE mismatch exhibited), declared map rejects, h0_agg pins; `AZB-10b` group map: the FPP-4 pair — shipped recompute + weight-invariance; migration leaks the explicit weight functional c_5*w1, canary fires, hash edge rejects | E-10 [ENGINE PENDING - BB] (against the real Statement v3 pass manifest — F-O1) |
| AZB-11 | weight-independence canary (FB Section 4.2, four legs + reject semantics) | `AZB-11a` the four FB-spec legs: static support, functional recompute (claims AND floor), perturbation invariance, REJECT-F5 migration; `AZB-11b` two deliberately weight-CONTAMINATED variants FIRE (claim-layer smuggle; floor-layer fold-in with the delta an explicit weight functional) | E-11 [ENGINE PENDING - BB] (deployment-blocking semantics wired into derive — F-Z3) |

Count: 20 executable spike legs green (incl. the F-Z1 row of Section
4), 11 engine legs spec'd below. Every AZB id has at least one green
executable leg TODAY; no id's disposition waits on BB.

## 3. The [ENGINE PENDING - BB] SPEC blocks

Common harness discipline (EC Section 6): serialized runs, 2^22
element cap per run, memory-capped wrap (the shared-box rule; on this
round's Mac box the machine note applies — byte/verdict outputs are
machine-independent). "Derive time" = during statement/proof
derivation, before any wire bytes are emitted. Each leg lands when
its BB stage exists; none blocks a BC exit.

- **E-1 (AZB-1 at engine scale).** Procedure: rigged
  single-coefficient-support toy tensor family (U-R1a style) inside
  the aggregate statement with terminal blinding DISABLED (a test
  hook, never a shipping mode); collect the terminal values across
  ceil(dim) proofs of the same witness; solve. PASS: exact recovery
  at the predicted transcript count and rank growth exactly
  dim-per-proof. Stays in the suite as the permanent pre-fix
  regression. Needs: BB stage (2) (a committed statement with
  terminals). 
- **E-2 (AZB-2 at engine scale).** Procedure: (i) the same pipeline
  with blinding ON: the solver's consistent set must be the full
  predicted coset (spot-checked by explaining >= 2 planted wrong
  tensors exactly); (ii) derive-time counting canaries at the real
  instance shapes: per instance, mask-map rank = n_g with exactly
  ell+1 forced relations (AZ-L1a); joint rank across the
  shared-challenge parallel instances = sum n_g (AZ-L1b);
  terminal/pad map full-rank diagonal (AZ-L2a). PASS: all ranks
  exact — counted by the engine, not assumed. Needs: BB stages
  (2)-(3); the canaries belong in the derive path (E3Z-N4 pattern).
- **E-3 (AZB-3).** Procedure: harness variant that computes h0_agg
  WITHOUT the T_blind digest (test hook); replay the spike's swap
  (second mask segment set presented to the opening) at engine scale
  — must ACCEPT under the hook and REJECT byte-identically under the
  shipped hash (digest mismatch surfaces as a statement-hash
  mismatch, not a late opening failure). PASS: both directions.
  Needs: BB stage (2) + the statement-hash plumbing.
- **E-4 (AZB-4).** Procedure: three FS-order test hooks — (i)
  extension-pad segment committed after the instance outer draw;
  (ii) mu derived before the blinded terminal absorption; (iii) nu_i
  derived before the G_i pin. For each: the spike's crafting replayed
  at engine scale ACCEPTS under the hook, REJECTS under the shipped
  transcript order. PASS: all three pairs, both directions. Needs:
  BB stages (2)-(3).
- **E-5 (AZB-5).** Procedure: (i) attack leg — two proofs of the same
  pass forced (hook) to share the T_blind segment: the transcript
  differencing solver recovers planted values at the predicted half
  rate; (ii) the shipped derive path REFUSES the second proof —
  derive-time freshness assert (statement hash records the T_blind
  segment id; a repeated (witness digest, T_blind digest) pair
  aborts). PASS: leak demonstrated under the hook; refusal fires in
  the shipped path; freeze-row pinned both directions (R-EB-row
  style). Needs: BB stage (2) + the derive-path assert (F-Z3
  wiring).
- **E-6 (AZB-6).** Procedure: per LaBRADOR level i and per commitment
  group, a hook that derives c^(i) before absorbing u_i; the SPKZ-5
  steering replayed at the real level shapes must ACCEPT under the
  hook and REJECT shipped; the floor-last edge (z_L after all fold
  challenges) checked the same way. PASS: every level, every group,
  both directions. Needs: BB stage (5)/the eval-proof path.
- **E-7 (AZB-7).** Procedure: (i) recompute the floor image z_L from
  (witness, public challenges) by the engine's own fold chain —
  byte-exact match against the transcript (the leak is exactly the
  predicted object, no more, no less); (ii) unrecursed harness:
  accumulate P transcripts, assert rank grows by exactly dim(z) per
  proof to exact recovery at the predicted threshold (rigged toy
  scale); (iii) distributional simulator-match for every non-R
  component against the S1-S6 sampler at toy scale. PASS: (i) exact,
  (ii) at-threshold-not-before, (iii) all components. This leg is to
  AZ-T1 what Z1-a is to C-02. Needs: BB stage (5).
- **E-8 (AZB-8 / AZ-O2).** Procedure: at derive time, assemble the
  joint exposure system — all sumcheck exposures + the floor image —
  restricted to the pad/mask dimensions (T_blind columns are inside
  the batched opening: AGGREGATION_ZK_DESIGN 2.4 item 3); per group,
  with AZB-11 leg 1's support check as input (FB 8.2 item 2); assert
  conditional full row rank on the T_sim block:
  rank([E;F]) − rank(F) = n_exposures. FAIL demotes the Surface-1/2
  grades (the 5.3 conditional step) and is deployment-blocking.
  PASS: rank exact at every derive. Needs: BB stages (2)-(5) (the
  full exposure inventory exists only with the eval-proof path).
- **E-9 (AZB-9).** Procedure: real partially-split GF(q^16)
  arithmetic: (i) rigged slot-shared blind (one K-value drawn, its 8
  slot residues reused) — the per-slot solver recovers planted slot
  data (attack demonstrated); (ii) shipped ring-granular draw — all
  8 slot images certified independently uniform (rank per slot).
  PASS: both directions at engine slot arithmetic. Needs: BB stage
  (2) (T_blind segment sampling discipline).
- **E-10 (AZB-10).** Procedure: against the real Statement v3 pass
  manifest (32/16 segment rows + privacy-class group map — F-O1,
  BB's manifest work): (i) segment-swap hook (manifest absorbed
  after the outer draws): a relabeled pass that only chains under
  the swap must ACCEPT under the hook, REJECT shipped (h0_agg
  mismatch); (ii) group-swap hook: a weight segment migrated into
  the activation group after mu/nu_g — ACCEPT + leak under the hook
  (the floor delta is an explicit weight functional), REJECT
  shipped. PASS: both edges, both directions. Needs: BB stages
  (3)-(4) (manifest + fold).
- **E-11 (AZB-11).** Procedure: the four FB-spec legs wired into the
  derive path (F-Z3): (1) static support check every pass (manifest
  arithmetic: activation batch entries reference T_act only; nu_act
  support zero on T_W); (2) functional recompute of the
  activation-group batched claims AND activation floor from (T_act,
  challenges) alone — byte-exact; (3) perturbation harness: W
  perturbed, T_act fixed — bare activation transcript byte-identical;
  (4) the F5 migration reject. REJECT SEMANTICS (FB 4.2, verbatim):
  ANY canary failure is deployment-blocking for P2 — the label
  "weights private" is void until it passes — not a warning. PASS:
  legs 1-3 pass and leg 4 fires as specified. Needs: BB stages
  (3)-(5) + F-O1 manifest.

## 4. F-Z1 — the masking-corner re-check (dated row)

**Row (2026-08-08, lane BC)** — re-derived from
AGGREGATION_FOLD_PRIVACY_PRICING 3.1's formula (the FPP-7
convention: corner bound b = 27.2 + 0.5·log2(floor_coords/81,920)
[MODEL, sqrt(dim) first-order from EC SPKZ-7b's e_L <= 4
no-limb-growth corner at the EB-corrected layer floor]; corner
survives iff b < 28.00 = log2(q/8); limb-growth branch 28.6 + same
scaling must stay dead). Printed by `azb_battery_spike.py` leg F-Z1:

| operating point | floor | bound b | verdict |
|---|---:|---:|---|
| activation pass floor (design-doc schedule, L8) | 710 rings = 90,880 coords | 2^27.27 | **corner SURVIVES** (0.73 b) |
| weight pass floor (design-doc schedule, L8) | 734 rings = 93,952 coords | 2^27.30 | survives (0.70 b) |
| 2^20 rig pass floor (L7) | 732 rings = 93,696 coords | 2^27.30 | survives (0.70 b) |
| limb-growth branch, all points | — | 2^28.67-28.70 | stays DEAD (the corner is e_L <= 4 no-limb-growth ONLY) |
| survival threshold (general) | 248,335 coords = 1,940 rings | b = 28.00 | any floor under ~1,940 rings keeps the corner |
| 125M-pass floor band (plausible regrowth class 600-800 rings) | 76,800-102,400 coords | 2^27.15-27.36 | survives across the whole band |

**125M exact point: [BB-SCHEDULE PENDING].** The 125M-shape pass
schedule (level count, floor rings) is BB's derivation (the ledger's
"the 125M-shape Tier Z pass number must be DERIVED by this round").
Recomputation recipe, exact: when BB posts the schedule, read
floor_rings per group, set floor_coords = 128 · floor_rings, compute
b = 27.2 + 0.5·log2(floor_coords / 81,920); the corner survives iff
b < 28.00; check the limb-growth branch at 28.6 + the same scaling
stays > 28.00 (it is dead at 81,920 already and the scaling is
monotone increasing, so it stays dead at any floor >= the layer
floor — one-sided). The floor is witness-size-independent (the
LaBRADOR regrowth law, FP-L1 component 3), so the 600-800-ring band
above is the expected landing zone; a schedule outside it would
itself be a finding.

Also carried on the A1 freeze but NOT spike-implementable here:
**F-Z2** (SC-L4 extraction at the masked-floor response bound —
exported to the Phase 2.5 review with SC-L4/SC-L6 per FB 8.2 item 1;
the extractor rewinds challenges only and never needs the floor
mask's randomness — the Q4.2a'-class transcription lands at build)
and **F-Z3** (the floor-mask rejection sampler + abort discipline +
AZB-11 wiring into the derive path — BB stage (5) work; E-11 above
is its battery face; the A8 row of FP-L2 is its ordering face:
the floor mask is prover-internal, rejection-sampled, never
committed — no hash edge exists or is needed, and the response is
sent after all of that group's level challenges, AZB-6 unchanged).

## 5. O-5 to measurement — the verifier model (R2 discipline)

**Identification.** O-5 is the U-AG trench obligation "verifier
model to R2: sqrt + polylog cost model on measured kernel constants,
statement validation included, against <= 2 s single-threaded p95"
(AGGREGATION_LITERATURE.md 8.1, adopted at the U-AG FINAL;
PROGRESS_UAG2.md: "O-5/O-6 models carried in DA's doc"). F-O3
(AGGREGATION_FOLDING_DESIGN 9.4) is the same obligation at pass
scope ("the pass verifier model to R2 discipline... includes the
two-proof structure").

**The [MODEL] rows to replace** (every number below is currently a
model, none measured):

| current [MODEL] row | source | value |
|---|---|---:|
| ring-MAC kernel constant | RING_MULT_BOTTLENECK 6.5 (measured 2026-07, REFERENCE box) — the one measured anchor, machine-bound | 0.18 us/ring-MAC |
| layer verify, 2^20 exact-digit / per-level | PARAMS 5.3 | 0.14 / 0.18 s |
| layer verify, FFN exact-digit / per-level | PARAMS 5.3 | 0.52 / 0.93 s |
| W-C pass verify (two-proof, FFN) | FA 6.4 | ~0.34 + ~0.83 + polylog ≈ 1.2 s-class |
| W-A rejection arithmetic (public-weight evaluation) | FA 6.4 | 4.33e9 el ≈ 6.1 s |

**Plan.**
- *Instrument/harness:* the zkmatrix-rs release verifier, driven the
  way tests/test_statement_v3.py drives the native binaries; a
  dedicated `verify --timed` mode on BB's aggregate-statement CLI;
  p50/p95 over >= 20 warm runs, single-threaded, statement
  validation INCLUDED (the contract statistic, TARGET_CONTRACT
  Section 4).
- *Shapes:* (a) the 125M 12-layer pass statement 512x768x2048 — the
  PoC exit number (roadmap Section 1(b): verify <= 2 s); (b) the
  2^20 ledger-unit pass (the running-gate shape); (c) per-gadget
  micro-costs: the level-1 statement pass MAC count (the PARAMS 5.3
  dominant term) measured directly, which also re-anchors the 0.18
  us/ring-MAC constant on this box.
- *What replaces what:* the measured 125M-pass p50/p95 replaces the
  FA 6.4 1.2 s-class row AT THE 125M SHAPE (the 7B-shape row stays
  [MODEL] until a 7B statement exists); the measured level-1-pass
  time replaces the PARAMS 5.3 dominant-term model at the built
  shape; a 10-second microbench of verifier-side stacked-MLE
  evaluation at ~4.33e9 elements settles the W-A rejection
  empirically (cheap, recommended, optional).
- *Machine note:* every timing this round is **[MAC-BOX,
  non-reference]** (PROGRESS_UAGB1.md machine note) — magnitudes and
  ratios only; the <= 2 s contract line is only PASSABLE
  contract-grade on the reference box or after a dated machine-line
  amendment (orchestrator decision at FINAL, not a lane decision).
  The PoC exit criterion should be read accordingly: measure on the
  Mac, flag, and let FINAL disposition the machine line.
- *Blocks on:* BB stage (2) (matmul statement) for any single-layer
  verify; stages (3)-(4) for the pass number; **the eval-proof
  (batched-opening) verify path is the DOMINANT modeled term (the
  level-1 statement pass) and does not exist in the engine yet** —
  so O-5 lands in full only at/after BB stage (5); the wire format
  (6) affects byte gates, not time gates.

## 6. O-6 to measurement — the prover model (H-05 discipline)

**Identification.** O-6 is "prover model vs H-05: multiplier on the
578.7 us/el whole-prove, including the commit-path change (global
Ajtai matvecs replacing per-wave BDLOP commits); >10x means surface
it, not ship it" (AGGREGATION_LITERATURE.md 8.1). FA 6.5 extends it
to pass scope (IXF adds no prover-side fold work beyond the bigger
single sumchecks; commit path = EA's dense marginal over 32x
elements, committed once; "No H-05-class risk is introduced [MODEL];
O-6 owns the full model").

**The [MODEL] rows to replace:**

| current [MODEL] row | source | value |
|---|---|---:|
| commit-path marginal, FFN per-level / exact-digit | PARAMS 5.4 | +25.6 / +13.2 us/el (+4% / +2% on 578.7 us/el) |
| commit-path marginal, 2^20 | PARAMS 5.4 | +9.1 / +6.6 us/el |
| dense commit marginal | EA (cited in FA 6.5) | +0.2 us/el |
| whole-prove multiplier vs H-05 | O-6 headline | unmeasured (the >10x line) |
| pass prover p50/p95 | roadmap Section 1(d) | measured-not-targeted, owed by the PoC |

**Plan.**
- *Instrument/harness:* prover wall-clock with per-phase timers
  (commit pass / sumcheck instances / masked descent pair /
  eval proof / serialization) on BB's 125M statement; >= 20 warm
  runs, p50/p95; single-run < ~10 min and H-03 memory discipline
  (serialized runs; the Mac box is not the 15 GiB WSL2 box but the
  cap discipline stays).
- *Shapes:* the 125M single layer (512x768x2048) at BB stage (2);
  the 12-layer pass at stages (3)-(4); Tier Z mode (masked floor,
  stage (5)) separately — the mask surcharge is priced prover-cheap
  (committed data, no sampling loops except the floor sampler's
  FS-with-aborts restarts — F-Z3's discipline governs; restart
  counts logged).
- *What replaces what:* measured commit-pass us/el at the 125M
  statement replaces the PARAMS 5.4 marginal AT THAT SHAPE and the
  EA dense marginal; the measured phase breakdown gives the
  Mac-internal commit share. **The H-05 multiplier itself is
  reference-box-bound**: 578.7 us/el is the reference-box measured
  whole-prove, so the contract-grade multiplier requires either a
  reference-box pass or the machine-line amendment — this round
  records the Mac ratios [MAC-BOX] and the multiplier lands at
  FINAL's discretion (same disposition as O-5's 2 s line).
- *Blocks on:* BB stage (2) for the commit + single-layer numbers
  (nothing else); stages (3)-(5) for pass/Tier Z rows. O-6 has no
  paper dependency — it is measurement-ready the day the statement
  runs.

## 7. F-O2 to measurement — the kel(dw,dt) descent-size fit

**What it is.** The masked descent pair's K-element count at dt = 9
is today a 4-point [MODEL] fit — kel(dw,9) = 2·dw² + 11·dw + 235 —
exact on the four recorded points dw 17/19/21/24 -> 1,000 / 1,166 /
1,348 / 1,651 kel (PROOF_BYTE_LEDGER 0.1/1-2; F-IF1.8), extrapolated
+5 to the pass depths. It is carried as a CONDITION on the frozen
Amendment A1 Tier Z number (TARGET_CONTRACT A1: "F-O2 (kel(dw,dt)
descent-size measurement)") and flagged as THE load-bearing model
risk of the byte tables (F-IF1.8; FA 6.3: +25% on the extrapolated
increment moves the W-C pass total +1.9%).

**The points owed, and a 125M finding.**

| point | pass | fit predicts | status |
|---|---|---:|---|
| kel(26, 9) | 2^20 ledger-unit pass (dw 21 + 5) | 1,873 kel = 119,872 B | owed — feeds the 294,136 / 576,056 B running gates |
| kel(29, 9) | FFN 7B pass (dw 24 + 5) | 2,236 kel = 143,104 B | owed — feeds every FA/FB pass table and the A1 freeze condition |
| kel(~25, 9) | **125M 12-layer pass** [MODEL, this lane's derivation]: layer witness 512x2048 = 2^20 exactly -> dw_layer 21 (the RECORDED 2^20 rig point, 1,348 kel); 12 layers pad to a 16 index space (PROGRESS_UAGB1 BB item 4 note) -> lambda 4 -> dw_pass ~ 25 | 1,760 kel = 112,640 B | owed for the 125M budget derivation — but only ONE step beyond the last recorded point (vs +5 for the 7B rows): **the 125M rung barely exercises the extrapolation, so F-O2 is NOT PoC-blocking; it is 7B-freeze-blocking** |

(The dw_pass ~ 25 row is [MODEL] pending BB's settle of the 12->16
index-padding design note against F-IF1; if BB lands lambda = 4 the
row stands, and kel(25) becomes the round's measurable point.)

**The precise blocking statement.** Two measurement routes:

1. *In-statement route (full grade).* The folded pass descent
   instance exists only inside the aggregate pass statement. That
   statement's terminal batch is served by the batched
   Greyhound/LaBRADOR **evaluation proof, which does not exist in
   the engine yet** — it is BB's critical path (stages (2)-(5)). So
   the in-statement kel measurement blocks on the eval-proof
   implementation in the direct sense: no aggregate statement runs
   end-to-end without it, and serialized-byte grade additionally
   needs the wire format (stage (6)). Landing order: stage (4) for
   the count, stage (6) for bytes.
2. *Standalone-rig route (early, count-grade — FA 9.4's route).* The
   M4 masked descent rig at stacked toy shapes can produce the kel
   COUNTS without any eval proof: the pair is GKR-transcript-only
   and the Q4.7-9 masking machinery is built. Its real prerequisite
   is the **multi-wave C2 lift** (BB stage (2)'s sub-item): a
   dw >= 25 descent commits a >= 2^24-element witness column against
   the ~2^17-element q31 C2 wave cap
   (RANGE_AGGREGATION_DESIGN Phase 5; TARGET_CONTRACT Section 5's
   known wall). With the lift landed, the rig measures kel(25)/
   kel(26) directly (memory-disciplined; dw 29 needs an H-03-grade
   plan — the FFN-pass witness is 32x the recorded dw-24 run).

*Pass/fail criterion:* measured kel within +25% of the fit at each
point keeps every recorded verdict (FA 6.3: the pass totals move
<= +1.9%); a larger miss re-opens the FB tier tables — mechanical
re-run, formulas are in fold_privacy_pricing_spike FPP-5a — and, if
kel(29) misses, the A1 freeze condition F-O2 fails and the freeze
re-opens per its own text. *What replaces what:* each measured point
replaces the fit AT THAT POINT in F-IF1.8's table; the fit itself is
retired (or re-fit and re-flagged) once dw 26 and 29 are recorded.

## 8. Running gates and freeze-condition status (BC view, 2026-08-08)

| gate / condition | line | status |
|---|---:|---|
| Tier N per-layer engineering gate (P0 only) | 262,144 B/layer | STANDING — not yet measurable (no aggregate statement, no wire format; byte gates bind on serialized bytes, M-05). Checkpoint for BB stages (2)/(6). |
| 2^20 rig Tier Z pass gate | 576,056 B | STANDING — same dependency; the number is FB's derived row (FPP-5c), machine-independent when it lands. |
| Tier N pass rows (2^20 / FFN W-C) | 294,136 / 505,272 B | reference rows for BB's serializer (FA 6.1). |
| 125M-shape Tier Z pass number | [MODEL — must be DERIVED this round] | orchestrator/BB derivation; BC input: the F-Z1 recipe (Section 4) + the kel(25) row (Section 7). |
| F-Z1 (masking corner) | b < 28.00 | **RE-CHECKED, survives** at all design-doc points and the whole plausible 125M band (Section 4, dated row); exact 125M point [BB-SCHEDULE PENDING]. |
| F-Z2 (SC-L4 at masked response bound) | — | OPEN — Phase 2.5 review item (with SC-L4/SC-L6), FB 8.2's transcription route; not a BC spike item. |
| F-Z3 (floor-mask sampler + abort discipline + canary wiring) | — | OPEN — BB stage (5); battery face spec'd as E-11 (Section 3). |
| F-O1 (pass manifest + AZB-10 engine pair) | — | spike face GREEN (AZB-10a/b); engine face = E-10, blocks on BB manifest work. |
| F-O2 (kel measurement) | fit +25% | plan in Section 7; NOT PoC-blocking at the 125M rung (dw ~25 is one step past a recorded point), 7B-freeze-blocking. |
| F-O3 / O-5 (pass verifier to R2) | <= 2 s p95 | plan in Section 5; [MAC-BOX] rule applies. |
| F-O4 (relaxed-e0 before any 8B freeze) | — | STANDING, untouched — no 8B layout is frozen this round; the obligation gates the 8B rung, not the 125M PoC. |
| F-O5 (Tier Z pass number = W-C base + mask deltas) | frozen 1,114,112 B | DISCHARGED at U-AG4 FINAL (7B reference scope); the 125M-shape derivation is the round's open row (above). |
| O-6 (prover model vs H-05) | >10x surfaces | plan in Section 6; commit-path marginal measurable at BB stage (2), multiplier reference-box-bound. |

---

*Changelog: 2026-08-08 — first edition (U-AG-B1 lane BC). Disposition
table for AZB-1..11 (20 executable spike legs green in
azb_battery_spike.py; 11 engine SPEC blocks E-1..E-11 [ENGINE
PENDING - BB]); F-Z1 re-check dated row (corner survives at
27.27/27.30 vs 28.00, growth branch dead, 1,940-ring survival
threshold, 125M band safe, recipe for the BB schedule); O-5/O-6
identified from AGGREGATION_LITERATURE 8.1 with measurement plans
(instruments, shapes, replaced [MODEL] rows, [MAC-BOX] rule, precise
blocking); F-O2 plan with the two-route blocking statement (eval-proof
implementation for in-statement; multi-wave C2 lift for the
standalone rig) and the 125M finding that dw_pass ~ 25 sits one step
past the recorded dw-24 point (F-O2 not PoC-blocking); running-gate
status table.*
