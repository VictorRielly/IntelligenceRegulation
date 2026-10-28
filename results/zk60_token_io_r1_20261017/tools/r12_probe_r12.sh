#!/bin/bash
# ROUND 12: the rebase probe onto NATIVE R12 (scratch tree tio-r12 = R-C1 + capture hooks + native
# R8->R12, 3 adjacency conflicts resolved), the FULL suite, --no-fail-fast; declared from s16's
# measured 6.77 GiB. Marker logs/r12-probe-r12c.done.
python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class cpu --need-gib 7.5 --cap-gib 9.5 --label tio-r12-probe-r12c-suite --wait-secs 14400 --max-secs 3600 --log /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-probe-r12c.log --done /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-probe-r12c.guard.done --result-json /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-probe-r12c.guard.json -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path /tmp/claude-1000/-home-victor-IntelligenceRegulation/c08c4558-9df4-474f-a0b5-1bf1cd034626/scratchpad/tio-r12/hashline/Cargo.toml --no-fail-fast -- --test-threads=8
echo $? > /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r12-probe-r12c.done
