# Addendum, 2026-10-21: gate round 12 — the ten harness captures re-captured on frozen-r9

Written 2026-10-21 (00:05 UTC) by the PRIVACY GATE lane, a delegated Claude
Opus 5.5 agent. **This is a separate note.** It does not edit the frozen drafts:
v2 (`EV/round10/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT_v2.md`, 34562422…)
and v3 (`EV/round11/PRIVACY_STATEMENT_NEXT_TOKEN_T32_DRAFT_v3.md`, 97853f25…).
It fills v3's dated slot §10 item 2.

| Status | **Gate evidence. It is NOT a privacy acceptance.** It answers privacy review round 5's PR5-4 (`results/zk60_privacy_review_trained_t32_20261017/REVIEW5.md`). Only the security review process can accept, and rulings are Victor's. |
|---|---|

EV means `results/zk60_gate_tinyllama_20261017/`. Labels: [MEASURED], [COUNTED], [READ].

## Result

**Every randomness-free figure on the frozen-r9 re-captures equals the
figure on the frozen-r7 captures of the same name: 10 of 10 captures, every
compared record [MEASURED].** So the carry PR5-4 rests on holds. The
measured figures now replace the carried ones.

The re-captures really are fresh. A figure that depends on which columns
were opened differs as expected. For example, `tinyllama-t32-L2-dense-pt1`
compared 2,494,851 view entries on r9 and 2,500,124 on r7 [MEASURED].

## What was done

- **Tree** [MEASURED]: `ops/zkp-mvp/token-gate-r9/`.
  - It is an unmodified rsync of frozen-r9: 236 of 236 files equal
    `results/zk60_token_io_r1_20261017/manifest_final_r9.sha256`, none moved,
    no gate patch (`EV/round12/verify_copy.json`).
  - The captures therefore pin exactly frozen-r9's files.
  - The test binary is `hashline-1339dd732ed3d3e7`, sha256 36d29238…
    (`EV/round12/hashline-lib-test-release.r12.sha256`).
- **Captures** [MEASURED]: `~/zk60-artifacts/token-io-r9-gate/captures/<name>/`.
  - Source label `frozen-r9-b666a991-gate-copy`.
  - Ten captures, the same names as the frozen-r7 set: TinyLlama T32 at
    L = 1, 2 and 22, and Llama-3-8B T32 at L = 1 and 2, each dense and fixed.
  - Every capture exited 0. Each was verified with the recorder attached.
  - Peak memory per capture: 0.98–3.49 GiB (`EV/round12/cap-*.guard.json`).
  - Queue: `EV/round12/r12_heavy.sh`.
- **Gate** [MEASURED]: frozen tools **v16** (`EV/gate-tinyllama.tools.frozen.v16.sha256`, 8e33c998…).
  - Each of the three gate queues checked the tools first: 65 listed, 0
    moved (`EV/round12/r12_gate_{a,b,c}.toolcheck`).
  - Records: 10 token-gate records, 10 NL-1, 12 surjection (10 plus the two
    L = 1 block surjections) and one calibration-attribution record over all
    ten: 33 records in all, every one exit 0.
  - Paths: `EV/round12/{gate,nl,ts,cal}/`.
  - Queues: `EV/round12/r12_gate_{a,b,c}.sh`. All of them finished on
    2026-10-20, the last at 10:11 UTC.
- **Comparison**: `EV/round12/compare_r12.py`, sha256 e71b6962…, which reads JSON only. Its output is
  `EV/round12/compare_r12.json` (220ff5dd…).
  - r9 records are compared with the frozen-r7 records of the same capture
    name:
    - token gate: round 7, tools v10, `EV/token_io/v10/token-v10-<cap>.json`;
    - NL-1 and surjection: round 10, `EV/round10/{nl,ts}/`;
    - calibration: `EV/round10/cal/v16-cal-all.json`.
  - **Compared** (randomness-free):
    - statuses and false parts;
    - replay counts and the reproduced run binding;
    - hashed bytes and columns;
    - for every commitment: role, class, stage kind, rows, data rows,
      disclosed and expected dimension, claims, groups, k0, rank of P1,
      reserved pairs and mask rows;
    - G-3: the functionals and recomputed mask entries per stage;
    - the joint and its word pairs;
    - the full preimage's commitments, salted leaves and differing entries;
    - terminal slot counts and the block-stage terminal parts;
    - controls fired and not applicable;
    - the NL-1 summary;
    - the surjection summary, with TS-1's and the review controls' figures;
    - the absorbed calibration word.
  - **Not compared**, because they depend on the opened columns or are wall
    clock: view entries compared, pad margins and timings.

## The figures (r9, measured; each equal to r7's)

| Capture | Token gate | Stages | Disclosed Fp, each A / B / E commitment | Disclosed Fp, each H commitment | Joint | Full preimage differing | Controls | NL-1 | Surjection disclosed |
|---|---|---|---|---|---|---|---|---|---|
| tinyllama-t32-L1-{dense,fixed} | PASS | 3 | 0 each | 2 each | 0 = sum of parts | 0 (2,560 salted leaves authenticated) | 38 / 38 fire | PASS (T-0 15/15, S3 45/45) | 0, except H-in 2 and H-out 2 |
| tinyllama-t32-L2-{dense,fixed} | PASS | 4 | 0 each | 2 each | 0 = sum | 0 (3,328 leaves) | 38 / 38 | PASS (15/15, 45/45) | same |
| tinyllama-t32-L22-{dense,fixed} | PASS | 24 | 0 each | 2 each | 0 = sum | 0 (18,688 leaves) | 38 / 38 | PASS (15/15, 45/45) | same |
| llama3-8b-t32-L1-{dense,fixed} | PASS | 3 | 0 each | 2 each | 0 = sum | 0 (2,560 leaves) | 38 / 38 | PASS (15/15, 40/40) | same |
| llama3-8b-t32-L2-{dense,fixed} | PASS | 4 | 0 each | 2 each | 0 = sum | 0 (3,328 leaves) | 38 / 38 | PASS (15/15, 40/40) | same |

More figures from the same records:

- **Terminals.** On the 15 token slots: 15 / 15 equal. Every block-stage
  slot is equal. Integrity source pins: ok, read at frozen-r9's pins.
- **Block surjection** (TinyLlama L = 1, dense and fixed):
  - BLOCK:A disclosed 0 over 36 groups;
  - BLOCK:H disclosed 2 (9 groups, 8 surjective);
  - BLOCK:Input disclosed 0;
  - controls ok.
- **Calibration attribution:** 10 / 10 ok, controls ok. The absorbed
  calibration words equal r7's:
  - TinyLlama L1 45537596…, L2 3287884a…, L22 5a89f1d3…;
  - Llama-3-8B L1 c47635ce…, L2 c7e85519….

The 2 Fp disclosed per H commitment is the figure the draft and the
accepted T32 statement already carry for every H commitment. It is equal
here to the frozen-r7 figure, so nothing new is disclosed.

## What this does and does not establish

- It establishes that the frozen-r7 → frozen-r9 carry of the ten harness
  figures (PR5-4) agrees with measurement on frozen-r9 code. The decision
  item "the harness figures are carried" (PR5-3) can now cite measured
  frozen-r9 figures instead of a reading.
- It does not cover the CLI-path capture. That is gate round 15: the
  re-pin onto frozen-r11 and a re-capture with the r11 binary 0c9f247c…,
  in a separate note.
- It does not establish any privacy property beyond the records it reports.
  **NOTHING HERE IS A PRIVACY ACCEPTANCE.**
