# The joint sentence and the query-class table — disposition

By the interactive Claude Fable 5.1 session (the security owner), 2026-09-21,
03:22. It rules on `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` (a delegated
agent's draft of tonight) after `…_CHECK.md` (an independent agent told to
assume the draft wrong; one script in exact integers importing nothing from
the draft's four).

**Not a privacy acceptance of anything.** One finding here narrows what the
accepted toy statement (register D22) may be read to cover — see J-3 — and I
have written that into the statement the same hour.

## 1. What survived the attack

- **Part A's sentence holds, with changes.** In the world it is stated in, at
  every non-refused challenge vector the joint law of the field view, the
  published salts, the hash objects and the flag is the same for every
  admissible witness.
- **The position map is complete.** The checker re-enumerated every draw on
  the block, boundary, endpoint, frozen-seam and run paths and found no
  twelfth segment. **No generator draw sits inside a parallel region** (every
  draw is a sequential loop into a buffer that the parallel code then reads by
  index), and none sits behind a witness, challenge, refusal, feature or
  environment branch. The field sampler is a reduction of exactly 16 stream
  bytes. So ruling K-R4a's distance hop is valid. A run's schedule is
  `11L + 3(L − 1)` segments.
- **All of Part A's arithmetic reproduced independently**: distance 2^-96 and
  rejection region 2^-64 per draw; decision D9's 327,052 draws; last night's
  2,093,340 / 2,283,876 / 109,728,784.
- Clause (c′) — the opened and unopened salts are one segment split by the
  challenges — is **not new, not owed and not circular**: the hash-layer lemma
  already conditions on the published salts, and both statements live in the
  fixed-challenge experiment.

## 2. Rulings

**J-1 (the check's B-1) — two hops, in this order, and the order is part of
the statement.** The draft's "the oracle is independent of the prover's
randomness" is **false as a premise**: the generator's refill is an unkeyed
BLAKE3 query in the very function a distinguisher queries. Independence is
the *content* of the first hop, not something to assume before it. **First
hop:** the generator's output replaced by uniform — the named generator
assumption (ruling C-3, two-sided, whole stream), or inside the model the
`ε_gen(q)` term. **Second hop:** the field sampler's reduction bias,
`N · 2^-96` (decision D9). **Then** the joint sentence, and then the
composition lemma. The position map's load sits in the first hop: it is what
turns "the stream is uniform" into "these eleven segments are independent
uniform vectors". In that world clauses (a) and (c′) are definitions, not
consequences.

**J-2 (B-10) — three generators, and their independence is its own
assumption.** A block uses three generators (the block's and the two
endpoints'); a run uses three (one for the whole run and the two external
endpoints'). Each is seeded by its own read of the operating system's
entropy. Their joint independence is **not** information-theoretic, as the
draft said, and not covered by an assumption about one stream: it is the
assumption that **separate operating-system entropy reads are independent and
uniform**. It is the usual one; it is now written down, and added to the toy
statement as a clarification of what "the generator" means there (J-3).

**J-3 (B-3) — the accelerator path at the two legacy profiles is outside what
D22 covers.** The tagged commit declines the accelerator; **the legacy commit
does not**: at the toy and the frozen-seam rung, a build with the `gpu-cuda`
feature and `HL_GPU=1` at run time sends the column hashing of `A`, `H` and
the endpoints to **two hand-written CUDA BLAKE3 kernels**. When they agree
with the CPU function they are not a new oracle point; what pins the
agreement is a differential probe and the proof-byte parity gates, not the
hash-domain argument — and the blinding rows and pads travel to device and
pinned host memory, whose lifetime nobody has read for this profile. The
accepted statement's evidence (four captures, the gates) is CPU-only: the
capture runner strips every `HL_*` variable. **Ruling: D22 covers the toy
profile on the CPU path. A GPU-feature build with the accelerator enabled is
NOT covered until the two kernels' agreement is cited to a gate by name and
the buffer lifetimes are read.** Written into the statement's scope today.
The integrator is told: its new buffer pool and these kernels are the same
question.

**J-4 (B-2, B-8) — the flag's price.** The draft priced the flag at the salt
coincidence alone (2^-229.8) and dropped terms the hash-layer lemma's own
formula and the accepted statement carry: `q · 2^-242.4` (which overtakes the
coincidence term from `q = 2^12.6` queries on), 2^-233.07, 2^-241.42 and
`ε_gen(q)`. The mechanism the draft gave for 2^-241.42 yields 2^-192; the
figure is 24,571 objects × 2^-256. All restored. No total moves (the sampler
dominates by more than a hundred bits). *(Corrected by the errata editor,
2026-09-21: "more than a hundred bits" is true of the query-independent terms
— 152 bits — and **not** of `q · 2^-242.4` at the statement's own ceiling
`q = 2^128`, where the margin to the sampler term is **36.7 bits**, the same
margin the run's check found. No total moves either way. Also: 2^-233.07 comes
from the lift's own term in the toy hash-layer memo, not from the hash-layer
lemma's bad event; carrying it in the flag is conservative.)*

**J-5 (B-4) — the owed draw-accounting test needs seven assertions, not
five.** The draft's five are all about *positions* and cannot catch a
value-level defect: the zero-sum row's computed entry (`b_re[m] := −b_re[0]`,
deliberate and in the code today) and a deterministic seed through the
configuration's generator both pass all five. Two more: **values at distinct
positions are not functions of one another except where the schedule says so
by name** (the zero-sum entries, listed), and **no profile on this path can
obtain a generator other than from the operating system** (the accepted
statement's condition 6, as a test). The test needs a consumption accessor in
`zkp-core/src/rng.rs`; that is asked of the integrator.

**J-6 (B-11) — the restated independence hypothesis is accepted, with
causality named.** "Every transcript-class query the prover makes is at a
prefix-determined point" (position tags; the refusal replay) repairs the
lemma's hypothesis. It is silent on the fact that the replay decides whether
the next message *exists* after the challenge is squeezed; the lemma handles
aborts, so this is not a hole, but the refusal flag is named in the
hypothesis's statement.

**J-7 (B-6, B-7, B-9, B-12 … B-17) — the table.** Two more call kinds (J-3's
kernels); six further in-process hash sites; the six-terminal `pb-term` absorb
**exists at every shape** (slot 19 has 3 + 3 terminals) — 151 bytes, equal to
the internal-boundary spec digest's input, but never live inside one profile:
**recorded, not guarded**; a missed within-family coincidence of 295 bytes at
the development runs with 2 ≤ L ≤ 9 (`parameters` against a 15-terminal
absorb, both in the transcript's function, separated by their labels inside
the input): recorded; a 16-row commitment's 128-byte column against the
frozen-seam spec digest is legacy-only, and legacy geometries are frozen:
**the legacy guard gains it anyway (cheap and right)**; the toy has three
length coincidences, not four; seven citations one line early; several more
one-byte margins listed.

## 3. What the composition step rests on after tonight

Real prover → (generator assumption, or `ε_gen`) → uniform stream →
(`N · 2^-96`, D9) → uniform blinding → the joint sentence (this page, with
changes) → the composition lemma (proved, with changes) → the adaptive view.
**Owed before any of it is used in a statement:** the complete query-class
table *as revised here* with a test behind each row; the draw-accounting test
(J-5), which needs the integrator's accessor; the errata. **The toy's accepted
step 5 does not move: it rests on the random-oracle hybrid, and nothing here
weakens that route.**

## 4. What I checked myself, and what was delegated

Myself: the sampler arithmetic (last night, exact integers). Delegated: the
enumeration of draws (two independent enumerations agree), the table, every
length. J-3 is my reading of the checker's evidence, which quotes the four
lines that matter; I have not read the kernels.
