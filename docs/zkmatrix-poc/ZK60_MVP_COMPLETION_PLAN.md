# ZK60 — What "finish the MVP" means, and the ordered plan to get there

**Status: DRAFT — delegated analysis, not yet reviewed by the security owner.**
Written 2026-09-19 by a delegated read-only analyst. No builds, no proofs, no
tests were run; every claim below is a citation to a file and a line in this
repository or in a sibling worktree. Nothing here accepts a privacy property,
and nothing here reopens a decided ruling.

---

## 0. How to read this document

The question put to me was the owner's own: **"finish the MVP."** To answer it
I had to first find out what the project has written down that "the MVP" means,
because that phrase is used for at least five different things in this
repository. Section 1 collects every definition and shows where they disagree,
then turns them into one checklist of gates, each marked MET, PARTLY MET or
OPEN with the file that is the evidence. Sections 2 to 4 measure the three
distances that are actually left: from the tiny block to a real model, from a
proof that verifies to a proof anyone may call private, and from two separate
proving lines to one honest sentence. Section 5 is the ordered plan, section 6
the three lanes that can start today.

**Words you will meet.**

* **P1** — the decided privacy scope: inputs, outputs and every intermediate
  activation hidden from the verifier and from every public artifact; model
  weights may be public. **P3** additionally hides the weights.
  `ZK60_PRIVACY_REQUIREMENTS.md:9-14`, ruling D1 in `ZK60_DECISIONS.md:13`.
* **The two lines** (ruling D2, `ZK60_DECISIONS.md:14`). The **zkVM line** runs
  the exact integer block as an ordinary program inside RISC Zero's virtual
  machine and proves the execution; its public artifact is a 785-byte Groth16
  receipt. It is a privacy demonstrator and, by that ruling, never the
  product's prover. The **custom line** is this project's own prover,
  `hashline/`; it is the only route to the speed target.
* **A receipt** is the bytes a verifier is given. "Verifies in a fresh process
  from bytes only" means a separate program, started clean, given nothing but
  the public statement and those bytes, accepts.
* **An endpoint** is the commitment that stands for the hidden input or the
  hidden output of a proof on the custom line. A **caller-fixed** endpoint is
  one the verifier was handed before the proof existed; that is the setting of
  the open obligation D8/D11 (§3.3).
* **A capture** is a recording of everything a verifier sees during one real
  proof, written in a fixed format ("schema 3") so that the project's
  privacy-checking tools can be run on it afterwards.
* **Tiny geometry** means T32/d16/f16: 32 tokens, model width 16, feed-forward
  width 16, two query heads, one key/value head. **8B geometry** means width
  4096, feed-forward width 14336, 32 query heads over 8 key/value heads, a
  ~128,000-word vocabulary (`TARGET_CONTRACT.md:21-24`).
* Measurement labels follow the house rule: **[MEASURED]** a run happened,
  **[COUNTED]** arithmetic on measured pieces, **[MODEL]** an estimate. No
  number in this document is a quiesced benchmark.

**What this document deliberately does not do.** It does not accept any
privacy property, reopen D1, D2, D3, D4, D5 or D12, or attempt to prove or
refute D8/D11. It does not restate the speed plan: a separate analyst is
writing `ZK60_FIVE_SECOND_PLAN.md` (present as a draft skeleton at the time of
writing). Where the two plans touch, §5.3 names the point and stops.

## 1. What the MVP is — the definitions on record, and where they disagree

### 1.1 The definitions

Seven documents define something they call the MVP, the PoC, or the acceptance
target. They are listed here in the order they were written, because the later
ones correct the earlier ones and nobody has retired the earlier ones.

**D-1. The frozen benchmark contract (the destination).**
`TARGET_CONTRACT.md:1` — *"What a 5-15 s Proof of an 8B Feedforward Will
Mean."* The model is Llama-3-8B-class: feed-forward width 14336, grouped-query
attention with 32 query heads over 8 key/value heads and head dimension 128,
rotary position embeddings, softmax, RMSNorm twice per layer, residual
additions, embedding and unembedding at ~128,000 words
(`TARGET_CONTRACT.md:21-24`). That line then says, of all of those:
**"None of these are implemented in the proof system today"**
(`TARGET_CONTRACT.md:25-26`). The clock starts with the committed model and
input tokens in memory and stops when the serialized proof bytes exist; it
excludes one-time setup such as committing the weights
(`TARGET_CONTRACT.md:85-96`). Publication needs at least 20 warm runs on an
idle named machine, p95 with p50 alongside and a separate cold row
(`TARGET_CONTRACT.md:124-127`), a proof-size budget of 256 KB or less
(`TARGET_CONTRACT.md:128`), and a GPU of at most 600 W board power
(`TARGET_CONTRACT.md:102-116`, the 2026-09-04 ruling amending 450 W).

**D-2. The roadmap's "PoC-complete" (the 125M rung).**
`LLM_POC_ROADMAP.md:19-32` — one 12-layer feed-forward pass of the frugal-lm
125M model with **real trained weights**, shapes 768→2048, under one statement
on the CPU box, with the artifact inside its size budget, verification ≤ 2 s,
the adversarial battery green, and prover wall-clock measured rather than
targeted. Written 2026-08-08.

**D-3. The execution contract's acceptance target.**
`ZK60_EXECUTION.md:70-76` — *"a calibrated 8B-class model at 512 prefill rows,
with P1 … and P3 … reported separately. The target clock is 512 / 60 =
8.533333 seconds from input/witness preparation through serialized proof
readiness."* Same page, `:88-93`: today's coverage is feed-forward only for
`pass`, transformer blocks for `attn-pass` (with no zero-knowledge
integration), and **"Neither path can report `goal_met: true`."**

**D-4. The task ladder (the engineering definition).**
`zk60_private_block_tasks.json` sets the milestone as **A07**, *"Compose the
first complete P1 transformer block"* — `"first_complete_milestone": "A07"` —
then **A08** (a private two-block chain plus independent verification from
framed bytes), **A09** (P3 with approved private-model consistency) and
**A10** (embedding, final norm, head, token selection, KV and window state).
A10's acceptance line is the sharpest sentence in the file: *"Only this
complete relation can support a generated-token throughput claim; 512 prefill
rows remain a separately labeled milestone."*

**D-5. The September 15 refresh (the "next implementation gate").**
`ZK60_MVP_20260915.md:10-17` — *"one tiny fixed-calibration P1 transformer
block, T32/d16/f16, with hidden input, output and intermediate activations,
independently approved public weights, actual attention/FFN boundary equality,
and saved bytes verified in an independent process … The complete verifier view
must meet the stated privacy requirements."* And immediately, `:13-15`:
**"This is an engineering milestone toward the model-scale MVP, not a
replacement for the 8B/model-coverage goal in the execution contract."** Its
shortest sequence (`:56-70`) runs: reproducible FFN component → resolve the
security experiment → private attention → compose the block → two-block chain →
embeddings/head/token decision.

**D-6. The milestone map's gate table.** `ZK60_STATUS.md:306-316` lists six
gates with owners: B4 (externally bound public receipt, **acceptance passed**),
whole-profile privacy and identity, one complete private block then two, the
complete generated-response relation, bounded-memory GPU execution, and target
measurement.

**D-7. The living status page.** `MVP_STATUS.md:11-13` answers "do we have a
workable proof" with **"A complete small-block experiment works. The model MVP
remains open."** and `:88-92` sets the speed question against *"5 to 15 seconds
per proof of an 8B model's feed-forward blocks over 512 tokens, on one consumer
GPU (p95 over 20 warm runs, idle machine)."*

Two more framings, not definitions but binding on how progress is reported:
`ZK60_MVP_LOOP_20260918.md:1-4` — *"The user explicitly asked to continue until
a workable MVP … Component progress does not close it"* — and
`ADVERSARIAL_TESTING_PLAN.md:1-8`, which shelves the whole adversarial campaign
*"until the working PoC"* and says it *"activates by ruling once the 8B FFN PoC
proof has run end to end."*

### 1.2 Where the definitions disagree

**Disagreement 1 — the privacy mode of the PoC. This one is a live
contradiction and should be fixed by deleting a sentence.** The roadmap's
PoC-complete definition asks for the 125M pass *"in mode P2 (weights private,
inputs public)"* (`LLM_POC_ROADMAP.md:22-23`). Ruling D1 and the privacy
requirements say the first proof of concept is **P1**: inputs, outputs and
activations hidden, weights may be public
(`ZK60_PRIVACY_REQUIREMENTS.md:9-14`; `ZK60_DECISIONS.md:13`). P2 and P1 hide
opposite halves of the computation. The roadmap page predates the 2026-09-09
reaffirmation by a month, and `ZK60_PRIVACY_REQUIREMENTS.md:26-30` explicitly
says public-input diagnostics "do not satisfy the PoC privacy target". D1
governs; **the roadmap's clause is stale and, because it is the only page that
states the PoC as one runnable definition, it is the page most likely to be
quoted by mistake.** Recommended correction in §5.2, delivery R0.

**Disagreement 2 — the number of seconds.** Three figures are in force at
once: "5-15 s" (`TARGET_CONTRACT.md:1`), "512 / 60 = 8.533333 seconds"
(`ZK60_EXECUTION.md:72`, derived from a 60-rows-per-second goal), and the
owner's working figure of 5 s. They are not contradictory — 5 s is the hard
end of the contract's range and 8.53 s is what 60 rows/s implies at 512 rows —
but any status line that says "we are N× off" must name which of the three it
divides by. `MVP_STATUS.md:97` quotes both ("19× slower than 5 s, 6× slower
than 15 s"), which is the right form.

**Disagreement 3 — which model.** The contract's *measured surrogate* is the
Llama-2-7B feed-forward geometry, 4096→11008 (`TARGET_CONTRACT.md:16-20`); its
*target* is 8B-class with attention and a vocabulary head
(`TARGET_CONTRACT.md:21-24`); the roadmap's integration rung is frugal-lm 125M,
768→2048 (`LLM_POC_ROADMAP.md:19-21`); and every private artifact that exists
today is at T32/d16/f16. Four scales, one word. There is no contradiction in
intent — they are rungs of one ladder — but there is no single page that states
the ladder as "MVP = rung k", so "the MVP" silently means a different rung in
different documents.

**Disagreement 4 — feed-forward blocks, or a model that emits a token.** The
contract's headline claim is literally about *"an 8B Feedforward"*
(`TARGET_CONTRACT.md:1`) and `ZK60_EXECUTION.md:72` clocks 512 prefill rows.
But `ZK60_STATUS.md:352-355` says that arithmetic *"is meaningful for the
target only with the required model/operation coverage"*, and A10's acceptance
says only the complete generated-response relation can support a
generated-token claim. So the speed target and the product target measure two
different computations, and the project is careful about it in the status pages
and loose about it in the word "MVP".

**Disagreement 5 — is the tiny block the MVP?** No, and the documents say so
plainly: `ZK60_MVP_20260915.md:13-15` ("not a replacement for the
8B/model-coverage goal") and `MVP_STATUS.md:13` ("The model MVP remains open").
This is a labelling hazard rather than a contradiction, but it is the most
expensive one available: two receipts now exist that are easy to describe as
"we proved a private transformer block", and both of them are at a geometry
1/256th the width of the target, on synthetic weights.

**A near-disagreement worth recording.** D-5 requires *"actual attention/FFN
boundary equality"* (`ZK60_MVP_20260915.md:12`). The custom-line block that was
built has **no boundary at all**: form (S), the attention construction grown
into the whole block, so the second norm's output is one plane read by two
relations and there is nothing to prove equal
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:18-21`). That satisfies the
intent (the two halves are bound) and fails the literal words. The gate text
should be restated as "the two halves are bound by the proof, by equality or by
construction".

### 1.3 The MVP as one checklist of acceptance gates

Reading all seven definitions together, the MVP is: **a proof that an approved
real model, at model scale, produced a particular answer, with the prompt, the
answer and everything in between hidden, checkable by a stranger from bytes
alone, fast enough to be usable.** That decomposes into fourteen gates. Each is
marked for the line it belongs to; where the two lines differ, both are shown,
because a gate met on the zkVM line is explicitly not met on the custom line
(ruling D2).

| # | Gate | Status | Evidence / what is missing |
|---|---|---|---|
| **G1** | One complete transformer block proved with hidden input, output and activations, verified in a fresh process — **zkVM line** | **MET as an experiment** | 785-byte Groth16 receipt, fresh-process verify 8 ms, seven corruption controls plus the inner-receipt-kind control rejected (`MVP_STATUS.md:13-22`). Rests on D3 (≈97 bits conjectured), D4 (trusted setup), D5 (Groth16 only) — all accepted rulings. **Qualifier:** D7, the salted-SHA-256 endpoint and identity profile, is *implemented, ruling pending* (`ZK60_DECISIONS.md:19`, `:216-226`), so the artifact is "complete-block experiment", not "private block" |
| **G2** | The same, **custom line** | **PARTLY MET** | Proves and verifies: 2,816,472-byte receipt, prove 0.095 s, fresh-process verify 0.041–0.043 s, 46 unit + 4 integration tests, witness equal to the reference kernel on 1,200 cases, nine verifier-side tampers rejected (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:8`, `:41-52`). **Accepted only as an experimental component; no privacy property is established** (`:73-92`). The privacy half of the gate is G6 |
| **G3** | Two private blocks chained — **zkVM line** | **MET as an experiment** | Two-block token model, hidden seam inside one program, 785-byte Groth16 receipt, eleven rejection controls, the block-profile verifier refuses it as a different profile; prove 7,488 s, wrap 197 s [MEASURED, NOISY-SHARED] (`MVP_STATUS.md:30-38`) |
| **G4** | Two private blocks chained — **custom line** | **OPEN** | Ruling D12 forbids the obvious join: no commitment may be opened twice, and a hidden value may not sit on a caller-fixed endpoint shared by two proofs (`ZK60_DECISIONS.md:276-305`). The route left is the deferred equality-seam form, specified but unbuilt (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:517-527`, seam S5) |
| **G5** | Embedding, final norm, output head, token selection, request and state binding | **PARTLY MET on the zkVM line; OPEN on the custom line** | `private-model-kernel/src/lib.rs:1-16` computes embedding gather → two blocks → final norm → int8 head → greedy next token, and its zkVM proof exists (G3). But: public embedding, 32-word vocabulary, no KV cache, no sampling, no EOS, one token only, explicitly *"NOT 125M/8B coverage and NOT MVP completion"* (`:5-16`). On the custom line this is task A10, untouched |
| **G6** | Whole-proof privacy **accepted** on the custom line | **OPEN** | Three things are missing and they are ordered: no schema-3 capture writer for the attention or block profiles (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:116`, gap G6); therefore the round-2 joint-view tools have never run on a real block receipt (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:75-81`); and the caller-fixed-endpoint obligation D8/D11 is open (`ZK60_DECISIONS.md:228-274`). §3 sets this out in full |
| **G7** | Real trained, calibrated weights | **OPEN on both lines** | Every private artifact on either line is a public synthetic fixture (`MVP_STATUS.md:43-44`; `ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:83`). The calibration machinery works and is measured on real checkpoints — Mistral-7B +0.216 nats, Gemma-4-12B +0.035 under the widened stack (`U_PERF3_QUANTIZATION_MEASUREMENTS.md:37-41`) — but nothing connects it to a private block. §2.2 |
| **G8** | Model-scale geometry (8B widths) under privacy | **OPEN** | Public-input/output proofs of real 7B-class feed-forward stacks exist and are measured (`MVP_STATUS.md:97`). No private proof exists above T32/d16. §2.1 lists what breaks |
| **G9** | Approved-model identity: the proof is for *this* approved model, not merely *a* model | **PARTLY MET** | The metadata contract exists and is tested (`ZK60_BLOCK_CONTRACT.md:9-34`, 7 tests, 42 hostile mutations, `:91-99`), and the stable-weight registration and storage exist (`ZK60_STABLE_WEIGHT_REGISTRATION.md:1-8`). For P1 with public weights the binding is the approved public roots, which the custom block enforces. For P3 the constraint is **missing entirely**: two different hidden weight tensors verify under one declared model, reproduced at the tiny shape (`ZK60_FABLE_MODEL_IDENTITY.md:20-30`). D7 is the zkVM line's version of the same question, pending |
| **G10** | Independent verification from bytes in a fresh process | **MET at the tiny shapes, both lines** | zkVM: `MVP_STATUS.md:20-22`. Custom block: `ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:46-49`. Custom FFN component demo: 5,029,244-byte receipt, six rejection controls (`ZK60_MVP_REVIEW.md:9-14`). Public two-block receipt B5, 4,290,981 bytes, separate-process bounded verification (`ZK60_STATUS.md:291`) |
| **G11** | Speed: 5–15 s for the 8B feed-forward blocks over 512 tokens, p95 over 20 warm runs on an idle named consumer GPU | **OPEN** | Best measured public-IO 8B pass on the laptop GPU: prove 95 s, verify 1.1 s, 1.23 GB proof — 19× the 5 s figure (`MVP_STATUS.md:97`). The project's own model says the built design does not reach the goal on any GPU without recorded design changes that were counted and not built (`MVP_STATUS.md:126-131`; `START_HERE.md:260-265`, which puts the gap at 140–420× on this laptop and 10–50× on a desktop board, *"in the shape of the protocol, not in tuning"*). The separate speed plan owns this gate |
| **G12** | Proof-size budget: ≤ 256 KB serialized | **OPEN** | `TARGET_CONTRACT.md:128`. Today: 2,816,472 B for the tiny private block, 1.23 GB for the 8B public-IO pass. The zkVM line's 785 bytes meets it but is not the product prover (D2). Lever D10 (1.94 MB instead of 38.7 MB per Mistral layer, at 4.4× prover time and 95–98 bits) is a **pending owner ruling** (`ZK60_DECISIONS.md:348-351`) |
| **G13** | Security level | **DEVIATED, recorded** | Target 128 bits. Accepted: ≈97 bits conjectured for the zkVM intermediate (D3) and its trusted setup (D4). The custom line's default profile is 106 bits, and D10 would take it to 95–98 (`ZK60_DECISIONS.md:80-84`). D9, the `fp()` reduction-bias term of about 2^-75, is a **pending ruling** (`:340-346`). None of these is a defect; all are open owner-facing deviations |
| **G14** | The adversarial campaign | **SHELVED by ruling, correctly** | `ADVERSARIAL_TESTING_PLAN.md:1-8`: shelved by Victor 2026-08-30, *"activates by ruling once the 8B FFN PoC proof has run end to end."* Its standing rule — every new statement feature ships its tamper legs at the same commit (`:79-85`) — has been honoured by both recent lanes |

**Summary count: 3 MET (G1, G3, G10 — two of them only on the line that by
ruling cannot be the product), 3 PARTLY MET (G2, G5, G9), 6 OPEN (G4, G6, G7,
G8, G11, G12), 1 recorded deviation (G13), 1 correctly shelved (G14).**

**Three pending owner rulings sit inside this table and block nothing today but
will block a claim later: D7 (the zkVM statement), D9 (the bias term), D10 (the
proof-size lever).** §3.4 says what each one gates.

## 2. The distance from the tiny block to a model

### 2.1 Real geometry (width 16 → 8B widths)

The tiny block is 32 tokens at width 16. The target is 512 tokens at width
4096 with feed-forward width 14336. That is 256× the width and 16× the tokens.
Six specific things break, and none of them is "make the numbers bigger".

**(a) A new domain variant is required at every geometry, and the tiny shape
hides it.** At T32/d16/f16 the feed-forward width equals the model width, so
the feed-forward axis happens to be the same 512-entry, 9-variable cube as the
model axis. The construction memo is explicit that this is a coincidence and
that a distinct `Dom::F` is needed anyway, because the domain key drives the
lookup list, the helper block and the per-domain enumeration; *"Only the log
coincides with `Dom::D`'s here, and that coincidence of size will not hold at
125M or 8B"* (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:744-754`). So the first
non-tiny shape is not a parameter change; it is a layout change.

**(b) The single 8-bit range table is a deliberate trade that has never been
priced above tiny.** The accepted attention component replaced the declared
table set (Int16, U16, Prob, Srem, Win) with **one 256-entry U8 table**,
expressing every range as byte limbs. That cut the two commitments from 1,487
and 2,490 rows to 306 and 290 — the two 65,536-entry tables alone had accounted
for about 77 MB of extra committed rows
(`ZK60_PRIVATE_ATTENTION_NATIVE.md:64`;
`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:125-130`). *"The price is more planes
(limbs) and more lookups"* (`ZK60_PRIVATE_ATTENTION_NATIVE.md:64`). At the tiny
block that price is 61,440 byte lookups
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:29-33`). Lookups scale with
the number of committed values, which scales with width; whether one byte table
or the big tables is cheaper at 4096 has **not been measured**, and the two
choices produce different layouts, so it is a decision to take before building
at scale, not after.

**(c) The mask rows have a hard headroom rule that is checked at tiny and
unchecked at scale.** Every slot's mask row is laid out as
`[L_s ‖ 256 pads ‖ zeros]` on a 512-wide group, so the acceptance condition is
`L_s + 256 ≤ 512` on every slot — largest 62 in the attention component, 50 in
the block (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:83`;
`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:98-103`). Slot lengths grow
with the number of sumcheck rounds, which grows with the logarithm of the
domain, so this is not obviously violated at 8B — but it is a **hard refusal**
that nobody has evaluated at the larger logs, and the whole mask layout and the
proof-parameter triple (`log_cols = 8`, inverse rate 8, 256 column checks;
`ZK60_BLOCK_CONTRACT.md:46`) were chosen for T32.

**(d) The block as built gives up the GPU feed-forward prover. This is the
single most important geometry fact in this document.** The design accepted
form (S) — no seam, the attention construction grown into the whole block — and
with it T1's decision 13: *"for the tiny block the feed-forward is re-derived
on the host and does not inherit the GPU prover"*
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:45-47`). The deferred
alternative, form (E), an equality between two components' own commitments, *"is
worth the 8B feed-forward prover. The block-decomposed CUDA path
(`layer.rs:1379-1400`, `zk.rs:2685-2690`) is the custom line's only measured
route to throughput, and form (S) does not inherit it"*
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:282-289`). Form (E) is also what a
*streamed* multi-block proof needs if one block's commitments cannot all be
resident at once — *"a constraint that does not bind at T32/d16 and does bind
at 8B (`zk.rs:2388-2394`)"* (same page, `:286-290`).

**(e) Memory, on the hardware that exists.** The 8B pass peaks around 72 GB in
the cheaper range-only mode [COUNTED] (`START_HERE.md:253-256`) against a
15 GiB laptop with an 8 GiB card. The memo names the two measurements that
would force form (E), both at the 125M rung on a quiesced box: peak resident
bytes of a single form-(S) commitment against the two form-(E) commitments plus
their simultaneous residency, and the prover wall-clock of the feed-forward
half, host-only against the GPU path
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:291-302`). *"Neither measurement is taken
here, and neither can be taken on the current box while it is loaded."*

**(f) The soundness margin thins with depth, and one known gap opens exactly at
8B geometry.** The project's own accounting projects an 8B proof at 32 layers ×
6 openings to about 2^-94 rather than the tiny profile's 2^-110
(`ZK60_FABLE_SECURITY_OBLIGATIONS.md:408`). Worse, the same page records an
open soundness gap tied to the norm's integer-square-root limbs: *"any profile
with n_limbs >= 3 (… e.g. an Int24 residual class at d = 4096 …) and tn >= 1
accepts an all-zero norm output row"*, with a reproduced counterexample
(`:101`). Section 2.2 explains why a real 7B-class model needs exactly that
int24 residual class. **These two facts meet: the quantization the real model
requires lands the norm in the profile where the soundness gap is open.** Fix
candidates are named on that line (a direct range fact on `D`, or a parity /
small-range fact on `a1 + a2`); neither is built.

### 2.2 Real trained and calibrated weights

A proof system that only proves synthetic numbers proves nothing anyone wants.
This is the part of the project that is furthest along in *measurement* and
completely unconnected to the private line in *code*.

**What was measured.** Modern 7B-plus transformers cannot be represented by
the frozen contract's static per-tensor power-of-two int8 chain. Mistral-7B
fails at +8.18 nats and 14,531 held-out range violations; Gemma-4-12B-QAT at
+17.60 and 116,852 (`U_PERF3_QUANTIZATION_MEASUREMENTS.md:13-26`). The cause
was found not to be range coverage but **resolution**: a few outlier channels
stretch per-tensor ranges 40–6000×, collapsing the bulk signal into a handful
of int8 levels at two to four specific sites. Every range-covering mechanism
tried reduced violations to tens and moved quality by nearly nothing.

**The fix on record — the "widened stack".** Four items
(`U_PERF3_QUANTIZATION_MEASUREMENTS.md:28-36`): (1) the activation table's
**output** at int16 resolution while its domain stays 256 int8 rows; (2)
int16 classes at the up-output, Hadamard-product and down-output sites; (3)
round-to-nearest requantization; (4) the input and the gate/up matmul inputs
stay int8. Result: Mistral +0.2157 nats, Gemma +0.0353 — a 38× recovery on
Mistral, and Gemma below its own weights-only floor (`:37-42`). Weights stay
int8 everywhere. A later ruling added **clamp-at-z** for Gemma's roaming tail
elements (`:162-170`).

**What the tiny block's integer specification already covers, checked in the
source.** More than I expected. `private-block-kernel/src/lib.rs`:

* the activation table is `act: [i16; 256]` (`:182`) — a 256-row int8 domain
  with **int16 output**: widened-stack item 1, present;
* `u16`, `h16`, `z16` are int16 classes and the class constants are
  `I8N = (-127,127)`, `I8`, `I16` (`:94-96`) — item 2, present;
* `requant` is documented and implemented as *"round to nearest, ties toward
  +inf"* (`:294-308`) — item 3, present;
* the input and the gate output are int8 (`nm` in `[-127,127]`, `g8` int8) —
  item 4, present;
* refusal, never clamping: *"an out-of-class value is a refusal, never a
  saturated result"* (`:26-28`).

So the tiny block is not a toy integer scheme; it is the widened stack at
width 16.

**What it does not cover, and what that costs.**

1. **The int24 residual class.** The tiny block's residual values are int16
   (`SH_X1 = SH_R1 = SH_X2 = SH_Z2 = SH_R2 = 0` with int16 classes,
   `lib.rs:73-87`). Mistral's attention verdict is that the compute core is
   int8-clean but *"the residual stream is the one poisoned site"*: `xres` at
   int8 costs +9.72 nats, at int16 still +0.12 — missing the class — and
   **"xres needs int24"**; the quotable row is *"stack_wide (xres int24, ao
   int16) = +0.0266"* (`TASK_BOARD.md:1164-1180`). The statement consequence
   recorded there: *"xres and therefore THE SEAM are int24 (two 16-bit limbs
   against the existing table)"*. As §2.1(f) showed, that is the profile with
   the open isqrt soundness gap. **This is the single largest
   quantization-to-proof gap, and it is where quantization and soundness
   collide.**
2. **Clamp-at-z.** Ruled in on 2026-08-27 for Gemma; the kernel clamps nothing
   anywhere by design. `U_PERF3_QUANTIZATION_MEASUREMENTS.md:198-200` lists
   *"the clamp-selector relation at the z edge"* as an open statement
   obligation, needed only when a witness actually clamps.
3. **Per-channel exponent vectors (contract item C2).** The tiny calibration is
   a single frozen set of scalars, *"deliberately not configurable: a different
   calibration is a different kernel"* (`private-block-kernel/src/lib.rs:57-59`).
   C2's per-channel vectors remain in the contract as an optional mechanism not
   required by either measured checkpoint (`QUANTIZATION_CONTRACT_DESIGN.md:104-107`),
   but a real model needs at minimum per-tensor exponents that vary by layer —
   and the engine already had to be extended once for per-tensor weight
   exponents when the 125M's uniform −9 had hidden the need
   (`U_PERF3_QUANTIZATION_MEASUREMENTS.md:177-181`).
4. **The qualification gate is not wired to the private line.** Gate C4 —
   zero range violations, quality delta within budget, every table member in
   the frozen registry (`QUANTIZATION_CONTRACT_DESIGN.md:86-99`) — is a
   mechanical script run whose verdict JSON is meant to be part of the public
   record. No private artifact carries one.
5. **The calibration digest is a pinned literal, not a statement field.** The
   block's disposition accepts this *"for the proof of concept, to become a
   statement field when a second calibration exists"*
   (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:36`). A real model is the
   second calibration.
6. **Grouped-query attention at real ratios, non-power-of-two head maps and
   dummy heads** are listed as not covered (`ZK60_OPUS_ATTENTION_INVENTORY.md:757`).

**The good news, stated plainly.** Real int8/int16 exports of both Mistral-7B
(32×512) and Gemma-4-12B (48×512) exist, and the Rust engine re-derives both
bit for bit, with full-plane SHA-256s equal and every table row a frozen
registry member (`U_PERF3_QUANTIZATION_MEASUREMENTS.md:172-181`). The witness
side of "a real model" is done; it has simply never met a private prover.

### 2.3 Many layers: binding block k to block k+1 under D12

A model is 32 blocks, not one. The obvious way to chain them is the way that
is now forbidden, and understanding why is the key to the rest of the plan.

**Why the obvious way is forbidden.** Block *k*'s hidden output is block
*k+1*'s hidden input. The natural design is to commit that value once and let
both proofs open the same commitment. Ruling D12 forbids it, and not on
principle: *"at the actual endpoint geometry (7 rows of 256 columns) two
openings recover all 512 hidden words"*
(`ZK60_DECISIONS.md:281-285`). That is not a worry, it is a reproduced native
test: *"Two native PCS openings at the actual seven-row, 256-column endpoint
geometry recover all 512 data words, using only the two public group vectors
and their public challenge coefficients. The fresh-owner control does not
recover the plane"* (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:3-9`). The
algebra is simple: each opening publishes `v = a·x + b·y + c·m`; two openings
cancel the mask `m` and leave two equations in two unknowns with an invertible
public coefficient matrix (`:16-21`).

**So D12's three binding clauses** (`ZK60_DECISIONS.md:289-299`): no commitment
is opened more than once anywhere in a composed block; a block is one proof
under one transcript with exactly two external endpoints, its hidden input and
its hidden output; hidden intermediates never get a caller-fixed endpoint
commitment shared by two proofs.

**What that leaves for a chain — exactly two routes.**

*Route 1: one proof for everything.* Extend form (S) — the no-seam shape that
was actually built — across all 32 blocks. Every hidden intermediate lives on
one proof's own commitments. This is the form that works today at one block,
and it is the form that **cannot stream**: all commitments must be resident at
once, the constraint that *"does not bind at T32/d16 and does bind at 8B"*
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:286-290`). It also carries the host-only
feed-forward, so it is on a collision course with the speed target (§5.3).

*Route 2: the equality seam, form (E).* Blocks stay separate proofs, and the
crossing value is bound by a masked equality between the two blocks' **own**
attention commitments, with a dedicated seam slot on block *k+1*'s mask
commitment, reserved mask-pair rows on both commitments drawn before either
root exists, and block *k*'s commitment forbidden to finalise before block
*k+1* binds it (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:517-527`, seam S5,
citing `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:100`). This moves the reuse off
the caller-fixed endpoints and onto prover-generated roots, *"where D8's
experiment does not apply"* (`:528-537`).

**What Route 2 still owes.** The same paragraph is careful: it *"does not
discharge D8 for the block's two external endpoints"*, and the joint privacy
analysis for the extra seam groups **has never been done** (recorded as U-2,
`ZK60_OPUS_SEAM_REVIEW.md:639-646`). Form (E) also needs six pieces of
machinery that form (S) needs none of: a seam relation, a second mask
commitment, a second transcript, a reserve-before-commit lifecycle with a role
manifest, a new opening group, and a composed wire frame
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:252-258`). Of those, the
reserve-before-commit lifecycle is recorded as **"absent"** on both sides
today (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:118`, gap G8, citing
`ZK60_OPUS_SEAM_REVIEW.md:531`), and the existing wire format is recorded as
not extensible (U-6).

**The honest statement of the chain problem.** The project has one built form
that composes perfectly and does not scale, and one specified form that scales
and is unbuilt, unanalysed for privacy, and needs the prover lifecycle nobody
has written. Choosing between them is not a coin flip: §2.1(e) names the two
measurements that decide it, and neither can be taken on a loaded box.

### 2.4 Embedding, final norm, head, token selection

A stack of blocks is not a model that answers a question. Between the prompt
and the answer sit four more pieces: looking up each token's embedding vector,
a final normalisation, multiplying by the output head to get a score per
vocabulary word, and choosing the next token.

**The zkVM line has all four, at toy scale.** `private-model-kernel/src/lib.rs`
computes *"embedding gather → block 0 → block 1 → final RMS norm (last row) →
int8 output head → greedy next token"* (`:1-3`), with 19 native tests
including an independent 128-bit reference and model ablations
(`ZK60_MVP_LOOP_20260918.md:132-136`), and its Groth16 receipt exists (G3).
The file's own limits are the honest list of what is still missing: *"context
exactly 32 private token IDs (no padding, no empty prompt, no truncation),
vocabulary 32 … There is no KV cache, no sampling, no EOS convention and no
multi-token decoding here: the output is ONE greedy next-token ID for the full
fixed context"* (`:11-16`), and the embeddings and head are **public**
(`:17-20`).

**The custom line has none of them.** This is task A10 in the ladder, and its
change list is the full specification of the gap
(`zk60_private_block_tasks.json`, task A10): prove the token-ID embedding
gather, the final RMSNorm, the vocabulary projection and quantization, and the
actual emitted-token decision with a fixed tie and sampling policy; bind the
request, the absolute rotary positions, the prior context and the output
disclosures; and prove the key/value cache read and update, the window state
commitment transitions, the causal and sliding-window semantics, and
output/input continuity across windows. Its negative tests are the right ones:
a wrong embedding row, a wrong head weight, a wrong argmax or tie-break, stale
cache state, a wrong position, a reordered window, an altered context — all
must be rejected.

**Two product questions are embedded here and only the owner can answer
them.** A10's external dependencies name the first: *"Explicit product
decision: delayed window/sequence proofs versus proof before token release"*.
The contract records the same open question: *"Victor has not yet answered
whether the eventual generated-token product may use delayed window/sequence
proofs or must verify each token before release"* (`ZK60_EXECUTION.md:78-81`).
The answer changes the shape of the proof, not just its schedule: *"Sixty
prefill rows/s, delayed completed-sequence receipts and each token proved
before release are different products"* (`ZK60_STATUS.md:363-365`). The second
is A10's other dependency: an **approved** complete integer model including
embeddings, head and token-selection semantics — today no such approval record
exists for any model.

**And one construction question that is not asked anywhere yet.** Under P1 the
*output* is hidden. A model that emits a token and hides it is proving "I
computed some token"; the value must reach the authorized owner over a channel
the statement binds. The privacy requirements allow this — *"The authorized
input/output owner can know its own values"*
(`ZK60_PRIVACY_REQUIREMENTS.md:17-18`) — and the zkVM block profile already
does it in practice, keeping the request, salts and plaintext output in a
separate private directory that never enters the public artifact directory
(`ZK60_MVP_LOOP_20260918.md:60-62`). No document states the equivalent
end-to-end delivery relation for the custom line. I raise it as a construction
question for §5, not as a defect.

### 2.5 The public statement and model identity

The product promise is *"a regulator or auditor can check that an **approved
model** produced an answer without learning the prompt or the answer"*
(`ZK60_DECISIONS.md:37-39`). The words "approved model" carry as much weight as
the privacy, and they are a separate obligation with its own state.

**What exists.** The A00 contract pins, for the tiny profile, the approved
weights, gamma, constants, scales and shape, with an explicit authorization
operation whose documentation is unusually blunt: *"Source arguments must be
authenticated independently of any candidate proof. Copying candidate roots
into this constructor does not authenticate a model"*
(`ZK60_BLOCK_CONTRACT.md:16-19`). It has 7 tests, 42 hostile metadata
mutations and boundary preconditions for consecutive layers
(`:91-99`). The stable-weight side has local encrypted material, a durable
opening-slot journal and a registration store keyed only by the commitment
root (`ZK60_STABLE_WEIGHT_REGISTRATION.md:9-21`), explicitly *"not …
authenticate model approval"* (`:5-7`). The custom block binds its calibration
digest into the statement and refuses any endpoint scale pair but the
calibration's `(0, 0)`
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:36`).

**What is missing, in order of severity.**

1. **P3 identity is unconstrained.** Under P3 the feed-forward proof
   re-commits the weights with fresh randomness every proof, so the weight root
   changes every time and the verifier compares it to nothing; the `model=`
   string binds the prover to its *declaration*, not the declaration to the
   weights. *"Two different hidden weight tensors therefore verify under one
   declared model, one statement and one input"* — reproduced at the tiny
   shape with three different randomness sources
   (`ZK60_FABLE_MODEL_IDENTITY.md:20-30`). The repair is specified (a stable,
   independently approved hiding commitment per layer, sized for a public
   opening budget) and not implemented. This is P3, so it does not block P1 —
   but it does block the product.
2. **The zkVM line's statement is awaiting a ruling.** D7: salted SHA-256
   endpoint commitments in a fixed 144-byte journal, weights and calibration
   identified by digests over the bytes the guest uses. *"Pending: Victor's
   acceptance of this profile as the P1 statement for the intermediate, and a
   new approval record for the model digests. Until then the artifact is
   'complete-block experiment', not 'private block'"*
   (`ZK60_DECISIONS.md:216-226`).
3. **Reproducibility of the approved program image.** The guest image ID
   depends on the build directory — the compiled program embeds one absolute
   source path and the non-Docker build applies no path remapping — so the
   approved ID is reproducible only from the main checkout's path or from a
   reproducible container build (`MVP_STATUS.md:204-208`). An approval record
   that names an image ID nobody else can reproduce is not an approval record.
4. **The scale tags still prove nothing in general.** D12 item 5:
   *"Today the tag proves nothing, and the attention fixtures declare
   `(-3, -3)` where the calibration has `e_r = e_r1 = 0`; a tag-equality check
   would pass on a factor-of-8 mismatch"* (`ZK60_DECISIONS.md:314-316`). The
   block module now refuses the wrong pair, but the general rule — compare
   represented values, not tags — is unbuilt
   (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:121`, gap G11).
5. **The calibration digest is a pinned literal rather than a statement
   field**, accepted for the proof of concept and owed once a second
   calibration exists (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:107`).
6. **The endpoint slot-tag namespace has no owner.** Attention uses slot ids
   21/22 and 23/24, the feed-forward 1/2 and 3/4, and the disjointness is
   load-bearing — it is why a feed-forward endpoint cannot be presented to the
   attention prover — but *"Nothing enumerates the assigned slots anywhere"*
   (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:122`, gap G12).

### 2.6 The three largest gaps

Of everything in §2.1–§2.5, three items dominate. They are the ones that would
change the plan if they resolved differently, and they are ranked by how much
other work hangs off them.

**Gap 1 — the block that was built cannot become the block that is fast, and
nobody has measured which way to go.** Form (S) satisfies the composition
ruling with no new privacy machinery and gives up the only measured route to
throughput on the custom line
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:250-292`). Form (E) keeps the GPU
feed-forward prover and is the only form that can stream at 8B, and it is
unbuilt, unanalysed for privacy at its seam groups (U-2), and needs a
reserve-before-commit lifecycle that is recorded as absent. The two
measurements that decide it are named, at the 125M rung, on a quiesced box, and
neither has been taken. **Everything about "many layers" and everything about
speed on the custom line waits behind this one fork.**

**Gap 2 — no private artifact has ever met a real model, and the one class a
real model needs is the one class with an open soundness gap.** The
quantization campaign is finished and measured: real int8/int16 exports of
Mistral-7B and Gemma-4-12B exist and the engine re-derives them bit for bit
(`U_PERF3_QUANTIZATION_MEASUREMENTS.md:172-181`). But Mistral's residual stream
needs int24 (`TASK_BOARD.md:1172-1180`), the int24 residual at width 4096
drives the norm's limb count to 3, and *"any profile with n_limbs >= 3 … and
tn >= 1 accepts an all-zero norm output row"* with a reproduced counterexample
(`ZK60_FABLE_SECURITY_OBLIGATIONS.md:101`). Closing that is a small, bounded
construction job — a range fact on `D`, or a parity fact on `a1 + a2` — and
until it is closed, the first real model cannot be proven soundly at the norm.

**Gap 3 — nothing on the custom line may be called private, and the first step
toward saying so does not exist.** The gate the construction sets for itself
is a zero-witness preimage with the same free dimension as the real witness on
every channel, **on captured real receipts**
(`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`). It has never been run for any
component, because there is no schema-3 capture writer for the attention or
block profiles (gap G6). The tools that would consume such a capture exist and
work; they are pointed at the feed-forward profile only. This gap is the
cheapest of the three to close and is the precondition for every privacy
sentence the project will ever write on its own prover. §3 is about it.

## 3. The privacy-acceptance path

### 3.1 The capture writer (schema 3)

**What a capture is, in plain words.** When a proof is verified, the verifier
sees a long list of numbers: commitment roots, challenge values, sumcheck
round messages, opened columns, authentication paths. A *capture* is a
recording of exactly that list, written to a file in a fixed format, so that
afterwards a separate program can ask the only question that matters for
privacy: **could this same list have been produced by a prover who held no
secret at all?** If yes, on every channel, with the same number of free
choices, then the list carries no information about the secret. That question
cannot be asked of a proof you did not record.

**What exists.** One writer, for the repaired feed-forward profile:
`hashline/src/zk_ffn_io_diagnostic.rs:337` emits
`{"schema":3,"kind":"zk60-verifier-observations", …}` carrying the coverage
and profile strings, the transcript domain, the source commit, the privacy
mode, the shape `{t:32,d:16,f:16}`, the shifts, the field modulus and
extension non-residue, the receipt's SHA-256 and length, the expected policy
and its digest, the layout description and digest, the weight policy, and
`"opening_order":["M","W","A","H","Input","Output"]` followed by the per-role
observation records.

**What consumes it.** `scripts/zk60_io_capture_preflight.py` is the gate: its
own docstring says it *"checks artifact digests, the new schema, claim
geometry, row aliases, transcript joins and public-vector equations"* and
warns that *"CFS/pads/columns are captured, but their privacy and joint
transcript composition remain open"* (`:1-9`). It pins the profile and
coverage strings as constants (`:18-19`), rejects duplicate JSON keys and any
floating-point value outright (`:31-40`), requires exactly 256 sampled columns
with in-range indices and the right width (`:52-60`), and requires each
transcript checkpoint to carry a 32-byte state and its next challenge
(`:48-50`). Downstream sit `scripts/zk60_io_cfs_composition.py`,
`zk60_endpoint_fibre.py`, `zk60_fable_joint_capture.py` and
`zk60_opus_repaired_capture.py`.

**What an attention or block writer must emit.** The gap inventory specifies
it (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:116`, gap G6): *"the per-role
observation record the round-2 joint tools parse: transcript states and next
challenges, claim geometry, group and proximity vectors, 256 sampled columns,
CFS/M openings"*, plus *"the capture-side profile/coverage constants; the
attention-shaped `opening_order` (`M, A, H, Input, Output`, no `W` under P1)
and the six-commitment role list."* Two differences from the feed-forward
writer matter: there is no separate weight commitment under P1 (weights are
public), and the block's commitments are taller and carry more opening groups
— 35 on the `A` side and 9 on the `H` side, against the feed-forward profile's
different shape (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:29-33`).

**Its class and its acceptance check.** The inventory classes it **ENG** with
no dependency on any construction decision, and it is the one build item the
suggested order puts first for exactly that reason
(`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:556`, step 2, and the note at
`:576-579`). The acceptance check is already written there and is the right
one because it can fail: *"`scripts/zk60_io_capture_preflight.py` (or an
attention sibling) parses a capture produced from a real accepted attention
receipt and passes its digest, schema, claim-geometry and transcript-join
checks; and the round-2 joint tools run on it without modification. A capture
from a tampered receipt must be refused."*

**Why it is the hinge.** The block's own disposition puts it third in its owed
list and says where it leads: *"The schema-3 capture writer for this profile,
then the round-2 joint-view tools on real block receipts. **That is where a
privacy statement starts**"*
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:104-105`). The construction
disposition says the same (`:165-167`). Two independent rulings, same
sentence.

### 3.2 The round-2 joint-view tools: what they cover and what they do not

The tools live on branch `zk60-mvp-fable`, worktree
`/home/victor/wt-zk60-mvp-fable`, and are described in
`docs/zkmatrix-poc/ZK60_MVP_JOINT_VIEW.md` there. They are **not** in the main
tree; `scripts/zk60_joint_cfs_view.py` is absent from it, which is one of the
two pre-existing red Python tests the block lane recorded
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:112-114`).

**The five tools** (`ZK60_MVP_JOINT_VIEW.md:55-59`):

* `scripts/zk60_joint_view.py` — the commitment side. It models every group
  vector, terminal, proximity vector and opened column of every role jointly
  as an affine function of the prover's randomness, with data aliasing across
  roles, and restricts each row's freedom by its 256 opened column values. It
  reports the **disclosed dimension** — how many independent facts about the
  hidden data the public view pins down. The expected answer is zero beyond the
  one public identity, and its controls (an ablated endpoint pair row, a pad
  budget below the opened count) must *fail*, i.e. must disclose.
* `scripts/zk60_joint_cfs_view.py` — the masked-sumcheck side: all slots and
  the mask opening together at the captured coefficients, per-slot mask maps
  onto the consistency subspace, and the composed rank with shared rows.
* `scripts/zk60_transcript_replay.py` — re-derives every transcript state and
  challenge of a receipt from public data, so that the challenge history the
  other two tools condition on is *checked*, not assumed.
* `scripts/zk60_root_simulator.py` — the oracle-layer bookkeeping of §3.3.
* `scripts/zk60_mvp_joint_view_gate.py` — the one-command execution record.

**What they would establish if they ran green on a block receipt.** Stated
carefully by the memo itself (`:65`, its §3): at the captured challenge
vectors, the joint law of every field-valued object is witness-independent *in
the independent-uniform-randomness idealisation*; combined with the sequential
kernel lemma (§1.2 of that memo), that gives witness-independence of the whole
transcript for any challenge function, hence for real BLAKE3 — **up to** the
pseudorandomness assumption on the keyed hash stream, the `fp()` reduction
bias of about 2^-75 (ruling D9), the LogUp collision event, and the oracle
programming of §3.3.

**What they do not cover, and this is the part that must never be dropped.**

1. **Only the captured challenge vectors.** *"It does not give: a proof for
   challenge vectors other than the captured ones"* (`:67`). Four captured
   vectors do not establish a universal premise; the independent review says so
   in the same words: *"Four actual captured vectors do not establish its
   universal premise. Replay authenticates schedule and coefficients; it is not
   that distributional argument"* (`ZK60_JOINT_VIEW_REVIEW_20260918.md:67-70`).
2. **The hash layer is excluded from the commitment-side tool.**
   *"`scripts/zk60_joint_view.py:35` excludes hash objects, adaptive dependence
   and CFS messages … A full argument must combine those conditionals with
   roots, paths and the observer's oracle history. Salted-leaf hiding alone
   does not justify deleting those correlated objects from the view"*
   (`ZK60_JOINT_VIEW_REVIEW_20260918.md:71-75`).
3. **The masked-sumcheck tool does not close its own loop.** It defines the
   quantity it then substitutes back, so *"This does not independently check
   the actual FFN terminal polynomial … the source-level link from the
   conditional model to that polynomial is still required"* (`:76-80`).
4. **They model a linear-algebra abstraction, not the protocol.** The block
   disposition lists exactly what that abstraction leaves out: *"the sampled
   columns, the salted Merkle paths, the CFS channel, transcript conditioning,
   integer-range side information and correlation between the two
   commitments"* (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:75-79`).
5. **Soundness is out of scope entirely**, as are side channels, behaviour on
   invalid inputs, and P3 model identity (`ZK60_MVP_JOINT_VIEW.md:67`).

**The disposition of the whole delivery, in one sentence, by the reviewer:**
*"This delivery does not establish the privacy prerequisite for accepting the
custom private block or the model-scale MVP"*
(`ZK60_JOINT_VIEW_REVIEW_20260918.md:100-101`). The tools are the right
instrument and they have never been pointed at the thing that matters.

### 3.3 The open obligation D8 / D11: proved, refuted, and what would close it

**The obligation, in plain words.** The verifier of a custom-line proof is
handed two commitment roots before the proof exists — one standing for the
hidden input, one for the hidden output. It did not make them; the caller did.
To say the proof is zero-knowledge you must show that **someone who knows no
secret at all could have produced an indistinguishable proof for those same
two roots**. That imaginary someone is called a simulator, and producing one
is the standard way to prove a proof reveals nothing. D8 states this as a
standing obligation with the distinguisher allowed to keep prior public
history (`ZK60_DECISIONS.md:230-232`, citing
`ZK60_ENDPOINT_SIMULATION_MODEL.md`).

**What is proved.**

* *The experiments are two, and they are different.* Simulating a proof for an
  **arbitrary existing root** is not the same game as simulating the
  root-generation and the proof **together**. The second allows the simulator
  to issue its own roots and keep its own state; the first does not. Both are
  written out with explicit interfaces `SimPrepare` / `SimProve`, and the
  distinction is standard terminology, cited to Lyubashevsky–Nguyen–Seiler
  Definition 2.8 (`ZK60_ENDPOINT_SIMULATION_MODEL.md:36-66`). *"The general
  external-root obligation remains open rather than being relabelled as
  solved"* (`:86`).
* *Any hash-Merkle commit-and-prove system meets root-only zero knowledge only
  in the programmable random-oracle model* — because an accepting receipt
  reveals a pair of digests hashing to the root, and without programming, a
  simulator that does not hold the honest tree would have to invert a 32-byte
  digest (`ZK60_MVP_JOINT_VIEW.md:22`). That model is already assumed by
  the system's Fiat–Shamir soundness, so this is a legitimate frame, not a
  weakening.
* *The adaptive lift is a correct lemma.* The sequential-kernel lemma — if for
  every fixed challenge vector the **joint** law of all published messages is
  the same for two candidate witnesses, then the whole adaptive view is the
  same for any challenge function — is stated, proved by induction, and
  checked exhaustively on finite toy protocols
  (`ZK60_MVP_JOINT_VIEW.md:36-40`). The independent reviewer agrees: *"The
  sequential-kernel lemma … is valid for the stated causal message rules when
  the complete joint message law is witness-independent under every forced
  challenge vector"* (`ZK60_JOINT_VIEW_REVIEW_20260918.md:53-56`). The earlier
  marginal-law counterexample does not contradict it; it shows why the
  hypothesis must be joint.
* *Two openings of one endpoint commitment recover everything.* Reproduced
  natively at the real seven-row, 256-column geometry: 512 hidden words
  recovered from the two public group vectors and their public coefficients;
  the fresh-owner control does not recover
  (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:3-9`). This is what makes D12
  restrictive rather than cautious.

**What is refuted.**

* *The two-point closure, for any root with prior public history.* The round-2
  memo argued the obligation is met by programming exactly one oracle point per
  root. The review showed that a previously published authentication path
  already reveals the honest top pair — recompute the child on the path and
  take the last sibling — so the programmed second preimage is **detectable**
  with no secret salt and no collision search
  (`ZK60_JOINT_VIEW_REVIEW_20260918.md:8-20`). The claim is retracted for such
  roots, in the register (`ZK60_DECISIONS.md:236-241`) and in the memo itself
  (`ZK60_MVP_JOINT_VIEW.md`, correction note in §1.1). What survives: for a
  root with **no** prior opening the argument is unaffected.
* *The reduction of the obligation to the empty-history case.* D11: *"An
  ordinary authentication path or root-child hash query can exist before the
  sole accepted `finish`; the consuming API does not erase that history"*
  (`ZK60_DECISIONS.md:255-259`). Consuming the owner in Rust is an
  implementation fact; it does not narrow the mathematical statement.
* *The universal per-use rank premise of the proposed budgeted scheme —
  the forced-challenge counterexample.* Here is the shape of it, because the
  brief asks for precision: two uses of the same endpoint each pass their own
  proximity-pair check while **sharing identical mask coefficients**; their
  data coefficients differ by `(1, U)`; subtracting the two proximity vectors
  therefore cancels the masks and reveals both data coordinates. So the
  proposed assertion "for every non-refused challenge, the ranks are
  independent" is **false as written**
  (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:48-54`; regression
  `tests/test_zk60_budgeted_endpoint_boundary.py`). Its scope is stated just
  as carefully: *"This is not an efficient attack on random Fiat–Shamir
  challenges"* — it is an exceptional challenge, exhibited to kill a universal
  claim.
* *One general inference.* *"Neither finitely many rank calculations nor
  counting additional equations establishes the universal independent-rank and
  composition premises of a new budgeted scheme"* (`:45-48`).

**What would close it — the two routes, named, with the experiment each must
win.** I state these and stop; closing them is not this document's job.

*Route A — a stateful simulator in the programmable random-oracle model.*
*"A repaired ROM simulator would need to retain previously exposed tree nodes
and paths, and simulate consistently below their public frontier, jointly with
prior field observations. That is a new stateful construction"*
(`ZK60_JOINT_VIEW_REVIEW_20260918.md:88-90`). The experiment it must win is
the **external-statement, root-only** one of
`ZK60_ENDPOINT_SIMULATION_MODEL.md:37-42`: the simulator gets the real public
policy and model, both roots already fixed by a committer whose data and salts
it never sees, and must produce the whole proof view; the distinguisher keeps
all prior public views, oracle answers and refusal behaviour
(`:74-80`). The repaired argument needs, specifically, either *"a joint-rank
refusal or a justified bound on the bad-challenge event"*
(`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:53-54`).

*Route B — change the statement so the endpoint tree is never opened in
public.* *"Alternatively, prove knowledge of the exact endpoint openings and
the complete computation inside an established general-purpose ZK argument.
The endpoint tree and paths then remain private witness computations"*
(`ZK60_JOINT_VIEW_REVIEW_20260918.md:92-94`). The warning attached is
important and is exactly what the zkVM line did: *"a separately versioned
salted-SHA profile is a new statement format and does not certify the old
protocol"* (`:96-97`; the same point at
`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:59-62`).

**And one restatement task that is neither route and is owed today.** D8's own
text sets it: state the experiment for unopened roots and keep one opening per
commitment — *"that restatement is the security owner's next custom-line task,
not a closed item"* (`ZK60_DECISIONS.md:243-245`). It is small, it is the
security owner's, and until it exists the obligation has no written current
form.

### 3.4 The pending owner rulings D7, D9, D10 and what each blocks

Three rulings are waiting on Victor. None of them blocks implementation today;
each blocks a *claim*, and two of them will block it at the worst moment —
when a result is ready to be announced.

**D7 — the zkVM line's endpoint and identity profile as the P1 statement.**
*"implemented, ruling pending"* (`ZK60_DECISIONS.md:19`). The zkVM route
commits endpoints as salted SHA-256 hashes inside a fixed 144-byte public
journal and identifies weights and calibration by digests over the bytes the
guest actually uses; the old commitment roots have no meaning in it
(`:216-222`). **What it blocks:** the name of the artifact. *"Until then the
artifact is 'complete-block experiment', not 'private block'"* (`:224-226`).
Both existing Groth16 receipts — the block and the two-block token model — are
under this qualifier. It also needs a second thing that is not a ruling but an
act: *"a new approval record for the model digests"*. **What the owner needs
in order to rule:** a one-page description of what the journal binds and what
it deliberately does not, and the reproducibility fact of §2.5 item 3, because
an approval record naming an unreproducible image ID is worthless.

**D9 — the `fp()` reduction bias on the custom line.** Challenge words are
128-bit draws reduced modulo the prime, each within 2^-96 of uniform; over a
proof that accumulates to about 2^-75 at the tiny profile. The choice is to
accept the term inside the privacy bound, or re-freeze the fixtures with
rejection sampling, which changes proof bytes (`ZK60_DECISIONS.md:340-346`).
*"Not gating any current work."* **What it blocks:** the final privacy
statement. The joint-view memo lists it as one of the four residual terms any
privacy conclusion is "up to" (`ZK60_MVP_JOINT_VIEW.md:65`). If the answer
is "re-freeze", it changes bytes and therefore must happen **before** any
artifact is frozen as evidence, not after — which is why it is worth ruling
early even though nothing waits on it.

**D10 — the compact proof-size lever.** Drops a Mistral-7B layer's proof from
38.7 MB to 1.94 MB at 4.4× the prover time and 95–98 bits instead of 106
(`ZK60_DECISIONS.md:348-351`). *"Not compatible with the GPU path or zero
knowledge yet."* **What it blocks:** gate G12, the 256 KB proof-size budget.
Today the custom line is three to four orders of magnitude over that budget at
8B, and this is the only recorded lever against it. Because it costs 4.4× in
prover time, it is in direct tension with the speed target — so this ruling is
one the owner should take **with the speed plan in front of him**, not
separately. It is a soundness-and-size-versus-time trade, and it belongs in
the same conversation as D3's recorded 97-bit deviation, since together they
set how far below 128 bits the whole project sits.

**A fourth item, not a numbered ruling but an owner decision of the same
kind:** the generated-token product question of §2.4 — delayed window or
sequence proofs, versus each token proved before release
(`ZK60_EXECUTION.md:78-81`). It blocks the *shape* of task A10 and therefore
everything downstream of a token. It has been open since at least 2026-09-04.
I recommend it be given a D-number and put in the register alongside the other
three, so it stops being invisible.

### 3.5 The privacy-acceptance path in order

Nobody may say a custom-line proof is private until all six of these exist.
They are ordered by dependency, and the first two have no dependencies at all.

1. **A schema-3 capture writer for the block profile** (and, the same work, for
   the attention profile). ENG. Acceptance: a capture from a real accepted
   receipt passes the preflight's digest, schema, claim-geometry and
   transcript-join checks, and a capture from a tampered receipt is refused
   (§3.1).
2. **The D8 restatement.** CONSTRUCTION, security owner. Write the experiment
   as it now stands — unopened roots, one opening per commitment, prior history
   in scope — so the obligation has a current written form
   (`ZK60_DECISIONS.md:243-245`). Acceptance: a dated entry in the register
   that a reviewer can attack.
3. **The round-2 joint-view tools on real block receipts.** ENG to run, then
   security-owner reading. Acceptance, as the tools' own controls define it:
   disclosed dimension zero on every opening group and both endpoints beyond
   the one public identity, the composed masked-sumcheck rank showing every
   slot's honest rounds unconstrained beyond its two functionals, **and every
   negative control still firing**. A control that stops firing is a stop
   (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:96-103`).
4. **The construction's own gate at block scope.** CONSTRUCTION. On captured
   real receipts, a zero-witness preimage with the same free dimension as the
   real witness **on every channel**, plus the component's zero-witness
   acceptance test (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`). This is
   step 3 plus the channels step 3's model leaves out, and it is where the
   excluded objects of §3.2 have to be confronted rather than noted.
5. **D8/D11 discharged, by Route A or Route B of §3.3**, for the block's two
   external endpoints. CONSTRUCTION, and the hardest item in this document.
   Nothing about removing internal seams touches it: *"Removing the seams
   removes the reuse of intermediates; it does nothing for the caller-fixed-root
   obligation at the block's boundary"*
   (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:147-149`).
6. **The residual terms ruled or removed.** D9's bias term accepted or
   rejection-sampled away (RULING); the pseudorandomness assumption on the
   keyed hash stream and the LogUp collision event written into the final
   statement rather than left in a memo's footnote.

**Two things that are *not* on this path and should not be mistaken for it.**
The leak-checking tools that were run on the real block source — 46 of 46
counts equal to the design, nothing disclosed in any opening group or at
either endpoint, all 22 negative controls firing — are a **static check of a
linear-algebra model of the schedule**, not a check of a receipt
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:35`, with the exclusions at
`:75-79`). And the adversarial code review that found no blocking problem was
a **soundness** review — could a prover construct a false proof the verifier
accepts — not a privacy review (`:56-60`). Both are real work and neither is
step 1.

**One item on this path was closed while I was writing.** D12 item 5's
fixture defect — the attention fixtures declaring scale tags `(-3, -3)`
against a calibration of `(0, 0)` — was corrected by Codex during the
2026-09-19 integration: *"Correct the public synthetic fixture endpoint tags
from `(-3, -3)` to `(0, 0)`, matching the approved calibration (D12)"*
(`ZK60_ATTENTION_INTEGRATION_20260919.md:38-41`). The block API already
enforced it. The general rule of gap G11 — compare represented values, not
tags — is still open.

## 4. The two lines together

### 4.1 Is there a coherent two-line MVP?

**Yes, and it is worth stating deliberately rather than letting it emerge.**

The two lines have complementary holes, and ruling D2 already licenses the
division of labour: *"'Tiny block' claims come from `zkvm-block/`; speed
claims come from hashline. Neither line's results are quoted as the other's"*
(`ZK60_DECISIONS.md:60-62`). The reason they can be held together honestly is
a fact that is easy to miss: **both lines compute the same thing, bit for
bit.** *"The exact-integer kernel (`private-block-kernel/`) is shared by
both"* (`:62-63`), and the custom block's witness was tested equal to that
kernel element for element on 1,200 cases, refusing at the identical site with
the identical message (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:37`).
So the zkVM line is not merely a demonstrator; it is a **differential oracle**
for the custom line, and that is already how the register describes it
(`ZK60_DECISIONS.md:58-59`).

That gives a coherent, defensible MVP shape:

* **The zkVM line owns "it is really private, and here is a token."** It has a
  complete block and a two-block token model, each with a 785-byte receipt
  that verifies in 8 ms, under a privacy argument the project can cite
  (Groth16 zero knowledge, D4) at a security level it has recorded as a
  deviation (D3). Its honest weakness is speed — 3,743 s for one tiny block,
  7,488 s for the token model — and D2 says that is fine because it is not the
  product's prover.
* **The custom line owns "it is fast, and it is the same computation."** It
  has measured public-input/output proofs of real 7B-class feed-forward stacks
  and the only GPU path in the project. Its honest weakness is that no privacy
  property of any of its proofs has been accepted.
* **The bridge is the shared kernel.** Any statement the custom line proves at
  the tiny geometry can be checked against a zkVM proof of the identical
  computation, so a disagreement between the two lines is a bug in one of
  them, detectable without either being trusted.

**What makes it incoherent if stated carelessly.** Three sentences must never
appear: that the 785-byte receipt is a step toward the speed target (it is
not; D2); that the custom line's 0.095 s tiny-block proof is evidence about
8B (it is not; *"a tenth of a second at width 16 says nothing about width
4096"*, `ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:85-86`); and that
either line has demonstrated the product, since both prove synthetic fixtures
of 32 tokens at width 16.

### 4.2 The honest MVP statement for today

> **As of 2026-09-19, the project can prove that a complete transformer block
> — and a two-block model that emits a token — ran exactly as specified, while
> hiding the input, the output and every intermediate value, and a stranger
> can check that proof from 785 bytes in eight milliseconds. That result is
> real and it is verified, but it stands on three qualifications: the model is
> a synthetic fixture of 32 tokens at width 16, roughly 1/256th of the target
> width, with made-up weights; the proof was produced by re-executing the
> computation inside a general-purpose zero-knowledge virtual machine, which
> took an hour for the block and two hours for the token model, and which by
> the project's own ruling can never be the product's prover; and the public
> statement it proves is still awaiting the owner's acceptance as the
> definition of the privacy claim. On the project's own prover — the only one
> that could ever be fast — the same complete private block now proves in a
> tenth of a second and verifies from bytes in forty milliseconds, but no
> privacy property of it has been accepted: the tools that would check what a
> real receipt leaks have never been run on one, because the recorder they
> need does not exist yet, and one cryptographic obligation about the hidden
> input and output commitments is open with a known counterexample against the
> shortcut that was proposed for it. On that same fast prover, proofs of a
> real 7-billion-parameter model's feed-forward layers do exist and are
> measured at 95 seconds on a laptop graphics card — but with nothing hidden,
> and that is 19 times slower than the five-second goal. So: privacy is
> demonstrated but slow and tiny; speed is demonstrated but public and
> partial; and no single artifact yet does both on a real model. The MVP is
> not finished, and the honest distance to it is three named pieces of work —
> a recorder and a privacy verdict on the fast prover, a real calibrated model
> in place of the fixture, and a decision about how blocks chain that the
> project has deliberately not yet taken because the measurement that settles
> it cannot be run on a loaded laptop.**

Every clause above is citable: the receipts and their controls
(`MVP_STATUS.md:13-38`), the zkVM durations (`:26-27`, `:36-37`), D2
(`ZK60_DECISIONS.md:14`), D7 pending (`:19`), the custom block's numbers and
non-acceptance (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:8`,
`:41-52`, `:73-92`), the missing capture writer (`:104-105`), D8/D11 with the
forced-challenge counterexample
(`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:48-54`), and the 8B public-IO
row (`MVP_STATUS.md:97`).

### 4.3 The smallest set of deliveries that would change that paragraph

Four deliveries, in the order they change the most words for the least work.
Each is expanded in §5.2 with owner, dependencies and acceptance check.

1. **The capture writer plus the joint-view run on a real block receipt.**
   This is the only item that can turn *"no privacy property of it has been
   accepted"* into a sentence with a verdict in it — even a negative verdict
   is progress, because a disclosed dimension above zero would be a finding
   that changes the design. It depends on nothing and nobody.
2. **The two form-(S)-versus-form-(E) measurements at the 125M rung on a
   quiesced box.** These delete the last clause of the paragraph — *"a
   decision the project has deliberately not yet taken"* — and unblock every
   chaining and speed decision behind it. They are cheap; they need a quiet
   machine, not new code.
3. **A real calibrated model at the smallest rung the private prover can
   reach.** The exports exist for Mistral-7B and Gemma-4-12B and are verified
   bit for bit against the Rust engine; the frugal-lm 125M checkpoint
   calibrates as-is with zero range-fact violations
   (`LLM_POC_ROADMAP.md:196-201`). Replacing "synthetic fixture with made-up
   weights" with "a real trained checkpoint" is the single largest change to
   how the result reads to an outsider, and the quantization work for it is
   already done.
4. **Victor's three rulings (D7, D9, D10) plus the token-product decision.**
   D7 alone changes *"awaiting the owner's acceptance"* to a name the
   artifacts can carry. None of these needs engineering first; they need one
   page each, which §5.2 schedules.

**What would *not* change the paragraph materially, despite feeling like
progress:** another tamper battery on the tiny block, another rank pass at
fixed challenges (*"A further standalone rank pass cannot close this gate"*,
`ZK60_MVP_REVIEW.md:71-72`), a faster tiny-block proof, or a third receipt of
the same kind at the same geometry.

## 5. The integrated plan

### 5.1 Owner classes and how to read the table

This is one ordered plan, not a menu. Where two deliveries could be done in
either order I have picked one and said why; where a later delivery's *shape*
depends on an earlier one's *result*, the table says so rather than pretending
the dependency is optional.

**Owner classes.**

* **ENG** — engineering against a design that already exists. Codex owns code
  integration, the zkVM line, the demo and tool runners, and the heavy-run
  queue (`ZK60_CODEX_FABLE_COORDINATION.md:8-13`). An ENG item never requires
  a new security argument; if one turns out to be needed, the item stops and
  becomes CON.
* **CON** — a construction decision belonging to the security owner: new
  masks, slots, openings, transcript orders, or a privacy argument. A CON item
  produces a written, attackable statement, not code.
* **RUL** — the project owner's: product, spend, or an accepted deviation.
  Every RUL item goes into `ZK60_DECISIONS.md` the day it is made.
* **MEAS** — a measurement that must be taken on a **quiesced** box. The house
  rule is explicit that timing ladders on a loaded machine are polluted, with
  about 2× run-to-run variance already observed. A MEAS item is cheap in
  effort and expensive in machine-time discipline.

**"Start today?"** means: on the shared 15 GiB laptop with an 8 GiB GPU, with
the box in its current loaded state, without waiting on another person. A
"no" is always explained.

**"Speed path?"** marks the deliveries that also lie on the critical path to
five seconds per proof of the 8B feed-forward blocks. Items marked orthogonal
are still required for the MVP; they simply do not move the clock.

### 5.2 The ordered deliveries

| # | Delivery | Owner | Depends on | Acceptance check (something that can fail) | Start today? | Speed path? |
|---|---|---|---|---|---|---|
| **P0** | **Retire the stale PoC definition.** Correct `LLM_POC_ROADMAP.md:22-23`'s "mode P2 (weights private, inputs public)" to P1 per D1, and restate `ZK60_MVP_20260915.md:12`'s "actual attention/FFN boundary equality" as "the two halves bound by the proof, by equality **or by construction**", since form (S) has no boundary | ENG (docs) | — | A search for `P2` in `LLM_POC_ROADMAP.md` finds only historical references, each labelled superseded by D1; the block gate text no longer contradicts the accepted design | **Yes** | orthogonal |
| **P1** | **Schema-3 capture writer for the block profile** (and the attention profile, same work) | ENG | — | A capture from a real accepted block receipt passes the preflight's digest, schema, claim-geometry and transcript-join checks and the round-2 tools parse it unmodified; **a capture from a tampered receipt is refused** (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:556`) | **Yes** | orthogonal |
| **P2** | **Restate D8 for the current protocol** — the experiment for unopened roots, one opening per commitment, prior history in scope | CON | — | A dated D8 restatement entry in `ZK60_DECISIONS.md` stating the experiment, the adversary's allowed history and the exact unproven step, that an independent reviewer can attack (`ZK60_DECISIONS.md:243-245`) | **Yes** | orthogonal |
| **P3** | **Prepare and take the three pending rulings, plus the token-product decision** — D7 (the zkVM statement as the P1 claim), D9 (the ≈2^-75 bias term), D10 (the proof-size lever), and delayed-window versus proof-before-release | CON prepares, **RUL** decides | P9 for D7's second half (the approval record needs a reproducible image) | Four dated entries in `ZK60_DECISIONS.md`, each with its plain-words consequence and what would reopen it; the zkVM artifacts stop carrying the "experiment, not private block" qualifier | **Yes** (one page each) | D10 only |
| **P4** | **Run the round-2 joint-view tools on real block receipts** and read the verdict | ENG to run, CON to rule | P1 | Disclosed dimension 0 on every opening group and both endpoints beyond the one public identity; composed masked-sumcheck rank leaves every slot's honest rounds unconstrained beyond its two functionals; **every negative control still fires** — a control that stops firing is a stop (`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:96-103`) | **Yes**, after P1 | orthogonal |
| **P5** | **The fork measurement: form (S) against form (E) at the 125M rung** — peak resident bytes of one commitment versus two plus their simultaneous residency; host-only feed-forward wall-clock versus `prove_layer_zk_v3` on the GPU (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:291-302`) | MEAS | a quiesced box | Two numbers with p50/p95 over repeated runs on a named idle machine, and a written verdict "form (S) survives at 8B" or "form (E) is forced". A run on a loaded box **fails** this check by the house rule | **No** — needs a quiet machine; the laptop is shared and the Mac runs a multi-week training job | **Yes** |
| **P6** | **Close the integer-square-root soundness gap for `n_limbs ≥ 3`** — a direct range fact on `D`, or a parity/small-range fact on `a1 + a2` (`ZK60_FABLE_SECURITY_OBLIGATIONS.md:101`) | CON designs, ENG builds | — | The reproduced all-zero-norm-row counterexample (`results/zk60_fable_fa5_isqrt_alias.txt`) is **rejected by the verifier** under the repaired relation, at the int24-residual/width-4096 parameters, and the tiny profile's proof bytes are unchanged or the change is a declared new profile | **Yes** (design and a tiny-profile build) | orthogonal, but blocks P8 |
| **P7** | **Reproducible build of the approved guest image** — remove the absolute-source-path dependence, or produce the image from a container build (`MVP_STATUS.md:204-208`) | ENG | — | Two builds from different directories produce the same image ID; the approval record names an ID a third party can reproduce | **Yes** | orthogonal |
| **P8** | **Complete the private line's integer specification to the widened stack at real-model classes** — the int24 residual class with its two 16-bit limbs, the clamp-at-z selector relation, per-tensor (not per-kernel) exponents, and the calibration digest as a statement field | CON for the classes, ENG for the planes | P6 | The private prover accepts a witness exported from the real Mistral-7B v3 export at one layer and refuses the same witness with one plane perturbed; the C4 qualification verdict JSON is carried with the artifact (`QUANTIZATION_CONTRACT_DESIGN.md:86-99`) | **Yes** (design; the exports already exist) | orthogonal |
| **P9** | **Generalize the block module's geometry** — the distinct `Dom::F` variant (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:744-754`), parametric T/d/f, and a decision on one U8 table versus the declared table set at width ≫ 16 | ENG for the parametrization, **CON** for the table choice | P5's verdict (it decides whether this is built inside form (S) or form (E)) | The module proves and verifies at the 125M rung shape (768→2048) with the witness equal to the reference kernel element for element, and `L_s + 256 ≤ 512` still holds on every slot at the larger logs | after P5 | **Yes** |
| **P10** | **The block-scope privacy gate** — on captured real receipts, a zero-witness preimage with the same free dimension as the real witness **on every channel**, plus the zero-witness acceptance test (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`) | CON | P1, P4 | The preimage exists on every channel including the ones §3.2 lists as excluded today, or the gate reports which channel it fails on. Either outcome is a result; silence is not | after P4 | orthogonal |
| **P11** | **Discharge D8/D11 for the block's two external endpoints** — Route A (a stateful ROM simulator retaining exposed nodes and paths, with a joint-rank refusal or a bounded bad-challenge event) or Route B (move the endpoint openings inside the argument) | CON | P2, P10 | A written reduction, independently reviewed, that survives the prior-path distinguisher of `ZK60_JOINT_VIEW_REVIEW_20260918.md:8-20` and the forced-challenge counterexample of `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:48-54` | design can start today | orthogonal |
| **P12** | **Form (E) machinery, if P5 forces it** — the seam relation, second mask commitment, composed transcript order, reserve-before-commit lifecycle with a role manifest (recorded as **absent** today, gap G8), a new opening group, and an extensible composed wire frame | CON for the role list and transcript order, ENG for the rest | P5, P9 | `finalize` refuses when a declared role is never consumed **and** when one is consumed twice; a late mask insertion after the commitment is a typed refusal or a compile error, never a silent success (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:561`) | after P5 | **Yes** |
| **P13** | **A private two-block chain on the custom line** | ENG against P12's design | P12 (or P9 under form (S)) | The headline negative test first: build honestly, rebuild the second block on a different hidden input, and require **the verifier** to reject — not a prover assertion; then the positive case verifies from bytes in a fresh process (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:562`) | after P12 | **Yes** |
| **P14** | **A real calibrated model at the first private rung** — the frugal-lm 125M checkpoint, which calibrates as-is with zero held-out range-fact violations (`LLM_POC_ROADMAP.md:196-201`), proven privately at one block and then at the layer count | ENG | P8, P9, P13 | The proof is for a checkpoint whose digest matches a published trained model; the C4 gate verdict is green; a one-bit change to the checkpoint makes the proof refuse | after P9 | **Yes** (coverage half) |
| **P15** | **Embedding, final norm, head, token selection and state on the custom line** (task A10) | CON for the generation relation, ENG to build | P13, P3's token-product decision | A tiny autoregressive reference emits identical tokens; consecutive windows verify with bound state and stated proof lag; a wrong embedding row, head weight, argmax tie-break, stale cache entry, wrong position or reordered window each reject (`zk60_private_block_tasks.json`, A10) | after P13 | coverage |
| **P16** | **P3 model identity** — a stable, independently approved hiding commitment per layer, sized for a public opening budget, that the proof opens directly (`ZK60_FABLE_MODEL_IDENTITY.md:20-30`) | CON, then ENG | P14 | Two different hidden weight tensors under the same declared model **no longer both verify**; the reproduction at the tiny shape flips from accept to reject | after P14 | orthogonal |
| **P17** | **Activate the adversarial campaign** by ruling, per its own trigger: once the 8B feed-forward PoC proof has run end to end (`ADVERSARIAL_TESTING_PLAN.md:1-8`) | RUL to activate, ENG to run | P14 | Every attack surface in that plan has a green battery, a documented accepted-risk row, or a fix — *"no silent categories"* (`:76-77`) | no | orthogonal |

**Why this order and not another.** P0–P3 come first because they cost hours,
unblock other people, and remove the two ways this project can currently
mislead itself (a stale P2 definition, and artifacts whose name outruns their
ruling). P1 is the first build item because the gap inventory identified it as
*"the one item with no dependency"* and because every later privacy check
consumes its output (`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:556`, `:567-571`).
P5 is placed as early as machine availability allows because **nine of the
remaining twelve deliveries change shape depending on its answer** — it is the
cheapest decision-unblocking measurement in the project. P6 precedes P8
because there is no point exporting a real model into a relation with a known
accepted counterexample. P10 and P11 are last among the privacy items not
because they are least important but because they are the only ones that
cannot be attempted before their inputs exist.

### 5.3 Where this plan meets the speed plan

A separate analyst is writing `ZK60_FIVE_SECOND_PLAN.md`; at the time of
writing it is a draft skeleton with its sections still to be filled. I have
not duplicated any of it. There are four points where the two plans touch, and
one of them is a genuine conflict that must be resolved by a decision rather
than by both plans quietly assuming their own answer.

**Meeting point 1 — the conflict. The private block as built gives up the GPU
feed-forward prover.** Form (S) was chosen because it satisfies the
composition ruling with no new privacy machinery, and it carries T1's
decision 13: the feed-forward is re-derived on the host
(`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:45-47`). The block-decomposed
CUDA path is *"the custom line's only measured route to throughput, and form
(S) does not inherit it"* (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:282-289`). So
**the privacy plan's built artifact and the speed plan's only measured lever
are, today, incompatible.** This is not a mistake: the memo defers form (E)
explicitly, *"with its cost written down here so it can be picked up without
re-deriving"*, and names the two measurements that force it. But no status
page should describe the tiny private block as progress toward five seconds,
and no speed plan should assume the GPU feed-forward path is available in a
private profile. **Delivery P5 is the decision point for both plans, and it
belongs to whichever plan gets the quiesced box first.**

**Meeting point 2 — streaming and memory at 8B.** Form (E) is also what a
streamed multi-block proof needs if one block's commitments cannot be resident
at once, *"a constraint that does not bind at T32/d16 and does bind at 8B"*
(`:286-290`), against a 72 GB counted peak for the 8B pass in the cheaper mode
(`START_HERE.md:253-256`) and an 8 GiB card. Whatever the speed plan proposes
about residency, preprocessing or two-tier openings has to be compatible with
one opening per commitment (D12 clause 1) — the constraint that is *why* the
privacy line cannot simply reuse commitments to save memory.

**Meeting point 3 — proof size and the D10 ruling.** Gate G12 (256 KB) and the
speed target pull in opposite directions through the same lever: D10 buys a
20× size reduction at 4.4× prover time and 95–98 bits instead of 106
(`ZK60_DECISIONS.md:348-351`). Neither plan should take that ruling alone.

**Meeting point 4 — coverage, which is the speed target's hidden dependency.**
The contract's clock is meaningful *"only with the required model/operation
coverage and reviewed privacy/soundness; proving 512 exported FFN rows alone
does not establish it"* (`ZK60_STATUS.md:352-355`). Every private-line
delivery from P8 to P14 is therefore also a speed-target delivery, in the
sense that without them a fast number is a number for the wrong computation.
The speed plan owns the seconds; this plan owns what the seconds have to be
seconds *of*.

## 6. The first three lanes that can start today

Three lanes, independent of each other, each starting without waiting on any
person, ruling or measurement. Each is scoped the way this project scopes
lanes: a sibling worktree on its own branch, a declared set of files it owns,
an explicit statement of what it must leave untouched, and one acceptance
check that can fail.

**A standing constraint for all three.** Codex is working live and
uncommitted in the main tree: as of this writing `git status --short` shows
`hashline/src/lib.rs`, `hashline/Cargo.toml`, `hashline/src/tables_attn.rs`
and the whole `hashline/src/private_block/`, `hashline/src/private_attention/`
and `scripts/zk60_*` integration set as modified or untracked there. **No lane
below edits any file in that set.** Where a lane genuinely needs one line in a
shared file (a module export in `lib.rs`), it writes the line in its own
worktree and hands the request to Codex rather than taking the file.

---

### Lane A — the block capture writer (delivery P1; gate G6)

**Why first.** It is the only privacy item with no dependency on any decision
or measurement, and two independent dispositions say the same thing about it:
*"the schema-3 capture writer for this profile, then the round-2 joint-view
tools on real block receipts. That is where a privacy statement starts"*
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:104-105`;
`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md:165-167`).

**Files it owns (all new).** `hashline/src/private_block_capture.rs` — a
separate diagnostic module modelled on `hashline/src/zk_ffn_io_diagnostic.rs`,
which is the working precedent for a schema-3 writer that lives outside the
prover; `hashline/tests/zk60_block_capture.rs`;
`scripts/zk60_block_capture_preflight.py` (or an argument to the existing
preflight, decided in the lane and written down);
`tests/test_zk60_block_capture_preflight.py`;
`results/zk60_block_capture_evidence/`. One module-export line in
`hashline/src/lib.rs` is **requested from Codex, not taken**.

**What protects the accepted artifacts.** The same discipline the block lane
itself used and recorded: at every stage, `hashline/src/private_block/*`,
`hashline/src/private_attention/*`, `zk.rs`, `layer.rs`,
`zk_ffn_fresh_io.rs` and `private_seam.rs` must be **byte-identical** to
`zk60-attention-compile`
(`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:41-44`), and a receipt
produced **before** the lane's work must still verify under the binary built
**after** it — the exact check that proved the last round of fixes changed no
protocol behaviour (`:50-52`). A writer that changes a transcript byte is a
new profile and invalidates the accepted receipt; that is the failure mode to
guard against.

**Acceptance check.** A capture produced from a real accepted block receipt
passes the preflight's digest, schema, claim-geometry, row-alias, transcript-
join and public-vector checks; the round-2 joint tools parse it **unmodified**;
and a capture produced from a tampered receipt is **refused**
(`ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md:556`). All three legs must hold; the
refusal leg is the one that can silently not work.

**Box cost.** One release build of `hashline` plus one tiny proof (0.095 s).
Takes the shared build lock; nothing heavy.

---

### Lane B — the obligations-and-rulings writing lane (deliveries P2, P3, P0)

**Why now.** It costs machine-time nothing, it is the only lane that unblocks
*Victor*, and one of its three items — the D8 restatement — is named in the
register as *"the security owner's next custom-line task"*
(`ZK60_DECISIONS.md:243-245`) and has been outstanding since 2026-09-18.

**Files it owns (all new except the register).**
`docs/zkmatrix-poc/ZK60_ENDPOINT_OBLIGATION_RESTATEMENT.md` — D8 as it now
stands, with the experiment, the adversary's allowed prior history, the
forced-challenge counterexample stated as a constraint on any repair, and the
exact unproven step; `docs/zkmatrix-poc/ZK60_PENDING_RULINGS_BRIEF.md` — one
page each for D7, D9, D10 and the token-product question, each written for a
reader who is not reading the code, each ending in the two or three options
and what each costs; the corrections of P0 in `LLM_POC_ROADMAP.md` and
`ZK60_MVP_20260915.md`; and the resulting entries in `ZK60_DECISIONS.md`.

**What protects the accepted artifacts.** Nothing in this lane touches code,
so the risk is different in kind: it is that a restatement quietly **narrows**
an obligation. The guard is the register's own rule — *"Entries are never
deleted; a reversed decision gets a new entry that points back"*
(`ZK60_DECISIONS.md:6-7`) — plus the standing prohibition that an unresolved
argument *"is not permission to shrink the private set"*
(`ZK60_PRIVACY_REQUIREMENTS.md:29-30`). The restatement must be **narrower in
what it claims** and not narrower in what it owes.

**Acceptance check.** An independent reviewer, given only the restatement,
can name the experiment, the adversary's powers and the unproven step, and can
say whether the prior-path distinguisher
(`ZK60_JOINT_VIEW_REVIEW_20260918.md:8-20`) still applies to it. If the
reviewer cannot, the restatement failed. For the ruling briefs: Victor can
answer each one without asking a follow-up question.

**Box cost.** None.

---

### Lane C — the norm-limb soundness gap (delivery P6; blocks the real model)

**Why now.** It is the one defect standing between the finished quantization
work and the first real model, it has a **reproduced counterexample already in
the repository**, and its fix candidates are already named: *"a direct range
fact on D (U16 lookup at this profile; U16+U8 limbs generally) or a
parity/small-range fact on a1+a2. Until then the fixed profile's exactness
rests on the (tn, n_limbs) coincidence derived here, which no source comment
or test records"* (`ZK60_FABLE_SECURITY_OBLIGATIONS.md:101`).

**Files it owns (all new).**
`docs/zkmatrix-poc/ZK60_NORM_LIMB_SOUNDNESS.md` — the restated alias, the
admission condition (`tn ≤ 16n − 31`, with `n = 2` giving `tn ≤ 1` and `n = 3`
giving `tn ≤ 17`, i.e. all of the A00 band, `:459`), the two fix candidates
with their table and commitment costs, and a recommendation;
`hashline/tests/zk60_norm_limb_alias.rs` — a test that *reproduces the
acceptance* at the int24/width-4096 parameters and is expected to flip to
rejection once the fix lands; `results/zk60_norm_limb_evidence/`.

**What protects the accepted artifacts.** The lane writes **no** change to any
prover or verifier: it produces a design and a failing test. The repair itself
is a later ENG delivery, and it must be a declared new profile if it changes
proof bytes, per the standing freeze discipline (*"Transcript-changing work is
a NEW protocol version"*, `QUANTIZATION_CONTRACT_DESIGN.md:44-45`). The
existing frozen proof artifacts and the block's 2,816,472-byte receipt must be
unchanged at the end of the lane, trivially, because nothing they depend on is
edited.

**Acceptance check.** The new test **accepts** the all-zero norm output row
today at `n_limbs = 3, tn ≥ 1` — i.e. it reproduces the gap rather than
describing it — and the memo states, for each fix candidate, the exact
additional lookup or plane and whether it changes proof bytes at the tiny
profile. A memo without a running reproduction fails this check; the point of
the lane is to make the gap executable before anyone designs around it.

**Box cost.** One release build plus a unit test. No proof, no GPU.

---

**A fourth candidate, held back only to keep the list at three:** the
reproducible guest-image build (P7). It is small, Codex-owned, independent,
and it is a precondition for the D7 approval record. If a fourth lane is
available, take it.

## 7. What I did not read, and what I could not find

**What I did not read (and where a conclusion might therefore be thin).**

* The Rust of the private block and private attention modules themselves, in
  any depth. I read the two dispositions, the construction memo's sections B,
  C.3–C.5 and the composition gap inventory, and the kernel
  (`private-block-kernel/src/lib.rs`) for the calibration, class constants,
  requantization mode and activation-table type. I did not read
  `private_block/argument.rs`, `layout.rs` or `protocol.rs`. Everything I say
  about what the proof pins is quoted from the reviews, not verified by me.
* The four long construction documents in full: `ZK60_PRIVATE_BLOCK_CONSTRUCTION.md`
  (1,600 lines), its check, the Tier-2 memo and its check, and the 58 KB code
  review — about 4,600 lines together. I read their dispositions, their errata
  summaries and the sections the brief named.
* `ZK60_FABLE_SECURITY_OBLIGATIONS.md` in full (85 KB). I searched it for the
  norm-limb and deployment-soundness findings and quoted three lines. There
  may be other open obligations in it that belong in §1.3's checklist.
* The round 7–25 records, the `U_PERF*` performance reports, the aggregation
  design corpus, and `TASK_BOARD.md` beyond the int24 passage. The speed plan
  covers that ground.
* `ZK60_MVP_JOINT_VIEW.md` beyond its first 80 lines, and none of the
  joint-view tools' source. My description of what they compute is from the
  memo and the independent review, not from reading
  `scripts/zk60_joint_view.py`.
* Any results file. No evidence JSON, log or receipt was opened.

**What I could not find.**

* **No single page states the MVP as one definition with one privacy mode, one
  model scale and one coverage boundary.** Seven documents each state part of
  it and two of them contradict each other (§1.2). This document's §1.3 is my
  reconstruction, not a quotation.
* **No document states the P1 output-delivery relation for the custom line** —
  how a hidden output reaches its authorized owner in a way the statement
  binds. The privacy requirements permit it and the zkVM host implements a
  version of it operationally, but no construction exists (§2.4).
* **No estimate anywhere of what the private block costs at 125M or 8B.** The
  construction memo derives the receipt size at T32 from the wire format
  exactly, and stops. There is no counted projection of rows, lookups or
  receipt bytes at a larger width on the private line — which is why P5 and P9
  are decisions rather than calculations.
* **The token-product question (delayed windows versus proof before release)
  has no D-number**, so it does not appear in the register's "at a glance"
  table and is invisible to anyone reading only that table. §3.4 recommends
  giving it one.
* **`scripts/zk60_joint_cfs_view.py` is not in the main tree**, only on
  `zk60-mvp-fable`; this is one of the two pre-existing red Python tests the
  block lane recorded (`ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:112-114`).
  I could not determine whether the plan is to merge it or to keep the tools
  on their lane.
* **I could not reconcile two figures for the best public-IO 8B feed-forward
  prove time**: `MVP_STATUS.md:97` says 95 s (lane AH), while
  `ZK60_FIVE_SECOND_PLAN.md:50` refers to lane AL at **58.40 s** as "the
  current best" and `ZK60_EXECUTION.md:107` cites `results/hashline_convert_gpu.md`
  at 58.40 s prove for an FFN P0 pass with host allocation optimization
  already included. These may be different profiles or different
  measurement boundaries. **The speed plan owns this; I have not used either
  number for anything except the order-of-magnitude statement in §4.2, which
  holds at both.**
* **The status of the ceremony check.** `MVP_STATUS.md:203` records that it
  never ran (killed by the 01:04 restart) and that Codex was relaunching it;
  `ZK60_CEREMONY_CHECK_REVIEW.md` exists but is one of Codex's live untracked
  files, which I did not open. D4's "run RISC Zero's published ceremony
  verification once and record the outcome here" is therefore still
  outstanding as far as the register shows
  (`ZK60_DECISIONS.md:163-166`).

---

*(draft complete)*
