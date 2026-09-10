# O12 — the conditional endpoint fibre, audited

Reviewer: Claude Opus 5, independent reviewer, 2026-09-09 (task O12 of
[ZK60_OPUS_QUEUE.md](ZK60_OPUS_QUEUE.md)).
Review baseline: `b3a253592b9269d7b65359d33efcd1e40d5217ed`.
Subjects: `scripts/zk60_endpoint_fibre.py`, `tests/test_zk60_endpoint_fibre.py`,
`results/zk60_round24_endpoint_fibre.json`, and the round-24 argument
([ZK60_ROUND24.md](ZK60_ROUND24.md) §"Conditional sampling argument").

**Independence, stated precisely.** The rank computations below use a second
Gaussian elimination written for this audit (`_rank` in
`tests/test_zk60_opus_endpoint_fibre.py`), so the fibre dimensions are
cross-checked rather than read back from `LinearFibre`'s own pivots. Field and
polynomial helpers (`zk60_io_opening_translation`) are imported, not rewritten.
Codex's sampler is unmodified.

## 0. Verdict

Every algebraic premise I could check holds, on all eight real endpoint owners
and in independent small geometry. The advertised free dimensions follow from
rank alone; the terminal is an algebraic consequence rather than an independent
constraint; the polynomial fibre map is a bijection; the division guard is
unreachable at the shipped geometry.

The boundary that matters is not algebraic. **A conditional preimage is not a
simulated transcript**, for four concrete reasons set out in §6 — the sharpest
being that the sampler changes the endpoint data rows while `A` rows 14–17
alias them and `A` is not resampled. Round 24 states this exclusion; §6 gives
the consequence.

No defect found. No private value is recovered, and nothing here narrows the
P1/P3 requirements.

## 1. The two systems, rank-checked independently

`split_folds` splits the two `F_{p²}` folds (group vector and proximity vector)
into base coordinates, giving a **4 × 7** matrix `B` over `F_p`
(`zk60_endpoint_fibre.py:72`–`:73`, `:164`).

| System | Source | Shape | Rank (independent) | Nullity |
|---|---|---|---|---|
| mask | `:165`, `B[:, 2:]` | **4 × 5** | 4 | **1** |
| pad | `:166`, all of `B` | **4 × 7** | 4 | **3** |

Confirmed on all eight owners. `LinearFibre` demands full row rank and refuses
otherwise (`:55`, `"deficient mask/fold rank"`), so rank 4 is an *assumption
checked per run*, not a theorem about the construction — correctly handled.

The advertised dimensions then follow from rank alone:

- `message_free_dim = n · nullity(mask) = 256 · 1 = 256` (`:198`)
- `pad_free_dim = nullity(pad) · (budget − q) = 3 · (256 − q)` (`:199`)

Recomputed from my own rank for all eight owners:

| mode | role | q distinct | message free | pad free | `3(256−q)` |
|---|---|---|---|---|---|
| P3 | Input | 236 | 256 | 60 | 60 |
| P3 | Output | 246 | 256 | 30 | 30 |
| P1 | Input | 242 | 256 | 42 | 42 |
| P1 | Output | 240 | 256 | 48 | 48 |
| P3 | Input | 248 | 256 | 24 | 24 |
| P3 | Output | 243 | 256 | 39 | 39 |
| P1 | Input | 238 | 256 | 54 | 54 |
| P1 | Output | 240 | 256 | 48 | 48 |

A further consistency check the record supports: the eight distinct counts sum
to **1933**, exactly the run's `programmed_salted_leaf_inputs`. One programmed
leaf per distinct opened position, none repeated, none spare.

## 2. The terminal is implied, not an extra constraint

This is the premise that would silently inflate the free dimensions if it
failed, so it is worth deriving rather than assuming.

The endpoint group carries exactly one claim over members `[0]`
(`from_capture`, `:146`–`:150`). `validate` establishes a nonzero `λ` with
`folds[0] = λ · claim_weights` (`:123`–`:127`). Since the folded message
coordinate is `vectors[0][j] = ⟨folds[0], column_j⟩`, we get

```
Σ_j cw[j]·⟨claim_weights, msg[:,j]⟩
  = (1/λ)·Σ_j cw[j]·⟨folds[0], msg[:,j]⟩
  = (1/λ)·⟨cw, vectors[0][:n]⟩
  = (1/λ)·(λ · claim_value)                 [validate, :128]
  = claim_value.
```

So once the group vector is preserved, the masked terminal is preserved
automatically and consumes **zero** fibre dimension. Verified numerically on
all eight owners (`TerminalIsImpliedNotIndependent`). `verify_sample` still
re-checks it explicitly (`:215`–`:219`), which is the right belt-and-braces
choice — the implication depends on `λ` being nonzero and the layout having a
single claim, both of which are per-run checks.

## 3. The polynomial fibre is a bijection

`conditional_poly` (`:76`–`:95`) claims `L + V·h` is a bijection from degree
`< budget − q` polynomials onto the affine fibre of degree `< budget`
polynomials with prescribed values at `q` distinct nodes.

Correct, and for the standard reason: `L = interpolate(xs, ys)` has degree
`< q`; `V = Π(X − x_i)` is monic of degree `q`; `V·h` has degree `< budget`, so
the sum stays in range. Injectivity is immediate from `V ≠ 0`. Surjectivity:
two solutions differ by a polynomial vanishing at all `q` nodes, hence
divisible by `V` with quotient of degree `< budget − q`.

Both boundary cases are handled: `q = budget` gives `noise = []` and a unique
solution (`:92`), and empty constraints give the unconstrained uniform draw.
`q > budget` is refused (`:82`–`:84`). Checked independently in
`PolynomialFibreBijection`, including that distinct `h` give distinct outputs
and that a full-budget constraint collapses two different randomness streams to
the same polynomial.

## 4. Equal completion counts

Both fibres are solution sets of inhomogeneous linear systems of **full row
rank**, so each is a nonempty affine subspace and its cardinality is `p^dim`.
Neither dimension depends on the chosen dummy data: `message_free_dim` depends
only on `n` and the mask nullity, `pad_free_dim` only on the pad nullity and
the distinct-position count. Therefore every admissible data choice has the
same number of completions, which is what makes the uniform draw over free
coordinates a uniform draw over the fibre — **in the ideal independent-`F_p`
model only** (§6c).

The run exercises this with two data choices per owner (all-zero and a fixed
nonzero diagnostic plane) and reports identical dimensions for both, on all
eight owners.

## 5. Duplicate positions, adversarial correlation, deficient rank

- **Duplicates.** `unique = dict(zip(indices, columns))` collapses repeats
  (`:178`) and `validate` refuses a conflicting duplicate (`:135`). Pushed to
  the extreme in `AdversariallyCorrelatedColumns`: 256 draws at **one** index
  validate, sample and verify, with `pad_free_dim = 3·255 = 765` exactly as the
  formula predicts.
- **A conflicting duplicate** at the same index is refused.
- **The same column bytes at different indices** is refused by the
  fold/column consistency check (`:138`–`:141`), which is the check that stops
  an adversary from presenting a correlated column set that no encoding
  produces.
- **Deficient rank** refuses rather than reporting a wrong free dimension;
  confirmed with an explicitly rank-3 system.

The delivered suite already covers corrupted terminals, vectors, columns,
claims, deficient masks and non-canonical data; those eight tests pass here.

## 6. What the result does and does not mean

The tool establishes, for each of eight real endpoint owners: **with the public
field view held exactly fixed** — both folded vectors including all 256 message
and 256 pad coordinates, the masked terminal, and all seven base values at
every one of the 256 sampled positions — and with all challenges fixed, a
preimage exists for a chosen dummy data plane, and the preimages form an affine
space of dimension `256 + 3(256 − q)`.

Four reasons that is not a transcript simulation:

**(a) The public view is an input, not an output.** It comes from a real
capture. The tool cannot generate a view; round 24 says so and the result
record carries `public_field_view_sampled: false`.

**(b) Fixed challenges are not Fiat–Shamir.** The opened column indices are
derived in the real protocol from the transcript, which absorbs the very
messages being resampled. Holding indices and challenges fixed while changing
the message is exactly the step a real transcript forbids. The root is likewise
non-binding here: it is a `PreparedSimulation` root with programmed salted
leaves, so it does not commit to the sampled rows.

**(c) Uniformity is idealized.** The draw is uniform over free coordinates in
an independent-`F_p` model. Production randomness is a BLAKE3 stream whose
per-word reduction has exact total variation `r(p−r)/(p·2^128) < 2^-96` from
uniform — see the [round-25 disposition](ZK60_ROUND25_OPUS_REVIEW.md), whose
correction of my earlier O10 figure I have verified and accept.

**(d) The sampled object contradicts `A` unless `A` is solved too.** O8's
`ALIAS_PAIRS` make `A` rows 14/15 the same unknowns as `Input` rows 0/1, and
`A` rows 16/17 the same as `Output` rows 0/1. The sampler replaces those rows
with a dummy plane while `A`'s captured observations, which constrain the same
unknowns, are neither resampled nor consulted — the view carries no `A` data at
all (`ScopeOfTheSampledObject`). So the sample is consistent with **one
endpoint's** public view in isolation; joint consistency with the rest of the
proof is not established, and round 24 correctly lists the joint sampler as
still owed.

None of (a)–(d) is a defect in the tool. Each is a boundary the tool declares.
The reason to restate them is that "16 conditional samples verified" reads like
a privacy result if the exclusions are dropped, and it is not one.

## 7. Private data handling

`from_capture` (`:144`–`:157`) reads only verifier-visible fields: the claim
list, the group vector, the proximity vector, the group's `cw` weights, the
opened column indices and values, the row-role kinds and `q_pad`. No message
row, mask, pad or salt of the real proof is read. The data planes are supplied
by the caller and are the two declared diagnostic choices (`:258`–`:261`). The
run additionally asserts no prior oracle answer changed (`:274`) and preserves
round-22 dependency digests, failing closed (`:234`–`:241`).

## 8. Findings

**F12.1** — the advertised free dimensions are correct and follow from rank
alone; independently reproduced on all eight owners, with `3(256−q)` exact in
every case.

**F12.2** — the masked terminal is an algebraic consequence of the group vector
given the single-claim layout and `λ ≠ 0`; it costs zero fibre dimension.
Derived in §2, verified on all eight owners.

**F12.3** — the coset/subgroup division guard (`:183`) is **unreachable at the
shipped geometry**: none of the 2048 coset points satisfies `x^256 = 1`, because
`7^256` is not an eighth root of unity. The guard is correct to keep as a
per-run check but never fires here, so the division is total.

**F12.4** — one programmed salted leaf per distinct opened position: the eight
distinct counts sum to 1933, matching `programmed_salted_leaf_inputs` exactly.

**F12.5** — the conditional result is per-endpoint and is not joint with `A`
(§6d). This is the gap between round 24 and a field-view sampler.

## 9. Validation

Fifteen independent controls in
[`tests/test_zk60_opus_endpoint_fibre.py`](../../tests/test_zk60_opus_endpoint_fibre.py)
pass in about eight seconds, alongside the eight delivered tests.

The capture directory resolves from `ZK60_IO_CAPTURES`, defaulting to the
persisted round-22 workspace. **These tests do skip when those gitignored bytes
are absent**, and a skip is not evidence — integration must require the captures
and reject skips, as the round-25 disposition asks. I am stating that plainly
here because my O11 report's wording on this point was too strong.

No production Rust, transcript, proof format, privacy mode or benchmark
parameter changed, and `scripts/zk60_endpoint_fibre.py` was not edited.
Commands, exits and digests are in
[`results/zk60_opus_endpoint_fibre_review.json`](../../results/zk60_opus_endpoint_fibre_review.json).
