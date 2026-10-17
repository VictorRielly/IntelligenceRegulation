# Token I/O rung R1 — independent adversarial code review

Reviewer: the independent adversarial code reviewer for rung R1 (a Claude
Opus 5.5 subagent that did not write the code), 2026-10-17, 22:02–22:39 UTC.
Binding rules followed: `ops/zkp-mvp/LANE_RULES_20261017.md` (every cargo
leaf through the resource guard, detached with `.done` markers, no git
writes). **No privacy acceptance and no ruling is made here**; rulings are
Victor's (`docs/zkmatrix-poc/ZK60_DECISIONS.md`).

**Object reviewed.** `ops/zkp-mvp/token-io/`, frozen at 22:04 UTC into
`ops/zkp-mvp/token-io-review-r1/` (no target dirs). Manifest
`ops/zkp-mvp/token-io-review-r1.sha256`: 224 files, list sha256
`8e1e29613fca8dd4afa6779ccd55bc29a0f703ced680f13fc1019211c306074f`. All 223
entries of the author's `results/zk60_token_io_r1_20261017/manifest_suite_start.sha256`
(list sha256 `b9a55176…`) match byte for byte; the one extra file is
`BASELINE.sha256`. So the reviewed tree **is** the tree the author's full
suite (`s1-suite`) started on. My own tests live in a separate scratch copy
(`ops/zkp-mvp/token-io-review-r1-scratch/tree/`: the frozen tree plus
`hashline/src/private_block/token_io/run/review_tests.rs` and one
`mod review_tests;` line in `token_io/run.rs`); the frozen copy is untouched.

---

## 1. Verdict

**Is R1 sound as built?** Yes, for what R1 claims (the public-row variant,
mode (i), the tiny rung, verifier configured with `Tier::R1_MVP`). I found no
way to make the verifier accept a wrong or non-maximal token, a broken tie, a
wrong or arbitrary embedding row, a token not sealed in the output endpoint,
a prompt not sealed in the input endpoint, a receipt under another model,
table, constant, context or root, or segments moved within or between runs.
Every relation of DESIGN v3 §2.3 and §3.1 is in the verifier with its public
factors and its own fresh coefficient, drawn after every commitment it binds
(§3.1, §3.2 below). Prover and verifier run one schedule. The
schedule-driven `run_stage_slot` is a faithful copy of `argument::run_slot`.
`B_in` / `B_out` are two-site D12a boundaries, each opened once after its
second claim. The token endpoints (2^8, rate 1/8, one site, 6 rows) are each
opened once. Every one of my 33 new controls (RV-01..33) was refused, each
at the predicted place. On my copy the author's 10 tests pass, with all of
their control lines refused as predicted, and so does the fresh-process pair.

**Faithful to the design?** Mostly. Four places are weaker than a binding
ruling or the design: TR-1 (MEDIUM: the D27 tier door admits tiers below
DESIGN B-1, and the verifier has no minimum-tier policy), TR-2 (LOW-MEDIUM:
the tier's column-check lever Q works only at 256), TR-3 (LOW: the verifier
accepts selector variants it does not implement, D26 C-a) and TR-4 (LOW: the
owner check checks none of the plane rules D26 C-d lists). None of them lets
an R1_MVP-configured verifier accept a false statement. TR-5..TR-7 are
informational. TR-8 lists the R1 acceptance items still open, and TR-9 the
R2 work items.

**May R1 be the base for R2 at TinyLlama?** Yes, on these conditions:
(a) the author's full existing suite (pins; `tio-s1-suite`, started
22:36:20 UTC after queueing) comes back with the baseline's 688 passed / 0
failed. I did not repeat it and did not see its result.
(b) TR-1 and TR-2 are fixed before any tier other than `Tier::R1_MVP` is
offered, or a CLI or receipt file is allowed to choose the tier.
(c) TR-3's one-line verifier refusal goes in before variant P is built.
(d) R2's genuinely new parts get their own failing-first controls: the
multi-row stage planes the R1 door refuses today (`V_pad = 2^15`), 7 limbs,
and the calibration-rule `Cn`, which brings back the D20 final-norm refusal
class (TR-9).
(e) The G-1..G-7 rank / CFS gate is still owed, and no privacy figure may be
quoted before it.

---

## 2. Findings

Severity scale: HIGH = an R1_MVP verifier accepts a false statement or
learns hidden data; MEDIUM = the code is weaker than a binding ruling or the
design in a way that becomes exploitable by configuration or by the next
rung; LOW = a hardening or conformance gap with no current exploit; INFO =
worth recording, no action required for R2.

### TR-1 — MEDIUM — the tier door admits tiers below DESIGN B-1; no minimum-tier policy (D27)

**Where.** `hashline/src/private_block/token_io.rs` 90–107 (`Tier::check`
only checks ranges: row width 2^2..2^20, inverse rate a power of two ≥ 2,
`1 <= Q <= row width`, stage width ≥ 2^8). `token_io/run.rs` 69–100
(`TokenRunStatement::new` takes any tier that passes) and 480–548
(`verify_token_run`: no policy). `Tier::name` is a free string. The
statement carries no derived whole-run figure.

**What D27 / the design require.** D27 (Victor, 20:21–20:22 UTC) says the
tier is a profile parameter bound into the run statement *with its derived
whole-run figure*, and *the verifier takes a minimum tier as policy and
refuses receipts below it*. DESIGN B-1 says token endpoints sit at 2^8,
rate 1/8, and every stage commitment at row width ≥ 2^12. The v1 geometry
(2^8, rate 1/4) was the hole that took the whole proof to 2^-66.3.

**Reproduction** (`review_the_tier_door`, `logs/t1-tests.log`, lines
`REVIEW-R1 FINDING TR-tier`) [MEASURED, n=1]. For each tier: the door's
answer, and an honest run proved and then verified at that tier.

| tier (all other levers R1_MVP's; the first two keep the name `mvp-95-whole-run (D27)`) | door | per-opening [COUNTED] | proves and verifies |
|---|---|---|---|
| R1_MVP (control) | admits | endpoint 2^-106.25, stage 2^-103.69 | yes |
| token endpoints 2^8 rate 1/4 (the v1 B-1 hole) | **admits** | endpoint **2^-67.34** | **yes** |
| token endpoints 2^8 rate 1/2 (`RS(512, 512)`, zero distance) | **admits** | endpoint **2^0** (vacuous) | **yes** |
| stage commitments at 2^9 | **admits** | stage **2^-86.28** | **yes** |
| Q = 128 | admits | endpoint 2^-58.33, stage 2^-52.48 | no: TR-2 |
| Q = 1 | admits | endpoint 2^-0.50, stage 2^-0.41 | no: TR-2 |

**Impact.** A verifier whose statement is built from a tier that the prover
can influence accepts receipts whose token endpoints carry no proximity
soundness at all. Examples: a future CLI that reads the tier from a
receipt's `statement.txt`, the way the fresh-process test reads roots and
checks the parameter line; or a profile registry entry. Today every caller
passes `Tier::R1_MVP`, so there is no live exploit.

**Minimal fix.**
1. `Tier::check` enforces the design's floors for the MVP tier:
   `per_opening_log2(stage) <= -103` and `per_opening_log2(token endpoint)
   <= -106`. In general, derive the whole-run figure from the levers at the
   named workload and refuse anything below the tier's declared target.
2. `verify_token_run` (or `TokenRunStatement::new` on the verifier side)
   takes a policy minimum in whole-run bits and refuses a statement below it.
3. Tiers become registered constants. The name is checked against the levers
   rather than chosen, and the derived whole-run figure goes into the
   parameter line.

### TR-2 — LOW-MEDIUM — the column-check lever Q works only at 256 (completeness)

**Where.** `token_io.rs` 1027–1041 and 1043–1070 (`StageSegGeom::len`,
`validate`). These size the mask commitment's opening with
`Dim::of(&lay.params).checks`, which is the tier's Q. But `zk.rs`
`mask_open` always opens `MASK_Q = 256` columns (`zk.rs` 375, 594). The block
wire (`wire.rs` 125, 345) has the same conflation, and there it is harmless
because every block shape's Q is 256.

**Reproduction.** Q = 128 and Q = 1: the door admits both, and the honest run
fails at `PROVE: token I/O wire: opening shape` (table above). A verifier
would refuse the same segment on decode.

**Impact.** D27's "column checks Q" lever cannot be moved for the new stages:
any tier other than 256 cannot prove. That includes a stronger tier (Q = 320
or 384 at a 2^9 endpoint row). The author's TF-5 records only that M's own Q
is fixed. This defect is wider: one fixed Q blocks the whole lever. It is
not a soundness issue.

**Minimal fix.** Size the M opening from `crate::zk::{MASK_Q, MASK_VEC,
MASK_LOG_DOM}`, independent of the tier. Add an honest prove-and-verify test
at Q ≠ 256. Until both exist, `Tier::check` should refuse `opened_cols !=
MASK_Q` by name.

### TR-3 — LOW — the verifier accepts selector variants it does not implement (D26 C-a)

**Where.** `token_io/run.rs` 381–383: the refusal of P/F is in
`prove_token_run` only. `verify_token_run` has none, and `endpoint_specs`
ignores the variant (P still gets the one-site, 6-row M-7 endpoint, not
D26's two-site spec).

**Reproduction** (`review_an_unbuilt_variant_at_the_verifier`). A forger's
prover, identical to `prove_token_run` except for that one refusal, builds a
public-row receipt under statements naming
`P-selector-sealed-in-input` and `F-selector-sealed-in-output`.
`verify_token_run` **accepted both** (`REVIEW-R1 FINDING TR-variant`).

**Impact.** The verified statement says "the prompt length is hidden and the
selector is sealed", but the receipt proved row `T − 1` with no selector at
all. An owner checking under P or F semantics would reject the decommitment,
because the selector half is absent: the IO slot forces those words to zero.
So no wrong token passes an owner who does the check. The verifier's
acceptance is still a misstatement, and C-a's intent is that a variant is
fixed by a statement the verifier actually enforces.

**Minimal fix.** In `verify_token_run`, and in `TokenRunStatement::new` or
`endpoint_specs` while P and F are unbuilt, refuse `tp.variant !=
SelectorVariant::PublicRow` by name. When P lands, `endpoint_specs` must
build D26's two-site spec for it (C-c).

### TR-4 — LOW — `owner_rebuild_root` checks no plane semantics (DESIGN 3.4, D26 C-d)

**Where.** `token_io.rs` 1213–1238. It checks the decommitment's shape,
canonical words and the rebuilt root, and returns the words. The checks for
BOS at position 0, the prompt and zero pad words exist only in the test
helper `owner_checks` (tests.rs 235–256). For the output endpoint nothing
checks that word 0 is below `V` and the other words are zero.

**Reproduction** (`review_the_owner_check`). Two planes, each sealed by its
real spec, both rebuild their roots: **ACCEPTED** (`REVIEW-R1 FINDING
TR-owner`).
* input: a non-BOS position 0 and a nonzero pad word;
* output: an id ≥ V and a nonzero pad word.

The binding itself is solid. My six decommitment tampers were all refused:
one salt bit, two salts swapped, a mask-row word, the token word, the pads of
two rows swapped, and a noncanonical word (RV-22..27).

**Impact.** None for an owner who first verifies the receipt: the IO slots
force exactly those semantics. But the function named as the owner check
gives no semantic guarantee to a caller who skips verification or reuses it.

**Minimal fix.** Two functions, both taking the *verified* statement:
`owner_check_input(statement, dec, prompt)`, which checks the root, BOS, the
prompt and zero pads; and `owner_check_output(statement, dec) -> token`,
which checks the root, `tok < V` and zero pads.

### TR-5 — INFO — the head-word class is not declared at the door

DESIGN 3.1 clips `W'` to `[-127, 127]`, and the door derives the keyed
window with `127²`. But `TokenTables` / `TokenProfile::new` admit an int8
`-128` (`REVIEW-R1 FINDING TR-head`: ACCEPTED). Exact arithmetic
(`REVIEW-R1 ARITH`) shows it does not matter at any registered shape: with
−128 the honest maximum stays inside the same 45 / 53 / 56-bit window (R1 /
TinyLlama / Llama-3-8B), and limbs and no-wrap hold. **Fix:** refuse −128
(D24 F-1 rule: every exportable constant gets a declared class), or derive
the window with `127·128`. Either is one line, plus the class in
`describe()`.

### TR-6 — INFO — To entry 1 of `tok` and `M` is not pad-zeroed (TI-1 lift)

The lift of the one-entry `To` domain to two entries (author's TI-1) gives
`tok` and `M` a second committed word that no clause constrains. D and Dsq
are covered by TZC's pad clause. A run with `tok[1] = 5` and `M[1] = 7`
verifies (`REVIEW-R1 FINDING TR-To1`: ACCEPTED). No claim reads those words,
so there is no soundness or privacy consequence: a malicious prover controls
a word nobody reads. It does depart from G-4's "pad-zero on the P-3 lift of
every small domain". **Fix:** add `tok` and `M` to TZC's pad zeta-fold (one
term each), or list the exception in the gate checklist.

### TR-7 — INFO — the run's hash-tag key set is the block shape's

DESIGN 4.1 (D17 bullet) says a token-I/O run has "its own string,
transcript and hash-tag key set". The code uses `Shape::hash_tag()`, which is
derived from the block shape's profile, the same as every existing run
profile. Transcripts are separated by the run profile string
(`tagged_transcript`), so no receipt can be transplanted. **Fix:** amend the
sentence in the design, or derive the run's tag from
`RUN_PROFILE_TOKEN_IO_RUNG_TC`. That second option moves bytes for the token
profile only.

### TR-8 — acceptance items of DESIGN §6.1 still open (not code defects)

* **Pins.** "Existing profiles byte-identical (block, run and D22 toy pins
  re-run)": the author's full suite started at 22:36:20 UTC. Not yet
  reported to me.
* **Rank / CFS controls on the new stages (G-1..G-7).** Not built, as the
  author states. Add to the gate's checklist two partially fixed claim kinds
  that are not on DESIGN's G-2 list: `A_out`'s `x` (IO-in) and `y` (HEAD) at
  three fixed lift bits, and the To-domain reads at a fixed coordinate. Each
  terminal is still masked by at least one uniform pair column (§3.4).
* **The D16 rule-5 audit** is a hand-written classification table with
  exact no-wrap arithmetic (coverage asserted), not one derived from the slot
  polynomials. That is enough at R1. It is worth mechanising at R2, where the
  planes multiply.

### TR-9 — R2 notes (not R1 defects)

* **C-7 is decided against the refusal-free form.** The fidelity REPORT
  measured T4's agreement at the calibration-rule `Cn` (5,664); the
  refusal-free `Cn` (1,024) gives 93.7 %. R1's fixtures use the refusal-free
  constants, so R1 never exercises an honest run at a calibrated `Cn`. At R2
  the final-norm int8 refusal becomes a live, input-dependent D20 class. R2
  needs an honest completeness run at the calibrated `Cn` and the D20
  statement.
* **New layout code.** The R1 door refuses `V_pad`, `d_pad` larger than one
  stage row (2^12). TinyLlama needs `V_pad = 2^15` and `d_pad = 2^11` in
  stage OUT, so R2 needs multi-row planes or a wider stage row. That means
  new counts, new `A_GROUPS` / `H_GROUPS` and new controls.
* **Limbs and helpers.** A 53-bit window gives 7 limbs and 4 VZC helpers.
* **Verifier cost.** The verifier folds 65.5 M public words per proof for
  each of the embedding and the head.

---

**Not found** (attacks tried, each refused or impossible by construction):
* a multiplicity moved onto a padded table entry with the same `tau`,
  invisible to LogUp (RV-01/02, caught by the pad clause);
* a second hot selector entry beside the honest one on a padded entry
  (RV-31);
* pad-column and lifted-entry values of `x`, `y` and `lambda`, and the
  isqrt limbs (RV-03..05, 32, 33);
* the logits from the BOS row (RV-06);
* each of the two boundaries proved against a different plane by its two
  stages (RV-07/08);
* segments swapped, repeated or imported from another run (RV-09..12);
* each statement field changed alone within its class (RV-13..21);
* position 0 = id 0 under BOS 1 (RV-30).

Completeness holds at the class edges: every `m_j = 2^12` (RV-28) and
`BOS = 0` (RV-29).

---

## 3. What was checked, item by item

### 3.1 Transcript order (brief item 1)

| challenge | drawn in | after (bound) | prover = verifier |
|---|---|---|---|
| run header | `TokenRunStatement::transcript` | profile string, run shape incl. `V`, expected-IO (both token-endpoint spec digests and roots), public statement (block digests, embedding and head digests), parameter line (incl. `TokenProfile::describe`: V, BOS, final-norm constants, multiplier class, derived window and limbs, variant, mode, tier levers), calibration (model identity, profile digest), schedule digest (both stage layouts, block layout, stage lines) | same constructor both sides |
| `beta, gamma, alpha, r_emb` (stage IN) | `stage_in::challenges` | stage tag, embedding digest, `B_in` root, `A_in` root, `M_in` root | yes (lines 281–307 vs 407–412) |
| `H_in` root absorbed | | after the four challenges, before every slot | yes |
| IN-00 `tau` (IO-in) | `define(SI_IO)` | `A_in` (`tok`), `H_in`, the input endpoint root (header) | yes |
| IN-01 `tau, mu_q, mu_bos, mu_pad, zeta` | `define(SI_QZC)` | `A_in`, `M_in`, `H_in` (so `mu_bos` is fresh: CHECK2 N-1 closed) | yes |
| IN-02 `tau, mu, mu_pad, zeta` | `define(SI_TZC)` | same | yes |
| stage OUT `gamma, alpha` | `stage_out::prove/verify` | stage tag, head digest, `A_out`, `M_out`; `B_out` root (block L−1's stage) and output endpoint root (header) earlier | yes (lines 600–643 vs 750–756) |
| OUT-00 `tau` (IO-in, row `T−1`) | `define(SO_IO)` | `A_out` (`x`), `B_out` | yes |
| OUT-02 `tau, mu[4], nu, zeta` (TZC; hosts SS) | | `A_out`, `H_out`, SS's published scalar | yes |
| OUT-04 `r_j` (HEAD point) | | `A_out` (`y`, `e`, `lambda`, `tok`, `M`) | yes |
| OUT-05 DZC `tau, mu[10], zeta` | | `A_out`, `H_out` | yes |
| OUT-06 VZC `tau, mu, nu, zeta` | | `A_out`, `H_out`, HEAD's published scalar, `r_j` | yes |
| OUT-07 RSEL `c1, c2, c3` | | `A_out` (fresh: A2, A3, A6 separately) | yes |
| OUT-10 `tau` (IO-out) | | `A_out` (`tok`), output endpoint root | yes |
| every slot's CFS `c` and terminal `e` | `run_stage_slot` | the slot index, then the scalar, rounds, terminals in order | the same function both sides |

`run_stage_slot` (token_io.rs 696–823) against `argument::run_slot`
(argument.rs 448–664): identical step order (slot index → `c`, zero refused →
the one scalar, with the same Private / Standalone / Host formulas → masked
rounds with `recover_one` → one extension round per family with the same
`mask_eval` at the commitment's own row width → degenerate `e` refused →
terminals absorbed → claims with the same `cd`, `cm` → functionals in the
same order, host Gammas last). Only the absorb labels differ (`tk-*` for
`pb-*`, domain separation) and the grouped-eq prover path is absent (a
prover-side optimisation with no transcript effect).

### 3.2 Relations present in the verifier (brief item 2)

Each row was checked as the polynomial the verifier evaluates (the
`define` closures run identically on both sides), with what each public factor
and fresh coefficient does.

| design relation | where | verifier's polynomial (public factors, fresh coefficients) | status |
|---|---|---|---|
| IO-in, stage IN: `end = supp_T tok` over the endpoint's whole 256-word plane (D17 rule 1, C-3) | IN-00 | `eq(tau) (end − supp_T · tok(0000‖z))`; the lift bits of `tok` fixed to 0 | present; pad words bound to 0 |
| query zero-check: LogUp `h_q (alpha − tok − beta x~(t, r_emb) − g_emb) = supp_T`, BOS `u0 (tok − BOS)`, pad `(1 − supp_T)(tok + zeta h_q)` | IN-01 | `eq(tau) [mu_q·LogUp + mu_bos·BOS + mu_pad·pad]`, three fresh `mu` plus a fresh `zeta`, all after `H_in`; `B_in` read at `(rho_t, r_emb)` on the trailing row bits, broadcast over the lift where pad forces `h_q = 0` | present; N-1 closed (own `mu_bos`, controls #4 and my RV-30) |
| table zero-check `h_tab (alpha − tau) = m`, `tau(v) = v° + beta E~(v°, r_emb) + g_emb`, pad `(1 − supp_V)(m + zeta h_tab)` | IN-02 | as written; `tau` public (verifier folds `E` at `r_emb`, O(V·d)); padded rows repeat row 0 | present; pad clause live (my RV-01/02) |
| LogUp sum `Σ h_q − Σ h_tab = 0` | `StageLayout::logup_sum_claim` on `H_in` | one pairless all-ones claim, signs `[+1, −1, +1]` for `h_q, h_tab, u`; masked by the zero-sum row (IN-03) | present |
| `B_in` two-site boundary, site 0 = stage IN, site 1 = block 0's IO-in, opened once in block 0's stage after both claims (D12a) | run.rs 413–449 / 504–530 | `boundary::check_opening` (exactly two groups, each its own pair) then one `verify_zk` | present (my RV-07) |
| IO-in, stage OUT: `x = B_out[T−1, ·]` (public fixed row bits, G-2) | OUT-00 | `eq(tau)(x(000‖i) − B_out(bits(T−1)‖i))` over `d_pad` | present (control #18, my RV-04, RV-06) |
| final RMSNorm: SS `Σ_{i<d} x²` hosted by TZC; TZC `Dsq = D²`, `D = limbs`, `2D = a1 + a2`, pad on To entry 1, host term `nu·u0·(Dsq + a1 − Ceps)` | OUT-01, OUT-02, OUT-03 (LZC: limb bytes + pad) | fresh `mu[4]`, `nu`, `zeta` after `H_out` and SS's scalar | present; `D = isqrt(Ceps + Σx²)` exactly (controls 17b±, 17c) |
| final norm quotient with windows: `c0 = 2 g0 Cn x + D 2^tn − 2 D 2^tn y − rho`, `c1 = sigma + rho + 1 − 2 D 2^tn`, `c2 = x + 32768 − xl0 − 256 xl1`; `y` by `sym` lookups; pad on all 12 Do planes | OUT-05 (DZC) | `eq(tau)[supp_d·(mu0 c0 + mu1 c1 + mu2 c2) + Σ mu_k helper_k + mu_pad (1 − supp_d) zeta-fold]`, rho/sigma four bytes (window exactly 32, door-pinned) | present (17a, 17d, 17e; my RV-03, RV-05) |
| raw logits `l_j = m_j (y·W'_j)`, `m_j ∈ [1, 2^12]` public per row (D25 T4 amended), virtual | OUT-04 (HEAD, private) hosted by OUT-06 | `Σ_i y(i)·Wf(i)`, `Wf = Σ_{j<V} eq(r_j, j) m_j W'_j` (public fold); VZC host term `nu·eq(r_j, z)·l*(z)` | present; `l*` = true `l` on the whole Vo cube w.h.p. (`r_j` after `A_out`) |
| A1 `e(1 − e) = 0`, pad `e = λ = 0` beyond `V` | OUT-06 (VZC) | `eq(tau)[mu0 e(1−e) + Σ mu_k helper_k(λ bytes) + mu_pad (1 − supp_V) zeta-fold(e, λ_0..λ_5)]` | present (#1, #14; my RV-31, RV-32) |
| A5 `l* = supp_V (M + 2^-v (iota − tok − delta))` | OUT-06 host term | as written, `delta = Σ_k 256^k λ_k`, `tok`, `M` read at To entry 0 | present (#12a, #13) |
| A4 `delta` in `ceil(window/8)` byte limbs, window derived over the class (`bits(2^v·2d·127²·2^12 + V − 1)` = 45 → 6 limbs at R1) | VZC helpers + TAB + LogUp sum on `H_out` | no top-limb pin (C-4); door checks `2^(8L) + 2^window < p` | present (#15, #12b) |
| A2 `Σ e = 1`, A3 `tok = Σ i e`, A6 `Σ e delta = 0`, public factor in every monomial | OUT-07 (RSEL, standalone) | `supp_V e (c1 + c2 iota + c3 delta) − u0 (c1 + c2 tok)`, three fresh `c` after `A_out` | present (#2 A6-only, #3 A3-only) |
| U8 table helper `h (alpha − (z mod 256) − g_u8) = m`, pad beyond 256 | OUT-08 (TAB) | fresh `mu`, `zeta` | present |
| IO-out `end = u0 · tok` over the output endpoint's whole 256-word plane | OUT-10 | `eq(tau)(end − u0·tok(0))` | present (#9, #10b) |
| token endpoints: 2^8, rate 1/8, one site, `data + 5` = 6 rows, one opening each | `endpoint_specs`, `check_token_endpoint_opening` | spec digest in the header; exactly one claim with three parts on rows `0..data`, `data`, `data+1`; prox row `data+2` | present; opened in their own stage (IN: after M A H; OUT: after M A H and `B_out`) |
| `B_out` two-site boundary, site 0 = block L−1's IO-out, site 1 = stage OUT, opened once in stage OUT | stage_out.rs 711–714 / 769–773 | as `B_in` | present (my RV-08) |

Soundness of the keyed argmax as built (my re-derivation, no new
assumption): RSEL + booleanity give one hot `j < V` with `tok = j` and
`delta_j = 0`; A5 at `j` gives `M = l_j` as an integer; for every `i < V`,
`delta_i = 2^v (l_j − l_i) + (i − j)` in the field, the right side an integer
of absolute value below `2^v·2·2^12·d·127·128 + V < 2^45` at R1 (even with a
−128 head word, TR-5), the left side in `[0, 2^48)`, `2^48 + 2^45 < p`, so the
integer is non-negative: `j` is numpy's first maximum. The R1 per-opening and
whole-commitment figures in the author's report re-derive exactly: 7 openings
at 2^-96.13 (four block A/H at 2^10 rate 1/4 plus three boundaries) dominate,
`7 · 2^-96.13 = 2^-93.32`; four stage A/H at 2^-103.69 and six at 2^-106.25
(four M, two token endpoints) add under 0.01 bit [COUNTED].

### 3.3 Tests run (brief item 3)

All runs used the scratch copy and went through the resource guard,
detached, waiting on `.done` markers (`launch_r1.sh`) [MEASURED, shared box,
n=1; the 8B calibration light job was live].

| step | guard | result | wall |
|---|---|---|---|
| `cargo test --release --offline --locked -j2 --lib --no-run` | build, need 3 / cap 5 GiB; waited 553 s for the heavy lock | exit 0; no warning from `review_tests.rs` (17 pre-existing warnings elsewhere) | 225 s, peak RSS 1.84 GiB |
| `cargo test ... --lib token_io -- --test-threads 2 --nocapture` | cpu, need 4 / cap 7 GiB | **22 passed, 0 failed, 2 ignored**: the author's 10 plus my 12; 0 lines `NOT AS PREDICTED` | 146 s |
| `token_io_r1_prove_to_dir` (ignored test; `TOKEN_IO_R1_OUT` = scratch `runs/`) | cpu, need 3 / cap 6 GiB | both fixtures written; next tokens 24 and 116; 19,026,480 B each | 8.9 s |
| `token_io_r1_verify_from_dir` (a separate process) | cpu, need 3 / cap 6 GiB | both accepted from the saved bytes (0.58 / 0.56 s); a one-bit change refused in both | 2.5 s |

**Honest runs on my copy** [MEASURED, n=1, release test binary]:
* generic model: next token 116, equal to the reference; prove 3.54 s, verify
  0.56 s;
* R0's model: next token 24; prove 3.24 s, verify 0.63 s;
* receipt 19,026,480 B as `[1,224,328, 7,421,464, 7,421,464, 2,959,224]`,
  which are the counted lengths.

These agree with the author's figures within run-to-run noise.

**My controls** (each MUST be refused; each was refused at the predicted
place). Every row is a `REVIEW-R1 CONTROL` line in `logs/t1-tests.log`.

| id | forgery | refused at |
|---|---|---|
| RV-01 | one count of `m[0]` moved to padded entry `V` (`tau(V) = tau(0)`: invisible to LogUp) | stage IN slot 02 (table pad clause) |
| RV-02 | the same move to a lifted entry above `V_pad` | stage IN slot 02 |
| RV-03 | `x` nonzero on a lifted entry above `d_pad` (no IO or SS term reads it) | stage OUT slot 05 (DZC pad) |
| RV-04 | `x` nonzero on a pad column inside `d_pad` | stage OUT slot 00 (IO-in) |
| RV-05 | `y = 1` on a pad column (no logit changes) | stage OUT slot 05 |
| RV-06 | stage OUT computed from row 0 (the BOS row) | stage OUT slot 00 |
| RV-07 | stage IN honest on `B_in`, block 0 proved on another input | block 0 slot 21 (IO-in endpoint equality) |
| RV-08 | `B_out` committed with row `T−1` changed, stage OUT on it, block 1 honest | block 1 slot 22 (IO-out endpoint equality) |
| RV-09 / 10 | the block segments swapped / block 0's segment repeated | private run wire (segment index) |
| RV-11 / 12 | another honest run's stage OUT segment / whole receipt | token I/O wire: belongs to another run |
| RV-13..19, 21 | statement with one field changed: context; BOS 2; `Ceps + 1`; `g0 = 126`; tier renamed; roots swapped; another model statement; `Cn = 2047` | binding (another run) |
| RV-20 | the block digests in the other order | refused at construction (trained statement) |
| RV-22..27 | owner decommitment: salt bit; salts swapped; mask-row word; token word; pads of two rows swapped; noncanonical word | owner check |
| RV-28 | honest, every multiplier `2^12` | **accepted** (completeness, as predicted) |
| RV-29 | honest, BOS = 0 | **accepted** (completeness, as predicted) |
| RV-30 | position 0 = id 0 with a consistent lookup, under BOS 1 | stage IN slot 01 (BOS clause) |
| RV-31 | a second hot `e` on a padded vocabulary entry beside the honest one (A2/A3/A6 sum over `supp_V`) | stage OUT slot 06 (VZC pad) |
| RV-32 | a nonzero difference limb (a byte) on a padded entry | stage OUT slot 06 |
| RV-33 | a nonzero odd entry of the isqrt limb plane (To entry 1) | stage OUT slot 02 (TZC) |

**Finding demonstrations** (printed, not asserted): TR-1 / TR-2
(`review_the_tier_door`), TR-3 (`review_an_unbuilt_variant_at_the_verifier`),
TR-4 (`review_the_owner_check`), TR-5 (`review_head_class_edges`), TR-6
(`review_to_entry_one_of_tok_and_m_is_unconstrained`).

The "forger" in every control is the author's cheating prover (the honest
prover algorithm with its refusals off), plus, for TR-3, a copy of
`prove_token_run` without its variant refusal. A prover deviating from the
honest round algorithm is covered by sum-check soundness, which these
controls do not test.

### 3.4 Privacy smell test (brief item 4)

What a verifier of an R1 receipt sees, and whether any of it depends on the
hidden prompt or token beyond the design's admitted channels:

* **Segment sizes**: four segments whose lengths are functions of the
  statement only (`StageSegGeom::len`, `wire::segment_len`), checked equal on
  decode; the author's runs and mine give the counted
  `[1,224,328 / 7,421,464 / 7,421,464 / 2,959,224]` B for both fixtures. No
  data-dependent length.
* **Published slot scalars**. Stage IN's four slots are all standalone:
  scalar = `c · mask total`, independent of the witness. Stage OUT: nine
  standalone or host slots (`c·T` or `c·T − nu·c'·T'`), and two PRIVATE slots
  whose scalars carry data — SS (`Σ x² + c·T_SS`, a function of the hidden
  `B_out` row) and HEAD (`l~(r_j) + c·T_HEAD`, a random combination of the
  hidden logits). Both are masked by an unopened CFS mask total and hosted
  exactly as the block's own norm row sum is (SS hosted by TZC); no new kind
  of channel, but they are on the G-3 list (CFS functionals of the new
  stages) and must be in the joint-view gate.
* **Terminals and openings**: every private-table terminal is masked by its
  own reserved pair (audit: each pair touched by exactly one claim); the new
  partially-fixed claim points are (a) `B_in` at `(rho_t, r_emb)` (column tail
  all challenge values), (b) `B_out` at the public bits of `T − 1` (one fixed
  bit falls in the column tail at R1: half the reserved pair's columns carry
  the mask, G-2 as the design states), (c) `A_out`'s `x` and `y` at the three
  fixed lift bits (3 of 12 column bits fixed: 512 of 4,096 pair columns carry
  the terminal's mask), (d) the To reads at a fixed coordinate (one pair
  column). (c) and (d) are not on the design's G-2 list and should be added
  to the gate's checklist; each terminal is still masked by at least one
  uniform pair column, so this is a gate item, not a finding.
* **Refusal messages**. Verifier refusals occur only for receipts that do
  not verify. Honest-prover refusals happen before any commitment and publish
  nothing (D21): out-of-vocabulary id, missing BOS, wrong prompt length
  (public), and the final-norm classes (denominator, int8 overflow), none
  naming a position or value. With R1's refusal-free constants
  (`g0·Cn = 127·2^tn`) the final-norm overflow cannot fire; at R2 it will
  (TR-9), as an admitted D20 input-dependent class.
* **Statement**: model identity, V, BOS, final-norm constants, multiplier
  class, digests, variant, tier, roots: public model facts and random roots;
  nothing computed from the prompt.
* **The owner hand-off** (rows, pads, salts) is returned to the caller and
  never encoded into a segment; it lets its holder unmask that endpoint's IO
  terminal, a function of its own data (design 3.4).

No channel beyond the admitted ones was found. This is a smell test, not the
G-1..G-7 rank / CFS gate, which remains owed before any privacy figure.

---

## 4. Files

* Frozen review copy: `ops/zkp-mvp/token-io-review-r1/`; manifest
  `ops/zkp-mvp/token-io-review-r1.sha256`.
* Scratch copy with my tests: `ops/zkp-mvp/token-io-review-r1-scratch/tree/`
  (tests: `hashline/src/private_block/token_io/run/review_tests.rs`);
  launcher `ops/zkp-mvp/token-io-review-r1-scratch/launch_r1.sh`; the
  fresh-process pair's saved receipts `ops/zkp-mvp/token-io-review-r1-scratch/runs/`.
* Logs: `results/zk60_token_io_review_r1_20261017/logs/` (`b1-build.*`,
  `t1-tests.*`, `p1-prove-to-dir.*`, `p2-verify-from-dir.*`, `launch_r1.*`).
* Ledger: `results/zk60_token_io_review_r1_20261017/PROGRESS.md`.
