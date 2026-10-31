# Coordinator review: A5 app half (one-load batch adapter), 2026-10-31

Independent reviewer for the coordinator. Scope: the staged app half only
(`integrated_app/proven_media`, `integrated_app.patch`, `mac-portability.patch`,
evidence in `mac-review-3/`). Not in scope: the native batch (`classify-prove-batch`,
which waits for Sol's R15 macOS fix), cryptographic soundness and classifier privacy.
Line numbers refer to `integrated_app/proven_media/*.py` unless a path is given.

## Verdict: GO WITH FIXES (app half)

- **Safety design accepted.** I found no path that publishes a post, or marks a
  category verified, after a failed, timed-out, killed or crash-interrupted prove,
  verify, input-owner or label step. R18-1 is met in the logic: every outcome goes
  through one collector, an unfinished batch is quarantined at queue start-up, and
  `.batch-quarantine/` is never published or downloaded. I found no leak of
  owner-private data in the app paths.
- **Not adoptable as staged.** Three blocking defects make every real batch fail
  closed, and each failure uses up the post's single D45 attempt. The current tests
  miss all three because they simulate the guard record, the guard pin and the host
  identity (B1-B3).
- **Required before the adapter is selected:**
  - B1-B3 and M1-M2, each with a test that uses the real guard record shape and the
    unpatched host identity;
  - a re-run of the five suites.
- **Before the first multi-post run:** M3-M5.
- **Lows:** at Astra's discretion. L3 and L4 should be fixed or written into the
  adoption runbook.

## Findings

| ID | Sev | Location | Failure scenario | Fix |
|---|---|---|---|---|
| **B1** | blocking | `batch_pipeline.py:105-106` (`clean_guard`: `g.get('cmd')==argv`). Guard: `scripts/zk60_resource_guard.py:1083` (`"cmd": command[:8]`), the same in the pinned S9 guard (`git show 9843a82b:scripts/zk60_resource_guard.py`, line 807). | The real guard stores only the first 8 argv elements. Every wrapped command has at least 10 (`/usr/bin/env` plus 3 variables plus the leaf). So after the full prove and every fresh check, `collect_checks` raises "guard ran a different batch/check command". The pipeline then exits 1, the queue quarantines the batch and the post becomes `failed` with `prove_attempted=1`, so it can never be screened again. Probe P1 reproduces this. The integrated tests' fake guard writes the full argv (`test_integrated_batch.py:151`). | Compare against `argv[:8]`. Bind the full argv separately: before Popen, the supervisor writes `logs/<step>.argv.json` (argv and its sha256), and `clean_guard` checks it together with `guard_pid`, `label` and the prefix. Add a test whose guard record comes from the real `terminal()` shape. |
| **B2** | blocking (Mac) | Linux-only identity in production code: `batch_registry.py:24-25` (`/proc/sys/kernel/random/boot_id`), used at `:72` (register), `:88` (terminal check), `batch_supervisor.py:30`, `batch_pipeline.py:153`. Also `os.readlink('/proc/self/ns/pid')` at `batch_supervisor.py:78` and `:117-118`, and `batch_prover.py:109` (`launched.json`). | On macOS (probe P2):<br>• `register_prepared` raises inside its transaction, so no batch can start. The job directory is already prepared, so every queued category then fails with "already prepared".<br>• If any `batch_runs` row exists without a terminal marker, `terminal_known` raises on every tick, and the whole queue, per-category work included, is stuck.<br>• `_run_locked` writes `supervisor-process.json` outside its `try` (`:117-118`), so a supervisor dies without a terminal marker.<br>The tests patch `boot_id` and `readlink` (`test_integrated_batch.py:41-45`, `test_batch_supervisor.py:46-49`). The brief allows simulated identity only if production code does not depend on Linux paths, and this production code does. | Add one host-identity helper that matches the guard (`zk60_resource_guard.py:223-251`): `/proc` boot_id on Linux, `sysctl -n kern.bootsessionuuid` on Darwin, pid namespace `None` on Darwin. Then `guard['boot_id']==self.boot` keeps holding (`batch_supervisor.py:92`). Move the identity writes inside the `try`. Test both platforms without patching. |
| **B3** | blocking | `batch_supervisor.py:23,43-44` pins the guard at `67e9478f…` (Linux S9). The current guard (macOS port) is `ed8b5b38…` (probe P3). | `_guard_argv` refuses the first step (seqgen), so the run is quarantined and the post burned (see M2). The supervisor tests patch `_guard_argv` (`test_batch_supervisor.py:61`), so the pin is never exercised. | First check the lifecycle contract against the Darwin guard: watchdog-only enforcement, `boot_id`=`kern.bootsessionuuid`, `pid_ns` None, terminate-and-drain on SIGTERM, record fields. Then re-pin. Check the pin in `start_batch`, before `register_prepared`. |
| **M1** | medium (required) | `batch_supervisor.py:55-57` raises on a coordinator HOLD. Compare `tools/classifier_pipeline.py:55-59`, which waits. | A HOLD posted while `prove-batch` runs (as on 2026-10-30) makes the next step raise, so a fully proved batch of up to about 2.8 h is quarantined and the post burned. The per-category pipeline pauses before each step instead. | Wait while held, as the per-category pipeline does: `held` progress state, bounded by the existing admission deadline. Never raise mid-batch because of a HOLD. |
| **M2** | medium (required) | `batch_registry.py:75` sets `prove_attempted=1` at registration, and `_failed` (`:109`) keeps it. Compare `jobs.py:53-63`. | A refusal before any native step ran consumes the one attempt. Examples: guard pin (B3), HOLD (M1), guard admission refusal after the 7,200 s wait, boot mismatch (`batch_pipeline.py:153`), source-pin drift in `load_spec`, a missing interpreter (M5). The per-category path leaves such an item re-submittable ("re-submittable only if nothing ran"). | Record `native_started` (seqgen or prove guard `child_wall_seconds`>0, or `.log` non-empty), the way `prove_attempted(j)` does. If nothing ran, fail with `prove_attempted=0` but still quarantine. |
| **M3** | medium | `batch_registry.py:192-200`; `jobs.py:359-360`; tick order in `jobs.py:156-162`. | A permanent publication error (for example a refused bundle) raises out of every tick (probe P4, 4/4 ticks):<br>• `publisher.tick()` is never reached, so no anchor batch closes;<br>• no other post ever launches;<br>• each 2 s tick re-runs `collect_checks`, re-hashing every receipt (about 7.6-18.7 GB for 9-22 jobs);<br>• 2 of the 3 category leaves are already in the public ledger while the post stays `screening`. Nothing is shown as complete, but the queue is stuck with no terminal state. | For `verified` rows, publish from the committed records. Re-hash once before publication, not on every tick. Retry with backoff. Never raise out of `tick`, and run `publisher.tick()` regardless. After N failures, park the row and alert the operator, keeping the post unpublished. |
| **M4** | medium | `storage_policy.py:14-29` (`is_relative_to`) and `:34-36,46-48` (repo and overlap checks). | macOS APFS is case-insensitive, but the checks compare paths case-sensitively:<br>• `/private/TMP/a`, `/Private/tmp/a` and `/private/var/Folders/a` are accepted as durable;<br>• `PM_PRIVATE_DIR=/Users/victorrielly/intelligenceregulation/x` is accepted as outside the repository (`samefile` is True, `is_relative_to` is False), so the database, `app.key` and the signing key could sit in the git tree;<br>• the public/private overlap check has the same gap;<br>• `/var/run` (→ `/private/var/run`) is not covered.<br>Lexical, resolved and symlink cases all work. Only operator misconfiguration can trigger this. | Compare by inode ancestry: walk `resolved` and its parents with `os.path.samefile` against each root and the repo (or canonicalize the deepest existing ancestor with `fcntl F_GETPATH`). Add `/private/var/run`. Add case-variant tests. |
| **M5** | medium (Mac) | `config.py:54` `SYSTEM_PYTHON="/usr/bin/python3"`, used by seqgen at `batch_pipeline.py:79`. | On this Mac that interpreter is the Command Line Tools Python 3.9.6 without numpy (checked). The activation writer fails at step 1, and the post is burned (M2). This affects the per-category path too. | Make it configurable. Pin version and numpy presence, and check them in `start_batch` before registration. |
| L1 | low | `batch_supervisor.py:100-145` | The supervisor is SIGKILLed while its guard and native child live on, and someone runs `python -m proven_media.batch_pipeline JOB` by hand. The flock is free and the seqgen artefacts exist, so the step raises, `on_terminal(1)` quarantines against a live prover, and the run writes `children_reaped: True` for children it never owned. Operator action only; the queue never relaunches. | `_run_locked` refuses, with no collector and no terminal marker, whenever `supervisor-process.json` or any `logs/*` already exists. |
| L2 | low | `batch_registry.py:175-185` | The verified commit does not re-check `batch_runs.status`. With two app instances (there is no instance lock), one can quarantine while the other commits `done` records and `verified`. It ends fail-closed on the next tick, but `done` rows point at moved receipts in the meantime. | `UPDATE … WHERE post_id=? AND status IN ('active','unverified','verified')` and check rowcount. Add an app-instance flock in `PRIVATE_DIR`. |
| L3 | low | `batch_queue_gate.py:38-39` (scope built outside the `try`); `batch_cleanup.py:31-34`; `app.py:569-607` | Crash between `finalize` and `finished`, then the author deletes the post (`rmtree` of the job directory), then a reboot: `CleanupScope` raises on every tick and the queue is stuck for good (probe P5). Separately, author delete never removes `.batch-quarantine/<pid>-*`, although the message says "receipt erased". | Treat rows of deleted posts as terminal. Refuse delete while a row is not finished or quarantined. Remove the quarantine directory on delete. |
| L4 | low (runbook) | `batch_prover.py:42-46`; `batch_registry.py:65-67` | Switching the factory to the batch prover while per-category jobs are running or queued: `collect` raises for running per-category jobs, and partly done posts cannot register. Both end as failed, burned posts. | Drain the queue before the switch, or delegate `collect` and `start` for non-batch job directories. |
| L5 | low | `batch_pipeline.py:68`; `batch_prover.py:55` | Any truthy `large_batch_window` passes the over-10 GB D46 check. | Require a recorded announcement id and a validity window. |
| L6 | low | `config.py:51-52`; `tokenizer.py:17-22` | The TinyLlama tokenizer path can now be overridden from the environment, with no digest check (stub mode only). | Pin `9e556afd…`, as Tekken is pinned (`shieldstral_text.py:16,25-27`). |
| L7 | low | `tests/native_fixtures.py`; setUp in `test_shieldstral_prover.py` and `test_real_publication_verifier.py` | These suites now always swap in a fixture binary, so on the native host they no longer check the real r16b pin. This is test-only; production `Deployment.validate` still hashes the real binary. | Use the real binary when it is present and matches its pin, the fixture otherwise, and log which was used. |
| L8 | nit | `storage_policy.py:18` | `tempfile.gettempdir()` probes with a write at import, and can fall back to the cwd, which then counts as volatile (fail-closed). | Only add `TMPDIR` if it is set. |

## Answers to the five questions

### 1. Fail-closed and partial batches (R18-1)

No fail-open path found. How each case is handled:

- **Transport never accepts.** `collect_batch_result` and `split_unverified_log` return only `unverified` (`batch_request.py:174-198, 268-276`). Any exception there quarantines the batch (`:193-198`).
- **Terminal outcomes all go through one collector.** Normal, failed and post-reboot outcomes share `recover_batch` (`batch_pipeline.py:144-160`, `batch_registry.py:141-146`). Missing logs, a missing `.done` or missing guard evidence count as failure (`batch_queue_gate.py:67-76`). A completed quarantine cannot be undone (`:53-55`).
- **Live or uncertain batches block the queue.** If the batch is live or uncertain and the boot is the same, the queue blocks (`batch_registry.py:83-95, 132-135`). A missing guard cleanup proof writes no terminal marker (`batch_supervisor.py:86-95, 133`).
- **Acceptance needs every step.**
  - Every step must have a clean guard record (`batch_pipeline.py:97-110`).
  - Fresh verify and input-owner checks are parsed per job, and the whole-category label per category (`:113-139`).
  - Receipts are re-hashed and must equal `batch-verified.json`, and the content ids are re-encoded from the post text (`batch_prover.py:124-131`).
  - Full coverage and aggregate checks run (`batch_prover.py:161`, `batch_registry.py:165-168`).
- **Categories are committed together.** Every category record is committed in one transaction (`batch_registry.py:175-188`). A failed commit is atomic, as Astra's test shows.
- **Partial batches are never published as complete.** A post becomes `published` only when every category has an anchor (`jobs.py:359-360`). Otherwise it stays `screening` and is retried, or it is quarantined and set `failed` (`batch_registry.py:192-198`).
- **Residual issues:**
  - Single category leaves can reach the public ledger before the post does (M3).
  - Several fail-closed outcomes are destructive: they use up the D45 attempt although nothing ran (B1, B3, M1, M2, M5).

### 2. Owner-private data

No leak found:

- **Openings.** Owner directories are refused inside a receipt parent or a git tree (`batch_request.py:57-61`). On failure they move to the private `job/failed-batch-owners` (`batch_cleanup.py:81, 88-97`), never to the public root.
- **Post text.** The content goes only into a 0600 `content.ids` (`batch_request.py:96`; `provers.py:78-81`), never onto a command line (`batch_request.py:126-127`).
- **Messages.** A failed post shows only "Could not be verified." (`app.py:239-240`). Queue and DB errors are fixed strings (`batch_registry.py:106-110`). Supervisor errors stay in the 0700 job directory under `umask 077` (`batch_pipeline.py:164`).
- **Quarantine.** `.batch-quarantine` is 0700 and owner-checked (`batch_cleanup.py:46-52`). It is refused at CAS ingest, local and testnet publish and bundle download (`quarantine_paths.py`; `publisher.py` put_file and publish; `testnet_publisher.py` publish; `app.py:691-711`).
- **Guard records.** The guard's registry and history hold only argv prefixes: paths, never content.
- **Temporary directories.** No batch code writes private data under a temporary root.
- **macOS temporary-root rejection.** The lexical case works (`/tmp`, `/private/tmp`, `/var/folders` and `$TMPDIR`, each also in resolved form), and so do the resolved case and both symlink cases. My scratch mirror sits under `/private/tmp`, and the app correctly refused it as a durable root (see evidence). Case-variant gap: M4.
- **Pre-existing, not new:** activations and openings stay in the private job directory after success; author delete misses quarantined receipts (L3).

### 3. Concurrency and identity

- **One claim per post.** It is atomic (`BEGIN IMMEDIATE`, post_id primary key, unique `launch_id`), and requires every category still queued and none attempted (`batch_registry.py:59-79`).
- **No re-preparation.** The job directory is created exclusively and the outputs must not exist (`batch_request.py:80, 91-94`).
- **No second supervisor and no step retry.** The supervisor takes an exclusive non-blocking flock, and step artefacts block a retry (`batch_supervisor.py:62-63, 101-106`).
- **Terminal markers.** A marker is bound to `launch_id` and boot (`batch_registry.py:90-95`).
- **Cleanup scope.** The scope comes from the database, not the child, and the cleanup file is cross-checked against it (`batch_queue_gate.py:38-41, 57-58`).
- **Content and post ids.** Changed content is refused: ids are re-encoded and the screening claim checked (`batch_prover.py:127-128`; `store.py:143-149`). Post ids are 128-bit random and never reused, because delete keeps the row (`app.py:385, 604`).
- **Gaps:** a manual stale relaunch (L1), two app instances (L2), and delete in the crash window (L3).

### 4. Mac portability changes

- **Pins.** `mac-portability.patch` equals the working-tree diff plus `native_fixtures.py`. Production pins are unchanged: r16b `BINARY_SHA`, `PROFILE_SHA`, `IDENTITY`, `WRITER_SHA` (writer re-hashed, `8d6ce81b…`) and `POLICIES_SHA`.
- **Tokenizers.** The Tekken override keeps its digest check. The TinyLlama override has none (L6).
- **Storage policy.** The macOS temporary roots are a real strengthening, apart from the case gap (M4).
- **Tests.** The fixture binary is test-only, but it drops real-pin coverage on the native host (L7).
- **Guard identity.** Production batch code still relies on Linux paths (B2) and on a stale guard pin (B3). The simulated Linux identity is therefore **not** acceptable as it stands.

### 5. Other blockers for the app-half go

- B1 (guard `cmd` truncation) is platform-independent: it would also fail every real batch on Linux.
- The seqgen interpreter fails on the Mac (M5).
- Recovery from a permanent publication error is missing (M3).

## Evidence (all in the reviewer's scratch; no repository file was changed)

- **Pins.** All five `base` and fourteen `candidate` hashes in `integrated_app_sources.json` match.
  - `integrated_app.patch` regenerates byte-for-byte from base plus candidate.
  - The top-level helper modules differ from the integrated copies only in their import lines.
  - All 99 `mac-review-3/evidence.json` source pins (before and after) match the current files.
- **Suites.** I re-ran Astra's runner against a scratch mirror of the repository, with real copies of the app and the packet and the rest symlinked read-only. I used the same venv and tokenizers (hashes checked by the runner) and `PYTHONDONTWRITEBYTECODE`.
  - batch-lifecycle 65/0, publication 6/0, integrated-batch 17/0.
  - app and staged-app: 200 run, 196 pass. The 4 failures are all in `test_storage_policy`: the mirror lives under `/private/tmp`, so "public proof root must use durable storage". That is the macOS rejection working, and it does not contradict Astra's 200/0 from a durable checkout.
- **Probes** (`test_probe_review.py`, subclassing Astra's integrated fixture; output verbatim):
  - P1: pipeline exit 1; "guard ran a different batch/check command"; post `failed`, `prove_attempted` 1. The only change from the passing whole-pipeline test is the guard record's real `cmd[:8]`.
  - P2: darwin; `/proc` boot_id missing.
  - P3: pinned `67e9478f5551`, current `ed8b5b38660c`.
  - P4: 4/4 ticks raise; first post `screening` with 2 anchors; the second post's jobs stay `queued`; `publisher.tick` calls 0.
  - P5: after the simulated reboot, every tick raises "cleanup roots must be existing canonical directories".
- **Host checks.** `/usr/bin/python3` is 3.9.6, with no numpy. Case-variant paths go through `durable_path` (M4 table).
- **Repository unchanged.** `git status --porcelain --untracked-files=all` was identical before and after my runs.
- **Scratch files:**
  - mirror and probe: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/review/repo/results/zk60_astra_20261026/a5_batch_candidate/test_probe_review.py`
  - probe log: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/review/probe.log`
  - suite logs: `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/review/ev1/`

Not run: the app server, any native prover or verifier, the guard, any publication or transaction. This is not a privacy acceptance, not a native-batch result and not a timing claim.
