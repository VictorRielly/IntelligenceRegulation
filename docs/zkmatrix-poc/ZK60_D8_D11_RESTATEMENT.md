# ZK60 — the D8/D11 obligation stated as a game, and a costed survey of ways to meet it (NOT a discharge)

**Status: CORRECTED AFTER INDEPENDENT CHECK — NOT accepted as the project's position, per `ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` (security owner, 2026-09-19). D8 and D11 stand as written in the register. This page states the obligation and surveys routes with their costs; it recommends no reduction. Corrections of `ZK60_D8_D11_RESTATEMENT_CHECK.md` applied. Drafted by a delegated Opus agent.**

## Where this stands after ruling D18

For the first MVP the prover generates every commitment at proof time (D18,
`ZK60_DECISIONS.md:582-617`). So the configuration D8 and D11 bind — somebody
other than the prover fixing a commitment in advance — **does not arise in the
first MVP's artifacts**, and the standard privacy game, in which the simulator
produces the commitments, is the one that applies to them. That is all it
says. It is **not** a privacy acceptance: the joint-view checks remain what
they are, and U-3 remains open.

The obligation binds from the day a third party fixes a commitment in advance.
The route the project expects to take then is the **sealed handle**: a salted
hash of the plane, checked inside the proof against a **fresh
prover-generated** commitment. It is scoped separately in
`ZK60_SEALED_HANDLE_SCOPING.md` (commissioned 2026-09-19).

Durable facts the independent check confirmed: in today's code **the committer
is the prover**; the two-point simulator has **no ordering problem**; the
hash-layer counts of §3.3 **reproduce**; separately finished private proofs
**cannot chain through a commitment root**; the transcript and the Merkle and
leaf hashes **share an untagged 64-byte BLAKE3 domain**; and D9's figures are
exact — **statistical distance 2^-96 per draw, per-outcome relative bias
2^-64**.

| | |
|---|---|
| Author | delegated Opus researcher-drafter, working for the security owner |
| Baseline | working tree at `perf/zk-batch-optimizations`, `db5ee01`, 2026-09-19 |
| Scope | the custom (hashline) line only. The zkVM line's D7 profile is referenced for contrast, never as evidence about this line |
| Status | a restatement, an inventory of what is settled, a counted analysis of the hash layer, and five candidate closures with costs. No privacy property is established here |
| Reads | nothing was built, run, tested or benchmarked for this document |

---

## 0. For the project owner: what this is about, in plain words

The product promise (D1) is that a regulator can check a proof that an
approved model produced an answer, **without learning the prompt or the
answer**. To make that checkable, the prompt and the answer are each put in a
**sealed envelope** whose outside is a 32-byte fingerprint called a **root**.
The root is public; the contents are not. The proof says: "the model,
applied to what is inside envelope A, produced what is inside envelope B."

For the proof to be checkable the prover must show the verifier *some* of the
envelope. The custom prover does this by opening **256 randomly chosen
windows** into each envelope. Each window shows a strip of scrambled numbers,
a 32-byte random **salt**, and a short chain of 11 fingerprints (an
**authentication path**) proving that this strip really is part of *that*
root. The scrambling is designed so the 256 strips look uniformly random
whatever is inside — that part is analysed and, on real receipts, measured
(§2.5). The 32-byte fingerprints are not analysed at all. That is the gap.

The open obligation, recorded as decisions **D8** and **D11**, is the standard
cryptographic test for "reveals nothing": a **simulator** — a program that
does *not* know what is in the envelope — must be able to manufacture a fake
receipt that nobody can tell apart from a real one. If such a program exists,
the real receipt cannot be leaking anything, because the fake one contains no
secret to leak. For the numbers in the receipt, the project has a long way
towards this. For the **fingerprints**, the simulator faces a wall: it must
produce authentication paths that add up to a root **somebody else chose**.
That is exactly what a fingerprint is designed to make impossible.

There are only three ways out, and §3.6 proves it is only three:

1. Make sure the root has **never been opened before** and give the simulator
   one free "let this fingerprint come out however I want" move, which is a
   standard and widely used modelling assumption (the *random-oracle model*).
   This is the cheapest route, and the first version of this page proposed
   restricting the obligation to it. **That reduction was attempted and
   refused** (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §1): it is circular —
   the restriction that is supposed to make the case safe simply states the
   conclusion — and it protects the hidden value against everyone **except
   the party who sealed it**, which is the party D8 is named for. The refused
   attempt is kept below, as a record of what does not work and why. It only
   ever applied to a root with no earlier opening, and it would have meant
   changing what the project promises about roots.
2. Make the root something the **prover generates fresh inside each proof**,
   and have the caller refer to the hidden data by something else — the
   **sealed handle**. This is what the other proving line already does (D7,
   salted SHA-256 handles), and D18 records it as the approach the product is
   expected to use. On the custom line it costs a proof that the two
   references agree, and §4.2 counts that cost: about **+5.5 % of a public
   pass and +12.6 % of a private one** — a relative cost that scales with the
   pass, not a fixed slice of the speed budget. The first version of this
   page called it "bigger than the entire speed budget", which compared a
   figure derived from today's pass against tomorrow's target; that is
   withdrawn (§4.2). It still needs a hashing gadget that does not exist.
3. **Never publish the opening at all** — check the envelope inside the proof.
   That is the zkVM line. It is correct and it is roughly 10^4 times too slow
   to be the product (D2).

Nothing in this document settles D8 or D11; they stand exactly as written in
the register. §5 sets out the theorem the refused route would have needed, the
proof obligations that remain whichever route is taken, and what result would
kill each of them.

---

## 1. The obligation, restated exactly

### 1.1 The objects

**Terms, each on first use.** A *plane* is the rectangular block of integer
words that carries one hidden activation (the block's input `x_in` or its
output `xres2`). A *commitment* is a short public value that pins down a
plane without revealing it. *Hiding* means the commitment reveals nothing
about the plane; *binding* means the committer cannot later claim a different
plane. An *opening* is the prover's public evidence that some stated fact
about the committed plane is true. The *random-oracle model (ROM)* is a
proof technique in which the hash function is replaced by an idealised random
function; *programmable* ROM additionally lets the simulator choose the
oracle's answer at points that have not yet been queried. A *simulator* is
the program of §0 step 1; a *distinguisher* is the adversary that tries to
tell the real receipt from the simulated one.

**The endpoint commitment, exactly as built.** `private_seam::prepare`
(`hashline/src/private_seam.rs:186`) builds it:

| item | value at the tiny (pinned) shape | source |
|---|---|---|
| plane | 512 field words (`rows = 32`, `cols = 16`) | `zk_ffn_fresh_io.rs:40-42` (`SeamSpec::new(context, 32, 16, scale, …)`) |
| message columns `n` | 256 (`LOG_COLS = 8`) | `private_seam.rs:28` |
| data rows | 2 = `ceil(512/256)` | `private_seam.rs:106-108` |
| mask rows | 5 (`MASK_ROWS`): two terminal-mask rows, three proximity rows | `private_seam.rs:36`, `:216-217` |
| commitment rows | **7** | `private_seam.rs:109-111`; pinned in the policy at `zk_ffn_fresh_io.rs:58-68` and re-checked at `private_block/protocol.rs:184,250` |
| pad symbols per row `Q` | 256 (`ZkOpts::standard` sets `q_pad = num_col_checks`) | `zkp-core/src/pcs.rs:543`; refused below that at `:670` |
| inverse rate | 8 (`INV_RATE`) → encoded columns `nn = 2048` | `private_seam.rs:30`; `pcs.rs:50-52` |
| opened columns | 256 (`CHECKS`), drawn **with replacement** | `private_seam.rs:29`; `transcript.rs:119-131` |
| leaf | `blake3(blake3(column bytes) ‖ salt)`, salt = **32 bytes** | `pcs.rs:137-143` (`hash_column`), `:640-645` (`salt_leaf`), salts drawn at `:674` as `rng.bytes32()` |
| Merkle node | `blake3(left ‖ right)`, **no tag, no length frame** | `zkp-core/src/merkle.rs:14-19` |
| tree | 2048 salted leaves, **11 levels of siblings** | `pcs.rs:689-690`; `merkle.rs:22-35`, path length `merkle.rs:46-54` |

The published root is `Commitment { root, rows: 7, log_cols: 8 }`
(`private_seam.rs:150-152`). The whole of what the verifier is handed about
one endpoint is that root plus one `OpeningZk`
(`pcs.rs:567-573`): two group vectors of 512 `Fp2` values, one proximity
vector of 512 `Fp2` values, and 256 tuples `(column index, 7 field words,
32-byte salt, 11 sibling digests)`. That is
`ENDPOINT_OPEN_BYTES = 2·512·16 + 256·(8 + 7·8 + 32 + 11·32) = 131,072`
bytes per endpoint (`zk_ffn_fresh_io.rs:15`), 256 KiB for the pair.

### 1.2 The timeline: who fixes what, and when

1. The endpoint owner calls `prepare_endpoints(spec, input, output)`
   (`zk_ffn_fresh_io.rs:109`; siblings `private_block.rs:375`,
   `private_attention.rs:220`). This draws **fresh OS entropy**
   (`private_seam.rs:196`, `ZkRng::from_os(DOMAIN)`), commits both planes,
   and returns a public `ExpectedIo` and a private, non-`Clone`,
   non-serialisable `Endpoints`.
2. The two roots become the statement. `ExpectedIo::to_bytes` is a **112-byte**
   record: `b"HFFNEXP1"` (8) ‖ context (32) ‖ `input_scale` (4) ‖
   `output_scale` (4) ‖ input root (32) ‖ output root (32)
   (`zk_ffn_fresh_io.rs:76-85`). Those 112 bytes are absorbed into the
   transcript **before any challenge exists** (`:138-146`), so both roots are
   fixed before the columns that will be opened are chosen.
3. The prover runs `prepare` (`:148`) and then
   `PendingProof::finish(endpoints)` (`:276`), which consumes the owners on
   success *and* on failure (`:274-277`) and emits the receipt.
4. The verifier runs `verify` (`:412`), rebuilds the transcript from the
   112 bytes alone, and checks the 256 openings per endpoint against the root
   it was given (`pcs::verify_zk`, `pcs.rs:947`, Merkle check at `:1018-1021`).

**The asymmetry that creates the obligation.** The verifier accepts *any*
well-formed 112 bytes — `ExpectedIo::from_bytes` (`:86-100`) validates only
length, magic and the seam spec, and the doc comment at `:47` says so
explicitly. The honest prover, by contrast, can only prove for roots **it
just generated**: `check_endpoints` (`:258-270`) refuses unless the owner's
own commitment roots equal the policy roots. This is O9's finding **F2**
(`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:152-157`). The statement the
verifier checks is therefore strictly larger than the statement the prover
can produce, and zero knowledge is a property of the *statement*.

### 1.3 What "prior public history" can physically be in this system

D11 says prior authentication/hash history "remains in scope"
(`ZK60_DECISIONS.md:283-296`) but does not enumerate it. Enumerated:

| # | Candidate history about root `R` | Physically reachable today? |
|---|---|---|
| **H0** | Nothing at all; `R` first appears with the receipt that consumes it | Yes — the default path |
| **H1** | `R` alone published earlier (a policy record, a registry entry, an earlier message), with **no** opening | Yes. Harmless to the one-point construction: publishing an *output* of the oracle blocks nothing, because programming needs a fresh *input* (§3.5) |
| **H2** | Public metadata pinned beside `R`: `rows = 7`, `log_cols = 8`, the two scales, the context digest | Yes, and it is inside the absorbed 112 bytes. It is public parameter data, not oracle history |
| **H3** | A previously published **authentication path** under `R` (any one of them; the last sibling plus the recomputed child *is* the honest top pair) | **Only via a second opening of the same commitment.** Structurally unreachable — see §1.5. This is the history that killed the round-2 closure |
| **H4** | A distinguisher oracle query at the honest top pair `l‖r` | Requires already holding `(l, r)`, i.e. H3, or the committer's salts, or a `2^-256`-per-try guess |
| **H5** | A distinguisher oracle query at any other node or salted-leaf input of the honest tree | Same: requires the salts or the encoded columns |
| **H6** | Application side information about the plane's *contents* (e.g. "the answer is one of 32 values" — the qualifier already written into D7 for the zkVM line, `ZK60_DECISIONS.md:242-247`) | Yes, always. It is not hash-layer history; it bounds what *any* hiding commitment can buy |
| **H7** | A **different** commitment to the same plane, with independent randomness, opened by another proof | Yes, and it is exactly what route (iii) would create. It is a *data-channel* correlation, not hash-layer history: the two trees share no oracle point except by `2^-256` accident. Its field-layer status is **measured, not unexamined**: round 23 ran the two-proof joint analysis and reports zero disclosed base dimensions over 88,064 shared data unknowns, four with every private commitment added (exactly the two public `H` LogUp identities), and 256 in the single-mask ablation control (`ZK60_ROUND23.md:58-65`) — at **fixed coefficients, on two captures, field channels only**, explicitly excluding the CFS, pad, encoded-column and Merkle channels and adaptive composition (`:67-71`), and explicitly not covering commitment reuse or an arbitrary number of proofs |
| **H8** | A **rejected-but-emitted** receipt under `R` — `finish` has "No equality precheck" (`zk_ffn_fresh_io.rs:256-257`; same comment at `private_block/protocol.rs:256-257`), so a proof against a mismatched witness is fully built and emits 256 genuine authentication paths before the verifier's polynomial identity rejects it | **Yes, today, with no new interface.** It is a published path set under `R`, i.e. H3-grade history. The consuming owner means no *second* opening follows, but the bytes are out. Added after the independent check; §1.5 noticed it and the first version of this table omitted it |
| **H9** | A **retained capture** — `native_capture.rs:275-281` writes each accepted receipt, its 112-byte policy and its JSON to disk, and the joint-view lane reads those files | **Yes.** A retained capture is a published opening of its two endpoint roots. Today each capture uses fresh roots, so one path set per root still holds; but any "first published with the consuming proof" rule must count writing a capture as publishing, or the project's own evidence pipeline violates it. Added after the independent check |

**The point of the table, as corrected.** The entries that break the
hash-layer argument are **H3, H8 and H9**, and all three are the same thing:
a published path set under `R`. That is why the case split that matters is
not "history / no history" but **"a path set has been published before / it
has not"**, and D8's own correction text already says this
(`ZK60_DECISIONS.md:268-274`).

**But note what that observation is worth, because the first version of this
page over-claimed it.** Saying "the only history that hurts is a prior
opening" is very close to a definition: an authentication path *under `R`* is
by construction a component of an opening of the commitment whose root is
`R` (`OpeningZk.columns` carries `(index, column, salt, path)`,
`pcs.rs:571-572`, and nothing else in the system emits a sibling chain). The
enumeration is useful bookkeeping — and it is not an argument. D11 refuses
the reduction as it was argued in round 2, and the disposition of 2026-09-19
refuses it again in the form §3.7 first gave it; see §1.8 and §3.7.

### 1.4 The three cases the documents conflate

- **Case (a)** — `R` has no prior opening and no prior history at all (H0,
  optionally H1/H2), and is consumed by exactly one proof.
- **Case (b)** — `R` has prior history but still exactly one **published path
  set** in total. By §1.3 this can only be H1, H2, H6 or H7. **A prior
  authentication path is not in case (b): it is case (c).** The documents
  place it in (b) and that is the conflation. Note the unit: it is a
  published path set, not an accepted `finish`. H8 (a rejected-but-emitted
  receipt) and H9 (a retained capture) are path sets too, so they sit with
  case (c) even though neither is a second accepted proof.
- **Case (c)** — a path set under `R` is published more than once. This is
  where the two-opening recovery of §2.1 lives, and it is fatal at this
  geometry.

Three observations follow. **They are bookkeeping, not results, and the first
version of this page wrote them as results** — the disposition of 2026-09-19
(hole 1) records that as the document's central defect:

1. Case (b) as it can actually arise (H1, H2, H6, H7) does **not** touch the
   hash layer. H1/H2 are public outputs and parameters; H6 is an
   application-level bound on any commitment; H7 lives on a disjoint tree
   (and its field-layer status is measured — §1.3).
2. The "case (b)" the retraction was about (H3) is case (c) in disguise —
   which is true by the definition of an authentication path, not by an
   argument.
3. The hash-layer question that is left is: **is there a simulator for case
   (a) — and is case (c) excluded by something a verifier can rely on?** The
   honest answer to the second half is that a verifier cannot check it from
   the bytes at all; it is a rule about the world.

**What must not be inferred from any of the three.** They do not show that
case (b) is empty. Everything in (b) that would break the construction is
excluded by the restrictions R1 and R2 of §5.2, and R2 *states* that
exclusion. Read as a narrowing of D11 the argument is circular; see §3.7.

### 1.5 What the code enforces, and for which roots

The enforcement of "one opening per commitment", with sources:

| Mechanism | Source | What it forbids |
|---|---|---|
| `PreparedPlane` has no `Clone`, no data getter, no opening method | `private_seam.rs:143-147` | holding two copies of one committed plane |
| `into_ffn_endpoint(self, …)` takes `self` by value and is `pub(crate)` | `private_seam.rs:156` | extracting the `CommittedZk` twice, or at all from outside the crate |
| `Endpoints` has no `Clone`, no serialisation, private fields | `zk_ffn_fresh_io.rs:103-107`; `private_block.rs:367-370`; `private_attention.rs:212-215` | passing the same owners to two provers |
| `finish` / `prove` take `Endpoints` **by value** and consume on success *and* failure | `zk_ffn_fresh_io.rs:276-277`; `private_block/protocol.rs:257`; the `compile_fail` doctests at `zk_ffn_fresh_io.rs:125-131`, `private_block.rs:360-366`, `private_attention.rs:205-211` | a second proof attempt against the same commitment — at **compile** time |
| `private_seam::prove` likewise consumes both planes | `private_seam.rs:335-339` | the standalone seam re-opening a plane |
| `prepare` always draws `ZkRng::from_os`; the seed-injecting `prepare_with_rng` is crate-private | `private_seam.rs:186-198`, `:200` | reproducing the same root twice from the same plane |

**The precise answer to "does code enforce one opening for caller-fixed
roots?" is: for a root the prover generated, yes, at compile time. For a root
the prover did *not* generate, the code enforces something stronger — no
proof is possible at all**, because `check_endpoints`
(`zk_ffn_fresh_io.rs:258-270`, `private_block/protocol.rs:243-253`) requires
the prover to hold a `PreparedPlane` whose own root equals the policy root,
and the only producer of a `PreparedPlane` is `private_seam::prepare` with
fresh OS entropy. There is no import interface, no seed interface and no
serialisation.

The independent check re-walked every path named above, plus the examples,
the release CLI and a grep for `unsafe`, `from_os` and `seed:`, and confirmed
each row. **Five things this does not settle.**

- It is a property of *this crate's public API*, not of the verifier's
  statement. `verify` will accept a receipt for any root; whether some other
  producer could ever exist is a system rule, not a type.
- **What the types enforce is "at most one `finish`", not "at most one
  published path set".** Those are different rules, and the second is the one
  the privacy argument needs. The next two bullets are why.
- A **failed** attempt still emits bytes. `finish` builds the full receipt
  and only the verifier's polynomial identity rejects it
  (`zk_ffn_fresh_io.rs:274-275`: "No equality precheck"). A rejected receipt
  carries 256 genuine authentication paths under `R` — this is H8. The owner
  is consumed, so no *second* opening follows — but if anyone ever adds a
  retry path that re-prepares the same plane **with the same randomness**,
  H3 becomes reachable. Today it cannot, because there is no seed interface.
- **Retained captures publish path sets too** (H9): `native_capture.rs:275-281`
  writes each accepted receipt, its policy and its JSON to disk. Any rule of
  the form "a root is first published with the proof that consumes it" has to
  count a capture as a publication.
- The types do not protect the plane *inside* the crate, and two adjacent
  facts are worth asserting rather than assuming: `CommittedZk`'s `data`,
  `pads` and `salts` fields are all `pub` (`pcs.rs:551-564`), so the
  endpoint's secrecy inside `hashline` rests only on `PreparedPlane.committed`
  being private (`private_seam.rs:146`) and `into_ffn_endpoint` being
  `pub(crate)` and by-value; and the release CLI's `--zk --seed N`
  (`hashline/src/bin/hashline.rs:120`) makes the legacy zk path's `A`/`H`/`M`
  commitments byte-reproducible, which the binary itself flags as "INSECURE
  TEST RANDOMNESS … provides no privacy" (`:178-179`) and which does not
  reach endpoints. Both belong in the mechanical invariant of O4.

### 1.6 The experiment, written as a game

Notation follows O9 (`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:74-135`), which
this section restates and sharpens rather than replaces. `pp` = public
parameters (the profile string, the shape, `log_cols 8 / inv_rate 8 / Q 256`);
`x` = the 48-byte statement part of the policy (magic, context, two scales);
`c_in, c_out` = the two 32-byte roots; `O` = the hash oracle; `q` = the
distinguisher's total oracle queries.

**Game E (the obligation).** The one D8 states.

| phase | real world | ideal world |
|---|---|---|
| setup | `pp` published; `D` may query `O` | same; `S` holds its own state |
| fix | an environment `E` picks the plane values and honest commitment randomness `r` (salts, pads, mask rows) and publishes `c_in`, `c_out`. **`r` is given to neither `S` nor `D`.** `D` additionally receives an auxiliary string `aux` drawn from the history set of §1.3 | identical; `S` receives `(pp, x, c_in, c_out, aux)` |
| prove | the honest prover, holding the `Endpoints`, runs `finish` and publishes the receipt or the refusal | `S(pp, x, c_in, c_out, aux)` publishes a receipt or a refusal |
| output | `D` sees `pp`, the 112-byte policy, the receipt or the refusal string, and all its own oracle answers; it outputs one bit | identical |

`S` is **not** given: any plane value, any salt, any pad, any mask row, any
`PreparedPlane`, or the real `ZkRng` stream. `S` **may**: program `O` at
points that have not yet been answered, and must answer consistently
thereafter. Refusal is an output, not a silent restart (O9 **F6**,
`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:168-173`).

**Game J (joint preparation).** The same, except that the *preparation* is
inside the experiment: `SimPrepare(x, dims)` issues its **own** roots and
keeps its own state, and `SimProve` must then honour them
(`ZK60_ENDPOINT_SIMULATION_MODEL.md:48-64`). Game J covers the honest
workflow completely and covers Game E not at all, because `SimPrepare` chose
the roots.

**Why the "`r` is given to neither" clause is load-bearing, and why it is the
first thing the check struck down.** If `D` holds `r`, it can rebuild the
honest tree, read off the honest top pair `(l, r̂)` with `blake3(l‖r̂) =
c_in`, and detect any programmed second preimage — with probability **1**,
not `2^-256`. No simulator of the present shape survives.

**So the clause decides who may be the adversary, and it excludes the party
who fixed the root** (hole 2). It may be the verifier or regulator that
receives only the 112-byte policy and the receipt, any third party, or a
model owner that did not commit. It may **not** be the committer, or anyone
the committer gave the randomness to. Concretely: *a regulator, user or data
owner who fixes a root by committing the plane itself is excluded from ever
being the distinguisher* — and that is precisely the party D8 is named for.
The dichotomy is unpleasant in both branches. If the **prover** commits — the
configuration all of today's code is in, and the one D18 pins for the first
MVP — then the standard game in which the simulator issues its own roots
(Game J below) covers it and no programming is needed at all. If a **third
party** commits, that party holds `r`, must never be the distinguisher, must
never open the commitment, and in practice must destroy `r` after handing the
plane over. **No document in this repository names such a party**, which is
condition 22 of the check and a ruling only Victor can give.

**The notion this game defines is new and project-specific, and must be
labelled as such** (hole 3). The first version of this page called the
restriction "exactly the restriction in Lyubashevsky–Nguyen–Seiler Definition
2.8" and "the established commit-and-prove notion". **That citation does not
license it.** O9 §5 — this page's own source — maps Def 2.8 the other way:
its ideal-world commitments are produced by `SimCom_ck(x)`, i.e. the
simulator chooses them, which is Game J, not Game E
(`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:227-228`, `:236-239`). Game E under
this clause keeps the commitments environment-produced and demands that the
simulator hit them: strictly harder for `S` than Def 2.8, strictly weaker
than textbook NIZK zero knowledge (which quantifies over all auxiliary
inputs), and a **third, intermediate notion with no source in the record or
in the cited paper**. Any theorem this project states must name it as new,
must carry the excluded parties in the product claim the way D7's three
qualifiers travel with the zkVM claim (`ZK60_DECISIONS.md:242-251`), and must
not describe it as established.

### 1.7 The security notion, and the residual terms already accepted

The notion in view is **computational zero knowledge in the programmable
random-oracle model**, with a statistical core: the field-valued part of the
view is argued statistically (up to the reduction bias below) and only the
hash layer is computational-and-programmable. Statistical ZK is not
available: §3.6 shows a non-programming simulator would break binding.

Residual terms the project has already accepted or recorded, which any
theorem must carry rather than hide:

| term | size | source |
|---|---|---|
| mask/pad reduction bias (`ZkRng::fp` draws 128 bits and reduces mod `p`) | `2^-96` per draw; about **`2^-75`** over a tiny proof, `2^-72.9` at 125M, **`2^-72`** at 8B | **D9, accepted as stated** (`ZK60_DECISIONS.md:370-392`) |
| a further recorded residual at the same shape | about `2^-62` | D9 entry, `ZK60_DECISIONS.md:387` |
| LogUp collision (a witness-dependent refusal event, the one such event in `/2`) | `(lookups + table rows)/2^128` per proof | `ZK60_MVP_JOINT_VIEW.md` §1.2 (branch `zk60-mvp-fable`) |
| PRG assumption on the keyed BLAKE3 prover stream | assumption, not a term | `ZK60_NATIVE_JOINT_VIEW.md` §7 item 7 (branch `zk60-native-jointview`) |
| hash-layer programming freshness | `≤ q/2^256` per programmed point, **plus** the union terms of §3.5 | `ZK60_ENDPOINT_SIMULATION_MODEL.md` "fresh-query bound"; O10 §3 |

**The `2^-64` / `2^-96` question is settled; it is not open.** The first
version of this page offered it to the security owner as a discrepancy. It
had already been ruled on the same day, in **D9's verification note**
(`ZK60_DECISIONS.md:394-408`), and the independent check reproduced the
arithmetic with exact rationals. The two numbers are two different
quantities, not a disagreement: with `p = 2^64 − 2^32 + 1` and a draw a
uniform 128-bit integer reduced mod `p` (`zkp-core/src/rng.rs:72-77`),
`2^128 mod p = p − 2^32`, so the **total statistical distance of one draw
from uniform is exactly `2^-96`** and the **relative bias of a single outcome
is exactly `2^-64`**. A privacy bound sums statistical distances, so the
per-draw term is `2^-96`, and D9's accumulated figures stand: `2^-75.0` at
`2^21` draws, `2^-72.9` at `2^23.1`, `2^-71.7` at `2^24.3`; the 6,144
endpoint draws alone give `2^-83.4`. The document that states it wrongly is
O10 **F10.4** (`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:135-142`, `:167-169`),
which reads the per-outcome relative bias as the per-draw distance and so
derives a `2^-51.4` floor; the origin of the confusion is the source comments
`rng.rs:72` and `transcript.rs:96`, which say "bias 2^-64" without saying
which bias and should say both numbers. F10.4's qualitative conclusion — that
the reduction term dwarfs the `q/2^256` hash term and a bound must not lead
with `q/2^256` — is **unchanged and correct**; only its number moves.

### 1.8 What a reviewer attacks first in this section

1. **"§1.5 is the retracted argument again."** It is not, but it is one
   sentence away from it. Round 1 §2 argued from the Rust API that Game E is
   unreachable and was retracted because the *verifier's statement* does not
   know about the API (`ZK60_MVP_JOINT_VIEW.md` §1.1 and its correction note;
   D8's correction, `ZK60_DECISIONS.md:268-274`). §1.5 makes no claim about
   the statement. It says only: *if* the project chooses route (i) or (v),
   the types already enforce **one `finish`** for every root this prover can
   prove about. **That is not the rule those routes need**, which is "one
   published path set of any kind, accepted, rejected or captured" — H8 and
   H9 are outside what the types can see (§1.5). So the rule is cheaper to
   adopt than it looks and is *not* free, and it still requires a decision by
   Victor about what the product promises.
2. **"H3 unreachable" is a claim about a moving target.** It rests on there
   being no import, no seed and no serialisation interface. Any of the three
   would reopen it. It should be a named, tested invariant (§5), not an
   observation.
3. **The `aux`-excludes-`r` clause (§1.6), and this is where the check
   landed first.** An external cryptographer will say that this is not zero
   knowledge as usually defined, and they are right. The answer originally
   given here — that it is "the established commit-and-prove notion (LNS Def
   2.8)" — **is withdrawn**: the cited source maps Def 2.8 to the game in
   which the simulator produces the commitments (§1.6). What can honestly be
   said is that no hash-Merkle commit-and-prove system is known to achieve
   the stronger notion for foreign roots, and that this is therefore a new,
   project-specific notion whose excluded parties must be written into the
   product claim. Whether the product's threat model matches it is exactly
   the unanswered question of §1.6: nobody has named the third-party
   committer.
4. **Case (b)'s emptiness (§1.4).** This has already happened twice: the
   check found **H8** (a rejected-but-emitted receipt) and **H9** (a
   retained capture), both reachable today with no new interface and both
   published path sets, so the enumeration that was offered as exhaustive was
   not. Any further kind of history that is neither a public output, a
   parameter, an application bound nor a disjoint tree changes §4's costing
   again — which is one reason the enumeration is not load-bearing and
   should not be treated as one.

## 2. What is proved, what is refuted, what is open

### 2.1 Proved natively: two openings of one endpoint commitment recover the plane

**Statement (PROVED, reproduced in native Rust).** At the actual seven-row,
256-column endpoint geometry, **two PCS openings of one commitment recover
all 512 data words**, using only the two public group vectors and their
public challenge coefficients — no masks, pads, salts, paths or RNG seed
(`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:3-9`, `:16-22`; regression
`zkp-core/tests/endpoint_reuse.rs`, invoked by
`cargo test --release --offline --manifest-path zkp-core/Cargo.toml --test endpoint_reuse`).

**The mechanism, in one line.** For each coordinate pair an opening publishes
`v = a·x + b·y + c·m` over the quadratic extension, where `x, y` are
base-field data words and `m` is the *fixed* terminal mask. Two openings
share `m`; subtracting cancels it and leaves one complex equation, i.e. two
base-field equations, in `x, y`. The tested public coefficient matrix is
invertible (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:16-22`).

**What it settles.** Case (c) is not repairable at this geometry by any
simulator: in the real world two openings *determine* the plane, so no
witness-independent distribution exists. D12 rule 1 ("no commitment is opened
more than once, anywhere in a composed block", `ZK60_DECISIONS.md:319`)
is the correct and necessary response.

**What it does not settle.** The disposition says so itself: it deliberately
bypasses the consuming owner, no production code changed, and "the one-use
lifecycle does not close the outstanding caller-fixed-root privacy argument"
(`:35-43`).

### 2.2 Refuted: the forced-challenge counterexample, and what it does not show

**The premise refuted.** The archived two-use redesign asserted (its item
**A4**) that for **every** non-refused challenge vector, the per-use
proximity checks leave the data rows unrecoverable. That universal assertion
is **false as written**: there exist challenge pairs that pass both uses'
individual proximity-pair checks while sharing identical mask coefficients,
so that subtracting the two proximity vectors cancels the masks and reveals
both data coordinates (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:48-56`;
test `tests/test_zk60_budgeted_endpoint_boundary.py`, whose own docstring
states the scope, lines 1-8; the control at
`test_separate_proximity_masks_do_not_cancel_in_the_control`).

**What it does *not* show**, stated as strongly as the evidence allows:

- It is **not** an efficient attack on randomly sampled Fiat–Shamir
  challenges. The bad challenge set is exhibited by *forcing* the challenges,
  not by sampling them; nothing bounds its density from below.
- It is **not** a native full-proof attack, and it touches no production
  path: the model it refutes is an archived research proposal
  (`results/zk60_loop_20260918/reviews/fable_reuse/…`, pinned by SHA-256 in
  the test at `tests/test_zk60_budgeted_endpoint_boundary.py:25`).
- It says nothing about case (a) or about the hash layer.

**What a repaired budgeted argument would need** (from the same disposition,
`:45-54`): either a *joint*-rank refusal — a check the verifier can run that
rejects exactly the degenerate challenge pairs — or a justified upper bound on
the probability of the bad-challenge event under real Fiat–Shamir. Neither
exists. Since D12 forbids two uses anyway, the practical status is: the
budgeted two-use scheme is not a live candidate, and nothing should be built
on A4.

### 2.3 Retracted: the one-programmed-point closure, and exactly where it breaks

**The claim that was made.** `ZK60_MVP_JOINT_VIEW.md` §1.1 (branch
`zk60-mvp-fable`) proposed: run the honest prover on the all-zero witness
with fresh randomness, building each endpoint's own tree over zero data with
fresh salts; let `(l′, r′)` be that tree's two top-level children; and
**program the single oracle point `l′‖r′ ↦ R`**, where `R` is the caller's
root. Two programmed points per proof (one per endpoint); every other leaf,
node and transcript hash a genuine query. The stated detection bound was
`q/2^256` for `q` prior oracle answers.

**Where it breaks.** An accepted opening under `R` publishes an 11-sibling
authentication path. Recompute the chain from the opened leaf; at the top,
the recomputed value is one child of the root and **the last sibling on the
path is the other**. So any previously published path hands the distinguisher
the honest pair `(l, r̂)` with `blake3(l‖r̂) = R`, with no secret salt and no
guessing. The distinguisher now holds **two distinct 64-byte preimages of
`R`** — the honest one from the earlier path and the simulator's `(l′, r′)`
from this receipt — which cannot happen in the real world except with
probability about `2^-256`. The simulator's own freshness guard does not
fire, because it guards the *input* it is about to program, not whether a
preimage of the same *output* is already public
(`ZK60_JOINT_VIEW_REVIEW_20260918.md:10-22`; regression
`tests/test_zk60_root_history_boundary.py`, which loads the pinned delivery
read-only at lines 17-19 and skips rather than substitutes if the commit is
absent, lines 24-35; validated 2026-09-18, three tests, 0.068 s,
`ZK60_JOINT_VIEW_REVIEW_20260918.md:49`).

**Exactly what survives the retraction, and exactly what does not.**

- **Survives:** the construction for a root with **no prior opening**. The
  retraction note in the memo itself says so, and D8's correction repeats it
  (`ZK60_DECISIONS.md:270-274`).
- **Does not survive:** the sentence in the memo's §1.1 bullet that the
  distinguisher "can tell the worlds apart only if … it already holds the
  honest committer's `(l, r)`, which requires the committer's secret salts or
  a `2^-256`-per-guess event". A path is a third way and it needs neither.
- **Also does not survive:** using `q/2^256` as *the* bound. O10 §3 lists
  six further union terms it omits (`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:100-142`),
  and §1.7 above records which term actually dominates.

**Note on which artefact is being talked about.** Two different hash-layer
constructions exist in the record and are easy to confuse:

| construction | leaves | programmed points | where |
|---|---|---|---|
| round-23 candidate | 2048 **free digest handles**, not preimages of anything | up to 256 salted-leaf points per endpoint, programmed late | `scripts/zk60_endpoint_simulation.py`; `ZK60_ENDPOINT_SIMULATION_MODEL.md` "A concrete candidate" |
| round-2 / two-point | a **genuine** fresh commitment to zero data: all 2048 leaves are real `salt_leaf(hash_column(·), ·)` images | **one node point per endpoint**, at the top | `scripts/zk60_root_simulator.py` on branch `zk60-mvp-fable` (not in the main tree) |

O10's **F10.3** — "the unopened leaves are the larger half of the union",
1792 of 2048 unexplained handles per endpoint
(`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:159-161`) — is a criticism of the
**round-23** construction only. The two-point construction has no unexplained
leaves. Any restatement must not carry F10.3 across; §3.5 does the count
afresh for the two-point shape.

### 2.4 The sequential-kernel lemma and its joint hypothesis

**Lemma (sequential kernel), as stated and as accepted.** Let the prover
publish `m_0, …, m_n`; let each challenge `r_j` after `m_j` be any function
`H` of the public prefix; let `m_j` depend only on the witness, the prover's
private randomness and `r_{<j}`. **If, for every fixed challenge vector `ρ`,
the *joint* law of `(m_0, …, m_n)` given `ρ` is the same for witnesses `w`
and `w′`,** then for every `H` the law of the whole view `(m, r)` is the same
for `w` and `w′`. Proof: induction on `j`; each kernel
`K_j(m_j | m_{<j}, r_{<j})` is a ratio of two marginals of the per-`ρ` joint
law, the challenges are deterministic in the public prefix, and the view's law
is the product of the kernels with the challenge indicators
(`ZK60_MVP_JOINT_VIEW.md` §1.2, branch `zk60-mvp-fable`).

**Its status.** The independent review accepted it as **valid for the stated
causal message rules, under the strengthened joint hypothesis**
(`ZK60_JOINT_VIEW_REVIEW_20260918.md:54-56`). The earlier
marginal-law counterexample (`H(mask), mask ⊕ w`: witness-independent
marginals, witness-*dependent* joint law) does not contradict it; it shows
why the hypothesis must be joint. Exhaustive checks on finite toy protocols
are in `tests/test_zk60_sequential_kernel.py` — **on branch `zk60-mvp-fable`
only; it is not in the main tree** (verified 2026-09-19).

**Two carve-outs in the lemma itself, which must travel with any use of it.**

1. Refusal events that are functions of the public prefix inherit the same
   law; **witness-dependent refusals break the conclusion**. In `/2` there is
   exactly one such event, the LogUp collision, priced at
   `(lookups + table rows)/2^128` per proof.
2. The hypothesis is about *field* messages. The lemma says nothing about the
   hash layer, because roots, salts and paths are not "messages the prover
   chooses given `ρ`" in the sense of its causal rule — they are determined
   before the challenges exist.

**The open item.** The joint hypothesis is **not discharged**. It is carried
as **U-3** (`ZK60_MVP_JOINT_VIEW.md` §4) and reaffirmed as open by the
security owner as recently as 2026-09-19
(`ZK60_NATIVE_JOINT_VIEW.md` §9a answer 5, branch `zk60-native-jointview`).

### 2.5 What today's joint-view evidence supports, and what it cannot touch

The 2026-09-19 native joint-view lane analysed **real receipts** — two
complete-block and two attention receipts — at their **real** BLAKE3
challenges, replayed from the public prefix (`ZK60_NATIVE_JOINT_VIEW.md`
§§1-6, branch `zk60-native-jointview`).

**Supported, on the linear channels:**

- Disclosed dimension **0** on `A`, on the Input endpoint and on the Output
  endpoint; **2** on `H`, and that 2 is its public LogUp identity, whose
  published claim value is `Fp2::ZERO` (§5). A zero-data preimage therefore
  exists on every channel.
- Channels covered: claim values, opening-group vectors, the proximity
  vector, every sampled column value, the M opening's `q`, its proximity
  vector and column values, and the slots' masked round messages (§5).
- The pad budget is **sufficient with zero margin**: 256 pads against 256
  distinct opened positions of the real encoded domain gives exact Gaussian
  rank **256 of 256**; the boundary cases `q_pad = d`, `d+1`, `d−1` disclose
  0, 0, 3 (§9b). The reason is structural — the pad half of the column map is
  `diag(x_j^n − 1)` times a Vandermonde in distinct nodes, full **row** rank
  for every `d ≤ q_pad` (§9b, citing `pcs.rs:618`, `:543`, `:670`).
- Group vectors consume **no** pad freedom: measured `q_pad · k0` with
  `k0 = 0` on every role of every capture (§9b).
- Every negative control fires, including "the commitment opened twice"
  (disclosed 10 in the small model, §6) and an altered capture (the replay
  fails on all four, §6).

**Not touched — stated by the lane itself** (§5 "Channels NOT covered", §7):

1. **The three Merkle roots, the 256 salts served per opening, and the 11-
   and 12-level authentication paths.** "Hash objects; linear algebra does
   not cover them." What is *assumed* for them is salted-leaf hiding of the
   unopened columns and, for the two caller-fixed roots, "the programmable
   random-oracle argument of D8/D11, **which is OPEN**" (§5).
2. Only two challenge vectors per profile — not a generic-rank argument.
3. The adaptive/distributional lift (the lemma of §2.4 and its joint
   hypothesis).
4. The nonlinear link between the two channels (`fin − c·g(ρ) =
   poly(terminals)`, degree up to 4).
5. Integer-range side information: the planes are small integers embedded in
   `Fp`; the model treats them as free `Fp` values.
6. Timing and other side channels; the PRG assumption on `ZkRng`.

**The sentence the project may quote** is the lane's own (§9a, last
paragraph), and it is careful: on a *linear model* of the verifier's view at
the *real* challenges of four receipts, nothing about the hidden planes is
determined beyond public identities — **and** the hash layer, which rests on
the open D8/D11 obligation, is excluded.

**So the division of labour is now clean.** The field layer has strong,
real-receipt evidence and one named written obligation (U-3, the joint
hypothesis). The hash layer has **no** argument at all for foreign roots.
Everything below is about the hash layer.

### 2.6 The ledger

| item | status | where |
|---|---|---|
| two openings of one endpoint commitment recover all 512 data words | **PROVED** (native regression) | `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:3-9`; `zkp-core/tests/endpoint_reuse.rs` |
| case (c) has no simulator at this geometry | **follows from the above** | §2.1 |
| the budgeted two-use scheme's universal per-use rank premise (A4) | **REFUTED** as stated | `:48-56`; `tests/test_zk60_budgeted_endpoint_boundary.py` |
| an efficient attack on random challenges | **not shown** | same |
| the one-programmed-point closure for a root with a prior public opening | **RETRACTED** | `ZK60_JOINT_VIEW_REVIEW_20260918.md:10-22`; D8 correction |
| the same closure for a root with **no** prior opening | **not retracted; also not proved** — the bound as written omits the union terms of O10 §3 | §2.3, §3.5 |
| sequential-kernel lemma | **valid** under its joint hypothesis | `ZK60_JOINT_VIEW_REVIEW_20260918.md:54-56` |
| the joint hypothesis itself | **OPEN (U-3)** | `ZK60_NATIVE_JOINT_VIEW.md` §9a.5 |
| disclosed dimension 0 on the linear channels of real receipts | **MEASURED** on four captures at real challenges | `ZK60_NATIVE_JOINT_VIEW.md` §2.3, §5, §9b |
| the hash layer (roots, salts, paths) for foreign roots | **OPEN — no construction exists** | `ZK60_NATIVE_JOINT_VIEW.md` §5, §7.1; O9 §7.1 |
| one opening per commitment, enforced in code | **one `finish` is enforced at compile time for every root this prover can prove about**, confirmed on every code path by the independent check; **"one published path set" is not enforced** (H8, H9), and neither is a property of the verifier's statement | §1.5 |
| "within the hash layer, case (b) is either empty or equal to case (a)" | **ATTEMPTED AND REFUSED** — circular: its content is restriction R2, which assumes it | §1.4, §3.7; `ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §1.1 |
| the two-point simulator's programming order | **no ordering problem** — the programmed point is the top node, drawn before the 256 indices exist | §3.5 |
| the two-proof-of-one-witness (H7) field-layer joint law | **MEASURED** at fixed coefficients on two captures, field channels only — zero disclosed base dimensions over 88,064 shared unknowns | `ZK60_ROUND23.md:58-65`, scope at `:67-71` |
| chaining two separately finished private proofs through a commitment root | **IMPOSSIBLE** — the upstream receipt already opens that root, so the downstream proof is a second opening (case c), and it is unimplementable today | §5.5; `ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §2.5 |
| the Fiat–Shamir table and the Merkle/leaf table | **share one untagged 64-byte BLAKE3 domain** — no attack follows, but O5 is concrete, not hypothetical | §3.8 item 1 |

## 3. The hash layer, which is the actual gap

### 3.1 What the verifier actually sees, counted

Per endpoint, exactly (`pcs.rs:567-573`, `:915-943`; serialisation `:582-601`):

| object | count | bytes | note |
|---|---|---|---|
| root | 1 | 32 | in the absorbed 112-byte policy |
| group vector | 1 | `(n+Q)·16 = 512·16 = 8,192` | `Fp2`, message then pad entries |
| proximity vector | 1 | 8,192 | |
| column index | 256 | 2,048 | drawn **with replacement**, `transcript.rs:119-131` |
| column values | 256 × 7 words | 14,336 | |
| **salts** | 256 × 32 B | **8,192** | one per opened column, `pcs.rs:935` |
| **authentication paths** | 256 × 11 digests | **90,112** | full path emitted per *draw*, duplicates included |
| **total** | | **131,072** | matches `ENDPOINT_OPEN_BYTES`, `zk_ffn_fresh_io.rs:15` |

So the hash layer inside the opening is `8,192 + 90,112 = 98,304` bytes of
the 131,072 — **exactly 75.00 % of an endpoint opening is hash material**,
and none of it is covered by the linear analysis of §2.5. (The root's 32
bytes are *not* part of that total: `ENDPOINT_OPEN_BYTES` does not contain
them, because the root travels in the 112-byte policy, as the table above
says. The first version of this page added them in and wrote `98,336`.)

### 3.2 What a simulator must produce

For case (a), `S` receives `(pp, x, R_in, R_out)` and must output, per
endpoint:

1. **256 column value vectors.** The pad argument (§2.5,
   `ZK60_NATIVE_JOINT_VIEW.md` §9b) shows that with `q_pad = 256` pads per
   row and up to 256 distinct opened positions, the opened symbols of each
   row are **jointly uniform given the data** — the pad half of the column
   map is `diag(x_j^n − 1)` times a Vandermonde in distinct nodes, full row
   rank for every `d ≤ q_pad`; and because the draws are with replacement,
   `d ≤ 256 = q_pad` always, so the statement applies with probability 1.
   That is sound **as a statement about the linear channel only, and it is
   not a sampler.** The first version of this page said "sampling a real
   commitment to the all-zero plane and reading off its columns gives
   exactly the right law"; **that sentence is withdrawn.** `verify_zk`
   imposes *two* conditions on these objects, not one —
   `⟨v[..n], c⟩ == combined claim` (`pcs.rs:976-979`) and, per opened column,
   `Σ_i ρ[i]·col[i] == encoded_group_vec[j]` (`pcs.rs:1022-1030`) — so the
   matrix is conditioned on the FFN's own claim value and on the published
   vectors at the sampled positions, and the leaf preimage covers the mask
   and proximity rows as well as the data rows (`pcs.rs:137-143`, all 7 words
   published per opened column at `:934`). What is required is the **joint
   conditional sampler O1**, which does not exist; §3.5's last paragraph says
   so, and this step must be read against it, not against the withdrawn
   sentence.
2. **256 salts.** Uniform 32-byte strings, drawn freshly (`pcs.rs:674`).
   **The laws are equal only under a stated assumption, not flatly.** In the
   real world the salts come from the **same keyed BLAKE3 stream** that
   moments earlier produced this plane's five secret mask rows
   (`private_seam.rs:211-213`) and its `rows × 256` pads (`pcs.rs:673` — pads
   then salts, in that order, from the same `rng`), and 256 of those 2,048
   salts, 8,192 bytes of stream output, are then published in the clear
   (`pcs.rs:935`). Equality of laws therefore rests on the **PRG assumption
   on `ZkRng`**, in a specific direction: published later outputs must not
   reveal earlier secret outputs. That assumption belongs in the theorem
   beside salted-leaf hiding, not only in §1.7's table.
3. **256 authentication paths verifying under a root it did not choose.**
   This is the whole problem.
4. **Group and proximity vectors consistent with (1)** and with the FFN's
   field messages. This is the U-3 field-layer obligation of §2.4, not the
   hash layer; §3 assumes it and says so.

**Can (3) be done without programming the oracle?** No. `verify_zk`
recomputes `salt_leaf(hash_column(col), salt)` and walks the 11 siblings to
the root (`pcs.rs:1018-1021`, `merkle.rs:56-63`). To produce a chain that
lands on `R` without holding a preimage of `R` is to invert BLAKE3, or to
find a second preimage of `R` — both `2^-256`-class. The model document
states this (`ZK60_ENDPOINT_SIMULATION_MODEL.md`, "A valid authentication
path also reveals a pair of top-level child digests hashing to the fixed
root"), O9 restates it (`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md:111-135`, Game E),
and §3.6 turns it into a statement about *every* construction, not just this
one.

### 3.3 Counting the tree: revealed nodes at both geometries

The 256 column indices are drawn uniformly **with replacement** from `nn`
positions (`pcs.rs:928` → `transcript.rs:119-131`). Writing `A_j` for the
expected number of distinct level-`j` ancestors of the opened set,
`A_j = (nn/2^j)·(1 − (1 − 2^j/nn)^{256})`. Every node at level `j` that is a
child of a level-`(j+1)` ancestor becomes public — it is either recomputed by
the verifier or published as a sibling — so the revealed set at level `j` has
size `2·A_{j+1}`.

**Tiny geometry (`nn = 2048`, depth 11 — the pinned endpoint profile, and
also the widened profile if it keeps `log_cols 8 / inv_rate 8`)**
[COUNTED, exact expectations]:

| quantity | value |
|---|---|
| distinct opened leaves | **240.7** of 256 draws (≈ 15.3 duplicate draws) |
| `A_1 … A_{11}` | 226.6, 201.6, 162.0, 110.8, 62.9, 32.0, 16.0, 8.0, 4.0, 2.0, 1.0 |
| leaf digests revealed | **453.2** = 240.7 opened + **212.5 unopened** |
| internal nodes revealed (levels 1–10) | **1,200.6** |
| root | 1 |
| **total distinct tree nodes revealed** | **1,654.8 of 4,095** — **40.4 % of the whole tree** |
| distinct sibling digests actually published | **587.2** (of 2,816 digest slots emitted — heavy duplication) |
| honest oracle queries to build the tree | 2,048 column hashes + 2,048 salted leaves + 2,047 nodes = **6,143** |

**Model geometry (`nn = 65,536`, depth 16 — `log_cols 14 / inv_rate 4`, the
CLI default at `hashline/src/bin/hashline.rs:59` and the geometry a widened
`SeamSpecG` would inherit from `LayerParams` under D17/E-2)**
[COUNTED]:

| quantity | value |
|---|---|
| distinct opened leaves | **255.5** of 256 |
| leaf digests revealed | **510.0** = 255.5 opened + **254.5 unopened** |
| internal nodes revealed (levels 1–15) | **3,643.8** |
| **total distinct nodes revealed** | **4,154.7 of 131,071** — **3.2 %** |
| distinct sibling digests published | **1,822.4** (of 4,096 slots) |
| honest queries to build the tree | 65,536 + 65,536 + 65,535 = **196,607** |

**Opening bytes for reference** [COUNTED from the geometry]: 131,072 B per
endpoint at the tiny shape; **946,176 B (0.90 MiB)** per endpoint at
`log_cols 14 / inv_rate 4` with a `512 × 4096 = 2^21`-word plane (133 rows);
and **16,904,192 B (16.1 MiB)** per endpoint if the same `2^21` plane were
committed at `log_cols 8 / inv_rate 8` (8,197 rows). The last figure is a
reason to widen the endpoint profile with the layer, independent of privacy.

**Two things this count makes concrete.** First, the tiny geometry publishes
**40 % of the tree** — near the top, every node is revealed (`A_j` saturates:
levels 6–11 are fully covered). Second, the top pair is revealed **with
probability `1 − 2^-255`**: 256 draws miss one half of the tree only if every
draw lands in the other, so the deficit `2 − A_{depth−1}` is exactly `2^-255`
at both geometries (independently verified). There is no "sometimes the top
pair stays hidden" case to hide behind, but it is a probability statement,
not an identity — `A_{10}` is `2 − 2^-255`, not 2, and any gate that asserts
equality asserts something false with probability `2^-255` (see §5.4). Same
at the model geometry, where `A_{15} = 2 − 2^-255`.

### 3.4 The unopened leaves, the salt, and what hiding requires of the oracle

Of the leaf digests published as level-0 siblings, **212.5 at the tiny
geometry and 254.5 at the model geometry are hashes of columns that are never
opened**. Each is `blake3( blake3(column bytes) ‖ salt )` with a **32-byte
(256-bit) salt** drawn from `ZkRng::bytes32()` (`pcs.rs:640-645`, `:674`).

**What their hiding needs.**

- *In the ROM*: immediate. The input is a fresh 64-byte point, the output is
  uniform, and the distinguisher learns the preimage only by querying it,
  which requires guessing the 256-bit salt: `≤ q·2^-256` over all `q`
  queries.
- *In the standard model*: **an assumption that is not collision
  resistance.** What is needed is that `BLAKE3(y ‖ s)` with uniform
  256-bit `s` is a computationally hiding commitment to `y`. That is a
  PRF/extractor-style assumption on BLAKE3 keyed by the second half of its
  input. It is reasonable and universally made; it is not implied by
  anything the project has written down, and any theorem must name it.
- *Sharpness*: the 32-byte salt is ample (the leak, if any, is bounded by
  the salt's min-entropy, 256 bits, against a 256-bit digest).

**The domain-overlap constraint, re-checked and narrowed.** O10 **F10.1**
(`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:143-157`) records that `salt_leaf`
(`pcs.rs:640`) and `hash_pair` (`merkle.rs:14`) are **the same untagged
64-byte BLAKE3 domain**, and that `hash_column` (`pcs.rs:137`) avoids them
only by length (`8·rows`), degenerating at exactly 8 rows — and that a 5-row
commitment would alias `ZkRng::refill`'s 40-byte input (`rng.rs:53`).

**New observation, offered as a correction to the risk framing.** For seam
endpoints the degenerate row counts are **unreachable by construction**.
`SeamSpec::new` refuses unless both axes are powers of two and
`2 ≤ len ≤ 4096` (`private_seam.rs:66-72`), so `len` is a power of two;
`data_rows = ceil(len/256)` (`:106-108`) is therefore 1, 2, 4, 8 or 16, and
`commitment_rows = data_rows + 5` (`:109-111`) is one of **{6, 7, 9, 13, 21}**
— never 5, never 8. A widened `SeamSpecG` inherits the same shape rule, so
the invariant is `2^k + MASK_ROWS ≠ 8` and `≠ 5`, which holds for every
`k ≥ 0` given `MASK_ROWS = 5`. This should be an **asserted, tested
invariant** rather than a coincidence, because it is one change to
`MASK_ROWS` away from being false, and because the *other* commitments in a
proof (`A` at 702 rows, `H` at 1326, `M` at 20, P3 `W` at 11, P1 public `W`
at 3 — O9 §4) are not protected by any rule at all.

### 3.5 Case (a): how many points are programmed, where, and are they fresh

Take the **two-point** construction of §2.3 (a genuine fresh commitment to
zero data, not the round-23 free-handle tool). Per endpoint:

| level | what the simulator does | count | genuine or programmed |
|---|---|---|---|
| column hashes | `hash_column` over its own encoded columns | 2,048 (tiny) / 65,536 (model) | genuine |
| salted leaves | `salt_leaf(·, fresh salt)` | 2,048 / 65,536 | genuine |
| internal nodes, levels 1..depth−1 | `hash_pair` up its own tree | 2,046 / 65,534 | genuine |
| **root** | `hash_pair(l′, r′) ↦ R` | **1** | **programmed** |

**One programmed point per endpoint root, both at the topmost level** (the
hash of the two level-`(depth−1)` children). Everything else — 6,142 of 6,143
queries at the tiny geometry, 196,606 of 196,607 at the model geometry — is a
genuine oracle call. **"Two per proof" is the pinned tiny profile only, and
must not be carried to model scale:** D17 rule 4 records that a
feed-forward-only 32-layer private pass has **64 caller-fixed endpoint
roots**, every one of which carries the open D8/D11 obligation
(`ZK60_DECISIONS.md:544-549`). At that scale the programming count, the
freshness union and the one-path-set bookkeeping are all 32× larger, and
every model-scale sentence below must be read with `m = 64`, not `m = 2`.

**The strongest single property of this shape, which the first version of
this page never stated.** The two-point construction **has no ordering
problem.** The programmed point is the tree's top node, and it is independent
of the 256 column indices — which are drawn only *after* the group and
proximity vectors have been absorbed (`pcs.rs:922-928` →
`transcript.rs:119-131`). The simulator's own tree is complete over all 2,048
(or 65,536) leaves before any index exists, so it can serve any index
multiset, and it is never allowed to choose leaves after seeing the indices
and never needs to. That is exactly where the round-23 free-handle
construction is weak — late salted-leaf programming, which O9 (`:95-99`) and
the model document (`ZK60_ENDPOINT_SIMULATION_MODEL.md:114-116`) flag as
"consistent late assignment, not adaptive Fiat–Shamir security". It is the
clearest reason to prefer the two-point shape, and it was confirmed
independently against the source order in `pcs.rs` and `transcript.rs`.

**Is the programmed point fresh in case (a)?** Freshness means: no answer for
the 64-byte string `l′‖r′` exists yet. The bad events, counted:

| event | bound (tiny) | bound (model) |
|---|---|---|
| the distinguisher already answered `l′‖r′` (it must guess two uniform digests) | `q·2^-256` per endpoint | same |
| `l′‖r′` collides with one of the simulator's own genuine inputs — **every** one, not just the endpoint tree's: its `A` (702 rows), `H` (1,326) and `M` (20) trees each contribute `nn` column hashes, `nn` salted leaves and `nn−1` nodes, and the transcript's own absorbs and squeezes contribute too | endpoint tree alone is `(2,046 + 2,048)·2^-256 ≈ 2^-244.0`; the **correct** union is over the simulator's whole honest query count `Q_S`, of order `3 × 10^4`, i.e. `≈ 2^-241` | same construction; `≈ 2^-239` from the endpoint tree, larger union with `Q_S` |
| `l′‖r′` collides with a `hash_column` input | **0** — column inputs are `8·rows` bytes, never 64, by the invariant of §3.4 | 0 |
| the two endpoints' programmed points coincide | `2^-256` | `2^-256` |
| the distinguisher's own verification queries enter the same table (O10 **F10.5**) — 13 queries per opening it checks at the tiny geometry, 18 at the model geometry | inside `q` | inside `q` |
| **a second preimage of `R` is already public** | **excluded by the case-(a) hypothesis** — this is exactly H3 | — |

**Total hash-layer term in case (a): about `m·(q + Q_S)·2^-256`** [COUNTED
from the stated events], where `m` is the number of caller-fixed endpoint
roots (2 at the tiny profile, **64** at a 32-layer feed-forward-only private
pass, D17 rule 4) and `Q_S` is the simulator's **total** honest query count
across all its commitments and the transcript, of order `3 × 10^4` at the
tiny profile. The first version of this page wrote the constant as
`2·(q + 4,094)`, counting only the endpoint tree's own points; the corrected
union gives `≈ 2^-241` in place of `2^-244`. For any realistic `q` (say
`2^80`) the whole term is still about `2^-175`, and **it is dwarfed by the
accepted D9 term of `2^-72`** (§1.7). The correction is numerically
irrelevant and is recorded because the constant, not the conclusion, was
wrong.

**The honest reading of that.** In case (a), the hash layer is *not* the
binding constraint on the privacy bound — the mask/pad reduction bias and
the unfinished field-layer joint hypothesis are. What the hash layer costs in
case (a) is not bits; it is an **assumption**: the programmable random-oracle
model, in which the *same* oracle also carries the Fiat–Shamir challenges.
The project already assumes the ROM for Fiat–Shamir soundness of this
transcript, so this is not a new assumption class — but it *is* a new *use*:
programming for privacy, on a table shared with the soundness argument. A
reviewer should be asked explicitly whether the two uses compose (see §3.8).

**Not established by any of this**, and it must be said in the same breath:
the column values the simulator serves at step (1) of §3.2 must be sampled
from the **real joint conditional distribution**, jointly with the group
vectors, the proximity vectors, the CFS rounds and the FFN messages. That
sampler does not exist (O9 §7.2; `ZK60_ENDPOINT_SIMULATION_MODEL.md` "What
remains before acceptance", first bullet). §3.5 is a statement about the
hash layer **given** that sampler, not a simulator.

### 3.6 The equivocation trilemma: why there are only three kinds of closure

**Proposition (PROPOSED; elementary, but not previously written down in this
repository).** Let `C` be a computationally binding commitment scheme and let
a proof system publish, as part of its accepted transcript, an opening of `C`
at a commitment value `c` that the simulator did not produce. Then any
efficient simulator that produces an accepting transcript without the
committed value must do at least one of:

1. **program the idealised primitive** underlying `C` (the random oracle, a
   CRS trapdoor, or an equivalent), or
2. **break binding** of `C`, or
3. **not publish an opening of `C` at all.**

*Argument.* Suppose neither (1) nor (3). The simulator outputs an accepting
opening of `c` to some value `v′`. The real prover's opening is to the true
value `v`. If the two worlds are indistinguishable and the witness
distribution is non-trivial, then with noticeable probability `v′ ≠ v`, and
the pair of openings is a binding break; if `v′ = v` always, the simulator
computed the witness, contradicting that it was not given it (for a hiding
commitment with non-trivial witness entropy). ∎

*What a reviewer attacks:* the step "if the two worlds are indistinguishable
then with noticeable probability `v′ ≠ v`" is informal — the simulator could
in principle output an opening to `v` without "computing" it, if the
commitment's opening set is small enough. That is why this is labelled
**PROPOSED**, and why it is offered as a structuring device rather than as a
theorem the project relies on. Its value is that it exactly matches the three
routes already visible in the record: the ROM programming of §2.3 (route 1);
"the commitment's randomness is the simulator's", i.e. Game J (which escapes
the hypothesis, not the conclusion); and the zkVM line's D7 profile, where
the opening is a private witness computation and only a salted SHA-256 handle
and the Groth16 proof are public (route 3,
`ZK60_DECISIONS.md:222-232`).

**Corollary for the hash layer.** Statistical zero knowledge for foreign
roots is unavailable with this commitment: route 2 is a break, route 3 is a
different protocol, and route 1 is computational-and-programmable by
definition. Any theorem this project states about case (a) is therefore a
**computational, programmable-ROM** theorem, and §1.7's framing is forced,
not chosen.

### 3.7 Case (b): which programmed points stop being fresh, item by item

Taking the history enumeration of §1.3 item by item against the single
programmed point `l′‖r′ ↦ R` of §3.5:

| history | does the programmed point stop being fresh? | why |
|---|---|---|
| **H0** nothing | no | the case-(a) analysis applies unchanged |
| **H1** `R` alone published early | **no** | programming needs an unanswered **input**. `R` is an *output*. Publishing it constrains nothing about which 64-byte strings are answered. The simulator may program after `R` is public, and must, since it learns `R` then |
| **H2** shape/scale/context metadata | no | not oracle history; it is absorbed public parameter data (`zk_ffn_fresh_io.rs:76-85`) |
| **H3** a prior authentication path under `R` | **YES — fatally** | the path hands the distinguisher the honest pair `(l, r̂)` with `blake3(l‖r̂) = R`. Together with the simulator's published `(l′, r′)` that is **two distinct preimages of one output**, an event of probability `≈ 2^-256` in the real world. The programmed point is still *fresh as an input*; it is **detectable as an output collision**. This is the precise failure mode, and it is why "fresh input" is the wrong guard (`ZK60_JOINT_VIEW_REVIEW_20260918.md:16-20`) |
| **H4** a query at the honest top pair | **YES** | same detection, arrived at differently; requires H3 or the salts |
| **H5** a query at another honest node/leaf input | **partially** | it does not break the top programming, but it lets the distinguisher rebuild part of the honest tree upward and eventually reach `(l, r̂)` — from a level-`j` honest node it needs the `2^j` honest leaves below it. Reachable only with the salts or the columns |
| **H6** application knowledge of the plane's contents | **no** (to the hash layer) | it bounds what hiding is worth, exactly as D7's qualifier (1) records for the zkVM line (`ZK60_DECISIONS.md:242-247`). It is a product statement, not a simulator failure |
| **H7** a second, independent commitment to the same plane | **no** (to the hash layer) | the two trees share no oracle point except with probability `≈ 6,143·6,143·2^-256`. It **does** load the *field* layer: two openings of two commitments to one plane is the round-23 "two proofs of one witness" configuration. That configuration has been **measured**, not left unexamined: zero disclosed base dimensions over 88,064 shared data unknowns, four with every private commitment added (the two public `H` identities), 256 in the single-mask control (`ZK60_ROUND23.md:58-65`) — at fixed coefficients, on two captures, field channels only, excluding CFS, pads, encoded columns, Merkle and adaptive composition, and not covering commitment reuse (`:67-71`). The first version of this page called it "not done" and cited `:29`, which is the section's heading |
| **H8** a rejected-but-emitted receipt under `R` | **YES — fatally, exactly as H3** | the 256 authentication paths are genuine and are published whether or not the verifier accepts (`zk_ffn_fresh_io.rs:256-257`, no equality precheck). The output-collision detector does not care that the receipt was rejected |
| **H9** a retained capture of an accepted receipt | **YES — exactly as H3** | `native_capture.rs:275-281` writes the receipt, the policy and the JSON to disk; that is a published path set under both endpoint roots |

**What the first version of this page concluded here, and why it is
refused.** It wrote, in bold: *"within the hash layer, case (b) is either
empty or equal to case (a)"*, on the grounds that every history that breaks
the construction (H3, H4, H5) requires a prior opening or the commitment
randomness, and every history reachable with one opening (H1, H2, H6, H7)
leaves the programmed point fresh. **That sentence is withdrawn**, on the
security owner's disposition of 2026-09-19 (`§1.1`, hole 1), for two reasons
kept here as a record of what does not work:

1. **It is circular.** "H3 requires a prior opening" is the definition of an
   authentication path, not a finding. Everything else is excluded by the
   theorem's own restrictions R1 and R2 of §5.2 — and R2 literally states
   the conclusion: *"neither root's honest top pair has reached the
   distinguisher by any route."* So §3.7 derives from R1 and R2 exactly what
   R1 and R2 assume. This is the third time the project has been offered
   this reduction; D11 refused it, and
   `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:36-38` called the same move
   "too strong".
2. **The enumeration it rests on was not exhaustive.** H8 and H9 above are
   reachable today with no new interface, and both were missing.

**What is left, stated as bookkeeping and not as a narrowing.** D11 says the
general obligation "stands unchanged" (`ZK60_DECISIONS.md:283-296`), and it
does. The rows above are an inventory of **what R2 assumes**, useful for
writing R2 down precisely and for costing an operational control. The honest
form of the reduction is: *"D11 becomes: exclude case (c) by rule **and**
assume R2"* — which is a restatement with an added hypothesis, not a
narrowing, and which still leaves the hash-layer simulator unbuilt for any
root the prover did not generate.

### 3.8 What a reviewer attacks first in this section

1. **Programming for privacy on the same oracle table that carries
   Fiat–Shamir soundness — and the two tables genuinely overlap.** The
   simulator fixes `blake3(l′‖r′) = R`. The first version of this page
   dismissed the composition concern by length: *"the transcript's challenges
   are `squeeze_bytes` outputs on 47-byte inputs (`transcript.rs:85`, O10
   row 3) — a different length, so no direct overlap."* **That is false and
   is withdrawn.** The transcript does not only squeeze; it **absorbs**, on
   the same untagged BLAKE3, with input
   `state(32) ‖ len(label)(8) ‖ label ‖ len(data)(8) ‖ data`
   (`transcript.rs:44-52`), whose length is `48 + |label| + |data|` and is
   therefore **exactly 64 whenever `|label| + |data| = 16`**. `absorb_u64`
   supplies 8 bytes of data (`transcript.rs:54-56`), so any 8-character
   label lands in the 64-byte domain, and one such call is on the private
   path: `absorb_u64(b"log-cols", …)` at `private_seam.rs:253`,
   `private_block/protocol.rs:43`, `private_attention/protocol.rs:38` and
   `native_capture.rs:206`. So **the Fiat–Shamir table and the Merkle-node /
   salted-leaf table share one untagged 64-byte input domain**, and O10
   F10.1's "domain separation is dimensional, not designed"
   (`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md:143-157`) extends to the
   transcript, which no document previously recorded. **Numerically nothing
   moves**: for `l′‖r′` to be such an absorb input the uniform right child
   `r′` would have to equal a fixed 32-byte string, i.e. `2^-256` per
   candidate. What moves is O5's status. It is not "two uses that happen to
   be length-separated"; it is **two uses of one domain**, so a simulator
   that programs a 64-byte point is programming a point the Fiat–Shamir
   reduction may also need to control. The length argument must be replaced
   by a **counted union over every 64-byte point the protocol answers**, and
   O5 restated against the real shared domain. A mechanical form of the same
   check is worth running beside the written argument: *does any 64-byte
   point the simulator programs lie in the set of 64-byte points the
   protocol itself answers?* — a finite, checkable statement about
   `hash_pair`, `salt_leaf`, `hash_column` at 8 rows, and every `absorb`
   whose `|label| + |data| = 16`. A *joint* statement ("this system is sound
   **and** zero knowledge") quantifies over one oracle, and the soundness
   reduction may not remain valid against an adversary that sees programmed
   answers. This composition is **not** addressed anywhere in the record and
   is the single most likely place an external reviewer stops. Naming it is
   part of the deliverable of §5.
2. **The `m·(q + Q_S)·2^-256` figure.** It counts the events I could
   enumerate, with the union corrected to cover the simulator's whole honest
   query count. O10 §3 lists seven gap classes between a local fresh-query
   bound and a whole-view bound; items 1, 3 and 4 of that list are covered
   above, items 5 (reduction bias) and 7 (unmodelled couplings) are carried
   in §1.7 and §3.5's last paragraph, and item 2 (unopened leaves) does not
   apply to the two-point shape (§2.3's table). Item 6 (repetition) does
   apply and is not counted here: the union grows with the number of proofs
   a distinguisher sees.
3. **"40 % of the tree is revealed" sounds alarming and is not.** In the
   simulated world those nodes are genuine hashes of a genuine zero-data
   tree; the count matters only because it fixes how much the simulator must
   build honestly, not because it leaks. A reviewer should nevertheless check
   that no *statistical* test on 1,655 revealed digests separates the worlds
   — in the ROM it cannot, in the standard model it is the same BLAKE3
   assumption as §3.4.
4. **The proposition of §3.6 is informal.** It should either be tightened to
   a standard commit-and-prove impossibility statement with a proper
   reduction, or demoted to a taxonomy and not cited as a result.
5. **The whole of §3 is conditional on the field-layer sampler that does not
   exist.** If the joint conditional sampler (U-3 plus O9 §7.2) turns out to
   be impossible at these parameters, §3 is moot.

## 4. Candidate closures

All five are costed against the same two reference points: the pinned tiny
shape, and the **58.40 s** Mistral-7B 32-layer × 512-token pass on a laptop
RTX 4070 (`MVP_STATUS.md:139`, [MEASURED, NOISY-SHARED, 2026-09-04]), whose
committed volume is **9.78 × 10^9 field words** — 18,649 rows × 16,384
columns per layer × 32 layers, 78 GB of message data into 313 GB of codeword
(`ZK60_L4_FEWER_HASHED_BYTES_MEMO.md:127-138`, [COUNTED/MEASURED]). That is
**1.67 × 10^8 committed words per second** on that machine, which is the rate
every estimate below divides by. The LogUp helper volume of the same pass is
`H = 4,379 × 16,384 × 32 = 2.29 × 10^9` field inverses; "helpers + commit H"
is 5.555 s of the public pass and **146.26 s of 265.34 s (55 %)** of the
legacy private pass (`ZK60_L4_FEWER_HASHED_BYTES_MEMO.md:463`).

Every option is measured against **D17 rule 2**: the tiny private-IO path
stays byte-frozen and everything new is additive
(`ZK60_DECISIONS.md:521-525`).

### 4.1 (i) Restrict the obligation to case (a)

**The change.** Make it a rule of the system that an endpoint root is
**published for the first time together with the first (and only) proof that
consumes it**. Nothing is proved about roots with prior openings, because no
such root can occur.

**Does the code already do this?** **Partly, and less than the first version
of this page claimed.** The types enforce **one `finish`** for every root
this prover can prove about — §1.5, confirmed on every code path by the
independent check. They do **not** enforce "one published path set": a
rejected receipt is emitted in full (H8) and a retained capture is written to
disk (H9). So the rule this route needs must read **"at most one published
path set of any kind per root — accepted, rejected or captured"**, and that
is not what the types say. It is also not *stated*, not *asserted* and not
*tested as an invariant*, and the verifier cannot check it from the bytes.
"This root has never been opened before" is a property of the world, not of
the artefact. At model scale the rule binds **64 roots per feed-forward-only
32-layer private pass**, not two (D17 rule 4, `ZK60_DECISIONS.md:544-549`).

**What it makes the verifier's statement.** Today: "there exist hidden planes
under `R_in`, `R_out` such that the model maps one to the other." Under (i):
the same, **plus** a caveat the artefact cannot carry — "and this proof is
private provided `R_in`, `R_out` were never opened before". A regulator
receiving one receipt cannot verify the proviso. Three ways to give it
teeth, in increasing cost:

1. **A registry.** Whoever publishes roots records `(root, context)` and
   refuses a repeat. Detection, not prevention; it is an operational
   control, and it is exactly the kind of control a regulator already
   understands.
2. **Bind freshness into the statement.** The 112-byte policy already
   absorbs a 32-byte `context` (`zk_ffn_fresh_io.rs:79`). Require the
   context to be a per-request nonce and require the verifier to reject a
   context it has seen. Cheap; still operational; changes no bytes because
   the field exists.
3. **Make reuse impossible by construction** — which is closure (ii) or the
   architectural fix of §4.3.

**What it costs.** Nothing in prover time, nothing in proof bytes, at either
geometry. Zero rows, zero seconds. [COUNTED: no change to any committed
object.]

**What it loses, and this is the real price.** The root stops being a stable
public name for a hidden value. A regulator cannot use it to say "the same
prompt was used in these two proofs"; a downstream proof cannot refer to an
upstream hidden output by its root. §4.3 shows the second of those is
recoverable architecturally and the first is not.

**Would cover:** (a) — in the sense that it makes (a) the only case. **(b):**
only by assumption, not by argument — §3.7's "the reachable (b) histories do
not touch the hash layer" is the content of restriction R2 restated, so this
route assumes (b) away rather than disposing of it. **(c):** excluded by
rule, and by the types today only in the weaker "one `finish`" sense.
**Residual assumptions:** everything in §5's theorem, plus the operational
control. **Files:** `ZK60_DECISIONS.md` (a new ruling),
`ZK60_ENDPOINT_SIMULATION_MODEL.md`, this document, and one new test file
asserting the invariants of §1.5 and §3.4. No source file on a frozen path.
**Measurement that would test it:** a capture-level gate that refuses two
retained receipts sharing an endpoint root or a context digest — runnable
today on `results/` captures.

### 4.2 (ii) Change what the caller fixes

**The change.** The caller fixes a **salted hash handle** `h = H(plane ‖ s)`
— the D7 shape already accepted for the zkVM line
(`ZK60_DECISIONS.md:222-232`) — and the proof's endpoint PCS commitment is
**prover-generated and fresh for every proof**. The proof additionally shows
that the fresh PCS commitment and `h` are commitments to the same plane. The
PCS root then never has any prior history *by construction*, so the whole
endpoint question moves from Game E to Game J, where the simulator issues its
own roots and **programs nothing** (`ZK60_MVP_JOINT_VIEW.md` §1.1, third
bullet).

**The cost is entirely in "showing they agree".** Counted:

*At model scale.* The plane is `512 tokens × 4096 = 2^21` words; as int16
that is 4,194,304 bytes = **65,536** 64-byte compressions per endpoint. The
project has **no bitwise machinery at all** — its arithmetisation is integer
arithmetic plus range lookups plus LogUp — so a hash must be built from
8-bit XOR/AND lookup tables and 32-bit carry facts. Per SHA-256 compression
that is, on a byte-lookup arithmetisation: 64 rounds × (Σ0, Σ1 at 8 lookups
each; Ch, Maj at ~12 each; ~5 modular additions at ~4 each) plus 48 message-
schedule rounds ≈ **4,000 lookups and ~2,500 committed words per
compression** [ESTIMATE, factor-2 band, NOT MEASURED].

| per-compression cost | lookups, both endpoints | of the pass's `H` (2.29e9) | committed words, both endpoints | of the pass's 9.78e9 |
|---|---|---|---|---|
| 2,000 / 1,250 (optimistic) | 2.62 × 10^8 | **+11.4 %** | 1.64 × 10^8 | +1.7 % |
| **4,000 / 2,500 (central)** | **5.24 × 10^8** | **+22.9 %** | **3.28 × 10^8** | **+3.4 %** |
| 8,000 / 5,000 (pessimistic) | 1.05 × 10^9 | +45.8 % | 6.55 × 10^8 | +6.7 % |

Turning that into seconds: on the **public** 58.40 s pass, helpers+commit H
is 5.555 s (9.5 %), so +22.9 % of helpers is **+1.3 s**, and +3.4 % of the
committed volume at 1.67 × 10^8 words/s is **+2.0 s** — call it **+3 to +4 s,
central; +2 to +8 s across the band** [COUNTED from the stated assumptions;
NOT MEASURED]. On a **private** profile, where helpers are 55 % of the time,
the same +22.9 % is **+12.6 % of the whole pass**.

**The honest verdict on those numbers — corrected.** The first version of
this page wrote: *"against the **5-second target** (`MVP_STATUS.md:132-135`)
it is between 60 % and 160 % of the *entire* budget … the wrong place to
spend the last remaining headroom."* **That verdict is a category error and
is withdrawn.** The +3.2 s was computed as a fraction of the *same pass's own
work* — 22.8 % of its helper time and 3.35 % of its committed volume — and
the 58.40 s pass is **11.7×** the 5 s target (`MVP_STATUS.md:137`). If the
pass ever reaches 5 s it reaches it by making that same work cheaper, and a
gadget proportional to committed volume takes the same discount: **+0.28 s,
i.e. 5.5 % of the 5 s budget.** The honest metric for a lever of this shape
is the relative one computed two paragraphs above: **about +5.5 % of a public
pass and +12.6 % of a private pass** [COUNTED from the stated assumptions,
factor-two band, NO GADGET EXISTS]. The caveat runs the other way too, and
must be said rather than picked silently: if part of the 11.7× ever comes
from a change that does *not* help the gadget — a lower encoding rate under
D14, say — then for that part the absolute figure is the right one. Against
58.40 s, +3 to +8 s is survivable. And all of this is before the bit
decomposition of `2^21` words (another 3.4 × 10^7 bit cells per endpoint
minimum), before the new 8-bit table planes and their multiplicity planes,
and before the wire and verifier work.

*At the tiny shape* the same estimate gives 16 compressions per endpoint,
**128,000 extra lookups (+38 % of the tiny `H` = 1,326 × 256 = 339,456)** and
**80,000 extra committed words** [COUNTED]. The first version of this page
put the second figure at "+13 %" without naming a denominator, and no
denominator stated anywhere in the document reproduces it; against the
message-part committed words `(702 + 1,326 + 20 + 2×7) × 256 = 527,872` it is
**+15.2 %**. Proportionally worse than at model scale, because the tiny
proof's fixed overheads are small.

**Cheaper algebraic handles, worked and rejected.** The obvious question is
whether the caller's handle can be something the verifier checks with field
arithmetic instead of a hash.

- *A second Ligero/PCS commitment*: circular. It is the same object with the
  same problem, and it would have to be opened, which is case (c).
- *Pedersen*: the commitment itself is cheap to publish, but linking a
  Pedersen-committed vector to a Ligero-committed one is a cross-system
  argument (LegoSNARK-style CP-link). **The reason first given here — "it
  needs the second commitment to be homomorphic, and Ligero is not" — is
  wrong and is withdrawn:** a Ligero/Brakedown opening *is* a linear
  functional of the committed rows (`fold_rows_multi_zk`, `pcs.rs:922`), and
  CP-link constructions do not in general require both commitments to be
  group-homomorphic. **The real and sufficient obstruction is the next
  clause:** an elliptic-curve multi-scalar multiplication would have to be
  arithmetised non-natively over Goldilocks, and this verifier does
  Goldilocks only. So it is a new proof system beside the existing one, plus
  elliptic-curve arithmetic in a verifier that cannot do it. The conclusion
  stands; only the reason changes.
- *Ajtai/SIS over the same Goldilocks prime*, which looks attractive because
  the plane is **already short** (int8/int16) and the relation `t = A·x mod p`
  is **linear over `Fp`**, i.e. exactly the shape the existing sumcheck
  speaks. It fails on verifier cost: folding the `k` rows with a random `ρ`
  gives one inner product `⟨ρᵀA, x⟩`, and the verifier must evaluate the MLE
  of `A` at the sumcheck's point, which for a dense `k × 2^21` matrix is
  `O(k·2^21)` verifier work — non-succinct. Structuring `A` to be succinct
  (for instance "evaluate the plane's MLE at `k` fixed public points")
  **destroys binding for short vectors** — but the reasoning first given
  here proved too much and is corrected. The pigeonhole count ("the
  multilinear polynomials vanishing at `k` fixed points form a space of
  dimension `2^21 − k`, which by pigeonhole contains short vectors, so two
  distinct short planes collide") applies equally to a **random** `A`: any
  map from `2^21` int8 words (`2^24` bits) to `k` Goldilocks elements
  (`64k` bits) has colliding short preimages for every `k ≪ 2^18`, and SIS
  binding is *computational*, so the mere existence of short collisions is
  not a break — as written the argument would also refute the primitive
  being proposed. The correct statement is that for this **structured** `A`
  the collisions are efficiently **findable**: the vanishing subspace is
  explicit linear algebra, and with `n = 2^21 ≫ k` the instance is so
  over-determined that combinatorial or lattice search is easy, whereas for
  a random `A` at `n ≈ k log q` they are conjectured hard. I could not find
  a structured `A` that is both succinct for this verifier and SIS-binding,
  and I record that as a negative result rather than an exhausted search,
  and certainly not as an impossibility.
- *Delegating the link to the zkVM line*: a small RISC Zero program could
  prove `h = SHA-256(plane ‖ s)` **and** that the same plane produces the
  PCS root, but the second half means recomputing a coset NTT and 2,048
  BLAKE3 leaves inside the guest. At the tiny shape that is plausibly
  seconds; at `2^21` words and 65,536 leaves it is 10^10-class cycles, i.e.
  out (D2's arithmetic, `ZK60_DECISIONS.md:62-65`). It would also import D3
  (97 bits) and D4 (trusted setup) into the custom line's statement.

**Would cover:** (a), (b) **and** (c) — because a fresh prover-generated root
is opened exactly once and has no history at all, and the caller's handle is
never opened. It is the only option that reaches all three, **provided** the
caller's handle is never opened, the fresh PCS root carries exactly one
published path set, and Game J's simulator exists — which it does not: the
model document says of `SimProve`, "This algorithm is not yet complete"
(`ZK60_ENDPOINT_SIMULATION_MODEL.md:76`). This is the route D18 records as
the expected end state, scoped separately in `ZK60_SEALED_HANDLE_SCOPING.md`
(commissioned 2026-09-19).
**Residual assumptions:** hiding of the salted hash handle (with D7's
qualifier (1): the handle hides only as well as the salt's secrecy and the
plane's own entropy, `ZK60_DECISIONS.md:242-247`); Game J's simulator, still
unbuilt; the field-layer obligations unchanged.
**Files:** a new endpoint-handle module beside `private_seam.rs`; a new hash
gadget with its tables in the layout (`hashline/src/zk.rs`), new lookup
domains and their LogUp helpers (`hashline/src/private_block/protocol.rs`,
`zkp-core/src/ffn_v3/*`), a new wire frame, a new profile tag. All additive
under D17.2, but it is a subsystem, not a patch.
**Measurement that would test it:** implement **one** SHA-256 (or BLAKE3)
compression in the existing lookup framework and count its committed rows and
lookup instances. That single number turns the factor-2 band above into an
answer, and it is a day of work, not a quarter.

### 4.3 (iii) Re-randomise per proof, with a link argument

**The change.** The owner publishes a fresh commitment to the same plane for
every consumer, plus an argument that they all commit to the same thing.

**Count the openings, which is what D12 rule 1 is about**
(`ZK60_DECISIONS.md:319-323`). Let the plane be consumed by `k` proofs, with
fresh commitments `C_1 … C_k`, each opened once by its own proof. A link
argument between two commitments opens **each side once** — that is what
`private_seam::prove` does (`private_seam.rs:335-339`, consuming both
planes).

| topology | openings of the caller's stable commitment `C_0` | openings of an interior `C_i` | verdict |
|---|---|---|---|
| star (every `C_i` linked to a master `C_0`) | 1 per link → **`k`** | 1 (proof) + 1 (link) = **2** | **violates D12 at `k ≥ 2`**, and the object that gets opened `k` times is precisely the caller's stable reference |
| path (`C_1—C_2—…—C_k`) | — | 1 (proof) + 2 (links) = **3** | violates D12 at `k ≥ 3`, and at `k = 2` the two endpoints are opened twice each |
| no links; each proof carries the caller's non-PCS handle | 0 (never opened) | **1** | this is closure (ii) |
| **no reuse: `k = 1` for every commitment** | — | **1** | satisfies D12 exactly |

So (iii) as usually imagined is **dominated**: either it collapses into (ii),
or it breaks D12 and hence §2.1.

**But the last row is reachable, and it is the useful part of (iii).** The
reason `k > 1` arises at all is that a forward pass is being assembled from
several separately-finished proofs. D12 rule 2 already forbids that inside a
block ("a block is one proof under one transcript with exactly two external
endpoints", `ZK60_DECISIONS.md:323-327`). Extended to the whole request, the
rule is: **one request, one transcript, exactly two external endpoints (the
model's hidden input and its hidden output); every intermediate activation
lives on a commitment the prover generates inside that one proof and opens
once.** Then `k = 1` everywhere and no link argument is needed.

**Is that architecture already there? No — and the first version of this
page's "partly, and this is encouraging" is withdrawn.** It rested on the
measured 58.40 s pass being produced by `hashline pass <layers> <t_rows>`,
documented as "the multi-layer pass, **one transcript**"
(`hashline/src/bin/hashline.rs:6`), building a single
`Transcript::new(b"hashline-pass")` at `:707` and looping the layers at
`:714`. The independent check traced it, which this page had not: `pass`
calls `hashline::layer::prove_layer` (imported at `:25`, called at `:714`),
the **public** prover, building a per-layer `Statement { l, t_rows, shifts,
table, table_digest }` (`:717`) with **public** inter-layer activations
(rung 1, `chain`, "reproduces every z digest", `:3`), and `MVP_STATUS.md:137`
labels that row "**public IO**". So the measured pass is **32 statements
sharing one transcript with public activations** — which is precisely why
`k = 1` is free there, and says nothing about the private case. The private
path has **no multi-block entry point at all**; the only chain example is
`hashline/examples/zk60_chain_receipt.rs`, which is `public_chain_receipt`,
mode "P0-public-synthetic" (`:9-10`, `:97`). One transcript is a necessary
condition, not a sufficient one, and for the private prover it has not been
built. This is now an **architecture decision that has to be taken in
writing** — one transcript per private request end to end, or route (ii)'s
non-PCS handle at run boundaries — and until it is taken, "the multi-block
story survives" must not be stated (§5.5, check condition 27).

**What it costs.** In the `k = 1` architecture: nothing extra; it is the
architecture already measured. In the link-argument form: one extra seam
argument per link. At the tiny shape a seam proof is 416,456 bytes
(`ZK60_PRIVATE_SEAM.md`, validation section) against a much smaller FFN
receipt, so links are not cheap even before they break D12.

**Chaining, which this page originally waved away.** The configuration is an
output root published **with** the upstream proof and consumed **later** by a
downstream proof. Three things are true of it at once, and the independent
check put them together. First, **it is a second opening**: the upstream
receipt already contains a full opening of that commitment — 256 columns,
salts and 11-level paths (`pcs.rs:930-941`) — so consuming the same root
downstream opens it again, and §2.1's proved recovery applies (two openings
at the 7×256 geometry recover **all 512 data words**). That is case (c), and
D12 rule 1 forbids it (`ZK60_DECISIONS.md:319-322`). Second, **it is also
prior history**: the upstream paths hand out the honest top pair, so the
hash-layer construction dies independently of the first mechanism. Third,
**it is unimplementable today**: `Endpoints` is consumed and non-`Clone` and
`prepare` always draws fresh OS entropy (`private_seam.rs:196`), so the
prover could not rebuild the commitment even if it wanted to. **The
consequence: there is no way to chain two separately finished private proofs
through a commitment root at all.** The only surviving composition is one
transcript end to end — or a boundary handle that is not a
polynomial-commitment root, i.e. route (ii).

**Would cover:** neither (a) nor (b) on its own. Its value is that it removes
the *reason* to want case (b) or (c), which is what would make route (i)
affordable — if the `k = 1` architecture existed for the private prover,
which it does not.
**Residual assumptions:** unchanged. **Files:** none if the architecture is
already `k = 1`; the composition work D12 and D17 already schedule otherwise.
**Measurement:** confirm from a real 32-layer receipt that no commitment root
appears in two openings — a capture-level check, runnable today.

### 4.4 (iv) A zero-knowledge opening at the hash layer

Four sub-options, each worked to a verdict:

**(iv-a) Hide which columns are opened.** Impossible. The 256 indices are
derived from the transcript by `challenge_indices` (`pcs.rs:928` →
`transcript.rs:119-131`) and the verifier must recompute and check them; they
are public by construction and their publicity is what makes the proximity
test sound.

**(iv-b) A hiding/equivocal vector commitment instead of a plain Merkle
tree.** For a simulator to open a root it did not create *without*
programming, the commitment must be **equivocal** — a trapdoor (chameleon)
commitment whose trapdoor holder can open to anything. A transparent system
has no trapdoor holder, so this means introducing a structured reference
string. The project has accepted a trusted setup once already, for the zkVM
line's Groth16 layer (D4, `ZK60_DECISIONS.md:128-160`), so it is not
unthinkable — but note D4's own observation that a setup affects
*soundness*, not privacy, whereas here it would be the privacy that depends
on it. Cost: a new commitment scheme, a new verifier, **every frozen digest
in the repository moves**, and the GPU commit path is rewritten. And it does
**not** buy case (c): the two-opening recovery of §2.1 is a *field-layer*
attack on the mask budget, not a hash-layer one, so it survives any change of
tree. **Verdict: highest cost of the five, and it does not buy the case it
would be bought for.**

**(iv-c) Commit to the salts differently** (a salt tree, PRF-derived salts).
Moves the wrong way: the simulator wants *more* freedom in the salts, not
less. A PRF-derived salt is *worse*, because it is no longer independently
samplable.

**(iv-d) A Merkle cap** — publish the top `c` levels as the commitment
instead of one root. The top pair becomes public by construction, so the
simulator programs `2^c` points at the cap level instead of one; each is
fresh under exactly the analysis of §3.5, so the term becomes
`2^c·(q + …)·2^-256`, still negligible. It neither helps nor hurts case (a),
does nothing for (c), and on proof size it is worth about **1 %** on this
commitment, not the 29 % first recorded — a figure D10's correction already
fixed (`ZK60_DECISIONS.md:411-418`). **Verdict: not a privacy lever.**

**Would cover:** (iv-b) would reach (a) and (b) and not (c); the others reach
nothing. **Files:** `zkp-core/src/pcs.rs`, `zkp-core/src/merkle.rs` — the
frozen core, so nothing here can be additive under D17.2; it is a new
profile from the ground up.

### 4.5 (v) A computational, programmable-random-oracle statement for case (a) only

This is (i) plus the written theorem. It is not an alternative to (i); it is
what (i) has to produce to be worth anything. Stated in §5.

**Would cover:** (a) only, and only if proved. (b) is **not** reduced to (a):
§3.7's attempt to do so is circular and has been refused, so (b) is assumed
away by restriction R2 rather than handled. (c) is excluded by the rule of
(i), which the types enforce only in the weaker "one `finish`" sense.
**Residual assumptions:** the programmable ROM; salted-leaf hiding in
the standard model if anyone wants a standard-model reading (§3.4); D9's
`2^-72`; the LogUp collision; the PRG assumption on `ZkRng`; and the
composition of programming with Fiat–Shamir soundness (§3.8 item 1).
**Cost:** zero prover seconds, zero proof bytes, at both geometries.
**Files:** documents, one new test file, one ruling in `ZK60_DECISIONS.md`.

### 4.6 Side by side

| | covers (a) | covers (b) | covers (c) | prover cost, tiny | prover cost, 8B | proof bytes | frozen bytes move? | files |
|---|---|---|---|---|---|---|---|---|
| **(i)** restrict to case (a) | makes it the only case | **no — assumed away by R2, which is circular (§3.7)** | by rule; by the types only as "one `finish`", not "one published path set" (H8, H9) | **0** | **0** | **0** | no | docs + 1 test |
| **(ii)** caller fixes a salted handle, PCS root fresh per proof | yes (Game J), whose simulator is unbuilt | yes | **yes** | +15.2 % words (of the 527,872 message-part committed words), +38 % lookups [COUNTED from an ESTIMATE] | **+5.5 % of a public pass, +12.6 % of a private one** — i.e. +3 to +4 s central on 58.40 s, and about **+0.28 s** if the pass reaches 5 s by a uniform speedup | +hash witness rows | no (additive) | new handle module, hash gadget + tables, wire, verifier, new profile tag |
| **(iii)** re-randomise + link | no | no | no — **breaks D12** in star or path form | one seam per link (416 KB at tiny) | not costed; dominated | + a seam per link | no | dominated by (ii); its `k = 1` reading is **refuted** for the private prover (§4.3) |
| **(iv-b)** equivocal/trapdoor vector commitment | yes | yes | **no** | new scheme | new scheme | new scheme | **yes, all of them** | `pcs.rs`, `merkle.rs`, GPU commit path |
| **(iv-d)** Merkle cap | neutral | neutral | no | ~0 | ~0 | −1 % | yes (format) | `pcs.rs` |
| **(v)** the written case-(a) theorem | yes, if proved | **no — §3.7's route to (b) is refused** | no (needs (i)'s rule) | **0** | **0** | **0** | no | docs + 1 test |

**Scope note on the whole table** (correction 16): the per-proof programming
and bookkeeping counts above are the pinned **tiny** profile's. A
feed-forward-only 32-layer private pass has **64** caller-fixed endpoint
roots, each carrying the open D8/D11 obligation (D17 rule 4,
`ZK60_DECISIONS.md:544-549`), so every model-scale row must be read at
`m = 64`.

## 5. The reduction that was attempted and refused, and the obligations that remain

### 5.1 The attempted reduction, recorded as REFUSED

**This page makes no recommendation.** The first version of it did, and the
recommendation was not accepted. It is kept here in full, with the reasons it
fails, because a route that does not work is worth recording once so that it
is not proposed a fourth time.

**What was proposed.** *"Pursue (i) + (v) first: make 'a sealed envelope is
used exactly once and is first published with the proof that uses it' a rule
of the product, and then write the theorem for that case. It costs no proving
time and no proof bytes, the code already enforces it for every root this
prover can prove about, and the analysis in §3 says the remaining hash-layer
risk in that case is astronomically smaller than terms the project has
already accepted (`2^-175`-class against D9's accepted `2^-72`)."*

**Why it was refused** (`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md` §1; the
security owner's verdict is that D8 and D11 stand exactly as written):

1. **The central reduction is circular.** The restriction that is supposed to
   make case (b) safe — R2 of §5.2, "neither root's honest top pair has
   reached the distinguisher by any route" — *is* the conclusion §3.7 draws
   from it. A previously published path under a root is an opening by
   definition, and every other history is excluded by R1 and R2 themselves.
   D11 and `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:36-38` refused this
   same move twice before.
2. **The party who fixed the root is excluded from ever being the
   adversary.** R1 keeps the commitment randomness from the distinguisher,
   and whoever holds the salts can rebuild the honest tree and detect the
   programmed top pair with probability 1. So the notion protects a hidden
   input against everyone **except the party who committed it** — and a
   regulator who supplies *and commits* an input is exactly that party
   (§1.6). No document names a third-party committer who is not the
   verifier, never opens and withholds the randomness, so the theorem has no
   named beneficiary.

Two further defects make the proposal unquotable even as an intention: the
advantage expression of §5.2 **is not a bound** while U-3 is open (§5.2
below), and the enumeration it rests on was not exhaustive (H8, H9 in §1.3).

**What survives the refusal, and it is a great deal** — listed in the
disposition's §2 and, on this page, in §2.6's ledger and in the framing
section at the top: the obligation stated as a game with its three cases kept
apart and case (c) dead by a proved recovery; the committer being the prover
in today's code; the two-point simulator having no ordering problem; the
hash-layer counts; the impossibility of chaining separately finished private
proofs through a commitment root; the corrected cost of the sealed-handle
route; the shared 64-byte BLAKE3 domain; the code-level invariants worth
asserting; and D9's figures.

**What is *not* settled by any of it.** The remaining hash-layer risk figure
quoted in the withdrawn recommendation (`2^-175`-class) is conditional on the
field-layer sampler O1, which does not exist, and on the programmable ROM; it
is not a privacy result and must not be quoted as one.

**On pricing the sealed-handle route.** Route (ii) is the only one that
reaches all three cases, it is what D18 records as the expected end state,
and its cost is still an estimate with a factor-of-two band. One SHA-256 (or
BLAKE3) compression implemented in the existing lookup framework converts
that band into a number; it is a day of work. `ZK60_SEALED_HANDLE_SCOPING.md`
(commissioned 2026-09-19) carries that scoping, not this page.

**What the refused route would have given up, if anyone revisits it.** The
root stops being a permanent public name for a hidden prompt or answer. A
regulator can no longer point at two different receipts and say "these used
the same input" — unless the application gives it a different way to do
that. That is a product decision and it belongs to Victor. Two cheap
mitigations exist and neither is cryptography: a registry of
`(root, context)` pairs, and making the 32-byte `context` a per-request
nonce (the field already exists and is already absorbed).

**And what must no longer be said about it.** The first version of this page
wrote "the multi-block story survives", on the grounds that the 58.40 s pass
is already built as one transcript. **That claim is withdrawn** (§4.3): the
measured pass is the *public* prover with public inter-layer activations, the
private path has no multi-block entry point, and a boundary between two
separately finished private runs is a root opened twice (§5.5). Until the
architecture question is settled in writing — one transcript per private
request end to end, or route (ii)'s non-PCS handle at run boundaries — the
multi-block story is an open question, not a survival.

### 5.2 The theorem the refused route would have needed

**Read this as the statement the project would have to *intend* to prove, not
as a bound.** The displayed inequality below contains the term "whatever the
discharge of U-3 contributes", and U-3 is open
(`ZK60_NATIVE_JOINT_VIEW.md` §9a answer 5, branch `zk60-native-jointview`),
so as an inequality it states nothing and **must never be quoted as a
`2^-175`-class result** (hole 6). The notion it defines is **new and
project-specific** — not LNS Definition 2.8, which maps to the game in which
the simulator produces the commitments (§1.6, hole 3) — and its **excluded
parties must travel with any product claim built on it**, the way D7's three
qualifiers travel with the zkVM claim.

**Theorem (PROPOSED — NOT PROVED; no part of this is established in this
repository; the route it belongs to has been refused).** Fix the pinned tiny
profile `pp` (`T32/d16/f16`,
`log_cols 8 / inv_rate 8 / Q 256`, endpoint shape `rows 7`). Model BLAKE3 as
a programmable random oracle `O`, shared by the commitment layer, the
transcript and the prover's RNG refill (one table, per O10 §1). Consider
Game E of §1.6 under these restrictions:

- **(R1) Honest commitment randomness, hidden from everyone.** Both endpoint
  roots are produced by `private_seam::prepare` on planes of the caller's
  choice with randomness from the honest distribution (`ZkRng::from_os`,
  `private_seam.rs:196`). That randomness — salts, pads, mask rows — is given
  to neither the simulator nor the distinguisher.
- **(R2) First publication.** No **published path set of any kind** under
  either commitment — accepted, rejected (H8) or written out as a retained
  capture (H9) — exists before the challenge receipt, and neither root's
  honest top pair has reached the distinguisher by any route. *Note what this
  clause does: the second half of it is the conclusion §3.7 tried to derive,
  which is why the route is circular and refused. It is written here as a
  hypothesis, which is the only honest place for it.*
- **(R3) Bounded, randomness-independent auxiliary input.** The
  distinguisher's auxiliary input is independent of the commitment
  randomness, and it makes at most `q` oracle queries in total, including the
  queries its own verification performs. **As written this is too permissive
  for `Δ_field` below** (hole 4): a second receipt on an *independent*
  commitment to the *same plane* — H7 — is independent of *this*
  commitment's randomness, so R3 admits it, and then `Δ_field` would have to
  cover a two-proof joint law. Either `aux` is restricted to exclude other
  receipts on the same plane, or `Δ_field` is extended and round 23 named as
  its only evidence (measured, fixed coefficients, two captures, field
  channels only, `ZK60_ROUND23.md:58-65`, scope at `:67-71`).
- **(R4) Generator assumption.** `ZkRng` is a pseudorandom generator in the
  direction the construction needs: its published later outputs (the 256
  salts served per opening) do not reveal its earlier secret outputs (this
  plane's mask rows and pads). Without this, §3.2 step 2's equality of laws
  does not hold (hole 8). Salted-leaf hiding (§3.4) is the companion
  assumption and belongs here too.

Then there is an efficient simulator `S`, given only `(pp, x, R_in, R_out,
aux)`, which makes **one programming call per caller-fixed endpoint root** —
`m = 2` at this pinned profile, and `m = 64` at a feed-forward-only 32-layer
private pass (D17 rule 4, `ZK60_DECISIONS.md:544-549`) — each at the top node
of an endpoint tree, such that no distinguisher's advantage exceeds

> `m·(q + Q_S)·2^-256  +  Δ_field`,

where `Q_S` is the simulator's **total** honest oracle-query count (its
endpoint trees, its `A`/`H`/`M` trees and the transcript's own queries;
order `3 × 10^4` at this profile) and `Δ_field` is the field-layer term: D9's
`2^-75` at this shape, plus the LogUp collision term
`(lookups + table rows)/2^128`, **plus whatever the discharge of U-3
contributes — which is unquantified, and is why this expression is an
intention and not a bound.** The first version of this page wrote the
constant as `2·(q + 2·nn − 2)` with `nn = 2048`, which under-counts the
union (correction 15) and fixes `m` at the tiny profile's 2
(correction 16).

**Every clause of that statement is load-bearing.** Drop (R1) and the
distinguisher rebuilds the honest tree — and note that (R1) is what excludes
the party who fixed the root from being the adversary at all (hole 2), so it
is load-bearing in a way that costs the theorem its product meaning. Drop
(R2) and §3.7's H3 row applies and the theorem is false — that is the
retraction of 2026-09-18. Drop (R4) and the salts are not argued. Drop the
programmability of `O` and §3.6 says no simulator exists at all.

### 5.3 The proof obligations, in order

| # | obligation | kind | who |
|---|---|---|---|
| **O1** | **The joint conditional field-view sampler exists** at the pinned profile: given fixed challenges, produce the columns, group vectors, proximity vectors, CFS rounds and terminals with the real joint law from the zero witness. This is U-3's substance plus O9 §7.2 | **written construction + proof**; the hard one | security owner, then external review |
| **O2** | The sequential-kernel lemma's **joint hypothesis** holds at the pinned profile for **every** non-refused challenge vector — not four captures (`ZK60_JOINT_VIEW_REVIEW_20260918.md:67-69`) | written proof (a generic-rank argument, or a verifier-side refusal of the degenerate set) | security owner |
| **O3** | The **hash-layer lemma of §3.5** written against the actual `pcs.rs` geometry with one-table overlap accounting. This is **U-6** of `ZK60_MVP_JOINT_VIEW.md` §4, and §3.3/§3.5 supply its arithmetic | short written proof | delegable |
| **O4** | **Salted-leaf hiding** named as an explicit assumption (§3.4), the **PRG assumption on `ZkRng`** named beside it (R4), and the **mechanical invariants** asserted and tested: `commitment_rows ∉ {5, 8}` for every reachable seam shape (today always one of `{6, 7, 9, 13, 21}`); `8·rows ∉ {40, 64}` for every commitment in a receipt; **no deployment-path commitment reproducible from a seed**; and **no new accessor exposing `PreparedPlane`'s `CommittedZk`**, whose `data`, `pads` and `salts` fields are `pub` (`pcs.rs:551-564`) | one sentence + **mechanical** | delegable |
| **O5** | **Composition of the two uses of `O`**: programming node points for privacy must not invalidate the Fiat–Shamir soundness reduction that uses the same table — and the two tables **genuinely share the untagged 64-byte BLAKE3 domain** (§3.8 item 1), so this is concrete, not hypothetical. It must be restated against the real shared domain, with a counted union over every 64-byte point the protocol answers and the mechanical point-set check beside the written argument. Nothing in the record addresses it | written proof + **mechanical**; **most likely external stopping point** | external reviewer |
| **O6** | **(R2) enforced as a system rule**: "**at most one published path set of any kind per root** — accepted, rejected or captured", with a code-level invariant, a capture-level gate that refuses two retained receipts sharing an endpoint root or a context digest, a negative control, and an operational control (registry or nonce context) | **mechanical** + a ruling | Codex + Victor |

**The seven conditions the independent check attached** (conditions 22–28),
recorded here because none of them is met and no route can be adopted until
the ones it depends on are:

| # | condition | where it lands above |
|---|---|---|
| 22 | A ruling from Victor **naming the party that fixes a root**: not the verifier, never opens, does not retain or forward the commitment randomness. Without it the theorem has no product meaning | §1.6, §5.2 (R1) |
| 23 | The notion **written out as project-specific**, with R1/R2/R3 and the **excluded parties** in the product claim, as D7's qualifiers travel with the zkVM claim | §1.6, §5.2 |
| 24 | R2 enforced as "**one published path set of any kind per root**" — accepted, rejected or captured — with a capture-level gate and a negative control | O6 |
| 25 | The **joint conditional field sampler** and the **joint hypothesis** discharged, or `Δ_field` stays unbounded and the whole of §3 is moot | O1, O2 |
| 26 | **O5 restated against the actual shared 64-byte domain**, with the mechanical point-set check alongside the written composition argument | O5, §3.8 item 1 |
| 27 | The **architecture question settled in writing**: one transcript per private request end to end, or route (ii) at run boundaries. Until then "the multi-block story survives" must not be stated | §4.3, §5.1, §5.5 |
| 28 | The **mechanical invariants asserted in code and tested** | O4 |

### 5.4 What can be checked mechanically today, and what cannot

**Mechanically checkable now, on captured receipts with existing tools:**

- **O6.** A capture gate that refuses two retained receipts sharing an
  endpoint root or a context digest. The captures already carry both
  (`hashline/src/native_capture.rs:291`; the joint-view gate already reads
  them, `ZK60_NATIVE_JOINT_VIEW.md` §§1-2).
- **O4's invariant half.** Assert over every commitment in a receipt that
  `8·rows ∉ {40, 64}`, and over `SeamSpec`/`SeamSpecG` that
  `data_rows + MASK_ROWS ∉ {5, 8}`. Both are one-line checks and both are
  cheap negative controls (feed a synthetic 8-row commitment; the gate must
  fire). Two more belong in the same gate (condition 28): **no
  deployment-path commitment is reproducible from a seed**, and **no new
  accessor exposes `PreparedPlane`'s `CommittedZk`**, whose `data`, `pads`
  and `salts` fields are `pub`.
- **O3's arithmetic.** Recompute §3.3's node counts from a real receipt's
  own 256 paths and check them against the closed form. The thing §3.3
  predicts and no test currently checks is that the **top pair is revealed
  with probability `1 − 2^-255`** — so the gate must assert
  `A_{depth−1} = 2 − 2^-255`, or assert the revelation as an event on the
  actual paths. A gate that asserts `A_{depth−1} = 2` exactly is asserting
  something false with probability `2^-255` (correction 18); negligible in
  practice, wrong as written, and a gate is the wrong place to be wrong.
- **The `k = 1` architecture question of §4.3 — and note it is a question,
  not a claim.** The claim that the architecture is already there has been
  **refuted** for the private prover: the measured 32-layer pass is the
  public prover with public activations and the private path has no
  multi-block entry point (§4.3). What remains checkable is the narrower
  fact: that no commitment root appears in two openings anywhere in a
  32-layer receipt.

**Needs a written proof and an external reviewer:** O1, O2, O5. O1 and O2 are
the U-3 obligation the security owner already owns. **O5 is the one nobody
owns**, it is new in this document, and it should be added to the ledger
today.

### 5.5 The kill criterion

**Primary kill.** If **O1** is shown impossible at the pinned profile — that
is, if some functional of the joint view (including the nonlinear
cross-channel link `fin − c·g(ρ) = poly(terminals)`, which `ZK60_NATIVE_JOINT_VIEW.md`
§7 item 4 explicitly says the linear model cannot see) is shown to determine
a data direction, the way the two-opening recovery determines the plane in
case (c) — then case (a) is dead as well, and the custom line's P1 must move
to route 3 of §3.6: the endpoint openings become private witness
computations, i.e. the zkVM shape, and the custom line becomes a
throughput vehicle for a statement it cannot itself make private.

**Early warning, cheaper than the primary.** If the existing joint-view gate
ever reports a **nonzero disclosed data dimension on an endpoint role** once
the nonlinear channel is brought into the model — today it reports 0 on
Input and Output on all four captures
(`ZK60_NATIVE_JOINT_VIEW.md` §2.3, §9a) — stop and re-plan before writing any
of §5.2.

**Second kill, on the assumption rather than the algebra.** If **O5** cannot
be argued — if programming the oracle for privacy is shown to invalidate the
Fiat–Shamir soundness reduction on the same table — then route 1 of §3.6 is
ruled out for this system and only (ii) and the zkVM shape remain. That would
make the one-compression measurement of §4.2 urgent rather than prudent. As
stated, though, that is a proof-shaped criterion nobody will discharge or
refute cleanly, so a **sharper mechanical form belongs beside it**: *does any
64-byte point the simulator programs lie in the set of 64-byte points the
protocol itself answers?* — a finite, checkable statement about `hash_pair`,
`salt_leaf`, `hash_column` at 8 rows, and every `absorb` whose
`|label| + |data| = 16` (§3.8 item 1).

**Two further kills, both cheaper than the primary and both decidable
without cryptography.**

- **A product kill (condition 22), decidable this week.** If the party of
  §1.6 cannot be named — if every realistic committer is either the prover
  (in which case the standard game applies and no Game E theorem is needed,
  which is what D18 pins for the first MVP) or the verifier/regulator
  (excluded by R1) — then the theorem is worth nothing even if proved. This
  costs one question to Victor and should be answered **before** anything in
  §5.2 is written.
- **An architecture kill (condition 27), decidable by counting.** If an 8B
  private pass cannot be one transcript end to end — for memory, or because
  a "short runs of blocks" form is adopted — then route (i) does not survive,
  because a run boundary is a root opened by two proofs (§4.3's chaining
  paragraph). The `k = 1` claim that (i) leaned on is already refuted for the
  only pass that has been measured (§4.3).

**What is explicitly not a kill, and what the first version of this page got
wrong about it.** A reviewer objecting that (R1) or (R3) makes the notion
weaker than textbook NIZK zero knowledge is right, and that objection on its
own is not a kill. **But the defence originally offered here is withdrawn:**
it is *not* "the established commit-and-prove notion (LNS Def 2.8)" — the
cited source maps Def 2.8 to the game in which the simulator produces the
commitments (§1.6, hole 3). It is a new, project-specific notion. The honest
response is to name it as new and to write the weakening **and the excluded
parties** into the product claim, as D7 already does for the zkVM line's
three qualifiers — and to accept that the weakening is exactly what the
product kill above tests.

## 6. What I did not read, and what I could not determine

**Could not determine, and it is load-bearing:**

1. **Whether the round-2 two-point simulator tool can be exercised here.**
   `scripts/zk60_root_simulator.py` and `tests/test_zk60_sequential_kernel.py`
   exist **only on branch `zk60-mvp-fable`**, not in the main tree (checked
   2026-09-19). `tests/test_zk60_root_history_boundary.py` loads the pinned
   delivery through `git show` and **skips** if the commit is unavailable
   (lines 24-35). So the "validated, three tests, 0.068 s" record is a
   statement about that branch, and I did not re-run anything.
2. ~~**Whether the 32-layer pass is one proof with two external endpoints,
   or 32 statements sharing one transcript.**~~ **RESOLVED by the
   independent check, and the answer is the unfavourable one.** It is **32
   statements sharing one transcript with public activations**: `pass` calls
   the public prover `hashline::layer::prove_layer`
   (`hashline/src/bin/hashline.rs:25`, `:714`), building a per-layer
   `Statement` at `:717`, and `MVP_STATUS.md:137` labels that row "public
   IO". The private path has no multi-block entry point. §4.3's conclusion —
   that the `k = 1` architecture is already there — **is withdrawn**.
3. **The per-compression cost of a hash gadget in this arithmetisation.**
   §4.2's central figures (4,000 lookups, 2,500 committed words per SHA-256
   compression) are an **estimate with a factor-two band**, derived from the
   structure of SHA-256 against an 8-bit lookup arithmetisation. The project
   has no bitwise gadget to measure. The measurement is named in §4.2.
4. **Whether a structured SIS matrix exists that is both succinct for this
   verifier and binding for short vectors.** §4.2 gives a corrected argument
   against the one structure I tried (evaluation at fixed public points):
   for that structured `A` the short collisions are efficiently *findable*.
   It is not an exhausted search and it must not be cited as impossibility.
5. **The exact endpoint geometry a widened profile will adopt.** §3.3 costs
   both readings (`log_cols 8 / inv_rate 8` keeping 2,048 leaves, and
   `log_cols 14 / inv_rate 4` giving 65,536), because
   `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` §2.3 (P12) records the two-sources-of-
   truth hazard and the additive `SeamSpecG` fix without pinning which
   parameters it inherits. The privacy analysis is the same in both; the
   bytes differ by 18×.

**Read in full:** `ZK60_ENDPOINT_SIMULATION_MODEL.md`;
`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md`;
`ZK60_JOINT_VIEW_REVIEW_20260918.md`;
`ZK60_OPUS_ENDPOINT_EXPERIMENT_REVIEW.md`;
`ZK60_OPUS_ORACLE_BOOKKEEPING_REVIEW.md`; `ZK60_DECISIONS.md` entries D1,
D3–D5, D7–D12, D15, D17; `ZK60_MVP_JOINT_VIEW.md` §§0-7 (branch
`zk60-mvp-fable`); `ZK60_NATIVE_JOINT_VIEW.md` §§5, 7, 9a, 9b (branch
`zk60-native-jointview`); `zkp-core/src/pcs.rs` (the ZK half and
`hash_column`), `zkp-core/src/merkle.rs`, `zkp-core/src/transcript.rs`
(index sampling), `hashline/src/private_seam.rs`,
`hashline/src/zk_ffn_fresh_io.rs`, `hashline/src/private_block/protocol.rs`
(the endpoint half), the headers of
`tests/test_zk60_root_history_boundary.py` and
`tests/test_zk60_budgeted_endpoint_boundary.py`.

**Read only in part:** `ZK60_ROUND23/24/25.md` (headings and the endpoint
sections); `ZK60_PRIVATE_SEAM.md` (budget and limitations);
`ZK60_OPUS_SEAM_REVIEW.md` (headings only);
`ZK60_FABLE_SECURITY_OBLIGATIONS.md` (the endpoint/root/salt/Merkle grep and
the PCS row); `ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md` and its disposition (the
geometry pins and the errata table's endpoint rows);
`ZK60_L4_FEWER_HASHED_BYTES_MEMO.md` §B.2 and the option table;
`MVP_STATUS.md` §2. **Not read:** the attention construction memos, the
block construction memos and their checks, `ZK60_ROUND20/21/22.md`,
`ZK60_FABLE_TRANSCRIPT_REVIEW.md`, and the zkVM line beyond D3–D7.

**Nothing was built, run, tested, proved or benchmarked for this document.**
Every number labelled [COUNTED] is arithmetic from geometry or from a figure
cited to a measured source; every number labelled [ESTIMATE] is mine and is
banded. No file other than this one was created or modified.

*(original draft complete 2026-09-19; corrected the same day — see the
correction record below)*

## Correction record (2026-09-19)

Every numbered item of `ZK60_D8_D11_RESTATEMENT_CHECK.md` §8, applied in
place by a delegated editor working to
`ZK60_D8_D11_RESTATEMENT_DISPOSITION.md`. Items 1–10 are the check's HOLES,
11–21 its CORRECTIONS, 22–28 its CONDITIONS. Nothing in this record, and
nothing in the corrected text, establishes a privacy property; D8 and D11
stand as written in the register.

| # | kind | sections changed | what changed |
|---|---|---|---|
| 1 | HOLE | §0 step 1, §1.3, §1.4, §1.8 item 4, §2.6, §3.7, §4.1, §4.5, §4.6, §5.1 | "Within the hash layer, case (b) is either empty or equal to case (a)" **withdrawn everywhere**. §3.7 demoted from a result to an enumeration of what restriction R2 assumes, with the circularity stated (R2 contains the conclusion) and the two prior refusals cited; §1.4's "three consequences" relabelled bookkeeping; the (b) cells of the §4.6 table and the "would cover" lines of (i) and (v) rewritten to "assumed away by R2, which is circular" |
| 2 | HOLE | §1.6, §5.2 (R1), §5.1, §5.5 | R1 now says plainly that it **excludes the party who fixed the root from ever being the distinguisher** — a regulator who supplies *and* commits an input is excluded — and that no document names a third-party committer; the dichotomy (prover commits → standard game; third party commits → unnamed party) is written out, with condition 22 and a product kill in §5.5 |
| 3 | HOLE | §1.6, §1.8 item 3, §5.2 preamble, §5.5 | The LNS Definition 2.8 defence is **withdrawn**: the cited source maps Def 2.8 to the game in which the simulator produces the commitments. The notion is now named as **new and project-specific**, "established" removed, and it is removed from §5.5's "what is explicitly not a kill" |
| 4 | HOLE | §5.2 (R3) | R3 now records that it admits a second receipt on an independent commitment to the same plane (H7), which `Δ_field` does not cover, and names the two repairs: restrict `aux`, or extend `Δ_field` with round 23 as its only evidence (scope stated) |
| 5 | HOLE | §3.8 item 1, §5.3 (O5), §5.5, framing section | The "47-byte inputs, a different length, so no direct overlap" argument is **withdrawn as false**. `Transcript::absorb` is a 64-byte BLAKE3 input whenever `|label| + |data| = 16`, and `absorb_u64(b"log-cols", …)` is exactly that on the private path; Fiat–Shamir and the Merkle/leaf layer **share the untagged 64-byte domain**. The bound does not move (`2^-256` per candidate); O5 is restated against the real shared domain and the mechanical point-set check added beside it |
| 6 | HOLE | §5.2 preamble and displayed bound | The advantage expression is labelled **the statement the project would have to intend to prove, not a bound**, in the theorem itself, because `Δ_field` contains the unquantified U-3 term; "must never be quoted as a `2^-175`-class result" added |
| 7 | HOLE | §3.2 step 1 | "Sampling a real commitment to the all-zero plane … gives exactly the right law" **deleted**; replaced by the two verifier identities that condition the matrix (`pcs.rs:976-979`, `:1022-1030`) and a pointer to the unbuilt joint conditional sampler O1. The pad argument is retained as a linear-channel statement, with `d ≤ q_pad` justified |
| 8 | HOLE | §3.2 step 2, §5.2 (new R4) | "Same law in both worlds" replaced by the **PRG assumption on `ZkRng`**, stated in the direction needed (published later outputs must not reveal earlier secret outputs), with the shared-stream sources cited; promoted into the theorem as restriction R4 beside salted-leaf hiding |
| 9 | HOLE | §4.3, §5.1, §5.4, §6 item 2 | "The multi-block story survives" and "the `k = 1` architecture is already there" **withdrawn**. The measured 58.40 s pass is traced to the **public** prover, 32 statements sharing one transcript with public activations; the private path has no multi-block entry point; the architecture decision is named as condition 27 and as an architecture kill |
| 10 | HOLE | §1.3 (table and the paragraph after it), §1.4, §1.5, §1.8 item 4, §3.7, §4.1, §5.2 (R2), §5.3 (O6) | **H8** (rejected-but-emitted receipt) and **H9** (retained capture) added as reachable histories; R2 restated as "no **published path set of any kind** — accepted, rejected or captured"; §1.5 now says the types enforce "one `finish`", not "one published path set" |
| 11 | CORRECTION | §0 step 2, §4.2, §4.6, §5.1 | The "60–160 % of the entire budget" verdict **withdrawn as a category error**. Replaced by the relative figures **+5.5 % of a public pass, +12.6 % of a private one**, with **+0.28 s of a 5 s budget** under a uniform 11.7× speedup, and the explicit caveat that a speedup which does not help the gadget leaves the absolute figure right for that part |
| 12 | CORRECTION | §4.2 Pedersen bullet | Reason replaced: a Ligero opening *is* a linear functional of the rows and CP-link does not need both sides homomorphic; the valid obstruction is non-native elliptic-curve arithmetic over Goldilocks. Conclusion kept |
| 13 | CORRECTION | §4.2 SIS bullet, §6 item 4 | The pigeonhole argument is corrected: it proves too much (it applies to a random `A` as well, and SIS binding is computational). The right statement — for this structured `A` the collisions are efficiently **findable** — substituted, and the "not an impossibility" flag strengthened |
| 14 | CORRECTION | §1.3 H7 row, §2.6, §3.7 H7 row | "The joint analysis is not done" (citing `ZK60_ROUND23.md:29`, a heading) replaced with round 23's measured result — zero disclosed base dimensions over 88,064 shared unknowns, four with every private commitment, 256 in the control — and its scope: fixed coefficients, two captures, field channels only, excluding CFS/pad/encoded-column/Merkle and adaptive composition |
| 15 | CORRECTION | §3.5 table and total, §3.8 item 2, §5.2 | The freshness union now covers the simulator's whole honest query count `Q_S` (its `A`/`H`/`M` trees and the transcript), order `3 × 10^4`, giving `≈ 2^-241` in place of `2^-244`; the constant `2·(q + 2nn − 2)` replaced by `m·(q + Q_S)` |
| 16 | CORRECTION | §3.5, §4.1, §4.6 (scope note), §5.2 | "Exactly two top-node programming calls" scoped to the pinned tiny profile; **64 caller-fixed endpoint roots** at a feed-forward-only 32-layer private pass (D17 rule 4) recorded, and the theorem restated for `m` roots |
| 17 | CORRECTION | §3.1 | `32 + 8,192 + 90,112 = 98,336` corrected to `8,192 + 90,112 = 98,304` of 131,072 = **exactly 75.00 %**; the root's 32 bytes travel in the 112-byte policy, not in `ENDPOINT_OPEN_BYTES` |
| 18 | CORRECTION | §3.3, §5.4 | "The top pair is *always* revealed / `A_{10} = 2.0` exactly" replaced by **probability `1 − 2^-255`**, with `A_{depth−1} = 2 − 2^-255`; §5.4's proposed gate rewritten so it does not assert something false with probability `2^-255` |
| 19 | CORRECTION | §1.7, §6 (item 4 deleted, later items renumbered) | The `2^-64` / `2^-96` question is **no longer presented as open**. §1.7 now cites D9's verification note (`ZK60_DECISIONS.md:394-408`): statistical distance exactly `2^-96` per draw, per-outcome relative bias exactly `2^-64`, `6144·2^-96 = 2^-83.4`, `2^21·2^-96 = 2^-75.0`; O10 F10.4 named as the document that states it wrongly, and the two source comments named. §6's item 4 deleted |
| 20 | CORRECTION | §4.2 tiny shape, §4.6 | "+13 % committed words" replaced by **+15.2 %** against the stated denominator, the message-part committed words `(702 + 1,326 + 20 + 2×7) × 256 = 527,872`; the missing denominator called out |
| 21 | CORRECTION *(in the draft's favour)* | §3.5, §2.6 | **Added:** the two-point construction has **no ordering problem** — the programmed point is the top node, independent of the 256 indices, which are drawn only after the group and proximity vectors are absorbed (`pcs.rs:922-928`), so the simulator's tree is complete before any index exists. Contrasted with the round-23 free-handle construction's late salted-leaf programming |
| 22 | CONDITION | §1.6, §5.3 (conditions table), §5.5 | Recorded: a ruling from Victor **naming the party that fixes a root**, and the matching product kill. No text elsewhere claims such a party exists |
| 23 | CONDITION | §1.6, §5.2 preamble, §5.3 (conditions table) | Recorded: the notion written out as project-specific with R1/R2/R3 and the **excluded parties** in the product claim, as D7's qualifiers travel with the zkVM claim |
| 24 | CONDITION | §5.3 (O6 and conditions table), §5.2 (R2), §4.1 | Recorded: R2 enforced as "one published path set of any kind per root", with a capture-level gate and a negative control |
| 25 | CONDITION | §5.3 (conditions table) | Recorded: O1 and O2 discharged, or `Δ_field` stays unbounded and §3 is moot. §3.5's closing paragraph already said §3 is conditional on O1 and is unchanged |
| 26 | CONDITION | §3.8 item 1, §5.3 (O5 and conditions table), §5.5 | Recorded: O5 restated against the actual shared 64-byte domain, with the mechanical point-set check |
| 27 | CONDITION | §4.3, §5.1, §5.3 (conditions table), §5.5 | Recorded: the architecture question settled in writing — one transcript per private request end to end, or route (ii) at run boundaries — and the instruction that until then "the multi-block story survives" must not be stated |
| 28 | CONDITION | §1.5, §5.3 (O4 and conditions table), §5.4 | Recorded: the mechanical invariants — `commitment_rows ∉ {5, 8}`; `8·rows ∉ {40, 64}`; no deployment-path commitment reproducible from a seed; no new accessor exposing `PreparedPlane`'s `CommittedZk`, whose `data`, `pads` and `salts` fields are `pub` |
| — | **RE-TITLING AND RE-FRAMING** | title, status line, §0 step 1, §0 closing, §2.6, §4.1–§4.6 ("Closes:" → "Would cover:"), §5 heading, §5.1, §5.2 heading, §6 sign-off | Per the disposition: the page is no longer a recommendation. New title and status line; §5 renamed and §5.1 rewritten so the proposed (i) + (v) route is recorded as **ATTEMPTED AND REFUSED**, quoting what was proposed and giving the two reasons (circular restriction R2; the root-fixer excluded from being the adversary), kept as a record of what does not work |
| — | **NEW SECTION** | "Where this stands after ruling D18", immediately after the status line | States that for the first MVP the prover generates every commitment at proof time, so the configuration D8/D11 bind **does not arise in the first MVP's artifacts** and the standard privacy game applies to them — explicitly not a privacy acceptance, with the joint-view checks and U-3 unchanged; that the obligation binds from the day a third party fixes a commitment in advance; that the expected route then is the **sealed handle**, scoped in `ZK60_SEALED_HANDLE_SCOPING.md` (commissioned 2026-09-19); and the six durable facts the check confirmed |

**Applied without needing a text change:** none — every numbered item above
either changed text or added a recorded condition. **Not changed:** anything
the check judged sound (the hash-layer counts of §3.3, which reproduce
exactly; the enforcement audit of §1.5, confirmed on every code path; §3.6's
trilemma, which stays demoted to a taxonomy; §2.1's proved two-opening
recovery).
