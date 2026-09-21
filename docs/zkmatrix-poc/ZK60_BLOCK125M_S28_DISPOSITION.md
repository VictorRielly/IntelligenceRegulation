# ZK60 — security owner's disposition of lane stage 28 ("the 125M prover, faster without moving a byte") and of its independent review

**Written 2026-09-21 10:43 PDT by the security owner (interactive Claude
Fable 5.1).** Inputs: the lane `zk60-private-block-125m` at `2905e58` (stage
28: `d2c2733`, `a9f2211`, `1952a1e`, `309d238`, control `2905e58`), its ledger
section, and the independent adversarial review
`ZK60_BLOCK125M_S28_REVIEW.md` (review branch tip `a6216b2`, merged into the
lane at `db28728` by me, no conflicts). Labels: [MEASURED] = a run that
happened, one run on a shared laptop unless said otherwise; [COUNTED] = from
code or shape; [READ] = I read the lines myself.

## 0. In plain words

The lane made one private block at the 125M shape prove in **17.40 s instead
of 27.71 s** [MEASURED, dense weights, generic hidden input; control on the
all-zero input with the old diagonal weights: 17.71 s], with the same receipt
length (40,783,352 B), by computing the same numbers more cheaply: the lookup
inverses come from a 256-entry table, and the tables each sub-argument starts
from are built once, in parallel. Nothing that is sent, absorbed or drawn
changed, and no file outside `private_block/` was touched.

Receipts cannot be compared byte for byte, because every attempt draws fresh
randomness from the operating system — an accepted privacy condition that a
test enforces. So an independent reviewer who did not write the code attacked
the claim instead. **It found no defect and changed no production line.** Its
strongest result: a complete twelve-block 125M run written by the OLD prover
is accepted by the NEW verifier (15.20 s, 476 MiB) [MEASURED]. It also found
that one sentence of the stage's own finding S28-F1 over-reaches, and four
places where the tests are thinner than the claim. This page rules on all of
it.

## 1. Rulings

**V-1 — accepted as experimental lane code, reviewed.** Stage 28 stands on the
same footing as the rest of the lane: experimental, for the integrator to
integrate, **not a privacy acceptance of anything**. The figure 17.40 s may be
quoted as [MEASURED, one run, shared box, reviewed]. It is a CPU figure for one
125M-shape block and says nothing about the 8B pass the 5-second target is
defined on.

**V-2 — what "same bytes" rests on, said once.** (i) Five of the nine changed
computations have a real old-against-new oracle (the reviewer checked
mechanically that the "old" side is the text at `79f0726`), driven by 1,800
randomised comparisons and all 560 `eq_cube` triples; (ii) no changed
computation has a caller on the verifying path, and the verifier's arm is
untouched [the reviewer's structural finding; I re-read the prover/verifier
split of `protocol.rs` for the refusal region myself]; (iii) honest proofs at
five shapes verify from their own bytes, under 1 and 8 threads (the whole
filter re-run with `RAYON_NUM_THREADS=1`: 327 passed / 0 failed); (iv) the
cross-version run above. What this does NOT exclude is named in V-4.

**V-3 — finding S28-F1, in the form I accept (S28-F1a).** For every witness
the constructors admit, every looked byte is one of the 256 byte rows, every
`(delta, e)` pair a row of the public exponential table and every activation
pair a row of the public activation table. The prover inverts the WHOLE of
each public table on every attempt, before multiplicities enter
(`protocol.rs:905-909` on the lane; `:353-357` on main) [READ]. Therefore:

1. **Whether an attempt is refused for a zero LogUp denominator is a
   deterministic function of the three public challenges and the three public
   tables** — the event "alpha equals one of at most 768 public field
   elements" — and not of the hidden input.
2. **Which of the two lines returns first does depend on the hidden input**
   (the helper line fires first iff the witness carries the unlucky value),
   but nothing published can tell them apart: the two return the byte-identical
   string, and **no transcript absorb and no generator draw lies between the
   challenge draw and the second line** — on the lane `alpha` is drawn at
   `:848`, the helper lines are `:857-879`, the table line `:909`, the next
   draw `:933` and the next absorb `:949`; on main `:332`, `:339-351`, `:357`,
   `:362` [READ, both]. A refused attempt publishes nothing in either case
   (ruling M-9 and the refusal-reason rule already forbid showing a refusal or
   its stage to anyone not entitled to the input).
3. **The sentence the stage wrote — "a function of the public challenges and
   the public table alone" without the qualifier — is false**, as the
   reviewer's counterexample shows (a looked value of 4096, or a pair the
   exponential table does not carry). Such a witness is not admitted and
   cannot yield a verifying proof; a prover feeding it is lying about its own
   secret, and nothing about anybody else's input is at stake. The ledger is
   to carry the qualified sentence.
4. **Consequence for the accepted figures: none.** The toy statement and the
   run documents price this refusal as if it depended on the input (at most
   768 distinct denominators: `2^-118.4` per block, `2^-114.8` per twelve-block
   run). With item 1 the event is reproduced exactly by anyone who knows the
   challenges, so that row is an over-estimate. **I leave the numbers as they
   are** — they are not the binding term anywhere — and record the sharper
   reason as clarification 10 of the toy statement. The elapsed time of a
   refused attempt (which line fired) is a timing channel of the same class as
   every other in the prover and is outside every statement made so far.

**V-4 — the gaps the review found are to be closed before the integrator
takes the stage (lane stage 29).**

| finding | what it is | ruling |
|---|---|---|
| S28-R1 | `total` (the parallel claimed sum) has no old-against-new gate, and its parallel branch — like the moved public table, the parallel table build and the histogram — is crossed only by the `#[ignore]`d 125M run | **Close.** Both branches of every size threshold stage 28 introduced must be crossed by a test that runs in the ordinary filter, with an old-against-new comparison. The implementer chooses the means (an inner function taking the threshold as an argument, the production wrapper passing the constant, is acceptable; a `cfg(test)` constant that silently changes which branch every other test runs is NOT) |
| S28-R6 | the frozen toy's byte pins cross none of the five thresholds | **Accepted as a fact, closed by R1's remedy**: the toy's bytes cannot move through a branch it never takes; the thresholds get their own gates |
| S28-R7 | `eq_cube` diverges from the old gather if `start + |point| <= n_vars` is violated — unreachable today | **Close with a hard assertion** naming the precondition. A panic on a public-shape invariant is acceptable; a silent divergence is not |
| S28-R8 | `helper_pair_inverses_u8` adds one refusal string the ledger does not list (unreachable) | **Close in the ledger**, and the string is covered by the refusal-reason rule like every other |
| S28-R3 | the `Err` arm of the out-of-table fallback was never exercised | closed by the reviewer's test (merged) |
| S28-R4 | the sub-step table's "baseline" column is a tree that is no commit (24.59 s, after task 1) | **Close in the ledger**: label the column as what it is; the headline 27.71 -> 17.40 s is between two commits and stands |
| S28-R5 | "nine tests" for ten | ledger |
| S28-R2 | S28-F1's second half | ruled above (V-3) |

**V-5 — no deterministic digest pin (finding S28-F2) is the right call and
stays.** A seeded generator on the proving path would break condition 6 of the
accepted toy statement; the test that enforces it is worth more than a digest.
Where byte identity is wanted in future, the pattern of this stage is the one
to use: old-against-new oracles at the level of each computation, the whole
filter under one thread, and old receipts under the new verifier.

**V-6 — for the integrator.** Build any optimisation of the shaped block on
top of `db28728`, not beside it: the lookup helpers and the lane's side of the
softmax slot — two of the three targets the integrator named on 2026-09-20
14:15 — are done here. What remains of those three targets is inside shared
files and is measured in the lane's ledger (stage 28, "Integrator requests"):
the masked-sumcheck round loop 6.59 s, the two hiding commitments 6.50 s, the
openings 0.67 s, of 17.40 s.

## 2. What this is not

Not a privacy result: no gate reads a prover's speed. Not a statement about
timing or memory side channels: the dense and the all-zero control differ by
0.31 s on one run each on a shared box, which shows nothing either way. Not a
replication of 17.40 s: one run. Not a number on the 5-second target: that is
defined on the 8B pass, best measured 58.4 s on public inputs, unchanged.
