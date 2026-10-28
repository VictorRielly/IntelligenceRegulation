# Dated update to the round-14 DD gate report: the pending T128 L2 records, 2026-10-21 05:30 UTC

Written by the PRIVACY GATE lane, a delegated Claude Opus 5.5 agent. It is a
separate note. The report it updates,
`EV/round14/DD_GATE_REPORT_R9_20261021.md` (sha256 4dd9dd91…), is not
edited. It closes that report's §6 list.

| Status | **Gate evidence. It is NOT a privacy acceptance.** |
|---|---|

## The records that were pending at 02:10 UTC [MEASURED]

All of them use frozen tools v17: every record's `tool_sha256` equals the
v17 manifest ff68af54….

**Everything + controls, T128 DD L2 dense** (`EV/round14/v17/tl128dd-l2-dense-everything.json`):
**PASS**, 0 unexplained false leaves.

- Replay 9,984 / 261, with the binding reproduced.
- Terminals **48 / 48**. Stage 1 is evaluated at layer 1's own constants,
  bound to the schedule digest.
- **Full zero-data preimage: 7 commitments, 3,786,805 view entries,
  0 differing**, every commitment solved and exhibited.
- Mask / CFS 33,812 / 0. Joint 3,820,617 / **0**, all four couplings
  respected.
- Export check ok. E3b layers [0, 1]; E5 stage 1 equals layer 1 at its own
  constants; E4 equal.
- Negative controls ok.
- 5,522 s (full preimage 4,099 s), peak 1.96 GiB.

**Everything + controls, T128 DD L1 dense, official run** (`…/v17/tl128dd-l1-dense-everything.json`):
**PASS**, 0 unexplained, 6,375 s (slower under load), 1.83 GiB.

- Every summarized randomness-free figure equals the dev11 record the
  report cited: replay, terminals, per commitment, full preimage 1,905,229 /
  0, mask 16,906 / 0, joint 1,922,135 / 0, export and controls.

**The DD surjection on T128 L2** (`EV/round14/dd_long/`, 4-hour cap), dense
(5,636 s) and zero (6,014 s), 1.10 GiB each. On each capture, at both
stages:

- A: **0**, 38 / 38 groups onto.
- H: **2**, 9 / 10 onto, joint component {7, 9} = 2.
- Input and Output: 0.
- **DS-1** (slot 23's 8-claim A group, one reserved pair removed: 0 → 2 Fp)
  and **DS-2** (the tuple helper's 4-claim H group: 0 → 2) fire.
- The review's controls on stage 0's first two-member A group behave as of
  record.

**The rest of the DD tools:**

- T128 L1 zero DD surjection: the same figures as L1 dense, controls ok.
- T128 L2 dense / zero DD NL-1: PASS.
- T128 L2 dense / zero DD controls: DT-1..DT-7, 7 / 7.

**Queue A's copies of the two T128 L2 surjections** hit their 1-hour cap
(guard exit 75), as the report predicted. They are superseded by the
`dd_long/` records above, from the same tools on the same captures.

## The round's totals

- **13 staged records, all PASS** with 0 unexplained false leaves:
  - 8 pass A;
  - 5 everything (rung L1 dense / zero, rung L2 dense, T128 L1 dense,
    T128 L2 dense).
- **8 / 8 predictions validated**, 12 / 12 figures each.
- **DD NL-1: 8 / 8 PASS.**
- **DD controls: 8 / 8**, 7 / 7 each.
- **DD surjection: 8 / 8**:
  - A 0 and H 2 at every stage;
  - DS-1 / DS-2 fire at every stage.
- Controls:
  - TL: 19 / 19, 16 / 16, 24 / 24 and 24 / 24.
  - EXP-1..4 and EX-1 / 2 / 3 / 6 fire.
  - G-10: 8 / 8 on all three pairs.
  - PC-0..PC-11: 12 / 12 exact.
  - Schema: ok.
  - Witness comparison at T128 L2: 118 / 128 figures identical. Only distinct
    opened columns, pad margins and the pad block differ.
- Summary: `EV/round14/r14-summary.json` (880f194b…).

## Still queued (duplicates only)

The coordinator's hold of 04:35:43Z (`EV/HOLD`, "native R12 freeze + token
classifier tests need memory") is holding the rest of queue A:

- its own copies of the control tail that queue C already ran: TL, export
  controls, schema, G-10, pin controls, the witness comparison;
- the v17 unit suite in the working copy.

That suite ran 79 tests OK there before the freeze. The v18 suite, a superset
with 81 tests, ran OK in round 15. These jobs add no new figure. They will
run when the hold is lifted.

**None of this is a privacy acceptance.**
