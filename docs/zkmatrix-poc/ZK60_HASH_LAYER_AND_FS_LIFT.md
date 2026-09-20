# The hash layer (H6) as a random-oracle lemma, and the Fiat–Shamir lift of the fixed-challenge theorem

**Status: REVISED AFTER INDEPENDENT CHECK — the core is accepted for the toy
block in the random-oracle model, per
`ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md` (security owner, 2026-09-20):
the hash layer adds nothing a verifier can use, and the whole view of a
verifier making q oracle queries is within a listed sum of residuals of the
honest prover's view on the all-zero input. The random-oracle model is a
PROPOSED ruling (D19), not an accepted one. Blocking items B-1 … B-4, the
corrections and conditions of `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md` and
rulings L-1 … L-7 applied. NOT a privacy acceptance; D8 and D11 untouched;
every larger shape owes all of it again. Drafted by a delegated Opus agent.**

| | |
|---|---|
| Author | delegated Opus cryptographic drafter, working for the security owner |
| Baseline | working tree at `perf/zk-batch-optimizations`, `d4f34f8`, 2026-09-20 03:23 |
| Scope | the custom (hashline) line, toy profile `hashline-zk-mr1/private-block-t32-poc/1` only |
| Occasion | the last named GAP of `ZK60_JOINT_LAW_COMPOSITION.md` (its §5.2 and §6.1) and of `ZK60_PRIVACY_CASE_FIRST_MVP.md` (its items 14–17 and 28): **(H6) written as one random-oracle lemma with its query budget, and the sequential lift composed with it into a single argument** (condition O-4) |
| What it is | one argument in two halves — Lemma H (the hash layer) and the lift (Fiat–Shamir) — with every step labelled **PROVED HERE**, **MIXED**, **RELIES ON** (a named, cited fact), **VERIFIED IN THE CODE**, **COMPUTED**, **ASSUMED**, **CONDITION** or **GAP**, in the independent check's own labelling (§8) |
| What it is not | a privacy acceptance. The security owner accepted the **core** for the toy block, inside a model the project owner has not yet ruled on; this page does not establish a privacy property and does not close D8 or D11 |
| Review and ruling | independently checked by `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md` (evidence `results/zk60_hash_layer_fs_lift_check/`); ruled on by `ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md` (rulings L-1 … L-7). This revision applies the check's blocking items, corrections and omitted conditions and those rulings; where a ruling differs from the draft or from the check, the ruling wins |
| Runs | nothing was built, benchmarked, proved or verified for this document. One exact-arithmetic Python script was run (§7.1); every other number is read from a source line or from a cited document |

---

## 0. In plain words, before any notation

A receipt from the toy private block is two kinds of thing bolted together.
The **numbers** — a few hundred thousand field words the verifier does
arithmetic on — and the **fingerprints**: five 32-byte roots, 1,280 salts and
1,280 authentication paths of 32-byte hashes each. Overnight the project
accepted, for the toy block only and in an idealisation, that *the numbers'
joint law is the same whatever the hidden input was, once the random
challenges are fixed* (`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, the
verdict). Two things were then explicitly owed, and they are this page:

1. **The fingerprints.** A Merkle tree over 2,048 columns publishes about
   **40 % of its nodes** when 256 columns are opened, and about **212 of the
   revealed leaf hashes are hashes of columns nobody ever opens**. Those
   columns contain the hidden data. Why is publishing their hashes safe? The
   answer is one sentence — *each one is hashed together with a fresh 32-byte
   secret salt that is never published, so in an idealised model the hash is
   an independent random string that says nothing* — and this page writes it
   out as a lemma with a number attached to the word "nothing" (§2).
2. **The challenges.** The accepted theorem holds "at fixed challenges". In
   the real protocol nobody fixes the challenges: they are hashes of what came
   before, so they depend on the roots, which depend on the hidden input. This
   page writes the step from one to the other (§3), lists the accidents that
   could break it, and sizes each (§3.2).

**The honest shape of the result.** Inside the proposed random-oracle model
(D19, not yet ruled), the two halves compose: **everything a verifier is
given** — the 112-byte policy, the receipt (roots, salts, paths, field values
and challenges) and whether the prover refused — has a law that does
not depend on the hidden input, **up to a list of residuals whose sum is
dominated by something that has nothing to do with hashing**: the sampler bias
the project owner already accepted in D9, at about 2^-77.7 for one toy proof.
**The exclusions belong in the same sentence and are named here, not softened
later** (correction C-11 of the check): the refusal **string**, which is a
declared GAP (§4); `ProveStats`'s phase **timings**, proposed ruling D20; and
anything a capture format might gain beyond the three files
`native_capture.rs:275` writes, proposed ruling D21.
Every hash-layer term this page derives sums to below 2^-114 even against an
adversary allowed 2^128 oracle queries. That is the useful headline: *the hash
layer is not where the privacy budget goes.*

**What this page does not do, said before anyone quotes it.** It establishes
no privacy property. It works inside a model the project owner has not
accepted. It is about one shape (the toy block) and one configuration (the
prover seals, ruling D18); the 125M profile and the development rung owe all
of it again, and **D8 and D11 — a root fixed in advance by somebody else —
are untouched and are not closed by anything here**. One of its inputs is
itself not finished: the sequential-kernel lemma it leans on lives only
on branch `zk60-mvp-fable`. The accepted fixed-challenge theorem carries one
step that a check supplied and that **was independently reviewed and
corrected on 2026-09-20** (`ZK60_TERMINAL_SURJECTION_REVIEW.md`; ruling J-2
resolved at 03:49 in `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`) — and the
**three conditions that review added travel with the theorem wherever it is
cited here** (§2.1). Both are named where they are used.

**One thing this page found that was not in the earlier documents.** The
prover's random-number generator is *also* plain BLAKE3: `ZkRng::refill`
hashes `key ‖ counter`, 40 untagged bytes, through the same unkeyed function
that hashes the tree (`zkp-core/src/rng.rs:53-61`). That is a fourth
length class nobody had tabulated, and it is a genuine correction to the
privacy case's description of the stream ("a keyed BLAKE3 stream with a
counter", right about the derivation and wrong about the stream). It
collides with nothing **on the toy-block path** (§1.4).

**What the finding does and does not buy — ruling L-2, which overrides the
draft this page was.** The draft concluded from it that inside the
random-oracle model the separate "PRG assumption" (M-3) *is not needed*.
That conclusion is **withdrawn as the primary reading**. The privacy
statement keeps the **standard assumption** named by the privacy case's
ruling C-3 — the generator's whole output stream is indistinguishable from
uniform, for the BLAKE3-over-key-and-counter stream of
`zkp-core/src/rng.rs`. The in-model derivation is kept, clearly separated,
as an **ALTERNATIVE**, because it needs BLAKE3's extendable output to be
**indifferentiable** from a random oracle — not merely consistent as an
extendable output, which is all the "first 32 bytes of the XOF" property
gives (correction C-5). Read as that alternative, the generator's term is
`6q·2^-256` (the draft's `3q·2^-256` missed a second route: guessing the
32-byte operating-system entropy and recomputing the key — correction C-3).
§5.1 states both readings and the two modelling conventions the alternative
costs.

## 1. The hash layer, from the code

### 1.1 What a leaf is: the preimage, the salt, and where the salt comes from

Everything in this subsection is a source reading at a named line and is
re-readable there. **VERIFIED IN THE CODE** unless a sentence says otherwise.

**The object being hashed.** A ZK commitment holds a `rows × n` message matrix
(`n = 256` for `A`, `H` and the endpoints; `512` for `M`) plus `Q = 256` pad
symbols per row, encoded row by row into `rows × nn` evaluations on a coset
(`encode_row_zk`, `zkp-core/src/pcs.rs:618-637`; the coset generator is 7,
`ZkOpts::standard`, `:540-543`). A **column** is one coset position `j` taken
across all `rows` rows.

**The leaf preimage, in two stages.**

| stage | function | input | input length | output |
|---|---|---|---|---|
| 1 | `hash_column` (`pcs.rs:137-143`; tiled form `hash_columns`, `:147-166`; the byte-identical copy for `M` is `pcs_hash_column`, `hashline/src/zk.rs:592-595`) | the column's `rows` field elements, little-endian 8 bytes each, concatenated, **no tag and no length prefix** | `8·rows` bytes | a 32-byte digest `d_j` |
| 2 | `salt_leaf` (`pcs.rs:640-645`) | `d_j ‖ salt_j` | **64 bytes**, untagged | the leaf `ℓ_j` |

So a leaf is `blake3( blake3(column bytes) ‖ salt )`, exactly as
`ZK60_JOINT_LAW_COMPOSITION_CHECK.md` §A6.1 reads it. The verifier recomputes
that same two-stage preimage from the published column and the published salt
(`pcs.rs:1018-1021`; `zk.rs:576-577`), which is the fact §2 leans on: **for an
opened column the leaf is a public function of the field view and the
published salt.**

**The salt: 32 bytes, 256 bits, one per encoded column, from the proof's own
stream.** `ZkRng::bytes32()` (`zkp-core/src/rng.rs:93-99`) fills 32 bytes from
four `next_u64` calls. In a PCS commitment the pads are drawn first and then
**`nn` salts — one per encoded column, not one per opened column**
(`pcs.rs:673-674`); for the masking commitment the same, `dom = 4096` salts
(`hashline/src/zk.rs:462`). The stream is `ZkRng::from_os(domain)`, 32 bytes
of `/dev/urandom` through a keyed BLAKE3 into a 32-byte key, failing closed
on an unsupported host (`rng.rs:30-51`). Three streams exist per proof: one
for the block (`private_block/protocol.rs:275`) and one per endpoint
(`private_seam.rs:196`, called twice).

**Salts drawn versus salts published: 12,288 versus at most 1,280.**
`open_zk` emits `(index, column values, salt, path)` **per draw**
(`pcs.rs:930-941`); `mask_open` the same (`zk.rs:544-548`). Only the salt of a
*sampled* column ever leaves the process. With 256 draws per commitment the
receipt carries 1,280 salt slots and, because the draws repeat, about
**1,211 distinct salts** (§1.3); the remaining **11,077 salts stay inside the
prover and are dropped with the commitment**. That is the entire supply of
secrecy the hash layer runs on, and §2.5 records that publishing one of them
would destroy the argument for its column.

**The tree.** `MerkleTree::build` over the salted leaves
(`pcs.rs:689-690`; `zk.rs:464-465`), node `= blake3(left ‖ right)`, **64
untagged bytes** (`zkp-core/src/merkle.rs:14-19`), depth `log2(nn)` — 11 for
`A`, `H` and the two endpoints, 12 for `M`. A path is the sibling digest at
each level (`merkle.rs:46-54`), verified by re-hashing upward
(`:56-63`).

**What a receipt publishes of the hash layer, exhaustively.** Five roots —
`a_root`, `h_root`, `mask_root` in the receipt frame
(`hashline/src/private_block/wire.rs:71-99`) and the two endpoint roots inside
the 112-byte `ExpectedIo` policy (`private_block.rs:336-345`:
`8 + 32 + 4 + 4 + 32 + 32 = 112`), which the verifier must hold and which
every capture writes to disk — plus, per commitment, 256 salts and 256 paths
of 11 or 12 digests. **Nothing else of the tree is transmitted**: no unopened
salt, no unopened column, no internal state.

### 1.2 What a receipt publishes of each tree, counted

**COMPUTED** by `results/zk60_hash_layer_fs_lift/hash_layer_counts.py` (§7.1),
exact expectations under 256 uniform draws with replacement. The four
2,048-leaf rows **reproduce `ZK60_D8_D11_RESTATEMENT.md` §3.3 to the
displayed digit** (240.7 / 453.2 / 212.5 / 1,200.6 / 1,654.8 / 40.4 %), which
is the cross-check that the script is computing the same object. The `M` row
is new: no document had counted the masking commitment's tree.

| tree | rows | leaves `nn` | depth | distinct opened | leaf digests revealed | **of them, of columns never opened** | internal nodes revealed | total revealed | of `2nn−1` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `A` | 455 | 2,048 | 11 | 240.7 | 453.2 | **212.5** | 1,200.6 | 1,654.8 | 40.4 % |
| `H` | 384 | 2,048 | 11 | 240.7 | 453.2 | **212.5** | 1,200.6 | 1,654.8 | 40.4 % |
| input endpoint | 7 | 2,048 | 11 | 240.7 | 453.2 | **212.5** | 1,200.6 | 1,654.8 | 40.4 % |
| output endpoint | 7 | 2,048 | 11 | 240.7 | 453.2 | **212.5** | 1,200.6 | 1,654.8 | 40.4 % |
| `M` | 50 | 4,096 | 12 | 248.2 | 481.4 | **233.2** | 1,653.8 | 2,136.2 | 26.1 % |
| **one proof** | | **12,288** | | **1,211.0** | | **1,083.2** | | **8,755.3** | |

Two consequences worth stating in the lemma's language.

* **The unopened leaves are the whole of the problem, and there are 11,077 of
  them** (12,288 encoded columns minus 1,211 distinct opened). Of those,
  **1,083 have their leaf digest published** as a level-0 sibling; the other
  **9,994 reach the view only through an internal node above them**. §2.3
  covers both cases in one induction, so the split does not matter to the
  argument — but it matters to anyone trying to attack it, which is why it is
  printed.
* **The top pair is revealed with probability `1 − 2^-255`** at every tree
  (`ZK60_D8_D11_RESTATEMENT.md` §3.3, independently verified there): 256 draws
  miss one half of the tree only if all 256 land in the other. **PROVED**
  there, quoted here. Nothing in §2 needs the top pair to be hidden.

### 1.3 Sampling with replacement, and what it does to the counts

`Transcript::challenge_indices` draws each index by masking a 64-bit word to
the tree's width, with **no rejection of repeats**
(`zkp-core/src/transcript.rs:118-131`); `pcs.rs:1193` says so in a test
comment. The captures record **231–246 distinct** indices out of 256
(`ZK60_JOINT_LAW_COMPOSITION.md` §4.2, quoting the four real receipts);
the expectation is 240.7 at `nn = 2048` and 248.2 at `nn = 4096`.

Three effects, all small and all in the argument's favour, and one that is
not:

1. **Fewer distinct salts are published** than slots: 1,211 of 1,280. A
   repeated draw re-publishes a salt already published; it reveals nothing new.
2. **Fewer distinct columns are opened**, so *more* leaves stay unopened —
   1,807 per 2,048-leaf tree rather than 1,792. The hiding burden grows with
   the number of unopened leaves and so does the salt-guessing term of §2.4,
   by a factor 1,807/1,792. §7.1 uses the conservative count `nn` (every
   leaf) and so is not sensitive to this at all.
3. **Duplicate paths are emitted**, which is why the receipt carries 2,816
   path digest slots per 2,048-leaf tree while only about 587 distinct sibling
   digests exist (`ZK60_D8_D11_RESTATEMENT.md` §3.3). Duplication publishes no
   new object. **It does mean the receipt's hash material — 499,712 bytes,
   17.7 % of 2,816,472 — overstates the information content by about a factor
   of five**, which is a proof-size observation, not a privacy one.
4. *The one that is not in the argument's favour, recorded because it belongs
   to the field layer and this page must not be read as covering it:* with
   replacement, only a `d`-dimensional projection of each published pad half
   is pinned by the opened columns, `d = 231…246`, so `10…25` coordinates of
   each pad half are published independently of them
   (`ZK60_JOINT_LAW_COMPOSITION.md` §4.2, resolving its Q7). The check
   settled that those coordinates are supported on **pad** coordinates only
   and carry no data coordinate. **RELIES ON** that resolution; §3.4 uses it
   and does not reprove it.

### 1.4 Every oracle-query length class **on the toy-block path**, in one table — and the two classes elsewhere in the crate

The system has **no domain tags at all** on its BLAKE3 calls except the ones
that happen to be inside the hashed data (`Transcript::absorb`'s `label`,
`Transcript::new`'s `"hashline-v1/"`, the digest helpers' literal prefixes).
Two calls are in *keyed* BLAKE3 mode; every other call is plain unkeyed
BLAKE3 over one concatenation. So "which queries can coincide" has to be
settled by **input length**, and this is that table. It extends the one in
`ZK60_JOINT_LAW_COMPOSITION_CHECK.md` §A6.2 with the two randomness classes
and the public-statement digests, which no document had tabulated.
**Scope, corrected after the check (blocking item B-3): the table is of the
toy-block path, not of the whole crate.** Row Q11 records the two transcript
seeds elsewhere in the crate that share the 40-byte class; the independent
check re-derived the whole table and found four of the draft's absorb
lengths wrong (correction C-7, applied in §1.5), none of them at 64.

| # | query class | site | input | length (bytes) | mode | carries a secret? |
|---|---|---|---|---:|---|---|
| Q1 | **challenge draw** | `Transcript::squeeze_bytes` (`transcript.rs:85-94`) | `state(32) ‖ "squeeze"(7) ‖ le64(counter)(8)` | **47** | unkeyed | no (state is recomputable from the receipt) |
| Q2 | **transcript absorb** | `Transcript::absorb` (`:44-52`) | `state(32) ‖ le64(\|label\|) ‖ label ‖ le64(\|data\|) ‖ data` | **48 + \|label\| + \|data\| ≥ 60 on this path** | unkeyed | no |
| Q3 | **Merkle node** | `merkle::hash_pair` (`merkle.rs:14-19`) | `left(32) ‖ right(32)` | **64** | unkeyed | yes, above unopened leaves |
| Q4 | **salted leaf** | `pcs::salt_leaf` (`pcs.rs:640-645`) | `column digest(32) ‖ salt(32)` | **64** | unkeyed | **yes — the salt** |
| Q5 | **column hash** | `hash_column` / `hash_columns` (`pcs.rs:137-166`), `pcs_hash_column` (`zk.rs:592-595`) | `8·rows` bytes of field words | **3,640** (`A`), **3,072** (`H`), **400** (`M`), **56** (endpoint) | unkeyed | yes, for unopened columns |
| Q6 | **RNG refill** | `ZkRng::refill` (`rng.rs:53-61`) | `key(32) ‖ le64(counter)(8)`, XOF to 8,192 B | **40** | unkeyed **XOF** | **yes — the key** |
| Q7 | **RNG key derivation** | `ZkRng::from_entropy_reader` (`rng.rs:44-51`) | `"hashline-zk-os-rng/v1/"(22) ‖ domain` | 61 (block), 50 (seam) | **keyed**, key = 32 B of `/dev/urandom` | yes — the OS entropy |
| Q8 | transcript seed | `Transcript::new` (`transcript.rs:25-30`) | `"hashline-v1/"(12) ‖ PROFILE(39)` | 51 | unkeyed | no |
| Q9 | public-statement digests | `BlockPublic::digest` (`private_block.rs:258-264`), `Layout::schedule_digest` (`layout.rs:678-686`), `calibration_identity` (`:94-96`, a 30-byte constant), `SeamSpec::digest` (`private_seam.rs:115-132`, 128 bytes) | public data with a literal prefix | **30** (calibration, a constant), **128** (seam spec), and thousands of bytes for the two statement digests — none is 40, 47 or 64 | unkeyed | **no** |
| Q10 | seeded RNG (fixtures) | `ZkRng::new` (`rng.rs:20-26`) | `"hashline-zk-rng/"(16) ‖ domain ‖ le64(seed)` | 63 (block domain) | unkeyed | **no — and it must never be on a deployment path**; see below |
| Q11 | **other transcripts' seeds — NOT on the block path** | `Transcript::new(b"experimental-private-seam/v1")` (`private_seam.rs:26`, `:245`), `Transcript::new(b"zk60-public-block-receipt-v1")` (`public_block_receipt.rs:20`, `:178`) | `"hashline-v1/"(12) ‖ domain(28)` | **40** | unkeyed | no — but they occupy the refill class, which is why the 40-byte claim below is rescoped (B-3) |

**What the table settles.** Arithmetic on the lengths above — but **the two
label rows this feeds are MIXED, not unconditional** (§8 rows 4 and 5): the
table was incomplete and four absorb lengths were wrong, and the 40-byte
claim holds only on the toy-block path.

* **47 is occupied by nothing else.** Q2 is at least 60 on this path (the
  shortest absorb is `absorb_u64(b"rows", ·)` at `48+4+8`), Q3 and Q4 are 64,
  Q6 is 40, Q8 is 51, and no `8·rows` equals 47 because 47 is not a multiple
  of 8. **So no challenge-producing query can ever coincide with a node, a
  leaf, a column hash, a refill or an absorb.** This is the check's own
  argument (`ZK60_JOINT_LAW_COMPOSITION_CHECK.md` §A6.2), reproduced because
  §3.2 needs it as a bad event that cannot happen rather than one that is
  merely unlikely.
* **40 is occupied by nothing else *on the toy-block path* — and it is NOT
  unique in the crate.** The draft said "occupied by nothing else either",
  full stop; that is **false of the crate** and is blocking item **B-3**.
  Two `Transcript::new` seeds are exactly `12 + 28 = 40` untagged unkeyed
  bytes: `b"experimental-private-seam/v1"` (`private_seam.rs:26`, `:245`) and
  `b"zk60-public-block-receipt-v1"` (`public_block_receipt.rs:20`, `:178`)
  (row Q11). **Neither is on the block's path** — the block builds one
  transcript, `Transcript::new(PROFILE)` at `protocol.rs:30`, 51 bytes — so
  the conclusion survives **rescoped to that path**, and the corresponding
  label row is demoted from unconditional to MIXED (§8 row 5). What such a
  seed could allow is a coincidence between a refill input
  `key ‖ le64(counter)` and a *fixed public constant*: 2^-256 per stream,
  not a break.
  On the block's own path the class is one row away from being occupied:
  `8·rows = 40` is exactly a **5-row** commitment's column
  hash. No commitment in this proof has 5 rows (455, 384, 50, 7, 7), and
  `SeamSpec::new` forces `data_rows ∈ {1,2,4,8,16}` hence
  `commitment_rows ∈ {6,7,9,13,21}` (`private_seam.rs:66-72`, `:106-111`), so
  an endpoint can never have 5. `A`, `H` and `M` are protected by **nothing**.
  ***Condition `rows ∉ {5, 8}` for every commitment in an accepted private
  profile — and it is NOT new*** (correction C-6): privacy-case item 16
  already names **both** values, crediting condition 28 of the D8/D11 check,
  and already observes that `A`, `H` and `M` are protected by no rule at all
  (`ZK60_PRIVACY_CASE_FIRST_MVP.md:825-834`; also
  `ZK60_D8_D11_RESTATEMENT.md` §3.4). A 5-row commitment would put a column
  hash into the generator's own domain; an 8-row commitment would put it into
  the node/leaf domain.
* ***Condition C-H4′ (new, from the check — omitted condition O-C): no
  accepted private profile's `Transcript::new` domain may have length 28 or
  35***, which give 40- and 47-byte seeds, i.e. the refill and challenge
  classes. True on the block path today (`PROFILE` is 39 bytes → 51),
  **false crate-wide** by row Q11. The separating tag that proposed ruling
  D19 asks for in new profiles would close it.
* **64 is shared by Q3, Q4 and exactly one absorb**, which is §1.5.
* **Q10 must not exist on a deployment path.** It is unreachable from the
  block profile — `private_block/protocol.rs:275` and `private_seam.rs:196`
  call `from_os` and nothing else — but it *is* production code on the legacy
  feed-forward line (`hashline/src/zk.rs:334-338`), which is blocking item
  B-5 of the privacy case and its condition for the integrator. **RELIES ON**
  that finding; nothing here re-reads the legacy line.

**A framing that removes most of the table from the argument.** Q8, Q9, Q10
and the label-and-length prefixes are computed from **public** data, so any
query in them is one the adversary can make itself and is already inside the
`q` budget of §2. Q1 and Q2 are recomputable from the published receipt, so
they are public after the fact. **Only Q3, Q4, Q5, Q6 and Q7 have inputs the
adversary cannot compute**, and of those only two hold a secret the argument
depends on: the 11,077 unpublished **salts** (Q4) and the three 256-bit
generator **keys** (Q6, Q7).

### 1.5 The one genuine overlap, recounted

**The fact.** `absorb_u64(b"log-cols", LOG_N)` hashes
`state(32) ‖ le64(8) ‖ "log-cols" ‖ le64(8) ‖ le64(8)` — `8+8+8+8 = 32` bytes
after the state, so **64 in all**, the shape of `hash_pair` and `salt_leaf`.
It is called from `absorb_root` (`private_block/protocol.rs:40-44`), twice per
proof, for `A` (`:320`) and `H` (`:377`). Enumerating every other absorb on
the path — `b"rows"` 60, `b"pb-slot"` 63, `b"pb-scalar"` 73, `b"A"`/`b"M"`/
`b"H"` 81, `b"schedule"` 88, `b"calibration"` 91,
`b"public-statement"` 96, `b"sc-round"` **≥ 104** (`16·(d+1)`, `d ≥ 2`),
`b"expected-IO"` 171 and `b"parameters"` **171** (its literal is 113 bytes),
`b"pb-term"` **once per slot, 71…951** (`slot_terms(s) ∈ 1…56`),
`b"pcs-vec"` 8,247, `b"pcs-prox"` 8,248, `b"mask-q"` 16,438 and
`b"mask-prox"` **16,441** — **no other absorb on this path is 64 bytes.**
**PROVED HERE** (arithmetic; the enumeration is the grep of §1.4's sites).
This is the check's finding (`..._CHECK.md` §A6.2), re-derived. **Four of
these lengths are corrections** made after the independent check re-derived
every absorb on the path (`mask-prox`, `parameters`, `sc-round`, `pb-term`:
correction C-7); the draft had 16,438, "≥158", "≥88" and a single 2,823-byte
`pb-term`. None of the four is 64, so the conclusion is unmoved.

**Why it is nearly harmless.** The last 32 bytes of that input are the
**fixed public constant** `le64(8) ‖ "log-cols" ‖ le64(8) ‖ le64(8)`. So the
input equals `hash_pair(l, r)`'s only if `r` is that constant, and equals
`salt_leaf(d, s)`'s only if `s` is that constant. Node children and salts are
uniform 32-byte values (the children as oracle images, the salts by §2.4's
generator step), so each candidate matches with probability `2^-256`.

**The recount, and it differs from the figure in circulation.** The candidate
objects in one toy-block proof are **12,283 internal-node inputs**
(4 × 2,047 + 4,095) and **12,288 salted-leaf inputs**, **24,571** in all, so
the term is at most

```
24,571 · 2^-256  =  2^-241.42          [PROVED HERE, arithmetic; §7.1]
```

**Settled by the independent check (correction C-1): 2^-241.42 is the figure
to carry, and the earlier `2^-243` was an undercount.**
`ZK60_JOINT_LAW_COMPOSITION.md` §5.2 and the disposition of 2026-09-20 said
**≈ 2^-243**, which corresponds to about 8,200 objects: 8,192 is exactly the
salted leaves of the **four 2,048-leaf trees**, so that count left out `M`'s
4,096 leaves **and all 12,283 internal nodes**. The check reproduced
`24,571 · 2^-256 = 2^-241.4153` from its own script
(`results/zk60_hash_layer_fs_lift_check/recount.py`) and the owner-facing
documents were corrected on 2026-09-20. The difference moves nothing, because
both sit about 130 bits below the dominant residual.

**And the row is wildly conservative, as the check remarks.** Matching also
requires the *first* 32 bytes of the 64-byte input to equal the transcript
state, another 2^-256, so the true bound is `24,571 · 2^-512 ≈ 2^-497`
[the check's recomputation]. The larger figure is kept here because it is
the one the derivation of §2.3 actually uses. The absorb happens **twice**
per proof (`A` at `protocol.rs:320`, `H` at `:377`) and that does *not*
double the term: both share the same suffix `C`, and it is the suffix
condition that carries the probability.

**What the overlap does not touch.** It is not a challenge: Q1 is 47 bytes and
cannot coincide with anything (§1.4). It is not a *programming* problem
either: under D18 nothing is programmed at all (privacy-case item 14). Where
the shared untagged domain still matters is the composition of **this**
argument with the **soundness** reduction over the same table — condition O-7,
untouched here and listed in §6.

**A second ambiguity in the same 64-byte class: FLAGGED AND NOT CHASED
(ruling L-7).** A Merkle node input is `left ‖ right` and a salted-leaf input
is `d ‖ salt`; both are **64 untagged bytes** and **nothing in the format
tells them apart**, so one 32+32 split is simultaneously a valid node
preimage and a valid leaf preimage. *For hiding* this costs one more bad
event — "a leaf input equals a node input" — which the check added at
`12,283 · 12,288 · 2^-512 ≈ 2^-484.8` (correction C-4) and which §2.2 and
§2.3 now carry. *For **binding** it is outside this memo*: it is the
classical internal-node-as-leaf ambiguity, a **soundness** question. With
fixed-depth, position-checked paths it would need a preimage, and the
security owner does not believe it is exploitable — **but nobody has checked
soundness here**, and the separating tag proposed for new profiles under D19
is one more reason to add it.

## 2. Lemma H: hiding of the unopened part

### 2.1 What the composition needs, stated before the lemma

**Notation, taken unchanged from `ZK60_JOINT_LAW_COMPOSITION.md` §1.1.** Fix
an admissible public statement `P` and a hidden input `w`. Split the prover's
output into

* the **field view** `V` — every `Fp`/`Fp2` word the receipt carries: the 23
  masked scalars, the 721 masked round values, the 173 masked terminals, the
  46 group vectors, the 5 proximity vectors, `M`'s `q` and proximity rows, and
  **the 5 × 256 opened columns**;
* the **hash view** `H` — the five roots, the 5 × 256 published salts and the
  5 × 256 authentication paths.

Write `ρ` for the whole challenge vector and `NR(ρ)` for non-refusal. The
accepted result is about `V`:

> **[RELIES ON — Theorem 3.3 of `ZK60_JOINT_LAW_COMPOSITION.md`, core accepted
> by the security owner's disposition of 2026-09-20.]** For every admissible
> `w, w′` and every `ρ` with `NR(ρ)`, `law(V | ρ, NR, w) = law(V | ρ, NR, w′)`,
> in the uniform-blinding idealisation. Its own carried conditions travel with
> every use here: the idealisation (the real prover is reached only through
> the explicit replacement hop of §3.3, at the D9 sampler term), the
> terminals step supplied by the independent check and **independently
> reviewed and corrected on 2026-09-20**
> (`ZK60_TERMINAL_SURJECTION_REVIEW.md`; ruling J-2 resolved at 03:49,
> `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`), cross-role blinding
> independence verified by reading and not machine-asserted (condition O-2),
> and hypotheses (H1)–(H5).
>
> **The three conditions that review added to (H1), which travel with the
> theorem wherever this page cites it** (blocking item B-1, ruling L-5;
> omitted condition O-A):
>
> 1. the condition that carries privacy is the **shape** of the reserved
>    pair's weights, `(cm, cm·U)` (`argument.rs:232-234`) — **not merely
>    `cm ≠ 0`**; with base-field-dependent weights a singleton group
>    discloses 256 `Fp`;
> 2. on `H` **two groups share the zero-sum pair**, so the per-group argument
>    is invalid as written there and it is the **joint** rank that holds —
>    a stated exception, sound only because the two groups' claims are tied
>    by the public lookup identity;
> 3. the **pad budget on `H` is load-bearing**: one opened position beyond it
>    discloses 2 `Fp`, so the pad count and the number of opened columns move
>    together.

**What must be proved is not "H is witness-independent".** The project has a
standing counterexample to that shape of reasoning —
`(H(mask), mask ⊕ w)`, two values each uniform on its own whose *joint* law
determines `w`. Multiplying a witness-free `law(V)` by a witness-free
`law(H)` is exactly that error. The correct factorisation is

```
law(V, H | ρ, NR, w)  =  law(V | ρ, NR, w) · law(H | V, ρ, NR, w),
```

so what the hash layer owes is the **second factor**: the conditional law of
the hash objects **given the field view**. That is the form in which "the
published digests say nothing about the hidden columns" has to be read
here — the digests are *uniform given what the receipt already reveals and
given the hidden columns themselves* (§2.2, correction C-10), because the
field view already fixes the opened columns, and those columns are precisely
the part of the tree the paths authenticate.

**Where the conditioning is legitimate, and why this is not circular.** Both
factors are taken **in the fixed-challenge (interactive) experiment**: the
challenges are supplied from outside, the prover's messages are as in the real
protocol, and the opened index sets are a public function of `ρ` alone
(`challenge_indices`, `transcript.rs:118-131`). In that experiment `ρ` is
exogenous, so conditioning on it assumes nothing about the roots, which are
*outputs*. The real protocol, where `ρ` is a hash of the roots, is §3 and
nothing in §2 anticipates it. **This is the specific loop a delegated
argument in this repository was refused for two days ago, and §9 checks every
step against it.**

### 2.2 The lemma

**The model, stated once.** `O` is a random oracle from `{0,1}*` to an
infinite uniform string, and every *unkeyed* BLAKE3 call in the system is
`O(input)` truncated to the length it reads — 32 bytes for a digest, 8,192
bytes for an XOF refill. `O_k` is a second, independent random oracle
modelling *keyed* BLAKE3 (used only at `rng.rs:47`). This is proposed ruling
**D19** with one convention added (§5.1, the two modes as two oracles).
**ASSUMED**; not accepted.

> **Lemma H (hiding of the unopened part).** Fix an admissible public
> statement, a hidden input `w`, and a challenge vector `ρ` with `NR(ρ)`, in
> the fixed-challenge experiment of §2.1. For each commitment `r` let
> `OPEN_r ⊆ [nn_r]` be the distinct sampled indices — a public function of
> `ρ`. Then there is a **public, witness-free** map `T^O`, depending only on
> the geometry, on `ρ`, and on oracle answers, such that
>
> ```
> H  =  T^O( (col_{r,j}, salt_{r,j})_{j ∈ OPEN_r} ,  (u_{r,k})_{k ∉ OPEN_r} )
> ```
>
> where `col_{r,j}` are the opened columns (part of `V`), `salt_{r,j}` are the
> published salts, and the `u_{r,k}` — one per **never-opened** encoded
> column — are the leaf digests of the unopened columns.
>
> **The conditional-independence statement, in the exact form the check
> supplied (correction C-10).** Write `V = v` for the field view, `S_pub = s`
> for the published salts and `m` for the number of never-opened encoded
> columns. In the ROM, for every admissible `w` there is an event `B_H` with
> `Pr[B_H] ≤ β(q)` such that, off `B_H`,
>
> ```
> law( (u_{r,k})_{r,k}  |  V = v,  S_pub = s,  ρ,  NR,  w,
>                          the unopened columns themselves,
>                          and the adversary's q oracle answers )
>       =  Unif({0,1}^256)^{⊗ m}
> ```
>
> **for every** `(v, s)` in the support, every unopened-column value and
> every `w`: the conditional law is the *same product measure* whatever the
> conditioning and whatever the hidden input. Two wordings of the draft are
> withdrawn here. The conditioning **must include the adversary's own `q`
> oracle answers**, because the distinguisher holds them when it decides.
> And "independent of the unopened columns" is the **wrong phrase** and is
> replaced by "uniform **given** the unopened columns": the unopened columns
> are *not* independent of `V` and need not be — §3.4 shows they may be a
> deterministic function of (view, hidden data) — so the lemma must not be
> readable as a claim about their entropy.
>
> **What the bound rests on, said once and plainly: the 256-bit salt alone.**
> No term below uses the entropy of a hidden column; the bound would be the
> same if every column were the all-zero vector. Given the view and the
> hidden data an unopened column is determined, and only the salt hides it.
>
> Since `H = T^O(opened columns, S_pub, (u_{r,k}))` with `T^O` public, it
> follows that `law(H | V, ρ, NR, w)` is a fixed witness-free kernel
> `K(H | V)`, and hence
> `law(V, H | ρ, NR, w) = law(V | ρ, NR, w) · K(H | V)`, the first factor
> witness-free by Theorem 3.3. Consequently, for any distinguisher
> making at most `q` queries to `O`,
>
> ```
> | Pr[D(V, H) = 1 | w] − Pr[D(V, H) = 1 | w′] |
>       ≤  Δ_field  +  2·Pr[B_H],
> ```
>
> where `Δ_field` is the field-layer distance of Theorem 3.3 (zero in the
> idealisation) and
>
> ```
> Pr[B_H]  ≤  q·N_leaf·2^-256  +  C(N_leaf, 2)·2^-256  +  N_overlap·2^-256
>             +  N_node·N_leaf·2^-512  +  ε_gen(q)
> ```
>
> with `N_leaf = 12,288` encoded columns in one toy-block proof,
> `N_overlap = 24,571` (§1.5), `N_node = 12,283` internal nodes and
> `ε_gen(q)` the generator's term (§5.1).
> Numerically:
> `q·2^-242.42 + 2^-229.83 + 2^-241.42 + 2^-484.83 + ε_gen(q)`.
> The fourth term — a salted-leaf input equal to a **node** input, both 64
> untagged bytes — is the check's correction C-4 and ruling L-7: it is
> immaterial, and it completes a list the draft presented as exhaustive.
>
> **PROVED HERE, inside the model** — the derivation is §2.3 and is
> elementary. **The model itself is ASSUMED** (D19, proposed), and the
> salts' uniformity is the generator step: **primarily assumption M-3
> (ruling C-3)**, with the in-model alternative of §5.1 the route by which
> `ε_gen` would enter instead (ruling L-2). Nothing here is a standard-model
> statement: in the standard model
> what replaces it is assumption **M-2** of the privacy case, a keyed-hiding
> property of BLAKE3 that **is not implied by collision resistance**.

### 2.3 Proof

**Step 1 — the opened leaves are a public function of `V` and the published
salts. PROVED HERE (a one-line code fact).** For `j ∈ OPEN_r` the receipt
carries the whole column `col_{r,j}` (all `rows` words) and its salt, and the
**verifier itself** recomputes `ℓ_{r,j} = salt_leaf(hash_column(col), salt)`
before walking the path (`pcs.rs:1018-1021`; `zk.rs:576-577`). So these leaves
contribute nothing beyond `V` and the salts by construction — not by an
argument about hashing.

**Step 2 — each unopened leaf is a fresh uniform oracle image.** For
`k ∉ OPEN_r` the leaf is `O( hash_column(col_{r,k}) ‖ salt_{r,k} )`, a
64-byte input whose second half is a 256-bit value that **never leaves the
process** (§1.1). In the ROM the answer at a point not otherwise queried is
uniform and independent of every other answer.

**The load-bearing sentence of this page, out of the parenthesis it was in
(the check's §3.2).** *Everything below prices the **salt** and nothing else.
Guessing the column does not help, because the input must match in **both**
halves and the salt half is independent of the data; and the bound would be
unchanged if every hidden column were the all-zero vector. The argument
never assumes an unopened column is hard to guess — §3.4 shows it may be
determined by the view and the hidden data.*

**Four** things can spoil the freshness of the image, and they are the four
hash-layer terms of `Pr[B_H]`:

* *(a) the distinguisher queries the point.* To do so it must produce the
  64-byte input, whose last 32 bytes are the unknown salt. Per query the
  chance of matching **some** unopened salt is at most `N_leaf·2^-256` (union
  over leaves; using all `nn` leaves rather than only the unopened ones is a
  deliberate over-count). Over `q` queries: `q·N_leaf·2^-256 = q·2^-242.42`.
  *(Guessing the column instead does not help: the input must match in both
  halves, and the salt half is independent of the data.)*
* *(b) two leaf inputs coincide*, which would make two "independent uniform"
  values equal. Two salted-leaf inputs are equal iff both the column digests
  **and** the salts are equal, so the probability is `2^-256` per pair over
  the uniform salts:
  `C(12288,2)·2^-256 = 2^26.17 · 2^-256 = 2^-229.83`. **This is the largest
  hash-layer term in the whole page.**
* *(c) a leaf input coincides with a query whose answer is published anyway* —
  the only candidate is the 64-byte transcript absorb of §1.5, at
  `2^-241.42`. If it happened, that leaf's digest would equal a public
  transcript state.
* *(d) a leaf input coincides with a **node** input.* Both are 64 untagged
  bytes and nothing in the format separates them (§1.5, ruling L-7), so this
  is a real member of the list and not a variant of (c): it needs
  `salt_j = right` and `d_j = left`, i.e.
  `12,283 · 12,288 · 2^-512 = 2^-484.83`. Immaterial, and carried because
  the list is presented as exhaustive. **Added by the check (C-4); the
  draft omitted it.**

A fifth conceivable event — the distinguisher querying an **internal node**
above an unopened subtree — needs it to produce both 32-byte children, i.e.
to guess two uniform unknown digests: `2^-512` per query per node, dominated
by everything above and not carried separately. (That is a different event
from (d): there the adversary queries, here two of the prover's own inputs
coincide.)

**Step 3 — the inner nodes, by induction from the leaves. PROVED HERE.** A
node digest is `O(left ‖ right)` and its input contains **no salted data and
no field data** — only two child digests (`merkle.rs:14-19`, `:22-35`). So no
new secret enters the tree above level 0, and by induction on the level every
revealed node is a deterministic function of the leaf vector and of oracle
answers at inputs built from it. Formally: define `T^O` as "build the salted
leaf vector — `ℓ_{r,j}` from Step 1 where `j ∈ OPEN_r`, `u_{r,k}` otherwise —
then run `MerkleTree::build` and `path`". `T^O` reads only public data and
the oracle, and it reproduces the roots and every published sibling exactly,
because the honest prover runs that same code. The sibling that is a subtree
of unopened leaves and the sibling that contains other opened leaves are both
covered: they are nodes of the same tree, and the map does not distinguish
them.

**Step 4 — the root.** The root is one such node, so it is inside `T^O`
nothing special happens to it *in this lemma*. Two things about it are
nonetheless worth saying out loud because they are where the root is usually
mishandled. (i) It is **published and absorbed**, so it feeds every later
challenge — that dependence is §3's subject and is exactly what the
sequential-kernel lemma is for; the fixed-challenge experiment of §2.1 does
not see it. (ii) The **top pair is revealed with probability `1 − 2^-255`**
(§1.2), so no argument may lean on the top of the tree being hidden, and none
here does.

**Conclusion of the proof.** Outside `B_H`, the conditional law of `H` given
`(V, salts, ρ, NR`, the unopened columns, and the adversary's `q` oracle
answers`)` is `T^O` applied to arguments whose conditional law is the
same for every `w`: the opened columns and salts are fixed by the
conditioning, and the unopened leaves are i.i.d. uniform **given all of it**
(the conditioning list of §2.2, as the check requires). Both worlds use the
same oracle, so the induced law of `H` is the same kernel. Multiplying by
Theorem 3.3's witness-free `law(V | ρ, NR)` gives a witness-free joint law.
∎ **PROVED HERE, inside the model, conditional on Theorem 3.3.**

**One observation that keeps the two uses of the oracle apart.** The ROM is
used twice in this page — here, for leaf hiding, and in §3, for the
challenges. Those two uses would interfere if a challenge query could be a
leaf or node query. **It cannot: challenges are 47-byte inputs and leaves and
nodes are 64-byte inputs** (§1.4). The length-class table is therefore not
bookkeeping; it is what makes the two halves of the argument independent
rather than mutually recursive.

### 2.4 The bound as a function of q, term by term

All figures **COMPUTED** by §7.1 from the geometry; `q` is the number of
oracle queries the distinguisher makes (the prover's own ≈ 2^15.3 queries are
inside `T^O` and are not part of `q`).

| term | what it is | size | at `q = 2^50` | at `q = 2^80` | at `q = 2^128` |
|---|---|---|---|---|---|
| salt guessing | `q · 12,288 · 2^-256` | `q·2^-242.42` | 2^-192.4 | 2^-162.4 | **2^-114.4** |
| leaf-input collision | `C(12,288, 2)·2^-256` | **2^-229.83** | — | — | — |
| 64-byte absorb overlap (§1.5) | `24,571·2^-256` | 2^-241.42 | — | — | — |
| leaf input = **node** input (C-4, L-7) | `12,283·12,288·2^-512` | **2^-484.83** | — | — | — |
| generator key guessing (§5.1, the ROM **alternative**) | `6q·2^-256` (C-3: two routes, the key and the OS entropy) | `q·2^-253.42` | 2^-203.4 | 2^-173.4 | 2^-125.4 |
| node-input guessing | `q·(#nodes)·2^-512` | < 2^-480 | — | — | — |
| **`Pr[B_H]`, total** | | | **2^-192.4** | **2^-162.4** | **2^-114.4** |

The total row was **recomputed and confirmed** by the independent check
(its §1.2); the two rows the check added or corrected — the leaf-versus-node
term and the generator's second route — do not move the displayed figures.

**How to read this.** At any query budget a real adversary could have — and
at the absurd budget `2^128` as well — the hash layer contributes **less than
2^-114**, which is below every other named residual of the privacy case
except the generic-rank term's structural route. The dominant term flips
from the collision term to the salt term at about `q = 2^12.6`; below that
budget the bound is `q`-free at 2^-229.8.

**The salt is comfortably oversized, and by how much.** The leak against a
`q`-query adversary is `q·N·2^-256` with `N = 12,288 ≈ 2^13.6`. A 16-byte
salt would give `q·2^-114.4`, still adequate at `q = 2^80` but no longer
absurdly so; an 8-byte salt would be broken (`q·2^-50.4`). The 32-byte choice
costs 8,192 bytes per opening — **exactly 6.25 % of the endpoint opening's
131,072 bytes** — and is the right side of that trade. Recorded because the
D14 "fewer hashed bytes" speed lever will be tempted by it: **shortening the
salt is a privacy change, not a speed change**, and this line is the number
it must be argued against.

### 2.5 What would break the lemma — the code conditions, with their truth today

Stated as conditions, because an acceptance would have to carry them and
because each is one edit away in a new profile. **The draft's list of
"unasserted code conditions" is replaced here by the independent check's own
table** (its §8.2), which re-read every condition at the line, says whether
it is true today, and says how each could be pinned (ruling L-3).

| # | condition | true today? | where the check read it | can it be pinned cheaply? |
|---|---|---|---|---|
| **C-H1** | a salt is published **iff** its column is opened | **TRUE** | `pcs.rs:928-941` (`cmz.salts[j]` for sampled `j` only); `zk.rs:543-548`; the salt travels inside the per-column tuple, so there is no path that emits one alone | **yes** — a test that the distinct salts in a receipt number at most the distinct opened indices, per commitment. Byte-free |
| **C-H2** | salts are `ZkRng::bytes32()` off an OS-seeded stream, never from the witness, the statement or a counter | **TRUE on the block path** (`pcs.rs:674`, `zk.rs:462`; streams at `protocol.rs:275`, `private_seam.rs:196`); **FALSE crate-wide**: `zk.rs:334-338` takes a caller seed on the legacy feed-forward line | partly — privacy-case ruling C-4 (refuse a caller seed outside test builds, or surface `randomness_label`). **Unfixed; it is B-5 of the privacy case**, and it is **irrelevant to the block**, which is unreachable from that constructor |
| **C-H3** | the salt is 32 bytes | **TRUE, at the type level**: `salts: Vec<[u8; 32]>` (`pcs.rs:559`), `bytes32` (`rng.rs:93-99`) | **already pinned** by the type. §2.4 prices 16 and 8 bytes: a D14-style byte-saving lever must not touch the salt without redoing §2.4 |
| **C-H4** | no commitment has 5 or 8 rows | **TRUE**: 455, 384, 50, 7, 7. Structural for the endpoints (`{6,7,9,13,21}` from `private_seam.rs:28-35`, `:66-72`, `:106-111`); **accidental** for `A`, `H`, `M` | **yes** — one assertion in the block's own layout test beside `assert_eq!(M_ROWS, 50)` (`layout.rs:703-708`). **Not** in `zkp-core`: other profiles may legitimately use 5 or 8 rows |
| **C-H4′** | *(added by the check; omitted condition O-C)* no `Transcript::new` domain on an accepted private path has length 28 or 35 (which give 40- and 47-byte seeds) | **TRUE on the block path** (`PROFILE`, 39 → 51 bytes); **FALSE crate-wide**: `private_seam.rs:26` and `public_block_receipt.rs:20` are both 28 | **yes** — a `const` assertion on the profile domain's length, or the separating tag D19 already proposes for new profiles |
| **C-H5** | no salt or blinding value is reused across commitments or proofs | **TRUE**: each commitment draws its own `nn` salts from its own stream segment; three `from_os` calls per proof | reading only (condition O-2). A stream-position test is possible but awkward |
| **C-H6** | no commitment is opened twice | **TRUE and ALREADY PINNED**: `PreparedPlane` has no `Clone` and no getter (`private_seam.rs:142-147`), `Endpoints` is taken by value, and `private_block.rs:360-366` carries a **compile-fail doctest** that a second `prove` on the same owners does not compile | **already pinned** — the draft said "prevented by the type system" and did not know a test enforces it. Load-bearing: two openings of one endpoint commitment **recover all 512 hidden words** (`zkp-core/tests/endpoint_reuse.rs`), a field-layer break no hash-layer lemma would catch |
| **C-H7** | no root is fixed in advance by a third party | **TRUE for this MVP**: `check_endpoints` refuses any policy whose roots differ from the prover's own fresh ones (`protocol.rs:247-249`), under D18 | pinned by the code path; **D8 and D11 remain open and are untouched.** Under a caller-fixed root the simulator would have to *program* the oracle and Lemma H would not be the right tool at all (privacy-case item 14) |
| **C-H8** | no external/device commit path produces different leaves | **TRUE**: the block calls `commit_zk_owned` → the `Cpu` backend; `commit_zk_owned_with`'s `backend.try_commit_zk` (`pcs.rs:678-684`) is never offered a device on this path | **yes** — assert the store is `Store::Host` in the block profile's own test, so a future device backend has to re-open this question deliberately. **GAP for any future device path** |

**What becomes of them (ruling L-3, and the check's omitted condition O-G).**
**C-H1, C-H4, C-H8 and the new C-H4′ are to become byte-free assertions or
tests on the 125M lane** — each is a few lines and none changes a proof
byte. **C-H6 is already pinned** by the compile-fail doctest above.
**C-H2 is false crate-wide and irrelevant to the block**: it is the privacy
case's blocking item B-5 on the legacy feed-forward line, not a property of
this profile's path.

## 3. The lift: from fixed challenges to the real non-interactive protocol

### 3.1 The real interleaving, and which hash objects feed a challenge

**The order, from the source** (`private_block/protocol.rs:1-8` states it;
`prove_inner` at `:260-400` executes it). **VERIFIED IN THE CODE.**

| step | message emitted | challenges drawn after it |
|---|---|---|
| preparation | **`R_in`, `R_out`** — the two endpoint roots, from `private_seam::prepare`, each on its own OS stream (`private_seam.rs:196`) | none; they are absorbed inside the 112-byte policy in the header (`protocol.rs:31`) |
| header | (public only: policy, statement digest, parameters, calibration, schedule) | none |
| 1 | **`a_root`** + rows + log-cols (`:320`) | none |
| 2 | **`mask_root`** (`:326`) | `β, γ, α` (`:330-332`) |
| 3 | **`h_root`** (`:377`) | the slot schedule's challenges |
| 4 | 23 slots: slot index absorbed, `c_s` drawn, `Γ_s` absorbed, round messages absorbed and round challenges drawn, `e` drawn, masked terminals absorbed (`argument.rs:270`, `:290`, `:321`, `:350`) | interleaved as shown |
| 5 | `M`'s opening: `θ` drawn, `q` absorbed, the proximity `r`s drawn, `prox` absorbed, **256 indices** drawn (`zk.rs:512-548`) | as shown |
| 6 | four PCS openings in order `A`, `H`, `In`, `Out`: `λ`s and proximity `ρ`s drawn, group vectors and proximity vector absorbed, **256 indices** drawn, then the **columns, salts and paths** emitted (`pcs.rs:915-943`) | as shown |

**The fact that makes the lift much smaller than it looks. PROVED HERE (a
source reading of `open_zk` and `mask_open`).** Of the hash view, **only the
five roots are ever absorbed.** The 1,280 salts and the 1,280 paths are
absorbed nowhere: `open_zk` absorbs the group vectors and the proximity
vector, draws the indices, and *then* gathers `(index, column, salt, path)`
(`pcs.rs:921-941`); `mask_open` does the same (`zk.rs:533-548`); the verifier
mirrors it (`pcs.rs:965-985`, `zk.rs:562-566`). Nothing downstream of the
openings exists. So:

* **no challenge is a function of a salt or of a path** — the hash objects
  that Lemma H works for are *terminal* messages that influence nothing;
* the only witness-dependent objects feeding the challenge chain are the
  **five roots** and the **field messages**, and the field messages are
  Theorem 3.3's subject;
* the adaptivity problem the privacy case names in its part D (item 10,
  "the challenges depend on the roots, which depend on the witness") is
  therefore exactly the problem of five 32-byte values, not of half a
  megabyte of hash material.

**Two smaller facts the lift uses.**

* **Every challenge input within one proof is distinct, by construction.**
  `squeeze_bytes` hashes `state ‖ "squeeze" ‖ le64(counter)` and increments
  the counter on every call (`transcript.rs:85-94`), so two squeezes in one
  transcript never share an input even if the state repeated. **PROVED HERE.**
* **The refusal replay deliberately re-queries the same points.**
  `Transcript::clone_state` copies the state *and the counter*
  (`transcript.rs:139-142`), so `check_opening_challenges` draws exactly the
  challenges `open_zk` will draw (`protocol.rs:139-152` against
  `pcs.rs:835-855`). That is a repetition **by design**, giving the same
  answers; it is not a collision and it does not enter any bound. Recorded
  because a reader hunting for "distinct inputs" will find it.

### 3.2 The bad events, written out with their sizes

The check asked for these to be enumerated rather than left in prose
(`..._CHECK.md` §A6.3, condition O-4). Here they are, with what disposes of
each. `A ≤ 4,000` is a **bound** on the number of absorbs plus squeezes in one
toy-block proof — the schedule gives roughly 1,900 squeezes (3 LogUp, 23 slot
masks, 184 round challenges, the `e`s, `θ`, 48 mask-proximity coefficients,
120 + 455 and 51 + 384 opening coefficients, 2 × 8 endpoint coefficients and
5 × 64 index squeezes) and roughly 1,000 absorbs. **I have not counted them
exactly, and say so**; every term the count enters is 2^-230 or smaller, so
the bound suffices.

| # | bad event | disposed of by | size |
|---|---|---|---|
| **B1** | two challenge draws in one proof share an oracle input (the challenge chain repeats) | **impossible**: the squeeze counter increments every call (`transcript.rs:85-94`) | **0** |
| **B2** | a challenge input coincides with a node, leaf, column-hash, refill or absorb input | **impossible**: challenges are 47 bytes, a length no other class uses (§1.4) | **0** |
| **B3** | the distinguisher queried a challenge input **before** the prover did | possible; **harmless** (an oracle answer is uniform and independent of `w` whoever queries first), priced for completeness: it needs a 32-byte state guess — **and that reason covers pre-receipt queries only** (the check's §4.2). *After* it has the receipt the distinguisher can recompute **every** challenge input and query it with probability 1; that is harmless because the answers are already fixed, and the only thing B3 is needed for is the lazy-sampling **ordering** of §3.3 | `q·4,000·2^-256 = q·2^-244.03` |
| **B4** | two distinct absorb inputs collide (the transcript's binding) | `C(4,000, 2)·2^-256` | **2^-233.07** |
| **B5** | a 64-byte absorb input coincides with a node or salted-leaf input | §1.5 | **2^-241.42** |
| **B6** | anything in `B_H` (salt guessed, two leaf inputs equal, a leaf input equal to a node input, the generator's key or the OS entropy guessed) | §2.4 | `q·2^-242.42 + 2^-229.83 + 2^-484.83 + ε_gen(q)` |
| **B7** | the distinguisher **chooses the public statement** so as to bias a challenge (grinding) | **impossible on this schedule**: no challenge is drawn before `a_root` is absorbed (`protocol.rs:320` then `:330`), and `a_root` is an oracle image on an input the distinguisher cannot compute without `B_H`. So every challenge is uniform given everything the distinguisher chose | **0**, outside `B_H` |
| **B8** | the prover's own queries colliding with the transcript's | subsumed by B2, B4, B5 | — |

```
ε_lift(q) = q·2^-244.03 + 2^-233.07 + 2^-241.42 + Pr[B_H]
          ≈ 2^-228.837 at q = 2^12,   2^-192.008 at q = 2^50,
            2^-162.008 at q = 2^80,   2^-114.008 at q = 2^128.
```

**CORRECTED after the independent check (correction C-2).** The draft's
display line read `2^-228.9 / 2^-192.4 / 2^-162.4 / 2^-114.4`: those are the
**salt term alone**, copied from the `Pr[B_H]` row of §2.4, which is itself
right. The four figures above are the check's own recomputation of the sum
`B3 + B4 + B5 + Pr[B_H]` that `ε_lift` is defined to be
(`results/zk60_hash_layer_fs_lift_check/recount.py`), with its generator row
in the `3q·2^-256` form; the completion to `6q` of §5.1 is not included in
them. §5.2's prose "the hash-layer terms together are below 2^-114 even at
`q = 2^128`" survives, but by 0.6 %, not by the factor the draft assumed.

**COMPUTED** (§7.1 for the components; the sums are the check's). The
lift adds nothing material to Lemma H's own bound: **B1, B2 and B7 are zero,
and the rest are below the salt term at every interesting `q`.**

### 3.3 The per-step kernel argument

**The oracle splits by input length, and that is what licenses the whole
step. PROVED HERE.** Write `O = (O_47, O_64, O_40, O_rest)` for the
restrictions of the oracle to inputs of 47 bytes, of 64 bytes, of 40 bytes,
and of every other length. A random oracle's restrictions to disjoint input
sets are **independent random functions**. By §1.4:

* every **challenge** is an `O_47` image;
* every **node and salted leaf** is an `O_64` image; so is the one 64-byte
  absorb, which is bad event **B5** and is priced;
* every **generator refill** is an `O_40` image;
* every other absorb, the column hashes and the public digests are `O_rest`.

The prover's messages are functions of `(w, O_40, O_64, O_rest)` and of the
challenges it has received; the challenge function is `O_47`, which is
**independent of all of those**. That independence is not an assumption
added here — it is a consequence of the length table, and it is why the
shared untagged BLAKE3 domain does not make the argument circular.

**Route A (the one this page carries): lazy sampling, written out hop by
hop.** The draft gave this step in prose and **omitted a hop**: it applied
Theorem 3.3, which is stated *in the uniform-blinding idealisation* (ruling
J-3), to the **real** prover without ever replacing the real prover's
slightly biased blinding by uniform blinding. That is blocking item **B-2**,
and ruling **L-1** requires the hop to be written in. It is written in below,
as hop **G_3 → G_4**, and it is where decision **D9**'s term — 2^-77.7 for
one toy proof — enters, **once per proof**, as a single replacement of the
whole blinding stream (not once per commitment and not once per challenge).
The hop list is the independent check's one-page hybrid (its §4.1); every
hop cites a named lemma or a listed bad event.

Fix the admissible public statement `P`, a hidden input `w` and a
distinguisher `D` making at most `q` oracle queries. `G_0` is the real game:
the honest prover runs `prove_inner` with the real oracle; `D` sees the
policy, the receipt or `⊥`, and may query the oracle before, during and
after.

| hop | what changes | what justifies it | cost |
|---|---|---|---|
| **G_0 → G_1** | the oracle is sampled **lazily**: a fresh uniform answer at each new point, in query order | identical distribution, by the definition of the ROM (row 0, proposed D19) | 0 |
| **G_1 → G_2** | **all generator outputs are sampled up front** | **the refill query points are NON-ADAPTIVE**: they are `key ‖ le64(counter)` for `counter = 0,1,…` (`rng.rs:53-57`), fixed by the key alone and by no protocol value, so reordering their sampling changes nothing. *This is the hop the draft left implicit* (omitted condition **O-F**), and it is what makes "sample the challenges in advance and feed them to the prover" the same experiment even though the prover interleaves refills with challenge draws (`H`'s pads are drawn after `β, γ, α`) | 0 |
| **G_2 → G_3** | the generator's output stream is treated as uniform: **primarily by assumption M-3 (ruling C-3)**, the route ruling L-2 keeps; in §5.1's ASSUMED alternative instead, **abort** if any query of `D`'s begins with one of the three stream keys or hits the `O_k` key-derivation point | M-3, or the bad event priced in §5.1 | `ε_PRG` (primary) / `ε_gen(q) ≤ 6q·2^-256` (alternative) |
| **G_3 → G_4** | **the prover's pads, masks and CFS coefficients are replaced by uniform field elements** — the uniform-blinding idealisation | **THE HOP THE DRAFT OMITTED (B-2).** The 327,052 `fp()` draws are each exactly 2^-96 from uniform (§5.1), so one union bound over the whole blinding stream gives the replacement. The 12,288 salts need **no** replacement: `bytes32` is raw stream output, not reduced mod `p`, hence already exactly uniform in this game | **2^-77.7 — decision D9, accepted; once per proof** |
| **G_4 → G_5** | **abort on `B_H`** (a salt queried; two leaf inputs equal; a leaf input equal to the 64-byte absorb; a leaf input equal to a node input) | Lemma H, §2.2–§2.3 | `q·2^-242.42 + 2^-229.83 + 2^-241.42 + 2^-484.83` |
| **G_5 → G_6** | **abort on B1–B5, B7** | B1 and B2 are **impossible** (the squeeze counter; the 47-byte class); B3, B4, B5 are priced in §3.2 | `q·2^-244.03 + 2^-233.07` |
| **G_6 → G_7** | **every challenge is replaced by a value drawn uniformly in advance** | each squeeze input is 47 bytes, fresh (B1), met by no other class (B2) and not pre-queried (B3), so its answer is uniform given the whole history — which, by G_2, already contains all of the prover's randomness | 0 |
| **G_7** | = the **fixed-challenge experiment** of §2.1, with `ρ` uniform and independent of `(w, blinding)` | — | — |
| **G_7 → G_8** | split on refusal; on a non-refused `ρ` apply **Theorem 3.3** (field) × **Lemma H** (hash) | §4; the refusal events differ between the two worlds only in the LogUp class | `2·2^-112.0` |
| **G_8 → G_8′** | **`w := 0`**; the all-zero input is admissible | RELIES ON the measurement (`zero_witness_tests.rs`, §4) | 0 |
| **G_8′ → G_0′** | undo G_6 … G_1 in the zero world | the same bounds | (already counted) |

Written as an identity, hops G_6 → G_7 onward are

```
law(view | w)  =  E_ρ [ law(V, H | ρ, w) ]
               =  E_ρ [ law(V | ρ, w) · law(H | V, ρ, w) ]
```

with `ρ` uniform in both worlds: by Theorem 3.3 (with its three travelling
conditions, §2.1) the first factor is witness-free at every non-refused `ρ`,
by Lemma H the second is. Integrating gives a witness-free law for the whole
view, up to `ε_lift(q)`, up to the D9 term of hop G_3 → G_4, and up to the
refusal conditioning of §4. **The derivation now reaches its conclusion;
as written in the draft it did not.** **PROVED HERE, inside the model,
conditional on Theorem 3.3 and Lemma H** — and the label row (§8 row 23) is
demoted to MIXED, as the check requires, because the conclusion was
reachable but the draft's derivation did not reach it.

**Route B (the one the independent check asked for, condition O-4 / its Q5):
the sequential-kernel lemma with paired messages.** Define the message at
step `j` as the **pair** `(field part, hash part)`: `m_0 = (∅, (R_in, R_out))`,
`m_1 = (∅, a_root)`, `m_2 = (∅, mask_root)`, `m_3 = (∅, h_root)`, then the
slot messages (field only), then the opening messages, the last of which
carries `(group vectors, proximity vector | columns, salts, paths)`. Two
hypotheses have to be checked against the code, and both hold:

* **causality** — each `m_j` depends only on `w`, the prover's private
  randomness and the challenges drawn *before* it. **VERIFIED IN THE CODE**
  from the table of §3.1: the roots exist before any challenge; a slot's
  messages use only that slot's and earlier challenges; the columns, salts
  and paths are gathered after the index challenges and are never re-absorbed;
* **the joint per-`ρ` hypothesis** — for every `ρ` with `NR(ρ)`, the joint law
  of all the `m_j` is witness-free. That is Theorem 3.3 times Lemma H,
  exactly as in Route A.

The lemma (`ZK60_MVP_JOINT_VIEW.md` §1.2, reviewed at
`ZK60_JOINT_VIEW_REVIEW_20260918.md:54-56`) then gives the conclusion for
*any* challenge function, uniform or not. **RELIES ON** that lemma, and here
is the honest caveat that must travel with it: **its proof and its exhaustive
toy tests exist only on branch `zk60-mvp-fable`, not in the main tree**
(privacy-case item 17), so the independent check **could not verify** it.
**And Route B EXTENDS that lemma rather than applying it as reviewed**
(omitted condition **O-D**): privacy-case item 17's carve-out (ii) says the
reviewed lemma "*is about field messages and says nothing about the hash
layer, because roots, salts and paths are not messages chosen given `ρ`*".
Pairing each message with a hash part widens the lemma's **message
alphabet**. The extension is legitimate because the joint per-`ρ` hypothesis
is supplied here as Theorem 3.3 × Lemma H — but the page must say it is
extending, not applying. Route A does not need any of this. Route B is stronger in one
way — it does not need the challenges to be uniform — and weaker in another:
it needs the per-`ρ` hypothesis at *every* `ρ`, and Theorem 3.3 supplies it
only at non-refused `ρ`, so Route B still needs §4.

**Why the two routes are given rather than one.** The project's condition O-4
asks for Route B, and it is written here. But Route B's only ingredient that
is not in the main tree is precisely the lemma, and an acceptance that rests
on a branch is fragile. Route A reaches the same conclusion from the ROM the
project is already proposing to adopt. **A checker should attack Route A
first**, because it is the one this page recommends carrying, and because its
lazy-sampling step is the place where an error would hide.

### 3.4 The known counterexample, and the delicate point it is pointed at

**The counterexample.** `(H(mask), mask ⊕ w)`: each value is uniform on its
own, the pair determines `w`. The shape to hunt for is **one blinding
variable published twice under different encodings**. The composition memo
hunts it through the field channels (its §5.3, six candidates). The question
this page has to answer is the hash-layer instance of it, and the brief
states it exactly: *is any pad symbol both under an unopened leaf and
determining a published field value?*

**The answer is yes, and it is worth showing why rather than asserting it.**
`encode_row_zk` (`pcs.rs:618-637`) writes the row's coefficient vector as
`coeffs(X) − g(X) + X^n·g(X) = coeffs(X) + (X^n − 1)·g(X)` where `g` has the
row's `Q = 256` pad symbols as coefficients, multiplies by the coset powers
and evaluates. So

```
col_j[i]  =  ⟨E_j, z_i⟩,       E_j[msg t] = (x_j^n − 1)/(n(x_j ω^{-t} − 1)),
                               E_j[pad k] = (x_j^n − 1)·x_j^k
```

(the closed form the privacy case's item 5 quotes and the check re-derived).
`x_j^n ≠ 1` at every coset point (`coset_powers` asserts the coset is
disjoint from the subgroup, `pcs.rs:613-615`), so **every pad symbol of row
`i` appears, with a non-zero coefficient, in every one of the 2,048 encoded
columns — the 240 that are opened and the 1,807 that are not.** And the same
pads appear in the clear in the published **pad halves** of the 46 group
vectors and the 5 proximity vectors: `v_g = Σ_i ρ_g[i]·z_i` is transmitted in
full, 256 message coordinates then 256 pad coordinates (`pcs.rs:858-875`,
`OpeningZk::write_bytes`, `:582-601`).

So the protocol really does publish a linear image of the pads **and** hash
the same pads under leaves that are never opened. That is the counterexample's
shape, and it is where a hash-layer argument could fail.

**Why it does not fail — stated precisely, because the draft's one-liner was
not.** The draft wrote that the digest of an unopened column "is **not a
function of the pads** at all". Read literally that is **false and is
withdrawn**: in the ROM the digest *is* a function of `(column, salt)`, and
the column is a function of the pads. What is true is the **conditional**
statement of Lemma H, in the form §2.2 now states it: conditioned on
everything the adversary has — the field view, the published salts, the
challenges, non-refusal, its own `q` oracle answers — **and on the unopened
columns themselves**, the digest is uniform, because the point
`hash_column(col_k) ‖ salt_k` has been queried by nobody else, its second
half being a **fresh 256-bit value that is never published** (§1.1). Made
precise that way the counterexample dies for the right reason: in
`(H(mask), mask ⊕ w)` the two published objects are images of **the same**
unknown at **two** addresses the adversary can relate, whereas here the
second address is unreachable without a fresh 256-bit secret that is
published for **no** unopened column.

**The contrast that makes the mechanism visible.** For an **opened** column
the salt *is* published, so its leaf digest *is* a deterministic function of
published data — the verifier recomputes it (`pcs.rs:1018`). That is the
counterexample's dangerous shape realised in full, and it is harmless for the
only possible reason: the column itself is published too, so the digest adds
nothing. Every leaf in the tree is therefore in one of two safe states —
*fully published* or *fully salted* — and there is no third state. **The rule
this suggests, and it is the rule C-H1 of §2.5: a salt is published if and
only if its column is.**

**What the field layer contributes, cited not reproved.** Two facts from the
accepted generic-rank lemma keep the published pad images from being a
separate leak: the pad block `diag(x_j^n − 1) × Vandermonde` has **full row
rank for every `d ≤ Q`** (privacy-case item 5, PROVED), so the opened columns
are absorbed; and **the pad halves of the group and proximity vectors are
determined by the opened columns** and the vectors' message halves
(`ZK60_GENERIC_RANK_LEMMA.md` §3.4; `..._DISPOSITION.md` §1), so publishing
them consumes no further pad freedom — with the correction that only a
`d`-dimensional projection is so determined, the remaining `10…25`
coordinates being supported on pad coordinates only
(`ZK60_JOINT_LAW_COMPOSITION.md` §4.2, resolving Q7). **RELIES ON** both.
Neither is re-derived here, and neither is a hash-layer statement.

**The honest bound on all of this.** Everything above is *inside the random
-oracle model*. In the standard model the sentence "the salt makes the digest
carry no usable information about the pads" is assumption **M-2** of the
privacy case — a keyed-hiding/extractor property of BLAKE3 that **is not
implied by collision resistance** and that nobody here has reduced to
anything. The size of the claim is `q·2^-242.4` in the model and *unbounded*
outside it. That is the trade the proposed ruling D19 is asking the project
owner to make, and it should be put to him in those words.

**A second candidate the composition memo could not dispose of, and what §5.1
does to it.** Row 6 of its §5.3 table is `A`'s 256 published salts, drawn
from the same stream that **later** produces `H`'s secret pads
(`pcs.rs:673-674`, three commitments on one stream) — "the one candidate with
no structural answer", left to assumption M-3. **M-3 (ruling C-3) remains the
primary answer** (ruling L-2). Inside the model there is also an
alternative reading: the stream is `O_40(key ‖ counter)`, and the refill
points are non-adaptive, so the published bytes and the secret bytes are
disjoint ranges of one uniform string and published output reveals nothing
about unpublished output unless the 256-bit key — or the 32-byte OS entropy
behind it — is queried (§5.1), at the price of `6q·2^-256`. That does not
make M-3 true, and it does **not** replace it: it is the ALTERNATIVE of
§5.1, and it costs the two modelling conventions stated there.

## 4. Refusals in the real protocol

Everything in §2 and §3 is conditioned on `NR(ρ)`. This section removes the
conditioning. Nothing here is new work: it is the privacy case's item 24
inventory and the composition memo's §5.4, assembled with the ROM step of
§3.3 so the conditioning can be discharged rather than declared.

**A refusal is terminal. RELIES ON ruling J-4 (security owner, 2026-09-20),
which the independent check established from the code.**
`private_block::prove_with_stats` calls `prove_inner` **once**
(`private_block.rs:431-435`); there is no retry loop; the two endpoint owners
are consumed by value and `PreparedPlane` has no `Clone`
(`private_seam.rs:142-147`, `private_block.rs:360-370`); the endpoint roots
are in the public statement and re-checked (`protocol.rs:31`, `:247-249`). So
there is no restart to condition on and no i.i.d.-attempts argument to make —
and "opened twice" is prevented by the type system, which is also what keeps
C-H6 of §2.5 safe.

**The three classes, and what each does to the bound.**

| class | count | depends on | what it costs the argument |
|---|---:|---|---|
| shape, schedule, policy, environment | **10 of 18** (rows 1–5, 7, 11, 13, 14, 17 of the privacy case's own table), **plus** the two `panic`s argued unreachable (rows 15, 16) and the witness-builder row (18) | the public statement, the declared shapes, or the host (`s` and the entropy class) | **nothing**: identical functions of identical public data in both worlds. The two `panic`s (`pcs.rs:886`, `:890`) are **argued** unreachable by the independent check, **not** tested, and an abort is a louder operational signal than an `Err`. *(The draft said "14 of 18", which matches no grouping of that table: correction **C-9**, bookkeeping.)* |
| challenge-driven | **4** (rows 8, 9, 10, 12): `c_s = 0`; `e ∈ {0,1}`; a zero group coefficient; a dependent proximity pair | the challenges **alone**, drawn from a *cloned* prefix so the decision never advances the live transcript (`protocol.rs:174-176`, `argument.rs:275-276`, `:347-348`, `:493-494`) | **nothing, but only because of the model.** These events *are* deterministic functions of `(w, β)` once BLAKE3 is fixed; what makes their law witness-independent is that §3.3 makes every challenge uniform. Rate **≈ 2^-62.0 per proof — newly counted for this block, not imported** (see below), a liveness cost, equal in both worlds |
| witness-dependent | **exactly one**: a zero LogUp denominator, `inverses` → `"zero LogUp denominator; discard attempt"` (`protocol.rs:231-234`, raised at `:339`, `:349`, `:351`, `:357`) | the witness values **and** the challenges | **2^-112.0** (64,768 inverted denominators over \|Fp2\| = 2^128; **2^-117.4** counting distinct values, which a write-up should prefer). Carried as a residual |

**Discharging the conditioning. PROVED HERE (elementary), on §3.3.** Let
`P_w = Pr[the prover refuses | w]` and let `μ_w` be the law of the view
conditioned on not refusing. The distinguisher sees either `⊥` or a receipt,
so

```
d( view_w , view_0 )  ≤  Pr_w[LogUp]  +  Pr_0[LogUp]
                         +  sup_{NR ρ} d( … )
                      ≤  2·2^-112.0  +  ε_hash .
```

**The decomposition is the check's, not the draft's (correction C-8).** The
draft wrote `d ≤ |P_w − P_0| + d(μ_w, μ_0)` and then took the second term
from §2–§3. That is loose by a small constant: `μ_w` is the view conditioned
on *not refusing*, and the conditioning event itself differs between the
worlds in the LogUp class, so the induced law of `ρ` given completion also
differs, by up to ≈ 2^-112. The honest constant is 2, as above. Immaterial
against 2^-77.7 — but the step was labelled an elementary derivation and as
written it was not tight enough to be one (§8 row 31, demoted to MIXED).

The challenge-driven part of the refusal event is the same measurable
function of a uniform `ρ` in both worlds, so it contributes nothing to the
difference; only the LogUp class does.

**The challenge-driven refusal rate is a LIVENESS figure and NOT a distance
— and it is COUNTED here for this block, not imported (blocking item B-4,
ruling L-4).** The draft printed "2^-62.0 per proof" citing the privacy
case, which says of that number, for this shape, that it "*has never been
counted; that number is OPEN, and this page does not guess it*"
(`ZK60_PRIVACY_CASE_FIRST_MVP.md:319-327`) — it was computed at the A00
shape for a different prover, the repaired feed-forward profile `ffn-v3-mr1`.
The independent check counted it for the private block instead (its §7.2),
and that count replaces the import:

| site | condition | probability |
|---|---|---|
| `check_opening_challenges`, proximity pair | `det(ρ_prox, ρ_prox+1) = 0` (`protocol.rs:135-137`, `:148-150`) — a determinant in the **base field `Fp`** | ≈ `1/p ≈ 2^-64` each |
| called for | `A` (`protocol.rs:396`), `H` (`:399`), the input endpoint (`:402`), the output endpoint (`:405`) | **4 sites** |
| zero group member coefficient, zero CFS mask challenge, degenerate terminal mask challenge | `is_zero()` / `e ∈ {0,1}` in `Fp2` | ≈ 2^-128 each, 64 bits smaller |

**Four base-field determinants dominate: `4/p ≈ 2^-62.0`.** The figure the
draft quoted survives, but by a derivation it did not give and for a
completely different reason from the A00 inventory. It is a **completeness
(liveness) loss, not a distinguishing term** — the same reading D9's source
gives it (`ZK60_FABLE_TRANSCRIPT_REVIEW.md` §B.7) — and it stays one only
while the rule *refuse, never resample* holds.

**Admissibility, stated so the quantifier is honest.** The witness builder's
20 named refusal sites (`witness.rs:79-96` and the sites listed in item 24)
fire **before any proof object exists**, and they are what "admissible `w`"
means: the statement quantifies over inputs the builder accepts. The ideal
world's all-zero input is one of them — proved and verified on 2026-09-20 at
00:36, with the two range boundaries pinned
(`hashline/src/private_block/zero_witness_tests.rs`, lane
`zk60-private-block-125m` at `ec84dac`). **RELIES ON** that measurement; it
is the existence certificate this whole argument needs and it is now in hand.

**What an observer of a SERVICE sees, and what it is not.** On a refusal
nothing is published: `prove_inner` returns `Err` and no receipt exists. A
service that retries must call `private_seam::prepare` again, so the retry
carries **fresh endpoint roots** — the observable is *a changed root*, at a
rate of about 2^-62 per proof, carrying no information about the input
(ruling J-4's operational note). Two things this does **not** cover, both
outside this page:

* **the refusal string (ruling L-6).** Some refusal strings are
  **data-dependent** and real: `"fixed oracle range refusal: {site}"`
  (`hashline/src/private_block/witness.rs:80`),
  `"causal maximum attainment"` (`:271`), `"softmax denominator"` (`:287`).
  A caller that submits an input and reads the `Err` string learns **which
  relation its own input violated**. **This is not a blocker for the
  statement as quantified**: those sites fire only for inputs the statement
  does not admit — the statement quantifies over **admissible** `w`, which
  means the builder accepted it — and the strings that *can* fire inside the
  quantifier are already partitioned above (the challenge-driven ones are
  functions of `ρ` alone, the one witness-dependent one is the LogUp class
  priced at 2^-112.0). It is a **service-boundary** gap, not a proof gap.
  **The rule for any service built on this, recorded here: a refusal reason
  is never returned to anyone who is not entitled to the input.** It joins
  proposed ruling D21; the fix is to map every refusal to one opaque code at
  the API boundary. **GAP**, an engineering one, for *inadmissible* inputs.
* **timing, memory and power** — proposed ruling D20, and explicitly not
  claimed here.

## 5. The final statement, with every residual listed and sized

### 5.1 The generator: the standard assumption stays primary, and the in-model derivation is a separated alternative

**The brief asks whether "the same hash function serves as the random oracle
and inside the generator" needs a remark, and forbids hiding it. It needs
one and it is given here — but NOT as a saving. Ruling L-2 (security owner,
2026-09-20) settles how it is carried:**

> **PRIMARY — the standard assumption.** The privacy statement keeps the
> named assumption of the privacy case's ruling **C-3**: *the generator's
> whole output stream is computationally indistinguishable from uniform*,
> in the two-sided form C-3 requires, for the named generator — a BLAKE3
> stream over key and counter, `zkp-core/src/rng.rs`. That is assumption
> **M-3**, and it is an assumption the project already carries for Theorem
> 3.3's own (H3) and (H5).
>
> **ALTERNATIVE, labelled ASSUMED — the in-model derivation below.** Inside
> D19's model the generator's pseudorandomness *can* be derived rather than
> assumed, and that derivation is written out here. It is recorded as an
> alternative reading and **not** as the primary route, for the reason the
> check gave: it needs BLAKE3's extendable output to be **indifferentiable
> from a random oracle**, not merely consistent as an extendable output
> (correction C-5) — a stronger property of the hash than the one being put
> to the project owner, and one this repository has not established.

**The generator, read exactly.** `ZkRng` (`zkp-core/src/rng.rs:9-99`):

1. `from_os(domain)` reads **32 bytes of `/dev/urandom`**, failing closed on
   an unsupported host (`:30-51`), and derives the 32-byte key as
   **keyed** BLAKE3 — `Hasher::new_keyed(&entropy)` — over
   `"hashline-zk-os-rng/v1/" ‖ domain` (`:47-50`);
2. `refill` produces each 8,192-byte block as **unkeyed** BLAKE3 in **XOF**
   mode over `key(32) ‖ le64(counter)(8)` — **40 bytes** (`:53-61`);
3. `fp()` takes two `next_u64`s as a 128-bit integer reduced mod `p`
   (`:72-77`) — the D9 bias, exactly `2^-96` per draw; `bytes32()` takes four
   (`:93-99`).

So the privacy case's description, "a keyed BLAKE3 stream with a counter", is
right about the key derivation and **not** right about the stream: the stream
itself is **plain unkeyed BLAKE3 on a 40-byte input**, the same function that
hashes the Merkle tree. That is the fact that needs the remark.

**The two conventions.**

* **(V-1)** One oracle `O` with long output models unkeyed BLAKE3 in both its
  32-byte and its XOF form. The draft justified this by "the 32-byte hash
  is the first 32 bytes of the XOF" and labelled it RELIES ON. **That
  justification is not sufficient and the label is withdrawn** (correction
  C-5): the prefix property makes the two *readings* consistent, whereas
  what the model needs is that BLAKE3's extendable output is
  **indifferentiable from a random oracle with long output** — a design
  claim of BLAKE3's tree mode with its length and flag separation, not an
  arithmetic fact, and the thing to cite. **ASSUMED** (demoted from RELIES
  ON), and nobody here has checked the literature on it.
* **(V-2)** Keyed BLAKE3 (used at `rng.rs:47` and nowhere else on this path)
  is modelled as a **second, independent** oracle `O_k`. BLAKE3 separates its
  modes by internal flags, so this is the standard convention; it is
  nonetheless a convention. **ASSUMED.** One word on why it is the
  *conservative* convention here (the check's §3.4): modelling a
  secret-keyed PRF as a random oracle indexed by the key gives the adversary
  *more* power — it may query `O_k` at any key — so the resulting bound is
  an upper bound on the real one under the usual flag-separation reading.

**The alternative derivation, inside (V-1), (V-2) and D19 — ASSUMED, not
primary.** The key is uniform on 256 bits (from `/dev/urandom` through
`O_k`) and never leaves the process. Every output block is
`O(key ‖ counter)`, an image at an input the adversary cannot address
without the key. **And the refill query points are NON-ADAPTIVE** —
`key ‖ 0`, `key ‖ 1`, … , fixed by the key alone and by no protocol value
(`rng.rs:53-57`) — which is the fact that makes the argument work and which
the draft asserted its conclusion without naming (omitted condition
**O-F**). It is also what disposes of the "`A`'s salts are published before
`H`'s pads are drawn" worry: the published bytes and the secret bytes are
disjoint byte ranges of one uniform string, hence independent. Therefore the
whole stream — pads, mask rows, CFS coefficients, `b`, `u` and **all 12,288
salts** — is uniform and independent of everything in the adversary's view,
except on the event that one of its `q` queries begins with one of the three
keys, **or guesses the 32-byte `/dev/urandom` entropy and recomputes the key
through `O_k` on the public input `"hashline-zk-os-rng/v1/" ‖ domain`**. The
draft priced only the first route; the second is correction **C-3**:

```
ε_gen(q)  ≤  6·q·2^-256  =  q·2^-253.42 .
```

**What that does and does not buy, stated carefully and as ruling L-2
requires.** Assumption **M-3** of the privacy case — "the generator's whole
output stream is computationally indistinguishable from uniform", in the
two-sided form ruling C-3 requires because `A`'s 256 salts are published
**before** `H`'s pads are drawn from the same stream (`pcs.rs:673-674`) —
**stays as the primary assumption of the privacy statement.** The draft
said it was "not needed as a separate assumption inside D19's model"; that
reading is **withdrawn as primary** and survives only as the alternative
above. Four qualifications, none of them optional:

1. **It is a model statement, not a proof about BLAKE3.** In the standard
   model M-3 stands exactly as ruling C-3 wrote it, and the privacy statement
   must be written twice — once in the standard model with `ε_PRG` (the
   primary row), once in the ROM with `ε_gen` (the alternative). §5.2 does
   that.
2. **It rests on the 40-byte length class being unused elsewhere — and that
   is TRUE ONLY ON THE BLOCK'S PATH** (§1.4, blocking item B-3). Two
   `Transcript::new` seeds in the crate are exactly 40 bytes
   (`private_seam.rs:26`, `public_block_receipt.rs:20`), both off that path.
   The qualification as the draft wrote it ("unused elsewhere") was already
   not satisfied crate-wide. Conditions **C-H4** and **C-H4′**; on the
   block's path it is also one row count away from being false, a 5-row
   commitment's `hash_column` input being 40 bytes.
3. **It rests on `/dev/urandom`**, an assumption about the operating system
   that no hash model covers. Name it in the statement.
4. **It rests on convention V-1, which is ASSUMED, not relied on** —
   indifferentiability, per correction C-5. That is the reason the security
   owner keeps M-3 primary: *a privacy statement should not quietly depend
   on a stronger property of the hash than the one being put to the project
   owner.*

**And one thing it does not buy.** The `fp()` reduction bias is untouched: a
uniform 128-bit draw reduced mod `p = 2^64 − 2^32 + 1` is still exactly
`2^-96` from uniform, 327,052 draws still give `≤ 2^-77.7` for one toy proof,
and D9 still governs it. The ROM makes the *stream* uniform; it does not make
the *reduction* unbiased. This is the term that enters hop **G_3 → G_4** of
Route A (§3.3), once per proof.

**Where the 327,052 draws come from (correction C-12).** The draft
hard-coded the number with no derivation; the independent check rebuilt it
call site by call site and got 327,052 **on the nose**:

| site | draws |
|---|---:|
| `A` mask and proximity rows, `(455 − 213)·256` | 61,952 |
| `A` pads, `455·256` | 116,480 |
| the 23 CFS masks, `2 × Σ((n+e)·d + 2) = 2 × 583` (`layout.rs:438-462` SLOTS, `sumcheck.rs:197-203`) | 1,166 |
| `M` row pads, `23·2·256` | 11,776 |
| `M`'s `b_re, b_im, u_re, u_im`, `4·1024` | 4,096 |
| `H` mask and proximity rows, `(384 − 280)·256` | 26,624 |
| `H`'s two zero-sum rows, `2·255` | 510 |
| `H` pads, `384·256` | 98,304 |
| the two endpoints, `2·((7−2)·256 + 7·256)` | 6,144 |
| **total** | **327,052** |

[RECOMPUTED by the check; the site list is the check's own argument. The
per-draw bias is exactly `b(p−b)/(p·2^128)` with `b = 2^128 mod p`, which
the check confirms is 2^-96 to twelve places and strictly below it, so the
draft's "exactly 2^-96" is right and conservative.]

### 5.2 The statement

> **The sentence the security owner could adopt, if the project owner accepts
> D19.** *In the random-oracle model for BLAKE3 (proposed ruling D19, with the
> two conventions of §5.1), for the toy private-block profile
> `hashline-zk-mr1/private-block-t32-poc/1` under ruling D18, and for every
> admissible hidden input `w`: the whole view of a verifier making at most `q`
> oracle queries — the 112-byte expected-IO policy including its two endpoint
> roots, the 2,816,472-byte receipt with its three roots, its field values,
> its 1,280 salts and its 1,280 authentication paths, and whether the prover
> refused — is within* `ε(q)` *in total variation of the same view produced by
> the honest prover on the all-zero input, which sees no hidden data;* `ε(q)`
> *is the sum below. **The exclusions, in the same sentence** (correction
> C-11): the refusal **string**, a declared GAP (§4); `ProveStats`'s phase
> timings, proposed ruling D20; and anything a capture format might gain
> beyond the three files `native_capture.rs:275` writes, proposed ruling
> D21.*

| residual | source | size | at `q = 2^80` |
|---|---|---|---|
| `fp()` sampler bias | D9, **accepted**; 327,052 draws at exactly 2^-96 | **2^-77.7** | 2^-77.7 |
| LogUp-collision refusal | privacy-case item 19, recomputed by its check; the one witness-dependent refusal of eighteen | **2^-112.0** (2^-117.4 counting distinct) | 2^-112.0 |
| generic-rank term `Δ_gr` | `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md`: on the accepted structural route the disclosure set lies **inside** the refusal set, so conditioning on `NR(ρ)` removes it | **0** on that route; **≈ 2^-56** on the fallback if its structural step is rejected | 0 |
| salt guessing (Lemma H) | §2.4 | `q·12,288·2^-256 = q·2^-242.42` | 2^-162.4 |
| leaf-input collision (Lemma H) | §2.4 | **2^-229.83** | 2^-229.8 |
| 64-byte absorb overlap | §1.5 | **2^-241.42** (earlier project documents said ≈2^-243, an undercount of the objects; corrected 2026-09-20 by the independent check) | 2^-241.4 |
| leaf input = **node** input (C-4, L-7) | §2.3 step 2(d) | **2^-484.83** | 2^-484.8 |
| challenge pre-query (B3) | §3.2; harmless, priced anyway | `q·2^-244.03` | 2^-164.0 |
| absorb-input collision (B4) | §3.2 | **2^-233.07** | 2^-233.1 |
| generator, **in the standard model — PRIMARY** (ruling L-2) | M-3, ruling C-3 | `ε_PRG` against `ZkRng`, **no bit count** | — |
| generator, **in the ROM — the ALTERNATIVE of §5.1, not an addition** | §5.1, ASSUMED (conventions V-1, V-2) | `6q·2^-256 = q·2^-253.42` (C-3: two routes) | 2^-173.4 |
| **sum, `ε(q)`** | | **2^-77.7** at every `q ≤ 2^128` — to **eleven** significant figures, not four: the check's exact sum at `q = 2^128` is `2^-77.699999999915` | **2^-77.6999…** |

**Separately, not in the sum:** the prover **refuses** about once in `2^62.0`
proofs, a completeness (liveness) loss equal in both worlds (§4), **not a
distinguishing term**. That figure is **counted for this block** — four
base-field proximity determinants, `4/p ≈ 2^-62.0`
(`check_opening_challenges`, `protocol.rs:141-152`, reached at `:396`,
`:399`, `:402`, `:405`) — and is **not** imported from the A00 inventory,
whose own page says the number for this shape is OPEN (blocking item B-4,
ruling L-4; the count is the check's §7.2).

**The arithmetic. COMPUTED** (§7.1), and every term independently
**RECOMPUTED** by the check from its own script: the hash-layer terms
together are below `2^-114` even at `q = 2^128` — by 0.6 %, not by the
factor the draft assumed (correction C-2) — so `ε(q)` equals the D9 sampler
term to eleven significant figures at any query budget. **The hash layer is not where this
statement's error goes.** If an auditor ever wanted a smaller `ε`, the lever
is D9's one-line rejection-sampling change (byte-changing, unscheduled), not
anything in the tree.

**No target is proposed and none should be read in.** Ruling C-1 withdrew the
100-bit proposal, and D9 already fixes how the statement reads. This page
lists and sums; it does not grade.

**The conditions that must be printed with the sentence, every time.**

1. **D19 is proposed, not ruled.** Without it there is no sentence: the
   hash-layer terms are replaced by assumptions M-1 and M-2, and M-2 is not
   implied by collision resistance.
2. **Theorem 3.3's own conditions travel**: the uniform-blinding idealisation
   (reached by the explicit replacement hop G_3 → G_4 of §3.3, priced in the
   D9 row), the terminals step supplied by the independent check and
   **independently reviewed and corrected on 2026-09-20**
   (`ZK60_TERMINAL_SURJECTION_REVIEW.md`; ruling J-2 resolved), cross-role
   blinding independence verified by reading and **not machine-asserted**
   (condition O-2), and hypotheses (H1)–(H5). **And the three conditions
   that review added to (H1)** (blocking item B-1, ruling L-5, omitted
   condition O-A): the reserved pair's weight **shape** `(cm, cm·U)`, not
   merely `cm ≠ 0`; on `H` the two groups that **share the zero-sum pair**,
   a stated exception to the per-group argument; and the **pad budget on
   `H`**, where the pad count and the number of opened columns move
   together.
3. **The lift is Route A or Route B** (§3.3). Route A's hybrid must be
   carried **with its idealisation hop**, which the draft omitted (B-2).
   Route B leans on a lemma that exists only on branch `zk60-mvp-fable` and
   **extends** its message alphabet rather than applying it as reviewed
   (condition O-D).
4. **The ideal world exists**: the all-zero input proves and verifies
   (measured 2026-09-20 00:36), and the two constructor facts that make it so
   — `NORM_CEPS = 1` and the pinned first exponential-table entry — are
   hypotheses of the theorem, not background.
5. **The code conditions C-H1 … C-H8 and C-H4′ of §2.5**, with the truth of
   each today and with `rows ∉ {5, 8}` (§1.4, and **not** a new condition:
   C-6). C-H6 is already pinned by a compile-fail doctest; C-H1, C-H4, C-H8
   and C-H4′ are to become byte-free assertions or tests on the 125M lane
   (ruling L-3, condition O-G); C-H2 is false crate-wide and irrelevant to
   the block.
6. **The refusal-string rule** (§4, ruling L-6): the data-dependent strings
   fire only for inputs the statement does not admit, and the service rule
   is that **a refusal reason is never returned to anyone not entitled to
   the input**. D20 and D21 are proposed, not ruled.
7. **This is one shape and one configuration.** §6.
8. **The statement's own two external hypotheses, which are NOT out of
   scope** (omitted conditions O-B and O-E). *O-B*: the 32-byte
   `IoSpec::context` rides inside the 112-byte policy, which this sentence
   puts **in the view**; if a deployment derives it from the request, the
   two worlds do not share a statement and the quantifier collapses. *O-E*:
   the sentence's view is exactly what a capture contains, so D21's capture
   rule is a hypothesis of it — a capture format that gains a field
   computed from hidden data falsifies the sentence.
9. **The generator is carried under the standard assumption M-3 (ruling
   C-3), primary**; the ROM derivation of §5.1 is the ASSUMED alternative
   and costs conventions V-1 (indifferentiability) and V-2 (ruling L-2,
   correction C-5).
10. **Flagged and not chased** (ruling L-7): Merkle node inputs and
    salted-leaf inputs are both 64 untagged bytes. For hiding that is the
    2^-484.83 row; for **binding** it is a soundness question this memo does
    not touch and **nobody has checked**.

**It is not a privacy acceptance.** It is the sentence that *could* be
written if the owner rules and if the conditions above are carried. Nothing
in this page establishes a privacy property, and **D8 and D11 are open.**

## 6. What is NOT covered

Written so a status page can quote it without softening it.

1. **Every other shape. GAP.** This is the toy block at
   `log_cols 8 / inv_rate 8 / Q 256`, with `A` 455 rows, `H` 384, `M` 50 over
   4,096, and two 7-row endpoints. The **development rung and the 125M
   profile owe all of it again**: the tree counts change with `nn`, the
   length-class table must be redone row by row (at 125M the row counts
   quoted by the composition memo — `A` 5,681, `H` 7,186, endpoints re-tiled
   to 29 — give `hash_column` inputs of 45,448 / 57,488 / 232 bytes, none of
   them 40 or 64, but **that is an arithmetic accident at each new shape and
   must be re-checked, not inherited**), and `M`'s `n_base = 2·slots + 4`
   grows with the schedule. Under proposed D19 new profiles also get a
   **separating tag**, which deletes the 2^-241.42 row and makes the
   length-class argument unnecessary there — a reason to add the tag rather
   than to re-do this table.
2. **Sealing in advance by a third party. UNTOUCHED.** D8 and D11 bind that
   configuration and **nothing here touches them**. Under a caller-fixed root
   the simulator would have to *program* an oracle point, and Lemma H — which
   is about genuine trees the prover built — would not be the right tool at
   all (privacy-case item 14; the one-point closure was retracted, D8/D11
   §2.3). **Do not read this page as progress on D8 or D11.**
3. **Side channels.** Timing, memory and power: proposed D20, out of scope,
   not claimed. Refusals are **inside** the argument (§4) — and the
   operational refusal-string channel is a **GAP**, unmet in the code today.
4. **Many proofs about related inputs — what is assumed, and whether it
   composes.** It composes, by a union bound, under one assumption:
   **each proof draws fresh OS randomness** — three `from_os` calls, no seed,
   nothing derived from the witness (`protocol.rs:275`, `private_seam.rs:196`
   twice) — **and `/dev/urandom` gives independent uniform bytes across
   proofs**. Then for `k` proofs against a `q`-query distinguisher
   ```
   ε_k(q) ≤ k·2^-77.7 + k·2^-112.0 + q·k·12,288·2^-256
            + C(k·12,288, 2)·2^-256 + 6kq·2^-256 + k·(the rest)
   ```
   **PROVED HERE** at the hash layer (the salts of different proofs are
   independent, so §2.3's Step 2 applies to their union), and **RELIES ON**
   the composition memo's §6.3 for the field layer (PROVED there for any `n`,
   conditional on Theorem 3.3 and on stream independence). Two honest
   readings of that formula: the cross-proof leaf-collision term is
   quadratic in `k` but still `2^-189.8` at `k = 2^20`; and **the term that
   actually degrades is D9's**, linearly — a service that emits `2^20` proofs
   sits at about **2^-57.7**, not 2^-77.7. That is a product fact worth
   putting in front of the project owner, and it is *not* a hash-layer fact.
   It also does **not** discharge condition O-5 (the measured evidence covers
   **two** proofs, round 23).
5. **The standard model.** Outside D19 the hash-layer terms are replaced by
   M-1 and M-2, and M-2 is a keyed-hiding assumption on BLAKE3 **not implied
   by collision resistance**. No reduction of it to anything is offered here.
6. **The composition with soundness over the same untagged table** —
   condition O-7. **GAP**, and the reason the shared domain still matters
   even though §1.4 disposes of it for privacy. **Ruling L-7 belongs here
   too**: node inputs and salted-leaf inputs are both 64 untagged bytes, so
   for *binding* this is the classical internal-node-as-leaf ambiguity. With
   fixed-depth, position-checked paths it would need a preimage and is not
   believed exploitable — **but it is checked by nobody**, and it is
   flagged, not chased.
7. **Weight privacy (P3), the zkVM line (D7/D3) and rejected-but-emitted
   receipts (privacy-case item 25)** — not in scope, and not improved by
   anything here. **Two items the draft filed here are NOT out of scope and
   have moved to §5.2's conditions 8**: the context-digest condition **O-1**
   and **D21's capture rule** are *hypotheses of the sentence*, because the
   sentence puts the 112-byte policy in the view and the view is exactly
   what a capture contains (the check's omitted conditions O-B and O-E).
8. **Two openings of one commitment.** Prevented by the type system
   (`PreparedPlane` has no `Clone`), not by this argument; two openings of one
   endpoint recover all 512 hidden words (`zkp-core/tests/endpoint_reuse.rs`).
   A hash-layer lemma would not notice.

## 7. Evidence

### 7.1 `hash_layer_counts.py`

`results/zk60_hash_layer_fs_lift/hash_layer_counts.py`, output
`hash_layer_counts.json` beside it. One file, exact arithmetic, no
dependencies, runs in well under a second. **It reads no capture, no witness,
no salt and no private plane**; every input is a geometry constant quoted
from a source line in the file's own header. Nothing was built, proved,
verified or benchmarked for this page.

What it computes and what it is worth:

| it computes | worth |
|---|---|
| per tree: distinct opened leaves, leaf digests revealed, **of them the ones whose column is never opened**, internal nodes revealed, total revealed, fraction of the tree | an **illustration** for `A`/`H`/`In`/`Out` — it **reproduces `ZK60_D8_D11_RESTATEMENT.md` §3.3 to the displayed digit** (240.7 / 453.2 / 212.5 / 1,200.6 / 1,654.8 / 40.4 %), which is the cross-check that it computes the intended object; **new** for `M` (4,096 leaves, depth 12: 248.2 / 481.4 / 233.2 / 1,653.8 / 2,136.2 / 26.1 %), which no document had counted |
| the whole-proof totals: 12,288 encoded columns, 11,077 unopened, 12,283 internal nodes, 1,211 distinct published salts, 8,755 nodes revealed | the coefficients of every term in §2.4 |
| the oracle-query length classes as a dictionary | a machine-readable copy of §1.4, so a future shape can diff it |
| the residual terms in log2, and their sum at `q = 2^50, 2^80, 2^128` | the arithmetic behind §2.4, §3.2 and §5.2 |
| a **bound** of 4,000 transcript queries, not a count | flagged as a bound in the file and in §3.2 |

Its limits, stated: the node counts are **expectations** over the index draws
(the receipts' own distinct counts are 231–246, so the realised numbers move
by a few per cent); it models `Pr[B_H]` with the conservative leaf count `nn`
rather than `nn − d`; and it proves nothing — it evaluates the formulas this
page derives.

### 7.2 The independent check's own recount

`results/zk60_hash_layer_fs_lift_check/recount.py`, output `recount.json`,
written for `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md` **off the source lines
and not from the script above**. Every term of `ε(q)` reproduced; the sum at
`q = 2^128` agrees with 2^-77.7 to eleven significant figures; the 327,052
`fp()` draws were rebuilt call site by call site and agree exactly (§5.1);
`24,571 · 2^-256 = 2^-241.4153` is confirmed and the earlier `2^-243`
identified as an undercount; and four of §1.5's absorb lengths, one display
line of `ε_lift` (§3.2) and the two missing terms (C-3, C-4) were corrected
from it. No capture, witness, salt or private plane was read for either
script.

## 8. The label table, step by step

Three labels, as the brief requires: **PROVED HERE**, **RELIES ON** (a named,
cited fact) and **GAP**. Two more appear because this page would otherwise
launder them: **VERIFIED IN THE CODE** (a source reading at a named line — it
says what the code does, not that it suffices), **COMPUTED** (arithmetic run
in §7.1), **ASSUMED** (the model) and **CONDITION** (something an acceptance
must carry that nothing enforces today).

**The table below is the independent check's, not the draft's.** The check
re-labelled all 41 rows itself and **never strengthened one**; it adds an
eighth label, **MIXED**, for a row that is proved but whose statement must
be rescoped or whose enumeration is incomplete. Its nine demotions — rows 4,
5, 13, 16, 21, 23, 30, 31 and 35 — are applied here with its reasons, and
its tally replaces the draft's. No row is promoted.

| # | § | step | label |
|---:|---|---|---|
| 0 | §2.2, §5.1 | the model: one long-output oracle for unkeyed BLAKE3 (V-1), an independent oracle for keyed BLAKE3 (V-2), i.e. proposed ruling **D19** | **ASSUMED** |
| 1 | 1.1 | the leaf preimage `blake3(blake3(column)‖salt)`, the 32-byte salt per **encoded** column from the proof's own OS-seeded stream, and the exhaustive list of what a receipt publishes of the tree | VERIFIED IN THE CODE |
| 2 | 1.2 | the per-tree revealed-node counts; the `A/H/In/Out` rows reproduce `ZK60_D8_D11_RESTATEMENT.md` §3.3 exactly, the `M` row is new | COMPUTED |
| 3 | 1.3 | sampling with replacement: 231–246 distinct, 1,211 distinct published salts, duplicated paths | VERIFIED IN THE CODE |
| 4 | 1.4 | the length class of every oracle query **on the toy-block path** | **MIXED** (demoted) — the arithmetic is right, but the draft's table was incomplete (the two 40-byte `Transcript::new` seeds) and four absorb lengths were wrong (`mask-prox`, `parameters`, `sc-round`, `pb-term`; C-7). None of the errors touches 64, so the conclusion stands — but a row claiming "*every* class in the system" cannot be unconditional while it is missing classes |
| 5 | 1.4 | **47 is used by nothing else** (unconditionally, on every path); **40 is used by nothing else on the block's path** | **MIXED** (demoted, B-3) — "47 is occupied by nothing else" is confirmed unconditionally; "40 is occupied by nothing else either" is **false of the crate** (`private_seam.rs:26`, `public_block_receipt.rs:20`) and true only of the toy-block path |
| 6 | 1.4 | `rows ∉ {5, 8}` for every commitment, and (added by the check, condition O-C) **C-H4′**: no accepted private profile's transcript domain has length 28 or 35 | **CONDITION** — and `rows ∉ {5, 8}` is **not new** (C-6): privacy-case item 16 already names both values, crediting condition 28 of the D8/D11 check. Both hold on the block path today (the row counts by construction for the endpoints and by accident for `A`, `H`, `M`); C-H4′ is false crate-wide; neither is asserted |
| 7 | 1.5 | exactly one 64-byte absorb on this path (`absorb_u64(b"log-cols", ·)`), with a fixed 32-byte suffix | **PROVED HERE** |
| 8 | 1.5 | the overlap term `24,571·2^-256 = 2^-241.42` | **PROVED HERE**, unconditionally (and the `2^-243` earlier in circulation is settled as an undercount: C-1) |
| 9 | 2.1 | what the composition needs is the **conditional** law `law(H \| V)`, not a second marginal | **PROVED HERE** (elementary, and it is the step the counterexample makes necessary) |
| 10 | 2.1 | Theorem 3.3: the field view's law at fixed non-refused challenges is witness-free | **RELIES ON** (`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, core accepted; its conditions travel) — **with three conditions added** by the J-2 review (B-1, L-5): the reserved pair's weight shape `(cm, cm·U)`, `H`'s shared zero-sum pair as a stated exception, and `H`'s load-bearing pad budget |
| 11 | 2.2 | **Lemma H** | **PROVED HERE**, inside row 0 |
| 12 | 2.3 §1 | opened leaves are a public function of `V` and the published salts — the verifier recomputes them | VERIFIED IN THE CODE |
| 13 | 2.3 §2 | unopened leaves are fresh uniform oracle images; the **four** ways that fails, each bounded | **MIXED** (demoted) — the draft listed three; a leaf input can also coincide with a **node** input (2^-484.83, C-4). Proved inside row 0 once the list is completed |
| 14 | 2.3 §3 | the induction up the tree: a node input carries no secret beyond its children, so `T^O` is public and witness-free | **PROVED HERE** |
| 15 | 2.3 §4 | the root is one such node; the top pair is revealed with probability `1 − 2^-255` and nothing leans on it being hidden | **PROVED HERE** / RELIES ON the count |
| 16 | 2.4 | `Pr[B_H] ≤ q·2^-242.42 + 2^-229.83 + 2^-241.42 + 2^-484.83 + ε_gen(q)` | **MIXED** (demoted) — the arithmetic reproduces exactly, but as the draft wrote it `Pr[B_H]` was missing the leaf-versus-node term (C-4) and `ε_gen` was missing the entropy-guessing route (C-3) |
| 17 | 2.5 | conditions C-H1 … C-H8 and C-H4′, each with its truth today, at the line, and how it could be pinned | VERIFIED IN THE CODE (the check's table, adopted whole) |
| 18 | 2.5 | C-H8: a future external/device commit path | **GAP** |
| 19 | 3.1 | the transcript order, and that **only the five roots of the hash view are absorbed** — salts and paths influence nothing | VERIFIED IN THE CODE |
| 20 | 3.1 | every challenge input in one proof is distinct, because the squeeze counter increments | **PROVED HERE** |
| 21 | 3.2 | bad events B1, B2, B7 are **impossible**; B3, B4, B5, B6 are sized | **MIXED** (demoted) — B1, B2, B7 are confirmed zero and each size is confirmed term by term, but the **summed** `ε_lift` display line was wrong at every `q` (C-2, corrected in §3.2) and B3's stated reason covers pre-receipt queries only |
| 22 | 3.3 | the oracle splits by input length into independent restrictions, so the challenge function is independent of the prover's randomness | **PROVED HERE** |
| 23 | 3.3 | **Route A**: lazy sampling — the real experiment has the same law as the fixed-challenge experiment with uniform `ρ`, through the eleven-hop hybrid | **MIXED** (demoted, B-2) — the conclusion is reachable and the hybrid now reaches it, but the draft's derivation **omitted the idealisation hop** (G_3 → G_4, the D9 replacement) and left the generator's non-adaptivity (O-F) implicit |
| 24 | 3.3 | **Route B**: the sequential-kernel lemma over paired (field, hash) messages, which is what condition O-4 asked for | **RELIES ON** — the lemma's proof and tests are **only on branch `zk60-mvp-fable`** (the check could not verify them), and Route B **extends** its message alphabet rather than applying it as reviewed (O-D) |
| 25 | 3.3 | Route B's causality hypothesis against the code | VERIFIED IN THE CODE |
| 26 | 3.4 | every pad symbol enters **every** encoded column, opened or not, and the pad halves of the group and proximity vectors are published in full | **PROVED HERE** (from `encode_row_zk`) |
| 27 | 3.4 | why `(H(mask), mask ⊕ w)` does not apply: conditioned on everything the adversary has **and on the unopened columns themselves**, the leaf digest is uniform, because its point is addressed by an unpublished 256-bit salt (the draft's "not a function of the pads" is withdrawn as literally false) | **PROVED HERE**, inside row 0 |
| 28 | 3.4 | the pad halves are determined by the opened columns (up to the `10…25` pad-only coordinates) | **RELIES ON** (`ZK60_GENERIC_RANK_LEMMA*`, `..._COMPOSITION.md` §4.2) |
| 29 | 4 | a refusal is terminal; there is no restart; "opened twice" is prevented by the types | **RELIES ON** (ruling J-4) |
| 30 | 4 | the 18-class inventory; one witness-dependent class at 2^-112.0; the challenge-driven rate ≈ 2^-62.0 | **MIXED** (demoted, B-4) — the inventory is relied on correctly (privacy-case items 19 and 24 and their check), but the **rate is not in the cited source for this shape**, which says it is OPEN. It is carried here as the check's own count: four base-field determinants, `4/p ≈ 2^-62.0`, a liveness figure |
| 31 | 4 | discharging the conditioning: `d(view_w, view_0) ≤ Pr_w[LogUp] + Pr_0[LogUp] + sup_{NR ρ} d(…) ≤ 2·2^-112.0 + ε_hash` | **MIXED** (demoted, C-8) — the draft's decomposition omitted the shift in the conditional law of `ρ` given completion; the honest constant is 2, and the corrected form is elementary |
| 32 | 4 | the ideal world exists: the all-zero input proves and verifies, with the two boundaries pinned | **RELIES ON** (measured, `zero_witness_tests.rs`, `ec84dac`) |
| 33 | 4 | the refusal string names the failing relation, for inputs the statement does not admit | **GAP** (engineering, a service boundary; unmet today) — with the rule of L-6: a refusal reason is never returned to anyone not entitled to the input |
| 34 | 5.1 | the generator read exactly: keyed derivation, **unkeyed 40-byte XOF stream** | VERIFIED IN THE CODE |
| 35 | 5.1 | in the ROM, `ε_gen(q) ≤ 6q·2^-256` — the **alternative** reading of the generator, M-3 (ruling C-3) staying primary | **MIXED** (demoted, C-3/C-5) — correct inside the model, but the draft's bound was incomplete (the OS-entropy route) and convention V-1's stated justification (the XOF prefix property) does not license a long-output oracle; **indifferentiability does, and V-1 is now ASSUMED**. Under ruling L-2 the whole derivation is presented as the ASSUMED alternative, not as a saving |
| 36 | 5.2 | the summed statement and its residual table | COMPUTED, and conditional on rows 0, 10, 11, 23/24 |
| 37 | 6.4 | `k` proofs compose by a union bound; the hash-layer half | **PROVED HERE**; the field-layer half **RELIES ON** the composition memo §6.3 |
| 38 | 6.5 | the hash layer in the **standard** model | **GAP** (assumption M-2, not implied by collision resistance) |
| 39 | 6.6 | composition with the soundness reduction over the same untagged table (O-7) | **GAP** |
| 40 | 6.1 | every other shape — the development rung and the 125M profile | **GAP** |

**Tally over the 41 rows — the independent check's, replacing the draft's:
11 PROVED HERE, 9 MIXED, 5 RELIES ON, 7 VERIFIED IN THE CODE, 2 COMPUTED,
1 ASSUMED, 1 CONDITION, 5 GAP** (the gaps are rows 18, 33, 38, 39, 40: a
future device commit path, the refusal string, the standard model, the
composition with soundness, and every other shape; the nine MIXED rows are
4, 5, 13, 16, 21, 23, 30, 31, 35). The draft's tally read 18 PROVED HERE,
6 RELIES ON, 7 VERIFIED IN THE CODE, 3 COMPUTED, 1 ASSUMED, 1 CONDITION,
5 GAP; **no label here is stronger than the check's**, and the check
promoted nothing.

**And the honest reading of the 11, in the discipline the privacy case set.**
**None of them is unconditional.** Most are elementary derivations *inside
the assumed model* (rows 11, 14, 15, 27 and the parts of 37 that depend on
them) or downstream of Theorem 3.3, which is itself accepted-with-conditions
— now including the three the J-2 review added. **The rows that are
unconditional are four, not the six the draft claimed: 7, 8, 20 and 26** —
exactly one 64-byte absorb on this path; the overlap term; every challenge
input in a proof being distinct because the squeeze counter increments
(`transcript.rs:90`); and every pad entering every encoded column
(`encode_row_zk` with the coset assertion at `pcs.rs:613-615`). **Rows 4 and
5 survive rescoped to the toy-block path, which is not the same thing as
unconditional.** That is what this page adds that nobody can take away;
everything else is conditional on a model the project owner has not yet
ruled on and on a theorem accepted the night before.

## 9. The circularity check: what each step assumes that a later step concludes

**Why this section is here.** A delegated argument in this repository was
refused two days ago for a hypothesis that restated its conclusion, and the
project's discipline since then is to answer, for every step, *what does this
step assume that a later step concludes?* An entry in the last column is a red
flag. There is none — the independent check looked for one too and found
none, and confirmed the quantifier order in Lemma H is the safe one
(∀ρ ∃T, not the reverse). What there are instead are the four **declared
premises** below, which are a different and declared defect.

| step | assumes | which step concludes it | circular? |
|---|---|---|---|
| §1.1–1.5 the code facts and the length table | nothing but the source | — | no |
| §2.1 the factorisation `law(V,H) = law(V)·law(H\|V)` | nothing; it is the definition of conditional probability | — | no |
| §2.1 Theorem 3.3 | the composition memo's accepted core | concluded **earlier and elsewhere**, not here | no |
| §2.2–2.3 **Lemma H**, at a fixed `ρ` | that `ρ` is **exogenous** — the interactive experiment | §3.3 concludes that the real protocol's `ρ` behaves like a uniform exogenous one. **This is the row to look at twice.** It is not circular: Lemma H is proved *for every* fixed `ρ`, with no assumption about how `ρ` arose, so §3.3 may use it at each `ρ` without §3.3 being used inside it | **no** — and the check should confirm the quantifier order: "for all `ρ`, the law is witness-free", never "the law is witness-free for the `ρ` that occurs" |
| §2.3 Step 2, the unopened leaves | that the **salts are uniform and secret** | **M-3 (ruling C-3) assumes it — the primary route (L-2)** — and §5.1's in-model derivation concludes it as the ASSUMED alternative. §5.1's argument uses the oracle only at **40-byte** inputs, the refills' non-adaptivity and the key's secrecy; it does not use Lemma H | no |
| §2.3 Step 3, the node induction | that node inputs are distinct and carry no salted data | its own bound (B6) and `merkle.rs:14-19` | no |
| §3.2 **B7** (no grinding) | that `a_root` is unpredictable to the distinguisher | §2.3 Step 2 — the leaves are fresh images. Step 2 does not use B7 | no |
| §3.3 Route A | that every challenge input is fresh (B1), the length split (§1.4), the generator refills' **non-adaptivity** (O-F), and — at hop G_3 → G_4 — that the real prover's biased blinding may be **replaced by uniform blinding** at D9's 2^-77.7 | all are established earlier and independently: B1 and the length split in §1.4 and §3.1, non-adaptivity from `rng.rs:53-57`, the replacement from the `fp()` bias of §5.1 and decision D9 | no |
| §3.3 Route A's **conclusion** | it is stated "up to the refusal conditioning of §4" | §4 closes it, and §4 uses Route A's uniformity. **Not mutually dependent**: Route A's equivalence of experiments is unconditional — it is a statement about the whole run, refusal or not — and §4 then splits on an event | no |
| §3.3 Route B | the sequential-kernel lemma and the per-`ρ` joint hypothesis | the hypothesis is Theorem 3.3 × Lemma H, both concluded before | no |
| §3.4 the counterexample disposal | Lemma H's conditioning | concluded in §2 | no |
| §4 the refusal law | uniform challenges (§3.3) and the inventory | concluded before | no |
| §5.1 `ε_gen` | conventions V-1, V-2, the secret OS key, and that **40 bytes** is an unused class | §1.4 concludes the last; the others are assumptions declared at row 0 | no |
| §5.2 the sum | every row above | — | no; it is correctly last |

**The declared premises — unenforced, unverified here, or carried from
elsewhere; not circular, and they must be written as such wherever this page
is quoted.**

1. **Theorem 3.3 carries a step supplied by the independent check** (ruling
   J-2, the 173 individual terminals). The draft called that step "reviewed
   by nobody"; **that was stale and is withdrawn** — the step was
   **independently reviewed and corrected at 03:49 on 2026-09-20**
   (`ZK60_TERMINAL_SURJECTION_REVIEW.md`, ruling J-2 resolved). What every
   conclusion of this page now inherits is the **three conditions that
   review added** (§2.1, §5.2 condition 2): the reserved pair's weight shape
   `(cm, cm·U)`; `H`'s two groups sharing the zero-sum pair, as a stated
   exception; and `H`'s load-bearing pad budget. **Blocking item B-1.**
2. **Route B's sequential-kernel lemma exists only on branch
   `zk60-mvp-fable`**, so the check could not verify it, and Route B
   **extends** its message alphabet (O-D). Route A is carried precisely so
   that an acceptance need not rest on it.
3. **Conditions C-H1 … C-H8, C-H4′ and `rows ∉ {5, 8}` are enforced by
   almost nothing.** They are properties of today's call sites and row
   counts, not invariants of the crate — with one exception the draft did
   not know: **C-H6 is already pinned** by the compile-fail doctest at
   `private_block.rs:360-366`. **C-H1, C-H4, C-H8 and C-H4′ are to become
   byte-free assertions or tests on the 125M lane** (ruling L-3), and C-H2
   is false crate-wide and irrelevant to this block.
4. **The generator is carried under M-3 (ruling C-3)**, and the in-model
   alternative of §5.1 rests on convention V-1, which is **ASSUMED** and
   needs an indifferentiability citation nobody here has checked (C-5).

**One shape of over-claim this page must not be read into.** The privacy
case's rule — *no sentence may use a COMPUTED ON CAPTURES result as the
premise of a universally quantified claim* — has an analogue here: **no
sentence may use a ROM derivation as a statement about BLAKE3.** Rows 11, 13,
23, 27 and 35 are statements *inside* a model that is a proposed ruling.

## 10. The questions this page put to the checker, and the answers it got

**All ten were answered by the independent check** (`..._CHECK.md` §11.1);
the answers are recorded with each question below and summarised in the
table at the end of the section. The questions are kept as they were asked,
with the claims the check corrected marked in place.

**1 — the generator and the oracle are the same function, and §5.1 turned
that into a saving. Is that legitimate?** `ZkRng::refill` is plain unkeyed
BLAKE3 over `key ‖ counter` (`rng.rs:53-61`), the same function that hashes
the tree. The draft concluded that inside D19 the PRG assumption M-3 is
"not needed" and is replaced by `3q·2^-256`; **that conclusion is withdrawn
as primary** (ruling L-2) and the term is `6q·2^-256` (C-3). Three specific
things were put up to attack: (i) convention **V-1**, that one long-output
oracle models both the 32-byte hash and the XOF — is the "first 32 bytes of
the XOF equal the hash" property of BLAKE3 enough, or does an
indifferentiability argument have to be cited? (ii) convention **V-2**,
keyed BLAKE3 as an independent oracle — is the flag separation sufficient in
a model where the adversary picks inputs? (iii) whether an argument that
uses one primitive as both the FS oracle and the PRG core is acceptable
practice at all, or whether the project should simply keep M-3 and lose
nothing. **Answered: mechanism yes, presentation no.** (i) V-1 needs
**indifferentiability** and is demoted to ASSUMED (C-5); (ii) V-2 is a sound
and conservative convention, no demotion; (iii) **keep M-3 as primary** —
which is what ruling L-2 does. The bound was also short one route (C-3).
*Nothing else on this page depends on §5.1: with M-3 primary, the residual
table's generator row is `ε_PRG`, and the ROM row is the alternative.*

**2 — the lazy-sampling step of Route A (§3.3).** This is the step this page
recommends carrying, so it is the one to break. The prover queries the oracle
at 40-, 64-, and various other byte lengths *while* challenges are being
drawn at 47 bytes, and the **inputs** to the later queries contain earlier
challenge values (`squeeze_bytes` sets `state = out`, `transcript.rs:92`), so
the classes are not independent as *processes*, only as *functions*. Is the
chronological lazy-sampling argument airtight under that feedback? Is there
any place where the prover's behaviour depends on an `O_47` value other than
through a challenge it was handed?

**3 — is Lemma H's inventory of the hash view complete?** The lemma asserts
`H = T^O(opened columns, published salts, unopened leaf digests)`. A single
published hash object that is *not* a node of one of the five trees would
falsify it. I checked `OpeningZk::write_bytes` (`pcs.rs:582-601`), the
`MaskOpening` path (`zk.rs:544-548`) and the receipt frame
(`private_block/wire.rs:71-99`) and found none. **This is the source reading
most worth redoing**, in the same spirit as the composition check's Q3.

**4 — is the leaf-input collision term (2^-229.83) necessary?** It is the
largest hash-layer term at small `q`. I include it because the model wants
*distinct* oracle inputs, but i.i.d. uniform digests may collide too, so a
sharper argument may delete the term. A checker who deletes it improves the
bound and should say what replaces the "fresh input" requirement.

**5 — the 2^-243 that was in circulation versus the 2^-241.42 recounted
here. SETTLED.** `ZK60_JOINT_LAW_COMPOSITION.md` §5.2, its check's §A6.2,
the disposition of 2026-09-20 and the D19 one-pager all said ≈2^-243. The
count of the candidate objects is 12,283 node inputs plus 12,288
salted-leaf inputs = 24,571, giving **2^-241.42**, which the check
reproduced from its own script. **2^-243 corresponds to ≈8,200 objects —
8,192 is exactly the salted leaves of the four 2,048-leaf trees, so it left
out `M`'s 4,096 leaves and all 12,283 internal nodes** (C-1). The
owner-facing documents were corrected on 2026-09-20.

**6 — the `k`-proof formula of §6.4.** Is the cross-proof leaf-collision term
the right one, and does the field layer's §6.3 product law really survive the
endpoints being consumed (so that two proofs about the same input cannot
share an endpoint commitment)? And is the **linear degradation of the D9 term
with `k`** — 2^-57.7 at a million proofs — something the project owner should
be told before a service is built, rather than after?

**7 — Route B's causality check (§3.3).** I verified from the transcript
order that no message depends on a later challenge, including the host slots,
which run **after** the slots they host. A checker should re-read
`argument.rs:255-380` against `HOSTS` (`layout.rs:501-508`) rather than trust
that reading.

**8 — the 4,000 bound on absorbs plus squeezes (§3.2).** It is a bound, not a
count; I did not count them. Should it be counted exactly, and does anything
depend on it beyond a 2^-233 term?

**9 — the two code conditions this page carries.** `rows ∉ {5, 8}` for every
commitment (§1.4 — **not new**, C-6) and "a salt is published if and only if
its column is" (C-H1). Both hold today; neither is asserted. Are they worth
a Rust test now, or at the 125M shape, where the row counts change anyway?
**Answered: yes, both, and now** — each is a few lines and neither changes a
byte; the row check belongs in the block's own layout test, **not** in
`zkp-core`. And the draft did not know that **C-H6 is already pinned** by a
compile-fail doctest (`private_block.rs:360-366`), which is the same
treatment. Ruling L-3 sends C-H1, C-H4, C-H8 and C-H4′ to the 125M lane as
byte-free assertions or tests.

**10 — what the hash layer inherits from Theorem 3.3's terminals step.**
Every conclusion here multiplies a hash-layer kernel by the field-layer law.
If the terminals step (ruling J-2) is wrong, the product is wrong. The draft
asked this of a step it called unreviewed; **the step was independently
reviewed and corrected on 2026-09-20**, and what it now carries is the three
conditions of §2.1. The question that remains is the one the draft asked
next: is there any part of §2 or §3 that would survive a failure of Theorem
3.3? **Answered: yes — Lemma H and the whole length-class analysis are
independent of it.** Lemma H is a statement about the conditional law of the
hash view **given** the field view, and it holds whatever the field view's
own law turns out to be; if Theorem 3.3 moved, §2 would survive verbatim and
only the product step would need redoing.

**The check's answers, in one line each** (`..._CHECK.md` §11.1):

| # | the answer |
|---:|---|
| 1 | mechanism yes, presentation no: V-1 needs indifferentiability (ASSUMED), V-2 is sound and conservative, **keep M-3 primary**, and the bound was short one route |
| 2 | **yes**, the lazy-sampling step is airtight — the missing ingredient is the refills' **non-adaptivity**; no prover behaviour depends on an `O_47` value except through a challenge it was handed |
| 3 | **yes**, the inventory is complete; the reading was redone and widened to `ProveStats`, the wire `binding`, `last_mask_sites` and the capture files |
| 4 | **yes, the leaf-input collision term is necessary** — it is the salts' birthday bound; counting only unopened leaves would buy 0.16 bits |
| 5 | **2^-241.42**; 2^-243 counted ≈8,200 objects, the four 2,048-leaf trees' salted leaves alone |
| 6 | the `k`-proof formula is the right shape and the arithmetic checks; **yes, the owner should be told** about the linear D9 degradation (≈2^-57.7 at a million proofs) |
| 7 | **re-read and confirmed** (`layout.rs:501-508`, `argument.rs:286-288`): a host consumes only earlier slots' values |
| 8 | **no** — an honest bound beats a count that could go stale with the schedule |
| 9 | **yes, both, and now**; and C-H6 is already pinned by a compile-fail doctest |
| 10 | **yes** — Lemma H and the length-class analysis are independent of Theorem 3.3 and would survive it moving |

## Revision record (2026-09-20)

One row per adjudicated item: the blocking items **B-1 … B-4**, the
corrections **C-1 … C-13** and the omitted conditions **O-A … O-G** of
`ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md`, and the rulings **L-1 … L-7** of
`ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md`. **No claim was added beyond
what those two documents establish, no label was strengthened beyond the
check's, and no evidence file was edited.** Where a ruling differs from the
draft or from the check, the ruling wins — above all L-2.

| Item | Section(s) changed | What changed |
|---|---|---|
| **B-1** (with L-5, O-A) | §0, §2.1, §5.2 condition 2, §8 row 10, §9 premise 1, §10 Q10 | "reviewed by nobody" withdrawn as stale: the terminals step was **independently reviewed and corrected on 2026-09-20** (`ZK60_TERMINAL_SURJECTION_REVIEW.md`, ruling J-2 resolved at 03:49). The **three conditions that review added to (H1)** — the reserved pair's weight shape `(cm, cm·U)`, `H`'s two groups sharing the zero-sum pair as a stated exception, `H`'s load-bearing pad budget — now travel with Theorem 3.3 at every citation |
| **B-2** (with L-1, O-F) | §3.3 Route A, §8 row 23, §9 table and premises | the missing hop written in: Route A is now the check's eleven-hop hybrid, each hop citing a named lemma or a listed bad event, with **G_3 → G_4** replacing the real prover's biased blinding by uniform blinding at **D9's 2^-77.7, once per proof**, before Theorem 3.3 is invoked; the salts need no replacement (`bytes32` is raw stream); the refills' **non-adaptivity** is stated at G_1 → G_2. Row 23 demoted to MIXED |
| **B-3** (with L-3, O-C) | §1.4 heading, table (row Q11) and bullet, §5.1 qualification 2, §2.5, §8 rows 4, 5, 6 | "40 is occupied by nothing else" rescoped to **the block profile's path**: two other transcripts start with 40-byte inputs (`private_seam.rs:26`, `public_block_receipt.rs:20`), both off that path. Rows 4 and 5 demoted to MIXED; condition **C-H4′** added (no 28- or 35-byte transcript domain) |
| **B-4** (with L-4) | §4 class table and a new counted block, §5.2 "Separately, not in the sum", §8 row 30 | the imported 2^-62.0 replaced by **the check's own count** — four base-field proximity determinants, `4/p ≈ 2^-62.0` (`protocol.rs:141-152`, reached at `:396`, `:399`, `:402`, `:405`) — carried as a **liveness** figure, not a distance, with the cited source's "OPEN, and this page does not guess it" quoted. Row 30 demoted to MIXED |
| **C-1** | §1.5, §5.2 residual table, §10 Q5 (and, outside this memo, `ZK60_JOINT_LAW_COMPOSITION.md`) | 2^-241.42 kept and the earlier **2^-243 explained as an undercount** (the four 2,048-leaf trees' salted leaves only, without `M`'s 4,096 leaves and the 12,283 inner nodes); the check's remark added that the true bound using both halves is about 2^-497 |
| **C-2** | §3.2 `ε_lift` display | the draft's line was the salt term alone; replaced by the check's sums **2^-228.837 / 2^-192.008 / 2^-162.008 / 2^-114.008** at `q = 2^12 / 2^50 / 2^80 / 2^128`, with the note that §5.2's "below 2^-114" survives by 0.6 % |
| **C-3** (with L-2) | §0, §2.2, §2.4, §3.2 B6, §3.4, §5.1, §5.2, §6 item 4 | `ε_gen(q)` completed to **`6q·2^-256 = q·2^-253.42`**: the second route is guessing the 32-byte operating-system entropy and recomputing the key through `O_k` on a public input |
| **C-4** (with L-7) | §1.5, §2.2 Lemma H, §2.3 step 2(d), §2.4, §3.2 B6, §5.2 | the fourth failure mode added — a salted-leaf input equal to a **node** input, both 64 untagged bytes — at `12,283·12,288·2^-512 ≈ 2^-484.83` |
| **C-5** | §5.1 conventions, §8 row 35, §9 premise 4, §10 Q1 | **V-1 demoted from RELIES ON to ASSUMED**: the XOF prefix property makes the two readings consistent, but licensing one long-output oracle needs **indifferentiability**, which is cited and not established here |
| **C-6** | §1.4 bullet, §8 row 6 | `rows ∉ {5, 8}` is **not new**: privacy-case item 16 already names both values, crediting condition 28 of the D8/D11 check, and already observes that `A`, `H`, `M` are protected by nothing |
| **C-7** | §1.5 absorb enumeration, §8 row 4 | four absorb lengths corrected: `mask-prox` **16,441**, `parameters` **171**, `sc-round` **≥ 104**, `pb-term` **once per slot, 71…951**. None is 64 |
| **C-8** | §4 discharge, §8 row 31 | the refusal decomposition replaced by `d ≤ Pr_w[LogUp] + Pr_0[LogUp] + sup_{NR ρ} d(…) ≤ 2·2^-112 + ε_hash`, because the conditioning event itself differs between the worlds. Row 31 demoted to MIXED |
| **C-9** | §4 class table | "14 of 18" replaced by the check's grouping: 10 shape/schedule/policy/environment rows, 2 unreachable panics, 1 witness-builder row, 4 challenge-driven, 1 witness-dependent |
| **C-10** (item 3 of the brief) | §2.2 Lemma H, §2.3 conclusion, §3.4, §8 row 27 | Lemma H restated in the check's exact conditional form: conditioned on the field view, the published salts, the challenges, non-refusal, **the unopened columns** and **the adversary's `q` oracle answers**, the unopened leaves' digests are the same product of uniforms for every hidden input. "Independent of the unopened columns" withdrawn; the sentence that the bound rests on the **salt alone**, using no column entropy, promoted out of its parenthesis |
| **C-11** | §0, §5.2 statement | "the whole view" now names its exclusions in the same sentence: the refusal **string** (a GAP), `ProveStats`'s timings (D20), and anything a capture format might gain beyond the three files `native_capture.rs:275` writes (D21) |
| **C-12** | §5.1 | the **327,052** `fp()` draws derived call site by call site (the check's list), instead of hard-coded |
| **C-13** | §0 | §0's "one thing this page found" no longer states the M-3 saving without its conventions; under L-2 it states the finding and then the ruling |
| **O-A** | see B-1 | the three J-2 conditions travel with Theorem 3.3 |
| **O-B** | §5.2 condition 8, §6 item 7 | privacy-case **O-1** (the 32-byte `IoSpec::context` inside the 112-byte policy) moved from "not in scope" to a **hypothesis of the sentence** |
| **O-C** | §1.4, §2.5, §8 row 6 | **C-H4′** added: no accepted private profile's transcript domain may have length 28 or 35 |
| **O-D** | §3.3 Route B, §8 row 24 | Route B recorded as **extending** the sequential-kernel lemma's message alphabet to (field, hash) pairs, not applying it as reviewed (privacy-case item 17's carve-out ii) |
| **O-E** | §5.2 condition 8, §6 item 7 | **D21's capture rule** recorded as a hypothesis of the sentence, because the sentence's view is exactly what a capture contains |
| **O-F** | §3.3 hop G_1 → G_2, §5.1, §9 table | the **non-adaptivity** of the generator's query points (`key ‖ le64(counter)`, `rng.rs:53-57`) stated where both §5.1 and Route A's reordering need it |
| **O-G** | §2.5 and its closing note, §9 premise 3 | the three conditions that are true today and cheap to pin (C-H1, C-H4, C-H8) recorded as such, with **C-H6 already pinned** by the compile-fail doctest at `private_block.rs:360-366` |
| **L-1** | see B-2 | the hop is explicit, D9 enters once per proof, the refills are non-adaptive, and the hop list is the check's hybrid with a named justification per hop |
| **L-2** | §0, §3.4, §5.1 (restructured), §5.2 residual table, §8 row 35, §9 table and premise 4, §10 Q1 | **the standard assumption is primary**: the generator's whole output stream indistinguishable from uniform (ruling C-3, `zkp-core/src/rng.rs`). The in-model derivation is a clearly separated **ALTERNATIVE labelled ASSUMED**, with the check's reason (indifferentiability, not consistency as an extendable output) and with the term completed to `6q·2^-256` |
| **L-3** | §1.4, §2.5 (table replaced by the check's), §5.2 condition 5, §9 premise 3 | the draft's list of unasserted conditions replaced by the check's table — each condition, whether it is true today, the line, and how it could be pinned — with C-H1, C-H4, C-H8 and C-H4′ routed to the 125M lane as byte-free assertions or tests, C-H6 recorded as already pinned, and C-H2 recorded as false crate-wide and irrelevant to the block |
| **L-4** | see B-4 | the refusal rate is counted, with its provenance, as a **liveness** figure and not a distance |
| **L-5** | see B-1 | provenance brought up to date, and the three travelling conditions cited with the theorem wherever it is cited |
| **L-6** | §4 refusal-string bullet, §5.2 condition 6, §8 row 33 | the strings recorded as **data-dependent for inputs the statement does not admit** (`witness.rs:80`, `:271`, `:287`), **not** a blocker for the statement as quantified, with the service rule: **a refusal reason is never returned to anyone not entitled to the input** |
| **L-7** | §1.5, §2.2, §2.3 step 2(d), §2.4, §5.2 condition 10, §6 item 6 | node inputs and salted-leaf inputs recorded as both 64 untagged bytes: for **hiding**, the missing bad event at ≈2^-484.8; for **BINDING**, declared outside this memo (soundness), believed to need a preimage under fixed-depth, position-checked paths, and **checked by nobody** — **FLAGGED AND NOT CHASED** |
| Label table and tally (brief item 5) | §8 | the check's 41-row table and tally adopted whole — **11 PROVED HERE, 9 MIXED, 5 RELIES ON, 7 VERIFIED IN THE CODE, 2 COMPUTED, 1 ASSUMED, 1 CONDITION, 5 GAP** — with its nine demotions (rows 4, 5, 13, 16, 21, 23, 30, 31, 35) and its finding that **four** rows are unconditional (7, 8, 20, 26), not six. Nothing strengthened |
| Status line (brief item 6) | header | replaced with the text the security owner's disposition requires; the header table's "what it is not" row and a review-and-ruling row updated with it |
| Open questions (brief item 1) | §10 | the section retitled and the check's answers recorded, in place for questions 1, 5, 9 and 10 (which repeated corrected claims) and in a one-line table for all ten |
| Evidence | new §7.2 | the check's own recount (`results/zk60_hash_layer_fs_lift_check/recount.py`) recorded beside this page's script, with what it reproduced and what it corrected |

**Items that needed no change: none of the adjudicated items was left
unapplied.** Remarks of the check that are not in its errata tables were not
acted on — in particular its observation that one policy admits at most one
proof, and its suggested sharpenings of the leaf-collision count — because
they add claims rather than correct them. No number in this page was
recomputed for this revision: every figure is either the draft's, confirmed
by the check, or the check's own.

---

**(revision complete)**
