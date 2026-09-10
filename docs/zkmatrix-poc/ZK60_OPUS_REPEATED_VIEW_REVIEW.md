# O11 — the two-proof joint model, audited and its expectations recomputed

Reviewer: Claude Opus 5, independent reviewer, 2026-09-09 (task O11 of
[ZK60_OPUS_QUEUE.md](ZK60_OPUS_QUEUE.md)).
Review baseline: `c5eb2019353fdf56f1a115edb0c424bf86a9c195`.
Subjects: `scripts/zk60_io_repeated_view.py`,
`results/zk60_round23_repeated_view.json`, against the source fixture
`hashline/src/zk_ffn_fresh_io_tests.rs` and the round-22 captures.

**Engine provenance, stated up front.** O8's `JointModel` rank engine is reused
unchanged, by import. What follows is an independent recomputation of the
*expectations* — which rows may alias, what each constraint is worth, what the
controls should return — **not** an independent implementation of the rank
algebra. Any claim of independence extends only that far.

## 0. Verdict

The delivered model is sound within its stated scope. Every structural premise
I could check holds, the headline number is exactly what it is claimed to be,
and the one modelling choice that looked load-bearing turns out to err on the
conservative side. No unexpected disclosure, and nothing here recovers a
private value.

## 1. The four base-field coordinates, explained exactly

The delivered result reports `disclosed_total = 4` for the full union in both
P1 and P3, and `0` for the `A`/`Input`/`Output` sub-union.

I recomputed this by adding the two H zero-sum constraints **one at a time**:

| zero-sum constraints in the model | P1 disclosed | P3 disclosed |
|---|---|---|
| 0 | **0** | **0** |
| 1 | **2** | **2** |
| 2 | **4** | **4** |

The step is exactly 2 per constraint, in both modes. So:

> Each proof's `H` carries one `F_{p²}`-valued public identity, `Σ_j u[j] = 0`,
> and an `F_{p²}` equation fixes exactly **two base-field coordinates**. Two
> proofs give four. That is the whole of the reported disclosure.

Two facts pin the interpretation:

- **With no zero-sum constraint the joint disclosure is 0** in both modes. So
  none of the four coordinates is witness-dependent; they appear only once the
  *public* constraint is written down. This is the same identity O8 reports as
  `H = 2` for a single proof.
- **The public LogUp identities add rank 0** on top of the zero sums
  (recomputed: `rank_aug − rank_full = 0` in both modes). They are already
  implied, so they contribute no further determined coordinate. The delivered
  tool's `public_H_identities_add_no_rank` assertion is correct.

The role renaming to `H@0`/`H@1` does disable the archived model's exact-name
zero-sum hook, and the tool restores each constraint explicitly in merged row
coordinates (`zk60_io_repeated_view.py:66`–`:81`). The step function above is
the check that the restoration is complete: if either constraint had been lost,
the totals would read 0, 2, 2 rather than 0, 2, 4.

## 2. Alias hygiene, recomputed from the alias list

| | P1 | P3 |
|---|---|---|
| cross-attempt aliases | 348 | 351 |
| row kinds joined | `data`↔`data` only | `data`↔`data` only |
| H cross-attempt aliases | **0** | **0** |
| `W` a private role? | **no** | yes |
| `public_w` equal across attempts | yes | yes |

- **Only witness data aliases.** Every one of the 348/351 cross-attempt aliases
  joins two rows both declared `data`. No mask, pad or proximity row aliases —
  which is the property that matters, since merging two independent secrets
  would corrupt the model.
- **P3 − P1 = 3**, and those three are exactly `W`'s private data rows, shared
  because both attempts prove the same weights. The arithmetic closes.
- **P1 carries no private `W` role at all.** Its fixed public weight root is
  handled as public policy — `check_pair` requires `a.public_w == b.public_w`
  (`:29`) — and never enters the model as private rows. This is the specific
  thing O11 was asked to verify, and it holds.
- The within-attempt endpoint aliases are O8's `ALIAS_PAIRS`
  (`A` 14/15 ↔ `Input` 0/1, `A` 16/17 ↔ `Output` 0/1), applied per attempt.

`check_pair` also refuses a repeated proof digest, mixed privacy modes,
differing endpoint policy metadata and any reused private root
(`:22`–`:32`). The last is consistent with [O9](ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md)
F1: the public API cannot produce two proofs against one endpoint root, so
"repeated" here can only mean fresh roots over shared data, which is what the
captures are.

## 3. H's proof-locality: an assumption, and which way it errs

The tool does not alias `H` across attempts, on the stated ground that H's data
depends on each proof's `β`, `γ`, `α`.

**Recorded support.** In both modes, every role's transcript `before_state` and
every private root differ between the two attempts. That follows from the
construction: `transcript()` absorbs the 112-byte policy — including the two
fresh endpoint roots — before any challenge is drawn
(`zk_ffn_fresh_io.rs:138`–`:145`), so the two proofs' challenge streams diverge
from the first squeeze. Asserted in
`tests/test_zk60_opus_repeated_view.py::ProofLocalityEvidence`.

**Which way would an error go?** This looked like the risky choice: failing to
alias unknowns that are really equal normally makes a model *understate*
disclosure. I measured the counterfactual — aliasing all 664 of H's data rows
across the two attempts — and it goes the other way:

| | P1 | P3 |
|---|---|---|
| as delivered (H proof-local) | **4** | **4** |
| counterfactual (H data aliased) | **2** | **2** |

Aliasing H would *reduce* the reported total, because the two zero-sum
constraints would collapse onto one set of unknowns and count once instead of
twice. So the delivered choice is the **conservative** one: it reports more
than the alternative. And in both readings every disclosed coordinate is a
public identity, so the *character* of the result — no witness-dependent
disclosure — does not depend on this assumption at all. Only the count does.

This is worth recording because it converts a premise that had to be trusted
into one whose failure mode is known and harmless.

## 4. The endpoint mask-pair ablation

The positive control drops the second (`×u`) mask part of attempt 0's `Input`
claim, rebuilding the legacy single-base-mask form on the same commitment
(`zk60_opus_io_capture.py:1620`–`:1638`).

| | value |
|---|---|
| paired (as shipped) | 0 disclosed |
| single mask (ablated) | **256** disclosed |
| per column | **1** |
| columns | 256 |

**Interpretation.** With only one base mask instead of an `F_{p²}` mask pair,
exactly one of the two base-field coordinates of each column's combination
stops being hidden. 256 columns × 1 coordinate = 256. This matches O8's
archived `endpoint_mask_ablation` control number for number, and it is the same
channel as the legacy scalar-mask disclosure recorded in
[round 16](ZK60_ROUND16.md). The control fires, so the model is capable of
seeing a real leak; a model that returned 0 here would be worthless as
evidence.

## 5. Exclusions, confirmed still excluded

The delivered record lists them and I confirm none is silently in scope: CFS
rounds, pads, encoded columns, Merkle roots and paths, nonlinear cross-proof H
relations, adaptive transcript, arbitrary repetition count, reused commitment
owners.

Adding the scope limits that matter for reading the number:

1. **Fixed coefficients at the recorded challenges.** This is not an adaptive
   argument, and a two-proof rank calculation is not a composition theorem —
   the endpoint model says so itself.
2. **Exactly two proofs.** Nothing here extends to `k` proofs. The step function
   in §1 suggests `2k`, but that is an extrapolation, not a measurement.
3. **One synthetic source-pinned witness.** The fixture builds one witness
   before its two-attempt loop, so "shared data" is a property of this fixture,
   not a proved property of all witnesses.
4. **Owner reuse is out of model** and is separately unreachable through the
   public API (O9 F1).

## 6. Findings

**F11.1** — the reported 4 is exactly two proofs × two base-field coordinates
of the public `F_{p²}` zero-sum identity, established by the 0 → 2 → 4 step
function rather than asserted. Nothing witness-dependent is disclosed.

**F11.2** — H's proof-locality assumption errs conservatively (§3). Failure of
the assumption would lower the count to 2, not raise it, and would not change
the character of the result.

**F11.3** — alias hygiene is exact: 348/351 cross-attempt aliases, all
`data`↔`data`, zero H aliases, and P3's three extra aliases are precisely its
private `W` data rows.

**F11.4** — P1's public `W` is correctly outside the private model, with
equality enforced as a policy precondition rather than modelled as rows.

**F11.5** — the mask-pair ablation's 256 is one base-field coordinate per
column, agreeing with O8's archived control.

No defect found. Two presentational suggestions for Codex, not applied:
record the 0 → 2 → 4 step function in the tool's own output so the "4" carries
its explanation, and state the H-aliasing direction so the assumption's failure
mode is visible to a later reader.

## 7. Validation

Eleven independent controls in
[`tests/test_zk60_opus_repeated_view.py`](../../tests/test_zk60_opus_repeated_view.py)
pass in under four seconds. The rank recomputations run offline (minutes) and
their outcomes are recorded in
[`results/zk60_opus_repeated_view_review.json`](../../results/zk60_opus_repeated_view_review.json),
which the tests pin.

The test file resolves its capture directory from `ZK60_IO_CAPTURES`, defaulting
to the persisted round-22 workspace directory rather than a `/tmp` path, so a
reboot cannot silently turn these controls into skips — the failure mode
recorded in the [O10 review](ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md) §4 F10.6
and in round 22.

No production Rust, transcript, proof format, privacy mode or benchmark
parameter was changed, and `scripts/zk60_io_repeated_view.py` was not edited.
