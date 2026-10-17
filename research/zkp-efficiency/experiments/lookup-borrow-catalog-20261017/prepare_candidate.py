#!/usr/bin/env python3
"""Generate an unapplied, uncompiled candidate from pinned native source."""
from pathlib import Path
import difflib
import hashlib
import json
HERE=Path(__file__).resolve().parent
src=(HERE/'native/protocol.rs').read_text()
anchor='''/// **STAGE 29 (finding S28-R1).** The word count above which the byte
/// histogram is summed in chunks, as stage 28 chose it: a constant of the
/// PRODUCTION call and an ARGUMENT of [`byte_histogram_at`].
pub(super) const HISTOGRAM_PAR_MIN: u64 = 1 << 17;'''
new='''/// Review candidate: borrow exact identity lookup columns for this invocation.
/// Nonidentity maps retain the original wrapping arithmetic and indexed order.
pub(super) fn lookup_columns_at<'a>(lay: &Layout, wit: &'a Witness, dom: Dom, par_min: usize) -> Vec<std::borrow::Cow<'a, [i64]>> {
    use std::borrow::Cow;
    let len = lay.shape().size(dom);
    let lks = lay.lookups(dom);
    let col = |l: &Lk| -> Cow<'a, [i64]> {
        if l.cst == 0 {
            if let [(p, 1)] = l.terms.as_slice() {
                return Cow::Borrowed(&wit.planes[*p][..len]);
            }
        }
        Cow::Owned((0..len).map(|x| l.terms.iter().fold(l.cst, |a, (p, c)| a.wrapping_add(c.wrapping_mul(wit.planes[*p][x])))).collect())
    };
    if lks.len() > 1 && lks.len() * len >= par_min {
        use rayon::prelude::*;
        return lks.par_iter().map(&col).collect();
    }
    lks.iter().map(col).collect()
}

'''
repls=[
 (anchor,new+anchor),
 ('pub(super) fn byte_histogram_at(looked: &[(Dom, Vec<Vec<i64>>)], lookup_words: u64, par_min: u64) -> Vec<u64> {','pub(super) fn byte_histogram_at<C: AsRef<[i64]> + Sync>(looked: &[(Dom, Vec<C>)], lookup_words: u64, par_min: u64) -> Vec<u64> {'),
 ('let cols: Vec<&Vec<i64>> = looked.iter().flat_map(|(_, cols)| cols.iter()).collect();','let cols: Vec<&[i64]> = looked.iter().flat_map(|(_, cols)| cols.iter().map(|c| c.as_ref())).collect();'),
 ('for v in cols.iter().flatten() {','for v in cols.iter().flat_map(|c| c.as_ref().iter()) {'),
 ('let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, lookup_values(&lay, &wit, *d))).collect();',"let looked: Vec<(Dom, Vec<std::borrow::Cow<'_, [i64]>>)> = lay.lookup_doms().iter().map(|d| (*d, lookup_columns_at(&lay, &wit, *d, LOOKUP_PAR_MIN))).collect();")]
out=src
for a,b in repls:
    assert out.count(a)==1,(a,out.count(a)); out=out.replace(a,b)
(HERE/'protocol-candidate.rs').write_text(out)
(HERE/'protocol-candidate.patch').write_text(''.join(difflib.unified_diff(src.splitlines(True),out.splitlines(True),fromfile='a/hashline/src/private_block/protocol.rs',tofile='b/hashline/src/private_block/protocol.rs')))
(HERE/'candidate-metadata.json').write_text(json.dumps(dict(status='uncompiled unapplied review candidate',baseline_sha256=hashlib.sha256(src.encode()).hexdigest(),candidate_sha256=hashlib.sha256(out.encode()).hexdigest(),replacements=len(repls),scope='Cow columns, generic histogram; helpers/transcript/RNG/table inversions/drop order unchanged'),indent=2)+'\n')
print('prepared review-only candidate; no production changes')
