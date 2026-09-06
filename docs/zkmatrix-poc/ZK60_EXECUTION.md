# Execution toward 60 proven tokens per second

Opened 2026-09-04 following Victor's request to begin the reviewed plan and
provide tasks for Fable and Claude. This is an execution queue, not a claim
that the target has been achieved. Implementation began from `da626db`;
Claude's subsequent round-16 handoff `19ebd18` is acknowledged.

**Current continuation:** round 4 is committed/pushed as `5657a8d`.
Victor requested continued implementation and a substantial Claude queue:
[ten tasks CL2–CL11](ZK60_CLAUDE_QUEUE.md) and [round-5 ownership](ZK60_PARALLEL_ROUND5.md).
Codex's read-only [CL1 review](ZK60_CL1_INTEGRATION_REVIEW.md) holds integration
pending explicit correctness/fallback/measurement follow-ups. Observed
`c9fc897` adds the pooled-memory correction to `15eeda6`; CUDA source is unchanged.
Codex verifier hardening and full Python fixture selection are validated:
129 Rust tests, 144 full Python/native tests without skips, four frozen CPU
artifacts and public receipt byte parity pass. Full evidence is in
`results/zk60_round5_validation.json`; all Codex workers/jobs are complete.
Claude retains GPU/PCS and takes the memory planner for CL3. Fable's review
remains independent and outstanding.

**Round-4 validation snapshot before publication:**
[Overall milestone map](ZK60_STATUS.md) and [round-4 scope](ZK60_PARALLEL_ROUND4.md)
track the externally bound public receipt/codec and remaining private/full-LLM
gates. Round 4 is validated but not yet committed: 124 Rust/48 targeted Python
tests, four frozen CPU artifacts and separate-process byte verification pass.
Claude has delivered CL1 at `15eeda6` on `zk60-cl1` (not merged); Codex has
read its report, not reviewed its code. Concurrent board-only handoff `2c88e4a`
is preserved. Codex queued gates behind CL1's shared lock without interrupting
it. Preserve GPU/PCS ownership; review source/results and fix the separately
reported broader Python fixture-path failures before integration promotion.

**Round 2 integrated:** Victor approved the complete-PoC direction and
autonomous work while away. [ZK60_PARALLEL_ROUND2.md](ZK60_PARALLEL_ROUND2.md)
records the fixed contract/causal witness oracle, CPU phase profiler,
primary-source research and experimental equality receipt: 94 release
Rust tests, 48 targeted Python tests and four unchanged frozen CPU proof
artifacts. The singleton opening-mask hazard below is a privacy review
gate before application use, not a repaired whole-FFN result. [Round 1](ZK60_PARALLEL_ROUND1.md)
is also integrated. Fable and Claude's files remain reserved; the Codex
workers are not those named models. The 5090 is still pending.

## Coordination and ownership

**Claude's CL1 handoff is now delivered, not merged.** Do not interrupt or
restart its work, or treat a proposed follow-up as already running. Check
the live task board, HEAD and working-tree changes before starting any lane.
Round 16's predicate and L9 kernel work have landed; neither is a new task.

| Owner | Initial task | Owned files | State |
|---|---|---|---|
| Codex | C0: secure randomness, truthful command claims, complete timing, benchmark collector | `hashline/src/zk.rs`, `hashline/src/bin/hashline.rs`, `hashline/tests/cli_claims.rs`, `scripts/hashline_benchmark.py`, `tests/test_hashline_benchmark.py`, `results/zk60_foundations_validation.json`, this file | Implemented and integrated; see validation record below |
| Fable | F1: adversarial model-identity review and consistency-proof design | `docs/zkmatrix-poc/ZK60_FABLE_REVIEW.md`, new `hashline/tests/zk60_model_identity.rs` | Ready for pickup in its own checkout |
| Claude | CL1 delivered; CL2–CL11 follow-up queue | GPU/PCS plus task-specific files in [expanded queue](ZK60_CLAUDE_QUEUE.md); CL3 owns memory planner/tests | CL1 observed at `c9fc897`; merge held for CL2/CL3/CL4 review fixes. Ten tasks queued, not claimed running |
| Codex | C1: integrate reviewed identity mechanism and complete private transformer statement | Reassign shared Rust files explicitly after C0/F1/CL1 handoffs | Next |

Use separate worktrees/checkouts and report the exact base revision. For a
file outside a lane's ownership, propose the interface in its report first;
do not independently edit another lane's file. Shared task-board/ledger
updates are the integrator's job. Handoffs must include actual changed files,
exact validation commands and exit codes, proof digests where applicable,
and limitations. A task document is not evidence that another model ran it.

The auxiliary agents helping Codex with C0 are an independent read-only
security reviewer and a benchmark-collector implementer. They are not being
represented as Fable or Claude. The named agents' work remains queued for
their own sessions.

## Acceptance target and current limits

The first shape is a calibrated 8B-class model at 512 prefill rows, with P1
(private inputs/activations/output, public weights) and P3 (weights private
too) reported separately. The target clock is **512 / 60 = 8.533333 seconds**
from input/witness preparation through serialized proof readiness. Report
inference/proving overlap explicitly if later introduced. One GPU includes
the inference work; do not benchmark it on a second device off the clock.

This is the existing prefill milestone. Victor has not yet answered whether
the eventual generated-token product may use delayed window/sequence proofs
or must verify each token before release. Continue work common to both; do
not silently claim one workload satisfies the other. 30B is the follow-on.

Publication requires at least 20 warm runs on an idle named machine, p50 and
p95 nearest-rank, a separate cold row, proof bytes, verification including
artifact decoding, CPU/RAM/VRAM, driver/toolkit and power settings, frozen
model/quantization identity, complete coverage, and an explicit whole-proof
security argument. Keep the existing size/verifier budgets visible as unmet
where applicable; a faster prover does not amend those budgets.

Current hashline coverage is FFN-only for `pass`, and transformer blocks
(attention, norms, residuals, FFN and seams) for `attn-pass`. The latter has
no ZK integration. Neither covers the complete token-generation interface.
P3's fresh weight commitment still lacks a consistency proof to an approved
stable model identity. **Neither path can report `goal_met: true`.**

Round-2 review additionally reproduced a single-base-mask singleton-opening
privacy hazard in the generic PCS interface. The diagnostic and paired-mask
control are in `hashline/tests/zk60_mask_rank.rs`; impact on actual complete
FFN opening groups still requires an audit. The new experimental seam uses
paired terminal masks. No legacy caller is repaired or privacy-certified
by that change. Treat this opening-rank audit as a required gate before
sensitive applications, not as a reason to weaken or erase old byte fixtures.

The following prior observations are diagnostic baselines, not p95 results:

| Evidence | Recorded result | Limit |
|---|---|---|
| `results/hashline_convert_gpu.md` | FFN P0: 58.40 s prove, approximately 134.5 s witness work | Host allocation optimization is already included |
| `results/hashline_zk_8b_gpu.md` | FFN P1: 265.34 s prove, 1,285,578,368 B | Laptop VRAM pressure; one noisy run |
| `results/am_r3_8b_p1_scan_cpu.log` / `am_r3_8b_p3_cpu.log` | CPU P1 485.33 s, P3 499.04 s | +2.82% is a cold-commit CPU comparison, not a warm-cache GPU forecast |
| Round-16 AO handoff | Opening re-encode 1.292x in its controlled microbenchmark | Not a 1.292x speedup of the entire pass; remeasure merged code |

Use phase seconds, not multiplied headline factors. Wire proof bytes and
encoded bytes read/hashed are separate quantities. Record the effect on both.

## C0 — foundations started by Codex

1. Make every normal ZK prover invocation obtain 32 secret OS-random bytes.
   Configuration cloning/reuse must not repeat masks. Preserve explicit
   `--seed N` as an INSECURE deterministic fixture so byte gates remain useful.
   Entropy failure must stop proving, and normal logs must contain no seed.
2. Reject attention/diagnostic commands that request unimplemented privacy,
   predicates or declared identities before reading exports. Require a real
   positive `attn-pass` layer count. Reject unsupported v2 statement modes.
3. Emit `HASHLINE_TIMING` JSON after each pass with witness/prove/serialize,
   proof-readiness and in-memory verify clocks; actual coverage/privacy,
   shape, serialized length, verification status and GPU status. These
   diagnostics do not alter the transcript. Export reads and optional proof
   file writes are conservatively included in proof readiness; setup and
   subsequent verification are excluded. This is not a pure inference clock.
4. Add a collector that keeps raw logs, cold/warm separation, exact binary
   and export hashes, machine metadata and nearest-rank statistics. Detect
   GPU-off/fallback, missing verification, changing shapes, missing artifacts
   and deterministic fixtures. Refuse private 8B runs on the 8 GiB laptop.

Normal randomness currently supports Linux/WSL and macOS through the OS
random device. Other hosts fail closed until an OS backend is added. This
change fixes seed reuse/exposure; it does not settle the masking simulator,
range constraints, model identity, or whole-proof security level.

API migration: `ZkConfig.seed` is now `Option<u64>`. Use `None` (the
default) for fresh private proofs and `Some(N)` only for deterministic
regression fixtures. Existing deployed callers must not merely wrap a fixed
seed in `Some` and assume privacy has been restored.

`gpu_enabled: true` establishes successful GPU initialization, not that
every operation stayed on the device. The collector catches logged
fallbacks; the full baseline still requires per-operation counters and
peak-memory measurements. Warm means a new process using the same weight
cache, not a resident prover or warmed CUDA context. Verification currently
uses in-memory proof objects, not a standalone decoder.

## F1 — task for Fable: prove which model ran

Round-3 handoff adds [the executed public attention schedule](ZK60_ATTENTION_SCHEDULE.md)
and [the reviewed pending-FFN interface proposal](ZK60_PENDING_FFN.md).
Use these to locate actual claim sites and ownership boundaries; neither
is an independent privacy audit. The P0 block tests in
`hashline/tests/zk60_public_block.rs` now exercise real internal X/Z linkage
and independently approved W roots. They do not establish private composition.
Fable's reserved review file/tests remain unmodified and ready for pickup.

Read `hashline/src/zk.rs` (`ZkStatementMode`, `prove_layer_zk_v3`,
`verify_layer_zk_v3`), `hashline/src/layer.rs` (`StatementV3`),
`U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md`, and the AM model-identity honesty note
in `PROGRESS_UPERF3.md`. The old lattice range/modulus gadgets are not
hashline APIs; verify every proposed mechanism against the correct engine.

Deliver these rungs in order:

1. At a tiny synthetic v3 shape, demonstrate that distinct hidden weight
   tensors can currently verify under the same declared `--model-id`.
   Also check the P1 verifier's caller obligation to pin expected W roots:
   a root carried in a proof is not by itself an approved-model check.
   Record this as a reproduction of a known missing constraint, not as a
   production acceptance test or a reason to erase existing regression gates.
2. Specify the public relation: approved architecture, frozen quantization,
   table registry and stable hiding weight commitment; per-proof W commitment;
   equality/consistency relation tying the two. State what is public and what
   the verifier must obtain independently of the prover.
3. Compare the simplest correct per-proof consistency construction with a
   reusable hidden-column-opening construction. Account for preprocessing,
   per-proof work, private repeated openings, proof bytes, memory, soundness
   and ZK composition. A `model=` transcript string alone is insufficient.
4. Give a code-level interface proposal for C1 and a malicious-prover test
   matrix: substituted model/weights, quantization/table changes, replay under
   another model, reused randomness, inconsistent layer roots and seams.
5. Review C0's randomness behavior independently, including repeated calls
   with cloned config and default-vs-explicit-seed use. Do not mistake the
   preserved deterministic byte fixtures for secure deployed transcripts.
6. Audit each actual opening group's joint base-field mask rank, including
   the singleton counterexample in `ZK60_RESEARCH_DECISIONS.md`. Analyze
   proximity vectors, functionals and repeated calls together. Identify
   actual affected FFN shapes before proposing versioned fixes; a mask-site
   nonzero assertion alone does not establish that the private vector hides.

Acceptance: a reproducible tiny identity counterexample; a precise candidate
relation with no merely asserted links; citations for the construction's
actual security theorem; counted costs with all assumptions; and one
recommended first implementation with alternatives documented. Avoid a
large GPU run or a new protocol implementation in this first review.

For the Orion lineage, start with the repaired construction Scorpius, not
the unrepaired sketch: <https://eprint.iacr.org/2024/1164>. Confirm current
primary sources yourself before relying on a theorem.

## CL1 — task for Claude: private commitments within a VRAM budget

**Start only after finishing and handing off the current task.** Rebase the
brief on the actual latest tree; AO's output pruning and AL's host allocation
fix have already landed. C0 changes `zk.rs` and the CLI, so those files are
read-only during this lane; propose any caller changes for Codex to integrate.

Read `dev_commit_zk_from`, `dev_commit_zk`, chunked P0 commitments and opening
columns in `hashline/src/gpu/cuda.rs`; `commit_zk_owned`/`commit_zk_device` in
`pcs.rs`; the AI/AM VRAM reports; and `BLACKWELL_5090_RUNBOOK.md`.

Deliver these rungs in order:

1. Write an allocation-lifetime table for one real-width W/A/H hiding
   commitment: systematic values, pads, coefficient buffers, expanded code,
   sumcheck tables and pooled storage. Distinguish simultaneously live bytes
   from cumulative traffic. Derive a memory bound before running it.
2. Implement the smallest bounded-memory/chunked hiding commitment change
   that preserves the existing pad/coset/salt construction, transcript order,
   openings and explicit-seed bytes. Expose a memory/chunk budget and clear
   failure diagnostics; no silent privacy downgrade or untracked CPU fallback.
3. Validate CPU/GPU commitments AND opened columns against the existing CPU
   oracle on small shapes, including forced chunking, varied row counts,
   padding/query counts and all currently supported encoding rates. Run the
   four frozen fixtures on both binaries, plus forced chunking and P3 tests.
4. On a sufficiently large GPU, measure one layer, then four, then the full
   32-layer FFN P1/P3 pass with C0's collector. Record phase wall, device
   counters and peak memory, and distinguish cold/warm P1 weight caches.
   Stay at safe small shapes if the 5090 is not available; deliver code and
   oracle results without inventing a full-scale speedup.

Acceptance: documented peak bound, unchanged deterministic artifacts,
meaningful negative tests, successful forced-chunk CPU/GPU comparisons, and
an honest before/after phase table on named hardware when available.
Attribute gains to the portion of the pass changed. Retain a switch for the
reference implementation until the integration gates pass.

## C1 and subsequent milestones

| Milestone | Prerequisite | Exit evidence |
|---|---|---|
| Stable P3 model identity | F1 reviewed relation | Wrong-model and inconsistent-commitment proofs reject; repeated proofs hide weights |
| Complete private transformer block | Identity interface plus attention ZK design | One layer, then 125M chain; range facts and seams verified; unsupported mode guards removed only when implemented |
| Full 8B proof | Stable calibration and complete block | 32 layers plus embedding, final norm, output projection and token-selection relation; independent verifier consumes bytes |
| Device witness generation | Exact CPU oracle | Every integer tensor matches; inference included in end-to-end clock |
| Sequence/window proving | Output timing requirement settled | Generated token choices and context/KV state bound across windows; throughput AND proof lag measured |
| Compact private opening | Measured bytes/encoding bottleneck | Hiding + GPU support + security accounting at actual dimensions; no silent weakening of parameters |
| 60/s validation | Complete relation and adequate hardware | >=20 warm runs, p95 <=8.533333 s at 512 rows for the prefill milestone; generated-token result stated separately |

Study Attestable's sequence-level amortization without assuming its private
implementation is available: <https://attestable.com/blog/proving-llms-scale>.
Its stated sequence proof is not evidence for proof-before-release of each
individual token. Preserve exact arithmetic unless a changed model contract
is explicitly agreed. Do not obtain speed by silently changing attention.

## Commands and machine handoff

CPU tests (no datasets or GPU needed):

```sh
cargo test --release --offline --manifest-path hashline/Cargo.toml
python3 -m unittest discover -s tests -p 'test_hashline_benchmark.py'
```

Full repository suite on this host (includes the existing native
`freeze-check` tests; use the detached-job protocol for the longer run):

```sh
env M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl \
  python3 -m unittest discover -s tests
```

Analyze the historical P3 artifact without rerunning it:

```sh
python3 scripts/hashline_benchmark.py analyze --privacy P3 --device cpu \
  --cold results/am_r3_8b_p3_cpu.log --out /tmp/zk60-p3-history
```

The output directory must not exist. The report will retain the historical
metrics and mark the missing proof-readiness clock/statistical sample as
ineligible; it will not turn `512 / PROVE` into an end-to-end result.

The accessible machine was checked during C0: **RTX 4070 Laptop, driver
566.14, 8,188 MiB VRAM**, not the 5090. Do not run private 8B GPU passes
there. GPU initialization needs access outside the Codex sandbox; a blocked
device is not a CPU performance regression.

For the 5090: finish the Windows-host driver step first, then the compatible
NVRTC/toolkit step and GPU probe described in the runbook. Preserve Claude's
active environment until its task is handed off. The latest contract accepts
the stock 575 W card; do not reopen the obsolete 450 W approval question.

After the hardware and memory gates, use `hashline_benchmark.py run` with
the GPU binary, real v3 export, `--privacy P1` or `P3`, `--device gpu`,
`--warm-runs 20`, and a new output directory for each mode. The runner owns
`/tmp/zk-heavy.lock`; **do not wrap it in a second flock of that lock**.
Runs expected to exceed five minutes must use the repository's detached-job
protocol, retaining both log and exit-code `.done` marker. A ready command
does not mean an expensive job was launched or hardware rented.

## C0 validation record

The isolated implementation started at `da626db`. Before integration, both
shared Rust files were checked unchanged against that base on `19ebd18`.
Claude's GPU implementation and current handoff were not edited; the task
board received only a link to this separate queue. No branch switch, commit,
push, driver change, rented hardware, or full private 8B GPU job was made.

- Release CPU crate: 46 unit tests and 3 CLI integration tests passed,
  exit 0. Includes repeated fresh-entropy P1/P3 proofs, cloned configuration,
  entropy failure, preserved legacy stream and unsupported command claims.
- Collector unit tests: 28 passed, exit 0, without datasets or a GPU.
- Release CUDA build: passed, exit 0. GPU probe passed field arithmetic,
  BLAKE3, NTT and chunked commitments/opened-column comparisons.
- Frozen 125M, 12-layer, 512-row fixtures: **8/8 passed**, all verified;
  the four digests and sizes below match on BOTH CPU and GPU. ZK rows
  deliberately use `--seed 1`; they are correctness gates, not private
  production proofs or 8B performance evidence.

| Fixture | SHA-256 prefix (CPU = GPU) | Bytes |
|---|---|---:|
| v2 P0 | `50cf7bdfd6b5b182` | 66,844,928 |
| v3 P0 | `5f368db6240e0614` | 70,758,084 |
| v2 P1 seed 1 | `021485e4f80ec695` | 87,228,528 |
| v3 P1 seed 1 | `40eb54795e023c77` | 87,697,008 |

The full Python suite passed: **109 tests run, 107 passed, 2 skipped**,
exit 0, 526.455 seconds. `M125_EXPORT_DIR` was set to the existing WSL
export; this includes the native freeze-check tests. Tiny CPU collector
P1/P3 smoke runs also exited 0: one cold and one warm sample per mode,
one layer at two rows, all four proofs verified with OS randomness and
different proof digests between repetitions. Each sample passed the
collector's checks, while both aggregate reports correctly remain
ineligible because 20 warm samples are required. No performance target
was established.

The collector was also run against the archived 8B P1/P3 CPU logs without
rerunning those workloads. Both retain their original phase timings and
are ineligible because proof-readiness timing and repeated samples are
missing.

Machine-readable evidence, full digests, exact commands and report scopes
are in [results/zk60_foundations_validation.json](../../results/zk60_foundations_validation.json).
Scratch logs, proof artifacts and exit-code markers are in
`/tmp/zk60-fixtures-pAtLMl`; all five markers are 0. The initial sandboxed
detached launch did not survive its process namespace; it produced no
proof. Validation was then relaunched with approved host access and a
persistent detached session. `git diff --check` passes.
