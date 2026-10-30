#!/bin/bash
# TOKEN ROUND 16, g1: build the rebased + ported tree from scratch, then the focused batch: the round's tests, every
# classifier test, the registry censuses (s24 / s25 / s33 / hash_domain), run_capture, the R13 accuracy loader /
# profile tests. need 3.9 / cap 4.8 (r14 g2 peaked 3.12 GiB RSS; the census now builds two 805 MB Shieldstral tables).
source /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r16/tools/r16_common.sh
hold; gap; lean
echo "$(date -u +%FT%TZ) g1 start" >> $L/queue.log
$G --class build --need-gib 3.9 --cap-gib 4.8 --label tio16-g1 --wait-secs 14400 --max-secs 3000 --log $L/g1.log --done $L/g1.guard.done --result-json $L/g1.guard.json -- $ENV $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- token_io::classify s24_tests s25_tests s33_tests hash_domain run_capture trained_accuracy accuracy_profile_tests --test-threads=4
echo $? > $L/g1.done
echo "$(date -u +%FT%TZ) g1 end $(cat $L/g1.done)" >> $L/queue.log
