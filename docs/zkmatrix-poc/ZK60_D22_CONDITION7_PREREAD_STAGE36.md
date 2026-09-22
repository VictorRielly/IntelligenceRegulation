# The D22 condition-7 PRE-READ of lane stage 36 (`fee1a8d`..`29cba9a`)

**Status: `CLOSED` (the reading is done).** Opened 2026-09-22 11:33 PDT and
closed at 11:41 on the review worktree `/home/victor/wt-zk60-block125m-review`,
branch `zk60-private-block-125m-review`, at `29cba9a` (identical to the lane
tip). Written by an independent adversarial reviewer who is the sole writer on
that worktree, under instruction to assume every claim of the stage wrong
until re-derived by a different method.

**What this is.** A pre-read of the lane's stage 36 — the read-only test
observers — against the conditions of the accepted toy privacy statement
(`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` §5 conditions 1–7, §8, §9 items 5–8
and 11), written so that the security owner can re-pin the statement on the
day the integrator merges the delta.

**What this is NOT** (written first, so it cannot be read as more):

* **Not the re-pin.** Only the security owner moves a pin of D22. This page is
  the reading and the arithmetic they would otherwise have to do; §6 is a
  table to paste, not a pin that has moved.
* **Not a statement about the integrator's merge**, which does not exist yet.
  It says what a clean merge would produce, what only the integrator's own
  tree can answer, and what must be re-checked when it exists.
* **Not a privacy claim.** Stage 36 establishes no privacy property and
  neither does this pre-read. What is at issue is condition 7 — whether the
  changed files are still the files the gates' Python ports describe — and
  whether the delta can be seen from a production build.
* **Not a review of the lane's stages 1–35, nor of main's host changes.** It
  reports where those two have already diverged (§6), because that decides
  what the re-pin at integration is against, and it reviews neither.

**Verdict in one line.** Stage 36's production-identity claim is TRUE and
stronger than the lane proved it: the production residue of all four pinned
files it moves is byte-identical, and the compiler confirms the release
artifact carries none of the added code. Conditions 1–6 and §9 items 5–8 are
unaffected; condition 7 is triggered for four pinned files, exactly as the
statement's §9 item 11 already records. Seven findings, none of them a defect
in the proof, two of them worth acting on at the re-pin (P36-2, P36-3).

---

## 1. The delta, and what it touches

Eight commits, `fee1a8d`..`29cba9a`. Twenty-three files change; six carry
code or configuration and the rest are the ledger and evidence logs.

| file | + | − | kind | in the D22 pin set? |
|---|---:|---:|---|---|
| `zkp-core/src/rng.rs` | 225 | 0 | the consumption accessor + 4 tests | **yes** (`SOURCE_PINS`) |
| `zkp-core/src/transcript.rs` | 114 | 0 | the squeeze counter + 2 tests | **yes** (`SOURCE_PINS`) |
| `hashline/src/private_block/protocol.rs` | 21 | 0 | the observer hook (10 gated lines + 11 comment) | **yes** (`PATH_PINS`, `terminal_polys`) |
| `hashline/src/private_block.rs` | 11 | 0 | two `#[cfg(test)] mod` declarations + comment | **yes** (`PATH_PINS`) |
| `zkp-core/Cargo.toml` | 15 | 0 | `[features] test-observers = []` | **no — pinned by nothing** |
| `hashline/Cargo.toml` | 7 | 0 | one `[dev-dependencies]` line | **no — pinned by nothing** |
| `hashline/src/private_block/draw_observer.rs` | 177 | 0 | new, whole module `#[cfg(test)]` | no (new test file) |
| `hashline/src/private_block/s36_tests.rs` | 882 | 0 | new, the draw-accounting test | no (new test file) |
| `hashline/src/private_block/s25_tests.rs` | 42 | 11 | the tripwire retired by its mirror image | no (test file) |

**Every deletion in the whole delta — all 11 — is in `s25_tests.rs`**, a
`#[cfg(test)]` file, and they are the old tripwire's body. No line was deleted
from any other file. That is a fact of `git diff` and needs no parser.

The other 28 of the 32 pinned paths are byte-identical at `fee1a8d` and
`29cba9a` (`p36-threeway-digests.txt`), so conditions 1, 2, 3 and 5 — which
live in `zk.rs`, `argument.rs`, `layout.rs`, `pcs.rs`, `merkle.rs` and the
attention files — cannot have been touched by this delta at all.

## 2. The production-identity claim, re-derived — proof and evidence separated

The lane proves its claim one way: `z36-cfg-gate-proof.py` classifies the
DIFF's added lines and requires each to be inside a `#[cfg(test)]` /
`#[cfg(any(test, feature = "test-observers"))]` item or to be a comment.

**This pre-read never looks at the diff.** `p36-production-residue.py` takes
each file WHOLE at both commits, deletes every gated item together with the
attribute that gates it, deletes comments and blank lines, and compares what
is left — line by line and by digest. That is a strictly stronger statement
than "every added line is gated", because it also covers lines that were *not*
added: a reordering, an edit inside an existing function, a deleted line, a
production line moved into a gate would all show. Brace tracking ignores
braces in strings, chars and comments, and the walk asserts depth 0 at end of
file, so a mis-parse cannot pass silently.

| file | lines | gated | comment/blank | **production lines** | residue sha256 |
|---|---|---|---|---|---|
| `zkp-core/src/rng.rs` | 136 → 361 | 33 → 227 | 9 → 102 | **78 → 78** | `11735c63…` → `11735c63…` |
| `zkp-core/src/transcript.rs` | 244 → 358 | 76 → 175 | 37 → 92 | **119 → 119** | `3a58769b…` → `3a58769b…` |
| `…/private_block/protocol.rs` | 1212 → 1233 | 96 → 106 | 374 → 385 | **676 → 676** | `bbbff456…` → `bbbff456…` |
| `hashline/src/private_block.rs` | 995 → 1006 | 80 → 84 | 419 → 426 | **449 → 449** | `3ee0cab5…` → `3ee0cab5…` |

**Every watched file's production residue is byte-identical across the delta.**
Note the fourth row: `private_block.rs` is a PINNED file the delta moves, and
the lane's own script does not watch it (finding P36-1). It is watched here.

**The stronger check, made with the compiler.** `p36-symbol-differential.txt`:
three release builds at `29cba9a`, cargo's own JSON reporting the feature set
of each zkp-core unit, and the three added identifiers counted in each
artifact.

| build | zkp-core features | `consumed_bytes` | `OBSERVED_BLOCK_BYTES` | `squeezes` |
|---|---|---:|---:|---:|
| zkp-core, release | `[]` | **0** | **0** | **0** |
| zkp-core, release, `--features test-observers` | `["test-observers"]` | 3 | 2 | 2 |
| **hashline, release (the real release graph)** | `[]` | **0** | **0** | **0** |

The middle row is the control: it shows the search discriminates. The third
row is the one the lane could not make, and it is the important one —
`cargo tree -e features,no-dev` (the lane's evidence) removes the dev edge by
construction and would print the same thing under either feature resolver,
whereas this is cargo compiling the real release graph and reporting that the
dev-dependency's feature did not unify into it.

**What is proof and what is evidence.**

* **Proof** (a check that cannot pass if the claim is false): that no
  pre-existing line was deleted or modified in the four files — a property of
  the diff itself; and that the production residue is byte-identical — modulo
  this reviewer's parser, whose one dangerous failure mode (a gated region
  extended too far) is guarded by the depth-0 assertion and by running the
  same parser on both sides.
* **Evidence** (strong, but not a proof of the same sentence): the symbol
  differential, which says the release ARTIFACT carries none of the added
  code; the feature resolution of the release graph; 11 tests green including
  three frozen toy gates and four archived toy receipts still verifying at
  2,816,472 B; zkp-core's own 56 tests green without the feature flag.
* **Not established**: that the release BINARY is bit-identical before and
  after. Compiling `fee1a8d` would have needed a checkout this reviewer may
  not make, and building a copy of the tree would have used a different
  manifest path from the one the review's build rule fixes. The residue
  identity carries that half of the argument at the source level; the symbol
  differential carries it at the artifact level; neither is the bit-identity
  check, and this page does not claim it.

**One property worth naming, because it is better than a pin.** The hook in
`protocol.rs` calls into `super::draw_observer`, and that module is itself
declared `#[cfg(test)] mod draw_observer;`. So if any of the five
`#[cfg(test)]` attributes in `check_opening_challenges` were ever dropped, a
release build would **fail to compile** rather than silently compile an
observer into the prover. The compiler, not a source scan, is the guard there.

## 3. Conditions 1–7, one by one

| # | condition | verdict against this delta |
|---|---|---|
| 1 | one reserved mask pair per claim site; `audit_claims`' pair-exclusivity | **unaffected** — `zk.rs` and `argument.rs` are byte-identical across the delta |
| 2 | pad count equals opened columns, per row | **unaffected** — same files, byte-identical |
| 3 | `d+1` per sumcheck round; exact-row-span assertions; refusal on a zero mask challenge; the declared order of the mask functionals | **holds.** This is the one condition the delta comes near: `check_opening_challenges` IS the refusal function. Its production residue is byte-identical (§2), and a differential test run here (§5) shows the returned verdict, the refusal string, the challenge sequence and the draw count are identical with and without the observer engaged, at all three exits |
| 4 | one opening per commitment; a refusal is terminal, enforced by the type system | **holds**, and §9 item 7's type-level fact with it — see the row below |
| 5 | every Merkle leaf salted; no unsalted column digest published, logged or captured | **holds** — nothing in the delta publishes, logs or captures anything. The added `eprintln!`s print counts, labels, segment offsets and verdicts; the source scans print a SOURCE line on failure, which is public text; no capture writer changed |
| 6 | fresh OS randomness per proof; no seeded configuration on this profile's path | **holds** — see §4 item 5 |
| 7 | the source pins of the Python gates | **TRIGGERED** — four pinned files move. Step 3 is suspended for them until re-read and re-pinned, which is what §9 item 11 already records and what §6 prepares |

**Condition 4 and §9 item 7, in detail.** `ZkRng` is still not `Clone`. The
delta adds no `impl Clone`, no `derive(Clone`, no `derive(Copy`, no
`Serialize`/`Deserialize` for the generator — not in production text and not
under `cfg(test)` either; the only `Clone` tokens the delta adds are the
non-`Clone` PROBE and its two controls, and `derive(Clone, Copy)` on the
observer's two count types (`Verdict`, `Call`), which hold a draw count and an
exit name and no generator state. The delta strengthens this condition: it
adds a second independent probe (`zkp-core::rng::tests::the_generator_is_
still_not_clone`) beside the lane's existing one, each with its own two
controls, both run here and green. The generator's four fields are still
private and both accessors take `&self` and return `u64`.

## 4. §9 items 5, 6, 7, 8 and 11

**Item 5 — three fresh reads of the operating system's entropy per proof.**
Holds, and the delta does not change the number of generator constructions.
Two independent reasons: the production residue of `protocol.rs` is identical,
so its one `ZkRng::from_os` is where it was; and the delta's own source scan
(`the_three_generators_of_one_proof_are_three_separate_streams`, run here,
green) asserts one construction in `prove_inner_at`, two calls to endpoint
preparers from `prepare_endpoints`, one `from_os` in each preparer, zero
`ZkRng::new` in any of them. **The observer module constructs no generator and
the hook constructs none** — `draw_observer.rs` names no generator at all; it
wraps a closure. The delta does add seeded `ZkRng::new` fixtures, six of them,
all inside `#[cfg(test)]` tests in `zkp-core/src/rng.rs`, plus one `from_os`
inside `measure_endpoint`; none is reachable from a profile. One thing for the
security owner to know rather than to act on: stage 25's provenance scan reads
only hashline's `private_block` production modules and `private_seam.rs` — it
does not read zkp-core at all, so it is not what rules those new fixtures out;
their being inside `#[cfg(test)] mod tests` is.

**Item 6 — the two endpoint generators derive their keys from byte-identical
public inputs.** Unchanged and still true at the frozen toy profile:
`private_seam::prepare` calls `ZkRng::from_os(DOMAIN)` with the same constant
for both sides (its `side` parameter does not enter the domain), while the
generalised endpoint `endpoint_g::prepare` already uses
`seed_domain(spec, role)`. **The delta neither closes the weakness nor makes
it worse, and it adds no test that would notice a change to either domain.**
The "owed on the lane" half of clarification 6 — the endpoint's role and spec
digest into the generator's domain for every unfrozen profile — is still owed
and is not in this stage.

**Item 7 — the generator is not `Clone`.** Holds; see §3.

**Item 8 — no commitment has 5 or 8 rows, and no transcript domain on this
path has length 28 or 35.** Unaffected. These are properties of production
lines, and no production line of any pinned file changed. The delta's own new
transcript domain, `b"stage36"` (7 bytes), is in zkp-core's own test module.

**Item 11 — the counts are now MEASURED by an accessor.** Reproduced here
independently of the lane's logs: the test
`the_three_generators_of_a_toy_proof_draw_the_statements_327052_field_elements`
runs in the ordinary filter and printed, on this reviewer's own run
(`p36-gate.log`), *327052 fp() draws per toy proof = 320908 (block) + 6144
(two endpoints); 12288 salts; 5626048 stream bytes*. It compares a measured
quantity with `assert_eq!`, so it fails for 327,051 by construction. **But the
label needs one refinement** — see finding P36-5: what the accessor measures
is the BYTE TOTAL; the fp/salt split of the block's share is the closed form's,
tied to the measurement only through `bytes = 16·fp + 32·salts`.

## 5. The attacks, and what they found

The reviewer's own tests are in `hashline/src/private_block/p36_preread_tests.rs`,
registered in `private_block.rs` under `#[cfg(test)]`. **They exist only on the
review branch and are no part of the lane's delta.** All three pass
(`p36-gate.log`, 11 tests, 0 failed, exit 0).

1. **Can the hook change anything a caller sees?** `the_observer_changes_no_
   value_no_verdict_and_no_generator_state` drives the production
   `check_opening_challenges` over a draw source the test controls, twice for
   each of its three exits — once with no observer session open and once with
   one open — and compares the full sequence of challenges the function
   consumed, the `Result` including its refusal string, the number of times
   the draw closure was called, and the generator's consumption at the end.
   **All four agree at all three exits** (accepted: 9 draws, 5 group + 4
   proximity; zero group member: 4 draws, short-circuited; dependent
   proximity: 4 draws). The observer's own numbers are then checked against
   the ground truth the test holds separately. The shadowing `let` therefore
   changes neither evaluation order nor the number of draws nor a returned
   value; the wrapper releases its borrow of the thread-local before calling
   the inner closure, so it cannot re-enter or panic.
2. **Can a record leak between measurements?** `the_observer_leaks_no_record_
   across_sessions_or_out_of_an_unwatched_call`: a session's records do not
   survive its drop, and a call made with no session open records nothing — so
   a stale record cannot be counted into the next proof's 1,027 points.
3. **Can any code outside a `cfg` gate observe the counters?** No. Both
   accessors are inside `#[cfg(any(test, feature = "test-observers"))]`
   `impl` blocks, take `&self` and return `u64`; `ZkRng`'s four fields stay
   private; neither type gained a `Debug`, `Display` or `Serialize` impl or a
   `pub` field; the only `Debug` in the delta is on the observer's two count
   types inside a `#[cfg(test)]` module. `OBSERVED_BLOCK_BYTES` is the
   existing `RNG_BLOCK` constant, a compile-time property of the code.
4. **Does any test in the delta print a value?** No. Every `eprintln!` added
   prints counts, labels, byte offsets, refill/squeeze counts and verdict
   names. Two `format!`s build failure messages containing a SOURCE line from
   a production file — public text, and only on failure.
5. **Is `test-observers` reachable from a normal build of any crate?** No.
   `test-observers` appears in exactly two manifests in the whole checkout —
   zkp-core's `[features]` and hashline's `[dev-dependencies]` — and hashline
   is the only crate in the tree that depends on zkp-core. `cargo metadata`
   reports `workspace_members = [hashline]`. The release graph resolves
   zkp-core with `features: []` (§2). **The one way this could silently become
   false is finding P36-3.**
6. **Does the stage's own source-scan machinery have a hole the delta widens?**
   One, small: the replica-fidelity test pins the wrong half of the frozen
   seam (finding P36-4). A test written here closes it and passes today.

## 6. The three-way digest table, and the re-pin

**The three-way view the security owner needs.** The lane forked from main at
`3811e55`. `4751b93` — the tree D22 pins — is on main after the fork. So there
are three trees, not two, and the lane's own "before/after" table is against
the LANE's base, not against the tree the statement pins.

**13 of the 32 pinned paths already differ between the lane base `fee1a8d`
and main `4751b93`, before stage 36 touches anything** (full table in
`p36-threeway-digests.txt`, attribution in `p36-divergence.txt`):

| moved since the fork by | count | which |
|---|---:|---|
| the LANE only (main untouched) | 9 | `private_block/argument.rs`, `zkp-core/pcs.rs`, `zkp-core/transcript.rs`, `zkp-core/merkle.rs`, `private_block/wire.rs`, `private_block/witness.rs`, `zkp-core/lib.rs`, `private_block/layout.rs`, `private_block/protocol.rs` |
| MAIN only | 1 | `hashline/src/gpu/mod.rs` |
| **both** | 3 | `hashline/src/zk.rs`, `hashline/src/private_block.rs`, `hashline/src/pcs.rs` |
| neither | 19 | the rest |

Every one of main's 32 pinned files is at a digest the pinned tool accepts
today — 28 at the pin of record and 4 at the second accepted digest
(`zk.rs`, `hashline/pcs.rs`, `private_block.rs`, `gpu/mod.rs`) — checked here
against `zk60_native_mask_commit`'s own tables rather than against the record's
prose. **The condition-7 obligation at integration is therefore much larger
than stage 36: it is 13 pinned files, of which stage 36 contributes 4.** That
is the lane's whole integration to answer for, not this stage; it is stated
here so the re-pin is not scoped to six files by accident.

**The six files stage 36 moves, three ways, with what a clean merge gives**
(`p36-merge-prediction.txt`):

| path | pinned? | main `4751b93` | lane base `fee1a8d` | lane tip `29cba9a` | a clean 3-way merge |
|---|---|---|---|---|---|
| `zkp-core/src/rng.rs` | **yes** | `0d4a99ab…` (pin of record) | `0d4a99ab…` | `b9920aeb…` | **`b9920aeb…`** (main never moved it) |
| `zkp-core/src/transcript.rs` | **yes** | `31ce3c9a…` (pin of record) | `cc9752d0…` | `b8a228d9…` | **`b8a228d9…`** (lane-only, then this delta) |
| `hashline/src/private_block/protocol.rs` | **yes** | `d9455a10…` (pin of record) | `ac412237…` | `e0e617be…` | **`e0e617be…`** (lane-only, then this delta) |
| `hashline/src/private_block.rs` | **yes** | `412a43f4…` (2nd accepted) | `b4aeb6ed…` | `fa0daca6…` | **`fa0daca6…`** — both sides moved it, but main's only change since the fork is the two lines `#[cfg(test)] mod norm_alias;`, which the lane's tip already carries at the same place |
| `zkp-core/Cargo.toml` | **no** | `b9038a52…` | `b9038a52…` | `90156d58…` | `90156d58…` |
| `hashline/Cargo.toml` | **no** | `eaba50ec…` | `e3acda1b…` | `5633d1e4…` | `5633d1e4…` |

Full 64-hex digests are in `p36-threeway-digests.txt` and
`p36-merge-prediction.txt`; the four pinned "after" values agree with the six
the lane's ledger publishes.

**What the integrator's merge must reproduce, and what it cannot be assumed
to.** Every digest in the last column is a PREDICTION of a clean three-way
merge. The integrator states (coordination note, 2026-09-22 07:25) that it is
**assembling the lane at `fee1a8d` as a fixed snapshot, not merging the
branch** — and its own reported integration hashes confirm the model but not
the method: `zkp-core/src/pcs.rs` `6b8d1bfa…` and `zkp-core/src/transcript.rs`
`cc9752d0…` are exactly the lane base's blobs (lane-only changes, so a merge
would give those), while `hashline/src/zk.rs` `07282c76…` is neither side's —
a genuinely new blob, as the "both moved it" row predicts. **So the security
owner must hash the integrator's tree as it is; the predictions are what to
compare against, and a disagreement is a question, not a failure.**

One thing to expect that is not in the table: `hashline/src/private_block/
norm_alias.rs` exists on BOTH sides with DIFFERENT content (main
`5dc36880…`, lane `6edd517c…`). It is a `#[cfg(test)]` module, pinned by
nothing, on no gate's list — but it is a real textual conflict for the
integrator to resolve, and the resolution is worth one look.

**The re-pin, as a table to paste.** For the 32 pinned paths: 28 are untouched
by this delta and keep their current pin of record (or second accepted digest)
unchanged; the four below move. The recommendation is the same form the
`zk.rs` move of 2026-09-20 took — **both digests kept**, the new one recorded
with its reason, since bundles already captured carry the old ones.

| # | path | pin of record today | add as accepted | reason to record |
|---|---|---|---|---|
| 1 | `zkp-core/src/rng.rs` | `0d4a99abbc424286de60ec4bfbe1084dc2ccaa2db8c5380e5f4594157ccea9eb` | `b9920aeb3a12c2fd45e7f50f701852086cdf8bf73530de4f7658d4b4c09c3b9f` | a `cfg`-gated read-only consumption accessor and four tests; production residue byte-identical; release artifact carries neither symbol |
| 2 | `zkp-core/src/transcript.rs` | `31ce3c9a…` (main) / `cc9752d0…` (lane base) | `b8a228d9b33f7dbf19cd631c7b9a08eb9465b56ab3c32ea40c06fee2416adad4` | the same, for the squeeze counter; **note the lane base already differs from main — the re-pin is against the integrator's tree, not against `29cba9a`** |
| 3 | `hashline/src/private_block/protocol.rs` | `d9455a10…` (main) / `ac412237…` (lane base) | `e0e617be617a548641cb33c8564cee86ee7d2af90f9c6487b5fb7af30113d45b` | five `#[cfg(test)]` statements in `check_opening_challenges` and an eleven-line doc comment; verdicts and draws unchanged, tested differentially |
| 4 | `hashline/src/private_block.rs` | `412a43f4…` (2nd accepted, main) / `b4aeb6ed…` (lane base) | `fa0daca6797501ec9fe9ad93a5b890c0fa72165fbdb21c6854d4eaddac47ec94` | two `#[cfg(test)] mod` declarations and a comment |
| 5 | `zkp-core/Cargo.toml` | **not pinned** | `90156d589336ce790a103f69c42aa5c2489c5c2b12e1c1ce12e3b7b1c1ea4891` | **recommended for the pin set** — finding P36-2 |
| 6 | `hashline/Cargo.toml` | **not pinned** | `5633d1e46fd1c0878751283bf722a5cdbfb565bdf414aa521d7c160d4276fb38` | **recommended for the pin set** — finding P36-2 |

A bundle captured after integration records the new digests for rows 1–4 (they
are all in `run_capture::SHARED_SOURCE_FILES`/`OWN_SOURCE_FILES`); rows 5 and 6
are in no capture list at all.

## 7. Findings

**P36-1 — the lane's own production-identity script does not watch one of the
four pinned files the delta moves. Severity: low (re-derived here; no defect).**
`z36-cfg-gate-proof.py` watches `rng.rs`, `transcript.rs` and `protocol.rs`.
`hashline/src/private_block.rs` is pinned, gains 11 lines, and is checked only
by eye. It is watched in §2 here and is clean. Two lesser points on the same
script: it hardcodes `ROOT = "/home/victor/wt-zk60-block125m"`, so the
committed evidence cannot be re-run in another checkout without editing it;
and it classifies added lines rather than comparing residues, so it would not
see a pre-existing line edited in place if the edit happened to be counted as
a deletion plus an addition inside a gate. Neither affects this delta.

**P36-2 — the two files that decide whether the observers can reach a
production build are pinned by nothing. Severity: medium (act at the re-pin).**
After this delta the answer to "can a release build compile
`ZkRng::consumed_bytes`?" lives in `zkp-core/Cargo.toml` (the feature must stay
out of `default`) and `hashline/Cargo.toml` (it must stay in
`[dev-dependencies]`). Neither is in `zk60_native_mask_commit.SOURCE_PINS` or
`PATH_PINS`, in `zk60_native_terminal_polys.SOURCE_PINS`, or in
`run_capture`'s 38-file capture list. A one-word edit in either — `default =
["test-observers"]`, or moving the line to `[dependencies]` — would put the
accessors into the production library and no gate, no capture bundle and no
pin would notice. **Recommendation: add both manifests to `PATH_PINS` at the
re-pin.** The ruling of 2026-09-20 23:57 — "the pin set is extended to every
file on the path" — was about Rust files; this delta makes two manifests
load-bearing for the first time.

**P36-3 — the production-identity claim depends on Cargo's feature resolver
version 2, which nothing in the tree asserts. Severity: medium (latent; act at
the re-pin).** Under resolver v1 a dev-dependency's features unify into the
NORMAL dependency graph, so `cargo build --release` of hashline would compile
`test-observers` into zkp-core and the accessors would be in the production
library — with every source file, every `cfg` gate and every pin unchanged.
This tree resolves v2, and that is confirmed here by the compiler (§2, the
release graph reports `features: []` and the artifact carries no symbol). But
it holds for one reason only: there is no workspace manifest at the repository
root, so hashline is its own workspace root and its `edition = "2021"` selects
resolver 2. `cargo metadata` reports no `resolver` key anywhere. **Adding a
virtual workspace root without `resolver = "2"`, or lowering hashline's
edition, would flip it silently.** The lane's own evidence cannot see this:
`cargo tree -e features,no-dev` removes the dev edge by construction and
prints the same thing under either resolver. Recommendations, in order of
cost: (a) the integrator adds `resolver = "2"` explicitly to
`hashline/Cargo.toml`; (b) the manifests are pinned (P36-2); (c) a test
asserts that `cargo metadata`'s release graph resolves zkp-core with an empty
feature set.

**P36-4 — the endpoint replica's fidelity test pins the half of the frozen
seam that draws, not the half that constructs. Severity: low (no defect
today; one line of test to close).** Finding S36-F2 says the two endpoint
generators are measured on a replica whose fidelity is a source fact. That
source fact is asserted of `private_seam::prepare_with_rng` and
`endpoint_g::prepare`. But the production path calls `private_seam::prepare`,
which is the function that CONSTRUCTS the generator and then forwards it: a
draw taken there, before the hand-off, would add stream bytes to the real
endpoint that the replica cannot see, and nothing in the delta would notice —
the endpoints' 6,144 draws are measured ONLY by the replica, so the accepted
statement's 327,052 would be wrong while every test stayed green. Today
`prepare` draws nothing; this pre-read adds the missing assertion
(`the_frozen_seams_own_prepare_constructs_the_generator_and_draws_nothing_
itself`, green), and recommends the lane adopt it.

**P36-5 — "measured" is exactly right for the byte total and loose for the
draw count. Severity: low (a label, not a number).** §9 item 11 says the
counts are "MEASURED by an accessor, not only counted". What the accessor
returns is stream BYTES. For the block generator the split into 320,908 field
draws and 8,192 salts is the closed form's, tied to the measurement only
through `bytes = 16·fp + 32·salts`. Because two field draws and one salt are
both 32 bytes, **a change that replaced two `fp()` draws by one salt would
keep every assertion in the module green while the true draw count moved from
327,052 to 327,050** — the residual 327,052·2⁻⁹⁶ would then be a hair
conservative, so nothing accepted becomes false, but the sentence "measured"
should read "measured as stream bytes, split by the counted schedule". For the
two ENDPOINT generators the split IS anchored: `measure_endpoint` compares its
closed form against the commitment's own `salts` and `pads` vectors. This is
finding S36-F3 seen from the value side, and the stage names S36-F3 honestly.

**P36-6 — a pinned file's comment miscounts the gated lines it describes.
Severity: informational.** `private_block.rs` says "`protocol.rs` gains four
`#[cfg(test)]` lines"; `protocol.rs`'s own doc says five, and five is right
(the `draw` shadow, `note_groups_passed`, and one note beside each of the
three exits). A comment in a pinned file that miscounts what it documents is
exactly what a source re-read is for.

**P36-7 — the identifier `draw_observer` appears in the release rlib's
metadata. Severity: informational (not a leak).** `libhashline.rlib` contains
the string `draw_observer` in its metadata identifier table, next to the
pre-existing `#[cfg(test)]` module names `tamper`, `s35_tests` and
`slot_ir_tests`. No function symbol and no occurrence in the release binary
`release/hashline`. Recorded so the next reader who greps an artifact does not
raise it as a finding.

## 8. Verdict

* **Production identity: established**, and more strongly than the lane
  claimed — residue-identical, not merely gate-covered, and extended to the
  fourth pinned file; with the compiler confirming the release artifact
  carries none of the added code, including through the dev-dependency edge.
* **Conditions 1, 2, 3, 5: unaffected.** **Condition 4 and §9 item 7: hold**,
  and the delta adds a second probe for the non-`Clone` property.
  **Condition 6 and §9 item 5: hold** — no generator is constructed by the
  observers and the three `from_os` sites are unchanged. **§9 items 6 and 8:
  unchanged**, item 6's owed domain separation still owed.
* **Condition 7: triggered**, for four pinned files plus two unpinned
  manifests that this pre-read recommends adding to the pin set.
* **The statement does not lapse on this delta.** Nothing here reopens §3's
  five steps, §4's residuals or §2's sentence. What is suspended is step 3 for
  the four changed files, until the security owner re-reads them in the
  integrator's tree and moves the pins — for which §6 is the arithmetic.
* **The strongest thing not established:** that the release binary is
  bit-identical before and after the delta. It would need a build of
  `fee1a8d`'s two crates, which this review's rules do not permit; §2 says
  what stands in its place and what that is worth.

### Evidence

All under `results/zk60_d22_preread_stage36/`: `p36-production-residue.{py,txt}`
(the residue re-derivation), `p36-threeway-digests.{py,txt}` and
`p36-divergence.{py,txt}` (the three-way pin table and who moved what),
`p36-merge-prediction.{py,txt}` (what a clean merge gives),
`p36-symbol-differential.txt` (the three release builds and the symbol counts),
`p36-gate.{sh,log,done}` (11 tests, 0 failed, exit 0) and
`p36-core-plain.{log,done}` (zkp-core's own 56 tests without the feature).
The reviewer's three tests are
`hashline/src/private_block/p36_preread_tests.rs`, review branch only.
