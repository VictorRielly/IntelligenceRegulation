"""Generate a research-only multiple-private-site adapter. Never writes a production path."""
from pathlib import Path
import difflib, hashlib, json
HERE=Path(__file__).resolve().parent
src=(HERE/'native/hashline__src__private_block__argument.rs').read_text()
start=src.index('/// the mask pair\'s value at the claim\'s column tail')
end=src.index('/// `cd * plane~',start)
original=src[start:end]
helper='''// UNCOMPILED research proposal: current slot, public challenge weights only.
#[derive(Default)]
struct MaskTailWeights {
    point: Vec<Fp2>,
    eq: Vec<Fp2>,
}

impl MaskTailWeights {
    fn at(&mut self, point: &[Fp2]) -> &[Fp2] {
        if self.eq.is_empty() || self.point.as_slice() != point {
            // Drop the old vector before allocating its replacement.
            self.eq = Vec::new();
            self.point.clear();
            self.point.extend_from_slice(point);
            self.eq = eq_table_msb(point);
        }
        &self.eq
    }
}

'''
cached=original.replace('fn mask_eval(', 'fn mask_eval_cached(',1)
cached=cached.replace('point: &[Fp2]) -> Fp2', 'point: &[Fp2], weights: &mut MaskTailWeights) -> Fp2',1)
cached=cached.replace('let eq = eq_table_msb(&point[p.log - logm..]);','let eq = weights.at(&point[p.log - logm..]);',1)
new=src[:end]+helper+cached+src[end:]
needle='''            super::timing::slot_step(s, "extension rounds (mask_eval + zk.rs)", ext as u64, || {
                for m in 0..ext {'''
replacement='''            super::timing::slot_step(s, "extension rounds (mask_eval + zk.rs)", ext as u64, || {
                // Public weights are owned by this slot; private rows remain per site.
                let mut tail_weights = if n_priv > 1 { Some(MaskTailWeights::default()) } else { None };
                for m in 0..ext {'''
assert new.count(needle)==1
new=new.replace(needle,replacement,1)
needle='''                            Tab::Priv(p) if p.ext_round == m => mask_eval(&sh, p, pd.data[p.cm as usize], &claim_point(p, &rho)),'''
replacement='''                            Tab::Priv(p) if p.ext_round == m => {
                                let point = claim_point(p, &rho);
                                match tail_weights.as_mut() {
                                    Some(weights) => mask_eval_cached(&sh, p, pd.data[p.cm as usize], &point, weights),
                                    None => mask_eval(&sh, p, pd.data[p.cm as usize], &point),
                                }
                            },'''
assert new.count(needle)==1
new=new.replace(needle,replacement,1)
target='hashline/src/private_block/argument.rs'
patch=''.join(difflib.unified_diff(src.splitlines(True),new.splitlines(True),fromfile='a/'+target,tofile='b/'+target,n=3))
(HERE/'mask-tail-weights.unapplied.patch').write_text(patch)
(HERE/'candidate-argument.rs').write_text(new)
(HERE/'adapter-manifest.json').write_text(json.dumps({'baseline_sha256':hashlib.sha256(src.encode()).hexdigest(),
 'candidate_sha256':hashlib.sha256(new.encode()).hexdigest(),'compiled':False,'applied':False,
 'selection':'n_priv > 1; single-private-site slots retain original mask_eval',
 'new_private_storage':False,'eq_lifetime':'one extension closure, including extension() after row evaluation'},indent=2)+'\n')
print('research-only patch',len(patch),'bytes')
