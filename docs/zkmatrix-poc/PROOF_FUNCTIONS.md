# The two proof functions, and what each one requires of the statement

Status: LIVE, written 2026-09-05 (orchestrator, Claude) from Victor's
console ruling. This page exists because the two functions below are
NOT two settings of one proof — they make different claims, hide
different things, and the second needs machinery the statement does not
have yet. Getting this wrong ships a false privacy claim, which is a
worse failure than a slow prover.

Companion to `TARGET_CONTRACT.md` (which this will amend once lane AM
reports) and `U_PERF3_SIXTY_TOKENS_PLAN.md` (the two tiers).

---

## 1. The two functions, stated exactly

### Function 1 — ATTESTED INFERENCE

*"A forward pass really happened through the model that is claimed."*

| | |
|---|---|
| private | the input, **all** activations, **and the output** |
| public | the model identity digest, the statement's shapes and quantization metadata, the proof |
| the verifier learns | "this exact model, on some committed input, produced some committed output" — and neither value |
| output handling | bound as a **commitment**; never in the clear |

### Function 2 — VALIDATED CLASSIFICATION (the ZK content filter)

*"This content was classified, by the agreed filter, as acceptable."*

| | |
|---|---|
| private | the input and **all** activations |
| public | the model identity digest, the predicate, the proof — **and one bit: that the predicate holds** |
| the verifier learns | "this exact filter model, on some committed input, produced an output in the ACCEPTABLE class" — and nothing else about the input or the output |
| output handling | bound as a commitment, **plus a proven predicate over it** |
| the enforcement | **only class-acceptable proofs verify at all.** An unacceptable classification cannot be given a passing proof — the filter is enforced by the soundness of the proof system, not by a policy layer that could be bypassed |

---

## 2. What each needs from the engine

### Function 1: an output commitment, and honest bookkeeping

Nearly built. Lane ZA's zero-knowledge form already commits every
activation hidingly, and the final layer's output IS an activation. The
open question is whether the STATEMENT still declares the output values
in the clear for the verifier to check against — `TARGET_CONTRACT.md`
§3 says it does ("the declared output tensor values" are public), while
`U_PERF3_ROUTE_B_THROUGHPUT.md` §4.5 gives P1's private set as "inputs
/ activations", which would cover it. **Both can be true of different
things**, which is exactly why lane AM was told to answer it from a
produced proof rather than from the documents.

### Function 2: a PREDICATE over the committed output — new machinery

This is the part that does not exist. The statement must carry, and
prove, an assertion about the committed output without revealing it.
Two instantiations, in increasing difficulty:

**(a) Threshold on a named class — trivial.** "Class *j*'s score is at
least τ", for public *j* and public τ. One non-negativity fact on
`y[j] - τ`. The project's range machinery already does exactly this
(the remainder bit-plane range proofs at the q46 gadget modulus, tied
to the q31 value commitments by the U-L modulus link). Cost:
negligible.

**(b) Argmax lies in an acceptable set — the real one.** "The winning
class is a member of the public set S." Naively this reveals which
class won, which is more than one bit. Done properly it does not, and
**the machinery for it is already in this repository**:

1. Commit the winning class index *c* as part of the witness.
2. Prove `c ∈ S` by **table membership** — this is a LogUp lookup, the
   same subprotocol the activation tables already use, with S as a
   frozen public table.
3. Prove `y[c] ≥ y[i]` for every other class *i*, with `y[c]` selected
   through the committed index rather than a public one. Each
   comparison is a non-negativity range fact on a difference.

Cost is **V − 1 range facts** for V classes. For a content filter with
a handful of classes this is free. For an argmax over a ~128k-token
vocabulary it is ~128k range facts — affordable (comparable to a
fraction of one layer's range work) but no longer free, and it should
be counted before it is promised.

**Neither instantiation needs private weights.** See §4.

---

## 3. Consequences that must be stated, not discovered later

- **Refusal semantics.** If only acceptable proofs verify, then the
  absence of a proof is not evidence of unacceptable content — the
  prover may simply not have tried. The deployment posture must
  therefore be **"no valid proof ⇒ reject"**. This is the correct
  posture and it should be written into the product description rather
  than assumed by integrators.
- **The prover always learns the classification.** They ran the model.
  Function 2 hides the classification from the VERIFIER, not from the
  party doing the filtering. If the content owner and the prover are
  different parties, that is a deployment question with real privacy
  content, and it is not something the proof system can fix.
- **One bit is still a bit.** A valid function-2 proof reveals that the
  input was acceptable. Over many proofs about related inputs, that bit
  is information. Worth stating; not worth solving here.
- **The predicate is part of the statement's identity.** A proof of
  "acceptable under predicate P against filter model M" must not be
  presentable as a proof under a different predicate or a different
  model. The predicate identifier and the model identity digest belong
  in the same statement header, bound by the same transcript.
- **Function 1 and function 2 proofs must not be interchangeable.** A
  function-1 proof says nothing about acceptability; if the two share a
  format, a verifier could be induced to read one as the other. The
  mode declaration must distinguish them.

---

## 4. How this maps onto the two product tiers — and it maps well

The 2026-09-05 rulings set a FAST tier (private inputs and outputs,
public weights) and a FULL tier (private weights too). The two
functions do not split the same way, and the fit is better than it
looks:

- **Function 2, the content filter, wants PUBLIC WEIGHTS.** For a
  filter, everyone concerned should be able to audit *what filter was
  applied*. A publicly committed, publicly inspectable filter model is
  a feature, not a compromise — and it is the cheap tier. So the ZK
  content filter is buildable on exactly the track just chosen, with no
  private-weight machinery at all.
- **Function 1, attested inference, is the one that may eventually want
  private weights** — a model vendor proving their proprietary model
  ran. That is the full tier, and the reason to keep building toward
  it.

So the fast tier is not merely the cheaper stepping stone; it is the
right home for one of the two products outright.

---

## 5. What is NOT decided here

- The filter's output shape: binary accept/reject, or N classes with an
  acceptable subset. This changes whether §2(b) costs nothing or costs
  V − 1 range facts, so it should be settled before the gadget is
  built.
- Whether the acceptable set S is fixed per deployment (a frozen table,
  cheapest) or selectable per proof (a committed table, and then its
  own commitment must be bound into the statement header).
- Whether function 2 also commits the output at all, or only proves the
  predicate. Committing it costs almost nothing and keeps the door open
  to selective disclosure later; not committing it is marginally
  cheaper and closes that door.
- The counted cost of either instantiation. Nothing in §2 has been
  measured, and the V − 1 figure is arithmetic, not a benchmark.
