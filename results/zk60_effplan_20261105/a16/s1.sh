#!/bin/bash
# A16 stage 1, THE SEALING PASS ALONE (no default decided by it alone): the D55 harness with
# HL_A16_ONLY=1 (it ends after the sealing passes), W16R2 8B T128, 32 blocks, device products.
#  (a) HL_A16_SEAL_AB, 4 passes, the arm order reversed in odd passes: the builder before A16
#      (a16old) and the forms added one at a time in the default sealing pool (8 threads here),
#      all forms, all but one; production's builder (`prod`: build_for_block) before A16, with
#      every form and with every form but `once`; every form in pools of 12 and 16. Pass 0
#      compares one digest of every plane of every witness of the 32-block chain across arms.
#  (b) a sampler window (/usr/bin/sample, 2 ms) of 2 sealing passes on the builder before A16
#      and on every form (the default pool), for the ranking after A16.
#  (c) A16's 8B byte test (CPU and device products, every form set, refusals).
# The raw call graphs stay in raw/ (not committed). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a16
HS=$O/raw/handshake
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s1.progress
E="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_A16_ONLY=1"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
mkdir -p $O/raw $HS
$C --no-run > $O/raw/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/s1_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
ARMS="spauto+a16old,spauto+a16cache,spauto+a16cache+a16quant,spauto+a16cache+a16quant+a16norm,spauto+a16cache+a16quant+a16norm+a16loops,spauto+a16cache+a16quant+a16norm+a16loops+a16kernels,spauto+a16all,spauto+a16xoverlap,spauto+a16xkernels,spauto+a16xcache,spauto+a16xquant,spauto+a16xnorm,spauto+a16xloops,spauto+a16old+prod,spauto+a16all+prod,spauto+a16xonce+prod,sp12+a16all,sp16+a16all"
env $E HL_A16_SEAL_AB=$ARMS HL_A16_SEAL_PASSES=4 HL_D55_AB_ALTERNATE=1 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_alone.log 2>&1
say "sealing alone, 4 passes rc=$?"
grep -E "^D55-AB A16 SEALONLY|panicked" $O/raw/s1_alone.log | cut -c1-400 >> $P
python3 $O/alone_table.py $O/raw/s1_alone.log --base spauto+a16old > $O/s1_alone_table.md 2>&1
cat $O/s1_alone_table.md >> $P
rm -f $HS/go.* $HS/next.*
SARMS="spauto+a16old,spauto+a16all"
env $E HL_A16_SAMPLE=2 HL_A16_SAMPLE_ARMS=$SARMS HL_A16_SAMPLE_DIR=$HS $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_sample.log 2>&1 &
TP=$!
for i in 0 1; do
  PID=""
  for k in $(seq 1 1800); do
    PID=$(grep -o "A16-SAMPLE READY s$i \[[^]]*\] pid [0-9]*" $O/raw/s1_sample.log 2>/dev/null | awk '{print $NF}')
    [ -n "$PID" ] && break
    kill -0 $TP 2>/dev/null || break
    sleep 1
  done
  say "s$i ready pid ${PID:-none}"
  if [ -n "$PID" ]; then
    /usr/bin/sample "$PID" 9 2 -mayDie -file $O/raw/s1_sample_s$i.txt > $O/raw/s1_sample_s$i.out 2>&1 &
    SP=$!
    sleep 1
    touch $HS/go.s$i
    wait $SP
    say "s$i sample rc=$?"
    touch $HS/next.s$i
  fi
done
wait $TP
say "sample windows rc=$?"
grep -E "^A16-SAMPLE|panicked" $O/raw/s1_sample.log | cut -c1-300 >> $P
for i in 0 1; do
  if [ -f $O/raw/s1_sample_s$i.txt ]; then
    python3 $W/results/zk60_effplan_20261105/a15/sample_seal.py $O/raw/s1_sample_s$i.txt --label "a16 s1 [s$i]" > $O/s1_sample_s$i.summary.txt 2>&1
    python3 $O/mainline_split.py $O/raw/s1_sample_s$i.txt $W/results/zk60_effplan_20261105/a11 > $O/s1_sample_s$i.split.txt 2>&1
  fi
done
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a16_the_8b_witness_planes_in_every_form -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_a16_8b.log 2>&1
say "a16 8B byte test (CPU and device products) rc=$?"
grep -E "A16-8B|test result|panicked" $O/raw/s1_a16_8b.log | cut -c1-260 | tail -40 >> $P
say "all done"
