# G-R4 follow-up: do the toy's hash-layer lemma and composition cover the endpoint roots?

> Written by a delegated Opus reader for the security owner on 2026-09-23
> (`date` read at 16:44 and 16:50 PDT on the WSL box). It is the reading that
> §3 of `ZK60_BLINDING_LAW_GR4_DISPOSITION.md` owes before that page may say
> anything about the toy. **Reading only.** No D22 document, and not the toy
> statement, was edited. **This is not a privacy acceptance of anything, and
> D22 stands as accepted.**

## The toy (D22) reading owed by §3 of the G-R4 disposition

### 1. The question, and the answer in plain words

**Why the question arises.** The check of the G-R4 draft (finding F-1)
showed a problem with one phrase: "the blinding is independent of the
public statement".
* The public statement carries the two **endpoint roots**. These are the
  last 64 bytes of the 112-byte expected-IO policy.
* Each root is a hash of that endpoint's randomly drawn masks, pads and
  salts.
* So the blinding cannot be independent of a statement that contains the
  roots.

The ruling (LW-1) restates the law over the statement *without* the two
roots, which that page calls `P°`. It treats the roots as part of what a
verifier sees, and hands them to the hash-layer assumption (H6), which
already handles the roots of `A`, `H` and `M`.

**The question.** The toy's composition memo carries the same phrase, in
its hypothesis (H5) under a fixed statement that includes the policy. The
question is whether the toy's **accepted** hash-layer lemma already counts
the two endpoint roots among the hashed values whose hiding it establishes,
and whether the toy's argument routes them through it.

**Answer: (i), covered. The fix for the toy is wording only.**
* The accepted lemma, **Lemma H** of `ZK60_HASH_LAYER_AND_FS_LIFT.md`,
  explicitly counts **five** roots. Two of them are the endpoint roots
  inside the 112-byte policy. Its derivation builds every one of those roots
  from the salted leaves (§2.1 below).
* The lift in the same document puts the endpoint roots **in the view**, as
  the first message. So does its final sentence, which D22 rests on (§2.2).
* What is wrong is wording in two places:
  * the composition memo (step 4 of D22), which names only **three** roots
    in its (H6) and puts the whole policy into the fixed statement;
  * the notation line that Lemma H imports from that memo.

  Read literally, both would say the endpoint roots are fixed in advance.
  The chain cannot mean that, because its own last hop changes them (§2.3).

### 2. The reading

#### 2.1 Lemma H counts the two endpoint roots among the hashed values it hides

All line numbers are in `ZK60_HASH_LAYER_AND_FS_LIFT.md` (called "L" below),
the document that D22 §3 step 5 cites through its disposition.

| What L says | Where | What it establishes about the endpoint roots |
|---|---|---|
| "Five roots — `a_root`, `h_root`, `mask_root` in the receipt frame … and the two endpoint roots inside the 112-byte `ExpectedIo` policy … which the verifier must hold" | §1.1, l. 164-171 | The endpoint roots are counted among the published hash objects |
| The tree table has rows "input endpoint" and "output endpoint" (2,048 leaves each); the per-proof total is 12,288 leaves | §1.2, l. 182-189 | The two endpoint trees are in scope, leaf by leaf |
| "the **hash view** `H` — the five roots, the 5 × 256 published salts and the 5 × 256 authentication paths" | §2.1, l. 423-424 | **The object whose conditional law Lemma H derives contains both endpoint roots** |
| Lemma H: `H = T^O((col, salt)_{opened}, (u)_{never opened})` "for each commitment `r`", with `N_leaf = 12,288` | §2.2, l. 497-510, 561 | The endpoint commitments are among the `r`. Their unopened leaves are among the i.i.d. uniform `u` |
| Step 3: `T^O` "reproduces the roots and every published sibling exactly". Step 4: "The root is one such node" | §2.3, l. 638-660 | Each endpoint root is a deterministic image of opened columns, published salts and uniform unopened-leaf digests. So, given the field view, its conditional law is witness-free |
| The hops count the three stream keys, all 327,052 draws (6,144 of them the endpoints') and all 12,288 salts (4,096 of them the endpoints') | §3.3, l. 881-882; §5.1, l. 1297 | The endpoint generators' output is inside the replacement hops that make the salts uniform |

This is exactly the (H6) coverage that ruling LW-1 asks for. The endpoint
roots are hashed values of genuine trees the prover built. Lemma H covers
them the same way it covers `A`'s, `H`'s and `M`'s roots. The one condition
it needs to be the right tool is that nobody fixed the root in advance.
That is condition C-H7 (L §2.5, l. 734), true under D18: the prover seals,
and a third-party root does not type-check.

The check of L confirmed the view item by item. The row "the 112-byte
`ExpectedIo` policy, incl. the two endpoint roots | yes | correct"
(`ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md` §1.3, l. 135).

#### 2.2 Where the argument routes them through that lemma

* **The lift (step 5) routes them.**
  * L §3.1's table opens with a **preparation** row: "`R_in`, `R_out` — the
    two endpoint roots, from `private_seam::prepare`, each on its own OS
    stream … absorbed inside the 112-byte policy in the header" (l. 754).
  * It then states "**only the five roots are ever absorbed**" and "the
    only witness-dependent objects feeding the challenge chain are the
    **five roots** and the field messages" (l. 763-780). The label table
    marks that fact VERIFIED IN THE CODE (§8 row 19, l. 1566).
  * Route B makes the endpoint roots the first message:
    `m_0 = (∅, (R_in, R_out))` (l. 910).
  * Route A, the route D22 carries, composes Theorem 3.3 × Lemma H at hop
    G_7 → G_8. It does so over a hash view that contains them (l. 887,
    l. 891-906).
* **The final sentence (L §5.2) puts them in the view in so many words:**
  "the whole view … — the 112-byte expected-IO policy including its two
  endpoint roots, the 2,816,472-byte receipt with its three roots, … — is
  within `ε(q)` … of the same view produced by the honest prover on the
  all-zero input" (l. 1307-1321). Condition 8 repeats it: "the 112-byte
  policy, which this sentence puts **in the view**" (l. 1398-1402). The
  disposition of L accepts exactly that sentence's core: "the whole view of
  a verifier … is within a listed sum of residuals of the honest prover's
  view on the all-zero input" (`ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md`,
  l. 11).
* **The privacy case sets up the game this way from the start.** Step 3
  compares `V(w)`, "the joint random variable (**endpoint roots, 112-byte
  policy, receipt bytes**) produced by the honest `prepare_endpoints` +
  `prove`". Its Rider one says "the ideal world's statement is **not** the
  real world's statement, because the endpoint roots differ … the theorem
  must say 'the joint public views are indistinguishable', never 'the same
  statement'" (`ZK60_PRIVACY_CASE_FIRST_MVP.md` l. 503-526). Step 1 fixes
  the game as the joint preparation-and-proof game, in which the prover
  issues the roots (l. 425-444). The disposition of the privacy case keeps
  that framing: "the receipt for hidden input w looks like the receipt for
  the fixed input" (`ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md` l. 16-23).
* **The composition memo (step 4), read alone, does not route them.** It is
  consistent only once completed by step 5:
  * Its §1.1 puts "the 112-byte policy" into the fixed `P` and lists "the
    **three** 32-byte roots" as the hash view (l. 107-115).
  * Its (H6) is stated over "(the three roots, the 5 × 256 authentication
    paths)" (§5.2, l. 1432-1442).
  * It says "`m_0` is `A`'s root" (§5.1, l. 1403-1404) and "their roots
    are part of the public statement" (§5.4, l. 1579).
  * Theorem 3.3 and Corollary 5.1 both begin "Fix an admissible public
    statement" (l. 747, l. 1601-1602).

  The composition's disposition names what was owed under it: "(H6)
  written as one random-oracle lemma … and the sequential lift"
  (`ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md` l. 140-143). L is that
  document, and D22 §3 lists it as step 5. The routing of the endpoint roots
  is therefore done by step 5, which widened the hash view from three roots
  to five. Step 4's own wording was never updated to match.

#### 2.3 Why the "roots in the fixed statement" wording cannot be what the chain means

If `P` really held the endpoint roots fixed, two things in the accepted
chain would break at once:

1. **The last hop of Route A could not be taken.** Hop G_8 → G_8′ sets
   `w := 0` under the same fixed `P` (L l. 888). The all-zero prover's
   `prepare_endpoints` makes new endpoint roots from new draws
   (`private_block.rs:377-387` at `4751b93`; `private_seam.rs:196, :215`).
   The chance that those equal a fixed pair is negligible. So the ideal
   world is only defined if the roots are **outputs**. That is what Rider
   one of the privacy case says, and what L §3.1's preparation row does.
2. **Lemma H would be vacuous for two of its five roots.** Its factorisation
   `law(V, H | ρ, NR, w) = law(V | ρ, NR, w) · K(H | V)` (L §2.1, l.
   464-466) puts the endpoint roots in `H`. Conditioning them away into `P`
   as well would make their law a point mass, which contradicts the kernel
   `K(H | V)` that the lemma derives.

So the only coherent reading of the accepted chain is the one ruling LW-1
gives:
* `P` means `P°`, the statement without the two endpoint roots. At the toy
  that is the weights and tables digest, the calibration and schedule
  digests, and the policy's 48 non-root bytes.
* (H5) then holds as written in the fixed-challenge experiment. The
  endpoint blinding B9 is drawn by the endpoint generators, independent of
  `(P°, w, ρ)`.
* The two roots reach the view through Lemma H.

This is the check's "should be read as 'via (H6)'"
(`ZK60_BLINDING_LAW_GR4_CHECK.md` §1, end of F-1; review branch
`zk60-private-block-125m-review`).

#### 2.4 The one refusal at the toy that reads the roots

`check_endpoints` (`hashline/src/private_block/protocol.rs:243-254` at
`4751b93`) compares the owners' roots with the policy's (`:247-248`). It is
called at `:268`, after both endpoint generators have drawn and before the
block generator (`:275`).
* **How the toy classifies it.** The privacy case's inventory lists it as
  row 2, class "s (the caller's policy)" (`ZK60_PRIVACY_CASE_FIRST_MVP.md`
  l. 1084). L §4 groups it with the rows that are "identical functions of
  identical public data in both worlds" (l. 1071).
* **Why that label is wrong under `P°`.** The event is not a function of
  public data: it reads a hash of the endpoint draws.
* **Why the conclusion survives.** It is **certain to pass for an honest
  caller**. `prepare_endpoints` builds the policy from the owners' roots in
  the same call (`private_block.rs:386` at `4751b93`), and under D18 the
  prover (or the zero-input prover of the ideal world) holds both. It
  therefore costs nothing in either world.

This is the same fix as LW-1's refusal-table row for the lane, and no
figure moves.

#### 2.5 Verdict

**(i) Covered.**
* **Where the endpoint roots are included:** Lemma H's hash view is "the
  five roots" (L §2.1, l. 423), with `N_leaf = 12,288` including both
  endpoint trees (l. 561, §1.2 l. 186-189). Its proof builds every root
  through `T^O` (§2.3 Steps 3-4, l. 638-660).
* **Where the argument uses it for them:** L §3.1 (l. 754, l. 763-780);
  Route B's `m_0 = (∅, (R_in, R_out))` (l. 910); Route A's G_7 → G_8 over
  that `H` (l. 887, l. 891-906); and the §5.2 sentence that puts "the
  112-byte expected-IO policy including its two endpoint roots" in the view
  (l. 1311-1313), which the disposition of L accepted and D22 §3 step 5
  cites.

No step is missing. What is wrong is only the wording listed in §3.

### 3. The wording fix for the toy (not applied here; for the owner of the D22 documents)

| # | Document, place | Now reads | Should read |
|---|---|---|---|
| T-1 | `ZK60_JOINT_LAW_COMPOSITION.md` §1.1, l. 107-108 | `P` includes "the 112-byte policy" | `P` includes the policy **without its two endpoint roots** (its 48 other bytes); the roots are published objects in `H` |
| T-2 | same, §1.1 l. 113; §5.2 (H6) statement l. 1437; §6 item 1 l. 1625 | "the three roots" | "the five roots (`A`, `M`, `H` and the two endpoint roots in the policy)", as L §2.1 has it |
| T-3 | same, §5.1 l. 1403-1404 | "`m_0` is `A`'s root" | `m_0` is the pair of endpoint roots, then `A`'s root (L l. 910) |
| T-4 | same, §5.4 l. 1579; `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md` J-4, l. 76-77 | "their roots are part of the public statement" | "…part of the published policy, which the verifier holds". The no-restart conclusion is unchanged |
| T-5 | same, Theorem 3.3 l. 747 and Corollary 5.1 l. 1601-1602 | "Fix an admissible public statement" | "Fix an admissible public statement `P°` (without the two endpoint roots)". (H5) is then true as written, and the roots go through (H6) |
| T-6 | `ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.1 l. 415-416, Lemma H l. 497, Route A l. 871 | "Notation, taken unchanged from … §1.1. Fix an admissible public statement `P`" | The notation is **not** unchanged: `P` is `P°`, and L's own `H` holds the five roots |
| T-7 | same, Route A `G_0`, l. 872-873 | "the honest prover runs `prove_inner`" | "runs `prepare_endpoints` and then `prove_inner`". This is what §3.1's preparation row and the hop counts (three keys, 327,052 draws, 12,288 salts) already assume |
| T-8 | `ZK60_PRIVACY_CASE_FIRST_MVP.md` item 24 row 2, l. 1084; L §4, l. 1071 | class "s (the caller's policy)"; "identical functions of identical public data in both worlds" | "reads the endpoint roots (a hash of the endpoint draws); certain to pass for an honest caller in both worlds (D18)". Cost unchanged: nothing |

None of these moves a number, a residual, a condition of D22 §5 or the
sentence of D22 §2.

### 4. What this means for D22, and what this reading did not do

**Effect on D22: none on its sentence, its figures or its seven conditions.**
When the owner chooses, the eight wording items above can go into the two
documents as a dated errata note. Until then, D22 §3 steps 4 and 5 should be
read with `P` as `P°`.

**Two observations for the owner. Neither comes from F-1, and neither
changes the verdict.**
1. **The coverage leans on D18.** It holds because, under D18, the roots are
   fresh oracle images produced inside this proof: condition C-H7 of L, the
   joint preparation-and-proof game.
   * The privacy case carries a related hypothesis, **O-2**: the endpoint
     roots of an accepted receipt are never registered, republished or
     referred to by a later artifact (`ZK60_PRIVACY_CASE_FIRST_MVP.md` l.
     198-204, l. 1633; ask R-9).
   * O-2 does not appear by name among D22 §5's seven conditions. D22's
     scope (§1) and §7 exclude only sealing in advance by a third party.
   * Whether O-2 belongs in D22's condition list is the owner's call. It is
     recorded here because the endpoint roots are exactly its subject.
2. **The run case is already written the right way.** Lemma H^run's hash
   view is the `4L + 1` roots, both external endpoint roots included, and
   it says the endpoint roots' hiding is carried by Lemma H^run
   (`ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` l. 635, l. 799-809). No document
   yet writes the standalone *tagged* block (rung-G, 125M)
   (`ZK60_SHAPED_PRIVACY_PATH_STATUS.md` row 5). This is outside D22.

**Not done here:**
* No proof step was re-derived.
* Lemma H's bound was not re-checked.
* The gate of step 3 was not re-read for whether it handles roots. It is a
  field-layer tool, and the hash layer is step 5.
* Nothing was run.
* Code was read only where cited: `4751b93` for the toy, `2ea7221` for the
  lane.

**Not a privacy acceptance. D22 is untouched.**
