# Adversarial check of the GS-4 / GS-5 / GS-11 / GS-12 closures memo

> **CHECK, 2026-09-23 12:22–12:55 PDT (`date`).** One delegated Opus agent
> (checker), with two read-only sub-checkers (the `audit_claims`
> transcription diff; the GS-11 / GS-12 code facts). Under attack:
> `ZK60_GS4_GS5_GS11_GS12_CLOSURES.md` (DRAFT, commits `80aa124`…`23207cd`)
> and `results/zk60_gs_closures/`. My evidence: `results/zk60_gs_closures_check/`.
> The draft is not edited. **This is not a privacy acceptance and it
> establishes no privacy property.**

**How to read this page.** Each finding has a number (F-1 …), a severity and
a fix. **Blocking** means the draft's verdict cannot stand as written.
**Erratum** means a statement in the draft is false or overclaims but the
verdict survives. **Note** means something worth recording that changes
nothing. A **counterexample** is ranked first. Labels as in the draft:
MEASURED (read off a real capture), COMPUTED (exact arithmetic on a stated
model, script named), ARGUED / PROVED HERE (derivation on this page).

Code is cited at lane `zk60-private-block-125m`, `/home/victor/wt-zk60-block125m`,
commit **`2ea7221`** (read-only), unless marked otherwise.

---

## 0. Verdicts

| gap | draft says | verdict | in one line |
|---|---|---|---|
| **GS-4** | CLOSED | **CONFIRMED independently** (the conclusion); the evidence is overstated (F-4, F-5) | Exclusivity holds on all 22 views of the four 125M captures — I re-checked it with my own code, including the two things the gate does not check (pairs disjoint, every reserved row covered) and the pair-basis leg. But the draft's two "independent observations" are, respectively, a check of a **weaker** property (the gate accepts overlapping pairs) and a replay that passes **by construction** (the capture is written only after the Rust audit has accepted the same claims). |
| **GS-5** | CLOSED (one sub-step computed) | **CONFIRMED independently** for the theorem as stated; **sub-step 2(c) REFUTED** as a general statement (F-1), and it is not needed, because the protocol already enforces its missing hypothesis (F-2) | I re-derived steps 1, 2(b) and 3 and found them correct. My own brute force (not the draft's code) agrees with the formula on every instance that meets (P), (X) and (Π). It also agrees on the instances where (Π) is broken and the §F-1 condition holds: n = Q, n < Q up to Q = 3n, odd n (3, 5, 15), d < Q, the real 125M / rung-G group structures, and the real endpoint and boundary row counts at n/Q = 64. **Counterexample to 2(c):** take a dependent proximity pair and let the only multi-member group have column weights that are Fp-collinear. Then the claim values disclose **one** Fp dimension that the formula does not count (108 of 108 instances). I prove the corrected statement. The draft's proposed "fourth hypothesis" is not necessary: an exact rank form of the u-term removes it (F-3). |
| **GS-11** | CLOSED | **CONFIRMED independently**, with one false statement (F-9) and one incomplete list (F-10) | `M`'s declared geometry equals the `zk.rs` constants on all 8 capture stages, and `M-q` / `M-prox` re-derive shape-free. The fit condition is a named construction refusal (ruling C-4, `shape.rs:610-647`), not "an assert, not a refusal". |
| **GS-12** | CLOSED at every registered shape | **CONFIRMED independently**, with one overclaim (F-11) | act[128] = 0, re-measured without assuming which challenge is β and which is γ: exactly one table and one ordering invert. `Dom::F` pads 3,584 positions at rung-G and 0 at 125M. The draft's claim that CS-3 makes a padded pair row **128** "for any witness" is false: CS-3 guarantees only that the pair is **some** table row. |

The draft's closure of all four gaps survives this check. What must change is
listed as errata below. None is blocking.

---

## 1. Findings

### F-1 — COUNTEREXAMPLE to GS-5 step 2(c) (erratum; FIRST RANK)

**Claim attacked.** Draft §2.2.2(c): "Multi-member groups without (Π) —
COMPUTED, not proved … brute = formula, 70 of 70." Also §2.3: "H-prox is not
needed for the formula to be exact in any instance tried; its failure shows up
inside `k0`." The draft offers these as evidence that values drop out
without (Π).

**Counterexample.** [COMPUTED, `results/zk60_gs_closures_check/gs5_check.py`,
families `CE` and `CE2`, outputs `gs5_check.json`, `gs5_check_CE2.json`,
`gs5_summary.txt`.] One hiding commitment with:

* hypothesis (P) holds: d ≤ Q distinct opened columns;
* hypothesis (X) holds: every claim owns an exclusive adjacent pair with
  weights (cm, cm·U), cm ≠ 0;
* every λ ≠ 0;
* the proximity pair is Fp-dependent, so (Π) is broken;
* the only multi-member group has **Fp-collinear column weights**, meaning
  every ratio of two nonzero entries lies in Fp. Examples: the empty-tail
  "sum" key (all ones), an empty-tail sub-range indicator (`zkey_weights`,
  `zkp-core/src/pcs.rs:902-914`), an Fp-valued tail, or an Fp2 scalar times
  an Fp vector;
* no reserved row outside the pairs.

Result: the brute force reads **n·k0 + u\* + 1**. The claim values alone
contribute the extra dimension (brute with values − brute without values =
1). This holds on **108 of 108** instances: 13 (n, Q) points including
n = 3, 5, 6, 15, n = Q, n < Q up to Q = 3n; two-member and three-member
groups; two groups with proportional weights; and an H-like commitment.

The three controls read exactly the formula (0 extra):

* the same commitment with (Π) intact (36 / 36);
* the same commitment plus a second multi-member group with generic
  weights (36 / 36);
* the same commitment plus one reserved row outside every pair (36 / 36).

Two Fp-collinear groups whose weights are **not** proportional also read the
formula exactly (12 / 12).

**The corrected statement (PROVED HERE).** Setting for the proof:

* Assume (P) and (X), and λ_c ≠ 0 for every member.
* Suppose the proximity pair (p0, p1) is dependent, with ρ_prox[p0] ≠ 0.
* Take a left-kernel element ψ of the randomness block, written as in the
  draft's 2(b).
* The prox-pair equations Tr(θ_prox[t]·ρ_prox[p0]) = Tr(θ_prox[t]·ρ_prox[p1]) = 0
  now force only θ_prox[t] = s_t·w. Here w spans the Fp-line
  {θ : Tr(θ·ρ_prox[p0]) = 0} and s ∈ Fp^n.
* The pair-row equations of an owner c read Tr(cm_c·x_c[t]·z) = −s_t·Tr(w·ρ_prox[r_c + k])
  for z ∈ {1, U}, where x_c[t] = λ_c·θ_g[t] + η_c·cw_g[t].
* Since {1, U} is an Fp-basis and cm_c ≠ 0, this gives x_c[t] = s_t·α_c for
  one fixed α_c ∈ Fp2.

Two cases follow.

* *(G) θ_prox = 0 and 2(b) applies verbatim* if at least one of two things
  holds:
  - some multi-member group g has two pair owners c1, c2 with
    β = α_2/λ_2 − α_1/λ_1 ≠ 0 and column weights that are **not**
    Fp-collinear;
  - some reserved row r outside every pair has Tr(w·ρ_prox[r]) ≠ 0.

  *Proof.* Subtract the two owners' relations. With δ = η_2/λ_2 − η_1/λ_1,
  this gives δ·cw_g[t] = s_t·β for every t. If δ ≠ 0, every nonzero entry
  cw_g[t] equals (s_t/δ)·β with s_t ∈ Fp, so the weights are Fp-collinear.
  That contradicts the hypothesis. So δ = 0, then s_t·β = 0, so s ≡ 0. For
  a reserved row outside every pair, its only equation is
  s_t·Tr(w·ρ_prox[r]) = 0. ∎
* *(C) Otherwise the values can disclose.* The counterexample above is this
  case: s = σ·cw_g is a one-parameter family of kernel elements. It exists
  only with the values' η terms, which is why the generator-only formula
  misses it.

**Why it is not blocking.**

* (Π) is enforced by the protocol, not merely observed (F-2).
* No multi-member group in any capture is Fp-collinear. On all 30 views
  (125M and rung-G) every multi-member group has a tail with a coordinate
  outside Fp (`gs4_check.json`, field `multi_member_groups_Fp_collinear` = 0).
* The only empty-tail key in any capture is the LogUp sum claim, and it is
  a singleton group.

So real receipts are outside the counterexample family twice over.

**Fix.**

* Replace §2.2.2(c) by the statement (G) / (C) above, with the proof.
* Strike "H-prox is not needed for the formula to be exact in any instance
  tried".
* Cite the protocol refusal of F-2 as the reason (Π) always holds.

### F-2 — (Π) and λ ≠ 0 are ENFORCED, not just observed (erratum)

The draft treats (Π) as "the tool's H-prox" and says only that "every
recorded view has H-prox true" (§2.2.2(c), §2.5). The Rust refuses a
dependent proximity pair outright:

* `check_opening_challenges` (`protocol.rs:293-314`) returns
  `"dependent proximity mask coefficients; discard attempt"` when
  `determinant(rho[prox], rho[prox + 1])` (the Fp-wedge, `:276-278`) is zero
  (`:305-310`). It returns `"zero group member coefficient"` for any zero λ
  (`:296-301`).
* It is the last step of `check_opening` (`:327`) and of
  `check_endpoint_opening` (`:389`). Prover and verifier run both: the
  prover at `:1153` / `:1157`, the verifier at `:1257` / `:1291` / `:1381`.

MEASURED here as well: the proximity ρ's wedge at (prox, prox+1) is nonzero,
and every recorded λ is nonzero, on all 30 views. The ρ bytes were read from
the capture's array store and checked against the array's sha256
(`gs4_check.py`, fields `H_prox_wedge_nonzero`, `prox_rhos_sha_ok`,
`lambdas_nonzero`).

**Fix:** state in §2.2 that (P) and (Π) hold on every accepted opening by
code:

* (P): `q_pad ≥ num_col_checks` (`pcs.rs:721/774`). The opened columns are
  distinct points of a coset that avoids the subgroup (`pcs.rs:649`), so
  F^pad is a scaled Vandermonde matrix of rank d.
* (Π): `protocol.rs:305-310`.

(X) is enforced by `audit_claims` plus `build_claim`'s (cm, cm·U)
(`argument.rs:382-384`). The gate's three checks are then confirmations,
not assumptions.

### F-3 — the u-term's "fourth hypothesis" is not necessary; compute u\* exactly instead (erratum)

**Draft §2.2 proposal:** make `u_row_indicators_admissible == |U|` a checked
hypothesis of the gate.

* **Is the hypothesis met at every recorded shape?** Yes. It is also
  **implied**, not contingent. Under (X), (Π) and λ ≠ 0, consider the space
  W = {c : cΓ_{N'} = 0}:
  - The prox pair's 2×2 realified block is nonsingular by (Π), so the
    proximity component of c vanishes.
  - Every group with a pair owner has a nonsingular 2×2 block on that pair,
    namely λ_c·cm_c·(1, U), so its component vanishes too.
  - What is left is the pairless groups, which is only the LogUp sum claim's
    singleton on `H`. Its u-row weights are λ·(1, U). MEASURED at 125M:
    coefficients (1, 0) and (0, 1) on rows 7016 / 7017; `logup_sum_claim`
    writes them.
  - So both indicators are reachable and u\* = 2.
* **Does the tool under-count without it?** Yes, and that is demonstrated.
  Family `U-adm`: give the sum claim u-weights (1, a) with a ∈ Fp, so only a
  non-axis combination of the indicators is reachable. The gate's
  per-indicator term reads 1 short on 36 of 36 instances.
* **The better fix.** The exact form is already in the draft's own §2.2.3:
  u\* = rank Γ_{D∪N'} − rank Γ_{N'} − k0. It reads exactly on the same 36 of
  36. It needs no hypothesis and costs two ranks of a K × R matrix.

**Fix:** have the gate compute u\* by the rank form. Keep the admissibility
count as a report, not as a refusal.

### F-4 — GS-4: the gate's H-pair does not observe exclusivity (erratum)

Draft §1.2 says the gate's H-pair verdict is "the same observation" as
`audit_claims`, with "every reserved row used once". It is not.
`RoleView._check_pair_schedule` (`/home/victor/wt-zk60-jointview/scripts/zk60_native_jv_pcs.py:394-433`,
at `adcd831`) does not check any of these:

* that pairs are disjoint;
* that every reserved row is covered;
* even offset;
* that the sum claim is last.

The draft's "every reserved row used once" is only the count identity
`2·(pairs − sum claims) = reserved rows − spare`
(`results/zk60_gs_closures/gs4_exclusivity_records.py:80`).

[COMPUTED, `results/zk60_gs_closures_check/gate_overlap.{py,txt}`, run
against the gate's own class] Take pairs (4, 5) and (5, 6). Row 5 is shared
and row 7 is unused. The gate reports **H-pair = True**, used = claims, no
finding, and the count identity holds. An odd-offset pair and a partial
schedule also pass.

The gate does check one thing the Rust audit does not: the pair's Fp-basis
determinant.

**Fix.**

* Strike "every reserved row used once" from §1.2 and the "two independent
  routes" wording from §1.4.
* Optionally, the gate adds a disjointness-and-coverage check. My
  `gs4_check.py` (X3) does it and passes on all 30 views.

### F-5 — GS-4: the replay's "22 of 22 accepted" holds by construction (erratum)

The capture's claim lists are the **verifier's own**, written after the
audit has passed.

* In `verify_core`, `check_opening(&ac, …)?` (`protocol.rs:1257`) runs
  before the capture calls for `A`: `capture::pcs`, `run_capture::pcs` and
  `block_capture_shaped::block_pcs` (`:1266-1289`).
* The same order holds for `H`: the check at `:1291`, the captures at
  `:1300-1323`.
* The same order holds for the endpoints: `check_endpoint_opening` at
  `:1381`, the captures after it.
* The writer serializes `ac` / `hc` / `ic` / `oc` from this path, not the
  proof bytes and not prover state (`run_capture.rs:1118-1165`, per the
  sub-checker).

So a literal transcription of `audit_claims` **must** accept these lists.
The replay confirms the transcription and the serialization. It is not a
second observation.

The direct evidence for GS-4 is this chain: the Rust verifier accepted these
receipts, and the capture is its state. The sub-checker diffed the
transcription clause by clause and found it faithful. It reproduced
`gs4_audit_replay.{json,txt}` byte-identically. It found no deviation that
could change a verdict on these captures.

**Fix:** reword §1.3 and §1.4 as "the Rust verifier accepted; the replay
confirms the recorded claims satisfy the transcribed audit".

### F-6 — GS-4: the 26 negative controls are 7 kinds and leave clauses unexercised (note)

The 26 controls are N1–N5 and N7 on four bundles plus N6 on two. They never
exercise these clauses:

* the sum claim touching a site row or missing a zero-sum row;
* an evaluation claim with 0, 1 or 3 site rows;
* a non-adjacent pair;
* an unused pair without any sharing;
* a part leaving the commitment;
* a data part on the proximity row;
* parts with different column weights;
* an endpoint zero coefficient;
* two endpoint claims.

The sub-checker wrote 13 more
(`results/zk60_gs_closures_check/extra_controls.{py,txt}`). All 13 are
refused on the real 125M claim lists, 12 by the expected clause. "Sum claim
on `A`" is caught first by the proximity clause. So the `(true, None)`
branch of `audit_claims` (`protocol.rs:264`) and the group-count mismatch
(`:322-324`) remain unexercised. **Fix:** describe the controls as seven
kinds, and cite the extra set or merge it.

### F-7 — GS-4 provenance: the run captures come from `f4697f9`, not `2ea7221` (note)

The two-block run captures `m125-capture-{dense,zero}-l2` (2026-09-21) pin
source commit `f4697f9`. Their `protocol.rs`, `argument.rs`, `layout.rs`,
`shape.rs`, `run.rs`, `witness.rs`, `private_block.rs`, and zkp-core's
`rng.rs` and `transcript.rs` all differ from `2ea7221` (manifest pins against
the lane files). Even so, the transcription applies to them:

* The first differing hunk of `protocol.rs` begins at old line 279, inside
  `check_opening_challenges`' comment and its `cfg(test)` lines. So
  `part_key_at`, `opening_groups_at`, `part_rows`, `audit_claims`,
  `check_opening`, `endpoint_geometry` and `check_endpoint_opening` are
  unchanged.
* `boundary.rs` pins "same".

Every pin of the two standalone block captures equals `2ea7221`. The draft
should say this.

Separately, raw 12-block 125M receipts exist
(`/home/victor/zk60-artifacts/m125-run-l12{,-dense,-tagged}/segment-*.bin`,
2026-09-20). They are not JSON captures, so §1.4(i)'s "not captured" stands,
but the bytes are there.

### F-8 — GS-4 small overstatements (note)

* "Every reserved row used exactly once" is measured on 14 openings (A, H,
  boundary), not 22. The endpoints record no uses. My X3 covers all 22.
* "Endpoint 1 group" is hard-coded (`&[1]`, `protocol.rs:389`), not a count
  the verifier checks.
* The replay's docstring says "a writer that declared the wrong rows cannot
  make the audit pass". That overclaims: `rows` and `data_rows` come from the
  capture. The draft's §1.4(iii) concedes the point.
* The Fp-basis leg of exclusivity is not in `audit_claims`, which checks only
  that coefficients are nonzero. It holds by `build_claim`
  (`argument.rs:382-384`). MEASURED (cm, cm·U) with cm ≠ 0 on all 30 views
  (X2).

### F-9 — GS-11: the fit is a named refusal, not only an assert (erratum)

Draft §3.4 item 1 says the fit is "an assert (a panic on a public,
shape-level condition, not a refusal) … (the gate's ruling C-4 figure)". This
is false since stage 24. Ruling C-4 is a named **construction refusal** in
shape validation (`shape.rs:610-647`: `lens[s] + MASK_PADS > MASK_MSG` →
`Err("… ruling C-4 …")`). `zk.rs:442/493` is a backstop. C-4 is the shape's
ruling, not the gate's. **Fix:** cite `shape.rs:610-647`.

### F-10 — GS-11: "three places and no others" misses four uses (note)

L_s or the shape also enters in four more places. None of them couples q' or
prox to the shape:

* `combined_weights` keeps W_s on [0, L_s) (`zk.rs:528-529`). This is what
  keeps V free of the pads.
* Each a-row message has a known-zero tail on [L_s + 256, 512)
  (`zk.rs:443-446`). This is harmless: 256 pads against ≤ 256 opened points.
* `CfsMask::random` draws 2·L_s words, which shifts the RNG stream
  (`zk.rs:434/485`).
* The NTT tables are sized by `ntt_log_at = max(log_cols + log inv_rate, 12)`
  (`protocol.rs:40-42`), which is 16 at 125M. Sub-size transforms nest, so
  this is harmless too.

"Every ingredient … is a constant of `zk.rs`" should read "… or a
shape-dependent input that provably does not enter". Also, `M-prox`'s
"independent of everything else in the view" should say that u's opened
columns are determined by prox (the next paragraph of the draft does say it).

Verified by me:

* `mask_commit` pins `b[512] = −b[0]` and draws u fresh (`zk.rs:452-457`).
* The main tree's and the lane's `zk.rs` agree on lines 1-468 (per the
  sub-checker; the first difference is at line 469).
* Declared `M` equals the constants on all 8 capture stages
  (`gs11_check.{py,json}`):
  - 50 rows, 23 slots;
  - q and prox of 1,024 each;
  - 48 proximity ρ;
  - 256 columns of height 50;
  - 34 functionals.
* Σ L_s and the largest L_s:
  - 1,239 and 117 at slot 17 at 125M, headroom 139;
  - 859 and 72 at rung-G, headroom 184.

### F-11 — GS-12: CS-3 guarantees table membership, not row 128 (erratum)

Draft §4.1 says "Item 5 makes the same true [that every padded activation
argument is table row 128] for every attempt that reaches the LogUp
challenges, for any witness". §5 item 5 says a nonzero padded
`A_G8` / `A_A16` "would be refused by CS-3". Both overclaim:

* `refuse_lookup_misses` (`protocol.rs:511-524, 960-967, 978`) refuses only
  pairs that are **not** table rows.
* A hand-made witness with padded (g8, a16) = (x, act[x + 128]), x ≠ 0, is a
  table row. It passes CS-3 and reaches the challenges.
* Only the verifier's pad-zero term (`argument.rs:1575-1581`) rejects it.
  There is no prover-side pad-zero check in `protocol.rs`.

N-3's |S| ≤ 768 bound needs only membership and is unaffected.

The draft's §0 "before the first commitment" is also loose. Inside a run the
boundary is committed first (M-9). §4.1's "before the first `A` mask draw" is
the right wording.

**Fix:** item 5 → "every attempt that reaches the LogUp challenges has every
activation pair in the table; row 128 at padded positions is the builder's
(item 2) and the pad-zero term's".

### F-12 — GS-12 at 125M: `Dom::F` is unpadded, but six other domains pad (note)

"Vacuous at 125M" is **correct for the activation family**: `Dom::F` =
512 × 2048, 0 of 1,048,576 positions padded. Re-measured in `gs12_check.json`
from the shape in `block.json`.

But six other domains do pad at 125M. The sub-checker read this from
`shape.rs` / `layout.rs`. I did not re-derive it, except for
`pad.rs:285-303`.

| domain | padded positions at 125M |
|---|---|
| `Ht` | 2,048 of 8,192 |
| `L` | 11,776 of 16,384 |
| `D` | 131,072 |
| `Q` | 131,072 |
| `S` | 1,048,576 of 2^22 |
| `Tab` | 16,128 of 16,384 |

What the lookups at those padded positions read:

* Padded u8 arguments read row 0 or row 127: Zero-rule planes plus
  constants 0 / 127 (`layout.rs:595-605`).
* The `S` domain's padded exp pairs are (0, exp[0]) or (127, exp[127]).
  `A_E` is **EXEMPT** from the pad rule (`pad.rs:299-301`, verified), so that
  fact rests on LogUp soundness plus CS-3's exp count
  (`protocol.rs:955-959`), not on the pad rule.

The draft's "beside GS-12" bullet covers the u8 and exp families by B-6 /
S-4 but does not state the exemption. This is not a GS-12 defect. It belongs
in the N-3 refinement GS-12 served.

### F-13 — GS-12 scripts count `Dom::F` padding without the P-3 lift (note)

`results/zk60_gs_closures/gs12_act_row128.py:91` counts padding as
`t_pad·f_pad − tokens·hidden`. `Shape::pads` also counts a domain enlarged by
the P-3 lift (`shape.rs:1297-1299`). The count is right at rung-G and 125M,
where `Dom::F` spans at least one row, but it would under-count at a shape
whose `Dom::F` is lifted. My `gs12_check.py` has the same limitation, and
says so.

---

## 2. What I did, gap by gap

**GS-5 (the part to attack first).**

* **Re-derivation.** I re-derived the whole theorem by hand, and each step
  holds:
  - Step 1 (pad change of variables; the pad halves' p′ part is redundant,
    and the block rank splits).
  - Step 2(a) and 2(b). The annihilator argument is right. The only view
    coordinates touching a pair row are the group vector, the proximity
    vector and the owner's value. On `H`, `SC_ZS`'s u-row weights touch
    rows in U, never N′, so they do not reach the pair-row equations.
    Tr(x·z) = 0 for z ∈ {1, U} ⇒ x = 0 holds by non-degeneracy of the
    trace form.
  - Step 3. The Kronecker split along Fp^n = H0 ⊕ ⟨e⟩ is right, and so is
    the identification u\* = dim(WΓ_D) − k0.
  - I also re-derived `encode_row_zk`'s polynomial (`pcs.rs:655-674`):
    f_msg + (x^n − 1)·Σ π_k x^k for every Q ≤ nn − n. So the draft's
    "including Q > n" is right.
* **Brute force.** `gf.py` is my own Goldilocks arithmetic: a numpy uint64
  multiply with the 2^64 ≡ 2^32 − 1 reduction, self-tested against Python
  ints. The elimination is self-tested against a pure-Python reference.
  `gs5_check.py` builds the whole view from scratch: every published value,
  both halves of every group and proximity vector, and every opened column
  on every row.
  - It covers **531 instances** in 27 case families (`gs5_summary.txt`).
  - The grid: (n, Q) ∈ {(4,4), (4,8), (4,12), (8,8), (8,2), (3,3), (3,9),
    (5,5), (5,2), (15,4), (16,1), (6,6)}, with d < Q as well.
  - The real 125M and rung-G group-size multisets of A and H (36 and 9
    groups, SC_ZS, the pairless sum claim), at n = 2 and 4.
  - The real 125M endpoint and boundary row geometry (37 and 38 rows, 32
    data) at n = 128, Q = 2, i.e. n/Q = 64 as at 125M.
  - The rung-G endpoint geometry (9 rows) at n/Q = 4 and 64.
  - The exact formula agrees on all 423 instances outside F-1's family. The
    gate's per-indicator formula agrees on all except F-3's 36.
* **The real 125M (n, Q, rows).** This is out of reach for a dense brute
  force (≈ 10^8 unknowns). The one real (n, Q, rows) geometry within reach,
  the rung-G endpoint commitment (9 rows, n = 1,024, Q = d = 256), is
  running detached under the heavy lock (`gs5_check_exact.{log,done}`). Its
  scaled twin (n = 256, Q = 64, same rows) reads disclosed 0 = formula on
  3 of 3.
* **The records.** I did not recompute the gate's 79 per-commitment
  figures. As the draft itself says, they are a consistency check.

**GS-4.**

* `gs4_check.py` is my own code over the verifier-side claim lists of 30
  views (22 at 125M, 8 at rung-G). It checks X1–X5, which exclusivity needs
  in full, including disjointness and coverage, plus (Π) from the array
  store, λ ≠ 0, and G1. There are 0 failures.
* The sub-checker diffed the transcription clause by clause (faithful). It
  re-ran the replay (byte-identical), demonstrated the gate gap (F-4) and
  added 13 controls (F-6).

**GS-11.** `gs11_check.py` measures the declared geometry on 8 stages. The
sub-checker verified every cited line, the tagged / untagged draw order, the
degree bound (≤ 1022, a 1024-point product NTT, no wrap) and the column
checks. I read `mask_commit` myself.

**GS-12.**

* `gs12_check.py` finds, on each of the four standalone captures, exactly
  one (table, β-index, γ-index) that inverts all 256 true rows to i16:
  table 9, β = challenge 0, γ = challenge 1.
* act[128] = 0, act[0] = 0 and act[255] = 32,512 on all four.
* The padded rows equal row i mod 256.
* The sub-checker verified every citation of §4.1 items 1–6, found no
  non-test `Witness` constructor other than `build_shaped`, and mapped the
  125M padding.

## 3. What I did NOT check

1. No Rust was built or run. Every Rust fact is a reading at `2ea7221`
   (plus the diff to `f4697f9`).
2. **No brute force at 125M's real (n, Q, rows).** The real 125M structure
   was tested only at reduced n, Q and data rows, and the endpoint / boundary
   row counts only at n/Q = 64. The exact rung-G endpoint run was
   **pending** when this page was written; see its marker.
3. The gate's 79 recorded figures, its `M` arm (b / u preimages, q′
   identities) and its `disclosed_fp_computed = 2` at 125M were not
   recomputed.
4. That the challenge replay in `check_opening_challenges` draws the same
   λ and ρ as `zk_rhos` was not re-verified. I read the proximity ρ the
   capture records.
5. The 125M padding picture of F-12, apart from `pad.rs:285-303`, and the
   line-by-line citation checks of GS-12 items 1–6 are the sub-checker's
   reading, spot-checked by me.
6. The draft's own scripts other than `gs4_audit_replay.py` were not re-run.
   Mine are independent replacements, not reproductions.
7. Out of scope, as in the draft: the joint view (GS-6), Fiat–Shamir
   (GS-7), the non-linear channel (GS-13), completeness (GS-14), the hash
   layer.

**Not a privacy acceptance.**
