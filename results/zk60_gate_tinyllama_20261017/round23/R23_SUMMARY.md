# Gate round 23 summary: draft v3, condition C-9, NL-1 on all 26 real blocks (2026-10-30)

PRIVACY GATE lane. **NOT a privacy acceptance.** Draft v3 goes to Victor through the coordinator. Details, times and
hashes: the round-23 section of `../PROGRESS.md`. EV = `results/zk60_gate_tinyllama_20261017/`.

## What happened

- 02:14-02:21 UTC: draft v3 written from v2 (the re-review's R-1..R-4 and N-1..N-5); N-3 (count_rung re-run, outputs
  byte-identical) and N-1's S3 at every real pair (85 / 85 tight) measured. C-9 launched, NL-1 all-26 queued.
- ~02:50 UTC: the laptop crashed (Windows drive C: full; D46). C-9 had finished block A only; NL-1 was still queued.
- 05:27 UTC resume: **the two runs' inputs were hash-checked first, 120 / 120 files equal** to the hashes recorded before
  the crash (the real capture's 31 manifest files including the 2.25 GB `arrays.bin`, the 80 frozen-v23 tool files,
  the in-code pins, the round-22 wrappers, the guard, the drafts v1 / v2): `INTEGRITY_AFTER_CRASH.json` (`d7afb3b4…`).
  The crashed attempt's partial files were moved aside unread to `crashed_attempt1_0215/` (`MOVED.json`).
- C-9 attempt 2 (05:27:55, the unchanged script) stopped at its 7,200-s cap (guard exit 75) after the census and TS-1
  on A and H: TS-1 rows on the real block are slow (2,584 s, 551 s, and 8,777 s for Input). Attempt 3 (07:28:56,
  `c9b.sh`): the same command, the same unmodified wrapper and class, with only `--max-secs` sized to the job (25,200 s,
  the re-review's note N22-1) and its own output names. It finished at 11:34:14 UTC, exit 0. On everything attempt 2
  reached, the two runs agree (timings aside).
- NL-1 all-26 started at 09:21:34 when its queue found the box quiet, and finished at 09:33:46, exit 0.

## Results [MEASURED, shared box, n = 1]

**Condition C-9** (`c9b-real-block0-ts1-census.json`, `a2d2dea3…`; real block 0 = `stage-01`; light 1.0 / 1.5, 14,718 s,
0.85 GiB): status PASS.

| Role (2^14) | Rows / claims | Groups onto | Disclosed | Census: identical claims / equal published values | TS-1 (honest -> pair removed) |
|---|---|---|---|---|---|
| A | 4,577 / 146 | 36 / 36 | 0 | none / none | fires: 0 -> 32,768 |
| H | 4,390 / 54 | 8 / 9 | 2 (joint {7, 8}) | none / none | fires: 0 -> 32,768 |
| Input | 38 / 2 | 2 / 2 | 0 | none / none | fires: 0 -> 32,768 |

The review controls on block A (group 3, two claims) came out as predicted. C1 (shared reserved pair), C2 (cm = 0) and
G7-D3 fire (2 disclosed each); the honest reference, C3, C6, C8 and G7-D1 disclose 0; G7-D2 is short of rank by 2 and
discloses 0. **C-9's lapse trigger does not fire**: TS-1 fires on A, H and Input, and the census finds no identical
claims and no equal published values. Whether C-9 is met is the security owner's reading.

**NL-1 S1-S5 on all 26 real blocks** (`nl-real-hate-all26.json`, `95fce6d5…`; cpu 2.5 / 3.5, 731 s, 2.60 GiB): PASS.
The 7 R13-changed slots x 26 blocks = 182 slot instances, at the blocks' own gates (G 20 x 18, 19 x 7, 18 x 1):

- T-0 182 / 182, with its control firing 182 / 182; E-0 182 / 182;
- in all four challenge modes, F-0, S1 and S4 182 / 182;
- S3 30 / 30 tight at the six real-shape pairs;
- S5: N5-1 182 / 182, N5-2 130 / 130 (52 not applicable at slack > 0), N5-3, N5-4 and F-1 fire.

## Draft v3

`docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md`, sha256
`c752abe6d8857df28c271e7d1fdfc84371f8a740dc8426d01fb08b8d449d46e4` (82,957 B). Its slots are filled with the two results
above (§0, §3 Step 4, §5 C-9, §10, §11, §12). C-9's lapse trigger is unchanged in §5 and §9. v1 (`db89f427…`) and v2
(`cfbfeafe…`) are unchanged.

## Not measured / notes

- No new capture, prove or checkpoint stream. The classifier slots' T-0 was not repeated (it needs the checkpoint
  stream; round 20 measured 12 / 12).
- NL-1 peaked above its declared need (2.60 GiB RSS, cgroup 2.96 GiB, against need 2.5 and cap 3.5). A re-run should
  declare at least 3.3 GiB.
- C-9 used a 25,200-s cap instead of the coordinator's 7,200 s. This was the lane's sizing decision, stated in the
  ledger; attempt 2's record is kept as it is.
- No job of this lane is pending.
