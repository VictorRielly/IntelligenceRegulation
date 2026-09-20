# Adversarial check of the D8/D11 restatement

**STATUS: COMPLETE.** Independent, adversarial check of
[`ZK60_D8_D11_RESTATEMENT.md`](ZK60_D8_D11_RESTATEMENT.md) for the security
owner. **Nothing here closes D8 or D11, and nothing here establishes a privacy
property.** Where I judge a step sound I say under which model and which
assumption.

| | |
|---|---|
| Checker | delegated Opus checker, no prior context on this file, 2026-09-19 |
| Baseline | working tree at `perf/zk-batch-optimizations`, `f65b2d2` |
| Target | `docs/zkmatrix-poc/ZK60_D8_D11_RESTATEMENT.md`, 1,365 lines, read in full |
| Method model | `ZK60_PRIVATE_ENDPOINTS_AT_SCALE_CHECK.md` §§0–1 and its errata table |
| Ran | one Python arithmetic script, `results/zk60_d8_d11_check/counts.py` (output `counts.out`). No cargo, no proofs, no benchmarks. Nothing else was built, run or measured |
| Sources opened myself | every citation checked below is opened at the cited file and line; the draft's citations were not taken on trust |

## 0. Disposition, method, and scope

**Disposition in one paragraph.** The draft is careful, its counts are exactly
right, its code citations are accurate, and it does not claim a closure. Its
central structural claim — that the "history but one opening" case is empty or
equal to the no-history case — **survives as a statement about today's code and
fails as an argument**, because its content is precisely the theorem's own
hypothesis R2 (§1.2). Its restriction R1 excludes the party that fixed the root
from ever being the distinguisher, which removes the adversary D8 is named for
and leaves the theorem with no named beneficiary (§1.4); the citation offered
to defend R1 licenses Game J, not Game E (§1.5). The simulator itself
reconstructs cleanly and has **no ordering problem**, which is the draft's
strongest and unstated point (§2.1); three of its four channel arguments are
glib or wrong in the source (§2.2). One factual dismissal is false: the
Fiat–Shamir transcript and the Merkle/leaf layer **share the untagged 64-byte
BLAKE3 domain** (§2.3(d)), which makes O5 concrete. Every hash-layer count
reproduces (§3) and one-opening enforcement holds on every code path I could
find (§4). Two of the costing arguments are wrong in ways that favour the
recommendation: the "60–160 % of the budget" verdict against (ii) is a category
error (§5.1), and the "multi-block story survives" claim rests on a `k = 1`
reading the measured pass does not support (§5.2, §5.5). The bias arithmetic
confirms the security owner's ruling exactly (§6). **Nothing here closes D8 or
D11, and nothing here establishes a privacy property.**

**Method.** The draft was read in full. Every citation checked below was opened
at the cited file and line rather than taken on trust; the code read was
`zkp-core/src/pcs.rs` (the ZK half, `hash_column`, `salt_leaf`, `commit_zk*`,
`open_zk`, `verify_zk`), `zkp-core/src/merkle.rs`, `zkp-core/src/transcript.rs`,
`zkp-core/src/rng.rs`, `hashline/src/private_seam.rs`,
`hashline/src/zk_ffn_fresh_io.rs`, `hashline/src/private_block/protocol.rs`,
`hashline/src/private_block.rs`, `hashline/src/private_attention.rs`,
`hashline/src/native_capture.rs`, `hashline/src/bin/hashline.rs` (the pass) and
the four relevant `hashline/examples/`. Documents read: `ZK60_DECISIONS.md`
(D7–D17), `ZK60_ENDPOINT_SIMULATION_MODEL.md`,
`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md`,
`ZK60_JOINT_VIEW_REVIEW_20260918.md`,
`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md` §§2–5,
`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md` §§3–4, `ZK60_ROUND23.md`,
`MVP_STATUS.md` §2, and `ZK60_MVP_JOINT_VIEW.md` §§0–1 on branch
`zk60-mvp-fable`. One Python script was written and run
(`results/zk60_d8_d11_check/counts.py`); its output is committed beside it.
Nothing else was built, run, tested, proved or benchmarked, and no file outside
this document and that directory was created or modified.

## 1. The structural claim: is "the history case is empty" true, and who may be the distinguisher?

### 1.1 What the draft claims

Draft §1.4 splits the obligation into case (a) (no prior opening, no history),
case (b) (history but exactly one opening) and case (c) (opened more than
once), and §3.7 concludes, in bold: *"within the hash layer, case (b) is either
empty or equal to case (a)"*, because every history that defeats the hash-layer
simulator — a previously published authentication path (H3), a query at the
honest top pair (H4), a query at another honest node (H5) — "requires a prior
opening or the commitment randomness".

### 1.2 The claim is definitionally true, and therefore carries no weight

An authentication path **under `R`** is, by construction, a component of an
opening of the commitment whose root is `R`: `OpeningZk.columns` carries the
tuple `(index, column, salt, path)` (`zkp-core/src/pcs.rs:571-572`) and nothing
else in the system emits a sibling chain. So "H3 requires a prior opening" is
not a finding; it is the definition of H3 restated. The load-bearing part of
the claim is therefore entirely **H4 and H5** — can the honest top pair reach
the distinguisher without an opening? — and the draft answers that with R1:
the honest commitment randomness is given to neither `S` nor `D`.

Now read the theorem's own hypothesis (draft §5.2, R2): *"No opening of either
commitment, accepting or rejecting, has been published before the challenge
receipt, **and neither root's honest top pair has reached the distinguisher by
any route**."* The clause after "and" **is** the conclusion of §3.7. The
argument is therefore circular as a narrowing of D11: §3.7 derives from R1 and
R2 exactly what R1 and R2 assume.

This matters because it is the same step the project has already refused twice.
D11 says (`ZK60_DECISIONS.md:287-289`): "An ordinary authentication path or
root-child hash query **can exist before** the sole accepted `finish`; the
consuming API does not erase that history." The disposition it rests on is
blunter (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:36-38`): "Fable's
statement that prior history is either empty or a spent owner is **too
strong**." The draft's §3.7 is that statement with a better enumeration and a
narrower scope ("within the hash layer"). The enumeration is genuine progress.
The conclusion, as a sentence in bold, is the refused one.

**Fair credit, because it changes the disposition:** the draft does not smuggle
a closure. §3.7 ends "This is a narrowing of D11, and it needs the security
owner's ruling, not mine", §1.8 item 4 invites a fifth kind of history, and the
document is labelled DRAFT/NOT A CLOSURE throughout. The defect is in how §1.4's
"three consequences" and §3.7's bold sentence are *worded* — they read as
results and will be quoted as results.

### 1.3 Who commits, in the code — and therefore who the "caller" is

| fact | source |
|---|---|
| `prepare_endpoints` builds **both** commitments and returns `(ExpectedIo, Endpoints)` | `hashline/src/zk_ffn_fresh_io.rs:109-120`; `private_block.rs:375-385`; `private_attention.rs:220-229` |
| `Endpoints` has private fields, no `Clone`, no serialisation | `zk_ffn_fresh_io.rs:103-107`; `private_block.rs:367-370`; `private_attention.rs:212-215` |
| `PreparedPlane` likewise; its only escape is `pub(crate) fn into_ffn_endpoint(self, …)` | `private_seam.rs:143-147`, `:156` |
| `ExpectedIo::from_roots` is **`pub`**: anyone may name arbitrary roots in a 112-byte policy | `zk_ffn_fresh_io.rs:55-69`; `private_block.rs:327`; `private_attention.rs:172` |
| `check_endpoints` refuses unless the prover **holds owners whose own roots equal the policy roots** | `zk_ffn_fresh_io.rs:258-270`; `private_block/protocol.rs:243-253` |

Put together: an `Endpoints` value **cannot leave the process that created it**.
Therefore, in every configuration the code supports, **the committer is the
prover**. The "caller" of "caller-fixed roots" is, today, the prover itself.
That is not a criticism of the draft — it is O9's F2 and F3 restated
(`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:152-157`, `:159-166`) and the
simulation model says the obligation is for "the general `from_roots`
interface" (`ZK60_ENDPOINT_SIMULATION_MODEL.md:42`), i.e. for an interface that
does not exist. But it decides the next question.

### 1.4 Exactly who may act as distinguisher under R1–R3

R1 gives the honest commitment randomness (salts, pads, mask rows) to neither
`S` nor `D`. Anyone holding it can re-run `commit_zk_owned_with`
(`pcs.rs:665-700`) on the plane, rebuild the salted leaves and the tree, read
off the honest top pair `(l, r̂)` with `hash_pair(l, r̂) = R`
(`merkle.rs:14-19`, `:22-35`), and compare it with the pair the receipt's paths
recompute. Against the two-point simulator that detection succeeds with
probability **1**, not `2^-256`.

**May be the distinguisher:** the verifier/regulator that receives only the
112-byte policy and the receipt; any third party; the model owner if it did not
commit.

**May NOT be the distinguisher:** the committer, and anyone the committer gave
the randomness to. Concretely — **a regulator, user or data owner who fixes a
root by committing the plane itself is excluded.** If instead that party hands
the plane in the clear to the prover, who commits it, the party is not excluded
but the root is now prover-generated and the experiment is Game J, where the
simulator issues its own roots and **programs nothing**
(`ZK60_MVP_JOINT_VIEW.md` §1.1, third bullet, branch `zk60-mvp-fable`).

So R1 forces a dichotomy, and the Game E theorem is unnecessary in one branch
and inapplicable to the obvious adversary in the other:

1. **Prover commits.** Game J covers it. The two programmed points are not
   needed. (This is the configuration all of today's code is in.)
2. **A third party commits.** That party holds `r`; under R1 it must not be the
   distinguisher, must never open the commitment (R2), and in practice must
   destroy `r` after handing the plane and the randomness to the prover.

The residual product meaning of the theorem is therefore exactly: *"a
third-party committer who is not the verifier, who never opens, and whose
randomness never reaches the verifier, may fix a root."* **No document in the
repository names that party.** Until it is named, the theorem's product content
is undefined, and §5.1's "it costs no proving time" is not yet a statement
about anything the product does.

Note the asymmetry the draft does not draw: even in branch 2 the caller can only
fix the **input** root, because it does not know the output plane. A
caller-fixed **output** root can only come from an upstream proof — and that
root has already been opened (§5.5 below). So the configuration D8 names, taken
literally and applied to both endpoints, is not reachable at all except by
chaining, and chaining is case (c).

### 1.5 The LNS Definition 2.8 citation does not license R1

Draft §1.6 (lines 254-259) and §5.5 (lines 1286-1290) defend R1 as "exactly the
restriction in Lyubashevsky–Nguyen–Seiler Definition 2.8" and as "the
established commit-and-prove notion", citing O9 §5.

O9 §5 was opened. It confirms Def 2.8 exists and reads as quoted — and then
maps it: *"(a) the adversary still chooses the messages `m_i`, so the analogue
is that `D` may choose the endpoint values while the commitment randomness stays
honest — **which is what Game J says**"*
(`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:236-239`). In Def 2.8 the ideal
world's commitments are output by `SimCom_ck(x)` (`:227-228`): **the simulator
chooses them.** That is Game J, not Game E.

Game E under R1 keeps the commitments environment-produced and demands that the
simulator hit them. It is strictly harder for `S` than Def 2.8 and strictly
weaker than textbook NIZK ZK (where the adversary chooses `r`). It is a **third,
intermediate notion**, and this check found no source in the repository, and
none in the cited paper, that establishes it as standard. **HOLE (repairable):**
the draft must either name the notion as new and project-specific, with the
party of §1.4 written into it, or find a primary source for exactly it. As
written, §5.5's "what is explicitly not a kill" — "it is the established
commit-and-prove notion (LNS Def 2.8)" — is not supported by the source it
cites.

### 1.6 The enumeration H0–H7: one correction and two missing entries

**Correction — H7's status is misstated.** Draft §1.3 and §3.7 both say the
"two proofs of one witness" joint analysis "is not done", citing
`ZK60_ROUND23.md:29`. Line 29 is the *heading* of the section that did it.
Round 23 ran it on the two retained fresh receipts per mode and reports
(`ZK60_ROUND23.md:58-65`): **zero disclosed base dimensions over 88,064 shared
data unknowns** on the jointly shared A/Input/Output system; four dimensions
with every private commitment added, which are exactly the two public H LogUp
identities; and 256 disclosed dimensions in the single-mask ablation control.
Its own scope line (`:67-71`) says it is a two-proof, fixed-coefficient
message/terminal/proximity result that excludes the CFS/pad/encoded-column/
Merkle channels and adaptive composition, and that *"Reusing the same commitment
or proving an arbitrary number of times is not covered."* The honest statement
is "measured on two captures at fixed coefficients, field channels only", not
"not done".

**Missing H8 — a rejected-but-emitted receipt.** Draft §1.5 notices it ("a
failed attempt still emits bytes … a rejected receipt carries 256 genuine
authentication paths under `R`"; source `zk_ffn_fresh_io.rs:256-257`, "No
equality precheck: an endpoint committed to other values must fail the
verifier's polynomial identity", and the same comment at
`private_block/protocol.rs:256-257`) but §1.3's table and §3.7's row-by-row
both omit it. It is reachable today with no new interface: commit an endpoint,
prove against a mismatched witness, publish the resulting bytes. Those bytes are
H3-grade history about `R`. Today the owner is consumed so no *second* opening
follows — but the enumeration claims to be exhaustive and is not.

**Missing H9 — retained captures.** `hashline/src/native_capture.rs:275-281`
writes each accepted receipt, its 112-byte policy and its JSON to disk, and the
joint-view lane reads those files. **A retained capture is a published opening
of its two endpoint roots.** Today each capture uses fresh roots so R2 holds per
root; but closure (i)'s "first published together with the proof that consumes
it" rule must be written so that writing a capture counts as publishing, or the
rule will be violated by the project's own evidence pipeline.

### 1.7 Verdict on item 1

- The "history case is empty" claim **survives as a statement about today's
  code**, under R1 and R2 — and it is definitionally true of H3, so most of its
  content is R1/R2 themselves.
- It does **not** survive as a *narrowing of D11*: its content is R2, which is a
  hypothesis of the theorem it supports. As an argument it is circular, and it
  is the third time the project has been offered this reduction.
- The enumeration is not exhaustive (H8, H9) and one row (H7) is factually
  stale.
- **The party who fixed the root is excluded from being the distinguisher.** A
  regulator who supplied *and committed* the input is excluded. The draft's own
  defence — "the party holding the salts is the endpoint owner, who in this
  system is the prover" (§1.6, line 262-263) — is true of today's code and, in
  that case, makes Game E unnecessary; in the case where it is false, R1 is the
  restriction and it must be defended by naming a real third party, which no
  document does.

## 2. The proposed theorem and its simulator, reconstructed

### 2.1 The simulator for one endpoint, step by step, against the code

The order below is forced by `zkp-core/src/pcs.rs` and
`zkp-core/src/transcript.rs`; I reconstructed it from the sources, not from the
draft.

| # | step | what fixes it |
|---|---|---|
| 0 | `S` receives `(pp, x, R_in, R_out, aux)`. `R` is already inside the 112-byte policy that the transcript absorbs before any challenge exists | `zk_ffn_fresh_io.rs:138-146` |
| 1 | `S` runs the honest prover on the zero witness for the field layer; the FFN's own `A`, `H`, `M` commitments are **genuine** and their roots go into the transcript as usual | `private_block/protocol.rs:275-300`-class paths |
| 2 | the endpoint's row weights `ρ` are drawn from the transcript **before** the vectors are produced | `pcs.rs:919` (`zk_rhos`), verifier mirror `:970` |
| 3 | `S` chooses a full `7 × (256+256)` message/pad matrix: zero data rows, mask and proximity rows and pads chosen so the claim identity holds; encodes it on the coset | `encode_row_zk`, `pcs.rs:618-637` |
| 4 | 2,048 `hash_column` queries (56-byte inputs), 2,048 fresh salts, 2,048 `salt_leaf` queries (64-byte inputs) — **all genuine** | `pcs.rs:137-143`, `:640-645`, `:674`, `:689` |
| 5 | the tree is built genuinely **to level 10 only**, giving `(l′, r′)`; `S` then **programs** `O(l′‖r′) ↦ R` and never queries it | `merkle.rs:22-35` (the honest build would query it; the simulator must not) |
| 6 | the group vector and the proximity vector are computed as row folds and absorbed | `pcs.rs:922-927`; verifier `:981-987` |
| 7 | **only now** are the 256 column indices drawn, with replacement | `pcs.rs:928` → `transcript.rs:119-131` |
| 8 | the 256 tuples `(index, 7 words, salt, 11 siblings)` are read off `S`'s own complete tree | `pcs.rs:930-941` |

**Consequence, and the draft never states it plainly: the two-point
construction has no ordering problem.** The programmed point is the top node
and is independent of the indices; the simulator's tree is complete over all
2,048 leaves before step 7, so any index multiset can be served; the simulator
is *not* allowed to choose leaves after seeing the indices and *does not need
to*. This is exactly where the round-23 free-handle construction is weak —
late salted-leaf programming, which O9 (`:95-99`) and the model document
(`ZK60_ENDPOINT_SIMULATION_MODEL.md:114-116`) flag as "consistent late
assignment, not adaptive Fiat–Shamir security". The draft is right to insist
the two are different artefacts (§2.3's table) and right that F10.3 does not
carry across; it should say the ordering point out loud, because it is the
strongest single argument for the two-point shape.

Note also what step 3 permits: because only the *law* of the view matters, `S`
may fix its endpoint matrix **after** seeing `ρ`, which the real prover cannot.
That extra freedom is legitimate and helps.

### 2.2 What makes each sampled object right — and two places the draft is glib

**(1) The 256 column value vectors.** Draft §3.2 step 1: "Sampling a real
commitment to the all-zero plane and reading off its columns gives exactly the
right law", citing the pad argument
(`ZK60_NATIVE_JOINT_VIEW.md` §9b, branch `zk60-native-jointview`). Two
problems.

- The verifier does **two** checks on these objects, not one:
  `⟨v[..n], c⟩ == combined claim` (`pcs.rs:976-979`) and, per opened column,
  `Σ_i ρ[i]·col[i] == encoded_group_vec[j]` (`pcs.rs:1022-1030`). So the
  matrix is not free: it must satisfy the FFN's claim value and be internally
  consistent with the published vectors at the sampled positions. "Sample a
  real commitment to zero" is therefore **not a sampler**; the object required
  is the joint conditional sampler of O1. §3.5's last paragraph says exactly
  this. **§3.2 and §3.5 contradict each other**, and §3.2 is the sentence that
  will be quoted. ERRATUM.
- The pad argument itself is correctly cited: `q_pad = num_col_checks = 256`
  (`pcs.rs:543`), refused below that (`pcs.rs:670`), and the draws are with
  replacement so the number of *distinct* opened positions is at most 256
  (240.7 in expectation, §3 below) — hence `d ≤ q_pad` always and the
  full-row-rank statement applies with probability 1. That part is sound, as a
  statement about the linear channel only.

**(2) The 256 salts.** Draft §3.2 step 2: "Uniform 32-byte strings, drawn
freshly. **Same law in both worlds** (`pcs.rs:674`)." That is not right as
stated. In the real world the salts are `rng.bytes32()` (`rng.rs:93`) from the
**same keyed BLAKE3 stream** that, moments earlier, produced this plane's five
mask rows (`private_seam.rs:211-213`) and its `rows × 256` pads
(`pcs.rs:673` — pads then salts, in that order, from the same `rng`). 256 of
those 2,048 salts, 8,192 bytes of stream output, are then **published in the
clear** (`pcs.rs:935`). So the equality of laws holds only under the PRG
assumption on `ZkRng`, and in a specific direction: published later outputs
must not reveal earlier secret outputs. §1.7 lists the PRG assumption in its
table; §3.2 asserts identical laws flatly. ERRATUM, and the assumption should
be stated in the theorem next to salted-leaf hiding, not only in a table.

**(3) The unopened sibling digests** (587.2 distinct per endpoint at the tiny
shape, §3 below). In the two-point construction these are **not** uniform
strings to be argued about: they are genuine images of the simulator's own
honest tree. The question "what makes a uniform string indistinguishable from a
hash" therefore does not arise here at all. It arises for the round-23
construction, and that is the whole content of F10.3. The draft has this right.

**(4) The leaf digests of never-opened columns** (212.5 tiny / 254.5 model).
Genuine in both worlds; what they must not reveal is the unopened columns.
Draft §3.4 names the requirement correctly: in the ROM it is immediate
(`≤ q·2^-256`); in the standard model it is a **PRF/extractor-style assumption
on `BLAKE3(y ‖ s)` with a uniform 256-bit `s`**, which is not collision
resistance and is not implied by anything the project has written down.
Agreed, and the 32-byte salt (`pcs.rs:674`, `rng.rs:93`) is ample.

### 2.3 The four attack surfaces, answered against the source

**(a) Does a leaf hash rows of other planes?** No. `hash_column` hashes the
column of **one** `CommittedZk`'s encoded matrix across its `rows`
(`pcs.rs:137-143`, gathered at `:150-163`), i.e. 56 bytes = 7 words for an
endpoint. The two endpoints are two separate `PreparedPlane`s with separate
trees (`zk_ffn_fresh_io.rs:116-117`), and `A`, `H`, `M` are separate
`CommittedZk`s. **But within one endpoint the leaf preimage covers the data
rows *and* the mask and proximity rows**, and all 7 words are published for
each opened column (`pcs.rs:934`). So the simulator cannot choose data and mask
words independently — another reason (1) above is a conditional sampler.

**(b) Shared nodes, leaves or salts.** Each commitment draws its own `nn`
salts (`pcs.rs:674`) and builds its own tree (`pcs.rs:690`). The two endpoints
use two independent OS-seeded streams (`private_seam.rs:196`, called twice from
`zk_ffn_fresh_io.rs:116-117`); `A`/`H`/`M` share one OS stream per attempt
(`private_block/protocol.rs:275`). No structural sharing; coincidences only at
`2^-256`. **But the draft's freshness union is under-counted.** §3.5 unions over
`2,046 + 2,048 = 4,094` points — the endpoint tree alone. The simulator also
honestly answers every point of its *other* commitments (`A` 702 rows, `H`
1,326, `M` 20, each `nn` column hashes + `nn` salted leaves + `nn−1` nodes) and
every transcript absorb/squeeze. The union is of order `3 × 10^4`, not
`4 × 10^3`: the term is about `2^-241`, not `2^-244`. Numerically irrelevant;
**the theorem's constant `2·(q + 2nn − 2)` is wrong** and should be
`2·(q + Q_S)` with `Q_S` the simulator's total honest query count.

**(c) Ordering of programming versus challenges.** Answered in §2.1: no hole
for the two-point construction.

**(d) O5 — shared oracle domains. This is where the draft is wrong on the
facts.** §3.8 item 1 dismisses the composition concern with: *"The transcript's
challenges are `squeeze_bytes` outputs on 47-byte inputs (`transcript.rs:85`,
O10 row 3) — a different length, so no direct overlap."*

The transcript does not only squeeze; it **absorbs**, on the same untagged
BLAKE3, with input `state(32) ‖ len(label)(8) ‖ label ‖ len(data)(8) ‖ data`
(`transcript.rs:44-52`). The length is `48 + |label| + |data|`, which is
**exactly 64 when `|label| + |data| = 16`** — and `absorb_u64` supplies 8 bytes
of data (`transcript.rs:54-56`), so any 8-character label lands in the
64-byte domain. One exists and is on the private path:

```
absorb_u64(b"log-cols", …)  ->  32 + 8 + 8 + 8 + 8 = 64 bytes
```

at `hashline/src/private_seam.rs:253`,
`hashline/src/private_block/protocol.rs:43`,
`hashline/src/private_attention/protocol.rs:38` and
`hashline/src/native_capture.rs:206`. (`b"rows"` gives 60, `b"layer"` 61,
`b"t_rows"` 62, `b"io-side"`/`b"pb-slot"`/`b"pa-slot"` 63, `b"expected-IO"`
with 112 bytes 171; `squeeze_bytes` is 47 — full table in
`results/zk60_d8_d11_check/counts.out`.)

So **the Fiat–Shamir table and the Merkle-node / salted-leaf table share the
64-byte domain**; "no direct overlap" is false, and O10 F10.1's "domain
separation is dimensional, not designed"
(`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:143-157`) extends to the transcript,
which no document currently records.

*How much does it matter?* Numerically, nothing: for the programmed point
`l′‖r′` to be such an absorb input, the uniform right child `r′` would have to
equal the fixed 32-byte string `0x0800000000000000 ‖ "log-cols" ‖
0x0800000000000000 ‖ v`, i.e. `2^-256` per candidate. What it changes is O5's
status. O5 is not "two uses that happen to be length-separated"; it is **two
uses of one domain**, and a simulator that programs a 64-byte point is
programming a point the Fiat–Shamir reduction may also need to control. That
makes O5 a real obligation rather than a precaution, and it makes the draft's
own §3.8 item 1 the place where an external reviewer will notice the
dismissal is unsupported. **HOLE (repairable):** replace the length argument
with a counted union over every 64-byte point the protocol answers, and state
O5 against the actual shared domain.

### 2.4 The theorem as stated: four defects

1. **"Exactly two top-node programming calls."** True for the pinned tiny FFN
   profile. **Not true at the geometry the recommendation is argued at:** D17
   rule 4 records that a feed-forward-only 32-layer private pass has **64
   endpoint roots fixed by the caller** and that "every one of them carries the
   open D8/D11 obligation" (`ZK60_DECISIONS.md:544-549`). The theorem is
   explicitly scoped to `pp = T32/d16/f16`, which is honest; but §4.1, §4.6 and
   §5.1 argue the recommendation at model scale, where the count is 64 and the
   union and the R2 bookkeeping are 32× larger.
2. **The advantage expression is not a bound.** `Δ_field` is "D9's `2^-75` …
   plus the LogUp collision … **plus whatever the discharge of U-3
   contributes**". U-3 is open (`ZK60_NATIVE_JOINT_VIEW.md` §9a answer 5,
   branch `zk60-native-jointview`), so the third summand is unquantified and
   the inequality states nothing. §3.8 item 5 admits it; the theorem statement
   must carry it, or it will be quoted as `2^-175`-class.
3. **R3 admits auxiliary inputs that `Δ_field` does not cover.** R3 allows any
   `aux` "independent of the commitment randomness". A second receipt on an
   *independent* commitment to the *same plane* (the draft's own H7) is
   independent of this commitment's randomness, so R3 admits it — and then
   `Δ_field` must cover a two-proof joint law. Round 23 *measured* that case
   (zero disclosed base dimensions at fixed coefficients on two captures,
   `ZK60_ROUND23.md:58-65`) and explicitly excluded the Merkle/CFS/pad channels
   and adaptive composition (`:67-71`). **HOLE (repairable):** either restrict
   `aux` to exclude other receipts on the same plane, or extend `Δ_field` and
   name round 23 as the only evidence.
4. **The constant `2nn − 2`** — see §2.3(b).

**What I judge sound, and under what model.** Given (i) the programmable ROM
with one table, (ii) R1, R2 and R3, (iii) the joint conditional field sampler
of O1, and (iv) the PRG assumption on `ZkRng` and salted-leaf hiding, the
*hash-layer* step of the two-point construction is correct and its cost is a
union term of order `2·(q + Q_S)·2^-256`. Every one of (i)–(iv) is an
assumption or an unbuilt object; (iii) in particular does not exist. That is
not zero knowledge; it is a correctly-identified reduction of the hash layer to
the field layer plus an assumption list.

## 3. The hash-layer counts, recomputed

Recomputed independently in `results/zk60_d8_d11_check/counts.py` (exact
rational arithmetic, `Fraction`; output in `counts.out`). Model: 256 draws with
replacement from `nn` leaves; expected distinct level-`j` ancestors
`A_j = (nn/2^j)(1 − (1 − 2^j/nn)^256)`; revealed at level `j` = `2·A_{j+1}`
(every child of a revealed ancestor is either recomputed or published);
distinct published siblings at level `j` = `2·A_{j+1} − A_j`.

| quantity | draft (§3.3) | this check | verdict |
|---|---|---|---|
| tiny (`nn` 2048, depth 11) distinct opened leaves | 240.7 | **240.7015** | agrees |
| `A_1 … A_11` | 226.6, 201.6, 162.0, 110.8, 62.9, 32.0, 16, 8, 4, 2, 1 | **226.6054, 201.6081, 162.0071, 110.8126, 62.8642, 31.9906, 16.0000, 8.0000, 4.0000, 2.0000, 1.0000** | agrees |
| leaf digests revealed / of which unopened | 453.2 / 212.5 | **453.2108 / 212.5093** | agrees |
| internal nodes revealed (1–10) | 1,200.6 | **1,200.5652** | agrees |
| total distinct nodes revealed | 1,654.8 of 4,095 (40.4 %) | **1,654.776 of 4,095 (40.41 %)** | agrees |
| distinct sibling digests published | 587.2 of 2,816 slots | **587.1865 of 2,816** | agrees |
| honest queries to build the tree | 6,143 | **6,143** | agrees |
| model (`nn` 65,536, depth 16) distinct opened leaves | 255.5 | **255.5026** | agrees |
| leaf digests revealed / unopened | 510.0 / 254.5 | **510.0130 / 254.5104** | agrees |
| internal nodes (1–15) | 3,643.8 | **3,643.7150** | agrees |
| total distinct nodes | 4,154.7 of 131,071 (3.2 %) | **4,154.728 of 131,071 (3.17 %)** | agrees |
| distinct siblings published | 1,822.4 of 4,096 | **1,822.3614 of 4,096** | agrees |
| honest queries | 196,607 | **196,607** | agrees |
| opening bytes, tiny endpoint | 131,072 | **131,072** | agrees |
| opening bytes, `log_cols 14 / inv_rate 4`, `2^21` plane (133 rows, depth 16) | 946,176 | **946,176** | agrees |
| opening bytes, same plane at `log_cols 8 / inv_rate 8` (8,197 rows) | 16,904,192 | **16,904,192** | agrees |

**Every count in §3.3 reproduces.** Two remarks.

- **"The top pair is *always* revealed."** Correct, and the draft's
  justification is right: `A_{depth−1} = 2·(1 − 2^-255)`, i.e. the deficit is
  exactly `2^-255` at both geometries (the draft writes it as `1 − 2·2^-256`,
  the same number). It is a probability statement, not an identity; §3.3's
  "`A_{10} = 2.0` exactly" and §5.4's proposed assertion "the top pair is always
  revealed (`A_{depth−1} = 2`)" should be phrased as "with probability
  `1 − 2^-255`", or a capture-level gate asserting equality will be asserting
  something that is false with probability `2^-255`. Trivial in practice,
  wrong as written.
- **One arithmetic slip in §3.1.** The table lists the root (32 B) and then
  totals **131,072**, which is `ENDPOINT_OPEN_BYTES` (`zk_ffn_fresh_io.rs:15`)
  and does **not** contain the root — the root lives in the 112-byte policy, as
  the same table says. The following sentence then adds it back:
  "`32 + 8,192 + 90,112 = 98,336` bytes of the 131,072 — 75 %". The correct
  figure is `8,192 + 90,112 = 98,304` of 131,072, which is exactly **75.00 %**.
  The conclusion is unchanged.

## 4. "One opening is enforced": every code path

I opened every path the brief named and looked for a way to obtain two
openings of one endpoint commitment, or to rebuild one.

| claim | source | verdict |
|---|---|---|
| `Endpoints` has no `Clone`, no serialisation, private fields | `zk_ffn_fresh_io.rs:103-107`; `private_block.rs:367-370`; `private_attention.rs:212-215` | **confirmed** |
| `compile_fail` doctests pin the second use at compile time | `zk_ffn_fresh_io.rs:125-131`; `private_block.rs:360-366`; `private_attention.rs:205-211` | **confirmed**, all three present and well-formed |
| `finish`/`prove` take `Endpoints` by value and consume on success *and* failure | `zk_ffn_fresh_io.rs:276-277`; `private_block/protocol.rs:256-258, :268` | **confirmed** |
| `PreparedPlane` has no `Clone` and no data getter; its only exit is `pub(crate) into_ffn_endpoint(self, …)` | `private_seam.rs:143-147`, `:156-161` | **confirmed** |
| `private_seam::prove` consumes both planes | `private_seam.rs:335-339` | **confirmed**, and it additionally requires `left.side == Left`, `right.side == Right` (`:342-347`) |
| `prepare` always draws `ZkRng::from_os`; `prepare_with_rng` is not exported | `private_seam.rs:186-198`, `:200` | **confirmed**: `prepare_with_rng` is a module-private `fn`, its only caller is `:197` |
| no seed path into an endpoint commitment | grep of `hashline/src` for `from_os` / `seed:` | **confirmed**: the only `seed: Some(..)` sites are `zk.rs` unit tests, `zk_ffn_fresh_poc_tests.rs:300` and the diagnostic's `proof_seed` (`zk_ffn_mask_diagnostic.rs:433, :453`), all of which feed `ZkConfig` for the FFN's own `A`/`H`/`M` commitments — none reaches `private_seam::prepare` |
| no import/deserialisation of an owner | grep: the only `from_roots`/`from_bytes` producers build a **policy**, never an owner | **confirmed**; `ExpectedIo::from_roots` is `pub` but yields no opening power |
| no `unsafe` | grep of `private_seam.rs`, `zk_ffn_fresh_io.rs`, `private_block.rs`, `private_attention.rs`, `pcs.rs`, `merkle.rs` | **confirmed**: none |
| `check_endpoints` makes a proof impossible for a foreign root | `zk_ffn_fresh_io.rs:258-270`; `private_block/protocol.rs:243-253` | **confirmed** |
| the example under `hashline/examples/` does not build an endpoint from a seed | `zk60_bound_ffn.rs:92` prepares; `:117` uses `from_roots` **only on the verify path** to rebuild a policy from a trusted file | **confirmed**, no prover-side import |

**So §1.5's claim holds as written, on every path I could find.** Four caveats
the draft should carry.

1. **`CommittedZk`'s fields are all `pub`** — `data`, `pads`, `salts`
   (`pcs.rs:551-564`). The endpoint plane's secrecy inside the `hashline` crate
   rests on `PreparedPlane.committed` being private (`private_seam.rs:146`) and
   on `into_ffn_endpoint` being `pub(crate)` and by-value. Integration tests and
   examples are separate crates and cannot reach it; a future `pub` accessor, or
   any new module inside `hashline`, can. This is a one-line invariant worth
   asserting, alongside O4.
2. **The guarantee is about the private-seam endpoint path only.** The release
   CLI accepts `--zk --seed N` (`hashline/src/bin/hashline.rs:120`), which makes
   the legacy zk path's `A`/`H`/`M` commitments byte-reproducible; the binary
   prints "INSECURE TEST RANDOMNESS … provides no privacy" (`:178-179`), so the
   project knows. It does not touch endpoints. But O4's mechanical gate should
   also assert "no commitment in a deployment receipt is reproducible from a
   seed", not only the row-count invariant.
3. **Two independent commitments to the same plane are trivially reachable and
   are shipped as an example**: `hashline/examples/zk60_seam_receipt.rs:35-36`
   calls `seam::prepare` twice on the same `vals`. That is the draft's H7, and
   §1.6 above corrects its status.
4. **A rejected-but-emitted receipt** (draft §1.5's own observation;
   `zk_ffn_fresh_io.rs:256-257` "No equality precheck") publishes 256 genuine
   paths under `R`. The type system does not prevent *that*; it prevents a
   second one. The named invariant of §5.4/O6 must therefore be "at most one
   receipt of any kind, accepted or rejected, ever leaves the process for a
   given root", which is **not** what the types enforce — they enforce "at most
   one `finish`".

## 5. The five candidate closures

### 5.1 (ii) the caller-fixed salted handle: arithmetic and the two impossibility claims

**The arithmetic reproduces** (`counts.out`): `2^21` words as int16 = 4,194,304 B
= **65,536** compressions per endpoint; central case `5.243 × 10^8` lookups =
**22.8 %** of the pass's `H = 2.296 × 10^9`; `3.277 × 10^8` committed words =
**3.35 %** of `9.777 × 10^9`; seconds `= 5.555 × 0.228 + 3.277×10^8 / 1.67×10^8
= 1.27 + 1.96 = **3.23 s**`. The draft's "+3 to +4 s central" is right.

**But the headline verdict is a category error, and it is the draft's most
consequential number.** §4.2 concludes: "Against the **5-second target** it is
between 60 % and 160 % of the *entire* budget". The 58.40 s pass is **11.7×**
the 5 s target (`MVP_STATUS.md:137`). The +3.2 s was computed as a *fraction of
the same pass's own work* — 22.8 % of its helper time and 3.35 % of its
committed volume. If the pass ever reaches 5 s, it reaches it by making that
same work cheaper, and the hash gadget takes the same discount: **+0.28 s, i.e.
5.5 % of the 5 s budget.** The honest metric for a lever proportional to
committed volume is the relative one the draft itself computes two paragraphs
earlier: **+5.5 % of a public pass, +12.6 % of a private pass.** (Caveat in the
other direction: if the 11.7× ever comes from a change that does not help the
gadget — a lower encoding rate under D14, say — the absolute figure is right
for that part. The draft should say which, not pick the unfavourable framing
silently.) This materially weakens §5.1's "it is the wrong place to spend the
last remaining headroom".

*Tiny shape:* 16 compressions/endpoint ✓; 128,000 extra lookups = **37.7 %** of
`H_tiny = 339,456` ✓ (draft: +38 %); 80,000 extra committed words — the draft's
"**+13 %**" is **not reproducible from any denominator stated in the
document**. Against the message-part committed words
`(702 + 1326 + 20 + 2×7) × 256 = 527,872` it is **15.2 %**. Minor, but a
reader cannot check it.

**Pedersen — the stated reason is wrong, the conclusion stands.** "Linking a
Pedersen-committed vector to a Ligero-committed one is a cross-system argument
that needs the second commitment to be homomorphic. Ligero is not." A
Ligero/Brakedown opening *is* a linear functional of the committed rows
(`fold_rows_multi_zk`, `pcs.rs:922`), and CP-link constructions do not in
general require both commitments to be group-homomorphic. The real and
sufficient obstruction is the draft's *next* clause: an elliptic-curve
multi-scalar multiplication would have to be arithmetised over Goldilocks
(non-native field arithmetic) and the verifier does Goldilocks only. Keep the
conclusion, replace the reason.

**SIS pigeonhole — the argument proves too much.** "The multilinear polynomials
vanishing at `k` fixed points form a space of dimension `2^21 − k`, which by
pigeonhole contains short vectors, so two distinct short planes collide." The
identical counting applies to a **random** `A`: any map from `2^21` int8 words
(`2^24` bits) to `k` Goldilocks elements (`64k` bits) has colliding short
preimages for every `k ≪ 2^18`. Existence of short collisions is not a break of
SIS — SIS binding is *computational*. The correct statement is that for this
**structured** `A` the collisions are efficiently *findable* (the vanishing
subspace is explicit linear algebra, and with `n = 2^21 ≫ k` the instance is so
over-determined that combinatorial/lattice search is easy), whereas for a
random `A` at `n ≈ k log q` they are conjectured hard. The conclusion is right;
as written the reasoning would also refute the primitive being proposed. §6
item 5 already declines to call it an impossibility, which is the right
instinct — the *argument* should be fixed to match.

**Verdict on (ii).** "Closes (a), (b) and (c)" is right *provided* the caller's
handle is never opened and the fresh PCS root is opened exactly once — and
provided Game J's simulator exists, which it does not: the model document says
of `SimProve`, "This algorithm is not yet complete"
(`ZK60_ENDPOINT_SIMULATION_MODEL.md:76`). The draft's residual list says so.

### 5.2 (iii) re-randomise and link: the recount, and the `k = 1` claim

The opening counts are **correct** given the premise that a link argument opens
each side once, and that premise is confirmed at the source: a seam proof
carries two 11-level endpoint openings plus a 12-level mask opening
(`private_seam.rs:600-608`) and consumes both planes (`:335-339`). Star:
`C_0` opened `k` times, interior `C_i` twice — violates D12 rule 1 at `k ≥ 2`.
Path: interior three times, and at `k = 2` both ends twice. (iii) is dominated.
Agreed.

**The `k = 1` reading is not supported by the evidence offered.** §4.3 says the
architecture is "partly" there and calls it "encouraging", citing
`hashline/src/bin/hashline.rs:6`, `:707`, `:714`. Traced: `pass` calls
`hashline::layer::prove_layer` (imported at `:25`, called at `:714`) — the
**public** prover — building a per-layer `Statement { l, t_rows, shifts, table,
table_digest }` (`:717`) with **public** inter-layer activations (rung 1,
`chain`, "reproduces every z digest", `:3`). `MVP_STATUS.md:137` labels that
row "**public IO**". So the measured 58.40 s pass is *32 statements sharing one
transcript with public activations* — which is precisely why `k = 1` is free
there, and says nothing about the private case. The private path has **no
multi-block entry point at all**; the only chain example is
`hashline/examples/zk60_chain_receipt.rs`, which is `public_chain_receipt`,
mode "P0-public-synthetic" (`:9-10`, `:97`). The draft's §6 item 2 flags that
it did not trace this. **Resolved here, and the answer is the unfavourable
one.**

### 5.3 (iv) the hash-layer options

- **(iv-a)** correct: the indices are transcript-derived and re-derived by the
  verifier (`pcs.rs:988-990` → `transcript.rs:119-131`); they cannot be hidden.
- **(iv-b)** "moves every frozen digest" is **right**: `pcs.rs` and `merkle.rs`
  are the commitment core, and D17 rule 2 makes anything there non-additive
  (`ZK60_DECISIONS.md:537-540`). "Does not buy case (c)" is also **right**, and
  for the reason given: the two-opening recovery is a mask-budget fact about
  `v = a·x + b·y + c·m` in the extension field
  (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:16-21`), entirely field-layer,
  so no change of tree touches it.
- **(iv-c)** correct in direction. **(iv-d)** the ~1 % figure is consistent with
  D10's own correction (`ZK60_DECISIONS.md:426-433`).

### 5.4 (i) + (v): enforceable, or a usage rule?

**A usage rule**, and the draft says so ("a property of the world, not of the
artefact"). Three additions.

- The "make `context` a per-request nonce and reject a repeat" option is not
  cheaper than the registry: the verifier is stateless (`verify` rebuilds the
  transcript from the 112 bytes alone, `zk_ffn_fresh_io.rs:412`), so "reject a
  context it has seen" *is* a registry, relocated.
- R2 as stated must be read to cover **rejected receipts** and **retained
  captures** (§1.6 H8/H9, §4 caveat 4). "One `finish`" is not "one published
  path set".
- At model scale the rule binds **64 roots per pass**, not two (D17 rule 4,
  `ZK60_DECISIONS.md:544-549`).

And "(b) closes vacuously" is the circularity of §1.2: (b) is empty *because*
R2 says so.

### 5.5 The chaining question, which the draft waves away

Configuration named in the brief: an output root published **with** the
upstream proof and consumed **later** by a downstream proof. Three answers, all
of which the draft has the pieces for and none of which it states together.

1. **It is a second opening.** The upstream receipt contains a full opening of
   that commitment — 256 columns, salts and 11-level paths
   (`pcs.rs:930-941`). Consuming the same root downstream opens it again, and
   §2.1's PROVED recovery applies: two openings at the 7×256 geometry recover
   **all 512 data words** (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:3-9`;
   regression `zkp-core/tests/endpoint_reuse.rs`). Case (c). D12 rule 1
   forbids it (`ZK60_DECISIONS.md:319-322`).
2. **It is *also* prior history.** The upstream paths hand out the honest top
   pair, so the hash-layer simulator dies independently of (1). Both
   mechanisms, not one.
3. **It is unimplementable today.** `Endpoints` is consumed and non-`Clone`,
   and `private_seam::prepare` always draws fresh OS entropy
   (`private_seam.rs:196`), so the prover cannot rebuild the commitment for a
   second proof even if it wanted to.

**The consequence the draft does not draw:** there is no way to chain two
separately-finished private proofs at all. The only surviving composition is
"one transcript, one proof, two external endpoints" — the whole run in one
statement. That collides with the project's other draft of the same day, which
recommends chaining "as short runs of blocks under one transcript **starting at
two**" (commit `caa90af`): the boundary between two runs is exactly a root that
one run opens as its output and the next opens as its input, i.e. case (c).
Either a private run is one transcript end to end, or its boundaries need
closure (ii)'s non-PCS handle. **§5.1's "the multi-block story survives" is
therefore not established**, and it rests on the `k = 1` claim refuted in §5.2.

This also settles §1.4's asymmetry: a caller-fixed **output** root has no
honest origin. Nobody but the prover knows the output plane; the only party who
could have committed it earlier is an upstream prover, which has already opened
it.

## 6. The residual-term discrepancy

Recomputed with exact rationals (`counts.py::bias`, output in `counts.out`).
`p = 2^64 − 2^32 + 1`; a draw is a uniform 128-bit integer reduced mod `p`
(`zkp-core/src/rng.rs:72-77`, `Fp::from_u128`).

- `2^128 mod p = 18446744065119617025 = p − 2^32` — **confirmed**.
- Writing `2^128 = q·p + s` with `s = p − 2^32`: exactly `s` residues occur
  `q + 1` times and exactly `2^32` residues occur `q` times.
- **Total statistical distance of one draw from uniform: exactly `2^-96.000000`.**
- **Relative bias of one outcome:** the `2^32` under-represented residues are
  short by exactly `2^-64` relative; the others are over by `2^-96` relative.
- Accumulations: `6144 · 2^-96 = 2^-83.42`; `2^21 · 2^-96 = 2^-75.00`;
  `2^23.1 → 2^-72.90`; `2^24.3 → 2^-71.70`.

**This confirms the security owner's ruling exactly**, including the figures in
D9's verification note (`ZK60_DECISIONS.md:394-408`, which gives 2^-75.0,
2^-72.9, 2^-71.7). D9's accumulated figures stand.

**Which document states it wrongly.** `ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md`
**F10.4** (`:135-142` and the summary at `:167-169`): it reads the source
comment's "bias 2^-64" as the per-draw distance and derives a floor of
`6144 · 2^-64 ≈ 2^-51.4`. That is the one substantive error; the correct figure
for the same 6,144 endpoint draws is `2^-83.4`. Its *qualitative* conclusion —
that the reduction term dwarfs `q/2^256` and a bound must not lead with
`q/2^256` — survives, because the whole-proof term is `2^-75`, not `2^-175`.
The origin of the error is the source comments themselves, which say "bias
2^-64" without saying *which* bias: `zkp-core/src/rng.rs:72` and
`zkp-core/src/transcript.rs:96`. Both are correct as a per-outcome relative
figure and misleading as a distance; they are one word from being right
("relative bias 2^-64; statistical distance 2^-96").

**And the draft is stale, not wrong.** §1.7's "One correction to the record,
offered for the security owner's ruling" and §6 item 4 ("could not determine
whether the D9 per-draw bias is 2^-64 or 2^-96") present this as open. It was
settled by the security owner in the register at 21:50 on the same day
(`ZK60_DECISIONS.md:394-408`), with the same `2^128 mod p = p − 2^32`
derivation. The draft's own recomputation (`6144 · 2^-96 ≈ 2^-83.4`) agrees
with mine. Delete §6 item 4 and rewrite §1.7's "correction" as a citation of
D9's verification note.

## 7. What an outside reviewer attacks first, and the kill criterion

### 7.1 My ranking of the first objections

1. **The definition, before any algebra.** The first question is "what is your
   zero-knowledge notion?" and the answer is Game E under R1 and R2. R1 puts
   the commitment randomness beyond the distinguisher — which excludes the
   party that fixed the root from ever being the adversary (§1.4) — and R2 is a
   hypothesis the verifier cannot check from the artefact and which the
   draft's §3.7 then *derives* (§1.2). A reviewer will make this one objection,
   not three, and it lands before the counting. The LNS citation does not
   answer it (§1.5).
2. **"Your theorem has an unquantified term."** `Δ_field` contains "whatever
   the discharge of U-3 contributes" and U-3 is open, so the displayed
   inequality bounds nothing. It should be presented as the statement the
   project *intends* to prove; §5.2 almost does this and the abstract does not.
3. **O5, and for a better reason than the draft gives.** The Fiat–Shamir
   transcript and the Merkle/leaf layer genuinely share the untagged 64-byte
   BLAKE3 domain (§2.3(d)); the draft's length argument for "no direct
   overlap" is false. The union is still negligible, but the composition
   question is now concrete rather than hypothetical.
4. **The circularity of §3.7** (§1.2), which a reviewer who has read D11 will
   spot immediately because D11 refused the same reduction.

**Not first, and the draft is right about them:** the counts (they reproduce
exactly, §3); §3.6's informal trilemma (already demoted to a taxonomy, and it
should stay demoted); and "40 % of the tree is revealed", which is a red
herring for the reason §3.8 item 3 gives.

### 7.2 Is the kill criterion the right one?

The **primary kill** (O1 shown impossible at the pinned profile) is the right
primary, and the **early warning** — a nonzero disclosed data dimension on an
endpoint role once the nonlinear channel enters the model, against today's
measured 0 — is a genuinely cheap, monitorable trigger tied to a tool that
already runs. Both are well chosen.

The kill *set* is incomplete in the direction that actually decides the
product. Two kills are missing, and both are cheaper than O1.

- **A product kill, decidable this week and before any of §5.2 is written.**
  If the party of §1.4 cannot be named — if every realistic committer is either
  the prover (Game J, in which case no Game E theorem is needed) or the
  verifier/regulator (excluded by R1) — then the theorem is worth nothing even
  if proved. This costs one question to Victor and should be answered **first**,
  because it determines whether (i)+(v) is a route or a formality.
- **An architecture kill, decidable by counting, not cryptography.** If an 8B
  private pass cannot be one transcript end to end — for memory on the 15 GB
  box, or because the form-E draft's "short runs of blocks starting at two" is
  adopted — then closure (i) does not survive, because a run boundary is a root
  opened by two proofs (§5.5). The `k = 1` claim that (i) leans on is already
  refuted for the only pass that has been measured (§5.2).

One correction to the **second kill** as stated. "If programming the oracle for
privacy is shown to invalidate the Fiat–Shamir soundness reduction" is a
proof-shaped criterion nobody will ever discharge or refute cleanly. Given
§2.3(d) there is a sharper, mechanical form worth adding beside it: **"if any
64-byte point the simulator programs lies in the set of 64-byte points the
protocol itself answers"** — which is a finite, checkable statement about
`hash_pair`, `salt_leaf`, `hash_column` at 8 rows, and every `absorb` whose
`|label| + |data| = 16`.

## 8. ERRATA, HOLES AND CONDITIONS

**HOLE** = a step of the argument that fails or is unjustified as written.
**CORRECTION** = a factual or arithmetic error that does not by itself break a
step. **CONDITION** = what must hold before the recommended route could be
adopted as the project's stated position.

| # | kind | where | finding | repairable? how |
|---|---|---|---|---|
| 1 | **HOLE** | §3.7 (and §1.4's three consequences) | "Within the hash layer, case (b) is either empty or equal to case (a)" is **circular**: H3 ⊆ "a prior opening" is definitional, and everything else is excluded by R1/R2 — and R2 *states* the conclusion ("neither root's honest top pair has reached the distinguisher by any route"). D11 and `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:36-38` refused this reduction twice already | Yes. Demote §3.7 from a result to "an enumeration of what R2 assumes". State the reduction as "D11 becomes: exclude case (c) by rule **and** assume R2", never as "case (b) is empty" |
| 2 | **HOLE** | §1.6, §5.2 R1 | R1 hides the commitment randomness from the **distinguisher**, which excludes the party that fixed the root from ever being the adversary. In today's code the committer *is* the prover (`Endpoints` cannot leave the process), so Game E is unnecessary; in any other configuration the committer is a real party and **no document names it**. A regulator who supplied *and committed* the input is excluded | Only by a product ruling naming that third party (not the verifier, never opens, withholds `r`) — or by dropping Game E in favour of Game J plus closure (ii) |
| 3 | **HOLE** | §1.6 lines 254-259; §5.5 lines 1286-1290 | LNS Def 2.8 is cited as "exactly the restriction" and "the established commit-and-prove notion". O9 §5 — the draft's own source — maps Def 2.8 to **Game J** (`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:236-239`), whose ideal commitments are produced by `SimCom`. Game E-with-R1 is a third, intermediate notion with no cited source | Yes. Name it as new and project-specific; remove "established" and remove it from §5.5's "what is explicitly not a kill" |
| 4 | **HOLE** | §5.2 R3 vs `Δ_field` | R3 admits any `aux` independent of *this* commitment's randomness — including a second receipt on an independent commitment to the **same plane** (the draft's H7). `Δ_field` does not cover a two-proof joint law | Yes. Restrict `aux`, or extend `Δ_field` and cite round 23 as the only evidence (measured, fixed coefficients, two captures, field channels only) |
| 5 | **HOLE** | §3.8 item 1 | "The transcript's challenges are `squeeze_bytes` outputs on 47-byte inputs — a different length, so no direct overlap" is **false**. `Transcript::absorb` is `BLAKE3(state‖8‖label‖8‖data)` (`transcript.rs:44-52`), 64 bytes whenever `|label|+|data| = 16`; `absorb_u64(b"log-cols", …)` is exactly that, at `private_seam.rs:253`, `private_block/protocol.rs:43`, `private_attention/protocol.rs:38`, `native_capture.rs:206`. Fiat–Shamir and the Merkle/leaf layer **share the untagged 64-byte domain** | Yes, and the bound does not move (`2^-256` per candidate). Replace the length argument with a counted union over every 64-byte point the protocol answers; restate O5 against the real shared domain; add the mechanical check of §7.2 |
| 6 | **HOLE** | §5.2 | The advantage expression is **not a bound**: `Δ_field` contains "whatever the discharge of U-3 contributes", and U-3 is open | Yes. Label it the statement the project intends to prove, in the theorem itself, not only in §3.8 item 5 |
| 7 | **HOLE** | §3.2 step 1 vs §3.5 last paragraph | "Sampling a real commitment to the all-zero plane and reading off its columns gives exactly the right law" is not a sampler: `verify_zk` enforces `⟨v, c⟩ = claim` (`pcs.rs:976-979`) **and** the per-column row fold (`:1022-1030`), so the matrix is conditioned. §3.5 says this; §3.2 contradicts it and is the quotable sentence | Yes. Delete the §3.2 sentence and point at O1 |
| 8 | **HOLE** | §3.2 step 2 | "256 salts … **same law in both worlds**" ignores that the salts come from the same keyed BLAKE3 stream as this plane's secret mask rows (`private_seam.rs:211-213`) and pads (`pcs.rs:673-674`), and that 8,192 bytes of that stream are published per endpoint (`pcs.rs:935`) | Yes. State the PRG assumption on `ZkRng` in the theorem, in the "published later outputs must not reveal earlier secret outputs" direction |
| 9 | **HOLE** | §4.3, §5.1 | "The multi-block story survives" rests on the `k = 1` architecture being "already there". The measured 58.40 s pass is the **public** prover (`bin/hashline.rs:25, :714`), 32 per-layer statements sharing one transcript with public activations (`MVP_STATUS.md:137`). The private path has no multi-block entry point; the only chain example is `public_chain_receipt` ("P0-public-synthetic"). And the same author's form-E draft (`caa90af`) recommends runs of ≥ 2 blocks, whose boundaries are roots opened twice | Only by an architecture decision: one transcript per private request end to end, or closure (ii)'s non-PCS handle at run boundaries |
| 10 | **HOLE** | §1.3's table (exhaustiveness) | Two reachable histories are missing. **H8**, a rejected-but-emitted receipt: `finish` has "No equality precheck" (`zk_ffn_fresh_io.rs:256-257`) and emits 256 genuine paths under `R` before the verifier rejects — the draft notices this in §1.5 and does not carry it into §1.3/§3.7. **H9**, retained captures: `native_capture.rs:275-281` writes complete receipts and policies to disk | Yes. Add both rows; restate R2 as "no published path set of any kind, accepted, rejected or captured" |
| 11 | CORRECTION | §4.2, §5.1 | "Against the 5-second target it is between 60 % and 160 % of the entire budget" is a **category error**: the +3.2 s is a fraction of the same pass's own work (22.8 % of helpers, 3.35 % of committed volume), so it scales with the pass. Relative cost **+5.5 % public / +12.6 % private**; under a uniform 11.7× speedup, **+0.28 s of the 5 s budget** | Quote the relative figures; if a future speedup would *not* help the gadget (e.g. a rate change under D14), say so explicitly |
| 12 | CORRECTION | §4.2 Pedersen bullet | "Needs the second commitment to be homomorphic. Ligero is not" is wrong as reasoning — a Ligero opening is a linear functional of the rows (`pcs.rs:922`) and CP-link does not require both sides homomorphic. The valid reason is the next clause: EC arithmetic non-natively over Goldilocks | Replace the reason; keep the conclusion |
| 13 | CORRECTION | §4.2 SIS bullet | The pigeonhole argument proves too much: short collisions exist for a **random** `A` too (`2^24` bits in, `64k` bits out). SIS binding is computational. The right statement is that for the structured `A` they are efficiently **findable** | Rewrite; §6 item 5's refusal to call it impossibility is the right instinct |
| 14 | CORRECTION | §1.3 and §3.7, H7 rows | "The joint analysis is not done" is stale. Round 23 ran it: **zero disclosed base dimensions over 88,064 shared data unknowns**, four with every private commitment (the two public H identities), 256 in the single-mask control (`ZK60_ROUND23.md:58-65`), excluding CFS/pad/encoded-column/Merkle channels and adaptive composition (`:67-71`). The draft cites `:29`, which is the section's heading | Restate as "measured at fixed coefficients on two captures, field channels only" |
| 15 | CORRECTION | §3.5 table, §5.2 constant | The freshness union counts only the endpoint tree's 4,094 own points. It must also cover the simulator's `A`/`H`/`M` trees and the transcript's own queries: order `3 × 10^4`, so `≈ 2^-241`, not `2^-244`. The theorem's `2·(q + 2nn − 2)` should be `2·(q + Q_S)` | Trivial; numerically irrelevant |
| 16 | CORRECTION | §5.2, §4.1, §4.6, §5.1 | "Exactly two top-node programming calls" is the **tiny profile only**. D17 rule 4 records **64 caller-fixed endpoint roots** in a feed-forward-only 32-layer private pass, each carrying D8/D11 (`ZK60_DECISIONS.md:544-549`). The recommendation is argued at model scale | Scope every model-scale sentence, or restate the theorem for `m` roots |
| 17 | CORRECTION | §3.1 | The root's 32 bytes are in the 112-byte policy, not in `ENDPOINT_OPEN_BYTES`. The hash layer is `8,192 + 90,112 = 98,304` of 131,072 = **exactly 75 %**, not `98,336` | One line |
| 18 | CORRECTION | §3.3, §5.4 | "The top pair is *always* revealed" holds with probability `1 − 2^-255` (verified: the deficit `2 − A_{depth−1}` is exactly `2^-255` at both geometries). §5.4 proposes asserting `A_{depth−1} = 2` in a capture gate | Phrase as a probability, or the gate asserts something false with probability `2^-255` |
| 19 | CORRECTION | §1.7, §6 item 4 | The `2^-64` vs `2^-96` question is presented as open. It was settled the same day (`ZK60_DECISIONS.md:394-408`). **Confirmed independently here**: total statistical distance exactly `2^-96`, per-outcome relative bias exactly `2^-64`, `6144·2^-96 = 2^-83.42`, `2^21·2^-96 = 2^-75.00`. The document that states it wrongly is **O10 F10.4** (`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:135-142`, `:167-169`); the origin is the source comments `rng.rs:72` and `transcript.rs:96` | Delete §6 item 4; rewrite §1.7's "correction" as a citation of D9's note; fix the two source comments to say "relative bias 2^-64; statistical distance 2^-96" |
| 20 | CORRECTION | §4.2 tiny shape | "+13 % committed words" is not reproducible from any denominator in the document; against the message-part total `(702+1326+20+14)·256 = 527,872` it is **15.2 %** | State the denominator |
| 21 | CORRECTION *(in the draft's favour)* | §3.5 | The draft never states its strongest point: the **two-point construction has no ordering problem**. The programmed point is the top node, independent of the 256 indices, which are drawn only after the group and proximity vectors are absorbed (`pcs.rs:922-928`); the simulator's tree is complete, so it never needs to choose leaves after seeing indices. That is exactly where the round-23 free-handle construction is weak | Add it; it is the clearest reason to prefer the two-point shape |
| 22 | **CONDITION** | — | A ruling from Victor **naming the party that fixes a root**: not the verifier, never opens, and does not retain or forward the commitment randomness. Without it the theorem has no product meaning (HOLE 2) | |
| 23 | **CONDITION** | — | The notion written out as project-specific, with R1/R2/R3 and the **excluded parties** in the product claim — the way D7's three qualifiers travel with the zkVM claim (`ZK60_DECISIONS.md:242-251`) | |
| 24 | **CONDITION** | O6 | R2 enforced as "**one published path set of any kind per root**" — accepted, rejected or captured — with a capture-level gate that refuses two retained receipts sharing an endpoint root or a context digest, and a negative control | |
| 25 | **CONDITION** | O1, O2 | The joint conditional field sampler and the joint hypothesis discharged, or `Δ_field` stays unbounded and §3 is moot | |
| 26 | **CONDITION** | O5 | O5 restated against the **actual shared 64-byte domain** (HOLE 5), with the mechanical point-set check of §7.2 alongside the written composition argument | |
| 27 | **CONDITION** | §4.3, §5.5 | The architecture question settled in writing: one transcript per private request end to end, or closure (ii) at run boundaries. Until then "the multi-block story survives" must not be stated | |
| 28 | **CONDITION** | O4 | The mechanical invariants asserted in code and tested: `commitment_rows ∉ {5, 8}` for every reachable seam shape (today `{6,7,9,13,21}`, verified from `private_seam.rs:55-72`, `:106-111`); `8·rows ∉ {40, 64}` for every commitment in a receipt; no deployment-path commitment reproducible from a seed; and no new accessor exposing `PreparedPlane`'s `CommittedZk` (whose `data`, `pads`, `salts` fields are `pub`, `pcs.rs:551-564`) | |

### What would still be open if every item above were fixed

1. **D8 and D11 themselves.** Nothing in the draft or in this check closes
   them. The best case is that the obligation is *re-scoped* — from "simulatable
   for any caller-fixed root with prior history" to "simulatable for a root
   fixed by a named third party that has never published an opening" — and that
   re-scoping is a **product decision**, not a proof.
2. **The field layer.** O1 (the joint conditional sampler) and O2 (the joint
   hypothesis, U-3) are the hard obligations and neither is started. All of §3
   is conditional on O1.
3. **The whole-view bound.** Even with O1 and O2, the bound carries D9's
   `2^-75`/`2^-72`, the LogUp collision, the `ZkRng` PRG assumption, salted-leaf
   hiding as a non-standard BLAKE3 assumption (§3.4), the programmable ROM, and
   O5's composition with soundness. It is a computational, programmable-ROM
   statement with a five-item assumption list; it will never be statistical ZK
   (§3.6's trilemma, whose informality the draft correctly flags).
4. **Case (c) at model scale.** The two-opening recovery is proved and
   field-layer; no hash-layer change touches it. Every widening, every chain,
   every retry path must keep one opening per commitment, and the verifier
   cannot check that from the bytes.
5. **Everything outside the hash and linear-field layers**: the nonlinear
   cross-channel link, integer-range side information about the planes, timing,
   and the adaptive/distributional lift — all listed by
   `ZK60_NATIVE_JOINT_VIEW.md` §7 and none affected by anything here.

### What I did not check

- I ran **no** Rust, no cargo, no proof, no benchmark. `zkp-core/tests/endpoint_reuse.rs`
  was not executed; §2.1's PROVED recovery is taken from its disposition.
- The branch-only artefacts were read but not run:
  `ZK60_MVP_JOINT_VIEW.md` (`zk60-mvp-fable`) was read for §1.1/§1.2;
  `ZK60_NATIVE_JOINT_VIEW.md` (`zk60-native-jointview`) was **not** opened — every
  claim I attribute to it is relayed from the draft and marked as such
  (§2.2(1), §2.4 item 2). `scripts/zk60_root_simulator.py` and
  `tests/test_zk60_sequential_kernel.py` were not opened.
- I did not re-derive the sequential-kernel lemma (§2.4 of the draft) or check
  `ZK60_ROUND24/25.md` beyond the endpoint paragraphs.
- I did not attempt a construction: no alternative simulator, no attack, no
  search for a structured SIS matrix, and no cost model for a hash gadget.
- I did not read the attention or block construction memos, the zkVM line
  beyond D3–D7, or `ZK60_L4_FEWER_HASHED_BYTES_MEMO.md` (its `H`, committed-word
  and 5.555 s figures are taken from the draft's citation and only used
  arithmetically).
