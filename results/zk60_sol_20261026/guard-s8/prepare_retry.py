"""Restore the reviewed test payload after the first automatic rollback."""
from pathlib import Path
import hashlib
import json

root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
backup=out.parent/'guard-s8-backup'
manifest=json.loads((backup/'manifest.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,entry in manifest['files'].items():
    if name=='swap_guard.s3.py':continue
    assert sha(Path(entry['path']))==entry['sha256'],name
fixture=root/'tests/test_zk60_resource_guard.py'
text=fixture.read_text()
old='''    def test_refuses_when_swap_is_already_in_use(self):
        self.meminfo.write_text(meminfo_text(swap_used_gib=2))'''
new='''    def test_refuses_swap_when_headroom_cannot_restore_all_pages(self):
        self.meminfo.write_text(meminfo_text(avail_gib=2.5, swap_used_gib=2))'''
assert text.count(old)==1
fixture.write_text(text.replace(old,new))
policy=root/'tests/test_zk60_guard_s8.py'
assert not policy.exists()
policy.write_bytes((out/'rolled_back_test_zk60_guard_s8.py').read_bytes())
assert sha(fixture)==manifest['official_fixture_sha256']
assert sha(policy)==manifest['official_policy_sha256']
print('Reviewed test payload restored; live guard and both pins remain original.')
