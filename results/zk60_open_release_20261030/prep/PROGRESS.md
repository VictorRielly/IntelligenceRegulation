# Open-release prep (E1 to E5) — progress log

Agent: Claude (Opus subagent), commissioned by the coordinating session under D48.
Scope: build the staging tree `/home/victor/ir-public/` from `candidate_files.tsv`
(decision != exclude), do E1 to E5 of `docs/zkmatrix-poc/ZK60_OPEN_RELEASE_PLAN.md`
in staging only. Nothing is published; no git writes; the private repo is not
modified (only this `prep/` folder is written).

Resume rule for a successor: read this log top to bottom; every step names its
output and its completion marker. Heavy jobs go through
`scripts/zk60_resource_guard.py` and write `prep/*.guard.json` + `prep/*.done`.

## Log (UTC)

- 2026-10-30T06:16:16Z  start. `/home/victor/ir-public` and `/home/victor/ir-public-build`
  absent. Disk: / 490 G free, /mnt/c 131 G free. Guard status: heavy lock HELD
  (sol-r14-native-capture-dd-3, cpu 8G) + gate23 light job; budget 9.0/11.89 GiB.
- 2026-10-30T06:17:23Z  read plan, D43/D46/D47/D48, resource protocol, inventory
  (`candidate_files.tsv`: 1,316 rows; 1,297 publishable = 1,155 include + 8 redact
  + 134 review; 19 exclude). The 93 lane tools are already mapped to
  `tools/model-export/<group>/` in the TSV, so the step-3 copy performs the lift.
- 2026-10-30T06:20Z  step 3 done: `prep/stage_copy.py` copied 1,297 files (47,268,094 B) into
  `/home/victor/ir-public`; every sha256 equals the inventory; 0 forbidden paths
  (`prep/stage_copy.json`).
- E1 done: staging `hashline/ zkp-core/ private-block-kernel*/ results/` = frozen-r16b exactly:
  301/301 files match `manifest_final_r16b.sha256` (list sha256 04d94bc0…), none missing.
  No REVIEW_R16b exists yet; r17 frozen (test-only, unreviewed); no frozen-r18 yet.
- E2 policy decided (see `prep/E2_NOTES.md`): the capture source-pinned production files
  (run_capture.rs OWN/SHARED/CLASSIFY_SOURCE_FILES) are NOT edited, because privacy gate
  v23 pins their exact digests (e.g. derive.rs c5bec3c6…, trained_accuracy.rs f47b1084…);
  test-only files and unpinned files are parametrised.
- 2026-10-30T06:25Z  E2 Rust: `prep/e2_rust_edits.py` (8 files: capture/r2/r3/run_capture tests, gpu_cache
  test, unpinned export.rs default, two Cargo.toml comments). Not edited: derive.rs (pinned).
- 2026-10-30T06:27Z  E5 addition: 129 public synthetic R13 loader fixtures (16.4 MB) copied to staging
  `results/zk60_1b_native_20261017/r13/loader-fixtures/` (`prep/additions.tsv`); the native suite reads
  them through HL_R13_LOADER_FIXTURES. Not in candidate_files.tsv: coordinator to confirm.
- 2026-10-30T06:30:26Z  E5 build (copy `/home/victor/ir-public-build`, guard build 3.5/5 GiB):
  `cargo build --release --locked --offline -j2` exit 0, 88 s, peak RSS 1.26 GiB; binary sha256
  a98b58e4… (differs from dfb8025e…: different source path + E2 test edits do not reach the bin, path does).
- 2026-10-30T06:43:35Z  E5 native suite (guard cpu 9/11): exit 0, 789 s, 29 binaries, 936 passed,
  0 failed, 68 ignored (= s21), peak RSS 10.35 GiB / cgroup 10.77 (cap 11: thin margin). 2 gpu_cache
  process tests loud-skip (125M v3 export absent). Logs `prep/e5-suite.log`, `prep/e5-suite.guard.json`.
- 2026-10-30T06:40Z  review agents A/B done: 40 docs/app files, 39 include, 1 redacted
  (ZK60_PARALLEL_ROUND2.md "while away"); `prep/review_decisions_A.tsv`, `_B.tsv`.
- 2026-10-30T06:50Z  E2 tools: `prep/e2_tools_edits.py` (60 files) + 7 follow-up fixes (source-name
  digest loops -> CODE, report_fidelity runner, report_categories digest, corpus4 note,
  evaluate_verdicts_cached baseline constant). vendor_port output verified byte-identical for
  tlcalib/b3calib/b3_ladder (adapted sha256 2441cc40 / 656049c8 = the lane's PORT_MANIFEST).
  E2 app: `prep/e2_app_edits.py` (7 files). E2 scripts/tests: `prep/e2_scripts_edits.py` (20 files).
  privacy-gate/ left = frozen v23 (80/80 manifest match); see E2_NOTES.md.
- 2026-10-30T06:58Z  E3 done in staging: DECISIONS (D43/D46/D47/D48 rows + "shown to investors" in D37),
  MVP_STATUS (crash/Windows block, two funding passages, "VC readiness" heading/link), START_HERE (5090 PC /
  hardware-guide sentence, team-map link, one path), RULINGS_FOR_VICTOR (cuda-root path),
  RULINGS_FOR_VICTOR_20261017 (items 3-5 of 10-28: Fellows, company, Windows tools), RULINGS_FOR_VICTOR_PRIVACY
  (nothing personal found), RESOURCE_PROTOCOL (restart wording, guard path, Windows/C: specifics, .wslconfig path),
  README (replaced). Extra: web/techweek "What funding moves forward" -> "What comes next"; app README
  "Investor screenshots" -> "Demo screenshots"; TASK_BOARD Telegram-router bullet removed;
  docs ZK60_5090_LINUX_BRINGUP.md EXCLUDED (owner home-machine SSH/user setup; kept in scratchpad only).
- 2026-10-30T06:58Z  E4 written: README.md, LICENSE-MIT, LICENSE-APACHE (word-identical to the canonical text),
  NOTICE, SECURITY.md, CITATION.cff, tools/model-export/README.md. Root PDFs: not in staging (never in the list).
- 2026-10-30T06:58Z  scan: `prep/ir-public-scan.tsv`: 1,432 files, 0 critical, 0 high, 15 info (public testnet
  addresses), 22 low (all false positives: matrix sizes, user@1000.service, kernel versions). No keys / DBs /
  .testnet-private / owner-private / symlinks / target in staging. `/home/victor` left in code only in pinned files
  (derive.rs, privacy-gate v23 x12, zk60_opus_attention_inventory.py); see E2_NOTES.md.
- Tools review agents (read-only, 93 tools) running; baseline Python suite (pristine copy, cpu 3/4.5) queued
  behind the heavy lock. Next: merge review_decisions.tsv, launch `prep/e5_python.sh` (resync + py suite +
  classify example + P1 demo), then delete build target/.
- 2026-10-30T07:04Z  tools reviews done (A: 49 shieldstral-export files, B: 44 others): 93 include; B's two fixes
  applied (record_pins SNAP honours ZK60_MODELS; oracle.py marked historical); README limits extended. Stray
  `__pycache__` from the vendor_port check removed. `prep/review_decisions.tsv` = all 134 review files (131
  include, 2 include-fixed, 1 include-redacted). Launched `prep/e5_python.sh` (resync build copy, py suite cpu 5/8,
  classify example build, P1 demo); markers `prep/e5-py-suite.done`, `e5-classify-build.done`, `e5-p1-demo.done`,
  `e5_python.done`.
- 2026-10-30T07:10Z  baseline Python suite (PRISTINE staging copy, no cargo on PATH, guard cpu 3/4.5; light
  1.5 GiB attempt was cap-killed at 06:33, kept as `e5-py-baseline.light-killed.*`): 1,232 tests, 18 failures,
  35 errors, 123 skipped, 359 s, peak RSS 1.77 GiB. Causes: test inputs under results/ and ops/ that are not in
  the public tree (results/zk60_opus_attention_inventory.json x11, results/zk60_round22_captures.json x5,
  results/cl1_floors.sh x~16 FloorsRunner, ops/zkp-mvp/*.py, ...), and tests that parse main-tree hashline
  sources while the snapshot ships r16b ("substring not found" x9).
- 2026-10-30T07:26Z  E5 part 2 (build copy re-synced from final staging 07:04):
  * Python suite (guard cpu 5/8, cargo on PATH, offline): 1,232 tests, 18 failures + 36 errors, 110 skipped,
    973 s, peak RSS 2.54 GiB. Failing set = the pristine baseline's exactly, plus test_ring_freeze_check, which
    only runs when cargo is present and needs the absent 125M regression export. The E2 edits added no failure.
  * `cargo build --release --locked --offline -j2 --example zk60_classify`: exit 0, 16 s; sha256 88d14ec6…
    (differs from dfb8025e…: the build path is compiled in).
  * `scripts/zk60_p1_demo.py`: passed, 9 steps, 6 of 6 rejection controls (`prep/e5-p1-demo.manifest.json`).
- 2026-10-30T07:28Z  D46 cleanup: deleted the build copy's hashline/target (268,284,643 B = 259 MiB) and
  zkmatrix-rs/target (117,854,385 B = 114 MiB), and the 80 MB test scratch dir. The build copy (65 MB, no target)
  is kept at /home/victor/ir-public-build. Final scan: 1,431 files, 0 critical, 0 high, 15 info, 22 low (all false
  positives). No keys, DBs, .testnet-private, owner-private, venv, target, pyc, PDFs or symlinks in staging.
  Staging: 1,431 files, 64,315,326 B.
- 2026-10-30T07:38Z  E6 (coordinator follow-up): `prep/e6_test_edits.py` applied in staging to the 54 failing
  entries. 17 entries get (a) skip guards (in 7 files); 37 entries are (c) removed (FloorsRunner 18, LegacyLauncher 2,
  security-probe 5, cl_profile 1, and 3 whole files); (b) none possible.
  Decisions in `prep/e6_decisions.tsv` and `prep/removed_tests.tsv`; diff `prep/e6_tests.diff`. Exact derive.rs
  change and the 11/12 GiB native-suite rule added to E2_NOTES.md. Launched `prep/e6_python.sh` (resync +
  guarded cpu Python suite, -v); markers `prep/e6-py-suite.done`, `prep/e6_python.done`.
- 2026-10-30T08:00:41Z  E6 Python suite (clean build copy re-synced 07:38, guard cpu 5/8, cargo on PATH, offline):
  **Ran 1,223, OK: 0 failures, 0 errors, 151 skipped**; 977 s, peak RSS 1.95 GiB (`prep/e6-py-suite.log`).
  Before (E5): 1,232 ran, 18 failures, 36 errors, 110 skipped. Skips listed in `prep/e6_skips.tsv`
  (41 introduced by E6, 110 pre-existing guards). Removed from staging: 59 test methods (26 inside files + 3 files
  with 33). Repointed: 0 (none applicable). Build copy's zkmatrix-rs/target (117,854,385 B) and the e6 scratch
  deleted. Final scan: 1,428 files, 0 critical, 0 high. Staging 1,428 files, 64,260,445 B. README results updated.
- 2026-10-30T07:41Z  check of the (a) inventory skip message: `scripts/zk60_opus_attention_inventory.py` runs on the
  staging tree (3 s, all checks pass). Its output equals the private record except six recorded source digests.
  A partial copy ran the two attention test modules (47 of 48 ran green; 1 failed only because that copy lacked docs/).
  A full-copy rerun is queued: `prep/e6-inventory-tests.log` / `.done`.
- 2026-10-30T08:20Z  full-copy check with the regenerated inventory: 48 ran, 47 pass, 1 skipped, 1 FAIL
  (`test_committed_schedule_record_is_this_tools_output`: the committed record pins the ORIGINAL inventory
  sha256 81e634be…, the regenerated one is 478a2895… because it records r16b's digests of six other sources).
  The test is not weakened. The skip message in both attention test files now says exactly this (message-only
  edit; the two modules re-checked in a fresh copy: 33 ran, OK, 31 skipped). Log `prep/e6-inventory-tests.log`.
- 2026-10-30T08:22Z  coordinator hold (token round 18 step E): acknowledged. No irpub-* job is live or queued (checked
  with ps and the guard status). E6 needs no further cpu or build job; the last one (irpub-e6-inv-tests) finished
  at 08:20. A successor must not launch heavy jobs until no tio18-* label remains in the guard status, or
  results/zk60_token_io_r1_20261017/r18/logs/r18_eq.done exists.
- 2026-10-30T16:25Z  E1 SWITCH to token round 19b + gate v24 (coordinator). Hold condition met (r18_eq.done exists;
  guard quiet). Repointed inventory `prep/inventory_r19b/build_inventory.py` (+ outputs there; the morning inventory
  is untouched): 1,326 listed, 1,307 publishable; vs morning +15 / -5 / 28 changed. `prep/e1_switch.py` built the
  new tree: morning edits carried for 111 unchanged sources, 4 removals repeated, 135 staging-only files copied
  (E4 + loader fixtures); re-applied by hand for the 6 edited-but-changed sources (app README, config.py,
  test_storage_policy.py, MVP_STATUS, DECISIONS and RULINGS_20261017 by diff3 merge, clean except MVP_STATUS,
  whose redaction was re-applied to the new text). New doc ZK60_OPEN_RELEASE_PLAN.md EXCLUDED (personal: job,
  attorney). Checks: r19b manifest 299 match + 7 = the carried E2 Rust test/unpinned edits; gate v24 80/80.
  README: r19b/v24, the E7 verification text, the statements' scope; CITATION round updated. Staging swapped:
  /home/victor/ir-public = r19b (1,437 files, 64,621,500 B); old tree kept at /home/victor/ir-public-r16b.
  Fresh build copy; launched `prep/e5_r19b.sh` (build, native cpu 11/12, classify, py suite, P1 demo);
  queue log `prep/r19b_queue.log`, marker `prep/r19b_queue.done`.
- 2026-10-30T16:54Z  E5 on round 19b, in a fresh build copy, all guarded, offline:
  * build: exit 0, 73 s, 1.3 GiB; bin sha256 41e4f24f….
  * native suite (cpu 11/12): exit 0, 29 binaries, 971 passed / 0 failed / 71 ignored (= the lane's s24),
    713 s, peak RSS 10.2 GiB, cgroup 11.44 GiB (cap 12).
  * zk60_classify example: exit 0, sha256 bafcd2d9… (development binary 6d65d32e…; the build path is compiled in).
  * Python suite: Ran 1,223, OK, 151 skipped, 874 s, 2.36 GiB. Per-test statuses are identical to the E6 run.
  * P1 demo: passed, 9 steps, 6 of 6 controls.
  * Deleted hashline/target (269,653,278 B) and zkmatrix-rs/target (117,854,385 B), plus the 79 MB scratch.
  * Final scan: 1,437 files, 0 critical, 0 high (15 info, 22 low, same false positives). Staging 1,437 files,
    64,621,500 B. README counts updated (971/0/71).
