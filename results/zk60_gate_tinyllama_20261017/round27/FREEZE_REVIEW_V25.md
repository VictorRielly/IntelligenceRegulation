# Gate round 27: independent freeze review of the v25 staging gate (D55 "commit, fork, join")

Reviewer: Claude (Opus 5.5), 2026-11-02, read-only. The task was to find ways the gate can say PASS when it should not.
This review is not a privacy statement, and it changes no code.

## Bottom line

**Freeze after named fixes.**

The checks that run look correct, and they fail closed when a figure is wrong. The weak points are in what the
status counts:

* A load-bearing check can be skipped and still give D55-PASS: the Rust hash-census lookup when its environment
  variable is missing, the run-level joint rank under `--no-joint`, and every negative control under `--no-controls`.
* D55-PASS ignores the `not_here` list.
* The pin classification does not check that the pin list is complete. It also still admits two files on a 48-bit
  prefix.

None of the findings shows a leak in the 12 recorded bundles.

The fixes needed before the freeze are FR25-01 to FR25-06. All six are in files that are new in v25
(`zk60_native_rg_d55.py`, `zk60_native_rg_d55hash.py`, `zk60_native_rg_w16.py`, `zk60_native_rg_r26readings.py`),
so no v24 file moves. FR25-13 is a one-line relabel to do at the same time.

The merged 18-part run now under way can finish; its figures stand. Before its records are used as freeze evidence,
check each one for:

* controls on;
* joint rank on;
* the printout given at the pinned digest;
* the 75 expected pins;
* no prefix-only reading used.

Or re-run the gate on the fixed tool state.

## 1. Scope

**Tree.** The main checkout `/Users/victorrielly/IntelligenceRegulation`, branch `perf/zk-batch-optimizations` at
`22039169`. Every file under `staging_v25/` equals that commit's blob (258 files, 0 mismatches).

The worktree branch this report is committed on (`worktree-agent-a24371c142b91bde5`) is based on the older `9d9d9aee`
and does not contain `staging_v25`. The report directory is new on that branch.

**What v25 adds.** I compared `staging_v25` with `frozen_v24` file by file:

* 9 new scripts and 5 new tests;
* no v24 file changed or removed.

The brief's list matches.

### Files under review (sha256 of the bytes read)

| file | sha256 |
|---|---|
| `scripts/zk60_native_rg_d55.py` (the driver, `d55_gate`) | `60f1c73e888114a85e19e5958f2499fd98b180d997e2f1c76ac3e0d384139201` |
| `scripts/zk60_native_rg_d55r13.py` | `927cb40841a1b7c54bec464943714e247239a41c8fe58ab6cc5023d981d4b556` |
| `scripts/zk60_native_rg_d55joint.py` | `3fc784d6e547fcba9465c2496b571bab8d340591c00999629bdb0d6ba77242d7` |
| `scripts/zk60_native_rg_d55nl.py` | `e8d855b36b8a0ad76c3f63181ef9e5aef6b2898269859855dbc37a0e8231109b` |
| `scripts/zk60_native_rg_d55preimage.py` | `dbbf3f1c05556472114a429752ca44890855c4f90a78b021f8ff084e87934b90` |
| `scripts/zk60_native_rg_d55ts.py` | `d938b0c7c2b6b1cc6bab2998f206569a464bfc8a09be6fa12772b380fcb10a0d` |
| `scripts/zk60_native_rg_d55hash.py` | `929fc51b85f8fb702bde4d7d7c6aa569e4c644bfade8db93f9661295c405e5ed` |
| `scripts/zk60_native_rg_r26readings.py` | `e601e9554c3359949b47431de974292bd36bd5d9e340a4c90c69521dde892b77` |
| `scripts/zk60_native_rg_w16.py` | `96342f8a1868c400684ab2f773a62a2d4f569c4a9c2504bea94e8c8a3ae46530` |
| `tests/test_d55_nl_preimage.py` | `58d742073020a8eecde625f23331e4c7f59dcdf163e90b410bb9eceafda03e60` |
| `tests/test_d55_r13_gate.py` | `ad5df13caa1e966f60cc7459865ea038d9ad53446561223fe9d17142c8a3d146` |
| `tests/test_d55_ts_hash.py` | `c1bcafb40cf429f4aec23f8988c22b451d960a64bb3bb8329209755a2b820c21` |
| `tests/test_r26_readings.py` | `6776c320823623113f0110c50f7132954df1a2155390ff7412b6d8ce2830d69b` |
| `tests/test_w16_gate.py` | `6f4c4229eacae49e7edd9e15167cc1bda5d663a7fec5e4d4def6599cf601e96f` |

All paths are under `ops/zkp-mvp/gate-tinyllama/staging_v25/`.

### How much I read

**Read in full:**

* the driver;
* the joint, R13, NL-1, preimage, TS and hash modules;
* `r26readings`;
* the W16 module's facts, geometry, tab and PINS sections and its driver;
* `test_r26_readings.py`.

The other four tests I read by test list and skip conditions only.

**v24 files read where the new code depends on them**, unchanged since v24:

* `zk60_native_rg_stagecal.py` (`a47b9a98…`);
* `zk60_native_rg_r13blocks.py` (`f4ef6373…`, `stage_facts` and `check_stage`);
* `zk60_native_rg_r13slots.py` (`09878d5e…`, precision, plane list, lookups);
* `zk60_native_rg_terminals.py` (`094029b7…`, `check_source_pins`);
* `zk60_native_rg_tokennl.py` (`c5047cf0…`, `controls`);
* `zk60_native_rg_replay.py` (`6852cd94…`, `summary`).

**Rust, at the call sites only:**

* `run_capture.rs` `10b6d3be…`: `write_fork_bundle`, `source_pins`;
* `run_fork_tests.rs` `5ce04593…`: the D60 writer test;
* `w16_privacy_gate_tests.rs` `cad59545…`: the test-only fork writer and `d60_registered_bundle_checks`;
* `run_fork.rs`: the seed domains and the census;
* the `HL_GPU` toggles, found by grep.

**Records**, read as evidence:

* the decisions register, rows D12a, D33, D55 and D60 in full (`64fd10fd…`);
* the D55 soundness note §3–§6 (`a0ecaa7c…`);
* `READINGS_R26_WIRING_CHECK.md` (`3c3dae4a…`);
* the tsbases `summarize_pass1.out` (`0c438bf9…`);
* the merged-gate `pygate.sh` (`642fdccf…`);
* the round-20 classifier record (`e94d6e7b…`);
* the D58 statement's G-R2 section;
* the nlpre and tsbases READMEs (parts);
* `round24/freeze_v24.py`.

**Not read:**

* the v24 rank, mask and preimage internals (`RunRoleView`, `zk60_native_rg_joint`, `ahpreimage`, `mcontrols`), taken
  as frozen;
* `ts_trained.py` and `nl_check.py`, which are pinned;
* the Metal device code;
* the `privacy_gate_r26` README beyond its scripts.

**Run.** Three small experiments on in-memory copies, each under
`zk60_resource_guard.py run --class light` (logs in `logs/`, under 1 s and about 0 GiB each):

* `pins.log`: pin-list completeness, on a real bundle's manifest, read-only;
* `nldir.log`: the `ZK60_NL_CHECK_DIR` import shadow, in a scratch directory;
* `prefix.log`: the prefix twins, the PINS controls with no object, and the unpinned Metal files.

No build, proof, gate run or test suite was run. The heavy lock stayed with the merged gate.

## 2. Findings

CONFIRMED means I reproduced it, or it is shown by a record in the repository. PLAUSIBLE means I found it by reading
and did not run it. Line numbers refer to the sha256 values above.

| ID | severity | status | file:line | failure scenario → wrong verdict | suggested fix |
|---|---|---|---|---|---|
| FR25-01 | **High** | CONFIRMED | `d55hash.py:669-674`, `:547`, `:651`; `d55.py:987`, `:993` | `ZK60_S25_W2_PRINTOUT` unset, or set to a path that does not exist (for example, the printout not unpacked) → `load_rust` returns None → HASH-2 checks only the gate's own conditions, HC-7 is dropped, and the part is TRUE → **D55-PASS**. The repository has one: `records/d55-first-r13-rung-s0.json` is D55-PASS 16/16 with "Rust table: ZK60_S25_W2_PRINTOUT is not set … None compared" (`summarize_pass1.out:1-27`). In the same pass, the only HASH-2 finding on the 8B bundles was this lookup (the 317-byte L = 3 `parameters` absorb, which s25 had never measured). Run without the variable, the L = 2..9 finding would have come out D55-PASS on every bundle. | At an R13 base, make the printout mandatory: absent or unreadable → HASH-2 false. Run HC-7 always. |
| FR25-02 | Medium | CONFIRMED | `d55hash.py:669-674`, `:588`; `privacy_gate_merged/pygate.sh:6-8`, `:18`, `:24` | Any file named by `ZK60_S25_W2_PRINTOUT` is accepted as "the Rust census". An edited copy, or a printout from another tree that lists more kinds, makes the lookup pass. Its sha256 is recorded and compared with nothing. `s25_tests.rs` is in no pin list, so even the genuine printout is not tied to the pinned tree. The wrapper's comment says the digest is "checked against PRINTOUTS_SHA256.txt", but neither the wrapper nor the gate does it. | Pin the printout's sha256 in the gate (like `TS_TRAINED_PIN`) and refuse any other. Record the digest of the `s25_tests.rs` that made it, and give that file a reading. |
| FR25-03 | Medium | CONFIRMED (code) | `d55.py:885-893`, `:894-896`, `:911-916`, `:938-939`; `d55.py:688`; `d55preimage.py:238-240`; `d55nl.py:551`; `d55r13.py:313`, `:555`; `d55ts.py:497`, `:549`; `d55hash.py:682`, `:699` | `--no-joint`: D55-J, ruling M-8's run-level joint rank and the one D55-specific privacy obligation, never runs and is not a part. Status D55-PASS, with one `not_here` line. `--no-controls`: no negative control runs anywhere (D55-C, the PINS controls, J-C1..6, P-1..6, PRE-*, TS-1, CEN-*, HL-*, HR-*, HC-*, NL-*, R13-*, exclusivity, mask, IO). Status still D55-PASS. The nlpre README suggests `--no-controls` "only for runs that are not records", but the record looks the same. | If `joint` or `controls` is false, cap the status at D55-DEV-PASS, or give it a status of its own. Write `controls_run` and `joint_run` into the record. |
| FR25-04 | Medium | CONFIRMED | `d55.py:916`, `:928-937`, `:957`, `:963`, `:994` | The status never reads `not_here`. (a) The four round-26 bundles and `first-r13-rung-s0` are D55-PASS while `not_here` lists NL-1 and the full preimage (and, at round 26, TS-1, the census and the hash census too). D60's rule "the CLI's real-content block stays closed until a PASS record exists" was met by records that owed four privacy items. (b) W16 family: D55-PASS needs only the eight W16 parts, while `not_here` lists T-0, NL-1, TS-1 and the census, the full preimage and the hash census. Today it is unreachable only because the test-only fork writer records no `proved_on_gpu` (`w16_privacy_gate_tests.rs:1966`), so the backend is UNKNOWN. One writer line plus a reading of that pinned test file would make W16 D55 bundles D55-PASS with five privacy items owed. | D55-PASS only when every `not_here` entry is a named, accepted residual: a constant list, each entry citing the decision row that accepts it. Cap the W16 family at DEV-PASS until its items are ported. |
| FR25-05 | Medium | CONFIRMED | `w16.py:580-613`; `d55.py:897-909`; `d55.py:278` | The pin list a bundle declares is never checked for completeness. `logs/pins.log`: the real rung bundle's manifest with 69 of its 75 pins removed still gives PINS ok and an admissible backend. Only `argument.rs`, `layout.rs`, `plane_index.rs`, `protocol.rs`, `pad.rs` and `shape.rs` were kept. The removed pins include `run_fork.rs`, `run_fork_wire.rs`, `run_capture.rs`, zkp-core `pcs.rs` and `rng.rs`, `gpu/metal.rs` and `metal_kernels.metal`. D55-0 leaves `manifest.json` out of its file hashing, so the edit is not seen. For the W16 family even an empty list gives PINS ok. The real-world version is any other writer of D55 bundles with a shorter list, for example a CLI-capture path after the flip. | The gate holds the expected pin set per writer and requires exactly that set (missing or unexpected → refused). For the registered writer that is the 75 files of `OWN_SOURCE_FILES` + `SHARED_SOURCE_FILES` of the read `run_capture.rs` `10b6d3be`; the test-only writer adds three. Also require the manifest's `writer` to be a known writer string. |
| FR25-06 | Medium | CONFIRMED | `w16.py:529-537`, `:592`; `d55.py:788` | Two W16 readings have no R26 reading at the same prefix: `run.rs` `b9b40cadef4a` and `run_capture.rs` `d10d33e3e04f`. They still read a pin on its 12-hex prefix alone. `logs/prefix.log` (a): the prefix followed by 52 zeros is "read here" for both, and PINS is ok. This contradicts `r26readings`' "a 48-bit prefix alone never reads a pin". Control P-1 always targets an R26-read pin (`d55.py:788`), so it cannot see this path. `run_capture.rs` writes every field the gate reads, including the pin list and `proved_on_gpu`. A file whose SHA-256 starts with 48 given bits takes about 2^48 hashes, hours on this machine's GPU. | Give `W16_READINGS` the full digests from the W16 reading record and match by equality, or drop the prefix branch for D55 bundles. Add a P-3 control on a W16-read pin. |
| FR25-07 | Low | CONFIRMED | `d55nl.py:118-130`, `:142-143`; `d55.py:983-984`, `:970` | `ZK60_NL_CHECK_DIR` puts its directory at `sys.path[0]` for the rest of the process. `d55_gate` imports `zk60_native_rg_d55hash` and `_d55ts` only after NL-1. `logs/nldir.log`: a directory with byte-identical `nl_check.py` and `nl_field.py` plus an extra `zk60_native_rg_d55hash.py` passes `load_nl`'s pin check, and the driver's import then loads that extra file. The record's `tool_sha256` still shows the staging file's digest, because it hashes the scripts directory at the end of the run, not the modules loaded. | Load `nl_check` by file location (`importlib.util.spec_from_file_location`) without touching `sys.path`, or remove the directory again after the import. Import every part module at the top of `d55_gate`. Hash each loaded module's `__file__` into `tool_sha256`. Record the variable in the main record. |
| FR25-08 | Low | CONFIRMED (code) | `d55.py:359-374`; `w16_privacy_gate_tests.rs:2069ff` (the Rust checks) | `receipt/tail.bin` (3,281,008 B at the rung) holds every boundary and endpoint opening. It is checked only against the manifest's file hash. `d55_tail.json` has no `segment_bytes` or `segment_sha256`, unlike each fork stage file. The Rust checks compare only the tail JSON's shape across two inputs. A writer that writes a tail frame other than the one the recorder saw would pass, for example a CLI-capture path that writes the CLI's receipt file and records a re-verification. No current bundle is affected: the writer writes the very frames it verified (`run_fork_tests.rs:1227-1232`). | The recorder writes the tail frame's length and sha256 into `d55_tail.json`, and the gate checks them as it checks the forks. Better: decode the frames independently. |
| FR25-09 | Low (latent) | PLAUSIBLE | `r26readings.py:291-324`; `run_capture.rs:4469` | The backend rule takes `proved_on_gpu` as given. W-1 and W-2 show how it can be wrong (verdicts in §3). The gate never reads the manifest's `writer` field, which is what currently tells an in-process registered capture from anything else. | Rust latches the backend per proof and records the prover's own backend. The gate requires `writer` to equal the registered in-process writer string, and otherwise refuses the bundle as UNKNOWN. |
| FR25-10 | Low | CONFIRMED (code) | `w16.py:574-579`, `:633-640`; `d55.py:897`, `:1009` | The r19b reference manifest is an unpinned input. `--r19b-manifest` naming a later tree's `manifest_final`, or an edited `manifest_final_r19b.sha256` found by the upward directory walk (for example in a worktree), turns every moved pin into "at r19b" with no reading. The record keeps only the path. | Pin the r19b manifest's sha256 in the gate, refuse any other, and record the digest. |
| FR25-11 | Low | CONFIRMED | `d55.py:788-793`; `d55ts.py:115`, `:509-520` | Two controls count as fired with nothing to act on. P-1 and P-2 are `fires: True` when no pin uses an R26 reading (`logs/prefix.log` (b)). TS-1F is `all([])` = true when no TS-1 row has at most `ZK60_D55TS_FIDELITY_ROWS` data rows; that variable set to 0 makes TS-1F vacuous on every bundle. D12a's own rule is that a control with no object is NOT APPLICABLE and a family with none applicable is not a pass (quoted at `d55preimage.py:42-45`). | Report no object as `fires: None`, and require at least one applicable control per family. Refuse a fidelity row limit below 1. |
| FR25-12 | Low | CONFIRMED (code) | `d55joint.py:315-329`; `d55.py:885-887` | J-C5 runs only with `--other`; without it the control drops silently out of `applicable`. With `--other` naming a bundle of another profile or shape, the replay fails at the header and the control "fires" for a reason that has nothing to do with a fork swap. `--other` feeds no figure (see §3, binding). | Require `other.profile == b.profile` and a different `run_binding`. Name the expected failure site (fork 1's start tag). Require `--other` for a record. |
| FR25-13 | Info | CONFIRMED | `r26readings.py:246-262`; `d55.py:928-930` | The three wiring readings were checked independently in `748fe707` (`READINGS_R26_WIRING_CHECK.md`), but they are still labelled SELF_READ. So every PASS record still says "the independent check of the self-read readings … at the v25 freeze review" is owed. | At the freeze, label the three entries with the check as their independent reader. Keep `metal.rs` and `metal_kernels.metal` at CPU-path scope only. |
| FR25-14 | Info | CONFIRMED | `tests/*` | No test calls `d55_gate`'s status computation. The two lane blocks are checked only as text (`DriverBlock`, `…delimited_block…`). `main` exits 0 for both D55-PASS and D55-DEV-PASS (`d55.py:1037`), so a queue that checks exit codes cannot tell them apart. Records are overwritten silently by name (`d55.py:1025`). | Stub the parts and assert the status for every flag combination, together with the FR25-01, -03 and -04 fixes. Give DEV-PASS its own exit code, and refuse to overwrite a record. |
| FR25-15 | Info | CONFIRMED (code) | `d55r13.py:427-446`, `:456-459` | Per-fork own calibration: `d_max` and `norm_wrho` are not re-derived (the shim takes the run's `norm_wrho`), and an out-of-class own shift raises a ValueError out of `d55_gate` (a crash, no record). Both come from v24 (`r13blocks.py:323-324`) and both fail closed. | Re-derive as `stagecal.stage_shapes` does (SC-7). Catch the ValueError into R13-3 = false. |
| FR25-16 | Info | — | `d55r13.py:506-517` | G_k is recovered, not read (verdict in §3). | Print it in the D55 stage line as the classifier does (`; R13 gate denominator N (…)`, bound through the schedule digest), and compare the recovered value with it. |
| FR25-17 | Low | — | `d55nl.py:109-110`, `:495-496` | S1–S5 on the 16 slots R13 does not redefine are not computed at any D55 base shape (verdict in §3). | The exact run is given in §3. |
| FR25-18 | Info | PLAUSIBLE | `d55ts.py:197-241`, `:273-289` | TS-1 and the census re-read `run.json`, the stage files and the tail from disk long after D55-0, with no new manifest check; an 8B record takes about 78 min. A file changed in between would be ranked unchecked. In inline mode the `_W` cache keys roles by path, so one process gating two bundles at the same path would reuse the first one's roles. | Pass the loaded `D55Bundle` documents to TS, or re-hash each file against the manifest before reading it. Key the cache by file digest. |

## 3. Verdicts on the must-cover items

### Q1. Fail-open paths: how `parts`, `status` and `not_here` are computed

* **`parts`** is a dict of booleans. Every part that runs stores `bool(...ok)`. When the replay fails, the dependent
  parts are set false explicitly (`d55.py:859-860`, `:889-893`, `:958-965`, `:989`), not left out.
* **`status`** is computed at `:916` from `all(parts.values())` and `pins["ok"]`. The two lane blocks can only lower it:
  * the NL-1 / PRE block at `:966-968`;
  * the TS / CENSUS block at `:995-997`, which re-tests `all(parts.values())` and so covers both blocks' parts.
* **A part that is FALSE can never give D55-PASS.** I checked the two blocks' order, the shared `parts` dict (`:914`)
  and the guard around `views` (`:960`).
* **A part that is ABSENT or SKIPPED can give D55-PASS:**
  * D55-J under `--no-joint`;
  * every control under `--no-controls` (FR25-03);
  * HASH-2's Rust lookup without the environment variable (FR25-01);
  * J-C5 without `--other` (FR25-12);
  * TS-1F with no cheap row (FR25-11);
  * for the W16 family, the five items still listed in `not_here` (FR25-04, latent).
* **`not_here`** is a report only and never enters the status (FR25-04).
* **Caught exceptions.**
  * The only broad catches on the D55 path are `stagecal.schedule_digest` (sets `equal` to false) and the RSS probe in
    `main`.
  * The slot ports catch `ValueError` / `IndexError` / `KeyError` into "not checked", which counts against `ok`.
  * `rust_table` skips lines it cannot parse. An empty table fails the lookup (`bool(table)`), so that is not fail-open.
* **Empty loops.** Each is guarded: `n == 2L` (D55-IO), `bool(per)` (R13-3), `n == 7L` (NL-1), `columns_checked > 0`
  (HASH-1), `bool(applicable)` (joint controls), `bool(live)` (TS-1, N5-2). The exceptions are TS-1F and P-1 / P-2
  (FR25-11).
* **Defaults.** `public_tables_included` defaults to false (fails closed). `source_pins` defaults to `[]`, which is
  accepted (FR25-05).

### Q2. Controls

Each control I traced mutates the object the real check reads, and restores it in a `finally`:

* D55-C C1 and C2;
* J-C1..J-C4 and J-C6;
* the IO control;
* PRE-T1..T3 and PRE-A2 / A3;
* HL-2..HL-7 and HR-1..HR-4;
* HC-1..HC-7;
* NL-TAB-GC, NL-TAB-ACT and NL-G;
* B-1..B-3.

The controls that only build doctored copies (HC-*, CEN-*, B-*, P-*) build them from the same functions the real
check calls. The exceptions:

* P-1 / P-2 and TS-1F can count as fired with no object (FR25-11).
* P-1 never targets a W16 prefix reading, which is exactly where a prefix twin still passes (FR25-06).
* J-C5's premise is not checked (FR25-12).
* No control removes a pin from the list (FR25-05), or drops the printout (FR25-01).

### Q3. Binding

| input | what it feeds | verdict |
|---|---|---|
| `--other` | J-C5 only; `b.stages[1]` is swapped and restored. No figure reads it. | bound to the judged bundle; FR25-12 for the control |
| `ZK60_S25_W2_PRINTOUT` | HASH-2's lookup and HC-7 | **not bound**: optional (FR25-01), unpinned (FR25-02) |
| `ZK60_NL_CHECK_DIR` | the NL-1 tool, digest-checked; also, by `sys.path`, every module imported after it | partly bound (FR25-07) |
| `ZK60_D55TS_WORKERS` | process count only; results are keyed by task, and a worker exception propagates | no effect on figures |
| `ZK60_D55TS_FIDELITY_ROWS` / `_COUNT` | how much TS-1F runs; written into its text | can make TS-1F vacuous (FR25-11) |
| `--r19b-manifest` / the upward walk | the "at r19b" class | unpinned (FR25-10) |
| `HL_*` | not read by the Python gate. Rust: `HL_GPU` sets `proved_on_gpu` at write time (W-1 / W-2); `HL_TEST_SOURCE_COMMIT` sets `source_commit`, which the gate does not use | see W-1 / W-2 |
| manifest `source_pins` | PINS | self-declared, list completeness unchecked (FR25-05); read from disk at write time (W-9, from v24) |
| `receipt/tail.bin` | nothing | not bound to the observations (FR25-08) |

Everything the replay and the rank parts compute is bound to the bundle's own transcript:

* run_binding, S0, the forks, S1 and the tail end are re-derived;
* the hash rule is derived from the block profile, not taken from the bundle's tag (HR-1..3);
* the head length is exact.

### Q4. Source pins and readings, and the backend rule

`reading_for` reads a pin only at an R26 reading's FULL digest. A prefix twin of any R26 entry stays UNREAD; this is
tested and correct.

Two old W16 entries still read on a prefix (FR25-06). A stale reading cannot be used for an R26 file: where R26 has a
reading at a prefix, the W16 prefix branch is shut off (`w16.py:592`). The two W16-only entries are stale readings of
`run.rs` and `run_capture.rs` at their W16-era digests, which no current bundle uses.

The backend rule, `gpu_backend`:

| `proved_on_gpu` | result |
|---|---|
| missing | UNKNOWN, refused |
| not a boolean (`"false"`, `0`, `null`) | refused |
| `true` | refused while either Metal file is unpinned or lacks a FULL reading (none exists) |
| `false` | admissible; the Metal pins then need at least the CPU-path reading |

With `false`, the rule does not require the Metal files to be pinned at all (`logs/prefix.log` (c)). That is part of
FR25-05.

### Q5. The must-cover items

**W-1 (the backend is recorded by the capturing process, not the prover): agree, Medium, latent.**

* In v25 the rule applies only to W16 and D55 bundles.
* Every D55 bundle comes from the registered writer test, which proves in the same process
  (`run_fork_tests.rs:1099-1232`: `prove_run_with_forks`, then `cap::write_bundle`).
* So no recorded bundle is affected.
* It becomes live the first time a D55 capture records a proof made by a CLI child. That is the natural next step after
  `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` flips, because `stack-prove --d55-workers` is a CLI path. Nothing in the bundle
  could show it.
* Fix before any capture of a CLI-made D55 run (FR25-09): the prover records its own backend, and the gate checks
  `writer`.

**W-2 (`enabled()` re-read on every call): agree, Low.**

* The writer test and the six `HL_GPU`-flipping tests are all `#[ignore]`.
* They share a process only under `--ignored` without `--exact`, or `--include-ignored` with more than one thread.
* The recorded bundles were written with `--exact --test-threads=1` and `HL_GPU` unset.
* The gate cannot see it. `gpu::label()` in the README note is computed at write time too, so it is no independent
  witness.
* Fix in Rust: latch the backend per proof, or check the Metal counters before writing `false`.

**G_k recovered rather than read: sound for the privacy question; it is a determination, not a binding.**

* Only SC_FZC depends on G. NL-G and R13-G2 each fail exactly SC_FZC.
* Exactly one value in [17, 24] must close the slot, or R13-3 and NL-1 are false (`d55r13.py:506-520`,
  `d55nl.py:499-501`). A wrong value closes by chance with probability about 1/|F_p²| per candidate.
* G enters only public coefficients (SC_FZC's host term and the Rg top-limb pin). NL-1's structural verdict therefore
  does not depend on its value. The records' G values (20 / 21 / 20 and 19 / 19 / 19) lie inside the band the classifier
  statement already covers.
* What it does not show: that G_k is the statement's `accuracy-gate-layer`. The gate cannot open the public-statement
  digest; the verifier binds that, through the header.
* Accept as is. FR25-16 is the hardening.

**NL-1 S1–S5 only on the seven slots R13 redefines; the 16 others on D33: still valid at D55, as the same argument
accepted for D58, with one unmeasured limit (FR25-17).**

Why D55 does not break it:

* D55 changes neither the slot polynomials nor the masking. `define` is byte-identical to r19b's (the R26 block
  reading).
* Each fork has its own M and its own OS generator. `run_fork.rs:361-384`: L + 1 generators under per-fork domains
  `le64(k) ‖ profile`, none cloned or shared.
* R13 changes only the 16 slots' fold values.

What is measured at D55:

* R13-3 holds 23 / 23 on every fork of all 12 bundles. That ties each of the 16 legacy bodies to the Rust slot
  polynomial at a random point.
* S3 and the mask budget hold at every (N, d) of all 23 slots of every fork (`d55nl.all_slot_pairs`).

The limit:

* S1 (the extension-round premise, the per-variable bound) and S4 / S5 for the 16 legacy bodies were computed by D33
  at T32 TinyLlama only.
* S1 depends on each slot's (main, extension) split, which differs at 8B T128, Shieldstral T256 and TinyLlama T128.
* This is an evidence gap, not a gate bug.

The exact closing run:

* `zk60_native_rg_d55nl.d55_nl1` with `SLOTS7` widened to `range(23)`. `fork_contexts` already takes the legacy ports
  from `T.PORTS`, as it does for slot 3.
* Add the bilinear slots' derived eq point as `r13blocks.check_stage` sets it (`r13blocks.py:237-242`).
* Run it on fork 1 of `d55-r13_8b_t128_h24-s0`, `d55-r13_shield_t256_h24-s0` and `d55-r13_tiny_t128_low-s0`.
* At NL-1's measured 88 s for 21 slot instances (8B), expect about 5 min per bundle, cpu class, under 6 GiB.

**The per-layer own accuracy-base shift path (`sh_s`): no path to a wrong PASS found.**

* The D55 code (`fork_calibrations`, `d55r13.py:427-446`) is a line-for-line copy of the v24 classifier port's
  `stage_facts` (`r13blocks.py:139-156`).
* That port ran on the real Shieldstral T128 capture with own `sh_s` / `sh_ao` / `sh_h` / `cn_a` / `cn_m` clauses on 25
  of 26 blocks, and every block closed 23 / 23 (the round-20 record, `per_stage[*].own_clauses`; D58).
* At D55 the clauses are bound: the stage lines are quoted inside the registered schedule (`d55r13.py:130-131`), whose
  digest is recomputed (`:204-207`).
* Precision is re-derived per fork. It reaches the Rs lookup pin and the SC_SCORE / SC_SZC ports through `R13Ctx`.
* R13-2's plane list does not depend on precision (`r13slots.py:162-166`). No other D55 part reads the calibration
  (grep over the joint, TS, hash and preimage modules).
* Applying a fork's clause wrongly, or ignoring it, breaks those slots, so R13-3 fails closed.
* Residuals: FR25-15. No D55 bundle exercises the path yet; that needs a writer variant with per-layer public blocks.
* Suggested negative control for that bundle: strip fork 1's own clause, recompute the schedule digest, and R13-3 must
  fail on fork 1 only.

**Hash census coverage: the L classes are closed, and I found no other uncovered length class.**

* On the gate's D55 path, every absorb's data length is fixed by the registered shape, except the parameter line. Its
  length moves with:
  * the digits of L;
  * `rows0` at L = 1.
* 076a485f closed that for L ≤ 32 (s25) and for any u64 L by the length lemma.
* The fixed-length inputs:
  * the join's claim lists (one IO claim each);
  * `pb-join-state` (40 B);
  * the fork words (u64, 32 B);
  * the PCS vectors (n + Q per commitment kind);
  * the column digests (rows per commitment kind);
  * the commit-phase and per-fork seed domains (`le64(k)` is fixed-width, `run_fork.rs:378-383`).
* The parameter line's `sh-g/h/z` come from the registered shape's base. If a future profile let the run base vary
  (for example product shift 9 against 10), a new class would appear. The printout lookup is what would catch it,
  which is one more reason FR25-01 matters.

### Q6. Anything else

* The status label "D55-PASS" does not say which optional checks ran (FR25-03, FR25-04).
* The exit code does not tell PASS from DEV-PASS (FR25-14).
* The D55 soundness note's open privacy items are argued in code readings, not tested by this gate: the opening order,
  the L + 1 generators, concurrent read-only access to the boundary mask rows. The joint rank (D55-J) checks only the
  linear model's coordinate classes (ruling R-3). That is a stated limit, not a defect.
* I found no path by which a bundle carrying hidden content in the observations the gate ranks would pass with every
  part true, controls on, the joint rank on, the printout given and a complete pin list. The leak paths I found need a
  wrong input, a skipped check, or a writer that publishes bytes the gate did not rank (FR25-08).

## 4. Experiments (each guarded, light class)

| log | what | result |
|---|---|---|
| `logs/pins.log` | `exp_pins.py` on `pg_bundles_r26/d55-r13_rung_h24-s0/manifest.json` (`789f4548…`), doctored in memory only | honest 75 pins PINS ok; 6 pins PINS ok; 0 pins refused at R13 only by the terminal port's four required files; W16 driver ok with 0 pins |
| `logs/nldir.log` | `exp_nldir.py`: `ZK60_NL_CHECK_DIR` → scratch copies of the two pinned NL files plus a `zk60_native_rg_d55hash.py` | `load_nl` accepts; the driver's next import loads the scratch module; `tool_sha256` shows the staging digest |
| `logs/prefix.log` | `exp_prefix.py`: prefix twins, PINS controls without an object, Metal files unpinned | (a) both W16 prefix twins read, PINS ok; (b) P-1 / P-2 `fires: True` with `no_object`; (c) `proved_on_gpu: false` with no Metal pin is admissible |

The scripts are in `experiments/`, with `make_json.py`, which writes `FREEZE_REVIEW_V25.json`. They were run from the
session scratchpad. `exp_nldir.py` writes only into the directory given as its argument. The other two write nothing.

**Heavy confirmation, not run.** It would turn FR25-01 and FR25-05 into end-to-end records.

1. Copy one rung bundle to scratch (about 47 MB). Edit only `manifest.json`'s `source_pins` down to the six files.
2. Run, with `--other` the s1 bundle, controls on and the joint on:

       env ZK60_D55TS_WORKERS=16 python3 -B staging_v25/scripts/zk60_native_rg_d55.py --bundle <copy> --evidence <dir> --name fr25-pins

   once with `ZK60_S25_W2_PRINTOUT` unset, under the guard's cpu class (about 6 min and 12 GiB at the rung, per
   `records_final`).
3. Predicted: D55-PASS, with `PINS.pins` = 6 and HASH-2 `rust_table.not_compared`.

## 5. What I did not do

* No build, proof, gate run or test-suite run (the heavy lock was held).
* No reading of the Metal device code, `ts_trained.py`, `nl_check.py`, or the v24 rank, mask and preimage internals.
* No edit of any script, test, Rust file, frozen file or the decisions register. No bundle was modified.
