#!/bin/bash
# ROUND 12: the registry gates (s24 / s25 / s33) with the classifier profile registered, plus the
# classifier tests; pre-check outside the lock, then the guard. Marker logs/r12-t5-registry.done.
pre() { until out=$(python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py check --class cpu --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done; }
pre 4
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 4 --cap-gib 7 --label tio-r12-t5-registry --wait-secs 14400 --max-secs 2700 --log /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-t5-registry.log --done /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-t5-registry.guard.done --result-json /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-t5-registry.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline/Cargo.toml --lib -- s24_tests s25_tests s33_tests token_io::classify --test-threads 4 --nocapture
echo $? > /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-t5-registry.done
