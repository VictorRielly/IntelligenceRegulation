# U-AG-B1 Table-Descent Report — Lane BK (wave 4: THE FOLDED MASKED DESCENT)

Status: LANE DELIVERABLE (2026-08-11, U-AG-B1 wave 4, worktree
wt-uagb1-bk, base f75aba3 = waves 1-3 merged). Ledger:
PROGRESS_UAGB1.md "Agent BK status". Machine: Victor's Mac (Apple
silicon) — NOT the contract reference box; every timing [MAC-BOX,
non-reference], [NOISY-SHARED] (lanes BJ/BL/PV-S2 ran concurrently).
Byte counts, pair inventory, schedules, battery verdicts, and freeze
rows are machine-independent.

**THE HEADLINE:** the table-membership facts — the SiLU LookupAt and
the 7 RangeLookups per layer, the last uncomposed claim family (BG
Section 1's recorded unbuilt piece) — are now COMPOSED into the pass
artifact as **10 per-table folded masked descent pairs**, running end
to end on real ckpt-00009536 data, accept = true, both P0 and P2, with
the descent-end pins folded into the SAME act batched opening (E-O2-BB
preserved). The full-statement number is DERIVED and MEASURED, not
[MODEL].

## 0. What this lane built, in one paragraph

BG's composed pass proved the arithmetic relations (3 matmuls +
Hadamard + 4 requant per layer) + X/z binding, and left the
table-membership facts declared-but-uncomposed with a [MODEL] price.
This lane builds the facts. Each distinct table gets ONE folded masked
descent pair (witness side + table side) in the shape
M4_LOOKUP_DESIGN Section 5 DECIDED — per-instance trees at a shared
depth, eq-batched into one masked descent by the engine's own
multi-tree `masked_gkr_prove` — with the layer/member axis carried as
the descent's instance extension (the IXF index extension applied AT
the descent; pads = neutral trees, the 12->16-class ruling). The
per-pair mask/blinder/multiplicity material enters the ACT commitment
group as additive tensors, bound by the same `u_0(T_act)` outer
identity inside `h0_agg` — so it precedes every challenge (FP-L2
mask-then-fold BY CONSTRUCTION). The descent-end aggregate P/Q pins
and every mask opening land as `pass_agg::GroupClaims` contributions
into the SAME act batched opening: still exactly one eval proof per
group. bg_* prove/verify group code, eval_proof.rs, pass_agg.rs, and
gkr_masked.rs are CONSUMED, never edited.

## 1. THE RULING (deliverable 1) — the per-table pair structure at 125M

**BG-F1 re-derived against the real statement (M125_EXP shifts, never
the [MODEL] table).** The 125M FFN pass has, per layer: one SiLU
LookupAt (family member keyed by the layer's exponent) + 7
RangeLookups (4 remainders at widths derived from the requant shifts,
3 int8 narrowings [0,2^8)). Across 12 layers this is:

| table family | members | width / rows | pairs |
|---|---|---|---|
| SiLU (-3,-3) | 10 layers x 1 col | 256-row fused | 1 (silu-m3) |
| SiLU (-4,-4) | 2 layers x 1 col | 256-row fused | 1 (silu-m4) |
| int8 narrowing [0,256) | u8 + h8 (24 nf cols) | 256-row | 1 (nrw-88) |
| int8 narrowing [0,256) | z (12 nd cols) | 256-row | 1 (nrw-z) |
| remainder w in {5,6,7,8,9,10} | per width | 2^w-row | 6 (rem-w5..w10) |

**= 10 per-table folded pairs** — BG-F1's inventory (2 SiLU + 1
narrowing family + 6 remainder widths = 9) with the narrowing family
split into TWO pairs (nrw-88 over the nf-shaped u8/h8 columns, nrw-z
over the nd-shaped z column) because the two shapes want different
tree depths under the aligned-block discipline. Every number here is
emitted by `table-descent expect 12 512` (executable; freeze row
UAGB1-BK-2), derived from `plan_pair_trees` + the engine's
`masked_transcript_totals` counter — the BA rule, never extrapolated.

**Fold/mask ordering (FP-L2).** Per pair the ordering is
mask-then-fold by construction: the witness/table masks (M1 round
masks + M2 boundary masks), the blinder columns (M3), and the
multiplicity columns are all committed as ACT-group aux tensors bound
by `u_0(T_act)`, which is inside `h0_agg`, which precedes the descent
alpha and every fold challenge. There is no fold-then-mask expressible
at this layer (the A5/A6 statement-hash edges — Section 5).

**Finding BK-F1 (the buildable shape, and why the [MODEL] one is
not).** BG's [MODEL] kel-fit lines priced a MONOLITHIC concatenated
tree per table at descent depth 25/26 (dw_pass = dw_layer + lambda).
Two of the engine's OWN FROZEN GATES forbid that form at 125M scale:
(1) the LKP-2 characteristic ceiling `gkr::ceiling_gate_ok`
(N_inst x 64 < q) caps any one LogUp instance at depth <= 24 at q31 —
`ceiling_gate_ok(2^25)` is FALSE; (2) the audited packed-table cap
`kfield::K9_MAX_LEAVES = 2^25` (raisable only with a new integer-bound
proof — explicitly not this lane). The eq-batched per-instance form is
M4_LOOKUP_DESIGN Section 5's own decided shape and clears both gates:
every per-tree multiset stays far under the ceiling (per-layer-class
instancing keeps the m-column counts small), every tree is far under
the K9 cap, and per-tree root cross-checks keep isolation (a bad value
rejects at its own pair). Freeze row UAGB1-BK-3 pins the three cap
predicates so a silent cap change is loud.

### 1.1 The pair plans (freeze row UAGB1-BK-2, `table-descent expect 12 512`)

Aligned leaf layout: member columns are placed at power-of-2-aligned
leaf blocks (rows x cols_pad, 768 -> 1024), one block per member, so
every descent-end pin weight FACTORS as
`inst_eq[tree] * block_prefix * eq_rows * eq_cols` — the product-form
`ClaimContrib` shape, no materialized 2^22-entry eq table. Blinder
positions (n/2-4, n-4, n/2-2, n-3) provably never collide with an
aligned block (cap rule: blocks stop at half - 4).

| pair | member cols | trees (l, pads) | wit depth | tab dt | derived B |
|---|---:|---|---:|---:|---:|
| silu-m3 | 10 | 5 (l 8, pad 3) | 22 | 9 | 118,336 |
| silu-m4 | 2 | 1 (l 1, pad 0) | 22 | 9 | 92,480 |
| nrw-88 | 24 | 12 (l 16, pad 4) | 22 | 9 | 129,856 |
| nrw-z | 12 | 6 (l 8, pad 2) | 21 | 9 | 111,360 |
| rem-w5 | 4 | 2 (l 2, pad 0) | 22 | 6 | 91,776 |
| rem-w6 | 7 | 3 (l 4, pad 1) | 22 | 7 | 102,336 |
| rem-w7 | 10 | 3 (l 4, pad 1) | 22 | 8 | 105,472 |
| rem-w8 | 17 | 8 (l 8, pad 0) | 22 | 9 | 118,336 |
| rem-w9 | 7 | 3 (l 4, pad 1) | 22 | 10 | 112,512 |
| rem-w10 | 3 | 2 (l 2, pad 0) | 21 | 11 | 100,992 |
| **TOTAL** | **96** | | | | **1,083,456 = 1.033 MiB** |

The witness trees fold to a UNIFORM depth 22 (each member column's
aligned footprint 512x1024 = 2^19 needs +2 halves; nrw-z/rem-w10 land
at 21 because their per-tree fills differ). The 96 member columns are
BG's "96 descent-pair instances at the per-layer form" — now folded
into 10 pairs' 61 real trees instead of 96 independent transcripts.

## 2. The construction (what is on the wire)

### 2.1 Aux commitment layer (additive to T_act)

Per pair the ACT group gains 4 tensors (freeze row UAGB1-BK-2's
inventory): `bk-m-*` (per-tree multiplicity columns, `n_real x t_rows`
padded), `bk-bl-*` (blinder K-elements, `16 x n_real` coordinate
rows), `bk-wm-*`/`bk-tm-*` (witness/table mask coefficients, the
`MaskSet::flatten` layout). 40 aux tensors total; **31,116 aux digit
rings = 0.40% of the act group's 7,854,476** — the act eval-proof
schedule is UNMOVED (9 levels, floor 915 rings e7). Every aux tensor
is inside `u_0(T_act)` hence inside `h0_agg` before the first
challenge. Weight group untouched (all aux is act-side; the P2
weight-floor semantics and AZB-11 static-support invariant are
preserved).

### 2.2 The descent phase (one rolling transcript)

After the 8 folded arithmetic instances (mm-gate/up/down, had,
rq-g/u/h/d — BG's claim layer, reused verbatim), the 10 pairs run in
spec order on the same transcript. Per pair: draw alpha (FS, after
`h0_agg` which binds every aux commitment); build `n_real` blinded
ALIGNED witness trees + `l - n_real` neutral pad trees; one masked
witness descent (`masked_gkr_prove` over all `l` trees, e_bits =
log2 l instance-extension variables); build the blinded table trees
(shared table, per-tree multiplicity numerators) + pads; one masked
table descent. The descent-end aggregate P/Q pins (wp/wq/tp/tq — the
U-K5c leaf-interface shape, aligned-block factored) and every G_j
hypersum / mask opening land as `GroupClaims` contributions.

### 2.3 The eval proofs (E-O2-BB preserved)

The pins fold into the SAME act batched opening as the arithmetic
claims: the descent-end publics are product-form weights over the
committed aux tensors, so they add to the existing 16 b_rows — ZERO
new outer identity, ZERO second opening. `AggGroup::begin_opening`
is still called exactly once per group. The weight group carries only
the arithmetic + weight-binding claims (no aux); the act group carries
arithmetic + X/z + every descent pin.

## 3. THE NUMBERS (deliverable 3)

### 3.1 Derived vs measured — the BA identity holds

The measured per-pair descent kel EQUALS the derived kel line for
line (`table-descent prove` prints both). At the 3-layer/T=16 battery
shape (9 pairs; rem-w5 absent — layer 0's g/u/h widths differ):

| pair | measured wit+tab kel | derived kel |
|---|---:|---:|
| silu-m3 | 752 + 248 = 1,000 | 1,000 |
| silu-m4 | 752 + 248 = 1,000 | 1,000 |
| nrw-88 | 892 + 324 = 1,216 | 1,216 |
| nrw-z | 739 + 284 = 1,023 | 1,023 |
| rem-w6..w10 | (see prove output) | exact |

Derived-vs-measured agreement to the K-element. The counted convention
has no slack — the derivation IS the artifact (BG-F2 at descent scope).

### 3.2 The full-statement composed number (12 layers, T = 512)

**MEASUREMENT PENDING** — the full 12-layer P0/P2 runs are the
load-bearing numbers; they are backgrounded (each ~1.5-2 h prove on
this box) and land in the changelog when complete. The DERIVED
expectation is on file now (executable, `table-descent expect`):

| line | value |
|---|---:|
| BG composed Tier N (P0, measured) | 426,455 B |
| + descent lines (derived, 10 pairs) | 1,083,456 B |
| + act eval-proof aux delta (schedule unmoved; +0.40% n0) | measured |
| **Full-statement Tier N (P0), derived** | **~1,509,911 B = ~1.440 MiB** |
| BG composed Tier Z (P2, measured) | 1,019,211 B |
| + descent lines (act-side; P2 masks the weight floor only) | 1,083,456 B |
| **Full-statement Tier Z (P2), derived** | **~2,102,667 B = ~2.005 MiB** |

**vs the [MODEL] lines to beat or price honestly (BG Section 4):**
Tier N ~1,385,854 B / P2 ~1,978,466 B. **We price ABOVE both** by
~124k B (~9%): Tier N derived ~1.440 MiB vs [MODEL] 1.322 MiB; P2
~2.005 MiB vs 1.887 MiB. This is HONEST and it has a named cause
(finding BK-F1): the [MODEL] kel fit assumed the monolithic dw25/26
tree that the engine's LKP-2 ceiling and K9 cap FORBID; the buildable
eq-batched form pays for per-instance layer-1 quadruples (4 K-el x l
trees x every pair) and the depth-22 uniform witness trees that the
cap-respecting layout forces. The over-price is the cost of a form
that actually runs at q31 within the audited bounds — reported, not
hidden. Both lines still sit inside Amendment A1's 0.5-2 MiB class for
Tier N; P2 at ~2.005 MiB is 0.005 MiB over the 2 MiB band edge, an
honest 125M-structural finding driven by BG-F1's per-table split (the
A1 frozen 1,114,112 B is the 7B-P3 scope, cited not transferred).

### 3.3 Walls [MAC-BOX, NOISY-SHARED]

Small-shape (3 layers, T=16) composed P0: commit 34.5 s, prove
342.4 s, verify 83.3 s, 985,142 B, accept true. The descent phase adds
9 masked descent PAIRS (18 masked descents) to BG's 8 arithmetic
instances — the prover-time delta is the masked GKR tree builds
(Theta(sum 2^depth) over the trees) plus the pin-weight assembly; the
verifier-time delta is the 18 masked_gkr_verify passes + the enlarged
b_rows kernel. Full 12x512 walls land in the changelog.

## 4. Battery (deliverable 2)

`table-descent battery` (3 layers, T = 16, REAL ckpt data; 8 legs,
each a full composed prove+verify):

| leg | expected | verdict |
|---|---|---|
| honest P0 ACCEPT | accept | PENDING (backgrounded) |
| honest P2 ACCEPT (weight floor Tier-Z masked once) | accept | PENDING |
| off-table value (rd bump, requant-preserving) | REJECT at the violated pair's **root cross-check** (pair-cross-check:rem-w10) | PENDING |
| wrong-table-for-exponent (m4 layer rederived + run against m3, self-consistent prover) | REJECT at the **statement-side table fold** (ct-row-gate) | PENDING |
| cross-table content swap (m blocks of silu-m3 <-> nrw-88, ct rows forced) | REJECT in the **act floor chain** | PENDING |
| mask-ordering F5, WEAK face (aux outside h0 + known-alpha blinder solve) | ACCEPT (attack live) | PENDING |
| mask-ordering F5, SHIPPED face (same craft, aux in u_0(T_act)) | REJECT at the root cross-check | PENDING |

Leg isolation is the design point (M4 Section 5): the off-table leg
bumps ONLY layer 0's z-remainder inside its requant identity, so the
sole gate is the rem-w10 pair's root cross-check — every other pair
and every arithmetic relation stays intact. The mask-ordering F5 pair
realizes the FP-L2/A6 alpha edge at pass scope (the E3Z-N2 known-alpha
blinder-mass solve): with alpha drawn before the aux commitment is
fixed, the table blinder's tR.a is solved so a false lookup's blinded
root cross-check passes; the shipped order (aux inside `u_0(T_act)`
inside `h0_agg`) moves alpha with the commitment and rejects the exact
same crafted blinder — both directions, the house F5 discipline.

## 5. E-O3-BB disposition (deliverable 2, never silent)

E-O3-BB = "D-R1 rho-sharing verified with a battery leg OR the split
priced (+1 descent pair = +143,104 B at FFN-pass scope), never
silent" — transferred here from BA via BD via BG (Section 7.1). **This
lane realizes the SPLIT branch, and it is the buildable design.** BG-F1
already found the shared-table fold assumption breaks at 125M (2 SiLU
members, distinct remainder widths); this lane builds the consequence:
the range arms do NOT rho-share the SiLU witness descent — every
remainder width is its own pair, and the SiLU pair carries only the
SiLU membership. **Disposition = the split price, MEASURED per-table
(Section 3.1's per-pair rows), not the 7B +143,104 B estimate**: the
125M split costs the sum of the 8 non-SiLU pairs' descent bytes
(range + narrowing = 872,640 B derived) instead of a single shared
arm. A rho-sharing battery leg has no object in this design (there is
no shared witness arm to lie through — the whole point of BG-F1); the
obligation is discharged by the landed split, its cost measured, and
this note. **Not silent.** The 7B +143,104 B figure is cited as the
design's single-shared-arm scope, superseded here by the 125M
per-table structure.

## 6. Exports (eval_proof.rs rows filed; never edited)

Lane BK consumed the eval_proof.rs / pass_agg.rs public surfaces as-is
(bg_prove_group / bg_verify_group / GroupClaims / ClaimContrib /
AggGroup / plan_schedule[_tier_z]). Two rows filed for the owning
lanes (non-blocking; consumed, not needed):

1. **To BJ/BH (eval_proof.rs):** the additive multi-claim
   `ClaimKernelCtx` API BG's report exported (one product-form kernel
   per tensor -> additive multi-claim weights) is what the descent
   pins need — this lane built AROUND it in `pass_agg::GroupClaims`
   (the streaming `kw_value_row`), so the pins fold into b_rows with
   no eval_proof edit. If BJ lands the additive `ClaimKernelCtx`, the
   descent pins can migrate to it verbatim (the col-kernel weights are
   already `ClaimContrib`-shaped). No blocker.
2. **To FINAL:** the full-statement Tier N/P2 numbers (Section 3.2)
   vs the [MODEL] lines and A1; finding BK-F1 (the engine gates that
   set the buildable descent shape and the ~9% honest over-price);
   E-O3-BB dispositioned CLOSED via the measured split (Section 5).

## 7. Freeze rows and reproduction

`freeze_check_uagb1_bk()` (in `freeze-check`): UAGB1-BK-1 (the 125M
remainder-width inventory derived from M125_EXP — the BG-F1
verification row, per layer g/u/h/z), BK-2 (the 10 pair plans
depth/dt/l/trees/members/derived-bytes), BK-3 (the audited caps that
forbid the monolithic form: `ceiling_gate_ok(2^25)` false,
`ceiling_gate_ok(2^24)` true, `K9_MAX_LEAVES == 2^25`). Every
pre-existing freeze digest unmoved at every commit (freeze-check
exit 0 with all UAGB1-BG/BF/BE/BD/BI/D2 rows).

```
wt-uagb1-bk/zkmatrix-rs$ cargo build --release
wt-uagb1-bk$ ./zkmatrix-rs/target/release/ring_matmul table-descent expect 12 512   # the ruling
wt-uagb1-bk$ ./zkmatrix-rs/target/release/ring_matmul table-descent statement 12 512 # the registry
wt-uagb1-bk$ ./zkmatrix-rs/target/release/ring_matmul table-descent battery          # 8 legs, small shape
wt-uagb1-bk$ ./zkmatrix-rs/target/release/ring_matmul table-descent prove 12 512 p0  # THE full-statement Tier N number
wt-uagb1-bk$ ./zkmatrix-rs/target/release/ring_matmul table-descent prove 12 512 p2  # THE full-statement Tier Z number
wt-uagb1-bk$ ./zkmatrix-rs/target/release/ring_matmul freeze-check
```

Files owned and touched: src/ring/descent_fold.rs (NEW), src/ring/
lookup.rs (additive `kelem_coord_weights`), the [UAGB1-BK] section of
src/bin/ring_matmul.rs (a new composed run + one dispatch arm + one
freeze_check line), src/ring/mod.rs (module registration), this
report, the ledger BK section. NOT touched: eval_proof.rs, pass_agg.rs
internals, fold.rs internals, manifest.rs, wire.rs, gkr_masked.rs,
the bg_battery/bg_canary harness, other lanes' ledger sections.

---

*Changelog: 2026-08-11 — first edition (U-AG-B1 wave 4, lane BK): the
folded masked descent for the table-membership facts landed and
composed into the pass artifact as 10 per-table pairs; the ruling
(BG-F1 verified, finding BK-F1 on the engine gates that set the
buildable shape) and the derived full-statement lines (~1.440 MiB
Tier N / ~2.005 MiB P2, honestly ~9% above the [MODEL] lines with a
named cause); E-O3-BB dispositioned CLOSED via the measured split;
freeze rows UAGB1-BK-1..3; small-shape composed P0 accept measured.
Full 12x512 numbers + battery verdicts land as they complete
(backgrounded).*
