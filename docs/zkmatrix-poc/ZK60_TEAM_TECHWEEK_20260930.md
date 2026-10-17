# Tech Week implementation team — September 29 PDT / September 30 UTC

Victor requests GPT-6.1-Sol and Claude Sonnet 5.5 collaboration, enough agents
to advance the MVP, and a persistent efficiency research lane. The previous
goal turn made verified progress: the real local demonstration and its
acceptance checks landed. Completion of the complete trained private model
MVP remains unproven; a working synthetic demo does not close that objective.

| Owner | Exclusive write lane | Acceptance and handoff |
|---|---|---|
| Integrator | This team record, reviewed integration; `sonnet-hardening/hashline/src/private_block/run.rs` bounded segment IO | Preserve measured candidate and frozen profiles; build offline with locks; combine independently reviewed results |
| Claude Sonnet 5.5 | `ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/mvp_driver.rs`, its example, `HARDENING_DELIVERY.txt` | Valid Unicode JSON, faithful command argv, bounded artifact reads, existing receipt/refusal behavior; no protocol change |
| GPT-6.1-Sol `sol_mvp` | `results/zk60_sonnet_hardening_20260930/sol-review/` | Independent adversarial CLI tests, replay generated argv, inspect changed source and saved receipt identity |
| GPT-6.1-Sol `sol_trained_readiness` | `results/zk60_trained_contract_review_20260930/` | Executable exact-integer norm/window/no-wrap checks and counterexamples; concrete trained-profile handoff |
| Existing Claude calibration lane B | `results/zk60_1b_calibration_20260929/` | Full-block integer reference and held-out trained calibration; ownership preserved |
| Existing Claude profile lane C | `results/zk60_1b_profile_20260929/`, `/tmp/zk60-lane-c-20260929` | Separate trained geometry/profile prototype; ownership preserved |
| Existing Claude presentation lane D | `results/zk60_vc_readiness_20260929/` | Measured evidence and appropriately qualified meeting presentation; ownership preserved |
| Existing hourly researcher | `research/zkp-efficiency/` | Ranked hypotheses, primary-source checks, bounded experiments and implementation handoffs; no duplicate supervisor |

The Sonnet hardening lane is a four-crate source copy with `baseline-pins.json`.
The original `ops/zkp-mvp/candidate` stays the measured integration candidate.
Neither successful parsing nor verification widens privacy acceptance. Root
will retain source diffs, exact commands and completion markers before any
promotion. Build serialization uses `/tmp/zk-build.lock`; heavy proofs/tests
use `/tmp/zk-heavy.lock`. No Git write or worktree approval is a prerequisite.

Next trained-model integration gates remain the checkpoint's actual weights,
full-block calibration and profile binding, trained witness parity, one-block
proof, complete-stack proof, privacy review and CPU/GPU measurement. New
norm-bound findings must be checked against both proof constraints and native
integer execution before profile/calibration work adopts them. Width scaling
alone is not a throughput forecast.
