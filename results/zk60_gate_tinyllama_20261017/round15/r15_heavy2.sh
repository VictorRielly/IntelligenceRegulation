#!/bin/bash
# PRIVACY GATE lane, gate round 15, second heavy queue (for D33's part): the
# trained-block CPU CLI built from the gate's UNMODIFIED frozen-r11 copy with
# the native lane's own command, then run on review P-18's inputs (layers
# 7..9, checked against their manifests first): stack-prove, and stack-verify
# in a fresh process with --expect-statement ef061000... (the tk7 / tk9 run's
# identity). Measured (tk9): build ~4 min at 1.6 GiB; prove 1.02 GiB / 6.1 s;
# verify 0.27 GiB / 1.3 s. A hold-file check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round15
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-gate-r11
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
HOLDF=$E/HOLD
cd /tmp
until [ -f $P/r15_heavy.done ]; do sleep 30; done
g() {  # g <class> <label> <need> <cap> <max> -- cmd...
  local c=$1 l=$2 n=$3 k=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class $c --need-gib $n --cap-gib $k --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/r15_heavy2.progress
  return $rc
}
python3 - <<'PY' || { echo "SOURCES MOVED" > $P/r15_heavy2.finished; exit 4; }
import hashlib, os, sys
root = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-gate-r11"
man = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/manifest_final_r11.sha256"
bad = [p for d, p in (l.split(None, 1) for l in open(man) if l.strip())
       if hashlib.sha256(open(os.path.join(root, p.strip()), "rb").read()).hexdigest() != d]
print("moved", bad)
sys.exit(1 if bad else 0)
PY
g build r15-cli-build 1.8 3 3600 -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml --example zk60_trained_block || { date -u > $P/r15_heavy2.finished; exit 8; }
mkdir -p $A/tinyllama-gate-bins
CLI=$A/tinyllama-gate-bins/zk60_trained_block.r11.release.bin
[ -e $CLI ] && { echo "BINARY EXISTS" > $P/r15_heavy2.finished; exit 8; }
cp $T/hashline/target/release/examples/zk60_trained_block $CLI
sha256sum $CLI > $P/zk60_trained_block.r11.release.bin.sha256
XP7=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
SEQ=$A/tinyllama-cli-r7-seq-ho00
VX=$A/tinyllama-cli-r7-verifier-export
RUN=$A/tinyllama-cli-r11-run-l2
mkdir -p $P/cli
python3 - "$SEQ" "$E/r7cli/inputs.seq-ho00.sha256" "$VX" "$E/r7cli/inputs.verifier-export.sha256" > $P/cli/inputs.check 2>&1 <<'PY' || { echo "INPUTS MOVED" > $P/r15_heavy2.finished; exit 9; }
import hashlib, os, sys
bad = 0
for root, man in ((sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])):
    n = 0
    for line in open(man):
        d, p = line.split(None, 1)
        p = p.strip()
        n += 1
        if hashlib.sha256(open(os.path.join(root, p), "rb").read()).hexdigest() != d:
            print("MOVED", root, p); bad += 1
    print(root, n, "listed")
print("bad", bad)
sys.exit(1 if bad else 0)
PY
[ -e $RUN ] && { echo "RUN DIR EXISTS" > $P/r15_heavy2.finished; exit 10; }
g cpu r15-cli-stack-prove 1.5 2.5 1800 -- $CLI stack-prove --export $XP7 --seq-dir $SEQ --out $RUN --layers 7..9 --label zk60-trained-stack || { date -u > $P/r15_heavy2.finished; exit 11; }
g cpu r15-cli-stack-verify 0.6 1.5 1800 -- $CLI stack-verify --export $VX --artifact $RUN --expect-statement ef0610008901e09101709db727a19b30a5de9afb64217e284432afe892aaeb54 --layers 7..9 --label zk60-trained-stack
date -u > $P/r15_heavy2.finished
