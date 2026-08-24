# U-PERF3 spike S1 / S2 — range facts as booleanity zero-checks; SiLU LogUp as one sumcheck (lane S)

Status: COMPLETE (2026-08-23, U-PERF3 round 1, lane S, worktree
wt-uperf3-s, branch uperf3-s, base d1d1963; opened 2026-08-18, resumed
and finished 2026-08-23). Ledger: PROGRESS_UPERF3.md "Agent S status".
Box: the WSL box (Intel Core Ultra 9 185H, 22 threads, 15 GB; default
CPU build, no GPU). The box was QUIET for every timing pass (checked
with `top` immediately before: 99.4% idle, 12.3 GB free, load 0.59).
Every number carries a label: [MEASURED]/[COUNTED]/[MODEL] and
[WSL-BOX 1T|8T QUIET].

Design memo: U_PERF3_OPENING_LAYER_DESIGN.md §2.2-2.4 (the batched
sumcheck; how the range facts and the SiLU lookup ride it), §5.1/§5.3
(assumptions; the spike definitions), §6.1. The frozen pass is the
ORACLE (the masked descent of gkr_masked.rs + the blinded tree builders,
the exact call sequence of bk_pass_run's descent phase), never the
patient — no engine file was changed by this lane; everything new is
additive (ring/zc_range.rs + the `[UPERF3-S]` bin section).

## 0. One paragraph — go / no-go per spike, with the measured ratios

**Both spikes are GO.** S1 (range facts -> digit-plane zero-check): at
the design's challenge field E_4 = GF(q^4), the zero-check over one
2^20-element remainder column is **13.5x cheaper in K-mult-equivalents,
13.7x fewer rounds, 49x fewer wire bytes** than the masked descent pair
as built at the representative width w = 8 (w = 4: 25.2x / 12.2x /
45x; w = 12: 9.2x / 16.0x / 56x) [COUNTED, exchange rate 256 base MACs
per K-mult] — clearing the memo's acceptance line (>= 5x equivalents,
~10x rounds) at every width. The measured wall is 1.6x faster at 8T
(1.0x at 1T) at w = 8 [MEASURED WSL-BOX QUIET] — the counted lever is
real but the spike's prototype E_4 kernel runs ~8x below the frozen K9
kernel's MAC throughput, so most of the counted 13.5x is still on the
table as kernel engineering, not protocol cost. S2 (SiLU LogUp as one
sumcheck): the descent-form claims and the LogUp-as-sumcheck claims are
**EQUAL at fixed seeds** (four asserted K-field equalities, Section 3),
with **13.7x fewer rounds (274 -> 20), 15.7x fewer wire bytes, and a
1.9x (1T) / 1.2x (8T) faster prove wall including the helper-h build**;
the h overhead is 64 MiB of committed base values per 2^20 column
(rides the ACT eval proof) and 0.13-0.15 s to build. Batteries: 48
legs green with one digest byte-identical at ZK_THREADS 1/2/7,
including byte-identity of the new prover at c = 16 against the frozen
`ixf_sumcheck_prove`; `uperf-pc diff-battery` green; freeze-check green
in its WSL form (98 ok rows, then the expected panic at the UAGB1-BF
m125-export rows).

## 1. What was built (files / functions; what is reused from the frozen code)

New files/sections (everything additive, nothing shipped is changed):

- `zkmatrix-rs/src/ring/zc_range.rs` (NEW, ~1380 lines):
  - `SubExt` — the sub-extension E_c = GF(q^c) realized INSIDE
    K = GF(q^16) as Z = Y^(16/c) (coordinates at stride 16/c), c in
    {4, 8, 16}: mul/inv/uniform/transcript draw with the house K
    encoding. At c = 16 the arithmetic, the XOF positions, and the
    absorb bytes are EXACTLY the frozen K path (battery leg A pins it
    byte-for-byte). Per-element cost: an E x E multiply is c^2 base
    MACs against K's 256.
  - `zc_range_prove` / `zc_range_verify` — the S1 zero-check
    sum_x eq(rho, x) [ sum_k beta_k f(d_k(x)) + beta_rec (r(x) - sum_k
    2^(e0 k) d_k(x)) ] = 0 over one column's committed digit planes,
    with the prover TABLES in the base field until the first fold and
    every challenge in E_c. The digit constraint f is the house
    alphabet's vanishing polynomial (`ring::digits::alphabet`:
    sign-binary {-1,0,1} at e0 = 1, deg_f = 3; balanced base-4 {-2..1}
    at e0 = 2, deg_f = 4). Kernel discipline mirrors K9: lane-blocked
    SoA tables, split lo/hi u64 planes, one special-form reduction per
    coordinate, persistent lazy node accumulators summed in index order
    (bit-identical for any ZK_THREADS — verified by the battery digest
    at 1/2/7). The eq factor is never folded: eq(rho_t, X) is a
    per-round scalar and the eq table over unbound variables is an
    even-lane compaction (no arithmetic), the descent kernel's own
    trick.
  - `zc_range_prove_oracle_k` — the same zero-check on the FROZEN boxed
    prover (`fold.rs ixf_sumcheck_prove` with the RLC combine): the
    c = 16 differential oracle.
  - `zc_range_open_check` — the spike's stand-in for the eval proof:
    every final equals the MLE of its committed table at the sumcheck
    point.
  - `logup_sumcheck_prove` / `logup_sumcheck_verify` — S2: the LogUp
    well-formedness sum_x eq(rho, x) [h(x)(alpha - key(x)) - 1] = 0 run
    VERBATIM on the frozen packed Had prover
    (`fold.rs ixf_sumcheck_prove_packed`, `IxfCombine::Had`, tables
    [eq, h, alpha - key, 1]) — the claim layer's own kernel; h built
    from the 256 table-row inverses; plus the two sums h_sum /
    table_sum (the LogUp identity in sum form).
  - `masked_descent_kmuls` / `masked_pair_kmuls` / `MACS_PER_KMUL` —
    structural K-mult counters for the frozen masked descent as built
    (3 K-mults per pair-term per evaluated node in the fused round
    kernel, the 5-table folds, the eq doubling, the tree build with the
    c=2 checkpoint recompute; MACS_PER_KMUL = 256 is the 16x16 lane MAC
    of kfield.rs).
- `zkmatrix-rs/src/bin/ring_matmul.rs`, `// [UPERF3-S]` section +
  `uperf-s` dispatch arm: `s1 | s2 | battery | count`, threads/shape/
  seed as ARGS (ZK_THREADS set programmatically at arm entry before
  any pool initializes), and `uperf_s_descent_pair` — the descent
  ORACLE leg reproducing bk_pass_run's per-pair call sequence:
  alpha as the first transcript challenge, `blinded_witness_tree`
  (the BF-F3 split leaf layout) at depth n_log2+1, `blinded_table_tree`
  at dt with honest multiplicities, the table blinder mass solved to
  the witness's (`solve_mass` — the modified root cross-check
  condition), `masked_gkr_prove` on both sides, pinned
  `masked_gkr_verify` on a fresh transcript.

Reused frozen machinery (read-only): gkr_masked.rs (trees, masks,
masked descent prove/verify, `masked_transcript_shape`), gkr.rs
(FracTree, `root_cross_check`, `eq_eval`), fold.rs (both ixf provers,
the Had combine, `ixf_sumcheck_verify`), kfield.rs (K arithmetic, the
packed tables, the thread pool), lookup.rs (silu-int8-table-v1,
`fuse_pair`, `fused_silu_table`), digits.rs (the alphabet), sumcheck.rs
(LkpTranscript, mle_eval).

## 2. S1 — the range facts: method, counts, measurements

**Method.** One synthetic 2^20-element remainder column at fixed seeds,
rem uniform in [0, 2^w), with its w committed digit planes (the bits of
rem — a valid sign-binary digit vector, so the instance is honest under
the house alphabet AND every key lands in the [0, 2^w) range table).

(a) the descent side, as built: ONE masked descent pair per column —
blinded witness tree over the embedded remainders at depth 21 (2^20
keys need capacity n - 8), the [0, 2^w) range table at depth w + 1
(the split-layout blinders push a full 2^w table one level deeper),
l = 1, honest multiplicities, both descents masked and verified with
pins. This is bk_pass_run's per-pair call sequence; the real pass packs
several member columns per pair (l up to 16 at depth 22), with the same
per-leaf cost — the structural counter gives 24 K-mults per leaf here
vs the pass's measured-derived ~23 per leaf (5.5e9 K-mults / 239M
leaves incl. pads, design memo §1.1), so the single-pair shape is a
faithful per-column stand-in [COUNTED].

(b) the zero-check side: the w digit planes + the recomposition tied to
the SAME committed column, one aggregate sumcheck of 20 rounds under
challenges in E_c, verified, and the finals checked against the
committed tables' MLEs (`zc_range_open_check`, the eval-proof
stand-in).

Comparability: the descent "wall" below is trees + prove (the
column-marginal work the zero-check removes); both sides exclude their
verify and their eval-proof/opening leg (the descent's pins and the
zero-check's finals both ride the pass's eval proof). Wire bytes count
4 B per base coordinate on both sides (a K-element = 64 B).

**Counts and measurements at 2^20** (each cell: descent pair -> zero-
check; K-mult-equivalents at x256; box QUIET):

| w | side | K-mult equiv [COUNTED] | rounds [COUNTED] | wire B [COUNTED] | wall 1T [MEASURED] | wall 8T [MEASURED] |
|---|------|------------------------|------------------|------------------|--------------------|--------------------|
| 4 | descent pair (depth 21 + dt 5) | 50.33M | 244 | 76,288 | 1.70 s | 0.56 s |
| 4 | zero-check E_4 | 2.00M (**25.2x**) | 20 (**12.2x**) | 1,680 (**45.4x**) | 0.800 s (**2.1x**) | 0.172 s (**3.2x**) |
| 8 | descent pair (depth 21 + dt 9) | 50.34M | 274 | 86,272 | 1.66 s | 0.55 s |
| 8 | zero-check E_4 | 3.73M (**13.5x**) | 20 (**13.7x**) | 1,744 (**49.5x**) | 1.710 s (1.0x) | 0.334 s (**1.6x**) |
| 12 | descent pair (depth 21 + dt 13) | 50.53M | 320 | 100,352 | 1.69 s | 0.55 s |
| 12 | zero-check E_4 | 5.47M (**9.2x**) | 20 (**16.0x**) | 1,808 (**55.5x**) | 2.025 s (0.8x) | 0.456 s (**1.2x**) |

The c-dependence at w = 8 [COUNTED equiv / MEASURED 8T wall]: c = 4:
13.5x / 0.334 s; c = 8: 3.9x / 0.905 s; c = 16: 1.0x / 2.947 s. c = 16
IS the frozen K arithmetic (and is byte-identical to the boxed oracle),
so the entire lever is the sub-extension: the E x E round work scales
as c^2 while soundness needs only c >= 4 (~2^-120 per round, memo
§2.6). The first round is cheaper still (base x base tables — the
prover tables lift to E_c only at the first fold).

**Acceptance (memo §5.3: >= 5x in K-mult-equivalents, ~10x fewer
rounds): GO at every width at c = 4** (weakest cell 9.2x equivalents at
w = 12; rounds 12.2-16.0x everywhere).

**The honest wall story.** The counted 13.5x (w = 8) nets only 1.6x of
measured wall at 8T because the two sides run very different kernels:
the descent runs the frozen K9 packed AVX2 lane kernel at ~23
GMAC-equivalents/s (8T, this box [MEASURED]), while the spike's
prototype E_4 round kernel runs ~2.9 GMAC/s (8T) — an ~8x
kernel-quality gap (staging copies, scalar extrapolation, no
hand-vectorization). The protocol-level cost is the counted column;
the wall is a floor, not a ceiling: a production E_4 kernel at K9's
MAC throughput would realize ~10x of the 13.5x [MODEL]. Two counted
upsides not taken here: (i) the spike used the house sign-binary
alphabet (deg_f = 3); the memo's {0,1} bit-plane booleanity (deg_f = 2)
cuts the round-node work by another ~1/3 [COUNTED]; (ii) the aggregate
of the real design batches MANY columns into ONE sumcheck (shared eq,
shared rounds) — the spike paid the eq build and the 20 rounds per
column.

Memory [MEASURED]: whole-process peak RSS 627-729 MiB for every run —
the (b) side alone holds the w+1 base tables (36 MiB at w = 8) plus
E-tables that halve each round (~2x the base tables at c = 4), i.e.
~100 MiB per 2^20 column, no trees. The (a) side builds the 0.5 GB
packed tree pair this replaces.

Verifier + opening [MEASURED 8T]: zero-check verify < 1 ms (20 round
checks + one G evaluation in E_4); the open-check stand-in 0.064 s
(w + 1 MLE folds — in the real design these finals ride the existing
per-group eval proof; the stand-in is not a cost of the protocol).

## 3. S2 — the SiLU lookup: method, equality evidence, measurements

**Method.** One SiLU column at 2^20: keys drawn (fixed seed) as fused
(x, S[x]) rows of the frozen `silu-int8-table-v1` (kappa = x + Y y,
`lookup::fuse_pair`), honest multiplicities. Both legs draw the SAME
alpha — it is the first challenge of a transcript at the same
(domain, seed) — so the claims are comparable K-field values.

(a) the descent, as built: blinded witness tree depth 21, the 256-row
fused table at depth 9, table blinder mass solved to the witness's,
masked descents, pinned verify (identical to S1 (a) but with fused
pair keys).

(b) LogUp-as-one-sumcheck: commit h_i = 1/(alpha - key_i) (built from
the 256 row inverses), then ONE degree-3 sumcheck of
sum_x eq(rho, x) [h(x)(alpha - key(x)) - 1] = 0 on the frozen packed
Had prover, plus the sum equality h_sum = sum_j m_j / (alpha - t_j)
(256 rows, closed form). rho is drawn after an h-commitment stand-in
absorb (in the real protocol the h and m commitments bind here).

**Which values are compared — the claims asserted EQUAL at fixed seeds**
(all K-field equalities, asserted in `uperf-s s2` at 2^20 and in
battery leg C at 2^10):

1. `P_w / Q_w - mass(bl_w) == h_sum` — the witness tree's derived root
   fraction, minus the witness blinder mass (sum a_k/u_k over the four
   blinder leaves), equals the sumcheck's witness-side sum
   sum_i 1/(alpha - key_i).
2. `P_t / Q_t - mass(bl_t) == table_sum` — the table tree's root
   fraction minus its blinder mass equals sum_j m_j / (alpha - t_j).
3. `mass(bl_t) == mass(bl_w)` — the completeness solve the pass runs
   (`solve_mass`), which is exactly why the blinded cross-check works.
4. `root_cross_check(P_w Q_t == P_t Q_w) <=> h_sum == table_sum` —
   both hold on the honest instance; i.e. the descent's root
   cross-check and the LogUp sum equality are the same fact in two
   forms.

Negative evidence (battery leg C): one off-table key (fuse of
(x, S[x]+1)) keeps the well-formedness chain (h_i is its own inverse)
and FAILS the sum equality — the descent's tamper leg in sumcheck
form; a multiplicity tamper (m_0 += 1) also fails the sum equality.

**Measurements at 2^20** [WSL-BOX QUIET]:

| | descent pair (a) | LogUp sumcheck (b) | ratio |
|---|---|---|---|
| rounds [COUNTED] | 274 | 20 | **13.7x** |
| wire bytes [COUNTED] | 86,272 | 5,504 | **15.7x** |
| K-mults [COUNTED] | 50.34M | ~14.9M | 3.4x |
| prove wall 1T [MEASURED] | 1.68 s (trees 0.40 + prove 1.27) | 0.869 s (h 0.154 + tables 0.156 + sumcheck 0.429 + opens 0.116) | **1.9x** |
| prove wall 8T [MEASURED] | 0.54 s | 0.440 s | 1.2x |

The h overhead [MEASURED]: 2^20 x 16 = 16.8M committed base values =
64.0 MiB raw per 2^20 column, built in 0.13-0.15 s; it rides the ACT
eval proof (commit-time cost, no separate transcript). What it buys:
no witness tree, no table tree (the 0.5 GB packed pair at this shape),
254 fewer round-poly objects, and the h claims fold into the one-point
opening. Acceptance (claims equal, rounds ~log N, h overhead < the
tree saving): **GO** — 20 = log2 N rounds exactly, and 64 MiB of
commit input vs ~0.5 GB of tree peak per pair.

## 4. The counted implication for the 12x512 shape and the 8B shape [MODEL]

Anchors from the design memo §1.1 (all [COUNTED]/[MEASURED] there): at
12x512 the descent phase is 10 pairs / 20 masked descents / 45 real
trees, 2,367 rounds, ~5.5e9 K-mults, 6.5 s of the 21.0 s pass
[8T+GPU], 1,083,456 B of the 1,509,911 B artifact; range/narrowing =
84 of 96 columns and 39 of 45 trees; the nrw-88 pair's 5.6 GB tree
peak was the pass's memory peak before lane H.

**descents 6.5 s -> ?** Splitting by fact class with the spike's
ratios: the range share (~85-87% of trees/rounds) leaves the descent
engine entirely — its counted work drops 9-25x (width-dependent; the
pass's widths 5-11 center near the w = 8 cell, ~13x) and what remains
is base-field zero-check MACs that fold into the claim layer's
existing aggregate (the requant instances already prove the
recomposition half; only the digit-plane booleanity terms are added).
The SiLU share (6/45 trees) becomes one sumcheck per instance at ~3.4x
fewer K-mults on the SAME frozen packed kernel. Net [MODEL]: the 6.5 s
descent phase collapses to ~1-2 s of equivalent work (SiLU sumchecks +
the added claim-layer terms) IF the zero-check kernel reaches
K9-class throughput; at the spike's prototype throughput the phase
would be roughly wall-neutral at 1T and ~1.5-2x faster at 8T
[MEASURED basis]. This is consistent with the memo's Stage-A whole-
pass model (~1.35x) — the spike CONFIRMS the counted lever (which the
memo's §3 model already assumed) and localizes the residual risk in
kernel engineering, not in the protocol.

**tree memory peak -> ?** The 39 range trees are gone — no witness
trees, no table trees, no 5.6 GB nrw-88 pair. The SiLU side keeps NO
tree either (S2 replaces its descent with the sumcheck); what appears
instead is the committed h (64 MiB raw per 2^20 column; the pass's 12
SiLU columns hold ~23M lookups -> ~1.4 GiB of h commit input at 12x512
[COUNTED], amortized into the existing ACT commit phase) and the
zero-check's table residency (~100 MiB per 2^20 column-equivalent,
transient per instance). The descent phase stops being the pass's
memory peak; the peak moves to the claim layer's existing table budget
(device-built, ~300 MB compact operands, memo §1.2) [MODEL].

**artifact -> ?** The descents' 1,083,456 B shrink by the spike's wire
ratios (45-56x for range pairs, 15.7x for SiLU): ~24 KB of aggregate-
sumcheck rounds replaces ~1.08 MB of descent transcript [COUNTED from
the spike's per-column bytes scaled by the pass's 10 pairs]. Artifact
1,509,911 B -> ~0.45-0.50 MB [MODEL] — the memo's ~3x, now with a
measured per-object byte basis.

**The 8B shape.** The descent work scales with activations (~x19,
memo §1.6); at 8B x 512 the phase as built would be ~2 minutes of
GPU descent and its trees would multiply the memory peak — while the
LKP-2 characteristic ceiling (N_inst x 64 < q) and the audited 2^25
packed-table cap force MORE pair splitting at 8B, i.e. the descent
route gets structurally worse with scale. The zero-check route escapes
both gates for the 84% range share (no LogUp instance at all — the
booleanity + recomposition argument has no characteristic ceiling and
no tree), and its cost rides the claim layer, which the 8B plan
already streams. The counted 9-25x on the range share and the S2
equality therefore carry to 8B unchanged [COUNTED/MODEL]; the h
commit input scales to ~27 GiB at 8B x 512 if every SiLU lookup
commits h naively (2^20 x 14336/2048-ish columns) — the design's
per-instance batching and the Mac's 256 GB absorb this, but it should
be priced in lane R's memory architecture [MODEL, flagged].

## 5. What is left / caveats — what the spike did NOT test

- **Kernel quality is the open wall risk.** The counted 13.5x (w = 8,
  c = 4) is measured-confirmed as counts, but the spike's E_4 kernel
  runs ~8x below K9's MAC throughput, so the measured wall win is
  1.6x (8T), not ~13x. Closing that is AVX2/GPU engineering on a
  simpler kernel than K9 (base-field MACs, no 16-wide reduction), and
  the first round is base x base — but it is unbuilt and unpriced
  beyond [MODEL].
- **Batching across columns was not exercised.** The spike ran one
  column per sumcheck (per-column eq build and 20 rounds). The design
  batches all range columns of an instance into ONE aggregate; the
  counted per-column advantage only improves, but the engineering
  (instance axis, shared eq, the claim layer's stacking) is Stage-A
  build work, not spike-verified.
- **The alphabet.** The spike used the house sign-binary planes
  (deg_f = 3) because those are the digits the tensor already commits;
  the memo's {0,1} booleanity (deg_f = 2) is ~1/3 cheaper again in
  round MACs [COUNTED] but needs the bit-granularity commitment the
  memo's subtlety (1) discusses (q46 remainders / U-L link). Untested.
- **Masking/ZK of the zero-check.** The spike's zero-check runs
  unmasked (the descent oracle side runs the full masked machinery).
  The memo's §2.6 argues the existing g-mask machinery transfers to a
  sumcheck; that transfer (O-4) is a Stage-A obligation, not
  spike-verified.
- **The one-point opening (Stage B / S3).** Untouched, as scoped: the
  finals here were checked against table MLEs directly; folding them
  into the per-group eval proof (and the r = 32 replan) is the memo's
  S3/Stage-B question.
- **1T wall parity at w >= 8 on this box** means a CPU-only 1T
  deployment gains rounds/bytes/memory but not wall until the kernel
  gap closes; the 8T (and any GPU) picture already favors the
  zero-check.
- Walls were taken on a QUIET box but this box has shown ~2x
  run-to-run variance under load historically; the ratios above were
  stable across the widths/threads matrix (six independent descent
  runs at 1.66-1.70 s 1T attest run-to-run stability during the
  pass), and every ratio is backed by a counted column that does not
  depend on the box.

Gates at close: `uperf-s battery` 48 legs ok, BATTERY DIGEST
3752cba4fa08c2ee052475e9f4459e2fc3ed0a0c59862468e0c31cbeb165aaae
identical at ZK_THREADS 1/2/7; `uperf-pc diff-battery` green (O1 4/4,
O2 35/35, O3 63/63, O5 12/12, E2E 2/2); freeze-check WSL form green —
98 rows ok, last ok row `UAGB1-BL-1d pass schedules unmoved by the
blind (+1728 rings): tierz L8 floor 1368 e4 (pins L8/1368/e4), bare L8
floor 939 e7 (pins L8/939/e7)`, then the EXPECTED panic at the
UAGB1-BF rows (no m125 export on this box).
