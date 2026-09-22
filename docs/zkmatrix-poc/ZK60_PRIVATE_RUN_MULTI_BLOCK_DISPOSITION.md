# Disposition of the multi-block private run — security owner, 2026-09-20

Written by the interactive Claude Fable 5.1 session (the security owner) at
09:46 on 2026-09-20. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| R | `ZK60_PRIVATE_RUN_MULTI_BLOCK.md` | a paper design for a private RUN of L transformer blocks (12 at the 125M shape) under one transcript, block k's hidden output being block k+1's hidden input |
| R-check | `ZK60_PRIVATE_RUN_MULTI_BLOCK_CHECK.md` | an independent adversarial check against the real code (`results/zk60_private_run_multi_block_check/`): 4 blocking items (B1 … B4), 13 corrections, 11 omitted conditions |

| Verdict | **Accepted as the design to build, subject to the four blocking items and the rulings of §2.** The checker, told to assume it wrong, attacked the boundary construction hardest and it held; it also tried to break the rejected alternative's memory claim and could not. **Nothing here is a privacy acceptance and nothing has been built or run.** |
|---|---|

## 1. What survived the attack

- **One boundary commitment per internal boundary, two claim sites, opened
  once — and the real code can do it without touching a forbidden file.**
  `open_zk` borrows the commitment and a list of claims and the verifier
  re-forms the groups itself; the block's claim accumulators cross a stage
  boundary as plain data, pushed outside the prove/verify branch, so **the
  verifier computes the pending claim itself and never reads it from a
  segment.** The prover's per-role arrays have exactly four places and this
  option uses exactly four; the rejected option would need five.
- **The boundary's hiding, in an exact small model of the checker's own:**
  honest geometry — rank 6 of 6 on the reserved rows, disclosed 0; two claims
  sharing one pair — disclosed 2, the control fires 40 of 40.
- **No challenge precedes what it must bind**; the stage order was checked
  line by line against `prove_inner_at`.
- **The memory carry-over is exact to the byte** (88.2 MiB at the first
  stage; *corrected 2026-09-20 14:56: an interior stage carries 88.8 MiB — two
  boundaries and the output endpoint — as the revised design's §3 says; the
  0.6 MiB does not change any conclusion, the measured peak being 10.15 GiB
  inside a 12 GB ceiling*), the time
  recomputes to 6.26 minutes of proving and 12.5 s of verifying for twelve
  blocks, every receipt byte reproduces, and the draw count and residual
  (109.4 million draws, 2^-69.3 for one twelve-block run) are confirmed.
- **The same hidden plane under three commitments** (block k's activation
  commitment, the boundary, block k+1's) is the two-commitment argument
  applied once more, not a new one — but the gate must rank all three roles.
- The rejected alternative really is a near-tie on memory (its kept matrix is
  3.5 GiB, and the seam can be placed early); it loses on the four-place
  arrays and on needing a re-cut slot schedule.

## 2. Rulings

**M-1 (B4): the boundary's row count is DERIVED, never accepted.** The
checker's model found that a boundary with a *single* proximity row — 37 rows
instead of 38 — has rank 5 and **discloses 1, and that `audit_claims` accepts
that geometry.** So `rows = data + 2·sites + 2` is a hiding requirement the
audit does not enforce. The boundary module computes its geometry from the
plane and the number of claim sites and refuses any other; a test builds the
37-row geometry and shows it refused by name; and the gate ranks the boundary
**restricted to its reserved rows** (over all rows every case looks like full
rank). Today's single-claim endpoints are unaffected: their five non-data rows
already are a pair, a proximity pair and a spare — and the draft's description
of them as "a further random row" is corrected.

**M-2 (B1): the run's soundness is stated wherever the run is described:
about 2^-97.5 for twelve blocks at this geometry** (twelve blocks at 2^-101.1
and eleven boundary openings at 2^-105.6, by the project's own accounting).
That is the level Victor accepted for the zkVM line in D3; **whether it is
acceptable for a native-line run is his ruling, not mine**, and it goes to him
with decision D15's open question. It does not block building.

**M-3 (B2): segments are flushed.** Each block's segment is written out and
dropped before the next block is committed; holding twelve of them adds 423
MiB and was missing from the model. With the twelve statements' weights the
modelled peak is **10.74 GiB**. The first measured multi-block runs record the
high-water mark per stage: a rising mark across blocks is the sign of
allocator fragmentation and stops the ladder.

**M-4 (B3): calibration is bound at every boundary.** D12's fifth item ties
the scales of the two external endpoints to the calibration; a run multiplies
the places where a scale is declared from 2 to 13. **A boundary's scale is ONE
field, shared by construction between block k's output and block k+1's input,
and the run header absorbs one calibration identity covering all of them.**
Test: a run whose block k+1 declares a different input scale than block k's
output scale does not construct, and a receipt made under one calibration
identity is rejected under another.

**M-5 (D12a): the amendment is recorded in the register today**, with the
check's corrections: all five items of D12 carried over (the fourth — the
int8 range proof on the second norm — is in fact satisfied at both ends of
every boundary, and says so); "joining finished runs needs D18's option B
**and** D8/D11 discharged"; a boundary commitment fixed by anyone but the
prover stays forbidden.

**M-6 (the receipt).** The segment framing is one format, counted once: the
draft counted 40 bytes of framing and specified 136; the byte-exact acceptance
test uses the specified figure. The header's transcript state is **re-derived
by the verifier and compared, never absorbed and never adopted.** A verifier
checks exactly L segments, L being its own; one that stops early knows nothing.
**A receipt of about 484 MB is a product fact for Victor** (the contract's
proof-size budget is 256 KB, and the one lever that shrinks it cannot run
privately — decision D10); it goes on his page as a recorded deviation, not as
a blocker.

**M-7 (the moving sites).** "No forbidden file is needed" is confirmed, but
seven permitted sites move and were unlisted — among them a mask-row constant
**inside a digest** and a constructor that today refuses the draft's 36-row
external endpoint by name. **The run's external endpoints keep today's
geometry unchanged** (37 rows at the 125M shape); only internal boundaries use
the new two-site geometry. That removes the digest change and the refusal
from the build.

**M-8 (the gate).** Three blocks at the development rung, all three roles of
each boundary plane ranked jointly, the shared-pair and single-proximity-row
controls included; capture by a NEW run-capture module, never by editing the
integrator's capture writer. No privacy statement about any run before it.

## 2a. Built and measured (10:48, 2026-09-20), and rulings on the build's findings

**The run exists** [MEASURED by the lane, `zk60-private-block-125m`, stage 12;
I read the final log: filter `private_` 181 passed / 0 failed / 4 ignored; no
shared or forbidden file touched; toy byte-identical]. At the development
rung, runs of 2, 3 and 12 blocks verify from their segments (12 blocks: prove
5.87 s, verify 1.16 s, 49,217,600 bytes, equal to the counted figure). **The
headline negative test passes both ways, with the prover succeeding and the
VERIFIER refusing:** block 2 run on something other than block 1's output is
rejected at the input-equality slot; a boundary holding block 2's input where
block 1's output differs, at the output-equality slot. Dropped, swapped,
duplicated, truncated and foreign segments, a wrong block count, a foreign
calibration and all 27 single-block tamper families applied to block 2 are
rejected; a boundary scale disagreement does not construct; the all-zero
hidden input proves and verifies as a run.

**At the 125M shape, two blocks under one transcript** [MEASURED by me, one
run each, shared box, CPU only, inside a 12 GB ceiling; evidence on the lane
branch]: **prove 62.86 s (31.19 + 31.67 s per block, witnesses built just in
time), verify from segments 2.04 s, receipt 81,084,496 bytes in two segments,
equal to the counted figure to the byte; peak 10.82 GiB** (finished 10:45).
The high-water mark rose between blocks, 10.67 then 10.82 GiB. **That rise is
allocator fragmentation**: the same run with `MALLOC_MMAP_THRESHOLD_=131072`
gives 10.04 then 10.05 GiB, flat, peak 10.05 GiB, at no measurable cost
(prove 64.07 s; finished 10:47). **Operating rule: large multi-block runs are
launched with that variable set**, and their tests print the mark after every
block.

Rulings on the build's findings: **U-1** — the check's 37-row *instance* does
not reproduce in the two-site geometry (it is refused for bookkeeping
reasons), but its conclusion stands in another instance the lane found: a
one-site budget with the proximity position declared one row too high, which
`audit_claims` accepts. M-1's derived row count closes it for boundaries; the
question of the shared audit stays with the integrator. *(Answered by the
integrator on 2026-09-20, `ZK60_RUN_AUDIT_GEOMETRY_REVIEW_20260920.md`, and
accepted by me at 13:51: the instance shows that the audit helper **trusts the
row declaration it is handed** — a precondition — and is **not** an accepted
leaking proof: the test builds claims and metadata, no proof; both external
endpoint constructors fill all five appended rows with fresh draws, the spare
included, and the real determinant check sits on rows `data+2`, `data+3`
whatever a caller declares. No change to the shared audit. The invariant to
keep is that `BoundarySpec` derives the geometry once and that preparation,
metadata and opening all use that one spec. The single-proximity-row control
stays, labelled as a deliberately weakened construction.)* **U-2** — moot under
M-7 (external endpoints unchanged). **U-3** — accepted: the transcript type
has no counter accessor and lives in a forbidden file *(since 2026-09-22 it
has a read-only squeeze counter under a test-only feature — lane stage 36,
authorised by the integrator; the position tag below stays as designed,
because the tag is a public verifier-side value and the counter is
test-only)*, so a segment header
carries a 32-byte position tag squeezed from a *discarded clone*; it is a
public function of public transcript data, re-derived and compared by the
verifier, never absorbed, never adopted; framing is 120 bytes per segment and
the counted totals use it. **U-4** — explained and closed by the allocator
finding above. **U-5** — accepted: the end-of-run "every claim discharged"
check is built; an "opened exactly once" table is not a runtime check because
each segment's content is fixed by the verifier's own statement. **U-6** and
the byte reconciliation: accepted; twelve blocks count to 484,100,736 bytes.

## 2b. The run's gate (ruling M-8) has run (13:01, 2026-09-20)

**Twelve blocks at the 125M shape** were measured first [by me, one run,
shared box, finished 11:22; evidence on the lane branch]: prove 370.61 s
(about 30.9 s per block, flat), verify by streaming 13.71 s, receipt
484,100,736 bytes equal to the counted figure to the byte, peak 10.15 GiB with
the allocator threshold pinned. A correctness result.

**The gate, on two independent honest three-block runs at the development
rung** [MEASURED by the lane; `zk60-native-jointview` at `9997d6c`, new tool
`scripts/zk60_native_run_gate.py`, no existing module edited; tests 161 → 187,
all passing; captures written by a new verifier-side module on the Rust lane,
the integrator's capture writer untouched]:

- **Whole-run transcript replay in Python**: the run binding, 375 transcript
  positions, 6,086 challenges and 6 segment position tags re-derived per
  bundle; nothing left un-re-derived.
- **Every commitment of every stage**: `A` 0, `H` 2 (shown to be the public
  lookup identity by span equality), the external endpoints 0, the masking
  commitment exactly its batched value, all as expected; every certifying
  minor nonsingular; 243–251 distinct opened columns against 256 pads.
- **Each boundary, restricted to its reserved rows: rank 6 of 6, disclosed 0**
  — both boundaries, both runs. Over all rows the rank is also 6, which is why
  the restriction matters.
- **The same hidden plane under three commitments** (block k's activation
  commitment, the boundary, block k+1's), joined through the capture's claim
  sources: a 154 × 1,248 system, **joint 0 = sum of parts**. **The whole run**
  (308 × 3,761): **joint 6 = sum 6**, in about a second. A theorem here given
  a block-diagonal non-data block and parts of 0 — and both premises are
  computed, not assumed.
- **All six controls fire, each after the honest case passes**: two claims
  sharing one pair — per-claim figures unchanged, **disclosed 2**; a single
  proximity row — **disclosed 1** (the checker's two predictions, reproduced
  on real receipts); a blinding row shared between the boundary and an
  adjacent commitment — marginals 0, **joint 1,024**; swapped claim sources,
  a foreign stage file, one pad short — each refused.
- Channels: 2 constructed, 2 derived, 4 argued, **15 open** — among them
  everything open by design for a single block, and what is new for a run: the
  sequencing surface, the cross-block joint law beyond linear rank, and the
  preimage construction for `A` and `H` at this shape (done for the boundaries
  and the external endpoints; skipped for `A` and `H`, not faked).
- **One public field is missing from the capture**: the plane index table,
  without which the per-slot terminal check stays open at this shape. It is
  public layout data; I am asking the lane to add it.

**What this is and is not.** It is the gate M-8 asked for, passing, on two
runs at one development shape, on the linear channels. **It says nothing about
the 125M shape, the hash layer is argued and not computed, and the joint-law
composition for a run is unwritten. No privacy claim is made about any run.**

**Round 2 (14:51, 2026-09-20): the table landed and the per-slot check now
runs — for 12 slots of 23.** [MEASURED by the lane; I re-ran its 39 new tests,
all passing; `zk60-native-jointview` at `fdc210e`, pushed; suite 232, all
passing.] The Rust lane added the plane index table (stage 15, `b26c869`; a
function of the public layout only — I read the module) and two new bundles.
On both, for every stage, the gate recomputes each checked slot's terminal
value from the captured evaluations and compares it with the sumcheck's final
claim: **36 of 36 equal**. The twelve cover everything that is new at this
shape except the weight slots: the pad-zero term and the support gates, the
grouped-head slots, the third limb, and **both boundary claim sites**. Five
controls fired, each for its stated reason (a perturbed evaluation fails at
exactly its slot; swapped or re-pointed planes are refused three ways; an old
bundle stays OPEN rather than "passed"; a flipped support entry is caught by
the capture's hash).
**The other eleven slots stay OPEN, and not for want of the table**: the
bundles were taken without the *values* of the public tables (folded public
weights, norm gains, the rotary pair, the exponent table) — only their lengths
and hashes. Nothing hidden is missing. **Ruling: the re-capture already owed
under the D19 tag is taken with the public tables included**, which closes
those eleven with no new arithmetic. The channel count is now 15 open of 24
(the terminal channel was honestly split in two), so the headline does not
move yet.

**Round 3 (17:27, 2026-09-20): under the separating hash tag, with the public
tables — every slot checked, and the hash layer computed for the first time.**
[MEASURED by the lane; I re-ran its 29 new tests, all passing;
`zk60-native-jointview` at `8bab0f5`, pushed; suite 261, all passing; no toy
gate file's bytes moved.] On the two re-taken, tagged three-block bundles
(`run-e-tame-tagged`, `run-f-zero-tagged`; register D19a):
- **The gate derives the four keys itself** from its own pinned context
  strings and the profile it expects, compares them with what the bundle
  names, and never consumes keys from a bundle. Six controls on that: a wrong
  key, context, profile, a tagged bundle claiming the legacy rule (refused by
  name; and replayed under the legacy rule by force, the run binding fails and
  0 of 3,328 opened columns authenticate), the member removed, a legacy
  bundle replayed under the tag.
- **Whole-run replay under the keyed function**: 375 positions, 6,086
  challenges and 6 of 6 position tags re-derived per bundle, none left over —
  the same counts as under the legacy rule.
- **New: the hash layer is computed, not argued, for what a receipt opens**:
  13 openings, 3,328 of 3,328 opened columns re-hashed (column digest → salted
  leaf → path) and authenticated against the committed roots, every path
  length checked.
- **The per-slot terminal identity: 23 slots of 23, 69 checks of 69 equal**,
  the eleven new ones using the captured public tables (each table checked
  against its length and hash, rebuilt where the shape determines it, and
  structure-checked). Fourteen controls fired, among them a perturbed table
  value failing at exactly the slots that read it.
- **Every disclosure, rank and joint figure is identical to rounds 1 and 2**
  (each boundary 6 of 6, disclosed 0; three roles joint 0 = sum; whole run
  joint 6 = sum 6). The tag moves values, not sizes or ranks.
- Channels: 25, of which **14 open** (was 15 of 24): one added and derived
  (the hash rule), one closed (the table-bearing slots).
- One thing the tool noticed in the PUBLIC test weights — the down
  projection's fold is nonzero on only 96 of 192 hidden indices — is being
  looked at separately: a fixture quirk or an indexing defect, not a privacy
  matter either way.

Still: linear channels, two runs, one development shape, nothing about the
125M shape, a captured weight fold is checked against the capture and never
against a weight matrix. **No privacy claim about any run.**

**Correction to rounds 1–3 (ruling R-3 of the run's composition disposition,
2026-09-20):** wherever "joint = sum of parts" appears above, read it as a
**consistency check of the model's coordinate classes, not evidence of
independence**. Two distinct blinding rows whose values coincide would score
exactly like an honest run. Independence across commitments rests on the
generator and the draw discipline and is still to be machine-asserted.

**Round 4 (21:35, 2026-09-20): the repaired attention slots, and the first
NON-DEGENERATE witness.** [MEASURED by the lane; I re-ran its 29 new tests,
all passing; `zk60-native-jointview` at `50fab1c`, pushed; suite 290, all
passing; no toy gate file's bytes moved.] Every bundle the gate had seen
before (a–f) used a fixture whose hidden state is identical in every attention
head, or the all-zero input; the afternoon's finding S19-F1 showed what that
can hide (`ZK60_BLOCK125M_S19F1_DISPOSITION.md`). The lane re-took two
three-block bundles at the development shape on the repaired argument:
`run-g-dense-s20` (fully dense public weights, a generic hidden input) and
`run-h-zero-s20` (the all-zero input).
- **Replay**: 375 positions, 6,092 challenges (round 3's 6,086 plus one group
  challenge per repaired slot per stage), 6 of 6 position tags, none left
  over; both private factors' whole coordinate lists re-derived and compared.
  The gate derives the public `eq` factor from the challenges *it* re-derived
  and only compares with the bundle's; the comparison is two-sided.
- **Terminal identity: 23 slots of 23, 69 of 69, on both bundles**, the two
  repaired slots under their new definition.
- **Dense against zero: 173 figures compared, 153 identical, and the 20 that
  differ are all counts of distinct sampled columns or what is computed from
  them** — they move with the transcript's randomness, not with the witness.
  **No disclosure figure, rank, boundary figure, joint figure, preimage
  figure, pad budget or hash-layer count differs between a generic input and
  the all-zero one**: `A` 0, `H` 2, boundaries, endpoints and the masking
  commitment 0; each boundary 6 of 6, disclosed 0; whole run 308 × 3,761,
  joint 6 = sum 6. That is what the linear model predicts — it ranks the
  blinding structure, which does not depend on the data rows' values — and it
  is now a measurement and not only a prediction.
- **What the gate cannot see, stated by the lane and accepted by me:** the
  defect S19-F1 is invisible from the gate's side **on every witness**, not
  only a degenerate one. Evaluated on the captured terminals, the repaired
  definition holds 6 of 6 and the pre-repair one 0 of 6 on both new bundles;
  but the defect was a disagreement between the prover's claim and the true
  sum over groups, and no capture carries a witness. **A privacy gate checks
  the verifier's view; it is no test of completeness.** The acceptance rule of
  the S19-F1 disposition (a generic honest witness against an independent
  reference) is what covers that.
- Controls all fire (a perturbed terminal in each repaired slot fails at
  exactly that slot and stage; a changed `eq` point is refused by name from
  either side; the other definition forced is refused in every stage).
  Bundles a–f stay readable under the definition their own source pin
  selects, marked superseded; their records re-run with no unclassified
  difference. Channels: 25, **14 open**, unmoved.
- Limits: every group figure was taken with ONE group bit (two key-value
  heads); a shape with more group bits — 125M has two — has never been through
  the gate. Linear channels, two runs, one development shape. **No privacy
  claim about any run.**

**Round 5 (23:57, 2026-09-20): two group bits, and the toy gates' pins
completed.** [MEASURED by the lane; I re-ran its 36 new tests and the record
guard, all passing; `zk60-native-jointview` at `6667aba`, pushed; suite 335,
all passing.] The Rust lane built a development shape with the 125M head
geometry — twelve query heads over four key-value heads, padded slots
{3, 7, 11, 15} — and two three-block bundles on it (`run-i-dense-k4`, fully
dense and generic; `run-j-zero-k4`).
- **Nothing failed to scale.** Replay: 375 positions, 6,854 challenges, 6 of 6
  tags, nothing left over; the 762 challenges more than at the two-head shape
  decompose to the unit (three stages of 3 definition draws, 3 sumcheck
  rounds, 104 and 144 proximity entries). Terminal identity 23 of 23, 69 of
  69, the group factor now over two variables. Hash layer 3,328 of 3,328 under
  the shape's own derived keys, and **0 of 3,328 under the other shape's
  keys, in both directions**. Of 173 figures against the two-head shape, 134
  are identical and every one of the 39 that differ is a size the shape must
  change or a group count that doubles as predicted (predicted in a pure test
  before being read off a record). The commitments grow **only in data
  rows**; non-data rows, the claim-block ranks (74 and 20), every disclosure
  figure (`A` 0, `H` 2, all else 0) and the whole-run figure are unmoved.
  Dense against zero at two group bits: the same twenty sampled-column classes
  as at one.
- **Two findings about the gate itself, which only a second shape could
  show.** (1) The port had *correctly* refused the new bundles when their
  `shape.rs` pin moved — and then crashed, because the refusal path returned a
  record without the keys the next stage reads; no bundle had ever moved a pin
  before. Repaired and tested. (2) **`run_capture.rs`, `run.rs` and
  `boundary.rs` are pinned by no run-gate tool**, while the tool's own comment
  said they were; `run.rs` changed between the two pairs of bundles and
  nothing noticed. The comment is corrected and the three files named with
  their digests; **the gap is recorded, not closed** — closing it means
  reading three files at five capture commits. Ruling: owed, next round; until
  then the run gate's statements about the *run layer* rest on the replay
  reproducing every challenge and tag, not on a pin.
- A one-group-bit assumption was found in a **control** (it perturbed only the
  first group coordinate), not in any measured figure; the controls are now
  families reaching both bits and both slots, with a new one (the declared
  point's two coordinates swapped) that can only exist at two bits.
- **The toy gates' pin set now covers the whole path** (my ruling of 22:06):
  29 files established from the integrator's `4751b93`, 9 already pinned, **20
  pinned by nothing until tonight**, all 20 read and pinned, none refused;
  exactly one tool's hash moved, and only because the tables were written
  into it; every figure of record unchanged (11 / 2 / 8 / 7 on all four
  captures, ten controls). Named residual: three files of the separate
  private-attention profile that two of the four toy captures reach.
- Channels: 25, **14 open**, unmoved. Linear channels; two runs per shape; two
  development shapes; nothing at the 125M shape. **No privacy claim about any
  run.**

**Round 6 (00:46, 2026-09-21): the run layer is pinned.** [MEASURED by the
lane; I re-ran its 25 new tests, all passing; `zk60-native-jointview` at
`eacdddc`, pushed; suite 360, all passing; no earlier assertion moved.] Round
5's gap is closed: of eight run-layer files, the gate's ports depend on four —
`run.rs` (the six header absorbs and their order, the stage loop, the position
tag), `boundary.rs` (the boundary table and its reserved block),
`run_capture.rs` (the writer: schema, field orders, transcript labels) and
`plane_index.rs` (already pinned). Nine (file, digest) pairs over the five
capture commits were **read hunk by hunk against the ports before being
pinned; none refused, and no port turned out stale** — the three hunks that
touch something a port relies on had each already been followed by the port.
A changed digest now suspends the stages that depend on it, by name and
without raising (shown live for a run-layer file, the boundary file and an
argument-layer file). All ten bundles re-run with no unclassified difference
and no figure moved. Two of round 5's own figures were wrong and are corrected
in place (a line count; "byte-identical at every capture commit" — the
boundary file has two digests). **Named limit:** `wire.rs`, `run_sink.rs`,
`endpoint_g.rs` and `hash_domain.rs` cannot be pinned from a bundle at all,
because the capture writer does not list them among its sources; the ask to
the Rust side is to list them. *(Done on the lane the same night, stage 24:
the writer lists 15 sources; future bundles only.)*

**Round 7 (05:59, 2026-09-21): the preimage construction for the two big
commitments — the step every earlier round had recorded as "skipped, not
faked".** [MEASURED by the lane; I re-ran its 30 new tests, all passing, 120 s;
`zk60-native-jointview` at `df04d14`, pushed; suite 390, all passing; the arm
is off by default and the ten records of record re-run with no figure moved.]
For every hiding commitment of every stage of all four current bundles — ten
per run, forty in all, `A` and `H` included — the gate **fixes the
commitment's data rows to zero and solves for blinding (reserved pair rows,
the proximity pair, the helper commitment's zero-sum pair, 256 pads per row)
that reproduces the captured view**, then recomputes the view from that
preimage and compares entry by entry: **4,763,302 view entries, none
differing** (group vectors, proximity vectors, claim values, opened column
entries), and **10,240 salted Merkle leaves** rebuilt from the preimage,
re-hashed under the keyed rule and re-authenticated against the published
salts and paths. The captured views come from a **fully dense, generic hidden
input**; their reproduction from zero data is the concrete content, on real
bytes, of "the linear view does not depend on the input". Round 1's "too
expensive" was wrong: with zero data every data row drops out of the
accumulations, the system never has to be assembled (per group, 1,024
independent 2 × 2 systems and a small kernel correction), and one commitment
takes 8 to 13 seconds in exact arithmetic. The solver is not a fork: every
primitive is imported from the toy gate's pinned module, and run at the toy's
widths the new code reproduces the toy module's whole solved matrix.
**Six controls fire**, among them the one that tests the criterion itself (a
perturbed group-vector entry leaves the claim values unreachable inside the
kernel) and the project's standing counterexample made concrete: **with a
blinding row shared between `A` and `H`, each commitment alone still has a
preimage, and the two force different values at all 1,024 positions — no joint
preimage exists.** Channels: 25, now **5 constructed, 5 derived, 4 argued, 11
open** (was 2 / 5 / 4 / 14).
**What it is not.** It fixes a commitment's data rectangle to zero — the
object all rounds call "the all-zero hidden input" — and does not show that
rectangle is a reachable witness (the Rust lane's all-zero proofs do that); it
says nothing about the *law* of the blinding (the lemma's job); it does not
cover the masking commitments (the port of their channel is written at the
toy's row layout — now the largest open channel), a joint run-wide preimage,
the unopened leaves, or the 125M shape. **No privacy claim about any run.**

**Round 8 (08:03, 2026-09-21): the masking commitments, and one joint preimage
for a whole run.** [MEASURED by the lane; I re-ran its 42 new tests, all
passing; `zk60-native-jointview` at `6fa571e`, pushed; suite 432, all passing.
Five assertions of earlier test files moved — all channel counts about the
record's shape — and the lane says so.]
- **The masking commitment `M` at the shaped layouts**: 23 slots, 50 rows and
  34 functionals at both development shapes (constants of the slot table, not
  of the shape); the functionals' declared order checked by position, value
  and weights, 34 of 34 on every stage of every bundle. The toy gate's solver
  was already shape-driven; what was toy-specific was five other things (the
  source pins, the capture and replay types, three mask-domain constants now
  derived from the bundle, a missing cross-check against the shape, a missing
  Merkle layer), each supplied. Fifteen objects are imported from the toy
  module and none re-implemented; at the toy's widths the driver reproduces 19
  of 19 committed toy-gate figures, both exhibited-randomness digests
  included.
- **Constructed and verified per stage: one mask-coefficient vector that does
  both sides** — it reproduces every slot's published masked round messages
  and mask-bearing scalar *and* `M`'s whole opened view (the toy gate never
  joined the two): 191,610 entries over the four bundles, none differing;
  3,072 salted leaves re-authenticated.
- **A joint preimage for the whole run**: zero data everywhere, round 7's
  blinding, round 8's coefficients — one assignment per run reproducing
  **4,954,912 published entries over the four runs, none differing**, with
  13,312 salted leaves. The four things that couple commitments in an honest
  run were enumerated and checked: the boundary and endpoint planes under
  several commitments (24 identified row pairs, all data rows on both sides,
  **none touching a blinding row — which is the whole difference from the
  shared-row counterexample**); 531 claim values, one shared and met as the
  same published number; the masking layer by one vector per stage; the
  terminal identity, respected only in the narrow sense that every published
  number is reproduced, and written narrowly.
- **Six controls fire.** The most instructive: an opened-column entry moved on
  a coefficient row produces exactly four mismatches, all on the blinding and
  zero-sum rows of that one column — the pads buy the row and pay for it four
  rows down; and the masking layer's own version of the shared-row
  counterexample — a coefficient index that two slots' rounds both force, to
  different values, has no joint assignment while `M`'s disclosed dimension
  does not move.
- Channels: 28 (three of `M`'s that this gate had never graded separately),
  **10 constructed, 5 derived, 4 argued, 9 open**.
- **Still open, and why**: the *law* of the blinding on the fibre the preimage
  lives in (the lemma's and the composition's job, with its owed
  draw-accounting test *— the test is live since 2026-09-22, lane stage 36:
  all seven assertions, 327,052 draws per toy proof measured exactly; what
  stays owed is the LAW, not the count*); the hiding of unopened leaves (argued, in the model);
  the honest unmasked rounds of a slot (no capture carries them, by the
  capture rule); a writer-side pin for `zk.rs` and seven `zkp-core` files that
  no bundle pins; the 125M shape; the private-attention profile. **No privacy
  claim about any run.**

**Round 9 (11:18, 2026-09-21): the gate at the 125M shape — the first time
anything is MEASURED there** (`zk60-native-jointview` at `ad16a77`, pushed;
report §13; I re-ran its 42 tests and read the two records' public-identity
flags myself). Input: two two-block runs captured by the lane at `f4697f9`
(dense generic input; all-zero input), a new capture schema that keeps big
arrays in one side file by SHA-256. Everything below is [MEASURED] on those two
bundles unless labelled otherwise.

- **Loader.** A reference is resolved only after its length, element type,
  byte range and SHA-256 are checked; thirteen malformed cases each give the
  NAMED refusal. The decoder was proved against the format on a development
  bundle two ways (3,430,417 leaves member by member, none differing; and
  through the whole gate, only names, paths, clocks and the new store block
  moving). That does not test the Rust encoder, which has its own test.
- **Pins.** All 38 pinned files verified against the blobs at `f4697f9`; the
  six that moved since the last accepted capture commit were read hunk by
  hunk; **the 23 shared files are now pinned by the writer, and the eight a
  port depends on carry exactly the digests round 8 read** — the writer-side
  pin this page listed as open is granted.
- **Replay and hash layer.** 251 positions and 27,828 challenges re-derived,
  none not reproduced; 2,304 opened columns (52,867,072 bytes) re-hashed under
  the derived keys and authenticated.
- **The 23-slot terminal identity: 46 of 46**, with two group bits, 13 public
  tables rebuilt and 15 taken from the capture after a digest check.
  **Finding M-F1 (the headline, and a port defect, not a prover defect):** the
  first pass was 40 of 46 — every zero-check port assumed a pad-zero term, and
  at 125M three domains are exact powers of two (2^9, 2^17, 2^20), so their
  host slots draw two fewer challenges (`argument.rs:936`). No development
  shape could have shown it. Repaired by deriving the condition from the
  shape; the crash became a named refusal; its own control exists only at this
  shape. It agrees with the counted five pad-zero hosts at 125M against eight
  at the rungs.
- **Disclosure, exact ranks.** `A` 5,681 rows, 122 claims, disclosed **0**; `H`
  7,120 rows, 51 claims, disclosed 2 **which the gate checks IS the public
  LogUp identity** (true in both stages of both bundles); both endpoints 0;
  **the boundary 6 of 6 on its reserved rows, disclosed 0**; `M` 50 rows,
  disclosed 0 beyond its budget; the whole run 206 functionals over 25,686
  rows, joint 4 = the sum of the parts.
- **Preimage construction.** Three small commitments (145,118 entries) and
  **`A` of block 0 alone — 2,070,138 published entries recomputed from
  blinding constructed for all-zero data, none differing**, 365 s at 2.5 GB;
  the masking arm 32,918 entries, none differing. The other three big
  commitments, round 7's controls and the joint run-wide preimage are
  **running detached** (about 26 minutes a bundle; markers under
  `results/zk60_native_run_gate_m125/`), so the 125M records of record
  carry the channel table at **2 constructed / 5 derived / 4 argued / 17
  open** — NOT the development shapes' 10 / 5 / 4 / 9 — until they land.
- **ADDED 12:49 the same day — the preimage step is now COMPLETE at 125M**
  (`zk60-native-jointview` at `51f74b2`, pushed; I read the figures out of the
  committed record `m125-dense-full.json` myself). **All seven hiding
  commitments of a two-block run, on BOTH bundles, have blinding constructed
  for all-zero data that reproduces the captured view: dense 8,263,736
  published entries, all-zero 8,256,579, none differing, 1,792 salted leaves
  re-authenticated each; round 7's six controls fire.** And **one joint
  assignment for the whole run holds at 125M on both: 8,296,654 and 8,289,497
  entries, none differing** (the masking layer's 32,918 entries and 512 leaves
  included; 2,304 leaves in all), the four couplings between commitments
  checked, 128 identified row pairs, all data rows, **none touching a blinding
  row**. Cost: about 21.5 minutes a bundle (an `A` about 315 s, an `H` about
  260 s) at 5.5 GB — the advance estimate was 3.8 times too high, the second
  time the cost estimate for this construction was the thing that was wrong.
  Ten development records re-run and leaf-diffed with nothing unclassified;
  the native suite is 474 tests. Two more findings in the gate's own tools
  (M-F3's first repair was partial; M-F4, a controls-off pass words a closed
  arm as not closed — recorded, not repaired). **The 2 / 5 / 4 / 17 channel
  count above is therefore superseded for the full-arm records; round 9b
  states the table from the tool's own array.** Ruling R-3's sentence stays
  beside every joint figure: a joint preimage shows the published values are
  CONSISTENT with all-zero data; the LAW of the blinding on that fibre is the
  lemma's and the composition's job. *Orchestration note: the round-9 agent
  and its successor wrote the same worktree for about half an hour (my error:
  the first was re-woken by its own finished jobs). By the first agent's own
  check everything committed through `51f74b2` is free of the successor's
  tool-byte changes — the full-arm record I read finished at 11:37, before the
  successor started — and the successor, now the single writer, re-verifies
  that, treats later job output as scratch and regenerates the records once
  its tools are final.*
- **CORRECTED 14:26 the same day, after round 9b verified round 9 against the
  committed records (`zk60-native-jointview` at `4db3a4d`; report §14.9 and
  §14.10). Three things I carried from round 9's report were too strong:**
  1. **The joint figure is a SUM, not a third verification.** The joint stage
     builds nothing new: it checks the four couplings between commitments and
     adds the two arms up — 8,296,654 = 8,263,736 (the seven commitments) +
     32,918 (the masking layer), 2,304 leaves = 1,792 + 512, and likewise
     8,289,497 for the all-zero bundle. Every entry WAS recomputed and
     compared, once, in its own arm (round 9b re-added the seven per-commitment
     counts and they sum exactly). What makes the statement JOINT is coupling
     C1: 128 identified row pairs, all data rows on both sides, none touching
     a blinding row — so the per-commitment assignments are compatible and
     their union reproduces the run's published view. The same reading applies
     to round 8's 4,954,912 at the development shapes.
  2. **"Controls fire at 125M" was true only of two families.** Round 7's six
     preimage controls and round 8's masking controls fired at 125M. The
     terminal-identity family and the run-control family RAISED in both 125M
     control passes (tool defects, finding M-F3 and a shadow-bundle bug, since
     repaired), and the control written for finding M-F1 (M9-3) **had never
     fired at any shape** — it read an attribute its input does not have and
     reported itself inapplicable with `ok: true` (round 9b's finding P-F2).
     It is repaired and now has a development-shape twin (CT-9) that fires in
     four directions at rung-P2 in about a second, in the ordinary suite. **A
     125M control pass under the repaired tools has not landed**; it is queued.
  3. **The channel table at 125M:** the records of record say 2 / 5 / 4 / 17,
     the dense full-arm record 10 / 3 / 4 / 11, the all-zero full-arm record
     5 / 3 / 4 / 16 (its exit code 1 is finding M-F4 only: controls not
     requested). **No 125M record carries the rungs' 10 / 5 / 4 / 9 yet**; one
     queued pass can.
  What stands unchanged: the ranks, the terminal identity 46 of 46, the hash
  layer, the prediction table, and the per-commitment preimage construction
  for all seven commitments on both bundles with no entry differing.
- **Round 9b's own results (same commit; native suite 507 tests, exit 0).**
  The new small shape rung-P2 — T, Kv and F unpadded, the same three as 125M —
  through the WHOLE gate on both bundles: the pad rule was derived by the
  predictor BEFORE the run (slots 02 / 16 / 18 at 13 / 19 / 24 draws against
  rung-K4's 15 / 21 / 26; a stage exactly 400 B shorter) and the capture
  agrees; terminal identity 46 of 46 twice; preimage 862,980 entries and the
  joint sum 894,880, none differing; channels 28 at 10 / 5 / 4 / 9; every
  control family fires. Source pins re-read from `f4697f9` to `4ccbad1`, hunk
  by hunk: **the lane's speed stages 28 and 29 changed nothing that is sent,
  absorbed or drawn — upheld by a second independent reading**, and the replay
  re-derives all 4,560 challenges. Finding P-F1: `pad.rs`, the file the pad
  rule is ported from, had been listed as unpinned since a statement that
  stopped being true at stage 27; it is pinned now, and no production line of
  it has moved since round 1.
- **Round 9c (10:02, 2026-09-22; `zk60-native-jointview` at `d9ca384`,
  pushed; native suite 530). The 125M shape now carries the WHOLE channel
  table, and three more small shapes went through the whole gate.**
  1. **125M, complete.** The one pass that could carry every control family
     under the repaired tools (`dense-everything`) landed twice with the same
     figures: 46 of 46 slots; the seven commitments' preimage entries summing
     exactly to 8,263,736, none differing, 1,792 leaves; masking 32,918 / 0 /
     512; the joint sum 8,296,654; **channels 28 at 10 constructed / 5 derived
     / 4 argued / 9 open — the same table as the development shapes** (I
     counted the grades in the committed record myself). The 14:26 correction
     of 2026-09-21 is therefore closed on its second and third points: the
     terminal and run-control families fire at 125M, and the control written
     for finding M-F1 (M9-3) fires at 125M in all three directions. Its
     `ok: false` is the wording the round predicted (a public-table check
     pre-empts the message it demands), not a failure. The two records of
     record were re-taken (174 s / 1,460 MB and 162 s / 1,452 MB) with nothing
     unclassified.
  2. **rung-C6, rung-W14, rung-E32** (the lane's stages 31–33: correction
     C-6; the 2^14 row width with head size 64 — 125M's slot structure exactly;
     the 125M endpoint's 32 data / 37 commitment rows): predictions committed
     before any run derive C-6's dropped lookups, the ×64 table lift and the
     endpoint rows, 21 validations, none wrong; **six bundles, 46 of 46 each,
     every stage ok, 28 at 10 / 5 / 4 / 9, every control family firing, 180
     figures with none unexplained at each shape**; dense against zero
     differs only in sampled-column counts and what derives from them.
     rung-W14 costs 1,410 s and 1.26 GB (508 s of it the 2^16-wide preimage).
     Correction to my own brief: the 56,960-byte column-digest class is
     125M's `H` and no small shape reaches it; rung-E32 reproduces the
     296-byte endpoint digest instead.
  3. **The lane's speed stages changed nothing sent, absorbed or drawn** —
     the four rewrites of stage 35 read hunk by hunk, each an identity — the
     third independent reading of that claim.
  4. **The lane's slot-IR export read as a cross-check of the hand port:**
     7 shapes × 23 slots × 8 = 1,288 structural comparisons, 0 disagreements
     (the first run's eleven were all in the new reader's label map — none in
     the port, none in the export). Ruling I-8 kept: the hand port remains
     the evaluator.
  5. **Finding E32-F1 (the lane's, recorded here for the lane):** the rung-E32
     bundles' `source_commit` label names `4505ddf`, one commit BEFORE
     `Shape::rung_e32` existed; the 38 digests are honest (35 match that
     commit, the three that do not are the files the next commit added), the
     label is stale — the writer's environment variable was not advanced. The
     gate now asserts the stale label by machine. **Ruling: record, do not
     regenerate** (the bundles are regression data, not evidence for any
     statement); after integration the lane's writer refuses a label that is
     not the tree it runs from.
  6. **The native suite has outgrown a 4 GiB single-process cap**: 530 tests
     pass at 8 GiB; at 4 GiB the process is killed (measured: the suite
     without the new slot-IR reader peaks at 5,054 MB, mostly reclaimable
     file-backed pages; the reader adds 366 MB of anonymous memory). Not a
     leak; run the suites at `MemoryMax=8G` from now on, and no suite result
     at 4G is to be read as a failure of the tools.
  What this is not: still linear channels, two-block runs, no privacy claim
  about any run; ruling R-3's sentence beside every joint figure.
- **Prediction before measurement.** 180 figures predicted from the shape and
  validated on both development shapes first: 55 shape-independent figures
  identical at all three shapes, 61 block-count figures, 64 scaling figures as
  predicted, **none unexplained**. Dense against all-zero at 125M: 124 of 128
  figures identical; the four that differ are sampled-column counts and the
  pad margins that follow from them — the same classes as at the rungs.
- **Controls fire at 125M** *(too strong as written — see the 14:26
  correction above: only the preimage and masking families are verified to
  have fired at 125M; the run-control and terminal families raised)*: a moved
  array range is refused by digest (this
  one caught a defect in the round's own loader cache, finding M-F2, fixed);
  one moved column entry fails exactly one leaf of 2,304; the rung's keys
  authenticate nothing; round 8's six masking controls.
- **What this is not.** Two runs of two blocks: one internal boundary, where
  the model has eleven. Linear channels only. The law of the blinding, the
  joint law and the hiding of unopened leaves are where round 8 left them.
  Both bundles still say `privacy_review_complete: false`. **No privacy claim
  about any run, at any shape.**

## 3. What I reviewed myself, and what was delegated

I read the check's hand-back report. M-7's choice (keep the external
endpoints' geometry) is mine: it removes two of the seven moving sites and
keeps the measured single block's digest meaningful inside a run. I did not
re-run the rank model or re-read the stage order. Both documents were produced
by delegated Opus agents, the second instructed to assume the first was wrong.

## 4. Next steps

1. Errata pass on R (the four blocking items, 13 corrections, 11 conditions,
   M-1 … M-8).
2. Build, test-first, on the lane `zk60-private-block-125m`: the claim audit on
   a hand-built two-claim boundary schedule; the 37-row refusal; then two
   blocks at the development rung with the headline negative test (block 2
   rebuilt on a different hidden input than block 1's output, rejected by the
   VERIFIER); then three; then twelve at the rung.
3. One measured two-block run at the 125M shape — detached, heavy lock, memory
   ceiling, per-stage high-water marks — before twelve.
