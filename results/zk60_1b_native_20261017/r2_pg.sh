#!/bin/bash
# NATIVE LANE round 2, R2-2 (2026-10-17): pg_rot1 layers 0 and 21 on both
# held-out sequences; layer 0 / ho00 and layer 21 / ho01 carry every control.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
$D/r2_run.sh $E 0 ho00 --controls
$D/r2_run.sh $E 21 ho01 --controls
$D/r2_run.sh $E 0 ho01
$D/r2_run.sh $E 21 ho00
