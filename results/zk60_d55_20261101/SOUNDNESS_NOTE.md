# D55 "commit, fork, join": soundness note on the prototype as built

**Status (2026-11-01):** a note for the independent D24-class reviewer and the security owner. It is not an
acceptance, not a privacy statement, and it registers nothing.
- The prototype is the opt-in, unregistered run profile Victor ruled on (D55). It is compiled in TEST BUILDS
  ONLY.
- Code:
  - `ops/zkp-mvp/gpu-metal/hashline/src/private_block/run_fork.rs`: the prover, the verifier and the controls'
    cheating prover;
  - `run_fork_wire.rs`: the frames;
  - `run_fork_tests.rs`: the tests and the A/B.
- Design: `docs/zkmatrix-poc/ZK60_D55_CONCURRENT_RUN_DESIGN.md`. Today's construction: D12a,
  `run.rs::prove_run_with`.

Each point below says what the code does, then what that buys. Points where I am unsure are marked
**[UNSURE]**.

## 0. What was built, exactly

The prototype takes a D12a `RunStatement` (blocks-only; token-I/O and classifier runs are refused) and an explicit
`D55OptIn` token. Everything a D12a run fixes stays as it is:
- the geometry, the blocks and their digests;
- the boundary specs (derived rows, two sites, reserved mask pairs);
- the endpoint policy and the calibration identity;
- the per-stage shapes and layouts.

What changes is the transcript and the receipt.

**Header.** The run transcript is built as follows.
1. It is constructed under the **base** run profile, exactly as D12a's (`tagged_transcript(sh, base_profile)`).
   The constructor's input length is therefore one the base profile's own W-2 census already admits.
2. Its FIRST absorb is `run-construction` = `d55-commit-fork-join-prototype-unregistered/<base profile>`. This
   absorb separates every later state and challenge from D12a's.
3. Then come D12a's six header absorbs, in D12a's order. Two of them carry the fork run's own values:
   - the `parameters` line ends `/d55-commit-fork-join-prototype-unregistered` instead of
     `/one-run-one-transcript`;
   - the `schedule` digest is a new one, under its own domain. It covers the fork line, the layout, the three
     phases in words, and each block's D12a stage line under its fork's name.

The run binding (the state after the header) therefore differs from D12a's for the same statement (tested).
`ForkRun::new` also runs a small W-2 census. The constructor input must be at least two bytes away from every
fixed-length absorb this module adds. Every non-empty claim-list absorb is longer than the constructor. The two
seed-derivation inputs avoid 64, 40 and 47.

**Phase 1 (commit), on the run transcript.**
- For `k = 0 .. L-2`, the boundary plane comes from the source and is committed with
  `boundary::prepare(spec_k, ...)`, using one commit-phase generator.
- Then, in boundary order, each boundary `k` absorbs `pb-fork-commit-root = k` and then `B = root_k`, `rows`,
  `log-cols` (D12a's `absorb_root`).
- Then `pb-fork-s0 = L`. The state is now **S0**.
- The head frame carries every root and a tag of S0. The tag is compared and never adopted (M-6).

**Phase 2 (fork).**
- Block `k`'s transcript is `fork(S0, k)`: S0, then `pb-run-fork = k`, then `pb-run-fork-block = block_digest[k]`.
- `Transcript` is neither `Clone` nor `Send`, so each worker rebuilds S0 from the public header and the roots.
  These are the same absorbs, so the state and the squeeze counter are the same. The verifier rebuilds S0 the
  same way.
- `protocol::prove_core` then runs **unchanged** on the fork, with:
  - the stage's own shape and layout (`stage_shape(k)`, `stage_layout(k)`: the same reserved pair rows as D12a);
  - the incoming matrix (`B_{k-1}`, or the external input endpoint);
  - the outgoing matrix (`B_k`, or the external output endpoint).
- Block `k` has its own generator, `ZkRng::from_os(domain_k)`, with the domain built as
  `hashline-zk-rng/private-block/d55-fork-run-one-stream-per-fork/v1/`, then the run-prover role byte, then `k`,
  then the fork profile.
- The blocks run on `N` threads in one process, sharing the one Metal context.
- Fork frame `k` holds: block `k`'s roots, slots and `M` / `A` / `H` openings; a start tag; and an end tag.

**Phase 3 (join), on the run transcript from S0.**
- For `k = 0 .. L-1`, in block order, absorb:
  - `pb-join-fork = k`;
  - `pb-join-state` = fork `k`'s final 32-byte state and its squeeze counter;
  - `pb-join-in-claims` = every public word of the claims slot 21 raised;
  - `pb-join-out-claims` = the same for slot 22.

  A claim's public words are its value, and for each part the slice offset and size, the coefficient and the
  point.
- Then `pb-fork-s1 = L`. The state is now **S1**.
- Then, all on the run transcript after S1:
  1. each `B_k` is opened ONCE, via `PreparedBoundary::into_opening`, with block `k`'s slot-22 claims then block
     `k + 1`'s slot-21 claims. That is D12a's site order: site 0 = `mask_row(0)` = block `k`'s out-pair, site 1
     = block `k + 1`'s in-pair;
  2. the external input endpoint is opened with block 0's slot-21 claims;
  3. the external output endpoint is opened with block `L - 1`'s slot-22 claims.
- The tail frame carries every opening, a tag of S1 and an end tag.

**Verifier.** It mirrors the prover:
1. the preflight (CS-1 / CS-4 / CS-6, with the same refusals as D12a);
2. the header, then the head's roots, then S0;
3. the `L` forks on a pool of threads. Each fork:
   - rebuilds `fork(S0, k)`;
   - decodes frame `k` against its own `L`, `k` and start tag;
   - checks every Merkle path's depth (T-4);
   - runs `protocol::verify_core`. The verifier COMPUTES the IO claims itself from the slot terminals;
4. the join, in block order. It uses the verifier's own fork states and its own claims, never the frames';
5. S1, then the tail's openings in the prover's order, each against `boundary::check_opening` /
   `check_endpoint_opening` and `pcs::verify_zk_tagged`.

## 1. Every boundary root is fixed before any challenge a claim on it depends on

**Kept, and strengthened.**
- Every one of the `L - 1` roots is absorbed into S0 before any fork exists.
- Every fork's first state is a function of S0.
- So every challenge of every block comes after every root. That includes slot 21's and slot 22's claim points
  on `B_{k-1}` and `B_k`, the LogUp challenges and every sumcheck challenge.

In D12a, `B_k`'s root comes before block `k`'s challenges but after blocks `0 .. k-1`'s. So a cheating D12a
prover may choose `B_k` after seeing earlier blocks' challenges. Here it may not.

The external endpoints are in `expected-IO`, absorbed in the header, as in D12a.

Control 3 (a root absorbed after a fork) is rejected:
- with the cheater's own tags, by the S0 tag;
- with forged honest tags, by fork 0's `verify_core`, because every fork was proved on the wrong S0.

## 2. Each block's sub-proof keeps today's per-block error

- Block `k`'s sub-proof is `prove_core` / `verify_core` byte for byte. Only the transcript prefix changes: S0
  and `(k, digest_k)` instead of D12a's chain prefix.
- Inside a fork every challenge is still drawn after every message it must follow, because the fork IS a
  single transcript.
- So the per-block soundness error is the D24-class per-block figure, unchanged.

The openings have the same commitments, the same PCS parameters, the same claim structure (two sites per
boundary, one per endpoint) and the same audits. So the per-opening error is unchanged.

**Interactive (union-bound) reading, D15 / D27.** Say the run statement is false: the committed output is not
`F_{L-1} ∘ ... ∘ F_0` of the committed input.
- The roots bind planes `b_0 .. b_{L-2}`, by the same Merkle and Reed-Solomon binding as D12a. Write
  `b_{-1}` and `b_{L-1}` for the endpoints.
- Then some `k` has `b_k ≠ F_k(b_{k-1})`. For the run to be accepted, one of two things must happen:
  - **(a)** fork `k` accepts a false sub-statement while its IO claims are true evaluations of `B_{k-1}` and
    `B_k`. That is the per-block error `ε_k`;
  - **(b)** some IO claim is false and the one opening that carries it accepts. That is the opening's
    `ε_open`.
- The opening's challenges are drawn after S1. S1 binds the claim, both the point and the value, explicitly
  (`pb-join-*-claims`) as well as through the fork's final state.

So Pr[accept | false] ≤ Σ_k ε_k + Σ_{L+1 openings} ε_open. These are the same terms as D12a: the same `L`
blocks and the same `L - 1 + 2` openings. **The whole-run figure at the named workload (D27) is unchanged.** No
term is added. The join absorbs are hash inputs, not protocol rounds.

**Work-factor reading (MEMO_G02: "about the worst single round", about 99.7 bits).**
- The rounds are the same rounds: each fork's rounds, then the openings' rounds, in sequence after S1.
- The worst single round is still one block's lookup round, so the reading is unchanged.

## 3. Mix-and-match (the point the review must check carefully)

**The attack in question.** A cheating prover makes several candidate sub-proofs for each block. It then picks
one candidate per block after seeing the others, or after seeing a candidate join.

**The argument, as built.**

1. **Forks do not see each other.** Fork `k`'s challenges are random-oracle outputs on inputs that begin with
   S0, `pb-run-fork = k` and `digest_k`, followed by fork `k`'s own messages only.
   - For `j ≠ k` the inputs differ from their first absorb on, so the forks' challenge streams are independent
     oracles. This holds even when two layers carry the same block, as the A/B's synthetic stack does at every
     layer: the index separates them.
   - So whether a candidate for block `k` verifies on fork `k` does not depend on what was chosen for any
     other block.
   - The candidate set of each block is fixed by that block alone. Choosing a combination means choosing one
     element per set, independently.
   - Control 1 (a fork-index swap) is the check that the index is really in the derivation. Blocks `a` and `b`,
     each proved on the other's fork, are rejected:
     - with the cheater's tags, by the start tag;
     - with forged tags, by `verify_core` on the swapped fork.
2. **Every candidate must verify on its own against the fixed roots.**
   - A candidate whose sub-statement is false, but whose IO claims are true, is an `ε_k` event of fork `k`'s
     own rounds.
   - A candidate whose IO claims are false must survive its opening.
3. **The openings come after S1, and S1 binds the chosen combination completely.** In block order, the join
   absorbs:
   - every fork's final state. The state together with the squeeze counter binds every message the fork
     absorbed. After its last squeeze a fork sends only Merkle-opened columns, which its roots bind;
   - every claim's point and value.

   Control 2 (a stale fork state, i.e. the fork's start state at the join) is rejected:
   - with the cheater's tags, by the S1 tag;
   - with forged tags, by the first boundary opening, because every opening challenge was drawn from the
     cheater's S1.

   Control 4 (a claim raised on a fork but not joined) is rejected the same way. The variant that also leaves
   the claim out of the opening is refused by the prover's own boundary audit, before any receipt exists:
   `into_opening` requires both sites.
4. **So choosing among valid candidates is grinding the opening phase, and it is bounded by oracle queries.**
   - Each distinct combination gives a distinct S1, by collision resistance.
   - The opening challenges are fresh oracle outputs on S1.
   - Each tried S1 costs at least one query (the join's last absorb and the first squeeze). The query is the
     unit of the Fiat-Shamir bound.
   - In round-by-round terms: the state after the forks is doomed if some false claim exists, or if some fork
     with a false sub-statement has not been lucky. Each oracle query either:
     - advances one fork by one round, and un-dooms that fork with probability ≤ that round's error; or
     - draws an opening challenge for one S1, and un-dooms with probability ≤ that opening's error.
   - So with `Q` queries, Pr[forge] ≤ Q · max(round error), plus collision terms. That is the same form and
     the same maximum as D12a's Fiat-Shamir bound, because the set of round types is the same.

**[UNSURE] Proving work per attempt can fall.** This does not change the query bound. With `c` candidates
per block, a cheater gets up to `c^L` distinct S1 values for `c · L` fork proofs and `c^L` cheap join
computations, each about `4L + 1` hashes.
- In D12a, a fresh challenge for a boundary opening needs a different valid prefix. The cheapest such prefix is
  probably a re-run of part of the next block's proof.
- So on a "work per attempt" reading measured in proofs, D55 is cheaper to grind than D12a. On the
  oracle-query reading it is the same.
- MEMO_G02's work-factor reading already charges one hash per try ("generous one-hash-per-try estimate", D27).
  Under that reading nothing moves.
- **The reviewer should confirm that the project's accepted reading is the query (hash) count. If any figure
  counts attempts in proofs, it must be re-derived for D55.** I believe none does.

**Hosted-claim batching.** The hosted pairs (`argument_accuracy.rs`: `hosted = vec![(SC_WO, nu[0]), ...]`) are
between slots of ONE block, with `nu` drawn on that block's transcript.
- `prove_core` keeps no run-level state other than its two IO matrices. So every hosted pair lies inside one
  fork, with the same order and challenges as in a single-transcript block.
- No claim is batched across blocks, except at the boundary openings. There both sides' claims are combined
  with opening challenges drawn after S1, which binds both sides.

**"One reserved pair per claim site, opened exactly once"** carries over unchanged.
- The stage layouts point the two IO tabs at the same reserved pair rows as D12a.
- `B_k` has exactly two sites: block `k`'s slot 22 at `mask_row(0)` and block `k + 1`'s slot 21 at
  `mask_row(1)`.
- `PreparedBoundary::into_opening` consumes the owner, so a second opening does not type-check. It audits the
  claim schedule against the derived geometry and requires exactly two column-weight groups.
- Each external endpoint is opened once.

**[UNSURE] Concurrent reads of the mask rows.** Two forks read `B_k`'s committed matrix, mask rows included,
at the same time. Both reads are read-only, and they return the values D12a's two stages read one after the
other. I see no soundness or privacy consequence, but the joint-view gate has never seen this order.

## 4. Zero knowledge (for the privacy re-check; not argued here)

- **No new value is revealed.**
  - The fork frames are D12a's segments without their IO openings.
  - The tail carries the same openings, over the same data and masks, at challenges drawn from S1.
  - The join absorbs only values the verifier recomputes itself: fork states and claims.
- **The opening order changes.** D12a opens `B_{k-1}` right after block `k`; D55 opens all of them after S1. The
  opened vectors are the same function of (data, masks, challenges), and the challenges are uniform in both
  constructions. The run-wide joint law has never been checked for this order.
- **The randomness split** is the one place the code departs from the design's words. The design says "the
  run's OS stream split per block". The code has `L + 1` independent OS-seeded generators: one for the commit
  phase and one per fork, each under its own domain.
  - It is at least as strong: no derivation relation exists between any two streams.
  - It needs no change to `zkp-core/src/rng.rs`. That file is pinned, and stage 25's census guards the
    generator's derivation there.
  - **It breaks W-8 assertion 5 for this profile.** That assertion says each prover constructs exactly one
    generator and passes it on by `&mut`. The census tests do not scan this test-only module, so this is
    recorded here and must be accepted or redesigned in the privacy re-check.
- **The capture tooling** (`run_capture.rs`, the plane index, the W16 privacy gate) records only D12a runs. No
  D55 run has been captured, and the Python gate has not seen one.

## 5. What the tests show, and what they do not

They show the following, at the R13 h24 development rung, with three stages that alternate two gate
denominators, on the CPU and with Metal:
- honest fork runs verify at 1, 2 and 3 workers, with 1 and 3 verifier threads;
- a changed byte in the head, a fork or the tail is refused;
- D12a still proves and verifies on the same statement;
- the profiles do not cross: a fork receipt fails as D12a, and D12a segments fail as forks;
- CS-7 does not register the fork string;
- the four named controls are each rejected, and again with forged tags, where the rejection comes from the
  chain and not from a tag compare;
- swapped fork frames are rejected.

The rejections, verbatim (`logs/iter_i1.log`, CPU), with the cheater's own tags and then with forged honest
tags:

| control | cheater's tags | forged honest tags |
|---|---|---|
| fork-index swap | `D55: fork 0: D55 wire: fork frame 0's start tag is not the verifier's own fork-0 position` | `D55: fork 1: slot 0 [01 SS row sums norm_a (private)]: sumcheck round 1: s(0) + s(1) != claim` |
| stale fork state | `D55 wire: the tail's S1 tag is not the verifier's own joined transcript position` | `D55: boundary 0: pcs zk: group 0: <v, c> != combined claim` |
| root absorbed after a fork | `D55: the head's S0 tag is not the verifier's own S0 (every boundary root absorbed, in order, before any fork)` | `D55: fork 0: slot 0 [01 SS row sums norm_a (private)]: sumcheck round 1: s(0) + s(1) != claim` |
| claim raised, not joined | `D55 wire: the tail's S1 tag is not the verifier's own joined transcript position` | `D55: boundary 0: pcs zk: group 0: <v, c> != combined claim` |
| … nor opened (prover side) | `D55: boundary 0: private block: mask schedule audit: a reserved pair is unused or shared between claims` | (no receipt exists) |

They do **not** show any of the following:
- a bound;
- that the forged-tag cheaters are the strongest ones. A cheater can, for example, choose its fork-`k`
  messages adaptively across forks;
- zero knowledge;
- anything about a dense real-weight stack. The A/B uses one synthetic diagonal-weight block at every layer.

## 6. Owed before any use

1. An independent D24-class review of points 1–3, especially point 3 and its [UNSURE] work-per-attempt item.
2. A privacy re-check of point 4: the opening order, the `L + 1` generators, and a capture and gate at the
   fork profile.
3. A full hash-input census (T-3, W-2, W-4) of the fork profile, with the stage-25 tools rather than this
   module's small check.
4. Victor's amendment of D12a for an opt-in profile with its own profile string and receipt kind. Until then
   it stays unregistered and test-only.
5. A streaming receipt sink (M-3) if a fork run is ever used beyond the A/B. Today the prover holds every
   frame, which is fine on 256 GB but not on the 8 GB laptop's budget.
