The first launch used Python Popen(start_new_session=True) inside the isolated
workspace sandbox. It returned namespace PID 4 but produced no report or log
output. The empty validation.log and validation.pid preserve that launch.

The bounded validator then ran outside the sandbox as
`python3 results/zk60_round24_evidence/validate.py` and exited 0. All five stage
logs, results/zk60_round24_validation.json and validation.done belong to that
completed run. PID 4 is not an active host-process identifier; the empty
initial log is not the final validation result.
