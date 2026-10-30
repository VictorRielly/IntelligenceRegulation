"""D44 preparation; does not install or mutate the live guard/pins."""
from pathlib import Path
import datetime
import hashlib
import json
import shutil

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/"results/zk60_sol_20261026"
BACKUP=OUT/"guard-s8-backup"
OLD="87138bda80ae4499a668e67a1c0e7706bb859eafb5e766020bcd59567c8ac59c"
NEW="88af4c639848d39df8da559652db11529575aa745b916a06eb522c20ea89fbd3"
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(ROOT/"scripts/zk60_resource_guard.py")==OLD
assert sha(OUT/"guard-s8/zk60_resource_guard.py.candidate")==NEW
second=ROOT/"results/zk60_guard_fix_20261021/zk60_resource_guard.py.new"
assert sha(second)==OLD
BACKUP.mkdir(exist_ok=False)
files={"zk60_resource_guard.py.orig":ROOT/"scripts/zk60_resource_guard.py",
    "zk60_guarded_command.py":ROOT/"scripts/zk60_guarded_command.py",
    "zk60_techweek_demo.py":ROOT/"scripts/zk60_techweek_demo.py",
    "test_zk60_resource_guard.py":ROOT/"tests/test_zk60_resource_guard.py",
    "swap_guard.s3.py":OUT/"swap_guard.py"}
manifest={"utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"old":OLD,"new":NEW,
    "independent_old_copy":{"path":str(second),"sha256":sha(second)},"files":{}}
for name,path in files.items():
    shutil.copy2(path,BACKUP/name)
    manifest["files"][name]={"path":str(path),"sha256":sha(path)}
test=ROOT/"tests/test_zk60_resource_guard.py"
s=test.read_text()
old='''    def test_refuses_when_swap_is_already_in_use(self):
        self.meminfo.write_text(meminfo_text(swap_used_gib=2))'''
new='''    def test_refuses_swap_when_headroom_cannot_restore_all_pages(self):
        self.meminfo.write_text(meminfo_text(avail_gib=2.5, swap_used_gib=2))'''
assert s.count(old)==1;test.write_text(s.replace(old,new))
policy=ROOT/"tests/test_zk60_guard_s8.py"
assert not policy.exists()
s=(OUT/"guard-s8/test_swap_admission.py").read_text()
s=s.replace("HERE=Path(__file__).resolve().parent\nPATH=HERE/'zk60_resource_guard.py.candidate'", "PATH=Path(__file__).resolve().parents[1]/'scripts/zk60_resource_guard.py'")
s=s.replace("guard_s8_candidate","guard_s8_installed")
assert "PATH=Path(__file__).resolve().parents[1]" in s
policy.write_text(s)
manifest["official_fixture_sha256"]=sha(test)
manifest["official_policy_sha256"]=sha(policy)
(BACKUP/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
(OUT/"guard-s8/protocol_note.draft.md").write_text(f'''\n\n## Swap headroom update (S8, D44)

The installed guard is SHA-256 `{NEW}`. While swap use exceeds1 GiB,
admission requires MemAvailable to cover the declared need, the existing
1 GiB admission margin, and every swapped page. The normal memory check,
global declared budget, exclusive heavy lock, runtime floor and caps remain
in force. FIFO remains OFF. Both static consumers pin this release.

The guard sees only Linux/WSL VM memory. It cannot observe Windows host
memory pressure: high MemAvailable inside the VM does not establish that
the Windows host has headroom. This limitation applies to both swap rules.

Installation evidence and rollback: `results/zk60_sol_20261026/guard-s8/`
and `guard-s8-backup/`. The official45-case, S3/FIFO31-case and S8 policy9-case
suites must all pass on the host without systemd skips before completion.
''')
print(json.dumps({"prepared":True,"backup":str(BACKUP),"guard_unchanged":sha(ROOT/"scripts/zk60_resource_guard.py")==OLD,"pins_unchanged":True}))
