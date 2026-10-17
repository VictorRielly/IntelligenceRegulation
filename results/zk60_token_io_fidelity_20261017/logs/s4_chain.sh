#!/bin/bash
# s4 smoke (T32, 2 chunks) then the full s4 run only if the smoke exits 0; each step guarded, own .done marker
L=/home/victor/IntelligenceRegulation/results/zk60_token_io_fidelity_20261017
G="python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib 2.5 --cap-gib 3.5 --wait-secs 5400"
$G --label fid-s4-smoke --max-secs 900 --log $L/logs/s4_smoke.log --result-json $L/logs/s4_smoke.guard.json -- python3 $L/tools/s4_head.py --smoke
rc=$?
echo $rc > $L/logs/s4_smoke.done
if [ $rc -ne 0 ]; then echo 99 > $L/logs/s4_head.done; exit $rc; fi
$G --label fid-s4-head --max-secs 2700 --log $L/logs/s4_head.log --result-json $L/logs/s4_head.guard.json -- python3 $L/tools/s4_head.py
echo $? > $L/logs/s4_head.done
