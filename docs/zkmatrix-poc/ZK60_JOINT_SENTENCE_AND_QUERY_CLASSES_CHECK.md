# Independent adversarial check of the joint sentence and the query-class table

**Part A's sentence: HOLDS WITH CHANGE** (it is true in the world it is stated
in, but it takes **two** hops and not one, their **order** is load-bearing and
unstated, clause (a) and clause (c′) are definitional in that world rather
than consequences of M-3, and the flag's price in A-17 is understated by
everything except its largest collision term).
**The position map: COMPLETE** — I enumerated every generator consumption on
the block, boundary, endpoint, seam and run paths at `8c5922b` and found no
twelfth draw, no draw inside a parallel region, and no draw behind a witness,
challenge, refusal, feature or environment branch; what is *incomplete* is the
owed test the memo specifies from it (§3.1's five assertions are all about
positions and cannot exclude the counterexample they are introduced to
exclude), and the run's schedule is `11L + 3(L−1)` segments, not "the eleven".
**Part B's completeness: INCOMPLETE** — a 25th and 26th call kind (two
hand-written BLAKE3 kernels in CUDA) are reached on the production path at
exactly the two LEGACY profiles whose whole separation argument is "there is
one unkeyed function"; six further in-process hash sites appear in neither the
24 nor the "off-path, checked clean" list; one within-family length clash is
missing; one cross-family row is not reachable within one execution; the toy's
clash count is three, not four.

Checked by an independent adversarial agent for the security owner.
2026-09-21, 03:15 PDT (`date` read at 02:58 and 03:15 on the WSL box).
Code read-only at lane commit `8c5922b`; nothing compiled, no test run, no
git write. Evidence: `results/zk60_joint_sentence_query_classes_check/`
(`recheck.py`, `recheck.out`, `README.md`) — one script, exact integers,
importing nothing from the memo's four.

**This establishes no privacy property of anything.** D22 is untouched.

---

## 0. What reproduced, before anything is attacked

The memo's arithmetic is good. I rebuilt it from the code without looking at
its scripts, and every number of Part A came back:

| memo claim | my figure | verdict |
|---|---|---|
| A-12 `p − r = 2^32` exactly | `4294967296` | reproduces |
| A-12 `TV = 2^-96.0000000003` | `2^-96.0000000003` | reproduces |
| A-12 `Pr[rej] = 2^-64.0000000007` | `2^-64.0000000007` | reproduces |
| A-14 the two forms differ by 32.0 bits | `32.000000` | reproduces |
| A-13 `r/N` is optimal for an exactly-uniform good event | brute-forced on six `(p,N)` | reproduces, and the counter-instance `p=5,N=16` is real |
| A-5 toy / rung / rung-G / rung-K4 / 125M `fp()` draws | 320,908 / 687,028 / 687,028 / 750,540 / 9,029,804 | all five reproduce from `Shape`+`Layout` constants |
| A-5 toy proof total = D9's 327,052 | 320,908 + 2 × 3,072 | reproduces |
| A-7 125M run `L=12`: 109,546,000 fp, 2,342,912 salts, 1,827,709,184 B | identical | reproduces |
| A-7 total with endpoints = H-6's 109,728,784 | identical | reproduces |
| A-7 rung-G `L=3` 2,093,340; rung-K4 `L=3` 2,283,876 | identical | reproduce |
| A-11 `C(47,2) = 1,081` | 1,081 | reproduces |
| A-18 / A-19 both counterexamples | reimplemented from scratch mod 101, six seeds | reproduce |
| A-19 accidental coincidence `p^-256 = 2^-16384` | `2^-16384.0` | reproduces |

Three code facts the brief asked to be settled, settled:

* **No generator draw is inside a parallel region.** Every draw is a
  sequential `for`/`map` over a range — `fp_vec` (`rng.rs:85-87`), the salt
  comprehensions (`pcs.rs:725, :778`, `zk.rs:462, :513`), the mask-row loops
  (`protocol.rs:655-657, :757-768`, `boundary.rs:324-326`,
  `endpoint_g.rs:231-233`, `private_seam.rs:211-213`). Rayon appears only
  *after* the draws, over the already-filled `pads`/`salts` buffers, indexed
  by position (`pcs.rs:733, :740, :790, :797`, `zk.rs:464, :515`,
  `merkle.rs:42, :59`). The thread schedule cannot move a byte.
* **No draw is behind a witness, challenge, refusal, feature or environment
  branch.** `pos` is a function of `(shape, stage index)` and of nothing else
  — not even of the public statement.
* **Eleven is the right count for a block body**, and `argument()`,
  `zk::mask_open` and `pcs::open_zk` draw nothing.

## 1. Verdict table

| # | what the memo says | verdict |
|---|---|---|
| A-1 … A-5 | the stream is byte-addressed at `8i`, `fp()` is a 16-byte reduction, eleven segments with these counts | **CORRECT**, reproduced |
| A-6 | four `from_os` sites; three generators at a block, three in a run | **CORRECT** as a count; see B-10 on what their independence rests on |
| A-7 | the run totals | **CORRECT**, reproduced |
| A-8 | `pos` is a function of the shape alone | **CORRECT, and understated** — it is also independent of the public statement |
| A-9 | what rejection sampling would have cost | **CORRECT** |
| A-10 | clause (a) is immediate given M-3 | **WRONG PLACE** — see B-1a. In the world (JS) is stated in, (a) is part of the definition of the world; its content belongs to the hop |
| A-12 … A-14 | the sampler arithmetic and the distance hop | **ARITHMETIC CORRECT; the hop's justification is defective** — see B-1 |
| A-15 | clause (b), the published salts | **CORRECT**, riders included, rider 1 still unpinned |
| A-16 | clause (c), Lemma H's kernel | **MIS-TRANSCRIBED** — drops `+ ε_gen(q)` from Lemma H's own bound |
| A-16 / (c′) | clause (c′) is new and is the half Lemma H owes | **NOT NEW, NOT OWED, NOT CIRCULAR** — see B-5 |
| A-17 | the flag is `B_salt ∪ B_logup`, `B_salt` priced at 2^-229.8 | **UNDER-PRICED** — see B-2 |
| A-18, A-19 | the two counterexamples | **CORRECT**, reproduced |
| §3.1 | the five assertions the owed test must make | **INSUFFICIENT** — see B-4 |
| A-20, A-21 | what changes at a shaped block and in a run | **CORRECT**; `with_io_mask_rows` really does leave `a_rows`/`h_rows` alone (`layout.rs:1151-1154`) |
| B-1 | 24 call kinds | **INCOMPLETE** — see B-3 and B-17 |
| B-2 | the toy's four legacy clashes | **THREE**, not four — see B-9 |
| B-3 / B-4 | the tagged families and the cross-family coincidences | **one row not reachable in one execution; one within-family clash missing** — B-7, B-9 |
| B-5 | every absorbed word is public, and it is pinned | **CORRECT** and the best-supported claim on the page |
| B-6 / (iii-a′) | the prover queries the transcript class; the restated hypothesis | **CORRECT finding; the repair is right for (iii) and silent on causality** — see B-11 |
| B-7 | leaf vs node is the only pair separated by nothing | **CORRECT** at the profile level |
| B-8 | the 151-byte `pb-term`(6) pair, `[UNVERIFIED]` | **VERIFIED — the six-terminal absorb exists at every shape** (slot 19 = `SC_TAB`). See B-6 |
| B-9 | `rows = 16` → 128 B, "dangerous at every shape" | **half right** — see B-9 |
| B-10 … B-12 | the pin table, the work list, the models | **CORRECT**; W-6 can now be closed as a reading (B-6) and two items should be added (B-4) |

---

## 2. Findings, most serious first

### B-1 — the distance hop's justification is defective: `O` is **not** independent of `ω`, and it is **two** hops, not one

**The memo's text.** §2.0: *"the whole experiment is a deterministic function
of `(ω, O)`, so replacing the real `ω` by the ideal one moves the view by at
most `N · 2^-96`"*, and A-14: *"the whole experiment — prover, challenge
oracle, distinguisher — is one deterministic function of `(ω, O)`, and `O` is
independent of `ω`; so by data processing the view moves by at most
`TV(ω_real, ω_ideal)` whatever the challenge schedule does."*

**My evidence.** `ω` **is a function of `O`**. The generator's refill
(`zkp-core/src/rng.rs:53-61`) is

```rust
let mut h = blake3::Hasher::new();          // UNKEYED, at every profile
h.update(&self.key); h.update(&self.counter.to_le_bytes());
let mut out = h.finalize_xof(); out.fill(&mut self.buf);
```

so the prover's whole randomness stream is `O(key‖0) ‖ O(key‖1) ‖ …`, where
`O` is the *same* unkeyed oracle the distinguisher queries — the memo's own
claim B-3 says so in as many words (`F_U`, *"still unkeyed, carrying **R2 the
refill** and every statement digest D1–D8"*). At the two legacy profiles it is
additionally the same function as every leaf, node and column digest. An
oracle-querying distinguisher therefore has, in principle, access to the very
points that produced `ω`; the only thing standing between it and the stream is
that `key` is secret. So "`O` is independent of `ω`" is **false as a fact
about the experiment** and is instead **the content of the M-3 hop**
(ruling C-3; priced in the accepted toy statement as *"the named assumption;
inside the model alternatively `6q·2^-256`, labelled ASSUMED"*).

**Consequence.** The real prover is reached by **two** steps in a fixed order,
not "one distance hop":

1. **M-3 / `ε_gen(q)`**: replace `O(key‖·)` by an independent uniform byte
   string. Only after this is `ω` a product measure independent of `O`.
2. **the sampler**: replace the reductions of that uniform string by exactly
   uniform `Fp` elements — `N·2^-96`, D9's 2^-77.68 / 2^-69.29, which my §1
   reproduces.

A-14's data-processing argument is valid **only inside step 2's world**. As
written it is applied to the real world, where its hypothesis fails.

**Smallest repair.** One clause in §2.0's box and one in A-14: *"in the
post-M-3 world the generator's output is an independent uniform string; the
sampler hop is taken there, and `O ⟂ ω` is a consequence of the first hop, not
a fact about the code."* Then say "two hops" and carry `ε_gen(q)` beside
`N·2^-96` (it is in the accepted statement's table already; the memo's §2.0
box lists only the sampler).

**B-1a, the same defect seen from clause (a).** §2.0 defines the world as
*"every `fp()` value a uniform element of `Fp`, every `bytes32()` value a
uniform 256-bit string, **all mutually independent**"*. In that world clause
(a) — the salt segments independent of the blinding segments — is part of the
definition, not a theorem. A-10's table (*"the stream is uniform: ASSUMED —
M-3, and nothing else"*) therefore books M-3 twice: once for the hop and once
inside a sentence stated after it. The position map's real job is not to make
(a) true; it is to make the ideal `ω` a **well-defined product measure over
the same index set** so that "replace `ω_real` by `ω_ideal`" is a map at all —
which is exactly what A-14's last sentence says and what A-10's table does
not. Repair: state (JS) in the post-M-3, post-sampler world, say that (a) and
(c′) hold there by construction, and move the position map's load into the
hop, where it belongs.

**B-1b, the conditioning.** (JS) is stated conditioned on `NR(ρ)`. The hop is
taken unconditioned. Total variation does not survive conditioning for free:
`TV(P|A, Q|A) ≤ TV(P,Q)/Pr[A]`. With `Pr[refuse] ≤ 2^-112` the inflation is
under one bit and nothing moves, but the step is not in the page. One
sentence.

### B-2 — A-17 under-prices the flag: `B_salt` is not 2^-229.8

**The memo's text.** A-16 gives `Pr[B_salt] ≤ q·N_leaf·2^-256 +
C(N_leaf,2)·2^-256 + N_overlap·2^-256 + N_node·N_leaf·2^-512`. A-17's table
then prices the same event at **`2^-229.8` (toy)**.

**My evidence** (`recheck.py` §4, exact):

```
C(12288,2) · 2^-256          = 2^-229.8302     <- the only term A-17 carries
N_overlap (24,571) · 2^-256  = 2^-241.4153
N_node·N_leaf · 2^-512       = 2^-484.8307
q · 12288 · 2^-256           = q · 2^-242.4150 <- DROPPED
```

`q·2^-242.415` overtakes `2^-229.830` at **`q = 6,144 = 2^12.58`**. For any
adversary making more than about four thousand oracle queries the dropped term
is the *dominant* one. Two further checks against the sources:

* Lemma H's own bound (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.2) ends
  `+ ε_gen(q)`. **A-16 drops that too** — which is the one term Part A is
  about (see B-1).
* the accepted toy statement
  (`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md:119-122`) carries **three** oracle-
  collision figures, `2^-229.8; 2^-233.1; 2^-241.4`, plus `q·2^-242.4` on its
  own row. **`2^-233.1` appears nowhere in the memo**, neither in A-16's
  four-term formula nor in A-17's table; it is the absorb-input collision
  term, `2^-233.07` at `ZK60_HASH_LAYER_AND_FS_LIFT.md:1333`.

**Smallest repair.** A-17's price column for `B_salt` becomes
`q·2^-242.42 + 2^-229.83 + 2^-233.07 + 2^-241.42 + 2^-484.83 + ε_gen(q)`, and
A-16's formula gains the absorb-input term and `ε_gen(q)`. Nothing accepted
moves — the statement of record already carries all of them — but the memo as
it stands would let a reader quote a flag probability 30+ bits too small.

This is precisely the failure mode the brief names: a figure carried from one
document into another in a form it does not have there. `2^-229.8` is the
*largest collision term of a five-term event*, not the event.

### B-3 — Part B is incomplete: a 25th and 26th call kind, live at exactly the legacy profiles

**The memo's text.** *"the CUDA column kernel (`gpu/kernels.cu:447-600`) is a
hand-written unkeyed BLAKE3, feature-gated and declined by tagged commitments
(`pcs.rs:782-785`, ruling T-8)"* — listed under **"Not on the path, checked
clean"**.

**My evidence.** Both halves of that sentence are true and together they are
misleading. `commit_zk_owned_with_tag` (`zkp-core/src/pcs.rs:782-785`) reads

```rust
let dev = match tag.column_key() { None => backend.try_commit_zk(...), Some(_) => None };
```

`column_key()` is `None` exactly when `hashes_under_the_legacy_rule()`
(`shape.rs:549-551`: the frozen toy, and the frozen-seam rung). So the device
**is** offered the column hashing for `A` (`protocol.rs:662`), `H`
(`protocol.rs:770`) and every endpoint/boundary at precisely the two profiles
where the whole domain-separation argument is *"there is one unkeyed
function"*. `private_seam::prepare` goes through `commit_zk_owned` →
`commit_zk_owned_with` (`pcs.rs:728`), which has **no tag gate at all**.
There are moreover **two** independent kernels, not one:

| file:line | what | reached from |
|---|---|---|
| `hashline/src/gpu/kernels.cu:512, :582` | `b3_hash_column` / `k_hash_cols` | `cuda.rs:2741` (`dev_commit_from`), `cuda.rs:3597` (`dev_commit_zk_from`) |
| `hashline/src/gpu/kernels.cu:1429` | `k_hash_cols_stream` — a *second* hand-written BLAKE3, chunk-streamed with a per-column CV stack | `cuda.rs:1741` (`commit_zk_chunked`), `:2154`, `:2242` |

Neither is in the memo's table. Both are gated by `--features gpu-cuda` (off
by default, `hashline/Cargo.toml:21-24`) **and** `HL_GPU=1` at runtime —
`hashline/src/pcs.rs:61, :74` call `&backend()`, which reads the environment.

**Why it matters for this page and not only for the build.** Part B's claim is
an enumeration of the oracle points the system queries. A second
implementation of the same function is not a new oracle point **when it
agrees**; it is one when it does not. Under `HL_GPU=1` at the toy, the column
digests of `A`, `H` and both endpoints are produced by hand-written CUDA, and
what pins the agreement is a differential probe (`cuda.rs:2795`,
`dev_hash_cols_check`) and the `PROOF sha256` parity gate — not a hash-domain
argument. The honest row is *"reachable at the two legacy profiles under a
build flag and an environment variable; agreement with `pcs.rs:171` is pinned
by a parity gate, not by the domain argument"*, and it belongs in the table,
not in the clean list.

**Smallest repair.** Move the CUDA row out of "checked clean", split it in
two, and correct A-4's parenthetical (*"drawn before the accelerator is
offered … so neither the GPU path nor the hash tag moves a byte"* is right
about the draws and should not be read as "the accelerator is never reached").

### B-4 — the owed draw-accounting test cannot exclude the counterexample it is introduced to exclude

**The memo's text.** §3.1 lists the five assertions ruling R-3's test must
make, and A-19 concludes *"the part of (JS) that excludes ruling R-3's
counterexample is the witness-independence AND injectivity of the position
map"*. Two paragraphs earlier the same section says *"the gate is a statement
about which symbol each site uses and the leak is a statement about the
values"*.

**My evidence.** All five assertions are statements about **which symbol each
site uses**. Assertions 1–4 are byte offsets and ranges; assertion 5 is
"no clone, one construction". Two defects keep every position disjoint,
witness-independent and correctly offset, pass all five, and still correlate
the realised values:

* **(d1) — it is in the code today.** `zk.rs:503-506`:
  ```rust
  let mut b_re = rng.fp_vec(2 * m);      // 1024 draws, positions disjoint
  let mut b_im = rng.fp_vec(2 * m);
  b_re[m] = b_re[0].neg();               // the drawn word at position m is DISCARDED
  b_im[m] = b_im[0].neg();
  ```
  The memo's A-3 calls this *"an overwrite, not a re-draw"* and moves on. For
  positions that is right. For clause (a) the object that matters is the map
  from consumed stream words to committed blinding values, and that map is
  **not injective**: two committed entries carry a deterministic linear
  relation and two drawn words are thrown away. It is declared and the CFS
  argument models it — which is exactly why a test must assert that the
  declared set is the whole set.
* **(d2) — one line away.** `ZkRng::new(seed, domain)` (`rng.rs:20`) is a
  deterministic fixture generator, reachable through `ZkConfig::rng`
  (`zk.rs:334-340`) whenever `ZkConfig.seed` is `Some`. Today the private
  block calls `from_os` directly, so it is not on the path — but a generator
  seeded deterministically is **one**, is never cloned, has perfect offsets
  and passes assertions 1–5 while making every proof of every witness
  identical. Nothing in the five assertions looks at where the key came from.

**Smallest repair — two more assertions:**

> **6. The realised value map.** Enumerate every deterministic relation the
> prover imposes on drawn values after drawing them — today exactly
> `b_re[m] = −b_re[0]`, `b_im[m] = −b_im[0]` (`zk.rs:505-506`) and the
> computed last entry of each `H` zero-sum row (`protocol.rs:767`, which is
> *not* an overwrite: that position is never drawn) — and assert that set is
> exactly the declared one, so that a reused buffer or a repeated slice is a
> failure and not a silence.
>
> **7. The key is fresh.** Assert that every generator on a production path
> is built by `from_os` from its own `/dev/urandom` read, and that
> `ZkRng::new` is unreachable from `prove_inner_at`, `prove_run`,
> `endpoint_g::prepare`, `boundary::prepare` and `private_seam::prepare`.

Assertion 2 also needs widening: the memo says *"each of the **eleven**
segments of §1.2"*, and a run's schedule is `11L + 3(L−1)` segments (eleven
per block body, three per boundary), interleaved as
`[boundary_k if k+1<L] then [block_k]` (`run.rs:498-523`). The stage offset
the memo gives, `k·block + min(k, L−1)·boundary`, is the offset of the
**stage**; the offset of stage `k`'s *block body* is
`k·block + min(k+1, L−1)·boundary`.

### B-5 — clause (c′) is not new, is not owed by Lemma H, and is not circular

The brief asks whether (c′) is new, covered, or circular. It is **covered**,
and the memo's own construction is what covers it.

* **Not circular.** Lemma H is stated in the fixed-challenge experiment and
  says so at length: *"In that experiment `ρ` is exogenous, so conditioning on
  it assumes nothing about the roots, which are outputs. The real protocol,
  where `ρ` is a hash of the roots, is §3"*
  (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.1). (JS) is stated in the same
  experiment and the memo's A-15 rider 2 says the same thing. So the loop the
  brief points at — *conditioning on `ρ` is conditioning on oracle outputs at
  points that include the root* — is not entered here. It is entered in the
  Fiat–Shamir lift, §3 of that memo, which this page explicitly does not
  touch, and which already owes it.
* **Not new.** Lemma H's conditional statement already conditions on
  `S_pub = s`: *"law( (u_{r,k}) | V = v, **S_pub = s**, ρ, NR, w, the unopened
  columns themselves, and the adversary's q oracle answers ) =
  Unif({0,1}^256)^{⊗m}"*. And in the world (JS) is stated in — every
  `bytes32()` uniform and **mutually independent** (§2.0) — the unopened
  salts are uniform given the opened ones by the definition of the world, in
  one line, not by "M-3 again".
* **What it really names.** The residual is that the salts come from the
  generator, so "uniform and mutually independent" is bought by the M-3 hop.
  That price is already in Lemma H's bound as `+ ε_gen(q)` — the term A-16
  drops (B-2). So (c′) adds a useful *documentation* sentence (where in the
  code the salts come from, and that the opened/unopened split lives inside
  one segment) and **no new mathematical obligation, and no second use of
  M-3**.

**Smallest repair.** Keep (c′) as a remark; close **GAP-JS-2** as
"documentation, discharged by the M-3 hop and already priced as `ε_gen(q)` in
Lemma H"; and stop describing it as *"the half ruling K-R3 says the hash-layer
lemma owes"*. What K-R3 actually owes is the joint sentence, and the honest
answer to it is B-1's two-hop ordering, not a new clause.

### B-6 — B-8's `[UNVERIFIED]` is now VERIFIED: a six-terminal `pb-term` absorb exists at every shape

`Shape::slot_terms()` (`shape.rs:742`) is `a_sites[s] + h_sites[s] +
(s ≥ SC_IO_IN)`. At slot **19 = `SC_TAB`**, `a[SC_TAB] = 3` and
`h[SC_TAB] = 3` (`shape.rs:704-739`), and `19 < SC_IO_IN = 21`, so
`slot_terms[19] = 6` at **every** shape [COUNTED]. The absorb's input is
therefore `48 + 7 + 96 = 151` bytes, and it is issued once per proof.

The distinct terminal counts, per shape [COMPUTED]:

| shape | `slot_terms` distinct | `pb-term` absorb lengths |
|---|---|---|
| toy | 1,2,3,**6**,13,15,17,21,22,56 | 71, 87, 103, **151**, 263, 295, 327, 391, 407, 951 |
| rung / rung-G / rung-K4 | 1,2,3,**6**,13,15,17,22,24,56 | 71, 87, 103, **151**, 263, 295, 327, 407, 439, 951 |
| 125M | 1,2,3,**6**,13,15,17,22,24,54 | 71, 87, 103, **151**, 263, 295, 327, 407, 439, 919 |

So **W-6 can be closed as a reading now** (it remains worth a test), and B-8's
length is real. What B-8 gets right and should say more plainly: the pair is
**never live inside one profile**. A legacy profile has no internal boundary,
so `D7` does not exist there; a tagged profile puts the absorb in `F_T` and
the digest in `F_U`. The only reading under which the pair exists is one
global `F_U` across profiles on one machine, at `2^-256` per absorb. **Record;
do not guard.** The memo's `55 + 16k ≡ 7 (mod 16)` argument reproduces: no
`pb-term` absorb can ever equal a column digest, at any shape [PROVED].

### B-7 — a within-family length clash the memo's table misses: 295 bytes in a rung-G / rung-K4 run

[COMPUTED, `recheck.py` §5.] At a **rung-G** or **rung-K4** run with
`2 ≤ L ≤ 9` the run's `parameters` line is 237 bytes (`run.rs:234-246`), so
its absorb is `48 + 10 + 237 = 295`; and `pb-term` with 15 terminals is
`48 + 7 + 240 = 295`. **Both are `F_T` queries — the same keyed function, the
same length, in the same execution.** rung-G `L=3` is the configuration the
lane runs.

They are separated the way the 81-byte root absorbs are: by the label literal
and its length prefix at a fixed offset (`le64(10)‖"parameters"` against
`le64(7)‖"pb-term"`), so the separation is deterministic, not probabilistic,
and nothing is broken. But it is a clash of the class §6.2's table is supposed
to enumerate and it is not there. (`L=1` gives 294, `L ≥ 10` gives 296; at the
125M run the `parameters` absorb is 300/301/302 and misses every `pb-term`.)

### B-8 — the stated mechanism for `2^-241.42` does not produce `2^-241.42`

**The memo's text** (§6.1, §6.2a): *"the absorb carries `le64(8) ‖ "log-cols"
‖ le64(8)` at a fixed offset, so a coincidence needs a digest to spell 24
fixed bytes — **2^-241.42** as counted"*.

24 fixed bytes is `2^-192` per pair, not `2^-241.42`. The figure of record
comes from somewhere else: `ZK60_HASH_LAYER_AND_FS_LIFT_CHECK.md:77, :309`
gives `24,571 × 2^-256 = 2^-241.4153`, i.e. **the 32-byte salt of each of the
24,571 salted-leaf and inner-node objects is uniform**, and the bound counts
one `2^-256` per object. My §4 reproduces both numbers. The figure is right;
the one-line justification beside it is a different (and weaker) argument.
One-clause repair.

### B-9 — three smaller Part B corrections

1. **The toy has three legacy clashes, not four.** My enumeration of the toy's
   unkeyed set finds 64 (`log-cols` / salted leaf / Merkle node), 81 (the four
   root absorbs) and 171 (`expected-IO` / `parameters`). **151 has no partner
   at the toy**: the internal boundary spec digest exists only in a run and
   runs are tagged. The memo's own §7 says this in prose and its §6.1 table
   counts it anyway.
2. **The 68-byte cross-family row is not reachable within one execution.**
   §6.2 pairs `absorb "pb-run-stage"` (68) with *"R1 seed derivation at the
   rung-G block prover"* (`22 + 46 = 68`). But `pb-run-stage` is absorbed only
   in a run (`run.rs:494`), and in a run the block prover makes **no**
   generator — `prove_run` makes one for the whole run (`run.rs:475`) under
   the **run** profile, 44 bytes, giving 66. At rung-K4 the run seed is 67
   against the same 68. So the row is cross-execution, like 151, and should
   carry the same caveat.
3. **`rows = 16` is not "dangerous at every shape".** 128 bytes is the
   **frozen-seam** spec digest (`private_seam.rs:116`), and the frozen seam
   exists only at the two legacy profiles, whose geometries are frozen; at a
   tagged profile a column digest is `F_C` and the digest `F_U`, so the length
   means nothing — as the memo's own §6.2a row says. The correct statement is
   *"dangerous at a legacy profile, which today means a frozen geometry"*.
   W-4 remains right and costs nothing; it is a hygiene item, not a hazard.

### B-10 — the three generators' independence is not information-theoretic

**The memo's text** (A-6, repeated in A-11 and in `stream_positions.out`):
*"each from its own 32-byte `/dev/urandom` read (`rng.rs:45-46`). Their mutual
independence is **information-theoretic**, not an M-3 consequence."*

`/dev/urandom` is the kernel's CSPRNG. Two 32-byte reads from it are
*computationally* indistinguishable from independent uniform, not
information-theoretically independent: the pool is a finite-state generator
and the two reads are a deterministic function of one state. The honest
statement is that the three generators are independent **under a second
assumption about the OS source**, of the same computational kind as M-3 and
not implied by it.

Why it matters beyond wording: A-11's headline — *"three pairs rest on M-3 and
the rest are information-theoretic"* at a block, *"1,081 pairs"* in a run — is
read as "the rest are free". They are not free; they rest on a different
assumption. The count is right, the characterisation is not. One-clause
repair, and a new named assumption (say **E-1**, the OS-entropy assumption) so
the register can carry it.

### B-11 — (iii-a′) repairs the independence hypothesis but is silent on causality

**The memo's text** (§6.3): *"Neither is a leak, and neither breaks the
hypothesis — but the hypothesis has to be restated to be true: **(iii-a′)**
every transcript-class query the prover makes is at a point determined by the
public prefix."*

**On the finding itself: correct, and confirmed in the code.**
`check_opening` (`protocol.rs:305-306`) clones the transcript and draws
`Σ counts + rows` challenges through `check_opening_challenges`
(`:282-293`); `pcs::open_zk` (`zkp-core/src/pcs.rs:1023-1027`) then calls
`zk_rhos` on the **live** transcript with no absorb in between, drawing
`Σ members.len()` lambdas per group and then `rows` for `prox_rho` — the same
count, in the same order, at the same `(state, counter)` pairs. They are
literally the same oracle points. Confirmed.

**Is (iii-a′) enough?** For hypothesis (iii) — *the challenge source is
independent of the prover's internal randomness and of the witness* — yes:
`ξ = O|_T` is exogenous whether or not the prover reads it, and reading it at
prefix-determined points cannot make `ξ` depend on `ω` or on `w`. The proof
goes through unchanged.

**For causality it is not enough, and the memo should say so.** The lemma's
causality hypothesis is that message `j` is a function of `ρ_{<j}`. The
replay squeezes `ρ_j` **before** the prover commits to message `j`, and then
*decides whether message `j` exists at all*. That is a dependence of the
prover's behaviour on `ρ_j`. It is already handled — the refusals in
`check_opening_challenges` are challenge-driven, so at fixed `ρ` the decision
is a deterministic function of public data, and under D21/M-9's
accepted-receipts game a refused attempt is outside the probability space —
but that is an argument the page owes, not a consequence of (iii-a′).

Two small things in the same area, in the memo's favour:

* the **position tag** is safe for a reason the memo does not give: the live
  chain's next operation after `start_tag` is an *absorb*
  (`run.rs:492-494`), so the tag's two squeeze points are never queried live.
  `end_tag(k)` and `start_tag(k+1)` are, however, the identical pair of oracle
  points, published twice (`run.rs:551` then `:492`).
* `check_opening_challenges` short-circuits (`.any()`), so on the *refusal*
  branch it draws fewer than `Σ counts + rows` — irrelevant to an accepted
  receipt, but it means the replay's query count is not a shape constant off
  the accepted path.

### B-12 … B-17 — smaller matters, one line each

* **B-12.** A-4: *"drawn before the accelerator is offered … so neither the
  GPU path nor the hash tag moves a byte"* is correct about the draws; the
  clause *"declined by tagged commitments"* elsewhere should not be read as
  "the accelerator is never reached" (B-3). `hashline/src/pcs.rs:61, :74` pass
  `&backend()`, which reads `HL_GPU` — an environment branch on the
  production path that changes the *store* and the *hasher implementation*,
  never a draw.
* **B-13.** A-16 drops `+ ε_gen(q)` from Lemma H's stated bound. See B-2.
* **B-14.** Seven of the memo's literal citations are one line early: they
  land on `blake3::Hasher::new()` and the literal is the next line
  (`private_block.rs:513`→`:514`, `run.rs:221`→`:222`, `:286`→`:287`,
  `layout.rs:1289`→`:1290`, `boundary.rs:211`→`:212`,
  `endpoint_g.rs:158`→`:159`, `private_seam.rs:116`→`:117`). The boundary
  `DOMAIN` is at `boundary.rs:58`. There is no `run_parameter_line` symbol;
  it is `RunStatement::parameter_line` at `run.rs:234-246`. Every *length* the
  memo derives from these is nonetheless correct — I recomputed 128 / 142 /
  151 / 30 / 31 / 33 / 29 / 31 from the field lists and all eight agree.
* **B-15.** The memo lists one 1-byte margin (ruling H-8's, the 125M run
  profile's 46-byte constructor against the 47-byte squeeze — reproduced).
  There are more, at every profile: `pb-slot` 63 vs `log-cols` 64 everywhere;
  `pb-term(1)` 71 vs the rung-G/K4 endpoint column 72; `pb-term(2)` 87 vs
  `schedule` 88; `pb-term(6)` **151** vs `sc-round(degree 5)` **152**; the
  toy's seam seed derivation 50 vs its constructor 51. None is a clash. The
  point is that a "one byte away" observation is not rare here, so H-8's
  margin should be defended as a *class* of test (W-2 generalised: no two
  input kinds within one byte, per profile, printed) rather than as one line.
* **B-16.** §9: *"D2 (attacker-chosen weights) … is the only `F_U` input whose
  length an adversary moves"*. The adversary chooses the weight **values**;
  the serialisation is `u64` length-framed per tensor with shapes fixed by the
  `Shape` (`private_block.rs:393, :473`), so its **length** is shape-
  determined like everything else. Unless `BlockPublic` has a variable-length
  field I did not find, no adversary moves any `F_U` length. Recheck or
  withdraw the sentence.
* **B-17.** Six further hash sites are reachable **in the same process** from
  the named entry points and appear in neither the 24 nor the "off-path,
  checked clean" list: `private_block_contract.rs:545` (unkeyed, a large
  framed registration buffer), `causal_oracle.rs:98` (unkeyed, a 37-byte
  literal), `causal_oracle.rs:194` (unkeyed — the *identical* 30-byte preimage
  as `D1`, at a second site), `causal_oracle.rs:590` (a second call site of
  `hash_columns` + `hash_pair`), and three **SHA-256** table-spec digests at
  `zkp-core/src/tables.rs:134`, `tables_attn.rs:125` and `:166`. They are
  reached through `BlockPublic::synthetic_fixture()` (`private_block.rs:521`),
  which is **not** `#[cfg(test)]`. Nothing they produce is absorbed, so they
  are not in the receipt's hash view — but the memo's cross-profile `F_U`
  argument (§7) is a statement about *one machine*, and under that reading the
  set is not closed. Either add them or narrow the `F_U` argument to "one
  proof".

---

## 3. What the counterexamples showed on re-implementation

Reimplemented from scratch mod 101, six seeds each, no code shared with the
memo's script (`recheck.py` §7):

* **(i) a shared blinding row.** Independent rows: disclosed dimension 0.
  One shared row: disclosed dimension 3 while each site's marginal is still
  perfectly blinded, and `V_0 − V_1 = (M_0 − M_1)·w` separates two witnesses
  on all six seeds. Reproduces.
* **(ii) ruling R-3's variant.** Two distinct rows at disjoint positions whose
  values coincide: the rank gate reports disclosed 0 — the honest answer —
  and the realised view determines `(M_0 − M_1)·w` exactly, on all six seeds.
  Reproduces.
* the accidental rate at the real geometry is `p^-256 = 2^-16384`;
  a broken draw discipline has probability one. Reproduces.

The memo's reading of what excludes each is right. What it then specifies as
the test is not sufficient — B-4.

## 4. The position map, as I enumerated it

Every generator consumption reachable from `prove_inner_at`, `prove_run`,
`endpoint_g::prepare`, `boundary::prepare` and `private_seam::prepare`, at
`8c5922b`:

| role | site | draws | shape-determined? | branch? |
|---|---|---|---|---|
| block, `A` mask+prox rows | `protocol.rs:655-657` | `(a_rows − a_mask_base)·n` | yes | none |
| block, `A` pads then salts | `zkp-core/pcs.rs:777-778` | `a_rows·Q` fp, `nn` salts | yes | drawn **before** the backend offer at `:782` |
| `M` CFS coefficients | `zk.rs:485` → `sumcheck.rs:201` | `2·Σ (n_s·d_s + 2)` | yes | none |
| `M` per-row pads | `zk.rs:496` | `2·N_SLOTS·MASK_Q` | yes | none |
| `M` `b_re,b_im,u_re,u_im` | `zk.rs:503-508` | `4·2·MASK_M` | yes | two words overwritten, not re-drawn |
| `M` salts | `zk.rs:513` | `MASK_DOM` | yes | none |
| block, `H` mask+prox rows | `protocol.rs:757-759` | `(h_rows − h_mask_base)·n` | yes | none |
| block, `H` zero-sum rows | `protocol.rs:760-768` | `2(n−1)` | yes | last entry computed, never drawn |
| block, `H` pads then salts | `zkp-core/pcs.rs:777-778` | `h_rows·Q` fp, `nn` salts | yes | as above |
| boundary (caller's stream) | `boundary.rs:324-328` | `6·n` fp + `(e_rows+1)·Q` fp + `nn_e` salts | yes | none |
| generalised endpoint (own stream) | `endpoint_g.rs:224-235` | `5·n_e` fp + `e_rows·Q` fp + `nn_e` salts | yes | none |
| frozen-seam endpoint (own stream) | `private_seam.rs:196-215` | `5·256` fp + `e_rows·256` fp + `2048` salts | yes | none |

Nothing else draws. `argument()` (`protocol.rs:782`), `zk::mask_open`
(`:790`), `pcs::open_zk`, `check_opening`, `check_endpoint_opening`,
`PreparedBoundary::into_opening` (`boundary.rs:269-275`), `position_tag`
(`run.rs:404-411`) and `wire::encode_segment` take no generator. The only
witness-sensitive control flow inside the draw window is the total abort at
`inverses()` (`protocol.rs:402-405`, called at `:691, :702, :704, :734`), and
it sits between segment 7 and segment 8 exactly as A-3 says. `private_seam.rs`
has a **fourth** `from_os` at `:349` — it belongs to the seam's own proof
(`private_seam::prove`), not to the private-block path, and the memo is right
to leave it out.

## 5. What I could not check

* **`D2`, `D3` and `D5`'s input lengths** (`31 + w`, `33 + Σ`, `31 + Σ`). I
  did not enumerate the weight serialisation or the `describe()` line set, so
  those three lengths are missing from my sets as they are from the memo's. A
  clash between a statement digest and an absorb at a legacy profile would
  live here and neither of us would have seen it. This is the largest hole in
  Part B's length argument and it is **not** among the memo's named gaps.
* **Whether the refusal classes really read no salt** (A-15 rider 1). I read
  `check_opening_challenges`, `audit_claims` and `argument.rs:332-334,
  :404-406, :765-768` and saw no salt; `audit_claims` does read
  `part.coef.is_zero()`, which is a masked coefficient, and whether that is
  challenge-driven or witness-driven I took from the memo rather than
  establishing. It is the one refusal I would look at again.
* **`ε_gen(q)`'s size.** I record that A-16 drops it; I did not re-derive the
  accepted statement's `6q·2^-256` alternative.
* **Whether any deployment builds `--features gpu-cuda`.** B-3's exposure is
  conditional on a build flag I cannot observe from the source.
* **Lemma H itself**, Theorem 3.3, Route A, the Fiat–Shamir lift and the
  soundness rows. Out of scope, as they were for the memo.
* Nothing here was compiled or run in Rust.

## 6. What the security owner must rule on — one thing

**The hop order and the hop count.** Everything else in this check is a
correction, a missing row or a wider test. B-1 is the one place where an
argument of record does not hold as written: A-14 asserts `O ⟂ ω` as a fact,
and it is false — the generator's refill is an *unkeyed* BLAKE3 query
(`rng.rs:54`), a member of the same `F_U` the distinguisher queries and, at
the two legacy profiles, the same function as every leaf, node and column
digest. The independence is the **content of the M-3 hop**, not a premise of
it. Rule that (JS) is stated in the post-M-3, post-sampler world, that the
real prover is reached by **two** steps in that order with `ε_gen(q)` beside
`N·2^-96`, and that clause (a) and clause (c′) hold in that world by
construction while the position map's load moves into the first hop. Then
K-R3's owed sentence is delivered and A-17's flag can be re-priced (B-2) on a
stable footing.
