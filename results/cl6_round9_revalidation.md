# CL6 chunk sweep, revalidated under the CL14 evidence contract

[ZK60-CL14] 2026-09-07. Codex's round-9 review showed that
`scripts/hashline_cl_chunk_sweep.py measure` accepted a prover log whose
`HASHLINE_TIMING` said `prove_s: -1` and which ended in `exit 1`, and
reported it as `prove_s=-1`, `byte_identical_across_choices: true`. The
tool never saw an exit status and never checked a clock. The review did
not declare the archived CL6 sweep invalid on that account; it asked
whether the archived rows satisfy a stronger contract. This file answers
that. Machine-readable record: `results/cl6_round9_revalidation.json`
(the exact command, every input's SHA-256, per row the evidence channels,
the gate outcome and reasons, the clocks, the digests, and the
reconciliation).

## Verdict

**The prior CL6 conclusion survives.** All six archived rows
(`results/cl6_sweep_p3_c{128,256,512}_r{1,2}.log`, bound to
`results/cl6_chunk_sweep.log`) pass the corrected contract:
6 eligible, 0 refused, 0 missing-evidence. Nothing was invented for any
log: every required item is present in the archived text itself.

| choice | observed rmax | prove s | chunked commit s | chunked re-encode s | VRAM peak MB | proof | exit |
|---|---|---:|---:|---:|---:|---|---|
| 128:1 | 128 | 4.111 | 0.622 | 0.577 | 5182 | 190e85a1d3bebdc3.. / 40251860 B | 0 (CL6_RUN (per-run log)) |
| 256:1 | 256 | 4.174 | 0.615 | 0.573 | 5349 | 190e85a1d3bebdc3.. / 40251860 B | 0 (CL6_RUN (per-run log)) |
| 512:1 | 512 | 4.039 | 0.617 | 0.568 | 5651 | 190e85a1d3bebdc3.. / 40251860 B | 0 (CL6_RUN (per-run log)) |
| 128:2 | 128 | 4.049 | 0.629 | 0.579 | 5182 | 190e85a1d3bebdc3.. / 40251860 B | 0 (CL6_RUN (per-run log)) |
| 256:2 | 256 | 4.005 | 0.626 | 0.570 | 5349 | 190e85a1d3bebdc3.. / 40251860 B | 0 (CL6_RUN (per-run log)) |
| 512:2 | 512 | 4.011 | 0.626 | 0.560 | 5651 | 190e85a1d3bebdc3.. / 40251860 B | 0 (CL6_RUN (per-run log)) |

The original statement — "chunk rows are a MEMORY knob, not a speed knob:
128/256/512 prove in 4.0–4.2 s with flat commit/re-encode seconds while
VRAM peak climbs as the planner predicts" — reads off this table unchanged:
prove 4.005–4.174 s across all six rows; chunked commit 0.615–0.629 s and
re-encode 0.560–0.579 s at every choice; VRAM peak 5,182 / 5,349 / 5,651 MB
against the planner's 5,183 / 5,327 / 5,615 MB printed in the sweep log.
The two repeats of the SAME choice differ by as much as the choices differ
from each other (256 rows: 4.174 s then 4.005 s), which is the reason no
speed ranking follows from these seconds.

## What each row had to show

- **Exit status.** The archived per-run logs carry no `exit N` line and no
  `CMD:` line. Their exit evidence is the sweep runner's
  `CL6_RUN chunk_rows=<c> rep=<r> exit=0 sha256=<h> bytes=<b>` line, which
  `results/cl6_chunk_sweep.sh` writes with `tee -a` into BOTH the per-run
  log (its last line) and the sweep log. The tool binds each row to the
  sweep-log record by (chunk_rows, rep) and requires the two copies to
  agree field for field; both say exit 0 for all six runs, and their
  sha256/bytes equal each per-run log's `PROOF sha256` line. Absent both
  channels the row would have been classified `missing-evidence` and the
  comparison refused.
- **The CL5 validated-row gate** (`hashline_cl_profile.attribute`, reused
  as is): `PASS-V3 ACCEPT` present with `proof 40251860 B` matching TIMING;
  `verified` and `serialized` true; all five clocks finite and positive;
  `witness_s + prove_s + serialize_s` 0.003–0.010 s under
  `proof_ready_s` (never over); the `prover phases` block sums to within
  1.5 ms of `prove_s` against an 11 ms tolerance; `gpu: ON` with
  `gpu_requested` and `gpu_enabled` true; privacy P3, coverage ffn-only,
  shape 1 x 512 (d 4096, f 14336). Eligible on every row.
- **Chunk-sweep additions:** each label's chunk-row choice matches the
  log's own commit lines (85/43/22 chunks of <= 128/256/512 for the
  10,774-row W, and the 3,601- and 3,033-row commits likewise); one PROOF,
  one PASS, one TIMING, one CL6_RUN per log; digests identical
  (`190e85a1…`, 40,251,860 B); privacy, coverage, shape, randomness label,
  verdict, device line and cache state identical across the set.

Cache state is `unknown` on every row, uniformly: the per-run logs record
no command line, so the CL5 gate notes it rather than refusing (the runner
script shows the invocation carried no `--wcache`, and P3 refuses the
cache anyway). It is the same on all six rows, so the set is consistent.

## What this does not say

- These are single-box diagnostic seconds on an RTX 4070 Laptop GPU with
  n=2 per choice, not a p95 and not quiesced-certified. The 0–4.2 %
  `prove_vs_fastest` spread is inside rep-to-rep noise.
- **No chunk-row selector is promoted** from equal digests or from these
  seconds (`selector_promoted: false` in the record). The memory
  selection remains `plan --scratch-budget-mib`, an explicit operator
  budget.
- The half-1 frozen-fixture gates in the sweep log (`40eb5479…`,
  87,697,008 B at 128/256/512/1024) are recorded as provenance; the tool
  does not re-verify them.
- The sweep ran at lane HEAD `9b249755…` with 1 tracked file modified and
  binary `0040cd84…` (5,318,584 B), before the H1 merge and the round-8
  cache fix; nothing here extends that evidence to the combined tree
  (CL17's job).

Command (from the worktree `/home/victor/wt-zk60-cl1`):

```
python3 scripts/hashline_cl_chunk_sweep.py measure \
  --log 128:1=results/cl6_sweep_p3_c128_r1.log --log 256:1=results/cl6_sweep_p3_c256_r1.log \
  --log 512:1=results/cl6_sweep_p3_c512_r1.log --log 128:2=results/cl6_sweep_p3_c128_r2.log \
  --log 256:2=results/cl6_sweep_p3_c256_r2.log --log 512:2=results/cl6_sweep_p3_c512_r2.log \
  --sweep-log results/cl6_chunk_sweep.log            # add --markdown for the table above
```

Exit 0. The record in `cl6_round9_revalidation.json` was produced by the
same command with absolute paths (its `command.argv` field).
