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
- **The memory carry-over is exact to the byte** (88.2 MiB), the time
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
has no counter accessor and lives in a forbidden file, so a segment header
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
