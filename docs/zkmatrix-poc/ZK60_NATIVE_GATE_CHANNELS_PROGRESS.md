# ZK60 — the P10 gate's open channels: inventory, the mask-commitment port, M's closure

Lane ledger. Worktree `/home/victor/wt-zk60-jointview`, branch
`zk60-native-jointview`, opened 2026-09-20 04:37 PDT off 1857c04.

**Nothing in this lane is a privacy acceptance and nothing here establishes a
privacy property.** The P10 gate is a consistency gate on four captured
receipts at two fixed toy layouts: it replays them with exact linear algebra
and reports, channel by channel, whether a preimage was exhibited. Every
statement below is scoped to those four captures.

## 0. Status

| step | what | state |
|---|---|---|
| S0 | ledger skeleton, lane opened | done |
| S1 | inventory the 10 OPEN channels from the gate's own `channels` array; classify (a)/(b)/(c) | done |
| S2 | port the mask-commitment layout (`hashline/src/zk.rs`) into `scripts/zk60_native_mask_commit.py` with source pins | pending |
| S3 | close M's three channels in the gate: disclosed dimension, preimage, M in the joint stage | pending |
| S4 | negative controls on M: a pad removed, the functional order permuted, a second functional leaked | pending |
| S5 | the owed one-liner: the pad-budget guard into the base small-model class; regenerate the affected evidence | pending |
| S6 | report section in `ZK60_NATIVE_JOINT_VIEW.md`; suite green; ledger final | pending |

## 1. Commands and logs

**S1, the baseline** (2026-09-20 04:40 PDT, detached under `setsid nohup`):

```
python3 /home/victor/wt-zk60-jointview/scripts/zk60_native_privacy_gate.py \
  --captures /home/victor/wt-zk60-jointview/results/zk60_native_captures_20260919 \
  --evidence /home/victor/wt-zk60-jointview/results/zk60_native_privacy_gate_channels \
  --columns full --controls-on all
```

- `results/zk60_native_privacy_gate_channels/gate_baseline.log`, `.done` = 0,
  192.7 s, four captures, all `ok`.
- `results/zk60_native_privacy_gate_channels/tests_baseline.log`, `.done` = 0:
  `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p
  'test_zk60_native*.py'` — **Ran 139 tests in 185.1 s, OK (skipped=1, expected
  failures=1)**.

## 2. Findings

### F1 — the inventory (S1)

28 channels, **8 CONSTRUCTED / 2 DERIVED / 8 ARGUED / 10 OPEN**, and the
`by_status` count is byte-identical on all four captures. The ten OPEN
channels, with the gate's own reason abbreviated, and this lane's
classification:

| # | channel | § | class | why |
|---|---|---|---|---|
| 1 | the M opening's `q` | 2.1 | **(a)** | the gate does not model M's row layout; "no capture field is missing" |
| 2 | the M proximity vector | 2.1 | **(a)** | same port: the `u` row is not modelled |
| 3 | opened column values (M's own 256 columns) | 2.1 | **(a)** | same port: the a-row pads are not modelled |
| 4 | whether a proof attempt produced a receipt | 2.2 | **(c)** | refusal event; a capture only exists when the proof was ACCEPTED, so no capture can ever show it (ruling C-2) |
| 5 | rejected-but-emitted receipts | 2.2 | **(c)** | procedural condition on the deployment (history item H8); not a linear channel |
| 6 | retained captures | 2.2 | **(c)** | procedural condition (H9); a retained capture IS a published opening |
| 7 | timing, memory, power | 2.2 | **(c)** | out of scope for the first MVP (M-5, C-2); no capture field bears on it |
| 8 | prior proofs by the same prover | 2.2 | **(c)** | multi-receipt composition, chain item 21 / open item U-3b |
| 9 | the integer-range facts the statement implies | 4.2 r16 | **(c)** | chain item 20: information no preimage argument removes |
| 10 | any nonlinear functional of the joint view | 4.2 r17 | **(c)** | the terminal identity is degree 4; this gate is linear |

**No channel is class (b).** Nothing in this inventory needs a capture field
that does not exist, so no field is requested from the integrator, and in
particular no field that is a function of hidden data (the security owner
already refused one such, a slot's unmasked honest rounds).

The (c) channels stay ARGUED-or-OPEN by design. The memos that carry them:
`ZK60_JOINT_LAW_COMPOSITION.md` (revised) for #8 and #10 (the composition of
the channels into one law, and the nonlinear link), and
`ZK60_HASH_LAYER_AND_FS_LIFT.md` (revised) for the refusal-rate counting that
#4 rests on. #5, #6, #7 and #9 are deployment or scope conditions, not
channels a linear model can close.

## NEXT

S2: port `zk.rs::mask_commit` / `mask_open` / `mask_verify` and the declared
functional order from `private_block/argument.rs` into
`scripts/zk60_native_mask_commit.py`, with source pins.
