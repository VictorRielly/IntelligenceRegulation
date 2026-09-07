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
