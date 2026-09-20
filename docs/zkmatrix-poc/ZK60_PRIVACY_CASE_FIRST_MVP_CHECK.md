# Independent check of "the privacy case for the first MVP"

**INDEPENDENT ADVERSARIAL CHECK of a delegated draft — delegated Opus agent,
2026-09-19. Paper and Python only; NOT a privacy acceptance.**

| | |
|---|---|
| What is checked | `docs/zkmatrix-poc/ZK60_PRIVACY_CASE_FIRST_MVP.md` (1,381 lines, commit `27dd32d`) |
| Method | every claim assumed wrong until verified at a named line. Code read in the main tree at `perf/zk-batch-optimizations`; arithmetic redone in Python under `results/zk60_privacy_case_check/` |
| Ran | nothing. No cargo, no test, no prover, no benchmark |
| Labels used here | **VERIFIED IN THE CODE** (file:line) · **VERIFIED IN A DOCUMENT** (file:line) · **RECOMPUTED** · **MY OWN SKETCH** (not a proof) · **COULD NOT VERIFY** |

---

## 0. Verdict, in plain words

**The draft survives its central attack, and it is the most accurate document
of its kind this project has produced — but it must not be accepted as it
stands.** Its structural claim is right: because the prover seals its own
input (ruling D18), the imaginary program that a privacy proof needs is just
the honest prover run on an all-zero input, and the whole question becomes
"does the receipt look the same whatever the hidden input was". I checked the
thing the draft itself could not check — whether that all-zero run actually
works — by tracing the integer witness builder line by line on paper, and it
does work, for **every** public statement the code admits, for a reason the
draft never states: a zero input annihilates every relation, and two
constants (`NORM_CEPS = 1` and the pinned first entry of the exponential
table) are what keep the two divisions from dividing by zero. Every arithmetic
figure in the draft that I could recompute came out right to the byte — the
receipt size, the byte-class table, the count of random field draws, the
bias — with **one exception**: the collision probability quoted as 2^-113 is
2^-112.0.

**What falls.** Four things. (1) The proposed privacy target of 100 bits is a
target the design **misses today by 22 to 27 bits** — the draft quotes both
numbers on the same page and does not notice they contradict; the fix is
already recorded in decision D9 (one line in the random-number generator plus
a re-freeze). (2) The recommendation to rule "side channels out of scope"
bundles **refusals** in with timing and power, and refusals are not a side
channel here: the project's own simulation model puts refusal behaviour
**inside** the game the simulator must win. (3) The assumption named for the
prover's random stream is stated in one direction and is needed in **both** —
published salts come out of the same stream *before* later secret pads, which
the draft's M-3 does not cover. (4) The count of "PROVED" steps is eleven; six
of those are readings of the source rather than proofs, and three more are
conditional on a step that is OPEN, so the honest count of proved,
unconditional, security-relevant statements is **two** (and a third that lives
only on a branch).

**The shortest honest path to a privacy acceptance of the toy block** is
unchanged in shape but shorter than the draft thinks: write the zero-witness
Rust test (half a day — and it should assert the two boundary values this
check found), fix the reduction bias or lower the target, split the refusal
ruling out of the side-channel ruling, and write U-3(a). On U-3(a) the draft
over-estimates the difficulty: a single capture at full rank **does** prove
the minor is not identically zero, which is the step the draft calls "the one
that carries the content"; what remains is degree bookkeeping, and on my own
sketch the resulting term is around 2^-120 — so closing it changes a label,
not the size of the bound. The joint composition write-up (U-3(b)) and the
nonlinear channel (item 21) remain the real work.

## 1. The structural claim (attack 1)

### 1a. Is the all-zero input a valid witness? — YES, and the draft does not know why

**RECOMPUTED / paper trace**, evidence
`results/zk60_privacy_case_check/zero_witness_trace.py`. I transcribed
`hashline/src/private_block/witness.rs` (the whole of `build`, `rms_norm`,
`quantize`, `requant`, `limbs`) and ran the all-zero input through every
refusal it contains. **Nothing refuses, and nothing divides by zero.** The
reason is that a zero input annihilates every matrix multiply, every rotation
and every accumulator, so the only values that are not zero are the ones the
calibration constants force:

| site | value at the all-zero input | the check it must pass | source |
|---|---|---|---|
| sum of squares | `ss = NORM_CEPS = 1` | — | `witness.rs:170`, `layout.rs:54` |
| integer square root | `D = 1`, `a1 = 0`, `a2 = 2` | all `< 2^24` | `witness.rs:171-176` |
| **norm denominator** | `den = 2·(1 << 11) = 4096` | `den > 0` | `witness.rs:184-188` |
| norm quotient | `y = 0`, `rho = 2048`, `sigma = 2047` | `y ∈ [-127,127]`, both `< 2^29` | `witness.rs:189-196` |
| every requantisation | `y = 0`, biased remainder `2^(sh-1)` | class and byte-limb lookups | `witness.rs:84-96` |
| causal maximum | `best = 0` at `arg = 0 ≤ t` | attainment | `witness.rs:262-272` |
| exponent difference | `0` on the support, `127` off it | `∈ [0, 256)` | `witness.rs:277-280`, `MASK_SCORE = -127` |
| **softmax denominator** | `total = (t+1)·exp[0] = (t+1)·512` | `∈ [2^9, 32·2^9]` | `witness.rs:286-288` |
| feed-forward | `a16 = act[128]` (arbitrary), `u16 = 0`, so `h16 = z16 = 0` | int16 classes | `witness.rs:372-392` |

**The two constants the simulator's existence rests on** — this is the part
the draft does not say, and it belongs in the statement:

1. `NORM_CEPS = 1` (`layout.rs:54`). At `NORM_CEPS = 0` the all-zero input
   gives `D = 0`, `den = 0`, and `witness.rs:186-188` refuses with "norm
   denominator". The simulator would not exist. The constant is *calibration*,
   i.e. one edit away, and it is absorbed into the transcript as part of the
   schedule string (`layout.rs:659`) — so a future profile could carry a
   calibration for which the zero witness is invalid.
2. `exp[0] == 2^F_E`, **enforced on the public statement** by
   `AttentionPublic::new` (`private_block.rs:138`). With `exp[0] = 0` the
   softmax row sum is zero and `witness.rs:286-288` refuses. This is the
   answer to attack 1(b) below: the constructor's structure check is what
   stops an adversarially chosen statement from killing the simulator.

**Two boundary facts that U-4 must assert, and that nobody has noticed.** At
the all-zero input the softmax remainder window is **exactly full**:
`sigma_s = 16383` against a window of `2^14 = 16384` (headroom **zero**,
`witness.rs:298`), and the softmax quotient is `p = 512` against the inclusive
bound `2^F_P = 512`. The zero witness therefore sits on two range boundaries
at once. It passes — but a one-bit change in `WRHO_S`, in `F_E`, or turning
`0..=1 << F_P` into `0..1 << F_P` would make **the simulator invalid while
every ordinary witness stayed valid**. That is precisely the kind of thing a
paper argument cannot be trusted with, and it is the strongest argument for
U-4 that exists: the test must assert acceptance *and* pin those two values.

**Verdict on chain item 2.** The label OPEN is correct as written ("no Rust
test"), but the draft's own summary that it is "a day of work" understates its
value and its rider ("the zero input must remain in the declared integer
class") names the wrong condition. The real condition is: *for every public
statement the two constructors admit, and for every calibration the profile
may carry, the honest witness builder accepts the all-zero input.* I have
verified that today, on paper. **What the simulator should use: the all-zero
input** — there is no need for a second random witness at this profile.

### 1b. Can the adversary choose a statement that separates the two worlds?

I tried to build such a statement and **failed** at the block profile — the
constructors are tight enough. `AttentionPublic::new` pins the exponential
table's first entry, its range and its monotonicity, and the rotation table's
range and identity prefix (`private_block.rs:124-140`);
`FeedForwardPublic::new` fixes the activation table's type
(`private_block.rs:201-207`); `IoSpec::new` pins both scales to `(0, 0)`
(`private_block.rs:294-301`); every weight is `i8`. With the input zero, none
of the weights reaches any refusal. **So the draft's step 3 holds for every
admissible statement at this profile** — but only because of those
constructor checks, which are therefore load-bearing for *privacy* and not
only for correctness. They must be named in the theorem. If a later profile
loosens one — or adds a relation the zero input does not annihilate (a bias
term, a non-zero-preserving activation applied to a *used* value, a
normalisation with no epsilon) — the simulator must be re-established, not
inherited.

**The one real leak in the public statement, which the draft lists and does
not analyse: the context digest.** `IoSpec` carries a 32-byte `context`
documented as "Trusted request/connection metadata (context must authenticate
model, calibration **and request**)" (`private_block.rs:277-284`). It is
absorbed into the transcript inside the 112-byte policy
(`protocol.rs:31`) and travels with every receipt and every capture. If a
deployment computes that digest from the request — which is what
"authenticate the request" invites — then for a low-entropy prompt the digest
**is** the prompt, recoverable by a dictionary search, and no property of the
proof helps. The draft's §2.2 lists this channel as "public" with no
condition. **This is an omitted condition, not a flaw in the reduction**: both
worlds get the same statement, so it does not break simulation. It breaks the
product promise. The privacy statement must carry: *the context digest must
not be a deterministic function of the hidden input; if it must bind the
request, it must be salted with randomness never published.*

Other candidates I checked and cleared: the receipt length is a constant of
the layout (**RECOMPUTED** exactly, §7); the counts (`A_GROUPS 35`,
`H_GROUPS 9`, `N_FUNCTIONALS 34`, `M_ROWS 50`, slot shapes) are compile-time
constants that the decoder reads from the layout and never from the frame
(`wire.rs:144-174`); the endpoint scales are pinned; the calibration digest is
a constant (`private_block.rs:94-96`).

### 1c. Joint preparation-and-proof: does the boundary stay honest?

**Yes, and the code enforces it more strongly than the draft claims.** The
draft supports "the committer *is* the prover" by citing
`zk_ffn_fresh_io.rs:103-120` — a **different module** (the legacy FFN IO
path). For the block profile the enforcement is in
`hashline/src/private_seam.rs:142-161` and `private_block.rs:356-386`:
`PreparedPlane` has no `Clone`, no serialisation, no value getter and only two
methods (`commitment()`, and `into_ffn_endpoint` which **consumes** it);
`Endpoints` can only be built by `prepare_endpoints`, which draws fresh OS
entropy for each plane (`private_seam.rs:194-196`); `prove` takes `Endpoints`
by value. A caller *can* hand in any `ExpectedIo` it likes
(`ExpectedIo::from_roots` and `from_bytes` are public), but
`check_endpoints` (`protocol.rs:243-254`) refuses unless the prover's own
freshly committed roots equal it. **So a third-party-sealed root cannot be
proved against at all** — the D8/D11 configuration is not merely excluded by
ruling, it does not type-check. That is worth saying in the draft's item 1,
with these lines rather than the FFN ones.

**Where the boundary is thinner than the draft admits.** The endpoint roots
leave the process in the 112-byte policy, which the verifier must hold to
verify and which every capture writes to disk (`native_capture.rs:266-281`).
So the roots *are* published objects. Nothing in the first MVP stops a
deployment from recording them — in a receipt registry, an audit log, or a
regulator's file. The moment anything outside this one proof refers to a root,
the simulator's freedom to choose its own roots is no longer legitimate and
the D8/D11 game is back. The draft's item 14 rider says this for the case
where a caller *supplies* a root; it does not say it for the case where a root
is merely *retained and referred to later*. **Omitted condition:** an
acceptance at rung (ii) must be conditioned on "the endpoint roots of an
accepted receipt are not registered, republished or referred to by any later
artifact".

### 1d. What is reduced to what — is there a hybrid?

The reduction is an **equivalence, not a hybrid**, and stating it precisely
matters because the two worlds do not share the same statement:

> Fix an admissible public statement `P` (weights, tables, calibration,
> schedule, context digest, scales). Let `V(w)` be the joint random variable
> (endpoint roots, 112-byte policy, receipt bytes) produced by the honest
> `prepare_endpoints` + `prove` on hidden input `w`, over the three OS streams.
> Because the simulator is defined as `V(0)`, "there is a simulator" **is**
> "`V(w) ≈ V(0)` for every admissible `w`". No hybrid over hash queries, no
> rewinding, no oracle programming.

Two riders the draft should carry with it. First, the ideal world's
**statement is not the real world's statement**: the endpoint roots differ.
That is legitimate only in the joint preparation-and-proof game
(`ZK60_ENDPOINT_SIMULATION_MODEL.md:53-66`), and the theorem must say "the
joint public views are indistinguishable", never "the same statement". The
draft does this correctly in its §1.2 but its §0 shorthand ("does the receipt
look the same") drops it.

Second, and this is the thing to keep in view: **the collapse moves 100 % of
the content into `V(w) ≈ V(0)`, and not one line of that has been proved.**
The pieces that would establish it are items 9, 18, 21 and 28 — all four OPEN.
So the structural claim survives **in this exact form**: *D18 removes the
equivocation problem and replaces the simulator-construction question with a
single indistinguishability question; it does not answer that question, and
the answer is still entirely open.* Any sentence shorter than that overstates
what the ruling bought.

## 2. The eleven PROVED labels (attack 2)

The draft's own glossary allows **PROVED** to mean "a written proof exists,
**or** the statement is a fact about the source that was read". Those are two
different things and merging them under one word is how a later page ends up
saying "eleven steps are proved". I went through all eleven at the named
lines. Nothing is *false*. Six are source readings, three are conditional on
an OPEN step, and one contains a factual error.

| # | the draft's claim | my finding | verdict |
|---|---|---|---|
| **3** | ZK reduces to witness-indistinguishability | correct and elementary (§1d) — but it is an **implication whose hypothesis is step 2 (OPEN)** | PROVED, **conditional** |
| **4** | `audit_claims` refuses a shared/unused pair, a zero coefficient, a claim reaching the proximity pair | **VERIFIED IN THE CODE**, `protocol.rs:89-133`, `:141-152`, `:155-175`, `:191-203`. Every refusal listed is there. The *security* content (block-triangular, hence jointly uniform openings) is the function's own doc comment and is labelled "PREMISE, not proven here" at `:86-88` | **source fact**, not a proof |
| **5** | 256 opened columns are absorbed by 256 pads per row | **the one genuinely proved structural statement.** I re-derived it: `encode_row_zk` (`pcs.rs:618-632`) makes the pad contribution at coset point `x_j` equal `(x_j^n − 1)·Σ_k pad_k x_j^k`, so the `d × q` pad block is `diag(x_j^n − 1) × Vandermonde`, full row rank for distinct `x_j` with `x_j^n ≠ 1` (guaranteed by the coset generator assertion, `pcs.rs:612`) whenever `d ≤ q`; and `q_pad ≥ num_col_checks` is asserted at `pcs.rs:670` with equality set by `ZkOpts::standard` (`pcs.rs:540-543`) | **PROVED**, deserved |
| **11** | the hiding discipline is enforced, not designed | `L_s + 256 ≤ 512` asserted at `zk.rs:442` ✓; `max L_s = 50` **RECOMPUTED** ✓; refusals at `argument.rs:275-276`, `:347-348`, `:493-494` ✓; "hosts run after the slots they host" is asserted in the layout's own test (`layout.rs:717-724`) ✓. But the last sentence — "the six host groups were modelled jointly … nothing leaked" — is **COMPUTED ON CAPTURES** smuggled into a PROVED entry | **source fact**, with one computed sentence to split out |
| **12** | a derived mask evaluation is not an independent observation | **VERIFIED IN THE CODE**: the verifier computes `g_val = (fin − poly(vals))·c⁻¹` at `argument.rs:340`, and the wire frame has no field for it — a slot carries `scalar`, `rounds`, `terms` and nothing else (`wire.rs:156-163`) | **PROVED**, deserved (definitional) |
| **14** | under D18 the simulator programs no oracle point | true, but it is a **restatement of step 2**: if the simulator *is* the honest prover, of course it programs nothing. Its whole content is inherited from an OPEN step | PROVED, **conditional and near-vacuous** |
| **17** | the sequential-kernel lemma | a real lemma with a real proof, independently reviewed (`ZK60_JOINT_VIEW_REVIEW_20260918.md:52-56`: valid "when the **complete joint** message law is witness-independent under **every** forced challenge vector"). Its hypothesis is item 18, OPEN. Its proof and its exhaustive tests exist **only on branch `zk60-mvp-fable`** | PROVED as a **conditional** lemma, off the main tree |
| **19** | one public LogUp identity; exactly one witness-dependent refusal in the prover | **VERIFIED IN THE CODE** and stronger than stated: the sum claim's value is the compile-time constant `Fp2::ZERO` (`protocol.rs:61`), so "the zero witness gives the same value" needs no capture at all. The refusal is at `protocol.rs:231-234` ✓. The probability is **not** 2^-113 (§6) | source fact; **the number is wrong** |
| **22** | every blinding source is fresh, OS-seeded, independent | streams and order **VERIFIED IN THE CODE** (§5), and I confirm the stronger fact the draft does not state: **no draw count anywhere depends on a witness value**. But the sentence "its call sites are all test modules" is **FALSE**: `ZkConfig::rng` at `hashline/src/zk.rs:334-338` takes `Some(seed) => ZkRng::new(seed, domain)` and is production code on the legacy line | source fact; **contains a factual error** |
| **24** | the refusal inventory | substantially right, three omissions (§6) | source fact |
| **27** | capture bundles carry the verifier's view and nothing more | an **inspection at key level**, by the drafter's own words; I confirmed the role writer (`native_capture.rs:250-264`) and the export (`:266-281`) emit only roots, rows, checkpoints, claims, groups, columns, salts, paths, `q_pad`, row roles and public constraints | **inspection**, not a proof |

**The laundering test.** The draft sets itself the rule "no sentence may use a
COMPUTED ON CAPTURES result as the premise of a universally quantified claim"
(§3.3). I grepped for violations and found **none that survive reading** — the
one that looks like a violation, item 7's "the zero witness gives the same
value", turns out to be supported by a source constant rather than by the
captures (above). On this specific discipline the draft is clean, which is
worth recording because it is the discipline the two refused memos broke.

## 3. The circularity table, redone (attack 3)

I rebuilt the dependency graph from the text of §3.2 rather than from the
draft's table: for each step I listed what it consumes and checked whether any
consumer appears earlier in the chain than its producer, and whether any
hypothesis restates the final claim.

**No loop.** The graph is acyclic and no step's hypothesis is the conclusion
of a later step. The three shapes I specifically hunted for — "the joint
hypothesis assumed and then concluded", "the view is witness-independent given
the challenges" used to prove witness-independence, "pads are uniform given
the view" — are **absent**; the draft states the joint hypothesis as an
explicit OPEN item (18) and never discharges it. The refused D8/D11 memo's
defect is not repeated.

**Three defects in the table itself.**

1. **The wrong question is being asked.** The risk in this chain is not
   circularity, it is **conditionality**. Counting dependencies: items 3, 14
   and (through them) the whole reduction rest on item 2 (OPEN); items 6, 7,
   8, 10, 13, 26 are evidence that only becomes an argument through items 9
   and 18 (both OPEN); item 20 waits on 21 (OPEN); item 28 waits on 9, 18, 21.
   **Every step of the chain except 4, 5, 11, 12, 19, 22, 23, 24, 27 is
   downstream of something OPEN.** A dependency column would show that at a
   glance; the "circular? no" column hides it behind nine reassuring rows.
2. **Row 8 launders M-3.** It says the disjoint-randomness hypothesis is
   established by "step 22 … in the source". Step 22's own text says the
   opposite in its last three lines: `A`, `M` and `H` are **one stream**, and
   disjoint segments of a pseudorandom stream are independent only
   **computationally, under M-3**. The row must read "step 22 under M-3", or
   the very laundering the page warns about has happened in the page's own
   audit table.
3. **Row 13 is generous to itself.** It says the strong terminal check assumes
   "that the Python port equals the Rust closures" and that *nothing* later
   concludes it — true — but then marks it "no, but the obligation is real".
   An unverifiable premise in the middle of the evidence chain is not the same
   risk class as a satisfied one and should be shown as a **dangling
   dependency**, not as a clean row. The same applies to row 25 (one path set
   per root: unenforced).

## 4. U-3 and the generic-rank argument (attack 4)

**The definition is right.** U-3, in the sense the draft uses, is the
write-up obligation of `ZK60_MVP_JOINT_VIEW.md:67` ("a generic-rank argument
for all non-refused `ρ` is the write-up obligation U-3") and `:73` ("this memo
§1–§3 is the composition write-up; independent review still required"), on
branch `zk60-mvp-fable` — **VERIFIED IN A DOCUMENT**. The second, unrelated
U-3 ("nothing marks a seam endpoint consumed exactly once",
`ZK60_OPUS_SEAM_REVIEW.md:647`, closed for this API by ownership at
`ZK60_OPUS_IO_REVIEW.md:477,493`) is a different obligation, and the draft
flags the collision itself. I checked every use of "U-3" in the draft: the
right one is meant every time.

**Does it exist anywhere? No.** An independent search over the main tree, the
four named branches and every `wt-*` worktree found **no** Schwartz–Zippel or
generic-rank argument for the disclosed-dimension statement. The genuine
Schwartz–Zippel derivations in the repository
(`AGGREGATION_CLAIM_REDUCTION.md:324`, `M4_LOOKUP_DESIGN.md:557`,
`ZK60_FABLE_SECURITY_OBLIGATIONS.md:143`, `U_PERF3_OPENING_LAYER_DESIGN.md:369`
and about eight more) all bound **soundness** quantities. The lane reaffirms
the gap on 2026-09-19 (`ZK60_NATIVE_JOINT_VIEW.md:561,645`, branch
`zk60-native-jointview`). The draft's claim is confirmed.

**Does D18 change it? No** — and the draft's reason is right: U-3 is about
field messages at fixed challenges, and is indifferent to who fixed the
roots.

### My own sketch of the argument, and what it comes to

**MY OWN SKETCH — not a proof.** Evidence:
`results/zk60_privacy_case_check/sz_sketch.py`.

The reduction the lane uses gives `disclosed = 256·k0 + (a u-row term)` with
`k0 = dim{p ∈ rowspace(ρ) : p vanishes on every non-data row}`. For one
commitment with `G` combined row-weight vectors (groups plus the proximity
vector) and `R` non-data rows, let `M(chal)` be the `R × G` matrix of combined
row weights. Then `k0 = G − rank M`, so **`k0 = 0` iff some `G × G` minor of
`M` is nonzero**. Each entry is a transcript challenge `λ` (degree 1) times a
claim coefficient assembled from the terminal-mask challenges through products
`(1 − e)` (degree ≤ 2 at this profile: at most two extension rounds per slot,
`layout.rs:438-462`). Budget: degree ≤ 3 per entry.

* **Which field.** The challenges are `Fp2` elements drawn by
  `challenge_fp2` / `challenge_fp2_vec`; `|Fp2| = p² = 2^128.0000`
  (**RECOMPUTED**). Schwartz–Zippel over the extension field gives
  `deg/|Fp2|`.
* **Are they independent and uniform?** The group lambdas and the proximity
  `ρ` are separate, independent transcript draws (`pcs.rs:835-855`), so in the
  random-oracle model they are independent and uniform — *this is where M-1
  enters the privacy argument, and it must be said*. The sumcheck round
  challenges are not free: they enter through equality-polynomial tensors, so
  the minor must be treated as a polynomial in the **underlying** independent
  draws, which is what raises the degree.
* **Non-vanishing — and here the draft is too pessimistic.** It says showing
  the minors are not identically zero "is the step that carries the content".
  It is not: a single capture measured at **full rank** exhibits a concrete
  point at which some maximal minor is nonzero, and a polynomial that is
  nonzero at one point is not identically zero. That is a complete proof of
  step (iii) for the minor witnessed, and the tool already computes the rank
  (`ZK60_NATIVE_JOINT_VIEW.md` §2.1-2.3, §9b). What the write-up must add is
  only: name the minor the capture witnesses, record it, and bound its degree.
* **Refusals.** The refusal set (zero λ, zero proximity determinant,
  `c_s = 0`, `e ∈ {0,1}`, zero batching challenge) is itself the vanishing of
  low-degree polynomials, so conditioning on non-refusal multiplies the bound
  by `1/Pr[no refusal] = 1 + negligible`. This is easy, not hard.
* **What it comes to.** With the degree budget above: `A` 2^-121.2,
  `H` 2^-123.1, each endpoint 2^-125.4, union **≈ 2^-120.8**; with a
  hundredfold slack on every degree, **≈ 2^-114**.

**The consequence for the plan.** On this sketch the generic-rank term does
**not** dominate: it sits far below the `fp()` bias (2^-77.7) and below the
LogUp event (2^-112.0). So closing U-3(a) converts seven COMPUTED labels into
PROVED ones — which is exactly what an acceptance needs — but it does **not**
move the number. The draft ranks it second of eleven; I agree it should be
written, and I would tell the owner plainly that it buys a label, not a bound.

**What a full write-up still owes**, beyond my sketch: the `M` commitment does
not fit this shape at all (47 combined vectors over 4 non-data rows — the
`k0 = 0` condition cannot be a full-rank condition there, and the `M` channel's
hiding comes from `b` and `u` instead, `zk.rs:451-455`); the `u`-row term of
the reduction is not covered above; and the composition across five
commitments and 23 slots is U-3(b), which is a different and harder
obligation that this sketch does not touch.

## 5. The randomness findings, recounted (attack 5)

**Prediction before recounting:** I expected the draft's 327,052 to be short,
because salts are drawn from the same stream and a drafter counting "field
draws" often forgets a row class. It is not short. Evidence:
`results/zk60_privacy_case_check/recount.py`.

| site | source | fp() draws | draft |
|---|---|---:|---:|
| `A` mask rows, 242 × 256 | `protocol.rs:313-315` | 61,952 | ✓ |
| `A` pads, 455 × 256 | `pcs.rs:673` | 116,480 | ✓ |
| 23 CFS masks, 2 × Σ`L_s` = 2 × 583 | `zk.rs:434`, `zkp-core/src/sumcheck.rs:201-203` | 1,166 | ✓ |
| `M` pads, 46 × 256 | `zk.rs:445` | 11,776 | ✓ |
| `b_re, b_im, u_re, u_im`, 4 × 1,024 | `zk.rs:452-455` | 4,096 | ✓ |
| `H` mask rows, 104 × 256 | `protocol.rs:361-363` | 26,624 | ✓ |
| the two zero-sum rows, 2 × 255 | `protocol.rs:364-372` | 510 | ✓ |
| `H` pads, 384 × 256 | `pcs.rs:673` | 98,304 | ✓ |
| two endpoints, 2 × (5 + 7) × 256 | `private_seam.rs:211-215` | 6,144 | ✓ |
| **total** | | **327,052** = 2^18.319 | ✓ |

**Salts.** 4 × 2,048 + 4,096 = **12,288** `bytes32` draws, each four
`next_u64` calls (`rng.rs:93-99`) — they consume the stream but are not
reduced, so they contribute nothing to the reduction bias. The draft is right.

**The bias.** `2^128 mod p = p − 2^32` exactly; `p − 2^32` residues occur
`k+1` times and `2^32` occur `k` times; the exact total variation distance of
one draw is **2^-96.0000** (**RECOMPUTED** as a rational). Totals:
**2^-77.68** at the toy shape and **2^-72.86** at the draft's 125M draw count
— matching the draft's 2^-77.7 / 2^-72.9 and D9's own accepted figure of
"2^-72.9 at 2^23.1" (`ZK60_DECISIONS.md`, D9 verification note). I could not
independently verify the 125M **row totals** the 9,257,800 rests on (they come
from the 125M layout memo); the arithmetic on top of them is right.

**Independence, path by path — VERIFIED IN THE CODE.** Three `from_os` calls
per proof: `protocol.rs:275` (the block stream) and `private_seam.rs:196`
called twice from `private_block.rs:382-383` (one per endpoint). `from_os`
reads 32 bytes of `/dev/urandom` and fails closed (`rng.rs:30-51`). No stream
is cloned or re-seeded. **No seed, counter or statement value enters any
stream on this path.** `A`, `M` and `H` are disjoint consecutive segments of
the single block stream, exactly as the draft says.

**The question the brief asks and the draft does not: is the number or order
of draws data-dependent? No.** Every draw site is shaped by a compile-time
constant: mask rows = `rows − data_rows`; pads = `rows × q_pad`; salts =
`enc_cols`; CFS coefficients = `(n+e)·d + 2`; `b`/`u` = 4 × 1,024. Nothing
branches on a witness value before or between draws, and the one refusal that
does depend on witness values (`inverses`, `protocol.rs:339`) happens **after**
`A`'s randomness and **before** `H`'s — so on a refusal the stream is
abandoned entirely and no receipt exists. There is no path on which a
witness value shifts a pad's position in the stream.

### The finding: M-3 is stated in the wrong direction

The draft names the PRG assumption as "later published outputs do not reveal
earlier secret outputs", because 256 salts are published after the pads. **The
order of the code needs the opposite direction as well.** Within one
commitment `commit_zk_owned_with` draws pads then salts (`pcs.rs:673-674`),
and the commitments run in sequence on **one** stream:

> `A` mask rows (secret) → `A` pads (secret) → **`A` salts (256 of them
> published)** → the CFS masks, `M` pads, `b`, `u` (all secret) → **`M` salts
> (256 published)** → `H` mask rows (secret) → **`H` pads (secret)** → `H`
> salts (published).

So 8 KB of raw stream output is published **before** `H`'s pads and mask rows
are drawn from the same stream. The assumption actually required is ordinary
two-sided PRG security — later secret outputs must be unpredictable given
earlier published ones, *and* earlier secret outputs must stay hidden given
later published ones. A keyed BLAKE3 XOF with a counter (`rng.rs:53-61`)
plainly gives both; the point is that **M-3 as written does not cover the
case the code actually creates**, and ask R-4 inherits the error.

## 6. Refusals, rejected receipts, captures (attack 6)

### The full inventory of the private block's proving path

**VERIFIED IN THE CODE**; `w` = depends on witness values, `c` = on challenges
only, `s` = on shapes, the schedule or the environment.

| # | refusal / panic | site | class |
|---|---|---|---|
| 1 | endpoint context or side mismatch | `private_seam.rs:157-159` | s |
| 2 | expected endpoint root mismatch | `protocol.rs:247-249` | s (the caller's policy) |
| 3 | endpoint geometry | `protocol.rs:250-252` | s |
| 4 | witness shape | `protocol.rs:271-273` | s |
| 5 | **OS entropy unavailable** | `protocol.rs:275`; `private_seam.rs:196` | environment — **omitted from the draft's table** |
| 6 | **zero LogUp denominator** | `protocol.rs:231-234`, raised at `:339`, `:349`, `:351`, `:357` | **w** and c |
| 7 | slot differs from the declared schedule / table shape / table length / terminal count / site count / unknown slot / functional count | `argument.rs:263,266,282,319,453,910,927` | s |
| 8 | zero CFS mask challenge | `argument.rs:275-276` | c |
| 9 | degenerate terminal mask challenge `e ∈ {0,1}` | `argument.rs:347-348` | c |
| 10 | zero batching challenge | `argument.rs:493-494` | c |
| 11 | mask-schedule audit (5 distinct messages) | `protocol.rs:89-133` | s |
| 12 | zero group coefficient; dependent proximity pair | `protocol.rs:143-150` | c |
| 13 | group count ≠ declared; parts with different column weights | `protocol.rs:161-171` | s |
| 14 | endpoint claim differs from the schedule | `protocol.rs:191-200` | s |
| 15 | **panic**: a group vector with no mask row | `pcs.rs:886` | c — argued unreachable, see below |
| 16 | **panic**: the proximity vector misses the prox row | `pcs.rs:890` | c — argued unreachable |
| 17 | **panic**: `q_pad < num_col_checks`; data length; coset order | `pcs.rs:669-670`, `:612` | s |
| 18 | witness-builder refusals — **20 distinct site names** (11 from `quantize` call sites: Q, K, V, QR, KR, score, O, AO, FFN gate, FFN product, FFN down; 7 other range sites: norm denominator, norm quotient/remainder, exp difference, softmax quotient/remainder, residual 1, FFN up, residual 2; 2 relation failures: causal maximum attainment, softmax denominator) | `witness.rs:79-96`, `:174`, `:187`, `:194`, `:271`, `:278`, `:287`, `:298`, `:322`, `:376`, `:384`, `:414`, `:29` | **w**, before any proof exists |

**Are the two panics reachable?** No — and I checked rather than assumed.
`check_opening` replays the challenges from a **cloned** transcript in exactly
the order `open_zk` will draw them (per group: one λ per claim, then `rows`
proximity coefficients — `protocol.rs:141-152` against `pcs.rs:835-855`), and
refuses a zero λ or a zero proximity determinant. `audit_claims` guarantees
each reserved pair is touched by exactly one claim with a nonzero coefficient,
so the combined weight on that row is `λ·w ≠ 0` and `pcs.rs:886` cannot fire;
a zero determinant implies a zero first coordinate, so `pcs.rs:890` cannot
fire either. **The draft's item 4 is right that the code refuses rather than
panics** — but the panics should be in the inventory as "argued unreachable",
because an abort is a louder operational signal than an `Err`.

**Is the rank check before each opening witness-dependent? No.**
`check_opening` reads only claim *shapes*, the layout constants and challenge
values; no witness value reaches it (`protocol.rs:155-175`). Confirmed.

### Three corrections

1. **The probability is 2^-112.0, not 2^-113.** **RECOMPUTED**: the prover
   inverts 61,440 U8-lookup denominators (the layout's own test asserts that
   total, `layout.rs:744-746`), 2,048 exponent, 512 activation and 3 × 256
   table-row denominators — **64,768** in all, so the draft's own formula
   `(lookups + table rows)/|Fp2|` gives `64,768/2^128 = 2^-112.02`. Counting
   *distinct* values instead (each lookup value lies in `[0, 256)`) would give
   about 2^-117.4, which is the better bound and the one a write-up should
   use — but 2^-113 is neither, and it is quoted in the would-be privacy
   statement at §1.4.
2. **"Witness-independent" for the challenge-driven refusals holds only under
   M-1.** Every challenge is a BLAKE3 image of a prefix containing the roots,
   which are functions of the witness; the refusal events are therefore
   deterministic functions of the witness and the randomness. They are
   *identically distributed* in the two worlds only because the random-oracle
   model makes each fresh prefix's challenge uniform. The conclusion stands;
   the reason given in the draft's table ("depends on challenges → no") does
   not, and the composition with M-1 must be written.
3. **The refusal-message text is a channel of more than one bit.** The
   witness builder's refusals name the relation that failed ("norm
   quotient/remainder", "softmax denominator", "FFN product", …
   `witness.rs:79-81`). A caller who sees the string learns *which* relation
   its own input violated. That is sharper than "a refusal happened" and R-3
   should say so.

### Rejected receipts and captures

* **"`finish` has no equality precheck" — VERIFIED.** `into_ffn_endpoint`
  checks only the spec digest and the side (`private_seam.rs:156-161`) and
  `check_endpoints` compares only **roots** against the policy
  (`protocol.rs:243-254`). Nothing compares the endpoint's committed plane to
  `wit.planes[A_X]`, so a proof against an endpoint holding other values is
  built in full — 256 genuine authentication paths per root — and dies only at
  the verifier's identity. The draft's citation (`protocol.rs:255-257`) is the
  comment that says so.
* **"Every retained capture writes a receipt to disk" — VERIFIED**
  (`native_capture.rs:266-281`), with two mitigations the draft omits and the
  owner should be told: the capture writer is inside `#[cfg(test)] mod capture`
  (`private_block.rs:477-484`) so it is compiled out of production builds, and
  it only writes when `HL_TEST_NATIVE_CAPTURES` is set; and the four captures
  that exist are of `BlockPublic::synthetic_fixture()`, whose input is
  deliberately public test data (`private_block.rs:166-168`). **So H9 is a
  procedural risk, not a live disclosure** — which makes the R-5 rule cheap to
  adopt now and expensive to adopt after the first capture of a real input.
* The **112-byte policy** is written beside every capture and carries both
  endpoint roots. R-5's rule must name the policy, not only the receipt.

## 7. The view, byte class by byte class (attack 7)

I recomputed the whole frame from `wire.rs:28-36` rather than trusting the
measurement, and then rebuilt the draft's channel table independently.
Evidence: `results/zk60_privacy_case_check/recount.py`.

| class | my recount | the draft |
|---|---:|---:|
| header + 3 roots | 136 | 96 for the roots (the 40-byte envelope is not named) |
| slot payload (23 slots) | 14,672 | part of "the residue 14,712" |
| mask opening | 243,712 | split across three rows |
| `A` opening | 1,327,104 | — |
| `H` opening | 968,704 | — |
| two endpoint openings | 262,144 | 131,072 each, "exactly 75 % hash" ✓ |
| **total** | **2,816,472** | 2,816,472 (measured, `ZK60_PRIVATE_BLOCK_IMPLEMENTATION_DISPOSITION.md:47`) |
| group vectors / proximity / columns / indices / salts / paths / `q` / `M`-prox | 376,832 / 32,768 / 1,849,344 / 10,240 / 40,960 / 458,752 / 16,384 / 16,384 | identical, every one |
| openings + roots subtotal | 2,801,760 | 2,801,760 |
| hash material | 499,712 = **17.7 %** | 499,712 = 17.7 % |

**Every figure in the draft's §2.1 is exactly right**, including the residue.
That is unusual and worth saying.

**What the channel table is missing.**

1. **The 40-byte wire envelope** (`wire.rs:17`, `:78-79`): an 8-byte magic and
   a 32-byte **binding digest** equal to the transcript state after the
   header. It is a function of the public statement and the policy only
   (`private_block.rs:450-457`), so it is witness-independent except through
   the endpoint roots — but a table that claims to be "byte class by byte
   class" must name it. It is silently inside the 14,712 residue.
2. **Error strings.** Not receipt bytes, but part of the view of anyone who
   gets a refusal, and they name the failing relation (§6, correction 3).
3. **Nothing else.** I checked the decoder field by field
   (`wire.rs:144-174`): there are no optional fields, no counts read from the
   frame, no variable-length anything. Every count comes from `Layout` and a
   frame of any other length is refused at `:145-147`. Claim order, slot order
   and group order are compile-time constants. `ProveStats` (which does carry
   wall-clock phases) is a prover-side struct and never enters the receipt
   (`private_block.rs:410-423`) — its doc comment says the lookup totals are
   geometry, and I confirm they are (`protocol.rs:416-418` sums over
   histograms whose totals are the fixed 61,440 / 2,048 / 512).

## 8. The gate P10 (attack 8)

**Is it implementable? Yes, with two frictions the draft names and one it
does not.** The four capture bundles are in the main tree
(`results/zk60_native_captures_20260919/captures/`, twelve files, four
`sha256` stems) ✓. The tools — `zk60_native_joint_view.py`,
`zk60_native_jv_replay.py`, `zk60_native_terminal_polys.py` and six more —
exist **only on branch `zk60-native-jointview`** and are not in the main tree
✓ (the draft says so). `zkp-core/src/mle.rs` is indeed modified in the working
tree (staged, `M`), so a re-pin is required ✓. The friction the draft does not
name: **the gate as defined needs code that does not exist yet.** Channels 1–4
and 6–11 are "CONSTRUCTED", i.e. *solve for the zero-witness pads, masks and
pair values that reproduce the captured view* — the present tool measures
disclosed dimensions, it does not construct preimages. P10 is therefore a new
tool, not a new invocation, and the draft's "a day, once the worktree is free"
(§7.1 rank 4) is an underestimate.

### Equal fibre dimension is not enough — this is the gate's central defect

Asked directly: is a dimension count sufficient? **No.** The set
`{r : view(0, r) = V}` for the captured view `V` is the solution set of an
*inhomogeneous* linear system. Its dimension, when non-empty, equals the
kernel dimension of the homogeneous system — which is the same number whether
or not a solution exists. **Equal fibre dimension can hold while the fibre is
empty.** What carries the content is consistency: `V` must lie in the *image*
of `r ↦ view(0, r)`, i.e. `rank[M] = rank[M | V]`.

The draft's prose gets this right ("actually compute the pads, masks and
coefficients that reproduce the captured view", §4.2; "an exhibited
preimage", criterion 6) — but its **machine-readable form does not**: the
`channels` array carries only `fibre_dim_real` and `fibre_dim_zero`, and the
stated fail rule trips only when those differ. A tool written to that schema
would pass a channel with an empty fibre. **Correction: every `constructed`
entry must carry `preimage_exhibited: true|false` (and, better, a residual
norm or a rank-of-augmented-matrix field), and `false` must be a fail.**

### The negative controls

The ten controls in §4.4 are inherited from the existing joint-view work and
I have no reason to doubt the reported "fires" — including the pad-boundary
case, which the lane measured as 0, 0, 3 at `q_pad = d`, `d+1`, `d−1`
(`ZK60_NATIVE_JOINT_VIEW.md` §9b) — and the honest-instance rule the draft
adds is the right lesson from today's form-E finding. **But every one of them
is a control on the disclosed-dimension tool. Not one of them exercises P10's
own new criterion.** A gate whose central new check has no control is exactly
the failure the project has now seen twice. Two controls must be added:

* **an unsatisfiable channel**: perturb one coordinate of a captured group
  vector so that no zero-witness preimage exists, and require the gate to
  report `preimage_exhibited: false` and FAIL. If it still passes, the
  construction is fitting noise;
* **a witness-bearing channel**: force the `H` LogUp sum claim's published
  value to something other than `Fp2::ZERO` and require the fibre to be empty
  at the zero witness. (This one is cheap because the honest value is a
  compile-time constant, `protocol.rs:61`.)

Under the honest-instance rule both must first be shown to *differ* from the
honest run, which they do by construction.

### The hash layer, and whether "ARGUED" is honest

"ARGUED" is honest **only with three things attached**, two of which the draft
has. It names the assumption per channel ✓; it forbids the headline "every
channel is covered" ✓; it must also say, in the record, that these channels
are the plan's own "or the gate reports which channel it fails on" branch
(`ZK60_MVP_COMPLETION_PLAN.md:1171`) rather than a pass. So the rung (ii)
sentence must read "**a zero-witness preimage was constructed on 11 of the 14
channels; the three hash channels rest on M-2 and M-3 and were not
constructed**" — not "P10 passed". With that, ARGUED is honest.

One more thing the gate should report and the draft does not ask for: **which
unknowns the disclosed dimensions are over.** Criterion 2 lists `A` 0, `H` 2,
In 0, Out 0, `M` 2 and "joint 4 = sum of parts"; the `H` 2 are over data
coordinates (the LogUp identity) while the `M` 2 are the θ-combination over
mask coefficients, which is a functional of values already published. Stating
both as "disclosed dimensions" in one row invites the reader to think four
things about the hidden planes are disclosed. They are not.

## 9. The five rulings R-1 … R-5 (attack 9)

| ask | whose is it? | is the recommendation sound? |
|---|---|---|
| **R-1** random-oracle model + one untagged BLAKE3 domain | **the project owner's** — it is an acceptance of an idealisation, the same kind D3 (97-bit conjectured) and D4 (Groth16 setup) were | sound in direction, **too passive** (below) |
| **R-2** a 100-bit whole-proof statistical target | **the project owner's** — a product standard | **not sound as written**: the design misses it (below) |
| **R-3** side channels out of scope | **half of it is not the owner's to rule** (below) | **must be split** |
| **R-4** name the PRG assumption | **not really a ruling** — naming an assumption in a theorem is the security owner's job; the only owner-level act is accepting a computational hash assumption, which is R-1 | fold into R-1; and the assumption as stated is the wrong one (§5) |
| **R-5** rejected receipts never transmitted; captures count as publishing | **the project owner's** — it constrains operations | sound, and cheap today (below) |

**R-1, and whether to fix rather than rule.** The code fact is right: a
transcript absorb of a `u64` under an 8-byte label hashes
`state(32) ‖ 8 ‖ label(8) ‖ 8 ‖ data(8)` = **64 untagged bytes**
(`zkp-core/src/transcript.rs:44-51`), the same length as `hash_pair`
(`zkp-core/src/merkle.rs:13-18`) and `salt_leaf` (`pcs.rs:640-645`). What the
draft does not say is *why* no attack follows: the transcript's 64-byte
strings carry a rigid interior — a little-endian `8` at offset 32 and again at
offset 48 — that a Merkle node or a salted leaf matches only by accident
(≈ 2^-128 for a digest the adversary does not control). That sentence belongs
in the ruling; "no attack follows" without it is an assertion.
**On fixing it:** the draft says domain separation "would move every frozen
digest, so it belongs to the next statement version". That is true of
`merkle.rs` / `pcs.rs`, which every profile shares — but **the private-block
profile is not frozen**: `private_block.rs:16-17` says it "is not registered,
not accepted and not for use", and it appears in no freeze manifest (only in
`scripts/zk60_native_capture.py` and `scripts/zk60_private_block_inventory.py`).
A profile-scoped tag costs a re-capture of four bundles and a re-pin of eight
source hashes, not a frozen-digest break. **Amended recommendation:** accept
the ROM; record the shared untagged domain as a deviation **with an expiry —
"before this profile is registered"** — rather than deferring it to an
unnamed future version.

**R-2 is the one number that is wrong in kind.** The draft recommends "one
whole-proof statistical target of **100 bits**" on the same page on which it
states that the statistical terms today are **2^-77.7** (toy) and **2^-72.9**
(125M). Those are 22 and 27 bits *short* of the proposed target. The draft
presents the number as "matched to where the soundness side actually sits";
it is not matched to where the **privacy** side sits. Either the target is set
near 70 bits — which is honest but means the project is adopting a standard
its own soundness page calls low — or the dominant term is fixed. **It is
cheap to fix**, and D9 already says how: "the change is one line in
`ZkRng::fp` (rejection sampling) plus a re-freeze of the zero-knowledge
fixtures" (`ZK60_DECISIONS.md`, D9). Rejection sampling or a 192-bit
reduction takes the per-draw term from 2^-96 to ≈2^-160 and the whole-proof
term to ≈2^-141 at the toy shape. **The ask the owner should be given is a
pair: "target 100 bits **and** fix the draw" or "target 70 bits and record
why".** As written, adopting R-2 puts the artifact out of compliance on the
day it is adopted.

**R-3 must be split, because half of it is already inside the game.** Timing,
memory and power are outside any model this project could carry today: rule
them out of scope, record it — that is the owner's, and the recommendation is
sound. **Refusals are different.** The project's own simulation model requires
that the simulator "mirror **refusal**/consumption behavior"
(`ZK60_ENDPOINT_SIMULATION_MODEL.md:75`) and that the distinguisher sees
"published proof(s), **refusal behavior** and its oracle answers" (`:78`). The
draft's own item 17 carve-out (i) says a witness-dependent refusal *breaks*
the sequential-kernel lemma's conclusion. So a ruling that puts refusals out
of scope would rule out of scope the one channel that carries real
information about the input — the witness builder refuses out-of-class inputs
and **names the failing relation** (§6). **Amended:** R-3a (timing, memory,
power: out of scope, recorded) is the owner's; R-3b (refusals) is a
**construction obligation** — the statement must either bound the refusal
channel or the deployment must guarantee that out-of-class inputs never reach
the prover, and the owner's part is only the deployment rule.

**R-5 is right and is cheaper than it looks.** Two facts the draft omits make
it easy to adopt now: the capture writer is inside `#[cfg(test)] mod capture`
and gated on an environment variable, and all four existing captures are of
the public synthetic fixture (§6). So nobody has published anything secret and
the rule is prospective. **Amended:** the rule must name the **112-byte
policy** as well as the receipt (the policy carries both endpoint roots and is
written beside every capture), and it should say who may hold a bundle and for
how long.

**Four asks that are missing.**

* **R-6 — the context digest.** Rule that the caller's context digest must not
  be a deterministic function of the hidden input (§1b). This is a product
  ruling, it is free today, and it is the only place in the whole view where a
  low-entropy prompt could be recovered by brute force.
* **R-7 — how many proofs of one hidden input.** Chain item 26's evidence
  covers **two** proofs, at fixed coefficients, field channels only. Either
  the statement says "one proof per hidden input" or the owner accepts an
  unbounded number on measured evidence. Say which.
* **R-8 — what the first MVP publishes, and to whom.** Receipt only, or
  receipt plus policy; retained by the verifier or discarded. The privacy
  statement is different in each case, and §2.2 lists the channels without
  ever saying which of them a deployment actually emits.
* **R-9 — the endpoint roots are not to be registered.** See §1c: the moment
  an accepted receipt's roots are recorded somewhere that a later artifact
  refers to, D8/D11 binds and the acceptance is void.

## 10. "What must not be claimed" (attack 10)

**The list is obeyed.** I grepped the whole draft for sentences asserting that
privacy is established, proved, accepted or closed
(`is established|is proved|privacy is accepted|establishes privacy|is closed`)
and found six hits, all of them negations or references to other objects
(lines 14, 25, 648, 1205, 1263, 1315). No sentence in the draft claims a
privacy property. Its §1.1 claim is stated as "the claim the project *would
like to be able to make*", its rung (i) wording is accurate, and the riders
travel with the results.

**Four items the list should gain.**

12. **Not "the simulator exists".** Until U-4 runs, the existence of the
    imaginary program is a paper trace — this check's included. A paper trace
    that found the zero witness sitting exactly on two range boundaries is an
    argument for running the test, not a substitute for it.
13. **Not "the statistical target is met".** If R-2 is adopted at 100 bits,
    the toy profile is 22 bits short until `ZkRng::fp` is changed (§9).
14. **Not "refusals are out of scope".** They are inside the project's own
    simulation model (§9).
15. **Not "the captures hold nothing secret" as a permanent fact.** True today
    because the fixture is public; false the first time a capture is taken of
    a real input, and nothing in the code distinguishes the two cases.

## 11. The corrected tally

The draft's tally is 11 PROVED / 7 COMPUTED / 3 ASSUMED / 7 OPEN. Splitting
"PROVED" into what it actually contains:

| label | count | steps |
|---|---:|---|
| **PROVED** — a written proof of a security-relevant statement, unconditional | **2** | 5 (pad absorption, re-derived here), 12 (the derived mask evaluation) |
| **PROVED, CONDITIONAL on an OPEN step** | **3** | 3 and 14 (both on step 2), 17 (on step 18; proof and tests on branch `zk60-mvp-fable` only) |
| **VERIFIED IN THE CODE** — a source reading, not a proof | **6** | 4, 11 (one computed sentence to split out), 19 (**its number is wrong**), 22 (**contains a factual error**), 24 (three omissions), 27 (an inspection at key level) |
| **COMPUTED ON CAPTURES** | **7** | 6, 7, 8, 10, 13, 26, and 23 — whose per-draw term is exact and which I reproduced draw by draw |
| **ASSUMED** | **3** | 1, 15, 16 — agreed, and M-3 (item 22's assumption) must be restated two-sided |
| **OPEN** | **7** | 2 (untested, but verified on paper here), 9, 18, 20, 21, 25, 28 |

Twenty-eight steps, as the draft says. The demotions are 4, 11, 19, 22, 24 and
27 from PROVED to VERIFIED IN THE CODE, and 3, 14 and 17 from PROVED to
PROVED-CONDITIONAL. Nothing was promoted except item 2's *risk*, which this
check lowers without changing its label.

### What I could not check

* **I ran nothing** — no cargo, no test, no prover, no benchmark. §1a is a
  paper trace of the witness builder, not an execution of it. If U-4 is
  written and fails, this check is wrong about the simulator's existence.
* **The four captures' measured results** (chain items 6, 7, 8, 10, 13, 26):
  the tool lives on a branch and I did not run it. I read no capture value.
* **The 125M row totals** behind the 9,257,800 draw count. The arithmetic on
  top of them reproduces D9's accepted figure; the inputs I did not verify.
* **The Python-to-Rust terminal-polynomial port** (item 13's reviewed
  obligation) — unchanged by this check.
* **The Merkle exposure counts.** My own model reproduces 240.7 distinct
  opened leaves, 453.1 revealed leaf digests and 212.4 of unopened columns
  against the draft's 240.7 / 453.2 / 212.5; my node total came to 1,652.8
  against the draft's 1,654.8, a difference in how the top pair is counted
  that I did not chase.
* **The modified and untracked files in the working tree** (Codex is live
  there). I read only `zkp-core/src/mle.rs`'s status, not its content.
* **The attention profile** where its numbers differ from the block's, the
  zkVM line, and the GPU commit path.

## 12. ERRATA AND CONDITIONS FOR ACCEPTANCE

### A. BLOCKING — the draft should not be accepted, or quoted, until these are fixed

| # | what | where | why it blocks |
|---|---|---|---|
| **B-1** | The recommended **100-bit** statistical target is one the design **fails by 22–27 bits** (2^-77.7 toy, 2^-72.9 at 125M). The draft states both and does not reconcile them | §1.4, §5.2, ask R-2 | adopting R-2 as written puts the artifact out of compliance on day one. Fix: either set the target near 70 bits and record why, or pair the ruling with the one-line `ZkRng::fp` change D9 already names (→ ≈2^-141 at the toy shape) |
| **B-2** | Ask **R-3 bundles refusals with timing and power**. The project's own simulation model requires the simulator to mirror refusal behaviour and gives the distinguisher the refusal channel | ask R-3; `ZK60_ENDPOINT_SIMULATION_MODEL.md:75,78` | it would rule out of scope the one channel that carries real information about the input. Split into R-3a (timing/memory/power, owner) and R-3b (refusals, construction) |
| **B-3** | **M-3 is stated in one direction only.** The stream publishes 256 `A` salts *before* it draws `H`'s pads and mask rows; two-sided PRG security is required | M-3 in §1.3, item 22, ask R-4; `pcs.rs:673-674`, `protocol.rs:275-377` | the assumption as written does not cover the case the code creates |
| **B-4** | The LogUp collision bound is **2^-112.0**, not 2^-113 | items 19, 24; §1.4; §5.2 | it is quoted inside the would-be privacy statement. **RECOMPUTED**: 61,440 + 2,048 + 512 + 768 = 64,768 denominators over \|Fp2\| = 2^128 |
| **B-5** | "its call sites are all test modules" is **false** for `ZkRng::new`; and the proposed invariant "no deployment-path commitment is reproducible from a seed" is **false today** on the legacy line | item 22; item 11 of §7.1; `hashline/src/zk.rs:334-338` | a factual error about randomness inside the randomness item, and a code invariant recommended as if it held |
| **B-6** | **P10 cannot detect an empty fibre**, and has **no negative control for its own new criterion** | §4.2 machine-readable form, §4.3 criterion 6, §4.4 | equal fibre dimension does not imply a preimage exists; all ten controls test the old tool. Add `preimage_exhibited` as a fail field and the two controls of §8 |
| **B-7** | The **tally of eleven PROVED** steps overstates what is proved | §3.4 | six are source readings and three are conditional on an OPEN step. Publish the corrected tally of §11 |

### B. CORRECTIONS — the draft's line, the evidence, what it must say instead

| # | the draft says | evidence | it must say |
|---|---|---|---|
| C-1 | item 2's rider: "the zero input must remain **in the declared integer class**" | `results/zk60_privacy_case_check/zero_witness_trace.py`; `layout.rs:54`; `private_block.rs:138` | the condition is over **every admissible public statement and calibration**, and it holds today because `NORM_CEPS = 1` and `exp[0] == 2^F_E` is enforced by the constructor. Name both |
| C-2 | item 1 cites `zk_ffn_fresh_io.rs:103-120` for "the committer is the prover" | `private_seam.rs:142-161`; `private_block.rs:356-386`; `protocol.rs:243-254` | cite the block's own module: `PreparedPlane` has no `Clone`, no serialisation and one consuming method; `Endpoints` only comes from `prepare_endpoints`; a third-party root does not type-check |
| C-3 | §3.3 row 8: disjoint randomness is established by "step 22 … in the source" | item 22's own last three lines | "step 22 **under M-3**" — `A`, `M` and `H` are one stream |
| C-4 | item 11 ends with "the six host groups were modelled jointly … nothing leaked" inside a **PROVED** entry | the draft's own label glossary | split the computed sentence out, or label the entry PROVED + COMPUTED |
| C-5 | item 24's refusal table | `protocol.rs:275`; `pcs.rs:886,890`; `witness.rs:79-81` | add the **entropy failure**, the two **panic** paths (argued unreachable — I checked the draw orders match, §6), and the fact that a witness-builder refusal **names the failing relation** |
| C-6 | item 19: "the zero witness gives the same value" for the LogUp identity, supported by captures | `protocol.rs:61` (`value: Fp2::ZERO`) | it is a **compile-time constant**; no capture is needed. This strengthens the item |
| C-7 | item 9: showing the minors are not identically zero is "the step that carries the content" | §4 of this check | a single capture at full rank **is** a proof of non-vanishing for the minor it witnesses; what remains is the degree bookkeeping, the `M` channel and the `u`-row term |
| C-8 | §2.1 "byte class by byte class" | `wire.rs:17,78-79`; **RECOMPUTED** total 2,816,472 | add the **40-byte envelope** (magic + the 32-byte statement binding). Every other figure in the table is exactly right |
| C-9 | item 25 / §2.2: "every retained capture writes a receipt to disk" | `private_block.rs:477-484`; `native_capture.rs:266-281`; `private_block.rs:166-168` | add that the writer is compiled out of production builds and gated on an environment variable, and that all four captures are of the **public** synthetic fixture — so H9 is procedural today |
| C-10 | §7.1 rank 4: P10 is "a day, once the worktree is free" | §8 of this check | P10's constructed channels need a **new tool**: the present one measures dimensions, it does not build preimages |
| C-11 | ask R-1: domain separation "belongs to the next statement version" | `private_block.rs:16-17`; no freeze manifest names the profile | a profile-scoped tag costs a re-capture and a re-pin, not a frozen-digest break; record the deviation **with an expiry** |
| C-12 | the refusal table's reason "depends on challenges → no [not witness-dependent]" | `transcript.rs:44-51`; the roots are witness-derived | the refusals are equidistributed in the two worlds **under M-1 (the random-oracle model)**, not unconditionally |

### C. OMITTED CONDITIONS — things an acceptance must carry and the draft does not

| # | condition |
|---|---|
| **O-1** | **The caller's context digest must not be a deterministic function of the hidden input.** It is absorbed into the statement (`protocol.rs:31`) and documented as authenticating "the request" (`private_block.rs:277-284`); an unsalted digest of a low-entropy prompt is recoverable by dictionary search, whatever the proof does |
| **O-2** | **The endpoint roots of an accepted receipt must not be registered, republished or referred to by any later artifact.** The moment they are, the D8/D11 game applies and the acceptance is void |
| **O-3** | **The constructors' structure checks are load-bearing for privacy**, not only for correctness (`private_block.rs:124-140`, `:201-207`, `:294-301`). They belong in the theorem's hypotheses and should carry a test that says so |
| **O-4** | **U-4 must assert the two boundary values** this check found: `sigma_s = 16383` of a 16384 window and `p = 512` of an inclusive 512 bound. Acceptance alone would not notice a calibration change that invalidated the simulator |
| **O-5** | **A bound on the number of proofs of one hidden input** (item 26's evidence covers two), or a statement that the MVP makes one |
| **O-6** | **Who may hold a capture bundle, and for how long** — and R-5's rule must name the 112-byte policy, not only the receipt |
| **O-7** | **M-1 (the random oracle) is needed for the refusal argument and for the independence of the opening challenges**, not only for the hash layer. The composition over one table must be written for privacy as well as soundness |
| **O-8** | **The `M` commitment is outside the shape of the generic-rank argument** (47 combined vectors over 4 non-data rows): its hiding comes from `b` and `u` (`zk.rs:452-455`) and needs its own paragraph in U-3(a) |

*(check complete)*
