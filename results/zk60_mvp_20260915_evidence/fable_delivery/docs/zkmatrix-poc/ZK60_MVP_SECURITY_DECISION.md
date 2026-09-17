# ZK60 MVP security decision — the shortest sound route from the fresh-IO FFN `/2` to the first tiny P1 block

| | |
|---|---|
| Author | Claude Fable 5.1, security critical-path assessment, 2026-09-15 |
| Baseline | `763e308` (worktree `/tmp/wt-zk60-mvp-fable-20260915`); capture producer `1f0ff36` |
| Source pins | `zk.rs` `c5b54753…9c1310`, `zk_ffn_fresh_io.rs` `1d9bab12…da362c`, `private_seam.rs` `2f36c779…8ecf5`, `pcs.rs` `2d914956…b24d`, `transcript.rs` `31ce3c9a…33da8`, `sumcheck.rs` `56dbb8c7…07d19` — all six equal the round-22 manifest pins, so the captures describe HEAD |
| New files | this memo; `scripts/zk60_mvp_security_probe.py` `8966e590…b7b277`; `tests/test_zk60_mvp_security_probe.py` `baddc461…61b37b`; `results/zk60_mvp_security_decision.json` (decision record, not probe output) |
| Not done here | **no Python ran in this session**: every `python3` invocation, including `python3 -m unittest`, was denied by the permission layer. The probe and tests are delivered desk-checked and un-executed. §8 gives the commands. Nothing below claims a test outcome. |
| Scope guard | P1 hides inputs, outputs and intermediate activations; weights may be public. Nothing here narrows that set, introduces public IO, or claims whole-proof privacy acceptance. |

## 0. The decision in one paragraph

The `/2` profile does not need a new cryptographic construction, an oracle-programming simulator, a leaf-programming candidate, or a separate joint field-view sampler. **Its simulator is the honest prover itself, run on the all-zero valid witness with fresh randomness, inside the joint prepare-and-prove game where the simulator issues the endpoint roots.** The privacy statement to prove is *witness-independence of the accepting view*: for every valid witness the joint law of (prepared roots, refusals, receipt bytes) is the same. That statement is hash-agnostic, so the "adaptive transcript" question dissolves into a two-line induction (§3) whose per-step hypotheses are exactly the fixed-challenge checks rounds 17–25 already built; the missing piece is the write-up plus one solver this memo adds. The arbitrary-external-root obligation is closed as *not a P1 requirement* (§2): it is unreachable through the owner API, vacuous for whoever chose the root, and impossible for any Merkle-opening commitment without hash programming. **What actually blocks the tiny P1 block is the private attention side (A1–A4, committed histograms, seams), which is engineering under a fixed discipline and can start now (§6).** No protocol change to `/2` is required; the smallest justified implementation change is one Rust test (§5).

## 1. What `/2` publishes, in order (source-bound)

`hashline/src/zk_ffn_fresh_io.rs` (pinned bytes):

1. `transcript()` (138–146) absorbs the 112-byte `ExpectedIo` (context, two scales, both endpoint roots) and the parameter string. No challenge is squeezed.
2. `prepare()` (148–181) draws one OS-keyed stream `ZkRng::from_os(PROFILE)` (164), passes `seed: None` (158) and hands the stream to `prepare_layer_zk_v3_inner` (165–175). The seeded `ZkConfig::rng` path (`zk.rs` 334–337, 1130) is unreachable from `/2`: the inner function takes `rng` by value and never calls it.
3. `zk.rs` `prepare_layer_zk_v3_inner` (2337): statement (2364), mode header (2368), W root (2471; public under P1, a fresh hiding commitment under P3), all A mask rows drawn from the stream **before** A is committed (2527–2537), A root absorbed (2542), M committed with fresh CFS coefficients, pads, blinders and salts (`mask_commit` 430–467) and absorbed (2550). **The first challenge of the whole transcript is β at 2554, after the fresh A and M roots.** Multiplicity histograms are committed rows of A (76–82, 2496–2501); nothing histogram-shaped is sent. H is committed after β, γ, α.
4. Six FFN masked sumchecks (slots 0–5), each: point challenges, `c_s` (refused if zero), masked claimed sum, rounds with `sc-round` absorbs, masked terminals absorbed.
5. `finish()` (276–368), per side i ∈ {0,1}: absorb `io-side`, squeeze τ (9 coordinates) and c (293, zero refused), absorb γ = c·Σ(mask slot 6+i) (298), ten masked rounds via `masked_prove` (312) and `extension` (325), refuse e = 0 (336–338), push the A-side claim on the X or z16 slice with the pair rows `a_io[i]` and the endpoint claim on rows 0–1 with pair rows 2–3 (343–346), absorb terminals and `mask_eval` (348–350), and register the slot's two M functionals (Σ-weights scaled by c; eval-weights at ρ‖e) (352).
6. `PendingV3::finish` (`zk.rs` 2307–2334): one M opening (θ, q′, proximity, 256 columns), W opening (plain under P1), A opening (seven groups incl. the two singleton IO groups; `check_masks` refuses degenerate coefficients), H opening; then `finish` opens Input and Output (360–361), 256 salted columns with 11-node paths each.

Every private owner is consumed on success or failure (`Endpoints` 104–107 and `PreparedPlane` 143–147 have no `Clone`, serializer or getter; `into_ffn_endpoint(self)` 156–161; `PendingProof::finish(mut self, …)`). `check_endpoints` (258–271) refuses a root that differs from the caller policy.

Prover-side failures an observer can see, classified from source (the probe pins each line): challenge-only refusals (zero `c`, zero `e`, degenerate table coordinate, mask coefficients not spanning F_{p²}, zero group member coefficient, dependent proximity coefficients), public-policy refusal (root mismatch), statement/shape refusals, entropy failure, and **exactly one witness-dependent event**: a LogUp denominator α − l = 0 makes `batch_inverse2` (`zk.rs` 2654, `field.rs` 207–222) hit `inv` of zero (`field.rs` 77). Its probability is at most (lookups + table rows)/2^128 per proof.

## 2. The security game, and why the external-root obligation closes

**Adopted game (P1).** Joint prepare-and-prove simulatability with owner-generated roots, in the sense of LNS20 Definition 2.8 as already cited by `ZK60_ENDPOINT_SIMULATION_MODEL.md` (`a948a825…cef95a`): `SimPrepare(public context, scales, shape)` outputs both endpoint roots and private simulator state; the caller fixes them as the statement; `SimProve` must then produce every later proof view, mirror refusal and consumption behaviour, and answer nothing it cannot answer honestly. The distinguisher keeps all public outputs, all refusals and its own hash queries, and may choose statements adaptively.

**Closing the arbitrary-external-root game.** Three independent reasons, each sufficient:

- *Unreachable by the API.* `ExpectedIo::from_roots` (55) can *name* any roots, but an accepting receipt requires `finish(endpoints)` with a `PreparedPlane` whose root equals the policy (265–268), and the only constructor of `PreparedPlane` is `private_seam::prepare_with_rng` (218) reached through `prepare()` (186–198) with fresh OS entropy. There is no import, export, clone or re-open path (probe check `owner_api`). The owner and the prover are the same process by construction.
- *Vacuous for the chooser.* In the standard NIZK game the adversary chooses (x, w) and therefore knows the committed input. Distinguishing a simulator there reveals nothing the adversary did not already hold. P1's requirement ("hidden from the verifier and public artefacts; the owner may know its own values") is the joint game.
- *Impossible without programming for any Merkle-opening PCS.* An accepting receipt reveals, for 256 positions, a salted leaf and 11 siblings hashing to the root. A simulator that did not build the tree and cannot program `BLAKE3(left‖right)` at a fresh point can produce a valid path only by inverting a 32-byte digest. With programming it can (one programmed point at the root of a freshly built fake tree), but only if the honest tree's top pair is never revealed, i.e. never if the root is reused — which the consumption rule already forbids. None of this is demanded by the requirement text.

Recommendation: record the external-root game as *out of scope for P1* in `ZK60_ENDPOINT_SIMULATION_MODEL.md` with the three reasons, keep the consumption rule as a load-bearing invariant, and stop investing in root-only simulation. Round 23's leaf-programming candidate (and its one-table overlap bound) becomes an unused alternative: the simulator below programs nothing, so `salt_leaf = hash_pair` matters for soundness (collision resistance) only, not for hiding.

## 3. The simulator and the adaptive lift — stated with its hypothesis, not manufactured

**Simulator.** Sim = the honest `/2` prover on the zero witness: input plane 0, activation planes 0, output plane 0 (so `g8 = 0`, `a16 = table[128]`, `h16 = 0`, `z16 = 0`, all remainders 0, multiplicities concentrated on the zero rows), with the same public W (P1) or zero weights (P3-fresh), the same shapes, shifts and table digest; `prepare_endpoints` on zero planes issues the roots; fresh OS randomness throughout. This is a valid witness of every statement in the family, so Sim outputs *real* accepting receipts under real BLAKE3 and programs no oracle point. (The existence condition — the zero witness verifies in both modes — is the one Rust test recommended in §5.)

**Privacy statement.** Witness-independence: for every two valid witnesses w, w′ of the same public statement, the law of the full public view V = (issued roots, every refusal event, receipt bytes) under the honest prover is identical, up to (i) the pseudorandomness of the keyed BLAKE3 XOF under a 256-bit `/dev/urandom` key, (ii) the reduction bias of `fp()` draws (each word within δ < 2^-96 of uniform, round 25's exact ledger; a hybrid over the N_fp mask/pad words gives at most 2·N_fp·δ, about 2^-75 at A00 P1, removable by rejection sampling at the cost of a byte-changing fixture re-freeze), and (iii) the LogUp collision event of §1. Witness-independence for all pairs, plus a public valid witness, is zero knowledge with Sim as above; no random-oracle programmability is used anywhere.

**The adaptive lift (the argument Codex asked for; to be independently checked, not assumed).** Write the prover as a sequence of published messages m_0, m_1, …; the challenge after message j is a function of the public past, r_j = H(public prefix through m_j), for *any* function H (real BLAKE3, an oracle, or an adversarial choice). The prover's message m_j depends only on (its witness, its randomness, r_<j). Hence the law of the whole view factorises as

  P_w(m, r) = ∏_j K_j^w(m_j | m_<j, r_<j) · 1[r_j = H(…)] .

If every per-step kernel K_j^w is witness-independent, the whole law is, for every H, and refusal events (functions of the public prefix) inherit the same law. *Per-step kernel witness-independence follows from the fixed-challenge statements already checked*: if for every challenge vector ρ the joint law of all messages given ρ is witness-independent (which is what "same image, same fibre dimension, uniform masks" establishes), then marginalising to the first j messages — which the prover produces before r_j exists — shows K_0, then K_1, … are witness-independent by induction on j. So the "fixed-coefficient" results are not a shortcut that assumes later challenges early; they are precisely the per-ρ joint statement the induction consumes. What must be true for the induction to apply, channel by channel:

| Channel (published object) | Fixed-challenge witness-independence: evidence at HEAD | Status |
|---|---|---|
| Input/Output openings: group vector, proximity vector, terminal, 256 columns | round 24: zero-data preimage with equal fibre dimension for all eight captured owners (`results/zk60_round24_endpoint_fibre.json` `3796b630…71991`); round 25: the zero-data generator's image has the same law for every data choice | evidence-backed |
| A, H (P1) and W, A, H (P3) group vectors, terminals, proximity, two proofs jointly | O8 / round 23: `disclosed_dim = 0`, only the public H identity (value 0, constant in both worlds) remains (`zk60_round23_repeated_view.json` `f6e01e4d…28e33f`) | evidence-backed |
| pads, columns, folded pads | FA8 L2 + round 20 translations; opened positions ≤ 256 = pad budget | evidence-backed |
| M opening (q′, proximity, 256 columns) | M has no data rows; FA6 G2 (function of the θ-combined functional value plus independent blinders); round 20/22 translations | evidence-backed |
| IO CFS slots 6/7: γ, ten rounds, `mask_eval`, together with the two terminals | round 21/22 fibre surjectivity at captured challenges; **this memo adds the explicit zero-witness preimage solver** (§7) | evidence-backed; solver un-executed here |
| FFN CFS slots 0–5 | FA6 G1 surjectivity onto the consistency subspace for every challenge sequence, checked at stand-in challenges (`ZK60_FABLE_TRANSCRIPT_REVIEW.md` `c843571c…a08b7066`, L3) | argument-backed; captured-challenge check is a bounded follow-up (needs per-slot ρ in the capture or a BLAKE3 transcript replay) |
| terminals shared between CFS `fin` and PCS claims | FA8 §B.5: `fin = want(terminals) + c·g(ρ)`; terminals uniform through pair rows, independent of CFS coefficients; the probe's IO solver instantiates exactly this coupling (δ = (m₁ − m₂)/e) | argument-backed + solver |
| roots of unopened columns | 32-byte salts, `salt_leaf` (`pcs.rs` 640–645); hiding is a salt-guessing event ≤ q·n_leaves/2^256 | standard |
| refusals | all challenge-only or public except the LogUp collision (§1) | source-bound |
| repeated / adaptively requested proofs | fresh owners, fresh streams, no shared pads/salts; the induction above already quantifies over the environment's adaptive statement choice | follows |

Nothing in this table is a new theorem; it is the composition of existing pieces under the one hypothesis stated in bold above. The write-up that composes them is a two-page document by this template (obligation U-3 in §4), and it should be reviewed by someone other than me.

**What this does not cover.** Soundness (multi-round Fiat–Shamir loss, FA5's open item), side channels (timing, memory, stderr), application-level exposure of failures on *invalid* private inputs (outside the relation; O14's interface question), and P3's authenticated model identity.

## 4. Obligation ledger — what really blocks P1

**Proved / evidence-backed at HEAD (no further construction):** the schedule facts of §1 (probe `schedule`, `refusals`, `owner_api`); the fixed-challenge rows marked evidence-backed in §3; the source pins.

**Unresolved, bounded, non-blocking for starting attention (owner in brackets):**

- U-1 Run `scripts/zk60_mvp_security_probe.py` and `tests/test_zk60_mvp_security_probe.py` (denied here). Expected: all pins match; first challenge after the A root; sixteen refusal lines resolve; synthetic honest IO argument has a zero-witness preimage with kernel dimension 1 and five corruption controls fail; on the captures, both IO slots per receipt have a zero-witness preimage, all fourteen M functionals are jointly independent, all eight endpoints have zero-data preimages. Any deviation is a finding. [Codex or Opus]
- U-2 Captured-challenge surjectivity for the six FFN CFS slots: extend the IO capture with each slot's ρ (test-only writer, `zk_ffn_io_diagnostic.rs`) or replay the transcript in Python with a BLAKE3 binding, then rerun FA6's rank check at those ρ. [Opus-suitable]
- U-3 The two-page whole-view witness-independence write-up by the §3 template, citing the per-channel records by hash; independent review. [Codex writes, Opus reviews]
- U-4 One Rust test: `/2` on the all-zero witness verifies in P1 (same public W root) and P3. [Codex, see §5]
- U-5 Decide the accepted-view bias term: state 2·N_fp·2^-96 as accepted, or rejection-sample `fp()` (byte-changing; needs a fixture re-freeze ruling). [Victor ruling; not gating]

**Blocking for the first tiny P1 block (attention side — engineering, not open cryptography):**

- B-1 The private attention schedule A1–A4 of FA8 §C.4: a pair mask per single-row site, proximity pairs, block-table slots for multi-row tables, a CFS slot table with `(n_vars, degree)` and extension degree = mask degree, the M functional order, and the attention-side seam terminals as reserved pair rows.
- B-2 Attention's LogUp histograms and helper sums committed inside A/H, not published (today's public block publishes them: FA5 R12).
- B-3 Block composition: external endpoints bound to the attention component's `x_in` and `xres2` planes by the `/2` IO mechanism (reserved pair rows in the attention A, two slots in the attention M, zero-claimed equality sumchecks); internal X/Z seams with pair rows on both sides; single opening per commitment after all equalities; owners consumed.
- B-4 An attention/block capture hook like `zk_ffn_io_diagnostic.rs` so the same fixed-challenge zero-witness checks run on real block receipts.
- B-5 The block's zero-witness acceptance test (P1 and P3) — the simulator's existence condition for the block.

**Explicitly not blocking (stop spending on them):** arbitrary external-root simulation; leaf/node programming and its one-table bound; a separate joint A/H/W/CFS field-view sampler (the honest zero-witness prover *is* that sampler, and it is already implemented); O12's fibre audit and O13's schedule inventory as gates (useful cross-checks, not prerequisites).

## 5. Smallest justified implementation change

None to the `/2` protocol, transcript, receipt format or randomness. Add one Rust integration test (Codex-owned file `zk_ffn_fresh_io_tests.rs` or a new test file): build the zero witness through the existing oracle on an all-zero input, `prepare_endpoints` on zero planes, `prepare`/`finish`, and `verify_bytes` under the same `WeightStatement::Public(root)` used by the honest fixture, then the same under `FreshPrivate`. This pins the simulator's existence condition and doubles as the acceptance gate every future private component must pass before its channels are analysed. Optional and deferred: rejection-sampled `fp()` (U-5).

## 6. Private attention can proceed in parallel — prerequisites

Yes. The FFN-side privacy argument is a *schedule discipline*, not a property of the FFN arithmetic, so attention engineering can start now against these prerequisites, each of which is checkable on the schedule alone:

1. Every private plane is opened only through pair-masked claims `(1 − e)·T(p) + e·(R_re + u·R_im)(tail p)`; every proximity vector is covered by a dedicated proximity pair; multi-row tables use block slots; no single base-field mask anywhere (FA8 C1–C2).
2. Every CFS slot has exactly the `(Σ, eval)` functional pair in one M per component, opened once with one θ (FA6 I5); extension-round degree equals mask degree; zero-claimed slots send `c·Σ`, matmul slots send the private sum plus `c·Σ`.
3. Every message is absorbed before the challenge that constrains it; no challenge before the fresh A root; the block header, public roots and endpoint policy come first.
4. Refusals are functions of public inputs and challenges only, never resampled; one OS stream per component per attempt; owners consumed on success and failure; no seed reachable; nothing published on failure.
5. Histograms, helper sums and every terminal are committed/masked, never sent in the clear.
6. Acceptance gate per channel, run on captured real receipts: a zero-witness preimage with the same free dimension as the real witness (the probe's solvers are the template), plus the block-level zero-witness acceptance test (B-5).

The FFN `/2` code is the worked example of all six; copying its structure is the shortest sound route. Anything that cannot meet item 1 or 2 (FA7's uninventoried `SeamXm8[c]`, `SeamZ16c[c]`) is a design gap to close before capture, not a reason to weaken the private set.

## 7. Executable falsification content (delivered, un-executed here)

`scripts/zk60_mvp_security_probe.py` — read-only over pinned sources, the round-22 manifest and (if readable) the capture triplets; never reads a witness, mask, pad, salt or seed:

- `check_source_pins`: HEAD bytes of the ten manifest-pinned files versus the manifest.
- `check_schedule_order`: parses `prepare_layer_zk_v3_inner`, `io::transcript/prepare/finish`, `private_seam::prepare`; asserts A root < M root < first challenge, no seeded RNG reachable, OS entropy for endpoints.
- `check_refusal_inventory`: sixteen exact source snippets with their classification; fails if any line moved.
- `check_owner_api`: no `derive`/public fields on `Endpoints`/`PreparedPlane`, single constructor, consuming `finish`, root equality.
- `io_zero_witness_preimage(arg)`: **the falsification test for the IO channel.** Solves the exact F_{p²} system "captured (γ, ten rounds, terminals, mask_eval) = honest `/2` output on zero planes for some 22 slot coefficients and pair values" (32 equations, 22 unknowns). Assumptions: FA6's `cfs_round_weights` replicate `CfsMask::round` (`sumcheck.rs` 255–274; cross-checked by FA6 against the Rust fixture and re-checked in the test file against the brute-force form); the zero-witness extension polynomial is x(1 − x)·eq(τ, ρ)·(ext_A − ext_E) with ext_i = terminal_i/e (`extension_round` 297–309, `masked_terminal` 312–314). Prediction: a preimage exists with kernel dimension exactly 1 for every accepted argument, and does not exist after any of five single-coordinate corruptions (`io_negative_controls`) or for unequal planes. A captured argument *without* a zero-witness preimage would be a counterexample to witness-independence of that channel.
- `m_functional_rank`: all fourteen M functionals jointly independent at the captured coefficients (so the eight slots' (claim, fin) pairs are jointly free); also records that a programmable-ROM simulator would need Σ n_vars programmed points while this simulator needs 0.
- endpoint zero-data preimages via round 24's unchanged `zk60_endpoint_fibre.sample` for all eight owners.
- `honest_io_argument`: a Python re-implementation of the IO equality prover (eq table, degree-2 rounds, masking, extension, terminals) used by the tests to generate honest and wrong-witness arguments; `zk60_io_cfs_composition.replay` (round 21's verifier equations) must accept the former and refuse the latter.

`tests/test_zk60_mvp_security_probe.py` — 13 tests: pins, schedule, refusal lines, owner API, parser on synthetic Rust text, F_{p²} solver on consistent/inconsistent systems, mask arithmetic self-consistency, honest-equal-planes preimage with kernel 1 and five failing corruptions (three seeds), rebuild with shifted pair values accepted by the verifier equations with unchanged terminal difference, exact agreement of the zero-plane prover with the zero-witness formula, unequal planes refused, the capture stage (skipped with an explicit reason when the triplets are unreadable — an evidence gap, not a pass), and `FullRun` (writes the probe record to `ZK60_MVP_PROBE_OUT` if set).

## 8. Commands, files, and what was and was not verified

Run from the repository root:

```
python3 -m unittest discover -s tests -p 'test_zk60_mvp_security_probe.py' -v
ZK60_MVP_PROBE_OUT=results/zk60_mvp_security_probe_run1.json python3 -m unittest tests.test_zk60_mvp_security_probe.FullRun -v
python3 scripts/zk60_mvp_security_probe.py --captures /home/victor/IntelligenceRegulation/results/zk60_round22_captures --out results/zk60_mvp_security_probe_run1.json
```

Verified in this session by read-only commands: `git log`/`git status`; `sha256sum` of the nine source files (the six pinned ones match the manifest byte for byte); every line reference above was read directly. Denied in this session: `ls` outside the worktree (the capture directory could not be listed) and every `python3` invocation. Therefore: the probe and tests were **not executed**; the captures were **not read**; no run result is claimed. Changed files: the four listed in the header, all new; no existing file was modified; no Rust, board, queue or Git state was touched.

## 9. Summary of proved versus unresolved

- **Proved (source-bound, this session):** the `/2` schedule absorbs the fresh A root before any challenge; the `/2` API cannot reach a seed; endpoints are owner-generated, consumed, and non-exportable; the only witness-dependent prover event is a negligible LogUp collision; the six argument-relevant sources at HEAD are the capture producer's bytes.
- **Established by prior executed rounds and reused here without re-execution:** fixed-challenge zero-data preimages for the endpoints (round 24), `disclosed_dim = 0` for A/H/W across two proofs (round 23/O8), M-opening and pad/column translations (round 20/22), IO CFS fibre surjectivity at captured challenges (round 21/22).
- **Argued, to be independently reviewed:** the sequential-kernel lift (§3) and its consequence that the honest zero-witness prover is a programming-free simulator in the joint game.
- **Unresolved but bounded (U-1…U-5):** execution of the delivered probe/tests; captured-challenge FFN CFS surjectivity; the two-page write-up; the zero-witness Rust test; the bias-term ruling.
- **Blocking for the tiny P1 block (B-1…B-5):** the private attention schedule and block composition — engineering under §6's discipline, startable now.
