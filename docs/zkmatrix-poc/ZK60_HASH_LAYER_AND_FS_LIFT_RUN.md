# The hash layer and the Fiat–Shamir lift for a multi-block RUN (gap G-R5)

**Drafted by a delegated Opus agent for the security owner.**

> **REVISED after an independent check and the security owner's disposition,
> 2026-09-21 01:13 PDT: not a privacy claim; the conditional statement HOLDS
> WITH CHANGES; condition C-R3 is a fact of the code for an accepted run
> (H-1); the model of D19a is restated as an ideal compression function and is
> PROPOSED to the project owner as D19b (H-4).**
>
> The two inputs to this revision are
> `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_CHECK.md` (an independent agent told to
> assume this page wrong: findings B-1 … B-12) and
> `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_DISPOSITION.md` (the security owner's
> rulings H-1 … H-8 and §3, which are the specification for this revision —
> where the check's suggested repair and a ruling differ, the ruling wins).
> Every label on the page is kept; nothing that survived the attack is
> softened; no gap is deleted. The last section, **§10 "What the check
> changed"**, is one line per finding.

**Changes in this revision**

| ruling | what changed | sections |
|---|---|---|
| **H-1** (B-1) | C-R3 is **not** a hypothesis of the lift: the run header absorbs `expected-IO`, which carries **both** external endpoint roots, before any challenge exists, and `check_endpoints` refuses unless the prover's own owners produce exactly them — so the input plane and the **final output** plane are committed before the header and the prover has already run the whole forward pass. "Harder, not merely longer" is withdrawn: **longer, not harder.** What remains of C-R3 is an interface item. Ruling R-1.3's pre-pass costing is withdrawn and a new rule for a production caller is added | §0, §4.1, **§4.4**, §4.5, §5.3, §6.1, §7.1 rows 26/27, §7.2, §7.3 item 3, §9 |
| **H-2** (B-2) | "the code side of M-9 is built and pinned" → the whole run-statement writer is `#[cfg(test)]` and `prove_run` has **no production caller** at `8c5922b`; M-9 is a rule plus a tested writer until the integrator's wrapper exists | §5.1, §7.1 row 28, §7.2 |
| **H-3** (B-3) | the generator stated exactly: `rng.rs:47` is keyed for the **key derivation only**; `rng.rs:53-61` `refill` is **unkeyed** BLAKE3 over `key(32) ‖ le64(counter)(8)`, 40 bytes, in XOF form. Five BLAKE3 functions in a tagged run. Register D19a, the tag disposition §2a and `hashtag.rs:22-33` carried the wrong sentence and are corrected | §1.1, §2.1, §6.1 |
| **H-4** (B-4) | the model restated: the **form** (a family indexed by mode and key) is what the argument uses; the **justification** is an ideal compression function at a chaining value the adversary knows and chooses — stronger than D19 as it was put to the project owner, and **proposed as D19b**. The toy's two terms are **not deleted but re-priced** into a key-collision row `C(m,2)·2^-256`, added to the residual table | §2.1, §2.2, §2.3 (N7), §6.2, §6.4, §7.1 rows 5/6/9, §7.3 item 1, §9 |
| **H-5** (B-5) | F-1 kept, with the checker's analysis (not a leak, not splicing) and the ruling that the **property** is pinned — no transcript operation between `run.rs:551` and the next iteration's `:492` — owed on the lane | §3.5, §7.1 row 17 |
| **H-6** (B-8) | F-3 completed: the draw counts at the three configurations, the pre-repair controls, the residual unmoved, and the **third** receipt total that moved with the attention repair (frozen-seam rung 4,218,264 → 4,218,600) | §6.2, §7.1 row 33 |
| **H-7** (B-6, B-7, B-9 … B-12) | errata: B9's "impossible: 0" re-worded and the last stage's missing case named; new row **B10** (constructor vs absorb); 10^6 is not 2^20; the absorb count's "validated by nothing" **retracted**; C-R5's `gpu-cuda` gate; two run profiles, not three shapes; and the smaller corrections B-12 b–f | §1.1, §1.3, §2.3, §3.5, §4.3, §6.2, §6.3, §7.2, §7.3 items 4/5, §8.2 |
| **H-8** (F-2) | F-2 kept, with the analysis (a constructor input can equal a squeeze input only by spelling `squeeze` at a fixed offset after a 32-byte state; none of the seven constructor lengths is 47) and the ruling: **a one-line test** that no registered profile's constructor input has the squeeze length, owed on the lane | §2.3, §7.2 |
| **§3** of the disposition | O-4 is unchanged in kind from the toy; hypothesis (ii) of the sequential-kernel lemma is now a **code fact**; the lemma exists only for field messages on an older branch, and extending it to (field, hash) message pairs is the **next paper task**, closing the toy's O-4 at the same time. **G-H1 stays THE gap** | §4.5, §7.1 row 27, §7.4, §9 |

| | |
|---|---|
| Written | 2026-09-21, between 00:05 and 00:45 PDT (`date` read at 00:05:47, 00:28:35 and 00:39); **revised from 01:13 PDT** (`date` read at 01:13) against the check and the disposition |
| Lane read | `/home/victor/wt-zk60-block125m` at **`8c5922b`** ("Stage 23 ledger", 2026-09-21 00:02:08 -0700), read-only, through `git --no-pager show 8c5922b:<path>`. **Every `file:line` in this page is at that commit** and was read there, not transcribed from an earlier memo |
| Subject | gap **G-R5** of `ZK60_JOINT_LAW_COMPOSITION_RUN.md` §4.3: *(H6^run) is not written, and the composition of Theorem B with it into ONE sequential argument is not written* |
| What it is | one argument in two halves for a **run** of `L` blocks — Lemma H^run (the hash layer) and the lift (Fiat–Shamir) — with every step labelled, every count sourced, and the gaps named |
| What it is not | **a privacy acceptance of anything, and no privacy claim about any run.** Register entry D22 covers exactly one artifact, the toy block, and bars the development rungs, the 125M block and every multi-block run by name. Nothing here narrows that. D8 and D11 are untouched |
| Runs | **nothing was built, proved, verified or benchmarked**, in the draft or in this revision. One exact-arithmetic Python script was run for the draft (§8.1) and one read-only check over already-existing capture bundles' public tag fields (§8.2); the revision ran only a one-line exact evaluation of `C(12,2)·2^-256` and re-read the Rust. No witness, no salt, no private plane and no receipt byte was read |

---

## 0. In plain words, before any notation

A run is `L` transformer blocks proved under **one** Fiat–Shamir transcript,
each block's hidden output being the next one's hidden input. Last night the
project accepted, as a **reduction**, that the *numbers* a run publishes have
the same joint law whatever the hidden run input was, once the random
challenges are fixed (Theorem B, `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md`).
Two things were explicitly left over, and together they are gap **G-R5**:

1. **The fingerprints.** A run publishes `4L + 1` Merkle roots, `256` salts
   and `256` authentication paths per commitment, and — new at a run — `2L`
   32-byte **position tags** in the segment frames. At the twelve-block 125M
   shape the trees hold **2,473,984** leaves of which about **2,461,552**
   belong to columns nobody ever opens, and about **12,215** of those have
   their leaf digest published outright. Why is that safe?
2. **The challenges.** Theorem B holds "at fixed challenges". In the real
   protocol every challenge is a hash of everything published before it,
   across all `L` stages. The step from one to the other is the lift.

**What this page can reach.** Inside the model the project has proposed
(decision D19 as amended by D19a: BLAKE3 read as a *family* of independent
random functions indexed by mode and key), the two halves compose for a run
exactly as they do for the toy, and the arithmetic is **not where a run's
privacy budget goes**. Every hash-layer term of a twelve-block 125M run is
below **2^-106** even against an adversary allowed 2^128 oracle queries,
while the sampler bias decision D9 already accepted sits at **2^-69.3**. The
hash layer is 37 bits of slack.

**What it cannot reach, and this is the honest headline.** The composition
into ONE sequential argument is delivered here by **Route A** (a lazy-sampling
hybrid inside the random-oracle model), which is what the toy carries. The
form condition **O-4** actually asks for — **Route B**, the sequential-kernel
lemma over messages that are *(field, hash)* pairs — is **still not closed**,
for a run as for the toy. **A run is LONGER, not harder** (ruling H-1, after
the check's finding B-1; the draft of this page said "harder, not merely
longer" and was wrong). The reason the first draft gave — that a run's hidden
input is supplied one stage at a time and so is not fixed before the first
message — **is false of the code**: the run header absorbs `expected-IO`
(`run.rs:316`), which carries binding commitment roots to **both** the hidden
input plane and the hidden **output** plane (`private_block.rs:213`,
`:686-695`), before any challenge exists, and `check_endpoints`
(`run.rs:470` → `protocol.rs:451`) refuses unless the prover's own endpoint
owners produce exactly those roots. So the prover has already run the whole
forward pass before the header, and "the witness is fixed before the first
message" holds — computationally, by the binding of the endpoint commitments
and by the proved chain. §4.4 states it; §4.5 states the exact lemma that
would close O-4, and the gap that remains is that **nobody has extended the
sequential-kernel lemma to messages that are (field, hash) pairs** — which is
the next paper task and closes the toy's O-4 at the same time.

**Three things this page found that no document names.**

* **F-1**, verified against ten real capture bundles rather than argued:
  **a run segment's 32-byte trailer is byte-equal to the next segment's
  32-byte header tag.** The `2L` position-tag fields on the wire carry only
  `L + 1` distinct values. Not a leak — duplication publishes nothing — and,
  after the check's own mechanism reading, **not a splicing weakness** either:
  `decode_segment` compares the 32-byte run binding first and the start tag
  against **the verifier's own transcript position**, never against the
  previous segment's trailer (`wire.rs:430-438`). But every statement about a
  run's hash objects must say `L + 1`, not `2L`; `32(L − 1)` bytes of receipt
  buy nothing; and nothing pins it. **Ruling H-5: what is pinned is the
  PROPERTY** — no transcript operation between a segment's end tag and the
  next segment's start tag — **not the coincidence**; the wire format is
  settled and stays. §3.5.
* **F-2**: the completed hash-length guard is switched off wholesale for
  tagged profiles, which is right for coincidences *between* the four keyed
  domains and one notch too wide for the one that is *within* a domain
  (transcript constructor against transcript squeeze) — **and the set a run
  builds never contained the run's own transcript domain in the first place**.
  The 125M run profile's constructor input is **46 bytes**, one character of
  profile string from the 47-byte squeeze class. Structural at worst, and
  checked by nothing. **Ruling H-8: a one-line test** that no registered
  profile's constructor input has the squeeze length, so the margin is
  watched rather than argued. §2.3.
* **F-3**: the run composition memo's sampler draw counts are stale at
  `8c5922b` — the stage-20 S19-F1 repair moved `Σ L_s` and so the masking
  commitment's draws (+38 per rung-G block, +62 per 125M block), and the
  pinned receipt totals with them (`+336` B at rung-G, `+336` B at the
  frozen-seam rung and `+560` B at 125M against the figures the D19 tag
  disposition recorded — **three** of its four pinned totals have moved, and
  the first draft of this page named two). The residual does not move. §6.2.

---

## 1. Every hash object a run publishes, in transcript order

### 1.1 The five functions a tagged run uses, and which is which

Under ruling T-1 and register entry **D19a** a tagged profile derives four
public 32-byte keys, each `blake3::derive_key(<context>, <profile string>)`
(`zkp-core/src/hashtag.rs:47-53` the four context strings, `:92-101`
`for_profile`; both re-read at `8c5922b`, where the first draft's `:48-56`
and `:95-104` were each a line or two out), and BLAKE3 in keyed mode under
each is read as an independent random function. `hashtag::hasher(None)` is the
literal legacy `blake3::Hasher::new()` call (`hashtag.rs:152-158`), so a
legacy caller is byte-identical by construction.

**A run is keyed under its BLOCK shape's keys** — `Shape::hash_tag()` keys off
`self.profile`, the block profile (`shape.rs:558-572`), and `run.rs:477`
takes `sh.hash_tag()` from the block shape — while its transcript *domain* is
the run's own profile string (`run.rs:310`, `protocol::tagged_transcript`,
`protocol.rs:96-101`). That is ruling D19a as accepted, and it is what
separates a run's challenge chain from a standalone block's of the same shape.

| # | function | used by | keyed? | where the choice is made |
|---|---|---|---|---|
| **F_T** | Fiat–Shamir transcript | every absorb and every squeeze of the run, and every squeeze of a discarded clone (position tags, refusal replays) | keyed, `K_T = derive_key(CTX_TRANSCRIPT, block profile)` | `transcript.rs:40-45` (`new_tagged`), `:59-68` (`absorb`), `:101-111` (`squeeze_bytes`), `:156-162` (`clone_state` copies the key) |
| **F_C** | PCS column digest | one query per *encoded* column of every commitment | keyed, `K_C` | `pcs.rs:148-153` (`hash_column_keyed`), `:182-…` (`hash_columns_keyed`), `zk.rs:695-698` (`pcs_hash_column_keyed`, the `M` copy) |
| **F_L** | salted Merkle leaf | one query per encoded column | keyed, `K_L` | `pcs.rs:691-696` (`salt_leaf_keyed`) |
| **F_N** | Merkle inner node | `nn − 1` per tree | keyed, `K_N` | `merkle.rs:27-32` (`hash_pair_keyed`), `:52-65` (`build_keyed`), `:102-109` (`verify_path_keyed`) |
| **F_U** | plain UNKEYED BLAKE3 | the statement digests **and the randomness generator's refill** | **not keyed** | `run.rs:221`, `:286`; `boundary.rs:211`; `endpoint_g.rs:158`; `private_block.rs:222`, `:512-518`; `layout.rs:1288`; **`rng.rs:53-61`** |
| (F_K) | BLAKE3 *keyed* mode under a **secret** key | the generator's key derivation only | keyed, `K = 32 B of /dev/urandom` | `rng.rs:44-51` (`new_keyed` at `:47`) |
| (F_D) | BLAKE3 *derive-key* mode | the four tag keys themselves | — | `hashtag.rs:95-98` |
| (SHA) | SHA-256, not BLAKE3 at all | segment file digests in the sink and in the run statement file | — | `run_sink.rs:29`, `:49-51` |

**Claim N1 [VERIFIED IN THE CODE; CONFIRMED by the independent check, B-3].**
`ZkRng::refill` is **still plain unkeyed BLAKE3 over `key(32) ‖ le64(counter)(8)`,
40 bytes**, at `rng.rs:53-61` — read as an **extendable output** (`finalize_xof`
at `:58`, filled into an 8,192-byte buffer). The D19 tag did **not** move the
generator. So a tagged run uses five BLAKE3 functions, not four, and the
fifth is shared with every statement digest the lane computes. §2.3 is about
what that still costs.

> **RULING H-3 — the generator, stated exactly, and three documents corrected.**
> Keyed mode appears in the generator **once, at the birth of the key**:
> `ZkRng::from_entropy_reader` hashes `"hashline-zk-os-rng/v1/"(22) ‖ domain`
> under `Hasher::new_keyed(&entropy)` with 32 bytes of `/dev/urandom` as the
> key (`rng.rs:44-51`, `new_keyed` at **`:47`**). **Every byte of every pad,
> mask, CFS coefficient and salt is then produced by the UNKEYED function**,
> in XOF form, over a 40-byte input (`rng.rs:53-61`). Consequences, all three
> ruled: a tagged run uses **five** BLAKE3 functions, not six; **the 40-byte
> input class is still load-bearing** (it is the only thing that keeps the
> prover's randomness stream out of an input an adversary can construct —
> §2.3's N5, ruling L-3's rescoped C-H1); and the **toy statement's generator
> assumption is unaffected**, because `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`
> §2 assumes the *output stream* is indistinguishable from uniform and says
> nothing about the mode. Three places said the opposite and are wrong:
> register entry **D19a**, `ZK60_D19_HASH_TAG_DISPOSITION.md` **§2a** (T-1 as
> worded: *"the generator's keyed function under its secret key"*) and the doc
> comment at **`zkp-core/src/hashtag.rs:22-33`**. The first two are corrected
> by the disposition of 2026-09-21; the source comment is corrected at
> integration — it is a comment in the integrator's crate, and this lane does
> not edit it. The corrected sentence reads: *"…the four keyed functions of a
> profile, the **unkeyed** function, which the legacy rule and **the
> generator's refill** both use, and BLAKE3's derive-key mode, in which the
> four tag keys and the generator's own key are made."*
>
> *(Editor's precision on the last clause, which does not change the ruling:
> the four **tag** keys are made in derive-key mode, `hashtag.rs:95-98`; the
> **generator's** key is made in BLAKE3's KEYED mode under 32 bytes of
> `/dev/urandom`, `rng.rs:47`. Both are key-derivations that never touch the
> output stream, which is the point the ruling makes; the §1.1 table keeps
> them on two rows, `(F_D)` and `(F_K)`, so the code citations stay exact.)*

### 1.2 What a run publishes, in transcript order, with the hash objects marked

Header (`run.rs:315-320`), six absorbs, before any commitment exists:
`run-shape` (56 B), `expected-IO` (112 B, which **contains the two external
endpoint roots and the two external scales**, `private_block.rs:213`),
`public-statement` (32 B, an F_U digest over the `L` block digests,
`run.rs:220-227`), `parameters` (the run's line, `run.rs:234-246`),
`calibration` (32 B, the fixed F_U literal `private_block.rs:221-223`),
`schedule` (32 B, an F_U digest, `run.rs:285-300`). The transcript state right
here is the **run binding** (`run.rs:480`), carried in every segment header
and **compared, never adopted** (`wire.rs:430-432`).

Stage `k`, in the order the bytes are produced:

| # | object | kind | function | code at `8c5922b` |
|---|---|---|---|---|
| 1 | `start_tag`, 32 B, from a **discarded clone** | hash object, never absorbed | F_T (2 squeezes) | `run.rs:492`, `:404-411` |
| 2 | absorb `pb-run-stage` (k), absorb `pb-run-block` (block digest) | absorbs | F_T | `run.rs:494-495` |
| 3 | `B_k`'s root (k + 1 < L), then `rows`, then `log-cols` | **hash object**, on the wire | F_T absorbs; the root is an F_N image | `run.rs:505` → `protocol.rs:150-154`; wire `wire.rs:388-390` |
| 4 | `A_k`'s root, then `rows`, then `log-cols` | hash object | as above | `protocol.rs:666` |
| 5 | `M_k`'s root, absorbed **bare** (no rows, no log-cols) | hash object | F_T absorb | `protocol.rs:676` |
| 6 | β, γ, α | challenges | F_T squeezes | `protocol.rs:682-684` |
| 7 | `H_k`'s root, then `rows`, then `log-cols` | hash object | | `protocol.rs:774` |
| 8 | 23 slots: `pb-slot`, one masked scalar, the round messages, the terminals | **field values** | F_T absorbs, F_T squeezes | `argument.rs:327`, `:331`, `:347`, `:407` |
| 9 | `M_k`'s opening: θ, `q` (1,024 `Fp2`), the 48 proximity coefficients, `prox`, 256 indices, then **256 (column, salt, path)** | field + hash | | `zk.rs:563-600` |
| 10 | `A_k`'s opening: λ per claim, `a_groups` group vectors, the proximity ρ, `prox`, 256 indices, then **256 (column, salt, path)** | field + hash | | `pcs.rs:1023-1052`, `zk_rhos` at `:943-964` |
| 11 | `H_k`'s opening, the same shape | field + hash | | `protocol.rs:800` |
| 12 | the **incoming** opening: `B_{k−1}` with both claims, or at `k = 0` the external input endpoint | field + hash | | `run.rs:526-539` |
| 13 | at `k = L − 1` only: the external **output** endpoint's opening | field + hash | | `run.rs:540-549` |
| 14 | `end_tag`, 32 B, again from a discarded clone | hash object, never absorbed | F_T (2 squeezes) | `run.rs:551` |

The segment's bytes are an **88-byte header** (magic `HLPRUNS1`, the run
binding, `L`, `k`, `start_tag`) plus the objects above plus a **32-byte
trailer** (`end_tag`): `wire.rs:250`, `:263`, `:265`, `:376-413`. Framing is
**120 B per segment**.

Beside the `L` segment files a publishable run directory carries **one more
published object**, which no earlier memo puts in the hash-object inventory:
the **run statement file** `statement/run-statement.json`
(`run_sink.rs:71`), which publishes the run binding, the public-statement
digest, the schedule digest, every internal boundary's **statement digest**
(an F_U digest that is never absorbed anywhere), the two external roots, and
each segment file's **SHA-256** (`run_statement_file.rs:353-364`, `:401-416`,
`:419-428`). Its own negative declaration lists what is not in it
(`:431-436`). **Claim N2 [VERIFIED IN THE CODE]:** every hash object in that
file is a deterministic function of data the receipt already publishes or of
the public statement, so it adds no new object to Lemma H^run — but it is in
the view, and (H6^run) must say so.

**Claim N3 [VERIFIED IN THE CODE] — the fact that makes the lift much smaller
than it looks, and it survives for a run.** Of the hash view, **only the
`4L + 1` roots are ever absorbed**. Salts and paths are absorbed nowhere:
`open_zk` absorbs the group vectors (`pcs.rs:1033`) and the proximity vector
(`:1035`), draws the indices (`:1036`), and *then* gathers
`(index, column, salt, path)` (`:1038-1050`); `mask_open` does the same
(`zk.rs:584`, `:593`, `:594`, `:596-599`); the verifiers mirror it. The
position tags are not absorbed either — they come off a clone and are
compared (`run.rs:625`, `:765-767`; `wire.rs:255-262`). The run binding is
compared, never absorbed (`wire.rs:430-432`). So **the only witness-dependent
hash objects feeding the challenge chain are the `4L + 1` roots**, exactly as
at the toy with five.

### 1.3 The counts [COUNTED, §8.1]

Commitments: `3L` block commitments (`A`, `H`, `M`), `L − 1` internal
boundaries, 2 external endpoints — `4L + 1`, and the same number of openings.

| | rung-G, L = 3 | rung-K4, L = 3 | 125M, L = 12 |
|---|---:|---:|---:|
| commitments = openings = roots | 13 | 13 | 49 |
| of which boundary roots (on the wire, **not** in the statement) | 2 | 2 | 11 |
| encoded columns per `A`/`H` tree | 4,096 | 4,096 | 65,536 |
| encoded columns per `M` tree | 4,096 | 4,096 | 4,096 |
| encoded columns per boundary/endpoint tree | 4,096 | 4,096 | 65,536 |
| **leaves in the whole run = salts drawn** | **53,248** | **53,248** | **2,473,984** |
| salt slots published (`256 × (4L+1)`) | 3,328 | 3,328 | 12,544 |
| distinct opened columns (expected) | 3,226.5 | 3,226.5 | 12,431.9 |
| **unopened leaves (expected)** | **50,021.5** | **50,021.5** | **2,461,552.1** |
| …of which the leaf **digest** is published (expected) | 3,031.7 | 3,031.7 | 12,215.4 |
| tree nodes revealed in total (expected) | 27,770.6 | 27,770.6 | 179,358.3 |
| path digest **slots** on the wire | 39,936 | 39,936 | 188,416 |
| position-tag fields / **distinct values** (F-1) | 6 / **4** | 6 / **4** | 24 / **13** |
| segment framing, bytes | 360 | 360 | 1,440 |

(The two totals in that row were 27,770.3 and 179,359.1 in the first draft;
the independent check recomputes them as **27,770.6** and **179,358.3** from
the same per-tree figures, which it reproduces exactly — a rounding
difference in the summation, not an error, corrected here. **B-12b.**)

The 2,473,984 figure **is** the salt count `ZK60_JOINT_LAW_COMPOSITION_RUN.md`
§3.5 quotes for a twelve-block 125M run — located and verified: it is
`L(2·nn_block + 4096) + (L+1)·nn_io = 12(2·65536 + 4096) + 13·65536`
(control C4, §8.1). The 3,328 is the gate's own "3,328 of 3,328 opened
columns re-hashed" at a three-block run (control C5).

Honest prover queries, by function [COUNTED]:

| function | rung-G L=3 | rung-K4 L=3 | 125M L=12 |
|---|---:|---:|---:|
| F_C, column digests | 53,248 | 53,248 | 2,473,984 |
| F_L, salted leaves | 53,248 | 53,248 | 2,473,984 |
| F_N, inner nodes (`Σ nn − (4L+1)`) | 53,235 | 53,235 | 2,473,935 |
| F_T, absorbs [COUNTED from the code's absorb sites; **VALIDATED** by a second route, B-10] | 1,129 | 1,138 | 5,932 |
| F_T, live squeezes | **6,924** [MEASURED] | **7,686** [MEASURED] | ≤ 176,848 [BOUNDED] |
| F_T, squeezes on discarded clones (the tags) | 12 | 12 | 48 |

The two measured squeeze counts are the run gate's own `final_counter`
(`zk60_native_run_gate_s20/run-g-dense-s20.json`,
`zk60_native_run_gate_k4/run-i-dense-k4.json`, field
`stage2_transcript_replay`). Control **C7** reproduces them from the gate's
own challenge count by `final_counter = challenges_checked + 64·(4L+1)` —
64 squeezes per opening, because `challenge_indices` takes four indices out
of each 32-byte squeeze (`transcript.rs:136-148`) — and it is exact on all
five bundles. **And the gate measures the same two numbers on the dense and
the all-zero bundle**: 6,092 / 6,924 at rung-G, 6,854 / 7,686 at rung-K4.
That is a *measurement* that the number of transcript operations does not
move with the hidden input, which §4.3 needs. (The independent check
re-derived control C7 itself on all six gate bundles —
`final_counter − challenges_checked = 832 = 64·(4L+1)` at `L = 3`, exactly,
on every one — and confirmed the dense-versus-zero equality at both rungs,
6,924/6,924 and 7,686/7,686.)

**The absorb count is validated, and this page's own self-flag is retracted
(B-10, ruling H-7).** The first draft said 1,129 / 1,138 / 5,932 was
"validated by nothing". It is validated: the check reproduced all three
exactly by a route this page did not use — the capture bundles' own public
`transcript_program` field (the recorder's transcription of `run.rs`'s
absorb sites), the pinned layout models, and the **measured** per-role
opening group counts read out of the bundles (`roles[*].groups`: A = 36,
H = 9, external endpoint = 1, internal boundary = 2), in
`results/zk60_hash_layer_fs_lift_run_check/absorb_count_validation.py`. Two
independent derivations agree on all three configurations, with the one free
parameter fixed by measurement rather than guessed.

At 125M nothing is measured. This page's script counts the opening channels
exactly (164,560 squeezes at L = 12) and does **not** model the 23 slots'
per-slot definition draws (`tau`, `mu`, `nu`, `zeta`, `r_*` in
`argument.rs:942-1560`); at the two rungs those account for 978 and 987
squeezes over three stages, so the script's allowance of 1,024 per stage at
125M is generous. **How generous is now sized** (B-10, answering §7.3 item
4): modelling the squeeze channels the capture's `transcript_program` names
and subtracting from the gate's measured `final_counter` leaves **325.0**
unmodelled slot-definition draws per stage at rung-G and **328.0** at
rung-K4; the slot variable count grows 1.49× to the 125M shape, so the
extrapolation is **~485 per stage** against the allowance of 1,024 — about
**2.1× generous**. Even a 100× error leaves the pre-query term at ~2^-103.8,
34 bits below D9. **The 125M transcript-query figure is a BOUND and is
labelled one everywhere it is used.** Every term it enters is 2^-110 or
smaller.

---

## 2. Domain separation under the keyed family

### 2.1 The modelling assumption, stated exactly

**The form, which is what the argument uses.**

> **(D19a, the FORM).** For a tagged profile, decision D19's random oracle is
> read as a **family of independent random functions indexed by BLAKE3's mode
> and key**: the four keyed functions `F_T, F_C, F_L, F_N` of that profile,
> the derive-key mode `F_D` in which the four tag keys **and the generator's
> own key** are made, and the unkeyed function `F_U`, which the legacy rule
> **and the generator's refill** both use. It is an idealisation like the rest
> of D19. (`ZK60_D19_HASH_TAG_DISPOSITION.md` §2a, T-1 as amended;
> `hashtag.rs:22-33`, whose present wording is the one ruling H-3 corrects.)
> **ASSUMED, not accepted.**

Two things the first draft of this page got wrong here, both ruled:

* it listed *"the generator's keyed function `F_K` under its own secret key"*
  as a member. **It is not one.** The generator's *stream* is the unkeyed
  function `F_U`; keyed mode appears only at the birth of the key, and
  derive-key mode is where that key is made. Ruling **H-3**, §1.1.
* it attached to the form the justification *"that is BLAKE3's own design
  claim for its modes"*. **That justification is false**, and the honest one
  is stronger than D19 as it was put to the project owner. Ruling **H-4**:

> **THE JUSTIFICATION, restated honestly (ruling H-4, the check's B-4), and
> PROPOSED TO THE PROJECT OWNER AS D19b.** BLAKE3's own design claim
> separates its three **modes** (hash, keyed_hash, derive_key), by flag bits.
> `F_L` and `F_N` are the **same mode** under **different, published** keys
> (`pcs.rs:691-696`, `merkle.rs:27-32`, both through
> `hashtag::hasher(Some(k))`); nothing in that claim covers key-indexing, and
> keyed BLAKE3 as a random-function family is a statement about **secret**
> keys, whereas all four tag keys are public functions of public strings.
> The honest model is: **BLAKE3's compression function is ideal, also when
> the adversary knows and chooses the chaining value it starts from** — keyed
> mode replaces the chaining value with the key words, so a query to `F_L`
> and a query to `F_N` are two *distinct points of one ideal primitive*
> whenever `K_L ≠ K_N`, which is everything the argument needs. That is the
> assumption under which BLAKE3 is shown to behave as a random function in
> the first place, but it is **strictly stronger than D19 as Victor accepted
> it**, and it was not put to him. **Nothing accepted rests on it** — no
> tagged profile has a privacy statement — and **nothing measurable changes**:
> see §2.2. It is proposed as register entry **D19b**, recommendation
> **accept**, on Victor's rulings page and not urgent. The alternative — a
> one-byte prefix per domain under the single unkeyed function — stays inside
> D19 exactly, costs about half a percent of hashing, and would mean redoing
> the tag stage; it is recorded, not recommended.

Two conventions travel with it from the toy and are unchanged (§5.1 of
`ZK60_HASH_LAYER_AND_FS_LIFT.md`, ruling L-2): **(V-1)** one long-output
oracle models unkeyed BLAKE3 in both its 32-byte and its XOF form, which needs
**indifferentiability** and is **ASSUMED**; **(V-2)** keyed BLAKE3 is an
independent oracle, the conservative convention — written at the toy for a
**secret** key, and reused here for four **public** ones, which is exactly
what D19b's ideal-compression reading is there to license.

### 2.2 Which of the toy's length arguments become unnecessary — and where the two deleted terms actually went

**Claim N4 [PROVED HERE, given D19a as restated in §2.1].** Three of the
toy's length arguments are no longer needed for a tagged run, because the
coincidences they rule out are now coincidences *between different
functions*:

| toy argument | why it is unnecessary here |
|---|---|
| "47 is occupied by nothing else" — no challenge query can be a node, leaf, column hash, refill or absorb | challenges are in F_T; nodes in F_N; leaves in F_L; columns in F_C; refills in F_U. Only **absorbs** share F_T with squeezes, and §2.3 keeps that one |
| the one 64-byte absorb `absorb_u64(b"log-cols", ·)` colliding with a node or a salted leaf — the toy's **2^-241.42** row | that absorb is still exactly 64 bytes at every shape (§8.1's table), but it is an **F_T** query and nodes and leaves are **F_N / F_L** queries. The row **disappears**, replaced by the model |
| a salted-leaf input equal to a **node** input, both 64 untagged bytes — the toy's **2^-484.83** row and ruling L-7's binding flag | F_L ≠ F_N. The row disappears, and the *binding* ambiguity L-7 flagged disappears with it for tagged profiles (`pcs.rs` test `a_salted_leaf_is_a_merkle_node_under_the_legacy_rule_and_is_not_under_a_tag`, `pcs.rs:1610-1616`) |
| condition C-H4 (`rows ∉ {5, 8}`) and its completed form | not imposed on a tagged profile, deliberately: `hash_domain::imposed_at_shape_with` returns an **empty** set unless the profile hashes under the legacy rule (`hash_domain.rs:320-326`), and `imposed_shape_free` likewise (`:353-359`). Right, for the same reason |

**This is a simplification, and it must not be quietly banked as a
strengthening.** It moves two *counted* terms into an *idealisation*. The run
composition memo says so at its §4.3 precision 4 and this page repeats it.

> **AND THE TWO TERMS ARE NOT DELETED — THEY ARE RE-PRICED (ruling H-4, the
> check's B-4).** The first draft struck the toy's **2^-241.42** and
> **2^-484.83** rows and put nothing in their place. Under the
> ideal-compression reading of §2.1 the events they priced are impossible
> **given** `K_L ≠ K_N`, so what remains is exactly `Pr[a derive_key
> collision]`. That is the probability Claim N7 computes, `C(m,2)·2^-256`
> over the `m` tag keys in existence, and it belongs **in the residual
> table**, which the first draft's version carried only the generator-key row
> `3·4·2^-256 = 2^-252.42` for. At `8c5922b` **`m = 12`** — three tagged
> block profiles (rung-G, rung-K4, 125M: `shape.rs:384`, `:444`, `:478`, all
> tagged by `hashes_under_the_legacy_rule` at `shape.rs:549-551`, which
> returns `true` only for the frozen toy and the frozen-seam rung) × four keys
> — so the row is `C(12,2)·2^-256 = 66·2^-256 =` **2^-249.96** [COUNTED].
> That is 181 bits below the sampler at 125M `L = 12`, so **no total moves**;
> the table must carry it because it is the honest price of the step that
> deleted the other two rows. **For today's profiles the term is not
> negligible, it is ZERO, by test**: `hashtag.rs:206-220`
> (`all_eight_keys_are_pairwise_distinct`) pins the eight keys of rung-G and
> 125M pairwise distinct, and `:188-200` pins them as hex literals; and
> `hash_tag_tests.rs:96` and `:109` pin rung-K4's key **set** as different
> from rung-G's and from 125M's — which is weaker than pairwise distinctness
> of all twelve keys, and is why the ruling below is owed.
> **Ruling: the pairwise-distinct test is extended to every tagged
> profile** — all twelve keys, pairwise, not two profiles' eight plus two
> set-inequalities — and that test is **owed on the lane**. The residual row
> applies only to future profiles.

### 2.3 Which length arguments STILL matter, and the unkeyed hashes that remain

Keying separates the four domains from each other. It does **not** separate
queries *within* one function, and it does not touch F_U. Three things
survive.

**Claim N5 [COUNTED, §8.1] — inside F_U, 40 bytes is still unoccupied, and
this is the one that carries a secret.** A tagged run's F_U queries are:

| F_U input | length (bytes) | rung-G L=3 | 125M L=12 | attacker-influenced or witness-dependent? |
|---|---|---:|---:|---|
| calibration identity, a fixed literal (`private_block.rs:222`) | 30 | 30 | 30 | no — a constant |
| block public-statement digest (`private_block.rs:512-518`) | 31 + all public weight words, length-prefixed — the 31 is the literal `b"hashline/private-block-public/1"` at `:514`, so a reader can check the count (B-12e) | ≫ 200 | ≫ 200 | **public weights only**; no hidden value enters |
| block schedule digest (`layout.rs:1288-1296`) | 33 + Σ(8 + line) | ≫ 200 | ≫ 200 | no — public layout |
| generalised-endpoint spec digest (`endpoint_g.rs:158`) | **142** | 142 | 142 | no — public geometry |
| internal-boundary spec digest (`boundary.rs:211`) | **151** | 151 | 151 | no — public geometry |
| run public statement (`run.rs:221`) | 29 + 32L | 125 | 413 | no — block digests |
| run schedule digest (`run.rs:286`) | 31 + Σ(8 + line) | ≥ 276 | ≥ 283 | no — public schedule |
| **generator refill** (`rng.rs:54-58`) | **40** | 40 | 40 | **yes — the 256-bit stream key** |

No other F_U input on the path is 40 bytes, and `29 + 32L = 40` has no integer
solution, so it is not an accident of `L`. **The toy's "40 is occupied by
nothing else *on this path*" survives verbatim for a run, and it is still the
argument that keeps the prover's randomness stream out of reach of a query
the adversary can construct.** [COUNTED; the check is in the script and prints
an empty list.]

Two riders. (i) The only F_U input of a run that is an *unbounded* function of
public data is the block public-statement digest, whose input is the public
weights — so an adversary who *chooses the weights* chooses an F_U input. It
cannot be 40 bytes (31 + four length-prefixed weight vectors + the activation
table), but a profile with a degenerate weight set should not be assumed away:
**condition C-R1** below. (ii) A **legacy-rule** profile proved on the same
machine (the toy, the frozen-seam rung) puts its nodes, leaves, columns,
absorbs and squeezes into F_U as well. A run's refill (40 B) could then
coincide with a legacy column digest of `8·rows = 40`, i.e. a 5-row
commitment. The toy has none (455 / 384 / 50 / 7 / 7) and the completed guard
refuses 5 rows under the legacy rule (`hash_domain.rs:266-277`, `:320-326`).
**Cross-profile separation therefore still rests on the legacy guard, which is
now only imposed on legacy profiles — which is exactly where it is needed.**

**Claim N6 [COUNTED, §8.1] — inside F_T, 47 is unoccupied, but at the 125M
run profile by ONE byte, and nothing checks it.** F_T's three input layouts,
read at `8c5922b`:

| query | input | length |
|---|---|---|
| constructor (`transcript.rs:24-33` unkeyed, `:35-45` tagged) | `"hashline-v1/"(12) ‖ domain` | `12 + \|domain\|` |
| absorb (`transcript.rs:59-68`) | `state(32) ‖ le64(\|label\|) ‖ label ‖ le64(\|data\|) ‖ data` | `48 + \|label\| + \|data\|` |
| squeeze (`transcript.rs:101-111`) | `state(32) ‖ "squeeze"(7) ‖ le64(counter)(8)` | **47** |

An absorb can never be 47 because `48 + |label| + |data| ≥ 48`. **The bound
that matters is that 48, the minimum of the layout, not the "≥ 60 on this
path" the first draft wrote** (B-12d): 60 is an unstated shape fact about
this path's labels and is not what makes B3 true. So the only way 47 is
occupied twice is a transcript **domain** of length 35. All seven profile
strings on the lane, measured:

| profile | `Transcript::new*` input |
|---|---:|
| **run `…/private-run-m125/1`** | **46** |
| block `…/private-block-m125/1` | 48 |
| block `…/private-block-t32-poc/1` (the frozen toy, legacy rule) | 51 |
| run `…/private-run-rung-g-t24-dev/1` | 56 |
| run `…/private-run-rung-k4-t24-dev/1` | 57 |
| block `…/private-block-rung-g-t24-dev/1` | 58 |
| block `…/private-block-rung-k4-t24-dev/1` | 59 |

The 125M **run** profile's constructor input is 46 bytes — one character of
profile string away from the squeeze class. **None of the seven is 47**, and
the nearest domain length to the dangerous 35 is the 125M run profile's 34
(independently measured by the check,
`results/zk60_hash_layer_fs_lift_run_check/tag_chain_recheck.py`).

**Finding F-2 [VERIFIED IN THE CODE].** Two separate things, both live:

1. **The length set a run builds does not contain the run's own transcript
   constructor.** `RunStatement::new` calls
   `hash_domain::imposed_at_shape_with(&st.rs.sh, Some(line))`
   (`run.rs:186`), and `at_shape_with` adds `NEW_FIXED + sh.profile.len()`
   (`hash_domain.rs:285`) — `sh.profile` is the **block** profile. The run's
   own domain string, which is what `run.rs:310` actually hands to
   `Transcript::new_tagged`, is in no set the code builds.
2. **The guard is off for tagged profiles wholesale, and the wholesale switch
   is one notch too wide.** T-3 as amended is right that coincidences
   *between* the four domains mean nothing under a tag. But the
   constructor-versus-squeeze coincidence is *within* F_T, where the key is
   the **same**, and switching the whole set off switches that one off too.

**How big is it? Small, and I say so.** The first draft wrote that "the
collision is not a probability but a deterministic property of the profile
string"; that clause is **wrong on its own terms and is struck** (B-7). The
honest statement has two conjuncts, one deterministic and one probabilistic:
a 47-byte constructor input is `"hashline-v1/" ‖ domain` and a squeeze input
is `state(32) ‖ "squeeze"(7) ‖ le64(counter)(8)`, so they coincide only if
**(a)** `|domain| = 35` and the domain's bytes 20..27 spell `squeeze` at that
fixed offset after the 32-byte state — deterministic, and **false at all
seven profiles**, none of which is even at length 35 — **and (b)** a
transcript state equals `"hashline-v1/" ‖ domain[0..20]`, which is `2^-256`
per squeeze. **It is a structural defect at worst, not a live break, and no
profile in scope is at 35.** It is written down because it is the one
C-H4′-shaped condition a tag does *not* discharge, and because nothing today
would catch a future profile string that hit it.

> **RULING H-8 — the margin is watched, not argued.** *A one-line test that
> no registered profile's constructor input has the squeeze length* (i.e.
> that no profile's `12 + |domain|` is 47, equivalently no `|domain|` is 35),
> over every profile the lane registers. **Owed on the lane.** Until it
> exists, **condition C-R2** is checked by nothing, which is what §7.2 says.

**Claim N7 — key collisions, and the row §2.2 sends here [COUNTED].** The
four keys of a profile are `derive_key(context, profile)` images
(`hashtag.rs:92-101`). Two of them, or a key of one profile and a key of
another, collide with probability `C(m, 2)·2^-256` over the `m` keys in
existence. **At `8c5922b`, `m = 12`**: three tagged block profiles — rung-G
(`shape.rs:384`), rung-K4 (`shape.rs:444`) and 125M (`shape.rs:478`) — times
four keys each, the run profiles contributing none because a run is keyed
under its **block** shape's keys (`run.rs:477`, `shape.rs:558-572`). So
`C(12,2)·2^-256 = 66·2^-256 =` **2^-249.96**, and that is the row §2.2 adds
to the residual table as the honest price of the two rows the tag deletes.
Today it is **zero by test** for the eight keys
`all_eight_keys_are_pairwise_distinct` (`hashtag.rs:206-220`) covers, which
`the_four_keys_of_each_tagged_profile_are_pinned` (`hashtag.rs:188-200`,
**not** `:188-203` as the first draft cited) pins as hex literals; rung-K4's
four are pinned only as a **set** distinct from the other two
(`hash_tag_tests.rs:96`, `:109`), and extending the pairwise test to all
twelve is the ruling of §2.2.

More to the point for hiding: a *public* tag key equal to a generator's
32-byte `key` field would let anybody recompute that generator's whole
stream, since the refill input is `key ‖ counter` in the **unkeyed**
function. With three generator keys per run, uniform on 256 bits, and `m`
public tag keys, that is `3m·2^-256`; the table below prices it at `m = 4`
for the profile at hand, **2^-252.4**. (Counting all twelve published keys
instead of the run's own four gives `36·2^-256 =` 2^-250.83 [COUNTED]; the
row is left at the profile's own four, which is what one run's stream can be
recomputed from, and the difference is 1.6 bits at 250.) Negligible, and it
is the one place where "the tag keys are public" has any cost at all.

### 2.4 Cross-profile and cross-run separation

**Claim N8 [VERIFIED IN THE CODE].** Three separations, three mechanisms:

1. **A block proof of shape S against a stage of a run over S.** They share
   all four keys (D19a, accepted) but not their transcript: the block's
   constructor absorbs the *block* profile (`protocol.rs:115`), the run's the
   *run* profile (`run.rs:310`), so their initial states differ and every
   challenge of one differs from every challenge of the other outside an F_T
   collision. Their **trees** are separated by nothing but their contents and
   their salts — which is enough for hiding (every salt is fresh) and is a
   fact (H6^run) must state rather than assume away.
2. **One run against another run of the same shape.** The **run binding** —
   the F_T state after the header (`run.rs:480`) — is in every segment header
   and is compared (`wire.rs:430-432`); it differs whenever any header word
   differs, and the header carries the two external roots, the `L` block
   digests, the calibration and the schedule. Two runs on the same statement
   with different hidden inputs share a binding, which is correct: the binding
   is a function of public data only. Their salts, roots and challenges differ
   because the generators are independent (three fresh `/dev/urandom` reads
   per run: `run.rs:475`, `endpoint_g.rs:224` twice).
3. **A run against a profile under the legacy rule.** Complete for
   F_T/F_C/F_L/F_N (different functions), and for F_U it is the 40-byte
   argument of N5.

One thing this does **not** give: the **context digest**. `RunStatement::new`
refuses an all-zero context (`run.rs:126-128`) and the context rides inside
the endpoint and boundary spec digests and inside `ExpectedIo`
(`private_block.rs:213`). If a deployment derived the context from the
*request*, two worlds would not share a statement and the quantifier of any
privacy sentence collapses — the toy's condition O-1/O-B, unchanged for a run
and restated here as **condition C-R4**.

---

## 3. Lemma H^run: the hash layer adds nothing, for a run

### 3.1 What the composition needs, restated for a run

Split a run's published output into the **field view** `V` — every `Fp`/`Fp2`
word of all `L` segments, i.e. exactly the rows marked *field values* in §1.2
— and the **hash view** `H` — the `4L + 1` roots, the `256(4L+1)` published
salts, the `256(4L+1)` authentication paths, the `2L` position-tag fields, the
run binding, the segment framing, and the run statement file's derived
digests. Write `ρ` for the whole challenge vector and `NR(ρ)` for non-refusal.

> **[RELIES ON — Theorem B, `ZK60_JOINT_LAW_COMPOSITION_RUN.md` §3.7, accepted
> as a REDUCTION by the disposition of 2026-09-20 17:58.]** For every
> admissible hidden **run** input (the JOINT condition on all `L` stages,
> ruling R-1.1) and every `ρ` with `NR(ρ)`,
> `law(V | ρ, NR, w) = law(V | ρ, NR, w′)`, in the uniform-blinding
> idealisation. **Its open conditions travel with every use here: G-R1
> ((H1) per commitment at a shaped layout), G-R2 ((H4), the 23 slot
> closures), G-R4 (cross-role blinding independence over `4L+1` roles on one
> stream), and at 125M G-R3 (no all-zero input exists there — BLOCKING).**

The wrong move is to multiply a witness-free `law(V)` by a witness-free
`law(H)`; the project's standing counterexample `(H(mask), mask ⊕ w)` kills
that. The correct factorisation is
`law(V, H | ρ, NR, w) = law(V | ρ, NR, w) · law(H | V, ρ, NR, w)`, and the
hash layer owes the **second factor**.

### 3.2 The lemma

> **Lemma H^run (hiding of the unopened part, for a run).** Fix an admissible
> run statement, an admissible hidden run input `w`, and a challenge vector
> `ρ` with `NR(ρ)`, in the fixed-challenge experiment. For each of the
> `4L + 1` commitments `r` let `OPEN_r ⊆ [nn_r]` be the distinct sampled
> indices — a public function of `ρ` (`transcript.rs:136-148`). Then there is
> a **public, witness-free** map `T` depending only on the run's geometry, on
> `ρ`, and on answers of `F_L`, `F_N`, `F_C` and `F_T`, such that
>
> ```
> H  =  T( (col_{r,j}, salt_{r,j})_{j ∈ OPEN_r},  (u_{r,k})_{k ∉ OPEN_r},  V )
> ```
>
> where `u_{r,k}` is the salted leaf of never-opened encoded column `k` of
> commitment `r`. In the model of §2.1, for every admissible `w` there is an
> event `B_H^run` with `Pr[B_H^run] ≤ β(q)` such that, off `B_H^run`,
>
> ```
> law( (u_{r,k})_{r,k} | V, the published salts, ρ, NR, w,
>                        the unopened columns themselves,
>                        and the adversary's q oracle answers )
>       =  Unif({0,1}^256)^{⊗ m}
> ```
>
> with `m` the number of never-opened encoded columns — **the same product
> measure for every conditioning and every `w`**. Consequently, for any
> distinguisher making at most `q` queries to the whole family,
>
> ```
> |Pr[D(V,H)=1 | w] − Pr[D(V,H)=1 | w′]| ≤ Δ_field + 2·Pr[B_H^run],
>
> Pr[B_H^run] ≤ q·N_leaf·2^-256  +  C(N_leaf, 2)·2^-256  +  ε_gen(q)
> ```
>
> with `N_leaf = Σ_r nn_r` (53,248 / 53,248 / 2,473,984 at the three
> configurations) and `ε_gen` the generator's term (§6).
>
> **PROVED HERE, inside the model.** The model is **ASSUMED** (D19, D19a,
> neither accepted for a run). The salts' uniformity is the generator step:
> **primarily assumption M-3 (ruling C-3)**, with §6's in-model derivation as
> the labelled alternative.

**What is *not* in the bound, and why the list is shorter than the toy's.**
The toy carried two extra terms — `24,571·2^-256` (a 64-byte absorb equal to a
node or leaf input) and `12,283·12,288·2^-512` (a leaf input equal to a node
input). Under D19a both events are impossible **given that the keys differ**:
the three inputs live in three different functions (§2.2). **The bound got
shorter because the model got stronger, not because anything was measured**
— and, after ruling **H-4**, the two terms are **not gone but re-priced**:
what is left of them is `Pr[a derive_key collision]`, the tag-key row
`C(12,2)·2^-256 =` 2^-249.96 that §6.2 now carries. Read `Pr[B_H^run]` above
with that row beside it.

### 3.3 Proof, in four steps

**Step 1 [VERIFIED IN THE CODE].** For `j ∈ OPEN_r` the opened leaf is a
public function of `V` and the published salt: the verifier itself recomputes
`salt_leaf_keyed(hash_column_keyed(col, K_C), salt, K_L)` before walking the
path (`pcs.rs:1248`; `zk.rs:671`). At a run this is true of every one of the
`4L + 1` openings, including the `L − 1` boundaries
(`run.rs:675`) and the two external endpoints (`run.rs:705`, `:737`).

**Step 2.** For `k ∉ OPEN_r` the leaf is `F_L(d_{r,k} ‖ salt_{r,k})`, a
64-byte input whose second half is a 256-bit value that **never leaves the
process**: `open_zk` emits the salt of a *sampled* column only
(`pcs.rs:1043`, `:1048`), and `mask_open` the same (`zk.rs:598`). Of the
2,473,984 salts a twelve-block 125M run draws, at most **12,544 slots** are
published — about **12,432** of them distinct, because the 256 indices are
drawn with replacement (`transcript.rs:136-148`) — and at least **2,461,440
salts are dropped with their commitment**. That is the entire
supply of secrecy the hash layer runs on. *Everything below prices the salt
and nothing else: the bound would be identical if every hidden column were the
all-zero vector.* Two things can spoil the freshness of the image, and they
are the two hash-layer terms:

* *(a) the distinguisher queries the point.* It must produce the 64-byte
  input, whose last 32 bytes are the unknown salt: at most `N_leaf·2^-256`
  per query, `q·N_leaf·2^-256` over `q`. At 125M `L = 12` that is
  `q·2^-234.76`, i.e. **2^-106.76 at `q = 2^128`**.
* *(b) two leaf inputs coincide*, which would make two "independent uniform"
  values equal. Two F_L inputs are equal iff both the column digest and the
  salt are equal, so `C(N_leaf, 2)·2^-256`: **2^-214.52** at 125M `L = 12`.
  This is the largest `q`-free hash-layer term, as at the toy, and it grows
  quadratically with the size of the run.

**Step 3 — the inner nodes, by induction. PROVED HERE.** A node digest is
`F_N(left ‖ right)` and its input contains no salt and no field value
(`merkle.rs:27-32`). So no new secret enters above level 0, and `T` — "build
the salted leaf vector, then run `build_keyed` and `path`" — is public. At a
run `T` runs `4L + 1` times, once per tree, with no cross-tree input.

**Step 4 — the roots, the tags, the binding and the framing.** Each root is
one such node. The position tags, the run binding and the framing are §3.5 and
§3.6; each is shown there to be a deterministic function of the published
prefix, so each is inside `T`.

**Conclusion.** Off `B_H^run`, `law(H | V, ρ, NR, w)` is a fixed witness-free
kernel; multiplying by Theorem B's witness-free `law(V | ρ, NR)` gives a
witness-free joint law. ∎ **PROVED HERE, inside the model, conditional on
Theorem B (and hence on G-R1, G-R2, G-R4, and at 125M G-R3).**

### 3.4 What a run's trees look like [COUNTED, §8.1]

The method reproduces the toy's published per-tree table exactly before it
computes anything new (control C2): `240.7 / 453.2 / 212.5 / 1,200.6 /
1,654.8 / 40.4 %` for a 2,048-leaf tree, and `248.2 / 481.4 / 233.2 /
1,653.8 / 2,136.2 / 26.1 %` for the toy's 4,096-leaf `M`.

| tree | leaves | depth | distinct opened | leaf digests revealed | of them never opened | internal nodes revealed | total revealed | of `2nn−1` |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| rung-G / rung-K4: every tree | 4,096 | 12 | 248.2 | 481.4 | **233.2** | 1,653.8 | 2,136.2 | 26.1 % |
| 125M: `A`, `H`, boundary, endpoint | 65,536 | 16 | 255.5 | 510.0 | **254.5** | 3,643.7 | 4,154.7 | 3.2 % |
| 125M: `M` | 4,096 | 12 | 248.2 | 481.4 | **233.2** | 1,653.8 | 2,136.2 | 26.1 % |

**The trees get emptier as the shape grows**, which is worth saying because
the intuition runs the other way: at 125M a receipt reveals 3.2 % of each big
tree against the toy's 40.4 %, because the number of opened columns is fixed
at 256 while `nn` grows to 65,536. What grows is the *number* of trees and
therefore `N_leaf`, and the salt-guessing term is linear in it.

### 3.5 The position tags — the verdict

The brief asks four things. Answers, in order.

**(i) What is a tag a function of?** `position_tag(tr)` builds
`Transcript::clone_state(tr)` and squeezes two `Fp2` from it, rendered as 32
bytes (`run.rs:404-411`). `clone_state` copies exactly the 32-byte state, the
squeeze counter and the profile **key**, asserts no masker is installed, and
starts an empty `masked_rounds` (`transcript.rs:156-162`). The state is the
F_T image of everything absorbed so far — all of it published — and the
counter is determined by the number of squeezes so far, which is determined by
the public schedule. The key is public (`derive_key` of two public strings).
**Claim N9 [VERIFIED IN THE CODE]: nothing prover-private enters the clone.**

**(ii) Could it be a side channel?** No. It is a deterministic public function
of the published prefix, and the **verifier recomputes it and refuses on a
mismatch**: `RunVerifier::step` computes `start_tag` itself before decoding
(`run.rs:625`), `decode_segment` compares it against the header
(`wire.rs:436-438`), and the trailer is compared at `run.rs:765-767`. A value
the verifier can compute from the rest of the view carries no information
beyond the rest of the view. It is inside `T`.

> **One clause the first draft owed here (the check's B-5, ruling H-5).**
> "A deterministic public function of the published prefix" must not be read
> as "input-independent". **The published prefix already contains a
> commitment to the hidden input** — the header absorbs `expected-IO`, whose
> endpoint roots are *hiding* commitments to the hidden input and output
> planes — and the check measured the consequence: `start_tag(0)` **differs**
> between bundles of the same profile that differ only in the hidden input.
> That is correct and is not a finding; it means the tags are carried by
> **Lemma H^run** (the roots' hiding), not by "the tag is public". Without
> the clause a reader would conclude the tags are input-independent, and
> they are not.
>
> *(B-12f, same place.)* The tag's 32 bytes are two `Fp2` rendered as bytes
> (`run.rs:404-411`); each `Fp` is a 128-bit squeeze reduced mod `p`, so the
> 32 published bytes carry slightly **under** 256 bits. A public value with
> no consequence for any figure — recorded so a later reader does not treat
> a tag as a full 32-byte oracle output.

**(iii) Does publishing a squeeze at a stage boundary break uniqueness of
challenge queries?** **No, and the reason is delicate enough to write out.**
The clone squeezes with the *same key and the same counter* as the live
transcript, so the tag's first query is at exactly the point
`state ‖ "squeeze" ‖ le64(counter)` the live transcript would use for **its**
next squeeze. It is not a duplicate of a live challenge query because the live
transcript's next operation at that point is never a squeeze:

* after `start_tag` (`run.rs:492`) the next live operation is
  `absorb_u64(b"pb-run-stage", …)` (`run.rs:494`), which changes the state
  before any squeeze;
* after `end_tag` (`run.rs:551`) at any stage but the last, the next live
  operation is the **next stage's `start_tag`** — another clone at the same
  point — and then the same absorb;
* **after `end_tag` at the LAST stage (`k = L − 1`) there is no next stage at
  all**: `prove_run` returns at `run.rs:573`. The first draft's sentence
  ("the next live operation is the next stage's `start_tag`") is simply not
  true there, and the check caught it (B-6). The conclusion holds a fortiori:
  there is no later live operation of any kind;
* and no *opening* falls between a tag and its comparison: the external
  output endpoint's opening happens at `run.rs:540-549`, **before** `end_tag`
  at `:551`, and on the verifier's side at `:737` before `:765`.

So a tag's two oracle points are never queried as live challenges **on the
schedule**, and the live challenge points remain pairwise distinct because
the counter increments on every live squeeze (`transcript.rs:107`). Two
precisions the first draft skipped, both from the check and neither moving a
number:

* **The local argument is not the whole of it.** It rules out a tag's point
  being reached again *by the live chain along the same path*. It does not
  rule out a live squeeze landing on a tag's point by a **state collision** —
  the live state returning to a value a clone was squeezed at. That event is
  not zero; it is an F_T state collision, and it is already priced by **B6**
  (`C(A,2)·2^-256`, 2^-222.04 at 125M). §4.3's row B9 is re-worded
  accordingly.
* **A tag's two points are not both a priori fixed.** A tag is two squeezes
  (`challenge_fp2_vec(2)`, `run.rs:406`), and the second is at
  `(first output, counter+1)` — a point determined by an oracle answer. In
  the lazy-sampling hybrid that is fine, but the two should not be spoken of
  alike, and this sentence is the correction.

The tags do add **duplicate**
queries at points the prover and the verifier each query more than once; that
is a repetition by design, giving the same answers, exactly like the refusal
replay of `check_opening_challenges` (which clones at `protocol.rs:305` and
`:367` and deliberately re-draws the challenges `open_zk` will draw). Neither
enters any bound.

**(iv) And the finding nobody has recorded.**

> **FINDING F-1 [VERIFIED IN THE CODE and MEASURED on ten bundles].
> A run segment's 32-byte trailer is byte-equal to the next segment's 32-byte
> header tag.** Between `let end_tag = position_tag(&tr)` (`run.rs:551`) and
> the next iteration's `let start_tag = position_tag(&tr)` (`run.rs:492`)
> nothing touches the transcript — the intervening lines build the `Segment`,
> encode it, hand it to the sink and record two statistics
> (`run.rs:552-571`). The verifier mirrors it: `position_tag(&self.tr)` at
> `run.rs:765` and at `run.rs:625` of the next `step`, with nothing between.
> So the `2L` tag fields on the wire carry **`L + 1` distinct values**.
>
> **Checked against data, not only read:** every one of the ten run-capture
> bundles on the lane
> (`results/zk60_run_captures_20260920/run-{a..j}*/stage-*.json`, whose
> `start_tag` and `end_tag` members are public transcript positions) has
> `end_tag(k) == start_tag(k+1)` for every `k`, and 6 tag fields carrying 4
> distinct values at `L = 3`. Output in
> `results/zk60_hash_layer_fs_lift_run/tag_identity_check.txt`.
> **CONFIRMED independently** by the check, on the same ten bundles with a
> script sharing no code with this page's
> (`…_check/tag_chain_recheck.py` / `.txt`).
>
> **What it is and is not.** It is **not** a leak: the duplicate is a copy of
> a value the verifier already computes. It is **not** a soundness break: the
> trailer's stated job — localising a corruption to its own segment
> (`run.rs:763-764`) — is done just as well by a value that also appears in
> the next header. **And it is not a splicing weakness** — the check read the
> mechanism rather than asserting it: `decode_segment` compares the 32-byte
> **run binding** first (`wire.rs:430-432`, *"this segment belongs to another
> run"*), then `L`, then `k`, then the start tag against **the verifier's own
> transcript position** (`wire.rs:436-438`), **never** against the previous
> segment's trailer. Two runs can share a binding only by sharing their whole
> public header, endpoint roots included, and `Endpoints` is consumed by
> value with no `Clone` (`private_block.rs:706-720`), so a second run against
> the same endpoint commitments does not type-check. Chained tags therefore
> buy an attacker nothing. It **is** three things: (a) any statement about a
> run's hash objects must say `L + 1` distinct tags, not `2L`; (b) `32(L − 1)`
> bytes of receipt buy nothing (64 B at `L = 3`, 352 B at a twelve-block 125M
> run, against 484 MB — a rounding error, recorded for completeness, not
> proposed as a change); (c) nothing pins the behaviour, so a future edit that
> put a transcript operation between the trailer and the next header would
> silently change the receipt's meaning without changing its length.
>
> > **RULING H-5 — what gets pinned, and what does not.** F-1 is kept as a
> > **measured finding**. The `32·(L−1)` bytes buy nothing; **the wire format
> > is settled and stays** — nothing here is proposed as a format change.
> > A test asserting `end_tag(k) == start_tag(k+1)` would pin the
> > **coincidence**, which is not the property anyone wants and would freeze a
> > redundancy the project may later remove. **Pin the PROPERTY instead: that
> > no transcript operation occurs between `run.rs:551` and the next
> > iteration's `run.rs:492`** — e.g. that the transcript's state and squeeze
> > counter are unchanged across `run.rs:552-571` (re-read at `8c5922b`: those
> > twenty lines build the `Segment`, call `wire::encode_segment`, push two
> > statistics and call `sink(k, bytes)` at `:568`, and none of them takes a
> > transcript). That catches the edit (c) is about. **Owed on the lane.**

### 3.6 The binding and the framing

**Claim N10 [PROVED HERE].** The 88-byte header is `HLPRUNS1 ‖ binding ‖
le64(L) ‖ le64(k) ‖ start_tag` and the trailer is `end_tag`
(`wire.rs:376-413`). The magic, `L` and `k` are public constants of the
statement; the binding is the F_T state after the header, a public function of
the public header words; the two tags are §3.5. Every byte of a run's framing
is therefore a deterministic function of the public statement and the
published prefix, and it is inside `T`. The binding is **repeated in all `L`
segment headers**, all equal — another duplication that publishes nothing.

---

## 4. The sequential lift for a run — the heart of G-R5

### 4.1 What Theorem B must deliver, and what a run adds

The lift needs, for the whole message sequence of all `L` stages:

1. **causality** — each message depends only on `w`, the prover's randomness
   (including the oracle family) and the challenges drawn *before* it;
2. **the joint per-`ρ` hypothesis** — for every non-refused `ρ`, the joint law
   of **every** message of **all** stages is the same for every admissible
   `w`. Theorem B supplies the field half; Lemma H^run the hash half;
3. **the challenges** — including the `2L` position tags, which are functions
   of the public prefix and therefore join `ρ` rather than the messages;
4. **the hidden input fixed before the first message** — §4.4, where it is a
   **fact of the code** for an accepted run (ruling H-1), not a hypothesis a
   caller must promise.

A run changes the *size* of all of this and nothing else. §4.4 is where the
first draft said otherwise and was wrong.

### 4.2 Route A^run: the hybrid, hop by hop

Fix an admissible run statement, an admissible hidden run input `w` and a
distinguisher `D` making at most `q` queries to the family. `G_0` is the real
game: the honest prover runs `prove_run` (`run.rs:462-574`); `D` sees the run
statement, the `L` segments and the statement file, or `⊥`, and may query
before, during and after.

| hop | what changes | what justifies it | cost |
|---|---|---|---|
| **G_0 → G_1** | every member of the family is sampled **lazily** | the definition of the model (D19 + D19a) | 0 |
| **G_1 → G_2** | **all three generators' outputs are sampled up front** | the refill query points are **non-adaptive**: `key ‖ le64(counter)`, `counter = 0, 1, …`, fixed by the key alone (`rng.rs:53-58`). One stream for the run (`run.rs:475`) and one per external endpoint (`endpoint_g.rs:224`) — **three OS reads, all before stage 1** | 0 |
| **G_2 → G_3** | the generator streams are treated as uniform | **primarily M-3 (ruling C-3)**, now over **109,546,000** field draws and **2,342,912** salt draws on the ONE run stream that feeds 47 of the 49 commitments, plus the two external endpoints' own streams (ruling R-2, accepted as built). In §6.1's ASSUMED alternative instead, abort if a query begins with one of the three stream keys or hits a key-derivation point | `ε_PRG` / `ε_gen(q) ≤ 6q·2^-256` |
| **G_3 → G_4** | **all** pads, masks, CFS coefficients and zero-sum rows of the whole run are replaced by uniform field elements | each `fp()` draw is exactly `2^-96` from uniform (`rng.rs:73-77`); one union bound over the run's whole blinding stream. The salts need no replacement: `bytes32` is raw stream output (`rng.rs:93-99`) | **decision D9's term at run scale: 2^-69.3 at 125M `L=12`** |
| **G_4 → G_5** | abort on `B_H^run` | Lemma H^run, §3.2–3.3 | `q·N_leaf·2^-256 + C(N_leaf,2)·2^-256` |
| **G_5 → G_6** | abort on the transcript-function bad events | §4.3 | `q·A·2^-256 + C(A,2)·2^-256 + (A+q)·2^-256` — the last being row **B10**, added in this revision |
| **G_6 → G_7** | **every challenge AND every position tag is replaced by a value drawn uniformly in advance** | each F_T squeeze input is 47 bytes, fresh within the run (the counter increments, `transcript.rs:107`), met by no absorb (any absorb is `48 + \|label\| + \|data\|` ≥ 48 > 47, §2.3 as corrected by B-12d) and not pre-queried (§4.3). The tags are F_T squeezes at points no live challenge uses (§3.5 iii), so they are replaced consistently and the verifier's re-derivation still holds | 0 |
| **G_7** | = the fixed-challenge experiment, `ρ` uniform and independent of `(w, blinding)` | — | — |
| **G_7 → G_8** | split on refusal; on a non-refused `ρ` apply **Theorem B** (field) × **Lemma H^run** (hash) | §5 | `2 · L·768/\|Fp2\|` |
| **G_8 → G_8′** | `w := the all-zero chain` | **RELIES ON** the measurement at rung-G and rung-K4; **G-R3 at 125M, BLOCKING** — §4.6 | 0 |
| **G_8′ → G_0′** | undo in the zero world | the same bounds | counted |

Written as an identity, from G_6 on,
`law(view | w) = E_ρ[ law(V | ρ, w) · law(H | V, ρ, w) ]` with `ρ` uniform in
both worlds; the first factor is witness-free by Theorem B at every
non-refused `ρ`, the second by Lemma H^run. Integrating gives a witness-free
law for the whole view up to the sum of §6. **PROVED HERE, inside the model,
conditional on Theorem B and Lemma H^run.**

**The hop order, which the brief asks about explicitly.** Hop G_3 → G_4
replaces **all** the blinding at once rather than stage by stage. The two cost
the same and I say why: a stage-by-stage hybrid has `L` hops, hop `k` costing
(stage `k`'s draws)`·2^-96`, and `Σ_k` (stage `k`'s draws) is the run's total —
so the sampler term is `(total draws)·2^-96` either way, **linear in draws and
not in `L` separately**. Doing it at once is preferable for one reason: an
intermediate world in which stages `1..k` are uniform and `k+1..L` are real is
only well defined because the stream positions of the two halves are disjoint
and non-adaptive, which is the very fact gap **G-R4** says is unproved. The
single-hop version needs that fact once, at the top, rather than `L − 1` times
in the middle. **So: one hop, and the ruled residual 2^-69.3 is the whole
cost.**

### 4.3 The transcript-function bad events, sized

`A` is the number of F_T queries in one run: absorbs + live squeezes + the
tags' clone squeezes. **rung-G L=3: 1,129 + 6,924 + 12 = 8,065** (the squeeze
figure MEASURED). **rung-K4 L=3: 1,138 + 7,686 + 12 = 8,836** (MEASURED).
**125M L=12: 5,932 + 164,560 + 48 + (≤ 1,024 per stage of unmodelled slot
definition draws) ≤ 182,828** (BOUNDED; §1.3).

| # | bad event | disposed of by | size at 125M `L=12` |
|---|---|---|---|
| **B1** | two live challenge draws in one run share an F_T input | **impossible**: the squeeze counter increments every call (`transcript.rs:107`) | **0** |
| **B2** | a challenge input coincides with a node, leaf, column-digest or refill input | **impossible** in the model: four different functions (§2.2) | **0** |
| **B3** | a challenge input coincides with an **absorb** input | **impossible**: 47 < 48 ≤ any absorb (§2.3) | **0** |
| **B4** | the constructor input coincides with a squeeze input | **impossible at every profile in scope** (46/48/51/56/57/58/59 ≠ 47); **condition C-R2** for future profiles, and ruling **H-8**'s one-line test | **0** today |
| **B5** | the distinguisher queried a challenge input **before** the prover did | possible, harmless (an oracle answer is uniform whoever asks first); priced for the lazy-sampling ordering | `q·A·2^-256` = **2^-110.52** |
| **B6** | two distinct absorb inputs collide | `C(A,2)·2^-256` | **2^-222.04** |
| **B7** | `B_H^run` | §3.2 | see §6 |
| **B8** | the distinguisher **chooses the public statement** to bias a challenge (grinding) | **impossible on this schedule**: no challenge is drawn before a root is absorbed — `run.rs:505` and `protocol.rs:666`, `:676` precede `protocol.rs:682` — and every root is an F_N image on an input the distinguisher cannot compute without `B_H^run` | **0**, outside `B_H^run` |
| **B9** | a position tag's query coincides with a live challenge query | **impossible ON THE SCHEDULE**: §3.5 (iii), verified at every boundary including the last stage, where there is no next stage at all. A **non-local** coincidence — the live state returning to a value a clone was squeezed at — is *not* impossible: it is an F_T state collision and **is inside B6** (ruling H-7, the check's B-6; the first draft's "impossible: 0" was overstated) | **0** on the schedule; the non-local case is priced in **B6** |
| **B10** *(new, the check's B-7)* | the **constructor** input coincides with an **absorb** input | six of the seven constructor lengths are ≥ 48 and so sit inside the absorb class (46/48/51/56/57/58/59 against `48 + \|label\| + \|data\|`), so length is **not** a separation here and the first draft's "≥ 60 on this path" was not one either. What disposes of it is content: the constructor's first 12 bytes are `hashline-v1/` and an absorb's first 32 are a transcript state, so equality needs the state to be a chosen 32-byte string | `(A + q)·2^-256` = **2^-128.00** at `q = 2^128` — 59 bits below the sampler, 22 below B5. **Changes no total** |

### 4.4 The hidden input IS fixed before the first message — and the prover has already run the whole forward pass

**This section is a rewrite. What stood here was the page's most serious
error** (the check's B-1, ruling **H-1**). The first draft called this "the
one thing a run makes HARDER, not merely longer" and wrote that "the witness
is fixed before the first message" is an operating condition on the driver
and **not a fact of the code**. That is **false of the code this page itself
transcribed in §1.2**. The corrected reading, and what it costs and buys:

**Claim N11 [VERIFIED IN THE CODE, corrected] — the run header commits BOTH
hidden endpoint planes before any challenge exists.** Four steps, every line
re-read at `8c5922b`:

1. `RunStatement::transcript()` (`run.rs:304-322`) absorbs `expected-IO` =
   `ExpectedIo::to_bytes()` as its **second** word, at **`run.rs:316`**. That
   frame is 112 bytes — `EXPECTED_BYTES = 8 + 32 + 4 + 4 + 2*32`
   (**`private_block.rs:213`**) — and it carries `self.input` and
   `self.output` (**`private_block.rs:686-695`**): **the Merkle roots of the
   hiding commitments to the hidden INPUT plane and the hidden OUTPUT
   plane.**
2. Those roots are not the prover's to choose at proof time. `prove_run`
   calls `protocol::check_endpoints` at **`run.rs:470`** — *before* the
   generator is opened (`:475`) and before the transcript exists (`:479`) —
   and `check_endpoints` **refuses** unless the prover's own endpoint owners
   produce exactly `expected.input` and `expected.output`
   (**`protocol.rs:451`**, `"private block: expected endpoint root
   mismatch"`).
3. The owners are made by `prepare_endpoints(spec, input, output)`
   (`private_block.rs:743-764`), which commits **both planes** with fresh OS
   entropy and returns the `ExpectedIo` those two roots go into (`:762`). So
   the caller must hold the run's **final output plane** before the statement
   exists. Computing it is a forward pass and nothing else:
   `witness::build_shaped(shape, public, ff, input)` (`witness.rs:437`) is a
   **pure deterministic function** — no rng, no state, no second input — and
   its only caller **on the run's path**, `Chain::from_parts`
   (`run_tests.rs:251-265`), runs it `L` times **up front** to build
   `planes[0..=L]`, after which `statement_of` calls
   `prepare_endpoints(spec, &c.planes[0], &c.planes[l])` at
   `run_tests.rs:433`. (The single-block helper `compute_output`
   (`private_block.rs:770-772`) is the same thing through `witness::build`.)
4. No live challenge precedes any of this: the header is six absorbs,
   `binding = tr.state()` is a *read* (`run.rs:480`), and the first squeeze
   of the whole run is `position_tag`'s, on a **clone**, at `run.rs:492`.

Even the interior is pinned before publication: boundary `k`'s plane is
committed and its root absorbed at `run.rs:500-505`, **inside stage `k`**,
while segment `k` does not leave until `run.rs:568`; and block `k+1`'s hidden
input *is* boundary `k`'s plane, by the slot-21/slot-22 equality the proof
carries. **So for an ACCEPTED run every plane of the chain is fixed before
the first published byte, by induction from the header.**

**What the first draft got right, and what it concluded wrongly.** The code
facts it cited are real: `RunWitnessSource` is documented as *"the private
inputs of a run, asked for ONE STAGE AT A TIME"* (`run.rs:426-435`), the
prover calls `src.boundary_plane(k)` at `run.rs:500` and `src.witness(k)` at
`run.rs:512` **inside** the loop, and segment `k − 1` left through
`sink(k-1, bytes)` at `run.rs:568` one iteration earlier
(`run_sink.rs:181-203` writes to a temporary, `sync_all`s and renames it into
place). What does not follow is that the *input* is unfixed. The API asks for
the witness late; the **header has already committed the answer**.

> **CONDITION C-R3 (restated — ruling H-1).** *In the privacy game the hidden
> run input is fixed by the game's own quantifier, at a run exactly as at the
> toy*: §5.1's game names two admissible hidden run inputs and the challenger
> runs the **honest** prover once, whose source is a `Chain` built from
> `(public weights, x_0)` before the header. *In a deployment it is a
> **consequence**, not a condition*, of three named things: the run header's
> endpoint roots (`run.rs:316`, `private_block.rs:686-695`), which
> `check_endpoints` (`run.rs:470` → `protocol.rs:451`) will not let the
> prover restate; the **binding** of the endpoint commitments; and the
> soundness of the boundary equalities the proved chain carries. Hypothesis
> (ii) of the sequential-kernel lemma therefore holds **computationally**
> where the toy's held syntactically — a real change, and the only one §4.4
> has to report. **C-R3 is no longer a hypothesis of the lift.**
>
> **What remains of it is an interface item, not a proof obligation.** The
> `RunWitnessSource` trait still *permits* a source that answers adaptively,
> and nothing refuses one. An adaptively-chosen witness cannot produce an
> **accepted** run (by the above), but it can produce an *aborted* one, and
> it makes the honest prover's determinism a property of every caller rather
> than of the type. The owed engineering item is therefore not "fix the
> input": it is **make `RunWitnessSource` take the chain at construction**.
> It is tightened when the production caller is written.

> **NEW RULE FOR ANY PRODUCTION CALLER OF A RUN (ruling H-1, consequence 2).**
> **The pass that seals the endpoints is the witness builder's own, with its
> refusals — so an inadmissible chain is refused before the header and no
> partial directory can arise from that cause.** Rule **M-9** stays, as the
> second line. The reason this is cheap is in §5.3: the prover *cannot* seal
> the output endpoint without having run the whole forward pass, so the pass
> is already paid, and the only real choice is **which** function computes the
> output plane — only `witness::build_shaped` carries the twelve range
> refusals (`witness.rs:290, 374, 386, 394, 526, 534, 542, 555, 600, 640,
> 672, 708`); a caller may legitimately use the reference kernel
> `private-block-kernel::run_block` instead, and nothing enforces either.
> That is the code fact the rule closes.

### 4.5 Route B^run, condition O-4, and the exact lemma that would close it

Condition **O-4** asks for the per-round kernels to be composed into ONE
sequential argument via the **sequential-kernel lemma over paired messages**,
which works for *any* challenge function and does not need the challenges to
be uniform. For a run, define the message at step `j` as the pair
`m_j = (field part, hash part)`:
`m_0 = (∅, B_1's root)` — **not** `A_1`'s, because `run.rs:505` precedes
`protocol.rs:666` — then `A_1`'s root, `M_1`'s root, `H_1`'s root, the 23
slots' field messages, the four openings of stage 1 (the last of which carries
columns, salts and paths), then stage 2's `B_2` root, and so on, ending with
the external output endpoint's opening. The tags and the challenges are the
`r_j`.

> **The lemma that would close O-4 for a run, stated exactly.** Let a protocol
> produce messages `m_0, …, m_N`, `m_j = (f_j, h_j)`, and challenges
> `r_j = χ_j(prefix_j)` for arbitrary deterministic functions `χ_j` of the
> published prefix. Suppose
> **(i) causality**: `m_j` is a function of `(w, the prover's randomness, r_{<j})` only;
> **(ii) non-adaptive input**: `w` is fixed before `m_0` and is not a function of any `r_j`;
> **(iii) independence of the challenge function from the prover's randomness**: the family `(χ_j)` is measurable with respect to a source independent of everything the prover's messages depend on;
> **(iv) the joint per-`ρ` hypothesis**: for every fixed `ρ` with `NR(ρ)`, the joint law of `(m_0, …, m_N)` is the same for every admissible `w`.
> Then for every family `(χ_j)` the law of the whole view — messages,
> challenges and the refusal indicator — is the same for every admissible `w`.

For a run: (i) is **VERIFIED IN THE CODE** from §1.2's order, including the
new object — `B_k`'s root exists before any challenge of either adjacent
equality slot (`run.rs:498-509`), and `B_{k−1}`'s opening is emitted in stage
`k` after its second claim exists (`run.rs:525-531`, the code's own comment
*"the incoming commitment's claim list is complete NOW, and not before"*).
**(ii) is a CODE FACT for an accepted run** (ruling H-1, §4.4): the run header
absorbs binding commitments to the hidden input plane **and the hidden output
plane** before any challenge exists (`run.rs:316`,
`private_block.rs:686-695`), `check_endpoints` (`run.rs:470` →
`protocol.rs:451`) will not let the prover restate them, and the game's own
quantifier fixes `w` in any case. It holds **computationally** — by the
binding of the endpoint commitments and the soundness of the proved chain —
where the toy's held syntactically. The first draft said (ii) was "condition
C-R3 and false of the code as written"; **that is withdrawn.** (iii) is where
Route B is **not** a free lunch, and the toy memo did not say so: in the real
protocol `χ` is the **F_T oracle** and the messages depend on F_C, F_L, F_N,
F_U — so (iii) is *exactly* D19a's independence-of-modes assumption, and
Route B therefore depends on the same idealisation Route A does, plus the
branch lemma. (iv) is Theorem B × Lemma H^run.

> **GAP G-H1 (= O-4 for a run, and it is THE gap — NARROWED in its diagnosis,
> not in its size).** The lemma above exists in the repository only on branch
> `zk60-mvp-fable` (`ZK60_MVP_JOINT_VIEW.md` §1.2, reviewed at
> `ZK60_JOINT_VIEW_REVIEW_20260918.md:54-56`), **for field messages only**;
> privacy-case item 17's carve-out (ii) says in as many words that it "*is
> about field messages and says nothing about the hash layer*". Pairing each
> message with a hash part **extends its message alphabet**, and adding the
> position tags to the challenge alphabet extends it again. Nobody has written
> the extension, the toy left it open, and a run does not close it.
>
> **Is a run harder or merely longer? LONGER** (ruling H-1, the check's B-1).
> Longer in (i) and (iv): `L` times the messages, `L + 1` extra roots, a
> bad-event union linear in `L`, and Route A's hop count unchanged at ten. Not
> harder anywhere: the first draft's one candidate, (ii), is a code fact for
> an accepted run. **What is open is open for the toy and for a run in exactly
> the same way, and for one reason only: nobody has extended the
> sequential-kernel lemma to messages that are (field, hash) pairs.**

> **O-4, as the security owner's disposition §3 puts it — UNCHANGED IN KIND
> FROM THE TOY.** This page's hybrid composes the fixed-challenge theorem
> with the hash-layer lemma **inside the model**, which is the standing the
> toy already has. What is **not** done, for the toy or for a run, is the
> sequential composition over **arbitrary challenge functions** — Route B.
> The lemma that closes it is known in shape: causality; the witness fixed
> before the first message (**now a code fact**, H-1); the challenge family
> independent of what the prover's messages depend on; and, for every
> non-refused challenge vector, the joint law of all messages witness-free.
> It **exists only for field messages, on an older branch**. **Extending it
> to (field, hash) message pairs is the NEXT PAPER TASK, and it closes the
> toy's O-4 at the same time.** G-H1 stays **THE** gap.

**So: O-4 is NOT closed for a run.** What *is* delivered here is Route A^run,
which composes Theorem B and Lemma H^run into one argument inside the model
(§4.2) — the same standing the toy has — plus, new, the precise statement of
what Route B would need, and the corrected finding that a run adds **no**
hypothesis to it.

### 4.6 Oracle programming, and whether the ideal world exists

**Claim N12.** Route A needs **no oracle programming**, at a run as at the
toy, because the ideal world is the honest prover on the all-zero chain
(decision D18-A) rather than a simulator: `check_endpoints` refuses any policy
whose external roots differ from the prover's own fresh ones
(`run.rs:470` → `protocol::check_endpoints`), and the `L − 1` internal
boundary roots are the prover's own by construction (`run.rs:504`). Under a
caller-fixed root — D8/D11's configuration, untouched here — the simulator
would have to program an oracle point and Lemma H^run would be the wrong tool
entirely.

**Does the all-zero chain exist?** Tested at the two development rungs, not at
125M:

| | all-zero run proves and verifies |
|---|---|
| rung-G, `L = 2` and `L = 3` | **yes** — `run_tests.rs`'s `the_all_zero_hidden_input_proves_and_verifies_as_a_run`, and the capture bundles `run-b-zero`, `run-d-zero`, `run-f-zero-tagged`, `run-h-zero-s20` [MEASURED by the lane] |
| rung-K4, `L = 3` | **yes** — bundle `run-j-zero-k4` [MEASURED by the lane] |
| **125M, any `L`** | **no test exists — GAP G-R3, BLOCKING (ruling R-4)**, and the zero witness sits on two exact range boundaries whose constants moved at that shape |

This page predicts nothing about G-R3's outcome and does not narrow it.
**Every 125M figure below is conditional on it.**

---

## 5. Refusals and aborts in the lifted protocol, and the privacy game

### 5.1 The game, stated explicitly

> **The privacy game for a run, as D21 and operating rule M-9 define the
> published object.** The adversary names an admissible run statement and two
> admissible hidden run inputs `w_0`, `w_1` (or `w` against the all-zero
> chain). The challenger runs the honest prover once. If the run completes and
> verifies, the adversary is handed **the whole publishable run directory**:
> the `L` segment files and the run statement file, and nothing else. If the
> prover refuses at any stage, the adversary is handed **`⊥` and nothing
> else** — no segment, no partial directory, no refusal reason. The adversary
> then makes at most `q` queries to the hash family and guesses.

That is the game M-9 makes real, and the code side of it is built and pinned
— **in a `#[cfg(test)]` module** (ruling **H-2**, the check's B-2; the first
draft wrote "built and pinned" and stopped there, which was misleading):
the statement file is written **only** by `verify_then_write`, which verifies
the whole run first (`run_statement_file.rs:235-247`: `verify_run_from_dir`
at `:237`, the file created at `:243` and `sync_all`ed at `:245`); a run directory must be **empty** at the start
(`run_sink.rs:151-159`) and may hold only the `L` segments and the one
`statement` directory (`run_sink.rs:71-80`); the test
`a_failed_run_leaves_no_statement_file` pins it.

> **RULING H-2 — M-9 has no production code behind it yet.** The whole
> run-statement writer, `verify_then_write` included, is registered as
> `#[cfg(test)] mod run_statement_file;` at **`private_block.rs:178-179`**,
> and it must be: `render` calls `st.capture_header()` and `st.binding()`,
> both `#[cfg(test)]` (`run.rs:327-338`). Further, at `8c5922b` **`prove_run`
> has no production caller at all** — `git grep prove_run` over
> `hashline/src` returns only `run.rs`'s definition, two doc comments and
> five `#[cfg(test)]` call sites (`run_tests.rs:440`, `:1125`, `:1412`,
> `k4_tests.rs:484`, `run_capture_tests.rs:110`), and `verify_run_from_dir`
> has no caller outside the test-only `run_statement_file.rs`. **The object
> this page's privacy game is defined over — the whole publishable run
> directory — does not exist in a production build of this crate.** That does
> not weaken the analysis (the code is the code), but it makes M-9 something
> *stronger* than the first draft said: not an operating rule with a built
> code side, but **a rule, a tested writer, and nothing more, until the
> integrator's run wrapper exists** — at which point the rule must be
> re-imposed on whatever production driver is written. It is carried in §7.2
> as a **condition**, not as a fact.

### 5.2 What a refusal is, at a run

Three classes, and only the second and third are inside the argument:

1. **Witness-build refusal at stage `k` — input-determined, probability 0 or
   1.** Twelve of the fourteen `return Err` sites of `witness::build_shaped`
   are range or relation checks on hidden values, at
   `witness.rs:290, 374, 386, 394, 526, 534, 542, 555, 600, 640, 672, 708`
   (re-read at `8c5922b`; **none has moved since the run memo read them at
   `caa9b9a`**); the other two, `:431` and `:443`, are shape refusals. They are
   reached at `run.rs:512`, **inside** the stage loop. So an inadmissible chain
   is discovered at its first inadmissible block, with certainty, leaving
   `k − 1` complete segments on disk — and **which** block refused is a
   function of the hidden input (ruling R-1). This is why "admissible hidden
   run input" is a JOINT condition on all `L` stages.
2. **Challenge-only refusals — liveness, not distance.** `(3L + 1)/p`, four
   base-field proximity determinants per PCS opening and `3L + 1` openings:
   **2^-60.68** at `L = 3`, **2^-58.79** at `L = 12` (ruling R-6).
3. **The one input-dependent refusal inside the argument** — a zero LogUp
   denominator. Ruling **S-4**: at most 768 distinct inverted arguments per
   block at every shape, so `L·768/|Fp2|`: **2^-116.83** at `L = 3`,
   **2^-114.83** at `L = 12` [COUNTED, control C6].

**Discharging the conditioning [PROVED HERE, elementary].** With the
challenge-driven part the same measurable function of a uniform `ρ` in both
worlds, and the witness-build class excluded from the quantifier by
definition,

```
d(view_w, view_0) ≤ Pr_w[LogUp] + Pr_0[LogUp] + sup_{NR ρ} d(…)
                  ≤ 2·L·768/|Fp2| + ε_hash + ε_sampler .
```

The constant is 2, not 1, because the conditioning event itself differs
between the worlds in the LogUp class (the toy's correction C-8, unchanged).
*(Beware a one-bit reading trap the check flagged as B-12c: §6.2's table
prices the S-4 row at `L·768/|Fp2|` — the one-sided figure, −116.83 / −114.83
— while the discharge above uses **twice** it, −115.83 at `L = 3` and
−113.83 at `L = 12`. Neither moves a total, which is the sampler term to four
decimals either way; the two are named here so nobody adds them twice.)*

**And one sentence about what a relying party learns from a refusal, which
the check asked for and which belongs here.** Of the three classes, the
argument covers the second (challenge-only, 2^-58.79 at 125M `L = 12`,
liveness) and the third (LogUp, 2^-114.83). So a relying party who sees a
refusal on a run learns **"either an inadmissible chain, or one event of
probability ≤ 2^-58.79"** — which is very nearly "an inadmissible chain".
That is a statement about the FACT of refusal, and it is exactly why the
refusal fact is outside every privacy statement the project has (§5.3).

### 5.3 What changes if a deployment violated M-9

**Claim N13, and it is the sharp one.** If a partial directory were shipped,
the adversary would hold segments `1..k−1` of a run that refused at stage `k`.
**Nothing in this page or in Theorem B says anything about those bytes.**
Theorem B is quantified over chains that are admissible at **every** stage; a
chain that refuses at stage `k` is not one, so the law of its first `k − 1`
segments is outside every statement the project has. On top of that the
adversary would learn `k` itself — the index of the first inadmissible block —
which is a statistic of the hidden chain worth up to `log2 L` bits **given**
the refusal, and in truth the whole "first inadmissible index" random variable.
And the refusal **string** names the stage, and **all twelve** witness-build
strings name the failing check: ten are `range(<site>)` (`witness.rs:290`,
`:374`, `:386`, `:394`, `:534`, `:555`, `:600`, `:640`, `:672`, `:708`) and
two are explicit relation names (`:526` causal maximum attainment, `:542`
softmax denominator).

So **M-9 is a hypothesis of any run privacy statement, not an operating
nicety**, and it should be printed in the statement's conditions in exactly
those words — and, after ruling **H-2**, with the added clause that at
`8c5922b` it has **no production code behind it at all** (§5.1).

> **THE ADMISSIBILITY PRE-PASS: RULING R-1.3'S COSTING IS WITHDRAWN (ruling
> H-1, consequence 2).** The first draft repeated R-1.3's pricing of a
> whole-chain admissibility check as *"one more forward pass — up to about
> 15 % of a run if done with the witness builder"*. **It is not one more.**
> The output endpoint cannot be committed without a full forward pass
> (§4.4), so the pass is **already paid**: today's harness in fact pays it
> **twice**, once in `Chain::from_parts` (`run_tests.rs:251-265`) and again
> per stage in `Chain::witness`. The marginal cost of checking the whole
> chain's admissibility before the first segment is handed to the sink is
> about **zero**. The one real choice is **which function computes the output
> plane**: only `witness::build_shaped` carries the twelve range refusals,
> and a caller may legitimately use the reference kernel
> `private-block-kernel::run_block` instead, with nothing enforcing either.
> Hence the **new rule for any production caller** (§4.4): *the pass that
> seals the endpoints is the witness builder's own, with its refusals, so an
> inadmissible chain is refused before the header and no partial directory
> can arise from that cause.* **M-9 stays, as the second line.** What is
> "not built" is the production caller, not an extra pass.

One precision the run memo does not state: at stage `k` the prover commits
`B_k` and absorbs its root (`run.rs:500-505`) **before** it asks for the
witness (`run.rs:512`). So a witness refusal at stage `k` happens after `B_k`
is committed in memory. Nothing of it is published — `sink` is only called at
`run.rs:568` — and `PreparedBoundary` is dropped. **No published byte of stage
`k` exists after a witness refusal at stage `k`** [VERIFIED IN THE CODE].

---

## 6. The residuals for a run

### 6.1 The generator — the standard assumption stays primary

**The generator, read exactly at `8c5922b`.** `ZkRng::from_os(domain)` reads
32 bytes of `/dev/urandom`, failing closed on an unsupported host
(`rng.rs:30-42`), and derives its 32-byte key as **keyed** BLAKE3 —
`Hasher::new_keyed(&entropy)` — over `"hashline-zk-os-rng/v1/" ‖ domain`
(`rng.rs:44-51`). `refill` then produces each 8,192-byte block as **unkeyed**
BLAKE3 in XOF mode over `key(32) ‖ le64(counter)(8)`, 40 bytes
(`rng.rs:53-61`). `fp()` reduces two `next_u64`s mod `p`, exactly `2^-96` from
uniform (`rng.rs:73-77`); `bytes32()` takes four raw words (`rng.rs:93-99`).
**This paragraph is the one ruling H-3 pins** (§1.1): keyed mode **once**, at
the birth of the key (`rng.rs:47`); the stream **unkeyed**, in XOF form, over
a 40-byte input (`rng.rs:53-61`); and three project documents that said
otherwise corrected.

A run makes **three** OS reads, all before stage 1: one for the run
(`run.rs:475`, domain = the **run** profile string) and one inside each
external endpoint preparation (`endpoint_g.rs:224`, domain = the endpoint
module's own 42-byte constant). The run's single stream feeds **47 of the 49
commitments** — every stage's `A`, `H`, `M` through
`protocol::prove_core` (`run.rs:522`) and every internal boundary through
`boundary::prepare` (`run.rs:504`) — which ruling **R-2** accepts as built,
on two conditions (never cloned, forked or serialised; the hidden input fixed
before the first segment). **The second of those is now a fact of the code
for an accepted run, not a promise** (ruling H-1, §4.4): the run header's
endpoint roots commit both hidden planes before the generator is even opened
(`run.rs:470` precedes `:475`). R-2's condition 2 is **re-sized**
accordingly; what is left of the old C-R3 is the interface item of §4.4.

> **PRIMARY — the standard assumption, unchanged from ruling L-2.** The
> statement keeps assumption **M-3** (privacy-case ruling C-3): the
> generator's whole output stream is computationally indistinguishable from
> uniform, two-sidedly. **A run stretches it in two ways worth printing**:
> at 125M `L = 12` the run's single stream must look uniform over
> **109,546,000 field draws and 2,342,912 salt draws** (the run's totals,
> 109,728,784 and 2,473,984, less the two external endpoints' own streams)
> [COUNTED], against 327,052 field draws over three streams at the toy; and the two-sidedness reaches **eleven stage boundaries** — stage 1's
> whole segment, salts and opened columns included, is fsynced and renamed
> into place (`run_sink.rs:181-203`, called from `run.rs:568`) long before
> stage 12's mask rows are drawn from the same stream.
>
> **ALTERNATIVE, labelled ASSUMED.** Inside the model the stream's
> pseudorandomness can be derived instead of assumed: the key is uniform on
> 256 bits and never leaves the process; every output block is `F_U(key ‖
> counter)`; and **the refill query points are non-adaptive** — `key ‖ 0`,
> `key ‖ 1`, … , fixed by the key alone and by no protocol value
> (`rng.rs:53-58`), which is what licenses hop G_1 → G_2 and what disposes of
> "stage 1's salts are published before stage 12's pads are drawn": published
> and unpublished bytes are disjoint ranges of one uniform string. The
> exceptions are a query beginning with one of the three keys, or a guess of
> a 32-byte `/dev/urandom` read followed by recomputing the key through the
> keyed mode on a public input — two routes, three streams:
> `ε_gen(q) ≤ 6q·2^-256`. It costs convention **V-1**
> (indifferentiability of BLAKE3's extendable output, **ASSUMED**, nobody here
> has checked the literature), convention **V-2**, and an assumption about
> `/dev/urandom` that no hash model covers. It does **not** make M-3 true and
> it does not replace it.

And one thing neither buys: the `fp()` reduction bias is untouched. That is
hop G_3 → G_4's term, and at a run it is the whole of `ε(q)`.

### 6.2 The residual table [COUNTED, §8.1]

`q` is the distinguisher's query budget; the prover's own queries are inside
`T` and are not part of `q`. Figures are `log2`.

| residual | formula | rung-G `L=3` | rung-K4 `L=3` | 125M `L=12` | kind |
|---|---|---:|---:|---:|---|
| **sampler bias (decision D9, accepted)** | (run's `fp()` draws) × 2^-96 | **−75.00** | **−74.88** | **−69.29** | distance |
| input-dependent refusal inside the argument (ruling S-4), **one-sided** — §5.2's discharge uses twice it, −115.83 / −115.83 / −113.83 (B-12c) | `L · 768 / \|Fp2\|` | −116.83 | −116.83 | −114.83 | distance |
| salt guessing (Lemma H^run) | `q · N_leaf · 2^-256`, at `q = 2^128` | −112.30 | −112.30 | −106.76 | distance |
| leaf-input collision (Lemma H^run) | `C(N_leaf, 2) · 2^-256` | −225.60 | −225.60 | −214.52 | distance |
| challenge pre-query (B5) | `q · A · 2^-256`, at `q = 2^128` | −115.02 | −114.89 | −110.52 | distance |
| absorb-input collision (B6) | `C(A, 2) · 2^-256` | −231.05 | −230.78 | −222.04 | distance |
| **constructor-vs-absorb (B10, NEW — the check's B-7)** | `(A + q) · 2^-256`, at `q = 2^128` | **−128.00** | **−128.00** | **−128.00** | distance |
| **tag-key collision — the price of §2.2's deleted rows (NEW, ruling H-4)** | `C(m, 2) · 2^-256`, `m = 12` tag keys in existence at `8c5922b` | **−249.96** | **−249.96** | **−249.96** | distance — **and ZERO today, by the test of `hashtag.rs:206-220`, for the eight keys it covers** |
| key collision (tag key = a generator key) | `3 · 4 · 2^-256` | −252.42 | −252.42 | −252.42 | distance |
| generator, **standard model, PRIMARY** | `ε_PRG` against `ZkRng`, no bit count | — | — | — | **assumption** |
| generator, **in-model ALTERNATIVE** (§2.1's V-1, V-2) | `6q · 2^-256`, at `q = 2^128` | −125.42 | −125.42 | −125.42 | distance |
| **TOTAL `ε(q)` at `q = 2^128`** | | **−75.0026** | **−74.8769** | **−69.2906** | |
| *the same at `q = 2^80`* | | −75.0026 | −74.8769 | −69.2906 | |
| **separately: challenge-only refusal** | `(3L+1)/p` | **−60.68** | **−60.68** | **−58.79** | **liveness, NOT distance** |

`ε(q)` equals the D9 sampler term to four decimal places at every budget up to
`2^128`: at 125M `L = 12` the second-largest distance term is 37 bits below
it. **The hash layer is not where a run's error goes**, and the lever an
auditor would reach for is D9's one-line rejection-sampling change, which at
run scale is a better bargain than at block scale. **Neither of the two new
rows moves a total**: B10 at −128.00 is 59 bits below the sampler and the
tag-key row at −249.96 is 181 below it. **The whole table was reproduced
independently** by the check, from the Rust and by a script sharing no code
with §8.1's, including the 37-bit gap (**37.30 / 37.42 / 37.47** bits) and
the fact that `ε(q)` equals the D9 sampler term to four decimals at
`q = 2^80` and `q = 2^128` alike
(`results/zk60_hash_layer_fs_lift_run_check/residuals_recount.py`).

**The sampler draw counts, and a discrepancy with the run memo [COUNTED].**

| | per block | per boundary | per endpoint | run total |
|---|---:|---:|---:|---:|
| rung-G, as `ZK60_JOINT_LAW_COMPOSITION_RUN.md` §6.1 counted | 686,990 | 8,704 | 7,424 | 2,093,226 (`L=3`) |
| **rung-G at `8c5922b`** | **687,028** | 8,704 | 7,424 | **2,093,340** |
| rung-K4 at `8c5922b` (new) | 750,540 | 8,704 | 7,424 | 2,283,876 |
| 125M, as that memo counted | 9,029,742 | 108,032 | 91,392 | 109,728,040 (`L=12`) |
| **125M at `8c5922b`** | **9,029,804** | 108,032 | 91,392 | **109,728,784** |

> **FINDING F-3 [COUNTED — completed under ruling H-6, the check's B-8;
> CONFIRMED TO THE DRAW by an independent recount from the Rust].** The run
> composition memo's draw counts are **stale at `8c5922b`** by 38 per block
> at rung-G and 62 per block at 125M, because the **stage-20 S19-F1 repair**
> moved the two bilinear slots' schedules and therefore `Σ L_s`, which the
> masking commitment's draw count depends on (`2·Σ L_s + 46·256 + 4·1024`).
> The pinned models moved with it: `published_round_values` 1,034 → 1,055 and
> `challenge_draws` 240 → 242 at rung-G, 1,519 → 1,554 and 357 → 361 at 125M
> (`grow_tests.rs:369-391`, `:432-469`), so
> `Σ L_s = published − draws + 46` goes 840 → 859 and 1,208 → 1,239.
>
> **The figures at `8c5922b`, as the disposition lists them (ruling H-6):**
>
> | | generalised rung (rung-G) | four-group rung (rung-K4) | 125M |
> |---|---:|---:|---:|
> | `Σ L_s` | 859 | 871 | 1,239 |
> | **per block** | **687,028** | **750,540** | **9,029,804** |
> | per internal boundary | 8,704 | 8,704 | 108,032 |
> | per external endpoint | 7,424 | 7,424 | 91,392 |
> | **per run** | **2,093,340** (`L=3`) | **2,283,876** (`L=3`) | **109,728,784** (`L=12`) |
> | sampler term, `log2` | −75.0026 | −74.8769 | **−69.2906** |
> | *pre-repair control* | *686,990 / 2,093,226* | *—* | *9,029,742 / 109,728,040* |
>
> **The residual is UNMOVED**: 2^-69.29 under the pre- and post-repair
> figures alike. Last night's **109,728,040** is the *pre-repair* count and
> must be quoted as such.
>
> **Three of the four pinned receipt totals moved, not two.** The D19 tag
> disposition §2b of 2026-09-20 15:50 recorded *"receipt sizes unmoved
> (2,816,472 / 4,218,264 / 4,234,648 / 40,782,792)"*. At `8c5922b`:
>
> | model | at the disposition's 15:50 state | at `8c5922b` (`grow_tests.rs`) | delta |
> |---|---:|---:|---|
> | toy | 2,816,472 | **2,816,472** (`:307`) | 0 — correct: `lkv = 0`, S19-F1 does not reach it |
> | **frozen-seam rung** | **4,218,264** | **4,218,600** (`:351`) | **+336 — the third total, which the first draft did not name** |
> | rung-G | 4,234,648 | **4,234,984** (`:390`) | +336 |
> | rung-K4 | did not exist | 4,743,128 (`:429`) | — |
> | 125M | 40,782,792 | **40,783,352** (`:468`) | +560 |
>
> The two `+336`s are exactly `16 × (1,055 − 1,034)` and the `+560` is
> `16 × (1,554 − 1,519)`. (The pre-repair 4,218,264 survives in the tree as
> `rung_tests.rs:48`'s `RUNG_BYTES_BEFORE_S20`, which names it correctly.)
> This is bookkeeping, and it is recorded because the next person to quote
> 109,728,040 or 4,218,264 should quote it as "the figure before the S19-F1
> repair".
>
> The method behind these numbers reproduces the memo's own figures exactly
> when fed the pre-repair schedule, and reproduces decision D9's ruled 327,052
> toy draws **to the draw** (controls C1 and C3, §8.1). The independent check
> reproduced every one of them from the Rust with a script sharing no code
> with §8.1's (`…_check/residuals_recount.py`).

### 6.3 Many runs

All the terms compose by a union bound, under the assumption
that each run draws fresh OS randomness — three `from_os` calls, no seed
(`run.rs:475`, `endpoint_g.rs:224` twice) — and that `/dev/urandom` gives
independent uniform bytes across runs. For `k` runs the sampler term grows
**linearly** and the leaf-collision term quadratically:

| `k = 10^6` runs | sampler | refusal | leaf collision | salt guessing (`q=2^128`) | **total** |
|---|---:|---:|---:|---:|---:|
| rung-G `L=3` | **−55.07** | −96.90 | −185.74 | −92.37 | **−55.07** |
| 125M `L=12` | **−49.36** | −94.90 | −174.66 | −86.83 | **−49.36** |

> **CORRECTED (ruling H-7, the check's B-9): a million is not 2^20.** The
> first draft's row used `log2(10^6) = 20`; it is **19.9316**, so every
> linear entry was 0.07 bits optimistic and the quadratic leaf-collision
> entry 0.14. The corrected figures are above; the first draft printed
> −55.00 / −96.83 / −185.60 / −92.30 and −49.29 / −94.83 / −174.52 / −86.76.
> "About 2^-49" survives. The toy's published figure ("about 2^-57.7 at a
> million proofs") used 10^6 correctly, so the two pages now round the same
> way.

**A product fact for the project owner, in the same words the toy's got: a
service that emits a million twelve-block 125M runs sits at about 2^-49, not
2^-69, and the whole of that degradation is decision D9's sampler and none of
it is the hash layer.**

### 6.4 The sentence that could be reached, and what must be printed with it

Not a statement, and not proposed as one: this is the FORM a run's statement
would take if everything open were closed, written so the security owner can
see how far short the page falls.

> *In the model of decisions D19 and D19a, and assuming the prover's
> randomness generator's output stream is indistinguishable from uniform, a
> verifier who receives an **accepted** run directory of this profile — the
> run statement file and all `L` segment files, with their `4L+1` roots,
> their field values, their `256(4L+1)` salts, their `256(4L+1)` paths, their
> `L+1` distinct position tags and their framing — and makes at most
> `q ≤ 2^128` hash queries sees a view whose distribution is within about*
> **2^-75.0** *(rung-G, `L = 3`),* **2^-74.9** *(rung-K4, `L = 3`) or*
> **2^-69.3** *(125M, `L = 12`) of a distribution that does not depend on the
> hidden inputs, outputs, activations or boundary planes — per run, growing
> linearly with the number of runs. Whether the prover refuses on an*
> **admissible** *chain is, up to 2^-114.8 at 125M `L = 12`, a function of the
> verifier-visible challenges alone. Excluded from the sentence, in the same
> sentence: the refusal string; timings (D20); anything a capture format
> gains beyond what a run capture writes (D21); and a directory without its
> run statement, which is not a run (M-9).*

**And what today stops that sentence being written**, in the order a reader
should be told: G-R1, G-R2 and G-R4 under Theorem B; **G-R3 at 125M, which is
blocking**; **G-H1 (= O-4)**, the sequential composition in the form the
project asked for — now diagnosed as a **paper task**, extending the
sequential-kernel lemma to (field, hash) message pairs, which closes the
toy's O-4 at the same time; and conditions **C-R1 … C-R5**, of which
**C-R2 is enforced by nothing** (ruling H-8 owes the one-line test) and
**C-R3 is now a code fact for an accepted run** (ruling H-1), leaving only
its interface item. The two terms the toy counted at 2^-241.42 and 2^-484.83
are **not deleted but re-priced** (ruling H-4): under the ideal-compression
reading what remains of them is the tag-key-collision row, `C(12,2)·2^-256 =`
2^-249.96, now in §6.2's table and zero today by test. And the model that
does that re-pricing is **stronger than D19 as Victor accepted it**, which is
why it goes to him as **D19b**; §7.3 item 1 records that this was the
weakest step on the page and how it was ruled.

---

## 7. The step table, what to attack first, and what this is not

### 7.1 Every step

| # | step | label |
|---:|---|---|
| 1 | the inventory of every hash object a run publishes, in transcript order, with its function, layout and length (§1.2) | **VERIFIED IN THE CODE** |
| 2 | the counts of trees, leaves, salts, paths, tags and framing at three configurations (§1.3, §3.4) | **COUNTED** (§8.1; seven controls reproduce published figures first) |
| 3 | the run statement file is part of the published view and adds no new hash object (§1.2, N2) | **VERIFIED IN THE CODE** |
| 4 | only the `4L+1` roots are absorbed; salts, paths, tags and the binding influence no challenge (N3) | **VERIFIED IN THE CODE** |
| 5 | the model: BLAKE3 as a family indexed by mode and key (D19a), with conventions V-1 (indifferentiability) and V-2 | **ASSUMED** — **CHANGED**: the *form* is what the argument uses; the *justification* is an **ideal compression function at an adversary-chosen chaining value**, stronger than D19 as accepted, and **PROPOSED as D19b** (ruling H-4) |
| 6 | three of the toy's length arguments become unnecessary; two counted terms are **re-priced**, not deleted (N4) | **PROVED HERE**, inside step 5 — and it is a *simplification*, not a strengthening. **CHANGED** (H-4): their price is the tag-key-collision row, now in §6.2 |
| 7 | inside F_U, 40 bytes is unoccupied on a run's path, so the generator stream is unreachable (N5) | **COUNTED**; load-bearing **because** the stream is the UNKEYED function (ruling H-3) |
| 8 | inside F_T, 47 is unoccupied — but the 125M run profile is one byte away and nothing checks it (N6, **F-2**) | **COUNTED** + **CONDITION C-R2** + ruling **H-8**'s one-line test, **owed on the lane** |
| 9 | key-collision and tag-key-equals-generator-key terms (N7) | **COUNTED** — **CHANGED**: `m = 12` tag keys exist at `8c5922b`, `C(12,2)·2^-256 =` 2^-249.96, and the pairwise-distinct test is owed over all twelve (H-4) |
| 10 | cross-profile and cross-run separation: the transcript domain, the run binding, the context digest (N8) | **VERIFIED IN THE CODE**; the context is **CONDITION C-R4** |
| 11 | **Lemma H^run** | **PROVED HERE**, inside step 5, conditional on Theorem B |
| 12 | opened leaves are a public function of `V` and the published salts, at all `4L+1` openings | **VERIFIED IN THE CODE** |
| 13 | unopened leaves are fresh uniform images; the two ways that fails, each bounded | **PROVED HERE**, inside step 5 |
| 14 | the node induction and the public map `T`, `4L+1` times | **PROVED HERE** |
| 15 | the position tags carry nothing prover-private and are re-derived by the verifier (N9) | **VERIFIED IN THE CODE** |
| 16 | a tag query never coincides with a live challenge query **on the schedule** (§3.5 iii) | **PROVED HERE** (a source reading plus the counter argument) — **NARROWED** (H-7): the non-local case is an F_T state collision and is priced in B6, not 0 |
| 17 | **the trailer of segment `k` is the header tag of segment `k+1`** (**F-1**) | **VERIFIED IN THE CODE** and **MEASURED** on ten bundles (§8.2); **CONFIRMED** independently by the check. **Ruling H-5**: the PROPERTY (no transcript operation between `run.rs:551` and the next `:492`) is pinned, not the coincidence — **owed on the lane** |
| 18 | the binding and the framing are public functions of the published prefix (N10) | **PROVED HERE** |
| 19 | **Route A^run**, the ten-hop hybrid, with the D9 replacement as one hop | **PROVED HERE**, inside step 5, conditional on Theorem B and Lemma H^run |
| 20 | replacing the blinding at once costs the same as stage by stage, and needs G-R4 once instead of `L−1` times | **PROVED HERE** (elementary) |
| 21 | the transcript-function bad events **B1–B10**, four of them impossible | **COUNTED** / **PROVED HERE** — **CHANGED** (H-7): row **B10** (constructor vs absorb) added at −128.00, and B9's "impossible: 0" re-worded |
| 22 | the transcript query count `A` | **MEASURED** at the two rungs (the gate's `final_counter`); **BOUNDED** at 125M |
| 23 | the number of transcript operations does not move with the hidden input | **MEASURED** (dense vs all-zero bundles at both rungs) |
| 24 | no oracle programming is needed; the ideal world is the honest prover on the all-zero chain (N12) | **RELIES ON** D18-A; **MEASURED** at rung-G and rung-K4 |
| 25 | the all-zero chain at 125M | **GAP G-R3, BLOCKING** (ruling R-4), not narrowed here |
| 26 | **the run header commits BOTH hidden endpoint planes before any challenge exists, so "the witness is fixed before the first message" is a CODE FACT for an accepted run** (N11, rewritten) | **VERIFIED IN THE CODE** (`run.rs:316`, `:470`; `private_block.rs:213`, `:686-695`; `protocol.rs:451`) → **CHANGED** (ruling H-1): C-R3 is no longer a hypothesis of the lift; what remains is the **interface item** (make `RunWitnessSource` take the chain at construction) |
| 27 | **Route B^run and condition O-4** | **GAP G-H1** — the lemma is stated, its four hypotheses are named, and it is not closed. **NARROWED in diagnosis, not in size** (disposition §3): hypothesis (ii) is now a code fact, a run is **longer not harder**, and the open work is one paper task — extend the sequential-kernel lemma to (field, hash) message pairs, which closes the toy's O-4 too |
| 28 | the privacy game for a run, and that M-9 is a hypothesis and not a nicety (§5.1, N13) | **ARGUED** — **CHANGED** (ruling H-2): the code side is `#[cfg(test)]` (`private_block.rs:178-179`) and `prove_run` has **no production caller** at `8c5922b`, so M-9 is a rule plus a tested writer and is carried in §7.2 as a **CONDITION**, not a fact |
| 29 | the twelve witness-build refusal sites, re-read at `8c5922b`, none moved | **VERIFIED IN THE CODE** |
| 30 | no published byte of stage `k` exists after a witness refusal at stage `k` | **VERIFIED IN THE CODE** |
| 31 | the residual table and its total | **COUNTED**, conditional on steps 5, 11, 19 and on Theorem B |
| 32 | the many-runs union, and **2^-49.36** at a million twelve-block 125M runs | **COUNTED** — **CHANGED** (H-7, B-9): the first draft rounded 10^6 to 2^20 and printed 2^-49.29 |
| 33 | the sampler draw counts moved with the S19-F1 repair (**F-3**) | **COUNTED**, **CONFIRMED to the draw** by an independent recount — **CHANGED** (H-6): a **third** pinned receipt total moved too, the frozen-seam rung's 4,218,264 → 4,218,600 |
| 34 | the hash layer in the **standard** model | **GAP G-H2** — assumption M-2, a keyed-hiding property of BLAKE3 not implied by collision resistance, with no reduction offered |
| 35 | composition with the **soundness** reduction over the same functions | **GAP G-H3** (the toy's O-7). Under a tag the leaf/node ambiguity L-7 flagged is gone for tagged profiles, which *narrows* it; nobody has checked the rest |
| 36 | a future device commit path | **GAP G-H4** — `hashline/src/pcs.rs:83-97` (`commit_zk_device`) builds **unkeyed** leaves and an **unkeyed** tree. It is called only from `zk.rs:1427` and `:2801`, the legacy feed-forward line, and never from a block or a run; and `commit_zk_owned_with_tag` declines the device whenever a column key is set (`pcs.rs:782-785`). **NARROWED** (H-7, the check's B-11): the function is **`#[cfg(feature = "gpu-cuda")]`** (`hashline/src/pcs.rs:82`), so it does not exist in a build without that feature — which is every build this lane takes; the masking commitment `M` never reaches a backend under either rule — `mask_commit_tagged` (`zk.rs:480-518`) hashes its own columns (`hash_columns_keyed` at `:514`) and the doc comment at `:468-479` says so explicitly, so T-8 has nothing to decline there; and the `HashTag` type makes a partial key set unrepresentable (a private `Rule` enum, `hashtag.rs:64-79`), so "a column key is set" and "the profile is tagged" are the same condition. **Condition C-R5**: no tagged commitment may ever route through it |

**Tally over the 36 rows: 8 PROVED HERE (6, 11, 13, 14, 16, 18, 19, 20),
10 VERIFIED IN THE CODE (1, 3, 4, 10, 12, 15, 17, 26, 29, 30), 8 COUNTED
(2, 7, 8, 9, 21, 31, 32, 33), 2 MEASURED-led (22, 23), 1 RELIES ON (24),
1 ASSUMED (5), 1 ARGUED (28), 5 GAP (25, 27, 34, 35, 36 — G-H1, G-H2, G-H3,
G-H4 and the inherited G-R3).** Cross-cutting: **5 CONDITIONS (C-R1 … C-R5)**,
on rows 8, 10, 26 and 36 and in §7.2 — **and after ruling H-2, M-9 joins them
as a condition rather than a built fact**. None of the eight PROVED rows
is unconditional: every one is either inside the assumed model or downstream
of Theorem B, which is itself a reduction conditional on G-R1, G-R2 and G-R4.
The rows that stand whatever happens to the model are the counting rows and
the two code findings, **F-1** and **F-3**. **Fourteen rows changed in this
revision** — 5, 6, 7, 8, 9, 16, 17, 21, 26, 27, 28, 32, 33 and 36, each
marked CHANGED or NARROWED where it moved. **No row was deleted and no label
softened**, and the one row whose *direction* reversed is **26**.

### 7.2 The conditions an acceptance would have to carry

| # | condition | true today? |
|---|---|---|
| **C-R1** | no F_U input on an accepted run's path is 40 bytes — in particular no public weight set makes the block public-statement digest's input 40 bytes | **TRUE** at all three configurations [COUNTED]; asserted by nothing |
| **C-R2** | no transcript domain on an accepted run's path has length 35 (which gives a 47-byte constructor input, inside F_T's own squeeze class) | **TRUE** at all seven profile strings (constructor inputs 46 / 48 / 51 / 56 / 57 / 58 / 59, none 47; nearest domain length 34); **checked by nothing today** — the completed guard is off for tagged profiles and never saw the run's own domain anyway (**F-2**). **Ruling H-8 owes the one-line test**, after which this row reads "checked" |
| **C-R3** *(RE-SIZED, ruling H-1)* | the whole hidden run input is fixed before the first message | **A CODE FACT for an accepted run**, not an operating condition: the header absorbs binding commitments to the hidden **input and output** planes (`run.rs:316`, `private_block.rs:213`, `:686-695`) before any challenge exists, and `check_endpoints` (`run.rs:470` → `protocol.rs:451`) refuses unless the prover's own owners produce exactly them. It is **computational** (endpoint-commitment binding + the proved chain), where the toy's was syntactic. **What is left is an interface item, not a proof obligation**: `RunWitnessSource` still *permits* an adaptive source, which cannot make an accepted run but can make an aborted one — tighten it by taking the chain at construction when the production caller is written |
| **C-R4** | the 32-byte context inside `ExpectedIo` and inside every boundary spec is a constant of the statement, never derived from a request | true of the tests; a deployment hypothesis |
| **C-R5** *(wording corrected, H-7 / B-11)* | no tagged commitment routes through an unkeyed commit path | **TRUE, and for one more reason than the first draft gave**: `commit_zk_device` is **`#[cfg(feature = "gpu-cuda")]`** (`hashline/src/pcs.rs:82`) and so does not exist in a build without that feature — which is every build this lane takes; `zkp-core/src/pcs.rs:782-785` declines the backend whenever a column key is set; `commit_zk_device` has no caller on this path; and the tag type admits no partial key set, so "a column key is set" and "the profile is tagged" are one condition. The first draft's wording is if anything conservative |
| **M-9** *(promoted from "inherited fact" to CONDITION, ruling H-2)* | the published object is the whole run directory, written only after the whole run verifies; nothing is published on a refusal | the code side is **test-only** (`private_block.rs:178-179`), and `prove_run` has **no production caller** at `8c5922b`. **A rule plus a tested writer**, to be re-imposed on the integrator's production driver when it exists |
| **(new, ruling H-1)** | a production caller seals the endpoints with **the witness builder's own pass**, with its refusals, so an inadmissible chain is refused before the header | **not built** — there is no production caller yet. Costs about nothing (the pass is already paid, §5.3); M-9 stays as the second line |
| (inherited) | D21's capture rule; one opening per commitment (`boundary.rs:269` consumes `self`, `PreparedBoundary` has no `Clone` at `:232-241`); a salt is published iff its column is; fresh OS randomness per run | as recorded in the run disposition |

### 7.3 What the checker should attack first — and how each item was answered

**The five items below are the first draft's, kept verbatim so the record
shows what was flagged. Each now carries the check's verdict and the security
owner's ruling.**

1. **The independence-of-modes assumption doing the work in §2.2.** Two
   counted terms of the toy's bound (2^-241.42 and 2^-484.83) disappear here
   **only** because D19a says F_T, F_L and F_N are independent functions. Is
   BLAKE3's flag separation between "keyed hash with key `K_L`" and "keyed
   hash with key `K_N`" *the same kind* of separation as between its modes?
   It is not: those two are the **same mode** with **different keys**, so what
   is being assumed is not BLAKE3's mode separation at all but that keyed
   BLAKE3 is a PRF/random-oracle family indexed by the key — **with public
   keys**. Convention V-2 was written for a *secret* key
   (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §5.1) and this page reuses it for four
   **public** ones. I flag this myself: **it is the weakest step on the page**,
   and a checker should decide whether D19a as worded licenses it.
   > **ANSWERED — the check's B-4, ruling H-4 (§2.1, §2.2).** The flag was
   > right and the answer is *no, not as worded*: the **form** of D19a is
   > honest and is what the argument uses; the **justification** attached to
   > it ("BLAKE3's own design claim for its modes") is false, because `F_L`
   > and `F_N` are the same mode under different published keys. The honest
   > model is an **ideal compression function at an adversary-chosen chaining
   > value**, which is **stronger than D19 as put to the project owner** and
   > goes to him as **D19b** (recommendation accept). And the two terms are
   > **not deleted but re-priced** into the `C(12,2)·2^-256 =` 2^-249.96
   > tag-key row, now in §6.2 and zero today by test. **Nothing accepted
   > rests on the stronger model and nothing measurable moves.**
2. **Route A's hop G_6 → G_7 in the presence of the position tags.** The tags
   are F_T squeezes at points the live chain does not use, and they are
   replaced by uniform values along with the challenges. Does the verifier's
   *equality check* between its own recomputed tag and the header survive that
   replacement in every hybrid, including the ones where only some challenges
   are replaced? I claim yes because prover and verifier read the same `ρ`;
   a checker should build the hybrid explicitly for `L = 2` and confirm.
   > **STILL OPEN as an item for a future checker.** The check found no gap
   > in Route A^run's ten hops and disposed of the tag question at B-6 (a
   > tag's two points are not both a priori fixed, §3.5 iii as corrected),
   > but nobody built the explicit `L = 2` hybrid. The item stands.
3. **C-R3, and whether it is really only an operating condition.** Attack it
   from the adversary's side: construct a driver that chooses block 2's input
   as a function of segment 1's bytes and show what it learns. If the answer
   is "nothing, because segment 1's law is already witness-free", then C-R3 is
   weaker than this page says and the page should be corrected. I could not
   see how to make that argument, because the per-`ρ` hypothesis is applied at
   a `ρ` the adaptive choice can see.
   > **ANSWERED, and the page IS corrected — the check's B-1, ruling H-1
   > (§4.4).** C-R3 is weaker than the first draft said, and by a route the
   > draft did not consider: not "segment 1's law is already witness-free",
   > but **the header has already committed both endpoint planes**, so an
   > adaptive driver cannot produce an *accepted* run at all. The adaptive
   > driver of the attack can only produce an *aborted* one. C-R3 is
   > re-sized to an interface item (§7.2).
4. **The 125M transcript-query bound.** `A ≤ 182,828` rests on an unmodelled
   allowance of 1,024 definition draws per stage. Nothing turns on it above
   2^-110, but if the real figure were 100× larger the pre-query term would
   move to 2^-103.8, still 34 bits below D9. Check that the allowance is
   generous by counting one slot's definition draws at 125M.
   > **ANSWERED — the check's B-10 (§1.3).** The allowance is generous by
   > about **2.1×**: 325.0 unmodelled slot-definition draws per stage at
   > rung-G and 328.0 at rung-K4, measured against the gate's
   > `final_counter`, scaled 1.49× by the slot variable count to ~485 per
   > stage at 125M, against the allowance of 1,024. Even a 100× error leaves
   > the pre-query term at ~2^-103.8, 34 bits below D9, exactly as the draft
   > said.
5. **The absorb count.** 1,129 / 1,138 / 5,932 is this page's model of the
   code's absorb sites and is ~~validated by nothing~~ — the gate measures
   squeezes, not absorbs. It enters only `C(A,2)·2^-256`.
   > **RETRACTED — the check's B-10, ruling H-7 (§1.3).** "Validated by
   > nothing" is withdrawn. The check reproduced **all three exactly** by a
   > different route — the capture bundles' public `transcript_program`
   > field, the pinned layout models, and the measured per-role opening
   > group counts — in
   > `results/zk60_hash_layer_fs_lift_run_check/absorb_count_validation.py`.
   > Two independent derivations, agreeing on all three configurations, with
   > the one free parameter fixed by measurement.

### 7.4 What this is not

* **Not a privacy acceptance, and no privacy claim about any run.** D22 covers
  the toy block alone and bars every run by name.
* **Not a closing of G-R5.** It writes (H6^run) and Route A^run; **G-H1
  (= O-4) stays open** — and after the disposition's §3 it is open for the
  toy and for a run in the same way and for the same single reason, with
  the extension of the sequential-kernel lemma to (field, hash) message
  pairs named as the next paper task. Theorem B's own gaps G-R1, G-R2, G-R4
  and, at 125M, the blocking G-R3 are untouched.
* **Not a ruling on the model.** The ideal-compression justification behind
  D19a (§2.1) is **proposed to the project owner as D19b** and is not
  accepted. **Nothing accepted rests on it**: no tagged profile has a
  privacy statement, and D22 — the toy block — rests on the *untagged*
  profile and on D19 as Victor accepted it.
* **Not a statement about the 125M shape.** Everything at 125M is counted or
  bounded from the code and nothing has been measured there.
* **Nothing about timing, memory or power** (D20), nor about the refusal
  string beyond M-9's rule.
* **Soundness is untouched**; G-H3 remains.
* **D8 and D11 are untouched.** Under a root fixed in advance by a third party
  the ideal world would need oracle programming and Lemma H^run would be the
  wrong tool (§4.6).
* **Nothing was built, proved, verified or benchmarked.** Every [MEASURED] is
  the lane's or the gate's, attributed at the figure.

---

## 8. Evidence

### 8.1 `results/zk60_hash_layer_fs_lift_run/run_hash_counts.py`

Exact integer / `Fraction` arithmetic, no dependencies, under a second, output
in `run_hash_counts.json` beside it. It reads no capture, no witness, no salt
and no private plane; every input is a geometry constant quoted from a named
source line at `8c5922b` in the file's own header.

**Seven controls, all exact, run before anything new is computed:**

| control | reproduces |
|---|---|
| C1 | the toy's 12,288 salts; `Σ L_s = 583`; **327,052** `fp()` draws (A 178,432 + H 124,928 + H zero-sum 510 + M 17,038 + endpoints 6,144) — decision D9's ruled figure **to the draw** — and 2^-77.68 |
| C2 | the toy's tree tables to the displayed digit, both rows |
| C3 | 686,990 / 8,704 / 7,424 and 2,093,226; 9,029,742 / 108,032 / 91,392 and 109,728,040; `Σ L_s = 1,208`; 2^-69.29 — all with the **pre-repair** schedule, which is what the run memo counted |
| C4 | **2,473,984** salts at 125M `L = 12` |
| C5 | **3,328** opened columns of a three-block run |
| C6 | 2^-118.4 per block and 2^-114.8 at `L = 12` (ruling S-4) |
| C7 | the gate's measured `final_counter` 6,918 / 6,924 / 6,924 / 7,686 / 7,686 on five bundles, from `challenges_checked + 64(4L+1)` |

Its limits, stated: the tree figures are **expectations** over the index draws
(the realised distinct counts on real bundles are 243–251 of 256, so the
realised numbers move by a few per cent); the squeeze figure at 125M is a
**bound**, not a count; the absorb figure is a model of the code's absorb
sites, **now validated by a second, independent derivation** (the check's
B-10 — the first draft said "that nothing validates", and that clause is
withdrawn); and it proves nothing — it evaluates the formulas this page
derives.

**Its whole output has since been reproduced independently.** The check's
`results/zk60_hash_layer_fs_lift_run_check/` — README, four scripts, four
outputs, one JSON, exact integer / `Fraction` arithmetic, no dependencies —
re-derives the draw counts, `N_leaf`, the residual table, the many-runs row
and the tree-occupancy table **from the Rust and not from this page**, plus
F-1 on all ten bundles, the constructor-length table, the absorb count by a
second route and control C7 on all six gate bundles. Two figures of this
page moved as a result (§1.3's two revealed-node totals, B-12b) and two were
corrected (§6.3's many-runs row, B-9; §6.2's new rows). Everything else
reproduced exactly.

### 8.2 `results/zk60_hash_layer_fs_lift_run/tag_identity_check.txt`

The one data check: finding **F-1**, over the ten run-capture bundles at
`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-*`.
It reads only the `start_tag` and `end_tag` members of each `stage-*.json` —
public transcript positions the verifier re-derives and compares. All ten
bundles, at **two run profiles** and two hash rules: `end_tag(k) ==
start_tag(k+1)` for every `k`, 6 tag fields carrying 4 distinct values.
*(Corrected, B-12a: the first draft wrote "three shapes". The ten bundles are
`private-run-rung-g-t24-dev/1` (a–h) and `private-run-rung-k4-t24-dev/1`
(i, j), **all at `L = 3`**; the two hash rules are right — a–d legacy, e–j
`blake3-keyed/1`. The same correction applies to §3.5's F-1 wording.)*
**CONFIRMED independently** by the check's own script on the same ten
bundles, which also measured that `start_tag(0)` differs between bundles of
one profile that differ only in the hidden input — the clause added to
§3.5 (ii).

(The run capture is `#[cfg(test)]` throughout — `run.rs:638-639`, `:664-696`,
`:768-769` — and is on no production path; ruling D21 governs what a retained
bundle may contain, and this check read two published transcript positions per
stage and nothing else.)

### 8.3 Figures quoted and not re-derived here

The run gate's own `challenges_checked` (6,086 / 6,092 / 6,854),
`final_counter` (6,918 / 6,924 / 7,686) and `columns_authenticated`
(3,328 of 3,328, under the shape's own keys, and **0 of 3,328** under another
shape's keys in both directions) are the lane's measurements, read from
`/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_{tagged,s20,k4}/*.json`.
The pinned layout models `MODEL_TOY` / `MODEL_RUNG_G` / `MODEL_RUNG_K4` /
`MODEL_M125` are read from `grow_tests.rs` at `8c5922b`.

---

## 9. The circularity check

An entry in the last column is a red flag. There is none; what there are
instead are the declared premises below.

| step | assumes | which step concludes it | circular? |
|---|---|---|---|
| §1 the code facts and the length tables | nothing but the source | — | no |
| §2.1 the model | nothing; it is the assumption. **Since ruling H-4 its justification is named too — an ideal compression function at an adversary-chosen chaining value, stronger than accepted D19, proposed as D19b** | — | no (it is **declared**, and now declared in full) |
| §3.1 the factorisation `law(V,H) = law(V)·law(H\|V)` | nothing; the definition of conditional probability | — | no |
| §3.1 Theorem B | the run composition memo's accepted reduction, with its four open gaps | concluded **elsewhere**, and its gaps are named at every use | no |
| §3.2–3.3 Lemma H^run at a fixed `ρ` | that `ρ` is **exogenous** — the interactive experiment | §4.2 concludes the real `ρ` behaves like a uniform exogenous one. **Not circular**: the lemma is proved **for every** fixed `ρ` with no assumption about how `ρ` arose (∀ρ ∃T, never the reverse) | **no** — the row to look at twice |
| §3.3 step 2, the unopened leaves | that the salts are uniform and secret | **M-3 (ruling C-3) assumes it**, primary; §6's in-model derivation concludes it as the labelled alternative, using F_U at 40-byte inputs, the refills' non-adaptivity and the key's secrecy — none of which uses Lemma H^run | no |
| §3.5 the tags | that the transcript state is a function of the published prefix | §1.2's absorb list; and the verifier's own re-derivation is the code's proof of it | no |
| §4.2 Route A | B1 (the counter), the function split (§2.1), the refills' non-adaptivity, and the D9 replacement | each established independently and earlier | no |
| §4.2's conclusion | "up to the refusal conditioning of §5" | §5 closes it, and §5 uses Route A's uniformity. **Not mutually dependent**: Route A's equivalence of experiments is a statement about the whole run, refusal or not, and §5 then splits on an event | no |
| §4.5 Route B | the branch lemma and independence of the challenge function from the prover's randomness | the second **is** D19a, declared at §2.1; the first is declared open. **C-R3 is no longer on this list** (ruling H-1): hypothesis (ii) is a code fact for an accepted run | no, but it is **GAP G-H1** |
| §6 the sum | every row above | — | no; it is correctly last |

**The declared premises, which must travel wherever this page is quoted.**

1. **D19 and D19a are proposed for a run, not accepted** — and after ruling
   H-4, **D19a's justification is a strictly stronger assumption than D19 as
   the project owner accepted it**, proposed to him as **D19b**
   (recommendation accept). §2.1 states it; §7.3 item 1 records that it was
   flagged as the weakest step and how it was ruled.
2. **Theorem B is a reduction with four open conditions**, one of them
   (G-R3) blocking at 125M.
3. **Route B — condition O-4 — is not closed**, at the toy or at a run. A run
   adds **no** hypothesis to it (ruling H-1, correcting the first draft): it
   is longer, not harder, and the single open item is the extension of the
   sequential-kernel lemma to (field, hash) message pairs, which is the next
   paper task and closes the toy's O-4 at the same time.
4. **The generator is carried under M-3 (ruling C-3)**, now over one stream
   feeding 47 of 49 commitments; the in-model alternative costs conventions
   V-1 (indifferentiability, **ASSUMED**) and V-2. Its stream is the
   **unkeyed** BLAKE3 function over a 40-byte input (ruling H-3), which is
   why §2.3's length argument is load-bearing.
5. **Conditions C-R1 … C-R5 are enforced by almost nothing**, and C-R2 is
   enforced by nothing at all because the completed length guard is switched
   off for tagged profiles and never saw a run's own transcript domain —
   until ruling **H-8**'s one-line test lands. **C-R3 is now a code fact for
   an accepted run** (ruling H-1) and only its interface item is owed.
6. **M-9 is a condition, not a built fact** (ruling H-2): the run-statement
   writer is `#[cfg(test)]` and `prove_run` has no production caller at
   `8c5922b`, so the object the privacy game is defined over does not exist
   in a production build. **And a production caller must seal the endpoints
   with the witness builder's own pass** (ruling H-1).

**Three tests and one register entry are owed on the lane**, and none of them
is in this page's gift: the pairwise-distinct key test extended to all twelve
tagged-profile keys (H-4); the property test that no transcript operation
falls between a segment's end tag and the next start tag (H-5); the one-line
test that no registered profile's constructor input has the squeeze length
(H-8); and register entry **D19b** with its recommendation (H-4).

**One shape of over-claim this page must not be read into.** No sentence here
may be read as a statement about BLAKE3. Steps 6, 11, 13, 19 and the whole of
§6's hash-layer rows are statements *inside* a model that is a proposed
ruling, and the two terms the tag deletes were counted before and are now
**re-priced** into the tag-key-collision row rather than assumed away.

---

## 10. What the check changed

One line per finding of `ZK60_HASH_LAYER_AND_FS_LIFT_RUN_CHECK.md`, as the
security owner's disposition ruled it. **Nothing that survived the attack
has been softened, and no gap has been deleted.**

| # | the check's finding | what changed here | ruling |
|---|---|---|---|
| **B-1** | §4.4 / C-R3 — "a run's hidden input is not fixed before the first message" is **false of the code the draft itself transcribed** | §4.4 **rewritten**: the header absorbs `expected-IO` with both endpoint roots before any challenge, `check_endpoints` refuses anything else, the prover has already run the whole forward pass. "Harder, not merely longer" **struck** from §0, §4.4 and §4.5(ii); C-R3 re-sized to an interface item; R-1.3's pre-pass costing **withdrawn** and a new production-caller rule added (§5.3) | **H-1** |
| **B-2** | §5.1's "the code side of M-9 is built and pinned" describes **test-only** code, and a run has no production entry point | §5.1 carries the correction in full (`private_block.rs:178-179`; no production caller of `prove_run`); M-9 moves into §7.2 as a **condition** | **H-2** |
| **B-3** | the register, the tag disposition §2a and `hashtag.rs:22-33` all say the generator is **keyed**; it is not | §1.1 states the generator exactly and names all three documents as corrected; §2.1's model drops the phantom `F_K` member; §6.1 pins the paragraph. Five BLAKE3 functions; the 40-byte class still load-bearing; the toy statement unaffected | **H-3** |
| **B-4** | D19a's **justification** is not honest, and the model does not delete the toy's two terms — it **re-prices** them into a row the table was missing | §2.1 splits FORM from JUSTIFICATION and proposes **D19b**; §2.2 adds the re-pricing; §2.3's N7 counts `m = 12`; §6.2 carries the new row at **2^-249.96**, zero today by test, with the pairwise test owed over all twelve keys | **H-4** |
| **B-5** | F-1 confirmed; what it is, what it is not, and what should be pinned | §3.5 gains the check's splicing analysis (`wire.rs:430-438`), the clause that the published prefix already commits the hidden input, and the ruling that the **property** — no transcript operation between `run.rs:551` and the next `:492` — is what gets pinned. Owed on the lane | **H-5** |
| **B-6** | B9 is over-stated: a tag query cannot coincide with a live challenge **locally**; the non-local case folds into B6 | §4.3's B9 re-worded to "impossible **on the schedule**"; the non-local state collision is named and priced inside **B6**; §3.5(iii) gains the last-stage case (`run.rs:573`), the output-opening ordering and the note that a tag's two points are not both a priori fixed | **H-7** |
| **B-7** | constructor-versus-absorb is treated nowhere, and F-2's own size argument is right for the wrong stated reason | §4.3 gains row **B10** at `(A + q)·2^-256 = ` **2^-128.00**; §2.3's "≥ 60 on this path" corrected to the layout minimum **48**, and the "not a probability but a deterministic property" clause **struck** in favour of the two-conjunct statement | **H-7**, **H-8** |
| **B-8** | F-3 is right and **incomplete**: a third pinned receipt total moved | §6.2's F-3 gains the full three-configuration draw table with the pre-repair controls, and the **frozen-seam rung 4,218,264 → 4,218,600** (`grow_tests.rs:351`), the third of the D19 disposition's four totals to move | **H-6** |
| **B-9** | §6.3's many-runs row rounds 10^6 to 2^20 | §6.3's table corrected to **−55.07 / −49.36** (and −96.90 / −94.90, −185.74 / −174.66, −92.37 / −86.83), with the first draft's figures shown for the record. "About 2^-49" survives | **H-7** |
| **B-10** | a retraction the draft is owed: its absorb count **is** validated — and §7.3 item 4 is answered | §1.3 carries the second derivation (1,129 / 1,138 / 5,932 by the capture's `transcript_program` plus measured group counts) and the sized allowance (~485 vs 1,024 per stage, **2.1× generous**); §7.3 items 4 and 5 are answered and item 5's self-flag **retracted**; §8.1's limit line corrected | **H-7** |
| **B-11** | C-R5 / G-H4 is true, and true for one more reason than the draft gives | §7.1 row 36 and §7.2's C-R5 gain the **`gpu-cuda`** feature gate (`hashline/src/pcs.rs:82`), the fact that `M` never reaches a backend under either rule, and the unrepresentability of a partial key set | **H-7** |
| **B-12** | six smaller corrections | **(a)** "three shapes" → **two run profiles**, all `L = 3` (§8.2, §3.5); **(b)** revealed-node totals **27,770.6 / 179,358.3** (§1.3); **(c)** the S-4 row is the **one-sided** figure, §5.2's discharge uses twice it (§6.2); **(d)** the absorb bound that matters is **≥ 48**, not ≥ 60 (§2.3); **(e)** the 31 bytes of `b"hashline/private-block-public/1"` named at `private_block.rs:514` (§2.3); **(f)** a tag's 32 bytes carry slightly **under** 256 bits (§3.5) | **H-7** |

**What the check confirmed and this revision therefore did NOT touch:**
Lemma H^run and its four proof steps; Route A^run, its ten hops and their
order; Claim N3 (only the `4L+1` roots are absorbed); the twelve witness-build
refusal sites; every residual figure and the 37-bit gap (37.30 / 37.42 /
37.47); the privacy game's shape and §5.3's treatment of the abort
distribution; and F-1, F-2 and F-3 as findings. **The conditional statement
holds, with the changes above.**

**Citations found out by a line or two while re-reading them at `8c5922b`,
beyond the check's list**, and corrected in place. In this page:
`hashtag.rs:48-56` → `:47-53` and `:95-104` → `:92-101` (§1.1);
`hashtag.rs:96-103` → `:95-98` (§1.1's `F_D` row);
`all_eight_keys_are_pairwise_distinct` at `:206-221` → `:206-220` and
`the_four_keys_of_each_tagged_profile_are_pinned` at `:188-203` → `:188-200`
(§2.3, §6.2). **And two in the check itself**, adopted here in their
corrected form: `prepare_endpoints` is at `private_block.rs:743-764` (not
`:744-765`) and `compute_output` at `:770-772` (not `:771-773`); and the
check's *"the only caller in the tree"* of `witness::build_shaped` is
narrowed to **"its only caller on the run's path"** — `git grep build_shaped`
over `hashline/src` at `8c5922b` returns many callers, all in `#[cfg(test)]`
modules, which does not disturb the argument (`Chain::from_parts` is the
run's). **None of these changes a claim.**
