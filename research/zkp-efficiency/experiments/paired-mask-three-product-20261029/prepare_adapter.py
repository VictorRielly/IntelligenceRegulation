"""Recreate research adapter from retained manifest; never writes production."""
import difflib,json,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
m=json.loads((HERE/'adapter-manifest.json').read_text())
s=(HERE/'native/hashline__src__private_block__argument.rs').read_text()
assert hashlib.sha256(s.encode()).hexdigest()==m['source_sha256']
assert s.count(m['original_function'])==1
patched=s.replace(m['original_function'],m['candidate_function'],1)
assert hashlib.sha256(patched.encode()).hexdigest()==m['candidate_sha256']
(HERE/'candidate-argument.rs').write_text(patched)
diff=''.join(difflib.unified_diff(s.splitlines(True),patched.splitlines(True),fromfile='a/hashline/src/private_block/argument.rs',tofile='b/hashline/src/private_block/argument.rs'))
assert hashlib.sha256(diff.encode()).hexdigest()==m['patch_sha256']
(HERE/'paired-mask-dot.unapplied.patch').write_text(diff)
print('Research adapter regenerated; uncompiled and unapplied.')
