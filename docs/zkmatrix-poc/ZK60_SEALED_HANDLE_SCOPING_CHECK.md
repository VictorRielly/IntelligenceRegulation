# Check of the sealed-handle scoping memo

**INDEPENDENT ADVERSARIAL CHECK of a delegated draft — delegated Opus agent,
2026-09-19. Not a privacy acceptance.**

Target: `ZK60_SEALED_HANDLE_SCOPING.md` (1,319 lines, commit `d22a60f`).
Evidence, scripts and recomputations: `results/zk60_sealed_handle_check/`.
Nothing was built, run or measured; no file outside this document and that
directory was written. Labels used throughout: **VERIFIED IN THE CODE**
(file:line), **VERIFIED IN A PUBLIC SOURCE** (URL + figure), **RECOMPUTED**
(my arithmetic, script named), **COULD NOT VERIFY**.

---

## 0. Verdict in one paragraph

**The construction survives; the memo's numbers, its hash recommendation and
its correction to the decisions register do not.** What survives is the
important part and it is genuinely good work: the sealer holds the *witness*
(plane and salt) and no commitment randomness, which is precisely the hole
D8/D11 record, so a salted handle really does move the sealed-in-advance case
into a configuration those obligations do not bind — and the draft says three
times, correctly, that this does not close them. The chaining argument is
sound in its mechanics and dissolves a recorded blocker. Against that: the
memo's single most emphasised structural finding is wrong — a binary tree is
**not** forced and the missing shift costs `(1 + 1/k)`, not 2×, so the proposed
2× correction to D18 must not be written into the register; the hash the memo
recommends is the **more** expensive of the two zero-lookup candidates
(Rescue-Prime is 12.0 committed values per absorbed element against Poseidon2's
14.75, not 42 against 29.5), and it is the one carrying a Feb-2026 attack paper
and an August-2026 Ethereum Foundation abandonment; the prover's **CUDA
zero-check is hard-capped at degree 4**, exactly the hidden cost the draft's
§7.4 predicted, so the recommended degree-7 S-box has no GPU kernel and the
module it would be built in has no GPU path at all; and the cost table prices
128 claim sites flat after saying two pages earlier that it prices the form in
which sites multiply by the tree's depth, which understates proof bytes by
2.9× at Mistral, 6.4× at 125M and 5× at the tiny shape — where one endpoint's
gadget would exceed the whole receipt. On the security side the assumption is
mislabelled (a keyed mode of a primitive analysed only unkeyed), the hash input
drops the length that D7's own version absorbs and the tree has no shape
separation, so collision resistance does not hold as written, and the malicious
sealer — who chooses the salt, and who in the chaining design *is the upstream
prover* — is not in the threat model. Every one of the draft's own arithmetic
cells reproduced exactly; the drafter's self-flagged worry about the Poseidon2
round numbers was unfounded (8 full + 22 partial and 118 S-boxes are confirmed
four ways). Fix B-1…B-8 and add C-1…C-13 and this becomes a usable scoping
memo; as it stands it should not be quoted, and none of it is a privacy
acceptance.

## 1. The statement and the assumption (H-hide)

### 1.1 What survives, and it is the load-bearing idea

The draft's central security move is **right**, and it is worth stating
plainly because the rest of this section is critical. D8/D11's hole was never
that a third party knows the hidden value — it was that a third party who
*builds a polynomial commitment* holds the tree's per-leaf salts and pads, and
can therefore rebuild the tree and catch the simulator's programmed node
(`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md:24-29`). A zero-knowledge simulator
is allowed to be run against a distinguisher that knows the **witness**; it is
not allowed to be run against one that knows randomness the simulator itself
has to produce. Under the handle the sealer holds `(plane, salt)` — the
witness — and no commitment randomness at all. That distinction is real, it is
the whole content of the construction, and the draft gets it right.

The draft is also honest three separate times (§0 item 3, §1.3 caution 3,
§7.3 item 1) that this **does not close D8 or D11**. Correct, and it must stay
that way in any restatement.

### 1.2 Where "the standard commit-and-prove game applies" is too comfortable

**CORRECTION.** Today's receipts contain no public value that is a function of
the hidden plane which the prover did not choose: every root is fresh and
prover-generated, so a simulator may simply invent one. A handle is the first
object in this project that is (a) public, (b) a deterministic function of
hidden data, and (c) **fixed before the simulator runs**. The simulator's job
therefore gets strictly harder, not easier: it must fake a whole transcript
for a statement string it cannot choose, which is ordinary NIZK simulation but
is *more* than "the simulator produces the commitments" buys. Saying the
configuration moves to "the standard commit-and-prove game" is true and
incomplete; the sentence a reader will quote should be "it moves to the
standard game **and** adds a statement the simulator must live with".

Two further limits the draft does not state:

* NIZK simulation says nothing about whether the **statement** leaks. That is
  entirely carried by (H-hide), which is not a NIZK property and has no
  reduction for any algebraic candidate. The draft says this in §1.3; it
  should also say it wherever it says D8/D11's problem "disappears" (§0 item
  3), because one unproved thing is swapped for another unproved thing, not
  for nothing.
* Game J's simulator does not exist (`ZK60_ENDPOINT_SIMULATION_MODEL.md:76`),
  so no version of this is discharged today. The draft says so.

### 1.3 "Random-oracle hiding" is not an honest model for an algebraic permutation used with a secret key

**BLOCKING (B-1).** The draft models `H` as a random oracle, gets
`advantage ≤ q·2^-256`, and then recommends a **Poseidon2-shaped algebraic
permutation**. Those two halves do not fit together, for a reason sharper than
"algebraic hashes are newer":

1. The published analyses of Poseidon2, Rescue-Prime Optimized, Monolith and
   Tip5 are for an **unkeyed public hash**: collision resistance, preimage
   resistance, CICO. The handle uses the primitive in a **keyed** mode — a
   secret 256-bit salt is the only thing between a public digest and a
   low-entropy message. That is a PRF/keyed-sponge claim, and
   **VERIFIED IN A PUBLIC SOURCE (`sources.md` item 2, eprint 2023/323 §2)**
   the sponge bound the draft leans on is explicitly conditioned on an **ideal
   permutation**: *"indifferentiable from a random oracle up to around
   `p^(c/2)` queries"*. It says nothing about algebraic structure. Algebraic
   attacks are at their strongest exactly in the setting the handle creates:
   a known output, a known low-entropy part of the input, and a small unknown
   algebraic block to solve for. No published keyed-mode analysis of any of
   these permutations was found.
2. So the honest label is not "a random-oracle assumption on a new primitive"
   (§1.3) but **"a keyed-mode assumption on a primitive analysed only in
   unkeyed mode"**, which is a strictly weaker starting point and which the
   project owner must be told in those words.

The draft's ROM arithmetic itself is fine as far as it goes: `q·2^-256` for
one handle, and `q·N·2^-256` multi-target over `N` handles — which is why 256
bits rather than 128 is the right call. **RECOMPUTED**: at 128 bits and the
64 handles of a 32-layer feed-forward pass the multi-target term is
`q·2^-122`, so the draft's reasoning for 256 bits is sound.

### 1.4 The salt's position in the tree — the concrete finding the brief asked for

The draft puts the salt **"into the leftmost leaf (or a dedicated initial-value
block)"** (§2.5). Working out exactly what is exposed:

* **Only the root `h` is public.** Internal nodes and the other leaves' digests
  are committed planes inside the proof; nothing publishes them. So there is
  **no chunk-by-chunk brute force from public data**, and the draft is not
  broken on that axis. Recorded as checked, because it is the obvious attack.
* **But every leaf except the first is then an unsalted hash of a 32-byte
  chunk of an activation plane**, and those digests' secrecy rests on the very
  PCS-hiding hypotheses the project has not discharged (H-pad, H-pair, H-prox,
  the `ZkRng` PRG assumption, salted-leaf hiding of unopened columns). A
  failure anywhere in that stack degrades **chunk-locally and irreversibly**:
  one leaked internal digest is a 32-byte dictionary attack, and activation
  chunks are highly structured. It also makes **equal chunks detectable**: two
  planes sharing a 32-byte chunk produce an identical leaf digest, so anyone
  who can see internal nodes learns repetition structure.
* **The fix is free.** Put the salt in the **capacity (initial value) of every
  node**, not in one leaf's message. Capacity is 4 Goldilocks elements = 256
  bits — exactly the salt's width — and it is initialised to a constant today,
  so keying every node costs **zero extra permutations**. Domain separation
  and the node index then move into the rate or the round constants.
  **Condition C-1.**
* The alternative of absorbing the salt as message into every leaf costs 4 of
  the 8 rate elements and would **double** the permutation count. The draft
  costs neither option.

### 1.5 Binding: two omissions that break collision resistance as specified

**BLOCKING (B-2).** §1.4 of the draft correctly says collision resistance
against the prover is load-bearing. The specified handle cannot deliver it:

* **No length / element count.** **VERIFIED IN THE CODE**
  (`zkvm-block/statement/src/lib.rs:65-78`): D7's zkVM handle absorbs
  `h.update((ELEMENTS as u32).to_le_bytes())` before the values. The draft's
  formula `h = Hash(tag ‖ context ‖ role ‖ salt ‖ pack(plane))` **drops it**,
  and the draft's own prose describing the zkVM version lists it. Without a
  length, planes of different sizes collide trivially under any padding rule.
* **No tree-shape or frame separation.** A tree hash needs leaf/internal
  domain separation and a shape encoding (the Sakura-style discipline) or a
  node digest can be reinterpreted as message and different trees collide. The
  draft specifies a binary tree with none of this, and it specifies no padding
  for a ragged last chunk. The §2.5 sentence *"the tree is domain-separated
  and salt-dependent from the first compression"* is about the **message**
  domain tag, not about the tree, and does not supply either.

Both are cheap to fix in the specification and both must be fixed before any
number in the memo is quoted as a security property.

### 1.6 The malicious sealer — out of scope in the draft, and it must not be

**BLOCKING (B-3).** The draft's threat model has an honest sealer throughout
("the sealer, from OS randomness", §1.1). A sealer that knows the plane learns
nothing more, so the draft treats it as uninteresting. That is the wrong
question. **The sealer chooses the salt, and the salt is the only thing
protecting the prover's data.** A sealer that is honest about the plane but
adversarial about the prover's privacy can:

* reuse a salt across handles, making them linkable and dictionary-attackable
  together;
* derive the salt from the plane, destroying (H-hide) entirely while looking
  well-formed from outside;
* **grind the salt so that `h`'s low bits encode chosen information about the
  plane** — a covert channel in a value the product presents as revealing
  nothing.

This is not hypothetical in the chaining design of §5, where the "sealer" of
each boundary handle **is the upstream prover**, i.e. exactly the party whose
honesty the receipt is supposed not to require. The memo needs a stated
mechanism (for example a salt derived as `PRF(sealer key, context ‖ role)`
with the key's uniqueness attested, or a salt contributed by both parties —
though the latter gives up sealing in advance) and a ruling on what an
unverifiable salt is worth. **Condition C-2.**

### 1.7 Three smaller items on the assumption

* **Retroactive de-anonymisation, not stated.** A handle is a *stable*
  identifier: the same plane under the same salt always gives the same `h`,
  where two commitment roots for the same plane are always different. One salt
  leak therefore makes **every handle ever published under it checkable, for
  ever**, and the plane's low entropy makes checking cheap. That is a
  materially different exposure profile from a commitment root and belongs in
  PO-4.
* **Salt sampling.** "256 fresh random bits — 4 Goldilocks field elements"
  needs the elements sampled uniformly in `[0, p)`, not 64 random bits reduced
  mod `p`; the project has a recorded reduction bias for exactly this
  (D9, `ZK60_DECISIONS.md:371-410`). One line in the spec.
* **Timing and size.** The gadget's cost depends on the plane's *shape*, which
  is public, and on no plane *value* — the arithmetic is straight-line. So no
  new data-dependent side channel, provided the packing of signed values is
  branch-free. Worth asserting rather than assuming; the draft does not
  mention it and D7 already declares timing leakage as a qualifier.

## 2. "No shift operator, so a tree is forced, so D18's figure is 2× low"

### 2.1 What the code says

**CONFIRMED, VERIFIED IN THE CODE.** `Coord` is
`Rho(usize) | Flip(usize) | Fixed(Fp2)` and nothing else
(`hashline/src/private_block/argument.rs:46-53`; a byte-identical copy at
`private_attention/argument.rs:42-49`). `claim_point`
(`argument.rs:151-160`) maps `Rho(k) → rho[k]`, `Flip(k) → 1 − rho[k]`,
`Fixed(f) → f`. So the expressible index maps are **signed bit permutations**
(a permutation of the plane's bits, plus a single-bit complement) together with
partial evaluation. No plane bit can depend on two slot bits; there are no
carries; arbitrary affine maps are **not** expressible.

**CONFIRMED.** No `i → i+1` relation exists anywhere in `hashline/src` or
`zkp-core/src`. Every candidate the brief named turns out to be something else:
the causal mask is a public table over two independent variables
(`attention.rs:1884-1895` is an `O(T)` trick for evaluating that public MLE);
the softmax row sum is a whole-axis sum (`argument.rs:606-615`); byte-limb
recomposition is **across separate planes at the same index**
(`argument.rs:719-721`, `l2/l4` over plane ids `A_XL0`, `A_XL1`, …), never
between neighbouring indices; every `shift` in the tree is numeric
requantisation and every `rotate` is the RoPE bit complement.

**CONFIRMED, and it matters for the tree.** `Coord::Fixed` carries an arbitrary
`Fp2`, so it can be the constant 0 or 1: `priv_table` builds
`eq_table_msb(&fixed)` over the fixed coordinates
(`argument.rs:163-182`), which at 0 and 1 selects the even and odd halves
exactly as the draft's §2.5 says. The binary tree's parent–child wiring **is**
expressible. Good.

### 2.2 "A new primitive is needed" — contradicted

**CORRECTION.** A shift is **not implemented**; it is not excluded by the
arithmetisation. Three facts decide it:

* the sumcheck prover is table-generic — it takes arbitrary `Vec<Fp2>` tables
  and an arbitrary closure, and the round loop would not change
  (`zkp-core/src/sumcheck.rs:47-131`);
* the PCS's linear test already accepts an **arbitrary column-weight vector**:
  `let got = v[..n].iter().zip(cw.iter())…` (`zkp-core/src/pcs.rs:976`), and
  row weights are already arbitrary;
* the project's own `MaskFunctional` uses arbitrary weights today
  (`hashline/src/zk.rs:394-398`).

The eq-only restriction lives only in `zkey_weights` (`pcs.rs:794-805`) and in
`ZPart` carrying a `point` (`:719-725`). Adding a shifted access is a new
access mode in `priv_table`/`table_of`, a weight-vector `ZPart` variant (each
shifted access becoming its own opening group and mask pair) and a matching
arbitrary-weight `mask_eval` (`argument.rs:210-219`). That is an **additive
change of exactly the kind D17 rule 2 already contemplates**, not a new
primitive class. The draft's §2.5 sentence *"cannot be expressed in this prover
without a new primitive"* overstates a real gap.

### 2.3 The factor of two is not forced at all — and this is the memo's biggest structural error

**BLOCKING (B-4). RECOMPUTED** (`results/zk60_sealed_handle_check/recount.py`
§E, `corrected_model.py` §2). The doubling is an artefact of choosing leaves
that absorb **one** rate block each. Unroll `k` sequential absorptions inside
one leaf — permutation `j` of leaf `i` is its own plane family, chained to
permutation `j+1` **at the same hypercube index `i`**, reading message elements
at a constant offset inside the chunk, i.e. `log2(8k)` variables pinned by
`Coord::Fixed`. No shift, no gather, no new primitive:

| `k` permutations per leaf | permutations vs a linear sponge |
|---:|---:|
| 1 (the draft's tree) | **2.000** |
| 2 | 1.500 |
| 4 | 1.250 |
| 8 | 1.125 |
| 64 | 1.016 |

So the price of the missing shift is `(1 + 1/k)` with `k` free, traded against
`k` extra plane families (§6 finds the optimum near `k = 2…4` once claim sites
are counted). **Both conclusions the draft draws from the forced tree fall:**

* "a binary hash tree is forced, doubling permutations" — false;
* "D18's figure is 2× low" — false. **RECOMPUTED** (`corrected_model.py` §7):
  on D18's own per-compression basis the correct figure is **+5.6% to +6.2%**
  of a public pass at `k = 64…8`, against D18's recorded **+5.5%** and the
  draft's proposed **+11%**. D18's number is right to within ~13% on this
  account.

There is a *separate* and unapplied reason to doubt D18's figure: the draft's
own §2.1 count is **≈12,800 lookups per SHA-256 compression** against the
record's 4,000, and says so ("about 3× low for SHA-256") — yet §2.7's table and
SO-7 both keep the record's 4,000 and apply only the (wrong) tree factor.
**RECOMPUTED**: the drafter's own count with a linear chain gives **+10.3%** of
a public pass. The near-agreement between that and SO-7's "+11%" is a
coincidence of two unrelated errors, and SO-7 must not be adopted as written.

## 3. The hash comparison against the literature

Verified by a delegated literature lane against public sources only; full
quotes, URLs and figures in `results/zk60_sealed_handle_check/sources.md`.
Nothing from this repository was sent to any external service.

### 3.1 The parameters the whole memo rests on: CONFIRMED

The drafter flagged "8 full + 22 partial rounds at width 12 → 118 S-boxes" as
the most likely place the memo is wrong. **It is right.**

| claim | status | source |
|---|---|---|
| Poseidon2 Goldilocks width 12: `R_F = 8`, `R_P = 22` | **CONFIRMED** (4 independent sources) | eprint 2023/323 Table 1 p.16, row `(64, 12, 7) 8 22`; Plonky3 `GOLDILOCKS_POSEIDON2_HALF_FULL_ROUNDS = 4`, `..._PARTIAL_ROUNDS_12 = 22`; HorizenLabs `Poseidon2Params::new(12, 7, 8, 22, …)`; Monolith App. D.2 |
| `8·12 + 22 = 118` S-boxes per permutation | **CONFIRMED** twice over | arithmetic; and Monolith Table 4 lists Poseidon2 sponge at *"0 lookups, 118 nonlinear constraints, degree 7, witness 118"* |
| S-box is `x⁷` for Goldilocks | **CONFIRMED** | Plonky3 `GOLDILOCKS_S_BOX_DEGREE: u64 = 7`; same `d = 7`, `R_F = 8`, `R_P = 22` at widths 8, 12, 16, 20 |
| `x⁷` is a permutation, `x³` and `x⁵` are not | **CONFIRMED, RECOMPUTED** (`recount.py` §A) | `p − 1 = 2^32 · 3 · 5 · 17 · 257 · 65537`; `gcd(3, p−1) = 3`, `gcd(5, p−1) = 5`, `gcd(7, p−1) = 1`. 7 is the smallest permutation power |
| capacity 4 over Goldilocks gives ≈128-bit collision resistance | **CONFIRMED with a caveat** | eprint 2023/323 §2: *"indifferentiable … up to around `p^(c/2)` queries. Equivalently, in order to provide κ bits of security, `p^(c/2) ≥ 2^κ`"*. RPO Table 1 and Monolith Table 1 both claim λ = 128 at width 12 / capacity 4. **Caveat:** the bound assumes an ideal permutation, the real level is `min(capacity bound, digest bound)`, and 2023/323 also caps κ at `p^(t/3)` |

One footnote for anyone re-deriving: **re-deriving `R_P` from the paper's
Eq. (1) first term alone gives 21, not 22** — the published value comes from
the Gröbner branch of the maximum. Not a defect; a trap.

**CORRECTION (minor).** *"every Goldilocks design in the literature uses `x⁷`"*
(§2.2) is false: Monolith-64's Bricks layer is degree 2, and its nonlinearity
is the lookup Bars layer.

### 3.2 The other four rows of §2.7: three are wrong, one geometry is wrong

Every "committed values per absorbed element" figure below is Monolith Table 4's
witness size ÷ rate — the only source that compares these designs on one
arithmetisation. Figures **undoubled** (the tree factor is handled separately
per §2.3).

| design | lookups / absorbed elt | committed / absorbed elt | draft §2.7 (tree-doubled) | verdict |
|---|---:|---:|---|---|
| Poseidon2 w12 r8 | 0 | **14.75** | 0 / 29.5 | **CONFIRMED** (29.5 = 2 × 14.75) |
| Rescue-Prime Optimized w12 r8 | 0 | **12.00** | 0 / 42 | **CONTRADICTED — 3.5× too high** |
| Monolith-64 w12 r8 | **24.0** | **60.0** | 24 / 38 | lookups **CONFIRMED**; committed **CONTRADICTED** |
| Tip5 **w16 r10 c6** | **16.0** | **38.0** | 16 / 30 at "w12 r8 c4" | lookups **CONFIRMED**; committed **CONTRADICTED**; **geometry wrong** |
| Tip4′ w12 r8 | 20.0 | 45.0 | absent | this, not Tip5, is the width-12 Tip variant |

* **Rescue-Prime is the big one.** RPO (eprint 2022/1577) Table 1: `N = 7`,
  `α = 7`, `m = 12`, `r = 8`, `c = 4`, `λ = 128`. Raw S-box *evaluations* are
  `2·7·12 = 168`, which is where the draft's 21-per-element (doubled to 42)
  comes from — but the **arithmetisation is far cheaper**, because the inverse
  half is *verified* (`y⁷ = x`), not evaluated: Monolith App. D.2 records
  *"degree-7 constraints spanning a whole round of rescue, leading to 96
  degree-7 constraints in total"*. `96 / 8 = 12.0`.
  **This inverts PO-1.** Rescue-Prime is not "the conservative alternative at
  roughly 1.4× the cost"; it is **19% cheaper than Poseidon2 on committed
  volume, with zero lookups, an older and more carefully argued design, and a
  published round-count formula.** It dominates Poseidon2 on both axes the
  memo cares about. *(Two costs RPO does carry and the memo would have to add:
  its prover must compute `x^(1/7)` per S-box — **RECOMPUTED** ≈ 2.2 × 10⁹
  host field multiplications per Mistral endpoint, order 0.1–2 s depending on
  cores; and RPO ships `N = 7` where its own formula gives 8, a deliberate
  12.5% margin cut stated in RPO §4.2.)*
* **Monolith's "38"** is Tip5's number transposed: `380 / 10 = 38.0` exactly.
  Monolith's own witness is 480, so **60.0**. Its lookups (24.0 = 6 rounds ×
  4 Bars × 8 bytes ÷ rate 8) are right.
* **Tip5's geometry.** Tip5 Table 1: `N = 5`, `m = 16`, `r = 10`, `c = 6`,
  digest 5, `α = 7`, 4 split-and-lookups per round. The lookup figure 16.0 is
  right **only because the rate is 10**; the draft got the right number from
  the wrong shape.

### 3.3 Cryptanalysis: no break, but two things the project owner must be told

**No published attack breaks `R_F = 8 / R_P = 22`, and nobody recommends
raising the round numbers.** Details, all with URLs in `sources.md`:

* **Ethereum Foundation Poseidon Cryptanalysis Initiative** (launched Nov 2024):
  bounties target deliberately round-reduced instances. Deepest reach over a
  64-bit field is `R_F = 6, R_P = 12` (zero-test, Jul 2026); CICO reached
  `R_F = 6 / R_P = 10`. Margin against 8/22 is 2 full + 10 partial rounds — but
  **the partial-round reach moved from 7 to 12 in about two months**, and the
  programme was **paused 1 Aug 2026**. The site issues no round-number
  recommendation and states no conclusion that the parameters are adequate:
  citing it as an endorsement would be over-reading it.
* **⚠ eprint 2026/306** (Merz & Rodríguez García, 18 Feb 2026), *"Skipping
  Class: Algebraic Attacks exploiting weak matrices and operation modes of
  Poseidon2"*: exploits linear-layer matrix structure, is the first case where
  preimage-finding beats CICO and the first algebraic collision attack beating
  its preimage counterpart, and **improves collision attacks on a recommended
  128-bit parameter set by 2^106**. The authors state the primitive does not
  fall short of its claimed level and propose mitigations.
  **COULD NOT VERIFY whether the attacked recommended set is the Goldilocks
  t = 12 one.** This is the single most important open question in the memo's
  security case and it must be read in full before PO-1 is put to anyone.
  **Condition C-3.**
* **Ecosystem signal, CONFIRMED.** On 13–14 Aug 2026 the **Ethereum Foundation
  dropped Poseidon from the L1 roadmap in favour of SHA-256/BLAKE3** — on
  performance-convergence grounds, with no deployed parameter set broken.
  Nothing about that is a cryptographic finding, but it removes the premise
  PO-1 leans on: the largest funder of Poseidon cryptanalysis no longer plans
  to depend on it, so "heavily scrutinised because Ethereum needs it" should be
  **discounted going forward**. The project owner is being asked to adopt a new
  hash assumption in the same quarter the biggest adopter walked away from it.
  That belongs in the ruling.
* eprint 2023/537's HADES Gröbner objection applies at the 384-bit level, not
  here. The Graeffe line (2025/937, 2025/950, 2025/1916) speeds up challenge
  solving but reports memory access as the binding barrier.

### 3.4 What the literature lane could not establish

* Whether 2026/306's target set is Goldilocks t = 12 (above).
* **"Committed values per absorbed element" is not a published metric.** Every
  number in §3.2 is Monolith Table 4's witness size ÷ rate, and Monolith itself
  calls those *"non-optimized arithmetizations … subject to change"*. A
  different AIR gives different numbers. Do not treat 12 / 14.75 / 38 / 60 as
  constants — they are one paper's comparison.
* No Plonky3 document making its own numeric sponge-security claim.
* No BLAKE3 arithmetisation cost figure at all, and no byte-decomposed SHA-256
  AIR figure (the nearest anchor is Zcash halo2's `table16`: ~24 lookups per
  compression round, ~2,099 rows per compression, over a 2^16 *spread* table —
  a different representation from the draft's byte-limb one). So **the draft's
  §2.1 SHA-256 and BLAKE3 counts are unverified in both directions**, and so is
  the record's 4,000.

## 4. Degree 7 in this prover

### 4.1 On the CPU it fits — but the draft's reason is wrong

**CONFIRMED.** A degree-`d` sumcheck sends `d + 1` `Fp2` values per round
(`zkp-core/src/sumcheck.rs:73`, `:147-150`). The CFS mask length is
`L = n_vars·d + 2`, **verbatim** at `zkp-core/src/sumcheck.rs:197-199`, with
`n_vars` counting main plus extension rounds (`layout.rs:533-535`). The slot
constraint is `assert!(part.len() + MASK_Q <= m)` at `hashline/src/zk.rs:442`,
mirrored by `layout.rs:728-734` (`n·d + 2 + 256 <= 512`, *"the largest is
SC_SZC at 50"*). **No degree cap exists on the CPU path.**

**CORRECTION.** The draft's §2.0 reasoning — *"At the tiny profile a mask row
holds 256 elements, so a degree-8 slot over 21 variables (`21·8 + 2 = 170`)
still fits"* — is wrong about the geometry, though right in its conclusion.
**VERIFIED IN THE CODE** (`zk.rs:373-375`): the mask commitment `M` has a
**fixed** geometry of `MASK_LOG_MSG = 9` (512 message positions),
`MASK_LOG_DOM = 12` (4,096 evaluation positions), `MASK_Q = 256` pads —
**independent of `log_cols`**. So the budget is `512 − 256 = 256`
coefficients, i.e. `n_vars·d ≤ 254`, **identically at `log_cols` 8 and 14**.
This matters because the draft's version predicts the budget scales with the
row width; it does not.

**RECOMPUTED** from that: at `d = 7`, `n_vars` 19/20/21 gives `L` = 135/142/149
— all fit with 107–121 coefficient slots spare. Headroom is `n_vars ≤ 36` at
`d = 7`, or `d ≤ 12` at `n_vars = 21`. Today's worst case is `L = 50`
(`M_ROWS = 2·N_SLOTS + 4 = 2·23 + 4 = 50`, `layout.rs:519`, asserted `:708`,
matching `n_base` at `zk.rs:435`). **So x⁷ need not be split on the CPU
path.** Maximum degree in use today is 4 (`SLOTS`, `layout.rs:438-461`).

### 4.2 On the GPU it does not fit — the memo's biggest hidden cost, exactly where the draft said to look

**BLOCKING (B-5).** The draft's §2.0 states *"no cap was found anywhere in the
tree"*, and its §7.4 lists the GPU kernels as "the most likely hidden cost in
the whole memo". **VERIFIED IN THE CODE — there is a hard cap, and §7.4 was
right:**

```
#define SC_MAX_K 16
#define SC_DEG 4            <- hashline/src/gpu/kernels.cu:601
#define SC_THREADS 256
```

`SC_DEG` is baked into the kernels' register arrays and shared memory
(`kernels.cu:651, 654, 757, 763, 815, 820`) and into `scg_emit<SC_DEG + 1>`;
there is also a degree-3-specialised table kernel
(`hashline/src/gpu/cuda.rs:3152-3160`). A degree-8 slot (degree 7 × the `eq`
factor) needs 9 coefficients per round against today's 5, so the per-thread
register arrays and shared-memory footprint roughly **double** — on kernels
already tuned to an 8 GiB card that freezes the whole box when it spills
(`env-wsl-vram-freeze`).

**And the module the gadget is scoped into has no GPU path at all**: `grep gpu`
over `hashline/src/private_block/` is empty. The 4.649 s denominator the draft
prices the 125M case against is the **layer prover** on the GPU binary, a
different module. So §6's M4 ("the 512×768 endpoint inside the repaired private
profile, GPU binary") is not runnable as written: either the gadget goes into
`private_block` and runs on the host, or it goes into the layer prover and
needs a new degree-8 CUDA kernel.

**RECOMPUTED** (`corrected_model.py` §6b), using the project's own measured
host/GPU ratio for the private feed-forward at 12×512, `35.417 / 4.649 =
7.62×`: a gadget slot that runs on the host while the pass runs on the GPU
costs **7.6× the draft's estimate**. At 125M that is `+1.5 s` even on the
draft's own (understated) volume, and `+14…18 s` on the corrected volume of
§6 — **against M4's own kill threshold of 10% of the private pass.** On the
draft's numbers M4 passes comfortably; on the code's numbers it fails.

### 4.3 The fallback the draft dismissed in one line is probably the right answer

The draft weighs "degree 7 directly, one committed value per S-box" against
"degree ≤ 3 with an intermediate, two committed values per S-box" and picks the
first because committed volume dominates (§2.2). It made that choice **without
knowing about `SC_DEG 4`**. With the cap, the split form keeps the slot at
degree 4 (`t = x³` degree 3; `y = t²·x` degree 3; ×`eq` = 4) and therefore
keeps **every existing CUDA kernel**.

**RECOMPUTED** cost of the split form, per absorbed field element, before any
tree factor: Poseidon2 `2 × 118 / 8 = 29.5`; Rescue-Prime Optimized
`2 × 96 / 8 = 24.0`. That is a 2× committed-volume penalty in exchange for
running on the GPU at 7.6×. **On the measured numbers the split form wins by
roughly 3.8×**, and the plan should default to it, with the degree-7 form
reinstated only if a degree-8 kernel is written and measured. This reverses
SO-1's premise and changes M1's kill criterion.

## 5. "The packing is free"

### 5.1 The citations are real and say what the draft says

**VERIFIED IN THE CODE.** `layout.rs:318` and `:332` place both endpoints' byte
limbs in the `Dom::D` `U8` lookup list; `argument.rs:728`
(`x + 32768 − l2(A_XL0)`) and `:736` (`x2 + 32768 − l2(A_X2L0)`) are the
reconstruction constraints. The two external endpoints are `A_X` (input) and
`A_X2` (output, residual 2), per `argument.rs:905-907`.

**Injectivity holds.** The values are **signed int16**, mapped by
**offset binary / excess-32768 — not two's complement** (the literal
`k(32768)` plus two `U8` range checks *is* the int16 class statement,
`layout.rs:288-290`). Offset binary over `[−32768, 32767]` is injective; four
bytes reach `2^32 − 1 < p`; so `pack` is injective and cannot wrap.
**RECOMPUTED, confirmed.**

### 5.2 But the map is not the one a sealer would write, and it is not D7's

**CORRECTION.** The packed element the draft specifies is
`XL0[2j] + 256·XL0[2j+1] + 2^16·XL1[2j] + 2^24·XL1[2j+1]` — the *low* bytes of
two consecutive words followed by their *high* bytes, an interleaving forced by
reading two planes at an even and an odd index. That is **not** the natural
little-endian serialisation of two int16s, and it is **not** what D7 does:
`zkvm-block/statement/src/lib.rs:65-78` does `for v in values { h.update(
v.to_le_bytes()) }` over two's-complement `i16`s in order. Consequences:

* **PO-2 is wrong as written.** Even if the native handle used SHA-256, it
  would **not** be "the same object" as D7's zkVM handle: different byte order,
  different signed encoding, and D7 additionally absorbs a model digest and the
  element count. Interoperability costs a matched packing, which would give up
  the free byte limbs — so the interoperability option is more expensive than
  PO-2 says, not merely "the full bit-oriented price".
* The module contains at least **three** different signed byte encodings —
  `l2` offset-32768 for int16, `sym(p)` emitting both `v + 127` and `127 − v`
  for int8 (`layout.rs:274-276`), and `g8`'s offset-128 from the activation
  table (`argument.rs:777`). The statement version must name **which** map,
  **which** limb order and **which** tiling, or the sealer and the prover can
  disagree silently and the handle simply never matches. **Condition C-4.**

### 5.3 "Free" is true of one profile and false of the one the costs are quoted against

**CORRECTION.** The byte limbs the draft relies on exist in the **tiny
`private_block` profile**. The 125M and Mistral figures in §3.4 are quoted
against the **layer prover**'s measured pass — and D12 item 4 records, as a
fact the security owner re-checked in source, that *"the feed-forward prover
proves no range on its own input (verified in `hashline/src/layer.rs`: the
lookup list covers the activation, the two int16 planes and the output, never
the input plane)"*. The module header confirms the list (`layer.rs:11-14`:
`u8/h8/z in [-128,127]`, `rg/ru/rh/rd in [0, 2^sh)`; `X` is absent). So **on
the path the costs are quoted against, the input endpoint has no byte
decomposition and the packing is not free.**

**RECOMPUTED**, the cost of adding it is small but not zero: 2 limb planes per
int16 word, at Mistral `2 × 2,097,152 = 4.19 × 10⁶` committed words and
`2.10 × 10⁶` lookups per endpoint (helpers pairwise) — `+0.04%` of the pass's
words and `+0.09%` of its lookups. The *structural* cost is larger than the
arithmetic one: it puts the gadget's lookup column back above zero, which is
the single claim §2.7 uses to beat the bit-oriented candidates.

### 5.4 Above the toy shape

**Condition C-5.** D17 rule 1 requires any entry point above the pinned tiny
shape to bind the whole plane through the batched multi-block seam, so the
endpoint plane is **re-tiled**. The packing's index order is then a function of
the tiling, and the sealer — who has no proof, no layout object and possibly no
Rust — must reproduce it exactly. The draft's §1.1 says only "in a fixed
order". The tiling, the limb order and the offset constant must be pinned by
the statement version and covered by the M3 acceptance check 4 (the independent
Python reference), or the handle is not reproducible by a third party, which is
the entire point of the construction.

### 5.5 A table-size limit the draft's SHA-256 route runs into

**CORRECTION.** §2.0 says *"a public table is just a public vector handed to
the sumcheck, so a table of any size is expressible"*. In the profile the memo
builds in, tables are **pinned to 256 entries**: `LOG_N = 8` / `N = 256`
(`layout.rs:48-49`), `Dom::Tab => 8` (`layout.rs:103`), all three
`table_values_*` emit `N`, and it is checked per slot at
`argument.rs:280-282`. The 2^16-row XOR/AND tables the §2.1 SHA-256 and
BLAKE3 costings assume are **not** expressible there without a new table
domain. (A 2^16 table does exist on the separate public-weight FFN path,
`zk.rs:1943`, so it is a profile choice, not a system limit — but it is a new
domain, a new digest and a D17-rule-2 additive change, not something that
"already works".) Monolith's 2^16 Bars table hits the same wall; Tip5's
256-entry table does not.

Also verified for completeness: a lookup's argument is restricted to a
**linear** form over committed planes (`layout.rs:259-272`,
`argument.rs:459-475`), so a nonlinear function of committed values cannot be
looked up; and the LogUp helper relation is at `argument.rs:483`
(`h.mul(d1).mul(d2).sub(d1.add(d2))`, degree 3, degree 4 with `eq`) — the
draft's citation `argument.rs:596-597` is the *comment* stating the
consequence, not the code. Minor.

## 6. The costs

### 6.1 The draft's own arithmetic is flawless; the model underneath it is not

**RECOMPUTED, every cell** (`results/zk60_sealed_handle_check/recount.py` §C):
all thirteen rows of §3.3 and all of §3.4's percentages, seconds and byte
figures reproduce **exactly** from the draft's stated model, including the
64-endpoint vehicle (1.485 × 10⁹ values, 90,624 rows, 185.6 MB, 15.2%, +8.9 s)
and the tiny-receipt fractions (10.9% layout B, 20.8% layout A of 2,816,472 B).
The D18 basis reproduces too: `5.555 × 0.228 + 3.277×10⁸ / 1.67×10⁸ = 3.23 s =
5.5%`. No arithmetic error was found anywhere in the memo.

The errors are all in the model. Four of them, in order of size.

### 6.2 Error 1 — claim sites: the draft contradicts itself and prices the optimistic branch

**BLOCKING (B-6).** §2.5 says level-wise plane families multiply the claim-site
count *"by the depth (≈ 17 at Mistral width)"* and then says **"§3 prices the
level-wise form, which is the pessimistic one for sites"**. §3.2 and §3.3
price **128 sites flat, at every shape**. Those cannot both be true: 128 flat
is the *other* option (one plane family with a level axis), which §2.5 says
needs a public level-shift table and unquantified ragged padding.

**RECOMPUTED** (`corrected_model.py` §3): at Mistral a 131,072-leaf tree has 18
levels, so layout A's sites go 128 → **2,124**, and one endpoint's proof bytes
go 4,390,912 → **12,566,528 (×2.86)**. At 125M, 128 → 1,770 and
1,249,280 → 7,974,912 (**×6.38**). At the tiny shape, 128 → 708 and
585,728 → 2,961,408 — **105% of the whole 2,816,472-byte receipt**, against the
draft's 20.8%.

### 6.3 Error 2 — mask rows are committed rows, and are missing from every volume figure

**CORRECTION.** **VERIFIED IN THE CODE** (`layout.rs:523-526`, `:705`, `:778`):
`A_ROWS = 455 = A_DATA_ROWS 213 + 2 × 120 site pairs + 2 proximity`. A claim
site's reserved pair is **two rows of the data commitment**, `2^log_cols` wide
— at the tiny block the site pairs are already 53% of `A`. The draft counts
them in proof bytes and omits them from committed volume and therefore from
seconds. **RECOMPUTED**: even at the draft's own 128 flat sites, two Mistral
endpoints are **0.72%** of the pass's words and **+0.42 s**, not 0.63% and
+0.37 s; at 125M they are **7.39%** and **+0.34 s**, not 4.29% and +0.20 s.

### 6.4 Error 3 — the headline omits the gadget's own sumcheck, which the draft itself computes

**CORRECTION.** §3.2 computes layout A's zero-check at ≈3.2 × 10¹⁰ field
multiply-adds per Mistral endpoint and calls it *"the same order as the whole
pass's proven arithmetic"* — then §3.4's headline converts **committed words
only** to seconds at the whole-pass rate of 1.67 × 10⁸ words/s. The sumcheck is
never added. **RECOMPUTED** (`corrected_model.py` §6a, `k = 4`): layout A is
**4.66 × 10¹⁰** Goldilocks mul-adds per endpoint, layout C **2.67 × 10¹⁰** —
same order as the draft's own figure. At 10¹⁰–10¹¹ Goldilocks op/s that is
**0.5–4.7 s per endpoint** (A) or **0.3–2.7 s** (C), against a headline of
+0.37 s *for both endpoints together*.

Two further omissions of the same kind, both named by the draft and neither
costed: the host cost of generating and encoding the new mask rows (the MR1
lane found host mask work to be 53% of the repaired profile's *added* cost),
and the `7.62×` host penalty of §4.2 if the degree-7 slot has no GPU kernel.

### 6.5 Error 4 — mismatched denominators and a headline in a layout the memo does not recommend

* §3.4's "Mistral, 8B pass" row measures committed volume and seconds against
  the **public** 58.40 s / 9.777 × 10⁹-word pass, and proof bytes against the
  **private** 1.286 GB proof. They are different objects. The comparison the
  draft draws in §0 item 1 and §3.4 reading 1 — "+0.6–1.3%" against D18's
  "+12.6% private" — is therefore public-against-private.
* The headline numbers (+0.63%, +0.37 s, +4.29%, +0.20 s) are **layout A**,
  while SO-1 recommends **layout C**, which is 2× the volume and which §3.2
  itself argues for. A memo should not headline the layout it declines.
* §0 item 1 says "+11% to +23% of that receipt's bytes" at the tiny shape;
  §3.4's table says 10.9% and 20.8%. The 23% appears nowhere.
* **COULD NOT VERIFY: D18's "+12.6% private" is not reproducible.** The check
  it comes from states it at `ZK60_D8_D11_RESTATEMENT_CHECK.md:564` and
  correction 11 (`:827`) without a derivation, and no combination of the
  published denominators reproduces it: the natural ones give ≈5.5% (the same
  absolute cost against a pass that is 2.05× larger is a *smaller* fraction,
  not a larger one). Since SO-7 proposes to restate this figure, and D18 quotes
  it to Victor, a number in the decisions register currently has no
  reproducible derivation. **Condition C-6.**

### 6.6 My band, and the one measurement that collapses it

Two external endpoints unless stated. The low end keeps the draft's own 128
flat sites and adds only the mask rows; the high end uses level-wise sites per
§2.5's own sentence. Both use Poseidon2 (Rescue-Prime is 15–20% cheaper
throughout, per §3.2).

| quantity | draft | **corrected band** | dominant driver |
|---|---|---|---|
| Mistral, committed volume | 0.63% | **0.72% – 2.06%** | claim sites |
| Mistral, prove seconds (volume only) | +0.37 s | **+0.42 – +1.20 s** | claim sites |
| Mistral, the gadget's own zero-check | *not counted* | **+0.5 – +9.3 s** | degree-7 sumcheck, layout |
| Mistral, proof bytes | 8.78 MB (0.68%) | **8.78 – 25.1 MB (0.68% – 1.95%)** | claim sites |
| 125M, committed volume | 4.29% | **7.4% – 50%** | claim sites |
| 125M, prove seconds on GPU | +0.20 s | **+0.34 – +2.39 s** | claim sites |
| 125M, prove seconds if the slot is host-side | *not counted* | **×7.62 of the above** | `SC_DEG 4` |
| 125M, proof bytes | 2.50 MB (2.83%) | **2.50 – 17.3 MB (2.83% – 19.6%)** | claim sites |
| tiny, one endpoint, proof bytes | 585,728 B (20.8%) | **585,728 – 2,961,408 B (20.8% – 105%)** | claim sites |

Every band is dominated by **one unknown: how many claim sites the layout
builder demands for a tree of `L` leaves.** Everything else is second order.

**The one measurement that collapses it is the draft's own M2, and it should be
promoted to first.** The layout is *"a function of the fixed geometry only: no
proof value, witness value or challenge moves a row, a site or a slot"*
(`layout.rs:15-18`), and it asserts its own counts (`layout.rs:588-590`,
`:705-706`, `:778-779`). So building a **4-leaf tree in the layout builder
alone**, with no proof, no witness and no GPU, prints `A rows=… data=…
site-pairs=…` and settles the dominant term in hours on the tiny shape. M1's
single permutation does **not** settle it, because the site question is about
the tree, not the permutation. Run M2 first, or run M1 and M2 together.

The second measurement, and the one that decides whether the thing is
buildable at all at 125M: **write one degree-8 CUDA zero-check kernel and time
it against the degree-4 one** — or measure the host-side slot inside the GPU
pass and read the real penalty rather than my 7.62× proxy.

## 7. Protocol placement and the joint-view claim

### 7.1 What holds

The placement checks are mostly right and are checked here rather than taken
on trust. Nothing is opened twice: the gadget adds rows to commitments the
proof already opens once, and the handle is a public constant with no
authentication paths and no top pair (D12 item 1 ✓). Every hash intermediate
sits on prover-generated commitments inside the one proof (D12 item 3 ✓). The
salt needs its own reserved mask pair, and the draft says so (`layout.rs:20-23`
✓). The additive-only shipping discipline the draft imposes — new module, new
profile tag, new digest domain, new entry pair, no digest moves — is exactly
D17 rule 2 ✓.

**SO-4 verified.** `Transcript::absorb` is
`BLAKE3(state ‖ len(label) ‖ label ‖ len(data) ‖ data)`
(`zkp-core/src/transcript.rs:43-51`), so the input is
`48 + |label| + |data|` bytes and lands in the shared untagged 64-byte domain
exactly when `|label| + |data| = 16`. A 32-byte handle under an 8-byte label is
88 bytes. **RECOMPUTED, correct**, and the draft is right that the invariant
should be asserted mechanically rather than left to chance.

### 7.2 "A relation's degree does not enter that model at all" — wrong, and the draft contradicts it two paragraphs earlier

**CORRECTION.** §4.3's closing paragraph says the disclosed-dimension analysis
is about linear functionals of committed rows, so *"a relation's degree does
not enter that model at all"*. Its own item 3, twenty lines above, says
*"At degree 7 those masks are roughly twice as long as today's … This is the
one place where the degree-7 choice touches privacy rather than cost."* The
item is right and the closing paragraph is wrong. Degree enters through the
**masked-round channel**, which that analysis lists as one of its channels:

* a degree-8 slot publishes **9 `Fp2` values per round** against today's 5
  (`sumcheck.rs:73`, `:147-150`) — 1.8× the published field values per slot;
* its CFS mask length is `L = n_vars·d + 2` (`sumcheck.rs:197-199`), so the
  consistency subspace `C_s` changes dimension and the lane's measured
  property `rank R_s = dim C_s` must be re-established, not inherited.

**RECOMPUTED on the pad budget** (the brief's question): `MASK_Q = 256` and
`m = 512` are fixed (`zk.rs:373-375`), so the per-row budget is 256
coefficients and **is not threatened** — at `d = 8`, `n_vars = 21` gives
`L = 170`, leaving 86 spare against 206 spare at `d = 4`. The headroom halves;
the wall does not move. `n_base = 2·slots + 4` grows by **2 rows of `M` per new
slot** (`zk.rs:435`, `layout.rs:519`), so one slot per tree level costs ~36
extra `M` rows at Mistral — negligible beside the site pairs of §6.3. And
`H-pad` (distinct opened columns ≤ `Q = 256`, margin 9–25) is **not** affected
by adding rows, because the sampled column set does not change; what must be
re-measured is `k0`, and the draft says so.

So: correct the closing sentence, keep item 3, and add the pad arithmetic
above so nobody re-derives it.

### 7.3 One new implementer hazard the draft does not name

**Condition C-7.** `priv_table`'s correctness rests on a premise stated only in
a comment: *"multilinear in x because every challenge index occurs at most once
among the coordinates"* (`argument.rs:162-163`). **There is no code check.**
The loop does `x |= b << (n_vars − 1 − *k)`, so a duplicated index silently
ORs two plane bits into one and the table is no longer the plane's multilinear
extension. Today's ~23 slots are hand-audited; the gadget introduces on the
order of a **thousand** new `Coord` vectors. An assertion on coordinate
uniqueness must land before the first gadget slot, not after.

### 7.4 On the new negative control

SO-5 is right and should be a hard gate. One addition: the control the draft
proposes ("a gadget whose salt plane shares a mask pair with a hash-state plane
must disclose") tests the *tool*. A second control is owed that tests the
*model*: a gadget whose hash-state planes are **correlated with the endpoint
plane in a way the linear tools cannot see** — which is what a hash is — must
be shown to be outside the analysis rather than clean under it. The draft's own
§4.3 closing note says the gadget "enlarges the region the linear tools cannot
see"; that sentence must survive into any disposition, because a disclosed-0
reading on a hash gadget is weaker evidence than a disclosed-0 reading on a
linear relation, and a reader will not know that unless it is written down.

## 8. Chaining through handles, D12 and P1

### 8.1 What the construction gets right

Each proof opens its own commitments once; the chain's verifier compares 32
bytes; no root crosses a proof boundary. That genuinely dissolves the blocker
recorded in the disposition (`:72-80`) — "separately finished private proofs
cannot be chained through a commitment root" — and it is the strongest
practical argument in the memo, because the 32-layer private Mistral pass does
not fit one process on the laptop card. The draft is also right that linkage is
intrinsic and cannot be removed while keeping equality-checked chaining, and
right that handle equality says nothing about model, calibration or request
(D12 item 5's unresolved scale tag is owed separately).

### 8.2 D12: respected in the letter, and a rule is needed for the spirit

**Condition C-8.** D12 item 2 says *"A block is one proof under one transcript
with exactly two external endpoints… Two separately finished component receipts
glued by a shared root are not a block."* A handle-chained pair is two
separately finished receipts glued by a shared **handle**. The draft says
"D12 governs what happens inside one block and is untouched", which is true of
the letter and evasive about the substance: the whole purpose of §5 is to glue
finished proofs, and D12 exists to forbid a class of gluing. The right
resolution is not to argue D12 does not apply but to **ask for an amendment**
naming handle-chaining as a permitted second form, with its own name (it is
not a block), its own qualifier list, and D17 rule 4's discipline that a cost
vehicle is never called P1.

On D12 item 3 specifically — the brief's question of whether a handle is "a
commitment in the sense D12 cares about". Item 3 forbids a *caller-fixed
endpoint commitment shared by two proofs*. A handle is not a commitment the
proof opens, has no randomness, no paths and no top pair, so item 3's mechanism
does not bite. But a handle **is** a public, binding function of a hidden
intermediate that every later proof and every later analysis must treat as
prior history — and it is **more persistent than a root**, because it is stable
across proofs and provers (§1.7). So item 3's *mechanism* is respected and its
*concern* is only partly answered, and the amendment should say which.

### 8.3 P1: permitted by the letter, with one thing the letter does not cover

`ZK60_PRIVACY_REQUIREMENTS.md:18-19` already contemplates public handles for
hidden values: *"Public commitment roots are handles for hidden values;
publishing a root does not authorize publishing the corresponding raw input,
output or activation."* A salted-hash handle sits in the same category, so
publishing one is not by itself a breach of P1/D1 — **conditional on
(H-hide)**, which is §1.3's unreduced keyed-mode assumption.

What P1 does not cover is **linkage**, and the draft is right to send it to
Victor as PO-3 rather than decide it. Two things PO-3 should say that the draft
does not:

* the linkage is **retroactive and permanent** (§1.7): a salt leak years later
  makes every handle published under it checkable against a guessed plane;
* in a chain of `K` runs by different parties, boundary salt `s_k` is known to
  parties `k` and `k+1`, so **any two consecutive parties can confirm a third
  party's guess** of the intermediate activation. The draft's table covers the
  relay case; it does not cover the coalition case.

### 8.4 Who holds the salt

Correctly analysed for the same-prover case (a local secret) and for the
two-party case (transported with the plane). Not analysed:

* **Availability.** The prover cannot prove without the salt. A sealer that
  loses or withholds the salt has made the plane unprovable for ever — there is
  no re-sealing story and no revocation story. For a regulator-sealed input
  that is an operational failure mode with legal weight. **Condition C-9.**
* **The channel.** PO-4 accepts a two-party secret without naming the channel,
  its authentication, or what happens on compromise. That is an operational
  security requirement with no design, and it should be written as an owed
  item, not as an accepted cost.

## 9. The decisions list (PO-1…PO-5, SO-1…SO-8)

### 9.1 Filing: mostly right, two to move

The split is sound: PO-1 (a new cryptographic assumption), PO-3 (a new public
leak) and PO-4 (a new operational duty) are genuinely project-owner rulings of
the same kind as D3, D4 and D7; SO-1, SO-2, SO-4, SO-5 and SO-8 are engineering.
Two to move:

* **SO-3 should be PO-3b.** "Keep BLAKE3 for the transcript and the Merkle
  layer; use the algebraic hash only for the handle" is presented as an
  engineering choice and its own reason says *"Record it as two assumptions,
  not one."* Adding a second cryptographic assumption to the product is exactly
  what D3 and D4 were put to Victor for. It is a ruling, not a choice.
* **PO-5 (build order) is an engineering/spend item** filed as a project-owner
  decision. Harmless, and arguably correct as a spend ruling; noted only for
  consistency.

### 9.2 SO-6: right conclusion, wrong reason, and now quantified

**CORRECTION.** SO-6 says a 31–32-bit field under D14 *"would invalidate every
Goldilocks parameter set and the `x⁷` S-box"*. The parameter-set half is right.
The S-box half is wrong: **RECOMPUTED** (`recount.py` §A), `x⁷` is a
permutation of BabyBear (`2^31 − 2^27 + 1`) too; KoalaBear takes `x³`,
Mersenne31 takes `x⁵`, and published Poseidon2 parameter sets exist for those
fields at widths 16 and 24. The approach survives a field change; the
*instance* does not.

The real coupling is a **cost** coupling, and it is bigger than SO-6 says.
**RECOMPUTED** (`recount.py` §B): 128-bit collision resistance needs capacity
`≥ 9` elements in a 31-bit field against 4 in Goldilocks, which forces a wider
state and a worse rate-to-S-box ratio — plausibly **2–3× the gadget cost per
absorbed element**. SO-6's recommendation (rule on D14 and the hash together)
stands, and should carry that factor rather than "it breaks".

### 9.3 SO-7 must not be adopted

**BLOCKING (B-7).** SO-7 proposes to restate D18's figure as *"about +11%
public / +25% private for SHA-256"*. Per §2.3 the tree argument it rests on is
wrong — the correct tree overhead is `1 + 1/k`, giving **+5.6% to +6.2%**
against D18's recorded +5.5%. Writing +11% into the decisions register on a
wrong argument would put a number in front of Victor that is roughly 2× the
best available estimate, in the direction that makes the whole
sealed-in-advance milestone look more expensive than it is. And the private
half (+25%) is doubly unsafe because its base (+12.6%) is itself not
reproducible (§6.5).

What SO-7 *should* say: D18's `+5.5% public` is confirmed as arithmetic from
its stated basis; the basis's per-compression lookup count is uncertain by
about 3× in the expensive direction on the drafter's own count (giving up to
+10.3%); the tree adds at most ~13%; and the private figure has no published
derivation and should be recomputed or withdrawn.

### 9.4 PO-1's recommendation should change

**BLOCKING (B-8).** PO-1 recommends Poseidon2 and describes Rescue-Prime as
"the conservative alternative … at roughly 1.4× the cost". Per §3.2,
Rescue-Prime Optimized is **0.81× the cost** on committed volume, also
zero-lookup, older, with a published round-count formula and a stated λ = 128.
It dominates on both axes. Combined with §3.3's two flags on Poseidon2 —
eprint 2026/306's 2^106 collision improvement on *a* recommended 128-bit set,
and the Ethereum Foundation dropping Poseidon from the L1 roadmap in Aug 2026 —
the recommendation put to the project owner should be **Rescue-Prime Optimized
width 12, capacity 4, with Poseidon2 as the alternative**, and the ecosystem
signal must be in the text. PO-1's plain-words paragraph ("newer and less
battle-tested than SHA-256, in exchange for…") is otherwise well written and
should be kept, with the cost ratios corrected.

### 9.5 What is missing from the list entirely

Nine items, each a real decision nobody has been asked:

1. **Who generates the salt, from what entropy source, and how a verifier or
   an auditor knows it was uniform** — the malicious-sealer covert channel of
   §1.6. Currently unowned.
2. **Handle format versioning**: the tag, the packing map, the tiling, the
   signed encoding and the tree shape must all be pinned by a statement
   version, and a v2 must be distinguishable from a v1 (§5.2, §5.4).
3. **Salt lifecycle**: transport channel, storage, rotation, destruction,
   and what re-sealing means (§8.4). There is no revocation story at all.
4. **Availability**: a lost or withheld salt makes a sealed plane permanently
   unprovable (§8.4).
5. **Length and tree-shape binding** in the hash input (§1.5) — a soundness
   item filed nowhere.
6. **Salt placement** (capacity of every node vs one leaf's message, §1.4) —
   a security choice with a zero-cost right answer.
7. **The degree-4 split vs a new degree-8 CUDA kernel** (§4.3) — an
   engineering ruling that changes the whole cost picture and that SO-1
   currently presupposes away.
8. **Timing and size side channels** (§1.7): the gadget looks safe, but D7
   already carries timing as a declared qualifier and the native line should
   state the same thing deliberately.
9. **The amendment to D12** admitting handle-chaining as a named, non-block
   composition (§8.2).

## ERRATA AND CONDITIONS FOR ACCEPTANCE

### A. BLOCKING — the draft cannot be used until these are fixed

| # | where | what is wrong | what it must say instead |
|---|---|---|---|
| **B-1** | §1.3, lines 178-190 | "Random-oracle hiding" is not an honest model for an **algebraic** permutation used in a **keyed** mode. Every published analysis of Poseidon2/RPO/Monolith/Tip5 is of an unkeyed public hash; the sponge bound the memo quotes is explicitly conditioned on an *ideal* permutation (eprint 2023/323 §2). No keyed-sponge/PRF analysis of any candidate was found | Relabel (H-hide) as **"a keyed-mode assumption on a primitive analysed only in unkeyed mode"**, state that the ROM bound does not transfer to an algebraic permutation, and say that algebraic attacks are strongest in exactly this setting (known output, known low-entropy input part, small unknown block) |
| **B-2** | §1.1 line 92; §1.4 lines 211-221 | The handle **omits the element count** that D7's zkVM handle absorbs (`zkvm-block/statement/src/lib.rs:65-78`, `h.update((ELEMENTS as u32).to_le_bytes())`), and the tree has **no leaf/internal domain separation, no shape encoding and no padding rule**. Collision resistance, which §1.4 makes load-bearing, does not hold as specified | Add the length; add frame/level separation and a shape encoding (Sakura-style) and a padding rule for the ragged last chunk; re-state §1.4 as conditional on them |
| **B-3** | §1.1 line 107; §5; PO-4 | The **malicious sealer is out of scope**, but the sealer chooses the salt and the salt is the only thing protecting the prover's data. It can reuse it, derive it from the plane, or **grind it so `h` encodes chosen bits of the plane** — a covert channel. In §5 the "sealer" of each boundary handle **is the upstream prover** | Add a sealer threat model; specify a salt-generation mechanism whose uniformity is attestable; rule on what an unverifiable salt is worth |
| **B-4** | §2.5 lines 499-551; §2.7 box lines 619-630; SO-7 | **"A binary tree is forced, doubling permutations"** is false. Unrolling `k` sequential absorptions per leaf uses only `Coord::Fixed` and gives `(1 + 1/k)`. Both conclusions fall: the tree is not forced, and D18's figure is **not** 2× low | State the overhead as `1 + 1/k` with `k` free; withdraw "the honest SHA-256 figure is double"; keep the separate, unapplied observation that the memo's own SHA-256 lookup count is 3× the record's |
| **B-5** | §2.0 lines 312-320 ("no cap was found anywhere in the tree"); §3.4; §6 M4 | **The CUDA zero-check is hard-capped at degree 4**: `#define SC_DEG 4` (`hashline/src/gpu/kernels.cu:601`), baked into register arrays, shared memory and `scg_emit<SC_DEG+1>`; plus a degree-3 table kernel (`gpu/cuda.rs:3152-3160`). `private_block` has **no GPU path at all**. So every GPU-denominated figure and M4 itself presuppose a kernel that does not exist | Say the cap exists; price the degree-≤4 split form (2 committed values per S-box: 29.5/element Poseidon2, 24.0/element RPO) as the **default**; make "write and measure a degree-8 kernel" an explicit precondition of any GPU figure |
| **B-6** | §2.5 lines 545-546 vs §3.2 line 703 and §3.3 lines 744-758 | **Self-contradiction on claim sites.** §2.5 says level-wise families multiply sites by the depth and that "§3 prices the level-wise form"; §3 prices **128 flat**. Corrected: 128 → 2,124 at Mistral, 1,770 at 125M, 708 at tiny. Proof bytes ×2.86 / ×6.38 / ×5.06 | Price **one** wiring option consistently, state the other's cost, and make the site count the first thing M2 measures |
| **B-7** | SO-7, lines 1242-1247 | The proposed restatement of D18 ("+11% public / +25% private") rests on the wrong tree argument (B-4) and on a private base figure that is not reproducible. Adopting it would put a ~2×-inflated number in the decisions register | Restate as: +5.5% public confirmed from its stated basis; up to ~+10% if the memo's own per-compression count is right; tree adds ≤13%; **the private figure has no published derivation and must be recomputed or withdrawn** |
| **B-8** | PO-1, lines 1163-1176; §2.7 line 609 | **The recommendation is inverted.** Rescue-Prime Optimized is **12.0** committed values per absorbed element, not 42 — 0.81× Poseidon2, not 1.4×. It is also older, has a published round-count formula, and claims λ = 128. Meanwhile Poseidon2 carries eprint 2026/306 (2^106 collision improvement on *a* recommended 128-bit set, target set unverified) and the Ethereum Foundation dropped Poseidon from the L1 roadmap in Aug 2026 | Recommend **Rescue-Prime Optimized w12 c4**, with Poseidon2 as the alternative; add RPO's uncounted host-side `x^(1/7)` cost and its `N = 7 vs 8` margin cut; put the EF signal in the plain-words paragraph |

### B. CORRECTIONS — a wrong number or citation

| # | draft says | evidence | must say |
|---|---|---|---|
| E-1 | §2.7 line 609: Rescue-Prime ≈42 committed/element | Monolith App. D.2: *"96 degree-7 constraints in total"*; 96/8 | **12.0** |
| E-2 | §2.7 line 610: Monolith ≈38 committed/element | Monolith Table 4 witness 480; 480/8. The 38 is Tip5's number (380/10) | **60.0** (lookups 24.0 ✓) |
| E-3 | §2.7 line 611 and §2.3: Tip5 "w16, 5 rounds" costed at rate 8 / capacity 4, ≈30 committed | Tip5 Table 1: `m=16, r=10, c=6`, witness 380 | **38.0**; geometry is r10/c6; the width-12 variant is **Tip4′** (20 lk / 45 values) |
| E-4 | §2.2 line 386: "every Goldilocks design in the literature uses `x⁷`" | Monolith-64's Bricks is degree 2 | false as stated |
| E-5 | §2.0 lines 314-319: mask-row budget derived from "a mask row holds 256 elements at the tiny profile" | `zk.rs:373-375`: `M` is a separate commitment, fixed 512 message / 4,096 domain / 256 pads, independent of `log_cols` | budget is `512 − 256 = 256` coefficients, `n_vars·d ≤ 254`, **identical at every `log_cols`**. Conclusion (degree 7 fits on CPU) unchanged |
| E-6 | §2.0 line 302 and §2.1: "a table of any size is expressible" | `LOG_N = 8`/`N = 256` (`layout.rs:48-49`), `Dom::Tab => 8` (`:103`), checked at `argument.rs:280-282` | tables are **pinned at 256 entries in this profile**; the 2^16 XOR/AND tables of §2.1 and Monolith's Bars table need a new domain (a 2^16 table exists only on the public-weight path, `zk.rs:1943`) |
| E-7 | §2.5 line 509: a chain "cannot be expressed … without a new primitive" | `sumcheck.rs:47-131` is table-generic; `pcs.rs:976` already takes an arbitrary column-weight vector; `zk.rs:394-398` already uses arbitrary weights | a shift is **not implemented**, not inexpressible; adding it is a new access mode + `ZPart` variant + matching `mask_eval`, an additive change |
| E-8 | §3.4 line 796 etc.: two Mistral endpoints = 0.63% / +0.37 s | `layout.rs:523-526`: `A_ROWS = 455 = 213 data + 240 site pairs + 2 prox`. Site pairs are committed rows and are omitted from volume | ≥ **0.72% / +0.42 s** even at the draft's own site count; 0.72–2.06% / +0.42–1.20 s over the band |
| E-9 | §3.4 line 800: 125M = +4.29% / +0.20 s / +2.83% bytes | same, plus B-6 | **7.4–50% / +0.34–2.39 s / +2.83–19.6% bytes**, and ×7.62 on seconds if the slot is host-side |
| E-10 | §3.4 line 802-803: tiny +10.9% (B) / +20.8% (A) of the receipt | B-6 | up to **105% of the receipt** in layout A with level-wise sites |
| E-11 | §3.4's headline figures | §3.2 computes layout A's own zero-check at ≈3.2 × 10¹⁰ mul-adds and calls it second-largest; §3.4 converts committed words only | add the gadget's own sumcheck: **4.7 × 10¹⁰ (A) / 2.7 × 10¹⁰ (C)** mul-adds per endpoint = +0.3…+4.7 s per endpoint |
| E-12 | §3.4 table row "Mistral, 8B pass" | words and seconds are the **public** pass, bytes are the **private** proof | label the denominators; do not compare "+0.6% public" to D18's "+12.6% private" without saying so |
| E-13 | §3.4 headline and §0 item 1 use **layout A** | SO-1 recommends **layout C** | headline the recommended layout, or say why not |
| E-14 | §0 line 54: "+11% to +23% of that receipt's bytes" | §3.4 gives 10.9% and 20.8% | 23% appears nowhere |
| E-15 | §2.6 lines 582-594, §4.1 item 1: "the packing is free" | D12 item 4 (re-checked in source): the layer prover range-proves the activation, the two int16 planes and the output, **never the input plane** (`layer.rs:11-14`) | free on the **tiny `private_block`** path only; on the layer path the input endpoint has no byte limbs (+0.04% words, +0.09% lookups to add — and it puts the lookup column above zero) |
| E-16 | PO-2 lines 1178-1184: SHA-256 would make native and zkVM handles "the same object" | native packing is interleaved offset-binary over two limb planes; D7 is `v.to_le_bytes()` two's-complement in order, and also absorbs a model digest and a length | false unless the packing is matched too, which forfeits the free limbs |
| E-17 | §4.3 lines 994-1002: "a relation's degree does not enter that model at all" | its own item 3; `sumcheck.rs:73`, `:147-150`, `:197-199` | degree enters through the masked-round channel: **9 `Fp2` per round vs 5**, and `L = n_vars·d + 2` changes `dim C_s`. Pad budget is **not** threatened (`L = 170` of 256 at `d=8, n_vars=21`) |
| E-18 | SO-6 lines 1238-1240: a 31–32-bit field "would invalidate … the `x⁷` S-box" | `gcd(7, 2^31−2^27) = 1`: `x⁷` permutes BabyBear; KoalaBear takes `x³`, Mersenne31 `x⁵` | the *instance* changes, not the approach; the real coupling is cost — 128-bit collision resistance needs capacity ≥ **9** elements at 31 bits against 4 at 64, plausibly 2–3× the gadget |
| E-19 | §2.0 line 293: LogUp helper degree cited at `argument.rs:596-597` | the relation is at `argument.rs:483`; `:596-597` is the comment stating the consequence | cite `:483` |
| E-20 | §6 M4: "inside the repaired private profile, GPU binary" | `private_block` has no GPU path; the 4.649 s is the layer prover | name which module, and make the kernel question a precondition |

### C. OMITTED CONDITIONS — must be added before acceptance

| # | condition |
|---|---|
| **C-1** | **Put the salt in the capacity (IV) of every tree node**, not in one leaf's message. Costs zero extra permutations; without it every non-first leaf digest is an unsalted hash of a 32-byte activation chunk whose secrecy rests on the undischarged PCS-hiding stack, and equal chunks are detectable to anyone who sees an internal node |
| **C-2** | A **salt-generation mechanism** whose uniformity is attestable, against the malicious-sealer covert channel (B-3), plus the entropy note: 4 **uniform field elements**, not 64 random bits reduced mod `p` (D9's recorded reduction bias) |
| **C-3** | **Read eprint 2026/306 in full** and determine whether its attacked "recommended 128-bit parameter set" is the Goldilocks t = 12 one, **before** PO-1 is put to the project owner. This is the single most important unresolved security question in the memo |
| **C-4** | The statement version must **pin the packing map**: which signed encoding (the module has at least three), which limb order, which tiling — and M3's independent Python reference must exercise exactly that map |
| **C-5** | Above the tiny shape the endpoints are **re-tiled** under D17 rule 1; the tiling must be part of the pinned map, or a third-party sealer cannot reproduce the handle at all, which is the whole point |
| **C-6** | **Recompute or withdraw D18's "+12.6% private."** It is stated at `ZK60_D8_D11_RESTATEMENT_CHECK.md:564` and `:827` with no derivation and is not reproducible from any published denominator |
| **C-7** | Add a **code assertion that `Coord` challenge indices are unique** per plane. `priv_table` (`argument.rs:162-163`) states it as a comment and does `x \|= b << …`, so a duplicate silently ORs two bits and the table stops being the plane's multilinear extension. The gadget introduces ~1,000 new `Coord` vectors |
| **C-8** | **Ask for a D12 amendment** naming handle-chaining as a permitted, distinctly-named second composition form — not a block — rather than arguing D12 does not apply |
| **C-9** | A **salt lifecycle**: transport channel and its authentication, storage, rotation, destruction, re-sealing, and the availability failure (a lost or withheld salt makes a sealed plane permanently unprovable). PO-4 accepts the duty without naming any of this |
| **C-10** | PO-3 must add that linkage is **retroactive and permanent** (one salt leak makes every handle under it checkable, for ever) and that in a `K`-run chain **any two consecutive parties** can confirm a third party's guess of the intermediate |
| **C-11** | A **second negative control** that tests the *model*, not only the tool: a disclosed-0 reading on a hash gadget is weaker evidence than one on a linear relation, because the linear tools cannot see the nonlinearity. The draft's own sentence saying so must survive into any disposition |
| **C-12** | **Run M2 before or with M1.** The dominant unknown is the claim-site count for a tree of `L` leaves, and the layout is a pure function of the fixed geometry (`layout.rs:15-18`) that asserts its own counts (`:588-590`, `:705-706`, `:778-779`) — a 4-leaf tree in the layout builder alone, no proof, no witness, no GPU, settles it in hours |
| **C-13** | State the **timing/size side channel** deliberately: the gadget's cost depends on the public shape and on no plane value, provided the signed packing is branch-free. D7 already declares timing as a qualifier; the native line should say the same on purpose |

---

**(check complete)**
