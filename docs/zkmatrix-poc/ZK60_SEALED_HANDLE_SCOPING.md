# The sealed handle: scoping a hashing gadget for the fast native line

**Status: REVISED AFTER INDEPENDENT CHECK — the construction's shape is
accepted as the right one for sealing in advance; this memo is NOT accepted as
a basis for any cost or for the choice of hash, per
`ZK60_SEALED_HANDLE_SCOPING_DISPOSITION.md` (security owner, 2026-09-19).
Blocking items B-1 … B-8, the corrections and conditions of
`ZK60_SEALED_HANDLE_SCOPING_CHECK.md` and rulings S-1 … S-8 applied. Nothing
here is scheduled to be built: the first MVP seals at proof time (D18). Not a
privacy acceptance; D8 and D11 remain open. Paper only; every cost is counted
or modelled, none measured. Drafted by a delegated Opus agent.**

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

1. **The cost is a band, not a number, and the band is wide.** A hash designed
   for this kind of proof, working in the prover's own 64-bit arithmetic,
   counts at **0.72% to 2.06% of an 8B public pass's committed words for both
   endpoints**, plus **+0.5 to +9.3 s for the gadget's own zero-check** that
   the draft left out, and **adds no table lookups** on the tiny profile
   (though it does on the path the 8B figures are quoted against) (§3.4). At
   the 125M shape it is **7% to 50%** of the private pass, and at the tiny
   experimental shape **one endpoint's gadget can exceed the whole receipt**.
   Every one of those bands is dominated by a single unmeasured quantity —
   how many claim sites the layout builder demands for a tree — which a
   half-day experiment settles (§6 M0). *The draft's headline of "+0.6% to
   +1.3%" is withdrawn: it was the bottom of the band.* About the figures in
   the register: the public one (+5.5%) follows from its stated basis; **the
   private one (+12.6%) has no published derivation, could not be reproduced,
   and is unverified**; and the draft's claim that both were "about 2× low"
   was checked and **withdrawn** (§2.5, §2.7, SO-7).
2. **It buys something the project cannot otherwise have: chaining.** Two
   separately finished private proofs cannot be joined through a commitment
   root — the first one has already opened it
   (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:72-80`). A handle can be published
   by one proof and consumed by the next, with nothing opened twice (§5). On a
   consumer card that matters: the 32-layer private 8B pass does not fit one
   process today.
3. **It swaps one unproved thing for another unproved thing — not for
   nothing — and adds a new operational duty.** The configuration D8 and D11
   bind does not arise here, because no commitment the proof opens was made
   by anybody but the prover. What takes its place is an assumption that a
   salted hash hides a plane that may have **very little entropy** — D7's own
   first qualifier warns that in the toy token model the hidden answer is one
   of only 32 values, so anyone who learns the salt learns the answer
   (`ZK60_DECISIONS.md:242-247`). **And the honest name for that assumption,
   for the algebraic hashes this memo costs, is "a keyed-mode assumption on a
   primitive analysed only in unkeyed mode"** — every published analysis of
   those candidates is of an unkeyed public hash (§1.3). The security owner's
   direction for removing that discomfort is the **two-layer handle** of
   §1.4, which puts hiding back on a standard salted hash of the kind you
   already accepted in D7 and leaves only collision resistance on the newer
   primitive; **it is unchecked and priced only by counting**. The new duty:
   the salt must travel from the sealer to the prover and stay secret in two
   places instead of one (PO-4). **This does not close D8 or D11.** It builds
   a configuration they do not bind.
4. **Two things that were not in the draft and that you must be told.**
   Handle-based chaining makes linkage **public, retroactive and permanent**,
   and a party who guesses a low-entropy plane and knows the salt can confirm
   the guess (PO-3, §5). And **which hash the handle uses is a security
   acceptance for you**, of the same kind as D3, D4 and D7 — this memo now
   recommends **no hash**, because the published cryptanalysis moved twice in
   2026 and must be read again in the week the decision is taken (PO-1).

Everything below is paper. Nothing was built, run or measured for it. The
memo has been through one independent adversarial check
(`ZK60_SEALED_HANDLE_SCOPING_CHECK.md`) and one ruling
(`ZK60_SEALED_HANDLE_SCOPING_DISPOSITION.md`); what changed, item by item, is
listed in the revision record at the end.

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

**The handle.** *The draft's formula omitted the element count and every
tree-shape field; it is corrected here (B-2, S-2) and the omission is why
§1.5's binding argument did not hold as originally written.*

> `h = Hash( domain_tag ‖ context ‖ role ‖ element count ‖ shape ‖ salt ‖ pack(plane) )`
>
> hashed under a tree whose **leaves and internal nodes are domain-separated**,
> whose **shape is encoded** (Sakura-style), and with a **stated padding rule
> for a ragged last chunk**.

with the parts fixed as follows. This is the shape D7 already uses on the
zkVM line, transposed to the native field — and D7's version **already
absorbs its element count**
(`h.update((ELEMENTS as u32).to_le_bytes())`), which the draft's prose
described and its formula then dropped. The zkVM version is
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
| `element count` | the number of packed field elements, absorbed before the values, exactly as `zkvm-block/statement/src/lib.rs:65-78` does; without it planes of different sizes collide trivially under any padding rule | determined by the plane's shape | at sealing time |
| `shape` | the plane's dimensions and the **tree's shape** (leaf count, depth, the `k` of §2.5, and the padding of the last chunk), with leaf and internal nodes domain-separated; without it a node digest can be reinterpreted as message and different trees collide | the statement version and the plane's shape | at freeze / sealing time |
| `salt` | **256 fresh random bits per handle** — 4 **uniformly sampled** Goldilocks field elements (not 64 random bits reduced mod `p`: D9 records a reduction bias for exactly that), matching D7's 32 bytes; **never reused across handles and never derived from the plane** | **the sealer**, from OS randomness | at sealing time |
| `pack(plane)` | the plane's words packed into field elements, injectively, in a fixed order pinned by the statement version — the signed encoding, the limb order and the tiling all named, because the module contains at least three signed byte encodings (§3.1) | determined by the plane and the pinned map | — |

**Who knows what.** The sealer knows the plane and the salt. The prover must
be given **both**: it cannot produce the proof from the plane alone, because
the relation it proves mentions the salt. The verifier knows only `h`, the
`domain_tag`, the `context` and the `role`. Nobody else learns anything from
the published bytes beyond `h`.

**When.** `h` is published whenever the sealer chooses — days before any proof
exists. Nothing about the prover, the proving key, the commitment randomness
or the transcript is needed to compute it. That is the whole point: the
regulator can seal today and ask for a proof tomorrow.

**Who the sealer is, and what the product may assume about it.** *The draft
had an honest sealer throughout and did not state a threat model; this is the
model, in the form ruling S-4 fixes it* (B-3).

* **Who seals, deployment by deployment.** A regulator sealing **its own**
  test input; a user's client sealing the **user's own** prompt; an upstream
  prover sealing **its own** output at a chain boundary (§5). In every one of
  them **the sealer holds the plaintext of the plane it seals.** No mechanism
  here protects a plane from its own sealer, and none is claimed.
* **The sealer chooses the salt, and the salt is the only thing protecting
  the prover's data.** A sealer adversarial about the *prover's* privacy could
  reuse a salt across handles, derive the salt from the plane, or grind the
  salt so that `h`'s low bits encode chosen information about the plane. The
  rule of §1.1 forbids all three. But note what such a sealer would be doing:
  opening **a channel between parties who could talk anyway**, since it
  already holds the plaintext.
* **Symmetrically, a malicious *prover* can always publish its own witness.**
  Zero knowledge never protected a data subject from the prover, on this line
  or any other. The threat model is therefore smaller than it first appears,
  and it is written down so that nobody later mistakes the rule for a
  guarantee.
* **What an unverifiable salt is worth: exactly the sealer's diligence.**
  Nothing in the receipt proves the salt was uniform, and no party but the
  sealer can check it. That is acceptable **because the sealer is entitled to
  the plaintext** — and it is not a claim, and must never be written as one.
* **Attested salt generation** — a salt derived as `PRF(sealer key,
  context ‖ role)` with the key's uniqueness attested, or hardware attestation
  of the draw — is recorded as **a possible hardening, not a requirement**.

The operational half of this (transport, storage, rotation, destruction,
re-sealing, and the availability failure when a salt is lost) is PO-4 and is
still undesigned.

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

**But "the standard commit-and-prove game applies" is too comfortable as the
draft put it.** Today's receipts contain no public value that is a function
of the hidden plane which the prover did not choose: every root is fresh and
prover-generated, so a simulator may simply invent one. **A handle is the
first object in this project that is (a) public, (b) a deterministic function
of hidden data, and (c) fixed before the simulator runs.** The simulator's
job therefore gets strictly *harder*, not easier: it must fake a whole
transcript for a statement string it cannot choose. That is ordinary NIZK
simulation, but it is *more* than "the simulator produces the commitments"
buys. The sentence to carry forward is: the configuration moves to the
standard game **and adds a statement the simulator must live with**.

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
4. **NIZK simulation says nothing about whether the *statement* leaks.** That
   is carried entirely by (H-hide), which is not a NIZK property and has no
   published reduction for any algebraic candidate. So wherever this memo
   says D8/D11's problem "disappears", read: **one unproved thing is swapped
   for another unproved thing, not for nothing.**

**The assumption that takes the obligation's place.**

> **(H-hide)** For the chosen hash `H`, and for a salt drawn uniformly from
> 256 bits, the value `h = H(tag ‖ ctx ‖ role ‖ salt ‖ pack(P))` is
> computationally independent of the plane `P`, **even when `P` ranges over a
> small set**.

In the random-oracle model this is immediate and quantitative: an adversary
that makes `q` oracle queries distinguishes with advantage at most
`q · 2^-256` **provided the salt stays secret**, whatever `P`'s entropy,
because every query it can afford misses the secret 256-bit block. That
arithmetic is sound as far as it goes, and it is why 256 bits rather than 128
is the right call: over `N` published handles the multi-target term is
`q · N · 2^-256`, where at 128 bits and the 64 handles of a 32-layer
feed-forward pass it would be `q · 2^-122` [RECOMPUTED by the check].

**But the draft's label for (H-hide) is withdrawn** (B-1). It read: *"a
random-oracle assumption on a new primitive"*. **"Random-oracle hiding" is
not an honest model for an algebraic permutation used with a secret salt**,
for a reason sharper than "algebraic hashes are newer":

* every published analysis of Poseidon2, Rescue-Prime Optimized, Monolith and
  Tip5 is of an **unkeyed public hash** — collision resistance, preimage
  resistance, CICO. The handle uses the primitive in a **keyed** mode, where
  a secret 256-bit salt is the only thing between a public digest and a
  possibly low-entropy message. That is a PRF / keyed-sponge claim;
* the sponge bound the ROM arithmetic leans on is **explicitly conditioned on
  an ideal permutation** and says nothing about algebraic structure
  [reported by the independent check from a public source];
* **algebraic attacks are at their strongest in exactly the setting a salted
  handle of a low-entropy plane creates**: a known output, a known
  low-entropy part of the input, and a small unknown algebraic block to solve
  for;
* **no published keyed-mode analysis of any of these permutations was
  found.**

**So the honest label is: (H-hide) is a keyed-mode assumption on a primitive
analysed only in unkeyed mode.** That is a strictly weaker starting point
than "a new primitive in the random-oracle model", and the project owner must
be told it in those words. §1.4 is the security owner's direction for
removing this obligation rather than accepting it — unchecked.

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
  This is a new operational requirement and belongs in the ruling (PO-4).
* **Sample it as 4 uniform field elements**, not 64 random bits reduced mod
  `p`: this project has a recorded reduction bias for exactly that
  (D9, `ZK60_DECISIONS.md:371-410`) (C-2).
* **A handle is a stable identifier, and that is a different exposure profile
  from a commitment root.** The same plane under the same salt always gives
  the same `h`, where two commitment roots for the same plane are always
  different. **One salt leak therefore makes every handle ever published
  under it checkable, for ever**, and a low-entropy plane makes checking
  cheap. Retroactive and permanent — see PO-3.

### 1.4 The two-layer handle (the security owner's direction — UNCHECKED)

**This whole section is the security owner's proposal, recorded in ruling S-3
of `ZK60_SEALED_HANDLE_SCOPING_DISPOSITION.md`. It is unchecked by anyone, it
has been attacked by nobody, and nothing in it is priced by measurement. It
is written here so that the next independent check can attack it like any
other claim.** It exists because §1.3's assumption is uncomfortable: it puts
hiding on a keyed mode of a primitive analysed only unkeyed.

**The construction.**

* **The inner layer.** The algebraic hash of §2.2 is computed over the packed
  plane **with no secret in it at all** — no salt, no key, plain unkeyed
  hashing, exactly the mode the published cryptanalysis is about. Its root is
  **never published**. It exists only inside the proof, as hidden
  intermediates on the prover's own commitment, like every other hidden
  intermediate.
* **The outer layer.** The public handle is a **standard** hash:

  > `h = StdHash( tag ‖ context ‖ role ‖ element count ‖ shape ‖ salt ‖ algebraic root )`

  where `StdHash` is the slow line's **SHA-256** (D7's choice) or the
  transcript's **BLAKE3**. If it is BLAKE3, note the recorded hazard: the
  transcript and the Merkle/leaf hashes already share an **untagged 64-byte
  BLAKE3 domain** (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:90-98`), so **the
  handle needs its own tag** and the invariant must be asserted mechanically,
  not assumed (SO-4).
* **Inside the proof** that outer hash is one gadget over a **fixed, tiny
  input** — a few dozen bytes — so it costs **two byte-hash compressions and
  does not grow with the plane**, however wide the model.

**What that buys.**

1. **Hiding rests on a standard salted hash**, which is the assumption the
   project owner **already accepted** for the slow line in D7 — not on a
   keyed mode of an algebraic permutation with no published reduction.
2. **Only collision resistance rests on the algebraic permutation**, and that
   is the mode the literature actually analyses.
3. **The salt-position problem disappears.** §2.5's finding — that a salt
   placed in one leaf leaves every other leaf digest an unsalted hash of a
   32-byte activation chunk, whose secrecy then rests on the undischarged
   PCS-hiding stack — has nothing to bite on, because the inner hash has no
   salt anywhere and its digests are ordinary hidden intermediates.
4. The **element count and the shape enter the public hash directly**, which
   is where B-2 wanted them.

**What D7's qualifier becomes here, precisely.** D7's first qualifier warns
that *"the hiding of an endpoint is the secrecy of its salt under SHA-256 — in
the toy token model the answer is one of only 32 values, so whoever learns the
salt learns the answer"* (`ZK60_DECISIONS.md:242-247`). Under the two-layer
handle the hashed value is **a high-entropy 32-byte root plus a 256-bit
salt**, not a low-entropy plane. **What that changes:** the outer hash is no
longer being asked to hide a message drawn from a small set, which is the
setting where salted hashing is at its weakest and where algebraic attacks are
strongest; and the assumption is one the project owner has already accepted
once. **What it does not change:** a leaked salt still lets anyone who
*guesses* the plane confirm the guess — they compute the inner root from the
guess and then the outer hash — so the entropy of the plane still matters
exactly as much as before against a salt compromise. Two-layer hashing buys a
better-analysed assumption, **not** protection against a leaked salt over a
guessable plane.

**What it costs** [COUNTED from this memo's own per-unit figures, unverified;
nothing measured].

The outer hash's input, with the fields of §1.1 plus the count and shape:
`tag` + `context` 32 + `role` 1 + element count 4 + shape 8 + `salt` 32 +
`algebraic root` 32 bytes. With a compact 8-byte tag that is **117 bytes →
2 compressions** (117 + 9 bytes of padding ≤ 128); with the 22-byte ASCII tag
of §1.1 it is 131 bytes → **3 compressions**. Take 2 as the design target and
3 as the pessimistic case.

| per-compression figure used | source | lookups, 2 comp. | lookups, 3 comp. | committed words, 2 comp. | committed words, 3 comp. |
|---|---|---:|---:|---:|---:|
| **4,000 lookups / 2,500 committed words** | the record's central figure (`ZK60_D8_D11_RESTATEMENT.md:948-950`) | **8,000** | 12,000 | **5,000** | 7,500 |
| **12,800 lookups** | this memo's own byte-limb count of SHA-256 (§2.1) | **25,600** | 38,400 | (same 5,000) | (same 7,500) |

Both per-compression figures are **unverified in both directions** — the
check could confirm no byte-hash arithmetisation cost at all (§2.1) — so they
are shown side by side rather than one being chosen.

| shape | committed words added (2 comp.) | as a fraction of the pass | rows added | proof bytes added |
|---|---:|---|---:|---:|
| **tiny** (256-wide rows, 2,816,472 B receipt) | 5,000 | — | **20** | **40,960 B = 1.45% of the receipt** (3 comp.: 30 rows, 61,440 B, 2.18%) |
| **125M**, 12-layer private pass (2.70 × 10^8 words, 16,384-wide rows) | 5,000 | **0.0019%** | **1** | ≈ 2,048 B |
| **Mistral**, 8B public pass (9.777 × 10^9 words, 2.296 × 10^9 lookups) | 5,000 | **0.00005%**; lookups **0.00035%** on the record's figure, **0.0011%** on this memo's | **1** | ≈ 2,048 B |

**Read that table the right way.** The outer layer is **negligible at model
scale and small even at the toy shape** — because it hashes a fixed few dozen
bytes, not the plane. The gadget's real cost is unchanged: it is the **inner**
algebraic hash over the whole plane, priced in §3.4, and the two-layer form
neither adds to nor subtracts from that. What it adds is **engineering**: two
gadgets instead of one — an algebraic permutation gadget *and* a byte-hash
compression gadget, the latter needing the 2^16 XOR/AND table domain this
profile does not have (E-6, §2.0) — plus a second reference implementation, a
second set of negative controls and a second thing to get wrong. The claim
sites those extra planes demand are **not counted here** and are part of what
M0 must print.

#### How to attack this

A checker should press at least the following. None of them has been
answered.

1. **Does the sealer now need the algebraic hash in ordinary software?
   Yes.** The sealer must compute the inner root over the packed plane to
   compute `h` at all, so "a third party can seal with three lines of
   ordinary code" becomes "a third party needs a correct implementation of
   the algebraic permutation *and* the packing map *and* a standard hash".
   That is a materially higher bar for a regulator's toolchain than a plain
   SHA-256 of a serialised tensor, and it makes C-4's pinned packing map and
   M3's independent Python reference load-bearing rather than merely prudent.
2. **Is collision resistance of the inner hash still load-bearing for the
   statement's meaning? Yes.** The outer hash binds the root; the root binds
   the plane. If two planes share an inner root, the handle cannot tell them
   apart, so §1.5's entire argument still rests on the algebraic
   permutation — which is exactly what S-3 intends, but it means a break of
   the inner hash breaks *soundness of the statement*, not merely a cost
   estimate.
3. **Does a second preimage on the algebraic hash let a prover substitute a
   different plane?** It looks like it must: a prover that finds `P'` with
   the same inner root proves the model's arithmetic on a plane the sealer
   never sealed, and the outer hash matches unchanged. Note the prover here
   does **not** get to choose the salt (the sealer did), so this is a
   *second-preimage* attack on an unkeyed hash and not a collision search —
   a different and in principle harder problem than the one §1.5 states for
   the single-layer design. Whether that difference is worth anything must be
   argued from the literature, not asserted.
4. **What does the verifier of a CHAIN compare?** Two handles for byte
   equality, as in §5. But equality of the *outer* hashes now requires the
   two proofs to agree on the salt, the tag, the role, the count and the
   shape as well as the plane — so the chain's boundary carries more agreed
   metadata than before, and a mismatch in any of it looks identical to a
   mismatched plane. Is that a soundness improvement (more is bound) or an
   operational trap (more ways for an honest chain to fail)? Both, probably;
   nobody has written the failure table.
5. **Does the standard hash's in-proof gadget need tables this prover does
   not have? Yes.** Byte-limb SHA-256 or BLAKE3 needs 2^16-row XOR/AND
   tables, and this profile pins tables at 256 entries (`LOG_N = 8`,
   `layout.rs:48-49`; E-6). So the two-layer design **reintroduces the new
   table domain that the pure-algebraic route was chosen to avoid**, together
   with its multiplicity planes, helper planes and LogUp entries — for two
   compressions rather than 65,536 of them, but the domain is a fixed cost
   that does not shrink with the count.
6. **Does the untagged BLAKE3 domain matter?** If `StdHash` is BLAKE3, the
   handle's computation shares a primitive with the transcript and the Merkle
   layer, whose 64-byte input domain is already shared and untagged. A
   handle's own tag keeps its inputs out of that set, and SO-4's arithmetic
   shows the transcript *absorption* of a 32-byte handle is 88 bytes and
   safely outside it — but nobody has checked the **gadget's** internal
   inputs against that domain, and "we will pick a tag" is not an asserted
   invariant.
7. **Two further questions a checker should not skip.** Does the inner root
   need its own mask pair and claim site, and does hashing a hidden value
   that is *itself* a hash change anything in the joint-view analysis of
   §4.3 (where the tools are linear and a hash is precisely what they cannot
   see)? And is there any advantage to the attacker in seeing **two**
   functions of the same plane — the outer handle publicly, the inner root
   implicitly — rather than one?

**Status of this section: the security owner's proposal, unchecked and
unpriced by measurement. It is not a design decision, it does not change
PO-1, and nothing here is a privacy acceptance.**

### 1.5 Binding, soundness, and how wide the hash must be over a 64-bit field

**Why collision resistance is load-bearing.** The statement is "the plane
inside my commitment hashes to `h`". If a prover can find `(P', s')` with the
same handle as the sealer's `(P, s)`, it can prove the model's arithmetic on a
plane the regulator never sealed, and the receipt still checks. So the claim
means something **only** to the extent that `H` is collision resistant against
the prover, which is the party with the most to gain and the most compute.
Second-preimage resistance is not enough: the prover chooses both the plane and
the salt.

**And it does not hold as the draft specified the handle** (B-2, S-2).
Collision resistance here is **conditional on three things the draft's
formula omitted**, each of which is cheap to add and none of which is
optional:

1. **the element count**, absorbed before the values, exactly as D7's zkVM
   handle does (`h.update((ELEMENTS as u32).to_le_bytes())`,
   `zkvm-block/statement/src/lib.rs:65-78`). Without a length, planes of
   different sizes collide trivially under any padding rule;
2. **leaf-versus-internal domain separation and a tree-shape encoding**
   (§2.5). Without them a node digest can be reinterpreted as message and
   different trees collide;
3. **a padding rule for a ragged last chunk**, which the draft did not
   specify at all.

Everything below about widths and capacities presupposes all three. Until
they are in the specification, **the binding half of the statement means
nothing**, and no figure in this memo may be quoted as a security property.

**How wide the hash has to be.** These are the project's two relevant numbers.
Per D15 the custom line's per-opening level is about **106 bits** and the
projected whole-8B-proof level is about **94 bits**
(`ZK60_DECISIONS.md:439-467`); the stated target is 128. A sponge over
Goldilocks (`p = 2^64 − 2^32 + 1`, so each element carries just under 64 bits)
with **capacity** `c` elements has collision resistance about `c · 64 / 2` bits
under the standard flat-sponge / indifferentiability bound, and the squeezed
output must be at least twice the target too. The check confirmed the bound's
statement from a public source — *"indifferentiable … up to around `p^(c/2)`
queries; equivalently, to provide κ bits of security, `p^(c/2) ≥ 2^κ`"* — and
confirmed that RPO and Monolith both claim λ = 128 at width 12 / capacity 4,
**with three caveats that travel with it: the bound assumes an ideal
permutation, the real level is `min(capacity bound, digest bound)`, and the
same source also caps κ at `p^(t/3)`** [reported by the independent check from
public sources; not verified by the security owner]:

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
(`layout.rs:259-272`, `argument.rs:474-490`). A lookup's argument is
restricted to a **linear** form over committed planes, so a nonlinear
function of committed values cannot be looked up. Two lookups share one
**helper plane** committed in `H` (`layout.rs:278-279`, `layout.rs:371-379`),
and the helper relation `h·d₁·d₂ − (d₁ + d₂)` is degree 3, which with the
slot's `eq` factor makes a degree-4 zero-check — **the relation is at
`argument.rs:483`** (the draft cited `:596-597`, which is the *comment*
stating the consequence, not the code — E-19) and the SLOTS table lists
degree 4 for every lookup-bearing slot (`layout.rs:438-461`). The
8B pass performs about 2.296 × 10^9 lookups and spends 5.555 s on
"LogUp helpers + commit H". **Lookups are not free here**, and that single fact
decides §2.3 against the lookup-friendly hash designs.

**Two facts about tables that matter a great deal below.** First, a public
table is just a public vector handed to the sumcheck (`Tab::Pub`,
`argument.rs:70`) — but **the draft's "so a table of any size is expressible"
is wrong in this profile** (E-6): tables are pinned to 256 entries,
`LOG_N = 8` / `N = 256` (`layout.rs:48-49`), `Dom::Tab => 8` (`:103`), all
three `table_values_*` emit `N`, and it is checked per slot at
`argument.rs:280-282`. A 2^16-row table exists only on the separate
public-weight FFN path (`zk.rs:1943`), so a larger table here is **a new table
domain, a new digest and a D17-rule-2 additive change**. That bites the
byte-limb hashes of §2.1 and Monolith's Bars layer; Tip5's 256-entry table
escapes it. Second — and this is the important one — **a table may have more
than one column**. The activation table is built as `i + β·act[i] + tag`
(`argument.rs:533-535`) and the exponential table as `i + β·exp[i] + tag`
(`argument.rs:525-527`): the lookup binds the *pair* `(index, value)`, and the
code's comment says binding the pair is a soundness requirement rather than a
preference. **A multi-column lookup table is therefore already the prover's
native way to express an arbitrary small function `y = S(x)`** — which is
exactly what a lookup-based hash S-box is.

**Degree, and the cap the draft missed.** The sumcheck prover and the CFS mask
are generic in the round degree on the **CPU** path (`zkp-core/src/sumcheck.rs:47`,
`:197`, and `masked_prove` at `hashline/src/zk.rs:972`), and the check
confirmed that **no degree cap exists there**. A degree-`d` slot sends
`d + 1` values per round and its mask needs `L = n_vars·d + 2` field
coefficients, which live in two rows of `M` (`M_ROWS = 2·N_SLOTS + 4`,
`layout.rs:519`).

*The budget arithmetic, corrected* (E-5). The draft derived it from "a mask
row holds 256 elements at the tiny profile", which is the wrong geometry: `M`
is a separate commitment with a **fixed** shape — `MASK_LOG_MSG = 9` (512
message positions), `MASK_LOG_DOM = 12`, `MASK_Q = 256` pads
(`zk.rs:373-375`) — **independent of `log_cols`**. So the budget is
`512 − 256 = 256` coefficients, i.e. `n_vars·d ≤ 254`, **identically at
`log_cols` 8 and 14**, where the draft's version predicted it would scale
with the row width. At `d = 7` and `n_vars` 19/20/21, `L` is 135/142/149,
all fitting with 107–121 slots spare; headroom is `n_vars ≤ 36` at `d = 7`,
or `d ≤ 12` at `n_vars = 21`. Today's worst case is `L = 50`
(`layout.rs:519`, asserted `:708`), and the maximum degree in use today is 4.
**The conclusion is unchanged: the prover can express a degree-7 relation on
the CPU today.**

**On the GPU it cannot** (B-5, S-5). The draft wrote *"no cap was found
anywhere in the tree"* and flagged the GPU kernels as "the most likely hidden
cost in the whole memo". **There is a hard cap, and the flag was right:**
`#define SC_DEG 4` at `hashline/src/gpu/kernels.cu:601`, baked into the
kernels' register arrays and shared memory (`kernels.cu:651, 654, 757, 763,
815, 820`) and into `scg_emit<SC_DEG + 1>`, with a degree-3-specialised table
kernel at `hashline/src/gpu/cuda.rs:3152-3160`. **And `private_block` — the
module this memo scopes the gadget into — has no GPU path at all.**
Consequences, which run through every figure below: the **degree-≤4 split
form is the default pricing** (§2.2), and **every GPU-denominated figure in
this memo presupposes a kernel that does not exist** and says so in the same
sentence.

### 2.1 (a) A bit-oriented standard hash (SHA-256, BLAKE3)

**What it would take.** SHA-256 and BLAKE3 are built from 32-bit additions,
XOR, AND and rotations. This prover has none of those: its arithmetisation is
integer arithmetic plus range lookups plus LogUp
(`ZK60_D8_D11_RESTATEMENT.md:940-942`). Each 32-bit word becomes four byte
limbs; XOR and AND of two bytes become one lookup each into a 65,536-row
two-input table (built with the `(index, value)` idiom of §2.0, extended to
`x + β·y + β²·(x⊕y) + tag` over a table enumerating all 2^16 pairs); each
rotation by a non-multiple of 8 becomes, per byte, a split into a high and a
low part with a lookup for each; each 32-bit addition becomes four byte
additions with carry bits that must be pinned boolean and four output bytes
that must be range-checked.

**A table-size limit this route runs into** (E-6). Those 2^16-row tables are
**not expressible in the profile this memo builds in**: tables are pinned to
256 entries — `LOG_N = 8` / `N = 256` (`layout.rs:48-49`), `Dom::Tab => 8`
(`:103`), all three `table_values_*` emit `N`, checked per slot at
`argument.rs:280-282`. A 2^16 table does exist on the separate public-weight
FFN path (`zk.rs:1943`), so this is a profile choice and not a system limit —
but adding it here is **a new table domain, a new digest and a D17-rule-2
additive change**, not something that already works. §2.0's sentence "a table
of any size is expressible" is corrected there.

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
lookups, 56 `G` per compression ⇒ **≈ 3,100 lookups per compression**. So on
this memo's own count the record's 4,000 is a fair central figure *for
BLAKE3* and about 3× low for SHA-256.

**None of those figures is established, in either direction.** The check's
literature lane found **no BLAKE3 arithmetisation cost figure at all** and
**no byte-decomposed SHA-256 AIR figure**; the nearest public anchor is
Zcash halo2's `table16` at ~24 lookups per compression round and ~2,099 rows
per compression, over a 2^16 *spread* table — a different representation from
the byte-limb one used here. So the record's 4,000, this memo's ≈12,800 and
its ≈3,100 are all **unverified** and must be labelled that way wherever they
are quoted (check §3.4).

**Reproducing the record's arithmetic** at Mistral width, so the comparison in
§3 is like-for-like: 2^21 int16 words = 4,194,304 bytes = **65,536
compressions per endpoint**; at 2,500 committed words each that is 1.638 × 10^8
committed words = **1.68% of the pass's 9.777 × 10^9 per endpoint (3.35% for
two)**, and at 4,000 lookups each, 2.621 × 10^8 lookups = **11.4% of the pass's
2.296 × 10^9 per endpoint (22.8% for two)** [COUNTED; identical to the earlier
check's `counts.out`, `ZK60_D8_D11_RESTATEMENT_CHECK.md:550-552`]. Turned into
a relative time cost that is the **+5.5% public** figure in D18 — which
follows from this basis — and the **+12.6% private** figure, which **has no
published derivation, could not be reproduced by the check from any published
denominator, and is recorded in the register as unverified** (C-6).

**What recommends it.** Only one thing, but it is not nothing: the project
already depends on BLAKE3 for its transcript and Merkle trees
(`zkp-core/src/transcript.rs:44-52`), and using it for the handle too adds **no
new cryptographic assumption at all**. The draft added that a SHA-256 handle
would be **bit-identical to D7's zkVM handle**; **that is false** (E-16). D7
does `for v in values { h.update(v.to_le_bytes()) }` over two's-complement
`i16`s in order and additionally absorbs a model digest and the element
count, while the native packing is interleaved offset-binary over two limb
planes (§3.1). Interoperability therefore needs a **matched packing as well
as a matched hash**, and a matched packing gives up the free byte limbs. See
PO-2.

**Verdict.** Keep it as the conservative alternative — and note that PO-1 now
recommends no hash at all, so "conservative alternative" means a live option
and not a fallback. On the record's unverified per-compression figures it is
an order of magnitude above the algebraic candidates in committed volume
(≈156 committed values per absorbed element against 12.00 and 14.75, §2.7),
and it is the only candidate that adds hundreds of millions of lookups and a
new 2^16 table domain.

### 2.2 (b) An algebraic permutation over Goldilocks

**Why this is the natural fit.** The prover's words already *are* Goldilocks
elements. An algebraic hash's round function is a low-degree polynomial map
over the same field, so every relation it needs is a zero-check term of the
kind the prover writes all day, and **it needs no tables and no lookups at
all**.

**The S-box.** Over `p = 2^64 − 2^32 + 1`, `p − 1 = 2^32·(2^32 − 1) =
2^32 · 3 · 5 · 17 · 257 · 65537`. So `x³` and `x⁵` are **not** permutations
(3 and 5 divide `p − 1`), while 7 divides neither factor, and **`x⁷` is the
smallest permutation power** [COUNTED — the factorisation is elementary;
**independently confirmed by the check**, which recomputed
`gcd(3, p−1) = 3`, `gcd(5, p−1) = 5`, `gcd(7, p−1) = 1`]. The draft added
*"that is why every Goldilocks design in the literature uses `x⁷`"*, which is
**false as stated** (E-4): Monolith-64's Bricks layer is degree 2, and its
nonlinearity is the lookup Bars layer.

**The candidates, written from the drafter's memory and since checked against
public sources.** None of this is from this repository. **The independent
check confirmed the parameters this memo's costs rest on** — Poseidon2
Goldilocks width 12 at `R_F = 8`, `R_P = 22` from four independent sources,
118 S-box applications per permutation, the `x⁷` S-box, and capacity 4 giving
the claimed ≈128-bit collision level **with the caveat that the bound assumes
an ideal permutation**. It contradicted the comparison figures in §2.3 and
§2.7 (E-1, E-2, E-3) and the claim above about `x⁷` (E-4). One footnote for
anyone re-deriving: re-deriving `R_P` from the Poseidon2 paper's Eq. (1)
first term alone gives 21, not 22 — the published value comes from the
Gröbner branch of the maximum. Not a defect; a trap.

| design | authors, as I recall | Goldilocks parameters, as I recall | structure | cryptanalysis status, as I recall |
|---|---|---|---|---|
| **Poseidon** | Grassi, Khovratovich, Rechberger, Roy, Schofnegger (USENIX Sec. 2021) | width 8 and 12; **8 full + 22 partial rounds** at width 12, S-box `x⁷` (Plonky2's instance) | partial-SPN: `x⁷` on all elements in full rounds, on one element in partial rounds, MDS linear layer | the most deployed algebraic hash; extensive Gröbner-basis/CICO analysis; round counts carry a published margin |
| **Poseidon2** | Grassi, Khovratovich, Schofnegger (2023) | same widths and, I believe, the same 8 + 22 at width 12 | Poseidon with a cheaper, structured linear layer | inherits Poseidon's analysis; the linear-layer change was argued not to affect the algebraic bounds |
| **Rescue-Prime / RPO** | Aly, Ashur, Ben-Sasson, Dhooghe, Szepieniec; RPO used by Polygon Miden | width 12, capacity 4, **7 rounds**, `x⁷` and `x^{1/7}` | each round applies `x⁷` then `x^{1/7}`; the inverse direction is cheap as a *constraint* (`y⁷ = x`) | the cleanest published design rationale and round-count formula; conservative |
| **Monolith** | Grassi, Khovratovich, Roy, Rechberger, Schofnegger (2023/24) | width 8 and 12, **6 rounds** | lookup "Bars" layer on limbs + degree-2 "Bricks" + MDS "Concrete"; designed for lookup provers | newer; some third-party analysis; less settled than Poseidon |
| **Tip5 / Tip4** | Szepieniec, Lenngren and co-authors; Triton VM | width 16, **5 rounds**, rate 10 / capacity 6 | split-and-lookup S-box (256-entry table on 4 bytes of 4 elements) plus `x⁷` on the other 12 | newest of the set; least third-party analysis |
| **Reinforced Concrete** | Grassi, Khovratovich, Rechberger, Roy, Schofnegger (CCS 2022) | **not a Goldilocks design** — built for ~256-bit primes (BN254/BLS) | Bricks–Concrete–Bars with a lookup layer | the ancestor of Monolith/Tip5's lookup idea |

The drafter's own flag — *"I would not stake a security claim on the 8 + 22
above"* — was checked and the round counts stand (above). The families, the
S-box exponent and the sponge shapes stand too. The **cost** figures did not;
see §2.7.

**Cost in this prover, worked out.** Take Poseidon2 at width 12, rate 8,
capacity 4. Per permutation: `8 × 12 + 22 × 1 = ` **118 S-box applications**.
Two ways to constrain one S-box:

* **degree 7 directly**: commit only `y`, and assert `y = x⁷` where `x` is a
  *public linear form* of values already committed. One committed value per
  S-box; the slot's degree becomes 7 (8 with the `eq` factor).
* **degree ≤ 3 with an intermediate — the split form**: commit `t = x³` and
  `y = t²·x`. Two committed values per S-box; the slot stays at **degree 4**
  (`t = x³` is degree 3, `y = t²·x` is degree 3, ×`eq` = 4), the degree the
  layout already uses.

**The split form is the default, and the draft chose the other one without
knowing why it could not** (B-5, S-5). On the CPU either fits: the check
confirmed there is **no degree cap on the CPU path**, and at `d = 7` with 19
to 21 variables the CFS mask length `L = n_vars·d + 2` is 135 to 149 against
a 256-coefficient budget. **On the GPU the degree-7 form does not fit at
all**: `#define SC_DEG 4` (`hashline/src/gpu/kernels.cu:601`) is baked into
the kernels' register arrays, their shared memory and `scg_emit<SC_DEG + 1>`,
with a degree-3-specialised table kernel beside it
(`hashline/src/gpu/cuda.rs:3152-3160`). A degree-8 slot needs 9 coefficients
per round against today's 5, so the per-thread register and shared-memory
footprint roughly doubles on kernels already tuned to an 8 GiB card that
**freezes the whole box when it spills**. And the module this memo scopes the
gadget into has **no GPU path at all** (`grep gpu` over
`hashline/src/private_block/` is empty).

So: the split form keeps every existing kernel at the price of **two
committed values per S-box** — 29.5 per absorbed element for Poseidon2, 24.0
for Rescue-Prime Optimized — and the check's comparison, using the project's
own measured host/GPU ratio of `7.62×` for the private feed-forward at
12×512, makes **the split form win by roughly 3.8×** on the measured numbers.
The degree-7 form is reinstated only if a degree-8 CUDA kernel is written and
measured (§6 M1b). The draft's reason for preferring degree 7 — that
committed volume dominates while sumchecks are a small share of the pass
(matmul sumchecks 5.533 s and zero-checks F+D 5.468 s of 58.40 s) — is not
wrong about the currencies; it is wrong about which of them the hardware
lets you spend.

The linear layers and the round constants are public, so between S-boxes
nothing needs to be committed: the input of the next S-box is a public linear
combination of the initial state and of every S-box output so far. That gives
the **118 committed values per permutation** used in §3 for the degree-7 form
(236 in the split form), and it has a cost of its own — see layout A in §3.2,
whose linear forms grow to ~130 terms and make the sumcheck's own evaluation
an item the draft's headline omitted entirely (E-11).

**No lookups, no tables, no new range facts** — on the tiny profile, whose
endpoint limbs already exist. On the layer prover the input endpoint is not
byte-decomposed at all, so the packing is not free there and the lookup
column is no longer zero (E-15, §2.6). Against §2.1's lookup bill for a
byte-limb hash, a zero or near-zero lookup column is still the single biggest
difference between the two families.

### 2.3 (c) A lookup-friendly design

Monolith and Tip5 replace part of the algebraic S-box with a small table
lookup, precisely to be cheap in provers whose lookup argument is free. This
prover's lookups are **not** free: each is a committed helper plane in `H`, the
8B pass already spends 5.555 s on helpers and commit H, and the check's
arithmetic treats added lookups as the more expensive of the two currencies.

The draft's counts here were recalled and are **corrected by the check**
against Monolith Table 4 (E-2, E-3), and they move in the unfavourable
direction for these designs: **Monolith-64** width 12, rate 8, 6 rounds is
**24.0 lookups and 60.0 committed values per absorbed element** (witness 480 ÷
rate 8; the draft's ≈38 was Tip5's number transposed, `380 / 10`). **Tip5** is
**width 16, rate 10, capacity 6** — not the w12/r8/c4 the draft costed it at —
at **16.0 lookups and 38.0 committed values per absorbed element**; its lookup
figure was right only because the rate is 10. The width-12 member of that
family is **Tip4′**, at 20.0 lookups and 45.0 committed values. All four
figures are [reported by the independent check from public sources; not
verified by the security owner].

Against Rescue-Prime Optimized's **12.00** and Poseidon2's **14.75** committed
values per absorbed element with **zero lookups** (§2.7), the lookup-friendly
designs are **more expensive in committed volume here, not merely equal**, and
they add a lookup bill the pure-algebraic route does not have. They also add a
second table domain, its multiplicity planes, its helper planes, and their
entries in the LogUp identity — all of which are new rows and new claim sites.
Monolith's 2^16-row Bars table additionally hits the 256-entry table limit of
this profile (E-6, §2.0); Tip5's 256-entry table does not.

**Verdict:** a lookup-friendly hash is the right choice in an AIR with a free
lookup argument, and the wrong choice here. Note that the draft kept Monolith
on the list as the fallback *"if the degree-7 zero-check turns out to be much
more expensive in the GPU kernels than §2.0 assumes"*. **That contingency has
now occurred** — the CUDA zero-check is capped at degree 4 (§2.0, B-5) — but
the answer to it is the degree-≤4 **split form** of the algebraic S-box
(§2.2), which keeps every existing kernel at 2 committed values per S-box, and
not a lookup design at 24 lookups and 60 committed values per element.

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

### 2.5 (e) A tree rather than a sponge, and what it really costs

**The finding, restated after the check overturned half of it.** A sponge hash
is sequential: `state_{i+1} = perm(state_i + absorbed_i)`. In an AIR that is a
transition constraint between consecutive rows, and it is free. **This prover
is not an AIR.** It is a multilinear sumcheck prover, and its claim points are
built from fixed, flipped or challenge coordinates only — `Coord::Rho`,
`Coord::Flip`, `Coord::Fixed` (`argument.rs:48-53`). **Confirmed by the
independent check**: no `i → i+1` relation exists anywhere in `hashline/src`
or `zkp-core/src`, and every candidate the draft named turns out to be
something else (the causal mask is a public table over two independent
variables; the softmax row sum is a whole-axis sum; byte-limb recomposition
is across separate planes at the same index).

**Two things the draft concluded from that are withdrawn.**

* *"A linear sponge cannot be expressed in this prover without a new
  primitive"* — **overstated** (E-7). A shift is **not implemented**; it is
  not excluded by the arithmetisation. The sumcheck prover is table-generic
  (`zkp-core/src/sumcheck.rs:47-131`), the PCS's linear test already accepts
  an **arbitrary column-weight vector** (`zkp-core/src/pcs.rs:976`), and the
  project's own `MaskFunctional` already uses arbitrary weights
  (`hashline/src/zk.rs:394-398`). The eq-only restriction lives only in
  `zkey_weights` (`pcs.rs:794-805`) and in `ZPart` carrying a `point`
  (`:719-725`). Adding a shifted access is a new access mode in
  `priv_table`/`table_of`, a weight-vector `ZPart` variant and a matching
  arbitrary-weight `mask_eval` (`argument.rs:210-219`) — **an additive change
  of exactly the kind D17 rule 2 contemplates**, not a new primitive class.
* *"A binary tree is forced, doubling permutations"* — **false** (B-4, S-1),
  and it was the draft's most emphasised structural claim. See "what the tree
  costs" below.

What *is* expressible today without any new access mode is a split on a
coordinate: a plane's values at even and at odd positions are the plane's
multilinear extension with its last variable fixed to 0 and to 1 — exactly
`Coord::Fixed`, and the check confirmed the parent–child wiring is
expressible (`priv_table` builds `eq_table_msb(&fixed)`,
`argument.rs:163-182`). So a **hash tree** fits natively:

* **leaves**: partition the packed plane into chunks of `rate` field elements
  and hash each chunk independently — one permutation each, all parallel.
* **internal nodes**: each node absorbs its two children's digests. With a
  4-element digest and rate 8, **one 2-to-1 compression is exactly one
  permutation**, and the parent–child wiring is the even/odd split above.
* **root**: squeeze 4 elements; that is `h`.

**The salt goes in the capacity of every node, not in one leaf's message**
(C-1). The draft put the salt and the tag/context/role into the leftmost leaf
(or a dedicated initial-value block). Only the root is public, so that is not
broken from public data — but it leaves **every leaf except the first an
unsalted hash of a 32-byte chunk of an activation plane**, whose secrecy then
rests entirely on the PCS-hiding hypotheses this project has not discharged
(H-pad, H-pair, H-prox, the `ZkRng` PRG assumption, salted-leaf hiding of
unopened columns). A failure anywhere in that stack degrades **chunk-locally
and irreversibly** — one leaked internal digest is a 32-byte dictionary
attack against highly structured data — and it makes **equal chunks
detectable**: two planes sharing a 32-byte chunk produce an identical leaf
digest. **The fix is free.** Put the salt in the **capacity (initial value)
of every node**: capacity is 4 Goldilocks elements = 256 bits, exactly the
salt's width, and it is initialised to a constant today, so keying every node
costs **zero extra permutations**. Domain separation and the node index move
into the rate or the round constants. (Absorbing the salt as *message* into
every leaf would instead consume 4 of the 8 rate elements and double the
permutation count; the draft costed neither option.) Under §1.4's two-layer
direction this question disappears entirely, because the inner hash is then
computed with no secret at all.

**What the hash input must encode besides the message** (B-2, S-2). A tree
hash needs **leaf-versus-internal domain separation** and a **shape
encoding** — Sakura-style discipline — or a node digest can be reinterpreted
as message and different trees collide; and it needs a **padding rule for a
ragged last chunk**. The draft specified a binary tree with none of these,
and its sentence *"the tree is domain-separated and salt-dependent from the
first compression"* is about the **message** domain tag and supplies neither.
Together with the **element count** (§1.1), these are what make the binding
half of the statement mean anything (§1.5).

**What the tree costs: `1 + 1/k`, with `k` free — not a factor of two**
(B-4, S-1). The draft's doubling was an artefact of choosing leaves that
absorb **one** rate block each: a complete binary tree over `L` one-block
leaves has `L − 1` internal nodes and `2L − 1` permutations. **Unroll `k`
sequential absorptions inside one leaf** and the doubling collapses:
permutation `j` of leaf `i` is its own plane family, chained to permutation
`j+1` **at the same hypercube index `i`**, reading message elements at a
constant offset inside the chunk — `log2(8k)` variables pinned by
`Coord::Fixed`. No shift, no gather, no new primitive.

| `k` permutations unrolled per leaf | permutations against a linear sponge |
|---:|---:|
| 1 (the draft's tree) | **2.000** |
| 2 | 1.500 |
| 4 | 1.250 |
| 8 | 1.125 |
| 64 | 1.016 |

[RECOMPUTED by the independent check, `corrected_model.py` §2.] The price of
the missing shift is therefore `1 + 1/k`, traded against `k` extra plane
families; the check finds the optimum near `k = 2…4` once claim sites are
counted. **Every "doubled" figure in the draft is withdrawn on this account**,
including its proposed correction to the register (§2.7, SO-7).

**The wiring question, and which form §3 prices** (B-6, S-6). Levels differ
in size, and a level index is a third axis. Two ways to handle it:

* *level-wise plane families*: one family of planes per tree level. No new
  access mode; but the number of claim sites **multiplies by the depth** —
  2,124 at Mistral, 1,770 at 125M, 708 at the tiny shape (§3.2), and claim
  sites are 2 committed rows each (§2.0(iii)).
* *one family with a level axis*: the level axis has at most 18 values, so the
  level-to-level wiring is a **public 32 × 32 shift table** handed to the
  sumcheck as an ordinary `Tab::Pub`. This costs padding (levels are ragged,
  and nobody has counted that padding) but keeps the site count flat.

**§3 now prices the level-wise form throughout, consistently.** The draft said
it priced the level-wise form and then priced 128 flat sites at every shape,
which is the *other* option; that contradiction was the memo's largest cost
error and it is corrected in §3.2 and §3.4. Which form is actually cheaper is
unmeasured, and it is **measurement M0** — a four-leaf tree in the layout
builder alone, which prints its own site and row counts in hours and proves
nothing.

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
cannot wrap. **On the tiny `private_block` profile the packing therefore needs
no new lookup, no new table and no new range argument** — it is a public
linear form over values the proof already commits and already range-proves.
Both citations were verified by the independent check, and so was the
injectivity.

**"Free" is true of one profile and false of the one the costs are quoted
against** (E-15). The byte limbs above exist in the **tiny `private_block`
profile**. The 125M and Mistral figures of §3.4 are quoted against the
**layer prover**, and D12 item 4 records, as a fact the security owner
re-checked in source, that *"the feed-forward prover proves no range on its
own input"* — the lookup list covers the activation, the two int16 planes and
the output, **never the input plane** (`hashline/src/layer.rs:11-14`). So on
the path the costs are quoted against, **the input endpoint has no byte
decomposition and the packing is not free**. The arithmetic cost of adding it
is small: 2 limb planes per int16 word, at Mistral `2 × 2,097,152 =
4.19 × 10^6` committed words and `2.10 × 10^6` lookups per endpoint —
`+0.04%` of the pass's words and `+0.09%` of its lookups [RECOMPUTED by the
check]. The **structural** cost is larger than the arithmetic one: it puts
the gadget's lookup column **above zero**, and a zero lookup column is the
single claim §2.7 uses to beat the bit-oriented candidates.

### 2.7 Side by side, and what the verifier has to compute

Per **absorbed Goldilocks field element** — 4 bytes of plane data (§3.1) —
**undoubled**: the tree overhead is `1 + 1/k` with `k` free (§2.5, B-4), so it
is applied once, separately, and not baked into these rows as the draft's
factor of two was. The algebraic rows are the check's corrected figures
[reported by the independent check from public sources; not verified by the
security owner], each Monolith Table 4's witness size ÷ rate — **not a
published metric**, and Monolith calls its own arithmetisations
*"non-optimized … subject to change"*. The byte-hash rows are the record's
central per-compression figures, which **no public source could confirm in
either direction** (check §3.4).

| candidate | lookups / absorbed element | committed values / absorbed element, **degree-7 form** | committed values, **default split form** (B-5) | new tables | slot degree | note |
|---|---:|---:|---:|---|---|---|
| SHA-256, byte-limb (record's central per compression) | ≈ 250 [unverified] | ≈ 156 [unverified] | n/a (already degree ≤ 4) | 2^16-row XOR, AND, split tables — **a new table domain this profile does not have** (E-6) | 4 | *not* bit-identical to D7's handle (E-16, PO-2) |
| BLAKE3, byte-limb (the draft's count) | ≈ 195 [unverified] | ≈ 125 [unverified] | n/a | same | 4 | no new cryptographic assumption; already the project's hash |
| **Rescue-Prime Optimized w12 r8 c4** | **0** | **12.00** | **24.0** | none | 7 → **4 in the split form** | 96 degree-7 constraints per permutation; the inverse S-box is *verified*, not evaluated; carries an uncounted host-side `x^(1/7)` cost (PO-1) |
| **Poseidon2 w12 r8 c4, `x⁷`** | **0** | **14.75** | **29.5** | none | 7 → **4 in the split form** | 118 S-box applications per permutation, confirmed from four public sources |
| Monolith-64 w12 r8, 6 rounds | **24.0** | **60.0** | n/a | one 2^16-row table + helpers — a new domain | 2–3 | pays a lookup bill this prover charges for, and costs the most committed volume of the set |
| Tip5 **w16 r10 c6**, 5 rounds | **16.0** | **38.0** | n/a | one 256-row table + helpers | 7 | the lookup figure is right only *because* the rate is 10; the draft had the geometry wrong (E-3) |
| Tip4′ w12 r8 | 20.0 | 45.0 | n/a | same | 7 | **this**, not Tip5, is the width-12 Tip variant |

Arithmetic for the byte-hash rows: 4,000 lookups and 2,500 committed words per
64-byte compression, and 64 bytes is 16 absorbed elements, gives 250 and 156
per element in a linear chain. For Poseidon2: 118 committed values per
permutation ÷ rate 8 = 14.75. For Rescue-Prime Optimized: 96 ÷ 8 = 12.00.
**The draft's row for Rescue-Prime (≈42) was 3.5× too high** — it counted raw
S-box *evaluations* (`2·7·12 = 168`) where the arithmetisation verifies the
inverse half rather than evaluating it (E-1); **Monolith's ≈38 was Tip5's
number transposed** (E-2); and **Tip5's row was costed at the wrong geometry**
(E-3). Corrected, **Rescue-Prime Optimized is 0.81× Poseidon2 on committed
volume, not 1.4×** — which inverts the draft's recommendation and is why PO-1
now recommends no hash at all (B-8, S-7).

> **The draft's proposed correction to the register is WITHDRAWN** (B-4, S-1).
> It read: *"the honest SHA-256 figure for this prover is therefore double the
> one on the books … the absolute SHA-256 cost in D18 is understated by 2×."*
> That rested on the claim that this prover cannot express a sequential chain
> and so forces a binary tree. **The claim is false**: unrolling `k`
> absorptions inside one leaf uses only `Coord::Fixed` and costs `1 + 1/k`
> with `k` free (§2.5). On D18's own per-compression basis the corrected
> figure is **+5.6% to +6.2%** of a public pass at `k = 64…8`, against D18's
> recorded **+5.5%** [RECOMPUTED by the check] — so D18's public number is
> right to within about 13% on this account, and **nothing here restates it**.
> What survives is a *separate and unapplied* observation: this memo's own
> byte-limb count of SHA-256 (§2.1) is ≈12,800 lookups per compression against
> the record's 4,000, which on a linear chain would give about **+10.3%** of a
> public pass. The near-agreement between that and the draft's withdrawn
> "+11%" is a coincidence of two unrelated errors. And since the check could
> confirm **no** byte-hash arithmetisation figure in either direction, neither
> 4,000 nor 12,800 is established. See SO-7 for what the register now says.

**What the verifier computes: nothing extra of its own.** The verifier never
evaluates the hash. `h` is 32 public bytes in the statement, absorbed into the
transcript like every other public field. The gadget reaches the verifier only
as (i) more rows in the commitment it already checks — so its per-column work
and its Merkle path work grow in proportion to the added rows, which on the
corrected band of §3.4 is a low single-digit percentage of the `A`-side rows
at 8B and much more at smaller shapes (the draft's "+2%" rested on the
withdrawn flat site count) — and (ii) a few more sumcheck rounds and terminals,
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
tables, no new range facts** — on the tiny `private_block` profile; the layer
prover does not range-prove its input plane at all, so there the limbs must
be added (§2.6, E-15).

**Injectivity holds, and the check verified why.** The values are signed
int16 mapped by **offset binary / excess-32768, not two's complement** (the
literal `k(32768)` plus two `U8` range checks *is* the int16 class statement,
`layout.rs:288-290`). Offset binary over `[−32768, 32767]` is injective, four
bytes reach `2^32 − 1 < p`, so `pack` is injective and cannot wrap
[RECOMPUTED by the check].

**But this map must be pinned by the statement version, and it is not D7's**
(C-4, E-16). The packed element above interleaves the *low* bytes of two
consecutive words with their *high* bytes — an artefact of reading two limb
planes at an even and an odd index — which is **not** the natural
little-endian serialisation of two int16s and **not** what the zkVM line
does (`zkvm-block/statement/src/lib.rs:65-78` walks two's-complement `i16`s
in order). The module contains at least **three** different signed byte
encodings: `l2`'s offset-32768 for int16, `sym(p)`'s pair `v + 127` and
`127 − v` for int8 (`layout.rs:274-276`), and `g8`'s offset-128 from the
activation table (`argument.rs:777`). **The statement version must name which
map, which limb order and which tiling**, or the sealer and the prover
disagree silently and the handle simply never matches. M3's independent
Python reference must exercise exactly that map.

**Above the tiny shape the tiling itself changes** (C-5). D17 rule 1 requires
any entry point accepting a non-tiny shape to bind the whole plane through
the batched multi-block seam, so the endpoint plane is **re-tiled** — and the
packing's index order is a function of the tiling. The sealer has no proof, no
layout object and possibly no Rust. The draft said only "in a fixed order";
that is not enough. The tiling, the limb order and the offset constant must
be pinned by the statement version, or **a third party cannot reproduce the
handle at all**, which is the entire point of the construction.

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

| layout | what is committed per permutation | committed values (degree-7 form) | claim sites, **level-wise, as priced** | longest linear form |
|---|---|---:|---:|---|
| **A** | every S-box output only | **118** | **2,124** Mistral / **1,770** 125M / **708** tiny | ≈ 130 terms |
| **C** | S-box outputs + the 12-element state at ~10 round-block boundaries | **238** | same | ≤ 34 terms |
| **B** | the full 12-element state every round, padded to a 512-wide `(round, element)` axis | **512** | ≈ 12 per level | ≤ 12 terms |

In the **default split form** (B-5) the committed-value column doubles: 236,
476 and 1,024 respectively, two committed values per S-box, in exchange for a
slot that stays at degree 4 and therefore keeps every existing CUDA kernel.

**The claim-site count is corrected, and it was the memo's largest error**
(B-6, S-6). The draft priced **128 sites flat at every shape** while its own
§2.5 said that the form it was pricing — level-wise plane families —
multiplies sites *by the tree's depth*. Both cannot be true. Priced
consistently in the level-wise form, a 131,072-leaf Mistral tree has 18
levels and **2,124** sites, the 125M tree has **1,770** and the tiny tree
**708** [RECOMPUTED by the check, `corrected_model.py` §3]. The per-site rule
itself is unchanged and is an estimate from the existing idiom: `SC_DZC`
declares 37 `A` sites for a slot that sweeps about 29 contiguous planes plus
extras (`layout.rs:512`, `argument.rs:708`), so "roughly one site per plane
opened at one point" is the rule, and each site is 2 mask rows (§2.0(iii)) —
**which are committed rows, and therefore cost volume as well as bytes**
(E-8). What a real layout builder actually demands is unmeasured and is
**measurement M0**, the first step of the plan.

**What that does to the ranking.** At Mistral width the gadget's plane is
2^21 words, so committed volume still dominates and layout A is still the
volume floor — but one endpoint's proof bytes go from 4,390,912 to
**12,566,528 (×2.86)**. At 125M they go from 1,249,280 to **7,974,912
(×6.38)**. At the tiny shape the whole tree is 63 permutations — 7,434 values,
30 rows — while 708 sites cost 1,416 rows, so sites dominate completely and
one endpoint's layout-A gadget reaches **2,961,408 bytes, 105% of the whole
2,816,472-byte receipt**. The inversion between shapes is real and is the
single most important thing to know before reading a tiny-shape measurement
as if it predicted model scale. It is also the trap this project has fallen
into three times this week: *"Three counted step sizes out of three shrank by
a factor of three to seven when measured"*
(`ZK60_FIVE_SECOND_PLAN.md` §5, third correction) — and this memo fell into a
fourth version of it by pricing the optimistic branch of its own text.

**No layout is recommended here; M0 then M1 decide.** The draft recommended
layout C on the fourth column: layout A's zero-check evaluates 118
polynomials each built from a ~130-term public linear form, at 8 evaluation
points, for every permutation — at Mistral **≈ 4.66 × 10^10 Goldilocks
multiply-adds per endpoint**, against layout C's **≈ 2.67 × 10^10**
[RECOMPUTED by the check; the draft's own figure for A was 3.2 × 10^10 from
the same structure]. At 10^10–10^11 field operations per second that is
**+0.5 to +4.7 s per endpoint** in A and **+0.3 to +2.7 s** in C — an item the
draft computed and then left out of its headline (E-11). So layout A is the
volume floor and not the time floor, exactly as the draft said; but the
choice between them is now dominated by the site count, which neither the
draft nor the check has measured.

### 3.3 The counts, shape by shape

**The model, stated once, and corrected.** Permutations for a plane of `n`
words of `b` bytes each: absorbed elements `n_abs = n·b/4`; leaves
`L = ⌈n_abs / (8k) ⌉` when `k` absorptions are unrolled per leaf; **total
permutations `= (1 + 1/k) × n_abs / 8`** (§2.5, B-4) — *not* the `2L − 1` of
a one-absorption-per-leaf tree, which is only the `k = 1` corner of that
family and the most expensive one. Committed values `= (118 | 238 | 512) ×
permutations` in the degree-7 form, **doubled in the default split form**
(B-5). Rows `= ⌈values / 2^log_cols⌉` with `log_cols` 8 at the tiny shape and
14 at the 125M and Mistral shapes. Proof bytes `= (data rows + 2 × sites)
× 2,048`, **and the `2 × sites` mask rows are committed rows too**, so they
count in volume as well as in bytes (E-8) — the draft counted them only in
bytes. Everything below is **[COUNTED]** from that model; the model itself is
[MODEL], and the permutation's 118 S-box applications are now **confirmed
from four public sources by the independent check** (§2.2, §7.4).

**One endpoint plane, by shape and layout — at `k = 1`, the worst corner, and
at the draft's flat site count, which is wrong.** The table is kept because
its volume column is the arithmetic everything else is built on, and the
check reproduced every cell of it exactly from the stated model. **Two things
in it are superseded**: the permutation count is the `k = 1` corner (at
`k = 4` the Mistral leaf count falls from 131,072 to 32,768 and the total from
262,143 to 163,839 [RECOMPUTED by the check]), and the proof-byte column uses
128 flat claim sites, which §3.2 now corrects to 2,124 / 1,770 / 708. Read the
band in §3.4, not these single figures.

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

(The tiny row uses 256-wide rows; the other two use 16,384-wide rows. The
sites column behind the proof-byte figures is the draft's **128 flat for
layouts A and C, 12 for B — superseded**; with level-wise families the counts
are 2,124 at Mistral, 1,770 at 125M and 708 at the tiny shape, and the
corresponding proof bytes are 12,566,528 / 7,974,912 / 2,961,408 for one
endpoint [RECOMPUTED by the check].)

**A complete private block's two external endpoints** (D12 item 2: one proof,
one transcript, `x_in` and `xres2`) is exactly twice the relevant row, since
the two planes have the same shape. At Mistral width, layout A, `k = 1`,
flat sites: 61,865,748 committed values, 4,288 rows, 8,781,824 proof bytes —
the **bottom** of the band, and the band's top at level-wise sites is
25.1 MB of proof and 2.06% of the pass's committed words (§3.4).

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

**Label the denominators, because the draft mixed them** (E-12). Committed
words and prove seconds below are against the **public** 8B pass (58.40 s,
9.777 × 10^9 words); proof bytes are against the **private** 1.286 GB proof.
They are different objects, and **no figure here may be compared with D18's
"+12.6% private"** — which is public-against-private, and whose base has no
published derivation in any case (C-6).

**Two external endpoints, as a fraction — the corrected band.** The draft's
single-point figures are withdrawn (E-8, E-9, E-10, E-13). The band below is
**[RECOMPUTED by the independent check]** (`results/zk60_sealed_handle_check/
corrected_model.py`, `.out`). Its low end keeps the draft's own 128 flat claim
sites and adds only the mask rows those sites cost; its high end uses the
level-wise site counts the memo's own §2.5 implies (2,124 at Mistral, 1,770 at
125M, 708 at the tiny shape, §3.2). Both ends use Poseidon2 in the degree-7
form; Rescue-Prime Optimized is 15–20% cheaper throughout.

| quantity | draft said | **corrected band** | what drives it |
|---|---|---|---|
| Mistral, committed volume (public pass) | 0.63% | **0.72% – 2.06%** | claim sites |
| Mistral, prove seconds from volume alone | +0.37 s | **+0.42 – +1.20 s** | claim sites |
| Mistral, **the gadget's own zero-check** | *not counted* | **+0.5 – +9.3 s** | degree-7 sumcheck, layout |
| Mistral, proof bytes (private proof) | 8.78 MB (0.68%) | **8.78 – 25.1 MB (0.68% – 1.95%)** | claim sites |
| 125M, committed volume (private pass) | 4.29% | **7.4% – 50%** | claim sites |
| 125M, prove seconds **if the slot runs on the GPU** | +0.20 s | **+0.34 – +2.39 s** | claim sites |
| 125M, prove seconds **if the slot runs on the host** | *not counted* | **×7.62 of the above** | `SC_DEG 4`; no GPU path in `private_block` |
| 125M, proof bytes | 2.50 MB (2.83%) | **2.50 – 17.3 MB (2.83% – 19.6%)** | claim sites |
| tiny, **one** endpoint, proof bytes | 585,728 B (20.8%) | **585,728 – 2,961,408 B (20.8% – 105% of the 2,816,472 B receipt)** | claim sites |
| added lookups, any algebraic candidate, any shape | 0 | **0 on the tiny path; above zero on the layer path**, where the input endpoint's byte limbs must be added (E-15) | packing |

**Every GPU-denominated figure in this table presupposes a CUDA zero-check
kernel that does not exist** (`#define SC_DEG 4`,
`hashline/src/gpu/kernels.cu:601`; `private_block` has no GPU path at all).
Under the default split form (B-5) the committed values per absorbed element
double — Poseidon2 29.5, Rescue-Prime Optimized 24.0 — so the volume-driven
half of each row roughly doubles while the site-driven half does not; the
exact combination depends on how many planes the split form adds, which is
what M0 prints [MODEL, unverified].

**The three readings that matter.**

1. **At 8B the gadget is between a half and two per cent of the pass's
   committed words, plus a zero-check that has never been counted before and
   may be several seconds on its own.** The draft's sentence *"about +0.6% to
   +1.3% of an 8B pass"* is withdrawn as a headline: it was the bottom of the
   band, it counted no mask rows, it omitted the gadget's own sumcheck, and it
   was quoted in the layout the draft then declined to recommend. It also may
   not be set against D18's +12.6% private, for the two reasons above.
2. **The relative cost grows sharply as the model shrinks**, because the
   endpoint plane is a fixed slice of a pass that gets smaller: about 1–2% at
   Mistral, **7% to 50%** at 125M, and **up to the whole receipt** at the tiny
   shape, where one endpoint's gadget in layout A with level-wise sites is
   105% of the 2,816,472-byte receipt. Every proportional statement must name
   its shape. This is the same direction the record already found for SHA-256
   (+38% of the tiny lookups against +23% at model scale,
   `ZK60_D8_D11_RESTATEMENT.md:970-974`).
3. **The 64-endpoint vehicle is a different animal**: on the draft's own
   (understated) volume model it was 15.2% of the 8B pass's committed volume
   in layout A, about +8.9 s on 58.40 s, and 30.6% and +17.9 s in layout C;
   under the corrected site counts it is worse. If the project ever prices
   that vehicle with handles, it must be priced separately and it must keep
   D17's naming.

**One caveat in the unfavourable direction**, of the kind correction 11 asks
for (`ZK60_D8_D11_RESTATEMENT_CHECK.md:827`). These are relative costs, so if
the pass ever reaches 5 s by getting the same work cheaper, the gadget is
discounted with it. But if the speed comes from a change that does **not** help
the gadget — a lower encoding rate or a 31–32-bit field under D14 — the
absolute seconds stay. On the field question the draft overstated the coupling
and the corrected statement is SO-6's (E-18): a 31–32-bit field does **not**
break the `x⁷` S-box (`x⁷` permutes BabyBear too) and does not break the
approach; it invalidates the *instance*, and it costs — 128-bit collision
resistance needs capacity ≥ 9 elements at 31 bits against 4 at 64, plausibly
**2–3× the gadget per absorbed element** [RECOMPUTED by the check].
**A D14 field change and this gadget must still be decided together**, and
that coupling is a cost, not a wall.

### 3.5 For each number, the first measurement that would settle it

Three counted speed estimates in this project shrank or grew three- to
sevenfold this week when they were measured
(`ZK60_FIVE_SECOND_PLAN.md` §5, third correction). Treat everything above the
same way. For each figure, the experiment and the largest shape it can be run
at on the 8,188 MiB laptop RTX 4070:

| figure | first measurement | shape it can be taken at on the laptop |
|---|---|---|
| **the claim-site count for a tree of `L` leaves — the dominant unknown** | build a **4-leaf tree in the layout builder alone**: no proof, no witness, no challenges, no GPU. The layout is a pure function of the fixed geometry (`layout.rs:15-18`) and asserts its own counts (`:588-590`, `:705-706`, `:778-779`), so it prints `A rows / data rows / site pairs` directly. **This is M0 and it runs first** (C-12) | tiny, CPU, hours |
| 118 S-box applications / permutation | build **one** permutation as a standalone experimental slot; print the layout's own row, site and slot assertions | tiny, CPU. No GPU needed |
| the split form's cost against the degree-7 form | the same experiment in both arms, timed against a degree-4 control. **The degree-7 arm has no GPU kernel** (`SC_DEG 4`), so its seconds are host seconds | tiny, CPU |
| layout A vs C vs B | all three for one permutation, then for the tiny tree | tiny, CPU |
| the tree overhead `1 + 1/k`, and the level wiring | the tiny 512-word plane end to end at two or three values of `k`; count levels, sites and rows against the model | tiny, CPU |
| the 125M band (7.4% – 50% of the private pass's words) | the 512×768 endpoint gadget, ≥ 5 runs per arm, alternating, on a quiesced box — **after** deciding which module it lives in, because `private_block` has no GPU path and the layer prover needs a degree-8 kernel that does not exist (§6 M4) | **125M (512×768) — the data fits.** Layout C adds 714 rows ≈ 93 MiB of committed data, ~750 MiB encoded at `inv_rate` 8, against a measured 3,101 MB peak of 8,188 MiB. The corrected site count adds mask rows on top of that |
| the Mistral band (0.72% – 2.06% of the public pass's words) | the gadget alone at a Mistral-width endpoint | **does not fit the laptop.** Layout A alone is 236 MiB of data and ~1.9 GiB encoded; layout C ~3.8 GiB. The largest comfortable probe is a **512×2048** endpoint (layout A: 944 rows, 118 MiB data, ~0.9 GiB encoded). Full Mistral width needs the 5090 or the CPU binary |
| the byte-hash comparison, **for which no published figure exists in either direction** (check §3.4) | implement **one** BLAKE3 `G` function (not a whole compression) in the lookup framework and count its rows and lookup instances; note it needs a 2^16 table domain this profile does not have (E-6) | tiny, CPU. This is the earlier check's own recommended measurement (`ZK60_D8_D11_RESTATEMENT.md:1024-1029`), reduced to a quarter of a day |
| the gadget's own zero-check (+0.5 – +9.3 s at Mistral) | time the standalone slot's sumcheck at the real linear-form length, and scale by permutation count | tiny, CPU, for the rate; the absolute figure needs the 5090 |

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
commitment, no new lookup, no new table — on the tiny `private_block` profile
only.** On the **layer prover**, the path §3.4's 125M and Mistral figures are
quoted against, the input endpoint has **no byte decomposition at all**, so
the packing is not free there and the limbs must be added (E-15, §2.6).

**(2) The salt — a new hidden value, and it needs its own mask pair.** Four
field elements **sampled uniformly in `[0, p)` by the sealer** — not 64 random
bits reduced mod `p`, for which this project has a recorded reduction bias
(D9, `ZK60_DECISIONS.md:371-410`) (C-2) — committed in `A` as a tiny plane,
absorbed by the first permutation. Under the schedule rule it is one more claim site and therefore
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
(`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:90-98`). The check recomputed this
and **confirmed it, with the exact arithmetic**: `Transcript::absorb` is
`BLAKE3(state ‖ len(label) ‖ label ‖ len(data) ‖ data)`
(`zkp-core/src/transcript.rs:43-51`), so the input is `48 + |label| + |data|`
bytes and lands in the shared untagged 64-byte domain exactly when
`|label| + |data| = 16`; a 32-byte handle under an 8-byte label is 88 bytes,
so it does not land there — but the label must be chosen deliberately and the
invariant **asserted mechanically**, not left to chance (SO-4).

**Not an ingredient, but it belongs beside them: a side channel, stated
deliberately rather than assumed away** (C-13).
The gadget's cost is a function of the plane's *shape*, which is public, and
of no plane *value*: the arithmetic is straight-line, with no data-dependent
branch and no data-dependent size. So the gadget introduces **no new
data-dependent timing or size channel — provided the signed packing is
branch-free**, which is a requirement on the implementation and not an
observation about it. D7 already carries timing as a declared qualifier for
the zkVM line (`ZK60_DECISIONS.md:242-247`); the native line declares the same
thing here on purpose. Nothing here was measured.

### 4.2 Checked against D12 and D17

**D12 item 1 — no commitment opened more than once.** Respected, and by more
than accident. The gadget adds rows to commitments the proof already opens
exactly once, and it adds no second opening anywhere. The handle is not a
commitment the proof opens; it is a public constant. Note the direction of
travel: the handle is precisely the thing that lets the project *stop* wanting
a second opening (§5).

**D12 item 2 — one proof, one transcript, two external endpoints.** Respected
for a single block. For a *chain* of separately finished proofs the handle
changes the picture and §5 states exactly how. The draft added "D12 governs
what happens inside one block and is untouched"; that is **true of the letter
and not a sufficient answer** (C-8). A handle-chained pair is two separately
finished receipts glued by a shared handle, and D12 item 2 exists to forbid a
class of gluing, so what is owed is an **amendment naming handle chaining as
its own composition form** — not an argument that D12 does not apply. See §5
and SO-9.

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
   and **two** new controls are owed. The first tests the *tool*: **a gadget
   whose salt plane shares a mask pair with a hash-state plane must
   disclose**. Without it, the analysis cannot distinguish "the gadget is
   clean" from "the tool does not look at the gadget". The second, which the
   check adds (C-11), tests the *model*: a gadget whose hash-state planes are
   **correlated with the endpoint plane in a way the linear tools cannot
   see** — which is what a hash is — must be shown to be *outside* the
   analysis rather than clean under it. **A disclosed-0 reading on a hash
   gadget is weaker evidence than a disclosed-0 reading on a linear
   relation**, and a reader will not know that unless it is written down
   beside the reading.

**Does the hash's nonlinearity change the leak analysis?** The analysis is a
statement about **what the openings reveal**, i.e. about the linear
functionals of the committed rows that the receipt publishes: claim values,
group vectors, the proximity vector, the sampled columns, the `M` opening, the
masked rounds (§5 of that document lists the channels). The draft closed this
paragraph by saying *"a relation's degree does not enter that model at all"*.
**That sentence is withdrawn (E-17); it contradicted item 3 above, and item 3
is the one that is right.** Degree enters through the **masked-round
channel**, which the analysis itself lists as one of its channels:

* a degree-8 slot (degree 7 × the `eq` factor) publishes **9 `Fp2` values per
  round against today's 5** (`zkp-core/src/sumcheck.rs:73`, `:147-150`) — 1.8×
  the published field values per slot;
* its CFS mask length is `L = n_vars·d + 2` (`sumcheck.rs:197-199`), so the
  consistency subspace `C_s` changes dimension and the lane's measured
  property `rank R_s = dim C_s` must be **re-established, not inherited**.

**The pad budget is not threatened, and here is the arithmetic so nobody
re-derives it** [RECOMPUTED by the check]: `MASK_Q = 256` and `m = 512` are
fixed (`zk.rs:373-375`), so the per-row budget is 256 coefficients; at `d = 8`
and `n_vars = 21`, `L = 170`, leaving 86 spare against 206 spare at `d = 4`.
The headroom halves; the wall does not move. `n_base = 2·slots + 4` grows by
**2 rows of `M` per new slot** (`zk.rs:435`, `layout.rs:519`), so one slot per
tree level costs ~36 extra `M` rows at Mistral — negligible beside the site
pairs of §3.2. And **H-pad** (distinct opened columns ≤ `Q = 256`, margin
9–25) is **not** affected by adding rows, because the sampled column set does
not change; what must be re-measured is `k0`, as item 2 says. What the
openings reveal is fixed by the row weights, the mask schedule **and the slot
degree** — not by the polynomial's shape beyond that.

**One implementer hazard that must be closed before the first gadget slot**
(C-7). `priv_table`'s correctness rests on a premise stated only in a comment:
*"multilinear in x because every challenge index occurs at most once among the
coordinates"* (`argument.rs:162-163`). **There is no code check.** The loop
does `x |= b << (n_vars − 1 − *k)`, so a duplicated index silently ORs two
plane bits into one and the table is no longer the plane's multilinear
extension. Today's ~23 slots are hand-audited; the gadget introduces on the
order of a **thousand** new `Coord` vectors. An assertion on coordinate
uniqueness must land before the first gadget slot, not after.

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
| **who knows the salt?** | Both provers. If one party proves both, it is a local secret. If two parties do, `s_k` is a **shared secret that must be transported with the plane** — the plane and its salt travel together or the chain cannot be built. A pure relay that carries `(P, s_k)` learns the plane anyway; a relay that carries only `s_k` learns nothing but can help anyone who guesses `P` confirm the guess. **In a chain of `K` runs, any two consecutive parties hold the same boundary salt, so they can jointly confirm a third party's guess of that intermediate** (C-10) |
| **who is the sealer here?** | **The upstream prover.** At a chain boundary the party that publishes `h_k` is the party whose honesty the receipt is supposed not to require, and it chooses `s_k`. Per PO-4 this is the same case as every other: the sealer holds the plaintext of the plane it seals — here, its own output — so no mechanism protects that plane from it, and a malicious prover could publish its witness anyway. The rule that binds it is PO-4's: 256 fresh bits per handle, never reused, never derived from the plane, worth the sealer's diligence and nothing more |
| **what if the salt is lost?** | The plane becomes **permanently unprovable** downstream. There is no re-sealing and no revocation story (C-9). For a regulator-sealed input this is an operational failure mode with legal weight, and it is owed a design |
| **what does the chain's verifier check?** | Byte equality of the two handles across the two receipts, plus each receipt on its own. That is a 32-byte comparison, not a cryptographic operation. It is the same shape as D7's *"a chain of blocks is checked by journal equality"* (`ZK60_DECISIONS.md:227-228`) — and D11's caution applies here too: that phrase is an integration description, and the roles must be distinct enough that a boundary handle cannot be mistaken for an external endpoint handle |
| **what leaks?** | **Handle equality is public by design.** The chain's verifier — and any observer of both receipts — learns that the two proofs share a plane. It learns nothing about the plane's value beyond assumption (H-hide). This is *linkage*, not *content* |
| **can the linkage be removed?** | Not while keeping equality-checked chaining. Sealing the same plane twice under different salts gives unlinkable handles, but then the verifier cannot compare them; making the proof show that two handles seal the same plane costs a second gadget instance **and republishes both handles in one receipt, re-linking them**. Linkage is intrinsic to handle-based chaining |
| **cost per boundary** | **two gadget instances**, one in each proof — i.e. one boundary costs the same as the two external endpoints of §3.4, and carries the same corrected band: **0.72% – 2.06% of the 8B public pass's committed words, +0.42 – +1.20 s of volume time, 8.78 – 25.1 MB of proof, plus the gadget's own zero-check at +0.5 – +9.3 s** [RECOMPUTED by the independent check; the draft's "+0.63% / 8.78 MB per boundary" was the bottom of that band and is withdrawn as a headline]. Every GPU-denominated part of that presupposes a kernel that does not exist (§2.0). A 32-layer pass cut into `K` runs costs `2(K − 1)` boundary instances plus 2 external ones |

**What this owes D12, and it is not an argument that D12 does not apply**
(C-8, S-8, SO-9). D12 item 2 says *"A block is one proof under one transcript
with exactly two external endpoints… Two separately finished component
receipts glued by a shared root are not a block."* A handle-chained pair is
two separately finished receipts glued by a shared **handle**. The draft said
"D12 governs what happens inside one block and is untouched"; that is true of
the letter and evasive about the substance, because the whole purpose of this
section is to glue finished proofs and D12 exists to forbid a class of
gluing. The right resolution is to **ask for an amendment** — naming handle
chaining as a permitted second composition form, with its own name (it is
**not** a block), its own qualifier list, D17 rule 4's discipline that a cost
vehicle is never called P1, and an explicit statement that **a published
handle of an intermediate plane is prior history for every later proof and
every later analysis**. On D12 item 3 specifically: its *mechanism* is
respected (a handle is not a commitment the proof opens, has no randomness, no
paths and no top pair), and its *concern* is only partly answered, because a
handle is **more persistent than a root** — stable across proofs and provers.
The amendment should say which of the two it is settling.

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

Six stages. Each is a day or two, each ends in a number, and each can be
abandoned without touching a frozen path. Everything is **additive** under
D17 rule 2: a new module, a new profile tag, a new digest domain, new entry
points beside the pinned ones. *No existing constant, label, schedule or
digest moves at any stage; a moved digest is a bug in the change.*

**M0 — the four-leaf tree in the layout builder alone. This is the first step,
and it is the one the whole cost picture hangs on** (S-6, B-6, C-12). Build a
4-leaf tree's planes and slots **in the layout builder only** — no proof, no
witness, no challenges, no GPU — and read off the counts the builder asserts
about itself: `A rows`, data rows, site pairs, `M` rows, slot count. The
layout is *"a function of the fixed geometry only: no proof value, witness
value or challenge moves a row, a site or a slot"* (`layout.rs:15-18`) and it
asserts its own counts (`layout.rs:588-590`, `:705-706`, `:778-779`), so this
is hours of work and it proves nothing.
*Answers:* **how many claim sites a tree of `L` leaves actually demands** —
the single unknown that dominates every band in §3.4, where the corrected
range spans ×2.86 to ×6.38 in proof bytes; and whether level-wise families or
a level axis is cheaper in sites and rows (the old M2 question, which M0
absorbs).
**Kill:** if the builder demands materially more than one site per plane per
point, every figure in §3 is optimistic by that ratio and the memo must be
re-costed before anything else is built.

**M1 — one permutation, on paper's terms.** Implement a single permutation as
a standalone experimental zero-check in a scratch module, in all three layouts
of §3.2, **in the degree-≤4 split form as the default** (two committed values
per S-box: `t = x³`, `y = t²·x`), with the degree-7 form as the comparison arm.
Count committed values, claim sites and rows from the layout's own assertions;
time its sumcheck against a degree-4 control. Tiny shape, CPU, no proof needed.
*Answers:* is 118 S-box applications right; what the split form actually costs
against the degree-7 form on this prover; which layout wins where; whether
`masked_prove` at the chosen degree is efficient as well as expressible.
*Note:* the draft made the degree-7 form its default. The CUDA zero-check is
capped at degree 4 (`#define SC_DEG 4`, `hashline/src/gpu/kernels.cu:601`), so
**the degree-7 form has no GPU kernel** and the split form is the default
until one is written and measured (B-5).
**Kill:** if the split form costs more than about 300 committed values per
permutation in the best layout, stop and re-scope before writing anything else.

**M1b — write and time one degree-8 CUDA zero-check kernel** (optional, and
the precondition for every GPU-denominated figure in this memo). Compare it
against the degree-4 kernel, or instead measure a host-side slot inside a GPU
pass and read the real host penalty rather than the check's `7.62×` proxy
(the measured private-feed-forward host/GPU ratio at 12×512,
`35.417 / 4.649`). Until this exists, no GPU figure for the degree-7 form may
be quoted.
**Kill:** if the kernel cannot be written within the register and
shared-memory budget of an 8 GiB card, the degree-7 form is off the table and
the split form is not a default but the only option.

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
   specification and not from the Rust — and that reference must exercise
   **exactly the pinned packing map**: the signed encoding (the module has at
   least three), the limb order and the tiling (C-4, C-5, §3.1);
5. the **leak-checking tools run on the grown layout**: the joint-view rank
   and CFS gates report disclosed 0 on `A` and on both endpoints and 2 on `H`
   (the existing public LogUp identity), `rank R_s = dim C_s` on every new
   slot, and **every negative control fires**, including both new ones of
   §4.3 item 5 — the tool control and the model control (C-11). A disclosed-0
   reading on a hash gadget is weaker evidence than one on a linear relation,
   and the acceptance must record it that way;
6. the twelve byte gates and the four frozen digests are green **before and
   after**, and no digest moves;
7. the receipt's byte length and every added row and site match the model of
   §3.3, or the model is corrected in writing.

**Kill:** any of 1–6 failing; or a disclosed dimension above the baseline on
any role.

**M4 — the 125M shape on the GPU, once a GPU path exists for it.**
*Corrected (E-20, B-5).* The draft wrote this as "the 512×768 endpoint inside
the repaired private profile, GPU binary". **That is not runnable as written**:
`private_block` — the module this memo scopes the gadget into — has **no GPU
path at all** (`grep gpu` over `hashline/src/private_block/` is empty), and
the 4.649 s denominator §3.4 prices against is the **layer prover** on the GPU
binary, a different module. So M4 must first say which it is: either the
gadget goes into `private_block` and runs on the **host** — in which case the
check's measured host/GPU ratio of `7.62×` applies and the figures move by
that factor — or it goes into the layer prover and **needs the degree-8 CUDA
kernel of M1b**, which does not exist. Then: the 512×768 endpoint, ≥ 5 runs
per arm, alternating order, on a **quiesced** box, `gpu: ON` confirmed in
every header, exact rows and bytes recorded beside the noisy seconds. Compare
against §3.4's corrected band (7.4% – 50% of the private pass's words,
+0.34 – +2.39 s on the GPU, ×7.62 if host-side), **not** against the draft's
withdrawn +4.29% / +0.20 s.
**Kill:** measured cost above **10% of the private pass** at 125M. *The
threshold's old justification is withdrawn:* it was set against D18's "+12.6%
of a private pass" for SHA-256, and that figure has no published derivation
and is not reproducible (C-6), so it cannot serve as a comparison. The
threshold is kept as a **product** judgement — a handle that costs more than a
tenth of the pass it rides on is not worth building at this shape — and note
that on the corrected band the 125M case **already exceeds it** on the
volume figures alone.

**M5 — one Mistral-width endpoint, or as close as the hardware allows.** Not on
this laptop: §3.5 shows a full 512×4096 endpoint needs ~1.9 GiB encoded in the
cheapest layout. Run **512×2048** on the 4070 as the scaling rung, and the full
width on the 5090 when it lands.
**Kill:** the scaling from 125M to 512×2048 departs from the model by more than
2×, which would mean the model is wrong about what dominates.

**Three kill criteria that apply to every stage.** (i) If the gadget forces a
change to a frozen path rather than an additive one, stop and report — that is
D17 rule 2 and it is not negotiable. (ii) If no parameter set for the chosen
permutation can be pinned to a published specification with published
cryptanalysis, the security assumption cannot be put to the project owner and
the work is premature (PO-1). (iii) **No hash may be chosen before the
project owner's acceptance**, and that acceptance requires eprint 2026/306
read in full, with the question of whether its attacked recommended set is the
Goldilocks width-12 one answered (C-3, PO-1). M0 and M1 are deliberately
hash-agnostic in their counts so that they can run before that ruling.

**What is deliberately not in the plan.** Building the 7-bytes-per-element
gather (§3.1), the shifted access mode that would allow a linear sponge
(§2.5 — an additive change, not a new primitive, and not needed now that the
tree costs `1 + 1/k`), the 64-endpoint cost vehicle (§3.3), and any change to
the D14 field question — which, as §3.4 and SO-6 now state, changes the
hash *instance* and costs plausibly 2–3× per absorbed element rather than
invalidating the approach, and must still be decided jointly.

## 7. Decisions, open obligations, and what I did not check

### 7.1 Decisions for the project owner

These are written to be readable without cryptography. Each is a ruling of the
same kind as D3, D4 and D7: accepting a stated assumption in exchange for
something the product needs.

**PO-1 — Which hash the handle uses. This memo recommends no hash. The choice
is a security acceptance for you, of the same kind as D3, D4 and D7, and it is
taken when this option is scheduled, with the published cryptanalysis read
again that week.**

The draft recommended Poseidon2. That recommendation is **withdrawn** (B-8,
S-7): it rested on a cost comparison in which the figure for the main
alternative was 3.5× too high, and on a premise about who scrutinises the
primitive that moved during 2026. What follows is the two candidates side by
side and an honest third option, so that the choice can be made on the day
with the literature fresh.

| | **Rescue-Prime Optimized** w12 r8 c4 | **Poseidon2** w12 r8 c4 |
|---|---|---|
| committed values per absorbed element, degree-7 form | **12.00** | **14.75** |
| committed values per absorbed element, **default split form** (B-5) | **24.0** | **29.5** |
| table lookups | **0** | **0** |
| S-box | `x⁷` and `x^(1/7)`, the inverse *verified* (`y⁷ = x`), not evaluated | `x⁷` |
| permutation cost basis | 96 degree-7 constraints per permutation | 118 S-box applications per permutation |
| uncounted prover-side cost | computing `x^(1/7)` per S-box: ≈ **2.2 × 10⁹ host field multiplications per Mistral endpoint**, order 0.1–2 s depending on cores [RECOMPUTED by the check] | none of this kind |
| margin note | ships `N = 7` rounds where its own formula gives 8 — a deliberate 12.5% margin cut stated in RPO §4.2 | round counts confirmed at `R_F = 8`, `R_P = 22` from four independent sources |

All committed-value figures are Monolith Table 4's witness size ÷ rate
[reported by the independent check from public sources; not verified by the
security owner], and the check warns that this is **not a published metric**:
Monolith calls its own arithmetisations *"non-optimized … subject to change"*,
so these are one paper's comparison, not constants.

**The state of the cryptanalysis, exactly as the check reports it** [reported
by the independent check from public sources; not verified by the security
owner]:

* **No published attack breaks `R_F = 8 / R_P = 22`, and nobody recommends
  raising the round numbers.**
* The **Ethereum Foundation Poseidon Cryptanalysis Initiative** (launched
  Nov 2024) funds bounties against deliberately round-reduced instances. The
  deepest reach over a 64-bit field is `R_F = 6, R_P = 12` (zero-test,
  Jul 2026); CICO reached `R_F = 6 / R_P = 10`. The margin against 8/22 is
  2 full and 10 partial rounds — but **the partial-round reach moved from 7 to
  12 in about two months**, and the programme was **paused on 1 Aug 2026**.
  The site issues no round-number recommendation and states no conclusion that
  the parameters are adequate; citing it as an endorsement would be
  over-reading it.
* **eprint 2026/306** (Merz & Rodríguez García, 18 Feb 2026), *"Skipping
  Class: Algebraic Attacks exploiting weak matrices and operation modes of
  Poseidon2"*, exploits linear-layer matrix structure, is the first case where
  preimage-finding beats CICO and the first algebraic collision attack beating
  its preimage counterpart, and **improves collision attacks on a recommended
  128-bit parameter set by 2^106**. The authors state the primitive does not
  fall short of its claimed level, and propose mitigations. **The check could
  not verify whether the attacked recommended set is the Goldilocks t = 12
  one. That is the single most important open question in this memo's security
  case and it must be answered before this ruling is put to you** (C-3).
* On **13–14 Aug 2026 the Ethereum Foundation dropped Poseidon from the L1
  roadmap in favour of SHA-256/BLAKE3**, on performance-convergence grounds,
  with no deployed parameter set broken. That is not a cryptographic finding,
  but it removes the premise the draft leaned on: the largest funder of this
  primitive's cryptanalysis no longer plans to depend on it, so "heavily
  scrutinised because Ethereum needs it" should be **discounted going
  forward**. You would be adopting a new hash assumption in the same quarter
  the biggest adopter walked away from it.
* eprint 2023/537's HADES Gröbner objection applies at the 384-bit level, not
  here. The Graeffe line (2025/937, 2025/950, 2025/1916) speeds up challenge
  solving but reports memory access as the binding barrier.

**The conservative alternative: an all-standard-hash handle.** Use no
algebraic hash at all — build the handle from SHA-256 (interoperable in
principle with D7's zkVM line, but see PO-2) or BLAKE3 (already the project's
transcript and Merkle hash, so **no new cryptographic assumption at all**),
arithmetised byte-limb inside the proof. **The honest statement about its
cost is that nobody knows it**: the check found **no BLAKE3 arithmetisation
cost figure at all and no byte-decomposed SHA-256 AIR figure**, so the
record's 4,000 lookups and ~2,500 committed words per compression, this memo's
own ≈12,800-lookup count and the ≈3,100 BLAKE3 count are **unverified in both
directions**. The nearest public anchor is Zcash halo2's `table16` at ~24
lookups per compression round and ~2,099 rows per compression, over a 2^16
*spread* table — a different representation from the byte-limb one used here.
What *is* established is structural and unfavourable: this profile's tables are
**pinned at 256 entries** (`LOG_N = 8`, `layout.rs:48-49`), so the 2^16
XOR/AND tables a byte-limb SHA-256 or BLAKE3 needs are a **new table domain**
(E-6), and the route puts the gadget's lookup column back above zero, which is
the one axis on which the algebraic candidates win outright.

**And the option that changes the question.** Under §1.4's two-layer
direction — the security owner's, and unchecked — this ruling shrinks: hiding
would rest on a **standard** salted hash, the assumption already accepted in
D7, and only **collision resistance**, the mode the literature actually
analyses, would rest on the algebraic permutation. That does not make the
choice go away; it makes it a smaller one. It is not priced by measurement and
has not been attacked.

*In plain words.* You are being asked, when this option is scheduled, to
accept one of: a newer hash function analysed by fewer people than SHA-256,
in exchange for a handle that adds no table lookups; or the hash you already
trust, at a cost nobody has been able to pin down and with a new lookup bill;
or the two-layer form, which splits the question in two and which nobody has
checked yet. This memo does not choose for you, and it should not: the
literature moved twice in 2026 and must be read again in the week the decision
is taken.

**PO-2 — Interoperability with the zkVM line, and what it costs.**
*Corrected (E-16).* The draft said that if the handle used **SHA-256** the two
lines' handles would be the *same object*. **They would not.** The native
packing this memo specifies is interleaved offset-binary over two limb planes
(§3.1), while D7's zkVM handle does `for v in values { h.update(v.to_le_bytes())
}` over two's-complement `i16`s in order, and additionally absorbs a model
digest and the element count
(`zkvm-block/statement/src/lib.rs:65-78`). Interoperability therefore costs a
**matched packing as well as a matched hash** — and a matched packing gives up
the free byte limbs that §2.6 relies on, so the option is more expensive than
the draft said, not merely "the full bit-oriented price".
*Recommendation: do not buy it now; record it as one reason a standard hash
stays on the list, and record that buying it later means pinning a single
packing map across both lines (C-4).*

**PO-3 — Linkage. Do you want two receipts about the same hidden value to be
publicly recognisable as such?** Handle-based chaining makes them so, by
design and unavoidably (§5). *Recommendation: accept it for chaining, and
record it as a named deviation from "nothing about the hidden value is
public", in the way D7's three qualifiers travel with the zkVM claim.*
*Reason:* the alternative is no chaining, and today no 8B private pass fits one
proof on a consumer card. Note the same property is what would let a regulator
say "these two receipts used the same input" — which you may want.

**Three things about that linkage that must be said in plain words before you
accept it** (C-10, S-8):

* **It is public.** Anyone holding both receipts sees that they share a plane.
  Nothing has to be leaked for this; it is how the chain is checked.
* **It is retroactive and permanent.** A handle is a *stable* identifier —
  the same plane under the same salt always gives the same `h`, where two
  commitment roots for the same plane are always different. A salt that leaks
  years later makes **every handle ever published under it** checkable against
  a guessed plane, for ever. That is a materially different exposure profile
  from a commitment root.
* **A party who guesses a low-entropy plane and knows the salt can confirm the
  guess.** In a chain of `K` runs by different parties, boundary salt `s_k` is
  known to parties `k` and `k+1`, so **any two consecutive parties can confirm
  a third party's guess** of the intermediate activation. The draft's table
  covered the relay case; it did not cover this coalition case.

**PO-4 — The salt: who makes it, who holds it, and what the product is
entitled to assume.** *Recommendation: accept the duty, with the threat model
below written into the acceptance, and with the lifecycle items recorded as
owed work rather than as accepted costs.*

**Who the sealer is, deployment by deployment.** A regulator sealing **its
own** test input; a user's client sealing the **user's own** prompt; an
upstream prover sealing **its own** output at a chain boundary. In every case
**the sealer holds the plaintext of the plane it seals.** No mechanism in this
construction protects a plane from its own sealer, and none is claimed.

**What that settles, and what it does not.** A sealer that is adversarial
about the *prover's* privacy could reuse a salt across handles, derive the
salt from the plane, or grind the salt so that `h`'s low bits encode chosen
information about the plane. Those are real behaviours and the rule below
forbids them — but they are **a channel between parties who could talk
anyway**, because the sealer already has the plaintext. Symmetrically, a
malicious *prover* can always publish its own witness, so zero knowledge never
protected a data subject from the prover. The threat model is therefore
smaller than it first looks, and it is stated so that nobody later mistakes
the rule for a guarantee.

**The rule.** The salt is **256 fresh bits per handle**, drawn from the
operating system at sealing time, **never reused across handles and never
derived from the plane**. It is sampled as **4 uniform Goldilocks field
elements** — not 64 random bits reduced mod `p`, for which this project has a
recorded reduction bias (D9, `ZK60_DECISIONS.md:371-410`) — and it is
transported to the prover with the plane.

**What an unverifiable salt is worth: exactly the sealer's diligence.**
Nothing in the receipt proves the salt was uniform, and no party other than
the sealer can check it. That is acceptable **because the sealer is entitled
to the plaintext**; it is not acceptable as a claim, and must never be written
as one. **Attested salt generation** — a salt derived as `PRF(sealer key,
context ‖ role)` with the key's uniqueness attested, or hardware attestation
of the draw — is recorded here as **a possible hardening, not a requirement**.

**What is still owed** (C-9): the transport channel and its authentication,
storage, rotation, destruction, what re-sealing means, and the **availability
failure** — a sealer that loses or withholds the salt has made that plane
**permanently unprovable**, with no re-sealing and no revocation story. For a
regulator-sealed input that is an operational failure mode with legal weight.
And a leaked salt turns a low-entropy hidden value into a guessable one —
D7's first qualifier, now applying to a second party as well
(`ZK60_DECISIONS.md:242-247`).

**PO-5 — Build order.** *Recommendation: authorise M0–M3 of §6 now (a few
days, tiny shape, CPU, nothing frozen touched), and decide M4/M5 on M3's
numbers.* *Reason:* three counted estimates in this project moved by three- to
sevenfold this week when measured, and the check's band is dominated by a
single unknown — the claim-site count — that **M0 settles in hours with no
proof, no witness and no GPU**. M0 before M1, not after.

### 7.1a Decisions nobody has been asked yet

The check's §9.5 lists nine items that are real decisions with no owner. They
are recorded here so that they are not lost between this memo and whoever
schedules the work. Each is covered above or in the section named.

1. **Who generates the salt, from what entropy source, and how a verifier or
   an auditor knows it was uniform** — PO-4, and the answer there is "the
   sealer's diligence", which is a ruling and not a mechanism.
2. **Handle format versioning**: the tag, the packing map, the tiling, the
   signed encoding and the tree shape must be pinned by a statement version,
   and a v2 must be distinguishable from a v1 (§3.1, C-4, C-5).
3. **Salt lifecycle**: transport, storage, rotation, destruction, re-sealing
   (PO-4, C-9).
4. **Availability**: a lost or withheld salt makes a sealed plane permanently
   unprovable (PO-4, C-9).
5. **Length and tree-shape binding** in the hash input — a soundness item
   (§1.1, §1.5, B-2, S-2).
6. **Salt placement**: the capacity of every node rather than one leaf's
   message (§2.5, C-1) — a security choice with a zero-cost right answer under
   the single-layer design, and one that §1.4's two-layer direction removes.
7. **The degree-4 split form versus a new degree-8 CUDA kernel** (§2.2, B-5) —
   an engineering ruling that changes the whole cost picture.
8. **Timing and size side channels** (§7.3 item 12, C-13).
9. **The amendment to D12** admitting handle chaining as a named, non-block
   composition (SO-9, C-8).

### 7.2 Decisions for the security owner

**SO-1 — Layout A, C or B, and the S-box form.** *Recommendation: none until
M0 and M1 report.* Two things changed under the check. First, the **S-box form
is settled against the draft's choice**: the CUDA zero-check is capped at
degree 4 (`#define SC_DEG 4`, `hashline/src/gpu/kernels.cu:601`), so the
**degree-≤4 split form — two committed values per S-box — is the default**,
and the degree-7 form is reinstated only if a degree-8 kernel is written and
measured (B-5, §2.2). Second, the layout question is dominated by the
claim-site count, which is the largest single unknown in the memo and is
what M0 measures (B-6). *Reason:* A minimises committed volume but its
~130-term linear forms make its own sumcheck +0.5…+4.7 s per Mistral endpoint
[RECOMPUTED by the check]; C bounds the forms at 34 terms for twice the volume
at +0.3…+2.7 s; B wins only at the tiny shape, and only on the draft's flat
site count.

**SO-2 — The tree's level wiring.** *Recommendation: none; M0 decides, and
§3 now prices the level-wise form throughout* (B-6). *Reason:* the draft said
§3 priced the level-wise form and then priced 128 flat sites, which is the
other option; the two differ by ×2.86 in proof bytes at Mistral, ×6.38 at 125M
and ×5.06 at the tiny shape. The public level-shift table would keep the site
count flat, but it needs ragged padding that nobody has counted, so it is not
a recommendation until it has been built in the layout builder.

**SO-3 → PO-3b — Keep BLAKE3 for the transcript and the Merkle layer; use the
handle's hash only for the handle.** *Reclassified from a security-owner
choice to a project-owner ruling*, on the check's §9.1: the reason given for
it is *"Record it as two assumptions, not one"*, and adding a second
cryptographic assumption to the product is exactly the kind of thing D3 and D4
were put to the project owner for. The engineering content is unchanged and
stands: the two hashes have opposite requirements — the transcript's must be
fast in software, the handle's must be cheap inside a proof — and replacing
BLAKE3 everywhere is a far larger change. Under §1.4's two-layer direction the
outer hash would be a standard hash anyway, which narrows but does not remove
the second assumption (collision resistance of the inner algebraic hash).

**SO-4 — The handle's transcript label must not land in the shared untagged
64-byte BLAKE3 domain** (`transcript.rs:44-52`;
`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:90-98`). *Recommendation: fix the label
so `|label| + |data| ≠ 16`, and assert it mechanically alongside the existing
`commitment_rows ∉ {5, 8}` invariants of the disposition's §2.8.*

**SO-5 — Two new controls are required before any quoted measurement**, per
D17 rule 3. *Recommendation: make both gates, not checklist items.* The first
is §4.3 item 5's control of the **tool**: a gadget whose salt plane shares a
mask pair with a hash-state plane must disclose; without a control that fires,
a clean reading cannot be distinguished from a tool that does not look at the
new planes. The second, which the check adds (C-11), tests the **model**: the
hash's planes are correlated with the endpoint plane in a way the linear tools
*cannot see*, so a disclosed-0 reading on a hash gadget is **weaker evidence
than a disclosed-0 reading on a linear relation**, and the sentence saying so
must survive into any disposition that quotes the reading.

**SO-6 — D14 and this gadget are coupled and must be ruled on together.**
*Corrected (E-18).* A 31–32-bit field does **not** invalidate the `x⁷` S-box:
`gcd(7, 2^31 − 2^27) = 1`, so `x⁷` permutes BabyBear; KoalaBear takes `x³` and
Mersenne31 `x⁵`, and published Poseidon2 parameter sets exist for those fields
at widths 16 and 24 [RECOMPUTED by the check]. What a field change invalidates
is the **instance**, not the approach. The real coupling is **cost**: 128-bit
collision resistance needs capacity ≥ **9** elements in a 31-bit field against
4 in Goldilocks, which forces a wider state and a worse rate-to-S-box ratio —
plausibly **2–3× the gadget cost per absorbed element** [RECOMPUTED by the
check]. *Recommendation: add a line to the D14 memo's question list carrying
that factor, not the words "it breaks".*

**SO-7 — Nothing in this memo restates D18.** *The draft's proposal to
restate D18's figures as "about +11% public / +25% private" is withdrawn*
(B-7, S-1): it rested on the forced-tree argument, which is withdrawn
(§2.5), and on a private base figure that is not reproducible. What the
decisions register now says, in the scoping note of 2026-09-19 23:13 that
this memo does not amend: **the public figure (+5.5%) follows from its
stated basis; the private figure (+12.6%) has no published derivation, could
not be reproduced, and is to be treated as unverified**; both stay labelled
counted and untested. The separate, unapplied observation survives and is
*not* a restatement: this memo's own byte-limb count of SHA-256 gives ≈12,800
lookups per compression against the record's 4,000, which on a linear chain
would put the public figure near +10.3% [RECOMPUTED by the check] — and the
check could confirm **no** byte-hash cost figure in either direction, so
neither 4,000 nor 12,800 is established.

**SO-8 — Whether the 64-endpoint feed-forward-only vehicle is ever priced with
handles.** *Recommendation: no, unless a specific measurement needs it.*
*Reason:* it is a large fraction of the pass on any of the corrected bands
(§3.3, §3.4), and D17 rule 4 already says that pass is never P1.

**SO-9 — Ask for a D12 amendment before any chain is built** (C-8, S-8).
*Recommendation: request the amendment; do not argue that D12 does not
apply.* D12 item 2 forbids gluing two separately finished component receipts
through a shared root, and the whole purpose of §5 is to glue finished
proofs — through a handle rather than a root. The mechanism D12 item 3 names
is respected (§4.2, §5); its *concern* is only partly answered, because a
handle is **more persistent than a root**. The amendment must name handle
chaining as a permitted second composition form with its own name (it is not
a block), say that a published handle of an intermediate plane is **prior
history for every later proof and analysis**, and carry D17 rule 4's
discipline that a cost vehicle is never called P1.

### 7.3 Open obligations

1. **D8 and D11 remain open**, exactly as written. This construction does not
   close them; it builds a configuration they do not bind. If a caller ever
   fixes a polynomial-commitment root again, they apply in full.
2. **Game J's simulator does not exist.** `SimProve` is recorded as incomplete
   (`ZK60_ENDPOINT_SIMULATION_MODEL.md:76`). The handle makes the standard game
   the right one; it does not discharge it.
3. **(H-hide) is a new assumption**, and its honest name is **a keyed-mode
   assumption on a primitive analysed only in unkeyed mode** (§1.3, B-1): the
   handle uses the permutation with a secret salt, while every published
   analysis of Poseidon2, Rescue-Prime Optimized, Monolith and Tip5 is of an
   unkeyed public hash, and the sponge bound is conditioned on an *ideal*
   permutation. No keyed-sponge or PRF analysis of any candidate was found.
   It must travel with every claim, the way D7's three qualifiers do. The
   two-layer design of §1.4 is the security owner's direction for removing
   this obligation by resting hiding on a standard salted hash instead; it is
   unchecked, and until it is checked this obligation stands as written.
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
9. **eprint 2026/306 has not been read in full** (C-3). The check reports it as
   improving collision attacks on *a* recommended 128-bit Poseidon2 parameter
   set by 2^106, and **could not confirm whether the attacked set is the
   Goldilocks width-12 one**. That question must be answered before any hash
   is put to the project owner.
10. **D18's "+12.6% private" has no published derivation** (C-6). The check
    could not reproduce it from any published denominator, and the register's
    scoping note of 2026-09-19 23:13 now records it as unverified. It must be
    recomputed or withdrawn; nothing in this memo may be compared against it
    as if it were a measured figure.
11. **The `Coord` uniqueness premise is unasserted in code** (C-7). `priv_table`
    states *"multilinear in x because every challenge index occurs at most once
    among the coordinates"* in a comment only (`argument.rs:162-163`), and does
    `x |= b << …`, so a duplicated index silently ORs two plane bits and the
    table stops being the plane's multilinear extension. Today's ~23 slots are
    hand-audited; the gadget introduces on the order of a thousand new `Coord`
    vectors. The assertion must land before the first gadget slot.
12. **Timing and size are declared leakage on this line too** (C-13). The
    gadget's cost depends on the plane's *shape*, which is public, and on no
    plane *value* — the arithmetic is straight-line — **provided the signed
    packing is branch-free**. D7 already carries timing as a qualifier; the
    native line states the same thing here deliberately rather than by
    assumption. It is asserted, not measured.
13. **The salt lifecycle and the availability failure are undesigned** (C-9,
    §5): transport channel and its authentication, storage, rotation,
    destruction, what re-sealing means, and the fact that a lost or withheld
    salt makes a sealed plane **permanently unprovable**, with no revocation
    story.
14. **A D12 amendment is owed before any chain is built** (C-8, S-8): handle
    chaining must be named as its own composition form — it is not a block —
    with its own qualifier list.

### 7.4 What I did not check

**Ran nothing.** No build, no proof, no test, no benchmark; read-only
throughout, and no file in this repository was modified but this one.

**The literature, and what the independent check settled.** Every parameter
set, round count, width, rate, capacity, author list and cryptanalysis
statement in §2.2 and §2.3 was written from the drafter's memory and flagged
as the most likely place this memo was wrong. The independent check ran a
literature lane against public sources only and **confirmed the parameters
this memo's costs rest on**: Poseidon2 Goldilocks width 12 with `R_F = 8`,
`R_P = 22` (four independent sources), `8·12 + 22 = 118` S-box applications
per permutation, the `x⁷` S-box, and `gcd(7, p − 1) = 1` by arithmetic
(`ZK60_SEALED_HANDLE_SCOPING_CHECK.md` §3.1). The flat-sponge collision bound
of §1.5 was confirmed too, **with the caveat that it assumes an ideal
permutation**. What the check *contradicted* is the comparison table's other
rows (E-1, E-2, E-3 below) and the claim that every Goldilocks design uses
`x⁷` (E-4). What it could not establish: "committed values per absorbed
element" is **not a published metric** — every such figure is Monolith Table 4's
witness size divided by the rate, and Monolith calls its own arithmetisations
*"non-optimized … subject to change"*, so 12.0 / 14.75 / 38.0 / 60.0 are one
paper's comparison and not constants; and **no byte-hash arithmetisation cost
figure could be confirmed in either direction**, so the record's 4,000 lookups
per SHA-256 compression, this memo's own ≈12,800, and the BLAKE3 figure are all
unverified (check §3.4).

**Facts I verified in this repository** (file:line given throughout): the
prover's currencies and their measured shares; the lookup form and the
two-column table idiom; the `U8` byte decomposition of both external endpoint
planes and the zero-check terms that tie them; the absence of any shift or
rotation operator in the claim-point machinery; the sumcheck's and the CFS
mask's genericity in degree; the endpoint equality slots; the transcript's
absorb construction; the zkVM line's handle construction; the mask-pair
schedule rule; and the measured 125M private/public ratio, rows and bytes.

**Answered by the check, and both answers were unfavourable:**
* **the GPU zero-check kernels do not support degree 7.** The draft named this
  as "the most likely hidden cost in the whole memo" and it was right:
  `#define SC_DEG 4` (`hashline/src/gpu/kernels.cu:601`) is a hard cap baked
  into the kernels' register arrays, shared memory and `scg_emit<SC_DEG + 1>`,
  with a degree-3-specialised table kernel beside it (`gpu/cuda.rs:3152-3160`);
  and `private_block` has **no GPU path at all**. Hence the split form is the
  default pricing (B-5, §2.2) and **every GPU-denominated figure in this memo
  presupposes a kernel that does not exist**;
* **the claim-site count was the memo's largest error, not a footnote.** The
  draft priced 128 sites flat while its own §2.5 said the form it prices
  multiplies sites by the tree's depth; the corrected counts are 2,124 at
  Mistral, 1,770 at 125M and 708 at the tiny shape, and they dominate every
  band in §3.4 (B-6). The exact count a real layout builder demands is still
  unmeasured, and it is now measurement M0.

**Still not checked, and each could move a number:**
* whether `masked_prove` at degree 7 is *efficient*, as opposed to merely
  expressible (and it is now the split form at degree ≤ 4 that must be timed);
* the host-side cost of generating and encoding the new mask rows, which the
  MR1 lane found to be **53% of the repaired profile's added cost** — this
  memo's model counts rows, not host seconds;
* the wire format, the parser, the refusal list and the tamper tests, none of
  which were sized;
* whether a new commitment for the gadget is cheaper than more rows on `A`;
* the 5090's behaviour, which nothing in this memo models;
* **everything in §1.4**, the security owner's two-layer direction, which is
  unchecked by anyone and priced only by counting.

## Revision record (2026-09-19)

Every row below is a change made to this memo in the revision of 2026-09-19,
traceable to `ZK60_SEALED_HANDLE_SCOPING_CHECK.md` (items B-1 … B-8, E-1 …
E-20, C-1 … C-13) or to `ZK60_SEALED_HANDLE_SCOPING_DISPOSITION.md` (rulings
S-1 … S-8). Where a ruling and the check differ, the ruling was applied.

| item | section(s) changed | what changed |
|---|---|---|
| **B-1** | §0 item 3, §1.3, §7.3 item 3 | (H-hide) relabelled "a keyed-mode assumption on a primitive analysed only in unkeyed mode"; the ROM bound is stated as not transferring to an algebraic permutation; "random-oracle hiding" withdrawn as a label |
| **B-2** | §1.1 (the handle formula and its table), §1.5, §2.5 | the hash input gains element count, tree shape, leaf/internal separation and a padding rule; binding is re-stated as conditional on them |
| **B-3** | §1.1 (new "the sealer" paragraphs), §5, PO-4 | sealer threat model added, in the form ruling S-4 fixes (see S-4 below) |
| **B-4** | §2.5, §2.7 box, §3.3, SO-7 | "a binary tree is forced, doubling permutations" withdrawn; overhead stated as `1 + 1/k` with `k` free; the separate, unapplied observation that this memo's own SHA-256 count is ≈3× the record's is kept |
| **B-5** | §2.0, §2.2, §2.7, §3.4, §6 M4, §7.4 | `#define SC_DEG 4` stated; the degree-≤4 split form (2 committed values per S-box; 29.5/element Poseidon2, 24.0/element RPO) is the default pricing; every GPU-denominated figure carries the missing-kernel condition in the same sentence |
| **B-6** | §2.5, §3.2, §3.3, §3.4, §6 (new M0) | one wiring (level-wise) is priced consistently with the check's corrected site counts 2,124 / 1,770 / 708; the four-leaf layout-builder measurement became the first step of the plan |
| **B-7** | SO-7 | the proposal to restate D18 is deleted; SO-7 now records what the register's scoping note says (see S-1) |
| **B-8** | PO-1, §2.7 | the hash recommendation is withdrawn; RPO and Poseidon2 are presented side by side with the corrected figures (see S-7) |
| **E-1** | §2.7 | Rescue-Prime Optimized: ≈42 → **12.00** committed values per absorbed element (96 degree-7 constraints ÷ rate 8) |
| **E-2** | §2.3, §2.7 | Monolith-64: ≈38 → **60.0** committed (witness 480 ÷ 8); lookups 24.0 confirmed |
| **E-3** | §2.3, §2.7 | Tip5: geometry corrected to w16 r10 c6, committed ≈30 → **38.0**; Tip4′ (w12, 20 lk / 45 values) added as the width-12 Tip variant |
| **E-4** | §2.2 | "every Goldilocks design in the literature uses `x⁷`" corrected — Monolith-64's Bricks layer is degree 2 |
| **E-5** | §2.0 | the mask-row budget is `512 − 256 = 256` coefficients from `M`'s fixed geometry, identical at every `log_cols`; the "a mask row holds 256 elements at the tiny profile" derivation is removed. Conclusion (degree 7 fits on the CPU) unchanged |
| **E-6** | §2.0, §2.1 | tables are pinned at 256 entries in this profile (`LOG_N = 8`); the 2^16 XOR/AND tables §2.1 assumes need a new table domain |
| **E-7** | §2.5 | "cannot be expressed without a new primitive" corrected: a shift is **not implemented**, not inexpressible; adding it is an additive access mode + `ZPart` variant + `mask_eval` |
| **E-8** | §3.3, §3.4 | mask rows are committed rows and are now counted in volume: two Mistral endpoints are ≥ 0.72% / +0.42 s even at the old flat site count |
| **E-9** | §3.4 | 125M row replaced by the corrected band 7.4–50% words / +0.34–2.39 s / 2.83–19.6% bytes, ×7.62 if host-side |
| **E-10** | §3.4 | tiny shape: up to **105% of the whole receipt** in layout A with level-wise sites |
| **E-11** | §3.2, §3.4 | the gadget's own zero-check is added to the headline: 4.7 × 10¹⁰ (A) / 2.7 × 10¹⁰ (C) mul-adds per endpoint = +0.3…+4.7 s |
| **E-12** | §3.4 | denominators labelled: words and seconds are the **public** pass, bytes the **private** proof; the public-against-private comparison with D18 is withdrawn |
| **E-13** | §3.4 | the headline no longer leads with a layout the memo declines; the layout choice is deferred to measurement |
| **E-14** | §0 item 1 | "+11% to +23% of that receipt's bytes" removed (it appeared nowhere in §3.4) |
| **E-15** | §2.6, §3.1, §4.1(1) | "the packing is free" is true of the tiny `private_block` path only; on the layer prover the input endpoint has no byte limbs (+0.04% words, +0.09% lookups to add, and the lookup column stops being zero) |
| **E-16** | PO-2 | SHA-256 would **not** make the two lines' handles the same object: different limb order, different signed encoding, and D7 also absorbs a model digest and the element count |
| **E-17** | §4.3 | "a relation's degree does not enter that model at all" corrected — degree enters through the masked-round channel (9 `Fp2` per round against 5; `L = n_vars·d + 2` changes `dim C_s`); the pad-budget arithmetic is added |
| **E-18** | SO-6 | a 31–32-bit field does not invalidate `x⁷` (it permutes BabyBear); the *instance* changes, and the real coupling is cost: capacity ≥ 9 at 31 bits against 4, plausibly 2–3× the gadget |
| **E-19** | §2.0 | the LogUp helper relation is cited at `argument.rs:483`, not `:596-597` |
| **E-20** | §6 M4 | M4 names its module: `private_block` has no GPU path, and the degree-8 kernel question is an explicit precondition |
| **C-1** | §2.5, §7.1 (missing decisions) | salt in the capacity (IV) of every node, not one leaf's message, with the reason and the zero-permutation cost |
| **C-2** | §1.1, §4.1(2) | salt generation: 4 **uniform** field elements, not 64 random bits reduced mod `p` (D9's recorded reduction bias); attestable generation recorded per S-4 as a hardening |
| **C-3** | §7.1 PO-1, §7.3 | read eprint 2026/306 in full and determine whether its attacked recommended set is the Goldilocks t = 12 one, before any hash acceptance is put to the project owner |
| **C-4** | §3.1 | the statement version must pin the packing map: which signed encoding (the module has at least three), which limb order, which tiling |
| **C-5** | §3.1 | above the tiny shape the endpoints are re-tiled under D17 rule 1, and the tiling must be part of the pinned map or a third party cannot reproduce the handle |
| **C-6** | §0 item 1, §3.4, SO-7, §7.3 | D18's "+12.6% private" is recorded as having no published derivation and not reproducible — unverified |
| **C-7** | §4.3, §7.1 (missing decisions) | a code assertion that `Coord` challenge indices are unique per plane, before the first gadget slot |
| **C-8** | §5, SO-9 | ask for a D12 amendment naming handle-chaining as a distinct, non-block composition form |
| **C-9** | §5, PO-4 | a salt lifecycle: transport and its authentication, storage, rotation, destruction, re-sealing, and the availability failure |
| **C-10** | §5, PO-3 | linkage is retroactive and permanent, and any two consecutive parties in a `K`-run chain can confirm a third party's guess |
| **C-11** | §4.3 item 5, SO-5 | a second negative control that tests the model, not only the tool |
| **C-12** | §6 (new M0), §3.5 | the four-leaf layout-builder measurement runs first |
| **C-13** | §4.1(4), §7.3 | the timing/size side channel is stated deliberately |
| **S-1** | §0 item 1, §2.5, §2.7, SO-7 | "a binary tree is forced" and "D18's figure is two times low" withdrawn everywhere; overhead is `1 + 1/k`; the proposal to restate D18 is deleted and replaced by what the register's scoping note says (public figure follows from its basis; private figure unverified) |
| **S-2** | §1.1, §1.5, §2.5 | the handle's input encoding gains element count, tree shape, leaf/internal separation and a padding rule, on the model of `zkvm-block/statement/src/lib.rs:65-78` |
| **S-3** | **new §1.4** | the two-layer handle added as the security owner's direction, priced by counting, marked unchecked, with "How to attack this" |
| **S-4** | §1.1, §5, PO-4 | the sealer's threat model written as the ruling states it: who the sealer is in each deployment, the sealer holds the plaintext, a malicious prover can always publish its witness, 256 fresh bits per handle never reused and never derived from the plane, an unverifiable salt is worth the sealer's diligence, attested generation a hardening and not a requirement |
| **S-5** | §2.0, §2.2, §2.7, §3.4, §6 | the GPU degree cap stated; the split form is the default pricing; every GPU-denominated figure carries the missing-kernel condition |
| **S-6** | §2.5, §3.2, §3.3, §3.4, §6 M0 | one wiring priced consistently at the check's corrected site counts; the four-leaf layout-builder measurement is step one |
| **S-7** | PO-1 | the memo recommends **no hash**; RPO and Poseidon2 side by side with the corrected figures; the cryptanalysis stated exactly as the check reports it and labelled as the check's, not the security owner's; an all-standard-hash handle priced beside them as the conservative alternative with the honest statement that no byte-hash cost figure could be confirmed; the choice is a project-owner security acceptance taken when the option is scheduled, with the literature read again that week |
| **S-8** | §5, PO-3, SO-9 | the D12 amendment it needs, and the plain-words warning that linkage is public, retroactive and permanent and that a party who guesses a low-entropy plane and knows the salt can confirm the guess |
| check §9.1 (filing) | SO-3 → PO-3b | the check asked for two items to be re-filed. **SO-3 is moved** to a project-owner ruling, because adding a second cryptographic assumption is a D3/D4-class decision and SO-3's own reason says "record it as two assumptions, not one". **PO-5 is left where it is**, which the check itself calls harmless and arguably correct as a spend ruling |
| check §9.5 (missing decisions) | new §7.1a | the nine decisions with no owner are listed, each cross-referenced to where this revision covers it |
| status line | top of file | replaced with the disposition's wording |
| §7.4 | §7.4 | rewritten: what the check settled (parameters confirmed, metric not a published one, no byte-hash figure confirmable), what it answered unfavourably (the GPU cap, the site count), what is still unchecked |

**Items that needed no change.** None of B-1 … B-8, E-1 … E-20 or C-1 … C-13
was found already satisfied; every one required text. Three are recorded as
applied *in the form of the ruling rather than the check's*, because the
ruling wins: **B-3/C-2** (S-4 replaces the check's demand for an attestable
salt mechanism with a threat model plus attestation as a hardening),
**B-8/C-3** (S-7 replaces the check's "recommend Rescue-Prime Optimized" with
"recommend no hash, present both, and treat the choice as a project-owner
acceptance"), and **B-4/B-7** (S-1 deletes SO-7's restatement of D18 rather
than rewriting it).

**(revision complete)**
