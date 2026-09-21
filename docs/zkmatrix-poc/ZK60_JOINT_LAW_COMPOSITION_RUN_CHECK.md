# Independent adversarial check of the RUN joint-law memo

**Checker: a delegated Opus agent who did not write the memo and owes it
nothing.** 2026-09-20, 17:47 PDT (`date` read at 17:27 and again at 17:47
before anything below was written). Read-only against the lane worktree
`/home/victor/wt-zk60-block125m`, branch `zk60-private-block-125m`, tip
`caa9b9a` — **the code is the authority here, not the memo and not the
design pages**. Nothing was built, no cargo ran, no git write was made, no
existing file was edited. Evidence:
`results/zk60_joint_law_composition_run_check/` (two Python files written
from the lane source, sharing no code with the memo's own script, with a
README naming every source line each constant is transcribed from).

Target: `ZK60_JOINT_LAW_COMPOSITION_RUN.md`, drafted today.

---

## 0. First line

**Theorem B is not false.** Its proof is a correct reduction, and the two
conditions it hangs on (G-R1 and G-R2/G-R4) are honestly named. Every single
number the memo labels `[COUNTED]` reproduces exactly from the lane source on
an independent recount — all of them, including the two the memo corrects.

What is wrong is elsewhere, and three of those things matter.

1. **The memo's refusal inventory is incomplete for a run, and the omission
   is the one class that actually fires.** A run builds block `k`'s witness
   *inside* stage `k` (`run.rs:473`), after segments `0..k−1` are fsynced to
   disk. `witness::build_shaped` has fourteen refusal sites, twelve of them
   range or relation checks on hidden values. These are input-determined with
   probability **0 or 1**, not 2^-97.8. The memo's "the one refusal inside
   the proof that depends on a witness value" (§5.3) is true of a *block* and
   false of a *run*, and this — not the zero LogUp denominator — is what will
   put a half-run's segments on disk (G-R6).
2. **Finding R-F1 is mis-framed.** R-D4 is a *recommendation* in the design
   memo's own words, in a table whose column is headed "recommendation"; it
   appears nowhere in the disposition's ruling list M-1…M-8. The code does
   not differ from "the accepted design"; it declines an unratified
   suggestion. The finding survives — it is still a trade nobody recorded —
   but its force changes, and so does who has to act.
3. **The memo under-sizes what its own §3.8 discovered.** I computed it: a
   dependence between two *distinct* blinding rows whose *values* happen to
   coincide is scored **identically to the honest case** by the gate, while
   the real disclosed dimension is 1,024 `Fp` at rung-G — the same magnitude
   as the project's own alarm control C3. "Joint 0 = sum of parts" therefore
   tests that the gate's model has disjoint coordinate classes, which is true
   by construction of the model. G-R4 is the only thing between that result
   and a leak, and G-R4 now rides on one generator stream.

Four further items are wrong or mis-sized: G-R3 (the ideal world at 125M) is
called engineering and is mathematical; a `[COUNTED]` challenge count exceeds
the number of draw sites in the code; two citations were copied from the
design memo without re-checking, in the section that claims a line-by-line
re-read; and Corollary R.3 names one of the three conditions the
terminal-surjection proposition travels with.

Three things in the memo are *stronger* than it claims, and I say so in §3.
One of them is a result the memo left on the table: the 29,800-per-block draw
delta it reports and does not explain is **two** errors in the design's count
that partly cancel, and I name both (**B-8**). The memo's figure is right; the
design's, and the independent recount that confirmed it, are wrong.

---

## 1. Verdict table

| # | the memo's claim | verdict | why, in one line | `file:line` |
|---|---|---|---|---|
| 1 | Theorem B: the run's joint field law factorises over stages, adding no new step | **HOLDS WITH CHANGE** | the reduction is valid; it needs one hypothesis the theorem does not state, which I verified holds by construction | `protocol.rs:674`, `:780`; `run.rs:483` |
| 2 | Every slot of block `k` is masked only by `M_k`'s coefficients, and `M_k` is opened once in stage `k` | **HOLDS** | `prove_core` builds its own `MaskCommit` per call and hands only `mc.masks` to the slot loop; a run-wide `M` is not reachable | `protocol.rs:674`, `:780`, `:790` |
| 3 | `B_k`'s single opening batches claims from two stages, and the per-stage product law survives it | **HOLDS** | the opening's group vectors are functions of `B_k`'s own rows only; the cross-stage coupling is through `π`, which the proof conditions on first | `run.rs:487-500`; `boundary.rs:269-275`; `argument.rs:248-262` |
| 4 | Nothing published is a function of blinding from two different stages, in `V_pcs` | **HOLDS** | slot-`22`/slot-`21` terminals are `(1−e)·data + e·mask_eval` of ONE commitment each; the mixing is in the round messages, which are `V_sc` | `argument.rs:236-245`, `:341-351`, `:398` |
| 5 | Corollary R.2: three commitments over one plane is a shared *data* coordinate, not a shared blinding one | **HOLDS** | verified in code and reproduced in my own rank miniature (joint 0 = sum 0) | `rank_probe.txt` case H |
| 6 | Corollary R.3: two claim sites on one commitment, REDUCED to the terminal-surjection proposition + the derived row count | **HOLDS WITH CHANGE** | the reduction is right but names one of three travelling conditions; and it can be PROVED outright, not merely reduced | finding **B-6** |
| 7 | The boundary is the only zero-slack commitment (`6` generators, `6` free rows) | **HOLDS** | recomputed: A 172, H 82/86, endpoint 1, boundary **0** | `recount.txt` §5 |
| 8 | Finding R-F1: one stream, 47 of 49 commitments, against ruling R-D4 | **HOLDS WITH CHANGE** | the code facts are exact; R-D4 is a *recommendation*, never a ruling | finding **B-2** |
| 9 | "It costs nothing in Theorem B, and costs in the real-prover statement" | **HOLDS** | correct, and the real-prover cost is larger than the memo says — see B-3 | finding **B-3** |
| 10 | "It does not make the assumption adaptive" | **HOLDS WITH CHANGE** | true of the *draw*; the witness source is a per-stage interface, so non-adaptivity of the *input* is an operating condition, not a code fact | `run.rs:387-396`, `:461`, `:473`, `:529` |
| 11 | "Three OS reads per run, all before stage 1"; O-R4's "49 calls … six minutes in" is wrong | **HOLDS** | one `from_os` in `prove_run`, one per external endpoint in the caller | `run.rs:436`; `endpoint_g.rs:224` |
| 12 | Only one refusal inside the proof depends on a witness value | **BROKEN** | a run builds each witness inside its stage; twelve input-determined refusal sites now fire mid-run | finding **B-1** |
| 13 | Finding R-F2: 2^-97.8 for a twelve-block 125M run, not 2^-108.4 | **HOLDS** | 103,890,944 denominators reproduced exactly from `grow_tests.rs` + 3·`size(Dom::Tab)`; 12·that / 2^128 = 2^-97.78 | `recount.txt` §3 |
| 14 | Challenge-only liveness is `(3L+1)/p` = 2^-58.79 at `L = 12` | **HOLDS** | `3L+1` openings carry a proximity determinant; `M`'s does not | `protocol.rs:289-290`, `:298-307`; `zk.rs:563` |
| 15 | Finding R-F3: 109,728,040 draws, residual 2^-69.3, "0.33 % above the quoted 109.4 M" | **HOLDS, upgraded** | reproduced exactly; I located the 29,800 — the design omits H's zero-sum re-draw (−32,766) and bounds `ΣL_s` by `23×117` (+2,966) | finding **B-8** |
| 16 | G-R3, no all-zero run at 125M, "a small one: an engineering item" | **HOLDS WITH CHANGE** | there is no all-zero test at 125M at all, and the zero witness sits on two exact range boundaries whose constants moved at 125M | finding **B-4** |
| 17 | G-R7: a per-boundary declared scale is a published word about a hidden intermediate; "fine today" | **HOLDS WITH CHANGE** | the precision (never absorbed) is exactly right and its consequence is stronger; "constants of the statement" is a fact about the tests, not the code | finding **B-5** |
| 18 | §2.2: "new challenges ζ, 8 at rung-G" `[VERIFIED IN THE CODE]` | **BROKEN** (small) | the code has **seven** ζ draw sites — the seven the memo itself lists | finding **B-7** |
| 19 | §1.3 "Re-read line by line against the code", citing `pcs.rs:835-856` for `zk_rhos` | **BROKEN** (small) | `zk_rhos` is `zkp-core/src/pcs.rs:943`; `835-856` is the `ZClaim`/`ZKey` declarations; the citation was copied from the design memo | finding **B-9** |
| 20 | §2.6: the endpoint's fifth row is the only spare, `data+3` is load-bearing | **HOLDS** | `check_opening_challenges` takes `det(rho[prox], rho[prox+1])` with `prox = data+2` | `protocol.rs:276-278`, `:289-290`, `:356`, `:368` |
| 21 | §2.6's rider that the spare's harmlessness beyond rank rests on `H-pad` | **HOLDS, and closes in the memo's favour** | `ZkOpts::standard` sets `q_pad = num_col_checks` and the indices are drawn with replacement, so distinct opened ≤ pads at every shape | `zkp-core/src/pcs.rs:579-580`, `:721` |
| 22 | §2.1: `L_s` and `dim C_s` move together by construction, zero slack at every shape | **HOLDS** | `slot_lengths = (main+ext)·deg + 2` from the same triple that sets the published values per round | `shape.rs:662-669`, `:603-648` |
| 23 | §2.1: the worst `L_s` at 125M is 117, not 94 | **HOLDS** | `MODEL_M125.largest_slot_length = 117` | `grow_tests.rs` `MODEL_M125` |
| 24 | §1.2: framing is 120 B per segment | **HOLDS** as a fact; as an advertised code-vs-design difference it is **stale** | the disposition's as-built section already records 120 and says the counted totals use it | `wire.rs:263`, `:265`; `…RUN_MULTI_BLOCK_DISPOSITION.md:159`; finding **B-10** |
| 25 | §4.2: the position tags are squeezed from a clone carrying state, counter and key only | **HOLDS** | citation exact at this tip | `zkp-core/src/transcript.rs:156-162` |
| 26 | §3.4 table, H row: "102 (125M) / 106 (rung-G) **+ the zero-sum pair**" | **BROKEN** (cosmetic) | the zero-sum pair is *among* the 102/106 | `protocol.rs:757-771` |
| 27 | §1.4: no claim structure or value beyond the published terminals is on the wire | **HOLDS** | the verifier builds both claim lists from terminals, outside the prove/verify match | `run.rs:578-581`, `:622-631`; `argument.rs:395-401`; `wire.rs:286-289` |
| 28 | §3.8: "joint 0 = sum" is the linear-channel instance of Proposition R.1, verified at two challenge vectors | **HOLDS WITH CHANGE** | true, and materially weaker than §3.4's presentation of it — computed | finding **B-3** |
| 29 | §5.4: a refusal is terminal and the written segments stay | **HOLDS** | no retry, endpoints consumed on failure, `PreparedBoundary` consumed, atomic rename, no statement file | `run.rs:423`, `:431`, `:529`; `boundary.rs:269`; `run_sink.rs:181-202` |
| 30 | (H6^run), the hash-layer hand-over, and the one-argument composition | **UNVERIFIABLE-HERE** | correctly labelled a gap (G-R5); nothing to check | — |
| 31 | (H1^run) at either new shape | **UNVERIFIABLE-HERE** | the generic-rank lemma does not exist at these layouts (ruling G-2); correctly labelled G-R1 | — |

---

## 2. Findings, most serious first

### B-1. The one input-dependent refusal is not the one; a run moves the witness builder inside the loop. **BROKEN.**

**The memo (§5.3):** *"The one refusal inside the proof that depends on a
witness value is the **zero LogUp denominator** (`protocol.rs:403` …). Its
probability is (number of inverted denominators) over `|Fp2|`."* And §5.1
presents its inventory as complete: *"A run adds, per internal boundary, 28
distinct refusal sites … **Exactly two of the 28 are challenge-only**."* The
memo does notice the witness builder once and dismisses it: *"there is no
refusal enum in the code, and `private_block/refusals.rs` is a **test**
module about the witness builder's sites only."*

**The evidence.** `refusals.rs` is a test module; the *sites* are not.
`witness.rs` has fourteen `return Err` sites, and twelve of them are
functions of hidden values:

```
witness.rs:290   range(site)                          requant out of class
witness.rs:374   range("norm denominator")
witness.rs:386   range("norm denominator")
witness.rs:394   range("norm quotient/remainder")
witness.rs:526   "fixed oracle relation failure: causal maximum attainment"
witness.rs:534   range("exp difference")
witness.rs:542   "fixed oracle relation failure: softmax denominator"
witness.rs:555   range("softmax quotient/remainder")
witness.rs:600   range("residual 1")
witness.rs:640   range("exp difference")
witness.rs:672   range("FFN up")
witness.rs:708   range("residual 2")
```

For a **single block** these fire in the caller: `prove_inner_at` takes
`wit: Witness` already built (`protocol.rs:477`), so a range failure happens
before anything public exists — which is why the block's inventory can
truthfully say the zero LogUp denominator is the only one.

For a **run** it is the opposite by design. `RunWitnessSource` is documented
as *"the private inputs of a run, asked for ONE STAGE AT A TIME so that a
twelve-block run never holds twelve witnesses"* (`run.rs:387-390`), and the
prover calls it inside the stage loop:

```rust
let plane = src.boundary_plane(k)?;   // run.rs:461
let wit   = src.witness(k)?;          // run.rs:473
…
sink(k, bytes)?;                      // run.rs:529  segment k leaves, fsynced
```

So at stage 7 of a twelve-block run the prover can discover that the chained
hidden intermediate is out of the int8/int16 class — after six complete
segments are on disk under their final names (`run_sink.rs:181-202`).

**Why it matters, in three ways.**

* It is **not** a 2^-97.8 event. It is a deterministic function of the
  hidden input: probability 1 for an inadmissible chain, 0 for an admissible
  one. Any statement that says a run's refusal channel is "challenge-only up
  to 2^-97.8" is false unless *admissibility of the whole chain* is a
  precondition established before the first segment is flushed.
* It is the **likely** trigger of G-R6's partial directory, and G-R6 is
  presently justified by a 2^-97.8 event. The memo's own sentence — *"they
  contain stages `1..k−1` of a run whose refusal at stage `k` is — with
  probability up to the figure of §5.3 — input-dependent"* — understates by
  ninety-seven bits for this class.
* It makes "admissible hidden run input" a **joint** condition on all `L`
  stages that the honest prover cannot check at stage 1 without running the
  whole forward pass first. §3.2's *"the construction only needs
  admissibility at every stage, which the chained construction gives by
  definition"* is a definition, not a procedure.

**Smallest repair.** (i) §5.1 gains a row: *witness-build refusal at stage
`k`, input-determined, terminal, leaves `k−1` complete segments*, with the
twelve sites. (ii) §5.3's headline becomes "the one input-dependent refusal
**inside the argument**". (iii) G-R6 is re-sized and gains an operating
condition of D21's shape, which is the security owner's: **a run's chain is
built and range-checked for all `L` stages before segment 0 is handed to the
sink**, or the sink buffers until stage `L` succeeds. One of those two is a
code change of a few lines; the other is a rule.

### B-2. R-D4 is a recommendation, not a ruling; "the code and the accepted design differ" is not what happened. **HOLDS WITH CHANGE.**

**The memo (§3.5):** *"**Finding R-F1. The code and the accepted design
differ, and the difference is privacy-relevant.** **Ruling R-D4** of
`ZK60_PRIVATE_RUN_MULTI_BLOCK.md` §8.1 recommends …"* and step 22 of §7.1:
*"**Finding R-F1**: the code and ruling R-D4 differ."*

**The evidence.** R-D4 lives in §8.1's decision table whose third column is
headed **"recommendation"**, and its cell reads *"One `ZkRng::from_os` per
commitment"*. It is confirmed by the independent check (*"R-D4 … is the right
call and the draft is honest that it does not prove O-2. No objection."*) —
and it appears **nowhere** in `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md`'s
ruling list, which runs M-1 … M-8 and says nothing about randomness. The
security owner has never ruled on it. Calling it "Ruling R-D4" and "the
accepted design" is wrong twice in one sentence, and it is the load-bearing
sentence of the memo's headline finding.

**What survives, and it is the useful part.** The code facts are exact and I
confirm every one: one `ZkRng::from_os` at `run.rs:436`; the same `rng`
handed to every boundary (`run.rs:465`) and every stage (`run.rs:483`);
`boundary.rs:306-314` states the choice and its reason in as many words; only
the two external endpoints keep their own (`endpoint_g.rs:224`); `ZkRng` is a
counter-mode keyed BLAKE3 stream with no reseed and no per-commitment domain
separation (`zkp-core/src/rng.rs:44-61`). 47 of 49 on one stream is right.

**Smallest repair.** Re-word R-F1 as *"the code declines an unratified
recommendation, for a stated reason, and nobody has ruled"* and put it to the
security owner as a pending ruling beside G-R6 and G-R7. The trade is real:
one fail-closed entropy point (a genuine liveness property, §5.4) against
`L + (L−1)` OS reads that would make cross-block independence
information-theoretic. That is a ruling, not a finding.

### B-3. "Joint 0 = sum of parts" tests strictly less than the memo's §3.4 implies, and I can put a number on the gap. **HOLDS WITH CHANGE.** `[COUNTED]`

**The memo (§3.4):** *"Corollary R.2 … the gate obeys it: it ranks all three
roles as one system, 154 × 1,248, **joint 0 = sum of parts** on both
boundaries of both runs."* §3.8 does add the right caveat — *"the gate's 'no
blinding source is shared' is a statement about coordinate classes in its
model"* — but it is the fifth bullet of a list of things the gate "cannot
test", after four weaker ones.

**The evidence** (`rank_probe.py`, a miniature of the gate's own criterion
`disclosed = rank([G_b | G_d]) − rank(G_b)` over one message position of one
boundary plane held by three roles):

| case | per-role disclosed | sum | joint | does the gate see it? |
|---|---|---:|---:|---|
| **H** honest | A_k 0, B 0, A_{k+1} 0 | 0 | **0** | — |
| **S** a blinding ROW shared between `B`'s site-1 pair and `A_{k+1}`'s pair | 0, 0, 0 | 0 | **1** per position | **yes** — this is control C3 |
| **V** two **distinct** rows whose **values** the generator makes equal | 0, 0, 0 | 0 | **1** per position, in truth | **no** |
| **P** the 37-row boundary (one proximity row) | 0, **1**, 0 | 1 | 1 | yes — control C2, ruling M-1 |

The model is calibrated: case S at one position × 1,024 rung-G message
positions = **1,024**, which is exactly the gate's own C3 figure, and case P
reproduces ruling M-1's "discloses 1". Case **V** is the point. The gate
assigns distinct rows distinct free symbols and never looks at a value, so
its generator matrix in case V is case H's. It reports joint 0 = sum 0. The
true disclosed dimension is case S's.

**So**: "joint = sum" is a theorem about the *model's* coordinate classes,
and the model's coordinate classes are disjoint **by construction of the
model**. What separates the gate's green light from a 1,024-dimensional leak
at rung-G is exactly Proposition R.1 hypothesis (ii) — G-R4 — which the code
now carries on one BLAKE3 stream with no per-commitment domain separation.
The two facts belong in the same paragraph, and in the memo they are
forty lines apart with the encouraging one first.

**Smallest repair.** Move the sentence into §3.4 beside the gate figure, with
the number: *the gate's model cannot distinguish independent blinding from
equal-valued blinding; a coincidence of two reserved pairs would score 0 and
disclose 1,024 `Fp`.* Then G-R4's "the one thing that would close it cheaply
— a stream-segment accounting test" becomes visibly the cheapest thing on the
whole list, because it is the only check that looks at stream *positions*
rather than at row *labels*.

### B-4. G-R3 is mis-sized: it is not an engineering item, it is whether the ideal world exists at 125M. **HOLDS WITH CHANGE.**

**The memo (§3.2, step 17):** *"**No all-zero run has been proved at 125M.**
[GAP G-R3, a small one: it is an engineering item, the same half-day the
toy's was.]"*

**The evidence.**

1. There is **no all-zero test at 125M at all** — not a run, not a block. The
   only callers of the helper are `Shape::rung()` and `Shape::rung_g()`
   (`rung_tests.rs:175`, `:181`), and `zero_witness_tests.rs:59` is the toy.
   The memo's §3.2(b) chain — "the block is zero-preserving, therefore every
   boundary plane of an all-zero run is all zero" — is established at rung-G
   and at the toy and nowhere else.
2. The zero witness is **not generic**. `zero_witness_tests.rs:100-145` says
   so in its own header: *"the zero witness sits EXACTLY on two range
   boundaries at once … so a one-bit change in `WRHO_S`, in `F_E`, or turning
   `0..=1 << F_P` into `0..1 << F_P` would invalidate the fixed input while
   every ordinary witness stayed valid"* — `sigma_s = 16,383` of an exclusive
   `16,384`, **headroom exactly zero**, and `p = 512` of an inclusive `512`.
3. **125M moved one of exactly those constants.** The memo's own §2.5 says
   `limbs_sigma_s = ceil(wrho_s / 8)` (`shape.rs:431-433`) is 2 at the toy and
   **3** at both new shapes — i.e. `wrho_s` is not the toy's, so the window
   `2^WRHO_S` the zero witness sits one below is a different window. The
   layout disposition's P-5 additionally corrects the norm arithmetic
   (`wrho` 29, three limbs for `D`).

So the question is not "run the half-day job". It is: **does the fixed input
of the ideal world exist at the shape the memo is about?** If it does not,
D18's ideal-world program has to be a different input, and the privacy case's
step 2 changes shape. That is a mathematical prerequisite of the whole
construction, not an engineering chore, and the test that would settle it is
the one the project already wrote and never called at 125M.

**Smallest repair.** Re-label G-R3 **mathematical, blocking for any 125M
statement**, and state the precondition explicitly: *the all-zero chain must
be admissible at the 125M shape at every one of the `L` stages, and the two
range boundaries must be re-derived at that shape's `WRHO_S` and `F_P`.* One
call of `the_all_zero_hidden_input_proves_at(&Shape::m125(), …)` settles the
block half.

### B-5. G-R7 is right and its consequence is stronger than "fine today". **HOLDS WITH CHANGE.**

**The memo (§7.3):** *"Today the scales are constants of the statement (0 in
every test), which is fine."* And the precision: *"that digest is **never
absorbed into the run transcript**."*

**The evidence.** The precision is exactly right and I confirm it: the header
absorbs `run-shape`, `expected-IO`, `public-statement`, `parameters`,
`calibration`, `schedule` (`run.rs:276-281`); `parameter_line`
(`run.rs:195-207`) and `stage_line` (`run.rs:213-227`) carry no scale; and
what is absorbed at a boundary is the root, the row count and the row width
only (`protocol::absorb_root`, `run.rs:466`). `BoundarySpec::digest()` does
carry the scale (`boundary.rs:227`) and is never absorbed anywhere.

Two things follow that the memo does not draw.

* **The scales are a caller argument, not a constant of anything.**
  `RunStatement::new(…, block_scales: &[(i32, i32)])` (`run.rs:113`) takes
  them from whoever builds the statement; the only checks are that adjacent
  blocks agree (`run.rs:120-129`) and that the two *external* scales match the
  endpoint policy (`run.rs:130-133`). Nothing ties an interior scale to
  `calibration_identity()`, which is a fixed literal
  (`private_block.rs:198-200`) covering no scale. "Constants of the statement
  (0 in every test)" is a fact about the tests.
* **Nothing in the receipt binds them.** Since no interior scale reaches the
  transcript, one receipt verifies under every interior scale vector a
  statement file cares to declare. The memo assigns the correctness half to
  O-R8/D12 item 5, which is about *tying scales to the approved calibration*;
  this is a different and larger statement — the proof does not bind the word
  at all.

**Smallest repair.** Keep G-R7, raise it to the same class as G-R6 (a ruling
the security owner owes, not a note), and add the second sentence: *an
interior boundary scale is a published word that no part of the proof binds;
until it is absorbed, the condition "the declared scales are a function of
the approved calibration and the public statement, never of the input" is the
only thing standing between a run statement and a published function of the
hidden activations.*

### B-6. Corollary R.3 names one of three travelling conditions — and can be upgraded from REDUCED to PROVED. **HOLDS WITH CHANGE.**

**The memo (§3.4):** *"**REDUCED to `ZK60_TERMINAL_SURJECTION_REVIEW.md`
§1.4** … **plus the derived row count.** Disjointness is enforced by
`audit_claims`' `uses[r] == 1` check (`protocol.rs:271`)."*

**The evidence.** The corrected proposition travels with three conditions,
not one: (i) reserved pairs disjoint **across groups**; (ii) the proximity
pair exclusive, with a non-vanishing wedge; (iii) the pad budget. The memo
names (i). All three are in fact enforced, which is why this is a re-wording
and not a hole:

* (i) `protocol.rs:270-272`, `uses[r] != 1` refused by name — and
  `boundary.rs:597-607` is the test that a shared pair is refused on the
  opening path.
* (ii) `audit_claims` refuses a claim that reaches the proximity pair
  (`protocol.rs:241-243`) and refuses a mis-placed pair
  (`protocol.rs:232-233`, `prox + 2 != rows`); the wedge is
  `determinant(rho[prox], rho[prox+1]) != 0` (`protocol.rs:276-278`,
  `:289-290`).
* (iii) `ZkOpts::standard` sets `q_pad = params.num_col_checks`
  (`zkp-core/src/pcs.rs:579-580`) and the opened positions are
  `num_col_checks` indices drawn **with replacement**, so the number of
  distinct opened columns is **≤ the pad count at every shape, structurally**.
  This also closes the memo's own §7.2 item 4 in its favour: the pad budget
  cannot be exceeded under `ZkOpts::standard`, at any shape, ever.

**And an upgrade the memo leaves on the table.** With those three, the
boundary's `6 × 6` system is block-triangular with invertible diagonal — group
0's two published `Fp` see only site-0's pair, group 1's only site-1's, and
the proximity pair is reached only by the proximity vector whose `2 × 2`
block is the refused determinant. The code says exactly this, in the audit's
own doc comment: *"the map from (one pair per group, the proximity pair) to
(group vectors, proximity vector) is block triangular with invertible
diagonal, so the opened vectors are jointly uniform whatever the data is"*
(`protocol.rs:220-229`). That is a **proof** of the boundary's per-role
statement at every non-refused challenge, not a rank measured at two. The
memo labels the boundary MEASURED at rung-G (step 21) and REDUCED (step 20);
it can be PROVED HERE, which is the only per-commitment statement in the
whole run that can be.

### B-7. A `[VERIFIED IN THE CODE]` challenge count exceeds the number of draw sites. **BROKEN** (small).

**The memo (§2.2 and §5.1):** *"new **challenges** `ζ` (refused on zero) |
**8** | **5** | `argument.rs:931, 998, 1124, 1199, 1252, 1310, 1385`"*, and
*"**8 slots at rung-G, 5 hosting slots at 125M**"*, and the same 8/5 for
`mu_pad`.

**The evidence.** The memo lists **seven** line numbers and then says eight.
There are exactly seven `ζ` draw sites in `argument.rs`, each drawing one
`Fp2` under a `pad_on` guard:

```
931   let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
998   …  1124  …  1199  …  1252  …  1310  …  1385
```

so at most **seven** `ζ` challenges at any shape. (The refusal itself,
`argument.rs:735-740`, is cited exactly right.) Separately, the memo's *other*
count in the same table — "all **8** at rung-G, only **6** at 125M" for the
degree rise — is a count of `INDICATOR_SLOT_DOMAIN`, which has eight entries
(`shape.rs:65-66`) of which `Dom::Kv` and `Dom::F` do not pad at 125M. Those
are two different objects with two different counts and the memo runs 5, 6
and 8 together without saying so.

**Smallest repair.** Split the row: *hosting slots that draw a `ζ` (≤ 7 by
construction)* and *indicator slots that gain a degree (8 at rung-G, 6 at
125M)*, and recount the first at rung-G.

### B-8. Finding R-F3 is right, and it is bigger than the memo says: I located the 29,800, and it is two errors in the design's count that partly cancel. **HOLDS, upgraded.** `[COUNTED]`

**The memo (§6.1):** *"Counted from the code's own formulas the figure is
**109,728,040** — 0.33 % higher. **The residual is 2^-69.3 under both**, so
nothing quoted anywhere changes; the count is corrected for the record."*

**The evidence, in three steps** (`recount.txt` §1, §4b, §4c).

1. **I reproduce the memo's figure exactly**, term by term, from the lane
   source with a script sharing no code with the memo's: at 125M,
   `A` 5,484,800 + `H` 3,493,888 + `M` 18,288 + H's zero-sum re-draw
   32,766 = **9,029,742**, and
   12·9,029,742 + 11·108,032 + 2·91,392 = **109,728,040**. The salt figure
   2,473,984 also reproduces exactly (the memo said it had not recounted it).
2. **The toy control settles which formula is right.** The same formula gives
   the toy `A` 178,432 + `H` 124,928 + `M` 17,038 + zero-sum 510 + two
   endpoints 6,144 = **327,052**, which is D9's own accepted, ruled figure to
   the draw. **Drop the H zero-sum term and it is 326,542 and the control
   fails.** So the term is required, and the term is real code:
   `protocol.rs:757-759` fills every row from `h_mask_base` with `rng.fp()`,
   and then `:760-768` **re-draws** the two zero-sum rows, `n − 1` fresh
   values each.
3. **Therefore the delta has a name, and it is two names.**

   ```
   this recount (and the memo)                       9,029,742
   − H's zero-sum re-draw 2(n−1)                       −32,766   protocol.rs:760-768
   + M with ΣL_s bounded by 23 × 117 instead of 1,208   +2,966   RUN.md:1376-1378
   = the design memo's figure                         8,999,942   ✔ exact
   ```

   The design's own text announces the second error — *"the masking
   commitment's coefficient count depends on the per-slot message lengths
   `L_s`, **bounded here by `23 × largest_slot_length`**"* — and is silent on
   the first. 23 × 117 = 2,691 against the true ΣL_s = 1,208.

**Why this is worth more than "corrected for the record".** The design's
figure was **independently recounted and confirmed** (*"The independent check
re-derived it and confirms it (`run_recount.py`)"*, and that recount was good
enough to find and fix a *different* bug in the design's script, correction
C9). Two independent counts, both missing the same real term, because both
used the per-commitment formula `(rows − data)·n + rows·q` and neither
noticed that `H` alone draws twice for two of its rows. That is a method
finding about the project's counting, not a bookkeeping nicety — and the memo
had everything needed to see it, because its own script reproduces the toy's
327,052, which is only reachable *with* the zero-sum term.

**Smallest repair.** Replace R-F3's "0.33 % higher … corrected for the
record" with the three-line reconciliation above, and add the toy control as
the reason the memo's formula is the right one. The residual is 2^-69.3 under
both figures and nothing quoted anywhere moves — that part of R-F3 stands.

### B-9. Two citations were copied from the design memo into a section that claims a line-by-line re-read. **BROKEN** (small).

**The memo (§1.3):** *"`ZK60_PRIVATE_RUN_MULTI_BLOCK.md` §2.7 tabulates 'every
challenge and what it must follow'. **Re-read line by line against the
code**"* — and the table's row *"each opening's group `lambda`s and proximity
rho | `pcs.rs:835-856`"*, repeated in §2.6 (*"`zk_rhos` draws a proximity rho
over **every** row, `pcs.rs:835-856`"*).

**The evidence.** `fn zk_rhos` is at `zkp-core/src/pcs.rs:943-962`.
`zkp-core/src/pcs.rs:835-856` is the declaration of `ZClaim` and `ZKey`.
`pcs.rs:835-856` is exactly the citation the design memo's §2.7 table carries,
so the row was transcribed, not re-read. Same class: `pcs.rs:673` is cited for
the pad-draw formula in §6.1 and is `ntt.forward(out)`; the draws are
`hashline/src/pcs.rs:90-91` and `zkp-core/src/pcs.rs:725-726`. And
`shape.rs:638` is cited for the indicator's degree rise and is
`Some(dom) => self.log(dom)`; the rise is at `shape.rs:648`.

**None of the substance moves** — `zk_rhos` does draw `challenge_fp2_vec(rows)`
over every row including the spare, in exactly the transcript order
`check_opening_challenges` replays, and the pad formula is right. The memo's
other citations are unusually precise (`transcript.rs:156-162`,
`rung_tests.rs:184-192`/`:187-188`, `argument.rs:735-740`, `shape.rs:662-669`,
`boundary.rs:180-182`/`:146-151`, `endpoint_g.rs:52` all land exactly), which
is why the three that were inherited stand out. §7.2 item 8's confession
("three of its inputs are second-hand") should name the citations too, not
only the counts.

### B-10. The framing "difference" is stale: it was closed before the memo was written. **Not a difference.**

The memo states *"Framing is therefore **120 B per segment**"* (§1.2) as a
plain fact and repeats it in §4.2, and I confirm it: `RUN_HEADER = 8 + 32 + 8
+ 8 + 32 = 88` (`wire.rs:263`) plus `RUN_TRAILER = 32` (`wire.rs:265`).

The design specified something else — R-D6 asks for *"a 96-byte header and a
40-byte trailer"* and ruling **M-6** says *"the draft counted 40 bytes of
framing and specified 136; the byte-exact acceptance test uses the specified
figure"*. But the **same disposition's as-built section already records the
change**: *"framing is 120 bytes per segment and the counted totals use it"*
(`ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md:159`, ruling on finding U-3,
written 2026-09-20 before this memo). So 136 → 120 is settled, and there is
nothing left to report.

The memo's own headline nevertheless lists "120-byte framing" among four
places where *"code and design differ"*, and the memo's text never names what
it differs from. Net effect of B-2 and B-10 together: of the four advertised
differences, one (the framing) was already closed, one (R-D4) is against a
recommendation rather than a ruling, and two (three entropy reads, `L_s` 117)
are exactly right. The headline should say two.

### B-11. Two smaller things.

* **§3.4's H row double-counts.** *"`H_k` … free non-data rows 102 (125M) /
  106 (rung-G) **+ the zero-sum pair**"*. The zero-sum pair is inside the
  102/106: `protocol.rs:757-759` fills every row from `h_mask_base`, `:760-768`
  rewrites the two zero-sum rows, and `:771` declares
  `mask_rows = h_site_rows ++ h_u_rows`. Recount: 7,120 − 7,018 = 102 at 125M,
  576 − 470 = 106 at rung-G, slack 82 and 86.
* **"It does not make the assumption adaptive" is about the draw, not the
  input.** The claim is right for `ZkRng`: the stream is fixed at `from_os`
  and no draw count depends on a witness value, so stream positions are a
  compile-time fact. But the memo's supporting sentence — *"nothing anyone
  does between segments changes a later draw"* — sits next to a per-stage
  witness interface (`run.rs:391-396`) whose `witness(k)` and
  `boundary_plane(k)` are called *after* segment `k−1` has been handed to the
  sink (`run.rs:529`). Non-adaptivity of the hidden *input* across stage
  boundaries is therefore an operating condition on the driver, not a code
  fact, and it belongs in the conditions list beside the reseeding note the
  memo already wrote.

---

## 3. Three places the memo is stronger than it says

Recorded because an adversarial check that only subtracts is dishonest.

1. **Every `[COUNTED]` figure reproduces exactly.** I recounted all of them
   from the lane source with a script sharing no code with the memo's:
   the draw counts (686,990 / 9,029,742 per block, 8,704 / 108,032 per
   boundary, 7,424 / 91,392 per endpoint, 2,093,226 / 8,354,472 / 27,488,074
   / 109,728,040 per run), the residuals (2^-75.0 / 2^-73.0 / 2^-71.3 /
   2^-69.3), the salt count (2,473,984), the published field words
   (1,375,206 and 59,695,840 — and 59,695,840 × 8 = 477,566,720 B against the
   measured 484,100,736 B receipt), the round-message words (1,034 and
   1,519), the terminals (176 and 174), the LogUp denominators
   (64,768 / 439,296 / **103,890,944**) and their probabilities
   (2^-112.02 / 2^-109.26 / 2^-101.37 per block; **2^-97.78** at `L = 12`),
   the liveness ladder (2^-62.00 / 2^-60.68 / **2^-58.79**), and the slack
   table (A 172, H 82/86, endpoint 1, boundary **0**). The toy controls
   (327,052 draws → 2^-77.7; 64,768 → 2^-112.0) come out right too, which is
   the method check the memo claimed and I can now confirm from outside it.
2. **§7.2 item 2 — "verify the rejection of a run-wide `M` is enforced, not
   merely recommended" — is closed in the memo's favour.** It is enforced by
   construction, not by a check: `prove_core` builds its own `MaskCommit`
   (`protocol.rs:674`), hands only `mc.masks` to the slot loop
   (`protocol.rs:780`), and opens and drops it in the same call
   (`protocol.rs:790-791`); `prove_run` calls `prove_core` once per stage
   (`run.rs:483`). There is no path by which a slot of stage `k` reads a
   coefficient committed in stage `j ≠ k`. The factorisation's load-bearing
   premise is a type-level fact. **Theorem B should state it as a hypothesis
   and mark it PROVED, rather than leave it inside the proof's prose.**
3. **§7.2 item 4 — the spare row and the pad budget — is closed in the
   memo's favour, at every shape.** `ZkOpts::standard` sets
   `q_pad = num_col_checks` (`zkp-core/src/pcs.rs:579-580`), the commitment
   asserts `q_pad >= num_col_checks` (`:721`, `:774`), and the opened
   positions are `num_col_checks` indices drawn with replacement, so the
   distinct opened count is `≤` the pad count structurally. The rung-G
   measurement of "243–251 distinct inside 256" is a consequence, not a
   coincidence, and it will hold at 125M without being measured.

---

## 4. The refusal figures, and whether 2^-97.8 is compatible with what is written

The task asked specifically. Three separate points.

* **The like-for-like correction is right.** D22 as worded says *"refusal is
  challenge-only up to **2^-112**"* — and 2^-112.02 is the toy's **raw**
  denominator count (64,768 / 2^128), not its distinct-value count. So D22
  uses the raw bound, the memo's 2^-97.78 is the raw bound at 125M × 12, and
  the comparison is apples to apples. A run statement written in D22's
  sentence shape would read *"refusal is challenge-only up to 2^-97.8"*.
  Finding R-F2 stands.
* **But D22 does not cover a run, at all.** Its own text: *"It covers NOTHING
  else: not the development rung, not the 125M block, not any multi-block
  run."* Nothing here narrows that and the memo is right to say so.
* **The bound is loose in a way that is worth twenty bits, and nobody has
  taken it.** The toy write-up already prefers the distinct-value count
  (2^-117.4 against 2^-112.0, a 42× reduction). At 125M the reduction should
  be far larger, because 98,598,912 of the 103,890,944 denominators are `u8`
  lookups whose values live in `[0, 256)`, and the three table-helper families
  contribute `3 × 16,384` positions over ≤ 256 distinct values each (the P-3
  lift makes the padded table positions repeat true entries). The memo's rider
  (i) — *"nobody has done that count at 125M"* — is right and understates what
  it is worth. This matters beyond bookkeeping: **2^-97.8 sits within a third
  of a bit of the run's soundness figure 2^-97.5 (ruling M-2)**, and the first
  reader to notice will ask whether the two are the same number. They are not
  related, and a tightened refusal bound would stop the question being asked.

And note B-1: whatever number is carried, the sentence "refusal is
challenge-only up to 2^-x" is **false for a run** until the witness-builder
class is either excluded by a precondition or listed.

---

## 5. What I could not check

* **(H1^run) and (H4^G).** G-R1 and G-R2 are real and correctly labelled. The
  generic-rank lemma does not exist at rung-G or 125M and I did not attempt
  it; the 23 slot closures were not re-read by me either. Everything in this
  check is conditional on them exactly as the memo's is.
* **The gate's own numbers.** I read `ZK60_NATIVE_RUN_GATE.md`'s figures
  through the memo and through the run design's disposition; I did not run
  `zk60_native_run_gate.py`, did not re-derive the 154 × 1,248 or 308 × 3,761
  systems, and did not verify that the gate's cross-commitment **coordinate
  identification** (the same hidden words at different row widths and offsets
  in `A_k`, `B_k`, `A_{k+1}`) is correct. A wrong identification would make
  "joint 0 = sum" vacuous in a way neither the memo nor this check would see.
  That is worth one hour of somebody's time.
* **The hash layer.** (H6^run) is prose on both sides; nothing computable.
* **Whether the 125M all-zero chain is admissible.** B-4 says what is
  missing; I could not settle it without building, which I was told not to do.
  The two range boundaries are `WRHO_S` and `F_P` at the 125M shape and I did
  not compute either.
* **The real prover.** Everything about `ZkRng`'s output being
  indistinguishable from uniform is an assumption on both sides; I checked the
  structure (`rng.rs:44-61`: keyed BLAKE3, counter-mode refill, no reseed, no
  per-commitment domain) and nothing about the assumption.
* **`argument.rs`'s 23 closures and `pad.rs`'s host table.** I read the slot
  driver (`run_slot`, `build_claim`, `mask_eval`) and the pad-zero term's draw
  sites, not each closure. The memo does not claim to have read them either —
  that is G-R2.
