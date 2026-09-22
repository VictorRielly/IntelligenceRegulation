# `results/zk60_native_gate_record_refresh/` — the stale P10 record, established and refreshed

2026-09-20, branch `zk60-native-jointview`. **Nothing here is a privacy
acceptance, nothing here establishes a privacy property, and no figure
quoted in any report changed.** This directory is bookkeeping: it records
what was stale on disk, and it holds the pin that keeps it from happening
again silently.

## What was stale

Commit `d360466` ("M's three OPEN channels closed in the P10 gate") changed
`scripts/zk60_native_privacy_gate.py`, added
`scripts/zk60_native_mask_commit.py` and changed
`scripts/zk60_native_jv_cfs.py`, and refreshed only the newer of the two
committed records. On disk, therefore:

| committed record | last written at | state before this refresh |
|---|---|---|
| `results/zk60_native_privacy_gate/privacy_gate.json` | `825213e` | **stale**: `version` 1, **8 / 2 / 8 / 10**, no `masking_commitment_M_opening`, 7 controls, pre-port `tool_sha256` |
| `results/zk60_native_privacy_gate_channels/privacy_gate.json` | `d360466` | current in every channel (**11 / 2 / 8 / 7**), stale in ONE key: `tool_sha256/zk60_native_jv_cfs.py`, because the gate ran at 05:01 and the pad-budget guard moved into that file at 05:02, inside the same commit |

## The comparison, key by key

`scratch/privacy_gate.json` is the current tool's output, taken with the
documented command into a scratch path so that nothing of record was touched
before the comparison (240.9 s, four captures, exit 0, `gate_scratch.log`).
`jsondiff.py` compares every leaf at its full path.

* `diff_p10_before_refresh.txt` — **218 differing paths**, and every one of
  them is accounted for: the three M channels (`the M opening's q`, `the M
  proximity vector`, `opened column values (the M opening's own 256
  columns)`) on each of the four captures, `open` -> `constructed` with the
  port's fields replacing `reason` / `what_would_close_it`; the two
  `grade.by_status` counters; the new per-capture `masking_commitment_M_opening`
  block; the three M controls (`control_names` 7 -> 10); `version` 1 -> 2 and
  the new `version_2` note; three `tool_sha256` entries; and `seconds`.
  **Nothing else.** `transcript_replay`, `model`, `fixed_inputs`,
  `masking_commitment`, `proof_bytes` and `ok` are identical on all four
  captures, and the other 25 channels are identical entry for entry.
* `diff_channels_before_refresh.txt` — **2 differing paths**: `seconds`
  (wall clock) and `tool_sha256/zk60_native_jv_cfs.py`.

## The refresh

Both records were regenerated in place with the documented command, one after
the other:

```
python3 /home/victor/wt-zk60-jointview/scripts/zk60_native_privacy_gate.py \
  --captures /home/victor/wt-zk60-jointview/results/zk60_native_captures_20260919 \
  --evidence /home/victor/wt-zk60-jointview/results/zk60_native_privacy_gate \
  --columns full --controls-on all
python3 /home/victor/wt-zk60-jointview/scripts/zk60_native_privacy_gate.py \
  --captures /home/victor/wt-zk60-jointview/results/zk60_native_captures_20260919 \
  --evidence /home/victor/wt-zk60-jointview/results/zk60_native_privacy_gate_channels \
  --columns full --controls-on all
```

**249.1 s** and **267.7 s**, four captures `ok`, markers `0`; logs
`gate_refresh_p10.log` / `.done` and `gate_refresh_channels.log` / `.done`.
Each refreshed record is identical to `scratch/privacy_gate.json` leaf for
leaf **except `seconds`**, so the gate is deterministic at this shape over
three independent runs (the box was shared, which is the whole of the 240.9
/ 249.1 / 267.7 s spread). Nothing was copied and nothing was deleted: the
old bytes of both records stay in git history, correct at the commits named
above.

## The guard

| file | what it is |
|---|---|
| `channel_counts_of_record.json` | the channel-label counts OF RECORD — 28 channels, 11 / 2 / 8 / 7 — the one place `tests/test_zk60_native_gate_record.py` and section 14.1 / 15 of `ZK60_NATIVE_JOINT_VIEW.md` both cite |
| `guard_before.log`, `.done` | the new test BEFORE the refresh: **6 tests, FAILED (failures=2)** — the counts of the older record, and the `tool_sha256` of both |
| `guard_after.log`, `.done` | the same test after the refresh: **6 tests, OK** |
| `suite_after.log`, `.done` | the whole `test_zk60_native*.py` set after the refresh: **Ran 193 tests in 269.1 s, OK** (1 skip, 1 expected failure), against 187 before this lane (`results/zk60_native_run_gate/tests_after.log`) — the six new ones are this guard |

The test re-derives the counts from each committed record's own `channels`
array, compares them with the record's own `grade.by_status`, with the pin,
and with the `after` row of the channel table in section 14.1 of the report,
and compares each record's `tool_sha256` with the hashes of the tools now in
the tree — the convention `tests/test_zk60_native_run_gate.py` already
follows. A tool edited without re-running the gate now turns the suite red.

`scratch/` is a working copy of the current tool's output, kept so the
comparison above can be re-read without re-running the gate. It is not a
record of anything.

## The re-pins, each with its reason

The pinned hashes are not literals in a table: each committed record carries
the `tool_sha256` map of the tools that produced it, and the guard compares
that map with the tools now in the tree. So a re-pin is a **re-take of the
record with the documented command**, never an edited key, and the rule is
that a re-pin has to name the tool bytes that moved and why. Every one so
far:

| date | tools whose bytes moved | why | evidence |
|---|---|---|---|
| 2026-09-20 | `zk60_native_privacy_gate.py`, `zk60_native_mask_commit.py` (new), `zk60_native_jv_cfs.py` | commit `d360466` ported M's row layout and closed M's three OPEN channels; one of the two records had never been re-taken and the other was stale in one key | this directory (above) |
| **2026-09-22 (round 9e)** | `zk60_native_jv_capture.py` (`191f8bc9…` → `11f598d1…`), `zk60_native_privacy_gate.py` (`c33a27fb…` → `abaa316d…`), `zk60_native_joint_view.py` (`ca48c67a…` → `c66181aa…`) | the manifest cross-check **skipped itself silently** on a delivered bundle whose manifest is named `capture-validation.json` and whose `accepted` is one record (round 9d, `ZK60_NATIVE_D22_REPIN_4751B93.md` §8.5 observation 1, §8.7). `manifest_check` now reads either name and either shape and **refuses by name** where the cross-check cannot be made; the two gates take the declaration flag and exit 3 on a refusal. The gates' own bytes moved only because each lists the other's file in its `TOOLS` table | `results/zk60_native_manifest_check_20260922/` |
| **2026-09-22 (round 9f)** | `zk60_native_manifest_pins.py` (**new**, `1b08589a…`), `zk60_native_privacy_gate.py` (`abaa316d…` → `819079dd…`), `zk60_native_joint_view.py` (`c66181aa…` → `97601b89…`) | finding **P36-2** of the stage-36 pre-read: after the observers delta, `zkp-core/Cargo.toml` (the feature must stay out of `default`) and `hashline/Cargo.toml` (it must stay in `[dev-dependencies]`) decide whether the read-only test observers compile into a release build, and **nothing pinned either file**. Both are now pinned at main's `4751b93` bytes, with a CONTENT assertion beside the digest so that a manifest which ships the observers is refused by name even at a re-pinned digest. The two gates call the check before any analysis and exit 3 on a refusal; their bytes moved for that call alone, and the new file is in both `TOOLS` tables. The Rust pin tables (`mask_commit.py`, `terminal_polys.py`) were deliberately left byte-identical: they are named by 122 and 8 committed records | `results/zk60_native_manifest_pins_20260922/` |

**What the 2026-09-22 re-pins did NOT move.** In BOTH rounds the three
records were re-taken with the commands in their own READMEs and compared
leaf by leaf with their committed bytes — round 9e against `d837d50`, round
9f against `025e1ac` (`repin_diff.txt` in each round's own directory) — and
in both the only differences are the `tool_sha256` entries named above and
`seconds`. Round 9f adds one leaf rather than moving it: the new
`zk60_native_manifest_pins.py` entry, which is what makes the record name
every tool whose bytes can turn a run into a refusal. For round 9e, in
particular each record's `manifest` block is **identical**, because the
directory they are taken from has always had a `validation.json` with a list
`accepted` — the shape the fix leaves alone. A test pins that: the fixed
function's answer on that directory is compared, key for key, with
`d837d50`'s answer on it.
