#!/bin/bash
# Round 8, part B (after part A, tools/r8_chain.sh: t33, the round-8 CLI, the verifier copies and the
# three `profile` runs): the three approval records, the T128 demo chains (8B b7voc0_T128, 8B
# dg_rot1_voc0_T128, TinyLlama dg_rot1_T128; each: pre-check, prove, verify, verify again, owner,
# input-owner; guard needs from the measured peaks), the 8B public-file cross-checks, the full suite and
# the final manifest. Ends by writing logs/r8_round.done with the exit code (the coordinator's release
# signal for the light-job hold), on success or failure.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline
X=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
B=$D/zk60_token_io.r8.release.bin
finish() { echo "$1" > $L/r8_round.done; exit 0; }
until [ -f $L/r8_chain.done ]; do sleep 15; done
# (20:2x UTC, the coordinator's order: the rest of part B moved to tools/r8_round_v2.sh, TinyLlama first)
exec bash /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/tools/r8_round_v2.sh
