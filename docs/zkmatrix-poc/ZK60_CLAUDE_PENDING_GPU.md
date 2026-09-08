# CL8 — GPU support for the pending private blocks

Task: `zk60_claude_tasks.json` CL8 (`ready_design`). Owner: Claude.
Tool: `scripts/hashline_cl_pending_memory.py` · tests:
`tests/test_hashline_cl_pending_memory.py` (13 at first delivery; **42, green**
after the round-7 response in §7 — the first version's counting errors and
their corrections are recorded there, not erased).
Inputs read: A03 `ZK60_PENDING_FFN.md`, A01 `ZK60_ATTENTION_SCHEDULE.md`,
`ZK60_CLAUDE_GPU.md` (CL1 rungs 1-5), M1 `ZK60_PARALLEL_ROUND1.md`.

**This is design and counting only.** No private protocol is implemented here
and no privacy claim is made. Per CL8's own limits, the implementation and any
privacy statement need Fable's group/mask audit and Codex's interface
agreement. Nothing below presents a copied plane or a standalone S2 receipt as
provenance from real arithmetic — the seam terms are counted as obligations,
not as evidence.

---

## 1. The one fact the whole account turns on

> **RELEASE IS NOT FREE.**

`Pooled::drop` calls `pool_put`, which retains the buffer (up to 64, no byte
budget), and `pool_take` reuses only on an **exact** length match. So a
released buffer still occupies the card until a drain, and a released `rows*n`
buffer can never satisfy a later `rows*nn` request.

This is not a detail. CL1's first allocation table treated release as free and
understated the resident peak by **1,349 MiB** — in the direction that
authorises a run it should refuse. M1 caught it. The tool models LIVE and
POOLED as separate states for that reason, and its calibration test fails if
that behaviour is ever lost.

**Calibration.** The tool reproduces the Mistral W commitment at
**13,492.043 MiB**, peak event `column_hashes` — matching M1's independent
planner to three decimals and CL1's hand derivation. Three routes, one number.
That is the licence to believe anything else it prints.

---

## 2. What is simultaneously retained, per A03

A03 is explicit: *"Deferring openings retains encodings, data, pads, salts and
Merkle trees"*, and *"Do not claim A03 is a memory optimization: composition
can increase overlap."* So the composed block is modelled with **every
commitment live until the single final opening**, and the tool asserts that
(`test_composition_overlaps_rather_than_reusing`).

Per block, before `final_open` (table corrected after the round-7 review, §7:
the FFN side is concrete only when a **layout** is supplied — rows, columns,
rate, pads, path — never from a bare row count; and a supplied role is
counted as the SAME buffers the commit builders use, with the same fates):

| buffer | owner | born | dropped | fate at drop | status |
|---|---|---|---|---|---|
| `ffn_{W,A,H}_retained` | block *i* | `ffn_{role}_commit` | final_open | pooled until drain | **SYMBOLIC** unless a layout is given |
| `ffn_{role}_systematic_data` | block *i* | `ffn_{role}_commit` | final_open | POOL | concrete from the layout |
| `ffn_{role}_pads`, `_coset_powers` | block *i* | `ffn_{role}_commit` | final_open (chunked) / next event (resident) | **FREED** (raw) | concrete from the layout |
| `ffn_{role}_encoded_matrix` | block *i* | `ffn_{role}_commit` | final_open | POOL | resident layout only |
| `ffn_{role}_chunk_*`, `_blake3_column_state` | block *i* | `ffn_{role}_commit` | next event | POOL (take_min capacity) | chunked layout only |
| `ffn_{role}_inverse/expanded_coefficients` | block *i* | `ffn_{role}_commit` | next event | POOL | resident layout only |
| `ffn_{role}_device_leaf_hashes` | block *i* | `ffn_{role}_commit` | next event | **FREED** (raw) | concrete from the layout |
| `attn_{W,A,H}_retained` | block *i* | attn_commit | final_open | pooled until drain | **SYMBOLIC** |
| `seam_xz_boundary` | block *i* | seam | final_open | pooled until drain | **SYMBOLIC** `4*nb_d*base_rows` |
| `challenge_state` | block *i* | seam | final_open | pooled until drain | **SYMBOLIC** |
| `twiddles` | gpu | begin | never | kept | **SYMBOLIC** unless `ntt_max_log` is given |

With nothing supplied, two blocks double the per-block surface exactly (2 x 8
+ the process-wide twiddle term = 17 symbolic terms, asserted). Even with all
three FFN layouts and the tables supplied, five terms per block stay symbolic
and the plan stays incomplete (asserted).

### The tool REFUSES to print a peak for these

An incomplete plan reports `peak_accounted_mib: null` plus
`peak_refused_because`, and moves the numeric part to
`numeric_subtotal_bytes_excluding_symbolic`. The first draft printed
"peak 0.0 MiB" for a fully symbolic plan, which is the single most misquotable
thing this tool could emit — a reader could have taken it as "the pending
block costs nothing". Callers must key off `complete`.

---

## 3. What stays symbolic, and why it cannot be guessed

- **The attention arithmetic is not implemented.** A01 is an *observed*
  schedule; there is no source to count. Every `attn_*` term is a name.
- **The mask/claim plan is not selected.** A03's own acceptance item 1 says an
  independent API/privacy review picks it. Until then mask, histogram and
  proximity row counts are not fixed, so even the FFN side's *final* row counts
  are provisional.
- A03 adds that *"No existing A row is unallocated"* and that two paired X/Z
  boundary sites per d-block alone add `4*nb_d` base rows — **and that this is
  not the cost of a complete repaired profile.** So the seam term is a floor on
  an unfinished design, not an estimate.

Anything numeric published for these today would be invented. The tool is built
so that inventing them is awkward and omitting them is loud.

---

## 4. Proposed GPU interface for Codex

The current entry points are fine for ONE commitment opened by its own caller:

```rust
dev_commit_zk_from(params, d_data, rows, pads, pows, ntt) -> (DevCommit, Vec<Digest>)
dev_columns(dc, idx) -> Vec<Vec<Fp>>
```

They are **not** sufficient for a composed block deferred to a single final
opening, for three reasons, each with a concrete ask:

**(a) One-shot finalization is not enforced.** Nothing stops a caller opening
the same commitment twice under different challenges, or finalizing twice.
*Ask:* a `Finalizer` whose method takes `self` by value, so a second
finalization is a compile error rather than a runtime check:

```rust
pub struct CommitHandle { id: CommitId, /* opaque; owns its device buffers */ }
pub struct BlockFinalizer { handles: Vec<CommitHandle> }
impl BlockFinalizer {
    pub fn open_all(self, challenges: &Challenges) -> Result<Openings, String>; // consumes
}
```

**(b) Commitment identity is not immutable.** `DevCommit` is a plain struct;
its fields could be reassigned between commit and open, and CL1 already showed
what deferred state costs when an invariant it depends on changes underneath it
(the twiddle shrink, CL2). *Ask:* bind `CommitId` at construction to the
`(params, root)` pair and expose it read-only, so an opening can assert it is
opening what it committed.

**(c) Drain points must be explicit in a composed schedule.** Because release
is not free, a composition that commits several blocks before opening will hold
every released scratch buffer unless it drains. Today `prove_layer_zk_v3`
drains after H. *Ask:* let the block scheduler declare drain points, and have
the finalizer drain between blocks where the claim structure permits it.

**What I am NOT asking for:** any change to the transcript, the pad/coset
construction, the salts or the opening bytes. All three asks are ownership and
lifetime plumbing. If any of them would move a byte, it is the wrong design and
should come back to this lane.

---

## 5. How CL1's chunking interacts (and where it does not help)

Chunking removes the `rows*nn` buffers from each *individual* commitment, which
is why the FFN-only layer peak fell to a measured 5,182 MB with 37% headroom.
It does **not** address composition: the retained *encodings, data, pads, salts
and trees* A03 names are exactly what a deferred opening must keep, and CL1's
`ZkReenc` deliberately keeps pads and powers resident so the deferred opening
can re-encode.

So the honest statement for the pending work is: **chunking bought per-commit
headroom, not per-block headroom.** Whether a composed private block fits is
still open, and it is open in the symbolic terms above rather than in a number
I could quote.

---

## 6. Handoff

- `scripts/hashline_cl_pending_memory.py` — subcommands `resident`, `chunked`,
  `fallback` (each with `--inventory-bytes` for a warm pool, given as
  capacities, never as a flag) and
  `pending --blocks 1|2 [--ffn-layout ROLE=rows:log_cols:inv_rate:q_pad[:path[:chunk]]]...
  [--ntt-max-log N] [--drain-between-blocks]`. Opens no device, reads no data.
- `tests/test_hashline_cl_pending_memory.py` — 13 tests at first delivery, 42
  after §7: the 13,492 MiB calibration, release-is-not-free,
  drain-actually-frees, chunked-is-smaller, reconciliation of every builder
  against the shared planner, the review's chunk-rounding cases, twelve
  **rejection** tests (negative/non-integral counts, bad units and kinds,
  empty/duplicate schedules, double ownership, drop-before-or-at-birth,
  unknown events/owners, unsupported shapes, bad inventories, bare row
  counts), the resident/chunked/fallback return states, reuse identity
  (capacity transferred and counted once), pool-cap frees, an unreachable
  fallback refused, and the CLI.
- Nothing in Codex's receipt/codec modules was touched;
  `scripts/hashline_memory_plan.py` and `scripts/hashline_cl_chunk_sweep.py`
  are IMPORTED (their `_Pool`, `commitment_plan`, `plan_summary`), not edited.
- When the attention relations land, supply their LAYOUTS (rows, log_cols,
  inv_rate, q_pad, path) the way `ffn_layouts` takes the FFN ones and the
  symbolic surface shrinks; `complete` flips to `true` only when nothing is
  left symbolic, and only then is a peak printed at all. (This bullet used to
  say "supply their row counts to `ffn_rows`"; a row count without a width
  is not a byte count, and `ffn_rows` is now refused — §7, finding 4.)

---

## 7. Round-7 review response (Codex, 2026-09-06 — `ZK60_CL8_CL10_REVIEW.md`)

Codex kept the symbolic-plan refusal (`peak=null` while any term is
unresolved) and found five errors in the concrete component model. All five
were real. Each is answered below with what changed, how it is tested, and
what the fix does NOT claim. Test command and count, for any later session:

```
python3 -m unittest discover -s tests -p 'test_hashline_cl_pending_memory.py'
# Ran 42 tests ... OK   (13 before this response)
```

The through-line of the fix: **the first version copied rules; the second
imports them.** `hashline_cl_pending_memory.py` now loads
`hashline_memory_plan.py` and `hashline_cl_chunk_sweep.py` by path and uses
their `_Pool`, `commitment_plan` (as the shape validator and the reference
peak) and `plan_summary` (the device chunk plan). Finding 1 happened because
a correction made in one tool did not reach a copy in another; the test
`test_every_builder_reconciles_with_the_shared_planner` now asserts, for
every path at six shapes, that this tool's peak, no-reuse bound,
post-return pool bytes and post-return live bytes equal the planner's.

### Finding 1 — chunk rounding

*Reported:* `chunked_hiding_commit(300, 10, 4, 16, 1)` gave 8,192 B of
coefficient scratch; the device clamps to >= 128 rows and takes 1,048,576 B.

*Cause:* a private `rmax = min(rows, chunk)`, written before CL4/CL6 fixed
the same line in the planner. The fix never propagated.

*Change:* the chunk plan comes from `hashline_cl_chunk_sweep.effective_chunk_rows`
+ `plan_summary` (clamp >= 128, unrounded; rows <= choice is ONE chunk of
all rows; otherwise steps of `(choice // 128) * 128` with a short final
chunk), cross-checked against `commitment_plan(...)["chunk_rows"]`; the
builder REFUSES with `PlanError` if the two mirrors ever disagree. The report
carries `meta.shape.{chunk_choice, chunk_rows, rmax, chunks, final_chunk_rows}`.

*Tests:* `ChunkRounding.*` — (300, 10, 4, 16, 1) → 1,048,576 B, rmax 128,
3 chunks, final 44; (300, …, 300) → 300 rows of scratch, one chunk;
(1000, …, 300) → 256, 4 chunks, final 232; a nine-point grid equal across
this tool, the sweep and the planner (including 300 rows at choice 200 →
128: the choice is never the chunk size unless every row fits in it).

### Finding 2 — invalid dimensions

*Reported:* a buffer with `count=-1` was a "complete" plan with peak −8 B.

*Change:* `Buffer.check()` and `Plan.validate()` reject: non-positive,
non-integral or boolean counts; numeric strings posing as symbols; element
sizes outside {1, 2, 4, 8, 16, 32}; unknown kinds; empty names/owners or a
`::` in either; empty schedules, duplicate event names, unknown birth/drop/
drain events; a drop before OR at the birth event; owners outside the
plan's declared owner set; double ownership; malformed inventories. Shapes
go through `commitment_plan`'s validator (index widths, rates, pad ranges,
NTT limits), so an unsupported shape is refused by the same rule everywhere;
`blocks` must be 1 or 2 (the spec's scope); `ntt_max_log` must cover every
supplied layout's encoded width (CL2's monotonic-cache invariant).

*Tests:* `Validation.*` (12 tests, ~45 cases), starting with
`test_a_negative_count_is_rejected_not_a_negative_peak`.

### Finding 3 — release versus free

*Reported:* every released buffer was treated as pooled; the resident plan
kept pads, powers and leaves through return although the resident result
retains data + encoding and the callee had already dropped the leaves.

*Change:* every `Buffer` has a `kind` that decides its fate at `dropped`,
read from the source: `raw` (`htod_sync_copy` / `alloc::<u32>`) is FREED;
`pool` (`Pooled::take`, exact) and `pool_min` (`Pooled::take_min`) go back
to the POOL until a drain. The simulation reports `pooled_here`,
`freed_here`, `drained_here` per event and an `end_state` with the live,
pooled, freed and drained sets. The `dropped` event is the Rust `drop`;
what happens next is the type's business, exactly as in `cuda.rs`.

| path | retained at return (live) | pooled at return | freed before return |
|---|---|---|---|
| resident | data, encoded matrix (+ twiddles) | inverse coef (rows·n), expanded coef (rows·nn) | pads, coset powers (no `ZkReenc`), leaves (inside `hash_cols`) |
| chunked | data, pads, coset powers (`ZkReenc`) (+ twiddles) | chunk coef, chunk expanded, chunk encoded, blake3 state | leaves (inside `commit_zk_chunked`) |
| fallback | as chunked | as chunked, but coef/expanded carry the resident pair's CAPACITIES | leaves |

The blake3 state is now a u64 buffer of `(193·nn + 1) / 2` words (it was
"u32 slots"; same bytes for every power-of-two nn, wrong unit). The 64-buffer
pool cap is inherited from the shared `_Pool`: the 65th drop is a real free
and is reported as one.

*Tests:* `Lifetimes.test_resident_return_state`, `test_chunked_return_state`
(exact live/pooled/freed sets AND bytes), `test_raw_buffers_never_enter_the_pool`,
`test_the_pool_cap_frees_the_65th_dropped_buffer`,
`test_the_blake3_state_is_counted_in_u64_words`. The 13,492.043 MiB
calibration is unchanged by the fix (`column_hashes` still holds pads,
powers and leaves live); only the post-peak stages moved.

### Finding 4 — concrete pending units

*Reported:* `ffn_rows={"W": 100}` became a 100-element, 800-byte buffer
while the API described row counts.

*Change:* `ffn_rows` is REFUSED with a message that says why. The input is
now `ffn_layouts={role: {rows, log_cols, inv_rate, q_pad, path[, chunk]}}`.
A supplied role is expanded into the same buffers, units and lifetimes as
the standalone commit builders (`_commit_buffers`), so "what it includes" is
not a definition to keep in sync — it is the same code: on the chunked path
data + pads + powers are retained to `final_open`, the four scratch buffers
are pooled and the leaves freed at the next event; on the resident path
data + encoded matrix are retained, coef/coef2 pooled, pads/powers/leaves
freed at the next event. A role left out stays symbolic; a bare number, a
partial layout, an unknown key, an unknown role or an unknown path is
refused. The NTT tables stay symbolic unless `ntt_max_log` is given,
because their size follows the largest encoded width in the block —
attention included — and that width is not known.

*Tests:* `PendingBlocks.test_a_bare_row_count_is_refused_never_800_bytes`
(nine malformed inputs; the symbolic report contains no "800"),
`test_a_layout_is_counted_with_the_commit_rules_and_the_rest_stays_symbolic`
(per-event live/pooled/freed for a chunked W, attention still symbolic,
peak still `null`), `test_all_three_layouts_and_tables_are_still_not_a_complete_plan`.

### Finding 5 — reuse identity

*Reported:* a matching resident peak did not validate reuse or later
lifetimes; `take_min` transferring a larger pooled allocation to a smaller
request must be tracked by identity/capacity and not counted twice.

*Change:* the schedule is walked against a simulated pool
(`hashline_memory_plan._Pool`, subclassed only to add `drain`): at each
event, drops first, then a scheduled drain, then births. An exact take
(`pool`) reuses only an equal capacity; a `pool_min` take reuses the
smallest pooled capacity that fits; a reused capacity LEAVES the pool and
is counted once, under the new owner's name, with `origin` naming whose
capacity it was and `capacity_bytes` vs `requested_bytes` both reported.
The additive count with reuse disabled is reported as
`no_reuse_bound_bytes` (or its subtotal twin on incomplete plans). A warm
pool is an `inventory` of capacities. A `fallback_hiding_commit` builder
models CL3's refused resident attempt, and — Codex's CL3 point — refuses to
model a fallback the device cannot take (a second exact `rows·nn` in the
inventory would serve the encoded take before any refusal).

*Tests:* `ReuseIdentity.test_fallback_serves_the_retry_from_the_released_pair_by_capacity`
(coef/expanded reused by name, pooled 0 at the retry, peak equals the
closed form, no-reuse bound larger by exactly the two unallocated requests,
transferred capacities pooled after return under the NEW owners' names),
`test_an_inventory_capacity_is_transferred_and_counted_once` (a pooled
`rows·nn` serves the smaller chunk-coefficient request; equal to the
planner with the same `pool_inventory_bytes`),
`test_pending_reuse_across_roles_counts_capacity_once` (W resident then A
chunked in one block: A's scratch is served from W's coef/coef2 capacities,
each counted once at the A-commit stage), `Lifetimes.test_a_fallback_the_device_cannot_take_is_refused`.

### What this response does NOT change

- **`safe_to_run` is `false` in every report, and `measured` is `false`.**
  The report now also carries an `authorization` string saying so in words:
  a numeric subtotal, even an exact one, cannot authorise a pending private
  block whose mask plan, attention relations and workspaces are not
  implemented. `Authorization.test_no_plan_ever_authorises_a_run` covers
  every builder.
- **Still symbolic, on purpose:** every `attn_*` term (A01 is observed, not
  implemented), `seam_xz_boundary`, `challenge_state`, and the NTT tables
  when `ntt_max_log` is not given. A plan with all three FFN layouts and
  the tables supplied is still `complete: false` and still prints no peak.
- **Still unaccounted (listed in every report):** the mask/claim plan (A03
  acceptance item 1) — a supplied FFN layout is the caller's declaration,
  not the final profile; host-side salts, Merkle trees and proof vectors;
  transfer staging and pinned host buffers; the final opening's own
  re-encode scratch, index lists and gather outputs; CUDA context, modules,
  fragmentation.
- **Modelling choices to know about:** the commit order inside a block is
  W, A, H (declared in `meta.modelled_commit_order`); only reuse is
  order-sensitive, which is why the no-reuse bound is printed beside the
  reuse count. Symbolic retained terms are given the conservative fate
  (pooled until the drain) because their device kind is not known.
- **Cross-owner, not done here:** the two counting tools now share code,
  but `hashline_memory_plan.py`'s resident mode is still a per-phase sum
  rather than a pool simulation; this tool's resident plan IS simulated and
  reconciles with it at every tested shape, so a divergence would show up
  in `test_every_builder_reconciles_with_the_shared_planner` first. A
  `has_exact`-style unreachable-fallback rule also exists in both; if the
  planner's moves, the reconciliation test is the tripwire.
