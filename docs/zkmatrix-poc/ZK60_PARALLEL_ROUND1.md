# ZK60 parallel round 1 — work before the 5090 arrives

Opened 2026-09-04 at Victor's request. The 5090 is expected to be available
in one or two days; do not wait for it to do small CPU correctness work.
Base: `19ebd18` plus the uncommitted C0 foundation patch documented in
[ZK60_EXECUTION.md](ZK60_EXECUTION.md). Preserve that patch and Claude's
current work. No driver/toolkit changes or private 8B GPU jobs in this round.

## Ownership

| Lane | Owner | Isolated checkout | Only files it may change |
|---|---|---|---|
| I1: approved-model verifier boundary | Codex identity worker | `/tmp/zk60-parallel-OrrY0T/identity` | `hashline/src/model_identity.rs`, `hashline/tests/zk60_identity_gap.rs`, `docs/zkmatrix-poc/ZK60_IDENTITY_WORKER.md`; local `hashline/src/lib.rs` registration only |
| W1: exact CPU witness acceleration | Codex witness worker | `/tmp/zk60-parallel-OrrY0T/witness` | `hashline/src/chain.rs`, `hashline/src/export_v3.rs`, `hashline/examples/zk60_witness_bench.rs`, `docs/zkmatrix-poc/ZK60_WITNESS_WORKER.md` |
| A1: private transformer coverage | Codex private-block worker | `/tmp/zk60-parallel-OrrY0T/private_block` | `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK.md`, `docs/zkmatrix-poc/zk60_private_block_tasks.json` |
| M1: memory accounting and integration | Codex lead | main checkout | new `scripts/hashline_memory_plan.py`, `tests/test_hashline_memory_plan.py`, `hashline/tests/zk60_memory_layout.rs`, this queue and handoff links; integration of accepted worker changes |

The workers are Codex agents, **not Fable or Claude**. Fable's own files
remain reserved for an independent review of I1 and the P3 consistency
design. Claude's `gpu/` and `pcs.rs` lane remains **queued after its current
task**, with M1 supplying allocation analysis rather than concurrent edits.
Agents read the latest main-tree handoff but write only their isolated lanes.
The lead alone integrates changes and updates shared boards. No commits or
pushes are required for this round.

## Bounded deliverables

- **I1:** reproduce the existing same-label/different-weights P3 gap at a
  tiny shape; implement an opt-in P1 verifier boundary that checks an
  independently approved statement and weight commitment before invoking
  the existing verifier. It must reject P3, unsupported policy and wrong
  model parameters. Do not claim this fixes P3 identity or wire decoding.
- **W1:** establish a scalar exact-integer oracle and small CPU benchmark;
  implement one bounded matrix/witness optimization only if oracle equality
  and a controlled local A/B support it. Include signed/extreme values,
  odd sizes, tails and overflow semantics. No approximate GEMM or altered
  quantization. Do not extrapolate a microbenchmark into a 60/s claim.
- **A1:** map the actual attention, norms, residuals, FFN and seam proof
  relations to their privacy exposure and missing masking work. Produce
  ordered implementation tasks with exact files, dependencies and positive/
  negative tests; distinguish complete blocks from embedding/head/token
  selection and generated-token state. No unsupported `--zk` enablement.
- **M1:** derive conservative allocation accounting from current code,
  distinguish live buffers, retained/pool memory and workspace, test a pure
  planning tool without allocating model-sized tensors, and give Claude an
  explicit starting budget. A partial bound must never authorize a run.

## Run discipline and acceptance

Small CPU-only tests and bounded microbenchmarks are allowed. Coordinate
resource-heavy validation through `/tmp/zk-heavy.lock`; >5-minute jobs
must detach and retain an exit-code marker. The main-thread integrator
runs cross-lane tests and deterministic proof gates after review. Existing
GPU proof bytes, masking, domains, quantization and security parameters
must not change silently. Keep the C0 reference binary in
`/tmp/zk60-codex-SA3FDq/hashline/target/release/hashline` for A/B comparisons.

Before calling a lane complete, record its exact changes, commands,
results, measured-versus-modelled numbers and unresolved limitations.

## When the 5090 is ready

1. Validate host driver/toolkit compatibility and the small GPU oracle.
2. Confirm memory headroom and actual allocation peaks on one layer, then
   four layers. Do not infer full-pass safety from the card's capacity alone.
3. Run separate P1/P3 8B FFN cold/warm baselines with proof verification and
   device counters; use 20 warm runs only after the smaller gates pass.
4. Use measured phase seconds to prioritize device witness work, private
   commitments/openings and full-private-block integration. The initial
   512-row milestone is <=8.533333 seconds to serialized proof readiness;
   this is not yet a claim about 60 autoregressively generated tokens/s.

## M1 initial allocation result

The pure planner `scripts/hashline_memory_plan.py` reads no datasets and
never touches a GPU. Its nine unit tests pass. Example:

```sh
python3 scripts/hashline_memory_plan.py --p3-weights 4096 14336 \
  --component-budget-mib 32768
python3 -m unittest discover -s tests -p test_hashline_memory_plan.py
```

**[COUNTED, not measured]** At the current width/rate/check settings, the
P3 W commitment has 10,752 data rows + 21 block masks + 1 proximity row.
This single commitment accounts for **13,492 MiB (13.176 GiB)** at its
component peak, before other commitments, zero-check workspaces, CUDA
overhead and fragmentation. Its returned live data/encoding is 6,733.75
MiB; a further 6,733.75 MiB remains in the buffer pool under the cold-pool
model. `drop(d_coef)` and `drop(d_coef2)` are not device-memory frees:
the pool retains up to 64 buffers and has no byte-budget cap. The next
automatic drain in `prove_layer_zk_v3` is after H, not immediately after W.

This explains why Claude's chunked hiding-commit work must account for
both the two full expanded buffers and pool lifetime. The planner's
`safe_to_run` is **always false**: it is a component accounting aid, not
a complete bound or a substitute for free-VRAM checks. Supplied prior
live/pool memory is conservatively additive; reusable prior buffers can
make that subtotal an overestimate. No automatic launch gate consumes it.

Independent review confirmed this component arithmetic and prompted guards
against pads wider than a message row, column-hash byte-length overflow
and untested log_cols=0. The planner now rejects those inputs. This does
not repair or certify the underlying GPU kernels for those regimes.
Different-size twiddle replacement also needs the old tables counted as
prior live storage. A tiny Rust test ties the planner's three example W
layouts to the actual `ZkLayoutV3`, without allocating weight tensors.

## First handoff and next assignments

All three workers finished their bounded first tasks. The lead reviewed
and integrated the results into the main working tree; no production
matmul or GPU function was changed in this round.

| Lane | Integrated result | Next bounded task |
|---|---|---|
| I1 | [Approved P1 boundary and known P3 gap tests](ZK60_IDENTITY_WORKER.md) | Fable independently reviews trust registration and designs stable-commitment consistency for P3; do not treat a label as model approval |
| W1 | [Scalar oracles and paired CPU benchmark](ZK60_WITNESS_WORKER.md); blocking experiment not promoted | Attribute one real 125M layer's reads/digests, three products, requantization and copies before choosing a kernel; use the oracle for later GPU integer work |
| A1 | [Private-block coverage map](ZK60_PRIVATE_BLOCK.md) and [11 implementation tasks](zk60_private_block_tasks.json) | Start A00 fixed calibration/shape/range contract and A01 exposure inventory with split file ownership, then A02 private equality/seam gadget |
| M1 | Pure component memory planner and source-layout parity test | Claude uses the allocation lifetimes for CL1 after handing off its current task; add byte-budgeted pooling/chunking and CPU/GPU oracle gates |

I1 is an **opt-in library API for one P1 FFN layer**. Existing CLI/pass
verifier calls are deliberately unchanged and do not automatically use
that approval boundary. It does not fix private model identity, absent
input/output relations, proof decoding or full generation.

Integrated validation: **63 release Rust tests** across library,
CLI, identity/layout integrations and the experimental example; **37
targeted Python tests** for collection/memory accounting; all pass.
W1's eight new arithmetic/experimental tests also passed debug and release
in its lane. **All four frozen CPU proof gates passed** at 12 layers x
512 rows: v2/v3 P0 and explicit-seed v2/v3 P1, with the existing digests
and byte lengths unchanged. Evidence and raw experiment logs are preserved
in [zk60_round1_validation.json](../../results/zk60_round1_validation.json).
No full
Python/native suite or GPU fixture rerun is claimed for this round; C0's
earlier full suite and eight CPU/GPU byte gates are recorded separately.
