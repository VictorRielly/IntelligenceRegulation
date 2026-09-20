# The hash layer (H6) as a random-oracle lemma, and the Fiat–Shamir lift of the fixed-challenge theorem

**DRAFT argument for the security owner's review — NOT ACCEPTED, NOT a
privacy acceptance. Delegated Opus draft, 2026-09-20. Every step is labelled
proved here, relies on, or gap. The random-oracle model it works in is a
PROPOSED ruling (D19), not an accepted one.**

| | |
|---|---|
| Author | delegated Opus cryptographic drafter, working for the security owner |
| Baseline | working tree at `perf/zk-batch-optimizations`, `d4f34f8`, 2026-09-20 03:23 |
| Scope | the custom (hashline) line, toy profile `hashline-zk-mr1/private-block-t32-poc/1` only |
| Occasion | the last named GAP of `ZK60_JOINT_LAW_COMPOSITION.md` (its §5.2 and §6.1) and of `ZK60_PRIVACY_CASE_FIRST_MVP.md` (its items 14–17 and 28): **(H6) written as one random-oracle lemma with its query budget, and the sequential lift composed with it into a single argument** (condition O-4) |
| What it is | one argument in two halves — Lemma H (the hash layer) and the lift (Fiat–Shamir) — with every step labelled **PROVED HERE**, **RELIES ON** (a named, cited fact) or **GAP** |
| What it is not | an acceptance of anything. It does not establish a privacy property, it does not close D8 or D11, and it is written inside a model the project owner has not yet ruled on |
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
(D19, not yet ruled), the two halves compose: the whole view of one toy-block
proof — roots, salts, paths, field values and challenges — has a law that does
not depend on the hidden input, **up to a list of residuals whose sum is
dominated by something that has nothing to do with hashing**: the sampler bias
the project owner already accepted in D9, at about 2^-77.7 for one toy proof.
Every hash-layer term this page derives sums to below 2^-114 even against an
adversary allowed 2^128 oracle queries. That is the useful headline: *the hash
layer is not where the privacy budget goes.*

**What this page does not do, said before anyone quotes it.** It establishes
no privacy property. It works inside a model the project owner has not
accepted. It is about one shape (the toy block) and one configuration (the
prover seals, ruling D18); the 125M profile and the development rung owe all
of it again, and **D8 and D11 — a root fixed in advance by somebody else —
are untouched and are not closed by anything here**. Two of its inputs are
themselves not finished: the sequential-kernel lemma it leans on lives only
on branch `zk60-mvp-fable`, and the accepted fixed-challenge theorem carries
one step that a check supplied and nobody has reviewed. Both are named where
they are used.

**One thing this page found that was not in the earlier documents.** The
prover's random-number generator is *also* plain BLAKE3: `ZkRng::refill`
hashes `key ‖ counter`, 40 untagged bytes, through the same unkeyed function
that hashes the tree (`zkp-core/src/rng.rs:53-61`). That is a fourth
length class nobody had tabulated, it collides with nothing on this path —
and it has a consequence that goes the project's way: **inside the
random-oracle model the separate "PRG assumption" (M-3) is not needed as an
extra assumption**, because the generator's output is an oracle image on an
input containing a 256-bit secret key. It is replaced by a term of the same
shape as the salt term, `3q·2^-256`. §5.1 states that carefully, with the two
modelling conventions it costs.

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

### 1.4 Every oracle-query length class in the system, in one table

The system has **no domain tags at all** on its BLAKE3 calls except the ones
that happen to be inside the hashed data (`Transcript::absorb`'s `label`,
`Transcript::new`'s `"hashline-v1/"`, the digest helpers' literal prefixes).
Two calls are in *keyed* BLAKE3 mode; every other call is plain unkeyed
BLAKE3 over one concatenation. So "which queries can coincide" has to be
settled by **input length**, and this is that table. It extends the one in
`ZK60_JOINT_LAW_COMPOSITION_CHECK.md` §A6.2 with the two randomness classes
and the public-statement digests, which no document had tabulated.

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

**What the table settles. PROVED HERE (arithmetic on the lengths above).**

* **47 is occupied by nothing else.** Q2 is at least 60 on this path (the
  shortest absorb is `absorb_u64(b"rows", ·)` at `48+4+8`), Q3 and Q4 are 64,
  Q6 is 40, Q8 is 51, and no `8·rows` equals 47 because 47 is not a multiple
  of 8. **So no challenge-producing query can ever coincide with a node, a
  leaf, a column hash, a refill or an absorb.** This is the check's own
  argument (`ZK60_JOINT_LAW_COMPOSITION_CHECK.md` §A6.2), reproduced because
  §3.2 needs it as a bad event that cannot happen rather than one that is
  merely unlikely.
* **40 is occupied by nothing else either** — and it is one row away from
  being occupied: `8·rows = 40` is exactly a **5-row** commitment's column
  hash. No commitment in this proof has 5 rows (455, 384, 50, 7, 7), and
  `SeamSpec::new` forces `data_rows ∈ {1,2,4,8,16}` hence
  `commitment_rows ∈ {6,7,9,13,21}` (`private_seam.rs:66-72`, `:106-111`), so
  an endpoint can never have 5. `A`, `H` and `M` are protected by **nothing**
  — the same observation `ZK60_D8_D11_RESTATEMENT.md` §3.4 and privacy-case
  item 16 make about the 8-row case, now with a second forbidden value.
  ***Condition (new, and cheap): assert `rows ∉ {5, 8}` for every commitment
  in an accepted private profile.*** A 5-row commitment would put a column
  hash into the generator's own domain; an 8-row commitment would put it into
  the node/leaf domain.
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
`b"H"` 81, `b"schedule"` 88, `b"sc-round"` ≥ 88, `b"calibration"` 91,
`b"public-statement"` 96, `b"parameters"` ≥ 158, `b"expected-IO"` 171,
`b"pb-term"` 2,823, `b"pcs-vec"` 8,247, `b"pcs-prox"` 8,248, `b"mask-q"` and
`b"mask-prox"` 16,438 — **no other absorb on this path is 64 bytes.**
**PROVED HERE** (arithmetic; the enumeration is the grep of §1.4's sites).
This is the check's finding (`..._CHECK.md` §A6.2), re-derived.

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

`ZK60_JOINT_LAW_COMPOSITION.md` §5.2 and the disposition of 2026-09-20 quote
**≈ 2^-243**, which corresponds to about 8,200 objects — roughly the nodes
or the leaves of one or two trees rather than all five commitments'. I could
not reproduce 2^-243 and I do not know which subset it counts. **The larger
figure is the one to carry**; the difference moves nothing, because both sit
about 130 bits below the dominant residual. Flagged as open question **Q3** of
§10 so the checker can settle which count the earlier documents meant.

**What the overlap does not touch.** It is not a challenge: Q1 is 47 bytes and
cannot coincide with anything (§1.4). It is not a *programming* problem
either: under D18 nothing is programmed at all (privacy-case item 14). Where
the shared untagged domain still matters is the composition of **this**
argument with the **soundness** reduction over the same table — condition O-7,
untouched here and listed in §6.

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
> every use here: the idealisation (the real prover is within the D9 sampler
> term), the terminals step supplied by the independent check and reviewed by
> nobody (ruling J-2), cross-role blinding independence verified by reading
> and not machine-asserted (condition O-2), and hypotheses (H1)–(H5).

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
published digests are independent of the hidden columns" has to be read
here — independent *given what the receipt already reveals*, because the
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
> column — are the leaf digests of the unopened columns. Conditioned on
> `(V, ρ, NR)` and on the published salts, the family `(u_{r,k})` is
> **i.i.d. uniform on `{0,1}^256` and independent of `w` and of the unopened
> columns**, except on a bad event `B_H`. Consequently, for any distinguisher
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
>             +  ε_gen(q)
> ```
>
> with `N_leaf = 12,288` encoded columns in one toy-block proof,
> `N_overlap = 24,571` (§1.5) and `ε_gen(q)` the generator's term (§5.1).
> Numerically: `q·2^-242.42 + 2^-229.83 + 2^-241.42 + ε_gen(q)`.
>
> **PROVED HERE, inside the model** — the derivation is §2.3 and is
> elementary. **The model itself is ASSUMED** (D19, proposed), and the
> published salts' uniformity is the generator step, which is where `ε_gen`
> enters. Nothing here is a standard-model statement: in the standard model
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
uniform and independent of every other answer. Three things can spoil that,
and they are the three terms of `Pr[B_H]`:

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

A fourth conceivable event — the distinguisher querying an **internal node**
above an unopened subtree — needs it to produce both 32-byte children, i.e.
to guess two uniform unknown digests: `2^-512` per query per node, dominated
by everything above and not carried separately.

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
`(V, salts, ρ, NR)` is `T^O` applied to arguments whose conditional law is the
same for every `w`: the opened columns and salts are fixed by the
conditioning, and the unopened leaves are i.i.d. uniform. Both worlds use the
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
| generator key guessing (§5.1) | `3q·2^-256` | `q·2^-254.42` | 2^-204.4 | 2^-174.4 | 2^-126.4 |
| node-input guessing | `q·(#nodes)·2^-512` | < 2^-480 | — | — | — |
| **`Pr[B_H]`, total** | | | **2^-192.4** | **2^-162.4** | **2^-114.4** |

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

### 2.5 What would break the lemma

Stated as conditions, because an acceptance would have to carry them and
because each is one edit away in a new profile.

| # | what breaks it | status today | where it is enforced, or not |
|---|---|---|---|
| C-H1 | **publishing the salt of a column that is not opened** | safe: `open_zk` emits `cmz.salts[j]` only for sampled `j` (`pcs.rs:930-941`), `mask_open` likewise (`zk.rs:544-548`) | by the code's shape; **no assertion** says it must stay so |
| C-H2 | **deriving a salt from the witness, from the statement, or from a public counter** | safe: salts are `ZkRng::bytes32()` off an OS-seeded stream (`pcs.rs:674`, `zk.rs:462`) | the block path calls `from_os` only (`protocol.rs:275`, `private_seam.rs:196`); the legacy line's caller-chosen seed (`zk.rs:334-338`) is privacy-case blocking item B-5 and **is not fixed** |
| C-H3 | **a shorter salt** | 32 bytes | §2.4 prices 16 and 8 bytes; a D14-style byte-saving lever must not touch it without redoing §2.4 |
| C-H4 | **a commitment with 5 or 8 rows**, which would put its `hash_column` input into the refill (40 B) or node/leaf (64 B) domain | safe by arithmetic accident for `A` (455), `H` (384), `M` (50); safe **by construction** for the endpoints (`SeamSpec::new`, `private_seam.rs:66-72`, `:106-111`) | **asserted nowhere for `A`, `H`, `M`** — §1.4's new condition |
| C-H5 | **reusing a salt across two commitments or two proofs** | safe: each commitment draws its own `nn` salts from its own stream segment | condition O-2 of the composition check (no blinding value in two commitments) is **verified by reading, not machine-asserted** |
| C-H6 | **a second opening of the same commitment** | prevented by the type system: `PreparedPlane` has no `Clone`, `Endpoints` is consumed (`private_seam.rs:142-147`, `private_block.rs:360-370`) | but two openings of one endpoint commitment **recover all 512 hidden words** (`zkp-core/tests/endpoint_reuse.rs`), so this is load-bearing, and it is a field-layer break that no hash-layer lemma would catch |
| C-H7 | **a root fixed in advance by a third party** | excluded for the first MVP by ruling D18 and by `check_endpoints` (`protocol.rs:243-254`) | **D8 and D11 are open and are not closed by anything here.** Under that configuration the simulator would have to *program* the oracle and Lemma H would not be the right tool at all (privacy-case item 14) |
| C-H8 | **an external (device) commit path producing different leaves** | the block profile has no device path; `commit_zk_owned_with` offers one (`pcs.rs:678-688`) and the comment says the leaves are the same | **GAP for any future device path**: if a backend salts or hashes differently, Lemma H must be re-read against it |

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
| **B3** | the distinguisher queried a challenge input **before** the prover did | possible; **harmless** (an oracle answer is uniform and independent of `w` whoever queries first), priced for completeness: it needs a 32-byte state guess | `q·4,000·2^-256 = q·2^-244.03` |
| **B4** | two distinct absorb inputs collide (the transcript's binding) | `C(4,000, 2)·2^-256` | **2^-233.07** |
| **B5** | a 64-byte absorb input coincides with a node or salted-leaf input | §1.5 | **2^-241.42** |
| **B6** | anything in `B_H` (salt guessed, two leaf inputs equal, the generator's key guessed) | §2.4 | `q·2^-242.42 + 2^-229.83 + ε_gen(q)` |
| **B7** | the distinguisher **chooses the public statement** so as to bias a challenge (grinding) | **impossible on this schedule**: no challenge is drawn before `a_root` is absorbed (`protocol.rs:320` then `:330`), and `a_root` is an oracle image on an input the distinguisher cannot compute without `B_H`. So every challenge is uniform given everything the distinguisher chose | **0**, outside `B_H` |
| **B8** | the prover's own queries colliding with the transcript's | subsumed by B2, B4, B5 | — |

```
ε_lift(q) = q·2^-244.03 + 2^-233.07 + 2^-241.42 + Pr[B_H]
          ≈ 2^-228.9   at q = 2^12,   2^-192.4 at q = 2^50,
            2^-162.4   at q = 2^80,   2^-114.4 at q = 2^128.
```

**COMPUTED** (§7.1 for the components; the sums here by hand from them). The
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

**Route A (the one this page would carry): lazy sampling.** Outside B1–B5 and
B7, each challenge input is queried for the first time by the prover at the
moment it is drawn, so its answer may be sampled lazily. Sampling all of them
in advance, uniformly and independently, and feeding them to the prover
produces **exactly** the real experiment's law on the whole view. That is the
fixed-challenge experiment of §2.1 with `ρ` uniform. Hence

```
law(view | w)  =  E_ρ [ law(V, H | ρ, w) ]
               =  E_ρ [ law(V | ρ, w) · law(H | V, ρ, w) ]
```

and by Theorem 3.3 the first factor is witness-free for every non-refused
`ρ`, by Lemma H the second is, and the distribution of `ρ` is uniform in both
worlds. Integrating gives a witness-free law for the whole view, up to
`ε_lift(q)` and up to the refusal conditioning of §4. **PROVED HERE, inside
the model, conditional on Theorem 3.3 and Lemma H.**

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
(privacy-case item 17). Route A does not need it. Route B is stronger in one
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

**Why it does not fail, in one sentence, and what the sentence rests on.** In
the counterexample `H(mask)` is a *deterministic function of `mask` with no
fresh randomness*, which is what lets the pair be inverted. Here the digest of
an unopened column is `O( hash_column(col_k) ‖ salt_k )` with `salt_k` a
**fresh 256-bit value that is never published** (§1.1), so in the random-oracle
model it is **not a function of the pads at all**: it is an independent
uniform string, and the only link back to the pads is an oracle point nobody
can address without the salt. Lemma H is precisely the statement that the
conditional law of the hash view **given the field view** does not depend on
the unopened columns; the pads inside them are covered by that conditioning,
whatever they also do elsewhere.

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
no structural answer", left to assumption M-3. In the ROM it acquires one:
the stream is `O_40(key ‖ counter)`, so published output reveals nothing
about unpublished output unless the 256-bit key is queried (§5.1). That does
not make M-3 true; it makes it **unnecessary inside D19's model**, at the
price of `3q·2^-256`.

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
| shape, schedule, policy, environment | 14 of 18 | the public statement, the declared shapes, or the host (`s` and the entropy class) | **nothing**: identical functions of identical public data in both worlds. Two of them are `panic`s **argued** unreachable (`pcs.rs:886`, `:890`) — an argument by the independent check, **not a test**, and an abort is a louder operational signal than an `Err` |
| challenge-driven | `c_s = 0`; `e ∈ {0,1}`; a zero group coefficient; a dependent proximity pair; a zero batching challenge | the challenges **alone**, drawn from a *cloned* prefix so the decision never advances the live transcript (`protocol.rs:174-176`, `argument.rs:275-276`, `:347-348`, `:493-494`) | **nothing, but only because of the model.** These events *are* deterministic functions of `(w, β)` once BLAKE3 is fixed; what makes their law witness-independent is that §3.3 makes every challenge uniform. Rate **2^-62.0 per proof**, a liveness cost, equal in both worlds |
| witness-dependent | **exactly one**: a zero LogUp denominator, `inverses` → `"zero LogUp denominator; discard attempt"` (`protocol.rs:231-234`, raised at `:339`, `:349`, `:351`, `:357`) | the witness values **and** the challenges | **2^-112.0** (64,768 inverted denominators over \|Fp2\| = 2^128; **2^-117.4** counting distinct values, which a write-up should prefer). Carried as a residual |

**Discharging the conditioning. PROVED HERE (elementary), on §3.3.** Let
`P_w = Pr[the prover refuses | w]` and let `μ_w` be the law of the view
conditioned on not refusing. The distinguisher sees either `⊥` or a receipt,
so

```
d( view_w , view_0 )  ≤  |P_w − P_0|  +  d( μ_w , μ_0 ).
```

The second term is §2 and §3. For the first: the challenge-driven part of the
refusal event is the same measurable function of a uniform `ρ` in both
worlds, so it contributes zero; the only difference is the LogUp class, so
`|P_w − P_0| ≤ 2^-112.0`. **The 2^-62.0 refusal rate is therefore a
completeness (liveness) loss and not a distinguishing term** — the same
reading D9's source gives it (`ZK60_FABLE_TRANSCRIPT_REVIEW.md` §B.7) — and
it stays a completeness loss only while the rule *refuse, never resample*
holds.

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

* **the refusal string.** The witness builder names the relation that failed,
  so a caller who sees the string learns *which* relation its own input
  violated. The condition *a refusal string must not name a witness-dependent
  relation* is privacy-case item 24's and is **not satisfied today**. **GAP**,
  an engineering one.
* **timing, memory and power** — proposed ruling D20, and explicitly not
  claimed here.

## 5. The final statement, with every residual listed and sized

### 5.1 The one remark the generator needs

**The brief asks whether "the same hash function serves as the random oracle
and inside the generator" needs a remark, and forbids hiding it. It needs
one, it is given here, and it goes the project's way — at the price of two
modelling conventions and one code condition.**

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
  32-byte and its XOF form. This is sound for BLAKE3 because the 32-byte hash
  is the first 32 bytes of the XOF, so the two uses are consistent readings of
  one function. **RELIES ON** that property of BLAKE3 (its specification), not
  on anything in this repository.
* **(V-2)** Keyed BLAKE3 (used at `rng.rs:47` and nowhere else on this path)
  is modelled as a **second, independent** oracle `O_k`. BLAKE3 separates its
  modes by internal flags, so this is the standard convention; it is
  nonetheless a convention. **ASSUMED.**

**The consequence. PROVED HERE, inside (V-1), (V-2) and D19.** The key is
uniform on 256 bits (from `/dev/urandom` through `O_k`) and never leaves the
process. Every output block is `O(key ‖ counter)`, an image at an input the
adversary cannot address without the key. Therefore the whole stream — pads,
mask rows, CFS coefficients, `b`, `u` and **all 12,288 salts** — is uniform
and independent of everything in the adversary's view, except on the event
that one of its `q` queries begins with one of the three keys:

```
ε_gen(q)  ≤  3·q·2^-256  =  q·2^-254.42 .
```

**What that buys, stated carefully.** Assumption **M-3** of the privacy case
— "the generator's whole output stream is computationally indistinguishable
from uniform", in the two-sided form ruling C-3 requires because `A`'s 256
salts are published **before** `H`'s pads are drawn from the same stream
(`pcs.rs:673-674`) — **is not needed as a separate assumption inside D19's
model**; it is replaced by the term above. Three qualifications, none of them
optional:

1. **It is a model statement, not a proof about BLAKE3.** In the standard
   model M-3 stands exactly as ruling C-3 wrote it, and the privacy statement
   must be written twice — once in the ROM with `ε_gen`, once in the standard
   model with `ε_PRG`. §5.2 does that.
2. **It rests on the 40-byte length class being unused elsewhere** (§1.4).
   That holds today and is **one row count away from being false**: a 5-row
   commitment's `hash_column` input is 40 bytes. Condition C-H4.
3. **It rests on `/dev/urandom`**, an assumption about the operating system
   that no hash model covers. Name it in the statement.

**And one thing it does not buy.** The `fp()` reduction bias is untouched: a
uniform 128-bit draw reduced mod `p = 2^64 − 2^32 + 1` is still exactly
`2^-96` from uniform, 327,052 draws still give `≤ 2^-77.7` for one toy proof,
and D9 still governs it. The ROM makes the *stream* uniform; it does not make
the *reduction* unbiased.

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
> *is the sum below.*

| residual | source | size | at `q = 2^80` |
|---|---|---|---|
| `fp()` sampler bias | D9, **accepted**; 327,052 draws at exactly 2^-96 | **2^-77.7** | 2^-77.7 |
| LogUp-collision refusal | privacy-case item 19, recomputed by its check; the one witness-dependent refusal of eighteen | **2^-112.0** (2^-117.4 counting distinct) | 2^-112.0 |
| generic-rank term `Δ_gr` | `ZK60_GENERIC_RANK_LEMMA_DISPOSITION.md`: on the accepted structural route the disclosure set lies **inside** the refusal set, so conditioning on `NR(ρ)` removes it | **0** on that route; **≈ 2^-56** on the fallback if its structural step is rejected | 0 |
| salt guessing (Lemma H) | §2.4 | `q·12,288·2^-256 = q·2^-242.42` | 2^-162.4 |
| leaf-input collision (Lemma H) | §2.4 | **2^-229.83** | 2^-229.8 |
| 64-byte absorb / node-leaf overlap | §1.5 | **2^-241.42** (the documents in circulation say ≈2^-243; carry the larger) | 2^-241.4 |
| challenge pre-query (B3) | §3.2; harmless, priced anyway | `q·2^-244.03` | 2^-164.0 |
| absorb-input collision (B4) | §3.2 | **2^-233.07** | 2^-233.1 |
| generator, **in the ROM** | §5.1 | `3q·2^-256 = q·2^-254.42` | 2^-174.4 |
| generator, **in the standard model** | M-3, ruling C-3 — the alternative to the row above, not an addition | `ε_PRG` against `ZkRng`, **no bit count** | — |
| **sum, `ε(q)`** | | **2^-77.7** to four figures at every `q ≤ 2^128` | **2^-77.6999…** |

**Separately, not in the sum:** the prover **refuses** about once in `2^62.0`
proofs, a completeness loss equal in both worlds (§4), not a distinguishing
term.

**The arithmetic. COMPUTED** (§7.1): the hash-layer terms together are below
`2^-114` even at `q = 2^128`, so `ε(q)` equals the D9 sampler term to four
significant figures at any query budget. **The hash layer is not where this
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
   (absorbed into the D9 row), the terminals step supplied by the independent
   check and **reviewed by nobody** (ruling J-2), cross-role blinding
   independence verified by reading and **not machine-asserted** (condition
   O-2), and hypotheses (H1)–(H5).
3. **The lift is Route A or Route B** (§3.3). Route B leans on a lemma that
   exists only on branch `zk60-mvp-fable`.
4. **The ideal world exists**: the all-zero input proves and verifies
   (measured 2026-09-20 00:36), and the two constructor facts that make it so
   — `NORM_CEPS = 1` and the pinned first exponential-table entry — are
   hypotheses of the theorem, not background.
5. **The code conditions C-H1 … C-H8 of §2.5** and the new `rows ∉ {5, 8}`
   condition of §1.4, none of which is asserted in Rust today.
6. **The refusal-string condition is unmet** (§4), and D20/D21 are proposed,
   not ruled.
7. **This is one shape and one configuration.** §6.

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
            + C(k·12,288, 2)·2^-256 + 3kq·2^-256 + k·(the rest)
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
   even though §1.4 disposes of it for privacy.
7. **Weight privacy (P3), the zkVM line (D7/D3), rejected-but-emitted
   receipts and retained captures (privacy-case items 25 and 27, proposed
   D21), and the context-digest condition O-1** — none of them is in scope,
   and none is improved by anything here.
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

## 8. The label table, step by step

Three labels, as the brief requires: **PROVED HERE**, **RELIES ON** (a named,
cited fact) and **GAP**. Two more appear because this page would otherwise
launder them: **VERIFIED IN THE CODE** (a source reading at a named line — it
says what the code does, not that it suffices), **COMPUTED** (arithmetic run
in §7.1), **ASSUMED** (the model) and **CONDITION** (something an acceptance
must carry that nothing enforces today).

| # | § | step | label |
|---:|---|---|---|
| 0 | §2.2, §5.1 | the model: one long-output oracle for unkeyed BLAKE3 (V-1), an independent oracle for keyed BLAKE3 (V-2), i.e. proposed ruling **D19** | **ASSUMED** |
| 1 | 1.1 | the leaf preimage `blake3(blake3(column)‖salt)`, the 32-byte salt per **encoded** column from the proof's own OS-seeded stream, and the exhaustive list of what a receipt publishes of the tree | VERIFIED IN THE CODE |
| 2 | 1.2 | the per-tree revealed-node counts; the `A/H/In/Out` rows reproduce `ZK60_D8_D11_RESTATEMENT.md` §3.3 exactly, the `M` row is new | COMPUTED |
| 3 | 1.3 | sampling with replacement: 231–246 distinct, 1,211 distinct published salts, duplicated paths | VERIFIED IN THE CODE |
| 4 | 1.4 | the length class of every oracle query in the system | **PROVED HERE** (arithmetic over source-read lengths) |
| 5 | 1.4 | **47 and 40 are used by nothing else**, so no challenge query and no refill query can coincide with a node, leaf, column hash or absorb | **PROVED HERE** |
| 6 | 1.4 | `rows ∉ {5, 8}` for every commitment | **CONDITION** — holds today by construction for the endpoints and by accident for `A`, `H`, `M`; asserted nowhere |
| 7 | 1.5 | exactly one 64-byte absorb on this path (`absorb_u64(b"log-cols", ·)`), with a fixed 32-byte suffix | **PROVED HERE** |
| 8 | 1.5 | the overlap term `24,571·2^-256 = 2^-241.42` | **PROVED HERE** (and it differs from the 2^-243 in circulation: open question 5) |
| 9 | 2.1 | what the composition needs is the **conditional** law `law(H \| V)`, not a second marginal | **PROVED HERE** (elementary, and it is the step the counterexample makes necessary) |
| 10 | 2.1 | Theorem 3.3: the field view's law at fixed non-refused challenges is witness-free | **RELIES ON** (`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, core accepted; its conditions travel) |
| 11 | 2.2 | **Lemma H** | **PROVED HERE**, inside row 0 |
| 12 | 2.3 §1 | opened leaves are a public function of `V` and the published salts — the verifier recomputes them | VERIFIED IN THE CODE |
| 13 | 2.3 §2 | unopened leaves are fresh uniform oracle images; the three ways that fails, each bounded | **PROVED HERE**, inside row 0 |
| 14 | 2.3 §3 | the induction up the tree: a node input carries no secret beyond its children, so `T^O` is public and witness-free | **PROVED HERE** |
| 15 | 2.3 §4 | the root is one such node; the top pair is revealed with probability `1 − 2^-255` and nothing leans on it being hidden | **PROVED HERE** / RELIES ON the count |
| 16 | 2.4 | `Pr[B_H] ≤ q·2^-242.42 + 2^-229.83 + 2^-241.42 + ε_gen(q)` | COMPUTED |
| 17 | 2.5 | conditions C-H1 … C-H7, each with its status in today's code | VERIFIED IN THE CODE |
| 18 | 2.5 | C-H8: a future external/device commit path | **GAP** |
| 19 | 3.1 | the transcript order, and that **only the five roots of the hash view are absorbed** — salts and paths influence nothing | VERIFIED IN THE CODE |
| 20 | 3.1 | every challenge input in one proof is distinct, because the squeeze counter increments | **PROVED HERE** |
| 21 | 3.2 | bad events B1, B2, B7 are **impossible**; B3, B4, B5, B6 are sized | **PROVED HERE** / COMPUTED |
| 22 | 3.3 | the oracle splits by input length into independent restrictions, so the challenge function is independent of the prover's randomness | **PROVED HERE** |
| 23 | 3.3 | **Route A**: lazy sampling — the real experiment has the same law as the fixed-challenge experiment with uniform `ρ` | **PROVED HERE**, inside row 0 |
| 24 | 3.3 | **Route B**: the sequential-kernel lemma over paired (field, hash) messages, which is what condition O-4 asked for | **RELIES ON** — the lemma's proof and tests are **only on branch `zk60-mvp-fable`** |
| 25 | 3.3 | Route B's causality hypothesis against the code | VERIFIED IN THE CODE |
| 26 | 3.4 | every pad symbol enters **every** encoded column, opened or not, and the pad halves of the group and proximity vectors are published in full | **PROVED HERE** (from `encode_row_zk`) |
| 27 | 3.4 | why `(H(mask), mask ⊕ w)` does not apply: the unopened leaf's digest is not a function of the pads but a fresh image at a point addressed by an unpublished 256-bit salt | **PROVED HERE**, inside row 0 |
| 28 | 3.4 | the pad halves are determined by the opened columns (up to the `10…25` pad-only coordinates) | **RELIES ON** (`ZK60_GENERIC_RANK_LEMMA*`, `..._COMPOSITION.md` §4.2) |
| 29 | 4 | a refusal is terminal; there is no restart; "opened twice" is prevented by the types | **RELIES ON** (ruling J-4) |
| 30 | 4 | the 18-class inventory; one witness-dependent class at 2^-112.0; the challenge-driven rate 2^-62.0 | **RELIES ON** (privacy-case items 19 and 24 and their check) |
| 31 | 4 | discharging the conditioning: `d(view_w, view_0) ≤ \|P_w − P_0\| + d(μ_w, μ_0)` with `\|P_w − P_0\| ≤ 2^-112.0` | **PROVED HERE** |
| 32 | 4 | the ideal world exists: the all-zero input proves and verifies, with the two boundaries pinned | **RELIES ON** (measured, `zero_witness_tests.rs`, `ec84dac`) |
| 33 | 4 | the refusal string names the failing relation | **GAP** (engineering; unmet today) |
| 34 | 5.1 | the generator read exactly: keyed derivation, **unkeyed 40-byte XOF stream** | VERIFIED IN THE CODE |
| 35 | 5.1 | in the ROM, `ε_gen(q) ≤ 3q·2^-256` replaces assumption M-3 | **PROVED HERE**, inside row 0 and conventions V-1/V-2 |
| 36 | 5.2 | the summed statement and its residual table | COMPUTED, and conditional on rows 0, 10, 11, 23/24 |
| 37 | 6.4 | `k` proofs compose by a union bound; the hash-layer half | **PROVED HERE**; the field-layer half **RELIES ON** the composition memo §6.3 |
| 38 | 6.5 | the hash layer in the **standard** model | **GAP** (assumption M-2, not implied by collision resistance) |
| 39 | 6.6 | composition with the soundness reduction over the same untagged table (O-7) | **GAP** |
| 40 | 6.1 | every other shape — the development rung and the 125M profile | **GAP** |

**Tally over the 41 rows: 18 PROVED HERE, 6 RELIES ON, 7 VERIFIED IN THE
CODE, 3 COMPUTED, 1 ASSUMED, 1 CONDITION, 5 GAP** (the gaps are rows 18, 33,
38, 39, 40: a future device commit path, the refusal string, the standard
model, the composition with soundness, and every other shape).

**And the honest reading of the 18, in the discipline the privacy case set.**
**None of them is unconditional.** Twelve are elementary derivations *inside
the assumed model* (rows 11, 13, 14, 15, 23, 27, 35 and the parts of 21, 31,
37 that depend on them) or downstream of Theorem 3.3, which is itself
accepted-with-conditions. The rows that are unconditional are the arithmetic
and source-reading ones — **4, 5, 7, 8, 20, 26** — six statements about byte
lengths, a counter, and what `encode_row_zk` computes. That is what this page
adds that nobody can take away; everything else is conditional on a model the
project owner has not yet ruled on and on a theorem accepted last night.

## 9. The circularity check: what each step assumes that a later step concludes

**Why this section is here.** A delegated argument in this repository was
refused two days ago for a hypothesis that restated its conclusion, and the
project's discipline since then is to answer, for every step, *what does this
step assume that a later step concludes?* An entry in the last column is a red
flag. There is none; there are three **dangling premises**, which are a
different and declared defect.

| step | assumes | which step concludes it | circular? |
|---|---|---|---|
| §1.1–1.5 the code facts and the length table | nothing but the source | — | no |
| §2.1 the factorisation `law(V,H) = law(V)·law(H\|V)` | nothing; it is the definition of conditional probability | — | no |
| §2.1 Theorem 3.3 | the composition memo's accepted core | concluded **earlier and elsewhere**, not here | no |
| §2.2–2.3 **Lemma H**, at a fixed `ρ` | that `ρ` is **exogenous** — the interactive experiment | §3.3 concludes that the real protocol's `ρ` behaves like a uniform exogenous one. **This is the row to look at twice.** It is not circular: Lemma H is proved *for every* fixed `ρ`, with no assumption about how `ρ` arose, so §3.3 may use it at each `ρ` without §3.3 being used inside it | **no** — and the check should confirm the quantifier order: "for all `ρ`, the law is witness-free", never "the law is witness-free for the `ρ` that occurs" |
| §2.3 Step 2, the unopened leaves | that the **salts are uniform and secret** | §5.1 concludes it (in the ROM) or M-3 assumes it. §5.1's argument uses the oracle only at **40-byte** inputs and the key's secrecy; it does not use Lemma H | no |
| §2.3 Step 3, the node induction | that node inputs are distinct and carry no salted data | its own bound (B6) and `merkle.rs:14-19` | no |
| §3.2 **B7** (no grinding) | that `a_root` is unpredictable to the distinguisher | §2.3 Step 2 — the leaves are fresh images. Step 2 does not use B7 | no |
| §3.3 Route A | that every challenge input is fresh (B1), and the length split (§1.4) | both are proved earlier and independently | no |
| §3.3 Route A's **conclusion** | it is stated "up to the refusal conditioning of §4" | §4 closes it, and §4 uses Route A's uniformity. **Not mutually dependent**: Route A's equivalence of experiments is unconditional — it is a statement about the whole run, refusal or not — and §4 then splits on an event | no |
| §3.3 Route B | the sequential-kernel lemma and the per-`ρ` joint hypothesis | the hypothesis is Theorem 3.3 × Lemma H, both concluded before | no |
| §3.4 the counterexample disposal | Lemma H's conditioning | concluded in §2 | no |
| §4 the refusal law | uniform challenges (§3.3) and the inventory | concluded before | no |
| §5.1 `ε_gen` | conventions V-1, V-2, the secret OS key, and that **40 bytes** is an unused class | §1.4 concludes the last; the others are assumptions declared at row 0 | no |
| §5.2 the sum | every row above | — | no; it is correctly last |

**The three dangling premises — unenforced or unreviewed, not circular, and
they must be written as such wherever this page is quoted.**

1. **Theorem 3.3 carries a step supplied by the independent check and
   reviewed by nobody** (ruling J-2, the 173 individual terminals). Every
   conclusion of this page inherits it.
2. **Route B's sequential-kernel lemma exists only on branch
   `zk60-mvp-fable`.** Route A is offered precisely so that an acceptance
   need not rest on it.
3. **Conditions C-H1 … C-H8 and `rows ∉ {5, 8}` are enforced by nothing.**
   They are properties of today's call sites and row counts, not invariants
   of the crate.

**One shape of over-claim this page must not be read into.** The privacy
case's rule — *no sentence may use a COMPUTED ON CAPTURES result as the
premise of a universally quantified claim* — has an analogue here: **no
sentence may use a ROM derivation as a statement about BLAKE3.** Rows 11, 13,
23, 27 and 35 are statements *inside* a model that is a proposed ruling.

## 10. Open questions for the checker, the most doubtful first

**1 — the generator and the oracle are the same function, and §5.1 turns that
into a saving. Is that legitimate?** `ZkRng::refill` is plain unkeyed BLAKE3
over `key ‖ counter` (`rng.rs:53-61`), the same function that hashes the
tree. §5.1 concludes that inside D19 the PRG assumption M-3 is **not needed**
and is replaced by `3q·2^-256`. That is the most load-bearing new claim on
this page and the one an auditor is likeliest to challenge. Three specific
things to attack: (i) convention **V-1**, that one long-output oracle models
both the 32-byte hash and the XOF — is the "first 32 bytes of the XOF equal
the hash" property of BLAKE3 enough, or does an indifferentiability argument
have to be cited? (ii) convention **V-2**, keyed BLAKE3 as an independent
oracle — is the flag separation sufficient in a model where the adversary
picks inputs? (iii) whether an argument that uses one primitive as both the
FS oracle and the PRG core is acceptable practice at all, or whether the
project should simply keep M-3 and lose nothing. *If the checker rejects
§5.1, nothing else on this page breaks: M-3 comes back exactly as ruling C-3
states it, and the residual table's generator row changes from `q·2^-254.42`
to `ε_PRG`.*

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

**5 — the 2^-243 that is in circulation versus the 2^-241.42 recounted
here.** `ZK60_JOINT_LAW_COMPOSITION.md` §5.2, its check's §A6.2, the
disposition of 2026-09-20 and the D19 one-pager all say ≈2^-243. My count of
the candidate objects is 12,283 node inputs plus 12,288 salted-leaf inputs =
24,571, giving 2^-241.42. Which objects does 2^-243 count? Whichever is
right, the same number should appear in all five documents.

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

**9 — the two code conditions this page adds.** `rows ∉ {5, 8}` for every
commitment (§1.4) and "a salt is published if and only if its column is"
(C-H1). Both hold today; neither is asserted. Are they worth a Rust test now,
or at the 125M shape, where the row counts change anyway?

**10 — what the hash layer inherits from Theorem 3.3's unreviewed step.**
Every conclusion here multiplies a hash-layer kernel by the field-layer law.
If the terminals step (ruling J-2) is wrong, the product is wrong. Is there
any part of §2 or §3 that would survive a failure of Theorem 3.3 — i.e. is
there a statement about the hash layer alone worth keeping if the field layer
moves?

---

**(draft complete)**
