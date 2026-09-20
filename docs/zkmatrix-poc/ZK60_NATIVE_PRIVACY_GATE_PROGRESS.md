# Ledger — the block-scope privacy gate P10 (`zk60_native_privacy_gate.py`)

Lane `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`,
opened 2026-09-20 01:40 (PDT). Sole writer: one delegated Opus implementer
working for the security owner. PYTHON ONLY — no cargo, no builds, no GPU.

**What this lane builds.** A NEW tool, `scripts/zk60_native_privacy_gate.py`,
that does what the existing joint-view tool does not: for each captured
receipt it **constructs and exhibits** a preimage of the verifier's linear
view under a FIXED hidden input (the all-zero one, and a pseudorandom one
from a public seed), by solving exactly over the Goldilocks field, verifies
it by recomputing the view entry by entry, and labels **every** channel of
the privacy case's §2 as CONSTRUCTED / DERIVED / ARGUED / OPEN in a
machine-readable record. Definition: `ZK60_PRIVACY_CASE_FIRST_MVP.md` §4
(gate P10, rewritten under ruling C-6), §2 (the view, channel by channel);
`ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md` §8 (what the first definition lacked,
and the two controls it proposes).

**This is not a privacy acceptance and does not establish a privacy
property.** It is a statement about the linear channels of four captured
receipts at two toy layouts.

## 0. Status

| # | item | state |
|---|---|---|
| S0 | skeleton ledger, baseline test run | DONE (85 tests, 72.8 s, OK, 1 skipped) |
| S1 | the linear model: `y`, `M_data`, `M_nondata` per role, written down | pending |
| S2 | the exact constructive solver (msg block, pad block, infeasibility) | pending |
| S3 | the CFS / masked-round channel | pending |
| S4 | the `channels` array: every §2 channel labelled, fail rules | pending |
| S5 | negative controls, each shown to pass honest and fail perturbed | pending |
| S6 | tests, evidence, report, ledger close | pending |

## 1. Commands and logs

| what | command | log |
|---|---|---|
| baseline suite | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native*.py'` | `results/zk60_native_privacy_gate/tests_baseline.log` (Ran 85 in 72.8 s, OK) |

## 2. Findings

(pending)

## 3. NEXT

S1: write the model down and check which capture fields carry `y`.
