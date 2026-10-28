#!/bin/bash
# ROUND 11, TR7-2: the two 8B options dry-run through the presenter script on the r11 binary, one
# after the other (each step guarded inside demo_present.sh). Marker logs/r11_dryruns.done holds
# "<8b-t32 exit> <8b-t128 exit>". Transcripts: ~/zk60-owner-private/token-io/demo-present/<TAG>/.
R=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017
L=$R/logs
/usr/bin/env TAG=8b-t32-dryrun-r11 bash $R/tools/demo_present.sh 8b-t32 > $L/r11-dryrun-8b-t32.window.log 2>&1
A=$?
/usr/bin/env TAG=8b-t128-dryrun-r11 bash $R/tools/demo_present.sh 8b-t128 > $L/r11-dryrun-8b-t128.window.log 2>&1
B=$?
echo "$A $B" > $L/r11_dryruns.done
