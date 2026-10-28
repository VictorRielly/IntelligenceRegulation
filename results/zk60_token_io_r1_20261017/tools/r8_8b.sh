#!/bin/bash
# Round 8 follow-up (the coordinator, ~21:3x UTC): once part B has written logs/r8_round.done (the other
# lanes' release), run the two 8B T128 demos that part B skipped at its 23:00 cutoff, declared at the
# measured peak plus margin (prove 8 / cap 10, checks 6 / 8), each followed by its public-file
# cross-check. A demo part B completed is not repeated. Own marker: logs/r8_8b.done (exit code: 0 when
# every demo it ran ended with its input-owner step at exit 0).
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
D=$R/cli
X=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
B=$D/zk60_token_io.r8.release.bin
until [ -f $L/r8_round.done ]; do sleep 30; done
RC=0
for P in "r8 r8x llama3_8b_pg_rot1_b7voc0_T128" "r8dg r8dgx llama3_8b_dg_rot1_voc0_T128"; do
  read T0 T EN <<< "$P"
  if [ "$(cat $L/$T0-d7-cli-input-owner.exit 2>/dev/null)" = "0" ]; then
    continue
  fi
  /usr/bin/env TAG=$T EXPORT=$X/$EN BIN=$B NO_SUITE=1 PROVE_NEED=8 PROVE_CAP=10 VERIFY_NEED=6 VERIFY_CAP=8 bash $R/tools/r4_cli_demo.sh >> $L/r8_8b_demo_$T.log 2>&1
  [ "$(cat $L/$T-d7-cli-input-owner.exit 2>/dev/null)" = "0" ] || RC=1
  TOK=$(python3 -c "import json;l=[json.loads(x) for x in open('$L/$T-d6-cli-owner.log') if x.startswith('{\"event\":\"next-token\"')];print(l[-1]['token'])" 2>/dev/null)
  if [ -n "$TOK" ]; then
    $G --class light --need-gib 3.5 --cap-gib 5 --label tio-p8-crosscheck-$T --wait-secs 14400 --max-secs 1800 --log $L/p8-crosscheck-$T.log --done $L/p8-crosscheck-$T.guard.done --result-json $L/p8-crosscheck-$T.guard.json -- python3 $R/tools/crosscheck_cli_next_token.py $X/$EN ho00 $TOK $R/runs/r8_crosscheck_${EN}_ho00.json
    echo $? > $L/p8-crosscheck-$T.exit
  fi
done
echo $RC > $L/r8_8b.done
