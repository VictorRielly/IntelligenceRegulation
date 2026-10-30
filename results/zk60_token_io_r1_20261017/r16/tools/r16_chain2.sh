#!/bin/bash
# TOKEN ROUND 16, chain 2 (written after the first real prove; never edited while it runs):
#   r16_chain2.sh PNEED PCAP VNEED VCAP
#   1. the FROZEN r15 binary on the real R13 T128 export: must refuse (failing-first at the CLI: no profile)
#   2. moderate-sexual: verify, input-owner, label (fresh processes)
#   3. moderate-violence, moderate-hate: prove, verify, input-owner, label
# Declarations: prove PNEED / PCAP and verify-class steps VNEED / VCAP, from the first prove's / verify's measured
# peaks + 25%. Each step through r16_real.sh (hold, gap, lean). Stops at the first unexpected exit. Marker chain2.done.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/tools/r16_common.sh
RS=$T/tools/r16_real.sh
PN=$1; PC=$2; VN=$3; VC=$4
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
B15=$R/cli/zk60_classify.r15.release.bin
step() { echo "$(date -u +%FT%TZ) $1" >> $L/queue.log; }
finish() { echo "$1" > $L/chain2.done; step "chain2 end $1"; exit 0; }
hold; gap; step red-r15
$G --class cpu --need-gib 1.5 --cap-gib 3 --label tio16-red-r15 --wait-secs 14400 --max-secs 900 --log $L/red-r15-binary.log --done $L/red-r15-binary.guard.done --result-json $L/red-r15-binary.guard.json -- $B15 verify --export $EX --tables $EX/token_io --policy shieldstral-1.0-3b-card-unsafe/1 --artifact /home/victor/zk60-artifacts/token-io/r16-runs/sexual-run --expect-statement 0000000000000000000000000000000000000000000000000000000000000000 --min-bits 95
echo $? > $L/red-r15-binary.exit
[ "$(cat $L/red-r15-binary.exit)" = "1" ] || finish red-r15-not-refused
for s in verify owner label; do
  step "$s sexual"; $RS $s sexual $VN $VC; [ "$(cat $L/real-$s-sexual.done)" = 0 ] || finish $s-sexual
done
for c in violence hate; do
  step "prove $c"; $RS prove $c $PN $PC; [ "$(cat $L/real-prove-$c.done)" = 0 ] || finish prove-$c
  for s in verify owner label; do
    step "$s $c"; $RS $s $c $VN $VC; [ "$(cat $L/real-$s-$c.done)" = 0 ] || finish $s-$c
  done
done
finish 0
