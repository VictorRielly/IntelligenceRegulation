# U-PERF3 lane TT — the throughput model: proven tokens per second, honestly

Status: IN PROGRESS (opened 2026-09-02; round 10 of tranche U-PERF3,
lane TT, docs only, worktree wt-uperf3-tt). Sections land one commit
each; the "Agent TT status" block in PROGRESS_UPERF3.md carries the
summary.

Who this is for: a reader who knows what a cryptographic proof is
but has never opened this repository. Every term is defined where it
first appears. Every number carries one of four labels:

- **[MEASURED]** — a run happened on a named machine, on a named date.
- **[COUNTED]** — derived by arithmetic from measured pieces or from
  the engine's own counters (the arithmetic is shown).
- **[MODEL]** — an estimate; the assumption is written next to it.
- **[EXTERNAL]** — someone else's claim; unverified by us.

Where a number is a [MODEL] built on another [MODEL], the cell says
so ("[MODEL on MODEL]"). Where two sources disagree, the memo says
which is newer and uses that one.

The question this memo answers (Victor, 2026-09-02): the goal is now
**at least 50 proven tokens per second for a 30B-parameter model on
ONE GPU** (an H100-class board is allowed). What does the system as
built give today, in those units? What would a 50 tok/s design have
to look like? And is the 2026-08-30 task-board line ("~25-35 tok/s
amortized ... compose to ~65") derivable from anything recorded?

## Sources (every number below traces to one of these)

| tag | file | what is taken from it |
|---|---|---|
| S1 | `PROGRESS_UPERF2.md`, "Orchestrator status (2026-08-18, after round 9 — P + Q)" | the reference measurement: 12 layers x 512 tokens of the 125M model, 21.0 s = commit 2.5 / prove 15.5 / verify 1.7, 8 threads + RTX 4070 Laptop, QUIET; CPU-only 81.5 s; 6.7 GB; the phase attribution; 1.4e9 proven MAC/s |
| S2 | `PROGRESS_UPERF2.md`, "Decision memo (orchestrator, 2026-08-18)" | the gap arithmetic; the 4-6x desktop-board factor [MODEL]; the three routes |
| S3 | `docs/zkmatrix-poc/U_PERF3_HEADLINE_ROUTES.md` §1.2, §1.3, §2.1, §2.4, §2.6, §3.1, §3.3 | what scales how (weights x99.6, activations x18.5, opening terms x41-43); the 8B wall phase by phase [MODEL]; the two-tier reroute; the hardware note; weight preprocessing (designed, never built); the compounding table; the honesty block |
| S4 | `docs/zkmatrix-poc/U_PERF3_OPENING_LAYER_DESIGN.md` §1, §3.2, §3.3 | the built protocol's cost anatomy; Stage A's prover model at 12x512 and at 8B |
| S5 | `docs/zkmatrix-poc/U_PERF3_S4_REDESIGN.md` §1, §3, C-R1, closing verdict; `PROGRESS_UPERF3.md` "Agent FF status" rung 3 | the two-tier opening spike: measured 1.10x; the bench anatomy rows 1.45 / commit 14.59 / v-passes 20.01 / fold 2.25 s at 2^22 rings, 1 thread; the redesign's 1.6-2.5x composed count |
| S6 | `PROGRESS_UPERF3.md` "Orchestrator note 2026-08-29 — the composition ladder" | Stage A vs the oracle at 12x64 / 12x128 on CPU: bytes 2.1-2.15x smaller, prove +15% |
| S7 | `PROGRESS_UPERF3.md` "Agent OO status" RUNG 3 | 8B memory: commit ~61 GB, pass peak ~72 GB; 30B: weight-group terms ~265-270 GB |
| S8 | `docs/zkmatrix-poc/U_PERF3_MVP8B_SCALING.md` §1.1, §1.2, §1.6, §3.3 | the 8B scaling model (ring counts per group; the T axis moves only the activation side); the Mac CPU projections |
| S9 | `docs/zkmatrix-poc/AGGREGATION_LITERATURE.md`, "Addendum 2026-08-11 — Attestable" and "Conversion note 2026-08-18" | the competitor's claim (53 / 77 tok/s, one H100) and the ledger's conversion (3.1e10 MACs per token at 30B; 1.6e12 proven MAC/s) |
| S10 | `docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md` §3 | the common yardstick and the 5-15x hardware normalization used there |
| S11 | `docs/zkmatrix-poc/TASK_BOARD.md` §0, the "AS OF 2026-08-30" block | the line under audit: "~80 proven tokens/s per H100 board at 30B — currently counted ~25-35 amortized; ... 1.2-1.5x, pipelining 1.3x, spine amortization 1.1-1.2x ... compose to ~65" |
| S12 | `docs/zkmatrix-poc/TARGET_CONTRACT.md` §3-4 | what the clock covers (starts with the committed model and the tokens in memory, stops at proof bytes; excludes weight commitment and CRS expansion); the hardware line (<= 450 W consumer board) |
| S13 | `docs/zkmatrix-poc/MAC_RUNBOOK.md` M5 | the T-scaling leg on the Mac (layer 0 of the 8B model at T = 16 / 64 / 512): the measurement that gives the weight-vs-activation split directly |
| S14 | `docs/zkmatrix-poc/U_PERF2_GPU_REPORT.md` §4.5 and header; `U_PERF2_GPU4_REPORT.md` §4.5 | the laptop GPU's recorded specs (36 SMs, 8 GB); the measured kernel ceilings (1.7 G K-mults/s; the level-h GEMM at 74 G MAC/s, ~30% of the part's integer peak; 11.7 GB/s host-to-device); the report's own desktop-board note |
| S15 | `PROGRESS_UPERF3.md` "ROUND 10" block and "### Lane QQ / RR / TT" briefs | the goal as restated; the two facts Victor asked to double-check; what each round-10 lane measures |
| S16 | `docs/zkmatrix-poc/START_HERE.md` §2-6 | the plain-language state of the project (used for definitions and cross-checks only) |

Public hardware specifications (SM counts, clocks, memory bandwidth,
board power) are quoted from the vendors' published spec sheets and
are labelled [EXTERNAL, spec sheet]; none was measured here.

## 0. The answer in one paragraph

(lands with the §4 table)

## 1. Workload definitions and MACs per token

## 2. The cost anatomy per proof: per-model vs per-proof

## 3. The hardware factor: laptop -> desktop board -> H100, as a range

## 4. The tokens/s table

## 5. Audit of the 2026-08-30 task-board line

## 6. The competitor row on the same yardstick

## 7. What a 50 tok/s design must have

## What is not known
