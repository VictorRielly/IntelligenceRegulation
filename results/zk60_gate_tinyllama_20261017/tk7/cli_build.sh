#!/bin/bash
# PRIVACY GATE lane, round 8 (the D33 re-pin): the CPU command-line binary a
# re-pinned statement would name.  The statement in force names R7's
# `zk60_trained_block.release.bin` (e51cc6a4...), built by the native lane
# from its R7 tree; the token lane built no trained CLI from frozen-r7, so it
# is built here, from the gate's tk7 copy, with the native lane's own command
# (`r7_chain.sh`: cargo build --release --offline --locked -j2 --example
# zk60_trained_block).  The copy differs from frozen-r7 only in
# `run_capture.rs` and the stage-47 module, both `#[cfg(test)]`, so a
# production build compiles frozen-r7's non-test sources.  Waits for the tk7
# heavy queue (the captures), then takes the heavy lock as class build.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/tk7
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk7
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
until [ -f $P/heavy_queue.done ]; do sleep 30; done
cd /tmp
python3 - <<'PY' || { echo "SOURCES MOVED" > $P/cli_build.finished; exit 4; }
import hashlib, os, sys
root = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk7"
bad = [p for d, p in (l.split(None, 1) for l in open("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/tk7/trained-1b-gate-tk7.sources.v1.sha256"))
       if hashlib.sha256(open(os.path.join(root, p.strip()), "rb").read()).hexdigest() != d]
sys.exit(1 if bad else 0)
PY
python3 $G run --class build --need-gib 2.5 --cap-gib 5 --label gate-tk7-cli-build --wait-secs 21600 --max-secs 3600 \
  --log $P/tk7-cli-build.log --done $P/tk7-cli-build.done --result-json $P/tk7-cli-build.guard.json -- \
  /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml --example zk60_trained_block || { date -u > $P/cli_build.finished; exit 5; }
mkdir -p $A/tinyllama-gate-bins
cp $T/hashline/target/release/examples/zk60_trained_block $A/tinyllama-gate-bins/zk60_trained_block.tk7.release.bin
sha256sum $A/tinyllama-gate-bins/zk60_trained_block.tk7.release.bin > $P/zk60_trained_block.tk7.release.bin.sha256
date -u > $P/cli_build.finished
