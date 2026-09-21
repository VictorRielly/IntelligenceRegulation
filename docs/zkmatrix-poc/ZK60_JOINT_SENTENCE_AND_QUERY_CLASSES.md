# The joint sentence, and the complete query-class table

> **REVISED after an independent check and the security owner's disposition,
> 2026-09-21 03:29 PDT: not a privacy claim; Part A HOLDS WITH CHANGES (two
> hops, in a fixed order); the position map is COMPLETE; Part B was
> INCOMPLETE and is extended.**

Errata pass by a delegated editor (`date` read at 03:24 and 03:29 on the WSL
box, PDT) against two inputs: the independent adversarial check
`ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_CHECK.md` (findings B-1 … B-17) and
the security owner's disposition
`ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_DISPOSITION.md` (rulings J-1 … J-7),
which is this pass's **specification**: where the check's suggested repair and
a ruling differ, the ruling is applied as written. Every figure inserted in
this revision was **re-derived in the form in which it is used**, in exact
integers, and each derivation is printed beside its figure. No label was
softened, nothing that survived the attack was weakened, no claim was added,
and nothing was deleted silently: superseded text is struck through or marked
WITHDRAWN / NARROWED / RECORDED in place. Editor's disagreements, where any,
are marked **EDITOR'S NOTE** and change nothing.

**Nothing accepted moves.** Register entry D22 is untouched except that its
scope is now said more exactly: by ruling **J-3** the accepted toy statement
covers the **CPU path**, and a `gpu-cuda` build with the accelerator enabled
is outside it until the two kernels' agreement is cited to a gate by name and
the device/pinned buffer lifetimes are read (§5.2).

### Changes in this revision

| ruling (check finding) | sections touched | what changed |
|---|---|---|
| **J-1** (B-1, B-1a, B-1b) | §2.0 box, A-10, A-14, §10, §11, §13 | "the oracle is independent of `ω`" **removed as a premise**; the route restated as **two hops in a fixed order**; the position map's load moved into the FIRST hop; in the resulting world clauses (a) and (c′) are **definitions**, not consequences of M-3; the conditioning inflation priced |
| **J-2** (B-10) | A-6, A-11, A-21, §10, §13 | "information-theoretic" replaced by a named assumption, **E-1 (separate operating-system entropy reads are independent and uniform)**; three generators at a block and three in a run; every `ZkRng::from_os` site cited; `C(47,2) = 1,081` kept |
| **J-3** (B-3, B-12) | §5 table (new rows **G1**, **G2**), new §5.2, A-4, §11, §12, §13 | the CUDA row moved **out of** "not on the path, checked clean" and **split into the two kernels**; reachability stated exactly; what pins the agreement named; **D22's scope narrowed to the CPU path** |
| **J-4** (B-2, B-8) | A-16, A-17, §6.1, §6.2a, §10 | the flag's price restored to **the hash-layer lemma's own formula**, term by term with each derivation; the mechanism given for `2^-241.42` **corrected** (the draft's mechanism yields `2^-192`); no total moves |
| **J-5** (B-4) | §3.1, A-8, W-8 | the owed draw-accounting test's five assertions become **seven**; assertion 2 widened to a run's `11L + 3(L−1)` segments and the stage-offset formula corrected |
| **J-6** (B-11, B-5) | §6.3, §2.4, §0, §10, §13 | **(iii-a′)** kept as the restated hypothesis, with **causality named** and the refusal flag inside the hypothesis; clause (c′) re-labelled *not new, not owed, not circular*; **GAP-JS-2 WITHDRAWN** (marked, not deleted) |
| **J-7** (B-6, B-7, B-9, B-13 … B-17) | §5, §5.1, §6.1, §6.2, §6.2a, §7, §8, §9, §13 | two CUDA kernels and the further in-process hash sites added to the table; the six-terminal `pb-term` absorb **VERIFIED** and ruled **RECORDED, not guarded**; the **295-byte** within-family clash added; the toy has **three** legacy clashes, not four; `rows = 16` **NARROWED** to legacy-only with W-4 kept anyway; seven one-line-early citations fixed; the further one-byte margins listed; D2's length is **shape-determined**, not adversary-moved |
| editorial | §0 | the list introduced as "Three things" carries four items; the count is corrected |

A final section, **§14 "What the check changed"**, gives one line per
B-1 … B-17.

---

**Drafted by a delegated Opus agent for the security owner.**
2026-09-21, started 02:21, written 02:46–02:55 (`date` read at 02:21, 02:46,
02:53 and 02:54 on the WSL box, PDT).

It incorporates ruling **K-R4a** (security owner, 02:42), which reached
claims A-12…A-14 below independently and at the same hour; where this page
says "before reading K-R4a" it means the computation, not the ruling.

It delivers the two items ruling **K-R3** and ruling **K-R2** of
`ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_DISPOSITION.md` left owed. K-R1 is an
errata matter and is not touched here.

| | |
|---|---|
| **Part A (K-R3)** | the joint sentence the composition lemma needs: the probability space read off the code, the sentence split into four checkable clauses, the project's two counterexamples aimed at it, and what changes at a shaped block and in a run |
| **Part B (K-R2)** | every BLAKE3 call kind on the toy's path and a run's path at `8c5922b`, its mode, key, layout and length per shape, what separates it from every other, and what pins that separation today |

**This establishes no privacy property of anything.** Register entry D22 (the
toy block) is untouched and rests on Route A, not on this page. No sentence
here may be quoted as an acceptance.

Code facts are readings of the lane worktree `/home/victor/wt-zk60-block125m`
at commit **`8c5922b`**; nothing was compiled or run in Rust. Numbers are
labelled **[COUNTED]** (read off the code), **[COMPUTED]** (this page's
scripts, exact arithmetic), **[ARGUED]**, **[ASSUMED]**, **[UNVERIFIED]**.
Evidence: `results/zk60_joint_sentence_query_classes/` — four scripts, each
ending `ALL ASSERTIONS PASSED`, with their outputs and a README naming every
`file:line` transcribed.

---

## 0. In plain words, before any notation

The composition step needs one sentence that the accepted theorems do not
say. The accepted theorems say: *for fixed challenges, the numbers a receipt
publishes look the same whoever the hidden input was.* What the composition
needs is bigger in three ways. It needs the **salts** in the picture, because
a receipt publishes 1,280 of them and the theorems' probability space does
not contain them. It needs the **hashes** in the same picture, jointly, not
as a second marginal — the project's standing counterexample is two values
each uniform on its own whose pair gives the secret away. And it needs the
**flag** — the indicator that no bad event happened — inside the same joint
law, because the lemma compares two worlds "until something bad happens" and
the bad thing has to be the same thing in both worlds.

Part A writes that sentence, says exactly which of its clauses is a theorem
about the code, which rests on the generator assumption, and which needs a
test nobody has written.

The other owed item is smaller but sharper. The lemma needs the prover's hash
queries and the queries that make the challenges to be different queries.
Last night's check found the draft's list of query kinds incomplete. Part B
is the complete list — **24 call kinds, not five** — with, for every pair,
the thing that keeps them apart, and for every separation, the test that pins
it or the admission that nothing does.

> **REVISED (J-7).** Twenty-four was itself incomplete. The independent check
> found **two more BLAKE3 call kinds on the production path** — two
> hand-written CUDA kernels reached at exactly the two legacy profiles under
> a build flag and an environment variable (§5.2) — and further hash sites
> reachable in the same process that were in neither list (§5.3). The table
> below is the extended one. Part B's honest headline is therefore **26 call
> kinds on the path, plus in-process sites the `F_U` argument has to name**,
> and the reason the count moved is written into §5.2 and §5.3 rather than
> quietly corrected.

Four things this page found that nobody had written down:

1. **The prover does query the transcript class.** The refusal replay and the
   run's position tags squeeze off a discarded clone, at points the live
   chain queries next. The draft's "partition into a prover class and a
   transcript class" is not a partition of the prover's queries at all. The
   hypothesis survives, in a different form: *the prover's transcript-class
   queries are all at points determined by the public prefix* (§6.3, claim
   B-6).
2. **A commitment of 16 rows would hash a column to 128 bytes, the length of
   the frozen-seam spec digest, and no guard anywhere refuses 16.** The lane's
   completed guard carries 5, 8, 11, 12, 13, 15, 17, 19 and the shape-driven
   ones; the statement digests were never in its set [COMPUTED].
3. **A `pb-term` absorb of six terminals is 151 bytes, the length of the
   internal-boundary spec digest**, which is unkeyed at every rule — so it is
   a cross-profile coincidence between a legacy proof and a tagged run on one
   machine (§7, claim B-8). ~~Whether any slot really carries six terminals is
   [UNVERIFIED] here and is work-list item W-6.~~ **[VERIFIED — the check's
   B-6, ruling J-7.]** `Shape::slot_terms()` (`shape.rs:742-749`) is
   `a_sites[s] + h_sites[s] + (s ≥ SC_IO_IN)`; at slot **19 = `SC_TAB`**,
   `a[SC_TAB] = 3` and `h[SC_TAB] = 3` (`shape.rs:733-734`) and
   `SC_TAB = 19 < SC_IO_IN = 21` (`layout.rs:817, :819`), so
   `slot_terms[19] = 3 + 3 + 0 = 6` at **every** shape [COUNTED, re-read at
   `8c5922b`]. The absorb is `48 + 7 + 16·6 = 151` bytes [COMPUTED]. Because
   the pair is **never live inside one profile**, ruling J-7 disposes of it as
   **RECORDED, not guarded** — W-6 and GAP-QC-4 are changed accordingly (§7,
   §8, §13).
4. **Clause (c′) — the published and the withheld salts are one stream
   segment split by the challenge — is a DOCUMENTATION sentence, not a half
   that Lemma H owes.** ~~Lemma H's owed half is a WITHIN-segment
   conditioning, not a between-segment one … it is the half ruling K-R3 says
   the hash-layer lemma owes.~~ **[RE-LABELLED — the check's B-5, ruling
   J-6.]** The within-segment reading is correct and worth keeping: the
   published and the withheld salts really are one segment, selected by `ρ`.
   But it is **not new** (Lemma H's conditional already conditions on
   `S_pub = s`), **not owed** (what ruling K-R3 owes is the joint sentence
   itself, delivered by §2.0's two-hop ordering) and **not circular** (both
   Lemma H and (JS) live in the fixed-challenge experiment, where `ρ` is
   exogenous). In the world (JS) is stated in — after the first hop — it is a
   **definition**, in one line. **GAP-JS-2 is WITHDRAWN** with that reason,
   and marked, not deleted (§2.4, §13).

---

# PART A — the joint sentence (ruling K-R3)

## 1. The probability space, exactly

### 1.1 One generator, one stream, a constant price per draw

**Claim A-1 [COUNTED].** `ZkRng` (`zkp-core/src/rng.rs:9-99`) is a byte
stream with a 32-byte key and a counter. `refill` (`:53-61`) produces each
8,192-byte block as **unkeyed** BLAKE3 in XOF mode over `key(32) ‖
le64(counter)(8)` — 40 bytes. `RNG_BLOCK = 8192` (`:16`) is a multiple of 8
and every read is `next_u64` (`:63-70`), so a buffer boundary never splits a
word and **the byte position of the `i`-th `next_u64` is exactly `8i`**.

**Claim A-2 [COUNTED] — the field sampler is REDUCTION, not rejection.**
`fp()` (`rng.rs:73-77`) takes two `next_u64`s as a 128-bit integer and calls
`Fp::from_u128`, which is `Fp((v % (P as u128)) as u64)`
(`zkp-core/src/field.rs:36-38`), `P = 0xFFFF_FFFF_0000_0001` (`field.rs:10`).
There is no loop, no retry, no branch. **One `fp()` consumes exactly 16 bytes
whatever it draws**; `fp2()` 32; `bytes32()` (`rng.rs:93-99`) 32.

This is the fact the coordinator asked to be confirmed, and it is confirmed.
It is what makes "the draws sit at schedule-determined positions" true, and
therefore what licenses ruling **K-R4a**'s distance hop. Had the sampler
rejected, the hop would still be valid but the *argument* for it would have
to change (§2.1, claim A-9).

**Claim A-3 [COUNTED] — there is no re-draw anywhere on the path.** The two
places that look like one are not:

* `H`'s zero-sum rows (`hashline/src/private_block/protocol.rs:760-768`) draw
  exactly `n−1` values per row and **compute** the last as the negated sum. A
  prefix that happens to sum to zero simply gives a zero last entry. No
  condition, no loop.
* `M`'s `b` rows (`hashline/src/zk.rs:503-506`) draw `2m` values and then
  **overwrite** `b_re[m] := −b_re[0]`. An overwrite, not a re-draw.

Grep over the path finds no `loop {`/`while` around any `rng` call. The only
witness-sensitive control flow inside the draw window is a **total abort** —
`inverses()` returning `Err("zero LogUp denominator; discard attempt")`
(`protocol.rs:402-405`, called at `:691, :702, :704, :734`) — which discards
the stream and produces no receipt. Under D21 and rule M-9 the game is
accepted receipts only, so an aborted attempt contributes nothing to the view
(§2.4).

### 1.2 The segment schedule of one block body, in order

**Claim A-4 [COUNTED].** The prover reads the stream in exactly this order.
Sites are at `8c5922b`.

| # | segment | site | count | width | published? |
|---|---|---|---|---|---|
| 1 | `A` mask + proximity rows | `protocol.rs:655-658` | `(a_rows − a_data)·n` | `fp` | no |
| 2 | `A` pads | `zkp-core/src/pcs.rs:777` | `a_rows·Q` | `fp` | no |
| 3 | **`A` salts** | `pcs.rs:778` | `nn` | `bytes32` | **yes, 256 slots** |
| 4 | `M` CFS mask coefficients | `zk.rs:485` → `sumcheck.rs:201-203` | `2·Σ L_s` | `fp` | no |
| 5 | `M` per-row pads | `zk.rs:496` | `46·256` | `fp` | no |
| 6 | `M` `b_re,b_im,u_re,u_im` | `zk.rs:503-508` | `4·1024` | `fp` | no |
| 7 | **`M` salts** | `zk.rs:513` | `4096` | `bytes32` | **yes, 256 slots** |
| 8 | `H` mask + proximity rows | `protocol.rs:757-759` | `(h_rows − h_data)·n` | `fp` | no |
| 9 | `H` zero-sum rows | `protocol.rs:760-768` | `2(n−1)` | `fp` | no |
| 10 | `H` pads | `pcs.rs:777` | `h_rows·Q` | `fp` | no |
| 11 | **`H` salts** | `pcs.rs:778` | `nn` | `bytes32` | **yes, 256 slots** |

The order **pads then salts** inside a commitment is the same on the legacy
twin (`pcs.rs:724-725`) and is drawn *before* the accelerator is offered
(`pcs.rs:782-785`), so neither the GPU path nor the hash tag moves a byte —
the lane pins that with `the_tag_does_not_move_one_byte_of_the_generator`
(`zkp-core/src/pcs.rs:1736-1753`, which asserts equal pads and equal salts
under the legacy and the rung-G tag from the same seed).

> **Corrected (J-3 / the check's B-12).** That sentence is right about the
> **draws** and must not be read as *"the accelerator is never reached"*. It
> says only that the generator has already been consumed by the time the
> device is offered the columns, so no `HL_GPU` or tag branch can move a
> stream byte. Whether the device is then offered the **column hashing** is a
> different question, and at the two legacy profiles the answer is yes:
> `commit_zk_owned_with_tag` declines only when `tag.column_key()` is
> `Some(_)` (`pcs.rs:782-785`), and `commit_zk_owned_with` (`pcs.rs:728`) has
> **no tag gate at all**. See §5.2. The pin above covers the draws; it does
> not cover the hashing.

**The published salts sit between secret segments, in both directions.** `A`'s
salts (segment 3) are published, and segments 4–11, including all of `H`'s
pads, are drawn from the same stream afterwards. That is the two-sidedness
ruling C-3 insists on, and it is the whole reason M-3 must be read as a
statement about the *whole stream*, not as forward unpredictability.

**Claim A-5 [COMPUTED].** `stream_positions.py` lays segments 1–11 out with
byte offsets at five shapes, asserts pairwise disjointness, and totals:

| shape | `fp()` draws, block body | salts | stream bytes |
|---|---:|---:|---:|
| toy | 320,908 | 8,192 | 5,396,672 |
| rung / rung-G | 687,028 | 12,288 | 11,385,664 |
| rung-K4 | 750,540 | 12,288 | 12,401,856 |
| 125M | 9,029,804 | 135,168 | 148,802,240 |

Cross-check: the toy body's 320,908 plus the two frozen-seam endpoints'
6,144 is **327,052**, decision D9's accepted figure to the draw; the 125M
figures are ruling H-6's. Both reproduce from the code with no imported
number.

### 1.3 How many generators

**Claim A-6 [COUNTED].** Every `ZkRng::from_os` on the path, with its domain
and therefore its seed-derivation input length:

| caller | `file:line` | domain | seed input |
|---|---|---|---|
| block prover | `protocol.rs:486` | the block profile | `22 + \|profile\|` |
| **run prover** | `run.rs:475` | the run profile | `22 + \|profile\|` |
| generalised endpoint | `endpoint_g.rs:224` | `DOMAIN`, 42 B (`:45`) | **exactly 64** |
| frozen-seam endpoint | `private_seam.rs:196` | `DOMAIN`, 28 B (`:26`) | 50 |

A boundary takes the **caller's** generator (`boundary.rs:315-328`) and makes
none of its own.

Every `ZkRng::from_os` site on the path, re-read at `8c5922b` and cited in
full (ruling J-2 asks for all of them by name):

| site | line at `8c5922b` | domain passed | seed input |
|---|---|---|---|
| block prover | `hashline/src/private_block/protocol.rs:486` | `sh.profile.as_bytes()` | `22 + \|profile\|` |
| run prover | `hashline/src/private_block/run.rs:475` | `st.rs.profile.as_bytes()` | `22 + \|profile\|` |
| generalised endpoint | `hashline/src/private_block/endpoint_g.rs:224` | `DOMAIN` (`endpoint_g.rs:45`, 42 B) | **64** |
| frozen-seam endpoint | `hashline/src/private_seam.rs:196` | `DOMAIN` (`private_seam.rs:26`, 28 B) | 50 |
| *(off the private-block path)* frozen-seam **prover** | `hashline/src/private_seam.rs:349` | `DOMAIN` | 50 — belongs to `private_seam::prove`, not to this path; the check confirms this exclusion is right |

The read itself is `source.read_exact(&mut entropy)` into a 32-byte buffer,
and the key is `blake3::Hasher::new_keyed(&entropy)` over the domain
(`zkp-core/src/rng.rs:45-47`) — **keyed** mode, the key being the raw
operating-system bytes.

* **A toy proof has three generators**: the block's, and one per frozen-seam
  endpoint, each from its own 32-byte `/dev/urandom` read (`rng.rs:45-46`).
  ~~Their mutual independence is **information-theoretic**, not an M-3
  consequence (correction C-11 of the toy joint-law memo).~~
  **[CORRECTED — the check's B-10, ruling J-2.]** Their mutual independence
  is **not information-theoretic**. `/dev/urandom` is the kernel's CSPRNG: the
  three 32-byte reads are a deterministic function of one finite pool state,
  so they are *computationally* indistinguishable from independent uniform and
  nothing more. Their joint independence is therefore its own named
  assumption, of the same computational kind as M-3 and **not implied by it**:
  > **E-1 (the operating-system entropy assumption).** Separate reads of the
  > operating system's entropy source, made by one process within one proof,
  > are independent and uniform.
  E-1 is the usual assumption and nobody is objecting to it; the correction is
  that it now has a name, so the register can carry it and so that "the rest
  are free" stops being readable off A-11. Ruling J-2 adds it to the accepted
  toy statement as a clarification of what "the generator" means there, beside
  that statement's condition 6 (*"Fresh operating-system randomness per proof;
  no seeded configuration on this profile's path"*).
* **A shaped block has three**, the two endpoints now generalised.
* **A run of `L` blocks has three too — but the sharing is different.** One
  generator serves the whole run (`run.rs:475`, threaded by `&mut` through
  the stage loop at `:487`, never cloned or reseeded), i.e. `L` blocks and
  `L−1` boundaries: **47 of the 49 commitments at `L = 12`** share one
  stream [COUNTED]. Only the two external endpoints keep their own.

**Claim A-7 [COMPUTED].** At 125M, `L = 12`: the run stream carries
109,546,000 `fp()` draws and 2,342,912 salt draws over 1,827,709,184 bytes;
with the two external endpoints, 109,728,784 `fp()` draws — **ruling H-6's
figure, reproduced independently**. At rung-G `L = 3`: 2,093,340; at rung-K4
`L = 3`: 2,283,876. Both are H-6's.

### 1.4 The position map, and whether it is witness-independent

**Claim A-8 [COUNTED + ARGUED].** Write `pos(segment)` for the byte offset at
which a segment starts. By A-1 and A-2, `pos` is `8 ×` the number of
`next_u64`s already made, and by A-4 every count in the schedule is built
from shape constants: row counts (`layout.rs:1063-1140`), `n = 2^log_cols`,
`nn = n·inv_rate`, `Q = 256` (`shape.rs:51`, `pcs.rs:579-581`), `MASK_Q`,
`MASK_DOM`, `Σ L_s`, `N_SLOTS`. By A-3 no count is conditioned on anything.
**Therefore `pos` is a function of the shape alone — not of the witness, not
of the challenges, not of the values drawn.** In a run, the offset of stage
`k` is `k·(block) + min(k, L−1)·(boundary)`, a function of `k` and the shape
[COMPUTED].

> **Understated, and one formula sharpened (the check's A-8 verdict and
> B-4).** `pos` is also independent of the **public statement**, not only of
> the witness — the check re-derived this and the page may say it.
>
> The offset formula above is the offset of the **stage**, and it is right as
> such. The offset of stage `k`'s **block body** is one boundary further on,
> because the stage loop prepares the outgoing boundary *before* the block:
> `boundary::prepare` at `run.rs:504` runs inside the `if k + 1 < l` arm at
> `run.rs:498-509`, and `protocol::prove_core` only at `run.rs:522`
> [re-read at `8c5922b`, this revision]. So the number of boundaries drawn
> before block body `k` is `|{k′ ≤ k : k′ ≤ L−2}| = min(k+1, L−1)`, giving
>
> ```
> offset(stage k)      = k·block + min(k,   L−1)·boundary
> offset(block body k) = k·block + min(k+1, L−1)·boundary
> ```
>
> and a run's schedule is **`11L + 3(L−1)` segments** (eleven per block body,
> three per boundary) — 165 at `L = 12` [COMPUTED] — not "the eleven". §3.1's
> assertion 2 is widened accordingly.

**The position map is COMPLETE.** The independent check re-enumerated every
generator consumption reachable from `prove_inner_at`, `prove_run`,
`endpoint_g::prepare`, `boundary::prepare` and `private_seam::prepare` at
`8c5922b` and found **no twelfth segment**; **no draw inside a parallel
region** (every draw is a sequential `for`/`map` into a buffer that Rayon
then reads by index — `rng.rs:85-87`, `pcs.rs:725, :778`, `zk.rs:462, :513`,
`protocol.rs:655-657, :757-768`, `boundary.rs:324-326`,
`endpoint_g.rs:231-233`, `private_seam.rs:211-213`, against
`pcs.rs:733, :740, :790, :797`, `zk.rs:464, :515`, `merkle.rs:42, :59`); and
**no draw behind a witness, challenge, refusal, feature or environment
branch**. Two independent enumerations agree. That is what licenses ruling
K-R4a's distance hop, and it is the content of §2.0a's first hop.

This is the load-bearing code fact of Part A, and it is established **by
reading, and pinned by no test** (§8, gap **GAP-JS-1**) — complete as a
reading, unpinned as a gate.

**Claim A-9 [COMPUTED] — what rejection sampling would have cost.** If
`fp()` rejected, `pos` would be a random stopping time. The conclusion would
survive — `stream_positions.py` §4 computes, in exact rationals on an i.i.d.
stream with a rejection region, that the post-stopping-time symbols are still
exactly uniform and exactly independent of the accepted values (the strong
Markov property). But the *argument* would change: "disjoint fixed positions"
would have to become a stopping-time argument, and the stopping time would
have to be shown witness-free — a strictly stronger reading of the owed test.
The project needs only the weaker reading, and that is a fact of
`field.rs:37` which nothing pins as privacy-relevant (work-list item W-1).

## 2. The sentence, split into checkable parts

### 2.0 The sentence, as this page can state it

Fix a shape and an admissible public statement. Let `ω` be the prover's
randomness — **the uniform-blinding idealisation**: every `fp()` value a
uniform element of `Fp`, every `bytes32()` value a uniform 256-bit string,
all mutually independent, at the schedule-determined positions of §1.2. Let
`ρ` be a challenge vector with `NR(ρ)` (the prover does not refuse). Let

* `V` = the field view, exactly the list of `ZK60_JOINT_LAW_COMPOSITION.md`
  §2.1 (masked scalars, masked round values, masked terminals, group and
  proximity vectors, `M`'s `q` and proximity rows, and the opened columns);
* `S_pub` = the published salts — 256 slots per commitment, about 1,211
  distinct at the toy;
* `H` = the hash objects — the roots, the authentication paths, and in a run
  the `2L` position-tag fields and the run binding;
* `B = B_salt ∪ B_logup`, with `B_salt` the salt-coincidence event of Lemma H
  (§2.3) and `B_logup` the **union over both worlds** of the zero-lookup-
  denominator refusal;
* `1_{¬B}` the no-bad-event flag, defined by the **same rule** in both worlds.

> **The joint sentence (JS).** For every pair of admissible hidden inputs
> `w, w′` and every `ρ` with `NR(ρ)`,
> ```
> law( V, S_pub, H, 1_{¬B}  |  ρ, NR, w )  =  law( V, S_pub, H, 1_{¬B}  |  ρ, NR, w′ )
> ```
> where
> * **(a)** the salt segments of the stream are independent of every blinding
>   segment. **In the world (JS) is stated in this is a DEFINITION, not a
>   consequence of M-3** (ruling J-1): that world declares every `fp()` and
>   every `bytes32()` value uniform and mutually independent at the
>   schedule-determined positions, and disjoint index sets of a product
>   measure are independent by construction. The position map's content —
>   disjointness, witness-independence, injectivity — is what makes `ω_ideal`
>   a well-defined product measure over the same index set as `ω_real`, and
>   its load therefore sits in the **first hop** below, not here;
> * **(b)** `S_pub` is the restriction of the salt segments to an index set
>   `OPEN_r = f(ρ)` that is a public function of `ρ` alone, so publishing it
>   reveals a fresh uniform string and nothing about `V`;
> * **(c)** given `(V, S_pub, ρ, NR, w)` and the unopened columns and the
>   adversary's `q` oracle answers, the never-opened leaf digests are, off
>   `B_salt`, an i.i.d. uniform product — so `H` is a fixed witness-free
>   kernel `K(H | V, S_pub)` (Lemma H, `ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2);
> * **(d)** `B` is a function of `(ρ, w, w′, ω)` through rules identical in
>   both worlds, and `Pr[B | w] = Pr[B | w′]`.
>
> ~~**The real prover is reached by one distance hop taken BEFORE this
> sentence is used**, not inside it: the whole experiment is a deterministic
> function of `(ω, O)`, so replacing the real `ω` by the ideal one moves the
> view by at most `N · 2^-96`.~~
>
> **CORRECTED (ruling J-1, the check's B-1). The real prover is reached by
> TWO hops, taken BEFORE this sentence is used, and the ORDER is part of the
> statement:**
>
> ```
> real prover
>   →  [hop 1]  the generator assumption (ruling C-3: M-3, two-sided, over
>               the WHOLE stream) — or, inside the model, the term ε_gen(q)
>   →  uniform stream
>   →  [hop 2]  the field sampler's reduction bias: N · 2^-96 (decision D9)
>   →  uniform blinding
>   →  the joint sentence (JS), below
>   →  the composition lemma
>   →  the adaptive view
> ```
>
> with `N · 2^-96` = 2^-77.68 at the toy (`327,052 · 2^-96.0000000003`) and
> 2^-69.29 for a twelve-block 125M run (`109,728,784 · 2^-96.0000000003`)
> [COMPUTED, re-derived in exact rationals this revision]. **`B_samp` is
> still not in the flag** — that part of ruling K-R4a stands.

### 2.0a Why it is two hops, why the order is load-bearing, and where the position map's load sits

**Ruling J-1 (the check's B-1), applied.** The draft's premise — *"the whole
experiment is a deterministic function of `(ω, O)`, **and `O` is independent
of `ω`**"* — is **false as a fact about the experiment**, and this revision
removes it wherever it appeared (here and in A-14).

**Why it is false, in the code.** `ω` *is* a function of `O`. The generator's
refill is an **unkeyed** BLAKE3 query, at every profile
(`zkp-core/src/rng.rs:53-61`, verified at `8c5922b`):

```rust
fn refill(&mut self) {
    let mut h = blake3::Hasher::new();          // rng.rs:54 — UNKEYED
    h.update(&self.key);                        // :55
    h.update(&self.counter.to_le_bytes());      // :56
    self.counter += 1;                          // :57
    let mut out = h.finalize_xof();             // :58
    out.fill(&mut self.buf);                    // :59
```

so the prover's whole stream is `O(key‖0) ‖ O(key‖1) ‖ …` where `O` is the
*same unkeyed function the distinguisher queries* — this page's own claim B-3
says so in as many words (`F_U`, *"still unkeyed, carrying **R2 the refill**
and every statement digest D1–D8"*), and at the two legacy profiles it is
additionally the same function as every leaf, node and column digest (§6.1).
The only thing between the distinguisher and the stream is that `key` is
secret. Independence of `O` and `ω` is therefore the **content of the first
hop**, not a premise available before it.

**Why the ORDER is part of the statement.** The second hop is a statement
about *a uniform 128-bit input*: it says that reducing 128 uniform bits mod
`p` lands within `2^-96.0000000003` of uniform on `Fp` (A-12). Before the
first hop the sampler's input is not uniform — it is `O(key‖·)` — so hop 2
has nothing to be a statement about. Taken in the other order the second hop
is not merely unproved, it is **not well formed**. Hence: hop 1, then hop 2,
then (JS).

**Where the position map's load sits.** In the first hop. Its job is *not* to
make clause (a) true — in the post-hop world (a) is a definition. Its job is
to turn *"the stream is uniform"* into *"these eleven segments are
independent uniform vectors"*: it is what makes `ω_ideal` a well-defined
product measure **over the same index set** as `ω_real`, so that "replace
`ω_real` by `ω_ideal`" is a map at all. A-8's schedule-determined positions
and A-3's no-re-draw are exactly that, and the check's independent
enumeration confirms both (§4 of the check: no twelfth segment, no draw in a
parallel region, no draw behind a witness, challenge, refusal, feature or
environment branch).

**What follows for the labels.** In the resulting world, clause **(a)** and
clause **(c′)** are **definitions**, not consequences of M-3. A-10's table
below therefore no longer books M-3 twice — once for the hop and once inside
a sentence stated after it.

**The conditioning, priced (the check's B-1b).** (JS) is stated conditioned
on `NR(ρ)`; the hops are taken unconditioned. Total variation does not
survive conditioning for free:
`TV(P|A, Q|A) ≤ TV(P, Q)/Pr[A]`. With `Pr[refuse] ≤ 2^-112` (the accepted toy
statement's refusal row) the inflation factor is
`1/(1 − 2^-112) < 1 + 2^-111`, i.e. **under `2^-111` of a bit** — nothing
moves, but the step now appears on the page instead of being silently
skipped. [COMPUTED: `log2(1/(1 − 2^-112)) < 2^-111`.]

### 2.1 Clause (a): the salt segment against the blinding segments

**Claim A-10, as corrected by ruling J-1.** Under the idealisation "the
stream is uniform" — assumption **M-3** in ruling C-3's two-sided
whole-stream form, which is *hop 1* of §2.0 — clause (a) **is immediate**,
and it is immediate for exactly one reason: *disjoint byte ranges of a
uniform string are independent.* In the post-hop-1 world that reason is the
**definition** of the world, so (a) is not a second use of M-3; what the two
code facts below buy is that the hop itself is a well-defined map (§2.0a).
Two things have to be true for that to be the whole argument, and only one of
them is an assumption:

| ingredient | status |
|---|---|
| the positions are **disjoint** | **theorem about the code** (A-4, A-8): consecutive non-overlapping ranges, asserted pairwise in `stream_positions.py` |
| the positions are **witness-independent** | **theorem about the code** (A-2, A-3, A-8): every count is a shape constant; no rejection, no re-draw, no witness branch |
| the stream is **uniform** | **[ASSUMED] — M-3 (ruling C-3)**, in the two-sided whole-stream form, and nothing else. **Booked ONCE, as hop 1 of §2.0** (ruling J-1): it is not charged again inside (JS). The block memo's §5.3 row 6 calls this "the one candidate with no structural answer" and it is right to |
| the three generators are **jointly** independent | **[ASSUMED] — E-1**, the operating-system entropy assumption (ruling J-2, A-6). Not implied by M-3 |
| the positions are pinned by a **test** | **no. GAP-JS-1** |

So: clause (a) holds by construction in the world of §2.0, that world is
reached from the real prover by hop 1 (M-3 / `ε_gen(q)`) and hop 2 (the
sampler, `N·2^-96`) in that order, and the code half — the position map — is
a reading that nothing in the test suite would notice breaking. That is the
honest shape of the answer to the brief's question, and it is weaker than
"immediate" and stronger than "no structural answer": **the structural answer
exists and is unpinned; the assumptions are unavoidable and are M-3 and
E-1.**

**Claim A-11 [COUNTED], as corrected by ruling J-2.** The part that does
*not* rest on M-3 is smaller than a reader might hope, and it is **not free**.
At the toy, three separate `/dev/urandom` reads make the block's stream and
the two endpoints' streams independent without M-3 — but **under E-1**, not
information-theoretically; `A`, `M` and `H` — and therefore every salt the
block publishes against every pad it hides — are one stream, and there M-3 is
the only argument. Counting pairs: at a single block **three** commitments
share one stream, so `C(3,2) = 3` pairs rest on M-3 and the rest rest on
**E-1**. **In a twelve-block run forty-seven of the forty-nine commitments
(`4L − 1 = 47` of `4L + 1 = 49` at `L = 12`) share one stream, so
`C(47,2) = 1,081` pairs rest on M-3** [COMPUTED — `47·46/2 = 1,081`,
re-derived]. Unchanged in kind; worse by two and a half orders of magnitude in
degree.

> **What changed and what did not (J-2).** The **count is right** — 3, 1,081,
> 47 of 49 — and it is kept. What is corrected is the *characterisation* of
> the complement: the headline "three pairs rest on M-3 and the rest are
> information-theoretic" is replaced by "three pairs rest on M-3 and the rest
> rest on E-1". Two assumptions, neither implied by the other.

### 2.2 The sampler leaves the flag — and why the arithmetic forces it

**Claim A-12 [COMPUTED].** For `p = 2^64 − 2^32 + 1` and `N = 2^128`:
`k = ⌊N/p⌋`, `r = N − kp = 18446744065119617025`, and `p − r = 2^32` exactly.
Hence

```
TV(real draw, uniform)   = r(p−r)/(pN) = 2^-96.0000000003
Pr[rejection region]     = r/N         = 2^-64.0000000007
```

**Claim A-13 [PROVED + COMPUTED].** No coupling whose good event carries an
exactly uniform value can have bad probability below `r/N`. Such a coupling
is a constant `c ≥ 0` with `Pr[X = v, good] = c` for every `v` and
`c ≤ Pr[X = v]`, so `c ≤ min_v Pr[X = v] = k/N` and
`Pr[bad] = 1 − pc ≥ 1 − pk/N = r/N`. The rejection-region coupling attains it.
`sampler_coupling.py` confirms the identity exhaustively on six small
analogues (`p, N` = 5,16; 7,32; 11,64; 13,128; 5,1024; 17,256), and reproduces
the maximal coupling's conditional law as **not uniform** — which is the
check's B-4 objection, correct as far as it goes.

**Claim A-14 [COMPUTED].** In event form the sampler would cost
`327,052 · 2^-64 = 2^-45.68` at the toy and `109,728,784 · 2^-64 = 2^-37.29`
for a twelve-block 125M run — 32.0 bits worse than the distance form at every
shape.

This page reached A-12…A-14 independently and before reading ruling
**K-R4a** (security owner, 2026-09-21 02:42), which rules the same way and
for the same reason. Two things this page adds:

* **the closed-form criterion** [COMPUTED]: the distance hop beats the event
  form iff `2·TV < Pr[rej]` iff `2(p − r) < p`. Goldilocks satisfies it by
  31 bits because `p − r = 2^32`; a small field need not, and
  `sampler_coupling.py` prints an instance (`p = 5, N = 16`) where the event
  form is the *better* of the two, so that nobody reads the criterion as
  universal;
* **why the hop is legitimate under an ADAPTIVE challenge schedule**, which
  K-R4a states in one clause. ~~The whole experiment — prover, challenge
  oracle, distinguisher — is one deterministic function of `(ω, O)`, and `O`
  is independent of `ω`; so by data processing the view moves by at most
  `TV(ω_real, ω_ideal)` **whatever the challenge schedule does**.~~
  **CORRECTED (ruling J-1, the check's B-1).** The premise *"`O` is
  independent of `ω`"* is **struck**: the refill is an unkeyed BLAKE3 query
  in the very function the distinguisher queries (`rng.rs:54`; §2.0a). The
  data-processing argument is valid, but **only inside the post-hop-1
  world**, and this is where it is now stated: *after* the generator's output
  has been replaced by an independent uniform string (hop 1 — the named
  assumption C-3/M-3, or `ε_gen(q)` inside the model), the experiment —
  prover, challenge oracle, distinguisher — is one deterministic function of
  `(ω, O)` with `ω ⟂ O` **by the hop**, so by data processing the view moves
  by at most `TV(ω_real, ω_ideal)` whatever the challenge schedule does.
  Applied to the *real* world, as the draft wrote it, its hypothesis fails.
  This is also exactly where the schedule-determined positions of A-8 are
  needed, and §2.0a says why: they are what makes `ω_ideal` a well-defined
  product measure over `ω_real`'s index set, so the map exists at all — that
  load belongs to hop 1.
  `sampler_coupling.py` §6 runs a complete two-round adaptive model with a
  witness-dependent refusal, exhaustively over all 3,125 challenge schedules,
  and confirms both bounds hold and which is smaller in which regime. That
  model is unaffected: it idealises the generator, i.e. it is already stated
  in the post-hop-1 world.

**A code-comment defect worth one line.** `zkp-core/src/rng.rs:72` reads *"a
128-bit draw reduced mod p: bias 2^-64"*, and `zkp-core/src/transcript.rs:113`
says the same of `challenge_fp`. `2^-64` is the **rejection-region
probability**, not the distance from uniform, which is `2^-96`. The comment is
wrong for the number the project publishes and accidentally right for the
number K-R4a has just ruled out. It is a comment in the integrator's crate;
it goes to the integrator with the `hashtag.rs:22-33` correction already
named by ruling H-3.

### 2.3 Clause (b): the published salts

**Claim A-15 [COUNTED + ARGUED].** Given `ρ`, the opened index set is
`Transcript::challenge_indices` (`zkp-core/src/transcript.rs:136-148`), a
public function of the transcript state and counter, hence of `ρ` in the
fixed-challenge experiment. A salt enters exactly one object: the leaf hash
`salt_leaf(hash_column(col), salt)` (`pcs.rs:678`), and the verifier
recomputes that same leaf from the published column and the published salt
(`pcs.rs:1126-1127`, tagged `:1248-1249`). It enters **no** field value, no
absorb, no challenge. So `(V, S_pub)` has the product law
`law(V | ρ, NR, w) ⊗ Unif({0,1}^256)^{|S_pub|}`, and the first factor is
witness-free by the accepted fixed-challenge theorem.

Two riders, both needed:

1. **No refusal reads a salt.** The eighteen refusal classes are
   challenge-driven or witness-driven; the witness-driven one is the zero
   LogUp denominator (`protocol.rs:402-405`), the challenge-driven ones are
   `argument.rs:332-334, :404-406, :765-768` and `protocol.rs:284-291`. None
   touches `salts`. So conditioning on `NR(ρ)` does not tilt the salt
   segment. [ARGUED from the refusal inventory; not machine-checked.]
2. **In the fixed-challenge experiment `ρ` is exogenous, so the index set is
   independent of the salt values.** In the *real* protocol `ρ` is a hash of
   the roots, which are functions of *all* the salts — so which salts get
   published is correlated with what they are. That correlation is exactly
   what the Fiat–Shamir lift has to handle and what this sentence must not be
   read as handling. It is the first place an attacker should look (§11).

### 2.4 Clause (c): the hash objects given the field view and the salts

**Claim A-16 [RELIES ON Lemma H], as corrected by ruling J-4 (the check's
B-2, B-13).** `ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2, as corrected by its
check (C-10), gives exactly the conditional form needed: off an event
`B_salt` of probability

```
q·N_leaf·2^-256 + C(N_leaf,2)·2^-256 + N_overlap·2^-256
                + N_node·N_leaf·2^-512 + ε_gen(q)
```

the never-opened leaf digests are an i.i.d. uniform product **given** the
field view, the published salts, the unopened columns themselves, the
witness, and the adversary's `q` answers. Hence
`H = T^O(opened columns, S_pub, unopened digests)` with `T^O` public, and
`law(H | V, S_pub, ρ, NR, w)` is a witness-free kernel.

> **What was wrong.** ~~The draft's four-term formula~~ **dropped
> `+ ε_gen(q)`**, which is the last term of Lemma H's own bound
> (`ZK60_HASH_LAYER_AND_FS_LIFT.md:558`) and is *the one term Part A is
> about* — it is hop 1's price inside the model (§2.0a). Restored above.

**The toy's instantiation, every term re-derived here** [COMPUTED, exact
integers, this revision; `N_leaf = 12,288`, `N_overlap = 24,571`,
`N_node·N_leaf = 12,287 · 12,288 = 150,982,656`]:

| term | exact count | value | how it arises |
|---|---|---|---|
| `q · N_leaf · 2^-256` | `12,288 = 2^13.585` | **`q · 2^-242.4150`** | the adversary guesses one unopened leaf's 32-byte salt, `q` tries against `N_leaf` leaves |
| `C(N_leaf,2) · 2^-256` | `C(12,288,2) = 75,491,328 = 2^26.1698` | **`2^-229.8302`** | two leaf inputs collide |
| absorb-input collision (B4) | `C(4,000,2) = 7,998,000 = 2^22.9312` | **`2^-233.0688`** | two distinct absorb inputs collide — the transcript's binding (`ZK60_HASH_LAYER_AND_FS_LIFT.md:813, :1333`) |
| `N_overlap · 2^-256` | `24,571 = 2·12,288 − 5 = 2^14.5847` | **`2^-241.4153`** | a leaf input equals a node input |
| `N_node · N_leaf · 2^-512` | `150,982,656 = 2^27.1698` | **`2^-484.8302`** | the leaf/node format coincidence of correction C-4 |
| `ε_gen(q)` | — | the named assumption; inside the model `6q·2^-256 = q·2^-253.42` | hop 1 (`…:1242`) |

**EDITOR'S NOTE (provenance of `2^-233.07`, applied as ruled).** Ruling J-4
directs that the absorb-input term be carried here. Its home in the source is
`ZK60_HASH_LAYER_AND_FS_LIFT.md` **§3.2 row B4** and the `ε_lift` line at
`:820`, i.e. the Fiat–Shamir lift, whereas `Pr[B_H]` as printed at `:558-565`
of that memo carries the other four terms and `ε_gen(q)` but not this one.
The accepted toy statement nonetheless lists it among its oracle-collision
figures (`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md:140`, *"2^-229.8; 2^-233.1;
2^-241.4"*). Carrying it in the flag's price is therefore **conservative** —
it can only enlarge the bound — and the ruling is applied as written. I record
the provenance so that nobody later re-derives `Pr[B_H]` from §2.2 and
concludes the term is spurious. Arithmetic checked: `C(4,000,2)·2^-256 =
2^-233.0688`, matching `…:1333`'s `2^-233.07`.

**Does it silently use independence it has not got? One place — and, after
the check, it turns out to be covered.** Lemma H's hiding randomness is the
salts of the **unopened** leaves — 11,077 of the toy's 12,288. Those live in
the **same stream segments** as the published ones (segments 3, 7, 11 of
§1.2): the published and the withheld salts are interleaved inside one
segment, selected by `ρ`. So "the unopened salts are still uniform given the
published ones" is not a disjoint-segment fact; it is a **within-segment**
conditioning, and it needs the uniform stream plus rider 2 of A-15 (the
selection is `ρ`-determined). Written out:

> **(c′)** *In the world of §2.0 — i.e. after hop 1 — and with the opened
> index set a function of `ρ` alone, the restriction of a salt segment to the
> unopened indices is uniform and independent of its restriction to the
> opened indices and of every blinding segment.*

~~That is a **[GAP → now stated]**, not a theorem proved here: it is
immediate from M-3 and A-15 rider 2, and it is not immediate without
either.~~

> **RE-LABELLED (ruling J-6, the check's B-5). (c′) is NOT NEW, NOT OWED and
> NOT CIRCULAR. It is a DEFINITION in the world (JS) is stated in, and a
> documentation sentence about the code.**
>
> * **Not new.** Lemma H's conditional statement already conditions on the
>   published salts: *"law( (u_{r,k}) | V = v, **S_pub = s**, ρ, NR, w, the
>   unopened columns themselves, and the adversary's q oracle answers ) =
>   Unif({0,1}^256)^{⊗m}"* (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2). The
>   conditioning on `S_pub` is in the lemma as stated.
> * **Not circular.** Lemma H is stated in the fixed-challenge experiment and
>   says so at length — *"In that experiment `ρ` is exogenous, so conditioning
>   on it assumes nothing about the roots, which are outputs. The real
>   protocol, where `ρ` is a hash of the roots, is §3"* (that memo, §2.1) —
>   and (JS) is stated in the **same** experiment (A-15 rider 2). The loop
>   *"conditioning on `ρ` is conditioning on oracle outputs at points that
>   include the root"* is entered in the Fiat–Shamir lift, §3 of that memo,
>   which this page explicitly does not touch and which already owes it.
> * **Not owed, and not a second use of M-3.** What ruling K-R3 owes is the
>   joint sentence, and the honest answer to it is §2.0's **two-hop
>   ordering**, not a new clause. In the post-hop-1 world every `bytes32()`
>   value is uniform and mutually independent *by the definition of that
>   world*, so the unopened salts are uniform given the opened ones **in one
>   line**. The residual — that the salts really come from the generator — is
>   hop 1, and it is already priced in Lemma H's own bound as `+ ε_gen(q)`,
>   the term A-16 had dropped.
> * **What (c′) does add:** documentation. It records *where in the code* the
>   salts come from and *that the opened/unopened split lives inside one
>   segment*, which no document said. Kept as a remark, at that weight.
>
> **GAP-JS-2 is therefore WITHDRAWN** (§13), marked and not deleted.

### 2.5 Clause (d): the flag

**Claim A-17.** After K-R4a the flag is two events, not four:

| event | rule | same in both worlds? | price |
|---|---|---|---|
| ~~`B_samp`~~ | **removed** (K-R4a) — a distance hop before the lemma | — | 2^-77.7 / 2^-69.3 as a distance |
| ~~`B_sep`~~ | **removed** (K-R1) — a failed hypothesis, repaired by one hybrid hop | — | the same price, in the model |
| `B_salt` | a function of the salt segments and the adversary's queries; no witness enters | yes, by construction | ~~2^-229.8 (toy)~~ → **`q·2^-242.4150 + 2^-229.8302 + 2^-233.0688 + 2^-241.4153 + 2^-484.8302 + ε_gen(q)`** (toy) — see below |
| `B_logup` | **the union over both worlds** of the zero-lookup-denominator refusal | yes, because the union is taken | 2^-117.4 per block (two-world); the one-world figure is 2^-118.4 |

**UNDER-PRICED, and restored (ruling J-4, the check's B-2).** The draft
priced `B_salt` at `2^-229.8` — which is **the largest collision term of a
five-term event, not the event**. Exactly the failure mode this project's
errata discipline exists for: a figure carried from one document into another
in a form it does not have there. Every term of A-16's formula is now on the
row, with its derivation given in A-16's table. Two things a reader must take
from it:

* **`q·2^-242.4150` is the term that matters for a real adversary, and the
  draft dropped it.** It overtakes the fixed coincidence term at
  `q = C(12,288,2)/12,288 = 6,143.5`, i.e. from **`q = 6,144 = 2^12.585`**
  queries on [COMPUTED, exact: `75,491,328 / 12,288 = 6,143.5`]. For any
  adversary making more than about four thousand oracle queries the dropped
  term is the *dominant* one, and the memo as drafted would have let a reader
  quote a flag probability more than thirty bits too small.
* **The mechanism the draft gave for `2^-241.42` is wrong, and the figure is
  right.** §6.1 and §6.2a said the coincidence *"needs a digest to spell 24
  fixed bytes"*. Twenty-four fixed bytes is `2^-8·24 = `**`2^-192`** per
  pair [COMPUTED], not `2^-241.42` — a weaker argument, and 49 bits away.
  The figure of record comes from elsewhere: the 32-byte **salt** of each of
  the `N_overlap = 24,571` salted-leaf and inner-node objects is uniform, and
  the bound counts one `2^-256` per object —
  `24,571 · 2^-256 = 2^-241.4153` [COMPUTED]
  (`ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md:77, :309`). Both §6.1 and §6.2a are
  corrected in place.

**No total moves, and here is the margin.** The statement of record already
carries every one of these terms, so nothing accepted changes. Against the
sampler's `2^-77.68` (hop 2 at the toy):

| term | size | bits below the sampler |
|---|---|---|
| `2^-229.8302` | fixed | **152.15** |
| `2^-233.0688` | fixed | 155.39 |
| `2^-241.4153` | fixed | 163.73 |
| `2^-484.8302` | fixed | 407.15 |
| `q·2^-242.4150` at the statement's maximal `q = 2^128` | `2^-114.4150` | **36.73** |

[COMPUTED, this revision.] **EDITOR'S NOTE.** Ruling J-4 says the sampler
"dominates by more than a hundred bits". That is right for every
`q`-independent term (152 bits and more). Against `q·2^-242.415` at the
statement's own ceiling `q ≤ 2^128` the margin is **36.73 bits**, not a
hundred — still dominant, still no change to any total, but the ruling's
phrase should not be quoted at a large `q`. Nothing accepted moves either
way.

The union in `B_logup` is forced, not decorative: the check's C4 computation
shows a single-world flag violating the bound by 3/8 on an eight-value
instance. Both figures stay, each labelled.

**One thing the flag must also say, which no document states.** The game is
**accepted receipts only** (D21; M-9 for a run). An aborted attempt — the
`inverses()` discard of A-3 — has already consumed segments 1–7 of the stream
and produced no receipt. Under the accepted-receipts game that attempt is not
in the probability space at all, and the sentence is conditioned on `NR`. If
anybody ever hands a relying party a refused prefix, the conditioning breaks
and so does the lemma's hypothesis (ruling K-R5 says the same from the other
side). **This is a second reason the sentence cannot be quoted without M-9.**

## 3. The two counterexamples, aimed at (JS)

`counterexamples.py`, exact arithmetic mod 101, six seeds plus one
adversarially constructed instance per seed.

**Claim A-18 [COMPUTED] — counterexample (i), a shared blinding row.** Two
claim sites, three published coordinates each. With independent rows the
disclosed dimension is 0; with one row shared it is 3, while **each site's
marginal is still perfectly blinded**. The difference `V_0 − V_1` equals
`(M_0 − M_1)·w` with the blinding cancelled, for every blinding value, and it
separates two witnesses. Six seeds, all assert.

**Which clause of (JS) excludes it, and what kind of thing that clause is.**
Clause (a) — *disjoint witness-independent stream positions* — via A-4 and
A-8: a shared row would mean two roles reading the **same byte range**, which
the segment schedule forbids by construction. **This is a THEOREM about the
code** (the schedule is built from shape constants and the ranges are
consecutive) **and it is pinned by no test.** The project's rank gates would
also catch it, because a shared row changes the *structure* the gate reads.

**Claim A-19 [COMPUTED] — counterexample (ii), ruling R-3's variant.** Two
**distinct** rows at **disjoint** positions whose **values** coincide. The
gate's disclosed dimension is 0 on all six seeds — the honest answer, because
the gate computes a rank over two independent symbols — and the realised view
determines `(M_0 − M_1)·w` exactly on all six. **No rank computation can see
it**, because the gate is a statement about which symbol each site uses and
the leak is a statement about the values.

**Which clause excludes it.** Clause (a) again, but a *different half* of it:
not "the positions are disjoint" but "the stream is uniform" — **M-3**. Under
M-3 two disjoint 256-word ranges coincide with probability `p^-256 = 2^-16384`
[COMPUTED], which is not a term anybody carries.

**And this is the honest sharpening ruling R-3 was reaching for.** The
counterexample is not really about an accident. If the draw discipline is
broken — a reused buffer, a cloned generator, an off-by-one in a draw count,
a re-entered commit path — the coincidence has probability **one**, and it is
invisible to every gate the project runs *and* to M-3, which is an assumption
about a correctly consumed stream and says nothing about a stream consumed
twice. So:

> **The part of (JS) that excludes ruling R-3's counterexample is the
> witness-independence AND injectivity of the position map — a theorem about
> the code today, a reading, and the thing the owed test must assert.**

`counterexamples.py` measures the accidental rate at two small dimensions to
show the pricing is the right shape (`k=1`: predicted 9.901e-03, measured
1.014e-02 over 400,000 trials; `k=2`: predicted 9.803e-05, measured
1.075e-04) and then says in as many words that the accident is not the risk.

### 3.1 What the owed test must assert, exactly

Ruling **R-3** asks for a machine assertion. Here is what it has to say for
clause (a) to become a code fact. Each line is one assertion.

> **FIVE IS NOT ENOUGH — SEVEN (ruling J-5, the check's B-4).** The five
> below are all statements about **which symbol each site uses**: assertions
> 1–4 are byte offsets and ranges, assertion 5 is "no clone, one
> construction". This page's own A-19 says *"the gate is a statement about
> which symbol each site uses and the leak is a statement about the
> values"* — and then specifies a test made only of the first kind. Two
> defects keep every position disjoint, witness-independent and correctly
> offset, pass all five, and still correlate the realised values: the
> zero-sum row's computed entry (**in the code today**) and a
> deterministically seeded generator (**one line off the path**). Assertions
> **6** and **7** close them. The five are kept unchanged; two are added.

1. **Total consumption.** A block proof at shape `S` consumes exactly
   `bytes(S)` stream bytes, the closed form of `stream_positions.py`
   (5,396,672 at the toy). A run at shape `S`, `L` blocks, consumes exactly
   `L·bytes(S) + (L−1)·bytes_boundary(S)`.
2. **Per-role offsets.** ~~Each of the eleven segments of §1.2~~ **Each of a
   run's `11L + 3(L−1)` segments** (eleven per block body, three per
   boundary — WIDENED per J-5/B-4) begins at the offset the schedule
   predicts, and the segments are pairwise disjoint and cover the
   consumption with no hole. The interleaving to assert is
   `[boundary_k if k+1<L] then [block_k]` (`run.rs:498-523`), so block body
   `k` starts at `k·block + min(k+1, L−1)·boundary` and stage `k` at
   `k·block + min(k, L−1)·boundary` (A-8).
3. **Witness-independence.** Two different admissible witnesses at the same
   shape produce **identical** consumption and identical per-segment offsets.
   (The zero-witness fixtures give one of the two for free.) The check adds
   that consumption is independent of the **public statement** too, which is
   worth asserting in the same line.
4. **Injectivity across roles.** No two roles — the `4L+1` commitments'
   pads, mask rows and salts — are ever assigned overlapping ranges; in a run
   this is the `47`-commitment statement, and it is the one R-3 names.
5. **The generator is never cloned, forked or serialised**, and `prove_run`
   constructs exactly one (ruling R-2's condition, today a reading of
   `run.rs:475`).
6. **The realised value map — values at distinct positions are not functions
   of one another EXCEPT where the schedule says so BY NAME.** Enumerate every
   deterministic relation the prover imposes on drawn values *after* drawing
   them, and assert that the set of such relations is **exactly** the
   declared one, so that a reused buffer, a repeated slice or a re-entered
   commit path is a failure and not a silence. The declared set today, by
   name and with the line at `8c5922b` [re-read, this revision]:

   | relation | site | kind |
   |---|---|---|
   | `b_re[m] := −b_re[0]` | `hashline/src/zk.rs:505` | an **overwrite**: the word drawn at position `m` is consumed and then discarded |
   | `b_im[m] := −b_im[0]` | `hashline/src/zk.rs:506` | the same |
   | the last entry of each `H` zero-sum row, `h_data[r·n + n−1] := −Σ_{j<n−1} h_data[r·n + j]`, over `r ∈ lay.h_u_rows()` | `hashline/src/private_block/protocol.rs:760-768`, the assignment at `:767` | **not** an overwrite: that position is never drawn (the loop at `:762` runs `j` over `0..n−1`) |

   Nothing else. A-3 calls the first two *"an overwrite, not a re-draw"* and
   moves on; for **positions** that is right, and this page keeps it. For
   clause (a) the object that matters is the map from consumed stream words
   to **committed blinding values**, and that map is not injective: two
   committed entries carry a deterministic linear relation and two drawn
   words are thrown away. It is declared, and the CFS argument models it —
   which is exactly why the test must assert the declared set is the whole
   set.
7. **The key is fresh — no profile on this path can obtain a generator other
   than from the operating system.** This is the accepted toy statement's
   **condition 6** (*"Fresh operating-system randomness per proof; no seeded
   configuration on this profile's path"*,
   `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`), turned into a test. Assert that
   every generator on a production path is built by `ZkRng::from_os` from its
   own 32-byte read (`rng.rs:45-47`), and that **`ZkRng::new`
   (`zkp-core/src/rng.rs:20`) is unreachable** from `prove_inner_at`,
   `prove_run`, `endpoint_g::prepare`, `boundary::prepare` and
   `private_seam::prepare`.

   **Why it is needed, and exactly how far off the path the defect is.**
   `ZkRng::new(seed, domain)` is a deterministic fixture generator, and it is
   reachable through **`ZkConfig::rng`** (`hashline/src/zk.rs:334-340`),
   which reads
   ```rust
   match self.seed {
       Some(seed) => ZkRng::new(seed, domain),          // zk.rs:336
       None => ZkRng::from_os(domain) …                 // zk.rs:337
   }
   ```
   whenever `ZkConfig.seed` is `Some`. **Today it is NOT reachable from the
   private block**: the private block's three generators are the direct
   `from_os` calls of A-6 (`protocol.rs:486`, `run.rs:475`,
   `endpoint_g.rs:224` / `private_seam.rs:196`), and none of them goes
   through `ZkConfig::rng` [re-read at `8c5922b`, this revision]. But a
   generator seeded deterministically **is one**, is never cloned, has
   perfect offsets, and passes assertions 1–5 while making every proof of
   every witness identical — and nothing in the five looks at where the key
   came from. The condition is accepted; the test is what makes it hold
   tomorrow.

**Does it need a hook inside `zkp-core/src/rng.rs`?** **Yes, and that file
belongs to another engineer.** `ZkRng`'s fields are private
(`rng.rs:9-14`) and there is no `pos()`, `consumed()` or counter accessor.
Assertions 1–4 cannot be written from outside the crate. The smallest thing
that would do it is a `#[cfg(test)]`-or-always accessor returning
`counter·8192 + pos`, plus (for 4) an optional label-and-range recorder. **It
is to be requested of the integrator, not written by the lane** — as ruling
R-3 already anticipates ("If that needs a hook in `zkp-core/src/rng.rs`, it
is asked of the integrator"). This page's contribution is the list above, so
the request can be made once and completely.

> **The request is out (ruling J-5).** A **test-only consumption accessor on
> the generator** was asked of the integrator on **2026-09-21 03:25**, in the
> handoff, together with the count: **the owed draw-accounting test needs
> seven assertions, two of them about values.** Assertion 6 also needs the
> map from consumed words to committed values, which the accessor plus the
> declared relation table above supplies; assertion 7 needs no hook at all —
> it is a source-scan and a reachability assertion, and the lane can write it
> today. Until the accessor lands, assertions 1–4 and 6 are **owed and
> blocked on another engineer's file**; 5 and 7 are owed and **not blocked**
> (§8, W-8).

## 4. What changes at a shaped block, and in a run

**Claim A-20 [COUNTED] — a shaped block.** Three differences, none of which
touches the structure of (JS):

1. **More commitments and bigger ones.** The generalised endpoint has five
   mask rows (`endpoint_g.rs:52, 148`: one reserved pair plus three proximity
   rows) against the frozen seam's same five (`private_seam.rs:36, 110`); the
   geometry differs, the schedule does not.
2. **Internal boundaries exist** (runs only), six mask rows and
   `(endpoint_rows+1)·256` pads, on the **caller's** stream
   (`boundary.rs:315-328`).
3. **The pad-zero term draws nothing from the generator. CONFIRMED.** `ζ` and
   `mu_pad` are transcript squeezes — `argument.rs:961, 1027, 1028, 1224,
   1299, 1352, 1410, 1485`, each `tr.challenge_fp2_vec(1)` or
   `tr.challenge_fp2()`, with the zero refusal at `argument.rs:765-768`
   (`fn nonzero` at `:765`, its string at `:767`).
   `n_pad = usize::from(pad_on)` (`argument.rs:935`) and `pad_doms`
   (`:933`) are pure functions of the shape, so even the *challenge* counts
   are shape-determined. The brief asked this to be confirmed; it is.

**Claim A-21 [COUNTED] — a run.** Four differences, one of which matters:

1. **One generator for the whole run** (`run.rs:475`), ruling R-2 as built.
   The run's blinding and the run's salts for `4L−1` of the `4L+1`
   commitments are segments of one stream, so clause (a) rests on M-3 across
   **eleven stage boundaries** at `L = 12` — stage 1's salts are published
   before stage 12's mask rows are drawn.
2. **Block `k`'s generator state is CARRIED, not dropped** — `rng` is
   declared outside the stage loop and threaded by `&mut` (`run.rs:475`,
   `:504`, `:522`). Is that a memory fact or a privacy-relevant one? **It is
   privacy-relevant, and in the project's favour**: carrying one stream is
   what makes the per-stage offsets `k·(block) + min(k,L−1)·(boundary)`
   deterministic, hence disjoint, hence clause (a). What is *dropped* between
   stages is the witness segment and the committed data, which is a memory
   fact. The one thing carrying costs is the ~~information-theoretic~~
   **E-1-based** independence a per-commitment generator would have given
   (A-11, as corrected by ruling J-2) — which ruling R-2 withdrew
   deliberately, for one fail-closed entropy point instead of forty-nine.
   Note that the trade is between **two assumptions**, M-3 and E-1, not
   between an assumption and a free fact.
3. **The draw counts per stage are shape-determined and witness-independent,
   verified on the refusal and re-draw paths** [COUNTED]: per-stage layouts
   differ only in `io_mask_row` (`run.rs:391-393` →
   `layout.rs:1151-1154`), which does not change `a_rows` or `h_rows`, so
   every stage draws the same amount; the re-draw paths do not exist (A-3);
   the refusal paths abort the run (and, by ruling H-1, the whole forward
   pass has already run before the header, so an admissible chain never
   refuses).
4. **The hash view gains objects**: the `2L` position tags and the run
   binding. They are transcript outputs at prefix-determined points, so they
   belong to `H` and are covered by clause (c) — but see claim B-6, which is
   where they bite.

---

# PART B — the complete query-class table (ruling K-R2)

## 5. Every BLAKE3 call kind on the path

**Claim B-1 [COUNTED], EXTENDED by ruling J-7.** ~~Twenty-four distinct call
kinds~~ — **twenty-six**, against the draft's five: the independent check
found two hand-written BLAKE3 kernels in CUDA that are reached on the
production path at exactly the two legacy profiles (rows **G1** and **G2**
below, §5.2), and further in-process hash sites that were in neither list
(§5.3). Mode column: `new()` = unkeyed, `new_keyed(k)` = keyed, `derive_key`
= BLAKE3's third mode. "Rule" says whether the kind moves into a tagged
family.

| # | kind | `file:line` at `8c5922b` | mode / key | input layout | length | who | input is |
|---|---|---|---|---|---|---|---|
| **T1** | transcript constructor, legacy | `zkp-core/src/transcript.rs:30` | `new()` | `"hashline-v1/"(12) ‖ domain` | `12+\|d\|` | both | public |
| **T2** | transcript constructor, tagged | `transcript.rs:41` | keyed, **transcript key** | same layout | `12+\|d\|` | both | public |
| **T3** | transcript absorb | `transcript.rs:61` | selector, transcript key or none | `state(32) ‖ le64(\|l\|) ‖ l ‖ le64(\|d\|) ‖ d` | `48+\|l\|+\|d\|` | both | **public** (see B-5) |
| **T4a** | transcript squeeze, live | `transcript.rs:103` | selector | `state(32) ‖ "squeeze"(7) ‖ le64(ctr)(8)` | **47** | both | public |
| **T4b** | squeeze off a discarded clone — a run **position tag** | `run.rs:404-411` via `transcript.rs:156-162` | selector | identical to T4a | 47 ×2 | both | public |
| **T4c** | squeeze off a discarded clone — the **refusal replay** | `protocol.rs:305-306`, `:367-368`, `boundary.rs:281-283` | selector | identical to T4a | 47 each | prover, then verifier | public |
| **P1** | column digest, single (verify side) | `zkp-core/src/pcs.rs:139` / keyed `:149` | selector, **column key** | the column's `rows` words, LE, **no tag, no length prefix** | `8·rows` | both | **secret** for unopened |
| **P2** | column digests, bulk (commit side) | `pcs.rs:171` (`blake3::hash`) / keyed `:196` | selector, column key | same bytes | `8·rows` × `nn` | prover | secret |
| **P3** | salted leaf | `pcs.rs:678` / keyed `:692` | selector, **leaf key** | `column digest(32) ‖ salt(32)`, **untagged** | **64** | both | **secret — the salt** |
| **P4** | Merkle inner node | `zkp-core/src/merkle.rs:15` / keyed `:28` | selector, **node key** | `left(32) ‖ right(32)`, **untagged** | **64** | both | secret above unopened |
| **P5** | `M` column digest | `hashline/src/zk.rs:689` / keyed `:697` | selector, column key | as P1, `rows = 50` | **400** | both | secret |
| **R1** | generator **seed derivation** | `zkp-core/src/rng.rs:47` | **keyed, key = 32 raw `/dev/urandom` bytes** | `"hashline-zk-os-rng/v1/"(22) ‖ domain` | `22+\|d\|`; **64** at `endpoint_g` | prover | public message, **secret key** |
| **R2** | generator **refill** | `rng.rs:54` | `new()`, **XOF → 8,192 B** | `key(32) ‖ le64(counter)(8)` | **40** | prover | **secret — the key** |
| **R3** | generator fixture seed | `rng.rs:21` | `new()` | `"hashline-zk-rng/"(16) ‖ domain ‖ le64(seed)` | `24+\|d\|` | — | public; **off the production path** |
| **K** | tag key derivation ×4 | `zkp-core/src/hashtag.rs:95-98` | **`derive_key`** | contexts of 48/43/48/47 B over the profile string | — | both | public |
| **D1** | calibration identity | `hashline/src/private_block.rs:222` | `new()`, **unkeyed at every rule** | `b"B3 public fixed calibration v1"` | **30** | both | public constant |
| **D2** | block public / weights digest | `private_block.rs:513-514` (literal at `:514`) | `new()`, unkeyed | `b"hashline/private-block-public/1"(31) ‖` length-prefixed weights, `u64`-framed per tensor with shapes fixed by the `Shape` (`:393`, `:473`) | `31+w`, **shape-determined** (B-16) | both | public, **attacker-chosen weight VALUES** |
| **D3** | block schedule digest | `layout.rs:1289-1290` (literal at `:1290`) | `new()`, unkeyed | `b"…-schedule/1"(33) ‖ Σ(le64(len) ‖ line)` | `33+Σ` | both | public |
| **D4** | run public statement | `run.rs:221-222` (literal at `:222`) | `new()`, unkeyed | `b"hashline/private-run-blocks/1"(29) ‖ L×32` | `29+32L` | both | public |
| **D5** | run schedule digest | `run.rs:286-287` (literal at `:287`) | `new()`, unkeyed | `b"…-run-schedule/1"(31) ‖ Σ(le64(len) ‖ line)` | `31+Σ` | both | public |
| **D6** | generalised endpoint spec digest | `endpoint_g.rs:158-159` (`DOMAIN` at `endpoint_g.rs:45`) | `new()`, unkeyed | `DOMAIN(42) ‖ ctx(32) ‖ 8×u64 ‖ i32` | **142** | both | public |
| **D7** | internal boundary spec digest | `boundary.rs:211-212` (`DOMAIN` at **`boundary.rs:58`**) | `new()`, unkeyed | `DOMAIN(43) ‖ ctx(32) ‖ 9×u64 ‖ i32` | **151** | both | public |
| **D8** | frozen-seam spec digest | `private_seam.rs:116-117` (`DOMAIN` at `private_seam.rs:26`) | `new()`, unkeyed | `DOMAIN(28) ‖ ctx(32) ‖ 8×u64 ‖ i32` | **128** | both | public |
| **C1** | capture / sink file digests | `run_capture.rs:325, 803, 1002, 1544…`; `run_sink.rs:29, 49-51`; `export_v3.rs:168-173` | **SHA-256, not BLAKE3** (`sha2`) | file bytes | var | capture | **a different hash function entirely — it shares no oracle with anything above** |
| **G1** | **CUDA column kernel**, whole-column | `hashline/src/gpu/kernels.cu:512` (`b3_hash_column`), launched by `:582` (`k_hash_cols`) | **hand-written unkeyed BLAKE3 on the device** | the column's `rows` words, LE, **no tag, no length prefix** — the same bytes as P1/P2 | `8·rows` × `nn` | prover | **secret** for unopened. **ON THE PATH at the two legacy profiles** — §5.2 |
| **G2** | **CUDA column kernel**, chunk-streamed | `hashline/src/gpu/kernels.cu:1429` (`k_hash_cols_stream`) | **a SECOND hand-written unkeyed BLAKE3**, chunk-streamed with a per-column CV stack | as G1, consumed in row chunks | `8·rows` × `nn` | prover | as G1. **ON THE PATH at the two legacy profiles** — §5.2 |

**Not on the path, checked clean [COUNTED]:** `wire.rs` hashes nothing;
`run_statement_file.rs`, `run_sink.rs` are SHA-256 only; `audit_claims`
(`protocol.rs:230-274`) performs **zero** hash calls — its wrapper
`check_opening` only clones the transcript and squeezes (row T4c);
`private-block-kernel*`, `zkvm-*` contain no call site.

> ~~the CUDA column kernel (`gpu/kernels.cu:447-600`) is a hand-written
> unkeyed BLAKE3, feature-gated and declined by tagged commitments
> (`pcs.rs:782-785`, ruling T-8).~~
>
> **MOVED OUT OF "CHECKED CLEAN" (ruling J-3, the check's B-3, B-12).** Both
> halves of that sentence were true and together they were misleading: the
> **tagged** commitment declines the accelerator, the **legacy** one does
> not, and there are **two** kernels, not one. It is now rows G1 and G2 above
> and §5.2 below. Nothing is deleted; the sentence is struck where it stood.

**In the crate but off this path, and therefore sharing `F_U` at a legacy
profile [COUNTED]:** the two 40-byte `Transcript::new` constructors
(`private_seam.rs:26` with `b"experimental-private-seam/v1"`,
`public_block_receipt.rs:20` with `b"zk60-public-block-receipt-v1"`, both
`12+28 = 40`), the private-attention profile's constructor (55), and
`stable_weight_*`, `wcache`, `pcs_compact`, `attention_schedule`,
`public_chain_receipt` (which holds the tree's **only other** `derive_key`,
`public_chain_receipt.rs:119`).

### 5.1 The lengths, per shape [COMPUTED]

Every number below is `query_classes.py`'s, from the layouts above. The four
shapes the D19 scoping memo tabulated reproduce it exactly; `rung-K4`'s column
lengths are new here (from `a_rows = 727`, `h_rows = 720`).

| | toy | rung | rung-G | rung-K4 | 125M |
|---|---:|---:|---:|---:|---:|
| rule | legacy | legacy | tagged | tagged | tagged |
| transcript constructor (T1/T2) | 51 | 56 | 58 | 59 | 48 |
| column digest `A` | 3,640 | 4,984 | 4,984 | 5,816 | 45,448 |
| column digest `H` | 3,072 | 4,608 | 4,608 | 5,760 | 56,960 |
| column digest `M` | 400 | 400 | 400 | 400 | 400 |
| column digest endpoint | 56 | 168 | 72 | 72 | 296 |
| column digest boundary | — | — | 80 | 80 | 304 |
| **seed derivation, block prover (R1)** | 61 | 66 | 68 | 69 | 58 |
| **seed derivation, endpoint (R1)** | 50 | 50 | **64** | **64** | **64** |
| `pcs-vec` absorb, block | 8,247 | 20,535 | 20,535 | 20,535 | 266,295 |
| `pcs-vec` absorb, endpoint | 8,247 | 8,247 | 20,535 | 20,535 | 266,295 |

Fixed at every shape: squeeze **47**; refill **40**; node and salted leaf
**64**; `rows` absorb 60, `pb-slot` 63, **`log-cols` 64**, `pb-run-stage` 68,
`pb-scalar` 73, root absorbs 81, `schedule` 88, `pb-run-block` 92,
`public-statement` 96, `sc-round` 104/120/136/152, `run-shape` 113,
`expected-IO` 171, `mask-q` 16,438, `mask-prox` 16,441; `pb-term` `55 + 16k`;
calibration 30, seam spec 128, endpoint spec 142, boundary spec 151.

Runs: constructor 56 (rung-G `L=3`), 57 (rung-K4 `L=3`), **46** (125M `L=12`);
run public statement `29 + 32L` = 125, 125, **413**.

### 5.2 The accelerator path: two hand-written CUDA kernels, live at exactly the two legacy profiles

**Claim B-1a [COUNTED — the check's B-3 and B-12, ruling J-3].** This section
exists because the draft put the CUDA kernel under "not on the path, checked
clean" and it is on the path, at exactly the profiles whose entire
domain-separation argument is *"there is one unkeyed function"* (§6.1).

**Two kernels, not one**, with the launch sites re-read at `8c5922b`:

| kernel | `file:line` | launched from |
|---|---|---|
| `b3_hash_column` / `k_hash_cols` | `hashline/src/gpu/kernels.cu:512`, `:582` | `hashline/src/gpu/cuda.rs:2741` (in `dev_commit_from`, `:2690`) and `:3597` (in `dev_commit_zk_from`, `:3455`), both through `Gpu::hash_cols` (`cuda.rs:2763`) |
| `k_hash_cols_stream` — a **second** hand-written BLAKE3, chunk-streamed with a per-column chaining-value stack | `hashline/src/gpu/kernels.cu:1429` | `cuda.rs:1741` (in `commit_zk_chunked`, `:1713`), `cuda.rs:2154` (in `commit_chunked`, `:2127`) and `cuda.rs:2242` (in `commit_chunked_upload`, `:2180`) |

> **EDITOR'S NOTE, two citation corrections, both widening.** The check
> attributes `cuda.rs:2154` and `:2242` to `commit_zk_chunked`; at `8c5922b`
> they are in `commit_chunked` (`:2127`) and `commit_chunked_upload`
> (`:2180`), so `k_hash_cols_stream` has **three** launch sites, not one.
> The check names the differential probe `dev_hash_cols_check`; the symbol at
> `8c5922b` is **`dev_hash_check`** (`cuda.rs:2783`), with the device call at
> `:2795`. Neither correction changes the finding.

**The reachability, exactly.** All four conditions must hold, and at the two
legacy profiles they can:

1. **Build.** `--features gpu-cuda`, **off by default**
   (`hashline/Cargo.toml:15` `[features]`, `:25` `gpu-cuda = ["dep:cudarc"]`;
   the comment at `:20-24` records that the CPU build never sees `cudarc`).
2. **Run time.** `HL_GPU=1`. `hashline/src/pcs.rs:61` and `:74` pass
   `&backend()`, which reads the environment — an **environment branch on the
   production path**. It changes the store and the hasher implementation; by
   A-4 it never moves a generator byte.
3. **Rule.** The tagged entry point declines the device, the legacy one does
   not. `commit_zk_owned_with_tag` reads
   ```rust
   let dev = match tag.column_key() {           // zkp-core/src/pcs.rs:782
       None    => backend.try_commit_zk(...),   // :783  — OFFERED
       Some(_) => None,                         // :784  — declined
   };
   ```
   and `tag.column_key()` is `None` **exactly when**
   `Shape::hashes_under_the_legacy_rule()` (`shape.rs:549-551`:
   `self.is_frozen_toy() || self.profile == FROZEN_SEAM_RUNG_PROFILE`) — the
   frozen toy and the frozen-seam rung. Separately,
   **`commit_zk_owned_with` (`zkp-core/src/pcs.rs:728`) has NO tag gate at
   all**: it calls `backend.try_commit_zk(...)` unconditionally, and
   `private_seam::prepare` reaches it through `commit_zk_owned`
   (`private_seam.rs:215`).
4. **What is sent.** At those profiles the column hashing of `A`
   (`protocol.rs:662`), `H` (`protocol.rs:770`) and every endpoint /
   boundary commitment is offered to the device, and the **blinding rows and
   pads travel to device memory and pinned host memory** with them.

**Why this belongs in Part B and not only in the build notes.** Part B's
claim is an *enumeration of the oracle points the system queries*. A second
implementation of the same function **is not a new oracle point when it
agrees**; it is one when it does not. Under `HL_GPU=1` at the toy, the column
digests of `A`, `H` and both endpoints are produced by hand-written CUDA.

**What pins the agreement — and what does not.** The differential probe
`dev_hash_check` (`cuda.rs:2783`, device call at `:2795`) and the proof-byte
parity gates (the `PROOF sha256` comparison). **Not** the hash-domain
argument: no length, literal, mode or key separates G1/G2 from P1/P2, because
they are meant to compute the same function on the same bytes. The honest row
is: *"reachable at the two legacy profiles under a build flag and an
environment variable; agreement with `pcs.rs:171` is pinned by a parity gate,
not by the domain argument."*

**Buffer lifetimes: unread.** Nobody has read, for this profile, how long the
blinding rows and pads live in device memory and in pinned host memory, or
when they are zeroised. The integrator's new buffer pool and these kernels
are the **same question**, and it has been put to the integrator.

**The evidence of record is CPU-only.** The accepted toy statement's four
captures and its gates were produced with every `HL_*` variable removed: the
capture runner strips them (`scripts/zk60_native_capture.py:183`,
`env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}`;
likewise `scripts/zk60_p1_demo.py:58-59`, which records
`"removed_env_prefix": "HL_"` in its own output at `:85`).

> **RULING J-3, recorded here as it is written into the statement's scope.**
> **The accepted toy statement (register entry D22) covers the toy profile on
> the CPU path.** A GPU-feature build with the accelerator enabled is **NOT
> covered** until (i) the two kernels' agreement with `pcs.rs:171` is cited
> to a gate **by name**, and (ii) the device and pinned-host buffer lifetimes
> are read for this profile. This narrows what D22 may be read to cover; it
> does not weaken anything D22 asserts, and the security owner wrote it into
> the statement the same hour.

### 5.3 Further hash sites reachable in the same process

**Claim B-1b [COUNTED — the check's B-17, ruling J-7].** These appear in
neither the call-kind table nor the "checked clean" list, and they are
reachable **in the same process** from the named entry points — through
`BlockPublic::synthetic_fixture()` (`hashline/src/private_block.rs:525`,
which is **not** `#[cfg(test)]`; its doc comment runs `:520-524`). Every
line re-read at `8c5922b`:

| `file:line` | function | what |
|---|---|---|
| `hashline/src/private_block_contract.rs:545` | `*blake3::hash(&bytes).as_bytes()` | unkeyed, over a large framed registration buffer |
| `hashline/src/causal_oracle.rs:98` | `*blake3::hash(b"B3 public synthetic signed weights v1")` | unkeyed, a **37-byte** literal [COMPUTED: 37] |
| `hashline/src/causal_oracle.rs:194` | `*blake3::hash(b"B3 public fixed calibration v1")` | unkeyed — the **identical 30-byte preimage as D1** (`private_block.rs:222`), at a second site [COMPUTED: 30] |
| `hashline/src/causal_oracle.rs:590` | `MerkleTree::build(hash_columns(&encoded, rows, 2048))` | a second **call site** of `hash_columns` + `hash_pair`, i.e. of kinds **P2** and **P4** — not a new kind |
| `zkp-core/src/tables.rs:134` | `Sha256::new()` over the spec JSON | **SHA-256** table-spec digest |
| `hashline/src/tables_attn.rs:125` | `Sha256::new()` | **SHA-256** table-spec digest |
| `hashline/src/tables_attn.rs:166` | `Sha256::new()` | **SHA-256** table-spec digest |

> **EDITOR'S NOTE on the count.** Ruling J-7 and the check both say "six
> further hash sites" and both then enumerate **seven** `file:line` entries.
> They reconcile if `causal_oracle.rs:590` is counted as what it is — a
> second call site of kinds already in the table (P2, P4) rather than a new
> kind — leaving **six new sites**: one unkeyed BLAKE3 over a framed buffer,
> two unkeyed BLAKE3 literals, and three SHA-256 table-spec digests. That is
> how they are entered above. Nothing is dropped either way.

**Why it matters, and the narrowing it forces.** Nothing these produce is
absorbed, so they are not in the receipt's hash view. But §7's cross-profile
`F_U` argument is a statement about **one machine**, and under that reading
the set of `F_U` queries is **not closed** without them. Two ways out, and
the page takes both: the sites are listed here, **and** §7's `F_U` argument
is narrowed to what it can actually support. The three SHA-256 sites are
outside `F_U` altogether (a different function, like C1); the three unkeyed
BLAKE3 sites are inside it, and the one at `causal_oracle.rs:194` is an exact
duplicate of D1's query point — a coincidence that is **recorded** (it is the
same public constant, so it reveals nothing) and not guarded.

## 6. The classes, and what separates them

### 6.1 Under the LEGACY rule (the toy, the frozen-seam rung)

**Claim B-2.** There is **one** unkeyed function. T1, T3, T4a/b/c, P1–P5,
R2, R3, D1–D8 and every off-path unkeyed digest are queries to it. The only
separations available are (i) **input length**, (ii) **a fixed literal at a
fixed offset**, and (iii) for R1 only, **BLAKE3's keyed mode under a secret
key** (convention V-2).

`query_classes.py` computes the whole length set per shape. At the toy, 95
input kinds occupy 86 distinct lengths, with ~~**four genuine clashes**~~
**THREE genuine clashes** (two more are one call kind at two geometries):

| length | who shares it | what separates them |
|---|---|---|
| **64** | P3 salted leaf, P4 Merkle node, T3 `absorb "log-cols"` | leaf vs node: **NOTHING** (both `blake3(32‖32)`, untagged) — ruling L-7, 2^-484.83. Against the absorb: the absorb carries `le64(8) ‖ "log-cols" ‖ le64(8)` at a fixed offset. ~~so a coincidence needs a digest to spell 24 fixed bytes — 2^-241.42 as counted~~ **MECHANISM CORRECTED (J-4/B-8):** a digest spelling **24 fixed bytes** is `2^-192` per pair [COMPUTED: `2^-8·24`], not `2^-241.42`. The figure of record, `2^-241.4153`, is `N_overlap · 2^-256 = 24,571 · 2^-256` — the 32-byte **salt** of each of the 24,571 salted-leaf and inner-node objects is uniform and the bound counts one `2^-256` per object [COMPUTED]. The figure is right; the justification beside it was a different and weaker argument |
| **81** | T3 `absorb "A"/"H"/"B"/"M"` | the **label byte**, at a fixed offset. Not a length separation at all |
| ~~**151**~~ | ~~T3 `absorb "pb-term"` with 6 terminals, D7 boundary spec digest~~ | **NOT A TOY CLASH — WITHDRAWN from this table (J-7/B-9.1).** The `pb-term`(6) absorb does exist at the toy (§0 item 3, VERIFIED), but **151 has no partner there**: D7 is the *internal boundary* spec digest, internal boundaries exist only in a run, and runs are tagged. The pair is cross-profile and cross-execution; it is priced in §7, claim B-8, and it is **recorded, not guarded** (ruling J-7). §7 said this in prose while §6.1 counted it anyway; the count is now three |
| **171** | T3 `absorb "expected-IO"`, T3 `absorb "parameters"` | the label bytes |

**A within-family clash this table missed [COMPUTED — the check's B-7,
ruling J-7: RECORDED].** At a **rung-G** or **rung-K4** run with
`2 ≤ L ≤ 9`, two `F_T` queries have the same length in the same execution:

| length | the pair | separated by |
|---|---|---|
| **295** | T3 `absorb "parameters"` carrying the **run's** parameter line (`RunStatement::parameter_line`, `run.rs:234-246`), 237 B at those `L` → `48 + 10 + 237 = 295`; and T3 `absorb "pb-term"` with **15** terminals → `48 + 7 + 240 = 295` | the **label literal and its length prefix at a fixed offset**: `le64(10)‖"parameters"` against `le64(7)‖"pb-term"`. Deterministic, not probabilistic — nothing is broken |

[COMPUTED, both sides re-derived this revision.] **rung-G at `L = 3` is the
configuration the lane runs.** `L = 1` gives 294 and `L ≥ 10` gives 296; at
the 125M run the `parameters` absorb is 300/301/302 and misses every
`pb-term`. It is a clash of exactly the class §6.2's table is meant to
enumerate, and it was not there; it is recorded now.

### 6.2 Under the TAGGED rule (rung-G, rung-K4, 125M, and the runs)

**Claim B-3 [COUNTED].** Five functions, not six (ruling H-3): `F_T`
(transcript key), `F_C` (column key), `F_L` (leaf key), `F_N` (node key), and
`F_U`, still unkeyed, carrying **R2 the refill and every statement digest
D1–D8** — and, per §5.3, the three further unkeyed in-process BLAKE3 sites,
one of which (`causal_oracle.rs:194`) duplicates D1's query point exactly.
Plus R1's keyed function under a secret key, and `derive_key` for K. **G1 and
G2 are not a sixth function**: they are a second *implementation* of `F_C`'s
input under the legacy rule, i.e. of the unkeyed column digest, and the whole
question about them is agreement rather than separation (§5.2).

Inside `F_T` the only genuine clash is the 81-byte root absorbs (the label
byte separates them) — **except at a rung-G / rung-K4 run with `2 ≤ L ≤ 9`,
where `parameters`(run line) and `pb-term`(15) are both 295 bytes, separated
by their label literals at a fixed offset (§6.1, the check's B-7)**. Inside
`F_C`, `F_L`, `F_N`, `F_U` there is none.

**The cross-family coincidences are the interesting rows**, because a length
argument says nothing about them and a *mode* argument has to. At rung-G,
rung-K4, 125M and all three runs [COMPUTED]:

| length | the pair | separated by |
|---|---|---|
| 64 | P3 leaf (`F_L`) vs P4 node (`F_N`) | **the two keys** — D19a's family reading, whose honest justification is proposed **D19b** (ideal compression function at an adversary-chosen chaining value). Under the legacy rule: nothing |
| 64 | T3 `absorb "log-cols"` (`F_T`) vs P3/P4 | the keys |
| **64** | **R1 seed derivation at the generalised endpoint** (keyed, secret OS key) **vs P3 leaf and P4 node** | **BLAKE3's keyed mode and a key the adversary does not know — convention V-2, and nothing else.** This is the check's B-2(a), and it is the sharpest row in the table: by length it is in the leaf/node class, twice per block, on the production path |
| 68 | T3 `absorb "pb-run-stage"` (`F_T`) vs R1 seed derivation at the rung-G block prover | the keys — **but the row is CROSS-EXECUTION (J-7/B-9.2)**: `pb-run-stage` is absorbed only in a run (`run.rs:494`), and **in a run the block prover makes no generator** — `prove_run` makes one for the whole run (`run.rs:475`) under the **run** profile, whose domain is 44 B at rung-G, giving `22 + 44 = 66`, not 68; at rung-K4 the run seed is `22 + 45 = 67` against the same 68 [COMPUTED]. So the pair carries the **same caveat as 151**: it is never live inside one execution |
| 151 | T3 `absorb "pb-term"(6)` (`F_T`) vs D7 boundary digest (`F_U`) | the transcript key vs unkeyed. **Cross-profile and cross-execution** (§7, B-8); the six-terminal absorb is now **VERIFIED** at every shape |
| **8·rows** | **G1 / G2, the two CUDA column kernels, vs P1/P2 the CPU column digests** | **NOTHING — they are meant to be the same function on the same bytes** (§5.2). At a tagged profile the device is declined (`pcs.rs:782-785`), so the row is **legacy-only**; there, what pins agreement is a differential probe (`cuda.rs:2783`, device call `:2795`) and the proof-byte parity gates, **not** the hash-domain argument |

### 6.2a The partition into classes, with the separating feature per pair

**Claim B-4 [COUNTED].** Six classes, not two. A pairwise matrix over 24 rows
is unreadable; this is the partition, and every pair of classes has one named
separating feature.

| class | members | what it is |
|---|---|---|
| **X_T** | T1/T2, T3, T4a, T4b, T4c | the challenge chain and the prover's own replays of it |
| **X_C** | P1, P2, P5 | column digests |
| **X_L** | P3 | salted leaves |
| **X_N** | P4 | Merkle inner nodes |
| **X_G** | R2 (refill), R1 (seed derivation) | the generator |
| **X_D** | D1–D8, R3, K | public digests, fixtures, key derivation |
| **X_C (device)** | **G1, G2** | the same column digests, computed by hand-written CUDA at the two legacy profiles (§5.2). Members of X_C by input, not a seventh class |

| pair | separated, under the legacy rule, by | under a tag, by |
|---|---|---|
| X_T / X_C | length: no `8·rows` on a registered path meets a transcript length (the completed guard) | the transcript key vs the column key |
| X_T / X_L, X_T / X_N | length, **except `absorb "log-cols"` at 64** → a fixed 24-byte literal. ~~2^-241.42~~ **CORRECTED (J-4/B-8): the 24-byte literal is worth `2^-192`; the `2^-241.42` of record is `24,571 · 2^-256`, the uniform 32-byte salt counted once per overlapping object** (A-16, §6.1) | the keys |
| **G1, G2 / P1, P2** | **nothing — by design.** Two implementations of one function; the question is agreement, pinned by the differential probe `dev_hash_check` (`cuda.rs:2783`, `:2795`) and the proof-byte parity gates, **not** by the hash-domain argument (§5.2) | the device is declined (`pcs.rs:782-785`), so the pair does not arise |
| X_T / X_G | length: 40 and `22+\|d\|` against the transcript set; the constructor margin is **1 byte** at the 125M run profile | the keys (refill stays unkeyed: length again) |
| X_T / X_D | length, **except `pb-term(6)` = 151 = the boundary digest** → a fixed 43-byte literal, 2^-256. **Cross-profile and cross-execution; RECORDED, not guarded (J-7)** | the transcript key vs unkeyed |
| **X_T / X_T (within)** | **`parameters`(run line) = `pb-term`(15) = 295 at a rung-G / rung-K4 run with `2 ≤ L ≤ 9`** → the label literal and its length prefix at a fixed offset. Deterministic. **NEW (J-7/B-7), recorded** | unchanged — both are `F_T` under a tag too |
| X_C / X_L, X_C / X_N | length: no commitment has 8 rows (the guard refuses it) | the keys |
| **X_L / X_N** | **NOTHING** — 2^-484.83 | the two keys, under D19b |
| X_L / X_N / X_G | **`22+42 = 64` at the generalised endpoint**: the seed derivation is leaf/node-length. Separated by **mode and a secret key only** (V-2) | the same — the tag does not touch it |
| X_C / X_D | length, **except `rows = 16` → 128 = the seam digest**, refused by nothing. **NARROWED (J-7/B-9.3): 128 B is the FROZEN-SEAM spec digest (`private_seam.rs:116-117`), the frozen seam exists only at the two legacy profiles, and their geometries are frozen — so the correct statement is "dangerous at a legacy profile, which today means a frozen geometry", not "dangerous at every shape". Ruling J-7 keeps W-4 anyway: the legacy guard gains it, cheap and right** | the column key vs unkeyed — at a tagged profile a column digest is `F_C` and the digest `F_U`, so the length means nothing |
| X_G / X_D | length (40 against 30/128/142/151/`29+32L`/schedules); `29+32L ≠ 40` proved | unchanged |
| anything / C1 | a different hash function (SHA-256) | unchanged |

### 6.2b Every absorbed word is public — the hypothesis K-R4 asks to be
### matched to the code

**Claim B-5 [COUNTED].** The check's B-7 made "every word the transcript
absorbs is public" a numbered hypothesis of the lemma, and K-R4 asks for it to
be matched to the code with the lines. It holds **by construction**, and the
construction is one sentence: *the verifier recomputes every absorb from the
receipt.* The verifier's absorb sequence is the prover's, site for site —
`protocol.rs:860, 861, 862-864, 868` against the prover's `:666, 676,
682-684, 774`; `sumcheck.rs:154` against `:109`; `argument.rs:378` against
`:347`; `run.rs:640, 641, 645` against `:494, 495, 505`; the masked extension
round `zk.rs:1099` on both sides; `pcs::verify_zk` `:1090, 1095` and
`verify_zk_tagged` `:1212, 1217` against `open_zk` `:1033, 1035`;
`zk::mask_verify` `:613, 616` (legacy) and `:657, 660` (tagged) against
`mask_open` `:584, 593`. A word the verifier
could not recompute would fail the receipt, and the lane pins the agreement
with `honest_receipt_verifies_in_typed_and_wire_form_with_the_declared_
transcript_order` (`tests.rs:92-95`). **So the hypothesis is not an
assumption here; it is a consequence of the protocol being publicly
verifiable, and the pin exists.** It is the only hypothesis of the lemma in
that happy position.

The one thing it does *not* cover: an absorb of a value that is public but
**attacker-chosen**. There is exactly one, D2 (the block's weights digest),
and it is the row §9 marks to watch.

### 6.3 The hypothesis's form is wrong, and the repair

**Claim B-6 [COUNTED + ARGUED] — the prover DOES query the transcript class.**
The kernel draft's §1.3 partitions the oracle's inputs into a transcript class
`T` and a prover class `P`, sets `ξ := O|_T`, and says a random oracle's
restrictions to disjoint sets are independent. That is right about the
*inputs* and wrong about the *queries*: the prover makes `T`-queries, in two
families:

* **the position tag** (T4b) — two squeezes off `clone_state`, which copies
  the state, the counter **and** the key (`transcript.rs:156-162`), so the
  two 47-byte inputs are exactly the two the live chain will query next if no
  absorb intervenes (K-R2 already records this);
* **the refusal replay** (T4c) — `check_opening` clones and draws
  `Σ counts + rows` challenges (`protocol.rs:305-306`,
  `check_opening_challenges` `:282-293`), and then `pcs::open_zk` draws
  *the same* `Σ counts + rows` challenges from the live transcript
  (`zk_rhos`, `pcs.rs:943-964`). **These are not two near-misses; they are the
  same oracle points, queried twice, by design.** No document names this
  family, and it is far larger than the tag's two inputs.

Neither is a leak, and neither breaks the hypothesis — but the hypothesis has
to be restated to be true:

> **(iii-a′)** *Every transcript-class query the prover makes is at a point
> determined by the public prefix* — so the prover learns `ξ` only at points
> the verifier evaluates too, and learns nothing about `ξ` beyond the
> challenges themselves.

**ACCEPTED as the restated hypothesis, WITH CAUSALITY NAMED (ruling J-6, the
check's B-11).** The check confirms the finding in the code: `check_opening`
clones the transcript and draws `Σ counts + rows` challenges
(`protocol.rs:305-306`, `check_opening_challenges` `:282-293`), and
`pcs::open_zk` (`zkp-core/src/pcs.rs:1023-1027`) then calls `zk_rhos` on the
**live** transcript with no absorb in between, drawing `Σ members.len()`
lambdas per group and then `rows` for `prox_rho` — the same count, the same
order, the same `(state, counter)` pairs. *Literally the same oracle points.*

For hypothesis (iii) — *the challenge source is independent of the prover's
internal randomness and of the witness* — (iii-a′) is **enough**: `ξ = O|_T`
is exogenous whether or not the prover reads it, and reading it at
prefix-determined points cannot make `ξ` depend on `ω` or on `w`.

**For causality it is not enough by itself, and the page must say so, so the
hypothesis is written with the refusal flag inside it.** The lemma's
causality hypothesis is that message `j` is a function of `ρ_{<j}`. The
refusal replay squeezes `ρ_j` **before** the prover commits to message `j`,
and then *decides whether message `j` exists at all* — a dependence of the
prover's behaviour on `ρ_j`. Written so that the flag appears:

> **(iii-a″) — (iii-a′) with causality named.** *Every transcript-class query
> the prover makes is at a point determined by the public prefix; and the
> only way a squeezed challenge `ρ_j` influences the prover before message
> `j` is through the **refusal flag** `NR_j(ρ_{≤j}) ∈ {continue, refuse}`
> computed by `check_opening_challenges` (`protocol.rs:282-293`,
> `:305-306`), which is a deterministic function of `ρ_{≤j}` and public data
> alone — of no witness and of no `ω`. At fixed `ρ` the decision is
> therefore public, and under D21 / rule M-9 (accepted receipts only) a
> refused attempt is outside the probability space; the lemma's own abort
> handling covers what remains.*

Ruling J-6: **this is not a hole** — the lemma handles aborts — but it is an
argument the page owes rather than a consequence of (iii-a′), and the flag is
now in the hypothesis's statement so that nobody reads (iii-a′) as covering
causality on its own.

Two smaller things in the same area, both in this page's favour and both
recorded for completeness (the check's B-11):

* the **position tag** is safe for a reason this page did not give: the live
  chain's next operation after `start_tag` is an *absorb* (`run.rs:492-494`),
  so the tag's two squeeze points are never queried live. `end_tag(k)`
  (`run.rs:551`) and `start_tag(k+1)` (`run.rs:492`) are, however, the
  identical pair of oracle points, published twice.
* `check_opening_challenges` short-circuits (`.any()`), so on the **refusal**
  branch it draws fewer than `Σ counts + rows`. Irrelevant to an accepted
  receipt, but it means the replay's query count is not a shape constant off
  the accepted path — one more reason the sentence cannot be quoted without
  M-9.

Consequences. (1) Any count of **distinct** queries — `ε_hit`, the collision
rows, the former `B_sep` — must not double-count them, and must not assume
the prover makes none. (2) The clean statement "the classes are disjoint" is
false as a statement about the prover's behaviour and true as a statement
about the oracle's input sets; the two were being used interchangeably.

## 7. Every pair separated by nothing structural, priced

**Claim B-7 [COUNTED].** Exactly one pair on the production path is separated
by nothing at all, at any rule:

> **P3 salted leaf and P4 Merkle inner node**, both `blake3(32 ‖ 32)`, 64
> untagged bytes, `pcs.rs:678` and `merkle.rs:15`. Under the **legacy rule**
> (the toy, the frozen-seam rung) they are literally the same function on the
> same input shape. Price for hiding: **2^-484.83** (ruling L-7 / correction
> C-4). Price for **soundness**: not a probability — the depth-confusion
> ambiguity, which the wire format and ruling T-4's path-length check close
> (`hash_domain.rs:379-390`, `:427-438`), not the hash. Under a tag the two
> keys separate them, at the cost of assumption **D19b**.

**Claim B-8 [COMPUTED] — NEW: the 151-byte pair.** `absorb "pb-term"` with
six terminals is `48 + 7 + 96 = 151` bytes; the internal-boundary spec digest
(`boundary.rs:211`) is 151 bytes and is **unkeyed at every rule**. At a tagged
profile the absorb is in `F_T` and the digest in `F_U`, so the key separates
them. But a legacy profile's absorb is in `F_U` too, and a legacy profile has
no boundary — so the live pair is **cross-profile**: a legacy toy proof's
`pb-term(6)` absorb and a tagged run's boundary digest are queries to the same
unkeyed function, on one machine. The separation is probabilistic: the digest
begins with a 43-byte ASCII `DOMAIN`, the absorb with a 32-byte transcript
state, so a coincidence needs a state to equal that literal's first 32 bytes —
`2^-256` per absorb, the same shape and the same price as finding F-2's
constructor-versus-squeeze margin. ~~**[UNVERIFIED]** whether any slot's
`pb-term` really carries six terminals: the range `1..56` used here is an
over-approximation from the toy memo; `hash_domain.rs:172-182` builds the
exact per-slot set. Work-list item **W-6**.~~

> **[VERIFIED], and disposed of as RECORDED, NOT GUARDED (the check's B-6,
> ruling J-7).** `Shape::slot_terms()` (`shape.rs:742-749`) is
> `a_sites[s] + h_sites[s] + (s ≥ SC_IO_IN)`; at slot **19 = `SC_TAB`**,
> `a[SC_TAB] = 3` and `h[SC_TAB] = 3` (`shape.rs:733-734`), and
> `SC_TAB = 19 < SC_IO_IN = 21` (`layout.rs:817, :819`), so
> `slot_terms[19] = 6` at **every** shape [COUNTED at `8c5922b`]. The absorb
> is `48 + 7 + 16·6 = 151` bytes, issued once per proof [COMPUTED]. The
> distinct terminal counts and the resulting absorb lengths, per shape
> [COMPUTED by the check, `recheck.py` §5]:
>
> | shape | distinct `slot_terms` | `pb-term` absorb lengths |
> |---|---|---|
> | toy | 1, 2, 3, **6**, 13, 15, 17, 21, 22, 56 | 71, 87, 103, **151**, 263, 295, 327, 391, 407, 951 |
> | rung / rung-G / rung-K4 | 1, 2, 3, **6**, 13, 15, 17, 22, 24, 56 | 71, 87, 103, **151**, 263, 295, 327, 407, 439, 951 |
> | 125M | 1, 2, 3, **6**, 13, 15, 17, 22, 24, 54 | 71, 87, 103, **151**, 263, 295, 327, 407, 439, 919 |
>
> **What the verification changes, and what it does not.** B-8's length is
> real. But the pair is **never live inside one profile**: a legacy profile
> has no internal boundary, so `D7` does not exist there; a tagged profile
> puts the absorb in `F_T` and the digest in `F_U`. The only reading under
> which the pair exists at all is *one global `F_U` across profiles on one
> machine*, at `2^-256` per absorb. Ruling J-7: **record it; do not guard
> it.** W-6 changes from "print and assert" to "print and record" (§8), and
> GAP-QC-4 changes from [UNVERIFIED] to RECORDED (§13).

Also computed and clean: `55 + 16k` is `7 mod 16` for every `k`, and a column
digest is `0` or `8 mod 16`, so **no `pb-term` absorb can ever equal a column
digest**, at any shape [PROVED — re-derived this revision for `k = 0…19`].
And `29 + 32L = 40` has no integer solution, so the run public statement can
never land in the refill class [COMPUTED].

> **The `F_U`-across-profiles reading, narrowed (the check's B-17).** B-8's
> pair only exists under *"one global `F_U` across profiles on one machine"*.
> Under that same reading the `F_U` set is **not closed** by the call-kind
> table alone: §5.3 lists three further unkeyed in-process BLAKE3 sites
> (`private_block_contract.rs:545`, `causal_oracle.rs:98`,
> `causal_oracle.rs:194`) reachable from `BlockPublic::synthetic_fixture()`
> (`private_block.rs:525`, not `#[cfg(test)]`). Either the set includes them
> — it now does — or the `F_U` argument is narrowed to **one proof**, where
> it is closed and where B-8's pair does not arise at all. Both readings are
> now on the page and neither is left implicit.

**Claim B-9 [COMPUTED] — NEW: the dangerous row count in no guard.** A
commitment of **16 rows** hashes a column to 128 bytes (`8 · 16 = 128`), the
length of the frozen-seam spec digest D8 (`28 + 32 + 8·8 + 4 = 128`; both
re-derived). The lane's completed guard (`hash_domain.rs:239-256`, imposed at
`:320-326`) builds its set from the transcript lengths, the squeeze, the
refill and the node — **the statement digests D1–D8 and the seed derivation
R1 were never in it**. ~~So 16 is dangerous at every shape and refused by
nothing.~~ No real commitment is at 16 (toy 455/384/50/7; rung 623/576/50/21;
rung-G and K4 …/9/10; 125M 5681/7120/50/37/38), and the assertion in
`query_classes.py` confirms no real count is on any dangerous value — but the
*set* is incomplete, and the next geometry is the risk, exactly as stage 16's
own finding S16-F1 said about a different half of the set.

> **NARROWED (the check's B-9.3, ruling J-7).** "Dangerous at every shape" is
> **half right**. 128 bytes is the **frozen-seam** spec digest
> (`private_seam.rs:116-117`), and the frozen seam exists only at the two
> **legacy** profiles — whose geometries are frozen. At a tagged profile a
> column digest is `F_C` and the spec digest `F_U`, so the length means
> nothing, as §6.2a's own row says. The correct statement is **"dangerous at
> a legacy profile, which today means a frozen geometry"**, and the item is a
> hygiene item, not a hazard.
>
> **The ruling keeps the work anyway: W-4 stands** — the legacy guard gains
> the statement-digest lengths and the seed-derivation input, *cheap and
> right*. GAP-QC-3 is marked NARROWED, not withdrawn (§13).

**The 47-byte margin, recomputed** [COMPUTED]: the dangerous domain length is
35 (`12 + 35 = 47`). Measured over all seven registered profiles plus the toy,
the nearest is the **125M run profile at 34 — one byte away**, which is ruling
**H-8**'s margin and is watched by no test today.

**The other one-byte margins, listed [COMPUTED — the check's B-15, ruling
J-7].** H-8's margin is not rare here; it is one instance of a class, and
naming the class is the point. Every margin below was re-derived this
revision from the layouts of §5 and the length table of §5.1:

| the pair, one byte apart | sizes | where |
|---|---|---|
| `pb-slot` absorb vs `log-cols` absorb | `48+7+8 = 63` vs `48+8+8 = 64` | every profile |
| `pb-term`(1) vs the rung-G / rung-K4 endpoint column digest | `48+7+16 = 71` vs `8·9 = 72` | rung-G, rung-K4 |
| `pb-term`(2) vs the `schedule` absorb | `48+7+32 = 87` vs `48+8+32 = 88` | every profile |
| `pb-term`(6) vs `sc-round` at degree 5 | **151** vs `48+8+6·16 = 152` | every profile |
| the toy's seam seed derivation (R1) vs the toy transcript constructor | `22+28 = 50` vs `12+39 = 51` | toy |
| the 125M run profile's constructor vs the squeeze — **ruling H-8's** | `12+34 = 46` vs **47** | 125M run |

**None is a clash.** The point is that "one byte away" is common here, so
H-8's margin should be defended as a **class** of test — *no two input kinds
on a registered path are within one byte of each other, per profile,
printed* — rather than as one line about one profile. **W-2 is generalised
accordingly** (§8).

## 8. What pins each separation, and the work list

**Claim B-10.** The "what pins it" column, honestly:

| separation | pinned by |
|---|---|
| 47 is occupied by nothing else, on the path | **nothing**, at the run profile — ruling H-8's one-line test is **owed** (W-2) |
| 40 is occupied by nothing else, on the path | the completed length guard, legacy profiles only (`hash_domain.rs:266-277`, `:320-326`); false crate-wide (ruling L-3) |
| the label table is complete | `every_absorb_label_on_the_path_is_in_the_table` (`hash_domain.rs:98-101`, naming a source-scan test) — **this is a real pin and the best one in the table** |
| the refill still hashes 40 bytes | `hash_domain_tests.rs:35`, a source-text assertion |
| the four tag keys are pairwise distinct | `hashtag.rs:206-220` for rung-G and 125M's eight; rung-K4's four only as a **set** (`hash_tag_tests.rs:96, :109`) — the twelve-key pairwise test is **owed** (ruling H-4) |
| leaf ≠ node under a tag | the two keys; the isolated controls of ruling T-6 |
| leaf ≠ node under the legacy rule | **nothing** — 2^-484.8, and T-4's path-length check for the soundness half |
| the tag travels through a clone | the `clone_state` comment and ruling T-7; a unit test recomputes the legacy transcript by hand (`transcript.rs:231-235`) |
| the position tag's re-issue is harmless | the lane's stage-24 test (per K-R2) |
| **the refusal replay's re-issue** | **nothing — and nobody has named it** (W-3) |
| no commitment is at a dangerous row count | the completed guard, **legacy profiles only**, and its set omits D1–D8 and R1 (W-4) |
| the seed derivation is separated from leaves and nodes | **convention V-2 alone** — no test, and none is possible: it is a model statement (W-5 is a *documentation* item, not a test) |
| the capture writer is a different function | `export_v3.rs:168-173` uses `sha2`; no test asserts it must stay so |
| **the two CUDA kernels compute the same function as `pcs.rs:171`** | **the differential probe `dev_hash_check` (`cuda.rs:2783`, `:2795`) and the proof-byte parity gates — NOT the hash-domain argument, and NOT cited to a gate by name in any statement. Ruling J-3 puts the accelerator configuration outside D22 until it is (W-9)** |
| **the device and pinned-host buffers holding blinding rows and pads are released or zeroised** | **nothing has been read for this profile** (ruling J-3; the same question as the integrator's new buffer pool) (W-10) |
| **no two input kinds on a registered path are within one byte** | **nothing** — there are at least six such margins (§7), of which H-8's is one (W-2, generalised) |
| **the six unkeyed/SHA-256 in-process sites of §5.3 stay out of the receipt's hash view** | **nothing**; they are reached from a non-`#[cfg(test)]` fixture constructor (W-11) |

### The work list for the lane — one line each, no code written here

Revised per rulings J-3, J-5 and J-7. The **"whose file"** column is new: an
item marked *another engineer* cannot be written on this lane and is a
request, not a task.

| # | the test | whose file |
|---|---|---|
| **W-1** | assert that `Fp::from_u128` is a reduction and that `fp()` consumes exactly 16 stream bytes, **named as a privacy-relevant property** (today it is an arithmetic fact nobody guards); the natural home is beside the D9 fixtures | **another engineer** — `zkp-core/src/field.rs`, `zkp-core/src/rng.rs`; the assertion can live on the lane, the property it reads cannot |
| **W-2** | ~~ruling H-8's: no registered profile's `Transcript::new*` input has the squeeze length — equivalently no profile domain is 35 bytes~~ **GENERALISED (J-7/B-15): print, per profile, every input kind's length on the registered path and assert that no two are within one byte** — over every profile the lane registers, runs included. H-8's 34-vs-35 margin is then one row of the printout, and so are the five others in §7 | the lane |
| **W-3** | the refusal replay re-issues exactly the challenge points the live chain draws next, and the live transcript's counter is unchanged by it — on a real block's real openings, extending the stage-24 tag test to the replay family | the lane |
| **W-4** | extend the length-guard set with the statement digests D1–D8 and the seed-derivation input `22+\|domain\|`, so `rows = 16` and the endpoint's 64 are in it; keep the imposition legacy-only. **KEPT by ruling J-7 although B-9.3 narrows the hazard to a frozen legacy geometry: cheap and right** | the lane |
| **W-5** | a table in the register naming, per pair of BLAKE3 functions, the model that separates them (length, literal, mode, key), so D19b's scope is auditable. **Add the G1/G2 row, whose "model" is not a separation at all but an agreement pinned by a differential probe** | the lane (documentation) |
| **W-6** | ~~print the exact per-slot `pb-term` data lengths at every registered shape and **assert** none equals a statement-digest length~~ **CHANGED by ruling J-7: the six-terminal slot is VERIFIED (slot 19 = `SC_TAB`) and the 151-byte pair is never live inside one profile → print and RECORD the per-slot `pb-term` lengths at every registered shape; do NOT guard.** Add the 295-byte within-family row (B-7) to the same printout | the lane |
| **W-7** | the twelve-key pairwise distinctness test of ruling H-4 | the lane |
| **W-8** | **the draw-accounting test of ruling R-3**, ~~assertions 1–5~~ **assertions 1–7 of §3.1** (J-5), two of them about **values** | **split**: 1–4 and 6 need the **consumption accessor in `zkp-core/src/rng.rs`** — **another engineer**, requested of the integrator on **2026-09-21 03:25**; assertions **5 and 7** need no hook and are the lane's today |
| **W-9** | **NEW (J-3).** Cite, **by name**, the gate that pins agreement between the two CUDA kernels (`kernels.cu:512/582`, `:1429`) and `pcs.rs:171`, for the legacy profiles where the device is offered the columns; until that exists, the accelerator configuration is outside D22 | the lane, with the GPU gate scripts |
| **W-10** | **NEW (J-3).** Read and record the lifetime of the device and pinned-host buffers that carry blinding rows and pads on the accelerator path, and when they are released or zeroised | **another engineer** — the integrator's buffer pool and `hashline/src/gpu/cuda.rs` are the same question |
| **W-11** | **NEW (J-7/B-17).** Extend the source-scan that covers absorb *labels* (`every_absorb_label_on_the_path_is_in_the_table`) to hash **call sites**, so the six in-process sites of §5.3 are enumerated by a tool and not by a reading; this is GAP-QC-1's test | the lane |

## 9. Which rows matter for privacy, which only for soundness

**Claim B-11.** The composition lemma's independence hypothesis is about
**prover-side queries against challenge-derivation queries**. Sorting the
table:

* **Privacy-relevant (the hypothesis):** T3, T4a, T4b, T4c (the challenge
  derivation and the prover's own queries into it — claim B-6); P1–P5 and R2
  (the prover's queries that carry a secret: the unopened salts and the
  stream key); R1 (keyed, secret key). These are the rows the hypothesis
  quantifies over.
* **Privacy-irrelevant but hypothesis-relevant:** T1/T2, D1–D8, K, R3 — their
  inputs are public, so the adversary can make those queries itself and they
  are already inside the `q` budget. They matter only because a *coincidence*
  with a secret-carrying input would import a secret query into a public
  class. ~~That is why D2 (attacker-chosen weights) is the one to watch: it
  is the only `F_U` input whose length an adversary moves.~~

  > **CORRECTED (the check's B-16, ruling J-7): no adversary moves any `F_U`
  > length.** The adversary chooses the weight **values**; the serialisation
  > is `u64` length-framed per tensor with the shapes fixed by the `Shape`
  > (`BlockPublic`/`FeedForwardPublic` `absorb_into`,
  > `hashline/src/private_block.rs:393` and `:473`, re-read at `8c5922b`), so
  > D2's **length** is **shape-determined**, exactly like every other input
  > kind on the page. D2 remains the row to watch for a different and
  > weaker reason — it is the one absorb of a value that is public but
  > **attacker-chosen** (§6.2b) — but the sentence "the only `F_U` input
  > whose length an adversary moves" is withdrawn. Caveat, recorded because
  > neither the check nor this editor enumerated the weight serialisation or
  > `describe()`'s line set: if `BlockPublic` were ever to gain a
  > variable-length field, the sentence would come back. That is the hole
  > §12's last bullet and the check's §5 both name.
* **Soundness only:** the leaf/node ambiguity's binding half (ruling L-7 and
  T-4), `verify_zk`'s missing path-length check, transcript-state collisions.
  None of them is in this page's scope and none is reviewed here.

**Claim B-12 — the model behind each separation.**

| separation mechanism | model |
|---|---|
| different input **length**, same function | plain random oracle: restrictions to disjoint input sets are independent random functions. No extra assumption; the residual is the coincidence probability |
| a fixed **literal** at a fixed offset, same function | the same, plus an argument that the other side's bytes at that offset are a hash output: `2^-8·(literal length)`, in practice `2^-256` for a 32-byte state |
| different BLAKE3 **mode** (`hash` / `keyed_hash` / `derive_key`) | BLAKE3's own design claim, convention **V-2**. This is the one the designers' claim really covers |
| same mode, different **public** key (`F_C` vs `F_L` vs `F_N` vs `F_T`) | **proposed D19b**: the compression function is ideal also at an adversary-known, adversary-chosen chaining value. Stronger than D19 as put to the project owner; nothing accepted rests on it |
| same mode, a **secret** key (R1) | convention **V-2** read as an independent oracle indexed by the key; conservative, because the adversary is given the power to query at any key |
| a different hash function (SHA-256, C1) | no shared oracle; nothing to say |

---

## 10. Step table

| # | step | where | label |
|---|---|---|---|
| 1 | `fp()` is modular reduction, 16 bytes, no rejection | A-2 | **COUNTED** |
| 2 | no re-draw or witness-conditioned draw exists on the path | A-3 | **COUNTED** |
| 3 | the eleven-segment schedule, in order, with offsets | A-4, A-5 | **COUNTED** |
| 4 | the totals reproduce D9's 327,052 and H-6's four figures | A-5, A-7 | **COMPUTED** |
| 5 | the position map is a function of the shape alone — and of the public statement — and is **COMPLETE** (two independent enumerations, no twelfth segment, no parallel region, no branch) | A-8 | **ARGUED** from 1–3, **confirmed by the check**; no test — **GAP-JS-1** |
| 5a | a run's schedule is `11L + 3(L−1)` segments; block body `k` starts at `k·block + min(k+1, L−1)·boundary` | A-8 | **COUNTED + COMPUTED** (J-5/B-4) |
| 6 | three generators at a block; one for a whole run plus two | A-6 | **COUNTED** |
| 6a | the three generators' joint independence | A-6, A-11 | **ASSUMED — E-1**, the OS-entropy assumption (J-2); ~~information-theoretic~~ |
| 7 | ~~clause (a) is immediate given M-3 and step 5~~ clause (a) is a **DEFINITION** in the world (JS) is stated in | A-10, §2.0a | **BY CONSTRUCTION** (J-1); the code facts' load moves to step 8a |
| 8 | the stream is uniform | A-10 | **ASSUMED** — M-3, ruling C-3. **Hop 1, booked once** |
| 8a | **hop order: hop 1 (M-3 / `ε_gen(q)`) THEN hop 2 (the sampler, `N·2^-96`); `O ⟂ ω` is the content of hop 1, not a premise** (`rng.rs:54` is an unkeyed query in the distinguisher's own function) | §2.0, §2.0a, A-14 | **RULED — J-1**; the order is part of the statement |
| 8b | conditioning on `NR(ρ)` inflates the hops by `1/(1 − 2^-112) < 1 + 2^-111` | §2.0a | **COMPUTED** (B-1b) |
| 9 | `Pr[rej] = 2^-64` ≠ `TV = 2^-96`, and `2^-64` is optimal for an exactly-uniform good event | A-12, A-13 | **PROVED + COMPUTED**; reproduced independently by the check |
| 10 | the sampler is a distance hop before the lemma; data processing licenses it under any schedule — **inside the post-hop-1 world** | A-14 | **PROVED** there; agrees with ruling K-R4a; premise corrected per J-1 |
| 11 | clause (b): publishing `ρ`-selected salts adds nothing to `V` | A-15 | **ARGUED** from the code; rider 1 not machine-checked |
| 12 | clause (c): Lemma H's conditional kernel, **with `+ ε_gen(q)` restored** | A-16 | **RELIES ON** `ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2 (J-4/B-13) |
| 13 | clause (c′): unopened salts uniform given the opened ones | A-16, §2.4 | ~~**GAP, now stated**~~ → **NOT NEW, NOT OWED, NOT CIRCULAR** (J-6/B-5); a definition in the post-hop-1 world plus documentation. **GAP-JS-2 WITHDRAWN** |
| 14 | clause (d): the flag is `B_salt ∪ B_logup`, union over both worlds | A-17 | **PROVED** given K-R1 and K-R4a |
| 14a | the flag's price is the hash-layer lemma's **own five-term formula plus `ε_gen(q)`**, not its largest term; `q·2^-242.415` overtakes `2^-229.830` from `q = 6,144` | A-16, A-17 | **COMPUTED** (J-4/B-2); no total moves |
| 14b | the mechanism for `2^-241.42` is the uniform 32-byte salt over 24,571 objects, **not** "a digest spells 24 fixed bytes" (which is `2^-192`) | A-17, §6.1, §6.2a | **COMPUTED** (J-4/B-8) |
| 15 | counterexample (i) excluded by disjoint positions | A-18 | **COMPUTED**; the excluding clause is a code theorem, **untested** |
| 16 | counterexample (ii) excluded by M-3 for an accident, by the position map for a broken discipline | A-19 | **COMPUTED**; the excluding clause is a code theorem, **untested** |
| 17 | what the owed draw-accounting test must assert — **SEVEN assertions, two of them about values** — and that five of them need an `rng.rs` hook | §3.1 | **ARGUED**; extended by J-5 |
| 18 | ζ and `mu_pad` come from the transcript, not the generator | A-20 | **COUNTED** |
| 19 | a run carries one generator; the per-stage offsets are deterministic | A-21 | **COUNTED** |
| 20 | ~~24~~ **26** call kinds, with mode, key, layout, length | B-1, §5.2 | **COUNTED**; extended by J-3/J-7 |
| 20a | two hand-written CUDA BLAKE3 kernels are **on the path at the two legacy profiles** under `--features gpu-cuda` and `HL_GPU=1`; agreement is pinned by a differential probe and the parity gates, not the domain argument | §5.2 | **COUNTED**; **D22 narrowed to the CPU path (J-3)** |
| 20b | six further in-process hash sites (three unkeyed BLAKE3, three SHA-256) reachable from a non-`#[cfg(test)]` fixture constructor | §5.3 | **COUNTED** (J-7/B-17) |
| 21 | the legacy-rule clashes: ~~64, 81, 151, 171~~ **64, 81, 171 — three, not four** (151 has no partner at the toy) | B-2, §6.1 | **COMPUTED** (J-7/B-9.1) |
| 21a | a within-family clash at 295 B (`parameters`(run) vs `pb-term`(15)) at a rung-G / rung-K4 run with `2 ≤ L ≤ 9`; separated by the label literal | §6.1 | **COMPUTED** (J-7/B-7), **recorded** |
| 22 | the tagged-rule families and the five cross-family coincidences; the 68-byte row is **cross-execution**, like 151 | B-3 | **COMPUTED**; corrected by J-7/B-9.2 |
| 22a | the six-class partition with a separating feature per pair | B-4 | **COUNTED + COMPUTED** |
| 22b | every absorbed word is public, because the verifier recomputes it | B-5 | **PROVED** (a code fact, and pinned) |
| 23 | the prover queries the transcript class; the hypothesis restated as **(iii-a″)**, with the refusal flag named in it | B-6, §6.3 | **COUNTED + ARGUED**; causality named per J-6 |
| 24 | leaf vs node is the only pair separated by nothing **at the profile level**; at the two legacy profiles the CUDA kernels add an agreement question of a different kind | B-7, §5.2 | **COUNTED** |
| 25 | the 151-byte `pb-term`/boundary-digest pair | B-8 | **COMPUTED**; the six-terminal slot is ~~UNVERIFIED~~ **VERIFIED** (slot 19 = `SC_TAB`), and the pair is **RECORDED, not guarded** (J-7) |
| 26 | `rows = 16` is dangerous ~~at every shape~~ **at a legacy profile, which today means a frozen geometry**, and in no guard; W-4 kept anyway | B-9 | **COMPUTED**; **NARROWED** (J-7/B-9.3) |
| 26a | at least six one-byte margins between input kinds, of which H-8's is one; the test should be a class, not a line | §7 | **COMPUTED** (J-7/B-15) |
| 26b | D2's length is **shape-determined**; no adversary moves any `F_U` length | §9 | **COUNTED** (J-7/B-16) |
| 27 | the pin table and the ~~eight~~ **eleven**-item work list, with whose file each needs | B-10, §8 | **COUNTED** (what exists) + **ARGUED** (what is owed) |
| 28 | seven citations landed one line early (on `blake3::Hasher::new()` rather than the literal); every **length** derived from them is nonetheless correct | §14 | **COUNTED**; fixed, per J-7/B-14 |

## 11. What is still owed before this is used in a statement

**This section replaces "What the checker should attack first".** The check
happened; §11's six invitations were taken up, and what they returned is
recorded below, each with its disposition. What follows them is the
disposition's own list of what is owed — this page is not usable in a
statement until that list is empty.

### 11.1 The six invitations, and what came back

1. **The hop order, hardest.** ~~Is the whole experiment really a
   deterministic function of `(ω, O)`?~~ **ANSWERED, and the page was
   wrong.** The experiment is such a function, but the draft's *second*
   premise — `O ⟂ ω` — is false: the refill is an unkeyed BLAKE3 query
   (`rng.rs:54`) in the very function the distinguisher queries. There are
   **two** hops, in a fixed order (§2.0, §2.0a, ruling J-1). This was the one
   place an argument of record did not hold as written.
2. **Clause (c′), the within-segment conditioning.** **ANSWERED: covered.**
   Both Lemma H and (JS) live in the fixed-challenge experiment, so the loop
   is not entered here; it is entered in the Fiat–Shamir lift, §3 of the
   hash-layer memo, which this page does not touch and which already owes it.
   (c′) is not new, not owed and not circular (§2.4, ruling J-6);
   **GAP-JS-2 WITHDRAWN**. The lift question itself **remains open and is
   item 2 of §11.2** — it is the circularity this project has already refused
   one argument for, and withdrawing GAP-JS-2 does not withdraw it.
3. **Claim A-8, the position map. Find a twelfth draw.** **ANSWERED: there
   is none.** Two independent enumerations agree; no draw in a parallel
   region; no draw behind a witness, challenge, refusal, feature or
   environment branch; the run's schedule is `11L + 3(L−1)` segments. The
   position map is **COMPLETE** as a reading. What is incomplete is the
   **test** it specifies — five assertions became seven (§3.1, ruling J-5).
4. **Claim B-6, causality.** **ANSWERED: (iii-a′) is right for hypothesis
   (iii) and silent on causality.** Restated as **(iii-a″)** with the refusal
   flag inside it (§6.3, ruling J-6). Not a hole — the lemma handles aborts —
   but an argument the page owed.
5. **Claim B-1's completeness. Find the twenty-fifth.** **ANSWERED: the
   twenty-fifth and the twenty-sixth**, two hand-written CUDA BLAKE3 kernels,
   live at exactly the two legacy profiles (§5.2, ruling J-3) — plus six
   further in-process hash sites (§5.3). The candidate this page named,
   *"anything the GPU feature gate reaches"*, was the right one and this page
   had put it in the clean list. The `masker` path
   (`transcript.rs:84-85`) and `run_capture`'s header rebuild
   (`run_capture.rs:265-279`) remain unchased.
6. **Claim B-8's [UNVERIFIED].** **ANSWERED: VERIFIED** — slot 19 = `SC_TAB`
   carries six terminals at every shape (§0 item 3, §7). Disposed of as
   **RECORDED, not guarded**.

### 11.2 Owed before any of this is used in a statement

From the disposition's §3. The composition step, after tonight, rests on:

```
real prover → (generator assumption C-3/M-3, or ε_gen(q)) → uniform stream
            → (N · 2^-96, decision D9)                    → uniform blinding
            → the joint sentence (this page, with changes)
            → the composition lemma (proved, with changes)
            → the adaptive view
```

and the following are **owed**:

1. **The complete query-class table *as revised here*, with a test behind
   each row.** §8's pin table names what pins each separation today; eight of
   them are pinned by nothing, and W-1 … W-11 is the list.
2. **The draw-accounting test (ruling J-5)** — seven assertions, five of
   which need the integrator's consumption accessor, requested 2026-09-21
   03:25. Until it lands, GAP-JS-1 is open.
3. **The errata** — this pass.
4. **(J-3) The accelerator configuration**, if it is ever to be inside a
   statement: the two kernels' agreement cited to a gate by name (W-9) and
   the device / pinned-host buffer lifetimes read (W-10).
5. **The Fiat–Shamir lift's version of clause (c′)** (§11.1 item 2), which
   this page does not touch and the hash-layer memo's §3 already owes.

**The toy's accepted step 5 does not move.** It rests on the random-oracle
hybrid, and nothing on this page weakens that route. What ruling J-3 changes
is the *scope* of what D22 may be read to cover (the CPU path), not the
strength of what it asserts.

## 12. What this is not

* **Not a privacy acceptance.** Nothing here establishes a privacy property of
  the toy block, a shaped block, a run, or any artifact. D22 is untouched and
  does not rest on this page. **This revision is not one either**: the
  independent check and the security owner's disposition establish no privacy
  property of anything.
* **Not a widening of D22 — a NARROWING of its scope.** Ruling **J-3** records
  that the accepted toy statement covers the **CPU path**. A `gpu-cuda` build
  with `HL_GPU=1` is outside it until W-9 and W-10 are done (§5.2). Nothing
  D22 asserts is weakened; what it may be read to cover is smaller.
* **Not a proof that the joint sentence is true.** It is a *statement* of the
  sentence with its clauses separated, in a world reached from the real
  prover by **two hops in a fixed order** — clause (a) and clause (c′) being
  definitions in that world, and the first hop resting on M-3, the assumption
  the project has already named as its weakest, together with **E-1**.
* **Not a verification of the code.** Every code claim is a reading at
  `8c5922b`. No Rust was compiled, no test run, no proof produced.
* **Not soundness.** §9 says which rows are soundness rows and leaves them.
* **Not a review of Lemma H**, which is relied on in clause (c) as the
  security owner's disposition left it.
* **Not complete on `rung-K4`**: its `parameters` line was not read, so that
  shape's length set is missing one entry. *Partly supplied by the check:*
  at a rung-G or rung-K4 **run** with `2 ≤ L ≤ 9` the run's parameter line
  (`RunStatement::parameter_line`, `run.rs:234-246`) is **237 bytes**, giving
  a 295-byte absorb that collides within `F_T` with `pb-term`(15) (§6.1).
  The **block** `parameters` line at rung-K4 is still unread.
* **Not complete on the statement digests' lengths.** `D2`, `D3` and `D5`
  (`31+w`, `33+Σ`, `31+Σ`) are absent from every length set here and from the
  check's: neither agent enumerated the weight serialisation or the
  `describe()` line set. **GAP-QC-7**, and the check is right that it is the
  largest hole in Part B's length argument.

## 13. Gaps, by name

Names are stable. A gap that the check settled is marked **WITHDRAWN**,
**NARROWED** or **RECORDED** in place and is not deleted.

| name | status after the check | what |
|---|---|---|
| **GAP-JS-1** | **OPEN, and now completely specified** | The position map's disjointness and witness-independence (A-8) is a reading — **complete** as a reading, confirmed by two independent enumerations — pinned by **no test at any shape**. It is the clause that excludes both counterexamples. §3.1 says what the test must assert: **seven** assertions, not five (ruling J-5). Five of them need a consumption accessor in `zkp-core/src/rng.rs`, which is another engineer's file; the accessor was requested of the integrator on 2026-09-21 03:25. Assertions 5 and 7 need no hook. |
| **GAP-JS-2** | **WITHDRAWN** (ruling J-6, the check's B-5) | ~~Clause (c′) … is not proved anywhere, and Lemma H does not state it.~~ Withdrawn with reason: (c′) is **not new** (Lemma H already conditions on `S_pub = s`), **not owed** (what K-R3 owes is the joint sentence, delivered by §2.0's two-hop ordering) and **not circular** (both statements live in the fixed-challenge experiment). In the post-hop-1 world it is a **definition**; what remains of it is documentation, and its residual is already priced as `+ ε_gen(q)` in Lemma H's own bound. Kept as a remark in §2.4. |
| **GAP-JS-3** | **OPEN, and now two assumptions, not one** | M-3, in ruling C-3's two-sided whole-stream form, is the only argument for salt/blinding independence within one stream, and a run stretches it across 47 commitments and eleven stage boundaries. **E-1** (ruling J-2) is the only argument *between* the three generators. Unchanged in kind; worse in degree; and the complement of M-3 is not free. |
| **GAP-JS-4** | **NEW, OPEN** (ruling J-1) | The hop **order** is part of the statement and is pinned by nothing but this page: hop 1 (M-3 / `ε_gen(q)`) must precede hop 2 (the sampler). Anyone quoting the sampler's `2^-96` without hop 1 is quoting a statement about a uniform input the prover does not have. |
| **GAP-QC-1** | **OPEN, and worse than stated** | Claim B-1's completeness is a reading, not an enumeration a tool produced — and the reading **missed two call kinds on the path** (§5.2) and six further in-process sites (§5.3). No source-scan test covers hash *call sites* the way `every_absorb_label_on_the_path_is_in_the_table` covers absorb *labels*. W-11. |
| **GAP-QC-2** | **OPEN, widened** | ~~Eight~~ **Eleven or more** separations are pinned by nothing (§8): ruling H-8's margin (and the five other one-byte margins), the refusal-replay re-issue, the incomplete guard set, the twelve-key pairwise test, the four model statements that no test can pin, **the two CUDA kernels' agreement**, **the accelerator's buffer lifetimes**, and **the §5.3 sites' exclusion from the receipt's hash view**. |
| **GAP-QC-3** | **NARROWED** (ruling J-7, the check's B-9.3) | `rows = 16` (128 bytes = the frozen-seam spec digest) is dangerous ~~at every shape~~ **at a legacy profile, which today means a frozen geometry**, and in no guard. No real commitment is there today. **W-4 is kept anyway** — the legacy guard gains it, cheap and right. |
| **GAP-QC-4** | **RECORDED** (ruling J-7, the check's B-6) | ~~[UNVERIFIED] whether a slot's `pb-term` absorb is 151 bytes.~~ **VERIFIED**: slot 19 = `SC_TAB` carries `3 + 3 = 6` terminals at every shape, so the absorb is `48 + 7 + 96 = 151` B. The pair with D7 is **never live inside one profile**, so it is **recorded, not guarded**; W-6 becomes a printout. |
| **GAP-QC-5** | **OPEN, unchanged** | The toy's own step 5 rests on Route A, which this page does not re-examine. Whether Route A's hops implicitly need clause (c′) — the check's own open question 4 — is not answered here. |
| **GAP-QC-6** | **NEW, OPEN** (ruling J-3) | The accelerator path at the two legacy profiles is **outside what D22 covers**: two hand-written CUDA BLAKE3 kernels are offered the column hashing of `A`, `H` and every endpoint / boundary, and nobody has read the device and pinned-host buffer lifetimes for this profile. W-9, W-10. |
| **GAP-QC-7** | **NEW, OPEN** (the check's §5, not among this page's earlier named gaps) | **`D2`, `D3` and `D5`'s input lengths** (`31+w`, `33+Σ`, `31+Σ`) are missing from every length set on this page *and* from the check's. Neither agent enumerated the weight serialisation or the `describe()` line set. **A clash between a statement digest and an absorb at a legacy profile would live here and neither of us would have seen it.** The check calls this the largest hole in Part B's length argument, and it is right; it is recorded now under its own name. |
| **GAP-QC-8** | **NEW, OPEN** (the check's §5) | Whether the refusal classes really read no salt (A-15 rider 1) was taken from this page rather than established: `audit_claims` reads `part.coef.is_zero()`, a **masked** coefficient, and whether that is challenge-driven or witness-driven is unverified by either agent. It is the one refusal to look at again. |

---

## 14. What the check changed

One line per finding of
`ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_CHECK.md`, with the ruling that
disposed of it and the section that carries the change. **"Held"** means the
page was right and nothing moved.

| # | the finding | disposition | where it landed |
|---|---|---|---|
| **B-1** | `O` is **not** independent of `ω` — the generator's refill (`rng.rs:53-61`) is an unkeyed BLAKE3 query in the function the distinguisher queries — and the real prover is reached by **two** hops, not one, whose **order** is load-bearing | **J-1: upheld.** The premise is false; independence is the *content* of hop 1 | §2.0 box (rewritten), **§2.0a (new)**, A-14, step table 8a, §11.1.1, **GAP-JS-4 (new)** |
| **B-1a** | In the world (JS) is stated in, clause (a) is **definitional**, not a theorem; A-10's table books M-3 twice; the position map's real job is to make `ω_ideal` a well-defined product measure | **J-1: upheld** | §2.0 clause (a), §2.0a, A-10's table and conclusion, step table 7 |
| **B-1b** | (JS) is conditioned on `NR(ρ)` and the hop is taken unconditioned; `TV(P\|A, Q\|A) ≤ TV(P,Q)/Pr[A]` is not in the page | **J-1: upheld, nothing moves** | §2.0a, priced: `1/(1 − 2^-112) < 1 + 2^-111` [COMPUTED], step table 8b |
| **B-2** | A-17 under-prices the flag: `2^-229.8` is the largest term of a five-term event, and `q·2^-242.415` — dominant from `q = 6,144` on — was dropped | **J-4: upheld.** All terms restored; no total moves | A-16 (formula + per-term derivation table), **A-17 (re-priced, with the margin table)**, step table 14a |
| **B-3** | Part B is incomplete: a 25th and 26th call kind — two hand-written CUDA BLAKE3 kernels — are on the production path at exactly the two LEGACY profiles | **J-3: upheld, and D22's scope narrowed to the CPU path** | **§5.2 (new)**, rows **G1**/**G2** in §5's table, the "checked clean" list (struck), §6.2, §6.2a, §8's pin table, W-9, W-10, **GAP-QC-6 (new)**, §12 |
| **B-4** | The owed draw-accounting test's five assertions are all about *positions* and cannot exclude the counterexample they are introduced to exclude; two defects pass all five | **J-5: upheld.** Seven assertions, two of them about values | **§3.1 (assertions 6 and 7 added, 2 and 3 widened)**, A-8 (the run's `11L + 3(L−1)` segments and the block-body offset), W-8 |
| **B-5** | Clause (c′) is **not new, not owed and not circular** — Lemma H already conditions on `S_pub`, both statements live in the fixed-challenge experiment, and the residual is already `ε_gen(q)` | **J-6: upheld** | §0 item 4 (re-labelled), **§2.4 (re-labelled)**, step table 13, **GAP-JS-2 WITHDRAWN**, §11.1.2 |
| **B-6** | B-8's `[UNVERIFIED]` is **VERIFIED**: `slot_terms[19] = 6` at every shape (slot 19 = `SC_TAB`, `3 + 3`), so the 151-byte absorb exists — but the pair is never live inside one profile | **J-7: verified; RECORDED, not guarded** | §0 item 3, **§7 claim B-8**, W-6 (changed from "assert" to "print and record"), **GAP-QC-4 → RECORDED** |
| **B-7** | A within-family clash the table missed: **295 bytes** at a rung-G / rung-K4 run with `2 ≤ L ≤ 9` — `parameters`(run line, 237 B) against `pb-term`(15), both `F_T`, same execution | **J-7: recorded.** Separated deterministically by the label literal | **§6.1 (new sub-table)**, §6.2 (B-3's "only genuine clash"), §6.2a (new row), W-6, step table 21a |
| **B-8** | The stated mechanism for `2^-241.42` ("a digest must spell 24 fixed bytes") yields **`2^-192`**; the figure of record is `24,571 × 2^-256` | **J-4: upheld.** The figure is right, the justification was a different and weaker argument | A-16's derivation table, **A-17**, §6.1's 64-byte row, §6.2a's X_T/X_L row, step table 14b |
| **B-9.1** | The toy has **three** legacy clashes, not four: 151 has no partner at the toy | **J-7: upheld** | §6.1 (row struck and explained), step table 21 |
| **B-9.2** | The 68-byte cross-family row is **not reachable within one execution**: in a run the block prover makes no generator; the run seed is 66 (rung-G) or 67 (rung-K4) against 68 | **J-7: upheld** | §6.2's 68-byte row, step table 22 |
| **B-9.3** | `rows = 16` is **not** "dangerous at every shape": 128 B is the frozen-seam spec digest and the frozen seam exists only at the two legacy profiles, whose geometries are frozen | **J-7: NARROWED — and the legacy guard gains it anyway (cheap and right)** | **§7 claim B-9**, §6.2a's X_C/X_D row, **W-4 kept**, **GAP-QC-3 → NARROWED** |
| **B-10** | The three generators' independence is **not information-theoretic**: `/dev/urandom` is a finite-state CSPRNG, so the reads are computationally independent under a second assumption | **J-2: upheld.** Named **E-1**, the OS-entropy assumption; the counts (3, 1,081, 47 of 49) are kept | **A-6 (every `from_os` site cited, E-1 stated)**, **A-11**, A-10's table, A-21 item 2, step table 6a, GAP-JS-3 |
| **B-11** | (iii-a′) repairs hypothesis (iii) but is **silent on causality**: the refusal replay squeezes `ρ_j` before message `j` exists and then decides whether it exists | **J-6: accepted, with causality named; not a hole (the lemma handles aborts)** | **§6.3 — (iii-a″), with the refusal flag inside the hypothesis**; the position tag's real reason and the `.any()` short-circuit recorded; step table 23 |
| **B-12** | A-4's parenthetical is right about the *draws* and must not be read as "the accelerator is never reached"; `HL_GPU` is an environment branch on the production path | **J-3: upheld** | **A-4's correction box**, §5.2 condition 2 |
| **B-13** | A-16 drops `+ ε_gen(q)` from Lemma H's stated bound — the one term Part A is about | **J-4: upheld** | **A-16 (restored)**, step table 12 |
| **B-14** | Seven citations land one line early, on `blake3::Hasher::new()`, with the literal on the next line; the `boundary` `DOMAIN` is at `:58`; there is no `run_parameter_line` symbol; every **length** derived is nonetheless correct | **J-7: upheld** | **§5's rows D2–D8** (`:513-514`, `:1289-1290`, `:221-222`, `:286-287`, `:158-159`, `:211-212`, `:116-117`, plus the two `DOMAIN` lines); §6.1 cites `RunStatement::parameter_line` (`run.rs:234-246`); all eight lengths re-derived here and all eight agree; step table 28 |
| **B-15** | H-8's 1-byte margin is not rare: five more exist at every or some profile; the defence should be a **class** of test | **J-7: upheld.** Listed | **§7's margin table** (63/64, 71/72, 87/88, 151/152, 50/51, 46/47), **W-2 generalised**, step table 26a |
| **B-16** | D2's length is **shape-determined**, not adversary-moved: the serialisation is `u64` length-framed per tensor with shapes fixed by the `Shape` | **J-7: upheld; the sentence withdrawn** | **§9's second bullet**, §5's D2 row, **GAP-QC-7 (new)** for the lengths neither agent enumerated |
| **B-17** | Six further hash sites (four BLAKE3, three SHA-256 by `file:line`) are reachable in the same process from a non-`#[cfg(test)]` fixture constructor and are in neither list; the cross-profile `F_U` argument is therefore not closed | **J-7: upheld.** Added, and the `F_U` argument narrowed | **§5.3 (new)**, §6.2's B-3, §7's narrowing box, W-11, GAP-QC-1 |

**Held, and recorded as held:** A-1 … A-5, A-7, A-9, A-12, A-13, A-15,
A-18 … A-21, B-5 (every absorbed word is public — *"the best-supported claim
on the page"*), B-7 (leaf vs node, at the profile level), B-10 … B-12. Every
figure of Part A reproduced independently: `p − r = 2^32`,
`TV = 2^-96.0000000003`, `Pr[rej] = 2^-64.0000000007`, the 32.0-bit gap, the
five `fp()` draw counts, D9's 327,052, H-6's 2,093,340 / 2,283,876 /
109,728,784, `C(47,2) = 1,081`, `p^-256 = 2^-16384`, and both
counterexamples. This revision re-derived each of them once more, in the form
in which it is used, and each matched.
