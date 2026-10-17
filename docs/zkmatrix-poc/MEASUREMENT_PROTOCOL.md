# MEASUREMENT_PROTOCOL.md — the p50/p95 measurement protocol

**2026-09-26 workload/hardware amendment:** the current target is sustained
>=50 proved tokens/s for a complete private 8B forward pass on an RTX 5090 or
a named alternative high-end GPU. Victor allows larger workloads to amortize
initialization and initial prefill. Follow
[the current throughput contract](ZK60_THROUGHPUT_TARGET.md): disclose warm
and total-workload rates, setup fraction, context and pass count, and latency.
The historical 512-token reference and per-subcommand rows below remain
comparisons; they cannot substitute for completed full-stack work on the named
GPU. Keep the same workload size for each repeated p50/p95 measurement.

Status: LANE DELIVERABLE (2026-08-10, U-AG-B1 wave 3, Agent BI).
Implements the TARGET_CONTRACT.md Section 4 statistic as an executable
harness (`ring_matmul uagb1-bi bench-stat ...`) and pins the protocol
a REFERENCE-BOX pass follows. Machine labeling rules follow the ledger
Machine note (PROGRESS_UAGB1.md): every number produced on Victor's
Mac is [MAC-BOX, non-reference], plus [NOISY-SHARED] if sibling lanes
ran; contract-grade rows exist only from the reference box (the WSL2
Intel Core Ultra 9 185H workstation) or after a dated contract
machine-line amendment — an orchestrator/console decision, never a
lane's.

## 1. The statistic (contract Section 4, verbatim discipline)

- **>= 20 warm runs** of the workload on an otherwise idle machine.
- **p95** wall-clock is the claim statistic; **p50** reported
  alongside; **cold-start** (the FIRST run after setup) reported
  separately and never pooled into the warm set.
- Percentiles are **nearest-rank** on the sorted warm set
  (p = sorted[ceil(q * n)] with 1-based indexing): with n = 20 warm
  runs, p50 = 10th, p95 = 19th order statistic. Pinned here so every
  reported number is reproducible from the raw times.
- min/max of the warm set are printed for dispersion honesty; a warm
  set whose max/min ratio exceeds ~1.5x on a quiesced box indicates
  interference — rerun, do not report.
- What a "run" covers is workload-defined and stated on every row:
  the prover clock runs from committed-model+input in memory to
  serialized proof bytes existing (contract Section 3); the verifier
  clock INCLUDES artifact deserialization and statement validation.

## 2. The harness

One dispatch arm (`uagb1-bi bench-stat`), four modes:

| mode | workload | clock covers |
|---|---|---|
| `eval-verify [r i c] [n]` | the BD eval-proof artifact at shape (default 512x768x2048 bare) | setup (prove + serialize) ONCE, excluded; each run = wire deserialize + full verify (statement decode/validate/digest + rebuilt-statement gate + sumcheck + both group chains). Run 1 = cold. |
| `matmul-prove [r i c] [n]` | the D2 committed matmul statement (default 128x768x256, the recorded battery mid shape) | n+1 FULL honest instances; per-phase times from the instance cost struct; the PROVE phase is the statistic, commit/verify reported alongside. Run 1 = cold. |
| `freeze-check [n]` | the whole `freeze-check` subcommand | subprocess whole-invocation wall (the trivial calibration row: measures machine + spawn noise floor, ~all-derive workload). |
| `spawn <n> -- <argv...>` | ANY ring_matmul subcommand | subprocess whole-invocation wall; includes ~ms process spawn + binary load overhead (stated; negligible for multi-second workloads, visible on the calibration row). |

Output format (one line per phase, machine-parsable):

    BENCH-STAT <workload> <phase>: n_warm=<n> cold=<s> p50=<s> p95=<s> min=<s> max=<s>

## 3. The quiesced-machine protocol (what a reference-box pass runs)

Preconditions, in order, before ANY timed run:

1. `cargo build --release` completed BEFORE the session (binary warm
   on disk; no compilation during measurement).
2. No sibling worktree processes, no suite runs, no browsers/IDE
   indexers; mains power (no battery throttling); on the WSL2
   reference box: stock power limits, no other VMs.
3. `results/m125_ffn_export/` present if pass workloads run
   (regenerated beforehand by the export script — off the clock,
   one-time setup by the contract's Section 3 clock rule).
4. `ring_matmul freeze-check` green (a wrong-constants box must not
   produce numbers).

The run order of a full session (calibration first, heavier last —
thermal honesty):

1. `bench-stat freeze-check 20` — the calibration row (noise floor +
   spawn overhead; also re-proves the constants are frozen).
2. `bench-stat matmul-prove 128 768 256 20`.
3. `bench-stat eval-verify 512 768 2048 20`.
4. Any session-specific rows (wire-bench tables, fold rows), each
   with its own cold/warm separation.

Recorded per session, next to the rows: machine line (CPU model,
RAM, OS/virtualization, power state), binary git commit, date,
ambient load statement ("idle" or the named exceptions), and the
machine label per the ledger rule: **[MAC-BOX, non-reference]** for
Victor's Mac (plus **[NOISY-SHARED]** if anything else ran),
unlabeled contract-grade ONLY from the reference box.

## 4. The full reference pass (~55 min class; protocol only, NOT run this lane)

The 12-layer 125M pass measurement the contract rows will cite runs
as (all on the reference box, quiesced per Section 3):

1. Setup, off the clock: exports regenerated; `m125-pass statement`
   built once; weights committed once (the contract's one-time
   setup carve-out).
2. Cold row: ONE full pass — 12 x `m125-pass prove <layer>`
   sequentially (recorded per layer AND summed) + verify per layer.
   At wave-2 Mac magnitudes this is the ~55-min item (prove
   3,275 s + verify 411 s); reference-box numbers will differ —
   that is the point of the row.
3. Warm rows: the >= 20-run discipline applies per SUBCOMMAND
   workload (layer prove, layer verify), not to the 55-min
   aggregate — a 20x full-pass session (~18 h) is a dedicated
   soak, scheduled only when a contract row is being frozen.
   Until then, pass-level numbers carry n and are labeled
   single-shot/n-shot explicitly (the wave-2 convention).
4. The composed-artifact byte row rides the same session: serialized
   bytes via the ZKWF v1 wire format (WIRE_FORMAT.md) — the number
   the A1 budgets bind on — printed next to the counted-convention
   number for continuity.

## 5. Measured rows this lane (Mac box; the required three)

Recorded in the ledger BI verdict row and reproducible via the exact
commands above. Every row [MAC-BOX, non-reference], [NOISY-SHARED]
where sibling lanes were active — magnitudes and ratios only, no
contract claim. The three required workloads: the single-layer
eval-proof verify (512x768x2048), the matmul-statement prove at the
mid shape (128x768x256), and the freeze-check calibration row.

---

*Changelog: 2026-08-10 — first edition (U-AG-B1 wave 3, lane BI):
statistic pinned (nearest-rank, cold/warm separation, coverage
statements), harness modes documented, quiesced protocol + reference
pass procedure written, Mac-box labeling rules restated from the
ledger Machine note.*
