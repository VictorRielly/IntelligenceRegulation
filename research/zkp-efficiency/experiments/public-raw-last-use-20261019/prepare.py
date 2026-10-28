"""Pin read-only inputs and emit a review-only, UNBUILT Rust diff."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
PRIOR = HERE.parent / 'direct-signed-byte-padding-20261019'
pins = json.loads((PRIOR / 'source-pins.json').read_text())
for p in pins:
    assert hashlib.sha256(Path(p['source']).read_bytes()).hexdigest() == p['sha256'], p['source']
(HERE / 'source-pins.json').write_text(json.dumps(pins, indent=2) + '\n')
(HERE / 'native').mkdir(exist_ok=True)
for name in ['hashline__src__private_block__trained_block.rs',
             'hashline__src__private_block__trained_statement.rs',
             'hashline__src__private_block.rs']:
    (HERE / 'native' / name).write_bytes((PRIOR / 'native' / name).read_bytes())
for src, dst in [('fixtures.json', 'input-fixtures.json'), ('payload-ledger.json', 'prior-direct-ledger.json')]:
    (HERE / dst).write_bytes((PRIOR / src).read_bytes())
old = (HERE / 'native/hashline__src__private_block__trained_block.rs').read_text()
sentinel = '        let _ = (wq.sha256, exp.sha256);\n'
assert old.count(sentinel) == 1
anchor = '        let blk = BlockPublic::new(public, ff);\n'
assert old.count(anchor) == 1
insert = ('        // All raw PUBLIC arrays have passed their checks and been copied\n'
          '        // into the owned block. End their lifetime before record hashing.\n'
          '        let _ = (wq.sha256, exp.sha256);\n'
          '        drop((wq, wk, wv, wo, ga, gm, wg, wu, wd, exp, act));\n')
new = old.replace(sentinel, '').replace(anchor, anchor + insert)
(HERE / 'candidate-trained_block.rs').write_text(new)
patch = ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
    fromfile='a/hashline/src/private_block/trained_block.rs',
    tofile='b/hashline/src/private_block/trained_block.rs'))
(HERE / 'review-only-raw-last-use.patch').write_text(patch)
(HERE / 'run_bounded.py').write_bytes((PRIOR / 'run_bounded.py').read_bytes())
(HERE / 'input-pins.json').write_text(json.dumps([
    dict(path=str((HERE / n).relative_to(HERE)), sha256=hashlib.sha256((HERE / n).read_bytes()).hexdigest())
    for n in ['input-fixtures.json', 'prior-direct-ledger.json']
], indent=2) + '\n')
print(json.dumps(dict(status='PASS', source_pins=len(pins),
    r8_manifest_matches=sum(p['r8_manifest_match'] is True for p in pins),
    patch_lines=len(patch.splitlines()), native_build=False, patch_applied=False)))
