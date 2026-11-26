"""Exercise prepare and check as independent CLI calls using the archived public pilot manifests."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from qualify_reader_source import ARCHIVE_SHA, unpack_reader

HERE = Path(__file__).resolve().parent
APP = HERE.parents[2] / 'apps/proven-media'
PILOT = HERE / 'qualification-20261124T082610.220713Z'
sys.path.insert(0, str(APP))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', action='store_true', help='also run the guarded author/guest pilot and replay all three new proofs')
    args = parser.parse_args()
    if not __debug__:
        raise RuntimeError('qualification requires enabled assertions')
    with tempfile.TemporaryDirectory(prefix='astra-portable-verifier-') as temporary:
        root = Path(temporary).resolve()
        assert shutil.disk_usage(root).free >= 55 * 2**30 + 11_950_596_915
        script = [sys.executable, '-B', str(APP / 'tools/prepare_w16r2_verifier.py')]
        prepared = json.loads(subprocess.check_output([*script, str(root / 'operator')], cwd=root))
        kit = (root / 'operator').rename(root / 'reader kit')
        producer_environment = dict(os.environ, PM_W16R2_VERIFIER_KIT=str(kit))
        os.environ.update(PM_W16R2_VERIFIER_KIT=str(kit), PM_PUBLIC_DIR=str(root / 'public'),
                          PM_PRIVATE_DIR=str(root / 'unused-private'), PM_FAST_MODELS=str(root / 'absent-models'))
        reader = root/'received source'
        unpack_reader(reader)
        received_check = reader/'apps/proven-media/tools/prepare_w16r2_verifier.py'
        reader_env = dict(os.environ, PM_REPO_ROOT=str(reader))
        checked = json.loads(subprocess.check_output([sys.executable,'-I','-B',str(received_check),'--check',str(kit)],
                                                     cwd=root,env=reader_env))
        assert prepared == checked and checked['accepted'] and checked['files'] == 611

        from proven_media import manifest, records, w16r2_public_verifier as verifier
        signed = json.loads((PILOT / 'manifest.json').read_bytes())
        key = json.loads((PILOT / 'publisher_public_key.json').read_bytes())['public_key']
        assert manifest.verify_signature(signed, key)['accepted']
        post_id = signed['item']['post_id']
        policies = []
        pub = SimpleNamespace(store=root / 'public/bundle-store')
        for entry in signed['entries']:
            category = entry['category']
            publication = json.loads((PILOT / f'{category}.publication.json').read_bytes())
            assert hashlib.sha256(records.canonical(publication)).hexdigest() == entry['bundle']['manifest_sha256']
            context = verifier._context(pub, publication, post_id)
            command = verifier._guarded_command(root, root / 'receipt', context, post_id)
            assert context['environment']['ZK60_MODELS'] == str(kit / 'models')
            assert command[command.index('--') + 1] == str(kit / 'bin/zk60_classify')
            assert command[command.index('--tables') + 1] == str(kit / 'export/token_io')
            assert command[command.index('--export') + 1] == str(kit / 'export')
            assert command[command.index('--expect-statement') + 1] == entry['model_id']
            assert context['intake']['binary_sha256'] == entry['verifier_id'] == checked['binary_sha256']
            assert command[command.index('--policy') + 1] == entry['policy_id']
            policies.append(category)
        assert sorted(policies) == ['hate', 'sexual', 'violence']
        assert not (root / 'unused-private').exists() and not (root / 'public').exists()
        result = dict(**checked, checked_category_configurations=policies, checked_signed_manifest=True,
                      relocated_kit=True, reader_default_models_set_to_missing_path=True, native_proof_replayed=False)
        if args.native:
            output = subprocess.check_output([sys.executable, '-B', str(HERE / 'qualify.py'), '--released-reader'],
                                             env=producer_environment, cwd=root, text=True)
            report = Path(output.strip().splitlines()[-1])
            native = json.loads(report.read_bytes())
            assert native['passed'] and native['public_scratch_removed'] and native['guest_source_sha256'] == ARCHIVE_SHA
            service = json.loads((report.parent / 'service.guard.json').read_bytes())
            assert (service['need_gib'], service['cap_gib']) == (196, 220)
            coverage = native['native_post_coverage']
            assert coverage['planned_chunks'] == coverage['accepted_chunks'] == len(policies)
            assert coverage['content_tokens'] == signed['item']['content_length_tokens']
            assert coverage['labels'] == signed['labels']
            floors = {}
            guard_peaks = {}
            for category in policies:
                proof = json.loads((report.parent / f'{category}.json').read_bytes())['proof_verifier']
                invoked = proof['guard']['cmd']
                assert proof['ok'] and invoked[:2] == [str(kit / 'bin/zk60_classify'), 'verify']
                assert invoked[invoked.index('--export') + 1] == str(kit / 'export')
                guard = proof['guard']
                assert (guard['class'], guard['need_gib'], guard['cap_gib']) == ('gpu', 12, 16)
                assert 0 < guard['peak_rss_gib'] < guard['cap_gib'] and guard['peak_vram_mib'] > 0
                guard_peaks[category] = {key:guard[key] for key in
                    ('need_gib', 'cap_gib', 'peak_rss_gib', 'peak_vram_mib', 'child_wall_seconds', 'enforcement')}
                floors[category] = proof['verified']['whole_run_floor_bits']
            result.update(native_proof_replayed=True, whole_run_floors=floors,
                          guest_source_sha256=ARCHIVE_SHA, standalone_guards=guard_peaks,
                          native_post_coverage=coverage, pilot_report=str(report.relative_to(HERE)))
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
