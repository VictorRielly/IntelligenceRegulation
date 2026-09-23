# R1d (skip the redundant s(1)) and the round interface — review of Codex's candidate

Written 2026-09-23 01:27 (clock read before writing) by a Claude Opus 5.5
reviewer agent, at the integrator's (Codex's) request. **Read-only review:**
nothing in `results/zk60_sumcheck_rounds_20260922/` or in
`/tmp/zk60-rounds-20260922` was edited, built or run.

**Subject.** Codex's uncommitted candidate `candidate-v1/` (six files; hashes in
`source-changes-v1.json`) for request **R1d** (finding IR-C19 of
`ZK60_SLOT_EXPRESSION_IR_DISPOSITION.md`: do not evaluate the round polynomial
at 1, because `s(1) = claim − s(0)`) and for the additive round interface
**"Option A"** (ruling I-5 of the same disposition). Codex asked for review of
two things in particular: the additive interface, and its decision to seed the
shortcut only on Private slots (host and standalone slots compute their first
round in full and use the shortcut from round 2 on).

## The answer in plain words

* **The shortcut is correct.** For every slot, every round and every shape, the
  value the new prover uses for `s(1)` is the value the old prover computed —
  for honest witnesses **and** for the tampered witnesses the soundness tests
  hand to the honest prover — so the published bytes are the same. It rests on
  one premise that does not depend on the witness: each slot's polynomial has
  no higher degree per round than it declares. Four independent pieces of
  evidence support that premise (Q1).
* **Codex's first-round decision is right, and it is the cheapest correct
  choice.** Seeding host/standalone slots from the value they *assert* would
  change bad-proof bytes, fire a new debug panic, and move the verifier's
  refusal from round 0 to that slot's first extension round. No free
  "actual sum" exists for those slots: computing one costs more than the
  shortcut saves (Q1, R-7).
* **The interface is additive.** I checked this by diff, not by reading the
  claim: the old `prove` and `masked_prove` bodies are byte-identical. There
  is no `Sync` bound, the old path is unchanged, and the change opens no new
  way to leak secret values through a public function (Q3).
* **It cannot land as it stands.** It changes three files that the toy
  privacy statement (D22) pins, plus the `zk.rs` pin in the MVP security
  probe, and adds one new file on the toy path. Validation ran at the stage-35
  base, not at the lane's current stage-42 tip. These are gates and evidence
  gaps; **no code defect was found** (R-1 to R-3).
* **Speed.** No end-to-end speed-up is established, which is Codex's own
  verdict. The seeding rule gives up roughly half of the 15.8% counted saving,
  because the host slots carry about 96% of the measured sumcheck time.
  Expect about 8% of the counted baseline [MODEL]. The measured per-phase
  change of −6.3% is consistent with that and **does not support 15.8%** (Q4,
  R-6).

## How I checked

* **Base identified and diffed.** I extracted
  `results/zk60_shaped_integration_20260922/reviewed-source.tar.gz` to a
  scratch directory. Its `zkp-core/src/sumcheck.rs`, `hashline/src/zk.rs` and
  `hashline/src/private_block/argument.rs` hash to exactly the `base_sha256`
  values in `source-changes-v1.json` (`56dbb8c7…`, `07282c76…`, `f7fa2ad4…`).
  I ran `diff -u` from the base to `candidate-v1/`, and the diffs equal
  `candidate-v1.patch`.
* **Read the full path.** I read `sumcheck.rs` (prove, verify, CfsMask,
  CfsMasker, extension_round), `transcript.rs` (masker hook, clone_state),
  `mle.rs::interpolate_eval`, and `field.rs` (canonical Fp add/sub/mul). In
  `argument.rs` I read `run_slot`, `priv_table`, `eq_cube`, `total`, every
  slot closure, `Gate` and `helper_sum`. In `shape.rs` I read `slots()` and
  the degree table, and in `layout.rs` `SLOT_KINDS`.
* **Read the records.** I read all of Codex's records: both validation
  records, the native test log (511 ok + 1 rerun), the core logs, the four
  A/B logs and `comparison.json`.
* **Compared with the lane tip.** I hashed the candidate's files against lane
  `zk60-private-block-125m` at `6b68561`: `argument.rs` and `sumcheck.rs` are
  byte-identical to the candidate base, `zk.rs` differs only in the FFN
  hunks. I checked the D22 pin tables on `zk60-native-jointview`
  (`scripts/zk60_native_mask_commit.py`) and the pre-read
  `ZK60_D22_PREREAD_SHAPED_SNAPSHOT.md` (committed at `e4abb32`).

## Verdicts per question

### Q1 — Is the recovered s(1) the value the old code computed? **Yes, for honest and inconsistent witnesses, under a premise that does not depend on the witness.**

* **Which claim is tracked.** The running claim is the **unmasked**
  polynomial's value at the **masked-transcript** challenge.
  `prove_rounds` (`rounds.rs:38-46`) passes the unmasked sums to
  `absorb_fp2(b"sc-round")`, where the installed `CfsMasker` swaps in
  `s + c·g_j` before hashing (`transcript.rs:82-93`). `challenge_fp2` then
  draws `r` from that masked state and reports it to the masker. Next,
  `fold(r)` sets `unmasked_claim = interpolate_eval(unmasked sums, r)`
  (`rounds.rs:147`). This matches the masked verifier. The mask's own
  identity `g_j(0)+g_j(1) = g_{j−1}(r)` is exact (tested in
  `cfs_mask_rounds_match_brute_force`), so the masked round check holds if
  and only if the unmasked one does.
* **Masked and unmasked values never mix.** The evaluator only ever holds
  unmasked values (`pending`, `unmasked_claim`). Masked messages exist only
  inside the transcript's masker, and `masked_prove_rounds` returns only
  those (`zk.rs:1097-1100`). As before, the unmasked `ProverOutput.proof` is
  dropped. The extension rounds are unchanged: they are computed in full from
  the actual finals (`argument.rs:563-579`, `zk.rs::extension`).
* **The arithmetic is exact.**
  * Field operations keep canonical representatives (`field.rs:40-49`), so
    `(total + cG) − cG` is `total` as a word, and `v0 + (v1 − v0)` is `v1`.
    The round-0 `s(0)+s(1)` is therefore the cube sum, computed the same way
    `total` computes it (field sums do not depend on order).
  * The next-round identity `s_j(0)+s_j(1) = s_{j−1}(r_{j−1})` is a fact
    about linear folding. It holds for **any** table contents whenever the
    round polynomial's degree is at most `d`.
  * `interpolate_eval` does exact Lagrange interpolation through the `d+1`
    points 0..d, with base-field denominators. It is the very function the
    verifier uses (`sumcheck.rs` `verify`), and it is exact over Fp2 whether
    or not Fp2 is a field.
  * Degree-1 slots work: the `cur += dif` step still runs for X=1, so the
    X≥2 points stay correct (`rounds.rs:119-121`).
* **Where the identity can fail, and whether the candidate avoids recovery
  there.** The identity `s(0)+s(1) = claim` can fail for an inconsistent
  witness in exactly one place: round 0 of a **Host/Standalone** slot, whose
  claim is *asserted* (standalone: 0; host: `Σ ν·κ·total_hosted`), not
  measured. That is exactly where the candidate evaluates in full
  (`argument.rs:536-538` passes `None`). The Private round-0 seed is the
  *measured* cube sum, so it holds for any witness. In every later round the
  identity holds for any witness, given the degree premise.
* **The premise (does not depend on the witness).** For every slot and every
  shape, the per-round degree of `def.poly` composed with the tables is at
  most the declared degree. I found no way for a witness to break it. The
  closures branch on no table value: `Gate::at` multiplies, and every `if`
  or `match` in `argument.rs` is decided when the slot is defined. The tables
  depend on the variables in a way fixed by the shape (`Tab::Eq/Pub/Priv`,
  coordinates, broadcast; `argument.rs:204-299`). Four pieces of evidence
  support the premise:
  1. **The lane's S34 test**
     `the_honest_round_polynomial_satisfies_s0_plus_s1_equals_the_running_claim_at_every_round`
     (`slot_ir_tests.rs:500-560`, in the native log). It covers all 23
     slots at toy and rung-P2, a padded shape with grouped key-value heads:
     379 rounds of 46 (shape, slot) pairs. The data is **not** an honest
     witness: dense A planes, but **random** H/io/multiplicity planes.
  2. **The design check §8.** A symbolic true degree ≤ declared for slots
     14–18 at 125M and rung-W14.
  3. **Codex's in-process oracle.** It ran in every lib test at the toy,
     tamper modules included.
  4. **Verifier acceptance.** Honest dense proofs from the new prover pass
     the verifier at every registered shape and 4× at 125M. A wrong
     recovered value would, with overwhelming probability, carry a nonzero
     difference to that slot's first extension round (computed from the
     *actual* finals), which the verifier checks. So acceptance is evidence
     that the recovery was exact at every one of those slots.

  If the premise ever failed, the old verifier would already reject honest
  proofs at that slot (a completeness bug that exists without R1d). R1d would
  only change how that bug shows up: a debug panic, or the refusal moving to
  the extension round.

### Q2 — Is the Private seed the unmasked sum for every Private slot at every shape? **Yes.**

* `scalar = total(tables, def.poly) + c·G` (`argument.rs:523`). The seed is
  `scalar − c·G` (`:537`), which is `total` word for word. `total` is
  computed over the **same** `2^n` tables with the **same** closure, just
  before the sumcheck, and nothing in between changes the tables.
* So the seed is the *actual* cube sum. It includes every support-indicator
  factor and every padded position, and it depends neither on the witness
  being consistent nor on the pad rule.
* **Slots 08/09** (score and PV): their `n` includes the `lkv` group bits
  (`shape.rs:1164-1165`), so the group bits are summed over like any other
  sumcheck variable. The group `eq` raises the declared degree to 3
  (`shape.rs:1186-1187`). This is covered at a grouped shape by S34 (rung-P2)
  and by the oracle (08/09 are small at every shape; see Q4).
* `SLOT_KINDS` is a constant that does not depend on shape
  (`layout.rs:885`). A Private slot with a non-empty `hosted` list is refused
  (`argument.rs:450`), so Codex's general formula reduces to `scalar − c·G`
  for every Private slot.
* One fragility: the seed is taken back out of the published scalar instead
  of from the computed total (R-4).

### Q3 — Is the interface additive, with no `Sync`, the old path unchanged and no leak? **Yes, with deviations from I-5 that should be written down.**

* **Checked by diff against the base:**
  * `zkp-core/src/sumcheck.rs` only gains `mod rounds; pub use rounds::{…}`
    (`:16-17`). `prove`, `verify`, `CfsMask`, `CfsMasker`,
    `extension_round` and `masked_terminal` are byte-identical.
  * `hashline/src/zk.rs` only gains `masked_prove_rounds` and a
    `#[cfg(test)]` module declaration after `masked_prove`'s closing brace
    (`:1088-1105`). `masked_prove` (`:1077-1086`), the mask commitment,
    opening and verification, and `extension` are untouched.
  * `argument.rs` changes only its import line and the prover arm of
    `run_slot` (`:529-560`). The verifier arm (`:586-612`) is untouched.
  * The other 17 `masked_prove` call sites, including the frozen
    `private_seam.rs` and `private_attention/argument.rs`, still use the old
    function.
* **No `Sync`.** `trait SumcheckRounds` has no supertrait, and
  `prove_rounds`/`masked_prove_rounds` take `R: ?Sized`. Only the CPU
  `ClosureRounds` impl needs `F: Sync`. A test covers a non-`Sync`
  `Box<dyn SumcheckRounds>`.
* **Old path unchanged.** No allocation or table order changes on the old
  path. On the new path, the fold and table order are the same code, with
  the same `1<<16` single-thread cutoff and 1024-element chunks.
* **No new leak surface.** `ClosureRounds` has private fields and no
  `Debug`. The seed can only be passed in. `prove_rounds` returns unmasked
  rounds and finals, exactly as the existing public `prove` does, and it
  documents this (`rounds.rs:30-32`). The only new exposure is in failure
  messages (R-9).
* **Deviations from I-5:**
  * `prove` was not turned into a wrapper over `ClosureRounds`, so there
    are now two near-verbatim copies of the round loop (R-8).
  * The trait documentation lists only part of the required preservation
    list, and the frozen byte gates are not named (R-5).

### Q4 — What does the validation establish? **The shortcut at the toy, fully, one slot at a time; the larger shapes only partly; nothing about end-to-end speed.**

* **It establishes:**
  * **zkp-core unit tests (57 + 2, debug and release).** Bytes, challenges,
    finals and the next challenge match `prove` for degrees 1–6 and sizes
    `n ∈ {0,1,2,3,5,7,9,16}`, on random tables — i.e. inconsistent tables —
    with a seed of `None` and with the exact seed, tagged and untagged, with
    serial and parallel folds, and with 1–2 masked extension rounds. A
    call-count test confirms that release builds really skip the
    evaluations. A wrong seed is caught by the terminal check.
  * **512 hashline lib tests (release).** With the `#[cfg(test)]` oracle
    comparing each bounded slot against the old `masked_prove` on cloned
    tables and transcript. At the **toy every one of the 23 slots** is under
    the 2^18-word bound: the largest are slot 17 at 30 × 2^11 and slot 14
    at 60 × 2^9 words. So every toy proof in the lib suite — the `tamper`
    module, `rung_tests::every_toy_tamper_family…` and the dense
    perturbation tests included — was byte-compared slot by slot.
  * **Tamper tests named by slot.** The c6, p2, w14 and e32 tests that
    check a tamper is "rejected at its own slot" pass.
* **It does not establish:**
  * **An end-to-end receipt comparison.** Proofs use OS randomness, so the
    new toy receipt's hash differs from the baseline's, as expected.
    Byte-identity rests on the per-slot oracle and on the algebra. The
    cross-version verification (the new receipt under the old verifier, the
    old receipt under the new one, 9 corruption controls) shows only that
    the wire format and the verifier still agree. The verifier code did not
    change.
  * **Oracle coverage at the larger shapes (R-3).** At 125M the oracle
    covers only slots 02, 03, 05–13, 19 and 20. Slots 00, 01, 04, 14–18,
    21 and 22 were never byte-compared, and the rung shapes are likely
    similar. No counter records which comparisons actually ran.
  * **Wider suites (R-2).** The debug-build hashline tests, the integration
    tests (`hashline/tests/*.rs`), the Python suite plus freeze-check, and
    the D22 gates were not run.
  * **The current lane code (R-2).** Everything ran at the **stage-35 base**
    (the native log has no `k8_`, `census_` or `s36`–`s42` tests), not at
    the lane tip.
* **GPU.** No GPU file is touched. The masked slot sumcheck is CPU-only and
    no device evaluator exists yet. All validation is CPU-only.
* **A/B timing** (`dense-ab-1`; dense synthetic 125M; lib *test* binary,
  release; two threads; shared box; A/B/B/A order; two samples per arm).
  **No end-to-end speed-up is established.** Whole proving took
  61.79 s / 38.96 s (old) against 43.02 s / 38.06 s (new). That spread comes
  from phases R1d does not touch: `open A` took 18.1 s in run 00 against
  0.6–0.8 s in the other three.

  Per phase:

  | Measure | Old (two runs) | New (two runs) | Change of the means |
  |---|---|---|---|
  | 23 slot sumchecks, summed | 13.875 s / 14.172 s | 13.349 s / 12.926 s | −6.3% |
  | Slot 17 | 9.053 s / 9.258 s | 8.590 s / 8.551 s | −6.4% |

  These figures **do not support 15.8%**, and the design would not predict
  15.8% either (R-6).

### Q5 — D22: does the candidate touch the toy profile's pinned files? **Yes: three pinned files, plus one new unpinned file on the path. Every hunk is either off the path, or on it with the same bytes and the same random draws. None changes behaviour.**

**What the pins say.** The D22 gate's pin table
(`zk60_native_mask_commit.py` `SOURCE_PINS`/`PATH_PINS` on
`zk60-native-jointview`) pins:

* `zkp-core/src/sumcheck.rs` at `56dbb8c7…`: the candidate's base **equals**
  this pin, and the candidate moves it;
* `hashline/src/zk.rs` at `c5b54753…`, with `ce8cc516…` also accepted: the
  candidate base is already `07282c76…`, and the candidate moves it again;
* `hashline/src/private_block/argument.rs` at `e62f46c2…`: the candidate
  base is already `f7fa2ad4…`, and the candidate moves it again.

The pre-read `ZK60_D22_PREREAD_SHAPED_SNAPSHOT.md` (`e4abb32`) records the
same snapshot state: `sumcheck.rs` equal, `zk.rs` and `argument.rs` MOVED.
R1d therefore turns that pre-read's "equal" row for `sumcheck.rs` into a
moved one and adds a second move to the other two.

**Hunk by hunk:**

| Hunk | Class | Why |
|---|---|---|
| `zkp-core/src/sumcheck.rs:16-17` (`mod rounds; pub use …`) | on the path as a module declaration only; **no existing item changed** | `prove`, `verify` and the CfsMask/CfsMasker/extension code are byte-identical by diff |
| `zkp-core/src/sumcheck/rounds.rs` (new; `prove_rounds`, `ClosureRounds`) | **on the prover path; same bytes, same draws** | draws no randomness; absorbs one `sc-round` and draws one challenge per round, as `prove` does; produces the same field values (Q1/Q2); the toy is oracle-checked on all 23 slots. **It is not pinned: the path-pin ruling ("every Rust file on the path") requires adding it** |
| `zkp-core/src/sumcheck/rounds/tests.rs` (new) | off the path | `#[cfg(test)]`, excluded by the pin table's own rule |
| `hashline/src/zk.rs:1088-1101` (`masked_prove_rounds`) | **on the prover path; same bytes, same draws** | builds the same `CfsMasker`; same `set_masker`/`take_masker`; the zero-`c` refusal is kept; its two new shape assertions cannot fire at the toy (mask spec `(n+ext, d)` comes from the same schedule) |
| `hashline/src/zk.rs:1103-1105` + `zk_rounds_tests.rs` | off the path | `#[cfg(test)]` |
| `argument.rs:36` (import) | off-behaviour | an import is removed, nothing more |
| `argument.rs:529-560` (prover arm) | **on the prover path; same bytes, same draws** | Private: exact seed; host/standalone: full round 0; the oracle is `#[cfg(test)]`; the verifier arm is untouched |

**The seven conditions:**

* **Condition 3** is kept: `d+1` values are still published per round
  (`prove_rounds` asserts it), and the zero-mask refusal stays at
  `argument.rs:477`.
* **Conditions 1, 2, 4, 5 and 6** are not touched.
* **Condition 7 is triggered.** For the changed tree, step 3 is suspended
  until the security owner re-reads and re-pins, keeping both digests and
  adding `rounds.rs`.

The classification above is input for that re-read, not the re-read itself.

## Findings

| # | Severity | Finding |
|---|---|---|
| R-1 | **blocking for landing** (no code defect) | pin gates: D22 condition 7 and the MVP security probe's `zk.rs` pin |
| R-2 | erratum | validated at the stage-35 base, not the stage-42 lane tip; wider suites not run |
| R-3 | erratum | the oracle is bounded and silent; the large 125M/rung slots were never byte-compared |
| R-4 | erratum | the Private seed is taken back out of `scalar` instead of the computed total |
| R-5 | erratum | I-5's preservation list is only partly in the trait docs; the frozen gates are unnamed |
| R-6 | note | the 15.8% figure does not describe this candidate; ≈8% expected [MODEL]; −6.3% measured |
| R-7 | note (confirms Codex) | the unseeded first round is necessary and optimal |
| R-8 | note | `prove` is not a wrapper: two round loops now exist |
| R-9 | note | failure messages print secret-derived values |
| R-10 | note | the shortcut lives in `ClosureRounds`, not in the trait or driver |
| R-11 | note | the hashline slot-level debug assertion never ran (release-only tests) |

**R-1 — blocking for landing, not a defect.**
* **D22.** The candidate changes `zkp-core/src/sumcheck.rs`,
  `hashline/src/zk.rs` and `private_block/argument.rs`, all pinned by the
  D22 gates, and adds `zkp-core/src/sumcheck/rounds.rs` on the toy path. By
  §5 condition 7, step 3 is suspended for that tree until it is re-read and
  re-pinned.
* **Security probe.** `scripts/zk60_mvp_security_probe.py:66-73` pins
  `zk.rs` at `ce8cc516…`, so landing the `zk.rs` hunk turns
  `tests/test_zk60_mvp_security_probe.py` red unless a reviewed re-pin
  follows. This is I-5's own precondition: re-pin before any further change
  to `zk.rs`.
* **Cheaper route.** `masked_prove_rounds` and its test hook use only
  zkp-core's public `CfsMask`/`CfsMasker`. Placing them in a new hashline
  file, e.g. `hashline/src/zk_rounds.rs`, would leave `zk.rs` unchanged. That
  removes the security-probe re-pin and the `zk.rs` part of the D22 re-read;
  the new file then needs a path pin instead.

**R-2 — erratum.** Validation ran at the stage-35 shaped base
(`4751b93 + fee1a8d`). The lane has since reached stage 42 (`6b68561`):
`private_block.rs`, `protocol.rs` and `run.rs` differ, and stage 40 added the
`#[cfg(test)]` `CheatingProver` soundness harness, which drives an
inconsistent witness through `run_slot`. `argument.rs` and `sumcheck.rs` are
byte-identical at the tip, so the patch applies there. Before accepting:
* re-run the lane gate `--lib private_` (473 tests at stage 42) with R1d
  applied at the tip;
* run the integration tests and the Python suite plus freeze-check, which
  CLAUDE.md says must stay green.

**R-3 — erratum.** The oracle compares only when
`tables.len()·2^n ≤ 2^18` (`argument.rs:542`) and says nothing when it skips.
At 125M the covered slots are 02, 03, 05–13, 19 and 20. The Private slots
00, 01 and 04 and the host/standalone slots 14–18, 21 and 22 — every slot
that carries real time — are never byte-compared, and the same is likely at
the rungs. Their exactness rests on
the algebra, on S34 and on verifier acceptance (Q1), which is strong but
indirect. Two recommendations:
* add a thread-local comparison counter, as s35's `COMPARED_HERE` does, and
  print coverage per shape;
* run the oracle once with the bound lifted at one padded, grouped shape
  (rung-P2 or rung-K4), on the dense witness and on one tamper family.

**R-4 — erratum.** The Private seed is computed as `scalar − c·G`
(`argument.rs:537`), taking the value back out of the *published* scalar
instead of keeping the computed total. It is exact today, because nothing
between `:523` and `:536` changes `scalar`. But any future edit that lets a
Private `scalar` differ from `total + c·G` would silently turn the seed into
an *asserted* value — for example a `#[cfg(test)]` cheating-scalar switch
like stage 40's `CheatingProver`. That would produce the new debug panic and
changed bad-proof bytes that the qualification exists to avoid. Fix: compute
`let actual = total(…)` once, publish `actual + c·G`, and seed
`Some(actual)`. This also drops the second `mask.total()` evaluation.

**R-5 — erratum.** I-5 required the preservation list in the trait
documentation. `rounds.rs:9-21` names:
* the absorb order;
* where the masker acts;
* that extension rounds and terminals stay with the caller;
* that implementations may change the arithmetic but never the field values.

It does **not** name:
* the refusal points (`e ∈ {0,1}`, a zero `c`);
* rayon chunking with exact field addition;
* the one-`sc-round`-per-round schedule as a hash-length fact.

The README does not name the frozen byte gates that must stay green (the toy
2,816,472 B frame and digest pins, the D22 gates, the security probe). I-5
asked for them to be named in the request.

**R-6 — note.** 15.8% (IR-C19) is the count for seeding *every* slot. For an
unseeded slot with `n` rounds, the shortcut applies on `2^(n−1) − 1` of
`2^n − 1` pair indices, i.e. about half. In run 00, host and standalone slots
take 13.29 s of the 13.875 s of slot sumcheck time (96%), so this candidate
can deliver about **0.52 × 15.8% ≈ 8%** of the counted baseline. [MODEL: this
assumes the saving is distributed like the measured seconds.] The measured
−6.3% of summed sumcheck phases (two samples per arm) is consistent with ≈8%
diluted by table differences, folds and memory traffic. Before any figure is
quoted, re-run the checker's counter with the unseeded rule. The A/B used the
lib test binary, so the oracle ran on 125M's small slots. That cost is
negligible at those sizes but should be stated.

**R-7 — note (confirms Codex).** The unseeded first round is necessary and
optimal:
* **Necessary.** Seeding a host/standalone slot from its asserted claim
  forces round 0 to pass on a tampered witness. The discrepancy then travels
  through the recovered rounds and reaches the slot's first extension round,
  which is computed from the *actual* finals. So the refusal moves from round
  0 to round `n` of the same slot, the bytes change, and debug builds panic.
* **Optimal.** No actual sum exists for free for those slots: computing one
  costs `2^n` evaluations, more than the `2^(n−1)` the shortcut would save
  in round 0.
* **Optional refinement.** For Private slots, round 0 does not depend on the
  transcript, so a full round 0 could *provide* the total (`s(0)+s(1)`) and
  replace the separate `total()` pass. That saves `2^(n−1)` evaluations per
  Private slot, which is negligible at 125M (`total` ≤ 0.06 s). It would
  need a "round 0 before the scalar absorb" hook, so it is not recommended
  now.

**R-8 — note.** I-5 had `prove` become a wrapper over a verbatim
`ClosureRounds`. The candidate instead keeps `prove` untouched and adds a
second, near-verbatim loop. This is defensible: `prove` stays an
**independent** oracle, as I-3 wants, and the D22 re-read of `sumcheck.rs`
stays at two lines. But the two loops now share their constants (`1<<16`
cutoff, 1024 chunk) only by copy. Record the deviation in the disposition.
The existing serial/parallel tests would catch any drift in values, not in
thread use.

**R-9 — note.** On failure, the assertion messages print values derived from
secrets:
* `debug_assert_eq!` at `rounds.rs:138` prints both sides; for a Private
  slot the right side is the slot's **unmasked total**;
* the `#[cfg(test)]` `assert_eq!` calls at `argument.rs:553-554` print
  unmasked finals and whole folded tables.

These fire only in debug or test builds, and only on failure. But test logs
are archived under `results/`. Prefer `assert!(a == b, "…")` with a message
that contains no values.

**R-10 — note.** The shortcut and its seeding rule live in `ClosureRounds`,
not in the trait or `prove_rounds`. Every future evaluator (device, lever
(c)) must re-implement the recovery and the "seed Private only" rule. Two
options:
* state the rule in the trait documentation;
* let the driver do the recovery, with the evaluator told to skip index 1.

**R-11 — note.** The hashline lib suite ran in release, so the slot-level
`debug_assert` in `ClosureRounds::round` never ran on a real slot. Only
zkp-core's debug unit tests exercised it. The oracle is the stronger check
where it runs. One debug run of the toy block tests would exercise the
assertion on real slots too.

## What I did not check

* **Nothing was run.** I did not build or run anything: `validate.py` needs
  the hashline release build (≈130 s build plus ≈210 s of tests), which is
  outside "cheap". All test outcomes above are Codex's records, read
  (log hashes not re-verified).
* **No symbolic degree check.** I did not verify each of the 23 closures'
  degree symbolically at every shape. The premise rests on my branch-free
  reading, S34 (toy and rung-P2), the checker's §8 (slots 14–18 at 125M and
  W14), the oracle and verifier acceptance.
* **The lane's later code.** I did not read stages 36–42 beyond hash
  comparison, and in particular not how `CheatingProver` reaches
  `run_slot`.
* **Codex's scripts.** I did not review `validate.py`, `finish_validation.py`
  or `benchmark.py` line by line.
* **Counts and the privacy argument.** I did not recompute the 15.8% or my
  ≈8%, and did not re-derive the D22 privacy argument. For D22 I read only
  the §5 conditions and the pin tables.
* **Out of scope.** The private-attention profile (unchanged: it still
  calls `masked_prove`), the GPU paths (untouched, and no device evaluator
  exists), and trained weights or larger-profile privacy.
