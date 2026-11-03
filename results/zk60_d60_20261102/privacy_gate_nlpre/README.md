# NL-1 and the full zero-data preimage on the registered R13 D55 bundles (2026-11-02)

Gate round 26 (`../privacy_gate_r26/README.md` §7) left, among others, two items owed before the v25 staging privacy
gate can be frozen, for the REGISTERED R13 D55 ("commit, fork, join") fork-run bundles:

1. **NL-1 (S1–S5)**, the non-linear table checks, on the R13 slots, at D55, on every fork;
2. **the full zero-data preimage** on a D55 capture: A and H at MSG != PAD, both halves, every opened column and the
   salted leaves.

This directory ports both into the v25 staging D55 gate, runs the full gate on the four round-26 bundles, and records
the result. Privacy requirement P1 (`ZK60_PRIVACY_REQUIREMENTS.md`) is not reopened.

**Verdict: all four records stay D55-PASS with both new parts included.** These are the R13 rung and the 8B T128
geometry, at two hidden inputs each.

* **NL-1 holds on every fork.** That is 21 / 21 slot instances per bundle: 7 slots × 3 forks, at G 20 / 21 / 20 on the
  rung and 19 / 19 / 19 at 8B.
* **The full zero-data preimage is exhibited for all 10 commitments of every bundle.** That is 3.0 M (rung) and 9.4 M
  (8B) view entries, 0 differing, and 2,560 salted leaves authenticated per bundle.
* **Every new control fires: 382 of 382.** The 18 N5-2 rows that do not apply are slots with degree slack > 0.
* Every older control of the gate still fires too. Over the four records there are 550 control verdicts in all: 532
  fire, the 18 do not apply, and none fails to fire.
* No check failed on a real bundle, so there is no finding.

What this is not:

* **Not a privacy acceptance, a registration or a statement.** D55-PASS still means "every part computed true, and the
  code that made the bundle is read". Other items stay owed (section 6).
* **Not real content.** The bundles are round 26's test-only synthetic bundles (`TEST_BUNDLES_NOT_FOR_PUBLICATION.txt`).
* v25 is NOT frozen. No v24, `frozen_*` or `staging_v24` file was edited. No Rust file was touched (none of the
  capture source pins moved, so the bundles' pin digests are unchanged). `run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED`
  is untouched (false).

## 1. What was ported

### NL-1 on the R13 slots, every fork (`staging_v25/scripts/zk60_native_rg_d55nl.py`, new)

**Where it came from.** NL-1 at R13 was implemented in gate round 22 item 3
(`ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classnl.py`, `run_r13`) for the R13 classifier captures, which are
D12a runs. Round 23 ran it on all 26 real Shieldstral blocks, and the accepted classifier statement (D58) rests on it
(its G-R2). The modules it uses are byte-identical in frozen v23 and staging v25 (checked: `tokennl`, `tokenterminals`,
`terminals`, `r13slots`, `r13blocks`, `gqa`, `planes`, `tokenblocks`).

**What it does.** It feeds the FROZEN `results/zk60_nonlinear_channel_shaped/nl_check.py` (digests `e4db99a2…` /
`ea8ca392…` checked before import, no bytecode written there) a slot IR of each R13 slot. The IR is built from the
gate's own R13 port, expanded symbolically into monomials. The seven slots are round 22's: SC_LZC 3 (its lookups
change at R13) and the six bodies R13 redefines, SC_DZC 14, SC_QZC 15, SC_KVZC 16, SC_SZC 17, SC_FZC 18, SC_TAB 19.

**What changed for D55** (the layout only):

* the slots are built per FORK, through the D55 gate's one-fork shim (`zk60_native_rg_d55r13._shim_for`), at that
  fork's own calibration and at the gate denominator G_k that part R13-3 recovers (a D55 stage line does not print
  G_k: the D60 record's finding 1);
* the frozen nl_check is found in this repository (the old loader names the laptop's path), at the same digests;
* the trick that lets the port run on symbolic values (rebinding four field functions) is scoped to a `with` block
  and restored after, instead of lasting for the whole process.

**The checks, in order.** First the chain of fidelity, so the IR is known to be the real polynomial:

* **T-0**: the port, evaluated on this fork's own published terminals, rebuilt tables and replayed challenges, equals
  the terminal polynomial the fork recorded;
* **E-0**: the symbolic expansion, evaluated at those same values, equals the port;
* **F-0**: nl_check's own evaluation of the IR, at random table values, equals the port (three seeds).

Then nl_check's stages, in four challenge modes (the run's replayed challenges and three random seeds):

* **S1** per slot: every monomial has a public factor; the degree fits the declared degree; every private factor
  sits in its extension round; the mask budget L + 256 ≤ 512 holds;
* **S2**: the per-fork sums;
* **S3**: Fact 2.1 is tight at every distinct (rounds, degree) pair of the seven slots, five regimes each. Added here:
  the same at the pairs of ALL 23 slots, with the mask budget of all 23 (round 23's carry for the 16 unchanged slots);
* **S4**: a miniature honest masked run per slot accepts, and its terminal map is onto F_p²^m;
* **S5**: N5-1 (a public factor stripped), N5-2 (one degree short, at zero slack), N5-3 (the mask one degree short),
  N5-4 (C7 / C8), F-1 (one IR coefficient perturbed).

### The full zero-data preimage (`staging_v25/scripts/zk60_native_rg_d55preimage.py`, new)

**Where it came from.** The D12a run gate's stage 11 (`zk60_native_run_gate.stage11`, round 7), which calls
`zk60_native_rg_ahpreimage.full_preimages` and `zk60_native_rg_ahcontrols.ah_controls`. Both are imported UNCHANGED.

**What it does.** For each commitment it sets the hidden data to ZERO (a public object: a capture carries no witness
and none is read) and solves, exactly over F_p, for blinding values such that the commitment's whole published view
is reproduced. Then it recomputes the view from that solution, entry by entry, and compares:

* every opening group's vector, message half (n = 16,384) AND pad half (Q = 256): so A and H are solved at MSG != PAD;
* the proximity vector, both halves;
* every claim value;
* every row of every opened column.

The opened columns rebuilt from the solution are then re-hashed under the bundle's own hash rule and folded along their
PUBLISHED salts and Merkle paths: each must reach the committed root.

**What is new for D55.** The set of commitments: every fork's A and H (a fork commits no boundary), and every TAIL
commitment (both internal boundaries B0 and B1, committed in the head and opened once in the tail; and the two external
endpoints). Exactly the views part R13-6 ranks. On top of `full_preimages`' own verdict, the part checks that nothing
was skipped, that A and H really were solved at MSG != PAD, and that for every commitment the salted leaves
authenticated = columns re-hashed = its opened columns (256).

### The driver (`zk60_native_rg_d55.py`)

One delimited block, `# --- [NL-1 / PRE lane, 2026-11-02] begin` … `end`, after the `not_here` list is built. At an
R13 base it adds two parts:

* `NL-1 R13 slots, every fork`;
* `PRE full zero-data preimage`.

It removes their two entries from `not_here` once they have run. A false part makes the record NOT-OK; true parts
leave the status as the rest of the gate set it. Nothing else in the driver changed (`git diff 9432e88a -- …d55.py`
is the block only). The W16 family is unchanged: NL-1 there needs W16 slot ports that do not exist.

## 2. What each check proves, and what it does not

**NL-1 shows**, for the seven R13 slots of every fork, at that fork's real shape, calibration and gate denominator:
the slot polynomial has the structure the masked-sumcheck hiding argument (nl_check's model) needs. Every monomial
carries a public factor, the degrees fit, the masks are long enough, and a miniature masked run of the same polynomial
hides its terminals. Because T-0 / E-0 / F-0 hold, this is about the polynomial the fork actually proved, not a
transcription.

**NL-1 does not show:**

* S1–S5 on the 16 slots R13 does not redefine. They keep D33's argument of record, as in the accepted classifier
  statement. Here: their terminal identity is R13-3's (23 / 23 on every fork), and S3 plus the mask budget at their
  (rounds, degree) pairs are computed;
* anything at W16;
* anything outside nl_check's model.

**The preimage shows**, for every commitment of the run: a blinding EXISTS that, with all-zero hidden data, reproduces
every published field entry and every opened column's salted leaf. So the opened view alone cannot rule out
"all-zero data".

**The preimage does not show:**

* the LAW of the blinding (existence is not uniformity on the fibre);
* the masking commitment M's rows (that is part R13-7, mask / CFS);
* an UNOPENED Merkle leaf (hidden behind its salt, M-2 / M-3, argued);
* anything non-linear (that is NL-1).

## 3. The runs

**The bundles.** Round 26's four fresh bundles, read only:

* `/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/d55-r13_rung_h24-s0` and `-s1`;
* `d55-r13_8b_t128_h24-s0` and `-s1`.

They are CPU-made, `proved_on_gpu: false`, with 75 pins. Their manifests are in `../privacy_gate_r26/bundle_manifests/`.

**The tool state.** All four records name commit `fb22858a`'s tools in `tool_sha256`:

* `zk60_native_rg_d55.py` `14c451c2…`;
* `zk60_native_rg_d55nl.py` `e8d855b3…`;
* `zk60_native_rg_d55preimage.py` `dbbf3f1c…`;
* `zk60_native_rg_d55r13.py` `927cb408…` and `zk60_native_rg_d55joint.py` `3fc784d6…`, both unchanged.

The interpreter is the session's gate venv (Python 3.13.13, blake3 1.0.11).

**How they ran.** One detached chain (`chain.sh`, launched by `detach.py`, marker `logs/chain.done`):

* first `pygate_all.sh`: the four gate runs, one after another, each through `pygate.sh` (guarded cpu class, need 8 /
  cap 24 GiB, max 21,600 s), each bundle with its pair as `--other`;
* then `suite.sh`.

Guard lines are in `logs/chain.out`, each run's own output in `logs/<tag>.log`, and the records in `records/`.

**The first attempt.** It was launched with a 14,400 s wait for the heavy lock. The other lane (TS / census) held the
lock for that long, so the guard refused the run, exit 70 (`logs/py-r13-rung-s0.run.out`). The coordinator asked for
an 8 h wait. With it, the first run waited 9,353 s and then started; the others started at once.

| run | guard start → end (local PST) | wall | peak RSS |
|---|---|---|---|
| `py-r13-rung-s0` | 14:02:14 → 14:26:06 | 1,432 s | 1.58 GiB |
| `py-r13-rung-s1` | 14:26:06 → 14:50:01 | 1,435 s | 1.66 GiB |
| `py-r13-8b-s0` | 14:50:01 → 16:08:27 | 4,706 s | 5.51 GiB |
| `py-r13-8b-s1` | 16:08:27 → 17:25:33 | 4,626 s | 5.06 GiB |
| `suite_v25` | 17:25:33 → 17:32:08 | 395 s | 0.71 GiB |

**Where the time goes.**

* NL-1 is quick: 11 s (rung) and 88 s (8B).
* The preimage is the cost: 1,325 s (rung) and 4,160–4,241 s (8B).
* Inside the preimage, the six `ah_controls` take 536 s and 2,608–2,672 s, because each re-solves fork 1's A or H
  from scratch, as the D12a stage 11 does.

**Development runs before the record** (`dev/`, the two modules' standalone CLIs on rung s0, through `devrun.sh`):
NL-1 PASS in 25 s, and the preimage PASS in 1,385 s, with the same figures as the record.

## 4. Results

`summarize.py` prints every figure (`logs/summarize.out`).

**The status of each record.**

| record | status | parts true | pins: at r19b / read / UNREAD | backend |
|---|---|---|---|---|
| `py-r13-rung-s0` | **D55-PASS** | 14 / 14 | 75: 41 / 34 / 0 | CPU, admissible |
| `py-r13-rung-s1` | **D55-PASS** | 14 / 14 | 75: 41 / 34 / 0 | CPU, admissible |
| `py-r13-8b-s0` | **D55-PASS** | 14 / 14 | 75: 41 / 34 / 0 | CPU, admissible |
| `py-r13-8b-s1` | **D55-PASS** | 14 / 14 | 75: 41 / 34 / 0 | CPU, admissible |

The 14 parts are round 26's twelve plus `NL-1 R13 slots, every fork` and `PRE full zero-data preimage`. Each record's
`not_here` no longer lists NL-1 or the preimage. It still lists TS-1 and the claim census, the Python hash census,
G_k in the clear, and the independent check of the self-read readings.

**NL-1.** At both shapes:

* in all four challenge modes, F-0, S1 (premise, public factor, degree, budget) and S4 (miniature run, terminal map
  onto) hold on all 21 instances;
* S5 holds: N5-1 21 / 21, N5-3 and N5-4 fire, F-1 21 / 21.

| record | instances | G per fork | T-0 / E-0 / T-0 control | S3, the 7 slots | S3, all 23 slots | budget, all 23 (worst L) | N5-2 |
|---|---|---|---|---|---|---|---|
| rung s0 | 21 / 21 | 20 / 21 / 20 | 21 / 21 each | 25 / 25 at (15,3) (15,4) (15,5) (16,4) (16,5) | 55 / 55 | ok (82) | 15 / 15, 6 n/a |
| rung s1 | 21 / 21 | 20 / 21 / 20 | 21 / 21 each | 25 / 25, the same pairs | 55 / 55 | ok (82) | 15 / 15, 6 n/a |
| 8B s0 | 21 / 21 | 19 / 19 / 19 | 21 / 21 each | 25 / 25 at (15,3) (15,4) (18,4) (20,4) (22,5) | 55 / 55 | ok (112) | 18 / 18, 3 n/a |
| 8B s1 | 21 / 21 | 19 / 19 / 19 | 21 / 21 each | 25 / 25, the same pairs | 55 / 55 | ok (112) | 18 / 18, 3 n/a |

The rung's (rounds, degree) pairs are the rung captures' of round 22. The 8B pairs are five of the six real
Shieldstral pairs of round 23: all but (20,5). The gate denominators 19, 20 and 21 are all covered.

**The full zero-data preimage.** Every record: 10 / 10 commitments exhibited, 0 entries differing, every opened
column's salted leaf authenticated (256 per commitment, 2,560 per record), and A and H solved at n = 16,384 ≠ Q = 256.

| record | view entries compared | fork A (rows, groups, claims) | fork H (rows, groups, claims) | B0 / B1 rows | E-Input / E-Output rows |
|---|---|---|---|---|---|
| rung s0 | 3,045,032 | 437, 36, 148 | 248, 9, 55 | 7 | 6 |
| rung s1 | 3,045,110 | 437, 36, 148 | 248, 9, 55 | 7 | 6 |
| 8B s0 | 9,424,908 | 4,577, 36, 146 | 4,390, 9, 54 | 38 | 37 |
| 8B s1 | 9,428,999 | 4,577, 36, 146 | 4,390, 9, 54 | 38 | 37 |

The 8B fork shape (A 4,577 rows / 146 claims, H 4,390 / 54) is the real Shieldstral block's. The entry counts differ by
a few hundred between the two hidden inputs only because the number of DISTINCT sampled columns differs (253 to 256).

**The v25 staging suite** (`suite.sh`, `logs/suite_v25.log`): **158 tests: 86 ok, 71 skipped, 1 failure.**

* The baseline was 150 / 1 / 71; this lane adds 8 tests (`test_d55_nl_preimage.py`), and all 8 ran and passed. Its
  three bundle tests run NL-1 on every fork of rung s0, and the tail's preimage with the PRE-T controls.
* The one failure is the pre-existing `test_r19b_self_check_and_its_control`: it needs the r16b..r19b CLI binaries
  that stayed on the laptop. Round 26 records the same.
* The suite's guard exit 1 (`chain.suite.rc` = 1) is that failure's unittest exit status.
* Every round-26 test that ran before still passes.

## 5. Controls

Every control must fire, or its part is false. All of them work on in-memory copies; nothing on disk was written,
and no doctored bundle copy was needed (no `nlpre_*` directory).

**NL-1 (on fork 1, the interior fork, unless named):**

| control | perturbation | predicted |
|---|---|---|
| NL-T0 | one private terminal + 1, on EVERY slot instance | T-0 fails on that instance |
| NL-TAB-GC | a doctored table entry that passes the structure checks: SC_FZC's group column, one channel's group id + 1 on every token, digest recomputed | T-0 fails at slot 18 only (the arithmetic catches it) |
| NL-TAB-ACT | a doctored table entry the structure check catches: SC_TAB's ACT3 entry 100 + 1, digest recomputed | slot 19 refused, and only it |
| NL-G | the fork evaluated at G_k + 1 | T-0 fails at slot 18 only |
| N5-1, N5-2, N5-3, N5-4, F-1 | nl_check's own S5 (above) | each as nl_check predicts |

**The preimage:**

| control | perturbation | on | predicted |
|---|---|---|---|
| P-1 | one opened column entry + 1 | fork 1's H | no preimage: the pad half is not divisible by Z_S |
| P-2 | one group-vector entry + 1, message half | fork 1's A | no preimage: the claim values cannot be met |
| P-3 | one group-vector entry + 1, pad half | fork 1's H | no preimage: pad half not reachable |
| P-4 | one pad fewer than the distinct opened columns | fork 1's H | no preimage: interpolant degree too high |
| P-5 | a blinding row shared between A and H | fork 1's A, H | both preimages exist and force different values: no joint one |
| P-6 | a second fixed input off H's disclosed identity | fork 1's H | refused before projection, verified after |
| PRE-T1 | an opened column changed | the tail's B0 | no preimage |
| PRE-T2, PRE-A2 | a PAD/MSG swap: one group's first Q message entries and its Q pad entries exchanged | B0; fork 1's A | no preimage |
| PRE-T3, PRE-A3 | a salted leaf changed: one rebuilt column authenticates with its published salt and path, and NOT with one salt bit flipped, one path-node bit flipped, or one rebuilt entry + 1 | B0; fork 1's A | each of the three refused |

**The count.** Every applicable new control fires in all four records:

* NL-T0: 21 per record;
* N5-1 21, N5-2 15 (rung) or 18 (8B), N5-3 1, N5-4 1, F-1 21;
* the three NL D55 controls;
* P-1..P-6: six, all applicable (P-5 has its forced pair, P-6 its zero-sum identity);
* the five PRE controls.

That is **94 + 94 + 97 + 97 = 382 of 382 fire**. The 18 N5-2 rows not applicable are slots with degree slack 1:

* on the rung, SC_DZC and SC_FZC on each fork, 6 per record;
* at 8B, SC_FZC only on each fork (SC_DZC is at zero slack there, so N5-2 runs on it and fires), 3 per record.

**Each fired for the predicted reason:**

* NL-TAB-GC fails slot 18 only, by the arithmetic: no structure refusal;
* NL-TAB-ACT fails slot 19 only, refused by the ACT3 structure check;
* NL-G fails slot 18 only;
* P-1, P-3 and PRE-T1 are refused at the pad step: "not reachable from the opened columns";
* P-2, PRE-T2 and PRE-A2 are refused at the message step: "cannot be met inside the kernel";
* P-4 is refused as "d − 1 pad symbols cannot meet d distinct opened columns" (d = 255 on the rung, 256 at 8B);
* PRE-T3 and PRE-A3: the honest rebuilt column equals the published one and authenticates, and each of the three
  changes leaves 0 authenticated.

Counting the older parts' controls too, the four records hold 550 control verdicts: 532 fire, 18 do not apply, none
fails to fire.

## 6. What is still owed

Closed here, for the registered R13 D55 bundles: NL-1 S1–S5 on the R13 slots (every fork), and the full zero-data
preimage (A and H at MSG != PAD, both halves, every opened column, the salted leaves).

Still owed (from round 26 §7, unchanged by this work):

* T-0 and NL-1 on the seven W16 slots (no W16 slot port exists);
* TS-1 and the claim census on a D55 capture, and the Python hash census (the TS / CENSUS lane, a separate block of
  the same driver, merged by the coordinator);
* the TinyLlama T128 LOW and Shieldstral T128 / T256 registered bases (not captured here; Shieldstral's per-layer own
  calibration clauses are untested on real data — NL-1 applies each fork's own clauses, as R13-3 does);
* the four R13 DD bases (refused by name: SC_DD is not ported, so neither is its NL-1);
* the v25 freeze review: the independent check of round 26's three SELF-READ readings, and the review of this round's
  gate code (round 26's and this one's);
* G_k is still recovered on SC_FZC, not read from a bound line; NL-1 inherits that;
* S1–S5 on the 16 unchanged slots stay on D33's argument of record;
* no real trained weights are on this host.

**Findings: none.** NL-1 and the preimage passed on every real bundle. Two notes:

* **Cost.** An 8B record now takes about 78 min, up from round 26's 6 min, and peaks at 5.5 GiB. Most of it is the D12a
  `ah_controls`: 2,600 s of re-solving A and H. A merged-gate queue should plan for this, or pass `--no-controls` only
  for runs that are not records.
* **G_k's provenance.** NL-1 takes G_k from R13-3's recovery. A fork whose G_k is not recovered is not evaluated, and
  the part is then false (tested).

## 7. Files

**Commits** (worktree branch `worktree-agent-a19d9832207e830a4`, on `perf/zk-batch-optimizations` at `9432e88a`):

* `fb22858a`, the code: the two new modules, the driver block and the test file. The coordinator merged it on main as
  `d2ae2bc7`, next to the TS lane's block;
* the records commit that adds this directory.

**The files here:**

* Records: `records/d55-py-r13-{rung,8b}-s{0,1}.json` (the four D55 records).
* Development records: `dev/d55nl-rung-s0.json`, `dev/d55pre-rung-s0.json`.
* Logs: `logs/`, holding each run's log and guard marker, `chain.out`, `chain.*.rc`, `summarize.out`, `suite_v25.log`,
  and the refused first attempt `py-r13-rung-s0.run.out`.
* Scripts: `pygate.sh`, `pygate_all.sh`, `suite.sh`, `chain.sh`, `devrun.sh`, `detach.py`, `summarize.py`.
* Nothing was left out: every file is under 1 MiB, 4.3 MB in all.

**Code:**

* `ops/zkp-mvp/gate-tinyllama/staging_v25/scripts/zk60_native_rg_d55nl.py` (new);
* `zk60_native_rg_d55preimage.py` (new);
* `zk60_native_rg_d55.py` (the delimited block);
* `staging_v25/tests/test_d55_nl_preimage.py` (new, 8 tests).

**To repeat:** `python3 detach.py logs/chain bash chain.sh` (the four gate runs, then the suite).
