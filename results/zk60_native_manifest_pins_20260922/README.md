# `results/zk60_native_manifest_pins_20260922/` — the two Cargo manifests join the pin set (round 9f)

2026-09-22, branch `zk60-native-jointview`, base commit `025e1ac`. **Nothing
here is a privacy acceptance, nothing here establishes a privacy property,
and no figure quoted in any report changed.** This directory is the evidence
for one bookkeeping change to the hash-pinned TOY gate: two files that decide
a production-identity claim, and were pinned by nothing, are now pinned —
by digest AND by content.

## Why

Finding **P36-2** of the stage-36 pre-read
(`ZK60_D22_CONDITION7_PREREAD_STAGE36.md` §7, review branch). After the
stage-36 delta the answer to *"can a release build compile
`ZkRng::consumed_bytes` and `Transcript::squeezes`?"* lives in two manifests:

* `zkp-core/Cargo.toml` — the feature must stay out of `default`;
* `hashline/Cargo.toml` — it must stay in `[dev-dependencies]`.

A one-word edit in either would put the accessors into the production library
with **every Rust source, every `cfg` gate and every existing pin unchanged**,
and neither file was in `zk60_native_mask_commit.SOURCE_PINS`/`PATH_PINS`, in
`zk60_native_terminal_polys.SOURCE_PINS`, or in the Rust capture writer's
38-file list.

## What was done

| # | thing | where |
|---|---|---|
| 1 | the two pins, at main's `4751b93` bytes, with the reason naming P36-2 | `scripts/zk60_native_manifest_pins.py`, `MANIFEST_PINS` |
| 2 | the CONTENT assertion beside the digest, as data + a quote-aware TOML scanner (Python 3.10 here has no `tomllib`, no `tomli`, no `toml`) | the same file, `MANIFEST_POLICY` / `assert_manifest_policy` / `read_manifest` |
| 3 | both toy gates call the check **before any analysis** and exit **3** on a refusal, writing no record; the new file is in both `TOOLS` tables | `scripts/zk60_native_privacy_gate.py`, `scripts/zk60_native_joint_view.py` |
| 4 | 17 tests | `tests/test_zk60_native_gate_record.py`, class `TheCargoManifestsArePinnedAndAsserted` |
| 5 | the re-pin of the three records of record | `run.sh`, `run.log`, `run.done`, `repin_diff.py`, `repin_diff.txt` |

**The pins** (`git --no-pager -C <main tree> show 4751b93:<path> | sha256sum`):

| path | sha256 | git blob |
|---|---|---|
| `zkp-core/Cargo.toml` | `b9038a52f34e0ee8313aa93eec656ff62ea29571a04b3df7f3db349d623ba842` | `e3d46e4e2d52eda49a3ae10611345b538384f090` |
| `hashline/Cargo.toml` | `eaba50ecf1434ad8514feb83c6e610b0d662b8fd6d512f26bacdde69163b860a` | `8a670755028ecc1c8d20086530cd9aa5d1d733fc` |

**The content assertion, exactly as enforced** (`MANIFEST_POLICY`):

* `zkp-core/Cargo.toml`: `[features]`'s `default` must be **absent or empty**
  — no feature at all on by default — and the token `test-observers` may
  appear **only in a `[features]` table**, i.e. in no `[dependencies]`, no
  `[build-dependencies]` and no `[target.*.dependencies]` section;
* `hashline/Cargo.toml`: the token may appear **only in a dev-dependency
  section** (`[dev-dependencies]`, `[target.*.dev-dependencies]`) — not in
  `[dependencies]`, not in `[features]`, not anywhere else;
* a manifest the scanner cannot parse is **refused, never passed**.

## Failing first

`failing_first.py` loads `zk60_native_mask_commit.py` and
`zk60_native_terminal_polys.py` **as they stood at `025e1ac`, straight out of
git**, so the pre-change column keeps printing after the change has landed.
`failing_first_before.log` was taken before the gates were wired,
`failing_first_after.log` after; the pre-change column is identical in both.
The tree it tests is synthetic: a copy of every file the toy gate pins, with
`zkp-core/Cargo.toml` replaced by the pinned bytes plus
`default = ["test-observers"]` (sha256 `2af0bb66…`).

| case | before (`025e1ac`) | after |
|---|---|---|
| 1. the tampered tree, both Rust pin tables | **30 and 8 pinned files checked, NO refusal**; neither gate's source mentions `Cargo.toml`, `manifest_pins` or `test-observers` | — |
| 2. the same tree, the manifest pins | — | `ManifestPinError`, naming `zkp-core/Cargo.toml`, digest against digest |
| 3. the same tree, **digest force-accepted** | — | still refused: `[features] default = ["test-observers"]` (line 9), naming the file, the line and P36-2 |
| 4. `hashline` with the observers in `[dependencies]`, digest force-accepted | — | refused, naming the section and the line |
| 5. the LANE's real manifests at `a8e4939` (read-only, from the main checkout), digests force-accepted | — | **accepted**: `default` absent, the token only in `[features]` (zkp-core) and `[dev-dependencies]` (hashline) |
| 6. CONTROL: the tree as it stands | — | accepted, both digests equal to their pins of record |
| 7. the two gates, check pointed at the tampered tree | **no such check** | `main()` → **3**, `REFUSED (Cargo manifest pins): …`, **no record written** |

## The re-pin

Three tool digests move, so every record naming them was re-taken with the
command in its own README (`run.sh`, all three exit 0):

| tool | at `025e1ac` | now | why |
|---|---|---|---|
| `zk60_native_manifest_pins.py` | *(did not exist)* | `1b08589a…` | the pins and the content assertion |
| `zk60_native_privacy_gate.py` | `abaa316d…` | `819079dd…` | the call before any analysis, and the exit-3 refusal |
| `zk60_native_joint_view.py` | `c66181aa…` | `97601b89…` | the same |

| record | before | after | what moved |
|---|---|---|---|
| `results/zk60_native_privacy_gate/privacy_gate.json` | 224.9 s | **224.8 s**, four captures `ok` | 1 tool hash + 1 NEW tool hash + `seconds` — 3 leaves |
| `results/zk60_native_privacy_gate_channels/privacy_gate.json` | 222.1 s | **221.3 s**, four captures `ok` | the same 3 leaves |
| `results/zk60_native_joint_view/joint_view.json` | 20.7 s | **20.9 s**, every stage `ok` | 1 tool hash + 1 NEW tool hash + two `seconds` — 4 leaves |

`repin_diff.txt` compares each with its own committed bytes at `025e1ac`, leaf
by leaf: **0 unexpected differences**, so no channel, rank, dimension, control
or count moved. The reason is written into the guard's own record
(`results/zk60_native_gate_record_refresh/README.md`) and into each record
directory's README — `results/zk60_native_joint_view/README.md` was created
in this round, because that directory had none.

## Why the pins are NOT in `zk60_native_mask_commit.PATH_PINS`

That is where the Rust path pins live (round 5, the owner's ruling of
2026-09-20 22:06), and it would be the natural home. But `mask_commit.py` is
named by **122** committed records' `tool_sha256` maps — the whole RUN-gate
series over the real 125M bundles, not only the toy gate's three records —
and each of those records is asserted equal to the tool bytes now in the tree
by its own test. One byte changed there would stale ~115 run-gate records and
demand their re-take on bundles this round has no business re-running; the
same holds, smaller, for `terminal_polys.py` (8 records plus its own
`port_sha256`). Keeping the new table in its own file confines the re-pin to
the three records of record — exactly round 9e's set — and the record guard
holds the two tables together: it fails if either manifest is unpinned, if
any Rust pin table ever names one at a different digest, or if a gate stops
calling the check.

## What the pins are NOT at yet

The block lane (`a8e4939`) already carries the stage-36 manifests — sha256
`0c746b9d…` (zkp-core, `[features] test-observers = []` plus an explicit
`resolver = "2"`) and `10d99a63…` (hashline, the dev-dependency that enables
it). They are **recorded and deliberately not accepted**
(`EXPECTED_AFTER_INTEGRATION`): the pin moves once, against the integrator's
merged tree, after those bytes have been read there. The content assertion
already accepts them (case 5 above), so that re-pin will be a digest move and
nothing more. The pre-read's table quotes a third pair (`90156d58…` /
`5633d1e4…`) taken in the REVIEW worktree before P36-3 added the resolver
line; neither pair is accepted here.

## Files

| file | what it is |
|---|---|
| `failing_first.py` | the seven cases above, pre-change column loaded from git at `025e1ac` |
| `failing_first_before.log` | taken before the gates were wired: case 7 reads "has NO manifest-pin check (pre-change)" |
| `failing_first_after.log` | the same script after: case 7 is `main() -> 3`, no record |
| `guard_before.log` | the record guard BEFORE the re-pin: **29 tests, FAILED (failures=1)** — the records name the old gate bytes, which is exactly what the re-pin is for |
| `run.sh`, `run.log`, `run.done` | the three re-takes, detached under `flock /tmp/zk-heavy.lock` inside a `systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0` scope |
| `repin_diff.py`, `repin_diff.txt` | what the re-pin moved, leaf by leaf, against `025e1ac` |
| `suite.sh`, `suite.log`, `suite.done` | the toy gate's seven modules and the record guard, queued on the same lock: **Ran 204 tests in 210.0 s, OK** (skipped=1, expected failures=1) — 187 in round 9e, the seventeen new ones are this round's — and the record guard alone **29 tests, OK** (12 in round 9e) |
