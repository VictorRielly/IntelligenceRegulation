#!/usr/bin/env python3
"""Pin public source and existing aggregate timing logs; no proof data copied."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PROJECT = ROOT.parent.parent
sha = lambda b: hashlib.sha256(b).hexdigest()
pins = {}
for src, dst in [
    (PROJECT/'zkp-core/src/field.rs', HERE/'field.rs'),
    (Path('/tmp/zk60-groups-20260926/zkp-core/src/field.rs'), HERE/'grouped-field.rs'),
    (ROOT/'experiments/fused-fold-round-20260926/experiment.py', HERE/'fused_reference.py'),
    (ROOT/'experiments/sc-szc-groups-20260924/experiment.py', HERE/'grouped_reference.py'),
]:
    b = src.read_bytes()
    if dst.exists():
        assert dst.read_bytes() == b, 'snapshot drift'
    else:
        dst.write_bytes(b)
    pins[str(src)] = dict(sha256=sha(b), snapshot=dst.name)
for src in [PROJECT/'CLAUDE.md', PROJECT/'docs/zkmatrix-poc/MVP_STATUS.md',
            PROJECT/'docs/zkmatrix-poc/ZK60_DECISIONS.md',
            PROJECT/'docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md',
            PROJECT/'docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md', ROOT/'AGENDA.md']:
    pins[str(src)] = dict(sha256=sha(src.read_bytes()), read_only_context=True)
b = json.loads((ROOT/'experiments/batched-weight-fold-20260926/bottleneck.json').read_text())
for item in b['runs']:
    assert sha(Path(item['log_path']).read_bytes()) == item['sha256']
comparison = Path(b['comparison_path'])
assert sha(comparison.read_bytes()) == b['comparison_sha256']
assert json.loads(comparison.read_text())['state'] == 'passed'
assert (comparison.parent/'run.done').read_text().strip() == '0'
(HERE/'bottleneck.json').write_text(json.dumps(b, indent=2)+'\n')
(HERE/'source-pins.json').write_text(json.dumps(pins, indent=2)+'\n')

old = (HERE/'field.rs').read_text()
old_mul = '''        let ac = self.c0.mul(r.c0);
        let bd = self.c1.mul(r.c1);
        let ad = self.c0.mul(r.c1);
        let bc = self.c1.mul(r.c0);
        Fp2 { c0: ac.add(bd.mul(Fp(NONRESIDUE))), c1: ad.add(bc) }'''
new_mul = '''        let ac = self.c0.mul(r.c0);
        let bd = self.c1.mul(r.c1);
        let cross = self.c0.add(self.c1).mul(r.c0.add(r.c1));
        Fp2 { c0: ac.add(bd.mul(Fp(NONRESIDUE))), c1: cross.sub(ac).sub(bd) }'''
old_sq = '    pub fn square(self) -> Fp2 { self.mul(self) }'
new_sq = '''    pub fn square(self) -> Fp2 {
        // u^2 = 7: (a+b)(a+7b) - 8ab = a^2 + 7b^2.
        let ab = self.c0.mul(self.c1);
        let product = self.c0.add(self.c1)
            .mul(self.c0.add(self.c1.mul(Fp(NONRESIDUE))));
        let twice = ab.double();
        Fp2 { c0: product.sub(twice.double().double()), c1: twice }
    }'''
assert old.count(old_mul) == 1 and old.count(old_sq) == 1
candidate = old.replace(old_mul, new_mul).replace(old_sq, new_sq)
(HERE/'field.candidate.rs').write_text(candidate)
patch = ''.join(difflib.unified_diff(old.splitlines(True), candidate.splitlines(True),
                                   fromfile='a/zkp-core/src/field.rs', tofile='b/zkp-core/src/field.rs'))
(HERE/'fp2-arithmetic.proposed.patch').write_text(patch)
assert (HERE/'grouped-field.rs').read_text() == old
(HERE/'patch-provenance.json').write_text(json.dumps(dict(
    baseline_sha256=sha(old.encode()), candidate_sha256=sha(candidate.encode()),
    patch_sha256=sha(patch.encode()), source='zkp-core/src/field.rs',
    matches_grouped_candidate=True, applied_to_production=False, compiled=False,
    note='Review candidate for Karatsuba plus two-product square; add-chain-by-seven variant remains Python-only'), indent=2)+'\n')
print('Source snapshots, four owner logs, comparison state, zero terminal and proposed patch pinned.')
