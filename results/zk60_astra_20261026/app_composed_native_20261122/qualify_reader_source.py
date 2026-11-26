"""Exercise the distributable guest reader from its own checkout layout."""
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

sys.path.insert(0,str(Path(__file__).resolve().parent))
from package_reader import APP, HERE, ROOT, package, source_files

ARCHIVE = HERE/'w16r2-guest-source-12g.tar.gz'
ARCHIVE_SHA = 'df6f1ceead22165be82c2cbff456e6459ff9eb943539e7760d1d8377faac9d57'
PILOT = HERE/'qualification-20261124T082610.220713Z'
KEY = '32c026629c724e2b9ccac8670e54c1c2349110733b011065cd97ff37ac451d90'


def unpack_reader(root):
    raw = ARCHIVE.read_bytes()
    if hashlib.sha256(raw).hexdigest() != ARCHIVE_SHA:
        raise ValueError('Released reader archive digest differs')
    root.mkdir()
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz') as archive:
        expected = [str(p) for p in source_files()]
        if archive.getnames() != expected or not all(m.isfile() for m in archive.getmembers()):
            raise ValueError('Released reader archive inventory differs')
        archive.extractall(root, filter='data')


def qualify():
    if not __debug__:
        raise RuntimeError('Reader qualification requires enabled assertions')
    rebuilt, report = package()
    assert rebuilt == ARCHIVE.read_bytes()
    with tempfile.TemporaryDirectory(prefix='astra-reader-source-') as tmp:
        root = Path(tmp).resolve()
        reader = root/'received source'
        unpack_reader(reader)
        app = reader/APP
        env = {k:v for k,v in os.environ.items() if not k.startswith(('PM_','HL_','ZK60_','PYTHON'))}
        env.update(PM_PUBLIC_DIR=str(root/'unused public'), PM_PRIVATE_DIR=str(root/'unused owner'),
                   OPENBLAS_NUM_THREADS='1', OMP_NUM_THREADS='1')
        def call(*args):
            return subprocess.run([sys.executable, '-I', '-B', *map(str,args)],cwd=root,env=env,check=True,
                                  capture_output=True,text=True,timeout=30)
        signed = root/'downloaded.manifest.json'
        shutil.copyfile(PILOT/'manifest.json', signed)
        signature = json.loads(call(app/'tools/verify_manifest.py',signed,'--signature-only','--public-key',KEY).stdout)
        assert signature['accepted'] and signature['scope'] == 'publisher_signature_only'
        call(app/'tools/prepare_w16r2_verifier.py','--help')
        call(app/'tools/verify_publication.py','--help')
        # The test harness is supplied only to the qualification process. Its public store,
        # signer and segment fixture are all created inside a new temporary directory.
        shutil.copyfile(ROOT/APP/'tests/test_w16r2_post_coverage.py', root/'test_w16r2_post_coverage.py')
        probe = """
import hashlib, json, sys, unittest
from pathlib import Path
app, signed = map(Path, sys.argv[1:])
sys.path[:0] = [str(app), str(app/'tools'), str(signed.parent)]
from proven_media import config, w16r2_public_verifier as verifier
from proven_media import base_sepolia, testnet_publisher
from proven_media.w16r2_runtime import authority
assert config.REPO == app.parents[1]
assert config.GUARD == app.parents[1]/'scripts/zk60_resource_guard.py'
assert hashlib.sha256(config.GUARD.read_bytes()).hexdigest() == verifier.GUARD_SHA
assert authority()['public_content_only']
coverage = verifier.signed_post_coverage(json.loads(signed.read_bytes()))
suite = unittest.defaultTestLoader.loadTestsFromName('test_w16r2_post_coverage.WholePostTests')
result = unittest.TextTestRunner().run(suite)
assert result.wasSuccessful() and result.testsRun == 4
assert all(Path(m.__file__).resolve().is_relative_to(app) for name,m in sys.modules.items()
           if name == 'proven_media' or name.startswith('proven_media.'))
print(json.dumps({'coverage':coverage,'public_store_tests':result.testsRun}))
"""
        outcome = json.loads(call('-c',probe,app,signed).stdout)
        assert outcome['coverage']['content_tokens'] == 14 and outcome['coverage']['accepted_chunks'] == 3
        assert not (root/'unused public').exists() and not (root/'unused owner').exists()
    return dict(**report, isolated_source_tree=True, portable_publisher_signature=signature['accepted'],
                historical_signed_post=outcome['coverage'], public_store_tests=outcome['public_store_tests'],
                native_replay=False)


if __name__ == '__main__':
    print(json.dumps(qualify(),indent=2))
