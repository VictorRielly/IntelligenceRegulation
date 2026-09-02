# U-PERF3 lane YY — Route B (the hash-based line): proven tokens per second, honestly

Status: IN PROGRESS (opened 2026-09-02; round 11 of tranche U-PERF3,
lane YY, docs only, worktree wt-uperf3-yy). The sibling of lane TT's
`U_PERF3_THROUGHPUT_MODEL.md` (cited as S0 below) for the hash-based
line (`hashline/`, lane UU): the same yardstick, the same workload
definitions, the same model shapes, the same four labels. Where this
memo and S0 use the same word, it means the same thing; where a
number here differs from S0's lattice-line number, the two are meant
to be read side by side (§6).

Who this is for: a reader who knows what a cryptographic proof is
but has never opened this repository. Every term is defined where it
first appears. Every number carries one of four labels:

- **[MEASURED]** — a run happened on a named machine, on a named date.
- **[COUNTED]** — derived by arithmetic from measured pieces or from
  the code's own loops (the arithmetic is shown).
- **[MODEL]** — an estimate; the assumption is written next to it.
- **[EXTERNAL]** — someone else's claim; unverified by us.

Where a number is a [MODEL] built on another [MODEL], the cell says
so ("[MODEL on MODEL]"). Where two sources disagree, the memo says
which is newer and uses that one.

The question this memo answers (lane brief, PROGRESS_UPERF3.md round
11 "Lane YY"): the goal is **at least 50 proven tokens per second for
a 30B-parameter model on ONE GPU** (an H100 is allowed). Lane UU
built a hash-based prover of the same 12x512 statement and measured
it on the laptop's CPU. What does THAT line give, in those units, at
8B and 30B, on a laptop, a desktop board and an H100? What does
zero-knowledge — non-negotiable per Victor — add to it? What does
the 66.8 MB proof become under a different commitment scheme? And
what would a 50 tok/s design on this line have to look like?

## Sources (every number below traces to one of these)

| tag | file | what is taken from it |
|---|---|---|
| S0 | `docs/zkmatrix-poc/U_PERF3_THROUGHPUT_MODEL.md` (lane TT, 2026-09-02) | the workload definitions (§1.1-1.2), the 8B and 30B shapes (§1.3), MACs per token (§1.4), the witness sizes (§1.5), the hardware spec table and the composed-factor method (§3), the lattice line's tokens/s rows (§4.2-4.4), the competitor row (§6), the budget (§7.1) |
| S1 | `results/hashline_pass_12x512.md` (lane UU, 2026-09-02) | the measured row: 23.0 s p50 prove at 8 threads, 2.8 s verify, 66.8 MB, 1.56 GB, 1.26e9 proven MAC/s; the per-phase seconds; the proof-size anatomy; the parameters; the thread-scaling inversion; the tamper legs |
| S2 | `PROGRESS_UPERF3.md`, "Agent UU status (wt-uperf3-uu) — round 11" | the design of record (what is committed, which sumchecks, the LogUp form, the PCS shape); rung 4 (one layer at T = 512: 2.58 s with its phase split); rung 6 (the GPU estimate [MODEL]); the open items (a)-(f) |
| S3 | `hashline/src/pcs.rs`, `sumcheck.rs`, `layer.rs`, `mle.rs`, `ntt.rs`, `merkle.rs`, `bin/hashline.rs` | the loops this memo COUNTS: what each phase does per element, per row, per column; what the prover clock includes |
| S4 | `docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md` §2-3 | the two channels side by side; the B row and its caveats; the "5-15x" hardware note this memo replaces for this mix |
| S5 | `docs/zkmatrix-poc/AGGREGATION_LITERATURE.md` §4 (family (d)), "Addendum 2026-08-11 — Attestable", "Conversion note 2026-08-18" | the FRI / STIR / WHIR / BaseFold / Brakedown rows (WHIR: 63 KiB, 360 us at degree 2^22, 100 bits [abstract verified there]); the competitor's claim and the 3.1e10 MACs-per-token conversion |
| S6 | `docs/zkmatrix-poc/TARGET_CONTRACT.md` §3-4 and Amendment A1; `docs/zkmatrix-poc/ZK_GAP_OPTIONS.md` §6 | what the clock covers; the hardware line; the ZK rule and the P0-P3 private-set modes; the accumulation asymmetry (weights are re-proven every pass, activations are fresh) |
| S7 | `docs/zkmatrix-poc/START_HERE.md` §2, §6 | the plain-language state (cross-checks only) |
| L1 | Ames, Hazay, Ishai, Venkitasubramaniam, "Ligero" (CCS 2017) | the interleaved-code commitment and its zero-knowledge form: random padding of every encoded row, mask rows for every linear check [EXTERNAL] |
| L2 | Golovnev, Lee, Setty, Thaler, Wahby, "Brakedown" (ePrint 2021/1043) | the linear-time, sqrt-size multilinear PCS; the tensor-form opening; its remark that ZK follows by the Ligero techniques [EXTERNAL] |
| L3 | Chiesa, Forbes, Spooner, "A zero knowledge sumcheck and its applications" (ePrint 2017/305); Xie et al., "Libra" (CRYPTO 2019) | zero-knowledge sumcheck by a committed low-degree masking polynomial [EXTERNAL] |
| L4 | Arnon, Chiesa, Fenzi, Yogev, "WHIR" (ePrint 2024/1586) and "STIR" (ePrint 2024/390); Ben-Sasson et al., "FRI" (ICALP 2018); Zeilberger, Chen, Fisch, "BaseFold" (ePrint 2023/1705) | the polylog-size multilinear PCS class and its stated complexities [EXTERNAL] |
| L5 | Xie, Zhang, Song, "Orion" (ePrint 2022/1010) | hiding the column openings of a Brakedown-class commitment inside an inner proof [EXTERNAL] |
| L6 | Papini, Haböck, "Improving logarithmic derivative lookups using GKR" (ePrint 2023/1284) | the LogUp-GKR form that drops the committed helper columns [EXTERNAL] |
| HW | the vendors' spec sheets as copied in S0 §3.2 (RTX 4070 Laptop, RTX 4090, RTX 5090, H100 SXM5 / PCIe); Intel's Core Ultra 9 185H page (memory: LPDDR5x-7467 / DDR5-5600) | SM counts, clocks, memory bandwidths, board power [EXTERNAL, spec sheet]; none measured here |

## 0. The answer in one paragraph

(pending)

## 1. Workloads and MACs per token

(pending)

## 2. The per-proof cost anatomy for Route B: per-model vs per-proof

(pending)

## 3. The hardware factor for THIS mix, as a range

(pending)

## 4. The zero-knowledge surcharge [MODEL, mandatory]

(pending)

## 5. The proof-size lever

(pending)

## 6. The tokens/s table, next to the lattice line

(pending)

## 7. The competitor row, and what a 50 tok/s Route-B design must have

(pending)

## What is not known

(pending)
