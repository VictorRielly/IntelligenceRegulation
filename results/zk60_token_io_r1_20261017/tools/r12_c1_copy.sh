#!/bin/bash
# ROUND 12 capture hooks, developed in a scratch COPY of the token-io tree while the R-C1 freeze
# waits for the native window (the tree itself must not move before the freeze). Declared at
# 2.5 GiB (the coordinator's window limit; compile + classifier tests measured 2.07 GiB).
pre() { until out=$(python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py check --class cpu --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done; }
pre 2.5
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 2.5 --cap-gib 4 --label tio-r12-c1-copy --wait-secs 14400 --max-secs 2700 --log /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-c1-copy.log --done /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-c1-copy.guard.done --result-json /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-c1-copy.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path /tmp/claude-1000/-home-victor-IntelligenceRegulation/c08c4558-9df4-474f-a0b5-1bf1cd034626/scratchpad/tio-copy/hashline/Cargo.toml --lib -- token_io::classify_capture_tests --test-threads 2 --nocapture
echo $? > /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-c1-copy.done
