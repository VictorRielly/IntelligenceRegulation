#!/usr/bin/env bash
# Guard-fix lane test runner.  Runs on private temp paths only (see the test files);
# never takes /tmp/zk-heavy.lock or registers in /tmp/zk-guard.  Usage:
#   bash run_tests.sh <tag>        logs to test_logs/<tag>.*.log, marker <tag>.done
# The live-suite copy runs WITH its 5 signal cases (RUN_SIGNAL_CASES=1): they signal
# only processes the test itself spawned (own_kill checks the private temp dir).
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021
TAG=${1:-final}
L=$D/test_logs
export TMPDIR=${TMPDIR:-/tmp}
{
  date -u +%Y-%m-%dT%H:%M:%SZ
  sha256sum "$D/zk60_resource_guard.py.new" "$D/zk60_resource_guard.py.orig" \
            "$D/tests/test_zk60_guard_fix.py" "$D/test_guard_fix.py" \
            "$D/test_existing_suite_on_copy.py"
} > "$L/$TAG.hashes.txt"
python3 "$D/test_guard_fix.py" -v > "$L/$TAG.test_guard_fix.log" 2>&1
a=$?
RUN_SIGNAL_CASES=1 GUARD_UNDER_TEST="$D/zk60_resource_guard.py.new" \
  python3 "$D/test_existing_suite_on_copy.py" -v > "$L/$TAG.existing_on_new.log" 2>&1
b=$?
RUN_SIGNAL_CASES=1 GUARD_UNDER_TEST="$D/zk60_resource_guard.py.orig" \
  python3 "$D/test_existing_suite_on_copy.py" -v > "$L/$TAG.existing_on_orig.log" 2>&1
c=$?
date -u +%Y-%m-%dT%H:%M:%SZ >> "$L/$TAG.hashes.txt"
echo "test_guard_fix=$a existing_on_new=$b existing_on_orig=$c" > "$L/$TAG.done"
