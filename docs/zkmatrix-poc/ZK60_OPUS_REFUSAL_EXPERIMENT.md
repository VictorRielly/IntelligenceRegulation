# O14 — valid statements and the observable refusal experiment

Reviewer: Claude Opus 5, independent reviewer, 2026-09-09 (task O14 of
[ZK60_OPUS_QUEUE.md](ZK60_OPUS_QUEUE.md)).
Review baseline: `b3a253592b9269d7b65359d33efcd1e40d5217ed`.
Record: [`results/zk60_opus_refusal_experiment.json`](../../results/zk60_opus_refusal_experiment.json).

This resolves the row I left unspecified in
[O9](ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md)'s Game J, where I wrote only that
the simulator "must reproduce the same refusal event and the same consumption."
The [round-25 disposition](ZK60_ROUND25_OPUS_REVIEW.md) is right that this is
not automatic: a witness-dependent identity failure cannot be reproduced by a
simulator that is given no witness. The fix is not to weaken the simulator but
to say which experiment is being run.

Neither the external-root obligation nor the private-IO requirement is narrowed
here. P1 continues to hide inputs, outputs and intermediate activations.

## 1. Two different objects, which must not be conflated

**Game V — a valid-relation proof oracle with a relation-checking wrapper.**
This is standard zero knowledge, and the literature already has the exact shape.
From the version the endpoint memo links (§4 for why the version matters),
**Definition 8 (Wrappers for NIZK Simulator)**:

> `S′_1(x, w)` is an oracle that first checks `(pp, x, w) ∈ R` where `pp` is
> part of `srs` and then runs (and returns the output of) `S_1(x)`.

and **Definition 9 (Zero-Knowledge)** states the restriction outright:

> Zero-knowledge is a security property that is only guaranteed for valid
> statements in the language, hence the above definition uses `S′_1` as a proof
> simulation oracle.

The witness reaches the **wrapper**, never the simulator. `S_1` receives `x`
alone. Invalid requests are refused by the wrapper before the simulator is
invoked, so the witness-dependent rejections in §3 never arise inside the game.
This is the right game for a zero-knowledge claim about this prover. It is not
proved here.

**Game A — an application that exposes failures on invalid private inputs.**
The deployed CLI accepts arbitrary caller inputs and publishes either a receipt
or a specific error string. That leaks at least one witness-dependent bit, and
in fact more than one bit — see §2. Definition 9 does not cover it. Covering it
needs either **Definition 10**'s `F`-leaky zero knowledge with `F` naming
exactly the leaked predicate, or an application-level guarantee that only valid
inputs ever reach the prover.

A wrapper that *refuses* invalid statements is not the same thing as an
application that *reports why* they were invalid. Conflating them is how a
witness-dependent leak gets absorbed into "the simulator handles aborts".

**The simulator must not receive real endpoint values, real randomness or
private owner state under the name of a wrapper or auxiliary input.** In
Definition 8 the wrapper's use of `w` is a membership test whose only output is
admission; `S_1` is called with `x`. `S^F_1` is the deliberate exception, and
Definition 10 makes supplying `F(x, w)` a documented *weakening*, not a free
modelling convenience.

## 2. Every refusal is observed verbatim

`main` prints the error string and exits 1:

```
examples/zk60_bound_ffn.rs:129-131
    if let Err(e) = run() { eprintln!("{e}"); std::process::exit(1); }
```

So the observable is not a single abort symbol. **The observer learns which
predicate failed**, because the refusal alphabet is the set of distinct strings
in §3. Any experiment that models refusal as one bit understates what is
published.

## 3. The observable-error table

38 predicates, each with its source site. Classes: **P** public policy or
statement, **M** malformed wire/CLI input, **C** owner state or API use, **R**
internal randomness or a challenge value only, **W** the private witness, **I**
internal invariant, **E** deployment state.

| Class | Count | Simulator with only `x` can reproduce? |
|---|---|---|
| P — public policy/statement | 9 | yes |
| M — malformed wire or CLI input | 11 | yes |
| C — owner state / API use | 3 | yes, if it tracks its own owner state |
| R — randomness or challenge only | 7 | yes — it knows the challenges |
| **W — private witness** | **3** | **no** |
| I — internal invariant | 3 | yes (unreachable on a well-formed run) |
| E — deployment state | 2 | yes, given the deployment |

Representative entries (the record carries all 38):

| Site | Message | Class |
|---|---|---|
| `zk_ffn_fresh_io.rs:88` | `expected-policy length` | M |
| `zk_ffn_fresh_io.rs:268` | `expected endpoint root mismatch` | C |
| `zk_ffn_fresh_io.rs:393` | `zero terminal mask challenge` | R |
| **`zk_ffn_fresh_io.rs:400`** | **`IO {i}: equality terminal`** | **W** |
| `zk_ffn_fresh_io.rs:424` | `public W root mismatch` | P |
| `private_seam.rs:74` | `unsupported scale` | P |
| **`private_seam.rs:194`** | **`wrong length or noncanonical input words`** | **W** |
| **`private_seam.rs:471`** | **`terminal equality relation`** | **W** |
| `zk_ffn_fresh_poc.rs:121` | `fresh private weights cannot use the public weight cache` | E |
| `examples/zk60_bound_ffn.rs:110` | `p3 requires explicit 'fresh' policy` | P |

The seven **R**-class predicates are all zero-challenge aborts. O13 established
that neither challenge guard resamples, so the squeeze counter is deterministic
and there is no variable-length or timing channel from them
([O13](ZK60_OPUS_ADAPTIVE_SCHEDULE.md) F13.5). A simulator that knows the
challenges reproduces every R-class event exactly.

## 4. The three witness-dependent refusals

| Site | Message | Predicate |
|---|---|---|
| `zk_ffn_fresh_io.rs:400` | `IO {i}: equality terminal` | the committed endpoint values do not equal the FFN's X/z16 planes |
| `private_seam.rs:471` | `seam: terminal equality relation` | the seam's committed values fail the equality relation |
| `private_seam.rs:194` | `seam: wrong length or noncanonical input words` | the caller's plane is malformed as a *private* value |

**Why a simulator cannot reproduce them.** `finish` deliberately performs no
equality precheck:

```
zk_ffn_fresh_io.rs:274-275
    /// Consumes all private owners on success or failure. No equality precheck:
    /// unequal committed values must fail the verifier's polynomial identity.
```

So a prover holding mismatched endpoints still emits a receipt, and the
**verifier** rejects. A simulator given only the statement — the two roots —
cannot distinguish a matching witness from a mismatching one, because both
produce well-formed roots. It therefore cannot decide whether to output an
accepting receipt or this rejection.

**All three are part of the relation `R`.** Two are the endpoint equality
relation; the third is well-formedness of the caller's plane. In Game V the
wrapper evaluates `(pp, x, w) ∈ R` and refuses before `S_1` is invoked, so the
simulator never faces them. In Game A they are published as distinct strings and
they leak. That is the whole of the difference, and it is why the choice of game
has to be stated rather than assumed.

## 5. Game J's refusal row, restated

Replacing the row I left vague in O9:

| Phase | Real world | Ideal world |
|---|---|---|
| refusal | classes P, M, C, R, I, E: the error string is published and the owner is consumed (`:274`) | `S` reproduces the same string and the same consumption; it has the policy, the challenges, its own owner state and the deployment |
| refusal | class W (the three above) | **out of the game.** The wrapper `S′_1` refuses the request before `S` is invoked. If instead the application publishes these, that is Game A and needs `F`-leaky ZK with `F` naming the predicate |

The consumption behaviour is unchanged and remains reproducible: a refused
attempt burns the owner on every path, and O9 F1 still holds — the public API
admits exactly one proof per endpoint commitment.

## 6. On citing the reference

The endpoint memo links the **EURECOM author-hosted PDF** (30 pages,
sha256 `1846f0cd…`), whose definitions are:

| # | Title |
|---|---|
| 7 | Succinctness |
| **8** | **Wrappers for NIZK Simulator** |
| 9 | Zero-Knowledge |
| 10 | Leaky Zero-Knowledge |

The 68-page ePrint 2023/569 numbers the same content differently — 8
Succinctness, 9 Wrappers, 10 Zero-Knowledge. **My O9 correction applied ePrint
numbering to the EURECOM link and is withdrawn**; the memo's existing
"Definitions 8–10" is correct for the version it cites. The lesson is the one
the round-25 disposition states: cite the version and the definition *title*,
never a numbering assumed to be shared. Both PDFs were fetched and read for this
review and both digests are in the record.

## 7. Findings

**F14.1** — refusal is not one bit. Every predicate's message is published
verbatim (`examples/zk60_bound_ffn.rs:129-131`), so the observable is the
identity of the failing predicate.

**F14.2** — exactly three of 38 predicates are witness-dependent, and all three
belong to the relation `R`, so a relation-checking wrapper removes them from the
game. Everything else is reproducible by a simulator holding the statement, the
challenges, its own owner state and the deployment.

**F14.3** — the equality failure is verifier-side by design (`:274-275`), not an
oversight: the prover does not precheck, so the observable rejection is
witness-dependent by construction.

**F14.4** — the R-class aborts carry no timing or length channel, by O13's
determinism result.

**F14.5** — Game A is a real deployment shape, not a hypothetical: the shipped
CLI is one. Any claim about the deployed tool needs `F`-leaky ZK or an input
validity guarantee, not Definition 9 alone.

## 8. Scope

No production Rust, transcript, proof format, privacy mode or benchmark
parameter changed; this task is read-only over the sources it cites. No archived
report, tool or result was edited. Game V is specified, not proved. The
external-root obligation is untouched and still open, and
`full_privacy_review_complete` and `u2_closed` remain false.
