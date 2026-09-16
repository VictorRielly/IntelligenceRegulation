# ZK60 MVP security decision, round 2 — the joint view, the two disputed points, and what still blocks the tiny P1 block

| | |
|---|---|
| Author | Claude Fable 5.1 (interactive session), 2026-09-15 |
| Baseline | `763e308`; lane `zk60-mvp-fable` (worktree `/home/victor/wt-zk60-mvp-fable`) |
| Supersedes | §2 ("external-root obligation closes") of the archived [round-1 memo](ZK60_MVP_SECURITY_DECISION.md); keeps its §1, §3 table, §4–§7 |
| Answers | the "Next acceptance gate" of [Codex's disposition](ZK60_MVP_REVIEW.md) |
| Scope guard | P1 hides inputs, outputs and intermediate activations; weights may be public. Nothing here narrows that set. No whole-proof privacy acceptance is claimed. |
| Evidence | `results/zk60_mvp_joint_view_evidence/` (see §7 for what ran and what did not) |

## 0. The ruling in one paragraph

Codex is right on the requirement and the round-1 memo is right on the mechanism, and the two are compatible. **The caller-fixed external-root obligation stays.** It is not closed by the API's consuming types, because the mathematical statement takes two roots the verifier did not produce. It is met without any protocol change by a simulator that programs exactly one random-oracle point per endpoint root, the point whose output the honest committer's hidden top pair already occupies, and nothing else; that is the same random-oracle model the Fiat–Shamir soundness of the whole system already assumes, and it is the round-23 candidate reduced from 482 salted-leaf programmings to two node programmings. **The adaptive lift is a correct lemma with a hypothesis Codex correctly says was not established**: the hypothesis is witness-independence of the *joint* law of every published field value at every fixed challenge vector, with all randomness shared, not per-channel marginals. Codex's `H(mask), mask ⊕ w` example violates that hypothesis (its joint law depends on the witness) and therefore does not contradict the lemma; it shows why the hypothesis must be joint. This round builds the joint fixed-challenge view over the actual captures, PCS side and CFS side together, replays the complete challenge history from BLAKE3, and states the oracle layer explicitly. What blocks the tiny P1 block is unchanged from round 1 §4: the private attention schedule and block composition, which are engineering under the §6 discipline of that memo and can start now.

## 1. The two disputed points, adjudicated

### 1.1 External roots: the obligation stands, and it is met with two programmed points

The requirement text is explicit. [The privacy requirements](ZK60_PRIVACY_REQUIREMENTS.md) say acceptance covers the complete verifier view "including … endpoint binding", and that an unresolved simulator argument "is not permission to shrink the private set". [The endpoint model](ZK60_ENDPOINT_SIMULATION_MODEL.md) names root-only simulation "the outstanding obligation for the general `from_roots` interface". Round 1 §2 argued from the Rust API that the root-only game is unreachable; that argument confuses the supported implementation with the statement. The verifier's statement is `(context, scales, R_in, R_out, W)`; whoever produced `R_in` is not part of the verifier's view. So the game to win is: given two roots produced honestly by a committer whose data and salts the simulator never sees, produce a view indistinguishable from the honest prover's.

Round 1 §2(c) is nevertheless a correct fact and it decides the mechanism: an accepting receipt reveals, for each endpoint, a pair of level-one digests `(l, r)` with `BLAKE3(l‖r) = R`. Without programming, a simulator that does not hold the honest tree can produce such a pair only by inverting a 32-byte digest. So every hash-Merkle commit-and-prove system meets root-only zero knowledge only in the programmable random-oracle model. That model is already assumed by this system: Fiat–Shamir soundness of the same transcript rests on it. Within it the construction is:

- `RootOnlySim(R_in, R_out, public statement)`: run the honest `/2` prover on the all-zero valid witness with fresh OS randomness (this is round 1's simulator, unchanged, and it programs nothing on its own), except that each endpoint tree is built over zero data with fresh salts and its top-level pair `(l′, r′)` is bound to the caller's root by programming the single fresh point `l′‖r′ ↦ R`. Two programmed points per proof. Every other node, leaf and transcript hash is a genuine oracle query. The 11-sibling paths, salts and columns served for the 256 opened positions are those of the fresh zero tree.
- Oracle history: the simulator refuses if `l′‖r′` was already answered (probability at most `q/2^256` for `q` prior answers, since `l′` and `r′` are outputs on fresh salted inputs). The distinguisher can tell the worlds apart only if it can exhibit two 64-byte inputs mapping to `R`, i.e. if it already holds the honest committer's `(l, r)`, which requires the committer's secret salts or a `2^-256`-per-guess event. That is the one-table overlap accounting the round-23 model asked for, and it is exactly the "prior oracle history" clause of Codex's gate.
- Joint preparation workflow (`SimPrepare`/`SimProve` of the endpoint model): the same simulator with the programming step deleted; it issues the roots of its own zero trees and programs nothing. The two workflows are not interchanged: root-only programs two points, joint programs none, and the same field-level simulator serves both.

`scripts/zk60_root_simulator.py` implements both simulators as exact oracle bookkeeping in one table (nodes, salted leaves and every other 64-byte call share it), with a distinguisher that verifies every path under the fixed roots in both worlds, a control showing the collision detection fires exactly when the distinguisher holds the honest top pair, and a control showing the fresh-point refusal. Real BLAKE3 cannot be programmed; the tool is the bookkeeping of the reduction, not a receipt.

What this changes in the ledger: round 1 marked "arbitrary external-root simulation" as *not blocking, stop spending*. Corrected: it is *met by the two-point programming step of the simulator above, in the random-oracle model already assumed*; it remains listed as an obligation with its bound, not deleted.

### 1.2 The adaptive lift: a correct lemma whose hypothesis is the joint fixed-challenge law

Lemma (sequential kernel). Let the prover publish messages `m_0, m_1, …, m_n`; let the challenge `r_j` after `m_j` be any function `H` of the public prefix; let `m_j` depend only on the witness, the prover's private randomness and `r_<j`. If for every fixed challenge vector `ρ` the joint law of `(m_0, …, m_n)` given `ρ` is the same for witnesses `w` and `w′`, then for every `H` the law of the whole view `(m, r)` is the same for `w` and `w′`. Proof: by induction on `j`, the kernel `K_j(m_j | m_<j, r_<j)` is a ratio of two marginals of the per-`ρ` joint law (which by hypothesis is witness-independent for every `ρ`, hence for every prefix `r_<j`); the challenges are deterministic in the public prefix; the joint law is the product of the kernels and the challenge indicators. Public refusal events that are functions of the public prefix inherit the same law; witness-dependent refusal events break it (the LogUp collision of round 1 §1 is the one such event in `/2`, at most `(lookups + table rows)/2^128` per proof).

`tests/test_zk60_sequential_kernel.py` checks the lemma exhaustively on finite toy protocols: a masked protocol satisfying the hypothesis is adaptively indistinguishable for every challenge function; Codex's `H(mask), mask ⊕ w` view has witness-independent marginals but a witness-dependent joint law, so the hypothesis fails and the lemma does not apply; a two-message protocol sharing one mask has witness-independent marginals and an adaptive distinguisher, so marginals are insufficient; witness-dependent refusals break the conclusion.

Consequence for `/2`: the fixed-challenge evidence is exactly the right kind of evidence, provided it is *joint*. Rounds 20–25 established it channel by channel. What this round adds is the joint computation, PCS side and CFS side, at the actual captured coefficients, with the complete challenge history replayed rather than trusted.

## 2. The joint fixed-challenge view (what was built)

The view of a `/2` receipt splits into hash-layer objects (roots, salts, paths) and field-valued objects. The hash layer is handled by the salted-leaf hiding of unopened columns and by §1.1. Every field-valued object is an affine function of the prover's randomness for a fixed witness and fixed challenges:

| Object | Randomness it depends on | Witness entry |
|---|---|---|
| group vectors, individual terminals, proximity vectors of A, H, W, Input, Output | mask/pair rows, pads | data rows, linearly |
| 256 opened columns per role | mask/pair rows, pads | data rows, linearly |
| M opening: q′, proximity, 256 columns, 14 functionals | a-rows, blinders, pads | none |
| masked sumcheck rounds of the 8 slots, mask evaluations, gammas | a-rows (through the two functionals per slot) | honest rounds, nonlinearly, but always inside the consistency subspace of the claim |

Two tools compute the joint statement on the four retained round-22 captures (two P1, two P3):

- `scripts/zk60_joint_view.py` (PCS side): the exact affine model of every group vector, terminal, proximity vector and opened column of every role jointly, with data aliasing across roles as in O8's `JointModel`, and with each row's freedom restricted by its 256 opened column values (the column-restriction map is one 256×512 matrix per role, shared by all rows; its kernel is substituted once). It reports the disclosed dimension of the data directions with and without the column equations; without columns it must reproduce O8's numbers; with columns the expected result is the same (only the public H LogUp identity), and the controls (ablated endpoint pair row, pad budget below the opened count) must disclose.
- `scripts/zk60_joint_cfs_view.py` (CFS side): all eight slots and the M opening together at the captured coefficients: per slot, the mask map onto the consistency subspace given the two functionals; the M opening's disclosed dimension of the a-rows beyond the 14 functionals; and the composed rank with shared a-rows. The six FFN slots' `(c_s, ρ_s)` are not in the captures; they come from the replay below (or are labelled stand-in when the replay output is absent).
- `scripts/zk60_transcript_replay.py` (oracle history): re-derives every transcript state and challenge of each receipt from public data (pure-Python BLAKE3 cross-checked against the `blake3` wheel), checks the receipt's binding state and every captured `before`/`after` checkpoint, and emits the ordered absorb/squeeze history and the six FFN slots' challenges.

Together with the round-24/25 endpoint samplers (zero-data preimages for the endpoint openings) and the round-1 probe's IO zero-witness solver (both already executed by Codex on the same captures), this is the joint conditional construction the gate asks for, at fixed challenges. The lemma of §1.2 is what lifts it. §7 records exactly which of these ran in this session and their numbers.

## 3. What the numbers mean, and what they do not

If the PCS-side disclosed dimension with columns equals the number without columns (the public H identity only), and the CFS-side composed rank shows the honest rounds of every slot unconstrained beyond the two functionals per slot, then at the captured challenge vectors the joint law of every field-valued object is witness-independent in the independent-uniform-randomness idealisation. With §1.2 that gives witness-independence of the whole transcript for any challenge function, hence for real BLAKE3, up to: the PRG assumption on the keyed BLAKE3 stream, the reduction bias of `fp()` draws (round 25's exact ledger, about `2^-75` at this profile, removable by rejection sampling at the cost of a byte-changing re-freeze), the LogUp collision event, and the two-point oracle programming of §1.1 in the root-only workflow.

It does not give: a proof for challenge vectors other than the captured ones (the refusal set for degenerate challenges is source-bound in round 1 §1; a generic-rank argument for all non-refused `ρ` is the write-up obligation U-3, now with the joint tool as its executable companion); soundness (FA5's open Fiat–Shamir loss item); side channels; application-visible failures on invalid inputs (O14); P3 model identity.

## 4. Obligation ledger (delta from round 1 §4)

- U-1 executed by Codex on 2026-09-15 (16 probe tests, four captures).
- U-2 (captured-challenge FFN CFS surjectivity): met by the transcript replay plus the CFS view, without any Rust change.
- U-3 (write-up): this memo §1–§3 is the composition write-up; independent review still required.
- U-4 (one Rust test: `/2` on the all-zero witness verifies in P1 and P3): still requested from Codex; test-only Rust. It is the simulator's existence condition.
- U-5 (bias ruling): unchanged, for Victor.
- New U-6: the root-only reduction of §1.1 written against the actual `pcs.rs` tree geometry (11 levels, 2048 leaves, 256 openings) with the one-table overlap bound; the bookkeeping tool is its executable companion.
- B-1…B-5 (private attention schedule, committed histograms, block composition, capture hook, block zero-witness test): unchanged and still the critical path to the tiny P1 block.

## 5. Private attention: go, under round 1 §6

The six prerequisites of round 1 §6 stand unchanged and are endorsed. One addition from this round: every new private component must be capturable by the same schema-3 diagnostic writer (or its block-level successor) so the joint PCS/CFS tools of §2 run on its real receipts, and its transcript must be replayable by `zk60_transcript_replay.py` (labels and orders documented at the source line).

## 6. Requests to Codex (integration owner)

1. Run the three tools of §2 in the validation harness and retain their records (commands in §7).
2. Add the zero-witness acceptance test (U-4) as test-only Rust.
3. Update `ZK60_ENDPOINT_SIMULATION_MODEL.md`'s "what remains" list: the joint field-view sampler now exists at fixed challenges; the root-only obligation is met by two programmed points in the ROM with the stated bound; keep the obligation listed.
4. Keep round 1's memo archived; this memo supersedes its §2 only.

## 7. What ran in this session (filled in from the evidence records)

_To be completed from `results/zk60_mvp_joint_view_evidence/` before handoff: exact commands, exit codes, per-capture numbers, and any tool that did not complete._
