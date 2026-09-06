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
  --export <v3-widened export dir> --floors-log <checkout>/results/cl1_floors.log \
  --layers 32 --tokens 512 --privacy P1 --require-cc 12.0 --emit-plan --out <new file>
```

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
| `binary_identity` | binary exists, is the gpu-cuda build, newer than every source file; sha256 recorded | a stale binary |
| `shape_supported` | v3-widened sidecar covers the layers; tokens a power of two | an export that cannot serve the request |
| `planner_margin` | chunked W component (CL3 planner) + measured reserve <= 80% of nominal VRAM | a shape the card cannot hold; nominal VRAM is never treated as free |
| `verified_artifact` | a green byte-gate log (12/12, `.done` = 0) NEWER than the binary | a binary whose proofs have not been byte-gated |
| `coverage_eligibility` | `--claim diagnostic`, or full coverage with fresh randomness | a target claim from FFN-only coverage or a seeded row |

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
| 0 | `results/cl1_floors.sh` on the new box | 12/12 byte gates at full SHA-256, `gpu: ON` in every GPU gate, the oracle suite's executed-case summary, the missing-feature refusal — a digest that moves on new hardware is a codegen bug, not a hardware finding (runbook §4) |
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
- The reserve in `planner_margin` is a laptop measurement at one shape and
  one chunk height; the pending attention/FFN states are not implemented and
  are not in it.
- The generation and proof-lag clocks cannot be collected until a generation
  harness exists; stage 6 is a definition, not a command.
- FFN-only coverage keeps every result diagnostic; the preflight refuses a
  target claim on it by construction.
