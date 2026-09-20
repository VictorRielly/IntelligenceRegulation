# Independent adversarial check of `ZK60_HASH_LAYER_AND_FS_LIFT.md`

**INDEPENDENT ADVERSARIAL CHECK of a delegated draft argument — delegated Opus
agent, 2026-09-20. Paper and Python only; NOT a privacy acceptance.**

| | |
|---|---|
| What was checked | `docs/zkmatrix-poc/ZK60_HASH_LAYER_AND_FS_LIFT.md` (1,298 lines, committed at `6d6c659`) and `results/zk60_hash_layer_fs_lift/hash_layer_counts.py` |
| Method | every number recomputed from the source lines by my own script (`results/zk60_hash_layer_fs_lift_check/recount.py`), never from the draft's script; every code claim re-read at the line |
| What I ran | one Python script. **No cargo, no binary, no proof, no Rust test, no benchmark.** No capture, witness, salt or private plane was read or copied |
| Labels I use | **VERIFIED IN THE CODE** (file:line I read myself), **RECOMPUTED** (my script), **MY OWN ARGUMENT** (labelled as mine, not a proof the project may quote as its own), **COULD NOT VERIFY** |
| What this is not | an acceptance of the draft, of Lemma H, of the lift, or of any privacy property. It does not rule on D19. It says nothing about D8 or D11 |

**How to read this.** §0 is the verdict in plain words. §§1–10 are the ten
attacks, each ending in a verdict. §11 says what I could not check. **§12 is
the only section an implementer needs**: four numbered BLOCKING items,
thirteen corrections, seven omitted conditions, and a short list of what I
confirmed and would not want lost.

## 0. Verdict in plain words

The draft is **substantially right and unusually well-sourced — and it is not
yet acceptable as written.** I set out to break it and could not break its
core: every one of the nine numbers in its final sum reproduces exactly from
my own script written off the source lines, including the one constant the
draft hard-codes without a derivation (327,052 field draws — I rebuilt it
call site by call site and got 327,052 on the nose); its recount of the
disputed collision term is right and the `2^-243` in four other documents is
wrong; its central move — that what the hash layer owes is the *conditional*
law of the digests given the field view, not a second marginal — is the
correct move and it is carried out correctly; and its bound really does rest
on the 256-bit salt alone and never smuggles in "the column is hard to
guess". The honest headline stands: **the hash layer is not where the privacy
budget goes** (2^-114.0 even against 2^128 oracle queries, against a sampler
term of 2^-77.7 that has nothing to do with hashing).

Four things block acceptance. (1) The hybrid it recommends carrying (Route A)
**omits a hop**: it applies a theorem stated "in the uniform-blinding
idealisation" to the real prover without ever making the replacement, so as
written the derivation does not reach its conclusion — the fix is one
paragraph and the price, 2^-77.7, is already in its own table. (2) The
statement that the 40-byte oracle-query class is "occupied by nothing else"
is **false of the crate** — two `Transcript::new` domains hash to exactly 40
untagged bytes — though true of the toy-block path, so the row must be
rescoped and demoted. (3) It prints a refusal rate of 2^-62.0 as a fact about
this block when the privacy case it cites says in terms that this number
**has never been counted for this shape and is OPEN** (I counted it myself: 4
determinant checks over `Fp`, ≈ 2^-62.0 — so the figure survives, but by a
derivation the draft does not give). (4) It repeats that Theorem 3.3's
terminals step is "**reviewed by nobody**"; that was true at 03:23 and false
by 03:49, and worse, the three conditions that review *added* to Theorem 3.3
do not travel with this page. None of the four is a hole in the mathematics.
**Nothing here establishes a privacy property, and nothing here touches D8 or
D11.**

## 1. Attack 1 — the final statement and its sum

### 1.1 Every term, recomputed

**Prediction before computing.** From the geometry alone I expected
12,288 encoded columns and 12,283 internal nodes, so a salt-guessing
coefficient of `2^13.585` and an overlap coefficient of `2^14.585`; I
expected `C(12288,2) ≈ 2^26.17`; and I expected the sum at `q = 2^128` to be
dominated by 2^-77.7 with a relative perturbation near `2^-34`, i.e. agreeing
with 2^-77.7 to far more than four figures. All three predictions held.

**RECOMPUTED** by `results/zk60_hash_layer_fs_lift_check/recount.py`
(independent of the draft's script; integer and `Fraction` arithmetic, `log2`
for display only). Output in `recount.json`.

| term in ε(q) | draft | my recomputation | verdict |
|---|---|---|---|
| sampler bias (D9) | 2^-77.7 | 327,052 × 2^-96 = **2^-77.681**, rounded up to 2^-77.7 | **agree** (conservative rounding) |
| LogUp-collision refusal | 2^-112.0 | 64,768 / 2^128 = **2^-112.017** | **agree** |
| salt guessing | `q·2^-242.42` | 12,288 × 2^-256 = `q·`**2^-242.4150** | **agree** |
| leaf-input collision | 2^-229.83 | C(12288,2) × 2^-256 = **2^-229.8302** | **agree** |
| 64-byte absorb overlap | 2^-241.42 | 24,571 × 2^-256 = **2^-241.4153** | **agree** (and see §2.4: `2^-243` is the wrong figure) |
| challenge pre-query (B3) | `q·2^-244.03` | 4,000 × 2^-256 = `q·`**2^-244.0342** | **agree** (on the draft's own *bound* of 4,000) |
| absorb-input collision (B4) | 2^-233.07 | C(4000,2) × 2^-256 = **2^-233.0688** | **agree** |
| generator | `3q·2^-256 = q·2^-254.42` | `q·`**2^-254.4150** | **agree on the arithmetic; the term is incomplete** — see §3.4 (a second route, guessing the 32-byte OS entropy, gives `6q·2^-256 = q·2^-253.42`) |
| `Δ_gr` | 0 on the accepted route | not re-derived | **RELIES ON**, unchecked here |

**Two terms I checked that the draft states without deriving.**

* **`fp()` bias per draw.** Exactly `b(p−b)/(p·2^128)` with
  `b = 2^128 mod p = p − 2^32`, i.e. `(2^64−2^33+1)·2^32 / ((2^64−2^32+1)·2^128)`
  — **2^-96 to twelve places, and strictly below it**. The draft's "exactly
  2^-96" is right and conservative. **RECOMPUTED.**
* **The 327,052 draws.** The draft and its script hard-code this number with
  no derivation. I rebuilt it from the call sites: `A` mask+prox rows
  `(455−213)·256 = 61,952`; `A` pads `455·256 = 116,480`; the 23 CFS masks
  `2 × Σ((n+e)·d + 2) = 2 × 583 = 1,166` (`layout.rs:438-462` SLOTS,
  `sumcheck.rs:197-203`); `M` row pads `23·2·256 = 11,776`; `M`'s
  `b_re,b_im,u_re,u_im` `4·1024 = 4,096`; `H` mask+prox rows
  `(384−280)·256 = 26,624`; `H`'s two zero-sum rows `2·255 = 510`; `H` pads
  `384·256 = 98,304`; two endpoints `2·((7−2)·256 + 7·256) = 6,144`.
  **Total 327,052 — exact agreement.** [RECOMPUTED; MY OWN ARGUMENT for the
  site list.] This is the strongest single confirmation in this check: a
  number nobody had sourced turns out to be right to the unit.

### 1.2 The sum, and whether anything of the form `q·2^-k` hides near `k = 128`

**RECOMPUTED.** The `q`-linear terms are exactly three: `q·2^-242.415`
(salt), `q·2^-244.034` (pre-query) and `q·2^-254.415` (generator). At
`q = 2^128` they are `2^-114.415`, `2^-116.034` and `2^-126.415`. **There is
no other `q`-dependent term anywhere in the page**, and in particular none
with an exponent near 128: I searched the draft for every `q·` and every
`3q`, and checked each against a coefficient I recomputed. The claim "**equal
to 2^-77.7 to four figures for every `q` up to 2^128**" is **true and
badly understated**: my exact sum at `q = 2^128` is

```
ε(2^128) = 2^-77.699999999915      (sum/2^-77.7 − 1 = 5.9 × 10^-11)
```

so it agrees with 2^-77.7 to **eleven** significant figures, not four.

**One numerical correction.** §3.2's closing display gives
`ε_lift(q) ≈ 2^-228.9 / 2^-192.4 / 2^-162.4 / 2^-114.4` at
`q = 2^12 / 2^50 / 2^80 / 2^128`. Those are the *salt term alone*. Summing
B3, B4, B5 and `Pr[B_H]` as `ε_lift` is defined gives **2^-228.837 /
2^-192.008 / 2^-162.008 / 2^-114.008**. The row `Pr[B_H]` in §2.4 *is* right
(2^-192.4 / 2^-162.4 / 2^-114.4); it is `ε_lift` that was copied from it.
§5.2's prose "the hash-layer terms together are below 2^-114 even at
`q = 2^128`" survives — but by 0.6 %, not by the factor of 1.3 the draft
thinks it has. **CORRECTION C-2.**

### 1.3 Is "the whole view" really everything?

**VERIFIED IN THE CODE**, item by item, against what actually leaves the
process:

| object | in the draft's §5.2 sentence? | my reading |
|---|---|---|
| the 112-byte `ExpectedIo` policy, incl. the two endpoint roots | yes | correct: `EXPECTED_BYTES = 8+32+4+4+2·32 = 112` (`private_block.rs:146`), absorbed at `protocol.rs:31` |
| the receipt: `MAGIC(8) ‖ binding(32) ‖ 3 roots ‖ slots ‖ 4+1 openings` | yes | correct and **complete**: `wire.rs:71-99`. The 32-byte `binding` is the transcript state after the header, a function of public data only (`private_block.rs:452`) — I re-read this because a 32-byte digest in a frame is exactly where a hash object hides |
| the event of refusal | yes | correct |
| the **refusal string** | **no** — declared a GAP in §4 | the strings are data-dependent and real: `witness.rs:80` `"fixed oracle range refusal: {site}"`, `:271` `"causal maximum attainment"`, `:287` `"softmax denominator"`. See §7 |
| `ProveStats` (phase **timings**, `transcript_order`, three lookup counts) | no | returned by `prove_with_stats` (`private_block.rs:414-423`, `protocol.rs:411-419`). The three lookup counts are shape constants (`m_u8.iter().sum()` is the number of lookup *values*, not of hits) — **not a leak**; the timings are D20 |
| a retained capture | mentioned in §1.1 | writes exactly `receipt`, `expected`, `json` (`native_capture.rs:267-281`) — inside the sentence's list |

**Verdict on attack 1: the sum is right, the headline is right and
understated, one display line of `ε_lift` is wrong, and the word "whole"
needs its exclusions written inline.**

## 2. Attack 2 — the hash layer from the code, and the length-class table

### 2.1 The leaf, the salt, and when it is drawn

Every one of these I read myself at the line. **VERIFIED IN THE CODE.**

* **The leaf is `blake3( blake3(column bytes) ‖ salt )`.** Inner:
  `hash_column` (`zkp-core/src/pcs.rs:137-143`) — one `update` over the
  column's little-endian bytes, **no tag, no length prefix**; the tiled form
  `hash_columns` (`:147-166`) builds the identical byte string per column;
  the `M` copy is `pcs_hash_column` (`hashline/src/zk.rs:592-595`).
  Outer: `salt_leaf` (`pcs.rs:640-645`) — `h.update(leaf); h.update(salt)`,
  **64 untagged bytes**. Draft correct.
* **The salt is 32 bytes**, `ZkRng::bytes32()` = four `next_u64`
  (`rng.rs:93-99`), so it is **raw stream output, not reduced mod p** —
  which is why the salts carry no `fp()` bias. The draft does not say this;
  it is a point in its favour.
* **One salt per ENCODED column, drawn AFTER that commitment's pads.**
  `commit_zk_owned_with`: `let pads = rng.fp_vec(rows * q);` then
  `let salts: Vec<[u8;32]> = (0..nn).map(|_| rng.bytes32()).collect();`
  (`pcs.rs:672-674`). `mask_commit` the same with `dom = 4096`
  (`zk.rs:462`). Draft correct, and the ordering it flags is real: `A`'s
  2,048 salts are drawn **before** `H`'s pads on the same stream
  (`protocol.rs:275` is the only stream for the block).
* **A receipt publishes salts only for opened columns.** `open_zk` gathers
  `(j, col, cmz.salts[j], tree.path(j))` over the *sampled* indices only
  (`pcs.rs:928-941`); `mask_open` the same (`zk.rs:543-548`). There is no
  code path that emits `cmz.salts` wholesale. **C-H1 confirmed.**
* **Counts.** 2,048·4 + 4,096 = **12,288 salts drawn**; 5 × 256 = **1,280
  published slots**, ≈ 1,211 distinct; ≈ **8,755 of 24,571** nodes revealed.
  All **RECOMPUTED** and identical to the draft's script to the displayed
  digit, and the four 2,048-leaf rows reproduce `ZK60_D8_D11_RESTATEMENT.md`
  §3.3 (240.7 / 453.2 / 212.5 / 1,200.6 / 1,654.8 / 40.4 %).
* **Row counts.** `A` 455, `H` 384 (`layout.rs:590-591`, test `:703-704`);
  `M` `2·23+4 = 50` (`layout.rs:519`, test `:708`); endpoints
  `ENDPOINT_ROWS = 7` (`protocol.rs:187`). All **VERIFIED**.

### 2.2 Is any other published object a function of an unopened column or an unpublished salt?

I redid the source reading the draft's open question 3 asks for, and widened
it. **VERIFIED IN THE CODE: no.**

`OpeningZk::write_bytes` (`pcs.rs:582-601`) emits group vectors, the
proximity vector, and per column `(index, values, salt, path)`.
`MaskOpening::write_bytes` (`zk.rs:551-561`) the same shape.
`wire::encode` (`wire.rs:71-99`) adds only `MAGIC`, the public `binding`, the
three roots and the slot payload. `ExpectedIo::to_bytes`
(`private_block.rs:336-345`) is `"HBLKEXP1" ‖ context ‖ two i32 scales ‖ two
roots` = 112. `ProveStats` carries no digest. The capture writes those three
files and nothing else. **The one object I checked that the draft does not
mention** is `pcs::last_mask_sites()` (`pcs.rs:880-905`), a thread-local of
human-readable strings recording which **mask rows** each group touches — it
is a function of the layout and the challenges, not of any column or salt,
and the block path never writes it to a receipt or a capture. Not a leak.

**The unsalted inner digest `blake3(column)` is never published**, in a
receipt, a capture, a log line or an error string: the only consumers of
`hash_column`/`hash_columns` are `commit_zk_owned_with` (feeds `salt_leaf`)
and `verify_zk`/`mask_verify` (recomputes it from a **published** column).
That closes the draft's §2.3 Step 2 sub-question about confirming a column
guess without a salt: the only published object that depends on an unopened
column is its salted leaf, and that needs the salt.

### 2.3 My own length-class table, against the draft's

I enumerated every `blake3::` call site reachable from the toy-block profile
(`grep` over `zkp-core/src` and the block's modules) and derived each input
length arithmetically. **RECOMPUTED** (`recount.json`, `lengths`).

| bytes | class | site |
|---:|---|---|
| 30 | `calibration_identity` (a constant) | `private_block.rs:95` |
| **40** | **RNG refill** `key(32) ‖ le64(counter)` | `rng.rs:53-56` |
| **40** | **`Transcript::new(b"experimental-private-seam/v1")`** — `12 + 28` | `private_seam.rs:26`, `:245` |
| **40** | **`Transcript::new(b"zk60-public-block-receipt-v1")`** — `12 + 28` | `public_block_receipt.rs:20`, `:178` |
| **47** | challenge squeeze `state(32) ‖ "squeeze"(7) ‖ le64(8)` | `transcript.rs:85-89` |
| 50 | RNG key derivation, seam (**keyed mode**) | `rng.rs:47-49` |
| 51 | `Transcript::new(PROFILE)` — `12 + 39` | `transcript.rs:25-28` |
| 56 | `hash_column`, endpoint (7 rows) | `pcs.rs:137` |
| 60 | absorb `b"rows"` — the shortest absorb on this path | `transcript.rs:44-50` |
| 61 | RNG key derivation, block (**keyed mode**) | `rng.rs:47-49` |
| 63 | absorb `b"pb-slot"`; `ZkRng::new` fixture, block domain | `argument.rs:270`; `rng.rs:20-24` |
| **64** | **Merkle node** `left ‖ right` | `merkle.rs:14-18` |
| **64** | **salted leaf** `d ‖ salt` | `pcs.rs:640-644` |
| **64** | **absorb `b"log-cols"`** `state ‖ le64(8) ‖ "log-cols" ‖ le64(8) ‖ le64(8)` | `protocol.rs:43` |
| 71…951 | absorb `b"pb-term"`, **per slot** (`slot_terms(s) ∈ 1…56`) | `argument.rs:350` |
| 73 | absorb `b"pb-scalar"` | `argument.rs:290`, `:321` |
| 81 | absorb `b"A"` / `b"M"` / `b"H"` root | `protocol.rs:41`, `:326` |
| 88 | absorb `b"schedule"` | `protocol.rs:36` |
| 91 | absorb `b"calibration"` | `protocol.rs:35` |
| 96 | absorb `b"public-statement"` | `protocol.rs:32` |
| ≥104 | absorb `b"sc-round"` (`16·(d+1)`, `d ≥ 2`) | `zk.rs:994` etc. |
| 128 | `SeamSpec::digest` (`28+32+64+4`) | `private_seam.rs:115-132` |
| 171 | absorb `b"expected-IO"` (112 B) **and** absorb `b"parameters"` (113-byte literal) | `protocol.rs:31`, `:33` |
| 400 / 3,072 / 3,640 | `hash_column` for `M` / `H` / `A` | `pcs.rs:137` |
| 8,247 / 8,248 | absorb `b"pcs-vec"` / `b"pcs-prox"` | `pcs.rs:927-929` |
| 16,438 / 16,441 | absorb `b"mask-q"` / `b"mask-prox"` | `zk.rs:533`, `:542` |
| thousands | `BlockPublic::digest`, `Layout::schedule_digest` | `private_block.rs:259`, `layout.rs:679` |

**What this settles.**

1. **47 is unique. CONFIRMED, unconditionally.** No absorb reaches it (the
   floor is 48 + |label| + |data| and the shortest on this path is 60); 47 is
   not a multiple of 8, so no `hash_column` can be 47; no `Transcript::new`
   domain on any path has length 35. **The draft's row 5 is right about 47.**
2. **40 is NOT unique in this crate. The draft's claim is false as written.**
   Two `Transcript::new` seeds are exactly 40 untagged bytes. Neither is on
   the toy-block path — the block builds one transcript, `Transcript::new(
   PROFILE)` at `protocol.rs:30` (51 bytes) — so the toy conclusion survives;
   but §1.4 is headed "*every oracle-query length class in the system*" and
   row 5 is tallied as an **unconditional** PROVED HERE. It must be rescoped
   to the block path and demoted. Concretely: the collision it would allow is
   between a refill input `key ‖ le64(counter)` and a *fixed public constant*,
   so it is worth 2^-256 per stream, not a break — but §5.1's qualification 2
   ("it rests on the 40-byte length class being unused elsewhere") is
   **already not satisfied crate-wide**, which is exactly the kind of sentence
   this project has been burned by. **BLOCKING B-3.**
3. **64 is shared by exactly three classes** — node, salted leaf, and the one
   `b"log-cols"` absorb. **CONFIRMED.** I re-derived every absorb on the path
   (the table above) and none other is 64: an absorb is 64 iff
   `|label| + |data| = 16`, and the only 8-byte label paired with 8 bytes of
   data is `b"log-cols"`. `b"rows"` is 60 and `b"pb-slot"` 63.
4. **`rows = 5` gives 40 and `rows = 8` gives 64. CONFIRMED** (`8·5 = 40`,
   `8·8 = 64`). No commitment in the toy block has either: 455, 384, 50, 7, 7.
   For the endpoints it is structural, not accidental: `SeamSpec::new` forces
   a power-of-two `len ∈ [2, 4096]` with `LOG_COLS = 8` and `MASK_ROWS = 5`
   (`private_seam.rs:28-35`, `:66-72`, `:106-111`), so
   `commitment_rows ∈ {6, 7, 9, 13, 21}` — **RECOMPUTED**, and 5 and 8 are
   both absent. Draft correct.
5. **Four of the draft's absorb lengths are wrong** (none of them to 64, so
   nothing moves): `b"mask-prox"` is **16,441** not 16,438; `b"parameters"`
   is **171** not "≥158" (the literal is 113 bytes); `b"sc-round"` is
   **≥104** not "≥88"; and `b"pb-term"` is absorbed **once per slot**
   (71…951 bytes), not once at 2,823. **CORRECTION C-7.**

### 2.4 Node versus salted leaf: the binding question, flagged not chased

Both are 64-byte unkeyed BLAKE3 inputs with no tag. A node input is
`left ‖ right`, a salted-leaf input is `d ‖ salt`. **There is nothing in the
format to tell them apart**, so a 32+32 split of the same 64 bytes is both a
valid node preimage and a valid leaf preimage. For **hiding** this is
irrelevant and the draft is right to say so. For **BINDING/soundness** it is
the classical unsalted-Merkle second-preimage shape: an adversary that can
choose the committed data could try to make an internal node's 64-byte
preimage double as a leaf preimage, collapsing a level. I did not chase it —
it is out of scope for this check, the tree is length-homogeneous so the
usual attack needs a 64-byte collision, and condition O-7 (composing this
argument with the soundness reduction over the same untagged table) is
already open. **FLAGGED; not analysed.**

### 2.5 The `2^-243` versus `2^-241.42` question, settled

**The draft is right; `2^-243` is wrong and should be corrected in four
documents.**

The bad event is: some node input or some salted-leaf input equals the
64-byte absorb input. That input's last 32 bytes are the fixed public
constant `C = le64(8) ‖ "log-cols" ‖ le64(8) ‖ le64(8)`, so a leaf matches
only if `salt_j = C` and a node only if `right = C`. Both are uniform
256-bit values, so each of the `12,283 + 12,288 = 24,571` objects matches
with probability 2^-256:

```
24,571 · 2^-256 = 2^-241.4153        [RECOMPUTED]
```

`2^-243` corresponds to ≈ 8,200 objects. **I can now say what it most likely
counted**: `8,192` is exactly the salted leaves of the four 2,048-leaf trees
— i.e. `M`'s 4,096 leaves and all 12,283 internal nodes were left out. The
source (`ZK60_JOINT_LAW_COMPOSITION_CHECK.md:588-590`) says "`2^-256` per
node or salt, `≈ 2^-243` over one proof's objects" and gives no count, so
this is inference, not a reading. **Carry 2^-241.42.**

**One thing the draft does not notice, in its favour.** The bound is wildly
conservative: matching also requires the *first* 32 bytes to equal the
transcript state, another 2^-256. The true bound is
`24,571 · 2^-512 = 2^-497.42` [RECOMPUTED]. The draft could delete this row
almost entirely. Also note the absorb happens **twice** per proof (`A` at
`protocol.rs:320`, `H` at `:377`) and this does *not* double the term,
because both share the same suffix `C` and it is the suffix condition that
carries the probability — I checked this because a factor 2 in the wrong
place is exactly the kind of error this repository has been finding.

**Documents to correct:** `ZK60_JOINT_LAW_COMPOSITION.md:1351`, `:1374`,
`:1489`, `:1846-1847`, `:1978` (C-5); `ZK60_JOINT_LAW_COMPOSITION_CHECK.md`
§A6.2 and its C-5; `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md:41`;
`ZK60_DECISIONS.md` D19 (at a glance, line 31); and
`ZK60_RULINGS_FOR_VICTOR_PRIVACY.md:45` — **the last of these is the page
going to the project owner**. **CORRECTION C-1.**

## 3. Attack 3 — Lemma H

### 3.1 (a) Can a column guess be confirmed without the salt?

**No, and the draft's one-line answer is right for the right reason.** The
only published object depending on an unopened column `k` is its salted leaf
`u_k = O(d_k ‖ s_k)` (or an ancestor of it). To test a guess `ĉ` the
adversary computes `d̂ = O(ĉ)` — it may query that freely, the unsalted
digest is not published (§2.2) — and then needs `s_k` to form the 64-byte
point. Guessing a 256-bit salt is the whole cost. **VERIFIED IN THE CODE**
that no unsalted digest ever leaves the process, which is the fact this
rests on.

### 3.2 (b) The delicate point: does the bound silently use column entropy?

**It does not. The bound rests on the salt alone.** I checked each of the
three terms:

* **(a) salt guessing, `q·N_leaf·2^-256`.** Derived from "the last 32 bytes
  of the input are the unknown salt", and the draft adds explicitly that
  guessing the column instead does not help. **No column entropy.**
* **(b) leaf-input collision, `C(N_leaf,2)·2^-256`.** Two salted-leaf inputs
  are equal iff *both* halves are, so the probability is bounded by
  `Pr[s_i = s_j] = 2^-256` over the uniform salts. **No column entropy** —
  and the bound would be the same if every column were the all-zero vector.
* **(c) the 64-byte absorb overlap.** Needs `salt = C`. **No column entropy.**

This matters because the draft's own §3.4 establishes that the unopened
columns are, conditioned on the field view and the hidden data, **not**
free: every pad symbol enters every encoded column with a non-zero
coefficient (`E_j[pad k] = (x_j^n − 1)·x_j^k`, `x_j^n ≠ 1` by the coset
assertion at `pcs.rs:613-615` — **VERIFIED IN THE CODE**), and the published
pad halves of the 46 group and 5 proximity vectors pin a `d`-dimensional
projection of the pads with `d = 231…246`
(`ZK60_JOINT_LAW_COMPOSITION.md:1145-1160`, Q7 resolved). So an unopened
column may well be a *deterministic function of (view, hidden data)*. Lemma
H must therefore be — and is — a statement whose only source of hiding is
the salt. **The draft gets this right; §2.3 Step 2's parenthesis is the
load-bearing sentence and it should be promoted out of a parenthesis.**

### 3.3 The exact conditional-independence statement, and whether the draft proves it

The statement that is needed, written as I would write it:

> Let `V` be the field view, `S_pub` the published salts, `ρ` a fixed
> non-refused challenge vector, and `(u_{r,k})` the salted-leaf digests of
> the never-opened encoded columns. In the ROM, for every admissible `w`,
> there is an event `B_H` with `Pr[B_H] ≤ β(q)` such that, on `B_H^c`,
>
> ```
> law( (u_{r,k})_{r,k}  |  V = v, S_pub = s, ρ, NR, w, and the adversary's
>                          q oracle answers )   =   Unif({0,1}^256)^{⊗ m}
> ```
>
> **for every** `(v, s)` in the support and every `w` — i.e. the conditional
> law is the *same product measure* whatever the conditioning and whatever
> the witness. Since `H = T^O(opened columns, S_pub, (u_{r,k}))` with `T^O`
> public, it follows that `law(H | V, ρ, NR, w)` is a fixed witness-free
> kernel, and hence
> `law(V, H | ρ, NR, w) = law(V | ρ, NR, w) · K(H | V)` with the first
> factor witness-free by Theorem 3.3.

**The draft states essentially this** ("Conditioned on `(V, ρ, NR)` and on
the published salts, the family `(u_{r,k})` is i.i.d. uniform … and
independent of `w` and of the unopened columns"). It is a **conditional**
statement, not a marginal one, and its §2.1 says in terms why a marginal
would be the `(H(mask), mask ⊕ w)` error. **I could not break it.** Two
wording fixes:

1. The conditioning must include **the adversary's own oracle answers** —
   the distinguisher has `q` answers in hand and the independence must hold
   given them. That is exactly what bad event (a) buys, but the lemma's
   conditioning list omits it.
2. "**independent of the unopened columns**" is the wrong phrase. The
   unopened columns are not independent of `V` and they need not be: what is
   true is that `(u_{r,k})` is uniform *given* the unopened columns, `V` and
   everything else. Write it that way; "independent of the unopened columns"
   reads as a claim about the columns' own entropy, which is the claim §3.2
   above shows must **not** be made.

### 3.4 (c) The generator: is the PRG assumption really replaceable?

**Read exactly. VERIFIED IN THE CODE** (`zkp-core/src/rng.rs`, whole file):

* `from_os` reads **32 bytes of `/dev/urandom`** (`:33`, `:45-46`) and fails
  closed on non-Unix (`:36-41`) — there is **no clock fallback and no public
  seed fallback**;
* the key is `blake3::Hasher::new_keyed(&entropy)` over
  `"hashline-zk-os-rng/v1/"(22) ‖ domain` (`:47-50`) — **keyed** mode;
* `refill` is `blake3::Hasher::new()` over `key(32) ‖ le64(counter)(8)`,
  finalised as an **XOF** filling 8,192 bytes (`:53-61`) — **unkeyed, 40
  bytes**. The draft's finding is correct and it is a genuine correction to
  the privacy case's M-3 text ("a keyed BLAKE3 stream with a counter"), which
  is right about the derivation and wrong about the stream.

**Is `ε_gen(q) ≤ 3q·2^-256` right?** The mechanism is right and the
conclusion is right in the model, with three qualifications the draft does
not all make:

* **The refill query inputs are NON-ADAPTIVE** — `key ‖ 0`, `key ‖ 1`, … —
  so all of the stream can be sampled before the protocol starts. **This is
  the fact that makes the argument work**, and it is also what makes the
  "publish `A`'s salts before `H`'s pads" worry evaporate: the published
  bytes and the secret bytes are disjoint byte ranges of a uniform string
  (either within one 8,192-byte block or in different blocks at different
  counters), hence independent. The draft asserts the conclusion without
  naming non-adaptivity; **it should, because it is also the hop Route A
  needs in §4.** [MY OWN ARGUMENT.]
* **The bound omits a second route.** The adversary can also guess the
  32-byte `/dev/urandom` entropy and query `O_k` at that key on the *public*
  input `"hashline-zk-os-rng/v1/" ‖ domain`, recovering the stream key. That
  is another `3q·2^-256`. **`ε_gen(q) ≤ 6q·2^-256 = q·2^-253.42`**
  [RECOMPUTED]. Immaterial; but it is a term, and the draft's page is built
  on listing every term. **CORRECTION C-3.**
* **The key's entropy is 256 bits *by assumption about the OS*.** The draft
  names this (`qualification 3`). Correct.

**The two conventions.**

* **(V-1) — one long-output oracle for unkeyed BLAKE3 in both its 32-byte
  and XOF forms.** The draft justifies this by "the 32-byte hash is the first
  32 bytes of the XOF", cited as a property of BLAKE3's specification, and
  labels the row **RELIES ON**. **That justification is not sufficient and
  the label is too strong.** The prefix property makes the two *readings*
  consistent; what the model needs is that BLAKE3's extendable output is
  **indifferentiable from a random oracle with long output**. That is a
  design claim of BLAKE3 (its tree mode with length/flag separation), not an
  arithmetic fact, and it is the thing to cite. **Demote V-1 from RELIES ON
  to ASSUMED, and cite indifferentiability.** **CORRECTION C-5.** (This is
  the draft's own open question 1(i), and the answer is: yes, an
  indifferentiability citation is required.)
* **(V-2) — keyed BLAKE3 as a second independent oracle.** Honest: the draft
  labels it ASSUMED and says it is a convention. I agree, and I would add
  one word of why it is the *conservative* convention here: modelling a
  secret-keyed PRF as a random oracle indexed by the key gives the adversary
  *more* power (it may query `O_k` at any key), so the resulting bound is an
  upper bound on the real one under the usual flag-separation reading.
  **No demotion.**

**Is the saving legitimate at all (open question 1(iii))?** My answer: **yes
for a residual table, no for a load-bearing claim.** Using one primitive as
both the Fiat–Shamir oracle and the PRG core is normal practice and the
length-class separation makes it clean here. But the saving buys one line in
a table and costs a convention (V-1) that has to be defended, while M-3 is
an assumption the project already carries for Theorem 3.3's own (H3) and
(H5). **I would keep M-3 and present `ε_gen` as the alternative reading, not
the primary one** — which is also what the draft's own escape hatch says
happens if a checker rejects §5.1.

### 3.5 A bad event the draft's list is missing

`Pr[B_H]`'s three terms cover: the distinguisher querying a leaf point; two
leaf inputs coinciding; a leaf input coinciding with the 64-byte absorb.
**Missing: a leaf input coinciding with a NODE input.** Both are 64 bytes.
This needs `salt_j = right` and `d_j = left`, so
`12,283 · 12,288 · 2^-512 = 2^-484.83` [RECOMPUTED] — utterly negligible,
and it changes no figure. But it is the fourth member of a list the draft
presents as exhaustive, and "the list is complete" is a claim the page makes.
**CORRECTION C-4.** (The draft *does* price the distinguisher querying an
internal node, at 2^-512 per query per node; that is a different event.)

I looked for others and found none: a refill input cannot meet a node, leaf
or absorb input (40 vs 64 vs ≥60) given `rows ∉ {5,8}`; two refill inputs in
one stream cannot coincide (distinct counters) and across the three streams
require equal keys (3·2^-256, unlisted and negligible); a column-hash input
cannot meet a challenge (not a multiple of 8) nor a node/leaf given
`rows ≠ 8`.

### 3.6 `rows ∉ {5, 8}` is not a new condition

The draft presents it as "***Condition (new, and cheap)***" and says it adds
"a second forbidden value" to the known 8-row case. **It is already in the
project's own documents, with both values.** Privacy-case item 16 says:
"*a seam commitment's row count is never 5 or 8 … 8 rows would make
`hash_column`'s input 64 bytes while 5 would alias `ZkRng::refill`'s 40-byte
input*", and attributes it to **condition 28 of the D8/D11 check**
(`ZK60_PRIVACY_CASE_FIRST_MVP.md:825-834`). The same passage already makes
the draft's point that `A`, `H` and `M` "are protected by no rule at all".
The condition is right; the novelty claim is wrong. **CORRECTION C-6.**

## 4. Attack 4 — the lift (Route A and Route B)

### 4.1 The hybrid, written out by me, and compared

**MY OWN ARGUMENT**, one page, for the toy block. Fix the admissible public
statement `P`, a hidden input `w`, and a distinguisher `D` making at most `q`
oracle queries. `G_0` is the real game: the honest prover runs `prove_inner`
with the real oracle; `D` sees the policy, the receipt or `⊥`, and may query
the oracle before, during (adaptively) and after.

| hop | what changes | what justifies it | cost |
|---|---|---|---|
| **G_0 → G_1** | the oracle is sampled **lazily**: a fresh uniform answer at each new point, in query order | identical distribution by definition of the ROM | 0 |
| **G_1 → G_2** | **all generator outputs are sampled up front.** The refill points are `key ‖ le64(counter)` for `counter = 0,1,…` — determined by the key alone, **not by any protocol value** | the query inputs are non-adaptive (`rng.rs:53-57`), so reordering their sampling changes nothing | 0 |
| **G_2 → G_3** | **abort if any query of `D`'s begins with one of the three stream keys, or hits the `O_k` key-derivation point** | — | `ε_gen(q) ≤ 6q·2^-256` (§3.4) |
| **G_3 → G_4** | **the prover's pads, masks and salts are replaced by uniform field elements and uniform 32-byte strings** | the salts are already exactly uniform (`bytes32` is raw stream); the field draws are `fp()`, each exactly 2^-96 from uniform, 327,052 of them | **2^-77.7** — D9. **THIS HOP IS MISSING FROM THE DRAFT** |
| **G_4 → G_5** | **abort on `B_H`** (salt queried; two leaf inputs equal; leaf input = the 64-byte absorb; leaf input = a node input) | §3 | `q·2^-242.42 + 2^-229.83 + 2^-241.42 + 2^-484.83` |
| **G_5 → G_6** | **abort on B1–B5, B7** | B1 and B2 are impossible (counter; length 47); B3, B4, B5 are priced | `q·2^-244.03 + 2^-233.07` |
| **G_6 → G_7** | **every challenge is replaced by a value drawn uniformly in advance** | each squeeze input is 47 bytes, fresh (B1: the counter increments, `transcript.rs:90`), met by no other class (B2), and not pre-queried (B3). So its answer is uniform given the whole history — which, by G_2, already contains all the prover's randomness | 0 |
| **G_7** | = the **fixed-challenge experiment** with `ρ` uniform and independent of `(w, blinding)` | — | — |
| **G_7 → G_8** | split on refusal; on non-refused `ρ` apply **Theorem 3.3** (field) × **Lemma H** (hash); the refusal event differs only in the LogUp class | §7 | `2·2^-112.0` |
| **G_8 → G_8′** | **`w := 0`**; the all-zero input is admissible (measured) | RELIES ON `zero_witness_tests.rs` | 0 |
| **G_8′ → G_0′** | undo G_6…G_1 in the zero world | same bounds | (already counted) |

Two hops the draft's Route A does not have.

* **G_3 → G_4, the idealisation hop, is absent.** §3.3 goes straight from
  lazy sampling to "by Theorem 3.3 the first factor is witness-free".
  Theorem 3.3 is stated **"in the uniform-blinding idealisation"** and its
  own remark (ruling J-3) says so in terms: *"the equality above is exact
  only in the idealisation where the prover's blinding is uniform"*. Applying
  it to the real prover without the replacement is exactly the move J-3 was
  written to stop. The draft knows the number — 2^-77.7 is the first row of
  its own §5.2 table and it says in §2.1 "the idealisation (the real prover
  is within the D9 sampler term)" — but the **derivation** never makes the
  substitution, so as written Route A does not reach its conclusion.
  **BLOCKING B-2**, and the repair is one paragraph.
* **G_1 → G_2, the non-adaptivity of the generator's query points, is
  implicit.** Without it, "sample all challenges in advance and feed them to
  the prover" is not obviously the same experiment, because the prover
  interleaves `O_40` queries with challenge draws (`H`'s pads are drawn after
  `β, γ, α`). It is true and easy (`refill` never reads a protocol value),
  but it is the hop the draft's own open question 2 is groping for and it
  should be stated. **OMITTED CONDITION O-F.**

### 4.2 Is the list of bad events complete?

Beyond §3.5's missing leaf-versus-node event, I attacked three specific
gaps the brief names.

* **Can the adversary's choice of STATEMENT make a transcript absorb
  collide with something?** The absorbs it controls are `b"expected-IO"`
  (171 B), `b"public-statement"` (96 B, a digest) and, through the layout,
  `b"schedule"` (88 B). None can be brought to 40, 47 or 64: the lengths are
  fixed by the frame, not by the content. `b"parameters"` and
  `b"calibration"` are literals. **VERIFIED IN THE CODE** (`protocol.rs:30-36`).
  B7 stands.
* **Can it query a challenge-defining input in advance?** Only by predicting
  the transcript state, and the first squeeze on the path comes after
  `a_root` and `mask_root` are absorbed. **VERIFIED IN THE CODE**: the header
  absorbs at `protocol.rs:30-36`, `absorb_root(b"A")` at `:320`,
  `tr.absorb(b"M", …)` at `:326`, and the first `challenge_fp2()` at `:330`.
  There is **no challenge before `a_root`**. Draft correct.
  *One nuance the draft mis-frames:* after `D` receives the receipt it can
  recompute **every** challenge input and query it — with probability 1, not
  `q·2^-244`. That is harmless (the answers are already fixed) and the only
  thing B3 is needed for is the lazy-sampling *ordering*. The B3 row is
  decoration, correctly sized for the sub-event it names; the draft's "it
  needs a 32-byte state guess" is true only for pre-receipt queries.
* **The refusal replay re-queries the same points.** `Transcript::clone_state`
  copies state **and counter** (`transcript.rs:139-142`), so
  `check_opening`'s replay (`protocol.rs:173`, `:201`) draws exactly the
  challenges `open_zk` will draw (`pcs.rs:915-929`). **VERIFIED IN THE
  CODE.** This is a repeat, not a collision — the same point, the same
  answer — and it is consistent with the fixed-challenge experiment only
  because Theorem 3.3's `ρ` is one vector used for both the refusal decision
  and the opening. The draft says this. Correct.

### 4.3 Where the refusal conditioning and the D9 bias enter, and how often

* **D9 enters once per proof**, at hop G_3 → G_4, as a single replacement of
  the whole blinding stream. **Confirmed**: 327,052 draws, one union bound,
  one row in the table. Not once per commitment, not once per challenge.
* **The refusal conditioning enters at G_7 → G_8**, after the challenges are
  uniform — which is the right order, because the challenge-driven refusals
  must be functions of a uniform `ρ` before their laws can be called equal in
  the two worlds. The draft's §9 row ("§3.3's conclusion is stated up to the
  refusal conditioning of §4, and §4 uses Route A's uniformity — not mutually
  dependent") is **correct**: G_6 → G_7 is unconditional on refusal.
* **The decomposition in §4 is loose by a small constant.** It writes
  `d(view_w, view_0) ≤ |P_w − P_0| + d(μ_w, μ_0)` and then says the second
  term is §2–§3. But `μ_w` is the view conditioned on *not refusing*, and the
  conditioning event differs between the worlds in the LogUp class, so the
  induced law of `ρ` given completion also differs by up to ≈ 2^-112. The
  clean bound is `d ≤ Pr_w[LogUp] + Pr_0[LogUp] + sup_{NR ρ} d(…) ≤
  2·2^-112 + ε_hash`. **Immaterial** against 2^-77.7, but the step is
  labelled PROVED HERE (elementary) and as written it is not tight enough to
  be that. **CORRECTION C-8.**

### 4.4 Route B

**Causality: VERIFIED IN THE CODE**, including the point the draft flags as
its open question 7. The host slots run after the slots they host
(`HOSTS`, `layout.rs:501-508`), and a host's scalar consumes
`acc.cs[*hs]` and `pd.masks[*hs].total()` — values of *earlier* slots
(`argument.rs:286-288`). No message depends on a later challenge. The
`(field, hash)` pairing is legitimate: salts and paths are gathered after
the index challenges and are **never re-absorbed** (`pcs.rs:927-941`;
`zk.rs:533-548`), which I re-read and confirm — **only the five roots of the
hash view are ever absorbed**.

**The lemma itself I could not verify**: `ZK60_MVP_JOINT_VIEW.md` §1.2 and
`tests/test_zk60_sequential_kernel.py` are on branch `zk60-mvp-fable`, not in
this tree. **COULD NOT VERIFY.** The draft says so. Its judgement that
"an acceptance that rests on a branch is fragile, so carry Route A" is
sound — and it raises the stakes on B-2, because Route A is then the only
route and its hybrid must be complete.

**One thing Route B needs that the draft states too weakly.** Privacy-case
item 17's carve-out (ii) says the sequential-kernel lemma "*is about field
messages and says nothing about the hash layer, because roots, salts and
paths are not messages chosen given `ρ`*". Route B's pairing is exactly the
extension that carve-out forbids reading into the lemma. That is fine — the
extension is legitimate because the joint per-`ρ` hypothesis is supplied as
Theorem 3.3 × Lemma H — but the page should say it is *extending* the lemma's
message alphabet, not applying it as reviewed. **OMITTED CONDITION.**

## 5. Attack 5 — the known counterexample `(H(mask), mask XOR w)`

**The draft's sentence is imprecise and its lemma is not.** The sentence —
an unopened leaf's digest "is **not a function of the pads** but a fresh
image at a point addressed by an unpublished salt" — is, read literally,
false: in the ROM the digest **is** a function of `(column, salt)` and the
column is a function of the pads. What is true is the conditional statement
of §3.3 above: conditioned on everything the adversary has, *and on the
unopened columns themselves*, the digest is uniform, because the point
`d_k ‖ s_k` has not been queried by anyone else. Make that precise and the
counterexample dies for the right reason: in `(H(mask), mask ⊕ w)` the two
published objects are images of **the same** unknown at **two** addresses the
adversary can relate; here the second address is unreachable without a fresh
256-bit secret that is published for **no** unopened column.

**Does the draft prove the conditional statement or only a marginal one?**
It proves the conditional one. Its §2.1 sets up the factorisation
`law(V,H) = law(V)·law(H|V)` explicitly, names multiplying two marginals as
the error to avoid, and §2.3's conclusion is stated as "the conditional law
of `H` given `(V, salts, ρ, NR)`". **I could not find a marginal step
smuggled in.** The two fixes are the wording ones of §3.3: add the
adversary's oracle answers to the conditioning, and stop saying "independent
of the unopened columns".

**The contrast the draft draws is worth keeping and I verified it.** For an
**opened** column the leaf digest *is* a deterministic public function of
published data — the verifier recomputes
`salt_leaf(hash_column(col), salt)` at `pcs.rs:1018-1021` and `zk.rs:576-577`
(**VERIFIED IN THE CODE**) — and that is harmless because the column is
published too. So every leaf is either fully published or fully salted, and
rule C-H1 ("a salt is published iff its column is") is the invariant that
keeps it so.

## 6. Attack 6 — many proofs

**The arithmetic. RECOMPUTED, all three figures agree:**

| claim | draft | mine |
|---|---|---|
| sampler term at `k = 2^20` proofs | ≈ 2^-57.7 | **2^-57.700** |
| cross-proof leaf collision at `k = 2^20` | 2^-189.8 | `C(2^20·12288, 2)·2^-256 =` **2^-189.830** |
| the term that degrades | D9's, linearly in `k` | correct: every other term is either `k`-linear at 2^-112 or lower, or quadratic from 2^-229.8 |

**Is there a cross-proof object that breaks the union bound?** I checked
each candidate the brief names. **VERIFIED IN THE CODE: no, for the block
profile.**

* **A repeated salt** — impossible except by chance: each proof calls
  `from_os` three times (`protocol.rs:275`, `private_seam.rs:196` twice) and
  each reads 32 fresh `/dev/urandom` bytes.
* **A repeated generator key** — same; requires a `/dev/urandom` repeat.
* **A statement-derived seed** — the transcript seed `Transcript::new(PROFILE)`
  **is** identical in every proof (51 bytes, a constant). This does *not*
  break anything, and there is a structural reason the draft misses and
  should add: **one policy admits at most one proof.** `check_endpoints`
  refuses unless the prover's freshly committed roots equal the policy's
  (`protocol.rs:247-249`), and `prepare` draws fresh entropy every call, so a
  second attempt against the same `ExpectedIo` refuses. Hence the header
  state — which includes the two endpoint roots through the 112-byte policy —
  **differs between any two proofs**, and no two proofs can share a challenge
  input. That is a much stronger statement than the union bound needs and it
  is worth stating. [MY OWN ARGUMENT, from `protocol.rs:31`, `:247-249`,
  `private_seam.rs:196`.]
* **A deterministic test seed reachable outside tests** —
  `ZkConfig::rng` at `hashline/src/zk.rs:334-338` does
  `Some(seed) => ZkRng::new(seed, domain)` and is **production code on the
  legacy feed-forward line**, marked only by the string `"deterministic-test"`
  that `randomness_label` returns (`:330-332`). **VERIFIED IN THE CODE.** It
  is **not reachable from the block profile** — `protocol.rs:275` and
  `private_seam.rs:196` call `from_os` and nothing else, and `ZkConfig` is
  not used by `private_block`. The draft reports this correctly as privacy-case
  blocking item B-5 and does not re-read it; I did, and it stands as stated.

**One reading of the many-proofs row I would sharpen.** §6.4 says the
composition holds "under one assumption: each proof draws fresh OS
randomness … and `/dev/urandom` gives independent uniform bytes across
proofs". True — and it also needs the ROM to be the **same** oracle across
proofs, which it is, so the cross-proof salt-guessing term is `q·k·N·2^-256`
with **one** `q` shared across all `k` proofs, not `q` per proof. The draft
writes `q·k·12,288·2^-256`, which is the right form. **Correct.**

## 7. Attack 7 — refusals

### 7.1 The refusal strings: what the gap actually is

**VERIFIED IN THE CODE, and it is a real, concrete, data-dependent channel.**
`hashline/src/private_block/witness.rs` names the failing relation in the
error string: `range(site)` → `"fixed oracle range refusal: {site}"`
(`:79-80`) with sites `"norm denominator"` (`:175`, `:187`),
`"norm quotient/remainder"` (`:195`), `"exp difference"` (`:279`),
`"softmax quotient/remainder"` (`:299`), `"residual 1"` (`:323`),
`"FFN up"` (`:377`), `"residual 2"` (`:415`), plus two relation failures,
`"causal maximum attainment"` (`:271`) and `"softmax denominator"` (`:287`).
A caller that submits an input and reads the `Err` string learns **which
relation its own input violated**. (`refusals.rs` is a *test* module that
pins these site names; it is not the production site.)

**Should it block acceptance of the toy profile? My answer: no for the
statement as quantified, yes as a printed condition — and the draft has it
in the right place.** The statement quantifies over **admissible** `w`, and
admissible means the builder accepted it, so none of these 20 strings can
fire inside the quantifier. The strings that *can* fire for an admissible
input are the ones inside `prove_inner`, and there the partition is already
covered: the challenge-driven strings
(`"zero group member coefficient; discard attempt"`,
`"dependent proximity mask coefficients; discard attempt"`,
`protocol.rs:144`, `:149`; `"zero CFS mask challenge"`, `argument.rs:275-276`;
`"degenerate terminal mask challenge"`, `:347-348`) are functions of a
**cloned** challenge prefix and therefore of `ρ` alone — **VERIFIED IN THE
CODE**, `check_opening_challenges` (`protocol.rs:141-152`) takes its draws
from `Transcript::clone_state(tr)` (`protocol.rs:173`, `:201`) — so their
law is identical in both worlds; and the one witness-dependent string,
`"zero LogUp denominator; discard attempt"` (`protocol.rs:231-232`), is the
class already priced at 2^-112.0. So revealing *which* class refused does not
worsen the bound beyond the constant of §4.3.

**What the gap really is, stated for the implementers:** it is a
**service-boundary** gap, not a proof gap — a deployment that returns
`prove`'s `Err(String)` to the requester leaks, for an *inadmissible* input,
which relation failed. The fix is to map every refusal to one opaque code at
the API boundary. The draft calls it "an engineering GAP"; that is right, and
it should say *inadmissible inputs* explicitly so nobody reads it as a hole
in the theorem.

### 7.2 The 2^-62.0 refusal rate: a number the cited source does not give

**This is an over-claim and I am raising it as blocking.** The draft prints
"Rate **2^-62.0 per proof**" in §4 and "the prover **refuses about once in
2^62.0 proofs**" in §5.2, as facts about the private block. The privacy case
it cites says the opposite in terms:

> "It was computed at the A00 … shape … but **for a different prover**: the
> repaired feed-forward profile `ffn-v3-mr1` … **Its size at the block's own
> schedule (46 opening groups, 5 proximity pairs, 23 slots) has never been
> counted; that number is OPEN, and this page does not guess it.**"
> — `ZK60_PRIVACY_CASE_FIRST_MVP.md:319-327`

**BLOCKING B-4**: a number imported across profiles against an explicit
"OPEN, and this page does not guess it".

**And now the count, so the repair is cheap. MY OWN ARGUMENT
[RECOMPUTED].** For the private block the challenge-driven refusals are:

| site | condition | probability |
|---|---|---|
| `check_opening_challenges`, proximity pair | `det(ρ_prox, ρ_prox+1) = 0` (`protocol.rs:135-137`, `:148-150`), a determinant in **`Fp`** | ≈ `1/p ≈ 2^-64` each |
| called for | `A` (`protocol.rs:396`), `H` (`:399`), input endpoint (`:402`), output endpoint (`:405`) | **4 sites** |
| zero group member coefficient | `c.is_zero()` for `c ∈ Fp2` | ≈ `2^-128` × (46 + 5 + …) |
| zero CFS mask challenge | `c.is_zero()`, `Fp2` | 23 × 2^-128 |
| degenerate terminal mask challenge | `e ∈ {0, 1}`, `Fp2` | 2 × (#e) × 2^-128 |

The determinant terms dominate by 64 bits:
`4/p = 4·2^-64 ≈ 2^-62.00`. **So 2^-62.0 happens to be right for this
block** — but for a completely different reason from the A00 inventory (four
`Fp`-valued determinant checks, not 22 pair claims and 6 slots). The draft
should carry this derivation, or drop the number.

**The rest of §4 I checked and it holds.** A refusal is terminal:
`prove_with_stats` calls `prove_inner` once (`private_block.rs:432-435`),
there is no retry loop, `PreparedPlane` has no `Clone`, and `Endpoints` is
taken by value — **VERIFIED IN THE CODE** (ruling J-4 reproduces). The class
counts are off by one or two: by the privacy case's own 18-row table the
shape/schedule/policy/environment classes are rows 1–5, 7, 11, 13, 14, 17
(ten), plus the two panics argued unreachable (rows 15, 16) and the
witness-builder row (18), against **four** challenge-driven (8, 9, 10, 12)
and **one** witness-dependent (6). The draft's "14 of 18" does not match any
grouping of that table. **CORRECTION C-9**, immaterial.

## 8. Attack 8 — the dangling premises and the code conditions

### 8.1 The three dangling premises the draft declares

**1. "Theorem 3.3 carries a step supplied by the independent check and
reviewed by nobody."** **STALE, and the stale part is not the worst of it.**
The disposition records at the end of ruling J-2: *"J-2 is resolved (03:49,
2026-09-20): the step is independently reviewed, and corrected"*
(`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md:89-99`), and the composition memo
already carries *"the imported terminals step, now independently reviewed and
corrected (2026-09-20)"* in its restatement of (H1)
(`ZK60_JOINT_LAW_COMPOSITION.md:1352-1360`). Both were in the tree when the
draft was written (its own baseline is `d4f34f8`, which is the revision
commit).

**The substantive problem is that the review's own conditions do not travel
with this page.** The disposition's J-2 resolution adds three to (H1), and
every conclusion of the draft multiplies (H1):

* the condition that carries privacy is the **shape** of the reserved pair's
  weights, `(cm, cm·U)` (`argument.rs:232-234`) — not merely `cm ≠ 0`; with
  base-field-dependent weights a singleton group discloses 256 `Fp`;
* on `H` **two groups share the zero-sum pair**, so the per-group argument is
  invalid as written there and the joint rank is what holds;
* **the pad budget on `H` is load-bearing**: one opened position beyond it
  discloses 2 `Fp`.

The draft's §5.2 condition 2 lists the idealisation, the terminals step, O-2
and (H1)–(H5). It must list these three as well. **BLOCKING B-1.**

**2. "Route B's lemma is only on branch `zk60-mvp-fable`."** **CONFIRMED and
unchanged** — `ZK60_MVP_JOINT_VIEW.md` and
`tests/test_zk60_sequential_kernel.py` are not in this tree. **COULD NOT
VERIFY** the lemma. The draft's handling (offer Route A instead) is right.

**3. "C-H1 … C-H8 and `rows ∉ {5,8}` are enforced by nothing."**
**CONFIRMED** — see the table below, with one exception the draft misses:
C-H6 *is* pinned, by a compile-fail doctest.

### 8.2 The code conditions, with their truth today

| # | condition | true today? | where I checked | can it be pinned cheaply? |
|---|---|---|---|---|
| **C-H1** | a salt is published **iff** its column is opened | **TRUE** | `pcs.rs:928-941` (`cmz.salts[j]` for sampled `j` only); `zk.rs:543-548`; the salt travels inside the per-column tuple, so there is no path that emits one alone | **yes** — a test that the distinct salts in a receipt number at most the distinct opened indices, per commitment. Byte-free |
| **C-H2** | salts are `ZkRng::bytes32()` off an OS-seeded stream, never from the witness, the statement or a counter | **TRUE on the block path** (`pcs.rs:674`, `zk.rs:462`; streams at `protocol.rs:275`, `private_seam.rs:196`), **FALSE crate-wide**: `zk.rs:334-338` takes a caller seed on the legacy line | partly — privacy-case ruling C-4 (refuse a caller seed outside test builds, or surface `randomness_label`). **Unfixed; it is B-5 of the privacy case** |
| **C-H3** | the salt is 32 bytes | **TRUE, at the type level**: `salts: Vec<[u8; 32]>` (`pcs.rs:559`), `bytes32` (`rng.rs:93-99`) | **already pinned** by the type. A const assert would add nothing |
| **C-H4** | no commitment has 5 or 8 rows | **TRUE**: 455, 384, 50, 7, 7. Structural for the endpoints (`{6,7,9,13,21}` from `private_seam.rs:28-35`, `:66-72`, `:106-111`); **accidental** for `A`, `H`, `M` | **yes** — one assertion in the block's own layout test beside `assert_eq!(M_ROWS, 50)` (`layout.rs:703-708`). Do **not** put it in `zkp-core`: other profiles may legitimately use 5 or 8 rows |
| **C-H4′** | *(added by this check)* no `Transcript::new` domain on an accepted private path has length 28 or 35 (which give 40- and 47-byte seeds) | **TRUE on the block path** (`PROFILE`, 39 → 51 bytes); **FALSE crate-wide**: `private_seam.rs:26` and `public_block_receipt.rs:20` are both 28 | **yes** — a `const` assertion on the profile domain's length, or the separating tag D19 already proposes for new profiles |
| **C-H5** | no salt or blinding value is reused across commitments or proofs | **TRUE**: each commitment draws its own `nn` salts from its own stream segment; three `from_os` calls per proof | reading only (condition O-2). A stream-position test is possible but awkward |
| **C-H6** | no commitment is opened twice | **TRUE and ALREADY PINNED**: `PreparedPlane` has no `Clone` and no getter (`private_seam.rs:142-147`), `Endpoints` is taken by value, and `private_block.rs:360-366` carries a **compile-fail doctest** that a second `prove` on the same owners does not compile | **already pinned** — the draft says "prevented by the type system" but not that a test enforces it |
| **C-H7** | no root is fixed in advance by a third party | **TRUE for this MVP**: `check_endpoints` refuses any policy whose roots differ from the prover's own fresh ones (`protocol.rs:247-249`), under D18 | pinned by the code path; **D8/D11 remain open and are untouched** |
| **C-H8** | no external/device commit path produces different leaves | **TRUE**: the block calls `commit_zk_owned` → the `Cpu` backend; `commit_zk_owned_with`'s `backend.try_commit_zk` (`pcs.rs:678-684`) is never offered a device on this path | **yes** — assert the store is `Store::Host` in the block profile's own test, so a future device backend has to re-open this question deliberately |

**Two conditions from outside the draft that must join the list**, because
the statement is false without them:

* **O-1 (privacy case §2.2)**: the 32-byte `IoSpec::context` travels inside
  the 112-byte policy, which the draft's own sentence puts *in the view*. If
  a deployment computes it from the request, the two worlds do not share a
  statement and the quantifier collapses. The draft files this under §6.7
  "not in scope"; it is not out of scope, it is a **hypothesis of the
  sentence**.
* **D21's capture rule**: the sentence's view is exactly the three files a
  capture writes (`native_capture.rs:275`). A capture format that gains a
  field computed from hidden data falsifies it.

## 9. Attack 9 — the label tally, re-labelled

I re-labelled all 41 rows myself and **never strengthened one**. I add one
label the draft does not use, **MIXED**, for a row that is proved but whose
statement must be rescoped or whose enumeration is incomplete — the same
device the composition check used.

### 9.1 The demotions, with reasons

| row | draft label | my label | why |
|---:|---|---|---|
| 4 | PROVED HERE (unconditional) | **MIXED** | the table is incomplete (two 40-byte `Transcript::new` seeds missing) and four lengths are wrong (`mask-prox`, `parameters`, `sc-round`, `pb-term`). None of the errors touches 64, so the conclusion stands — but a row claiming to be "*every* oracle-query length class in the system" cannot be unconditional while it is missing classes |
| 5 | PROVED HERE (unconditional) | **MIXED** | "47 is occupied by nothing else" is **confirmed unconditionally**. "40 is occupied by nothing else either" is **false of the crate** and true only of the toy-block path (§2.3) |
| 13 | PROVED HERE | **MIXED** | the three ways Step 2 can fail are four: a leaf input can also coincide with a node input (2^-484.83) |
| 16 | COMPUTED | **MIXED** | the arithmetic reproduces exactly, but `Pr[B_H]` is missing the term above and `ε_gen` is missing the entropy-guessing route |
| 21 | PROVED HERE / COMPUTED | **MIXED** | B1, B2, B7 are confirmed zero and each size is confirmed term by term; the **summed** `ε_lift` line is wrong at every `q` (§1.2); B3's stated reason covers only pre-receipt queries |
| 23 | PROVED HERE | **MIXED** | Route A's hybrid omits the idealisation hop (§4.1). The conclusion is reachable; the derivation as written does not reach it |
| 30 | RELIES ON | **MIXED** | the inventory is relied on correctly; the rate **2^-62.0 is not in the cited source for this shape** — that source says it is OPEN (§7.2) |
| 31 | PROVED HERE | **MIXED** | the decomposition omits the shift in the conditional law of `ρ` given completion; the honest constant is 2 (§4.3) |
| 35 | PROVED HERE | **MIXED** | correct inside the model, but the bound is incomplete and V-1's stated justification (the XOF prefix property) does not license a long-output oracle — indifferentiability does (§3.4) |
| 6 | CONDITION ("new") | **CONDITION** (not new) | already privacy-case item 16 / D8-D11-check condition 28, with both values |
| 10 | RELIES ON | **RELIES ON**, with three conditions added | the J-2 review's pair-weight shape, the `H` shared-pair exception, the `H` pad budget (§8.1) |

**No promotions.** Rows 7, 8, 20 and 26 I verified independently and they
hold exactly as written; row 2's counts reproduce to the displayed digit;
row 36's sum is true and understated.

### 9.2 The corrected tally

| label | draft | mine |
|---|---:|---:|
| PROVED HERE | 18 | **11** |
| MIXED | — | **9** |
| RELIES ON | 6 | **5** |
| VERIFIED IN THE CODE | 7 | **7** |
| COMPUTED | 3 | **2** |
| ASSUMED | 1 | **1** |
| CONDITION | 1 | **1** |
| GAP | 5 | **5** |
| **total** | **41** | **41** |

**"Unconditional" rows: the draft claims six (4, 5, 7, 8, 20, 26); I find
four** — 7 (exactly one 64-byte absorb on this path), 8 (the overlap term),
20 (every challenge input in a proof is distinct because the squeeze counter
increments, `transcript.rs:90`) and 26 (every pad enters every encoded
column, from `encode_row_zk` and the coset assertion at `pcs.rs:613-615`).
Rows 4 and 5 survive **rescoped to the toy-block path**, which is not the
same thing as unconditional.

### 9.3 Circularity

**I found no circularity, and I looked for the specific shape this
repository was burned by.** The critical row is the one the draft itself
flags: Lemma H is proved **for every fixed `ρ`**, with no hypothesis about
how `ρ` arose, and §3.3 then uses it at each `ρ`. I checked the quantifier
order in the lemma's own statement — "*Fix … a challenge vector `ρ` with
`NR(ρ)`*" then "*Then there is a public, witness-free map `T^O` …*" — it is
∀ρ ∃T, not the reverse, and `T^O` is built from the geometry and `ρ` only.
**Correct.**

Two dependency edges I checked that the draft's §9 does not list:

* **§2.3 Step 2 ← §5.1 ← §1.4.** Lemma H needs uniform secret salts; §5.1
  supplies them in the ROM; §5.1 needs the 40-byte class unused. §1.4 is
  proved from lengths alone. **Acyclic** — but the middle link is the one
  §2.3 of this check demotes, so the chain is only as strong as the rescoped
  version of row 5.
* **§3.2 B7 ← §2.3 Step 2.** B7 (no grinding) needs `a_root` unpredictable,
  which needs the unopened leaves to be fresh images. Step 2 does not use
  B7. **Acyclic**, as the draft says.

## 10. Attack 10 — the plain-words summary

**§0 does not over-claim, with two exceptions.**

What it gets right and I want on the record: it says in its own opening box
that it is "NOT ACCEPTED, NOT a privacy acceptance"; it says D8 and D11 are
"untouched and are not closed by anything here" **three times** (§0, §2.5
C-H7, §6.2); it names its model as a proposed ruling, not an accepted one;
it says its two inputs are unfinished; and §5.2 ends "It is not a privacy
acceptance … Nothing in this page establishes a privacy property." **No
sentence I could find says or implies that privacy is established or
accepted, or that D8/D11 are closed.**

The two exceptions:

1. **"the two halves compose: the whole view of one toy-block proof … has a
   law that does not depend on the hidden input, up to a list of
   residuals"** (§0). The words "*the whole view*" are doing work the body
   does not support: the refusal string is in the caller's view and is a
   declared GAP, and timing is D20. The body is careful; the summary is not.
   Write "*everything a verifier is given — the policy, the receipt and
   whether the prover refused*", and name the exclusions in the same
   sentence. **CORRECTION C-11.**
2. **"One thing this page found that was not in the earlier documents"**
   (§0, the generator). The *finding* is genuine and valuable — the stream
   really is unkeyed BLAKE3 on 40 bytes and no document had said so. But the
   consequence advertised in the same paragraph, "*inside the random-oracle
   model the separate PRG assumption (M-3) is not needed*", is stated in §0
   without the two conventions it costs, and one of them (V-1) I demote in
   §3.4. §5.1 states it carefully; §0 does not. **CORRECTION C-13.**

One more presentational point, in the draft's favour: §8's closing
paragraph — "**None of them is unconditional** … the rows that are
unconditional are the arithmetic and source-reading ones" — is exactly the
discipline this project has been asking for, and it is what let me find the
two rows to demote quickly.

## 11. What I could not check

* **The sequential-kernel lemma** (`ZK60_MVP_JOINT_VIEW.md` §1.2 and its
  exhaustive toy tests) — on branch `zk60-mvp-fable`, not in this tree. So
  Route B is unverified here in its central ingredient.
* **Theorem 3.3 itself.** I read its statement, its proof sketch, its
  hypotheses and the disposition that accepted its core; I did **not**
  re-derive it, re-read the 23 terminal closures, or re-run any enumeration.
  Every conclusion of the draft — and of this check — is downstream of it.
* **`Δ_gr`**, the generic-rank term, and the claim that on the accepted
  structural route the disclosure set lies inside the refusal set so the
  term is 0. Not re-derived.
* **The 4,000 bound on absorbs plus squeezes.** The draft says it is a bound
  and that it did not count them; neither did I. Everything it enters is
  2^-233 or smaller, so nothing turns on it. (The draft's own open question
  8 asks whether it should be counted exactly: my answer is **no** — it buys
  nothing and a wrong exact count would be worse than an honest bound.)
* **The LogUp count 64,768** (`layout.rs:744-746`) — I recomputed
  `64,768 / 2^128 = 2^-112.017` but did not re-derive the 61,440 + 2,048 +
  512 + 768 decomposition from the schedule.
* **Anything about BLAKE3 itself**, including whether its XOF is
  indifferentiable from a long-output random oracle. That is a literature
  question and I ran no code and read no specification.
* **Soundness, in any form.** The node/salted-leaf 64-byte ambiguity of §2.4
  is flagged and not analysed, and condition O-7 (composing this argument
  with the soundness reduction over the same untagged table) is untouched
  here as it is in the draft.
* **Anything at the 125M shape or on the development rung.** The draft's §6.1
  quotes `hash_column` inputs of 45,448 / 57,488 / 232 bytes at 125M; I did
  not check those row counts.

### 11.1 The draft's ten open questions, answered

| # | the draft's question | my answer |
|---:|---|---|
| 1 | is turning "the generator is the same function as the oracle" into a saving legitimate? | **Mechanism yes, presentation no.** (i) V-1 needs **indifferentiability**, not the XOF prefix property — C-5. (ii) V-2 is a sound and *conservative* convention. (iii) I would **keep M-3 as primary** and present `ε_gen` as the alternative reading: the saving buys one table row and costs a convention that must be defended, while M-3 is already inside Theorem 3.3's own (H3) and (H5). Also the bound is short one route — C-3 |
| 2 | is the lazy-sampling step airtight under the feedback `state = squeeze output`? | **Yes**, and the missing ingredient is the one I name in §4.1: the generator's query points are **non-adaptive**, so all of `O_40` may be sampled before the protocol starts; after that, each 47-byte challenge point is fresh (counter), met by no other class (length), and unqueried (B3), so its answer is uniform given the entire history. I found **no** place where the prover's behaviour depends on an `O_47` value other than through a challenge it was handed — the only consumer of `squeeze_bytes` is the transcript's own state and the challenge constructors (`transcript.rs:85-131`) |
| 3 | is Lemma H's inventory of the hash view complete? | **Yes.** I redid the reading and widened it to `ProveStats`, the 32-byte wire `binding`, `last_mask_sites` and the capture files. §2.2 |
| 4 | is the leaf-input collision term (2^-229.83) necessary? | **Yes, it is necessary — it is the salts' birthday bound.** If two leaf inputs coincide the two digests are equal with probability 1, whereas i.i.d. uniform digests would agree with probability 2^-256; the total-variation contribution is therefore the coincidence probability itself. The only sharpening available is to count **unopened** leaves (11,077) rather than all 12,288, worth **0.16 bits** (2^-229.99). Not worth the prose |
| 5 | `2^-243` versus `2^-241.42` | **`2^-241.42` is right**; `2^-243` counts ≈8,200 objects, most likely the four 2,048-leaf trees' salted leaves alone. §2.5, C-1 |
| 6 | the `k`-proof formula; and should the owner be told about the linear D9 degradation? | The formula is the right shape and the arithmetic checks (§6). **Yes, he should be told**, and I would put it in one line: *a service emitting a million proofs sits at about 2^-57.7, not 2^-77.7, and the only lever is D9's one-line rejection-sampling change.* I add a structural fact the draft misses: **one policy admits at most one proof**, so two proofs can never share a challenge input |
| 7 | Route B's causality, re-read against `HOSTS` | **Re-read and confirmed** (`layout.rs:501-508`, `argument.rs:286-288`): a host consumes only earlier slots' values. §4.4 |
| 8 | should the 4,000 absorb bound be counted exactly? | **No.** It enters only terms at 2^-233 and 2^-244; an honest bound is better than a count that could go stale with the schedule |
| 9 | are `rows ∉ {5,8}` and C-H1 worth a Rust test now? | **Yes, both, and now** — each is a few lines and neither changes a byte. Put the row check in the block's own layout test, **not** in `zkp-core`. And note the draft did not know that C-H6 is already pinned by a `compile_fail` doctest (`private_block.rs:360-366`) — the same treatment works here |
| 10 | is any part of §2/§3 worth keeping if Theorem 3.3 falls? | **Yes: Lemma H and the whole length-class analysis are independent of it.** Lemma H is a statement about the conditional law of the hash view **given** the field view; it holds whatever the field view's own law turns out to be. If Theorem 3.3 moved, §2 would survive verbatim and only the product step would need redoing. That is worth saying in the page, because it is the strongest structural thing on it |

## 12. ERRATA AND CONDITIONS FOR ACCEPTANCE

### A. BLOCKING — the draft should not be accepted until these are fixed

| # | item | where | what to do |
|---:|---|---|---|
| **B-1** | **Theorem 3.3's conditions are out of date and incomplete.** The page says the terminals step is "reviewed by nobody" (§0, §2.1, §5.2 cond. 2, §9 dangling premise 1); it was reviewed and corrected at 03:49 on 2026-09-20, before the page was written. Worse, the **three conditions that review added to (H1)** do not travel: the reserved pair's weights must have the shape `(cm, cm·U)` (`argument.rs:232-234`), on `H` two groups share the zero-sum pair so the per-group argument is invalid there, and the `H` pad budget is load-bearing | §0, §2.1, §5.2 condition 2, §8 row 10, §9 premise 1 | replace the provenance sentence with "independently reviewed and corrected, 2026-09-20"; add the three conditions to every list of what travels with Theorem 3.3 |
| **B-2** | **Route A's hybrid omits the idealisation hop.** Theorem 3.3 holds "in the uniform-blinding idealisation" (ruling J-3); §3.3 applies it to the real prover without ever replacing the `fp()`-biased blinding by uniform blinding. The number is already in the page's own table | §3.3 | insert the hop before Theorem 3.3 is invoked: *replace the prover's 327,052 `fp()` draws by uniform field elements, at total variation ≤ 2^-77.7 (D9); the 12,288 salts need no replacement, `bytes32` is raw stream output*. Also state the non-adaptivity of the refill query points, which the lazy-sampling step needs |
| **B-3** | **"40 is occupied by nothing else either" is false of the crate.** `Transcript::new(b"experimental-private-seam/v1")` (`private_seam.rs:26`, `:245`) and `Transcript::new(b"zk60-public-block-receipt-v1")` (`public_block_receipt.rs:20`, `:178`) are both `12 + 28 = 40` untagged unkeyed BLAKE3 bytes. Neither is on the toy-block path, so the toy conclusion survives — but §1.4 is headed "every … class **in the system**", row 5 is tallied **unconditional**, and §5.1's qualification 2 rests on it | §1.4, §5.1 qual. 2, §8 row 5 | rescope both the heading and the claim to the toy-block path; demote row 5 to MIXED; add condition **C-H4′** (no accepted private profile's transcript domain may have length 28 or 35) |
| **B-4** | **The 2^-62.0 refusal rate is imported across profiles** against the cited source's explicit "*has never been counted … that number is OPEN, and this page does not guess it*" (`ZK60_PRIVACY_CASE_FIRST_MVP.md:319-327`) | §4 table, §5.2 "Separately, not in the sum" | either drop the figure, or adopt the derivation in §7.2 of this check: **four** `Fp`-valued proximity determinants (`check_opening_challenges`, `protocol.rs:141-152`, reached at `:396`, `:399`, `:402`, `:405`) give `4/p ≈ 2^-62.0`, everything else being 64 bits smaller. Label it as newly counted, not as quoted |

### B. CORRECTIONS

| # | item | verdict |
|---:|---|---|
| **C-1** | `2^-243` → **2^-241.42**. The draft is **right**; the earlier figure counts ≈ 8,200 objects, most likely the 8,192 salted leaves of the four 2,048-leaf trees, leaving out `M`'s 4,096 leaves and all 12,283 internal nodes. Correct it in `ZK60_JOINT_LAW_COMPOSITION.md:1351`, `:1374`, `:1489`, `:1846-1847`, `:1978`; its `_CHECK.md` §A6.2 and C-5; its `_DISPOSITION.md:41`; `ZK60_DECISIONS.md` D19; and — most importantly — `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md:45`, which is the page going to the project owner | **settled in the draft's favour** |
| **C-2** | `ε_lift(q)`'s display line in §3.2 gives the salt term alone. The true sums are **2^-228.837 / 2^-192.008 / 2^-162.008 / 2^-114.008** at `q = 2^12 / 2^50 / 2^80 / 2^128`. §2.4's `Pr[B_H]` row is right; §5.2's "below 2^-114 at `q = 2^128`" survives by 0.6 % | arithmetic |
| **C-3** | `ε_gen(q)` omits a second route: guessing the 32-byte `/dev/urandom` entropy and recomputing the key through `O_k` on a public input. `ε_gen(q) ≤ 6q·2^-256 = q·2^-253.42` | immaterial, but it is a term |
| **C-4** | `Pr[B_H]` is missing a fourth failure mode: a salted-leaf input equal to a **node** input (both 64 bytes) — `12,283 · 12,288 · 2^-512 = 2^-484.83` | immaterial; completes a list presented as exhaustive |
| **C-5** | Convention **V-1** is justified by the wrong property. "The 32-byte hash is the first 32 bytes of the XOF" makes the readings consistent; licensing one long-output oracle needs **indifferentiability** of BLAKE3's extendable output. Demote V-1 from RELIES ON to ASSUMED and cite indifferentiability | answers the draft's open question 1(i): yes, the citation is required |
| **C-6** | `rows ∉ {5, 8}` is **not new**: privacy-case item 16 already names both values, crediting condition 28 of the D8/D11 check, and already observes that `A`, `H`, `M` are protected by nothing | attribution |
| **C-7** | Four absorb lengths are wrong: `b"mask-prox"` is **16,441** (not 16,438); `b"parameters"` is **171** (not ≥158; the literal is 113 bytes); `b"sc-round"` is **≥104** (not ≥88); `b"pb-term"` is absorbed **per slot**, 71…951 bytes (not once at 2,823). None is 64 | the 64-byte conclusion is unaffected |
| **C-8** | §4's refusal decomposition omits the shift in the law of `ρ` given completion. Use `d ≤ Pr_w[LogUp] + Pr_0[LogUp] + sup_{NR ρ} d(…) ≤ 2·2^-112 + ε_hash` | immaterial against 2^-77.7 |
| **C-9** | "14 of 18" refusal classes matches no grouping of the privacy case's own 18-row table: I read 10 shape/environment + 2 unreachable panics + 1 witness-builder + 4 challenge-driven + 1 witness-dependent | bookkeeping |
| **C-10** | Lemma H's conditioning list must include **the adversary's own `q` oracle answers**, and "independent of the unopened columns" should be replaced by "uniform **given** the unopened columns" — the columns may well be determined by (view, hidden data), and the lemma must not be readable as a claim about their entropy | wording, but load-bearing wording |
| **C-11** | "the whole view" (§0, §5.2) must name its exclusions in the same sentence: the refusal **string** (a declared GAP), `ProveStats`'s timings (D20), and anything a capture format might gain beyond the three files `native_capture.rs:275` writes | the body is careful; the summary is not |
| **C-12** | The 2^-77.7 figure is attributed to D9, which accepts the per-draw 2^-96 and the figures 2^-75 / 2^-72.9 / 2^-71.7 at other shapes. The toy-block figure rests on **327,052 draws**, hard-coded with no derivation. **I derived it exactly** (§1.1) — put the derivation in the page | the number is right to the unit |
| **C-13** | §0's "one thing this page found" states the M-3 saving without the two conventions it costs; §5.1 states it carefully. Move the qualification up | presentational |

### C. OMITTED CONDITIONS — things an acceptance must carry that the page does not list

| # | condition |
|---:|---|
| **O-A** | **The three conditions the J-2 review added to (H1)** (see B-1). Every conclusion of the page inherits them |
| **O-B** | **Privacy-case O-1**: the 32-byte `IoSpec::context` rides inside the 112-byte policy, which the sentence puts *in the view*. If a deployment derives it from the request, the two worlds do not share a statement. This is a **hypothesis of the sentence**, not an out-of-scope item as §6.7 files it |
| **O-C** | **C-H4′** (new, from this check): no accepted private profile may have a `Transcript::new` domain of length 28 or 35 — those give 40- and 47-byte seeds, the refill and challenge classes. The separating tag D19 already proposes for new profiles would close it |
| **O-D** | **Route B extends the sequential-kernel lemma's message alphabet** to `(field, hash)` pairs. Privacy-case item 17's carve-out (ii) says the reviewed lemma is about field messages only. The extension is legitimate under the joint per-`ρ` hypothesis, but the page must say it is extending, not applying |
| **O-E** | **D21's capture rule is a hypothesis of the sentence**, because the sentence's view is exactly what a capture contains |
| **O-F** | The **non-adaptivity of the generator's query points** (`key ‖ le64(counter)`, `rng.rs:53-57`) is what makes both §5.1 and Route A's reordering work. State it |
| **O-G** | Three conditions that are TRUE today and cheap to pin, none pinned: **C-H1** (a test that a receipt's distinct salts ≤ its distinct opened indices), **C-H4** (an assertion beside `assert_eq!(M_ROWS, 50)` in `layout.rs`, **not** in `zkp-core`), **C-H8** (assert the block's stores are `Store::Host`). C-H6 is **already** pinned by the compile-fail doctest at `private_block.rs:360-366`, which the draft does not know |

### D. What I confirmed and would not want lost

1. Every term of ε(q) reproduces exactly from my own script.
2. **327,052 fp draws** — derived independently, exact agreement.
3. **2^-241.42 beats 2^-243**; four documents need the fix, one of them the
   owner-facing page. And the true bound is nearer **2^-497.42**.
4. **47 is unique.** Unconditionally, on every path.
5. **Lemma H rests on the salt alone** and never uses column entropy.
6. **`rows ∈ {5, 8}` is impossible for the endpoints by construction**
   (`{6,7,9,13,21}`) and absent by accident for `A`, `H`, `M`.
7. **No hash object in a receipt, a capture or a log is a function of an
   unopened column or an unpublished salt** — I redid that source reading
   and widened it to `ProveStats`, the wire envelope and `last_mask_sites`.
8. **One policy admits at most one proof**, so no two proofs can share a
   challenge input — a stronger cross-proof fact than the union bound needs.
9. **No circularity**, and the quantifier order in Lemma H is the safe one.

**(check complete)**
