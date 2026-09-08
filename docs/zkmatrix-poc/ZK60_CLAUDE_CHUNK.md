# CL6 — chunk rows are a memory knob, not a speed knob

Task: `zk60_claude_tasks.json` CL6 ("tune chunk scheduling against both time
and memory"). Tools: `scripts/hashline_cl_chunk_sweep.py` (24 tests in
`tests/test_hashline_cl_chunk_sweep.py`), the corrected planner
`scripts/hashline_memory_plan.py` (25 tests). Oracle:
`every_chunk_row_choice_matches_the_cpu` in `hashline/tests/zk60_gpu_commit.rs`
(13 device cases). Measurement: `results/cl6_chunk_sweep.sh`, log
`results/cl6_chunk_sweep.log`, marker 0, per-run logs
`results/cl6_sweep_p3_c{128,256,512}_r{1,2}.log`.

**Diagnostic, not a headline.** One Mistral layer on the 8 GB laptop, two
repeats per choice in ABAB order, not quiesced-certified. The BYTE results
are exact; the seconds are indicative.

---

## 1. The finding in one table [MEASURED, WSL-BOX, RTX 4070, P3, one Mistral layer, n=2]

| chunk rows | chunks (W/A/H) | prove s (r1, r2) | chunked commits s | chunked re-encodes s | VRAM peak MB | planner W component MiB | proof |
|---:|---|---|---:|---:|---:|---:|---|
| **128** (default) | 85 / 29 / 24 | 4.111, 4.049 | 0.622, 0.629 | 0.577, 0.579 | **5,182** | 1,563 | `190e85a1..` / 40,251,860 B |
| 256 | 43 / 15 / 12 | 4.174, 4.005 | 0.615, 0.626 | 0.573, 0.570 | 5,349 | 1,707 | identical |
| 512 | 22 / 8 / 6 | 4.039, 4.011 | 0.617, 0.626 | 0.568, 0.560 | 5,651 | 1,995 | identical |

**Time does not move.** The three chunked commits take 0.62 s and the three
chunked re-encode openings 0.57 s at EVERY choice, inside 2%; the prove
clock's 4.0-4.2 s spread is this box's noise, not the chunk size. Going from
85 chunks to 22 chunks of W removes 63 kernel-launch groups and buys nothing
measurable: the chunk loop is bandwidth-bound on the encoded scratch, and
that traffic is the same whatever the chunk height.

**Memory does move, and the planner predicted it.** Peak VRAM rises
+167 MB at 256 and +469 MB at 512; the planner's chunked W component rises
+144 MiB and +432 MiB. The measured deltas are ~8% larger because the pool
retains the bigger chunk scratch through the helper phase, where the layer's
peak actually sits (rung 5 of `ZK60_CLAUDE_GPU.md`), and A and H reuse it by
`take_min`. The planner's chunked mode is therefore reconciled against a
measured high-water mark in the conservative direction it should be: it
under-predicts the whole-layer delta by ~8% and says so (it counts one
commitment, not the layer).

**The proof is byte-identical at every choice** — at Mistral width (all six
runs `190e85a1d3bebdc3..` / 40,251,860 B, the value CL1 rung 4 and lane AM
both recorded) and at the frozen 12x512 `zkv3` fixture with chunking FORCED
at 128, 256, 512 and 1024 rows (`40eb5479..` / 87,697,008 B, four gates in
the sweep log). The oracle covers the corners the sweep cannot: a choice
that is not a multiple of 128 (300 steps by 256), `rows <= choice` (one
chunk of all rows), ragged tails at every step, rates 2/4/8 and pads 16/64.

---

## 2. What this decides

1. **Keep `HL_GPU_CHUNK_ROWS=128`.** It is the smallest legal step (one blake3
   chunk of a column), it has the lowest peak, and it is not slower. Lane AJ's
   round-14 reasoning for 128 ("a 128-row chunk is 67 MB against a 32 MB
   L2") was not the mechanism — 67 MB does not fit L2 either — but the
   choice was right for the reason measured here: the chunk height does not
   set the speed, so the memory-minimal choice wins.
2. **No budget-based chunk selector is promoted.** CL6 says "if justified,
   implement a deterministic budget-based chunk selector with a retained
   fixed reference path". It is not justified: a selector can only choose a
   LARGER chunk than 128 (the clamp), and larger buys no time and costs
   memory. The deterministic selection rule exists in the sweep tool
   (`plan --scratch-budget-mib`, largest choice whose commit scratch fits an
   EXPLICIT budget, refusing a budget that is not below nominal VRAM) for
   whoever needs the memory arithmetic, and nothing in `cuda.rs` reads free
   VRAM or changes the chunk height on its own.
3. **The opening re-encode, not the chunk schedule, is the lever.** 0.57 s of
   the 4.05 s prove (14%) is the three chunked ZK re-encodes, and unlike the
   commits they write a full encoded chunk and read it back only to keep
   256 columns of it. That is CL7 (`ZK60_CLAUDE_RESIDENCY.md`).

---

## 3. The planner correction that fell out

The device's `chunk_plan` takes ALL rows as one chunk when `rows <= choice`
(the unrounded choice), and only when it must split does it step by
`(choice // 128) * 128`. The planner counted `min(rows, step)`, which
undercounted the single-chunk corner for a choice that is not a multiple of
128: 300 rows at choice 300 allocate 300 rows of scratch on the device; the
old count said 256. Fixed in `hashline_memory_plan.py` and pinned by
`test_the_cl3_planner_now_agrees_with_the_device_in_that_corner` and by the
sweep tool's own mirror (`plan_summary`), which refuses to select on a
mismatched count.

---

## 4. Limits

- Two repeats on a box that is not quiesced-certified; the seconds are not a
  p95 and are not published as one.
- Single-layer Mistral width only; no 8B pass was run (the rule stands).
- 1024 rows was byte-gated at the frozen fixture but not timed at Mistral
  width: with nothing to gain at 512 there was no reason to spend the
  headroom, and the planner puts its whole-layer prediction at ~6.2 GB.
- The sweep does not vary `HL_GPU_CHUNK_BYTES` (the by-size threshold);
  at Mistral width every hiding commitment chunks by size regardless.
