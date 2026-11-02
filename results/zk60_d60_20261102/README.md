# D60: the D55 "commit, fork, join" run profile, registered (2026-11-02)

Ruling D60 (`docs/zkmatrix-poc/ZK60_DECISIONS.md`): Victor approved registering the reviewed D55 profile
(review: sound as built; F1–F5 closed). Registered D12a runs are unchanged. This directory records the
registration: production code, registry entries, source scans, receipts verified in a fresh process, the
capture writer, and the A/B.

**Nothing here is a privacy statement.** Every receipt below is a TEST receipt on the public synthetic R13
loader fixture `r13-h24-wide` (layer 0, its other-gate twin, and its public sequence `seq_public`), not for
publication; the receipts live outside the repository under `/Users/victorrielly/zk60-artifacts/d60_20261102/`,
each directory marked `TEST_RECEIPTS_NOT_FOR_PUBLICATION.txt`.

Commits (worktree branch `worktree-agent-a13712d1ade4dcee1`): `83946995` (production code, registry, CLI,
scans, tests), `1a4f4b96` (merge of `perf/zk-batch-optimizations` at `914aabd7`, the privacy re-check),
`bbc70ce3` (the capture writer for registered fork runs), `a68b22b0` (W-11 count, runner), and the records
commit that adds this README and the logs.

## 1. What was registered

**Eligible bases (the coordinator's reading of D60, applied as given):** run profiles already registered under
D12a, R13 / R14 block runs. This tree registers no R14 run profile (R14 is reachable only through
`--experimental-r14` and its registration is still owed, N-r14-5), so the eligible set is the **twelve R13
blocks-only run profiles** of `run.rs::ACCURACY_RUN_PROFILES`.

**The twelve registered D55 run profiles** (`run.rs`: `RUN_PROFILE_D55_R13_*`, the table `D55_RUN_PROFILES`,
the lookup `d55_run_profile`). Each is `hashline-zk-mr1/` ‖ the 50-byte marker
`d55-commit-fork-join-run/registered-opt-in-d60/v1/` ‖ its base run profile without `hashline-zk-mr1/`:

| D55 run profile | base (D12a) run profile | constructor input |
|---|---|---:|
| `hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-tinyllama-1.1b-t128-low-stack-v01-run/1` | `…/private-run-tinyllama-1.1b-t128-low-stack-v01-run/1` | 129 B |
| `…/registered-opt-in-d60/v1/private-run-tinyllama-1.1b-t128-low-ddict-v01-run/1` | `…/private-run-tinyllama-1.1b-t128-low-ddict-v01-run/1` | 129 B |
| `…/registered-opt-in-d60/v1/private-run-llama-3-8b-t128-lh24-v1-statement/1` | `…/private-run-llama-3-8b-t128-lh24-v1-statement/1` | 125 B |
| `…/registered-opt-in-d60/v1/private-run-llama-3-8b-t128-lh24-dd-statement/1` | `…/private-run-llama-3-8b-t128-lh24-dd-statement/1` | 125 B |
| `…/registered-opt-in-d60/v1/private-run-shieldstral-3b-t128-lowh24-blocks-run/1` | `…/private-run-shieldstral-3b-t128-lowh24-blocks-run/1` | 129 B |
| `…/registered-opt-in-d60/v1/private-run-shieldstral-3b-t128-lowh24-ddict1-run/1` | `…/private-run-shieldstral-3b-t128-lowh24-ddict1-run/1` | 129 B |
| `…/registered-opt-in-d60/v1/private-run-shieldstral-3b-t256-lowh24-blocks-run/1` | `…/private-run-shieldstral-3b-t256-lowh24-blocks-run/1` | 129 B |
| `…/registered-opt-in-d60/v1/private-run-shieldstral-3b-t256-lowh24-ddict1-run/1` | `…/private-run-shieldstral-3b-t256-lowh24-ddict1-run/1` | 129 B |
| `…/registered-opt-in-d60/v1/private-run-rung-lo-t32-dev/1` | `…/private-run-rung-lo-t32-dev/1` | 107 B |
| `…/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1` | `…/private-run-rung-lh-t32-dev/1` | 107 B |
| `…/registered-opt-in-d60/v1/private-run-rung-ld-t32-dev/1` | `…/private-run-rung-ld-t32-dev/1` | 107 B |
| `…/registered-opt-in-d60/v1/private-run-rung-hh-t32-dev/1` | `…/private-run-rung-hh-t32-dev/1` | 107 B |

(`…` = `hashline-zk-mr1/d55-commit-fork-join-run` in the first column, `hashline-zk-mr1` in the second.)

**Domain and keys.** Each D55 string is its fork run's OWN transcript-constructor domain (`hashline-v1/` ‖ the
string, D55 review F3). Like every run profile it hashes under its base BLOCK shape's four keys (s24 H-4 (4),
now asserted for all twelve); the keys the D55 strings would derive are in s24's forward guard, pairwise distinct
from every live key. CS-7 (`registered_block_shape`) names none of the D55 strings, so a D12a run can never
carry one (tested for all twelve); `ForkRun::new` refuses any string CS-7 would admit, and checks that a
registered string is exactly the marker and its base. The fork run's parameter line ends
`/d55-commit-fork-join-registered-d60` (was `…-prototype-unregistered`) and its schedule digest's domain is
`hashline/private-run-fork-schedule/d55-registered-d60/1`. No other construction byte moved: the labels, absorb
order, frames and generator domains are the reviewed prototype's.

**Equal-length census.** s25's W-2 measures each registered profile at `L` = 1, 22 and 32
(`logs/chain/g_scans_print.log`). The constructor inputs sit 3 (rungs, 107 B vs `sc-round` 104 B), 5 (8B,
125 vs 120) and 7 (TinyLlama / Shieldstral, 129 vs 136) bytes from the nearest absorb. The only equal-length
pair of different kinds in a registered D55 table that its base's table does not already have is
`pb-fork-s0` / `pb-fork-s1` (66 B), the pair D55 review F3's closure already declared (separated by the label
bytes at offset 49): `logs/w2_registered_d55_pairs.txt`. **No new pair was declared for D60.** s33's J-7a
premise and lemma cover the twelve strings as registry literals (127 profiles, 5,302 layouts, thinnest 14
forced-NUL positions).

**Inventory of D12a-registered run profiles and what the fork prover supports:**

| kind | profiles | D55 |
|---|---|---|
| R13 blocks-only runs | 12 | **registered** (above) |
| pre-R13 blocks-only runs: 7 development rungs (rung-G, K4, P2, C6, W14, E32, M125) and 15 trained runs (TinyLlama / Llama-3-8B T32–T128, the DD runs, rung-TC / DD / HD, Shieldstral legacy T128 / T256 ± DD) | 22 | supported by the prover (the legacy stack runs through it: the rung-G false-statement tests), **not registered**; a test build reaches them through a test-only identity only |
| token-I/O runs | 5 | refused by the door (blocks-only runs only) |
| classifier runs | 3 | refused by the door |
| W16 / W16R2 (not D12a-registered; test-only run identities) | 5 | **not registered** (as instructed); test-only identities kept for the A/B and the privacy-gate captures |

## 2. Production code, and what stays test-only

`run.rs` / `wire.rs` declare `run_fork.rs` / `run_fork_wire.rs` without `#[cfg(test)]`. Production:
`ForkRun::new` (the door: `D55OptIn::registered_profile()`, refuses a base with no registered D55 profile by name),
`prove_run_with_forks`, `verify_run_with_forks`, `ForkRun::census` (W-2 at the constructor, run at every
construction; `hash_domain::path_labels` lost its `#[cfg(test)]` for it), the frames, and on disk
`write_fork_receipt` / `read_fork_receipt` (bounded reads against the verifier's own counted lengths; the
directory must hold exactly the `L + 2` frames `d55-head.bin`, `d55-fork-NNN.bin`, `d55-tail.bin` and at most the
`statement` directory) / `verify_run_with_forks_from_dir`. The CLI: `zk60_trained_block stack-prove
--d55-workers N` and `stack-verify --d55-workers N` (the statement names the D55 profile, its base and the
construction; `--controls` and `--lie-at-boundary` are D12a-only and refused with the flag).

Test builds only (`#[cfg(test)]`): the cheating prover (`ForkTamper`, `prove_run_with_forks_tampered`; production
reads every deviation as the honest prover's, as D12a reads CS-3's switch), the F2 mutation `DropForkIndex`, the
per-worker `ForkHooks`, every run-capture hook, `RepeatBlock`, `ForkRun::binding` / `capture_header` /
`new_test_identity`, and the TEST-ONLY identities (`D55_PROFILE_PREFIX` ‖ base, the prototype's strings byte for
byte) admitted only by `D55OptIn::unreviewed_prototype()` for a base with no registered profile.

D55 review Info items closed with registration: **F6** (the registered schedule text gives counts, and each fork
line says its IO claims are opened in phase 3) and **F7** (tests: a foreign fork frame from a second run, `L = 1`,
the receipt under another profile, and a D12a stage body re-wrapped as a fork, each refused by the chain).

## 3. Controls against the production verifier

All in `run_fork_tests.rs`, CPU and Metal (`logs/chain/g_d55_{cpu,metal}.log`):
- the four named controls (fork-index swap, stale fork state, root absorbed after a fork, claim raised but not
  joined; each with the cheater's tags and with forged honest tags) and the same-block swap with the drop-index
  mutation: under the **registered** profile of `R13_RUNG_H24`;
- the headline false statement, both variants, under the **registered** profile (`D60 HEADLINE`: fork 1 slot 22
  `IO-out`, fork 2 slot 21 `IO-in`);
- 13 native R13 byte-limb relation mutations on the interior fork, under the **registered** profile
  (`D60 TAMPER`, all 13 inside fork 1);
- D55 review F1's headline and all 27 D12a tamper families at rung-G (a pre-R13 base, so its test-only
  identity; the same production prover and verifier);
- F7 (above), the registry and door tests.

## 4. Receipts verified in a fresh process (TEST receipts, not for publication)

**(a) The production CLI**, the path every registered run profile's receipts took (`cli_receipts.sh`, logs
`logs/cli/c_*.log`; binary `zk60_trained_block` sha256 in `logs/cli/c_binary.sha256`). The fixture export has
one layer, so `L = 1`: one fork, no internal boundary, the join and both endpoint openings.

| step | process | result |
|---|---|---|
| `stack-prove --d55-workers 1` (the registered D55 profile of `R13_RUNG_H24`'s run profile; statement identity `6ac6d190…`) | 1 | exit 0: `d55-head.bin` 80 B, `d55-fork-000.bin` 14,465,864 B, `d55-tail.bin` 1,372,272 B |
| `stack-verify --d55-workers 1` on a verifier copy of the export (no `seq_*`) | 2 (fresh) | exit 0, **verified**; the verifier published `statement/` itself (`run_profile` = the D55 string, `base_run_profile` = the base; `logs/cli/c_d55_statement.json`, `c_d55_segments.json`) |
| `stack-verify` (the D12a verifier) on the D55 directory | 3 | exit 1, refused: the directory holds `d55-fork-000.bin`, not one of the run's segments |
| `stack-prove` (D12a) of the same base | 4 | exit 0 (one segment, 15,838,024 B) |
| `stack-verify --d55-workers 1` on the D12a directory | 5 | exit 1, refused: the directory holds `segment-000.bin`, not one of the fork run's 3 frames |
| `stack-verify` (D12a) on the D12a directory | 6 | exit 0, verified |

**(b) A three-block run, two test-binary processes** (`d60_fresh_process_write_test_receipts`, then
`d60_fresh_process_verify_test_receipts` in a new process; `logs/chain/g_fresh_{write,verify}.log`,
`g_fresh_manifest.txt`): process 1 proves the R13 rung (layer 0, its twin, layer 0) under the registered D55
profile on 3 workers (head 144 B, 3 forks of 14,465,864 B, tail 3,281,008 B; `L + 1` = 4 generators) and a D12a
receipt of the same base, and writes each with only its endpoint policy beside it. Process 2 rebuilds both
statements from the fixture and the policy files alone, and:
- the D55 receipt **verifies** from its directory (5 frames, 46,678,744 B);
- the D12a verifier refuses the D55 directory, and the D55 fork frames as segments (by the counted length);
- the D55 verifier refuses the D12a directory, and the D12a segments as forks (by the binding);
- the D12a receipt verifies under D12a.

The crossings the CLI refuses by directory layout or length are refused by the CHAIN in the in-memory F7 tests
(a foreign fork frame with its binding and start tag rewritten; the receipt under another D55 profile with every
binding and tag rewritten; a D12a stage body re-wrapped to a fork frame's length).

## 5. The capture writer

`run_capture::write_bundle` now writes a fork run's bundle when its profile is a REGISTERED D55 run profile
(`write_fork_bundle`: the layout of the privacy re-check's test-only writer, schema `SCHEMA_D55`, the frames under
`receipt/`, the manifest last, pins including `run_fork.rs` / `run_fork_wire.rs`, which `OWN_SOURCE_FILES` now
carries) and still refuses a test-only identity's. Test:
`d60_the_capture_writer_writes_a_registered_fork_run_bundle_and_refuses_a_test_only_one` (an R13-rung `L = 3`
bundle, 65.7 MB outside `receipt/`).

## 6. Gates

`d60_gates.sh` (detached through `run_d60.py`), one test binary (sha256 `c0c111e7…`, `logs/chain/binary.sha256`),
logs in `logs/chain/`. The chain ran start to finish twice: the first run stopped at the trained step on a wrong
check in the script (it expected the W16R2 rung GOLDEN `334e168f` from the trained test, whose rung recipe gives
`d6879fae`, the value the W16R2 chain recorded; the golden itself passed in the `w16r2-rung-metal` steps). That
check was fixed and the chain resumed at the trained step (`d60_gates.sh tail`, `logs/run_tail.out`) on the same
binary. Every step is green:

| step | result | log |
|---|---|---|
| build: gpu-metal test build + no-feature `cargo check --release --lib --tests` | ok; **133 warnings** (baseline 134, same count method) | `g_build.log` |
| scans: r19b, s24, s25, absorb, s33, hash_domain | **58 / 58**; every D55 census line present; the W-2 census measured the registered D55 profiles | `g_scans.log`, `g_scans_print.log` |
| zkp-core | 15 / 15 | `g_zkpcore.log` |
| D55 / D60 tests, CPU and Metal (`HL_GPU_REQUIRED=1`) | **18 passed, 3 ignored, both**; F1 27/27 inside fork 1; D60 13/13 inside fork 1; headline both variants; capture writer | `g_d55_cpu.log`, `g_d55_metal.log` |
| D55 capture through the Rust privacy gate (W16 rung, test-only identity, production verifier) | **W16-PG VERDICT 20 checks, all PASS** | `g_d55_capture.log` |
| fresh-process test receipts (two processes) | write ok, verify ok, 4 crossings refused | `g_fresh_*.log` |
| CLI receipts | 6 / 6 steps with the expected exits | `g_cli.log`, `logs/cli/` |
| D12a R13 two-stage run | ok | `g_d12a_run.log` |
| dev bytes, both batch-tail modes | **01fa1b2e / 992034f8 / 371e6b00 / 3ab090df** | `g_bytes_{default,0}.log` |
| W16R2 rung golden, CPU = Metal, both modes | **334e168f** | `g_r2rung_{default,0}.log` |
| unit sets, both modes | 116 / 116 (12 ignored) | `g_unit_{default,0}.log` |
| trained digests (CPU = Metal at every pass) | R13 **2b0d04bb / 678953f6**, W16 **01a6d51d / c5e0bdac**, W16R2 8B **5343008a**, Shieldstral **e0bb5917**, rung (trained recipe) d6879fae | `g_trained.log` |
| r13 run test (`r16_an_r13_classifier_run_with_two_gate_denominators…`) | ok | `g_r13.log` |
| a W16R2 rung run through D12a and the D55 fork verifier (test-only identity) | both verified | `g_r2run.log` |
| golden | **8 / 8** (`ALL 0`) | `golden/golden.done` |
| full lib suite | **882 passed, 6 failed, 88 ignored**; the 6 are exactly the known Mac-only ones | `g_full.log` |

## 7. A/B on one request: the registered base serial against its registered D55 profile at N = 6

**[MEASURED]** `logs/ab/ab.log` (`d60_ab.sh`; test `d55_ab_one_request_serial_against_forks`, now able to take an
R13 base). The conditions:
- `R13_8B_T128_H24`, its D12a run profile against its REGISTERED D55 profile
  (`…/registered-opt-in-d60/v1/private-run-llama-3-8b-t128-lh24-v1-statement/1`, the log's last line says
  `registered: true`);
- a 32-block Llama-3-8B T128 run at the true geometry, ONE synthetic diagonal-weight block at every layer (M10's
  recipe, as D55's A/B), every witness built before the timed call;
- one process, one binary (the gate chain's test binary, sha256 `c0c111e7…`, `logs/chain/binary.sha256`),
  `HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0`, `HL_METAL_TIMING` unset;
- one cold serial pass, then 4 warm passes in BOTH ORDERS (serial first in passes 0 and 2, forks first in 1 and
  3); the first warm pass of each arm verified (D12a verifier 5.04 s on one thread, D55 verifier 2.60 s on 6);
- guarded (gpu class), alone among guarded jobs. The Mac is shared (frugal-lm training may be live), so these are
  not quiesced-box numbers.

Proved tokens/s per request = 128 / wall.

| arm | serial first (best / mean) | forks first (best / mean) | all 4 (best / mean) |
|---|---:|---:|---:|
| D12a serial | 16.874 s = **7.59** / 7.54 | 16.946 s = 7.55 / 7.55 | 16.874 s = **7.59** / 7.54 tok/s |
| D55, N = 6 | 10.854 s = 11.79 / 11.54 | 10.708 s = 11.95 / 11.93 | 10.708 s = **11.95** / 11.73 tok/s |
| ratio | 1.55x | 1.58x | **1.58x** (best), 1.56x (mean) |

D55 phases at N = 6: preflight about 0.35 s, commit 0.30–0.32 s (31 boundaries), forks 9.9–10.5 s, join and
openings 0.09–0.15 s; each fork's `prove_core` median 1.78–1.87 s under 6-way sharing. Receipts: D12a
1,038,856,416 B, D55 1,038,856,608 B (+192 B). An earlier run of the same harness on the previous build
(same production code; `logs/ab/ab.log`, first half) gave 7.72 against 12.40 tok/s best (1.61x).

For comparison, D55's own A/B on the (unregistered) W16 8B T128 base gave 10.57 → 20.85 tok/s (1.97x). Why
the R13 base gains less at N = 6 was not measured here (no per-phase device profile was taken). Both are
synthetic-weight runs, not dense-weight measurements.

## 8. Open, and what needs a ruling

1. **Privacy before real content (D60's own condition).** The Python D55 replay gate
   (`staging_v25/scripts/zk60_native_rg_d55.py`, D55-DEV-PASS on the W16 / W16R2 rung fork runs) requires a
   W16-family block profile and a TEST-ONLY W16 run identity. A registered R13 D55 bundle can now be written by
   the production capture writer (section 5), but no Python gate has read one. Either the gate is extended to the
   R13 layout and run on such a bundle, or a ruling says the W16-rung runs count for the R13 profiles.
2. **Which bases (a product ruling, taken here as the coordinator wrote it).** Registered over the twelve R13
   blocks-only runs only. The 22 pre-R13 blocks-only D12a profiles (development rungs, trained TinyLlama /
   Llama-3-8B / Shieldstral legacy-stack runs) are supported by the prover and NOT registered; registering them
   needs a ruling. Token-I/O and classifier runs are refused by the fork prover. W16 / W16R2: not registered.
3. **The carried-over declared pair.** `pb-fork-s0` / `pb-fork-s1` (66 B absorbs, separated by the label bytes at
   offset 49) is declared in s25's W-2 since D55 review F3, and every registered D55 table has it. It is not a
   J-7a (constructor-against-absorb) separation; it is the same kind as the existing 81-byte one-byte-label row.
   No new pair was declared. Renaming one label would remove it (D55 receipt bytes only) if wanted.
4. **Prototype limits kept.** The verifier and `read_fork_receipt` hold the whole receipt (no M-3 streaming:
   about 1.04 GB at 8B `L = 32`), and the prover holds every frame. Fine on the 256 GB Mac, not on an 8 GB host.
5. **The CLI.** `stack-verify --controls` (D12a's run-level controls) is refused with `--d55-workers`; the D55
   controls exist as tests only. The fixture export has one layer, so the CLI receipts are `L = 1`; the
   three-block receipts are the test-binary pair.
6. **Two production-adjacent edits outside the fork files**, both mechanical: `hash_domain::path_labels` lost its
   `#[cfg(test)]` (the census runs in production), and `run_capture::OWN_SOURCE_FILES` pins `run_fork.rs` and
   `run_fork_wire.rs` (future bundles' manifests list two more pins; the W16 test writer no longer adds them a
   second time).
7. The decisions register and `MVP_STATUS.md` were not edited (the coordinator's).
