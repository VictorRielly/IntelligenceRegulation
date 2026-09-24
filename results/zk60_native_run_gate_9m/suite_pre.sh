#!/bin/bash
# ROUND 9m: the WHOLE native suite on the edited tool bytes BEFORE any record
# is re-taken (a scratch pass, as round 9l's).  Expected: the only failures
# are the tool-byte assertions of the records not yet re-taken
# (`zk60_native_rg_bundle.py` and `zk60_native_rg_runpins.py` are in the
# gate's hashed TOOLS list); any other failure is a logic failure and stops
# the freeze.
cd /home/victor/wt-zk60-jointview
date
free -g
/usr/bin/time -v python3 -m unittest discover -s tests -p 'test_zk60_native*.py'
echo "suite exit=$?"
date
