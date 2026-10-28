"""Build an unapplied review diff from the pinned source; no production writes."""
import difflib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
pin=next(x for x in json.loads((ROOT/'source-manifest.json').read_text()) if x['path'].endswith('/trained-1b/zkp-core/src/mle.rs'))
before=(ROOT/pin['snapshot']).read_text()
addition='''    // Arithmetic only: same values at nodes 0..m-1, same evaluation point.
    // Constants are inverses of factorials in Goldilocks; no proof material.
    let m = vals.len();
    if (2..=6).contains(&m) {
        const INV_FACT: [Fp; 6] = [
            Fp(1), Fp(1), Fp(9223372034707292161),
            Fp(15372286724512153601), Fp(17678129733188976641),
            Fp(18293021202169462785),
        ];
        let mut diff = [Fp2::ZERO; 6];
        diff[..m].copy_from_slice(vals);
        for order in 1..m {
            for i in (order..m).rev() {
                diff[i] = diff[i].sub(diff[i - 1]);
            }
        }
        for i in 1..m { diff[i] = diff[i].mul_base(INV_FACT[i]); }
        let mut acc = diff[m - 1];
        for i in (0..m - 1).rev() {
            acc = acc.mul(x.sub_base(Fp::new(i as u64))).add(diff[i]);
        }
        return acc;
    }
'''
needle='pub fn interpolate_eval(vals: &[Fp2], x: Fp2) -> Fp2 {\n'
assert before.count(needle)==1
after=before.replace(needle,needle+addition)
(ROOT/'candidate-mle.rs').write_text(after)
rel='ops/zkp-mvp/trained-1b/zkp-core/src/mle.rs'
(ROOT/'finite-difference.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+rel,tofile='b/'+rel)))
print('Unapplied and uncompiled patch prepared; one function insertion, original generic body retained.')
