"""Reconstruct the held two-crate source without needing Fable's unpublished ref.

Run from the IntelligenceRegulation repository. Argument: new scratch directory.
The base PCS commit is integrated; the retained patch reconstructs the reviewed
source and the SHA-256 inventory checks every tracked snapshot file.
"""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile

here = Path(__file__).resolve().parent
dest = Path(sys.argv[1]).resolve()
dest.mkdir(parents=True, exist_ok=False)
archive = subprocess.check_output(['git', 'archive', '--format=tar',
    '76ee27513763b7992bd57638b203b7ce76e6a8ed', 'hashline', 'zkp-core'])
with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
    for member in tar.getmembers():
        if member.issym() or member.islnk() or not (member.isfile() or member.isdir()):
            raise ValueError('unexpected Git archive member: ' + member.name)
        if not (dest / member.name).resolve().is_relative_to(dest):
            raise ValueError('unexpected archive path: ' + member.name)
    tar.extractall(dest)
subprocess.run(['git', 'apply', str(here / 'held_source.patch')], cwd=dest, check=True)
expected = json.loads((here / 'snapshot_sha256.json').read_text())
actual = {str(p.relative_to(dest)): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in dest.rglob('*') if p.is_file()}
assert actual == expected, 'reconstructed source differs from reviewed snapshot'
print(json.dumps({'source_commit': 'f8d40a74e07ee9d60f869fe323eee2a2f564f067',
                  'reconstructed_files': len(actual), 'all_sha256_match': True}))
