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
| S1 | inventory the 10 OPEN channels from the gate's own `channels` array; classify (a)/(b)/(c) | pending |
| S2 | port the mask-commitment layout (`hashline/src/zk.rs`) into `scripts/zk60_native_mask_commit.py` with source pins | pending |
| S3 | close M's three channels in the gate: disclosed dimension, preimage, M in the joint stage | pending |
| S4 | negative controls on M: a pad removed, the functional order permuted, a second functional leaked | pending |
| S5 | the owed one-liner: the pad-budget guard into the base small-model class; regenerate the affected evidence | pending |
| S6 | report section in `ZK60_NATIVE_JOINT_VIEW.md`; suite green; ledger final | pending |

## 1. Commands and logs

(filled as steps land)

## 2. Findings

(filled as steps land)

## NEXT

S1: run the gate with `--controls-on all` into
`results/zk60_native_privacy_gate_channels/` and read the `channels` array.
