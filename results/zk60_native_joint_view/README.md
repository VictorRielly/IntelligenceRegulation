# `results/zk60_native_joint_view/` — the joint-view gate's record

Produced by `scripts/zk60_native_joint_view.py` on branch
`zk60-native-jointview`. Read `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md`
for what the stages mean and, above all, for what they do NOT establish.
**Nothing here is a privacy acceptance and nothing here establishes a privacy
property**: the record itself says so, in `privacy_property_established` and
`privacy_review_complete`, on every run.

The documented command — the one every re-take of this record uses, unchanged
since the gate was written (§ "Gate" at the top of the report):

```
python3 scripts/zk60_native_joint_view.py \
  --captures results/zk60_native_captures_20260919 \
  --evidence results/zk60_native_joint_view
```

| file | what it is |
|---|---|
| `joint_view.json` | the record: the seven stages (transcript replay, the commitment-side joint view, the masking commitment's view, the stacked view, the zero-witness gate, the negative controls, the terminal-polynomial port), each with its own `ok`, plus `tool_sha256` and the manifest cross-check of the capture directory |
| `joint_view.done` | the exit code (`0` = every stage passed) |

**This README was written in round 9f (2026-09-22)**, because the re-pin
convention is that each record directory's README carries the reason its
record was last re-taken, and this directory had none. The earlier re-takes
are recorded in `results/zk60_native_gate_record_refresh/README.md`, which
holds the table of every re-pin with its cause, and in the ledger
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`.

> **2026-09-22 (round 9f): `joint_view.json` was RE-TAKEN, and only the two
> clocks and two tool digests moved — one of them new.** Finding P36-2 of the
> stage-36 pre-read: after the observers delta, `zkp-core/Cargo.toml` (the
> `test-observers` feature must stay out of `default`) and
> `hashline/Cargo.toml` (it must stay in `[dev-dependencies]`) — and no Rust
> source — decide whether the read-only test observers can compile into a
> release build, and **nothing pinned either file**. Both are now pinned at
> main's `4751b93` bytes in the new `scripts/zk60_native_manifest_pins.py`,
> with a CONTENT assertion beside the digest (a manifest that ships the
> observers is refused BY NAME even at a re-pinned digest), and this gate
> calls the check before it reads anything and exits 3 on a refusal. That
> call is the only change to the gate's own bytes. The documented command
> reproduced this record leaf for leaf apart from
> `tool_sha256/zk60_native_joint_view.py`, the NEW
> `tool_sha256/zk60_native_manifest_pins.py` leaf and the two `seconds`
> leaves (20.7 s → **20.9 s**, every stage `ok`, marker `0`): **4 differing
> leaves, 0 unexpected**. The comparison is
> `results/zk60_native_manifest_pins_20260922/repin_diff.txt`, the reason is
> in `results/zk60_native_gate_record_refresh/README.md`, and the reading is
> §8.8 of `docs/zkmatrix-poc/ZK60_NATIVE_D22_REPIN_4751B93.md`. **No number
> quoted in any report changed.**
