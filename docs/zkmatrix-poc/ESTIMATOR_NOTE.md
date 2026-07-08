# Q5 Estimator Sign-off: MSIS/MLWE Validation of the Frozen Route R Point

Status: **the frozen point HOLDS — no (kappa, N_r) movement is required.**
Every frozen shape clears 128-bit classical security on both the MSIS
(C3, binding) and MLWE (C4, hiding) sides, under BOTH an independent
core-SVP model and the real lattice-estimator. The design's stated fear
("expect tens-of-percent movement in kappa/N_r", ROUTE_R_DESIGN.md
Section 9 Q5 / ROUTE_R_BUILD_REPORT.md Section 2) did **not**
materialize: the measured movement requirement is **zero**, and the
slack runs in the safe direction (the C3 model is mildly conservative,
the C4 model very conservative). Two caveat-grade findings — a quantum
margin dip on three shapes and an integral-kappa bookkeeping gap in C4 —
are quantified below; neither forces a freeze change.

Sign-off grade: **estimator-validated (shimmed CPython run)**. The
genuine `lattice-estimator` executed here, in-process, under a
pure-Python `sage.all` shim that was validated against the estimator's
own published doctest outputs before any instance number was read
(Section 2). A native Sage re-run remains the zero-risk confirmation
step; exact commands in Section 8. If one insists on counting only
native-Sage output as "the estimator", then and only then this note is
PARTIAL — the commands to close that residue are provided.

Artifacts: `scripts/estimator_run.py` (the run; reruns end-to-end in
~3 min), `results/estimator_core_svp.txt` (full tables + sweeps),
`results/estimator_lattice_estimator.txt` (real-estimator log). Nothing
in existing source or docs was modified.

## 1. Source labeling (what produced which number)

Every figure in this note and in `results/` carries one of two tags:

- **[core-SVP]** — the self-contained model in `estimator_run.py`:
  BKZ block size b from the Chen asymptotic root-Hermite factor
  `delta(b) = (b/(2 pi e) * (pi b)^(1/b))^(1/(2(b-1)))`, attack cost
  `2^(0.292 b)` classical / `2^(0.257 b)` quantum (sieving, no
  dimensions-for-free, no memory cost — the conservative floor).
- **[lattice-estimator]** — github.com/malb/lattice-estimator, clone
  commit `3e48ef421ec256afddb3e7d2249a77eab6e9ba12`, run in-process
  under the shim of Section 2. Estimator algorithm code unmodified on
  disk; one disclosed runtime patch (Section 2). Two cost models per
  instance: **MATZOV** (the estimator's default, more realistic — larger
  numbers) and **ADPS16** (core-SVP `2^(0.292 b)`, for apples-to-apples
  comparison with the [core-SVP] leg).

Nothing here is a design-model (C3/C4) number presented as an estimate;
the design-model lines appear only in Section 5 where the two are
explicitly compared.

## 2. What actually ran: the shim, its validation, and the one patch

The lattice-estimator targets SageMath; `import sage.all` fails under
plain python3. Rather than fall back to a model-only note,
`estimator_run.py` registers a minimal pure-Python `sage.all` in
`sys.modules` (floats for RR/RDF/RealField, ints for ZZ, `mpmath` for
zeta and the chi-squared/Beta CDFs, bisection for `find_root`) and then
imports the UNMODIFIED estimator package from `tools/lattice-estimator`.

One runtime monkey-patch was required: `estimator.prob.amplify` computes
`ceil(log(1-target)/log(1-success))` at up-to-2048-bit MPFR precision;
under double precision `1 - success` rounds to `1.0` for
`success < 2^-53` and the division hits zero. The patch reimplements the
same formula via `log1p` (exact for doubles) and returns `oo` below
`2^-900`, where the repeat count is astronomical and the optimizer
discards the branch regardless. Disk code untouched; see
`patch_prob_amplify()`.

Shim validation, run before any instance (all three are the estimator's
own doctest outputs, reproduced EXACTLY — block size and cost):

| anchor | expected (doctest) | shim run |
|---|---|---|
| `LWE.primal_usvp(schemes.Kyber512)` | beta 406, rop 2^143.8 | beta 406, rop 2^143.8 |
| `SIS.lattice(n=113, q=2048, B=512, l2)` | beta 61, rop 2^47.0 | beta 61, rop 2^47.0 |
| `SIS.lattice(Dilithium2_MSIS_WkUnf)` (l-inf path) | beta 427, rop 2^152.2 | beta 427, rop 2^152.2 |

Independent cross-check: on all 10 Route R instances the
[lattice-estimator] ADPS16 numbers agree with the independently
implemented [core-SVP] leg to within one BKZ block (<= 0.3 bits) — two
implementations, one via the estimator's simulator machinery, one from
the closed-form model, landing on the same block sizes.

## 3. Instances (dimension conventions of ROUTE_R_DESIGN.md Section 3)

- **MSIS (binding, C3):** rank kappa over R_q -> Z-dimension
  `k_Z = kappa*128` rows, witness width `N_Z = N_r*128`, modulus q, l2
  length bound beta from the freeze's own norm chain
  (`route_r_params.py derive_q2` for the digit shapes;
  `ring_lattice.rs derive_sigma_params` for the prototype — the script
  self-checks its forward passes against both before running).
  Estimator call: `SIS.lattice(SIS.Parameters(n=k_Z, q,
  length_bound=beta, m=N_Z, norm=2))`.
- **The l-inf vs l2 subtlety, stated honestly:** the chain's beta is an
  l2 bound (sigma-, bound- and combination-terms are all l2), and the
  extracted MSIS solution is l2-bounded by it, so the instance is
  modeled in l2 — the norm the lattice attack natively optimizes. No
  hidden sqrt(m) inflation: a Dilithium-style l-inf analysis would
  additionally charge the attacker for fitting every coordinate under
  the bound (the `tag: infinity` path exercised in the validation
  anchor), i.e. l2 is the attacker-friendly, conservative choice here.
  Trivial q-vectors are excluded by C2 (q > 8 beta, >= 1.4 bits of
  headroom at every point, so beta < q strictly).
- **MLWE (hiding, C4):** BDLOP hiding in knapsack/normal form is MLWE
  with secret Z-dimension `n_sec = N_Z - (kappa + msg_r)*128`, exactly
  `m = (kappa + msg_r)*128` samples, ternary (uniform {-1,0,1}) secret
  AND error, stddev sqrt(2/3). [core-SVP]: primal uSVP embedding, 2016
  estimate `sigma sqrt(b) <= delta^(2b-d-1) q^(m/d), d = n_sec + m + 1`,
  optimized over used samples. [lattice-estimator]:
  `LWE.Parameters(n=n_sec, q, Xs=Xe=UniformMod(3), m)` under both
  `primal_usvp` and `primal_bdd`.
- `n_sec` uses the INTEGRAL rank actually deployed
  (`kappa = ceil(k_z/128)` rows of commitment matrix); the chain's own
  C4 check uses the raw pre-rounding `k_z` — the one place the two
  differ is flagged in Section 6.

Frozen instances (from `ring_matmul.rs freeze_check` and the
`ring_lattice.rs` prototype constants), at q8_31 = 2147483249, with
q8_46 = 70368744176561 as the fallback modulus (where kappa/N_r are the
chain's own re-derivation — candidates, not frozen values).

## 4. Results — the frozen point at q8_31

Classical bits; "MSIS/MLWE cl" = classical, "qu" = quantum `0.257 b`
applied to the same block size. The verdict column is against 128-bit
classical, the design's C3-implied target (see Section 5).

| shape (frozen kappa, N_r, msg_r) | log2 beta | MSIS cl [core-SVP] | MSIS cl [ADPS16] | MSIS cl [MATZOV] | MLWE cl [core-SVP] | MLWE cl [MATZOV, best] | min qu [core-SVP] | verdict (128 cl) |
|---|---|---|---|---|---|---|---|---|
| Pi2 2048^3 e=2 (8, 40, 16) | 25.13 | 143.1 | 143.1 | 168.9 | 193.3 | 215.7 | 125.9 | **PASS** |
| Pi2 2048^3 e=3 (8, 40, 16) | 25.55 | 136.7 | 136.7 | 162.8 | 193.3 | 215.7 | 120.3 | **PASS** |
| Pi2 2048^3 e=4 (9, 40, 16) | 26.13 | 151.3 | 151.3 | 176.8 | 177.8 | 200.9 | 133.1 | **PASS** |
| FFN 512x4096x11008 e=4 (9, 57, 32) | 26.64 | 143.4 | 143.4 | 169.3 | 193.3 | 215.7 | 126.2 | **PASS** |
| prototype opening (8, 26, 2) | 24.55 | 153.0 | 152.7 | 178.1 | 203.2 | 224.4 | 134.7 | **PASS** |

Readings:

- **MSIS is the binding side everywhere** (MLWE sits 26-57 bits above
  it). The tightest frozen point is Pi2 e=3 at 136.7 [core-SVP] /
  162.8 [MATZOV] — an 8.7-bit classical margin even under the most
  conservative cost accounting, 34.8 bits under the realistic one.
- The one sub-block disagreement between the legs is the prototype MSIS
  (core-SVP b=524 vs estimator b=523: 153.0 vs 152.7) — sub-dimension
  discretization, 0.3 bits, immaterial.
- **Quantum (0.257 b on the same blocks):** e=2 (125.9), e=3 (120.3) and
  FFN (126.2) dip below 128 QUANTUM on the MSIS side; e=4 2048^3 and the
  prototype clear it. The design's C3 model never targeted a quantum
  level (Section 5); if a 128-bit-quantum target is ever adopted, the
  fix is kappa + 1, costed in Section 6.

At q8_46 (fallback; chain-derived candidates kappa 5-6, N_r 31-62): all
five shapes PASS 128-bit classical — min side MSIS 133.7-163.2
[core-SVP] (159.6-188.3 [MATZOV]), C2 headroom 16-18 bits. Quantum
[core-SVP] dips below 128 at FFN (122.6) and the prototype (117.7).
Full tables in `results/estimator_core_svp.txt` and per-instance
estimator output in `results/estimator_lattice_estimator.txt`.

## 5. The C3/C4 design models vs the estimator (the "tens-of-percent" question)

**C3 (MSIS).** The model `k_Z >= (log2 beta / 2)^2 / (log2 q *
log2 delta0)` with `delta0 = 1.0037` (LOG2_DELTA0 = 0.005326) is
EXACTLY the [core-SVP] attack equation with the block size pinned:
delta(445) = 1.0037 under the Chen asymptotic, i.e. **the C3 line as
frozen is a ~130-bit-classical / ~114-bit-quantum core-SVP line**. The
frozen points clear 128 classical not because the line has margin but
because `kappa = ceil(k_z/128)` rounds UP (8-25% integral slack in k_Z).
Measured distance model -> estimator at the frozen points: +7 to +23
bits classical over the 130-bit line ([core-SVP]), +33 to +48 bits under
MATZOV. Direction: **model conservative**; per [core-SVP] alone, kappa
could even drop by 1 at the e=4 2048^3 point (128.2 at kappa 8) — NOT
recommended: it erases the quantum margin, sits 0.2 bits from the
target, and the e=3 sweep shows kappa-1 failing (113.0).

**C4 (MLWE).** The line `N_Z >= k_Z + msg_Z + 768 log2 q / 11.7` puts
the knapsack dimension at `768 log2 q / 11.7` (2035 at q31). Measured:
n_sec = 2048 ternary at q31 gives **193.3 bits classical [core-SVP]
(215.7 [MATZOV])** — the 11.7-line is calibrated ~60 bits ABOVE 128
(it encodes roughly "as hard as a Kyber768-class instance", not "128
bits"). MLWE is never the binding constraint; per the estimator, N_r
could shed ~4 ring elements (-10%) and still clear 128. Direction:
**model strongly conservative.** No change recommended — N_r's cost is
linear and small, and the slack is free insurance against the Q4
write-up moving beta.

**Verdict on Q5's stated risk:** kappa/N_r movement required =
**0% / 0%** (vs the feared tens of percent). The minimum-movement solve
([core-SVP], 128-bit classical) lands BELOW the frozen values at every
shape: min kappa 8/8/8/9/8 vs frozen 8/8/9/9/8; min N_r (MLWE side)
36/36/37/53/22 vs frozen 40/40/40/57/26.

**Margin structure** (sweep, kappa +-2 / N_r +-8, full tables in
`results/estimator_core_svp.txt`): one kappa step moves MSIS by ~23-26
classical bits; one N_r step of 4 moves MLWE by ~55-65 bits and MSIS by
only ~ -1.5 (via beta growth); C2 headroom stays >= 1.2 bits across the
whole swept region at q31. The frozen point sits one full kappa step
above classical failure on the MSIS side and one N_r-4 step above the
128-bit line on the MLWE side.

## 6. Two caveat-grade findings (quantified, no freeze change forced)

**(a) Quantum margin at e in {2,3} and FFN.** Under `2^(0.257 b)`
quantum sieving the MSIS side gives 125.9 / 120.3 / 126.2 (e=2 / e=3 /
FFN). The C3 model never encoded a quantum target (its line is ~114
quantum at equality), so this is a POLICY question, not a drift. If
128-bit quantum is adopted, kappa + 1 at those shapes suffices
([core-SVP] after the step: MSIS qu 148.5 / 141.9 / 146.2, classical
168.8 / 161.2 / 166.1; MLWE side already clears). Cost
(route_r_params.py formulas, q31): commit/col 11.62 -> 12.11 KB (+4.2%)
at the 2048^3 shapes, 19.86 -> 20.34 KB (+2.4%) at FFN; proof
296.0 -> 302.3 KB (+2.1%, e=2), 209.3 -> 213.7 KB (+2.1%, e=3),
239.7 -> 243.1 KB (+1.4%, FFN).

**(b) Integral-kappa C4 bookkeeping.** The chain's C4 check uses the raw
`k_z` (e.g. 1034 at Pi2 e=4) but the deployed commitment has
`kappa = 9` rows, so the ACTUAL knapsack dimension is
`n_sec = (40 - 9 - 16)*128 = 1920 < 2035 = ` the model's own d_lwe line.
The estimator shows this is harmless — 177.8 bits classical [core-SVP],
200.9 [MATZOV], 49.8 bits above target — but the C4 line as written is
not the quantity the implementation instantiates. If the C4 line is ever
enforced integrally, Pi2 e=4 2048^3 needs N_r 41 (proof 169.8 ->
173.0 KB, +1.9%; commit/col unchanged; MSIS 150.7, MLWE back to 193.3).
Recommendation: annotate, don't move parameters.

## 7. Freeze-check impact (integration notes for the merger)

**No freeze-check row needs updating.** The C2-C4 gate rows
(`Pi2 2048^3 e in {2,3,4}`, `FFN e=4`), the P0 lines and the prototype
constants all stand as frozen. For the next documentation pass (not this
tranche, per file lanes):

- ROUTE_R_BUILD_REPORT.md Section 2's Q5 bullet and ROUTE_R_DESIGN.md
  Section 9 Q5 can be marked RESOLVED: no movement (this note).
- The C4 model text (design Section 3) deserves the Section 6(b)
  integral-kappa footnote; if the freeze-check ever grows an integral
  `n_sec >= d_lwe` gate, the e=4 2048^3 row becomes (9, 41) — a
  strictly-optional hardening, security is already cleared as-is.
- If a quantum target is adopted, the three kappa+1 rows of Section 6(a)
  are the change set: freeze rows would read e=2 (9, 40), e=3 (9, 40),
  FFN (10, 57).

## 8. Reproduction

Local (this repo; core-SVP ~2 s, full run ~3 min):

    git clone https://github.com/malb/lattice-estimator tools/lattice-estimator
    git -C tools/lattice-estimator checkout 3e48ef421ec256afddb3e7d2249a77eab6e9ba12
    python3 scripts/estimator_run.py            # both legs
    python3 scripts/estimator_run.py --skip-lattice-estimator   # model only

(`tools/` is deliberately not committed; the two commands above recreate
it exactly.)

Native-Sage confirmation (any Sage >= 9.x machine; removes the shim from
the trust chain — the only remaining residue of this sign-off):

    git clone https://github.com/malb/lattice-estimator && cd lattice-estimator
    git checkout 3e48ef421ec256afddb3e7d2249a77eab6e9ba12
    sage -python -c "
    from estimator import *
    # MSIS rows: (k_Z, q, beta_l2_floor, N_Z), in freeze order
    # (Pi2 e=2, e=3, e=4; FFN e=4; prototype)
    for kz, q, B, m in [(1024, 2147483249, 36807994, 5120),
                        (1024, 2147483249, 49079310, 5120),
                        (1152, 2147483249, 73621941, 5120),
                        (1152, 2147483249, 104908513, 7296),
                        (1024, 2147483249, 24566215, 3328)]:
        print(SIS.lattice(SIS.Parameters(n=kz, q=q, length_bound=B, m=m, norm=2)))
    # MLWE rows: (n_sec, q, m) -- e=2 and e=3 share the first row
    # (Pi2 e=2/e=3; Pi2 e=4; FFN e=4; prototype)
    for n, q, m in [(2048, 2147483249, 3072), (1920, 2147483249, 3200),
                    (2048, 2147483249, 5248), (2048, 2147483249, 1280)]:
        p = LWE.Parameters(n=n, q=q, Xs=ND.UniformMod(3), Xe=ND.UniformMod(3), m=m)
        print(LWE.primal_usvp(p)); print(LWE.primal_bdd(p))
    "

Expected (MATZOV default): MSIS rop 2^168.9 / 2^162.8 / 2^176.8 /
2^169.3 / 2^178.1; MLWE usvp 2^217.5 / 2^202.6 / 2^217.5 / 2^226.7 —
matching `results/estimator_lattice_estimator.txt` line for line. Any
material deviation would falsify the shim and reopen this note; matching
output upgrades the sign-off from "estimator-validated (shimmed)" to
"estimator-validated (native)".

The exact beta floors above are `floor(beta_f)` of the chain at the
frozen shapes (in order: Pi2 e=2/e=3/e=4, FFN e=4, prototype); they are
recomputed and printed by `estimator_run.py`, which self-checks its
chain reconstruction against `route_r_params.py` and the
`ring_lattice.rs` published constants on every run.
