# Check of the G-R4 blinding-law draft

> **Independent adversarial check** of
> `docs/zkmatrix-poc/ZK60_BLINDING_LAW_GR4.md` (main tree, commit `0ae7d61`)
> and its evidence `results/zk60_blinding_law_gr4/`. Written by a delegated
> Opus checker on 2026-09-23 (`date` read at 16:14, 16:33, 16:34 and 16:37
> PDT; the mutation runs finished between the last two). **This is not a privacy acceptance of
> anything.** D22 is untouched. No run, development rung or 125M block is
> private because of this page or the draft.

**What was checked against.** The lane tip `2ea7221`, merged into this review
branch at `764eee6` (the only conflict was the `#[cfg(test)] mod` list of
`hashline/src/private_block.rs`, and both sides were kept). The review
branch changes no production line. The one production-adjacent difference
from `2ea7221` is a test-only `mod` in `zkp-core/src/pcs.rs:41-45`, which
moves that file's later lines down by 6. Citations below are at `2ea7221`
unless they say "review tree".

**Evidence** is in `results/zk60_blinding_law_gr4_check/`:

| File | What it is |
|---|---|
| `hashline/src/private_block/gr4_check_tests.rs` | The check's one test-only module: the **seeded value-level replay** (§2) |
| `a6-honest.log` | The lane's assertion-6 test on honest code (green) |
| `replay-honest.log` | The replay tests plus assertion 6 on honest code (5 of 5 green) |
| `mutation_runs.py`, `mutation_runs.out`, `mutation_runs.json`, `mut-m1.log`, `mut-m2.log`, `mut-m4.log` | m1, m2 and an `α` mutation m4, inserted into production source one at a time, run, then reverted |
| `order_and_exits_scan.py`, `.out` | An independent scan of every generator line on the path, plus the exits after the first draw (§4, §5) |
| `residuals_check.py`, `.out` | The residuals recomputed by counting preimages (§6) |
| `draft_scan_rerun.out`, `draft_law_rerun.out` | The draft's two scripts re-run: both exit 0, and the second's output is byte-identical to the draft's |

---

## 0. The answer in plain words

* **The draft's §5.7 finding is right, and the Rust test agrees with it.**
  The draft's two one-line mutations were inserted into `protocol.rs`:
  * m1 overwrites a random word of `A`'s proximity row;
  * m2 copies a random word of `A`'s reserved rows into `H`'s reserved rows.

  With either one in place, the lane's value-level test (assertion 6) is
  still green. The six-shape draw-count test is also still green, and the
  toy and rung-G receipts still **verify**. The machine assertion therefore
  does not see the blinding that the linear-channel arguments depend on.
* **A test-only closure now exists and works.** It is the draft's option
  (b), built in this review branch. `prove_core` runs on a seeded
  generator. The check then rebuilds `A`, `M` and `H` from the witness and
  the predicted stream segments, without calling the production commit
  functions, and requires the **three roots** to match. It passes on honest
  code at the toy and at rung-G, and for the run boundary. It fails on m1,
  on m2, and on an `α` mutation m4 inside `zk::mask_commit_tagged`.
* **One blocking correction to the statement itself (F-1).** LB-1 says the
  whole of `Ω` is independent of the public statement `P`. But `P` contains
  the two **endpoint roots**. They are the 112-byte `ExpectedIo`, absorbed
  first into the transcript, and each is a hash of an endpoint's drawn mask
  rows, pads and salts. So LB-1 is false as written for the endpoint
  blinding. There is also one refusal that reads those roots
  (`check_endpoints`), and the draft's inventory misses it. The fix is a
  restatement, not a code change (F-1).
* **No refusal after the block or run generator's first draw reads a drawn
  value.** The dependent-proximity refusal (`protocol.rs:305-310`) reads
  transcript **challenges** squeezed from a clone of the transcript
  (`:326-327`), not generator draws.
* **Order.** No draw sits under a loop whose trip count depends on hidden
  data. There are 17 draw lines on the path, and every enclosing bound is a
  shape, layout or spec constant, or the run's `k` and `L`. The replay also
  measures the order inside a block at the value level, at two shapes.
* **Residuals.** 2^-77.680839 (toy), 2^-72.864825 (125M proof) and
  2^-69.290633 (125M, `L = 12`). Recomputed exactly and confirmed; the D9
  reading is right.
* **Across proofs.** The million-proof figures need a named assumption the
  register does not carry yet. It is stated precisely in §7 (X-1). Without
  it, the failure is not a small term: two proofs on one key have
  identical blinding.

---

## 1. Findings, ranked

| # | Severity | Finding | Fix |
|---|---|---|---|
| F-1 | **blocking** (statement; not a code defect) | `P` carries the endpoint roots, so LB-1's "`Ω` independent of `(P, w, ρ)`" is false for the endpoint families; one refusal reads those roots | Restate LB over the root-free statement `P°`; route the roots through (H6); add the refusal to §5.1 (details below) |
| F-2 | **confirmed, blocking for claim 6's "MEASURED"** (the draft's own §5.7) | The lane's assertion 6 stays green under m1 and m2, and so do the count tests and verification | Adopt the replay test of §2, or its equivalent in a lane stage; correct the assertion-6 docstring (`s36_tests.rs:710-713`) |
| F-3 | erratum | "α" in §5.1's refusal table is the **LogUp challenge** `alpha` (`protocol.rs:1030`), not the CFS coefficients that the same letter names in `Ω` | Rename it (e.g. `α_LU`) wherever it is a challenge |
| F-4 | note | LB-real's `ε_M3` is one term, but a standalone proof has three generators and a run has three | Write `3·ε_M3`, or name a multi-instance M-3. Across `K` proofs this becomes `3K·ε_M3` |
| F-5 | note | The run exit inventory (§5.1, last row) is incomplete: the omitted exits are all public or shape checks, and one environment exit is a sink | List them, and name the sink's content-independence as a condition beside M-9 (§5) |
| F-6 | note | §3.2 "the owners are consumed by value and have no `Clone`" is true of `Endpoints`, `PreparedBoundary` and `MaskCommit`. But `CfsMask` is `#[derive(Clone)]` (`zkp-core/src/sumcheck.rs:188`) and is cloned into the masker (`zk.rs:1082`), and `CommittedZk`'s `data`, `pads` and `salts` are `pub` fields | Say "no reuse", which the replay now measures, rather than "no `Clone`" of drawn values in general |
| F-7 | note | E-1 is worded "made by **one process** within one proof". Endpoints sealed by another process (sealing in advance, D8/D11) fall outside it even inside one proof | Fold this into X-1 (§7) |
| F-8 | note | §5.4 says "nothing named" covers cross-proof independence. The toy memo does name the **condition**: `ZK60_JOINT_LAW_COMPOSITION.md` §6.3, row 29 ("cross-proof stream independence"). What is missing is a named **assumption** in the register | Wording only; §7 gives the assumption |

### F-1 in full

**What the draft says.** LB-1: `law(Ω | P, w, ρ) = Uniform(S_decl)`, "and
the whole of `Ω` is independent of `(P, w, ρ)`". The table in §1.2 puts the
endpoint rows, pads and salts into `Ω`. §2.2 step 4 argues independence
from the fact that no root enters a **key**. §3.3 and §5.1 say no refusal
reads a drawn value.

**What the code does.**

* `prepare_endpoints` builds the policy from the two owners' roots:
  `ExpectedIo::from_roots(spec, input.root(), output.root())`
  (`private_block.rs:1083`).
* Each root is the salted Merkle root of the endpoint's encoded columns,
  which include the drawn mask rows (`endpoint_g.rs:276-278`,
  `private_seam.rs:211-213`), the pads and the salts (`pcs.rs:777-778`).
* The policy is part of the statement. It is 112 bytes
  (`private_block.rs:357`), and it is absorbed first by both headers:
  `protocol.rs:116` for a block and `run.rs:436` for a run.
* The toy memo says the same: "their roots are part of the public
  statement" (`ZK60_JOINT_LAW_COMPOSITION.md:1579`). Its `P` includes "the
  112-byte policy" (§1.1).
* `check_endpoints` then compares the owners' roots with the statement's
  (`protocol.rs:761-762`). It runs in `prove_inner_at` (`:802`) and
  `prove_run` (`run.rs:715`), **after the endpoint generators have drawn**.

So `P` contains a deterministic function of `Ω_E`. Conditioned on the exact
root, `Ω_E` is confined to that root's preimages, which is not
`Uniform(S_decl)`. LB-1 is false as an exact statement, and the refusal at
`:762` reads a function of drawn values.

**Why it is not a leak.** For an honest caller, `(expected, owners)` come
from one `prepare_endpoints` call, so the refusal is a sure event.
Conditioning on the roots is harmless **in the random-oracle model**:
leaves are salted with fresh 256-bit salts, so a root is a function of the
opened values, the published salts and independent uniform values
(`ZK60_JOINT_LAW_COMPOSITION.md` §5.2, (H6)).

**Fix, wording only.**

1. State LB over `P°`, the statement without the two endpoint roots: the
   profile, the block or run digests, the IO spec, the parameters, the
   calibration and the schedule.
2. Treat the endpoint roots as part of the hash view, conditioned on in the
   (H6) hop.
3. List `protocol.rs:761-762` in §5.1 as "reads the endpoint roots (a hash
   of `Ω_E`); sure for an honest caller".

The same wrinkle sits upstream: the toy memo's (H5) takes `π ∋ B9`, the
endpoint blinding, as uniform under a fixed `P` that contains the endpoint
roots. That should be read as "via (H6)". This check flags it and does not
re-derive it.

---

## 2. Attack 1: m1 and m2 against the Rust, and a value-level check that catches them

### 2.1 The mutations, run on the Rust (`mutation_runs.py`)

Each mutation was inserted into production source in this worktree. The
lane's assertion-6 test, the lane's six-shape count test
(`a_block_proof_consumes_exactly_the_counted_stream_at_every_shape`) and the
replay were then run, and **the original bytes were written back in a
`finally`**. The driver ends by asserting `git diff --quiet` on both files.
Nothing mutated was committed.

| Mutation (production file) | Assertion 6 (`s36_tests.rs:727`) | Six-shape count test | Toy / rung-G receipt verifies | **Replay (this check)** |
|---|---|---|---|---|
| m1: `a_data[lay.a_prox * n] = Fp::ZERO;` after the `A` fill (`protocol.rs`, after `:1004`), the draft's line verbatim | **green** | **green** | **yes / yes** | **FAILS**: `A` root (and so `H`) |
| m2: `h_data[lay.h_mask_base * n] = a.data[lay.a_mask_base * n];` after the `H` fill (after `:1117`). In Rust `a_data` has already moved into `A`'s commitment, so the draft's port line reads `a.data` | **green** | **green** | **yes / yes** | **FAILS**: `H` root only (`A`, `M` equal) |
| m4: slot 1's first CFS coefficient := slot 0's, in `zk::mask_commit_tagged` (`let mut masks` at `zk.rs:485`, plus one line) | **green** | **green** | **yes / yes** | **FAILS**: `M` root (and so `H`) |

Afterwards the production files were restored: the driver's `git diff
--quiet` exited 0 (`mutation_runs.out`, last line), and `git diff --stat` on
`protocol.rs`, `zk.rs` and `zkp-core/src` is empty. The replay-stream byte
counts were unchanged under all three mutations (5,396,672 and 11,385,664):
a mutation that moves no count is exactly what a count cannot see.

**Verdict on §5.7: CONFIRMED independently, on the Rust.** The source scan
skips the `*x = rng.fp();` fill idiom (`s36_tests.rs:738, :755`), binds only
`let` names (`:897-906`), and cannot see `CfsMask::random(rng, ..)`. m1, m2
and m4 move no count, and the verifier accepts all three.

### 2.2 The strengthened check (`gr4_check_tests.rs`, test-only, review branch)

**How it works.**

1. **Prove.** `prove_core` takes its generator from the caller, so it is
   run on `ZkRng::new(SEED, DOMAIN)`, a public test seed, exactly as
   `measure_block` runs it. The receipt is then verified.
2. **Replay the stream.** A second generator on the same seed is cut into
   the eleven segments in the predicted order. The three matrices are
   rebuilt:
   * **`A`**: the witness rows, a restatement of `prove_core:954-1001`
     without the `cfg(test)` hook. Segment 1 goes row-major into rows
     `a_mask_base..a_rows`. Pads come from segment 2 and salts from
     segment 3.
   * **`M`**: every word, since `M` holds no data. The 23 `α` vectors come
     first, then 2 × 23 × 256 pads, then `b_re`, `b_im`, `u_re` and `u_im`
     with only `b[m] := −b[0]`, then 4,096 salts.
   * **`H`**: the LogUp rows use `β`, `γ` and `α_LU`, replayed on the
     header transcript after the rebuilt `A` and `M` roots. Segment 8 goes
     into rows `h_mask_base..h_rows`. Segment 9 fills the two zero-sum rows
     with the declared closing entry. Pads and salts follow.
3. **Encode and hash independently.** The encoding and hashing use
   `pcs::encode_row_zk`, `hash_columns_keyed`, `salt_leaf_keyed` and
   `MerkleTree::build_keyed`, **not** `commit_zk_owned_tagged` or
   `mask_commit_tagged`. A relation imposed inside those two functions is
   therefore caught too.
4. **Assert.** The three rebuilt roots must equal the prover's, and the
   replay must end at the prover's `consumed_bytes`.

**What it proves, and with what assumption.** Under collision resistance
of the column, leaf and node hashes, root equality means every committed
word of `A`, `M` and `H`, and every drawn word among them, sits at its
predicted coordinate with its predicted value. The predicted map sends each
stream word to exactly one coordinate, or, for `b[m]`, to the declared
discard. So the committed blinding is an **injective image of the stream
modulo the three declared relations**, with the reserved pairs, the
proximity rows and `α` included. A copy, an overwrite, a reordering or a
skipped draw anywhere in the eleven segments moves a root.

**It also measures the order inside a block** at the value level. That is
J-5's assertion 2 and S36-F3, previously "measured nowhere".

**Honest runs** (`replay-honest.log`; 5 of 5 green, 1.3 s):

| Shape | Receipt verifies | `A` / `M` / `H` roots rebuilt | Stream bytes (replay = prover) |
|---|---|---|---|
| toy | yes | all three equal | **5,396,672**. This is claim A-5's figure: 320,908 × 16 + 8,192 × 32 |
| rung-G (tagged, generalised endpoints) | yes | all three equal | **11,385,664** = 687,028 × 16 + 12,288 × 32. This is stage 46's count |
| run boundary `B_k`, rung-G spec, legacy and rung-G tags | — | root equal under both tags | **270,336** = 8,704 × 16 + 4,096 × 32 |

**Endpoints, in situ.** The two endpoint generators build their own
`from_os` stream and cannot be seeded without a production change. For
them, the test checks on the **real** owners that no drawn value repeats
within or across the two owners. The toy has 6,144 field values and 4,096
salts, and rung-G has 14,848 and 8,192; all are distinct. This check sees a
copy but not the order. The counts equal 2 × 3,072 and 2 × 7,424, stage
36/46's endpoint counts.

**Non-vacuity, on every run.** Three deliberate errors in the prediction
(the analogues of m1, m2 and the `α` mutation) each move exactly their
root, at both shapes.

**Limits.**

* Uses of drawn values outside the three commitments are bound by the
  verifier, not by this test. These are the slot argument's reads of `α`
  and of the reserved pairs through `mask_eval`.
* `prove_run`'s stage loop is not replayed.
* The frozen seam's `prepare_with_rng` is private, so the toy endpoints get
  only the in-situ check.

**Proposed for the lane.** Adopt `gr4_check_tests.rs`, or an equivalent, as
the value-level half of J-5's assertion 6. Keep the source scan as a
tripwire. A small follow-up would give the replay the endpoints too: a
`cfg(test)` seeded entry to `endpoint_g::prepare`, the one line the draft
calls `prepare_with_rng`. That also closes S36-F2.

---

## 3. Attack 2: refusal exits after the first draw

`order_and_exits_scan.py` §C lists every `?`, `return Err`, `assert`,
`expect` and `unwrap` in the four prover entry points after their first
draw, and in every function they call after it. Each is classified below by
what it reads:

| Exit (at `2ea7221`) | Reads | Reads a generator draw? |
|---|---|---|
| `prove_core:1052, 1053` (helper inverses) and `:1060, 1062, 1092` (`inverses`, `:589-591`) | `w`, the public tables, the LogUp challenges `β, γ, α_LU` | no (F-3: this `α` is a challenge) |
| `:1140` into `run_slot`: `argument.rs:451, 454, 463, 497` (schedule and table shape), `:481` (`c = 0`), `:590` (`e ∈ {0,1}`), and `nonzero` (`:951-956`) | shape, challenges | no |
| `:1153, 1157` into `check_opening`: `audit_claims` (`:230-274`) reads claim **coefficients** `coef·cd` and `cm·u` (`argument.rs:381, 384`), which are products of challenges and slot constants; `opening_groups_at` (`:200-213`) reads claim structure; the group count; `check_opening_challenges` (`:293-314`) | challenges, positions | no |
| **the dependent-proximity refusal `:305-310`** | `rho` drawn by `replay.challenge_fp2()` from `Transcript::clone_state(tr)` (`:326-327`): **Fiat–Shamir challenges**, never `ZkRng` | **no**. In the Fiat–Shamir world `rho` is a hash of a transcript that absorbed roots, which is G-R5's hop, as the draft says in §5.10 |
| `masked_prove`/`extension` asserts (`zk.rs:1081, 1093-1097`); `CfsMask::round` / `mask_round` asserts (`sumcheck.rs:256, 287`); `assert_mask_sites` (`pcs.rs:994-1000`); `open_zk` `unwrap`/`expect` (`:1031, :1047`, device gather) | challenges, lengths, environment | no |
| `prove_inner_at:820, 824` (`check_endpoint_opening`, `:376-390`) | challenges, schedule | no |
| **`prove_inner_at:802` → `check_endpoints` (`:761-762`)**, and the same in `run.rs:715` | the **endpoint roots**, a hash of the endpoint draws | **yes, through a hash. F-1**. It precedes the block generator but follows the endpoint generators |
| run: `:731, 751, 752, 754, 756` (via `boundary.rs:339-341`, before its draws), `:763, 764, 768, 772, 782` (`into_opening`: spec digest plus `check_opening`), `:785-794`, `:816` (`seg_geom`, `encode_segment` → `validate_segment`, `wire.rs:343-372`: lengths only) | public spec, shape, `w`, challenges | no |
| run: `sink(k, bytes)?` (`:820`) | the **bytes of a finished segment**, a function of `Ω` | only if the sink's failure depends on content. `DirSink` and `MemorySink` fail only on I/O. F-5: name it |
| `prepare_endpoints:1076` (the output endpoint, after the input endpoint drew) | lengths, canonicity, entropy failure | no, and nothing is published |

**Verdict.** No exit after the **block or run** generator's first draw reads
a value that generator drew. The only refusal that reads anything drawn is
F-1's endpoint-root comparison. Its event is sure for an honest caller, so
LB-2's conditioning is on `NR(ρ)` together with an event of probability 1.
LB-2's claim that every refusal is an event of `(P, w, ρ)` holds with `P`
read as the full statement (roots included). That is exactly why LB-1 has
to be stated over `P°` and bridged by (H6).

---

## 4. Attack 3: order

`order_and_exits_scan.py` §A starts from the other end from the draft's scan.
It takes **every** production line on the path that names `rng` or `ZkRng`,
across 21 files. It classifies each line as a construction, a draw, a
pass-through or a parameter, and fails on any unclassified line. It excludes
only named generator functions that are off the path, and asserts that none
is called from a private-block file:

* the FFN line;
* the untagged `zk::mask_commit`, used by the seam prover;
* `commit_zk_device`;
* `private_seam::prove`.

**Result.**

* **17 draw lines.** In protocol.rs: `:1003, 1116, 1121`. Then
  `boundary.rs:347` and `endpoint_g.rs:277`. In zk.rs: `:496, 503, 504,
  507, 508, 513`. Then `private_seam.rs:212`. In pcs.rs: `:724, 725, 777,
  778`. Finally `sumcheck.rs:202`.
* **Every enclosing bound is public.** Each is one of: `lay.a_mask_base`,
  `lay.h_mask_base`, `lay.h_u_rows()`, `n − 1`, `first_mask = spec.
  data_rows()`, the 23 slot specs, `[re, im]`, `MASK_Q`, `2m`, `dom`,
  `rows·q` (`rows = data.len()/n`, a layout constant), `nn`,
  `CfsMask::len(n_vars, degree)`, or the run's `for k in 0..l` and
  `if k + 1 < l`.
* **No draw sits under an `if`, `match`, `while`, `loop` or `else` on
  anything else.**
* There are no LogUp-multiplicity or sparse-row loops around a draw.
  Multiplicities are **values** written into `A`.
* The generator never reaches the slot argument, the masked sumcheck, an
  opening, a refusal check, the wire encoder, the transcript or a verifier
  (§B of the scan).

An early exit only truncates an attempt, and a truncated attempt publishes
nothing (D21). A refused run leaves up to `k` finished segments (R-1), and
their draws precede the exit.

**Verdict: CONFIRMED independently.** ORDER and NUMBER are functions of
`(shape, L, k)`. Inside a block this is now also **measured** by the
replay, at two shapes (§2.2).

---

## 5. What the missing run exits are (F-5)

The rows missing from the draft's run row are: `st.transcript()?` (`:731`),
`st.boundary_spec(k)?` (`:751`), the plane-length refusal (`:754`),
`st.stage_layout(k)?` (`:763`), the consumed-endpoint `ok_or`s (`:768, 772,
785, 793`), the two `check_endpoint_opening`s (`:786, 794`), and
`st.seg_geom(k)?` plus `wire::encode_segment` (`:816`). All are public,
shape or challenge events, so the conclusion is unchanged.

The sink is the only exit that receives `Ω`-dependent bytes. The condition
"a sink's failure does not depend on the bytes it is given" belongs beside
M-9.

---

## 6. Attack 4: the three residuals (`residuals_check.py`)

**The per-draw distance, counted directly.** The distance was computed by
counting preimages, not from the closed form. `2^128 = kp + r` with
`r = p − 2^32`: residues `0..r−1` have `k + 1` preimages and the rest have
`k`. The mass above uniform equals the mass below, which gives
`δ = r(p−r)/(p·2^128) = (1 − 2^32/p)·2^-96 = 2^-96.0000000003`. The closed
form matches exactly.

**The relative bias of a single outcome is `1/k = 2^-64`.** That is the
`rng.rs:72` comment, and it is not a distance. D9's verification note reads
it the same way (per-draw distance 2^-96, summed), so the draft's use of D9
is right.

**Salts** are four raw words with no reduction, so they carry no D9 term.

| Object | N (fp draws) | log2(N·δ) | Quoted |
|---|---:|---:|---|
| toy proof (block 320,908 + 2 × 3,072) | 327,052 | **−77.680839** | 2^-77.68 ✓ |
| 125M standalone (9,029,804 + 2 × 91,392) | 9,212,588 | **−72.864825** | 2^-72.86 ✓ |
| 125M run, `L = 12` (12 × 9,029,804 + 11 × 108,032 + 2 × 91,392) | 109,728,784 | **−69.290633** | 2^-69.29 ✓ |

**Recounts from geometry.** The 125M endpoint is 5 × 2^14 + 37 × 256 =
91,392 and the boundary is 6 × 2^14 + 38 × 256 = 108,032; both are
asserted. The toy and rung-G block counts are **measured again** by the
replay, from its stream bytes. The 125M block count was not re-measured,
because the brief allows no 125M prove.

**Many proofs.** Over `K` proofs: 10^6 toy proofs give 2^-57.75, 10^6 125M
proofs give 2^-52.93, and 10^6 125M `L = 12` runs give 2^-49.36. All hold
**only under X-1**.

**The bound's shape.** `TV(Ω_real, Ω_ideal) ≤ N·δ` is sub-additivity over
the independent reduced draws, followed by data processing. It is right,
**after** the generator hop has made the 128-bit integers uniform (F-4
covers the multiplicity of that hop).

**Verdict: CONFIRMED independently**, including the D9 reading.

---

## 7. Attack 5: independence across proofs (the assumption the million-proof figures need)

The figure `K·N·δ` over `K` proofs is a hybrid over proofs. It needs the
`K` proofs' blinding vectors to be (close to) **independent** uniform
vectors. Each proof's own guarantees (E-1 within a proof, and M-3) do not
give that. Stated precisely:

> **X-1 (cross-proof generator independence), proposed.** For every
> deployment and every sequence of proof attempts, in any number of
> processes and hosts:
>
> **(a)** the 32-byte `/dev/urandom` reads behind **every**
> `ZkRng::from_os` call (`rng.rs:30-51`) are mutually independent and
> uniform. In particular, no read is ever returned to two generators, which
> rules out a VM snapshot restore, a container checkpoint and restore, a
> `fork()` after a key was derived, and reads from a pool that has not been
> initialised;
>
> **(b)** the streams of all generators, under keys so derived, are jointly
> indistinguishable from independent uniform byte strings. This is a
> multi-instance M-3, with advantage at most `G·ε_M3` for `G` generators
> by a hybrid, `G = 3K` for `K` standalone proofs;
>
> **(c)** the hidden input of attempt `i`, and its endpoint values, are
> fixed before attempt `i`'s generators are created. They may depend on
> the receipts of earlier attempts, since `Ω_i` is fresh. For a run this is
> R-2's condition 2 applied per run;
>
> **(d)** refused attempts publish nothing (D21, M-9, HB-1), so the hybrid
> ranges over published attempts only.

Under X-1, `K` proofs are within `K·N·δ + 3K·ε_M3 + ε_X1(a)` of the ideal,
plus each proof's own refusal and hash terms.

**Without X-1(a), the failure is not a small term.** The seed domains are
identical for two proofs of the same profile (`hash_domain.rs:177-262`).
One repeated read therefore gives two proofs **the same key, and so the same
`Ω`**. The difference of two receipts' masked values is then the difference
of the hidden data, and the adversary's advantage is up to 1. This makes it
a deployment hazard to list beside D21's operating rules. It is not a
residual to sum.

**Structural mitigation**, for the lane to weigh; not proposed as a ruling.
Hedge the key with a public per-attempt nonce, such as a process-unique
counter or the statement digest `P°`. Then a repeated read gives distinct
keys for distinct attempts, under the PRF property of keyed BLAKE3. The
capture rule (`hash_domain.rs:161-167`) forbids witness values and roots in
a key. That is why the nonce must be public and root-free.

---

## 8. Verdict per claim (the draft's §6 table)

| # | Draft's claim | Verdict |
|---|---|---|
| 1 | LB implies (H5), (H5^run), R.1(ii)/O-2 and JS(a) | **CONFIRMED-WEAKLY**. The implication is immediate, but LB-1 must first be restated over `P°` and bridged by (H6) (F-1) |
| 2 | Generators uniform and reads independent | **UNVERIFIABLE** (ASSUMED). See F-4 (multiplicity) and F-7 (E-1's "one process") |
| 3 | Order and number are functions of `(shape, L, k)` | **CONFIRMED independently** (§4). Inside a block this is also MEASURED at the toy and rung-G by the replay |
| 4 | Each stream word returned at most once; owners not `Clone` | **CONFIRMED** for the generator (`rng.rs:9-100` read). The owner wording needs F-6 |
| 5 | No refusal or branch reads a drawn value | **REFUTED as worded** (F-1: `check_endpoints` reads the endpoint roots). **CONFIRMED** for every exit after the block or run generator's first draw (§3) |
| 6 | The declared relations are the only ones; measured only for pads, salts, `b`, `u` | The gap is **CONFIRMED on the Rust** (F-2). The value-level claim for `A`, `M`, `H` and the boundary is now **CONFIRMED independently** by the replay at two shapes; for the endpoints, only in-situ distinctness |
| 7 | Draw totals per generator | **CONFIRMED independently** at the toy (5,396,672 B), rung-G (11,385,664 B), the boundary (270,336 B) and the endpoint objects. 125M not re-measured |
| 8 | The total does not depend on the witness | **CONFIRMED-WEAKLY**. The replay's prediction is witness-free and equals the prover at one witness per shape. The three-pair toy measurement was not re-run |
| 9 | Coarse run-level order; openings draw nothing | **UNVERIFIABLE here**. `prove_run` not replayed; the scan's §B shows no opening takes a generator |
| 10 | The residuals | **CONFIRMED independently** (§6) |
| 11 | Order inside a block OPEN as a measurement | **Closed at two shapes** by the replay (value level); still ARGUED at 125M |
| 12 | Value-level injectivity for the reserved rows and `α` OPEN | Gap **CONFIRMED** on the Rust (m1, m2, m4). Closure offered (§2.2) |
| 13 | Cross-proof independence OPEN | **CONFIRMED** as a gap. X-1 stated (§7); F-8 on wording |
| 14 | The run's input fixed before its stream | Not checked (an operating condition; `run.rs:555-565`'s argument not re-derived) |
| 15 | Refused attempts never published | Not checked (operating rules) |
| 16 | S36-F2 immaterial to the law | **CONFIRMED**. The in-situ distinctness check adds a value-level observation; the byte counter is still unobserved |

The draft's §2.3 exact models: `law_and_residual.py` re-run, output
byte-identical. The idealised claim that an input-chosen but injective
**order** leaves the law unchanged is right: it is a re-indexing of an
i.i.d. uniform vector. The load-bearing facts are injectivity, now
measured, and no branch on a drawn value (§3).

---

## 9. What this check did NOT do

* No 125M prove, and no prove of a run. `prove_run`'s interleave and the
  `11L + 3(L−1)` offsets were not replayed.
* No seeded replay of the two endpoint generators (a production change
  would be needed); only the in-situ distinctness check.
* The GPU path (D22's scope is the CPU path) and the device commit.
* The Fiat–Shamir and ROM hops (G-R5, (H6)), timing, memory and power.
* The upstream toy memo's (H5)/(H6) interplay under F-1 was flagged, not
  re-derived.
* m3, the draft's control that assertion 6 does flag, was not re-run on the
  Rust. The lane test's own non-vacuity asserts stand in for it.
* R-2 condition 2 (the adaptive run source) and the operating rules D21,
  M-9 and HB-1.

**Not a privacy acceptance.**
