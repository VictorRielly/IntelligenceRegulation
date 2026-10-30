"""A5_PATCH_REVIEW.md section 4.3 step 10 (the fail-closed control's request), as written there.
usage: make_fail_request.py SRC_REQUEST OWN_FAIL_DIR EQ_FAIL_DIR"""
import json, os, sys
src, own, eq = sys.argv[1:4]
m = json.load(open(src))
for r in m['jobs']:
    r['out'], r['owner_dir'] = f"{eq}/{r['name']}", f"{own}/owners/{r['name']}"
m['jobs'][1]['sequence_dir'] = f"{own}/empty"      # job 1 must refuse before its header
fd = os.open(f"{own}/batch-request.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
os.write(fd, json.dumps(m).encode()); os.close(fd)
