# A private RUN of L blocks under one transcript — the boundary object, the order, the memory, the receipt, and what privacy would still owe

**Status: REVISED AFTER INDEPENDENT CHECK — accepted as the design to build, subject to `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` (security owner, 2026-09-20). Blocking items B1 … B4, corrections C1 … C13 and conditions O1 … O11 of `ZK60_PRIVATE_RUN_MULTI_BLOCK_CHECK.md` and rulings M-1 … M-8 applied. Paper only: nothing here has been built or run. NOT a privacy acceptance; the privacy checks for a run do not exist yet. Drafted by a delegated Opus agent.**

## Plain words, for a reader who is not a cryptographer

This morning one complete transformer block of a 125M-sized model proved and
verified: 26.5 seconds, a 40.8 MB receipt, 10.6 GB of memory, on the laptop.
A model has twelve such blocks, and each block's output is the next block's
input. This memo works out how to prove all twelve as **one** proof, because
proving them as twelve separate proofs and stapling them together is
forbidden by the project's own rules (a finished proof has already "opened"
its output, and opening the same thing twice is exactly the failure the rules
exist to prevent).

The question that decides everything is what the **handover** between two
blocks looks like. Two designs are possible.

* **A boundary commitment.** The handover values get their own sealed box.
  Block 1 proves "my output is what is in the box", block 2 proves "my input
  is what is in the box", and the box is unsealed exactly once, in the masked
  way the rest of the proof uses. (That this masked unsealing reveals nothing
  is what section 5 says is **owed**, not established — here and for one block
  alike.)
* **A direct comparison.** No box: block 2's proof reaches back into block 1's
  own sealed material and compares the two planes there.

**This memo recommends the boundary commitment**, and the reason is not
memory or speed — those come out nearly the same — but that it leaves the
block we already measured *completely unchanged*. Every counted constant of
the measured block (how many rows it commits, how many slots it runs, how big
its receipt is) stays exactly what it is; the only thing that changes is
which box two of its twenty-three steps point at. The direct comparison moves
those constants for the ten middle blocks and would need three variants of
the block instead of one. It also confines the one genuinely new privacy
question to a small object — a 38-row box — instead of spreading it over the
5,681-row main commitment.

The numbers that come out, all built from this morning's measurements:

| | one block [MEASURED] | twelve blocks, this design |
|---|---|---|
| prove | 26.5 s (+4.7 s to build the witness) | **6.26 minutes** [COUNTED from the measured parts] |
| verify | 1.03 s | **12.5 s**, streaming [COUNTED] |
| peak memory | 10.58 GiB | **10.74 GiB** — one block plus 89 MiB of handover boxes and 69 MiB of the other blocks' public weights [MODEL] |
| receipt | 40.8 MB | **484 MB**, in twelve pieces of ≤ 39.2 MiB [COUNTED] |
| chance a cheating prover gets away with it | about 2^-101 [COUNTED, the project's own per-block accounting, not a measurement] | about **2^-97.5** [COUNTED] — see below |

The memory answer is the important one: **twelve blocks cost the same memory
as one**, because each block's big commitments are opened and thrown away
before the next block's are built, and only the small handover box survives
the crossing. Two things have to be thrown away deliberately for that to be
true: each finished piece of the receipt must be written to disk and released
before the next block starts (holding all twelve would add 423 MiB), and the
twelve blocks' public weights are the one term that does grow with the number
of blocks (69 MiB more than one block's). The receipt has to be cut into
pieces because one file of 484 MB would break the format's own 64 MiB frame
limit; the pieces are tied together by the running hash that the whole proof
is built on, so a piece cannot be dropped, reordered, or taken from a
different run.

**The soundness number, in plain words.** Every proof of this kind has a
small chance that a false statement slips through. For one 125M block the
project's own accounting puts it at about 2^-101; twelve blocks under one
transcript, plus the eleven handover openings, come to about **2^-97.5**
[COUNTED: twelve blocks at 2^-101.1 plus eleven boundary openings at
2^-105.6]. That is the same level — about 97 bits — that the project accepted
by explicit ruling (D3) for the zkVM line. **Whether it is acceptable for the
native line is the project owner's ruling and it is pending**; it does not
block building.

**What this memo does not do.** It establishes no privacy property, at any
shape, for any number of blocks. It names, in section 5, exactly what a
privacy argument for a run would have to prove *in addition* to what the
one-block argument already assumes — and the honest headline there is that
the one-block argument itself relies on a step ("the different sealed boxes
use independent randomness") that has never been proved, only checked by
reading the code. A run makes that step carry more weight, and it adds a new
one: the handover box is claimed by two different blocks, so the two claims
must be shown to reveal nothing *jointly*, not just one at a time. The
project already has a counterexample showing those are different questions.

## 0. What this memo is, what it supersedes, and how its numbers are labelled

**What it is.** A paper design for a private RUN: `L` complete private blocks
proved and verified as one transcript, at the 125M shape (`L = 12`). It
answers seven questions the security owner posed — the boundary object, the
transcript order and soundness, the memory schedule, the receipt, the new
privacy obligations, the D12 amendment, and the build plan — against the real
code on branch `zk60-private-block-125m` (worktree
`/home/victor/wt-zk60-block125m`, read-only for this memo) and the measured
numbers of the 2026-09-20 07:03 run.

**What it supersedes.** `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §8 ("Chaining
twelve blocks") and the attack on it in
`ZK60_PRIVATE_BLOCK_125M_LAYOUT_CHECK.md` §9. Both were written before the
block existed, from a paper model of its memory. Three of their conclusions
change:

1. §8's table ranks a boundary commitment for an internal handover as option
   (i), "forbidden", conflating it with a **caller-fixed endpoint root shared
   by two proofs**. What D12 items 1 and 3 forbid is a *shared, caller-fixed*
   root opened by *two proofs*. A **prover-generated** commitment inside
   **one** transcript, opened **once**, with **one reserved pair per claim
   site**, is not that configuration; it is the same object D12 item 3
   already permits for `xres1`, `nm` and `z16`. §8's (i) and this memo's
   option A are different things, and §8 does not consider the latter.
2. §8's memory model for its preferred option (iii) said 9.6 GiB "with step
   S2 applied", from a paper allocation model. The measured peak of the built
   block is **10.58 GiB** [MEASURED], reached at the softmax zero-check with
   `A` and `H` both resident, and the correct statement for either option is
   that the run's peak is the **one-block peak plus a small additive term** —
   88.8 MiB of IO commitments, plus 6.3 MiB for each of the other blocks'
   public statements, and nothing else **provided each finished segment is
   written out and released** (§3) — because the seam-early order (§8's own)
   keeps `A_k` alive only during block `k+1`'s commit phase, which is
   8.4 GiB, below the peak that comes later anyway.
3. §8 quotes "5–7 minutes modelled". `12 × 26.54 s = 5.31 min` omits the
   witness build, which is **4.69 s per block** [MEASURED] and is not inside
   the prover's phase table. The honest figure is **6.26 minutes**
   [COUNTED: `12 × (26.539 + 4.69) = 374.7 s`, plus 0.22 s of boundary
   commits, 0.17 s of boundary openings and 0.23 s of extra segment encodes
   = 375.4 s], and the same omission should be corrected wherever "about 5.3
   minutes" appears. (The draft of this memo rounded to "6.3 minutes"; the
   independent check recomputed 6.26 and that is the figure used throughout.)

**Labels.** Every figure below is marked:

* **[MEASURED]** — from `results/zk60_block125m_lane/m125-run2-timing.log`
  (one run, shared box, 2026-09-20 08:47) or from the pinned constants of the
  Rust. The source is named at the figure.
* **[COUNTED]** — exact arithmetic from those measurements and from the code's
  own formulas. The draft's counted figures were computed by
  `results/zk60_private_run_multi_block/run_arithmetic.py`, whose output is
  committed beside it as `run_arithmetic.txt`. That script **reproduces two
  published numbers first as a check on its method**: the counted 125M
  receipt (40,782,792 B, `grow_tests.rs` `MODEL_M125`) and the D9 sampler
  residual at both shapes (2^-77.7 at the toy, 2^-72.9 at 125M). Both match.
  **The script is the draft's evidence and is not edited by this revision.**
  The independent check re-derived every one of its figures with
  `results/zk60_private_run_multi_block_check/run_recount.py` and found one
  arithmetic slip (`run_arithmetic.py:309-310` charges a 36-row external
  endpoint **six** mask rows where 36 rows is 32 data plus **four**; §5.3).
  Where this revision's number differs from the script's, the script's line
  is superseded by `run_recount.py` and the text says so at the figure.
* **[MODEL]** — a projection. Stated with the rule it is projected under.

**Standing rule for every step below:** *what does this assume that a later
step concludes?* Where the answer is "something nobody has proved", it is
written down as an obligation and not smoothed over. The memo's value is its
named gaps.

## 1. The boundary object

### 1.1 What the code does today: two external endpoints, one claim each

The built block has four hiding commitments — `A` (5,681 rows), `H` (7,120),
the masking commitment `M` (50), and **two endpoint commitments** of 37 rows
each — and opens each exactly once, in that order
(`private_block/protocol.rs:1-8`, `:674-696`).

An endpoint commitment (`private_block/endpoint_g.rs`) holds the padded
`(t_pad, d_pad) = (512, 1024) = 2^19`-word plane laid out over
`2^19 / 2^14 = 32` data rows, followed by **five** reserved random rows
(`endpoint_g.rs:51`, `:196-207`): the terminal pair at `(data, data+1)`, a
**proximity pair** at `(data+2, data+3)` and **one** spare row at `data+4`.
The second proximity row is **load-bearing, not spare**: `data+2` is the
declared `prox_mask_row` whose proximity rho must be nonzero
(`endpoint_g.rs:206`, `pcs::assert_mask_sites` `:889-890`), and
`check_opening_challenges` additionally requires
`determinant(rho[prox], rho[prox+1]) ≠ 0` (`protocol.rs:266-269`), which is a
condition on `data+3`. So the real budget is **pair (2) + proximity pair (2)
+ one spare (1)**, not "a pair, a proximity row and two further random rows"
as this memo's draft said [CORRECTION C2, verified in the code by the
independent check, §A1.3]. Its claim is raised
by exactly one slot — `SC_IO_IN` (slot 21) for the input, `SC_IO_OUT` (slot
22) for the output:

```rust
SC_IO_IN | SC_IO_OUT => {                          // argument.rs:1425-1432
    let tau = tr.challenge_fp2_vec(sh.log(Dom::D));
    b.eq(&tau, 0);
    b.a(ids.at(if slot == SC_IO_IN { A_X } else { A_X2 }))?;
    b.endpoint(if slot == SC_IO_IN { Cm::In } else { Cm::Out });
    b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1].sub(v[2]))), vec![])
}
```

That is a masked zero-check of `eq_tau(x) · (A_plane(x) − endpoint_plane(x))`
over the whole padded `Dom::D` cube — the *whole* plane, which is what D17
item 1 demands and what S11b's padding argument buys (a padded plane is a
power of two, so no `mu`-batched multi-block claim is needed). The endpoint
tab is built with `mask_row = sh.endpoint_rows − 5`, i.e. the terminal pair
sits immediately above the data rows (`argument.rs:519-523`), and
`build_claim` turns the slot's terminal into **one three-part claim**: the
data slice, plus two mask parts at rows `(mask_row, mask_row+1)` with
coefficients **exactly `(cm, cm·U)`** (`argument.rs:248-262`) — the weight
shape the terminal-surjection review found load-bearing rather than
cosmetic.

The endpoint roots reach the transcript through the **statement**, not
through a root absorb: `ExpectedIo::to_bytes` carries them and the header
absorbs it under `b"expected-IO"` before anything else
(`protocol.rs:91-101`, `private_block.rs:584-593`). That is D18 in code — the
prover seals them at proof time and publishes the roots with the receipt.

### 1.2 Option A — one boundary commitment, two claim sites, one opening

**The object.** For each internal boundary `k` (between block `k` and block
`k+1`, `k = 1..L−1`) the prover commits the padded output plane **once**, to
a commitment `B_k` of its own, and two slots claim it:

* block `k`'s slot 22 (`SC_IO_OUT`) proves `A_k`'s `A_X2` plane equals `B_k`'s
  plane;
* block `k+1`'s slot 21 (`SC_IO_IN`) proves `A_{k+1}`'s `A_X` plane equals
  `B_k`'s plane.

Transitively `A_k.A_X2 = A_{k+1}.A_X` word for word, which is the chaining
statement. `B_k` is opened **once**, in stage `k+1`, with both claims in that
one opening.

**Geometry: rows, pairs, proximity.** One reserved pair **per claim site** is
not negotiable — the known counterexample is two terminals sharing one pair,
where both marginals stay uniform and the *joint* law moves with the witness
(`ZK60_TERMINAL_SURJECTION_REVIEW.md` §3.6, reproduced at real scale: joint
rank drops 4 → 2 and rises back to 4 when the data is added). So `B_k` needs
**two** pairs. For the proximity rows the memo requires a proximity **pair**,
so that the row count is **derived and never accepted**:

```
rows = data + 2·sites + 2          (reserved pairs, then a proximity PAIR)
```

At 125M that is

```
rows 0..31    the padded plane (32 data rows of 2^14 columns)
rows 32,33    reserved pair for the OUT claim  (block k's slot 22)
rows 34,35    reserved pair for the IN  claim  (block k+1's slot 21)
rows 36,37    the proximity pair
              ------------------------------------------------
              38 rows                                  [COUNTED]
```

This is also the budget `endpoint_g` already uses **minus its one spare row**
(§1.1: pair + proximity pair + spare, `rows = data + 5`), not a different
discipline. Two reasons to derive it this way, and the draft gave only the
weaker one:

* it is the geometry `audit_claims` is written for (`protocol.rs:208-252`
  refuses unless `prox + 2 == rows`), so the boundary commitment inherits the
  reviewed pair-exclusivity check verbatim instead of needing a bespoke one;
* **and, the stronger reason, it is a HIDING requirement.** The published
  linear view is `2(G+1)` real dimensions, so hiding needs `2(G+1)` free
  base-field mask coordinates, which with `sites` claim sites plus a
  proximity vector is exactly `2·sites + 2` rows. The independent check
  computed this exactly in Goldilocks arithmetic
  (`results/zk60_private_run_multi_block_check/boundary_rank.py`): at the
  honest 38-row geometry the rank on the reserved rows is **6 of 6,
  disclosed 0**, and the shared-pair control (both claims on pair 0) drops to
  rank 4, disclosed 2, firing in 40 of 40 random draws. **With a single
  proximity row — 37 rows, `data + 2·sites + 1` — the rank is 5, one real
  dimension is disclosed, and `audit_claims` ACCEPTS that geometry** (its
  `prox + 2 == rows` test holds at `rows = 37, prox = 35`). **None of this
  is a privacy result**: it is a rank computation over the group and
  proximity vector channel alone, and it says nothing about the opened
  columns, the salts, the CFS channel or the hash layer (§5.1).

**Therefore the row count is derived, never accepted** [ruling M-1, from
BLOCKING B4]. `boundary.rs` computes `rows` from the plane and the site
count; a caller-supplied row count is refused **by name**; and a test builds
the 37-row geometry and shows it refused (§7.1, §7.2). The rank the gate
reports must be **restricted to the reserved mask rows**: over all 38 rows
every one of these cases has rank 6 and the failure is invisible (§5.1).

`check_endpoint_opening` (`protocol.rs:333-347`), which hard-codes "exactly
one claim of exactly three parts", cannot serve a two-site commitment and is
not asked to: it stays for the existing one-block profiles, untouched.

**The external endpoints keep today's geometry, unchanged** [ruling M-7].
The draft recommended giving the run's two external endpoints the same
construction with `sites = 1` (`rows = 32 + 2 + 2 = 36`). That is withdrawn.
A 36-row external endpoint is **refused by name** by
`private_block.rs:513-515`, which requires a declared `endpoint_rows` of
`data + 5`, and it would move `endpoint_g::MASK_ROWS = 5`, which sits inside
the endpoint spec **digest** (`endpoint_g.rs:51`, `:136`) — two code sites
whose change buys 2,048 B per endpoint and costs the measured single block's
digest its meaning inside a run. So a run has **37-row external endpoints in
today's `endpoint_g` form** and **38-row internal boundaries in the new
two-site form**, and only the internal boundaries use the derived geometry.

**Are the two claims at different points?** Yes, and not merely because the
two slots draw different `tau`: the claim's evaluation point is the slot's
own masked-sumcheck challenge vector `rho` mapped through the tab's
coordinates (`argument.rs:157-166`, `:393`), and the two slots live in two
different blocks' slot loops with different transcript states. The PCS keys
claims by `(point tail beyond the row width, column offset, slice length)`
(`zkp-core/src/pcs.rs:744-791`); the boundary plane's slice is `2^19 ≥ 2^14`,
so `c0 = 0`, `len = n`, and the key is the **last 14 coordinates of the
19-coordinate point**. Two independent points collide there with probability
about `(2/p²)^14 ≈ 2^-1792`. So the opening has **two groups**, and if the
astronomically unlikely collision happened the encoder's declared group count
(2) would not match the formed count (1) and `check_opening` would **refuse**
(`protocol.rs:275-285`) — a completeness failure at 2^-1792, never an
unsoundness.

### 1.3 Option B — a direct equality between two `A` commitments, no boundary commitment

The alternative, and the one `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §8 chose as
its option (iii): no boundary commitment at all. Block `k+1`'s incoming
equality slot binds `A_{k+1}`'s `A_X` plane **directly** to `A_k`'s `A_X2`
plane — one slot, two private tables, on two different commitments. Block `k`
then has no outgoing IO slot at all (for interior `k`).

This is structurally expressible today: a slot's private tables each push a
claim onto their own commitment's list (`argument.rs:390-396`), `build_claim`
already takes the row width from the commitment the plane lives in
(`argument.rs:228-233`, finding S12-F2), and `A_k` has 122 claim sites
already, so a 123rd is not a new kind of thing. What it costs:

* **`A_k` must stay unopened until block `k+1`'s seam slot has run.** Its
  claim list is not final before then. With §8's "seam early" order — commit
  `A_{k+1}`, commit `M_{k+1}`, run the seam, open `A_k`, drop it, *then* draw
  `(β,γ,α)_{k+1}` and commit `H_{k+1}` — the two `A`s are resident together
  only during block `k+1`'s commit phase. Measured decomposition: the whole
  `A` owner is **3,550 MiB** (the RSS drop at `drop(a)`, 8,727 → 5,177
  [MEASURED]); the RSS at the end of block `k+1`'s `A` commit is **5,085 MiB**
  [MEASURED]; so the seam moment is **8,635 MiB** [COUNTED], *below* the
  10,837 MiB peak that arrives later at the softmax zero-check. **Option B
  does not raise the peak** — provided `A_k` is freed before `H_{k+1}` is
  committed. §8's 9.6 GiB and the check's re-derivation both under-modelled
  the one-block peak; the right statement is "the peak is the one-block peak,
  in both options". The independent check tried to break this near-tie and
  could not: it reproduced both measured decompositions and confirmed the
  8,635 MiB seam moment is 2,202 MiB below the peak.
* **"Seam early" is not a reordering of existing slots, it is a different
  slot schedule** [OMITTED CONDITION O2]. `run_slot` refuses unless
  `s == acc.cs.len()` (`argument.rs:289`), so the seam has to **be** slot 0
  of the interior block: the whole `Acc` order, the mask schedule and the
  schedule digest are re-cut, on top of the `N_SLOTS 23 → 22` and
  `M_ROWS 50 → 48` changes counted below, and the LogUp challenge draw moves
  after a slot for the first time in this module. None of that is unsound; it
  is more work than "one fewer slot" sounds, and it counts against option B.
* **It moves the block's counted constants for interior blocks.** Interior
  block `k` loses its outgoing IO slot and block `k+1`'s incoming IO slot
  gains a second private table on a foreign commitment. That changes
  `N_SLOTS` (23 → 22 for interior blocks), hence `M_ROWS = 2·N_SLOTS + 4`
  (50 → 48), hence the mask schedule, the schedule digest, `slot_terms`,
  `a_groups`, `a_rows`, and the receipt arithmetic — for interior blocks
  only, so a run needs **three layout variants** (first, interior, last)
  where option A needs one. Every frozen-count test of the measured block
  would have to be extended to three shapes.
* **It puts the cross-block joint-view question on the 5,681-row `A`.** In
  option A the only object claimed from two blocks is a 38-row commitment
  with two sites; in option B it is `A_k` itself, whose opening also carries
  that block's own 122 sites and 36 groups. Whatever a cross-block
  joint-law analysis has to compute, it is computed on a much bigger object.
* **It interleaves the receipt.** `A_k`'s opening lands inside stage `k+1`,
  so a "segment per block" is no longer a segment per block; the segment
  boundary has to fall in the middle of a stage, and the streaming verifier
  carries block `k`'s whole claim list across it rather than one claim.

It buys, in exchange: **one fewer commitment per boundary** — about 8.2 MB
off a 484 MB receipt, about 1.7% [MODEL: the estimate charges each seam one
extra `A` group and two extra `A` rows, and does not model the slot re-cut,
so the sign is safe and the digits are not] — and 11 × 30 ms of prover time
[MODEL].

### 1.4 The comparison, honestly, and the recommendation

| | A: boundary commitment | B: direct `A_k` ↔ `A_{k+1}` |
|---|---|---|
| peak memory, `L = 12` | 10.74 GiB [MODEL from MEASURED, §3] | ≈ 10.58 GiB plus the same 68.8 MiB of the other blocks' public statements [MODEL from MEASURED], and only with "seam early" and the same segment flushing |
| receipt, `L = 12` | 484.1 MB [COUNTED] | ≈ 475.9 MB [MODEL] |
| per-block layout | **unchanged from the measured block** — same 23 slots, 50 `M` rows, 5,681 `A` rows, 36 groups, 122 sites | three variants; `N_SLOTS`, `M_ROWS`, `a_groups`, `a_rows` all move for interior blocks |
| new code | one module (`boundary.rs`, modelled on `endpoint_g.rs`, ~200 lines), plus run plumbing | a fifth `Cm` target and a fifth `ProverData` pointer, plus three layouts, plus run plumbing |
| commitments per run | `3L + (L−1) + 2` = 49 | `3L` = 36 |
| object claimed by two blocks | a 38-row commitment, 2 sites | the 5,681-row `A`, 123 sites |
| receipt segmentation | one segment per stage, clean | segment boundary inside a stage |
| what "one opening per commitment" needs | unchanged | unchanged |

**Recommendation: option A.** The deciding arguments are not memory (a tie)
and not bytes (option B wins by 1.7%), they are:

1. **The measured block is re-used unchanged.** Every constant this project
   has counted, frozen in tests and reproduced against a Python model stays
   exactly what it is; the run is plumbing plus one new small module. Option
   B re-cuts the block for ten of the twelve positions, which means
   re-counting and re-freezing everything that `grow_tests.rs` pins, for a
   1.7% byte saving.
2. **It confines the new privacy question to a small object.** The one thing
   a run adds to the one-block privacy argument is a commitment claimed from
   two blocks. In option A that is 38 rows × 2^14 columns with two sites and
   three mask-row pairs (98,304 `Fp` of blinding unknowns [COUNTED]); at the
   development rung the same object is 10 rows and 6,144 `Fp`. In option B
   the object claimed from two blocks is `A_k` itself. Both are within the
   exact-rank tools' reach per commitment (§5.4 corrects the assumption that
   they are not), but the *joint* system a cross-block argument must rank is
   where the difference bites, and adding a 38-row, 6-generator block to it
   is not the same as re-opening the 74-generator, 5,681-row one.
3. **Segment-per-stage falls out.** The receipt has to be segmented (§4), and
   option A's stages are self-contained.

Option B should be kept on file as the design to revisit **if** receipt size
becomes the binding constraint (the measurement that would justify it: a
run-size budget under about 480 MB, or a shape where the boundary
commitment's opening is a materially larger fraction than the 0.21% of a
stage it is here) — this is the "simplest first, alternatives documented with
what each is worth" rule, and the worth is 1.7%.

### 1.5 What the single opening batches, and what a second claim does and does not consume

`open_zk` (`zkp-core/src/pcs.rs:915-944`) does exactly this, for any
commitment:

1. `group_zclaims` buckets the claims by column-weight key, in first-occurrence
   order (`:809-831`). The boundary's two claims give two buckets.
2. `zk_rhos` (`:835-856`) draws `lambda` per group member, forms each group's
   row-weight vector `rho_g = Σ_c lambda_c · rw_c`, then draws a **fresh
   proximity `rho` over every row**.
3. `fold_rows_multi_zk` (`:859-875`) folds, for each `rho`, the message rows
   **and the pad block** with the same weights, producing vectors of length
   `n + q = 16,384 + 256`.
4. `assert_mask_sites` (`:881-896`) asserts every group's `rho` touches at
   least one declared mask row and the proximity `rho` touches the declared
   proximity row.
5. The 256 opened column indices are drawn from the transcript **once**, after
   all vectors are absorbed, and the same 256 columns serve every group.

So the single opening of `B_k` publishes **two group vectors + one proximity
vector + 256 columns** instead of one + one + 256. In bytes at 125M:
`(2+1)·16,640·16 + 256·(8 + 38·8 + 32 + 16·32) = 1,017,856 B` [COUNTED],
against `2 × 749,568 = 1,499,136 B` for the two separate 37-row endpoint
commitments a naive per-block form would use.

**Does the second claim consume anything the first did not?** Precisely:

* **Pads: no.** The pad budget is a property of the *commitment*, not of the
  claims: `q_pad = num_col_checks = 256` pads **per row**
  (`pcs.rs:542-544`, `:670`), and the load-bearing condition the surjection
  review identified is **`H-pad`: the pad block must have rank equal to the
  number of distinct opened positions** (`ZK60_TERMINAL_SURJECTION_REVIEW.md`
  §3.5 — "one opened position more than pads: disclosed 2 under brute force,
  0 under the reduction"). The number of distinct opened positions is a
  function of the 256 sampled columns, not of how many claims were folded, so
  a second claim consumes **no pad**. **This holds by construction at every
  shape and for any number of groups, and it is not a margin that can run
  out** [CORRECTION C3]: the opened indices are 256 draws from a single
  `challenge_indices` call serving every group (`open_zk`, `pcs.rs:928`), so
  `distinct ≤ 256`; `q_pad = num_col_checks = 256` and `commit_zk_owned_with`
  asserts `q_pad ≥ num_col_checks` (`pcs.rs:542-543`, `:670`); and the pad
  contribution at an opened position is `Z_n(x_j)·g_pad(x_j)` with `g_pad` of
  256 coefficients on a coset that misses the subgroup
  (`encode_row_zk` `:618-637`, `coset_powers` `:612`), so the map from pads
  to the values at `distinct` distinct positions is a full-rank Vandermonde
  of rank `distinct`. The draft quoted instead a measured margin (246
  distinct positions on `A`, 241–246 on the endpoints, against 256 pads);
  those counts come from **toy** captures where `enc_cols = 1024` and 256
  draws collide often (expected distinct ≈ 226), while at 125M
  `enc_cols = 65,536` and the expected distinct count is ≈ 255.5. Quoting one
  shape's sampling statistics at another is the failure mode D17/G-2 exist to
  prevent, so the empirical margin is **withdrawn**.
* **Reserved rows: yes, two.** One pair per claim site, and the pair must be
  exclusive to that claim *and to its group*.
* **Bytes: yes, one more group vector** — `16,640 × 16 = 266,240 B`.
* **Challenges: yes** — one more `lambda` (and the refusal list grows by one
  zero-`lambda` check; `check_opening_challenges`, `protocol.rs:260-271`,
  takes the per-group member counts, so the boundary passes `[1, 1]`).
* **Privacy analysis: yes, and this is the real cost.** With two groups on one
  commitment the per-group decomposition is only valid if the pairs are
  disjoint **across groups**, and the review found that condition **false on
  `H`** and had to redo `H` as a joint rank over connected components
  (`ts_components.py`; §1.3(a), A2). The boundary's two pairs are disjoint by
  construction — but "by construction" is what `audit_claims` has to enforce,
  and the joint rank over both groups is what the gate has to compute. See
  §5.1.

### 1.6 What `audit_claims` must check for a boundary commitment

`audit_claims(claims, n, rows, site_rows, sum_rows, prox)`
(`protocol.rs:208-252`) applies **verbatim** at
`rows = data + 2·sites + 2` — and it encodes everything needed **about the
claims**, but **not the row count itself** [BLOCKING B4]: its
`prox + 2 == rows` test also holds at `rows = 37, prox = 35`, the
single-proximity-row geometry that discloses one dimension (§1.2). The row
count is enforced by the module that derives it, not here.

| check | line | what it gives the boundary |
|---|---|---|
| `prox + 2 == rows` | `:210` | the proximity pair is the last two rows |
| no claim's part reaches row `≥ prox` | `:220-222` | no claim touches the proximity pair |
| a non-sum claim touches **exactly two adjacent** site rows, aligned to the pair grid | `:237-241` | each claim carries exactly one pair, and a whole one |
| `uses[r] == 1` for every site row | `:248-250` | **no pair is shared between the two claims, and none is left unused** — the pair-exclusivity check the privacy statement calls "the whole defence against a shared pair" |
| zero pair coefficient refused | `:224-227` | `cm ≠ 0`; with `build_claim`'s `(cm, cm·U)` this is the load-bearing weight shape |
| `sum_rows = None` | `:230-243` | the boundary has no zero-sum claim; only `H` does |

Two things must be added around it, both public and both checkable:

* **A declared site schedule for the run.** Which pair each claim uses must be
  fixed by the run schedule, not by the caller: the **OUT** claim (block `k`,
  slot 22) takes pair 0 at rows `(data, data+1)`, the **IN** claim (block
  `k+1`, slot 21) takes pair 1 at `(data+2, data+3)`. Today
  `B::endpoint` hard-codes `mask_row = sh.endpoint_rows − 5`
  (`argument.rs:521`); the run form must take the pair index from the tab's
  **role** (incoming vs outgoing) and the commitment's **site count**, and the
  schedule digest (`lay.schedule_digest()`, absorbed in the header at
  `protocol.rs:99`) must cover it.
* **The declared group count.** `check_opening` compares the formed group
  count against the schedule's (`protocol.rs:275-285`); for a boundary that
  is 2 (external endpoints 1). A mismatch is a refusal.

Both sides run all of this: `check_opening` is called from the prover
(`protocol.rs:680`, `:684`) **and** from the verifier (`:762`, `:769`), which
is what makes it a check rather than an assumption.

## 2. The transcript order and soundness

### 2.1 The run statement and the run header

A run is **one transcript end to end** (the D8/D11 restatement's §2.5, carried
into `ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §3.1). It is also a **new
profile** under D17 — a new profile id, a new parameter line, its own
digests — so no existing byte moves.

The header is built the way `protocol::transcript` builds a block's
(`protocol.rs:91-101`), with the run's quantities in place of the block's,
and **absorbed before any commitment exists**:

```
Transcript::new(run_profile)                       # "…/private-run-m125-L12/1"
  absorb "run-shape"        L, tokens, width, hidden, q_heads, kv_heads, head_dim
  absorb "expected-IO"      E_in root, E_out root, the IO spec (D18: the prover's own seals)
  absorb "public-statement" H(block 1's digest ‖ … ‖ block L's digest)
  absorb "parameters"       the run parameter line (below)
  absorb "calibration"      ONE calibration identity covering every block's
                            calibration and every declared scale of the run
  absorb "schedule"         the run schedule digest (below)
```

* **`"expected-IO"` carries only the run's two external roots.** The `L−1`
  boundary roots are *not* in the statement — they are prover commitments
  absorbed inside the run (§2.2). This is the whole point of the D12
  amendment in §6: an internal boundary is a hidden intermediate, not an
  endpoint.
* **`"calibration"` must cover the whole run** [BLOCKING B3, ruling M-4].
  D12 item 5 is an open finding — declared endpoint scales must be tied to
  the approved calibration, and "today the tag proves nothing": a
  tag-equality check would pass on a factor-of-8 mismatch. A block declares
  two scales; a run declares **thirteen** (`L + 1` IO scales at the 125M
  shape), so a run multiplies the places that hole bites from 2 to 13. Two
  requirements, and they are **correctness** requirements, not privacy ones:
  **a boundary's scale is ONE field, shared by construction between block
  `k`'s output and block `k+1`'s input** — option A gives it exactly one
  place to live, so nothing is *compared* at a boundary — and **the header
  absorbs one calibration identity covering all thirteen declared scales and
  every block's calibration**, not the single block-scope
  `calibration_identity()` of `protocol.rs:98`. Tests (§7.3): a run whose
  block `k+1` declares a different input scale than block `k`'s output scale
  **does not construct**, and a receipt made under one calibration identity
  is **rejected** under another.
* **The parameter line** is the block's (`protocol.rs:106-126`) plus
  `L{L}/boundary-log_n{…}-rate{…}-pad{…}-rows38-sites2/one-run-one-transcript`,
  with the external endpoints' own `endpoint-…-rows37` line unchanged (M-7).
  The security owner's S11b-F4 ruling — that a verifier's geometry inputs must
  appear in a form a human can read, not only inside a digest — applies to the
  boundary geometry exactly as it did to the endpoint's.
* **The schedule digest** must cover the run schedule, not only a block's:
  for each stage, which commitments are absorbed, which claim site (pair
  index) each IO tab uses, and which commitments are opened. A verifier that
  reads the schedule from the receipt rather than from its own statement
  would be reading the prover's choice of geometry; it never does — the
  verifier builds the layout from its caller's shape (`protocol.rs:721-724`)
  and this must hold for the run layout too.
* **Per-stage re-absorb.** At the start of stage `k` the transcript also
  absorbs `k` and block `k`'s own public digest. It is redundant with the
  header's list and it costs two hashes; it buys an explicit, local binding
  of "these slots are block `k`'s weights", and it is what makes the segment
  header of §4.3 checkable at a glance.

### 2.2 The per-stage order, commitment by commitment

Write `B_k` for the boundary between blocks `k` and `k+1` (`k = 1..L−1`),
`B_0 := E_in`, `B_L := E_out`. **Stage `k`** is:

| # | step | why it is here |
|---|---|---|
| 1 | absorb `k`, block `k`'s public digest | locality (§2.1) |
| 2 | **commit `B_k`** (for `k < L`), absorb its root with its rows and row width | `B_k` must be fixed **before any challenge of either adjacent equality slot**. Block `k`'s slot 22 challenges are drawn later in this stage; block `k+1`'s slot 21 challenges are drawn later still. Absorbing earlier is always safe; this is the earliest natural point. |
| 3 | commit `A_k`, absorb root + rows + log-cols | unchanged from `protocol.rs:547-555` |
| 4 | commit `M_k`, absorb root | unchanged; before every slot challenge it masks |
| 5 | draw `(β, γ, α)_k` | **after** `A_k` (which carries the three multiplicity planes) and `M_k`; LogUp soundness requires exactly this |
| 6 | build `H_k`'s helpers, commit `H_k`, absorb root + rows + log-cols | unchanged |
| 7 | run the 23 slots | slot 21 claims `B_{k−1}`, slot 22 claims `B_k`; both commitments already absorbed |
| 8 | open `M_k`; open `A_k`; open `H_k`; **open `B_{k−1}`** | `B_{k−1}`'s claim list is complete: block `k−1`'s slot 22 gave it one claim, block `k`'s slot 21 the other |
| 9 | drop `M_k`, `A_k`, `H_k`, `B_{k−1}` | nothing later claims them |

and stage `L` additionally opens `B_L = E_out` (its only claim came from
block `L`'s slot 22 in the same stage). Stage 1 opens `B_0 = E_in` in step 8
with one claim.

**The two external commitments are made before the header**, not in a stage:
D18 puts their roots in the statement and the header absorbs the statement
(§2.1). So `E_in` exists from before stage 1 and is opened at the end of
stage 1; `E_out` exists from before stage 1 and is opened at the end of stage
`L`, which is why it is resident for the whole run (§3). The `L−1` internal
boundaries are the only IO commitments created inside the run, and that
difference is exactly what §6's amendment turns into a rule.

The order **inside** a stage is the built block's order unchanged
(`protocol.rs:1-8`: A → M → (β,γ,α) → H → slots → M open → A open → H open →
IO opens), with two insertions: the boundary commit at the top and the
incoming boundary's opening at the bottom. That is deliberate: the whole
value of option A is that a stage is the measured block plus two lines.

### 2.3 Can block k be freed before block k+1 is committed?

**Yes — everything except the outgoing boundary commitment.** The reason is a
claim-list fact, not an optimisation: a commitment may be opened once its
claim list is final, and

* `A_k`'s claims come only from block `k`'s own 23 slots (`argument.rs:390-396`
  pushes each private tab's claim onto that tab's own commitment). No slot of
  block `k+1` names `A_k` — in option A, block `k+1`'s slot 21 names `B_k`.
* `H_k`'s claims likewise, plus its own LogUp sum claim (`protocol.rs:288-292`).
* `M_k`'s functionals are block `k`'s 34 (`protocol.rs:675`).

So at the end of stage `k` the only object that must survive is `B_k`, which
the next stage's slot 21 claims and whose opening is the next stage's step 8.
Two boundary commitments are resident during a stage (`B_{k−1}`, awaiting its
opening, and `B_k`, just committed), alongside `E_out`, which is committed
before the header and lives for the whole run: **88.8 MiB** of IO commitments
at 125M [MODEL, §3 — two 38-row boundaries at 29.8 MiB and one 37-row
external endpoint at 29.2 MiB].

Under option B the answer is *no* for `A_k`, which is the whole difference in
§1.3.

**A soundness note on freeing early.** Opening `A_k` before `A_{k+1}` is
committed means `A_{k+1}` is chosen by the prover *after* seeing block `k`'s
opened vectors and columns. That is harmless: the adaptivity a Fiat–Shamir
argument must exclude is a commitment chosen **after** the challenges that
test *it*, and every challenge of block `k+1` is drawn after `A_{k+1}`'s root
is absorbed. It is not harmless for **privacy**, where it is a new surface:
block `k`'s opened vectors are public before block `k+1`'s masks are used
(the layout check's omitted condition O-3). §5.1 carries it as an obligation.

### 2.4 One masking commitment per block, or one for the run?

**One per block.** The constraints the security owner named both survive
either way — `L_s + 256 ≤ 512` is per **row** (`zk.rs:442`: a mask a-row
carries `L_s` coefficients plus `MASK_Q = 256` pads inside `2^MASK_LOG_MSG =
512` message positions), and `n_base = 2·slots + 4` would be `2·276 + 4 =
556` rows of a 4,096-column domain for a whole run, which is 18 MB and fits.
So this is not a feasibility question; it is a "what does it change" question,
and the answers all point one way:

* **Per block, every counted constant of the measured block is preserved**:
  `M_ROWS = 50`, the 34 functionals, the mask schedule, `mask_open`'s
  243,712 B, `zk::mask_verify`'s five checks. A run-wide `M` changes all of
  them and re-opens the CFS analysis at a new geometry.
* **A run-wide `M` would be opened once with functionals from all `L` blocks**,
  which is a **cross-block channel on a single commitment** — precisely the
  kind of object the joint-law argument has never been run on. The CFS stage
  of the gate computes `disclosed_s` per slot over the mask coefficients; a
  shared `M` makes the slots of different blocks share a commitment's
  blinding, and the per-block decomposition would have to be re-argued.
* **It would force all `L` blocks' CFS masks to be drawn at the run's start**
  and held to the end — small in bytes, but it means the mask material of
  block 12 exists while block 1 is being opened, for no gain.
* The saving is `11 × (32 + 243,712) = 2.7 MB` of a 484 MB receipt, 0.55%
  [COUNTED].

**Recommendation: one `M` per block, and record the reason as a privacy
reason and not a byte reason.**

### 2.5 One LogUp challenge triple per block

**Forced, not chosen.** `(β, γ, α)_k` must be drawn after `A_k` (which
carries the three multiplicity planes `A_MU8`, `A_MEXP`, `A_MACT`,
`protocol.rs:520-524`) and before `H_k` (whose helper columns are
`1/(α − …)`, `protocol.rs:576-590`). A single triple for the whole run would
have to follow `A_L`, which is committed in stage 12 — after `H_1` has
already been built and opened. So the run draws **`L` triples, one per
stage**, each in step 5. The three domain tags `TAG_U8/TAG_EXP/TAG_ACT`
(`tables_attn.rs`) keep the three tables separated inside a block; nothing
new is needed to separate blocks, because each block's helpers are checked
against that block's own `α`.

### 2.6 The three public tables

The byte table, the exponential table and the activation table are **public
and are not committed at all** — both sides evaluate them from the public
statement (`argument::table_values_u8/exp/act`, called at
`protocol.rs:614-618`). They reach the transcript only through the
`"public-statement"` digest. So:

* **Absorbed once per run**, inside the header's digest over the `L` block
  public statements (and again per stage in the redundant re-absorb of §2.1).
* **Nothing is committed or re-committed per block.** What *is* per block is
  the three **table helper columns** on `H_k` (`protocol.rs:613-623`), because
  they are `multiplicity / (α_k − table value)` and depend on that block's
  `α_k` and `β_k`. That is unavoidable and is already counted in `H`'s rows.
* If all `L` blocks share one activation table and one exponential table — as
  a real checkpoint does — the run header's digest is over `L` public
  statements that repeat those tables. Deduplicating them is a **statement
  encoding** question with no effect on the proof; do not deduplicate before
  the first run works, and if it is ever done, the digest must still cover
  each block's table **by reference**, so that no block can silently use a
  different table.

### 2.7 Every challenge, and what it must follow

The obligation is that **every challenge is drawn after everything it must
bind**. Stage `k`'s challenges, in transcript order, with what each must
follow:

| challenge | drawn at | must follow | does it? |
|---|---|---|---|
| `(β, γ, α)_k` | step 5 | `A_k` (multiplicities), `M_k` | yes, steps 3–4 |
| slot `s`'s CFS multiplier `c` (`argument.rs:310`) | step 7 | `M_k` (the mask it multiplies), `A_k`, `H_k` | yes |
| slot `s`'s `tau` / definition challenges (`argument.rs:1426`) | step 7 | the commitments the slot reads: `A_k`, `H_k`, **and `B_{k−1}` / `B_k` for slots 21/22** | yes — `B_{k−1}` was absorbed in stage `k−1` step 2, `B_k` in this stage's step 2 |
| slot `s`'s sumcheck round challenges `rho` | step 7 | the same | yes |
| the extension challenges `e` | step 7 | the same | yes |
| `M_k`'s opening challenges (`theta`, proximity rhos) | step 8 | all 34 functionals, i.e. all 23 slots | yes |
| each opening's group `lambda`s and proximity `rho` (`pcs.rs:835-856`) | step 8 | that commitment's root and all its claims | yes |
| each opening's 256 column indices (`pcs.rs:928`) | step 8 | that opening's group and proximity vectors | yes, inside `open_zk` |
| **`B_{k−1}`'s `lambda`s and column indices** | step 8 of stage `k` | `B_{k−1}`'s root (stage `k−1`) **and both its claims** — block `k−1`'s slot 22 and block `k`'s slot 21 | **yes, and this is the new one**: it is why `B_{k−1}` is opened in stage `k` and not in stage `k−1` |

Two properties worth stating because they are the ones a reviewer should
attack:

1. **The boundary commitment is fixed before either block that claims it is
   proved.** `B_k` is absorbed in stage `k` step 2, before block `k`'s slots
   and long before block `k+1`'s. The binding requirement is only that `B_k`
   precede **slot 21's and slot 22's challenges**; the draft also said the
   order of step 2 before step 3 stops a prover adapting the boundary to
   block `k`'s challenges, and that reason is **over-strong and withdrawn**
   [CORRECTION C4] — no challenge is drawn between steps 2 and 3, so `B_k`
   before `A_k` and `A_k` before `B_k` are equally sound. Step 2 stays where
   it is because it is the earliest natural point, not because soundness
   forces it.
2. **No commitment is opened before its claim list is final, and none is
   claimed after it is opened.** `B_{k−1}` is the only commitment whose claim
   list spans two stages, and its opening is placed after the later of the
   two. A mechanical check asserts this at run-definition time, and a run
   schedule that opens `B_k` in stage `k` — before block `k+1`'s claim
   exists — must be a **prover-side refusal naming the commitment**, not an
   incorrect proof. §7.3 pins it as an acceptance test [OMITTED CONDITION
   O9].

### 2.8 The run's soundness error

[BLOCKING B1, ruling M-2. The draft titled this section "soundness" and gave
no soundness figure; that is repaired here, and the figure is repeated
wherever the run is described.]

The project's own accounting for one 125M block is **2^-101.1**
(`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md:510` — four PCS openings at 2^-103.61
union, plus the dominant LogUp term `N/|F_p²| = 2^-101.37` at 103.8M
lookups), and **2^-105.61 per PCS opening**
(`ZK60_PRIVATE_BLOCK_125M_LAYOUT_CHECK.md:1102`). A run is a union bound over
its blocks and its extra boundary openings:

```
twelve blocks           12 × 2^-101.10  = 2^-97.52
eleven boundary opens   11 × 2^-105.61  = 2^-102.15
                                        -----------
RUN, L = 12, 125M geometry              ≈ 2^-97.46     [COUNTED]
```

Three things a reader is owed:

* **About 97 bits.** That is the same level the project accepted **by
  explicit ruling** (D3, "97-bit conjectured accepted") for the zkVM line.
  **Whether about 2^-97.5 is acceptable for a native-line run is the project
  owner's ruling, and it is pending** (§8.1, R-D12; the disposition files it
  with D15's open question). It does not block building, and it must not be
  inherited silently.
* It is 3.6 bits worse than one block and it degrades as `log2 L`: an 8B
  model's 32 blocks would be about 2^-96.1 at this per-block level [COUNTED].
* The figure belongs in the run's statement and in any report of a run, next
  to the time and the receipt size, with this label.

## 3. The memory schedule on a 15 GB host

All of the following comes from the RSS and HWM columns of
`results/zk60_block125m_lane/m125-run2-timing.log` (one run, shared box,
under a 12 GiB ceiling, CPU only).

**What the measured block does, phase by phase** [MEASURED, MiB]:

| phase | RSS | HWM | what is resident |
|---|---|---|---|
| setup | 687 | 708 | witness planes (711 MB) |
| `A`: allocate + planes → rows | 1,397 | 1,397 | + `a_data` (745 MB) |
| `A`: lookup values + histogram | 2,128 | 2,128 | + `looked` (789 MB) |
| `A`: mask + proximity rows | 2,168 | 2,168 | + deltas, act indices |
| **`A`: commit** | **5,085** | 5,085 | + `A` encoded (2.98 GB) + tree |
| `M`: commit | 5,085 | 5,085 | + 18 MB |
| `H`: helper inverses | 6,031 | 7,054 | + `H` data, transient inverse buffers |
| `H`: the S2 drops | 5,039 | 7,054 | − witness, `looked`, deltas, indices |
| **`H`: commit** | **8,615** | 8,615 | + `H` encoded (3.73 GB) |
| slot 17, **softmax zero-check** | 8,727 | **10,837** | `A` + `H` + the 8.4 M-entry slot tables ← **the peak** |
| open `A`, drop | 5,177 | 10,837 | `A` owner freed: **3,550 MiB** |
| open `H`, drop | **727** | 10,837 | `H` owner freed: **4,450 MiB** |

Two numbers matter for a run: the **peak, 10,837 MiB (10.58 GiB)**, and the
**resident set between blocks, 727 MiB** — after the openings essentially
nothing of a block survives.

**What an IO commitment costs.** Same allocation rule as any hiding
commitment (`pcs.rs:665-699`: `data`, `encoded`, `pads`, `salts`, `tree`),
at `n = 2^14` and rate 1/4 [MODEL, from the measured rule]:

```
                     38 rows (a boundary)     37 rows (an external endpoint,
                                              today's endpoint_g form, M-7)
data      rows × 16,384 × 8    4,980,736 B                      4,849,664 B
encoded   rows × 65,536 × 8   19,922,944                        19,398,656
pads      rows ×    256 × 8       77,824                            75,776
salts     65,536 × 32          2,097,152                         2,097,152
tree      ~2 × 65,536 × 32     4,194,304                         4,194,304
                             ------------                      ------------
                               29.8 MiB                           29.2 MiB
```

(The draft costed a 36-row external endpoint at 28.6 MiB. M-7 keeps today's
37 rows, so the endpoint figure is 29.2 MiB and every total below moves with
it.)

**The run's peak.** Under §2.2's order, stage `k` holds exactly what the
measured block holds, plus **three** IO commitments: `B_{k−1}` (awaiting its
opening), `B_k` (just committed), and `E_out` — which is committed **before
the header**, because D18 puts its root in the statement, and therefore
lives from the run's first byte to its last opening. (`E_in` is in the same
position but is opened at the end of stage 1.)

Two further things are alive in a run that a single block never had, and the
draft counted neither [BLOCKING B2, CORRECTION C5, ruling M-3]:

* **the other blocks' public statements.** `AttentionPublic` and
  `FeedForwardPublic` hold their weights as `Vec<i8>`
  (`private_block.rs:226-233`, `:347-352`): at `d_pad = 768`, `f_pad = 2048`,
  `kv = 256`, `t = 512` that is `2·768² + 2·256·768 + 768` attention int8
  plus `768 + 2·768·2048 + 2048·768` feed-forward int8 = 6,292,992 B, plus
  264,192 B of `i64` rope/exp tables = **6.3 MiB per block**. Twelve are
  75.0 MiB, of which **+68.8 MiB** is new relative to the measured block.
  (The alternative is to stream statements per stage and make *that* an
  invariant; the run driver does not, so the term is counted.)
* **the finished segments, and this is the big one.** A stage ends at 727 MiB
  resident, of which about 40 MB is that stage's `Receipt`. A driver that
  accumulated segments and wrote at the end — the obvious first
  implementation — would hold eleven finished segments at stage 12's peak:
  **+423 MiB**.

**Invariant of the run driver, not an optimisation: each segment is
serialised and its `Receipt` released before the next stage begins.** The
`L = 2` gate asserts it (§7.3).

```
IO resident, interior stage = 29.8 + 29.8 + 29.2 = 88.8 MiB   (B_{k−1}, B_k, E_out)
IO resident, stage 1        = 29.2 + 29.8 + 29.2 = 88.2 MiB   (E_in, B_1, E_out)

PEAK(L = 12) = 10,837 MiB                        measured one-block peak
             +     88.8 MiB  IO commitments
             +     68.8 MiB  eleven extra public statements
             = 10,995 MiB = 10.74 GiB                    [MODEL from MEASURED]

unflushed variant (segments held to the end):
             + 423 MiB = 11,418 MiB = 11.15 GiB  — what flushing avoids
```

11.15 GiB is still inside the 12 GiB ceiling the measured run used, but it is
480 MiB of margin given away for nothing, and on the WSL box an
out-of-memory event freezes the whole machine.

**It grows with `L` only through the statements.** The carry across a stage
boundary is one boundary commitment (29.8 MiB) plus `E_out` (29.2 MiB,
constant for the whole run), the transcript state (32 bytes + an 8-byte
counter, `transcript.rs:17-22`), one pending `ZClaim` (three parts and a
19-coordinate point, about 1 KB), and the run statement — whose weight term
is the 6.3 MiB per block counted above. Nothing else.

**Per-stage high-water marks are recorded from the first multi-block run
onwards** [OMITTED CONDITION O3, ruling M-3]. The two big buffers (`A`
encoded 2.78 GiB, `H` encoded 3.47 GiB) are single allocations far above
glibc's mmap threshold and are returned to the OS on free, so they cannot
fragment the heap; the risk is the many medium buffers (slot tables of 8.4 M
entries, the LogUp helper columns) cycling twelve times. The sign that would
show it is the HWM **per stage**: if HWM(stage 2) exceeds HWM(stage 1) by
more than the 29.8 MiB of one extra boundary, fragmentation is real and the
ladder stops. R3 and R6 print and assert it (§7.3, §7.6).

(`E_out` could in principle be committed late and its root back-filled into
the statement — it must not be. The root is absorbed in the header, so
committing it late would mean re-deriving the same commitment from stored
randomness, which is exactly the consume-by-value, fresh-entropy discipline
the endpoint types exist to prevent. 29.2 MiB is not worth that.)

**What would break it** — the failure modes to watch, each with the sign it
would show:

1. **Two blocks' `A` or `H` resident at once.** Option B does this
   deliberately and gets away with it only because the overlap (8,635 MiB
   [COUNTED]) is below the peak; an implementation that opened `A_k` *after*
   committing `H_{k+1}` instead of before would sit at
   `3,550 + 8,615 = 12,165` MiB plus slot tables — **over the 12 GiB ceiling
   the measured run used and within a gigabyte of the box**. This is the one
   ordering mistake that turns a working run into a dead box (and on the WSL
   laptop an out-of-memory event is a whole-box freeze, not a process kill).
   Option A cannot make this mistake, because nothing of block `k` is alive
   to be held.
2. **Deferring boundary openings.** If `B_k` were opened at the *end of the
   run* instead of in stage `k+1`, all `L−1` boundary commitments would be
   resident: `11 × 29.8 = 328 MiB`. Survivable, but it buys nothing and it
   breaks segment-per-stage.
3. **Holding the witness across stages.** The witness build peaks at 708 MiB
   [MEASURED] and the S2 drops release 1.5 GB mid-stage
   (`protocol.rs:591-612`). A run driver that built all `L` witnesses up
   front would add `12 × 711 MB = 8.5 GB` and not fit. Build block `k`'s
   witness at the top of stage `k`, from the plane the prover already holds.
4. **The prover's own forward pass.** The honest prover must know all `L`
   boundary planes to commit them. Each padded plane is
   `512 × 1024 × 2 B = 1 MB` as `i16` (`12 MB` for the run) — negligible, but
   it must be held for the whole run, and it is the most sensitive material
   in the process. It belongs behind the same no-`Clone`, no-getter,
   consumed-by-value discipline as `PreparedPlaneG` (`endpoint_g.rs:144-162`).
5. **Accumulating the finished segments** [BLOCKING B2]. Eleven held
   `Receipt`s are **+423 MiB** and take the modelled peak from 10.74 GiB to
   11.15 GiB. The sign is an RSS that steps up by about 40 MB at the end of
   every stage instead of returning to the between-blocks level. The repair
   is the invariant above: serialise the segment, release the `Receipt`,
   then start the next stage.

**Operating conditions** are the measured run's, unchanged: detached, the
heavy lock held, a memory ceiling on the process that kills the process and
not the box, nothing else building.

## 4. The segmented receipt

### 4.1 Why segmentation is forced, and where the segment boundary goes

`wire.rs` bounds a frame two ways: `MAX_WIRE_BYTES = 4 MiB` for the frozen
toy, and `MAX_WIRE_BYTES_ANY = 64 MiB` as the ceiling **any** profile's frame
must fit, with each profile additionally bounded by its own counted receipt
length (`wire.rs:20-45`). A 484 MB run receipt cannot be one frame, and
raising the ceiling would be the wrong repair: the bound exists so that
nothing read from a frame controls an allocation, and a verifier that has to
hold half a gigabyte before it can check anything is a verifier nobody can
run in a constrained place.

**The segment is the stage.** Segment `k` carries exactly the bytes the
transcript gains during stage `k`:

```
segment k = header
          | B_k root (k < L)
          | A_k root | M_k root | H_k root
          | 23 slot proofs (scalar, sumcheck rounds, terminals)
          | M_k opening | A_k opening | H_k opening | B_{k-1} opening
          | (stage 1 only: E_in opening)   (stage L only: E_out opening)
          | trailer
```

This is the existing per-block frame (`wire.rs:87-94`, `:123-151`,
`:196-229`) with the endpoint openings replaced by boundary openings and a
header/trailer added. Everything the decoder needs to size a field still
comes from the **layout**, never from the frame — the run layout is a
function of the run shape and `L`, both of which the verifier has from its
own statement.

**The wire module needs a per-segment length and a per-segment bound**
[OMITTED CONDITION O4]. `wire::decode` requires `bytes.len() ==
encoded_len(lay)` exactly (`wire.rs:197`) and `wire_bound(lay) =
min(receipt_bytes().total, 64 MiB)` (`:38-45`). A run has **three** distinct
segment lengths (first, interior, last), so it needs
`encoded_len_segment(lay, k, L)` and a bound taken per segment. Left as is,
`receipt_bytes()` for a run profile would return 484 MB and the `min` would
clamp the bound to 64 MiB — the right answer for the wrong reason, which is
the kind of coincidence that stops being right at the next shape. R3 states
it explicitly (§7.3).

### 4.2 Sizes

[COUNTED. The per-opening and per-segment body figures are
`run_arithmetic.py`'s, which first reproduces the block's counted
40,782,792 B from `wire.rs`'s own formula and which the check's
`run_recount.py` reproduced to the byte. **Two things move them**: the
framing is counted once, at the 136 B §4.3 specifies and not at the 40 B the
draft counted (CORRECTION C7, ruling M-6), and the external endpoints keep
their 37-row `endpoint_g` form (M-7).]

| | bytes | note |
|---|---|---|
| boundary opening (2 groups, 38 rows) | 1,017,856 | vs 1,499,136 for two 37-row endpoint commitments |
| external endpoint opening (1 group, 37 rows) | 749,568 | today's `endpoint_g` form, unchanged (M-7) |
| segment framing | 136 | 96 B header (§4.3) + 40 B trailer, counted in every segment below |
| segment 1 | 40,033,352 | opens `E_in` |
| segments 2 … 11 (each) | 40,301,640 | opens `B_{k−1}` |
| segment 12 | 41,051,176 | opens `B_11` and `E_out` |
| **largest segment** | **41,051,176 (39.15 MiB)** | **fits the existing 64 MiB frame bound** |
| **run total, `L = 12`** | **484,100,928 (484.1 MB)** | vs `12 × 40,782,792 = 489.4 MB` as separate receipts |

**One framing, counted once** [ruling M-6]. The draft's table counted each
segment with `wire::HEADER`'s 40 bytes (magic 8 + binding digest 32) while
§4.3 specified a 96-byte header and a 40-byte trailer — +96 B per segment
over what was counted. Immaterial in bytes; material as a gate, because R6's
acceptance demands an exact segment length and an honest run built to §4.3
would have failed it by 96 bytes per segment. The figures above are the
specified framing, and **they are the figures R6's byte-exact acceptance
uses** (§7.6).

The boundary openings are **0.21% of a stage**. The dominant terms are
unchanged: `A`'s opening 21,626,880 B and `H`'s 17,385,472 B, i.e. 96% of
every segment is the two big commitments' 256 opened columns and their group
vectors.

**The 484 MB is a product fact, not a blocker** [ruling M-6]. The contract's
proof-size budget is 256 KB, the one lever that would shrink a receipt
cannot run privately (D10, declined), and an 8B model's 32 blocks at a
larger width would be several gigabytes. **Who stores a half-gigabyte
receipt, who transfers it and what the MVP promises about it is the project
owner's question**; it is recorded on his page as a deviation (§8.1, R-D13)
and it does not block building.

**Verifier time and memory** [COUNTED from MEASURED]: `12 × 1.027 s = 12.3 s`
of verification **plus `12 × 0.015 s` of decoding = 12.5 s wall**
[CORRECTION C6: quote 12.5 s, of which 12.3 s is algebra]. The measured
verifier's RSS while verifying a decoded 40.8 MB receipt is **727 MiB**
[MEASURED], and a streaming run verifier holds one segment at a time, so it
stays at about that — **not** 484 MB. It additionally needs block `k`'s
public weights during stage `k` (about 7 MB of `int8` at this shape, from its
own copy of the statement, streamable).

### 4.3 What binds the segments together

**The transcript does, implicitly**: every challenge in segment `k+1` is
squeezed from a BLAKE3 chain value over *all* bytes absorbed in segments
`1..k` (`transcript.rs:44-52`, `:85-94`). Drop, reorder, or splice a segment
and every later sumcheck and every later opening check fails. That is the
real binding, and it is why a run is one transcript.

**But a verifier should refuse by name, not by symptom.** Four explicit
checks, all cheap:

1. **Segment header** = magic `HLPRUNS1`, the run profile id's digest, `L`,
   the segment index `k`, and the **32-byte transcript state plus the 8-byte
   squeeze counter the verifier must already be at**. The verifier compares
   against its own running `tr.state()` / counter (`transcript.rs:133-142`)
   and refuses on mismatch, before parsing a single field element. A segment
   from another run fails here on its state field, because the two runs'
   chains differ from the header on (fresh `E_in`/`E_out` commitments, fresh
   salts). The transcript state is exactly 32 bytes plus a `u64` counter and
   nothing else (`transcript.rs:17-22`, `clone_state` `:139-141`), so the
   40-byte state field is the *whole* state and comparing it is meaningful.
   **Two conditions on the framing** [OMITTED CONDITION O5]: the header and
   trailer are **never absorbed** into the transcript — they sit outside the
   Fiat–Shamir chain, because a state field cannot predict a hash of
   itself — and the verifier **compares, never adopts**. A verifier that
   seeded its transcript from a header would accept any prover-chosen chain;
   a verifier handed only segment 3 refuses, because its own state after the
   run header is not segment 3's. (The state is a hash of published bytes
   only — roots, masked scalars, masked round polynomials, masked group
   vectors, opened columns — so it is a deterministic function of the receipt
   and adds no channel; that is the same argument that lets the receipt be
   published at all.)
2. **Index discipline**: the verifier accepts segments in order `1..L` and
   refuses a repeat, a gap or an out-of-range index. **`L` is the verifier's
   own**, from its statement, never the frame's, and it checks that it
   consumed **exactly `L`** segments (ruling M-6). A prover asserting a
   shorter run is proving a different statement under a different
   transcript.
3. **Segment trailer** = the transcript state and counter at the end of the
   stage, compared with the verifier's own after it has absorbed everything.
   This localises a corruption to one segment instead of surfacing it as an
   inscrutable failure three segments later.
4. **Run closing check**: after segment `L`, the verifier checks that it
   consumed exactly `L` segments, that the final transcript state equals the
   final trailer, that **every commitment it absorbed was opened exactly
   once** and **every claim it accumulated was discharged by an opening** —
   the run-level statement of "one opening per commitment", which at block
   scope is today an invariant of the code rather than something a verifier
   checks (the D8/D11 restatement notes exactly this: "a verifier cannot
   check that from the bytes"). At run scale it becomes checkable and
   should be checked: the verifier maintains a small table of absorbed roots
   and pending claims and requires it to be empty at the end.

Check 4 is the only genuinely new verifier obligation, and it is worth its
few lines — but **it is a regression guard on the verifier's own code path,
not an upgrade from a promise to a check** [CORRECTION C8]. The run layout —
which commitments exist and where each is opened — is a function of the
verifier's **own** statement and `L`, exactly as the block layout is today
(`protocol.rs:724`; `wire.rs:196-199` takes every count from `lay`), so a
prover cannot present a different set of commitments or openings without
changing a frame length or the chain. A second opening performed *outside*
the transcript stays invisible, and a second opening *inside* it is a
schedule the verifier does not have. Keep the check; drop the claim that it
makes "one transcript" enforced rather than promised.

### 4.4 What the verifier keeps between segments, and what it must check at the end

Between segment `k` and segment `k+1` the verifier keeps:

| object | size |
|---|---|
| transcript state + squeeze counter | 40 B |
| `B_k`'s root, rows, row width, site schedule | ~64 B |
| block `k`'s slot-22 claim on `B_k` (3 parts, a 19-coordinate point) | ~1 KB |
| the run statement (its own copy: `L`, shape, `E_in`, `E_out`, the `L` public digests) | `L × 32 B` + the shape |
| the open-commitment table of check 4 (at most 2 entries) | ~128 B |

Under 2 KB plus the statement. The block's public **weights** are needed only
during their own stage.

At the end it checks: all `L` segments seen in order; final state matches;
the open-commitment table empty; `E_in` and `E_out` are the roots its own
statement names (they are absorbed in the header, so a mismatch is caught at
segment 1's state check, but the explicit comparison is worth its two lines);
and the run profile id is the one it expected. Only then does it accept —
and what it accepts is what §6's amendment says a run proves, no more.

**A verifier that stops after segment `k` knows NOTHING about the run**
[OMITTED CONDITION O6]. After `k` segments it has seen `k` blocks' slot
relations discharged against commitments, but `B_k` is unopened — so even
block `k`'s own output relation is not closed — `E_out` is unopened, and the
statement being proved is a property of the whole chain. **A partial run is
not a proof of a prefix of the run**, and no partial result may be quoted as
one. (This is also why a dropped last segment is refused three times over:
`B_{L−1}` unopened, `E_out` unopened, and the segment count wrong. The
primary refusal is the count, not the empty open-commitment table.)

## 5. Privacy: what is new relative to one block, stated as obligations

**Nothing in this section claims a privacy property.** Nothing about privacy
is established at the 125M shape for even one block; the checked argument
exists for **one toy block** and is itself a draft awaiting three rulings
(`ZK60_PRIVACY_STATEMENT_TOY_PROFILE_DRAFT.md`, status line: "not in force").
What follows is the list of things a run would owe *in addition*, written so
that each can be assigned.

### 5.1 (a) The boundary plane: one hidden intermediate, two relations, two claim sites

The one-block argument has five steps: the all-zero witness is admissible;
per commitment the linear view discloses nothing; the gate constructs
blinding reproducing each captured view; **at fixed challenges the joint law
of all published field values is input-free**; the hash layer adds nothing
and the fixed-challenge theorem lifts. A run changes the fourth step and
stresses one of its hypotheses. Five obligations, in the order they bite —
four of them privacy obligations, the fifth (O-R8) a **correctness**
obligation this section originally missed altogether.

**O-R1. The boundary commitment's two groups must be ranked JOINTLY, and its
two pairs must be disjoint across groups as well as across claims.** The
terminal-surjection review's §1.3(a) is explicit that the per-group
decomposition "needs the reserved pairs to be disjoint *across groups*, not
only across claims — true on `A`, `Input`, `Output`; **false on `H`**", where
two groups share the zero-sum rows and the answer had to be recovered by a
joint rank over connected components (`ts_components.py`). The boundary's two
pairs are disjoint by construction and `audit_claims` enforces it (§1.6), so
the per-group decomposition is *expected* to be valid — but "expected" is the
word that has already cost this project one correction, and the gate must
compute the boundary's rank **jointly over both groups** and report it, not
sum two marginals. The object is small: at 125M, `2(2+1) = 6` generators over
38 rows; at the rung, 6 over 10 rows.

**The rank is computed RESTRICTED TO THE RESERVED MASK ROWS, and the report
must say which columns it ranked** [OMITTED CONDITION O10, ruling M-1].
Over all 38 rows every case below has rank 6 and the failure is invisible —
the same artefact the terminal-surjection review recorded as "rises back to 4
when the data is added". The independent check's exact Goldilocks model
(`results/zk60_private_run_multi_block_check/boundary_rank.py`) gives the
three numbers the gate must reproduce, for the linear-view channel only:

| case | rows | rank on the reserved rows | disclosed |
|---|---|---|---|
| honest: two claims, disjoint pairs, proximity **pair** | 38 | 6 of 6 | 0 |
| control: both claims on pair 0 | 38 | 4 | 2 (fires 40/40) |
| control: a single proximity **row** (`data + 2·sites + 1`) | 37 | 5 | **1 — and `audit_claims` accepts it** |

The third line is why the row count is derived and not accepted (§1.2, M-1):
the audit does not enforce the hiding geometry, so the module must.
**This is not a privacy result** — the model covers the group and proximity
vector channel only, and says nothing about the opened columns, the salts,
the CFS channel or the hash layer.

Two facts make this the cheapest new check in the project, and both should be
said out loud because they are unusually favourable:

* each of the boundary's groups is a **singleton** (one claim per group), and
  the joint-view gate's shared-blinding negative control "fires only at tight
  (singleton-group) positions" (`ZK60_NATIVE_JOINT_VIEW.md` §12.5, quoted in
  `ZK60_JOINT_LAW_COMPOSITION_CHECK.md:870`) — so the control that is blind
  elsewhere is exactly sharp here;
* the counterexample the whole rule exists for (two claims, one pair) is
  *reproducible on this object directly*: point both slots at pair 0 and the
  joint rank must drop while both marginals stay full. That is the headline
  negative control of §7.

**O-R2. Cross-block independence of blinding — the hypothesis the one-block
argument already assumes and never proves.** The terminal-surjection review
says it in one sentence (§6): "**Cross-role independence.** That `A`, `H` and
the two endpoints draw disjoint randomness is condition O-2 of the
composition memo, verified in the code there and not re-verified here; my
per-commitment computations assume it." The joint-law disposition rests the
whole product law on it: "independent per-role blinding gives the product law
directly". A run multiplies the number of roles by `L` and adds `L−1`
boundaries, so the same unproved hypothesis carries `49` commitments instead
of `4`.

What the code does today: `prove_inner_at` creates **one** `ZkRng::from_os`
per proof (`protocol.rs:475`) and every mask row, pad and salt of `A`, `H`,
`M` comes from that one stream, while each endpoint plane draws its **own**
`ZkRng::from_os` inside `endpoint_g::prepare` (`endpoint_g.rs:193`). So both
patterns are already in use, and "independence" today means "distinct
positions of one CSPRNG stream" for three of the four commitments.

**Recommendation: one `ZkRng::from_os` per COMMITMENT for the run** — per
block (its `A`/`H`/`M`, as now) and per boundary commitment (as
`endpoint_g::prepare` already does). Then cross-block independence rests on
operating-system entropy rather than on stream separation inside one
generator, the one-block argument applies to each stage verbatim, and the
named assumption in the privacy statement ("the prover's randomness
generator's output stream is indistinguishable from uniform") is not asked to
do new work at `L = 12`. The cost is `L + (L−1)` extra OS reads. **What this
does not do:** it does not *prove* O-2; it makes the thing O-2 assumes as
close to unconditional as the platform allows, and leaves the proof owed.

**O-R3. The run-wide joint law, and the new hiding surface the order
creates.** The fourth step must be restated for a run: *at fixed challenges,
the joint law of every field value the whole run publishes — all `L` blocks'
group vectors, proximity vectors, terminals and opened columns, and all
`L−1` boundary openings — is the same for every admissible hidden input.* Two
things are new:

* **Sequencing.** Block `k`'s opened vectors and columns are public **before
  block `k+1`'s masks are used** — the layout check's omitted condition O-3,
  which it raised for option B and which is equally true of option A (the
  stages are sequential either way). The fixed-challenge formulation absorbs
  this correctly *if* the blinding is independent across commitments
  (O-R2): conditioned on the challenges, each commitment's published vectors
  are a function of its own blinding and its own data, so the law factorises.
  **This is the shape of the argument, not the argument.** Nobody has written
  it, and the step it leans on is the one the review declined to re-verify.
* **The boundary appears in two blocks' relations.** `B_k`'s plane is
  constrained by block `k`'s slot 22 *and* block `k+1`'s slot 21, so its
  claim values are tied to two different blocks' witnesses. The generic-rank
  lemma is per commitment and does not care; the joint-law composition does,
  because `B_k`'s two claim values are the only published quantities in the
  run that are functions of two blocks' data at once. The obligation is to
  show that the pair of claim values discloses nothing beyond the public
  relation — which is exactly the `m = 2`, two-singleton-groups case of the
  corrected Proposition (`ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4), *given*
  disjoint pairs.
* **The same hidden plane sits under THREE commitments** [OMITTED CONDITION
  O7]. An internal boundary plane is held by `A_k`'s `A_X2` rows, by `B_k`,
  and by `A_{k+1}`'s `A_X` rows, where the toy analysis handled a plane under
  two. Three is the same argument applied once more rather than a new one —
  given per-commitment independent blinding (O-R2) and a full-rank reserved
  block on each, each view is uniform and the triple is a triple of
  independent uniforms — but **a rank deficiency in any one of the three
  leaks the same plane**, so the gate must rank **all three roles** of at
  least one interior boundary plane, jointly, not only `B_k` (§5.4, ruling
  M-8). A related coupling is already handled by R-D3: slot 22 of block `k`
  reads `A_k` and `B_k` while slot 21 of block `k+1` reads `A_{k+1}` and
  `B_k`, and their published scalars and round polynomials are masked by
  **two different** masking commitments, `M_k` and `M_{k+1}` — an argument
  *for* one `M` per block that §2.4 does not make.

**O-R4. The refusal channel at run scale.** Proposed D20 keeps refusals
inside the privacy argument: challenge-only at about 2^-62, with one
input-dependent class (a zero LogUp denominator) at about 2^-112. A run makes
`L` independent draws of every refusal class, so the run's refusal
probabilities are about `L ×` the block's: **`12 × 2^-62 ≈ 2^-58.4`** for the
challenge-only classes and **`12 × 2^-112 ≈ 2^-108.4`** for the
input-dependent one [COUNTED]. Neither is alarming; both must appear in the
run's statement rather than being inherited silently. And one operational
consequence is sharper for a run than for a block: a refusal in stage 12
throws away eleven stages of work (about 5.7 minutes), so the temptation to
retry is real — and a retry must use **fresh** endpoints and a fresh run, as
the single-attempt reading (J-4) requires. No partial re-run, ever.

One refusal class must be added to this list [OMITTED CONDITION O11]: a run
makes **49** `ZkRng::from_os` calls (23 more than a block), and `from_os`
**fails closed** — `protocol.rs:475` maps the error to a refusal before
anything public exists. At run scale that refusal can now happen in stage 12,
six minutes in. It is the one refusal class that is neither challenge-driven
nor input-driven, and the run's statement must list it with the others.

**O-R8. The boundary's scale must be tied to the approved calibration — a
CORRECTNESS obligation, not a privacy one** [BLOCKING B3, ruling M-4]. D12
item 5 is open: "declared endpoint scales must be tied to the approved
calibration before any seam compares them. Today the tag proves nothing …
a tag-equality check would pass on a factor-of-8 mismatch." A block declares
two scales; a run declares thirteen. The construction and the header carry
the fix (§2.1): **one field per boundary, shared by construction between
block `k`'s output and block `k+1`'s input** — option A gives a boundary
exactly one declared scale, so nothing is *compared* there, which option B
could not do — and **one calibration identity in the header covering all
thirteen**. What remains owed is the tie itself: the approved calibration
must be the thing that identity is computed from. Until it is, a run could
chain blocks whose calibrations disagree and no receipt field would say so.

### 5.2 (b) The internal boundaries are never sealed for anyone

Under D18 the prover seals the run's two external endpoints at proof time and
publishes their roots with the receipt. The `L−1` internal boundaries are
sealed for **nobody**: they are prover-generated commitments to hidden
intermediates, exactly as `xres1`, `nm` and `z16` are inside one block (D12
item 3).

**What is published about `B_k`, exhaustively:**

| published | what it is |
|---|---|
| its root | a Merkle root over **salted** column hashes of a hiding commitment (`pcs.rs:674`, `:689-690`) |
| its rows, row width, rate, pad count, site count | public geometry, in the parameter line and the schedule digest |
| its scale tag | **one** field, shared by the two blocks, covered by the run's single calibration identity (§2.1, O-R8) |
| one opening: 2 group vectors + 1 proximity vector (16,640 `Fp2` each) and 256 columns with salts and paths | the masked linear view the whole privacy argument is about |

**What is NOT owed here, and a reader of D12a will ask.** The boundary
plane's int16 class **is** proved at both ends [OMITTED CONDITION O8]: the
`Dom::D` LogUp list carries `byte(A_XL0), byte(A_XL1)` and `byte(A_X2L0),
byte(A_X2L1)` (`layout.rs:682`, `:704`), so block `k` range-proves its output
plane's int16 limbs, block `k+1` range-proves its input plane's, and the
equality ties the words. D12 item 4's analogue at a boundary is therefore
discharged twice over.

**And nothing else — provided:**

1. **No second opening, ever.** One opening per commitment is the rule the
   whole geometry rests on ("a commitment opened twice is dead at this
   geometry"). For `B_k` this is sharper than for an endpoint, because two
   *stages* touch it: the implementation must make a second opening
   impossible by type, as `PreparedPlaneG`/`Endpoints` do today (no `Clone`,
   no data getter, no repeated-opening method, consumed by value —
   `endpoint_g.rs:144-162`, `private_block.rs:604-618`). **The discipline
   lives on the WRAPPER, not on `open_zk`** [CORRECTION C1]: the draft said
   "the boundary owner must be consumed by the opening call, not borrowed",
   and that cannot be met by calling `open_zk`, whose signature is
   `open_zk(cmz: &CommittedZk<E>, claims: &[ZClaim], tr: &mut Transcript)`
   (`pcs.rs:915`) — it **borrows**, and `CommittedZk`'s `data`, `pads`,
   `salts`, `mask_rows` and `prox_mask_row` are all `pub` (`pcs.rs:551-564`).
   The no-`Clone`, consumed-by-value discipline lives one level up, on
   `PreparedPlaneG` (`endpoint_g.rs:146-162`, `into_endpoint(self)`). So
   `boundary.rs` must own the `CommittedZk`, expose only `root()`, and offer
   an `into_opening(self, claims, tr)` that consumes itself (§7.2).
2. **No boundary plane leaves the process.** No getter, no log line, no
   telemetry, no debug print, no capture field. `native_capture.rs` is
   test-only and exports "no witness plane, private pad, mask coefficient,
   endpoint preimage or RNG state"; the run's capture writer must keep that
   invariant for boundary planes and boundary mask rows (§5.4).
3. **A retained capture bundle counts as publishing** (the privacy
   statement's operating rules, §6). A run capture is a much bigger bundle
   (§5.4); the rule does not weaken.
4. **The run's driver does not return the planes to its caller.** The honest
   prover computes all `L` planes in the clear — that is inference — but the
   proving API must take them by value and drop them.

### 5.3 (c) The sampler's residual for L = 12, and the many-proofs arithmetic

D9's term is a **privacy** term and counts **every mask and pad the prover
draws**, each within 2^-96 of uniform in total variation (the Goldilocks-
specific figure; a generic 64-bit prime would give about 2^-66 per draw).
Salts are raw bytes with no modular reduction and contribute nothing.

`run_arithmetic.py` counts the draws from the code
(`protocol.rs:543-546`, `:642-654`; `pcs.rs:673`; `zk.rs:430-457`) and
**reproduces the two published figures before counting anything new**:

| | draws | residual |
|---|---|---|
| one toy block | 325,468 – 327,676 = 2^18.31 | **2^-77.7** — published 2^-77.7 ✔ |
| one 125M block | 9,177,436 – 9,182,726 = 2^23.13 | **2^-72.9** — published 2^-72.9 ✔ |

(The ranges are the only uncertainty: the masking commitment's coefficient
count depends on the per-slot message lengths `L_s`, bounded here by
`23 × largest_slot_length`; it moves the total by under 0.06%.)

The run, `L = 12` at 125M, with 11 boundary commitments and 2 external
endpoints [COUNTED]:

```
per block, excluding IO commitments        8,999,942
  × 12 blocks                            107,999,304
11 boundary commitments (108,032 each)     1,188,352
2 external endpoints, 37 rows (91,392)       182,784
                                        ------------
RUN TOTAL                                109,370,440  = 2^26.70
residual = draws × 2^-96                 2^-69.3
```

This total is the one M-7 makes the design's: 37-row external endpoints. The
independent check re-derived it and confirms it
(`run_recount.py`; the per-commitment counts follow
`(rows − data_rows)·n + rows·q`, `endpoint_g.rs:200-202`, `pcs.rs:673`, with
salts D9-exempt as raw bytes). **One line of the draft's own script is
superseded** [CORRECTION C9]: `run_arithmetic.py:309-310` charges a 36-row
endpoint **six** mask rows where 36 rows is 32 data plus **four**, printing
109,402,696 for the withdrawn uniform-endpoint variant where the correct
count is 109,337,160. The script is the draft's committed evidence and is not
edited; its line is superseded by the check's `run_recount.py`. Headline
effect: none, 2^-69.3 either way — and under M-7 that variant is not the
design.

So **one 12-block run at 125M is 2^-69.3**, against 2^-72.9 for one block —
3.6 bits, the cost of twelve times the blinding material. One million such
runs is **2^-49.4** (distance grows linearly), against the statement draft's
2^-57.7 for a million toy proofs. Both are far from any practical threshold,
and both must be **stated** rather than inherited: the run's privacy
statement, if one is ever signed, carries 2^-69.3 per run.

Two properties of this term worth recording: it is a distance, so it adds
across runs and across blocks with no cancellation; and it is the term that
disappears entirely if `ZkRng::fp` ever moves to rejection sampling (one
line, plus a re-freeze of the zero-knowledge fixtures), which at run scale
is a slightly better bargain than it was at block scale.

### 5.4 (d) Capture and gates at this scale; what to check at a small multi-block shape

**Where the gate is.** The joint-view gate is *not* in the main tree: it is
`scripts/zk60_native_joint_view.py` + `zk60_native_jv_*.py` on branch
`zk60-native-jointview` (worktree `/home/victor/wt-zk60-jointview`), eight
stages, run on **four schema-3 captures at two toy profiles** and nowhere
else. Its verdict there is `A 0 / H 2 / Input 0 / Output 0` disclosed, with
`H`'s 2 being the public LogUp identity. Every document that could say so
says the same thing about a new shape: "the joint-view gate is owed on the
grown layout … and again on a two-block capture before any chain"
(`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §10.2, O-3), "the 125M profile owes the
gate again from the start" (`ZK60_NATIVE_PRIVACY_GATE.md`), "at the
development rung and the 125M shape the layout changes and the question is
owed again" (ruling G-2).

**The feasibility answer is the opposite of what the question assumed, and
this is the most useful finding in this section.** An exact rank over a
5,681-row commitment is **not** the problem: the matrix the gate actually
factors is `2(G+1)` **generators** (the real and imaginary parts of the `G`
group vectors and the proximity vector) by **the commitment's rows** —
`74 × 5,681` for `A` at 125M — not rows × rows and not rows × opened columns
(`zk60_native_jv_pcs.py:451-456`, `:510-512`). Elimination stops after at
most `g` pivots, so the cost is `O(g² · rows)`, the group count barely moves
between the toy (35) and 125M (36), and the pad-block rank is `≤ 256 × 256`
at every shape forever (1.8 s measured). What *is* infeasible is different:

| | matrix | cost vs the measured toy joint stage |
|---|---|---|
| one 125M block, per role | 74 × 5,681 | 15× — **fine** |
| **L = 3 at the rung, joint over the whole run** | 308 × 3,785 | 38× — **fine** |
| **L = 12 at 125M, joint over the whole run** | 1,226 × 154,702 | **24,751×** — not in pure Python |

[COUNTED, `run_arithmetic.py`; the toy reference is the gate's measured
stage 4, 102 generators over 903 rows, inside a whole-gate 23.5 s.]

Two further walls at 125M, both engineering rather than mathematics:

* **The capture file.** A toy block capture is 9.25 MB of JSON, dominated by
  `columns` — 256 sampled indices × **one value per committed row** — which
  is linear in rows. At 125M that is roughly **120–140 MB** [MODEL,
  extrapolated linearly by row count], and
  `scripts/zk60_native_capture.py:143` refuses any capture over **64 MiB**
  (`bounded(path, 64 * 1024 * 1024)`), so a 125M capture is rejected before
  any checking, while `zk60_native_jv_capture.py:52-56` reads with no bound
  at all and would turn 130 MB of decimal `u64`s into multi-GB of Python
  objects. A run capture at `L = 12` would be twelve of those.
* **The per-claim and per-column work**, `O(sites × rows)` and
  `O(checked × rows × 512)`, is what turned a 702/1,326-row FFN capture into
  165 s; at 125M it extrapolates to tens of minutes per block [MODEL].

**Therefore: gate the run at a SMALL multi-block shape, and say precisely
what that does and does not transfer.**

*Proposal:* `L = 3` on the **rung-G profile** (the development rung carried
on the generalised endpoint: `T24 / d96 / f192`, `A 623 / H 576 / M 50`,
`a_groups 36 / h_groups 9`, boundary commitment `4 + 4 + 2 = 10` rows,
boundary opening 190,464 B [COUNTED]). `L = 3` and not 2, because 3 is the
smallest run with an **interior** block — one that has a boundary on both
sides — and with two consecutive boundaries. **This is the gate the security
owner set** (ruling M-8): three blocks at the development rung, all three
roles of each boundary plane ranked jointly, both controls included, the
capture written by a new module. **No privacy statement about any run may be
made before it**, and passing it is not itself a privacy acceptance.

**What it would settle** (all of it new, none of it available from a
one-block capture):

1. The boundary commitment's **joint** rank over its two singleton groups,
   **restricted to its reserved mask rows** and reported as such (O-R1),
   with **both** negative controls firing: the shared pair (rank 4,
   disclosed 2) and the single proximity row (rank 5, disclosed 1) — the
   second being the geometry `audit_claims` accepts and the module must
   refuse (§1.2, rulings M-1 and M-8).
2. That the two claims on one commitment, raised in two different stages at
   two different points, form two groups with disjoint pairs, and that
   `audit_claims` refuses when they do not.
3. The **run-wide joint** system — all 3 blocks' `A`/`H`/`M`, both
   boundaries, both external endpoints as one rank — and whether
   `joint == sum of parts` still holds when a commitment is shared between
   stages. This is the exact question ruling G-2 says is owed again whenever
   "something non-data is shared", and a boundary commitment is the first
   deliberately shared object the project has. **It must include all three
   roles that hold an interior boundary plane** — `A_k`'s output rows,
   `B_k`, and `A_{k+1}`'s input rows — because a deficiency in any one of
   them leaks the same plane (O-R3, OMITTED CONDITION O7, ruling M-8).
4. That block `k`'s published opening, absorbed before block `k+1`'s masks
   are used, adds no disclosure (O-3).
5. The transcript replay across segments: stage 1's challenges reproduce
   from the header, stage 2's from stage 1's bytes, and a dropped or
   reordered segment fails the state check.

**What it does not transfer:**

* **Nothing numerical about 125M.** The disclosed dimensions at the rung say
  nothing about the grown layout — G-2 and D17/R-3 say so explicitly, and the
  project has already been burned once by a gate result quoted across shapes.
  125M still owes the one-block gate from the start (steps S12/S13), and the
  run gate at 125M would owe it again on top.
* **The pad-budget *statistics*, but not the *condition*** [CORRECTION C10].
  The distinct-position counts are shape-dependent through the sampling (at
  the rung `enc_cols = 1024`, expected distinct ≈ 226; at 125M
  `enc_cols = 65,536`, expected ≈ 255.5), so no count transfers. The
  condition `distinct ≤ pads` itself holds **structurally at every shape**
  (§1.5), so it is not a margin that can run out and it is not a thing the
  gate has to re-establish per shape. The draft listed the whole item as not
  transferring; say which half.
* **Everything the rung does not exercise**: the 125M pad rule at its own
  padded domains, the grouped-head permutation, the third `sigma_s` limb.
* **The structural facts DO transfer**, and that is the point of choosing
  `L = 3`: the rank condition is computed on the **reserved rows only** and
  does not involve the data-row count at all, so the rung's 10-row boundary
  (4 data + 6) and 125M's 38-row boundary (32 + 6) have **identical**
  reserved blocks. `rows = data + 2·sites + 2` is derived at every shape and
  `audit_claims` runs on both sides at every profile. What the small shape
  settles is the **construction**, not the instance.

**Capture format for a run.** The capture is written by a **NEW
run-capture module** — never by editing the integrator's
`native_capture.rs` (ruling M-8, §7.8). The writer must gain: a `run` block (profile,
`L`, the segment index, the per-stage transcript checkpoints), a `boundary`
role per boundary commitment with the same fields a `Input`/`Output` role has
today plus **two** claim entries and a `row_roles` table naming both pairs,
and a cross-stage `opening_order` for the run. It must gain **nothing** that
names a boundary plane word, a boundary mask row or a pad. And the 64 MiB
ingestion bound must be raised deliberately, per profile, with the reason
recorded — not silently, because that bound is the thing standing between
"the tool refused" and "the tool consumed 12 GB".

## 6. The D12 amendment — RECORDED as D12a

D12 item 2 reads "a block is one proof under one transcript with **exactly
two external endpoints**". Read literally that forbids a multi-block run,
which has two external endpoints *for the run* and none for its `L−1`
interior boundaries. The layout check confirmed the amendment is "genuinely
needed" and should be "filed as a pending ruling in `ZK60_DECISIONS.md`, not
left in a memo".

**It is now recorded** [ruling M-5]. The authoritative text is the register's
entry **D12a** in `docs/zkmatrix-poc/ZK60_DECISIONS.md` (recorded 2026-09-20,
security owner), and this section is replaced by it. Where this memo and the
register disagree, the register wins:

> **D12a.** Amendment to D12 for a private RUN of several blocks: a run is
> **one transcript end to end** with two external endpoints **for the run**,
> sealed by the prover (D18); each internal boundary plane is a hidden
> intermediate on **one prover-generated boundary commitment**, claimed by
> the two adjacent blocks, **one reserved pair per claim site, opened exactly
> once**, its row count **derived** as `data + 2·sites + 2` (a single
> proximity row discloses 1 and the claim audit does not catch it); all five
> items of D12 carry over (no commitment opened twice; the second norm's int8
> range proof holds at both ends of every boundary; **a boundary's scale is
> one field shared by both blocks, and the run absorbs one calibration
> identity**). Still forbidden: joining two finished runs (needs D18's option
> B **and** D8/D11 discharged); a boundary commitment fixed by anyone but the
> prover. Soundness of a twelve-block run at the 125M geometry about 2^-97.5
> by the project's accounting — acceptance of that level is Victor's,
> pending. *Status: construction rule (restrictive; not a privacy
> acceptance); paper only, nothing built.*

Three things the draft's own proposed text got wrong or left out, all now
carried by the register's wording: it cited **D12 item 1** where the
prover-generated-hidden-intermediate rule is **item 3** [CORRECTION C11]; it
read "joining finished runs needs the sealed handle of D18 option B, which
does not exist" in a way that invites "…so when the handle exists, joining is
permitted", where D8 and D11 also bind that configuration and are open
[CORRECTION C12]; and it dropped D12's items 4 and 5, of which item 4 is in
fact **satisfied** at a boundary (the int16 class is proved at both ends,
§5.2, OMITTED CONDITION O8) and item 5 is the open correctness hole a run
multiplies from two places to thirteen (§2.1, §5.1 O-R8, BLOCKING B3).

One sentence a product reader needs, and the draft did not have it: **no
per-block claim can be extracted from a run's receipt.** Under D12 a block's
output was an external endpoint; under D12a an interior block's output is a
hidden intermediate nobody can refer to. A run's receipt may not be quoted as
evidence about any single block inside it.

The register entry is terse by design. The restrictions it carries, spelled
out for an implementer, are the ones this memo argues for and none beyond
them: a run is one transcript end to end and separately finished proofs may
not be joined (D8/D11 restatement §2.5); a run has exactly two external
endpoints, sealed by the prover for the first MVP (D18), and a block inside a
run has none of its own; internal boundary planes are hidden intermediates on
prover-generated commitments under **D12 item 3**, each claimed by exactly
two claim sites with its own reserved pair and opened exactly once; nothing
else about an internal boundary is published, and a retained capture bundle
counts as publishing; and what stays forbidden is joining two finished runs
(which would need D18's option B **and** D8 and D11 discharged), opening any
commitment twice, a caller-fixed root for an internal boundary, reuse across
two transcripts, and re-running part of a run after a refusal.

**What D12a does not do.** It establishes no privacy property for a run, at
any shape. It does not discharge D8 or D11 for the run's two external
endpoints. It adds obligations rather than removing them: the joint-law
argument must be restated for a run, the joint-view gate is owed on a
multi-block capture before any run's result is quoted, and the run's
soundness level (about 2^-97.5, §2.8) awaits the project owner's acceptance.

## 7. A staged build plan, smallest failing test first

**Lane rules.** The implementer works inside `hashline/src/private_block/`
and may not edit `zk.rs`, `pcs.rs`, `private_seam.rs`, `native_capture.rs`,
`zkp-core/` or the frozen kernel crates. **Nothing in the prover or verifier
path needs any of them** — see §7.8. Every step keeps the frozen toy profile
and both rung profiles byte-identical; that is an acceptance criterion at
every step, not only at the end.

### 7.1 R1 — the rule, before the code (the first test, and it must fail)

Write, at the boundary geometry and with no new module in the tree, a test
that calls the existing `audit_claims` (`protocol.rs:208-252`) on a
hand-built two-claim schedule at `rows = data + 2·sites + 2`:

* two claims, disjoint pairs at `(data, data+1)` and `(data+2, data+3)`,
  proximity pair last → **accepted**;
* the same two claims both on pair 0 → **refused**, with the message "a
  reserved pair is unused or shared between claims";
* a claim reaching the proximity pair → refused;
* a zero pair coefficient → refused;
* **the fifth case, and the reason R2 derives its geometry** [BLOCKING B4,
  ruling M-1]: the same two claims at `rows = 37`, `prox = 35` — a single
  proximity row — are **ACCEPTED by `audit_claims`** (its `prox + 2 == rows`
  test holds), and yet that geometry discloses one real dimension (§1.2,
  §5.1). The test records the acceptance as the finding it is: the audit does
  **not** enforce the hiding geometry, so `boundary.rs` must derive the row
  count and refuse a caller-supplied one (R2), and that refusal — not the
  audit — is what this case pins.

One trap to design the rows around: the alignment clause
`(touched[0] − site_rows[0]) % 2 != 0` (`protocol.rs:238`) means a pair
placed at rows `(33, 34)` is refused for the **alignment** reason, not the
sharing reason, so a test asserting on message text must choose its rows
deliberately.

This pins the rule before anything can be built around it, it needs no new
code, and it is the test that would have caught the project's known
counterexample.

### 7.2 R2 — `boundary.rs`, the commitment itself

A new module beside `endpoint_g.rs`, modelled on it line for line, with
`sites` as a parameter: its **own** domain label (so its digest can never
collide with `endpoint_g`'s or `private_seam`'s), **`rows` DERIVED as
`data + 2·sites + 2` from the plane and the site count — never taken from a
caller** [BLOCKING B4, ruling M-1], `mask_rows = [data … data + 2·sites − 1]`,
`prox_mask_row = data + 2·sites`, fresh OS entropy per call, no `Clone`, no
data getter, consumed by value.

**The consumed-by-value discipline lives here, on the wrapper** [CORRECTION
C1]: `boundary.rs` owns the `CommittedZk`, exposes only `root()`, and offers
`into_opening(self, claims, tr)` which consumes `self` and calls
`pcs::open_zk` — which itself only **borrows** (`pcs.rs:915`) and cannot
enforce anything (§5.2).

Tests: the declared geometry at rung-G (`4 + 4 + 2 = 10` rows) and at 125M
(`32 + 4 + 2 = 38`); **a caller-supplied row count, and specifically the
37-row `data + 2·sites + 1` geometry, refused BY NAME** (the case R1 pinned);
digest separation from both existing constructions and movement with every
parameter; every malformed statement refused **by name**; two commitments to
one plane give two roots; the C-H4 node-shaped-column refusal — which the
module must run on its own row count, as `endpoint_g.rs:107` does, because a
`sites`-parameterised module can be asked for 5 rows (`data = 1`,
`sites = 1`) and must refuse; and — the point of the module — **one opening
carrying two claims at two different points verifies through
`pcs::verify_zk`, a one-bit change to either claim value rejects, and two
claims at the same point produce one group and trip `check_opening`'s
declared-count refusal.**

### 7.3 R3 — `L = 2` at the development rung (rung-G): the run driver

`prove_run` / `verify_run_bytes` over a run layout, the transcript of §2.1,
the stage order of §2.2, the segment framing of §4. Acceptance:

1. **honest run verifies from segments** (from bytes, with a fresh layout —
   the only form in which a run counts for anything);
2. **THE HEADLINE NEGATIVE TEST: block 2 rebuilt on a hidden input that is
   not block 1's output is REJECTED BY THE VERIFIER.** Both variants must be
   tested, because they fail at different places: (i) the boundary holds
   block 1's true output and block 2 was run on something else → block 2's
   slot 21 equality fails; (ii) the boundary holds block 2's input and block
   1's output differs → block 1's slot 22 fails. The test asserts the
   refusal **names the failing slot**, and that no panic is reachable;
3. a boundary claim built on a **shared pair** is refused by `audit_claims`
   on the **prover** path and on the **verifier** path (both call sites);
4. a **dropped**, **reordered**, **duplicated** or **foreign** segment
   (spliced from a second honest run with different external endpoints) is
   rejected at the segment state check, by name, before any field element is
   parsed;
5. a one-bit change anywhere in any segment rejects; truncation and trailing
   bytes are refused;
6. `L = 1` through the run driver reproduces the single-block statement's
   counted receipt length, or the delta is stated and explained;
7. the frozen toy and both rung profiles are byte-identical to their
   pinned digests;
8. **the segment-flush invariant** [BLOCKING B2]: each segment is serialised
   and its `Receipt` released before the next stage begins, asserted by the
   driver, and **the high-water mark is printed per stage** [OMITTED
   CONDITION O3] — a mark rising by more than the 29.8 MiB of one extra
   boundary from stage to stage is the sign of allocator fragmentation and
   stops the ladder;
9. **the run wire module sizes each segment on its own** [OMITTED CONDITION
   O4]: `encoded_len_segment(lay, k, L)` for the three distinct segment
   lengths and a per-segment bound, not `receipt_bytes().total` clamped by
   `wire_bound`'s `min` to 64 MiB;
10. **a run schedule that opens `B_k` in stage `k`** — before block `k+1`'s
    claim exists — is a **prover-side refusal naming the commitment**, not
    an incorrect proof; and **a boundary whose two claims land at the same
    point** is refused at run scope by `check_opening`'s declared-group-count
    check (`protocol.rs:279-281`) [OMITTED CONDITION O9];
11. **calibration** [BLOCKING B3, ruling M-4]: a run whose block `k+1`
    declares a different input scale than block `k`'s output scale **does
    not construct** (a boundary's scale is one shared field), and a receipt
    made under one calibration identity is **rejected** under another.

### 7.4 R4 — `L = 3` at the rung: the interior block, and the capture

`L = 3` is the smallest run with a block that has a boundary on both sides
and with two consecutive boundaries. New acceptance beyond R3: the middle
block rebuilt on a different input rejects; the run-level open-commitment
table (§4.3 check 4) is empty at the end and **fails when a boundary opening
is removed**; each boundary commitment is opened exactly once (asserted by
the driver and by the verifier); the two refusals of R3 item 10 repeated
with an interior block on both sides [OMITTED CONDITION O9]; per-stage
high-water marks printed and non-rising across the three stages [OMITTED
CONDITION O3]; and the **run capture** is written — by the new
`run_capture.rs`, never by editing `native_capture.rs` (ruling M-8) — and
handed to the joint-view lane (§5.4). The gate itself runs on branch
`zk60-native-jointview` and is not this lane's work — this lane owes the
capture and the schema. **`L = 3` at the rung is the gate M-8 sets**, and
its rank stage must cover all three roles of an interior boundary plane and
both negative controls (§5.4).

### 7.5 R5 — `L = 12` at the rung

No new mechanism; it catches whatever scales — segment indices, row indices,
the segment writer's own memory, the `L`-fold statement digest. Cheap enough
to run in the test suite.

### 7.6 R6 — ONE measured `L = 2` at the 125M shape (a heavy run)

Detached, under the heavy lock, CPU only, inside a memory ceiling that kills
the process and not the box, phase timing on, evidence written under
`results/`. Predicted before the run, so the run can fail: prove wall about
`2 × 31.2 = 62 s` (26.54 prove + 4.69 witness per block) [MODEL from
MEASURED]; peak RSS about **10.68 GiB** (predict: under 11.0) [MODEL:
10,837 MiB measured, plus 88.2 MiB of stage-1 IO commitments, plus 6.3 MiB
for the second block's public statement]; two segments of **40,033,352** and
**41,051,176** bytes **exactly** [COUNTED at the §4.3 framing — 96 B header
plus 40 B trailer — with today's 37-row external endpoints (M-7)]; verify
from segments about 2.1 s. A segment length that is not the counted one is a
failed acceptance, not a curiosity — which is why the framing is counted once
and at the specified size (§4.2, CORRECTION C7). The run also prints its
**high-water mark per stage** and asserts the segment-flush invariant
(§7.3 items 8 and 9).

### 7.7 R7 — `L = 12` at 125M

Only after R6. Predictions: **6.26 minutes** of proving [COUNTED from
MEASURED parts], **484,100,928 B (484.1 MB)** in twelve segments [COUNTED],
peak **10.74 GiB** [MODEL], verify **12.5 s** [COUNTED]. Same operating
conditions. This is a measurement, not a privacy claim, and the statement
attached to it must say so in the same sentence — together with the run's
soundness level, about 2^-97.5 (§2.8), whose acceptance is the project
owner's and is pending.

### 7.8 What needs a forbidden file

**The prover and verifier path needs none.** Checked:

* `zkp-core/src/pcs.rs` — `open_zk`/`verify_zk` already batch any number of
  claims into groups and fold pads with every `rho` (`:915-944`, `:947-…`);
  `assert_mask_sites` is satisfied by setting `mask_rows` and
  `prox_mask_row` from the caller, which is exactly what `endpoint_g.rs:205`
  does today. **No change.**
* `hashline/src/zk.rs` — one masking commitment per block of 23 slots
  (§2.4), so `mask_commit`, `mask_open`, `mask_verify` and `M_ROWS = 50` are
  untouched. **No change.**
* `private_seam.rs` — untouched; the run never uses it. **No change.**
* Only slots 21 and 22 touch an IO commitment: `b.endpoint` is called at
  exactly one site in the whole argument (`argument.rs:1430`) [VERIFIED by
  grep], so the routing change is local.

**But "no forbidden file" is not "no existing code"** [CORRECTION C13,
OMITTED CONDITION O1]. The check listed seven **permitted** sites that a run
touches, and the draft named none of them. Saying the first without the
second is how a two-day estimate becomes a week:

| # | site | what it is | under M-7? |
|---|---|---|---|
| 1 | `endpoint_g::MASK_ROWS = 5` (`:51`), **and it is inside the endpoint spec digest** (`:136`) | the endpoint's five-row budget | **REMOVED from the build** — external endpoints keep today's geometry, so the constant and the digest do not move |
| 2 | `private_block.rs:513-515` — refuses any shape whose declared `endpoint_rows` is not `data + 5` | it would have **refused the draft's 36-row external endpoint by name** | **REMOVED from the build** — nothing asks it to accept 36 rows any more |
| 3 | `protocol::ENDPOINT_MASK_ROWS = 5` and `endpoint_geometry = (rows, rows−5, rows−3)` (`:298`, `:313-327`) | geometry helper, endpoint-shaped | stays: it must also serve a 38-row, two-site boundary |
| 4 | `argument.rs:521`'s `mask_row = sh.endpoint_rows − 5` | hard-codes one pair's position | stays: the pair index must come from the tab's role and the site count (§1.6) |
| 5 | `layout.rs:1043`'s node-shaped-column check | lists the endpoint; must list the boundary | stays |
| 6 | `shape.rs:706`'s `endpoint_openings: 2 * opening(1, endpoint_rows, …)` | hard-codes one group and two IO openings | stays: a run has `L+1` IO openings and the boundary has two groups |
| 7 | `wire.rs:93`, `:116`, `:224` | hard-code one group and two IO openings in the frame | stays: plus `encoded_len_segment` (§4.1) |

So **five of the seven move, and M-7 removes the two that would have touched
a spec digest and a by-name refusal.** `check_endpoint_opening`
(`protocol.rs:333-347`) is untouched either way: it keeps serving the
external endpoints, which keep their one-claim form.

**One thing would need a forbidden file, and the ruling forecloses it.** The
run's **capture writer** would naturally be an edit to `native_capture.rs`,
which is forbidden. **Ruling M-8 settles it: the capture is written by a NEW
run-capture module, never by editing the integrator's capture writer.** So:
a **new** test-only `private_block/run_capture.rs`, included the way
`native_capture.rs` is included (`private_block.rs:786`), sharing the schema
conventions but not the file — the run's roles are new (`boundary`) and the
stage/segment structure is new, so there is little to reuse. (The draft also
offered an explicit exception to extend `native_capture.rs`; that option is
**withdrawn**.) Either way the
Python side's ingestion bound (`scripts/zk60_native_capture.py:143`,
`bounded(path, 64 MiB)`) must be raised deliberately and per profile, with
the reason recorded.

## 8. Decisions for the security owner, open obligations, and what I did not check

### 8.1 Decisions

| # | decision | recommendation | why, in one sentence |
|---|---|---|---|
| **R-D1** | The boundary object: a boundary commitment with two claim sites (A), or a direct equality between two `A` commitments (B)? | **A** | Memory is a tie and B is 1.7% smaller, but A leaves every counted constant of the measured block untouched and confines the one new joint-law question to a 38-row object instead of the 5,681-row `A`. |
| **R-D2** | The boundary's geometry: `data + 2·sites + 2` or `data + 5` (today's endpoint budget)? | **`data + 2·sites + 2`, DERIVED by the module and never accepted from a caller** (ruling M-1); the run's **two external endpoints keep today's 37-row `endpoint_g` form unchanged** (ruling M-7) | It is the geometry `audit_claims` is written for **and** it is a hiding requirement — `2(G+1)` real dimensions need `2·sites + 2` free mask rows, and the 37-row single-proximity-row geometry discloses 1 while the audit accepts it. The draft's corollary of uniform 36-row external endpoints is withdrawn: it buys 2,048 B per endpoint and costs a change inside the endpoint spec digest plus a by-name refusal in `private_block.rs`. |
| **R-D3** | One masking commitment per block, or one per run? | **Per block** | A run-wide `M` would be a single commitment carrying `L` blocks' functionals — a cross-block channel nobody has analysed — and it saves 0.55% of the receipt. |
| **R-D4** | Randomness: one OS stream per run, or one per commitment? | **One `ZkRng::from_os` per commitment** (per block as now, per boundary as `endpoint_g::prepare` already does) | It makes cross-block independence rest on operating-system entropy rather than on stream separation inside one generator, which is the hypothesis (O-2) the one-block argument assumes and never proves. |
| **R-D5** | When is `B_k` opened, and is anything of block `k` held past its stage? | **`B_k` in stage `k+1`; `A_k`, `H_k`, `M_k` opened and dropped at the end of stage `k`** | It is the only placement that puts the opening after both claims while keeping the peak at one block's, and deferring boundary openings to the end of the run buys nothing and costs 328 MiB. |
| **R-D6** | Receipt: one frame, or segments? | **One segment per stage**, each with a 96-byte header and a 40-byte trailer carrying the transcript state and squeeze counter, **counted once at that size** (ruling M-6) | 484 MB cannot be one frame under the existing 64 MiB bound, and a segment-per-stage receipt keeps the verifier at 727 MiB with 2 KB carried across each boundary; the byte-exact acceptance uses the 136-byte framing (40,033,352 / 40,301,640 / 41,051,176). |
| **R-D7** | A new verifier obligation: must the verifier itself check "every commitment opened exactly once, every claim discharged"? | **Yes, at run scale** | Keep the answer, replace the reason (C8): the run layout is a function of the verifier's own statement, so this is a cheap **regression guard on the verifier's own path**, not an upgrade from a promise to a check. |
| **R-D8** | The D12 amendment: record before or after the first `L > 1` run? | **Before — and it is now RECORDED as D12a** (2026-09-20, security owner) | The layout check already ruled that item 2 read literally forbids a run, so proving one first would put the artifact ahead of the rule; the register's text carries D12's items 4 and 5, the item-3 citation and the D8/D11 condition on joining (§6). |
| **R-D9** | Where is the multi-block gate run? | **`L = 3` at rung-G** (ruling M-8), and explicitly **not** the run-wide joint rank at 125M with the present tools | The rung's run-wide joint matrix is 38× the measured toy stage and the 125M run's is 24,751×; the structural facts transfer because the reserved block is identical at every shape, the numbers do not, and the gate must rank **all three roles** of a boundary plane with both negative controls. |
| **R-D10** | The "about 5.3 minutes for twelve blocks" figure in `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §8 and anywhere it was copied | **Correct it to 6.26 minutes** | `12 × 26.54 s` omits the 4.69 s-per-block witness build, which is measured and is outside the prover's phase table; the run's own boundary commits, opens and extra encodes add 0.62 s. |
| **R-D11** | Is streaming verification a requirement or a nicety? | **A requirement** | It is what keeps the verifier's memory at one segment and it forces the segment binding (§4.3) to be explicit checks rather than "it would fail anyway". |
| **R-D12** | **Is about 2^-97.5 of soundness acceptable for a native-line RUN?** (§2.8) | **The PROJECT OWNER's ruling, pending** — the security owner states the figure and does not accept it on his behalf | Twelve blocks come to about 2^-97.46 [COUNTED]; that is the same 97-bit level D3 accepted by explicit ruling for the zkVM line, and the native line reaching it by union bound deserves the same explicit acceptance rather than silence. It does not block building. |
| **R-D13** | **Is a 484 MB receipt per twelve-block run acceptable for the MVP?** (§4.2) | **The PROJECT OWNER's**: recorded on his page as a deviation, **not a blocker** (ruling M-6) | The contract's proof-size budget is 256 KB, the one lever that would shrink it cannot run privately (D10), and an 8B model's 32 blocks would be several gigabytes — who stores it, who transfers it and what the MVP promises are product questions. |
| **R-D14** | How is a boundary's scale tied to the approved calibration? (§2.1, §5.1 O-R8) | **One scale field per boundary, shared by construction; one calibration identity in the run header covering all thirteen declared scales** (ruling M-4) | D12 item 5 is open — "today the tag proves nothing" — and a run multiplies the places it bites from 2 to 13; this is a **correctness** obligation, with two acceptance tests in R3. |

### 8.2 Open obligations

**New, created by a run** (none of these exists today):

* **O-R1** The boundary commitment's two groups ranked **jointly and
  restricted to its reserved mask rows**, with both negative controls firing
  (shared pair: rank 4, disclosed 2; single proximity row: rank 5, disclosed
  1) — and `audit_claims` enforcing cross-group pair disjointness on it,
  while the **module** enforces the row count the audit does not (§5.1,
  §1.2).
* **O-R2** Cross-block independence of blinding — the generalisation of
  condition O-2, which the terminal-surjection review explicitly assumes and
  does not re-verify. R-D4 makes it as close to unconditional as the platform
  allows; it does not prove it.
* **O-R3** The run-wide joint law at fixed challenges, including the
  sequencing surface (block `k`'s opening is public before block `k+1`'s
  masks are used — the layout check's O-3, unchanged by the choice of
  boundary object) and **all three commitments that hold an interior
  boundary plane** (`A_k`, `B_k`, `A_{k+1}`), since a deficiency in any one
  of them leaks the same plane.
* **O-R4** The refusal channel at run scale: `12 × 2^-62` challenge-only and
  `12 × 2^-112` input-dependent, to be **stated** in any run statement;
  `ZkRng::from_os` failing closed at any of its **49** calls, including six
  minutes in; and the operational rule that a refusal is terminal for the
  **whole** run.
* **O-R5** The run capture format and writer, in a **new** file — never an
  edit to `native_capture.rs` (ruling M-8, §7.8) — plus a deliberate rise of
  the Python ingestion bound.
* **O-R6** The run-level "one opening per commitment / every claim
  discharged" check in the verifier (R-D7), as a regression guard.
* **O-R7** ~~The D12a amendment recorded in `ZK60_DECISIONS.md`~~ —
  **DISCHARGED**: D12a is in the register, recorded 2026-09-20 (§6).
* **O-R8** The boundary's scale tied to the **approved calibration** — a
  **correctness** obligation, not a privacy one (§5.1, R-D14, BLOCKING B3).

**Inherited, and made heavier by a run:**

* The one-block privacy statement is a **draft not in force**, pending D19,
  D20, D21, and is scoped to the **toy** profile "and no other".
* The joint-view gate is **owed from the start** at the rung and at 125M,
  for one block, before any run gate means anything.
* D8 and D11 remain open for the run's two external endpoints; D18 says the
  prover seals them for the first MVP.
* The sampler residual for a run is **2^-69.3** per run and grows linearly
  across runs (**2^-49.4** at a million).
* `H`'s deliberate shared-pair exception (the zero-sum rows) is unchanged by
  a run, but it is the precedent showing that "pairs are disjoint" must be
  checked per commitment, not assumed.

### 8.3 What I did not check

* **I built nothing and ran nothing.** No cargo, no prover, no Rust test, no
  benchmark. Every "[MODEL]" figure is arithmetic over measured parts.
* I did not re-derive the generic-rank lemma, the terminal-surjection
  Proposition or the joint-law composition; I read the dispositions and the
  review and took their statements and their stated hypotheses as given.
* The masking commitment's coefficient count enters the draw total as a
  **bound**, not an exact count (the per-slot `L_s` at 125M was not
  recomputed); it moves the total by under 0.06% and cannot move the
  residual at one decimal.
* The **option-B receipt figure is a sketch**: it charges each seam one extra
  `A` group and two extra `A` rows and does not model the slot re-cut that
  option B forces on interior blocks. The sign (B is smaller) is safe; the
  digits are not.
* The rung's `A 623 / H 576` row counts come from
  `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §9a via a delegated read, not from
  running `Shape::rung().totals()`. The 125M counts (`5,681 / 7,120`, groups
  `36 / 9`, receipt `40,782,792`) I checked against `grow_tests.rs`
  `MODEL_M125` and reproduced arithmetically.
* I did not verify that a real 12-block checkpoint's public weights raise no
  statement-handling problem; the proof arithmetic is indifferent to it, the
  plumbing may not be. (Their **memory** term is no longer unaccounted: the
  check counted 6.3 MiB per block from the `Vec<i8>` fields themselves, 75.0
  MiB for twelve, of which +68.8 MiB is new against the measured block, and
  §3 now carries it — CORRECTION C5.)
* I did not examine any GPU or device path — this module has none — nor the
  zkVM line, nor form E.
* I did not check whether `Layout`/`Shape` refusals are complete for a run
  shape (`L` out of range, a boundary geometry that disagrees with the
  declared rows); those refusals do not exist yet and belong to R3.
* I read the two IO slot definitions and confirmed by grep that
  `b.endpoint` is called at exactly one site; I did **not** read all
  twenty-three slot definitions line by line.
* The draft said "nothing here has been attacked by an independent checker".
  **It has been**: `ZK60_PRIVATE_RUN_MULTI_BLOCK_CHECK.md` (delegated Opus
  agent, told to assume the draft wrong, read against the real code, with
  evidence in `results/zk60_private_run_multi_block_check/`). Its four
  blocking items, thirteen corrections and eleven omitted conditions are
  applied above, subject to the security owner's rulings M-1 … M-8 in
  `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md`. What the checker in turn did
  **not** do is listed in its own final section: it built nothing and ran
  nothing, its joint-rank model covers the group and proximity vector
  channel only and is **not** a privacy result, and it did not re-derive the
  generic-rank lemma, the terminal-surjection Proposition or the joint-law
  composition.

## Revision record (2026-09-20)

Applied against `ZK60_PRIVATE_RUN_MULTI_BLOCK_CHECK.md` (B1 … B4, C1 … C13,
O1 … O11) and `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` (M-1 … M-8).
Where a ruling differed from the draft or the check, the ruling won.

| item | sections changed | what changed |
|---|---|---|
| **B1** | plain words, §2.8 (new), §7.7, §8.1 R-D12 | the run's soundness error is stated: about 2^-97.46 for `L = 12` [COUNTED], from 12 × 2^-101.1 and 11 × 2^-105.61; noted as the same 97-bit level D3 accepted for the zkVM; acceptance opened as a project-owner decision |
| **B2** | plain words, §3 (peak block, failure mode 5), §7.3 item 8 | segment flushing made an invariant of the run driver; +423 MiB unflushed named; modelled peak 10.74 GiB flushed, 11.15 GiB unflushed |
| **B3** | §2.1 calibration bullet, §5.1 O-R8 (new), §7.3 item 11, §8.1 R-D14, §8.2 | D12 item 5 carried into the run as a **correctness** obligation: one shared scale field per boundary, one calibration identity over all thirteen, two acceptance tests |
| **B4** | §1.2, §5.1 O-R1 table, §7.1 fifth case, §7.2 | the row count is **derived**, never accepted; the 37-row geometry (rank 5, disclosed 1) is shown to be accepted by `audit_claims` and must be refused by the module by name |
| **C1** | §5.2 item 1, §7.2 | `open_zk` **borrows** (`pcs.rs:915`); the consumed-by-value discipline lives on the `boundary.rs` wrapper's `into_opening(self, …)`, not on the opening call |
| **C2** | §1.1 | today's five non-data rows corrected: pair, **proximity pair** (the `det(rho[prox], rho[prox+1]) ≠ 0` condition is load-bearing), one spare — not "two further random rows" |
| **C3** | §1.5 | the empirical pad margin withdrawn (toy captures, `enc_cols = 1024`); `H-pad` shown to hold structurally at every shape for any number of groups |
| **C4** | §2.7 property 1 | the "a prover cannot adapt the boundary to block `k`'s challenges" reason withdrawn as over-strong: no challenge is drawn between steps 2 and 3; the binding requirement is only "before slots 21/22's challenges" |
| **C5** | §3, §8.3 | eleven extra public statements counted: 6.3 MiB per block, +68.8 MiB at the peak |
| **C6** | plain words, §4.2, §7.7 | verify 12.5 s wall (12.3 s of algebra plus 12 × 0.015 s of decoding) |
| **C7** | §4.2, §7.6, §8.1 R-D6 | one framing, counted once at the specified 96 B header + 40 B trailer: segments 40,033,352 / 40,301,640 / 41,051,176 B; R6's byte-exact acceptance uses those figures |
| **C8** | §4.3, §8.1 R-D7 | check 4 restated as a regression guard on the verifier's own path; the claim that it upgrades a promise to a check is dropped |
| **C9** | §0 labels, §5.3 | `run_arithmetic.py:309-310`'s six-mask-row slip for a 36-row endpoint recorded; the script is evidence and is **not edited**; its line is superseded by the check's `run_recount.py`; corrected count 109,337,160, headline 2^-69.3 unchanged |
| **C10** | §5.4 | the pad-budget *statistics* do not transfer, the *condition* holds structurally — said which |
| **C11** | §6 | the citation corrected to D12 **item 3** (carried by the register's D12a text, which replaces the draft's proposed text) |
| **C12** | §6 | joining finished runs "would then still require D8 and D11 to be discharged" (register text) |
| **C13** | §7.8 | the seven permitted sites that move, tabulated, with the two M-7 removes marked |
| **O1** | §7.8 | included in the C13 table, with `private_block.rs:513-515`'s by-name refusal of a 36-row endpoint called out and then removed from the build by M-7 |
| **O2** | §1.3 | "seam early" is a slot-schedule re-cut (`run_slot` refuses out-of-order slots), not a reordering — against option B |
| **O3** | §3, §7.3 item 8, §7.4 | per-stage high-water marks printed and asserted non-rising; the fragmentation argument stated |
| **O4** | §4.1, §7.3 item 9 | `encoded_len_segment(lay, k, L)` and a per-segment wire bound; the 64 MiB clamp is right for the wrong reason |
| **O5** | §4.3 check 1 | header and trailer are outside the Fiat–Shamir chain, never absorbed, and are **compared, never adopted** |
| **O6** | §4.4 | a verifier that stops after segment `k` knows nothing; a partial run is not a proof of a prefix |
| **O7** | §5.1 O-R3, §5.4, §8.2 | all **three** commitments holding an interior boundary plane must be ranked |
| **O8** | §5.2, §6 | the boundary plane's int16 class is proved at both ends (`layout.rs:682`, `:704`); D12 item 4's analogue is discharged twice |
| **O9** | §2.7 property 2, §7.3 item 10, §7.4 | acceptance tests for a same-point boundary claim pair and for a schedule opening `B_k` in stage `k` (a prover-side refusal by name) |
| **O10** | §5.1 O-R1, §8.2 | the joint rank is computed **restricted to the reserved mask rows**, and the report says which columns it ranked |
| **O11** | §5.1 O-R4, §8.2 | `ZkRng::from_os` runs 49 times per run and fails closed, possibly six minutes in |
| **M-1** | §1.1, §1.2, §5.1, §7.1, §7.2, §8.1 R-D2 | rows derived (`data + 2·sites + 2`), other geometries refused by name, today's five rows described correctly, the gate ranks the reserved rows |
| **M-2** | plain words, §2.8, §7.7, §8.1 R-D12 | about 2^-97.5 stated wherever the run is described, labelled [COUNTED], with acceptance named as the project owner's and pending |
| **M-3** | plain words, §3, §7.3, §7.4, §7.6 | segments flushed; the two missing memory terms added; peak 10.74 GiB with the arithmetic shown and 11.15 GiB named as what flushing avoids; per-stage HWM required |
| **M-4** | §2.1, §5.1 O-R8, §7.3 item 11, §8.1 R-D14 | one shared scale field per boundary, one calibration identity over all thirteen, with the ruling's two tests |
| **M-5** | §6 | the amendment section replaced by the register's D12a text with a pointer to `ZK60_DECISIONS.md`; the draft's proposed text removed |
| **M-6** | §4.2, §4.3 check 2, §7.6, §8.1 R-D6, R-D13 | one framing counted once; the header state re-derived and compared, never absorbed or adopted; exactly `L` segments, `L` the verifier's own; the 484 MB receipt recorded as a product fact for the project owner, not a blocker |
| **M-7** | §1.2, §3, §4.2, §5.3, §7.6, §7.8, §8.1 R-D2 | the 36-row external endpoint removed from the design; rows (37), IO memory (88.8 MiB interior, 88.2 MiB stage 1), bytes (+2,048 per endpoint) and draws (109,370,440, unchanged) recomputed; the seven permitted sites listed with the two M-7 removes marked |
| **M-8** | §5.4, §7.4, §7.8, §8.2 O-R5 | the gate is three blocks at the development rung, all three roles ranked jointly, both controls included, capture by a **new** run-capture module; the draft's option of extending `native_capture.rs` withdrawn |
| **time** | plain words, §0 item 3, §5.1 O-R4, §7.7, §8.1 R-D10 | 6.26 minutes of proving and 12.5 s of verifying [COUNTED]; every "5.3 minutes", "6.3" and "12.3 s" corrected, keeping the labels |
| **the script** | §0 labels, §5.3 | `run_arithmetic.py` is the draft's evidence and is **not edited**; the corrected figure is given in the text with the supersession named |
| **status line** | header | replaced as the disposition directs |

*(revision complete — paper only; nothing here has been built or run, and
nothing here is a privacy acceptance)*
