# CL11 — the RTX 5090 qualification and measurement campaign (prepared, not run)

Task: `zk60_claude_tasks.json` CL11 (`queued_prepare_only`). Tool:
`scripts/hashline_cl_5090_preflight.py` (tests in
`tests/test_hashline_cl_5090_preflight.py`). Companion:
`BLACKWELL_5090_RUNBOOK.md` (what must be true before the first number),
`MEASUREMENT_PROTOCOL.md` (the p50/p95 statistic), and the existing collector
`scripts/hashline_benchmark.py` (the >= 20 warm-run harness this campaign
reuses; it creates no new clock).

**What this page does NOT do.** It does not rent or buy hardware, install a
driver or a toolkit, cap a card, launch a proof, or make a target-eligible
claim. Every command in §3 runs only after the preflight says `go`, and the
FFN-only coverage that exists today keeps every number labelled
*diagnostic* — a target-eligible claim needs full coverage, decoded
verification and the security gates, none of which this page supplies.

---

## 1. The preflight — fail-closed, one JSON report, exit 0 only on `go`

```
python3 scripts/hashline_cl_5090_preflight.py \
  --repo <checkout> --binary <checkout>/hashline/target-gpu/release/hashline \
  --export <v3-widened export dir> --run-manifest <floors scratch>/manifest.json \
  --layers 32 --tokens 512 --threads 2 --memory-budget-mib <MiB> --scratch <dir> \
  --privacy P1 --require-cc 12.0 --emit-plan --out <new file>
```

(`--run-manifest` is the CL13 manifest `results/cl1_floors.sh` writes; see §7.
`--floors-log` still parses but is a deprecated hint that cannot pass a check.)

Fourteen checks; each carries its evidence and, when it fails, the reason.
Any failure is `go: false` (exit 3). `--facts-json` replaces every probe with
a recorded fact set (the unit tests and dry runs use it), so the checks
themselves are tested without a device.

| check | passes when | what it refuses |
|---|---|---|
| `device_present` | exactly one selected, named GPU | none, or two |
| `compute_capability` | in the supported table (8.9 / 9.0 / 10.0 / 12.0) AND an `arch_str` arm exists in `gpu/cuda.rs` AND matches `--require-cc` | an unsupported part, a part that would JIT generic PTX, the wrong part |
| `driver_version` | >= 570 on Blackwell (>= 10.0) | the 566 branch, which cannot load NVRTC 12.8's PTX |
| `nvrtc_toolkit` | >= 12.8 on Blackwell | the 12.1 NVRTC that has no sm_120 codegen |
| `cudarc_feature` | `cuda-12080` on Blackwell | `cuda-12040`, the binding for the old driver API |
| `device_idle` | <= 1,024 MiB used and no compute processes | a card another job has not released (WSL returns VRAM late) |
| `host_memory` | MemAvailable >= the band for the width and `--coverage`: 4 GiB narrow, 16 GiB FFN-only at d >= 4096, 64 GiB full coverage (runbook §3); override `--host-min-gib` | the 15 GB box for the 8B pass (13.95 GiB available on the dry run) |
| `host_idle` | heavy lock free, 1-min load <= half the CPUs | a box that is proving or building |
| `source_identity` | HEAD recorded, tracked tree clean | uncommitted source |
| `binary_identity` | binary exists, is the gpu-cuda build, newer than every source file; sha256 PRESENT and equal to the run manifest's GPU-binary digest (CL13) | a stale binary; an absent or unrelated digest |
| `shape_supported` | v3-widened sidecar covers the layers; tokens a power of two | an export that cannot serve the request |
| `planner_margin` | chunked W component (CL3 planner) + measured reserve <= 80% of nominal VRAM, and <= `--memory-budget-mib` when given | a shape the card cannot hold; nominal VRAM is never treated as free |
| `verified_artifact` | a CL13 run manifest the gates validator accepts (complete, every case green, controls present, production suite) whose HEAD is the current HEAD and whose GPU binary is this one (§7) | a binary whose proofs have not been byte-gated; another source or binary; a green log alone |
| `coverage_eligibility` | `--claim diagnostic`, or full coverage RECORDED with decoded full-relation verification and fresh randomness | a target claim from FFN-only coverage, from the flag alone, or from a seeded row |

The three Blackwell version checks bind ONLY for compute >= 10.0. On the
4070 (8.9, driver 566.14, NVRTC 12.1, `cuda-12040`) they pass, which is what
lets the same preflight guard the laptop's diagnostic runs today.

**The order is the runbook's, enforced.** §3a of the runbook established by
experiment that NVRTC 12.8 ahead of the driver takes the GPU away (the binary
falls back to the CPU and still prints ACCEPT). The preflight will not say
`go` on a Blackwell part until driver, then NVRTC, then the `cudarc` feature
are all in place — and it reads all three from the box, not from a checklist.

`planner_margin`'s reserve is a laptop-measured constant: at Mistral width,
chunk 128, FFN-only, the whole-layer peak was 5,182 MB against a chunked W
component of 1,563 MiB (`ZK60_CLAUDE_GPU.md` rung 5; reconfirmed by the CL6
sweep), so the non-commit residency is 3,620 MB. It is explicit
(`--reserve-mib`) and it is NOT a model of the 5090 or of the pending
attention state (`ZK60_CLAUDE_PENDING_GPU.md`).

---

## 2. Dry run on the laptop (2026-09-06)

Run against this laptop (RTX 4070, driver 566.14, NVRTC 12.1, `cuda-12040`,
one Mistral layer requested, `--claim diagnostic`, no `--require-cc`): exit 3,
NOT go. The three Blackwell version gates pass (they bind only for compute
>= 10.0), `planner_margin` passes with 5,182.5 MiB needed against 6,550.4
allowed — the laptop's measured 5,182 MB peak, reproduced — and three checks
refuse: `host_memory` (13.95 GiB available < 16 GiB), `source_identity`
(seven dirty tracked files mid-session) and `verified_artifact` (the green
`cl4_floors.log` predates the current binary; the gates must be rerun on it).
The unit tests do not depend on the live box.

---

## 3. The ladder — byte gates before timings, one job at a time

Emitted by `--emit-plan` with exact commands. Every heavy stage is a DETACHED
job with a `.done` marker (the no-hangup protocol). Stages 0-2 take
`/tmp/zk-heavy.lock` in their wrapper; stages 3-5 do NOT — the collector
takes the same lock INSIDE `run_samples`, and an outer `flock` on it
deadlocks (its own docstring says so; the CL11 tests pin the distinction).
NO stage starts until `nvidia-smi` reads idle: the 2026-09-04 freezes were a
second GPU pass started against a card the first had not released.

| stage | what | gate before the next stage |
|---|---|---|
| 0 | `results/cl1_floors.sh` on the new box (portable flags, `--threads 2`, the suite's frozen 12x512 shape) | 12/12 byte gates at full SHA-256, `gpu: ON` in every GPU gate, the oracle suite's executed-case count equal to the suite's, the missing-feature refusals, the cache cases — and the run MANIFEST green (§7), which is what the preflight then binds to; a digest that moves on new hardware is a codegen bug, not a hardware finding (runbook §4) |
| 1 | single Mistral layer, P1 and P3, GPU | digests equal the laptop's `b5da6c38..` / `190e85a1..` (CL1 rung 4); CPU/GPU/device-to-device byte identity at real width |
| 2 | the card-size prediction (runbook §6): `pass 32 512 --zk --seed 1 --profile v3`, GPU, detached | layers 1-31 no slower than layer 0 (the laptop's 8,585 MB spill gone); VRAM peak < total. Cheapest thing the card settles; ONE run |
| 3 | P1 8B prefill: `hashline_benchmark.py run --privacy P1 --device gpu --warm-runs 20` | `measurement_eligible: true`; p50/p95 nearest-rank; proof-ready clock |
| 4 | P3 8B prefill, the same, as a SEPARATE job after an idle check | as stage 3; P3 recommits the weights every run, so warm = cold for W |
| 5 | comparability row: stage 3 again at `nvidia-smi -pl 450` (operator), clearly labelled | continuity with every row measured before the <= 600 W ruling; not for the contract |
| 6 | the one-GPU overlap (§4) | NOT RUNNABLE in this repository yet |

Stage 2 must not be skipped or folded into stage 3: it is the only run that
tests the card, not the code, and the runbook predicts ~1.9x on the private
8B pass from it alone.

---

## 4. The clocks — generation, proof-ready, proof-lag, and the overlap

60 tokens/s is a GENERATION claim. Everything measurable here today is
PREFILL: the collector's `proof_ready_s` runs from exported-input loading
through witness computation to the serialized proof, over T=512 prefill rows,
before in-memory verification; `tokens / p95(proof_ready_s)` is its
"rows per second" figure and the collector refuses to call it more than that.

For the campaign the three clocks are defined now so they are not improvised
on the day:

- **generation clock** — tokens emitted per second by the inference engine
  alone on the card, no proving. Not available: there is no generation
  harness in this repository; tokens are prefill rows.
- **proof-ready clock** — the collector's `proof_ready_s` per proof, p95 over
  >= 20 warm runs, cold reported separately.
- **proof-lag** — for a token (or a window of tokens) the time from its
  emission to its proof being serialized: proof-ready minus generation, on the
  same card, in the same session.

**The overlap protocol**, once a generation harness exists: (a) proving alone
on an idle card (stages 3-4: the upper bound); (b) inference alone; (c) both
on the one GPU concurrently, with proof-ready and generation clocks collected
in the same session and proof-lag derived. The deployable number is (c)'s
proof-ready p95, not (a)'s. Nothing measured under (a) may be reported as a
tokens/s-with-proof figure.

---

## 5. The statistic and the labels

- >= 20 warm runs, p95 nearest-rank (`sorted[ceil(0.95 n)]`), p50 alongside,
  min/max printed, cold kept out of the warm set — `MEASUREMENT_PROTOCOL.md`
  §1, as `hashline_benchmark.py summarize` already implements.
- Labels on every row: `[5090-BOX] [QUIET] [MEASURED]` and *diagnostic* until
  coverage is full.
- The collector rejects a seeded row, a reported CPU fallback, a proof whose
  written digest differs from the log, and a shape that differs from the
  manifest; it cannot detect a SILENT fallback, so `gpu: ON` in every log is
  checked by the preflight's artifact gate and must be grepped again by
  whoever reads the numbers.

---

## 6. Limits, stated plainly

- Nothing here has run on a 5090. The tool, the ladder and the clocks are
  prepared; the numbers are not.
- The qualification evidence (§7) is RECORDED provenance: a manifest the
  runner wrote and a validator recomputed. It is not independent privacy or
  security certification, and nothing in it makes FFN-only coverage more
  than diagnostic.

---

## 7. CL13 — qualification evidence is a run manifest; the runner is portable (2026-09-07)

Codex's round-9 review (`ZK60_ROUND9_REVIEW.md`, evidence
`results/zk60_round9_review.json`) reproduced four acceptances of the CL11
preflight against a passing facts file: the binary digest **absent**, an
**unrelated** binary digest, **zero** expected/executed floor cases, and
`--coverage full --claim target` with nothing behind the flag — all four
returned `go` with no failed check. `verified_artifact` read a green
substring, a case count printed by the same script, a `.done` marker and an
mtime; `binary_identity` never looked at the digest; `coverage_eligibility`
trusted the flag. On the runner side: the parser self-test ran AFTER the
hardware oracle, `--threads 8` was hardcoded three times, the checkout,
export, CUDA and scratch paths were fixed, and `ORACLE_MIN_CASES=20` was a
floor that would not have noticed removed cases in a 49-case suite.

### 7.1 What replaced it

**`scripts/hashline_cl_gpu_gates.py`** (new; stdlib, CPU-only) owns three
things, tested in `tests/test_hashline_cl_gpu_gates.py`:

- the **versioned suite definition** — suite version 1 is the CL1 floors:
  both builds, the CPU crate tests, the device oracle (`zk60_gpu_commit.rs`,
  **49 executed cases**, the count at 82314a1 and unchanged through ac5ff0f),
  the two missing-feature controls, the 12 byte gates ({v2, v3, zk, zkv3} x
  {cpu, gpu, gpu-zkchunk}) with their frozen full SHA-256 and exact length,
  and three separate-process cache cases modelled on `zk60_gpu_cache.rs`
  (`cache_cold_zkv3`, `cache_warm_zkv3` with `hits > 0` in the prover's
  `wcache ...: hits N | misses M` report line, `cache_p3_refusal`: exit 2,
  `REFUSED: --wcache with --p3.` first, no proof). The oracle's expected
  count is part of the version: a test file that gains or loses cases must
  cut a new version or the gate goes red. Version 0 is a synthetic
  self-check suite (tiny fixed strings stand in for proofs); it is never
  production evidence and the preflight refuses it.
- the **run manifest** — source identity (HEAD, branch, dirty count, the
  dirty-delta sha256 under `hashline/`, which must be the empty diff),
  build configuration (features, target dirs, `CARGO_BUILD_JOBS`,
  `RAYON_NUM_THREADS`, prover threads, shape), CPU and GPU binary sha256 +
  size + path, device identity (the oracle's `gpu: ON — ...` label and the
  `nvidia-smi` name/driver line), and one record per case: argv, exit,
  verdict, `gpu: ON`, produced proof sha256 + length against the frozen
  expectation, retained-log path + sha256, start/end timestamps, the binary
  digest the case ran. `start` before each case and `record` after; a case
  started and never recorded is an incomplete manifest.
- the **validator** — refuses missing / duplicate / unexpected case ids, a
  missing negative control, a HEAD or GPU-binary digest that differs from
  the one supplied (the preflight supplies the current HEAD and the digest
  of the binary in hand), a device label that differs between the oracle and
  a GPU case, any nonzero exit (or a control that exited 0), a non-ACCEPT
  verdict on a proving case, a GPU-labelled case without `gpu: ON`, a digest
  or length off the frozen expectation, zero (or off-by-one) oracle cases, a
  non-empty source delta, a coverage claim the suite does not cover, a
  non-frozen shape (`no_frozen_expectation`), an unfinalized manifest, and a
  stored verdict that disagrees with the recomputed one (verdicts are
  computed, never written). A complete supported diagnostic manifest passes.

**`results/cl1_floors.sh`** now: runs the helper's self-test and the
quoted-JSON shell expansion check FIRST (a helper that does not run stops the
script before any build); takes repository (from its own location), export
dirs, CUDA paths, scratch, `CUDA_VISIBLE_DEVICES` and threads as flags/env
with the archived values as defaults; **prover `--threads`,
`CARGO_BUILD_JOBS` and `RAYON_NUM_THREADS` all default to 2**; propagates
`--layers/--tokens` (default `12 512`) into every prover command and says in
its usage that any other shape has no frozen expectation and cannot be
green; records every step through `init` / `binaries` / `start` / `record`
/ `finalize`; and has `--dry-run`, which prints every command fully resolved
and `printf %q`-quoted, runs nothing heavy and writes nothing under the
scratch dir. The outer heavy lock is the launcher's; the script takes
`/tmp/zk-build.lock` inside each cargo step (never wrap it in the build
lock). The tests exercise `bash -n` and `--dry-run` on paths with spaces:
95 commands, 15 prover invocations at `--threads 2`, self-test before build
before tests before oracle before controls before gates before cache before
finalize; a missing or broken helper exits 1 with no build emitted.

**`scripts/hashline_cl_5090_preflight.py`**: `--run-manifest PATH`.
`verified_artifact` = the validator accepts the manifest (production suite)
AND its HEAD equals the git fact AND its GPU-binary sha256 equals the binary
in hand; `--floors-log` is a deprecated hint recorded in the evidence that
can never pass the check. `binary_identity` also requires a present digest
equal to the manifest's GPU-binary digest. `coverage_eligibility` requires
RECORDED full coverage and decoded full-relation verification for a target
claim; no current runner records either, so `--coverage full --claim target`
refuses by construction. `--emit-plan` shlex-quotes every path, carries the
requested `--layers/--tokens`, `--threads` (default 2) and the memory lever
`HL_GPU_CHUNK_ROWS=<chunk_rows>` in every command, records
`memory_budget_mib` (`--memory-budget-mib`, default the planner's allowance;
`planner_margin` refuses a need above it) on every heavy stage, and takes
the scratch dir from `--scratch` and the checkout from `--repo`. Two stages
have a shape by definition and say so: stage 0 runs the floors at the
suite's frozen 12x512 (the byte expectations exist only there), stage 1
the one-layer parity gate (`--parity-layers`).

### 7.2 The four probes, and what else the tests pin

| probe (round 9) | now | test |
|---|---|---|
| absent binary digest | `binary_identity` + `verified_artifact` refuse | `test_absent_binary_digest_refuses` |
| unrelated binary digest | both refuse; the validator names the digest in hand | `test_unrelated_binary_digest_refuses` |
| zero expected / executed cases | `verified_artifact` refuses (`missing case ...` / `zero-case`) | `test_zero_expected_cases_refuses`, `test_zero_executed_oracle_cases_refuses` |
| flag-only full/target | `coverage_eligibility` refuses: "the flag cannot supply coverage" | `test_flag_only_full_target_is_refused` |

Also pinned: HEAD mismatch, manifest-binary mismatch, incomplete and
unfinalized manifests, a missing control, a failed case, the synthetic suite
and a non-frozen shape all refuse; the ready box with a valid manifest is
still `go` for a diagnostic claim; the parser regression (valid JSON, empty,
missing fields, the former `${SUMMARY:-{}}` extra brace through a real
`bash -c`, and the count as the suite's rather than a floor); the
record/finalize CLI round trip over synthetic logs and proof files.

Fixtures whose meaning changed: `test_target_claim_with_full_coverage_and_no_seed_is_go`
became `test_flag_only_full_target_is_refused`; a missing git fact now also
fails `verified_artifact` (nothing to bind the manifest to); a missing
manifest fails `binary_identity` too (no recorded digest to bind against);
the floors-log fixtures are deprecated-hint fixtures.

### 7.3 Not done here

No build, no prover, no GPU job and no real floors run were executed for
CL13 — the runner was exercised by `bash -n` and `--dry-run` only. CL17
produces the first real manifest from the combined source; until then no
manifest exists and the preflight refuses `verified_artifact` on every box,
which is the intended state. The manifest validator reads the manifest
document; it does not re-hash the retained logs or re-derive the proofs (the
`record` step did, and stored the hashes). If `zk60_gpu_commit.rs` changes
its case set (CL15 adds the empty-query boundary), the oracle count moves and
suite version 2 must record the new count. **Done in the same round (CL13 follow-up, after CL15 `6dce8a9`): suite version 2 exists and is the default — identical to v1 except the oracle expects 141 executed cases (31 tests; `results/cl15_oracle_gpu.log`). v1 keeps 82314a1's 49 so the archived round-7 run stays describable.**
- The reserve in `planner_margin` is a laptop measurement at one shape and
  one chunk height; the pending attention/FFN states are not implemented and
  are not in it.
- The generation and proof-lag clocks cannot be collected until a generation
  harness exists; stage 6 is a definition, not a command.
- FFN-only coverage keeps every result diagnostic; the preflight refuses a
  target claim on it by construction.

## 8. CL21 — the extracted core is in the qualification provenance (2026-09-08, round 12)

`hashline/Cargo.toml` line 26: `zkp-core = { path = "../zkp-core" }`. The
core Codex extracted in round 11 (`c8a342f`) is a build input of every
binary the floors gate, and both `Cargo.lock` files pin what those builds
resolve. Round 11's outer validator
(`results/zk60_round11_evidence/validate.py`) hashed both crates and ran the
core's tests and example around the floors; the standalone manifest §7
defines still identified `hashline/` alone (HEAD + the delta under
`hashline/`), so a checkout with an edited or absent `zkp-core/` could have
produced a manifest the preflight accepted. CL21 (`d4f0758` on `zk60-cl1`)
closes that: the identity covers both crates and both lockfiles, the
validator refuses a dirty or missing core, the preflight binds the recorded
identity to the tree in hand, and suite version 4 gates the core's own tests
and example with tied expectations. Archived v1–v3 meanings are preserved.

### 8.1 The identity (manifest schema 2; schema-1 manifests still read)

`source` keeps `head`, `branch`, `dirty_tracked_count`, `dirty_delta_sha256`
(the hashline delta, unchanged in meaning) and gains:

| field | what it is | read by |
|---|---|---|
| `source.crates.hashline.tree`, `.zkp_core.tree` | `git rev-parse HEAD:<crate>` — the crate's tree id at HEAD | `probe_source_identity` (gates module) |
| `source.crates.<crate>.dirty_delta_sha256` | sha256 of `git diff HEAD -- <crate>` (bytes, exactly as the runner's `\| sha256sum`); empty = `e3b0c442..` | same |
| `source.crates.<crate>.present` (+ `manifest`, `src`, `example` for the core) | `Cargo.toml` exists; for the core also `src/` and `examples/public_sumcheck.rs` | same |
| `source.lockfiles.<crate>.{path, sha256, size}` | each `Cargo.lock` as it is in the working tree — what `--locked` builds against | same |
| `build.repo` | the checkout the identity was read from | `init --repo` |

The runner passes `init --repo <checkout>`; the helper probes the identity
itself and cross-checks the runner's `--head` / `--dirty-delta-sha256`
against what it reads (a disagreement is "the checkout moved", exit 2).
`source-identity --repo` prints the same document; `finalize --repo` and
`validate --repo` re-probe and BIND (`expect_trees` / `expect_lockfiles` in
the API): a recorded tree id or lockfile hash that differs from the tree in
hand is a reason, and a manifest that records none "cannot be bound". The
validator's rules whenever the block is recorded: both crates present, both
tree ids present, both deltas empty, both lockfile identities present, the
top-level hashline delta equal to the crate's. When it is absent: a v1–v3
manifest validates under its own version (the round-11 manifest at
`results/zk60_round11_evidence/floors/manifest.json` does, unbound); a v4
manifest refuses ("requires the recorded source identity").

### 8.2 Suite version 4 (the default; v0 mirrors it)

v3 plus two cases, inserted after `cargo_test_cpu`, both under the build
lock, both `--locked --offline` (cargo refuses rather than rewrites the
lockfile the manifest hashed; the registry is not part of the identity, the
lockfile is):

| case | command (as emitted, quoted) | expectation (the suite's) | established |
|---|---|---|---|
| `core_tests` | `env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 flock /tmp/zk-build.lock cargo test --release --locked --offline --manifest-path <repo>/zkp-core/Cargo.toml -- --test-threads=2` | exit 0; **19 passed / 0 failed / 0 ignored** summed over every `test result:` line, every line `ok`; argv names `zkp-core/Cargo.toml` and carries `--locked` | `results/zk60_round11_evidence/core_tests.log` at `c8a342f`: field 5, merkle 1, mle 4, ntt 2, rng 2, sumcheck 4, transcript 1 (the example's zero-test binary and the doc-test section add 0) |
| `core_example` | `... cargo run --release --locked --offline --manifest-path <repo>/zkp-core/Cargo.toml --example public_sumcheck` | exit 0; the whole line `public dot-product sumcheck verified; altered round refused (primitive example, no privacy claim)`; argv carries `--example public_sumcheck`, the core manifest, `--locked` | `core_example.log` at `c8a342f` |

The example binary's sha256/size is recorded informationally
(`record --artifact <repo>/zkp-core/target/release/examples/public_sumcheck`),
no expectation attached. **A changed zkp-core test set or example cuts suite
version 5; the 19 does not move** (the oracle rule from §7, applied to the
core). `expected-cases --suite-version 4` lists 23 ids; `DEFAULT_SUITE` is 4
with every test that assumed 3 updated deliberately; the synthetic v0 suite
now mirrors v4 (23 cases, a two-test synthetic core count that cannot pass
as the real one) so `self-test` round-trips the core record path.

### 8.3 The runner (`results/cl1_floors.sh`)

After the parser self-tests, before any build: HEAD, both tree ids, both
deltas, both lockfile hashes and the core's presence are printed. Not a dry
run and any of — not a checkout, core missing/incomplete, nonempty delta
under `zkp-core/`, nonempty delta under `hashline/` — is `FAILURE ...
nothing was built`, exit 1, before the manifest is even initialized (a
dirty crate can never be green; twelve minutes on it are pure cost). The
two core cases run after the hashline crate tests with retained logs
(`core_tests.out`, `core_example.out`); a v1–v3 run skips them and says so.
`finalize --repo` binds the verdict to the tree as it is at the END of the
run. `--dry-run` prints the core commands, writes nothing (102 commands at
v4, 96 + 6). The success line names the core gates and the identity.
Lock contract unchanged: the launcher takes the heavy lock outside, the
script takes the build lock inside around each cargo step (now eight).

### 8.4 The preflight (`scripts/hashline_cl_5090_preflight.py`)

Facts gain `source_identity` (the gates module's probe) and `sources` now
walks both crates (`hashline/{src,Cargo.toml,Cargo.lock,build.rs}`,
`zkp-core/{src,Cargo.toml,Cargo.lock,examples}`; the newest source over
both is what `binary_identity` compares the binary's mtime against);
`probe_git` names the core's dirty paths apart. `source_identity` now also
requires the core present, both tree ids, both deltas empty and both
lockfiles readable. `verified_artifact` = the validator accepts the
manifest AND HEAD AND GPU-binary digest AND both crate trees AND both
lockfile hashes equal the tree in hand's; an unreadable identity or a
pre-CL21 manifest cannot be bound and refuses.

### 8.5 Refusals pinned (tests: gates 61 -> 86, preflight 78 -> 92)

| refusal | validator / preflight | test |
|---|---|---|
| dirty core (nonempty delta under `zkp-core/`) | "uncommitted changes under zkp-core/" / `source_identity` | `test_dirty_core_refuses`, `test_dirty_core_delta_refuses`, `test_dirty_core_path_refuses` |
| missing or incomplete core | "crate zkp-core/ is missing from the source tree" / `source_identity` + `verified_artifact` | `test_missing_core_refuses`, `test_incomplete_core_refuses` |
| mismatched dependency identity (lockfile hash or crate tree) | "`Cargo.lock sha256 .. != the lockfile in hand`", "`tree .. != the tree in hand`" / `verified_artifact` | `test_mismatched_dependency_identity_refuses`, `test_mismatched_lockfile_identity_refuses`, `test_mismatched_crate_tree_refuses` |
| missing core cases in a v4 manifest | "missing case core_tests" | `test_missing_core_cases_refuses`, `test_v4_manifest_missing_core_cases_refuses` |
| v4 manifest without the identity block | "requires the recorded source identity" | `test_v4_without_the_identity_refuses` |
| pre-CL21 manifest offered to the preflight | "cannot bind ... records no crate tree ids" | `test_pre_cl21_manifest_cannot_be_bound`, `test_the_round11_archived_manifest_validates_and_cannot_be_bound` |
| core totals not the suite's / example line absent | "core tests: 18 passed ..." / "core example: its identifying line was not recorded" | `test_core_test_totals_not_the_suites_refuses`, `test_core_example_line_missing_refuses`, `test_core_record_failure_modes` |
| the runner on a missing/dirty core, a dirty hashline, a non-checkout | `FAILURE ... nothing was built` before any cargo command (real temp `git init` checkouts) | `test_missing_or_dirty_core_refuses_to_start_before_any_build` |

Also pinned: archived v1–v3 manifests (schema 1, no identity) validate
under their own versions and the round-11 manifest itself does; a complete
synthetic v4 manifest passes bound to its own identity (23 cases, summary
`crate_trees` / `lockfiles` / `core_tests_passed` = 19); the core-log
parsers on the round-11 logs themselves (19 / 0 / 0 over two result lines),
empty, failed, ignored, the old two-field result form, a prefix or a
containing line is not the example line; the dry-run plan's core commands
with spaced paths (`printf %q`-quoted, `--locked --offline`, the core
manifest, `--test-threads=2`, `--example public_sumcheck`, the artifact
path, the build lock); `init --repo` on a real temp checkout records the
tree ids git reports and refuses a moved HEAD / changed delta; `finalize
--repo` goes red when a lockfile is edited after init; the preflight's
`probe_sources` over both crates; a v4 manifest with the core cases is `go`
on the ready box.

### 8.6 The run — suite v4 on `d4f0758`: `results/cl21_floors_v4/manifest.json`, verdict GREEN

Launched detached under the heavy lock (outer `flock /tmp/zk-heavy.lock`,
the build lock inside, two threads everywhere) on the WSL laptop, 2026-09-08
10:28:35 local; queued ~4 min 39 s behind another lane; ran 10:33:14 to
10:45:44 (12 min 30 s inside the lock, not a quiesced-box timing; four
other agents on the box). Marker `floors_v4.done` = 0. Everything the runner
retained is under `results/cl21_floors_v4/`: `manifest.json` (byte-identical
to the scratch copy, sha256 `4f6f87ba679430722111dcbe767b84035f84f61b53dfbf67e6493fdb3cac36cc`),
every per-case `*.out`, the launcher log, the marker, `timing.txt`, the
102-command dry-run plan, the bound validator output (`validate_bound.json`)
and the preflight report (`preflight_d4f0758.json`).

| what | value |
|---|---|
| source | HEAD `d4f0758ed293cadd3adeacfcc6ef0ea31e879696` (`zk60-cl1`); hashline delta empty; zkp-core delta empty; core present (Cargo.toml, src/, example) |
| crate trees | hashline/ `e5d1a6af575d3943aa5c15315b91e34a54674868`; zkp-core/ `c18bc0c93eaa5568edf44e6f9c28957010d1e3b6` (the same core tree as round 11's `c8a342f`: `zkp-core/` is unchanged since) |
| lockfiles | hashline/Cargo.lock `31a00627c01e35a38562e0559f2d4e9c3983860c420d91970ecfd827bcf6b0f4` (6,093 B); zkp-core/Cargo.lock `4ff606b9c497d9040dde49c4d226ebcb5b91c82e98e815a4a6e1d1d88cf1d006` (3,465 B) |
| dirty tracked files | 2 — this document and `ZK60_CLAUDE_GPU.md`, being written during the run; neither is under a crate (both deltas empty), and the preflight below was run with them parked and the tree clean |
| binaries | CPU `b13dcf273fb64ff93f5ff2226dd59366d67195ae2ccca846eb7f04477bef8444` / 4,661,720 B; GPU `be358ec107b03658525620a28f8b7b964085a121eafdbea36a3579665763c347` / 5,363,944 B |
| device | `gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU (sm_89, 36 SMs, 8.6 GB)`, driver 566.14 |
| cases | 23/23 recorded, 21 of v3 + the 2 core cases, every record ok, no start left unrecorded |
| hashline crate tests | 21 result lines, 159 passed / 0 failed / 0 ignored (summed from the manifest's `test_results`) |
| **core_tests** | exit 0; `test result: ok. 19 passed; 0 failed; 0 ignored` (lib) + `0 passed` (doc-tests) = **19 / 0 / 0**, the suite's; `--locked --offline` accepted the hashed lockfile (11.9 s build incl. deps from the registry cache) |
| **core_example** | exit 0; the identifying line printed; artifact `zkp-core/target/release/examples/public_sumcheck` sha256 `7838c154b42ffa607f75283f447d811bfd1a2c0c8567cec4be263a508b974057` / 612,264 B (informational) |
| oracle | 189 executed cases / 34 tests, `gpu_enabled` + `gpu_required` true |
| controls | `HL_GPU_REQUIRED=1` without the feature refused (exit 101, the reason line present); plain run reports `executed_cases 0 / gpu_enabled false`; `--p3 --wcache` refused (exit 2, first line), no cache dir created |
| byte gates | 12/12 at the frozen full SHA-256 and length: v2 `50cf7bdf..` 66,844,928 B, v3 `5f368db6..` 70,758,084 B, zk `021485e4..` 87,228,528 B, zkv3 `40eb5479..` 87,697,008 B on cpu, gpu and gpu-zkchunk, `gpu: ON` on the eight device gates |
| cache | cold 12 MISS / warm 12 HIT, both at the frozen zkv3 digest |
| finalize | `finalize --repo` re-probed the tree at the end: trees and lockfiles unchanged; **MANIFEST GREEN** |
| validator, bound | `validate --repo <checkout> --expect-head d4f0758.. --expect-gpu-sha256 be358ec1.. --require-production`: ok, no reasons (`validate_bound.json`) |
| preflight, bound | `hashline_cl_5090_preflight.py --repo <checkout> --binary <gpu binary> --export <125M v3 export> --run-manifest ... --layers 12 --tokens 512 --claim diagnostic --coverage ffn-only` on the clean tree at `d4f0758`: **13 of 14 checks pass** — `source_identity` (clean, core present, both trees, both lockfiles), `binary_identity` (digest = the manifest's, newer than every source of both crates; newest source `zkp-core/src/rng.rs`), `verified_artifact` (validator ok, bound to HEAD + binary + both trees + both lockfiles), the device/version/shape/planner/coverage checks; the ONE refusal is `host_idle` (the heavy lock held by another lane, load 3.88 on 22 CPUs) — a box-state check, so **no `go` on the shared box**; a `go` needs the quiesced box, not more provenance |

What this run establishes: the CL21 code at `d4f0758` gates the same
frozen bytes as round 11 (`c8a342f`) on the same core tree, with the core's
own tests and example now cases in the manifest and the dependency identity
recorded and bound. What it does not establish: anything beyond the
FFN-only 12x512 diagnostic shape (§8.7).

### 8.7 Limits

- No private-block, deployment or throughput acceptance follows from this:
  the manifest says which source, which dependencies and which binaries
  produced the frozen 12x512 FFN-only diagnostic bytes, nothing more
  (`coverage_eligibility` is untouched).
- The identity is the checkout's: `--offline` keeps the registry out of it
  and `--locked` pins resolution to the hashed lockfile, but the compiler
  and toolchain are not in the manifest (they were not before either).
- The example binary's digest is informational; nothing compares it across
  runs (a release build of a tiny example is not reproducible across
  toolchains, and no claim rests on it).
- Shared production edits (`hashline/src`, `zkp-core/`) remain with their
  owners; CL21 touched only the lane's runner, helper, preflight, tests and
  this document.
