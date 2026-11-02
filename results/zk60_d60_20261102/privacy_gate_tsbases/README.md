# TS-1, the claim census and the hash census on D55 fork runs, and the three uncaptured registered bases (2026-11-02)

This lane closes three items that `../privacy_gate_r26/README.md` §7 lists as owed before the v25 staging privacy gate
can be frozen, for REGISTERED R13 D55 ("commit, fork, join") fork-run bundles:

1. **TS-1 and the claim census** on a D55 capture (they existed for D12a runs only);
2. **a Python hash census that reads a D55 bundle** (only the Rust s25 W-2 census measured the registered profiles);
3. **the registered bases never captured**: TinyLlama T128 LOW, Shieldstral T128 and Shieldstral T256.

Privacy requirement P1 is not reopened. v25 is NOT frozen. No v24 or frozen file was edited. No pinned Rust file was
edited (every bundle still has 75 pins at the round-26 digests). `run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is
untouched (false).

**Verdict: all 12 final records are D55-PASS** (`records_final/`, the authoritative records). They cover:

* the four round-26 registered bundles (R13 rung and 8B T128, two hidden inputs each);
* the eight new registered-base bundles: TinyLlama T128 LOW, Shieldstral T128, Shieldstral T128 with layer 1 at its
  OWN norm constant, and Shieldstral T256, two hidden inputs each.

Every record has 16 of 16 parts true, including the four new ones (TS-1, CENSUS, HASH-1, HASH-2). Every one of this
lane's 480 control verdicts is as predicted. Every pin is at r19b or read, and the backend is admissible (CPU-made).

On the way, the first pass found a real gap, in the Rust s25 W-2 census rather than in the bundles: it never
measured a registered D55 run at L = 2..9. That was fixed in Rust test code (section 3), and the gate re-ran on all
12 bundles.

What this is not:

* **Not a privacy acceptance, a registration or a statement.** D55-PASS means "every part computed true, and the code
  that made the bundle is read" — the round-26 meaning.
* **Not real content.** Every bundle is test-only and synthetic: one public synthetic block at every layer (no trained
  weights are on this host), or Sol's public rung fixture.
* The three SELF-READ readings of round 26 are still owed an independent check at the v25 freeze review.

## 1. What was ported

### TS-1 and the claim census (`staging_v25/scripts/zk60_native_rg_d55ts.py`, part names `TS-1 …` and `CENSUS …`)

The D12a / token / classifier wrappers (`zk60_native_rg_tokents.py`, `zk60_native_rg_ddts.py`,
`r22-item3/zk60_r22_classts2.py`) run the frozen G-7 tool `EV/g7/ts_trained.py` on a capture's commitments. The port
runs the same tool on **every commitment a D55 bundle opens**: each fork's A and H (`stage-KK.json`) and every tail
opening (`d55_tail.json`: the internal boundaries B0, B1, then the external input and output endpoints) — 10 roles
for an L = 3 run — each at its own row width.

* **The tool is used unchanged.** `ts_trained.py` is read from the repository and its SHA-256 compared with the pin
  (`d6f6cf93…`, `zk60_native_rg_tokents.TS_TRAINED_PIN`) before anything runs. It names its review scripts at the
  laptop path, so the ONE line `TS = "/home/victor/…/zk60_terminal_surjection_review"` is replaced by the repository's
  copy of that directory. ts_trained then checks its own three review-script pins there. Every record carries both
  digests and the replaced line (`loader`).
* **TS-R, the role analysis** (as `tokents.analyse`): the structural audit of the claim schedule, every claim group's
  system (blinding rank, onto-ness, the annihilator on blinding and data, "disclosed" by the null-space form, the
  original form too on small groups), and every joint component of groups sharing a non-data row (H's zero-sum pair).
  Expected, as the classifier precedent: every A, boundary and endpoint discloses 0 with every group onto; every H
  discloses exactly its declared zero-sum pair (2 Fp) in its one joint component; the audit has no finding.
* **TS-1, the control**: on every role with a singleton site-pair group (the one with the fewest data rows, classts2
  v2's rule), one claim's reserved pair is removed. The honest group must disclose 0 and the pair-removed one must
  disclose more than 0.
  * The pair-removed arm is computed by the tool's **original form** (its own `group_system`, then all blinding and
    data generators into one eliminator: `rank(B|D) - rank(B)`, ts_trained.py:307-314), not by its null-space form.
    With the pair removed, a singleton group has no blinding row, so the null-space form evaluates all 2(N + 1) unit
    functionals on each of rows × N data generators: 8,776 s for ONE 38-row role at the real classifier block
    (round 23), about 5 h for one 8B tail opening. The original form gives the same rank in seconds.
  * **TS-1F** runs the null-space form too on the bundle's cheapest TS-1 row (at most 2 data rows). Both forms must
    agree and equal TS-1's figure. They did on every bundle.
* **TS-RC**: the review's own nine controls (`ts_trained.controls`: honest reference, C1, C2, C3, C6, C8, G7-D1, D2,
  D3) on the first two-member group of fork 0's A, each against the prediction ts_trained writes beside it (fires:
  C1, C2, G7-D3; does not fire: the other six — the pattern the real classifier block measured in round 23).
* **CENSUS** (`ts_trained.pcs_census` on every role): identical claims, equal published values, and claims with the
  same data weights in one group must each be EMPTY (condition C-9's lapse trigger). Controls on doctored copies of
  fork 0's A: CEN-1 a claim duplicated, CEN-2 one claim's value set to another's, CEN-3 a claim at twice another's
  coefficient (same data weights, not identical). Each must be caught.
* The groups, components and TS-1 rows are independent pure computations and run in a 16-process pool
  (`ZK60_D55TS_WORKERS`); the figures do not depend on the order.

What TS-1 and the census prove: on each captured commitment, at that run's real challenges, the linear model of what
a verifier sees from the opened groups discloses nothing beyond the declared zero-sum pair, and the instrument would
have shown a disclosure had a reserved pair been missing. What they do not prove: anything about the hash layer, the
non-linear tables (NL-1, owed elsewhere), or a distribution over runs; each figure is a rank of a stated linear model.

### The hash layer and the hash census (`staging_v25/scripts/zk60_native_rg_d55hash.py`, part names `HASH-1 …`, `HASH-2 …`)

* **HASH-1, the hash layer** (D12a's run-gate stage 9, `check_hash_layer`, ported): every opened column of every
  fork's M, A and H (the D12a function, unchanged) and of every tail opening (the same fold, written here because the
  tail has no M) is re-hashed and its Merkle path re-folded to the committed root under the rule DERIVED from the
  block profile; the path depth is checked. Controls, each must fire:
  * the D12a cross-rule probe (legacy and three role-permuted key sets: none may reach the root);
  * HL-2 every opened column under the key set derived for ANOTHER registered R13 profile: 0 authenticate;
  * HL-3 the tail under the legacy rule: 0 authenticate;
  * HL-4 a tail column's value moved by one; HL-5 a fork column's salt byte flipped; HL-6 a tail path one entry
    short (refused by the depth check); HL-7 two tail openings' roots exchanged;
  * HR-1 / HR-2 / HR-3 the declared `hash_tag`'s key, context and profile altered (refused by the derivation);
  * HR-4 the D55 header absorbed under the legacy rule does not reproduce `run_binding` (the derived rule does).
* **HASH-2, the hash census, MEASURED** (round 22's `round22/census/hash_census.py`, ported from the classifier replay
  to the D55 one and widened to every function). While the process derives the four tag keys, recomputes the
  registered schedule digest, replays the whole D55 transcript and re-folds every opened column, EVERY BLAKE3 call is
  recorded by length only (no value is kept) and classified by the function that hashes it (s25's definition: the
  transcript, column, leaf and node keys, `derive_key`, unkeyed). Transcript calls are also recorded by kind; the two
  accounts must agree. Conditions:
  * C-R1 no unkeyed input is 40 bytes (the generator's refill length);
  * C-R2 no transcript constructor input is 47 bytes (the squeeze);
  * W-2 the constructor's length equals no other transcript input's and is not one byte from any;
  * W-2g (s25's rule) per function, no two different kinds of equal length unless DECLARED with the literal that
    separates them (s25's `DECLARED` list, ported with its reasons); pairs within one byte are listed;
  * ACC every call is attributed to exactly one function;
  * every measured kind is looked up in the Rust s25 W-2 census printout for the bundle's run profile; a measured
    kind the Rust table does not list is a finding (this is what found section 3's finding).
  * Controls, each making REAL hash calls on doctored inputs through the same recorder: HC-1 a 35-byte domain
    (C-R2), HC-2 / HC-3 a constructor as long as / one byte longer than the commonest absorb (W-2), HC-4 an unkeyed
    40-byte input (C-R1), HC-5 a new label's absorb as long as another label's (W-2g), HC-6 a call under a key no rule
    derives (ACC), HC-7 a `parameters` absorb 64 bytes longer than the run's (the Rust-table lookup must name it).

What the hash parts prove: the verifier's authentication of the columns it opened is computed under the derived
keys, and the hash inputs the gate itself computes are separated by length or by a declared literal. What they do
not prove: what an unopened leaf hides (a hash assumption, M-2 / M-3), or anything about the prover's own calls (the
generator's refill and seed derivations, D1 / D2 / D3 / D4 / D7), which never run in the gate; the Rust s25 census
covers those by arithmetic.

### The driver

`zk60_native_rg_d55.py` gains ONE block marked `# --- [TS / CENSUS lane, 2026-11-02] begin` / `end`. At an R13 base,
once the replay reproduced the transcript, it adds the four parts, removes `TS-1 and the claim census` and `the hash
census on the Python side` from `not_here`, and makes the record NOT-OK if any of them is false. The W16 path is
unchanged. Nothing outside the block was edited.

## 2. The bases captured

The round-26 writer (`run_fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles`) already took the base as
a parameter. One option was added, in test code only (`run_fork_tests.rs`, which is in no capture pin list):
`PROFILE:hidden:own`.

* **Why.** The writer gives every layer the run's calibration, so a Shieldstral bundle it writes carries no
  per-layer own-calibration clause, and the gate's own-clause path (`fork_calibrations`) would still be untested.
* **What.** The `own` variant proves layer 1 at its OWN norm constant: `norm cn_a 101 (the layer's own; the run's
  is 100)`. cn_a is outside the R13 accuracy base, so the block's public data and digest are the same at every
  layer, and fork 1's stage line carries the clause. The input search now requires the whole chain to build (the
  previous choice wherever the previous rule did not panic).

Every bundle was written on the CPU (`HL_GPU` unset; manifests say `proved_on_gpu: false`), guarded, by the binary
`7a4d3125…` (`logs/build1.log`), `HL_TEST_SOURCE_COMMIT=e44c01f5`, into
`/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases/` (marked `TEST_BUNDLES_NOT_FOR_PUBLICATION.txt`).
The writer read every bundle back and ran the Rust gate checks on it (REG, PG-7, PG-8, PG-10, C-2 / C-5 / C-6):
**12 checks, all PASS, every control fired**, for all eight (`logs/write-*.log`).

| bundles | base (registered D55 profile over) | hidden inputs | size each | write (guarded cpu) |
|---|---|---|---:|---|
| `d55-r13_tiny_t128_low-s0`, `-s1` | `…/private-run-tinyllama-1.1b-t128-low-stack-v01-run/1` | M10's family, s = 0 / 7 | 209 MB | 17 s, peak 12.4 GiB |
| `d55-r13_shield_t128_h24-s0`, `-s1` | `…/private-run-shieldstral-3b-t128-lowh24-blocks-run/1` | the same | 311 MB | 28 s, 20.8 GiB |
| `d55-r13_shield_t128_h24-own-s0`, `-s1` | the same, layer 1 at its own `norm cn_a` 101 | the same | 311 MB | 28 s, 20.9 GiB |
| `d55-r13_shield_t256_h24-s0`, `-s1` | `…/private-run-shieldstral-3b-t256-lowh24-blocks-run/1` | the same | 530 MB | 48 s, 46.5 GiB |

The four R13 DD bases stay refused by name (SC_DD not ported).

## 3. A finding, and its fix: s25's W-2 census did not measure L = 2..9

**What was found (pass 1, `records/`).** HASH-2 was FALSE on every non-rung bundle. That covers TinyLlama T128,
Shieldstral T128, Shieldstral T128 own and Shieldstral T256, two each, and also the round-26 8B T128 pair, which had
been D55-PASS before these parts existed. Every other part was true on all of them. The finding was the same each
time: the Rust-table lookup named ONE measured kind that the Rust s25 W-2 printout (`logs/s25_w2_printout.log`)
does not list for the bundle's run profile, "the transcript absorb of `parameters` with N bytes of data":

| base | `parameters` data at L = 3 (the bundles) | listed by s25 (L = 1 / L = 22 and 32) |
|---|---|---|
| R13 rung (7-row boundary) | 251 B | 251 / 252: listed, so the rung records passed |
| TinyLlama T128 (22-row boundary) | 257 B | 256 / 258 |
| Shieldstral T128 and T256 (38-row boundary) | 258 B | 257 / 259 |
| 8B T128 (38-row boundary) | 259 B | 258 / 260 |

(`param_lengths.py logs/s25_w2_printout.log`: each bundle's `parameter_line` length and the lengths the printout
lists for its run profile.)

**Why the length depends on L.** A registered D55 run's parameter line is D12a's (`run.rs:748-760`) with its last
clause replaced. Two of its fields move with the block count:

* `/L{l}/`: the decimal digits of L;
* `-rows{rows}-sites`: the boundary commitment's rows when L > 1, and `0` when L = 1 (no boundary).

So the line has one length at L = 1, another at L = 2..9, and a third at L = 10..99. s25's census measured each
registered D55 profile at L = 1, 22 and 32 only (`s25_tests.rs`, the D55 loop), so the L = 2..9 class was never
in its table. The bundles are L = 3. At the rung the boundary has 7 rows (one digit, like `0`), so L = 3 has the
same length as L = 1. That is why only the rung passed.

**The Python side measured correctly.** The 257 / 258 / 259 B absorbs are the bytes the D55 replay really absorbs:
the replay reproduces `run_binding` with them, and the transcript-level and BLAKE3-level accounts agree. No Python
change was needed. The lookup was kept as strict as it was. One control was added so the lookup itself is shown to
refuse: HC-7 makes a REAL `parameters` absorb 64 bytes longer than the run's (no L can produce it), and the lookup
must name it.

**The fix, on the Rust side, test code only** (`s25_tests.rs`, in none of `SHARED_SOURCE_FILES`,
`OWN_SOURCE_FILES` or `CLASSIFY_SOURCE_FILES`; checked before editing; commit `076a485f`):

* every registered D55 profile is now measured at **EVERY L in 1..=32**, which covers every R13 checkpoint's block
  count (TinyLlama 22, Shieldstral 26, 8B 32: D60 F9) and the A/B's 32; an assertion requires the measured set to be
  exactly 1..=32;
* **the length lemma**, asserted on every measured line: the parameter line at L is the L = 1 line with `/L1/`
  replaced by `/L{L}/` and `-rows0-sites` by `-rows{R}-sites` (R the boundary rows, the same at every L > 1), and
  nothing else; so its length is `len1 + (digits(L) - 1) + (L > 1 ? digits(R) - 1 : 0)`, one value per digit
  count of L; the formula is asserted equal to the substituted lines' lengths, and the measured lengths at 1..=32
  equal the lemma's;
* the `parameters` absorb at **every digit count of a u64 L (1..20)** is held to s25's own per-function rule against
  the profile's other transcript-function kinds: any equal-length pair must be DECLARED.

**The fixed census, measured** (`build.sh full build2`: binary `31e0ea86…`, 133 warnings, the round-26 count;
then `logs/s25_w2_v2.log`, copied to `logs/s25_w2_printout_v2.log`, sha256 `bac4bbd6…`):

* `test result: ok`, 35 s; 106 profiles, 34,141 hash input kinds, the D55 fork run over 421 base statements (73 before).
* Each registered D55 profile appears 32 times. Every lemma assertion holds. At no digit count of L does the
  `parameters` absorb meet an undeclared kind of equal length: **no new undeclared pair, so no new finding**.
* The lemma's lengths over every u64 L are one per digit count of L, plus the L = 1 line:

| registered D55 profile over | R (boundary rows) | `parameters` data length over every L | at L = 1..=32 |
|---|---|---|---|
| TinyLlama T128 (and its DD twin) | 22 | 256, 257, …, 276 | 256 / 257 / 258 |
| 8B T128 (and DD) | 38 | 258, …, 278 | 258 / 259 / 260 |
| Shieldstral T128 and T256 (and DD) | 38 | 257, …, 277 | 257 / 258 / 259 |
| the four development rungs | 7 | 251, …, 270 | 251 / 252 |

* `param_lengths.py logs/s25_w2_printout_v2.log`: the printout now lists the bundles' L = 3 lengths (257, 258, 259)
  for every base.

Pass 2 (`queue2.sh`: the rebuild, the census, then `pygate_all2.sh`) re-ran the WHOLE D55 gate on all 12 bundles
against the new printout, on one tool state, into `records_final/` (logs `logs/final-*.log`). Pass 1 stays in
`records/` and `logs/py-*.log` as the evidence of the finding. One correction about pass 1's bookkeeping: in
`queue.sh` the logged `rc=` values in `logs/queue.progress` are `date`'s exit status, not the steps'. The guard's
`logs/*.guard.done` markers carry the real codes, and pass 1's non-rung records exit 1 (NOT-OK). `queue2.sh` keeps
each step's code.

## 4. Per-bundle results

**Which records count.** `records_final/` (pass 2) is authoritative.

* Every pass-2 record was made by `pygate_all2.sh` on ONE tool state (commit `076a485f`; `tool_sha256` in every
  record), each run guarded at the cpu class, with its pair as `--other` and the TS pool at 16 workers.
* `check_final.py` (output in `logs/check_final.out`) checks each record part by part and control by control. It
  does not trust the status field.
* `summarize.py records_final` prints every figure (`logs/summarize_final.out`).
* `records/` is pass 1: the finding of section 3 (`logs/summarize_pass1.out`). Its rung records were already
  D55-PASS and its other records NOT-OK, by HASH-2 alone. `records/d55-first-r13-rung-s0.json` was a first run made
  without the printout.

| record (`records_final/d55-final-…`) | status | parts | R13-3: G per fork, slots per fork | own clause | TS-1 rows fire | census claims (findings) | HASH-1 columns | HASH-2 constructor; Rust kinds; missing | replay challenges / failures | wall / peak (guard) |
|---|---|---|---|---|---|---|---|---|---|---|
| `r13-rung-s0` | **D55-PASS** | 16 / 16 | 20 / 21 / 20, 23 each | — | 10 / 10 | 615 (0) | 3,328 / 3,328 | 107 B; 129; none | 4,934 / 0 | 346 s / 11.8 GiB |
| `r13-rung-s1` | **D55-PASS** | 16 / 16 | 20 / 21 / 20, 23 each | — | 10 / 10 | 615 (0) | 3,328 / 3,328 | 107 B; 129; none | 4,934 / 0 | 346 s / 12.1 GiB |
| `r13-8b-s0` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | — | 10 / 10 | 606 (0) | 3,328 / 3,328 | 125 B; 129; none | 30,339 / 0 | 890 s / 10.8 GiB |
| `r13-8b-s1` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | — | 10 / 10 | 606 (0) | 3,328 / 3,328 | 125 B; 129; none | 30,339 / 0 | 890 s / 11.0 GiB |
| `tiny-t128-s0` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | — | 10 / 10 | 603 (0) | 3,328 / 3,328 | 129 B; 129; none | 18,614 / 0 | 647 s / 11.3 GiB |
| `tiny-t128-s1` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | — | 10 / 10 | 603 (0) | 3,328 / 3,328 | 129 B; 129; none | 18,614 / 0 | 650 s / 11.1 GiB |
| `shield-t128-s0` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | — | 10 / 10 | 606 (0) | 3,328 / 3,328 | 129 B; 129; none | 30,345 / 0 | 944 s / 11.1 GiB |
| `shield-t128-s1` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | — | 10 / 10 | 606 (0) | 3,328 / 3,328 | 129 B; 129; none | 30,345 / 0 | 934 s / 11.1 GiB |
| `shield-t128-own-s0` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | fork 1: `norm_cn_a` 101 (run 100) | 10 / 10 | 606 (0) | 3,328 / 3,328 | 129 B; 129; none | 30,345 / 0 | 932 s / 11.1 GiB |
| `shield-t128-own-s1` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | fork 1: `norm_cn_a` 101 (run 100) | 10 / 10 | 606 (0) | 3,328 / 3,328 | 129 B; 129; none | 30,345 / 0 | 927 s / 11.0 GiB |
| `shield-t256-s0` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | — | 10 / 10 | 615 (0) | 3,328 / 3,328 | 129 B; 130; none | 34,233 / 0 | 2,456 s / 19.6 GiB |
| `shield-t256-s1` | **D55-PASS** | 16 / 16 | 19 / 19 / 19, 23 each | — | 10 / 10 | 615 (0) | 3,328 / 3,328 | 129 B; 130; none | 34,233 / 0 | 2,433 s / 19.9 GiB |

The parts are D55-0, D55-1/2, D55-3, R13-H, R13-2, R13-3, R13-6, R13-7, D55-IO, D55-J, D55-C and PINS controls
(round 26's twelve), plus this lane's TS-1, CENSUS, HASH-1 and HASH-2. On every record:

* pins: 75 declared, 41 at r19b, 34 read, 0 unread; backend CPU, admissible;
* round 26's three SELF-READ readings are named, owed at the freeze review.

The TS figures, the same on every record of a base:

* **A**: 36 of 36 groups onto, 0 disclosed. Rows: 437 at the rung, 4,577 at 8B and Shieldstral T128, 5,125 at
  Shieldstral T256.
* **H**: 8 of 9 groups onto, disclosed 2, its joint component [7, 8] disclosing exactly 2.
* **Boundaries B0, B1** (2 groups) **and endpoints** (1 group): onto, 0 disclosed.
* The 10 role expectations hold on every record.

TS-1's pair-removed group discloses:

* 16,384 Fp (= N, one data row) or 32,768 (two or more rows) at N = 2^14;
* 65,536 at Shieldstral T256 (N = 2^15).

TS-1F ran the null-space form on one row per bundle, and both forms agreed every time:

| bundles | TS-1F row | data rows |
|---|---|---|
| rung | fork 0's A | 1 |
| TinyLlama | fork 0's A | 2 |
| 8B and Shieldstral | fork 0's H | 2 |

The TS part took 242 s (rung), about 510 s (8B, Shieldstral T128) and about 1,570 s (Shieldstral T256) inside each
gate run.

**The own-clause path (the Shieldstral finding the task anticipated did not occur).** On the `-own` bundles:

* R13-3 parsed fork 1's clause `norm cn_a 101 (the layer's own; the run's is 100)`, evaluated fork 1's 23 slots at
  cn_a = 101, and all 23 closed. Forks 0 and 2 closed at the run's 100.
* Every other part is true.
* So the gate's per-layer path works on real own-clause data for a norm constant.
* It is NOT yet exercised for an own constant inside the R13 accuracy base (a shift such as `sh_s`, which the real
  Shieldstral export carries per layer). That needs per-layer block data and digests, which this writer does not
  build. Owed (section 7).

## 5. Controls

Over the 12 final records, **480 of 480 of this lane's control verdicts are as predicted** (`check_final.py`):

| family | per record | total | what fires |
|---|---|---|---|
| TS-1 rows (pair removed) | 10 | 120 | every role: honest 0, pair removed > 0 |
| TS-RC (the review's nine) | 9 | 108 | C1, C2, G7-D3 fire; honest, C3, C6, C8, G7-D1, G7-D2 do not, as ts_trained predicts |
| CEN-1 / 2 / 3 | 3 | 36 | each doctored role is caught |
| HASH-1 (cross-rule probe, HL-2..7, HR-1..4) | 11 | 132 | 0 columns authenticate under a wrong rule or a doctored column; the tag edits are refused; the legacy header does not bind |
| HASH-2 (HC-1..7) | 7 | 84 | each doctored measurement breaks its condition; HC-7's kind is named by the Rust lookup |

Round 26's own controls (R13-H, the R13 block port's, D55-IO, J-C1..J-C6, the exclusivity and mask controls, D55-C,
PINS B-1..P-2) are inside the parts, which are all true. The Rust writer's own checks (C-2 / C-5 / C-6 among its 12)
fired on every new bundle.

## 6. The suite

`suite.sh` (guarded, `logs/suite_v25.log`), with every bundle round 26 named plus the eight new ones:

**160 tests: 87 ok, 72 skipped, 1 failure.** That is round 26's baseline (150 / 71 skipped / 1 failure) plus this
lane's 10 tests in `test_d55_ts_hash.py`. Nine of them ran and passed, including the test on all eight new bundles.
One is skipped by design (`ZK60_D55TS_FULL`). The failure is the pre-existing `test_r19b_self_check_and_its_control`,
whose r16b..r19b CLI binaries stayed on the laptop.

The Rust side, with binary `31e0ea86…` (`logs/build2.log`): the gpu-metal test build and the no-feature `cargo check`
both finished, with 133 warnings (the round-26 count). The changed s25 W-2 test passes (`logs/s25_w2_v2.log`). The
other Rust floors (scans, dev bytes, the D55 set) were not re-run: only test files changed, `run_fork_tests.rs` and
`s25_tests.rs`.

## 7. Still owed

Covered here: TS-1 and the claim census on D55 captures; the Python hash census reading a D55 bundle (and, through it,
the s25 W-2 coverage gap, now closed); the three registered bases captured and gated; the per-layer own-clause path
for a norm constant.

Not covered, still owed:

* **NL-1 (S1–S5) and the full zero-data preimage on the R13 slots at D55:** the other lane's (the parallel NL-1 /
  preimage block of the same driver). They stay in each record's `not_here`.
* **W16:** T-0 of the seven W16-redefined slots and NL-1 on them stay deferred while W16 is unregistered. This lane's
  parts run only at R13 bases; the W16 records are unchanged.
* **GPU-made bundles:** none was made or gated. Every bundle here is CPU-made, and a GPU-made bundle is still refused
  (no full reading of the Metal device paths).
* **An own constant inside the R13 accuracy base** (a per-layer shift such as `sh_s`, the real Shieldstral export's
  kind). The writer here only varies a norm constant.
* **The v25 freeze review.** It must include the independent check of round 26's three SELF-READ readings and the
  review of this lane's code. It should check especially:
  * the one relocated line of `ts_trained.py`;
  * TS-1's pair-removed arm by the original form;
  * the D55 tail fold;
  * the hash census's attribution rule.
* **Also open, unchanged:** G_k is recovered on SC_FZC and not read from a bound line. Two header words are taken as
  bound bytes. No real trained weights are on this host. The four R13 DD bases are refused by name (SC_DD not ported).

v25 is not frozen. v24 is untouched. `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` stays false.

## 8. Files

Code (worktree branch `worktree-agent-ad5119ba9083f7dc7`, on `perf/zk-batch-optimizations` at `9432e88a`):

* `e44c01f5`, Rust test code: the writer's `PROFILE:hidden:own` option (`run_fork_tests.rs`).
* `732e3587`, the Python code:
  * `staging_v25/scripts/zk60_native_rg_d55ts.py` (new);
  * `zk60_native_rg_d55hash.py` (new);
  * the one block in `zk60_native_rg_d55.py`;
  * `staging_v25/tests/test_d55_ts_hash.py` (new, 10 tests);
  * the lane's scripts.
* `076a485f`, the finding's fix:
  * `s25_tests.rs`: every L in 1..=32 and the length lemma;
  * HASH-2's HC-7;
  * the pass-2 scripts.
* The records commit, which adds this README, the records and the logs.

Here:

* **Records:** `records_final/` (authoritative, 12) and `records/` (pass 1, 13). `bundle_manifests/` holds the eight
  new bundles' manifests and READMEs, with `MANIFEST_SHA256.txt`.
* **Scripts:**
  * `build.sh`, `run.sh`, `capture_all.sh`, `queue.sh` (pass 1), `queue2.sh` (pass 2);
  * `pygate.sh` / `pygate_all.sh` (pass 1), `pygate2.sh` / `pygate_all2.sh` (pass 2);
  * `suite.sh`, `detach.py`, `summarize.py`, `check_final.py`, `param_lengths.py`, `copy_manifests.py`.
* **Logs:** `logs/` holds each guarded run's `.log`, `.cmd` and `.guard.done`. The s25 printouts are kept only as
  `s25_w2_printout.log.gz` and `s25_w2_printout_v2.log.gz`, with the plain files' SHA-256 in `PRINTOUTS_SHA256.txt`.
  The plain printouts (1.5 MB and 4.8 MB, each with a byte-identical `s25_w2*.log` twin) are NOT committed.
* **The bundles:** outside the repository, never committed.
  * New: `/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases/`, 209–530 MB each.
  * Round 26's, read only: `/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/`.

To repeat, in order:

1. `build.sh full build2`
2. `capture_all.sh` (with `SOURCE_COMMIT`)
3. The s25 printout (`queue2.sh` step 2)
4. `pygate_all2.sh`
5. `check_final.py`
6. `suite.sh`
