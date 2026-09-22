# `results/zk60_native_profile_pins_20260922/` — the private-attention profile's three files join the pin set (round 9h)

2026-09-22, branch `zk60-native-jointview`, base commit `28853ac`. **Nothing
here is a privacy acceptance, nothing here establishes a privacy property,
and no figure quoted in any report changed.** This directory is the evidence
for one bookkeeping change to the hash-pinned TOY gate: three Rust files that
the attention profile's prover and verifier reach, and that no pin table
named, are now pinned.

## Why

Round 9g read the pin tables out (`ZK60_NATIVE_RUN_GATE_PROGRESS.md` §R9g.8)
and found three files in none of them — not in
`zk60_native_mask_commit.SOURCE_PINS`/`PATH_PINS`, not in
`zk60_native_terminal_polys.SOURCE_PINS`, not in any `zk60_native_rg_*`
table, not in the Rust capture writer's 38-file list:

* `hashline/src/private_attention.rs`
* `hashline/src/private_attention/wire.rs`
* `hashline/src/private_attention/witness.rs`

**Two of the four toy captures of record are attention-profile receipts**
(`hashline-zk-mr1/private-attention-t32-poc/1`, `validation.json` of
`results/zk60_native_captures_20260919`), so for those two the gates read
artifacts whose prover and verifier reach three files nothing compares: a
change to any of them would trip no gate. That is condition 7 of the toy
profile's accepted privacy statement ("every file on the path") unmet. The
security owner ruled on 2026-09-22 that the three join the pin set.

## That they really are on the path (read at `4751b93`, by call site)

| file | why it is on the prover's or the verifier's path |
|---|---|
| `private_attention.rs` | the profile's ROOT. `hashline/src/lib.rs:49` declares `pub mod private_attention;` with no `cfg` and no feature gate; the file holds `AttentionPublic`, `IoSpec`/`ExpectedIo`/`prepare_endpoints`, `compute_output` (236), `prove`/`prove_with_stats` (270/274), `verify` (285), `verify_bytes` (311), `Receipt::{to_bytes,from_bytes}` (298/303) |
| `private_attention/witness.rs` | the PROVER's integer witness: `witness::build` at `private_attention.rs:277` (prove) and `:236` (compute_output); its `Witness` is the argument of `protocol::prove_inner` (`protocol.rs:12`, `:259`) |
| `private_attention/wire.rs` | BOTH sides: `wire::validate` is the first statement of `protocol::verify_inner` (`protocol.rs:419`); `wire::encode`/`decode` are `Receipt::to_bytes`/`from_bytes`, so `verify_bytes` decodes through it |

None is `#[cfg(test)]`: the root declares `mod wire;` (line 45) and
`mod witness;` (line 46) with no attribute above them, and the line that IS
gated — `#[cfg(test)] mod tests;` (48-49) — is the next one. The profile's
other three files (`argument.rs`, `layout.rs`, `protocol.rs`) were already
pinned by `zk60_native_terminal_polys.SOURCE_PINS` (and `argument.rs` again
by `zk60_native_mask_commit.SOURCE_PINS`, at the same digest), so the
profile's six files are now complete.

## The three pins

`git --no-pager -C <main tree> show 4751b93:<path> | sha256sum`:

| path | sha256 | git blob |
|---|---|---|
| `hashline/src/private_attention.rs` | `dfc02d91356974b0cf4c6c0c672ec14660aa4b90b808236de81486272f010923` | `1bc8f8911f91ff66709f8186393774e3845ad3d7` |
| `hashline/src/private_attention/wire.rs` | `a35a468cf19eb672e5428c3286a3ece15f73e96e20291a220cf38dd4104dbdff` | `26e2166984b7164743683b0a2fb34cf3d732644f` |
| `hashline/src/private_attention/witness.rs` | `795cf6292e366bc48d1c1987b9a3173f9a19e266de537f72a9e738bdb5133ee0` | `0c9f7b60847e913ef81034bea7f62ed72db050e6` |

`bundle_crosscheck.txt`: each digest agrees with **four** independent
readings — main at `4751b93`, the block lane at `a8e4939`, this worktree, and
the delivered new-tree bundle's 132-entry `source_hashes`
(`results/zk60_native_d22_replay_20260922/bundle/validation.json`, read-only,
not committed here). Unlike round 9f's two Cargo manifests, **the lane has
not touched these three**, so there is no post-integration digest to expect
and nothing for the integrator's re-pin to move; `LANE_DIGESTS` records that
as data and the guard asserts it.

**Digest only, no content assertion.** Round 9f's manifests carry one because
a Cargo manifest can be re-pinned blind and still ship a test-only feature —
the property there is a fact about the file's meaning. The property here is
the one the pin set exists for, *these are the bytes the four captures of
record were produced and verified by*, and a sha256 is exactly that.

## Where the pin lives, and why not in an existing table

In a new module, `scripts/zk60_native_profile_pins.py`, called by both toy
gates before they read anything (exit **3**, no record, on a refusal).

* Not in `zk60_native_mask_commit.PATH_PINS`, the natural home: that file is
  named by **122** committed records' `tool_sha256` maps — the whole RUN-gate
  series over the real 125M bundles — each asserted equal to the tool bytes in
  the tree by its own test, so one byte there would stale ~115 records and
  demand their re-take on bundles this round has no business re-running
  (`terminal_polys.py`: 8 records plus its own `port_sha256`). This is round
  9f's reason, unchanged.
* Not folded into `zk60_native_manifest_pins.py`, which has the same shape and
  the same callers: that module is the two CARGO MANIFESTS and finding P36-2,
  its error type and its refusal line say "Cargo manifest pins", and Rust
  source pins filed under a name that says "manifest" would mislead the reader
  at the moment the refusal fires. The cost of the separate file is one more
  tool leaf in the three records — which this round re-takes anyway.

**Unconditional, not gated on the capture's profile.** A gate run reads a
capture DIRECTORY, and the directory of record holds all four captures — two
block receipts and two attention ones — so a per-profile branch would never
be taken differently in any run of record; and for a block run these three
are simply files that must not have moved either (the delivered bundle's
`source_hashes` carries them). One rule, no branch. A test asserts the call
takes no profile argument and comes before `load_all`.

## Failing first

`failing_first.py` loads `zk60_native_mask_commit.py`,
`zk60_native_terminal_polys.py` and `zk60_native_manifest_pins.py` **as they
stood at `28853ac`, straight out of git**, so the pre-change column keeps
printing after the change has landed. `failing_first_before.log` was taken
before the gates were wired, `failing_first_after.log` after; the pre-change
column is identical in both. Three synthetic trees, each a copy of every file
the toy gate pins with ONE file tampered with — one line each, of the kind
that matters:

| tampered file | the one-line change |
|---|---|
| `private_attention.rs` | `mod wire;` → `pub mod wire;` (the frame's internals become public API) |
| `private_attention/wire.rs` | the `!hiding_ok(&r.h_open, …)` clause deleted from `validate`, so the verifier stops checking H's opening shape |
| `private_attention/witness.rs` | `if !(lo..=hi).contains(&q)` → `if false && …`, so the prover's fixed-oracle range refusal never fires |

| case | before (`28853ac`) | after |
|---|---|---|
| 1. each tampered tree, every pin check the gate HAD | **30, 8 and 2 pinned files checked, NO refusal** in all three trees; neither gate's source mentions `private_attention.rs`, `private_attention/` or `profile_pins` | — |
| 2. the same three trees, the profile pins | — | `ProfilePinError` in each, **naming its own file**, digest against digest |
| 3. CONTROL: the tree as it stands | — | accepted, three digests equal to their pins of record |
| 4. the LANE's bytes at `a8e4939` (read-only, from the main checkout) | — | accepted — byte-identical to main |
| 5. the two gates, check pointed at a tampered tree | **no such check** ("has NO attention-profile pin check (pre-change)") | `main()` → **3**, `REFUSED (attention profile pins): …`, **no record written** |

## The re-pin

Three tool digests move, so every record naming them was re-taken with the
command in its own README (`run.sh`, all three exit 0):

| tool | at `28853ac` | now | why |
|---|---|---|---|
| `zk60_native_profile_pins.py` | *(did not exist)* | `3689bbb3…` | the three pins |
| `zk60_native_privacy_gate.py` | `819079dd…` | `040891a7…` | the call before any analysis, and the exit-3 refusal |
| `zk60_native_joint_view.py` | `97601b89…` | `383b4f97…` | the same |

| record | before | after | what moved |
|---|---|---|---|
| `results/zk60_native_privacy_gate/privacy_gate.json` | 224.8 s | **225.2 s**, four captures `ok` | 1 tool hash + 1 NEW tool hash + `seconds` — **3 leaves** |
| `results/zk60_native_privacy_gate_channels/privacy_gate.json` | 221.3 s | **221.6 s**, four captures `ok` | the same **3 leaves** |
| `results/zk60_native_joint_view/joint_view.json` | 20.9 s | **21.3 s**, every stage `ok` | 1 tool hash + 1 NEW tool hash + three `seconds` — **5 leaves** |

`repin_diff.txt` compares each with its own committed bytes at `28853ac`,
leaf by leaf: **0 unexpected differences** — no channel, rank, dimension,
control or count moved. The reason is written into the guard's own record
(`results/zk60_native_gate_record_refresh/README.md`) and into each record
directory's README.

## Files

| file | what it is |
|---|---|
| `failing_first.py` | the five cases above, pre-change column loaded from git at `28853ac` |
| `failing_first_before.log` | taken before the gates were wired: case 5 reads "has NO attention-profile pin check (pre-change)" |
| `failing_first_after.log` | the same script after: case 5 is `main() -> 3`, no record |
| `bundle_crosscheck.py`, `bundle_crosscheck.txt` | the three digests against main `4751b93`, lane `a8e4939`, this worktree and the delivered bundle's `source_hashes` |
| `guard_before.log` | the record guard BEFORE the re-pin: **42 tests, FAILED (failures=1)** — the records name the old gate bytes, which is exactly what the re-pin is for |
| `run.sh`, `run.log`, `run.done` | the three re-takes, detached under `flock /tmp/zk-heavy.lock` inside a `systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0` scope |
| `repin_diff.py`, `repin_diff.txt` | what the re-pin moved, leaf by leaf, against `28853ac` |
| `suite.sh`, `suite.log`, `suite.done` | the toy gate's seven modules and the record guard, queued on the same lock: **Ran 217 tests in 211.2 s, OK** (skipped=1, expected failures=1) — 204 in round 9f, the thirteen new ones are this round's — and the record guard alone **42 tests, OK** (29 in round 9f) |
