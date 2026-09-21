# Evidence for `docs/zkmatrix-poc/ZK60_JOINT_LAW_COMPOSITION_RUN.md`

Written 2026-09-20 by a delegated Opus agent (the drafter of that memo),
read-only against the lane worktree `/home/victor/wt-zk60-block125m`, branch
`zk60-private-block-125m`, tip `caa9b9a`. **Nothing here was built or run
against the Rust.** No cargo, no prover, no capture, no hidden value: every
number below is exact integer arithmetic over formulas transcribed from named
source lines, and every input is a public shape constant.

## The one file

`run_law_counts.py` — `python3 run_law_counts.py` prints `run_law_counts.txt`.
It is a Python transcription of five code formulas:

| formula | source |
|---|---|
| `Shape::slots()` → `(main, ext, degree)` per slot | `hashline/src/private_block/shape.rs:603-641` |
| `Shape::slot_lengths()` → `L_s = (main+ext)·deg + 2` | `shape.rs:662-669` |
| `Shape::totals()` → `a_rows = a_data + 2·a_sites + 2`, `h_rows`, `m_rows = 2·23+4` | `shape.rs:672-695`, `layout.rs:896` |
| `boundary::BoundarySpec::commitment_rows()` = `data + 2·sites + 2` | `boundary.rs:180-182` |
| the D9 draw count per hiding commitment: `(rows − data_rows)·n + rows·q` | `pcs.rs:673`, `endpoint_g.rs:227-235`, `boundary.rs:320-328`, `zk.rs:434-457` |

## What it reproduces before it counts anything new

These are the method checks. A number below that did not come out would mean
the transcription is wrong and nothing else in the file is usable.

| reproduced | figure | source of the published figure |
|---|---|---|
| the toy slot table, element for element | `SLOTS` | `layout.rs:815-839` |
| the toy's `dim C` | 560 | `ZK60_JOINT_LAW_COMPOSITION.md` §2.2 |
| the toy's published round values | 721 `Fp2` | same, §1.3 |
| the toy's published terminals | 173 | same, §1.3 |
| the toy's field draws and sampler residual | 327,052 → 2^-77.7 | `ZK60_PRIVACY_CASE_FIRST_MVP.md` item 23, decision D9 |
| the 125M worst masked message length | `L = 117` at `SC_SZC` | `ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §3.7a |
| rung-G's `A` data rows | 377 | `ZK60_NATIVE_RUN_GATE.md` §2.3 |
| rung-G's terminals per stage | 176 | same, §6.1 |
| the rung-G and 125M **receipt byte totals** | 4,234,648 and 40,782,792 | `grow_tests.rs` `MODEL_RUNG_G`, `MODEL_M125` |

## What it computes that was not on paper before

* the shaped slot table, `dim C`, `Σ L_s` and the mask-channel kernel
  dimension at rung-G and at 125M;
* which slots gain a degree from the support indicator at each shape
  (eight at rung-G, six at 125M);
* the D9 draw count and residual for a run of `L` blocks at both shapes;
* the number of base-field values a run's receipt publishes;
* the run's challenge-only refusal rate as `(3L+1)/p`, and the
  **shape-dependent** probability of the one input-dependent refusal class.

## Two numbers it moves

1. **The run's draw count.** `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` §1
   quotes 109.4 million draws for a twelve-block 125M run. Counted from the
   code's own formulas the figure is **109,728,040** (0.33 % higher). The
   residual is **2^-69.3 either way**, so nothing that was quoted changes.
2. **The input-dependent refusal class.** 2^-112.0 is a *toy* figure
   (64,768 inverted LogUp denominators over `|Fp2|`). At 125M the count is
   103,890,944 and the probability is **2^-101.4 per block**, about
   **2^-97.8** for twelve. `ZK60_PRIVATE_RUN_MULTI_BLOCK.md` §5.1 O-R4's
   "12 × 2^-112 ≈ 2^-108.4" is the toy figure carried to a shape it does not
   describe.

## What this is not

It is arithmetic, not a measurement and not a privacy result. It says nothing
about what any of these objects discloses.
