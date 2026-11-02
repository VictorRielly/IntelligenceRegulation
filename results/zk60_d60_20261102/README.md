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

`run_capture::write_bundle` (the run capture's own writer, test builds only, as for D12a: `run_capture` is
`#[cfg(test)]` as a whole) now writes a fork run's bundle when its profile is a REGISTERED D55 run profile
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
   the run capture's own writer (test builds), as for D12a (section 5), but no Python gate has read one. Either the gate is extended to the
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

## 9. Closing the independent review's findings (2026-11-02)

The review (`REVIEW_D60_20261102.md`) found D60 sound with findings F1–F9. This section records how each was
closed. Code commit `ed519548` on the worktree branch `worktree-agent-a2e328baa581cb5b0`, then the merge of
`perf/zk-batch-optimizations` at `05490b79` (the D60 privacy-gate work) and the records commit. Gate chain
`logs/close/d60_close_gates.sh` (copied from the W16R2 closure chain), logs in `logs/close/chain/`. The CLI
closure is `logs/close/cli_close.sh` (logs in `logs/close/cli/`), and the mutation check is
`logs/close/mutant_check.sh` (logs in `logs/close/mutant/`).

**No verified receipt or statement byte moved, for D12a or D55.** The frames, transcripts, `statement.json`
and `segments.json` renderings are unchanged. Dev bytes and trained digests are unchanged (§9.11). The release
CLI built from the merged tree has the same SHA-256 as the one built before the merge, `594292c6…`. The merge
and the `run.json` text below change test-only code.

### 9.1 F3 (Medium): the CLI fails closed for D55 until the real-content privacy gate passes

**The production constant.** `run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED: bool = false`.
- Its doc comment names D60 and this review's F3.
- It names what the flip waits for: the Python D55 replay gate and the Rust gate's PG-7 allow-list and fork
  checks PASSING on a bundle `run_capture::write_bundle` writes for a REGISTERED R13 D55 profile, with that
  verdict recorded in the D60 entry.
- Only a coordinator commit flips it. The privacy-gate merge records D55-**DEV**-PASS, with 23 source pins
  unread, so this commit leaves it `false`, as the coordinator directed.
- Flipping it moves no byte: it only lifts the refusal.

**`stack-prove --d55-workers N`** is refused unless the operator passes the explicit acknowledgement
`--d55-test-receipt-not-for-publication`.
- The refusal names D60 review F3 and the flag.
- It comes after the flags are parsed, before the export is read and before anything is created.
- The flag without `--d55-workers` is refused too.
- D12a runs are never affected.
- The rule is `trained_block::d55_prove_admission(workers, acknowledged, gate_passed)`. It is tested in both
  arms of the constant.

**With the flag, the marker.** The prover writes `D55_TEST_RECEIPT_NOT_FOR_PUBLICATION.txt` (fixed text,
`run_fork::D55_TEST_RECEIPT_MARKER_TEXT`) into the run directory.
- It is written after the frames, atomically (temporary name, flush, rename, never over an existing entry).
- It is written before any verification or statement. A run that fails later is removed with it.
- The `d55` and `d55-test-receipt` stdout events say so.

**`stack-verify --d55-workers N`** prints a `d55-publication` event on every verification.
- The event carries `not_for_publication`, `test_receipt_marker` (`present` or `ABSENT`) and
  `real_content_privacy_gate_passed`.
- While the constant is `false`, `not_for_publication` is `true` whether or not the marker is there.
- The verifier stays usable: an unmarked D55 receipt still verifies, and is reported ABSENT.

**Why a file in the run directory.** It is the one place that changes no verified byte and still travels
with the receipt.
- The frames are transcript-bound receipt bytes, so a marker there would be a new profile.
- `segments.json` is, by rule r5_A, the hashes of exactly the bytes verified.
- `statement.json` is compared byte for byte by `stack-verify`. A marker there would move D55 statement bytes,
  and it would break the statements of receipts already published.
- The run directory is the unit an operator copies and hands to a verifier.
- `read_fork_receipt` admits exactly one extra entry under the marker's name, and only as a regular file
  holding exactly the marker text. A link, a FIFO, a directory or other content under that name is refused
  before any frame is read.
- It is an operational marker, not a cryptographic binding: whoever can write the directory can delete it.
  That is why the verifier reports `not_for_publication` from the build constant as well as from the marker.
- The published `statement/` directory does not carry the marker. Its file set is D12a's checked list, which
  this commit does not change.

**Tests.**
- `run_fork_tests::d60_f3_the_cli_fails_closed_for_a_d55_run_until_the_privacy_gate_passes` (CPU and Metal):
  - the admission rule;
  - refusal without the flag, with nothing created;
  - acceptance with it: the directory holds the three frames and the marker only, and `segments.json` and
    `statement.json` name no marker;
  - `stack-verify` verifies, publishes and reports `present`;
  - a copy without the marker checks against the same published statement and is reported `ABSENT`;
  - other content, a symlink or a directory under the marker's name is refused;
  - `--verify-in-process` reads the marked directory.
- On the release CLI (`cli_close.sh` steps 1–3): `stack-prove --d55-workers 3` without the flag exits 1 and
  creates nothing; with it, exit 0, five frames and the marker; `stack-verify` reports the marker `present`.

### 9.2 F1 (Low): negative controls for the D55 verifier's own preflight

`run_fork_tests::d60_f1_the_fork_verifier_refuses_blocks_that_are_not_the_statements` runs at the R13 rung with
L = 3 and an HONEST receipt. Each case is refused by its ruling with no `D55 wire:` text, through
`verify_run_with_forks` and through `verify_run_with_forks_from_dir`. The from-directory call is made on the
honest directory and on a directory that does not exist, and both refusals are equal to the in-memory one, so the
refusal comes before the directory is listed.

| case | refusal |
|---|---|
| (a1) blocks 0 and 1 swapped | block 0: "R13 public folded gate denominator differs from the stage shape". The R13 stage shape carries each block's gate shift, so the swap is caught by the stage-shape check (CS-1's) before the digest loop. |
| (a2) block 1 with one public weight changed (same stage shape, another digest) | "ruling CS-6 — block 1 handed to the run is not the block the run statement names". The preflight with its digest loop off ADMITS this list, so the digest loop is what this case pins. |
| (b) two blocks for a three-block statement | "ruling CS-6 — the run statement names 3 blocks and 2 public statements were handed" |
| (c1) block 0 at stage 1 | block 1: "gate denominator differs from the stage shape" |
| (c2) block 1 with a feed-forward word outside its support | block 1: "ruling CS-1 — the feed-forward statement does not fit the shape it is proved at" |
| (d) two fork frames | "D55: 2 fork frames were offered, this run has 3". On disk, a directory missing fork 2: "is missing d55-fork-002.bin", before any frame is read. |

The honest prover refuses (a1), (a2) and (c2) by the same rulings.

### 9.3 F2 (Low): the release binary beyond L = 1 / N = 1, and a cross-binary check

**The multi-layer export.** No multi-layer R13 export is on this Mac.
- The test-binary tool `run_fork_tests::d60_close_write_r13_multi_layer_test_export` writes one from the public
  synthetic fixture `r13-h24-wide`, following the fixture's own recipe.
- Every layer is its layer 0: the arrays are copied, and the manifest carries `"layer": k`, re-hashed.
- The variant is `r13-h24-wide-x<L>-d60`.
- `seq_public` is chained by the native witness builder. CS-3's lookup-miss check is applied too, which is what
  `stack-prove`'s sealing pass checks.
- The repeated layer's residual stream grows until layer 11, where the builder refuses ("fixed oracle range
  refusal: norm quotient/remainder"). So the longest such export is L = 11, used for F5.
- The other-gate twin of the in-memory tests cannot be written as an export without a new manifest member.

**The release CLI** (`zk60_trained_block`, sha256 `594292c6…`), test receipts under
`/Users/victorrielly/zk60-artifacts/d60_20261102/close/`:

| step | result |
|---|---|
| `stack-prove --d55-workers 3` at L = 3, with the flag | exit 0: head 144 B, 3 forks of 14,465,864 B, tail 3,281,008 B, the marker |
| `stack-verify --d55-workers 3`, fresh process, verifier copy of the export | exit 0, statement published, marker reported |
| `stack-verify --d55-workers 1 / 2 / 64` on the published run | exit 0 each, statement checked |
| D12a `stack-prove` / `stack-verify` at L = 3 | exit 0 / 0. The D12a verifier refuses the D55 directory; the D55 verifier refuses the D12a directory. |
| probes on copies of the L = 3 run, N = 3 | all refused, none hung (table below) |
| one probe under N = 1 and N = 3 | the same refusal text |

| probe | refusal |
|---|---|
| a byte in fork 1's body | `D55: fork 1: A: pcs zk: group 26: <v, c> != combined claim` (the chain) |
| fork 1's start tag | `fork frame 1's start tag is not the verifier's own fork-1 position` (the reader, F7) |
| fork 2's end tag | `fork 2's end tag is not the verifier's own fork-2 position` |
| boundary root 0 in the head; the head's S0 tag | `the head's S0 tag is not the verifier's own S0` (the reader, F7) |
| a byte in the tail's B_0 opening | `D55: boundary 0: pcs zk: group 0: <v, c> != combined claim` (the chain) |
| the tail's S1 tag | `the tail's S1 tag is not the verifier's own joined transcript position` |
| forks 0 and 2 swapped (the SAME block: every layer is one block) | `frame 0 is not the 3-block run's fork 0` (the index) |
| forks 0 and 1 swapped | `frame 0 is not the 3-block run's fork 0` |
| fork 1 a FIFO; fork 1 a symlink | `not a regular file`, before it is opened |
| an extra file; a marker of other content | refused by name before any frame is read |
| the marker removed | verifies, reported `ABSENT` |

**The cross-binary check, both ways.**
- (A) A copy of the release CLI's L = 3 run, taken before any verification, was verified and promoted by the
  TEST binary. The test-binary tool `d60_close_cli_in_the_test_binary` runs the production CLI functions with
  the `cfg(test)` arms compiled in. It published `statement.json` and `segments.json` byte-identical to those
  the release CLI published for the same run.
- (B) The test binary proved an L = 3 receipt, and the release CLI verified and published it.

There is still no D55 golden, since receipts are OS-random. The cross-binary verdicts are the pin that the two
builds' transcript programs agree.

### 9.4 F4 (Low): no-follow / no-block opens on macOS and aarch64 Linux, every reader

**The flag table.** One table, `run::NOFOLLOW_NONBLOCK` (`O_NOFOLLOW | O_NONBLOCK`):

| target | value |
|---|---|
| x86-64 Linux | `0o400000 | 0o4000`, as before |
| aarch64 Linux | `0o100000 | 0o4000` (`0o400000` is `O_LARGEFILE` there) |
| macOS, any architecture | `0x0100 | 0x0004` |
| anything else | `None` (the `fstat` re-check alone, as before) |

**The readers.** One open, `run::open_nofollow_nonblock`, is used by every reader that shares the pattern:
- the D55 frame reader (`read_frame_bounded`);
- D12a's two readers (`read_segment_bounded`, `read_regular_file_bounded`);
- the token-table readers (`tied_tables::regular`, `token_io::load::read_exact_streamed`), which had the same
  x86-64-only flags;
- the batch request reader (`token_io::classify_batch::read_request`). It refused every request off x86-64
  Linux, so `prove-batch` was refused on this Mac. It now uses the same table.

`stable_weight_registration.rs` opens with `File::open` after an `lstat`. Its comment declares a trusted
directory and no adversarial boundary, it is outside the D55 / D12a path, and it was not changed.

**The swap test.** `run_fork_tests::d60_f4_a_fifo_or_symlink_swapped_in_after_the_check_is_refused_without_hanging`
(CPU and Metal) covers each of the four reader kinds.
- A file of the counted length passes the `lstat` checks.
- A test-only hook (`run::before_open_hook_for_tests`) then swaps in, between the check and the open, either a
  FIFO with no writer or a symlink to a regular file of the same length.
- The FIFO is refused by the `fstat` re-check ("changed after its check"). The symlink is refused at the open
  (`ELOOP`).
- Each reader runs on its own thread, and a hang is a timeout failure.

**The mutation check** (`logs/close/mutant/`). A temporary build with macOS's value set to `None` (the pre-F4
state):
- the FIFO case fails at the timeout ("THE READER HUNG");
- the symlink case fails because the symlinked file was READ;
- the harness itself did not hang.

### 9.5 F5 (Low): memory of D55 CLI proves and verifies

Peak memory was measured under the guard, with the child's exact `maximum resident set size` from
`/usr/bin/time -l` beside the guard's sampled `peak_rss`. It is on the release CLI, CPU path, at the rung (the
largest L here is 11, see 9.3). `logs/close/cli/c_mem_summary.txt`:

| run (release CLI, R13 rung, CPU) | receipt | max RSS (`time -l`) | guard peak | wall |
|---|---:|---:|---:|---:|
| D55 `stack-prove`, L = 3, N = 3 | 46,678,744 B | **1,560 MiB** | 1.51 GiB | 1.8 s |
| D55 `stack-verify`, L = 3, N = 3 | | **279 MiB** | (missed, 0.4 s) | 0.4 s |
| D55 `stack-verify`, L = 3, N = 1 | | **183 MiB** | 0.18 GiB | 0.5 s |
| D12a `stack-prove`, L = 3 | 46,678,552 B | 708 MiB | 0.69 GiB | 3.2 s |
| D12a `stack-verify`, L = 3 | | 161 MiB | 0.15 GiB | 0.6 s |
| D55 `stack-prove`, **L = 11, N = 6** | 170,040,856 B | **3,386 MiB** | 3.31 GiB | 5.5 s |
| D55 `stack-verify`, **L = 11, N = 6** | | **605 MiB** | 0.57 GiB | 1.2 s |
| D55 `stack-verify`, **L = 11, N = 1** | | **339 MiB** | 0.33 GiB | 2.0 s |
| D12a `stack-prove`, L = 11 | 170,040,664 B | 862 MiB | 0.83 GiB | 11.5 s |
| D12a `stack-verify`, L = 11 | | 193 MiB | 0.19 GiB | 2.1 s |

**One public block's resident bytes** (the test-binary probe `d60_close_f5_resident_bytes_of_one_public_block`,
the A/B's synthetic block at the true padded geometry):

| profile | padded weight words | tables | accuracy data | one block | × 22 / 26 / 32 |
|---|---:|---:|---:|---:|---:|
| R13 rung h24 (T32, d_pad 512, f_pad 1024) | 3,146,752 B | 18,944 B | 39,674 B | 3,205,370 B (3.1 MiB) | 0.07 / 0.08 / 0.10 GiB |
| R13 Llama-3-8B T128 h24 (d_pad 4096, f_pad 16384) | 243,277,824 B | 133,632 B | 225,530 B | 243,636,986 B (0.227 GiB) | 4.99 / 5.90 / **7.26 GiB** |

- **At the rung**, the blocks are noise. Eleven blocks are 35 MB. Peak memory is dominated by other things:
  - the receipt, which the D55 verifier holds whole (about 15.5 MB per block);
  - the per-worker verifier state: N = 6 against N = 1 costs 266 MiB more at L = 11;
  - on the prover, N concurrent `prove_core` states: 3.4 GiB at N = 6 against D12a's serial 0.86 GiB.
- **At 8B, the cost the review flagged.** `load_fork_blocks` holds L of the 8B blocks above on every D55 CLI
  path, where D12a's `BlockCache` holds one: **7.26 GiB of public blocks at L = 32**, on top of about 1.04 GB of
  receipt and the N verifier states. This is a [MODEL] from the measured per-block bytes and the measured rung
  slopes, not an 8B CLI measurement: no 8B export is on this Mac.
- **Not redesigned.** The fix the review names, an on-demand block source holding at most N blocks, changes the
  `ForkBlocks` trait: it hands out `&BlockPublic` borrowed from the source, shared across worker threads. That
  is not small. It is reported, not made.
- **The external-tester `--need-gib` guidance**: at 8B, L × (one 8B block) + about 1.04 GB of receipt + N
  verifier states.

### 9.6 F6 (Info): the scope text and the README wording

- **Not changed: the `scope` text.** The published D55 `statement.json` carries `scope`, D12a's "ONE bound run
  … (one transcript, hidden internal boundaries)".
  - It is part of the statement bytes `stack-verify` compares byte for byte with its own rendering.
  - The D60 test receipts' published statements carry it.
  - So it is a verified statement byte, and per this task's rules it was not changed.
  - A D55 scope of its own would move D55 statement bytes only (D12a's would be unchanged). That needs the
    coordinator's go-ahead.
  - The D55 statement does name `run_construction` (commit, fork, join) and the D55 profile beside the scope.
- **Fixed: the README wording** (§5 and §8.1): "the run capture's own writer (test builds), as for D12a".
- **Fixed: the capture's `run.json`** (the coordinator's addition).
  - A REGISTERED D55 run's `transcript_program[0]` now reads "D55 REGISTERED OPT-IN RUN PROFILE (ruling D60;
    production prover and verifier) …".
  - Its `parameters` label text now says the line ends `/d55-commit-fork-join-registered-d60`.
  - A test-only identity's bundle keeps the prototype's wording.
  - This is descriptive text only, in the test-only `run_capture` (no transcript or verified byte).
  - It is asserted in `d60_the_capture_writer_…`.
  - The Python D55 gate does not pin it: `transcript_labels` is read for its labels only, and
    `transcript_program` not at all. The gate passes on bundles this build writes (9.11).

### 9.7 F7 (Info, optional): headers checked before the next frame is read

`read_fork_receipt` checks each header against the verifier's own values before it reads the next frame:
- the head's magic, binding, L and S0 tag (every root absorbed);
- each fork frame's magic, binding, L, k and start tag;
- the tail's magic, binding and L.

Its S1 tag needs every fork verified. The checks are the wire's own, factored into `fork_header` /
`tail_header` and shared with `decode_fork` / `decode_tail`, so the refusal texts are the same. The verifier
still makes every check again.

`run_fork_tests::d60_f7_the_on_disk_reader_checks_each_header_before_it_reads_the_next_frame` (CPU and Metal)
puts a wrong header in frame j with a FIFO standing in for a later frame. Each is refused at that header, and the
FIFO is never reached.

### 9.8 F8 (Info): panics in fork workers

- **(a) Release builds.** A release build has `panic = "abort"` (`Cargo.toml:63`), so there a panic in any fork
  worker ends the process. "A thread panic becomes a rejection" holds in test builds only. Both fail closed.
- **(b) Test builds: a panic is now that fork's error.** In the prover's worker it is caught (`catch_unwind`),
  and the worker goes on taking jobs. The feeder can no longer block on a rendezvous no live worker will take.
  In a release build the `catch_unwind` changes nothing.
- **The test.** `run_fork_tests::d60_f8_a_prover_whose_every_worker_panics_fails_and_does_not_hang` runs L = 3
  on two workers, every fork panicking through a test-only switch carried into the workers. It returns `D55:
  fork 0: its worker panicked: …`.
- **The mutation check.** Without the `catch_unwind`, the test fails at its 120 s timeout ("THE FORK PROVER
  HUNG"), and the harness does not hang.

### 9.9 F9 (Info): each R13 base's D55 bound

D55 review §3 (the interactive / union-bound reading of D15 and D27): a D55 run's error terms are D12a's, block
for block (Σ_k ε_k + Σ_{L+1} ε_open). The join adds hash inputs, not rounds. So **each registered D55 profile's
bound is its base's D12a figure**. The base figures are the R13 D24 review's counted lookup terms
(`results/zk60_d24_review_20261017/REVIEW_R13.md` §6, recorded in ZK60_DECISIONS.md under "Native R13 frozen"),
at the checkpoint's full block count:

| registered D55 profile over the base | D55 bound = the base's D12a figure (bits, whole run) |
|---|---|
| `…/private-run-tinyllama-1.1b-t128-low-stack-v01-run/1` | 98.40 (22 blocks) |
| `…/private-run-tinyllama-1.1b-t128-low-ddict-v01-run/1` | 98.50 (22 blocks) |
| `…/private-run-llama-3-8b-t128-lh24-v1-statement/1` | 97.00 (32 blocks) |
| `…/private-run-llama-3-8b-t128-lh24-dd-statement/1` | 97.06 (32 blocks) |
| `…/private-run-shieldstral-3b-t128-lowh24-blocks-run/1` | 97.30 (26 blocks) |
| `…/private-run-shieldstral-3b-t128-lowh24-ddict1-run/1` | 97.36 (26 blocks) |
| `…/private-run-shieldstral-3b-t256-lowh24-blocks-run/1` | 96.09 (26 blocks) |
| `…/private-run-shieldstral-3b-t256-lowh24-ddict1-run/1` | 96.26 (26 blocks) |
| `…/private-run-rung-lo-t32-dev/1`, `-lh-`, `-ld-`, `-hh-` (development rungs) | 107.0 per block, so 107.0 − log2(L) for an L-block run |

- **Each is structural** (D55 review §3).
- **The figures' scope is REVIEW_R13 §6's.** They are the lookup term (N + 4·T_d − 1)/p² as a union over the
  blocks. That review states the PCS and sumcheck terms are not included. The D55 review's §9 counted the
  openings too, at W16 8B T128 only. No R13 recount including the openings exists in the accounting, and none
  was made here.
- **The proof-work caveat applies** (D55 review §3). Mix-and-match makes a cheater's retries of the opening term
  cheap: c^L distinct S1 values for c·L fork proofs. No project figure counts attempts in proofs, so no figure
  moves. A future proof-work-stated tier would have to count it.
- **The W16R2-F2 cheap-retry concern does not bite at R13.** Its openings are at rate 1/4, where the best known
  attack is about 2^-172 per opening.

### 9.10 Commits

- `ed519548`: code (F1, F3, F4, F7, F8 and their tests; the F2 and F5 tools; the `run.json` text).
- `8685c4b9`: the merge of `perf/zk-batch-optimizations` at `05490b79` (no conflict).
- `c6162749`: the capture-writer test asserts the registered `run.json` wording.
- the records commit: this section, `logs/close/`, and the F5 / F9 / F6 records.

The gate chain ran on the tree of `c6162749`.

### 9.11 Gates (merged tree; `logs/close/chain/`)

One complete run of `d60_close_gates.sh`, exit 0. Test binary sha256 `b6fc2fd7…` (`chain/binary.sha256`),
release CLI `594292c6…` (`chain/cli_binary.sha256`).

There was an earlier run, `chain/prior-20261102T041030/`. It stopped after the CPU D55 step because of a wrong
count in the script, not in the tests: an anchored `grep '^D60 F4'` missed each test's first printed line, which
follows the `test … …` name on the same line. The script was fixed and the chain re-run start to finish on the
same binary. The development runs are in `logs/close/dev/`, and in `cli_dev.out` with its logs in
`cli/prior-20261102T041530/`.

| step | result | log |
|---|---|---|
| gpu-metal test build + no-feature `cargo check --release --lib --tests` | ok; **133 warnings** (the D60 chain's count method; the limit is ≤ 133) | `g_build.log` |
| scans: r19b, s24, s25, absorb, s33, hash_domain | **58 / 58**; every named scan and every D55 census line present | `g_scans.log`, `g_scans_print.log` |
| D55 / D60 tests, CPU and Metal (`HL_GPU_REQUIRED=1`) | **23 passed, 7 ignored, both**. These are the 18 before plus F1, F3, F4, F7 and F8; the ignored are the fresh-process pair, the A/B, the two F2 tools, the F5 probe and the merged privacy-gate writer. Each closure test's printed lines are checked: F1 10 refusals, F4 8 swaps, F7 5 headers, F3's `present` / `ABSENT` events, F8. The D55 F1 27/27 and D60 13/13 tamper lines, both headline variants and the capture line are present. | `g_d55_cpu.log`, `g_d55_metal.log` |
| D55 capture through the Rust privacy gate (W16 rung, test-only identity) | **W16-PG VERDICT 20 checks, all PASS** | `g_d55_capture.log` |
| fresh-process test receipts (two test-binary processes) | write ok, verify ok, the four crossings refused | `g_fresh_*.log` |
| the CLI closure (`cli_close.sh`, release CLI + test binary) | every step as expected (9.1, 9.3, 9.5) | `g_cli.log`, `logs/close/cli/` |
| the Python D55 gate (merged `staging_v25`, read-only) on two REGISTERED R13-rung bundles written by this build | **D55-DEV-PASS** on s0 and s1 (each with its pair). The bundles' Rust checks give `D60-PG-RUST VERDICT 2 bundles, every check PASS and every control fired`. `test_d55_r13_gate.py` gives **8 / 8 OK**, none skipped. | `g_pg_write.log`, `g_pg_py_s{0,1}.log`, `g_pg_unittest.log` |
| D12a R13 two-stage run | ok | `g_d12a_run.log` |
| dev bytes, both batch-tail modes | **01fa1b2e / 992034f8 / 371e6b00 / 3ab090df** | `g_bytes_{default,0}.log` |
| W16R2 rung golden, CPU = Metal, both modes | **334e168f** | `g_r2rung_{default,0}.log` |
| trained digests, CPU = Metal at the cold and all 3 warm passes | R13 Shieldstral **2b0d04bb**, R13 8B **678953f6**, W16 **01a6d51d / c5e0bdac**, W16R2 8B **5343008a**, W16R2 Shieldstral **e0bb5917**, W16R2 rung (trained recipe) **d6879fae** | `g_trained.log` |
| r13 run test; a W16R2 rung run through D12a and the D55 fork verifier | ok; both verified | `g_r13.log`, `g_r2run.log` |
| golden | **8 / 8** (`ALL 0`) | `logs/close/golden/golden.done` |
| full lib suite | **896 passed, 3 failed, 92 ignored**. The three failures are among the six known Mac-only ones. The other three, `r18_a_rung_batch_proves_every_job_…`, `r18_each_batch_job_reloads_every_block_…` and `r18_the_request_reader_refuses_a_symlink_and_a_fifo_without_blocking`, now PASS: they failed only because the batch request reader had no macOS open flags (F4). | `g_full.log` |

The mutation check (`logs/close/mutant/`) is outside the chain. It ran on a temporary build, test binary sha256
`6854ad56…`, and the tree was restored before the code commit.

### 9.12 Not closed, or closed only in part

1. **F3, the flip.** `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` stays `false`.
   - The gate result is D55-DEV-PASS, not PASS: 23 source pins are unread.
   - The flip is a later, separate coordinator commit.
   - The marker is operational, not cryptographic (9.1).
2. **F5, the redesign and the 8B measurement.** The on-demand block source is not built (9.5). The 8B figure is
   modelled, not measured on the CLI: no 8B export is on this Mac.
3. **F6, the `scope` text.** Unchanged: it is a verified statement byte (9.6). It needs the coordinator's
   go-ahead.
4. **F2, the export's limits.** The release-binary runs use a repeated-layer synthetic export of at most 11
   layers, not the twin-alternating chain of the in-memory tests. There is still no D55 golden: receipts are
   OS-random.
5. **Source pins move.** The capture's pins move for the files this closure changed:
   - `run.rs`, `run_fork.rs`, `run_fork_wire.rs`, `run_capture.rs` and `trained_block.rs`, through
     `OWN_SOURCE_FILES`;
   - `tied_tables.rs`, `token_io/load.rs` and `token_io/classify_batch.rs`, outside that list.
   The privacy gate's pending reading of the 23 unread pins must read these versions. The Python gate passes on
   bundles written by this build (9.11).
6. **Left as they are:**
   - `stable_weight_registration.rs`'s `lstat`-then-`File::open`. Its own comment declares a trusted directory,
     and it is outside this path.
   - The CLI's own `vmhwm_mib` self-report, which reads `/proc` and prints `NaN` on macOS. F5 measured with
     `/usr/bin/time -l` instead.
   - The known Mac-only `review_n_r6_b` failure (`/proc/<pid>` liveness).
