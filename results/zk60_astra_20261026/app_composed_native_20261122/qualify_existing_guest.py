"""Replay a retained public pilot on a Mac without starting the publishing service."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from qualify import APP, HERE, ROOT, quiet, replay_guest, save
from qualify_reader_source import ARCHIVE_SHA, unpack_reader
from proven_media import public_store_download, w16r2_export, w16r2_runtime as runtime
from proven_media.publisher import LocalChainPublisher


def clone(source, target):
    # The fixture already occupies this APFS volume. Clone its public files
    # without duplicating the 12 GB kit or the 2 GB post on the host disk.
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['/bin/cp', '-cR', str(source), str(target)], check=True)
    assert source.stat().st_ino != target.stat().st_ino


def qualify(pilot, out, work, facts):
    original = json.loads((pilot/'RESULT.json').read_bytes())
    assert original['public_fixture_only']
    public = Path(original['public_scratch'])
    signed = json.loads((pilot/'manifest.json').read_bytes())
    key = json.loads((pilot/'publisher_public_key.json').read_bytes())['public_key']
    pid = signed['item']['post_id']
    for name, source, size in public_store_download.store_members(LocalChainPublisher(public), pid, signed):
        target = work/name
        if isinstance(source, bytes):
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source)
        else:
            clone(source, target)
        assert target.stat().st_size == size
    received = work/f'proven-media-{pid}'
    store = received/'public-store'
    kit = work/'received kit'
    clone(public/'verifier-export-w16r2-94643880', kit/'export')
    clone(runtime.BINARY, kit/w16r2_export.KIT_BINARY)
    checkpoint = w16r2_export.CHECKPOINT
    clone(runtime.baseline.NATIVE_MODELS/checkpoint, kit/'models'/checkpoint)

    reader = work/'received source'
    unpack_reader(reader)
    guest = reader/APP.relative_to(ROOT)
    # On this shared host the extracted reader must observe the real lane HOLD
    # and contribute its guard records to the common history.
    lane = Path('results/zk60_media_app_20261021')
    (reader/lane).symlink_to(ROOT/lane, target_is_directory=True)
    absent = work/'absent'
    os.environ.update(PM_REPO_ROOT=str(reader), PM_PRIVATE_DIR=str(absent), PM_PUBLIC_DIR=str(absent),
        PM_FAST_MODELS=str(absent), PM_W16R2_VERIFIER_KIT=str(kit),
        ZK60_GUARD_HISTORY=str(ROOT/'results/zk60_resource_guard/history.jsonl'),
        ZK60_GUARD_DISK_FLOOR_GIB='55', ZK60_GUARD_DISK_KILL_GIB='55')

    def cli(tool, *args):
        return json.loads(subprocess.check_output([sys.executable, '-I', '-B', str(guest/'tools'/tool),
                          *map(str,args)], cwd=work, timeout=600))

    checked_kit = cli('prepare_w16r2_verifier.py', '--check', kit)
    assert checked_kit['accepted'] and checked_kit['files'] == 611
    checked = cli('verify_manifest.py', received/f'{pid}.manifest.json', '--public-key', key,
                  '--public-dir', store, '--rehash')
    assert checked['accepted'] and not checked['pending_anchor']
    facts.update(source_pilot=pilot.name, source_service_exit=original.get('guard_exit'),
                 guest_source_sha256=ARCHIVE_SHA, kit=checked_kit)
    replay_guest(out, work, store, signed, checked, facts, guest)
    save(out/'verified-manifest.json', checked)
    facts['standalone_guards'] = {}
    for category in facts['public_verification']:
        proof = json.loads((out/f'{category}.json').read_bytes())['proof_verifier']
        guard = proof['guard']
        assert (guard['class'], guard['need_gib'], guard['cap_gib']) == ('gpu', 12, 16)
        assert 0 < guard['peak_rss_gib'] < guard['cap_gib'] and guard['peak_vram_mib'] > 0
        assert guard['cmd'][:2] == [str(kit/w16r2_export.KIT_BINARY), 'verify']
        assert guard['cmd'][guard['cmd'].index('--export')+1] == str(kit/'export')
        facts['standalone_guards'][category] = {key:guard[key] for key in
            ('need_gib','cap_gib','peak_rss_gib','peak_vram_mib','child_wall_seconds','enforcement')}
        facts['standalone_guards'][category]['floor_bits'] = proof['verified']['whole_run_floor_bits']
    assert set(facts['standalone_guards']) == {'sexual','violence','hate'} and not absent.exists()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pilot', type=Path, help='pilot result directory with its public scratch still available')
    args = parser.parse_args()
    if not __debug__:
        raise RuntimeError('Qualification requires enabled assertions')
    out = HERE/datetime.now(timezone.utc).strftime('guest-%Y%m%dT%H%M%S.%fZ')
    out.mkdir()
    facts = {'passed':False}
    try:
        quiet()
        with tempfile.TemporaryDirectory(prefix='astra-guest-replay-') as tmp:
            qualify(args.pilot.resolve(), out, Path(tmp).resolve(), facts)
    except BaseException as error:
        facts.update(passed=False, error=f'{type(error).__name__}: {error}')
        raise
    finally:
        save(out/'RESULT.json', facts)
    print(out/'RESULT.json', flush=True)
