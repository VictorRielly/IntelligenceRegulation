"""Pinned optional activation-worker integration; no model or native changes."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path

from . import config, records
from .classifier_cli import require
from .shieldstral_text import TEKKEN_SHA256

ROOT = config.REPO / 'results/zk60_astra_20261026/resident_writer_candidate_20261112'
SOURCE_PINS = {'client.py': 'bb6bfddda0f811754102613c60dc0a9a4544590f08126c45926e4287e5abd321', 'engine.py': 'e7fcae642b3aa094be395daefd3b32531c1330c3cf89d5475889a4c620817603', 'pipe_worker.py': 'f1b4eca100e7acde7a32506db8f328f10019e104959701597b64b3b9b1ee70ec'}  # Filled from the completed, independently hashed writer study.
NUMPY_VERSION = '2.3.5'
W16_ROOT = config.REPO / 'results/zk60_astra_20261026/w16r2_resident_app_candidate_20261112'
W16_SOURCE_PINS = {
    'client.py': '89264986015ad321224acaf370793012bef0575d2b3b210cd40df2c7be411c4c',
    'engine.py': 'ba042b524af174bbc47530c69179985ecdec11fc6051623a9d70e7e1a6037bc3',
    'pipe_worker.py': 'b45ec9c9c333e45812f19e7bc891896d3cc5bcf997d133a0b0103642fb914593',
    'export_selection.py': '6a967e20a7fb66657d20213e07fd500553ab37f57328986a7abd8ada90686d64',
}
W16_LOADER_SHA = 'cccd11846d0c1286b7b4a26fc9f3994a0c5a1ae00455fcb619a729d35d6afb3d'


def _spec(runtime=None):
    w16 = getattr(runtime, 'KIND', None) == 'shieldstral-fast-w16r2'
    return (W16_ROOT, W16_SOURCE_PINS, 4) if w16 else (ROOT, SOURCE_PINS, 3)


def authenticate(runtime=None):
    root, pins, count = _spec(runtime)
    require(len(pins) == count, 'resident writer source manifest is incomplete')
    for name, expected in pins.items():
        path = root / name
        require(path.is_file() and not path.is_symlink(), 'resident writer source is unavailable')
        require(records.sha256_file(path) == expected, 'resident writer source changed')


def identity(runtime=None):
    return hashlib.sha256(records.canonical(_spec(runtime)[1])).hexdigest()


def open_pool(runtime, private_root, logs, run_id):
    """Called only after taking the service lock and entering its resource guard."""
    authenticate(runtime)
    root, pins, count = _spec(runtime)
    directory = Path(logs) / ('resident-' + run_id)
    directory.mkdir(mode=0o700, exist_ok=False)
    source = root / 'client.py'
    spec = importlib.util.spec_from_file_location('_pm_pinned_resident_writer', source)
    module = importlib.util.module_from_spec(spec)
    raw = source.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == pins['client.py'], 'resident client changed')
    exec(compile(raw, str(source), 'exec'), module.__dict__)
    pool = None
    try:
        options = {'export': runtime.EXPORT} if count == 4 else {}
        pool = module.Pool(runtime.WRITER_PYTHON, Path(private_root), directory,
                           count=runtime.WRITERS_AT_ONCE, **options)
        require(len(pool.clients) == runtime.WRITERS_AT_ONCE, 'resident writer count differs')
        for client in pool.clients:
            ready = client.ready
            require(ready.get('event') == 'ready'
                    and ready.get('profile_sha256') == runtime.PROFILE_SHA
                    and ready.get('original_writer_sha256') == runtime.WRITER_SHA
                    and ready.get('writer_sha256') == pins['engine.py']
                    and ready.get('tokenizer_sha256') == TEKKEN_SHA256
                    and ready.get('layers_loaded') == 26
                    and ready.get('numpy') == NUMPY_VERSION,
                    'resident writer startup identity differs')
            if count == 4:
                export = ready.get('export', {})
                require(ready.get('selection_sha256') == pins['export_selection.py']
                        and export.get('name') == 'a29-uniform-u1'
                        and export.get('profile_sha256') == runtime.PROFILE_SHA
                        and export.get('loader_sha256') == W16_LOADER_SHA
                        and export.get('layers') == 26 and export.get('T') == 128,
                        'W16R2 resident writer export identity differs')
        ready_path = directory / 'ready.json'
        fd = os.open(ready_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump([client.ready for client in pool.clients], stream)
        return pool
    except BaseException:
        if pool is not None:
            pool.close()
        raise


def alive(pool):
    return bool(pool.clients) and all(not client.closed and client.process.poll() is None
                                      for client in pool.clients)
