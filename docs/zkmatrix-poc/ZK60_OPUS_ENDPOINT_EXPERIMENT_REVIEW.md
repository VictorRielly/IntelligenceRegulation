# O9 — the endpoint security experiments, reviewed against the real interfaces

Reviewer: Claude Opus 5, independent reviewer, 2026-09-09 (task O9 of
[ZK60_OPUS_QUEUE.md](ZK60_OPUS_QUEUE.md)).
Review baseline: `c5eb2019353fdf56f1a115edb0c424bf86a9c195` on
`perf/zk-batch-optimizations`.
Sources reviewed: [the endpoint model](ZK60_ENDPOINT_SIMULATION_MODEL.md),
`hashline/src/zk_ffn_fresh_io.rs`, `hashline/src/private_seam.rs`,
`zkp-core/src/{pcs,merkle}.rs`, `scripts/zk60_endpoint_simulation.py`, and
FA8 [ZK60_FABLE_TRANSCRIPT_REVIEW.md](ZK60_FABLE_TRANSCRIPT_REVIEW.md) §A.2–A.4.

**Privacy target is unchanged.** P1 hides inputs, outputs and intermediate
activations with public weights allowed; P3 additionally hides weights. Nothing
below narrows that target, and no experiment here is satisfied by publishing IO.

## 0. Verdict in plain words

The model document's central distinction — joint preparation simulation versus
simulation for an externally fixed root — is correct, correctly motivated, and
correctly declared unfinished. Its two cited definitions check out against the
primary sources, with one labelling correction (§5).

Three things it leaves implicit, which this review makes explicit and which
change how the games must be written:

1. The prover and the verifier do **not** accept the same statement space. The
   verifier accepts arbitrary caller-supplied roots; the honest prover can only
   ever prove for roots it just generated. So the joint-preparation game covers
   the prover's entire reachable behaviour and still leaves the deployed
   verifier's statement space uncovered (§2, F2).
2. Repeated proofs against **one fixed endpoint root are unreachable** through
   the public API. That is a structural property of the types, not a policy
   (§3, F1). It bounds what "repeated requests" can mean in either game.
3. No public interface admits simulator-chosen preparation randomness, so
   `SimPrepare` is a new interface rather than a re-parameterisation of an
   existing one (§3, F3).

FA8's §A.2 (H4) disjoint-oracle-domain premise is false as stated, and Codex's
correction is right. This review adds the sharper statement: the three
commitment-layer hash uses are separated **only by input length**, and that
separation degenerates at exactly eight rows (§4, F4).

Nothing here establishes zero knowledge, and nothing here recovers a private
endpoint value. No unexpected disclosure was found.

## 1. The interfaces that actually exist

Every row was read at the review baseline; line numbers are that baseline's.

| Interface | Source | Visibility | What it does |
|---|---|---|---|
| `IoSpec::new(context, in_scale, out_scale)` | `zk_ffn_fresh_io.rs:29` | `pub` | trusted request metadata; validates two `SeamSpec`s |
| `ExpectedIo::from_roots(spec, input, output)` | `:55` | `pub` | builds the public policy from **arbitrary** digests; forces `rows = 7`, `log_cols = 8` |
| `ExpectedIo::to_bytes` / `from_bytes` | `:76` / `:86` | `pub` | the 112-byte policy; `from_bytes` accepts any well-formed roots off the wire |
| `prepare_endpoints(spec, input, output)` | `:109` | `pub` | the only honest producer: two `private_seam::prepare` planes, roots taken **from** them |
| `Endpoints` | `:104` | `pub` type, private fields | no `Clone`, no serialisation, no value getter |
| `prepare(w, privacy, expected)` | `:148` | `pub` | binds the policy into the transcript, draws `ZkRng::from_os`, `seed: None` (`:157`) |
| `PendingProof::finish(endpoints)` | `:276` | `pub` | consumes owners on success **and** failure; `compile_fail` doctest at `:126` forbids a second `finish` |
| `check_endpoints(expected, endpoints)` | `:258` | private | refuses unless both owner roots equal the policy roots (`:265`) |
| `verify(st, weights, expected, receipt)` | `:412` | `pub` | rebuilds the transcript from the policy; opens 256 positions per endpoint under `pcs_for(8)` |
| `private_seam::prepare` | `private_seam.rs:186` | `pub` | `ZkRng::from_os(DOMAIN)` at `:196` |
| `private_seam::prepare_with_rng` | `:200` | **crate-private** | the only randomness-injecting path; not reachable by a simulator |

The 112-byte policy decomposes as **48 bytes of statement** and **64 bytes of
commitment**: `b"HFFNEXP1"` (8) ‖ context (32) ‖ `input_scale` (4) ‖
`output_scale` (4) ‖ input root (32) ‖ output root (32) (`:76`–`:84`). This
split matters in §5: the imported definition separates the statement `x` from
the commitments `c_i`, and here they arrive concatenated in one absorbed blob.

`transcript()` (`:138`) absorbs `expected-IO` (the whole 112 bytes) and then a
fixed parameter string, before any FFN message. Both roots are therefore fixed
before every challenge in the proof.

## 2. The two experiments, written out

Notation: `pp` = public parameters (profile string, shape `T32/d16/f16`,
`log_cols 8`, `inv_rate 8`, `Q256`); `x` = (context, input_scale, output_scale);
`c_in`, `c_out` = the two endpoint roots; `w` = the endpoint values plus the FFN
witness; `O` = the hash oracle; `q` = the distinguisher's total oracle queries.

### Game J — joint preparation and proof

Covers the honest workflow `prepare_endpoints` → `prepare` → `finish`.

| Phase | Real world | Ideal world |
|---|---|---|
| setup | `pp` published; `D` may query `O` freely | same; `S` holds its own state, no `w` |
| choose | `D` picks `x` and the endpoint values in `w` | `D` picks the same; `S` is **not** given them |
| prepare | `prepare_endpoints` draws `ZkRng::from_os`, returns `(ExpectedIo, Endpoints)`; `c_in`, `c_out` published | `SimPrepare(x, dims)` publishes its own `c_in`, `c_out` and keeps private simulator state |
| fix | the caller absorbs the 112-byte policy (`:140`); roots are now fixed for the rest of this experiment | identical |
| prove | `prepare` + `finish(endpoints)`; receipt published | `SimProve(sim_state, policy)` publishes a receipt |
| refusal | `check_endpoints` root mismatch (`:268`), witness-shape refusal (`check_witness`), or identity failure; owners consumed either way (`:274`) | `S` must reproduce the same refusal event and the same consumption |
| output | `D` sees `pp`, policy, receipt or refusal, and all its own oracle answers; `D` outputs one bit | identical |

Timing that must be honoured: `S` publishes roots **before** it learns which
columns will be opened, because the roots enter the transcript that derives the
challenges that select the columns. Codex's candidate respects exactly this
ordering (`zk60_endpoint_simulation.py:69`–`78`, roots built in `__init__`;
columns supplied later in `open_once`).

Side information explicitly allowed to `D`: prior oracle history, correlated
public views from earlier experiments, and the public model/weight policy (the
public `W` root under P1). Explicitly **not** allowed to `S`: any endpoint
value, any real mask/pad/salt, any real `PreparedPlane`, or the real
`ZkRng` stream. Aborts are outputs, not silent restarts.

**What Game J does and does not settle.** It settles the honest owner-generated
workflow. It does not settle any statement in which the roots pre-exist the
simulator, because `SimPrepare` chose them.

### Game E — proof simulation for an externally fixed root

Covers the deployed verifier: `ExpectedIo::from_bytes` off the wire, then
`verify`.

| Phase | Real world | Ideal world |
|---|---|---|
| setup | `pp` published | same |
| fix | environment fixes `x`, `c_in`, `c_out`, where the roots are honestly generated commitments to some endpoint values (so the statement is in the language) and the opening randomness is **not** given to `S` | identical |
| prove | honest prover holding the matching `Endpoints` runs `finish` | `SimProve(x, c_in, c_out)` alone |
| output | `D` sees `pp`, policy, receipt, refusals, oracle answers | identical |

This is ordinary zero knowledge for the relation the verifier actually checks.
It is the open obligation, and it is hard here for a reason the model document
states correctly: an accepted proof carries 256 authentication paths per
endpoint under a root `S` did not create, and a path exposes a pair of
child digests hashing to that root. With BLAKE3 unprogrammable, `S` is not
handed such a preimage.

**Do not narrow this by declaring the deployed interface to be Game J.** The
verifier has no way to tell that a root was produced by `prepare_endpoints`;
`ExpectedIo::from_bytes` (`:86`) accepts any 112 well-formed bytes, and the
doc comment at `:47` says so ("Reading this from an untrusted producer does NOT
authorize those endpoints").

## 3. Findings about reachability, and what they do to the games

**F1 — repeated proofs against one root are structurally unreachable.**
`Endpoints` has no `Clone` and no serialisation (`:103`–`:107`); `finish` takes
it by value and consumes it on both paths (`:274`–`:277`); the `compile_fail`
doctest at `:126` pins the second-use rejection at compile time; and
`prepare_endpoints` always draws fresh OS randomness (`private_seam.rs:196`),
so calling it twice on the same values yields two *different* roots. Therefore
the public API admits exactly one proof per endpoint commitment.

Consequence for both games: "repeated requests" can only mean **distinct roots
over shared underlying data**, never repeated openings of a fixed root. Any
future owner export/import, owner reuse, or root import interface reopens this
and must be re-reviewed; the model document lists those as uncovered, which is
consistent.

**F2 — prover and verifier statement spaces differ.**
`check_endpoints` (`:265`) refuses unless the owner's own roots equal the policy
roots, so the honest prover's reachable statement set is exactly
`{roots it just generated}`. The verifier's accepted set is all well-formed
roots. Game J covers the former completely and the latter not at all. This is
the precise reason Game E cannot be retired.

**F3 — `SimPrepare` is a new interface.**
The only randomness-injecting entry point, `private_seam::prepare_with_rng`
(`:200`), is crate-private; the public `prepare` (`:186`) hard-codes
`ZkRng::from_os`, and `zk_ffn_fresh_io::prepare` hard-codes `seed: None`
(`:157`). A simulator cannot be obtained by re-parameterising the existing
code path. The model document's numbered `SimPrepare`/`SimProve` interfaces are
therefore proposals for new code, and should be labelled as such so that no
later reader mistakes them for existing behaviour.

**F6 — refusal is an observable, state-consuming event.**
`finish` documents consumption "on success or failure" (`:274`) and
`check_endpoints` returns a distinguishable error string (`:268`). A
distinguisher learns one bit — whether the caller held owners matching the
policy — and learns that the owner is now spent. Both games above therefore
include refusal in the view; testing accepted proof bytes alone is insufficient,
as the model document already says.

## 4. The oracle-domain correction, verified and sharpened

FA8 §A.2 (H4) asserts that the prefixes `hashline-v1/`, `hashline-zk-rng/`,
`hashline-zk-os-rng/v1/`, `hashline-stable-slot-record-v1/` and length framing
"make the oracle points of the four uses disjoint", and (H2) treats
`hash_column`, `salt_leaf` and the Merkle nodes as one never-programmed family.

Read at the baseline:

```
zkp-core/src/merkle.rs:14   hash_pair(a: &Digest, b: &Digest)  -> BLAKE3(a ‖ b)      32+32 = 64 B
zkp-core/src/pcs.rs:640     salt_leaf(leaf: &Digest, salt)     -> BLAKE3(leaf ‖ salt) 32+32 = 64 B
zkp-core/src/pcs.rs:137     hash_column(col: &[Fp])            -> BLAKE3(rows·8 B)
```

None of the three carries a tag or a length frame; each is a bare
`blake3::Hasher` fed raw bytes. **H4 is false for these uses**: salted leaves
and Merkle nodes are the same function on the same 64-byte domain. This is a
statement about oracle *input sets*, not a collision claim — no collision is
searched for or needed.

**F4 — the remaining separation is by length alone, and it degenerates at eight
rows.** `hash_column` inputs are `rows · 8` bytes (`pcs.rs:139`–`:141`;
`hash_columns` builds the same buffer at `:153`–`:158`). The current profile's
row counts are: endpoints 7 (56 B), `A` 702 (5 616 B), `H` 1 326 (10 608 B),
P3 `W` 11 (88 B) and mask `M` 20 (160 B), all read from the four round-22
capture cases in `results/zk60_round22_captures.json`; and P1's public `W` 3
(24 B), read from the row assertion at `zk_ffn_fresh_io_tests.rs:79`–`:82`
(P1's `W` is public, so it is not one of the manifest's private roles).
None equals 64 B, so column hashes are today
disjoint from the node/leaf domain **by accident of dimension, not by design**.
A commitment with exactly 8 rows would put all three uses on one domain. This is
not a defect in the frozen proofs and requires no format change; it is a
constraint any completed reduction must carry, and a reason to prefer an
explicit tag if the format is ever revised.

Codex's candidate honours the corrected premise: one `RandomOracle.table`
serves nodes, inner column hashes and salted leaves
(`zk60_endpoint_simulation.py:23`–`39`), and `program_fresh` refuses a point
that already has an answer (`:34`–`:36`). Its `column_bytes` fixes seven words
(`:42`–`:45`), i.e. 56 B, so the tool reproduces the production length gap and
never exercises the 64-byte-column case.

## 5. The imported definitions, checked against the primary sources

Both papers were fetched and read for this review; neither was taken on trust.

**Lyubashevsky, Nguyen, Seiler, *Shorter Lattice-Based Zero-Knowledge Proofs via
One-Time Commitments*** (eprint 2020/1448, full version of PKC 2021).
Definition 2.8 (Simulatability) exists and reads, in the real world:
`ck ← Gen(1^λ)`, `(x, m_1..m_n) ← A(ck)`, `r_1..r_n ← χ`, `c_i = Com_ck(m_i; r_i)`,
`π ← Prove_ck(x, (m_1,r_1)..(m_n,r_n))`; in the ideal world
`(π, c_1..c_n) ← SimCom_ck(x)` then `SimProve_ck(x, c_1..c_n)`; both gated on
`(ck, x, (m_1..m_n)) ∈ R_L`. The paper then states the distinction verbatim:
"The difference between simulatability and zero-knowledge is that randomness
`r_1,…,r_n` is directly generated from χ as it would in the real-world protocol
rather than chosen from adversary."

**Disposition: the model document's use of this citation is correct.** Def 2.8
is precisely joint commitment/proof simulatability and is explicitly not ZK for
adversarially chosen commitment randomness. Two precisions for our mapping:
(a) the adversary still chooses the *messages* `m_i`, so the analogue is that
`D` may choose the endpoint values while the commitment randomness stays
honest — which is what Game J says; (b) in Def 2.8 the commitments are outputs
*separate from* `x`, whereas our 112-byte policy concatenates them (§1), so the
mapping is `x` = the 48-byte statement part and `c_1, c_2` = the two roots. The
mapping is sound once written that way, and should be written that way.

**Faonio, Fiore, Kohlweiss, Russo, Zając, *From Polynomial IOP and Commitments
to Non-malleable zkSNARKs*** (eprint 2023/569).

- **Definition 8 is Succinctness**, not simulator machinery.
- **Definition 9 (Wrappers for NIZK Simulator)** is the stateful one: the
  algorithms "are stateful and share their state `st = (st_S, coms, Q_sim,
  Q_RO, Q_aux)`", with `S_1(x, aux)` answering proof requests, `S_2(s, aux)`
  answering random-oracle queries against `Q_RO`, and `S^F_1(x, w)` running
  `S_1(x, F(x,w))` — introduced explicitly "to model leaky-zero-knowledge".
- **Definition 10 (Zero-Knowledge)** gives the ZK experiment and then the weaker
  notion: "A NIZK is `F`-leaky zero-knowledge if its proofs may leak some
  information, namely a proof leaks `F(x,w)` … by giving the zero-knowledge
  simulator the value `F(x,w)`, which should be interpreted as a hint."

**Disposition: substance correct, range off by one.** The model document's claim
— a stateful simulator handling proof requests and oracle queries together, and
witness-dependent auxiliary leakage as a *weaker* notion — is exactly what
Definitions 9 and 10 say. But the cited range "Definitions 8–10" should be
**Definitions 9–10**; Definition 8 is Succinctness. Correcting the range does
not weaken the model document's argument, and its accompanying sentence ("We do
not supply real endpoint secret state under the name of auxiliary input") is the
right reading of Def 10's `F`-leaky notion: supplying `F(x,w)` is a documented
*weakening*, so any future use of it must be declared, not absorbed silently.

## 6. FA8 premise dispositions

| FA8 premise | §A.2/A.3 statement | Disposition at this baseline |
|---|---|---|
| H1 transcript programmable at squeeze points only | `transcript.rs` 44–94, prefixed and length-framed | **Retained.** Not re-derived here; unchanged by the endpoint work. Codex's candidate does not rely on it. |
| H2 `hash_column` / `salt_leaf` / nodes never programmed | treated as one unprogrammed family | **Superseded for the candidate.** `zk60_endpoint_simulation.py:101` programs salted-leaf points. That is an extension of the proof model, as the model document states; it is not FA8 applied unchanged. |
| H3 keyed XOF of `ZkRng::from_entropy_reader` pseudorandom | `rng.rs` 44–61 | **Retained**, not re-derived here. |
| **H4 four uses occupy disjoint oracle points** | prefixes + length framing | **False as stated.** `merkle.rs:14` and `pcs.rs:640` are the same untagged 64-byte BLAKE3 domain. Length is the only remaining separator, and it fails at 8 rows (F4). |
| G1 mask-functional surjectivity onto `S` | FA6 §2.2 | **Out of O9's scope**; untouched by the endpoint interface. Round 21 checked the two IO slots' fibres separately. |
| G2 M opening a deterministic function of `V` plus pads | FA6 §3, I5 | Out of scope here; carried by rounds 20–21. |
| G3 `disclosed_dim = 0` for `A`, `H` (public identity only), P3 `W` | FA3 §9 | **Independently reproduced for the IO profile** by O8 and re-reproduced on fresh captures (`1ca12e4`): `A`=0, `H`=2 (its public LogUp identity), `Input`=0, `Output`=0, `W`=0. |
| G4 pad budget / coset bijection | FA2 §14.6 | Out of scope here. |
| G5 the emitted observation set of one proof | FA7 §4 | **Extended, not invalidated**: the IO profile adds the two endpoint openings and the two extra M slots, which O8 enumerated. |
| G6 challenge ordering and 128-bit reductions | FA5 §4.1 | Retained; the endpoint roots are absorbed before every challenge (`:138`–`:145`), which is what the games need. |
| G7 block transcript order | FA3 §12.2 | Superseded for this profile by the `/2` order `M, W, A, H, Input, Output`. |
| G8 one OS stream per component per attempt | FA6 §5 | **Retained and reinforced**: `private_seam.rs:196` and `zk_ffn_fresh_io.rs:164` each draw `ZkRng::from_os`, and F1 shows owners cannot be reused. |
| A.4 "not taken as given" list | — | Still not given. The endpoint work does not close any of it. |

## 7. What remains unsupported

1. **Game E in full.** No construction is proposed for simulating a proof under
   a root the simulator did not create. FA8's simulator cannot be transplanted:
   it builds its own zero-data commitments and never programs Merkle/leaf
   hashes, so its paths do not authenticate under a foreign root.
2. **The joint field-view sampler.** Both games need the columns fed to step 2
   to be sampled from the real conditional distribution. Rounds 20–23 supply
   conditional components at fixed challenges; none of them is that sampler.
3. **Adaptive Fiat–Shamir.** Choosing columns after seeing the root, as the
   candidate's tests do, checks consistent late assignment only.
4. **A whole-view bound.** The `q / 2^256` figure is the local fresh-query
   bound for one programmed salted leaf. It omits the coupling to committed
   polynomials, sumcheck distributions, preparation side information and every
   other bad event. O10 carries this further.
5. **P3 weight privacy and model identity**, and a complete private block. None
   is enabled by this review.

## 8. Validation

No production Rust, transcript, proof format or attention construction was
changed. This review adds one document and one result record. Commands, exits
and SHA-256 digests for every source and tool byte read are recorded in
[`results/zk60_opus_endpoint_experiment_review.json`](../../results/zk60_opus_endpoint_experiment_review.json).

The two primary references were fetched and their definitions extracted and
quoted above; their PDF digests are in the result record so a later reader can
confirm the same documents were read.
