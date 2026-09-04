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

## 5. DECIDED 2026-09-05: build the simplest form

Victor's standing rule — "start with the most simple option first, and
document the alternative for future exploration as needed". So the
first content filter is:

| | the form we build |
|---|---|
| output shape | **BINARY** — one acceptable class against one unacceptable class (or a single score against a public threshold) |
| the predicate | **one non-negativity fact**: `y[accept] - y[reject] >= 0`, or `y - tau >= 0` for the single-score form |
| machinery needed | **none that is new.** The remainder bit-plane range proofs at the q46 gadget modulus, tied to the q31 value commitments by the U-L modulus link, prove exactly this today |
| acceptable set | **frozen per deployment** — implicit in the statement, no set commitment, no lookup |
| the output | **committed**, because it already is: the output is an activation and the ZK path commits every activation. Not committing it would be a special case, i.e. more work, not less |
| counted cost | **one range fact per proof.** Negligible against a 265 s 8B pass — below measurement noise |

That is the whole content filter. It needs no committed class index, no
LogUp membership lookup, no V − 1 comparisons, and no new primitive:
**one comparison, using machinery that has been running since the
project's first integer chain.**

The generality is what costs, and none of it is needed to ship the
function.

## 6. Documented for future exploration, with what each is worth

Written down so the next agent does not re-derive them, and so nobody
builds them before a measurement asks for it.

### 6.1 N classes with an acceptable SUBSET, argmax hidden

The general form of §2(b): the winning class must not be revealed, only
its membership in the acceptable set S. Commit the winning index *c*,
prove `c IN S` by LogUp membership against a frozen table for S, and
prove `y[c] >= y[i]` for every other *i* with `y[c]` selected through
the committed index.

* **Worth:** the difference between a binary filter and a multi-category
  one (say, a taxonomy of content classes where several are acceptable).
* **Costs:** V − 1 range facts plus one LogUp membership. Free at V = 8;
  ~128k range facts at a vocabulary-sized argmax, which is a real line
  item and must be counted before it is promised.
* **Build it when:** a deployment actually needs more than accept/reject,
  AND the class count is known. Not before — the cost is entirely a
  function of V.

### 6.2 An acceptable set selected per proof

S committed per proof instead of frozen per deployment, so one filter
model can serve several policies.

* **Worth:** one model, many policies, without re-freezing the statement.
* **Costs:** S's commitment must be bound into the statement header
  under the same transcript as the model identity digest, and the
  membership lookup reads a committed table rather than a frozen one.
* **Build it when:** more than one policy is in production against the
  same filter model. Until then a frozen set is strictly simpler and
  strictly safer — a frozen set cannot be swapped by a malicious prover.

### 6.3 Selective disclosure of the output

Reveal part of the committed output (a score, a rank) while keeping the
rest hidden.

* **Worth:** richer verifier semantics — "acceptable, and here is the
  confidence" — without giving up the input.
* **Costs:** an opening at a chosen point plus a decision about what the
  revealed value leaks. The output is already committed (§5), so the
  door is open; nothing needs to change now to keep it open.
* **Build it when:** a customer asks for it. The commitment choice made
  in §5 is what preserves the option.

### 6.4 Not taken, and not recommended

* **Proving a disjunction over classes directly** (`EXISTS c IN S`
  without committing *c*) — the textbook route, and more expensive than
  §6.1 for no benefit here, because committing *c* and looking it up is
  cheaper with the machinery this repository already has.
* **A policy layer outside the proof.** The whole value of function 2 is
  that acceptability is enforced by soundness. Any check that lives
  outside the statement can be bypassed and should not be described as
  part of the guarantee.

## 7. Still genuinely open

* The counted cost of §6.1 at a real V. The V − 1 figure is arithmetic,
  not a benchmark.
* Whether the binary filter's two scores come from a dedicated
  classification head or from a repurposed language-model head — that is
  a modelling question, and it decides what the export contains.
