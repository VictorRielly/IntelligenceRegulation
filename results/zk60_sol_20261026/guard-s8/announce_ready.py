from pathlib import Path
from datetime import datetime,timezone
import hashlib
import json

root=Path(__file__).resolve().parents[3]
out=root/"results/zk60_sol_20261026"
s8=out/"guard-s8"
now=datetime.now(timezone.utc).isoformat()
new="88af4c639848d39df8da559652db11529575aa745b916a06eb522c20ea89fbd3"
swap_sha=hashlib.sha256((out/"swap_guard.py").read_bytes()).hexdigest()
note=f"""

## Sol S8 owner acknowledgment / D44 preparation — {now}

Victor D44 and coordinator S8_REVIEW accepted candidate `{new}`. I acknowledge
the planned update of my two static pins (zk60_guarded_command.py
REVIEWED_GUARD_SHA256 and zk60_techweek_demo.py GUARD_PIN) in the same quiet
window. The live guard/pins remain 87138bda until the coordinator OPEN record
and host preflight pass. FIFO stays OFF. Official swap fixture and 9 policy
tests prepared; backups in results/zk60_sol_20261026/guard-s8-backup, second
independent base copy verified at
results/zk60_guard_fix_20261021/zk60_resource_guard.py.new. No benchmark, demo
or consumer may be live.
"""
with (root/"ops/zkp-mvp/RECOVERY_COORDINATION.md").open("a") as f:f.write(note)
message=f"""- {now}: **S8 READY FOR WINDOW (D44).** Current R13 step terminal 0:
  profiles-3 component 63/0, no Sol guard/leaf/waiter remains. No further heavy
  Sol launches until S8 WINDOW CLOSED. Official 45 swap case now checks
  avail 2.5 GiB / swap 2 GiB refusal; installed-policy 9 tests point at the live
  guard and produce expected 6 pass / 3 red on 87138bda; candidate 9/0 revalidated.
  Reviewed candidate unchanged 88af4c63; guard/pins unchanged 87138bda. Hashed
  rollback copies and independent S3-base copy verified; protocol VM-only /
  Windows-host limitation draft ready; owner pin acknowledgment appended to
  RECOVERY. Adapted swap_guard.py SHA {swap_sha}.
  Read-only preflight refuses live rvtk13-build, held locks, sandbox host-scope
  unavailability and the stale D42 record. Host --apply must run with systemd
  scopes and zero skipped cases 45+31+9 plus consumer suites, rollback on failure.
  Claude: fresh GUARD_SWAP_READY.json needs change=S8, ruling including D44,
  window=OPEN, candidate_sha256={new}, current boot_id, written_utc (within
  30 minutes), absolute/existing hold_files, sandbox_views_checked=true; then
  WINDOW OPEN. R13 source idle; all 73 profiles / 3858 hash kinds passed before
  the final geometry correction. Host/LogUp definitions are staged; proof gate
  remains disabled. Token visibility (3 pub functions + re-export) acknowledged
  for carry after the window.
"""
todo=root/"docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md"
s=todo.read_text();mark="\n## Astra —";assert s.count(mark)==1
todo.write_text(s.replace(mark,"\n"+message+mark))
with (out/"PROGRESS.md").open("a") as f:f.write("\n"+message)
state_path=root/"results/zk60_1b_native_20261017/r13/CURRENT_DEV_STATE.json"
state=json.loads(state_path.read_text())
state.update(utc=now,live_tool_session=None,live_stage=None,
    latest_completed_filter="profiles-3:63/0; prior 73-profile/3858-kind census passes",
    phase="S8 D44 installation preparation; READY FOR WINDOW",source_edits_held_while_cargo_queued=False,
    next="S8 window/open + host apply, verify close; then carry token visibility and resume staged argument/protocol integration")
state_path.write_text(json.dumps(state,indent=2)+"\n")
(s8/"READY_FOR_WINDOW.json").write_text(json.dumps({"utc":now,"ruling":"D44","candidate_sha256":new,
    "swap_script_sha256":swap_sha,"own_jobs_terminal":True,"policy_red":"official-policy-red.json",
    "expected_host_cases":[45,31,9],"status":"awaiting fresh coordinator OPEN record and host preflight"},indent=2)+"\n")
print("S8 READY FOR WINDOW recorded; live guard/pins unchanged")
