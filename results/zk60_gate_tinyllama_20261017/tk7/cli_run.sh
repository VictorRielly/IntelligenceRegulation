#!/bin/bash
# PRIVACY GATE lane, round 8 (the D33 re-pin): exercise the CPU CLI binary
# built from the tk7 copy (zk60_trained_block.tk7.release.bin, dac7fc73...)
# on review P-18's own inputs, layers 7..9 (L = 2): stack-prove, then
# stack-verify in a fresh process, which must print statement-published with
# the trained statement identity R7's verifier published (ef061000...).
# This is NOT P-18's capture (no gate recorder; the CLI's run directory is
# not gated here). The inputs are the P-18 sub-lane's, read in place and
# checked against its manifests first.
# Queue rules: one job at a time; declarations from measured peaks (R7 P-18:
# prove 1.02 GiB / 5.7 s, verify 0.27 GiB / 0.9 s) plus a margin; a hold-file
# check before each job; and the coordinator's hold (0.8 / 1.5) while the
# token lane's r8_round.done is absent.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/tk7
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
BIN=$A/tinyllama-gate-bins/zk60_trained_block.tk7.release.bin
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
SEQ=$A/tinyllama-cli-r7-seq-ho00
VX=$A/tinyllama-cli-r7-verifier-export
RUN=$A/tinyllama-cli-tk7-run-l2
HOLDF=$E/HOLD
R8=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r8_round.done
mkdir -p $P/cli
cd /tmp
sha256sum -c $P/zk60_trained_block.tk7.release.bin.sha256 > $P/cli/bin.check 2>&1 || { echo "BINARY MOVED" > $P/cli_run.finished; exit 4; }
python3 - "$SEQ" "$E/r7cli/inputs.seq-ho00.sha256" "$VX" "$E/r7cli/inputs.verifier-export.sha256" > $P/cli/inputs.check 2>&1 <<'PY' || { echo "INPUTS MOVED" > $P/cli_run.finished; exit 4; }
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
[ -e $RUN ] && { echo "RUN DIR EXISTS" > $P/cli_run.finished; exit 5; }
g() {  # g <label> <need> <cap> <max> -- cmd...
  local l=$1 n=$2 c=$3 m=$4 decl rc; shift 5
  while [ -e $HOLDF ]; do sleep 60; done
  if [ -f $R8 ]; then decl="--need-gib $n --cap-gib $c"; else decl="--need-gib 0.8 --cap-gib 1.5"; fi
  python3 $G run --class cpu $decl --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/cli/$l.log --done $P/cli/$l.done --result-json $P/cli/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) cli/$l exit $rc ($decl)" >> $P/cli_run.progress
  return $rc
}
g tk7-cli-stack-prove 1.5 2.5 1800 -- $BIN stack-prove --export $XP --seq-dir $SEQ --out $RUN --layers 7..9 --label zk60-trained-stack || { date -u > $P/cli_run.finished; exit 6; }
[ -d $RUN.unverified-statement ] && cp -r $RUN.unverified-statement $P/cli/prover-unverified-statement
g tk7-cli-stack-verify 0.8 1.5 1800 -- $BIN stack-verify --export $VX --artifact $RUN --expect-statement ef0610008901e09101709db727a19b30a5de9afb64217e284432afe892aaeb54 --layers 7..9 --label zk60-trained-stack
date -u > $P/cli_run.finished
