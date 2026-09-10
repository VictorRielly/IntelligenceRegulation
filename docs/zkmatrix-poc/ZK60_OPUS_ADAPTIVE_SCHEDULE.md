# O13 — the `/2` transcript schedule and its dependency graph

Reviewer: Claude Opus 5, independent reviewer, 2026-09-09 (task O13 of
[ZK60_OPUS_QUEUE.md](ZK60_OPUS_QUEUE.md)).
Review baseline: `b3a253592b9269d7b65359d33efcd1e40d5217ed`.
Tool: [`scripts/zk60_opus_adaptive_schedule.py`](../../scripts/zk60_opus_adaptive_schedule.py).
Record: [`results/zk60_opus_adaptive_schedule.json`](../../results/zk60_opus_adaptive_schedule.json).

**This is a schedule inventory, not a cryptographic construction and not an
adaptive privacy theorem.** Nothing here proves anything can be simulated. Its
purpose is to say exactly what is public when, what each public value still
depends on, and where an attempt to compose the existing fixed-challenge pieces
runs into a cycle.

Ordering is read from the **verifier** — that is what a distinguisher sees —
and then cross-checked against all four round-22 captures. Challenge *values*
are not recomputed: that needs BLAKE3, which is unavailable in this toolchain
and unprogrammable in production anyway. What is machine-checked is structural.

## 1. The schedule

55 sites, in verifier order. `zk.rs` is `hashline/src/zk.rs`; line numbers were
read at the baseline and each was verified by reading it back.

| # | Site | Event |
|---|---|---|
| 1 | `zk_ffn_fresh_io.rs:139` | `Transcript::new(PROFILE)` |
| 2 | `:140` | absorb `expected-IO` — the whole 112-byte policy, **including both endpoint roots** |
| 3 | `:141` | absorb `parameters` (fixed geometry string) |
| 4 | `zk.rs:3501` | `absorb_statement_v3(st)` |
| 5 | `zk.rs:3507` | absorb `zk` mode header |
| 6 | `zk.rs:3518` | `absorb_com "W"` |
| 7 | `zk.rs:3519` | `absorb_com "A"` |
| 8 | `zk.rs:3521` | absorb `M` — one root covering **all eight** CFS slots |
| 9–11 | `zk.rs:3522–3524` | squeeze `beta`, `gamma`, `alpha` |
| 12 | `zk.rs:3525` | `absorb_com "H"` — **after** `beta/gamma/alpha` |
| 13–17 | `zk.rs:3536–3569` | `gu`: challenges, `gu-claim`, 6 rounds, `gu-term` |
| 18–21 | `zk.rs:3576–3598` | `d`: challenges, `d-claim`, 6 rounds, `d-term` |
| 22–25 | `zk.rs:3605–3635` | `zc20`: challenges, `gammaF`, 10 rounds, `zcF-term` |
| 26–29 | `zk.rs:3638–3662` | `zc17`: challenges, `gammaD`, 10 rounds, `zcD-term` |
| 30–33 | `zk.rs:3665–3687` | `tab`: challenges, `gamma-tab`, 17 rounds, `tab-term` |
| 34–37 | `zk.rs:3690–3696` | `zs`: `c_zs`, `gamma-zs`, 9 rounds, `zs-term` |
| 38 | `zk.rs:3739` | `before_openings` → `verify_arguments` |
| 39–44 | `zk_ffn_fresh_io.rs:385–394` | IO side 0: `io-side`, 9 `tau`, `c`, `io-gamma`, 10 rounds, terminal guard |
| 45–50 | `zk_ffn_fresh_io.rs:385–394` | IO side 1: the same, second iteration |
| 51 | `zk.rs:3742` | **M** opening — `mask_verify` |
| 52 | `zk.rs:3752–3753` | **W** opening (P3 private commitment; P1 public root) |
| 53 | `zk.rs:3768–3769` | **A** opening |
| 54 | `zk.rs:3775–3776` | **H** opening |
| 55 | `zk_ffn_fresh_io.rs:459,462` | **Input** then **Output** endpoint openings |

Three ordering facts carry most of the weight:

- **The endpoint roots are the *first* thing absorbed** (site 2), inside the
  112-byte policy, before the statement and before every challenge.
- **`H` is committed after `beta/gamma/alpha`** (site 12 after 9–11). It is the
  only commitment allowed to depend on them, which is what makes `H` genuinely
  proof-local — the structural reason behind O11's non-aliasing choice.
- **`M` is committed before every challenge it will mask** (site 8 before 9–11
  and everything after). All eight slots, one root.

## 2. Machine-checked against all four captures

`zk60_opus_adaptive_schedule.py` reconstructs the observable segment chain from
the recorded transcript states and checks:

| Check | Result |
|---|---|
| transcript contiguous: each segment's `after` state equals the next segment's `before` | **pass**, all 4 |
| segment order is `M → W → A → H → Input → Output`, with `W` the *public* W block in P1 | **pass**, all 4 |
| `mask.before.next == mask.theta` — `theta` is literally the next challenge peeked from the pre-opening state | **pass**, all 4 |
| exactly eight reserved CFS slots | **pass** |
| every argument's `(rounds, degree)` names exactly one reserved slot | **pass** |
| the two IO arguments declare slots 6 and 7 | **pass** |
| IO geometry: 9 `tau`, 10 `rho`, 10 rounds, 2 terminals per side | **pass** |
| mask proximity rhos number `2·|specs| + 2 = 18` | **pass** |
| every folded vector is `n + q_pad = 512` wide | **pass** |
| every role's proximity rhos number exactly its row count | **pass** |

The P1/P3 difference is visible in the chain and is exactly the expected one:
in P3 the second segment is the private `W` commitment; in P1 it is the
`public_w` block (3 rows, root only). The chain is contiguous in both, so no
transcript activity is unaccounted for between `M` and `A`.

**Slot index is not emission order.** The argument→slot map is
`gu→0, d→1, zc20→2, zc17→3, tab→5, zs→4, io0→6, io1→7`, while the emission
order is `gu, d, zc20, zc17, tab, zs, io0, io1`. Slots 4 and 5 are emitted in
the opposite order to their index. This is harmless — the slot index is a
reservation label, not a schedule position — but anyone composing the pieces by
slot number will get the order wrong, so it is recorded.

## 3. Every public observation class

The record carries all 13 with structured fields; the pattern is what matters.

| Class | Public at | Still depends on | A simulator must already have fixed |
|---|---|---|---|
| endpoint roots | before every challenge | both endpoints' 7 rows, pads, 2048 salts | both endpoint commitments, before any challenge exists |
| `W` root | before `beta/gamma/alpha` | private W rows (P3 only) | P3: the commitment. P1: nothing — the root is public policy |
| `A` root | before `beta/gamma/alpha` | all 702 rows, **including the X/z16 planes aliased to the endpoints** | `A`, consistently with both endpoints' data rows |
| `M` root | before `beta/gamma/alpha` | every slot's mask coefficients | all eight slots, before any challenge they will mask |
| `beta/gamma/alpha` | squeezed after `M` | — | — |
| `H` root | **after** `beta/gamma/alpha` | 1326 LogUp rows, functions of those challenges and the witness | `H`, and it may use the challenges |
| claims and gammas | before each argument's rounds | the witness sums | the slot totals, at `M` time |
| masked round messages | one per round, each followed by its challenge | slot coefficients and witness tables | the slot coefficients — the round values are then constrained, not free |
| terminals | after each argument's rounds | witness values at the final point | — |
| group vectors | at each role's opening | every row in the group | the committed rows |
| proximity vectors | at each role's opening | every row | the committed rows |
| sampled column indices | derived inside each opening | — | the commitment, whose root was absorbed long before these indices exist |
| column values, salts, paths | at each role's opening | encoded rows and per-column salts | the real encoding, or a programmable hash |

## 4. Rejection guards

There are two, and both are benign in a way worth stating:

| Site | Guard | Resamples? | Witness-dependent? |
|---|---|---|---|
| `zk_ffn_fresh_poc.rs:228–231` | `draw_mask_challenge`: `c == 0` aborts the attempt | **no** — one squeeze, then error | **no** |
| `zk_ffn_fresh_io.rs:392–394` | `rho[9] == 0` aborts ("zero terminal mask challenge") | no | **no** |

Neither loops, so **the squeeze counter advances deterministically** and the
schedule has no variable-length segments. Both predicates are functions of
challenges only, so a simulator that knows the challenges reproduces them
exactly and they leak nothing about the witness. Witness-*dependent* failure is
a different matter and is O14's subject; this section is not a claim about
those.

## 5. The circular dependencies

These are the reason the existing fixed-challenge results do not compose. None
is solved here, and none should be solved by assuming later challenges early.

**C1 — commit-then-mask.** `M`'s root is absorbed at site 8, before
`beta/gamma/alpha` and before every argument challenge. But the masked round
messages must lie on the fibre determined by challenges drawn later. So the
mask coefficients are fixed before the constraints they must satisfy exist.
FA8's device is to program the round challenges at squeeze points — a random
oracle programming argument, not a plain reduction. *Unresolved.*

**C2 — commit-then-open.** The cycle in full:

```
endpoint masks and pads → encoded rows → Merkle root
   → absorbed in the 112-byte policy (site 2, before everything)
   → transcript → opening challenges → which columns must be explained
   → the masks and pads
```

Round 24's fibre sampler runs this backwards: it fixes the opened columns and
*then* solves for masks and pads. In the real schedule the root that binds them
is absorbed first. Round 23 breaks the cycle by issuing a root before the
columns are chosen and programming salted leaves afterwards, which real BLAKE3
forbids. *Unresolved.*

**C3 — shared-plane consistency.** `A` rows 14–17 alias `Input` rows 0–1 and
`Output` rows 0–1. All three roots are absorbed before any challenge, so a
simulator must fix **one** shared X/z16 plane that simultaneously satisfies
`A`'s 20 claims across 7 groups and both endpoints' single claims. Round 24
samples one endpoint in isolation and neither resamples nor consults `A`.
*Unresolved — this is the joint field-view sampler Codex still owes.*

**C4 — slot total to gamma.** `io-gamma = c · mask[slot].total()`
(`zk_ffn_fresh_io.rs:388`), where `c` is squeezed immediately before and the
total was fixed at `M` commitment time. The simulator picks totals blind and
`gamma` is then forced by a challenge it does not control. Round 21 checks the
conditional fibre at fixed challenges only. *Unresolved.*

**How they interlock.** C2 and C3 are not independent: the shared plane in C3
lives in rows that C2's commitment binds, so a joint sampler must satisfy both
at once — choose the plane before any challenge (C3) *and* explain columns
chosen after the challenges (C2). Solving either alone does not help. C1 and C4
are the same difficulty on the mask side: the single `M` root is the common
early commitment for all eight slots.

## 6. Findings

**F13.1** — the observable schedule is fully contiguous on all four captures,
with no unaccounted transcript activity, and the P1 public-W block occupies
exactly the position the P3 private W commitment does.

**F13.2** — `theta` is the immediate next challenge from the pre-M-opening
state, verified by identity against the captures' own peeked value. This pins
the mask opening's schedule position without recomputing any hash.

**F13.3** — `H` is the only commitment absorbed after `beta/gamma/alpha`. That
is the source-level reason `H` is proof-local, and it is a stronger statement
than O11's evidence (which showed only that the transcripts differ).

**F13.4** — CFS slot index is not emission order: slots 4 and 5 are emitted
swapped. A composition indexed by slot number will mis-order them.

**F13.5** — both rejection guards are challenge-only aborts with no
resampling, so the squeeze counter is deterministic and neither guard leaks.

**F13.6** — four circular dependencies (§5), all unresolved, and C2/C3
interlock so that neither can be discharged alone.

## 7. Scope

No production Rust, transcript, proof format, privacy mode or benchmark
parameter changed. No archived tool, report or result was edited. This task adds
one script, one result record, one test and this document.

Not established here: any simulation, any adaptive argument, any bound, and any
statement about challenge values. The tool checks structure, ordering and counts.
`full_privacy_review_complete` and `u2_closed` remain false.
