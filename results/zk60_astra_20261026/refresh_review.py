"""Refresh reviewable source hashes/diffs, excluding all runtime/private data."""
from datetime import datetime,timezone
import difflib
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];APP=ROOT/'apps/proven-media'
OUT=HERE/'review'
BASELINE={'README.md':'README.md','items.py':'proven_media/items.py','publisher.py':'proven_media/publisher.py','test_app.py':'tests/test_app.py'}
ADDED=['TESTNET.md','R_C1_DEVELOPMENT.md','requirements-testnet.txt','contracts/ProvenMediaAnchor.sol',
       'proven_media/image_preprocess.py','proven_media/base_sepolia.py','proven_media/testnet_publisher.py',
       'proven_media/classifier_cli.py','proven_media/classifier_prover.py',
       'tools/compile_anchor.py','tools/sepolia_setup.py','tools/classifier_pipeline.py',
       'tests/test_image_preprocess.py','tests/test_testnet_publisher.py','tests/test_sepolia_setup.py',
       'tests/test_classifier_cli.py','tests/test_classifier_prover.py','tests/test_publication_bundle.py','tests/fixtures/image_area_v1.json']


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(exist_ok=True);paths=[]
    for directory in ('proven_media','tools','tests','policy','contracts','static'):
        paths.extend(p for p in (APP/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    paths.extend(p for p in APP.iterdir() if p.is_file() and
                 (p.suffix in ('.md','.txt','.py','.json') or p.name=='.gitignore'))
    hashes={str(p.relative_to(ROOT)):sha(p) for p in sorted(set(paths))}
    current=OUT/'app_source_sha256.json';old=OUT/'app_source_sha256_1834.json'
    if current.exists() and not old.exists():old.write_bytes(current.read_bytes())
    current.write_text(json.dumps(hashes,indent=2)+'\n')
    diffs=[]
    for before,after in BASELINE.items():
        diffs.extend(difflib.unified_diff((HERE/'baseline'/before).read_text().splitlines(True),
            (APP/after).read_text().splitlines(True),fromfile='intake/'+after,tofile='apps/proven-media/'+after))
    (OUT/'app_baseline_changes.patch').write_text(''.join(diffs))
    diffs=[]
    for name in ADDED:
        diffs.extend(difflib.unified_diff([], (APP/name).read_text().splitlines(True),
                                        fromfile='/dev/null',tofile='apps/proven-media/'+name))
    (OUT/'app_added_files.patch').write_text(''.join(diffs))
    export=ROOT/'results/zk60_shieldstral_export_20261026'
    files=sorted(export.glob('*.py'))+sorted((export/'vendor').glob('*.py'))
    (OUT/'export_source_sha256.json').write_text(json.dumps({str(p.relative_to(ROOT)):sha(p) for p in files},indent=2)+'\n')
    owned=sorted(HERE.glob('*.py'))
    (OUT/'astra_source_sha256.json').write_text(json.dumps({str(p.relative_to(ROOT)):sha(p) for p in owned},indent=2)+'\n')
    print(json.dumps({'at':datetime.now(timezone.utc).isoformat(),'app_files':len(hashes),'new_files':len(ADDED),
                      'export_source_files':len(files),'private_files_included':False}))


if __name__=='__main__':main()
