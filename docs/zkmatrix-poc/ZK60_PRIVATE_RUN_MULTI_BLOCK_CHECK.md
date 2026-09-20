# Adversarial check of the private multi-block RUN design

INDEPENDENT ADVERSARIAL CHECK of a delegated draft design — delegated Opus
agent, 2026-09-20. Paper and Python only; NOT a privacy acceptance.

Target: `docs/zkmatrix-poc/ZK60_PRIVATE_RUN_MULTI_BLOCK.md` (1,444 lines,
committed 2026-09-20) with `results/zk60_private_run_multi_block/run_arithmetic.py`.
Code read, read-only, in `/home/victor/wt-zk60-block125m` (branch
`zk60-private-block-125m`) and in the main tree.

Evidence for this check: `results/zk60_private_run_multi_block_check/`.

Labels used below: **VERIFIED IN THE CODE** (file:line), **RECOMPUTED** (my
own script, named), **MY OWN ARGUMENT** (paper, not verified), **COULD NOT
VERIFY**.

## A1. The boundary object: one commitment, two claim sites, one opening

**Verdict: the construction stands, the row budget is right for a reason the
draft does not give, and one of the draft's supporting descriptions of the
code is wrong.**

### A1.1 Can ONE `open_zk` call take claims accumulated across two stages?

**YES, with no change to any forbidden file.** VERIFIED IN THE CODE:

* `pcs::open_zk(cmz: &CommittedZk<E>, claims: &[ZClaim], tr: &mut Transcript)`
  (`zkp-core/src/pcs.rs:915`) takes the commitment **by shared reference** and
  the claims **as a slice the caller owns**. Nothing about where the claims
  came from, or when, reaches this function. `pcs::verify_zk`
  (`:947-955`) has the same signature shape and re-forms the groups itself
  from the claims it is handed (`:966`).
* Nothing consumes the owner early. In the block the owner is an ordinary
  local: `let mut a = pcs::commit_zk_owned(...)` … `pcs::open_zk(&a, &ac, &mut
  tr); drop(a);` (`protocol.rs:547`, `:681-682`). The endpoints are the same
  (`:689-690`, `:693-694`). A run driver holding `CommittedZk` values in a
  `Vec` across stages needs no new API.
* The "no `Clone`, no getter, consumed by value" discipline lives **one level
  up**, on `PreparedPlaneG` (`endpoint_g.rs:146-162`: `into_endpoint(self)`),
  not on `CommittedZk` — whose `data`, `pads`, `salts`, `mask_rows`,
  `prox_mask_row` are all `pub` (`pcs.rs:551-564`) and which the block reads
  directly (`protocol.rs:665`). So the draft's §5.2 requirement "the boundary
  owner must be consumed by the opening call, not borrowed" **cannot be met by
  calling `open_zk`**, which borrows. It has to be met by a `boundary.rs`
  wrapper that owns the `CommittedZk`, exposes only `root()`, and has an
  `into_opening(self, claims, tr)` that consumes itself. That is exactly what
  R2 should build, and the draft should say so rather than implying `open_zk`
  itself enforces it. **CORRECTION 1.**
* The pending-claims structure crosses a stage boundary as data:
  `Acc.claims: [Vec<ZClaim>; 4]` indexed by `Cm` (`argument.rs:111-120`,
  `:40-45`), filled at `argument.rs:389-396`. The run driver takes
  `acc.claims[Cm::Out]` out of stage `k` and concatenates it with
  `acc.claims[Cm::In]` of stage `k+1`. **`Cm` has exactly four variants and
  `ProverData.data` is `[&[Fp]; 4]` (`argument.rs:99-103`) — option A needs
  exactly four pointers (`A_k`, `H_k`, `B_{k−1}`, `B_k`), so neither type
  moves.** That is a real and unstated advantage of option A over option B,
  which needs a fifth of each; the draft asserts the fifth-pointer cost for B
  without noting that A fits the existing four exactly. VERIFIED.

### A1.2 Two claims, one group or two?

**Two, and the draft's reasoning is right.** VERIFIED IN THE CODE: the PCS key
is `ZKey { tail, c0, len }` (`pcs.rs:744-749`); for a slice of a row or more
it is `tail = point[ls − log_cols ..]`, `c0 = 0`, `len = n`
(`pcs.rs:774-782`). At the boundary `ls = 19`, `log_cols = 14`, so the key is
the **last 14 of the 19 point coordinates**. `private_block` mirrors this in
`part_key_at` (`protocol.rs:164-170`) and forms the same first-occurrence
groups in `opening_groups_at` (`:178-191`). Two claims raised in two different
blocks' slot loops draw their points from two different transcript states, so
the keys differ with probability `1 − (p⁻²)¹⁴ = 1 − 2^-1792`. On a collision
the formed count (1) would not equal the declared count (2) and
`check_opening` refuses (`protocol.rs:279-281`) — a completeness failure, not
an unsoundness, exactly as the draft says. VERIFIED.

The mask parts carry `log_size = min(p.log, log_n) = 14` and the **same**
tail (`argument.rs:250-260`), so a claim's three parts share one key and
`opening_groups_at`'s "parts with different column weights" refusal
(`protocol.rs:182-183`) is not tripped. VERIFIED.

### A1.3 The five rows of today's endpoint, and the six of the boundary

The draft says today's five reserved rows are "the terminal pair at
`(data, data+1)`, the proximity row at `data+2`, and **two further random
rows**". That is **not what the code requires**. VERIFIED IN THE CODE:

| row | role | enforced at |
|---|---|---|
| `data`, `data+1` | the terminal pair, weights exactly `(cm, cm·U)` | `argument.rs:258-260`; `audit_claims` `protocol.rs:237-241` |
| `data+2` | `prox_mask_row`; the proximity rho must be nonzero there | `endpoint_g.rs:206`; `pcs::assert_mask_sites` `:889-890` |
| `data+3` | **load-bearing, not spare**: `determinant(rho[prox], rho[prox+1])` must be nonzero | `check_opening_challenges` `protocol.rs:266-269` |
| `data+4` | genuinely spare | — |

So the real budget is `pair (2) + proximity PAIR (2) + one spare (1)`, and
`data + 2·sites + 2` is the same budget **minus the spare**, not "the `A`/`H`
discipline instead of the seam's". **CORRECTION 2.**

This matters because it supplies the reason the draft never gives. The
proximity **pair** is not an audit convenience: it is a hiding requirement.
See A1.4.

### A1.4 The joint rank, computed exactly (RECOMPUTED)

Script: `results/zk60_private_run_multi_block_check/boundary_rank.py`, output
`boundary_rank.txt`. Exact Goldilocks arithmetic, `Fp2 = Fp[u]/(u²−7)`
(`zkp-core/src/field.rs:2`, `:131`, `NONRESIDUE = 7`). The model is mine: the
mask rows are free base-field unknowns (`endpoint_g.rs:200-202` writes
`rng.fp()`), the three published vectors are `rho_g^T[M|pads]`
(`pcs.rs:859-875`), and hiding at a message column asks whether the Fp-linear
map `Fp^{#mask rows} → Fp2^{G+1} ≅ Fp^{2(G+1)}` is surjective — i.e. whether
the `2(G+1) × #maskrows` real matrix has full row rank. Prediction before
running: 6 for the honest case, 4 for the shared pair, 5 for a single
proximity row.

| case | rows | rank on the mask rows | disclosed |
|---|---|---|---|
| honest: two claims, **disjoint** pairs, proximity **pair** | 38 | **6 of 6** | **0** |
| negative control: both claims on pair 0 | 38 | 4 | **2** |
| negative control: proximity **row** only (`data + 2·sites + 1`) | 37 | 5 | **1** |
| the pad block (all 38 rows free) | 38 | 6 | 0 |

The shared-pair control fired in **40/40** random draws; the honest case was
degenerate in **0/40**.

Three things follow.

1. **The draft's O-R1 expectation is confirmed at the 125M geometry, for the
   linear-view channel only.** Disclosed 0, jointly over both groups, not as
   a sum of marginals.
2. **`rows = data + 2·sites + 2` is a HIDING requirement, not a convenience.**
   With one proximity row the joint rank is 5 and one real dimension is
   disclosed. The draft justifies the geometry only as "exactly the geometry
   `audit_claims` is written for"; the stronger and more durable reason is
   that `2(G+1)` real dimensions need `2(G+1)` free base-field mask
   coordinates, and with `sites` claim sites plus a proximity vector that is
   exactly `2·sites + 2` rows. **ERRATUM: R-D2's justification is weaker than
   the truth.** It also explains, retrospectively, why
   `check_opening_challenges` insists on `det(rho[prox], rho[prox+1]) ≠ 0`.
3. **A rank computed over ALL rows hides the failure.** In every control above
   the rank over all 38 rows is 6; only the restriction to the reserved rows
   separates them. This is the same artefact the terminal-surjection review
   recorded as "rises back to 4 when the data is added". Any gate stage that
   reports a rank must state which columns it ranked. **OMITTED CONDITION:
   the draft's O-R1 says "compute the rank jointly" but not "restricted to the
   reserved mask rows".**

### A1.5 Does a second claim consume a pad?

**No — and the reason is stronger than the draft's.** The draft argues from a
measured margin ("246 distinct positions on `A`, 241–246 on the endpoints,
against 256 pads"). Two problems.

* Those counts come from **toy** captures, where `enc_cols = 1024` and 256
  draws collide often (expected distinct ≈ 226). At 125M `enc_cols = 65,536`
  and the expected distinct count is ≈ 255.5. Quoting one shape's sampling
  statistics at another is the exact failure mode D17/G-2 exist to prevent.
  **CORRECTION 3.**
* The condition cannot fail at any shape. VERIFIED + MY OWN ARGUMENT: the
  opened indices are 256 draws (`open_zk` `pcs.rs:928`, one
  `challenge_indices` call serving **every** group), so `distinct ≤ 256`;
  `q_pad = num_col_checks` (`ZkOpts::standard`, `pcs.rs:542-543`) and
  `commit_zk_owned_with` asserts `q_pad ≥ num_col_checks` (`:670`). The pad
  contribution at an opened position is `Z_n(x_j)·g_pad(x_j)` with `g_pad` of
  256 coefficients on the coset (`encode_row_zk`, `:618-637`, and
  `coset_powers`' assertion that the coset misses the subgroup, `:612`), so
  the map from pads to the values at `distinct` distinct positions is a
  full-rank Vandermonde of rank `distinct`. `H-pad` therefore holds
  structurally, at every shape, for any number of groups.

Everything else in the draft's "what a second claim consumes" list checks out:
one more group vector of `16,640 × 16 = 266,240` B (`wire.rs:75-77`), one more
`lambda` (`pcs.rs:839`), one more zero-`lambda` refusal
(`check_opening_challenges` `protocol.rs:261-265`, which takes per-group member
counts and passes `[1, 1]`), and the joint-rank obligation. The replay in
`check_opening_challenges` matches `zk_rhos` exactly for two groups, because
`challenge_fp2_vec(n)` is literally `n` successive `challenge_fp2()`
(`transcript.rs:114-116`). VERIFIED.

### A1.6 `audit_claims` at 38 rows

**Applies verbatim. VERIFIED** (`protocol.rs:208-252`), at `rows = 38`,
`prox = 36`, `site_rows = [32,33,34,35]`: `prox + 2 == rows` ✔ (`:210`),
`site_rows.len() % 2 == 0` ✔, each non-sum claim must touch exactly two
adjacent site rows aligned to the pair grid ✔ (`:237-241`), no part may reach
row ≥ 36 ✔ (`:219-221`), zero pair coefficient refused ✔ (`:223-227`), and
`uses[r] == 1` on every site row ✔ (`:248-250`) — which is the pair-exclusivity
check, and it fires on the shared-pair control of A1.4. `check_endpoint_opening`
(`:333-347`) hard-codes one claim of three parts and cannot serve the boundary,
as the draft says. Both sides call the audit: prover `protocol.rs:680`, `:684`,
`:688`, `:692`; verifier `:762`, `:769`, `:779`. VERIFIED.

**What the draft understates: the "5" is spread over five call sites that a
run must change.** VERIFIED IN THE CODE: `endpoint_g::MASK_ROWS = 5`
(`:51`, and it is inside the spec **digest**, `:136`); `ENDPOINT_MASK_ROWS = 5`
with `endpoint_geometry = (rows, rows−5, rows−3)` (`protocol.rs:298`,
`:313-327`); `argument.rs:521`'s `mask_row = sh.endpoint_rows − 5`;
`private_block.rs:513-515`, which **refuses** any shape whose declared
`endpoint_rows` is not `data + 5`; `layout.rs:1043`'s node-shaped-column check,
which lists the endpoint but would have to list the boundary;
`shape.rs:706`'s `endpoint_openings: 2 * opening(1, endpoint_rows, …)` and
`wire.rs:93`, `:116`, `:224`, all of which hard-code **one** group and **two**
IO openings. R-D2's "give the external endpoints the same construction with
`sites = 1`" (36 rows) **trips `private_block.rs:513-515` by name**. None of
these is a forbidden file, but "no existing byte moves" is not the same as "no
existing code moves", and the draft's §7.8 list omits all seven.
**OMITTED CONDITION 1.**

One thing R-D2 buys that the draft does not claim, and should: with **one**
boundary commitment there is **one** declared scale tag, claimed by both
blocks, so the D12-item-5 hole ("a tag-equality check would pass on a
factor-of-8 mismatch") has no boundary to open at. Option B compares two
blocks' separately declared scales at every seam and keeps that hole. See A8.

## A2. Option B: is the memory really a near-tie?

**Yes. I tried to break this and could not. The draft is right and the
hypothesis that B costs 13 GiB is wrong — provided one ordering condition the
draft states.**

RECOMPUTED (`run_recount.py`, section 2) from `pcs.rs:665-699`'s own
allocations: `A_k`'s owner at 125M is

```
data     5,681 × 16,384 × 8 =   744,620,032 B
encoded  5,681 × 65,536 × 8 = 2,978,480,128 B
pads 11,634,688 B, salts 2,097,152 B, tree ~4,194,272 B
                              ---------------
                              3,741,026,272 B = 3,568 MiB
```

which matches the measured drop at `drop(a)` (8,727 → 5,177 MiB = **3,550
MiB**, timing log line 46). The encoded matrix alone is 2.78 GiB, so the
hypothesis is arithmetically right that holding `A_k` through `H_{k+1}`'s
commit would put the process at `8,615 + 3,550 = 12,165` MiB **before** the
slot tables, i.e. over the 12 GiB ceiling the measured run used. The draft
says exactly this, as failure mode 1 of its §3.

But that is not option B's schedule. Under "seam early" — commit `A_{k+1}`,
commit `M_{k+1}`, run the seam slot, open and drop `A_k`, **then** draw
`(β,γ,α)_{k+1}` and commit `H_{k+1}` — the two `A`s coexist only at the
`A`-commit point, measured at **5,085 MiB** (timing log line 14), giving
`5,085 + 3,550 = 8,635` MiB, which is 2,202 MiB **below** the 10,837 MiB peak
that arrives later at the softmax zero-check. RECOMPUTED, and it confirms the
draft. **Option B is a near-tie on memory. CONFIRMED, not refuted.**

Two conditions the draft names, and one it does not:

1. Stated: `A_k` must be opened before `H_{k+1}` is committed.
2. Stated: this forces the segment boundary into the middle of a stage.
3. **Not stated:** "seam early" is not a reordering of existing slots, it is a
   different slot schedule. `run_slot` refuses unless `s == acc.cs.len()`
   (`argument.rs:289`), so the seam has to *be* slot 0 of the interior block,
   which means the whole `Acc` order, the mask schedule and the schedule
   digest are re-cut — on top of the `N_SLOTS 23 → 22`, `M_ROWS 50 → 48`
   changes the draft already counts. It also moves the LogUp challenge draw
   after a slot for the first time in this module. None of that is unsound;
   it is more work than "one fewer slot" sounds. **OMITTED CONDITION 2**
   (against option B, so it strengthens the recommendation).

**Is there a hybrid — open `A_k` on schedule but keep a deferred claim?**
No. `open_zk` draws the group `lambda`s from the claims it is given
(`pcs.rs:918-919`) and then the 256 column indices (`:928`); a claim that
arrives afterwards cannot be folded into vectors that are already absorbed,
and folding it into a second opening is a second opening of the commitment,
which is the one thing D12 item 1 forbids outright. CONFIRMED: no hybrid.

**The recommendation (option A) is confirmed, and for better reasons than the
draft gives.** The draft's three deciding arguments stand; add two:

* option A fits the existing `Cm`/`ProverData`/`Acc` arity of four exactly
  (A1.1), while option B needs a fifth of each;
* option A leaves exactly one declared scale per boundary, closing a
  D12-item-5 surface that option B keeps open (A1.6, A8).

## A3. Transcript order and soundness

**The order is sound. The soundness FIGURE, which the section's own title
promises, is missing — BLOCKING.**

### A3.1 What the header absorbs, and where each challenge is drawn

VERIFIED IN THE CODE against `protocol::transcript` (`:91-101`) and
`prove_inner_at` (`:455-711`):

| absorb / draw | code | the draft's stage version |
|---|---|---|
| `Transcript::new(sh.profile)` | `:93` | run profile string ✔ |
| `"expected-IO"` = both external roots | `:94`, `private_block.rs` `ExpectedIo` | run's two external roots ✔ |
| `"public-statement"` = the block digest | `:95` | digest over the `L` block digests ✔ |
| `"parameters"` = the parameter line, which since stage 9 carries `endpoint-log_n/rate/pad/rows` in the clear | `:96`, `:106-126` | run line + `L` + boundary geometry ✔ (S11b-F4 honoured) |
| `"calibration"` | `:98` | unchanged — **see A8, this is a gap** |
| `"schedule"` = `lay.schedule_digest()` | `:99` | run schedule ✔ |
| `A` root with rows and log-cols | `:550-551` (`absorb_root` `:128-132`) | step 3 ✔ |
| `M` root | `:561` | step 4 ✔ |
| `(β, γ, α)` | `:567-569`, after `A` (which carries `A_MU8/A_MEXP/A_MACT`, `:520-524`) and after `M` | step 5 ✔ |
| `H` root | `:658-659` | step 6 ✔ |
| per-slot: `b"pb-slot"`, CFS `c`, scalar, sumcheck rounds, terminals | `argument.rs:306-310`, `:326-328`, `:386` | step 7 ✔ |
| `M` opening, then `A`, `H`, IO openings | `:675-695` | step 8 ✔ |

**No challenge is drawn before what it must bind.** The one new ordering
constraint — `B_{k−1}`'s opening `lambda`s and column indices must follow both
its claims, hence must be squeezed in stage `k` — is exactly why the draft
puts the opening in stage `k+1`, and it is correct. VERIFIED that the claim
each slot raises is built **outside** the prove/verify match
(`argument.rs:389-396`), so the verifier computes the pending boundary claim
itself; it never reads it from the frame. That answers A6's question in
advance.

`B_k` before `A_k` (step 2 before step 3): **immaterial for soundness**, since
no challenge is drawn between them. The draft's stated reason ("so that a
prover cannot choose the boundary after seeing block `k`'s challenges") is
satisfied by either order. Not an error; an over-strong reason.
**CORRECTION 4.**

### A3.2 The soundness figure the draft never gives

The section is titled "The transcript order and **soundness**" and contains no
soundness error at all. `grep` over the whole 1,444 lines finds no union
bound, no `2^-101`, no `2^-97`. The project has the per-block figure:

* `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md:510` — **one 125M block ≈ 2^-101.1**
  (four PCS openings at 2^-103.61 union plus the dominant LogUp term
  `N/|F_p²| = 2^-101.37` at 103.8M lookups);
* `ZK60_PRIVATE_BLOCK_125M_LAYOUT_CHECK.md:1102` — 2^-105.61 per opening,
  and it already publishes "**twelve-block 2^-97.5**".

RECOMPUTED (`run_recount.py`, section 4): `12 × 2^-101.1 = 2^-97.52`; the run
adds 11 boundary PCS openings at 2^-105.61 each = 2^-102.15; total

```
RUN, L = 12, at the 125M geometry  ≈  2^-97.46      [RECOMPUTED]
```

Two consequences the draft owes a reader:

* a twelve-block run sits at **about 97 bits**, which is the same level the
  project already accepted **by explicit ruling** for the zkVM line (D3,
  "97-bit conjectured accepted"). That is a statement the security owner
  should make deliberately for the native line too, not inherit silently.
* it is 3.6 bits worse than one block, and it degrades as `log2 L`, so an 8B
  model's 32 blocks would be ≈ 2^-96.1. Worth saying now.

**BLOCKING 1: §2 must state the run's soundness error and its per-block
inputs, and R-D-something must record whether ~2^-97 for a run is accepted.**

### A3.3 The three splicing attacks

1. **A segment produced under a different transcript state.** Rejected. The
   binding is real (every later challenge is squeezed from a BLAKE3 chain over
   all earlier absorbed bytes, `transcript.rs:44-52`, `:85-94`), and the
   explicit header check compares the verifier's own `tr.state()` / counter
   (`transcript.rs:133-136`, and `clone_state` at `:139-141` shows state+counter
   is the whole state) before parsing. VERIFIED that the transcript state is
   32 bytes plus a `u64` counter, so the draft's "40 bytes" is right.
2. **A dropped last segment.** Rejected, but **not by the empty-table check**
   the draft leans on. It is rejected by "exactly `L` segments seen", and `L`
   comes from the verifier's own statement (`protocol.rs:721-724`'s pattern:
   the verifier builds the layout from its caller's shape, never from the
   frame). The draft's "must end with an empty open-commitment table" is
   **sufficient but redundant** here: with segment `L` dropped, `B_{L−1}` is
   unopened *and* `E_out` is unopened *and* the segment count is wrong — three
   independent refusals. Fine, but see A6 for why check 4 is weaker than the
   draft claims.
3. **A run claiming a smaller `L`.** Cannot arise: `L` is in the verifier's
   statement, in the run profile string, in the `"run-shape"` absorb and in
   the parameter line. A prover asserting `L = 11` is proving a different
   statement under a different transcript. VERIFIED by analogy with
   `wire::decode`, which takes every length from `lay` and requires
   `bytes.len() == encoded_len(lay)` (`wire.rs:196-199`, `:225-227`).

## A4. Memory

**The 88.2 MiB is right to the byte. The peak is not: two things are alive in
a run that a single block never had, and one of them is 423 MiB.**

### A4.1 `B_k`'s resident size — RECOMPUTED, confirms the draft

From `commit_zk_owned_with`'s own allocations (`pcs.rs:665-699`: `pads` `:673`,
`salts` `:674`, `encoded` `:681`, `tree` `:690`, `data` kept `:694`), at
`n = 2^14`, `nn = 2^16`, `q = 256`:

| rows | data | encoded | pads | salts | tree | total |
|---|---|---|---|---|---|---|
| 38 (boundary) | 4.75 MiB | 19.00 | 0.07 | 2.00 | 4.00 | **29.82 MiB** |
| 37 (today's endpoint) | 4.62 | 18.50 | 0.07 | 2.00 | 4.00 | 29.20 MiB |
| 36 (uniform endpoint) | 4.50 | 18.00 | 0.07 | 2.00 | 4.00 | **28.57 MiB** |

`2 × 29.82 + 28.57 = 88.2 MiB` — the draft's figure, exactly. VERIFIED that
the run has at most two boundaries alive (`B_{k−1}` awaiting its opening,
`B_k` just committed) plus `E_out`, because a commitment may be opened once
its claim list is final and no slot of block `k+1` names `A_k`, `H_k` or
`M_k` under option A (`argument.rs:389-396` pushes each claim onto its own
tab's commitment). RECOMPUTED, confirms the draft.

Small transient the draft misses: `commit_zk_owned_with` holds `leaves` and
`salted` simultaneously (`:685-690`), 2 × 2 MiB per commitment. Immaterial.

### A4.2 What ELSE is alive at the peak in a run

The measured 10,837 MiB high-water is at the softmax zero-check with `A` and
`H` resident (timing log line 39). In a run, at that same moment:

* **The witness**: no. It is dropped at the S2 point before `H` is committed
  (`protocol.rs:607-610`), so the 711 MB is not at the peak — in a run either,
  provided the driver builds block `k`'s witness at the top of stage `k`. The
  draft says this (failure mode 3). ✔
* **The boundary planes the prover must hold to commit them**: 1 MB each as
  `i16`, 12 MB for the run. The draft counts this. Note it is an over-count:
  plane `k` can be dropped once `B_k` is committed and block `k+1`'s witness
  is built. ✔ harmless.
* **The `L` blocks' public statements — NOT COUNTED.** RECOMPUTED from
  `AttentionPublic` / `FeedForwardPublic`, whose weights are `Vec<i8>`
  (`private_block.rs:226-233`, `:347-352`) at `d_pad = 768`, `f_pad = 2048`,
  `kv = 256`, `t = 512`: `2·768² + 2·256·768 + 768` attention int8 plus
  `768 + 2·768·2048 + 2048·768` feed-forward int8 = 6,292,992 B, plus
  264,192 B of `i64` rope/exp tables = **6.3 MiB per block**. Twelve are
  **75.0 MiB**; eleven of them are new relative to the measured block:
  **+68.8 MiB**. The draft mentions the 85 MB figure only in §8.3 "what I did
  not check" and never adds it to the peak. **CORRECTION 5.**
* **The finished segments — NOT COUNTED, and this is the big one.** A stage
  ends at 727 MiB resident (timing log line 47), of which ~40 MB is that
  stage's `Receipt` (slots, `mask_open`, `a_open`, `h_open`, `io_open`). If
  the run driver accumulates segments and writes at the end — the obvious
  first implementation — eleven finished segments are resident at stage 12's
  peak: **+423 MiB**. The draft's §3 lists four failure modes and this is not
  one of them. **BLOCKING 2: the driver must serialise each segment and
  release its `Receipt` before the next stage begins, and the L = 2 gate must
  assert it.**

RECOMPUTED peaks:

```
draft                                          10,925 MiB  (10.67 GiB)
+ eleven extra public statements               10,994 MiB  (10.74 GiB)
+ eleven unflushed segments as well            11,417 MiB  (11.15 GiB)
```

11.15 GiB is still inside the 12 GiB ceiling the measured run used, but it is
480 MiB of margin gone for no reason, and the WSL box turns an
out-of-memory event into a whole-box freeze.

### A4.3 Fragmentation across twelve build-and-free cycles

**The draft ignores it. MY OWN ARGUMENT:** the two big buffers (`A` encoded
2.78 GiB, `H` encoded 3.47 GiB) are single allocations far above glibc's
mmap threshold, so they are returned to the OS on free and cannot fragment
the heap; the risk is in the many medium buffers (slot tables of 8.4 M
entries, the LogUp helper columns) cycling twelve times. The sign that would
show it is exactly what the draft's R3/R6 should record and does not: **the
high-water mark per stage, printed for every stage, rising monotonically
across an `L = 2` and an `L = 3` run**. If HWM(stage 2) > HWM(stage 1) by more
than the 29.8 MiB of one extra boundary, fragmentation is real.
**OMITTED CONDITION 3: add per-stage HWM to R3's and R6's acceptance.**

## A5. Time

**Both figures survive. The 6.3 minutes is a generous rounding of 6.26; the
12.3 s omits decoding.** RECOMPUTED (`run_recount.py`, section 3), all inputs
[MEASURED] from `m125-run2-timing.log`.

| | value | source |
|---|---|---|
| prove, one block | 26.539 s | line 6 |
| witness build, one block | 4.69 s | line 5, explicitly outside the prover's table |
| verify, one block | 1.027 s | line 66 |
| encode to bytes | 0.021 s | line 64 |
| decode from bytes | 0.015 s | line 65 |
| `A` commit, 5,681 rows | 2.997 s → 0.527 ms/row | line 14 |

```
12 × (26.539 + 4.69)                    = 374.7 s   (6.25 min)
+ 11 boundary commits at 38 rows        =   0.22 s   [MODEL, A's per-row rate]
+ 11 boundary opens (2 groups, 38 rows) =   0.17 s   [MODEL, endpoint rate ×1.5]
+ 11 extra segment encodes              =   0.23 s
RUN PROVE                               = 375.4 s   (6.26 min)   [RECOMPUTED]
RUN VERIFY  12 × 1.027 = 12.3 s, + 12 × 0.015 decode = 12.5 s    [RECOMPUTED]
```

So **6.3 minutes and 12.3 s both stand**, and R-D10's correction of the old
"5.3 minutes" is right: `12 × 26.539 = 5.31 min` omits the witness build,
which is measured and outside the prover's phase table. Two small things:

* the run's verify is **12.5 s wall** once decoding is counted; the draft
  quotes 12.3 s and lists decoding separately. Say 12.5 s. **CORRECTION 6.**
* the one-block 26.54 s does **not** include the two endpoint commitments,
  which happen in `endpoint_g::prepare` before `prove_inner_at`
  (`protocol.rs:468`'s `check_endpoints` receives them already committed).
  A run's 11 boundary commits happen *inside* the run and so are genuinely
  new work that the per-block table never measured. 0.22 s; immaterial, but
  it is the reason the run is not exactly `12 ×` anything.

## A6. The segmented receipt

**The byte arithmetic reproduces exactly — and then contradicts the design it
is counting. The header state is re-derived, not trusted, which is the right
answer. Check 4 is oversold.**

### A6.1 The sizes reproduce, and the framing does not match §4.3

RECOMPUTED (`run_recount.py`, section 1) from `wire.rs`'s own formula
(`:75-77`, `:87-94`). The block's 40,782,792 B (`grow_tests.rs` `MODEL_M125`)
is reproduced to the byte, with the 23 slot proofs falling out as the 27,456 B
residual. Then:

| | bytes | |
|---|---|---|
| boundary opening (2 groups, 38 rows) | 1,017,856 | draft ✔ |
| external endpoint (1 group, 36 rows) | 747,520 | draft ✔ |
| segment 1 | 40,031,208 | draft ✔ |
| segments 2…11 | 40,301,544 | draft ✔ |
| segment 12 | 41,049,032 | draft ✔ |
| run total | 484,095,680 | draft ✔ |

Every number in the draft's §4.2 table is right **for a segment framed by 40
bytes**, i.e. `wire::HEADER` = magic (8) + binding digest (32), with no
trailer. But §4.3 specifies a header of magic + run-profile digest + `L` +
segment index + 32-byte transcript state + 8-byte counter = **96 B**, and a
trailer of state + counter = **40 B**. That is **+96 B per segment** over what
was counted:

```
design's real sizes   40,031,304 / 40,301,640 / 41,049,128
design's real total   484,096,832 B
```

Immaterial in bytes, material as a gate: **R6's acceptance says "two segments
of 40,031,208 and 41,049,032 bytes EXACTLY … a segment length that is not the
counted one is a failed acceptance". Built to §4.3, the first honest run
fails its own acceptance by 96 bytes per segment.** **CORRECTION 7**, and it
is the kind that costs an afternoon.

Second, smaller: `wire::decode` requires `bytes.len() == encoded_len(lay)`
exactly (`:197`) and `wire_bound(lay) = min(receipt_bytes().total, 64 MiB)`
(`:38-45`). A run has **three** segment lengths, so the run's wire module needs
`encoded_len_segment(lay, k, L)` and a per-segment bound; `receipt_bytes()`
for a run profile would return 484 MB and the `min` would silently clamp the
bound to 64 MiB, which happens to be right but for the wrong reason. Worth one
explicit line in R3. **OMITTED CONDITION 4.**

### A6.2 Is the header's transcript state trusted or re-derived?

**Re-derived, which is the only acceptable answer, and the draft gets it
right** ("the verifier compares against its own running `tr.state()` /
counter … and refuses on mismatch"). VERIFIED that the whole transcript state
is `[u8; 32]` plus a `u64` counter and nothing else (`transcript.rs:17-22`,
`clone_state` `:139-141`), so 40 bytes is the complete state and comparing it
is meaningful.

Two conditions the draft does not state, and must:

* **The header and trailer must NOT be absorbed into the transcript.** If they
  were, the state field would have to predict a hash of itself. So the framing
  is *outside* the Fiat–Shamir chain: it is redundant, comparable data, never
  input. Say it. **OMITTED CONDITION 5.**
* **The verifier must COMPARE, never ADOPT.** A verifier that seeded its
  transcript from the header would accept any prover-chosen chain. One line in
  R3's acceptance: "a segment whose header state is correct but whose bytes
  were produced under another chain is rejected" is already covered by attack
  4; add "a verifier fed only segment 3 refuses, because its own state after
  the header is not segment 3's".

Is the state a function of hidden data? It is a hash of published bytes only
(roots, masked scalars, masked round polynomials, masked group vectors,
opened columns). It is therefore a deterministic function of the receipt and
adds no channel — MY OWN ARGUMENT, and it is the same argument that lets the
receipt be published at all.

### A6.3 Parallel or in order?

**In order for the chain, parallel for the algebra.** MY OWN ARGUMENT: the
sequence of absorbs and squeezes is fixed by the schedule and does not depend
on any check's outcome, so a verifier can do one cheap pass that only
absorbs/squeezes (BLAKE3 over 484 MB, well under a second) to recover all `L`
start states, then verify the `L` segments' sumchecks and PCS openings in
parallel — 12 × 1.03 s of algebra over however many cores. That is worth
saying, because §4.2's "12.3 s streaming" reads as a hard serial floor and it
is not. The draft never claims in-order-only; it also never says this.

### A6.4 What a verifier that stops after segment `k` knows

**Nothing about the run**, and the draft should say so in §4.4 rather than
leave it implied. Concretely: after segment `k` the verifier has seen `k`
blocks' slot relations discharged against commitments, but `B_k` is unopened,
so even block `k`'s own output relation is not closed; `E_out` is unopened;
and the statement being proved is a property of the whole chain. A partial
run is not a proof of a prefix of the run. **OMITTED CONDITION 6.**

### A6.5 Who carries the pending claim?

**The verifier, from its own computation.** VERIFIED IN THE CODE: the claim a
slot raises is pushed at `argument.rs:389-396`, which sits **after** the
`match side` and therefore runs identically on the `Side::Verify` arm; the
verifier's `verify_inner_at` then feeds `acc.claims` into `check_opening` and
`pcs::verify_zk` (`protocol.rs:761-782`). Nothing about a claim is read from
the frame; only the slot terminals are, and they are absorbed. So the ~1 KB
the draft's §4.4 table carries across a segment boundary is the verifier's own
`ZClaim` (3 parts × a 19-coordinate `Fp2` point ≈ 912 B + coefficients).
CONFIRMED.

### A6.6 Check 4 is oversold

The draft calls the run-level "every commitment opened exactly once, every
claim discharged" table "the only genuinely new verifier obligation" and
"what makes the run is one transcript a property the verifier enforces rather
than the prover promises". **That is too strong.** The run layout — which
commitments exist, which are opened where — is a function of the verifier's
**own** statement and `L`, exactly as the block layout is today
(`protocol.rs:724`, `wire.rs:196-199` take every count from `lay`). A prover
cannot present a different set of commitments or openings without changing a
frame length or the chain. So check 4 is a **regression guard on the
verifier's own code path**, valuable and cheap, but it does not upgrade a
promise to a check: a second opening performed *outside* the transcript is
still invisible, and a second opening *inside* it is a schedule the verifier
does not have. Keep R-D7 as **yes**, restate the reason.
**CORRECTION 8.**

## A7. Privacy obligations

**The obligations are the right ones and are honestly stated as obligations.
The draw recount finds one arithmetic error in the committed evidence script
(no headline effect), the three-commitments question has an answer the draft
does not give, and one obligation is missing entirely.**

### A7.1 The joint rank (O-R1)

Confirmed and strengthened at A1.4: disclosed 0 jointly over both groups, the
shared-pair control fires 40/40, and the geometry `data + 2·sites + 2` is a
hiding requirement rather than an audit convenience. The one thing O-R1 must
add: **say which columns the rank is computed over.** Over all rows the
degenerate cases are indistinguishable from the honest one (all rank 6); only
the restriction to the reserved mask rows separates them.

### A7.2 Cross-block independence (O-R2)

VERIFIED IN THE CODE, and the draft's description of today's behaviour is
exact: `prove_inner_at` creates **one** `ZkRng::from_os(sh.profile)` per proof
(`protocol.rs:475`) and every mask row, pad and salt of `A`, `H`, `M` comes
from that one stream (`:543-545`, `:642-653`, `pcs.rs:673-674`,
`zk::mask_commit`), while each endpoint draws its own
`ZkRng::from_os(DOMAIN)` inside `endpoint_g::prepare` (`endpoint_g.rs:193`).
R-D4 (one OS stream per commitment) is the right call and the draft is honest
that it does not prove O-2. No objection.

One thing to add: with 49 commitments the run makes **23 more `from_os` calls
per run**, and `from_os` **fails closed** (`protocol.rs:475` maps the error to
a refusal before anything public exists). At run scale that failure can now
happen in stage 12, six minutes in — which is the same "a refusal is terminal"
point as O-R4, and it is the one refusal class that is neither
challenge-driven nor input-driven. It belongs in O-R4's list.

### A7.3 The run-wide joint law (O-R3) and the THREE commitments

The brief's question: an internal boundary plane now sits under **three**
commitments — `A_k`'s `A_X2` rows, `B_k`, and `A_{k+1}`'s `A_X` rows — where
the toy analysis handled a plane under two. **MY OWN ARGUMENT: three is the
same argument applied three times, not a new argument, but the draft never
counts to three and should.**

Each of the three publishes a masked linear view of the same underlying words.
Given per-commitment independent blinding (O-R2) and a full-rank reserved
block on each (A1.4 for `B_k`; the owed one-block obligation for `A_k` and
`A_{k+1}`), each view is uniform and the triple is a triple of independent
uniforms, so the joint law is input-free. What is genuinely new is not the
count but two couplings:

* the **two claims on `B_k`**, whose values are functions of two blocks'
  witnesses — the `m = 2`, two-singleton-groups case of the corrected
  Proposition, and the case the shared-pair control is sharp for. The draft
  states this (O-R3, second bullet). ✔
* the **slot relations** that read two commitments at once. Slot 22 of block
  `k` reads `A_k` and `B_k`; slot 21 of block `k+1` reads `A_{k+1}` and
  `B_k`. Their published scalars and round polynomials are masked by **two
  different** masking commitments, `M_k` and `M_{k+1}` — a direct consequence
  of R-D3 (one `M` per block) and an argument **for** R-D3 that the draft does
  not make.

The practical consequence for O-R3: a rank deficiency anywhere among the
three views of a boundary plane leaks the **same** plane, so the run's gate
must rank all three roles of at least one interior boundary, not just the
boundary commitment. The draft's §5.4 `L = 3` list covers the boundary and the
run-wide joint but does not say "and the two `A`s that hold the same plane".
**OMITTED CONDITION 7.**

### A7.4 The draw recount (RECOMPUTED)

Anchored to the measured log rather than to a model: `A`'s mask rows are
**4,030,464** words (timing log line 13, "A: mask + proximity rows (fresh
randomness)") and `H`'s are **1,671,168** (line 20). With pads
`5,681 × 256` and `7,120 × 256` that is 8,978,688, leaving 21,254 for `M`'s
coefficients and its `50 × 256` pads plus `b_re/b_im/u_re/u_im`
(`zk.rs:430-460`) — consistent with the draft's per-block 8,999,942. The IO
counts follow `(rows − data_rows)·n + rows·q` (`endpoint_g.rs:200-202`,
`pcs.rs:673`; salts are raw bytes and D9-exempt):

| | draws | |
|---|---|---|
| boundary, 38 rows | 108,032 | draft ✔ |
| endpoint, 37 rows | 91,392 | draft ✔ |
| endpoint, 36 rows | **74,752** | — |
| RUN with 37-row external endpoints | 109,370,440 = 2^26.70 → **2^-69.3** | draft ✔ |
| RUN with 36-row external endpoints (R-D2's own recommendation) | **109,337,160 = 2^26.70 → 2^-69.3** | — |
| a million runs | 2^-49.4 | draft ✔ |

**`run_arithmetic.py:309-310` is wrong** for the recommended variant: it
charges a 36-row endpoint **six** mask rows (`6 * e_n`) when 36 rows is 32
data plus **four**. It prints 109,402,696 where the correct count is
109,337,160 — 65,536 draws too many, and in the direction that flatters
nothing. **CORRECTION 9.** Headline effect: none — 2^-69.30 either way.

The refusal arithmetic checks: `12 × 2^-62 = 2^-58.42`, `12 × 2^-112 =
2^-108.42`. ✔

### A7.5 The obligation that is missing

**Nothing in §5 covers the BOUNDARY's scale/calibration binding.** §5.2's
"what is published about `B_k`, exhaustively" lists "its scale tag — a public
calibration constant of the profile" and moves on. But D12 item 5 is an open
finding — "declared endpoint scales must be tied to the approved calibration
before any seam compares them. **Today the tag proves nothing**, and … a
tag-equality check would pass on a factor-of-8 mismatch" — and a run has
`L − 1` new places where two blocks meet at one declared scale. The transcript
absorbs a single `calibration_identity()` (`protocol.rs:98`); for a run it
must cover **every** block's calibration and the scale of every boundary, or
a run can chain blocks whose calibrations disagree and no receipt field will
say so. This is a **correctness** gap, not only a privacy one.
**BLOCKING 3.** (It is mitigated, not closed, by option A: with one commitment
there is one tag, so nothing is *compared* — see A1.6. What is missing is the
tie to the approved calibration.)

For completeness, the neighbouring worry is **not** a gap: the boundary
plane's class *is* proved at both ends. VERIFIED IN THE CODE — the Dom::D
LogUp list carries `byte(A_XL0), byte(A_XL1)` and `byte(A_X2L0),
byte(A_X2L1)` (`layout.rs:682`, `:704`), so block `k` range-proves its output
plane's int16 limbs and block `k+1` range-proves its input plane's, and the
equality ties the words. D12 item 4's analogue at a boundary is therefore
already discharged, twice over. The draft should say so; a reader of D12a will
ask. **OMITTED CONDITION 8** (satisfied, but unstated).

### A7.6 The gate at `L = 3`: what transfers

The draft's list is good and its feasibility finding (the gate factors
`2(G+1)` generators × rows, not rows × rows) is the useful part. Two
additions:

* **The structural fact transfers for a reason my model makes precise.** The
  rank condition of A1.4 is computed on the reserved rows only and does not
  involve the data-row count at all, so the rung's 10-row boundary (4 data + 6)
  and 125M's 38-row boundary (32 + 6) have **identical** reserved blocks. That
  is why `L = 3` at the rung settles the construction. Say it that way rather
  than "two sites at every shape".
* **The pad-budget margin transfers better than the draft says.** §5.4 lists
  it as not transferring, which is right about the *statistics* (rung
  `enc_cols = 1024`, expected distinct ≈ 226; 125M `enc_cols = 65,536`,
  expected ≈ 255.5) but wrong about the *condition*: by A1.5 the condition
  `distinct ≤ pads` holds structurally at every shape. The margin is not a
  thing that can run out. **CORRECTION 10.**

## A8. The D12 amendment

**Faithful to D12 items 1, 2 and 3, faithful to D17 and D18, and it drops
D12 items 4 and 5. It also leaves one door ajar.**

Checked line by line against `ZK60_DECISIONS.md:310-357` (D12), `:521`
(D17), `:585-640` (D18), `:642` (D13).

**Faithful.**

* Item 1 of D12a ("one proof, one transcript, end to end; separately finished
  proofs may not be joined because the upstream receipt has already opened its
  output commitment") is D12 item 1 plus the D8/D11 restatement's §2.5, and it
  matches `ZK60_PRIVATE_BLOCK_FORM_E_DISPOSITION.md` §3's "a private run is one
  transcript end to end". ✔
* Item 2's re-reading of "exactly two external endpoints" as a property of the
  **run** is the amendment's whole content and it is correct: D12's own
  justification for item 2 is that two separately finished receipts glued by a
  shared root are not one object, and a run under one transcript is one
  object. ✔ It correctly keeps D18-A (the prover seals both) and correctly
  says this does not discharge D8 or D11. ✔
* Item 3 is D12 item 3 applied to an internal boundary, with the three extra
  restrictions that make it not the forbidden configuration: prover-generated,
  inside one transcript, one reserved pair per claim site, opened once. ✔
  **Citation slip**: it says "forbidden exactly as **D12 item 1** forbids it
  for `xres1`, `nm` and `z16`" — that is **item 3**, not item 1.
  **CORRECTION 11.**
* Item 5's forbidden list (joining finished runs, double opening, caller-fixed
  internal roots, cross-transcript reuse, partial re-run after a refusal) is
  complete against D12 and the J-4 single-attempt reading. ✔
* D17 is honoured: a run is a new profile with its own digests, so no existing
  byte moves. ✔ Subject to A1.6's list of code that must nonetheless change.

**Missing.**

* **D12 item 4 (class) is not carried forward.** It is in fact satisfied at a
  boundary (A7.5), but the amendment should say so, because item 4's logic —
  "the receiving component proves no range on its own input" — is exactly the
  question a reader will ask about a boundary.
* **D12 item 5 (scales tied to the approved calibration) is not carried
  forward at all**, and a run multiplies the places it bites from 2 to `L+1`.
  See A7.5. **This is BLOCKING 3 and it belongs in the amendment text, not
  only in a memo section.**
* **The amendment does not say what a run's receipt does NOT prove about any
  single block.** Under D12 a block's output was an external endpoint; under
  D12a an interior block's output is a hidden intermediate nobody can refer
  to. That is more restrictive, which is fine, but "no per-block claim can be
  extracted from a run's receipt" is exactly the sentence a product reader
  needs and it is absent from "What this does not do".

**The door left ajar.** Item 3 forbids "a boundary commitment fixed by anyone
other than the prover" — good — but item 2 and the "what this does not do"
paragraph together leave the **external** endpoints under D18-A only "for the
first MVP". That is correct and matches D18 (option B is a recorded todo whose
handle does not exist). No door open there. The one genuinely ambiguous phrase
is item 1's "**Joining finished runs** needs the sealed handle of D18 option
B, which does not exist": read carelessly this reads as "when the handle
exists, joining is permitted". D8 and D11 are open and bind that
configuration; the amendment should say "and would then still require D8 and
D11 to be discharged". **CORRECTION 12.**

**Whose ruling is it?** The register lists D12's owner as the security owner
(Fable), so D12a is the security owner's, not Victor's — R-D8 ("record before
the first `L > 1` run") is correctly filed. The project-owner item the draft
never surfaces is different; see A10.

## A9. The staged build plan

**R1 is writable today and I checked it against the real function. The
headline negative test is there and does test the verifier. The
"no forbidden file" claim is TRUE for the prover and verifier path; the
list of files that DO move is incomplete.**

### A9.1 Is R1's first failing test writable before the module exists?

**Yes. VERIFIED:** `audit_claims` is `pub(crate)`
(`protocol.rs:208`) and takes only `(&[ZClaim], n, rows, &[usize],
Option<[usize;2]>, prox)` — all constructible by hand. `ZClaim`/`ZPart`/`Slice`
are public types from `zkp-core::pcs` (`:715-738`). A test inside
`private_block` can build two three-part claims at `rows = 38`, `prox = 36`,
`site_rows = [32,33,34,35]` with no new module in the tree. I traced the four
cases through the function:

| R1 case | fires at | message |
|---|---|---|
| disjoint pairs, proximity pair last | — | `Ok(())` |
| both claims on pair 0 | `:248-250` | "a reserved pair is unused or shared between claims" ✔ the draft quotes it exactly |
| a claim reaching the proximity pair | `:219-221` | "a claim reaches the proximity pair or leaves the commitment" |
| zero pair coefficient | `:223-227` | "zero terminal mask coefficient; discard attempt" |

One trap the draft does not warn about: the alignment clause
`(touched[0] − site_rows[0]) % 2 != 0` (`:238`) means a test that puts a pair
at rows `(33,34)` is refused for the *alignment* reason, not the sharing
reason. A test asserting on message text must pick its rows deliberately.

**Add a fifth case R1 is missing, and it is the one my model says matters:**
the same two claims with `rows = 37` and `prox = 35` (a single proximity
row) — `audit_claims` **accepts** it (`prox + 2 == rows` holds), and yet the
joint rank is 5 of 6 and one real dimension is disclosed (A1.4). So
`audit_claims` alone does **not** enforce the hiding geometry: what enforces
it is `rows = data + 2·sites + 2` being derived, not passed. R2's
`boundary.rs` must **compute** `rows` from `sites` and refuse a caller-supplied
row count, and R1 should pin that. **BLOCKING 4** — it is small, and it is
precisely the class of hole this project has hit before (a gate stage
hard-coded to pass).

### A9.2 The headline negative test

Present and correct (R3 acceptance 2): block 2 rebuilt on a hidden input that
is not block 1's output, **rejected by the verifier**, both variants, with the
refusal naming the failing slot. That is the right test and it does test the
verifier, because the slot relations run identically on the `Side::Verify` arm
(`argument.rs:352-378` for the sumcheck, `:389-396` for the claims) and the
IO equality slot's zero-check fails at `sumcheck::verify` with a message
carrying `SLOT_NAMES[s]` (`argument.rs:359`). VERIFIED that the refusal
mechanism the test asserts on exists.

Missing from R3/R4, and cheap: **a boundary whose two claims are at the same
point** (the declared-group-count refusal, `protocol.rs:279-281`) is in R2 but
not in R3, and **a run in which `B_k` is opened in stage `k` instead of `k+1`**
(i.e. before block `k+1`'s claim exists) should be a *prover-side* refusal by
name, not an incorrect proof. The draft's §2.7 asks for "a mechanical check at
run-definition time" but no acceptance test pins it.
**OMITTED CONDITION 9.**

### A9.3 The reachability list: what the run needs, file by file

VERIFIED IN THE CODE, every item:

| needed from | item | reachable as is? |
|---|---|---|
| `zkp-core/src/pcs.rs` | `commit_zk_owned` `:653` | `pub` ✔ |
| | `open_zk` `:915` — `&CommittedZk`, `&[ZClaim]`, any group count | `pub` ✔, **claims accumulated across two stages are just a slice** |
| | `verify_zk` `:947` — re-forms groups from the claims (`:966`), loops over them (`:971-980`, `:1022-1032`) | `pub` ✔, **two groups need no change** |
| | `ZkOpts::standard` `:542`, `CommittedZk.mask_rows` / `.prox_mask_row` / `.data` `:551-564` | `pub` ✔ |
| | `assert_mask_sites` `:881` — checks each group's rho touches a `mask_row` and the prox rho touches `prox_mask_row` (ONE row) | `pub` ✔, satisfied by setting the two fields, as `endpoint_g.rs:205-206` does |
| `hashline/src/zk.rs` | `ZkRng::from_os`, `mask_commit` `:430`, `mask_open`, `mask_verify` | unchanged under R-D3 ✔; `mask_commit`'s only shape constraint is `part.len() + MASK_Q ≤ 2^MASK_LOG_MSG` (`:442`), per row, per block ✔ |
| | twelve instantiations under one transcript | no static or thread-local state is load-bearing (`pcs::LAST_SITES` `:898-905` is a report buffer overwritten per call) ✔ |
| `private_seam.rs` | nothing | ✔ |
| `native_capture.rs` | the run capture writer | **needs it, or a new file** — the draft admits this and recommends a new `private_block/run_capture.rs` ✔ |
| `zkp-core/src/transcript.rs` | carry the transcript across blocks; `state()` `:133`, `clone_state` `:139` | `pub` ✔, it is an owned struct in a local |

**So the draft's §7.8 headline is TRUE: no forbidden file changes on the
prover or verifier path.** What §7.8 omits is the list of *permitted* files
that must change, which A1.6 gives: `endpoint_g::MASK_ROWS` (inside a digest),
`protocol::ENDPOINT_MASK_ROWS` / `endpoint_geometry` /
`check_endpoint_opening`, `argument.rs:521`'s `− 5`,
`private_block.rs:513-515`'s refusal (which R-D2 trips), `layout.rs:1043`,
`shape.rs:706`, `wire.rs:93/:116/:224`. Seven sites. Saying "no forbidden file"
without saying "and seven permitted ones" is how a two-day estimate becomes a
week. **CORRECTION 13.**

### A9.4 One thing R2 must add

`boundary.rs` must run `layout::no_commitment_has_a_node_shaped_column` on its
own row count (`endpoint_g.rs:107` does this; C-H4 forbids a column hashing to
40 or 64 bytes, i.e. 5 or 8 rows). 38 and 36 are fine; the **rung's 10** is
fine; but a `sites`-parameterised module can be asked for 5 rows (`data = 1`,
`sites = 1`) and must refuse. The draft's R2 test list says "the C-H4
node-shaped-column refusal" ✔ — good, keep it.

## A10. The eleven decisions R-D1 … R-D11

| # | is it the security owner's? | verdict |
|---|---|---|
| R-D1 boundary object A vs B | yes | **A confirmed**, and for two more reasons than given (A1.1 arity, A1.6 scale tag) |
| R-D2 geometry `data + 2·sites + 2` | yes | **confirmed, and it is a hiding requirement, not an audit convenience** (A1.4). Its corollary (external endpoints with `sites = 1`) trips `private_block.rs:513-515` and must be paired with that change |
| R-D3 one `M` per block | yes | confirmed; add the argument of A7.3 (the two relations touching a boundary get two different masks) |
| R-D4 one OS stream per commitment | yes | confirmed; add the run-scale `from_os` failure to O-R4 |
| R-D5 `B_k` opened in stage `k+1` | yes | confirmed (A3.1); add a prover-side refusal if the schedule places it earlier (A9.2) |
| R-D6 one segment per stage | engineering | confirmed; the counted sizes are 96 B/segment short of the design (A6.1) |
| R-D7 verifier checks one-opening-per-commitment | yes | **keep the answer, replace the reason** (A6.6): it is a regression guard, not an upgrade from promise to check |
| R-D8 record D12a before the first run | yes (D12's owner is the security owner) | confirmed; the text needs D12 items 4 and 5 (A8) |
| R-D9 gate at `L = 3` on rung-G | yes | confirmed; add "and the two `A`s holding the same boundary plane" (A7.3) and restate the pad-budget transfer (A7.6) |
| R-D10 correct "5.3 min" to 6.3 min | engineering | confirmed (A5); 6.26 min precisely |
| R-D11 streaming verification required | **partly the project owner's** | the technical half is the security owner's; "must a verifier run in bounded memory, and where" is a product requirement |

**What is missing from the list.**

* **The run's soundness level.** ~2^-97.5 for `L = 12` (A3.2). The project took
  an explicit ruling (D3) to accept 97 bits on the zkVM line; the native line
  reaching the same level by union bound over blocks deserves the same
  explicit acceptance, not silence. **This is a decision, and it is absent.**
* **A 484 MB receipt.** The draft treats segmentation as an engineering
  consequence and never asks whether half a gigabyte per twelve-block 125M run
  is acceptable for the MVP — with the obvious follow-on that an 8B model's 32
  blocks at a larger width is multiple gigabytes. That is a **project-owner**
  question (who stores it, who transfers it, what the MVP promises) filed
  nowhere. **Add it.**
* **The calibration/scale binding at internal boundaries** (A7.5, BLOCKING 3):
  a security-owner ruling, absent.
* **Whether a run's receipt may ever be quoted as evidence about one block.**
  A8's third "missing" item. One sentence, but it is the sentence a product
  reader will act on.

## VERDICT

**This is the right design to build, and the draft is the most solid one this
project has produced this week — but four things must change before anyone
writes code against it.** I attacked the boundary construction hardest and it
held: one commitment claimed by two blocks really does open in a single
`open_zk` call with no change to any file the lane may not touch, the claims
are two groups not one, the pair-exclusivity check applies word for word at
38 rows, and my own exact-arithmetic model says the boundary's two groups plus
the proximity vector are jointly full rank — disclosed 0 — while the
shared-pair control fires every time. I also tried to break option B's memory
claim, which the brief suspected, and could not: the two big `A` matrices
really do coexist only at a moment measured 2.2 GiB below the peak, so the
draft's "near-tie" is honest and its recommendation of option A rests on the
right grounds (the measured block is reused unchanged, and the new privacy
question sits on a 38-row object). The four things that must change are: the
section titled "soundness" must actually state the run's soundness (about
2^-97.5 for twelve blocks, the same 97-bit level the project ruled on
separately for the zkVM); the prover must be required to write each segment
out and free it, because eleven held segments are 423 MiB the memory model
does not count; D12's items 4 and 5 must be carried into the amendment, and
item 5 (declared scales tied to the approved calibration) is a **correctness**
hole that a run multiplies from two places to thirteen; and the boundary
module must **derive** its row count from the site count rather than accept
one, because `audit_claims` happily accepts a 37-row geometry that my model
shows discloses one dimension. None of this changes the design. All of it
changes what gets built.

## ERRATA AND CONDITIONS FOR ACCEPTANCE

### BLOCKING (fix before R1 is written)

| # | item | evidence | what must happen |
|---|---|---|---|
| **B1** | §2 is titled "transcript order and **soundness**" and states no soundness error. The run is **≈ 2^-97.46** for `L = 12` (12 × 2^-101.1 + 11 × 2^-105.61) | A3.2; `run_recount.py` §4; `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md:510`, `..._LAYOUT_CHECK.md:1102` | state the figure and its inputs in §2, note that it is the same 97-bit level D3 accepted for the zkVM, and open a decision on accepting it for the native line |
| **B2** | the memory model counts only the three IO commitments. Eleven unflushed segment `Receipt`s are **+423 MiB** and eleven extra public statements **+68.8 MiB**; peak 10.67 → **10.74 GiB** flushed, **11.15 GiB** unflushed | A4.2; `run_recount.py` §2 | make "serialise and release each segment before the next stage" a stated invariant of the run driver, add both terms to §3's peak, and add the unflushed case as failure mode 5 |
| **B3** | D12 item 5 (declared scales tied to the approved calibration — "today the tag proves nothing") is carried nowhere. A run has `L−1` new places two blocks meet at one declared scale, and the header absorbs a single `calibration_identity()` (`protocol.rs:98`) | A7.5, A8; `ZK60_DECISIONS.md:345-349` | D12a must restate item 5 for boundaries; the run's `"calibration"` absorb must cover every block's calibration and every boundary's scale; record it as a correctness obligation, not a privacy one |
| **B4** | `audit_claims` **accepts** `rows = 37, prox = 35` with two sites, and that geometry discloses one real dimension (joint rank 5 of 6). The audit does not enforce the hiding geometry | A1.4, A9.1; `boundary_rank.py` | `boundary.rs` must **derive** `rows = data + 2·sites + 2` from `sites` and refuse a caller-supplied row count; R1 must pin the 37-row case as the reason |

### CORRECTIONS (the draft's line → the evidence → what it must say)

| # | the draft says | evidence | it must say |
|---|---|---|---|
| **C1** | §5.2(1): "the boundary owner must be **consumed by the opening call**, not borrowed" | `pcs::open_zk(cmz: &CommittedZk, …)` takes a shared reference (`pcs.rs:915`); the no-`Clone` discipline lives on `PreparedPlaneG` (`endpoint_g.rs:146-162`) | the *wrapper* must consume itself — `boundary.rs` owns the `CommittedZk` and exposes `into_opening(self, claims, tr)`; `open_zk` cannot enforce it |
| **C2** | §1.1: the five endpoint rows are "the terminal pair, the proximity row at `data+2`, and **two further random rows**" | `check_opening_challenges` requires `det(rho[prox], rho[prox+1]) ≠ 0` (`protocol.rs:266-269`), so `data+3` is load-bearing; only `data+4` is spare | pair (2) + proximity **pair** (2) + one spare (1); `data + 2·sites + 2` is that budget minus the spare |
| **C3** | §1.5: "measured margin on the real captures: 246 distinct positions on `A`, 241–246 on the endpoints, against 256 pads" | those are **toy** captures (`enc_cols = 1024`); at 125M `enc_cols = 65,536` and expected distinct ≈ 255.5. And `distinct ≤ 256 = q_pad` structurally (`pcs.rs:670`, `:928`, `:618-637`) | drop the empirical margin; state that `H-pad` holds by construction at every shape for any number of groups |
| **C4** | §2.7(1): `B_k` before `A_k` "so that a prover cannot adapt the boundary to any challenge" | no challenge is drawn between steps 2 and 3 | either order is sound; the binding requirement is only "before slot 21/22's challenges" |
| **C5** | §3: run peak = one-block peak + 88.2 MiB | eleven extra `BlockPublic`s are 68.8 MiB of `Vec<i8>` (`private_block.rs:226-233`, `:347-352`) | + 68.8 MiB, or state that statements are streamed per stage and make that an invariant |
| **C6** | §4.2: "verify 12.3 s" | 12 × 1.027 + 12 × 0.015 decode | 12.5 s wall; 12.3 s of algebra |
| **C7** | §4.2 segment sizes are counted with **40 B** of framing; §4.3 specifies a 96 B header + 40 B trailer | `run_recount.py` §1 | either re-count (40,031,304 / 40,301,640 / 41,049,128; total 484,096,832 B) or shrink the framing. **R6's "exactly" acceptance currently fails an honest run by 96 B/segment** |
| **C8** | §4.3: check 4 "makes 'one transcript' a property the verifier **enforces** rather than promises" | the run layout is a function of the verifier's own statement, as the block's is (`protocol.rs:724`, `wire.rs:196-199`) | it is a regression guard on the verifier's own path; keep it, drop the claim that it upgrades a promise to a check |
| **C9** | `run_arithmetic.py:309` charges a 36-row endpoint **six** mask rows | 36 = 32 data + **four**; correct run draws 109,337,160, not 109,402,696 | fix the script; the headline 2^-69.3 is unaffected |
| **C10** | §5.4: the pad-budget margin "does not transfer" | the *statistics* do not; the *condition* holds structurally (C3) | say which |
| **C11** | §6 item 3: "forbidden exactly as **D12 item 1** forbids it for `xres1`, `nm`, `z16`" | that is D12 **item 3** (`ZK60_DECISIONS.md:331-339`) | cite item 3 |
| **C12** | §6 item 1: "Joining finished runs needs the sealed handle of D18 option B, which does not exist" | D8 and D11 bind that configuration and are open (`ZK60_DECISIONS.md:604-620`) | "…and would then still require D8 and D11 to be discharged" |
| **C13** | §7.8: "the prover and verifier path needs no forbidden file" — true — with no list of the permitted files that move | A1.6: `endpoint_g::MASK_ROWS` (inside a digest), `protocol::ENDPOINT_MASK_ROWS` / `endpoint_geometry` / `check_endpoint_opening`, `argument.rs:521`, `private_block.rs:513-515` (which R-D2 trips), `layout.rs:1043`, `shape.rs:706`, `wire.rs:93/:116/:224` | keep the headline, add the seven sites |

### OMITTED CONDITIONS

| # | condition | where it belongs |
|---|---|---|
| **O1** | the seven permitted-file sites of C13, and specifically that R-D2's 36-row external endpoint is **refused by name** by `private_block.rs:513-515` until that check is taught about the new construction | §7.2 / §7.8 |
| **O2** | option B's "seam early" is a slot-schedule re-cut (the seam must *be* slot 0; `run_slot` refuses out-of-order slots, `argument.rs:289`), not a reordering | §1.3 (strengthens the case against B) |
| **O3** | per-stage high-water mark printed and asserted non-rising across an `L = 2` / `L = 3` run — the only measurement that would show allocator fragmentation across twelve 10 GiB cycles | §3, R3 and R6 acceptance |
| **O4** | a run needs `encoded_len_segment(lay, k, L)` and a per-segment wire bound; `receipt_bytes().total` for a run profile is 484 MB and `wire_bound`'s `min` would clamp to 64 MiB for the wrong reason | §4.1, R3 |
| **O5** | the segment header and trailer are **outside** the Fiat–Shamir chain (never absorbed — the state cannot hash itself) and are **compared, never adopted** | §4.3 |
| **O6** | a verifier that stops after segment `k` knows **nothing** about the run: `B_k` is unopened, `E_out` is unopened, and a partial run is not a proof of a prefix | §4.4 |
| **O7** | the run's gate must rank **all three** commitments that hold an interior boundary plane (`A_k`'s output rows, `B_k`, `A_{k+1}`'s input rows), not only `B_k`; a deficiency in any one leaks the same plane | §5.1 O-R3, §5.4's `L = 3` list |
| **O8** | the boundary plane's int16 class **is** proved at both ends (`layout.rs:682`, `:704`), so D12 item 4's analogue is discharged twice — say so, because a reader of D12a will ask | §5.2, §6 |
| **O9** | acceptance tests for (a) a boundary whose two claims land at the same point (declared-group-count refusal, `protocol.rs:279-281`) at run scope, and (b) a run schedule that opens `B_k` in stage `k` — a prover-side refusal **by name**, not an incorrect proof | R3, R4 |
| **O10** | O-R1 must say the joint rank is computed **restricted to the reserved mask rows**; over all rows every control looks identical (rank 6) | §5.1 |
| **O11** | `ZkRng::from_os` now runs 49 times per run and fails closed at any point, including six minutes in — add it to O-R4's refusal classes | §5.1 O-R4 |

### What I could not check

* **I built nothing and ran nothing**: no cargo, no Rust test, no prover, no
  benchmark, per the lane rules. Every code claim above is a read of the
  source at a cited line; every number is either from
  `m125-run2-timing.log` or from my two Python scripts.
* My joint-rank model covers the **group/proximity vector channel only**. It
  says nothing about the opened columns, the Merkle salts, the CFS channel or
  the hash layer, and it is **not** a privacy result for anything.
* I did not re-derive the generic-rank lemma, the terminal-surjection
  Proposition or the joint-law composition; I used their statements.
* I did not verify the rung-G row counts (`A 623 / H 576`), the `L = 3`
  joint-matrix cost model, or the option-B receipt sketch — all three are
  labelled as estimates in the draft and I accepted the labels.
* I did not read all twenty-three slot definitions; I read slots 21/22, the
  Dom::D lookup list and the claim-raising path.
* I did not check the joint-view gate's own code (it is on another branch)
  beyond the draft's description of what its matrices are.
* I have not checked whether `Shape`/`Layout` refusals are complete for a run
  shape; they do not exist yet.

*(check complete)*
