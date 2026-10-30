"""Adapt pinned local native code; never execute foreign code."""
from pathlib import Path
import hashlib, json
H=Path(__file__).resolve().parent
P=H.parent/'resident-public-plan-20261029'
for n in ['native_priv_table.rs','native_claim_point.rs','native_mask_eval.rs']:
    (H/n).write_bytes((P/n).read_bytes())
baseline=(H/'native_priv_table.rs').read_text()
candidate=baseline.replace('fn native_priv_table(', 'fn changed_priv_table(',1).replace('let eqf = eq_table_msb(&fixed);','let eqf = candidate::eq_table_msb(&fixed);',1)
assert candidate.count('candidate::eq_table_msb')==1
(H/'changed_priv_table.rs').write_text(candidate)
mask=(H/'native_mask_eval.rs').read_text().replace('fn native_mask_eval(', 'fn changed_mask_eval(',1).replace('let eq = eq_table_msb(', 'let eq = candidate::eq_table_msb(',1)
assert mask.count('candidate::eq_table_msb')==1
(H/'changed_mask_eval.rs').write_text(mask)
prefix=(P/'harness.rs').read_text().split('fn main(){')[0]
prefix=prefix.replace('use candidate::Plan;','').replace('include!("native_priv_table.rs");','include!("native_priv_table.rs");\ninclude!("changed_priv_table.rs");')
prefix=prefix.replace('include!("native_mask_eval.rs");','include!("native_mask_eval.rs");\ninclude!("changed_mask_eval.rs");')
main=(H/'main.rs').read_text()
(H/'harness.rs').write_text(prefix+main)
original=(H/'native/zkp-core__src__mle.rs').read_text()
start=original.index('pub fn eq_table(')
end=original.index('/// eq(r, s)')
expected=original[start:end].replace('lo.par_iter_mut().zip(hi.par_iter_mut())','lo.iter_mut().zip(hi.iter_mut())').strip()
assert expected==(H/'serial_eq.rs').read_text().strip()
(H/'extraction.json').write_text(json.dumps(dict(eq_adapter='Only Rayon par_iter_mut -> iter_mut; branch and arithmetic unchanged',eq_native_sha256=hashlib.sha256(original[start:end].encode()).hexdigest(),changed_table_adapter='Function name and one eq_table_msb call only',native_priv_table_sha256=hashlib.sha256(baseline.encode()).hexdigest()),indent=2)+'\n')
print('Prepared serial Eq and table differential harness')
