# Adversarial check of the hash layer and the Fiat–Shamir lift for a RUN

**VERDICT — the draft's conditional statement: HOLDS WITH CHANGE.
"O-4 remains the gap": HOLDS, but the draft's reason for it is WRONG and must
be replaced.** Every number in the draft reproduces exactly on an independent
recount (including the two it says nothing validates), and Lemma H^run and
Route A^run survive the attack inside the stated model. Three things must
change before the page is quoted: (1) §4.4 / condition C-R3 — the claim that
"a run's hidden input is not fixed before the first message" is **false of the
code the draft itself transcribed**: the run header absorbs binding
commitments to the hidden input plane *and the hidden output plane* before any
challenge exists, so the prover has already run the whole forward pass; (2)
§5.1's "the code side of M-9 is built and pinned" — the whole run-statement
writer is `#[cfg(test)]`, and **there is no production caller of `prove_run`
at all**; (3) the residual table is missing the one row that the D19a model
actually costs (the pairwise `derive_key` collision), and §6.3's many-runs row
rounds 10^6 to 2^20.

| | |
|---|---|
| Written | 2026-09-21, 00:45 – 01:05 PDT (`date` read at 00:45:13 and 01:05:17) |
| Checker | an independent delegated Opus agent, instructed to assume the draft wrong. I did not write the draft and did not read its script before writing my own |
| Under attack | `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` (drafted 00:05–00:45 tonight) |
| Code read | `/home/victor/wt-zk60-block125m` at **`8c5922b`**, read-only, through `git --no-pager show 8c5922b:<path>`. Every `file:line` below was read there |
| Runs | nothing was built, proved, verified or benchmarked. Three Python scripts (exact integer/`Fraction` arithmetic) and one read-only pass over the public tag fields of the committed capture bundles: `results/zk60_hash_layer_fs_lift_run_check/` |
| What this is not | not a privacy acceptance, and no privacy claim about any run. D22 covers the toy block alone |

---

## 0. Verdict table

| # | The draft's claim | My verdict |
|---|---|---|
| 1 | The generator's `refill` is **plain unkeyed** BLAKE3 over `key(32) ‖ le64(counter)(8)`, 40 bytes (Claim N1) | **CONFIRMED**, `zkp-core/src/rng.rs:53-61`. The register, the tag disposition §2a and `hashtag.rs:22-33` are all **WRONG** on this point and must be corrected — see **B-3** |
| 2 | The 40-byte class inside F_U is still load-bearing and unoccupied on a run's path (N5) | **CONFIRMED**, and it is load-bearing *because* of item 1 |
| 3 | Lemma H^run, its four proof steps, and `T` as a public map | **HOLDS** inside the stated model. I found no gap in the argument |
| 4 | Route A^run, the ten hops, the hop order, B1–B9 | **HOLDS**, with two tightenings (**B-6**, **B-7**) that move no number |
| 5 | **F-1**: segment `k`'s trailer = segment `k+1`'s header tag; `L+1` distinct tags | **CONFIRMED** independently on all ten bundles (my own script). Not a leak, not a malleability weakness — see **B-5** for what I add |
| 6 | **F-2**: the length set a run builds never contained the run's own domain; the guard is off wholesale for tagged profiles; 125M run constructor = 46 B | **CONFIRMED** in the code and by measurement (46/48/51/56/57/58/59). One omission: constructor-vs-**absorb** is not treated anywhere (**B-7**) |
| 7 | **F-3**: the draw counts are stale; 687,028 / 9,029,804 per block, 2,093,340 / 109,728,784 per run; residual unmoved | **CONFIRMED to the draw** by an independent recount from the Rust. **Incomplete**: a *third* pinned receipt total moved too (**B-8**) |
| 8 | Every hash-layer term ≥ 37 bits below the D9 sampler term; total = the sampler term to 4 dp at every `q ≤ 2^128` | **CONFIRMED**: 37.30 / 37.42 / **37.47** bits |
| 9 | §6.3: 2^-49.29 at a million twelve-block 125M runs | **WRONG by 0.07 bits** — the row uses 2^20 for 10^6. It is **2^-49.36** (**B-9**) |
| 10 | The absorb count 1,129 / 1,138 / 5,932 is "validated by nothing" (§7.3 item 5) | **it is validated now** — I reproduce all three exactly by a different route (**B-10**, a retraction of the draft's own self-flag) |
| 11 | §7.3 item 4: is the 1,024-per-stage allowance generous? | **YES, by about 2.1×** (measured 325/stage at rung-G, scaled 1.49× = ~485 at 125M) |
| 12 | C-R5 / G-H4: no tagged commitment routes through the unkeyed device path | **CONFIRMED**, and stronger than the draft says (**B-11**) |
| 13 | **§4.4 / C-R3: the hidden run input is not fixed before the first message** | **BROKEN AS STATED** — see **B-1**, the most serious finding |
| 14 | §5.1: "the code side of [M-9] is built and pinned" | **MISLEADING** — the writer is `#[cfg(test)]` and no production path proves a run at all (**B-2**) |
| 15 | D19a "is an honest statement of exactly that assumption" (the draft's own §7.3 item 1 asks) | **NO, not as worded** — the *form* is honest, the *justification* is not (**B-4**), and the model does not delete the toy's two terms, it re-prices them into a row the table is missing |
| 16 | §8.2 "ten bundles, at three shapes and two hash rules" | **two run profiles**, not three shapes (rung-G ×8, rung-K4 ×2). Cosmetic (**B-12**) |

---

## B-1. THE MOST SERIOUS: the run header already fixes the hidden input *and the hidden output*, so §4.4's headline is false

**The memo's text.** §0: *"a run's hidden input is supplied one stage at a
time, after earlier segments are already on disk (`run.rs:512`, `:568`), so
'the witness is fixed before the first message' … is an operating condition on
the driver and **not a fact of the code**."* §4.4 escalates this to *"the one
thing a run makes HARDER, not merely longer"*, and §4.5 says *"at the toy the
witness is built by the caller before `prove_inner_at` is entered, so (ii) is a
fact; at a run it is condition C-R3 and **is false of the code as written**."*

**My evidence.** The draft transcribed the run header in its own §1.2 and then
did not read it. At `8c5922b`:

1. `RunStatement::transcript()` (`run.rs:304-322`) absorbs `expected-IO` =
   `ExpectedIo::to_bytes()` as its **second** word (`run.rs:316`). That frame
   is 112 bytes — `EXPECTED_BYTES = 8 + 32 + 4 + 4 + 2*32`
   (`private_block.rs:213`) — and it carries `self.input` and `self.output`
   (`private_block.rs:686-695`): **the Merkle roots of the hiding commitments
   to the hidden INPUT plane and the hidden OUTPUT plane.**
2. Those roots are not the prover's to choose at proof time.
   `prove_run` calls `protocol::check_endpoints` at `run.rs:470` — **before**
   the generator is opened (`:475`) and before the transcript exists (`:479`)
   — and `check_endpoints` (`protocol.rs:447-457`) **refuses** unless the
   prover's own endpoint owners produce exactly `expected.input` and
   `expected.output`.
3. The owners are made by `prepare_endpoints(spec, input, output)`
   (`private_block.rs:744-765`), which commits **both planes** with fresh OS
   entropy and returns the `ExpectedIo` those roots go into. So the caller must
   hold the run's **final output plane** before the statement exists.
4. `compute_output` is `witness::build(...)?.output()`
   (`private_block.rs:771-773`), and `witness::build_shaped(shape, public, ff,
   input)` (`witness.rs:437`) is a **pure deterministic function** — no rng, no
   state, no second input. The only caller in the tree, `Chain::from_parts`
   (`run_tests.rs:251-266`), runs it `L` times up front to build
   `planes[0..=L]`, and `statement_of` then calls
   `prepare_endpoints(spec, &c.planes[0], &c.planes[l])` (`run_tests.rs:433`).
5. No live challenge precedes any of this: the header is six absorbs, `binding
   = tr.state()` is a *read* (`run.rs:480`), and the first squeeze of the whole
   run is `position_tag`'s, on a clone, at `run.rs:492`.
6. Even the interior is pinned before publication. Boundary `k`'s plane is
   committed and its root absorbed at `run.rs:500-505`, **inside stage `k`**,
   while segment `k` does not leave until `run.rs:568`. Block `k+1`'s hidden
   input *is* boundary `k`'s plane, by the slot-21/slot-22 equality the proof
   carries. So for an **accepted** run every plane of the chain is fixed before
   the first published byte, by induction from the header.

**What is actually true.** Three statements, and the draft has none of them:

* **(a) In the privacy game the hypothesis is a definition, not a code fact —
  at the toy exactly as at a run.** The draft's own §5.1 game says *"the
  adversary names … two admissible hidden run inputs `w_0`, `w_1`. The
  challenger runs the **honest** prover once."* An honest prover's
  `RunWitnessSource` is `Chain`, whose `witness(k)` is
  `build_shaped(sh, public, ff, inputs[k])` with `inputs[k]` fixed at
  construction: **the whole witness sequence is a deterministic function of
  (public weights, `x_0`), all fixed before the header.** Hypothesis (ii) of
  the sequential-kernel lemma is discharged by the quantifier, and a run adds
  nothing to it.
* **(b) For a real deployment it is a consequence, not a condition — of three
  named things.** The header's endpoint roots + the binding of the endpoint
  commitment + the soundness of the proved chain give "the hidden input and
  output are fixed before the first message". That is **computational** where
  the toy's was syntactic, which is a real (and different) change and is the
  only honest thing §4.4 has to report.
* **(c) What genuinely remains** is not "the input", it is the **API**: the
  `RunWitnessSource` trait *permits* a source that answers adaptively, and
  nothing refuses one. An adaptively-chosen witness cannot produce an accepted
  run (by (b)), but it can produce an *aborted* one, and it makes the honest
  prover's determinism a property of the caller rather than of the type.

**Smallest repair.** Replace §4.4 and C-R3 with:

> **C-R3 (restated).** *In the privacy game the hidden run input is fixed by
> the game's own quantifier, at a run as at the toy.* In a deployment it is a
> consequence of the run header, which absorbs binding commitments to the
> hidden input and output planes (`run.rs:316`, `private_block.rs:686-695`)
> before any challenge is squeezed, and which `check_endpoints`
> (`protocol.rs:451`) refuses to let the prover restate — together with the
> binding of the endpoint commitment and the soundness of the boundary
> equalities. The owed engineering item is not "fix the input": it is **make
> `RunWitnessSource` take the chain at construction**, so that the honest
> prover's determinism is a fact of the type rather than of every caller.

And strike "harder in exactly one place" from §0, §4.4 and §4.5 item (ii);
a run is **longer** and not harder for O-4. O-4 itself stays open, for the
reason the draft gives in G-H1 and for that reason only: *nobody has extended
the sequential-kernel lemma to messages that are (field, hash) pairs.*

**Consequence for ruling R-1.3, which the draft repeats without checking.**
R-1.3 prices the "admissibility pre-pass" at *"one more forward pass — up to
about 15% of a run if done with the witness builder"*. **It is not one more.**
The output endpoint cannot be committed without it, so the pass is already
paid; today's harness pays it **twice** (once in `Chain::from_parts`, once
again per stage in `Chain::witness`). The marginal cost of R-1.3 is about
zero. The one real choice is *which* function computes the output plane: only
`witness::build_shaped` carries the twelve range refusals — a caller may
legitimately use the reference kernel `private-block-kernel::run_block`
instead, and nothing enforces either. **That** is the code fact R-1 should
carry, and it should be put back to the security owner.

---

## B-2. §5.1's "the code side is built and pinned" describes test-only code, and a run has no production entry point

**The memo's text.** §5.1: *"That is the game M-9 makes real, and the code side
of it is built and pinned: the statement file is written **only** by
`verify_then_write` …"* — with three `run_statement_file.rs` and two
`run_sink.rs` citations.

**My evidence.** `private_block.rs:178-179` reads
`#[cfg(test)] mod run_statement_file;`. The entire writer, `verify_then_write`
included, exists only in a test build — and it must, because `render` calls
`st.capture_header()` and `st.binding()`, both `#[cfg(test)]`
(`run.rs:327-338`). Further: `git grep prove_run` at `8c5922b` over
`hashline/src` returns **only** `run.rs`'s definition, two doc comments, and
three `#[cfg(test)]` modules (`run_tests.rs:440`, `:1125`, `:1412`,
`k4_tests.rs:484`, `run_capture_tests.rs:110`). `verify_run_from_dir` has no
caller outside `run_statement_file.rs`, itself test-only.

**Why it matters.** The object the draft's privacy game is defined over — "the
whole publishable run directory: the `L` segment files and the run statement
file" — **does not exist in a production build of this crate**. That does not
weaken the analysis (the code is the code), but it makes M-9 something
stronger than the draft says: not an operating rule with a built code side,
but a rule about **code that has not been written yet**.

**Smallest repair.** In §5.1, after "built and pinned", add: *"— in a
`#[cfg(test)]` module (`private_block.rs:178`). At `8c5922b` no production
path proves or verifies a run at all, so M-9's code side is a test harness and
the rule must be re-imposed on whatever production driver is written."* And
add it to §7.2 as a condition, not a fact.

---

## B-3. The register, the tag disposition and `hashtag.rs` all say the generator is keyed. It is not. Correct all three.

**The memo's text.** Claim N1, correctly: *"`ZkRng::refill` is still plain
unkeyed BLAKE3 over `key(32) ‖ le64(counter)(8)`, 40 bytes, at `rng.rs:53-61`."*

**The conflict the brief asks me to settle, settled.** Both memos are talking
about different lines and the *scoping* memo is the one being misread:

| line | mode | input | length |
|---|---|---|---|
| `rng.rs:47` `Hasher::new_keyed(&entropy)` | **KEYED**, key = 32 B of `/dev/urandom` | `"hashline-zk-os-rng/v1/"(22) ‖ domain` | 22 + \|domain\| |
| **`rng.rs:54`** `blake3::Hasher::new()` then `finalize_xof()` | **UNKEYED** | `key(32) ‖ le64(counter)(8)` | **40** |

So `ZK60_D19_HASH_TAG_SCOPING.md` §1's "`from_os` uses `new_keyed` at
`rng.rs:47`" is right about the **key derivation**, and the draft is right
about the **stream**. Keyed mode appears once, at the birth of the key; every
byte of every pad, mask, CFS coefficient and salt is produced by the
**unkeyed** function, in XOF form.

**What is wrong, and where.** Three places say the generator lives in its own
keyed member of the family:

* register **D19a** — via its source, the disposition below;
* `ZK60_D19_HASH_TAG_DISPOSITION.md` §2a (T-1, wording corrected): *"…the four
  keyed functions of a profile, **the generator's keyed function under its
  secret key**, and the unkeyed function the legacy rule uses"*;
* `zkp-core/src/hashtag.rs:22-33` — the same sentence, in the shipped source.

All three should read: *"…the four keyed functions of a profile, the **unkeyed**
function, which the legacy rule and **the generator's refill** both use, and
BLAKE3's derive-key mode, in which the four tag keys and the generator's own
key are made."*

**Why this is not cosmetic.** If the generator were its own keyed member, the
40-byte length argument (the draft's N5, ruling L-3's rescoped C-H1) would be
unnecessary; it is not. It is **the only thing that keeps the prover's
randomness stream out of an input an adversary can construct**, and the
completed length guard is what protects it on the legacy side
(`hash_domain.rs:72` `REFILL_LEN = 32 + 8`, imposed on legacy-rule profiles at
`:320-326`). The draft is right to keep it, the register is wrong to imply it
is not needed, and the "five BLAKE3 functions, not four" count in §1.1 is
correct. **The generator assumption as the toy's statement words it is
unaffected**: `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` §2 assumes the *output
stream* is indistinguishable from uniform and says nothing about the mode, so
no accepted sentence moves — only the modelling paragraph does.

---

## B-4. D19a is not an honest statement of the assumption it needs, and the model does not *delete* the toy's two terms — it re-prices them into a row the table is missing

**The memo's text.** §2.1 states D19a as *"a family of independent random
functions indexed by BLAKE3's mode and key"*, §2.2 deletes the toy's
**2^-241.42** and **2^-484.83** rows because *"the three inputs live in three
different functions"*, and §7.3 item 1 flags this itself as the weakest step
and asks a checker to rule.

**My ruling: the form is honest, the justification is not, and it is a change
of model relative to what was accepted as D19.**

1. The **form** — a family indexed by mode *and key* — is exactly what the
   argument uses, and the register says so. Good.
2. The **justification** attached to it is false. The disposition §2a and
   `hashtag.rs:26-30` both write: *"That is BLAKE3's own design claim for its
   modes."* BLAKE3's design claim is about its **three modes** (hash,
   keyed_hash, derive_key), separated by flag bits. `F_L` and `F_N` are the
   **same mode** under **different keys** (`pcs.rs:691-696`,
   `merkle.rs:27-32`, both through `hashtag::hasher(Some(k))`). Nothing in
   BLAKE3's design claim covers key-indexing.
3. The standard justification does **not** exist in the form written.
   Keyed BLAKE3 is a PRF/random-oracle family for **secret** keys; the toy's
   convention V-2 was written for a secret key and is here reused for four
   **public** ones. With public keys the functions are *not* independent
   random oracles — the adversary can evaluate all four. The right model is:
   **BLAKE3's compression function is ideal, and keyed mode replaces the
   chaining value with the key words.** Then a query to `F_L` and a query to
   `F_N` are two *distinct points of one ideal primitive* whenever
   `K_L ≠ K_N`, which gives everything the argument needs. That model is
   **strictly stronger** than the toy's (which needed unkeyed BLAKE3 as one
   random oracle plus indifferentiability of its XOF, convention V-1); it now
   needs ideality at a **chosen, public chaining value** as well.
4. **Therefore the two terms are not deleted, they are re-priced.** Under the
   ideal-compression reading, "a salted leaf input equals a node input" is
   impossible *given* `K_L ≠ K_N`, and the residual is exactly
   `Pr[derive_key collision]`. The draft computes that probability in Claim N7
   (`C(m,2)·2^-256`) and then **does not put it in the residual table**, which
   carries only the generator-key row `3·4·2^-256 = 2^-252.42`. The missing row
   is larger: with the `m = 8` keys that exist today, `C(8,2)·2^-256 =`
   **2^-251.19** [COUNTED]. It is 182 bits below the sampler, so nothing moves
   — but the table must carry it, because it is the honest price of the step
   that deleted two other rows.
5. One mitigation the draft has and does not use: `hashtag.rs:206-221`
   (`all_eight_keys_are_pairwise_distinct`) and `:188-203` pin the eight
   existing keys as distinct hex literals. **For today's profiles the term is
   not negligible, it is zero, by test.** The residual applies only to future
   profiles.

**The sentence for the project owner**, if the security owner agrees this is a
change of model relative to accepted D19:

> *When you accepted D19 you accepted that BLAKE3 behaves like a random
> function. The tag D19a adds something we did not put to you: that BLAKE3 in
> **keyed** mode behaves like a **separate, independent** random function for
> each of four keys that are **published**, not secret. That is a stronger
> assumption than D19, it is not what BLAKE3's designers claim (their claim is
> about the three modes, not about different keys of one mode), and the usual
> way to justify it is to assume BLAKE3's internal compression step is ideal
> even when an attacker chooses where it starts. Nothing measurable changes:
> the two error terms the tag removes were around 2^-241 and 2^-485, and the
> one it adds is about 2^-251, against a proof whose dominant error is 2^-69.
> The question is only whether you want the project's privacy statements to
> rest on the stronger assumption. We recommend yes, because the alternative —
> length-based separation under one unkeyed function — is what we are moving
> away from and is measurably more fragile.*

---

## B-5. F-1 confirmed; what it is, what it is not, and what should be pinned

**The memo's text.** F-1, "verified in the code and measured on ten bundles",
with `results/zk60_hash_layer_fs_lift_run/tag_identity_check.txt`.

**My evidence.** I wrote my own script
(`tag_chain_recheck.py`) against the same ten committed bundles, reading only
`start_tag` / `end_tag` / `profile` / `transcript_domain`:

```
bundle             L  fields distinct  L+1  chain  non-constant
run-a-tame ... run-j-zero-k4   (all ten)   6        4    4   OK      OK
F-1 verdict: CONFIRMED on 10 bundles
```

**Is it a leak, a malleability weakness, or wasted bytes?** Wasted bytes only.

* Not a leak: the value is a deterministic function of the published prefix
  and the verifier recomputes it (`run.rs:625`, `:765`).
* Not a splicing weakness, and I checked the mechanism rather than asserting
  it: `wire::decode_segment` compares the 32-byte **run binding** first
  (`wire.rs:430-432`, *"this segment belongs to another run"*), then `L`, then
  `k`, then the start tag against **the verifier's own transcript position**
  (`:436-438`) — never against the previous segment's trailer. Two runs can
  only share a binding if they share their whole public header, endpoint roots
  included, and `Endpoints` is consumed by value with no `Clone`
  (`private_block.rs:706-720`), so a second run against the same endpoint
  commitments does not type-check. Chained tags therefore buy an attacker
  nothing.
* The cost is `32(L−1)` bytes: 64 B at `L = 3`, 352 B at `L = 12`.

**One thing I add that the draft does not measure.** My F-1d test compared
`start_tag(0)` across bundles of the same profile that differ only in the
hidden input: **they differ.** That is correct and not a finding — the header
absorbs the endpoint roots, which are hiding commitments to the hidden planes
— but it makes the draft's §3.5(ii) phrase *"a deterministic public function
of the published prefix"* worth one clause: **the published prefix already
contains a commitment to the hidden input**, so the tags are carried by Lemma
H^run (the roots' hiding), not by "the tag is public". Put that clause in, or
a reader will think the tags are input-independent and they are not.

**What should be pinned (the draft's (c), sharpened).** A test asserting
`end_tag(k) == start_tag(k+1)` would pin the *coincidence*, which is not the
property anyone wants. Pin the property instead: **assert in `prove_run` (or a
test over it) that no transcript operation occurs between `run.rs:551` and the
next `run.rs:492`** — e.g. that the transcript's squeeze counter and state are
unchanged across `run.rs:552-571`. That catches the edit F-1(c) is about and
does not freeze a redundancy the project may want to remove.

---

## B-6. B9 is over-stated: a tag query cannot coincide with a live challenge *locally*; the non-local case folds into B6

**The memo's text.** §4.3 row B9: *"a position tag's query coincides with a
live challenge query — **impossible**: §3.5 (iii) — **0**."* §3.5(iii):
*"after `end_tag` the next live operation is the next stage's `start_tag` …
and then the same absorb."*

**My evidence.** The local argument is right and I verified every boundary,
including the two the draft's phrasing misses:

* after `start_tag` (`run.rs:492`) the next live operation is
  `absorb_u64(b"pb-run-stage", …)` at `:494` — true at every `k`;
* after `end_tag` at the **last** stage (`k = L−1`) there is no next stage at
  all: `prove_run` returns at `:573`. The draft's sentence ("the next live
  operation is the next stage's `start_tag`") is simply not true there; the
  conclusion is, a fortiori;
* the external **output** endpoint's opening happens at `run.rs:540-549`,
  *before* `end_tag` at `:551`, and on the verifier's side at `:737` before
  `:765`. So no opening falls between a tag and its comparison.

**What is over-stated.** The local argument rules out a tag point being
*reached again by the live chain along the same path*. It does not rule out a
live squeeze landing on a tag's point by a **state collision** — the live
state returning to a value a clone was squeezed at. That event is not zero; it
is an F_T state collision, already priced by B6 (`C(A,2)·2^-256`, 2^-222.04 at
125M). **Repair:** change B9's disposition from "impossible: 0" to
"impossible on the schedule; a non-local coincidence is an F_T state collision
and is inside B6". No number moves.

**One more, same size.** A tag is two squeezes (`challenge_fp2_vec(2)`,
`run.rs:406`), and the second is at `(first output, counter+1)` — a point
determined by an oracle answer. In the lazy-sampling hybrid that is fine, but
"the tags' two oracle points" are not both a priori fixed, and the sentence in
§3.5(iii) that treats them alike should say so.

---

## B-7. Constructor-versus-absorb is treated nowhere; and F-2's own size argument is right for the wrong stated reason

**The memo's text.** §2.3 / N6: *"F_T's inputs are the constructor
(`12 + |domain|`), the absorbs (`48 + |label| + |data|`, so ≥ 60 on this path)
and the squeezes (exactly 47)."* B3 covers absorb-vs-squeeze, B4 covers
constructor-vs-squeeze. **B1–B9 contain no row for constructor-vs-absorb.**

**My evidence.** From `transcript.rs` at `8c5922b`, the three layouts are

| query | input | length |
|---|---|---|
| constructor (`:29-45`) | `"hashline-v1/"(12) ‖ domain` | 12 + \|domain\| |
| absorb (`:59-68`) | `state(32) ‖ le64(\|label\|) ‖ label ‖ le64(\|data\|) ‖ data` | 48 + \|label\| + \|data\| |
| squeeze (`:101-111`) | `state(32) ‖ "squeeze"(7) ‖ le64(counter)` | **47** |

Measured constructor lengths, over every profile string on the lane
(`tag_chain_recheck.py`): **46** (125M run), **48** (125M block), **51** (toy
block), **56** (rung-G run), **57** (rung-K4 run), **58** (rung-G block),
**59** (rung-K4 block). *Six of the seven are ≥ 48 and therefore sit inside
the absorb class*, so the draft's "≥ 60 on this path" is not a separation: a
56-byte constructor and an absorb with `|label| + |data| = 8` are the same
length. Nothing follows — the constructor input's first 12 bytes are
`hashline-v1/` and an absorb's first 32 are a transcript state, so equality
needs the state to be a chosen 32-byte string, 2^-256 per query — but it is a
missing row, and it is the row a reader will look for once F-2 has taught them
to look at lengths. **Repair:** add **B10 — "the constructor input coincides
with an absorb input"**, disposed of at `(A + q)·2^-256`, **2^-128.00** at
`q = 2^128`, which is 59 bits below the sampler and 22 below B5. It changes no
total.

**And F-2's own arithmetic.** §2.3 says *"the collision is not a probability
but a deterministic property of the profile string"* and then, correctly,
prices the other half at 2^-256. The first clause is wrong on its own terms
and should go; the honest statement is: *a 47-byte constructor needs
`|domain| = 35` (deterministic, false at all seven profiles) **and** a
transcript state equal to `"hashline-v1/" ‖ domain[0..20]` (2^-256 per
squeeze).* I confirm 35 is the only dangerous length and that nothing in scope
is at it — 34 is the nearest (the 125M run profile). C-R2 is right and is
checked by nothing.

---

## B-8. F-3 is right and incomplete: a third pinned receipt total moved

**The memo's text.** F-3: *"`MODEL_RUNG_G` is **4,234,984 B** and
`MODEL_M125` **40,783,352 B** at `8c5922b`, against the 4,234,648 and
40,782,792 the D19 tag disposition §2b recorded."*

**My evidence.** `grow_tests.rs` at the two commits:

| model | at `9ded619` (the disposition's 15:50 state) | at `8c5922b` | delta |
|---|---:|---:|---|
| toy | 2,816,472 | 2,816,472 | 0 (correct: `lkv = 0`, S19-F1 does not reach it) |
| **frozen-seam rung** | **4,218,264** | **4,218,600** | **+336** — *not named in F-3* |
| rung-G | — (4,234,648 in §2b) | 4,234,984 | +336 |
| rung-K4 | did not exist | 4,743,128 | — |
| 125M | 40,782,792 | 40,783,352 | +560 |

The disposition §2b's sentence is *"receipt sizes unmoved (2,816,472 /
4,218,264 / 4,234,648 / 40,782,792)"* — **four** numbers, of which **three**
have since moved. F-3 names two. **Repair:** one line, "and the frozen-seam
rung's 4,218,264 → 4,218,600, the same +336 = 16 × 21".

**Everything else in F-3 reproduces exactly**, from the Rust and not from the
memo (`residuals_recount.py`, formula
`(rows − data_rows)·n + rows·Q` per hiding commitment, `2·Σ L_s + 46·256 +
4·1024` for `M` (`zk.rs:373-375`, `:431-462`), `2(n−1)` for `H`'s zero-sum
re-draw, `Σ L_s = published − draws + 46`):

```
config      sum L_s    per block  boundary  endpoint     run total   log2 term
rung-G          859      687,028     8,704     7,424     2,093,340    -75.0026
rung-K4         871      750,540     8,704     7,424     2,283,876    -74.8769
125M           1239    9,029,804   108,032    91,392   109,728,784    -69.2906
control, PRE-repair:  686,990 / 2,093,226 and 9,029,742 / 109,728,040  (the run memo's own)
```

---

## B-9. §6.3's many-runs row rounds 10^6 to 2^20

**The memo's text.** §6.3, header *"`k = 10^6` runs"*, and *"a service that
emits a million twelve-block 125M runs sits at about 2^-49"*, with the table
giving −55.00 / −49.29 (sampler), −96.83 / −94.83 (refusal), −185.60 /
−174.52 (leaf collision), −92.30 / −86.76 (salt guessing).

**My evidence.** `log2(10^6) = 19.9316`, not 20. Every entry is 0.07 bits
optimistic, and the quadratic row 0.14. Corrected:

| `k = 10^6` | sampler | refusal | leaf collision | salt guessing |
|---|---:|---:|---:|---:|
| rung-G `L=3` | **−55.07** | −96.90 | −185.74 | −92.37 |
| 125M `L=12` | **−49.36** | −94.90 | −174.66 | −86.83 |

"About 2^-49" survives. **Repair:** either move the numbers or relabel the row
`k = 2^20`. Note the toy's published figure ("about 2^-57.7 at a million
proofs") used 10^6 correctly, so the two pages currently round differently.

---

## B-10. A retraction the draft is owed: its absorb count IS validated

**The memo's text.** §7.3 item 5: *"1,129 / 1,138 / 5,932 is this page's model
of the code's absorb sites and is **validated by nothing** — the gate measures
squeezes, not absorbs."*

**My evidence.** It is validated now, by a route the draft did not use: the
capture bundles' own `transcript_program` (a public field of `run.json` —
the recorder's transcription of `run.rs`'s absorb sites), the pinned layout
models, and the **measured** per-role opening group counts read out of the
bundles (`roles[*].groups`: A = 36, H = 9, external endpoint = **1**, internal
boundary = **2**). `absorb_count_validation.py`:

```
config       L  this script   the draft  agree
rung-G       3        1,129       1,129  YES
rung-K4      3        1,138       1,138  YES
125M        12        5,932       5,932  YES
```

Two independent derivations agreeing on all three, with the one free parameter
(the endpoint and boundary group counts) fixed by measurement rather than
guessed. §7.3 item 5 should be struck and replaced by the citation.

**And §7.3 item 4 is answered.** Modelling the squeeze channels the program
names and subtracting from the gate's measured `final_counter` gives **325.0**
unmodelled slot-definition draws per stage at rung-G and 328.0 at rung-K4;
the slot variable count grows 1.49× to 125M, so ~485 per stage is the
extrapolation against the draft's allowance of 1,024 — **about 2.1× generous**.
Even a 100× error leaves the pre-query term at ~2^-103.8, 34 bits below D9,
exactly as the draft says. I also re-derived control **C7** myself on all six
gate bundles: `final_counter − challenges_checked = 832 = 64·(4L+1)` at
`L = 3`, exactly, on every one — **and the dense and all-zero bundles give
identical counters at both rungs** (6,924/6,924 and 7,686/7,686), which is the
measurement step 23 needs.

---

## B-11. C-R5 / G-H4 is true, and true for one more reason than the draft gives

**The memo's text.** §7.1 row 36 / C-R5: *"`hashline/src/pcs.rs:83-97`
(`commit_zk_device`) builds **unkeyed** leaves and an **unkeyed** tree. It is
called only from `zk.rs:1427` and `:2801` … and `commit_zk_owned_with_tag`
declines the device whenever a column key is set (`pcs.rs:782-785`)."*

**My evidence.** All of it checks out (`hashline/src/pcs.rs:83`,
`salt_leaf`/`MerkleTree::build` unkeyed at `:95-97`; `zk.rs:1427`, `:2801` are
`prove_zk` and `prove_zk_v3`, the legacy feed-forward line;
`zkp-core/src/pcs.rs:782-785` declines the backend on `Some(_)`). Three
additions:

1. `commit_zk_device` is **`#[cfg(feature = "gpu-cuda")]`** (`pcs.rs:82`). It
   does not exist in a build without that feature, which is every build this
   lane takes. That is a second barrier the draft does not name.
2. The masking commitment `M` never reaches a backend at all under either
   rule: `mask_commit_tagged` (`zk.rs:481-518`) hashes its own columns
   (`hash_columns_keyed` at `:514`) and `zk.rs:470-480` says so explicitly —
   so T-8 has nothing to decline there. The draft's inventory is right but
   its reason is only half the picture.
3. The `HashTag` type makes a partial key set unrepresentable (a private
   `Rule` enum, `hashtag.rs:64-79`), so "a column key is set" and "the profile
   is tagged" are the same condition. C-R5 cannot be violated by a
   half-configured tag.

**Verdict: C-R5 TRUE, G-H4 correctly sized as a future-path gap, and the
draft's wording is if anything conservative.**

---

## B-12. Smaller corrections

| # | where | the text | the correction |
|---|---|---|---|
| a | §8.2, §3.5 F-1 | *"ten bundles, at **three shapes** and two hash rules"* | **two run profiles**: `private-run-rung-g-t24-dev/1` (bundles a–h) and `private-run-rung-k4-t24-dev/1` (i, j). All ten are `L = 3`. The two rules are right (a–d legacy, e–j `blake3-keyed/1`) |
| b | §1.3 table | *"tree nodes revealed in total (expected) 27,770.3 / 179,359.1"* | I get 27,770.6 and 179,358.3 from the same per-tree figures. Rounding, not error; the per-tree table (248.2 / 481.4 / 233.2 / 1,654.8 / 2,136.2 / 26.1 % and 255.5 / 510.0 / 254.5 / 4,154.7 / 3.2 %) reproduces **exactly**, including the convention of counting the root outside "internal nodes" |
| c | §6.2 table vs §5.2 | the table prices S-4 at `L·768/\|Fp2\|`, §5.2 discharges it at `2·L·768/\|Fp2\|` | one bit; use the doubled figure in the table (−115.83 / −113.83) or say which is which |
| d | §2.3 | *"the absorbs (… so ≥ 60 on this path)"* | the bound that matters is ≥ 48 (the minimum of the layout), which is what B3 needs; "≥ 60" is an unstated shape fact and is not what makes B3 true |
| e | §1.1 table, F_U row | cites `layout.rs:1288` for the block schedule digest | at `8c5922b` the digest's hasher is at `layout.rs:1288-1296`; fine, but the row's "31 + all public weight words" for `private_block.rs:512-518` should say **`b"hashline/private-block-public/1"` is 31 bytes** so the reader can check it |
| f | §3.5 | the tag's 32 bytes are *"two `Fp2`, rendered as 32 bytes"* | true, and worth a clause: each `Fp` is a 128-bit squeeze reduced mod `p`, so the 32 published bytes carry slightly under 256 bits. Public value, no consequence — but a later reader must not treat a tag as a full 32-byte oracle output |

---

## What survived every attack I could make

* **Lemma H^run and its four steps.** Step 1 (`pcs.rs:1248`, `zk.rs:671` — the
  verifier itself recomputes `salt_leaf_keyed(hash_column_keyed(col), salt)`),
  step 2 (`open_zk` emits only sampled columns' salts, `pcs.rs:1043`, `:1048`;
  `mask_open` the same, `zk.rs:598`), step 3 (`merkle.rs:27-32` — a node input
  contains no salt and no field value), step 4. I could not break the
  factorisation and I could not find a published object outside `T`.
* **Claim N3** — only the `4L+1` roots are absorbed. I traced every absorb site
  in `run.rs`, `protocol.rs` and `pcs.rs` and found no salt, path, tag or
  binding absorbed anywhere; the run binding is compared, never adopted
  (`wire.rs:430-432`), and the tags come off clones.
* **The twelve witness-build refusal sites** at `witness.rs:290, 374, 386, 394,
  526, 534, 542, 555, 600, 640, 672, 708`, with `:431` and `:443` the two shape
  refusals — exactly the draft's list, fourteen `return Err` in total, and none
  has moved.
* **Every residual figure** in §6.2, reproduced from the Rust by a script that
  shares no code with the draft's, including the 37-bit gap
  (**37.30 / 37.42 / 37.47**) and the fact that `ε(q)` equals the D9 sampler
  term to four decimals at `q = 2^80` and `q = 2^128` alike.
* **The privacy game's shape.** "Accepted receipts only" is the right game
  given M-9, and the draft's §5.3 treatment of the abort distribution is
  correct and is the sharpest passage on the page: the FACT of refusal is
  observable to a relying party, it is 0-or-1 in the hidden chain, it is
  outside every statement the project has, and the draft says so. I add only
  B-2 (the code side is test-only) and the note that the challenge-only class
  (2^-58.79, liveness) and the LogUp class (2^-114.83, distance) are the two
  the argument does cover, so a relying party who sees a refusal learns
  "either an inadmissible chain, or one event of probability ≤ 2^-58.79" —
  which is very nearly "an inadmissible chain". That sentence belongs in §5.

---

## What I could not check

1. **Theorem B itself**, and gaps G-R1, G-R2, G-R3, G-R4. Out of scope here;
   every figure above is conditional on them, and G-R3 is blocking at 125M.
2. **Whether the constraint system determines the witness interior from the
   input plane.** B-1(b) needs it for a *malicious* prover; I established only
   that `witness::build_shaped` is a pure function of `(shape, weights, input)`,
   which is what the *honest* prover needs. Whether a different admissible
   witness could satisfy the same relation is a soundness question and nobody
   has asked it.
3. **The binding term of the endpoint commitment.** B-1(b) makes C-R3 a
   computational consequence, and computational consequences have terms. No
   page in this project prices the binding of a hiding Merkle/PCS commitment,
   and the run's soundness figure (~2^-97.5, ruling M-2) is not obviously the
   right substitute.
4. **BLAKE3 itself.** I did not read the literature on indifferentiability of
   its XOF (convention V-1) or on keyed mode with public keys. B-4 is a
   modelling judgement, not a citation.
5. **The 125M shape.** Nothing there is measured, by the draft or by me. My
   125M figures are arithmetic on geometry constants.
6. **The gate's `columns_authenticated` (3,328 of 3,328; 0 of 3,328
   cross-profile)** and the receipt byte totals of real proofs. I read the
   pinned models, not a proof.
7. **Whether any *other* consumer of `ZkRng`** outside the run path produces a
   40-byte unkeyed input. I checked the run's own F_U inventory and the legacy
   column case (5 rows, refused by the guard); I did not sweep the whole crate.
   Ruling L-3 already rescoped this claim to "on the profile's path", and that
   scoping is what B-3 relies on.

---

## Evidence

`results/zk60_hash_layer_fs_lift_run_check/` — README, three scripts, three
outputs, one JSON. Exact integer / `Fraction` arithmetic, no dependencies,
under two seconds total. They read the Rust at `8c5922b` (quoted as constants
with `file:line` in each header), the committed capture bundles' **public**
tag and role fields, and the run gate's JSON counters. **No witness, salt,
pad, private plane or receipt byte was read.**

| file | what |
|---|---|
| `tag_chain_recheck.py` / `.txt` | F-1 on all ten bundles (chain, distinct count, non-constancy), the new F-1d input-sensitivity measurement, and the constructor-length table for F-2 / C-R2 |
| `residuals_recount.py` / `.txt` / `.json` | the draw counts, `N_leaf`, the whole residual table, the many-runs row, and the tree-occupancy table — all from the Rust, none from the draft |
| `absorb_count_validation.py` / `.txt` | the absorb count 1,129 / 1,138 / 5,932 re-derived from the capture's `transcript_program`; the squeeze-channel model against the gate's measurement; the 1,024/stage allowance sized |
| `gate_squeeze_control.py` / `.txt` | control C7 re-derived on all six gate bundles, and the dense-vs-zero counter equality |
