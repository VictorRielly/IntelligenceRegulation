# Route A re-examined for the toy under the complete query table — GAP-QC-5

**VERDICT ON D22: UNCHANGED WITH CLARIFICATIONS.** Every step of the accepted
argument's Route A survives tonight's findings on the toy profile as it stands
in the MAIN tree at `4751b93`; every number of the statement's §4 reproduces
from the code, and the one number whose *form* is wrong-footed (the 2^-112.0
refusal row, printed as a distance but derived one-world) is still a valid
upper bound in the form it is used, by 5.4 bits. Nine clarifying sentences are
recommended below (§7); none changes the statement's sentence, its 2^-77.7,
its residual figures or the seven conditions' substance. Nothing is suspended.

| | |
|---|---|
| Written by | an independent adversarial checker (delegated Opus agent), 2026-09-21 04:57 PDT |
| Asked | does the accepted argument for the toy (register D22, step 5 = "Route A") still hold, sentence by sentence and number by number, given what tonight's work on larger shapes established? — gap **GAP-QC-5** |
| Code read | MAIN at `4751b93` (`git show 4751b93:<path>`), the tree D22 covers. Where the lane `zk60-private-block-125m` at `fd45a67` differs, main is what D22 covers and the difference is named |
| Evidence | `results/zk60_toy_route_a_reexamination/` — two exact-arithmetic Python scripts, run, with their output. No build, no cargo, no proof, no git write |
| What it is not | not a privacy acceptance, not a re-derivation of the mathematics, not a soundness review. It is one reader's attempt to break the accepted argument with tonight's facts in hand |
| Labels | every number is **[COUNTED]** (from the code's constants), **[COMPUTED]** (exact arithmetic from counted inputs) or **[ARGUED]** (a reading) |

---

## 0. In plain words

The one privacy statement this project has says: whoever receives an accepted
toy receipt learns essentially nothing about the hidden input, and "essentially
nothing" is a number, about 2^-77.7. That statement's fifth and last step says
the hashing adds nothing, and it proves that with a chain of small steps called
Route A. Route A was written when the project believed the system made about
five different kinds of hash call. Last night's work on bigger shapes counted
the real number — twenty-six kinds plus six more sites in the same process —
and one open item said nobody had gone back to check Route A against the full
list. That is this page.

The short answer: Route A was never really working in a five-kind world. Its
own table already had eleven rows, and I re-derived every length in it from the
code and every one reproduces, including the four that matter (47 for a
challenge, 40 for the generator, 64 for a tree node or a salted leaf, and the
one 64-byte transcript absorb that collides with them). The new kinds tonight
found are either off the toy's path, in a different hash function, or already
recorded in prose in the same memo. Every number in the statement reproduces.

Two things are worth the project owner's attention and neither changes a
number. First, the two generators that seal the input and the output endpoint
are separated by **nothing at all** except the operating system handing out two
different random reads — they call the same function with the same domain
string. That was always true; it is now written down. Second, the statement
prints one residual as a "distance" when the arithmetic behind it is a
one-world probability; it happens to still be a correct distance bound because
the count it uses is 5.4 bits looser than it needs to be, but the page should
say which it is.

---

## 1. The toy's complete query table on MAIN at `4751b93`

Re-derived by `results/zk60_toy_route_a_reexamination/toy_query_table.py`
from the source constants only; every `file:line` is at `4751b93`. Geometry:
`A` 455 rows, `H` 384, `M` 50, two endpoints of 7; `log_cols 8`, `inv_rate 8`,
`Q = 256` pads, `256` opened columns; trees of `2048` leaves (`A`, `H`, both
endpoints) and `4096` (`M`) — **all four row counts and both tree sizes
verified** [COUNTED] (`private_block/layout.rs:523-526`, `:519`;
`private_block/protocol.rs:22`, `:184`; `hashline/src/zk.rs:373-375`).

### 1.1 Unkeyed BLAKE3 — under the legacy rule this is ONE function

| # | kind | `file:line` at `4751b93` | input layout | length (B) | calls / proof | input secret? |
|---|---|---|---|---:|---:|---|
| T1 | transcript constructor | `zkp-core/src/transcript.rs:25-30`, via `private_block/protocol.rs:30` | `"hashline-v1/"(12) ‖ PROFILE(39)` | **51** | 1 | no |
| T3 | absorb `"expected-IO"` | `protocol.rs:31` | `state ‖ le64 ‖ label ‖ le64 ‖ policy(112)` | **171** | 1 | no |
| T3 | absorb `"public-statement"` | `protocol.rs:32` | … ‖ digest(32) | 96 | 1 | no |
| T3 | absorb `"parameters"` | `protocol.rs:33` | … ‖ literal(113) | **171** | 1 | no |
| T3 | absorb `"calibration"` | `protocol.rs:35` | … ‖ digest(32) | 91 | 1 | no |
| T3 | absorb `"schedule"` | `protocol.rs:36` | … ‖ digest(32) | 88 | 1 | no |
| T3 | absorb `"A"` / `"M"` / `"H"` (a root) | `protocol.rs:40-44` (`:320`, `:377`), `:326` | … ‖ root(32) | **81** | 3 | no |
| T3 | `absorb_u64 "rows"` | `protocol.rs:42` | … ‖ le64 | 60 | 2 | no |
| T3 | **`absorb_u64 "log-cols"`** | `protocol.rs:43` | `state(32) ‖ le64(8) ‖ "log-cols" ‖ le64(8) ‖ le64(8)` | **64** | 2 | no |
| T3 | `absorb_u64 "pb-slot"` | `private_block/argument.rs:270` | … ‖ le64 | 63 | 23 | no |
| T3 | `absorb_fp2 "pb-scalar"` | `argument.rs:290`, `:321` | … ‖ 16 B | 73 | 23 | no |
| T3 | `absorb_fp2 "sc-round"` | masked rounds / `zk.rs:994` | … ‖ 16(d+1) B | **104 / 120 / 136** | 184 | no |
| T3 | `absorb_fp2 "pb-term"` | `argument.rs:350` | … ‖ 16·slot_terms B | **71, 87, 103, 151, 263, 295, 327, 391, 407, 951** | 23 | no |
| T3 | `absorb_fp2 "mask-q"` | `hashline/src/zk.rs:533`, `:562` | … ‖ 16384 B | 16,438 | 1 | no |
| T3 | `absorb_fp2 "mask-prox"` | `zk.rs:542`, `:565` | … ‖ 16384 B | 16,441 | 1 | no |
| T3 | `absorb_fp2 "pcs-vec"` | `zkp-core/src/pcs.rs:924-926`, `:981-983` | … ‖ 16·(256+256) B | 8,247 | 46 | no |
| T3 | `absorb_fp2 "pcs-prox"` | `pcs.rs:927`, `:987` | … ‖ 8192 B | 8,248 | 4 | no |
| T4a | **squeeze, live chain** | `transcript.rs:85-94` | `state(32) ‖ "squeeze"(7) ‖ le64(ctr)(8)` | **47** | **1,863** | no |
| T4c | **squeeze off a clone — the REFUSAL REPLAY** | `protocol.rs:173-174`, `:201-202`; against `pcs.rs:919`, `:835-855` | *identical points to T4a* | 47 | **1,027** | no |
| P1/P2 | column digest (`A` / `H` / `M` / endpoint) | `pcs.rs:137-143`, `:147-166`; `zk.rs:592-595` | the column's `rows` words, LE, **no tag, no length prefix** | **3,640 / 3,072 / 400 / 56** | 12,288 | **yes** (unopened) |
| P3 | **salted leaf** `blake3(digest ‖ salt)` | `pcs.rs:640-645`, used `:689`; `zk.rs:464` | 64 untagged bytes | **64** | **12,288** | **yes — the salt** |
| P4 | **Merkle inner node** `blake3(l ‖ r)` | `zkp-core/src/merkle.rs:14-19` | 64 untagged bytes | **64** | **12,283** | yes, above unopened |
| R2 | **generator refill** (XOF → 8,192 B) | `zkp-core/src/rng.rs:53-61` | `key(32) ‖ le64(counter)(8)` | **40** | ~1,300 | **yes — the key** |
| D1 | calibration identity | `private_block.rs:96-98` | `b"B3 public fixed calibration v1"` | 30 | 2 | no |
| D2 | block public-statement digest | `private_block.rs:260-266`, framing `:155-166`, `:221-231` | literal(31) ‖ length-framed public words | **6,311** | 2 | no |
| D3 | block schedule digest | `layout.rs:678-686` | literal(33) ‖ Σ(le64(len) ‖ line), 35 lines | **3,205** | 2 | no |
| D8 | frozen-seam spec digest | `private_seam.rs:115-133` | `DOMAIN(28) ‖ ctx(32) ‖ 8×u64 ‖ i32` | **128** | 6 | no |

### 1.2 Keyed BLAKE3 — a different function (convention V-2)

| # | kind | `file:line` | input | length | key | calls |
|---|---|---|---|---:|---|---:|
| R1 | generator seed derivation, **block** | `rng.rs:44-51` via `protocol.rs:275` | `"hashline-zk-os-rng/v1/"(22) ‖ PROFILE(39)` | **61** | 32 B of `/dev/urandom` | 1 |
| R1 | generator seed derivation, **each endpoint** | `rng.rs:44-51` via `private_seam.rs:196`, reached twice from `private_block.rs:384-385` | `"hashline-zk-os-rng/v1/"(22) ‖ seam DOMAIN(28)` | **50** | 32 B of `/dev/urandom` | **2, with byte-identical inputs** |

### 1.3 In the same process but off the proof path

Reached from `BlockPublic::synthetic_fixture()` (`private_block.rs:171-177`,
**not** `#[cfg(test)]`) → `causal_oracle::public_synthetic_fixture`
(`causal_oracle.rs:32`, `:67`):

| `file:line` | what | length |
|---|---|---|
| `causal_oracle.rs:98` | unkeyed BLAKE3 of a 37-byte literal (model identity) | 37 |
| `causal_oracle.rs:194` | unkeyed BLAKE3 of the **same 30-byte literal as D1** | 30 |
| `causal_oracle.rs:577-593` (`cpu_commit`) | a **second call site of `hash_columns` + `MerkleTree::build`**: two **UNSALTED** trees over the public weights, 4 rows and 3 rows (`AttnLayout` `w_len = 1024`, `attention.rs:1083`; `LayoutV3` `w_len = 768`, `zkp-core/src/ffn_v3/statement.rs:170`) — so 2 × 2,048 column digests of **32 and 24 bytes** and 2 × 2,047 further **64-byte** node inputs | 32 / 24 / 64 |
| `private_block_contract.rs:545` | unkeyed BLAKE3 over a framed registration buffer (a different profile's precheck) | large |
| `zkp-core/src/tables.rs:134`, `tables_attn.rs:125`, `:166` | **SHA-256** table-spec digests — a different hash function | — |

`private_block/wire.rs` hashes nothing [COUNTED]; `audit_claims`
(`protocol.rs:89-133`) hashes nothing; `check_opening` only clones the
transcript and squeezes (row T4c). `Receipt::to_bytes` / `from_bytes`
(`private_block.rs:452-460`) each rebuild the header transcript, so
`verify_bytes` issues the header's six query points **twice** — the same
points, the same answers, exactly like the refusal replay.

### 1.4 What the table settles, from my own enumeration

* **37 distinct unkeyed input lengths; exactly THREE genuine clashes** [COUNTED]:
  **64** (`absorb "log-cols"` / salted leaf / Merkle node), **81** (the three
  root absorbs `"A"`, `"M"`, `"H"`), **171** (`"expected-IO"` / `"parameters"`).
  This is the lane's stage-25 count for the toy, reproduced independently
  (ruling J-7's "three legacy clashes, not four").
* **47 is occupied by nothing else on the toy's path** [COMPUTED] — 47 is not
  a multiple of 8 (so no column digest), the shortest absorb is 60, the
  constructor is 51, the refill is 40, leaves and nodes are 64, the digests are
  30 / 128 / 3,205 / 6,311. **The D19 register row's "challenges are 47-byte
  queries, a length nothing else uses" stands for this profile.**
* **40 is occupied by nothing else on the toy's path** [COMPUTED] — the two
  40-byte `Transcript::new` seeds of the crate (`private_seam.rs:26`,
  `public_block_receipt.rs:20`) are off it; no commitment on the path has 5
  rows (455 / 384 / 50 / 7 / 7, and the two fixture weight trees have 4 and 3);
  no `8·rows` on the path is 40.
* **The toy hash-layer memo's own absorb enumeration (§1.5) is COMPLETE and
  every length in it reproduces**, including `b"calibration"` at 91. (J-8's
  "the calibration absorb is in no list of the memo's" is about the newer
  joint-sentence memo's §5.1, not about the toy memo.)
* **One-byte margins at the toy** [COMPUTED]: `pb-slot` 63 / `log-cols` 64;
  `pb-term`(2) 87 / `schedule` 88; **`pb-term`(3) 103 / `sc-round`(d=2) 104**;
  **`pcs-vec` 8,247 / `pcs-prox` 8,248**; and across the mode boundary the seam
  seed derivation 50 / the constructor 51, and `"rows"` 60 / the block seed
  derivation 61. The last two of the unkeyed four are **not** in the
  joint-sentence memo's §7 list; conversely its "`pb-term`(6) 151 vs
  `sc-round` at degree 5 = 152, every profile" **does not exist at the toy**,
  whose slot degrees are 2, 3 and 4 only (`layout.rs:438-462`), so its
  `sc-round` absorbs are 104 / 120 / 136. None is a clash.

---

## 2. Route A, hop by hop, against the complete inventory

`ZK60_HASH_LAYER_AND_FS_LIFT.md` §3.3. For each hop: what has to be disjoint,
collision-free or otherwise true, and whether tonight's table breaks it.

| hop | what it changes | what it needs from the query table | still true at the toy on main? | cost, recomputed |
|---|---|---|---|---|
| G_0 → G_1 | lazy sampling | nothing | yes, by definition of the ROM (D19) | 0 |
| G_1 → G_2 | all generator output sampled up front | the refill points are **non-adaptive**: `key ‖ le64(counter)`, fixed by the key alone | **yes, and for all three generators** (`rng.rs:53-57`). Each generator's points are `key_i ‖ 0,1,…`; adaptivity is a per-generator property and holds for each | 0 |
| G_2 → G_3 | the stream is uniform | primary: assumption **M-3** on `ZkRng`. In-model alternative: no query of `D` begins with one of the **three** keys, nor hits the keyed seed-derivation point | yes. **`6q·2^-256` is correct *because* there are three generators**: 3 keys × 2 routes (guess a key; guess the 32-byte OS entropy and recompute the key through the keyed function on a public 61- or 50-byte input). Not per-generator to be multiplied again | `ε_PRG`, or `q·2^-253.415` [COMPUTED] |
| | | **and** that the three keys are independent | **this is where the toy is thinnest — finding B-1.** The two endpoint generators' key-derivation inputs are **byte-identical**; only the two `/dev/urandom` reads separate them | assumption (J-2) |
| G_3 → G_4 | real blinding → uniform blinding | the `fp()` draws sit at schedule-determined positions, are independent given a uniform stream (16 disjoint stream bytes each, `rng.rs:63-77`; `RNG_BLOCK = 8192` is a multiple of 8, so no draw straddles a refill), and the salts need no replacement (`bytes32` is raw stream, `rng.rs:93-99`) | yes. **327,052 `fp()` draws re-counted call site by call site** [COUNTED], agreeing exactly with the memo's table | **2^-77.6808** [COMPUTED] = 327,052 × 2^-96, the per-draw **distance** (the rejection region is 2^-64 — 32 bits larger — and is never used here: ruling **K-R4a** is satisfied, Route A takes the sampler as a distance hop and never as an event) |
| G_4 → G_5 | abort on `B_H` | (a) no salt guessed; (b) no two salted-leaf inputs equal; (c) no salted-leaf input equal to the one 64-byte absorb; (d) no salted-leaf input equal to a node input | yes. The new kinds add nothing at 64 bytes on the CPU path. The fixture's two public-weight trees add 4,094 further 64-byte node inputs **in the same process** — under the "one global unkeyed function on one machine" reading that moves (c) from 24,571 to 28,665 objects, i.e. 2^-241.42 → **2^-241.19**, and (d) by 0.2 bits. Immaterial | `q·2^-242.415 + 2^-229.830 + 2^-241.415 + 2^-484.831` [COMPUTED] |
| G_5 → G_6 | abort on B1–B5, B7 | **B1** the live challenge chain never repeats an input; **B2** 47 meets no other class; **B3** no pre-query; **B4** no two absorb inputs collide; **B7** no challenge before `a_root` is absorbed | yes — with one wording repair. **B1 is true of the live chain and false of the prover's calls**: the refusal replay re-issues 1,027 squeeze points per proof, and `verify_bytes` re-issues the header's six. Both are the *same points at the same history*, so the lazy-sampling table answers identically (finding B-5). **B7 verified on main**: `protocol.rs:320` (absorb `A`) precedes `:330` (first challenge) | `q·2^-244.034 + 2^-233.069` [COMPUTED], both on the memo's **bound** `A ≤ 4,000`; counted here: **317 absorbs + 1,863 distinct live squeeze points = 2,180 points** (3,207 calls with the replay), so the bound holds with room |
| G_6 → G_7 | challenges drawn uniformly in advance | each squeeze input fresh (B1), met by no other class (B2), not pre-queried (B3) | yes. **The argument uses uniqueness of the POINT, not of the call, and that is what survives.** Checked in the code: between `check_opening` and `open_zk` **no absorb intervenes** on either side (`protocol.rs:396-407`; verifier `:458-477`), so the replay's points are exactly the live chain's next points and the repeated query returns the value already sampled, uniform given the same history | 0 |
| G_7 → G_8 | split on refusal; apply Theorem 3.3 × Lemma H | the refusal decision at a non-refused ρ is a function of ρ and public data alone, up to the one witness-dependent class | yes. `check_opening_challenges` draws from a **clone** (`protocol.rs:173-174`) so the decision never advances the live transcript; the four challenge-driven classes are functions of ρ alone; exactly one class (a zero LogUp denominator) is witness-dependent | the memo writes **`2 · 2^-112.0`**; the statement's §4 prints `2^-112.0` — finding **B-2** |
| G_8 → G_8′ | `w := 0` | the all-zero input is admissible | relies on the measurement (`zero_witness_tests.rs`) — unchanged | 0 |

**The "five-kind world" question, answered.** Route A never worked in a
five-kind world: its §1.4 table has eleven rows and its §3.3 split is
`(O_47, O_64, O_40, O_rest)`, which is exactly the partition the length table
supports. The five-way partition ruling **K-R2** calls incomplete is the
*sequential-kernel* draft's, not the toy lift's. Every one of the eleven rows
reproduces from the code at the toy (§1.4).

**J-1's false premise is not Route A's.** Ruling J-1 holds that "the oracle is
independent of the prover's randomness" is false as a premise, because the
refill is an unkeyed query in the very function a distinguisher queries. Route
A does not assume it: §3.3 *derives* the independence it needs from the length
split (`O_47` against `O_40 ∪ O_64 ∪ O_rest`), and prices the one place the
generator's function is exposed (`ε_gen`). **Route A also already takes J-1's
two hops in J-1's ruled order** — generator first (G_2 → G_3), sampler second
(G_3 → G_4). [ARGUED, from the memo's text against the code.]

---

## 3. Every number of the accepted statement's §4, re-derived

`results/zk60_toy_route_a_reexamination/toy_residuals.py` (exact integers /
`fractions.Fraction`; `p = 2^64 − 2^32 + 1`).

| statement's figure | what it is | the form the statement uses it in | recomputed | verdict |
|---|---|---|---|---|
| **2^-77.7 per proof** | `N · 2^-96`, `N` = `fp()` draws | a **distance**, the dominant residual | `N = 327,052` [COUNTED]; per-draw TV `b(p−b)/(p·2^128)` with `b = 2^128 mod p = p − 2^32`, **exactly 2^-96.000000**; product **2^-77.6808** [COMPUTED] | **reproduces**, and the hop is a distance hop, never an event (K-R4a satisfied). *Caveat B-3: 2^-77.6808 is larger than 2^-77.7; "about" carries it, "≤ 2^-77.7" would not* |
| **2^-57.7 at 10^6 proofs** | `10^6 · N · 2^-96` | distance, linear growth | **2^-57.7493** [COMPUTED] | **reproduces** (and is genuinely ≤ 2^-57.7) |
| **2^-112.0** | the one input-dependent refusal class | printed **"distance"**; §2 uses it one-world ("refusal is, up to 2^-112, a function of the challenges alone") | denominators inverted per proof: U8 61,440 + exp 2,048 + act 512 + table 768 = **64,768** [COUNTED]; one-world `64,768/p² =` **2^-112.017**; distinct arguments (≤ 3 × 256) `768/p² =` **2^-118.415** (= ruling S-4); two-world unions **2^-111.017** and **2^-117.415** | **reproduces as a one-world bound; still valid as a distance** because `2 × 2^-118.415 = 2^-117.415` is **5.4 bits below** the printed 2^-112.0. Form needs a sentence — finding **B-2** |
| **`q · 2^-242.4`** | guessing an unopened leaf's salt | distance | `N_leaf = 4·2048 + 4096 = 12,288` [COUNTED]; `12,288 · 2^-256 =` **`q·2^-242.415`** [COMPUTED] | **reproduces**, and is conservative: using only the ~11,077 never-opened leaves gives `q·2^-242.565` |
| **2^-229.8** | two salted-leaf inputs coincide | distance | `C(12,288, 2) · 2^-256 =` **2^-229.830** [COMPUTED] | **reproduces** (the largest hash-layer term below `q = 2^12.6`) |
| **2^-233.1** | two absorb inputs collide | distance | `C(4,000, 2) · 2^-256 =` **2^-233.069** [COMPUTED] — **on a BOUND, not a count** | **reproduces the bound.** Counted here: 317 absorbs → 2^-240.39; 2,180 absorb+squeeze points → 2^-234.82. Bound holds |
| **2^-241.4** | the 64-byte absorb overlapping the node/leaf format | distance | `N_overlap = 12,283 + 12,288 = 24,571` [COUNTED]; `· 2^-256 =` **2^-241.415** [COMPUTED] | **reproduces.** (Mechanism note, per J-4/B-8: the figure is one 2^-256 per overlapping object because each object's second 32 bytes must equal a fixed public constant — *not* "a digest spelling 24 fixed bytes", which would be 2^-192) |
| **`q · 2^-244.0`** | challenge pre-query (B3) | distance | `4,000 · 2^-256 =` **`q·2^-244.034`** [COMPUTED], on the same bound | **reproduces**; counted, `q·2^-244.9` |
| **`6q · 2^-256`** (ASSUMED) | the generator, in-model alternative | assumption | `= q·2^-253.415` [COMPUTED]. **`6q` is right for three generators**: 3 keys × 2 routes | **reproduces; `6q` already accounts for all three.** It would be wrong to multiply it by three again |
| **2^-62.0** | refusal on degenerate challenges | **liveness, not distance** | one proximity determinant over `Fp` vanishes with probability `(p³+p²−p)/p⁴ =` 2^-64.000; four sites (`protocol.rs:396`, `:399`, `:402`, `:405`) → **2^-62.000** [COMPUTED]; the 222 `Fp2`-valued refusals contribute 2^-119.2, 57 bits smaller | **reproduces**, and the "four base-field determinants, `4/p`" derivation is the right one |
| *(absent)* | a salted-leaf input equals a node input | — | `12,283 · 12,288 · 2^-512 =` **2^-484.831** [COMPUTED] | **missing from §4's table** — finding **B-9**. Immaterial in size; the table reads as exhaustive |

**The sum, at the statement's own ceiling** [COMPUTED]: hash layer
2^-228.837 at `q = 2^12`, 2^-192.008 at 2^50, 2^-162.008 at 2^80,
**2^-114.008** at 2^128 — reproducing the memo's `ε_lift` line exactly. Total
`ε(q)` at `q = 2^128`: **2^-77.680839488937** with the one-world refusal,
**2^-77.680839488870** with the two-world union, **2^-77.680839489002** with
the two-world *distinct* count. **The three agree to ten decimal places: the
refusal row's form cannot move the headline at any `q`.** The margin of the
sampler term over the query-dependent hash term at `q = 2^128` is **36.7 bits**
(reproducing the errata pass's correction to J-4).

---

## 4. The seven conditions of §5 against tonight's findings

| # | condition | true on main at `4751b93`? | what tonight changes |
|---|---|---|---|
| 1 | one reserved mask pair per claim site, shape `(cm, cm·U)`; `audit_claims`' pair-exclusivity is the whole defence | **yes** — `protocol.rs:89-133` (every reserved pair used by exactly one claim; a zero coefficient refused; only the last, sum, claim may be pairless and must cover both zero-sum rows); the `(cm, cm·U)` shape at `argument.rs:232-234` | nothing |
| 2 | the pad count equals the number of opened columns, per row, always | **yes** — `ZkOpts::standard` sets `q_pad = num_col_checks = 256` (`pcs.rs:542-543`), asserted `≥` at `pcs.rs:670`; `M` uses `MASK_Q = 256` pads per mask row (`zk.rs:445`) against `MASK_Q = 256` opened columns | nothing |
| 3 | `d+1` values per round; the exact-row-span assertions; refusal on a zero mask challenge; the declared functional order | **yes** — zero-`c` refusal `argument.rs:275-277`; degenerate terminal challenge `:347-349`; zero batching challenge `nonzero()` `argument.rs:493-498`; the functional count checked `argument.rs:926-928` | nothing |
| 4 | one opening per commitment; a refusal is terminal, enforced by the type system | **yes** — `Endpoints` taken by value (`private_block.rs:430`), `PreparedPlane` has no `Clone` (`private_seam.rs:142-147`), compile-fail doctest `private_block.rs:360-368`; each owner dropped after its single opening (`protocol.rs:398`, `:401`, `:404`, `:407`) | **and now**: `ZkRng` has no `Clone` either (`rng.rs:9-14`) — the generator cannot be forked, by the type system (J-8). Free to record |
| 5 | every Merkle leaf salted with 32 fresh bytes; no unsalted column digest ever published, logged or captured | **yes for the profile's five commitments.** The capture writer emits only `(index, values, salt, path)` (`native_capture.rs:64-71`), transcript **states** (public, recomputable) and public digests; the only stdout line is `NATIVE_CAPTURE profile=… sha256=… slots=…` (`:280`) and carries no digest of a column; `ProveStats`' three lookup totals are geometry constants (61,440 / 2,048 / 512), not witness values | **read literally it is false of the process**: `BlockPublic::synthetic_fixture()` builds two **unsalted** Merkle trees over the *public* weights (`causal_oracle.rs:577-593`). No hidden data is in them. Scope the condition — finding **B-7** |
| 6 | fresh operating-system randomness per proof; no seeded configuration on this profile's path | **yes** — `ZkRng::from_os` only, at `protocol.rs:275` and `private_seam.rs:196` (twice); `ZkRng::new(seed, …)` is unreachable from the block | **under-specified.** There are **three** reads per proof, not one; their mutual independence is load-bearing; and the two endpoint reads are behind **no** domain separation at all — finding **B-1** |
| 7 | the source pins: a change to any pinned Rust file suspends step 3 | **yes**, and now 29 files (note of 2026-09-20 23:57) | it now also covers, de facto, the hash-layer memo's own code conditions C-H4 (`rows ∉ {5,8}`) and C-H4′ (no 28/35-byte transcript domain), since `layout.rs`, `private_seam.rs` and `rng.rs` are pinned. **Those conditions are not named in §5** — finding **B-8** |

**Is a condition missing?** Three candidates, all cheap and none substantive:

* *"every word the transcript absorbs is public"* — hypothesis (v) of the
  hashed sequential-kernel lemma (ruling K-R4). **True by construction here**:
  `verify_inner` recomputes the prover's absorb sequence site for site
  (`protocol.rs:438-477` against `:279-407`), so a word the verifier could not
  recompute would fail the receipt. Route A does not name it as a hypothesis
  and does not need it, but it is worth one free sentence.
* *"the generator is never cloned"* — type-enforced (`ZkRng` is not `Clone`).
* *the CPU-path scope* — **already added** on 2026-09-21 03:23 (J-3).

---

## 5. Does any accepted sentence rely on something now known to be false?

Searched: the statement, its draft, the five dispositions §3 cites
(`ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md`,
`ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md`,
`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`,
`ZK60_TERMINAL_SURJECTION_REVIEW.md`,
`ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md`) and the register rows D19–D22.

| now-known-false thing | found in an accepted sentence? |
|---|---|
| "the lemma holds for **arbitrary challenge functions**" (correction K-1) | **No.** The phrase occurs only in `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md:1183` and its disposition `:132` (the *run*, which has no accepted statement) and in the sequential-kernel memo's own comparison table. Ruling K-R3's finding — that the fixed-challenge hypothesis needed is about the **joint** law of field values, published salts, hash objects and flag — is exactly the form Lemma H and Theorem 3.3 are composed in in Route A (§2.1's factorisation `law(V) · law(H | V)`), so the toy does not inherit the gap |
| "the generator is a **keyed** BLAKE3 stream" | **Not in the statement.** §2 says only "the prover's randomness generator's output stream is indistinguishable from uniform". The register already records the correction (row **D19b**: "the randomness generator is **not** keyed (only its key derivation is; its stream is unkeyed BLAKE3 over key and counter)"). The phrase survives in `ZK60_PRIVACY_CASE_FIRST_MVP.md:220` and `ZK60_JOINT_LAW_COMPOSITION.md:803`, neither of which is an accepted sentence, and the hash-layer memo corrects it in place at `:1197` |
| "the oracle is **independent of the prover's randomness**" as a **premise** | **No.** The only occurrence in the toy line is `ZK60_HASH_LAYER_AND_FS_LIFT.md:1569` — label row 22 — where it is a **conclusion** ("the oracle splits by input length into independent restrictions, **so** the challenge function is independent of the prover's randomness", labelled PROVED HERE). That is J-1's own ruled reading |
| "challenge queries are **unique unconditionally**" (the L-disposition's §1 bullet) | **Present and imprecise, not false.** `ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md:27` reads "Challenge queries are 47 bytes, unique unconditionally." Read as *the 47-byte class is occupied by nothing else, and the live chain never repeats an input*, it is true and reproduces (§1.4). Read as *no oracle point in the 47-byte class is ever queried twice*, the refusal replay refutes it. The load-bearing use — hop G_6 → G_7 — is the first reading. Finding **B-5** |

---

## 6. Findings, most serious first

**B-1 — the two endpoint generators are separated by nothing but two
`/dev/urandom` reads.** `private_block::prepare_endpoints`
(`private_block.rs:377-388`) calls `private_seam::prepare` twice, and each call
constructs `ZkRng::from_os(DOMAIN)` with the same constant
`DOMAIN = b"experimental-private-seam/v1"` (`private_seam.rs:26`, `:196`). The
two key-derivation inputs are therefore **byte-identical** (`"hashline-zk-os-rng/v1/"(22) ‖ DOMAIN(28)`,
50 bytes); the `SeamSpec` — which *does* differ between the two endpoints
(slots 41/42 against 43/44, `private_block.rs:314`) — never reaches the
generator. If the two operating-system reads returned the same 32 bytes, the
input and output endpoint commitments would share every pad, every salt and
every mask row, and condition C-H5 ("no salt or blinding value is reused across
commitments") would be false. The block's own generator *is* separated
(`PROFILE`, 39 bytes → a 61-byte input); the two endpoints' are not separated
at all. **Size**: 2^-256 under the assumption J-2 now names (independent
uniform OS reads); **unbounded** if that assumption fails, which is exactly why
it should be visible where it is used. **Smallest repair**: one sentence in
condition 6 (§7 below). A code repair — feed the `SeamSpec` digest into the
seam generator's domain — changes proof bytes and so belongs to a *new*
profile, not to the frozen toy; it is worth one line on the lane's work list.

**B-2 — the 2^-112.0 row is printed as a distance and derived one-world.** §4
labels it "distance"; §2 uses it one-world. The memo's own hop G_7 → G_8 costs
`2 · 2^-112.0` and its §4 derivation is `d ≤ 2·2^-112.0 + ε_hash`
(correction C-8). **Nothing changes**, because the coefficient the statement
carries is the *all-denominator* count 64,768 while the correct one-world
figure is the *distinct-argument* count 768 (ruling S-4), so the two-world
union is 2^-117.415 — 5.4 bits **below** the printed 2^-112.0 [COMPUTED].
**Smallest repair**: one sentence saying which form the figure is in.

**B-3 — 2^-77.7 is a rounding of 2^-77.6808, and the rounding is the
optimistic way.** 327,052 × 2^-96 = 2^-77.68084 > 2^-77.7. The statement says
"within **about** 2^-77.7", which carries it; `ZK60_HASH_LAYER_AND_FS_LIFT.md:1278`
says "**≤** 2^-77.7", which does not. (The sequential-kernel disposition already
writes 2^-77.68.) The memo's "eleven significant figures, 2^-77.699999999915"
is a sum computed on its own rounded leading term; the exact sum at `q = 2^128`
is 2^-77.680839488937 [COMPUTED]. **Smallest repair**: print 2^-77.68 beside
2^-77.7 once in §4.

**B-5 — "every challenge input within one proof is distinct" is false as
written; the argument uses the right thing anyway.** `check_opening`
(`protocol.rs:173-174`) and `check_endpoint_opening` (`:201-202`) clone the
transcript — `Transcript::clone_state` copies state **and** counter
(`transcript.rs:139-142`) — and draw exactly the `Σ members + rows` challenges
that `open_zk` (`pcs.rs:919`, `zk_rhos` `:835-855`) draws next, with **no
absorb in between** on either side (`protocol.rs:396-407`; `:458-477`). That is
**1,027 squeeze points per proof re-issued by the prover and again by the
verifier** [COUNTED], plus the header's six points re-issued by `verify_bytes`
(`private_block.rs:459`, `:470`). The memo's §3.1 second bullet records the
replay and says it "does not enter any bound", which is right; its first bullet
and bad event **B1**, read alone, are not. Hop G_6 → G_7 needs *point*
freshness in the live chain, which holds, and a repeated query at the same
`(state, counter)` returns the value already sampled — uniform given the same
history. **Smallest repair**: "pairwise distinct **along the live chain**" in
§3.1 and in B1; the disposition's "unique unconditionally" gets the same
qualifier.

**B-7 — condition 5, read literally, is false of the process.**
`BlockPublic::synthetic_fixture()` (`private_block.rs:171-177`, **not**
`#[cfg(test)]`) reaches `causal_oracle::cpu_commit` (`:577-593`), which builds
two Merkle trees whose leaves are **unsalted column digests** — of the public
synthetic weights. No hidden value is in them, and their row counts (4 and 3)
put their column digests at 32 and 24 bytes, so C-H4's `rows ∉ {5,8}` survives
when extended to them. Their 2 × 2,047 internal nodes do add 64-byte unkeyed
inputs to the process, moving the 2^-241.415 overlap row to 2^-241.19 under the
"one global unkeyed function on one machine" reading [COMPUTED]. **Smallest
repair**: scope condition 5 to the profile's five commitments.

**B-8 — the seven conditions do not name the hash-layer memo's own code
conditions.** Its §5.2 item 5 says C-H1 … C-H8 and C-H4′ "must be printed with
the sentence, every time"; §5 of the statement names none of them. All are true
at the toy today — `rows ∉ {5,8}` (455/384/50/7/7, and the fixture's 4 and 3),
no 28- or 35-byte transcript domain on the path (`PROFILE` is 39 → 51), no
device commit path (now also a scope exclusion, J-3) — and condition 7's
29-file pin set means none can change silently. **Smallest repair**: name C-H4
and C-H4′ inside condition 7's sentence.

**B-9 — §4's residual table omits the leaf-input = node-input term**,
`12,283 · 12,288 · 2^-512 = 2^-484.831` (ruling L-7 / correction C-4) — the one
pair on this path separated by **nothing** (`pcs.rs:640-645` against
`merkle.rs:14-19`, both `blake3(32 ‖ 32)`). Immaterial in size; the table reads
as exhaustive. **Smallest repair**: add the row.

**B-10 — the owed one-byte-margin test must be per profile.** Two margins exist
at the toy that the joint-sentence memo's §7 list does not have (`pb-term`(3)
103 / `sc-round`(d=2) 104; `pcs-vec` 8,247 / `pcs-prox` 8,248), and one margin
it attributes to "every profile" does not exist here (`pb-term`(6) 151 /
`sc-round`(d=5) 152 — the toy has no degree-5 slot). None is a clash; the point
is that W-2 as a *class* test has to be run per profile, and the toy's answer is
four unkeyed margins and two cross-mode ones (§1.4).

**B-11 — `2^-233.1` and `q·2^-244.0` still rest on an uncounted bound.** The
memo says so plainly ("I have not counted them exactly, and say so"). Counted
here for the first time: **317 absorbs, 1,863 distinct live squeeze points,
1,027 replayed squeeze points; A = 2,180 distinct points, 3,207 calls**
[COUNTED]. The bound `A ≤ 4,000` holds under the most generous counting. No
change needed; worth putting the count in the record so the next shape can diff
it.

---

## 7. The clarifying sentences recommended for the statement

Nine sentences. None changes the statement's sentence, any figure, or the
substance of any condition.

1. **§4, the 2^-112.0 row (new "Kind" wording).** *"One-world probability of
   the input-dependent refusal class (64,768 inverted denominators over
   |Fp2|); the distance a two-world hybrid needs is twice the tighter
   distinct-argument count, 2 × 768/p² = 2^-117.4, which this figure bounds by
   5.4 bits."*
2. **§4, the sampler row.** *"Exactly 327,052 × 2^-96 = 2^-77.68; written
   2^-77.7 throughout, which is a rounding and not an upper bound."*
3. **§4, a new row.** *"A salted-leaf input equal to a Merkle node input (both
   64 untagged bytes; ruling L-7) | 2^-484.8 | distance."*
4. **§5 condition 5, scope.** *"This condition is about the five commitments of
   this proof (`A`, `H`, `M` and the two endpoints). The public-weight Merkle
   trees that `BlockPublic::synthetic_fixture()` builds
   (`causal_oracle.rs:577-593`) are unsalted and contain no hidden value."*
5. **§5 condition 6, first addition.** *"Three fresh reads per proof, not one:
   the block's (`protocol.rs:275`) and one per endpoint
   (`private_seam.rs:196`, reached twice). The assumption of §2 is that the
   three are jointly indistinguishable from uniform, which includes that
   separate operating-system entropy reads are independent."*
6. **§5 condition 6, second addition — finding B-1.** *"The two endpoint
   generators derive their keys from **byte-identical** public inputs
   (`"hashline-zk-os-rng/v1/" ‖ "experimental-private-seam/v1"`, 50 bytes): the
   two `/dev/urandom` reads are the only thing separating them. At this profile
   there is no domain separation behind that assumption for two of the three
   generators."*
7. **§5 condition 4, one clause.** *"The generator is likewise not `Clone`
   (`zkp-core/src/rng.rs:9-14`): it cannot be forked, by the type system."*
8. **§5 condition 7, one clause.** *"The pin set is what keeps the hash-layer
   memo's code conditions true: `rows ∉ {5, 8}` for every commitment (C-H4) and
   no transcript domain of length 28 or 35 on this path (C-H4′) are properties
   of `layout.rs`, `private_seam.rs` and `rng.rs`, all pinned."*
9. **§3, step 5's row, or a footnote.** *"Route A's hop G_6 → G_7 uses
   uniqueness of the challenge *point* along the live chain, not of the call:
   the prover's refusal replay re-issues 1,027 of those points per proof
   (`protocol.rs:173-174`, `:201-202`) with no absorb in between, which returns
   the value already sampled and enters no bound."*

Recommended **outside** the statement, on the lane's work list: (a) extend
W-2's one-byte-margin class test to print per profile, with the toy's four
unkeyed and two cross-mode margins as its first fixture; (b) for any **new**
profile, feed the endpoint's `SeamSpec` digest into the seam generator's
domain, so that B-1's assumption has a structural backstop — byte-changing, so
never for the frozen toy.

---

## 8. What I could not check

* **The mathematics of Theorem 3.3 and of Lemma H.** I checked what Route A's
  hops *need* from the query table and the code, and every number in them; I
  did not re-derive the generic-rank lemma, the joint-law composition or the
  terminal-surjection step.
* **That `/dev/urandom` gives independent uniform bytes across three reads.**
  It is the assumption J-2 names; nothing in the code or in a hash model can
  establish it, and finding B-1 is about how thin the margin behind it is at
  this profile, not about the assumption itself.
* **The exact byte length of the schedule digest's input (3,205).** It depends
  on Rust's `Display`/`Debug` output for the 35 `describe()` lines
  (`layout.rs:652-676`), which I reconstructed rather than executed. Nothing
  rests on it: no other input kind on the path is within 500 bytes of it.
* **The accelerator.** Ruling J-3 puts a `gpu-cuda` build with `HL_GPU=1`
  outside D22, and I did not read the two CUDA kernels or the device/pinned
  buffer lifetimes. Everything here is the CPU path.
* **Soundness.** Not looked at, as the statement's §7 requires. The 64-byte
  leaf/node ambiguity is priced here for hiding only.
* **Whether the capture *format* has changed since the four captures were
  taken.** I read the writer on main at `4751b93`; I did not open a capture.
* **The lane's shaped code.** I read the lane's stage-25 separation table as a
  cross-check and agreed with its toy rows; I did not verify the lane's tests
  run, and D22 covers main, not the lane.
