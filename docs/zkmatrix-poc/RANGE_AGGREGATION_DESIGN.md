# Range architecture + instance aggregation — paper-first design study

Status: STUDY (nothing here is built). Addresses the 2026-07-12 audit's
Phase 5 items 2 and 3 and the GPU_GO_NO_GO "Range architecture" gate.
Measured numbers are marked with their provenance; everything forward-
looking is [MODEL]. House rules apply: any constant this study freezes
gets a freeze row when its tranche lands, and every capacity claim must
be re-derived by the engine's derive-time gates before it is trusted.

## 1. The problem, measured

The U-K8 committed chain (ffn-chain, B = 1020 blocks, 2026-07-10/13,
[NOISY-SHARED] 1T) attributes 96-97% of proving time to the q46
binary/range family: 582 dce/el of q46 commitments (8 bit planes per
int8 value plus ARP mask material), the limb-split x3 q46 wave, and the
FS-with-aborts restart loop. Two 2026-07-13 fixes removed the restart
pathology (a log M constant sized for 12-sigma masks applied to the
ARP's 3.5-sigma masks, then the joint Q4.2b test across the round's 4
coupled units): measured restarts fell ~17x, from ~240 to ~14 per
1-block run. Wall-clock attribution after those fixes awaits a quiesced
re-measure — but even at ZERO restarts the planes, the q46 wave, and
the per-block structure remain, so the architecture question stands:

- Bit tensors are 82.8% of the whole pass's committed
  element-equivalents (GADGET_MODULUS_DECISION Section 2) — the range
  strategy multiplies the dominant share of the commit bill.
- The q31 ct-round's C2 gate (q > 8 beta) caps one wave at ~134
  commitments of the U-K5c shape, so a committed single-descent lookup
  caps near 2^17 dense elements — hence B = 1020 blocks, 5,526 blocks
  per 512x11008 layer, 176,832 per 32-layer pass (audit H-01). Fixed
  per-block costs never amortize: 14.1 dce/el of lookup material that
  would be ~1e-4 at per-layer instances, and 37.5 B/el of masked
  transcript (~6.3 GiB/pass against a 256 KiB budget).

The two levers below are separable: Section 2 lifts the instance size
(needed by EVERY strategy, including the as-built one), Section 3
replaces the bit-plane range argument itself.

## 2. Lifting the C2 cap: per-layer instances (audit Phase 5.3)

What actually hits the cap is the DATA mass: a layer's value
commitments (X and Y at 2^22.4 elements) need ~2,700 commitments of
the U-K5c shape, 20x past one wave's ~134. The lookup's own aggregate
material (m column, blinders, masks, pins) is small. Two options:

### Option (b), recommended: multiple q31 waves, one descent per layer

Nothing in the commit-before-challenge discipline requires ONE wave.
Commit the layer's material across ceil(n_commits/134) sequential
C2-capped waves, bind every wave into ctx (the D-4 streaming-binding
pattern already sequences per-block rounds this way), and only then
derive the descent challenges. One descent then serves the whole layer
— the Section 5 batched descent was designed for exactly this shape
(32 per-layer instances rho-combined, N_inst ~ 5.6e6, ceiling margin
381x at T = 512 per the Section 4 table).

- New math: NONE. Each wave is the existing ct-round at its existing
  parameters; the descent consumes claims from k waves instead of 1.
- Engine work: the as-built engine ties one descent to one round
  [ENGINE refactor, the real cost of this option].
- Overhead [MODEL]: per-wave g-mask fixed cost (~52 g-commitments per
  ~113-commitment wave, as in the block round today) — ~21 waves per
  layer instead of 5,526 block rounds; per-element fixed costs drop
  ~260x. Lookup material amortizes to the designed ~1e-4 dce/el class;
  per-instance masked transcript (~38 KB/block today) becomes ~38 KB
  per WAVE plus one descent — MB-class per pass instead of 6.3 GiB
  [MODEL, to be counted canonically per audit Phase 3].

### Option (a), complement: q46 wave bundles

The gadget study's re-derived table shows C2 stops binding at q46: 256-
commit bundles hold 12.8 bits of headroom (vs FAIL at 64 commits at
q31), at x1.03 CPU per committed element and x1.38 commit-stream bytes.
A per-layer instance is ~344 commitments at msg_r 32 — inside the
demonstrated range. But q31-native values committed at q46 need the
modulus link PER COMMITMENT GROUP to ground the descent algebra (the
planes get this today; m/masks/blinders would newly need it), so this
option adds link volume and cross-modulus surface. Keep it as the
fallback if the multi-wave engine refactor stalls, and as the natural
home for material that is ALREADY q46 (while any remains).

## 3. The range-lookup rung, fully priced (audit Phase 5.2)

Replace per-bit planes + ARP with lookups into a range table [0, 2^w)
using the E3/E4 machinery the SiLU lookup already exercises (the SiLU
lookup was built as this option's 1/50th-volume pilot; M4 Section 7).

What it removes, per range-proved element (all as-built, measured at
B = 1020 unless noted):
- 8 committed bit planes and their q46 wave share — the bulk of the
  582 dce/el and of the 82.8% pass-level bit fraction;
- the binary ct-claims and the ARP (masks, JL, reveals, restarts) —
  and with them the alpha/unit-capacity coupling entirely;
- the q46 ct-round verify share (~0.84 s per block round today).

What it adds:
- m columns: 32 x 2^12-row tables = 1.3e5 dce/pass ~ 2e-4 dce/el
  (Section 4 table row; ceiling margin ~100x at per-layer instances,
  N_inst gate <= 2^25 clears);
- lookup prover arithmetic: ~43 K-mults/el [MODEL]; the measured
  as-built lookup core is 10.8-10.9 us/el 1T scalar, ~2x better with
  U-K9's clean commit merged [measured, same box], 0.5-1 us/el
  kernel-grade [MODEL];
- committed+masked overhead: measured 6-9x over the unmasked core AT
  B = 1020 — dominated by per-block fixed material; at per-layer
  instances this factor is modeled ~1-1.5x [MODEL — the pilot's key
  measurement];
- per-instance transcript and pins (fixed, amortized at per-layer).

Soundness/ZK deltas, both directions: the lookup range argument is
EXACT (no SLACK_OP = 512 approximate-extraction slack, no wrap side
condition), which STRENGTHENS the range fact the scale equation
consumes (relevant to audit C-03a). Against that, the log-derivative
ceiling requires the instancing discipline (counts mod q — Section 4
rules, derive-time gated), and the masked-lookup HVZK grade must carry
over to range tables (same machinery, same lemmas; the table is public
either way).

Net effect [MODEL, both walls stated]: the range side's committed
material falls from 582 dce/el to the ~1e-2 dce/el class (m columns +
amortized masks), i.e. the pass commit bill's 82.8% bit fraction
collapses — better than the Section 7 flag's conservative 2-4x
estimate, which assumed planes survive elsewhere; prover time for the
range side falls from the ~10 ms/el class (pre-restart-fix, B = 1020,
[NOISY-SHARED]) to the ~15-50 us/el class (committed masked lookup at
per-layer instances). BOTH claims are conditional on Section 2 landing
first; at B = 1020 the fixed-cost factor eats most of the win.

What this does NOT fix: the 256 KiB proof-byte and 2 s verifier budgets
need succinct aggregation across instances/layers (audit Phase 5.4-5.5)
regardless of range strategy; and the Phase 1-3 security boundary work
(secret masks, independent verifier, typed statements) remains the
critical path in front of ANY integration tranche.

## 4. Proposed tranche (U-R), in order

1. U-R1 [ENGINE]: multi-wave single-descent per layer (Section 2b)
   behind the existing chain battery; differential vs the blocked
   chain; freeze row for the wave-count/binding order.
2. U-R2 [PILOT]: one range-lookup width in the live chain — replace
   X's planes+ARP with a 256-row [0,256) lookup (w = 8, int8), keep
   the rest of the chain fixed; A/B the marginal exactly as A-D2 did;
   the committed+masked-at-scale factor is the number to capture.
3. U-R3 [DOCS/LADDER]: Section 7'/7'' + LLM_SCALE_ESTIMATE
   reconciliation, freeze rows, quiesced ladder re-measure; re-run the
   GPU_GO_NO_GO range gate with measured numbers.

Decision inputs this study leaves open, honestly: the multi-wave
engine refactor's size (U-R1 must be scoped against ring/gkr + descent
plumbing before committing the tranche), and whether rescale-remainder
ranges (Phase 4's requantization edges) fit the same table widths —
they should (w <= 12 chunks), but the statement typing work decides.
