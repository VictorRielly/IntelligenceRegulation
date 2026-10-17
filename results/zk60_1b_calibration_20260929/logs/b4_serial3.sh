#!/bin/bash
# Lane B4-3 experiments, strictly after b4_serial2 (one guarded job at a time).
L=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/logs
until [ -f $L/b4_serial2.done ]; do sleep 30; done
for v in pg+fe13 pg+fp13 pg+fe13+fp13 pg+fe13+fp13+o16; do
  lab=$(echo $v | tr '+' '_')_rot1_T32
  $L/b4_run.sh $lab 2.5 3.5 --variant $v --rotate 1 --corpus b4 --T 32
done
echo done > $L/b4_serial3.done
