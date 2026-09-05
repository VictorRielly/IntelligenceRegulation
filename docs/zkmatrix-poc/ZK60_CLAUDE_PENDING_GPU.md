# CL8 — GPU support for the pending private blocks

Task: `zk60_claude_tasks.json` CL8 (`ready_design`). Owner: Claude.
Tool: `scripts/hashline_cl_pending_memory.py` · tests:
`tests/test_hashline_cl_pending_memory.py` (13, green).
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

Per block, before `final_open`:

| buffer | owner | born | released | status |
|---|---|---|---|---|
| `ffn_W_retained` | block *i* | ffn_commit | final_open | concrete when rows supplied |
| `ffn_A_retained` | block *i* | ffn_commit | final_open | concrete when rows supplied |
| `ffn_H_retained` | block *i* | ffn_commit | final_open | concrete when rows supplied |
| `attn_W_retained` | block *i* | attn_commit | final_open | **SYMBOLIC** |
| `attn_A_retained` | block *i* | attn_commit | final_open | **SYMBOLIC** |
| `attn_H_retained` | block *i* | attn_commit | final_open | **SYMBOLIC** |
| `seam_xz_boundary` | block *i* | seam | final_open | **SYMBOLIC** `4*nb_d*base_rows` |
| `challenge_state` | block *i* | seam | final_open | **SYMBOLIC** |

Two blocks double this surface exactly (16 symbolic terms, asserted).

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
  `pending --blocks 1|2`. Opens no device, reads no data.
- `tests/test_hashline_cl_pending_memory.py` — 13 tests: the 13,492 MiB
  calibration, release-is-not-free, drain-actually-frees, chunked-is-smaller,
  and four **rejection** tests (double ownership, release-before-birth, unknown
  event, symbolic byte access) so the tool detects bad plans rather than only
  summing good ones.
- Nothing in Codex's receipt/codec modules was touched.
- When the attention relations land, supply their row counts to
  `pending_private_block(..., ffn_rows=...)`-style inputs and the symbolic
  surface shrinks; `complete` flips to `true` only when nothing is left
  symbolic, and only then is a peak printed at all.
