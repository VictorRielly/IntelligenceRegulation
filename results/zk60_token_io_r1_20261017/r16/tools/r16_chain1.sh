#!/bin/bash
# TOKEN ROUND 16, chain 1: (a) the round's tests with --nocapture (their [COUNTED] lines; incremental build after the
# doc-only edits; need 5.0 / cap 6.0 from g2's measured 3.97 GiB + 25%), (b) the three items' activations, (c) the
# zk60_classify binary, (d) the FIRST real prove (sexual), declared from Sol's measured R13 L00 T128 prove peak 7.67 GiB
# + 25% = 9.6 / cap 11.5. Stops at the first failure. Marker logs/chain1.done.
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/tools/r16_common.sh
RS=$T/tools/r16_real.sh
hold; gap; lean
echo "$(date -u +%FT%TZ) facts start" >> $L/queue.log
$G --class build --need-gib 5.0 --cap-gib 6.0 --label tio16-facts --wait-secs 14400 --max-secs 2400 --log $L/facts.log --done $L/facts.guard.done --result-json $L/facts.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify_r16_tests --nocapture --test-threads=1
rc=$?; echo $rc > $L/facts.done; [ $rc = 0 ] || { echo "facts=$rc" > $L/chain1.done; exit; }
echo "$(date -u +%FT%TZ) act start" >> $L/queue.log
$RS act "" 6 8; rc=$(cat $L/real-act.done); [ "$rc" = 0 ] || { echo "act=$rc" > $L/chain1.done; exit; }
echo "$(date -u +%FT%TZ) cli start" >> $L/queue.log
$RS cli; rc=$(cat $L/real-cli.done); [ "$rc" = 0 ] || { echo "cli=$rc" > $L/chain1.done; exit; }
echo "$(date -u +%FT%TZ) prove sexual start" >> $L/queue.log
$RS prove sexual 9.6 11.5; rc=$(cat $L/real-prove-sexual.done)
echo "$(date -u +%FT%TZ) chain1 end prove=$rc" >> $L/queue.log
echo "facts=0 act=0 cli=0 prove-sexual=$rc" > $L/chain1.done
