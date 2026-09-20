# The sealed handle: scoping a hashing gadget for the fast native line

**DRAFT scoping memo for the security owner's review — NOT ACCEPTED.
Delegated Opus draft, 2026-09-19. Paper only; every cost is counted or
modelled, none measured.**

---

## 0. For the project owner: what this is about, in plain words

**The product question that was decided in D18, and the half that was
deferred.** A private proof talks about a hidden input without showing it. It
does that by referring to a **sealed envelope** — a short public string that
stands for the hidden value. D18 ruled that for the first MVP **the prover
seals**: the envelope appears for the first time inside the receipt
(`ZK60_DECISIONS.md:582-617`). The other case — a regulator seals an input
today and asks for a proof about it tomorrow — is a recorded todo and, in your
words, the approach the product will probably end up using. This memo scopes
that second case.

**Why it is not just "use the same envelope earlier".** Today's envelope is a
**polynomial-commitment root**: a hash tree over the hidden plane that the
proof later opens. Opening it publishes 256 columns of that tree, and the
project has proved that **two** openings of one endpoint commitment recover
every hidden word (D11, `ZK60_DECISIONS.md:284-306`). Worse, for the privacy
argument the project would have to write, whoever built the tree holds its
randomness and can always tell the real proof from a simulated one — so the
argument excludes exactly the party a regulator would be
(`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:24-32`). That is why the attempt to
argue the obligation away was refused and why **D8 and D11 stand**.

**The known way out, in one sentence.** The regulator publishes a **salted
hash** of the hidden plane — a 32-byte fingerprint, mixed with a secret random
salt, computed with ordinary software and never opened by anything — and the
proof shows, *inside itself*, that the plane in its own freshly built
commitment hashes to that fingerprint. The slow zkVM line already works this
way: D7's endpoints are salted SHA-256 values in a fixed public journal
(`ZK60_DECISIONS.md:223-234`; the code is
`zkvm-block/statement/src/lib.rs:65-78`). The fast native line has **no
hashing machinery of any kind**, and building one is what this memo prices.

**The three things worth taking away.**

1. **The cost is much smaller than the record currently says, because the
   record costed the wrong hash.** The only figure on the books — about +5.5%
   of a public 8B pass, +12.6% of a private one
   (`ZK60_DECISIONS.md:577-578` and `:614`, from
   `ZK60_D8_D11_RESTATEMENT_CHECK.md:827`) — is for SHA-256 taken apart into
   bytes, and it is itself about **2× low** for a reason §2.7 explains. A hash
   designed for this kind of proof, working in the prover's own 64-bit
   arithmetic, counts at roughly **+0.6% to +1.3% of the 8B pass for both
   endpoints** and **adds no table lookups at all** (§3.4). It is not free, and
   at the tiny experimental shape it is proportionally much worse (+11% to
   +23% of that receipt's bytes), but it is not the "last of the 5-second
   budget" the earlier record implied.
2. **It buys something the project cannot otherwise have: chaining.** Two
   separately finished private proofs cannot be joined through a commitment
   root — the first one has already opened it
   (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:72-80`). A handle can be published
   by one proof and consumed by the next, with nothing opened twice (§5). On a
   consumer card that matters: the 32-layer private 8B pass does not fit one
   process today.
3. **It swaps one unsolved problem for one ordinary assumption, and one new
   operational duty.** The unsolved problem (D8/D11) disappears because no
   commitment the proof opens was made by anybody but the prover. The
   assumption that takes its place is that a salted hash hides a plane that may
   have **very little entropy** — D7's own first qualifier warns that in the
   toy token model the hidden answer is one of only 32 values, so anyone who
   learns the salt learns the answer (`ZK60_DECISIONS.md:242-247`). The new
   duty: the salt must travel from the sealer to the prover and stay secret in
   two places instead of one. **This does not close D8 or D11.** It builds a
   configuration they do not bind.

Everything below is paper. Nothing was built, run or measured for it.

## 1. The statement

Terms used below, each on first use. A **plane** is one hidden rectangle of
numbers — an activation tensor, e.g. 512 tokens × 4096 channels. A
**commitment** is a short public string that fixes a plane without revealing
it; this prover's kind (a Ligero/Brakedown-class *polynomial* commitment) is a
hash tree that the proof later **opens** at 256 randomly chosen columns
(`zkp-core/src/pcs.rs:1-20`). A **handle** is the new object this memo is
about: also a short public string fixing a plane, but a plain salted hash that
is **never opened by anything**. A **salt** is secret random padding mixed into
a hash so that the same plane does not always produce the same fingerprint.

### 1.1 What is published, by whom, and when

**The handle.**

> `h = Hash( domain_tag ‖ context ‖ role ‖ salt ‖ pack(plane) )`

with the five parts fixed as follows. This is the shape D7 already uses on the
zkVM line, transposed to the native field — the zkVM version is
`endpoint(role, context, model, salt, values)` at
`zkvm-block/statement/src/lib.rs:65-78`, which absorbs, in order, a
NUL-terminated ASCII domain string, the profile string, a one-byte role, a
32-byte context, a 32-byte model digest, a 32-byte salt, the element count and
then every value as little-endian bytes.

| part | what it is | who fixes it | when |
|---|---|---|---|
| `domain_tag` | a fixed ASCII string naming this construction and its version, e.g. `zk60-native-handle-v1\0`, plus the profile string the transcript already absorbs (`hashline/src/private_block/protocol.rs:33`) | the statement version | at freeze time |
| `context` | 32 bytes authenticating the model, the calibration and the request; the field already exists, as `SeamSpec::context` (`hashline/src/private_seam.rs:44-45`, and `IoSpec::new` at `hashline/src/zk_ffn_fresh_io.rs:29`), and is required non-zero | the sealer and the verifier, agreed in advance | before sealing |
| `role` | one byte distinguishing *input* from *output* (and, for chaining, *seam k*); the endpoint slots `1,2,3,4` of `IoSpec::seams` (`zk_ffn_fresh_io.rs:40-41`) are today's equivalent | the statement version | at freeze time |
| `salt` | 256 fresh random bits — 4 Goldilocks field elements, matching D7's 32 bytes | **the sealer**, from OS randomness | at sealing time |
| `pack(plane)` | the plane's words packed into field elements, injectively, in a fixed order (§3.1) | determined by the plane | — |

**Who knows what.** The sealer knows the plane and the salt. The prover must
be given **both**: it cannot produce the proof from the plane alone, because
the relation it proves mentions the salt. The verifier knows only `h`, the
`domain_tag`, the `context` and the `role`. Nobody else learns anything from
the published bytes beyond `h`.

**When.** `h` is published whenever the sealer chooses — days before any proof
exists. Nothing about the prover, the proving key, the commitment randomness
or the transcript is needed to compute it. That is the whole point: the
regulator can seal today and ask for a proof tomorrow.

### 1.2 What the proof proves, and what each party checks

**The prover's claim, in one sentence:** *the plane inside my freshly
generated polynomial commitment, together with a salt I hold, hashes under the
fixed tag, context and role to the published `h`.*

The proof additionally proves everything it proves today — that the approved
model's arithmetic was carried out on that plane — and the two claims are
joined **inside one transcript**, so no separately finished sub-proof has to
be glued to another.

| party | what it checks | what it needs |
|---|---|---|
| the **verifier** of the receipt | the ordinary verification, plus the gadget's zero-check slot like any other slot. It never evaluates the hash itself; `h` enters as 32 public bytes absorbed into the transcript | the receipt, the public statement (which contains `h`) |
| the **sealer**, later | that the `h` in the receipt is byte-for-byte the `h` it published | its own record |
| **anyone given the plane and the salt** | recompute `h` in three lines of ordinary code and compare | plane + salt |
| the **verifier of a chain** (§5) | that the upstream receipt's output handle equals the downstream receipt's input handle | two receipts |

Note what is *not* on that list: at no point does anybody open, or need to
open, a commitment twice; and at no point does a party other than the prover
produce a polynomial commitment.

### 1.3 The privacy game this gives, and the assumption that replaces the open obligation

**The game.** Because every polynomial commitment in the receipt is produced
by the prover, from fresh OS randomness that never leaves the process, the
privacy experiment is the **standard commit-and-prove one** in which the
simulator issues its own roots and programs no oracle point — what the
project's documents call Game J. The disposition records exactly this for
today's artifacts: *"In today's code the committer is the prover … so for every
artifact that exists today the caller-fixed-root scenario does not physically
arise: the right game for them is the standard one in which the simulator
produces the commitments"* (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:53-60`).
The construction's contribution is that this stays true **even when a third
party sealed the input in advance**, because what that party fixed is not a
commitment the proof opens.

**Three cautions, so this is not over-read.**

1. Game J's simulator is **not built**. The project's own model document says
   of `SimProve`, *"This algorithm is not yet complete"*
   (`ZK60_ENDPOINT_SIMULATION_MODEL.md:76`, quoted at
   `ZK60_D8_D11_RESTATEMENT_CHECK.md:605-607`). The handle removes one class of
   obstruction; it does not supply the simulator.
2. Every field-layer obligation is unchanged: the joint conditional sampler
   (O1), the joint hypothesis / U-3 (O2), the `ZkRng` PRG assumption, salted-leaf
   hiding of unopened columns, and the untagged 64-byte BLAKE3 domain shared by
   the transcript and the Merkle layer
   (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:90-98`).
3. **This does not close D8 or D11.** Those obligations bind the configuration
   in which a caller fixes a *polynomial-commitment root*. The handle replaces
   that configuration with a different one carrying a different assumption,
   stated next. If the project ever again lets a caller fix a PCS root, D8 and
   D11 apply to it in full.

**The assumption that takes the obligation's place.**

> **(H-hide)** For the chosen hash `H`, and for a salt drawn uniformly from
> 256 bits, the value `h = H(tag ‖ ctx ‖ role ‖ salt ‖ pack(P))` is
> computationally independent of the plane `P`, **even when `P` ranges over a
> small set**.

In the random-oracle model this is immediate and quantitative: an adversary
that makes `q` oracle queries distinguishes with advantage at most
`q · 2^-256` **provided the salt stays secret**, whatever `P`'s entropy,
because every query it can afford misses the secret 256-bit block. Outside the
random-oracle model it is a keyed-hardcore / PRF-style assumption on `H` with
the salt as key, and for the algebraic candidates of §2.2 it is *not* a
property anybody has published a reduction for. **Label it as what it is: a
random-oracle assumption on a new primitive.**

The failure mode is the one D7 already carries as its first qualifier: *"the
hiding of an endpoint is the secrecy of its salt under SHA-256 — in the toy
token model the answer is one of only 32 values, so whoever learns the salt
learns the answer"* (`ZK60_DECISIONS.md:242-247`). A hidden activation plane at
Mistral width is not a 32-value object, but a *prompt* plane over a short
prompt can be: if the plausible inputs number in the millions, the salt is the
only thing standing between the handle and a dictionary attack. Two
consequences, both operational rather than cryptographic:

* **Salt length: 256 bits, not 128.** Handles will be published in bulk (64 per
  feed-forward-only pass at 32 layers, D17 rule 4). Multi-target guessing over
  `N` published handles costs `2^-128 · N` at 128 bits; at 256 bits the term
  never matters. The cost is 4 field elements — half of one permutation's
  absorption rate (§2.2), i.e. nothing.
* **The salt is now a two-party secret.** The sealer must hand it to the
  prover, over a channel the project does not currently have, and a leak of the
  salt is a leak of the plane's *distinguishability*, not of the plane itself.
  This is a new operational requirement and belongs in the ruling.

### 1.4 Binding, soundness, and how wide the hash must be over a 64-bit field

**Why collision resistance is load-bearing.** The statement is "the plane
inside my commitment hashes to `h`". If a prover can find `(P', s')` with the
same handle as the sealer's `(P, s)`, it can prove the model's arithmetic on a
plane the regulator never sealed, and the receipt still checks. So the claim
means something **only** to the extent that `H` is collision resistant against
the prover, which is the party with the most to gain and the most compute.
Second-preimage resistance is not enough: the prover chooses both the plane and
the salt.

**How wide the hash has to be.** These are the project's two relevant numbers.
Per D15 the custom line's per-opening level is about **106 bits** and the
projected whole-8B-proof level is about **94 bits**
(`ZK60_DECISIONS.md:439-467`); the stated target is 128. A sponge over
Goldilocks (`p = 2^64 − 2^32 + 1`, so each element carries just under 64 bits)
with **capacity** `c` elements has collision resistance about `c · 64 / 2` bits
under the standard flat-sponge / indifferentiability bound [RECALLED — Bertoni,
Daemen, Peeters, Van Assche; verify the exact statement before relying on it],
and the squeezed output must be at least twice the target too:

| target | capacity needed | Goldilocks elements | output needed |
|---|---|---|---|
| 128 bits | ≥ 256 bits | **4** | ≥ 256 bits = 4 elements |
| 106 bits (D15 per-opening) | ≥ 212 bits | **4** | 4 elements |
| 94 bits (D15 whole 8B proof) | ≥ 188 bits | **3** | 3 elements |

**So capacity 4 is the answer**: it is the smallest count that clears the
project's own per-opening figure *and* the 128-bit target at the same time, and
it is what every published Goldilocks parameter set uses anyway (§2.2). A
handle is then 4 field elements — 32 bytes, the same width as D7's SHA-256
handle, which keeps the wire format and the journal shapes comparable across
the two lines.

**One thing this does *not* let the project claim.** Adding a 128-bit-collision
handle does not raise the proof's soundness: the whole-proof figure stays where
D15 puts it, around 94 bits at 8B, because the handle is one more term in a
union bound dominated by the commitment and lookup terms. The handle's 128 bits
only mean the handle is not the weakest link.

## 2. Which hash, costed inside this proof system

### 2.0 What a relation costs in this prover's idiom

Everything in §2 is priced in the four currencies this prover actually pays
in. All four were read out of the source.

**(i) A committed value.** The prover's data lives in a few large commitments
(`A` the activations, `H` the lookup helpers, `W` the weights, `M` the masking
polynomials — `hashline/src/private_block/layout.rs:1-10`). Each commitment is
a matrix of **rows** of `2^log_cols` field elements; `log_cols` is 8 (256
columns) in the pinned tiny private block
(`hashline/src/private_block/protocol.rs:22`) and 14 (16,384 columns) in the
layer prover used at the 125M and Mistral shapes (`ZK60_FSP_MR1_PROGRESS.md` on
branch `fsp-mr1`: *"Rows are `a_n = 2^log_cols = 16,384` wide at both
shapes"*). Committed volume is the prover's dominant cost: of the best 8B
public pass's 58.40 s, commit W is 19.823 s, commit A 4.838 s and the PCS
openings 17.176 s (`ZK60_FIVE_SECOND_PLAN.md` §1.2), and the whole pass commits
about 9.777 × 10^9 words (`ZK60_D8_D11_RESTATEMENT_CHECK.md:550-552`).

**(ii) A committed row.** Proof bytes are almost exactly linear in rows,
because each of the `Q = 256` opened columns serves one field element per row:
**2,048 bytes of proof per committed row**. The MR1 lane's measurement
reproduces this exactly — *"256 opened columns × 66 extra rows × 8 B =
135,168 B per Mistral layer"*.

**(iii) A claim site, i.e. a mask pair.** The privacy schedule requires that
*"every claim site has its OWN reserved mask pair (two fresh rows), used by
exactly that one claim; a plane opened at k points has k pairs"*
(`layout.rs:20-23`). So **each plane opened at each point costs 2 more rows =
4,096 more proof bytes**, whatever the plane's length. That is why the gadget's
cost profile inverts between the tiny shape and model scale (§3.2). The
joint-view analysis shows this discipline is what makes the disclosed dimension
zero (hypothesis H-pair, `ZK60_NATIVE_JOINT_VIEW.md` §2.2 on branch
`zk60-native-jointview`), so it is not a knob an implementer may turn.

**(iv) A lookup.** A lookup is `value = cst + Σ coef · plane` — a **linear**
form in committed planes — checked against a public table by a LogUp identity
(`layout.rs:259-272`, `argument.rs:474-490`). Two lookups share one **helper
plane** committed in `H` (`layout.rs:278-279`, `layout.rs:371-379`), and the
helper relation `h·d₁·d₂ − (d₁ + d₂)` is degree 3, which with the slot's `eq`
factor makes a degree-4 zero-check — the code says so at `argument.rs:596-597`
and the SLOTS table lists degree 4 for every lookup-bearing slot
(`layout.rs:438-461`). The
8B pass performs about 2.296 × 10^9 lookups and spends 5.555 s on
"LogUp helpers + commit H". **Lookups are not free here**, and that single fact
decides §2.3 against the lookup-friendly hash designs.

**Two facts about tables that matter a great deal below.** First, a public
table is just a public vector handed to the sumcheck (`Tab::Pub`,
`argument.rs:70`), so a table of any size is expressible; the tiny profile
happens to use one 256-entry `U8` table and nothing else (`layout.rs:30-36`).
Second — and this is the important one — **a table may have more than one
column**. The activation table is built as `i + β·act[i] + tag`
(`argument.rs:533-535`) and the exponential table as `i + β·exp[i] + tag`
(`argument.rs:525-527`): the lookup binds the *pair* `(index, value)`, and the
code's comment says binding the pair is a soundness requirement rather than a
preference. **A multi-column lookup table is therefore already the prover's
native way to express an arbitrary small function `y = S(x)`** — which is
exactly what a lookup-based hash S-box is.

**Degree.** The sumcheck prover and the CFS mask are generic in the round
degree (`zkp-core/src/sumcheck.rs:47`, `:197`, and `masked_prove` at
`hashline/src/zk.rs:972`); no cap was found anywhere in the tree. A degree-`d`
slot sends `d + 1` values per round and its mask needs `n_vars·d + 2` field
coefficients, which live in two rows of `M` (`M_ROWS = 2·N_SLOTS + 4`,
`layout.rs:519`). At the tiny profile a mask row holds 256 elements, so a
degree-8 slot over 21 variables (`21·8 + 2 = 170`) still fits. **The prover can
express a degree-7 relation today**; nothing in the API forbids it. Whether the
GPU zero-check kernels handle degree 7 was not checked (§7.4).

### 2.1 (a) A bit-oriented standard hash (SHA-256, BLAKE3)

**What it would take.** SHA-256 and BLAKE3 are built from 32-bit additions,
XOR, AND and rotations. This prover has none of those: its arithmetisation is
integer arithmetic plus range lookups plus LogUp
(`ZK60_D8_D11_RESTATEMENT.md:940-942`). Each 32-bit word becomes four byte
limbs; XOR and AND of two bytes become one lookup each into a 65,536-row
two-input table (buildable with the `(index, value)` idiom of §2.0, extended to
`x + β·y + β²·(x⊕y) + tag` over a table enumerating all 2^16 pairs); each
rotation by a non-multiple of 8 becomes, per byte, a split into a high and a
low part with a lookup for each; each 32-bit addition becomes four byte
additions with carry bits that must be pinned boolean and four output bytes
that must be range-checked.

**My own count, and where it differs from the record.** The figure on the books
is *"≈ 4,000 lookups and ~2,500 committed words per compression"* with a
factor-2 band (`ZK60_D8_D11_RESTATEMENT.md:948-950`). Counting SHA-256 the way
above I get **more**, not less: per round, 6 rotations × 8 lookups = 48 for the
rotation splits, ~48 byte-ops for Σ₀, Σ₁, Ch and Maj, and ~42 for the seven
modular additions — about 138 lookups a round, 64 rounds, plus 48
message-schedule steps at about 82 each: **≈ 12,800 lookups per 64-byte
compression** [COUNTED from the stated decomposition; the assumptions are
mine and were not checked against an implementation]. BLAKE3 is meaningfully
cheaper because it is ARX-only and two of its four rotations (16 and 8) are
byte-aligned and therefore free in a byte-limb representation: per `G`
function, 4 additions (~24), 4 XORs (16) and 2 non-aligned rotations (16) ≈ 56
lookups, 56 `G` per compression ⇒ **≈ 3,100 lookups per compression**. So the
record's 4,000 is a fair central figure *for BLAKE3* and about 3× low for
SHA-256.

**Reproducing the record's arithmetic** at Mistral width, so the comparison in
§3 is like-for-like: 2^21 int16 words = 4,194,304 bytes = **65,536
compressions per endpoint**; at 2,500 committed words each that is 1.638 × 10^8
committed words = **1.68% of the pass's 9.777 × 10^9 per endpoint (3.35% for
two)**, and at 4,000 lookups each, 2.621 × 10^8 lookups = **11.4% of the pass's
2.296 × 10^9 per endpoint (22.8% for two)** [COUNTED; identical to the check's
`counts.out`, `ZK60_D8_D11_RESTATEMENT_CHECK.md:550-552`]. Turned into a
relative time cost that is the +5.5% public / +12.6% private now in D18.

**What recommends it.** Only one thing, but it is not nothing: the project
already depends on BLAKE3 for its transcript and Merkle trees
(`zkp-core/src/transcript.rs:44-52`), and using it for the handle too adds **no
new cryptographic assumption at all**. And if the handle used SHA-256 it would
be **bit-identical to D7's zkVM handle**, so a zkVM proof's output could be
consumed by a native proof and vice versa. That interoperability is worth
something and it is worth exactly the price above.

**Verdict.** Keep it as the conservative fallback and as the interoperability
option. It is 5× to 10× the committed volume of §2.2 and it is the only
candidate that adds hundreds of millions of lookups.

### 2.2 (b) An algebraic permutation over Goldilocks

**Why this is the natural fit.** The prover's words already *are* Goldilocks
elements. An algebraic hash's round function is a low-degree polynomial map
over the same field, so every relation it needs is a zero-check term of the
kind the prover writes all day, and **it needs no tables and no lookups at
all**.

**The S-box.** Over `p = 2^64 − 2^32 + 1`, `p − 1 = 2^32·(2^32 − 1) =
2^32 · 3 · 5 · 17 · 257 · 65537`. So `x³` and `x⁵` are **not** permutations
(3 and 5 divide `p − 1`), while 7 divides neither factor, and **`x⁷` is the
smallest permutation power** [COUNTED — the factorisation is elementary and I
verified `p − 1 = 2^32(2^32 − 1)` by exact arithmetic]. That is why every
Goldilocks design in the literature uses `x⁷`.

**The candidates, from the literature as I recall them — verify every number
before relying on it.** None of this is from this repository.

| design | authors, as I recall | Goldilocks parameters, as I recall | structure | cryptanalysis status, as I recall |
|---|---|---|---|---|
| **Poseidon** | Grassi, Khovratovich, Rechberger, Roy, Schofnegger (USENIX Sec. 2021) | width 8 and 12; **8 full + 22 partial rounds** at width 12, S-box `x⁷` (Plonky2's instance) | partial-SPN: `x⁷` on all elements in full rounds, on one element in partial rounds, MDS linear layer | the most deployed algebraic hash; extensive Gröbner-basis/CICO analysis; round counts carry a published margin |
| **Poseidon2** | Grassi, Khovratovich, Schofnegger (2023) | same widths and, I believe, the same 8 + 22 at width 12 | Poseidon with a cheaper, structured linear layer | inherits Poseidon's analysis; the linear-layer change was argued not to affect the algebraic bounds |
| **Rescue-Prime / RPO** | Aly, Ashur, Ben-Sasson, Dhooghe, Szepieniec; RPO used by Polygon Miden | width 12, capacity 4, **7 rounds**, `x⁷` and `x^{1/7}` | each round applies `x⁷` then `x^{1/7}`; the inverse direction is cheap as a *constraint* (`y⁷ = x`) | the cleanest published design rationale and round-count formula; conservative |
| **Monolith** | Grassi, Khovratovich, Roy, Rechberger, Schofnegger (2023/24) | width 8 and 12, **6 rounds** | lookup "Bars" layer on limbs + degree-2 "Bricks" + MDS "Concrete"; designed for lookup provers | newer; some third-party analysis; less settled than Poseidon |
| **Tip5 / Tip4** | Szepieniec, Lenngren and co-authors; Triton VM | width 16, **5 rounds**, rate 10 / capacity 6 | split-and-lookup S-box (256-entry table on 4 bytes of 4 elements) plus `x⁷` on the other 12 | newest of the set; least third-party analysis |
| **Reinforced Concrete** | Grassi, Khovratovich, Rechberger, Roy, Schofnegger (CCS 2022) | **not a Goldilocks design** — built for ~256-bit primes (BN254/BLS) | Bricks–Concrete–Bars with a lookup layer | the ancestor of Monolith/Tip5's lookup idea |

I am confident about the families, the S-box exponent, the sponge shapes and
the broad structures. I am **not** confident about the exact round counts, and
I would not stake a security claim on the "8 + 22" above without checking the
reference implementation.

**Cost in this prover, worked out.** Take Poseidon2 at width 12, rate 8,
capacity 4. Per permutation: `8 × 12 + 22 × 1 = ` **118 S-box applications**.
Two ways to constrain one S-box:

* **degree 7 directly**: commit only `y`, and assert `y = x⁷` where `x` is a
  *public linear form* of values already committed. One committed value per
  S-box; the slot's degree becomes 7 (8 with the `eq` factor).
* **degree ≤ 3 with an intermediate**: commit `t = x³` and `y = t²·x`. Two
  committed values per S-box; the slot stays at the degree 4 the layout
  already uses.

In this prover the first is clearly better: committed volume is the dominant
cost (§2.0(i)) while the sumchecks are a small share of the pass (matmul
sumchecks 5.533 s and zero-checks F+D 5.468 s of 58.40 s), and the sumcheck
here runs over the gadget's own small domain, not the layer's.

The linear layers and the round constants are public, so between S-boxes
nothing needs to be committed: the input of the next S-box is a public linear
combination of the initial state and of every S-box output so far. That gives
the **118 committed values per permutation** used in §3, and it has a cost of
its own — see layout A in §3.2, whose linear forms grow to ~130 terms and make
the sumcheck's own evaluation the second-largest item.

**No lookups, no tables, no new range facts.** The whole gadget contributes
zero to the `H` phase. Against §2.1's 22.8% of the pass's lookups for two
endpoints, that is the single biggest difference between the two families.

### 2.3 (c) A lookup-friendly design

Monolith and Tip5 replace part of the algebraic S-box with a small table
lookup, precisely to be cheap in provers whose lookup argument is free. This
prover's lookups are **not** free: each is a committed helper plane in `H`, the
8B pass already spends 5.555 s on helpers and commit H, and the check's
arithmetic treats added lookups as the more expensive of the two currencies.

A rough count, from the structures as I recall them. **Monolith**, width 12, 6
rounds, with a Bars layer applying a small table to 4 limbs of each of 4
elements: ≈ 16 lookups and ≈ 16 committed limb values per round, so ≈ 96
lookups and ≈ 96 + state values per permutation absorbing 8 elements — call it
**12 lookups and ~19 committed values per absorbed field element** [MODEL; the
structure is recalled, the arithmetic is mine]. **Tip5**, width 16, 5 rounds,
4 split-and-lookup elements per round: ≈ 16 lookups per round, ≈ 80 per
permutation, absorbing 10 elements — **8 lookups and ~15 committed values per
absorbed element** [MODEL].

Against Poseidon2's **0 lookups and ~14.75 committed values per absorbed
element** (§3.2 layout A), the lookup-friendly designs are no cheaper in
committed volume here and they add a lookup bill the pure-algebraic route does
not have. They also add a second table domain, its multiplicity planes, its
helper planes, and their entries in the LogUp identity — all of which are new
rows and new claim sites.

**Verdict:** a lookup-friendly hash is the right choice in an AIR with a free
lookup argument, and the wrong choice here. Keep Monolith on the list only as
the fallback if the degree-7 zero-check turns out to be much more expensive in
the GPU kernels than §2.0 assumes — which is measurement M1 of §6.

### 2.4 (d) Hashing the commitment instead of the plane — and why it cannot work

The tempting shortcut: let the handle be `h = Hash(salt ‖ the prover's fresh
PCS root)`. Then the gadget hashes 32 bytes rather than four megabytes, and
the cost collapses to nothing.

**It fails on the timing, which is the whole point of the exercise.** The
sealer must fix `h` *before any prover exists*. A PCS root is a hash tree over
the plane **interleaved with the prover's own secret pads and per-leaf salts**
(`zkp-core/src/pcs.rs:1-13`; the pads and salts are drawn fresh per commitment
inside `commit_zk_owned_with`). At sealing time those values do not exist and
cannot be predicted, so the sealer cannot compute the root.

**And the only way to fix that is the configuration we are leaving.** If the
sealer runs the commitment algorithm itself, it holds the pads and salts —
which is precisely HOLE 2 of the check: *"R1 hides the commitment's randomness
from the distinguisher. Whoever holds the salts can rebuild the tree and detect
the simulator's programmed top pair with probability 1"*
(`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:24-29`). Sealing the root is sealing a
caller-fixed PCS root with one extra hash wrapped round it, and D8/D11 apply
unchanged.

A third variant — the sealer fixes a *commitment to the plane under a
different scheme* and the proof links the two — is closure (iii) of the
restatement, and its two concrete instantiations were examined there and
rejected: a Pedersen commitment needs elliptic-curve arithmetic emulated over
Goldilocks in a verifier that does Goldilocks only (the *reason* stated in the
draft was wrong and was corrected; the *conclusion* stands —
`ZK60_D8_D11_RESTATEMENT_CHECK.md:828`), and a structured Ajtai/SIS matrix that
is succinct for this verifier has efficiently **findable** short collisions
(correction 13, `:829`; note the corrected wording — the original pigeonhole
argument proved too much and would have refuted random SIS as well). Neither
is revisited here.

**Conclusion: the handle must be a hash of the plane's own words.** That is
why there is a gadget at all.

### 2.5 (e) A tree rather than a sponge — which this prover forces

**A finding, and the most important structural point in this memo.** A sponge
hash is sequential: `state_{i+1} = perm(state_i + absorbed_i)`. In an AIR that
is a transition constraint between consecutive rows, and it is free. **This
prover is not an AIR.** It is a multilinear sumcheck prover, and its claim
points are built from fixed, flipped or challenge coordinates only —
`Coord::Rho`, `Coord::Flip`, `Coord::Fixed` (`argument.rs:48-53`). There is no
"next index" operator and no shift argument anywhere in the tree. **A linear
sponge over a long message cannot be expressed in this prover without a new
primitive.**

What *is* expressible is a split on a coordinate: a plane's values at even and
at odd positions are the plane's multilinear extension with its last variable
fixed to 0 and to 1 — exactly `Coord::Fixed`. So a **binary hash tree** fits
natively:

* **leaves**: partition the packed plane into chunks of `rate` field elements
  and hash each chunk independently — one permutation each, all parallel.
* **internal nodes**: each node absorbs its two children's digests. With a
  4-element digest and rate 8, **one 2-to-1 compression is exactly one
  permutation**, and the parent–child wiring is the even/odd split above.
* **root**: squeeze 4 elements; that is `h`.

The salt and the tag/context/role are absorbed into the leftmost leaf (or a
dedicated initial-value block), so the tree is domain-separated and
salt-dependent from the first compression.

**What the tree costs.** A complete binary tree over `L` leaves has `L − 1`
internal nodes, so **total permutations `= 2L − 1`, twice the linear sponge's
`L`.** That factor of two is the price of this prover's missing shift operator,
and it is included in every number in §3.

**The one remaining wiring question.** Levels differ in size, and a level index
is a third axis. Two ways to handle it, both affordable:

* *level-wise plane families*: one family of planes per tree level. No new
  primitive; but the number of claim sites multiplies by the depth (≈ 17 at
  Mistral width), and claim sites are 2 rows each (§2.0(iii)).
* *one family with a level axis*: the level axis has at most 18 values, so the
  level-to-level wiring is a **public 32 × 32 shift table** handed to the
  sumcheck as an ordinary `Tab::Pub` — the same shape as the prover's existing
  matmul sumchecks. This costs padding (levels are ragged) but keeps the site
  count flat.

I could not determine from the source which is cheaper in practice; it is
measurement M2 of §6. §3 prices the level-wise form, which is the pessimistic
one for sites and the exact one for volume.

**A GPU note, in the tree's favour.** Every permutation at a level is
independent, so the leaf level — half of all the work — is embarrassingly
parallel and maps onto the same kernel shape as the existing commitment work.
A linear sponge would not be.

### 2.6 A relation that is intentionally modular, beside relations about integers

The prover's existing relations are **integer identities embedded in the
field**, and the module carries a written no-wraparound premise for every one
of them: *"Every relation of `argument::define` is an identity between integers
only if no term wraps the 64-bit field"*, followed by the bound list —
`D² + a1 < 2^49`, `|2·cn·g·x| < 2^34`, `y·D·2^(tn+1) < 2^44`, and so on —
closing with *"All bounds are far below `p = 2^64 − 2^32 + 1`"*
(`layout.rs:281-309`). An algebraic hash is the opposite: it is modular **by
design** and its intermediate values are uniform over the whole field.

**They coexist, and the reason is precise.** A zero-check slot asserts a
**field** identity, `Σ mu_k · rel_k = 0`. The integer relations are field
identities that happen *also* to be integer identities because their operands
are range-pinned; the hash relations are field identities with no integer
meaning at all. The sumcheck machinery neither knows nor cares. So the two
families can sit in the same slot under different `mu` coefficients, or in
separate slots — an engineering choice, not a soundness one.

**The danger is one-directional, and the rule that removes it.** What must
never happen is a hash output flowing into an integer relation: a hash value is
uniform in `[0, p)`, so any sum or product built from it wraps, and the
no-wraparound premise silently fails. The rule for the gadget:

> **No value produced by the hash gadget is ever an operand of a
> range-dependent relation.** Information flows one way only: plane → packing →
> hash → handle. The handle leaves the field entirely (it is compared as 32
> public bytes).

**And the bridge is exact.** The only place where the integer world meets the
modular world is the packing map, `element = Σ 256^k · byte_k` over 4 bytes.
Each `byte_k` is a committed plane already pinned to `[0, 256)` by the existing
`U8` lookups — for the block's two external endpoints those are literally
`byte(A_XL0), byte(A_XL1)` and `byte(A_X2L0), byte(A_X2L1)` in the `Dom::D`
lookup list (`layout.rs:318`, `:332`), tied to the endpoint planes by the
zero-check terms `c2 = x + 32768 − (XL0 + 256·XL1)` and
`c8 = x2 + 32768 − (X2L0 + 256·X2L1)` (`argument.rs:728`, `:736`). Four bytes
reach at most `2^32 − 1`, far below `p`, so the map is injective and the sum
cannot wrap. **The packing therefore needs no new lookup, no new table and no
new range argument** — it is a public linear form over values the proof already
commits and already range-proves. That is a real and slightly surprising
saving, and it is why §3's lookup column is zero.

### 2.7 Side by side, and what the verifier has to compute

Per **absorbed Goldilocks field element** — 4 bytes of plane data (§3.1) —
**with the tree's factor of two (§2.5) included in every row**, so the rows are
comparable. Lookups and committed values are mine, counted from the structures
above; the SHA-256 per-compression figures are the record's central ones.

| candidate | lookups / absorbed element | committed values / absorbed element | new tables | slot degree | note |
|---|---:|---:|---|---|---|
| SHA-256, byte-limb (record's central per compression) | **≈ 500** | **≈ 313** | 2^16-row XOR, AND, split tables | 4 | interoperable with D7's zkVM handle |
| BLAKE3, byte-limb (my count) | ≈ 390 | ≈ 250 | same | 4 | no new assumption; already the project's hash |
| **Poseidon2 w12 r8 c4, `x⁷`, layout A** | **0** | **29.5** | none | **7** | recommended |
| Poseidon2, layout C (bounded linear forms) | 0 | 59.5 | none | 7 | recommended if M1 says layout A's sumcheck dominates |
| Rescue-Prime Optimized w12, 7 rounds | 0 | ≈ 42 | none | 7 | 168 S-boxes/permutation; the conservative choice |
| Monolith w12, 6 rounds | ≈ 24 | ≈ 38 | one 2^16-row table + helpers | 2–3 | pays a lookup bill this prover charges for |
| Tip5 w16, 5 rounds | ≈ 16 | ≈ 30 | one 256-row table + helpers | 7 | least third-party analysis |

Arithmetic for the first row: 4,000 lookups and 2,500 committed words per
64-byte compression, and 64 bytes is 16 absorbed elements, gives 250 and 156
per element in a **linear** chain; doubled for the tree, 500 and 313. For
Poseidon2 layout A: 118 committed values per permutation ÷ rate 8 = 14.75 in a
linear sponge, doubled to 29.5.

> **A correction to the figure now in the register.** D18 and the check quote
> SHA-256 at 65,536 compressions per Mistral endpoint, i.e. a **linear**
> Merkle–Damgård chain (`ZK60_D8_D11_RESTATEMENT.md:944-946`;
> `ZK60_D8_D11_RESTATEMENT_CHECK.md:549-551`). §2.5 shows this prover cannot
> express a sequential chain of any kind — the limitation is the
> arithmetisation's, not the hash's, and it applies to SHA-256 exactly as it
> applies to a sponge. **The honest SHA-256 figure for this prover is therefore
> double the one on the books: about +6.7% of the pass's committed words and
> +45.6% of its lookups for two Mistral endpoints**, not +3.35% and +22.8%.
> Every algebraic figure in §3 carries the same doubling, so the *comparison*
> between the two families is unaffected; the *absolute* SHA-256 cost in D18 is
> understated by 2×, on top of the factor-two band it already declares.

**What the verifier computes: nothing extra of its own.** The verifier never
evaluates the hash. `h` is 32 public bytes in the statement, absorbed into the
transcript like every other public field. The gadget reaches the verifier only
as (i) more rows in the commitment it already checks — so its per-column work
and its Merkle path work grow in proportion to the added rows, about +2% of the
`A`-side rows at 8B (§3.4) — and (ii) a few more sumcheck rounds and terminals,
a few kilobytes. Against the measured 1.08 s verify of the 8B public pass and
the contract's 2 s single-threaded verifier budget
(`ZK60_FIVE_SECOND_PLAN.md` §1.1, §1.2), the gadget is not what breaks the
verifier clause.

## 3. The size of the job

### 3.1 Packing small integers into field words

A hidden plane at one Mistral-width layer over 512 tokens is
`512 × 4096 = 2,097,152` words. They are small: the module's own premise list
puts the block's endpoint planes in int16 (`x`, `ao`, `xres1`, `xres2`, `u16`,
`h16`, `z16`) and its inner activations in `[-127, 127]`
(`layout.rs:284-287`). An algebraic hash absorbs **field elements**, so packing
several plane words into one element divides the permutation count directly.

**How many fit injectively?** `p = 2^64 − 2^32 + 1`, so `p − 1 = 2^64 − 2^32`
[verified by exact arithmetic].

| packing | width | fits? |
|---|---|---|
| 7 int8 (as bytes, base 256) | 56 bits, max `2^56 − 1` | **yes**, comfortably |
| 8 int8 | 64 bits, max `2^64 − 1 > p − 1` | **no** |
| 3 int16 (base 2^16) | 48 bits | **yes** |
| 4 int16 | 64 bits, max `2^64 − 1 > p − 1` | **no**, unless the top limb is capped at 65,534 (then max `2^64 − 2^48 − 1 < p`) |
| **4 bytes (base 256)** | **32 bits** | **yes, always** |

**But injectivity is not the binding constraint — the index map is.** Packing
`k` consecutive plane values into element `j` means reading the plane at
indices `k·j, …, k·j + k − 1`. In a multilinear prover "the plane at index
`k·j + b`" is a claim on the plane's extension with `log₂ k` of its variables
**fixed to `b`** — available as `Coord::Fixed` (`argument.rs:48-53`) **only
when `k` is a power of two**. A non-power-of-two `k` (7 for int8, 3 for int16)
is a *gather*, and needs the same missing shift machinery as §2.5.

So the clean choice is **4 bytes per field element**, which is a power-of-two
split on the byte-limb planes that already exist:

* an **int16** plane: 2 bytes per word ⇒ **2 words per element**, i.e.
  `n_abs = n_words / 2`;
* an **int8** plane: **4 words per element**, `n_abs = n_words / 4`.

For the block's two external endpoints the byte limbs are literally already
committed and already range-proved — `A_XL0/A_XL1` and `A_X2L0/A_X2L1`, with
their `U8` lookups at `layout.rs:318`, `:332` and their reconstruction terms at
`argument.rs:728`, `:736` (§2.6). The packed element is
`XL0[2j] + 256·XL0[2j+1] + 2^16·XL1[2j] + 2^24·XL1[2j+1]`: two planes, each
read at an even and an odd index — one fixed variable. **No new lookups, no new
tables, no new range facts.**

**The lever this leaves on the table.** Going from 4 bytes to 7 bytes per
element would cut the permutation count by **1.75×** and would cut every
number in §3.3 by the same factor. It needs a gather argument (the same
primitive §2.5 wants). Worth building only if M3 says the gadget is the
binding cost; named here so it is not forgotten.

### 3.2 Three layouts, and why the cheapest one changes with the shape

The permutation's 118 S-box applications can be committed in more or less
detail. Fewer committed values means longer public linear forms inside the
zero-check, which the sumcheck prover must evaluate at `degree + 1` points per
round. Three points on that curve:

| layout | what is committed per permutation | committed values | claim sites | longest linear form |
|---|---|---:|---:|---|
| **A** | every S-box output only | **118** | ≈ 128 (one per plane) | ≈ 130 terms |
| **C** | S-box outputs + the 12-element state at ~10 round-block boundaries | **238** | ≈ 128 | ≤ 34 terms |
| **B** | the full 12-element state every round, padded to a 512-wide `(round, element)` axis | **512** | ≈ 12 | ≤ 12 terms |

Claim-site counts are estimates from the existing idiom: `SC_DZC` declares 37
`A` sites for a slot that sweeps about 29 contiguous planes plus extras
(`layout.rs:512`, `argument.rs:708`), so "roughly one site per plane opened at
one point" is the right rule, and each site is 2 mask rows (§2.0(iii)).

**Why the ranking inverts.** At Mistral width the gadget's plane is 2^21 words
and the sites are 128 whatever the shape, so **committed volume dominates and
layout A wins by 4×**. At the tiny shape the whole tree is 63 permutations —
7,434 values, 30 rows — while 128 sites cost 256 rows, so **sites dominate and
layout B wins by 2×**. That inversion is the single most important thing to
know before reading a tiny-shape measurement as if it predicted model scale.
It is also the trap this project has fallen into three times this week:
*"Three counted step sizes out of three shrank by a factor of three to seven
when measured"* (`ZK60_FIVE_SECOND_PLAN.md` §5, third correction).

**My recommendation is layout C**, and the reason is the fourth column. Layout
A's zero-check evaluates 118 polynomials each built from a ~130-term public
linear form, at 8 evaluation points, for every permutation: at Mistral that is
≈ 3.2 × 10^10 field multiply-adds per endpoint [COUNTED from the stated
structure], which is the same order as the whole pass's proven arithmetic
(4.943 × 10^10 int8 MACs/s measured). Layout C's forms are bounded by 34 terms
and it is ≈ 1.7 × 10^10 with twice the volume. Layout A is the volume floor,
not the time floor. **M1 (§6) decides between them, and it is a small
experiment.**

### 3.3 The counts, shape by shape

**The model, stated once.** Permutations for a plane of `n` words of `b` bytes
each: absorbed elements `n_abs = n·b/4`; leaves `L = ⌈n_abs / 8⌉`; **total
permutations `= 2L − 1`** (§2.5). Committed values `= (118 | 238 | 512) ×
(2L − 1)`. Rows `= ⌈values / 2^log_cols⌉` with `log_cols` 8 at the tiny shape
and 14 at the 125M and Mistral shapes. Proof bytes `= (data rows + 2 × sites)
× 2,048`. Everything below is **[COUNTED]** from that model; the model itself
is [MODEL] and the permutation's 118 is [RECALLED] (§2.2).

**One endpoint plane, by shape and layout.**

| shape | words | type | absorbed | leaf perms | total perms | layout | committed values | data rows | proof bytes (incl. sites) |
|---|---:|---|---:|---:|---:|---|---:|---:|---:|
| tiny (T32×d16) | 512 | int16 | 256 | 32 | 63 | A | 7,434 | 30 | 585,728 |
| | | | | | | C | 14,994 | 59 | 645,120 |
| | | | | | | **B** | 32,256 | 126 | **307,200** |
| 125M (512×768) | 393,216 | int16 | 196,608 | 24,576 | 49,151 | **A** | 5,799,818 | 354 | **1,249,280** |
| | | | | | | C | 11,697,938 | 714 | 1,986,560 |
| | | | | | | B | 25,165,312 | 1,536 | 3,194,880 |
| Mistral (512×4096) | 2,097,152 | int16 | 1,048,576 | 131,072 | 262,143 | **A** | 30,932,874 | 1,888 | **4,390,912** |
| | | | | | | C | 62,390,034 | 3,808 | 8,323,072 |
| | | | | | | B | 134,217,216 | 8,192 | 16,826,368 |
| Mistral, int8 | 2,097,152 | int8 | 524,288 | 65,536 | 131,071 | A | 15,466,378 | 944 | 2,457,600 |

(The tiny row uses 256-wide rows; the other two use 16,384-wide rows. Sites
are 128 for layouts A and C, 12 for B.)

**A complete private block's two external endpoints** (D12 item 2: one proof,
one transcript, `x_in` and `xres2`) is exactly twice the relevant row, since
the two planes have the same shape. At Mistral width, layout A: **61,865,748
committed values, 4,288 rows, 8,781,824 proof bytes**.

**A 32-layer feed-forward-only private pass's 64 endpoints.** D17 rule 4 is
explicit that this *"is a cost vehicle and is never called P1"*
(`ZK60_DECISIONS.md:544-549`), so the figure below is a price, not a product.
Taking 32 int8 inputs (the second norm's output, class `[-127, 127]`) and 32
int16 outputs (`z16`), at Mistral width, layout A:
`32 × 15,466,378 + 32 × 30,932,874 = ` **1.485 × 10^9 committed values**, about
90,600 rows and 186 MB of extra proof. Layout C doubles it to
2.99 × 10^9 values.

### 3.4 As a fraction of the pass it rides on

**The denominators, all from the record.** The best 8B public feed-forward pass
is 58.40 s of prove with about 9.777 × 10^9 committed words, 2.296 × 10^9
lookups and 1,234,936,956 proof bytes
(`ZK60_FIVE_SECOND_PLAN.md` §1.2; `ZK60_D8_D11_RESTATEMENT_CHECK.md:550-552`).
Committed volume converts to seconds at about 1.67 × 10^8 words/s (the rate the
check uses). The **private** profile costs about **2.05× the public one**: the
MR1 lane measured the repaired-mask private arm at 4.649 s against a public
2.269 s at the 125M shape on the GPU binary, `rep/pub = 2.0492`
(`ZK60_FSP_MR1_PROGRESS.md` on branch `fsp-mr1`, the GPU table) — the first
measurement of the repaired private profile that exists. At 125M the 12-layer
private pass commits about 2.70 × 10^8 words (`(585 + 486 + 288 + 16) × 16,384
× 12`) and its proof is 88,356,464 bytes [both COUNTED from that lane's exact
row and byte table]. The 32-layer private Mistral proof is about
1.286 × 10^9 bytes (32 × the measured 40,186,228 B layer,
`ZK60_CLAUDE_GPU.md:262-265`).

**Two external endpoints, as a fraction:**

| shape | layout | committed volume | prove seconds | proof bytes |
|---|---|---|---|---|
| Mistral, 8B pass | **A** | **+0.63%** | **+0.37 s of 58.40 s (+0.63%)** | **+8.78 MB of 1.286 GB (+0.68%)** |
| Mistral, 8B pass | C | +1.28% | +0.75 s (+1.28%) | +16.6 MB (+1.29%) |
| Mistral, 8B pass | B | +2.75% | +1.61 s (+2.75%) | +33.7 MB (+2.62%) |
| Mistral, 8B pass | SHA-256, tree-corrected | +6.7% | — | — |
| 125M, 12-layer pass | **A** | **+4.29%** | **+0.20 s of 4.649 s** | **+2.50 MB of 88.4 MB (+2.83%)** |
| 125M, 12-layer pass | C | +8.66% | +0.40 s | +3.97 MB (+4.50%) |
| tiny block | **B** | — | — | **+307 KB of 2,816,472 B (+10.9%)** |
| tiny block | A | — | — | +586 KB (+20.8%) |
| **added lookups, every algebraic layout, every shape** | | **0** | | |

**The three readings that matter.**

1. **At 8B the gadget is small**: under 1% of the pass for both endpoints in
   the recommended layouts, against the +5.5% public / +12.6% private that D18
   records for SHA-256 — and that SHA-256 figure is itself 2× low (§2.7). The
   sentence to carry forward is *"about +0.6% to +1.3% of an 8B pass, and no
   lookups"*, replacing *"about +13% on the private pass"*.
2. **The relative cost grows as the model shrinks**, because the endpoint plane
   is a fixed slice of a pass that gets smaller: 0.63% at Mistral, 4.3% at
   125M, and a fifth of the receipt at the tiny shape. Every proportional
   statement must name its shape. This is the same direction the record already
   found for SHA-256 (+38% of the tiny lookups against +23% at model scale,
   `ZK60_D8_D11_RESTATEMENT.md:970-974`).
3. **The 64-endpoint vehicle is a different animal**: 15.2% of the 8B pass's
   committed volume in layout A, about +8.9 s on 58.40 s, 30.6% and +17.9 s in
   layout C. If the project ever prices that vehicle with handles, it must be
   priced separately and it must keep D17's naming.

**One caveat in the unfavourable direction**, of the kind correction 11 asks
for (`ZK60_D8_D11_RESTATEMENT_CHECK.md:827`). These are relative costs, so if
the pass ever reaches 5 s by getting the same work cheaper, the gadget is
discounted with it. But if the speed comes from a change that does **not** help
the gadget — a lower encoding rate or a 31–32-bit field under D14 — the
absolute seconds stay. In particular a **31–32-bit field would break the hash
outright**: every published Goldilocks parameter set, and the `x⁷` S-box
itself, is specific to `p = 2^64 − 2^32 + 1`. **A D14 field change and this
gadget must be decided together**, and that is a new coupling neither memo
records.

### 3.5 For each number, the first measurement that would settle it

Three counted speed estimates in this project shrank or grew three- to
sevenfold this week when they were measured
(`ZK60_FIVE_SECOND_PLAN.md` §5, third correction). Treat everything above the
same way. For each figure, the experiment and the largest shape it can be run
at on the 8,188 MiB laptop RTX 4070:

| figure | first measurement | shape it can be taken at on the laptop |
|---|---|---|
| 118 committed values / permutation (layout A) | build **one** Poseidon2 permutation as a standalone experimental slot in the private-block module; print the layout's own row, site and slot assertions | tiny, CPU. No GPU needed |
| the degree-7 slot is expressible and its sumcheck is cheap | the same experiment, timed; compare its seconds against a degree-4 control | tiny, CPU |
| layout A vs C vs B | all three for one permutation, then for the 63-permutation tiny tree | tiny, CPU |
| the tree's factor of two, and the level wiring | the tiny 512-word plane end to end; count levels, sites and rows against the model | tiny, CPU |
| +4.29% of the 125M private pass | the 512×768 endpoint gadget inside the repaired private profile, GPU binary, ≥ 5 runs per arm, alternating, on a quiesced box | **125M (512×768) — this fits.** Layout C adds 714 rows ≈ 93 MiB of committed data, ~750 MiB encoded at `inv_rate` 8, against a measured 3,101 MB peak of 8,188 MiB |
| +0.63% of the 8B pass | the gadget alone at a Mistral-width endpoint | **does not fit the laptop.** Layout A alone is 236 MiB of data and ~1.9 GiB encoded; layout C ~3.8 GiB. The largest comfortable probe is a **512×2048** endpoint (layout A: 944 rows, 118 MiB data, ~0.9 GiB encoded). Full Mistral width needs the 5090 or the CPU binary |
| the SHA-256 comparison | implement **one** BLAKE3 `G` function (not a whole compression) in the lookup framework and count its rows and lookup instances | tiny, CPU. This is the check's own recommended measurement (`ZK60_D8_D11_RESTATEMENT.md:1024-1029`), reduced to a quarter of a day |

Two general warnings from the ledgers, both binding on the 125M run: the box
must be quiesced, because the MR1 lane's own CPU ladder came out with the
repaired arm measuring *faster* than the legacy one on a loaded box
(`rep/leg = 0.9918`, an impossibility that calibrates the noise); and a GPU run
must be checked for `gpu: ON` in its header before any number from it is
believed (`ZK60_FIVE_SECOND_PLAN.md` §4).

## 4. Where the gadget goes in the protocol

### 4.1 The four ingredients and where each one lives

The relation "the plane inside `A` hashes to `h`" needs four things. Each has a
home in the existing structure, and one of them raises a question.

**(1) The plane's words — already there, already range-proved.** The two
external endpoint planes `A_X` (`x_in`) and `A_X2` (`xres2`) are committed in
`A` (`layout.rs:127`, `:146`) and byte-decomposed into `A_XL0/A_XL1` and
`A_X2L0/A_X2L1` with `U8` lookups (`layout.rs:318`, `:332`) and reconstruction
terms in `SC_DZC` (`argument.rs:728`, `:736`). The packing map of §3.1 is a
public linear form over those limb planes, read at one fixed variable. **No new
commitment, no new lookup, no new table.**

**(2) The salt — a new hidden value, and it needs its own mask pair.** Four
field elements, committed in `A` as a tiny plane, absorbed by the first
permutation. Under the schedule rule it is one more claim site and therefore
one more reserved mask pair, two more rows (`layout.rs:20-23`). It must be
drawn by nobody: unlike every other hidden value in the proof, the salt is
*given* to the prover by the sealer, so the prover cannot draw it from
`ZkRng`. That is a small but real change to the witness-preparation path, and
it is the only place where a value the prover did not generate enters the
witness. It does **not** make anything a caller-fixed *commitment*: the
commitment that holds it is still built by the prover from its own fresh
randomness.

**(3) The hash's intermediate state — new hidden planes, new mask pairs, no
lookups.** 118 (or 238, or 512) new planes over a new domain
`Dom::Hash = (tree node, …)`, laid out contiguously so one `a_range` sweep
covers them the way `SC_DZC` sweeps `A_X..A_RDL` (`argument.rs:708`). Each
plane opened at one point is one claim site and two mask rows. One new
zero-check slot per tree level (or one slot with a public level-shift table,
§2.5), of degree 7.

**(4) The public `h` — in the statement, absorbed into the transcript.** 32
bytes, alongside the profile string the transcript already absorbs
(`private_block/protocol.rs:33`). **A domain-separation warning that belongs in
the design, not in review:** the transcript's `absorb` is
`BLAKE3(state ‖ 8 ‖ label ‖ 8 ‖ data)` (`zkp-core/src/transcript.rs:44-52`),
which is a 64-byte input whenever `|label| + |data| = 16`, and that domain is
**shared, untagged, with the Merkle and leaf hashes**
(`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:90-98`). Absorbing a 32-byte handle
under an 8-byte label gives a 48-byte input, so it does not land in the shared
64-byte set — but the label must be chosen deliberately and the invariant
asserted, not left to chance.

### 4.2 Checked against D12 and D17

**D12 item 1 — no commitment opened more than once.** Respected, and by more
than accident. The gadget adds rows to commitments the proof already opens
exactly once, and it adds no second opening anywhere. The handle is not a
commitment the proof opens; it is a public constant. Note the direction of
travel: the handle is precisely the thing that lets the project *stop* wanting
a second opening (§5).

**D12 item 2 — one proof, one transcript, two external endpoints.** Respected
for a single block. For a *chain* of separately finished proofs the handle
changes the picture and §5 states exactly how; D12 governs what happens inside
one block and is untouched.

**D12 item 3 — hidden intermediates never get a caller-fixed endpoint
commitment shared by two proofs.** Respected: every hash intermediate lives on
commitments the prover generates inside that one proof. Worth saying plainly
because the gadget introduces a lot of new hidden intermediates and this is the
rule they could most easily have broken.

**D17 rule 1 — any entry point accepting a non-tiny shape binds the whole
plane.** This is a *precondition* on the gadget, not a consequence of it. The
gadget hashes the whole plane by construction (every leaf covers a disjoint
chunk and the tree covers every leaf), so it is compatible; but the endpoint
*equality* argument it rides beside — `SC_IO_IN` / `SC_IO_OUT`
(`argument.rs:902-908`) — is the one D17 constrains, and widening it still
requires the batched multi-block seam.

**D17 rule 2 — the tiny private-IO path stays byte-frozen; everything new is
additive.** This is the binding constraint on how the gadget ships: a **new
profile tag, a new digest domain, a new entry pair beside the pinned ones**,
and no change to any existing constant, label or schedule. Concretely that
means the gadget is a *new module beside* `private_block/`, not an edit to it,
and the twelve byte gates and four frozen digests must be green before and
after. *A moved digest is a bug in the change, not a new baseline.*

**D17 rule 3 — pair exclusivity enforced in code, and a joint-view analysis of
a captured receipt at the widened shape is a hard gate before any quoted
measurement.** This is the gate the gadget must pass, and §4.3 says what it
would have to show.

**D13 and D1 are unaffected.** The gadget changes who may fix an endpoint, not
what the proof is about.

### 4.3 What the joint-view hiding analysis would have to cover

The 2026-09-19 native joint-view analysis (`ZK60_NATIVE_JOINT_VIEW.md` on
branch `zk60-native-jointview`) measures, at the real challenges of four real
captures, the **disclosed dimension**: the rank of what the receipt's field
view reveals about the hidden planes beyond what the public statement already
implies (§2.1 of that document). Its headline is **0 on `A`, on the input
endpoint and on the output endpoint; 2 on `H`**, and the 2 is exactly the
public LogUp identity whose published value is zero (§2.3, §3, §4).

**What the new planes would add to that analysis, item by item.**

1. **Stage 2 (the joint commitment view).** The gadget's planes are more data
   rows on `A` (or on a new commitment of its own). The reduction's three
   hypotheses have to be re-checked, not assumed: **H-pad** (the distinct
   opened columns must not exceed the `Q = 256` pads per row — the measured
   margin today is 9 to 25 and the reduction needs only `distinct ≤ Q`);
   **H-pair** (every new claim site on its own reserved pair, used by no other
   claim, with the two coefficients an `Fp`-basis of `Fp2`); **H-prox** (the
   proximity pair's determinant non-zero). With 128 new sites, H-pair is the
   one most likely to be got wrong by an implementer, and `audit_claims` must
   cover them.
2. **The `k0` term.** The disclosed dimension is `256·k0 + (u-row term)` with
   `k0 = dim{p ∈ rowspace(rho) : p vanishes on every non-data row}`, and `k0`
   is measured 0 on every role today. It must be re-measured, not inherited:
   the gadget changes `rowspace(rho)` by adding 128 group weights.
3. **Stage 3 (the CFS/M view).** Each new slot adds a mask whose length is
   `n_vars·degree + 2`. At **degree 7** those masks are roughly twice as long
   as today's, and the property the lane measured — `rank R_s = dim C_s` for
   every slot, so the masked rounds are uniform on the consistency subspace —
   must be re-measured for the new slots. This is the one place where the
   degree-7 choice touches privacy rather than cost.
4. **Stage 5 (the zero-witness gate).** With nothing disclosed on the new
   planes, a zero-data preimage exists unconditionally, as it does on `A`
   today. If anything is disclosed, the gate must show the disclosed functional
   takes its zero-witness value — which for a hash intermediate it will not,
   so a non-zero reading is a failure, not a footnote.
5. **Stage 6 (the negative controls).** Every existing control must still fire,
   and one new control is owed: **a gadget whose salt plane shares a mask pair
   with a hash-state plane must disclose**. Without it, the analysis cannot
   distinguish "the gadget is clean" from "the tool does not look at the
   gadget".

**Does the hash's nonlinearity change the leak analysis? No — and the reason
is worth stating because it is the obvious worry.** The analysis is a statement
about **what the openings reveal**, i.e. about the linear functionals of the
committed rows that the receipt publishes: claim values, group vectors, the
proximity vector, the sampled columns, the `M` opening, the masked rounds
(§5 of that document lists the channels). A relation's *degree* does not enter
that model at all — a degree-7 hash relation is a zero-check term exactly like
the degree-2 residual relation `c9 = x2 − x1 − z16`. What the openings reveal
is fixed by the row weights and the mask schedule, not by the polynomial.

**What the nonlinearity does change** is already a known limitation rather than
a new one: item 4 of that document's "what is NOT established" says a linear
model cannot see the nonlinear link between the two channels, and item 6 says
integer-range side information is outside the model. A hash makes both of those
*larger in scope* — there is more nonlinearity and the hash's values are full
field elements with no range meaning — without making either of them a new
kind of gap. **It should be said in the disposition that the gadget enlarges
the region the linear tools cannot see, even though it adds no new category of
unexamined channel.**

## 5. Chaining with handles

**The problem, restated from the record.** Two separately finished private
proofs cannot be joined through a polynomial-commitment root. The upstream
receipt already contains a full opening of its output commitment — 256 columns
with salts and authentication paths — so a downstream proof consuming the same
root is a second opening; two openings at the endpoint geometry recover all 512
hidden words; and it is unimplementable today anyway because `Endpoints` is
non-`Clone` and consumed by value
(`ZK60_D8_D11_RESTATEMENT_CHECK.md:668-700`;
`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:72-80`). The disposition's conclusion:
*"a private run is one transcript end to end, or its boundaries need a handle
that is not a polynomial-commitment root."*

**The construction.** Give the boundary its own role. The upstream proof `U`
publishes `h_k = Hash(tag ‖ ctx ‖ SEAM_k ‖ s_k ‖ pack(P))` for its hidden
output plane `P`; the downstream proof `D` takes the same `P` as its hidden
input and proves, against its **own fresh commitment**, that it hashes to the
**same** `h_k` under the **same** `s_k`. Both proofs run the gadget once at
that boundary.

| question | answer |
|---|---|
| **what does each proof open?** | `U` opens its own commitments once each; `D` opens its own commitments once each. **Nothing is opened twice, anywhere.** D12 item 1 holds; case (c) of the obligation never arises |
| **is there prior history under a root?** | No. Each proof's roots are fresh and prover-generated and are first published with the proof that consumes them. The handle is not a root and is never opened, so it has no authentication paths and no top pair to leak |
| **who knows the salt?** | Both provers. If one party proves both, it is a local secret. If two parties do, `s_k` is a **shared secret that must be transported with the plane** — the plane and its salt travel together or the chain cannot be built. A pure relay that carries `(P, s_k)` learns the plane anyway; a relay that carries only `s_k` learns nothing but can help anyone who guesses `P` confirm the guess |
| **what does the chain's verifier check?** | Byte equality of the two handles across the two receipts, plus each receipt on its own. That is a 32-byte comparison, not a cryptographic operation. It is the same shape as D7's *"a chain of blocks is checked by journal equality"* (`ZK60_DECISIONS.md:227-228`) — and D11's caution applies here too: that phrase is an integration description, and the roles must be distinct enough that a boundary handle cannot be mistaken for an external endpoint handle |
| **what leaks?** | **Handle equality is public by design.** The chain's verifier — and any observer of both receipts — learns that the two proofs share a plane. It learns nothing about the plane's value beyond assumption (H-hide). This is *linkage*, not *content* |
| **can the linkage be removed?** | Not while keeping equality-checked chaining. Sealing the same plane twice under different salts gives unlinkable handles, but then the verifier cannot compare them; making the proof show that two handles seal the same plane costs a second gadget instance **and republishes both handles in one receipt, re-linking them**. Linkage is intrinsic to handle-based chaining |
| **cost per boundary** | **two gadget instances**, one in each proof. At Mistral width, layout A, int16: 2 × 30,932,874 = 61.9 × 10^6 committed values, 4,288 rows, 8.78 MB of proof — i.e. **+0.63% of an 8B pass per boundary** [COUNTED, §3.4]. A 32-layer pass cut into `K` runs costs `2(K − 1)` boundary instances plus 2 external ones |

**Is the linkage acceptable under P1?** D1 requires that inputs, outputs and
intermediate activations are hidden from the verifier and from every public
artifact (`ZK60_DECISIONS.md:38-52`). A handle is a public artifact computed
from a hidden activation; under (H-hide) it reveals nothing about the value,
so the *value* stays hidden. What becomes public is a *relation between two
receipts*. **That is a product ruling, not a security one**, and it is the same
question the restatement raised from the other side: without a reusable
identifier, *"a regulator can no longer point at two different receipts and say
'these used the same input'"* (`ZK60_D8_D11_RESTATEMENT.md:1163-1167`). With
handles it can — which is a feature for audit and a leak for privacy,
depending on what the product is for. Decision **PO-3** of §7.1.

**Against the only alternative: one transcript end to end.** Keeping the whole
private run in one proof costs zero gadget instances and leaks no linkage. It
is the right answer where it fits. **It does not fit today at 8B on a consumer
card**: the recorded 32-layer private GPU pass took 265.34 s because it spilled
to 8,585 MB on an 8,188 MiB card (`ZK60_FSP_MR1_PROGRESS.md`, quoting
`ZK60_CLAUDE_GPU.md`), and the form-E line of work recommends runs of blocks
rather than one run precisely for that reason. So the realistic reading is:
**one transcript within a run, handles between runs**, with the run length set
by memory rather than by cryptography — and the handle is what makes the split
legal rather than a second opening in disguise.

One thing this does **not** do: it does not make a chain's *soundness* follow
from the parts. Handle equality binds the planes; it says nothing about
whether the two proofs use the same model, calibration or request — those are
what `context` and the model digests are for, and D12 item 5 already records
that today's endpoint scale tags prove nothing
(`ZK60_DECISIONS.md:342-347`). A chain argument owes that separately.

## 6. A staged plan, smallest measurable step first

Five stages. Each is a day or two, each ends in a number, and each can be
abandoned without touching a frozen path. Everything is **additive** under
D17 rule 2: a new module, a new profile tag, a new digest domain, new entry
points beside the pinned ones. *No existing constant, label, schedule or
digest moves at any stage; a moved digest is a bug in the change.*

**M1 — one permutation, on paper's terms.** Implement a single Poseidon2-shaped
permutation as a standalone experimental zero-check in a scratch module, in all
three layouts of §3.2. Count committed values, claim sites and rows from the
layout's own assertions; time its sumcheck against a degree-4 control. Tiny
shape, CPU, no proof needed.
*Answers:* is 118 right; is degree 7 expressible in `define`/`masked_prove`
without a new primitive; which layout wins where; is the degree-7 sumcheck
cheap.
**Kill:** if the degree-7 slot needs a new primitive, or if one permutation
costs more than about 300 committed values in the best layout, stop and
re-scope to Monolith (§2.3) before writing anything else.

**M2 — the tree wiring.** Extend M1 to a 4-leaf tree. Decide between level-wise
plane families and the public level-shift table (§2.5) by counting sites and
rows for both.
**Kill:** if neither form avoids a shift primitive, the whole native route
fails and the fallback is "one transcript end to end, no chaining, prover
seals" — i.e. D18's case A forever.

**M3 — the tiny 512-word plane, end to end, with a verifier that rejects.**
A complete experimental profile: the tiny private block plus a handle gadget on
its input endpoint. **Acceptance checks, all of them required:**

1. an honest proof **verifies**;
2. a plane that does **not** hash to `h` is **rejected by the verifier** from
   the receipt bytes alone, in a fresh process — not by a prover-side check
   and not by an assertion;
3. a **wrong salt** is rejected the same way;
4. the handle is **reproduced bit-for-bit by an independent few-line Python
   reference implementation** of the same permutation, written from the
   specification and not from the Rust;
5. the **leak-checking tools run on the grown layout**: the joint-view rank
   and CFS gates report disclosed 0 on `A` and on both endpoints and 2 on `H`
   (the existing public LogUp identity), `rank R_s = dim C_s` on every new
   slot, and **every negative control fires**, including the new one of §4.3
   item 5;
6. the twelve byte gates and the four frozen digests are green **before and
   after**, and no digest moves;
7. the receipt's byte length and every added row and site match the model of
   §3.3, or the model is corrected in writing.

**Kill:** any of 1–6 failing; or a disclosed dimension above the baseline on
any role.

**M4 — the 125M shape on the GPU.** The 512×768 endpoint inside the repaired
private profile. ≥ 5 runs per arm, alternating order, on a **quiesced** box,
`gpu: ON` confirmed in every header, exact rows and bytes recorded beside the
noisy seconds. Compare against §3.4's +4.29% / +0.20 s / +2.83%.
**Kill:** measured cost above **10% of the private pass** at 125M. (The
threshold is set by the alternative: SHA-256 is counted at +12.6% of a private
pass, and an algebraic hash that does not comfortably beat that has no reason
to exist.)

**M5 — one Mistral-width endpoint, or as close as the hardware allows.** Not on
this laptop: §3.5 shows a full 512×4096 endpoint needs ~1.9 GiB encoded in the
cheapest layout. Run **512×2048** on the 4070 as the scaling rung, and the full
width on the 5090 when it lands.
**Kill:** the scaling from 125M to 512×2048 departs from the model by more than
2×, which would mean the model is wrong about what dominates.

**Two kill criteria that apply to every stage.** (i) If the gadget forces a
change to a frozen path rather than an additive one, stop and report — that is
D17 rule 2 and it is not negotiable. (ii) If no Goldilocks parameter set for
the chosen permutation can be pinned to a published specification with
published cryptanalysis, the security assumption cannot be put to the project
owner and the work is premature (§7.1 decision 1).

**What is deliberately not in the plan.** Building the 7-bytes-per-element
gather (§3.1), the shift primitive for a linear sponge (§2.5), the 64-endpoint
cost vehicle (§3.3), and any change to the D14 field question — which, as §3.4
notes, would invalidate the hash choice entirely and must be decided jointly.

## 7. Decisions, open obligations, and what I did not check

### 7.1 Decisions for the project owner

These are written to be readable without cryptography. Each is a ruling of the
same kind as D3, D4 and D7: accepting a stated assumption in exchange for
something the product needs.

**PO-1 — Which hash the handle uses. This is a new security assumption and it
needs your acceptance.**
*Recommendation: a Poseidon2-shaped permutation over the project's own 64-bit
field, width 12, capacity 4, with the `x⁷` S-box — subject to pinning its
parameters to a published specification (M1's precondition).*
*Reason:* it is the only family with widely deployed parameter sets for this
exact field, and in this prover it costs **no table lookups at all** and about
a fifth of what SHA-256 costs. In plain words: you would be trusting a hash
function that is newer and less battle-tested than SHA-256, in exchange for
the handle costing about half a per cent of a proof instead of several per
cent. The conservative alternative is **Rescue-Prime**, older and more
carefully argued, at roughly 1.4× the cost; the no-new-assumption alternative
is **BLAKE3**, which the project already relies on, at roughly 8× the cost and
with hundreds of millions of extra table lookups.

**PO-2 — Interoperability with the zkVM line, and what it costs.** If the
handle used **SHA-256**, a handle sealed for the slow zkVM line (D7) and a
handle sealed for the fast native line would be the *same object*, and a proof
on one line could consume the other's output. *Recommendation: do not buy it
now; record it as the reason SHA-256 stays on the list.* *Reason:* it costs the
full bit-oriented price (§2.1) on every proof, for a capability nothing in the
current roadmap needs, and it can be added later as a second handle kind.

**PO-3 — Linkage. Do you want two receipts about the same hidden value to be
publicly recognisable as such?** Handle-based chaining makes them so, by
design and unavoidably (§5). *Recommendation: accept it for chaining, and
record it as a named deviation from "nothing about the hidden value is
public", in the way D7's three qualifiers travel with the zkVM claim.*
*Reason:* the alternative is no chaining, and today no 8B private pass fits one
proof on a consumer card. Note the same property is what would let a regulator
say "these two receipts used the same input" — which you may want.

**PO-4 — The salt becomes a two-party secret.** The sealer must hand the salt
to the prover along with the plane, and both must keep it. *Recommendation:
accept, and record that a leaked salt turns a low-entropy hidden value into a
guessable one* — D7's first qualifier, now applying to a second party as well
(`ZK60_DECISIONS.md:242-247`). *Reason:* there is no construction that avoids
it; the prover cannot prove a statement about a salt it does not hold.

**PO-5 — Build order.** *Recommendation: authorise M1–M3 of §6 now (a few
days, tiny shape, CPU, nothing frozen touched), and decide M4/M5 on M3's
numbers.* *Reason:* three counted estimates in this project moved by three- to
sevenfold this week when measured; M1 alone converts the central claim of this
memo from a count into a number.

### 7.2 Decisions for the security owner

**SO-1 — Layout A, C or B.** *Recommendation: C provisionally, decide on M1.*
*Reason:* A minimises committed volume but its ~130-term linear forms make its
own sumcheck the second-largest item; C bounds the forms at 34 terms for twice
the volume; B wins only at the tiny shape.

**SO-2 — The tree's level wiring.** *Recommendation: the public level-shift
table, decide on M2.* *Reason:* it keeps the claim-site count flat, and claim
sites are the cost that does not shrink with the shape.

**SO-3 — Keep BLAKE3 for the transcript and the Merkle layer; use the
algebraic hash only for the handle.** *Recommendation: yes.* *Reason:* the two
hashes have opposite requirements — the transcript's must be fast in software,
the handle's must be cheap inside a proof — and the project would carry two
assumptions either way, since replacing BLAKE3 everywhere is a far larger
change. Record it as two assumptions, not one.

**SO-4 — The handle's transcript label must not land in the shared untagged
64-byte BLAKE3 domain** (`transcript.rs:44-52`;
`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:90-98`). *Recommendation: fix the label
so `|label| + |data| ≠ 16`, and assert it mechanically alongside the existing
`commitment_rows ∉ {5, 8}` invariants of the disposition's §2.8.*

**SO-5 — The new control of §4.3 item 5 is required before any quoted
measurement**, per D17 rule 3. *Recommendation: make it a gate, not a
checklist item.* *Reason:* without a control that fires, a clean reading from
the leak tools cannot be distinguished from a tool that does not look at the
new planes.

**SO-6 — D14 and this gadget are coupled and must be ruled on together.** A
31–32-bit field would invalidate every Goldilocks parameter set and the `x⁷`
S-box. *Recommendation: add a line to the D14 memo's question list saying so.*

**SO-7 — The SHA-256 figure in D18 should be corrected.** It assumes a linear
hash chain this prover cannot express (§2.7), so it is 2× low before its own
declared factor-two band. *Recommendation: restate D18's "+5.5% public /
+12.6% private" as "about +11% public / +25% private for SHA-256, or about
+0.6–1.3% of a public 8B pass for an algebraic handle, both counted and
untested".*

**SO-8 — Whether the 64-endpoint feed-forward-only vehicle is ever priced with
handles.** *Recommendation: no, unless a specific measurement needs it.*
*Reason:* 15–31% of the pass (§3.3), and D17 rule 4 already says that pass is
never P1.

### 7.3 Open obligations

1. **D8 and D11 remain open**, exactly as written. This construction does not
   close them; it builds a configuration they do not bind. If a caller ever
   fixes a polynomial-commitment root again, they apply in full.
2. **Game J's simulator does not exist.** `SimProve` is recorded as incomplete
   (`ZK60_ENDPOINT_SIMULATION_MODEL.md:76`). The handle makes the standard game
   the right one; it does not discharge it.
3. **(H-hide) is a new assumption** — random-oracle hiding of a salted hash of
   a possibly low-entropy plane — and for the algebraic candidates it has no
   published reduction. It must travel with every claim, the way D7's three
   qualifiers do.
4. **O1 (the joint conditional field sampler) and O2 (the joint hypothesis,
   U-3)** are untouched and are still the hard ones.
5. **The whole-proof soundness figure does not improve**: about 94 bits at 8B
   per D15, with the handle's 128 one more term in the union bound.
6. **The untagged 64-byte BLAKE3 domain** shared by the transcript and the
   Merkle layer is unchanged and is now one label closer to mattering (SO-4).
7. **The chain's model/calibration binding** is separate from handle equality
   and is owed by any chain argument (§5, last paragraph), as is D12 item 5's
   unresolved endpoint scale tag.
8. **The joint analysis at the grown layout has never been run** and is a hard
   gate under D17 rule 3.

### 7.4 What I did not check

**Ran nothing.** No build, no proof, no test, no benchmark; read-only
throughout, and no file in this repository was modified but this one.

**From my own memory of the literature, unverified against any source, and the
most likely place this memo is wrong:** every parameter set, round count,
width, rate, capacity, author list and cryptanalysis statement in §2.2 and
§2.3 — Poseidon, Poseidon2, Rescue-Prime/RPO, Monolith, Tip5, Reinforced
Concrete. In particular I would not stake anything on "8 full + 22 partial
rounds at width 12", and the 118 S-box applications that carry **every cost
number in §3** follow directly from it. The flat-sponge collision bound of
§1.4 is also recalled. **The first thing a reviewer should do is check the
round counts against the reference implementations**; if Poseidon2 at width 12
needs materially more rounds, §3's figures scale linearly with the S-box count.

**Facts I verified in this repository** (file:line given throughout): the
prover's currencies and their measured shares; the lookup form and the
two-column table idiom; the `U8` byte decomposition of both external endpoint
planes and the zero-check terms that tie them; the absence of any shift or
rotation operator in the claim-point machinery; the sumcheck's and the CFS
mask's genericity in degree; the endpoint equality slots; the transcript's
absorb construction; the zkVM line's handle construction; the mask-pair
schedule rule; and the measured 125M private/public ratio, rows and bytes.

**Not checked, and each could move a number:**
* whether the **GPU zero-check kernels** support degree 7, or would need new
  ones — this is the most likely hidden cost in the whole memo;
* whether `masked_prove` at degree 7 is *efficient*, as opposed to merely
  expressible;
* the exact claim-site count the layout builder would demand for a new domain
  (I used "one site per plane per point", which the existing slots support but
  which a real layout may exceed);
* the host-side cost of generating and encoding the new mask rows, which the
  MR1 lane found to be **53% of the repaired profile's added cost** — my model
  counts rows, not host seconds;
* the wire format, the parser, the refusal list and the tamper tests, none of
  which I sized;
* whether a new commitment for the gadget is cheaper than more rows on `A`;
* the 5090's behaviour, which nothing in this memo models.

**(draft complete)**
